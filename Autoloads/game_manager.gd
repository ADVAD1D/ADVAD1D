extends Node

#signals
signal score_updated(new_score)
signal pause(is_paused)

#global variables
const MAX_MESSAGES: int = 5
var messages_sent: int = 0
var player_name: String
var player_name_field_editable: bool = false
var score: int = 0
var can_add_score: bool = true
var phase_to_start: int = 1

# Arenas Base Structure
var current_arena_index: int = 0
var arena_names: Array[String] = ["Arena 1", "Arena 2", "Arena 3"]
var is_shader_animation: bool = false
var is_glitch_sound: bool = false
var game_paused: bool = false
var can_pause: bool = true
var show_debug: bool = false
var show_fps: bool = false
var force_web_mode: bool = false
#IMPORTANT: this bool change the value to _log_message function in some scripts!
var is_debug_text : bool = false
var debug_response_text_active: bool = false
var ai_last_response: String = ""
var is_scroll_active: bool = false
var start_server: bool = true
var production_server_active = true
var browser_support: bool = false
var admin_control: bool = false
var relative_control_active: bool = false
#speedrun global variables
var speedrun_mode_active: bool = false
var is_speedrun_running: bool = false
var speedrun_time: float = 0.0

var fps: float = 0.0

const save_path: String = "user://save_game.json"
#windows: %APPDATA%\Godot\app_userdata\ProjectName
#linux: ~/.local/share/godot/app_userdata/ProjectName/

func _ready() -> void:
	randomize()
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("web"):
		browser_support = true
	if start_server == true:
		Network.wake_up_server()
	load_data()

func _process(delta: float) -> void:
	fps = Engine.get_frames_per_second()
	if speedrun_mode_active and is_speedrun_running:
		speedrun_time += delta
		
#speedrun functions
func start_speedrun():
	if speedrun_mode_active:
		is_speedrun_running = true
		
func stop_speedrun():
	is_speedrun_running = false
	
func reset_speedrun():
	speedrun_time = 0.0
	is_speedrun_running = false
	
func get_formatted_speedrun_time() -> String:
	@warning_ignore("integer_division")
	var minutes = int(speedrun_time) / 60
	var seconds = int(speedrun_time) % 60
	var milliseconds = int((speedrun_time - int(speedrun_time)) * 1000)
	return "%02d:%02d.%03d" % [minutes, seconds, milliseconds]
	
#save and load data functions
func save_data():
	var data: Dictionary
	if browser_support == true:
		_log_message("Web version: using default values")
		#only save player name in web version
		_log_message("Save ONLY player_name in web version")
		data = {
			"pilot_name": player_name
		}
		_log_message(["Player name: ", player_name])
	else:
		data = {
			"selected_ship": SkinManager.selected_ship_index,
			"controls_mode": relative_control_active,
			"fps_mode": show_fps,
			"speedrun_mode_state": speedrun_mode_active,
			"scroll_bar_state": is_scroll_active,
			"pilot_name": player_name
		}
		_log_message(["saved game!, selected skin", SkinManager.selected_ship_index])
		_log_message(["Relative controls: ", relative_control_active])
		_log_message(["FPS mode: ", show_fps])
		_log_message(["Speedrun mode state", speedrun_mode_active])
		_log_message(["Scroll bar state", is_scroll_active])
		
	#create the file in path
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		_log_message(["Error al guardar los datos", FileAccess.get_open_error()])
		return
	#convert the dict to json text
	var json_string = JSON.stringify(data)
	file.store_string(json_string)
	
func load_data():
	if not FileAccess.file_exists(save_path):
		_log_message("The save file not exists, using default values")
		return
		
	var file = FileAccess.open(save_path, FileAccess.READ)
	var json_string = file.get_as_text()
	var data = JSON.parse_string(json_string)
	
	if data and "selected_ship" in data:
		SkinManager.selected_ship_index = int(data["selected_ship"])
		_log_message(["Loaded data, selected ship", SkinManager.selected_ship_index])
		
	if data and "controls_mode" in data:
		relative_control_active = bool(data["controls_mode"])
		_log_message(["loaded controls user config: ", relative_control_active])
		
	if data and "fps_mode" in data:
		show_fps = bool(data["fps_mode"])
		_log_message(["loaded fps_mode user config: ", show_fps])
		
	if data and "scroll_bar_state" in data:
		is_scroll_active = bool(data["scroll_bar_state"])
		_log_message(["loaded scrollbar state user config: ", is_scroll_active])
		
	if data and "speedrun_mode_state" in data:
		speedrun_mode_active = bool(data["speedrun_mode_state"])
		_log_message(["loaded speedrun mode state user config: ", speedrun_mode_active])
		
	if data and "pilot_name" in data:
		player_name = String(data["pilot_name"])
		_log_message(["Loaded player name: ", player_name])

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
	
func _log_message(message):
	if is_debug_text == true:
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

#global shader animation (apply to scenes)
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
	_log_message("Game Manager: Restart Game State...")
	phase_to_start = 1
	reset_score()

var _transition_layer: CanvasLayer
var _transition_rect: TextureRect

func freeze_frame():
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	var tex = ImageTexture.create_from_image(img)
	
	if not is_instance_valid(_transition_layer):
		_transition_layer = CanvasLayer.new()
		_transition_layer.layer = 100
		add_child(_transition_layer)
		
		_transition_rect = TextureRect.new()
		_transition_layer.add_child(_transition_rect)
		
	_transition_rect.texture = tex
	_transition_layer.show()

func unfreeze_frame():
	if is_instance_valid(_transition_layer):
		_transition_layer.hide()
