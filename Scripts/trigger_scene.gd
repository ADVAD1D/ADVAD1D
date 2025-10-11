extends Area2D

# En el Inspector, podrás escribir la ruta a la escena que quieres cargar.
@export var target_scene_path: PackedScene

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D):
	print("Body entered trigger: ", body.name)
	if body.is_in_group("player"):
		print("¡Jugador detectado! Cambiando de escena a: ", target_scene_path)
		
		if target_scene_path:
			get_tree().call_deferred("change_scene_to_packed", target_scene_path)
		else:
			print("Error, no se asignó una escena de destino")
