extends Node
## Central state manager for the game. Handles global variables such as score,
## current arena phase, debug toggles, and feature flags. Also manages the 
## persistence system (save/load) across different platforms (Web vs Desktop).

#signals
signal score_updated(new_score)
## Points of each add_score() call (ArcadeManager multiplies them into the run score).
signal points_added(points)
signal pause(is_paused)
## Emitted by apply_settings() after a settings panel toggle (the HUD shows/hides the FPS).
signal settings_changed
## Emitted by set_language(): UI that swaps images or builds text in code refreshes.
signal language_changed(language: String)

## Game language: "en" (the default, always on a new save) or "es". Texts are translated
## by Godot's TranslationServer from Localization/es.po (English text = key).
var language: String = "en"
const LANGUAGES: Array[String] = ["en", "es"]

#global variables
## Pilot name typed in the skin selector (local only, saved with the game).
var player_name: String
var score: int = 0
var can_add_score: bool = true
var phase_to_start: int = 1
var deaths_count: int = 0

# Arenas Base Structure
var current_arena_index: int = 0
## Boss checkpoint (saw_boss.gd): the health the boss comes back with after the player dies
## past the middle of its bar; -1 = none. Lives here so it survives the death reload, and
## is cleared when the boss is beaten or a new run / arena starts. Not saved to disk.
var boss_checkpoint_health: int = -1
## The boss of a boss arena is beaten: the arena is played again as normal phases (same
## enemies and values as arcade, but with the main mode's phase retries). Set by
## PhaseManager, survives the reloads; cleared by a new run and by the test room cinematic.
## Not saved to disk.
var post_boss_phases: bool = false
var arena_names: Array[String] = ["Arena 1", "Arena 2", "Arena 3"]
## UI colour of each arena (ArenaUiTint), as a hue rotation in degrees of the original
## cyan/blue UI: arena 1 = 0 (blue), arena 2 = -60 (green), arena 3 = 180 (red).
var arena_ui_hue_shifts: Array[float] = [0.0, -60.0, 180.0]
## Arena indices the player has reached in any mode, sorted and saved (`visited_arenas` in
## save_game.json). Arena 1 (index 0) is always there. main.gd adds its arena on load;
## ArcadeManager only offers arenas listed here.
var visited_arenas: Array[int] = [0]
# --- Feature Flags & Settings ---
var is_shader_animation: bool = false
var is_glitch_sound: bool = false
var game_paused: bool = false
var can_pause: bool = true
var retro_shader_active: bool = true
## Shows the achievements button in the main menu and the "achievement unlocked" toast.
## Progress and ship rewards keep working either way (ship locks live in SkinManager).
var achievements_enabled: bool = true
## Shows the arcade mode button in the main menu.
var arcade_enabled: bool = true
## Shows the shop button in the main menu (see ShopManager).
var shop_enabled: bool = true
## True while an arcade run is being played (an endless arena, see ArcadeManager).
## Set by the arcade button; cleared by the Play button and when the main menu opens.
var arcade_mode_active: bool = false

#this bool validate the shaders optimization in pc
var pc_optimize_shaders: bool = false
## The CRT shader's roll (bands scrolling down the screen), in every scene. Toggled from
## the main menu settings panel; ShaderManager applies it. Lightweight paths never roll.
var crt_roll_enabled: bool = true
## Music and sound effects volume (0-100), saved. MusicPlayer / SfxManager read them on start
## (they load after GameManager) and write them back, and save, on every change, whether
## it comes from the pause menu or the main menu settings panel.
var music_volume_percent: float = 100.0
var sfx_volume_percent: float = 100.0

# mobile compatibility bool
var mobile_mode_active: bool = false
var using_touch_controls: bool = true
var disable_auto_hide_mobile_controls: bool = false # Set to true to test mobile UI on PC with keyboard
var mobile_layout: Dictionary = {}
## In mobile mode, render at the 520x300 base resolution and let the screen upscale it,
## instead of drawing at the phone's native resolution. Set to false to compare.
var mobile_low_res_render: bool = false
# --- Debug & Environment Flags ---
var show_debug: bool = false
var show_debug_menu: bool = false
var show_fps: bool = false

## Forces the game to use Web-mode optimizations (e.g., lightweight shaders).
## Used by web_optimizer.gd.
var force_web_mode: bool = false
#IMPORTANT: this bool change the value to _log_message function in some scripts!
var is_debug_text : bool = false
var is_scroll_active: bool = false

## True if the game is running on HTML5/Web. Disables local file saving for config.
var browser_support: bool = false

## Toggles admin-specific UI options or abilities.
var admin_control: bool = false
var mute_game: bool = false

## Toggles rotational movement vs absolute directional movement.
var relative_control_active: bool = false

# --- Speedrun Tracking ---
var speedrun_mode_active: bool = false
var is_speedrun_running: bool = false
var speedrun_time: float = 0.0

var fps: float = 0.0

const save_path: String = "user://save_game.json"
## Deaths counter lives in its own tiny file so a death only costs one small write
const deaths_path: String = "user://deaths_count.txt"
#windows: %APPDATA%\Godot\app_userdata\ProjectName
#linux: ~/.local/share/godot/app_userdata/ProjectName/
#android/ios: user://

var preloaded_main: PackedScene
var preloaded_tutorial: PackedScene
var preloaded_tutorial_arena2: PackedScene
var preloaded_tutorial_arena3: PackedScene
var preloaded_arena2: PackedScene
var preloaded_arena3: PackedScene

const SHADER_WARMUP_SCRIPT: GDScript = preload("res://Scripts/shader_warmup.gd")
## True once the gameplay shaders were compiled ahead of time (see shader_warmup.gd).
var shader_warmup_done: bool = false

func _ready() -> void:
	randomize()
	process_mode = Node.PROCESS_MODE_ALWAYS
	mute_master_channel()

	# Precarga de escenas masivas para evitar tirones en Web
	_preload_heavy_scenes()
	call_deferred("_start_shader_warmup")

	# Disable Android's default behavior of instantly killing the app on Back button press
	get_tree().quit_on_go_back = false
	
	if OS.has_feature("web"):
		browser_support = true
	load_data()
	# Always English unless the player picked Spanish (not the system's language)
	TranslationServer.set_locale(language)
	# Saves from before the arena tracker: NEW GROUND means arena 2 was already reached
	if AchievementManager.is_unlocked(&"arena_2_reached") and not has_visited_arena(1):
		mark_arena_visited(1)
	# Deaths from before the "die 1000 times" achievement count too (no toast at boot)
	AchievementManager.raise_stat(&"deaths", deaths_count, true)

func _preload_heavy_scenes():
	if browser_support or OS.has_feature("web"):
		_log_message("Preloading heavy scenes for the Web version...")
	else:
		_log_message("Preloading heavy scenes...")
		
	# By keeping these variables alive in the Autoload (GameManager) 
	# Godot keeps them in RAM, making get_tree().change_scene_to_file() instantaneous.
	preloaded_main = load("res://Scenes/main.tscn")
	preloaded_tutorial = load("res://Scenes/tutorial.tscn")
	preloaded_tutorial_arena2 = load("res://Scenes/tutorial_arena2.tscn")
	preloaded_tutorial_arena3 = load("res://Scenes/tutorial_arena3.tscn")
	preloaded_arena2 = load("res://Scenes/arena2.tscn")
	preloaded_arena3 = load("res://Scenes/arena3.tscn")

## Compiles the shaders of the heavy scenes little by little while the splash is shown,
## so the first frame of an arena doesn't freeze the game on low-end GPUs.
func _start_shader_warmup() -> void:
	var warmup = SHADER_WARMUP_SCRIPT.new()
	add_child(warmup)
	warmup.finished.connect(func(): shader_warmup_done = true)
	warmup.run([
		preloaded_tutorial,
		preloaded_main,
		preloaded_tutorial_arena2,
		preloaded_arena2,
		preloaded_tutorial_arena3,
		preloaded_arena3,
		# Spawned from scripts via preload(), so they are not reachable from the scenes above
		load("res://Scenes/laser.tscn"),
		load("res://Scenes/enemy_laser.tscn"),
	])

## Waits until the shader warm-up is done. The timeout is only a safety net so a
## problem in the warm-up can never leave the game stuck in the splash screen.
func wait_for_shader_warmup(timeout_sec: float = 30.0) -> void:
	var deadline: int = Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while not shader_warmup_done and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame

func _process(delta: float) -> void:
	fps = Engine.get_frames_per_second()
	if speedrun_mode_active and is_speedrun_running and not get_tree().paused:
		speedrun_time += delta
		
#speedrun functions
func start_speedrun():
	if speedrun_mode_active:
		is_speedrun_running = true
		
func stop_speedrun():
	is_speedrun_running = false
	
func reset_speedrun():
	speedrun_time = 0.0
	is_speedrun_running = false
	
func get_formatted_speedrun_time() -> String:
	@warning_ignore("integer_division")
	var minutes = int(speedrun_time) / 60
	var seconds = int(speedrun_time) % 60
	var milliseconds = int((speedrun_time - int(speedrun_time)) * 1000)
	return "%02d:%02d.%03d" % [minutes, seconds, milliseconds]
	
#save and load data functions

## Saves the settings and emits settings_changed, so open scenes can react (the HUD shows
## or hides the FPS). Called by the settings panel after every toggle.
func apply_settings() -> void:
	save_data()
	settings_changed.emit()

## Switches the language (settings panel EN/ES button), saves it and tells the UI.
func set_language(new_language: String) -> void:
	if not LANGUAGES.has(new_language):
		return
	language = new_language
	TranslationServer.set_locale(language)
	save_data()
	language_changed.emit(language)

## Serializes and saves game configuration to user://save_game.json.
## On Web builds (browser_support = true), it only saves the player's name
## as local file persistence is not fully supported or is constrained in browsers.
func save_data():
	var data: Dictionary
	if browser_support == true:
		_log_message("Web version: using default values")
		#only save player name in web version
		_log_message("Save ONLY player_name in web version")
		data = {
			"pilot_name": player_name,
			"language": language
		}
		_log_message(["Player name: ", player_name])
	else:
		data = {
			"selected_ship": SkinManager.equipped_ship_index,
			"ship_color1": SkinManager.color1_index,
			"ship_color2": SkinManager.color2_index,
			"controls_mode": relative_control_active,
			"fps_mode": show_fps,
			"speedrun_mode_state": speedrun_mode_active,
			"scroll_bar_state": is_scroll_active,
			"pilot_name": player_name,
			"mobile_layout": mobile_layout,
			"retro_shader_active": retro_shader_active,
			"pc_optimize_shaders": pc_optimize_shaders,
			"crt_roll_enabled": crt_roll_enabled,
			"music_volume": music_volume_percent,
			"sfx_volume": sfx_volume_percent,
			"visited_arenas": visited_arenas,
			"language": language
		}
		_log_message(["saved game!, selected skin", SkinManager.equipped_ship_index])
		_log_message(["Relative controls: ", relative_control_active])
		_log_message(["FPS mode: ", show_fps])
		_log_message(["Speedrun mode state", speedrun_mode_active])
		_log_message(["Scroll bar state", is_scroll_active])
		_log_message(["Retro Shader state", retro_shader_active])
		
	#create the file in path
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		_log_message(["Error al guardar los datos", FileAccess.get_open_error()])
		return
	#convert the dict to json text
	var json_string = JSON.stringify(data)
	file.store_string(json_string)

## Persists only deaths_count to its own file (one write, no read or JSON parse).
## Called on every player death.
func save_deaths_count():
	# web version only persists the pilot name
	if browser_support == true:
		return
	var file = FileAccess.open(deaths_path, FileAccess.WRITE)
	if file == null:
		_log_message(["Error al guardar el contador de muertes", FileAccess.get_open_error()])
		return
	file.store_string(str(deaths_count))

func load_data():
	if FileAccess.file_exists(deaths_path):
		deaths_count = int(FileAccess.get_file_as_string(deaths_path))
		_log_message(["loaded deaths count: ", deaths_count])

	if not FileAccess.file_exists(save_path):
		_log_message("The save file not exists, using default values")
		return
		
	var file = FileAccess.open(save_path, FileAccess.READ)
	var json_string = file.get_as_text()
	var data = JSON.parse_string(json_string)
	
	if data and "selected_ship" in data:
		# Falls back to a default ship if the saved one is locked (see SkinManager.is_ship_unlocked)
		SkinManager.load_equipped_ship(int(data["selected_ship"]))
		_log_message(["Loaded data, selected ship", SkinManager.equipped_ship_index])

	if data and "ship_color1" in data:
		# Falls back to the default colours if a saved one is locked
		SkinManager.load_ship_colors(int(data["ship_color1"]), int(data.get("ship_color2", -1)))
		
	if data and "controls_mode" in data:
		relative_control_active = bool(data["controls_mode"])
		_log_message(["loaded controls user config: ", relative_control_active])
		
	if data and "fps_mode" in data:
		show_fps = bool(data["fps_mode"])
		_log_message(["loaded fps_mode user config: ", show_fps])
		
	if data and "scroll_bar_state" in data:
		is_scroll_active = bool(data["scroll_bar_state"])
		_log_message(["loaded scrollbar state user config: ", is_scroll_active])
		
	if data and "speedrun_mode_state" in data:
		speedrun_mode_active = bool(data["speedrun_mode_state"])
		_log_message(["loaded speedrun mode state user config: ", speedrun_mode_active])
		
	if data and "pilot_name" in data:
		player_name = String(data["pilot_name"])
		_log_message(["Loaded player name: ", player_name])

	if data and "language" in data and LANGUAGES.has(String(data["language"])):
		language = String(data["language"])
		
	if data and "mobile_layout" in data:
		mobile_layout = data["mobile_layout"]
		
	if data and "retro_shader_active" in data:
		retro_shader_active = bool(data["retro_shader_active"])
		_log_message(["loaded retro_shader_active user config: ", retro_shader_active])
	
	if data and "pc_optimize_shaders" in data:
		pc_optimize_shaders = bool(data["pc_optimize_shaders"])
		_log_message(["loaded pc optimize shaders in save data: ", pc_optimize_shaders])

	if data and "crt_roll_enabled" in data:
		crt_roll_enabled = bool(data["crt_roll_enabled"])

	if data and "music_volume" in data:
		music_volume_percent = clampf(float(data["music_volume"]), 0.0, 100.0)
	if data and "sfx_volume" in data:
		sfx_volume_percent = clampf(float(data["sfx_volume"]), 0.0, 100.0)

	if data and "visited_arenas" in data and typeof(data["visited_arenas"]) == TYPE_ARRAY:
		for index in data["visited_arenas"]:
			_add_visited_arena(int(index))
		_log_message(["loaded visited arenas: ", visited_arenas])

	# legacy: older saves kept deaths_count in the global json
	if data and "deaths_count" in data and not FileAccess.file_exists(deaths_path):
		deaths_count = int(data["deaths_count"])
		_log_message(["loaded legacy deaths count: ", deaths_count])

## Records that the player reached this arena (called by main.gd when an arena loads).
## Saves only when the arena is new.
func mark_arena_visited(index: int) -> void:
	if _add_visited_arena(index):
		_log_message(["New arena reached: ", index, visited_arenas])
		save_data()

func has_visited_arena(index: int) -> bool:
	return visited_arenas.has(index)

## Adds the index (kept sorted). Returns true if it was new.
func _add_visited_arena(index: int) -> bool:
	if index < 0 or visited_arenas.has(index):
		return false
	visited_arenas.append(index)
	visited_arenas.sort()
	return true

func save_mobile_layout(node_name: String, pos: Vector2):
	mobile_layout[node_name] = {"x": pos.x, "y": pos.y}

func get_mobile_layout(node_name: String) -> Vector2:
	if node_name in mobile_layout:
		var pos_dict = mobile_layout[node_name]
		return Vector2(pos_dict["x"], pos_dict["y"])
	return Vector2.INF

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and can_pause:
		toggle_pause()

func toggle_pause() -> void:
	get_tree().paused = !get_tree().paused
	pause.emit(get_tree().paused)
	
## Arcade: ignored after stop_scoring() (player death, phase timeout) until reset_score(),
## so a laser still flying after the death can't reach the phase goal and skip the restart
## from phase 1 (the death ends the run). The main mode keeps counting it on purpose: a
## last laser that clears the phase after the death gives the player that chance.
func add_score(points):
	if arcade_mode_active and not can_add_score:
		return
	score += points
	score_updated.emit(score)
	points_added.emit(points)

func stop_scoring() -> void:
	can_add_score = false

func reset_score() -> void:
	score = 0
	can_add_score = true
	score_updated.emit(score)
	
## Internal logging system for development tracking.
## Parses heterogeneous input messages (Strings, Arrays, mixed types) into a single 
## standardized String to prevent crashes and ensure clean console output.
## Only prints when `is_debug_text` is active in the environment.
func _log_message(message):
	if is_debug_text == true:
		var final_string = ""
		if typeof(message) == TYPE_ARRAY:
			for arg in message:
				final_string += str(arg) + " "
			final_string = final_string.strip_edges()
		else:
			final_string = str(message)
		print_rich("[color=yellow][DEV LOG][/color] " + final_string)
	else:
		return

#global shader animation (apply to scenes)
func play_glitch_effect(crt_material):
	var tween = create_tween()
	
	if mobile_mode_active or OS.has_feature("mobile") or OS.has_feature("web"):
		# EXTREME OPTIMIZATION: Keep low_quality enabled, just flick the aberration smoothly.
		# The shader has been optimized to only shift the screen, avoiding 3-pass RGB lookups.
		tween.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(crt_material, "shader_parameter/aberration", 0.5, 0.1)
		tween.chain().tween_property(crt_material, "shader_parameter/aberration", -0.5, 0.1)
		tween.chain().tween_property(crt_material, "shader_parameter/aberration", 0.01, 0.1)
	else:
		tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
		tween.parallel().tween_property(crt_material, "shader_parameter/distort_intensity", 0.1, 0.1)
		tween.parallel().tween_property(crt_material, "shader_parameter/static_noise_intensity", 0.1, 0.1)
		tween.chain().tween_property(crt_material, "shader_parameter/aberration", 1.0, 0.1)
		tween.chain().tween_property(crt_material, "shader_parameter/aberration", -1.0, 0.1)
		tween.chain().tween_property(crt_material, "shader_parameter/aberration", 0.01, 0.1)
		tween.parallel().tween_property(crt_material, "shader_parameter/distort_intensity", 0.01, 0.1)
		tween.parallel().tween_property(crt_material, "shader_parameter/static_noise_intensity", 0.01, 0.1)

	return tween
	
func play_glitch_sound(glitch_sound):
	glitch_sound.play()
	
## Hue rotation for the current arena's UI (0 when the arena has none listed).
func get_arena_ui_hue_shift() -> float:
	if current_arena_index < 0 or current_arena_index >= arena_ui_hue_shifts.size():
		return 0.0
	return arena_ui_hue_shifts[current_arena_index]

func reset_game_state():
	_log_message("Game Manager: Restart Game State...")
	phase_to_start = 1
	# A new run starts from arena 1 (the tutorial doesn't set the index itself)
	current_arena_index = 0
	arcade_mode_active = false
	boss_checkpoint_health = -1
	post_boss_phases = false
	reset_score()

var _transition_layer: CanvasLayer
var _transition_rect: TextureRect

func freeze_frame():
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	var tex = ImageTexture.create_from_image(img)
	
	if not is_instance_valid(_transition_layer):
		_transition_layer = CanvasLayer.new()
		_transition_layer.layer = 100
		add_child(_transition_layer)
		
		_transition_rect = TextureRect.new()
		_transition_layer.add_child(_transition_rect)
		
	_transition_rect.texture = tex
	_transition_layer.show()

func unfreeze_frame():
	if is_instance_valid(_transition_layer):
		_transition_layer.hide()
		
func mute_master_channel():
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), mute_game)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# If we are in a playable scene, toggle pause instead of quitting
		var current_scene = get_tree().current_scene
		if current_scene and current_scene.name in ["Main", "Tutorial", "Arena2"]:
			if can_pause:
				toggle_pause()
		else:
			# If we are in a menu, quit gracefully
			get_tree().quit()
