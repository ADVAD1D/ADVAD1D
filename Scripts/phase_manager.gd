extends Node

signal phase_started(phase_number, score_requirement)
signal timer_updated(time_left_string)

@export var player_node: CharacterBody2D
@export var asteroid_node: Marker2D

@export var ship_enemy_spawner: Node2D
@export var saw_enemy_spawner: Node2D

@export var min_shoot_timerate: float = 0.2 # = 0.2
@export var max_shoot_timerate: float = 0.5 # = 0.5

@export var min_ship_enemies: float = 2.0 # = 2.0
@export var max_ship_enemies: float = 5.0 # = 5.0

@export var max_saw_enemies: float = 2.0 # = 2.0

@export var phase_cooldown_timer: float = 1.0 # = 1.0

@export var wall_to_remove: StaticBody2D
@export var sprite_to_remove: AnimatedSprite2D

@onready var time_progress_bar: TextureProgressBar = $"../UILayer/HUD".get_node("TimeBarContainer/TimeProgressBar")
@onready var phase_label: Label = $"../UILayer/HUD".get_node("PhaseLabel")
@onready var objective_label: Label = $"../UILayer/HUD".get_node("ObjectiveLabel")

@onready var success_sound: AudioStreamPlayer2D = $"../SucessSound"
@onready var asteroids_spawner: Marker2D = $"../AsteroidSpawner"

var phase_requirements = {
	1: 500,
	2: 1000,
	3: 1500,
	4: 2000,
	5: 2500,
	6: 3000,
	7: 3500,
	8: 4000,
	9: 4500,
	10: 5000
}

var phase_durations = {
	1: 10.0,
	2: 15.0,
	3: 20.0,
	4: 30.0,
	5: 40.0,
	6: 50.0,
	7: 60.0,
	8: 70.0,
	9: 80.0,
	10: 100.0
}

var current_phase: int = 0

var phase_timer: float

var current_score_requirement: int

var is_phase_active: bool = false

var restart_from_phase: bool = true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("phase manager listo a ejecutarse")
	GameManager.score_updated.connect(_on_score_updated)
	
	#ready in current phase
	if  restart_from_phase == true:
		current_phase = GameManager.phase_to_start - 1
		
	start_new_phase() # Replace with function body.
	
	time_progress_bar.max_value = phase_timer

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not is_phase_active:
		return
		
	phase_timer = phase_timer - delta
	
	if is_instance_valid(time_progress_bar):
		time_progress_bar.value = phase_timer
	
	@warning_ignore("integer_division")
	var minutes = int(phase_timer) / 60
	var seconds = int(phase_timer) % 60
	timer_updated.emit("%02d:%02d" % [minutes, seconds])
	
	if phase_timer <= 0:
		_on_phase_failure()
		
func start_new_phase():
	current_phase = current_phase + 1
	if not phase_requirements.has(current_phase):
		print("has ganado las fases")
		phase_label.text = "ARENA WIN" 
		if is_instance_valid(objective_label):
			fade_out_objective_label()
		
		if is_instance_valid(saw_enemy_spawner):
			saw_enemy_spawner.stop()
			
		if is_instance_valid(ship_enemy_spawner):
			ship_enemy_spawner.stop()
			
		if is_instance_valid(wall_to_remove):
			wall_to_remove.queue_free()
			
		if is_instance_valid(sprite_to_remove):
			start_fade_out_sprite(sprite_to_remove)
			
		if is_instance_valid(asteroids_spawner):
			asteroids_spawner.stop()
			
		return
		
	print("--- Empezando Fase ", current_phase, " ---")	
	GameManager.reset_score()
	
	if is_instance_valid(phase_label):
		phase_label.text = "PHASE: " + str(current_phase)
	
	var current_phase_duration = phase_durations.get(current_phase, 60.0)
	
	phase_timer = current_phase_duration
	
	if is_instance_valid(time_progress_bar):
		time_progress_bar.max_value = current_phase_duration
		time_progress_bar.value = current_phase_duration
	
	current_score_requirement = phase_requirements[current_phase]
	phase_started.emit(current_phase, current_score_requirement)
	apply_difficulty()
	is_phase_active = true
	
func _on_score_updated(new_score: int):
	print("Puntuación actualizada: ", new_score)
	if is_phase_active and new_score >= current_score_requirement:
		_on_phase_success()
		
func _on_phase_success():
	is_phase_active = false
	print("fase", current_phase, "completada")
	success_sound.play()
	await clear_the_board()
	GameManager.phase_to_start = current_phase + 1
	start_new_phase()
		
func _on_phase_failure():
	is_phase_active = false
	print("TIEMPO AGOTADO. Reiniciando escena.")
	GameManager.stop_scoring()
	
	if is_instance_valid(player_node):
		player_node.vanish()
	
	clear_the_board()
	
	GameManager.is_shader_animation = true
	GameManager.is_glitch_sound = true
	GameManager.phase_to_start = current_phase
	
	get_tree().call_deferred("reload_current_scene")
	
func clear_the_board():
	print("Limpiando el tablero")
			
	get_tree().call_group("saws", "die_silently")
	get_tree().call_group("enemies", "die_silently")
	
func apply_difficulty():
	var progress = float(current_phase - 1) / (phase_requirements.size() - 1.0)
	
	#dificultad para las naves
	print("aplicando dificultad para la fase", current_phase, "progreso: ", progress)
	var ship_max_enemies = int(lerp(min_ship_enemies, max_ship_enemies, progress))
	var ship_config = {"speed": lerp(250.0, 500.0, progress),
					   "shoot_timerate": lerp(max_shoot_timerate, min_shoot_timerate, progress)} # Puedes añadir más stats
	
	if is_instance_valid(ship_enemy_spawner):
		ship_enemy_spawner.configure_for_phase(ship_max_enemies, ship_config)
		
	#dificultad para las sierras
	var saw_max_enemies = int(max_saw_enemies)
	var saw_config = {"speed": lerp(700.0, 1200.0, progress)}
	
	if is_instance_valid(saw_enemy_spawner):
		saw_enemy_spawner.configure_for_phase(saw_max_enemies, saw_config)
		
func start_fade_out_sprite(target_sprite: AnimatedSprite2D):
	var tween = create_tween()
	tween.tween_property(target_sprite, "modulate:a", 0.0, 1.0)
	tween.tween_callback(target_sprite.queue_free)
	
func fade_out_objective_label():
	objective_label.text = "> (ツ)"
	print("iniciando fade out de los labels")
	var tween = create_tween()
	if is_instance_valid(objective_label):
		tween.tween_property(objective_label, "modulate:a", 0.0, 1.0)
		tween.tween_callback(objective_label.queue_free)
