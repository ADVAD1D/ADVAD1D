extends Node2D

@export var pickup_scene: PackedScene 
@export var reward_scene: PackedScene 

@export var spawn_locator: PathFollow2D 

@onready var timer = $Timer

func _ready() -> void:
	timer.timeout.connect(_on_timer_timeout)

func _on_timer_timeout():
	spawn_locator.progress_ratio = randf()
	var spawn_position = spawn_locator.global_position

	var pickup_instance = pickup_scene.instantiate()

	pickup_instance.reward_scene = reward_scene

	add_child(pickup_instance)
	pickup_instance.global_position = spawn_position
