extends Node2D
## Triple shot powerup (arena 3): Scenes/triple_shot.tscn, put on the player by its pickup
## (triple_shot_pickup.tscn, laser_shield_pickup.gd with active_group player_triple_shot).
## While it's a child of the player, player.gd's shoot() fires three lasers per shot,
## fanned out by spread_degrees. It lasts `duration` seconds (game time) and then frees
## itself. It draws three small dots ahead of the ship's nose as the "on" sign, which
## blink during the last seconds.

@export var duration: float = 3.0
## Angle between the middle laser and each side one.
@export var spread_degrees: float = 12.0
## The dots blink during this many seconds at the end.
@export var warning_time: float = 1.0

const DOT_COLOR: Color = Color(0.64, 1.0, 1.0)
## Dots in the player's local space (the ship points up; its muzzle is at about y -13.5).
const DOTS: Array[Vector2] = [Vector2(-5.0, -19.0), Vector2(-0.5, -21.0), Vector2(4.0, -19.0)]

var _time_left: float = 0.0


func _ready() -> void:
	add_to_group("player_triple_shot")
	_time_left = duration
	z_index = 1


func _process(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()
		return
	if _time_left < warning_time:
		visible = int(_time_left * 10.0) % 2 == 0
	queue_redraw()


func _draw() -> void:
	for dot in DOTS:
		draw_rect(Rect2(dot - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), DOT_COLOR)
