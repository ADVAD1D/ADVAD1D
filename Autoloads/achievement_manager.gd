extends Node
## Achievements service. Loads every Achievement resource in ACHIEVEMENTS_DIR, keeps the
## stats that feed them, saves progress to its own file and shows a toast on unlock.
##
## Adding an achievement needs no code here: create an Achievement .tres in
## res://Resources/Achievements/ (see Scripts/Achievements/achievement.gd) and feed its stat
## from gameplay with add_stat() / submit_best_time(), or call unlock() for manual ones.
##
## Ship rewards: ships are locked by default (see SkinManager); unlocking an achievement
## with reward_ship_index unlocks that ship. GameManager.achievements_enabled only controls
## the main menu button and the unlock toast; rewards are granted either way.

signal achievement_unlocked(achievement: Achievement)
signal progress_changed

const ACHIEVEMENTS_DIR: String = "res://Resources/Achievements/"
const SAVE_PATH: String = "user://achievements.json"
const AUTOSAVE_INTERVAL: float = 5.0
const TOAST_SOUND: AudioStream = preload(
	"res://Assets/Audio/351564__bertrof__game-sound-correct-with-delay.wav"
)

## All loaded definitions, sorted by `order`.
var achievements: Array[Achievement] = []
var _by_id: Dictionary = {} # StringName -> Achievement
var _stats: Dictionary = {} # String -> float
var _unlocked: Dictionary = {} # String -> true
var _dirty: bool = false
var _autosave_left: float = AUTOSAVE_INTERVAL

# Arena run timer (real seconds, survives the reloads that follow a death)
var _run_arena: int = -1
var _run_time: float = 0.0
var _run_active: bool = false

# Toast
var _toast_layer: CanvasLayer
var _toast_panel: PanelContainer
var _toast_title: Label
var _toast_reward: Label
var _toast_sound: AudioStreamPlayer
var _toast_queue: Array[Achievement] = []
var _toast_busy: bool = false


func _ready() -> void:
	_load_definitions()
	_load_progress()


func _process(delta: float) -> void:
	# Pausable node: the run timer stops while the game is paused. Divide by time_scale so
	# slow-motion (time warp) still counts real seconds.
	if _run_active:
		_run_time += delta / maxf(Engine.time_scale, 0.001)
	if _dirty:
		_autosave_left -= delta
		if _autosave_left <= 0.0:
			save_progress()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if _dirty:
			save_progress()


# --- Definitions -------------------------------------------------------------

func _load_definitions() -> void:
	achievements.clear()
	_by_id.clear()
	# list_directory also resolves the .remap files of exported builds
	for file in ResourceLoader.list_directory(ACHIEVEMENTS_DIR):
		if not (file.ends_with(".tres") or file.ends_with(".res")):
			continue
		var res: Resource = load(ACHIEVEMENTS_DIR + file)
		if not (res is Achievement):
			continue
		var achievement: Achievement = res
		if achievement.id == &"":
			push_warning("Achievement without id: " + file)
			continue
		if _by_id.has(achievement.id):
			push_warning("Duplicated achievement id: " + String(achievement.id))
			continue
		achievements.append(achievement)
		_by_id[achievement.id] = achievement
	achievements.sort_custom(func(a: Achievement, b: Achievement): return a.order < b.order)
	_log_message(["Achievements loaded:", achievements.size()])


func get_achievement(id: StringName) -> Achievement:
	return _by_id.get(id)


## Achievements to list in the panel: hidden ones only show up once unlocked.
func get_visible_achievements() -> Array[Achievement]:
	var out: Array[Achievement] = []
	for achievement in achievements:
		if not achievement.hidden or is_unlocked(achievement.id):
			out.append(achievement)
	return out


func is_unlocked(id: StringName) -> bool:
	return _unlocked.has(String(id))


func get_unlocked_count() -> int:
	return _unlocked.size()


# --- Stats -------------------------------------------------------------------

func get_stat(stat: StringName) -> float:
	return float(_stats.get(String(stat), 0.0))


func has_stat(stat: StringName) -> bool:
	return _stats.has(String(stat))


## Adds to a counter stat (e.g. saws destroyed) and unlocks whatever it completes.
func add_stat(stat: StringName, amount: float = 1.0) -> void:
	_stats[String(stat)] = get_stat(stat) + amount
	_on_stat_changed(stat)


## Sets a counter stat that mirrors a count kept elsewhere (e.g. GameManager.deaths_count),
## only ever raising it. `quiet` unlocks without the toast (syncing a loaded save).
func raise_stat(stat: StringName, value: float, quiet: bool = false) -> void:
	if value <= get_stat(stat):
		return
	_stats[String(stat)] = value
	if not quiet:
		_on_stat_changed(stat)
		return
	_dirty = true
	for achievement in achievements:
		if achievement.stat == stat and not is_unlocked(achievement.id) \
				and achievement.is_met(value, true):
			_unlocked[String(achievement.id)] = true
	save_progress()
	progress_changed.emit()


## Records a time, keeping only the best (lowest) one.
func submit_best_time(stat: StringName, seconds: float) -> void:
	if has_stat(stat) and seconds >= get_stat(stat):
		return
	_stats[String(stat)] = seconds
	_on_stat_changed(stat)
	save_progress()


## Unlocks an achievement directly (MANUAL ones, secrets, debug).
func unlock(id: StringName) -> void:
	var achievement: Achievement = get_achievement(id)
	if achievement == null:
		push_warning("Unknown achievement: " + String(id))
		return
	if not is_unlocked(id):
		_set_unlocked(achievement)


func progress_ratio(achievement: Achievement) -> float:
	if is_unlocked(achievement.id):
		return 1.0
	return achievement.progress_ratio(get_stat(achievement.stat), has_stat(achievement.stat))


func progress_text(achievement: Achievement) -> String:
	return achievement.progress_text(get_stat(achievement.stat), has_stat(achievement.stat))


func _on_stat_changed(stat: StringName) -> void:
	_dirty = true
	for achievement in achievements:
		if achievement.stat != stat or achievement.goal_type == Achievement.GoalType.MANUAL:
			continue
		if not is_unlocked(achievement.id) and achievement.is_met(get_stat(stat), has_stat(stat)):
			_set_unlocked(achievement)
	progress_changed.emit()


func _set_unlocked(achievement: Achievement) -> void:
	_unlocked[String(achievement.id)] = true
	_log_message(["Achievement unlocked:", achievement.id])
	save_progress()
	achievement_unlocked.emit(achievement)
	progress_changed.emit()
	if GameManager.achievements_enabled:
		_queue_toast(achievement)


# --- Ship rewards --------------------------------------------------------------

## True when the achievement that rewards this ship is unlocked (SkinManager uses it).
func is_ship_reward_unlocked(ship_index: int) -> bool:
	var achievement: Achievement = get_achievement_for_ship(ship_index)
	return achievement != null and is_unlocked(achievement.id)


## Achievement that rewards this ship, or null.
func get_achievement_for_ship(ship_index: int) -> Achievement:
	for achievement in achievements:
		if achievement.reward_ship_index == ship_index:
			return achievement
	return null


# --- Arena run timer -----------------------------------------------------------

## Called by each arena on _ready. A reload of the same arena (after a death) keeps counting.
func begin_arena_run(arena_index: int) -> void:
	if _run_active and _run_arena == arena_index:
		return
	_run_arena = arena_index
	_run_time = 0.0
	_run_active = true


## Called when every phase of the arena is cleared. Counts arena_<n>_clears (every clear,
## even one started from a later phase) and records arena_<n>_best_time for timed runs.
func complete_arena_run(arena_index: int) -> void:
	add_stat(StringName("arena_%d_clears" % (arena_index + 1)))
	if not _run_active or _run_arena != arena_index:
		return
	_run_active = false
	_log_message(["Arena", arena_index + 1, "cleared in", Achievement.format_time(_run_time)])
	submit_best_time(StringName("arena_%d_best_time" % (arena_index + 1)), _run_time)


## Called when the player leaves the run (back to the main menu).
func cancel_arena_run() -> void:
	_run_active = false
	_run_arena = -1
	if _dirty:
		save_progress()


func get_arena_run_time() -> float:
	return _run_time


# --- Persistence ---------------------------------------------------------------

func save_progress() -> void:
	_dirty = false
	_autosave_left = AUTOSAVE_INTERVAL
	# Web builds only persist the pilot name (same rule as GameManager.save_data)
	if OS.has_feature("web"):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		_log_message(["Error saving achievements", FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify({"stats": _stats, "unlocked": _unlocked.keys()}))


func _load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return
	var saved_stats: Variant = data.get("stats", {})
	if typeof(saved_stats) == TYPE_DICTIONARY:
		for key in saved_stats:
			_stats[String(key)] = float(saved_stats[key])
	var saved_unlocked: Variant = data.get("unlocked", [])
	if typeof(saved_unlocked) == TYPE_ARRAY:
		for id in saved_unlocked:
			_unlocked[String(id)] = true
	# Saves from before arena_<n>_clears existed: a recorded best time means a clear
	for key in _stats.keys():
		if key.begins_with("arena_") and key.ends_with("_best_time"):
			var clears_key: String = key.trim_suffix("_best_time") + "_clears"
			if not _stats.has(clears_key):
				_stats[clears_key] = 1.0
	# A goal lowered in a later version unlocks silently for saves that already meet it
	for achievement in achievements:
		if achievement.goal_type == Achievement.GoalType.MANUAL or is_unlocked(achievement.id):
			continue
		if achievement.is_met(get_stat(achievement.stat), has_stat(achievement.stat)):
			_unlocked[String(achievement.id)] = true
	_log_message(["Achievements progress loaded:", _unlocked.keys()])


## Clears all progress (debug).
func reset_progress() -> void:
	_stats.clear()
	_unlocked.clear()
	save_progress()
	progress_changed.emit()


# --- Toast ---------------------------------------------------------------------

func _queue_toast(achievement: Achievement) -> void:
	_toast_queue.append(achievement)
	if not _toast_busy:
		_show_next_toast()


## Builds one toast and puts it where the CRT shader will also process it: inside the
## current scene's UILayer, right before its ColorRect (the CRT overlay reads the screen
## drawn before it). Scenes without that layer get a plain CanvasLayer instead.
func _build_toast() -> void:
	var host: Node = null
	var crt_rect: Node = null
	var scene: Node = get_tree().current_scene
	if scene:
		host = scene.get_node_or_null("UILayer")
		if host:
			crt_rect = host.get_node_or_null("ColorRect")
	if host == null:
		if not is_instance_valid(_toast_layer):
			_toast_layer = CanvasLayer.new()
			add_child(_toast_layer)
		host = _toast_layer

	_toast_panel = PanelContainer.new()
	_toast_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.08, 0.09, 0.92)
	style.border_color = Color(0.0157, 0.855, 1.0)
	style.set_border_width_all(1)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 3
	style.content_margin_bottom = 4
	_toast_panel.add_theme_stylebox_override("panel", style)
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(_toast_panel)
	if crt_rect:
		host.move_child(_toast_panel, crt_rect.get_index())
	# If the scene changes mid-toast the panel is freed with it; go on with the queue
	_toast_panel.tree_exited.connect(_show_next_toast, CONNECT_DEFERRED)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	_toast_panel.add_child(box)

	var header: Label = Label.new()
	header.text = "ACHIEVEMENT UNLOCKED"
	header.label_settings = FontManager.pixel_label_settings(12)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(header)

	_toast_title = Label.new()
	_toast_title.label_settings = FontManager.pixel_label_settings(18)
	_toast_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_toast_title)

	_toast_reward = Label.new()
	var reward_settings: LabelSettings = FontManager.pixel_label_settings(12)
	reward_settings.font_color = Color(0.635, 1.0, 1.0)
	reward_settings.outline_size = 0
	reward_settings.shadow_size = 0
	_toast_reward.label_settings = reward_settings
	_toast_reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_toast_reward)
	_toast_panel.modulate.a = 0.0


func _show_next_toast() -> void:
	if _toast_queue.is_empty():
		_toast_busy = false
		return
	# During a scene change there is no current scene yet; try again next frame
	if get_tree().current_scene == null:
		_show_next_toast.call_deferred()
		return
	if not is_instance_valid(_toast_sound):
		_toast_sound = AudioStreamPlayer.new()
		_toast_sound.stream = TOAST_SOUND
		_toast_sound.bus = &"SFX"
		_toast_sound.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_toast_sound)
	_build_toast()
	_toast_busy = true
	var achievement: Achievement = _toast_queue.pop_front()
	_toast_title.text = achievement.title
	var reward: String = achievement.reward_text()
	_toast_reward.text = (reward + " UNLOCKED") if reward != "" else ""
	_toast_reward.visible = reward != ""
	_toast_panel.reset_size()
	var width: float = _toast_panel.get_combined_minimum_size().x
	var view: Vector2 = get_viewport().get_visible_rect().size
	_toast_panel.position = Vector2(roundf((view.x - width) / 2.0), 8.0)
	_toast_sound.play()

	# Bound to the panel: it dies with it. Freeing the panel triggers the next toast.
	var panel: PanelContainer = _toast_panel
	var tween: Tween = panel.create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.2)
	tween.tween_interval(2.6)
	tween.tween_property(panel, "modulate:a", 0.0, 0.4)
	tween.tween_callback(panel.queue_free)


func _log_message(message) -> void:
	if GameManager.is_debug_text == true:
		var final_string: String = ""
		if typeof(message) == TYPE_ARRAY:
			for arg in message:
				final_string += str(arg) + " "
			final_string = final_string.strip_edges()
		else:
			final_string = str(message)
		print_rich("[color=yellow][DEV LOG][/color] " + final_string)
