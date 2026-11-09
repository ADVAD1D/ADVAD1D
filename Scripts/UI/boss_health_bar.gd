extends Control
## Boss health bar, built in code by saw_boss.gd and added to the HUD at the top, in place
## of the phase and objective labels. Drawn in the HUD's own cyan, so the arena tint (ArenaTint) recolours it
## like the rest of the HUD (red in arena 3). A light chunk shows the damage just taken and
## drains after a moment; a notch marks phase two. Fades out when the boss dies.

const FONT: FontFile = preload("res://Assets/Fonts/Kenney Pixel.ttf")
const FONT_SIZE: int = 16
const BAR_SIZE: Vector2 = Vector2(200.0, 8.0)
## Top of the bar block in HUD coordinates: where the phase label goes (PhaseManager hides
## the phase and objective labels during a boss fight).
const TOP: float = 20.0
## The HUD labels' centre is a bit right of the HUD's centre.
const CENTER_SHIFT: float = 8.0
const OUTLINE: Color = Color(0.0, 1.0, 1.0)
const BACK: Color = Color(0.0, 0.102, 0.102)
const FILL: Color = Color(0.0, 0.8, 0.8)
const FILL_LIGHT: Color = Color(0.55, 1.0, 1.0)
const TRAIL: Color = Color(0.85, 1.0, 1.0)
const TRAIL_DELAY: float = 0.45
const TRAIL_SPEED: float = 0.6

var boss_name: String = "BOSS"
## Health fraction where the notch goes (0 = none): the boss's checkpoint.
var phase_mark: float = 0.5
## Once the checkpoint is reached the notch becomes a bright line across the bar.
var mark_reached: bool = false

var _ratio: float = 1.0
var _trail: float = 1.0
var _trail_wait: float = 0.0
var _closing: bool = false


func _ready() -> void:
	# The HUD processes while paused (process mode ALWAYS); the bar belongs to the fight, so
	# its damage trail and fade-out stop with the pause menu like the boss does
	process_mode = Node.PROCESS_MODE_PAUSABLE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var width: float = BAR_SIZE.x + 4.0
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = -width / 2.0 + CENTER_SHIFT
	offset_right = width / 2.0 + CENTER_SHIFT
	offset_top = TOP
	offset_bottom = TOP + 28.0


## The boss reached its checkpoint (or comes back from it after a death).
func reach_mark() -> void:
	mark_reached = true
	queue_redraw()


func set_health(current: int, maximum: int, animate: bool = true) -> void:
	_ratio = clampf(float(current) / maxf(float(maximum), 1.0), 0.0, 1.0)
	if not animate or _ratio > _trail:
		_trail = _ratio
	_trail_wait = TRAIL_DELAY
	queue_redraw()
	if current <= 0 and not _closing:
		_closing = true
		var tween: Tween = create_tween()
		tween.tween_interval(0.8)
		tween.tween_property(self, "modulate:a", 0.0, 0.8)
		tween.tween_callback(queue_free)


func _process(delta: float) -> void:
	if _trail <= _ratio:
		return
	if _trail_wait > 0.0:
		_trail_wait -= delta
		return
	_trail = maxf(_ratio, _trail - TRAIL_SPEED * delta)
	queue_redraw()


func _draw() -> void:
	# Name, in the HUD label style (dark fill, bright outline)
	var text: String = boss_name.to_upper()
	var text_width: float = FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			FONT_SIZE).x
	var text_pos: Vector2 = Vector2(roundf((size.x - text_width) / 2.0), 11.0)
	draw_string_outline(FONT, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 4,
			OUTLINE)
	draw_string(FONT, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, BACK)

	var origin: Vector2 = Vector2(2.0, 16.0)
	var w: float = BAR_SIZE.x
	var h: float = BAR_SIZE.y
	draw_rect(Rect2(origin - Vector2.ONE * 2.0, BAR_SIZE + Vector2.ONE * 4.0), BACK)
	draw_rect(Rect2(origin - Vector2.ONE, BAR_SIZE + Vector2.ONE * 2.0), OUTLINE)
	draw_rect(Rect2(origin, BAR_SIZE), BACK)
	var trail_w: float = floorf(w * _trail)
	var fill_w: float = floorf(w * _ratio)
	if trail_w > 0.0:
		draw_rect(Rect2(origin, Vector2(trail_w, h)), TRAIL)
	if fill_w > 0.0:
		draw_rect(Rect2(origin, Vector2(fill_w, h)), FILL)
		draw_rect(Rect2(origin, Vector2(fill_w, 1.0)), FILL_LIGHT)
	# Segments every 10 %
	for i in range(1, 10):
		var x: float = origin.x + floorf(w * i / 10.0)
		draw_rect(Rect2(Vector2(x, origin.y + 1.0), Vector2(1.0, h - 1.0)), BACK)
	# Checkpoint notch, above and below the bar; once reached, a bright line joins them
	if phase_mark > 0.0:
		var mx: float = origin.x + floorf(w * phase_mark)
		var tall: float = 3.0 if mark_reached else 2.0
		draw_rect(Rect2(Vector2(mx - 1.0, origin.y - 2.0 - tall), Vector2(3.0, tall)), OUTLINE)
		draw_rect(Rect2(Vector2(mx - 1.0, origin.y + h + 2.0), Vector2(3.0, tall)), OUTLINE)
		if mark_reached:
			draw_rect(Rect2(Vector2(mx, origin.y - 2.0), Vector2(1.0, h + 4.0)), TRAIL)
