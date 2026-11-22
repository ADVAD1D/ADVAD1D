class_name ScannerOverlay
extends Control
## What the scanner powerup (Scripts/Powerups/scanner.gd) shows, built in code and added to the HUD:
## while scanning, a bracket around each locked target with a line to a THREAT label (number
## and kind), corner marks on the screen, a sweeping scan line and a bar with the time left;
## when it goes off, a flash and an expanding bracket on each target; when a use is lost, the
## brackets flicker out. Pips under the ship show the uses left. Texts aren't translated (the
## simulator's readout, like the console). Frees itself once the scanner is gone and its last
## effects end.
##
## It's drawn straight in the arena's colour (cyan, green, red: the HUD's hue,
## GameManager.get_arena_ui_hue_shift(), applied to cyan, with a touch of white so it's
## brighter than the arena's own colour) and keeps out of ArenaTint (it has its own
## material): the tint's hue rotation keeps brightness but not saturation, so the thin cyan
## lines came out pale pink, almost white, in arena 3. Every bright stroke (STROKE thick) sits
## on a dark edge with a soft halo outside it (neon look), and texts use the HUD labels' style
## (dark fill, bright outline) plus a halo, so it stands out over the arena and the CRT.

const FONT: FontFile = preload("res://Assets/Fonts/Kenney Pixel.ttf")
const FONT_SIZE: int = 16
## Hue of the HUD's own colour (cyan) before the arena's shift.
const BASE_HUE: float = 0.5
## Real milliseconds of each animation.
const LOCK_IN_MSEC: float = 140.0
const BURST_MSEC: float = 380.0
const FLASH_MSEC: float = 220.0
const LOST_MSEC: float = 320.0
const SWEEP_MSEC: float = 700.0
## Opacity of the halo around strokes and text.
const GLOW_ALPHA: float = 0.35
## Thickness of the target brackets and the screen corners.
const STROKE: float = 3.0

var scanner: ScannerPowerup

## The arena's colour, a lighter version of it and a very dark one (fills and edges).
var _line: Color
var _light: Color
var _back: Color
## Soft halo around every bright stroke, outside its dark edge (a neon look).
var _glow: Color
## Explosions of the last detonation: {pos (world), radius (world), msec}.
var _bursts: Array[Dictionary] = []
## Targets of the last lost scan, flickering out.
var _lost: Array = []
var _lost_msec: int = -1
var _flash_msec: int = -1


func _init() -> void:
	# Set before entering the tree: ArenaTint tints new HUD nodes on node_added, but leaves
	# alone the ones that already have a material
	material = CanvasItemMaterial.new()
	var hue: float = wrapf(BASE_HUE + GameManager.get_arena_ui_hue_shift() / 360.0, 0.0, 1.0)
	# A touch of white in the main colour lifts its brightness over the arena's own colour
	# (a pure red can't get any brighter on screen) while it still reads as the arena's hue
	_line = Color.from_hsv(hue, 0.72, 1.0)
	_light = Color.from_hsv(hue, 0.3, 1.0)
	_back = Color.from_hsv(hue, 1.0, 0.08, 0.92)
	_glow = Color(_line, GLOW_ALPHA)


func _ready() -> void:
	# The HUD processes while paused; the scanner's effects stop with the game
	process_mode = Node.PROCESS_MODE_PAUSABLE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func add_burst(world_position: Vector2, world_radius: float) -> void:
	_bursts.append({"pos": world_position, "radius": world_radius,
			"msec": Time.get_ticks_msec()})


func flash() -> void:
	_flash_msec = Time.get_ticks_msec()


func show_lost(lost_targets: Array) -> void:
	_lost = lost_targets
	_lost_msec = Time.get_ticks_msec()


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	for i in range(_bursts.size() - 1, -1, -1):
		if now - int(_bursts[i].msec) > BURST_MSEC:
			_bursts.remove_at(i)
	if not is_instance_valid(scanner) and _bursts.is_empty() \
			and (_flash_msec < 0 or now - _flash_msec > FLASH_MSEC) \
			and (_lost_msec < 0 or now - _lost_msec > LOST_MSEC):
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var now: int = Time.get_ticks_msec()
	var canvas: Transform2D = get_viewport().get_canvas_transform()
	# World -> this control's local space
	var to_local_xf: Transform2D = get_global_transform().affine_inverse() * canvas
	var zoom: float = canvas.get_scale().x

	if _flash_msec >= 0 and now - _flash_msec < FLASH_MSEC:
		var fade: float = 1.0 - (now - _flash_msec) / FLASH_MSEC
		draw_rect(Rect2(Vector2.ZERO, size), Color(_line, 0.35 * fade))

	var alive: bool = is_instance_valid(scanner)
	if alive and scanner.state == ScannerPowerup.State.SCANNING:
		_draw_scan_frame(now)
		_draw_range((to_local_xf * (scanner.get_parent() as Node2D).global_position).round(),
				scanner.scan_radius * zoom, now)
		for target in scanner.targets:
			if ScannerPowerup.is_valid_target(target.node):
				_draw_target(target, to_local_xf * (target.node as Node2D).global_position,
						zoom, now, 1.0)

	if _lost_msec >= 0 and now - _lost_msec < LOST_MSEC \
			and int((now - _lost_msec) / 50.0) % 2 == 0:
		for target in _lost:
			if ScannerPowerup.is_valid_target(target.node):
				_draw_target(target, to_local_xf * (target.node as Node2D).global_position,
						zoom, now, 0.45)

	for burst in _bursts:
		var k: float = clampf((now - int(burst.msec)) / BURST_MSEC, 0.0, 1.0)
		var center: Vector2 = (to_local_xf * (burst.pos as Vector2)).round()
		var half: float = (maxf(float(burst.radius) * zoom, 6.0) + 3.0) * (1.0 + 1.6 * k)
		_draw_brackets(center, half, maxf(half * 0.45, 5.0), Color(_light, 1.0 - k), STROKE)
		if k < 0.35:
			var core: float = half * 0.6 * (1.0 - k / 0.35)
			draw_rect(Rect2(center - Vector2.ONE * core, Vector2.ONE * core * 2.0),
					Color(_light, 0.7 * (1.0 - k / 0.35)))

	if alive and scanner.state != ScannerPowerup.State.DONE:
		_draw_charges(to_local_xf * (scanner.get_parent() as Node2D).global_position)


## Corner marks on the screen, a scan line sweeping down and the time-left bar.
func _draw_scan_frame(now: int) -> void:
	var inset: float = 8.0
	var arm: float = 16.0
	var left: float = inset
	var right: float = size.x - inset
	var top: float = inset
	var bottom: float = size.y - inset
	# The screen isn't square, so its corners are drawn here and not with _draw_brackets
	_bar(Rect2(left, top, arm, STROKE), _line)
	_bar(Rect2(left, top, STROKE, arm), _line)
	_bar(Rect2(right - arm, top, arm, STROKE), _line)
	_bar(Rect2(right - STROKE, top, STROKE, arm), _line)
	_bar(Rect2(left, bottom - STROKE, arm, STROKE), _line)
	_bar(Rect2(left, bottom - arm, STROKE, arm), _line)
	_bar(Rect2(right - arm, bottom - STROKE, arm, STROKE), _line)
	_bar(Rect2(right - STROKE, bottom - arm, STROKE, arm), _line)

	var sweep_y: float = roundf(fmod((now - scanner.scan_start_msec) / SWEEP_MSEC, 1.0) * size.y)
	draw_rect(Rect2(0.0, sweep_y - 1.0, size.x, 3.0), Color(_glow, _glow.a * 0.6))
	draw_rect(Rect2(0.0, sweep_y, size.x, 1.0), Color(_light, 0.6))

	# Time left before the use is lost
	var center_x: float = size.x / 2.0
	var bar_size: Vector2 = Vector2(80.0, 3.0)
	var bar_pos: Vector2 = Vector2(roundf(center_x - bar_size.x / 2.0), 66.0)
	var text: String = "SCANNING"
	var text_w: float = FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	_text(Vector2(roundf(center_x - text_w / 2.0), bar_pos.y - 4.0), text, 1.0)
	draw_rect(Rect2(bar_pos - Vector2.ONE * 4.0, bar_size + Vector2.ONE * 8.0), _glow)
	draw_rect(Rect2(bar_pos - Vector2.ONE * 2.0, bar_size + Vector2.ONE * 4.0), _back)
	_outline(Rect2(bar_pos - Vector2.ONE, bar_size + Vector2.ONE * 2.0), _line)
	var ratio: float = scanner.get_time_left() / maxf(scanner.max_hold_time, 0.01)
	draw_rect(Rect2(bar_pos, Vector2(floorf(bar_size.x * ratio), bar_size.y)), _light)


## The scanner's reach around the ship: a dashed ring that opens out when the scan starts
## and slowly turns.
func _draw_range(center: Vector2, radius: float, now: int) -> void:
	var k: float = clampf((now - scanner.scan_start_msec) / LOCK_IN_MSEC, 0.0, 1.0)
	var r: float = radius * (1.0 - pow(1.0 - k, 3.0))
	if r < 2.0:
		return
	var dashes: int = 36
	var step: float = TAU / dashes
	var spin: float = (now - scanner.scan_start_msec) / 1000.0 * 0.4
	for i in dashes:
		var from: float = spin + i * step
		draw_arc(center, r, from, from + step * 0.5, 3, Color(_glow, _glow.a * 0.8), 6.0)
		draw_arc(center, r, from, from + step * 0.5, 3, Color(_back, 0.8), 4.0)
		draw_arc(center, r, from, from + step * 0.5, 3, Color(_line, 0.9), 2.0)


## A target's bracket (it closes in when locked) and, once locked, its THREAT label.
func _draw_target(target: Dictionary, position_local: Vector2, zoom: float, now: int,
		alpha: float) -> void:
	var center: Vector2 = position_local.round()
	var radius: float = maxf(float(target.radius) * zoom, 6.0) + 3.0
	var k: float = clampf((now - int(target.locked_msec)) / LOCK_IN_MSEC, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - k, 3.0)
	var half: float = roundf(lerpf(radius * 2.2, radius, eased))
	var color: Color = Color(_line, alpha * (0.4 + 0.6 * k))
	_draw_brackets(center, half, maxf(roundf(half * 0.45), 5.0), color, STROKE)
	if k < 1.0:
		return

	var line1: String = "THREAT %02d" % int(target.number)
	var line2: String = str(target.name)
	var text_w: float = maxf(
			FONT.get_string_size(line1, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x,
			FONT.get_string_size(line2, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x)
	var box_size: Vector2 = Vector2(ceilf(text_w) + 10.0, 26.0)
	var gap: float = 10.0
	# Label to the right of the bracket, or to the left near the right edge
	var on_right: bool = center.x + half + gap + box_size.x <= size.x - 4.0
	var box_x: float = center.x + half + gap if on_right else center.x - half - gap - box_size.x
	var box_y: float = clampf(center.y - half, 4.0, size.y - box_size.y - 4.0)
	var box: Rect2 = Rect2(Vector2(box_x, box_y), box_size)
	var link_y: float = roundf(box_y + box_size.y / 2.0)
	var link_from: float = center.x + half if on_right else box_x + box_size.x
	var link_to: float = box_x if on_right else center.x - half
	_bar(Rect2(link_from, link_y, link_to - link_from, 2.0), color)
	draw_rect(box.grow(3.0), Color(_glow, _glow.a * alpha))
	draw_rect(box, Color(_back, _back.a * alpha))
	_outline(box, color)
	_outline(box.grow(-1.0), color)
	_outline(box.grow(-2.0), Color(_back, alpha))
	_text(Vector2(box_x + 5.0, box_y + 11.0), line1, alpha)
	_text(Vector2(box_x + 5.0, box_y + 22.0), line2, alpha)


## Uses left: pips under the ship (lit = left, dim = spent).
func _draw_charges(ship: Vector2) -> void:
	var total: int = scanner.max_charges
	var pip: float = 3.0
	var step: float = 6.0
	var start: Vector2 = Vector2(roundf(ship.x - (total * step - (step - pip)) / 2.0),
			roundf(ship.y + 16.0))
	for i in total:
		var rect: Rect2 = Rect2(start + Vector2(i * step, 0.0), Vector2(pip, pip))
		_bar(rect, _line if i < scanner.charges else Color(_line, 0.3))


## Four corner brackets of a square of half size `half` around `center`.
func _draw_brackets(center: Vector2, half: float, arm: float, color: Color,
		thick: float) -> void:
	var l: float = center.x - half
	var r: float = center.x + half
	var t: float = center.y - half
	var b: float = center.y + half
	_bar(Rect2(l, t, arm, thick), color)
	_bar(Rect2(l, t, thick, arm), color)
	_bar(Rect2(r - arm, t, arm, thick), color)
	_bar(Rect2(r - thick, t, thick, arm), color)
	_bar(Rect2(l, b - thick, arm, thick), color)
	_bar(Rect2(l, b - arm, thick, arm), color)
	_bar(Rect2(r - arm, b - thick, arm, thick), color)
	_bar(Rect2(r - thick, b - arm, thick, arm), color)


## A bright bar on a 1 px dark edge with a soft halo around it, so it stands out over any
## background, the arena's own colour included.
func _bar(rect: Rect2, color: Color) -> void:
	draw_rect(rect.grow(3.0), Color(_glow, _glow.a * color.a * 0.5))
	draw_rect(rect.grow(2.0), Color(_glow, _glow.a * color.a))
	draw_rect(rect.grow(1.0), Color(_back, _back.a * color.a))
	draw_rect(rect, color)


## Text in the HUD labels' style (dark fill, bright outline in the arena's colour) with a
## halo around the outline.
func _text(pos: Vector2, text: String, alpha: float) -> void:
	draw_string_outline(FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 9,
			Color(_glow, _glow.a * alpha))
	draw_string_outline(FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 5,
			Color(_line, alpha))
	draw_string(FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE,
			Color(_back.r, _back.g, _back.b, alpha))


func _outline(rect: Rect2, color: Color) -> void:
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 1.0)), color)
	draw_rect(Rect2(rect.position + Vector2(0.0, rect.size.y - 1.0), Vector2(rect.size.x, 1.0)),
			color)
	draw_rect(Rect2(rect.position, Vector2(1.0, rect.size.y)), color)
	draw_rect(Rect2(rect.position + Vector2(rect.size.x - 1.0, 0.0), Vector2(1.0, rect.size.y)),
			color)
