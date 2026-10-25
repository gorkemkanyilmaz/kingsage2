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
		_show_rename_modal()


func _on_prev_village_pressed() -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs != null and gs.has_method("cycle_active_village"):
		gs.cycle_active_village(-1)
		refresh()


func _on_next_village_pressed() -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs != null and gs.has_method("cycle_active_village"):
		gs.cycle_active_village(1)
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

		var count_str := " [%d/%d]" % [cur_idx, total_vills] if total_vills > 1 else ""
		var v_name := str(v.get("name", "Başkent"))
		village_name_label.text = "%s | %s (%d|%d)%s" % [user_name, v_name, int(v.get("x", 0)), int(v.get("y", 0)), count_str]
		village_name_label.tooltip_text = ""

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


var _rename_modal: Control = null

func _show_rename_modal() -> void:
	if _rename_modal != null and is_instance_valid(_rename_modal):
		_rename_modal.queue_free()

	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null or not gs.has_active_village():
		return
	var v: Dictionary = gs.get_active_village()
	var cur_name := str(v.get("name", "Başkent"))

	_rename_modal = Control.new()
	_rename_modal.name = "RenameVillageModal"
	_rename_modal.anchors_preset = Control.PRESET_FULL_RECT
	_rename_modal.anchor_left = 0.0
	_rename_modal.anchor_top = 0.0
	_rename_modal.anchor_right = 1.0
	_rename_modal.anchor_bottom = 1.0
	_rename_modal.z_index = 200

	# Koyu arkaplan karartması
	var dim := ColorRect.new()
	dim.anchors_preset = Control.PRESET_FULL_RECT
	dim.color = Color(0.04, 0.03, 0.06, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_rename_modal.add_child(dim)

	# Ortalanmış kart
	var center := CenterContainer.new()
	center.anchors_preset = Control.PRESET_FULL_RECT
	_rename_modal.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(640, 360)
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

