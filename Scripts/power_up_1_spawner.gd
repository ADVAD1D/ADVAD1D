extends Node2D

@export var pickup_scene: PackedScene 
@export var reward_scene: PackedScene 

@export var spawn_locator: PathFollow2D 
## Shop upgrade that makes this powerup spawn more often in arcade mode
## (ShopItem.upgrade_stat: shield, timewarp, ally_saw, quad_laser). Empty = never changes.
@export var upgrade_stat: StringName
## If not empty, every wait picks one of these seconds at random instead of the Timer's
## fixed wait_time (arena 3's ally saw: 5 or 10). The shop upgrade still shortens it.
@export var random_intervals: Array[float] = []

@onready var timer = $Timer

func _ready() -> void:
	add_to_group("powerup_spawners")
	timer.timeout.connect(_on_timer_timeout)
	if not random_intervals.is_empty():
		timer.start(_random_interval())
		return
	var interval: float = ShopManager.get_powerup_interval(upgrade_stat, timer.wait_time)
	if interval != timer.wait_time:
		timer.start(interval)

func _random_interval() -> float:
	return ShopManager.get_powerup_interval(upgrade_stat, random_intervals.pick_random())

func stop() -> void:
	timer.stop()

func _on_timer_timeout():
	spawn_locator.progress_ratio = randf()
	var spawn_position = spawn_locator.global_position

	var pickup_instance = pickup_scene.instantiate()

	pickup_instance.reward_scene = reward_scene

	add_child(pickup_instance)
	pickup_instance.global_position = spawn_position
	if not random_intervals.is_empty() and not timer.is_stopped():
		timer.start(_random_interval())
