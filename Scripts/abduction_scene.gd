extends Node2D
## First cinematic (Abduction.tscn): the commander welcomes adnex over the cockpit
## illustration (the sprite fades in by itself, the camera scrolls with a slow breath).
##
## The lines play in the shared CinematicDialogue box: Enter (the "Skip" action) or a tap
## completes the line being typed, then goes to the next one. After the last line, or
## when Esc is pressed, everything fades out and the scene changes to next_scene.

@export var next_scene: PackedScene
@export var speaker_name: String = "COMMANDER"
@export var lines: PackedStringArray = [
	"Welcome to the training program, soldier.",
	"This simulation is designed for you to learn and master the use of your ship.",
]
## Seconds the illustration shows alone before the dialogue box opens.
@export var dialogue_delay: float = 1.5
@export var fade_out_duration: float = 1.5

## The shared dialogue box script, by path, so it doesn't depend on the global class cache.
const DialogueBox = preload("res://Scripts/UI/cinematic_dialogue.gd")

var _finished: bool = false

@onready var illustration_sprite: Sprite2D = $Sprite2D
@onready var dialogue: DialogueBox = $UILayer/Dialogue


func _ready() -> void:
	GameManager.can_pause = false
	dialogue.finished.connect(_finish)
	await get_tree().create_timer(dialogue_delay).timeout
	if not _finished:
		dialogue.play(lines, speaker_name)


func _input(event: InputEvent) -> void:
	if not _finished and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	dialogue.close(fade_out_duration * 0.5)
	var illustration_tween: Tween = create_tween()
	illustration_tween.tween_property(illustration_sprite, "modulate:a", 0.0, fade_out_duration)
	MusicPlayer.fade_out_and_stop(fade_out_duration)
	await illustration_tween.finished
	GameManager.can_pause = true
	if next_scene:
		get_tree().change_scene_to_packed(next_scene)
	else:
		_log_message("ERROR: Not set a next_scene for the transition.")


func _log_message(message) -> void:
	if not GameManager.is_debug_text:
		return
	var final_string: String = ""
	if typeof(message) == TYPE_ARRAY:
		for arg in message:
			final_string += str(arg) + " "
		final_string = final_string.strip_edges()
	else:
		final_string = str(message)
	print_rich("[color=yellow][DEV LOG][/color] " + final_string)
