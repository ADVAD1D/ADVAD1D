extends Sprite2D

func _ready() -> void:
	# 1. Haces el sprite invisible. "self.modulate" es lo mismo que solo "modulate".
	modulate.a = 0.0
	
	# 2. Creas el tween.
	var tween = create_tween()#
	
	# 3. Le dices que anime la propiedad "modulate:a" de "self" (este mismo nodo).
	tween.tween_property(self, "modulate:a", 1.0, 2.0)
