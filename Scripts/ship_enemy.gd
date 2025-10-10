extends CharacterBody2D

var speed: float = 300.0
var ideal_distance: float = 100.0
var fire_range: float = 1500.0 
var distance_margin: float = 50.0
var strafe_speed: float = 150.0
var strafe_influence: float = 0.6
var acceleration: float = 4.0
var friction: float = 2.0
var separation_strength: float = 100.0

@export var explosion_particles: PackedScene

var is_dying: bool = false

signal died

@onready var hitbox: Area2D = $Hitbox

@onready var shoot_marker: Marker2D = $Muzzle

@onready var laser_sound: AudioStreamPlayer2D = $EnemyLsrSound

@onready var separation_area = $SeparationArea

@onready var shoot_timer: Timer = $ShootTimer

@onready var engine_trail: GPUParticles2D = $EngineTrail

var explosion_sound: AudioStreamPlayer2D = preload("res://Assets/Audio/AudioScenes/ship_enemy_explosion.tscn").instantiate()

var show_debug: bool = false

var bullet_scene = preload("res://Scenes/enemy_laser.tscn")

var player: Node2D

func setup(config: Dictionary):
	speed = config.get("speed", 250.0)
	print(config)
	$ShootTimer.wait_time = config.get("shoot_timerate", 0.2)
	
func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	hitbox.hit.connect(_on_hit)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(2.5, 2.5), 0.2).from(Vector2.ZERO)
	
func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		velocity = velocity.lerp(Vector2.ZERO, 0.1)
		move_and_slide()
		return
		
	var vector_to_player = player.global_position - global_position
	var distance_to_player = vector_to_player.length()

	var target_rotation = vector_to_player.angle() + PI / 2
	rotation = lerp_angle(rotation, target_rotation, 0.1)

	var target_velocity = Vector2.ZERO

	if distance_to_player > ideal_distance + distance_margin:
		target_velocity = vector_to_player.normalized() * speed
			
	elif distance_to_player < ideal_distance - distance_margin:
		target_velocity = -vector_to_player.normalized() * speed
	else:
		target_velocity = vector_to_player.orthogonal().normalized() * strafe_speed
		shoot()
	
	if distance_to_player < fire_range:
		shoot()
		
	if Input.is_action_just_pressed("debug"):
		show_debug = not show_debug
		queue_redraw()
	
	var separation_vector: Vector2 = Vector2.ZERO
	var neighbors = separation_area.get_overlapping_bodies()
	
	if not neighbors.is_empty():
		for neighbor in neighbors:
			separation_vector += (neighbor.global_position - global_position)
		
		separation_vector = -separation_vector.normalized()

	target_velocity += separation_vector * separation_strength
	
	velocity = velocity.lerp(target_velocity, acceleration * delta)
	move_and_slide()
	
func shoot() -> void:
	if shoot_timer.is_stopped():
		var bullet_instance = bullet_scene.instantiate()
		get_parent().add_child(bullet_instance)
		bullet_instance.global_position = shoot_marker.global_position
		
		#UP for direction of the laser in instance
		#Indica la dirección del laser en su instancia
		var fire_direction = Vector2.UP.rotated(rotation)
		bullet_instance.start(fire_direction)
		
		shoot_timer.start()
		laser_sound.play()
		
func _draw() -> void:
	
	if not show_debug:
		return
	
	if show_debug:
		var circle_color = Color.RED
		circle_color.a = 0.3
		draw_circle(Vector2.ZERO, fire_range, circle_color)

func _on_hit(area_collided: Area2D) -> void:
	if area_collided.is_in_group("lasers"):
		GameManager.add_score(100)
		area_collided.queue_free()
		die_and_respawn()

func die_and_respawn():
	if is_dying:
		return
	is_dying = true
	
	set_physics_process(false)
	
	$CollisionShape2D.set_deferred("disabled", true)
	shoot_marker.set_deferred("disabled", true)
	
	var particles_instance = explosion_particles.instantiate()
	add_sibling(particles_instance)
	particles_instance.position = position
	
	hide()
	get_tree().current_scene.add_child(explosion_sound)
	explosion_sound.play()
	
	await explosion_sound.finished
	died.emit(self)
	queue_free()

func die_silently():
	if is_dying:
		return
	is_dying = true
	
	set_physics_process(false)
	
	$CollisionShape2D.set_deferred("disabled", true)
	shoot_marker.set_deferred("disabled", true)
	
	var particles_instance = explosion_particles.instantiate()
	add_sibling(particles_instance)
	particles_instance.position = position
	
	hide()
	get_tree().current_scene.add_child(explosion_sound)
	explosion_sound.play()
	
	await explosion_sound.finished
	queue_free()
