extends Control

var back_scene: String = "res://Scenes/main_menu.tscn"
#references to child nodes

var current_text_lenght: int = 0

@onready var is_scroll_active: bool = GameManager.is_scroll_active

@onready var back_button: TextureButton = $BackButton
@onready var scroll_button: TextureButton = $ScrollBarButton
@onready var back_sound: AudioStreamPlayer = $BackSound
@onready var button_sound: AudioStreamPlayer = $ButtonSound
@onready var typing_sound: AudioStreamPlayer = $TypingSound

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
	var v_scrollbar = chat_display.get_v_scroll_bar()
	v_scrollbar.modulate = Color.TRANSPARENT
	chat_display.scroll_following = is_scroll_active
	scroll_button.set_pressed_no_signal(is_scroll_active)
		
	chat_display.visible_characters = -1
	chat_display.add_theme_constant_override("line_separation", 6)
	
	if Network:
		Network.ai_response_received.connect(_on_ai_response)
		Network.request_failed.connect(_on_error)
	add_message("Start System", "Server Status = ON. Type your request...", "gray")
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_on_back_button_pressed()
	
func _on_send_button_pressed():
	send_message()
	
func _on_text_submitted(_new_text):
	send_message()
	
func send_message():
	var text = input_field.text.strip_edges()
	
	if text.is_empty():
		return
		
	add_message("You ", text, "#40a4f4")
	input_field.clear()
	input_field.editable = false
	send_button.disabled = true
	add_message("System ", "Waiting response...", "gray")
	
	Network.ask_godot_ai(text)
	
func _on_ai_response(response_text):
	var clean_text = format_ai_text(response_text)
	add_message("AI ", clean_text, "#ffffff", true)
	
	input_field.editable = true
	send_button.disabled = false
	input_field.grab_focus()
	
func _on_error(error_msg):
	add_message("Error ", error_msg, "red")
	input_field.editable = true
	send_button.disabled = false
	
func format_ai_text(text: String) -> String:
	var regex = RegEx.new()
	regex.compile("\\*\\*(.*?)\\*\\*")
	var result = regex.sub(text, "[b]$1[/b]", true)
	return result
	
func add_message(sender: String, message: String, color: String, animate: bool = false):
	var formatted = "[b][color=%s]%s:[/color][/b] %s" % [color, sender, message]
	# Ejemplo: [b][color=red]Nombre:[/color][/b] mensaje
	chat_display.append_text(formatted + "\n")
	
	var new_total_chars = chat_display.get_total_character_count()
	
	if animate:
		chat_display.visible_characters = current_text_lenght
		var new_msg_lenght = new_total_chars - current_text_lenght
		var duration = new_msg_lenght * 0.03
		
		var tween = create_tween()
		tween.tween_property(chat_display, "visible_characters", new_total_chars, duration)
		tween.tween_callback(func(): chat_display.visible_characters = -1)
		typing_sound.play()
		tween.tween_callback(typing_sound.stop)
	else:
		chat_display.visible_characters = -1
		
	current_text_lenght = new_total_chars
	
func _on_scroll_button_toggled(button_pressed_state: bool):
	GameManager.is_scroll_active = button_pressed_state
	chat_display.scroll_following = button_pressed_state
	print("Estado de la barra de scroll", button_pressed_state)
	GameManager.save_data()
	
	if button_pressed_state == true:
		var v_scrollbar = chat_display.get_v_scroll_bar()
		v_scrollbar.value = v_scrollbar.max_value
	
func _on_scroll_button_pressed():
	button_sound.play()

func _on_back_button_pressed() -> void:
	get_tree().call_deferred("change_scene_to_file", back_scene) # Replace with function body.

func _on_back_button_mouse_entered() -> void:
	back_sound.play() # Replace with function body.

func _on_button_mouse_entered() -> void:
	back_sound.play() # Replace with function body.

func _on_scroll_bar_button_mouse_entered() -> void:
	back_sound.play() # Replace with function body.
