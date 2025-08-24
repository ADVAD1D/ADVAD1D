extends Area2D

@export var speed = 1400
var direction = Vector2.ZERO

# Called when the node enters the scene tree for the first time.
func start(start_rotation):
	rotation = start_rotation
	direction = Vector2.UP.rotated(rotation)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	position += direction * speed * delta


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("asteroides"):
		queue_free() # Replace with function body.
