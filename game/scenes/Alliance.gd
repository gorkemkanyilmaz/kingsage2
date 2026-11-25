extends Control
## Alliance — İttifak Yönetim ve Canlı Sohbet Ekranı (Taht ve Kılıç / docs/12).

const AllianceModelScript := preload("res://scripts/model/AllianceModel.gd")
const FontNunitoBold := preload("res://assets/fonts/Nunito-Bold.ttf")
const FontCinzelBold := preload("res://assets/fonts/Cinzel-Bold.ttf")

@onready var content_area: Control = $MainContainer/ContentArea
@onready var header_title: Label = $MainContainer/Header/HBox/Title

var _active_tab: String = "chat"
var _non_member_tab: String = "create"
var _last_rendered_alliance_id: int = -999
var _is_member_view_rendered: bool = false
var _suppress_state_refresh: bool = false
var _create_name_input: LineEdit = null
var _create_tag_input: LineEdit = null
var _create_desc_input: TextEdit = null
var _chat_input: LineEdit = null
var _invite_input: LineEdit = null
var _draft_create_name: String = ""
var _draft_create_tag: String = ""
var _draft_create_desc: String = ""
var _draft_chat_text: String = ""
var _draft_invite_text: String = ""


func _ready() -> void:
	_style_header()
	_sync_top_bar_layout()
	if not resized.is_connected(_sync_top_bar_layout):
		resized.connect(_sync_top_bar_layout)
	var rbar := get_node_or_null("ResourceBar") as Control
	if rbar != null and not rbar.resized.is_connected(_sync_top_bar_layout):
		rbar.resized.connect(_sync_top_bar_layout)
	refresh_view()

	var eb = Engine.get_main_loop().root.get_node_or_null("EventBus") if Engine.get_main_loop() is SceneTree else null
	if eb != null:
		if eb.has_signal("state_changed") and not eb.state_changed.is_connected(_on_state_changed):
			eb.state_changed.connect(_on_state_changed)


func _sync_top_bar_layout() -> void:
	var rbar := get_node_or_null("ResourceBar") as Control
	var bar_h := 116.0
	if rbar != null:
		if rbar.has_method("get_bar_height"):
			bar_h = float(rbar.call("get_bar_height"))
		elif rbar.size.y > 0.0:
			bar_h = rbar.size.y
	var main_cont := get_node_or_null("MainContainer") as Control
	if main_cont != null:
		main_cont.offset_top = bar_h + 6.0


func _style_header() -> void:
	var h_panel = find_child("Header", true, false) as PanelContainer
	if h_panel != null:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.12, 0.10, 0.15, 0.98)
		sb.border_color = Color(0.88, 0.74, 0.42, 0.95)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(14)
		sb.content_margin_left = 18
		sb.content_margin_right = 18
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
		sb.shadow_color = Color(0, 0, 0, 0.5)
		sb.shadow_size = 0
		h_panel.add_theme_stylebox_override("panel", sb)


func _has_focused_text_input() -> bool:
	var vp := get_viewport()
	if vp == null or content_area == null:
		return false
	var fo := vp.gui_get_focus_owner()
	if fo == null or not is_instance_valid(fo):
		return false
	if not (fo is LineEdit or fo is TextEdit):
		return false
	return content_area.is_ancestor_of(fo)


func _capture_input_drafts() -> void:
	if _create_name_input != null and is_instance_valid(_create_name_input):
		_draft_create_name = _create_name_input.text
	if _create_tag_input != null and is_instance_valid(_create_tag_input):
		_draft_create_tag = _create_tag_input.text
	if _create_desc_input != null and is_instance_valid(_create_desc_input):
		_draft_create_desc = _create_desc_input.text
	if _chat_input != null and is_instance_valid(_chat_input):
		_draft_chat_text = _chat_input.text
	if _invite_input != null and is_instance_valid(_invite_input):
		_draft_invite_text = _invite_input.text


func _on_state_changed() -> void:
	if _suppress_state_refresh:
		return
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null:
		return
	var p_name := str(gs.player.get("name", "Kral"))
	var alliance: Dictionary = AllianceModelScript.get_player_alliance(gs.to_dict(), p_name)
	var aid: int = int(alliance.get("id", -1)) if not alliance.is_empty() else -1
	if aid == _last_rendered_alliance_id:
		if _has_focused_text_input():
			return
		if not _is_member_view_rendered and _non_member_tab == "create":
			return
		if _is_member_view_rendered and _active_tab == "invite":
			return
	refresh_view()


func refresh_view() -> void:
	_capture_input_drafts()
	_create_name_input = null
	_create_tag_input = null
	_create_desc_input = null
	_chat_input = null
	_invite_input = null
	for child in content_area.get_children():
		content_area.remove_child(child)
		child.queue_free()

	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null:
		return

	var p_name := str(gs.player.get("name", "Kral"))
	var state: Dictionary = gs.to_dict()
	var alliance: Dictionary = AllianceModelScript.get_player_alliance(state, p_name)
	_last_rendered_alliance_id = int(alliance.get("id", -1)) if not alliance.is_empty() else -1
	_is_member_view_rendered = not alliance.is_empty()

	if alliance.is_empty():
		header_title.text = " İTTİFAK MERKEZİ"
		_build_non_member_view(gs, p_name)
	else:
		header_title.text = " [%s] %s" % [str(alliance.get("tag", "")), str(alliance.get("name", ""))]
		_build_member_view(gs, alliance, p_name)


# =============================================================================
#  Üye Olmayan Görünümü (İttifak Kur / İttifak Bul & Davetler)
# =============================================================================

func _build_non_member_view(gs: Node, player_name: String) -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 14)
	content_area.add_child(vbox)

	# Sekme Çubuğu
	var tab_bar := HBoxContainer.new()
	tab_bar.custom_minimum_size = Vector2(0, 56)
	tab_bar.add_theme_constant_override("separation", 12)
	vbox.add_child(tab_bar)

	var btn_tab_create := _make_tab_button(" İttifak Kur", _non_member_tab == "create")
	btn_tab_create.pressed.connect(func():
		_non_member_tab = "create"
		refresh_view()
	)
	tab_bar.add_child(btn_tab_create)

	var btn_tab_browse := _make_tab_button(" İttifak Bul & Davetler", _non_member_tab == "browse")
	btn_tab_browse.pressed.connect(func():
		_non_member_tab = "browse"
		refresh_view()
	)
	tab_bar.add_child(btn_tab_browse)

	if _non_member_tab == "create":
		_build_create_alliance_form(vbox, gs, player_name)
	else:
		_build_browse_alliances_view(vbox, gs, player_name)


func _build_create_alliance_form(parent: Control, gs: Node, player_name: String) -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 12
	parent.add_child(scroll)

	var scroll_vb := VBoxContainer.new()
	scroll_vb.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(scroll_vb)

	var card := _make_card()
	scroll_vb.add_child(card)

	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 14)
	card.add_child(card_vbox)

	var title := Label.new()
	title.text = "Yeni Bir İttifak Kur"
	title.add_theme_font_override("font", FontCinzelBold)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.90, 0.45))
	card_vbox.add_child(title)

	var desc_label := Label.new()
	desc_label.text = "Kendi sancağınızı dikin! İttifak kurarak diğer lordları bir araya getirin, ortak sohbet kanalında strateji belirleyin."
	desc_label.add_theme_font_override("font", FontNunitoBold)
	desc_label.add_theme_font_size_override("font_size", 22)
	desc_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_vbox.add_child(desc_label)

	# İsim
	var name_lbl := Label.new()
	name_lbl.text = "İttifak İsmi:"
	name_lbl.add_theme_font_size_override("font_size", 24)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	card_vbox.add_child(name_lbl)

	var name_input := LineEdit.new()
	name_input.name = "AllianceNameInput"
	name_input.placeholder_text = "Örn: Aslanlar Birliği"
	name_input.text = _draft_create_name
	name_input.custom_minimum_size = Vector2(0, 52)
	name_input.add_theme_font_size_override("font_size", 24)
	_style_input(name_input)
	var gc_a: Node = Engine.get_main_loop().root.get_node_or_null("GameConfig") if Engine.get_main_loop() is SceneTree else null
	if gc_a != null and gc_a.has_method("bind_keyboard_dismiss"):
		gc_a.call("bind_keyboard_dismiss", name_input)
	_create_name_input = name_input
	card_vbox.add_child(name_input)

	# Etiket (Tag - max 6 char)
	var tag_lbl := Label.new()
	tag_lbl.text = "İttifak Etiketi (En fazla 6 karakter, örn: ASLAN):"
	tag_lbl.add_theme_font_size_override("font_size", 24)
	tag_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	card_vbox.add_child(tag_lbl)

	var tag_input := LineEdit.new()
	tag_input.name = "AllianceTagInput"
	tag_input.placeholder_text = "ASLAN"
	tag_input.text = _draft_create_tag
	tag_input.max_length = 6
	tag_input.custom_minimum_size = Vector2(0, 52)
	tag_input.add_theme_font_size_override("font_size", 24)
	_style_input(tag_input)
	if gc_a != null and gc_a.has_method("bind_keyboard_dismiss"):
		gc_a.call("bind_keyboard_dismiss", tag_input)
	_create_tag_input = tag_input
	card_vbox.add_child(tag_input)

	# Açıklama
	var desc_field_lbl := Label.new()
	desc_field_lbl.text = "İttifak Tanımı / Slogan:"
	desc_field_lbl.add_theme_font_size_override("font_size", 24)
	desc_field_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	card_vbox.add_child(desc_field_lbl)

	var desc_input := TextEdit.new()
	desc_input.name = "AllianceDescInput"
	desc_input.custom_minimum_size = Vector2(0, 100)
	desc_input.placeholder_text = "Krallığımızın onurlu kılıçları..."
	desc_input.text = _draft_create_desc
	desc_input.add_theme_font_size_override("font_size", 22)
	_style_input(desc_input)
	if gc_a != null and gc_a.has_method("bind_keyboard_dismiss"):
		gc_a.call("bind_keyboard_dismiss", desc_input)
	_create_desc_input = desc_input
	card_vbox.add_child(desc_input)

	var err_label := Label.new()
	err_label.add_theme_font_size_override("font_size", 22)
	err_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	card_vbox.add_child(err_label)

	var create_btn := Button.new()
	create_btn.text = " İttifakı Kur"
	create_btn.custom_minimum_size = Vector2(0, 60)
	create_btn.add_theme_font_override("font", FontCinzelBold)
	create_btn.add_theme_font_size_override("font_size", 26)
	_style_gold_btn(create_btn)
	create_btn.pressed.connect(func():
		if create_btn.disabled:
			return
		if gc_a != null and gc_a.has_method("dismiss_keyboard_for"):
			gc_a.call("dismiss_keyboard_for", null)
		var state: Dictionary = gs.to_dict()
		var res := AllianceModelScript.create_alliance(
			state,
			player_name,
			name_input.text,
			tag_input.text,
			desc_input.text
		)
		if bool(res.get("ok", false)):
			create_btn.disabled = true
			_draft_create_name = ""
			_draft_create_tag = ""
			_draft_create_desc = ""
			name_input.text = ""
			tag_input.text = ""
			desc_input.text = ""
			_suppress_state_refresh = true
			gs.from_dict(state)
			_save_game(true)
			_suppress_state_refresh = false
			_active_tab = "chat"
			refresh_view()
		else:
			err_label.text = " " + str(res.get("message", "Hata oluştu."))
	)
	card_vbox.add_child(create_btn)


func _build_browse_alliances_view(parent: Control, gs: Node, player_name: String) -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	parent.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 16)
	scroll.add_child(vbox)

	# Bekleyen Davetler
	var state: Dictionary = gs.to_dict()
	var pending_allies := []
	for a in state.get("alliances", []):
		if typeof(a) != TYPE_DICTIONARY:
			continue
		for inv in (a as Dictionary).get("invitations", []):
			if typeof(inv) == TYPE_DICTIONARY and str((inv as Dictionary).get("player_name", "")) == player_name:
				pending_allies.append(a)
				break

	if not pending_allies.is_empty():
		var inv_card := _make_card()
		vbox.add_child(inv_card)
		var ic_vbox := VBoxContainer.new()
		ic_vbox.add_theme_constant_override("separation", 10)
		inv_card.add_child(ic_vbox)

		var inv_title := Label.new()
		inv_title.text = " Size Gelen İttifak Davetleri (%d)" % pending_allies.size()
		inv_title.add_theme_font_override("font", FontCinzelBold)
		inv_title.add_theme_font_size_override("font_size", 26)
		inv_title.add_theme_color_override("font_color", Color(0.45, 0.90, 1.0))
		ic_vbox.add_child(inv_title)

		for ally in pending_allies:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			ic_vbox.add_child(row)

			var info_lbl := Label.new()
			info_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
			info_lbl.add_theme_font_size_override("font_size", 24)
			info_lbl.text = " [%s] %s (Lider: %s)" % [str(ally.get("tag", "")), str(ally.get("name", "")), str(ally.get("leader", ""))]
			row.add_child(info_lbl)

			var accept_btn := Button.new()
			accept_btn.text = " Kabul Et"
			accept_btn.custom_minimum_size = Vector2(130, 48)
			_style_gold_btn(accept_btn)
			var a_id = int(ally.get("id", -1))
			accept_btn.pressed.connect(func():
				if accept_btn.disabled:
					return
				var st: Dictionary = gs.to_dict()
				var res := AllianceModelScript.accept_invitation(st, player_name, a_id)
				if bool(res.get("ok", false)):
					accept_btn.disabled = true
					_suppress_state_refresh = true
					gs.from_dict(st)
					_save_game(true)
					_suppress_state_refresh = false
					_active_tab = "chat"
					refresh_view()
			)
			row.add_child(accept_btn)

	# Mevcut İttifaklar Listesi
	var list_title := Label.new()
	list_title.text = "Mevcut Dünya İttifakları"
	list_title.add_theme_font_override("font", FontCinzelBold)
	list_title.add_theme_font_size_override("font_size", 26)
	list_title.add_theme_color_override("font_color", Color(1.0, 0.90, 0.45))
	vbox.add_child(list_title)

	var allies: Array = state.get("alliances", [])
	if allies.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Dünyada henüz kurulmuş bir ittifak bulunmuyor. İlk ittifakı siz kurun!"
		empty_lbl.add_theme_font_size_override("font_size", 22)
		empty_lbl.add_theme_color_override("font_color", Color(0.65, 0.60, 0.55))
		vbox.add_child(empty_lbl)
		return

	for a in allies:
		if typeof(a) != TYPE_DICTIONARY:
			continue
		var a_dict := a as Dictionary
		var row_card := _make_card()
		vbox.add_child(row_card)

		var r_hbox := HBoxContainer.new()
		r_hbox.add_theme_constant_override("separation", 14)
		row_card.add_child(r_hbox)

		var info_box := VBoxContainer.new()
		info_box.size_flags_horizontal = SIZE_EXPAND_FILL
		r_hbox.add_child(info_box)

		var tag_name_lbl := Label.new()
		tag_name_lbl.text = "[%s] %s" % [str(a_dict.get("tag", "")), str(a_dict.get("name", ""))]
		tag_name_lbl.add_theme_font_override("font", FontCinzelBold)
		tag_name_lbl.add_theme_font_size_override("font_size", 24)
		tag_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.60))
		info_box.add_child(tag_name_lbl)

		var members_count: int = (a_dict.get("members", []) as Array).size()
		var leader_name: String = str(a_dict.get("leader", ""))
		var desc: String = str(a_dict.get("description", ""))
		var sub_lbl := Label.new()
		sub_lbl.text = " Lider: %s |  %d Üye | %s" % [leader_name, members_count, desc]
		sub_lbl.add_theme_font_size_override("font_size", 20)
		sub_lbl.add_theme_color_override("font_color", Color(0.75, 0.72, 0.65))
		info_box.add_child(sub_lbl)


# =============================================================================
#  Üye Görünümü (Sohbet, Üyeler, Davet, Diplomasi)
# =============================================================================

func _build_member_view(gs: Node, alliance: Dictionary, player_name: String) -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 12)
	content_area.add_child(vbox)

	# Üst Bilgi Kartı
	var info_bar := _make_card()
	vbox.add_child(info_bar)
	var ib_hbox := HBoxContainer.new()
	ib_hbox.add_theme_constant_override("separation", 18)
	info_bar.add_child(ib_hbox)

	var members: Array = alliance.get("members", [])
	var total_pts := 0
	for m in members:
		total_pts += int((m as Dictionary).get("points", 0))

	var stat_lbl := Label.new()
	stat_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
	stat_lbl.text = " Lider: %s   |    Üye: %d   |    Toplam Puan: %d" % [
		str(alliance.get("leader", "")),
		members.size(),
		total_pts
	]
	stat_lbl.add_theme_font_override("font", FontNunitoBold)
	stat_lbl.add_theme_font_size_override("font_size", 24)
	stat_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.70))
	ib_hbox.add_child(stat_lbl)

	var leave_btn := Button.new()
	leave_btn.text = " Ayrıl"
	leave_btn.custom_minimum_size = Vector2(100, 42)
	_style_danger_btn(leave_btn)
	leave_btn.pressed.connect(func():
		if leave_btn.disabled:
			return
		leave_btn.disabled = true
		var state: Dictionary = gs.to_dict()
		AllianceModelScript.leave_alliance(state, player_name)
		_suppress_state_refresh = true
		gs.from_dict(state)
		_save_game(true)
		_suppress_state_refresh = false
		refresh_view()
	)
	ib_hbox.add_child(leave_btn)

	# İç Duyuru Paneli
	var ann_text: String = str(alliance.get("internal_announcement", ""))
	if not ann_text.is_empty():
		var ann_box := PanelContainer.new()
		var ann_sb := StyleBoxFlat.new()
		ann_sb.bg_color = Color(0.18, 0.15, 0.08, 0.95)
		ann_sb.border_color = Color(0.95, 0.78, 0.30, 0.9)
		ann_sb.set_border_width_all(1)
		ann_sb.set_corner_radius_all(10)
		ann_sb.content_margin_left = 14
		ann_sb.content_margin_right = 14
		ann_sb.content_margin_top = 8
		ann_sb.content_margin_bottom = 8
		ann_box.add_theme_stylebox_override("panel", ann_sb)
		vbox.add_child(ann_box)

		var ann_lbl := Label.new()
		ann_lbl.text = " İç Duyuru: " + ann_text
		ann_lbl.add_theme_font_override("font", FontNunitoBold)
		ann_lbl.add_theme_font_size_override("font_size", 22)
		ann_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.60))
		ann_box.add_child(ann_lbl)

	# Sekmeler
	var tab_bar := HBoxContainer.new()
	tab_bar.custom_minimum_size = Vector2(0, 52)
	tab_bar.add_theme_constant_override("separation", 10)
	vbox.add_child(tab_bar)

	var t_chat := _make_tab_button(" İttifak Sohbeti", _active_tab == "chat")
	t_chat.pressed.connect(func(): _active_tab = "chat"; refresh_view())
	tab_bar.add_child(t_chat)

	var t_members := _make_tab_button(" Üyeler (%d)" % members.size(), _active_tab == "members")
	t_members.pressed.connect(func(): _active_tab = "members"; refresh_view())
	tab_bar.add_child(t_members)

	var t_invite := _make_tab_button(" Davet Gönder", _active_tab == "invite")
	t_invite.pressed.connect(func(): _active_tab = "invite"; refresh_view())
	tab_bar.add_child(t_invite)

	var t_diplomacy := _make_tab_button(" Diplomasi", _active_tab == "diplomacy")
	t_diplomacy.pressed.connect(func(): _active_tab = "diplomacy"; refresh_view())
	tab_bar.add_child(t_diplomacy)

	match _active_tab:
		"chat":
			_build_chat_tab(vbox, gs, alliance, player_name)
		"members":
			_build_members_tab(vbox, gs, alliance, player_name)
		"invite":
			_build_invite_tab(vbox, gs, alliance, player_name)
		"diplomacy":
			_build_diplomacy_tab(vbox, gs, alliance, player_name)


# --- Sekme 1: İttifak İçi Sohbet (Alliance Chat) ------------------------------

func _build_chat_tab(parent: Control, gs: Node, alliance: Dictionary, player_name: String) -> void:
	var chat_container := VBoxContainer.new()
	chat_container.size_flags_vertical = SIZE_EXPAND_FILL
	chat_container.add_theme_constant_override("separation", 10)
	parent.add_child(chat_container)

	# Mesaj listesi
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	chat_container.add_child(scroll)

	var msg_list := VBoxContainer.new()
	msg_list.size_flags_horizontal = SIZE_EXPAND_FILL
	msg_list.add_theme_constant_override("separation", 8)
	scroll.add_child(msg_list)

	var chat_messages: Array = alliance.get("chat_messages", [])
	for m in chat_messages:
		if typeof(m) != TYPE_DICTIONARY:
			continue
		var msg_dict := m as Dictionary
		var sender := str(msg_dict.get("sender", ""))
		var text := str(msg_dict.get("text", ""))
		var ts := int(msg_dict.get("timestamp_unix", 0))

		var time_dt = Time.get_time_dict_from_unix_time(ts)
		var time_str := "%02d:%02d" % [time_dt["hour"], time_dt["minute"]]

		var row := HBoxContainer.new()
		row.size_flags_horizontal = SIZE_EXPAND_FILL

		var bubble := PanelContainer.new()
		bubble.size_flags_horizontal = SIZE_EXPAND_FILL
		var b_sb := StyleBoxFlat.new()
		var is_me := (sender == player_name)
		var is_sys := (sender == "Sistem")

		if is_sys:
			b_sb.bg_color = Color(0.18, 0.16, 0.12, 0.9)
			b_sb.border_color = Color(0.70, 0.60, 0.35, 0.6)
		elif is_me:
			b_sb.bg_color = Color(0.12, 0.22, 0.18, 0.95)
			b_sb.border_color = Color(0.35, 0.85, 0.50, 0.85)
		else:
			b_sb.bg_color = Color(0.15, 0.14, 0.20, 0.95)
			b_sb.border_color = Color(0.45, 0.60, 0.85, 0.8)

		b_sb.set_border_width_all(1)
		b_sb.set_corner_radius_all(12)
		b_sb.content_margin_left = 14
		b_sb.content_margin_right = 14
		b_sb.content_margin_top = 8
		b_sb.content_margin_bottom = 8
		bubble.add_theme_stylebox_override("panel", b_sb)

		var b_vbox := VBoxContainer.new()
		b_vbox.add_theme_constant_override("separation", 2)
		bubble.add_child(b_vbox)

		var s_lbl := Label.new()
		s_lbl.text = "%s  —  %s" % [sender, time_str]
		s_lbl.add_theme_font_override("font", FontNunitoBold)
		s_lbl.add_theme_font_size_override("font_size", 20)
		s_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.40) if is_me else (Color(0.50, 0.85, 1.0) if not is_sys else Color(0.85, 0.70, 0.40)))
		b_vbox.add_child(s_lbl)

		var t_lbl := Label.new()
		t_lbl.text = text
		t_lbl.add_theme_font_size_override("font_size", 24)
		t_lbl.add_theme_color_override("font_color", Color(0.96, 0.94, 0.90))
		t_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b_vbox.add_child(t_lbl)

		row.add_child(bubble)
		msg_list.add_child(row)

	# Otomatik en alta kaydır
	scroll.call_deferred("set_v_scroll", 99999)

	# Mesaj Gönderme Kutusu
	var send_box := HBoxContainer.new()
	send_box.custom_minimum_size = Vector2(0, 56)
	send_box.add_theme_constant_override("separation", 10)
	chat_container.add_child(send_box)

	var chat_input := LineEdit.new()
	chat_input.name = "AllianceChatInput"
	chat_input.size_flags_horizontal = SIZE_EXPAND_FILL
	chat_input.placeholder_text = "İttifak arkadaşlarına mesaj yaz..."
	chat_input.text = _draft_chat_text
	chat_input.add_theme_font_size_override("font_size", 24)
	_style_input(chat_input)
	var gc_c: Node = Engine.get_main_loop().root.get_node_or_null("GameConfig") if Engine.get_main_loop() is SceneTree else null
	if gc_c != null and gc_c.has_method("bind_keyboard_dismiss"):
		gc_c.call("bind_keyboard_dismiss", chat_input)
	_chat_input = chat_input
	send_box.add_child(chat_input)

	var send_btn := Button.new()
	send_btn.text = "Gönder "
	send_btn.custom_minimum_size = Vector2(130, 56)
	send_btn.add_theme_font_override("font", FontNunitoBold)
	send_btn.add_theme_font_size_override("font_size", 24)
	_style_gold_btn(send_btn)

	var on_send := func():
		var text := chat_input.text.strip_edges()
		if text.is_empty():
			return
		var state: Dictionary = gs.to_dict()
		var a_id = int(alliance.get("id", -1))
		var res := AllianceModelScript.send_chat_message(state, a_id, player_name, text)
		if bool(res.get("ok", false)):
			_draft_chat_text = ""
			chat_input.text = ""
			_suppress_state_refresh = true
			gs.from_dict(state)
			_save_game(true)
			_suppress_state_refresh = false
			refresh_view()

	send_btn.pressed.connect(on_send)
	chat_input.text_submitted.connect(func(_t): on_send.call())
	send_box.add_child(send_btn)


# --- Sekme 2: Üyeler ----------------------------------------------------------

func _build_members_tab(parent: Control, gs: Node, alliance: Dictionary, player_name: String) -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	parent.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	var members: Array = alliance.get("members", [])
	var is_leader := (str(alliance.get("leader", "")) == player_name)

	for m in members:
		if typeof(m) != TYPE_DICTIONARY:
			continue
		var m_dict := m as Dictionary
		var m_name := str(m_dict.get("name", ""))
		var m_rank := str(m_dict.get("rank_title", "Üye"))
		var m_pts := int(m_dict.get("points", 0))
		var m_is_lead := bool(m_dict.get("is_leader", false))

		var card := _make_card()
		vbox.add_child(card)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 14)
		card.add_child(hbox)

		var icon_lbl := Label.new()
		icon_lbl.text = "" if m_is_lead else ""
		icon_lbl.add_theme_font_size_override("font_size", 30)
		hbox.add_child(icon_lbl)

		var info_vbox := VBoxContainer.new()
		info_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
		hbox.add_child(info_vbox)

		var name_lbl := Label.new()
		name_lbl.text = "%s (%s)" % [m_name, m_rank]
		name_lbl.add_theme_font_override("font", FontNunitoBold)
		name_lbl.add_theme_font_size_override("font_size", 24)
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
		info_vbox.add_child(name_lbl)

		var pts_lbl := Label.new()
		pts_lbl.text = " Puan: %d" % m_pts
		pts_lbl.add_theme_font_size_override("font_size", 20)
		pts_lbl.add_theme_color_override("font_color", Color(0.75, 0.72, 0.65))
		info_vbox.add_child(pts_lbl)

		# Lider diğer üyeleri atabilir
		if is_leader and m_name != player_name:
			var kick_btn := Button.new()
			kick_btn.text = " At"
			kick_btn.custom_minimum_size = Vector2(80, 42)
			_style_danger_btn(kick_btn)
			kick_btn.pressed.connect(func():
				var st: Dictionary = gs.to_dict()
				AllianceModelScript.kick_member(st, player_name, m_name)
				_suppress_state_refresh = true
				gs.from_dict(st)
				_save_game(true)
				_suppress_state_refresh = false
				refresh_view()
			)
			hbox.add_child(kick_btn)


# --- Sekme 3: Davet Gönder ---------------------------------------------------

func _build_invite_tab(parent: Control, gs: Node, alliance: Dictionary, player_name: String) -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	parent.add_child(vbox)

	var card := _make_card()
	vbox.add_child(card)

	var c_vbox := VBoxContainer.new()
	c_vbox.add_theme_constant_override("separation", 12)
	card.add_child(c_vbox)

	var title := Label.new()
	title.text = "Yeni Oyuncu Davet Et"
	title.add_theme_font_override("font", FontCinzelBold)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.90, 0.45))
	c_vbox.add_child(title)

	var input := LineEdit.new()
	input.name = "AllianceInviteInput"
	input.placeholder_text = "Davet edilecek lordun adı (örn: Lord Edward)..."
	input.text = _draft_invite_text
	input.custom_minimum_size = Vector2(0, 52)
	input.add_theme_font_size_override("font_size", 24)
	_style_input(input)
	var gc_i: Node = Engine.get_main_loop().root.get_node_or_null("GameConfig") if Engine.get_main_loop() is SceneTree else null
	if gc_i != null and gc_i.has_method("bind_keyboard_dismiss"):
		gc_i.call("bind_keyboard_dismiss", input)
	_invite_input = input
	c_vbox.add_child(input)

	var msg_lbl := Label.new()
	msg_lbl.add_theme_font_size_override("font_size", 22)
	c_vbox.add_child(msg_lbl)

	var send_inv_btn := Button.new()
	send_inv_btn.text = " Davet Gönder"
	send_inv_btn.custom_minimum_size = Vector2(0, 52)
	_style_gold_btn(send_inv_btn)
	send_inv_btn.pressed.connect(func():
		var target := input.text.strip_edges()
		var st: Dictionary = gs.to_dict()
		var a_id = int(alliance.get("id", -1))
		var res := AllianceModelScript.invite_player(st, a_id, player_name, target)
		if bool(res.get("ok", false)):
			_draft_invite_text = ""
			input.text = ""
			_suppress_state_refresh = true
			gs.from_dict(st)
			_save_game(true)
			_suppress_state_refresh = false
			msg_lbl.text = " %s başarıyla davet edildi!" % target
			msg_lbl.add_theme_color_override("font_color", Color(0.40, 0.90, 0.50))
		else:
			msg_lbl.text = " " + str(res.get("message", "Hata"))
			msg_lbl.add_theme_color_override("font_color", Color(1.0, 0.40, 0.40))
	)
	c_vbox.add_child(send_inv_btn)


# --- Sekme 4: Diplomasi ------------------------------------------------------

func _build_diplomacy_tab(parent: Control, gs: Node, alliance: Dictionary, player_name: String) -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	parent.add_child(vbox)

	var diplo: Dictionary = alliance.get("diplomacy", {})
	var allies: Array = diplo.get("allies", [])
	var nap: Array = diplo.get("nap", [])
	var enemies: Array = diplo.get("enemies", [])

	var card := _make_card()
	vbox.add_child(card)
	var c_vbox := VBoxContainer.new()
	c_vbox.add_theme_constant_override("separation", 12)
	card.add_child(c_vbox)

	var t1 := Label.new()
	t1.text = " Diplomasi İlişkileri"
	t1.add_theme_font_override("font", FontCinzelBold)
	t1.add_theme_font_size_override("font_size", 24)
	t1.add_theme_color_override("font_color", Color(1.0, 0.90, 0.45))
	c_vbox.add_child(t1)

	var d_lbl := Label.new()
	d_lbl.text = "• Müttefikler (Sarı Renk): %s\n• Saldırmazlık Paktı / NAP (Turuncu Renk): %s\n• Düşmanlar (Kırmızı Renk): %s" % [
		str(allies) if not allies.is_empty() else "Yok",
		str(nap) if not nap.is_empty() else "Yok",
		str(enemies) if not enemies.is_empty() else "Yok"
	]
	d_lbl.add_theme_font_size_override("font_size", 22)
	d_lbl.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
	c_vbox.add_child(d_lbl)


# =============================================================================
#  Stil ve Yardımcılar
# =============================================================================

func _make_card() -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.10, 0.16, 0.96)
	sb.border_color = Color(0.85, 0.72, 0.40, 0.85)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 0
	pc.add_theme_stylebox_override("panel", sb)
	return pc


func _make_tab_button(text: String, is_active: bool) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.size_flags_horizontal = SIZE_EXPAND_FILL
	btn.add_theme_font_override("font", FontNunitoBold)
	btn.add_theme_font_size_override("font_size", 22)

	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	if is_active:
		sb.bg_color = Color(0.85, 0.68, 0.28, 0.3)
		sb.border_color = Color(0.96, 0.84, 0.45, 1.0)
		sb.set_border_width_all(2)
		btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.80))
	else:
		sb.bg_color = Color(0.14, 0.12, 0.18, 0.8)
		sb.border_color = Color(0.40, 0.35, 0.45, 0.5)
		sb.set_border_width_all(1)
		btn.add_theme_color_override("font_color", Color(0.70, 0.68, 0.65))

	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	return btn


func _style_input(ctrl: Control) -> void:
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


func _style_gold_btn(btn: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.80, 0.60, 0.20, 0.95)
	sb.border_color = Color(1.0, 0.88, 0.50, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 0
	btn.add_theme_stylebox_override("normal", sb)
	var h_sb = sb.duplicate() as StyleBoxFlat
	h_sb.bg_color = Color(0.92, 0.70, 0.25, 1.0)
	btn.add_theme_stylebox_override("hover", h_sb)
	btn.add_theme_color_override("font_color", Color(0.12, 0.08, 0.02))


func _style_danger_btn(btn: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.65, 0.18, 0.15, 0.95)
	sb.border_color = Color(0.95, 0.55, 0.45, 0.95)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))


func _save_game(is_alliance_mutation: bool = true) -> void:
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return
	var wm := (loop as SceneTree).root.get_node_or_null("WorldManager")
	if is_alliance_mutation and wm != null and wm.has_method("notify_local_alliance_mutation"):
		wm.call("notify_local_alliance_mutation")
	var sm := (loop as SceneTree).root.get_node_or_null("SaveManager")
	if sm != null:
		sm.save_game()
	if is_alliance_mutation and wm != null and wm.has_method("save_active_world"):
		wm.call("save_active_world", true)
