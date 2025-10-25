extends Control

var back_scene: String = "res://Scenes/main_menu.tscn"

@onready var back_button: TextureButton = $BackButton
@onready var right_button: TextureButton = $NextButton
@onready var ship_preview: TextureRect = $ShipPreview
@onready var left_button: TextureButton = $PreviousButton
@onready var ship_name_label: Label = $ShipNameLabel
@onready var ship_author_label: Label = $ShipAuthorLabel

@onready var button_sound: AudioStreamPlayer = $ButtonSound

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	back_button.pressed.connect(_on_back_button_pressed)
	left_button.pressed.connect(_on_left_button_pressed)
	right_button.pressed.connect(_on_right_button_pressed)
	GameManager.ship_selection_changed.connect(_on_ship_selection_changed)
	_on_ship_selection_changed(GameManager.get_selected_ship_data()) # Replace with function body.

func _on_ship_selection_changed(ship_data: Dictionary):
	ship_preview.texture = ship_data["texture"]
	ship_name_label.text = ship_data["name"]
	ship_author_label.text = "By: " + ship_data["author"]
	
func _input(event: InputEvent) -> void:
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
	
func _on_right_button_pressed():
	GameManager.select_next_ship()
	button_sound.play()

func _on_back_button_mouse_entered() -> void:
	button_sound.play() # Replace with function body.
