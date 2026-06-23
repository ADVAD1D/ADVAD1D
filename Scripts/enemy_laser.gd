extends Area2D

@export var speed = 1400
@export var enemy_laser_particles: PackedScene
var direction = Vector2.ZERO

# True while in use. Pool uses it as a double-release guard.
var is_active: bool = false


# Called by the pool on acquire: place, orient and switch on.
func activate(spawn_position: Vector2, start_direction: Vector2) -> void:
	global_position = spawn_position
	set_direction(start_direction)
	is_active = true
	show()
	set_process(true)
	# Deferred: can't toggle monitoring from inside _physics_process.
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)


# Switch off and ready the bullet for parking in the pool.
func deactivate() -> void:
	is_active = false
	direction = Vector2.ZERO
	set_process(false)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	hide()


# Kept for compatibility: used by laser_shield on reflect.
func start(start_direction: Vector2):
	set_direction(start_direction)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	position += direction * speed * delta

func set_direction(new_direction: Vector2):
	direction = new_direction
	rotation = direction.angle()

func _on_area_entered(area: Area2D) -> void:
	if (area.is_in_group("lasers") or area.is_in_group("enemies_death")):
		EnemyLaserPool.release(self)  # return to pool instead of queue_free()
