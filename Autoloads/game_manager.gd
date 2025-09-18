extends Node

signal score_updated(new_score)

var score: int = 0
var can_add_score: bool = true
var phase_to_start: int = 1

func _ready() -> void:
	pass 

func _process(_delta: float) -> void:
	pass

func add_score(points):
	score += points
	score_updated.emit(score)
	
func stop_scoring() -> void:
	can_add_score = false

func reset_score() -> void:
	score = 0
	can_add_score = true
	score_updated.emit(score)
