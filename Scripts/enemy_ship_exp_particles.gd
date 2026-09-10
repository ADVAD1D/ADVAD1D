extends GPUParticles2D

func _ready() -> void:
	emitting = false
	if GameManager.mobile_mode_active:
		lifetime = 0.4
		amount = 10
		
	# Waiting one frame allows Godot to reallocate memory (lifetime/amount)
	# without drawing the initial garbage data that causes giant particles.
	await get_tree().process_frame
	restart()
	emitting = true
		
func _on_finished() -> void:
	queue_free()
