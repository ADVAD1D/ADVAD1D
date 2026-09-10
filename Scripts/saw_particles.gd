extends GPUParticles2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	emitting = false
	if GameManager.mobile_mode_active:
		lifetime = 0.4
		
	# Waiting one frame allows Godot to reallocate memory 
	# without drawing initial garbage data that causes giant particles.
	await get_tree().process_frame
	restart()
	emitting = true

func _on_finished() -> void:
	queue_free() # Replace with function body.
