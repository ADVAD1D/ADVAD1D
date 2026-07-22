extends Node

signal server_status_checked(is_online: bool)
signal ai_response_received(text: String)
signal request_failed(error_msg: String)

#leaderboard signals
signal phase_recorded_successfully()
signal phase_record_failed (error_msg: String)
signal name_check_completed(is_available: bool, message: String)

signal identity_recovered(pilot_name: String)

var production_server_active = GameManager.production_server_active
var debug_response_text_active = GameManager.debug_response_text_active
var BASE_URL: String

var server_online: bool = false
var last_network_log: String = "Waiting for init..."

#var headers = [
#    "Content-Type: application/json; charset=utf-8",
#    "X-App-Token: SUPER_SECRETO_GODOT_123" 
#]

#the server is active in uptimerobot session (10min), Render off the server in 15 min

var headers = []

var _ping_http: HTTPRequest
var _ai_http: HTTPRequest
var _leaderboard_http: HTTPRequest
var _name_check_http: HTTPRequest
var _whoami_http: HTTPRequest

var start_server: bool = GameManager.start_server

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if production_server_active == true:
		BASE_URL = "https://advad-ai-server.onrender.com/api/advad-ai"
	else:
		BASE_URL = "http://127.0.0.1:10000/api/advad-ai"
		
	var app_token = EnvParser.parse("APP_TOKEN")
		
	var global_device_id = _get_persistent_device_uid()
		
	headers = [
		"Content-Type: application/json; charset=utf8",
		"X-App-Token: " + app_token,
		"X-Device-ID: " + global_device_id
		]
		
	_ping_http = HTTPRequest.new() # Replace with function body.
	add_child(_ping_http)
	_ping_http.request_completed.connect(_on_ping_completed)
		
	_ai_http = HTTPRequest.new()
	add_child(_ai_http)
	_ai_http.request_completed.connect(_on_ai_completed)
	
	_leaderboard_http = HTTPRequest.new()
	add_child(_leaderboard_http)
	_leaderboard_http.request_completed.connect(_on_leaderboard_completed)
	
	_name_check_http = HTTPRequest.new()
	add_child(_name_check_http)
	_name_check_http.request_completed.connect(_on_name_check_completed)
	
	_whoami_http = HTTPRequest.new()
	add_child(_whoami_http)
	_whoami_http.request_completed.connect(_on_whoami_completed)
		
	#ALWAYS start the server for testing, otherwise the variables will become NULL
	if start_server == true:
		wake_up_server()
		
	else:
		request_failed.emit("API SERVICE, MANUAL INIT, THE SERVER STATUS IS FALSE.")
		
#this function show log messages (response codes and messages) for devs, for security reasons
func _log_dev(message: String, respose_code: int) -> void:
	last_network_log = message + " (" + str(respose_code) + ")"
	if OS.is_debug_build():
		print_rich("[color=yellow][DEV LOG][/color] " + message, respose_code)
	else:
		pass

func wake_up_server():
	if BASE_URL == "":
		_log_message("API SERVICE: URL NOT FOUND IN THE CONSTANT")
		return
		
	_log_message("API SERVICE, TRY CALL SERVER!")
	var response = _ping_http.request(BASE_URL + "/")
	if response != OK:
		_log_message("LOCAL ERROR TO CONNECT SERVER")
		
func check_my_identity():
	var url = BASE_URL + "/whoami"
	_log_message("API SERVICE: Scanning digital DNA for auto-login...")
	
	_whoami_http.request(url, headers, HTTPClient.METHOD_GET)
		
func ask_godot_ai(prompt: String):
	if BASE_URL.strip_edges().is_empty():
		_log_message("API SERVICE: ERROR. URL IS EMPTY")
		request_failed.emit("API SERVICE: ERROR. URL IS EMPTY")
		return
		
	if not _ai_http:
		request_failed.emit("CRITIC ERROR: HTTP SERVICE NOT INIT")
		return
		
	if _ai_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_log_message("API SERVICE: Missed request, there is already one in progress")
		return
		
	var body = JSON.stringify({"prompt": prompt})
	var url = BASE_URL + "/askai"
	
	_log_message("API SERVICE: SEND PROMPT")
	
	var response = _ai_http.request(url, headers, HTTPClient.METHOD_POST, body)
	
	if response != OK:
		request_failed.emit("ERROR, CANNOT SEND THE REQUEST")
		
func check_pilot_name(pilot_name: String):
	if BASE_URL.strip_edges().is_empty():
		_log_message("API ERROR: URL IS EMPTY")
		return
	if not _name_check_http:
		_log_message("ERROR: CHECK NAME HTTP SERVICE NOT INIT")
		return
	if _name_check_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_log_message("CHECK IN PROGRESS")
		return
		
	var url = BASE_URL + "/check-name/" + pilot_name.uri_encode()
	
	_log_message(["API SERVICE: CHECKING NAME AVAILABILITY...", pilot_name])
	
	var response = _name_check_http.request(url, headers, HTTPClient.METHOD_GET)
	
	if response != OK:
		_log_message("LOCAL ERROR: The name query could not be processed.")
		name_check_completed.emit(false, "Local Network Error")
		
func send_player_phase(player_name: String, last_phase: int):
	if BASE_URL.strip_edges().is_empty():
		_log_message("API ERROR: URL IS EMPTY")
		return
		
	if not _leaderboard_http:
		phase_record_failed.emit("CRITIC ERROR. HTTP SERVICE NOT INIT")
		return
		
	if _leaderboard_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_log_message("API SERVICE: Transmission in progress, ignoring duplicates.")
		return
		
	var body = JSON.stringify({
		"pilot_name": player_name,
		"last_phase": last_phase
	})
	
	var url = BASE_URL + "/record-phase"
	_log_message(["API SERVICE: SENDING BLACK BOX TO SERVER...", player_name, "Fase:", last_phase])
	var response = _leaderboard_http.request(url, headers, HTTPClient.METHOD_POST, body)
	
	if response != OK:
		phase_record_failed.emit("LOCAL ERROR: The HTTP request could not be dispatched.")
		
#response managment (private)
func _on_ping_completed(result, response_code, _headers, _body):
	if result != HTTPRequest.RESULT_SUCCESS:
		_log_message("PING CAIDO: NOT CONECTION OR DOWN SERVER")
		server_online = false
		server_status_checked.emit(false)
		return
	if response_code == 200:
		_log_message("SERVER WAKE AND READY!")
		server_online = true
		server_status_checked.emit(true)
	else:
		_log_dev("THE SERVER RESPONSE WITH AN ERROR", response_code)
		server_online = false
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
			if "response" in data and debug_response_text_active == true:
				_log_message(["TEXTO CRUDO: ", data["response"]])
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
		
func _on_name_check_completed(result, response_code, _headers, body):
	if result != HTTPRequest.RESULT_SUCCESS:
		_log_message("NAME CHECH ERROR, CONNECTION FAILED")
		name_check_completed.emit(false, "Connection error to the server")
		return
	if response_code != 200:
		_log_message(["NAME CHECK ERROR: HTTP CODE: ", response_code])
		name_check_completed.emit(false, "Error del servidor (" + str(response_code) + ").")
		return
		
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	
	if parse_result == OK:
		var data = json.data
		if typeof(data) == TYPE_DICTIONARY and data.has("available"):
			name_check_completed.emit(data["available"], data.get("message", ""))
		else:
			name_check_completed.emit(false, "Invalid Server or DB Response")
	else:
		name_check_completed.emit(false, "Error decrypting database data.")
		
func _on_leaderboard_completed(result, response_code, _headers, body):
	if result != HTTPRequest.RESULT_SUCCESS:
		match result:
			HTTPRequest.RESULT_CANT_CONNECT:
				_log_message("LEADERBOARD ERROR: No Internet connection or server unreachable.")
			HTTPRequest.RESULT_CANT_RESOLVE:
				_log_message("LEADERBOARD ERROR: Route or Domain not found")
			HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
				_log_message("LEADERBOARD ERROR: SSL/HTTPS ERROR")
			_:
				_log_message("LEADERBOARD ERROR: UNKNOWN CONNECTION ERROR")
		phase_record_failed.emit("UNKNOWN CONNECTION ERROR")
		return
		
	if response_code == 409:
		_log_message("Overwritting existing name attempt")
		phase_record_failed.emit("Mission aborted: The name sign already belongs to another pilot.")
		return
		
	if response_code != 200:
		_log_message(["The server rejected the transmission. HTTP code: ", response_code])
		if body:
			_log_dev("DETAIL ERROR: " + body.get_string_from_utf8(), response_code)
			
		phase_record_failed.emit("HTTP ERROR: " + str(response_code))
		return
	_log_message("API SERVICE: Black box sent! Maximum phase recorded on the server.")
	phase_recorded_successfully.emit()
	
func _on_whoami_completed(result, response_code, _headers, body):
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var json = JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			var data = json.data
			if data.get("pilot_name") != null:
				identity_recovered.emit(data["pilot_name"])
				return
	identity_recovered.emit("")
	
func _get_persistent_device_uid():
	var hw_id = OS.get_unique_id()
	if hw_id != null and hw_id.strip_edges() != "":
		return hw_id
	#ONLY save UID browser logic in web version, native works nice
	var id_path = "user://web_device_id.dat"
	if FileAccess.file_exists(id_path):
		var file = FileAccess.open(id_path, FileAccess.READ)
		var saved_id = file.get_as_text().strip_edges()
		if saved_id != "":
			return saved_id
			
	randomize()
	var new_web_id = "WEB-" + str(Time.get_ticks_msec()) + "-" + str(randi() % 10000)
	var new_file = FileAccess.open(id_path, FileAccess.WRITE)
	if new_file:
		new_file.store_string(new_web_id)
	return new_web_id
	
func _log_message(message):
	var final_string = ""
	if typeof(message) == TYPE_ARRAY:
		for arg in message:
			final_string += str(arg) + " "
		final_string = final_string.strip_edges()
	else:
		final_string = str(message)
	
	last_network_log = final_string
	
	if GameManager.is_debug_text == true:
		print_rich("[color=yellow][DEV LOG][/color] " + final_string)
	else:
		return
