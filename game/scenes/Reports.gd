extends Control
## Reports — Raporlar ekranı ve Nano-Banana Görsel Savaş Raporu (Taht ve Kılıç / A-ARAYUZ).

const Palette := preload("res://themes/Palette.gd")
const FontNunitoBold := preload("res://assets/fonts/Nunito-Bold.ttf")
const FontCinzelBold := preload("res://assets/fonts/Cinzel-Bold.ttf")
const IconWood := preload("res://assets/sprites/ui/nano_banana/sharp_icon_wood.tres")
const IconStone := preload("res://assets/sprites/ui/nano_banana/sharp_icon_stone.tres")
const IconIron := preload("res://assets/sprites/ui/nano_banana/sharp_icon_iron.tres")

const ICON_BATTLE := "res://assets/sprites/icons/cartography/2x/skull.png"
const ICON_SPY := "res://assets/sprites/icons/cartography/2x/watchtower.png"
const ICON_TRADE := "res://assets/sprites/icons/cartography/2x/chest.png"
const ICON_EMPTY := "res://assets/sprites/icons/cartography/2x/chest.png"

const UNIT_ICONS := {
	"farmer": "🧑‍🌾",
	"spear": "🛡️",
	"sword": "⚔️",
	"axe": "🪓",
	"bow": "🏹",
	"spy": "🕵️",
	"light": "🐎",
	"heavy": "♞",
	"ram": "🪵",
	"kata": "🎯",
	"snob": "👑",
}

const UNIT_NAMES_TR := {
	"farmer": "Köy Koruyucusu",
	"spear": "Silahtar",
	"sword": "Muhafız",
	"axe": "Baltacı",
	"bow": "Okçu",
	"spy": "Casus",
	"light": "Akıncı",
	"heavy": "Kara Şövalye",
	"ram": "Şahmerdan",
	"kata": "Mancınık",
	"snob": "Kont",
}

var report_list: VBoxContainer = null
var detail_panel: PanelContainer = null
var detail_text: Label = null
var content_box: VBoxContainer = null
var close_detail_btn: Button = null

var btn_tab_reports: Button = null
var btn_tab_messages: Button = null
var btn_tab_new_message: Button = null
var scroll_container: ScrollContainer = null
var composer_panel: PanelContainer = null
var recipient_input: LineEdit = null
var subject_input: LineEdit = null
var body_input: TextEdit = null
var status_label: Label = null
var send_btn: Button = null

static var initial_tab: String = "reports"
var _current_tab: String = "reports"


func _ensure_nodes() -> void:
	if report_list == null:
		report_list = find_child("List", true, false) as VBoxContainer
		detail_panel = find_child("DetailPanel", true, false) as PanelContainer
		detail_text = find_child("DetailText", true, false) as Label
		content_box = find_child("ContentBox", true, false) as VBoxContainer
		close_detail_btn = find_child("CloseBtn", true, false) as Button

		btn_tab_reports = find_child("BtnTabReports", true, false) as Button
		btn_tab_messages = find_child("BtnTabMessages", true, false) as Button
		btn_tab_new_message = find_child("BtnTabNewMessage", true, false) as Button
		scroll_container = find_child("Scroll", true, false) as ScrollContainer
		composer_panel = find_child("ComposerPanel", true, false) as PanelContainer
		recipient_input = find_child("RecipientInput", true, false) as LineEdit
		subject_input = find_child("SubjectInput", true, false) as LineEdit
		body_input = find_child("BodyInput", true, false) as TextEdit
		status_label = find_child("StatusLabel", true, false) as Label
		send_btn = find_child("SendBtn", true, false) as Button


func _ready() -> void:
	_ensure_nodes()
	_style_detail_panel()
	_setup_tabs()
	_setup_composer()

	if detail_panel != null:
		detail_panel.hide()
	if close_detail_btn != null and not close_detail_btn.pressed.is_connected(detail_panel.hide):
		close_detail_btn.pressed.connect(func(): detail_panel.hide())

	var target_tab := initial_tab
	initial_tab = "reports"
	_select_tab(target_tab)

	var eb = Engine.get_main_loop().root.get_node_or_null("EventBus") if Engine.get_main_loop() is SceneTree else null
	if eb != null:
		if eb.has_signal("report_created") and not eb.report_created.is_connected(_on_report_event):
			eb.report_created.connect(_on_report_event)
		if eb.has_signal("message_created") and not eb.message_created.is_connected(_on_report_event):
			eb.message_created.connect(_on_report_event)
		if eb.has_signal("state_changed") and not eb.state_changed.is_connected(_on_report_event):
			eb.state_changed.connect(_on_report_event)


func _style_detail_panel() -> void:
	if detail_panel == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.08, 0.12, 0.98)
	sb.border_color = Color(0.85, 0.70, 0.35, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	detail_panel.add_theme_stylebox_override("panel", sb)


func _setup_tabs() -> void:
	if btn_tab_reports != null and not btn_tab_reports.pressed.is_connected(_on_tab_reports_pressed):
		btn_tab_reports.pressed.connect(_on_tab_reports_pressed)
	if btn_tab_messages != null and not btn_tab_messages.pressed.is_connected(_on_tab_messages_pressed):
		btn_tab_messages.pressed.connect(_on_tab_messages_pressed)
	if btn_tab_new_message != null and not btn_tab_new_message.pressed.is_connected(_on_tab_new_message_pressed):
		btn_tab_new_message.pressed.connect(_on_tab_new_message_pressed)


func _on_tab_reports_pressed() -> void:
	_select_tab("reports")


func _on_tab_messages_pressed() -> void:
	_select_tab("messages")


func _on_tab_new_message_pressed() -> void:
	_select_tab("new_message")


func _select_tab(tab_name: String) -> void:
	_current_tab = tab_name
	var title_lbl = find_child("Title", true, false) as Label
	var subtitle_lbl = find_child("Subtitle", true, false) as Label

	if tab_name == "reports":
		if title_lbl != null: title_lbl.text = "📜 Savaş & İstihbarat Raporları"
		if subtitle_lbl != null: subtitle_lbl.text = "Muharebeler, casusluk ve ticaret"
		if btn_tab_reports != null:
			btn_tab_reports.visible = true
			btn_tab_reports.text = "📜 Tüm Raporlar"
		if btn_tab_messages != null: btn_tab_messages.visible = false
		if btn_tab_new_message != null: btn_tab_new_message.visible = false
		_style_tab_btn(btn_tab_reports, true)
	else:
		if title_lbl != null: title_lbl.text = "✉️ Lord Mektupları & Mesajlar"
		if subtitle_lbl != null: subtitle_lbl.text = "Krallıklar arası diplomasi"
		if btn_tab_reports != null: btn_tab_reports.visible = false
		if btn_tab_messages != null:
			btn_tab_messages.visible = true
			btn_tab_messages.text = "✉️ Gelen Kutusu"
			_style_tab_btn(btn_tab_messages, tab_name == "messages")
		if btn_tab_new_message != null:
			btn_tab_new_message.visible = true
			btn_tab_new_message.text = "✍️ Yeni Mektup Yaz"
			_style_tab_btn(btn_tab_new_message, tab_name == "new_message")

	if tab_name == "new_message":
		if scroll_container != null: scroll_container.hide()
		if composer_panel != null: composer_panel.show()
	else:
		if scroll_container != null: scroll_container.show()
		if composer_panel != null: composer_panel.hide()
		if tab_name == "reports":
			_populate_reports()
		elif tab_name == "messages":
			_populate_messages()

	var bnav = find_child("BottomNav", true, false)
	if bnav != null and bnav.has_method("_style_buttons"):
		bnav._style_buttons()


func _style_tab_btn(btn: Button, is_active: bool) -> void:
	if btn == null:
		return
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	if is_active:
		sb.bg_color = Color(0.85, 0.68, 0.28, 0.35)
		sb.border_color = Color(0.96, 0.84, 0.45, 1.0)
		sb.set_border_width_all(2)
		btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	else:
		sb.bg_color = Color(0.12, 0.10, 0.16, 0.8)
		sb.border_color = Color(0.40, 0.35, 0.45, 0.5)
		sb.set_border_width_all(1)
		btn.add_theme_color_override("font_color", Color(0.70, 0.68, 0.65))

	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)


func _setup_composer() -> void:
	if composer_panel == null:
		return
	var c_sb := StyleBoxFlat.new()
	c_sb.bg_color = Color(0.12, 0.10, 0.16, 0.96)
	c_sb.border_color = Color(0.85, 0.72, 0.40, 0.85)
	c_sb.set_border_width_all(2)
	c_sb.set_corner_radius_all(16)
	c_sb.content_margin_left = 20
	c_sb.content_margin_right = 20
	c_sb.content_margin_top = 16
	c_sb.content_margin_bottom = 16
	composer_panel.add_theme_stylebox_override("panel", c_sb)

	if recipient_input != null: _style_text_input(recipient_input)
	if subject_input != null: _style_text_input(subject_input)
	if body_input != null: _style_text_input(body_input)

	if send_btn != null and not send_btn.pressed.is_connected(_on_send_message_pressed):
		var s_sb := StyleBoxFlat.new()
		s_sb.bg_color = Color(0.80, 0.60, 0.20, 0.95)
		s_sb.border_color = Color(1.0, 0.88, 0.50, 1.0)
		s_sb.set_border_width_all(2)
		s_sb.set_corner_radius_all(12)
		send_btn.add_theme_stylebox_override("normal", s_sb)
		var h_sb = s_sb.duplicate() as StyleBoxFlat
		h_sb.bg_color = Color(0.92, 0.72, 0.25, 1.0)
		send_btn.add_theme_stylebox_override("hover", h_sb)
		send_btn.add_theme_color_override("font_color", Color(0.12, 0.08, 0.02))
		send_btn.pressed.connect(_on_send_message_pressed)


func _style_text_input(ctrl: Control) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.10, 0.95)
	sb.border_color = Color(0.60, 0.50, 0.35, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	ctrl.add_theme_stylebox_override("normal", sb)
	ctrl.add_theme_stylebox_override("focus", sb)
	ctrl.add_theme_color_override("font_color", Color(1, 1, 1))


func _on_send_message_pressed() -> void:
	var to_player := recipient_input.text.strip_edges()
	var subj := subject_input.text.strip_edges()
	var body := body_input.text.strip_edges()

	if to_player.is_empty():
		status_label.text = "⚠️ Lütfen alıcı lordun adını giriniz."
		status_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		return
	if subj.is_empty():
		status_label.text = "⚠️ Lütfen bir konu başlığı giriniz."
		status_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		return
	if body.is_empty():
		status_label.text = "⚠️ Mesaj içeriği boş bırakılamaz."
		status_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		return

	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null:
		return

	var sender_name := str(gs.player.get("name", "Kral"))
	var now := int(Time.get_unix_time_from_system())

	var out_msg := {
		"id": now * 1000 + randi() % 1000,
		"from": sender_name,
		"to": to_player,
		"subject": subj,
		"body": body,
		"created_unix": now,
		"read": true
	}
	gs.add_message(out_msg)

	# Bot lordlara yazıldıysa gerçekçi diplomatik yanıt oluştur
	var lower_to := to_player.to_lower()
	if lower_to.contains("edward") or lower_to.contains("roland") or lower_to.contains("vlad") or lower_to.contains("lord") or lower_to.contains("baron"):
		var reply_body := "Selamlar Sayın %s,\n\nMektubunuzu aldım ve memnuniyetle okudum. Krallıklarımız arasındaki barış, ticaret ve onurlu dostluğun daim olmasını dilerim.\n\nKılıcınız keskin, halkınız huzurlu olsun.\n\nSaygılarımla,\n%s" % [sender_name, to_player]
		var bot_reply := {
			"id": (now + 1) * 1000 + randi() % 1000,
			"from": to_player,
			"to": sender_name,
			"subject": "Re: " + subj,
			"body": reply_body,
			"created_unix": now + 1,
			"read": false
		}
		gs.add_message(bot_reply)

	var sm = Engine.get_main_loop().root.get_node_or_null("SaveManager") if Engine.get_main_loop() is SceneTree else null
	if sm != null:
		sm.save_game()

	recipient_input.text = ""
	subject_input.text = ""
	body_input.text = ""
	status_label.text = "✓ Mektubunuz ulağa teslim edildi!"
	status_label.add_theme_color_override("font_color", Color(0.40, 0.90, 0.50))

	_select_tab("messages")


func _populate_messages() -> void:
	_ensure_nodes()
	if report_list == null:
		return

	for child in report_list.get_children():
		child.queue_free()

	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null:
		return

	var player_name := str(gs.player.get("name", "Kral"))
	var msgs: Array = gs.messages
	var player_msgs: Array = []
	for item in msgs:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var m := item as Dictionary
		var to_user := str(m.get("to", ""))
		var from_user := str(m.get("from", ""))
		# Sadece bu kullanıcıya gelen veya bu kullanıcının yazdığı mektuplar gösterilmeli
		if to_user == player_name or from_user == player_name:
			player_msgs.append(m)

	if player_msgs.is_empty():
		report_list.add_child(_make_empty_messages_state())
		return

	for i in range(player_msgs.size() - 1, -1, -1):
		var m := player_msgs[i] as Dictionary
		var from_user := str(m.get("from", "Bilinmeyen"))
		var to_user := str(m.get("to", ""))
		var subj := str(m.get("subject", "Konusuz"))
		var is_read := bool(m.get("read", false))
		var dt := Time.get_datetime_string_from_unix_time(int(m.get("created_unix", 0)))

		var icon := ICON_TRADE
		var is_outgoing := (from_user == player_name and to_user != player_name)
		var title := ""
		if is_outgoing:
			title = "📤 Kime: %s | %s" % [to_user, subj]
		else:
			title = "%s: %s" % [from_user, subj]
			if not is_read:
				title = "✉️ (Yeni) " + title
			else:
				title = "📩 " + title

		var subtitle := "Tarih: %s   |   Alıcı: %s" % [dt, to_user]
		var accent := Color(0.95, 0.85, 0.40) if (not is_read and not is_outgoing) else Color(0.60, 0.55, 0.50)
		report_list.add_child(_make_card(icon, title, subtitle, accent, func(): _show_message_detail(m)))


func _make_empty_messages_state() -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(0, 500)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)

	var lbl := Label.new()
	lbl.text = "✉️ Henüz gelen veya giden bir mektup bulunmuyor."
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", Color(0.65, 0.60, 0.52))
	box.add_child(lbl)

	var sub := Label.new()
	sub.text = "'✍️ Yeni Mesaj' sekmesinden diğer lordlara mektup gönderebilirsiniz."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color(0.50, 0.46, 0.40))
	box.add_child(sub)
	return box


func _show_message_detail(msg: Dictionary) -> void:
	msg["read"] = true
	var eb = Engine.get_main_loop().root.get_node_or_null("EventBus") if Engine.get_main_loop() is SceneTree else null
	if eb != null and eb.has_signal("state_changed"):
		eb.state_changed.emit()

	for child in content_box.get_children():
		child.queue_free()

	detail_text.visible = false

	var m_card := PanelContainer.new()
	var m_sb := StyleBoxFlat.new()
	m_sb.bg_color = Color(0.14, 0.12, 0.18, 0.98)
	m_sb.border_color = Color(0.85, 0.72, 0.42, 0.95)
	m_sb.set_border_width_all(2)
	m_sb.set_corner_radius_all(14)
	m_sb.content_margin_left = 20
	m_sb.content_margin_right = 20
	m_sb.content_margin_top = 18
	m_sb.content_margin_bottom = 18
	m_card.add_theme_stylebox_override("panel", m_sb)
	content_box.add_child(m_card)

	var mc_vbox := VBoxContainer.new()
	mc_vbox.add_theme_constant_override("separation", 14)
	m_card.add_child(mc_vbox)

	var subj_lbl := Label.new()
	subj_lbl.text = "✉️ " + str(msg.get("subject", "Konusuz"))
	subj_lbl.add_theme_font_override("font", FontCinzelBold)
	subj_lbl.add_theme_font_size_override("font_size", 28)
	subj_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.45))
	mc_vbox.add_child(subj_lbl)

	var meta_lbl := Label.new()
	var dt := Time.get_datetime_string_from_unix_time(int(msg.get("created_unix", 0)))
	meta_lbl.text = "Gönderen: %s   |   Alıcı: %s   |   Tarih: %s" % [
		str(msg.get("from", "")),
		str(msg.get("to", "")),
		dt
	]
	meta_lbl.add_theme_font_override("font", FontNunitoBold)
	meta_lbl.add_theme_font_size_override("font_size", 20)
	meta_lbl.add_theme_color_override("font_color", Color(0.70, 0.85, 1.0))
	mc_vbox.add_child(meta_lbl)

	var sep := HSeparator.new()
	mc_vbox.add_child(sep)

	var body_lbl := Label.new()
	body_lbl.text = str(msg.get("body", ""))
	body_lbl.add_theme_font_size_override("font_size", 22)
	body_lbl.add_theme_color_override("font_color", Color(0.96, 0.94, 0.90))
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mc_vbox.add_child(body_lbl)

	# Yanıtla butonu
	var from_user := str(msg.get("from", ""))
	var cur_subj := str(msg.get("subject", ""))
	var reply_btn := Button.new()
	reply_btn.text = "↩️ Bu Mektubu Yanıtla"
	reply_btn.custom_minimum_size = Vector2(0, 52)
	reply_btn.add_theme_font_override("font", FontNunitoBold)
	reply_btn.add_theme_font_size_override("font_size", 22)
	var r_sb := StyleBoxFlat.new()
	r_sb.bg_color = Color(0.18, 0.28, 0.42, 0.95)
	r_sb.border_color = Color(0.50, 0.80, 1.0, 0.95)
	r_sb.set_border_width_all(2)
	r_sb.set_corner_radius_all(12)
	reply_btn.add_theme_stylebox_override("normal", r_sb)
	reply_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	reply_btn.pressed.connect(func():
		detail_panel.hide()
		_select_tab("new_message")
		if recipient_input != null: recipient_input.text = from_user
		if subject_input != null: subject_input.text = ("Re: " + cur_subj) if not cur_subj.begins_with("Re:") else cur_subj
		if body_input != null:
			body_input.text = ""
			body_input.grab_focus()
	)
	mc_vbox.add_child(reply_btn)

	detail_panel.show()


func _on_report_event(_arg = null) -> void:
	if _current_tab == "reports":
		_populate_reports()
	elif _current_tab == "messages":
		_populate_messages()



func _populate_reports() -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null:
		return

	for child in report_list.get_children():
		child.queue_free()

	var player_name := str(gs.player.get("name", "Kral"))
	var player_vids: Array = []
	for v in gs.villages:
		if typeof(v) == TYPE_DICTIONARY and str(v.get("owner", "")) == player_name:
			player_vids.append(int(v.get("id", -1)))

	var reports: Array = gs.reports
	var player_reports: Array = []
	for item in reports:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var r: Dictionary = item
		var vid := int(r.get("village_id", -1))
		var rdata = r.get("data", {})
		var a_owner := ""
		var d_owner := ""
		var f_vid := -1
		var t_vid := -1
		if typeof(rdata) == TYPE_DICTIONARY:
			a_owner = str(rdata.get("attacker_name", rdata.get("attacker_owner", "")))
			d_owner = str(rdata.get("defender_name", ""))
			f_vid = int(rdata.get("from_village_id", -1))
			t_vid = int(rdata.get("target_village_id", -1))
		if vid in player_vids or f_vid in player_vids or t_vid in player_vids or a_owner == player_name or d_owner == player_name:
			player_reports.append(r)

	if player_reports.is_empty():
		report_list.add_child(_make_empty_state())
		return

	# En yeni raporlar en üstte görünsün
	for i in range(player_reports.size() - 1, -1, -1):
		var r: Dictionary = player_reports[i]
		var type: String = str(r.get("type", "battle"))
		var title := "Savaş Raporu"
		var icon := ICON_BATTLE
		var accent := Palette.c("dusman")
		if type == "spy" or type == "spy_incoming":
			title = "Casusluk Raporu"
			icon = ICON_SPY
			accent = Palette.c("dost")
		elif type == "trade":
			title = "Ticaret Teslimatı"
			icon = ICON_TRADE
			accent = Palette.c("basari")

		var is_unread := bool(r.get("unread", false))
		if is_unread:
			title = "🔴 " + title

		var subtitle := Time.get_datetime_string_from_unix_time(int(r.get("unix", 0)))
		report_list.add_child(_make_card(icon, title, subtitle, accent, func(): _show_detail(r)))


func _make_empty_state() -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(0, 620)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)

	if ResourceLoader.exists(ICON_EMPTY):
		var icon := TextureRect.new()
		icon.texture = load(ICON_EMPTY)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(0, 200)
		icon.modulate = Color(0.42, 0.32, 0.18, 0.45)
		box.add_child(icon)

	var lbl := Label.new()
	lbl.text = "Henüz okunmamış veya geçmiş rapor bulunmuyor."
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", Color(0.42, 0.36, 0.28))
	box.add_child(lbl)

	var hint := Label.new()
	hint.text = "Savaş, casusluk ve ticaret olayları burada listelenir."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", Color(0.55, 0.50, 0.42))
	box.add_child(hint)
	return box


func _make_card(icon_path: String, title: String, subtitle: String, accent: Color, on_press: Callable) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 110)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.99, 0.96, 0.96)
	var accent_border := accent
	accent_border.a = 0.9
	sb.border_color = accent_border
	sb.set_border_width_all(2)
	sb.border_width_left = 14
	sb.corner_radius_top_left = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_right = 14
	sb.shadow_color = Color(0.42, 0.26, 0.16, 0.22)
	sb.shadow_size = 6
	sb.content_margin_left = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	sb.content_margin_right = 16
	card.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card.add_child(row)

	if ResourceLoader.exists(icon_path):
		var icon := TextureRect.new()
		icon.texture = load(icon_path)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(68, 68)
		icon.modulate = Color(0.32, 0.24, 0.13, 0.95)
		row.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 4)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_override("font", FontNunitoBold)
	title_lbl.add_theme_font_size_override("font_size", 26)
	title_lbl.add_theme_color_override("font_color", Color(0.18, 0.14, 0.10))
	info.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = subtitle
	sub_lbl.add_theme_font_size_override("font_size", 22)
	sub_lbl.add_theme_color_override("font_color", Color(0.44, 0.38, 0.30))
	info.add_child(sub_lbl)
	row.add_child(info)

	var chevron := Label.new()
	chevron.text = "❯"
	chevron.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chevron.add_theme_font_size_override("font_size", 28)
	chevron.add_theme_color_override("font_color", Color(0.52, 0.44, 0.32))
	row.add_child(chevron)

	# Kartın tamamını tıklanabilir yapan şeffaf düğme
	var btn := Button.new()
	btn.flat = true
	var empty_sb := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty_sb)
	btn.add_theme_stylebox_override("hover", empty_sb)
	btn.add_theme_stylebox_override("pressed", empty_sb)
	btn.add_theme_stylebox_override("focus", empty_sb)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pressed.connect(on_press)
	card.add_child(btn)

	return card


func _show_detail(rep: Dictionary) -> void:
	if bool(rep.get("unread", false)):
		rep["unread"] = false
		var eb = Engine.get_main_loop().root.get_node_or_null("EventBus") if Engine.get_main_loop() is SceneTree else null
		if eb != null and eb.has_signal("state_changed"):
			eb.state_changed.emit()

	if content_box == null:
		content_box = get_node_or_null("DetailPanel/VBox/Scroll/ContentBox")
	if detail_panel == null:
		detail_panel = get_node_or_null("DetailPanel")

	if content_box == null:
		return

	# Önceki içeriği temizle
	for child in content_box.get_children():
		child.queue_free()

	var type: String = str(rep.get("type", "battle"))
	if type == "battle":
		_render_battle_report(content_box, rep)
	elif type == "spy" or type == "spy_incoming":
		_render_spy_report(content_box, rep)
	elif type == "trade":
		_render_trade_report(content_box, rep)
	else:
		_render_generic_report(content_box, rep)

	detail_panel.show()


# =============================================================================
#  NANO-BANANA GÖRSEL SAVAŞ RAPORU
# =============================================================================

func _render_battle_report(parent: Control, rep: Dictionary) -> void:
	var data: Dictionary = rep.get("data", {})
	var raw: Dictionary = data.get("raw", {})
	var attacker_won: bool = bool(data.get("attacker_won", raw.get("attacker_won", false)))
	var is_raid: bool = bool(data.get("is_raid", raw.get("is_raid", false)))
	var conquered: bool = bool(data.get("conquered", raw.get("conquered", false)))

	# 1. ZAFER / YENİLGİ BÜYÜK BAŞLIK KARTI
	var banner := PanelContainer.new()
	var b_sb := StyleBoxFlat.new()
	if attacker_won:
		b_sb.bg_color = Color(0.12, 0.42, 0.20, 0.95)
		b_sb.border_color = Color(0.55, 0.92, 0.60, 1.0)
	else:
		b_sb.bg_color = Color(0.50, 0.12, 0.14, 0.95)
		b_sb.border_color = Color(0.95, 0.50, 0.45, 1.0)
	b_sb.set_border_width_all(3)
	b_sb.set_corner_radius_all(16)
	b_sb.shadow_color = Color(0, 0, 0, 0.6)
	b_sb.shadow_size = 12
	b_sb.content_margin_top = 18
	b_sb.content_margin_bottom = 18
	b_sb.content_margin_left = 16
	b_sb.content_margin_right = 16
	banner.add_theme_stylebox_override("panel", b_sb)

	var banner_vbox := VBoxContainer.new()
	banner_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	banner_vbox.add_theme_constant_override("separation", 6)

	var title_lbl := Label.new()
	title_lbl.text = ("🏆 ZAFER!" if attacker_won else "💀 YENİLGİ") if not is_raid else ("⚔️ YAĞMA AKINI TAMAMLANDI" if attacker_won else "🛡️ YAĞMA PÜSKÜRTÜLDÜ")
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_override("font", FontNunitoBold)
	title_lbl.add_theme_font_size_override("font_size", 38)
	title_lbl.add_theme_constant_override("outline_size", 4)
	title_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.70) if attacker_won else Color(1.0, 0.80, 0.80))
	banner_vbox.add_child(title_lbl)

	var subtitle_lbl := Label.new()
	if conquered:
		subtitle_lbl.text = "👑 KÖY BAŞARIYLA FETHEDİLDİ VE KRALLIĞINIZA KATILDI!"
	elif attacker_won:
		subtitle_lbl.text = "Düşman hatları yarıldı, garnizon ezildi ve zafer kazanıldı!"
	else:
		subtitle_lbl.text = "Savunan kuvvetler üstün geldi, taarruz başarısızlıkla sonuçlandı."
	subtitle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_lbl.add_theme_font_size_override("font_size", 22)
	subtitle_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
	banner_vbox.add_child(subtitle_lbl)

	# İstatistik Hapları (Moral & Şans & Zaman)
	var stats_hbox := HBoxContainer.new()
	stats_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_hbox.add_theme_constant_override("separation", 16)

	var morale: float = float(data.get("morale", raw.get("morale", 1.0)))
	var luck: float = float(data.get("luck", raw.get("luck", 0.0)))

	var p_morale := _make_pill("⚔️ Moral: %%%d" % int(round(morale * 100.0)), Color(0.2, 0.25, 0.35, 0.85))
	var p_luck := _make_pill("🍀 Şans: %+d%%" % int(round(luck * 100.0)), Color(0.15, 0.35, 0.20, 0.85) if luck >= 0 else Color(0.4, 0.18, 0.18, 0.85))
	var p_time := _make_pill("📅 " + Time.get_datetime_string_from_unix_time(int(rep.get("unix", 0))), Color(0.18, 0.16, 0.22, 0.85))

	stats_hbox.add_child(p_morale)
	stats_hbox.add_child(p_luck)
	stats_hbox.add_child(p_time)
	banner_vbox.add_child(stats_hbox)

	banner.add_child(banner_vbox)
	parent.add_child(banner)

	# 2. TARAFLAR KARŞILAŞTIRMASI (DUEL CARDS)
	var att_name: String = str(data.get("attacker_name", "Saldıran"))
	var def_name: String = str(data.get("defender_name", "Savunan"))

	var duel_box := HBoxContainer.new()
	duel_box.add_theme_constant_override("separation", 14)

	var att_card := _make_side_card("👑 SALDIRAN", att_name, Color(0.18, 0.35, 0.60, 0.9))
	att_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	duel_box.add_child(att_card)

	var vs_lbl := Label.new()
	vs_lbl.text = "⚔️ VS 🛡️"
	vs_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vs_lbl.add_theme_font_override("font", FontNunitoBold)
	vs_lbl.add_theme_font_size_override("font_size", 28)
	vs_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.40))
	duel_box.add_child(vs_lbl)

	var def_card := _make_side_card("🏰 SAVUNAN", def_name, Color(0.55, 0.22, 0.20, 0.9))
	def_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	duel_box.add_child(def_card)

	parent.add_child(duel_box)

	# 3. GÖRSEL BİRLİK TABLOLARI (SALDIRAN VE SAVUNAN)
	var att_units: Dictionary = data.get("attacker_units", raw.get("attacker_units", {}))
	var att_losses: Dictionary = data.get("attacker_losses", raw.get("attacker_losses", {}))
	var att_alive: Dictionary = data.get("attacker_alive", raw.get("attacker_alive", {}))

	var def_units: Dictionary = data.get("defender_units", raw.get("defender_units", {}))
	var def_losses: Dictionary = data.get("defender_losses", raw.get("defender_losses", {}))
	var def_alive: Dictionary = data.get("defender_alive", raw.get("defender_alive", {}))

	var army_section := _make_army_table_card("Saldıran Ordusu Kayıp & Kalan Tablosu", att_units, att_losses, att_alive, Color(0.20, 0.30, 0.50, 0.95))
	parent.add_child(army_section)

	var def_army_section := _make_army_table_card("Savunan Garnizonu Kayıp & Kalan Tablosu", def_units, def_losses, def_alive, Color(0.45, 0.20, 0.20, 0.95))
	parent.add_child(def_army_section)

	# 4. GANİMET & YAĞMA KARTI
	var loot: Dictionary = data.get("loot", raw.get("loot", {}))
	var carry_cap: int = int(data.get("carry_capacity", raw.get("carry_capacity", 0)))
	var loot_card := _make_loot_card(loot, carry_cap)
	parent.add_child(loot_card)

	# 5. ÖZEL ETKİLER (SUR HASARI & FETİH)
	var wall_pct: float = float(data.get("wall_damage_pct", raw.get("wall_damage_pct", 0.0)))
	var wall_before: int = int(data.get("wall_level_before", raw.get("wall_level_before", 0)))
	var wall_after: int = int(data.get("wall_level_after", raw.get("wall_level_after", 0)))

	if wall_pct > 0.0 or wall_before != wall_after:
		var wall_box := PanelContainer.new()
		var w_sb := StyleBoxFlat.new()
		w_sb.bg_color = Color(0.28, 0.20, 0.12, 0.95)
		w_sb.border_color = Color(0.95, 0.70, 0.35, 1.0)
		w_sb.set_border_width_all(2)
		w_sb.set_corner_radius_all(14)
		w_sb.content_margin_all(14)
		wall_box.add_theme_stylebox_override("panel", w_sb)

		var w_lbl := Label.new()
		w_lbl.text = "🧱 SUR HASARI: Şahmerdanlar surlara vurdu! (Seviye %d ➔ Seviye %d | Hasar: %%%d)" % [wall_before, wall_after, int(round(wall_pct))]
		w_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		w_lbl.add_theme_font_override("font", FontNunitoBold)
		w_lbl.add_theme_font_size_override("font_size", 24)
		w_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.65))
		wall_box.add_child(w_lbl)
		parent.add_child(wall_box)


func _make_side_card(title: String, name_str: String, border_color: Color) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.13, 0.17, 0.95)
	sb.border_color = border_color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(14)
	pc.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 4)

	var t_lbl := Label.new()
	t_lbl.text = title
	t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_lbl.add_theme_font_size_override("font_size", 20)
	t_lbl.add_theme_color_override("font_color", Color(0.75, 0.72, 0.65))
	vb.add_child(t_lbl)

	var n_lbl := Label.new()
	n_lbl.text = name_str
	n_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n_lbl.add_theme_font_override("font", FontNunitoBold)
	n_lbl.add_theme_font_size_override("font_size", 26)
	n_lbl.add_theme_constant_override("outline_size", 3)
	n_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	n_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	vb.add_child(n_lbl)

	pc.add_child(vb)
	return pc


func _make_army_table_card(header: String, units: Dictionary, losses: Dictionary, alive: Dictionary, header_col: Color) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.13, 0.16, 0.98)
	sb.border_color = Color(0.50, 0.45, 0.38, 0.90)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(16)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 8
	pc.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)

	var h_lbl := Label.new()
	h_lbl.text = header
	h_lbl.add_theme_font_override("font", FontNunitoBold)
	h_lbl.add_theme_font_size_override("font_size", 26)
	h_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.70))
	vb.add_child(h_lbl)

	# Birlikler gridi
	var all_keys: Array = []
	for k in units.keys():
		if int(units[k]) > 0 and not all_keys.has(k):
			all_keys.append(k)
	for k in losses.keys():
		if int(losses[k]) > 0 and not all_keys.has(k):
			all_keys.append(k)

	if all_keys.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Bu muharebede birim konuşlandırılmadı veya garnizon boştu."
		empty_lbl.add_theme_font_size_override("font_size", 22)
		empty_lbl.add_theme_color_override("font_color", Color(0.65, 0.60, 0.55))
		vb.add_child(empty_lbl)
		pc.add_child(vb)
		return pc

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)

	for k in all_keys:
		var u_key: String = str(k)
		var total_count: int = int(units.get(u_key, 0))
		var lost_count: int = int(losses.get(u_key, 0))
		var rem_count: int = int(alive.get(u_key, maxi(0, total_count - lost_count)))
		var u_icon: String = str(UNIT_ICONS.get(u_key, "🛡️"))
		var u_name: String = str(UNIT_NAMES_TR.get(u_key, u_key))

		var u_card := PanelContainer.new()
		u_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var u_sb := StyleBoxFlat.new()
		u_sb.bg_color = Color(0.18, 0.16, 0.20, 0.95)
		u_sb.border_color = Color(0.40, 0.35, 0.28, 0.8)
		u_sb.set_border_width_all(1)
		u_sb.set_corner_radius_all(12)
		u_sb.set_content_margin_all(10)
		u_card.add_theme_stylebox_override("panel", u_sb)

		var u_vb := VBoxContainer.new()
		u_vb.add_theme_constant_override("separation", 4)

		var title_row := HBoxContainer.new()
		var icon_lbl := Label.new()
		icon_lbl.text = u_icon
		icon_lbl.add_theme_font_size_override("font_size", 26)
		title_row.add_child(icon_lbl)

		var name_lbl := Label.new()
		name_lbl.text = u_name
		name_lbl.add_theme_font_override("font", FontNunitoBold)
		name_lbl.add_theme_font_size_override("font_size", 22)
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
		title_row.add_child(name_lbl)
		u_vb.add_child(title_row)

		# 3 gösterge: Gönderilen, Kayıp, Kalan
		var row_sent := _make_stat_line("🔵 Mevcut:", str(total_count), Color(0.70, 0.85, 1.0))
		var row_lost := _make_stat_line("🔴 Kayıp:", "-%d" % lost_count, Color(1.0, 0.45, 0.45) if lost_count > 0 else Color(0.6, 0.6, 0.6))
		var row_rem := _make_stat_line("🟢 Kalan:", str(rem_count), Color(0.55, 1.0, 0.65))

		u_vb.add_child(row_sent)
		u_vb.add_child(row_lost)
		u_vb.add_child(row_rem)

		u_card.add_child(u_vb)
		grid.add_child(u_card)

	vb.add_child(grid)
	pc.add_child(vb)
	return pc


func _make_stat_line(title: String, val_str: String, val_col: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	var t_lbl := Label.new()
	t_lbl.text = title
	t_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t_lbl.add_theme_font_size_override("font_size", 20)
	t_lbl.add_theme_color_override("font_color", Color(0.75, 0.72, 0.68))
	row.add_child(t_lbl)

	var v_lbl := Label.new()
	v_lbl.text = val_str
	v_lbl.add_theme_font_override("font", FontNunitoBold)
	v_lbl.add_theme_font_size_override("font_size", 22)
	v_lbl.add_theme_color_override("font_color", val_col)
	row.add_child(v_lbl)
	return row


func _make_loot_card(loot: Dictionary, carry_cap: int) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.12, 0.15, 0.95)
	sb.border_color = Color(0.85, 0.72, 0.42, 0.90)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(16)
	pc.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)

	var h_lbl := Label.new()
	h_lbl.text = "📦 ELE GEÇİRİLEN GANİMET & YAĞMA"
	h_lbl.add_theme_font_override("font", FontNunitoBold)
	h_lbl.add_theme_font_size_override("font_size", 26)
	h_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.70))
	vb.add_child(h_lbl)

	var w: int = int(loot.get("wood", 0))
	var s: int = int(loot.get("stone", 0))
	var i: int = int(loot.get("iron", 0))
	var total_loot := w + s + i

	var res_row := HBoxContainer.new()
	res_row.alignment = BoxContainer.ALIGNMENT_CENTER
	res_row.add_theme_constant_override("separation", 24)

	res_row.add_child(_make_res_badge(IconWood, "Odun", w))
	res_row.add_child(_make_res_badge(IconStone, "Taş", s))
	res_row.add_child(_make_res_badge(IconIron, "Demir", i))
	vb.add_child(res_row)

	if carry_cap > 0:
		var cap_lbl := Label.new()
		cap_lbl.text = "Taşıma Kapasitesi: %d / %d (%%%d Dolu)" % [total_loot, carry_cap, int(round(float(total_loot) / float(carry_cap) * 100.0))]
		cap_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap_lbl.add_theme_font_size_override("font_size", 22)
		cap_lbl.add_theme_color_override("font_color", Color(0.85, 0.80, 0.72))
		vb.add_child(cap_lbl)

		var pb := ProgressBar.new()
		pb.custom_minimum_size = Vector2(0, 14)
		pb.max_value = carry_cap
		pb.value = total_loot
		pb.show_percentage = false
		var pb_bg := StyleBoxFlat.new()
		pb_bg.bg_color = Color(0.08, 0.07, 0.10, 0.95)
		pb_bg.set_corner_radius_all(7)
		var pb_fg := StyleBoxFlat.new()
		pb_fg.bg_color = Color(0.95, 0.75, 0.25, 1.0)
		pb_fg.set_corner_radius_all(7)
		pb.add_theme_stylebox_override("background", pb_bg)
		pb.add_theme_stylebox_override("fill", pb_fg)
		vb.add_child(pb)

	pc.add_child(vb)
	return pc


func _make_res_badge(tex: Texture2D, res_name: String, amount: int) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.16, 0.22, 0.90)
	sb.border_color = Color(0.40, 0.35, 0.25, 0.80)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(8)
	pc.add_theme_stylebox_override("panel", sb)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)

	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.custom_minimum_size = Vector2(36, 36)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hb.add_child(tr)

	var lbl := Label.new()
	lbl.text = "%s: %s" % [res_name, _format_number(amount)]
	lbl.add_theme_font_override("font", FontNunitoBold)
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	hb.add_child(lbl)

	pc.add_child(hb)
	return pc


func _make_pill(txt: String, bg_col: Color) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	pc.add_theme_stylebox_override("panel", sb)

	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_font_override("font", FontNunitoBold)
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	pc.add_child(lbl)
	return pc


func _render_spy_report(parent: Control, rep: Dictionary) -> void:
	var data: Dictionary = rep.get("data", {})
	var banner := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.25, 0.40, 0.95)
	sb.border_color = Color(0.45, 0.75, 1.0, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(16)
	banner.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	var t_lbl := Label.new()
	t_lbl.text = "🕵️ CASUSLUK VE İSTİHBARAT RAPORU"
	t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_lbl.add_theme_font_override("font", FontNunitoBold)
	t_lbl.add_theme_font_size_override("font_size", 32)
	t_lbl.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	vb.add_child(t_lbl)

	var survivors: int = int(data.get("spy_survivors", 0))
	var losses: int = int(data.get("spy_losses", 0))
	var def_spies: int = int(data.get("defence_spies", 0))
	var creeping: bool = bool(data.get("creeping", false))

	var sub := Label.new()
	sub.text = "Hedef: %s | Casuslarımız: %d Sağ / %d Kayıp | Savunan Casus: %d%s" % [
		str(data.get("target_name", "Köy")),
		survivors, losses, def_spies,
		" (Gizli Sızma)" if creeping else ""
	]
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.85))
	vb.add_child(sub)

	banner.add_child(vb)
	parent.add_child(banner)

	if data.has("resources"):
		var res: Dictionary = data["resources"]
		var res_card := _make_loot_card(res, 0)
		parent.add_child(res_card)

	if data.has("units"):
		var u_card := _make_army_table_card("Keşfedilen Birlikler (Köy İçi)", data["units"], {}, data["units"], Color(0.2, 0.35, 0.55))
		parent.add_child(u_card)

	# Binalar ve Seviyeleri (KingsAge: %50+ casus sağ kalımı)
	if data.has("buildings") and not (data["buildings"] as Dictionary).is_empty():
		var b_card := PanelContainer.new()
		var b_sb := StyleBoxFlat.new()
		b_sb.bg_color = Color(0.14, 0.12, 0.18, 0.95)
		b_sb.border_color = Color(0.85, 0.72, 0.42, 0.90)
		b_sb.set_border_width_all(2)
		b_sb.set_corner_radius_all(16)
		b_sb.set_content_margin_all(16)
		b_card.add_theme_stylebox_override("panel", b_sb)

		var b_vb := VBoxContainer.new()
		b_vb.add_theme_constant_override("separation", 10)
		var b_title := Label.new()
		b_title.text = "🏛️ KEŞFEDİLEN BİNALAR VE SEVİYELERİ"
		b_title.add_theme_font_override("font", FontNunitoBold)
		b_title.add_theme_font_size_override("font_size", 26)
		b_title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.70))
		b_vb.add_child(b_title)

		var b_grid := GridContainer.new()
		b_grid.columns = 2
		b_grid.add_theme_constant_override("h_separation", 16)
		b_grid.add_theme_constant_override("v_separation", 8)

		var b_names := {
			"main": "Ana Bina", "wood": "Oduncu", "stone": "Taş Ocağı", "iron": "Demir Madeni",
			"store": "Depo", "farm": "Çiftlik", "barracks": "Kışla", "stable": "Ahır",
			"garage": "Atölye", "snob": "Köşk", "hide": "Gizli Depo", "wall": "Sur",
			"statue": "Heykel", "market": "Pazar"
		}
		var b_dict: Dictionary = data["buildings"]
		for b_key in b_dict.keys():
			var lvl: int = int(b_dict[b_key])
			if lvl > 0:
				var tr_name: String = str(b_names.get(b_key, b_key.capitalize()))
				var b_lbl := Label.new()
				b_lbl.text = "• %s: Seviye %d" % [tr_name, lvl]
				b_lbl.add_theme_font_size_override("font_size", 22)
				b_lbl.add_theme_color_override("font_color", Color(0.90, 0.88, 0.82))
				b_grid.add_child(b_lbl)
		b_vb.add_child(b_grid)
		b_card.add_child(b_vb)
		parent.add_child(b_card)

	# Dışarıdaki birlikler (KingsAge: %70+ casus sağ kalımı ve creeping değilse)
	if data.has("outside_units") and not (data["outside_units"] as Dictionary).is_empty():
		var out_card := _make_army_table_card("🗺️ Dışarıdaki / Seferdeki Birlikler", data["outside_units"], {}, data["outside_units"], Color(0.45, 0.30, 0.20))
		parent.add_child(out_card)


func _render_trade_report(parent: Control, rep: Dictionary) -> void:
	var data: Dictionary = rep.get("data", {})
	var banner := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.35, 0.22, 0.95)
	sb.border_color = Color(0.55, 0.90, 0.65, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(16)
	banner.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	var t_lbl := Label.new()
	t_lbl.text = "📦 TİCARET TESLİMATI TAMAMLANDI"
	t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_lbl.add_theme_font_override("font", FontNunitoBold)
	t_lbl.add_theme_font_size_override("font_size", 32)
	t_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75))
	vb.add_child(t_lbl)
	banner.add_child(vb)
	parent.add_child(banner)

	var res: Dictionary = data.get("resources", {})
	if not res.is_empty():
		var res_card := _make_loot_card(res, 0)
		parent.add_child(res_card)


func _render_generic_report(parent: Control, rep: Dictionary) -> void:
	var data: Dictionary = rep.get("data", {})
	var text_lbl := Label.new()
	text_lbl.text = str(data.get("text", "Detay bulunamadı."))
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_lbl.add_theme_font_size_override("font_size", 24)
	text_lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	parent.add_child(text_lbl)


func _format_number(val: int) -> String:
	var s := str(val)
	var result := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		result = s[i] + result
		count += 1
		if count % 3 == 0 and i > 0 and s[i - 1] != "-":
			result = "." + result
	return result
