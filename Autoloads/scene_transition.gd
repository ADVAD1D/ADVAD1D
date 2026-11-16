extends CanvasLayer
## Scene transition: everything in the game happens on a simulation monitor, so changing
## scene is the monitor losing its feed and picking up the next one. The picture breaks up
## into static (Shaders/transition_static.gdshader: tearing, colour split, scanlines), the
## scene changes under pure static, and the static clears off the new scene. A terminal
## line (adnex@sim) shows the feed being relinked.
##
## Use it instead of the SceneTree calls: SceneTransition.change_scene_to_packed(scene) /
## change_scene_to_file(path). Reloads after a death keep their own glitch (main.gd,
## PhaseManager), so they don't come through here.

## Seconds the picture takes to break up, the pure static held while the new scene loads,
## and the static clearing off it.
var out_time: float = 0.12
var hold_time: float = 0.05
var in_time: float = 0.2
## Volume of the static noise (dB, SFX bus).
var sound_volume_db: float = -14.0

const SHADER: Shader = preload("res://Shaders/transition_static.gdshader")
const FONT: FontFile = preload("res://Assets/Fonts/Kenney Pixel.ttf")
const SOUND: AudioStream = preload("res://Assets/Audio/195491__alienxxx__glitch_001.wav")
const FEED_TEXT: String = "adnex@sim:~$ relink --feed"
## The CRT shader's own defaults, for a CRT material that doesn't set them.
const SHADER_DEFAULTS: Dictionary = {
	"warp_amount": 1.0, "vignette_intensity": 0.4, "vignette_opacity": 0.5,
	"brightness": 1.4, "aberration": 0.03,
}
## Values for a scene without a CRT overlay: a flat, plain screen.
const NO_CRT: Dictionary = {
	"warp_amount": 0.0, "vignette_intensity": 0.4, "vignette_opacity": 0.5,
	"brightness": 1.0, "aberration": 0.0,
}

var _screen: ColorRect
var _material: ShaderMaterial
var _feed_label: Label
var _sound: AudioStreamPlayer
var _busy: bool = false
var _cursor_clock: float = 0.0


func _ready() -> void:
	layer = 128  # over everything, CRT overlays and the pause menu included
	process_mode = Node.PROCESS_MODE_ALWAYS
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("low_quality", GameManager.mobile_mode_active \
			or OS.has_feature("mobile") or OS.has_feature("web") or GameManager.force_web_mode)

	_screen = ColorRect.new()
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.material = _material
	_screen.mouse_filter = Control.MOUSE_FILTER_STOP  # no clicks get through mid-change
	add_child(_screen)

	_feed_label = Label.new()
	_feed_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var settings: LabelSettings = LabelSettings.new()
	settings.font = FONT
	settings.font_size = 16
	settings.font_color = Color(0.0, 0.2, 0.2)
	settings.outline_size = 2
	settings.outline_color = Color(0.4, 1.0, 1.0)
	_feed_label.label_settings = settings
	_feed_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	# Clear of the CRT's rounded corner
	_feed_label.offset_left = 22.0
	_feed_label.offset_top = -32.0
	_feed_label.offset_bottom = -14.0
	_feed_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(_feed_label)

	_sound = AudioStreamPlayer.new()
	_sound.stream = SOUND
	_sound.bus = &"SFX"
	_sound.volume_db = sound_volume_db
	add_child(_sound)

	# One invisible frame (amount 0 draws the picture as it is) so the shader compiles at
	# boot instead of freezing the first transition
	_set_amount(0.0)
	_screen.visible = true
	_feed_label.visible = false
	await get_tree().process_frame
	await get_tree().process_frame
	if not _busy:
		_screen.visible = false


func is_transitioning() -> bool:
	return _busy


func change_scene_to_packed(scene: PackedScene) -> void:
	if scene == null:
		return
	_run(func() -> Error: return get_tree().change_scene_to_packed(scene))


func change_scene_to_file(path: String) -> void:
	_run(func() -> Error: return get_tree().change_scene_to_file(path))


func _run(change: Callable) -> void:
	if _busy:
		return
	if not is_enabled():
		change.call()
		return
	_busy = true
	_screen.visible = true
	_feed_label.visible = false
	_feed_label.text = FEED_TEXT
	_sound.volume_db = sound_volume_db
	_sound.play()
	_copy_screen_shape()
	await _tween_amount(0.0, 1.0, out_time)
	_feed_label.visible = true
	if change.call() == OK:
		await get_tree().scene_changed
		_copy_screen_shape()
	# The new scene's first frames (heavy _ready work) stay under the static
	await get_tree().process_frame
	await get_tree().create_timer(hold_time, true, false, true).timeout
	_feed_label.visible = false
	await _tween_amount(1.0, 0.0, in_time)
	_sound.stop()
	_screen.visible = false
	_busy = false


func _tween_amount(from: float, to: float, time: float) -> void:
	var tween: Tween = create_tween()
	tween.set_ignore_time_scale(true)  # the time slow powerup may still be on
	tween.tween_method(_set_amount, from, to, time)
	await tween.finished


## Gives the static the open scene's CRT look (warp, rounded border, vignette, brightness,
## aberration), so it stays inside the same monitor. A scene without a CRT overlay gets a
## flat, plain screen.
func _copy_screen_shape() -> void:
	var crt: ShaderMaterial = _find_crt(get_tree().current_scene)
	for parameter: String in SHADER_DEFAULTS:
		var value: Variant = NO_CRT[parameter] if crt == null else SHADER_DEFAULTS[parameter]
		if crt and crt.get_shader_parameter(parameter) != null:
			value = crt.get_shader_parameter(parameter)
		_material.set_shader_parameter(parameter, value)


## Off with the low quality shader setting (PC: "optimize shaders"; phones: retro shader
## off): the scene just changes.
func is_enabled() -> bool:
	if GameManager.mobile_mode_active:
		return GameManager.retro_shader_active
	return not GameManager.pc_optimize_shaders


func _find_crt(node: Node) -> ShaderMaterial:
	if node == null:
		return null
	if node is CanvasItem and node.visible:
		var material: ShaderMaterial = (node as CanvasItem).material as ShaderMaterial
		if material and material.shader and "CRT" in material.shader.resource_path:
			return material
	for child in node.get_children():
		var found: ShaderMaterial = _find_crt(child)
		if found:
			return found
	return null


func _set_amount(value: float) -> void:
	_material.set_shader_parameter("amount", value)


func _process(delta: float) -> void:
	# Blinking terminal cursor while the feed relinks
	if _feed_label and _feed_label.visible:
		_cursor_clock += delta
		var cursor: String = "_" if fmod(_cursor_clock, 0.4) < 0.2 else " "
		_feed_label.text = FEED_TEXT + cursor
