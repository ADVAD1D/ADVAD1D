extends Node2D 

@export var next_scene: PackedScene
## Scene after the ending of each arena, by arena index (GameManager.current_arena_index,
## still the arena just won). Arenas with no entry go to next_scene (the main menu).
@export var next_scene_by_arena: Array[PackedScene] = []
## Without lines, seconds the illustration stays before the fade out.
@export var display_duration: float = 10.0
@export var fade_out_duration: float = 1.5
@export var speaker_name: String = "COMMANDER"
## The commander's lines in the shared CinematicDialogue box (UILayer/Dialogue; Enter or a
## tap advances), set in the scene. The scene fades out after the last one. Empty = the
## illustration stays display_duration seconds. Esc skips it all.
@export var lines: PackedStringArray = []
## Seconds before the dialogue box opens.
@export var dialogue_delay: float = 1.0

## The shared dialogue box script, by path, so it doesn't depend on the global class cache.
const DialogueBox = preload("res://Scripts/UI/cinematic_dialogue.gd")

var _finished: bool = false

@onready var illustration_sprite: Sprite2D = $Sprite2D
@onready var dialogue: DialogueBox = get_node_or_null("UILayer/Dialogue")

func _ready() -> void:
	start_sequence()
	GameManager.can_pause = false

func start_sequence():
	if lines.is_empty() or dialogue == null:
		await get_tree().create_timer(display_duration).timeout
	else:
		dialogue.finished.connect(_finish)
		await get_tree().create_timer(dialogue_delay).timeout
		if not _finished:
			dialogue.play(lines, speaker_name)
		return
	_finish()


func _input(event: InputEvent) -> void:
	if not _finished and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	if dialogue:
		dialogue.close(fade_out_duration * 0.5)
	var illustration_tween = create_tween()
	illustration_tween.tween_property(illustration_sprite, "modulate:a", 0.0, fade_out_duration)
	MusicPlayer.fade_out_and_stop(fade_out_duration)

	await illustration_tween.finished
	# The music's fade ends with stop(): let it finish first, or it would stop the next
	# scene's song
	while MusicPlayer.is_fading:
		await get_tree().process_frame

	GameManager.can_pause = true
	
	var target: PackedScene = next_scene
	var arena: int = GameManager.current_arena_index
	if arena >= 0 and arena < next_scene_by_arena.size() and next_scene_by_arena[arena] != null:
		target = next_scene_by_arena[arena]

	if target:
		get_tree().change_scene_to_packed(target)
	else:
		print("ERROR: No se asignó una escena para la transición.")
