class_name LaserGun
extends Area2D
## Arena 2 enemy: a gun with green eyes mounted on a side wall. It slides up and down the
## wall and every few seconds stops, charges (a blinking aim line) and fires a laser beam
## across the arena. The beam is a RayCast2D: it ends at the first wall or at the player,
## and kills the player unless they are dashing or have a laser shield (which blocks it).
## Player lasers and ally saws destroy it. LaserGunSpawner places it on a wall: it sets
## `facing` and the patrol range before adding it to the tree, then calls setup().

signal died(gun: LaserGun)

enum State { ENTERING, PATROL, CHARGE, FIRE, DYING }

## Half size of the gun on screen (world units), to tell when it is off camera.
const HALF_SIZE: Vector2 = Vector2(84.0, 48.0)
## The off-screen marker keeps this far (world units) from the camera edge.
const MARKER_MARGIN: float = 110.0
const MARKER_COLOR: Color = Color(0.22, 1.0, 0.42)

## Vertical speed while patrolling the wall.
@export var patrol_speed: float = 460.0
## Seconds of warning (aim line) before the beam.
@export var charge_time: float = 0.9
## Seconds the beam stays on.
@export var fire_time: float = 0.55
## Seconds of patrol between shots (random in this range, scaled by setup()).
@export var cooldown_min: float = 2.0
@export var cooldown_max: float = 3.5
@export var beam_range: float = 4000.0
@export var health: int = 2
@export var score_value: int = 300

## 1 = mounted on the left wall shooting right, -1 = on the right wall shooting left.
var facing: int = 1
## Global y range the gun patrols.
var top_limit: float = -1000.0
var bottom_limit: float = 1000.0

var _state: State = State.ENTERING
var _direction: float = 1.0
var _timer: float = 0.0
var _cooldown_scale: float = 1.0
var _beam_time: float = 0.0
## The walls are usually off camera (the arena is wider than the view), so a small icon
## with an arrow sits on the screen edge at the gun's height while it can't be seen.
var _edge_marker: Node2D
## The beam as a shape, to test it against the player's hitbox.
var _beam_shape: RectangleShape2D = RectangleShape2D.new()
var _explosion_sound: AudioStreamPlayer2D = preload(
		"res://Assets/Audio/AudioScenes/ship_enemy_explosion.tscn").instantiate()

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var muzzle: Marker2D = $Muzzle
@onready var ray: RayCast2D = $Muzzle/RayCast2D
@onready var aim_line: Line2D = $AimLine
@onready var beam_glow: Line2D = $BeamGlow
@onready var beam_core: Line2D = $BeamCore
## Flash where the beam ends (sprite animation, no particles).
@onready var impact: AnimatedSprite2D = $Impact
## Break animation played on death, instead of particles (laser_gun_break.png).
@onready var break_sprite: AnimatedSprite2D = $BreakSprite
@onready var charge_sound: AudioStreamPlayer2D = $ChargeSound
@onready var fire_sound: AudioStreamPlayer2D = $FireSound


## Difficulty from PhaseManager (through the spawner): "cooldown_scale" < 1 shoots more often.
func setup(config: Dictionary) -> void:
	_cooldown_scale = config.get("cooldown_scale", 1.0)


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	# The scene is drawn facing right; mirror the parts for the right wall
	sprite.flip_h = facing < 0
	break_sprite.flip_h = facing < 0
	break_sprite.visible = false
	muzzle.position.x *= facing
	collision_shape.position.x *= facing
	ray.target_position = Vector2(beam_range * facing, 0)
	_hide_beam()
	_build_edge_marker()

	# Materialises on the wall (spawn animation of laser_gun_spawn.png: a slit opens, the
	# gun is scanned in as a hologram, then flashes real). It can't be hit until it's done.
	_state = State.ENTERING
	collision_shape.set_deferred("disabled", true)
	sprite.play(&"spawn")
	sprite.animation_finished.connect(_on_spawned, CONNECT_ONE_SHOT)


func _on_spawned() -> void:
	if _state != State.ENTERING:
		return
	collision_shape.set_deferred("disabled", false)
	_start_patrol()


func _process(_delta: float) -> void:
	_update_edge_marker()


func _physics_process(delta: float) -> void:
	match _state:
		State.PATROL:
			_patrol(delta)
		State.CHARGE:
			_charge(delta)
		State.FIRE:
			_fire(delta)


func _patrol(delta: float) -> void:
	position.y += _direction * patrol_speed * delta
	if position.y <= top_limit:
		position.y = top_limit
		_direction = 1.0
	elif position.y >= bottom_limit:
		position.y = bottom_limit
		_direction = -1.0
	_timer -= delta
	if _timer <= 0.0:
		_start_charge()


func _charge(delta: float) -> void:
	_timer -= delta
	_beam_time += delta
	# The aim line blinks faster as the shot gets closer (game time, so time slow slows it)
	var urgency: float = 1.0 - clampf(_timer / charge_time, 0.0, 1.0)
	var blink: float = absf(sin(_beam_time * (8.0 + 30.0 * urgency)))
	_set_line(aim_line, _cast_beam())
	aim_line.modulate.a = 0.35 + 0.45 * blink
	if _timer <= 0.0:
		_start_fire()


func _fire(delta: float) -> void:
	_timer -= delta
	_beam_time += delta
	var end: Vector2 = _hit_player(muzzle.global_position, _cast_beam())
	_destroy_enemies(muzzle.global_position, end)
	_set_line(beam_glow, end)
	_set_line(beam_core, end)
	var flicker: float = 1.0 + 0.15 * sin(_beam_time * 60.0)
	beam_glow.width = 48.0 * flicker
	beam_core.width = 16.0 * flicker
	impact.position = to_local(end)
	if _timer <= 0.0:
		_start_patrol()


func _start_patrol() -> void:
	_state = State.PATROL
	_hide_beam()
	sprite.play(&"idle")
	_timer = randf_range(cooldown_min, cooldown_max) * _cooldown_scale


func _start_charge() -> void:
	_state = State.CHARGE
	_timer = charge_time
	_beam_time = 0.0
	aim_line.visible = true
	sprite.play(&"charge")
	charge_sound.play()


func _start_fire() -> void:
	_state = State.FIRE
	_timer = fire_time
	_beam_time = 0.0
	aim_line.visible = false
	beam_glow.visible = true
	beam_core.visible = true
	impact.visible = true
	impact.play(&"impact")
	sprite.play(&"fire")
	fire_sound.play()


func _hide_beam() -> void:
	aim_line.visible = false
	beam_glow.visible = false
	beam_core.visible = false
	impact.visible = false
	impact.stop()


## Casts the beam from the muzzle and returns where it ends (global): the first wall
## (StaticBody2D). It goes through every other body (enemy ships, the player's body); the
## player is checked against their hitbox in _hit_player().
func _cast_beam() -> Vector2:
	ray.clear_exceptions()
	ray.force_raycast_update()
	for i in 12:
		if not ray.is_colliding() or ray.get_collider() is StaticBody2D:
			break
		ray.add_exception(ray.get_collider())
		ray.force_raycast_update()
	if ray.is_colliding():
		return ray.get_collision_point()
	return ray.to_global(ray.target_position)


func _set_line(line: Line2D, global_end: Vector2) -> void:
	line.points = PackedVector2Array([muzzle.position, to_local(global_end)])


## Hurts the player when the beam (from -> to) overlaps their Hitbox shape, like every
## other hazard: a disabled hitbox (dash i-frames, debugging) is never hit. A laser shield
## blocks the beam, so it then ends at the player. Returns where the beam ends.
func _hit_player(from: Vector2, to: Vector2) -> Vector2:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return to
	var hitbox: CollisionShape2D = player.get_node_or_null("Hitbox/CollisionShape2D")
	if hitbox == null or hitbox.disabled or hitbox.shape == null:
		return to
	_beam_shape.size = Vector2(from.distance_to(to), beam_core.width)
	var beam_xform: Transform2D = Transform2D(0.0, (from + to) * 0.5)
	if not hitbox.shape.collide(hitbox.global_transform, _beam_shape, beam_xform):
		return to
	if _has_shield(player):
		return Vector2(player.global_position.x, to.y)
	if player.has_method("die"):
		player.die()
	return to


## The beam also destroys the saws, enemy ships and asteroids it crosses (from -> to, after
## a shield may have cut it short). Their own death functions are used (die_and_respawn(),
## Asteroid.explode()): they give no score and no "saws destroyed" progress (only the
## player's lasers do), and the spawners replace them. Other laser guns and powerups are
## left alone.
func _destroy_enemies(from: Vector2, to: Vector2) -> void:
	_beam_shape.size = Vector2(from.distance_to(to), beam_core.width)
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = _beam_shape
	query.transform = Transform2D(0.0, (from + to) * 0.5)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = [get_rid()]
	var hits: Array[Dictionary] = get_world_2d().direct_space_state.intersect_shape(query, 32)
	for hit in hits:
		var target: Object = hit.collider
		if not target is Node:
			continue
		if target.is_in_group("asteroides") and target.has_method("explode"):
			target.explode()
		elif (target.is_in_group("saws") or target.is_in_group("enemigos")) \
				and target.has_method("die_and_respawn"):
			target.die_and_respawn()


func _has_shield(player: Node) -> bool:
	for child in player.get_children():
		if child.is_in_group("player_shield"):
			return true
	return false


func _on_area_entered(area: Area2D) -> void:
	if _state == State.DYING:
		return
	if area.is_in_group("lasers"):
		area.queue_free()
		health -= 1
		if health <= 0:
			GameManager.add_score(score_value)
			# Only guns the player shoots down count (GUN BREAKER achievement)
			AchievementManager.add_stat(&"laser_guns_destroyed")
			die_and_respawn()
		else:
			_flash()
	elif area.is_in_group("allies"):
		die_and_respawn()


func _flash() -> void:
	sprite.modulate = Color(3.0, 3.0, 3.0)
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)


## Destroyed by the player: breaks apart and tells the spawner (which brings another one).
func die_and_respawn() -> void:
	if _state == State.DYING:
		return
	_begin_dying()
	await _break_apart()
	died.emit(self)
	queue_free()


## Cleared by PhaseManager (phase change): breaks apart without respawning.
func die_silently() -> void:
	if _state == State.DYING:
		return
	_begin_dying()
	# Staggered like the other enemies so a board clear doesn't spike
	await get_tree().create_timer(randf_range(0.01, 0.25)).timeout
	await _break_apart()
	queue_free()


func _begin_dying() -> void:
	_state = State.DYING
	_hide_beam()
	_edge_marker.visible = false
	charge_sound.stop()
	fire_sound.stop()
	collision_shape.set_deferred("disabled", true)


# --- Off-screen marker ------------------------------------------------------------------

func _build_edge_marker() -> void:
	_edge_marker = Node2D.new()
	_edge_marker.top_level = true
	_edge_marker.z_index = 20
	_edge_marker.visible = false
	var icon: Sprite2D = Sprite2D.new()
	icon.texture = sprite.sprite_frames.get_frame_texture(&"idle", 0)
	icon.scale = Vector2(2.0, 2.0)
	icon.flip_h = facing < 0
	_edge_marker.add_child(icon)
	# Arrow pointing at the gun's wall
	var arrow: Polygon2D = Polygon2D.new()
	arrow.color = MARKER_COLOR
	arrow.polygon = PackedVector2Array([Vector2(-100.0 * facing, 0.0),
			Vector2(-64.0 * facing, -28.0), Vector2(-64.0 * facing, 28.0)])
	_edge_marker.add_child(arrow)
	add_child(_edge_marker)


func _update_edge_marker() -> void:
	if _state == State.DYING:
		return
	var view: Rect2 = _camera_view()
	var gun_rect: Rect2 = Rect2(global_position - HALF_SIZE, HALF_SIZE * 2.0)
	_edge_marker.visible = not view.intersects(gun_rect)
	if not _edge_marker.visible:
		return
	_edge_marker.global_position = Vector2(
			clampf(global_position.x, view.position.x + MARKER_MARGIN, view.end.x - MARKER_MARGIN),
			clampf(global_position.y, view.position.y + MARKER_MARGIN, view.end.y - MARKER_MARGIN))
	# Blinks while charging and stays bright while firing
	if _state == State.CHARGE:
		_edge_marker.modulate.a = 0.4 + 0.6 * absf(sin(_beam_time * 20.0))
	else:
		_edge_marker.modulate.a = 1.0 if _state == State.FIRE else 0.8


## The part of the world the camera shows, in global coordinates.
func _camera_view() -> Rect2:
	var to_world: Transform2D = get_viewport().get_canvas_transform().affine_inverse()
	var size: Vector2 = get_viewport().get_visible_rect().size
	return Rect2(to_world * Vector2.ZERO, to_world.basis_xform(size))


## Swaps the gun for its break animation (flash, cracks, pieces flying, blast, smoke) and
## waits for it to end. Plays the enemy ships' death sound where the gun is (it is a 2D
## positional sound: left at the scene origin it would be faint, the walls are far from it);
## the sound frees itself when it finishes.
func _break_apart() -> void:
	sprite.visible = false
	break_sprite.visible = true
	break_sprite.play(&"break")
	get_tree().current_scene.add_child(_explosion_sound)
	_explosion_sound.global_position = global_position
	_explosion_sound.play()
	await break_sprite.animation_finished
	break_sprite.visible = false
