extends PanelContainer
## ResourceBar — Üst kaynak ve köy durumu çubuğu (Taht ve Kılıç / A-ARAYUZ).

const Palette := preload("res://themes/Palette.gd")
const RulesEngineScript := preload("res://scripts/rules/RulesEngine.gd")
const VillageModelScript := preload("res://scripts/model/VillageModel.gd")
const FontNunitoBold := preload("res://assets/fonts/Nunito-Bold.ttf")

var village_name_label: Label = null
var points_label: Label = null
var wood_label: Label = null
var stone_label: Label = null
var iron_label: Label = null
var storage_bar: ProgressBar = null
var storage_label: Label = null
var citizens_label: Label = null
var realm_label: Label = null
var btn_prev: Button = null
var btn_next: Button = null


func _ensure_nodes() -> void:
	if wood_label == null:
		village_name_label = find_child("VillageName", true, false) as Label
		points_label = find_child("Points", true, false) as Label
		wood_label = find_child("WoodLabel", true, false) as Label
		stone_label = find_child("StoneLabel", true, false) as Label
		iron_label = find_child("IronLabel", true, false) as Label
		storage_bar = find_child("StorageBar", true, false) as ProgressBar
		storage_label = find_child("StorageLabel", true, false) as Label
		citizens_label = find_child("CitizensLabel", true, false) as Label
		realm_label = find_child("RealmLabel", true, false) as Label
		btn_prev = find_child("BtnPrevVillage", true, false) as Button
		btn_next = find_child("BtnNextVillage", true, false) as Button
		_style_nav_btn(btn_prev)
		_style_nav_btn(btn_next)


func _style_nav_btn(b: Button) -> void:
	if b == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.20, 0.16, 0.24, 0.95)
	sb.border_color = Color(0.92, 0.78, 0.40, 0.95)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	b.add_theme_stylebox_override("normal", sb)
	var h_sb = sb.duplicate() as StyleBoxFlat
	h_sb.bg_color = Color(0.35, 0.28, 0.42, 1.0)
	b.add_theme_stylebox_override("hover", h_sb)
	b.add_theme_stylebox_override("pressed", h_sb)
	b.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))


func _ready() -> void:
	_ensure_nodes()
	if btn_prev != null and not btn_prev.pressed.is_connected(_on_prev_village_pressed):
		btn_prev.pressed.connect(_on_prev_village_pressed)
	if btn_next != null and not btn_next.pressed.is_connected(_on_next_village_pressed):
		btn_next.pressed.connect(_on_next_village_pressed)

	if village_name_label != null:
		village_name_label.mouse_filter = Control.MOUSE_FILTER_STOP
		village_name_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		if not village_name_label.gui_input.is_connected(_on_village_name_gui_input):
			village_name_label.gui_input.connect(_on_village_name_gui_input)

	var bus = Engine.get_main_loop().root.get_node_or_null("EventBus") if Engine.get_main_loop() is SceneTree else null
	if bus != null:
		if bus.has_signal("resources_changed") and not bus.resources_changed.is_connected(_on_resources_changed):
			bus.resources_changed.connect(_on_resources_changed)
		if bus.has_signal("building_completed") and not bus.building_completed.is_connected(_on_building_completed):
			bus.building_completed.connect(_on_building_completed)
		if bus.has_signal("realm_of_power_changed") and not bus.realm_of_power_changed.is_connected(_on_realm_changed):
			bus.realm_of_power_changed.connect(_on_realm_changed)
		if bus.has_signal("state_changed") and not bus.state_changed.is_connected(refresh):
			bus.state_changed.connect(refresh)
	refresh()


func _on_village_name_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
		if gs != null and gs.has_method("get_player_villages") and gs.get_player_villages().size() > 1:
			_show_village_switcher_modal()
		else:
			_show_rename_modal()


func _on_prev_village_pressed() -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs != null and gs.has_method("cycle_active_village"):
		gs.cycle_active_village(-1)
		var wm = Engine.get_main_loop().root.get_node_or_null("WorldManager") if Engine.get_main_loop() is SceneTree else null
		if wm != null and wm.has_method("save_active_world"):
			wm.save_active_world()
		refresh()


func _on_next_village_pressed() -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs != null and gs.has_method("cycle_active_village"):
		gs.cycle_active_village(1)
		var wm = Engine.get_main_loop().root.get_node_or_null("WorldManager") if Engine.get_main_loop() is SceneTree else null
		if wm != null and wm.has_method("save_active_world"):
			wm.save_active_world()
		refresh()


func _on_resources_changed(village_id: int) -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs != null and gs.has_active_village() and village_id != gs.active_village_id:
		return
	refresh()


func _on_building_completed(village_id: int, _key: String, _level: int) -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs != null and gs.has_active_village() and village_id != gs.active_village_id:
		return
	refresh()


func _on_realm_changed(village_id: int, _val: int) -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs != null and gs.has_active_village() and village_id != gs.active_village_id:
		return
	refresh()


func _get_game_state() -> Node:
	if is_inside_tree() and has_node("/root/GameState"):
		return get_node("/root/GameState")
	if get_parent() != null and get_parent().has_node("GameState"):
		return get_parent().get_node("GameState")
	var loop = Engine.get_main_loop()
	if loop is SceneTree:
		var root_node = (loop as SceneTree).root
		if root_node != null:
			if root_node.has_node("GameState"):
				return root_node.get_node("GameState")
			var GSScript = load("res://autoload/GameState.gd")
			for child in root_node.get_children():
				if child.name == "GameState" or child.name.contains("GameState") or (GSScript != null and child.get_script() == GSScript):
					return child
	return null


func refresh() -> void:
	_ensure_nodes()
	var gs = _get_game_state()
	if gs == null or not gs.has_active_village():
		return

	var v: Dictionary = gs.get_active_village()
	var p_vills: Array = gs.get_player_villages() if gs.has_method("get_player_villages") else []
	var total_vills := p_vills.size()
	var cur_idx := 1
	for i in range(total_vills):
		if int(p_vills[i].get("id", -1)) == gs.active_village_id:
			cur_idx = i + 1
			break

	if btn_prev != null:
		btn_prev.visible = (total_vills > 1)
	if btn_next != null:
		btn_next.visible = (total_vills > 1)

	if village_name_label != null:
		var auth = Engine.get_main_loop().root.get_node_or_null("AuthManager") if Engine.get_main_loop() is SceneTree else null
		var user_name := ""
		if auth != null and auth.is_logged_in and not auth.display_name.is_empty():
			user_name = auth.display_name
			gs.player["name"] = user_name
		else:
			user_name = str(gs.player.get("name", ""))
		if user_name.is_empty() or user_name == "Kral":
			user_name = "Lord Gorkem"
			gs.player["name"] = user_name

		if str(v.get("owner", "")) == "Kral" or str(v.get("owner", "")).is_empty():
			v["owner"] = user_name

		var count_str := " [%d/%d] ▾" % [cur_idx, total_vills] if total_vills > 1 else ""
		var v_name := str(v.get("name", "Başkent"))
		village_name_label.text = "%s | %s (%d|%d)%s" % [user_name, v_name, int(v.get("x", 0)), int(v.get("y", 0)), count_str]
		village_name_label.tooltip_text = "Köy Değiştir / İsim Düzenle" if total_vills > 1 else "Köy Adını Düzenle"

	if points_label != null:
		points_label.text = "%d P" % int(v.get("points", 0))
		points_label.tooltip_text = "Köy Puanı: %d" % int(v.get("points", 0))

	var res: Dictionary = v.get("resources", {})
	if wood_label != null:
		wood_label.text = str(int(res.get("wood", 0)))
	if stone_label != null:
		stone_label.text = str(int(res.get("stone", 0)))
	if iron_label != null:
		iron_label.text = str(int(res.get("iron", 0)))

	var storage_lvl: int = int(v.get("buildings", {}).get("storage", 1))
	var storage_cap: int = RulesEngineScript.storage_capacity(storage_lvl)
	var max_res: int = maxi(int(res.get("wood", 0)), maxi(int(res.get("stone", 0)), int(res.get("iron", 0))))

	if storage_bar != null:
		storage_bar.max_value = storage_cap
		storage_bar.value = max_res
	if storage_label != null:
		storage_label.text = str(storage_cap)

	var farm_lvl: int = int(v.get("buildings", {}).get("farm", 1))
	var max_pop: int = RulesEngineScript.max_population(farm_lvl)
	var free_pop: int = VillageModelScript.population_free(v)
	if citizens_label != null:
		citizens_label.text = "👥 %d/%d" % [free_pop, max_pop]
		citizens_label.tooltip_text = "Vatandaş Durumu: %d Boş / %d Kapasite" % [free_pop, max_pop]

	if realm_label != null:
		var cur_realm: int = int(v.get("realm_of_power", 0))
		var max_realm: int = int(v.get("points", 0))
		realm_label.text = "⚡ %d" % cur_realm
		realm_label.tooltip_text = "Güç Alanı: %d / %d (Mevcut / Tavan). Köy Puanı: %d" % [cur_realm, max_realm, max_realm]


var _rename_modal: CanvasLayer = null
var _switcher_modal: CanvasLayer = null


func _show_village_switcher_modal() -> void:
	if _switcher_modal != null and is_instance_valid(_switcher_modal):
		_switcher_modal.queue_free()

	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null or not gs.has_method("get_player_villages"):
		return
	var player_villages: Array = gs.get_player_villages()
	if player_villages.size() <= 1:
		_show_rename_modal()
		return

	var vp_size := get_viewport().get_visible_rect().size if is_inside_tree() and get_viewport() != null else Vector2(1080.0, 1920.0)
	if vp_size.x < 100.0 or vp_size.y < 100.0:
		vp_size = Vector2(1080.0, 1920.0)
	var card_w := clampf(vp_size.x - 64.0, 460.0, 860.0)
	var card_h := clampf(vp_size.y - 260.0, 380.0, 820.0)

	_switcher_modal = CanvasLayer.new()
	_switcher_modal.name = "VillageSwitcherModal"
	_switcher_modal.layer = 135

	var root_ctrl := Control.new()
	root_ctrl.name = "ModalRoot"
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	_switcher_modal.add_child(root_ctrl)
	root_ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.06, 0.84)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			_switcher_modal.queue_free()
	)
	root_ctrl.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	root_ctrl.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(card_w, card_h)
	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color = Color(0.11, 0.09, 0.15, 0.98)
	card_sb.border_color = Color(0.88, 0.74, 0.42, 1.0)
	card_sb.set_border_width_all(3)
	card_sb.border_width_top = 5
	card_sb.set_corner_radius_all(18)
	card_sb.set_content_margin_all(22)
	card.add_theme_stylebox_override("panel", card_sb)
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	card.add_child(vb)

	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 10)
	vb.add_child(hdr)

	var title_lbl := Label.new()
	title_lbl.text = "🏰 Köylerim (%d Köy)" % player_villages.size()
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var FontCinzelBold = load("res://assets/fonts/Cinzel-Bold.ttf")
	if FontCinzelBold != null:
		title_lbl.add_theme_font_override("font", FontCinzelBold)
	title_lbl.add_theme_font_size_override("font_size", 28)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65))
	hdr.add_child(title_lbl)

	var btn_x := Button.new()
	btn_x.text = "✕"
	btn_x.custom_minimum_size = Vector2(46, 46)
	btn_x.add_theme_font_override("font", FontNunitoBold)
	btn_x.add_theme_font_size_override("font_size", 22)
	btn_x.pressed.connect(func(): _switcher_modal.queue_free())
	hdr.add_child(btn_x)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(scroll)

	var list_vb := VBoxContainer.new()
	list_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vb.add_theme_constant_override("separation", 10)
	scroll.add_child(list_vb)

	for pv in player_villages:
		if typeof(pv) != TYPE_DICTIONARY:
			continue
		var pvd := pv as Dictionary
		var vid := int(pvd.get("id", -1))
		var vname := str(pvd.get("name", "Köy"))
		var vx := int(pvd.get("x", 0))
		var vy := int(pvd.get("y", 0))
		var vpts := int(pvd.get("points", 0))
		var is_active := (vid == int(gs.active_village_id))
		var res_d: Dictionary = pvd.get("resources", {}) if typeof(pvd.get("resources")) == TYPE_DICTIONARY else {}
		var unit_d: Dictionary = pvd.get("units", {}) if typeof(pvd.get("units")) == TYPE_DICTIONARY else {}
		var total_troops := 0
		for uk in unit_d.keys():
			total_troops += int(unit_d.get(uk, 0))

		var row_panel := PanelContainer.new()
		var r_sb := StyleBoxFlat.new()
		r_sb.bg_color = Color(0.22, 0.18, 0.12, 0.96) if is_active else Color(0.16, 0.14, 0.21, 0.94)
		r_sb.border_color = Color(0.95, 0.80, 0.35, 1.0) if is_active else Color(0.45, 0.40, 0.55, 0.70)
		r_sb.set_border_width_all(2)
		r_sb.set_corner_radius_all(12)
		r_sb.set_content_margin_all(14)
		row_panel.add_theme_stylebox_override("panel", r_sb)
		list_vb.add_child(row_panel)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row_panel.add_child(row)

		var info_vb := VBoxContainer.new()
		info_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vb.add_theme_constant_override("separation", 4)
		row.add_child(info_vb)

		var info_lbl := Label.new()
		var active_badge := " ★ AKTİF" if is_active else ""
		info_lbl.text = "%s (%d|%d) — %d Puan%s" % [vname, vx, vy, vpts, active_badge]
		info_lbl.clip_text = true
		info_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		info_lbl.add_theme_font_override("font", FontNunitoBold)
		info_lbl.add_theme_font_size_override("font_size", 22)
		info_lbl.add_theme_color_override("font_color", Color(1.0, 0.94, 0.72) if is_active else Color(0.94, 0.91, 0.86))
		info_vb.add_child(info_lbl)

		var sub_stats := Label.new()
		sub_stats.text = "Odun: %d  |  Taş: %d  |  Demir: %d  |  Asker: %d" % [
			int(res_d.get("wood", 0)), int(res_d.get("stone", 0)), int(res_d.get("iron", 0)), total_troops
		]
		sub_stats.clip_text = true
		sub_stats.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		sub_stats.add_theme_font_override("font", FontNunitoBold)
		sub_stats.add_theme_font_size_override("font_size", 17)
		sub_stats.add_theme_color_override("font_color", Color(0.76, 0.82, 0.88))
		info_vb.add_child(sub_stats)

		var btn_go := Button.new()
		btn_go.text = "✓ AKTİF" if is_active else "Köye Geç"
		btn_go.disabled = is_active
		btn_go.custom_minimum_size = Vector2(146, 52)
		btn_go.add_theme_font_override("font", FontNunitoBold)
		btn_go.add_theme_font_size_override("font_size", 20)
		btn_go.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var g_sb := StyleBoxFlat.new()
		g_sb.bg_color = Color(0.22, 0.48, 0.26, 0.95) if not is_active else Color(0.28, 0.25, 0.16, 0.95)
		g_sb.border_color = Color(0.55, 0.90, 0.55, 1.0) if not is_active else Color(0.90, 0.78, 0.35, 1.0)
		g_sb.set_border_width_all(2)
		g_sb.set_corner_radius_all(10)
		btn_go.add_theme_stylebox_override("normal", g_sb)
		btn_go.add_theme_stylebox_override("disabled", g_sb)
		btn_go.add_theme_color_override("font_color", Color(1.0, 0.98, 0.90))
		btn_go.pressed.connect(func():
			if gs.has_method("set_active_village"):
				gs.set_active_village(vid)
			var wm = Engine.get_main_loop().root.get_node_or_null("WorldManager") if Engine.get_main_loop() is SceneTree else null
			if wm != null and wm.has_method("save_active_world"):
				wm.save_active_world()
			refresh()
			_switcher_modal.queue_free()
		)
		row.add_child(btn_go)

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 14)
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(foot)

	var btn_rename := Button.new()
	btn_rename.text = "✏️ Aktif Köyün Adını Değiştir"
	btn_rename.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_rename.custom_minimum_size = Vector2(240, 52)
	btn_rename.add_theme_font_override("font", FontNunitoBold)
	btn_rename.add_theme_font_size_override("font_size", 20)
	var rn_sb := StyleBoxFlat.new()
	rn_sb.bg_color = Color(0.24, 0.20, 0.32, 0.95)
	rn_sb.border_color = Color(0.85, 0.72, 0.42, 0.95)
	rn_sb.set_border_width_all(2)
	rn_sb.set_corner_radius_all(10)
	btn_rename.add_theme_stylebox_override("normal", rn_sb)
	btn_rename.add_theme_color_override("font_color", Color(1.0, 0.94, 0.78))
	btn_rename.pressed.connect(func():
		_switcher_modal.queue_free()
		_show_rename_modal()
	)
	foot.add_child(btn_rename)

	var btn_close := Button.new()
	btn_close.text = "Kapat"
	btn_close.custom_minimum_size = Vector2(140, 52)
	btn_close.add_theme_font_override("font", FontNunitoBold)
	btn_close.add_theme_font_size_override("font_size", 20)
	var cl_sb := StyleBoxFlat.new()
	cl_sb.bg_color = Color(0.42, 0.16, 0.16, 0.95)
	cl_sb.border_color = Color(0.85, 0.38, 0.38, 1.0)
	cl_sb.set_border_width_all(2)
	cl_sb.set_corner_radius_all(10)
	btn_close.add_theme_stylebox_override("normal", cl_sb)
	btn_close.add_theme_color_override("font_color", Color(1.0, 0.95, 0.95))
	btn_close.pressed.connect(func(): _switcher_modal.queue_free())
	foot.add_child(btn_close)

	var root = get_tree().root
	if root != null:
		root.add_child(_switcher_modal)
	else:
		add_child(_switcher_modal)

func _show_rename_modal() -> void:
	if _rename_modal != null and is_instance_valid(_rename_modal):
		_rename_modal.queue_free()

	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null or not gs.has_active_village():
		return
	var v: Dictionary = gs.get_active_village()
	var cur_name := str(v.get("name", "Başkent"))

	var vp_size := get_viewport().get_visible_rect().size if is_inside_tree() and get_viewport() != null else Vector2(1080.0, 1920.0)
	if vp_size.x < 100.0 or vp_size.y < 100.0:
		vp_size = Vector2(1080.0, 1920.0)

	_rename_modal = CanvasLayer.new()
	_rename_modal.name = "RenameVillageModal"
	_rename_modal.layer = 140

	var root_ctrl := Control.new()
	root_ctrl.name = "ModalRoot"
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	_rename_modal.add_child(root_ctrl)
	root_ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Koyu arkaplan karartması
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.06, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root_ctrl.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Ortalanmış kart
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	root_ctrl.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(clampf(vp_size.x - 80.0, 440.0, 680.0), 360)
	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color = Color(0.12, 0.10, 0.16, 0.98)
	card_sb.border_color = Color(0.88, 0.74, 0.42, 1.0)
	card_sb.set_border_width_all(3)
	card_sb.border_width_top = 5
	card_sb.set_corner_radius_all(18)
	card_sb.set_content_margin_all(28)
	card_sb.shadow_color = Color(0, 0, 0, 0.6)
	card_sb.shadow_size = 18
	card.add_theme_stylebox_override("panel", card_sb)
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 20)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vb)

	# Başlık
	var title_lbl := Label.new()
	title_lbl.text = "✏️ Köy Adını Değiştir"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var FontCinzelBold = load("res://assets/fonts/Cinzel-Bold.ttf")
	if FontCinzelBold != null:
		title_lbl.add_theme_font_override("font", FontCinzelBold)
	title_lbl.add_theme_font_size_override("font_size", 30)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65))
	vb.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "Köyünüz için yeni bir isim belirleyin:"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_override("font", FontNunitoBold)
	sub_lbl.add_theme_font_size_override("font_size", 20)
	sub_lbl.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
	vb.add_child(sub_lbl)

	var edit := LineEdit.new()
	edit.text = cur_name
	edit.placeholder_text = "Köy İsmi"
	edit.custom_minimum_size = Vector2(0, 56)
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.add_theme_font_override("font", FontNunitoBold)
	edit.add_theme_font_size_override("font_size", 24)
	edit.add_theme_color_override("font_color", Color(1.0, 0.96, 0.90))
	edit.add_theme_color_override("font_selected_color", Color(1.0, 1.0, 1.0))
	edit.add_theme_color_override("font_placeholder_color", Color(0.60, 0.55, 0.50))
	edit.add_theme_color_override("caret_color", Color(1.0, 0.85, 0.40))
	edit.add_theme_color_override("selection_color", Color(0.28, 0.42, 0.72, 0.90))
	edit.max_length = 30
	var edit_sb := StyleBoxFlat.new()
	edit_sb.bg_color = Color(0.08, 0.07, 0.10, 0.95)
	edit_sb.border_color = Color(0.85, 0.70, 0.40, 0.95)
	edit_sb.set_border_width_all(2)
	edit_sb.set_corner_radius_all(10)
	edit_sb.set_content_margin_all(10)
	edit.add_theme_stylebox_override("normal", edit_sb)
	edit.add_theme_stylebox_override("focus", edit_sb)
	vb.add_child(edit)

	# Butonlar
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var btn_cancel := Button.new()
	btn_cancel.text = "İptal"
	btn_cancel.custom_minimum_size = Vector2(160, 52)
	btn_cancel.add_theme_font_override("font", FontNunitoBold)
	btn_cancel.add_theme_font_size_override("font_size", 22)
	btn_cancel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var c_sb := StyleBoxFlat.new()
	c_sb.bg_color = Color(0.42, 0.16, 0.16, 0.95)
	c_sb.border_color = Color(0.85, 0.38, 0.38, 1.0)
	c_sb.set_border_width_all(2)
	c_sb.set_corner_radius_all(10)
	btn_cancel.add_theme_stylebox_override("normal", c_sb)

	var c_hover := c_sb.duplicate() as StyleBoxFlat
	c_hover.bg_color = Color(0.55, 0.22, 0.22, 1.0)
	c_hover.border_color = Color(1.0, 0.50, 0.50, 1.0)
	btn_cancel.add_theme_stylebox_override("hover", c_hover)

	var c_pressed := c_sb.duplicate() as StyleBoxFlat
	c_pressed.bg_color = Color(0.32, 0.12, 0.12, 1.0)
	btn_cancel.add_theme_stylebox_override("pressed", c_pressed)
	btn_cancel.add_theme_stylebox_override("focus", c_hover)

	btn_cancel.add_theme_color_override("font_color", Color(1.0, 0.95, 0.95))
	btn_cancel.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	btn_cancel.add_theme_color_override("font_pressed_color", Color(0.92, 0.88, 0.88))
	btn_cancel.add_theme_color_override("font_focus_color", Color(1.0, 0.95, 0.95))

	btn_cancel.pressed.connect(func():
		_rename_modal.queue_free()
	)
	hbox.add_child(btn_cancel)

	var btn_save := Button.new()
	btn_save.text = "💾 Kaydet"
	btn_save.custom_minimum_size = Vector2(160, 52)
	btn_save.add_theme_font_override("font", FontNunitoBold)
	btn_save.add_theme_font_size_override("font_size", 22)
	btn_save.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var s_sb := StyleBoxFlat.new()
	s_sb.bg_color = Color(0.88, 0.72, 0.36, 1.0)
	s_sb.border_color = Color(1.0, 0.90, 0.55, 1.0)
	s_sb.set_border_width_all(2)
	s_sb.set_corner_radius_all(10)
	btn_save.add_theme_stylebox_override("normal", s_sb)

	var s_hover := s_sb.duplicate() as StyleBoxFlat
	s_hover.bg_color = Color(0.96, 0.82, 0.45, 1.0)
	s_hover.border_color = Color(1.0, 0.95, 0.70, 1.0)
	btn_save.add_theme_stylebox_override("hover", s_hover)

	var s_pressed := s_sb.duplicate() as StyleBoxFlat
	s_pressed.bg_color = Color(0.76, 0.62, 0.28, 1.0)
	btn_save.add_theme_stylebox_override("pressed", s_pressed)
	btn_save.add_theme_stylebox_override("focus", s_hover)

	btn_save.add_theme_color_override("font_color", Color(0.16, 0.10, 0.04))
	btn_save.add_theme_color_override("font_hover_color", Color(0.10, 0.05, 0.02))
	btn_save.add_theme_color_override("font_pressed_color", Color(0.12, 0.08, 0.03))
	btn_save.add_theme_color_override("font_focus_color", Color(0.16, 0.10, 0.04))

	var do_save := func():
		var new_name := edit.text.strip_edges()
		if not new_name.is_empty():
			if gs.has_method("rename_village"):
				gs.rename_village(gs.active_village_id, new_name)
			else:
				v["name"] = new_name
				var sm = Engine.get_main_loop().root.get_node_or_null("SaveManager") if Engine.get_main_loop() is SceneTree else null
				if sm != null:
					sm.save_game()
				gs._emit_state_changed()
			refresh()
		_rename_modal.queue_free()

	btn_save.pressed.connect(do_save)
	edit.text_submitted.connect(func(_t): do_save.call())
	hbox.add_child(btn_save)

	vb.add_child(hbox)

	var root = get_tree().root
	if root != null:
		root.add_child(_rename_modal)
	else:
		add_child(_rename_modal)
	edit.grab_focus()
	edit.select_all()

