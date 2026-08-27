extends GPUParticles2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if GameManager.mobile_mode_active or OS.has_feature("web") or GameManager.force_web_mode:
		lifetime = 0.11
	emitting = true # Replace with function body.

func _on_finished() -> void:
	queue_free() # Replace with function body.
