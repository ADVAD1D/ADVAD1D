extends AudioStreamPlayer2D

func _ready() -> void:
	play()
	finished.connect(queue_free)


func _on_finished() -> void:
	pass # Replace with function body.
