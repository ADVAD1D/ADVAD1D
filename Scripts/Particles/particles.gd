extends CPUParticles2D

func _ready() -> void:
	if GameManager.mobile_mode_active or OS.has_feature("web") or GameManager.force_web_mode:
		lifetime = 0.4
		amount = 8
	fixed_fps = 0
	fract_delta = true
	emitting = true

func _on_finished() -> void:
	queue_free()
