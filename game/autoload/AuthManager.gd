extends Node
## AuthManager — Google ve Apple ile Kimlik Doğrulama & Oturum Yönetimi.
## (Taht ve Kılıç / Çevrimiçi Giriş Sistemi)

signal auth_state_changed(is_logged_in: bool, profile: Dictionary)

const SESSION_FILE := "user://auth_session.json"
const WEB_SESSION_KEY := "tvk_auth_session"

var is_logged_in: bool = false
var auth_provider: String = "" # "google" | "apple"
var user_id: String = ""
var display_name: String = "Lord Gorkem"
var email: String = ""
var auth_token: String = ""


func _ready() -> void:
	load_session()


func _normalize_name(raw_name: String) -> String:
	var n := raw_name.strip_edges()
	while n.contains("  "):
		n = n.replace("  ", " ")
	while n.length() >= 10 and n.substr(0, 10).to_lower() == "lord lord ":
		n = n.substr(5).strip_edges()
	if n.is_empty():
		return ""
	var low := n.to_lower()
	if low.begins_with("lord "):
		n = "Lord " + n.substr(5).strip_edges()
	elif not (low.begins_with("kral ") or low.begins_with("baron ") or low.begins_with("kont ") or low.begins_with("dük ") or low.begins_with("duk ") or low.begins_with("prens ")):
		n = "Lord " + n
	return n


func _web_set(key: String, val: String) -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("try{window.localStorage.setItem(" + JSON.stringify(key) + "," + JSON.stringify(val) + ");if(typeof FS!=='undefined'&&FS.syncfs){FS.syncfs(false,function(){});}}catch(e){}", true)


func _web_get(key: String) -> String:
	if not OS.has_feature("web"):
		return ""
	var res = JavaScriptBridge.eval("(function(){try{var v=window.localStorage.getItem(" + JSON.stringify(key) + ");return typeof v==='string'?v:'';}catch(e){return '';}})()", true)
	return str(res) if typeof(res) == TYPE_STRING else ""


func _web_remove(key: String) -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("try{window.localStorage.removeItem(" + JSON.stringify(key) + ");if(typeof FS!=='undefined'&&FS.syncfs){FS.syncfs(false,function(){});}}catch(e){}", true)


func login_with_google(mock_name: String = "Lord Gorkem") -> Dictionary:
	auth_provider = "google"
	var clean := _normalize_name(mock_name)
	if clean.is_empty():
		clean = "Lord Gorkem"
	display_name = clean
	user_id = "google_" + ("google:" + display_name.to_lower()).sha256_text().substr(0, 12)
	email = display_name.to_lower().replace(" ", ".") + "@gmail.com"
	auth_token = "goog_tok_" + str(randi() % 999999)
	is_logged_in = true

	var profile := get_profile()
	save_session()
	auth_state_changed.emit(true, profile)
	return profile


func login_with_apple(mock_name: String = "Lord Roland") -> Dictionary:
	auth_provider = "apple"
	var clean := _normalize_name(mock_name)
	if clean.is_empty():
		clean = "Lord Roland"
	display_name = clean
	user_id = "apple_" + ("apple:" + display_name.to_lower()).sha256_text().substr(0, 12)
	email = display_name.to_lower().replace(" ", ".") + "@icloud.com"
	auth_token = "appl_tok_" + str(randi() % 999999)
	is_logged_in = true

	var profile := get_profile()
	save_session()
	auth_state_changed.emit(true, profile)
	return profile


func logout() -> void:
	var loop = Engine.get_main_loop()
	if loop is SceneTree:
		var wm = loop.root.get_node_or_null("WorldManager")
		if is_logged_in and wm != null and wm.has_method("save_active_world"):
			wm.save_active_world()

	is_logged_in = false
	auth_provider = ""
	user_id = ""
	display_name = ""
	email = ""
	auth_token = ""

	if FileAccess.file_exists(SESSION_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_FILE))
	_web_remove(WEB_SESSION_KEY)

	if loop is SceneTree:
		var gs = loop.root.get_node_or_null("GameState")
		if gs != null and gs.has_method("reset"):
			gs.reset()

	auth_state_changed.emit(false, {})


func get_profile() -> Dictionary:
	return {
		"is_logged_in": is_logged_in,
		"provider": auth_provider,
		"user_id": user_id,
		"name": display_name,
		"email": email,
		"token": auth_token
	}


func save_session() -> void:
	var data := get_profile()
	var json_str := JSON.stringify(data)
	var file := FileAccess.open(SESSION_FILE, FileAccess.WRITE)
	if file != null:
		file.store_string(json_str)
		file.close()
	_web_set(WEB_SESSION_KEY, json_str)


func load_session() -> bool:
	var text := ""
	if FileAccess.file_exists(SESSION_FILE):
		var file := FileAccess.open(SESSION_FILE, FileAccess.READ)
		if file != null:
			text = file.get_as_text()
			file.close()
	if text.is_empty():
		text = _web_get(WEB_SESSION_KEY)
		if not text.is_empty():
			var mirror := FileAccess.open(SESSION_FILE, FileAccess.WRITE)
			if mirror != null:
				mirror.store_string(text)
				mirror.close()
	if text.is_empty():
		return false

	var test_json_conv := JSON.new()
	var error := test_json_conv.parse(text)
	if error != OK or typeof(test_json_conv.data) != TYPE_DICTIONARY:
		return false

	var data: Dictionary = test_json_conv.data
	is_logged_in = bool(data.get("is_logged_in", false))
	auth_provider = str(data.get("provider", ""))
	user_id = str(data.get("user_id", ""))
	display_name = _normalize_name(str(data.get("name", "")))
	email = str(data.get("email", ""))
	auth_token = str(data.get("token", ""))

	if is_logged_in:
		auth_state_changed.emit(true, get_profile())
	return is_logged_in
