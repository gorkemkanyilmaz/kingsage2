extends Node
## NetworkManager — Çevrimiçi Sunucu Bağlantısı ve Bulut Senkronizasyon Katmanı.
## (Taht ve Kılıç / 500 CCU Çevrimiçi Mimari)

signal sync_completed(success: bool, data: Dictionary)
signal auth_completed(success: bool, profile: Dictionary)
signal server_status_changed(reachable: bool, data: Dictionary)

const DEFAULT_SERVER_URL := "https://tahtkilic.vercel.app"

var server_url: String = DEFAULT_SERVER_URL
var is_server_reachable: bool = false
var auth_token: String = ""

var _http: HTTPRequest


func _ready() -> void:
	if OS.has_feature("web"):
		var web_origin = JavaScriptBridge.eval("window.location.origin")
		if web_origin != null and str(web_origin).begins_with("http"):
			server_url = str(web_origin)
	_http = HTTPRequest.new()
	add_child(_http)
	_http.timeout = 5.0
	call_deferred("_auto_connect_cloud")


static func is_cloud_sync_enabled() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	return OS.has_feature("web") or OS.has_feature("ios") or OS.has_feature("android")


func _auto_connect_cloud() -> void:
	if not is_cloud_sync_enabled():
		return
	check_server()
	var loop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return
	var auth = loop.root.get_node_or_null("AuthManager")
	if auth != null and bool(auth.is_logged_in) and not str(auth.display_name).strip_edges().is_empty():
		var saved_tok := str(auth.auth_token)
		if saved_tok.begins_with("tk_tok_"):
			auth_token = saved_tok
		var prov: String = str(auth.auth_provider) if not str(auth.auth_provider).is_empty() else "google"
		login_online(prov, str(auth.display_name))


func check_server(callback: Callable = Callable()) -> void:
	var req := HTTPRequest.new()
	add_child(req)
	req.timeout = 10.0
	req.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
		is_server_reachable = (result == HTTPRequest.RESULT_SUCCESS and response_code == 200)
		var data := {}
		var json_str := body.get_string_from_utf8()
		var test_json := JSON.new()
		if test_json.parse(json_str) == OK and typeof(test_json.data) == TYPE_DICTIONARY:
			data = test_json.data
		server_status_changed.emit(is_server_reachable, data)
		if callback.is_valid():
			callback.call(is_server_reachable, data)
		req.queue_free()
	)
	req.request(server_url + "/api/health")


func login_online(provider: String, display_name: String, callback: Callable = Callable(), _retry_count: int = 0) -> void:
	var req := HTTPRequest.new()
	add_child(req)
	req.timeout = 10.0

	var auth_email := ""
	var auth_uid := ""
	var loop_pre = Engine.get_main_loop()
	if loop_pre is SceneTree:
		var auth_pre = loop_pre.root.get_node_or_null("AuthManager")
		if auth_pre != null:
			auth_email = str(auth_pre.email)
			auth_uid = str(auth_pre.user_id)

	var payload_dict := {
		"provider": provider,
		"display_name": display_name,
	}
	if not auth_email.strip_edges().is_empty():
		payload_dict["email"] = auth_email.strip_edges()
	if not auth_uid.strip_edges().is_empty():
		payload_dict["provider_uid"] = auth_uid.strip_edges()
	var payload := JSON.stringify(payload_dict)

	var headers := ["Content-Type: application/json"]

	req.request_completed.connect(func(result: int, response_code: int, _hdrs: PackedStringArray, body: PackedByteArray):
		var success := (result == HTTPRequest.RESULT_SUCCESS and response_code == 200)
		var res_data := {}
		if success:
			is_server_reachable = true
			var json_str := body.get_string_from_utf8()
			var test_json := JSON.new()
			if test_json.parse(json_str) == OK and typeof(test_json.data) == TYPE_DICTIONARY:
				res_data = test_json.data
				auth_token = str(res_data.get("token", ""))
				var loop = Engine.get_main_loop()
				if loop is SceneTree:
					var auth = loop.root.get_node_or_null("AuthManager")
					if auth != null:
						auth.auth_token = auth_token
						if res_data.has("user_id") and not str(res_data.get("user_id", "")).is_empty():
							auth.user_id = str(res_data.get("user_id"))
						if res_data.has("display_name") and not str(res_data.get("display_name", "")).is_empty():
							auth.display_name = str(res_data.get("display_name"))
						if res_data.has("email") and not str(res_data.get("email", "")).is_empty():
							auth.email = str(res_data.get("email"))
						auth.save_session()
					var wm = loop.root.get_node_or_null("WorldManager")
					if wm != null and wm.has_method("apply_cloud_sync"):
						wm.apply_cloud_sync(res_data)
			server_status_changed.emit(true, res_data)
		elif _retry_count < 1 and is_inside_tree():
			req.queue_free()
			get_tree().create_timer(1.5).timeout.connect(func():
				if is_inside_tree():
					login_online(provider, display_name, callback, _retry_count + 1)
			)
			return

		if callback.is_valid():
			callback.call(success, res_data)
		auth_completed.emit(success, res_data)
		req.queue_free()
	)

	req.request(server_url + "/api/auth/login", headers, HTTPClient.METHOD_POST, payload)


func sync_state_from_cloud(token: String, callback: Callable = Callable()) -> void:
	var req := HTTPRequest.new()
	add_child(req)
	req.timeout = 10.0

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
				var loop = Engine.get_main_loop()
				if loop is SceneTree:
					var wm = loop.root.get_node_or_null("WorldManager")
					if wm != null and wm.has_method("apply_cloud_sync"):
						wm.apply_cloud_sync(res_data)

		if callback.is_valid():
			callback.call(success, res_data)
		sync_completed.emit(success, res_data)
		req.queue_free()
	)

	req.request(server_url + "/api/game/state", headers, HTTPClient.METHOD_GET)


func pull_shared_world_from_cloud(callback: Callable = Callable()) -> void:
	if auth_token.is_empty():
		return
	sync_state_from_cloud(auth_token, callback)


func save_state_to_cloud(token: String, state_dict: Dictionary, callback: Callable = Callable()) -> void:
	var req := HTTPRequest.new()
	add_child(req)
	req.timeout = 10.0

	var headers := [
		"Content-Type: application/json",
		"Authorization: Bearer " + token
	]

	var payload := JSON.stringify(state_dict)

	req.request_completed.connect(func(result: int, response_code: int, _hdrs: PackedStringArray, body: PackedByteArray):
		var success := (result == HTTPRequest.RESULT_SUCCESS and response_code == 200)
		var res_data := {}
		if success:
			var json_str := body.get_string_from_utf8()
			var test_json := JSON.new()
			if test_json.parse(json_str) == OK and typeof(test_json.data) == TYPE_DICTIONARY:
				res_data = test_json.data
				var loop = Engine.get_main_loop()
				if loop is SceneTree:
					var wm = loop.root.get_node_or_null("WorldManager")
					if wm != null and wm.has_method("apply_cloud_sync"):
						wm.apply_cloud_sync(res_data, true)
		if callback.is_valid():
			callback.call(success)
		if success and not res_data.is_empty():
			sync_completed.emit(true, res_data)
		req.queue_free()
	)

	req.request(server_url + "/api/game/save", headers, HTTPClient.METHOD_POST, payload)


# =============================================================================
# Yetkili Çevrimiçi API Çağrıları (Authoritative Server Action API)
# =============================================================================

func api_request(endpoint: String, method: int, payload: Dictionary = {}, callback: Callable = Callable()) -> void:
	var req := HTTPRequest.new()
	add_child(req)
	req.timeout = 10.0

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

