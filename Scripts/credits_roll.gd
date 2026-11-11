extends Control
## Credits roll (Scenes/credits_roll.tscn): the lines of credits_text scroll up over the
## animated starfield (Starfield, Scripts/UI/starfield.gd), and the end logo stays in the
## middle with the music playing. It only leaves when the player wants: Skip (Enter), pause
## (Esc), a click or a tap fades out (image and music) to next_scene_path.
##
## credits_text, one line per row: "# " = title, "## " = section heading, "> " = small dim
## line (sources, licences), an empty line = a gap, anything else = a normal line.

@export_multiline var credits_text: String = """# Credits

Created by ANGELUS11


## Programming / Art
ANGELUS11


## Music
Psychronic Games


## CRT Visual Shader
lord0Sanz


## Game Thumbnail
NestorGMS


## Sound Effects
Laser4.wav by jobro
> https://freesound.org/s/35681/ - License: Attribution 3.0

Picked Coin Echo by NenadSimic
> https://freesound.org/s/171696/ - License: Attribution 4.0

Glitch_001.wav by AlienXXX
> https://freesound.org/s/195491/ - License: Attribution 4.0

Game Sound Correct With Delay by Bertrof
> https://freesound.org/s/351564/ - License: Attribution 3.0


## Special Thanks to
Cro128
Odruu
Juanhez



Made with Godot Engine



ANGELUS11 - 2026"""
## Pixels per second.
@export var scroll_speed: float = 18.0
## Text styles, the same as the main menu's credits panel (Scenes/credits.tscn):
## the "CREDITS" title, its lines and its small sound credits.
@export var title_settings: LabelSettings
@export var heading_settings: LabelSettings
@export var text_settings: LabelSettings
@export var small_settings: LabelSettings
## Height of an empty line.
@export var gap: int = 10
@export var fade_time: float = 1.0
## Replaces the "# " title line (the ADVAD logo instead of "Credits"). Empty = the text.
@export var title_logo: Texture2D
## 1 keeps the pixel art sharp.
@export var title_logo_scale: float = 1.0
## Tint of the title logo: lower than white dims it (the CRT overlay brightens the screen).
@export var title_logo_tint: Color = Color(0.7, 0.7, 0.7, 1.0)
## Comes up after the last line and stays in the middle of the screen while the text leaves.
## Drawn additively, so a black background (logoascii.png) disappears and only its glow shows.
@export var end_logo: Texture2D
## Same scale as the splash screen's logo.
@export var logo_scale: float = 0.08
## Tint of the end logo: lower than white dims it. It's drawn additively and the CRT
## overlay brightens the screen a lot, so at full white it burns out.
@export var end_logo_tint: Color = Color(0.4, 0.4, 0.4, 1.0)
@export_file("*.tscn") var next_scene_path: String = "res://Scenes/main_menu.tscn"

@onready var lines: VBoxContainer = $Lines
@onready var fade: ColorRect = $UILayer/Fade

var _scroll_y: float = 0.0
var _leaving: bool = false
var _finished: bool = false
var _logo: TextureRect
var _logo_size: Vector2 = Vector2.ZERO


func _ready() -> void:
	GameManager.can_pause = false
	_build_lines()
	if end_logo:
		_build_logo()
	# Starts just below the screen
	_scroll_y = size.y
	_place_lines()
	_place_logo()
	fade.visible = true
	fade.modulate.a = 1.0
	create_tween().tween_property(fade, "modulate:a", 0.0, fade_time)


func _build_lines() -> void:
	for raw in credits_text.split("\n"):
		var text: String = raw.strip_edges()
		if text.is_empty():
			var spacer: Control = Control.new()
			spacer.custom_minimum_size.y = gap
			spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lines.add_child(spacer)
			continue
		var settings: LabelSettings = text_settings
		if text.begins_with("## "):
			text = text.substr(3)
			settings = heading_settings
		elif text.begins_with("# "):
			if title_logo:
				_add_image(title_logo, title_logo_scale, title_logo_tint)
				continue
			text = text.substr(2)
			settings = title_settings
		elif text.begins_with("> "):
			text = text.substr(2)
			settings = small_settings
		var label: Label = Label.new()
		label.text = text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.label_settings = settings
		lines.add_child(label)


## An image as a row of the credits, centred. The scale doesn't count for the layout, so a
## holder of the scaled size keeps the room.
func _add_image(texture: Texture2D, image_scale: float, tint: Color) -> void:
	var holder: Control = Control.new()
	holder.custom_minimum_size = (texture.get_size() * image_scale).round()
	var image: TextureRect = TextureRect.new()
	image.texture = texture
	image.scale = Vector2(image_scale, image_scale)
	image.modulate = tint
	holder.add_child(image)
	var center: CenterContainer = CenterContainer.new()
	center.add_child(holder)
	lines.add_child(center)
	# Clicks go through (a click anywhere skips the credits)
	for node: Control in [holder, image, center]:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE


## The logo is its own node (not in Lines): it comes up right after the last line and stops
## in the middle of the screen while the text keeps going (_place_logo).
func _build_logo() -> void:
	_logo_size = (end_logo.get_size() * logo_scale).round()
	_logo = TextureRect.new()
	_logo.texture = end_logo
	_logo.scale = Vector2(logo_scale, logo_scale)
	_logo.modulate = end_logo_tint
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE  # a click anywhere skips the credits
	var additive: CanvasItemMaterial = CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_logo.material = additive
	add_child(_logo)
	move_child(_logo, lines.get_index() + 1)


## Whole pixels, so the pixel font doesn't shimmer while it scrolls.
func _place_lines() -> void:
	lines.position = Vector2(0.0, roundf(_scroll_y))
	lines.size.x = size.x


## Bottom of the text (its computed height, not the container's current size).
func _text_bottom() -> float:
	return lines.position.y + lines.get_combined_minimum_size().y


## Follows the text from below until it reaches the middle of the screen, then stays there.
func _place_logo() -> void:
	if _logo == null:
		return
	var middle: float = (size.y - _logo_size.y) * 0.5
	var following: float = _text_bottom() + gap * 3
	_logo.position = Vector2(roundf((size.x - _logo_size.x) * 0.5), roundf(maxf(middle, following)))


func _process(delta: float) -> void:
	if not _finished:
		_scroll_y -= scroll_speed * delta
		_place_lines()
	_place_logo()
	# Every line gone off the top: the logo stays in the middle, with the music, until the
	# player leaves (click, tap, Enter or Esc)
	if not _finished and _text_bottom() < 0.0:
		_finished = true


func _unhandled_input(event: InputEvent) -> void:
	var pressed: bool = event.is_action_pressed("Skip") or event.is_action_pressed("pause") \
			or (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed)
	if pressed:
		get_viewport().set_input_as_handled()
		_leave()


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	MusicPlayer.fade_out_and_stop(fade_time)
	var tween: Tween = create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, fade_time)
	await tween.finished
	# The music's fade ends with stop(): let it finish first, or it would stop the menu's song
	while MusicPlayer.is_fading:
		await get_tree().process_frame
	GameManager.can_pause = true
	get_tree().change_scene_to_file(next_scene_path)
