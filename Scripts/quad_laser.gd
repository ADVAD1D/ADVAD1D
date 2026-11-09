class_name QuadLaser
extends Node2D
## Arena 2 powerup (picked up from QuadLaserPickup): four mini cannons pop out of the
## centre of the player's ship, one per diagonal, and fire four laser beams at the same
## time, a few volleys in a row. Each beam is a RayCast2D that only stops at walls
## (StaticBody2D), like the laser guns' beam, and destroys the asteroids, saws, enemy
## ships and enemy lasers it crosses, scoring like the player's own lasers. The laser guns
## on the walls, ally saws and powerups are left alone.
##
## It is a child of the player, so it turns with the ship. In group "player_quad_laser",
## so another pickup isn't collected while it's active. Built in code (no sprites).

enum State { DEPLOY, CHARGE, FIRE, GAP, RETRACT }

## Beam directions, in degrees from the ship's nose: an X around the ship.
const ANGLES: Array[float] = [45.0, 135.0, -135.0, -45.0]
const BEAM_GLOW: Color = Color(0.25, 0.95, 1.0, 0.45)
const BEAM_CORE: Color = Color(0.9, 1.0, 1.0)
const AIM_COLOR: Color = Color(0.25, 0.95, 1.0)
const CANNON_FILL: Color = Color(0.06, 0.72, 0.84)
const CANNON_EDGE: Color = Color(0.02, 0.2, 0.24)
const CANNON_TIP: Color = Color(0.64, 1.0, 1.0)
## Length of laser_gun_charge.ogg / laser_gun_fire.ogg, to fit them to charge/fire time.
const CHARGE_SOUND_LENGTH: float = 0.9
const FIRE_SOUND_LENGTH: float = 0.55

## Volleys fired before the cannons retract.
@export var volleys: int = 1
## Seconds for the cannons to come out / go back in.
@export var deploy_time: float = 0.25
## Seconds of blinking aim lines before each volley.
@export var charge_time: float = 0.3
## Seconds each volley's beams stay on.
@export var fire_time: float = 0.45
## Seconds between volleys.
@export var volley_gap: float = 0.45
@export var beam_range: float = 3000.0
## Distance (in the player's local units) from the ship's centre to each muzzle.
@export var muzzle_distance: float = 24.0
## Beam widths in the player's local units (the player is scaled ~1.85).
@export var glow_width: float = 16.0
@export var core_width: float = 5.0
## Width of the beam (world units) when testing what it hits.
@export var hit_width: float = 22.0
## Damage to a boss (saw_boss.gd, group "bosses") per volley: the beams touch it every
## physics frame, so each boss takes it once per volley however many beams cross it.
@export var boss_damage: int = 8

var _state: State = State.DEPLOY
var _timer: float = 0.0
var _volley: int = 0
var _beam_time: float = 0.0
var _pivots: Array[Node2D] = []
var _rays: Array[RayCast2D] = []
var _aims: Array[Line2D] = []
var _glows: Array[Line2D] = []
var _cores: Array[Line2D] = []
var _beam_shape: RectangleShape2D = RectangleShape2D.new()
## Bosses already hurt by the current volley.
var _bosses_hit: Array[Node] = []

@onready var charge_sound: AudioStreamPlayer2D = $ChargeSound
@onready var fire_sound: AudioStreamPlayer2D = $FireSound


func _ready() -> void:
	add_to_group("player_quad_laser")
	# First child of the player: drawn under the ship sprite (only the barrel ends stick
	# out of the hull) but still over the arena (a negative z_index would hide it there)
	get_parent().move_child.call_deferred(self, 0)
	charge_sound.pitch_scale = CHARGE_SOUND_LENGTH / charge_time
	fire_sound.pitch_scale = FIRE_SOUND_LENGTH / fire_time
	for angle in ANGLES:
		_build_cannon(deg_to_rad(angle))
	_hide_lines()

	# The cannons pop out of the ship's centre
	scale = Vector2.ZERO
	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_BOUND)
	tween.tween_property(self, "scale", Vector2.ONE, deploy_time) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_state = State.DEPLOY
	_timer = deploy_time


func _physics_process(delta: float) -> void:
	_timer -= delta
	_beam_time += delta
	match _state:
		State.DEPLOY:
			if _timer <= 0.0:
				_start_charge()
		State.CHARGE:
			if _timer <= 0.0:
				_start_fire()
		State.FIRE:
			for i in _pivots.size():
				_destroy_targets(_muzzle(i), _cast(i))
			if _timer <= 0.0:
				_end_volley()
		State.GAP:
			if _timer <= 0.0:
				_start_charge()


## The beams are drawn every rendered frame from a fresh cast, once the ship has moved and
## turned. The lines live in the cannons' local space, so drawing a cast made earlier (in
## the physics tick, before a fast turn or a dash, which snaps the rotation) turned the
## whole beam with the ship and swung its far end through the walls.
func _process(_delta: float) -> void:
	match _state:
		State.CHARGE:
			var blink: float = absf(sin(_beam_time * 30.0))
			for i in _pivots.size():
				_set_line(i, _aims[i], _cast(i))
				_aims[i].modulate.a = 0.3 + 0.5 * blink
		State.FIRE:
			var flicker: float = 1.0 + 0.15 * sin(_beam_time * 60.0)
			for i in _pivots.size():
				var end: Vector2 = _cast(i)
				_set_line(i, _glows[i], end)
				_set_line(i, _cores[i], end)
				_glows[i].width = glow_width * flicker
				_cores[i].width = core_width * flicker


# --- States -------------------------------------------------------------------

func _start_charge() -> void:
	_state = State.CHARGE
	_timer = charge_time
	_beam_time = 0.0
	_hide_lines()
	for aim in _aims:
		aim.visible = true
	charge_sound.play()


func _start_fire() -> void:
	_state = State.FIRE
	_timer = fire_time
	_beam_time = 0.0
	_bosses_hit.clear()
	_hide_lines()
	for i in _pivots.size():
		_glows[i].visible = true
		_cores[i].visible = true
	fire_sound.play()


func _end_volley() -> void:
	_hide_lines()
	_volley += 1
	if _volley < volleys:
		_state = State.GAP
		_timer = volley_gap
		return
	# Last volley: the cannons go back in and the powerup ends
	_state = State.RETRACT
	set_physics_process(false)
	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_BOUND)
	tween.tween_property(self, "scale", Vector2.ZERO, deploy_time) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


func _hide_lines() -> void:
	for i in _pivots.size():
		_aims[i].visible = false
		_glows[i].visible = false
		_cores[i].visible = false


# --- Beams --------------------------------------------------------------------

## Casts beam i and returns where it ends (global): the first wall (StaticBody2D). Every
## other body is skipped, like the laser guns' beam. The ray starts at the ship's centre,
## not at the muzzle: pressed against a wall, the muzzle is already inside or past it, and
## a ray that starts inside a wall doesn't see it (the beam went through). If the wall is
## closer than the muzzle, the beam ends at the muzzle (blocked, no length).
func _cast(i: int) -> Vector2:
	var end: Vector2 = _cast_from_centre(i)
	var origin: Vector2 = _rays[i].global_position
	var muzzle: Vector2 = _muzzle(i)
	if origin.distance_squared_to(end) <= origin.distance_squared_to(muzzle):
		return muzzle
	return end


## Global position of cannon i's muzzle, where the beam is drawn from.
func _muzzle(i: int) -> Vector2:
	return _pivots[i].to_global(Vector2(0, -muzzle_distance))


func _cast_from_centre(i: int) -> Vector2:
	var ray: RayCast2D = _rays[i]
	ray.clear_exceptions()
	if get_parent() is CollisionObject2D:
		ray.add_exception(get_parent())
	ray.force_raycast_update()
	for _attempt in 12:
		if not ray.is_colliding() or ray.get_collider() is StaticBody2D:
			break
		ray.add_exception(ray.get_collider())
		ray.force_raycast_update()
	if ray.is_colliding():
		return ray.get_collision_point()
	return ray.to_global(ray.target_position)


func _set_line(i: int, line: Line2D, global_end: Vector2) -> void:
	line.points = PackedVector2Array([Vector2(0, -muzzle_distance), _pivots[i].to_local(global_end)])


## Destroys what beam (from -> to) crosses, scoring like a hit by the player's laser:
## asteroids 50, saws 200 (and the saws-destroyed stat), enemy ships 100. Active enemy
## lasers go back to their pool. Bosses take boss_damage once per volley. Laser guns,
## ally saws and powerups are left alone.
func _destroy_targets(from: Vector2, to: Vector2) -> void:
	var length: float = from.distance_to(to)
	if length <= 0.0:
		return
	_beam_shape.size = Vector2(length, hit_width)
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = _beam_shape
	query.transform = Transform2D((to - from).angle(), (from + to) * 0.5)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 32):
		var target: Object = hit.collider
		if not (target is Node):
			continue
		var node: Node = target as Node
		if node.is_in_group("laser_guns") or node.is_in_group("allies"):
			continue
		if node.is_in_group("asteroides") and node.has_method("explode"):
			if not node.get("_exploded"):
				GameManager.add_score(50)
				node.explode()
		elif node.is_in_group("saws") and node.has_method("die_and_respawn"):
			if not node.get("is_dying"):
				GameManager.add_score(200)
				AchievementManager.add_stat(&"saws_destroyed")
				node.die_and_respawn()
		elif node.is_in_group("enemigos") and node.has_method("die_and_respawn"):
			if not node.get("is_dying"):
				GameManager.add_score(100)
				node.die_and_respawn()
		elif node.is_in_group("enemy_laser") and node.get("is_active"):
			EnemyLaserPool.release(node)
		elif node.is_in_group("bosses") and node.has_method("take_damage"):
			if not _bosses_hit.has(node):
				_bosses_hit.append(node)
				node.take_damage(boss_damage)


# --- Building -----------------------------------------------------------------

## One cannon on a pivot turned `angle` from the nose: a small barrel pointing outwards
## (drawn under the ship, so only its end sticks out), its RayCast2D and its lines.
func _build_cannon(angle: float) -> void:
	var pivot: Node2D = Node2D.new()
	pivot.rotation = angle
	add_child(pivot)
	_pivots.append(pivot)

	var barrel_start: float = 4.0
	_add_rect(pivot, Rect2(-3.0, -muzzle_distance - 1.0, 6.0, muzzle_distance - barrel_start + 2.0),
			CANNON_EDGE)
	_add_rect(pivot, Rect2(-2.0, -muzzle_distance, 4.0, muzzle_distance - barrel_start), CANNON_FILL)
	_add_rect(pivot, Rect2(-2.0, -muzzle_distance, 4.0, 2.0), CANNON_TIP)

	# From the ship's centre (see _cast); hit_from_inside so a wall overlapping the origin
	# still stops it
	var ray: RayCast2D = RayCast2D.new()
	ray.enabled = false
	ray.hit_from_inside = true
	ray.target_position = Vector2(0, -beam_range)
	pivot.add_child(ray)
	_rays.append(ray)

	_aims.append(_add_line(pivot, AIM_COLOR, 1.5))
	_glows.append(_add_line(pivot, BEAM_GLOW, glow_width))
	_cores.append(_add_line(pivot, BEAM_CORE, core_width))


func _add_rect(parent: Node2D, rect: Rect2, color: Color) -> void:
	var polygon: Polygon2D = Polygon2D.new()
	polygon.polygon = PackedVector2Array([
		rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y),
	])
	polygon.color = color
	parent.add_child(polygon)


func _add_line(parent: Node2D, color: Color, width: float) -> Line2D:
	var line: Line2D = Line2D.new()
	line.default_color = color
	line.width = width
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	parent.add_child(line)
	return line
