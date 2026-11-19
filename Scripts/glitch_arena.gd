extends Sprite2D
## Arena 4's background (Shaders/glitch_arena.gdshader draws the whole room). Drives the
## shader's breaking simulation:
## - corruption: how much of the floor and walls has broken down. It grows with the phase
##   (PhaseManager.phase_started), easing towards the new value.
## - bursts: short glitches every few seconds (bands slide sideways, colours split), plus a
##   strong one at every new phase.
## Only the background glitches, so the ships and lasers on top always read clearly.
## Also used by tutorial_arena4.tscn, which has no PhaseManager (start_corruption only).

## The arena's PhaseManager (PhaseNode). Empty in the tutorial.
@export var phase_manager: Node
## Corruption with no phase yet (the tutorial).
@export var start_corruption: float = 0.1
## Corruption added per phase (phase 1 = start_corruption).
@export var corruption_per_phase: float = 0.09
## How fast the corruption reaches its new value (per second).
@export var corruption_speed: float = 0.15
## Seconds between two bursts (random in this range).
@export var burst_interval: Vector2 = Vector2(3.0, 7.0)
## Length of a burst in seconds (random in this range).
@export var burst_duration: Vector2 = Vector2(0.12, 0.35)
## Strength of the random bursts (random in this range, 0-1).
@export var burst_strength: Vector2 = Vector2(0.35, 0.7)
## Strength and length of the burst at every new phase.
@export var phase_burst_strength: float = 1.0
@export var phase_burst_duration: float = 0.5
## The burst picks new bands this often (seconds), so it stutters instead of holding still.
@export var burst_reseed_time: float = 0.05

var _material: ShaderMaterial
var _corruption: float = 0.0
var _target_corruption: float = 0.0
var _next_burst: float = 0.0
var _burst_left: float = 0.0
var _burst_length: float = 1.0
var _burst_peak: float = 0.0
var _reseed_left: float = 0.0
## Last phase PhaseManager started in this scene (0 = none yet).
var _last_phase: int = 0
## The shader's animation clock (anim_time). Advanced here instead of the shader's TIME so
## the room stops with the pause menu (this node is pausable).
var _anim_time: float = 0.0


func _ready() -> void:
	_material = material as ShaderMaterial
	_target_corruption = start_corruption
	if is_instance_valid(phase_manager) and phase_manager.has_signal("phase_started"):
		phase_manager.phase_started.connect(_on_phase_started)
		_target_corruption = _corruption_for_phase(GameManager.phase_to_start)
	_corruption = _target_corruption
	_next_burst = randf_range(burst_interval.x, burst_interval.y)
	_apply(0.0)


func _process(delta: float) -> void:
	if _material == null:
		return
	_anim_time += delta
	_material.set_shader_parameter("anim_time", _anim_time)
	_corruption = move_toward(_corruption, _target_corruption, corruption_speed * delta)

	var amount: float = 0.0
	if _burst_left > 0.0:
		_burst_left -= delta
		amount = _burst_peak * clampf(_burst_left / _burst_length, 0.0, 1.0)
		_reseed_left -= delta
		if _reseed_left <= 0.0:
			_reseed_left = burst_reseed_time
			_material.set_shader_parameter("burst_seed", randf() * 1000.0)
	else:
		_next_burst -= delta
		if _next_burst <= 0.0:
			_start_burst(randf_range(burst_strength.x, burst_strength.y),
					randf_range(burst_duration.x, burst_duration.y))
	_apply(amount)


func _apply(amount: float) -> void:
	if _material == null:
		return
	_material.set_shader_parameter("corruption", _corruption)
	_material.set_shader_parameter("burst", amount)


func _start_burst(strength: float, duration: float) -> void:
	_burst_peak = strength
	_burst_length = maxf(duration, 0.01)
	_burst_left = _burst_length
	_reseed_left = 0.0
	_next_burst = randf_range(burst_interval.x, burst_interval.y)


func _corruption_for_phase(phase: int) -> float:
	return clampf(start_corruption + (maxi(phase, 1) - 1) * corruption_per_phase, 0.0, 1.0)


func _on_phase_started(phase_number: int, _score_requirement: int) -> void:
	_target_corruption = _corruption_for_phase(phase_number)
	# The first phase of a scene load is quiet; every new phase breaks the picture hard
	if _last_phase > 0 and phase_number > _last_phase:
		_start_burst(phase_burst_strength, phase_burst_duration)
	_last_phase = phase_number
