extends Node

func update_crt_shader_quality(mat: ShaderMaterial) -> void:
	if not is_instance_valid(mat):
		return
		
	# High Quality Base Settings
	mat.set_shader_parameter("aberration", 0.02)
	mat.set_shader_parameter("distort_intensity", 0.02)
	mat.set_shader_parameter("static_noise_intensity", 0.01)

	if GameManager.mobile_mode_active or OS.has_feature("web") or GameManager.force_web_mode:
		# On Mobile, always apply the default optimization
		mat.set_shader_parameter("low_quality", true)
		mat.set_shader_parameter("roll", false)
	else:
		# On PC
		if GameManager.pc_optimize_shaders:
			# Player toggled optimization on: use base mobile optimization
			mat.set_shader_parameter("low_quality", true)
			mat.set_shader_parameter("roll", false)
		else:
			# Default / High Quality:
			mat.set_shader_parameter("low_quality", false)
			mat.set_shader_parameter("roll", true)

func _ready():
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_apply_to_scene", get_tree().current_scene)

func _on_node_added(node: Node) -> void:
	if node.get_parent() == get_tree().root:
		call_deferred("_apply_to_scene", node)

func _apply_to_scene(scene: Node) -> void:
	if not is_instance_valid(scene):
		return
	for node in scene.find_children("*", "CanvasItem", true, false):
		if node.material is ShaderMaterial:
			var mat = node.material as ShaderMaterial
			var shader = mat.shader
			if shader != null and shader.resource_path.contains("CRT"):
				update_crt_shader_quality(mat)
				
				# Hide completely on mobile if retro_shader_active is false
				if GameManager.mobile_mode_active and not GameManager.retro_shader_active:
					node.visible = false
				else:
					node.visible = true
