extends Node

signal phase_started(phase_number, score_requirement)
signal timer_updated(time_left_string)

@export var ship_enemy_spawner: Node2D
@export var saw_enemy_spawner: Node2D
@export var phase_duration = 180.0

@export var min_shoot_timerate: float = 0.2
@export var max_shoot_timerate: float = 0.3

@export var min_ship_enemies: float = 4.0
@export var max_ship_enemies: float = 8.0

@export var min_saw_enemies: float = 2.0
@export var max_saw_enemies: float = 5.0

@export var phase_cooldown_timer: float = 5.0

@onready var success_sound: AudioStreamPlayer2D = $"../SucessSound"

var phase_requirements = {
	1: 500,
	2: 1000,
	3: 1500,
	4: 2000
}

var current_phase: int = 0

var phase_timer: float

var current_score_requirement: int

var is_phase_active: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("phase manager listo a ejecutarse")
	GameManager.score_updated.connect(_on_score_updated)
	start_new_phase() # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not is_phase_active:
		return
		
	phase_timer = phase_timer - delta
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
		
		if is_instance_valid(saw_enemy_spawner):
			saw_enemy_spawner.stop()
			
		if is_instance_valid(ship_enemy_spawner):
			ship_enemy_spawner.stop()
			
		return
		
	print("--- Empezando Fase ", current_phase, " ---")	
	GameManager.reset_score()
	
	phase_timer = phase_duration
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
	clear_the_board()
	GameManager.phase_to_start = current_phase + 1
	start_new_phase()
		
func _on_phase_failure():
	is_phase_active = false
	print("TIEMPO AGOTADO. Reiniciando escena.")
	GameManager.stop_scoring()
	
	clear_the_board()
	GameManager.is_shader_animation = true
	GameManager.is_glitch_sound = true
	GameManager.phase_to_start = current_phase
	
	get_tree().call_deferred("reload_current_scene")
	
func clear_the_board():
	for node in get_tree().get_nodes_in_group("destructibles"):
		for enemies in node.get_children():
			if enemies.has_signal("died"):
				enemies.died.emit(enemies)
	
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
	var saw_max_enemies = int(lerp(min_saw_enemies, max_saw_enemies, progress))
	var saw_config = {"speed": lerp(700.0, 1200.0, progress)}
	
	if is_instance_valid(saw_enemy_spawner):
		saw_enemy_spawner.configure_for_phase(saw_max_enemies, saw_config)
