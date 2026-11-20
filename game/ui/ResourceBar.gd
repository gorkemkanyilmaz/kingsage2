extends PanelContainer

const DESKTOP_BAR_HEIGHT := 116.0
const EconomyAPI := preload("res://scripts/sim/economy/EconomyAPI.gd")
const RulesEngine := preload("res://scripts/rules/RulesEngine.gd")
const ICON_WOOD: Texture2D = preload("res://assets/sprites/ui/nano_banana/sharp_icon_wood.tres")
const ICON_STONE: Texture2D = preload("res://assets/sprites/ui/nano_banana/sharp_icon_stone.tres")
const ICON_IRON: Texture2D = preload("res://assets/sprites/ui/nano_banana/sharp_icon_iron.tres")
const ICON_CITIZENS: Texture2D = preload("res://assets/sprites/ui/nano_banana/sharp_icon_citizens.tres")
const ICON_STORAGE: Texture2D = preload("res://assets/sprites/ui/nano_banana/sharp_icon_storage.tres")
const FONT_BOLD: Font = preload("res://assets/fonts/Nunito-Bold.ttf")
const FONT_SEMIBOLD: Font = preload("res://assets/fonts/Nunito-SemiBold.ttf")

var top_row: HBoxContainer
var resources_row: HBoxContainer
var vbox_root: VBoxContainer
var village_info_box: HBoxContainer
var island_spacer: Control
var right_wing: HBoxContainer

var village_name_label: Label
var points_box: Control
var points_label: Label
var wood_box: Control
var wood_label: Label
var wood_bar: ProgressBar
var stone_box: Control
var stone_label: Label
var stone_bar: ProgressBar
var iron_box: Control
var iron_label: Label
var iron_bar: ProgressBar
var citizens_box: Control
var citizens_label: Label

var storage_bar: ProgressBar
var storage_label: Label
var realm_label: Label
var btn_prev: Button
var btn_next: Button
var btn_market: Button

var _pb_fill_ok: StyleBoxFlat
var _pb_fill_warn: StyleBoxFlat
var _pb_fill_full: StyleBoxFlat
var _last_bar_height: float = DESKTOP_BAR_HEIGHT
var _switcher_modal: CanvasLayer = null
var _economy_modal: CanvasLayer = null
var _rename_modal: CanvasLayer = null


func _ensure_nodes() -> void:
	if vbox_root == null:
		vbox_root = get_node_or_null("VBox") as VBoxContainer
	if top_row == null:
		top_row = find_child("TopRow", true, false) as HBoxContainer
	if resources_row == null:
		resources_row = find_child("ResourcesRow", true, false) as HBoxContainer
	if village_info_box == null:
		village_info_box = find_child("VillageInfo", true, false) as HBoxContainer
	if island_spacer == null:
		island_spacer = find_child("IslandSpacer", true, false) as Control
	if right_wing == null:
		right_wing = find_child("RightWing", true, false) as HBoxContainer

	if village_name_label == null:
		village_name_label = find_child("VillageName", true, false) as Label
	if points_box == null:
		points_box = find_child("PointsBox", true, false) as Control
	if points_label == null:
		points_label = find_child("Points", true, false) as Label
	if wood_box == null:
		wood_box = find_child("WoodBox", true, false) as Control
	if wood_label == null:
		wood_label = find_child("WoodLabel", true, false) as Label
	if wood_bar == null:
		wood_bar = find_child("WoodBar", true, false) as ProgressBar
	if stone_box == null:
		stone_box = find_child("StoneBox", true, false) as Control
	if stone_label == null:
		stone_label = find_child("StoneLabel", true, false) as Label
	if stone_bar == null:
		stone_bar = find_child("StoneBar", true, false) as ProgressBar
	if iron_box == null:
		iron_box = find_child("IronBox", true, false) as Control
	if iron_label == null:
		iron_label = find_child("IronLabel", true, false) as Label
	if iron_bar == null:
		iron_bar = find_child("IronBar", true, false) as ProgressBar
	if citizens_box == null:
		citizens_box = find_child("CitizensBox", true, false) as Control
	if citizens_label == null:
		citizens_label = find_child("CitizensLabel", true, false) as Label

	if storage_bar == null:
		storage_bar = find_child("StorageBar", true, false) as ProgressBar
	if storage_label == null:
		storage_label = find_child("StorageLabel", true, false) as Label
	if realm_label == null:
		realm_label = find_child("RealmLabel", true, false) as Label
	if btn_prev == null:
		btn_prev = find_child("BtnPrevVillage", true, false) as Button
	if btn_next == null:
		btn_next = find_child("BtnNextVillage", true, false) as Button
	if btn_market == null:
		btn_market = find_child("BtnMarket", true, false) as Button

	if _pb_fill_ok == null:
		_pb_fill_ok = StyleBoxFlat.new()
		_pb_fill_ok.bg_color = Color(0.28, 0.78, 0.44, 1.0)
		_pb_fill_ok.set_corner_radius_all(2)
	if _pb_fill_warn == null:
		_pb_fill_warn = StyleBoxFlat.new()
		_pb_fill_warn.bg_color = Color(0.94, 0.72, 0.22, 1.0)
		_pb_fill_warn.set_corner_radius_all(2)
	if _pb_fill_full == null:
		_pb_fill_full = StyleBoxFlat.new()
		_pb_fill_full.bg_color = Color(0.92, 0.30, 0.26, 1.0)
		_pb_fill_full.set_corner_radius_all(2)


func _scene_tree() -> SceneTree:
	if is_inside_tree():
		var t := get_tree()
		if t != null:
			return t
	var loop := Engine.get_main_loop()
	return loop as SceneTree if loop is SceneTree else null


func _autoload(node_name: String) -> Node:
	var tree := _scene_tree()
	if tree != null and tree.root != null:
		var found := tree.root.get_node_or_null(node_name)
		if found != null:
			return found
	var cur: Node = self
	while cur.get_parent() != null:
		cur = cur.get_parent()
	return cur.get_node_or_null(node_name) if cur != self else null


func _ready() -> void:
	_ensure_nodes()
	_apply_responsive_layout()

	var eb := _autoload("EventBus")
	if eb != null:
		if eb.has_signal("resources_changed") and not eb.resources_changed.is_connected(_on_resources_changed):
			eb.resources_changed.connect(_on_resources_changed)
		if eb.has_signal("building_completed") and not eb.building_completed.is_connected(_on_building_completed):
			eb.building_completed.connect(_on_building_completed)
		if eb.has_signal("realm_changed") and not eb.realm_changed.is_connected(_on_realm_changed):
			eb.realm_changed.connect(_on_realm_changed)
		if eb.has_signal("village_switched") and not eb.village_switched.is_connected(_on_village_switched):
			eb.village_switched.connect(_on_village_switched)

	var sm := _autoload("StoreManager")
	if sm != null and sm.has_signal("diamonds_changed") and not sm.diamonds_changed.is_connected(_on_diamonds_changed):
		sm.diamonds_changed.connect(_on_diamonds_changed)

	if btn_prev != null and not btn_prev.pressed.is_connected(_on_prev_village_pressed):
		btn_prev.pressed.connect(_on_prev_village_pressed)
	if btn_next != null and not btn_next.pressed.is_connected(_on_next_village_pressed):
		btn_next.pressed.connect(_on_next_village_pressed)
	if btn_market != null and not btn_market.pressed.is_connected(_on_market_pressed):
		btn_market.pressed.connect(_on_market_pressed)

	if village_name_label != null:
		village_name_label.mouse_filter = Control.MOUSE_FILTER_STOP
		village_name_label.clip_text = true
		village_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if not village_name_label.gui_input.is_connected(_on_village_name_gui_input):
			village_name_label.gui_input.connect(_on_village_name_gui_input)

	for box in [points_box, wood_box, stone_box, iron_box, citizens_box]:
		if box != null:
			box.mouse_filter = Control.MOUSE_FILTER_STOP
			if not box.gui_input.is_connected(_on_economy_box_gui_input):
				box.gui_input.connect(_on_economy_box_gui_input)

	if not resized.is_connected(_on_self_resized):
		resized.connect(_on_self_resized)

	refresh()


func _on_self_resized() -> void:
	_apply_responsive_layout()


func get_bar_height() -> float:
	_apply_responsive_layout()
	return _last_bar_height


func _apply_responsive_layout() -> void:
	_ensure_nodes()
	var gc := _autoload("GameConfig")
	var safe_top := 0.0
	var island_w := 0.0
	if gc != null:
		if gc.has_method("get_ios_safe_top"):
			safe_top = float(gc.call("get_ios_safe_top"))
		if gc.has_method("get_ios_dynamic_island_width"):
			island_w = float(gc.call("get_ios_dynamic_island_width"))

	var has_island := island_w > 0.0
	var top_pad := 9.0
	var bottom_pad := 9.0
	var sep := 6
	var top_row_h := 46.0
	var res_row_h := 46.0

	if has_island:
		top_pad = 4.0
		bottom_pad = 8.0
		sep = 4
		top_row_h = maxf(48.0, safe_top - 2.0)
	elif safe_top > 0.0:
		top_pad = maxf(9.0, safe_top + 2.0)

	var total_h := top_pad + top_row_h + float(sep) + res_row_h + bottom_pad
	_last_bar_height = total_h

	var panel_sb := get_theme_stylebox("panel") as StyleBoxFlat
	if panel_sb != null:
		var mut_sb := panel_sb
		if not mut_sb.resource_local_to_scene:
			mut_sb = panel_sb.duplicate() as StyleBoxFlat
			mut_sb.resource_local_to_scene = true
			add_theme_stylebox_override("panel", mut_sb)
		mut_sb.content_margin_top = top_pad
		mut_sb.content_margin_bottom = bottom_pad
		mut_sb.content_margin_left = 10.0 if has_island else 14.0
		mut_sb.content_margin_right = 10.0 if has_island else 14.0

	if vbox_root != null:
		vbox_root.add_theme_constant_override("separation", sep)
	if top_row != null:
		top_row.custom_minimum_size.y = top_row_h
	if resources_row != null:
		resources_row.custom_minimum_size.y = res_row_h

	if island_spacer != null:
		island_spacer.visible = has_island
		island_spacer.custom_minimum_size = Vector2(island_w if has_island else 0.0, 0.0)

	if right_wing != null:
		right_wing.size_flags_horizontal = Control.SIZE_EXPAND_FILL if has_island else Control.SIZE_SHRINK_END

	if points_box != null:
		points_box.visible = not has_island
	if btn_prev != null:
		btn_prev.custom_minimum_size = Vector2(32, 34) if has_island else Vector2(36, 36)
	if btn_next != null:
		btn_next.custom_minimum_size = Vector2(32, 34) if has_island else Vector2(36, 36)
	if btn_market != null:
		btn_market.custom_minimum_size = Vector2(118, 36) if has_island else Vector2(132, 38)
		btn_market.add_theme_font_size_override("font_size", 17 if has_island else 19)
	if village_name_label != null:
		village_name_label.add_theme_font_size_override("font_size", 18 if has_island else 21)

	custom_minimum_size.y = total_h
	offset_top = 0.0
	offset_bottom = total_h


func _is_tap_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		return mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		return st.pressed
	return false


func _on_village_name_gui_input(event: InputEvent) -> void:
	if _is_tap_event(event):
		accept_event()
		_show_village_switcher_modal()


func _on_economy_box_gui_input(event: InputEvent) -> void:
	if _is_tap_event(event):
		accept_event()
		_show_economy_modal()


func _on_prev_village_pressed() -> void:
	var gs := _get_game_state()
	if gs != null:
		if gs.has_method("cycle_active_village"):
			gs.call("cycle_active_village", -1)
		refresh()


func _on_next_village_pressed() -> void:
	var gs := _get_game_state()
	if gs != null:
		if gs.has_method("cycle_active_village"):
			gs.call("cycle_active_village", 1)
		refresh()


func _on_market_pressed() -> void:
	var sm := _autoload("StoreManager")
	if sm != null and sm.has_method("open_market"):
		sm.call("open_market", self, "build")


func _on_resources_changed(village_id: int) -> void:
	var gs := _get_game_state()
	if gs != null and int(gs.get("active_village_id")) == village_id:
		refresh()


func _on_building_completed(village_id: int, _key: String, _level: int) -> void:
	var gs := _get_game_state()
	if gs != null and int(gs.get("active_village_id")) == village_id:
		refresh()


func _on_realm_changed(village_id: int, _val: int) -> void:
	var gs := _get_game_state()
	if gs != null and int(gs.get("active_village_id")) == village_id:
		refresh()


func _on_village_switched(_village_id: int) -> void:
	refresh()


func _on_diamonds_changed(_amount: int) -> void:
	_update_market_button()


func _get_game_state() -> Node:
	return _autoload("GameState")


func _update_market_button() -> void:
	_ensure_nodes()
	if btn_market == null:
		return
	var diamonds := 0
	var sm := _autoload("StoreManager")
	if sm != null and sm.has_method("get_diamonds"):
		diamonds = int(sm.call("get_diamonds"))
	else:
		var gs := _get_game_state()
		if gs != null:
			var p = gs.get("player")
			if p is Dictionary:
				diamonds = int((p as Dictionary).get("diamonds", 0))
	btn_market.text = "💎 %d  +" % diamonds


func _apply_gauge(bar: ProgressBar, amount: float, cap: int) -> void:
	if bar == null:
		return
	var safe_cap := maxf(1.0, float(cap))
	bar.max_value = safe_cap
	bar.value = clampf(amount, 0.0, safe_cap)
	var ratio := amount / safe_cap
	var sb := _pb_fill_ok
	if ratio >= 0.95:
		sb = _pb_fill_full
	elif ratio >= 0.75:
		sb = _pb_fill_warn
	bar.add_theme_stylebox_override("fill", sb)


func refresh() -> void:
	_ensure_nodes()
	_apply_responsive_layout()
	_update_market_button()

	var gs := _get_game_state()
	if gs == null:
		return
	var v: Dictionary = gs.call("get_active_village") if gs.has_method("get_active_village") else {}
	if v.is_empty():
		return

	var player_dict: Dictionary = gs.get("player") if gs.get("player") is Dictionary else {}
	var p_name := str(player_dict.get("name", "Lord"))
	var v_name := str(v.get("name", "Köy"))
	var vx := int(v.get("x", 0))
	var vy := int(v.get("y", 0))

	var gc := _autoload("GameConfig")
	var island_w := float(gc.call("get_ios_dynamic_island_width")) if gc != null and gc.has_method("get_ios_dynamic_island_width") else 0.0

	if village_name_label != null:
		if island_w > 0.0:
			village_name_label.text = "🏰 %s (%d|%d)" % [v_name, vx, vy]
		else:
			village_name_label.text = "%s | 🏰 %s (%d|%d)" % [p_name, v_name, vx, vy]
		village_name_label.tooltip_text = "%s | 🏰 %s (%d|%d)\nKöyleri görmek ve seçmek için dokun" % [p_name, v_name, vx, vy]

	var villages_list = gs.get("villages")
	var multi: bool = (villages_list is Array and (villages_list as Array).size() > 1)
	if btn_prev != null:
		btn_prev.visible = multi
	if btn_next != null:
		btn_next.visible = multi

	if points_label != null:
		var v_pts := int(v.get("points", 0))
		if villages_list is Array and (villages_list as Array).size() > 1:
			var total_pts := 0
			for item in villages_list:
				total_pts += int(item.get("points", 0))
			points_label.text = "👑 %d P (%d)" % [v_pts, total_pts]
		else:
			points_label.text = "👑 %d P" % v_pts

	var res: Dictionary = v.get("resources", {})
	var w := float(res.get("wood", 0))
	var s := float(res.get("stone", 0))
	var i := float(res.get("iron", 0))

	if wood_label != null:
		wood_label.text = "%d" % int(w)
	if stone_label != null:
		stone_label.text = "%d" % int(s)
	if iron_label != null:
		iron_label.text = "%d" % int(i)

	var b: Dictionary = v.get("buildings", {})
	var wh_lvl := int(b.get("warehouse", 1))
	var cap := int(RulesEngine.storage_capacity(wh_lvl))
	if cap <= 0:
		cap = 1000

	_apply_gauge(wood_bar, w, cap)
	_apply_gauge(stone_bar, s, cap)
	_apply_gauge(iron_bar, i, cap)

	var pop: Dictionary = EconomyAPI.population_summary(v)
	var free_pop := int(pop.get("free", 0))
	if citizens_label != null:
		citizens_label.text = "%d Boş" % free_pop

	var rlm: Dictionary = EconomyAPI.realm_summary(v)
	var max_res := maxf(w, maxf(s, i))
	if storage_bar != null:
		storage_bar.max_value = float(cap)
		storage_bar.value = clampf(max_res, 0.0, float(cap))
	if storage_label != null:
		storage_label.text = "%d / %d" % [int(max_res), cap]
	if realm_label != null:
		realm_label.text = "%d / %d" % [int(rlm.get("value", 0)), int(rlm.get("cap", 0))]


func _get_sim_now_unix() -> int:
	var gl := _autoload("GameLoop")
	if gl != null and gl.has_method("now_unix"):
		return int(gl.call("now_unix"))
	var clock := _autoload("GameClock")
	if clock != null and clock.has_method("now_unix"):
		return int(clock.call("now_unix"))
	return int(Time.get_unix_time_from_system())


func _fmt_duration(secs: int) -> String:
	var s := maxi(0, secs)
	var sm := _autoload("StoreManager")
	if sm != null and sm.has_method("format_duration"):
		return str(sm.call("format_duration", s))
	var h := s / 3600
	var m := (s % 3600) / 60
	var rem := s % 60
	if h > 0:
		return "%02d:%02d:%02d" % [h, m, rem]
	return "%02d:%02d" % [m, rem]


func _show_economy_modal() -> void:
	var tree := _scene_tree()
	if tree == null:
		return
	var root := tree.current_scene
	if root == null:
		root = tree.root
	if root == null:
		return
	if is_instance_valid(_economy_modal):
		_economy_modal.queue_free()
	var prev := root.get_node_or_null("EconomySummaryModal")
	if prev != null:
		prev.queue_free()

	var gs := _get_game_state()
	if gs == null:
		return
	var v: Dictionary = gs.call("get_active_village") if gs.has_method("get_active_village") else {}
	if v.is_empty():
		return

	var b: Dictionary = v.get("buildings", {})
	var res: Dictionary = v.get("resources", {})
	var wh_lvl := int(b.get("warehouse", 1))
	var cap := maxi(1000, int(RulesEngine.storage_capacity(wh_lvl)))

	var wood := int(res.get("wood", 0))
	var stone := int(res.get("stone", 0))
	var iron := int(res.get("iron", 0))
	var wood_hr := int(round(RulesEngine.production_per_hour("lumber", int(b.get("lumber", 0)))))
	var stone_hr := int(round(RulesEngine.production_per_hour("quarry", int(b.get("quarry", 0)))))
	var iron_hr := int(round(RulesEngine.production_per_hour("ironmine", int(b.get("ironmine", 0)))))

	var pop: Dictionary = EconomyAPI.population_summary(v)
	var rlm: Dictionary = EconomyAPI.realm_summary(v)
	var now := _get_sim_now_unix()
	var prot_until := maxi(int(v.get("protection_until", 0)), int(v.get("protection_until_unix", 0)))
	var conq_until := maxi(int(v.get("conquest_protection_until", 0)), int(v.get("conquest_protection_until_unix", 0)))
	var prot_rem := maxi(0, prot_until - now)
	var conq_rem := maxi(0, conq_until - now)

	var layer := CanvasLayer.new()
	layer.name = "EconomySummaryModal"
	layer.layer = 136
	_economy_modal = layer
	root.add_child(layer)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.02, 0.05, 0.72)
	layer.add_child(dim)
	dim.gui_input.connect(func(ev: InputEvent):
		if _is_tap_event(ev):
			layer.queue_free()
	)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(780, 0)
	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color = Color(0.10, 0.09, 0.14, 0.98)
	card_sb.border_color = Color(0.86, 0.68, 0.28, 0.96)
	card_sb.set_border_width_all(2)
	card_sb.set_corner_radius_all(18)
	card_sb.content_margin_left = 24
	card_sb.content_margin_right = 24
	card_sb.content_margin_top = 20
	card_sb.content_margin_bottom = 20
	card.add_theme_stylebox_override("panel", card_sb)
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	card.add_child(vb)

	var head := HBoxContainer.new()
	vb.add_child(head)
	var title := Label.new()
	title.text = "🏰 Köy Ekonomisi & Depo Özeti"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_override("font", FONT_BOLD)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.98, 0.85, 0.45))
	head.add_child(title)

	var close_x := Button.new()
	close_x.text = "✕"
	close_x.custom_minimum_size = Vector2(44, 44)
	_style_modal_btn(close_x, Color(0.32, 0.14, 0.14, 0.95), Color(0.84, 0.38, 0.34, 0.9))
	close_x.pressed.connect(func(): layer.queue_free())
	head.add_child(close_x)

	var sub := Label.new()
	sub.text = "%s (%d|%d)   •   👑 %d Puan   •   🏛️ Depo Sv.%d (Kapasite: %d)" % [
		str(v.get("name", "Köy")), int(v.get("x", 0)), int(v.get("y", 0)), int(v.get("points", 0)), wh_lvl, cap
	]
	sub.add_theme_font_override("font", FONT_SEMIBOLD)
	sub.add_theme_font_size_override("font_size", 19)
	sub.add_theme_color_override("font_color", Color(0.86, 0.82, 0.72))
	vb.add_child(sub)

	var res_entries := [
		{"icon": ICON_WOOD, "name": "Odun (Oduncu Sv.%d)" % int(b.get("lumber", 0)), "cur": wood, "rate": wood_hr, "tint": Color(0.56, 0.86, 0.46)},
		{"icon": ICON_STONE, "name": "Taş (Taş Ocağı Sv.%d)" % int(b.get("quarry", 0)), "cur": stone, "rate": stone_hr, "tint": Color(0.78, 0.80, 0.84)},
		{"icon": ICON_IRON, "name": "Demir (Demir Madeni Sv.%d)" % int(b.get("ironmine", 0)), "cur": iron, "rate": iron_hr, "tint": Color(0.62, 0.78, 0.96)},
	]
	for entry in res_entries:
		var row_card := PanelContainer.new()
		var r_sb := StyleBoxFlat.new()
		r_sb.bg_color = Color(0.14, 0.12, 0.19, 0.94)
		r_sb.border_color = Color(0.38, 0.32, 0.24, 0.85)
		r_sb.set_border_width_all(1)
		r_sb.set_corner_radius_all(12)
		r_sb.content_margin_left = 14
		r_sb.content_margin_right = 14
		r_sb.content_margin_top = 10
		r_sb.content_margin_bottom = 10
		row_card.add_theme_stylebox_override("panel", r_sb)
		vb.add_child(row_card)

		var r_hb := HBoxContainer.new()
		r_hb.add_theme_constant_override("separation", 12)
		row_card.add_child(r_hb)

		var tex := TextureRect.new()
		tex.texture = entry["icon"]
		tex.custom_minimum_size = Vector2(36, 36)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r_hb.add_child(tex)

		var info_vb := VBoxContainer.new()
		info_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vb.add_theme_constant_override("separation", 4)
		r_hb.add_child(info_vb)

		var top_line := HBoxContainer.new()
		info_vb.add_child(top_line)

		var nm := Label.new()
		nm.text = str(entry["name"])
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.add_theme_font_override("font", FONT_BOLD)
		nm.add_theme_font_size_override("font_size", 20)
		nm.add_theme_color_override("font_color", Color(0.96, 0.93, 0.85))
		top_line.add_child(nm)

		var val_lbl := Label.new()
		val_lbl.text = "%d / %d   (+%d/saat)" % [int(entry["cur"]), cap, int(entry["rate"])]
		val_lbl.add_theme_font_override("font", FONT_BOLD)
		val_lbl.add_theme_font_size_override("font_size", 20)
		val_lbl.add_theme_color_override("font_color", entry["tint"])
		top_line.add_child(val_lbl)

		var pb := ProgressBar.new()
		pb.show_percentage = false
		pb.custom_minimum_size = Vector2(0, 8)
		pb.max_value = float(cap)
		pb.value = clampf(float(entry["cur"]), 0.0, float(cap))
		pb.add_theme_stylebox_override("background", _make_pb_bg())
		pb.add_theme_stylebox_override("fill", _make_pb_fill(entry["tint"]))
		info_vb.add_child(pb)

	var stats_card := PanelContainer.new()
	var s_sb := StyleBoxFlat.new()
	s_sb.bg_color = Color(0.13, 0.11, 0.17, 0.95)
	s_sb.border_color = Color(0.54, 0.44, 0.24, 0.85)
	s_sb.set_border_width_all(1)
	s_sb.set_corner_radius_all(12)
	s_sb.content_margin_left = 14
	s_sb.content_margin_right = 14
	s_sb.content_margin_top = 12
	s_sb.content_margin_bottom = 12
	stats_card.add_theme_stylebox_override("panel", s_sb)
	vb.add_child(stats_card)

	var stats_vb := VBoxContainer.new()
	stats_vb.add_theme_constant_override("separation", 8)
	stats_card.add_child(stats_vb)

	var pop_lbl := Label.new()
	pop_lbl.text = "👥 Vatandaş: %d Boş  /  %d Toplam  (Kullanılan: %d)" % [
		int(pop.get("free", 0)), int(pop.get("max", 0)), int(pop.get("used", 0))
	]
	pop_lbl.add_theme_font_override("font", FONT_SEMIBOLD)
	pop_lbl.add_theme_font_size_override("font_size", 20)
	pop_lbl.add_theme_color_override("font_color", Color(0.84, 0.96, 0.86))
	stats_vb.add_child(pop_lbl)

	var rlm_lbl := Label.new()
	rlm_lbl.text = "✨ Güç Alanı: %d / %d  (+%d/saat)" % [
		int(rlm.get("value", 0)), int(rlm.get("cap", 0)), int(round(float(rlm.get("hourly_gain", 0))))
	]
	rlm_lbl.add_theme_font_override("font", FONT_SEMIBOLD)
	rlm_lbl.add_theme_font_size_override("font_size", 20)
	rlm_lbl.add_theme_color_override("font_color", Color(0.76, 0.88, 0.98))
	stats_vb.add_child(rlm_lbl)

	var prot_txt := "🛡️ Saldırı Koruması: "
	if prot_rem > 0:
		prot_txt += _fmt_duration(prot_rem)
	else:
		prot_txt += "Yok"
	if conq_rem > 0:
		prot_txt += "   •   🏰 Fetih Koruması: " + _fmt_duration(conq_rem)
	var prot_lbl := Label.new()
	prot_lbl.text = prot_txt
	prot_lbl.add_theme_font_override("font", FONT_SEMIBOLD)
	prot_lbl.add_theme_font_size_override("font_size", 19)
	prot_lbl.add_theme_color_override("font_color", Color(0.96, 0.86, 0.52) if (prot_rem > 0 or conq_rem > 0) else Color(0.72, 0.70, 0.68))
	stats_vb.add_child(prot_lbl)

	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_END
	btns.add_theme_constant_override("separation", 10)
	vb.add_child(btns)

	var btn_rename := Button.new()
	btn_rename.text = "✏️ Köy Adı Değiştir"
	btn_rename.custom_minimum_size = Vector2(210, 48)
	_style_modal_btn(btn_rename, Color(0.20, 0.18, 0.28, 0.96), Color(0.78, 0.62, 0.30, 0.90))
	btn_rename.pressed.connect(func():
		layer.queue_free()
		_show_rename_modal()
	)
	btns.add_child(btn_rename)

	var btn_open_mkt := Button.new()
	btn_open_mkt.text = "🛒 Kraliyet Pazarı"
	btn_open_mkt.custom_minimum_size = Vector2(210, 48)
	_style_modal_btn(btn_open_mkt, Color(0.14, 0.28, 0.50, 0.98), Color(0.94, 0.78, 0.36, 0.96))
	btn_open_mkt.pressed.connect(func():
		layer.queue_free()
		_on_market_pressed()
	)
	btns.add_child(btn_open_mkt)

	var btn_ok := Button.new()
	btn_ok.text = "Kapat"
	btn_ok.custom_minimum_size = Vector2(130, 48)
	_style_modal_btn(btn_ok, Color(0.22, 0.19, 0.24, 0.95), Color(0.62, 0.56, 0.44, 0.85))
	btn_ok.pressed.connect(func(): layer.queue_free())
	btns.add_child(btn_ok)


func _make_pb_bg() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.09, 0.96)
	sb.set_corner_radius_all(4)
	return sb


func _make_pb_fill(col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(4)
	return sb


func _style_modal_btn(b: Button, bg: Color, border: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	var sb_h := sb.duplicate() as StyleBoxFlat
	sb_h.bg_color = bg.lightened(0.12)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb_h)
	b.add_theme_stylebox_override("pressed", sb_h)
	b.add_theme_font_override("font", FONT_BOLD)
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_color_override("font_color", Color(0.98, 0.95, 0.86))


func _show_village_switcher_modal() -> void:
	var gs := _get_game_state()
	if gs == null:
		return
	var tree := _scene_tree()
	if tree == null:
		return
	var root := tree.current_scene
	if root == null:
		root = tree.root
	if root == null:
		return
	if is_instance_valid(_switcher_modal):
		_switcher_modal.queue_free()
	var prev := root.get_node_or_null("VillageSwitcherModal")
	if prev != null:
		prev.queue_free()

	var layer := CanvasLayer.new()
	layer.name = "VillageSwitcherModal"
	layer.layer = 135
	_switcher_modal = layer
	root.add_child(layer)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.02, 0.05, 0.72)
	layer.add_child(dim)
	dim.gui_input.connect(func(ev: InputEvent):
		if _is_tap_event(ev):
			layer.queue_free()
	)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(760, 0)
	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color = Color(0.10, 0.09, 0.14, 0.98)
	card_sb.border_color = Color(0.86, 0.68, 0.28, 0.96)
	card_sb.set_border_width_all(2)
	card_sb.set_corner_radius_all(18)
	card_sb.content_margin_left = 24
	card_sb.content_margin_right = 24
	card_sb.content_margin_top = 20
	card_sb.content_margin_bottom = 20
	card.add_theme_stylebox_override("panel", card_sb)
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	card.add_child(vb)

	var header := HBoxContainer.new()
	vb.add_child(header)
	var title := Label.new()
	title.text = "🏰 Köylerim"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_override("font", FONT_BOLD)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.98, 0.85, 0.45))
	header.add_child(title)

	var rename_btn := Button.new()
	rename_btn.text = "✏️ Adı Değiştir"
	rename_btn.custom_minimum_size = Vector2(180, 44)
	_style_modal_btn(rename_btn, Color(0.20, 0.18, 0.28, 0.96), Color(0.78, 0.62, 0.30, 0.90))
	rename_btn.pressed.connect(func():
		layer.queue_free()
		_show_rename_modal()
	)
	header.add_child(rename_btn)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 440)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 12
	vb.add_child(scroll)

	var list_vb := VBoxContainer.new()
	list_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vb.add_theme_constant_override("separation", 10)
	scroll.add_child(list_vb)

	var active_id := int(gs.get("active_village_id"))
	var villages_arr = gs.get("villages")
	if villages_arr is Array:
		for item in villages_arr:
			if not (item is Dictionary):
				continue
			var v: Dictionary = item
			var vid := int(v.get("id", -1))
			var is_cur := (vid == active_id)

			var row := PanelContainer.new()
			row.mouse_filter = Control.MOUSE_FILTER_PASS
			var r_sb := StyleBoxFlat.new()
			r_sb.bg_color = Color(0.18, 0.16, 0.24, 0.98) if is_cur else Color(0.13, 0.11, 0.17, 0.94)
			r_sb.border_color = Color(0.95, 0.78, 0.34, 0.95) if is_cur else Color(0.42, 0.36, 0.26, 0.85)
			r_sb.set_border_width_all(2 if is_cur else 1)
			r_sb.set_corner_radius_all(12)
			r_sb.content_margin_left = 14
			r_sb.content_margin_right = 14
			r_sb.content_margin_top = 10
			r_sb.content_margin_bottom = 10
			row.add_theme_stylebox_override("panel", r_sb)
			list_vb.add_child(row)

			var hb := HBoxContainer.new()
			hb.mouse_filter = Control.MOUSE_FILTER_PASS
			hb.add_theme_constant_override("separation", 10)
			row.add_child(hb)

			var info_vb := VBoxContainer.new()
			info_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hb.add_child(info_vb)

			var nm := Label.new()
			nm.text = "%s%s (%d|%d) • 👑 %d P" % [
				"▶ " if is_cur else "🏰 ", str(v.get("name", "Köy")), int(v.get("x", 0)), int(v.get("y", 0)), int(v.get("points", 0))
			]
			nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
			nm.add_theme_font_override("font", FONT_BOLD)
			nm.add_theme_font_size_override("font_size", 21)
			nm.add_theme_color_override("font_color", Color(0.98, 0.88, 0.56) if is_cur else Color(0.96, 0.93, 0.85))
			info_vb.add_child(nm)

			var v_res: Dictionary = v.get("resources", {})
			var v_pop: Dictionary = EconomyAPI.population_summary(v)
			var sub := Label.new()
			sub.text = "🪵 %d  🪨 %d  ⛏️ %d  👥 %d Boş" % [
				int(v_res.get("wood", 0)), int(v_res.get("stone", 0)), int(v_res.get("iron", 0)), int(v_pop.get("free", 0))
			]
			sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
			sub.add_theme_font_override("font", FONT_SEMIBOLD)
			sub.add_theme_font_size_override("font_size", 18)
			sub.add_theme_color_override("font_color", Color(0.80, 0.78, 0.72))
			info_vb.add_child(sub)

			var sel_btn := Button.new()
			sel_btn.text = "Seçili" if is_cur else "Geçiş Yap"
			sel_btn.disabled = is_cur
			sel_btn.mouse_filter = Control.MOUSE_FILTER_PASS
			sel_btn.custom_minimum_size = Vector2(140, 44)
			_style_modal_btn(sel_btn, Color(0.18, 0.42, 0.24, 0.96), Color(0.45, 0.84, 0.52, 0.90))
			sel_btn.pressed.connect(func():
				if gs.has_method("set_active_village"):
					gs.call("set_active_village", vid)
				refresh()
				layer.queue_free()
			)
			hb.add_child(sel_btn)

	var close_btn := Button.new()
	close_btn.text = "Kapat"
	close_btn.custom_minimum_size = Vector2(160, 46)
	_style_modal_btn(close_btn, Color(0.22, 0.19, 0.24, 0.95), Color(0.62, 0.56, 0.44, 0.85))
	close_btn.pressed.connect(func(): layer.queue_free())
	vb.add_child(close_btn)


func _show_rename_modal() -> void:
	var gs := _get_game_state()
	if gs == null:
		return
	var v: Dictionary = gs.call("get_active_village") if gs.has_method("get_active_village") else {}
	if v.is_empty():
		return

	var tree := _scene_tree()
	if tree == null:
		return
	var root := tree.current_scene
	if root == null:
		root = tree.root
	if root == null:
		return
	if is_instance_valid(_rename_modal):
		_rename_modal.queue_free()
	var prev := root.get_node_or_null("VillageRenameModal")
	if prev != null:
		prev.queue_free()

	var layer := CanvasLayer.new()
	layer.name = "VillageRenameModal"
	layer.layer = 138
	_rename_modal = layer
	root.add_child(layer)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.02, 0.05, 0.72)
	layer.add_child(dim)
	dim.gui_input.connect(func(ev: InputEvent):
		if _is_tap_event(ev):
			layer.queue_free()
	)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(600, 0)
	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color = Color(0.10, 0.09, 0.14, 0.98)
	card_sb.border_color = Color(0.86, 0.68, 0.28, 0.96)
	card_sb.set_border_width_all(2)
	card_sb.set_corner_radius_all(18)
	card_sb.content_margin_left = 24
	card_sb.content_margin_right = 24
	card_sb.content_margin_top = 20
	card_sb.content_margin_bottom = 20
	card.add_theme_stylebox_override("panel", card_sb)
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	card.add_child(vb)

	var title := Label.new()
	title.text = "✏️ Köy Adını Değiştir"
	title.add_theme_font_override("font", FONT_BOLD)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.98, 0.85, 0.45))
	vb.add_child(title)

	var line := LineEdit.new()
	line.text = str(v.get("name", ""))
	line.max_length = 24
	line.placeholder_text = "Yeni köy adını girin..."
	line.custom_minimum_size = Vector2(0, 52)
	line.add_theme_font_override("font", FONT_BOLD)
	line.add_theme_font_size_override("font_size", 22)
	vb.add_child(line)

	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_END
	hb.add_theme_constant_override("separation", 10)
	vb.add_child(hb)

	var cancel_btn := Button.new()
	cancel_btn.text = "İptal"
	cancel_btn.custom_minimum_size = Vector2(130, 48)
	_style_modal_btn(cancel_btn, Color(0.22, 0.19, 0.24, 0.95), Color(0.62, 0.56, 0.44, 0.85))
	cancel_btn.pressed.connect(func(): layer.queue_free())
	hb.add_child(cancel_btn)

	var save_btn := Button.new()
	save_btn.text = "Kaydet"
	save_btn.custom_minimum_size = Vector2(150, 48)
	_style_modal_btn(save_btn, Color(0.18, 0.44, 0.24, 0.96), Color(0.45, 0.86, 0.52, 0.95))
	save_btn.pressed.connect(func():
		var new_name := line.text.strip_edges()
		if not new_name.is_empty():
			if gs.has_method("rename_village"):
				gs.call("rename_village", int(v.get("id", -1)), new_name)
			else:
				v["name"] = new_name
			refresh()
		layer.queue_free()
	)
	hb.add_child(save_btn)
	line.grab_focus()
