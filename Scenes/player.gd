extends CharacterBody2D

@export var speed: float
@export var acceleration: float = 5.0
@export var shoot_timerate: float = 0.1
@export var safe_radius: float = 400.0
@export var friction: float = 1.0

@onready var lsrsound = $Lasersnd

signal died

var show_debug: bool = false

var laser_scene = preload("res://Scenes/laser.tscn")

var can_shoot: bool = true

var player_died: bool = false

func _ready() -> void:
	var player_score = GameManager.score
	print(player_score)

func _physics_process(delta: float) -> void:
	
	if player_died:
		return
	
	if Input.is_action_just_pressed("Shoot") and can_shoot:
			shoot()
	
	var direction = Input.get_vector("Move_Left", "Move_Right", "Move_Up", "Move_Down")
	if direction != Vector2.ZERO:
		velocity = velocity.lerp(direction * speed, acceleration * delta)
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
			
func shoot():
	can_shoot = false
	lsrsound.play()
	var laser_instance = laser_scene.instantiate()
	laser_instance.global_position = $Muzzle.global_position
	laser_instance.start(rotation)
	get_parent().add_child(laser_instance)
	
	await get_tree().create_timer(shoot_timerate).timeout
	can_shoot = true
	
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
	if area.is_in_group("asteroides"):
		player_died = true
		died.emit()
		hide()
		$CollisionShape2D.set_deferred("disabled", true) # Replace with function body.
