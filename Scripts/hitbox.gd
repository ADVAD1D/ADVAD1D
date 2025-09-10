extends Area2D
signal hit(area_collided: Area2D)

func _on_area_entered(area: Area2D) -> void:
	if (area.is_in_group("lasers") or area.is_in_group("enemies_death")):
		hit.emit(area)
