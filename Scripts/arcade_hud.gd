extends Control
## Arcade mode HUD, a child of the HUD: run score, multiplier with its combo bar, the
## diamonds wallet, and a summary of the previous run after a death. Hidden outside
## arcade mode. The nodes are built in code; tweak the layout through the exports.

const DIAMOND_TEXTURE: Texture2D = preload("res://Assets/Sprites/Arcade/diamond.png")
const DIAMOND_SOUND: AudioStream = preload(
	"res://Assets/Audio/171696__nenadsimic__picked-coin-echo.wav"
)
const TEXT_DARK: Color = Color(0, 0.1457, 0.1457)
const CYAN: Color = Color(0, 1, 1)
const LIGHT: Color = Color(0.635, 1.0, 1.0)
const DIM: Color = Color(0.553, 0.706, 0.682)
const PINK: Color = Color(1.0, 0.184, 0.69)
const PINK_DARK: Color = Color(0.165, 0.05, 0.14)
const PINK_SHADOW: Color = Color(0.32, 0.02, 0.2)

## Distance from the HUD's top-right corner to the panel's top-right corner
## (x = 30 lines it up with the score label).
@export var panel_offset: Vector2 = Vector2(30, 52)
@export var panel_width: float = 120.0
@export var combo_bar_width: float = 44.0
## Seconds the previous run's summary stays on screen.
@export var results_time: float = 3.0
## Vertical shift of the summary from the screen centre (negative = up).
@export var results_offset_y: float = -45.0

var _total_label: Label
var _mult_label: Label
var _mult_settings: LabelSettings
var _combo_fill: ColorRect
var _diamond_icon: TextureRect
var _diamond_label: Label
var _sound: AudioStreamPlayer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not GameManager.arcade_mode_active:
		hide()
		set_process(false)
		return
	_build_panel()
	ArcadeManager.run_score_changed.connect(_on_run_score_changed)
	ArcadeManager.multiplier_changed.connect(_on_multiplier_changed)
	ArcadeManager.diamonds_earned.connect(_on_diamonds_earned)
	_on_run_score_changed(ArcadeManager.run_score)
	_on_multiplier_changed(ArcadeManager.multiplier)
	_diamond_label.text = str(CurrencyManager.diamonds)
	_show_results(ArcadeManager.take_last_results())


func _process(_delta: float) -> void:
	_combo_fill.size.x = roundf(combo_bar_width * ArcadeManager.get_combo_ratio())


# --- Panel ---------------------------------------------------------------------

func _build_panel() -> void:
	var panel: VBoxContainer = VBoxContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_constant_override("separation", 0)
	# Anchored to the top-right corner so it follows the score label on wide screens
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -panel_offset.x - panel_width
	panel.offset_right = -panel_offset.x
	panel.offset_top = panel_offset.y
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(panel)

	var total_row: HBoxContainer = _row(panel)
	total_row.add_child(_label("TOTAL", 10, Color.TRANSPARENT, DIM))
	_total_label = _label("0", 16, CYAN)
	total_row.add_child(_total_label)

	var mult_row: HBoxContainer = _row(panel)
	_mult_label = _label("x1", 22, PINK, PINK_DARK)
	_mult_settings = _mult_label.label_settings
	_mult_settings.shadow_color = PINK_SHADOW
	mult_row.add_child(_mult_label)

	# Combo bar: drains while no kill keeps the multiplier going
	var bar_row: HBoxContainer = _row(panel)
	var bar: ColorRect = ColorRect.new()
	bar.custom_minimum_size = Vector2(combo_bar_width, 3)
	bar.color = Color(0.03, 0.08, 0.09, 0.85)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_row.add_child(bar)
	_combo_fill = ColorRect.new()
	_combo_fill.color = PINK
	_combo_fill.size = Vector2(0, 3)
	_combo_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(_combo_fill)

	var diamond_row: HBoxContainer = _row(panel)
	diamond_row.add_theme_constant_override("separation", 3)
	_diamond_icon = TextureRect.new()
	_diamond_icon.texture = DIAMOND_TEXTURE
	_diamond_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_diamond_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	diamond_row.add_child(_diamond_icon)
	_diamond_label = _label("0", 16, CYAN)
	diamond_row.add_child(_diamond_label)

	_sound = AudioStreamPlayer.new()
	_sound.stream = DIAMOND_SOUND
	_sound.bus = &"SFX"
	_sound.pitch_scale = 1.3
	add_child(_sound)


func _row(parent: Control) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	return row


## Pixel label. A transparent outline gives a flat label (no outline, no shadow).
func _label(text: String, font_size: int, outline: Color, fill: Color = TEXT_DARK) -> Label:
	var label: Label = Label.new()
	var settings: LabelSettings = FontManager.pixel_label_settings(font_size)
	settings.font_color = fill
	if outline.a == 0.0:
		settings.outline_size = 0
		settings.shadow_size = 0
	else:
		settings.outline_color = outline
	label.label_settings = settings
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _pop(node: Control, peak: float = 1.35) -> void:
	node.pivot_offset = node.size / 2.0
	var tween: Tween = node.create_tween()
	tween.tween_property(node, "scale", Vector2(peak, peak), 0.07)
	tween.tween_property(node, "scale", Vector2.ONE, 0.12)


# --- Signals ---------------------------------------------------------------------

func _on_run_score_changed(run_score: int) -> void:
	_total_label.text = str(run_score)


func _on_multiplier_changed(multiplier: int) -> void:
	_mult_label.text = "x" + str(multiplier)
	# x1 stays quiet; any real multiplier lights up pink
	_mult_settings.outline_color = PINK if multiplier > 1 else DIM
	_mult_label.modulate.a = 1.0 if multiplier > 1 else 0.7
	if multiplier > 1:
		_pop(_mult_label, 1.5)


func _on_diamonds_earned(amount: int, _run_diamonds: int) -> void:
	_diamond_label.text = str(CurrencyManager.diamonds)
	_pop(_diamond_icon, 1.6)
	_pop(_diamond_label)
	_sound.play()
	# Floating "+N" over the counter
	var plus: Label = _label("+" + str(amount), 14, CYAN)
	add_child(plus)
	plus.global_position = _diamond_label.global_position + Vector2(-6, -12)
	var tween: Tween = plus.create_tween()
	tween.tween_property(plus, "position:y", plus.position.y - 10.0, 0.6)
	tween.parallel().tween_property(plus, "modulate:a", 0.0, 0.6).set_delay(0.2)
	tween.tween_callback(plus.queue_free)


# --- Previous run summary ------------------------------------------------------------

func _show_results(results: Dictionary) -> void:
	if results.is_empty():
		return
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.08, 0.09, 0.92)
	style.border_color = Color(0.0157, 0.855, 1.0)
	style.set_border_width_all(1)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 3
	style.content_margin_bottom = 5
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	panel.add_child(box)
	box.add_child(_centered(_label("RUN OVER", 20, CYAN)))
	var phase_text: String = "PHASE %d   SCORE %d" % [int(results["phase"]), int(results["score"])]
	box.add_child(_centered(_label(phase_text, 12, Color.TRANSPARENT, LIGHT)))
	if results["new_best"]:
		box.add_child(_centered(_label("NEW BEST!", 14, PINK, PINK_DARK)))
	else:
		var best_text: String = "BEST %d" % int(results["best_score"])
		box.add_child(_centered(_label(best_text, 12, Color.TRANSPARENT, DIM)))

	var reward_row: HBoxContainer = HBoxContainer.new()
	reward_row.alignment = BoxContainer.ALIGNMENT_CENTER
	reward_row.add_theme_constant_override("separation", 3)
	reward_row.add_child(_label("+" + str(int(results["diamonds"])), 16, CYAN))
	var icon: TextureRect = TextureRect.new()
	icon.texture = DIAMOND_TEXTURE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	reward_row.add_child(icon)
	box.add_child(reward_row)

	# Centred on the screen (the HUD itself is shifted inside the arena's UILayer)
	panel.reset_size()
	var view: Vector2 = get_viewport().get_visible_rect().size
	var top_left: Vector2 = (view - panel.size) / 2.0 + Vector2(0, results_offset_y)
	panel.global_position = top_left.round()

	panel.modulate.a = 0.0
	var tween: Tween = panel.create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.25)
	tween.tween_interval(results_time)
	tween.tween_property(panel, "modulate:a", 0.0, 0.5)
	tween.tween_callback(panel.queue_free)


func _centered(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label
