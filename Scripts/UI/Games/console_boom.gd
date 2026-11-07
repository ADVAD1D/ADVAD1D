extends "res://Scripts/UI/Games/console_game.gd"
## boom: first person shooter drawn with a raycaster, because everything has to be able
## to run one. One map (MAP) with sentry robots; destroy them all to clear the area.
##
## Rendering: one ray per 2 px column (DDA over the grid) gives each wall slice its
## height and depth (_zbuf); robots are billboards drawn column by column, only where
## they're closer than the wall. Shots are hitscan through the screen centre.
## Keys: Move_Up / Move_Down walk, Move_Left / Move_Right turn, Shoot fires.
## Phones: hold the left or right quarter of the screen to turn, the middle to walk
## forward and fire.

## "#" and "X" are walls (two colours), "P" the start (facing east), "E" a robot.
const MAP: Array = [
	"################",
	"#P...#.........#",
	"#....#...E.....#",
	"#....#..XXX....#",
	"#.........X..E.#",
	"#....#....X....#",
	"##.###.........#",
	"#....######.####",
	"#.E..#.........#",
	"#....#..E......#",
	"#.........XX..E#",
	"#..E.#...XX....#",
	"#....#.........#",
	"################",
]
## Camera plane length: about 66 degrees of field of view.
const FOV_PLANE: float = 0.66
const COLUMN_WIDTH: float = 2.0
const HUD_HEIGHT: float = 18.0
const MOVE_SPEED: float = 2.6
const TURN_SPEED: float = 2.4
const PLAYER_RADIUS: float = 0.25
const FIRE_COOLDOWN: float = 0.35
const MAX_HP: int = 100
const ENEMY_HP: int = 2
const ENEMY_SPEED: float = 1.1
## Robots stop this close to the player.
const ENEMY_REACH: float = 1.4
const SIGHT_RANGE: float = 9.0
const END_TIME: float = 2.5
const WALL_COLORS: Dictionary = {"#": Color("#0fb8d6"), "X": Color("#ff2fb0")}
## Sentry robot, 12x14.
const ENEMY_SPRITE: Array = [
	".....yy.....",
	"......#.....",
	"...######...",
	"..########..",
	".###rrrr###.",
	".##rRRRRr##.",
	".###rrrr###.",
	"..########..",
	"...######...",
	"..#.#..#.#..",
	".#..#..#..#.",
	".#..#..#..#.",
	"#...#..#...#",
	"............",
]
const ENEMY_PALETTE: Dictionary = {
	"#": Color("#6f8f96"), "r": Color("#b3122b"), "R": Color("#ff4b4b"), "y": Color("#ffd36b"),
}


var _pos: Vector2 = Vector2.ZERO
var _dir: Vector2 = Vector2.RIGHT
var _plane: Vector2 = Vector2(0.0, FOV_PLANE)
var _hp: int = MAX_HP
var _robots: Array = []
var _kills: int = 0
var _time: float = 0.0
var _fire_cooldown: float = 0.0
var _muzzle: float = 0.0
var _hurt: float = 0.0
var _bob: float = 0.0
## Seconds left of the end screen, -1 while playing.
var _end: float = -1.0
var _enemy_texture: ImageTexture
## Per column: wall depth, and [top, height, colour] of its slice.
var _zbuf: PackedFloat32Array = PackedFloat32Array()
var _columns: Array = []


func intro() -> Array:
	return [
		line("Can it run boom? Yes. Everything runs boom.", "#5f8f8f"), 0.4,
		line("Loading BOOM.WAD... 6 robots, 0 demons.", "#5f8f8f"), 0.3,
		line("Walk: W S / arrows. Turn: A D. Fire: F / Space."),
		line("Destroy every robot. Esc leaves.", "#5f8f8f"), 0.5,
	]


func start() -> void:
	_enemy_texture = make_sprite(ENEMY_SPRITE, ENEMY_PALETTE)
	for y in MAP.size():
		var row: String = MAP[y]
		for x in row.length():
			if row[x] == "P":
				_pos = Vector2(x + 0.5, y + 0.5)
			elif row[x] == "E":
				var robot: Robot = Robot.new()
				robot.pos = Vector2(x + 0.5, y + 0.5)
				robot.hp = ENEMY_HP
				robot.cooldown = randf_range(0.8, 1.6)
				_robots.append(robot)
	_cast()


func summary() -> Array:
	if _kills == _robots.size():
		return [line("BOOM  area clear in %.1fs, %d HP left" % [_time, _hp])]
	return [line("BOOM  %d/%d robots destroyed" % [_kills, _robots.size()])]


func tick(delta: float) -> void:
	_muzzle = maxf(0.0, _muzzle - delta)
	_hurt = maxf(0.0, _hurt - delta)
	if _end >= 0.0:
		_end -= delta
		if _end < 0.0:
			end(summary())
		return
	_time += delta
	var fire: bool = _move(delta)
	_cast()
	_fire_cooldown -= delta
	if fire and _fire_cooldown <= 0.0:
		_fire_cooldown = FIRE_COOLDOWN
		_muzzle = 0.08
		_shoot()
	_update_robots(delta)
	if _hp <= 0 or _kills == _robots.size():
		_hp = maxi(_hp, 0)
		_end = END_TIME


## Walks and turns; returns whether the player is firing.
func _move(delta: float) -> bool:
	var forward: float = 0.0
	var turn: float = 0.0
	if held(&"Move_Up"):
		forward += 1.0
	if held(&"Move_Down"):
		forward -= 1.0
	if held(&"Move_Left"):
		turn -= 1.0
	if held(&"Move_Right"):
		turn += 1.0
	var fire: bool = held(&"Shoot")
	for touch in _touches.values():
		var at: Vector2 = touch
		if at.x < size.x * 0.25:
			turn = -1.0
		elif at.x > size.x * 0.75:
			turn = 1.0
		else:
			forward = 1.0
			fire = true
	if turn != 0.0:
		_dir = _dir.rotated(turn * TURN_SPEED * delta)
		_plane = _plane.rotated(turn * TURN_SPEED * delta)
	if forward != 0.0:
		_pos = _slide(_pos, _dir * forward * MOVE_SPEED * delta, PLAYER_RADIUS)
		_bob += delta
	return fire


## Moves by step one axis at a time, so walls are slid along instead of sticking.
func _slide(from: Vector2, step: Vector2, radius: float) -> Vector2:
	var to: Vector2 = from
	if _is_free(Vector2(to.x + step.x, to.y), radius):
		to.x += step.x
	if _is_free(Vector2(to.x, to.y + step.y), radius):
		to.y += step.y
	return to


func _is_free(point: Vector2, radius: float) -> bool:
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var probe: Vector2 = point + corner * radius
		if _is_wall(_cell(floori(probe.x), floori(probe.y))):
			return false
	return true


func _cell(x: int, y: int) -> String:
	if y < 0 or y >= MAP.size() or x < 0 or x >= (MAP[y] as String).length():
		return "#"
	return (MAP[y] as String)[x]


func _is_wall(cell: String) -> bool:
	return WALL_COLORS.has(cell)


func _view_height() -> float:
	return size.y - HUD_HEIGHT


## One DDA ray per column: fills _zbuf and _columns.
func _cast() -> void:
	var count: int = int(size.x / COLUMN_WIDTH)
	var view_h: float = _view_height()
	_zbuf.resize(count)
	_columns.resize(count)
	for column in count:
		var camera_x: float = 2.0 * column / count - 1.0
		var ray: Vector2 = _dir + _plane * camera_x
		var map_x: int = floori(_pos.x)
		var map_y: int = floori(_pos.y)
		var delta_x: float = absf(1.0 / ray.x) if ray.x != 0.0 else 1e30
		var delta_y: float = absf(1.0 / ray.y) if ray.y != 0.0 else 1e30
		var step_x: int = -1 if ray.x < 0.0 else 1
		var step_y: int = -1 if ray.y < 0.0 else 1
		# Distance along the ray to the first x / y grid line
		var side_x: float = (_pos.x - map_x if ray.x < 0.0 else map_x + 1.0 - _pos.x) * delta_x
		var side_y: float = (_pos.y - map_y if ray.y < 0.0 else map_y + 1.0 - _pos.y) * delta_y
		var side: int = 0
		var cell: String = "#"
		for i in 64:
			if side_x < side_y:
				side_x += delta_x
				map_x += step_x
				side = 0
			else:
				side_y += delta_y
				map_y += step_y
				side = 1
			cell = _cell(map_x, map_y)
			if _is_wall(cell):
				break
		var dist: float = maxf(side_x - delta_x if side == 0 else side_y - delta_y, 0.05)
		# Where the ray hit along the wall (0-1), for the panel seams
		var wall_x: float = _pos.y + dist * ray.y if side == 0 else _pos.x + dist * ray.x
		wall_x -= floorf(wall_x)
		var color: Color = WALL_COLORS.get(cell, WALL_COLORS["#"])
		if side == 1:
			color = color.darkened(0.3)
		if fposmod(wall_x * 4.0, 1.0) < 0.1:
			color = color.darkened(0.45)
		color = color.darkened(clampf(dist / 10.0, 0.0, 0.85))
		var height: float = view_h / dist
		_zbuf[column] = dist
		_columns[column] = [view_h / 2.0 - height / 2.0, height, color]


## A world point on screen: x = screen column, y = depth, z = wall height at that depth.
## Depth <= 0 means behind the camera.
func _project(point: Vector2) -> Vector3:
	var rel: Vector2 = point - _pos
	var inv_det: float = 1.0 / (_plane.x * _dir.y - _dir.x * _plane.y)
	var tx: float = inv_det * (_dir.y * rel.x - _dir.x * rel.y)
	var ty: float = inv_det * (-_plane.y * rel.x + _plane.x * rel.y)
	if ty <= 0.05:
		return Vector3(0.0, -1.0, 0.0)
	return Vector3(size.x / 2.0 * (1.0 + tx / ty), ty, _view_height() / ty)


## Hitscan through the screen centre: the nearest robot in front of the wall there.
func _shoot() -> void:
	var centre: int = _zbuf.size() >> 1
	var target: Robot = null
	var nearest: float = _zbuf[centre]
	for robot: Robot in _robots:
		if robot.dead:
			continue
		var proj: Vector3 = _project(robot.pos)
		if proj.y <= 0.0 or proj.y >= nearest:
			continue
		var half_width: float = proj.z * 0.7 * (12.0 / 14.0) * 0.35
		if absf(proj.x - size.x / 2.0) < half_width:
			target = robot
			nearest = proj.y
	if target == null:
		return
	target.hp -= 1
	target.hurt = 0.15
	target.awake = true
	if target.hp <= 0:
		target.dead = true
		_kills += 1


func _update_robots(delta: float) -> void:
	for robot: Robot in _robots:
		robot.flash = maxf(0.0, robot.flash - delta)
		robot.hurt = maxf(0.0, robot.hurt - delta)
		if robot.dead:
			continue
		var to_player: Vector2 = _pos - robot.pos
		var dist: float = to_player.length()
		var sees: bool = dist < SIGHT_RANGE and _line_of_sight(robot.pos, _pos)
		if sees:
			robot.awake = true
		if robot.awake and dist > ENEMY_REACH:
			robot.pos = _slide(robot.pos, to_player / dist * ENEMY_SPEED * delta, 0.3)
		robot.cooldown -= delta
		if sees and robot.cooldown <= 0.0:
			robot.cooldown = randf_range(1.3, 2.2)
			robot.flash = 0.15
			# Worse aim from far away
			if randf() < 0.6 - dist * 0.04:
				_hp -= randi_range(6, 12)
				_hurt = 0.3


func _line_of_sight(from: Vector2, to: Vector2) -> bool:
	var steps: int = int(from.distance_to(to) / 0.1)
	for i in steps:
		var point: Vector2 = from.lerp(to, float(i) / steps)
		if _is_wall(_cell(floori(point.x), floori(point.y))):
			return false
	return true


func _draw() -> void:
	var view_h: float = _view_height()
	var half: float = view_h / 2.0
	# Ceiling and floor in bands, darker towards the horizon
	for i in 6:
		var t: float = i / 6.0
		draw_rect(Rect2(0.0, half * t, size.x, half / 6.0 + 1.0),
				Color("#00141a").lerp(Color("#000507"), t))
		draw_rect(Rect2(0.0, half + half * t, size.x, half / 6.0 + 1.0),
				Color("#001a17").lerp(Color("#00352d"), t))
	# Walls
	for column in _columns.size():
		var slice: Array = _columns[column]
		var x: float = column * COLUMN_WIDTH
		var top: float = slice[0]
		var height: float = slice[1]
		var color: Color = slice[2]
		draw_rect(Rect2(x, top, COLUMN_WIDTH, height), color)
		# Light strip near the top of the wall
		var strip: Rect2 = Rect2(x, top + height * 0.18, COLUMN_WIDTH, maxf(1.0, height * 0.04))
		draw_rect(strip, color.lightened(0.25))
	_draw_robots(view_h)

	# Crosshair and gun
	var centre: Vector2 = Vector2(roundf(size.x / 2.0), roundf(half))
	draw_rect(Rect2(centre + Vector2(-3, 0), Vector2(2, 1)), COLOR_TEXT)
	draw_rect(Rect2(centre + Vector2(2, 0), Vector2(2, 1)), COLOR_TEXT)
	draw_rect(Rect2(centre + Vector2(0, -3), Vector2(1, 2)), COLOR_TEXT)
	draw_rect(Rect2(centre + Vector2(0, 2), Vector2(1, 2)), COLOR_TEXT)
	var bob: float = roundf(absf(sin(_bob * 9.0)) * 3.0)
	var gun: Vector2 = Vector2(centre.x, view_h + bob)
	if _muzzle > 0.0:
		var tip: Vector2 = gun + Vector2(0, -32)
		draw_colored_polygon(PackedVector2Array([tip + Vector2(0, -8), tip + Vector2(7, 0),
				tip + Vector2(0, 6), tip + Vector2(-7, 0)]), COLOR_GOLD)
		draw_rect(Rect2(tip - Vector2(2, 2), Vector2(4, 4)), Color.WHITE)
	draw_rect(Rect2(gun + Vector2(-3, -29), Vector2(6, 13)), Color("#6f8f96"))
	draw_rect(Rect2(gun + Vector2(-2, -30), Vector2(4, 2)), Color("#0fb8d6"))
	draw_rect(Rect2(gun + Vector2(-10, -18), Vector2(20, 18)), Color("#2a3a40"))
	draw_rect(Rect2(gun + Vector2(-10, -18), Vector2(20, 2)), Color("#4a6670"))
	draw_rect(Rect2(gun + Vector2(-10, -11), Vector2(20, 2)), Color("#0fb8d6"))

	if _hurt > 0.0:
		draw_rect(Rect2(0.0, 0.0, size.x, view_h), Color(1.0, 0.1, 0.1, _hurt))
	# HUD
	draw_rect(Rect2(0.0, view_h, size.x, HUD_HEIGHT), Color("#00161a"))
	draw_rect(Rect2(0.0, view_h, size.x, 1.0), COLOR_DIM)
	var hp_color: Color = COLOR_RED if _hp < 30 else COLOR_TEXT
	draw_text(Vector2(4, view_h + 14.0), "HP %d" % _hp, hp_color)
	draw_rect(Rect2(44.0, view_h + 6.0, 50.0, 6.0), Color("#002a30"))
	draw_rect(Rect2(44.0, view_h + 6.0, 50.0 * _hp / float(MAX_HP), 6.0), hp_color)
	draw_text(Vector2(size.x - 92.0, view_h + 14.0), "ROBOTS %d/%d" % [_kills, _robots.size()])
	if _end >= 0.0:
		if _hp <= 0:
			draw_rect(Rect2(0.0, 0.0, size.x, view_h), Color(0.5, 0.0, 0.0, 0.45))
			draw_centered(half, "YOU DIED", COLOR_RED)
		else:
			draw_centered(half - 10.0, "AREA CLEAR", COLOR_GOLD)
	draw_close()


## Robots as billboards, farthest first, one column slice at a time where they're in
## front of the wall. Destroyed ones stay as a flat wreck.
func _draw_robots(view_h: float) -> void:
	var in_view: Array = []
	for robot: Robot in _robots:
		var proj: Vector3 = _project(robot.pos)
		if proj.y > 0.0:
			in_view.append([proj, robot])
	in_view.sort_custom(func(a: Array, b: Array) -> bool: return a[0].y > b[0].y)
	for entry in in_view:
		var proj: Vector3 = entry[0]
		var robot: Robot = entry[1]
		var height: float = proj.z * 0.7
		var width: float = height * 12.0 / 14.0
		var left: float = proj.x - width / 2.0
		var bottom: float = view_h / 2.0 + proj.z / 2.0
		var drawn_height: float = height * (0.3 if robot.dead else 1.0)
		var top: float = bottom - drawn_height
		var tint: Color = Color.WHITE.darkened(clampf(proj.y / 10.0, 0.0, 0.8))
		if robot.dead:
			tint = tint.darkened(0.5)
		elif robot.hurt > 0.0:
			tint = Color(1.0, 0.55, 0.55)
		var first: int = maxi(0, floori(left / COLUMN_WIDTH))
		var last: int = mini(_zbuf.size() - 1, floori((left + width) / COLUMN_WIDTH))
		for column in range(first, last + 1):
			if proj.y >= _zbuf[column]:
				continue
			var x: float = column * COLUMN_WIDTH
			var u0: float = clampf((x - left) / width, 0.0, 1.0)
			var u1: float = clampf((x + COLUMN_WIDTH - left) / width, 0.0, 1.0)
			if u1 <= u0:
				continue
			draw_texture_rect_region(_enemy_texture, Rect2(x, top, COLUMN_WIDTH, drawn_height),
					Rect2(u0 * 12.0, 0.0, (u1 - u0) * 12.0, 14.0), tint)
		if robot.flash > 0.0 and not robot.dead:
			var flash_column: int = clampi(floori(proj.x / COLUMN_WIDTH), 0, _zbuf.size() - 1)
			if proj.y < _zbuf[flash_column]:
				var size_px: float = maxf(2.0, width * 0.2)
				draw_rect(Rect2(proj.x - size_px / 2.0, top + height * 0.5, size_px, size_px), COLOR_GOLD)


class Robot:
	var pos: Vector2
	var hp: int
	var cooldown: float = 1.0
	## Seconds left of the muzzle flash and of the hit flash.
	var flash: float = 0.0
	var hurt: float = 0.0
	var awake: bool = false
	var dead: bool = false
