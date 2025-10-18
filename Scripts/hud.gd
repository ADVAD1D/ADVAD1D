extends Control

@onready var objective_label: Label = $ObjectiveLabel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var phase_manager = get_tree().root.get_node("Main/PhaseNode") # Replace with function body.
	
	if phase_manager:
		phase_manager.phase_started.connect(_on_phase_started)
	else:
		print("Error, no se pudo encontrar el Phase Manager")

func _on_phase_started(_phase_number: int, score_requirement: int):
	objective_label.text = "> " + str(score_requirement)
