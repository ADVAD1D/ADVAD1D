extends Control

var back_scene: String = "res://Scenes/main_menu.tscn"
#references to child nodes

@onready var is_scroll_active: bool = GameManager.is_scroll_active

@onready var back_button: TextureButton = $BackButton
@onready var scroll_button: TextureButton = $ScrollBarButton
@onready var back_sound: AudioStreamPlayer = $BackSound
@onready var button_sound: AudioStreamPlayer = $ButtonSound
@onready var typing_sound: AudioStreamPlayer = $TypingSound

#box containers nodes
@onready var chat_display: RichTextLabel = $PanelContainer/MarginContainer/VBoxContainer/RichTextLabel
@onready var input_field: LineEdit = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/LineEdit
@onready var send_button: Button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/Button

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	send_button.pressed.connect(_on_send_button_pressed) # Replace with function body.
	input_field.text_submitted.connect(_on_text_submitted)
	scroll_button.toggled.connect(_on_scroll_button_toggled)
	scroll_button.pressed.connect(_on_scroll_button_pressed)
	
	GameManager.can_pause = false
	input_field.context_menu_enabled = true
	var v_scrollbar = chat_display.get_v_scroll_bar()
	v_scrollbar.modulate = Color.TRANSPARENT
	chat_display.scroll_following = is_scroll_active
	scroll_button.set_pressed_no_signal(is_scroll_active)
		
	chat_display.visible_characters = -1
	chat_display.add_theme_constant_override("line_separation", 6)
	
	back_button.modulate.a = 0.0
	scroll_button.modulate.a = 0.0
	
	if Network:
		Network.ai_response_received.connect(_on_ai_response)
		Network.request_failed.connect(_on_error)
	
	if GameManager.messages_sent >= GameManager.MAX_MESSAGES:
		input_field.editable = false
		send_button.disabled = true
		chat_display.visible_characters = -1
		add_message("System", "CHANNEL PREVIOUSLY CLOSED. LIMIT REACHED.", "red")
	else:
		add_message("Start System", "Server Status = ON. Type your request...", "gray")
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_on_back_button_pressed()
	
func _on_send_button_pressed():
	send_message()
	
func _on_text_submitted(_new_text):
	send_message()
	
func send_message():
	if GameManager.messages_sent >= GameManager.MAX_MESSAGES:
		return
	var text = input_field.text.strip_edges()
	if text.is_empty():
		return
		
	GameManager.messages_sent += 1
	
	input_field.clear()
	input_field.editable = false
	send_button.disabled = true
		
	await add_message("You ", text, "#40a4f4")
	await add_message("System ", "Waiting response...", "gray")
	
	Network.ask_godot_ai(text)
	
func _on_ai_response(response_text):
	var clean_text = format_ai_text(response_text)
	await add_message("AI ", clean_text, "#ffffff", true)
	
	if GameManager.messages_sent < GameManager.MAX_MESSAGES:
		input_field.editable = true
		send_button.disabled = false
		input_field.grab_focus()
	else:
		await add_message("System ", "TRANSMISSION LIMIT REACHED. CHANNEL CLOSED.", "red")
		input_field.editable = false
		send_button.disabled = true
	
func _on_error(error_msg):
	await add_message("Error ", error_msg, "red")
	if GameManager.messages_sent < GameManager.MAX_MESSAGES:
		input_field.editable = true
		send_button.disabled = false
	else:
		await add_message("System ", "TRANSMISSION LIMIT REACHED. CHANNEL CLOSED.", "red")
		input_field.editable = false
		send_button.disabled = true
	
func format_ai_text(text: String) -> String:
	var regex = RegEx.new()
	regex.compile("\\*\\*(.*?)\\*\\*")
	var result = regex.sub(text, "[b]$1[/b]", true)
	return result
	
func add_message(sender: String, message: String, color: String, animate: bool = false):
	var chars_before = chat_display.get_total_character_count()
	if chat_display.visible_characters == -1:
		chat_display.visible_characters = chars_before
	var formatted = "[b][color=%s]%s:[/color][/b] %s" % [color, sender, message]
	# Ejemplo: [b][color=red]Nombre:[/color][/b] mensaje
	chat_display.append_text(formatted + "\n")
	
	await get_tree().process_frame
	
	var chars_after = chat_display.get_total_character_count()
	
	if animate:
		chat_display.visible_characters = chars_before
		var new_msg_lenght = chars_after - chars_before
		var duration = new_msg_lenght * 0.03
		
		var tween = create_tween()
		tween.tween_property(chat_display, "visible_characters", chars_after, duration).from(chars_before)
		typing_sound.play()
		await tween.finished
		typing_sound.stop()
	chat_display.visible_characters = -1
	
func _on_scroll_button_toggled(button_pressed_state: bool):
	GameManager.is_scroll_active = button_pressed_state
	chat_display.scroll_following = button_pressed_state
	_log_message(["Estado de la barra de scroll", button_pressed_state])
	GameManager.save_data()
	
	if button_pressed_state == true:
		var v_scrollbar = chat_display.get_v_scroll_bar()
		v_scrollbar.value = v_scrollbar.max_value
		
func fade_button_visibility(button: TextureButton, make_visible: bool):
	var target_alpha = 1.0 if make_visible else 0.0
	var tween = create_tween()
	
	tween.tween_property(button, "modulate:a", target_alpha, 0.2).set_trans(Tween.TRANS_SINE)
		
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

	
func _on_scroll_button_pressed():
	button_sound.play()

func _on_back_button_pressed() -> void:
	get_tree().call_deferred("change_scene_to_file", back_scene) # Replace with function body.

func _on_back_button_mouse_entered() -> void:
	back_sound.play() # Replace with function body.
	fade_button_visibility(back_button, true)

func _on_button_mouse_entered() -> void:
	back_sound.play() # Replace with function body.

func _on_scroll_bar_button_mouse_entered() -> void:
	back_sound.play() # Replace with function body.
	fade_button_visibility(scroll_button, true)

func _on_scroll_bar_button_focus_entered() -> void:
	back_sound.play() # Replace with function body.
	fade_button_visibility(scroll_button, true)

func _on_back_button_focus_entered() -> void:
	back_sound.play() # Replace with function body.
	fade_button_visibility(back_button, true)

func _on_button_focus_entered() -> void:
	back_sound.play() # Replace with function body.

func _on_back_button_mouse_exited() -> void:
	fade_button_visibility(back_button, false) # Replace with function body.

func _on_back_button_focus_exited() -> void:
	fade_button_visibility(back_button, false) # Replace with function body.

func _on_scroll_bar_button_mouse_exited() -> void:
	fade_button_visibility(scroll_button, false) # Replace with function body.

func _on_scroll_bar_button_focus_exited() -> void:
	fade_button_visibility(scroll_button, false) # Replace with function body.
