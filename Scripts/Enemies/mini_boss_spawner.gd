extends Node2D
## Arcade arena 3: brings the small GEMELA (Scenes/Enemies/gemela_mini.tscn) along with the
## usual enemies. PhaseManager calls configure_for_phase(count, config) at every phase
## start (count from the arena config's "mini_boss" table, like the laser guns); a destroyed
## one comes back after respawn_delay. It appears at a random point of spawn_locator's path
## (the enemies' spawn path), away from the player.

@export var mini_scene: PackedScene
@export var player_node: Node2D
@export var spawn_locator: PathFollow2D
## A new one doesn't appear closer than this to the player.
@export var player_clearance: float = 900.0
@export var respawn_delay: float = 6.0

var max_minis: int = 0
var mini_config: Dictionary = {}
var is_active: bool = true
var _alive: int = 0
## Bumped every phase, so one from the previous phase dying late doesn't count.
var _generation: int = 0


func configure_for_phase(new_max: int, new_config: Dictionary) -> void:
	max_minis = new_max
	mini_config = new_config
	get_tree().call_group("mini_bosses", "die_silently")
	_alive = 0
	_generation += 1
	for i in max_minis:
		_spawn()


func stop() -> void:
	is_active = false


func _spawn() -> void:
	if not is_active or mini_scene == null or _alive >= max_minis:
		return
	# Untyped: it's a saw_boss.gd scene (its `died` signal and setup())
	var boss = mini_scene.instantiate()
	boss.position = _pick_point()
	if boss.has_method("setup"):
		boss.setup(mini_config)
	boss.add_to_group("enemies")
	boss.add_to_group("mini_bosses")
	boss.died.connect(_on_died.bind(_generation))
	_alive += 1
	get_parent().call_deferred("add_child", boss)


## A point of the spawn path away from the player (the farthest of a few tries).
func _pick_point() -> Vector2:
	if spawn_locator == null:
		return global_position
	var best: Vector2 = spawn_locator.global_position
	var best_distance: float = -1.0
	for i in 8:
		spawn_locator.progress_ratio = randf()
		var point: Vector2 = spawn_locator.global_position
		if not is_instance_valid(player_node):
			return point
		var distance: float = point.distance_to(player_node.global_position)
		if distance >= player_clearance:
			return point
		if distance > best_distance:
			best_distance = distance
			best = point
	return best


func _on_died(_boss: Node, generation: int) -> void:
	if generation != _generation:
		return
	_alive = maxi(_alive - 1, 0)
	if not is_active:
		return
	await get_tree().create_timer(respawn_delay, false).timeout
	if generation == _generation:
		_spawn()
