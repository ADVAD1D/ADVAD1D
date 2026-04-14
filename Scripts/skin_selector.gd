extends Control

var back_scene: String = "res://Scenes/main_menu.tscn"

@onready var back_button: TextureButton = $BackButton
@onready var right_button: TextureButton = $NextButton
@onready var ship_preview: TextureRect = $ShipPreview
@onready var left_button: TextureButton = $PreviousButton
@onready var ship_name_label: Label = $ShipNameLabel
@onready var ship_author_label: Label = $ShipAuthorLabel

@onready var button_sound: AudioStreamPlayer = $ButtonSound

@onready var name_line_edit: LineEdit = $NameLineEdit
@onready var submit_button: Button = $SubmitButton

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GameManager.can_pause = false
	back_button.pressed.connect(_on_back_button_pressed)
	left_button.pressed.connect(_on_left_button_pressed)
	right_button.pressed.connect(_on_right_button_pressed)
	GameManager.ship_selection_changed.connect(_on_ship_selection_changed)
	_on_ship_selection_changed(GameManager.get_selected_ship_data()) # Replace with function body.
	
	Network.name_check_completed.connect(_on_name_checked)
	Network.identity_recovered.connect(_on_identity_recovered)
	Network.check_my_identity()
	
func _on_identity_recovered(recovered_name: String):
	if recovered_name != "":
		GameManager.player_name = recovered_name
		_log_message("Identidad confirmada: " + recovered_name)

func _on_ship_selection_changed(ship_data: Dictionary):
	ship_preview.texture = ship_data["texture"]
	ship_name_label.text = ship_data["name"]
	ship_author_label.text = "By: " + ship_data["author"]
	
func _on_name_line_edit_text_submitted(new_text: String) -> void:
	_register_pilot(new_text) # Replace with function body.

func _on_submit_button_pressed() -> void:
	_register_pilot(name_line_edit.text) # Replace with function body.
	
func _register_pilot(entered_text: String):
	var final_name = entered_text.strip_edges()
	
	if final_name.is_empty():
		_log_message("The user name cant be empty")
		return
		
	submit_button.disabled = true
	_log_message(["Pilot registered in memory: ", final_name])
	Network.check_pilot_name(final_name)
	
func _input(event: InputEvent) -> void:
	if name_line_edit.has_focus():
		return
		
	if event.is_action_pressed("pause"):
		_on_back_button_pressed()
	elif event.is_action_pressed("Move_Left"):
		_on_left_button_pressed()
	elif event.is_action_pressed("Move_Right"):
		_on_right_button_pressed()
	
func _on_back_button_pressed():
	get_tree().change_scene_to_file(back_scene)
	
func _on_left_button_pressed():
	GameManager.select_previous_ship()
	button_sound.play()
	GameManager.save_data()
	
func _on_right_button_pressed():
	GameManager.select_next_ship()
	button_sound.play()
	GameManager.save_data()

func _on_back_button_mouse_entered() -> void:
	button_sound.play() # Replace with function body.
	
func _on_name_checked(is_available: bool, message: String):
	submit_button.disabled = false
	if is_available:
		GameManager.player_name = name_line_edit.text.strip_edges()
		name_line_edit.text = ""
		name_line_edit.placeholder_text = "NAME AVAILABLE!"
		_log_message("Authorization granted. Starting mission")
	else:
		_log_message(["The name is already taken", message])
		name_line_edit.text = ""
		name_line_edit.placeholder_text = "NAME TAKEN!"
	
func _log_message(message):
	if GameManager.is_debug_text == true:
		var final_string = ""
		if typeof(message) == TYPE_ARRAY:
			for arg in message:
				final_string += str(arg) + " "
			final_string = final_string.strip_edges()
		else:
			final_string = str(message)
		print_rich("[color=yellow][DEV LOG][/color] " + final_string)
	else:
		return
