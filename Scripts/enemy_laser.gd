extends Area2D

@export var speed = 1400
@export var enemy_laser_particles: PackedScene
var direction = Vector2.ZERO
var is_active: bool = false

func activate(spawn_position: Vector2, start_direction: Vector2) -> void:
	global_position = spawn_position
	set_direction(start_direction)
	modulate = Color.WHITE # Resetear el color general
	
	# Restaurar materiales y luces por si fue usado por un Drone (que lo vuelve verde)
	if has_node("Sprite2D"):
		get_node("Sprite2D").material = null
	if has_node("PointLight2D"):
		get_node("PointLight2D").color = Color.WHITE
		
	is_active = true
	show()
	set_physics_process(true)
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)

func deactivate() -> void:
	is_active = false
	direction = Vector2.ZERO
	set_physics_process(false)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	hide()

# Kept for compatibility: used by laser_shield on reflect.
func start(start_direction: Vector2):
	set_direction(start_direction)

# Raycast the current->next segment so fast bullets can't tunnel through the
# thin arena walls (StaticBody2D, which Area2D never physically stops against).
func _physics_process(delta: float) -> void:
	var motion: Vector2 = direction * speed * delta
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, global_position + motion)
	query.collide_with_areas = false
	query.collision_mask = 1
	var hit: Dictionary = space.intersect_ray(query)
	if hit and hit.collider is StaticBody2D:
		_spawn_impact_particles(hit.position)
		EnemyLaserPool.release(self)
		return
	global_position += motion

# Spawn the impact burst at the wall hit point, parented to the arena so it
# outlives this bullet when it gets recycled back into the pool.
func _spawn_impact_particles(at: Vector2) -> void:
	if not enemy_laser_particles:
		return
	var particles = enemy_laser_particles.instantiate()
	get_parent().add_child(particles)
	particles.global_position = at

func set_direction(new_direction: Vector2):
	direction = new_direction
	rotation = direction.angle()

func _on_area_entered(area: Area2D) -> void:
	if (area.is_in_group("lasers") or area.is_in_group("enemies_death")):
		EnemyLaserPool.release(self)
