extends Node
## Shader warm-up, started once by GameManager at boot (while the splash is on screen).
##
## The renderer compiles each shader the first time something that uses it is drawn.
## On low-end GPUs that takes long enough that entering an arena (new materials, particle
## trails, portals, pickups...) blocks a single frame for seconds and Windows flags the
## game as "not responding".
##
## This node reads the given PackedScenes WITHOUT instantiating them (SceneState), so no
## gameplay script runs, builds one script-less "ghost" per unique drawable/material and
## draws them for a couple of frames in an offscreen viewport, a few at a time. The compilation
## cost is paid here, spread over many frames, instead of all at once in the scene change.

signal finished

const GHOST_TYPES: Array[StringName] = [
	&"Sprite2D", &"AnimatedSprite2D", &"GPUParticles2D", &"CPUParticles2D",
	&"Line2D", &"Polygon2D", &"ColorRect", &"TextureRect", &"NinePatchRect",
	&"TextureButton", &"TextureProgressBar", &"Label",
]

# Scene properties that must not be copied to a ghost (logic, layout and visibility).
const SKIPPED_PROPERTIES: Array[StringName] = [
	&"script", &"position", &"rotation", &"scale", &"skew", &"transform",
	&"visible", &"modulate", &"z_index", &"z_as_relative", &"top_level",
	&"process_mode", &"light_mask", &"unique_name_in_owner",
	&"layout_mode", &"anchors_preset", &"anchor_left", &"anchor_top",
	&"anchor_right", &"anchor_bottom", &"offset_left", &"offset_top",
	&"offset_right", &"offset_bottom", &"grow_horizontal", &"grow_vertical",
	&"size", &"custom_minimum_size", &"pivot_offset",
	&"emitting", &"one_shot", &"preprocess", &"autoplay",
]

const VIEWPORT_SIZE: int = 128
const FRAMES_PER_BATCH: int = 2
const MAX_BATCH: int = 4
# If a batch took longer than this, something was really compiled: go back to one at a time.
const SLOW_BATCH_MSEC: int = 100

var _visited_scenes: Dictionary = {}
var _seen_keys: Dictionary = {}
var _ghosts: Array[CanvasItem] = []
var _holder: Node2D
var _light: PointLight2D

## Must be called after this node is inside the tree. Emits `finished` and frees itself.
func run(scenes: Array) -> void:
	# The headless renderer has nothing to compile
	if DisplayServer.get_name() == "headless":
		_finish()
		return

	process_mode = Node.PROCESS_MODE_ALWAYS

	# The ghosts are rendered into an offscreen viewport that is never shown anywhere,
	# so nothing of this can reach the screen (particles ignore parent scale/modulate tricks)
	var viewport = SubViewport.new()
	viewport.size = Vector2i(VIEWPORT_SIZE, VIEWPORT_SIZE)
	viewport.disable_3d = true
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var center: Vector2 = Vector2(VIEWPORT_SIZE, VIEWPORT_SIZE) / 2.0

	_holder = Node2D.new()
	_holder.position = center
	viewport.add_child(_holder)

	# Lit and unlit items can use different shader variants, so the ghosts are drawn both ways
	_light = PointLight2D.new()
	var light_texture = GradientTexture2D.new()
	light_texture.width = VIEWPORT_SIZE
	light_texture.height = VIEWPORT_SIZE
	_light.texture = light_texture
	_light.position = center
	_light.enabled = false
	viewport.add_child(_light)

	for scene in scenes:
		_collect(scene)

	await _draw_ghosts()
	_light.enabled = true
	await _draw_ghosts()
	_finish()

func _finish() -> void:
	finished.emit()
	queue_free()

## Walks a scene (and every scene it instances or references) looking for drawables.
func _collect(scene: PackedScene) -> void:
	if scene == null or _visited_scenes.has(scene):
		return
	_visited_scenes[scene] = true

	var state: SceneState = scene.get_state()
	while state != null:
		for node_idx in state.get_node_count():
			_collect(state.get_node_instance(node_idx))

			var properties: Dictionary = {}
			for prop_idx in state.get_node_property_count(node_idx):
				var value = state.get_node_property_value(node_idx, prop_idx)
				# Spawners keep what they spawn in exported PackedScene properties
				if value is PackedScene:
					_collect(value)
				elif value is Array:
					for item in value:
						if item is PackedScene:
							_collect(item)
				else:
					properties[state.get_node_property_name(node_idx, prop_idx)] = value

			_add_ghost(state.get_node_type(node_idx), properties)
		state = state.get_base_scene_state()

func _add_ghost(type: StringName, properties: Dictionary) -> void:
	if not GHOST_TYPES.has(type):
		return

	# One ghost per node type + shader (+ particle process material) is enough
	var material = properties.get(&"material")
	if material is ShaderMaterial:
		material = material.shader
	var key: String = "%s|%d|%d" % [type, _resource_id(material), _resource_id(properties.get(&"process_material"))]
	if _seen_keys.has(key):
		return
	_seen_keys[key] = true

	var ghost = ClassDB.instantiate(type)
	if not ghost is CanvasItem:
		return

	for property in properties:
		if SKIPPED_PROPERTIES.has(property) or String(property).begins_with("metadata/"):
			continue
		var value = properties[property]
		if value is NodePath or value is Callable or value is Signal:
			continue
		ghost.set(property, value)

	if ghost is Control:
		ghost.size = Vector2(64, 64)
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ghost.focus_mode = Control.FOCUS_NONE
	elif ghost is GPUParticles2D or ghost is CPUParticles2D:
		ghost.one_shot = false
		ghost.emitting = true

	ghost.visible = false
	_holder.add_child(ghost)
	_ghosts.append(ghost)

func _resource_id(resource) -> int:
	if resource is Object:
		return resource.get_instance_id()
	return 0

## Shows the ghosts for a couple of frames each. Starts one at a time and only groups
## them while the frames stay fast (meaning those shaders were already compiled/cached).
func _draw_ghosts() -> void:
	var batch_size: int = 1
	var index: int = 0
	while index < _ghosts.size():
		var batch: Array = _ghosts.slice(index, index + batch_size)
		index += batch.size()

		var start_msec: int = Time.get_ticks_msec()
		for ghost in batch:
			ghost.show()
		for i in FRAMES_PER_BATCH:
			await get_tree().process_frame
		for ghost in batch:
			ghost.hide()

		if Time.get_ticks_msec() - start_msec > SLOW_BATCH_MSEC:
			batch_size = 1
		else:
			batch_size = mini(batch_size * 2, MAX_BATCH)
