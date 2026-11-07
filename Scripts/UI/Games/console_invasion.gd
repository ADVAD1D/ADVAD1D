extends "res://Scripts/UI/Games/console_game.gd"
## invasion: fixed shooter. Rows of the simulator's drones (ships, saws, rocks) march
## sideways and step down at the edges, faster as they thin out; clearing them brings the
## next, lower wave. One shot on screen at a time, and it can cancel a falling bomb.
## Keys: Move_Left / Move_Right, Shoot. Phones: hold left or right of the ship to move,
## it fires by itself while touched.

const COLS: int = 8
const ROWS: int = 4
const CELL: Vector2 = Vector2(26, 16)
const ALIEN_SIZE: Vector2 = Vector2(11, 8)
## Top of the first wave (below the HUD line); later waves start a bit lower.
const TOP: float = 22.0
const STEP_DOWN: float = 6.0
const PLAYER_SPEED: float = 120.0
const SHOT_SPEED: float = 260.0
const BOMB_SPEED: float = 90.0
const MAX_BOMBS: int = 3
const LIVES: int = 3
const INVULNERABLE_TIME: float = 1.5
const BANNER_TIME: float = 1.2
const OVER_TIME: float = 2.0
const BURST_TIME: float = 0.3

## Drone kind and points by row, top to bottom.
const ROW_KIND: Array = [0, 1, 1, 2]
const ROW_POINTS: Array = [30, 20, 20, 10]
const KIND_COLORS: Array = [Color("#ff6b6b"), Color("#ffd36b"), Color("#8db4ae")]
## Two frames per kind: enemy ship, saw, rock.
const SPRITES: Array = [
	[
		[
			"#.........#",
			"##.......##",
			".###...###.",
			".#########.",
			"..##.#.##..",
			"...#####...",
			"....###....",
			".....#.....",
		],
		[
			"...........",
			"#.........#",
			"##.......##",
			".#########.",
			"..##.#.##..",
			"...#####...",
			"....###....",
			".....#.....",
		],
	],
	[
		[
			"...#.#.#...",
			"..#######..",
			".##.....##.",
			"###..#..###",
			"###..#..###",
			".##.....##.",
			"..#######..",
			"...#.#.#...",
		],
		[
			"..#.#.#.#..",
			"..#######..",
			"###.....###",
			".#...#...#.",
			".#...#...#.",
			"###.....###",
			"..#######..",
			"..#.#.#.#..",
		],
	],
	[
		[
			"...####....",
			"..######...",
			".###.####..",
			".#########.",
			".####.####.",
			"..#######..",
			"...##.##...",
			"...........",
		],
		[
			"....####...",
			"...######..",
			"..####.###.",
			".#########.",
			".####.####.",
			"..#######..",
			"...##.##...",
			"...........",
		],
	],
]
const PLAYER_SPRITE: Array = [
	"......o......",
	".....ooo.....",
	".....o#o.....",
	"....o###o....",
	"..o#######o..",
	".o#########o.",
	"oo.oo...oo.oo",
]

var _alien_textures: Array = []
var _player_texture: ImageTexture
## One flag per drone, row by row.
var _alive: Array = []
var _origin: Vector2 = Vector2.ZERO
var _dir: float = 1.0
var _anim: float = 0.0
var _player_x: float = 0.0
var _shot: Vector2 = Vector2.ZERO
var _shot_active: bool = false
var _bombs: Array = []
var _bomb_timer: float = 1.0
var _score: int = 0
var _lives: int = LIVES
var _wave: int = 1
var _invulnerable: float = 0.0
## Seconds left of the "WAVE n" pause, and of the game over screen (-1 while playing).
var _banner: float = BANNER_TIME
var _over: float = -1.0
## Explosions: [centre, age].
var _bursts: Array = []


func intro() -> Array:
	return [
		line("Loading invasion.rom...", "#5f8f8f"), 0.3,
		line("Hostile formation incoming."),
		line("Move: arrows / A D. Fire: F / Space. Esc leaves.", "#5f8f8f"), 0.5,
	]


func start() -> void:
	var white: Dictionary = {"#": Color.WHITE}
	for frames in SPRITES:
		_alien_textures.append([make_sprite(frames[0], white), make_sprite(frames[1], white)])
	_player_texture = make_sprite(PLAYER_SPRITE, {"#": Color("#0fb8d6"), "o": COLOR_TEXT})
	_player_x = size.x / 2.0
	_new_wave()


func summary() -> Array:
	return [line("INVASION  score %d, wave %d" % [_score, _wave])]


func tick(delta: float) -> void:
	_anim += delta
	for burst in _bursts:
		burst[1] += delta
	_bursts = _bursts.filter(func(burst: Array) -> bool: return burst[1] < BURST_TIME)
	if _over >= 0.0:
		_over -= delta
		if _over < 0.0:
			end(summary())
		return
	_invulnerable = maxf(0.0, _invulnerable - delta)
	_move_player(delta)
	if _banner > 0.0:
		_banner -= delta
		return
	_move_formation(delta)
	_move_shot(delta)
	_move_bombs(delta)


func _new_wave() -> void:
	_alive.clear()
	for i in COLS * ROWS:
		_alive.append(true)
	var width: float = (COLS - 1) * CELL.x + ALIEN_SIZE.x
	_origin = Vector2(floorf((size.x - width) / 2.0), TOP + minf(_wave - 1, 4) * 4.0)
	_dir = 1.0
	_bombs.clear()
	_shot_active = false
	_banner = BANNER_TIME


func _player_y() -> float:
	return size.y - 11.0


func _row_of(index: int) -> int:
	return floori(index / float(COLS))


func _alien_rect(index: int) -> Rect2:
	var col: int = index % COLS
	return Rect2(_origin + Vector2(col * CELL.x, _row_of(index) * CELL.y), ALIEN_SIZE)


func _move_player(delta: float) -> void:
	var axis: float = 0.0
	if held(&"Move_Left"):
		axis -= 1.0
	if held(&"Move_Right"):
		axis += 1.0
	var fire: bool = held(&"Shoot")
	if touching():
		var target: Vector2 = first_touch()
		if target.x < _player_x - 4.0:
			axis = -1.0
		elif target.x > _player_x + 4.0:
			axis = 1.0
		fire = true
	_player_x = clampf(_player_x + axis * PLAYER_SPEED * delta, 8.0, size.x - 8.0)
	if fire and not _shot_active and _banner <= 0.0:
		_shot = Vector2(roundf(_player_x), _player_y() - 2.0)
		_shot_active = true


func _move_formation(delta: float) -> void:
	var alive: int = _alive.count(true)
	if alive == 0:
		_wave += 1
		_new_wave()
		return
	# Faster as the formation thins out and with every wave
	var speed: float = 10.0 + 3.0 * _wave + 70.0 * (1.0 - alive / float(COLS * ROWS))
	_origin.x += _dir * speed * delta
	var left: float = INF
	var right: float = -INF
	var bottom: float = -INF
	for i in _alive.size():
		if _alive[i]:
			var rect: Rect2 = _alien_rect(i)
			left = minf(left, rect.position.x)
			right = maxf(right, rect.end.x)
			bottom = maxf(bottom, rect.end.y)
	if (_dir > 0.0 and right > size.x - 4.0) or (_dir < 0.0 and left < 4.0):
		_origin.x -= _dir * speed * delta
		_dir = -_dir
		_origin.y += STEP_DOWN
	if bottom >= _player_y() - 1.0:
		_lives = 0
		_game_over()
		return
	_bomb_timer -= delta
	if _bomb_timer <= 0.0:
		_bomb_timer = maxf(0.35, 1.2 - 0.1 * _wave) * randf_range(0.6, 1.4)
		_drop_bomb()


## A bomb from the lowest drone of a random column.
func _drop_bomb() -> void:
	if _bombs.size() >= MAX_BOMBS:
		return
	var shooters: Array = []
	for col in COLS:
		for row in range(ROWS - 1, -1, -1):
			if _alive[row * COLS + col]:
				shooters.append(row * COLS + col)
				break
	if shooters.is_empty():
		return
	var rect: Rect2 = _alien_rect(shooters.pick_random())
	_bombs.append(Vector2(roundf(rect.get_center().x), rect.end.y))


func _move_shot(delta: float) -> void:
	if not _shot_active:
		return
	_shot.y -= SHOT_SPEED * delta
	if _shot.y < 14.0:
		_shot_active = false
		return
	var shot_rect: Rect2 = Rect2(_shot.x - 0.5, _shot.y, 1.0, 4.0)
	for i in _alive.size():
		if _alive[i] and _alien_rect(i).intersects(shot_rect):
			_alive[i] = false
			_score += ROW_POINTS[_row_of(i)]
			_bursts.append([_alien_rect(i).get_center(), 0.0])
			_shot_active = false
			return
	for i in _bombs.size():
		var bomb: Vector2 = _bombs[i]
		if Rect2(bomb.x - 1.0, bomb.y, 2.0, 4.0).intersects(shot_rect):
			_bursts.append([bomb, 0.0])
			_bombs.remove_at(i)
			_shot_active = false
			return


func _move_bombs(delta: float) -> void:
	var player_rect: Rect2 = Rect2(_player_x - 6.0, _player_y(), 13.0, 7.0)
	for i in range(_bombs.size() - 1, -1, -1):
		var bomb: Vector2 = _bombs[i]
		bomb.y += BOMB_SPEED * delta
		_bombs[i] = bomb
		if bomb.y > size.y:
			_bombs.remove_at(i)
		elif _invulnerable <= 0.0 and player_rect.intersects(Rect2(bomb.x - 1.0, bomb.y, 2.0, 4.0)):
			_hit_player()
			return


func _hit_player() -> void:
	_lives -= 1
	_bursts.append([Vector2(_player_x, _player_y() + 3.0), 0.0])
	_bombs.clear()
	_invulnerable = INVULNERABLE_TIME
	if _lives <= 0:
		_game_over()


func _game_over() -> void:
	if _over < 0.0:
		_over = OVER_TIME


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG)
	var frame: int = int(_anim / 0.4) % 2
	for i in _alive.size():
		if _alive[i]:
			var kind: int = ROW_KIND[_row_of(i)]
			draw_texture(_alien_textures[kind][frame], _alien_rect(i).position.floor(), KIND_COLORS[kind])
	var blink: bool = _invulnerable > 0.0 and int(_invulnerable * 10.0) % 2 == 1
	if _lives > 0 and not blink:
		draw_texture(_player_texture, Vector2(roundf(_player_x) - 6.0, _player_y()))
	if _shot_active:
		draw_rect(Rect2(_shot.floor(), Vector2(1, 4)), COLOR_TEXT)
	for bomb in _bombs:
		var pos: Vector2 = (bomb as Vector2).floor()
		draw_rect(Rect2(pos + Vector2(-1, 0), Vector2(1, 2)), COLOR_RED)
		draw_rect(Rect2(pos + Vector2(0, 2), Vector2(1, 2)), COLOR_RED)
	for burst in _bursts:
		var centre: Vector2 = burst[0]
		var reach: float = 2.0 + burst[1] * 30.0
		for angle in 8:
			var spark: Vector2 = centre + Vector2.from_angle(angle * TAU / 8.0) * reach
			draw_rect(Rect2(spark.floor(), Vector2(2, 2)), COLOR_GOLD)
	draw_rect(Rect2(0, size.y - 3.0, size.x, 1.0), COLOR_DIM)

	# HUD
	draw_text(Vector2(4, 12), "SCORE %04d" % _score)
	draw_centered(12, "WAVE %d" % _wave, COLOR_DIM)
	for life in maxi(_lives, 0):
		draw_texture(_player_texture, Vector2(size.x - CLOSE_SIZE - 20.0 - life * 16.0, 5.0))
	if _over >= 0.0:
		draw_centered(size.y / 2.0, "GAME OVER", COLOR_RED)
	elif _banner > 0.0:
		draw_centered(size.y * 0.62, "WAVE %d" % _wave, COLOR_GOLD)
	draw_close()
