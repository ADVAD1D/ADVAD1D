extends Area2D

@export var speed = 2100
@export var enemy_laser_particles: PackedScene
var direction = Vector2.ZERO

# Called when the node enters the scene tree for the first time.
func start(start_direction: Vector2):
	direction = start_direction
	rotation = direction.angle() + PI / 2

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	position += direction * speed * delta

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("asteroides"):
		queue_free() # Replace with function body.
	if area.is_in_group("enemy_laser"):
		
		if enemy_laser_particles:
			var enemy_particles_instance = enemy_laser_particles.instantiate()
			get_parent().add_child(enemy_particles_instance)
			enemy_particles_instance.global_position = (global_position + area.global_position) / 2
			
		area.queue_free()
		queue_free()
