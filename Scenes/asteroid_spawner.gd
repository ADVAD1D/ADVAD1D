extends Marker2D

@export var asteroid_scene: PackedScene 
@export var spawn_margin: float = 1680.0
@export var target_radius: float = 250.0
@export var player_node: CharacterBody2D
@export var safe_radius: float = 200.0

var screen_size: Vector2

func _ready() -> void:
	screen_size = get_viewport().get_visible_rect().size

func create_asteroid():
	
	if not is_instance_valid(player_node):
		return
	var spawn_position: Vector2
	var is_position_safe: bool = false
	var center = screen_size / 2
		
	while not is_position_safe:
		var spawn_radius = center.length() + spawn_margin
		var random_angle = randf_range(0, TAU)
		spawn_position = center + Vector2.RIGHT.rotated(random_angle) * spawn_radius
			
		if spawn_position.distance_to(player_node.global_position) > safe_radius:
			is_position_safe = true
				
				
	var asteroid_instance: Area2D = asteroid_scene.instantiate()
	get_parent().add_child(asteroid_instance)
	asteroid_instance.position = spawn_position
	
	var random_offset = Vector2(
		randf_range(-target_radius, target_radius),
		randf_range(-target_radius, target_radius)
	)
	
	var final_target = center + random_offset
	
	asteroid_instance.start(final_target)

func _on_timer_timeout() -> void:
	create_asteroid()
