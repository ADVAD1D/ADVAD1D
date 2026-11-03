class_name ArenaUiTint
extends ColorRect
# A ColorRect (hidden, transparent) and not a plain Control so shader_warmup.gd, which
# only ghosts drawable node types, compiles the tint shader during the splash.
## Drop this node into a UI (it tints everything under its parent): the UI takes the
## current arena's colour (GameManager.arena_ui_hue_shifts) through a hue rotation of every
## CanvasItem, including the ones added later (arcade HUD, floating labels...). Items that
## already have their own material are left alone. In arena 1 (shift 0) it does nothing.
## Its own material (ui_hue_shift.gdshader, set in the scene) is the one shared by the
## whole UI; keeping it in the scene lets the shader warm-up compile it during the splash.

var _root: Node
var _tint_material: ShaderMaterial


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root = get_parent()
	var shift: float = GameManager.get_arena_ui_hue_shift()
	_tint_material = material as ShaderMaterial
	if _root == null or _tint_material == null or is_zero_approx(shift):
		return
	_tint_material.set_shader_parameter("hue_shift_degrees", shift)
	_tint_tree(_root)
	get_tree().node_added.connect(_on_node_added)


func _tint_tree(node: Node) -> void:
	_tint(node)
	for child in node.get_children():
		_tint_tree(child)


func _tint(node: Node) -> void:
	var item: CanvasItem = node as CanvasItem
	if item and item.material == null:
		item.material = _tint_material


func _on_node_added(node: Node) -> void:
	if _root.is_ancestor_of(node):
		_tint(node)
