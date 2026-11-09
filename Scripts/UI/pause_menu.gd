extends CanvasLayer
## Pause menu shared by every playable scene (arenas and tutorials): a terminal-style
## list ("> resume / settings / quit") over the dimmed game, the deaths counter and the
## same SettingsPanel as the main menu (opened next to the list by "settings").
##
## GameManager.toggle_pause() (Esc / the HUD pause button) shows and hides it through
## GameManager.pause. Keyboard or gamepad move the selection (ui_up / ui_down, wrapping)
## and ui_accept picks; the mouse moves the selection too, so the ">" only ever marks one
## row. While the settings panel is open the three rows are disabled (and dimmed); Esc or
## a click outside the panel closes it, and the rows come back on the next frame.
## Process mode ALWAYS: it works while the tree is paused.

## Text colours of each arena (set per scene with `palette`). Same style as the HUD
## labels: dark fill and bright outline (arena 2 uses the HUD's green outline), plus a
## glow in the outline colour.
enum Palette { BLUE, GREEN, RED }

const MENU_PATH: String = "res://Scenes/main_menu.tscn"
const PALETTES: Dictionary = {
	Palette.BLUE: {
		"fill": Color(0, 0.102, 0.102),
		"outline": Color(0, 1, 1),
		"dim": Color(0, 0.42, 0.46),
		"skull": Color(1, 1, 1),
	},
	Palette.GREEN: {
		"fill": Color(0, 0.102, 0.04),
		"outline": Color(0, 1, 0.373),
		"dim": Color(0, 0.42, 0.16),
		"skull": Color(0.45, 1, 0.55),
	},
	Palette.RED: {
		"fill": Color(0.102, 0, 0.02),
		"outline": Color(1, 0.13, 0.25),
		"dim": Color(0.46, 0.04, 0.1),
		"skull": Color(1, 0.55, 0.6),
	},
}
## Outline width of the texts (the HUD labels use 2).
const OUTLINE_SIZE: int = 2
## Glow: a centred, blurred shadow in the outline colour behind every text
## (LabelSettings shadow with no offset). Selected row / other rows / header and counter.
## With the pixel font the glow has a hard edge, so a big size reads as a thick outline.
const GLOW_SELECTED: Dictionary = {"size": 4, "alpha": 0.45}
const GLOW_IDLE: Dictionary = {"size": 3, "alpha": 0.15}
const GLOW_INFO: Dictionary = {"size": 6, "alpha": 0.35}
## How much the selected row's fill lightens towards the outline colour.
const SELECTED_FILL_LIGHTEN: float = 0.18

## Scene "quit" goes to. Empty = the main menu by path.
@export var menu_scene: PackedScene
## Colours of this scene's pause menu: BLUE in arena 1 and its tutorial, GREEN in arena 2
## and its tutorial, RED in arena 3 (set on the PauseMenu instance of each scene).
@export var palette: Palette = Palette.BLUE

var _buttons: Array[Button] = []
## Quit was pressed: the scene change is pending.
var _quitting: bool = false

@onready var resume_button: Button = %ResumeButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton
@onready var settings_panel: SettingsPanel = %SettingsPanel
@onready var deaths_label: Label = $skullIcon/Label
@onready var skull_icon: Sprite2D = $skullIcon
@onready var header_label: Label = %Header
@onready var hover_sound: AudioStreamPlayer = $HoverSound
@onready var select_sound: AudioStreamPlayer = $SelectSound
## The list's container (no background, only margins); dimmed while the settings panel is open.
@onready var menu_plate: Control = $Root/Center/Layout/MenuPlate


func _ready() -> void:
	hide()
	_buttons = [resume_button, settings_button, quit_button]
	var colors: Dictionary = PALETTES[palette]
	var font_source: LabelSettings = resume_button.get_parent().get_node("Arrow").label_settings
	# Selected row: bright outline, lighter fill, strong glow. Other rows: dim and faint
	var selected_style: LabelSettings = _text_style(font_source,
			colors["fill"].lerp(colors["outline"], SELECTED_FILL_LIGHTEN), colors["outline"],
			GLOW_SELECTED)
	var idle_style: LabelSettings = _text_style(font_source, colors["fill"], colors["dim"],
			GLOW_IDLE)
	_style_labels(colors, selected_style)
	for i in _buttons.size():
		var button: Button = _buttons[i]
		var arrow: Label = button.get_parent().get_node("Arrow")
		arrow.modulate.a = 0.0
		var text_label: Label = _make_text_label(button, idle_style)
		# The selected row shows the ">" and glows; the arrow keeps its width, so the
		# text doesn't move
		button.focus_entered.connect(func():
			arrow.modulate.a = 1.0
			text_label.label_settings = selected_style
			hover_sound.play()
		)
		button.focus_exited.connect(func():
			arrow.modulate.a = 0.0
			text_label.label_settings = idle_style
		)
		# The mouse selects too, so there is a single highlighted row (not while the
		# buttons are disabled by the open settings panel)
		button.mouse_entered.connect(func():
			if not button.disabled:
				button.grab_focus()
		)
		# Up/down wrap around the list
		var previous: Button = _buttons[(i - 1 + _buttons.size()) % _buttons.size()]
		var next: Button = _buttons[(i + 1) % _buttons.size()]
		button.focus_neighbor_top = button.get_path_to(previous)
		button.focus_neighbor_bottom = button.get_path_to(next)
		button.focus_neighbor_left = button.get_path()
		button.focus_neighbor_right = button.get_path()

	resume_button.pressed.connect(_on_resume_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	GameManager.pause.connect(_on_pause_toggled)


## A Button can't draw a shadow (glow) under its text, so the button's text moves to a
## Label child; the button stays as is for focus, clicks and keyboard.
func _make_text_label(button: Button, style: LabelSettings) -> Label:
	var label: Label = Label.new()
	label.text = button.text
	label.label_settings = style
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.text = ""
	button.add_child(label)
	button.custom_minimum_size = label.get_combined_minimum_size()
	return label


## Header, arrows and deaths counter: like the HUD labels (dark fill, bright outline), with
## the glow. The arrows share the selected row's style (they only show on that row).
func _style_labels(colors: Dictionary, selected_style: LabelSettings) -> void:
	for button in _buttons:
		button.get_parent().get_node("Arrow").label_settings = selected_style
	header_label.label_settings = _text_style(header_label.label_settings, colors["fill"],
			colors["outline"], GLOW_INFO)
	deaths_label.label_settings = _text_style(deaths_label.label_settings, colors["fill"],
			colors["outline"], GLOW_INFO)
	skull_icon.modulate = colors["skull"]


## Copy of `source` (font and size) with the given fill, outline and glow. Copies, so the
## scene's shared LabelSettings stay untouched.
func _text_style(source: LabelSettings, fill: Color, outline: Color, glow: Dictionary) -> LabelSettings:
	var settings: LabelSettings = source.duplicate()
	settings.font_color = fill
	settings.outline_size = OUTLINE_SIZE
	settings.outline_color = outline
	settings.shadow_size = int(glow["size"])
	settings.shadow_offset = Vector2.ZERO
	settings.shadow_color = Color(outline, float(glow["alpha"]))
	return settings


func _on_pause_toggled(is_paused: bool) -> void:
	# Quit already pressed: the scene is on its way out (it leaves the tree at the end of the
	# frame), there is nothing to show or focus
	if _quitting or not is_inside_tree():
		return
	# Every pause starts with the panel closed and the list usable
	settings_panel.visible = false
	_set_buttons_enabled(true)
	if not is_paused:
		hide()
		return
	deaths_label.text = str(GameManager.deaths_count)
	show()
	resume_button.grab_focus()


func _input(event: InputEvent) -> void:
	if not visible or not settings_panel.visible:
		return
	# Esc closes the settings first (before GameManager unpauses: scene nodes get input
	# before the autoloads)
	if event.is_action_pressed("pause"):
		_close_settings()
		select_sound.play()
		get_viewport().set_input_as_handled()
		return
	# A click/touch outside the panel only closes it: the event is consumed, so it can't
	# also press the row under it
	if _is_press(event) and not settings_panel.get_global_rect().has_point(event.position):
		_close_settings()
		get_viewport().set_input_as_handled()


func _on_resume_pressed() -> void:
	select_sound.play()
	GameManager.toggle_pause()


## Opens the settings panel. The list is disabled while it's open (see _close_settings).
func _on_settings_pressed() -> void:
	select_sound.play()
	settings_panel.sync_with_settings()
	settings_panel.visible = true
	_set_buttons_enabled(false)


## Closes the panel (Esc or a click outside). The rows come back on the next frame, so
## the same click, or the mouse click a phone emulates after a touch, can't press one.
func _close_settings() -> void:
	settings_panel.visible = false
	_restore_buttons.call_deferred()


func _restore_buttons() -> void:
	if _quitting or not is_inside_tree() or settings_panel.visible or not visible:
		return
	_set_buttons_enabled(true)
	settings_button.grab_focus()


## While disabled the rows can't be clicked, focused or picked with the keyboard, and the
## list is dimmed so it reads as inactive.
func _set_buttons_enabled(enabled: bool) -> void:
	menu_plate.modulate.a = 1.0 if enabled else 0.45
	for button in _buttons:
		if not enabled:
			button.release_focus()
		button.disabled = not enabled
		button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE


## Back to the main menu, leaving the arena clean (time scale, shader, entity colours),
## like the old pause menu did.
func _on_quit_pressed() -> void:
	# A second press (or an Esc) before the scene change lands must not quit or pause again:
	# pausing now would leave the tree paused on the way to the menu
	if _quitting:
		return
	_quitting = true
	GameManager.can_pause = false
	_set_buttons_enabled(false)
	select_sound.play()
	get_tree().paused = false
	var scene: Node = get_parent()
	if scene and scene.has_method("reset_shader_parameters"):
		scene.reset_shader_parameters()
	for group in ["asteroides", "enemigos", "enemy_laser", "saws"]:
		for node in get_tree().get_nodes_in_group(group):
			if is_instance_valid(node) and node is CanvasItem:
				node.modulate = Color.WHITE
	if menu_scene:
		get_tree().change_scene_to_packed(menu_scene)
	else:
		get_tree().change_scene_to_file(MENU_PATH)


func _is_press(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	return event is InputEventScreenTouch and event.pressed
