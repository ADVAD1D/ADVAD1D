extends Node2D 

@export var next_scene: PackedScene
@export var display_duration: float = 10.0
@export var fade_out_duration: float = 1.5

@onready var illustration_sprite: Sprite2D = $Sprite2D
@onready var enter_key: TextureRect = $UILayer/EnterKey
@onready var skip_label: Label = $UILayer/SkipLabel

func _ready() -> void:
	start_sequence()
	GameManager.can_pause = false
	
	enter_key.modulate.a = 0.0
	
	var enter_fadein_tween = create_tween()
	enter_fadein_tween.tween_property(enter_key, "modulate:a", 1.0, 1.5)
	
	var skip_fadein_tween = create_tween()
	skip_fadein_tween.tween_property(skip_label, "modulate:a", 1.0, 1.5)
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Skip"):
		get_tree().change_scene_to_packed(next_scene)

func start_sequence():
	await get_tree().create_timer(display_duration).timeout
	
	#fades 
	var illustration_tween = create_tween()
	illustration_tween.tween_property(illustration_sprite, "modulate:a", 0.0, fade_out_duration)
	
	var enter_tween = create_tween()
	enter_tween.tween_property(enter_key, "modulate:a", 0.0, fade_out_duration)
	
	var skip_tween = create_tween()
	skip_tween.tween_property(skip_label, "modulate:a", 0.0, fade_out_duration)
	
	MusicPlayer.fade_out_and_stop(fade_out_duration)
	
	await illustration_tween.finished
	
	GameManager.can_pause = true
	
	if next_scene:
		get_tree().change_scene_to_packed(next_scene)
	else:
		print("ERROR: No se asignó una escena para la transición.")
