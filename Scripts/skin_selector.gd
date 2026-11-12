extends Control

# Colour picker layout (520x300); the picker sits under the ship name
const COLOR_PANEL_POS: Vector2 = Vector2(182, 217)
const SWATCH_SIZE: float = 11.0
const SWATCH_STEP: float = 13.0
const GRID_OFFSET_X: float = 52.0
const PANEL_DARK: Color = Color(0.03, 0.08, 0.09)
const PANEL_ACTIVE: Color = Color(0.02, 0.33, 0.38)
const PANEL_CYAN: Color = Color(0.0157, 0.855, 1.0)
const LOCK_COLOR: Color = Color(0.75, 0.85, 0.85)

var back_scene: String = "res://Scenes/main_menu.tscn"
## Easter-egg chat (predefined replies). Its button hides in a corner of the panel.
@export var chat_console_scene: PackedScene
## Opacity of the chat button while the mouse isn't over it (barely visible on purpose).
const CHAT_BUTTON_IDLE_ALPHA: float = 0.3

@onready var back_button: TextureButton = $BackButton
@onready var right_button: TextureButton = $NextButton
@onready var ship_preview: TextureRect = $ShipPreview
## Padlock that covers locked ships (no spoilers of the sprite)
@onready var lock_icon: TextureRect = $LockIcon
@onready var left_button: TextureButton = $PreviousButton
@onready var ship_name_label: Label = $ShipNameLabel
@onready var ship_author_label: Label = $ShipAuthorLabel

@onready var button_sound: AudioStreamPlayer = $ButtonSound

@onready var name_line_edit: LineEdit = $HBoxContainer/NameLineEdit
@onready var submit_button: Button = $SubmitButton

@onready var system_warning_label: Label = $SystemMessage
@onready var chat_button: TextureButton = get_node_or_null("ChatConsoleButton")

var message_tween: Tween
var original_positions = {}

# --- Colour picker (Geometry Dash style, see SkinManager ship colours) ---
## Layer being edited: 1 = body, 2 = details.
var _color_layer: int = 1
var _color_tabs: Array[Control] = []
var _swatches: Array[Control] = [] # index = palette index

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GameManager.can_pause = false
	system_warning_label.visible = false
	back_button.pressed.connect(_on_back_button_pressed)
	left_button.pressed.connect(_on_left_button_pressed)
	right_button.pressed.connect(_on_right_button_pressed)
	SkinManager.ship_selection_changed.connect(_on_ship_selection_changed)
	_on_ship_selection_changed(SkinManager.get_selected_ship_data()) # Replace with function body.
	# Built before _save_original_positions so mobile re-centring moves it too
	_build_color_panel()
	SkinManager.ship_colors_changed.connect(_on_ship_colors_changed)
	_setup_chat_button()

	# The saved pilot name (local only)
	name_line_edit.text = GameManager.player_name

	if GameManager.mobile_mode_active:
		_save_original_positions()
		get_tree().root.size_changed.connect(_on_window_resized)
		_on_window_resized()

func _save_original_positions() -> void:
	for child in get_children():
		if "position" in child:
			# Ignore the background so it can stretch naturally
			if child.name == "SkinPanel":
				continue
			original_positions[child] = child.position

func _on_window_resized() -> void:
	# The original menu is designed for 520x300 (Center = 260)
	var current_center_x = get_viewport().get_visible_rect().size.x / 2.0
	var offset_x = current_center_x - 260.0
	
	for child in original_positions.keys():
		if is_instance_valid(child):
			child.position.x = original_positions[child].x + offset_x
	
func _on_ship_selection_changed(ship_data: Dictionary):
	ship_preview.texture = ship_data["texture"]
	var index: int = SkinManager.selected_ship_index
	SkinManager.apply_ship_colors(ship_preview, index)
	var locked: bool = SkinManager.is_ship_locked(index)
	# Locked ships stay hidden behind the padlock
	ship_preview.visible = not locked
	lock_icon.visible = locked
	if locked:
		ship_name_label.text = "???"
		# Achievement ships say which achievement; ships reserved for future achievements
		# stay a mystery; the rest come from the shop
		var achievement: Achievement = AchievementManager.get_achievement_for_ship(index)
		if achievement and achievement.hidden:
			# Secret achievements don't spoil their name
			ship_author_label.text = "Get: ???"
		elif achievement:
			ship_author_label.text = "Get: " + achievement.title
		elif ShopManager.is_ship_reserved(index):
			ship_author_label.text = "Get: ???"
		else:
			ship_author_label.text = "Get: SHOP"
	else:
		ship_name_label.text = ship_data["name"]
		ship_author_label.text = "By: " + ship_data["author"]
	
# --- Colour picker ---------------------------------------------------------------

func _build_color_panel() -> void:
	var panel: Control = Control.new()
	panel.name = "ColorPanel"
	panel.position = COLOR_PANEL_POS
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	# COL 1 / COL 2 tabs, each with a chip of its current colour
	for layer in [1, 2]:
		var tab: Control = _make_box(panel, Vector2(0, (layer - 1) * 18), Vector2(46, 14))
		_make_rect(tab, "Bg", Vector2.ZERO, tab.size, PANEL_DARK)
		_make_rect(tab, "ChipBorder", Vector2(2, 2), Vector2(10, 10), Color.BLACK)
		_make_rect(tab, "Chip", Vector2(3, 3), Vector2(8, 8), Color.WHITE)
		var label: Label = Label.new()
		label.text = "COL %d" % layer
		label.label_settings = FontManager.pixel_label_settings(12)
		label.position = Vector2(15, 0)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tab.add_child(label)
		tab.gui_input.connect(_on_color_tab_input.bind(layer))
		tab.mouse_entered.connect(button_sound.play)
		_color_tabs.append(tab)

	# Palette grid
	var palette: ShipColorPalette = SkinManager.PALETTE
	var columns: int = maxi(palette.columns, 1)
	for index in palette.size():
		@warning_ignore("integer_division")
		var cell: Vector2 = Vector2(index % columns, index / columns) * SWATCH_STEP
		var swatch: Control = _make_box(panel, Vector2(GRID_OFFSET_X, 0) + cell,
				Vector2(SWATCH_SIZE, SWATCH_SIZE))
		_make_rect(swatch, "Border", Vector2.ZERO, swatch.size, PANEL_DARK)
		_make_rect(swatch, "Fill", Vector2.ONE, swatch.size - Vector2(2, 2), Color.WHITE)
		var lock: Control = Control.new()
		lock.name = "Lock"
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		swatch.add_child(lock)
		# 5x5 pixel padlock in the middle of the swatch
		_make_rect(lock, "", Vector2(4, 2), Vector2(3, 1), LOCK_COLOR)
		_make_rect(lock, "", Vector2(3, 3), Vector2(1, 2), LOCK_COLOR)
		_make_rect(lock, "", Vector2(7, 3), Vector2(1, 2), LOCK_COLOR)
		_make_rect(lock, "", Vector2(3, 5), Vector2(5, 4), LOCK_COLOR)
		swatch.gui_input.connect(_on_swatch_input.bind(index))
		_swatches.append(swatch)
	_refresh_color_panel()


func _make_box(parent: Control, pos: Vector2, box_size: Vector2) -> Control:
	var box: Control = Control.new()
	box.position = pos
	box.size = box_size
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(box)
	return box


func _make_rect(parent: Control, rect_name: String, pos: Vector2, rect_size: Vector2,
		color: Color) -> ColorRect:
	var rect: ColorRect = ColorRect.new()
	if rect_name != "":
		rect.name = rect_name
	rect.position = pos
	rect.size = rect_size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect


## Tabs show the active layer; swatch borders show the picked colours
## (white = this layer, cyan = the other one); locked colours are dimmed with a padlock.
func _refresh_color_panel() -> void:
	for i in _color_tabs.size():
		var layer: int = i + 1
		var tab: Control = _color_tabs[i]
		var tab_color: Color = PANEL_ACTIVE if layer == _color_layer else PANEL_DARK
		(tab.get_node("Bg") as ColorRect).color = tab_color
		var chip_color: Color = SkinManager.get_color(SkinManager.get_ship_color_index(layer))
		(tab.get_node("Chip") as ColorRect).color = chip_color
	var current: int = SkinManager.get_ship_color_index(_color_layer)
	var other: int = SkinManager.get_ship_color_index(2 if _color_layer == 1 else 1)
	for index in _swatches.size():
		var swatch: Control = _swatches[index]
		var unlocked: bool = SkinManager.is_color_unlocked(index)
		var color: Color = SkinManager.get_color(index)
		(swatch.get_node("Fill") as ColorRect).color = color if unlocked else color.darkened(0.65)
		swatch.get_node("Lock").visible = not unlocked
		var border: Color = PANEL_DARK
		if index == current:
			border = Color.WHITE
		elif index == other:
			border = PANEL_CYAN
		(swatch.get_node("Border") as ColorRect).color = border


func _on_color_tab_input(event: InputEvent, layer: int) -> void:
	if _is_click(event) and layer != _color_layer:
		_color_layer = layer
		button_sound.play()
		_refresh_color_panel()


func _on_swatch_input(event: InputEvent, index: int) -> void:
	if not _is_click(event):
		return
	if SkinManager.set_ship_color(_color_layer, index):
		button_sound.play()
		GameManager.save_data()
	else:
		# Locked: colours are sold in the shop
		_show_animated_warning_message("GET IT IN THE SHOP!")


func _on_ship_colors_changed() -> void:
	SkinManager.apply_ship_colors(ship_preview, SkinManager.selected_ship_index)
	_refresh_color_panel()


func _is_click(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.pressed \
		and event.button_index == MOUSE_BUTTON_LEFT


func _on_name_line_edit_text_submitted(new_text: String) -> void:
	_register_pilot(new_text) # Replace with function body.

func _on_submit_button_pressed() -> void:
	if name_line_edit.editable == false:
		return
	_register_pilot(name_line_edit.text) # Replace with function body.
	
func _register_pilot(entered_text: String):
	var final_name = entered_text.strip_edges()
	
	if final_name.is_empty():
		_log_message("The user name cant be empty")
		return
		
	GameManager.player_name = final_name
	GameManager.save_data()
	name_line_edit.release_focus()
	_log_message(["Pilot name saved: ", final_name])
	_show_animated_warning_message("NAME SAVED!")
	
func _input(event: InputEvent) -> void:
	if name_line_edit.has_focus():
		return
		
	if event.is_action_pressed("pause"):
		_on_back_button_pressed()
	elif event.is_action_pressed("Move_Left"):
		_on_left_button_pressed()
	elif event.is_action_pressed("Move_Right"):
		_on_right_button_pressed()
	
func _on_back_button_pressed():
	SkinManager.restore_equipped_ship()
	get_tree().change_scene_to_file(back_scene)
	
## Half-hidden easter-egg button: faint until the mouse finds it (no keyboard focus).
func _setup_chat_button() -> void:
	if not is_instance_valid(chat_button):
		return
	chat_button.modulate.a = CHAT_BUTTON_IDLE_ALPHA
	chat_button.mouse_entered.connect(func():
		button_sound.play()
		_fade_chat_button(1.0)
	)
	chat_button.mouse_exited.connect(_fade_chat_button.bind(CHAT_BUTTON_IDLE_ALPHA))
	chat_button.pressed.connect(_on_chat_button_pressed)

func _fade_chat_button(alpha: float) -> void:
	var tween: Tween = chat_button.create_tween()
	tween.tween_property(chat_button, "modulate:a", alpha, 0.2).set_trans(Tween.TRANS_SINE)

func _on_chat_button_pressed() -> void:
	if chat_console_scene == null:
		return
	# Leaving the selector puts back the equipped ship, like the back button
	SkinManager.restore_equipped_ship()
	get_tree().change_scene_to_packed(chat_console_scene)

func _on_left_button_pressed():
	SkinManager.select_previous_ship()
	button_sound.play()
	GameManager.save_data()
	
func _on_right_button_pressed():
	SkinManager.select_next_ship()
	button_sound.play()
	GameManager.save_data()

func _on_back_button_mouse_entered() -> void:
	button_sound.play() # Replace with function body.
	
func _show_animated_warning_message(text_msg: String) -> void:
	system_warning_label.text = text_msg
	system_warning_label.visible = true
	system_warning_label.modulate.a = 0.0 
	
	if message_tween and message_tween.is_valid():
		message_tween.kill()
		
	message_tween = create_tween()
	message_tween.tween_property(system_warning_label, "modulate:a", 1.0, 0.5)
	message_tween.tween_interval(2.5)
	message_tween.tween_property(system_warning_label, "modulate:a", 0.0, 1.0)
	message_tween.tween_callback(func(): system_warning_label.visible = false)
	
func _log_message(message):
	if GameManager.is_debug_text == true:
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
