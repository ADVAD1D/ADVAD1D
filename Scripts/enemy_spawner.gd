extends Node2D
@export var enemy_scene: PackedScene
@export var player_node: CharacterBody2D
@export var spawn_locator_node: PathFollow2D
@export var safe_spawn_radius: float = 100.0
@export var spawn_timeout: float = 1.0

var max_enemies: int = 4
var current_enemy_count: int = 0
var screen_size: Vector2

var is_active: bool = true

var enemy_current_config = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	screen_size = get_viewport().get_visible_rect().size
	
func spawn_initial_wave():
	current_enemy_count = 0
	get_tree().call_group("enemies", "die_silently")
	var max_initial_attempts = 100 
	var current_attempts = 0

	while current_enemy_count < max_enemies and current_attempts < max_initial_attempts:
		spawn_enemy()
		current_attempts += 1
		
func configure_for_phase(new_max_enemies: int, new_config: Dictionary):
	max_enemies = new_max_enemies
	enemy_current_config = new_config
	spawn_initial_wave()


func spawn_enemy():
	
	#logica para encontrar la posición del spawn
	if current_enemy_count >= max_enemies or not is_instance_valid(player_node):
		return
	spawn_locator_node.progress_ratio = randf()
	var spawn_position = spawn_locator_node.global_position
	
	if spawn_position.distance_to(player_node.global_position) <= safe_spawn_radius:
		print("Spawn cancelado: el punto aleatorio en el camino estaba muy cerca.")
		return
	
	var enemy_instance = enemy_scene.instantiate()
	enemy_instance.add_to_group("enemies")
	call_deferred("add_child", enemy_instance)
	enemy_instance.global_position = spawn_position
	
	#logica del update de la dificultad
	if not enemy_current_config.is_empty():
		enemy_instance.setup(enemy_current_config)
		
	enemy_instance.died.connect(_on_enemy_died)
	current_enemy_count += 1
	
func stop():
	is_active = false
	print("Spawner de naves enemigas detenido")
	
func _on_enemy_died(_enemy_reference):
	
	if not is_active:
		current_enemy_count -= 1
		return
	
	current_enemy_count -= 1
	await get_tree().create_timer(spawn_timeout).timeout
	spawn_enemy()
