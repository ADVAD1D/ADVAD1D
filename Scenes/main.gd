extends Node2D

@onready var player = $CharacterBody2D
@onready var crt_material: ShaderMaterial = $UILayer/ColorRect.material
@onready var glitch_sound: AudioStreamPlayer2D = $GlitchSound

@export var laser_explosion_particles: PackedScene
@export var enemy_laser_explosion: PackedScene
@export var asteroids_explosion_particles: PackedScene
# Called when the node enters the scene tree for the first time.

func _ready() -> void:
	reset_shader_parameters()
	player.died.connect(_on_player_died) # Replace with function body.
	
func play_glitch_effect():
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)

	tween.parallel().tween_property(crt_material, "shader_parameter/distort_intensity", 0.1, 0.1)
	tween.parallel().tween_property(crt_material, "shader_parameter/static_noise_intensity", 0.1, 0.1)

	tween.chain().tween_property(crt_material, "shader_parameter/aberration", 1.0, 0.1)
	tween.chain().tween_property(crt_material, "shader_parameter/aberration", -1.0, 0.1)
	tween.chain().tween_property(crt_material, "shader_parameter/aberration", 0.1, 0.01)
	
	tween.parallel().tween_property(crt_material, "shader_parameter/aberration", 0.01, 0.1)
	tween.parallel().tween_property(crt_material, "shader_parameter/distort_intensity", 0.01, 0.1)
	tween.parallel().tween_property(crt_material, "shader_parameter/static_noise_intensity", 0.01, 0.1)

	return tween
	
	
func reset_shader_parameters():
	if is_instance_valid(crt_material):
		crt_material.set_shader_parameter("aberration", 0.02)
		crt_material.set_shader_parameter("distort_intensity", 0.02)
		crt_material.set_shader_parameter("static_noise_intensity", 0.01)

func _process(_delta: float) -> void:
	pass

func _on_death_zone_area_entered(area: Area2D) -> void:
	if area.is_in_group("asteroides"):
		var asteroids_exp_instance = asteroids_explosion_particles.instantiate()
		add_child(asteroids_exp_instance)
		asteroids_exp_instance.global_position = area.global_position
		area.queue_free()

func _on_laser_zone_area_entered(area: Area2D) -> void:
	# Si el área es un láser del JUGADOR...
	if area.is_in_group("lasers"):
		# ...instancia las partículas del jugador.
		if laser_explosion_particles: # Buena práctica comprobar si está asignada
			var laser_exp_instance = laser_explosion_particles.instantiate()
			add_child(laser_exp_instance)
			laser_exp_instance.global_position = area.global_position
		
		area.queue_free()
	
	# O si no, si el área es un láser ENEMIGO...
	elif area.is_in_group("enemy_laser"):
		# ...instancia las partículas del enemigo.
		if enemy_laser_explosion:
			var enemy_laser_exp_instance = enemy_laser_explosion.instantiate()
			add_child(enemy_laser_exp_instance)
			enemy_laser_exp_instance.global_position = area.global_position

		area.queue_free()
		
func _on_player_died() -> void:
	glitch_sound.play()
	GameManager.stop_scoring()
	var glitch_tween = play_glitch_effect()
	await  glitch_tween.finished
	await get_tree().create_timer(0.02).timeout
	GameManager.reset_score()
	get_tree().call_deferred("reload_current_scene")
