extends Node2D
## Quad laser powerup spawner (arena 2, QuadLaserSpawner node).
##
## Every time its Timer runs out it drops pickup_scene (quad_laser_pickup.tscn) at a random
## point of spawn_locator's path and hands it reward_scene (quad_laser.tscn), which the
## pickup puts on the player. In arcade mode the shop's quad laser upgrade
## (quad_laser_spawn.tres, upgrade_stat = quad_laser) shortens the interval.

@export var pickup_scene: PackedScene
@export var reward_scene: PackedScene

@export var spawn_locator: PathFollow2D
## Shop upgrade that makes the quad laser spawn more often in arcade mode
## (ShopItem.upgrade_stat). Empty = never changes.
@export var upgrade_stat: StringName = &"quad_laser"

@onready var timer: Timer = $Timer


func _ready() -> void:
	add_to_group("powerup_spawners")
	timer.timeout.connect(_on_timer_timeout)
	var interval: float = ShopManager.get_powerup_interval(upgrade_stat, timer.wait_time)
	if interval != timer.wait_time:
		timer.start(interval)
	_log_message(["Quad laser spawn interval:", interval])


## Called through the powerup_spawners group when the arena is won.
func stop() -> void:
	timer.stop()


func _on_timer_timeout() -> void:
	spawn_locator.progress_ratio = randf()
	var spawn_position: Vector2 = spawn_locator.global_position

	var pickup_instance = pickup_scene.instantiate()
	pickup_instance.reward_scene = reward_scene

	add_child(pickup_instance)
	pickup_instance.global_position = spawn_position


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
