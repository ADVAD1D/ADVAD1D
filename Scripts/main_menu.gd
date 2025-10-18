extends Control

@export var scroll_speed: float = 20.0
@export var next_scene: PackedScene

@onready var animated_background: AnimatedSprite2D = $Background
@onready var play_button: TextureButton = $VBoxContainer/PlayButton
@onready var credits_button: TextureButton = $VBoxContainer/CreditsButton
@onready var special_thanks_button: TextureButton = $SpecialThanksButton
@onready var quit_button: TextureButton = $VBoxContainer/QuitButton
@onready var button_sound: AudioStreamPlayer = $ButtonSound
@onready var credits_panel: Control = $CreditsPanel

var is_scrolling: bool = true

func _ready() -> void:
	GameManager.can_pause = false
	play_button.pressed.connect(_on_play_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
	credits_button.pressed.connect(_on_credits_button_pressed)
	special_thanks_button.pressed.connect(_on_special_thanks_button_pressed)

func _process(delta: float) -> void:
	if is_scrolling:
		animated_background.position.y -= scroll_speed * delta

func _on_play_button_pressed():
	GameManager.reset_game_state()
	get_tree().change_scene_to_packed(next_scene)
	
func _on_quit_button_pressed():
	get_tree().quit()

func _on_play_button_mouse_entered() -> void:
	button_sound.play()
	
func _on_credits_button_pressed():
	credits_panel.show()
	
func _on_special_thanks_button_pressed():
	pass

func _on_quit_button_mouse_entered() -> void:
	button_sound.play() # Replace with function body.

func _on_scroll_timer_timeout() -> void:
	is_scrolling = false # Replace with function body.

func _on_credits_button_mouse_entered() -> void:
	button_sound.play() # Replace with function body.

func _on_special_thanks_button_mouse_entered() -> void:
	button_sound.play() # Replace with function body.
