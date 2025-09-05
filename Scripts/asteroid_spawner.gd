extends Marker2D

@export var asteroid_scene: PackedScene 
@export var spawn_margin: float = 1200.0
@export var target_radius: float = 250.0
@export var player_node: CharacterBody2D
@export var safe_radius: float = 1250.0

func create_asteroid():
	if not is_instance_valid(player_node):
		return
		
	var viewport_rect = get_viewport().get_visible_rect()
	var center = viewport_rect.size / 2
	var spawn_radius = viewport_rect.size.length() / 2 + spawn_margin 
	var random_angle = randf_range(0, TAU)
	var spawn_position = center + Vector2.RIGHT.rotated(random_angle) * spawn_radius
	
	var distance_to_player = spawn_position.distance_to(player_node.global_position)
	
	if distance_to_player < safe_radius:
		var direction_from_player = (spawn_position - player_node.global_position).normalized()
		spawn_position = player_node.global_position + direction_from_player * safe_radius 
	
	var asteroid_instance: Area2D = asteroid_scene.instantiate()
	get_parent().add_child(asteroid_instance)
	asteroid_instance.global_position = spawn_position
	
	var random_offset = Vector2(
		randf_range(-target_radius, target_radius),
		randf_range(-target_radius, target_radius)
	)
	
	var final_target = center + random_offset
	
	asteroid_instance.start(final_target)

func _on_timer_timeout() -> void:
	create_asteroid()
