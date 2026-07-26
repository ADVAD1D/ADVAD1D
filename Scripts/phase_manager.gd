extends Node

signal phase_started(phase_number, score_requirement)
signal timer_updated(time_left_string)

@export var player_node: CharacterBody2D
@export var asteroid_node: Marker2D

@export var ship_enemy_spawner: Node2D
@export var saw_enemy_spawner: Node2D


var arena_enemy_configs = {
	0: { "min_shoot": 0.5, "max_shoot": 0.8, "min_ship": 2.0, "max_ship": 5.0, "max_saw": 2.0, "min_ship_spd": 250.0, "max_ship_spd": 500.0, "sep_radius": 75.0, "sep_strength": 100.0, "can_retreat": true, "fire_range": 1500.0 },
	1: { "min_shoot": 0.2, "max_shoot": 0.3, "min_ship": 5.0, "max_ship": 6.0, "max_saw": 3.0, "min_ship_spd": 400.0, "max_ship_spd": 650.0, "sep_radius": 300.0, "sep_strength": 300.0, "can_retreat": false, "fire_range": 3500.0 },
	2: { "min_shoot": 0.4, "max_shoot": 0.7, "min_ship": 4.0, "max_ship": 8.0, "max_saw": 4.0, "min_ship_spd": 300.0, "max_ship_spd": 600.0, "sep_radius": 150.0, "sep_strength": 300.0, "can_retreat": true, "fire_range": 2000.0 }
}

@export var phase_cooldown_timer: float = 1.0 # = 1.0

@export var wall_to_remove: StaticBody2D
@export var sprite_to_remove: AnimatedSprite2D

@onready var browser_support: bool = GameManager.browser_support
@onready var relative_control_active: bool = GameManager.relative_control_active

@onready var background_sprite: Sprite2D = $"../Sprite2D"
@onready var time_progress_bar: TextureProgressBar = $"../UILayer/HUD".get_node("TimeBarContainer/TimeProgressBar")
@onready var time_bar_container: HBoxContainer = $"../UILayer/HUD".get_node("TimeBarContainer")
@onready var phase_label: Label = $"../UILayer/HUD".get_node("PhaseLabel")
@onready var objective_label: Label = $"../UILayer/HUD".get_node("ObjectiveLabel")
@onready var code_label: Label = $"../UILayer/HUD".get_node("CodeLabel")

@onready var success_sound: AudioStreamPlayer2D = $"../SucessSound"
@onready var asteroids_spawner: Marker2D = $"../AsteroidSpawner"

var arena_phase_requirements = {
	0: { 1: 500, 2: 1000, 3: 1500, 4: 2000, 5: 2500, 6: 3000, 7: 3500, 8: 4000, 9: 4500, 10: 5000 },
	1: { 1: 1000, 2: 2000, 3: 3000, 4: 4000, 5: 5000, 6: 6000, 7: 7000, 8: 8000, 9: 9000, 10: 10000 },
	2: { 1: 2000, 2: 4000, 3: 6000, 4: 8000, 5: 10000, 6: 12000, 7: 14000, 8: 16000, 9: 18000, 10: 20000 }
}

var arena_phase_durations = {
	0: { 1: 10.0, 2: 15.0, 3: 20.0, 4: 30.0, 5: 40.0, 6: 50.0, 7: 60.0, 8: 70.0, 9: 80.0, 10: 100.0 },
	1: { 1: 15.0, 2: 20.0, 3: 25.0, 4: 35.0, 5: 45.0, 6: 55.0, 7: 65.0, 8: 75.0, 9: 85.0, 10: 105.0 },
	2: { 1: 10.0, 2: 15.0, 3: 20.0, 4: 30.0, 5: 40.0, 6: 50.0, 7: 60.0, 8: 70.0, 9: 80.0, 10: 100.0 }
}

var current_phase: int = 0

var phase_timer: float

var current_score_requirement: int

var is_phase_active: bool = false

var restart_from_phase: bool = true

func _ready() -> void:
	GameManager.score_updated.connect(_on_score_updated)

	# Phases shown in the debug menu (Tab).
	DebugMenu.watch(self, "current_phase", "Phase")
	DebugMenu.watch(self, "phase_timer", "Phase timer")
	DebugMenu.watch(self, "current_score_requirement", "Score req")
	DebugMenu.watch(self, "is_phase_active", "Phase active")

	if GameManager.speedrun_mode_active:
		GameManager.start_speedrun()
	_log_message("Phase manager ready to execute")
	_log_message("Speedrun timer started!")
	code_label.modulate.a = 0.0
	#ready in current phase
	if  restart_from_phase == true:
		current_phase = GameManager.phase_to_start - 1
		
	start_new_phase() # Replace with function body.
	
	time_progress_bar.max_value = phase_timer

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if is_instance_valid(background_sprite) and background_sprite.material != null:
		DebugMenu.track("Arena Grayscale", "%.2f" % background_sprite.material.get_shader_parameter("grayscale_amount"))

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
	if current_phase > 1:
		var current_pilot_name = GameManager.player_name
		if current_pilot_name.strip_edges().is_empty():
			current_pilot_name = "Player"
		Network.send_player_phase(current_pilot_name, current_phase)
		
	var reqs = arena_phase_requirements.get(GameManager.current_arena_index, arena_phase_requirements[0])
		
	#yes, i don't use elifs
	if not reqs.has(current_phase):
		_log_message("You win all phases!")
		phase_label.text = "ARENA WIN"
		gray_scale_transition()
		fade_out_time_bar()
		if GameManager.is_speedrun_running:
			GameManager.stop_speedrun()
		var codelabel_tween = create_tween()
		
		# (object, property, final value, duration)
		codelabel_tween.tween_property(code_label, "modulate:a", 1.0, 1.0)
		
		if is_instance_valid(objective_label):
			fade_out_objective_label()
		
		if is_instance_valid(saw_enemy_spawner):
			saw_enemy_spawner.stop()
			
		if is_instance_valid(ship_enemy_spawner):
			ship_enemy_spawner.stop()
			
		get_tree().call_group("powerup_spawners", "stop")
		get_tree().call_group("pickups", "queue_free")
			
		if is_instance_valid(wall_to_remove):
			wall_to_remove.queue_free()
			
		if is_instance_valid(sprite_to_remove):
			start_fade_out_sprite(sprite_to_remove)
			
		if is_instance_valid(asteroids_spawner):
			asteroids_spawner.stop()
			
		return
		
	_log_message(["--- Starting Phase ---", current_phase])
	GameManager.reset_score()
	
	if is_instance_valid(phase_label):
		phase_label.text = "PHASE: " + str(current_phase)
	
	var dur = arena_phase_durations.get(GameManager.current_arena_index, arena_phase_durations[0])
	var current_phase_duration = dur.get(current_phase, 60.0)
	
	phase_timer = current_phase_duration
	
	if is_instance_valid(time_progress_bar):
		time_progress_bar.max_value = current_phase_duration
		time_progress_bar.value = current_phase_duration
	
	current_score_requirement = reqs[current_phase]
	phase_started.emit(current_phase, current_score_requirement)
	apply_difficulty()
	is_phase_active = true
	
func _on_score_updated(new_score: int):
	_log_message(["Score Update: ", new_score])
	if is_phase_active and new_score >= current_score_requirement:
		_on_phase_success()
		
func _on_phase_success():
	is_phase_active = false
	_log_message(["fase", current_phase, "completada"])
	success_sound.play()
	await clear_the_board()
	GameManager.phase_to_start = current_phase + 1
	start_new_phase()
		
func _on_phase_failure():
	is_phase_active = false
	_log_message("NO TIME LEFT. Restart Scene.")
	GameManager.stop_scoring()
	
	if is_instance_valid(player_node):
		player_node.vanish()
	
	clear_the_board()
	
	GameManager.is_shader_animation = true
	GameManager.is_glitch_sound = true
	GameManager.phase_to_start = current_phase
	
	get_tree().call_deferred("reload_current_scene")
	
func clear_the_board():
	_log_message("Limpiando el tablero")
			
	get_tree().call_group("saws", "die_silently")
	get_tree().call_group("enemies", "die_silently")
	
func apply_difficulty():
	var reqs = arena_phase_requirements.get(GameManager.current_arena_index, arena_phase_requirements[0])
	var progress = float(current_phase - 1) / (reqs.size() - 1.0)
	
	var config = arena_enemy_configs.get(GameManager.current_arena_index, arena_enemy_configs[0])
	var cur_min_shoot = config["min_shoot"]
	var cur_max_shoot = config["max_shoot"]
	var cur_min_ship = config["min_ship"]
	var cur_max_ship = config["max_ship"]
	var cur_max_saw = config["max_saw"]
	
	if relative_control_active:
		cur_max_shoot = 0.9
		cur_min_shoot = 0.6
		cur_max_ship = 4.0
	
	var cur_min_ship_spd = config.get("min_ship_spd", 250.0)
	var cur_max_ship_spd = config.get("max_ship_spd", 500.0)
	var cur_sep_radius = config.get("sep_radius", 75.0)
	var cur_sep_strength = config.get("sep_strength", 100.0)
	var cur_can_retreat = config.get("can_retreat", true)
	var cur_fire_range = config.get("fire_range", 1500.0)
	
	#ships difficulty
	_log_message(["Apply difficult from Phase:", current_phase, "Progress: ", progress])
	var ship_max_enemies = int(lerp(cur_min_ship, cur_max_ship, progress))
	var ship_config = {"speed": lerp(cur_min_ship_spd, cur_max_ship_spd, progress),
					   "shoot_timerate": lerp(cur_max_shoot, cur_min_shoot, progress),
					   "separation_radius": cur_sep_radius,
					   "separation_strength": cur_sep_strength,
					   "can_retreat": cur_can_retreat,
					   "fire_range": cur_fire_range} # Puedes añadir más stats
	
	if is_instance_valid(ship_enemy_spawner):
		ship_enemy_spawner.configure_for_phase(ship_max_enemies, ship_config)
		
	#saws difficulty
	var saw_max_enemies = int(cur_max_saw)
	var saw_config = {"speed": lerp(700.0, 1200.0, progress)}
	
	if is_instance_valid(saw_enemy_spawner):
		saw_enemy_spawner.configure_for_phase(saw_max_enemies, saw_config)
		
func start_fade_out_sprite(target_sprite: AnimatedSprite2D):
	var tween = create_tween()
	tween.tween_property(target_sprite, "modulate:a", 0.0, 1.0)
	tween.tween_callback(target_sprite.queue_free)
	
func fade_out_objective_label():
	
	#browsers can't show some characters, for this reason change win text in this version
	if browser_support == true:
		objective_label.text = "CONGRATULATIONS!"
	else:
		objective_label.text = "> (ツ)"
		
	_log_message("iniciando fade out de los labels")
	var tween = create_tween()
	if is_instance_valid(objective_label):
		tween.tween_property(objective_label, "modulate:a", 0.0, 1.0)
		tween.tween_callback(objective_label.queue_free)
		
func gray_scale_transition():
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	tween.tween_property(
		background_sprite.material,
		"shader_parameter/grayscale_amount",
		1.0,
		2.0
	)
	
func fade_out_time_bar():
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	tween.tween_property(time_bar_container, "modulate:a", 0.0, 1.0)
		
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
