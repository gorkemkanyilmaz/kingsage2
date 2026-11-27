extends Control
## Alliance — İttifak Yönetim ve Canlı Sohbet Ekranı (Taht ve Kılıç / docs/12).

const AllianceModelScript := preload("res://scripts/model/AllianceModel.gd")
const FontNunitoRegular := preload("res://assets/fonts/Nunito-Regular.ttf")
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
var _editing_announcement: bool = false
var _ann_edit_input: TextEdit = null
var _draft_ann_text: String = ""
var _diplo_search_input: LineEdit = null
var _draft_diplo_search: String = ""
var _diplo_status_msg: String = ""
var _diplo_status_ok: bool = true


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
	if header_title != null:
		header_title.add_theme_font_override("font", FontNunitoBold)
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
	if _ann_edit_input != null and is_instance_valid(_ann_edit_input):
		_draft_ann_text = _ann_edit_input.text
	if _diplo_search_input != null and is_instance_valid(_diplo_search_input):
		_draft_diplo_search = _diplo_search_input.text


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
		if _editing_announcement or _has_focused_text_input():
			return
		if not _is_member_view_rendered and _non_member_tab == "create":
			return
		if _is_member_view_rendered and _active_tab in ["invite", "diplomacy"]:
			return
	refresh_view()


func refresh_view() -> void:
	_capture_input_drafts()
	_create_name_input = null
	_create_tag_input = null
	_create_desc_input = null
	_chat_input = null
	_invite_input = null
	_ann_edit_input = null
	_diplo_search_input = null
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
	title.add_theme_font_override("font", FontNunitoBold)
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
	create_btn.add_theme_font_override("font", FontNunitoBold)
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
		inv_title.add_theme_font_override("font", FontNunitoBold)
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
	list_title.add_theme_font_override("font", FontNunitoBold)
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
		tag_name_lbl.add_theme_font_override("font", FontNunitoBold)
		tag_name_lbl.add_theme_font_size_override("font_size", 24)
		tag_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.60))
		info_box.add_child(tag_name_lbl)

		var members_count: int = (a_dict.get("members", []) as Array).size()
		var leader_name: String = str(a_dict.get("leader", ""))
		var desc: String = str(a_dict.get("description", ""))
		var sub_lbl := Label.new()
		sub_lbl.text = " Lider: %s |  %d Üye | %s" % [leader_name, members_count, desc]
		sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub_lbl.add_theme_font_size_override("font_size", 20)
		sub_lbl.add_theme_color_override("font_color", Color(0.75, 0.72, 0.65))
		info_box.add_child(sub_lbl)

		var a_id_b := int(a_dict.get("id", -1))
		var already_req := AllianceModelScript.has_pending_join_request(a_dict, player_name)
		var req_btn := Button.new()
		req_btn.name = ("BtnCancelJoinReq_%d" if already_req else "BtnJoinReq_%d") % a_id_b
		req_btn.text = "⏳ İsteği İptal Et" if already_req else "📩 Katılma İsteği"
		req_btn.custom_minimum_size = Vector2(200, 48)
		req_btn.size_flags_vertical = SIZE_SHRINK_CENTER
		req_btn.add_theme_font_override("font", FontNunitoBold)
		req_btn.add_theme_font_size_override("font_size", 20)
		if already_req:
			_style_danger_btn(req_btn)
		else:
			_style_gold_btn(req_btn)
		req_btn.pressed.connect(func():
			if req_btn.disabled:
				return
			req_btn.disabled = true
			var st_req: Dictionary = gs.to_dict()
			var r_req := (
				AllianceModelScript.cancel_join_request(st_req, player_name, a_id_b)
				if already_req
				else AllianceModelScript.request_join_alliance(st_req, player_name, a_id_b)
			)
			if bool(r_req.get("ok", false)):
				_suppress_state_refresh = true
				gs.from_dict(st_req)
				_save_game(true)
				_suppress_state_refresh = false
				refresh_view()
		)
		r_hbox.add_child(req_btn)


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

	# İç Duyuru Paneli (Kurucu Lider düzenleyebilir, tüm üyeler görür)
	var wm_node = Engine.get_main_loop().root.get_node_or_null("WorldManager") if Engine.get_main_loop() is SceneTree else null
	var raw_ann: String = str(alliance.get("internal_announcement", ""))
	if wm_node != null and wm_node.get_script() != null and wm_node.get_script().has_method("repair_mojibake_str"):
		raw_ann = str(wm_node.get_script().call("repair_mojibake_str", raw_ann))
	var ann_text: String = raw_ann.strip_edges()
	var is_founder_user := AllianceModelScript.is_founder(alliance, player_name)
	if not ann_text.is_empty() or is_founder_user:
		var ann_box := PanelContainer.new()
		ann_box.name = "InternalAnnouncementCard"
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

		var ann_vb := VBoxContainer.new()
		ann_vb.add_theme_constant_override("separation", 8)
		ann_box.add_child(ann_vb)

		var ann_hdr := HBoxContainer.new()
		ann_hdr.add_theme_constant_override("separation", 10)
		ann_vb.add_child(ann_hdr)

		var ann_lbl := Label.new()
		ann_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
		ann_lbl.text = "📢 İç Duyuru: " + (ann_text if not ann_text.is_empty() else "Henüz bir iç duyuru eklenmedi.")
		ann_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ann_lbl.add_theme_font_override("font", FontNunitoBold)
		ann_lbl.add_theme_font_size_override("font_size", 22)
		ann_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.60))
		ann_hdr.add_child(ann_lbl)

		if is_founder_user and not _editing_announcement:
			var edit_ann_btn := Button.new()
			edit_ann_btn.name = "EditAnnouncementBtn"
			edit_ann_btn.text = "✏️ Düzenle"
			edit_ann_btn.custom_minimum_size = Vector2(132, 40)
			edit_ann_btn.add_theme_font_override("font", FontNunitoBold)
			edit_ann_btn.add_theme_font_size_override("font_size", 20)
			_style_gold_btn(edit_ann_btn)
			edit_ann_btn.pressed.connect(func():
				_draft_ann_text = ann_text
				_editing_announcement = true
				refresh_view()
			)
			ann_hdr.add_child(edit_ann_btn)

		if is_founder_user and _editing_announcement:
			var gc_ann: Node = Engine.get_main_loop().root.get_node_or_null("GameConfig") if Engine.get_main_loop() is SceneTree else null
			var ann_edit := TextEdit.new()
			ann_edit.name = "AnnouncementEditInput"
			ann_edit.custom_minimum_size = Vector2(0, 96)
			ann_edit.text = _draft_ann_text if not _draft_ann_text.is_empty() else ann_text
			ann_edit.placeholder_text = "Tüm ittifak üyelerinin göreceği iç duyuruyu yazın..."
			ann_edit.add_theme_font_override("font", FontNunitoRegular)
			ann_edit.add_theme_font_size_override("font_size", 21)
			_style_input(ann_edit)
			if gc_ann != null and gc_ann.has_method("bind_keyboard_dismiss"):
				gc_ann.call("bind_keyboard_dismiss", ann_edit)
			_ann_edit_input = ann_edit
			ann_vb.add_child(ann_edit)

			var ann_btns := HBoxContainer.new()
			ann_btns.add_theme_constant_override("separation", 10)
			ann_vb.add_child(ann_btns)

			var save_ann_btn := Button.new()
			save_ann_btn.name = "SaveAnnouncementBtn"
			save_ann_btn.text = "💾 Kaydet"
			save_ann_btn.custom_minimum_size = Vector2(140, 44)
			save_ann_btn.add_theme_font_override("font", FontNunitoBold)
			save_ann_btn.add_theme_font_size_override("font_size", 20)
			_style_gold_btn(save_ann_btn)
			save_ann_btn.pressed.connect(func():
				if gc_ann != null and gc_ann.has_method("dismiss_keyboard_for"):
					gc_ann.call("dismiss_keyboard_for", null)
				var st_a: Dictionary = gs.to_dict()
				var a_id := int(alliance.get("id", -1))
				var u_res := AllianceModelScript.update_announcement(st_a, a_id, player_name, ann_edit.text)
				if bool(u_res.get("ok", false)):
					_editing_announcement = false
					_draft_ann_text = ""
					_suppress_state_refresh = true
					gs.from_dict(st_a)
					_save_game(true)
					_suppress_state_refresh = false
					refresh_view()
			)
			ann_btns.add_child(save_ann_btn)

			var cancel_ann_btn := Button.new()
			cancel_ann_btn.text = "İptal"
			cancel_ann_btn.custom_minimum_size = Vector2(110, 44)
			cancel_ann_btn.add_theme_font_override("font", FontNunitoBold)
			cancel_ann_btn.add_theme_font_size_override("font_size", 20)
			_style_danger_btn(cancel_ann_btn)
			cancel_ann_btn.pressed.connect(func():
				_editing_announcement = false
				_draft_ann_text = ""
				refresh_view()
			)
			ann_btns.add_child(cancel_ann_btn)

	var is_leader_member := AllianceModelScript.is_leader(alliance, player_name)
	var join_reqs: Array = alliance.get("join_requests", []) if typeof(alliance.get("join_requests")) == TYPE_ARRAY else []
	var pending_req_cnt: int = join_reqs.size() if is_leader_member else 0

	if pending_req_cnt > 0 and _active_tab != "invite":
		var req_alert := Button.new()
		req_alert.name = "JoinRequestsAlertBanner"
		req_alert.text = "🔔 %d yeni ittifaka katılma isteği var! İncelemek ve onaylamak için dokunun." % pending_req_cnt
		req_alert.custom_minimum_size = Vector2(0, 48)
		req_alert.add_theme_font_override("font", FontNunitoBold)
		req_alert.add_theme_font_size_override("font_size", 20)
		var ab_sb := StyleBoxFlat.new()
		ab_sb.bg_color = Color(0.54, 0.14, 0.14, 0.96)
		ab_sb.border_color = Color(1.0, 0.56, 0.44, 1.0)
		ab_sb.set_border_width_all(2)
		ab_sb.set_corner_radius_all(10)
		req_alert.add_theme_stylebox_override("normal", ab_sb)
		req_alert.add_theme_stylebox_override("hover", ab_sb)
		req_alert.add_theme_color_override("font_color", Color(1, 0.96, 0.94))
		req_alert.pressed.connect(func(): _active_tab = "invite"; refresh_view())
		vbox.add_child(req_alert)

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

	var invite_lbl := (" Davet (%d)" % pending_req_cnt) if pending_req_cnt > 0 else " Davet Gönder"
	var t_invite := _make_tab_button(invite_lbl, _active_tab == "invite")
	t_invite.name = "TabInviteBtn"
	if pending_req_cnt > 0 and _active_tab != "invite":
		t_invite.add_theme_color_override("font_color", Color(1.0, 0.56, 0.50))
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
		var text := str(msg_dict.get("text", "")).strip_edges()
		var wm_c = Engine.get_main_loop().root.get_node_or_null("WorldManager") if Engine.get_main_loop() is SceneTree else null
		if wm_c != null and wm_c.get_script() != null and wm_c.get_script().has_method("repair_mojibake_str"):
			sender = str(wm_c.get_script().call("repair_mojibake_str", sender))
			text = str(wm_c.get_script().call("repair_mojibake_str", text))
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
		var is_sender_leader := (not is_sys) and AllianceModelScript.is_leader(alliance, sender)

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
		var disp_sender := ("👑 " + sender) if is_sender_leader else sender
		s_lbl.text = "%s  —  %s" % [disp_sender, time_str]
		s_lbl.add_theme_font_override("font", FontNunitoBold)
		s_lbl.add_theme_font_size_override("font_size", 20)
		s_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35) if (is_me or is_sender_leader) else (Color(0.50, 0.85, 1.0) if not is_sys else Color(0.85, 0.70, 0.40)))
		b_vbox.add_child(s_lbl)

		var t_lbl := Label.new()
		t_lbl.text = text
		t_lbl.add_theme_font_override("font", FontNunitoRegular)
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
		icon_lbl.text = "👑" if (m_is_lead or AllianceModelScript.is_leader(alliance, m_name)) else "🛡️"
		icon_lbl.add_theme_font_size_override("font_size", 30)
		hbox.add_child(icon_lbl)

		var info_vbox := VBoxContainer.new()
		info_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
		hbox.add_child(info_vbox)

		var name_btn := Button.new()
		name_btn.text = "👤 %s (%s)" % [m_name, m_rank]
		name_btn.flat = true
		name_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		name_btn.add_theme_font_override("font", FontNunitoBold)
		name_btn.add_theme_font_size_override("font_size", 24)
		name_btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
		name_btn.add_theme_color_override("font_hover_color", Color(0.55, 0.90, 1.0))
		name_btn.pressed.connect(func(): _open_player_profile_modal(gs, m_name, -1, false))
		info_vbox.add_child(name_btn)

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


# --- Sekme 3: Davet Gönder & Katılma İstekleri -------------------------------

func _build_invite_tab(parent: Control, gs: Node, alliance: Dictionary, player_name: String) -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 14)
	scroll.add_child(vbox)

	var a_id_cur := int(alliance.get("id", -1))
	var is_leader := AllianceModelScript.is_leader(alliance, player_name)
	var join_reqs: Array = alliance.get("join_requests", []) if typeof(alliance.get("join_requests")) == TYPE_ARRAY else []

	if is_leader:
		var req_card := _make_card()
		req_card.name = "JoinRequestsCard"
		vbox.add_child(req_card)
		var r_vb := VBoxContainer.new()
		r_vb.add_theme_constant_override("separation", 10)
		req_card.add_child(r_vb)

		var r_title := Label.new()
		r_title.text = "📥 Gelen Katılma İstekleri (%d)" % join_reqs.size()
		r_title.add_theme_font_override("font", FontNunitoBold)
		r_title.add_theme_font_size_override("font_size", 24)
		r_title.add_theme_color_override("font_color", Color(1.0, 0.58, 0.52) if not join_reqs.is_empty() else Color(0.85, 0.82, 0.72))
		r_vb.add_child(r_title)

		if join_reqs.is_empty():
			var no_req := Label.new()
			no_req.text = "Şu anda bekleyen katılma isteği yok."
			no_req.add_theme_font_size_override("font_size", 20)
			no_req.add_theme_color_override("font_color", Color(0.70, 0.68, 0.62))
			r_vb.add_child(no_req)
		else:
			var full_state: Dictionary = gs.to_dict()
			for jr_raw in join_reqs:
				if typeof(jr_raw) != TYPE_DICTIONARY:
					continue
				var jr := jr_raw as Dictionary
				var app_name := str(jr.get("player_name", "")).strip_edges()
				if app_name.is_empty():
					continue
				var app_pts := AllianceModelScript._calculate_player_points(full_state, app_name)

				var jr_row := HBoxContainer.new()
				jr_row.name = "JoinRequestRow_" + app_name
				jr_row.add_theme_constant_override("separation", 8)
				r_vb.add_child(jr_row)

				var prof_btn := Button.new()
				prof_btn.name = "BtnApplicantProfile_" + app_name
				prof_btn.text = "👤 %s  (%d Puan)" % [app_name, app_pts]
				prof_btn.size_flags_horizontal = SIZE_EXPAND_FILL
				prof_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
				prof_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				prof_btn.add_theme_font_override("font", FontNunitoBold)
				prof_btn.add_theme_font_size_override("font_size", 21)
				var p_sb := StyleBoxFlat.new()
				p_sb.bg_color = Color(0.14, 0.16, 0.24, 0.92)
				p_sb.border_color = Color(0.45, 0.74, 0.98, 0.78)
				p_sb.set_border_width_all(1)
				p_sb.set_corner_radius_all(10)
				p_sb.content_margin_left = 12
				p_sb.content_margin_right = 10
				p_sb.content_margin_top = 8
				p_sb.content_margin_bottom = 8
				prof_btn.add_theme_stylebox_override("normal", p_sb)
				prof_btn.add_theme_stylebox_override("hover", p_sb)
				prof_btn.add_theme_color_override("font_color", Color(0.82, 0.94, 1.0))
				prof_btn.pressed.connect(func():
					_open_player_profile_modal(gs, app_name, a_id_cur, true)
				)
				jr_row.add_child(prof_btn)

				var ok_btn := Button.new()
				ok_btn.name = "BtnApproveJoin_" + app_name
				ok_btn.text = "✅ Onayla"
				ok_btn.custom_minimum_size = Vector2(126, 46)
				ok_btn.add_theme_font_override("font", FontNunitoBold)
				ok_btn.add_theme_font_size_override("font_size", 19)
				_style_gold_btn(ok_btn)
				ok_btn.pressed.connect(func():
					var st_j: Dictionary = gs.to_dict()
					var r_ok := AllianceModelScript.respond_join_request(st_j, a_id_cur, player_name, app_name, true)
					if bool(r_ok.get("ok", false)):
						_suppress_state_refresh = true
						gs.from_dict(st_j)
						_save_game(true)
						_suppress_state_refresh = false
						refresh_view()
				)
				jr_row.add_child(ok_btn)

				var rej_btn := Button.new()
				rej_btn.name = "BtnRejectJoin_" + app_name
				rej_btn.text = "❌ Reddet"
				rej_btn.custom_minimum_size = Vector2(118, 46)
				rej_btn.add_theme_font_override("font", FontNunitoBold)
				rej_btn.add_theme_font_size_override("font_size", 19)
				_style_danger_btn(rej_btn)
				rej_btn.pressed.connect(func():
					var st_j: Dictionary = gs.to_dict()
					var r_no := AllianceModelScript.respond_join_request(st_j, a_id_cur, player_name, app_name, false)
					if bool(r_no.get("ok", false)):
						_suppress_state_refresh = true
						gs.from_dict(st_j)
						_save_game(true)
						_suppress_state_refresh = false
						refresh_view()
				)
				jr_row.add_child(rej_btn)

	var card := _make_card()
	vbox.add_child(card)

	var c_vbox := VBoxContainer.new()
	c_vbox.add_theme_constant_override("separation", 12)
	card.add_child(c_vbox)

	var title := Label.new()
	title.text = "Yeni Oyuncu Davet Et"
	title.add_theme_font_override("font", FontNunitoBold)
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

func _apply_diplo_action(gs: Node, res: Dictionary) -> void:
	_diplo_status_ok = bool(res.get("ok", false))
	_diplo_status_msg = str(res.get("message", "İşlem tamamlandı." if _diplo_status_ok else "İşlem başarısız."))
	if _diplo_status_ok:
		var st: Dictionary = gs.to_dict()
		_suppress_state_refresh = true
		gs.from_dict(st)
		_save_game(true)
		_suppress_state_refresh = false
	refresh_view()


func _build_diplomacy_tab(parent: Control, gs: Node, alliance: Dictionary, player_name: String) -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 12
	parent.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 14)
	scroll.add_child(vbox)

	var a_id := int(alliance.get("id", -1))
	var state: Dictionary = gs.to_dict()
	var diplo: Dictionary = alliance.get("diplomacy", {}) if typeof(alliance.get("diplomacy")) == TYPE_DICTIONARY else {}
	var allies: Array = diplo.get("allies", []) if typeof(diplo.get("allies")) == TYPE_ARRAY else []
	var enemies: Array = diplo.get("enemies", []) if typeof(diplo.get("enemies")) == TYPE_ARRAY else []
	var req_in: Array = diplo.get("ally_requests_in", []) if typeof(diplo.get("ally_requests_in")) == TYPE_ARRAY else []
	var req_out: Array = diplo.get("ally_requests_out", []) if typeof(diplo.get("ally_requests_out")) == TYPE_ARRAY else []
	var is_founder_user := AllianceModelScript.is_founder(alliance, player_name)

	if not _diplo_status_msg.is_empty():
		var st_lbl := Label.new()
		st_lbl.name = "DiplomacyStatusLabel"
		st_lbl.text = _diplo_status_msg
		st_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		st_lbl.add_theme_font_override("font", FontNunitoBold)
		st_lbl.add_theme_font_size_override("font_size", 21)
		st_lbl.add_theme_color_override("font_color", Color(0.45, 0.95, 0.58) if _diplo_status_ok else Color(1.0, 0.42, 0.42))
		vbox.add_child(st_lbl)

	# 1. Mevcut İlişkiler Kartı (Müttefikler & Düşmanlar — NAP kaldırıldı)
	var card := _make_card()
	vbox.add_child(card)
	var c_vbox := VBoxContainer.new()
	c_vbox.add_theme_constant_override("separation", 10)
	card.add_child(c_vbox)

	var t1 := Label.new()
	t1.text = "⚖️ Diplomasi İlişkileri"
	t1.add_theme_font_override("font", FontNunitoBold)
	t1.add_theme_font_size_override("font_size", 24)
	t1.add_theme_color_override("font_color", Color(1.0, 0.90, 0.45))
	c_vbox.add_child(t1)

	var ally_hdr := Label.new()
	ally_hdr.text = "🤝 Müttefikler (%d):" % allies.size()
	ally_hdr.add_theme_font_override("font", FontNunitoBold)
	ally_hdr.add_theme_font_size_override("font_size", 21)
	ally_hdr.add_theme_color_override("font_color", Color(0.45, 0.92, 0.55))
	c_vbox.add_child(ally_hdr)

	if allies.is_empty():
		var no_ally := Label.new()
		no_ally.text = "  • Henüz müttefik ittifak yok."
		no_ally.add_theme_font_override("font", FontNunitoRegular)
		no_ally.add_theme_font_size_override("font_size", 20)
		no_ally.add_theme_color_override("font_color", Color(0.72, 0.70, 0.65))
		c_vbox.add_child(no_ally)
	else:
		for a_tag_raw in allies:
			var a_tag := str(a_tag_raw).strip_edges().to_upper()
			var tgt_a := AllianceModelScript.find_by_tag(state, a_tag)
			var disp := ("[%s] %s" % [a_tag, str(tgt_a.get("name", ""))]) if not tgt_a.is_empty() else ("[%s]" % a_tag)
			var r_hb := HBoxContainer.new()
			r_hb.add_theme_constant_override("separation", 10)
			c_vbox.add_child(r_hb)
			var rl := Label.new()
			rl.size_flags_horizontal = SIZE_EXPAND_FILL
			rl.text = "🤝 " + disp
			rl.add_theme_font_override("font", FontNunitoBold)
			rl.add_theme_font_size_override("font_size", 21)
			rl.add_theme_color_override("font_color", Color(0.95, 0.94, 0.88))
			r_hb.add_child(rl)
			if is_founder_user:
				var rem_btn := Button.new()
				rem_btn.text = "💔 Sonlandır"
				rem_btn.custom_minimum_size = Vector2(138, 40)
				rem_btn.add_theme_font_override("font", FontNunitoBold)
				rem_btn.add_theme_font_size_override("font_size", 18)
				_style_danger_btn(rem_btn)
				rem_btn.pressed.connect(func():
					var st2: Dictionary = gs.to_dict()
					var r2 := AllianceModelScript.remove_ally(st2, a_id, player_name, a_tag)
					if bool(r2.get("ok", false)):
						_suppress_state_refresh = true
						gs.from_dict(st2)
						_save_game(true)
						_suppress_state_refresh = false
					_diplo_status_ok = bool(r2.get("ok", false))
					_diplo_status_msg = "Müttefiklik sonlandırıldı: [%s]" % a_tag
					refresh_view()
				)
				r_hb.add_child(rem_btn)

	var enemy_hdr := Label.new()
	enemy_hdr.text = "⚔️ Düşman İttifaklar (%d):" % enemies.size()
	enemy_hdr.add_theme_font_override("font", FontNunitoBold)
	enemy_hdr.add_theme_font_size_override("font_size", 21)
	enemy_hdr.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	c_vbox.add_child(enemy_hdr)

	if enemies.is_empty():
		var no_en := Label.new()
		no_en.text = "  • Henüz düşman ilan edilmiş ittifak yok."
		no_en.add_theme_font_override("font", FontNunitoRegular)
		no_en.add_theme_font_size_override("font_size", 20)
		no_en.add_theme_color_override("font_color", Color(0.72, 0.70, 0.65))
		c_vbox.add_child(no_en)
	else:
		for e_tag_raw in enemies:
			var e_tag := str(e_tag_raw).strip_edges().to_upper()
			var tgt_e := AllianceModelScript.find_by_tag(state, e_tag)
			var disp_e := ("[%s] %s" % [e_tag, str(tgt_e.get("name", ""))]) if not tgt_e.is_empty() else ("[%s]" % e_tag)
			var e_hb := HBoxContainer.new()
			e_hb.add_theme_constant_override("separation", 10)
			c_vbox.add_child(e_hb)
			var el := Label.new()
			el.size_flags_horizontal = SIZE_EXPAND_FILL
			el.text = "⚔️ " + disp_e
			el.add_theme_font_override("font", FontNunitoBold)
			el.add_theme_font_size_override("font_size", 21)
			el.add_theme_color_override("font_color", Color(1.0, 0.76, 0.72))
			e_hb.add_child(el)
			if is_founder_user:
				var clr_btn := Button.new()
				clr_btn.text = "🏳️ Kaldır"
				clr_btn.custom_minimum_size = Vector2(120, 40)
				clr_btn.add_theme_font_override("font", FontNunitoBold)
				clr_btn.add_theme_font_size_override("font_size", 18)
				_style_gold_btn(clr_btn)
				clr_btn.pressed.connect(func():
					var st2: Dictionary = gs.to_dict()
					var r2 := AllianceModelScript.remove_enemy(st2, a_id, player_name, e_tag)
					if bool(r2.get("ok", false)):
						_suppress_state_refresh = true
						gs.from_dict(st2)
						_save_game(true)
						_suppress_state_refresh = false
					_diplo_status_ok = bool(r2.get("ok", false))
					_diplo_status_msg = "Düşmanlık kaldırıldı: [%s]" % e_tag
					refresh_view()
				)
				e_hb.add_child(clr_btn)

	if not is_founder_user:
		var lock_lbl := Label.new()
		lock_lbl.name = "DiplomacyFounderOnlyNotice"
		lock_lbl.text = "ℹ️ Diplomasi yönetimini yalnızca İttifak Kurucu Lideri yapabilir."
		lock_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lock_lbl.add_theme_font_override("font", FontNunitoRegular)
		lock_lbl.add_theme_font_size_override("font_size", 20)
		lock_lbl.add_theme_color_override("font_color", Color(0.82, 0.80, 0.72))
		vbox.add_child(lock_lbl)
		return

	# 2. Gelen Müttefiklik Davetleri (Kurucu Lider Kabul/Red)
	if not req_in.is_empty():
		var in_card := _make_card()
		in_card.name = "IncomingAllyRequestsCard"
		vbox.add_child(in_card)
		var in_vb := VBoxContainer.new()
		in_vb.add_theme_constant_override("separation", 10)
		in_card.add_child(in_vb)
		var in_t := Label.new()
		in_t.text = "📨 Gelen Müttefiklik Davetleri (%d)" % req_in.size()
		in_t.add_theme_font_override("font", FontNunitoBold)
		in_t.add_theme_font_size_override("font_size", 22)
		in_t.add_theme_color_override("font_color", Color(0.52, 0.92, 1.0))
		in_vb.add_child(in_t)

		for rq_raw in req_in:
			if typeof(rq_raw) != TYPE_DICTIONARY:
				continue
			var rq := rq_raw as Dictionary
			var fid := int(rq.get("alliance_id", -1))
			var ftag := str(rq.get("tag", ""))
			var fname := str(rq.get("name", ftag))
			var rhb := HBoxContainer.new()
			rhb.add_theme_constant_override("separation", 8)
			in_vb.add_child(rhb)
			var rlbl := Label.new()
			rlbl.size_flags_horizontal = SIZE_EXPAND_FILL
			rlbl.text = "[%s] %s" % [ftag, fname]
			rlbl.add_theme_font_override("font", FontNunitoBold)
			rlbl.add_theme_font_size_override("font_size", 21)
			rlbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.90))
			rhb.add_child(rlbl)

			var acc_btn := Button.new()
			acc_btn.name = "AcceptAllyInviteBtn_%d" % fid
			acc_btn.text = "✅ Kabul Et"
			acc_btn.custom_minimum_size = Vector2(126, 42)
			acc_btn.add_theme_font_override("font", FontNunitoBold)
			acc_btn.add_theme_font_size_override("font_size", 18)
			_style_gold_btn(acc_btn)
			acc_btn.pressed.connect(func():
				var st_a: Dictionary = gs.to_dict()
				var r_acc := AllianceModelScript.respond_ally_invite(st_a, a_id, player_name, fid, true)
				if bool(r_acc.get("ok", false)):
					_suppress_state_refresh = true
					gs.from_dict(st_a)
					_save_game(true)
					_suppress_state_refresh = false
				_diplo_status_ok = bool(r_acc.get("ok", false))
				_diplo_status_msg = str(r_acc.get("message", ""))
				refresh_view()
			)
			rhb.add_child(acc_btn)

			var rej_btn := Button.new()
			rej_btn.text = "❌ Reddet"
			rej_btn.custom_minimum_size = Vector2(110, 42)
			rej_btn.add_theme_font_override("font", FontNunitoBold)
			rej_btn.add_theme_font_size_override("font_size", 18)
			_style_danger_btn(rej_btn)
			rej_btn.pressed.connect(func():
				var st_a: Dictionary = gs.to_dict()
				var r_rej := AllianceModelScript.respond_ally_invite(st_a, a_id, player_name, fid, false)
				if bool(r_rej.get("ok", false)):
					_suppress_state_refresh = true
					gs.from_dict(st_a)
					_save_game(true)
					_suppress_state_refresh = false
				_diplo_status_ok = bool(r_rej.get("ok", false))
				_diplo_status_msg = str(r_rej.get("message", ""))
				refresh_view()
			)
			rhb.add_child(rej_btn)

	# 3. Gönderilen Müttefiklik Davetleri
	if not req_out.is_empty():
		var out_card := _make_card()
		vbox.add_child(out_card)
		var out_vb := VBoxContainer.new()
		out_vb.add_theme_constant_override("separation", 8)
		out_card.add_child(out_vb)
		var out_t := Label.new()
		out_t.text = "⏳ Bekleyen Müttefiklik Davetleriniz (%d)" % req_out.size()
		out_t.add_theme_font_override("font", FontNunitoBold)
		out_t.add_theme_font_size_override("font_size", 21)
		out_t.add_theme_color_override("font_color", Color(0.98, 0.85, 0.45))
		out_vb.add_child(out_t)
		for oq_raw in req_out:
			if typeof(oq_raw) != TYPE_DICTIONARY:
				continue
			var oq := oq_raw as Dictionary
			var tid := int(oq.get("alliance_id", -1))
			var ohb := HBoxContainer.new()
			ohb.add_theme_constant_override("separation", 8)
			out_vb.add_child(ohb)
			var olbl := Label.new()
			olbl.size_flags_horizontal = SIZE_EXPAND_FILL
			olbl.text = "[%s] %s (Yanıt bekleniyor)" % [str(oq.get("tag", "")), str(oq.get("name", ""))]
			olbl.add_theme_font_override("font", FontNunitoRegular)
			olbl.add_theme_font_size_override("font_size", 20)
			olbl.add_theme_color_override("font_color", Color(0.88, 0.86, 0.78))
			ohb.add_child(olbl)
			var can_btn := Button.new()
			can_btn.text = "İptal"
			can_btn.custom_minimum_size = Vector2(96, 38)
			_style_danger_btn(can_btn)
			can_btn.pressed.connect(func():
				var st_a: Dictionary = gs.to_dict()
				var r_c := AllianceModelScript.cancel_ally_invite(st_a, a_id, player_name, tid)
				if bool(r_c.get("ok", false)):
					_suppress_state_refresh = true
					gs.from_dict(st_a)
					_save_game(true)
					_suppress_state_refresh = false
				_diplo_status_ok = true
				_diplo_status_msg = "Müttefiklik daveti iptal edildi."
				refresh_view()
			)
			ohb.add_child(can_btn)

	# 4. İttifak Ara ve Müttefik Daveti / Düşman İlan Et
	var search_card := _make_card()
	search_card.name = "DiplomacySearchCard"
	vbox.add_child(search_card)
	var sc_vb := VBoxContainer.new()
	sc_vb.add_theme_constant_override("separation", 12)
	search_card.add_child(sc_vb)

	var sc_title := Label.new()
	sc_title.text = "🔍 İttifak Ara & Diplomasi Başlat"
	sc_title.add_theme_font_override("font", FontNunitoBold)
	sc_title.add_theme_font_size_override("font_size", 23)
	sc_title.add_theme_color_override("font_color", Color(1.0, 0.90, 0.45))
	sc_vb.add_child(sc_title)

	var gc_d: Node = Engine.get_main_loop().root.get_node_or_null("GameConfig") if Engine.get_main_loop() is SceneTree else null
	var search_in := LineEdit.new()
	search_in.name = "DiplomacySearchInput"
	search_in.placeholder_text = "İttifak adı veya etiketi ara..."
	search_in.text = _draft_diplo_search
	search_in.custom_minimum_size = Vector2(0, 50)
	search_in.add_theme_font_override("font", FontNunitoRegular)
	search_in.add_theme_font_size_override("font_size", 22)
	_style_input(search_in)
	if gc_d != null and gc_d.has_method("bind_keyboard_dismiss"):
		gc_d.call("bind_keyboard_dismiss", search_in)
	_diplo_search_input = search_in
	sc_vb.add_child(search_in)

	var results_vb := VBoxContainer.new()
	results_vb.name = "DiplomacySearchResults"
	results_vb.add_theme_constant_override("separation", 10)
	sc_vb.add_child(results_vb)

	var populate_results := func(q_txt: String) -> void:
		for ch in results_vb.get_children():
			results_vb.remove_child(ch)
			ch.queue_free()
		var cur_st: Dictionary = gs.to_dict()
		var matches := AllianceModelScript.search_alliances(cur_st, a_id, q_txt)
		if matches.is_empty():
			var empty_r := Label.new()
			empty_r.text = "Eşleşen başka ittifak bulunamadı."
			empty_r.add_theme_font_override("font", FontNunitoRegular)
			empty_r.add_theme_font_size_override("font_size", 20)
			empty_r.add_theme_color_override("font_color", Color(0.68, 0.65, 0.60))
			results_vb.add_child(empty_r)
			return
		for other_a in matches:
			var oa := other_a as Dictionary
			var o_id := int(oa.get("id", -1))
			var o_tag := str(oa.get("tag", "")).strip_edges().to_upper()
			var o_name := str(oa.get("name", ""))
			var o_mems: int = (oa.get("members", []) as Array).size()
			var row_vb := HBoxContainer.new()
			row_vb.name = "DiplomacyTargetRow_%d" % o_id
			row_vb.add_theme_constant_override("separation", 8)
			results_vb.add_child(row_vb)

			var o_lbl := Label.new()
			o_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
			o_lbl.text = "[%s] %s (%d üye)" % [o_tag, o_name, o_mems]
			o_lbl.add_theme_font_override("font", FontNunitoBold)
			o_lbl.add_theme_font_size_override("font_size", 21)
			o_lbl.add_theme_color_override("font_color", Color(0.95, 0.93, 0.86))
			row_vb.add_child(o_lbl)

			var already_ally := AllianceModelScript._has_tag(allies, o_tag)
			var already_enemy := AllianceModelScript._has_tag(enemies, o_tag)
			var pending_out := AllianceModelScript._find_req_by_aid(req_out, o_id, o_tag) >= 0

			if not already_ally:
				var inv_btn := Button.new()
				inv_btn.name = "SendAllyInviteBtn_%d" % o_id
				inv_btn.text = "⏳ Bekliyor" if pending_out else "🤝 Müttefik Daveti"
				inv_btn.disabled = pending_out
				inv_btn.custom_minimum_size = Vector2(180, 44)
				inv_btn.add_theme_font_override("font", FontNunitoBold)
				inv_btn.add_theme_font_size_override("font_size", 18)
				_style_gold_btn(inv_btn)
				inv_btn.pressed.connect(func():
					if gc_d != null and gc_d.has_method("dismiss_keyboard_for"):
						gc_d.call("dismiss_keyboard_for", null)
					var st_a: Dictionary = gs.to_dict()
					var res_i := AllianceModelScript.send_ally_invite(st_a, a_id, player_name, o_id)
					if bool(res_i.get("ok", false)):
						_suppress_state_refresh = true
						gs.from_dict(st_a)
						_save_game(true)
						_suppress_state_refresh = false
					_diplo_status_ok = bool(res_i.get("ok", false))
					_diplo_status_msg = str(res_i.get("message", ""))
					refresh_view()
				)
				row_vb.add_child(inv_btn)

			if not already_enemy:
				var en_btn := Button.new()
				en_btn.name = "DeclareEnemyBtn_%d" % o_id
				en_btn.text = "⚔️ Düşman İlan Et"
				en_btn.custom_minimum_size = Vector2(170, 44)
				en_btn.add_theme_font_override("font", FontNunitoBold)
				en_btn.add_theme_font_size_override("font_size", 18)
				_style_danger_btn(en_btn)
				en_btn.pressed.connect(func():
					if gc_d != null and gc_d.has_method("dismiss_keyboard_for"):
						gc_d.call("dismiss_keyboard_for", null)
					var st_a: Dictionary = gs.to_dict()
					var res_e := AllianceModelScript.declare_enemy(st_a, a_id, player_name, o_id)
					if bool(res_e.get("ok", false)):
						_suppress_state_refresh = true
						gs.from_dict(st_a)
						_save_game(true)
						_suppress_state_refresh = false
					_diplo_status_ok = bool(res_e.get("ok", false))
					_diplo_status_msg = str(res_e.get("message", ""))
					refresh_view()
				)
				row_vb.add_child(en_btn)

	populate_results.call(_draft_diplo_search)
	search_in.text_changed.connect(func(new_q: String):
		_draft_diplo_search = new_q
		populate_results.call(new_q)
	)


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


func _open_player_profile_modal(gs: Node, target_name: String, pending_alliance_id: int = -1, show_req_actions: bool = false) -> void:
	if gs == null:
		return
	var state: Dictionary = gs.to_dict()
	var target_l := target_name.strip_edges().to_lower()
	var total_pts := 0
	var target_villages: Array[Dictionary] = []
	for v_raw in state.get("villages", []):
		if typeof(v_raw) != TYPE_DICTIONARY:
			continue
		var vd := v_raw as Dictionary
		if str(vd.get("owner", "")).strip_edges().to_lower() == target_l:
			target_villages.append(vd)
			total_pts += int(vd.get("points", 0))
	if total_pts == 0:
		total_pts = AllianceModelScript._calculate_player_points(state, target_name)

	var player_ally := AllianceModelScript.get_player_alliance(state, target_name)
	var ally_label := ("[%s] %s" % [str(player_ally.get("tag", "")), str(player_ally.get("name", ""))]) if not player_ally.is_empty() else "İttifaksız"

	var existing := get_node_or_null("AlliancePlayerProfileModal")
	if existing != null:
		remove_child(existing)
		existing.queue_free()

	var layer := CanvasLayer.new()
	layer.name = "AlliancePlayerProfileModal"
	layer.layer = 160
	add_child(layer)

	var root_ctrl := Control.new()
	root_ctrl.set_anchors_preset(PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(root_ctrl)

	var dim := ColorRect.new()
	dim.set_anchors_preset(PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.02, 0.04, 0.80)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root_ctrl.add_child(dim)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(PRESET_FULL_RECT)
	root_ctrl.add_child(cc)

	var card := PanelContainer.new()
	card.name = "PlayerProfileCard"
	card.custom_minimum_size = Vector2(760, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.09, 0.14, 0.99)
	sb.border_color = Color(0.92, 0.76, 0.36, 1.0)
	sb.set_border_width_all(3)
	sb.border_width_top = 5
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(22)
	card.add_theme_stylebox_override("panel", sb)
	cc.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	card.add_child(vb)

	var hdr := HBoxContainer.new()
	vb.add_child(hdr)
	var title := Label.new()
	title.text = "👤 OYUNCU PROFİLİ: %s" % target_name
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	title.add_theme_font_override("font", FontNunitoBold)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.90, 0.45))
	hdr.add_child(title)

	var cls := Button.new()
	cls.name = "BtnCloseProfileModal"
	cls.text = "×"
	cls.custom_minimum_size = Vector2(46, 42)
	cls.add_theme_font_override("font", FontNunitoBold)
	cls.add_theme_font_size_override("font_size", 26)
	_style_danger_btn(cls)
	cls.pressed.connect(func(): layer.queue_free())
	hdr.add_child(cls)

	var summary := Label.new()
	summary.text = "🛡️ İttifak: %s   |   🏆 Toplam Puan: %d   |   🏰 Köy Sayısı: %d" % [ally_label, total_pts, target_villages.size()]
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_theme_font_override("font", FontNunitoBold)
	summary.add_theme_font_size_override("font_size", 22)
	summary.add_theme_color_override("font_color", Color(0.94, 0.92, 0.84))
	vb.add_child(summary)

	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 220)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(sc)

	var v_list := VBoxContainer.new()
	v_list.size_flags_horizontal = SIZE_EXPAND_FILL
	v_list.add_theme_constant_override("separation", 8)
	sc.add_child(v_list)

	if target_villages.is_empty():
		var none_lbl := Label.new()
		none_lbl.text = "Bu oyuncuya ait aktif köy bilgisi bulunamadı."
		none_lbl.add_theme_font_size_override("font_size", 20)
		none_lbl.add_theme_color_override("font_color", Color(0.72, 0.70, 0.64))
		v_list.add_child(none_lbl)
	else:
		for tv in target_villages:
			var row_c := _make_card()
			v_list.add_child(row_c)
			var rl := Label.new()
			rl.text = "🏰 %s   (%d|%d)   •   %d Puan" % [
				str(tv.get("name", "Köy")),
				int(tv.get("x", 0)),
				int(tv.get("y", 0)),
				int(tv.get("points", 0))
			]
			rl.add_theme_font_override("font", FontNunitoBold)
			rl.add_theme_font_size_override("font_size", 21)
			rl.add_theme_color_override("font_color", Color(0.95, 0.94, 0.88))
			row_c.add_child(rl)

	if show_req_actions and pending_alliance_id > 0:
		var actor := str(gs.player.get("name", ""))
		var act_hb := HBoxContainer.new()
		act_hb.add_theme_constant_override("separation", 12)
		vb.add_child(act_hb)

		var acc_p := Button.new()
		acc_p.name = "BtnProfileApproveJoin"
		acc_p.text = "✅ İttifaka Onayla"
		acc_p.size_flags_horizontal = SIZE_EXPAND_FILL
		acc_p.custom_minimum_size = Vector2(0, 50)
		acc_p.add_theme_font_override("font", FontNunitoBold)
		acc_p.add_theme_font_size_override("font_size", 22)
		_style_gold_btn(acc_p)
		acc_p.pressed.connect(func():
			var st_p: Dictionary = gs.to_dict()
			var res_p := AllianceModelScript.respond_join_request(st_p, pending_alliance_id, actor, target_name, true)
			layer.queue_free()
			if bool(res_p.get("ok", false)):
				_suppress_state_refresh = true
				gs.from_dict(st_p)
				_save_game(true)
				_suppress_state_refresh = false
				refresh_view()
		)
		act_hb.add_child(acc_p)

		var rej_p := Button.new()
		rej_p.name = "BtnProfileRejectJoin"
		rej_p.text = "❌ Reddet"
		rej_p.size_flags_horizontal = SIZE_EXPAND_FILL
		rej_p.custom_minimum_size = Vector2(0, 50)
		rej_p.add_theme_font_override("font", FontNunitoBold)
		rej_p.add_theme_font_size_override("font_size", 22)
		_style_danger_btn(rej_p)
		rej_p.pressed.connect(func():
			var st_p: Dictionary = gs.to_dict()
			var res_r := AllianceModelScript.respond_join_request(st_p, pending_alliance_id, actor, target_name, false)
			layer.queue_free()
			if bool(res_r.get("ok", false)):
				_suppress_state_refresh = true
				gs.from_dict(st_p)
				_save_game(true)
				_suppress_state_refresh = false
				refresh_view()
		)
		act_hb.add_child(rej_p)


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
