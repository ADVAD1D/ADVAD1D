extends Node2D
## Test room cinematic: the commander talks to adnex over the test room illustration.
##
## The illustration fills the screen with some room to spare and pans slowly from its
## right edge to its left one. The lines play in the shared CinematicDialogue box (Enter
## or a tap to advance). After the last line everything fades out and the scene changes
## to next_scene. Esc skips it all.

@export var next_scene: PackedScene
@export var speaker_name: String = "COMMANDER"
@export var lines: PackedStringArray = [
	"Second test completed successfully, soldier.",
	"We are impressed by the skill you have shown in the first two battle arenas.",
	"What comes next will be the ultimate test: a deadly enemy.",
	"Not the simple robots you have been dealing with all this time.",
	"We want to guarantee excellence in this organization.",
	"Your results will be used to strengthen future trials for other soldiers.",
	"We will collect your endurance, your reaction times, your behavior and your overall way of piloting.",
	"The simulator's artificial intelligence will improve based on the experiences and use of all of you.",
	"Handling your ship will always feel very close to the simulator experience.",
	"In the next phase of the trial, you will face a single threat.",
	"You need to put into practice everything you have learned so far.",
	"Good luck in arena 3.",
]
## Seconds the pan takes from the right edge of the illustration to the left one.
@export var pan_duration: float = 40.0
## Minimum horizontal travel of the pan, in viewport pixels.
@export var pan_distance: float = 64.0
@export var fade_in_duration: float = 1.5
@export var fade_out_duration: float = 1.5

## The shared dialogue box script, by path, so it doesn't depend on the global class cache.
const DialogueBox = preload("res://Scripts/UI/cinematic_dialogue.gd")

var _finished: bool = false

@onready var illustration: Sprite2D = $Illustration
@onready var dialogue: DialogueBox = $UILayer/Dialogue


func _ready() -> void:
	GameManager.can_pause = false
	dialogue.finished.connect(_finish)
	_start_pan()
	illustration.modulate.a = 0.0
	var fade_in: Tween = create_tween()
	fade_in.tween_property(illustration, "modulate:a", 1.0, fade_in_duration)
	await fade_in.finished
	if not _finished:
		dialogue.play(lines, speaker_name)


## Scales the illustration to cover the visible area (wider screens on phones too) with
## pan_distance to spare, then moves it from showing its right edge to its left one.
func _start_pan() -> void:
	var view: Vector2 = get_viewport_rect().size
	var texture_size: Vector2 = illustration.texture.get_size()
	var scale_factor: float = maxf(view.y / texture_size.y,
			(view.x + pan_distance) / texture_size.x)
	illustration.centered = false
	illustration.scale = Vector2.ONE * scale_factor
	var drawn: Vector2 = texture_size * scale_factor
	illustration.position = Vector2(view.x - drawn.x, (view.y - drawn.y) * 0.5)
	var pan: Tween = create_tween()
	pan.tween_property(illustration, "position:x", 0.0, pan_duration) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _input(event: InputEvent) -> void:
	if not _finished and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	dialogue.close(fade_out_duration * 0.5)
	var fade_out: Tween = create_tween()
	fade_out.tween_property(illustration, "modulate:a", 0.0, fade_out_duration)
	MusicPlayer.fade_out_and_stop(fade_out_duration)
	await fade_out.finished
	GameManager.can_pause = true
	# Arena 2's win leaves phase_to_start past its last phase: arena 3 starts from phase 1
	GameManager.phase_to_start = 1
	GameManager.boss_checkpoint_health = -1
	GameManager.post_boss_phases = false
	GameManager.reset_score()
	if next_scene:
		get_tree().change_scene_to_packed(next_scene)
	else:
		_log_message("ERROR: next_scene is not set for the test room cinematic.")


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
