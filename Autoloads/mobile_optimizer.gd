extends Node
## Autoload: MobileOptimizer
## Optimizes the game for Android/iOS by detecting the platform, enabling mobile mode,
## and capping the framerate to prevent thermal throttling and battery drain.

func _ready():
	# Detect if running on a mobile OS
	if OS.get_name() == "Android" or OS.get_name() == "iOS":
		# Automatically toggle the mobile controls on GameManager
		GameManager.mobile_mode_active = true
	
	apply_performance_settings()
	
	# Apply CRT Shader low-quality mode automatically if on mobile
	if GameManager.mobile_mode_active:
		get_tree().node_added.connect(_on_node_added)
		call_deferred("_apply_to_scene", get_tree().current_scene)

## Applies framerate and performance settings based on the current mobile mode
func apply_performance_settings():
	if GameManager.mobile_mode_active:
		# Limit to 60 FPS to stabilize physics/movement and save battery
		Engine.max_fps = 60
		# Turn off V-Sync (usually forced by Android anyway, but saves overhead)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		# Wake Lock: Prevent the screen from sleeping while playing
		DisplayServer.screen_set_keep_on(true)
		# Dynamically expand the viewport to fill Ultrawide screens without black bars
		get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	else:
		# 0 means unlimited FPS (or handled by Desktop V-Sync)
		Engine.max_fps = 0
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		# Allow desktop monitors to sleep normally
		DisplayServer.screen_set_keep_on(false)

func _on_node_added(node: Node) -> void:
	# A new top-level scene was added under the root (i.e. change_scene_*)
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
				# Flatten the curve and reduce black borders for mobile ultrawide screens
				(mat as ShaderMaterial).set_shader_parameter("warp_amount", false)
				(mat as ShaderMaterial).set_shader_parameter("vignette_intensity", 0.7)
				(mat as ShaderMaterial).set_shader_parameter("vignette_opacity", 0.4)
				
				# Extreme Mobile Optimizations: Cut heavy GPU branches
				(mat as ShaderMaterial).set_shader_parameter("roll", false) # Disables animated sine-wave screen rolling
				(mat as ShaderMaterial).set_shader_parameter("discolor", false) # Disables expensive greyscale/pow color math
				
				# If the user disabled the retro shader completely for performance, hide the node
				if not GameManager.retro_shader_active:
					if node is CanvasItem:
						node.visible = false
