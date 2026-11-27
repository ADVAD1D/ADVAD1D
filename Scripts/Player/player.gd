extends CharacterBody2D

#player variables
@export var speed: float
@export var rotation_speed: float = 3.5
@export var acceleration: float = 5.0
@export var shoot_timerate: float = 0.1
@export var safe_radius: float = 200.0
@export var friction: float = 1.0
@export var dash_speed_multiplier: float = 1.7
@export var dash_duration: float = 0.1
@export var dash_cooldown: float = 1.0
@export var dash_particles: PackedScene
## Ghost look while the dash's i-frames last (the hitbox is off): brighter than normal
## (HDR modulate, so it glows) and see-through, so the short invulnerability reads.
@export var dash_ghost_color: Color = Color(1.6, 2.4, 3.0, 0.2)
## How much the ghost's alpha pulses up while it lasts (shimmer).
@export var dash_ghost_shimmer: float = 0.2
## When the i-frames end the ship is solid again at once, then loses the glow over this.
@export var dash_glow_fade: float = 0.45
## Afterimages: while dashing the ship leaves glowing see-through copies of itself on its
## path, which fade out after the dash (the i-frames are 0.1 s, too short to read on the
## ship alone). How many per dash, spread evenly over `dash_duration`.
@export var dash_afterimage_count: int = 3
## How long each afterimage takes to fade out.
@export var dash_afterimage_lifetime: float = 0.4
## Colour and starting opacity of the afterimages (HDR, so they glow).
@export var dash_afterimage_color: Color = Color(1.2, 2.2, 3.0, 0.7)

#resources
@onready var player_collider = $CollisionShape2D
@onready var lsrsound: AudioStreamPlayer2D = $Lasersnd
@onready var dash_sound: AudioStreamPlayer2D = $Dashsnd
@onready var engine_trail: CPUParticles2D = $EngineTrail
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_collider: CollisionShape2D = $Hitbox/CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var muzzle: Marker2D = $Muzzle
@onready var vignette_light: PointLight2D = $PointLight2D

@export var ship_explosion_particles: PackedScene

#signals
signal died
signal dash(direction: Vector2)

#init script variables
var laser_scene = preload("res://Scenes/laser.tscn")
var can_shoot: bool = true
var player_died: bool = false
var is_dashing: bool = false
var can_dash: bool = true
var main_camera: Camera2D
var dash_camera_shake: float = 45.0
var dash_tween: Tween
var hitbox_disabled: bool = false
## Time left until the next dash afterimage.
var _afterimage_timer: float = 0.0
## Afterimages still to leave in the current dash.
var _afterimages_left: int = 0

func _ready() -> void:
	var player_score = GameManager.score
	sprite.texture = SkinManager.get_equipped_ship_texture()
	# Paints the ship with the player's two colours (the material lives in player.tscn
	# so the shader warm-up compiles it during the splash)
	SkinManager.apply_ship_colors(sprite, SkinManager.equipped_ship_index)
	# The trail and dash particles are drawn in greys: tint them with the ship's colour 1
	engine_trail.self_modulate = _particle_color()
	main_camera = get_viewport().get_camera_2d()
	_log_message(player_score)
	engine_trail.amount = 4
	engine_trail.fixed_fps = 0
	engine_trail.fract_delta = true
	vignette_light.shadow_enabled = false

	# Vars shown live in the debug menu (Tab). Velocity is already in the panel.
	DebugMenu.watch(self, "is_dashing", "Dashing")
	DebugMenu.watch(self, "can_dash", "Can dash")
	
	# `sudo hitbox_disable` in the chat console turns it off for the session
	hitbox_disabled = hitbox_disabled or GameManager.debug_hitbox_disabled
	if hitbox_disabled == true:
		hitbox_collider.disabled = true
		_log_message("PLAYER HITBOX DISABLED")
	else:
		return

## Ship colour 1 (body), used to tint the grey trail and dash particles.
func _particle_color() -> Color:
	return SkinManager.get_color(SkinManager.get_ship_color_index(1))

func _physics_process(delta: float) -> void:
	if player_died:
		return
		
	if is_dashing:
		move_and_collide(velocity * delta)
		_afterimage_timer -= delta
		if _afterimages_left > 0 and _afterimage_timer <= 0.0:
			_afterimage_timer = dash_duration / dash_afterimage_count
			_spawn_afterimage()
		return
		
	var relative_control_active: bool = GameManager.relative_control_active
		
	var is_moving = false
	
	# While the scanner powerup has uses, Shoot drives it (scanner.gd) instead of the lasers
	if Input.is_action_pressed("Shoot") and can_shoot and not _has_scanner():
			shoot()
			
	# --- RELATIVE MOVEMENT (Tank/Asteroids Controls) ---
	# In this mode, Left/Right inputs purely rotate the ship on its axis.
	# Up/Down inputs apply thrust forward or backward relative to the direction the ship is currently facing.
	if relative_control_active == true:
		var rotation_direction = Input.get_axis("Move_Left", "Move_Right")
		rotation_speed = 5.0
		rotation += rotation_direction * rotation_speed * delta
		
		var input_thrust = Input.get_axis("Move_Up", "Move_Down")
		var direction_relative = Vector2.UP.rotated(rotation) * -input_thrust
		
		if input_thrust != 0:
			velocity = velocity.lerp(direction_relative * speed, acceleration * delta)
			is_moving = true
		else:
			velocity = velocity.lerp(Vector2.ZERO, friction * delta)
			
		if Input.is_action_just_pressed("dash") and can_dash:
			var forward_vec = Vector2.UP.rotated(rotation)
			do_dash(forward_vec)
			
	else:
		# --- ABSOLUTE MOVEMENT (Standard Top-Down Arcade Controls) ---
		# In this mode, the input vector translates directly to world-space movement (e.g., Up always moves north).
		# The ship's rotation is automatically interpolated (lerped) to face the direction it is moving.
		var direction = Input.get_vector("Move_Left", "Move_Right", "Move_Up", "Move_Down")
		
		if direction != Vector2.ZERO:
			velocity = velocity.lerp(direction * speed, acceleration * delta)
			is_moving = true
			
			if not is_dashing:
				var target_rotation = direction.angle() + PI/2
				# 0.22 per tick at 60 ticks/s, kept the same at any physics tick rate
				rotation = lerp_angle(rotation, target_rotation, 1.0 - pow(0.78, delta * 60.0))
		else:
			velocity = velocity.lerp(Vector2.ZERO, friction * delta)
			
		# --- DASH ---
		# Only the cooldown limits it: it goes right away towards the input direction (or
		# where the ship faces if there's no input), whatever the ship's current rotation;
		# do_dash() snaps the ship to face it.
		if Input.is_action_just_pressed("dash") and can_dash:
			var move_direction = direction
			if move_direction == Vector2.ZERO:
				move_direction = -transform.y
			do_dash(move_direction.normalized())

	engine_trail.emitting = is_moving
		
	# --- APPLY MOVEMENT AND COLLISIONS ---
	if velocity != Vector2.ZERO:
		var collision = move_and_slide()
		
		if collision:
			velocity = Vector2.ZERO
			
	# Debug menu (Tab) drives this via GameManager.show_debug: repaint _draw().
	if GameManager.show_debug:
		queue_redraw()
		
func shoot():
	can_shoot = false
	lsrsound.play()
	var fire_direction = Vector2.UP.rotated(rotation)
	# Triple shot powerup (triple_shot.gd, a child of the player while it lasts): three
	# lasers fanned out from the muzzle instead of one
	var angles: Array[float] = [0.0]
	var triple_shot: Node = _get_triple_shot()
	if triple_shot:
		var spread: float = deg_to_rad(float(triple_shot.get("spread_degrees")))
		angles = [-spread, 0.0, spread]
	for angle in angles:
		var laser_instance = laser_scene.instantiate()
		laser_instance.global_position = muzzle.global_position
		laser_instance.start(fire_direction.rotated(angle))
		get_parent().add_child(laser_instance)

	await get_tree().create_timer(shoot_timerate, false, false, true).timeout
	can_shoot = true
	
## The scanner powerup (scanner.gd) leaves the group as soon as its last use is spent.
func _has_scanner() -> bool:
	for child in get_children():
		if child.is_in_group("player_scanner"):
			return true
	return false

func _get_triple_shot() -> Node:
	for child in get_children():
		if child.is_in_group("player_triple_shot") and not child.is_queued_for_deletion():
			return child
	return null

# --- DASH: EXECUTION AND EFFECTS ---
# Handles the entire dash sequence: visual effects, invincibility, and physics push.
func do_dash(direction: Vector2):
	if main_camera:
		main_camera.shake(dash_camera_shake, dash_duration)
	rotation = direction.angle() + PI/2
	is_dashing = true
	can_dash = false
	velocity = direction * speed * dash_speed_multiplier
	dash.emit(direction)
	dash_sound.play()
	
	if dash_particles:
		var dash_particles_instance = dash_particles.instantiate()
		dash_particles_instance.self_modulate = _particle_color()
		get_parent().add_child(dash_particles_instance)
		dash_particles_instance.global_position = global_position
	
	# Ghost look for exactly as long as the hitbox is off, and a trail of afterimages
	# (the first one right at the starting point)
	_start_dash_ghost()
	_afterimages_left = dash_afterimage_count
	if _afterimages_left > 0:
		_spawn_afterimage()
		_afterimage_timer = dash_duration / dash_afterimage_count

	# Invincibility frames (i-frames): disable hitbox during dash
	hitbox_collider.set_deferred("disabled", true)
	await get_tree().create_timer(dash_duration, false, false, true).timeout

	is_dashing = false

	# Restore hitbox (unless it's disabled for debugging) and wait for cooldown before
	# allowing another dash
	hitbox_collider.set_deferred("disabled", hitbox_disabled)
	_end_dash_ghost()
	await get_tree().create_timer(dash_cooldown, false, false, true).timeout
	can_dash = true

## The ship turns bright and see-through, its alpha shimmering, while the i-frames last.
func _start_dash_ghost() -> void:
	if dash_tween:
		dash_tween.kill()
	sprite.modulate = dash_ghost_color
	var shimmer_alpha: float = minf(dash_ghost_color.a + dash_ghost_shimmer, 1.0)
	var half: float = dash_duration * 0.5
	# Same clock as the dash timer (it ignores the time scale too)
	dash_tween = create_tween().set_ignore_time_scale(true).set_trans(Tween.TRANS_SINE)
	dash_tween.tween_property(sprite, "modulate:a", shimmer_alpha, half)
	dash_tween.tween_property(sprite, "modulate:a", dash_ghost_color.a, half)

## The i-frames are over: solid at once (so the ship looks hittable exactly when it is),
## keeping the glow, which fades back to normal.
func _end_dash_ghost() -> void:
	if player_died or not is_inside_tree():
		return
	if dash_tween:
		dash_tween.kill()
	var glow: Color = dash_ghost_color
	glow.a = 1.0
	sprite.modulate = glow
	dash_tween = create_tween()
	dash_tween.tween_property(sprite, "modulate", Color.WHITE, dash_glow_fade).set_ease(Tween.EASE_IN)

## A glowing see-through copy of the ship where it is now, left behind in the arena (under
## the ship, same z) and fading out. Same texture and colour material as the ship.
func _spawn_afterimage() -> void:
	var parent: Node = get_parent()
	_afterimages_left -= 1
	if parent == null or sprite.texture == null or not is_inside_tree():
		return
	var ghost := Sprite2D.new()
	ghost.texture = sprite.texture
	ghost.material = sprite.material
	ghost.centered = sprite.centered
	ghost.offset = sprite.offset
	ghost.flip_h = sprite.flip_h
	ghost.flip_v = sprite.flip_v
	ghost.hframes = sprite.hframes
	ghost.vframes = sprite.vframes
	ghost.frame = sprite.frame
	ghost.region_enabled = sprite.region_enabled
	ghost.region_rect = sprite.region_rect
	ghost.z_index = z_index
	ghost.modulate = dash_afterimage_color
	parent.add_child(ghost)
	parent.move_child(ghost, get_index())
	ghost.global_transform = sprite.global_transform
	var fade: Tween = ghost.create_tween().set_ignore_time_scale(true)
	fade.tween_property(ghost, "modulate:a", 0.0, dash_afterimage_lifetime).set_ease(Tween.EASE_OUT)
	fade.tween_callback(ghost.queue_free)

func _draw() -> void:
	if GameManager.show_debug == false:
		return

	_log_message("DEBUG TRAIL AND SAFE RADIUS ACTIVATE")
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

func die():
	if player_died:
		return
	## The perform death effects func instanciates every time to death and animate the tween
	# Capped at 9999 (it's shown in the pause menu); the "die 1000 times" achievement needs >= 1000
	GameManager.deaths_count = min(GameManager.deaths_count + 1, 9999)
	GameManager.save_deaths_count()
	AchievementManager.raise_stat(&"deaths", GameManager.deaths_count)
	_perform_death_effects()
	died.emit()

func vanish():
	if player_died:
		return
	_perform_death_effects()
	
## Simple perform death effect: the sprite turned to red color in modulate
func _perform_death_effects():
	player_died = true
	
	for child in get_children():
		if child.is_in_group("player_shield"):
			if child.has_method("_on_timeout"):
				child._on_timeout()
	
	if dash_tween:
		dash_tween.kill()
		
	var current_brightness = max(sprite.modulate.r, max(sprite.modulate.g, sprite.modulate.b))
	sprite.modulate = Color(max(1.0, current_brightness), 0, 0, sprite.modulate.a)
	if engine_trail:
		engine_trail.emitting = false
	player_collider.set_deferred("disabled", true)
	
func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("asteroides") or area.is_in_group("enemy_laser") or area.is_in_group("saws"):
		if area.is_in_group("enemy_laser"):
			EnemyLaserPool.release(area)

		die() # Replace with function body.

func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemigos"):
		_log_message("Es un enemigo")
		die()
		
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

func _exit_tree() -> void:
	# Release inputs to prevent ghost movement from the virtual joystick on scene restart
	Input.action_release("Move_Left")
	Input.action_release("Move_Right")
	Input.action_release("Move_Up")
	Input.action_release("Move_Down")
