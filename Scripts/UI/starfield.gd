class_name Starfield
extends Control
## Animated pixel-art starfield, drawn in code over a flat background (fills the Control,
## so it follows the viewport when anchored full rect). Square stars of 1-2 px that
## twinkle in steps, a few cross-shaped sparkles that grow and shrink, big dim teal stars
## that pulse, slow parallax drift, and shooting stars: stepped diagonal trails that fade
## from the head to the tail. Every position is snapped to whole pixels.

@export var background: Color = Color("070d18")
@export var star_count: int = 110
## Colours of the small stars (picked at random; repeat one to make it more common).
@export var star_colors: Array[Color] = [Color("f0f6fa"), Color("f0f6fa"), Color("2fd3e0"),
		Color("a8f0ff")]
@export var big_star_color: Color = Color("0f4a58")
@export var sparkle_color: Color = Color("e6ffff")
## Downward drift of the nearest stars, in pixels per second (farther layers go slower).
@export var drift_speed: float = 6.0

@export_group("Shooting stars")
## Seconds between shooting stars (random between x and y).
@export var shooting_interval: Vector2 = Vector2(1.5, 4.0)
@export var shooting_speed: float = 150.0
@export var trail_length: int = 12
@export var trail_head: Color = Color("8a95a3")
@export var trail_tail: Color = Color("1c222c")
@export_group("")

var _stars: Array[Dictionary] = []
var _shooting: Array[Vector2] = []
var _time: float = 0.0
var _next_shot: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_generate)
	_generate()
	_next_shot = randf_range(0.5, 1.5)


func _generate() -> void:
	_stars.clear()
	if size.x <= 0.0 or size.y <= 0.0:
		return
	for i in star_count:
		_stars.append(_new_star(Vector2(randf() * size.x, randf() * size.y)))


func _new_star(pos: Vector2) -> Dictionary:
	var star: Dictionary = {
		"pos": pos,
		"layer": randi_range(1, 3),
		"phase": randf() * TAU,
		"speed": randf_range(0.8, 3.0),
		"kind": "dot",
		"px": 1,
		"color": star_colors.pick_random() if not star_colors.is_empty() else Color.WHITE,
	}
	var roll: float = randf()
	if roll < 0.06:
		star["kind"] = "sparkle"
		star["color"] = sparkle_color
	elif roll < 0.12:
		star["kind"] = "big"
		star["px"] = 3
		star["color"] = big_star_color
		star["speed"] = randf_range(0.4, 0.9)
	elif roll < 0.3:
		star["px"] = 2
	return star


func _process(delta: float) -> void:
	_time += delta
	for star in _stars:
		var pos: Vector2 = star["pos"]
		pos.y += drift_speed * star["layer"] / 3.0 * delta
		if pos.y > size.y + 4.0:
			# Back in at the top, somewhere else
			pos = Vector2(randf() * size.x, -4.0)
		star["pos"] = pos

	_next_shot -= delta
	if _next_shot <= 0.0:
		_next_shot = randf_range(shooting_interval.x, shooting_interval.y)
		_shooting.append(Vector2(randf_range(size.x * 0.3, size.x + 40.0),
				randf_range(-20.0, size.y * 0.4)))
	# Exactly 45 degrees down-left, so the trail steps one pixel at a time
	var step: float = shooting_speed / sqrt(2.0) * delta
	for i in range(_shooting.size() - 1, -1, -1):
		_shooting[i] += Vector2(-step, step)
		if _shooting[i].x < -trail_length or _shooting[i].y > size.y + trail_length:
			_shooting.remove_at(i)
	queue_redraw()


## 0 (dim), 1 or 2 (full): twinkling in steps, not smoothly, to stay pixel art.
func _level(star: Dictionary) -> int:
	var wave: float = 0.5 + 0.5 * sin(_time * float(star["speed"]) + float(star["phase"]))
	if wave > 0.66:
		return 2
	if wave > 0.33:
		return 1
	return 0


func _shade(color: Color, level: int) -> Color:
	match level:
		2:
			return color
		1:
			return color.lerp(background, 0.45)
	return color.lerp(background, 0.75)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), background)
	for star in _stars:
		var p: Vector2 = (star["pos"] as Vector2).floor()
		var level: int = _level(star)
		match star["kind"]:
			"sparkle":
				# A cross with an empty centre; its arms grow with the level (1-3 px)
				var color: Color = _shade(star["color"], maxi(level, 1))
				for i in range(2, 3 + level):
					draw_rect(Rect2(p + Vector2(i, 0), Vector2.ONE), color)
					draw_rect(Rect2(p - Vector2(i, 0), Vector2.ONE), color)
					draw_rect(Rect2(p + Vector2(0, i), Vector2.ONE), color)
					draw_rect(Rect2(p - Vector2(0, i), Vector2.ONE), color)
			_:
				var s: float = float(star["px"])
				draw_rect(Rect2(p, Vector2(s, s)), _shade(star["color"], level))
	for head in _shooting:
		var h: Vector2 = head.floor()
		for i in trail_length:
			var t: float = float(i) / maxf(trail_length - 1.0, 1.0)
			draw_rect(Rect2(h + Vector2(i, -i), Vector2.ONE), trail_head.lerp(trail_tail, t))
