extends Node2D 

@export var next_scene: PackedScene
## Scene after the ending of each arena, by arena index (GameManager.current_arena_index,
## still the arena just won). Arenas with no entry go to next_scene (the main menu).
@export var next_scene_by_arena: Array[PackedScene] = []
@export var display_duration: float = 10.0
@export var fade_out_duration: float = 1.5

@onready var illustration_sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	start_sequence()
	GameManager.can_pause = false

func start_sequence():
	await get_tree().create_timer(display_duration).timeout
	
	var illustration_tween = create_tween()
	illustration_tween.tween_property(illustration_sprite, "modulate:a", 0.0, fade_out_duration)
	MusicPlayer.fade_out_and_stop(fade_out_duration)
	
	await illustration_tween.finished
	
	GameManager.can_pause = true
	
	var target: PackedScene = next_scene
	var arena: int = GameManager.current_arena_index
	if arena >= 0 and arena < next_scene_by_arena.size() and next_scene_by_arena[arena] != null:
		target = next_scene_by_arena[arena]

	if target:
		get_tree().change_scene_to_packed(target)
	else:
		print("ERROR: No se asignó una escena para la transición.")
