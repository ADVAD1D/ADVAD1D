extends Node2D
@export var enemy_scene: PackedScene
@export var portal_scene: PackedScene
@export var player_node: CharacterBody2D
@export var spawn_locator_node: PathFollow2D
## No ship appears closer than this to the player (world units; the arenas' camera zoom is
## 0.25, so 500 is about 125 screen pixels). Rejected points retry every RETRY_DELAY.
@export var safe_spawn_radius: float = 500.0
@export var spawn_timeout: float = 1.0

var max_enemies: int = 4
var current_enemy_count: int = 0
var screen_size: Vector2

var is_active: bool = true

var enemy_current_config = {}
## Bumped by every new wave (phase start). A ship killed by the player just before the phase
## ended emits `died` after its explosion sound, once the new wave is already counted: its
## generation no longer matches, so it isn't subtracted from the new count (otherwise each
## phase left one extra ship, and they piled up in arcade's high phases).
var _generation: int = 0
## Delay between spawn attempts while the wave isn't full (spawn_enemy() rejects points too
## close to the player or to another ship).
const RETRY_DELAY: float = 0.25
var _refilling: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	screen_size = get_viewport().get_visible_rect().size

func spawn_initial_wave():
	_generation += 1
	current_enemy_count = 0
	get_tree().call_group("enemies", "die_silently")
	var max_initial_attempts = 100 
	var current_attempts = 0

	while current_enemy_count < max_enemies and current_attempts < max_initial_attempts:
		var prev_count = current_enemy_count
		spawn_enemy()
		current_attempts += 1
		
		# OPTIMIZATION: Yield slightly if an enemy was successfully spawned.
		# Staggering instantiation across multiple frames prevents massive CPU spikes
		# and stuttering on mobile devices when loading a new phase.
		if current_enemy_count > prev_count:
			await get_tree().process_frame
	# If the attempts ran out before the wave was full, keep trying
	_refill()

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
		_log_message("Spawn Cancel: the random point in the safe radius is near")
		return
		
	var cur_sep_radius = enemy_current_config.get("separation_radius", safe_spawn_radius)
	var existing_enemies = get_tree().get_nodes_in_group("enemies")
	for e in existing_enemies:
		# Arena 2's wall guns are in "enemies" too, but they don't take part in the ships'
		# separation (they only blocked spawn points along the walls)
		if is_instance_valid(e) and not e.is_queued_for_deletion() and not e.is_in_group("laser_guns"):
			if spawn_position.distance_to(e.global_position) < cur_sep_radius * 1.5:
				_log_message("Spawn Cancel: too close to another enemy")
				return
		
	if portal_scene != null:
		var portal_instance = portal_scene.instantiate()
		call_deferred("add_child", portal_instance)
		portal_instance.set_deferred("global_position", spawn_position)
	
	var enemy_instance = enemy_scene.instantiate()
	enemy_instance.add_to_group("enemies")
	call_deferred("add_child", enemy_instance)
	enemy_instance.global_position = spawn_position
	
	#logica del update de la dificultad
	if not enemy_current_config.is_empty():
		enemy_instance.setup(enemy_current_config)
		
	enemy_instance.died.connect(_on_enemy_died.bind(_generation))
	current_enemy_count += 1

func stop():
	is_active = false
	_log_message("Ship enemies spawner STOPEED")

func _on_enemy_died(_enemy_reference, generation: int):
	# A ship from an earlier wave: the current count doesn't include it
	if generation != _generation:
		return
	current_enemy_count = maxi(current_enemy_count - 1, 0)
	if not is_active:
		return
	await get_tree().create_timer(spawn_timeout, false).timeout
	_refill()

## Spawns ships until the wave is back to max_enemies (the phase's fixed count). A single
## try per death used to lose that ship for the rest of the phase whenever the random
## point was rejected, so it retries every RETRY_DELAY. Only one loop runs at a time; it
## always fills the current wave, so a new phase starting meanwhile is fine.
func _refill() -> void:
	if _refilling:
		return
	_refilling = true
	while is_active and is_inside_tree() and current_enemy_count < max_enemies:
		var before: int = current_enemy_count
		spawn_enemy()
		if current_enemy_count > before:
			# Wait for it to enter the tree, so the next one keeps its distance from it
			await get_tree().process_frame
		else:
			await get_tree().create_timer(RETRY_DELAY, false).timeout
	_refilling = false

func _log_message(message):
	if GameManager.is_debug_text == true:
		var final_string = ""
		if typeof(message) == TYPE_ARRAY:
			for arg in message:
				final_string += str(arg) + " "
			final_string = final_string.strip_edges()
		else:
			final_string = str(message)
		print_rich("[color=yellow][DEV LOG][/color] " + final_string)
	else:
		return
