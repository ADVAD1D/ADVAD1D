extends Node
## Object pool for enemy ship/drone projectiles (enemy_laser).
##
## Replaces per-shot instantiate()/queue_free(), which thrashes the GC and
## stutters on the web build. Free bullets live OUTSIDE the tree (orphan nodes)
## in _available. As an autoload this survives scene reloads, so parked bullets
## persist; bullets still flying in the old scene die with it.

const ENEMY_LASER_SCENE: PackedScene = preload("res://Scenes/enemy_laser.tscn")
const PREWARM_COUNT: int = 40

# Inactive bullets ready for reuse (NOT in the scene tree).
var _available: Array = []


func _ready() -> void:
	# Prewarm so the first enemy wave doesn't pay instantiation cost mid-gameplay.
	for i in PREWARM_COUNT:
		var bullet = ENEMY_LASER_SCENE.instantiate()
		bullet.deactivate()
		_available.append(bullet)


## Takes a bullet, adds it under 'parent' and fires it.
func acquire(parent: Node, spawn_position: Vector2, fire_direction: Vector2) -> Node:
	var bullet = _take_available()
	parent.add_child(bullet)
	bullet.activate(spawn_position, fire_direction)
	return bullet


## Returns a bullet to the pool. Idempotent: a no-op if already returned.
func release(bullet) -> void:
	if not is_instance_valid(bullet):
		return
	if not bullet.is_active:
		return  # already returned this frame: guard against double-release
	# Mark inactive now (sync) so a second release() this frame hits the guard.
	# Defer the actual reparent: don't touch the tree during area_entered.
	bullet.deactivate()
	call_deferred("_recycle", bullet)


# --- internal ---

func _take_available() -> Node:
	# Skip dead refs (bullet freed by a scene reload); instantiate if none left.
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
