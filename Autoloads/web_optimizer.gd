extends Node
## On desktop this autoload removes itself immediately (zero overhead)
## On web it switches every CRT ShaderMaterial in the current scene to its
## cheap "low_quality" path (see Shaders/CRT.gdshader), so menus and gameplay
## drop the expensive warp / chromatic-aberration / animated-noise passes
## without having to edit each of the ~9 scenes by hand

func _ready() -> void:
	if not OS.has_feature("web"):
		# Desktop / native: nothing to do, don't pay for the node_added signal
		queue_free()
		return

	# Apply to whatever is already loaded, then re-apply on every scene change
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_apply_to_scene", get_tree().current_scene)

func _on_node_added(node: Node) -> void:
	# A new top-level scene was added under the root (i.e. change_scene_*)
	# Defer so its children exist before we scan
	if node.get_parent() == get_tree().root:
		call_deferred("_apply_to_scene", node)

func _apply_to_scene(scene: Node) -> void:
	if not is_instance_valid(scene):
		return
	for node in scene.find_children("*", "CanvasItem", true, false):
		var mat: Material = node.material
		if mat is ShaderMaterial:
			var shader: Shader = (mat as ShaderMaterial).shader
			if shader != null and shader.resource_path.contains("CRT"):
				(mat as ShaderMaterial).set_shader_parameter("low_quality", true)
