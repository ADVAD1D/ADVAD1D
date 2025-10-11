extends Area2D

@export var target_scene_path: PackedScene
@export var fade_duration: float = 1.5

var main_scene_node: Node2D

func _ready() -> void:
	main_scene_node = get_tree().root.get_node("Main")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D):
	print("Body entered trigger: ", body.name)
	if body.is_in_group("player"):
		set_deferred("monitoring", false)
		call_deferred("set", "process_mode", PROCESS_MODE_DISABLED)
		print("¡Jugador detectado! Cambiando de escena a: ", target_scene_path)
		
		MusicPlayer.fade_out_and_stop(fade_duration)
		
		if main_scene_node and main_scene_node.has_method("fade_to_scene"):
			main_scene_node.fade_to_scene(target_scene_path)
