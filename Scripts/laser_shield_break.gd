extends GPUParticles2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	emitting = true # Replace with function body.


func _on_finished() -> void:
	queue_free() # Replace with function body.
