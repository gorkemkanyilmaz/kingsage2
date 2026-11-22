extends Node
## AuthManager — Google ve Apple ile Kimlik Doğrulama & Oturum Yönetimi.
## (Taht ve Kılıç / Çevrimiçi Giriş Sistemi)

signal auth_state_changed(is_logged_in: bool, profile: Dictionary)

const SESSION_FILE := "user://auth_session.json"
const WEB_SESSION_KEY := "tvk_auth_session"

var is_logged_in: bool = false
var auth_provider: String = "" # "google" | "apple"
var user_id: String = ""
var provider_uid: String = ""
var display_name: String = ""
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


func login_with_google(mock_name: String = "Lord Gorkem", user_email: String = "", uid: String = "") -> Dictionary:
	return complete_external_login("google", mock_name, user_email, uid)


func login_with_apple(mock_name: String = "Lord Roland", user_email: String = "", uid: String = "") -> Dictionary:
	return complete_external_login("apple", mock_name, user_email, uid)


func complete_external_login(provider: String, user_name: String, user_email: String = "", uid: String = "") -> Dictionary:
	var prov := "apple" if provider.strip_edges().to_lower() == "apple" else "google"
	auth_provider = prov
	var clean_email := user_email.strip_edges().to_lower()
	var derived := user_name.strip_edges()
	if derived.is_empty() and clean_email.contains("@"):
		derived = clean_email.split("@")[0].replace(".", " ").replace("_", " ").capitalize()
	var clean := _normalize_name(derived)
	if clean.is_empty():
		clean = "Lord Gorkem" if prov == "google" else "Lord Roland"
	display_name = clean
	if not uid.strip_edges().is_empty():
		provider_uid = uid.strip_edges()
	var uid_seed := (prov + ":" + uid.strip_edges()) if not uid.strip_edges().is_empty() else ((prov + ":" + clean_email) if not clean_email.is_empty() else (prov + ":" + display_name.to_lower()))
	user_id = prov + "_" + uid_seed.sha256_text().substr(0, 12)
	email = clean_email if not clean_email.is_empty() else (display_name.to_lower().replace(" ", ".") + ("@icloud.com" if prov == "apple" else "@gmail.com"))
	if not auth_token.begins_with("tk_tok_"):
		auth_token = ""
	is_logged_in = true

	var profile := get_profile()
	save_session()
	auth_state_changed.emit(true, profile)
	return profile


func clear_session_only() -> void:
	is_logged_in = false
	auth_provider = ""
	user_id = ""
	provider_uid = ""
	display_name = ""
	email = ""
	auth_token = ""
	identity_token = ""
	if FileAccess.file_exists(SESSION_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_FILE))
	_web_remove(WEB_SESSION_KEY)
	auth_state_changed.emit(false, {})


func clear_all_account_data() -> void:
	var loop = Engine.get_main_loop()
	if loop is SceneTree:
		var net = loop.root.get_node_or_null("NetworkManager")
		if net != null:
			net.auth_token = ""
	clear_session_only()
	if FileAccess.file_exists(KNOWN_ACCOUNTS_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(KNOWN_ACCOUNTS_FILE))
	_web_remove("tvk_account_profiles")


func logout() -> void:
	var loop = Engine.get_main_loop()
	if loop is SceneTree:
		var co = loop.root.get_node_or_null("ConqueredOverlay")
		if co != null and is_instance_valid(co):
			co.queue_free()
		var wm = loop.root.get_node_or_null("WorldManager")
		var gs_pre = loop.root.get_node_or_null("GameState")
		if is_logged_in and wm != null and gs_pre != null and gs_pre.has_active_village():
			var has_unsaved_cloud := false
			if wm.get("_last_local_mutation_unix") != null and wm.get("_last_cloud_save_unix") != null:
				has_unsaved_cloud = int(wm.get("_last_local_mutation_unix")) > int(wm.get("_last_cloud_save_unix"))
			if wm.has_method("save_active_world"):
				wm.save_active_world(has_unsaved_cloud, has_unsaved_cloud)
		var sm_pre = loop.root.get_node_or_null("SaveManager")
		if is_logged_in and gs_pre != null and gs_pre.has_active_village() and sm_pre != null and sm_pre.has_method("save_game"):
			sm_pre.save_game()
		if wm != null:
			wm.set("_suppress_reset_save", true)
			if wm.has_method("cancel_pending_cloud_poll"):
				wm.call("cancel_pending_cloud_poll")
		var nm = loop.root.get_node_or_null("NotificationManager")
		if nm != null and nm.has_method("on_user_logout"):
			nm.call("on_user_logout")
		var net = loop.root.get_node_or_null("NetworkManager")
		if net != null:
			net.auth_token = ""
			if net.has_method("cancel_background_requests"):
				net.call("cancel_background_requests")

	is_logged_in = false
	auth_provider = ""
	user_id = ""
	provider_uid = ""
	display_name = ""
	email = ""
	auth_token = ""
	identity_token = ""

	if FileAccess.file_exists(SESSION_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_FILE))
	_web_remove(WEB_SESSION_KEY)

	if loop is SceneTree:
		var gs = loop.root.get_node_or_null("GameState")
		if gs != null and gs.has_method("reset"):
			gs.reset()
		var wm_after = loop.root.get_node_or_null("WorldManager")
		if wm_after != null:
			wm_after.set("_suppress_reset_save", false)

	auth_state_changed.emit(false, {})


func get_profile() -> Dictionary:
	return {
		"is_logged_in": is_logged_in,
		"provider": auth_provider,
		"user_id": user_id,
		"provider_uid": provider_uid,
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
	provider_uid = str(data.get("provider_uid", ""))
	display_name = _normalize_name(str(data.get("name", "")))
	email = str(data.get("email", ""))
	var loaded_tok := str(data.get("token", ""))
	auth_token = loaded_tok if loaded_tok.begins_with("tk_tok_") else ""

	if is_logged_in:
		auth_state_changed.emit(true, get_profile())
	return is_logged_in


var _auth_sheet: CanvasLayer = null
var _auth_status_lbl: Label = null
var _auth_poll_timer: Timer = null
var _name_modal: CanvasLayer = null


func _dismiss_name_modal() -> void:
	if _name_modal != null and is_instance_valid(_name_modal):
		_name_modal.queue_free()
	_name_modal = null


func _dismiss_auth_sheet() -> void:
	if _auth_poll_timer != null and is_instance_valid(_auth_poll_timer):
		_auth_poll_timer.stop()
		_auth_poll_timer.queue_free()
	_auth_poll_timer = null
	_auth_status_lbl = null
	if _auth_sheet != null and is_instance_valid(_auth_sheet):
		_auth_sheet.queue_free()
	_auth_sheet = null
	if OS.has_feature("web"):
		JavaScriptBridge.eval("try{var el=document.getElementById('tvk-oauth-overlay');if(el)el.remove();window._tvkOAuthRes='';}catch(e){}", true)


func _get_server_base_url() -> String:
	var loop = Engine.get_main_loop()
	if loop is SceneTree:
		var net = loop.root.get_node_or_null("NetworkManager")
		if net != null and not str(net.server_url).strip_edges().is_empty():
			return str(net.server_url).trim_suffix("/")
	return "https://92.5.113.251.nip.io/tahtkilic"


func _show_waiting_sheet(parent_node: Node, title_text: String, status_text: String, is_apple: bool, on_cancel: Callable = Callable()) -> Label:
	_dismiss_auth_sheet()
	_auth_sheet = CanvasLayer.new()
	_auth_sheet.name = "NativeAuthWaitSheet"
	_auth_sheet.layer = 185

	var root_ctrl := Control.new()
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	_auth_sheet.add_child(root_ctrl)
	root_ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var vp_size := Vector2(1080.0, 1920.0)
	if parent_node != null and parent_node.get_viewport() != null:
		var r := parent_node.get_viewport().get_visible_rect().size
		if r.x >= 100.0 and r.y >= 100.0:
			vp_size = r

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.05, 0.84)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root_ctrl.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	root_ctrl.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(clampf(vp_size.x - 112.0, 420.0, 640.0), 250.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.12, 0.98) if is_apple else Color(0.10, 0.12, 0.18, 0.98)
	sb.border_color = Color(0.86, 0.88, 0.95, 0.92) if is_apple else Color(0.45, 0.72, 1.0, 0.95)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(22)
	sb.set_content_margin_all(26)
	card.add_theme_stylebox_override("panel", sb)
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vb)

	var FontCinzelBold = load("res://assets/fonts/Cinzel-Bold.ttf")
	var FontNunitoBold = load("res://assets/fonts/Nunito-Bold.ttf")

	var hdr := Label.new()
	hdr.text = title_text
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if FontCinzelBold != null:
		hdr.add_theme_font_override("font", FontCinzelBold)
	hdr.add_theme_font_size_override("font_size", 28)
	hdr.add_theme_color_override("font_color", Color(0.98, 0.98, 1.0) if is_apple else Color(0.75, 0.90, 1.0))
	vb.add_child(hdr)

	var status_lbl := Label.new()
	status_lbl.text = status_text
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if FontNunitoBold != null:
		status_lbl.add_theme_font_override("font", FontNunitoBold)
	status_lbl.add_theme_font_size_override("font_size", 22)
	status_lbl.add_theme_color_override("font_color", Color(0.86, 0.89, 0.94))
	vb.add_child(status_lbl)

	var btn_cancel := Button.new()
	btn_cancel.text = "İptal"
	btn_cancel.custom_minimum_size = Vector2(200, 54)
	btn_cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if FontNunitoBold != null:
		btn_cancel.add_theme_font_override("font", FontNunitoBold)
	btn_cancel.add_theme_font_size_override("font_size", 23)
	btn_cancel.pressed.connect(func():
		_dismiss_auth_sheet()
		if on_cancel.is_valid():
			on_cancel.call()
	)
	vb.add_child(btn_cancel)

	var host := parent_node.get_tree().root if (parent_node != null and parent_node.get_tree() != null) else get_tree().root
	if host != null:
		host.add_child(_auth_sheet)
	elif parent_node != null:
		parent_node.add_child(_auth_sheet)

	_auth_status_lbl = status_lbl
	return status_lbl


## Apple ID (iOS ASAuthorizationController + Face ID) veya Google Hesap OAuth doğrulama akışını açar.
func authenticate_with_provider(provider: String, suggested_name: String, parent_node: Node, on_complete: Callable = Callable()) -> void:
	var prov := provider.strip_edges().to_lower()
	if prov != "apple" and prov != "google":
		prov = "google"

	var clean_name := _normalize_name(suggested_name)
	if clean_name.is_empty():
		clean_name = "Lord Gorkem" if prov == "google" else "Lord Roland"

	# Headless birim testlerinde doğrudan oturum aç
	if DisplayServer.get_name() == "headless":
		var prof := login_with_apple(clean_name) if prov == "apple" else login_with_google(clean_name)
		if on_complete.is_valid():
			on_complete.call(prof)
		return

	var base_url := _get_server_base_url()
	var req_id := "%d_%s" % [int(Time.get_unix_time_from_system()), str(randi() % 999999)]
	var is_apple := (prov == "apple")

	if OS.get_name() == "iOS":
		_start_ios_native_auth(prov, is_apple, req_id, base_url, parent_node, on_complete)
	elif OS.has_feature("web"):
		_start_web_oauth(prov, is_apple, req_id, base_url, parent_node, on_complete)
	else:
		_start_desktop_oauth(prov, is_apple, req_id, base_url, parent_node, on_complete)


func _start_ios_native_auth(prov: String, is_apple: bool, req_id: String, base_url: String, parent_node: Node, on_complete: Callable) -> void:
	var req_path := ProjectSettings.globalize_path("user://native_auth_req.json")
	var res_path := ProjectSettings.globalize_path("user://native_auth_res.json")
	var ack_path := ProjectSettings.globalize_path("user://native_auth_ack.json")
	var home_dir := OS.get_environment("HOME").strip_edges()
	var docs_dir := home_dir.path_join("Documents") if not home_dir.is_empty() else ""
	var docs_req_path := docs_dir.path_join("native_auth_req.json") if not docs_dir.is_empty() else ""
	var docs_res_path := docs_dir.path_join("native_auth_res.json") if not docs_dir.is_empty() else ""
	var docs_ack_path := docs_dir.path_join("native_auth_ack.json") if not docs_dir.is_empty() else ""

	var cleanup_native_files := func():
		for p in [req_path, res_path, ack_path, docs_req_path, docs_res_path, docs_ack_path]:
			if not p.is_empty() and FileAccess.file_exists(p):
				DirAccess.remove_absolute(p)

	cleanup_native_files.call()

	var oauth_url := "%s/api/auth/oauth_page?provider=%s&session=%s&platform=ios" % [base_url, prov, req_id]
	var web_fallback_url := "%s/api/auth/oauth_page?provider=%s&session=%s&platform=web" % [base_url, prov, req_id]
	var req_payload := JSON.stringify({
		"req_id": req_id,
		"provider": prov,
		"oauth_url": oauth_url,
	})
	var f := FileAccess.open("user://native_auth_req.json", FileAccess.WRITE)
	if f != null:
		f.store_string(req_payload)
		f.close()
	if not docs_req_path.is_empty() and docs_req_path != req_path:
		var df := FileAccess.open(docs_req_path, FileAccess.WRITE)
		if df != null:
			df.store_string(req_payload)
			df.close()

	var title := "Apple ile Giriş Yap" if is_apple else "Google ile Oturum Aç"
	var wait_msg := (
		"Cihazınızın Apple Kimliği ve Face ID doğrulaması bekleniyor..."
		if is_apple
		else "Google hesabınızı seçmek için güvenli pencere açılıyor..."
	)
	var status_lbl := _show_waiting_sheet(parent_node, title, wait_msg, is_apple, cleanup_native_files)

	_auth_poll_timer = Timer.new()
	_auth_poll_timer.wait_time = 0.15
	var ticks := [0]
	var ack_seen := [false]
	var safari_fallback_opened := [false]
	var remote_busy := [false]
	_auth_poll_timer.timeout.connect(func():
		ticks[0] += 1
		if ticks[0] > 300:
			if _auth_poll_timer != null and is_instance_valid(_auth_poll_timer):
				_auth_poll_timer.stop()
			cleanup_native_files.call()
			if is_instance_valid(status_lbl):
				status_lbl.text = "Apple / tarayıcı doğrulaması zaman aşımına uğradı. Lütfen tekrar deneyin."
			if _auth_sheet != null and is_instance_valid(_auth_sheet):
				var vb := _auth_sheet.find_child("VBoxContainer", true, false) as VBoxContainer
				if vb != null and vb.find_child("NativeRetryBtn", false, false) == null:
					var retry_btn := Button.new()
					retry_btn.name = "NativeRetryBtn"
					retry_btn.text = "🔄 Tekrar Dene"
					retry_btn.custom_minimum_size = Vector2(220, 54)
					retry_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
					var FontNunitoBold = load("res://assets/fonts/Nunito-Bold.ttf")
					if FontNunitoBold != null:
						retry_btn.add_theme_font_override("font", FontNunitoBold)
					retry_btn.add_theme_font_size_override("font_size", 23)
					retry_btn.pressed.connect(func():
						var next_req_id := "%d_%s" % [int(Time.get_unix_time_from_system()), str(randi() % 999999)]
						_start_ios_native_auth(prov, is_apple, next_req_id, base_url, parent_node, on_complete)
					)
					vb.add_child(retry_btn)
					vb.move_child(retry_btn, maxi(0, vb.get_child_count() - 2))
			return

		if not ack_seen[0]:
			if FileAccess.file_exists("user://native_auth_ack.json") or (not docs_ack_path.is_empty() and FileAccess.file_exists(docs_ack_path)):
				ack_seen[0] = true

		# 3.6 sn içinde native bridge cevap vermezse otomatik Safari OAuth yedeğini aç + sunucuyu dinle
		if not ack_seen[0] and not safari_fallback_opened[0] and ticks[0] >= 24:
			safari_fallback_opened[0] = true
			if is_instance_valid(status_lbl):
				status_lbl.text = "Tarayıcıda " + ("Apple ID" if is_apple else "Google Hesabı") + " doğrulama ekranı açılıyor..."
			OS.shell_open(web_fallback_url)

		if safari_fallback_opened[0] and ticks[0] % 8 == 0 and not remote_busy[0]:
			_poll_oauth_endpoint(base_url, req_id, prov, remote_busy, parent_node, on_complete)

		var found_res_path := ""
		if FileAccess.file_exists("user://native_auth_res.json"):
			found_res_path = res_path
		elif not docs_res_path.is_empty() and FileAccess.file_exists(docs_res_path):
			found_res_path = docs_res_path
		if found_res_path.is_empty():
			return

		var rf := FileAccess.open(found_res_path, FileAccess.READ)
		var txt := rf.get_as_text() if rf != null else ""
		if rf != null:
			rf.close()
		for p in [res_path, docs_res_path, ack_path, docs_ack_path]:
			if not p.is_empty() and FileAccess.file_exists(p):
				DirAccess.remove_absolute(p)
		if txt.is_empty():
			return
		var jp := JSON.new()
		if jp.parse(txt) != OK or typeof(jp.data) != TYPE_DICTIONARY:
			return
		var data: Dictionary = jp.data
		if not str(data.get("req_id", "")).is_empty() and str(data.get("req_id", "")) != req_id:
			return
		if bool(data.get("ok", false)):
			var res_prov := str(data.get("provider", prov))
			var res_email := str(data.get("email", ""))
			var res_uid := str(data.get("provider_uid", ""))
			var res_id_tok := str(data.get("identity_token", ""))
			if _auth_poll_timer != null and is_instance_valid(_auth_poll_timer):
				_auth_poll_timer.stop()
			if is_instance_valid(status_lbl):
				status_lbl.text = "Apple doğrulandı — hesabınız yükleniyor..."
			var net_t := get_tree()
			if net_t != null:
				net_t.create_timer(0.25).timeout.connect(func():
					_handle_verified_identity(res_prov, res_email, res_uid, parent_node, on_complete, res_id_tok)
				)
			else:
				_handle_verified_identity(res_prov, res_email, res_uid, parent_node, on_complete, res_id_tok)
		else:
			if is_instance_valid(status_lbl):
				status_lbl.text = str(data.get("error", "Giriş iptal edildi."))
			if _auth_poll_timer != null:
				_auth_poll_timer.stop()
			var t := Timer.new()
			t.one_shot = true
			t.wait_time = 0.9
			t.timeout.connect(func(): _dismiss_auth_sheet())
			if _auth_sheet != null and is_instance_valid(_auth_sheet):
				_auth_sheet.add_child(t)
				t.start()
	)
	_auth_sheet.add_child(_auth_poll_timer)
	_auth_poll_timer.start()


func _start_web_oauth(prov: String, is_apple: bool, req_id: String, base_url: String, parent_node: Node, on_complete: Callable) -> void:
	var oauth_url := "%s/api/auth/oauth_page?provider=%s&session=%s&platform=web" % [base_url, prov, req_id]
	var title := "Apple ile Giriş Yap" if is_apple else "Google ile Oturum Aç"
	_show_waiting_sheet(parent_node, title, "Hesap penceresi üzerinden oturum açın...", is_apple)

	JavaScriptBridge.eval("""
(function(){
  try {
    var old = document.getElementById('tvk-oauth-overlay');
    if (old) old.remove();
    window._tvkOAuthRes = '';
    if (!window._tvkOAuthBound) {
      window._tvkOAuthBound = true;
      window.addEventListener('message', function(ev) {
        if (ev && ev.data && ev.data.type === 'tvk_oauth') {
          window._tvkOAuthRes = JSON.stringify(ev.data);
        }
      });
    }
    var wrap = document.createElement('div');
    wrap.id = 'tvk-oauth-overlay';
    wrap.style.cssText = 'position:fixed;inset:0;z-index:999999;background:rgba(6,8,14,0.82);backdrop-filter:blur(6px);display:flex;align-items:center;justify-content:center;padding:16px;';
    var box = document.createElement('div');
    box.style.cssText = 'position:relative;width:100%;max-width:440px;height:560px;max-height:92vh;border-radius:18px;overflow:hidden;box-shadow:0 24px 64px rgba(0,0,0,0.6);border:2px solid rgba(212,175,55,0.55);background:#12151f;';
    var closeBtn = document.createElement('button');
    closeBtn.textContent = '✕';
    closeBtn.style.cssText = 'position:absolute;top:10px;right:10px;z-index:2;width:34px;height:34px;border-radius:50%;border:none;background:rgba(0,0,0,0.55);color:#fff;font-size:18px;cursor:pointer;';
    closeBtn.onclick = function() {
      window._tvkOAuthRes = JSON.stringify({type:'tvk_oauth',ok:false,cancelled:true});
      wrap.remove();
    };
    var ifr = document.createElement('iframe');
    ifr.src = """ + JSON.stringify(oauth_url) + """;
    ifr.allow = 'publickey-credentials-get *; publickey-credentials-create *';
    ifr.style.cssText = 'width:100%;height:100%;border:none;background:transparent;';
    box.appendChild(closeBtn);
    box.appendChild(ifr);
    wrap.appendChild(box);
    document.body.appendChild(wrap);
  } catch(e) {
    window._tvkOAuthRes = JSON.stringify({type:'tvk_oauth',ok:false,error:String(e)});
  }
})();
""", true)

	_auth_poll_timer = Timer.new()
	_auth_poll_timer.wait_time = 0.2
	var ticks := [0]
	var remote_busy := [false]
	_auth_poll_timer.timeout.connect(func():
		ticks[0] += 1
		var raw_res := str(JavaScriptBridge.eval("window._tvkOAuthRes || ''", true))
		if not raw_res.is_empty():
			var jp := JSON.new()
			if jp.parse(raw_res) == OK and typeof(jp.data) == TYPE_DICTIONARY:
				var data: Dictionary = jp.data
				if bool(data.get("ok", false)):
					if _auth_poll_timer != null and is_instance_valid(_auth_poll_timer):
						_auth_poll_timer.stop()
					_handle_verified_identity(str(data.get("provider", prov)), str(data.get("email", "")), str(data.get("provider_uid", "")), parent_node, on_complete)
				else:
					_dismiss_auth_sheet()
			else:
				_dismiss_auth_sheet()
			return
		if ticks[0] % 6 == 0 and not remote_busy[0]:
			_poll_oauth_endpoint(base_url, req_id, prov, remote_busy, parent_node, on_complete)
	)
	_auth_sheet.add_child(_auth_poll_timer)
	_auth_poll_timer.start()


func _start_desktop_oauth(prov: String, is_apple: bool, req_id: String, base_url: String, parent_node: Node, on_complete: Callable) -> void:
	var oauth_url := "%s/api/auth/oauth_page?provider=%s&session=%s&platform=web" % [base_url, prov, req_id]
	var title := "Apple ile Giriş Yap" if is_apple else "Google ile Oturum Aç"
	_show_waiting_sheet(parent_node, title, "Tarayıcıda " + ("Apple ID" if is_apple else "Google Hesabı") + " girişini tamamlayın...", is_apple)
	OS.shell_open(oauth_url)

	_auth_poll_timer = Timer.new()
	_auth_poll_timer.wait_time = 1.1
	var remote_busy := [false]
	_auth_poll_timer.timeout.connect(func():
		if not remote_busy[0]:
			_poll_oauth_endpoint(base_url, req_id, prov, remote_busy, parent_node, on_complete)
	)
	_auth_sheet.add_child(_auth_poll_timer)
	_auth_poll_timer.start()


func _poll_oauth_endpoint(base_url: String, req_id: String, prov: String, remote_busy: Array, parent_node: Node = null, on_complete: Callable = Callable()) -> void:
	if _auth_sheet == null or not is_instance_valid(_auth_sheet):
		return
	remote_busy[0] = true
	var req := HTTPRequest.new()
	add_child(req)
	req.timeout = 6.0
	req.request_completed.connect(func(result: int, code: int, _hdrs: PackedStringArray, body: PackedByteArray):
		remote_busy[0] = false
		if result == HTTPRequest.RESULT_SUCCESS and code == 200:
			var jp := JSON.new()
			if jp.parse(body.get_string_from_utf8()) == OK and typeof(jp.data) == TYPE_DICTIONARY:
				var payload: Dictionary = jp.data
				var st := str(payload.get("status", "pending"))
				var data: Dictionary = payload.get("data", {})
				if st == "done" and bool(data.get("ok", false)):
					if _auth_poll_timer != null and is_instance_valid(_auth_poll_timer):
						_auth_poll_timer.stop()
					_handle_verified_identity(str(data.get("provider", prov)), str(data.get("email", "")), str(data.get("provider_uid", "")), parent_node, on_complete)
				elif st == "cancelled":
					_dismiss_auth_sheet()
		req.queue_free()
	)
	req.request("%s/api/auth/oauth_poll?session=%s" % [base_url, req_id])


var identity_token: String = ""
const KNOWN_ACCOUNTS_FILE := "user://account_profiles.json"


func _kb_dismiss(target: Control = null) -> void:
	var loop := Engine.get_main_loop()
	var gc = loop.root.get_node_or_null("GameConfig") if loop is SceneTree else null
	if gc != null and gc.has_method("dismiss_keyboard_for"):
		gc.call("dismiss_keyboard_for", target)
	elif target != null and is_instance_valid(target) and target.has_focus():
		target.release_focus()


func _kb_bind(ctrl: Control, on_submit: Callable = Callable()) -> void:
	var loop := Engine.get_main_loop()
	var gc = loop.root.get_node_or_null("GameConfig") if loop is SceneTree else null
	if gc != null and gc.has_method("bind_keyboard_dismiss"):
		gc.call("bind_keyboard_dismiss", ctrl, on_submit)
	elif ctrl is LineEdit and on_submit.is_valid():
		(ctrl as LineEdit).text_submitted.connect(on_submit)


func _cache_known_account(prov: String, raw_uid: String, raw_email: String, disp_name: String, srv_uid: String) -> void:
	var store := _load_known_accounts()
	var entry := {
		"provider": prov,
		"display_name": disp_name,
		"email": raw_email,
		"user_id": srv_uid,
		"provider_uid": raw_uid,
	}
	for k in [raw_uid, srv_uid, raw_email.strip_edges().to_lower()]:
		if not k.is_empty():
			store[prov + ":" + k] = entry
	var f := FileAccess.open(KNOWN_ACCOUNTS_FILE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(store))
		f.close()


func _load_known_accounts() -> Dictionary:
	if not FileAccess.file_exists(KNOWN_ACCOUNTS_FILE):
		return {}
	var f := FileAccess.open(KNOWN_ACCOUNTS_FILE, FileAccess.READ)
	var txt := f.get_as_text() if f != null else ""
	if f != null:
		f.close()
	var jp := JSON.new()
	if not txt.is_empty() and jp.parse(txt) == OK and typeof(jp.data) == TYPE_DICTIONARY:
		return jp.data as Dictionary
	return {}


func _lookup_known_account(prov: String, raw_uid: String, raw_email: String) -> Dictionary:
	var store := _load_known_accounts()
	for k in [raw_uid, raw_email.strip_edges().to_lower()]:
		if not k.is_empty() and store.has(prov + ":" + k) and typeof(store[prov + ":" + k]) == TYPE_DICTIONARY:
			return store[prov + ":" + k] as Dictionary
	return {}


func _show_account_check_retry_sheet(prov: String, clean_email: String, clean_uid: String, parent_node: Node, on_complete: Callable, raw_id_tok: String) -> void:
	var is_apple := (prov == "apple")
	var title := "Apple Hesabı Bağlanamadı" if is_apple else "Google Hesabı Bağlanamadı"
	_show_waiting_sheet(parent_node, title, "Sunucuyla bağlantı zaman aşımına uğradı. Hesabınız kontrol edilemedi; lütfen tekrar deneyin.", is_apple)
	if _auth_sheet != null and is_instance_valid(_auth_sheet):
		var vb := _auth_sheet.find_child("VBoxContainer", true, false) as VBoxContainer
		if vb != null:
			var retry_btn := Button.new()
			retry_btn.text = "🔄 Tekrar Dene"
			retry_btn.custom_minimum_size = Vector2(220, 54)
			retry_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			var FontNunitoBold = load("res://assets/fonts/Nunito-Bold.ttf")
			if FontNunitoBold != null:
				retry_btn.add_theme_font_override("font", FontNunitoBold)
			retry_btn.add_theme_font_size_override("font_size", 23)
			retry_btn.pressed.connect(func():
				_handle_verified_identity(prov, clean_email, clean_uid, parent_node, on_complete, raw_id_tok)
			)
			vb.add_child(retry_btn)
			vb.move_child(retry_btn, maxi(0, vb.get_child_count() - 2))


func _handle_verified_identity(prov: String, raw_email: String, raw_uid: String, parent_node: Node, on_complete: Callable, raw_id_tok: String = "") -> void:
	var clean_prov := "apple" if prov.strip_edges().to_lower() == "apple" else "google"
	var clean_email := raw_email.strip_edges().to_lower()
	var clean_uid := raw_uid.strip_edges()
	identity_token = raw_id_tok.strip_edges()
	if clean_uid.is_empty() and not clean_email.is_empty():
		clean_uid = clean_prov + "_" + (clean_prov + ":" + clean_email).sha256_text().substr(0, 14)

	var loop = Engine.get_main_loop()
	var net = loop.root.get_node_or_null("NetworkManager") if loop is SceneTree else null
	if _auth_status_lbl != null and is_instance_valid(_auth_status_lbl):
		_auth_status_lbl.text = "Sunucudan köy verileriniz alınıyor..."
	if net != null and net.has_method("check_account_online"):
		net.check_account_online(clean_prov, clean_email, clean_uid, func(success: bool, res_data: Dictionary):
			if success and bool(res_data.get("exists", false)):
				var existing_name := str(res_data.get("display_name", "")).strip_edges()
				var resolved_email := str(res_data.get("email", clean_email))
				var resolved_uid := str(res_data.get("user_id", clean_uid))
				var srv_token := str(res_data.get("token", "")).strip_edges()
				auth_provider = clean_prov
				email = resolved_email
				user_id = resolved_uid
				provider_uid = str(res_data.get("provider_uid", clean_uid)).strip_edges()
				display_name = _normalize_name(existing_name) if not existing_name.is_empty() else "Lord Oyuncu"
				_cache_known_account(clean_prov, provider_uid if not provider_uid.is_empty() else clean_uid, resolved_email, display_name, resolved_uid)

				if not srv_token.is_empty():
					_dismiss_auth_sheet()
					# check_account zaten geçerli token + cloud_state + server_village döndürdü; ikinci round-trip gerekmez!
					net.auth_token = srv_token
					net.is_server_reachable = true
					auth_token = srv_token
					is_logged_in = true
					save_session()
					auth_state_changed.emit(true, get_profile())
					var wm = loop.root.get_node_or_null("WorldManager") if loop is SceneTree else null
					if wm != null and wm.has_method("apply_cloud_sync"):
						wm.apply_cloud_sync(res_data)
					net.server_status_changed.emit(true, res_data)
					net.auth_completed.emit(true, res_data)
					var prof := get_profile()
					prof["_server_synced"] = true
					if on_complete.is_valid():
						on_complete.call(prof)
					return

				net.login_online(clean_prov, existing_name, func(l_ok: bool, _l_data: Dictionary):
					_dismiss_auth_sheet()
					if not l_ok:
						complete_external_login(clean_prov, existing_name, resolved_email, resolved_uid)
					var prof := get_profile()
					prof["_server_synced"] = l_ok
					if on_complete.is_valid():
						on_complete.call(prof)
				, 0, resolved_email, clean_uid)
				return

			if not success:
				# Sunucu doğrulanamadıysa kullanıcıyı yeni oyuncu gibi isim ekranına atma!
				var cached := _lookup_known_account(clean_prov, clean_uid, clean_email)
				var cached_name := str(cached.get("display_name", "")).strip_edges() if not cached.is_empty() else ""
				if not cached_name.is_empty():
					var wm_chk = loop.root.get_node_or_null("WorldManager") if loop is SceneTree else null
					var has_local_v := false
					if wm_chk != null and wm_chk.has_method("has_player_village"):
						for wid_c in range(1, 11):
							if wm_chk.has_player_village(wid_c, cached_name):
								has_local_v = true
								break
					if has_local_v:
						_dismiss_auth_sheet()
						provider_uid = clean_uid
						var prof_c := complete_external_login(clean_prov, cached_name, str(cached.get("email", clean_email)), clean_uid)
						if not str(cached.get("user_id", "")).is_empty():
							user_id = str(cached.get("user_id"))
							save_session()
						prof_c["_server_synced"] = false
						if on_complete.is_valid():
							on_complete.call(prof_c)
						return
					if _auth_status_lbl != null and is_instance_valid(_auth_status_lbl):
						_auth_status_lbl.text = "Sunucu ile yeniden bağlanılıyor..."
					net.login_online(clean_prov, cached_name, func(l_ok2: bool, _l_data2: Dictionary):
						if l_ok2:
							_dismiss_auth_sheet()
							var prof_l := get_profile()
							prof_l["_server_synced"] = true
							if on_complete.is_valid():
								on_complete.call(prof_l)
						else:
							_show_account_check_retry_sheet(clean_prov, clean_email, clean_uid, parent_node, on_complete, identity_token)
					, 1, str(cached.get("email", clean_email)), clean_uid)
					return
				_show_account_check_retry_sheet(clean_prov, clean_email, clean_uid, parent_node, on_complete, identity_token)
				return

			_dismiss_auth_sheet()
			_show_lord_name_prompt_modal(clean_prov, clean_email, clean_uid, parent_node, on_complete)
		, 0, identity_token)
	else:
		_dismiss_auth_sheet()
		_show_lord_name_prompt_modal(clean_prov, clean_email, clean_uid, parent_node, on_complete)


func _show_lord_name_prompt_modal(prov: String, clean_email: String, clean_uid: String, parent_node: Node, on_complete: Callable) -> void:
	_dismiss_name_modal()
	_dismiss_auth_sheet()

	_name_modal = CanvasLayer.new()
	_name_modal.name = "LordNamePromptModal"
	_name_modal.layer = 190

	var root_ctrl := Control.new()
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	_name_modal.add_child(root_ctrl)
	root_ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var vp_size := Vector2(1080.0, 1920.0)
	if parent_node != null and parent_node.get_viewport() != null:
		var r := parent_node.get_viewport().get_visible_rect().size
		if r.x >= 100.0 and r.y >= 100.0:
			vp_size = r

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.05, 0.86)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root_ctrl.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	root_ctrl.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(clampf(vp_size.x - 96.0, 440.0, 680.0), 340.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.08, 0.12, 0.99)
	sb.border_color = Color(0.84, 0.68, 0.28, 0.96)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(22)
	sb.set_content_margin_all(28)
	card.add_theme_stylebox_override("panel", sb)
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 15)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vb)

	var FontCinzelBold = load("res://assets/fonts/Cinzel-Bold.ttf")
	var FontNunitoBold = load("res://assets/fonts/Nunito-Bold.ttf")

	var hdr := Label.new()
	hdr.text = "HÜKÜMDAR İSMİNİZİ BELİRLEYİN"
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if FontCinzelBold != null:
		hdr.add_theme_font_override("font", FontCinzelBold)
	hdr.add_theme_font_size_override("font_size", 29)
	hdr.add_theme_color_override("font_color", Color(1.0, 0.90, 0.58))
	vb.add_child(hdr)

	var sub := Label.new()
	sub.text = "Diyarda tanınacağınız hükümdar adınızı yazın.\nAynı isim başka bir lord tarafından alınmamış olmalıdır."
	if not clean_email.is_empty():
		sub.text += "\nHesap: " + clean_email
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if FontNunitoBold != null:
		sub.add_theme_font_override("font", FontNunitoBold)
	sub.add_theme_font_size_override("font_size", 21)
	sub.add_theme_color_override("font_color", Color(0.86, 0.82, 0.75))
	vb.add_child(sub)

	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "Örn: Alparslan veya Lord Fatih"
	name_edit.max_length = 28
	name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_edit.custom_minimum_size = Vector2(0, 62)
	if FontNunitoBold != null:
		name_edit.add_theme_font_override("font", FontNunitoBold)
	name_edit.add_theme_font_size_override("font_size", 26)
	var inp_sb := StyleBoxFlat.new()
	inp_sb.bg_color = Color(0.05, 0.05, 0.08, 1.0)
	inp_sb.border_color = Color(0.68, 0.54, 0.24, 0.9)
	inp_sb.set_border_width_all(2)
	inp_sb.set_corner_radius_all(12)
	inp_sb.set_content_margin_all(12)
	name_edit.add_theme_stylebox_override("normal", inp_sb)
	name_edit.add_theme_stylebox_override("focus", inp_sb)
	name_edit.add_theme_color_override("font_color", Color(0.98, 0.96, 0.90))
	name_edit.add_theme_color_override("font_placeholder_color", Color(0.55, 0.52, 0.48))
	vb.add_child(name_edit)

	var err_lbl := Label.new()
	err_lbl.text = ""
	err_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	err_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if FontNunitoBold != null:
		err_lbl.add_theme_font_override("font", FontNunitoBold)
	err_lbl.add_theme_font_size_override("font_size", 21)
	err_lbl.add_theme_color_override("font_color", Color(1.0, 0.42, 0.36))
	vb.add_child(err_lbl)

	var btn_confirm := Button.new()
	btn_confirm.text = "Diyara Adım At"
	btn_confirm.custom_minimum_size = Vector2(0, 64)
	btn_confirm.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if FontCinzelBold != null:
		btn_confirm.add_theme_font_override("font", FontCinzelBold)
	btn_confirm.add_theme_font_size_override("font_size", 26)
	var ok_sb := StyleBoxFlat.new()
	ok_sb.bg_color = Color(0.64, 0.46, 0.14, 1.0)
	ok_sb.border_color = Color(0.98, 0.84, 0.42, 1.0)
	ok_sb.set_border_width_all(2)
	ok_sb.set_corner_radius_all(14)
	ok_sb.set_content_margin_all(12)
	btn_confirm.add_theme_stylebox_override("normal", ok_sb)
	btn_confirm.add_theme_color_override("font_color", Color(1.0, 0.97, 0.88))
	var ok_hover := ok_sb.duplicate() as StyleBoxFlat
	ok_hover.bg_color = Color(0.75, 0.55, 0.18, 1.0)
	btn_confirm.add_theme_stylebox_override("hover", ok_hover)
	vb.add_child(btn_confirm)

	var btn_cancel := Button.new()
	btn_cancel.text = "Vazgeç"
	btn_cancel.custom_minimum_size = Vector2(180, 48)
	btn_cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if FontNunitoBold != null:
		btn_cancel.add_theme_font_override("font", FontNunitoBold)
	btn_cancel.add_theme_font_size_override("font_size", 21)
	btn_cancel.pressed.connect(func():
		_kb_dismiss(name_edit)
		_dismiss_name_modal()
	)
	vb.add_child(btn_cancel)

	dim.gui_input.connect(func(ev: InputEvent):
		var tapped := (ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed) or (ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed)
		if tapped:
			_kb_dismiss(name_edit)
	)

	var submit_fn := func():
		_kb_dismiss(name_edit)
		var chosen := name_edit.text.strip_edges()
		if chosen.length() < 2:
			err_lbl.text = "⚠️ Lütfen en az 2 karakterli bir Hükümdar ismi girin."
			return
		var norm := _normalize_name(chosen)
		if norm.length() < 4:
			err_lbl.text = "⚠️ Lütfen geçerli bir Hükümdar ismi girin."
			return
		btn_confirm.disabled = true
		btn_confirm.text = "Bağlanıyor..."
		err_lbl.text = ""
		var loop = Engine.get_main_loop()
		var net = loop.root.get_node_or_null("NetworkManager") if loop is SceneTree else null
		if net != null and net.has_method("login_online"):
			net.login_online(prov, norm, func(ok: bool, res_data: Dictionary):
				if not is_instance_valid(_name_modal):
					return
				if ok:
					_cache_known_account(prov, clean_uid, clean_email, str(res_data.get("display_name", norm)), str(res_data.get("user_id", "")))
					_dismiss_name_modal()
					var prof := get_profile()
					prof["_server_synced"] = true
					if on_complete.is_valid():
						on_complete.call(prof)
					return
				btn_confirm.disabled = false
				btn_confirm.text = "Diyara Adım At"
				var http_code := int(res_data.get("_http_code", 0))
				var err_code := str(res_data.get("error_code", ""))
				var detail := str(res_data.get("detail", ""))
				if http_code == 409 or err_code == "NAME_TAKEN":
					err_lbl.text = "⚠️ " + (detail if not detail.is_empty() else "Bu Lord ismi daha önce alınmış! Lütfen başka bir Lord ismi seçin.")
				elif not detail.is_empty():
					err_lbl.text = "⚠️ " + detail
				else:
					err_lbl.text = "⚠️ Sunucuya bağlanılamadı. Lütfen tekrar deneyin."
			, 0, clean_email, clean_uid)
		else:
			_dismiss_name_modal()
			var prof := complete_external_login(prov, norm, clean_email, clean_uid)
			if on_complete.is_valid():
				on_complete.call(prof)

	btn_confirm.pressed.connect(submit_fn)
	_kb_bind(name_edit, func(_txt: String): submit_fn.call())

	var host := parent_node.get_tree().root if (parent_node != null and parent_node.get_tree() != null) else get_tree().root
	if host != null:
		host.add_child(_name_modal)
	elif parent_node != null:
		parent_node.add_child(_name_modal)
	name_edit.call_deferred("grab_focus")
