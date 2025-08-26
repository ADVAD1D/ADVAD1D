extends Area2D
signal hit

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("lasers"):
		hit.emit()
		area.queue_free()
