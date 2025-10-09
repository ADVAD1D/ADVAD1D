extends Camera2D

@export var player_target: CharacterBody2D
@export var smoothness: float = 0.5


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.	
	
	
func shake(strength: float, duration: float):
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	tween.tween_property(self, "offset", Vector2(randf_range(-strength, strength), randf_range(-strength, strength)), duration * 0.1)
	tween.tween_property(self, "offset", Vector2(randf_range(-strength, strength), randf_range(-strength, strength)), duration * 0.1)
	tween.tween_property(self, "offset", Vector2(randf_range(-strength, strength), randf_range(-strength, strength)), duration * 0.1)
	tween.tween_property(self, "offset", Vector2.ZERO, duration * 0.4)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if is_instance_valid(player_target):
		global_position = global_position.lerp(player_target.global_position, smoothness)
