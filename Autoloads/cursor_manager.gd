extends Node
## Replaces the system mouse cursor with a small pixel-art arrow in the game's colours.
## It's a hardware cursor (Input.set_custom_mouse_cursor): no rendering cost and it works on
## web too. Since a hardware cursor isn't scaled with the 520x300 game, the arrow is scaled
## by the same whole factor as the game's pixels and rebuilt when the window is resized.
## While the left button is held it lights up. Not used on phones (touch, no cursor).
## To change the drawing, edit ARROW: one character per pixel, see COLORS.
## While playing (an arena or a tutorial, main mode or arcade) the cursor is hidden; it comes
## back while the game is paused (pause menu) and in every other scene.

## Scenes where the cursor hides: main.gd (every arena) and tutorial.gd join it.
const GAMEPLAY_GROUP: StringName = &"gameplay_scenes"

const ARROW: Array[String] = [
	"O........",
	"OO.......",
	"OLO......",
	"OLCO.....",
	"OLCCO....",
	"OLCCCO...",
	"OLCCCCO..",
	"OLCCCCCO.",
	"OLCCOOOOO",
	"OLOOCDO..",
	"OO..OCDO.",
	".....OCO.",
	".....OO..",
]
## Outline, light edge, cyan fill, shade (same palette as the shop and menu UI).
const COLORS: Dictionary = {
	"O": Color("0d1414"),
	"L": Color("a2ffff"),
	"C": Color("04daff"),
	"D": Color("03708a"),
}
## While clicking: the fill lights up.
const PRESSED_COLORS: Dictionary = {
	"O": Color("0d1414"),
	"L": Color("ffffff"),
	"C": Color("a2ffff"),
	"D": Color("04daff"),
}
const BASE_SIZE: Vector2 = Vector2(520, 300)
## Keeps the cursor a sensible size on huge windows (the system limit is 256 px).
const MAX_SCALE: int = 4

var _normal: ImageTexture
var _pressed: ImageTexture
var _scale: int = 0
var _is_pressed: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _is_touch_device():
		set_process_input(false)
		set_process(false)
		return
	get_tree().root.size_changed.connect(_rebuild)
	_rebuild()


func _process(_delta: float) -> void:
	var mode: Input.MouseMode = Input.MOUSE_MODE_HIDDEN if _is_playing() else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != mode:
		Input.mouse_mode = mode


## In a gameplay scene and not paused. Mobile mode forced on desktop keeps the cursor: its
## touch buttons are pressed with the mouse there.
func _is_playing() -> bool:
	if GameManager.mobile_mode_active or get_tree().paused:
		return false
	var scene: Node = get_tree().current_scene
	return scene != null and scene.is_in_group(GAMEPLAY_GROUP)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed != _is_pressed:
			_is_pressed = event.pressed
			_apply()


## Rebuilds the arrow when the window changes size, so its pixels match the game's.
func _rebuild() -> void:
	var window: Vector2 = Vector2(get_tree().root.size)
	var factor: float = minf(window.x / BASE_SIZE.x, window.y / BASE_SIZE.y)
	var new_scale: int = clampi(int(factor), 1, MAX_SCALE)
	if new_scale == _scale:
		return
	_scale = new_scale
	_normal = _make_texture(COLORS)
	_pressed = _make_texture(PRESSED_COLORS)
	_apply()


func _apply() -> void:
	if _normal == null:
		return
	# Hotspot (0, 0): the arrow's tip is its top-left pixel
	Input.set_custom_mouse_cursor(_pressed if _is_pressed else _normal)


func _make_texture(colors: Dictionary) -> ImageTexture:
	var width: int = ARROW[0].length()
	var image: Image = Image.create(width, ARROW.size(), false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in ARROW.size():
		for x in width:
			var key: String = ARROW[y][x]
			if colors.has(key):
				image.set_pixel(x, y, colors[key])
	image.resize(width * _scale, ARROW.size() * _scale, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)


func _is_touch_device() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") \
			or OS.has_feature("web_ios")
