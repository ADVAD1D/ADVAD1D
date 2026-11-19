class_name ScannerPowerup
extends Node2D
## Scanner powerup (Scenes/scanner.tscn), put on the player by its pickup
## (scanner_pickup.tscn, laser_shield_pickup.gd with active_group player_scanner), which
## ScannerSpawner drops by chance instead of on a timer.
##
## It gives `charges` uses of the Shoot key; player.gd doesn't fire its lasers while it's on.
## Pressing Shoot opens the scanner: the game goes into slow motion (slow_time_scale) and it
## locks onto the enemies within scan_radius of the ship one by one, every lock_interval,
## nearest first, up to max_targets, each with a bracket and a THREAT label
## (Scripts/UI/scanner_overlay.gd, in the HUD, in the arena's colour; it also draws the
## scan_radius ring around the ship while scanning). Releasing Shoot destroys every
## locked target at once, like a bomb, scoring like the player's lasers (mini GEMELAs too;
## the big GEMELA is never a target). Holding it longer than max_hold_time (real seconds)
## throws that use away. After the last use it frees itself.

enum State { ARMED, SCANNING, DONE }

## Groups it locks onto (lock order: distance only).
const TARGET_GROUPS: Array[StringName] = [&"bosses", &"laser_guns", &"saws", &"enemigos",
		&"asteroides"]
## Same points as the player's lasers / the quad laser.
const SAW_SCORE: int = 200
const SHIP_SCORE: int = 100
const ASTEROID_SCORE: int = 50
## Achievement stat: the most enemies one blast destroyed (Resources/Achievements/overload.tres).
const BLAST_STAT: StringName = &"scanner_best_blast"

## Uses (each press of Shoot) in the main mode. Arcade adds one per level bought of the
## shop upgrades whose upgrade_stat matches (Resources/Shop/scanner_uses.tres, 2 levels).
@export var charges: int = 1
@export var upgrade_stat: StringName = &"scanner_uses"
## Real seconds the scanner can stay open; past that the use is lost.
@export var max_hold_time: float = 1.0
## Engine.time_scale while scanning.
@export var slow_time_scale: float = 0.2
## Real seconds between two locks.
@export var lock_interval: float = 0.1
## Only targets this close to the ship (world units; the arenas' camera shows 4 world units
## per screen pixel, so 600 is about 150 screen pixels, half the screen's height).
@export var scan_radius: float = 600.0
@export var max_targets: int = 5
## Camera shake when it goes off (camera_2d.gd shake()).
@export var detonate_shake: float = 60.0

var state: State = State.ARMED
## Locked targets of the current scan: {node, name, number, radius (world), locked_msec}.
var targets: Array[Dictionary] = []
## Charges it started with (the overlay draws used and left ones).
var max_charges: int = 0
## Real time (msec) the current scan started.
var scan_start_msec: int = 0

var _next_lock_msec: int = 0
## After a lost use: the next scan needs Shoot released and pressed again.
var _wait_for_release: bool = false
var _paused_msec: int = -1
## Engine.time_scale before the scan (the time warp powerup may have it slowed already).
var _time_scale_before: float = 1.0
## The value this scan set, to notice when something else changes it.
var _applied_time_scale: float = 1.0
var _overlay: ScannerOverlay

@onready var scan_sound: AudioStreamPlayer = $ScanSound
@onready var lock_sound: AudioStreamPlayer = $LockSound
@onready var detonate_sound: AudioStreamPlayer = $DetonateSound
@onready var discard_sound: AudioStreamPlayer = $DiscardSound


func _ready() -> void:
	add_to_group("player_scanner")
	charges += ShopManager.get_upgrade_levels(upgrade_stat)
	max_charges = charges
	var scene: Node = get_tree().current_scene
	var hud: Node = scene.get_node_or_null("UILayer/HUD") if scene else null
	if hud:
		_overlay = ScannerOverlay.new()
		_overlay.scanner = self
		hud.add_child(_overlay)


func _process(_delta: float) -> void:
	if state == State.ARMED:
		# Held, not just pressed: picked up while firing (Shoot already down), the scan
		# starts right away with the same press. After a lost use Shoot is still down, so
		# that one waits for a release first (or it would throw away the next use too).
		if not Input.is_action_pressed("Shoot"):
			_wait_for_release = false
		elif not _wait_for_release and _can_scan():
			_start_scan()
		return
	if state != State.SCANNING:
		return
	if not _can_scan():
		# The player died mid-scan: the use isn't spent, time goes back to normal
		_restore_time_scale()
		targets.clear()
		state = State.ARMED
		return
	_keep_slow_motion()
	_prune_targets()
	var now: int = Time.get_ticks_msec()
	if not Input.is_action_pressed("Shoot"):
		_detonate()
	elif now - scan_start_msec >= int(max_hold_time * 1000.0):
		_discard()
	elif now >= _next_lock_msec:
		_next_lock_msec = now + int(lock_interval * 1000.0)
		_lock_next()


## A scene reload (death) or the arena changing mid-scan: time back to normal.
func _exit_tree() -> void:
	if state == State.SCANNING:
		_restore_time_scale()


## The pause menu runs at normal speed and doesn't eat into the scan's time.
func _notification(what: int) -> void:
	if state != State.SCANNING:
		return
	if what == NOTIFICATION_PAUSED:
		_paused_msec = Time.get_ticks_msec()
		_restore_time_scale()
	elif what == NOTIFICATION_UNPAUSED and _paused_msec >= 0:
		var gap: int = Time.get_ticks_msec() - _paused_msec
		scan_start_msec += gap
		_next_lock_msec += gap
		_paused_msec = -1
		_apply_slow_motion()


## Real seconds left before this scan is lost (for the overlay's bar).
func get_time_left() -> float:
	if state != State.SCANNING:
		return 0.0
	return maxf(max_hold_time - (Time.get_ticks_msec() - scan_start_msec) / 1000.0, 0.0)


func _can_scan() -> bool:
	var player: Node = get_parent()
	return player != null and not player.get("player_died") and not get_tree().paused


# --- Scan -------------------------------------------------------------------------------

func _start_scan() -> void:
	state = State.SCANNING
	targets.clear()
	scan_start_msec = Time.get_ticks_msec()
	_next_lock_msec = scan_start_msec + int(lock_interval * 1000.0)
	_time_scale_before = Engine.time_scale
	_apply_slow_motion()
	scan_sound.play()
	# The first lock right away, so a quick tap still hits the nearest threat
	_lock_next()


## Locks the next target: the nearest one to the ship that isn't locked yet, within
## scan_radius and on screen.
func _lock_next() -> void:
	if targets.size() >= max_targets:
		return
	var locked: Dictionary = {}
	for target in targets:
		locked[target.node] = true
	var view: Rect2 = _world_view()
	var origin: Vector2 = get_parent().global_position
	var best: Node2D = null
	var best_distance: float = scan_radius
	for group in TARGET_GROUPS:
		for node in get_tree().get_nodes_in_group(group):
			if not (node is Node2D) or locked.has(node) or not is_valid_target(node):
				continue
			var spot: Vector2 = (node as Node2D).global_position
			if not view.has_point(spot):
				continue
			# To its edge, not its centre: a big target (mini GEMELA) counts once it touches
			# the ring
			var distance: float = origin.distance_to(spot) - _target_radius(node)
			if distance <= best_distance:
				best_distance = distance
				best = node as Node2D
	if best == null:
		return
	targets.append({
		"node": best,
		"name": _target_name(best),
		"number": targets.size() + 1,
		"radius": _target_radius(best),
		"locked_msec": Time.get_ticks_msec(),
	})
	lock_sound.pitch_scale = 1.0 + 0.06 * (targets.size() - 1)
	lock_sound.play()


## Drops the targets that died meanwhile (another hit, a phase clear).
func _prune_targets() -> void:
	for i in range(targets.size() - 1, -1, -1):
		if not is_valid_target(targets[i].node):
			targets.remove_at(i)


## Shoot released: every locked target blows up at once.
func _detonate() -> void:
	_restore_time_scale()
	var hits: int = 0
	var enemy_hits: int = 0
	for target in targets:
		var node: Node = target.node
		if not is_valid_target(node):
			continue
		if _overlay:
			_overlay.add_burst((node as Node2D).global_position, target.radius)
		if not node.is_in_group("asteroides"):
			enemy_hits += 1
		_destroy(node)
		hits += 1
	# Most enemies (asteroids don't count) destroyed by one blast: OVERLOAD achievement
	if enemy_hits > 0:
		AchievementManager.raise_stat(BLAST_STAT, enemy_hits)
	if hits > 0:
		detonate_sound.play()
		var camera: Camera2D = get_viewport().get_camera_2d()
		if camera and camera.has_method("shake"):
			camera.shake(detonate_shake, 0.3)
		if _overlay:
			_overlay.flash()
	_use_charge()


## Held too long: the use is lost and the brackets flicker out.
func _discard() -> void:
	_restore_time_scale()
	if _overlay:
		_overlay.show_lost(targets.duplicate())
	discard_sound.play()
	_wait_for_release = true
	_use_charge()


func _use_charge() -> void:
	charges -= 1
	targets.clear()
	if charges > 0:
		state = State.ARMED
		return
	# Out of the group right away (the player shoots again, another pickup can be taken);
	# freed once its last sound ends
	state = State.DONE
	remove_from_group("player_scanner")
	set_process(false)
	for sound in [detonate_sound, discard_sound]:
		if sound.playing:
			await sound.finished
	queue_free()


## Destroys a locked target and scores it like the player's lasers would.
func _destroy(node: Node) -> void:
	if node.is_in_group("bosses"):
		GameManager.add_score(int(node.get("score_value")))
		node.die_and_respawn()
	elif node.is_in_group("laser_guns"):
		GameManager.add_score(int(node.get("score_value")))
		AchievementManager.add_stat(&"laser_guns_destroyed")
		node.die_and_respawn()
	elif node.is_in_group("saws"):
		GameManager.add_score(SAW_SCORE)
		AchievementManager.add_stat(&"saws_destroyed")
		node.die_and_respawn()
	elif node.is_in_group("asteroides"):
		GameManager.add_score(ASTEROID_SCORE)
		node.explode()
	elif node.has_method("die_and_respawn"):
		GameManager.add_score(SHIP_SCORE)
		node.die_and_respawn()


# --- Slow motion ------------------------------------------------------------------------

func _apply_slow_motion() -> void:
	Engine.time_scale = minf(_time_scale_before, slow_time_scale)
	_applied_time_scale = Engine.time_scale


## The time warp powerup starting or ending mid-scan changes Engine.time_scale: that becomes
## the value to go back to, and the scan's slow motion is put back on top.
func _keep_slow_motion() -> void:
	if not is_equal_approx(Engine.time_scale, _applied_time_scale):
		_time_scale_before = Engine.time_scale
		_apply_slow_motion()


func _restore_time_scale() -> void:
	Engine.time_scale = _time_scale_before


# --- Targets ----------------------------------------------------------------------------

## Alive, on screen and hittable: not dying, not an ally, not the big GEMELA, with its
## collision on (a laser gun still spawning or a ship blowing up has it off).
static func is_valid_target(node: Variant) -> bool:
	if not is_instance_valid(node) or not (node is Node2D):
		return false
	var item: Node2D = node as Node2D
	if not item.is_inside_tree() or item.is_queued_for_deletion() or not item.is_visible_in_tree():
		return false
	if item.get("is_dying") or item.get("_exploded") or item.is_in_group("allies"):
		return false
	if item.is_in_group("bosses"):
		return bool(item.get("is_mini")) and item.has_method("get_avoid_radius") \
				and item.get_avoid_radius() > 0.0
	var shape: CollisionShape2D = _shape_of(item)
	return shape == null or not shape.disabled


## The world rectangle the camera shows.
func _world_view() -> Rect2:
	var viewport: Viewport = get_viewport()
	return viewport.get_canvas_transform().affine_inverse() * viewport.get_visible_rect()


static func _shape_of(node: Node) -> CollisionShape2D:
	var shape: Variant = node.get("collision_shape")
	if shape is CollisionShape2D:
		return shape
	for child in node.get_children():
		if child is CollisionShape2D:
			return child
	return null


## Rough radius (world units) of a target, for the size of its bracket.
static func _target_radius(node: Node) -> float:
	if node.has_method("get_avoid_radius"):
		var avoid: float = node.get_avoid_radius()
		if avoid > 0.0:
			return avoid
	var collision: CollisionShape2D = _shape_of(node)
	if collision and collision.shape:
		var k: float = maxf(absf(collision.global_scale.x), absf(collision.global_scale.y))
		var shape: Shape2D = collision.shape
		if shape is CircleShape2D:
			return (shape as CircleShape2D).radius * k
		if shape is RectangleShape2D:
			var size: Vector2 = (shape as RectangleShape2D).size
			return maxf(size.x, size.y) * 0.5 * k
		if shape is CapsuleShape2D:
			var capsule: CapsuleShape2D = shape as CapsuleShape2D
			return maxf(capsule.radius, capsule.height * 0.5) * k
	return 100.0


static func _target_name(node: Node) -> String:
	if node.is_in_group("bosses"):
		var display: Variant = node.get("display_name")
		return str(display).to_upper() if display != null else "GEMELA"
	if node.is_in_group("laser_guns"):
		return "LASER GUN"
	if node.is_in_group("saws"):
		return "SAW"
	if node.is_in_group("asteroides"):
		return "ASTEROID"
	return "SHIP"
