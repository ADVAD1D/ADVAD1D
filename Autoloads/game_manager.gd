extends Node

#signals 
signal score_updated(new_score)
signal pause(is_paused)
signal ship_selection_changed(new_ship_data)

#global variables
var score: int = 0
var can_add_score: bool = true
var phase_to_start: int = 1
var is_shader_animation: bool = false
var is_glitch_sound: bool = false
var game_paused: bool = false
var can_pause: bool = true

var browser_support: bool = false
var admin_control: bool = false

const save_path: String = "user://save_game.json"
#windows: %APPDATA%\Godot\app_userdata\ProjectName
#linux: ~/.local/share/godot/app_userdata/ProjectName/

#this dictionary defines ships data (name, author name, tetxure)
#this list start with index 0
var ship_data = [
	{
		"name": "ship1",
		"author": "ANGELUS11",
		"texture": preload("res://Assets/Sprites/Ship1.png")
	},
	
	{
		"name": "ship2",
		"author": "ANGELUS11",
		"texture": preload("res://Assets/Sprites/Ships/ship2.png")
	},
	
	{
		"name": "ship3",
		"author": "ANGELUS11",
		"texture": preload("res://Assets/Sprites/Ships/ship3.png")
	},
	
	{
		"name": "ship4",
		"author": "ANGELUS11",
		"texture": preload("res://Assets/Sprites/Ships/ship4.png")
	},
	
	{
		"name": "ship5",
		"author": "ANGELUS11",
		"texture": preload("res://Assets/Sprites/Ships/ship5.png")
	},
	
	{
		"name": "ship6",
		"author": "ANGELUS11",
		"texture": preload("res://Assets/Sprites/Ships/ship6.png")
	},
	
	{
		"name": "ship7",
		"author": "Tector9",
		"texture": preload("res://Assets/Sprites/Ships/ship7.png")
	},
	
	{
		"name": "ship8",
		"author": "ANGELUS11",
		"texture": preload("res://Assets/Sprites/Ships/ship8.png")
	},
	
	{
		"name": "ship9",
		"author": "ANGELUS11",
		"texture": preload("res://Assets/Sprites/Ships/ship9.png")
	},
	
	{
		"name": "ship10",
		"author": "ANGELUS11",
		"texture": preload("res://Assets/Sprites/Ships/ship10.png")
	},
	
	{
		"name": "ship11",
		"author": "ANGELUS11",
		"texture": preload("res://Assets/Sprites/Ships/ship11.png")
	},
	
	{
		"name": "ship12",
		"author": "ANGELUS11",
		"texture": preload("res://Assets/Sprites/Ships/ship12.png")
	},
	
	{
		"name": "ship13",
		"author": "ANGELUS11",
		"texture": preload("res://Assets/Sprites/Ships/ship13.png")
	},
	
	{
		"name": "ship14",
		"author": "ANGELUS11",
		"texture": preload("res://Assets/Sprites/Ships/ship14.png")
	},
	
	{
		"name": "ship15",
		"author": "ANGELUS11",
		"texture": preload("res://Assets/Sprites/Ships/ship15.png")
	},
	
	{
		"name": "ship16",
		"author": "ANGELUS11",
		"texture": preload("res://Assets/Sprites/Ships/ship16.png")
	},
	
	{
		"name": "ship17",
		"author": "ANGELUS11",
		"texture": preload("res://Assets/Sprites/Ships/ship17.png")
	},
	
	{
		"name": "ship18",
		"author": "ANGELUS11",
		"texture": preload("res://Assets/Sprites/Ships/ship18.png")
	},
	
	{
		"name": "ship19",
		"author": "Cro128",
		"texture": preload("res://Assets/Sprites/Ships/ship19.png")
	},
	
	{
		"name": "ship20",
		"author": "ANGELUS11",
		"texture": preload("res://Assets/Sprites/Ships/ship20.png")
	},
	
	{
		"name": "ship21",
		"author": "ANGELUS11",
		"texture": preload("res://Assets/Sprites/Ships/ship21.png")
	},
	
	{
		"name": "ship22",
		"author": "ANGELUS11",
		"texture": preload("res://Assets/Sprites/Ships/ship22.png")
	},
	
	{
		"name": "ship23",
		"author": "Odruu",
		"texture": preload("res://Assets/Sprites/Ships/ship23.png")
	},
	
	{
		"name": "ship24",
		"author": "Johnny224",
		"texture": preload("res://Assets/Sprites/Ships/ship24.png")
	},
	
	{
		"name": "ship25",
		"author": "ANGELUS11",
		"texture": preload("res://Assets/Sprites/Ships/ship25.png")
	},
	
	{
		"name": "ship26",
		"author": "ANGELUS11",
		"texture": preload("res://Assets/Sprites/Ships/ship26.png")
	},
	
	{
		"name": "ship27",
		"author": "ANGELUS11",
		"texture": preload("res://Assets/Sprites/Ships/ship27.png")
	},
	
	{
		"name": "ship28",
		"author": "Ringa Tech",
		"texture": preload("res://Assets/Sprites/Ships/ship28.png")
	}
]

var selected_ship_index: int = 0

func _ready() -> void:
	randomize()
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("web"):
		browser_support = true
	load_data()

func _process(_delta: float) -> void:
	pass
	
func save_data():
	if browser_support == true:
		print("Web version: using default values")
		return
		
	var data: Dictionary = {
		"selected_ship": selected_ship_index
	}
	#create the file in path
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	#convert the dict to json text
	var json_string = JSON.stringify(data)
	file.store_string(json_string)
	print("saved game!, selected skin", selected_ship_index)
	
func load_data():
	if browser_support == true:
		print("Web version: using default values")
		return
		
	if not FileAccess.file_exists(save_path):
		print("The save file not exists, using default values")
		return
		
	var file = FileAccess.open(save_path, FileAccess.READ)
	var json_string = file.get_as_text()
	var data = JSON.parse_string(json_string)
	
	if data and "selected_ship" in data:
		selected_ship_index = int(data["selected_ship"])
		print("Loaded data, selected ship", selected_ship_index)
	
func select_next_ship():
	selected_ship_index += 1
	
	if selected_ship_index >= ship_data.size():
		selected_ship_index = 0
		
	ship_selection_changed.emit(ship_data[selected_ship_index])
	
func select_previous_ship():
	selected_ship_index -= 1
	
	if selected_ship_index < 0:
		selected_ship_index = ship_data.size() - 1
		
	ship_selection_changed.emit(ship_data[selected_ship_index])
	
func get_selected_ship_data() -> Dictionary:
	return ship_data[selected_ship_index]
	
func get_selected_ship_texture() -> Texture2D:
	return ship_data[selected_ship_index]["texture"]

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and can_pause:
		toggle_pause()

func toggle_pause() -> void:
	get_tree().paused = !get_tree().paused
	pause.emit(get_tree().paused)
	
func add_score(points):
	score += points
	score_updated.emit(score)
	
func stop_scoring() -> void:
	can_add_score = false

func reset_score() -> void:
	score = 0
	can_add_score = true
	score_updated.emit(score)
	
func play_glitch_effect(crt_material):
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)

	tween.parallel().tween_property(crt_material, "shader_parameter/distort_intensity", 0.1, 0.1)
	tween.parallel().tween_property(crt_material, "shader_parameter/static_noise_intensity", 0.1, 0.1)

	tween.chain().tween_property(crt_material, "shader_parameter/aberration", 1.0, 0.1)
	tween.chain().tween_property(crt_material, "shader_parameter/aberration", -1.0, 0.1)
	tween.chain().tween_property(crt_material, "shader_parameter/aberration", 0.1, 0.01)
	
	tween.parallel().tween_property(crt_material, "shader_parameter/aberration", 0.01, 0.1)
	tween.parallel().tween_property(crt_material, "shader_parameter/distort_intensity", 0.01, 0.1)
	tween.parallel().tween_property(crt_material, "shader_parameter/static_noise_intensity", 0.01, 0.1)

	return tween
	
func play_glitch_sound(glitch_sound):
	glitch_sound.play()
	
func reset_game_state():
	print("Game Manager: Reseteando el estado del juego")
	phase_to_start = 1
	reset_score()
