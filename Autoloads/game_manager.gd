extends Node

var score: int = 0

func _ready() -> void:
	pass 

func _process(_delta: float) -> void:
	pass

func add_score(points):
	score += points

func reset_score() -> void:
	score = 0
