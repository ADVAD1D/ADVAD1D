# ==========================================
# PHASE MANAGER
# ==========================================
# This script handles the progression logic of the arenas.
# It controls the timer, the score requirements, and orchestrates
# the difficulty scaling for enemy spawners (Ships, Saws, Asteroids)
# based on the current phase. It also manages visual transitions 
# and UI updates between phases.
extends Node

signal phase_started(phase_number, score_requirement)
signal timer_updated(time_left_string)

@export var player_node: CharacterBody2D
@export var asteroid_node: Marker2D

@export var ship_enemy_spawner: Node2D
@export var saw_enemy_spawner: Node2D
## Arena 2's wall guns (LaserGunSpawner); how many per phase comes from "laser_guns".
@export var laser_gun_spawner: Node2D
## Arcade arena 3's small GEMELA (MiniBossSpawner); how many per phase comes from "mini_boss".
@export var mini_boss_spawner: Node2D

@export_group("Boss")
## Boss arena: in the main mode this boss comes before the phases (no timer, no score goal);
## beating it starts the phases (see post_boss_countdown). Arcade mode ignores it and plays
## the phases as usual.
@export var boss_scene: PackedScene
## Where the boss appears (and wanders around).
@export var boss_spawn: Node2D
## Seconds of the countdown shown after the boss is beaten; then the arena reloads as normal
## phases (GameManager.post_boss_phases), and clearing them wins it. 0 = beating the boss
## wins the arena right away.
@export var post_boss_countdown: float = 5.0
## Style of that countdown (like the tutorials' countdown).
@export var countdown_settings: LabelSettings
## Stat added when the boss is beaten (main mode), e.g. for an achievement.
@export var boss_defeated_stat: StringName = &""
@export_group("")

@export var phase_cooldown_timer: float = 1.0 # = 1.0

@export var wall_to_remove: StaticBody2D
@export var sprite_to_remove: AnimatedSprite2D
## Also freed when the last phase is won, with wall_to_remove (e.g. the LaserZone shape
## that covers the same opening, so lasers fly through it once it is open).
@export var nodes_to_remove: Array[Node] = []

@export_group("Arcade")
## Arcade mode only: past the last table phase, difficulty progress keeps growing this
## much per phase (1.0 = the last table phase), so enemies get more numerous and faster.
@export var arcade_overdrive_per_phase: float = 0.05
## Cap for that growth (1.5 is reached at phase 20 with the default step).
@export var arcade_max_progress: float = 1.5
## From this phase on the number of enemy ships stops growing (more ships every phase
## becomes unplayable). Speed and fire rate keep scaling.
@export var arcade_ship_count_cap_phase: int = 8
@export_group("")

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

var arena_enemy_configs = {
	#0: { "min_shoot": 0.5, 
		#"max_shoot": 0.8, 
		#"min_ship": 2.0, 
		#"max_ship": 5.0, 
		#"max_saw": 2.0, 
		#"min_ship_spd": 250.0, 
		#"max_ship_spd": 500.0, 
		#"sep_radius": 75.0, 
		#"sep_strength": 100.0, 
		#"can_retreat": true, 
		#"fire_range": 1500.0 },
		
	0: { "min_shoot": 0.5,
		"max_shoot": 0.8,
		"min_ship": 2.0, 
		"max_ship": 4.0, 
		"max_saw": 2.0, 
		"min_ship_spd": 250.0, 
		"max_ship_spd": 500.0, 
		"sep_radius": 75.0, 
		"sep_strength": 100.0, 
		"can_retreat": true, 
		"fire_range": 1500.0 },
		
	1: { "min_shoot": 0.4, #0.2
		"max_shoot": 0.6, #0.3
		"min_ship": 5.0, #5.0
		"max_ship": 6.0, #6.0
		"max_saw": 3.0, #3.0
		"min_ship_spd": 400.0, 
		"max_ship_spd": 500.0, 
		"sep_radius": 300.0, 
		"sep_strength": 300.0,
		"can_retreat": false,
		"fire_range": 3500.0,
		# Laser guns on the walls: {from phase: how many}
		"laser_guns": {3: 1, 5: 2, 7: 3, 10: 4} },
		
	2: { "min_shoot": 0.3, 
		"max_shoot": 0.6, 
		"min_ship": 2.0, 
		"max_ship": 3.0, 
		"max_saw": 4.0, 
		"min_ship_spd": 300.0, 
		"max_ship_spd": 600.0, 
		"sep_radius": 150.0, 
		"sep_strength": 300.0, 
		"can_retreat": true, 
		"fire_range": 2000.0,
		# Arcade and the phases after the boss (the main mode starts with the boss fight):
		# small GEMELAs {from phase: how many}
		"mini_boss": {1: 1, 6: 2} }
}

var arena_phase_requirements = {
	0: { 
		1: 500, 
		2: 1000, 
		3: 1500, 
		4: 2000, 
		5: 2500, 
		6: 3000, 
		7: 3500, 
		8: 4000, 
		9: 4500, 
		10: 5000 },
	
	1: { 
		1: 1000, 
		2: 2000, 
		3: 3000, 
		4: 4000, 
		5: 5000, 
		6: 6000, 
		7: 7000, 
		8: 8000, 
		9: 9000, 
		10: 10000 },
	
	2: { 
		1: 1500, 
		2: 2500, 
		3: 3500, 
		4: 4500, 
		5: 5500, 
		6: 6500, 
		7: 7500, 
		8: 8500, 
		9: 9500, 
		10: 10500 }
}

var arena_phase_durations = {
	0: { 
		1: 10.0, 
		2: 15.0, 
		3: 20.0, 
		4: 30.0, 
		5: 40.0, 
		6: 50.0, 
		7: 60.0, 
		8: 70.0, 
		9: 80.0, 
		10: 100.0 },
		
	1: { 
		1: 15.0, 
		2: 20.0, 
		3: 25.0, 
		4: 35.0, 
		5: 45.0, 
		6: 55.0, 
		7: 65.0, 
		8: 75.0, 
		9: 85.0, 
		10: 105.0 },
		
	2: { 
		1: 25.0, 
		2: 30.0, 
		3: 40.0, 
		4: 50.0, 
		5: 60.0, 
		6: 70.0, 
		7: 80.0, 
		8: 90.0, 
		9: 100.0, 
		10: 110.0 }
}

var current_phase: int = 0
var phase_timer: float
var current_score_requirement: int
var is_phase_active: bool = false
var last_time_string: String = ""
var last_seconds_int: int = -1
var restart_from_phase: bool = true
var _countdown_timer: Timer
var _countdown_label: Label

func _ready() -> void:
	GameManager.score_updated.connect(_on_score_updated)

	# Phases shown in the debug menu are now handled directly by the debug menu script.
	# Arcade runs have no end, so they don't use the speedrun timer
	if GameManager.speedrun_mode_active and not GameManager.arcade_mode_active:
		GameManager.start_speedrun()
	_log_message("Phase manager ready to execute")
	_log_message("Speedrun timer started!")
	code_label.modulate.a = 0.0
	#ready in current phase
	if  restart_from_phase == true:
		current_phase = GameManager.phase_to_start - 1

	if _is_boss_fight():
		_start_boss_fight()
	else:
		start_new_phase()

	time_progress_bar.max_value = phase_timer

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if GameManager.show_debug_menu:
		if is_instance_valid(background_sprite) and background_sprite.material != null:
			DebugMenu.track("Arena Grayscale", "%.2f" % background_sprite.material.get_shader_parameter("grayscale_amount"))

	if is_instance_valid(_countdown_label) and is_instance_valid(_countdown_timer):
		_countdown_label.text = "%0.1f" % _countdown_timer.time_left

	if not is_phase_active:
		return
		
	phase_timer = phase_timer - delta
	
	if is_instance_valid(time_progress_bar):
		time_progress_bar.value = phase_timer
	
	# OPTIMIZATION: Solo generar el texto del timer visual si los segundos enteros cambiaron.
	# Esto NO afecta a la precisión de la jugabilidad, ya que phase_timer se sigue
	# calculando con precisión de milisegundos para determinar el cambio de fase.
	var current_sec = int(phase_timer)
	if current_sec != last_seconds_int:
		last_seconds_int = current_sec
		@warning_ignore("integer_division")
		var minutes = current_sec / 60
		var seconds = current_sec % 60
		var new_time_string = "%02d:%02d" % [minutes, seconds]
		if new_time_string != last_time_string:
			last_time_string = new_time_string
			timer_updated.emit(new_time_string)
	
	if phase_timer <= 0:
		_on_phase_failure()
		
## Initializes the next phase, checks if the arena has been completed, and sets up the
## timer and requirements.
func start_new_phase():
	current_phase = current_phase + 1

	#yes, i don't use elifs
	if not _has_phase(current_phase):
		_win_arena()
		return

	_log_message(["--- Starting Phase ---", current_phase])
	GameManager.reset_score()

	if is_instance_valid(phase_label):
		phase_label.text = "PHASE: " + str(current_phase)

	var current_phase_duration = _get_phase_duration(current_phase)

	phase_timer = current_phase_duration

	if is_instance_valid(time_progress_bar):
		time_progress_bar.max_value = current_phase_duration
		time_progress_bar.value = current_phase_duration

	current_score_requirement = _get_phase_requirement(current_phase)
	if GameManager.arcade_mode_active:
		ArcadeManager.on_phase_started(current_phase)
	phase_started.emit(current_phase, current_score_requirement)
	apply_difficulty()
	is_phase_active = true

## Every phase cleared (or the boss beaten): the arena turns grey, the spawners stop and the
## way out opens.
func _win_arena() -> void:
	_log_message("You win all phases!")
	phase_label.text = "ARENA WIN"
	phase_label.visible = true  # hidden during a boss fight
	gray_scale_transition()
	fade_out_time_bar()
	if GameManager.is_speedrun_running:
		GameManager.stop_speedrun()
	AchievementManager.complete_arena_run(GameManager.current_arena_index)

	if GameManager.mobile_mode_active or OS.has_feature("web") or GameManager.force_web_mode:
		var ambient = get_node_or_null("../AmbientParticles")
		if ambient:
			ambient.emitting = true
			
	var codelabel_tween = create_tween()
	
	# (object, property, final value, duration)
	if GameManager.current_arena_index == 1:
		code_label.text = ">ZGVhdGhhcmVuYQ=="
		codelabel_tween.tween_property(code_label, "modulate:a", 1.0, 1.0)
	elif GameManager.current_arena_index == 2:
		code_label.text = "bWFpbmFyZW5h"
		codelabel_tween.tween_property(code_label, "modulate:a", 1.0, 1.0)
	else:
		codelabel_tween.tween_property(code_label, "modulate:a", 1.0, 1.0)
	
	if is_instance_valid(objective_label):
		fade_out_objective_label()
	
	if is_instance_valid(saw_enemy_spawner):
		saw_enemy_spawner.stop()
		
	if is_instance_valid(ship_enemy_spawner):
		ship_enemy_spawner.stop()

	if is_instance_valid(laser_gun_spawner):
		laser_gun_spawner.stop()

	if is_instance_valid(mini_boss_spawner):
		mini_boss_spawner.stop()

	call_deferred("_stop_powerup_spawners")
		
	if is_instance_valid(wall_to_remove):
		wall_to_remove.queue_free()
	for node in nodes_to_remove:
		if is_instance_valid(node):
			node.queue_free()
		
	if is_instance_valid(sprite_to_remove):
		start_fade_out_sprite(sprite_to_remove)
		
	if is_instance_valid(asteroids_spawner):
		asteroids_spawner.stop()

# --- Boss arena ---------------------------------------------------------------------

## Arcade and the phases after the boss (post_boss_phases) skip the boss fight.
func _is_boss_fight() -> bool:
	return boss_scene != null and not GameManager.arcade_mode_active \
			and not GameManager.post_boss_phases

## Main mode of a boss arena: no phase timer or score goal, only the boss. A death reloads
## the scene and the fight starts over (phase_to_start stays 1). Once it is beaten the
## arena reloads as phases (post_boss_countdown > 0), or phase_to_start goes past the last
## table phase so a reload keeps the arena won. Asteroids and powerups keep coming as usual.
func _start_boss_fight() -> void:
	if GameManager.phase_to_start > _last_table_phase():
		_win_arena()
		return
	current_phase = 1
	var boss = boss_scene.instantiate()
	if is_instance_valid(boss_spawn):
		boss.position = boss_spawn.global_position
	boss.defeated.connect(_on_boss_defeated)
	get_parent().call_deferred("add_child", boss)
	# The boss's health bar (with its name) takes the labels' place at the top
	if is_instance_valid(phase_label):
		phase_label.visible = false
	if is_instance_valid(objective_label):
		objective_label.visible = false
	if is_instance_valid(time_bar_container):
		time_bar_container.visible = false

func _on_boss_defeated() -> void:
	success_sound.play()
	if boss_defeated_stat != &"":
		AchievementManager.add_stat(boss_defeated_stat)
	if post_boss_countdown <= 0.0:
		GameManager.phase_to_start = _last_table_phase() + 1
		_win_arena()
		return
	_start_post_boss_countdown()

## After the boss: a countdown, then the scene reloads as normal phases from phase 1. The
## state is set right away, so a death during the countdown also reloads into the phases.
## No new asteroids meanwhile.
func _start_post_boss_countdown() -> void:
	GameManager.post_boss_phases = true
	GameManager.phase_to_start = 1
	if is_instance_valid(asteroids_spawner):
		asteroids_spawner.stop()

	_countdown_timer = Timer.new()
	_countdown_timer.one_shot = true
	_countdown_timer.wait_time = post_boss_countdown
	_countdown_timer.timeout.connect(_on_post_boss_countdown_finished)
	add_child(_countdown_timer)
	_countdown_timer.start()

	# Centre of the screen (the bottom has the HUD's own timer); anchored so it stays
	# centred when a phone widens the viewport
	_countdown_label = Label.new()
	_countdown_label.label_settings = countdown_settings
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_countdown_label.anchor_left = 0.5
	_countdown_label.anchor_right = 0.5
	_countdown_label.anchor_top = 0.5
	_countdown_label.anchor_bottom = 0.5
	_countdown_label.offset_left = -84.0
	_countdown_label.offset_right = 84.0
	_countdown_label.offset_top = -24.0
	_countdown_label.offset_bottom = 24.0
	_countdown_label.pivot_offset = Vector2(84.0, 24.0)
	_countdown_label.scale = Vector2(0.6135, 0.6135)
	_countdown_label.text = "%0.1f" % post_boss_countdown
	var ui_layer: Node = get_node_or_null("../UILayer")
	if ui_layer:
		ui_layer.add_child(_countdown_label)
		# Under the CRT overlay, like the HUD
		ui_layer.move_child(_countdown_label, 1)

func _on_post_boss_countdown_finished() -> void:
	# A player dying right now is already reloading the scene (into the phases)
	if is_instance_valid(player_node) and player_node.get("player_died"):
		return
	_log_message("Boss beaten: the arena restarts as phases")
	GameManager.is_shader_animation = true
	GameManager.is_glitch_sound = true
	get_tree().call_deferred("reload_current_scene")

func _on_score_updated(new_score: int):
	_log_message(["Score Update: ", new_score])
	# Arcade: a dead player can't clear the phase, the death already ended the run (restart
	# from phase 1). The main mode lets a laser still flying after the death clear it.
	if GameManager.arcade_mode_active and is_instance_valid(player_node) \
			and player_node.get("player_died"):
		return
	if is_phase_active and new_score >= current_score_requirement:
		_on_phase_success()
		
## Called when the player reaches the required score for the current phase.
## Clears the enemies and triggers the next phase sequence.
func _on_phase_success():
	is_phase_active = false
	_log_message(["fase", current_phase, "completada"])
	success_sound.play()
	if GameManager.arcade_mode_active:
		ArcadeManager.on_phase_cleared(current_phase)
	await clear_the_board()
	GameManager.phase_to_start = current_phase + 1
	start_new_phase()
		
## Called when the timer runs out before reaching the required score.
## Kills the player, triggers a screen glitch, and restarts the current phase.
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
	# Arcade: running out of time ends the run, the reload starts again from phase 1
	if GameManager.arcade_mode_active:
		ArcadeManager.end_run()

	get_tree().call_deferred("reload_current_scene")
	
## Immediately kills all active enemies on the screen.
## Note: The enemies handle their own staggered explosions via die_silently() 
## to prevent mobile performance drops.
func clear_the_board():
	_log_message("Limpiando el tablero")
			
	get_tree().call_group("saws", "die_silently")
	get_tree().call_group("enemies", "die_silently")
	
## Phase table lookups. Past the last phase of the tables (only reachable in arcade
## mode) the values are extrapolated from the end of the tables.
func _get_requirements_table() -> Dictionary:
	var arena: int = GameManager.current_arena_index
	return arena_phase_requirements.get(arena, arena_phase_requirements[0])

func _get_durations_table() -> Dictionary:
	return arena_phase_durations.get(GameManager.current_arena_index, arena_phase_durations[0])

func _last_table_phase() -> int:
	return int(_get_requirements_table().keys().max())

## In arcade mode every phase exists; in the main mode the table ends the arena.
func _has_phase(phase: int) -> bool:
	return _get_requirements_table().has(phase) or GameManager.arcade_mode_active

## Score goal. Past the table it keeps the step between the last two phases
## (arena 1: 5000, 5500, 6000...).
func _get_phase_requirement(phase: int) -> int:
	var reqs: Dictionary = _get_requirements_table()
	if reqs.has(phase):
		return int(reqs[phase])
	var last: int = _last_table_phase()
	var step: int = int(reqs[last]) - int(reqs.get(last - 1, 0))
	return int(reqs[last]) + (phase - last) * step

## Phase length. Past the table it keeps the points-per-second pace of the last phase,
## so later phases last longer without getting easier (arena 1: 100s, 110s, 120s...).
func _get_phase_duration(phase: int) -> float:
	var dur: Dictionary = _get_durations_table()
	if dur.has(phase):
		return float(dur[phase])
	if not GameManager.arcade_mode_active:
		return 60.0
	var last: int = _last_table_phase()
	var pace: float = float(_get_phase_requirement(last)) / float(dur.get(last, 60.0))
	return roundf(_get_phase_requirement(phase) / pace)

## 0 at phase 1, 1 at the last table phase. In arcade mode it keeps growing past 1
## (lerp extrapolates: more ships, faster, shooting more often) up to arcade_max_progress.
func _get_difficulty_progress(phase: int) -> float:
	var last: int = _last_table_phase()
	if phase > last and GameManager.arcade_mode_active:
		return minf(1.0 + (phase - last) * arcade_overdrive_per_phase, arcade_max_progress)
	return float(phase - 1) / maxf(last - 1.0, 1.0)

func apply_difficulty():
	var progress = _get_difficulty_progress(current_phase)

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
	
	# ==========================================
	# SHIPS DIFFICULTY & PARAMETER INSTANTIATION
	# ==========================================
	_log_message(["Apply difficult from Phase:", current_phase, "Progress: ", progress])
	
	# Calculate the maximum number of enemy ships for the current phase using linear interpolation (lerp).
	# This scales the number of enemies smoothly from 'cur_min_ship' (at phase 1) to 'cur_max_ship' (at the last phase).
	# Arcade: past arcade_ship_count_cap_phase the count stays at that phase's value
	var ship_count_progress = progress
	if GameManager.arcade_mode_active and current_phase > arcade_ship_count_cap_phase:
		ship_count_progress = _get_difficulty_progress(arcade_ship_count_cap_phase)
	var ship_max_enemies = int(lerp(cur_min_ship, cur_max_ship, ship_count_progress))
	
	# Pack all the calculated properties into a dictionary. This acts as a configuration blueprint 
	# that will be sent to the spawner. Using lerp() allows stats like speed and fire rate to 
	# become progressively harder as the player advances through the phases.
	var ship_config = {
		"speed": lerp(cur_min_ship_spd, cur_max_ship_spd, progress),
		"shoot_timerate": lerp(cur_max_shoot, cur_min_shoot, progress), # Note: max_shoot is used first because a lower timer value means faster shooting
		"separation_radius": cur_sep_radius,
		"separation_strength": cur_sep_strength,
		"can_retreat": cur_can_retreat,
		"fire_range": cur_fire_range
	}
	
	# If the spawner node exists in the scene, we inject the calculated parameters into it.
	# The spawner will then read this dictionary and assign these properties to every new ship it instantiates.
	if is_instance_valid(ship_enemy_spawner):
		ship_enemy_spawner.configure_for_phase(ship_max_enemies, ship_config)
		
	#saws difficulty
	var saw_max_enemies = int(cur_max_saw)
	var saw_config = {"speed": lerp(700.0, 1200.0, progress)}
	
	if is_instance_valid(saw_enemy_spawner):
		saw_enemy_spawner.configure_for_phase(saw_max_enemies, saw_config)

	# Laser guns (arena 2): count from the "laser_guns" table, shooting more often later on
	if is_instance_valid(laser_gun_spawner):
		var gun_config = {"cooldown_scale": lerp(1.0, 0.7, minf(progress, 1.0))}
		laser_gun_spawner.configure_for_phase(_get_phase_count(config, "laser_guns"), gun_config)

	# Small GEMELA (arcade arena 3): count from the "mini_boss" table, attacking more often later
	if is_instance_valid(mini_boss_spawner):
		var mini_config = {"cooldown_scale": lerp(1.0, 0.7, minf(progress, 1.0))}
		mini_boss_spawner.configure_for_phase(_get_phase_count(config, "mini_boss"), mini_config)

## How many of something the current phase gets from a {from phase: count} table of the
## arena config ("laser_guns", "mini_boss"): the value of the highest "from phase" reached.
func _get_phase_count(config: Dictionary, key: String) -> int:
	var table: Dictionary = config.get(key, {})
	var best_phase: int = 0
	var count: int = 0
	for from_phase in table:
		if current_phase >= int(from_phase) and int(from_phase) > best_phase:
			best_phase = int(from_phase)
			count = int(table[from_phase])
	return count

## Smoothly fades out and deletes a target sprite (e.g., arena background elements).
func start_fade_out_sprite(target_sprite: AnimatedSprite2D):
	var tween = create_tween()
	tween.tween_property(target_sprite, "modulate:a", 0.0, 1.0)
	tween.tween_callback(target_sprite.queue_free)
	
## Changes the objective label to a victory message and fades it out smoothly.
func fade_out_objective_label():
	
	#browsers can't show some characters, for this reason change win text in this version
	if browser_support == true:
		objective_label.text = "CONGRATULATIONS!"
	elif GameManager.current_arena_index == 1:
		objective_label.text = "bWVudGFs" #base64 encrypted text easter egg
	else:
		objective_label.text = "> (ツ)"
		
	_log_message("iniciando fade out de los labels")
	var tween = create_tween()
	if is_instance_valid(objective_label):
		tween.tween_property(objective_label, "modulate:a", 0.0, 1.0)
		tween.tween_callback(objective_label.queue_free)
		
## Animates the background shader into grayscale when the player completes all phases.
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
	
## Smoothly fades out the HUD time bar when the arena is completed.
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

#stop powerup spawners in finish all phases to avoid entities memory leaks
func _stop_powerup_spawners():
	get_tree().call_group("powerup_spawners", "stop")
