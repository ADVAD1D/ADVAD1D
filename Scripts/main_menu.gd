extends Control

@export var scroll_speed: float = 20.0
@export var next_scene: PackedScene
@export var skin_selector_scene: PackedScene
@export var chat_console_scene: PackedScene

@onready var browser_support: bool = GameManager.browser_support
@onready var is_debug_text: bool = GameManager.is_debug_text

@onready var animated_background: AnimatedSprite2D = $Background
@onready var button_sound: AudioStreamPlayer = $ButtonSound
@onready var back_sound: AudioStreamPlayer = $BackSound

@onready var credits_panel: Control = $CreditsPanel
@onready var special_thanks_panel: Control = $SpecialThanksPanel

@onready var relative_label: Label = $RelativeLabel
@onready var global_label: Label = $GlobalLabel

var is_scrolling: bool = true
var feedback_tween: Tween
var feedback_label_lifetime: float = 2.0

func _ready() -> void:
	GameManager.can_pause = false
	GameManager.reset_speedrun()
	
	global_label.visible = false
	relative_label.visible = false
	
	_setup_buttons()

func _setup_buttons() -> void:
	# Autoconnect all audio hovers/focuses for any button inside this menu
	_connect_audio_to_buttons(self)
	
	# Connect specific functionalities manually, eliminating the need for 20+ variables
	if has_node("VBoxContainer/PlayButton"):
		get_node("VBoxContainer/PlayButton").pressed.connect(func():
			GameManager.reset_game_state()
			get_tree().change_scene_to_packed(next_scene)
		)
	
	if has_node("VBoxContainer/QuitButton"):
		get_node("VBoxContainer/QuitButton").pressed.connect(func():
			if browser_support:
				get_tree().reload_current_scene()
			else:
				get_tree().quit()
		)
		
	if has_node("FullScreenButton"):
		var fs_btn = get_node("FullScreenButton")
		fs_btn.button_pressed = (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
		fs_btn.toggled.connect(func(is_checked):
			if is_checked:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		)
		
	if has_node("VBoxContainer/CreditsButton"):
		get_node("VBoxContainer/CreditsButton").pressed.connect(credits_panel.show)
		
	if has_node("SpecialThanksButton"):
		get_node("SpecialThanksButton").pressed.connect(special_thanks_panel.show)
		
	if has_node("SkinSelectorButton"):
		get_node("SkinSelectorButton").pressed.connect(func(): get_tree().change_scene_to_packed(skin_selector_scene))
		
	if has_node("ChatConsoleButton"):
		get_node("ChatConsoleButton").pressed.connect(func(): get_tree().change_scene_to_packed(chat_console_scene))
		
	if has_node("GithubButton"):
		get_node("GithubButton").pressed.connect(func(): OS.shell_open("https://github.com/ADVAD1D/ADVAD1D"))
		
	if has_node("DiscordButton"):
		get_node("DiscordButton").pressed.connect(func(): OS.shell_open("https://discord.com/invite/ne3U8RS8bA"))
		
	# Toggles
	if has_node("FPSButton"):
		var fps_btn = get_node("FPSButton")
		fps_btn.set_pressed_no_signal(GameManager.show_fps)
		fps_btn.pressed.connect(back_sound.play)
		fps_btn.toggled.connect(func(toggled_on):
			GameManager.show_fps = toggled_on
			_log_message(["FPS Mode", toggled_on])
			GameManager.save_data()
		)
		
	if has_node("ControlsButton"):
		var controls_btn = get_node("ControlsButton")
		controls_btn.set_pressed_no_signal(GameManager.relative_control_active)
		controls_btn.pressed.connect(back_sound.play)
		controls_btn.toggled.connect(func(toggled_on):
			GameManager.relative_control_active = toggled_on
			_log_message(["Relative Controls", toggled_on])
			GameManager.save_data()
			show_feedback_label(toggled_on)
		)
		
	if has_node("SpeedrunButton"):
		var speedrun_btn = get_node("SpeedrunButton")
		speedrun_btn.set_pressed_no_signal(GameManager.speedrun_mode_active)
		speedrun_btn.toggled.connect(func(toggled_on):
			GameManager.speedrun_mode_active = toggled_on
			back_sound.play()
			GameManager.save_data()
		)

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
	if event.is_action_pressed("pause"):
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
