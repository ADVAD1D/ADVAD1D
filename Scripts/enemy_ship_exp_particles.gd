extends GPUParticles2D

func _ready() -> void:
	if GameManager.mobile_mode_active or OS.has_feature("web") or GameManager.force_web_mode:
		lifetime = 0.11
	emitting = true
		
func _on_finished() -> void:
	queue_free()
