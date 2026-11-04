extends Control

@export var scroll_speed: float = 20.0
@export var next_scene: PackedScene
@export var skin_selector_scene: PackedScene
@export var chat_console_scene: PackedScene
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
	
	if has_node("ChatConsoleButton"):
		get_node("ChatConsoleButton").hide()

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
		play_mode_panel.get_node("ArcadeButton").pressed.connect(_start_arcade_mode)

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
		
	var fs_btn = _get_setting_button("FullScreenButton")
	if fs_btn:
		fs_btn.button_pressed = (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
		fs_btn.toggled.connect(func(is_checked):
			if is_checked:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		)
		
	if has_node("VBoxContainer/CreditsButton"):
		get_node("VBoxContainer/CreditsButton").pressed.connect(credits_panel.show)
		
	var thanks_btn = _get_setting_button("SpecialThanksButton")
	if thanks_btn:
		# Close the settings panel first, or the click that follows would only close it
		thanks_btn.pressed.connect(func():
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
		
	if has_node("ChatConsoleButton"):
		get_node("ChatConsoleButton").pressed.connect(func(): get_tree().change_scene_to_packed(chat_console_scene))
		
	if has_node("GithubButton"):
		get_node("GithubButton").pressed.connect(func(): OS.shell_open("https://github.com/ADVAD1D/ADVAD1D"))
		
	if has_node("DiscordButton"):
		get_node("DiscordButton").pressed.connect(func(): OS.shell_open("https://discord.com/invite/ne3U8RS8bA"))
		
	# Toggles (inside the settings panel)
	var fps_btn = _get_setting_button("FPSButton")
	if fps_btn:
		fps_btn.set_pressed_no_signal(GameManager.show_fps)
		fps_btn.pressed.connect(back_sound.play)
		fps_btn.toggled.connect(func(toggled_on):
			GameManager.show_fps = toggled_on
			_log_message(["FPS Mode", toggled_on])
			GameManager.save_data()
		)
		
	var controls_btn = _get_setting_button("ControlsButton")
	if controls_btn:
		controls_btn.set_pressed_no_signal(GameManager.relative_control_active)
		controls_btn.pressed.connect(back_sound.play)
		controls_btn.toggled.connect(func(toggled_on):
			GameManager.relative_control_active = toggled_on
			_log_message(["Relative Controls", toggled_on])
			GameManager.save_data()
			show_feedback_label(toggled_on)
		)
		
	var speedrun_btn = _get_setting_button("SpeedrunButton")
	if speedrun_btn:
		speedrun_btn.set_pressed_no_signal(GameManager.speedrun_mode_active)
		speedrun_btn.toggled.connect(func(toggled_on):
			GameManager.speedrun_mode_active = toggled_on
			back_sound.play()
			GameManager.save_data()
		)
		
	var retro_btn = _get_setting_button("RetroShaderButton")
	if retro_btn:
		if GameManager.mobile_mode_active:
			retro_btn.set_pressed_no_signal(GameManager.retro_shader_active)
			retro_btn.pressed.connect(back_sound.play)
			retro_btn.toggled.connect(func(toggled_on):
				GameManager.retro_shader_active = toggled_on
				_log_message(["Retro Shader", toggled_on])
				GameManager.save_data()
				# We can apply the shader logic here immediately for visual feedback
				if has_node("UILayer/ColorRect"):
					get_node("UILayer/ColorRect").visible = toggled_on
			)
		else:
			# On PC: The button acts as an "Optimize Shaders" toggle
			retro_btn.set_pressed_no_signal(GameManager.pc_optimize_shaders)
			retro_btn.pressed.connect(back_sound.play)
			retro_btn.toggled.connect(func(toggled_on):
				GameManager.pc_optimize_shaders = toggled_on
				_log_message(["PC Shader Optimize", toggled_on])
				GameManager.save_data()
				_refresh_menu_crt()
				# The optimized shader never rolls, so the roll toggle greys out
				_update_roll_button()
			)

	# Pressed = roll off (like the shader button: pressed = lighter effects)
	var roll_btn = _get_setting_button("RollButton")
	if roll_btn:
		roll_btn.set_pressed_no_signal(not GameManager.crt_roll_enabled)
		roll_btn.pressed.connect(back_sound.play)
		roll_btn.toggled.connect(func(toggled_on):
			GameManager.crt_roll_enabled = not toggled_on
			_log_message(["CRT roll", GameManager.crt_roll_enabled])
			GameManager.save_data()
			_refresh_menu_crt()
		)
		_update_roll_button()

func _get_setting_button(button_name: String) -> TextureButton:
	if not is_instance_valid(settings_panel):
		return null
	return settings_panel.get_node_or_null(button_name) as TextureButton

## Disabled (dimmed) where the CRT never rolls anyway: mobile, web and optimized shaders.
func _update_roll_button() -> void:
	var roll_btn = _get_setting_button("RollButton")
	if roll_btn:
		roll_btn.disabled = not ShaderManager.is_roll_supported()

## Re-applies the CRT settings to this menu's shader (other scenes get them when they load).
func _refresh_menu_crt() -> void:
	if has_node("UILayer/ColorRect"):
		var color_rect = get_node("UILayer/ColorRect")
		if color_rect.material is ShaderMaterial:
			ShaderManager.update_crt_shader_quality(color_rect.material)

func _start_normal_mode() -> void:
	GameManager.reset_game_state()
	get_tree().change_scene_to_packed(next_scene)

## Arena 1, endless (see ArcadeManager). main.tscn links back to this menu, so it is
## taken from GameManager's preload instead of an export (no circular scene reference).
func _start_arcade_mode() -> void:
	ArcadeManager.start_run()
	get_tree().change_scene_to_packed(GameManager.preloaded_main)

func _set_play_mode_panel_open(open: bool) -> void:
	play_mode_panel.visible = open
	play_mode_arrow.set_pressed_no_signal(open)
	if open:
		_hide_settings_panel()
		# Focus lets keyboard/gamepad pick a mode (its focus sound is the open feedback)
		play_mode_panel.get_node("NormalButton").grab_focus()
	else:
		back_sound.play()

func _is_play_mode_panel_open() -> bool:
	return is_instance_valid(play_mode_panel) and play_mode_panel.visible

func _set_settings_panel_open(open: bool) -> void:
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
		if _is_play_mode_panel_open() and not _is_on_popup(point, play_mode_panel, play_mode_arrow):
			_set_play_mode_panel_open(false)
			get_viewport().set_input_as_handled()
			return
		if _is_settings_panel_open() and not _is_on_popup(point, settings_panel, settings_button):
			_set_settings_panel_open(false)
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed("pause"):
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
