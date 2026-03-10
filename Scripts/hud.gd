extends Control

@onready var objective_label: Label = $ObjectiveLabel
@onready var speedrun_label: Label = $SpeedrunLabel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var phase_manager = get_tree().root.get_node("Main/PhaseNode") # Replace with function body.
	if not GameManager.speedrun_mode_active:
		speedrun_label.hide()
	else:
		speedrun_label.show()
		
	if phase_manager:
		phase_manager.phase_started.connect(_on_phase_started)
	else:
		print("Error, no se pudo encontrar el Phase Manager")

func _on_phase_started(_phase_number: int, score_requirement: int):
	objective_label.text = "> " + str(score_requirement)

func _process(_delta: float) -> void:
	if GameManager.speedrun_mode_active:
		speedrun_label.text = GameManager.get_formatted_speedrun_time()
