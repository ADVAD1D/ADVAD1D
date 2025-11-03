extends Node
signal score_updated(new_score)
signal pause(is_paused)
signal ship_selection_changed(new_ship_data)
var score: int = 0
var can_add_score: bool = true
var phase_to_start: int = 1
var is_shader_animation: bool = false
var is_glitch_sound: bool = false
var game_paused := false
var can_pause: bool = true

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
	}
]

var selected_ship_index: int = 0

func _ready() -> void:
	randomize()
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	pass
	
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
