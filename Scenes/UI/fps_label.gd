extends Label

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	var fps = GameManager.fps
	text = "FPS: " + str(fps)
