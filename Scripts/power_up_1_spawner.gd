extends Node2D

@export var pickup_scene: PackedScene 
@export var reward_scene: PackedScene 

@export var spawn_locator: PathFollow2D 
## Shop upgrade that makes this powerup spawn more often in arcade mode
## (ShopItem.upgrade_stat: shield, timewarp, ally_saw, quad_laser). Empty = never changes.
@export var upgrade_stat: StringName

@onready var timer = $Timer

func _ready() -> void:
	add_to_group("powerup_spawners")
	timer.timeout.connect(_on_timer_timeout)
	var interval: float = ShopManager.get_powerup_interval(upgrade_stat, timer.wait_time)
	if interval != timer.wait_time:
		timer.start(interval)

func stop() -> void:
	timer.stop()

func _on_timer_timeout():
	spawn_locator.progress_ratio = randf()
	var spawn_position = spawn_locator.global_position

	var pickup_instance = pickup_scene.instantiate()

	pickup_instance.reward_scene = reward_scene

	add_child(pickup_instance)
	pickup_instance.global_position = spawn_position
