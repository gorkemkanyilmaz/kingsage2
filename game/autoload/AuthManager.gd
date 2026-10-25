extends Node
## AuthManager — Google ve Apple ile Kimlik Doğrulama & Oturum Yönetimi.
## (Taht ve Kılıç / Çevrimiçi Giriş Sistemi)

signal auth_state_changed(is_logged_in: bool, profile: Dictionary)

const SESSION_FILE := "user://auth_session.json"

var is_logged_in: bool = false
var auth_provider: String = "" # "google" | "apple"
var user_id: String = ""
var display_name: String = "Lord Gorkem"
var email: String = ""
var auth_token: String = ""


func _ready() -> void:
	load_session()


func login_with_google(mock_name: String = "Lord Gorkem") -> Dictionary:
	auth_provider = "google"
	user_id = "google_" + str(Time.get_unix_time_from_system()).sha256_text().substr(0, 12)
	display_name = mock_name
	email = mock_name.to_lower().replace(" ", ".") + "@gmail.com"
	auth_token = "goog_tok_" + str(randi() % 999999)
	is_logged_in = true

	var profile := get_profile()
	save_session()
	auth_state_changed.emit(true, profile)
	return profile


func login_with_apple(mock_name: String = "Lord Roland") -> Dictionary:
	auth_provider = "apple"
	user_id = "apple_" + str(Time.get_unix_time_from_system()).sha256_text().substr(0, 12)
	display_name = mock_name
	email = mock_name.to_lower().replace(" ", ".") + "@icloud.com"
	auth_token = "appl_tok_" + str(randi() % 999999)
	is_logged_in = true

	var profile := get_profile()
	save_session()
	auth_state_changed.emit(true, profile)
	return profile


func logout() -> void:
	is_logged_in = false
	auth_provider = ""
	user_id = ""
	display_name = ""
	email = ""
	auth_token = ""

	if FileAccess.file_exists(SESSION_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_FILE))

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
	var file := FileAccess.open(SESSION_FILE, FileAccess.WRITE)
	if file != null:
		var data := get_profile()
		file.store_string(JSON.stringify(data))
		file.close()


func load_session() -> bool:
	if not FileAccess.file_exists(SESSION_FILE):
		return false
	var file := FileAccess.open(SESSION_FILE, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	file.close()

	var test_json_conv := JSON.new()
	var error := test_json_conv.parse(text)
	if error != OK:
		return false

	var data: Dictionary = test_json_conv.data
	is_logged_in = bool(data.get("is_logged_in", false))
	auth_provider = str(data.get("provider", ""))
	user_id = str(data.get("user_id", ""))
	display_name = str(data.get("name", ""))
	email = str(data.get("email", ""))
	auth_token = str(data.get("token", ""))

	if is_logged_in:
		auth_state_changed.emit(true, get_profile())
	return is_logged_in
