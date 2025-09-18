extends Node2D

@onready var player = $PlayerInstance
@onready var crt_material: ShaderMaterial = $UILayer/ColorRect.material
@onready var glitch_sound: AudioStreamPlayer2D = $GlitchSound
@onready var cam: Camera2D = $Camera2D
@onready var saw_spawner: SawSpawner = $SawSpawner
@onready var saw_sound: AudioStreamPlayer2D = $SawSound
@onready var laser_wall_animated: AnimatedSprite2D = $LaserWallAnimation
@onready var phase_manager = $PhaseNode

var base_zoom: Vector2
@export var laser_explosion_particles: PackedScene
@export var enemy_laser_explosion: PackedScene
@export var asteroids_explosion_particles: PackedScene
# Called when the node enters the scene tree for the first time.

func _ready() -> void:
	reset_shader_parameters()
	base_zoom = cam.zoom
	player.died.connect(phase_manager._on_player_hit) # Replace with function body.
	player.connect("dash", Callable(self, "_on_player_dashed"))
	saw_spawner.first_saw_spawner.connect(saw_sound.play, CONNECT_ONE_SHOT)
	phase_manager.phase_failed.connect(_on_phase_manager_failed)
	laser_wall_animated.play()
	
<<<<<<< HEAD
func _on_phase_manager_failed():
	glitch_sound.play()
	play_glitch_effect()
	
=======
>>>>>>> parent of 0ecf31d (add restart in failure)
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
	
	if area.is_in_group("lasers"):
		if laser_explosion_particles:
			var laser_exp_instance = laser_explosion_particles.instantiate()
			add_child(laser_exp_instance)
			laser_exp_instance.global_position = area.global_position
		
		area.queue_free()
	
	elif area.is_in_group("enemy_laser"):
		if enemy_laser_explosion:
			var enemy_laser_exp_instance = enemy_laser_explosion.instantiate()
			add_child(enemy_laser_exp_instance)
			enemy_laser_exp_instance.global_position = area.global_position

		area.queue_free()
