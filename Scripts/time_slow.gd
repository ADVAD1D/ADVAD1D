extends Node2D
## Power-up logic: Slows down time and turns screen grayscale.

@export var slow_duration: float = 3.0
@export var slow_factor: float = 0.4

func _ready() -> void:
	add_to_group("time_slow_effect")
	Engine.time_scale = slow_factor
	
	# Pitch shift audio
	var master_bus = AudioServer.get_bus_index("Master")
	var pitch_idx = _get_or_add_pitch_effect(master_bus)
	if pitch_idx != -1:
		AudioServer.get_bus_effect(master_bus, pitch_idx).pitch_scale = slow_factor
	
	var main_scene = get_tree().current_scene
	var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	
	# Grayscale background
	if main_scene:
		var bg = main_scene.get_node_or_null("Sprite2D")
		if bg and bg.material:
			tween.tween_property(bg.material, "shader_parameter/grayscale_amount", 1.0, 0.5)
			
	# Darken enemies and asteroids to simulate B&W without melting mobile GPUs
	var groups_to_darken = ["asteroides", "enemigos", "enemy_laser", "saws"]
	for g in groups_to_darken:
		for node in get_tree().get_nodes_in_group(g):
			if node is CanvasItem:
				tween.parallel().tween_property(node, "modulate", Color(0.2, 0.2, 0.2), 0.5)
	
	# Wait for duration (ignoring time_scale)
	await get_tree().create_timer(slow_duration, false, false, true).timeout
	
	Engine.time_scale = 1.0
	if pitch_idx != -1:
		AudioServer.get_bus_effect(master_bus, pitch_idx).pitch_scale = 1.0
	
	if not is_instance_valid(main_scene):
		queue_free()
		return
		
	var revert_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var bg = main_scene.get_node_or_null("Sprite2D")
	if bg and bg.material:
		revert_tween.tween_property(bg.material, "shader_parameter/grayscale_amount", 0.0, 0.5)
		
	for g in groups_to_darken:
		for node in get_tree().get_nodes_in_group(g):
			if is_instance_valid(node) and node is CanvasItem:
				revert_tween.parallel().tween_property(node, "modulate", Color.WHITE, 0.5)
				
	await revert_tween.finished
	queue_free()

func _get_or_add_pitch_effect(bus_idx: int) -> int:
	for i in range(AudioServer.get_bus_effect_count(bus_idx)):
		if AudioServer.get_bus_effect(bus_idx, i) is AudioEffectPitchShift:
			return i
	var effect = AudioEffectPitchShift.new()
	AudioServer.add_bus_effect(bus_idx, effect)
	return AudioServer.get_bus_effect_count(bus_idx) - 1
