extends CanvasLayer
## ConqueredModal — Tüm köyler fethedildiğinde gösterilen "Yeniden Başla" ekranı (Taht ve Kılıç).

const FontCinzelBold: Font = preload("res://assets/fonts/Cinzel-Bold.ttf")
const FontNunitoBold: Font = preload("res://assets/fonts/Nunito-Bold.ttf")

var _world_id: int = 1
var _player_name: String = ""
var _conquered_by: String = ""
var _selected_target: Vector2i = Vector2i(-1, -1)
var _dir_buttons: Array[Button] = []
var _desc_lbl: Label = null
var _status_lbl: Label = null
var _btn_restart: Button = null


static func get_active(tree_root: Node) -> Node:
	if tree_root == null:
		return null
	return tree_root.get_node_or_null("ConqueredOverlay")


static func dismiss(tree_root: Node) -> void:
	var existing := get_active(tree_root)
	if existing != null and is_instance_valid(existing):
		existing.queue_free()


static func show_modal(world_id: int, player_name: String, conquered_by: String = "") -> Node:
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return null
	var tree := loop as SceneTree
	if tree.root == null:
		return null
	var existing := get_active(tree.root)
	if existing != null and is_instance_valid(existing):
		if existing.has_method("configure"):
			existing.call("configure", world_id, player_name, conquered_by)
		return existing

	var modal = load("res://ui/ConqueredModal.gd").new()
	modal.name = "ConqueredOverlay"
	modal.layer = 120
	tree.root.add_child(modal)
	modal.configure(world_id, player_name, conquered_by)
	return modal


func _ready() -> void:
	_build_ui()


func configure(world_id: int, player_name: String, conquered_by: String = "") -> void:
	_world_id = world_id
	_player_name = player_name
	_conquered_by = conquered_by.strip_edges()
	_update_desc()


func _build_ui() -> void:
	var root_ctrl := Control.new()
	root_ctrl.name = "RootControl"
	root_ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root_ctrl)

	var dim := ColorRect.new()
	dim.name = "DimBg"
	dim.color = Color(0.03, 0.02, 0.02, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root_ctrl.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	root_ctrl.add_child(center)

	var card := PanelContainer.new()
	card.name = "ConqueredCard"
	card.custom_minimum_size = Vector2(880, 0)
	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color = Color(0.11, 0.08, 0.07, 0.98)
	card_sb.border_color = Color(0.84, 0.34, 0.24, 1.0)
	card_sb.set_border_width_all(3)
	card_sb.border_width_top = 6
	card_sb.set_corner_radius_all(24)
	card_sb.set_content_margin_all(38)
	card_sb.shadow_color = Color(0, 0, 0, 0.78)
	card_sb.shadow_size = 24
	card_sb.shadow_offset = Vector2(0, 10)
	card.add_theme_stylebox_override("panel", card_sb)
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 22)
	card.add_child(vb)

	var emblem := Label.new()
	emblem.text = "⚔️ 🏰 ⚔️"
	emblem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emblem.add_theme_font_size_override("font_size", 50)
	vb.add_child(emblem)

	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "TÜM KÖYLERİNİZİ KAYBETTİNİZ!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_override("font", FontCinzelBold)
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.48, 0.38))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
	title.add_theme_constant_override("outline_size", 4)
	vb.add_child(title)

	_desc_lbl = Label.new()
	_desc_lbl.name = "DescLabel"
	_desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_lbl.add_theme_font_override("font", FontNunitoBold)
	_desc_lbl.add_theme_font_size_override("font_size", 26)
	_desc_lbl.add_theme_color_override("font_color", Color(0.93, 0.89, 0.82))
	vb.add_child(_desc_lbl)

	var dir_hdr := Label.new()
	dir_hdr.text = "Yeni Başlangıç Lokasyonu Seçin:"
	dir_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dir_hdr.add_theme_font_override("font", FontNunitoBold)
	dir_hdr.add_theme_font_size_override("font_size", 24)
	dir_hdr.add_theme_color_override("font_color", Color(0.98, 0.86, 0.52))
	vb.add_child(dir_hdr)

	var dir_grid := GridContainer.new()
	dir_grid.name = "DirectionGrid"
	dir_grid.columns = 2
	dir_grid.add_theme_constant_override("h_separation", 12)
	dir_grid.add_theme_constant_override("v_separation", 12)
	vb.add_child(dir_grid)

	var dirs := [
		{"name": "DirBtn_NW", "label": "↖ Kuzeybatı", "pos": Vector2i(35, 35)},
		{"name": "DirBtn_NE", "label": "↗ Kuzeydoğu", "pos": Vector2i(165, 35)},
		{"name": "DirBtn_SW", "label": "↙ Güneybatı", "pos": Vector2i(35, 165)},
		{"name": "DirBtn_SE", "label": "↘ Güneydoğu", "pos": Vector2i(165, 165)},
	]
	for d in dirs:
		var db := Button.new()
		db.name = str(d["name"])
		db.text = str(d["label"])
		db.custom_minimum_size = Vector2(0, 56)
		db.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		db.add_theme_font_override("font", FontNunitoBold)
		db.add_theme_font_size_override("font_size", 24)
		db.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		db.set_meta("target_pos", d["pos"])
		db.pressed.connect(_on_dir_selected.bind(db))
		dir_grid.add_child(db)
		_dir_buttons.append(db)

	var rand_btn := Button.new()
	rand_btn.name = "DirBtn_Random"
	rand_btn.text = "🎲 Farklı Rastgele Konum"
	rand_btn.custom_minimum_size = Vector2(0, 56)
	rand_btn.add_theme_font_override("font", FontNunitoBold)
	rand_btn.add_theme_font_size_override("font_size", 24)
	rand_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	rand_btn.set_meta("target_pos", Vector2i(-1, -1))
	rand_btn.pressed.connect(_on_dir_selected.bind(rand_btn))
	vb.add_child(rand_btn)
	_dir_buttons.append(rand_btn)

	_refresh_dir_styles()

	_status_lbl = Label.new()
	_status_lbl.name = "StatusLabel"
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_lbl.add_theme_font_override("font", FontNunitoBold)
	_status_lbl.add_theme_font_size_override("font_size", 22)
	_status_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.45))
	_status_lbl.visible = false
	vb.add_child(_status_lbl)

	_btn_restart = Button.new()
	_btn_restart.name = "BtnRestartGame"
	_btn_restart.text = "🔄 Oyuna Tekrar Başla"
	_btn_restart.custom_minimum_size = Vector2(0, 72)
	_btn_restart.add_theme_font_override("font", FontCinzelBold)
	_btn_restart.add_theme_font_size_override("font_size", 30)
	_btn_restart.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var r_sb := StyleBoxFlat.new()
	r_sb.bg_color = Color(0.58, 0.22, 0.14, 1.0)
	r_sb.border_color = Color(0.95, 0.80, 0.40, 1.0)
	r_sb.set_border_width_all(3)
	r_sb.set_corner_radius_all(16)
	r_sb.set_content_margin_all(14)
	_btn_restart.add_theme_stylebox_override("normal", r_sb)
	var r_hover := r_sb.duplicate() as StyleBoxFlat
	r_hover.bg_color = Color(0.72, 0.28, 0.18, 1.0)
	_btn_restart.add_theme_stylebox_override("hover", r_hover)
	_btn_restart.add_theme_stylebox_override("pressed", r_hover)
	_btn_restart.add_theme_color_override("font_color", Color(1.0, 0.96, 0.84))
	_btn_restart.pressed.connect(_on_restart_pressed)
	vb.add_child(_btn_restart)

	var btn_worlds := Button.new()
	btn_worlds.name = "BtnWorldSelect"
	btn_worlds.text = "Dünya Seçimine Dön"
	btn_worlds.custom_minimum_size = Vector2(0, 52)
	btn_worlds.add_theme_font_override("font", FontNunitoBold)
	btn_worlds.add_theme_font_size_override("font_size", 23)
	btn_worlds.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var w_sb := StyleBoxFlat.new()
	w_sb.bg_color = Color(0.16, 0.13, 0.18, 0.92)
	w_sb.border_color = Color(0.55, 0.48, 0.36, 0.85)
	w_sb.set_border_width_all(1)
	w_sb.set_corner_radius_all(12)
	btn_worlds.add_theme_stylebox_override("normal", w_sb)
	btn_worlds.add_theme_color_override("font_color", Color(0.82, 0.78, 0.70))
	btn_worlds.pressed.connect(_on_world_select_pressed)
	vb.add_child(btn_worlds)

	_update_desc()


func _update_desc() -> void:
	if _desc_lbl == null:
		return
	if not _conquered_by.is_empty():
		_desc_lbl.text = "Son köyünüz %s tarafından fethedildi.\nTüm köylerinizi kaybettiniz. Farklı bir bölgede sıfırdan yeni bir başkent kurarak oyuna tekrar başlayabilirsiniz." % _conquered_by
	else:
		_desc_lbl.text = "Dünya %d topraklarındaki tüm köylerinizi kaybettiniz.\nFarklı bir lokasyonda sıfırdan yeni bir başkent kurarak oyuna tekrar başlayabilirsiniz." % _world_id


func _on_dir_selected(btn: Button) -> void:
	var pos = btn.get_meta("target_pos", Vector2i(-1, -1))
	if pos is Vector2i:
		_selected_target = pos
	_refresh_dir_styles()


func _refresh_dir_styles() -> void:
	for b in _dir_buttons:
		if not is_instance_valid(b):
			continue
		var pos = b.get_meta("target_pos", Vector2i(-1, -1))
		var selected := (pos is Vector2i and (pos as Vector2i) == _selected_target)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.28, 0.22, 0.14, 0.98) if selected else Color(0.16, 0.13, 0.19, 0.92)
		sb.border_color = Color(1.0, 0.85, 0.42, 1.0) if selected else Color(0.52, 0.44, 0.32, 0.8)
		sb.set_border_width_all(3 if selected else 1)
		sb.set_corner_radius_all(12)
		sb.set_content_margin_all(10)
		b.add_theme_stylebox_override("normal", sb)
		var h_sb := sb.duplicate() as StyleBoxFlat
		h_sb.bg_color = Color(0.35, 0.28, 0.18, 1.0)
		b.add_theme_stylebox_override("hover", h_sb)
		b.add_theme_stylebox_override("pressed", h_sb)
		b.add_theme_color_override("font_color", Color(1.0, 0.95, 0.72) if selected else Color(0.86, 0.82, 0.74))


func _on_restart_pressed() -> void:
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return
	var tree := loop as SceneTree
	var wm := tree.root.get_node_or_null("WorldManager")
	if wm == null or not wm.has_method("restart_after_conquest"):
		if _status_lbl != null:
			_status_lbl.text = "WorldManager bulunamadı."
			_status_lbl.visible = true
		return
	var p_name := _player_name
	if p_name.strip_edges().is_empty():
		var auth := tree.root.get_node_or_null("AuthManager")
		if auth != null and not str(auth.display_name).is_empty():
			p_name = str(auth.display_name)
		else:
			p_name = "Lord Gorkem"

	if _btn_restart != null:
		_btn_restart.disabled = true
	var ok := bool(wm.restart_after_conquest(_world_id, p_name, _selected_target.x, _selected_target.y))
	if ok:
		queue_free()
		tree.change_scene_to_file("res://scenes/Village.tscn")
	else:
		if _btn_restart != null:
			_btn_restart.disabled = false
		if _status_lbl != null:
			_status_lbl.text = "Yeni köy oluşturulamadı, lütfen tekrar deneyin."
			_status_lbl.visible = true


func _on_world_select_pressed() -> void:
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return
	var tree := loop as SceneTree
	var wm := tree.root.get_node_or_null("WorldManager")
	if wm != null:
		wm.set("suppress_auto_conquered_prompt", true)
	queue_free()
	tree.change_scene_to_file("res://scenes/VillageSelect.tscn")
