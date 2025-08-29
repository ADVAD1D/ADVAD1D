extends Camera2D

@export var player_target: Node2D
@export var smoothness: float = 0.5


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if is_instance_valid(player_target):
		global_position = global_position.lerp(player_target.global_position, smoothness)
