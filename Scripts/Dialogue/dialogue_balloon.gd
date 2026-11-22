class_name DialogueBalloon
extends CanvasLayer
## Reusable dialogue balloon for Dialogue Manager (prototype).
##
## From code:
##     DialogueBalloon.open(preload("res://Dialogues/prototype.dialogue"), "start")
##     await balloon.dialogue_finished   # optional
##
## Or drop Scenes/UI/dialogue_balloon.tscn into a scene, assign
## `dialogue_resource` and enable `auto_start`.

## Emitted when the conversation reaches its end and the balloon closes.
signal dialogue_finished

const SCENE_PATH: String = "res://Scenes/UI/dialogue_balloon.tscn"

## The dialogue resource (.dialogue file).
@export var dialogue_resource: DialogueResource
## Title (~ title) to start from.
@export var start_from_title: String = ""
## Start on _ready when the balloon is placed directly in a scene.
@export var auto_start: bool = false
## Pause the game while the dialogue is open. The balloon keeps working
## because it runs with PROCESS_MODE_ALWAYS.
@export var pause_game: bool = true
## Action that advances to the next line / confirms a response.
@export var next_action: StringName = &"ui_accept"
## Action that skips the typewriter effect.
@export var skip_action: StringName = &"ui_cancel"

## Game states passed to Dialogue Manager (this balloon + any extra ones).
var temporary_game_states: Array = []
## True when the current line is fully shown and waits for the player.
var is_waiting_for_input: bool = false
## True while a blocking mutation runs, so the balloon hides briefly.
var will_hide_balloon: bool = false
## The current line. Setting it to null ends the dialogue.
var dialogue_line: DialogueLine:
	set(value):
		if value:
			dialogue_line = value
			apply_dialogue_line()
		else:
			_finish()
	get:
		return dialogue_line

var _was_paused: bool = false
var _could_pause: bool = true
var _is_running: bool = false
var _mutation_cooldown: Timer = Timer.new()

@onready var balloon: Control = %Balloon
@onready var character_label: RichTextLabel = %CharacterLabel
@onready var dialogue_label: DialogueLabel = %DialogueLabel
@onready var responses_menu: DialogueResponsesMenu = %ResponsesMenu
@onready var progress: Polygon2D = %Progress


## Create a balloon and start a dialogue in the current scene.
static func open(
	resource: DialogueResource,
	title: String = "",
	extra_game_states: Array = [],
	pause: bool = true
) -> DialogueBalloon:
	var new_balloon := load(SCENE_PATH).instantiate() as DialogueBalloon
	new_balloon.pause_game = pause
	DialogueManager.show_dialogue_balloon_scene(new_balloon, resource, title, extra_game_states)
	return new_balloon


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	balloon.hide()
	DialogueManager.mutated.connect(_on_mutated)

	if responses_menu.next_action.is_empty():
		responses_menu.next_action = next_action
	dialogue_label.skip_action = skip_action

	_mutation_cooldown.one_shot = true
	_mutation_cooldown.timeout.connect(_on_mutation_cooldown_timeout)
	add_child(_mutation_cooldown)

	if auto_start:
		if not is_instance_valid(dialogue_resource):
			push_error("DialogueBalloon: auto_start is on but there is no dialogue_resource.")
			return
		start()


func _exit_tree() -> void:
	# Never leave the game paused if the balloon is freed mid-dialogue.
	if _is_running:
		_restore_game_state()


func _process(_delta: float) -> void:
	if is_instance_valid(dialogue_line):
		progress.visible = (
			is_waiting_for_input
			and not dialogue_label.is_typing
			and dialogue_line.responses.is_empty()
		)


func _input(event: InputEvent) -> void:
	# Block the pause menu while a pausing dialogue is open.
	if _is_running and pause_game and event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()


func _unhandled_input(_event: InputEvent) -> void:
	# Only the balloon handles input while it is showing.
	if _is_running:
		get_viewport().set_input_as_handled()


## Start a dialogue. Called by Dialogue Manager or by auto_start.
func start(
	with_dialogue_resource: DialogueResource = null,
	title: String = "",
	extra_game_states: Array = []
) -> void:
	if is_instance_valid(with_dialogue_resource):
		dialogue_resource = with_dialogue_resource
	if not title.is_empty():
		start_from_title = title

	temporary_game_states = [self] + extra_game_states
	is_waiting_for_input = false

	if not _is_running:
		_is_running = true
		_apply_game_state()

	show()
	dialogue_line = await dialogue_resource.get_next_dialogue_line(
		start_from_title, temporary_game_states
	)


## Show a new line in the balloon.
func apply_dialogue_line() -> void:
	_mutation_cooldown.stop()

	progress.hide()
	is_waiting_for_input = false
	balloon.focus_mode = Control.FOCUS_ALL
	balloon.grab_focus()

	character_label.visible = not dialogue_line.character.is_empty()
	character_label.text = tr(dialogue_line.character, "dialogue")

	dialogue_label.hide()
	dialogue_label.dialogue_line = dialogue_line

	responses_menu.hide()
	responses_menu.responses = dialogue_line.responses

	balloon.show()
	will_hide_balloon = false

	dialogue_label.show()
	if not dialogue_line.text.is_empty():
		dialogue_label.type_out()
		await dialogue_label.finished_typing

	if dialogue_line.responses.size() > 0:
		balloon.focus_mode = Control.FOCUS_NONE
		responses_menu.show()
	elif dialogue_line.time != "":
		var wait_time: float = (
			dialogue_line.text.length() * 0.02
			if dialogue_line.time == "auto"
			else dialogue_line.time.to_float()
		)
		await get_tree().create_timer(wait_time, true).timeout
		next(dialogue_line.next_id)
	else:
		is_waiting_for_input = true
		balloon.focus_mode = Control.FOCUS_ALL
		balloon.grab_focus()


## Go to the next line.
func next(next_id: String) -> void:
	dialogue_line = await dialogue_resource.get_next_dialogue_line(
		next_id, temporary_game_states
	)


func _finish() -> void:
	if not _is_running:
		return
	_is_running = false
	_restore_game_state()
	_log_message(["Dialogue finished:", start_from_title])
	dialogue_finished.emit()

	# Spawned from code: free it. Placed in a scene: just hide it for reuse.
	if owner == null:
		queue_free()
	else:
		balloon.hide()
		hide()


func _apply_game_state() -> void:
	if not pause_game:
		return
	_was_paused = get_tree().paused
	_could_pause = GameManager.can_pause
	GameManager.can_pause = false
	get_tree().paused = true


func _restore_game_state() -> void:
	if not pause_game:
		return
	if is_inside_tree():
		get_tree().paused = _was_paused
	GameManager.can_pause = _could_pause


#region Signals


func _on_mutation_cooldown_timeout() -> void:
	if will_hide_balloon:
		will_hide_balloon = false
		balloon.hide()


func _on_mutated(mutation: Dictionary) -> void:
	if not _is_running:
		return
	if not mutation.is_inline:
		is_waiting_for_input = false
		will_hide_balloon = true
		_mutation_cooldown.start(0.1)


func _on_balloon_gui_input(event: InputEvent) -> void:
	# Skip the typewriter effect
	if dialogue_label.is_typing:
		var mouse_was_clicked: bool = (
			event is InputEventMouseButton
			and event.button_index == MOUSE_BUTTON_LEFT
			and event.is_pressed()
		)
		var key_was_pressed: bool = (
			event.is_action_pressed(skip_action) or event.is_action_pressed(next_action)
		)
		if mouse_was_clicked or key_was_pressed:
			get_viewport().set_input_as_handled()
			dialogue_label.skip_typing()
			return

	if not is_waiting_for_input:
		return
	if dialogue_line.responses.size() > 0:
		return

	get_viewport().set_input_as_handled()

	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		next(dialogue_line.next_id)
	elif event.is_action_pressed(next_action) and get_viewport().gui_get_focus_owner() == balloon:
		next(dialogue_line.next_id)


func _on_responses_menu_response_selected(response: DialogueResponse) -> void:
	next(response.next_id)


#endregion


func _log_message(message) -> void:
	if GameManager.is_debug_text == true:
		var final_string: String = ""
		if typeof(message) == TYPE_ARRAY:
			for arg in message:
				final_string += str(arg) + " "
			final_string = final_string.strip_edges()
		else:
			final_string = str(message)
		print_rich("[color=yellow][DEV LOG][/color] " + final_string)
