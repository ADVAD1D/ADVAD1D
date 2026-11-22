extends Node2D
## Scanner powerup spawner (ScannerSpawner node in the arenas). The only powerup that
## doesn't come on a timer: every check_interval seconds (game time) it rolls a chance that
## grows from start_chance to max_chance over ramp_time seconds since the last drop, so it's
## rare right after one and more and more likely the longer it takes. When the roll hits it
## drops pickup_scene (scanner_pickup.tscn) at a random point of spawn_locator's path and
## hands it reward_scene (scanner.tscn). No rolls while a scanner pickup is on the field or
## the player still has one (the ramp starts again after).

@export var pickup_scene: PackedScene
@export var reward_scene: PackedScene
@export var spawn_locator: PathFollow2D
## Seconds between rolls.
@export var check_interval: float = 1.0
## Chance per roll right after a drop...
@export_range(0.0, 1.0) var start_chance: float = 0.01
## ...growing to this one after ramp_time seconds.
@export_range(0.0, 1.0) var max_chance: float = 0.2
@export var ramp_time: float = 40.0

var _since_drop: float = 0.0
var _until_roll: float = 0.0
var _pickup: Node = null


func _ready() -> void:
	add_to_group("powerup_spawners")
	_until_roll = check_interval


## Called through the powerup_spawners group when the arena is won.
func stop() -> void:
	set_process(false)


func _process(delta: float) -> void:
	if is_instance_valid(_pickup) or _player_has_scanner():
		_since_drop = 0.0
		return
	_since_drop += delta
	_until_roll -= delta
	if _until_roll > 0.0:
		return
	_until_roll = check_interval
	if randf() < get_chance():
		_spawn()


## Chance of the next roll.
func get_chance() -> float:
	return lerpf(start_chance, max_chance, clampf(_since_drop / maxf(ramp_time, 0.01), 0.0, 1.0))


func _spawn() -> void:
	_since_drop = 0.0
	spawn_locator.progress_ratio = randf()
	var pickup_instance: Node2D = pickup_scene.instantiate()
	pickup_instance.set("reward_scene", reward_scene)
	add_child(pickup_instance)
	pickup_instance.global_position = spawn_locator.global_position
	_pickup = pickup_instance
	_log_message(["Scanner dropped at", pickup_instance.global_position])


func _player_has_scanner() -> bool:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return false
	for child in player.get_children():
		if child.is_in_group("player_scanner"):
			return true
	return false


func _log_message(message) -> void:
	if not GameManager.is_debug_text:
		return
	var final_string: String = ""
	if typeof(message) == TYPE_ARRAY:
		for arg in message:
			final_string += str(arg) + " "
		final_string = final_string.strip_edges()
	else:
		final_string = str(message)
	print_rich("[color=yellow][DEV LOG][/color] " + final_string)
