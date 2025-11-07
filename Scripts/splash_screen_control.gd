extends Control

@export var next_scene: PackedScene
@export var display_duration: float = 2.0
@export var fade_out_duration: float = 0.5
@export var fade_in_duration: float = 0.5

@onready var sprite_logo: TextureRect = $LogoSprite

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	sprite_logo.modulate.a = 0.0
	
	var sprite_fadein_tween = create_tween()
	sprite_fadein_tween.tween_property(sprite_logo, "modulate:a", 1.0, fade_in_duration)
	GameManager.can_pause = false
	start_sequence() # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func start_sequence():
	await get_tree().create_timer(display_duration).timeout
	
	#fades 
	var sprite_tween = create_tween()
	sprite_tween.tween_property(sprite_logo, "modulate:a", 0.0, fade_out_duration)
	
	await sprite_tween.finished
	
	if next_scene:
		get_tree().change_scene_to_packed(next_scene)
	else:
		print("Error, no se asignó una escena")
