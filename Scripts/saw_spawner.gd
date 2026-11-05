class_name SawSpawner 
extends Node2D

@export var saw_scene: PackedScene
@export var portal_scene: PackedScene
@export var player_node: CharacterBody2D
@export var spawn_locator_node: PathFollow2D
@export var safe_spawn_radius: float = 100.0
@export var spawn_timeout: float = 1.0

var max_enemies: int = 2
var current_enemy_count: int = 0
var screen_size: Vector2

var is_active: bool = true

var enemy_current_config = {}

signal first_saw_spawner

var has_emitted_first_spawn_signal: bool = false
## Bumped by every new wave (phase start). A saw destroyed just before the phase ended
## emits `died` after its sound, once the new wave is already counted: its generation no
## longer matches, so it isn't subtracted from the new count (otherwise saws piled up).
var _generation: int = 0
## Delay between spawn attempts while the wave isn't full (spawn_enemy() rejects points too
## close to the player).
const RETRY_DELAY: float = 0.25
var _refilling: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	screen_size = get_viewport().get_visible_rect().size # Replace with function body.

func spawn_initial_wave():
	_generation += 1
	current_enemy_count = 0
	get_tree().call_group("saws", "die_silently")
	
	var max_initial_attempts = 100 
	var current_attempts = 0

	while current_enemy_count < max_enemies and current_attempts < max_initial_attempts:
		var prev_count = current_enemy_count
		if spawn_enemy():
			current_attempts = 0 # Reinicia los intentos si tiene éxito
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
	
	#logica para buscar la posición del spawn
	if current_enemy_count >= max_enemies or not is_instance_valid(player_node):
		return
		
	spawn_locator_node.progress_ratio = randf()
	var spawn_position = spawn_locator_node.global_position
	
	if spawn_position.distance_to(player_node.global_position) <= safe_spawn_radius:
		_log_message("Spawn Cancel: the random point in the safe radius is near")
		return
		
	if portal_scene != null:
		var portal_instance = portal_scene.instantiate()
		call_deferred("add_child", portal_instance)
		portal_instance.set_deferred("global_position", spawn_position)
	
	#logica del spawn
	var enemy_instance = saw_scene.instantiate()
	enemy_instance.add_to_group("saws")
	call_deferred("add_child", enemy_instance)
	if not has_emitted_first_spawn_signal:
		has_emitted_first_spawn_signal = true
		first_saw_spawner.emit.call_deferred()
	
	enemy_instance.global_position = spawn_position
	
	#logica del update de la dificultad
	if not enemy_current_config.is_empty():
		enemy_instance.setup(enemy_current_config)
		
	enemy_instance.died.connect(_on_enemy_died.bind(_generation))
	current_enemy_count += 1

func stop():
	is_active = false
	_log_message("Saw spawner STOPPED")

func _on_enemy_died(_saw_reference, generation: int):
	# A saw from an earlier wave: the current count doesn't include it
	if generation != _generation:
		return
	current_enemy_count = maxi(current_enemy_count - 1, 0) # Aún registramos que murió.
	if not is_active:
		return
	await get_tree().create_timer(spawn_timeout, false).timeout
	_refill()

## Spawns saws until the wave is back to max_enemies. A single try per death used to lose
## that saw for the rest of the phase whenever the random point was rejected, so it
## retries every RETRY_DELAY. Only one loop runs at a time; it always fills the current wave.
func _refill() -> void:
	if _refilling:
		return
	_refilling = true
	while is_active and is_inside_tree() and current_enemy_count < max_enemies:
		var before: int = current_enemy_count
		spawn_enemy()
		if current_enemy_count > before:
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
