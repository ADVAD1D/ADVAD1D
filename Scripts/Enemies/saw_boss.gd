extends Area2D
## Arena 3 boss saw, GEMELA (Scenes/Enemies/gemela.tscn), and its small arcade version
## (is_mini, Scenes/Enemies/gemela_mini.tscn).
##
## GEMELA is drawn in layers that spin on their own (Body/Ring with the 6 laser vents,
## Body/Star the other way, Body/Head with the two cannons) and fights in a loop:
## - BURST: the vents fire small lasers outward while the ring spins, a spiral.
## - CHARGE + BEAM: the head turns its cannons at the player (blinking aim lines), then both
##   cannons fire a beam like the laser guns' (only walls stop it) and the head sweeps.
## Below phase_two_at of its health it goes faster and bursts during the beams too.
## A health bar (Scripts/UI/boss_health_bar.gd) goes into the HUD, so the arena tint
## colours it. Beating it emits `defeated` (PhaseManager wins the arena).
##
## The mini (arcade, MiniBossSpawner) chases the player like a saw, and every few seconds
## blinks and fires two rings of small lasers from its 3 vents. No beams, no health bar.
##
## Not in the "saws" group on purpose: the ally saw frees any "saws" area it touches and the
## shield / quad laser kill them outright. It hurts the player itself (their Hitbox entering
## it) and takes damage from player lasers and ally saws.

signal defeated
## Killed by the player (not by a board clear), for the spawner.
signal died(boss: Node)
signal health_changed(current: int, maximum: int)

enum State { ENTERING, IDLE, BURST, CHARGE, BEAM, DYING }

const BossHealthBar = preload("res://Scripts/UI/boss_health_bar.gd")
## Blocked hit (invulnerable): body tint and the spark ring where the shot landed.
const BLOCKED_TINT: Color = Color(0.6, 0.72, 0.9)
const BLOCKED_SPARK: Color = Color(0.75, 0.88, 1.0, 0.9)
## Sweep arrows (from the checkpoint on): distances from the centre along each aim line,
## how far beside the line they sit, and their colour.
const SWEEP_ARROW_DISTANCES: Array[float] = [450.0, 900.0, 1400.0]
const SWEEP_ARROW_OFFSET: float = 60.0
const SWEEP_ARROW_COLOR: Color = Color(1.0, 0.4, 0.46)
const EXPLOSION_SOUND: PackedScene = preload(
		"res://Assets/Audio/AudioScenes/ship_enemy_explosion.tscn")

@export var is_mini: bool = false
@export var display_name: String = "GEMELA"
@export var max_health: int = 150
@export var score_per_hit: int = 10
@export var score_value: int = 5000
## Damage an ally saw (powerup) does when it rams the boss (it breaks).
@export var ally_damage: int = 3
@export var show_health_bar: bool = true
@export var explosion_particles: PackedScene

@export_group("Movement")
@export var move_speed: float = 320.0
## GEMELA wanders around the point it spawned at, inside this ellipse (world units).
@export var wander_radius: Vector2 = Vector2(550.0, 380.0)
## How much each new wander point leans towards the player (0 = none, 1 = on the player).
@export var follow_player: float = 0.3
## Each new wander point is at least this far from where it is, so it never hovers in place
## (an easy target from afar).
@export var min_wander_step: float = 400.0
## Seconds before it picks a new wander point even if it hasn't got there (random x..y).
@export var wander_time: Vector2 = Vector2(1.5, 2.5)
## Speed kept while charging and firing the beams (fraction of move_speed).
@export_range(0.0, 1.0) var attack_move_factor: float = 0.65
## The mini chases the player instead, with this acceleration (like the saws).
@export var acceleration: float = 2.0

@export_group("Spin")
## Degrees per second (negative = counterclockwise).
@export var ring_spin: float = 70.0
@export var star_spin: float = -160.0

@export_group("Small lasers")
@export var vent_count: int = 6
## Vent radius in ring sprite pixels and the angle of the first one.
@export var vent_radius_px: float = 43.5
@export var vent_angle_offset: float = 0.0
@export var burst_time: float = 2.4
@export var burst_interval: float = 0.16
## Mini: volleys per attack.
@export var mini_volleys: int = 2

@export_group("Beams")
## Cannon tip in head sprite pixels (the cannons point up and down in the sprite).
@export var cannon_tip_px: float = 33.0
## Key points: each health fraction reached adds two more beams to every shot, spread
## evenly around the head with the cannons' pair (2 -> 4 -> 6 with the default). The extra
## ones come out of the edge of the head's disc (head_radius_px).
@export var extra_beams_at: Array[float] = [0.66, 0.33]
@export var head_radius_px: float = 20.0
@export var charge_time: float = 1.0
@export var beam_time: float = 1.8
## Degrees per second the head sweeps while firing.
@export var beam_sweep: float = 45.0
## Degrees per second the head turns to aim while charging. The aim is random, not at the
## player.
@export var head_turn_speed: float = 160.0
## Each new aim turns at least this many degrees from the last one.
@export var min_aim_turn: float = 30.0
@export var beam_width: float = 22.0
@export var beam_range: float = 5000.0

@export_group("Rhythm")
@export var attack_cooldown_min: float = 1.4
@export var attack_cooldown_max: float = 2.2
@export var enter_time: float = 1.2
## Health fraction where phase two starts (0 = never).
@export var phase_two_at: float = 0.5
## Phase two multiplies spin, movement and fire rate by this.
@export var phase_two_speed: float = 1.4
## Checkpoint (health fraction, 0 = none; GEMELA only): once its health drops this low, a
## player death brings it back with this much health instead of full
## (GameManager.boss_checkpoint_health survives the reload). Marked on the health bar.
@export var checkpoint_at: float = 0.5

var health: int = 0
var _state: State = State.ENTERING
var _timer: float = 0.0
var _shot_timer: float = 0.0
var _shots: int = 0
var _phase_two: bool = false
var _invulnerable: bool = true
var _last_attack: State = State.BEAM
var _sweep_dir: float = 1.0
## Head rotation the cannons turn to while charging (random each shot).
var _aim_rotation: float = 0.0
## Beams of the current shot (fixed when the charge starts, see _beam_count()).
var _beams: int = 2
## Extra beam pairs already unlocked, to flash when a key point is reached.
var _beam_level: int = 0
var _checkpoint_reached: bool = false
## Multiplies the ring's spin (the checkpoint animation spins it up for a moment).
var _spin_boost: float = 1.0
var _blocked_tween: Tween
var _beam_clock: float = 0.0
var _home: Vector2
var _wander_target: Vector2
var _wander_timer: float = 0.0
var _velocity: Vector2 = Vector2.ZERO
var _cooldown_scale: float = 1.0
var _player: Node2D
var _health_bar: BossHealthBar
var _beam_shape: RectangleShape2D = RectangleShape2D.new()
## Per cannon: [aim line (Line2D), glow (Polygon2D), core (Polygon2D)]
var _beam_lines: Array = []
## Per beam: its sweep arrows (Polygon2D), one per SWEEP_ARROW_DISTANCES.
var _sweep_arrows: Array = []

@onready var body: Node2D = $Body
@onready var ring: Node2D = $Body/Ring
@onready var star: Node2D = get_node_or_null("Body/Star")
@onready var head: AnimatedSprite2D = get_node_or_null("Body/Head")
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var charge_sound: AudioStreamPlayer2D = get_node_or_null("ChargeSound")
@onready var fire_sound: AudioStreamPlayer2D = get_node_or_null("FireSound")
@onready var shot_sound: AudioStreamPlayer2D = get_node_or_null("ShotSound")
## The phase-change sound (the arena's SucessSound, same settings), for the checkpoint.
@onready var checkpoint_sound: AudioStreamPlayer = get_node_or_null("CheckpointSound")


## Difficulty from the spawner (arcade): "cooldown_scale" < 1 attacks more often.
func setup(config: Dictionary) -> void:
	_cooldown_scale = config.get("cooldown_scale", 1.0)


func _ready() -> void:
	add_to_group("bosses")
	area_entered.connect(_on_area_entered)
	health = max_health
	_home = global_position
	_wander_target = _home
	_player = get_tree().get_first_node_in_group("player") as Node2D
	if head:
		_build_beam_lines()
		head.play(&"idle")
	_load_checkpoint()
	if show_health_bar and not is_mini:
		_build_health_bar()
	_enter()


func _uses_checkpoint() -> bool:
	return not is_mini and checkpoint_at > 0.0


## Back from a death past the checkpoint: starts with the checkpoint's health, already in
## the phase and with the beams that health has (no flashes, those were seen already).
func _load_checkpoint() -> void:
	if not _uses_checkpoint() or GameManager.boss_checkpoint_health <= 0:
		return
	health = mini(GameManager.boss_checkpoint_health, max_health)
	_checkpoint_reached = true
	_phase_two = phase_two_at > 0.0 and health <= max_health * phase_two_at
	for fraction in extra_beams_at:
		if health <= max_health * fraction:
			_beam_level += 1


# --- States -------------------------------------------------------------------------

## Grows in while spinning fast; it can't be hurt until it's done.
func _enter() -> void:
	_state = State.ENTERING
	_invulnerable = true
	body.scale = Vector2.ZERO
	var tween: Tween = create_tween()
	tween.tween_property(body, "scale", Vector2.ONE, enter_time) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		_invulnerable = false
		_start_idle(0.6))


func _start_idle(wait: float = -1.0) -> void:
	_state = State.IDLE
	_hide_beams()
	_set_charge_look(false)
	if wait < 0.0:
		wait = randf_range(attack_cooldown_min, attack_cooldown_max) * _cooldown_scale
		if _phase_two:
			wait /= phase_two_speed
	_timer = wait


func _start_next_attack() -> void:
	if is_mini or head == null:
		_start_charge()  # the mini blinks, then fires its volleys
	elif _last_attack == State.BEAM:
		_start_burst()
	else:
		_start_charge()


func _start_burst() -> void:
	_state = State.BURST
	_last_attack = State.BURST
	_timer = burst_time
	_shot_timer = 0.0
	_shots = 0


func _start_charge() -> void:
	_state = State.CHARGE
	_timer = charge_time
	_beam_clock = 0.0
	# Random aim, at least min_aim_turn away from the current one so every shot moves
	if head:
		var turn: float = deg_to_rad(randf_range(min_aim_turn, 180.0))
		_aim_rotation = head.rotation + turn * (1.0 if randf() < 0.5 else -1.0)
		_beams = _beam_count()
		# Picked now (not when firing) so the arrows can show it while charging
		_sweep_dir = 1.0 if randf() < 0.5 else -1.0
	_set_charge_look(true)
	if charge_sound:
		charge_sound.play()


func _start_beam() -> void:
	_state = State.BEAM
	_last_attack = State.BEAM
	_timer = beam_time
	_beam_clock = 0.0
	_shot_timer = 0.0
	if fire_sound:
		fire_sound.play()


## Mini: after its charge, fires mini_volleys rings of lasers.
func _start_mini_volleys() -> void:
	_state = State.BURST
	_timer = burst_interval * (mini_volleys + 1)
	_shot_timer = 0.0
	_shots = 0
	_set_charge_look(false)


func _physics_process(delta: float) -> void:
	if _state == State.DYING:
		return
	var speed_mult: float = phase_two_speed if _phase_two else 1.0
	_spin(delta * speed_mult)
	_move(delta, speed_mult)
	match _state:
		State.IDLE:
			_timer -= delta
			if _timer <= 0.0:
				_start_next_attack()
		State.BURST:
			_burst(delta, speed_mult)
		State.CHARGE:
			_charge(delta)
		State.BEAM:
			_beam(delta, speed_mult)


func _spin(delta: float) -> void:
	var spin: float = ring_spin * (4.0 if _state == State.ENTERING else _spin_boost)
	ring.rotation_degrees += spin * delta
	if star:
		star.rotation_degrees += star_spin * delta


func _move(delta: float, speed_mult: float) -> void:
	if not is_instance_valid(_player):
		return
	if is_mini:
		var target: Vector2 = global_position.direction_to(_player.global_position) * move_speed
		_velocity = _velocity.lerp(target, 1.0 - exp(-acceleration * delta))
		global_position += _velocity * delta
		return
	_wander_timer -= delta
	if _wander_timer <= 0.0 or global_position.distance_to(_wander_target) < 40.0:
		_pick_wander_target()
	var speed: float = move_speed * speed_mult
	if _state == State.BEAM or _state == State.CHARGE:
		speed *= attack_move_factor
	var wanted: Vector2 = global_position.direction_to(_wander_target) * speed
	_velocity = _velocity.lerp(wanted, 1.0 - exp(-2.5 * delta))
	global_position += _velocity * delta


## A random point in the wander ellipse, leaning towards the player, at least
## min_wander_step away (the farthest of a few tries if none is).
func _pick_wander_target() -> void:
	_wander_timer = randf_range(wander_time.x, wander_time.y)
	var best: Vector2 = _home
	var best_distance: float = -1.0
	for i in 6:
		var angle: float = randf() * TAU
		var spot: Vector2 = _home + Vector2(cos(angle) * wander_radius.x,
				sin(angle) * wander_radius.y) * sqrt(randf())
		spot = spot.lerp(_player.global_position, follow_player)
		# Keep it inside the ellipse
		var offset: Vector2 = (spot - _home) / wander_radius
		if offset.length() > 1.0:
			spot = _home + offset.normalized() * wander_radius
		var distance: float = global_position.distance_to(spot)
		if distance > best_distance:
			best = spot
			best_distance = distance
		if distance >= min_wander_step:
			break
	_wander_target = best


func _burst(delta: float, speed_mult: float) -> void:
	_timer -= delta
	_shot_timer -= delta
	if _shot_timer <= 0.0:
		_shot_timer = burst_interval / speed_mult
		# Every other volley shifts half a vent (always for the mini, phase two for GEMELA),
		# so the pattern is denser
		var stagger: float = 0.5 if (_phase_two or is_mini) and _shots % 2 == 1 else 0.0
		_fire_vents(stagger)
		_shots += 1
	if _timer <= 0.0 or (is_mini and _shots >= mini_volleys):
		_start_idle()


func _charge(delta: float) -> void:
	_timer -= delta
	_beam_clock += delta
	var urgency: float = 1.0 - clampf(_timer / charge_time, 0.0, 1.0)
	var blink: float = absf(sin(_beam_clock * (8.0 + 30.0 * urgency)))
	if is_mini or head == null:
		ring.modulate = Color.WHITE.lerp(Color(2.5, 2.5, 2.5), blink)
		if _timer <= 0.0:
			ring.modulate = Color.WHITE
			_start_mini_volleys()
		return
	# Turn the cannons to this shot's random angle (not at the player: the aim lines show
	# where the beams will go, and the player has to get out of the way)
	head.rotation = rotate_toward(head.rotation, _aim_rotation, deg_to_rad(head_turn_speed) * delta)
	for i in _beams:
		var line: Line2D = _beam_lines[i][0]
		line.visible = true
		line.modulate.a = 0.35 + 0.45 * blink
		var dir: Vector2 = _cannon_dir(i)
		var end: Vector2 = _cast(global_position, dir)
		_set_line(line, _muzzle(i), end)
		_update_sweep_arrows(i, dir, end, blink)
	if _timer <= 0.0:
		for i in _beams:
			_beam_lines[i][0].visible = false
		_hide_sweep_arrows()
		_start_beam()


func _beam(delta: float, speed_mult: float) -> void:
	_timer -= delta
	_beam_clock += delta
	head.rotation += deg_to_rad(beam_sweep * speed_mult) * _sweep_dir * delta
	var flicker: float = 1.0 + 0.15 * sin(_beam_clock * 60.0)
	for i in _beams:
		var dir: Vector2 = _cannon_dir(i)
		var from: Vector2 = _muzzle(i)
		var end: Vector2 = _cast(global_position, dir)
		var glow: Polygon2D = _beam_lines[i][1]
		var core: Polygon2D = _beam_lines[i][2]
		# Pressed against a wall: the cannon is past it, no beam on that side
		if (end - global_position).dot(dir) <= (from - global_position).dot(dir):
			glow.visible = false
			core.visible = false
			continue
		end = _hit_player(from, end, dir)
		_destroy_targets(from, end, dir)
		glow.visible = true
		core.visible = true
		var reach: float = (end - global_position).dot(dir)
		_set_beam(glow, from, dir, reach, beam_width * 3.0 * flicker)
		_set_beam(core, from, dir, reach, beam_width * flicker)
	# Phase two also fires the vents while the beams sweep
	if _phase_two:
		_shot_timer -= delta
		if _shot_timer <= 0.0:
			_shot_timer = burst_interval * 2.0
			_fire_vents(0.0)
	if _timer <= 0.0:
		_start_idle()


# --- Small lasers -------------------------------------------------------------------

## One laser from every vent, straight out from the centre. `stagger` shifts the vents
## by that fraction of the gap between two of them.
func _fire_vents(stagger: float) -> void:
	var step: float = TAU / float(vent_count)
	var radius: float = vent_radius_px * ring.global_scale.x
	for i in vent_count:
		var angle: float = ring.global_rotation + vent_angle_offset + (i + stagger) * step
		var dir: Vector2 = Vector2.RIGHT.rotated(angle)
		EnemyLaserPool.acquire(get_parent(), global_position + dir * radius, dir, global_position)
	if shot_sound:
		shot_sound.play()


# --- Beams ----------------------------------------------------------------------------

## Beams per shot right now: the cannons' pair plus two for every key point reached.
func _beam_count() -> int:
	var count: int = 2
	for fraction in extra_beams_at:
		if health <= max_health * fraction:
			count += 2
	return mini(count, _beam_lines.size())


## Angle of beam `index` in the head's own space: evenly spread, starting with the cannon
## that points up (with 2 beams: up and down, the two cannons).
func _beam_angle(index: int) -> float:
	return index * TAU / float(_beams)


func _cannon_dir(index: int) -> Vector2:
	return Vector2.UP.rotated(head.global_rotation + _beam_angle(index))


## The cannons' beams start at their tips, the extra ones at the edge of the head's disc.
func _muzzle(index: int) -> Vector2:
	var angle: float = _beam_angle(index)
	var on_cannon: bool = is_zero_approx(fposmod(angle + 0.001, PI) - 0.001)
	var distance: float = cannon_tip_px if on_cannon else head_radius_px
	return head.to_global(Vector2.UP.rotated(angle) * distance)


## Where a beam from `from` along `dir` ends: the first wall (StaticBody2D). It goes
## through every other body (the player's body included: their Hitbox is tested apart).
func _cast(from: Vector2, dir: Vector2) -> Vector2:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var to: Vector2 = from + dir * beam_range
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to, 1)
	query.collide_with_areas = false
	var exclude: Array[RID] = []
	for i in 12:
		query.exclude = exclude
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			return to
		if hit.collider is StaticBody2D:
			return hit.position
		exclude.append(hit.rid)
	return to


## Kills the player when the beam (from -> to) overlaps their Hitbox shape. A disabled
## hitbox (dash) is never hit. Unlike the laser guns' beam, the laser shield does NOT block
## it: the player dies and the shield breaks with them (player.die()). Returns where the
## beam ends (it doesn't stop at the player).
func _hit_player(from: Vector2, to: Vector2, dir: Vector2) -> Vector2:
	if not is_instance_valid(_player):
		return to
	var hitbox: CollisionShape2D = _player.get_node_or_null("Hitbox/CollisionShape2D")
	if hitbox == null or hitbox.disabled or hitbox.shape == null:
		return to
	_beam_shape.size = Vector2(from.distance_to(to), beam_width)
	var beam_xform: Transform2D = Transform2D(dir.angle(), (from + to) * 0.5)
	if not hitbox.shape.collide(hitbox.global_transform, _beam_shape, beam_xform):
		return to
	if _player.has_method("die"):
		_player.die()
	return to


## What a beam (from -> to) breaks besides the player: asteroids and the player's ally saws
## (powerup1.gd), like the laser guns' beam. The ally saw's die() has no guard of its own
## and the beam touches it every frame, so only while it isn't dying already.
func _destroy_targets(from: Vector2, to: Vector2, dir: Vector2) -> void:
	_beam_shape.size = Vector2(from.distance_to(to), beam_width)
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = _beam_shape
	query.transform = Transform2D(dir.angle(), (from + to) * 0.5)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.exclude = [get_rid()]
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 16):
		var target: Object = hit.collider
		if not target is Node:
			continue
		if target.is_in_group("asteroides") and target.has_method("explode"):
			target.explode()
		elif target.is_in_group("allies") and target.has_method("die") \
				and not target.get("is_dying"):
			target.die()



func _build_beam_lines() -> void:
	for i in 2 + 2 * extra_beams_at.size():
		var aim: Line2D = _make_line(4.0, Color(1.0, 0.25, 0.32, 0.9))
		var glow: Polygon2D = _make_beam(Color(1.0, 0.12, 0.22, 0.4))
		var core: Polygon2D = _make_beam(Color(1.0, 0.86, 0.88, 1.0))
		_beam_lines.append([aim, glow, core])
		var arrows: Array[Polygon2D] = []
		for _k in SWEEP_ARROW_DISTANCES.size():
			arrows.append(_make_arrow())
		_sweep_arrows.append(arrows)


## Chevron pointing right (+x), turned to the sweep direction when shown.
func _make_arrow() -> Polygon2D:
	var arrow: Polygon2D = Polygon2D.new()
	arrow.polygon = PackedVector2Array([Vector2(-16, -26), Vector2(-2, -26), Vector2(20, 0),
			Vector2(-2, 26), Vector2(-16, 26), Vector2(6, 0)])
	arrow.color = SWEEP_ARROW_COLOR
	arrow.z_index = -1
	arrow.visible = false
	add_child(arrow)
	return arrow


## From the checkpoint on, while the cannons aim, chevrons along beam i's aim line point
## the way the beams will sweep, beside the line (only the ones before the wall).
func _update_sweep_arrows(index: int, dir: Vector2, end: Vector2, blink: float) -> void:
	var reach: float = global_position.distance_to(end)
	var tangent: Vector2 = dir.rotated(PI / 2.0) * _sweep_dir
	var arrows: Array = _sweep_arrows[index]
	for k in arrows.size():
		var arrow: Polygon2D = arrows[k]
		var distance: float = SWEEP_ARROW_DISTANCES[k]
		arrow.visible = _checkpoint_reached and distance < reach - SWEEP_ARROW_OFFSET
		if not arrow.visible:
			continue
		arrow.position = to_local(global_position + dir * distance + tangent * SWEEP_ARROW_OFFSET)
		arrow.rotation = tangent.angle()
		arrow.modulate.a = 0.45 + 0.55 * blink


func _hide_sweep_arrows() -> void:
	for arrows in _sweep_arrows:
		for arrow in arrows:
			arrow.visible = false


func _make_line(width: float, color: Color) -> Line2D:
	var line: Line2D = Line2D.new()
	line.width = width
	line.default_color = color
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.z_index = -1  # under the boss
	line.visible = false
	add_child(line)
	return line


func _set_line(line: Line2D, from: Vector2, to: Vector2) -> void:
	line.points = PackedVector2Array([to_local(from), to_local(to)])


## A fired beam's glow or core: a quad redrawn by _set_beam.
func _make_beam(color: Color) -> Polygon2D:
	var beam: Polygon2D = Polygon2D.new()
	beam.color = color
	beam.z_index = -1  # under the boss
	beam.visible = false
	add_child(beam)
	return beam


## Draws a beam `width` wide from the muzzle `from` along `dir` as a quad whose two long
## edges each end where their own ray meets a wall. A thick line only stops its centre
## there: sweeping past a slanted wall, its outer edge (and its round cap) went through it.
## `reach` is the centre's distance to the wall from the boss's centre, along `dir`.
func _set_beam(beam: Polygon2D, from: Vector2, dir: Vector2, reach: float, width: float) -> void:
	var side: Vector2 = dir.orthogonal() * (width * 0.5)
	var start: float = (from - global_position).dot(dir)
	var ends: Array[Vector2] = []
	for offset: Vector2 in [-side, side]:
		var origin: Vector2 = global_position + offset
		var edge_reach: float = (_cast(origin, dir) - origin).dot(dir)
		# An edge that slips past a corner (or misses every wall) isn't drawn further than
		# a little past the centre's hit: shorter is fine, poking out isn't
		edge_reach = clampf(edge_reach, start, reach + width * 4.0)
		ends.append(origin + dir * edge_reach)
	beam.polygon = PackedVector2Array([to_local(from - side), to_local(ends[0]),
			to_local(ends[1]), to_local(from + side)])


func _hide_beams() -> void:
	for lines in _beam_lines:
		for line in lines:
			line.visible = false
	_hide_sweep_arrows()


## The head's charge frame (white-hot eyes and muzzles) / the mini's.
func _set_charge_look(on: bool) -> void:
	if head:
		head.play(&"charge" if on else &"idle")
	elif ring is AnimatedSprite2D:
		(ring as AnimatedSprite2D).play(&"charge" if on else &"idle")


# --- Damage ---------------------------------------------------------------------------

func _on_area_entered(area: Area2D) -> void:
	if _state == State.DYING:
		return
	# The player's Hitbox: contact kills, like a saw (a dash disables it)
	if area.name == "Hitbox" and area.get_parent() == _player:
		if _player.has_method("die"):
			_player.die()
		return
	if area.is_in_group("lasers"):
		# Enemy lasers deflected by the shield belong to EnemyLaserPool
		if area.has_method("deactivate"):
			EnemyLaserPool.release(area)
		else:
			area.queue_free()
		take_damage(1, area.global_position)
	elif area.is_in_group("allies") and area.has_method("die") and not area.get("is_dying"):
		area.die()
		take_damage(ally_damage, area.global_position)


## `hit_position` (global) is where the blocked-hit spark goes; without it (the quad laser's
## beams) only the tint shows.
func take_damage(amount: int, hit_position: Vector2 = Vector2.INF) -> void:
	if _state == State.DYING:
		return
	if _invulnerable:
		_show_blocked(hit_position)
		return
	health = maxi(health - amount, 0)
	GameManager.add_score(score_per_hit * amount)
	health_changed.emit(health, max_health)
	_flash()
	if _uses_checkpoint() and not _checkpoint_reached and health > 0 \
			and health <= max_health * checkpoint_at:
		_reach_checkpoint()
	if health <= 0:
		GameManager.add_score(score_value)
		_die(true)
	elif not _phase_two and phase_two_at > 0.0 and health <= max_health * phase_two_at:
		_enter_phase_two()
	elif head and _beam_count() > 2 + 2 * _beam_level:
		# A key point: from the next shot on it fires two more beams
		_beam_level += 1
		body.modulate = Color(4.0, 1.2, 1.2)
		var tween: Tween = create_tween()
		tween.tween_property(body, "modulate", Color.WHITE, 0.5)


func _enter_phase_two() -> void:
	_phase_two = true
	# A short breather with a big flash, so the change reads
	_invulnerable = true
	body.modulate = Color(4.0, 1.2, 1.2)
	var tween: Tween = create_tween()
	tween.tween_property(body, "modulate", Color.WHITE, 0.6)
	tween.tween_callback(func(): _invulnerable = false)


## Saves the checkpoint and plays its animation: the saw swells and springs back, the ring
## spins up and winds down, and a red ring wave rolls out from it.
func _reach_checkpoint() -> void:
	_checkpoint_reached = true
	GameManager.boss_checkpoint_health = roundi(max_health * checkpoint_at)
	if _health_bar:
		_health_bar.reach_mark()
	if checkpoint_sound:
		checkpoint_sound.play()
	var pulse: Tween = create_tween()
	pulse.tween_property(body, "scale", Vector2(1.2, 1.2), 0.12) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	pulse.tween_property(body, "scale", Vector2.ONE, 0.45) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_spin_boost = 7.0
	create_tween().tween_property(self, "_spin_boost", 1.0, 1.4) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_shockwave()


func _shockwave() -> void:
	var wave: Line2D = Line2D.new()
	wave.width = 26.0
	wave.default_color = Color(1.0, 0.2, 0.3)
	wave.closed = true
	wave.z_index = -1
	add_child(wave)
	var start: float = vent_radius_px * ring.global_scale.x
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_method(func(radius: float): wave.points = _circle(radius), start,
			start * 4.5, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(wave, "modulate:a", 0.0, 0.7)
	tween.tween_property(wave, "width", 6.0, 0.7)
	tween.chain().tween_callback(wave.queue_free)


func _circle(radius: float, segments: int = 48) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i in segments:
		points.append(Vector2.RIGHT.rotated(i * TAU / float(segments)) * radius)
	return points


## A hit that does nothing (it's entering, or changing phase): a short cool grey-blue tint
## instead of the white damage flash, and a small spark ring where the shot landed, so the
## player can tell the hit was blocked and not missed.
func _show_blocked(hit_position: Vector2) -> void:
	if _blocked_tween:
		_blocked_tween.kill()
	# Over the phase-change red flash only once it has faded a bit
	if body.modulate.r < 2.0:
		body.modulate = BLOCKED_TINT
		_blocked_tween = create_tween()
		_blocked_tween.tween_property(body, "modulate", Color.WHITE, 0.18)
	if hit_position == Vector2.INF:
		return
	var spark: Line2D = Line2D.new()
	spark.width = 7.0
	spark.default_color = BLOCKED_SPARK
	spark.closed = true
	spark.position = to_local(hit_position)
	add_child(spark)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_method(func(radius: float): spark.points = _circle(radius, 12), 10.0, 42.0,
			0.22).set_ease(Tween.EASE_OUT)
	tween.tween_property(spark, "width", 1.0, 0.22)
	tween.tween_property(spark, "modulate:a", 0.0, 0.22)
	tween.chain().tween_callback(spark.queue_free)


func _flash() -> void:
	body.modulate = Color(3.0, 3.0, 3.0)
	var tween: Tween = create_tween()
	tween.tween_property(body, "modulate", Color.WHITE, 0.12)


## Radius (world units) enemy ships and saws keep clear of, plus their own boss_margin, so
## they don't fly under the boss. 0 while it dies (they can pass over the explosion).
func get_avoid_radius() -> float:
	if _state == State.DYING:
		return 0.0
	var circle: CircleShape2D = collision_shape.shape as CircleShape2D
	if circle == null:
		return 0.0
	return circle.radius * absf(collision_shape.global_scale.x)


## Contract of the "enemies" group: PhaseManager's board clear (arcade phase change).
func die_silently() -> void:
	_die(false)


func die_and_respawn() -> void:
	_die(true)


func _die(killed: bool) -> void:
	if _state == State.DYING:
		return
	_state = State.DYING
	_hide_beams()
	if charge_sound:
		charge_sound.stop()
	if fire_sound:
		fire_sound.stop()
	collision_shape.set_deferred("disabled", true)
	health_changed.emit(0, max_health)
	if is_mini:
		await _explode_at(global_position)
	else:
		await _death_sequence()
	if killed:
		died.emit(self)
		if not is_mini:
			GameManager.boss_checkpoint_health = -1
			defeated.emit()
	queue_free()


## GEMELA's death: blasts all over it while it shakes and spins down, then a last flash.
func _death_sequence() -> void:
	var radius: float = vent_radius_px * ring.global_scale.x
	for i in 8:
		var spot: Vector2 = global_position + Vector2.RIGHT.rotated(randf() * TAU) \
				* randf_range(0.0, radius)
		_explode_at(spot)
		body.position = Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))
		body.modulate = Color(3.0, 1.5, 1.5) if i % 2 == 0 else Color.WHITE
		await get_tree().create_timer(0.16, false).timeout
	body.position = Vector2.ZERO
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(body, "scale", Vector2(1.3, 1.3), 0.35)
	tween.tween_property(body, "modulate", Color(4.0, 4.0, 4.0, 0.0), 0.35)
	_explode_at(global_position)
	await tween.finished


func _explode_at(spot: Vector2) -> void:
	if explosion_particles:
		var particles: Node2D = explosion_particles.instantiate()
		get_parent().add_child(particles)
		particles.global_position = spot
	var sound: AudioStreamPlayer2D = EXPLOSION_SOUND.instantiate()
	get_tree().current_scene.add_child(sound)
	sound.global_position = spot
	sound.play()
	if is_mini:
		hide()
		await sound.finished


# --- Health bar -------------------------------------------------------------------------

func _build_health_bar() -> void:
	var hud: Node = get_tree().current_scene.get_node_or_null("UILayer/HUD")
	if hud == null:
		return
	_health_bar = BossHealthBar.new()
	_health_bar.boss_name = display_name
	_health_bar.phase_mark = checkpoint_at if _uses_checkpoint() else phase_two_at
	hud.add_child(_health_bar)
	_health_bar.set_health(health, max_health, false)
	if _checkpoint_reached:
		_health_bar.reach_mark()
	health_changed.connect(_health_bar.set_health)
