extends Control
## BuildingView — King's Age Orijinal Tarzı Profesyonel 2.5D Köy Binası Hotspot ve Büyük Belirgin Seviye Plaketi.

signal clicked()
signal dragged(relative_delta: Vector2)

const Palette := preload("res://themes/Palette.gd")

class PolygonHitButton extends Button:
	var click_polygon: PackedVector2Array = []
	var building_view: Control = null

	func _has_point(point: Vector2) -> bool:
		if building_view != null:
			if building_view._level_badge != null and building_view._level_badge.visible and building_view._level_badge.get_rect().has_point(point):
				return true
			if building_view._name_plate != null and building_view._name_plate.visible and building_view._name_plate.get_rect().has_point(point):
				return true
		if click_polygon.is_empty():
			return Rect2(Vector2.ZERO, size).has_point(point)
		return Geometry2D.is_point_in_polygon(point, click_polygon)


var building_key: String = ""
var building_name: String = ""
var current_level: int = 0
var is_locked: bool = false
var is_upgrading: bool = false
var custom_badge_offset: Vector2 = Vector2(-1, -1)
var click_polygon: PackedVector2Array = []

# Sürükleme / Tıklama Ayrımı (Mobilde harita kaydırırken bina paneli kazara açılmasın)
var _mouse_press_pos := Vector2.ZERO
var _touch_press_pos := Vector2.ZERO
var _is_dragging := false
var _touch_active := false
var _last_click_frame: int = -1

# Düğümler
var _btn: Button
var _hover_highlight: Panel
var _sprite: TextureRect # Geriye dönük uyumluluk için var, boş bırakılır
var _name_plate: PanelContainer
var _name_label: Label
var _level_badge: PanelContainer
var _badge_label: Label

# İnşaat Düğümleri
var _scaffold_panel: Panel
var _hammer_icon: Label
var _hammer_tween: Tween
var _progress_bar: ProgressBar
var _countdown_label: Label
var _level_up_popup: Node = null


func _init() -> void:
	custom_minimum_size = Vector2.ZERO
	size = Vector2(100, 100)
	mouse_filter = MOUSE_FILTER_PASS
	resized.connect(_update_button_size)


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	if _btn != null:
		return

	# 1. Fare Üzerine Gelince (Hover) Şeffaf Vurgu Paneli (sarı kare gizlendi)
	_hover_highlight = Panel.new()
	_hover_highlight.anchors_preset = PRESET_FULL_RECT
	_hover_highlight.size = size
	_hover_highlight.mouse_filter = MOUSE_FILTER_IGNORE
	var h_sb := StyleBoxEmpty.new()
	_hover_highlight.add_theme_stylebox_override("panel", h_sb)
	_hover_highlight.hide()
	add_child(_hover_highlight)

	# 2. Kukla Sprite (Kod uyumluluğu)
	_sprite = TextureRect.new()
	_sprite.mouse_filter = MOUSE_FILTER_IGNORE
	_sprite.visible = false
	add_child(_sprite)

	# 3. İskele (Geriye uyumluluk)
	_scaffold_panel = Panel.new()
	_scaffold_panel.mouse_filter = MOUSE_FILTER_IGNORE
	_scaffold_panel.visible = false
	add_child(_scaffold_panel)

	# 4. İnşaat Çekici (🔨)
	_hammer_icon = Label.new()
	_hammer_icon.text = "🔨"
	_hammer_icon.add_theme_font_size_override("font_size", 28)
	_hammer_icon.position = Vector2(size.x - 52, -26)
	_hammer_icon.pivot_offset = Vector2(14, 26)
	_hammer_icon.mouse_filter = MOUSE_FILTER_IGNORE
	_hammer_icon.hide()
	add_child(_hammer_icon)

	# 5. Mini İnşaat İlerleme Çubuğu ve Kalan Süre
	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(90, 10)
	_progress_bar.size = Vector2(90, 10)
	_progress_bar.position = Vector2((size.x - 90) * 0.5, size.y - 10)
	_progress_bar.show_percentage = false
	_progress_bar.mouse_filter = MOUSE_FILTER_IGNORE
	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.12, 0.10, 0.08, 0.90)
	pb_bg.set_corner_radius_all(5)
	var pb_fg := StyleBoxFlat.new()
	pb_fg.bg_color = Color(0.96, 0.72, 0.22, 1.0)
	pb_fg.set_corner_radius_all(5)
	_progress_bar.add_theme_stylebox_override("background", pb_bg)
	_progress_bar.add_theme_stylebox_override("fill", pb_fg)
	_progress_bar.hide()
	add_child(_progress_bar)

	_countdown_label = Label.new()
	_countdown_label.custom_minimum_size = Vector2(90, 18)
	_countdown_label.position = Vector2((size.x - 90) * 0.5, size.y - 32)
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.add_theme_font_size_override("font_size", 13)
	_countdown_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.75))
	_countdown_label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.02, 0.95))
	_countdown_label.add_theme_constant_override("outline_size", 4)
	_countdown_label.mouse_filter = MOUSE_FILTER_IGNORE
	_countdown_label.hide()
	add_child(_countdown_label)

	# 6. King's Age Tarzı: BÜYÜK, NET, OKUNAKLI SEVİYE PLAKETİ (70x36 px)
	_level_badge = PanelContainer.new()
	_level_badge.custom_minimum_size = Vector2(70, 36)
	_level_badge.size = Vector2(70, 36)
	_level_badge.mouse_filter = MOUSE_FILTER_IGNORE

	_badge_label = Label.new()
	_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge_label.add_theme_font_override("font", preload("res://assets/fonts/Nunito-Bold.ttf"))
	_badge_label.add_theme_font_size_override("font_size", 18)
	_badge_label.text = "Sv. 1"
	_level_badge.add_child(_badge_label)
	add_child(_level_badge)

	# 7. Seviye / Kilit Rozetinin Hemen Üstünde BÜYÜK VE NET Arka Planlı Bina İsmi
	_name_plate = PanelContainer.new()
	_name_plate.mouse_filter = MOUSE_FILTER_IGNORE

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_override("font", preload("res://assets/fonts/Nunito-Bold.ttf"))
	_name_label.add_theme_font_size_override("font_size", 22)
	_name_label.mouse_filter = MOUSE_FILTER_IGNORE
	_name_label.text = building_name
	_name_plate.add_child(_name_label)
	add_child(_name_plate)
	_update_badge_position()

	# 8. Binanın Tüm Alanını Kapsayan Şeffaf Tıklama Butonu
	_btn = PolygonHitButton.new()
	_btn.flat = true
	_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty_sb := StyleBoxEmpty.new()
	_btn.add_theme_stylebox_override("normal", empty_sb)
	_btn.add_theme_stylebox_override("hover", empty_sb)
	_btn.add_theme_stylebox_override("pressed", empty_sb)
	_btn.add_theme_stylebox_override("disabled", empty_sb)
	_btn.add_theme_stylebox_override("focus", empty_sb)

	_btn.pressed.connect(func():
		if not _is_dragging:
			_trigger_click()
	)
	_btn.gui_input.connect(_on_btn_gui_input)
	_btn.mouse_entered.connect(_on_mouse_entered)
	_btn.mouse_exited.connect(_on_mouse_exited)
	add_child(_btn)
	_update_button_size()

	_update_visuals()


func _has_point(point: Vector2) -> bool:
	if _level_badge != null and _level_badge.visible and _level_badge.get_rect().has_point(point):
		return true
	if _name_plate != null and _name_plate.visible and _name_plate.get_rect().has_point(point):
		return true
	if click_polygon.is_empty():
		return Rect2(Vector2.ZERO, size).has_point(point)
	return Geometry2D.is_point_in_polygon(point, click_polygon)


func _update_button_size() -> void:
	if _btn == null:
		return
	_btn.position = Vector2.ZERO
	_btn.size = size
	_btn.custom_minimum_size = size
	if _btn is PolygonHitButton:
		var phb := _btn as PolygonHitButton
		phb.click_polygon = click_polygon
		phb.building_view = self


func cancel_press() -> void:
	_is_dragging = true


func _trigger_click() -> void:
	var current_frame := Engine.get_process_frames()
	if current_frame > 0 and current_frame == _last_click_frame:
		return
	_last_click_frame = current_frame
	clicked.emit()


func _on_btn_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touch_active = true
			_touch_press_pos = st.position
			_is_dragging = false
		else:
			if not _is_dragging:
				_trigger_click()
			_is_dragging = false
			_touch_active = false
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if not _is_dragging and (sd.position - _touch_press_pos).length() > 16.0:
			_is_dragging = true
	elif event is InputEventMouseButton:
		if _touch_active:
			return
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_mouse_press_pos = mb.global_position
				_is_dragging = false
			else:
				if not _is_dragging:
					_trigger_click()
				_is_dragging = false
	elif event is InputEventMouseMotion:
		if _touch_active:
			return
		var mm := event as InputEventMouseMotion
		if mm.button_mask & MOUSE_BUTTON_MASK_LEFT:
			if not _is_dragging and (mm.global_position - _mouse_press_pos).length() > 16.0:
				_is_dragging = true
			if _is_dragging:
				dragged.emit(mm.relative)


func _update_badge_position() -> void:
	if _level_badge == null:
		return
	if custom_badge_offset.x >= 0 and custom_badge_offset.y >= 0:
		_level_badge.position = custom_badge_offset
	else:
		_level_badge.position = Vector2(size.x - 76, 4)

	if _name_plate != null and _name_label != null:
		_name_plate.reset_size()
		var plate_sz := _name_plate.get_combined_minimum_size()
		if plate_sz.x < 70:
			plate_sz.x = 70
		if plate_sz.y < 30:
			plate_sz.y = 32
		_name_plate.size = plate_sz
		var badge_center_x := _level_badge.position.x + (_level_badge.size.x * 0.5)
		_name_plate.position = Vector2(
			badge_center_x - (plate_sz.x * 0.5),
			_level_badge.position.y - plate_sz.y - 2.0
		)
		_name_plate.show()


func setup(key: String, b_name: String, _texture_path: String = "", custom_size: Vector2 = Vector2.ZERO, badge_offset: Vector2 = Vector2(-1, -1), polygon: PackedVector2Array = PackedVector2Array()) -> void:
	building_key = key
	building_name = b_name
	click_polygon = polygon
	if custom_size != Vector2.ZERO:
		custom_minimum_size = custom_size
		size = custom_size
	if badge_offset.x >= 0 and badge_offset.y >= 0:
		custom_badge_offset = badge_offset

	_build_ui()
	_update_button_size()
	if _hover_highlight != null:
		_hover_highlight.size = size
	if _name_label != null:
		_name_label.text = b_name
	if _progress_bar != null:
		_progress_bar.position = Vector2((size.x - 90) * 0.5, size.y - 10)
	if _countdown_label != null:
		_countdown_label.position = Vector2((size.x - 90) * 0.5, size.y - 32)
	_update_badge_position()



func set_state(level: int, locked: bool, upgrading: bool, progress_pct: float = 0.0, rem_seconds: int = 0) -> void:
	current_level = level
	is_locked = locked
	is_upgrading = upgrading
	_update_visuals(progress_pct, rem_seconds)


func _update_visuals(progress_pct: float = 0.0, rem_seconds: int = 0) -> void:
	if _badge_label == null or _level_badge == null:
		return

	# BÜYÜK, KESKİN VE DERİN GÖLGELİ SEVİYE PLAKETİ
	var badge_sb := StyleBoxFlat.new()
	badge_sb.set_corner_radius_all(6)
	badge_sb.content_margin_left = 8
	badge_sb.content_margin_right = 8
	badge_sb.content_margin_top = 4
	badge_sb.content_margin_bottom = 4
	badge_sb.shadow_size = 6
	badge_sb.shadow_color = Color(0.0, 0.0, 0.0, 0.50)

	var name_sb := StyleBoxFlat.new()
	name_sb.set_corner_radius_all(6)
	name_sb.content_margin_left = 12
	name_sb.content_margin_right = 12
	name_sb.content_margin_top = 3
	name_sb.content_margin_bottom = 3
	name_sb.shadow_size = 6
	name_sb.shadow_color = Color(0.0, 0.0, 0.0, 0.50)

	if is_upgrading:
		# İnşaat: Altın sarısı kare rozet + Çekiç animasyonu
		badge_sb.bg_color = Color(0.96, 0.68, 0.18, 0.98)
		badge_sb.border_color = Color(1.0, 0.94, 0.55, 1.0)
		badge_sb.set_border_width_all(2)
		_badge_label.text = "🔨%d" % (current_level + 1)
		_badge_label.add_theme_color_override("font_color", Color(1, 1, 1))

		name_sb.bg_color = Color(0.96, 0.68, 0.18, 0.98)
		name_sb.border_color = Color(1.0, 0.94, 0.55, 1.0)
		name_sb.set_border_width_all(2)
		if _name_label != null:
			_name_label.add_theme_color_override("font_color", Color(0.16, 0.12, 0.08))

		_hammer_icon.show()
		_progress_bar.show()
		_progress_bar.value = progress_pct
		_countdown_label.show()
		_countdown_label.text = "%02d:%02d" % [rem_seconds / 60, rem_seconds % 60]
		_start_hammer_anim()

	elif current_level > 0:
		# Aktif Seviye: King's Age orijinal parşömen beyazı kutu (büyük ve net)
		badge_sb.bg_color = Color(0.99, 0.98, 0.95, 0.96)
		badge_sb.border_color = Color(0.42, 0.32, 0.18, 0.95)
		badge_sb.set_border_width_all(2)
		_badge_label.text = "Sv. %d" % current_level
		_badge_label.add_theme_color_override("font_color", Color(0.16, 0.12, 0.08))

		name_sb.bg_color = Color(0.99, 0.98, 0.95, 0.96)
		name_sb.border_color = Color(0.42, 0.32, 0.18, 0.95)
		name_sb.set_border_width_all(2)
		if _name_label != null:
			_name_label.add_theme_color_override("font_color", Color(0.16, 0.12, 0.08))

		_stop_hammer_anim()
		_hammer_icon.hide()
		_progress_bar.hide()
		_countdown_label.hide()

	elif is_locked:
		# Kilitli: Mat koyu antrasit rozet
		badge_sb.bg_color = Color(0.18, 0.16, 0.14, 0.94)
		badge_sb.border_color = Color(0.55, 0.48, 0.38, 0.90)
		badge_sb.set_border_width_all(2)
		_badge_label.text = "🔒"
		_badge_label.add_theme_color_override("font_color", Color(0.90, 0.90, 0.90))

		name_sb.bg_color = Color(0.18, 0.16, 0.14, 0.94)
		name_sb.border_color = Color(0.55, 0.48, 0.38, 0.90)
		name_sb.set_border_width_all(2)
		if _name_label != null:
			_name_label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.82))

		_stop_hammer_anim()
		_hammer_icon.hide()
		_progress_bar.hide()
		_countdown_label.hide()

	else:
		# Seviye 0 İnşa Edilebilir: Canlı mavi kare rozet
		badge_sb.bg_color = Color(0.18, 0.46, 0.76, 0.96)
		badge_sb.border_color = Color(0.60, 0.85, 1.0, 1.0)
		badge_sb.set_border_width_all(2)
		_badge_label.text = "+"
		_badge_label.add_theme_color_override("font_color", Color(1, 1, 1))

		name_sb.bg_color = Color(0.18, 0.46, 0.76, 0.96)
		name_sb.border_color = Color(0.60, 0.85, 1.0, 1.0)
		name_sb.set_border_width_all(2)
		if _name_label != null:
			_name_label.add_theme_color_override("font_color", Color(1, 1, 1))

		_stop_hammer_anim()
		_hammer_icon.hide()
		_progress_bar.hide()
		_countdown_label.hide()

	_level_badge.add_theme_stylebox_override("panel", badge_sb)
	if _name_plate != null:
		_name_plate.add_theme_stylebox_override("panel", name_sb)
	_update_badge_position()


func _start_hammer_anim() -> void:
	if _hammer_tween != null and _hammer_tween.is_valid():
		return
	_hammer_tween = create_tween().set_loops()
	_hammer_tween.tween_property(_hammer_icon, "rotation_degrees", 25.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hammer_tween.tween_property(_hammer_icon, "rotation_degrees", -20.0, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_hammer_tween.tween_interval(0.25)


func _stop_hammer_anim() -> void:
	if _hammer_tween != null:
		_hammer_tween.kill()
		_hammer_tween = null
	if _hammer_icon != null:
		_hammer_icon.rotation_degrees = 0


func trigger_level_up(new_level: int) -> void:
	if _level_up_popup != null and is_instance_valid(_level_up_popup):
		_level_up_popup.queue_free()
		_level_up_popup = null

	var popup := PanelContainer.new()
	var popup_sb := StyleBoxFlat.new()
	popup_sb.bg_color = Color(0.12, 0.10, 0.08, 0.96)
	popup_sb.border_color = Color(1.0, 0.85, 0.35, 1.0)
	popup_sb.set_border_width_all(2)
	popup_sb.set_corner_radius_all(10)
	popup_sb.content_margin_left = 16
	popup_sb.content_margin_right = 16
	popup_sb.content_margin_top = 8
	popup_sb.content_margin_bottom = 8
	popup_sb.shadow_size = 8
	popup_sb.shadow_color = Color(0, 0, 0, 0.75)
	popup.add_theme_stylebox_override("panel", popup_sb)

	var lbl := Label.new()
	lbl.text = "✨ SEVİYE %d! ✨" % new_level
	lbl.add_theme_font_override("font", preload("res://assets/fonts/Nunito-Bold.ttf"))
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.40))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.add_child(lbl)

	popup.position = Vector2((size.x - 180) * 0.5, -20)
	popup.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(popup)
	_level_up_popup = popup

	popup.scale = Vector2(0.85, 0.85)
	popup.modulate.a = 0.0

	# Tam 2.0 saniyelik animasyon:
	# 0.0 - 0.25s: Pop in (büyüyerek beliriş)
	# 0.25 - 1.50s: 1.25s boyunca ekranda tam net ve sabit kalış
	# 1.50 - 2.00s: 0.5s yumuşak kayboluş ve yukarı hafif süzülüş
	# 2.00s: queue_free()
	var pt := create_tween()
	pt.tween_property(popup, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pt.parallel().tween_property(popup, "modulate:a", 1.0, 0.20)
	pt.tween_property(popup, "position:y", -35.0, 1.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	pt.tween_property(popup, "modulate:a", 0.0, 0.50).set_ease(Tween.EASE_IN)
	pt.parallel().tween_property(popup, "position:y", -55.0, 0.50)
	pt.tween_callback(func():
		if _level_up_popup == popup:
			_level_up_popup = null
		if is_instance_valid(popup):
			popup.queue_free()
	)


func _on_mouse_entered() -> void:
	if _hover_highlight != null:
		_hover_highlight.show()
	if _name_plate != null:
		_name_plate.show()
	if _level_badge != null:
		var t := create_tween()
		t.tween_property(_level_badge, "scale", Vector2(1.10, 1.10), 0.12).set_trans(Tween.TRANS_QUAD)


func _on_mouse_exited() -> void:
	if _hover_highlight != null:
		_hover_highlight.hide()
	if _level_badge != null:
		var t := create_tween()
		t.tween_property(_level_badge, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_QUAD)


func get_button() -> Button:
	return _btn


func get_level_label() -> Label:
	return _badge_label


func get_name_label() -> Label:
	return _name_label
