extends Control

@onready var show_fps: bool = GameManager.show_fps

@onready var objective_label: Label = $ObjectiveLabel
@onready var phase_label: Label = $PhaseLabel
@onready var fps_label: Label = $FPSContainer/FPSLabel
@onready var speedrun_label: Label = $SpeedrunLabel
@onready var mobile_controls_layer: CanvasLayer = $CanvasLayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
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

func _input(event: InputEvent) -> void:
	if GameManager.mobile_mode_active and mobile_controls_layer:
		if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
			GameManager.using_touch_controls = false
			mobile_controls_layer.hide()
		elif event is InputEventScreenTouch or event is InputEventScreenDrag:
			GameManager.using_touch_controls = true
			mobile_controls_layer.show()

func _process(_delta: float) -> void:
	if GameManager.speedrun_mode_active:
		speedrun_label.text = GameManager.get_formatted_speedrun_time()
		
func fps_toggled():
	if show_fps == false:
		fps_label.hide()
	else:
		return
