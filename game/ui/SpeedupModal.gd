extends CanvasLayer
## SpeedupModal — Aktif veya sıradaki inşaat, eğitim, araştırma veya sefer için hızlandırma modalı.

const FontCinzelBold := preload("res://assets/fonts/Cinzel-Bold.ttf")
const FontNunitoBold := preload("res://assets/fonts/Nunito-Bold.ttf")
const FontNunitoSemiBold := preload("res://assets/fonts/Nunito-SemiBold.ttf")
const GameLoopScript := preload("res://scripts/core/GameLoop.gd")
const IconDiamond := preload("res://assets/sprites/ui/nano_banana/sharp_icon_diamond.tres")
const IconScrollBuild := preload("res://assets/sprites/ui/nano_banana/sharp_scroll_build.tres")
const IconScrollTrain := preload("res://assets/sprites/ui/nano_banana/sharp_scroll_train.tres")
const IconScrollResearch := preload("res://assets/sprites/ui/nano_banana/sharp_scroll_research.tres")
const IconScrollMarch := preload("res://assets/sprites/ui/nano_banana/sharp_scroll_march.tres")


func _scroll_tex_for_cat(cat: String) -> Texture2D:
	match cat:
		"train": return IconScrollTrain
		"research": return IconScrollResearch
		"march": return IconScrollMarch
	return IconScrollBuild

const FALLBACK_SCROLLS: Array[Dictionary] = [
	{"id": "build_10m", "category": "build", "seconds": 600, "cost_diamonds": 5, "name": "İnşaat 10 Dk"},
	{"id": "build_30m", "category": "build", "seconds": 1800, "cost_diamonds": 12, "name": "İnşaat 30 Dk"},
	{"id": "build_60m", "category": "build", "seconds": 3600, "cost_diamonds": 20, "name": "İnşaat 1 Saat"},
	{"id": "train_10m", "category": "train", "seconds": 600, "cost_diamonds": 5, "name": "Asker Eğitimi 10 Dk"},
	{"id": "train_30m", "category": "train", "seconds": 1800, "cost_diamonds": 12, "name": "Asker Eğitimi 30 Dk"},
	{"id": "train_60m", "category": "train", "seconds": 3600, "cost_diamonds": 20, "name": "Asker Eğitimi 1 Saat"},
	{"id": "research_10m", "category": "research", "seconds": 600, "cost_diamonds": 6, "name": "Araştırma 10 Dk"},
	{"id": "research_30m", "category": "research", "seconds": 1800, "cost_diamonds": 15, "name": "Araştırma 30 Dk"},
	{"id": "research_60m", "category": "research", "seconds": 3600, "cost_diamonds": 25, "name": "Araştırma 1 Saat"},
	{"id": "march_10m", "category": "march", "seconds": 600, "cost_diamonds": 8, "name": "Sefer Hızlandırma 10 Dk"},
	{"id": "march_30m", "category": "march", "seconds": 1800, "cost_diamonds": 18, "name": "Sefer Hızlandırma 30 Dk"},
	{"id": "march_60m", "category": "march", "seconds": 3600, "cost_diamonds": 30, "name": "Sefer Hızlandırma 1 Saat"},
]

var _ui_built: bool = false
var _category: String = "build"
var _target_id: Variant = null
var _title_text: String = ""

var _task_title_lbl: Label = null
var _timer_lbl: Label = null
var _diamond_lbl: Label = null
var _status_panel: PanelContainer = null
var _status_lbl: Label = null
var _rows_vbox: VBoxContainer = null
var _market_btn: Button = null
var _close_btn: Button = null


func _ready() -> void:
	name = "SpeedupModal"
	layer = 165
	_ensure_ui()
	_connect_signals()
	_refresh_all()


func configure(category: String, target_id: Variant = null, title_text: String = "") -> void:
	_category = category if category in ["build", "train", "research", "march"] else "build"
	_target_id = target_id
	_title_text = title_text
	_ensure_ui()
	_connect_signals()
	_refresh_all()


func setup(category: String, target_id: Variant = null, title_text: String = "") -> void:
	configure(category, target_id, title_text)


func _process(_delta: float) -> void:
	if not _ui_built:
		return
	_update_live_timer()


func _get_store_manager() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree and (loop as SceneTree).root != null:
		return (loop as SceneTree).root.get_node_or_null("StoreManager")
	return null


func _get_game_state() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree and (loop as SceneTree).root != null:
		return (loop as SceneTree).root.get_node_or_null("GameState")
	return null


func _fmt_duration(secs: int) -> String:
	var s := maxi(0, secs)
	var sm := _get_store_manager()
	if sm != null and sm.has_method("format_duration"):
		return str(sm.call("format_duration", s))
	if s >= 3600:
		return "%02d:%02d:%02d" % [s / 3600, (s % 3600) / 60, s % 60]
	return "%02d:%02d" % [s / 60, s % 60]


func _current_now() -> int:
	if GameLoopScript.instance != null and GameLoopScript.instance.now_unix() > 0:
		return GameLoopScript.instance.now_unix()
	var gs := _get_game_state()
	if gs != null and typeof(gs.world) == TYPE_DICTIONARY and (gs.world as Dictionary).has("sim_now_unix"):
		return maxi(int((gs.world as Dictionary)["sim_now_unix"]), int(Time.get_unix_time_from_system()))
	return int(Time.get_unix_time_from_system())


func _get_diamonds() -> int:
	var sm := _get_store_manager()
	if sm != null and sm.has_method("get_diamonds"):
		return int(sm.call("get_diamonds"))
	var gs := _get_game_state()
	if gs != null:
		return int(gs.player.get("diamonds", 35))
	return 35


func _get_scroll_count(scroll_id: String) -> int:
	var sm := _get_store_manager()
	if sm != null and sm.has_method("get_scroll_count"):
		return int(sm.call("get_scroll_count", scroll_id))
	var gs := _get_game_state()
	if gs != null and typeof(gs.player.get("scrolls")) == TYPE_DICTIONARY:
		return int((gs.player["scrolls"] as Dictionary).get(scroll_id, 0))
	return 0


func _get_scrolls_for_category(cat: String) -> Array:
	var sm := _get_store_manager()
	if sm != null and sm.has_method("get_scrolls_for_category"):
		var res = sm.call("get_scrolls_for_category", cat)
		if res is Array and not (res as Array).is_empty():
			return res
	var out: Array = []
	for s in FALLBACK_SCROLLS:
		if str(s.get("category", "")) == cat:
			out.append(s)
	return out


func _connect_signals() -> void:
	var sm := _get_store_manager()
	if sm != null:
		if sm.has_signal("diamonds_changed") and not sm.diamonds_changed.is_connected(_on_store_num_changed):
			sm.diamonds_changed.connect(_on_store_num_changed)
		if sm.has_signal("scrolls_changed") and not sm.scrolls_changed.is_connected(_on_store_dict_changed):
			sm.scrolls_changed.connect(_on_store_dict_changed)


func _on_store_num_changed(_amt: int) -> void:
	_refresh_all()


func _on_store_dict_changed(_d: Dictionary) -> void:
	_refresh_all()


func _ensure_ui() -> void:
	if _ui_built:
		return
	_ui_built = true

	var vp_size := Vector2(1080.0, 1920.0)
	if is_inside_tree() and get_viewport() != null:
		var r := get_viewport().get_visible_rect().size
		if r.x >= 200.0 and r.y >= 200.0:
			vp_size = r

	var root_ctrl := Control.new()
	root_ctrl.name = "ModalRoot"
	root_ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root_ctrl)

	var dim := ColorRect.new()
	dim.name = "DimBackdrop"
	dim.color = Color(0.03, 0.02, 0.05, 0.84)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			queue_free()
	)
	root_ctrl.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	root_ctrl.add_child(center)

	var card := PanelContainer.new()
	card.name = "SpeedupCard"
	card.custom_minimum_size = Vector2(clampf(vp_size.x - 56.0, 480.0, 860.0), 0.0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color = Color(0.10, 0.09, 0.14, 0.99)
	card_sb.border_color = Color(0.95, 0.78, 0.36, 1.0)
	card_sb.set_border_width_all(3)
	card_sb.border_width_top = 5
	card_sb.set_corner_radius_all(20)
	card_sb.set_content_margin_all(24)
	card_sb.shadow_color = Color(0, 0, 0, 0.78)
	card_sb.shadow_size = 20
	card.add_theme_stylebox_override("panel", card_sb)
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	card.add_child(vb)

	# Header
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 10)
	vb.add_child(hdr)

	var hdr_icon := TextureRect.new()
	hdr_icon.custom_minimum_size = Vector2(36, 36)
	hdr_icon.texture = _scroll_tex_for_cat(_category)
	hdr_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hdr_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hdr_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr.add_child(hdr_icon)

	var title_lbl := Label.new()
	title_lbl.text = "SÜRE HIZLANDIR"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_override("font", FontCinzelBold)
	title_lbl.add_theme_font_size_override("font_size", 26)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.56))
	title_lbl.add_theme_constant_override("outline_size", 0)
	title_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	hdr.add_child(title_lbl)

	var dia_pill := PanelContainer.new()
	var dp_sb := StyleBoxFlat.new()
	dp_sb.bg_color = Color(0.10, 0.18, 0.34, 0.98)
	dp_sb.border_color = Color(0.55, 0.85, 1.0, 0.95)
	dp_sb.set_border_width_all(2)
	dp_sb.set_corner_radius_all(12)
	dp_sb.content_margin_left = 10
	dp_sb.content_margin_right = 12
	dp_sb.content_margin_top = 4
	dp_sb.content_margin_bottom = 4
	dia_pill.add_theme_stylebox_override("panel", dp_sb)
	hdr.add_child(dia_pill)

	var dp_hb := HBoxContainer.new()
	dp_hb.add_theme_constant_override("separation", 6)
	dia_pill.add_child(dp_hb)

	var dp_ic := TextureRect.new()
	dp_ic.custom_minimum_size = Vector2(22, 22)
	dp_ic.texture = IconDiamond
	dp_ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dp_ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dp_hb.add_child(dp_ic)

	_diamond_lbl = Label.new()
	_diamond_lbl.text = "%d" % _get_diamonds()
	_diamond_lbl.add_theme_font_override("font", FontNunitoBold)
	_diamond_lbl.add_theme_font_size_override("font_size", 21)
	_diamond_lbl.add_theme_color_override("font_color", Color(0.92, 0.98, 1.0))
	_diamond_lbl.add_theme_constant_override("outline_size", 0)
	_diamond_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	dp_hb.add_child(_diamond_lbl)

	# Target Info + Timer
	var timer_card := PanelContainer.new()
	var tc_sb := StyleBoxFlat.new()
	tc_sb.bg_color = Color(0.06, 0.05, 0.09, 0.96)
	tc_sb.border_color = Color(0.38, 0.82, 0.98, 0.78)
	tc_sb.set_border_width_all(2)
	tc_sb.set_corner_radius_all(14)
	tc_sb.set_content_margin_all(14)
	timer_card.add_theme_stylebox_override("panel", tc_sb)
	vb.add_child(timer_card)

	var tc_vb := VBoxContainer.new()
	tc_vb.add_theme_constant_override("separation", 4)
	timer_card.add_child(tc_vb)

	_task_title_lbl = Label.new()
	_task_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_task_title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_task_title_lbl.add_theme_font_override("font", FontNunitoBold)
	_task_title_lbl.add_theme_font_size_override("font_size", 22)
	_task_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.86))
	_task_title_lbl.add_theme_constant_override("outline_size", 0)
	_task_title_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	tc_vb.add_child(_task_title_lbl)

	_timer_lbl = Label.new()
	_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_lbl.add_theme_font_override("font", FontNunitoBold)
	_timer_lbl.add_theme_font_size_override("font_size", 32)
	_timer_lbl.add_theme_color_override("font_color", Color(0.42, 0.92, 1.0))
	_timer_lbl.add_theme_constant_override("outline_size", 0)
	_timer_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	tc_vb.add_child(_timer_lbl)

	# Status feedback
	_status_panel = PanelContainer.new()
	_status_panel.visible = false
	vb.add_child(_status_panel)

	_status_lbl = Label.new()
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_lbl.add_theme_font_override("font", FontNunitoBold)
	_status_lbl.add_theme_font_size_override("font_size", 19)
	_status_lbl.add_theme_constant_override("outline_size", 0)
	_status_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	_status_panel.add_child(_status_lbl)

	# Rows
	_rows_vbox = VBoxContainer.new()
	_rows_vbox.name = "SpeedupScrollRows"
	_rows_vbox.add_theme_constant_override("separation", 10)
	vb.add_child(_rows_vbox)

	# Footer
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 14)
	vb.add_child(foot)

	_market_btn = Button.new()
	_market_btn.name = "SpeedupOpenMarketBtn"
	_market_btn.text = "🛒 Pazara Git"
	_market_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_market_btn.custom_minimum_size = Vector2(0, 54)
	_market_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_market_btn.add_theme_font_override("font", FontNunitoBold)
	_market_btn.add_theme_font_size_override("font_size", 22)
	var m_sb := StyleBoxFlat.new()
	m_sb.bg_color = Color(0.16, 0.24, 0.42, 0.98)
	m_sb.border_color = Color(0.88, 0.74, 0.36, 1.0)
	m_sb.set_border_width_all(2)
	m_sb.set_corner_radius_all(12)
	_market_btn.add_theme_stylebox_override("normal", m_sb)
	var m_h := m_sb.duplicate() as StyleBoxFlat
	m_h.bg_color = Color(0.22, 0.34, 0.56, 1.0)
	_market_btn.add_theme_stylebox_override("hover", m_h)
	_market_btn.add_theme_stylebox_override("pressed", m_h)
	_market_btn.add_theme_color_override("font_color", Color(1.0, 0.96, 0.84))
	_market_btn.pressed.connect(_on_open_market_pressed)
	foot.add_child(_market_btn)

	_close_btn = Button.new()
	_close_btn.name = "SpeedupCloseBtn"
	_close_btn.text = "Kapat"
	_close_btn.custom_minimum_size = Vector2(160, 54)
	_close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_close_btn.add_theme_font_override("font", FontNunitoBold)
	_close_btn.add_theme_font_size_override("font_size", 22)
	var c_sb := StyleBoxFlat.new()
	c_sb.bg_color = Color(0.44, 0.16, 0.16, 0.96)
	c_sb.border_color = Color(0.88, 0.40, 0.38, 1.0)
	c_sb.set_border_width_all(2)
	c_sb.set_corner_radius_all(12)
	_close_btn.add_theme_stylebox_override("normal", c_sb)
	var c_h := c_sb.duplicate() as StyleBoxFlat
	c_h.bg_color = Color(0.58, 0.22, 0.22, 1.0)
	_close_btn.add_theme_stylebox_override("hover", c_h)
	_close_btn.add_theme_stylebox_override("pressed", c_h)
	_close_btn.add_theme_color_override("font_color", Color(1.0, 0.96, 0.94))
	_close_btn.pressed.connect(func(): queue_free())
	foot.add_child(_close_btn)


func _refresh_all() -> void:
	if not _ui_built:
		return
	if _diamond_lbl != null:
		_diamond_lbl.text = "%d" % _get_diamonds()
	if _task_title_lbl != null:
		var def_title := "Aktif İşlem"
		match _category:
			"build": def_title = "🔨 Bina İnşaatı"
			"train": def_title = "⚔️ Asker Eğitimi"
			"research": def_title = "🔬 Birim Araştırması"
			"march": def_title = "🐴 Ordu / Kervan Seferi"
		_task_title_lbl.text = _title_text if not _title_text.is_empty() else def_title
	_update_live_timer()
	_populate_rows()


func _find_target_item() -> Dictionary:
	var gs := _get_game_state()
	if gs == null:
		return {}
	if _category == "march":
		for m in gs.movements:
			if typeof(m) != TYPE_DICTIONARY:
				continue
			var md := m as Dictionary
			if _target_id != null and str(md.get("id", "")) == str(_target_id):
				return md
		var vid := int(gs.active_village_id)
		var p_name := str(gs.player.get("name", "")).strip_edges().to_lower()
		for m in gs.movements:
			if typeof(m) == TYPE_DICTIONARY:
				var md := m as Dictionary
				var m_own := str(md.get("owner", "")).strip_edges().to_lower()
				if (not p_name.is_empty() and m_own == p_name) or int(md.get("from_village_id", -1)) == vid or int(md.get("to_village_id", -1)) == vid or int(md.get("village_id", -1)) == vid:
					return md
		return {}
	else:
		var vid := int(gs.active_village_id)
		for q in gs.queues:
			if typeof(q) != TYPE_DICTIONARY:
				continue
			var qd := q as Dictionary
			if int(qd.get("village_id", -1)) != vid or str(qd.get("type", "")) != _category:
				continue
			if _target_id == null or str(qd.get("id", "")) == str(_target_id):
				return qd
		return {}


func _update_live_timer() -> void:
	if _timer_lbl == null:
		return
	var item := _find_target_item()
	if item.is_empty():
		_timer_lbl.text = "✅ Tamamlandı!"
		_timer_lbl.add_theme_color_override("font_color", Color(0.45, 0.96, 0.56))
		return
	var now := _current_now()
	if _category == "march":
		var arr := int(item.get("arrive_unix", now))
		var rem := maxi(0, arr - now)
		_timer_lbl.text = "⏱ Kalan Süre: %s" % _fmt_duration(rem)
		_timer_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.42))
	else:
		var start := int(item.get("start_unix", now))
		var finish := int(item.get("finish_unix", now))
		if now < start:
			var dur := maxi(0, finish - start)
			_timer_lbl.text = "⏳ Sırada • Süre: %s" % _fmt_duration(dur)
			_timer_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.44))
		else:
			var rem := maxi(0, finish - now)
			_timer_lbl.text = "⏱ Kalan Süre: %s" % _fmt_duration(rem)
			_timer_lbl.add_theme_color_override("font_color", Color(0.42, 0.92, 1.0))


func _populate_rows() -> void:
	if _rows_vbox == null:
		return
	for c in _rows_vbox.get_children():
		_rows_vbox.remove_child(c)
		c.queue_free()

	var scrolls := _get_scrolls_for_category(_category)
	for s_raw in scrolls:
		var s: Dictionary = s_raw
		var s_id := str(s.get("id", ""))
		var s_name := str(s.get("name", s_id))
		var secs := int(s.get("seconds", 600))
		var cost := int(s.get("cost_diamonds", 5))
		var owned := _get_scroll_count(s_id)
		var short_dur := "1 Saat" if secs >= 3600 else ("%d Dk" % (secs / 60))

		var row_card := PanelContainer.new()
		var r_sb := StyleBoxFlat.new()
		r_sb.bg_color = Color(0.15, 0.13, 0.21, 0.98)
		r_sb.border_color = Color(0.48, 0.86, 0.56, 0.85) if owned > 0 else Color(0.75, 0.62, 0.34, 0.78)
		r_sb.set_border_width_all(2)
		r_sb.set_corner_radius_all(14)
		r_sb.content_margin_left = 16
		r_sb.content_margin_right = 16
		r_sb.content_margin_top = 12
		r_sb.content_margin_bottom = 12
		row_card.add_theme_stylebox_override("panel", r_sb)

		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 12)
		row_card.add_child(hb)

		var tier_txt := "1 SA" if secs >= 3600 else ("%d DK" % (secs / 60))
		var tier_col := Color(1.0, 0.86, 0.34) if secs >= 3600 else (Color(0.54, 0.88, 1.0) if secs >= 1800 else Color(0.68, 0.94, 0.64))
		var ic_box := PanelContainer.new()
		ic_box.custom_minimum_size = Vector2(64, 64)
		ic_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var ic_sb := StyleBoxFlat.new()
		ic_sb.bg_color = Color(0.11, 0.09, 0.16, 0.98)
		ic_sb.border_color = tier_col
		ic_sb.set_border_width_all(2)
		ic_sb.set_corner_radius_all(12)
		ic_sb.set_content_margin_all(4)
		ic_box.add_theme_stylebox_override("panel", ic_sb)
		var ic_tr := TextureRect.new()
		ic_tr.texture = _scroll_tex_for_cat(_category)
		ic_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic_tr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ic_tr.size_flags_vertical = Control.SIZE_EXPAND_FILL
		ic_box.add_child(ic_tr)
		var ic_ov := Control.new()
		ic_ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ic_ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic_box.add_child(ic_ov)
		var ic_pill_box := PanelContainer.new()
		ic_pill_box.anchor_left = 0.0
		ic_pill_box.anchor_right = 1.0
		ic_pill_box.anchor_top = 1.0
		ic_pill_box.anchor_bottom = 1.0
		ic_pill_box.offset_top = -18.0
		ic_pill_box.offset_bottom = 2.0
		ic_pill_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ip_sb := StyleBoxFlat.new()
		ip_sb.bg_color = Color(0.06, 0.05, 0.09, 0.92)
		ip_sb.border_color = tier_col
		ip_sb.set_border_width_all(1)
		ip_sb.set_corner_radius_all(5)
		ic_pill_box.add_theme_stylebox_override("panel", ip_sb)
		var ic_pill := Label.new()
		ic_pill.text = tier_txt
		ic_pill.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ic_pill.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ic_pill.add_theme_font_override("font", FontNunitoBold)
		ic_pill.add_theme_font_size_override("font_size", 11)
		ic_pill.add_theme_color_override("font_color", tier_col)
		ic_pill_box.add_child(ic_pill)
		ic_ov.add_child(ic_pill_box)
		hb.add_child(ic_box)

		var info_vb := VBoxContainer.new()
		info_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vb.add_theme_constant_override("separation", 2)
		hb.add_child(info_vb)

		var n_lbl := Label.new()
		n_lbl.text = "%s (-%s)" % [s_name, short_dur]
		n_lbl.add_theme_font_override("font", FontNunitoBold)
		n_lbl.add_theme_font_size_override("font_size", 22)
		n_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82))
		n_lbl.add_theme_constant_override("outline_size", 0)
		n_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		info_vb.add_child(n_lbl)

		var o_lbl := Label.new()
		o_lbl.text = "Sahip: %d" % owned
		o_lbl.add_theme_font_override("font", FontNunitoBold)
		o_lbl.add_theme_font_size_override("font_size", 18)
		o_lbl.add_theme_color_override("font_color", Color(0.48, 0.95, 0.58) if owned > 0 else Color(0.75, 0.74, 0.82))
		o_lbl.add_theme_constant_override("outline_size", 0)
		o_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		info_vb.add_child(o_lbl)

		var action_btn := Button.new()
		action_btn.custom_minimum_size = Vector2(210, 52)
		action_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		action_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		action_btn.add_theme_font_override("font", FontNunitoBold)
		action_btn.add_theme_font_size_override("font_size", 20)
		action_btn.add_theme_constant_override("outline_size", 0)
		action_btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))

		if owned > 0:
			action_btn.name = "UseScrollBtn_" + s_id
			action_btn.text = "⚡ Kullan (%s)" % short_dur
			var u_sb := StyleBoxFlat.new()
			u_sb.bg_color = Color(0.18, 0.58, 0.30, 1.0)
			u_sb.border_color = Color(0.56, 0.94, 0.66, 1.0)
			u_sb.set_border_width_all(2)
			u_sb.set_corner_radius_all(12)
			action_btn.add_theme_stylebox_override("normal", u_sb)
			var u_h := u_sb.duplicate() as StyleBoxFlat
			u_h.bg_color = Color(0.24, 0.68, 0.38, 1.0)
			action_btn.add_theme_stylebox_override("hover", u_h)
			action_btn.add_theme_stylebox_override("pressed", u_h)
			action_btn.add_theme_color_override("font_color", Color(1, 1, 1))
			action_btn.pressed.connect(_on_use_scroll_pressed.bind(s_id))
			hb.add_child(action_btn)

			var buy_more_btn := Button.new()
			buy_more_btn.name = "BuyMoreScrollBtn_" + s_id
			buy_more_btn.text = "+1 Al (💎 %d)" % cost
			buy_more_btn.custom_minimum_size = Vector2(142, 52)
			buy_more_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			buy_more_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			buy_more_btn.add_theme_font_override("font", FontNunitoBold)
			buy_more_btn.add_theme_font_size_override("font_size", 18)
			var bm_sb := StyleBoxFlat.new()
			bm_sb.bg_color = Color(0.14, 0.32, 0.54, 0.98)
			bm_sb.border_color = Color(0.58, 0.88, 1.0, 0.95)
			bm_sb.set_border_width_all(2)
			bm_sb.set_corner_radius_all(12)
			buy_more_btn.add_theme_stylebox_override("normal", bm_sb)
			var bm_h := bm_sb.duplicate() as StyleBoxFlat
			bm_h.bg_color = bm_sb.bg_color.lightened(0.12)
			buy_more_btn.add_theme_stylebox_override("hover", bm_h)
			buy_more_btn.add_theme_stylebox_override("pressed", bm_h)
			buy_more_btn.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
			buy_more_btn.pressed.connect(_on_buy_more_scroll_pressed.bind(s_id, s_name, cost))
			hb.add_child(buy_more_btn)
		else:
			action_btn.name = "QuickBuyScrollBtn_" + s_id
			action_btn.text = "💎 %d Al & Kullan" % cost
			var q_sb := StyleBoxFlat.new()
			q_sb.bg_color = Color(0.76, 0.56, 0.14, 1.0)
			q_sb.border_color = Color(1.0, 0.88, 0.44, 1.0)
			q_sb.set_border_width_all(2)
			q_sb.set_corner_radius_all(12)
			action_btn.add_theme_stylebox_override("normal", q_sb)
			var q_h := q_sb.duplicate() as StyleBoxFlat
			q_h.bg_color = Color(0.88, 0.68, 0.20, 1.0)
			action_btn.add_theme_stylebox_override("hover", q_h)
			action_btn.add_theme_stylebox_override("pressed", q_h)
			action_btn.add_theme_color_override("font_color", Color(0.14, 0.08, 0.02))
			action_btn.pressed.connect(_on_quick_buy_use_pressed.bind(s_id, cost))
			hb.add_child(action_btn)

		_rows_vbox.add_child(row_card)


func _on_buy_more_scroll_pressed(scroll_id: String, scroll_name: String, cost: int) -> void:
	var sm := _get_store_manager()
	if sm == null or not sm.has_method("buy_scroll"):
		_show_status("Mağaza servisi hazır değil.", false)
		return
	var b_res = sm.call("buy_scroll", scroll_id, 1)
	if typeof(b_res) == TYPE_DICTIONARY and bool((b_res as Dictionary).get("ok", false)):
		_show_status("✅ +1 %s envantere eklendi! '⚡ Kullan' ile hemen uygulayabilirsiniz." % scroll_name, true)
		_refresh_all()
	else:
		if _get_diamonds() < cost:
			_show_status("💎 Yetersiz elmas (%d gerekli)." % cost, false)
		else:
			_show_status(str((b_res as Dictionary).get("error", "Satın alınamadı.")) if typeof(b_res) == TYPE_DICTIONARY else "Satın alınamadı.", false)


func _show_status(msg: String, is_ok: bool) -> void:
	if _status_panel == null or _status_lbl == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.28, 0.16, 0.96) if is_ok else Color(0.38, 0.14, 0.14, 0.96)
	sb.border_color = Color(0.45, 0.92, 0.56, 1.0) if is_ok else Color(0.95, 0.42, 0.38, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	_status_panel.add_theme_stylebox_override("panel", sb)
	_status_lbl.text = msg
	_status_lbl.add_theme_color_override("font_color", Color(0.94, 1.0, 0.94) if is_ok else Color(1.0, 0.92, 0.90))
	_status_panel.show()


func _on_use_scroll_pressed(scroll_id: String) -> void:
	var sm := _get_store_manager()
	if sm == null or not sm.has_method("apply_scroll_to_queue"):
		_show_status("Hızlandırma servisi hazır değil.", false)
		return
	var res = sm.call("apply_scroll_to_queue", scroll_id, _category, _target_id)
	if typeof(res) == TYPE_DICTIONARY and bool((res as Dictionary).get("ok", false)):
		if bool((res as Dictionary).get("completed", false)) or _find_target_item().is_empty():
			queue_free()
			return
		var sec := int((res as Dictionary).get("reduced_seconds", 0))
		_show_status("⚡ Süre %s kısaltıldı!" % _fmt_duration(sec), true)
		_refresh_all()
	else:
		var err := str((res as Dictionary).get("error", "Parşömen uygulanamadı.")) if typeof(res) == TYPE_DICTIONARY else "Parşömen uygulanamadı."
		_show_status(err, false)


func _on_quick_buy_use_pressed(scroll_id: String, cost: int) -> void:
	var sm := _get_store_manager()
	if sm == null or not sm.has_method("buy_scroll"):
		_show_status("Mağaza servisi hazır değil.", false)
		return
	var b_res = sm.call("buy_scroll", scroll_id, 1)
	if typeof(b_res) != TYPE_DICTIONARY or not bool((b_res as Dictionary).get("ok", false)):
		if _get_diamonds() < cost:
			_show_status("💎 Yetersiz elmas (%d gerekli). Pazara giderek elmas alabilirsiniz." % cost, false)
		else:
			_show_status(str((b_res as Dictionary).get("error", "Satın alınamadı.")) if typeof(b_res) == TYPE_DICTIONARY else "Satın alınamadı.", false)
		return
	_on_use_scroll_pressed(scroll_id)


func _on_open_market_pressed() -> void:
	var sm := _get_store_manager()
	var target_tab := "diamonds" if _get_diamonds() < 5 else _category
	var loop := Engine.get_main_loop()
	var st_root: Node = (loop as SceneTree).root if loop is SceneTree else null
	queue_free()
	if sm != null and sm.has_method("open_market"):
		sm.call("open_market", st_root, target_tab)
		return
	var m_script = load("res://ui/MarketModal.gd")
	if m_script != null and st_root != null:
		var modal = m_script.new()
		st_root.add_child(modal)
		if modal.has_method("open_tab"):
			modal.call("open_tab", target_tab)
