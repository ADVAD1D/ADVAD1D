class_name DialogueTrigger
extends Area2D
## Starts a dialogue when the player enters the area.
## Drop Scenes/dialogue_trigger.tscn in a level, assign `dialogue_resource`
## and resize the CollisionShape2D.

## Emitted when the dialogue started by this trigger ends.
signal dialogue_finished

## The dialogue resource (.dialogue file).
@export var dialogue_resource: DialogueResource
## Title (~ title) to start from.
@export var start_from_title: String = "start"
## Only fire once. If false, it fires again every time the player re-enters.
@export var one_shot: bool = true
## Pause the game while the dialogue is open.
@export var pause_game: bool = true

var _is_active: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _is_active or not body.is_in_group("player"):
		return
	if not is_instance_valid(dialogue_resource):
		push_warning("DialogueTrigger '%s' has no dialogue_resource." % name)
		return

	_is_active = true
	_log_message(["Dialogue trigger fired:", name])
	if one_shot:
		set_deferred("monitoring", false)

	var balloon: DialogueBalloon = DialogueBalloon.open(
		dialogue_resource, start_from_title, [], pause_game
	)
	await balloon.dialogue_finished

	_is_active = false
	dialogue_finished.emit()


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
