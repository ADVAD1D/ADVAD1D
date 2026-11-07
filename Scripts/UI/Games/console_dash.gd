extends "res://Scripts/UI/Games/console_game.gd"
## dash: auto-runner. The cube runs by itself and the obstacles are random patterns of
## spikes and blocks. Jump with Shoot, Move_Up, Enter or a tap (holding keeps jumping);
## blocks can be landed on, but touching a spike or running into a block's side restarts
## the run. Speed grows with the distance. Endless: Esc or [x] leaves with the best run.

const TILE: float = 12.0
const GRAVITY: float = 1500.0
## Jump height ~51 px (4 tiles), ~0.52 s in the air.
const JUMP_SPEED: float = 390.0
const START_SPEED: float = 150.0
const MAX_SPEED: float = 230.0
const ACCELERATION: float = 2.5
## Screen x of the cube.
const PLAYER_X: float = 64.0
## Spin while in the air (radians per second); it snaps to a side on landing.
const SPIN_SPEED: float = 6.0
const DEATH_TIME: float = 0.8
## Seconds the "ATTEMPT n" label stays.
const ATTEMPT_LABEL_TIME: float = 1.5
## Where the first pattern starts, in pixels.
const FIRST_OBSTACLE: float = 300.0
## Obstacle patterns in tiles: [kind, x, level] for spikes ("s", 1x1), [kind, x, level,
## width, height] for blocks ("b"). Level 0 is on the ground.
const PATTERNS: Array = [
	[["s", 0, 0]],
	[["s", 0, 0], ["s", 1, 0]],
	[["s", 0, 0], ["s", 1, 0], ["s", 2, 0]],
	[["b", 0, 0, 2, 1], ["s", 4, 0]],
	[["b", 0, 0, 2, 1], ["b", 2, 0, 2, 2], ["b", 4, 0, 2, 3]],
	[["b", 0, 0, 4, 1], ["s", 4, 0], ["s", 5, 0]],
	[["b", 0, 0, 1, 1], ["s", 1, 0], ["s", 2, 0], ["b", 3, 0, 1, 1]],
]
const COLOR_CUBE: Color = Color("#0fb8d6")
const COLOR_BLOCK: Color = Color("#00262c")
const COLOR_GRID: Color = Color(0.06, 0.4, 0.45, 0.25)

## Obstacles: {"kind": "s"/"b", "rect": Rect2 in world pixels}.
var _objects: Array = []
## World x where the next pattern goes.
var _next_x: float = 0.0
## World pixels scrolled this run; the cube is at _scroll + PLAYER_X.
var _scroll: float = 0.0
var _speed: float = START_SPEED
var _ground: float = 0.0
## Top of the cube (screen y), vertical speed, spin.
var _y: float = 0.0
var _vy: float = 0.0
var _on_ground: bool = true
var _rot: float = 0.0
## Seconds left of the death explosion, -1 while running.
var _dead: float = -1.0
var _attempt: int = 1
var _best: int = 0
var _run_time: float = 0.0
## Death fragments: [position, velocity].
var _pieces: Array = []


func intro() -> Array:
	return [
		line("Generating level... done (it's random).", "#5f8f8f"), 0.3,
		line("Jump: Space / W / Up / tap. Hold to keep jumping."),
		line("Esc leaves.", "#5f8f8f"), 0.5,
	]


func start() -> void:
	_ground = size.y - 28.0
	_reset()


func summary() -> Array:
	return [line("DASH  best %d m, %d attempts" % [_best, _attempt])]


func _reset() -> void:
	_objects.clear()
	_scroll = 0.0
	_speed = START_SPEED
	_next_x = FIRST_OBSTACLE
	_y = _ground - TILE
	_vy = 0.0
	_on_ground = true
	_rot = 0.0
	_dead = -1.0
	_run_time = 0.0
	_spawn()


func _meters() -> int:
	return int(_scroll / TILE)


## Adds patterns until the screen (and a bit more) is filled.
func _spawn() -> void:
	while _next_x < _scroll + size.x + 40.0:
		var pattern: Array = PATTERNS.pick_random()
		var width: int = 0
		for part in pattern:
			var tile_x: int = part[1]
			var level: int = part[2]
			var w: int = part[3] if part.size() > 3 else 1
			var h: int = part[4] if part.size() > 4 else 1
			width = maxi(width, tile_x + w)
			var rect: Rect2 = Rect2(_next_x + tile_x * TILE, _ground - (level + h) * TILE,
					w * TILE, h * TILE)
			_objects.append({"kind": part[0], "rect": rect})
		# Gaps grow with the speed so the patterns stay jumpable
		_next_x += width * TILE + randf_range(7.0, 12.0) * TILE * (_speed / START_SPEED)


func tick(delta: float) -> void:
	for piece in _pieces:
		var velocity: Vector2 = piece[1]
		velocity.y += 300.0 * delta
		piece[1] = velocity
		piece[0] = (piece[0] as Vector2) + velocity * delta
	if _dead >= 0.0:
		_dead -= delta
		if _dead < 0.0:
			_pieces.clear()
			_attempt += 1
			_reset()
		return

	_run_time += delta
	_speed = minf(MAX_SPEED, _speed + ACCELERATION * delta)
	_scroll += _speed * delta
	_best = maxi(_best, _meters())
	_spawn()
	var behind: float = _scroll - 20.0
	_objects = _objects.filter(func(o: Dictionary) -> bool: return o["rect"].end.x > behind)

	var jump: bool = held(&"Shoot") or held(&"Move_Up") or held(&"Skip") or touching() or _tapped
	if _on_ground and jump:
		_vy = -JUMP_SPEED
		_on_ground = false
	var previous_bottom: float = _y + TILE
	_vy += GRAVITY * delta
	_y += _vy * delta
	_on_ground = false
	if _y + TILE >= _ground:
		_y = _ground - TILE
		_vy = 0.0
		_on_ground = true

	var player: Rect2 = Rect2(_scroll + PLAYER_X, _y, TILE, TILE)
	for o in _objects:
		var rect: Rect2 = o["rect"]
		if o["kind"] == "s":
			# Forgiving hitbox: the spike's lower middle only
			var spike: Rect2 = Rect2(rect.position + Vector2(3, 4), rect.size - Vector2(6, 4))
			if player.grow(-2.0).intersects(spike):
				_die()
				return
		elif player.intersects(rect):
			if _vy >= 0.0 and previous_bottom <= rect.position.y + 5.0:
				_y = rect.position.y - TILE
				_vy = 0.0
				_on_ground = true
				player.position.y = _y
			else:
				_die()
				return

	if _on_ground:
		_rot = snappedf(_rot, PI / 2.0)
	else:
		_rot += SPIN_SPEED * delta


func _die() -> void:
	_dead = DEATH_TIME
	var centre: Vector2 = Vector2(PLAYER_X + TILE / 2.0, _y + TILE / 2.0)
	for i in 10:
		_pieces.append([centre, Vector2.from_angle(randf() * TAU) * randf_range(40.0, 130.0)])


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG)
	# Background grid, slower than the ground (parallax)
	var x: float = -fposmod(_scroll * 0.3, 24.0)
	while x < size.x:
		draw_rect(Rect2(x, 16.0, 1.0, _ground - 16.0), COLOR_GRID)
		x += 24.0
	var grid_y: float = 40.0
	while grid_y < _ground:
		draw_rect(Rect2(0.0, grid_y, size.x, 1.0), COLOR_GRID)
		grid_y += 24.0
	# Ground
	draw_rect(Rect2(0.0, _ground, size.x, size.y - _ground), Color("#001a1f"))
	x = -fposmod(_scroll, 24.0)
	while x < size.x:
		draw_rect(Rect2(x, _ground + 1.0, 1.0, size.y - _ground), COLOR_GRID)
		x += 24.0
	draw_rect(Rect2(0.0, _ground, size.x, 1.0), COLOR_TEXT)

	for o in _objects:
		var rect: Rect2 = o["rect"]
		rect.position.x -= _scroll
		if rect.position.x > size.x:
			continue
		if o["kind"] == "b":
			draw_rect(rect, COLOR_BLOCK)
			draw_rect(rect.grow(-0.5), COLOR_CUBE, false, 1.0)
		else:
			var points: PackedVector2Array = PackedVector2Array([
				Vector2(rect.position.x, rect.end.y),
				Vector2(rect.get_center().x, rect.position.y),
				Vector2(rect.end.x, rect.end.y),
			])
			draw_colored_polygon(points, COLOR_BLOCK)
			points.append(points[0])
			draw_polyline(points, COLOR_RED, 1.0)

	if _dead < 0.0:
		var centre: Vector2 = Vector2(PLAYER_X + TILE / 2.0, _y + TILE / 2.0).round()
		draw_set_transform(centre, _rot)
		draw_rect(Rect2(-6, -6, 12, 12), COLOR_CUBE)
		draw_rect(Rect2(-5.5, -5.5, 11, 11), COLOR_TEXT, false, 1.0)
		draw_rect(Rect2(-2, -2, 4, 4), COLOR_BG)
		draw_set_transform(Vector2.ZERO)
	for piece in _pieces:
		draw_rect(Rect2((piece[0] as Vector2).floor(), Vector2(3, 3)), COLOR_CUBE)

	draw_text(Vector2(4, 12), "%d m" % _meters())
	draw_text(Vector2(56, 12), "BEST %d m" % _best, COLOR_DIM)
	if _run_time < ATTEMPT_LABEL_TIME:
		var fade: Color = COLOR_GOLD
		fade.a = 1.0 - _run_time / ATTEMPT_LABEL_TIME
		draw_centered(size.y * 0.4, "ATTEMPT %d" % _attempt, fade)
	draw_close()
