extends Node

signal server_status_checked(is_online: bool)
signal ai_response_received(text: String)
signal request_failed(error_msg: String)

const BASE_URL = ""

#var headers = [
#    "Content-Type: application/json; charset=utf-8",
#    "X-App-Token: SUPER_SECRETO_GODOT_123" 
#]

var headers = []

var _ping_http: HTTPRequest
var _ai_http: HTTPRequest

var start_server: bool = GameManager.start_server

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var app_token = EnvParser.parse("APP_TOKEN")
	headers = [
		"Content-Type: application/json; charset=utf8",
		"X-App-Token: " + app_token
		]
		
	if start_server == true:
		_ping_http = HTTPRequest.new() # Replace with function body.
		add_child(_ping_http)
		_ping_http.request_completed.connect(_on_ping_completed)
		
		_ai_http = HTTPRequest.new()
		add_child(_ai_http)
		_ai_http.request_completed.connect(_on_ai_completed)
		
		wake_up_server()
		
	pass

func wake_up_server():
	print("API SERVICE, TRY CALL SERVER!")
	var response = _ping_http.request(BASE_URL)
	if response != OK:
		print("LOCAL ERROR TO CONNECT SERVER")
		
func ask_godot_ai(prompt: String):
	var body = JSON.stringify({"prompt": prompt})
	var url = BASE_URL + "/askai"
	
	print("API SERVICE: SEND PROMPT")
	
	var response = _ai_http.request(url, headers, HTTPClient.METHOD_POST, body)
	
	if response != OK:
		request_failed.emit("ERROR, CANNOT SEND THE REQUEST")
		
#response managment (private)
func _on_ping_completed(_result, response_code, _headers, _body):
	if response_code == 200:
		print("SERVER WAKE AND READY!")
		server_status_checked.emit(true)
	else:
		print("THE SERVER RESPONSE WITH AN ERROR", response_code)
		server_status_checked.emit(false)
		
func _on_ai_completed(_result, response_code, _headers, body):
	var json = JSON.new()
	var json_parse_result = json.parse(body.get_string_from_utf8())
	if json_parse_result == OK:
		var data = json.data
		if response_code == 200:
			if "response" in data:
				ai_response_received.emit(data["response"])
			else:
				request_failed.emit("The server responded 200 but the 'response' key is missing.")
		else:
			if "error" in data:
				request_failed.emit("SERVER ERROR: " + str(response_code) + data["error"])
			else:
				request_failed.emit("UNKNOWN ERROR" + str(response_code))
	else:
		request_failed.emit("CRITIC ERROR, THE RESPONSE IS NOT A VALID JSON " + str(response_code))
