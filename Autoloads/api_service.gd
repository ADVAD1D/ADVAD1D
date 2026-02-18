extends Node

signal server_status_checked(is_online: bool)
signal ai_response_received(text: String)
signal request_failed(error_msg: String)

var production_server_active = GameManager.production_server_active
var BASE_URL: String

#var headers = [
#    "Content-Type: application/json; charset=utf-8",
#    "X-App-Token: SUPER_SECRETO_GODOT_123" 
#]

#the server is active in uptimerobot session, Render off the server in 15 min

var headers = []

var _ping_http: HTTPRequest
var _ai_http: HTTPRequest

var start_server: bool = GameManager.start_server

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if production_server_active == true:
		BASE_URL = "https://advad-ai-server.onrender.com"
	else:
		BASE_URL = "http://127.0.0.1:10000"
		
	var app_token = EnvParser.parse("APP_TOKEN")
	headers = [
		"Content-Type: application/json; charset=utf8",
		"X-App-Token: " + app_token
		]
		
	_ping_http = HTTPRequest.new() # Replace with function body.
	add_child(_ping_http)
	_ping_http.request_completed.connect(_on_ping_completed)
		
	_ai_http = HTTPRequest.new()
	add_child(_ai_http)
	_ai_http.request_completed.connect(_on_ai_completed)
		
	#ALWAYS start the server for testing, otherwise the variables will become NULL
	if start_server == true:
		wake_up_server()
		
	else:
		request_failed.emit("API SERVICE, MANUAL INIT, THE SERVER STATUS IS FALSE.")
		
		
#this function show log messages (response codes and messages) for devs, for security reasons
func _log_dev(message: String, respose_code: int) -> void:
	if OS.is_debug_build():
		print_rich("[color=yellow][DEV LOG][/color] " + message, respose_code)
	else:
		pass

func wake_up_server():
	if BASE_URL == "":
		print("API SERVICE: URL NOT FOUND IN THE CONSTANT")
		return
		
	print("API SERVICE, TRY CALL SERVER!")
	var response = _ping_http.request(BASE_URL)
	if response != OK:
		print("LOCAL ERROR TO CONNECT SERVER")
		
func ask_godot_ai(prompt: String):
	if BASE_URL.strip_edges().is_empty():
		print("API SERVICE: ERROR. URL IS EMPTY")
		request_failed.emit("API SERVICE: ERROR. URL IS EMPTY")
		return
		
	if not _ai_http:
		request_failed.emit("CRITIC ERROR: HTTP SERVICE NOT INIT")
		return
		
	if _ai_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		print("API SERVICE: Peticion ignorada, ya hay una en curso")
		return
		
	var body = JSON.stringify({"prompt": prompt})
	var url = BASE_URL + "/askai"
	
	print("API SERVICE: SEND PROMPT")
	
	var response = _ai_http.request(url, headers, HTTPClient.METHOD_POST, body)
	
	if response != OK:
		request_failed.emit("ERROR, CANNOT SEND THE REQUEST")
		
#response managment (private)
func _on_ping_completed(result, response_code, _headers, _body):
	if result != HTTPRequest.RESULT_SUCCESS:
		print("PING CAIDO: SIN CONEXIÓN O SERVIDOR CAÍDO")
		server_status_checked.emit(false)
		return
	if response_code == 200:
		print("SERVER WAKE AND READY!")
		server_status_checked.emit(true)
	else:
		_log_dev("THE SERVER RESPONSE WITH AN ERROR", response_code)
		server_status_checked.emit(false)
		
func _on_ai_completed(result, response_code, _headers, body):
	if result != HTTPRequest.RESULT_SUCCESS:
		match result:
			HTTPRequest.RESULT_CANT_CONNECT:
				request_failed.emit("THERE IS NOT INTERNET CONNECTION OR THE SERVER DOES NOT EXIST")
			HTTPRequest.RESULT_CANT_RESOLVE:
				request_failed.emit("DNS ERROR: DOMAIN NOT FOUND")
			HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
				request_failed.emit("SSL/HTTPS ERROR")
			_:
				request_failed.emit("UNKNOWN CONNECTION ERROR")
		return
		
	if response_code == 0:
		request_failed.emit("THE SERVER NOT RESPONSE, TIMEOUT OR CRASH")
		return
		
	var json = JSON.new()
	var json_parse_result = json.parse(body.get_string_from_utf8())
	if json_parse_result == OK:
		var data = json.data
		if typeof(data) != TYPE_DICTIONARY:
			request_failed.emit("ERROR, DATA FORMAT, NO JSON")
			return
			
		if response_code == 200:
			if "response" in data:
				ai_response_received.emit(data["response"])
			else:
				request_failed.emit("The server responded 200 but the 'response' key is missing.")
		else:
			if "error" in data:
				request_failed.emit("SERVER ERROR")
				_log_dev("SERVER ERROR: ", response_code)
			else:
				request_failed.emit("UNKNOWN ERROR")
				_log_dev("UNKNOWN ERROR", response_code)
	else:
		request_failed.emit("CRITIC ERROR, THE RESPONSE IS NOT A VALID JSON ")
		_log_dev("CRITIC ERROR, THE RESPONSE IS NOT A VALID JSON ", response_code)
