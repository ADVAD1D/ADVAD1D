extends Control

@onready var show_fps: bool = GameManager.show_fps

@onready var objective_label: Label = $ObjectiveLabel
@onready var phase_label: Label = $PhaseLabel
@onready var fps_label: Label = $FPSContainer/FPSLabel
@onready var speedrun_label: Label = $SpeedrunLabel
@onready var mobile_controls_layer: CanvasLayer = $CanvasLayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if mobile_controls_layer:
		mobile_controls_layer.process_mode = Node.PROCESS_MODE_PAUSABLE
		
	var phase_manager = get_tree().root.get_node("Main/PhaseNode") # Replace with function body.
	fps_toggled()
	
	if not GameManager.mobile_mode_active:
		# Hide all virtual buttons and joysticks modularly
		for control in mobile_controls_layer.get_children():
			if control.has_method("hide"):
				control.hide()
	else:
		if not GameManager.using_touch_controls:
			for control in mobile_controls_layer.get_children():
				if control.has_method("hide"):
					control.hide()
		else:
			# Make all mobile controls semi-transparent so they don't block the player's view
			for control in mobile_controls_layer.get_children():
				if "modulate" in control:
					control.modulate.a = 0.5
				
				# Restore user's custom layout position
				var saved_pos = GameManager.get_mobile_layout(control.name)
				if saved_pos != Vector2.INF:
					if "global_position" in control:
						control.global_position = saved_pos
					elif "position" in control:
						control.position = saved_pos
	if not GameManager.speedrun_mode_active:
		speedrun_label.hide()
	else:
		speedrun_label.show()
	if phase_manager:
		phase_manager.phase_started.connect(_on_phase_started)
	else:
		print("Error, no se pudo encontrar el Phase Manager")
		
	if GameManager.mobile_mode_active:
		get_tree().root.size_changed.connect(_on_window_resized)
		_on_window_resized()

func _on_window_resized() -> void:
	var center_x = get_viewport().get_visible_rect().size.x / 2.0
	var center_y = get_viewport().get_visible_rect().size.y / 2.0
	
	# Restore original positions relative to center (Original 520x300 -> Center: 260x150)
	
	# PhaseLabel (Original X=251, Y=20 -> Offsets: X=-9, Y=-130)
	phase_label.anchor_left = 0.5
	phase_label.anchor_right = 0.5
	phase_label.anchor_top = 0.5
	phase_label.anchor_bottom = 0.5
	phase_label.position.x = center_x - 9.0
	phase_label.position.y = center_y - 130.0
	
	# ObjectiveLabel (Original X=249, Y=39 -> Offsets: X=-11, Y=-111)
	objective_label.anchor_left = 0.5
	objective_label.anchor_right = 0.5
	objective_label.anchor_top = 0.5
	objective_label.anchor_bottom = 0.5
	objective_label.position.x = center_x - 11.0
	objective_label.position.y = center_y - 111.0
	
	# SpeedrunLabel (Original X=268, Y=243 -> Offsets: X=+8, Y=+93)
	speedrun_label.anchor_left = 0.5
	speedrun_label.anchor_right = 0.5
	speedrun_label.anchor_top = 0.5
	speedrun_label.anchor_bottom = 0.5
	speedrun_label.position.x = center_x + 8.0
	speedrun_label.position.y = center_y + 93.0

func _on_phase_started(_phase_number: int, score_requirement: int):
	objective_label.text = "> " + str(score_requirement)

var dragged_node: Node = null
var drag_offset: Vector2 = Vector2.ZERO

func _input(event: InputEvent) -> void:
	if GameManager.mobile_mode_active and mobile_controls_layer:
		if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
			if not GameManager.disable_auto_hide_mobile_controls:
				GameManager.using_touch_controls = false
				mobile_controls_layer.hide()
		elif event is InputEventScreenTouch or event is InputEventScreenDrag:
			GameManager.using_touch_controls = true
			mobile_controls_layer.show()
			
		# Layout dragging logic during pause
		if get_tree().paused and mobile_controls_layer.visible:
			if event is InputEventScreenTouch:
				if event.pressed:
					for control in mobile_controls_layer.get_children():
						if _is_point_inside(control, event.position):
							dragged_node = control
							var node_pos = control.global_position if "global_position" in control else control.position
							drag_offset = node_pos - event.position
							get_viewport().set_input_as_handled()
							break
				else:
					if dragged_node != null:
						var final_pos = dragged_node.global_position if "global_position" in dragged_node else dragged_node.position
						GameManager.save_mobile_layout(dragged_node.name, final_pos)
						GameManager.save_data() # Persist to disk immediately
					dragged_node = null
					
			elif event is InputEventScreenDrag and dragged_node != null:
				if "global_position" in dragged_node:
					dragged_node.global_position = event.position + drag_offset
				elif "position" in dragged_node:
					dragged_node.position = event.position + drag_offset
				get_viewport().set_input_as_handled()

func _is_point_inside(node: Node, point: Vector2) -> bool:
	if node is Control:
		var rect = Rect2(node.global_position, node.size * node.scale)
		return rect.has_point(point)
	elif node.is_class("TouchScreenButton"):
		if node.texture_normal:
			var rect = Rect2(node.global_position, node.texture_normal.get_size() * node.global_scale)
			return rect.has_point(point)
	return false

func _process(_delta: float) -> void:
	if GameManager.speedrun_mode_active:
		speedrun_label.text = GameManager.get_formatted_speedrun_time()
		
func fps_toggled():
	if show_fps == false:
		fps_label.hide()
	else:
		return
