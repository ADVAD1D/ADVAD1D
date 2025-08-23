extends Node2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _on_death_zone_area_entered(area: Area2D) -> void:
	if area.is_in_group("asteroides"):
		area.queue_free()


func _on_laser_zone_area_entered(area: Area2D) -> void:
	if area.is_in_group("lasers"):
		area.queue_free() # Replace with function body.
