extends Node2D
## Commander cinematic over an illustration: the test room briefing before arena 3
## (test_room_cinematic.tscn) and the end of the simulation after it (monitor_cinematic.tscn,
## the monitor illustration). Each scene sets its own illustration, lines and next_scene.
##
## The illustration fills the screen with some room to spare and pans slowly from its
## right edge to its left one. The lines play in the shared CinematicDialogue box (Enter
## or a tap to advance). After the last line everything fades out and the scene changes
## to next_scene. Esc skips it all.

@export var next_scene: PackedScene
@export var speaker_name: String = "COMMANDER"
## Set in each scene (no default, so a scene that loses them doesn't show another scene's
## lines: it warns and skips to next_scene).
@export var lines: PackedStringArray = []
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
	if _finished:
		return
	if lines.is_empty():
		push_warning("Cinematic without lines: " + scene_file_path)
		_finish()
		return
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
	# The music's fade ends with stop(): let it finish first, or it would stop the next
	# scene's song (the ending after the monitor cinematic)
	while MusicPlayer.is_fading:
		await get_tree().process_frame
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
