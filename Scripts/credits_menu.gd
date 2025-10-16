extends Control

@onready var close_button: TextureButton = %CloseButton
@onready var button_sound: AudioStreamPlayer = $ButtonSound

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	close_button.pressed.connect(hide) # Replace with function body.

func _on_close_button_mouse_entered() -> void:
	button_sound.play() # Replace with function body.
