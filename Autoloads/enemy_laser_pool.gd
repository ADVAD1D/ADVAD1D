extends Node
## Object pool for enemy (ship/drone) projectiles, to avoid per-shot
const ENEMY_LASER_SCENE: PackedScene = preload("res://Scenes/enemy_laser.tscn")
const PREWARM_COUNT: int = 40

var _available: Array = []

func _ready() -> void:
	for i in PREWARM_COUNT:
		var bullet = ENEMY_LASER_SCENE.instantiate()
		bullet.deactivate()
		_available.append(bullet)

## Takes a bullet, adds it under 'parent' and fires it. If 'origin' (a point
## inside the arena, e.g. the ship center) is given and a wall lies between it
## and the muzzle, the shot is blocked (returns null) so no bullet spawns outside.
func acquire(parent: Node, spawn_position: Vector2, fire_direction: Vector2, origin: Vector2 = Vector2.INF) -> Node:
	if origin != Vector2.INF and _muzzle_behind_wall(parent, origin, spawn_position):
		return null
	var bullet = _take_available()
	parent.add_child(bullet)
	bullet.activate(spawn_position, fire_direction)
	return bullet

func _muzzle_behind_wall(ref_node, from: Vector2, to: Vector2) -> bool:
	var space = ref_node.get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.collide_with_areas = false
	query.collision_mask = 1
	var hit: Dictionary = space.intersect_ray(query)
	return hit and hit.collider is StaticBody2D

## Returns a bullet to the pool. Idempotent (is_active guards double-release).
func release(bullet) -> void:
	if not is_instance_valid(bullet) or not bullet.is_active:
		return
	bullet.deactivate()
	# Defer the reparent: don't touch the tree during an area_entered signal.
	call_deferred("_recycle", bullet)

func _take_available() -> Node:
	# Skip dead refs (freed by a scene reload); instantiate if none left.
	while not _available.is_empty():
		var bullet = _available.pop_back()
		if is_instance_valid(bullet):
			return bullet
	return ENEMY_LASER_SCENE.instantiate()

func _recycle(bullet) -> void:
	if not is_instance_valid(bullet):
		return
	var parent = bullet.get_parent()
	if parent != null:
		parent.remove_child(bullet)
	if not _available.has(bullet):
		_available.append(bullet)
