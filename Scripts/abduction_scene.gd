extends Node2D 

@export var next_scene: PackedScene
@export var display_duration: float = 10.0
@export var fade_out_duration: float = 1.5

@onready var illustration_sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	start_sequence()

func start_sequence():
	await get_tree().create_timer(display_duration).timeout
	
	var illustration_tween = create_tween()
	illustration_tween.tween_property(illustration_sprite, "modulate:a", 0.0, fade_out_duration)
	MusicPlayer.fade_out_and_stop(fade_out_duration)
	
	await illustration_tween.finished
	
	if next_scene:
		get_tree().change_scene_to_packed(next_scene)
	else:
		print("ERROR: No se asignó una escena para la transición.")
