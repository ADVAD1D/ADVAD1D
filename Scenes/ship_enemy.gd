extends CharacterBody2D

@export var speed: float = 250.0
@export var ideal_distance: float = 100.0
@export var fire_range: float = 500.0 
@export var distance_margin: float = 50.0
@export var strafe_speed: float = 150.0
@export var strafe_influence: float = 0.6
@export var acceleration: float = 4.0
@export var friction: float = 2.0

@onready var hitbox: Area2D = $Hitbox
@onready var laser_sound: AudioStreamPlayer2D = $EnemyLsrSound

var show_debug: bool = false

var bullet_scene = preload("res://Scenes/enemy_laser.tscn")

var player: Node2D

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	hitbox.hit.connect(_on_hit)
	
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
		
	velocity = velocity.lerp(target_velocity, acceleration * delta)
	
	move_and_slide()
	
	if distance_to_player < fire_range:
		shoot()
		
	if Input.is_action_just_pressed("debug"):
		show_debug = not show_debug
		queue_redraw()
	
func shoot() -> void:
	if $ShootTimer.is_stopped():
		var bullet_instance = bullet_scene.instantiate()
		get_parent().add_child(bullet_instance)
		bullet_instance.global_position = $Muzzle.global_position
		bullet_instance.start(rotation)
		$ShootTimer.start()
		laser_sound.play()
		
func _draw() -> void:
	
	if not show_debug:
		return
	
	if show_debug:
		var circle_color = Color.RED
		circle_color.a = 0.3
		draw_circle(Vector2.ZERO, fire_range, circle_color)

func _on_hit() -> void:
	queue_free()
