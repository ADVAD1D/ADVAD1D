extends Node
## Global Object Pool for Enemy Lasers (Autoload).
## Pre-instantiates a set number of lasers at startup and reuses them throughout the game.
## This prevents the performance overhead (stuttering/garbage collection spikes) caused by 
## constantly calling `instantiate()` and `queue_free()` during heavy bullet-hell combat.

const ENEMY_LASER_SCENE: PackedScene = preload("res://Scenes/enemy_laser.tscn")
const PREWARM_COUNT: int = 40

var _available: Array = []

func _ready() -> void:
	for i in PREWARM_COUNT:
		var bullet = ENEMY_LASER_SCENE.instantiate()
		bullet.deactivate()
		_available.append(bullet)

## Retrieves an available laser from the pool, or creates a new one if the pool is empty.
## Optionally performs a raycast to ensure the laser doesn't spawn inside or behind a wall.
func acquire(parent: Node, spawn_position: Vector2, fire_direction: Vector2, origin: Vector2 = Vector2.INF) -> Node:
	if origin != Vector2.INF and _muzzle_behind_wall(parent, origin, spawn_position):
		return null
	var bullet = _take_available()
	parent.add_child(bullet)
	bullet.activate(spawn_position, fire_direction)
	return bullet

func _muzzle_behind_wall(ref_node, from: Vector2, to: Vector2) -> bool:
	var space = ref_node.get_world_2d().direct_space_state
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to)
	query.collide_with_areas = false
	query.collision_mask = 1
	var hit: Dictionary = space.intersect_ray(query)
	# Draw the ray and its hit point in the debug menu (Tab).
	DebugMenu.register_ray(from, to, hit.position if hit else Vector2.INF)
	if hit:
		DebugMenu.register_point(hit.position, Color.ORANGE_RED)
	return hit and hit.collider is StaticBody2D

## Returns a bullet to the pool. Idempotent (is_active guards double-release).
func release(bullet) -> void:
	if not is_instance_valid(bullet) or not bullet.is_active:
		return
	bullet.deactivate()
	# Defer the reparent: don't touch the tree during an area_entered signal.
	call_deferred("_recycle", bullet)

## Internal method to fetch a laser. 
## Skips dead references (e.g., if a laser was freed by a scene reload).
func _take_available() -> Node:
	while not _available.is_empty():
		var bullet = _available.pop_back()
		if is_instance_valid(bullet):
			return bullet
	return ENEMY_LASER_SCENE.instantiate()

## Removes the bullet from the scene tree and pushes it back into the available pool.
func _recycle(bullet) -> void:
	if not is_instance_valid(bullet):
		return
	var parent = bullet.get_parent()
	if parent != null:
		parent.remove_child(bullet)
	if not _available.has(bullet):
		_available.append(bullet)
