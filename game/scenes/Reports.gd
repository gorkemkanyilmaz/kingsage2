extends Control
## Reports — Raporlar ekranı ve Nano-Banana Görsel Savaş Raporu (Taht ve Kılıç / A-ARAYUZ).

const Palette := preload("res://themes/Palette.gd")
const FontNunitoBold := preload("res://assets/fonts/Nunito-Bold.ttf")
const FontCinzelBold := preload("res://assets/fonts/Cinzel-Bold.ttf")
const IconWood := preload("res://assets/sprites/ui/nano_banana/sharp_icon_wood.tres")
const IconStone := preload("res://assets/sprites/ui/nano_banana/sharp_icon_stone.tres")
const IconIron := preload("res://assets/sprites/ui/nano_banana/sharp_icon_iron.tres")
const IconReportSeal := preload("res://assets/sprites/ui/nano_banana/sharp_icon_report_seal.tres")
const IconScrollMarch := preload("res://assets/sprites/ui/nano_banana/sharp_scroll_march.tres")
const IconScrollResearch := preload("res://assets/sprites/ui/nano_banana/sharp_scroll_research.tres")
const IconResourceCaravan := preload("res://assets/sprites/ui/nano_banana/sharp_pack_resource_caravan.tres")
const TexRoyalBtnBg := preload("res://assets/sprites/ui/nano_banana/sharp_ui_royal_btn_bg.tres")

const ICON_BATTLE := "res://assets/sprites/icons/cartography/2x/skull.png"
const ICON_SPY := "res://assets/sprites/icons/cartography/2x/watchtower.png"
const ICON_TRADE := "res://assets/sprites/icons/cartography/2x/chest.png"
const ICON_EMPTY := "res://assets/sprites/icons/cartography/2x/chest.png"

const UNIT_ICONS := {
	"farmer": "",
	"spear": "",
	"sword": "",
	"axe": "",
	"bow": "",
	"spy": "",
	"light": "",
	"heavy": "",
	"ram": "",
	"kata": "",
	"snob": "",
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
var _report_filter: String = "all"
var _toolbar: VBoxContainer = null
var _filter_buttons: Dictionary = {}


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
	_sync_top_bar_layout()
	if not resized.is_connected(_sync_top_bar_layout):
		resized.connect(_sync_top_bar_layout)
	var rbar := get_node_or_null("ResourceBar") as Control
	if rbar != null and not rbar.resized.is_connected(_sync_top_bar_layout):
		rbar.resized.connect(_sync_top_bar_layout)
	_style_detail_panel()
	_ensure_report_toolbar()
	_setup_tabs()
	_setup_composer()
	var gc_util = Engine.get_main_loop().root.get_node_or_null("GameConfig") if Engine.get_main_loop() is SceneTree else null
	if gc_util != null and gc_util.has_method("bind_keyboard_dismiss"):
		gc_util.call("bind_keyboard_dismiss", recipient_input)
		gc_util.call("bind_keyboard_dismiss", subject_input)
		gc_util.call("bind_keyboard_dismiss", body_input)

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


func _sync_top_bar_layout() -> void:
	var rbar := get_node_or_null("ResourceBar") as Control
	var bar_h := 116.0
	if rbar != null:
		if rbar.has_method("get_bar_height"):
			bar_h = float(rbar.call("get_bar_height"))
		elif rbar.size.y > 0.0:
			bar_h = rbar.size.y
	var header := get_node_or_null("Header") as Control
	if header != null:
		header.offset_top = bar_h + 8.0
		header.offset_bottom = bar_h + 104.0
	var cont := get_node_or_null("Container") as Control
	if cont != null:
		cont.offset_top = bar_h + 114.0


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
	var tab_bar := find_child("TabBar", true, false) as Control

	if tab_name == "reports":
		if title_lbl != null: title_lbl.text = "Savaş & İstihbarat Raporları"
		if subtitle_lbl != null: subtitle_lbl.text = "Muharebeler, casusluk ve ticaret"
		if tab_bar != null: tab_bar.visible = false
		if btn_tab_reports != null: btn_tab_reports.visible = false
		if btn_tab_messages != null: btn_tab_messages.visible = false
		if btn_tab_new_message != null: btn_tab_new_message.visible = false
	else:
		if title_lbl != null: title_lbl.text = "Lord Mektupları & Mesajlar"
		if subtitle_lbl != null: subtitle_lbl.text = "Krallıklar arası diplomasi"
		if tab_bar != null: tab_bar.visible = true
		if btn_tab_reports != null: btn_tab_reports.visible = false
		if btn_tab_messages != null:
			btn_tab_messages.visible = true
			btn_tab_messages.text = "Gelen Kutusu"
			_style_tab_btn(btn_tab_messages, tab_name == "messages")
		if btn_tab_new_message != null:
			btn_tab_new_message.visible = true
			btn_tab_new_message.text = "Yeni Mektup Yaz"
			_style_tab_btn(btn_tab_new_message, tab_name == "new_message")

	if tab_name == "new_message":
		if _toolbar != null: _toolbar.hide()
		if scroll_container != null: scroll_container.hide()
		if composer_panel != null: composer_panel.show()
	else:
		if _toolbar != null: _toolbar.visible = (tab_name == "reports")
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
		status_label.text = " Lütfen alıcı lordun adını giriniz."
		status_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		return
	if subj.is_empty():
		status_label.text = " Lütfen bir konu başlığı giriniz."
		status_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		return
	if body.is_empty():
		status_label.text = " Mesaj içeriği boş bırakılamaz."
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
	status_label.text = " Mektubunuz ulağa teslim edildi!"
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
			title = " Kime: %s | %s" % [to_user, subj]
		else:
			title = "%s: %s" % [from_user, subj]
			if not is_read:
				title = " (Yeni) " + title
			else:
				title = " " + title

		var subtitle := "Tarih: %s   |   Alıcı: %s" % [dt, to_user]
		var accent := Color(0.95, 0.85, 0.40) if (not is_read and not is_outgoing) else Color(0.60, 0.55, 0.50)
		report_list.add_child(_make_card(icon, title, subtitle, accent, func(): _show_message_detail(m)))


func _make_empty_messages_state() -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(0, 500)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)

	var lbl := Label.new()
	lbl.text = " Henüz gelen veya giden bir mektup bulunmuyor."
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", Color(0.65, 0.60, 0.52))
	box.add_child(lbl)

	var sub := Label.new()
	sub.text = "' Yeni Mesaj' sekmesinden diğer lordlara mektup gönderebilirsiniz."
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
	subj_lbl.text = " " + str(msg.get("subject", "Konusuz"))
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
	reply_btn.text = " Bu Mektubu Yanıtla"
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



func _ensure_report_toolbar() -> void:
	if _toolbar != null:
		return
	var main_vb := find_child("MainVBox", true, false) as VBoxContainer
	if main_vb == null:
		return
	_toolbar = VBoxContainer.new()
	_toolbar.name = "ReportToolbar"
	_toolbar.add_theme_constant_override("separation", 8)
	main_vb.add_child(_toolbar)
	var scroll_idx := scroll_container.get_index() if scroll_container != null else main_vb.get_child_count()
	main_vb.move_child(_toolbar, clampi(scroll_idx, 0, main_vb.get_child_count() - 1))

	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 8)
	_toolbar.add_child(filter_row)

	var filters := [
		["all", "Tümü"],
		["battle", "⚔️ Savaş"],
		["spy", "👁️ Casus"],
		["trade", "📦 Ticaret"],
	]
	for f in filters:
		var f_key := str(f[0])
		var f_btn := Button.new()
		f_btn.name = "BtnFilter_" + f_key
		f_btn.text = str(f[1])
		f_btn.custom_minimum_size = Vector2(0, 44)
		f_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		f_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		f_btn.add_theme_font_override("font", FontNunitoBold)
		f_btn.add_theme_font_size_override("font_size", 21)
		f_btn.pressed.connect(func():
			_report_filter = f_key
			_refresh_filter_styles()
			_populate_reports()
		)
		filter_row.add_child(f_btn)
		_filter_buttons[f_key] = f_btn

	var act_row := HBoxContainer.new()
	act_row.add_theme_constant_override("separation", 10)
	_toolbar.add_child(act_row)

	var mark_btn := Button.new()
	mark_btn.name = "BtnMarkAllRead"
	mark_btn.text = "✓ Tümünü Okundu İşaretle"
	mark_btn.custom_minimum_size = Vector2(0, 40)
	mark_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mark_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mark_btn.add_theme_font_override("font", FontNunitoBold)
	mark_btn.add_theme_font_size_override("font_size", 20)
	var m_sb := StyleBoxFlat.new()
	m_sb.bg_color = Color(0.13, 0.25, 0.17, 0.96)
	m_sb.border_color = Color(0.45, 0.85, 0.52, 0.85)
	m_sb.set_border_width_all(1)
	m_sb.set_corner_radius_all(10)
	mark_btn.add_theme_stylebox_override("normal", m_sb)
	mark_btn.add_theme_stylebox_override("hover", m_sb)
	mark_btn.add_theme_color_override("font_color", Color(0.84, 0.98, 0.86))
	mark_btn.pressed.connect(_mark_all_reports_read)
	act_row.add_child(mark_btn)

	var del_btn := Button.new()
	del_btn.name = "BtnDeleteReadReports"
	del_btn.text = "🗑️ Okunanları Sil"
	del_btn.custom_minimum_size = Vector2(0, 40)
	del_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	del_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	del_btn.add_theme_font_override("font", FontNunitoBold)
	del_btn.add_theme_font_size_override("font_size", 20)
	var d_sb := StyleBoxFlat.new()
	d_sb.bg_color = Color(0.28, 0.12, 0.14, 0.96)
	d_sb.border_color = Color(0.86, 0.40, 0.36, 0.85)
	d_sb.set_border_width_all(1)
	d_sb.set_corner_radius_all(10)
	del_btn.add_theme_stylebox_override("normal", d_sb)
	del_btn.add_theme_stylebox_override("hover", d_sb)
	del_btn.add_theme_color_override("font_color", Color(1.0, 0.86, 0.84))
	del_btn.pressed.connect(_delete_read_reports)
	act_row.add_child(del_btn)
	_refresh_filter_styles()


func _refresh_filter_styles() -> void:
	for fk in _filter_buttons.keys():
		var b: Button = _filter_buttons[fk]
		if b == null:
			continue
		var act := (str(fk) == _report_filter)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.28, 0.21, 0.10, 0.98) if act else Color(0.11, 0.10, 0.15, 0.94)
		sb.border_color = Color(0.95, 0.78, 0.36, 1.0) if act else Color(0.36, 0.32, 0.42, 0.75)
		sb.set_border_width_all(2 if act else 1)
		sb.set_corner_radius_all(10)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		b.add_theme_color_override("font_color", Color(1.0, 0.93, 0.68) if act else Color(0.80, 0.78, 0.72))


static func _report_sig(r: Dictionary) -> String:
	var rdata: Dictionary = r.get("data", {}) if typeof(r.get("data")) == TYPE_DICTIONARY else {}
	return "%s:%d:%d:%d:%d" % [
		str(r.get("type", "")),
		int(r.get("village_id", 0)),
		int(r.get("unix", r.get("created_unix", 0))),
		int(rdata.get("target_village_id", 0)),
		int(rdata.get("from_village_id", 0))
	]


static func _report_belongs_to_player(r: Dictionary, player_name: String, player_vids: Array) -> bool:
	var rtype := str(r.get("type", "battle"))
	var vid := int(r.get("village_id", -1))
	var rdata: Dictionary = r.get("data", {}) if typeof(r.get("data")) == TYPE_DICTIONARY else {}
	var a_owner := str(rdata.get("attacker_name", rdata.get("attacker_owner", ""))).strip_edges()
	var d_owner := str(rdata.get("defender_name", "")).strip_edges()
	var f_vid := int(rdata.get("from_village_id", -1))
	var t_vid := int(rdata.get("target_village_id", -1))
	var pname_l := player_name.strip_edges().to_lower()
	var is_att := (f_vid in player_vids) or (not pname_l.is_empty() and a_owner.to_lower() == pname_l)
	var is_def := (t_vid in player_vids) or (not pname_l.is_empty() and d_owner.to_lower() == pname_l)
	if rtype == "spy_incoming":
		# Saldiran savunanin kendi casus-uyari raporunu gormesin (cift rapor hatasi)
		return (not is_att) and ((vid in player_vids) or is_def)
	if rtype == "spy":
		return (vid in player_vids) or is_att
	return (vid in player_vids) or is_att or is_def


func _get_sig_set(gs: Node, key: String) -> Dictionary:
	var out := {}
	if gs == null or not ("player" in gs) or typeof(gs.player) != TYPE_DICTIONARY:
		return out
	var arr = (gs.player as Dictionary).get(key, [])
	if typeof(arr) == TYPE_ARRAY:
		for item in (arr as Array):
			out[str(item)] = true
	return out


func _update_sig_list(gs: Node, key: String, sig: String, add: bool) -> void:
	if gs == null or not ("player" in gs) or typeof(gs.player) != TYPE_DICTIONARY or sig.is_empty():
		return
	var p: Dictionary = gs.player
	var arr: Array = []
	if typeof(p.get(key)) == TYPE_ARRAY:
		for x in (p[key] as Array):
			var xs := str(x)
			if xs != sig:
				arr.append(xs)
	if add:
		arr.append(sig)
	if arr.size() > 400:
		arr = arr.slice(arr.size() - 400)
	p[key] = arr
	if "world" in gs and typeof(gs.world) == TYPE_DICTIONARY:
		var profs = (gs.world as Dictionary).get("player_profiles")
		var pname := str(p.get("name", "")).strip_edges().to_lower()
		var p_bare := pname.substr(5).strip_edges() if pname.begins_with("lord ") else pname
		if typeof(profs) == TYPE_DICTIONARY:
			for k in (profs as Dictionary).keys():
				if typeof(profs[k]) != TYPE_DICTIONARY:
					continue
				var kn := str(k).strip_edges().to_lower()
				var kb := kn.substr(5).strip_edges() if kn.begins_with("lord ") else kn
				if kn == pname or (not p_bare.is_empty() and kb == p_bare):
					profs[k][key] = arr.duplicate()


func _persist_report_changes() -> void:
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree) or (loop as SceneTree).root == null:
		return
	var root := (loop as SceneTree).root
	var eb := root.get_node_or_null("EventBus")
	if eb != null and eb.has_signal("state_changed"):
		eb.state_changed.emit()
	var sm := root.get_node_or_null("SaveManager")
	if sm != null and sm.has_method("save_game"):
		sm.call("save_game")
	var wm := root.get_node_or_null("WorldManager")
	if wm != null and wm.has_method("save_active_world"):
		wm.call("save_active_world", true)


func _set_report_read(rep: Dictionary, make_read: bool) -> void:
	var gs: Node = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	var sig := _report_sig(rep)
	rep["unread"] = not make_read
	_update_sig_list(gs, "read_report_sigs", sig, make_read)
	_update_sig_list(gs, "unread_toggled_sigs", sig, not make_read)
	_persist_report_changes()


func _delete_report(rep: Dictionary) -> void:
	var gs: Node = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	var sig := _report_sig(rep)
	_update_sig_list(gs, "deleted_report_sigs", sig, true)
	if gs != null and "reports" in gs and typeof(gs.reports) == TYPE_ARRAY:
		var pname := str(gs.player.get("name", "")).strip_edges().to_lower()
		var p_bare := pname.substr(5).strip_edges() if pname.begins_with("lord ") else pname
		var rdata: Dictionary = rep.get("data", {}) if typeof(rep.get("data")) == TYPE_DICTIONARY else {}
		var rtype := str(rep.get("type", "battle"))
		var a_owner := str(rdata.get("attacker_name", rdata.get("attacker_owner", ""))).strip_edges().to_lower()
		var d_owner := str(rdata.get("defender_name", "")).strip_edges().to_lower()
		var same_a := (a_owner == pname or (not p_bare.is_empty() and a_owner == p_bare))
		var same_d := (d_owner == pname or (not p_bare.is_empty() and d_owner == p_bare))
		var single_owner := (rtype == "spy" or rtype == "spy_incoming") or (same_a and (d_owner.is_empty() or same_d or d_owner.contains("barbar")))
		if single_owner:
			(gs.reports as Array).erase(rep)
	if detail_panel != null and detail_panel.visible:
		detail_panel.hide()
	_persist_report_changes()
	_populate_reports()


func _mark_all_reports_read() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null or not ("reports" in gs):
		return
	var player_name := str(gs.player.get("name", "Kral"))
	var player_vids: Array = []
	for v in gs.villages:
		if typeof(v) == TYPE_DICTIONARY and str((v as Dictionary).get("owner", "")) == player_name:
			player_vids.append(int((v as Dictionary).get("id", -1)))
	var del_sigs := _get_sig_set(gs, "deleted_report_sigs")
	for item in gs.reports:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var r := item as Dictionary
		var sig := _report_sig(r)
		if del_sigs.has(sig):
			continue
		if _report_belongs_to_player(r, player_name, player_vids):
			r["unread"] = false
			_update_sig_list(gs, "read_report_sigs", sig, true)
	_persist_report_changes()
	_populate_reports()


func _delete_read_reports() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null or not ("reports" in gs):
		return
	var player_name := str(gs.player.get("name", "Kral"))
	var player_vids: Array = []
	for v in gs.villages:
		if typeof(v) == TYPE_DICTIONARY and str((v as Dictionary).get("owner", "")) == player_name:
			player_vids.append(int((v as Dictionary).get("id", -1)))
	var del_sigs := _get_sig_set(gs, "deleted_report_sigs")
	var read_sigs := _get_sig_set(gs, "read_report_sigs")
	var to_delete: Array = []
	for item in gs.reports:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var r := item as Dictionary
		var sig := _report_sig(r)
		if del_sigs.has(sig):
			continue
		if not _report_belongs_to_player(r, player_name, player_vids):
			continue
		var is_unread := bool(r.get("unread", false)) and not read_sigs.has(sig)
		if not is_unread:
			to_delete.append(r)
	for r in to_delete:
		_delete_report(r)


func _populate_reports() -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null or report_list == null:
		return

	for child in report_list.get_children():
		report_list.remove_child(child)
		child.queue_free()

	var player_name := str(gs.player.get("name", "Kral"))
	var player_vids: Array = []
	for v in gs.villages:
		if typeof(v) == TYPE_DICTIONARY and str(v.get("owner", "")) == player_name:
			player_vids.append(int(v.get("id", -1)))

	var del_sigs := _get_sig_set(gs, "deleted_report_sigs")
	var read_sigs := _get_sig_set(gs, "read_report_sigs")
	var seen_sigs := {}
	var reports: Array = gs.reports
	var player_reports: Array = []
	for item in reports:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var r: Dictionary = item
		var sig := _report_sig(r)
		if del_sigs.has(sig) or seen_sigs.has(sig):
			continue
		if not _report_belongs_to_player(r, player_name, player_vids):
			continue
		var rtype := str(r.get("type", "battle"))
		if _report_filter == "battle" and rtype != "battle":
			continue
		elif _report_filter == "spy" and rtype != "spy" and rtype != "spy_incoming":
			continue
		elif _report_filter == "trade" and rtype != "trade":
			continue
		seen_sigs[sig] = true
		player_reports.append(r)

	if player_reports.is_empty():
		report_list.add_child(_make_empty_state())
		return

	# En yeni raporlar en üstte görünsün
	for i in range(player_reports.size() - 1, -1, -1):
		var r: Dictionary = player_reports[i]
		var rsig := _report_sig(r)
		var rtype: String = str(r.get("type", "battle"))
		var rdata: Dictionary = r.get("data", {}) if typeof(r.get("data")) == TYPE_DICTIONARY else {}
		var t_name := str(rdata.get("target_name", "")).strip_edges()
		var f_name := str(rdata.get("from_name", "")).strip_edges()
		var title := "Savaş Raporu"
		var icon := ICON_BATTLE
		var accent := Color(0.92, 0.36, 0.34)
		if rtype == "spy":
			title = ("Casus Raporu • %s" % t_name) if not t_name.is_empty() else "Casusluk Raporu"
			icon = ICON_SPY
			accent = Color(0.45, 0.78, 1.0)
		elif rtype == "spy_incoming":
			title = ("Casus Tespit Edildi • %s" % f_name) if not f_name.is_empty() else "Savunma İstihbaratı"
			icon = ICON_SPY
			accent = Color(0.95, 0.65, 0.25)
		elif rtype == "trade":
			title = "Ticaret Teslimatı"
			icon = ICON_TRADE
			accent = Color(0.42, 0.88, 0.56)
		elif not t_name.is_empty():
			var won := bool(rdata.get("attacker_won", false))
			title = ("%s • %s" % ["Zafer" if won else "Savaş", t_name])

		var is_unread := bool(r.get("unread", false)) and not read_sigs.has(rsig)
		var badge_tag := "● YENİ" if is_unread else "✓ Okundu"
		var subtitle := "%s • %s" % [badge_tag, Time.get_datetime_string_from_unix_time(int(r.get("unix", 0)))]
		report_list.add_child(_make_report_card(r, icon, title, subtitle, accent, is_unread))


func _make_empty_state() -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(0, 520)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 18)

	var icon := TextureRect.new()
	icon.texture = IconReportSeal
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(0, 140)
	icon.modulate = Color(0.95, 0.85, 0.58, 0.72)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)

	var lbl := Label.new()
	lbl.text = "Bu kategoride görüntülenecek rapor bulunmuyor."
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", FontNunitoBold)
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.90, 0.76))
	box.add_child(lbl)

	var hint := Label.new()
	hint.text = "Savaş, casusluk ve ticaret olayları burada arşivlenir."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color(0.68, 0.64, 0.56))
	box.add_child(hint)
	return box


func _make_card(icon_path: String, title: String, subtitle: String, accent: Color, on_press: Callable) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 108)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.095, 0.145, 0.98)
	var accent_border := accent
	accent_border.a = 0.92
	sb.border_color = accent_border
	sb.set_border_width_all(2)
	sb.border_width_left = 10
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	sb.content_margin_left = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	sb.content_margin_right = 14
	card.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)

	var icon_wrap := PanelContainer.new()
	icon_wrap.custom_minimum_size = Vector2(64, 64)
	icon_wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var iw_sb := StyleBoxFlat.new()
	iw_sb.bg_color = Color(0.16, 0.13, 0.21, 0.98)
	iw_sb.border_color = accent_border
	iw_sb.set_border_width_all(2)
	iw_sb.set_corner_radius_all(12)
	iw_sb.set_content_margin_all(6)
	icon_wrap.add_theme_stylebox_override("panel", iw_sb)
	var icon := TextureRect.new()
	if icon_path == ICON_BATTLE:
		icon.texture = IconScrollMarch
	elif icon_path == ICON_SPY:
		icon.texture = IconScrollResearch
	elif icon_path == ICON_TRADE:
		icon.texture = IconReportSeal if title.contains(":") or title.contains("Mektup") or title.contains("Kime:") else IconResourceCaravan
	elif ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	else:
		icon.texture = IconReportSeal
	icon.custom_minimum_size = Vector2(46, 46)
	icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = Color(1.0, 1.0, 1.0, 0.98)
	icon_wrap.add_child(icon)
	row.add_child(icon_wrap)

	var info_wrap := PanelContainer.new()
	info_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_wrap.mouse_filter = Control.MOUSE_FILTER_PASS
	var empty_wrap_sb := StyleBoxEmpty.new()
	info_wrap.add_theme_stylebox_override("panel", empty_wrap_sb)
	row.add_child(info_wrap)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_theme_constant_override("separation", 4)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.clip_text = true
	title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_lbl.add_theme_font_override("font", FontNunitoBold)
	title_lbl.add_theme_font_size_override("font_size", 23)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.94, 0.78))
	info.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = subtitle
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub_lbl.add_theme_font_size_override("font_size", 21)
	sub_lbl.add_theme_color_override("font_color", Color(0.76, 0.74, 0.68))
	info.add_child(sub_lbl)
	info_wrap.add_child(info)

	# Kart gövdesine basılınca detay açılır (aksiyon butonları kardeş olarak üstte kalır)
	var btn := Button.new()
	btn.name = "CardOpenArea"
	btn.flat = true
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var empty_sb := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty_sb)
	btn.add_theme_stylebox_override("hover", empty_sb)
	btn.add_theme_stylebox_override("pressed", empty_sb)
	btn.add_theme_stylebox_override("focus", empty_sb)
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pressed.connect(on_press)
	info_wrap.add_child(btn)

	return card


func _make_report_card(rep: Dictionary, icon_path: String, title: String, subtitle: String, accent: Color, is_unread: bool) -> PanelContainer:
	var card := _make_card(icon_path, title, subtitle, accent, func(): _show_detail(rep))
	var row := card.get_child(0) as HBoxContainer
	if row == null:
		return card

	if is_unread:
		var sb := (card.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
		sb.bg_color = Color(0.15, 0.13, 0.21, 0.99)
		sb.border_color = Color(0.98, 0.80, 0.36, 1.0)
		sb.border_width_left = 12
		card.add_theme_stylebox_override("panel", sb)

	var act_hb := HBoxContainer.new()
	act_hb.add_theme_constant_override("separation", 8)
	act_hb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	act_hb.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(act_hb)

	var read_btn := Button.new()
	read_btn.name = "BtnToggleRead"
	read_btn.text = "✓" if is_unread else "●"
	read_btn.tooltip_text = "Okundu işaretle" if is_unread else "Okunmadı yap"
	read_btn.custom_minimum_size = Vector2(46, 46)
	read_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	read_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	read_btn.add_theme_font_override("font", FontNunitoBold)
	read_btn.add_theme_font_size_override("font_size", 20)
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = Color(0.14, 0.32, 0.20, 0.96) if is_unread else Color(0.18, 0.16, 0.24, 0.96)
	rsb.border_color = Color(0.45, 0.88, 0.56, 0.90) if is_unread else Color(0.75, 0.62, 0.34, 0.80)
	rsb.set_border_width_all(1)
	rsb.set_corner_radius_all(10)
	read_btn.add_theme_stylebox_override("normal", rsb)
	read_btn.add_theme_stylebox_override("hover", rsb)
	read_btn.add_theme_color_override("font_color", Color(0.84, 1.0, 0.88) if is_unread else Color(0.98, 0.84, 0.42))
	read_btn.pressed.connect(func():
		_set_report_read(rep, is_unread)
		_populate_reports()
	)
	act_hb.add_child(read_btn)

	var del_btn := Button.new()
	del_btn.name = "BtnDeleteReport"
	del_btn.text = "🗑️"
	del_btn.tooltip_text = "Raporu Sil"
	del_btn.custom_minimum_size = Vector2(46, 46)
	del_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	del_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	del_btn.add_theme_font_size_override("font_size", 19)
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = Color(0.32, 0.12, 0.14, 0.96)
	dsb.border_color = Color(0.86, 0.38, 0.36, 0.90)
	dsb.set_border_width_all(1)
	dsb.set_corner_radius_all(10)
	del_btn.add_theme_stylebox_override("normal", dsb)
	del_btn.add_theme_stylebox_override("hover", dsb)
	del_btn.add_theme_color_override("font_color", Color(1.0, 0.84, 0.82))
	del_btn.pressed.connect(func(): _delete_report(rep))
	act_hb.add_child(del_btn)

	return card


func _show_detail(rep: Dictionary) -> void:
	_set_report_read(rep, true)

	if content_box == null:
		content_box = get_node_or_null("DetailPanel/VBox/Scroll/ContentBox")
	if detail_panel == null:
		detail_panel = get_node_or_null("DetailPanel")

	if content_box == null:
		return

	# Önceki içeriği temizle
	for child in content_box.get_children():
		content_box.remove_child(child)
		child.queue_free()

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	var unread_btn := Button.new()
	unread_btn.text = "● Okunmadı İşaretle"
	unread_btn.custom_minimum_size = Vector2(0, 44)
	unread_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unread_btn.add_theme_font_override("font", FontNunitoBold)
	unread_btn.add_theme_font_size_override("font_size", 21)
	var u_sb := StyleBoxFlat.new()
	u_sb.bg_color = Color(0.16, 0.14, 0.22, 0.96)
	u_sb.border_color = Color(0.84, 0.68, 0.34, 0.90)
	u_sb.set_border_width_all(1)
	u_sb.set_corner_radius_all(10)
	unread_btn.add_theme_stylebox_override("normal", u_sb)
	unread_btn.add_theme_color_override("font_color", Color(0.98, 0.88, 0.56))
	unread_btn.pressed.connect(func():
		_set_report_read(rep, false)
		if detail_panel != null:
			detail_panel.hide()
		_populate_reports()
	)
	bar.add_child(unread_btn)

	var del_detail_btn := Button.new()
	del_detail_btn.text = "🗑️ Raporu Sil"
	del_detail_btn.custom_minimum_size = Vector2(180, 44)
	del_detail_btn.add_theme_font_override("font", FontNunitoBold)
	del_detail_btn.add_theme_font_size_override("font_size", 21)
	var dd_sb := StyleBoxFlat.new()
	dd_sb.bg_color = Color(0.36, 0.13, 0.14, 0.96)
	dd_sb.border_color = Color(0.90, 0.42, 0.38, 0.95)
	dd_sb.set_border_width_all(1)
	dd_sb.set_corner_radius_all(10)
	del_detail_btn.add_theme_stylebox_override("normal", dd_sb)
	del_detail_btn.add_theme_color_override("font_color", Color(1.0, 0.88, 0.86))
	del_detail_btn.pressed.connect(func(): _delete_report(rep))
	bar.add_child(del_detail_btn)
	content_box.add_child(bar)

	var type: String = str(rep.get("type", "battle"))
	if type == "battle":
		_render_battle_report(content_box, rep)
	elif type == "spy" or type == "spy_incoming":
		_render_spy_report(content_box, rep)
	elif type == "trade":
		_render_trade_report(content_box, rep)
	else:
		_render_generic_report(content_box, rep)

	if _current_tab == "reports":
		_populate_reports()
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
	title_lbl.text = (" ZAFER!" if attacker_won else " YENİLGİ") if not is_raid else (" YAĞMA AKINI TAMAMLANDI" if attacker_won else " YAĞMA PÜSKÜRTÜLDÜ")
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_override("font", FontNunitoBold)
	title_lbl.add_theme_font_size_override("font_size", 38)
	title_lbl.add_theme_constant_override("outline_size", 4)
	title_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.70) if attacker_won else Color(1.0, 0.80, 0.80))
	banner_vbox.add_child(title_lbl)

	var subtitle_lbl := Label.new()
	if conquered:
		subtitle_lbl.text = " KÖY BAŞARIYLA FETHEDİLDİ VE KRALLIĞINIZA KATILDI!"
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

	var p_morale := _make_pill(" Moral: %%%d" % int(round(morale * 100.0)), Color(0.2, 0.25, 0.35, 0.85))
	var p_luck := _make_pill(" Şans: %+d%%" % int(round(luck * 100.0)), Color(0.15, 0.35, 0.20, 0.85) if luck >= 0 else Color(0.4, 0.18, 0.18, 0.85))
	var p_time := _make_pill(" " + Time.get_datetime_string_from_unix_time(int(rep.get("unix", 0))), Color(0.18, 0.16, 0.22, 0.85))

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

	var att_card := _make_side_card(" SALDIRAN", att_name, Color(0.18, 0.35, 0.60, 0.9))
	att_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	duel_box.add_child(att_card)

	var vs_lbl := Label.new()
	vs_lbl.text = " VS "
	vs_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vs_lbl.add_theme_font_override("font", FontNunitoBold)
	vs_lbl.add_theme_font_size_override("font_size", 28)
	vs_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.40))
	duel_box.add_child(vs_lbl)

	var def_card := _make_side_card(" SAVUNAN", def_name, Color(0.55, 0.22, 0.20, 0.9))
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
		w_lbl.text = " SUR HASARI: Şahmerdanlar surlara vurdu! (Seviye %d  Seviye %d | Hasar: %%%d)" % [wall_before, wall_after, int(round(wall_pct))]
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
		var u_icon: String = str(UNIT_ICONS.get(u_key, ""))
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
		var row_sent := _make_stat_line(" Mevcut:", str(total_count), Color(0.70, 0.85, 1.0))
		var row_lost := _make_stat_line(" Kayıp:", "-%d" % lost_count, Color(1.0, 0.45, 0.45) if lost_count > 0 else Color(0.6, 0.6, 0.6))
		var row_rem := _make_stat_line(" Kalan:", str(rem_count), Color(0.55, 1.0, 0.65))

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
	h_lbl.text = " ELE GEÇİRİLEN GANİMET & YAĞMA"
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
	t_lbl.text = " CASUSLUK VE İSTİHBARAT RAPORU"
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
		b_title.text = " KEŞFEDİLEN BİNALAR VE SEVİYELERİ"
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
		var out_card := _make_army_table_card(" Dışarıdaki / Seferdeki Birlikler", data["outside_units"], {}, data["outside_units"], Color(0.45, 0.30, 0.20))
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
	t_lbl.text = " TİCARET TESLİMATI TAMAMLANDI"
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
