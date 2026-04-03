extends Node2D

@export var transition_sound: AudioStream

@onready var tutorial_timer: Timer = $TutorialTimer
@onready var player = $PlayerInstance
@onready var crt_material: ShaderMaterial = $UILayer/ColorRect.material
@onready var glitch_sound: AudioStreamPlayer2D = $GlitchSound
@onready var cam: Camera2D = $Camera2D
@onready var laser_wall_animated: AnimatedSprite2D = $LaserWallAnimation
@onready var fade_in_rect: ColorRect = $ColorRect1
@onready var admin_control: bool = GameManager.admin_control

var base_zoom: Vector2
@export var laser_explosion_particles: PackedScene
@export var asteroids_explosion_particles: PackedScene
# Called when the node enters the scene tree for the first time.

func _ready() -> void:
	ResourceLoader.load_threaded_request("res://Scenes/main.tscn")
	
	fade_in_rect.visible = true
	fade_in_rect.modulate.a = 1.0 
	
	var tween = create_tween()
	tween.tween_property(fade_in_rect, "modulate:a", 0.0, 1.5)
	tween.tween_callback(fade_in_rect.hide)
	
	tutorial_timer.timeout.connect(_on_tutorial_timer_timeout)
	tutorial_timer.start()
	
	reset_shader_parameters()
	GameManager.can_pause = false
	base_zoom = cam.zoom
	player.died.connect(_on_player_died) # Replace with function body.
	player.connect("dash", Callable(self, "_on_player_dashed"))
	laser_wall_animated.play()
	
	if GameManager.is_shader_animation:
		GameManager.play_glitch_effect(crt_material)
		GameManager.is_shader_animation = false
		
	if GameManager.is_glitch_sound:
		GameManager.play_glitch_sound(glitch_sound)
		GameManager.is_glitch_sound = false
	
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
		
func _on_player_died() -> void:
	tutorial_timer.stop()
	GameManager.play_glitch_sound(glitch_sound)
	var glitch_tween = GameManager.play_glitch_effect(crt_material)
	await  glitch_tween.finished
	await get_tree().create_timer(0.01).timeout
	get_tree().call_deferred("reload_current_scene")
	
func _on_tutorial_timer_timeout():
	if player.player_died:
		_log_message("The player is in the process of dying; the scene change is cancelled.")
		return
		
	_log_message("Finished tutorial. Change to main scene...")
	
	MusicPlayer.play_sfx(transition_sound)
	change_to_next()
		
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Skip") and admin_control == true:
		change_to_next()
	else:
		pass
		
func change_to_next():
	var next_scene = ResourceLoader.load_threaded_get("res://Scenes/main.tscn")
	if next_scene:
		get_tree().change_scene_to_packed(next_scene)
		
func _log_message(message):
	if GameManager.is_debug_text == true:
		print_rich("[color=yellow][DEV LOG][/color] " + message)
	else:
		return
