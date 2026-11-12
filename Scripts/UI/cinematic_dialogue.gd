class_name CinematicDialogue
extends Control
## Dialogue box for the cinematics (Scenes/UI/cinematic_dialogue.tscn), anchored to the
## bottom of the screen.
##
## play() opens it and types each line with a blip. Enter (the "Skip" action) or a tap
## first completes the line being typed, then goes to the next one; a blinking ">" shows
## when a line is complete. After the last line it emits `finished` and stays open: the
## cinematic calls close() as part of its own fade out.

signal finished

@export var speaker_name: String = "COMMANDER"
## Typing speed of the text.
@export var characters_per_second: float = 38.0
## A blip every this many typed characters (0 = silent).
@export var type_sound_every: int = 3
## Seconds the box takes to appear.
@export var open_duration: float = 0.4

## Presses closer than this are ignored, so a single tap can't advance twice.
const PRESS_COOLDOWN: float = 0.15

var _lines: PackedStringArray = []
var _line_index: int = -1
var _active: bool = false
var _typing: bool = false
var _typed: float = 0.0
var _last_press: float = -1.0

@onready var name_label: Label = %NameLabel
@onready var text_label: Label = %TextLabel
@onready var next_arrow: Label = %NextArrow
@onready var type_sound: AudioStreamPlayer = $TypeSound
@onready var next_sound: AudioStreamPlayer = $NextSound


func _ready() -> void:
	modulate.a = 0.0
	name_label.text = speaker_name
	text_label.text = ""
	next_arrow.visible = false
	var arrow_blink: Tween = create_tween().set_loops()
	arrow_blink.tween_property(next_arrow, "modulate:a", 0.15, 0.4)
	arrow_blink.tween_property(next_arrow, "modulate:a", 1.0, 0.4)


## Opens the box and starts with the first line. An empty `speaker` keeps speaker_name.
## Every "soldier" (the word alone, not "soldiers") becomes "soldier <pilot name>", the
## name typed in the skin selector (GameManager.player_name). No name: it stays "soldier".
func _with_pilot_name(lines: PackedStringArray) -> PackedStringArray:
	var pilot: String = GameManager.player_name.strip_edges()
	if pilot.is_empty():
		return lines
	var word: RegEx = RegEx.create_from_string("(?i)\\bsoldier\\b")
	var result: PackedStringArray = []
	for line in lines:
		# Built by hand (not RegEx.sub) so a "$" in the name isn't read as a group
		var out: String = ""
		var last: int = 0
		for found in word.search_all(line):
			out += line.substr(last, found.get_end() - last) + " " + pilot
			last = found.get_end()
		result.append(out + line.substr(last))
	return result


func play(lines: PackedStringArray, speaker: String = "") -> void:
	if not speaker.is_empty():
		speaker_name = speaker
	name_label.text = speaker_name
	_lines = _with_pilot_name(lines)
	_line_index = -1
	var open: Tween = create_tween()
	open.tween_property(self, "modulate:a", 1.0, open_duration)
	await open.finished
	_active = true
	_next_line()


## Stops the dialogue and fades the box out.
func close(duration: float = 0.4) -> void:
	_active = false
	_typing = false
	create_tween().tween_property(self, "modulate:a", 0.0, duration)


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
	if not _active:
		return
	# Mouse clicks also arrive as touches (emulate_touch_from_mouse), so this covers both
	var pressed: bool = event.is_action_pressed("Skip") \
			or (event is InputEventScreenTouch and event.pressed)
	if not pressed:
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
	if _line_index >= _lines.size():
		_active = false
		finished.emit()
		return
	text_label.text = _lines[_line_index]
	text_label.visible_characters = 0
	_typed = 0.0
	_typing = true
	next_arrow.visible = false


func _end_typing() -> void:
	_typing = false
	text_label.visible_characters = -1
	next_arrow.visible = true
