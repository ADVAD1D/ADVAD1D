extends Node2D
## Test room cinematic: the commander talks to adnex over the test room illustration.
##
## The illustration fills the screen with some room to spare and pans slowly from its
## right edge to its left one. The dialogue box types each line; Enter (the "Skip" action)
## or a tap first completes the line being typed, then goes to the next one. After the
## last line everything fades out and the scene changes to next_scene. Esc skips it all.

@export var next_scene: PackedScene
@export var speaker_name: String = "COMMANDER"
@export var lines: PackedStringArray = [
	"Second test completed successfully, soldier.",
	"We are impressed by the skill you have shown in the first two battle arenas.",
	"What comes next will be the ultimate test: a deadly enemy.",
	"Not the simple robots you have been dealing with all this time.",
	"We want to guarantee excellence in this organization.",
	"Good luck in arena 3.",
]
## Typing speed of the dialogue text.
@export var characters_per_second: float = 38.0
## A blip every this many typed characters (0 = silent).
@export var type_sound_every: int = 3
## Seconds the pan takes from the right edge of the illustration to the left one.
@export var pan_duration: float = 40.0
## Minimum horizontal travel of the pan, in viewport pixels.
@export var pan_distance: float = 64.0
@export var fade_in_duration: float = 1.5
@export var fade_out_duration: float = 1.5

## Presses closer than this are ignored, so a single tap can't advance twice.
const PRESS_COOLDOWN: float = 0.15

var _line_index: int = -1
var _typing: bool = false
var _finished: bool = false
var _typed: float = 0.0
var _last_press: float = -1.0

@onready var illustration: Sprite2D = $Illustration
@onready var dialogue_box: Control = $UILayer/DialogueBox
@onready var name_label: Label = %NameLabel
@onready var text_label: Label = %TextLabel
@onready var next_arrow: Label = %NextArrow
@onready var type_sound: AudioStreamPlayer = $TypeSound
@onready var next_sound: AudioStreamPlayer = $NextSound


func _ready() -> void:
	GameManager.can_pause = false
	name_label.text = speaker_name
	text_label.text = ""
	next_arrow.visible = false
	dialogue_box.modulate.a = 0.0
	_start_pan()

	var arrow_blink: Tween = create_tween().set_loops()
	arrow_blink.tween_property(next_arrow, "modulate:a", 0.15, 0.4)
	arrow_blink.tween_property(next_arrow, "modulate:a", 1.0, 0.4)

	illustration.modulate.a = 0.0
	var fade_in: Tween = create_tween()
	fade_in.tween_property(illustration, "modulate:a", 1.0, fade_in_duration)
	fade_in.tween_property(dialogue_box, "modulate:a", 1.0, 0.4)
	await fade_in.finished
	_next_line()


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
	var y: float = (view.y - drawn.y) * 0.5
	illustration.position = Vector2(view.x - drawn.x, y)
	var pan: Tween = create_tween()
	pan.tween_property(illustration, "position:x", 0.0, pan_duration) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _process(delta: float) -> void:
	if not _typing:
		return
	var before: int = int(_typed)
	_typed += characters_per_second * delta
	var shown: int = mini(int(_typed), text_label.text.length())
	text_label.visible_characters = shown
	if type_sound_every > 0 and shown / type_sound_every > before / type_sound_every:
		type_sound.pitch_scale = randf_range(1.35, 1.6)
		type_sound.play()
	if shown >= text_label.text.length():
		_end_typing()


func _input(event: InputEvent) -> void:
	if _finished:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_finish()
		return
	# Mouse clicks also arrive as touches (emulate_touch_from_mouse), so this covers both
	var pressed: bool = event.is_action_pressed("Skip") \
			or (event is InputEventScreenTouch and event.pressed)
	if not pressed or _line_index < 0:
		return
	get_viewport().set_input_as_handled()
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_press < PRESS_COOLDOWN:
		return
	_last_press = now
	if _typing:
		_end_typing()
	else:
		next_sound.play()
		_next_line()


func _next_line() -> void:
	_line_index += 1
	if _line_index >= lines.size():
		_finish()
		return
	text_label.text = lines[_line_index]
	text_label.visible_characters = 0
	_typed = 0.0
	_typing = true
	next_arrow.visible = false


func _end_typing() -> void:
	_typing = false
	text_label.visible_characters = -1
	next_arrow.visible = true


func _finish() -> void:
	if _finished:
		return
	_finished = true
	_typing = false
	var fade_out: Tween = create_tween().set_parallel()
	fade_out.tween_property(illustration, "modulate:a", 0.0, fade_out_duration)
	fade_out.tween_property(dialogue_box, "modulate:a", 0.0, fade_out_duration * 0.5)
	MusicPlayer.fade_out_and_stop(fade_out_duration)
	await fade_out.finished
	GameManager.can_pause = true
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
