extends CanvasLayer
## LordUpgradeModal — Knight Online Örsü Stili +0 .. +8 Ekipman Geliştirme Ekranı.

signal closed()
signal open_market_lord_requested()
signal open_market_diamonds_requested()

const LordModelScript := preload("res://scripts/model/LordModel.gd")
const FontCinzelBold := preload("res://assets/fonts/Cinzel-Bold.ttf")
const FontNunitoBold := preload("res://assets/fonts/Nunito-Bold.ttf")
const FontNunitoSemiBold := preload("res://assets/fonts/Nunito-SemiBold.ttf")
const TexUpgradeScroll := preload("res://assets/sprites/lord/upgrade_scroll.png")
const TexDiamond := preload("res://assets/sprites/ui/nano_banana/sharp_icon_diamond.png")


class ScrollDragTile extends PanelContainer:
	var scroll_count: int = 0
	var is_shop: bool = false
	var _press_pos: Vector2 = Vector2.ZERO
	var _pressing: bool = false
	signal tile_pressed()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_pressing = true
					_press_pos = mb.position
				elif _pressing:
					_pressing = false
					if mb.position.distance_to(_press_pos) <= 22.0:
						tile_pressed.emit()
		elif event is InputEventScreenTouch:
			var st := event as InputEventScreenTouch
			if st.pressed:
				_pressing = true
				_press_pos = st.position
			elif _pressing:
				_pressing = false
				if st.position.distance_to(_press_pos) <= 22.0:
					tile_pressed.emit()

	func _get_drag_data(_at_position: Vector2) -> Variant:
		_pressing = false
		if not is_shop and scroll_count <= 0:
			return null
		if is_inside_tree() and get_viewport() != null and get_viewport().gui_is_dragging():
			var preview := TextureRect.new()
			preview.texture = TexUpgradeScroll
			preview.custom_minimum_size = Vector2(72, 72)
			preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			set_drag_preview(preview)
		return {"kind": "upgrade_scroll_shop" if is_shop else "upgrade_scroll"}


class AnvilGridSlot extends PanelContainer:
	var slot_index: int = 0
	var has_scroll: bool = false
	signal slot_dropped(payload: Dictionary, index: int)
	signal slot_clicked(index: int)

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return typeof(data) == TYPE_DICTIONARY and (str((data as Dictionary).get("kind", "")) in ["upgrade_scroll", "upgrade_scroll_shop"])

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if typeof(data) == TYPE_DICTIONARY:
			slot_dropped.emit(data as Dictionary, slot_index)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			slot_clicked.emit(slot_index)
		elif event is InputEventScreenTouch and event.pressed:
			slot_clicked.emit(slot_index)


class TargetItemSlot extends PanelContainer:
	signal item_dropped(item_id: String)
	signal slot_cleared()
	var _press_pos: Vector2 = Vector2.ZERO
	var _pressing: bool = false

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return typeof(data) == TYPE_DICTIONARY and str((data as Dictionary).get("kind", "")) == "upgrade_item" and not str((data as Dictionary).get("item_id", "")).is_empty()

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if typeof(data) == TYPE_DICTIONARY:
			var iid := str((data as Dictionary).get("item_id", ""))
			if not iid.is_empty():
				item_dropped.emit(iid)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_pressing = true
					_press_pos = mb.position
				elif _pressing:
					_pressing = false
					if mb.position.distance_to(_press_pos) <= 22.0:
						slot_cleared.emit()
		elif event is InputEventScreenTouch:
			var st := event as InputEventScreenTouch
			if st.pressed:
				_pressing = true
				_press_pos = st.position
			elif _pressing:
				_pressing = false
				if st.position.distance_to(_press_pos) <= 22.0:
					slot_cleared.emit()


class ItemDragCard extends PanelContainer:
	var item_id: String = ""
	var icon_tex: Texture2D = null
	var _press_pos: Vector2 = Vector2.ZERO
	var _pressing: bool = false
	signal item_pressed(item_id: String)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_pressing = true
					_press_pos = mb.position
				elif _pressing:
					_pressing = false
					if mb.position.distance_to(_press_pos) <= 22.0:
						item_pressed.emit(item_id)
		elif event is InputEventScreenTouch:
			var st := event as InputEventScreenTouch
			if st.pressed:
				_pressing = true
				_press_pos = st.position
			elif _pressing:
				_pressing = false
				if st.position.distance_to(_press_pos) <= 22.0:
					item_pressed.emit(item_id)

	func _get_drag_data(_at_position: Vector2) -> Variant:
		_pressing = false
		if item_id.is_empty():
			return null
		if is_inside_tree() and get_viewport() != null and get_viewport().gui_is_dragging() and icon_tex != null:
			var preview := TextureRect.new()
			preview.texture = icon_tex
			preview.custom_minimum_size = Vector2(72, 72)
			preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			set_drag_preview(preview)
		return {"kind": "upgrade_item", "item_id": item_id}


var _selected_item_id: String = ""
var _placed_scroll_slot: int = -1
var _preview_active: bool = false
var _ui_built: bool = false
var _opened_explicitly: bool = false

var _root_ctrl: Control
var _beam_panel: PanelContainer
var _beam_label: Label
var _beam_tween: Tween

var _target_slot: TargetItemSlot
var _target_icon: TextureRect
var _target_name_lbl: Label
var _target_sub_lbl: Label

var _grid_slots: Array[AnvilGridSlot] = []
var _grid_icons: Array[TextureRect] = []
var _scroll_badge_lbl: Label
var _shop_tile: ScrollDragTile
var _inv_scroll_tile: ScrollDragTile

var _info_panel: PanelContainer
var _rate_lbl: Label
var _warn_lbl: Label
var _preview_box: PanelContainer
var _preview_lbl: Label
var _btn_cancel_preview: Button

var _btn_preview: Button
var _btn_upgrade: Button
var _inv_grid: GridContainer
var _empty_inv_lbl: Label
var _body_scroll: ScrollContainer = null

var _confirm_layer: Control = null


func _ready() -> void:
	layer = 135
	_build_ui()
	var lm := _lord_mgr()
	if lm != null and lm.has_signal("lord_changed") and not lm.lord_changed.is_connected(_refresh_all):
		lm.lord_changed.connect(_refresh_all)
	if not _opened_explicitly:
		hide()


func _lord_mgr() -> Node:
	var loop := Engine.get_main_loop()
	return (loop as SceneTree).root.get_node_or_null("LordManager") if loop is SceneTree else null


func open_modal(initial_item_id: String = "") -> void:
	_opened_explicitly = true
	_build_ui()
	_selected_item_id = ""
	_preview_active = false
	_placed_scroll_slot = -1
	_beam_panel.hide()
	if not initial_item_id.is_empty():
		var lm := _lord_mgr()
		var ld: Dictionary = lm.call("get_lord_state") if lm != null else {}
		if not LordModelScript.is_item_equipped(ld, initial_item_id):
			_selected_item_id = initial_item_id
	_refresh_all()
	show()


func close_modal() -> void:
	_opened_explicitly = false
	_selected_item_id = ""
	_placed_scroll_slot = -1
	_preview_active = false
	hide()
	closed.emit()


func scroll_to_control(ctrl: Control) -> void:
	if _body_scroll == null or not is_instance_valid(_body_scroll):
		return
	if ctrl == null or not is_instance_valid(ctrl) or not _body_scroll.is_ancestor_of(ctrl):
		return
	var sc_rect := _body_scroll.get_global_rect()
	var c_rect := ctrl.get_global_rect()
	if sc_rect.size.y <= 10.0:
		return
	var margin_y := 28.0
	if c_rect.position.y >= sc_rect.position.y + margin_y and c_rect.end.y <= sc_rect.end.y - margin_y:
		return
	var content_y := c_rect.position.y - sc_rect.position.y + float(_body_scroll.scroll_vertical)
	var desired := int(round(maxf(0.0, content_y - sc_rect.size.y * 0.32)))
	_body_scroll.scroll_vertical = desired


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
	dim.color = Color(0.02, 0.02, 0.04, 0.88)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root_ctrl.add_child(dim)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 90)
	margin.add_theme_constant_override("margin_bottom", 80)
	_root_ctrl.add_child(margin)

	var card := PanelContainer.new()
	card.name = "UpgradeAnvilCard"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.08, 0.13, 0.99)
	sb.border_color = Color(0.92, 0.75, 0.34, 1.0)
	sb.set_border_width_all(3)
	sb.border_width_top = 6
	sb.set_corner_radius_all(20)
	sb.set_content_margin_all(20)
	card.add_theme_stylebox_override("panel", sb)
	margin.add_child(card)

	var main_vb := VBoxContainer.new()
	main_vb.add_theme_constant_override("separation", 14)
	card.add_child(main_vb)

	# Header
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 12)
	main_vb.add_child(hdr)

	var title := Label.new()
	title.text = "⚒️ KRALİYET ÖRSÜ · EKİPMAN GELİŞTİRME"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_override("font", FontCinzelBold)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	hdr.add_child(title)

	var btn_close := Button.new()
	btn_close.name = "BtnCloseUpgrade"
	btn_close.text = "✕"
	btn_close.custom_minimum_size = Vector2(56, 52)
	_style_btn(btn_close, Color(0.32, 0.14, 0.16, 0.96), Color(0.92, 0.48, 0.48, 1.0), Color(1, 0.92, 0.92))
	btn_close.pressed.connect(close_modal)
	hdr.add_child(btn_close)

	# Knight Online Başarı/Başarısızlık Işık Şeridi (Sarı / Kırmızı Parlak Şerit)
	_beam_panel = PanelContainer.new()
	_beam_panel.name = "ResultBeam"
	_beam_panel.visible = false
	_beam_panel.custom_minimum_size = Vector2(0, 62)
	main_vb.add_child(_beam_panel)

	_beam_label = Label.new()
	_beam_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_beam_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_beam_label.add_theme_font_override("font", FontCinzelBold)
	_beam_label.add_theme_font_size_override("font_size", 26)
	_beam_panel.add_child(_beam_label)

	var scroll_body := ScrollContainer.new()
	scroll_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_body.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vb.add_child(scroll_body)
	_body_scroll = scroll_body

	var body_vb := VBoxContainer.new()
	body_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_vb.add_theme_constant_override("separation", 14)
	scroll_body.add_child(body_vb)

	# Üç Sütunlu Knight Online Örs Alanı: [Sol Eşya Slotu] [Orta 3x3 Parşömen Slotu] [Sağ Parşömen Dükkanı]
	var stage_hb := HBoxContainer.new()
	stage_hb.add_theme_constant_override("separation", 14)
	body_vb.add_child(stage_hb)

	# Sol: Seçili Eşya Slotu
	var left_panel := PanelContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.custom_minimum_size = Vector2(250, 310)
	var lp_sb := _dark_box_sb(Color(0.12, 0.10, 0.17, 0.98), Color(0.84, 0.68, 0.32, 0.90))
	left_panel.add_theme_stylebox_override("panel", lp_sb)
	stage_hb.add_child(left_panel)

	var left_vb := VBoxContainer.new()
	left_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	left_vb.add_theme_constant_override("separation", 8)
	left_panel.add_child(left_vb)

	var l_hdr := Label.new()
	l_hdr.text = "HEDEF EŞYA"
	l_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l_hdr.add_theme_font_override("font", FontCinzelBold)
	l_hdr.add_theme_font_size_override("font_size", 19)
	l_hdr.add_theme_color_override("font_color", Color(0.95, 0.80, 0.42))
	left_vb.add_child(l_hdr)

	_target_slot = TargetItemSlot.new()
	_target_slot.name = "TargetItemSlot"
	_target_slot.custom_minimum_size = Vector2(138, 138)
	_target_slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_target_slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_target_slot.add_theme_stylebox_override("panel", _dark_box_sb(Color(0.07, 0.06, 0.10, 1.0), Color(0.65, 0.54, 0.30, 0.9)))
	_target_slot.item_dropped.connect(_on_target_item_dropped)
	_target_slot.slot_cleared.connect(_on_target_slot_cleared)
	left_vb.add_child(_target_slot)

	_target_icon = TextureRect.new()
	_target_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_target_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_target_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target_slot.add_child(_target_icon)

	_target_name_lbl = Label.new()
	_target_name_lbl.text = "Eşya Seçin"
	_target_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_target_name_lbl.add_theme_font_override("font", FontNunitoBold)
	_target_name_lbl.add_theme_font_size_override("font_size", 21)
	_target_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.94, 0.78))
	left_vb.add_child(_target_name_lbl)

	_target_sub_lbl = Label.new()
	_target_sub_lbl.text = "Alttan takılı olmayan eşya seç"
	_target_sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_target_sub_lbl.add_theme_font_override("font", FontNunitoSemiBold)
	_target_sub_lbl.add_theme_font_size_override("font_size", 17)
	_target_sub_lbl.add_theme_color_override("font_color", Color(0.75, 0.76, 0.82))
	left_vb.add_child(_target_sub_lbl)

	# Orta: 3x3 (9 Slot) Knight Online Parşömen Izgarası
	var center_panel := PanelContainer.new()
	center_panel.custom_minimum_size = Vector2(310, 310)
	center_panel.add_theme_stylebox_override("panel", _dark_box_sb(Color(0.11, 0.10, 0.16, 0.98), Color(0.84, 0.68, 0.32, 0.90)))
	stage_hb.add_child(center_panel)

	var center_vb := VBoxContainer.new()
	center_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	center_vb.add_theme_constant_override("separation", 8)
	center_panel.add_child(center_vb)

	var c_hdr := Label.new()
	c_hdr.text = "PARŞÖMEN YUVASI (9 SLOT)"
	c_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c_hdr.add_theme_font_override("font", FontCinzelBold)
	c_hdr.add_theme_font_size_override("font_size", 18)
	c_hdr.add_theme_color_override("font_color", Color(0.65, 0.88, 1.0))
	center_vb.add_child(c_hdr)

	var grid_3x3 := GridContainer.new()
	grid_3x3.name = "AnvilScrollGrid"
	grid_3x3.columns = 3
	grid_3x3.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid_3x3.add_theme_constant_override("h_separation", 8)
	grid_3x3.add_theme_constant_override("v_separation", 8)
	center_vb.add_child(grid_3x3)

	_grid_slots.clear()
	_grid_icons.clear()
	for idx in range(9):
		var gs_slot := AnvilGridSlot.new()
		gs_slot.name = "GridSlot_%d" % idx
		gs_slot.slot_index = idx
		gs_slot.custom_minimum_size = Vector2(76, 76)
		gs_slot.add_theme_stylebox_override("panel", _dark_box_sb(Color(0.06, 0.06, 0.09, 1.0), Color(0.45, 0.42, 0.56, 0.85)))
		gs_slot.slot_dropped.connect(_on_anvil_slot_dropped)
		gs_slot.slot_clicked.connect(_on_anvil_slot_clicked)
		var ic := TextureRect.new()
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gs_slot.add_child(ic)
		grid_3x3.add_child(gs_slot)
		_grid_slots.append(gs_slot)
		_grid_icons.append(ic)

	# Sağ: Parşömen Dükkanı + Envanterdeki Parşömen
	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.custom_minimum_size = Vector2(260, 310)
	right_panel.add_theme_stylebox_override("panel", _dark_box_sb(Color(0.12, 0.10, 0.17, 0.98), Color(0.48, 0.72, 0.96, 0.85)))
	stage_hb.add_child(right_panel)

	var right_vb := VBoxContainer.new()
	right_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	right_vb.add_theme_constant_override("separation", 8)
	right_panel.add_child(right_vb)

	var r_hdr := Label.new()
	r_hdr.text = "PARŞÖMEN DÜKKANI"
	r_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r_hdr.add_theme_font_override("font", FontCinzelBold)
	r_hdr.add_theme_font_size_override("font_size", 18)
	r_hdr.add_theme_color_override("font_color", Color(0.65, 0.88, 1.0))
	right_vb.add_child(r_hdr)

	_shop_tile = ScrollDragTile.new()
	_shop_tile.name = "BtnShopUpgradeScroll"
	_shop_tile.is_shop = true
	_shop_tile.custom_minimum_size = Vector2(96, 96)
	_shop_tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_shop_tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_shop_tile.add_theme_stylebox_override("panel", _dark_box_sb(Color(0.08, 0.09, 0.14, 1.0), Color(0.95, 0.78, 0.36, 0.95)))
	_shop_tile.tile_pressed.connect(_prompt_buy_scroll_with_resources)
	right_vb.add_child(_shop_tile)

	var shop_tr := TextureRect.new()
	shop_tr.texture = TexUpgradeScroll
	shop_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shop_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	shop_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shop_tile.add_child(shop_tr)

	var shop_cost_lbl := Label.new()
	shop_cost_lbl.text = "5.000 Odun · 5.000 Taş · 5.000 Demir"
	shop_cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_cost_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shop_cost_lbl.add_theme_font_override("font", FontNunitoBold)
	shop_cost_lbl.add_theme_font_size_override("font_size", 16)
	shop_cost_lbl.add_theme_color_override("font_color", Color(0.96, 0.90, 0.72))
	right_vb.add_child(shop_cost_lbl)

	var btn_buy_res := Button.new()
	btn_buy_res.name = "BtnBuyScrollResources"
	btn_buy_res.text = "🪵 Hammadde İle Satın Al"
	btn_buy_res.custom_minimum_size = Vector2(0, 46)
	_style_btn(btn_buy_res, Color(0.46, 0.28, 0.09, 0.98), Color(0.96, 0.78, 0.34, 0.98), Color(1.0, 0.95, 0.82))
	btn_buy_res.pressed.connect(func(): _prompt_buy_scroll_with_resources())
	right_vb.add_child(btn_buy_res)

	var btn_buy_diamond := Button.new()
	btn_buy_diamond.name = "BtnBuyScrollDiamonds"
	btn_buy_diamond.text = "5 Elmas ile Satın Al"
	btn_buy_diamond.icon = TexDiamond
	btn_buy_diamond.expand_icon = true
	btn_buy_diamond.custom_minimum_size = Vector2(0, 46)
	_style_btn(btn_buy_diamond, Color(0.14, 0.26, 0.48, 0.98), Color(0.55, 0.85, 1.0, 0.98), Color(0.92, 0.97, 1.0))
	btn_buy_diamond.pressed.connect(_on_buy_scroll_diamonds_pressed)
	right_vb.add_child(btn_buy_diamond)

	# Oran, Uyarı & Önizleme Kutusu
	_info_panel = PanelContainer.new()
	_info_panel.add_theme_stylebox_override("panel", _dark_box_sb(Color(0.13, 0.11, 0.17, 0.96), Color(0.55, 0.48, 0.34, 0.85)))
	body_vb.add_child(_info_panel)

	var info_vb := VBoxContainer.new()
	info_vb.add_theme_constant_override("separation", 6)
	_info_panel.add_child(info_vb)

	_rate_lbl = Label.new()
	_rate_lbl.text = "Başarı Oranı: —"
	_rate_lbl.add_theme_font_override("font", FontNunitoBold)
	_rate_lbl.add_theme_font_size_override("font_size", 22)
	_rate_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.46))
	info_vb.add_child(_rate_lbl)

	_warn_lbl = Label.new()
	_warn_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warn_lbl.add_theme_font_override("font", FontNunitoBold)
	_warn_lbl.add_theme_font_size_override("font_size", 19)
	_warn_lbl.add_theme_color_override("font_color", Color(1.0, 0.46, 0.42))
	info_vb.add_child(_warn_lbl)

	# Önizleme Kutusu
	_preview_box = PanelContainer.new()
	_preview_box.visible = false
	_preview_box.add_theme_stylebox_override("panel", _dark_box_sb(Color(0.10, 0.17, 0.24, 0.96), Color(0.45, 0.86, 1.0, 0.92)))
	body_vb.add_child(_preview_box)

	var prev_hb := HBoxContainer.new()
	prev_hb.add_theme_constant_override("separation", 10)
	_preview_box.add_child(prev_hb)

	_preview_lbl = Label.new()
	_preview_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_lbl.add_theme_font_override("font", FontNunitoBold)
	_preview_lbl.add_theme_font_size_override("font_size", 20)
	_preview_lbl.add_theme_color_override("font_color", Color(0.84, 0.96, 1.0))
	prev_hb.add_child(_preview_lbl)

	_btn_cancel_preview = Button.new()
	_btn_cancel_preview.name = "BtnCancelPreview"
	_btn_cancel_preview.text = "İptal"
	_btn_cancel_preview.custom_minimum_size = Vector2(105, 48)
	_style_btn(_btn_cancel_preview, Color(0.28, 0.18, 0.20, 0.96), Color(0.85, 0.55, 0.55, 0.9), Color(1, 0.92, 0.92))
	_btn_cancel_preview.pressed.connect(func():
		_preview_active = false
		_refresh_all()
	)
	prev_hb.add_child(_btn_cancel_preview)

	# Aksiyon Butonları
	var act_hb := HBoxContainer.new()
	act_hb.add_theme_constant_override("separation", 14)
	body_vb.add_child(act_hb)

	_btn_preview = Button.new()
	_btn_preview.name = "BtnPreviewUpgrade"
	_btn_preview.text = "👁️ Önizle"
	_btn_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_preview.custom_minimum_size = Vector2(0, 62)
	_style_btn(_btn_preview, Color(0.16, 0.28, 0.44, 0.98), Color(0.45, 0.80, 1.0, 0.98), Color(0.92, 0.98, 1.0))
	_btn_preview.pressed.connect(_on_preview_pressed)
	act_hb.add_child(_btn_preview)

	_btn_upgrade = Button.new()
	_btn_upgrade.name = "BtnDoUpgrade"
	_btn_upgrade.text = "🔥 GELİŞTİR"
	_btn_upgrade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_upgrade.custom_minimum_size = Vector2(0, 62)
	_style_btn(_btn_upgrade, Color(0.56, 0.32, 0.08, 0.98), Color(1.0, 0.84, 0.32, 1.0), Color(1.0, 0.97, 0.86))
	_btn_upgrade.pressed.connect(_on_upgrade_pressed)
	act_hb.add_child(_btn_upgrade)

	# Envanter Parşömeni + Yükseltilebilir Ekipmanlar
	var inv_hdr_hb := HBoxContainer.new()
	inv_hdr_hb.add_theme_constant_override("separation", 12)
	body_vb.add_child(inv_hdr_hb)

	var inv_title := Label.new()
	inv_title.text = "GELİŞTİRİLEBİLİR ENVANTER (Sadece Takılı Olmayanlar)"
	inv_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv_title.add_theme_font_override("font", FontCinzelBold)
	inv_title.add_theme_font_size_override("font_size", 20)
	inv_title.add_theme_color_override("font_color", Color(0.98, 0.86, 0.48))
	inv_hdr_hb.add_child(inv_title)

	_scroll_badge_lbl = Label.new()
	_scroll_badge_lbl.add_theme_font_override("font", FontNunitoBold)
	_scroll_badge_lbl.add_theme_font_size_override("font_size", 20)
	_scroll_badge_lbl.add_theme_color_override("font_color", Color(0.65, 0.90, 1.0))
	inv_hdr_hb.add_child(_scroll_badge_lbl)

	# Envanter Parşömeni Sürükle/Tıkla Kartı
	var scroll_bar := PanelContainer.new()
	scroll_bar.add_theme_stylebox_override("panel", _dark_box_sb(Color(0.11, 0.14, 0.21, 0.95), Color(0.45, 0.78, 1.0, 0.85)))
	body_vb.add_child(scroll_bar)

	var sb_hb := HBoxContainer.new()
	sb_hb.add_theme_constant_override("separation", 12)
	scroll_bar.add_child(sb_hb)

	_inv_scroll_tile = ScrollDragTile.new()
	_inv_scroll_tile.name = "InvUpgradeScrollTile"
	_inv_scroll_tile.is_shop = false
	_inv_scroll_tile.custom_minimum_size = Vector2(72, 72)
	_inv_scroll_tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_inv_scroll_tile.add_theme_stylebox_override("panel", _dark_box_sb(Color(0.07, 0.08, 0.12, 1.0), Color(0.95, 0.80, 0.36, 0.9)))
	_inv_scroll_tile.tile_pressed.connect(_on_inv_scroll_clicked)
	sb_hb.add_child(_inv_scroll_tile)

	var inv_sc_tr := TextureRect.new()
	inv_sc_tr.texture = TexUpgradeScroll
	inv_sc_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	inv_sc_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	inv_sc_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inv_scroll_tile.add_child(inv_sc_tr)

	var sc_help := Label.new()
	sc_help.text = "Geliştirme Parşömeni · Örse yerleştirmek için dokunun veya 3×3 yuvaya sürükleyin."
	sc_help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sc_help.add_theme_font_override("font", FontNunitoSemiBold)
	sc_help.add_theme_font_size_override("font_size", 19)
	sc_help.add_theme_color_override("font_color", Color(0.90, 0.94, 1.0))
	sb_hb.add_child(sc_help)

	_inv_grid = GridContainer.new()
	_inv_grid.columns = 2
	_inv_grid.add_theme_constant_override("h_separation", 10)
	_inv_grid.add_theme_constant_override("v_separation", 10)
	body_vb.add_child(_inv_grid)

	_empty_inv_lbl = Label.new()
	_empty_inv_lbl.text = "Geliştirilebilecek boşta ekipman bulunmuyor. Takılı ekipmanları önce Lord ekranından çıkarın."
	_empty_inv_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_inv_lbl.add_theme_font_override("font", FontNunitoSemiBold)
	_empty_inv_lbl.add_theme_font_size_override("font_size", 19)
	_empty_inv_lbl.add_theme_color_override("font_color", Color(0.75, 0.72, 0.78))
	body_vb.add_child(_empty_inv_lbl)


func _on_inv_scroll_clicked() -> void:
	var lm := _lord_mgr()
	var sc := int(lm.call("get_scroll_count")) if lm != null else 0
	if sc <= 0:
		_prompt_buy_scroll_with_resources()
		return
	_placed_scroll_slot = 0 if _placed_scroll_slot < 0 else -1
	_refresh_all()


func _on_anvil_slot_clicked(idx: int) -> void:
	var lm := _lord_mgr()
	var sc := int(lm.call("get_scroll_count")) if lm != null else 0
	if _placed_scroll_slot == idx:
		_placed_scroll_slot = -1
	elif sc > 0:
		_placed_scroll_slot = idx
	else:
		_prompt_buy_scroll_with_resources()
		return
	_refresh_all()


func _on_anvil_slot_dropped(payload: Dictionary, idx: int) -> void:
	var kind := str(payload.get("kind", ""))
	if kind == "upgrade_scroll_shop":
		_prompt_buy_scroll_with_resources(idx)
		return
	if kind == "upgrade_scroll":
		var lm := _lord_mgr()
		var sc := int(lm.call("get_scroll_count")) if lm != null else 0
		if sc > 0:
			_placed_scroll_slot = idx
			_refresh_all()


func _refresh_all() -> void:
	if not _ui_built:
		return
	var lm := _lord_mgr()
	if lm == null:
		return
	var ld: Dictionary = lm.call("get_lord_state")
	var scroll_cnt := int(ld.get("upgrade_scrolls", 0))
	if scroll_cnt <= 0:
		_placed_scroll_slot = -1

	_inv_scroll_tile.scroll_count = scroll_cnt
	_scroll_badge_lbl.text = "📜 Parşömen: %d" % scroll_cnt

	# 3x3 Parşömen ızgarasını güncelle
	for idx in range(9):
		var placed := (idx == _placed_scroll_slot and scroll_cnt > 0)
		_grid_slots[idx].has_scroll = placed
		_grid_icons[idx].texture = TexUpgradeScroll if placed else null
		var border_col := Color(1.0, 0.86, 0.32, 1.0) if placed else Color(0.42, 0.40, 0.54, 0.82)
		var bg_col := Color(0.18, 0.14, 0.08, 1.0) if placed else Color(0.06, 0.06, 0.09, 1.0)
		_grid_slots[idx].add_theme_stylebox_override("panel", _dark_box_sb(bg_col, border_col))

	var items: Array[Dictionary] = lm.call("get_unequipped_items")
	var selected_item := {}
	if not _selected_item_id.is_empty():
		for it in items:
			if str(it.get("id", "")) == _selected_item_id:
				selected_item = it
				break
	if selected_item.is_empty():
		_selected_item_id = ""
		_preview_active = false

	# Sol hedef slotu güncelle
	if selected_item.is_empty():
		_target_icon.texture = null
		_target_name_lbl.text = "Boş Slot"
		_target_name_lbl.add_theme_color_override("font_color", Color(0.86, 0.84, 0.78))
		_target_sub_lbl.text = "Aşağıdan eşyaya dokunun veya sürükleyin"
		if _target_slot != null:
			_target_slot.add_theme_stylebox_override("panel", _dark_box_sb(Color(0.07, 0.06, 0.10, 1.0), Color(0.55, 0.48, 0.30, 0.85)))
		_rate_lbl.text = "Başarı Oranı: Eşya ve parşömen yerleştirin"
		_warn_lbl.text = ""
		_warn_lbl.hide()
		_preview_box.hide()
		_btn_preview.disabled = true
		_btn_upgrade.disabled = true
	else:
		var st_type := str(selected_item.get("slot_type", "sword"))
		var cur_plus := int(selected_item.get("plus", 0))
		var rar := str(selected_item.get("rarity", "common"))
		_target_icon.texture = load(LordModelScript.icon_path_for(st_type)) as Texture2D
		if _target_slot != null:
			_target_slot.add_theme_stylebox_override("panel", _dark_box_sb(Color(0.11, 0.09, 0.16, 1.0), LordModelScript.rarity_color(rar)))
		_target_name_lbl.text = "%s (+%d)" % [str(selected_item.get("name", "Ekipman")), cur_plus]
		_target_name_lbl.add_theme_color_override("font_color", LordModelScript.rarity_color(rar))
		_target_sub_lbl.text = "%s · %s" % [LordModelScript.rarity_label(rar), LordModelScript.format_item_short_bonus(selected_item)]
		if cur_plus >= LordModelScript.MAX_PLUS:
			_rate_lbl.text = "Eşya maksimum (+8) seviyesinde!"
			_warn_lbl.hide()
			_preview_box.hide()
			_btn_preview.disabled = true
			_btn_upgrade.disabled = true
		else:
			var rate := LordModelScript.upgrade_rate_for_plus(cur_plus)
			_rate_lbl.text = "+%d → +%d Yükseltme · Başarı Oranı: %%%d" % [cur_plus, cur_plus + 1, rate]
			if rate < 100:
				_warn_lbl.text = "⚠️ Dikkat: Başarısız olursa bu eşya ve parşömen kalıcı olarak YOK OLUR!"
				_warn_lbl.show()
			else:
				_warn_lbl.text = "✅ +%d → +%d seviyesinde yanma riski yoktur (%%100 başarı)." % [cur_plus, cur_plus + 1]
				_warn_lbl.add_theme_color_override("font_color", Color(0.55, 0.94, 0.64))
				_warn_lbl.show()
			if rate < 100:
				_warn_lbl.add_theme_color_override("font_color", Color(1.0, 0.46, 0.42))
			_btn_preview.disabled = false
			_btn_upgrade.disabled = (_placed_scroll_slot < 0 or scroll_cnt <= 0)
			if _preview_active:
				var pv: Dictionary = lm.call("preview_upgrade", _selected_item_id)
				if bool(pv.get("ok", false)):
					var cur_txt := LordModelScript.format_item_short_bonus(selected_item, cur_plus)
					var nxt_txt := LordModelScript.format_item_short_bonus(selected_item, cur_plus + 1)
					_preview_lbl.text = "👁️ Önizleme (+%d → +%d):\nŞimdi: %s\nSonra: %s" % [cur_plus, cur_plus + 1, cur_txt, nxt_txt]
					_preview_box.show()
				else:
					_preview_box.hide()
			else:
				_preview_box.hide()

	# Envanter listesi (parşömenler + sadece takılı olmayan ekipmanlar)
	for ch in _inv_grid.get_children():
		_inv_grid.remove_child(ch)
		ch.queue_free()

	if scroll_cnt > 0:
		var is_placed_sc := (_placed_scroll_slot >= 0)
		var sc_card := ScrollDragTile.new()
		sc_card.name = "InvUpgradeScrollCard"
		sc_card.is_shop = false
		sc_card.scroll_count = scroll_cnt
		sc_card.custom_minimum_size = Vector2(0, 88)
		sc_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc_card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var sc_border := Color(1.0, 0.86, 0.30, 1.0) if is_placed_sc else Color(0.55, 0.86, 1.0, 0.95)
		var sc_bg := Color(0.20, 0.16, 0.09, 0.98) if is_placed_sc else Color(0.10, 0.14, 0.22, 0.96)
		sc_card.add_theme_stylebox_override("panel", _dark_box_sb(sc_bg, sc_border))
		sc_card.tile_pressed.connect(_on_inv_scroll_clicked)

		var sc_hb := HBoxContainer.new()
		sc_hb.add_theme_constant_override("separation", 10)
		sc_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sc_card.add_child(sc_hb)

		var sc_ic := TextureRect.new()
		sc_ic.texture = TexUpgradeScroll
		sc_ic.custom_minimum_size = Vector2(60, 60)
		sc_ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sc_ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sc_ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sc_ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sc_hb.add_child(sc_ic)

		var sc_vb := VBoxContainer.new()
		sc_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc_vb.alignment = BoxContainer.ALIGNMENT_CENTER
		sc_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sc_hb.add_child(sc_vb)

		var sc_nl := Label.new()
		sc_nl.text = "Geliştirme Parşömeni (x%d)" % scroll_cnt
		sc_nl.add_theme_font_override("font", FontNunitoBold)
		sc_nl.add_theme_font_size_override("font_size", 19)
		sc_nl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.46) if is_placed_sc else Color(0.72, 0.92, 1.0))
		sc_nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sc_vb.add_child(sc_nl)

		var sc_sl := Label.new()
		sc_sl.text = "✓ Örste Yerleştirildi (Çıkar)" if is_placed_sc else "Sürükle veya Dokun · Örse Koy"
		sc_sl.add_theme_font_override("font", FontNunitoSemiBold)
		sc_sl.add_theme_font_size_override("font_size", 15)
		sc_sl.add_theme_color_override("font_color", Color(0.70, 0.96, 0.72) if is_placed_sc else Color(0.84, 0.88, 0.94))
		sc_sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sc_vb.add_child(sc_sl)

		_inv_grid.add_child(sc_card)

	_empty_inv_lbl.visible = items.is_empty()
	if items.is_empty():
		if scroll_cnt > 0:
			_empty_inv_lbl.text = "Geliştirilebilecek boşta ekipman bulunmuyor. Parşömeniniz hazır — takılı ekipmanı Lord ekranından çıkarıp geliştirebilirsiniz."
		else:
			_empty_inv_lbl.text = "Geliştirilebilecek boşta ekipman bulunmuyor. Takılı ekipmanları önce Lord ekranından çıkarın."
	for it in items:
		var iid := str(it.get("id", ""))
		var plus := int(it.get("plus", 0))
		var rar := str(it.get("rarity", "common"))
		var is_sel := (iid == _selected_item_id)
		var ic_tex := load(LordModelScript.icon_path_for(str(it.get("slot_type", "sword")))) as Texture2D

		var card := ItemDragCard.new()
		card.name = "InvItemCard_%s" % iid
		card.item_id = iid
		card.icon_tex = ic_tex
		card.custom_minimum_size = Vector2(0, 88)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var b_col := Color(1.0, 0.86, 0.30, 1.0) if is_sel else LordModelScript.rarity_color(rar)
		var bg_col := Color(0.20, 0.16, 0.09, 0.98) if is_sel else Color(0.11, 0.10, 0.16, 0.96)
		card.add_theme_stylebox_override("panel", _dark_box_sb(bg_col, b_col))
		card.item_pressed.connect(_on_inv_item_selected)

		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(hb)

		var ic := TextureRect.new()
		ic.texture = ic_tex
		ic.custom_minimum_size = Vector2(60, 60)
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
		nl.text = "%s (+%d)" % [str(it.get("name", "Ekipman")), plus]
		nl.add_theme_font_override("font", FontNunitoBold)
		nl.add_theme_font_size_override("font_size", 19)
		nl.add_theme_color_override("font_color", LordModelScript.rarity_color(rar))
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tx_vb.add_child(nl)

		var sl := Label.new()
		sl.text = LordModelScript.format_item_short_bonus(it)
		sl.add_theme_font_override("font", FontNunitoSemiBold)
		sl.add_theme_font_size_override("font_size", 16)
		sl.add_theme_color_override("font_color", Color(0.84, 0.86, 0.90))
		sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tx_vb.add_child(sl)

		_inv_grid.add_child(card)


func _on_inv_item_selected(iid: String) -> void:
	_selected_item_id = "" if _selected_item_id == iid else iid
	_preview_active = false
	_refresh_all()


func _on_target_item_dropped(iid: String) -> void:
	if iid.is_empty():
		return
	_selected_item_id = iid
	_preview_active = false
	_refresh_all()


func _on_target_slot_cleared() -> void:
	if _selected_item_id.is_empty():
		return
	_selected_item_id = ""
	_preview_active = false
	_refresh_all()


func _on_preview_pressed() -> void:
	if _selected_item_id.is_empty():
		return
	_preview_active = not _preview_active
	_refresh_all()


func _on_upgrade_pressed() -> void:
	var lm := _lord_mgr()
	if lm == null or _selected_item_id.is_empty() or _placed_scroll_slot < 0:
		return
	var pv: Dictionary = lm.call("preview_upgrade", _selected_item_id)
	if not bool(pv.get("ok", false)):
		return
	if bool(pv.get("destroys_on_fail", false)):
		var rate := int(pv.get("rate", 0))
		var cur_p := int(pv.get("cur_plus", 0))
		var nxt_p := int(pv.get("next_plus", 1))
		_show_confirm_dialog(
			"Geliştirmeyi Onayla",
			"+%d → +%d başarı şansı %%%d.\nBaşarısız olursa eşya ve parşömen kalıcı olarak YOK OLUR!\nDevam edilsin mi?" % [cur_p, nxt_p, rate],
			"🔥 Geliştir",
			func(): _execute_upgrade()
		)
	else:
		_execute_upgrade()


func _execute_upgrade() -> void:
	var lm := _lord_mgr()
	if lm == null:
		return
	var res: Dictionary = lm.call("upgrade_item", _selected_item_id)
	if not bool(res.get("ok", false)):
		_show_beam(false, str(res.get("error", "Geliştirme yapılamadı.")))
		return
	_preview_active = false
	_placed_scroll_slot = -1
	if bool(res.get("upgraded", false)):
		_show_beam(true, "✨ GELİŞTİRME BAŞARILI! (+%d → +%d)" % [int(res.get("old_plus", 0)), int(res.get("new_plus", 1))])
	else:
		_selected_item_id = ""
		_show_beam(false, "💥 GELİŞTİRME BAŞARISIZ! Eşya Yandı ve Yok Oldu!")
	_refresh_all()


func _show_beam(success: bool, msg: String) -> void:
	if _beam_tween != null and _beam_tween.is_valid():
		_beam_tween.kill()
	var sb := StyleBoxFlat.new()
	if success:
		sb.bg_color = Color(0.95, 0.78, 0.14, 0.96)
		sb.border_color = Color(1.0, 0.96, 0.56, 1.0)
		_beam_label.add_theme_color_override("font_color", Color(0.14, 0.08, 0.02))
	else:
		sb.bg_color = Color(0.86, 0.14, 0.16, 0.96)
		sb.border_color = Color(1.0, 0.56, 0.56, 1.0)
		_beam_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.95))
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(12)
	_beam_panel.add_theme_stylebox_override("panel", sb)
	_beam_label.text = msg
	_beam_panel.modulate = Color(1, 1, 1, 1)
	_beam_panel.show()
	_beam_tween = create_tween()
	_beam_tween.tween_property(_beam_panel, "modulate:a", 0.72, 0.28)
	_beam_tween.tween_property(_beam_panel, "modulate:a", 1.0, 0.28)
	_beam_tween.tween_interval(3.0)
	_beam_tween.tween_property(_beam_panel, "modulate:a", 0.0, 0.45)
	_beam_tween.tween_callback(_beam_panel.hide)


func _get_current_diamonds() -> int:
	var loop := Engine.get_main_loop()
	if loop is SceneTree and (loop as SceneTree).root != null:
		var root := (loop as SceneTree).root
		var sm: Node = root.get_node_or_null("StoreManager")
		if sm != null and sm.has_method("get_diamonds"):
			return int(sm.call("get_diamonds"))
		var gs: Node = root.get_node_or_null("GameState")
		if gs != null and typeof(gs.get("player")) == TYPE_DICTIONARY:
			return maxi(0, int((gs.get("player") as Dictionary).get("diamonds", 0)))
	return 0


func _on_buy_scroll_diamonds_pressed() -> void:
	const DIAMOND_COST := 5
	var diamonds := _get_current_diamonds()
	if diamonds >= DIAMOND_COST:
		_show_confirm_dialog(
			"5 Elmas ile Parşömen Satın Al",
			"1 adet Lord Geliştirme Parşömeni satın almak için 5 Elmas kullanılacaktır.\n(Mevcut Elmas: %d)\n\nOnaylıyor musunuz?" % diamonds,
			"Evet (5 Elmas)",
			func(): _execute_buy_scroll_with_diamonds()
		)
	else:
		close_modal()
		if open_market_diamonds_requested.get_connections().size() > 0:
			open_market_diamonds_requested.emit()
		else:
			var loop := Engine.get_main_loop()
			if loop is SceneTree and (loop as SceneTree).root != null:
				var sm: Node = (loop as SceneTree).root.get_node_or_null("StoreManager")
				if sm != null and sm.has_method("open_market"):
					var host: Node = get_parent() if get_parent() != null else (loop as SceneTree).current_scene
					sm.call("open_market", host, "diamonds")


func _execute_buy_scroll_with_diamonds() -> void:
	var loop := Engine.get_main_loop()
	var sm: Node = (loop as SceneTree).root.get_node_or_null("StoreManager") if loop is SceneTree and (loop as SceneTree).root != null else null
	if sm == null or not sm.has_method("buy_scroll"):
		_show_beam(false, "Mağaza servisi hazır değil.")
		return
	var res: Dictionary = sm.call("buy_scroll", "lord_upgrade_scroll", 1)
	if bool(res.get("ok", false)):
		_show_beam(true, "💎 5 Elmas ile Geliştirme Parşömeni alındı! Envanterden örse ekleyin.")
	else:
		_show_beam(false, str(res.get("error", "Elmas ile satın alma başarısız.")))
	_refresh_all()


func _prompt_buy_scroll_with_resources(auto_place_slot: int = -1) -> void:
	_show_confirm_dialog(
		"Geliştirme Parşömeni Satın Al",
		"1 adet Lord Geliştirme Parşömeni satın almak için aktif köy deposundan:\n• 5.000 Odun\n• 5.000 Taş\n• 5.000 Demir\nharcanacaktır. Onaylıyor musunuz?",
		"📜 Satın Al",
		func():
			var lm := _lord_mgr()
			if lm == null:
				return
			var res: Dictionary = lm.call("buy_scroll_with_resources")
			if bool(res.get("ok", false)):
				if auto_place_slot >= 0:
					_placed_scroll_slot = auto_place_slot
				elif _placed_scroll_slot < 0:
					_placed_scroll_slot = 0
				_show_beam(true, "📜 Geliştirme Parşömeni alındı!")
			else:
				_show_beam(false, str(res.get("error", "Satın alma başarısız.")))
			_refresh_all()
	)


func _clear_confirm_layer() -> void:
	if _confirm_layer != null and is_instance_valid(_confirm_layer):
		if _confirm_layer.get_parent() != null:
			_confirm_layer.get_parent().remove_child(_confirm_layer)
		_confirm_layer.queue_free()
	_confirm_layer = null


func _show_confirm_dialog(title_txt: String, body_txt: String, ok_txt: String, on_ok: Callable) -> void:
	_clear_confirm_layer()
	_confirm_layer = Control.new()
	_confirm_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_root_ctrl.add_child(_confirm_layer)

	var d := ColorRect.new()
	d.set_anchors_preset(Control.PRESET_FULL_RECT)
	d.color = Color(0, 0, 0, 0.72)
	d.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_layer.add_child(d)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_layer.add_child(cc)

	var pnl := PanelContainer.new()
	pnl.custom_minimum_size = Vector2(720, 0)
	pnl.add_theme_stylebox_override("panel", _dark_box_sb(Color(0.11, 0.09, 0.15, 0.99), Color(0.95, 0.76, 0.34, 1.0)))
	cc.add_child(pnl)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	pnl.add_child(vb)

	var tl := Label.new()
	tl.text = title_txt
	tl.add_theme_font_override("font", FontCinzelBold)
	tl.add_theme_font_size_override("font_size", 26)
	tl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	vb.add_child(tl)

	var bl := Label.new()
	bl.text = body_txt
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bl.add_theme_font_override("font", FontNunitoBold)
	bl.add_theme_font_size_override("font_size", 22)
	bl.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	vb.add_child(bl)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	vb.add_child(hb)

	var b_no := Button.new()
	b_no.name = "BtnConfirmDialogNo"
	b_no.text = "İptal"
	b_no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_no.custom_minimum_size = Vector2(0, 56)
	_style_btn(b_no, Color(0.24, 0.20, 0.26, 0.96), Color(0.65, 0.62, 0.72, 0.9), Color(0.95, 0.95, 0.98))
	b_no.pressed.connect(func():
		_clear_confirm_layer()
	)
	hb.add_child(b_no)

	var b_yes := Button.new()
	b_yes.name = "BtnConfirmDialogYes"
	b_yes.text = ok_txt
	b_yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_yes.custom_minimum_size = Vector2(0, 56)
	_style_btn(b_yes, Color(0.56, 0.30, 0.08, 0.98), Color(1.0, 0.84, 0.32, 1.0), Color(1.0, 0.97, 0.88))
	b_yes.pressed.connect(func():
		_clear_confirm_layer()
		on_ok.call()
	)
	hb.add_child(b_yes)


func _dark_box_sb(bg: Color, border: Color) -> StyleBoxFlat:
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
	btn.add_theme_font_size_override("font_size", 22)
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
	var dis := sb.duplicate() as StyleBoxFlat
	dis.bg_color = Color(0.16, 0.16, 0.20, 0.72)
	dis.border_color = Color(0.35, 0.35, 0.42, 0.6)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", hov)
	btn.add_theme_stylebox_override("pressed", hov)
	btn.add_theme_stylebox_override("disabled", dis)
