extends Control

@export var scroll_speed: float = 20.0
@export var next_scene: PackedScene
@export var skin_selector_scene: PackedScene

#this bool manage scene in game versions (browser and native)
@onready var browser_support: bool = GameManager.browser_support

@onready var animated_background: AnimatedSprite2D = $Background
@onready var play_button: TextureButton = $VBoxContainer/PlayButton
@onready var credits_button: TextureButton = $VBoxContainer/CreditsButton
@onready var special_thanks_button: TextureButton = $SpecialThanksButton
@onready var quit_button: TextureButton = $VBoxContainer/QuitButton
@onready var button_sound: AudioStreamPlayer = $ButtonSound
@onready var back_sound: AudioStreamPlayer = $BackSound
@onready var credits_panel: Control = $CreditsPanel
@onready var special_thanks_panel: Control = $SpecialThanksPanel
@onready var github_button: TextureButton = $GithubButton
@onready var discord_button: TextureButton = $DiscordButton
@onready var fullscreen_button: TextureButton = $FullScreenButton
@onready var skin_selector_button: TextureButton = $SkinSelectorButton

#this bool manage menu background scroll
var is_scrolling: bool = true

func _ready() -> void:
	GameManager.can_pause = false
	play_button.pressed.connect(_on_play_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
	fullscreen_button.toggled.connect(_on_fullscreen_toggled)
	credits_button.pressed.connect(_on_credits_button_pressed)
	special_thanks_button.pressed.connect(_on_special_thanks_button_pressed)
	skin_selector_button.pressed.connect(_on_skin_selector_button_pressed)
	github_button.pressed.connect(_on_github_button_pressed)
	discord_button.pressed.connect(_on_discord_button_pressed)
	
	fullscreen_button.button_pressed = (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)

func _process(delta: float) -> void:
	if is_scrolling:
		animated_background.position.y -= scroll_speed * delta

func _on_play_button_pressed():
	GameManager.reset_game_state()
	get_tree().change_scene_to_packed(next_scene)
	
func _on_quit_button_pressed():
	if browser_support == true:
		get_tree().reload_current_scene()
	else:
		get_tree().quit()

func _on_play_button_mouse_entered() -> void:
	button_sound.play()
	
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
	
func _on_credits_button_pressed():
	credits_panel.show()
	
func _on_special_thanks_button_pressed():
	special_thanks_panel.show()
	
func _on_github_button_pressed():
	OS.shell_open("https://github.com/ADVAD1D/ADVAD1D")
	
func _on_discord_button_pressed():
	OS.shell_open("https://discord.com/invite/ne3U8RS8bA")
	
func _on_skin_selector_button_pressed():
	get_tree().change_scene_to_packed(skin_selector_scene)

func _on_quit_button_mouse_entered() -> void:
	button_sound.play() # Replace with function body.

func _on_scroll_timer_timeout() -> void:
	is_scrolling = false # Replace with function body.

func _on_credits_button_mouse_entered() -> void:
	button_sound.play() # Replace with function body.

func _on_special_thanks_button_mouse_entered() -> void:
	button_sound.play() # Replace with function body.

func _on_discord_button_mouse_entered() -> void:
	button_sound.play() # Replace with function body.
	
func _on_fullscreen_toggled(is_checked: bool):
	if is_checked:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)

func _on_full_screen_button_mouse_entered() -> void:
	button_sound.play() # Replace with function body.

func _on_skin_selector_button_mouse_entered() -> void:
	button_sound.play() # Replace with function body.

func _on_special_thanks_button_focus_entered() -> void:
	button_sound.play() # Replace with function body.
	
func _on_github_button_mouse_entered() -> void:
	button_sound.play() # Replace with function body.
	
func _on_github_button_focus_entered() -> void:
	button_sound.play() # Replace with function body.

func _on_discord_button_focus_entered() -> void:
	button_sound.play() # Replace with function body.

func _on_skin_selector_button_focus_entered() -> void:
	button_sound.play() # Replace with function body.

func _on_play_button_focus_entered() -> void:
	button_sound.play() # Replace with function body.

func _on_credits_button_focus_entered() -> void:
	button_sound.play() # Replace with function body.

func _on_quit_button_focus_entered() -> void:
	button_sound.play() # Replace with function body.
