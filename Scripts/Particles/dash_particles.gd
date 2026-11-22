extends GPUParticles2D

func _ready() -> void:
	if GameManager.mobile_mode_active:
		lifetime = 0.4
	emitting = true

func _on_finished() -> void:
	queue_free()
