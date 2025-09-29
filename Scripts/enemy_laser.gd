extends Area2D

@export var speed = 1400
@export var enemy_laser_particles: PackedScene
var direction = Vector2.ZERO

# Called when the node enters the scene tree for the first time.
func start(start_direction: Vector2):
	direction = start_direction
	#con .RIGHT se siguen disparando mal en drone
	rotation = direction.angle()  

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	position += direction * speed * delta
  
func _on_area_entered(area: Area2D) -> void:
	if (area.is_in_group("lasers") or area.is_in_group("enemies_death")):
		queue_free() # Replace with function body.
