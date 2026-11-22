extends Control
## Base of the chat console's real-time minigames (/usr/games: invasion, dash, boom).
##
## The console (ai_console.gd) prints intro(), puts the game over its log (same rect, the
## log is hidden meanwhile) and waits for `finished`, whose lines it prints afterwards.
## Subclasses set themselves up in start(), update in tick() and draw in _draw() (calling
## draw_close() last). Keyboard uses the game's actions (Move_*, Shoot, Skip); touches are
## kept in _touches (local positions) so phones can play too. Esc (the console calls
## quit()) or a tap on the [x] in the top-right corner leaves.

signal finished(lines: Array)

const COLOR_BG: Color = Color("#00080a")
const COLOR_TEXT: Color = Color("#a2ffff")
const COLOR_DIM: Color = Color("#5f8f8f")
const COLOR_GOLD: Color = Color("#ffd36b")
const COLOR_RED: Color = Color("#ff6b6b")
const CLOSE_SIZE: float = 14.0
## Longest step per frame, so a hitch doesn't push things through walls.
const MAX_DELTA: float = 1.0 / 30.0
const FONT_SIZE: int = 16

## The console log's font, set before the game enters the tree.
var font: Font
## Touch index -> local position, while held.
var _touches: Dictionary = {}
## True during the tick after a new touch began.
var _tapped: bool = false
var _done: bool = false


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font == null:
		font = ThemeDB.fallback_font
	start()


func _process(delta: float) -> void:
	if _done:
		return
	tick(minf(delta, MAX_DELTA))
	_tapped = false
	queue_redraw()


## Console lines printed before the game shows up (BBCode lines and float pauses).
func intro() -> Array:
	return []


## Sets the game up; size is already the screen's.
func start() -> void:
	pass


func tick(_delta: float) -> void:
	pass


## Console lines printed when the game ends or is left.
func summary() -> Array:
	return []


func quit() -> void:
	end(summary())


func end(lines: Array) -> void:
	if _done:
		return
	_done = true
	finished.emit(lines)


func _input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if not touch.pressed:
			_touches.erase(touch.index)
			return
		var local: Vector2 = _screen_to_local(touch.position)
		if not Rect2(Vector2.ZERO, size).has_point(local):
			return
		if _close_rect().has_point(local):
			quit()
			return
		_tapped = true
		_touches[touch.index] = local
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		if _touches.has(drag.index):
			_touches[drag.index] = _screen_to_local(drag.position)


func held(action: StringName) -> bool:
	return Input.is_action_pressed(action)


func touching() -> bool:
	return not _touches.is_empty()


func first_touch() -> Vector2:
	return _touches.values()[0]


func draw_text(pos: Vector2, text: String, color: Color = COLOR_TEXT) -> void:
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)


## Text centred across the screen, y is the baseline.
func draw_centered(y: float, text: String, color: Color = COLOR_TEXT) -> void:
	draw_string(font, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, FONT_SIZE, color)


## The [x] box in the top-right corner (tap to leave).
func draw_close() -> void:
	var box: Rect2 = _close_rect()
	draw_rect(box, COLOR_BG)
	draw_rect(box.grow(-0.5), COLOR_DIM, false, 1.0)
	for i in range(4, int(CLOSE_SIZE) - 4):
		draw_rect(Rect2(box.position + Vector2(i, i), Vector2.ONE), COLOR_DIM)
		draw_rect(Rect2(box.position + Vector2(CLOSE_SIZE - 1 - i, i), Vector2.ONE), COLOR_DIM)


func _close_rect() -> Rect2:
	return Rect2(size.x - CLOSE_SIZE - 2.0, 2.0, CLOSE_SIZE, CLOSE_SIZE)


func _screen_to_local(screen_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * screen_position


## Pixel-art texture from a character map: each character in the palette is a pixel of
## that colour, anything else is transparent.
static func make_sprite(rows: Array, palette: Dictionary) -> ImageTexture:
	var width: int = (rows[0] as String).length()
	var image: Image = Image.create_empty(width, rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		var row: String = rows[y]
		for x in width:
			if palette.has(row[x]):
				image.set_pixel(x, y, palette[row[x]])
	return ImageTexture.create_from_image(image)


## A console line in a colour (BBCode, text escaped).
static func line(text: String, color: String = "#ffd36b") -> String:
	return "[color=%s]%s[/color]" % [color, SimTerminal.esc(text)]
