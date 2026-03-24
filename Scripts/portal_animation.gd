extends AnimatedSprite2D

func _ready() -> void:
	scale = Vector2.ZERO
	play() 
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(5, 5), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.1)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	tween.finished.connect(queue_free)
