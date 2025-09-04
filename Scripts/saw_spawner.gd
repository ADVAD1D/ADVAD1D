class_name SawSpawner 

extends Node2D
@export var saw_scene: PackedScene
@export var player_node: CharacterBody2D
@export var max_enemies: int = 5
@export var spawn_locator_node: PathFollow2D
@export var safe_spawn_radius: float = 100.0
@export var spawn_timeout: float = 1.0

var current_enemy_count: int = 0
var screen_size: Vector2

signal first_saw_spawner

var has_emitted_first_spawn_signal: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	screen_size = get_viewport().get_visible_rect().size
	spawn_initial_wave() # Replace with function body.
	
func spawn_initial_wave():
	var max_initial_attempts = 100 
	var current_attempts = 0

	while current_enemy_count < max_enemies and current_attempts < max_initial_attempts:
		spawn_enemy()
		current_attempts += 1

func spawn_enemy():
	if current_enemy_count >= max_enemies or not is_instance_valid(player_node):
		return
	spawn_locator_node.progress_ratio = randf()
	var spawn_position = spawn_locator_node.global_position
	
	if spawn_position.distance_to(player_node.global_position) <= safe_spawn_radius:
		print("Spawn cancelado: el punto aleatorio en el camino estaba muy cerca.")
		return
	
	var enemy_instance = saw_scene.instantiate()
	get_parent().call_deferred("add_child", enemy_instance)
	if not has_emitted_first_spawn_signal:
		has_emitted_first_spawn_signal = true
		first_saw_spawner.emit.call_deferred()
	
	enemy_instance.global_position = spawn_position
	enemy_instance.died.connect(_on_enemy_died)
	current_enemy_count += 1
	
func _on_enemy_died():
	current_enemy_count -= 1
	await get_tree().create_timer(spawn_timeout).timeout
	spawn_enemy()
