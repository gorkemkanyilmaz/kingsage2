extends Control
## Ranking — Oyuncu ve İttifak Gücü Sıralaması (Taht ve Kılıç / Royal Dark-Gold Tema).

const AllianceModelScript := preload("res://scripts/model/AllianceModel.gd")

const FontCinzelBold = preload("res://assets/fonts/Cinzel-Bold.ttf")
const FontNunitoBold = preload("res://assets/fonts/Nunito-Bold.ttf")
const IconAllianceShield = preload("res://assets/sprites/ui/nano_banana/sharp_icon_alliance_shield.tres")
const TexRoyalBtnBg = preload("res://assets/sprites/ui/nano_banana/sharp_ui_royal_btn_bg.tres")

const ROW_H := 92.0
const MEDAL_COLORS := [
	Color(0.95, 0.76, 0.24), # 1. Altın
	Color(0.78, 0.82, 0.88), # 2. Gümüş
	Color(0.80, 0.50, 0.25), # 3. Bronz
]

@onready var ranking_scroll: ScrollContainer = $Container/Scroll
@onready var ranking_list: VBoxContainer = $Container/Scroll/List
@onready var btn_alliance: Button = $Header/HBox/BtnAlliance if has_node("Header/HBox/BtnAlliance") else null
@onready var btn_tab_players: Button = $Tabs/BtnTabPlayers if has_node("Tabs/BtnTabPlayers") else null
@onready var btn_tab_alliances: Button = $Tabs/BtnTabAlliances if has_node("Tabs/BtnTabAlliances") else null
@onready var summary_banner: PanelContainer = $SummaryBanner if has_node("SummaryBanner") else null

var _current_tab: String = "players" # "players" | "alliances"
var _summary_label: Label = null
var _last_rank_sig: String = ""


func _ready() -> void:
	if ranking_scroll != null:
		ranking_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		ranking_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		ranking_scroll.scroll_deadzone = 12
		ranking_scroll.follow_focus = false
	if ranking_list != null:
		ranking_list.mouse_filter = Control.MOUSE_FILTER_PASS
	_sync_top_bar_layout()
	if not resized.is_connected(_sync_top_bar_layout):
		resized.connect(_sync_top_bar_layout)
	var rbar := get_node_or_null("ResourceBar") as Control
	if rbar != null and not rbar.resized.is_connected(_sync_top_bar_layout):
		rbar.resized.connect(_sync_top_bar_layout)
	_setup_summary_banner()
	_style_header_alliance_btn()

	if btn_tab_players != null:
		btn_tab_players.pressed.connect(func(): _switch_tab("players"))
	if btn_tab_alliances != null:
		btn_tab_alliances.pressed.connect(func(): _switch_tab("alliances"))

	var bus = Engine.get_main_loop().root.get_node_or_null("EventBus") if Engine.get_main_loop() is SceneTree else null
	if bus != null and bus.has_signal("state_changed") and not bus.state_changed.is_connected(_populate_rankings):
		bus.state_changed.connect(_populate_rankings)

	_update_tab_styles()
	_populate_rankings(true)


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
		header.offset_bottom = bar_h + 102.0
	var tabs := get_node_or_null("Tabs") as Control
	if tabs != null:
		tabs.offset_top = bar_h + 114.0
		tabs.offset_bottom = bar_h + 180.0
	if summary_banner != null:
		summary_banner.offset_top = bar_h + 192.0
		summary_banner.offset_bottom = bar_h + 262.0
	var cont := get_node_or_null("Container") as Control
	if cont != null:
		cont.offset_top = bar_h + 274.0


func _style_header_alliance_btn() -> void:
	if btn_alliance == null:
		return
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.10, 0.16, 0.27, 0.95)
	st.border_color = Color(0.86, 0.70, 0.34, 0.88)
	st.set_border_width_all(2)
	st.set_corner_radius_all(12)
	st.content_margin_left = 12
	st.content_margin_right = 14
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	btn_alliance.add_theme_stylebox_override("normal", st)
	var h_st := st.duplicate() as StyleBoxFlat
	h_st.bg_color = Color(0.15, 0.24, 0.39, 0.98)
	h_st.border_color = Color(0.98, 0.84, 0.44, 1.0)
	btn_alliance.add_theme_stylebox_override("hover", h_st)
	btn_alliance.add_theme_stylebox_override("pressed", h_st)
	btn_alliance.icon = IconAllianceShield
	btn_alliance.expand_icon = true
	btn_alliance.add_theme_constant_override("icon_max_width", 28)
	btn_alliance.add_theme_font_override("font", FontCinzelBold)
	btn_alliance.add_theme_font_size_override("font_size", 22)
	btn_alliance.add_theme_color_override("font_color", Color(0.98, 0.93, 0.72))
	if not btn_alliance.pressed.is_connected(_on_header_alliance_pressed):
		btn_alliance.pressed.connect(_on_header_alliance_pressed)


func _on_header_alliance_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Alliance.tscn")


func _setup_summary_banner() -> void:
	if summary_banner == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.11, 0.16, 0.96)
	sb.border_color = Color(0.85, 0.70, 0.34, 0.90)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	summary_banner.add_theme_stylebox_override("panel", sb)

	_summary_label = Label.new()
	_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary_label.add_theme_font_override("font", FontNunitoBold)
	_summary_label.add_theme_font_size_override("font_size", 23)
	_summary_label.add_theme_color_override("font_color", Color(1.0, 0.93, 0.74))
	summary_banner.add_child(_summary_label)


func _switch_tab(tab_name: String) -> void:
	_current_tab = tab_name
	_update_tab_styles()
	_populate_rankings(true)
	if ranking_scroll != null:
		ranking_scroll.scroll_vertical = 0


func _update_tab_styles() -> void:
	_apply_tab_btn_style(btn_tab_players, _current_tab == "players")
	_apply_tab_btn_style(btn_tab_alliances, _current_tab == "alliances")


func _apply_tab_btn_style(btn: Button, is_active: bool) -> void:
	if btn == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.32, 0.22, 0.10, 0.98) if is_active else Color(0.11, 0.10, 0.14, 0.94)
	sb.border_color = Color(0.95, 0.78, 0.32, 1.0) if is_active else Color(0.45, 0.39, 0.28, 0.65)
	sb.set_border_width_all(3 if is_active else 2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	btn.add_theme_stylebox_override("normal", sb)
	var hov := sb.duplicate() as StyleBoxFlat
	hov.bg_color = sb.bg_color.lightened(0.10)
	btn.add_theme_stylebox_override("hover", hov)
	btn.add_theme_stylebox_override("pressed", hov)
	btn.add_theme_font_override("font", FontNunitoBold)
	btn.add_theme_color_override("font_color", Color(1.0, 0.94, 0.72) if is_active else Color(0.75, 0.72, 0.68))


## Tüm köyleri sahiplerine göre toplayarak her oyuncunun toplam gücünü döndürür.
static func compute_player_rankings(state: Dictionary) -> Array[Dictionary]:
	var villages: Array = state.get("villages", []) if typeof(state.get("villages")) == TYPE_ARRAY else []
	var player_alliance_tag: Dictionary = {}
	for a in state.get("alliances", []):
		if typeof(a) != TYPE_DICTIONARY:
			continue
		var tag := str((a as Dictionary).get("tag", ""))
		for m in (a as Dictionary).get("members", []):
			if typeof(m) == TYPE_DICTIONARY:
				var m_name := str((m as Dictionary).get("name", "")).strip_edges().to_lower()
				if not m_name.is_empty():
					player_alliance_tag[m_name] = tag

	var by_owner: Dictionary = {}
	for v_raw in villages:
		if typeof(v_raw) != TYPE_DICTIONARY:
			continue
		var v: Dictionary = v_raw
		var owner := str(v.get("owner", "")).strip_edges()
		if owner.is_empty():
			owner = "Barbar"
		var owner_key := owner.to_lower()
		var pts := int(v.get("points", 0))
		if not by_owner.has(owner_key):
			by_owner[owner_key] = {
				"owner": owner,
				"points": 0,
				"village_count": 0,
				"top_village": v,
				"top_pts": -1,
				"is_bot": bool(v.get("is_bot", false)),
				"alliance_tag": str(player_alliance_tag.get(owner_key, "")),
			}
		var rec: Dictionary = by_owner[owner_key]
		rec["points"] = int(rec["points"]) + pts
		rec["village_count"] = int(rec["village_count"]) + 1
		if pts > int(rec["top_pts"]):
			rec["top_pts"] = pts
			rec["top_village"] = v

	var entries: Array[Dictionary] = []
	for k in by_owner.keys():
		entries.append(by_owner[k])
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa := int(a.get("points", 0))
		var pb := int(b.get("points", 0))
		if pa != pb:
			return pa > pb
		return int(a.get("village_count", 0)) > int(b.get("village_count", 0))
	)
	return entries


## İttifakları içlerindeki oyuncuların toplam puan gücüne göre azalan sırada döndürür.
static func compute_alliance_rankings(state: Dictionary) -> Array[Dictionary]:
	var p_ranks := compute_player_rankings(state)
	var player_points_map: Dictionary = {}
	var player_villages_map: Dictionary = {}
	for pr in p_ranks:
		var key := str(pr.get("owner", "")).strip_edges().to_lower()
		if not key.is_empty():
			player_points_map[key] = int(pr.get("points", 0))
			player_villages_map[key] = int(pr.get("village_count", 0))

	var alliances: Array = state.get("alliances", []) if typeof(state.get("alliances")) == TYPE_ARRAY else []
	var rows: Array[Dictionary] = []
	for a_raw in alliances:
		if typeof(a_raw) != TYPE_DICTIONARY:
			continue
		var a: Dictionary = a_raw
		var members: Array = a.get("members", []) if typeof(a.get("members")) == TYPE_ARRAY else []
		var total_power := 0
		var total_villages := 0
		for m_raw in members:
			if typeof(m_raw) != TYPE_DICTIONARY:
				continue
			var m_name := str((m_raw as Dictionary).get("name", "")).strip_edges().to_lower()
			total_power += int(player_points_map.get(m_name, 0))
			total_villages += int(player_villages_map.get(m_name, 0))
		rows.append({
			"id": int(a.get("id", 0)),
			"name": str(a.get("name", "İttifak")),
			"tag": str(a.get("tag", "")),
			"leader": str(a.get("leader", "")),
			"member_count": members.size(),
			"village_count": total_villages,
			"total_power": total_power,
		})

	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa := int(a.get("total_power", 0))
		var pb := int(b.get("total_power", 0))
		if pa != pb:
			return pa > pb
		return int(a.get("member_count", 0)) > int(b.get("member_count", 0))
	)
	return rows


func _compute_rank_sig(state: Dictionary, player_name: String) -> String:
	var parts: Array[String] = [_current_tab, player_name]
	if _current_tab == "alliances":
		var rows := compute_alliance_rankings(state)
		parts.append(str(rows.size()))
		for i in range(mini(rows.size(), 200)):
			var a := rows[i]
			parts.append("%d:%d:%d" % [int(a.get("id", 0)), int(a.get("total_power", 0)), int(a.get("member_count", 0))])
	else:
		var entries := compute_player_rankings(state)
		parts.append(str(entries.size()))
		for i in range(mini(entries.size(), 200)):
			var e := entries[i]
			parts.append("%s:%d:%d" % [str(e.get("owner", "")), int(e.get("points", 0)), int(e.get("village_count", 0))])
	return "|".join(parts)


func _populate_rankings(force: bool = false) -> void:
	if ranking_list == null:
		return
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null:
		return

	var state: Dictionary = gs.to_dict()
	var player_name := str(gs.player.get("name", "")).strip_edges()
	var sig := _compute_rank_sig(state, player_name)
	if not force and sig == _last_rank_sig and ranking_list.get_child_count() > 0:
		return
	_last_rank_sig = sig

	var prev_scroll := ranking_scroll.scroll_vertical if ranking_scroll != null else 0
	for child in ranking_list.get_children():
		ranking_list.remove_child(child)
		child.queue_free()

	if _current_tab == "alliances":
		_populate_alliance_tab(state, player_name)
	else:
		_populate_player_tab(state, player_name)

	if ranking_scroll != null and not force and prev_scroll > 0:
		ranking_scroll.set_deferred("scroll_vertical", prev_scroll)


func _populate_player_tab(state: Dictionary, player_name: String) -> void:
	var entries := compute_player_rankings(state)
	var my_rank := -1
	var my_pts := 0
	var my_vills := 0
	var p_low := player_name.to_lower()

	for i in range(entries.size()):
		var entry := entries[i]
		var is_me := (not p_low.is_empty() and str(entry.get("owner", "")).strip_edges().to_lower() == p_low)
		if is_me:
			my_rank = i + 1
			my_pts = int(entry.get("points", 0))
			my_vills = int(entry.get("village_count", 0))
		if i < 200:
			ranking_list.add_child(_make_player_row(i + 1, entry, is_me))

	if _summary_label != null:
		if my_rank > 0:
			_summary_label.text = "👑 %s  •  Sıra: #%d / %d  •  Toplam Güç: %d P  (%d Köy)" % [
				player_name, my_rank, entries.size(), my_pts, my_vills
			]
		else:
			_summary_label.text = "👑 Toplam %d Hükümdar Sıralanıyor" % entries.size()


func _populate_alliance_tab(state: Dictionary, player_name: String) -> void:
	var rows := compute_alliance_rankings(state)
	var my_alliance := AllianceModelScript.get_player_alliance(state, player_name)
	var my_aid := int(my_alliance.get("id", -1)) if not my_alliance.is_empty() else -1
	var my_rank := -1
	var my_power := 0

	for i in range(rows.size()):
		var a_row := rows[i]
		var is_mine := (my_aid > 0 and int(a_row.get("id", -2)) == my_aid)
		if is_mine:
			my_rank = i + 1
			my_power = int(a_row.get("total_power", 0))
		if i < 200:
			ranking_list.add_child(_make_alliance_row(i + 1, a_row, is_mine))

	if rows.is_empty():
		ranking_list.add_child(_make_empty_alliance_card())

	if _summary_label != null:
		if my_rank > 0:
			_summary_label.text = "🛡️ İttifakın [%s]  •  Sıra: #%d / %d  •  Toplam Güç: %d P" % [
				str(my_alliance.get("tag", "")), my_rank, rows.size(), my_power
			]
		elif rows.is_empty():
			_summary_label.text = "🛡️ Dünyada henüz kurulmuş bir ittifak bulunmuyor."
		else:
			_summary_label.text = "🛡️ %d İttifak Güce Göre Sıralanıyor (Üyelerin Toplam Puanı)" % rows.size()


func _build_row_card(rank: int, highlight: bool) -> Dictionary:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, ROW_H)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var sb := StyleBoxFlat.new()
	if highlight:
		sb.bg_color = Color(0.24, 0.19, 0.10, 0.98)
		sb.border_color = Color(0.98, 0.80, 0.32, 1.0)
	else:
		sb.bg_color = Color(0.11, 0.10, 0.14, 0.94) if rank % 2 == 1 else Color(0.14, 0.12, 0.17, 0.94)
		sb.border_color = MEDAL_COLORS[rank - 1] if rank <= 3 else Color(0.45, 0.38, 0.26, 0.55)
	sb.set_border_width_all(3 if (highlight or rank <= 3) else 1)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 14
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 0
	card.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)

	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(64, 64)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bsb := StyleBoxFlat.new()
	if rank <= 3:
		var m_col: Color = MEDAL_COLORS[rank - 1]
		bsb.bg_color = m_col.darkened(0.25)
		bsb.border_color = m_col
	else:
		bsb.bg_color = Color(0.16, 0.15, 0.20, 0.98)
		bsb.border_color = Color(0.55, 0.46, 0.32, 0.75)
	bsb.set_border_width_all(2)
	bsb.set_corner_radius_all(32)
	badge.add_theme_stylebox_override("panel", bsb)

	var badge_lbl := Label.new()
	badge_lbl.text = "%d" % rank
	badge_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_lbl.add_theme_font_override("font", FontCinzelBold)
	badge_lbl.add_theme_font_size_override("font_size", 26)
	badge_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.78) if rank <= 3 else Color(0.82, 0.78, 0.70))
	badge.add_child(badge_lbl)
	row.add_child(badge)

	return {"card": card, "row": row}


func _make_player_row(rank: int, entry: Dictionary, is_player: bool) -> PanelContainer:
	var built := _build_row_card(rank, is_player)
	var card: PanelContainer = built["card"]
	var row: HBoxContainer = built["row"]

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_theme_constant_override("separation", 2)

	var owner := str(entry.get("owner", "Hükümdar"))
	var tag := str(entry.get("alliance_tag", ""))
	var v_top: Dictionary = entry.get("top_village", {})
	var v_count := int(entry.get("village_count", 1))
	var pts := int(entry.get("points", 0))

	var title_lbl := Label.new()
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_lbl.text = ("%s  [%s]" % [owner, tag]) if not tag.is_empty() else owner
	if is_player:
		title_lbl.text += "  ★"
	title_lbl.add_theme_font_override("font", FontCinzelBold)
	title_lbl.add_theme_font_size_override("font_size", 25)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.60) if is_player else Color(0.96, 0.93, 0.86))
	info.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub_lbl.text = "🏰 %s (%d|%d)  •  %d Köy" % [
		str(v_top.get("name", "Köy")),
		int(v_top.get("x", 0)),
		int(v_top.get("y", 0)),
		v_count
	]
	sub_lbl.add_theme_font_override("font", FontNunitoBold)
	sub_lbl.add_theme_font_size_override("font_size", 23)
	sub_lbl.add_theme_color_override("font_color", Color(0.74, 0.70, 0.62))
	info.add_child(sub_lbl)
	row.add_child(info)

	var pts_box := VBoxContainer.new()
	pts_box.alignment = BoxContainer.ALIGNMENT_CENTER
	pts_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pts_lbl := Label.new()
	pts_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pts_lbl.text = "%d P" % pts
	pts_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pts_lbl.add_theme_font_override("font", FontCinzelBold)
	pts_lbl.add_theme_font_size_override("font_size", 27)
	pts_lbl.add_theme_color_override("font_color", MEDAL_COLORS[rank - 1] if rank <= 3 else Color(0.92, 0.84, 0.62))
	pts_box.add_child(pts_lbl)
	if is_player:
		var you := Label.new()
		you.mouse_filter = Control.MOUSE_FILTER_IGNORE
		you.text = "SENİN KRALLIĞIN"
		you.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		you.add_theme_font_override("font", FontNunitoBold)
		you.add_theme_font_size_override("font_size", 20)
		you.add_theme_color_override("font_color", Color(0.55, 0.95, 0.65))
		pts_box.add_child(you)
	row.add_child(pts_box)

	return card


func _make_alliance_row(rank: int, a_row: Dictionary, is_mine: bool) -> PanelContainer:
	var built := _build_row_card(rank, is_mine)
	var card: PanelContainer = built["card"]
	var row: HBoxContainer = built["row"]

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_theme_constant_override("separation", 2)

	var title_lbl := Label.new()
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_lbl.text = "[%s] %s" % [str(a_row.get("tag", "")), str(a_row.get("name", "İttifak"))]
	if is_mine:
		title_lbl.text += "  ★"
	title_lbl.add_theme_font_override("font", FontCinzelBold)
	title_lbl.add_theme_font_size_override("font_size", 25)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.60) if is_mine else Color(0.96, 0.93, 0.86))
	info.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub_lbl.text = "👥 %d Üye  •  🏰 %d Köy  •  Lider: %s" % [
		int(a_row.get("member_count", 0)),
		int(a_row.get("village_count", 0)),
		str(a_row.get("leader", "-"))
	]
	sub_lbl.add_theme_font_override("font", FontNunitoBold)
	sub_lbl.add_theme_font_size_override("font_size", 23)
	sub_lbl.add_theme_color_override("font_color", Color(0.74, 0.70, 0.62))
	info.add_child(sub_lbl)
	row.add_child(info)

	var pts_box := VBoxContainer.new()
	pts_box.alignment = BoxContainer.ALIGNMENT_CENTER
	pts_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pts_lbl := Label.new()
	pts_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pts_lbl.text = "%d P" % int(a_row.get("total_power", 0))
	pts_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pts_lbl.add_theme_font_override("font", FontCinzelBold)
	pts_lbl.add_theme_font_size_override("font_size", 28)
	pts_lbl.add_theme_color_override("font_color", MEDAL_COLORS[rank - 1] if rank <= 3 else Color(0.92, 0.84, 0.62))
	pts_box.add_child(pts_lbl)

	var sub_pow := Label.new()
	sub_pow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub_pow.text = "TOPLAM GÜÇ"
	sub_pow.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sub_pow.add_theme_font_override("font", FontNunitoBold)
	sub_pow.add_theme_font_size_override("font_size", 20)
	sub_pow.add_theme_color_override("font_color", Color(0.75, 0.68, 0.52))
	pts_box.add_child(sub_pow)
	row.add_child(pts_box)

	return card


func _make_empty_alliance_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.10, 0.15, 0.95)
	sb.border_color = Color(0.75, 0.62, 0.32, 0.80)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(24)
	card.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	card.add_child(vb)

	var lbl := Label.new()
	lbl.text = "Bu dünyada henüz kurulmuş bir ittifak yok.\nİlk ittifakı kurarak krallığa liderlik edebilirsin!"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_override("font", FontNunitoBold)
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
	vb.add_child(lbl)

	var btn := Button.new()
	btn.text = "🛡️ İttifak Kur veya Katıl"
	btn.custom_minimum_size = Vector2(300, 56)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_override("font", FontNunitoBold)
	btn.add_theme_font_size_override("font_size", 23)
	btn.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/Alliance.tscn")
	)
	vb.add_child(btn)
	return card
