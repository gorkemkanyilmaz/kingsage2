extends Node
## NetworkManager — Çevrimiçi Sunucu Bağlantısı ve Bulut Senkronizasyon Katmanı.
## (Taht ve Kılıç / 500 CCU Çevrimiçi Mimari)

signal sync_completed(success: bool, data: Dictionary)
signal auth_completed(success: bool, profile: Dictionary)

const DEFAULT_SERVER_URL := "http://127.0.0.1:8000"

var server_url: String = DEFAULT_SERVER_URL
var is_server_reachable: bool = false
var auth_token: String = ""

var _http: HTTPRequest


func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.timeout = 3.0


func check_server(callback: Callable = Callable()) -> void:
	var req := HTTPRequest.new()
	add_child(req)
	req.timeout = 2.0
	req.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
		is_server_reachable = (result == HTTPRequest.RESULT_SUCCESS and response_code == 200)
		if callback.is_valid():
			var json_str := body.get_string_from_utf8()
			var test_json := JSON.new()
			var data := {}
			if test_json.parse(json_str) == OK and typeof(test_json.data) == TYPE_DICTIONARY:
				data = test_json.data
			callback.call(is_server_reachable, data)
		req.queue_free()
	)
	req.request(server_url + "/api/health")


func login_online(provider: String, display_name: String, callback: Callable = Callable()) -> void:
	var req := HTTPRequest.new()
	add_child(req)
	req.timeout = 4.0

	var payload := JSON.stringify({
		"provider": provider,
		"display_name": display_name
	})

	var headers := ["Content-Type: application/json"]

	req.request_completed.connect(func(result: int, response_code: int, _hdrs: PackedStringArray, body: PackedByteArray):
		var success := (result == HTTPRequest.RESULT_SUCCESS and response_code == 200)
		var res_data := {}
		if success:
			var json_str := body.get_string_from_utf8()
			var test_json := JSON.new()
			if test_json.parse(json_str) == OK and typeof(test_json.data) == TYPE_DICTIONARY:
				res_data = test_json.data
				auth_token = str(res_data.get("token", ""))

		if callback.is_valid():
			callback.call(success, res_data)
		auth_completed.emit(success, res_data)
		req.queue_free()
	)

	req.request(server_url + "/api/auth/login", headers, HTTPClient.METHOD_POST, payload)


func sync_state_from_cloud(token: String, callback: Callable = Callable()) -> void:
	var req := HTTPRequest.new()
	add_child(req)
	req.timeout = 5.0

	var headers := [
		"Authorization: Bearer " + token
	]

	req.request_completed.connect(func(result: int, response_code: int, _hdrs: PackedStringArray, body: PackedByteArray):
		var success := (result == HTTPRequest.RESULT_SUCCESS and response_code == 200)
		var res_data := {}
		if success:
			var json_str := body.get_string_from_utf8()
			var test_json := JSON.new()
			if test_json.parse(json_str) == OK and typeof(test_json.data) == TYPE_DICTIONARY:
				res_data = test_json.data

		if callback.is_valid():
			callback.call(success, res_data)
		sync_completed.emit(success, res_data)
		req.queue_free()
	)

	req.request(server_url + "/api/game/state", headers, HTTPClient.METHOD_GET)


func save_state_to_cloud(token: String, state_dict: Dictionary, callback: Callable = Callable()) -> void:
	var req := HTTPRequest.new()
	add_child(req)
	req.timeout = 5.0

	var headers := [
		"Content-Type: application/json",
		"Authorization: Bearer " + token
	]

	var payload := JSON.stringify(state_dict)

	req.request_completed.connect(func(result: int, response_code: int, _hdrs: PackedStringArray, body: PackedByteArray):
		var success := (result == HTTPRequest.RESULT_SUCCESS and response_code == 200)
		if callback.is_valid():
			callback.call(success)
		req.queue_free()
	)

	req.request(server_url + "/api/game/save", headers, HTTPClient.METHOD_POST, payload)


# =============================================================================
# Yetkili Çevrimiçi API Çağrıları (Authoritative Server Action API)
# =============================================================================

func api_request(endpoint: String, method: int, payload: Dictionary = {}, callback: Callable = Callable()) -> void:
	var req := HTTPRequest.new()
	add_child(req)
	req.timeout = 6.0

	var auth = Engine.get_main_loop().root.get_node_or_null("AuthManager") if Engine.get_main_loop() is SceneTree else null
	var token: String = auth_token
	if token.is_empty() and auth != null:
		token = str(auth.auth_token)

	var headers := PackedStringArray([
		"Content-Type: application/json"
	])
	if not token.is_empty():
		headers.append("Authorization: Bearer " + token)

	var body_str := JSON.stringify(payload) if (method == HTTPClient.METHOD_POST and not payload.is_empty()) else ""

	req.request_completed.connect(func(result: int, response_code: int, _hdrs: PackedStringArray, body: PackedByteArray):
		var success := (result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300)
		var res_json := {}
		var json_str := body.get_string_from_utf8()
		var test_json := JSON.new()
		if test_json.parse(json_str) == OK and typeof(test_json.data) == TYPE_DICTIONARY:
			res_json = test_json.data

		if callback.is_valid():
			callback.call(success, res_json)
		req.queue_free()
	)

	req.request(server_url + endpoint, headers, method, body_str)


func api_join_world(world_id: int, target_x: int, target_y: int, callback: Callable) -> void:
	api_request("/api/worlds/join", HTTPClient.METHOD_POST, {
		"world_id": world_id,
		"target_x": target_x,
		"target_y": target_y
	}, callback)


func api_get_world_map(world_id: int, callback: Callable) -> void:
	api_request("/api/worlds/%d/map" % world_id, HTTPClient.METHOD_GET, {}, callback)


func api_get_village(village_id: int, callback: Callable) -> void:
	api_request("/api/villages/%d" % village_id, HTTPClient.METHOD_GET, {}, callback)


func api_build(village_id: int, building_key: String, callback: Callable) -> void:
	api_request("/api/action/build", HTTPClient.METHOD_POST, {
		"village_id": village_id,
		"building_key": building_key
	}, callback)


func api_train(village_id: int, unit_key: String, count: int, callback: Callable) -> void:
	api_request("/api/action/train", HTTPClient.METHOD_POST, {
		"village_id": village_id,
		"unit_key": unit_key,
		"count": count
	}, callback)


func api_send_troops(from_vid: int, to_vid: int, units: Dictionary, move_type: String, callback: Callable) -> void:
	api_request("/api/action/send_troops", HTTPClient.METHOD_POST, {
		"from_village_id": from_vid,
		"to_village_id": to_vid,
		"units": units,
		"type": move_type
	}, callback)


func api_send_message(to_name: String, subject: String, body: String, callback: Callable) -> void:
	api_request("/api/messages/send", HTTPClient.METHOD_POST, {
		"to_name": to_name,
		"subject": subject,
		"body": body
	}, callback)


func api_get_inbox(callback: Callable) -> void:
	api_request("/api/messages/inbox", HTTPClient.METHOD_GET, {}, callback)


func api_get_reports(callback: Callable) -> void:
	api_request("/api/reports", HTTPClient.METHOD_GET, {}, callback)

