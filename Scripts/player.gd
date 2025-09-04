extends CharacterBody2D

@export var speed: float
@export var acceleration: float = 5.0
@export var shoot_timerate: float = 0.1
@export var safe_radius: float = 200.0
@export var friction: float = 1.0
@export var dash_speed_multiplier: float = 2.0
@export var dash_duration: float = 0.1
@export var dash_cooldown: float = 1.0

@onready var lsrsound = $Lasersnd
@onready var engine_trail: GPUParticles2D = $EngineTrail
@onready var hitbox_collider: CollisionShape2D = $Hitbox/CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D

@export var ship_explosion_particles: PackedScene

signal died

var show_debug: bool = false

var laser_scene = preload("res://Scenes/laser.tscn")

var can_shoot: bool = true

var player_died: bool = false

var is_dashing: bool = false

var can_dash: bool = true

var dash_buffered: bool = false

var buffered_direction: Vector2 = Vector2.ZERO

func _ready() -> void:
	var player_score = GameManager.score
	print(player_score)

func _physics_process(delta: float) -> void:
	
	if player_died:
		return
		
	if is_dashing:
		move_and_collide(velocity * delta)
		return
		
	if Input.is_action_just_pressed("dash") and can_dash:
		var move_direction = Input.get_vector("Move_Left", "Move_Right", "Move_Up", "Move_Down")
		
		if move_direction == Vector2.ZERO:
			move_direction = -transform.y
		
		if can_start_dash(move_direction):
			do_dash(move_direction.normalized())
		else:
			dash_buffered = true
			buffered_direction = move_direction.normalized()
			
	if dash_buffered and can_dash and can_start_dash(buffered_direction):
		do_dash(buffered_direction)
		dash_buffered = false
	
	if Input.is_action_pressed("Shoot") and can_shoot:
			shoot()
	
	var direction = Input.get_vector("Move_Left", "Move_Right", "Move_Up", "Move_Down")
	engine_trail.emitting = (direction != Vector2.ZERO)
	
	if direction != Vector2.ZERO:
		velocity = velocity.lerp(direction * speed, acceleration * delta)
		if not is_dashing:
			var target_rotation = direction.angle() + PI/2
			rotation = lerp_angle(rotation, target_rotation, 0.22)
	else:
		velocity = velocity.lerp(Vector2.ZERO, friction * delta)
		
		
	if velocity != Vector2.ZERO:
		var collision = move_and_collide(velocity * delta)
		
		if collision:
			velocity = Vector2.ZERO
			
	if Input.is_action_just_pressed("debug"):
		show_debug = not show_debug
		queue_redraw()
		
func can_start_dash(direction: Vector2) -> bool:
	if direction == Vector2.ZERO:
		return false
		
	var target_rotation = direction.angle() + PI/2
	var diff = abs(wrapf(rotation - target_rotation, -PI, PI))
	return diff < deg_to_rad(6) 

func shoot():
	can_shoot = false
	lsrsound.play()
	var laser_instance = laser_scene.instantiate()
	laser_instance.global_position = $Muzzle.global_position
	laser_instance.start(rotation)
	get_parent().add_child(laser_instance)
	
	await get_tree().create_timer(shoot_timerate).timeout
	can_shoot = true
	
func do_dash(direction: Vector2):
	rotation = direction.angle() + PI/2
	is_dashing = true
	can_dash = false
	velocity = direction * speed * dash_speed_multiplier
	
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(2, 2, 2, 1), 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.3).set_ease(Tween.EASE_IN)
	
	hitbox_collider.disabled = true
	await get_tree().create_timer(dash_duration).timeout
	
	is_dashing = false
	
	hitbox_collider.disabled = false
	
	await get_tree().create_timer(dash_cooldown).timeout
	can_dash = true
	
func _draw() -> void:
	
	if not show_debug:
		return
	
	if show_debug:
		var circle_color = Color.AQUAMARINE
		circle_color.a = 0.3
		draw_circle(Vector2.ZERO, safe_radius, circle_color)
		
		var walls = get_tree().get_nodes_in_group("colisiones")
		
		for wall in walls:
			var collider = wall.find_child("CollisionShape2D")
			
			if collider and collider.shape:
				if collider.shape is CircleShape2D:
					draw_circle(Vector2.ZERO, collider.shape.radius, Color.RED)
				elif collider.shape is RectangleShape2D:
					draw_rect(Rect2(-collider.shape.size / 2, collider.shape.size), Color.RED, false, 2.0)
					


func _on_hitbox_area_entered(area: Area2D) -> void:
	if player_died:
		return
	if area.is_in_group("asteroides") or area.is_in_group("enemy_laser") or area.is_in_group("saws"):
		if area.is_in_group("enemy_laser"):
			area.queue_free()
			
		var ship_exp_instance = ship_explosion_particles.instantiate()
		add_sibling(ship_exp_instance)
		ship_exp_instance.position = position
		
		player_died = true
		died.emit()
		hide()
		$CollisionShape2D.set_deferred("disabled", true) # Replace with function body.
