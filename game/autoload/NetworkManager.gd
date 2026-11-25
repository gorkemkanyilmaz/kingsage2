extends Node
## NetworkManager — Çevrimiçi Sunucu Bağlantısı ve Bulut Senkronizasyon Katmanı.
## (Taht ve Kılıç / 500 CCU Çevrimiçi Mimari)

signal sync_completed(success: bool, data: Dictionary)
signal auth_completed(success: bool, profile: Dictionary)
signal server_status_changed(reachable: bool, data: Dictionary)

const DEFAULT_SERVER_URL := "https://92.5.113.251.nip.io/tahtkilic"

var server_url: String = DEFAULT_SERVER_URL
var is_server_reachable: bool = false
var auth_token: String = ""

var _http: HTTPRequest
var _bg_requests: Array[HTTPRequest] = []
var _cloud_save_in_flight: bool = false
var _pending_cloud_save: Dictionary = {}
var _store_req_queue: Array[Dictionary] = []
var _store_req_in_flight: bool = false


func has_pending_or_inflight_cloud_save() -> bool:
	return _cloud_save_in_flight or not _pending_cloud_save.is_empty()


func _untrack_bg_request(req: HTTPRequest) -> void:
	_bg_requests.erase(req)


func cancel_background_requests() -> void:
	var copy := _bg_requests.duplicate()
	_bg_requests.clear()
	for r in copy:
		if r != null and is_instance_valid(r):
			r.cancel_request()
			r.queue_free()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_cloud_save_in_flight = false
		_pending_cloud_save.clear()
		_store_req_queue.clear()
		_store_req_in_flight = false
		cancel_background_requests()
		if _http != null and is_instance_valid(_http):
			_http.cancel_request()


func _ready() -> void:
	if OS.has_feature("web"):
		var web_origin = JavaScriptBridge.eval("window.location.origin")
		if web_origin != null and (str(web_origin).contains("localhost") or str(web_origin).contains("127.0.0.1")):
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
	req.use_threads = not OS.has_feature("web")
	add_child(req)
	_bg_requests.append(req)
	req.timeout = 8.0
	req.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
		_untrack_bg_request(req)
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
	var err := req.request(server_url + "/api/health")
	if err != OK:
		_untrack_bg_request(req)
		is_server_reachable = false
		server_status_changed.emit(false, {})
		if callback.is_valid():
			callback.call(false, {})
		req.queue_free()


func check_account_online(provider: String, email: String, provider_uid: String, callback: Callable = Callable(), _retry_count: int = 0, identity_token: String = "") -> void:
	var req := HTTPRequest.new()
	req.use_threads = not OS.has_feature("web")
	add_child(req)
	var timeouts := [6.0, 8.0, 10.0]
	var cur_timeout := float(timeouts[mini(_retry_count, timeouts.size() - 1)])
	req.timeout = cur_timeout
	var payload_dict := {
		"provider": provider,
		"email": email.strip_edges(),
		"provider_uid": provider_uid.strip_edges(),
	}
	if not identity_token.strip_edges().is_empty():
		payload_dict["identity_token"] = identity_token.strip_edges()
	var payload := JSON.stringify(payload_dict)
	var headers := ["Content-Type: application/json; charset=utf-8"]
	var done := [false]

	var handle_failure := func(response_code: int, res_data: Dictionary):
		if _retry_count < 2 and is_inside_tree():
			var delay := 0.35 if _retry_count == 0 else 0.60
			get_tree().create_timer(delay).timeout.connect(func():
				if is_inside_tree():
					check_account_online(provider, email, provider_uid, callback, _retry_count + 1, identity_token)
			)
			return
		if callback.is_valid():
			callback.call(false, res_data)

	req.request_completed.connect(func(result: int, response_code: int, _hdrs: PackedStringArray, body: PackedByteArray):
		if bool(done[0]):
			return
		done[0] = true
		var success := (result == HTTPRequest.RESULT_SUCCESS and response_code == 200)
		var res_data := {}
		var json_str := body.get_string_from_utf8()
		var test_json := JSON.new()
		if not json_str.is_empty() and test_json.parse(json_str) == OK and typeof(test_json.data) == TYPE_DICTIONARY:
			res_data = test_json.data
		res_data["_http_code"] = response_code
		req.queue_free()
		if success:
			is_server_reachable = true
			if callback.is_valid():
				callback.call(true, res_data)
		elif response_code != 400 and response_code != 403 and response_code != 404:
			handle_failure.call(response_code, res_data)
		else:
			if callback.is_valid():
				callback.call(false, res_data)
	)

	var watchdog := Timer.new()
	watchdog.one_shot = true
	watchdog.wait_time = cur_timeout + 1.5
	watchdog.timeout.connect(func():
		if bool(done[0]):
			return
		done[0] = true
		if is_instance_valid(req):
			req.cancel_request()
			req.queue_free()
		handle_failure.call(0, {"_http_code": 0, "_watchdog_timeout": true})
	)
	req.add_child(watchdog)
	watchdog.start()

	var req_err := req.request_raw(server_url + "/api/auth/check_account", headers, HTTPClient.METHOD_POST, payload.to_utf8_buffer())
	if req_err != OK and not bool(done[0]):
		done[0] = true
		req.queue_free()
		handle_failure.call(0, {"_http_code": 0, "_request_error": req_err})


func login_online(provider: String, display_name: String, callback: Callable = Callable(), _retry_count: int = 0, explicit_email: String = "", explicit_uid: String = "") -> void:
	var req := HTTPRequest.new()
	req.use_threads = not OS.has_feature("web")
	add_child(req)
	var timeouts := [6.0, 8.0, 10.0]
	var cur_timeout := float(timeouts[mini(_retry_count, timeouts.size() - 1)])
	req.timeout = cur_timeout

	var auth_email := explicit_email.strip_edges()
	var auth_uid := explicit_uid.strip_edges()
	var auth_id_tok := ""
	var loop_pre = Engine.get_main_loop()
	if loop_pre is SceneTree:
		var auth_pre = loop_pre.root.get_node_or_null("AuthManager")
		if auth_pre != null:
			if auth_email.is_empty():
				auth_email = str(auth_pre.email).strip_edges()
			if auth_uid.is_empty() and auth_pre.get("provider_uid") != null:
				auth_uid = str(auth_pre.get("provider_uid")).strip_edges()
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

	var headers := ["Content-Type: application/json; charset=utf-8"]
	var done := [false]

	var handle_login_failure := func(res_data: Dictionary):
		if _retry_count < 2 and is_inside_tree():
			var delay := 0.35 if _retry_count == 0 else 0.60
			get_tree().create_timer(delay).timeout.connect(func():
				if is_inside_tree():
					login_online(provider, display_name, callback, _retry_count + 1, explicit_email, explicit_uid)
			)
			return
		if callback.is_valid():
			callback.call(false, res_data)
		auth_completed.emit(false, res_data)

	req.request_completed.connect(func(result: int, response_code: int, _hdrs: PackedStringArray, body: PackedByteArray):
		if bool(done[0]):
			return
		done[0] = true
		var success := (result == HTTPRequest.RESULT_SUCCESS and response_code == 200)
		var res_data := {}
		var json_str := body.get_string_from_utf8()
		var test_json := JSON.new()
		if not json_str.is_empty() and test_json.parse(json_str) == OK and typeof(test_json.data) == TYPE_DICTIONARY:
			res_data = test_json.data
		res_data["_http_code"] = response_code
		req.queue_free()

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
					var resolved_puid := str(res_data.get("provider_uid", auth_uid)).strip_edges()
					if not resolved_puid.is_empty():
						auth.set("provider_uid", resolved_puid)
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
						auth.call("_cache_known_account", provider, resolved_puid, auth.email, auth.display_name, auth.user_id)
					auth.auth_state_changed.emit(true, auth.get_profile())
				var wm = loop.root.get_node_or_null("WorldManager")
				if wm != null and wm.has_method("apply_cloud_sync"):
					wm.apply_cloud_sync(res_data)
			server_status_changed.emit(true, res_data)
			if callback.is_valid():
				callback.call(true, res_data)
			auth_completed.emit(true, res_data)
		elif response_code != 400 and response_code != 403 and response_code != 409:
			handle_login_failure.call(res_data)
		else:
			if callback.is_valid():
				callback.call(false, res_data)
			auth_completed.emit(false, res_data)
	)

	var watchdog := Timer.new()
	watchdog.one_shot = true
	watchdog.wait_time = cur_timeout + 1.5
	watchdog.timeout.connect(func():
		if bool(done[0]):
			return
		done[0] = true
		if is_instance_valid(req):
			req.cancel_request()
			req.queue_free()
		handle_login_failure.call({"_http_code": 0, "_watchdog_timeout": true})
	)
	req.add_child(watchdog)
	watchdog.start()

	var req_err := req.request_raw(server_url + "/api/auth/login", headers, HTTPClient.METHOD_POST, payload.to_utf8_buffer())
	if req_err != OK and not bool(done[0]):
		done[0] = true
		req.queue_free()
		handle_login_failure.call({"_http_code": 0, "_request_error": req_err})


func sync_state_from_cloud(token: String, callback: Callable = Callable(), req_seq: int = -1) -> void:
	var req := HTTPRequest.new()
	req.use_threads = not OS.has_feature("web")
	add_child(req)
	_bg_requests.append(req)
	req.timeout = 8.0

	var headers := [
		"Authorization: Bearer " + token
	]

	req.request_completed.connect(func(result: int, response_code: int, _hdrs: PackedStringArray, body: PackedByteArray):
		_untrack_bg_request(req)
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

	var err := req.request(server_url + "/api/game/state", headers, HTTPClient.METHOD_GET)
	if err != OK:
		_untrack_bg_request(req)
		if callback.is_valid():
			callback.call(false, {})
		sync_completed.emit(false, {})
		req.queue_free()


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


func _flush_pending_cloud_save() -> void:
	if _cloud_save_in_flight or _pending_cloud_save.is_empty():
		return
	var next_save := _pending_cloud_save.duplicate(false)
	_pending_cloud_save.clear()
	var tok := str(next_save.get("token", ""))
	if tok.is_empty():
		return
	var st_val = next_save.get("state_dict", {})
	if typeof(st_val) != TYPE_DICTIONARY:
		return
	var cb: Callable = next_save.get("callback", Callable())
	var rseq := int(next_save.get("req_seq", -1))
	save_state_to_cloud(tok, st_val as Dictionary, cb, rseq)


func save_state_to_cloud(token: String, state_dict: Dictionary, callback: Callable = Callable(), req_seq: int = -1) -> void:
	if token.strip_edges().is_empty():
		if callback.is_valid():
			callback.call(false)
		return
	if _cloud_save_in_flight:
		_pending_cloud_save = {
			"token": token,
			"state_dict": state_dict.duplicate(true),
			"callback": callback,
			"req_seq": req_seq,
		}
		return

	_cloud_save_in_flight = true
	var req := HTTPRequest.new()
	req.use_threads = not OS.has_feature("web")
	add_child(req)
	req.timeout = 10.0

	var headers := [
		"Content-Type: application/json; charset=utf-8",
		"Authorization: Bearer " + token
	]

	var payload := JSON.stringify(state_dict)
	var done := [false]

	var finish_cloud_save := func(ok: bool, res_data: Dictionary):
		if bool(done[0]):
			return
		done[0] = true
		_cloud_save_in_flight = false
		if is_instance_valid(req):
			req.queue_free()
		if ok:
			var loop = Engine.get_main_loop()
			if loop is SceneTree:
				var wm = loop.root.get_node_or_null("WorldManager")
				if wm != null and wm.has_method("apply_cloud_sync"):
					wm.apply_cloud_sync(res_data, true, req_seq)
		if callback.is_valid():
			callback.call(ok)
		if ok and not res_data.is_empty():
			sync_completed.emit(true, res_data)
		call_deferred("_flush_pending_cloud_save")

	req.request_completed.connect(func(result: int, response_code: int, _hdrs: PackedStringArray, body: PackedByteArray):
		var success := (result == HTTPRequest.RESULT_SUCCESS and response_code == 200)
		var res_data := {}
		if success:
			var json_str := body.get_string_from_utf8()
			var test_json := JSON.new()
			if test_json.parse(json_str) == OK and typeof(test_json.data) == TYPE_DICTIONARY:
				res_data = test_json.data
		finish_cloud_save.call(success, res_data)
	)

	var watchdog := Timer.new()
	watchdog.one_shot = true
	watchdog.wait_time = 12.0
	watchdog.timeout.connect(func():
		if bool(done[0]):
			return
		if is_instance_valid(req):
			req.cancel_request()
		finish_cloud_save.call(false, {})
	)
	req.add_child(watchdog)
	watchdog.start()

	var req_err := req.request_raw(server_url + "/api/game/save", headers, HTTPClient.METHOD_POST, payload.to_utf8_buffer())
	if req_err != OK and not bool(done[0]):
		finish_cloud_save.call(false, {})


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
		"Content-Type: application/json; charset=utf-8",
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
	req.request_raw(server_url + "/api/account/delete", headers, HTTPClient.METHOD_POST, "{}".to_utf8_buffer())


# =============================================================================
# Yetkili Çevrimiçi API Çağrıları (Authoritative Server Action API)
# =============================================================================

func _is_serialized_store_endpoint(endpoint: String) -> bool:
	return endpoint in ["/api/store/use_scroll", "/api/store/buy_scroll", "/api/store/buy_resources"]


func _drain_store_req_queue() -> void:
	if _store_req_in_flight or _store_req_queue.is_empty():
		return
	var next_item := _store_req_queue.pop_front() as Dictionary
	_store_req_in_flight = true
	_dispatch_api_request(
		str(next_item.get("endpoint", "")),
		int(next_item.get("method", HTTPClient.METHOD_POST)),
		next_item.get("payload", {}) as Dictionary,
		next_item.get("callback", Callable()) as Callable,
		true
	)


func api_request(endpoint: String, method: int, payload: Dictionary = {}, callback: Callable = Callable()) -> void:
	if method == HTTPClient.METHOD_POST and _is_serialized_store_endpoint(endpoint):
		if _store_req_queue.size() >= 32:
			_store_req_queue.pop_front()
		_store_req_queue.append({
			"endpoint": endpoint,
			"method": method,
			"payload": payload.duplicate(true),
			"callback": callback,
		})
		_drain_store_req_queue()
		return
	_dispatch_api_request(endpoint, method, payload, callback, false)


func _dispatch_api_request(endpoint: String, method: int, payload: Dictionary, callback: Callable, is_store_queued: bool) -> void:
	var req := HTTPRequest.new()
	req.use_threads = not OS.has_feature("web")
	add_child(req)
	req.timeout = 10.0

	var auth = Engine.get_main_loop().root.get_node_or_null("AuthManager") if Engine.get_main_loop() is SceneTree else null
	var token: String = auth_token
	if token.is_empty() and auth != null:
		token = str(auth.auth_token)

	var headers := PackedStringArray([
		"Content-Type: application/json; charset=utf-8"
	])
	if not token.is_empty():
		headers.append("Authorization: Bearer " + token)

	var body_str := JSON.stringify(payload) if (method == HTTPClient.METHOD_POST and not payload.is_empty()) else ""
	var done := [false]

	var finish_req := func(success: bool, res_json: Dictionary):
		if bool(done[0]):
			return
		done[0] = true
		if is_instance_valid(req):
			req.queue_free()
		if callback.is_valid():
			callback.call(success, res_json)
		if is_store_queued:
			_store_req_in_flight = false
			call_deferred("_drain_store_req_queue")

	req.request_completed.connect(func(result: int, response_code: int, _hdrs: PackedStringArray, body: PackedByteArray):
		var success := (result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300)
		var res_json := {}
		var json_str := body.get_string_from_utf8()
		var test_json := JSON.new()
		if test_json.parse(json_str) == OK and typeof(test_json.data) == TYPE_DICTIONARY:
			res_json = test_json.data
		finish_req.call(success, res_json)
	)

	var watchdog := Timer.new()
	watchdog.one_shot = true
	watchdog.wait_time = 12.0
	watchdog.timeout.connect(func():
		if bool(done[0]):
			return
		if is_instance_valid(req):
			req.cancel_request()
		finish_req.call(false, {"_watchdog_timeout": true})
	)
	req.add_child(watchdog)
	watchdog.start()

	var req_err := req.request_raw(server_url + endpoint, headers, method, body_str.to_utf8_buffer()) if not body_str.is_empty() else req.request(server_url + endpoint, headers, method, "")
	if req_err != OK and not bool(done[0]):
		finish_req.call(false, {"_request_error": req_err})


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

