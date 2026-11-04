class_name LaserGunSpawner
extends Node2D
## Places arena 2's laser guns (Scenes/laser_gun.tscn, LaserGun) on the side walls.
## PhaseManager calls configure_for_phase(count, config) at every phase start (count comes
## from the arena config's "laser_guns" table); a destroyed gun comes back after
## respawn_delay. Keep this node at the origin: the wall values are global coordinates.

@export var gun_scene: PackedScene
@export var player_node: Node2D
## Global x where the back of the gun's mount goes on each side wall. Taken from the wall
## lines drawn in arena2.png (texture columns 59-60 and 343-344, about -1360 / 1369 in the
## world; the colliders sit further in), a few units inside so the mount looks bolted on.
@export var left_wall_x: float = -1364.0
@export var right_wall_x: float = 1373.0
## Global y range the guns patrol (centre of the gun).
@export var top_y: float = -1070.0
@export var bottom_y: float = 1180.0
## Distance from the gun's centre to the back of its wall mount (sprite pixels x scale).
@export var mount_offset: float = 81.0
## A new gun doesn't appear closer than this (vertically) to the player.
@export var player_clearance: float = 350.0
@export var respawn_delay: float = 3.0

var max_guns: int = 0
var gun_config: Dictionary = {}
var is_active: bool = true
## Live guns on each wall: [left, right]
var _per_side: Array[int] = [0, 0]
## Bumped every phase, so a gun from the previous phase dying late doesn't count.
var _generation: int = 0


func configure_for_phase(new_max_guns: int, new_config: Dictionary) -> void:
	max_guns = new_max_guns
	gun_config = new_config
	get_tree().call_group("laser_guns", "die_silently")
	_per_side = [0, 0]
	_generation += 1
	for i in max_guns:
		_spawn_gun()


func stop() -> void:
	is_active = false


func _live_guns() -> int:
	return _per_side[0] + _per_side[1]


func _spawn_gun() -> void:
	if not is_active or gun_scene == null or _live_guns() >= max_guns:
		return
	# The wall with fewer guns (random on a tie)
	var side: int = randi() % 2
	if _per_side[0] != _per_side[1]:
		side = 0 if _per_side[0] < _per_side[1] else 1
	var facing: int = 1 if side == 0 else -1

	var gun: LaserGun = gun_scene.instantiate()
	gun.facing = facing
	gun.top_limit = top_y
	gun.bottom_limit = bottom_y
	var wall_x: float = left_wall_x if side == 0 else right_wall_x
	gun.position = Vector2(wall_x + mount_offset * facing, _pick_height())
	gun.setup(gun_config)
	gun.add_to_group("enemies")
	gun.died.connect(_on_gun_died.bind(side, _generation))
	_per_side[side] += 1
	call_deferred("add_child", gun)


## A random height on the wall, away from the player's so it can't appear right on them.
func _pick_height() -> float:
	var y: float = randf_range(top_y, bottom_y)
	if not is_instance_valid(player_node):
		return y
	for i in 10:
		if absf(y - player_node.global_position.y) >= player_clearance:
			break
		y = randf_range(top_y, bottom_y)
	return y


func _on_gun_died(_gun: LaserGun, side: int, generation: int) -> void:
	if generation != _generation:
		return
	_per_side[side] = maxi(_per_side[side] - 1, 0)
	if not is_active:
		return
	await get_tree().create_timer(respawn_delay, false).timeout
	if generation == _generation:
		_spawn_gun()
