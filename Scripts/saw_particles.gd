extends GPUParticles2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if GameManager.mobile_mode_active:
		lifetime = 0.11
	emitting = true

func _on_finished() -> void:
	queue_free() # Replace with function body.
