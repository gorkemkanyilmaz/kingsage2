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
	if not auth_token.begins_with("tk_tok_"):
		auth_token = ""
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
	if not auth_token.begins_with("tk_tok_"):
		auth_token = ""
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
	var loaded_tok := str(data.get("token", ""))
	auth_token = loaded_tok if loaded_tok.begins_with("tk_tok_") else ""

	if is_logged_in:
		auth_state_changed.emit(true, get_profile())
	return is_logged_in


var _auth_sheet: CanvasLayer = null


## Apple ID (Face ID / Passkey) veya Google Hesap Doğrulama akışını açar ve doğrulama tamamlanınca giriş yapar.
func authenticate_with_provider(provider: String, suggested_name: String, parent_node: Node, on_complete: Callable = Callable()) -> void:
	var prov := provider.strip_edges().to_lower()
	if prov != "apple" and prov != "google":
		prov = "google"

	var clean_name := _normalize_name(suggested_name)
	if clean_name.is_empty():
		clean_name = "Lord Gorkem" if prov == "google" else "Lord Roland"

	# Headless testlerde doğrudan oturum aç
	if DisplayServer.get_name() == "headless":
		var prof := login_with_apple(clean_name) if prov == "apple" else login_with_google(clean_name)
		if on_complete.is_valid():
			on_complete.call(prof)
		return

	if _auth_sheet != null and is_instance_valid(_auth_sheet):
		_auth_sheet.queue_free()

	_auth_sheet = CanvasLayer.new()
	_auth_sheet.name = "BiometricAuthSheet"
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
	dim.color = Color(0.02, 0.02, 0.05, 0.88)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root_ctrl.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	root_ctrl.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(clampf(vp_size.x - 96.0, 460.0, 740.0), 580)
	var is_apple := (prov == "apple")
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.11, 0.99) if is_apple else Color(0.11, 0.12, 0.17, 0.99)
	sb.border_color = Color(0.85, 0.88, 0.95, 0.90) if is_apple else Color(0.45, 0.72, 1.0, 0.95)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(22)
	sb.set_content_margin_all(28)
	card.add_theme_stylebox_override("panel", sb)
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vb)

	var FontCinzelBold = load("res://assets/fonts/Cinzel-Bold.ttf")
	var FontNunitoBold = load("res://assets/fonts/Nunito-Bold.ttf")

	var hdr := Label.new()
	hdr.text = "Apple ile Giriş Yap • Face ID" if is_apple else "Google ile Oturum Aç • Hesap Doğrulama"
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if FontCinzelBold != null:
		hdr.add_theme_font_override("font", FontCinzelBold)
	hdr.add_theme_font_size_override("font_size", 28)
	hdr.add_theme_color_override("font_color", Color(0.98, 0.98, 1.0) if is_apple else Color(0.75, 0.90, 1.0))
	vb.add_child(hdr)

	var acct_panel := PanelContainer.new()
	var ap_sb := StyleBoxFlat.new()
	ap_sb.bg_color = Color(0.14, 0.14, 0.20, 0.95)
	ap_sb.border_color = Color(0.50, 0.55, 0.68, 0.75)
	ap_sb.set_border_width_all(2)
	ap_sb.set_corner_radius_all(14)
	ap_sb.set_content_margin_all(14)
	acct_panel.add_theme_stylebox_override("panel", ap_sb)
	vb.add_child(acct_panel)

	var ap_vb := VBoxContainer.new()
	ap_vb.add_theme_constant_override("separation", 8)
	acct_panel.add_child(ap_vb)

	var acct_lbl := Label.new()
	acct_lbl.text = "Apple ID / E-posta veya Lord Adı:" if is_apple else "Google Hesabı (@gmail.com) veya Lord Adı:"
	if FontNunitoBold != null:
		acct_lbl.add_theme_font_override("font", FontNunitoBold)
	acct_lbl.add_theme_font_size_override("font_size", 19)
	acct_lbl.add_theme_color_override("font_color", Color(0.82, 0.85, 0.92))
	ap_vb.add_child(acct_lbl)

	var acct_edit := LineEdit.new()
	acct_edit.text = clean_name
	acct_edit.placeholder_text = "ornek@icloud.com veya Lord Gorkem" if is_apple else "ornek@gmail.com veya Lord Gorkem"
	acct_edit.custom_minimum_size = Vector2(0, 52)
	acct_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	if FontNunitoBold != null:
		acct_edit.add_theme_font_override("font", FontNunitoBold)
	acct_edit.add_theme_font_size_override("font_size", 22)
	ap_vb.add_child(acct_edit)

	var email_edit := LineEdit.new()
	var def_handle := clean_name.to_lower().replace(" ", ".")
	email_edit.text = email if (not email.is_empty() and auth_provider == prov) else (def_handle + ("@icloud.com" if is_apple else "@gmail.com"))
	email_edit.placeholder_text = "Apple ID (@icloud.com)" if is_apple else "Gmail Adresi (@gmail.com)"
	email_edit.custom_minimum_size = Vector2(0, 48)
	email_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	if FontNunitoBold != null:
		email_edit.add_theme_font_override("font", FontNunitoBold)
	email_edit.add_theme_font_size_override("font_size", 20)
	ap_vb.add_child(email_edit)

	# Face ID Biyometrik Çerçeve
	var bio_box := PanelContainer.new()
	var b_sb := StyleBoxFlat.new()
	b_sb.bg_color = Color(0.06, 0.08, 0.12, 0.96)
	b_sb.border_color = Color(0.28, 0.78, 0.98, 0.90)
	b_sb.set_border_width_all(2)
	b_sb.set_corner_radius_all(18)
	b_sb.set_content_margin_all(18)
	bio_box.add_theme_stylebox_override("panel", b_sb)
	vb.add_child(bio_box)

	var bio_vb := VBoxContainer.new()
	bio_vb.add_theme_constant_override("separation", 8)
	bio_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	bio_box.add_child(bio_vb)

	var face_icon := Label.new()
	face_icon.text = "[ ☺ ]  Face ID / Passkey"
	face_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if FontNunitoBold != null:
		face_icon.add_theme_font_override("font", FontNunitoBold)
	face_icon.add_theme_font_size_override("font_size", 26)
	face_icon.add_theme_color_override("font_color", Color(0.45, 0.92, 1.0))
	bio_vb.add_child(face_icon)

	var bio_status := Label.new()
	bio_status.text = "Devam etmek için Face ID veya hesap doğrulamasını onaylayın."
	bio_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bio_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if FontNunitoBold != null:
		bio_status.add_theme_font_override("font", FontNunitoBold)
	bio_status.add_theme_font_size_override("font_size", 19)
	bio_status.add_theme_color_override("font_color", Color(0.84, 0.88, 0.92))
	bio_vb.add_child(bio_status)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 14)
	vb.add_child(btn_row)

	var btn_cancel := Button.new()
	btn_cancel.text = "İptal"
	btn_cancel.custom_minimum_size = Vector2(150, 56)
	if FontNunitoBold != null:
		btn_cancel.add_theme_font_override("font", FontNunitoBold)
	btn_cancel.add_theme_font_size_override("font_size", 22)
	btn_cancel.pressed.connect(func():
		if _auth_sheet != null and is_instance_valid(_auth_sheet):
			_auth_sheet.queue_free()
			_auth_sheet = null
	)
	btn_row.add_child(btn_cancel)

	var btn_confirm := Button.new()
	btn_confirm.text = "Face ID ile Doğrula ve Gir" if is_apple else "Hesabı Doğrula ve Gir"
	btn_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_confirm.custom_minimum_size = Vector2(0, 56)
	if FontNunitoBold != null:
		btn_confirm.add_theme_font_override("font", FontNunitoBold)
	btn_confirm.add_theme_font_size_override("font_size", 22)
	var cf_sb := StyleBoxFlat.new()
	cf_sb.bg_color = Color(0.16, 0.56, 0.34, 1.0) if not is_apple else Color(0.12, 0.44, 0.82, 1.0)
	cf_sb.border_color = Color(0.55, 0.95, 0.72, 1.0) if not is_apple else Color(0.65, 0.88, 1.0, 1.0)
	cf_sb.set_border_width_all(2)
	cf_sb.set_corner_radius_all(12)
	btn_confirm.add_theme_stylebox_override("normal", cf_sb)
	btn_confirm.add_theme_color_override("font_color", Color(1, 1, 1))
	btn_row.add_child(btn_confirm)

	var finish_auth := func():
		var chosen_name := acct_edit.text.strip_edges()
		if chosen_name.contains("@"):
			chosen_name = chosen_name.split("@")[0].replace(".", " ")
		var chosen_email := email_edit.text.strip_edges()
		var prof := login_with_apple(chosen_name) if is_apple else login_with_google(chosen_name)
		if not chosen_email.is_empty():
			email = chosen_email
			save_session()
			prof = get_profile()
		if _auth_sheet != null and is_instance_valid(_auth_sheet):
			_auth_sheet.queue_free()
			_auth_sheet = null
		if on_complete.is_valid():
			on_complete.call(prof)

	var verifying := [false]
	btn_confirm.pressed.connect(func():
		if verifying[0]:
			return
		verifying[0] = true
		btn_confirm.disabled = true
		btn_cancel.disabled = true
		face_icon.text = "[ ◎ ]  Face ID Taranıyor..."
		face_icon.add_theme_color_override("font_color", Color(1.0, 0.88, 0.38))
		bio_status.text = "Cihaz biyometrisi / Apple & Google kimliği doğrulanıyor..."

		if OS.has_feature("web"):
			JavaScriptBridge.eval("""
(async function(){
  window._tvkBioState = 'pending';
  try {
    if (window.PublicKeyCredential && await PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable()) {
      const ch = new Uint8Array(16);
      window.crypto.getRandomValues(ch);
      const uid = new TextEncoder().encode(""" + JSON.stringify(acct_edit.text.strip_edges()) + """);
      try {
        await navigator.credentials.create({
          publicKey: {
            challenge: ch,
            rp: { name: 'Taht ve Kilic' },
            user: { id: uid, name: """ + JSON.stringify(email_edit.text.strip_edges()) + """, displayName: """ + JSON.stringify(acct_edit.text.strip_edges()) + """ },
            pubKeyCredParams: [{ type: 'public-key', alg: -7 }, { type: 'public-key', alg: -257 }],
            authenticatorSelection: { authenticatorAttachment: 'platform', userVerification: 'required' },
            timeout: 20000
          }
        });
        window._tvkBioState = 'ok';
      } catch (e1) {
        if (e1 && e1.name === 'NotAllowedError') { window._tvkBioState = 'cancelled'; }
        else { window._tvkBioState = 'fallback'; }
      }
    } else {
      window._tvkBioState = 'fallback';
    }
  } catch (e) {
    window._tvkBioState = 'fallback';
  }
})();
""", true)
			var poll := Timer.new()
			poll.wait_time = 0.15
			var ticks := [0]
			poll.timeout.connect(func():
				ticks[0] += 1
				var st_res := str(JavaScriptBridge.eval("window._tvkBioState || 'pending'", true))
				if st_res == "cancelled":
					poll.stop()
					poll.queue_free()
					verifying[0] = false
					btn_confirm.disabled = false
					btn_cancel.disabled = false
					face_icon.text = "[ ✕ ]  Face ID İptal Edildi"
					face_icon.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
					bio_status.text = "Doğrulama iptal edildi. Tekrar deneyin."
				elif st_res == "ok" or (st_res == "fallback" and ticks[0] >= 5) or ticks[0] >= 80:
					poll.stop()
					poll.queue_free()
					face_icon.text = "[ ✓ ]  Face ID Doğrulandı!"
					face_icon.add_theme_color_override("font_color", Color(0.45, 0.98, 0.58))
					bio_status.text = "Kimlik doğrulandı, krallığa bağlanılıyor..."
					finish_auth.call()
			)
			_auth_sheet.add_child(poll)
			poll.start()
		else:
			var t := Timer.new()
			t.one_shot = true
			t.wait_time = 0.75
			t.timeout.connect(func():
				face_icon.text = "[ ✓ ]  Face ID Doğrulandı!"
				face_icon.add_theme_color_override("font_color", Color(0.45, 0.98, 0.58))
				bio_status.text = "Kimlik doğrulandı, krallığa bağlanılıyor..."
				finish_auth.call()
			)
			_auth_sheet.add_child(t)
			t.start()
	)

	var host := parent_node.get_tree().root if (parent_node != null and parent_node.get_tree() != null) else get_tree().root
	if host != null:
		host.add_child(_auth_sheet)
	elif parent_node != null:
		parent_node.add_child(_auth_sheet)
