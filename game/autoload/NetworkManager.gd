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


func check_account_online(provider: String, email: String, provider_uid: String, callback: Callable = Callable(), _retry_count: int = 0, identity_token: String = "") -> void:
	var req := HTTPRequest.new()
	add_child(req)
	req.timeout = 10.0
	var payload_dict := {
		"provider": provider,
		"email": email.strip_edges(),
		"provider_uid": provider_uid.strip_edges(),
	}
	if not identity_token.strip_edges().is_empty():
		payload_dict["identity_token"] = identity_token.strip_edges()
	var payload := JSON.stringify(payload_dict)
	var headers := ["Content-Type: application/json"]
	req.request_completed.connect(func(result: int, response_code: int, _hdrs: PackedStringArray, body: PackedByteArray):
		var success := (result == HTTPRequest.RESULT_SUCCESS and response_code == 200)
		var res_data := {}
		var json_str := body.get_string_from_utf8()
		var test_json := JSON.new()
		if not json_str.is_empty() and test_json.parse(json_str) == OK and typeof(test_json.data) == TYPE_DICTIONARY:
			res_data = test_json.data
		res_data["_http_code"] = response_code
		if success:
			is_server_reachable = true
		elif response_code != 400 and response_code != 403 and response_code != 404 and _retry_count < 1 and is_inside_tree():
			req.queue_free()
			get_tree().create_timer(0.8).timeout.connect(func():
				if is_inside_tree():
					check_account_online(provider, email, provider_uid, callback, _retry_count + 1, identity_token)
			)
			return
		if callback.is_valid():
			callback.call(success, res_data)
		req.queue_free()
	)
	req.request(server_url + "/api/auth/check_account", headers, HTTPClient.METHOD_POST, payload)


func login_online(provider: String, display_name: String, callback: Callable = Callable(), _retry_count: int = 0, explicit_email: String = "", explicit_uid: String = "") -> void:
	var req := HTTPRequest.new()
	add_child(req)
	req.timeout = 10.0

	var auth_email := explicit_email.strip_edges()
	var auth_uid := explicit_uid.strip_edges()
	var auth_id_tok := ""
	var loop_pre = Engine.get_main_loop()
	if loop_pre is SceneTree:
		var auth_pre = loop_pre.root.get_node_or_null("AuthManager")
		if auth_pre != null:
			if auth_email.is_empty():
				auth_email = str(auth_pre.email).strip_edges()
			if auth_uid.is_empty():
				auth_uid = str(auth_pre.user_id).strip_edges()
			if auth_pre.get("identity_token") != null:
				auth_id_tok = str(auth_pre.get("identity_token")).strip_edges()

	var payload_dict := {
		"provider": provider,
		"display_name": display_name,
	}
	if not auth_email.is_empty():
		payload_dict["email"] = auth_email
	if not auth_uid.is_empty():
		payload_dict["provider_uid"] = auth_uid
	if not auth_id_tok.is_empty():
		payload_dict["identity_token"] = auth_id_tok
	var payload := JSON.stringify(payload_dict)

	var headers := ["Content-Type: application/json"]

	req.request_completed.connect(func(result: int, response_code: int, _hdrs: PackedStringArray, body: PackedByteArray):
		var success := (result == HTTPRequest.RESULT_SUCCESS and response_code == 200)
		var res_data := {}
		var json_str := body.get_string_from_utf8()
		var test_json := JSON.new()
		if not json_str.is_empty() and test_json.parse(json_str) == OK and typeof(test_json.data) == TYPE_DICTIONARY:
			res_data = test_json.data
		res_data["_http_code"] = response_code

		if success:
			is_server_reachable = true
			auth_token = str(res_data.get("token", ""))
			var loop = Engine.get_main_loop()
			if loop is SceneTree:
				var auth = loop.root.get_node_or_null("AuthManager")
				if auth != null:
					auth.auth_provider = provider
					auth.is_logged_in = true
					auth.auth_token = auth_token
					if res_data.has("user_id") and not str(res_data.get("user_id", "")).is_empty():
						auth.user_id = str(res_data.get("user_id"))
					if res_data.has("display_name") and not str(res_data.get("display_name", "")).is_empty():
						auth.display_name = str(res_data.get("display_name"))
					else:
						auth.display_name = display_name
					if res_data.has("email") and not str(res_data.get("email", "")).is_empty():
						auth.email = str(res_data.get("email"))
					elif not auth_email.is_empty():
						auth.email = auth_email
					auth.save_session()
					if auth.has_method("_cache_known_account"):
						auth.call("_cache_known_account", provider, auth_uid, auth.email, auth.display_name, auth.user_id)
					auth.auth_state_changed.emit(true, auth.get_profile())
				var wm = loop.root.get_node_or_null("WorldManager")
				if wm != null and wm.has_method("apply_cloud_sync"):
					wm.apply_cloud_sync(res_data)
			server_status_changed.emit(true, res_data)
		elif response_code != 400 and response_code != 403 and response_code != 409 and _retry_count < 1 and is_inside_tree():
			req.queue_free()
			get_tree().create_timer(0.8).timeout.connect(func():
				if is_inside_tree():
					login_online(provider, display_name, callback, _retry_count + 1, explicit_email, explicit_uid)
			)
			return

		if callback.is_valid():
			callback.call(success, res_data)
		auth_completed.emit(success, res_data)
		req.queue_free()
	)

	req.request(server_url + "/api/auth/login", headers, HTTPClient.METHOD_POST, payload)


func sync_state_from_cloud(token: String, callback: Callable = Callable(), req_seq: int = -1) -> void:
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
						wm.apply_cloud_sync(res_data, false, req_seq)

		if callback.is_valid():
			callback.call(success, res_data)
		sync_completed.emit(success, res_data)
		req.queue_free()
	)

	req.request(server_url + "/api/game/state", headers, HTTPClient.METHOD_GET)


func pull_shared_world_from_cloud(callback: Callable = Callable()) -> void:
	if auth_token.is_empty():
		return
	var req_seq := -1
	var loop = Engine.get_main_loop()
	if loop is SceneTree:
		var wm = loop.root.get_node_or_null("WorldManager")
		if wm != null and wm.get("_local_mutation_seq") != null:
			req_seq = int(wm.get("_local_mutation_seq"))
	sync_state_from_cloud(auth_token, callback, req_seq)


func save_state_to_cloud(token: String, state_dict: Dictionary, callback: Callable = Callable(), req_seq: int = -1) -> void:
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
						wm.apply_cloud_sync(res_data, true, req_seq)
		if callback.is_valid():
			callback.call(success)
		if success and not res_data.is_empty():
			sync_completed.emit(true, res_data)
		req.queue_free()
	)

	req.request(server_url + "/api/game/save", headers, HTTPClient.METHOD_POST, payload)


func delete_account_online(callback: Callable = Callable()) -> void:
	var loop = Engine.get_main_loop()
	var auth = loop.root.get_node_or_null("AuthManager") if loop is SceneTree else null
	var token: String = auth_token
	if token.is_empty() and auth != null:
		token = str(auth.auth_token)
	if token.is_empty() or not is_cloud_sync_enabled():
		auth_token = ""
		if callback.is_valid():
			callback.call(true, {"ok": true, "local_only": true})
		return

	var req := HTTPRequest.new()
	add_child(req)
	req.timeout = 15.0
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + token,
	])
	req.request_completed.connect(func(result: int, response_code: int, _hdrs: PackedStringArray, body: PackedByteArray):
		var ok := (result == HTTPRequest.RESULT_SUCCESS and (response_code == 200 or response_code == 401 or response_code == 404))
		var res_json := {}
		var json_str := body.get_string_from_utf8()
		var test_json := JSON.new()
		if not json_str.is_empty() and test_json.parse(json_str) == OK and typeof(test_json.data) == TYPE_DICTIONARY:
			res_json = test_json.data
		res_json["_http_code"] = response_code
		if ok:
			auth_token = ""
		if callback.is_valid():
			callback.call(ok, res_json)
		req.queue_free()
	)
	req.request(server_url + "/api/account/delete", headers, HTTPClient.METHOD_POST, "{}")


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

