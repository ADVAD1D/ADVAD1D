extends Node2D

@export var drones: Array[AnimatedSprite2D]
@export var traverse_time: float = 6.0
@export var spawn_delay_min: float = 1.0
@export var spawn_delay_max: float = 3.0
@export var shoot_interval: float = 0.5
@export var spawn_distance_x: float = 6000.0 # Adjust according to the arena size

var current_drone: AnimatedSprite2D = null
var is_moving: bool = false
@onready var shoot_timer: Timer = Timer.new()
@onready var respawn_timer: Timer = Timer.new()

var green_material: ShaderMaterial

func _ready() -> void:
	# Create a shader to convert color without losing quality
	var shader = Shader.new()
	shader.code = "shader_type canvas_item; void fragment() { vec4 c = texture(TEXTURE, UV); COLOR = vec4(c.g, c.r, c.b, c.a); }"
	green_material = ShaderMaterial.new()
	green_material.shader = shader
	
	for drone in drones:
		if is_instance_valid(drone):
			drone.visible = false
			drone.play()
	
	add_child(shoot_timer)
	shoot_timer.wait_time = shoot_interval
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	
	add_child(respawn_timer)
	respawn_timer.one_shot = true
	respawn_timer.timeout.connect(_spawn_random_drone)
	
	# Play de cycle
	_spawn_random_drone()

func _spawn_random_drone() -> void:
	if drones.is_empty(): return
	
	# Choose a random drone
	current_drone = drones.pick_random()
	if not is_instance_valid(current_drone): return
	
	var from_left = randi() % 2 == 0
	var start_x = -spawn_distance_x if from_left else spawn_distance_x
	var target_x = spawn_distance_x if from_left else -spawn_distance_x
	
	current_drone.position.x = start_x
	current_drone.visible = true
	is_moving = true
	shoot_timer.start()
	
	var tween = create_tween()
	tween.tween_property(current_drone, "position:x", target_x, traverse_time)
	tween.tween_callback(_on_drone_finished)

func _on_drone_finished() -> void:
	is_moving = false
	shoot_timer.stop()
	if is_instance_valid(current_drone):
		current_drone.visible = false
	
	# Time delay to drones
	respawn_timer.start(randf_range(spawn_delay_min, spawn_delay_max))

func _on_shoot_timer_timeout() -> void:
	if is_moving and is_instance_valid(current_drone) and current_drone.visible:
		var marker = null
		for child in current_drone.get_children():
			if child is Marker2D:
				marker = child
				break
		
		var spawn_pos = marker.global_position if marker else current_drone.global_position
		_shoot_laser(spawn_pos)

func _shoot_laser(spawn_pos: Vector2) -> void:
	if EnemyLaserPool:
		var laser = EnemyLaserPool.acquire(get_tree().current_scene, spawn_pos, Vector2.DOWN)
		if laser:
			if laser.has_node("Sprite2D"):
				laser.get_node("Sprite2D").material = green_material
			if laser.has_node("PointLight2D"):
				laser.get_node("PointLight2D").color = Color(0.0, 1.0, 0.0)
		else:
			pass
