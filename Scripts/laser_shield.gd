extends Area2D

@export var animated_sprites: Array[AnimatedSprite2D]
@export var duration_timer: Timer
@export var laser_shield_particles: PackedScene
@export var shield_break_particles: PackedScene

@onready var spawn_time: float = 0.1
@onready var metal_sound: AudioStreamPlayer2D = $BreakSound

# Called when the node enters the scene tree for the first time.
func _ready() -> void: 
	duration_timer.timeout.connect(_on_timeout)
	duration_timer.start()
	area_entered.connect(_on_area_entered)
	
	scale = Vector2.ZERO
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_BOUND)
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), spawn_time)
	
func _on_timeout():
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	hide()
	
	if shield_break_particles:
		call_deferred("_spawn_break_particles", global_position)
		
	metal_sound.play()
	await metal_sound.finished
	queue_free()

func play_all(animation_name: String):
	for sprite in animated_sprites:
		if is_instance_valid(sprite):
			sprite.play(animation_name)
		
func _on_area_entered(area: Area2D):
	if area.is_in_group("enemy_laser"):
		play_all("break")
		call_deferred("_spawn_laser_particles", area.global_position)
		metal_sound.play()
		
		if area.has_method("set_direction"):
			Callable(area, "set_direction").call_deferred(-area.direction)
			#change the group
			area.call_deferred("remove_from_group", "enemy_laser")
			area.call_deferred("add_to_group", "lasers")
			
	elif area.is_in_group("saws"):
		Callable(area, "die_and_respawn").call_deferred()
		
func _spawn_laser_particles(spawn_pos: Vector2):
	if laser_shield_particles:
		var laser_shield_instance = laser_shield_particles.instantiate()
		get_parent().add_child(laser_shield_instance)
		laser_shield_instance.global_position = spawn_pos
		
func _spawn_break_particles(spawn_pos: Vector2):
	var explosion = shield_break_particles.instantiate()
	get_parent().add_child(explosion)
	explosion.global_position = spawn_pos
