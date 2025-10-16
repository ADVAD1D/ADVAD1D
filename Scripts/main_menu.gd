extends Control

@export var scroll_speed: float = 20.0
@export var next_scene: PackedScene

@onready var animated_background: AnimatedSprite2D = $Background
@onready var play_button: TextureButton = $VBoxContainer/PlayButton
@onready var quit_button: TextureButton = $VBoxContainer/QuitButton
@onready var button_sound: AudioStreamPlayer = $ButtonSound

var is_scrolling: bool = true

func _ready() -> void:
	GameManager.can_pause = false
	play_button.pressed.connect(_on_play_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)

func _process(delta: float) -> void:
	if is_scrolling:
		animated_background.position.y -= scroll_speed * delta

func _on_play_button_pressed():
	get_tree().change_scene_to_packed(next_scene)
	
func _on_quit_button_pressed():
	get_tree().quit()

func _on_play_button_mouse_entered() -> void:
	button_sound.play()

func _on_quit_button_mouse_entered() -> void:
	button_sound.play() # Replace with function body.

func _on_scroll_timer_timeout() -> void:
	is_scrolling = false # Replace with function body.
