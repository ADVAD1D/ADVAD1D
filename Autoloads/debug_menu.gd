extends Node
## Central debug autoload. Toggled with the "debug" action (Tab).
## Draws hitboxes/raycasts/collision points in world space and a text panel
## with fps, ticks, phases, velocities and watched/tracked variables.
## Keeps GameManager.show_debug in sync so existing _draw() code still works.

# --- Config ---

const TOGGLE_ACTION: String = "debug"

# Groups whose CollisionShape2D we draw, and their color.
const SHAPE_GROUPS: Dictionary = {
	"player": Color(0.2, 1.0, 0.4),
	"player_shield": Color(0.6, 0.9, 1.0),
	"enemies": Color(1.0, 0.3, 0.3),
	"asteroids": Color(1.0, 0.7, 0.2),
	"colisiones": Color(0.4, 0.6, 1.0),
	"lasers": Color(0.3, 1.0, 1.0),
	"enemy_laser": Color(1.0, 0.4, 0.8),
	"saws": Color(1.0, 1.0, 0.3),
	"destructibles": Color(0.8, 0.5, 1.0),
}

# Default lifetime (s) for transient rays/points.
const DEFAULT_TTL: float = 0.5

# --- State ---

# Master switch: set to false to fully disable the menu (Tab does nothing).
var enabled: bool = false

# Runtime toggle state: whether the overlay is currently shown.
var _shown: bool = false

# Live-watched properties: {node, property, label}. Read every frame.
var _watches: Array = []

# Loose values pushed via track(): {label: value}.
var _tracked: Dictionary = {}

# Rays to draw: {from, to, hit, ttl}. Auto-expire by ttl.
var _rays: Array = []

# Collision points to draw: {pos, color, ttl}. Auto-expire by ttl.
var _points: Array = []

# Runtime-built nodes (no scene needed).
var _world: Node2D          # world-space layer (respects the camera)
var _overlay: CanvasLayer   # screen-space layer for the text panel
var _label: Label
var _audio_label: Label
var _network_label: Label

# --- Lifecycle ---

func _ready() -> void:
	# Debug-build only. In release stay inert: no layers, no process, no input.
	if not OS.is_debug_build():
		set_process(false)
		set_process_unhandled_input(false)
		return

	# Keep running while the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_world_layer()
	_build_overlay()
	_apply_shown(false)

func _unhandled_input(event: InputEvent) -> void:
	# Master switch off -> ignore Tab entirely.
	if not enabled:
		return
	# _unhandled_input so normal UI can consume Tab first.
	if event.is_action_pressed(TOGGLE_ACTION):
		toggle()

func _process(delta: float) -> void:
	# Expire even while hidden so lists don't pile up.
	_expire(_rays, delta)
	_expire(_points, delta)
	# Master switch off -> force-close and stop updating (checked live).
	if not enabled:
		if _shown:
			_apply_shown(false)
		return
	if not _shown:
		return
	_update_overlay_text()
	_world.queue_redraw()

# --- Public API ---

func toggle() -> void:
	if not enabled:
		return
	_apply_shown(not _shown)

func set_shown(value: bool) -> void:
	_apply_shown(value)

# Watch a node property, shown live every frame.
# Ex: DebugMenu.watch(self, "velocity", "Player vel")
func watch(node: Node, property: String, label: String = "") -> void:
	if label == "":
		label = "%s.%s" % [node.name, property]
	_watches.append({"node": node, "property": property, "label": label})

# Push a one-off value; caller refreshes it (usually from its _process).
func track(label: String, value) -> void:
	_tracked[label] = value

func untrack(label: String) -> void:
	_tracked.erase(label)

# Register a ray, drawn for a few frames (e.g. the enemy laser wall check).
func register_ray(from: Vector2, to: Vector2, hit: Vector2 = Vector2.INF, ttl: float = DEFAULT_TTL) -> void:
	if not _shown:
		return
	_rays.append({"from": from, "to": to, "hit": hit, "ttl": ttl})

# Register a collision point, drawn for a few frames.
func register_point(pos: Vector2, color: Color = Color.MAGENTA, ttl: float = DEFAULT_TTL) -> void:
	if not _shown:
		return
	_points.append({"pos": pos, "color": color, "ttl": ttl})

# --- Layer setup ---

func _build_world_layer() -> void:
	# Node2D child of the autoload: shares the root viewport, so the active
	# camera transforms its drawing like the rest of the world.
	_world = _WorldDrawer.new()
	_world.owner_menu = self
	add_child(_world)

func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 128  # above the HUD
	add_child(_overlay)

	var hbox = HBoxContainer.new()
	hbox.position = Vector2(8, 8)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 20)
	_overlay.add_child(hbox)

	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Reuse the shared pixel style (see FontManager).
	_label.label_settings = FontManager.pixel_label_settings(11)
	hbox.add_child(_label)

	_audio_label = Label.new()
	_audio_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_audio_label.label_settings = FontManager.pixel_label_settings(11)
	hbox.add_child(_audio_label)

	_network_label = Label.new()
	_network_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_network_label.label_settings = FontManager.pixel_label_settings(11)
	hbox.add_child(_network_label)

func _apply_shown(value: bool) -> void:
	# No layers built (release/disabled) -> nothing to toggle.
	if _overlay == null:
		return
	_shown = value
	# Compat: lights up existing _draw() (player, ship_enemy, ...).
	GameManager.show_debug = value
	_overlay.visible = value
	_world.visible = value
	if value:
		_world.queue_redraw()

# --- Text panel ---

func _update_overlay_text() -> void:
	var tree: SceneTree = get_tree()
	var fps: float = Engine.get_frames_per_second()
	var lines: PackedStringArray = []

	lines.append("== DEBUG (Tab) ==")
	lines.append("FPS: %d" % fps)
	lines.append("Frame: %.2f ms" % (1000.0 / max(fps, 1.0)))
	lines.append("Physics tick: %d Hz" % Engine.physics_ticks_per_second)
	lines.append("Physics frames: %d" % Engine.get_physics_frames())
	lines.append("Process frames: %d" % Engine.get_process_frames())
	lines.append("Nodes: %d" % tree.get_node_count())
	if tree.current_scene:
		lines.append("Scene: %s" % tree.current_scene.name)
	lines.append("Paused: %s" % str(tree.paused))
	lines.append("Controls: %s" % ("Relative" if GameManager.relative_control_active else "Global"))

	# Player velocity (auto, via group).
	var players: Array = tree.get_nodes_in_group("player")
	if not players.is_empty() and players[0] is CharacterBody2D:
		var v: Vector2 = players[0].velocity
		lines.append("Player vel: %.0f  (%.0f, %.0f)" % [v.length(), v.x, v.y])

	# Quick per-group counts (mapped to English display names).
	lines.append("--- counts ---")
	var count_groups = {
		"enemigos": "enemies",
		"asteroides": "asteroids",
		"enemy_laser": "enemy_lasers",
		"lasers": "player_lasers",
		"saws": "saws"
	}
	for group_id in count_groups:
		lines.append("%s: %d" % [count_groups[group_id], tree.get_nodes_in_group(group_id).size()])

	# Watched properties.
	if not _watches.is_empty():
		lines.append("--- watches ---")
		for w in _watches:
			if is_instance_valid(w.node):
				lines.append("%s: %s" % [w.label, str(w.node.get(w.property))])

	# Tracked values.
	if not _tracked.is_empty():
		lines.append("--- tracked ---")
		for key in _tracked:
			lines.append("%s: %s" % [key, str(_tracked[key])])

	var audio_lines: PackedStringArray = []
	audio_lines.append("== AUDIO ==")
	if get_tree().root.has_node("MusicPlayer"):
		var music_player = get_node("/root/MusicPlayer")
		audio_lines.append("Music Vol: %.1f%% (%.2f dB)" % [music_player.get_volume_percent(), music_player.volume_db])
	if get_tree().root.has_node("SfxManager"):
		var sfx_manager = get_node("/root/SfxManager")
		audio_lines.append("SFX Vol: %.1f%% (%.2f dB)" % [sfx_manager.get_sfx_volume_percent(), AudioServer.get_bus_volume_db(sfx_manager.sfx_bus_index)])

	# Network Status
	var network_lines: PackedStringArray = []
	network_lines.append("== NETWORK ==")
	if get_tree().root.has_node("Network"):
		var net = get_node("/root/Network")
		network_lines.append("URL: %s" % net.BASE_URL)
		network_lines.append("Online: %s" % str(net.server_online))
		network_lines.append("Log: %s" % net.last_network_log)

	_label.text = "\n".join(lines)
	_audio_label.text = "\n".join(audio_lines)
	_network_label.text = "\n".join(network_lines)

# --- World drawing (called by _WorldDrawer._draw) ---

func _draw_world(c: CanvasItem) -> void:
	# 1) Hitboxes / CollisionShapes per group.
	for group in SHAPE_GROUPS:
		var color: Color = SHAPE_GROUPS[group]
		for node in get_tree().get_nodes_in_group(group):
			_draw_node_shapes(c, node, color)

	# 2) Rays.
	for ray in _rays:
		c.draw_line(ray.from, ray.to, Color.YELLOW, 1.5)
		if ray.hit != Vector2.INF:
			c.draw_circle(ray.hit, 4.0, Color.RED)

	# 3) Collision points.
	for p in _points:
		c.draw_circle(p.pos, 4.0, p.color)

func _draw_node_shapes(c: CanvasItem, node: Node, color: Color) -> void:
	for shape_node in _collision_shapes(node):
		if shape_node is CollisionShape2D and shape_node.shape:
			var col: Color = color
			col.a = 0.35 if shape_node.disabled else 0.9  # dim disabled shapes
			var xf: Transform2D = shape_node.global_transform
			c.draw_set_transform(xf.origin, xf.get_rotation(), xf.get_scale())
			_draw_shape(c, shape_node.shape, col)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)  # reset

func _draw_shape(c: CanvasItem, shape: Shape2D, color: Color) -> void:
	if shape is CircleShape2D:
		c.draw_arc(Vector2.ZERO, shape.radius, 0.0, TAU, 32, color, 2.0)
	elif shape is RectangleShape2D:
		c.draw_rect(Rect2(-shape.size / 2.0, shape.size), color, false, 2.0)
	elif shape is CapsuleShape2D:
		# Central segments + two end arcs.
		var r: float = shape.radius
		var h: float = shape.height / 2.0 - r
		c.draw_line(Vector2(-r, -h), Vector2(-r, h), color, 2.0)
		c.draw_line(Vector2(r, -h), Vector2(r, h), color, 2.0)
		c.draw_arc(Vector2(0, -h), r, PI, TAU, 16, color, 2.0)
		c.draw_arc(Vector2(0, h), r, 0.0, PI, 16, color, 2.0)
	elif shape is SegmentShape2D:
		c.draw_line(shape.a, shape.b, color, 2.0)

# Recursively collect CollisionShape2D/Polygon2D under a node (incl. nested
# Area2D like the player's Hitbox).
func _collision_shapes(node: Node) -> Array:
	var out: Array = []
	for child in node.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			out.append(child)
		if child.get_child_count() > 0:
			out.append_array(_collision_shapes(child))
	return out

# --- Util ---

func _expire(arr: Array, delta: float) -> void:
	var i: int = arr.size() - 1
	while i >= 0:
		arr[i].ttl -= delta
		if arr[i].ttl <= 0.0:
			arr.remove_at(i)
		i -= 1

# --- World drawer node ---

# Internal Node2D whose only job is to delegate _draw() to the autoload.
class _WorldDrawer extends Node2D:
	var owner_menu: Node

	func _draw() -> void:
		if owner_menu != null:
			owner_menu._draw_world(self)
