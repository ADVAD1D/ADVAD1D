extends Sprite2D
## Wave layer over an arena background (Shaders/background_waves.gdshader). Put it as a
## child of the background Sprite2D: it draws the same texture at the same place, so the
## shader can find the background's empty areas, and it follows the background's
## grayscale_amount (arena won, time slow) every frame. It also feeds the shader its clock:
## it only advances while this node processes, so the waves stop when the game is paused
## (and slow down with the time slow powerup, like everything else).

var _background: Sprite2D
var _time: float = 0.0


func _ready() -> void:
	_background = get_parent() as Sprite2D
	if _background == null:
		push_warning("BackgroundWaves needs a Sprite2D parent")
		set_process(false)
		return
	texture = _background.texture
	centered = _background.centered
	offset = _background.offset


func _process(delta: float) -> void:
	var own: ShaderMaterial = material as ShaderMaterial
	if own == null:
		return
	_time += delta
	own.set_shader_parameter("time", _time)
	var source: ShaderMaterial = _background.material as ShaderMaterial
	if source:
		var amount: Variant = source.get_shader_parameter("grayscale_amount")
		if amount != null:
			own.set_shader_parameter("grayscale_amount", amount)
