extends Control
#references to child nodes
@onready var chat_display: RichTextLabel = $PanelContainer/MarginContainer/VBoxContainer/RichTextLabel
@onready var input_field: LineEdit = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/LineEdit
@onready var send_button: Button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/Button


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	send_button.pressed.connect(_on_send_button_pressed) # Replace with function body.
	input_field.text_submitted.connect(_on_text_submitted)
	
	if Network:
		Network.ai_response_received.connect(_on_ai_response)
		Network.request_failed.connect(_on_error)
	add_message("Sistema", "Conexión establecida. Escribe algo...", "gray")
	
func _on_send_button_pressed():
	send_message()
	
func _on_text_submitted(_new_text):
	send_message()
	
func send_message():
	var text = input_field.text.strip_edges()
	
	if text.is_empty():
		return
		
	add_message("You: ", text, "#40a4f4")
	input_field.clear()
	input_field.editable = false
	send_button.disabled = true
	add_message("System:", "Waiting response...", "gray")
	
	Network.ask_godot_ai(text)
	
func _on_ai_response(_response_text):
	add_message("AI: ", _response_text, "#ffffff")
	
	input_field.editable = true
	send_button.disabled = false
	input_field.grab_focus()
	
func _on_error(error_msg):
	add_message("Error: ", error_msg, "red")
	input_field.editable = true
	send_button.disabled = false
	
func add_message(sender: String, message: String, color: String):
	var formatted = "[b][color=%s]%s:[/color][/b] %s" % [color, sender, message]
	# Ejemplo: [b][color=red]Nombre:[/color][/b] mensaje
	chat_display.append_text(formatted + "\n")
