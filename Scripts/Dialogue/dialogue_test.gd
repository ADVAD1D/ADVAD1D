extends Node2D
## Test scene for the dialogue prototype. Open Scenes/dialogue_test.tscn and press F6.

@export var dialogue_resource: DialogueResource
@export var start_from_title: String = "start"

var _balloon: DialogueBalloon

@onready var hint_label: Label = $UI/HintLabel


func _ready() -> void:
	_start_dialogue()


func _unhandled_input(event: InputEvent) -> void:
	if _balloon == null and event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		_start_dialogue()


func _start_dialogue() -> void:
	hint_label.hide()
	_balloon = DialogueBalloon.open(dialogue_resource, start_from_title)
	await _balloon.dialogue_finished
	_balloon = null
	hint_label.show()
