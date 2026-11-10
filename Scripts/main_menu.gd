extends Control

@export var scroll_speed: float = 20.0
@export var next_scene: PackedScene
@export var skin_selector_scene: PackedScene
@export var achievements_scene: PackedScene
@export var shop_scene: PackedScene

@onready var browser_support: bool = GameManager.browser_support
@onready var is_debug_text: bool = GameManager.is_debug_text

@onready var animated_background: AnimatedSprite2D = $Background
@onready var button_sound: AudioStreamPlayer = $ButtonSound
@onready var back_sound: AudioStreamPlayer = $BackSound

@onready var credits_panel: Control = $CreditsPanel
@onready var special_thanks_panel: Control = $SpecialThanksPanel

@onready var play_mode_arrow: TextureButton = get_node_or_null("PlayModeArrow")
@onready var play_mode_panel: Control = get_node_or_null("PlayModePanel")

# Arcade arena picker: built in code beside the play-mode panel, only when more than one
# arena can be played in arcade mode (arenas the player has reached, see ArcadeManager).
# It lives inside the (scaled) panel, so these are panel units. Its height is always the
# mode panel's: the arena buttons share it, and the preview fills it.
const ARENA_PICKER_MARGIN: int = 2
const ARENA_PICKER_SEPARATION: int = 2
const ARENA_BUTTON_WIDTH: float = 40.0
const ARENA_BUTTON_FONT_SIZE: int = 10
## Pixels of the preview image per panel unit (the panel is drawn at ~1.83x).
const ARENA_PREVIEW_PIXEL_SCALE: int = 2
const ARENA_BUTTON_BG: Color = Color(0.0, 0.12, 0.13)
const ARENA_BUTTON_BG_HOVER: Color = Color(0.0, 0.3, 0.3)
const ARENA_BUTTON_BORDER: Color = Color(0.0, 0.85, 0.85)
const ARENA_BUTTON_TEXT: Color = Color(0.0, 1.0, 1.0)
const ARENA_BUTTON_TEXT_HOVER: Color = Color(0.85, 1.0, 1.0)
var arena_picker: Control
var arena_buttons: Dictionary = {}
var arena_preview: TextureRect
var arena_preview_pixels: Vector2i
## Downscaled preview textures by arena, made on first use.
var arena_preview_textures: Dictionary = {}

# Settings panel (gear button): the controls/FPS/shader/roll toggles live inside it
@onready var settings_button: TextureButton = get_node_or_null("SettingsButton")
@onready var settings_panel: Control = get_node_or_null("SettingsPanel")

@onready var relative_label: Label = $RelativeLabel
@onready var global_label: Label = $GlobalLabel

var is_scrolling: bool = true
var feedback_tween: Tween
var feedback_label_lifetime: float = 2.0

var original_positions = {}

func _ready() -> void:
	if has_node("UILayer/ColorRect"):
		var cr = get_node("UILayer/ColorRect")
		if GameManager.mobile_mode_active:
			cr.visible = GameManager.retro_shader_active
		else:
			cr.visible = true # On PC the ColorRect is always visible
			if cr.material is ShaderMaterial:
				ShaderManager.update_crt_shader_quality(cr.material)

	GameManager.can_pause = false
	GameManager.reset_speedrun()
	# Leaving a run for the menu discards its arena clear time
	AchievementManager.cancel_arena_run()
	# Same for an arcade run left from the pause menu (records and diamonds are saved)
	ArcadeManager.leave_arcade()

	global_label.visible = false
	relative_label.visible = false
	
	_setup_buttons()

	# Re-center on every platform: mobile mode expands the viewport beyond 520px wide,
	# so without this the menu stays glued to the left side of the screen
	_save_original_positions()
	get_tree().root.size_changed.connect(_on_window_resized)
	_on_window_resized()

func _save_original_positions() -> void:
	for child in get_children():
		if "position" in child:
			# Ignore full-screen modals
			if child == credits_panel or child == special_thanks_panel:
				continue
			original_positions[child] = child.position

func _on_window_resized() -> void:
	# The original menu is designed for 520x300 (Center = 260)
	var current_center_x = get_viewport().get_visible_rect().size.x / 2.0
	var offset_x = current_center_x - 260.0
	
	for child in original_positions.keys():
		if is_instance_valid(child):
			child.position.x = original_positions[child].x + offset_x
			
	# Center the inner textures of the full-screen modals manually
	if is_instance_valid(credits_panel) and credits_panel.has_node("CreditsTexture"):
		credits_panel.get_node("CreditsTexture").position.x = 79.0 + offset_x
		
	if is_instance_valid(special_thanks_panel) and special_thanks_panel.has_node("CreditsTexture"):
		special_thanks_panel.get_node("CreditsTexture").position.x = 79.0 + offset_x
func _setup_buttons() -> void:
	# Autoconnect all audio hovers/focuses for any button inside this menu
	_connect_audio_to_buttons(self)
	
	# Connect specific functionalities manually, eliminating the need for 20+ variables
	# The big PLAY button always starts the main mode; its arrow opens the mode picker
	if has_node("VBoxContainer/PlayButton"):
		get_node("VBoxContainer/PlayButton").pressed.connect(_start_normal_mode)

	if is_instance_valid(play_mode_arrow) and is_instance_valid(play_mode_panel):
		play_mode_arrow.visible = GameManager.arcade_enabled
		play_mode_arrow.toggled.connect(_set_play_mode_panel_open)
		play_mode_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		play_mode_panel.get_node("NormalButton").pressed.connect(_start_normal_mode)
		play_mode_panel.get_node("ArcadeButton").pressed.connect(_on_arcade_button_pressed)
		_build_arena_picker()

	if is_instance_valid(settings_button) and is_instance_valid(settings_panel):
		settings_button.toggled.connect(_set_settings_panel_open)
		settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	if has_node("VBoxContainer/QuitButton"):
		get_node("VBoxContainer/QuitButton").pressed.connect(func():
			if browser_support:
				get_tree().reload_current_scene()
			else:
				get_tree().quit()
		)
		
	if has_node("VBoxContainer/CreditsButton"):
		get_node("VBoxContainer/CreditsButton").pressed.connect(credits_panel.show)

	_setup_main_buttons()

	# The settings panel (Scenes/UI/settings_panel.tscn) runs its own toggles; the menu
	# only opens/closes it and reacts to what concerns the menu
	if settings_panel is SettingsPanel:
		settings_panel.controls_changed.connect(show_feedback_label)
		# Close the settings panel first, or the click that follows would only close it
		settings_panel.special_thanks_requested.connect(func():
			_hide_settings_panel()
			special_thanks_panel.show()
		)

	if has_node("AchievementsButton"):
		var achievements_btn = get_node("AchievementsButton")
		achievements_btn.visible = GameManager.achievements_enabled
		achievements_btn.pressed.connect(func(): get_tree().change_scene_to_packed(achievements_scene))

	if has_node("ShopButton"):
		var shop_btn = get_node("ShopButton")
		shop_btn.visible = GameManager.shop_enabled
		shop_btn.pressed.connect(func(): get_tree().change_scene_to_packed(shop_scene))

	if has_node("SkinSelectorButton"):
		get_node("SkinSelectorButton").pressed.connect(func(): get_tree().change_scene_to_packed(skin_selector_scene))
		
	if has_node("DiscordButton"):
		get_node("DiscordButton").pressed.connect(func(): OS.shell_open("https://discord.com/invite/ne3U8RS8bA"))
		
func _start_normal_mode() -> void:
	GameManager.reset_game_state()
	get_tree().change_scene_to_packed(next_scene)

## An endless arena (see ArcadeManager). The arena scenes link back to this menu, so they
## come from GameManager's preloads instead of exports (no circular scene reference).
func _start_arcade_mode(arena: int = 0) -> void:
	ArcadeManager.start_run(arena)
	get_tree().change_scene_to_packed(ArcadeManager.get_arena_scene(ArcadeManager.arena_index))

## With a single playable arena ARCADE starts it right away; otherwise it opens the picker.
func _on_arcade_button_pressed() -> void:
	if not is_instance_valid(arena_picker):
		_start_arcade_mode(0)
		return
	_set_arena_picker_open(not arena_picker.visible)

## Arena list + preview of the arena under the cursor/focus, one button per arena the
## player has reached (no picker when only arena 1 is available).
##   ArenaPicker (NinePatchRect, mode panel sprite, fixed size)
##   └ MarginContainer → HBoxContainer
##       ├ VBoxContainer: arena buttons, sharing the height evenly
##       └ PanelContainer (frame) → TextureRect (preview)
func _build_arena_picker() -> void:
	var arenas: Array[int] = ArcadeManager.get_available_arenas()
	if arenas.size() <= 1:
		return
	# Base height = the mode panel's, so both read as one block; the width follows the
	# preview, which keeps the aspect of the arena room
	var height: float = play_mode_panel.size.y
	var inner_height: float = height - ARENA_PICKER_MARGIN * 2.0
	var region: Vector2 = Vector2(ArcadeManager.PREVIEW_REGION.size)
	var preview_size: Vector2 = Vector2(roundf(inner_height * region.x / region.y), inner_height)
	var width: float = ARENA_PICKER_MARGIN * 2.0 + ARENA_BUTTON_WIDTH + ARENA_PICKER_SEPARATION + preview_size.x

	var picker: NinePatchRect = NinePatchRect.new()
	picker.name = "ArenaPicker"
	picker.texture = (play_mode_panel as TextureRect).texture
	picker.patch_margin_left = 2
	picker.patch_margin_top = 2
	picker.patch_margin_right = 2
	picker.patch_margin_bottom = 2
	picker.mouse_filter = Control.MOUSE_FILTER_STOP
	picker.visible = false
	# Right of the mode panel, top-aligned
	picker.position = Vector2(play_mode_panel.size.x + 2.0, 0.0)
	picker.size = Vector2(width, height)
	play_mode_panel.add_child(picker)
	arena_picker = picker

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, ARENA_PICKER_MARGIN)
	picker.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", ARENA_PICKER_SEPARATION)
	margin.add_child(row)

	var list: VBoxContainer = VBoxContainer.new()
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.custom_minimum_size.x = ARENA_BUTTON_WIDTH
	list.add_theme_constant_override("separation", ARENA_PICKER_SEPARATION)
	row.add_child(list)
	for arena in arenas:
		var button: Button = _make_arena_button(GameManager.arena_names[arena].to_upper())
		button.pressed.connect(_start_arcade_mode.bind(arena))
		# The mouse moves the focus too (see _make_arena_button), so focus drives the preview
		button.focus_entered.connect(_show_arena_preview.bind(arena))
		list.add_child(button)
		arena_buttons[arena] = button

	row.add_child(_make_arena_preview_frame(preview_size))
	_connect_audio_to_buttons(picker)
	_show_arena_preview(ArcadeManager.arena_index if arena_buttons.has(ArcadeManager.arena_index) else arenas[0])

## Framed preview (1-unit border like the buttons). The image is made at
## ARENA_PREVIEW_PIXEL_SCALE so the downscaled room stays sharp.
func _make_arena_preview_frame(frame_size: Vector2) -> PanelContainer:
	var frame: PanelContainer = PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.custom_minimum_size = frame_size
	var style: StyleBoxFlat = _arena_button_style(ARENA_BUTTON_BG)
	style.set_content_margin_all(1)
	frame.add_theme_stylebox_override("panel", style)

	arena_preview = TextureRect.new()
	arena_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arena_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arena_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	arena_preview.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	frame.add_child(arena_preview)
	arena_preview_pixels = Vector2i((frame_size - Vector2(2, 2)) * ARENA_PREVIEW_PIXEL_SCALE)
	return frame

func _show_arena_preview(arena: int) -> void:
	if not is_instance_valid(arena_preview):
		return
	if not arena_preview_textures.has(arena):
		arena_preview_textures[arena] = _make_preview_texture(ArcadeManager.get_arena_preview(arena))
	arena_preview.texture = arena_preview_textures[arena]

## The arena background cropped to its room and downscaled once on the CPU (smooth, no
## shimmering). If the image can't be read back, the GPU scales an AtlasTexture instead.
func _make_preview_texture(source: Texture2D) -> Texture2D:
	if source == null:
		return null
	var region: Rect2i = ArcadeManager.PREVIEW_REGION.intersection(Rect2i(Vector2i.ZERO, Vector2i(source.get_size())))
	var image: Image = source.get_image()
	if image == null or image.is_empty():
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = source
		atlas.region = Rect2(region)
		return atlas
	if image.is_compressed():
		image.decompress()
	image = image.get_region(region)
	image.resize(arena_preview_pixels.x, arena_preview_pixels.y, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)

## Fills its share of the list height; clip_text keeps long names from widening it.
## Only focus highlights a button, and the mouse moves the focus, so exactly one button
## (the one keyboard, gamepad or mouse is on) is ever highlighted.
func _make_arena_button(text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.clip_text = true
	button.custom_minimum_size = Vector2(ARENA_BUTTON_WIDTH, 0)
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.add_theme_font_override("font", FontManager.PIXEL_FONT)
	button.add_theme_font_size_override("font_size", ARENA_BUTTON_FONT_SIZE)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_set_arena_button_highlight(button, false)
	button.mouse_entered.connect(button.grab_focus)
	button.focus_entered.connect(_set_arena_button_highlight.bind(button, true))
	button.focus_exited.connect(_set_arena_button_highlight.bind(button, false))
	return button

## Same look in every button state (normal, hover, pressed), so a hover left behind by the
## mouse can't light up a second button: the look only follows focus.
func _set_arena_button_highlight(button: Button, on: bool) -> void:
	var style: StyleBoxFlat = _arena_button_style(ARENA_BUTTON_BG_HOVER if on else ARENA_BUTTON_BG)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		button.add_theme_stylebox_override(state, style)
	var text_color: Color = ARENA_BUTTON_TEXT_HOVER if on else ARENA_BUTTON_TEXT
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, text_color)

func _arena_button_style(bg: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = ARENA_BUTTON_BORDER
	style.set_border_width_all(1)
	style.set_content_margin_all(0)
	return style

## PLAY, CREDITS and QUIT (Assets/Sprites/MainMenu/*.svg): hover and focus share the lit
## sprite, and hovering one focuses it, so only one button is ever lit, with the mouse or
## the keyboard. Not while a popup is open, so the hover doesn't pull focus out of it.
func _setup_main_buttons() -> void:
	for button_name in ["PlayButton", "CreditsButton", "QuitButton"]:
		var button: TextureButton = get_node_or_null("VBoxContainer/" + button_name)
		if button == null:
			continue
		button.mouse_entered.connect(func():
			if not _is_play_mode_panel_open() and not _is_settings_panel_open():
				button.grab_focus()
		)
	# The arcade arrow sits on PLAY's screen: it lights up with PLAY so the screen looks whole
	var play_button: TextureButton = get_node_or_null("VBoxContainer/PlayButton")
	if is_instance_valid(play_button) and is_instance_valid(play_mode_arrow):
		var arrow_idle: Texture2D = play_mode_arrow.texture_normal
		play_button.focus_entered.connect(func():
			play_mode_arrow.texture_normal = play_mode_arrow.texture_hover
		)
		play_button.focus_exited.connect(func():
			play_mode_arrow.texture_normal = arrow_idle
		)

func _set_arena_picker_open(open: bool) -> void:
	if not is_instance_valid(arena_picker):
		return
	arena_picker.visible = open
	if open:
		# Focus the arena of the last arcade run (keyboard/gamepad can pick right away)
		var focus: Button = arena_buttons.get(ArcadeManager.arena_index, arena_buttons.values()[0])
		focus.grab_focus()

func _is_arena_picker_open() -> bool:
	return is_instance_valid(arena_picker) and arena_picker.visible

func _set_play_mode_panel_open(open: bool) -> void:
	play_mode_panel.visible = open
	play_mode_arrow.set_pressed_no_signal(open)
	_set_arena_picker_open(false)
	if open:
		_hide_settings_panel()
		# Focus lets keyboard/gamepad pick a mode (its focus sound is the open feedback)
		play_mode_panel.get_node("NormalButton").grab_focus()
	else:
		back_sound.play()

func _is_play_mode_panel_open() -> bool:
	return is_instance_valid(play_mode_panel) and play_mode_panel.visible

func _set_settings_panel_open(open: bool) -> void:
	if open and settings_panel is SettingsPanel:
		settings_panel.sync_with_settings()
	settings_panel.visible = open
	settings_button.set_pressed_no_signal(open)
	back_sound.play()
	# Only one popup at a time
	if open and _is_play_mode_panel_open():
		play_mode_panel.visible = false
		play_mode_arrow.set_pressed_no_signal(false)

## Closes the settings panel without a sound (another popup is opening).
func _hide_settings_panel() -> void:
	if _is_settings_panel_open():
		settings_panel.visible = false
		settings_button.set_pressed_no_signal(false)

func _is_settings_panel_open() -> bool:
	return is_instance_valid(settings_panel) and settings_panel.visible

## True when a press lands on the popup or on the button that opens it.
func _is_on_popup(point: Vector2, popup: Control, opener: Control) -> bool:
	return popup.get_global_rect().has_point(point) or opener.get_global_rect().has_point(point)

func _connect_audio_to_buttons(node: Node) -> void:
	# The settings panel plays its own hover sound
	if node is SettingsPanel:
		return
	if node is BaseButton:
		if not node.mouse_entered.is_connected(button_sound.play):
			node.mouse_entered.connect(button_sound.play)
		if not node.focus_entered.is_connected(button_sound.play):
			node.focus_entered.connect(button_sound.play)
	for child in node.get_children():
		_connect_audio_to_buttons(child)

func _process(delta: float) -> void:
	if is_scrolling:
		animated_background.position.y -= scroll_speed * delta

func _input(event: InputEvent) -> void:
	# A click/touch outside an open popup (mode picker, settings) only closes it
	if _is_press(event):
		var point: Vector2 = event.position
		var on_arena_picker: bool = _is_arena_picker_open() and arena_picker.get_global_rect().has_point(point)
		if _is_play_mode_panel_open() and not on_arena_picker \
				and not _is_on_popup(point, play_mode_panel, play_mode_arrow):
			_set_play_mode_panel_open(false)
			get_viewport().set_input_as_handled()
			return
		if _is_settings_panel_open() and not _is_on_popup(point, settings_panel, settings_button):
			_set_settings_panel_open(false)
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed("pause"):
		# Esc steps back one level: arena picker first, then the mode panel
		if _is_arena_picker_open():
			_set_arena_picker_open(false)
			back_sound.play()
			play_mode_panel.get_node("ArcadeButton").grab_focus()
			return
		if _is_play_mode_panel_open():
			_set_play_mode_panel_open(false)
			return
		if _is_settings_panel_open():
			_set_settings_panel_open(false)
			return
		back_sound.play()
		if credits_panel.visible:
			credits_panel.hide()
		elif special_thanks_panel.visible:
			special_thanks_panel.hide()
		else:	
			if browser_support == true:
				get_tree().reload_current_scene()
			else:
				get_tree().quit()

func _is_press(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	# Touch is also emulated as mouse on desktop; real touch only matters on mobile
	return event is InputEventScreenTouch and event.pressed

func show_feedback_label(is_relative: bool):
	if feedback_tween:
		feedback_tween.kill()
		
	global_label.visible = false
	relative_label.visible = false
	
	var target_label = relative_label if is_relative else global_label
	target_label.visible = true
	target_label.modulate.a = 1.0
	
	feedback_tween = create_tween()
	feedback_tween.tween_interval(feedback_label_lifetime)
	feedback_tween.tween_property(target_label, "modulate:a", 0.0, 0.5)

func _on_scroll_timer_timeout() -> void:
	is_scrolling = false

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
