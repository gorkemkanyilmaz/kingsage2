extends CanvasLayer
## LordModal — Knight Online Stili Lord (Kahraman) & 13 Slotlu Ekipman Ekranı.

signal closed()
signal open_upgrade_requested(item_id: String)
signal open_market_lord_requested()

const LordModelScript := preload("res://scripts/model/LordModel.gd")
const LordUpgradeModalScript := preload("res://ui/LordUpgradeModal.gd")
const FontCinzelBold := preload("res://assets/fonts/Cinzel-Bold.ttf")
const FontNunitoBold := preload("res://assets/fonts/Nunito-Bold.ttf")
const FontNunitoSemiBold := preload("res://assets/fonts/Nunito-SemiBold.ttf")
const TexLordFull := preload("res://assets/sprites/lord/lord_hero_full.png")
const TexUpgradeScroll := preload("res://assets/sprites/lord/upgrade_scroll.png")

var _ui_built: bool = false
var _opened_explicitly: bool = false
var _inv_filter: String = "all" # "all" | "battle" | "accessory"
var _selected_slot_key: String = ""
var _detail_item_id: String = ""

var _root_ctrl: Control
var _title_lbl: Label
var _status_lbl: Label
var _hero_frame: PanelContainer
var _hero_tex: TextureRect
var _hero_gear_overlay_box: HBoxContainer
var _slot_btns: Dictionary = {}

var _hp_lbl: Label
var _atk_lbl: Label
var _def_lbl: Label
var _army_lbl: Label
var _scrolls_lbl: Label

var _inv_grid: GridContainer
var _empty_inv_lbl: Label
var _filter_btns: Dictionary = {}

var _slot_picker_overlay: Control = null
var _item_detail_overlay: Control = null
var _upgrade_modal: CanvasLayer = null


func _ready() -> void:
	layer = 120
	_build_ui()
	var lm := _lord_mgr()
	if lm != null and lm.has_signal("lord_changed") and not lm.lord_changed.is_connected(_refresh_all):
		lm.lord_changed.connect(_refresh_all)
	if not _opened_explicitly:
		hide()


func _lord_mgr() -> Node:
	var loop := Engine.get_main_loop()
	return (loop as SceneTree).root.get_node_or_null("LordManager") if loop is SceneTree else null


func open_modal(focus_action: String = "", focus_item_id: String = "") -> void:
	_opened_explicitly = true
	_build_ui()
	var lm := _lord_mgr()
	if lm != null and lm.has_method("tick_recovery"):
		lm.call("tick_recovery")
	_refresh_all()
	show()
	if focus_action == "upgrade_screen":
		open_upgrade_modal(focus_item_id)
	elif focus_action == "item_detail" and not focus_item_id.is_empty():
		_open_item_detail(focus_item_id)


func close_modal() -> void:
	_opened_explicitly = false
	if _slot_picker_overlay != null:
		_slot_picker_overlay.hide()
	if _item_detail_overlay != null:
		_item_detail_overlay.hide()
	hide()
	closed.emit()


func open_upgrade_modal(item_id: String = "") -> void:
	if _upgrade_modal == null or not is_instance_valid(_upgrade_modal):
		_upgrade_modal = LordUpgradeModalScript.new()
		_upgrade_modal.open_market_lord_requested.connect(func():
			close_modal()
			open_market_lord_requested.emit()
		)
		_upgrade_modal.closed.connect(_refresh_all)
		var host := get_parent() if get_parent() != null else self
		host.add_child(_upgrade_modal)
	_upgrade_modal.call("open_modal", item_id)


func _build_ui() -> void:
	if _ui_built:
		return
	_ui_built = true

	_root_ctrl = Control.new()
	_root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root_ctrl)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.02, 0.04, 0.86)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root_ctrl.add_child(dim)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 84)
	margin.add_theme_constant_override("margin_bottom", 76)
	_root_ctrl.add_child(margin)

	var card := PanelContainer.new()
	card.name = "LordModalCard"
	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color = Color(0.08, 0.07, 0.12, 0.99)
	card_sb.border_color = Color(0.92, 0.76, 0.34, 1.0)
	card_sb.set_border_width_all(3)
	card_sb.border_width_top = 6
	card_sb.set_corner_radius_all(20)
	card_sb.set_content_margin_all(18)
	card.add_theme_stylebox_override("panel", card_sb)
	margin.add_child(card)

	var main_vb := VBoxContainer.new()
	main_vb.add_theme_constant_override("separation", 12)
	card.add_child(main_vb)

	# 1. Başlık + Ekipman Geliştir + Kapat
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 10)
	main_vb.add_child(hdr)

	var title_vb := VBoxContainer.new()
	title_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(title_vb)

	_title_lbl = Label.new()
	_title_lbl.text = "👑 LORD"
	_title_lbl.add_theme_font_override("font", FontCinzelBold)
	_title_lbl.add_theme_font_size_override("font_size", 28)
	_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	title_vb.add_child(_title_lbl)

	_status_lbl = Label.new()
	_status_lbl.text = "🟢 Savaşa Hazır"
	_status_lbl.add_theme_font_override("font", FontNunitoBold)
	_status_lbl.add_theme_font_size_override("font_size", 18)
	_status_lbl.add_theme_color_override("font_color", Color(0.55, 0.95, 0.65))
	title_vb.add_child(_status_lbl)

	var btn_upgrade := Button.new()
	btn_upgrade.name = "BtnOpenLordUpgrade"
	btn_upgrade.text = "⚒️ Ekipman Geliştir"
	btn_upgrade.custom_minimum_size = Vector2(240, 52)
	_style_btn(btn_upgrade, Color(0.54, 0.30, 0.08, 0.98), Color(1.0, 0.84, 0.34, 1.0), Color(1.0, 0.96, 0.84))
	btn_upgrade.pressed.connect(func(): open_upgrade_modal())
	hdr.add_child(btn_upgrade)

	var btn_close := Button.new()
	btn_close.name = "BtnCloseLordModal"
	btn_close.text = "✕"
	btn_close.custom_minimum_size = Vector2(54, 52)
	_style_btn(btn_close, Color(0.32, 0.14, 0.16, 0.96), Color(0.92, 0.48, 0.48, 1.0), Color(1, 0.92, 0.92))
	btn_close.pressed.connect(close_modal)
	hdr.add_child(btn_close)

	# Kaydırılabilir Gövde
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vb.add_child(sc)

	var body_vb := VBoxContainer.new()
	body_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_vb.add_theme_constant_override("separation", 14)
	sc.add_child(body_vb)

	# 2. Knight Online Karakter & 13 Ekipman Slotu Paneli
	var ko_panel := PanelContainer.new()
	ko_panel.add_theme_stylebox_override("panel", _dark_sb(Color(0.06, 0.06, 0.10, 0.98), Color(0.75, 0.60, 0.28, 0.90)))
	body_vb.add_child(ko_panel)

	var ko_hb := HBoxContainer.new()
	ko_hb.add_theme_constant_override("separation", 10)
	ko_panel.add_child(ko_hb)

	var left_col := VBoxContainer.new()
	left_col.name = "LeftSlotsCol"
	left_col.add_theme_constant_override("separation", 8)
	left_col.custom_minimum_size = Vector2(210, 0)
	ko_hb.add_child(left_col)

	var center_vb := VBoxContainer.new()
	center_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	center_vb.add_theme_constant_override("separation", 8)
	ko_hb.add_child(center_vb)

	_hero_frame = PanelContainer.new()
	_hero_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hero_frame.custom_minimum_size = Vector2(0, 480)
	_hero_frame.add_theme_stylebox_override("panel", _dark_sb(Color(0.05, 0.05, 0.08, 1.0), Color(0.92, 0.75, 0.34, 0.95)))
	center_vb.add_child(_hero_frame)

	var hero_overlay_root := Control.new()
	hero_overlay_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hero_frame.add_child(hero_overlay_root)

	_hero_tex = TextureRect.new()
	_hero_tex.texture = TexLordFull
	_hero_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hero_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	hero_overlay_root.add_child(_hero_tex)

	# Kuşanılan ekipmanların Lord görseli üzerindeki canlı rozet/katman göstergesi
	var gear_bar_panel := PanelContainer.new()
	gear_bar_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	gear_bar_panel.offset_top = -78
	gear_bar_panel.offset_left = 8
	gear_bar_panel.offset_right = -8
	gear_bar_panel.offset_bottom = -8
	gear_bar_panel.add_theme_stylebox_override("panel", _dark_sb(Color(0.05, 0.05, 0.08, 0.84), Color(0.88, 0.72, 0.32, 0.85)))
	hero_overlay_root.add_child(gear_bar_panel)

	_hero_gear_overlay_box = HBoxContainer.new()
	_hero_gear_overlay_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_hero_gear_overlay_box.add_theme_constant_override("separation", 6)
	gear_bar_panel.add_child(_hero_gear_overlay_box)

	var right_col := VBoxContainer.new()
	right_col.name = "RightSlotsCol"
	right_col.add_theme_constant_override("separation", 8)
	right_col.custom_minimum_size = Vector2(210, 0)
	ko_hb.add_child(right_col)

	# 13 slotu sol & sağ sütunlara oluştur
	_slot_btns.clear()
	for sdef in LordModelScript.SLOTS:
		var sk := str(sdef["key"])
		var sb_tile := _create_slot_button(sdef)
		if str(sdef["side"]) == "left":
			left_col.add_child(sb_tile)
		else:
			right_col.add_child(sb_tile)
		_slot_btns[sk] = sb_tile

	# 3. Lord Dinamik Stat Kartı
	var stats_panel := PanelContainer.new()
	stats_panel.name = "LordStatsCard"
	stats_panel.add_theme_stylebox_override("panel", _dark_sb(Color(0.11, 0.10, 0.16, 0.98), Color(0.84, 0.68, 0.34, 0.88)))
	body_vb.add_child(stats_panel)

	var stats_vb := VBoxContainer.new()
	stats_vb.add_theme_constant_override("separation", 8)
	stats_panel.add_child(stats_vb)

	var stat_row := HBoxContainer.new()
	stat_row.add_theme_constant_override("separation", 10)
	stats_vb.add_child(stat_row)

	_hp_lbl = _make_stat_chip(stat_row, Color(0.16, 0.24, 0.18, 0.96), Color(0.45, 0.92, 0.56, 0.9))
	_atk_lbl = _make_stat_chip(stat_row, Color(0.26, 0.13, 0.14, 0.96), Color(0.95, 0.45, 0.40, 0.9))
	_def_lbl = _make_stat_chip(stat_row, Color(0.12, 0.18, 0.30, 0.96), Color(0.45, 0.78, 1.0, 0.9))

	var bonus_row := HBoxContainer.new()
	bonus_row.add_theme_constant_override("separation", 10)
	stats_vb.add_child(bonus_row)

	_army_lbl = Label.new()
	_army_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_army_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_army_lbl.add_theme_font_override("font", FontNunitoBold)
	_army_lbl.add_theme_font_size_override("font_size", 19)
	_army_lbl.add_theme_color_override("font_color", Color(0.96, 0.88, 0.60))
	bonus_row.add_child(_army_lbl)

	_scrolls_lbl = Label.new()
	_scrolls_lbl.add_theme_font_override("font", FontNunitoBold)
	_scrolls_lbl.add_theme_font_size_override("font_size", 19)
	_scrolls_lbl.add_theme_color_override("font_color", Color(0.65, 0.90, 1.0))
	bonus_row.add_child(_scrolls_lbl)

	# 4. Lord Envanteri Bölümü (Sadece takılı olmayan eşyalar listelenir)
	var inv_panel := PanelContainer.new()
	inv_panel.add_theme_stylebox_override("panel", _dark_sb(Color(0.09, 0.08, 0.14, 0.98), Color(0.62, 0.52, 0.30, 0.85)))
	body_vb.add_child(inv_panel)

	var inv_vb := VBoxContainer.new()
	inv_vb.add_theme_constant_override("separation", 10)
	inv_panel.add_child(inv_vb)

	var inv_hdr := HBoxContainer.new()
	inv_hdr.add_theme_constant_override("separation", 8)
	inv_vb.add_child(inv_hdr)

	var inv_t := Label.new()
	inv_t.text = "🎒 LORD ENVANTERİ"
	inv_t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv_t.add_theme_font_override("font", FontCinzelBold)
	inv_t.add_theme_font_size_override("font_size", 22)
	inv_t.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	inv_hdr.add_child(inv_t)

	_filter_btns.clear()
	for fdef in [
		{"key": "all", "label": "Tümü"},
		{"key": "battle", "label": "Savaş"},
		{"key": "accessory", "label": "Aksesuar"},
	]:
		var fkey := str(fdef["key"])
		var fb := Button.new()
		fb.text = str(fdef["label"])
		fb.custom_minimum_size = Vector2(110, 42)
		fb.pressed.connect(func():
			_inv_filter = fkey
			_refresh_all()
		)
		inv_hdr.add_child(fb)
		_filter_btns[fkey] = fb

	_inv_grid = GridContainer.new()
	_inv_grid.name = "LordInventoryGrid"
	_inv_grid.columns = 2
	_inv_grid.add_theme_constant_override("h_separation", 10)
	_inv_grid.add_theme_constant_override("v_separation", 10)
	inv_vb.add_child(_inv_grid)

	_empty_inv_lbl = Label.new()
	_empty_inv_lbl.text = "Envanterde boşta ekipman yok. Haydut köylerine saldırarak yeni ekipman düşürebilirsiniz!"
	_empty_inv_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_inv_lbl.add_theme_font_override("font", FontNunitoSemiBold)
	_empty_inv_lbl.add_theme_font_size_override("font_size", 19)
	_empty_inv_lbl.add_theme_color_override("font_color", Color(0.76, 0.74, 0.80))
	inv_vb.add_child(_empty_inv_lbl)

	# 5. Slot Seçici & Eşya Detay Katmanları
	_build_slot_picker_overlay()
	_build_item_detail_overlay()


func _make_stat_chip(parent: HBoxContainer, bg: Color, border: Color) -> Label:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", _dark_sb(bg, border))
	parent.add_child(p)
	var lbl := Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", FontNunitoBold)
	lbl.add_theme_font_size_override("font_size", 21)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.88))
	p.add_child(lbl)
	return lbl


func _create_slot_button(sdef: Dictionary) -> Button:
	var sk := str(sdef["key"])
	var btn := Button.new()
	btn.name = "Slot_" + sk
	btn.custom_minimum_size = Vector2(204, 82)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pressed.connect(func(): _on_slot_pressed(sk))

	var hb := HBoxContainer.new()
	hb.name = "Row"
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.add_theme_constant_override("separation", 8)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(hb)

	var pad := Control.new()
	pad.custom_minimum_size = Vector2(4, 0)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(pad)

	var ic := TextureRect.new()
	ic.name = "Icon"
	ic.custom_minimum_size = Vector2(54, 54)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(ic)

	var tx_vb := VBoxContainer.new()
	tx_vb.name = "Tx"
	tx_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tx_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	tx_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(tx_vb)

	var top_l := Label.new()
	top_l.name = "TopLbl"
	top_l.clip_text = true
	top_l.add_theme_font_override("font", FontNunitoBold)
	top_l.add_theme_font_size_override("font_size", 17)
	top_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tx_vb.add_child(top_l)

	var sub_l := Label.new()
	sub_l.name = "SubLbl"
	sub_l.clip_text = true
	sub_l.add_theme_font_override("font", FontNunitoSemiBold)
	sub_l.add_theme_font_size_override("font_size", 15)
	sub_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tx_vb.add_child(sub_l)

	btn.text = ""
	return btn


func _refresh_all() -> void:
	if not _ui_built:
		return
	var lm := _lord_mgr()
	var gs: Node = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	var p_name := str(gs.player.get("name", "Hükümdar")) if gs != null else "Hükümdar"
	_title_lbl.text = "👑 LORD %s" % p_name.to_upper()

	if lm == null:
		return
	var ld: Dictionary = lm.call("get_lord_state")
	var stats: Dictionary = lm.call("get_lord_stats")

	if bool(lm.call("is_injured")):
		var rem := int(lm.call("get_injury_remaining_secs"))
		var mm := rem / 60
		var ss := rem % 60
		_status_lbl.text = "🩸 Yaralı · İyileşme: %02d:%02d (Ekipmanlar Güvende)" % [mm, ss]
		_status_lbl.add_theme_color_override("font_color", Color(1.0, 0.50, 0.45))
	else:
		_status_lbl.text = "🟢 Savaşa Hazır · Kuşanılmış: %d / 13" % int(stats.get("equipped_count", 0))
		_status_lbl.add_theme_color_override("font_color", Color(0.55, 0.95, 0.65))

	_hp_lbl.text = "❤️ HP: %d" % int(stats.get("hp", 500))
	_atk_lbl.text = "⚔️ Saldırı: %d (+%%%.1f)" % [int(stats.get("attack", 120)), float(stats.get("attack_pct", 0.0))]
	_def_lbl.text = "🛡️ Savunma: %d (+%%%.1f)" % [int(stats.get("defense", 100)), float(stats.get("defense_pct", 0.0))]

	var ab_parts: Array[String] = []
	if float(stats.get("infantry_atk_pct", 0.0)) > 0.0:
		ab_parts.append("Piyade +%%%.1f" % float(stats["infantry_atk_pct"]))
	if float(stats.get("archer_atk_pct", 0.0)) > 0.0:
		ab_parts.append("Okçu +%%%.1f" % float(stats["archer_atk_pct"]))
	if float(stats.get("cavalry_def_pct", 0.0)) > 0.0:
		ab_parts.append("Süvari Sav. +%%%.1f" % float(stats["cavalry_def_pct"]))
	if float(stats.get("army_hp_pct", 0.0)) > 0.0:
		ab_parts.append("Ordu HP +%%%.1f" % float(stats["army_hp_pct"]))
	_army_lbl.text = "Ordu Bonusu: " + (" · ".join(ab_parts) if not ab_parts.is_empty() else "Yok (Nadir/Aksesuar kuşanın)")
	_scrolls_lbl.text = "📜 Parşömen: %d" % int(ld.get("upgrade_scrolls", 0))

	# Lord portre görseli ve üzerindeki canlı ekipman katmanı güncelle
	for ch in _hero_gear_overlay_box.get_children():
		ch.queue_free()
	var eq_cnt := int(stats.get("equipped_count", 0))
	if eq_cnt == 0:
		var empty_h := Label.new()
		empty_h.text = "Henüz ekipman takılı değil — yan slotlara dokun"
		empty_h.add_theme_font_override("font", FontNunitoSemiBold)
		empty_h.add_theme_font_size_override("font_size", 16)
		empty_h.add_theme_color_override("font_color", Color(0.75, 0.74, 0.80))
		_hero_gear_overlay_box.add_child(empty_h)
	var rare_glow := false

	for sdef in LordModelScript.SLOTS:
		var sk := str(sdef["key"])
		var btn: Button = _slot_btns.get(sk)
		if btn == null:
			continue
		var item: Dictionary = lm.call("get_equipped_item", sk)
		var ic := btn.get_node("Row/Icon") as TextureRect
		var top_l := btn.get_node("Row/Tx/TopLbl") as Label
		var sub_l := btn.get_node("Row/Tx/SubLbl") as Label
		if item.is_empty():
			ic.texture = load(LordModelScript.icon_path_for(str(sdef["slot_type"]))) as Texture2D
			ic.modulate = Color(0.45, 0.45, 0.50, 0.42)
			top_l.text = str(sdef["name"])
			top_l.add_theme_color_override("font_color", Color(0.65, 0.66, 0.72))
			sub_l.text = "[Boş Slot]"
			sub_l.add_theme_color_override("font_color", Color(0.48, 0.50, 0.56))
			_style_btn(btn, Color(0.08, 0.08, 0.12, 0.92), Color(0.32, 0.34, 0.42, 0.70), Color(0.7, 0.7, 0.75))
		else:
			var rar := str(item.get("rarity", "common"))
			var plus := int(item.get("plus", 0))
			var rc := LordModelScript.rarity_color(rar)
			if rar == "rare":
				rare_glow = true
			ic.texture = load(LordModelScript.icon_path_for(str(item.get("slot_type", sdef["slot_type"])))) as Texture2D
			ic.modulate = Color(1, 1, 1, 1)
			top_l.text = "+%d %s" % [plus, str(item.get("name", sdef["name"]))]
			top_l.add_theme_color_override("font_color", rc)
			sub_l.text = LordModelScript.format_item_short_bonus(item)
			sub_l.add_theme_color_override("font_color", Color(0.88, 0.90, 0.94))
			_style_btn(btn, Color(0.14, 0.12, 0.19, 0.98), rc, Color(1, 1, 1))

			# Kahraman portresi üzerindeki görsel ekipman ikon şeridine ekle
			var mini := PanelContainer.new()
			mini.custom_minimum_size = Vector2(44, 44)
			mini.add_theme_stylebox_override("panel", _dark_sb(Color(0.08, 0.07, 0.12, 0.96), rc))
			var m_tr := TextureRect.new()
			m_tr.texture = ic.texture
			m_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			m_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			mini.add_child(m_tr)
			_hero_gear_overlay_box.add_child(mini)

	var frame_col := Color(0.78, 0.50, 1.0, 1.0) if rare_glow else (Color(1.0, 0.82, 0.32, 1.0) if eq_cnt > 0 else Color(0.60, 0.52, 0.32, 0.85))
	_hero_frame.add_theme_stylebox_override("panel", _dark_sb(Color(0.05, 0.05, 0.08, 1.0), frame_col))

	# Filtre butonları
	for fk in _filter_btns.keys():
		var fb := _filter_btns[fk] as Button
		if str(fk) == _inv_filter:
			_style_btn(fb, Color(0.50, 0.34, 0.10, 0.98), Color(1.0, 0.84, 0.34, 1.0), Color(1.0, 0.96, 0.82))
		else:
			_style_btn(fb, Color(0.14, 0.13, 0.20, 0.95), Color(0.45, 0.44, 0.56, 0.85), Color(0.84, 0.86, 0.90))

	# Envanter listesi (takılı eşyalar ASLA görünmez)
	for ch in _inv_grid.get_children():
		ch.queue_free()
	var unequipped: Array[Dictionary] = lm.call("get_unequipped_items")
	var filtered: Array[Dictionary] = []
	for it in unequipped:
		var st := str(it.get("slot_type", ""))
		if _inv_filter == "battle" and not (st in LordModelScript.BATTLE_DROP_SLOTS):
			continue
		if _inv_filter == "accessory" and not (st in LordModelScript.ACCESSORY_SLOTS):
			continue
		filtered.append(it)

	_empty_inv_lbl.visible = filtered.is_empty()
	for it in filtered:
		var iid := str(it.get("id", ""))
		var plus := int(it.get("plus", 0))
		var rar := str(it.get("rarity", "common"))
		var rc := LordModelScript.rarity_color(rar)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 92)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_btn(btn, Color(0.11, 0.10, 0.16, 0.98), rc, Color(1, 1, 1))
		btn.pressed.connect(func(): _open_item_detail(iid))

		var hb := HBoxContainer.new()
		hb.set_anchors_preset(Control.PRESET_FULL_RECT)
		hb.add_theme_constant_override("separation", 10)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(hb)

		var pad := Control.new()
		pad.custom_minimum_size = Vector2(6, 0)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(pad)

		var ic := TextureRect.new()
		ic.texture = load(LordModelScript.icon_path_for(str(it.get("slot_type", "sword")))) as Texture2D
		ic.custom_minimum_size = Vector2(64, 64)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(ic)

		var tx_vb := VBoxContainer.new()
		tx_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tx_vb.alignment = BoxContainer.ALIGNMENT_CENTER
		tx_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(tx_vb)

		var nl := Label.new()
		nl.text = "+%d %s [%s]" % [plus, str(it.get("name", "Ekipman")), LordModelScript.rarity_label(rar)]
		nl.clip_text = true
		nl.add_theme_font_override("font", FontNunitoBold)
		nl.add_theme_font_size_override("font_size", 19)
		nl.add_theme_color_override("font_color", rc)
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tx_vb.add_child(nl)

		var sl := Label.new()
		sl.text = LordModelScript.format_item_short_bonus(it)
		sl.clip_text = true
		sl.add_theme_font_override("font", FontNunitoSemiBold)
		sl.add_theme_font_size_override("font_size", 16)
		sl.add_theme_color_override("font_color", Color(0.86, 0.88, 0.92))
		sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tx_vb.add_child(sl)

		btn.text = ""
		_inv_grid.add_child(btn)


func _on_slot_pressed(slot_key: String) -> void:
	_selected_slot_key = slot_key
	var lm := _lord_mgr()
	if lm == null or _slot_picker_overlay == null:
		return
	var sdef := LordModelScript.get_slot_def(slot_key)
	var title := _slot_picker_overlay.find_child("PickerTitle", true, false) as Label
	var list_vb := _slot_picker_overlay.find_child("PickerList", true, false) as VBoxContainer
	for c in list_vb.get_children():
		c.queue_free()

	var equipped_item: Dictionary = lm.call("get_equipped_item", slot_key)
	title.text = "🛡️ %s Slotu (%s)" % [str(sdef.get("name", slot_key)), LordModelScript.slot_type_name(str(sdef.get("slot_type", "")))]

	if not equipped_item.is_empty():
		var cur_lbl := Label.new()
		cur_lbl.text = "Takılı: +%d %s · %s" % [int(equipped_item.get("plus", 0)), str(equipped_item.get("name", "")), LordModelScript.format_item_short_bonus(equipped_item)]
		cur_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cur_lbl.add_theme_font_override("font", FontNunitoBold)
		cur_lbl.add_theme_font_size_override("font_size", 20)
		cur_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.45))
		list_vb.add_child(cur_lbl)

		var btn_unequip := Button.new()
		btn_unequip.text = "📤 Eşyayı Çıkar (Envantere Geri Al)"
		btn_unequip.custom_minimum_size = Vector2(0, 56)
		_style_btn(btn_unequip, Color(0.36, 0.16, 0.16, 0.98), Color(0.95, 0.50, 0.48, 1.0), Color(1, 0.94, 0.94))
		btn_unequip.pressed.connect(func():
			lm.call("unequip_slot", slot_key)
			_slot_picker_overlay.hide()
			_refresh_all()
		)
		list_vb.add_child(btn_unequip)

	var matching: Array[Dictionary] = lm.call("get_unequipped_items", str(sdef.get("slot_type", "")))
	if matching.is_empty():
		var empty_l := Label.new()
		empty_l.text = "Bu slota takılabilecek boşta eşya yok."
		empty_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_l.add_theme_font_override("font", FontNunitoSemiBold)
		empty_l.add_theme_font_size_override("font_size", 19)
		empty_l.add_theme_color_override("font_color", Color(0.75, 0.74, 0.80))
		list_vb.add_child(empty_l)
	else:
		for it in matching:
			var iid := str(it.get("id", ""))
			var rar := str(it.get("rarity", "common"))
			var rc := LordModelScript.rarity_color(rar)
			var b := Button.new()
			b.text = "⚔️ Kuşan: +%d %s (%s)" % [int(it.get("plus", 0)), str(it.get("name", "")), LordModelScript.format_item_short_bonus(it)]
			b.custom_minimum_size = Vector2(0, 58)
			_style_btn(b, Color(0.14, 0.24, 0.18, 0.98), rc, Color(0.98, 0.96, 0.88))
			b.pressed.connect(func():
				lm.call("equip_item", slot_key, iid)
				_slot_picker_overlay.hide()
				_refresh_all()
			)
			list_vb.add_child(b)

	_slot_picker_overlay.show()


func _open_item_detail(item_id: String) -> void:
	_detail_item_id = item_id
	var lm := _lord_mgr()
	if lm == null or _item_detail_overlay == null:
		return
	var item: Dictionary = lm.call("get_item_by_id", item_id)
	if item.is_empty():
		return

	var st_type := str(item.get("slot_type", "sword"))
	var rar := str(item.get("rarity", "common"))
	var plus := int(item.get("plus", 0))
	var stats := LordModelScript.compute_item_stats(item)
	var ld: Dictionary = lm.call("get_lord_state")
	var eq_slot := LordModelScript.equipped_slot_of(ld, item_id)

	var icon_tr := _item_detail_overlay.find_child("DetailIcon", true, false) as TextureRect
	var name_l := _item_detail_overlay.find_child("DetailName", true, false) as Label
	var body_l := _item_detail_overlay.find_child("DetailBody", true, false) as Label
	var act_hb := _item_detail_overlay.find_child("DetailActions", true, false) as HBoxContainer

	icon_tr.texture = load(LordModelScript.icon_path_for(st_type)) as Texture2D
	name_l.text = "+%d %s" % [plus, str(item.get("name", "Ekipman"))]
	name_l.add_theme_color_override("font_color", LordModelScript.rarity_color(rar))

	var slot_txt := str(LordModelScript.get_slot_def(eq_slot).get("name", eq_slot)) if not eq_slot.is_empty() else ("%s (Envanterde)" % LordModelScript.slot_type_name(st_type))
	var lines: Array[String] = [
		"Nadirlik: %s" % LordModelScript.rarity_label(rar),
		"Slot: %s · Seviye: +%d / +8" % [slot_txt, plus],
		"Saldırı Bonusu: +%d (%%%.1f)" % [int(stats.get("attack", 0)), float(stats.get("attack_pct", 0.0))],
		"Savunma Bonusu: +%d (%%%.1f)" % [int(stats.get("defense", 0)), float(stats.get("defense_pct", 0.0))],
		"Lord HP Katkısı: +%d" % int(stats.get("hp", 0)),
	]
	var ab_t := str(stats.get("army_bonus_type", ""))
	if not ab_t.is_empty():
		lines.append("Ordu Bonusu: %s +%%%.1f" % [LordModelScript.army_bonus_label(ab_t), float(stats.get("army_bonus_pct", 0.0))])
	var src := str(item.get("source", ""))
	if not src.is_empty():
		lines.append("Kaynak: %s" % src)
	body_l.text = "\n".join(lines)

	for ch in act_hb.get_children():
		ch.queue_free()

	if eq_slot.is_empty():
		# Boş olan ilk uygun slotu bul (örn. earring_1/earring_2, ring_1/ring_2)
		var target_slots: Array[String] = []
		for sdef in LordModelScript.SLOTS:
			if str(sdef["slot_type"]) == st_type:
				target_slots.append(str(sdef["key"]))
		var chosen_slot := target_slots[0] if not target_slots.is_empty() else st_type
		for ts in target_slots:
			if (lm.call("get_equipped_item", ts) as Dictionary).is_empty():
				chosen_slot = ts
				break
		var btn_eq := Button.new()
		btn_eq.text = "⚔️ Kuşan (%s)" % str(LordModelScript.get_slot_def(chosen_slot).get("name", chosen_slot))
		btn_eq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_eq.custom_minimum_size = Vector2(0, 56)
		_style_btn(btn_eq, Color(0.16, 0.42, 0.24, 0.98), Color(0.55, 0.94, 0.65, 1.0), Color(1, 1, 1))
		btn_eq.pressed.connect(func():
			lm.call("equip_item", chosen_slot, item_id)
			_item_detail_overlay.hide()
			_refresh_all()
		)
		act_hb.add_child(btn_eq)

		var btn_upg := Button.new()
		btn_upg.text = "⚒️ Geliştir"
		btn_upg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_upg.custom_minimum_size = Vector2(0, 56)
		_style_btn(btn_upg, Color(0.54, 0.30, 0.08, 0.98), Color(1.0, 0.84, 0.34, 1.0), Color(1, 0.96, 0.84))
		btn_upg.pressed.connect(func():
			_item_detail_overlay.hide()
			open_upgrade_modal(item_id)
		)
		act_hb.add_child(btn_upg)
	else:
		var btn_un := Button.new()
		btn_un.text = "📤 Slottan Çıkar"
		btn_un.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_un.custom_minimum_size = Vector2(0, 56)
		_style_btn(btn_un, Color(0.36, 0.16, 0.16, 0.98), Color(0.95, 0.50, 0.48, 1.0), Color(1, 0.94, 0.94))
		btn_un.pressed.connect(func():
			lm.call("unequip_slot", eq_slot)
			_item_detail_overlay.hide()
			_refresh_all()
		)
		act_hb.add_child(btn_un)

	_item_detail_overlay.show()


func _build_slot_picker_overlay() -> void:
	_slot_picker_overlay = Control.new()
	_slot_picker_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_slot_picker_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_slot_picker_overlay.hide()
	_root_ctrl.add_child(_slot_picker_overlay)

	var d := ColorRect.new()
	d.set_anchors_preset(Control.PRESET_FULL_RECT)
	d.color = Color(0, 0, 0, 0.72)
	d.mouse_filter = Control.MOUSE_FILTER_STOP
	_slot_picker_overlay.add_child(d)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_slot_picker_overlay.add_child(cc)

	var pnl := PanelContainer.new()
	pnl.custom_minimum_size = Vector2(760, 0)
	pnl.add_theme_stylebox_override("panel", _dark_sb(Color(0.10, 0.09, 0.15, 0.99), Color(0.95, 0.78, 0.36, 1.0)))
	cc.add_child(pnl)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	pnl.add_child(vb)

	var hdr := HBoxContainer.new()
	vb.add_child(hdr)

	var title := Label.new()
	title.name = "PickerTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_override("font", FontCinzelBold)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	hdr.add_child(title)

	var b_close := Button.new()
	b_close.text = "✕"
	b_close.custom_minimum_size = Vector2(50, 48)
	_style_btn(b_close, Color(0.32, 0.14, 0.16, 0.96), Color(0.92, 0.48, 0.48, 1.0), Color(1, 0.92, 0.92))
	b_close.pressed.connect(func(): _slot_picker_overlay.hide())
	hdr.add_child(b_close)

	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 420)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(sc)

	var list_vb := VBoxContainer.new()
	list_vb.name = "PickerList"
	list_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vb.add_theme_constant_override("separation", 10)
	sc.add_child(list_vb)


func _build_item_detail_overlay() -> void:
	_item_detail_overlay = Control.new()
	_item_detail_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_item_detail_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_item_detail_overlay.hide()
	_root_ctrl.add_child(_item_detail_overlay)

	var d := ColorRect.new()
	d.set_anchors_preset(Control.PRESET_FULL_RECT)
	d.color = Color(0, 0, 0, 0.72)
	d.mouse_filter = Control.MOUSE_FILTER_STOP
	_item_detail_overlay.add_child(d)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_item_detail_overlay.add_child(cc)

	var pnl := PanelContainer.new()
	pnl.custom_minimum_size = Vector2(740, 0)
	pnl.add_theme_stylebox_override("panel", _dark_sb(Color(0.10, 0.09, 0.15, 0.99), Color(0.95, 0.78, 0.36, 1.0)))
	cc.add_child(pnl)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	pnl.add_child(vb)

	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 12)
	vb.add_child(hdr)

	var ic := TextureRect.new()
	ic.name = "DetailIcon"
	ic.custom_minimum_size = Vector2(88, 88)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hdr.add_child(ic)

	var nl := Label.new()
	nl.name = "DetailName"
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nl.add_theme_font_override("font", FontCinzelBold)
	nl.add_theme_font_size_override("font_size", 26)
	hdr.add_child(nl)

	var b_close := Button.new()
	b_close.text = "✕"
	b_close.custom_minimum_size = Vector2(52, 50)
	_style_btn(b_close, Color(0.32, 0.14, 0.16, 0.96), Color(0.92, 0.48, 0.48, 1.0), Color(1, 0.92, 0.92))
	b_close.pressed.connect(func(): _item_detail_overlay.hide())
	hdr.add_child(b_close)

	var body_l := Label.new()
	body_l.name = "DetailBody"
	body_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_l.add_theme_font_override("font", FontNunitoBold)
	body_l.add_theme_font_size_override("font_size", 22)
	body_l.add_theme_color_override("font_color", Color(0.94, 0.94, 0.98))
	vb.add_child(body_l)

	var act_hb := HBoxContainer.new()
	act_hb.name = "DetailActions"
	act_hb.add_theme_constant_override("separation", 12)
	vb.add_child(act_hb)


func _dark_sb(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(12)
	return sb


func _style_btn(btn: Button, bg: Color, border: Color, fg: Color) -> void:
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_override("font", FontNunitoBold)
	btn.add_theme_font_size_override("font_size", 21)
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(10)
	var hov := sb.duplicate() as StyleBoxFlat
	hov.bg_color = bg.lightened(0.12)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", hov)
	btn.add_theme_stylebox_override("pressed", hov)
