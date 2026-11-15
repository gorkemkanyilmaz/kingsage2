extends Control
## WorldMap — Canlı İzometrik Dünya Haritası ve Sefer Sevk Ekranı (Taht ve Kılıç / A-ARAYUZ).

const TravelScript := preload("res://scripts/world/Travel.gd")
const ProtectionScript := preload("res://scripts/sim/actions/Protection.gd")
const Palette := preload("res://themes/Palette.gd")
const MapVillageViewScript := preload("res://scenes/map/MapVillageView.gd")
const FontNunitoBold := preload("res://assets/fonts/Nunito-Bold.ttf")

const TexHarita1 := preload("res://assets/sprites/map/harita-1.jpg")
const TexHarita2 := preload("res://assets/sprites/map/harita-2.jpg")

# 4 Sütun x 6 Satır Harita Boyutları (harita-1 ve harita-2 tabanlı, 2 katına çıkartılmış)
const MAP_WIDTH := 10120.0
const MAP_HEIGHT := 9984.0
const TILE_W := 2530.0
const TILE_H := 1664.0
const MARGIN_X := 160.0
const MARGIN_Y := 160.0

const MIN_ZOOM := 0.25
const MAX_ZOOM := 1.8
var _zoom: float = 0.75
var _camera_pos: Vector2 = Vector2(MAP_WIDTH * 0.5, MAP_HEIGHT * 0.5)

@onready var resource_bar: PanelContainer = $ResourceBar
@onready var bottom_nav: PanelContainer = $BottomNav
@onready var send_troops_panel: PanelContainer = $SendTroopsPanel
@onready var map_container: Control = $MapContainer
@onready var coord_x_input: SpinBox = $Header/HBox/CoordX
@onready var coord_y_input: SpinBox = $Header/HBox/CoordY
@onready var btn_goto: Button = $Header/HBox/BtnGoto

var world_root: Control
var bg_layer: Control
var grid_overlay: Control
var movements_layer: Control
var villages_root: Control

var _village_views: Dictionary = {}
var _is_dragging: bool = false
var _drag_start_mouse: Vector2 = Vector2.ZERO
var _drag_start_cam: Vector2 = Vector2.ZERO
var _total_drag_dist: float = 0.0
var _camera_tween: Tween

# Çoklu dokunmatik (Pinch-to-zoom)
var _touch_points: Dictionary = {}
var _initial_pinch_dist: float = 0.0
var _initial_pinch_zoom: float = 1.0
var _last_touch_ms: int = -10000

# ScrollContainer uyumluluğu için
@onready var map_scroll: ScrollContainer = $MapContainer/Scroll
@onready var village_grid_container: Control = $MapContainer/Scroll/GridControl
var _last_scroll_h: int = 0
var _last_scroll_v: int = 0

# Üst Hareket Durum Çubuğu
var movement_status_bar: PanelContainer
var movement_status_label: Label

# Sefer Detay & İptal Modalı (Madde 3)
var movement_detail_panel: PanelContainer
var _detail_movement_ref: Dictionary = {}
var _detail_title_lbl: Label
var _detail_route_lbl: Label
var _detail_status_lbl: Label
var _detail_timer_lbl: Label
var _detail_sub_timer_lbl: Label
var _detail_units_grid: GridContainer
var _detail_btn_cancel: Button
var _detail_cancel_note: Label
var _last_village_click_ms: int = -10000
var _cached_active_vid: int = -1
var _cached_own_sig: String = ""


func _ready() -> void:
	send_troops_panel.hide()
	send_troops_panel.z_index = 1000
	send_troops_panel.z_as_relative = false
	bottom_nav.z_index = 1000
	bottom_nav.z_as_relative = false
	resource_bar.z_index = 1000
	resource_bar.z_as_relative = false
	if has_node("Header"):
		$Header.z_index = 900
		$Header.z_as_relative = false
	if has_node("Legend"):
		$Legend.z_index = 900
		$Legend.z_as_relative = false

	btn_goto.pressed.connect(_on_goto_pressed)
	map_container.resized.connect(_update_camera_transform)

	_style_header()
	_style_legend()
	_setup_map_viewport()
	_build_background()
	_build_grid_overlay()
	_build_villages()
	_create_floating_controls()
	_setup_movement_status_bar()

	# Başlangıçta oyuncu köyüne ortala
	_center_on_home(false)
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs != null:
		_cached_active_vid = int(gs.active_village_id)
		if gs.has_method("get_player_villages"):
			var ids: Array = []
			for pv in gs.get_player_villages():
				ids.append(int((pv as Dictionary).get("id", -1)))
			_cached_own_sig = str(ids)
	var bus = Engine.get_main_loop().root.get_node_or_null("EventBus") if Engine.get_main_loop() is SceneTree else null
	if bus != null:
		if bus.has_signal("state_changed") and not bus.state_changed.is_connected(_on_world_state_changed):
			bus.state_changed.connect(_on_world_state_changed)
		if bus.has_signal("village_conquered") and not bus.village_conquered.is_connected(_on_village_conquered_map):
			bus.village_conquered.connect(_on_village_conquered_map)


func _process(_delta: float) -> void:
	if movements_layer != null:
		movements_layer.queue_redraw()

	_refresh_movement_status_bar()

	if movement_detail_panel != null and movement_detail_panel.visible:
		_update_movement_detail_timer()


# ---------------------------------------------------------------- Görsel Kurulum
func _style_header() -> void:
	var title: Label = $Header/HBox/Title
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	var player_name := str(gs.player.get("name", "Lord Gorkem")) if gs != null else "Lord Gorkem"
	var AllianceModelScript = load("res://scripts/model/AllianceModel.gd")
	var ally_info := ""
	if gs != null and AllianceModelScript != null:
		var p_ally: Dictionary = AllianceModelScript.get_player_alliance(gs.to_dict(), player_name)
		if not p_ally.is_empty():
			ally_info = "  •   [%s] %s" % [str(p_ally.get("tag", "")), str(p_ally.get("name", ""))]
		else:
			ally_info = "  •   İttifak: Yok"

	title.text = "Dünya Haritası" + ally_info
	title.add_theme_font_override("font", FontNunitoBold)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_constant_override("outline_size", 1)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	title.add_theme_color_override("font_color", Color(1.0, 0.94, 0.82))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))

	for lbl in [$Header/HBox/LabelX, $Header/HBox/LabelY]:
		if lbl != null:
			lbl.add_theme_font_override("font", FontNunitoBold)
			lbl.add_theme_font_size_override("font_size", 24)
			lbl.add_theme_constant_override("outline_size", 1)
			lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
			lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
			lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.65))

	for sb in [coord_x_input, coord_y_input]:
		if sb != null:
			sb.custom_minimum_size = Vector2(130, 52)
			var le: LineEdit = sb.get_line_edit()
			if le != null:
				le.alignment = HORIZONTAL_ALIGNMENT_CENTER
				le.add_theme_font_override("font", FontNunitoBold)
				le.add_theme_font_size_override("font_size", 24)
				le.add_theme_constant_override("outline_size", 2)
				le.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.98))
				le.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))

				var sb_box := StyleBoxFlat.new()
				sb_box.bg_color = Color(0.08, 0.07, 0.10, 0.92)
				sb_box.border_color = Color(0.85, 0.72, 0.42, 0.85)
				sb_box.set_border_width_all(2)
				sb_box.set_corner_radius_all(10)
				le.add_theme_stylebox_override("normal", sb_box)
				le.add_theme_stylebox_override("focus", sb_box)

	btn_goto.text = " Git"
	btn_goto.custom_minimum_size = Vector2(130, 52)
	btn_goto.add_theme_font_override("font", FontNunitoBold)
	btn_goto.add_theme_font_size_override("font_size", 24)
	btn_goto.add_theme_constant_override("outline_size", 3)
	btn_goto.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.98))
	btn_goto.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	btn_goto.add_theme_constant_override("shadow_offset_y", 2)

	var g_sb := StyleBoxFlat.new()
	g_sb.bg_color = Color(0.85, 0.72, 0.42, 1.0)
	g_sb.border_color = Color(0.36, 0.27, 0.14, 0.95)
	g_sb.set_border_width_all(2)
	g_sb.set_corner_radius_all(12)
	g_sb.shadow_size = 6
	g_sb.shadow_color = Color(0, 0, 0, 0.4)
	btn_goto.add_theme_stylebox_override("normal", g_sb)

	var g_sb_h := g_sb.duplicate()
	g_sb_h.bg_color = Color(1.0, 0.86, 0.52, 1.0)
	btn_goto.add_theme_stylebox_override("hover", g_sb_h)
	btn_goto.add_theme_stylebox_override("pressed", g_sb_h)
	btn_goto.add_theme_color_override("font_color", Color(0.18, 0.12, 0.05))


func _style_legend() -> void:
	var legend: PanelContainer = get_node_or_null("Legend")
	if legend != null:
		var leg_sb := StyleBoxFlat.new()
		leg_sb.bg_color = Color(0.10, 0.09, 0.12, 0.90)
		leg_sb.border_color = Color(0.85, 0.72, 0.42, 0.85)
		leg_sb.set_border_width_all(2)
		leg_sb.set_corner_radius_all(12)
		leg_sb.content_margin_left = 18
		leg_sb.content_margin_right = 18
		leg_sb.content_margin_top = 6
		leg_sb.content_margin_bottom = 6
		leg_sb.shadow_size = 6
		leg_sb.shadow_color = Color(0, 0, 0, 0.4)
		legend.add_theme_stylebox_override("panel", leg_sb)

		var own: Label = legend.get_node_or_null("HBox/Own")
		if own != null:
			own.text = "• Kendi Köyün"
			own.add_theme_font_override("font", FontNunitoBold)
			own.add_theme_font_size_override("font_size", 22)
			own.add_theme_constant_override("outline_size", 3)
			own.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.98))
			own.add_theme_color_override("font_color", Color(0.40, 0.95, 0.55))

		var ally: Label = legend.get_node_or_null("HBox/Ally")
		if ally != null:
			ally.text = "• İttifak Üyelerin"
			ally.add_theme_font_override("font", FontNunitoBold)
			ally.add_theme_font_size_override("font_size", 22)
			ally.add_theme_constant_override("outline_size", 3)
			ally.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.98))
			ally.add_theme_color_override("font_color", Color(0.35, 0.75, 1.0))

		var enemy: Label = legend.get_node_or_null("HBox/Enemy")
		if enemy != null:
			enemy.text = "• Düşman"
			enemy.add_theme_font_override("font", FontNunitoBold)
			enemy.add_theme_font_size_override("font_size", 22)
			enemy.add_theme_constant_override("outline_size", 3)
			enemy.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.98))
			enemy.add_theme_color_override("font_color", Color(1.0, 0.45, 0.40))

		var barb: Label = legend.get_node_or_null("HBox/Barb")
		if barb != null:
			barb.hide()
			barb.queue_free()


# ---------------------------------------------------------------- Harita ve Katmanlar
func _setup_map_viewport() -> void:
	map_container.clip_contents = true
	map_container.mouse_filter = Control.MOUSE_FILTER_STOP
	map_container.gui_input.connect(_on_map_gui_input)

	if map_scroll != null:
		map_scroll.hide()

	world_root = Control.new()
	world_root.name = "WorldRoot"
	world_root.mouse_filter = Control.MOUSE_FILTER_PASS
	world_root.custom_minimum_size = Vector2(MAP_WIDTH, MAP_HEIGHT)
	world_root.size = Vector2(MAP_WIDTH, MAP_HEIGHT)
	map_container.add_child(world_root)

	bg_layer = Control.new()
	bg_layer.name = "BackgroundGrid"
	bg_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world_root.add_child(bg_layer)

	grid_overlay = Control.new()
	grid_overlay.name = "GridOverlay"
	grid_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world_root.add_child(grid_overlay)

	villages_root = Control.new()
	villages_root.name = "VillagesRoot"
	villages_root.mouse_filter = Control.MOUSE_FILTER_PASS
	world_root.add_child(villages_root)

	movements_layer = Control.new()
	movements_layer.name = "MovementsLayer"
	movements_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	movements_layer.custom_minimum_size = Vector2(MAP_WIDTH, MAP_HEIGHT)
	movements_layer.size = Vector2(MAP_WIDTH, MAP_HEIGHT)
	movements_layer.draw.connect(_on_draw_movements)
	world_root.add_child(movements_layer)


func _build_background() -> void:
	# 4 sütun x 6 satır = 24 parçalık devasa ve kesintisiz harita (10120 x 9984 px)
	# Harita-1 ağırlıklı, aralara Harita-2 gölleri serpiştirilmiş düzen
	var layout := [
		[TexHarita1, TexHarita2, TexHarita1, TexHarita1],
		[TexHarita1, TexHarita1, TexHarita1, TexHarita2],
		[TexHarita2, TexHarita1, TexHarita1, TexHarita1],
		[TexHarita1, TexHarita1, TexHarita2, TexHarita1],
		[TexHarita1, TexHarita2, TexHarita1, TexHarita1],
		[TexHarita2, TexHarita1, TexHarita1, TexHarita2]
	]

	for row in range(6):
		for col in range(4):
			var tex: Texture2D = layout[row][col]
			var rect := TextureRect.new()
			rect.texture = tex
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.stretch_mode = TextureRect.STRETCH_SCALE
			rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			rect.position = Vector2(col * TILE_W, row * TILE_H)
			rect.size = Vector2(TILE_W, TILE_H)
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bg_layer.add_child(rect)


func _build_grid_overlay() -> void:
	var line_col := Color(0.18, 0.32, 0.12, 0.16)
	var major_col := Color(0.85, 0.72, 0.42, 0.35) # Kıta sınırları (0, 100, 200)

	for i in range(0, 201, 10):
		var pos_i := coord_to_world_pos(float(i), float(i))
		var is_major := (i == 0 or i == 100 or i == 200)

		# Düşey kılavuz
		var vline := ColorRect.new()
		vline.color = major_col if is_major else line_col
		vline.position = Vector2(pos_i.x, MARGIN_Y)
		vline.size = Vector2(3 if is_major else 1, MAP_HEIGHT - 2.0 * MARGIN_Y)
		vline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid_overlay.add_child(vline)

		# Yatay kılavuz
		var hline := ColorRect.new()
		hline.color = major_col if is_major else line_col
		hline.position = Vector2(MARGIN_X, pos_i.y)
		hline.size = Vector2(MAP_WIDTH - 2.0 * MARGIN_X, 3 if is_major else 1)
		hline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid_overlay.add_child(hline)


func _build_villages() -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null:
		return

	var wm = Engine.get_main_loop().root.get_node_or_null("WorldManager") if Engine.get_main_loop() is SceneTree else null
	var auth = Engine.get_main_loop().root.get_node_or_null("AuthManager") if Engine.get_main_loop() is SceneTree else null
	var player_name := ""
	if auth != null and not auth.display_name.is_empty():
		player_name = auth.display_name
	elif gs != null and not str(gs.player.get("name", "")).is_empty():
		player_name = str(gs.player.get("name", ""))
	else:
		player_name = "Lord Gorkem"

	if (gs.villages.is_empty() or not gs.has_active_village()) and wm != null:
		wm.enter_world(wm.current_world_id, player_name)

	# Aktif köy oyuncunun kendi köyü olmalı
	if gs.has_method("get_player_villages"):
		var p_vills: Array = gs.get_player_villages()
		if not p_vills.is_empty():
			var cur_v: Dictionary = gs.get_active_village() if gs.has_active_village() else {}
			var is_cur_own := (not cur_v.is_empty() and str(cur_v.get("owner", "")) == player_name)
			if not is_cur_own:
				gs.active_village_id = int((p_vills[0] as Dictionary).get("id", 1))

	var villages: Array = gs.villages
	var active_v: Dictionary = gs.get_active_village() if gs.has_active_village() else {}
	var active_vid: int = int(active_v.get("id", -1))
	if not str(gs.player.get("name", "")).is_empty():
		player_name = str(gs.player.get("name", ""))

	var player_village_ids: Array = []
	if gs.has_method("get_player_villages"):
		for pv in gs.get_player_villages():
			player_village_ids.append(int(pv.get("id", -1)))

	var AllianceModelScript = load("res://scripts/model/AllianceModel.gd")
	var player_ally: Dictionary = {}
	if AllianceModelScript != null:
		player_ally = AllianceModelScript.get_player_alliance(gs.to_dict(), player_name)

	var ally_member_names: Array = []
	var player_ally_tag := ""
	if not player_ally.is_empty():
		player_ally_tag = str(player_ally.get("tag", ""))
		for m in player_ally.get("members", []):
			var m_name: String = str(m) if typeof(m) == TYPE_STRING else str((m as Dictionary).get("name", ""))
			if not m_name.is_empty() and m_name != player_name:
				ally_member_names.append(m_name)

	for v in villages:
		if typeof(v) != TYPE_DICTIONARY:
			continue
		var vid: int = int(v.get("id", -1))
		var vx: int = int(v.get("x", 0))
		var vy: int = int(v.get("y", 0))
		var v_owner := str(v.get("owner", ""))

		# 3 Kategori Tespiti:
		var is_own: bool = (v_owner == player_name) or (vid in player_village_ids)
		var is_ally: bool = false
		var v_tag := ""

		if is_own:
			v_tag = player_ally_tag
		elif not ally_member_names.is_empty() and ally_member_names.has(v_owner):
			is_ally = true
			v_tag = player_ally_tag
		else:
			v_tag = str(v.get("alliance", ""))

		var center_pos := coord_to_world_pos(float(vx), float(vy))

		var v_view = MapVillageViewScript.new()
		# MapVillageView boyutu (360, 410), merkezleme Vector2(180, 156)
		v_view.position = center_pos - Vector2(180, 156)
		v_view.z_index = int(vy)
		v_view.set_meta("village_dict", v)
		v_view.setup(v, is_own, is_ally, v_tag)
		v_view.clicked.connect(func(): _on_village_clicked(v))

		villages_root.add_child(v_view)
		_village_views[vid] = v_view


# ---------------------------------------------------------------- Koordinat Dönüşümleri
func coord_to_world_pos(x: float, y: float) -> Vector2:
	var usable_w := MAP_WIDTH - 2.0 * MARGIN_X
	var usable_h := MAP_HEIGHT - 2.0 * MARGIN_Y
	var px := MARGIN_X + (clampf(x, 0.0, 200.0) / 200.0) * usable_w
	var py := MARGIN_Y + (clampf(y, 0.0, 200.0) / 200.0) * usable_h
	return Vector2(px, py)


func world_pos_to_coord(pos: Vector2) -> Vector2:
	var usable_w := MAP_WIDTH - 2.0 * MARGIN_X
	var usable_h := MAP_HEIGHT - 2.0 * MARGIN_Y
	var cx := ((pos.x - MARGIN_X) / usable_w) * 200.0
	var cy := ((pos.y - MARGIN_Y) / usable_h) * 200.0
	return Vector2(clampf(cx, 0.0, 200.0), clampf(cy, 0.0, 200.0))


# ---------------------------------------------------------------- Kamera & Gezinme (Pan & Zoom)
func _update_camera_transform() -> void:
	if world_root == null or map_container == null:
		return
	var view_size: Vector2 = map_container.size
	if view_size.x <= 10 or view_size.y <= 10:
		view_size = Vector2(1080, 1920)

	var half_w := (view_size.x * 0.5) / _zoom
	var half_h := (view_size.y * 0.5) / _zoom

	# Harita sınırından öteye kaydırmayı engelle (gri alanlar asla gözükmez)
	if MAP_WIDTH * _zoom <= view_size.x:
		_camera_pos.x = MAP_WIDTH * 0.5
	else:
		_camera_pos.x = clampf(_camera_pos.x, half_w, MAP_WIDTH - half_w)

	if MAP_HEIGHT * _zoom <= view_size.y:
		_camera_pos.y = MAP_HEIGHT * 0.5
	else:
		_camera_pos.y = clampf(_camera_pos.y, half_h, MAP_HEIGHT - half_h)

	world_root.scale = Vector2(_zoom, _zoom)
	var target_pos := (view_size * 0.5) - (_camera_pos * _zoom)
	world_root.position = Vector2(roundf(target_pos.x), roundf(target_pos.y))


func _set_zoom(new_zoom: float) -> void:
	_zoom = clampf(new_zoom, MIN_ZOOM, MAX_ZOOM)
	_update_camera_transform()


func _zoom_at(focus_screen_pos: Vector2, factor: float) -> void:
	var old_zoom := _zoom
	var new_zoom := clampf(old_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(old_zoom, new_zoom):
		return

	var view_size: Vector2 = map_container.size
	var world_focus := _camera_pos + (focus_screen_pos - view_size * 0.5) / old_zoom
	_zoom = new_zoom
	_camera_pos = world_focus - (focus_screen_pos - view_size * 0.5) / new_zoom
	_update_camera_transform()


func _smooth_zoom(factor: float) -> void:
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()
	var target_zoom := clampf(_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	_camera_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_camera_tween.tween_method(func(z: float):
		_zoom = z
		_update_camera_transform()
	, _zoom, target_zoom, 0.22)


func _center_on_home(animated: bool = true) -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	var vx: float = 100.0
	var vy: float = 100.0
	if gs != null:
		var v: Dictionary = gs.get_active_village() if gs.has_active_village() else {}
		if v.is_empty() and gs.has_method("get_player_villages"):
			var p_vills: Array = gs.get_player_villages()
			if not p_vills.is_empty():
				v = p_vills[0]
				gs.active_village_id = int(v.get("id", 1))
		if not v.is_empty():
			vx = float(v.get("x", 100))
			vy = float(v.get("y", 100))
			if vx > 200.0 or vy > 200.0 or vx < 0.0 or vy < 0.0:
				vx = 100.0
				vy = 100.0
	var in_x := coord_x_input if coord_x_input != null else (get_node_or_null("Header/HBox/CoordX") as SpinBox)
	if in_x != null:
		in_x.value = vx
	var in_y := coord_y_input if coord_y_input != null else (get_node_or_null("Header/HBox/CoordY") as SpinBox)
	if in_y != null:
		in_y.value = vy
	var wpos := coord_to_world_pos(vx, vy)
	_center_on_pos(wpos, animated)


func _center_on_coord(x: float, y: float, animated: bool = true) -> void:
	var wpos := coord_to_world_pos(x, y)
	_center_on_pos(wpos, animated)


func _center_on_pos(target_pos: Vector2, animated: bool = true) -> void:
	if not animated:
		_camera_pos = target_pos
		_update_camera_transform()
	else:
		if _camera_tween != null and _camera_tween.is_valid():
			_camera_tween.kill()
		_camera_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_camera_tween.tween_method(func(pos: Vector2):
			_camera_pos = pos
			_update_camera_transform()
		, _camera_pos, target_pos, 0.35)


# ---------------------------------------------------------------- Giriş Olayları (Touch / Drag / Pinch / Wheel)
func _on_map_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if not _touch_points.is_empty() or (Time.get_ticks_msec() - _last_touch_ms) < 250:
			return
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_is_dragging = true
				_drag_start_mouse = mb.position
				_drag_start_cam = _camera_pos
				_total_drag_dist = 0.0
			else:
				var was_drag := (_total_drag_dist > 20.0)
				_is_dragging = false
				call_deferred("_reset_drag_dist")
				if not was_drag:
					_check_movement_click(mb.position)
					if movement_detail_panel == null or not movement_detail_panel.visible:
						_try_select_village_at_screen_pos(mb.position)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at(mb.position, 1.15)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at(mb.position, 1.0 / 1.15)

	elif event is InputEventMouseMotion:
		if not _touch_points.is_empty() or (Time.get_ticks_msec() - _last_touch_ms) < 250:
			return
		var mm := event as InputEventMouseMotion
		if _is_dragging:
			var delta: Vector2 = mm.position - _drag_start_mouse
			_total_drag_dist += delta.length()
			_camera_pos = _drag_start_cam - (delta / _zoom)
			_update_camera_transform()

	elif event is InputEventScreenTouch:
		_last_touch_ms = Time.get_ticks_msec()
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touch_points[st.index] = st.position
			if _touch_points.size() == 1:
				_is_dragging = true
				_drag_start_mouse = st.position
				_drag_start_cam = _camera_pos
				_total_drag_dist = 0.0
			elif _touch_points.size() == 2:
				var pts = _touch_points.values()
				_initial_pinch_dist = pts[0].distance_to(pts[1])
				_initial_pinch_zoom = _zoom
				_total_drag_dist = 999.0
		else:
			_touch_points.erase(st.index)
			if _touch_points.is_empty():
				var was_drag := (_total_drag_dist > 20.0)
				_is_dragging = false
				call_deferred("_reset_drag_dist")
				if not was_drag:
					_check_movement_click(st.position)
					if movement_detail_panel == null or not movement_detail_panel.visible:
						_try_select_village_at_screen_pos(st.position)

	elif event is InputEventScreenDrag:
		_last_touch_ms = Time.get_ticks_msec()
		var sd := event as InputEventScreenDrag
		if _touch_points.size() == 2:
			_touch_points[sd.index] = sd.position
			var pts = _touch_points.values()
			var cur_dist: float = pts[0].distance_to(pts[1])
			_total_drag_dist = 999.0
			if _initial_pinch_dist > 10.0:
				_set_zoom(_initial_pinch_zoom * (cur_dist / _initial_pinch_dist))
		else:
			_camera_pos -= sd.relative / _zoom
			_total_drag_dist += sd.relative.length()
			_update_camera_transform()


func _reset_drag_dist() -> void:
	_total_drag_dist = 0.0


# ---------------------------------------------------------------- Arayüz Butonları & Sefer
func _create_floating_controls() -> void:
	# Büyüt (+) Butonu — BottomNav (248px) dokunun üzerinde
	var btn_zin := Button.new()
	btn_zin.name = "BtnZoomIn"
	btn_zin.text = "+"
	btn_zin.custom_minimum_size = Vector2(72, 72)
	btn_zin.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	btn_zin.offset_left = -96.0
	btn_zin.offset_top = -428.0
	btn_zin.offset_right = -24.0
	btn_zin.offset_bottom = -356.0
	_style_floating_btn(btn_zin, 32)
	btn_zin.pressed.connect(func(): _smooth_zoom(1.25))
	add_child(btn_zin)

	# Küçült (-) Butonu
	var btn_zout := Button.new()
	btn_zout.name = "BtnZoomOut"
	btn_zout.text = "-"
	btn_zout.custom_minimum_size = Vector2(72, 72)
	btn_zout.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	btn_zout.offset_left = -96.0
	btn_zout.offset_top = -344.0
	btn_zout.offset_right = -24.0
	btn_zout.offset_bottom = -272.0
	_style_floating_btn(btn_zout, 32)
	btn_zout.pressed.connect(func(): _smooth_zoom(1.0 / 1.25))
	add_child(btn_zout)

	# Haritada Köye Odaklan Butonu (Alt menüdeki Köy sekmesiyle çakışmaz)
	var btn_home := Button.new()
	btn_home.name = "BtnCenterHome"
	btn_home.text = "Odaklan"
	btn_home.custom_minimum_size = Vector2(160, 56)
	btn_home.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	btn_home.offset_left = 24.0
	btn_home.offset_top = -328.0
	btn_home.offset_right = 184.0
	btn_home.offset_bottom = -272.0
	_style_floating_btn(btn_home, 24)
	btn_home.pressed.connect(func(): _center_on_home(true))
	add_child(btn_home)

	for b in [btn_zin, btn_zout, btn_home]:
		b.z_index = 900
		b.z_as_relative = false


func _style_floating_btn(btn: Button, font_sz: int) -> void:
	btn.add_theme_font_override("font", FontNunitoBold)
	btn.add_theme_font_size_override("font_size", font_sz)
	btn.add_theme_constant_override("outline_size", 3)
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.98))
	btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	btn.add_theme_constant_override("shadow_offset_y", 2)
	btn.add_theme_color_override("font_color", Color(1.0, 0.94, 0.82))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.95, 0.70))
	btn.add_theme_color_override("font_focus_color", Color(1.0, 0.94, 0.82))
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.09, 0.13, 0.94)
	sb.border_color = Color(0.85, 0.72, 0.42, 0.95)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.shadow_size = 8
	sb.shadow_color = Color(0, 0, 0, 0.5)
	btn.add_theme_stylebox_override("normal", sb)

	var sb_h := sb.duplicate()
	sb_h.bg_color = Color(0.22, 0.18, 0.14, 0.98)
	sb_h.border_color = Color(1.0, 0.88, 0.52, 1.0)
	var sb_p := sb.duplicate()
	sb_p.bg_color = Color(0.26, 0.20, 0.14, 1.0)
	sb_p.border_color = Color(1.0, 0.95, 0.65, 1.0)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_stylebox_override("pressed", sb_p)


func _on_goto_pressed() -> void:
	var target_x: float = coord_x_input.value
	var target_y: float = coord_y_input.value
	_center_on_coord(target_x, target_y, true)


func _try_select_village_at_screen_pos(screen_pos: Vector2) -> void:
	if send_troops_panel != null and send_troops_panel.visible:
		return
	if map_container == null or world_root == null:
		return
	var view_size: Vector2 = map_container.size
	if view_size.x <= 10.0 or view_size.y <= 10.0:
		view_size = Vector2(1080.0, 1920.0)
	var world_pos := _camera_pos + (screen_pos - view_size * 0.5) / _zoom
	var best_v: Dictionary = {}
	var best_dist: float = 155.0
	for vid in _village_views:
		var v_view = _village_views[vid]
		if v_view == null or not is_instance_valid(v_view):
			continue
		var center: Vector2 = v_view.position + Vector2(180.0, 156.0)
		var d: float = world_pos.distance_to(center)
		if d <= best_dist and v_view.has_meta("village_dict"):
			best_dist = d
			best_v = v_view.get_meta("village_dict")
	if not best_v.is_empty():
		_on_village_clicked(best_v)


func _on_village_conquered_map(_vid: int, _owner: String) -> void:
	_cached_own_sig = ""
	_on_world_state_changed()


func _on_world_state_changed() -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null:
		return
	var cur_aid := int(gs.active_village_id)
	var ids: Array = []
	if gs.has_method("get_player_villages"):
		for pv in gs.get_player_villages():
			ids.append(int((pv as Dictionary).get("id", -1)))
	var sig := str(ids)
	if cur_aid == _cached_active_vid and sig == _cached_own_sig:
		return
	var aid_changed := (cur_aid != _cached_active_vid)
	_cached_active_vid = cur_aid
	_cached_own_sig = sig
	if villages_root != null:
		for c in villages_root.get_children():
			c.queue_free()
	_village_views.clear()
	_build_villages()
	if aid_changed:
		_center_on_home(true)


func _on_village_clicked(target_v: Dictionary) -> void:
	if _total_drag_dist > 25.0 or _touch_points.size() >= 2:
		_total_drag_dist = 0.0
		return
	var now_ms := Time.get_ticks_msec()
	if now_ms - _last_village_click_ms < 200:
		return
	_last_village_click_ms = now_ms
	_is_dragging = false
	_total_drag_dist = 0.0

	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null:
		return
	if not gs.has_active_village() and not gs.villages.is_empty():
		gs.active_village_id = int((gs.villages[0] as Dictionary).get("id", 1))
	if not gs.has_active_village():
		return

	var active_vid: int = gs.active_village_id
	var target_vid: int = int(target_v.get("id", -1))
	var player_name := str(gs.player.get("name", "Kral"))
	var target_owner := str(target_v.get("owner", ""))
	var is_own_village: bool = (not player_name.is_empty() and target_owner == player_name)
	if not is_own_village and gs.has_method("get_player_villages"):
		for pv in gs.get_player_villages():
			if int(pv.get("id", -1)) == target_vid:
				is_own_village = true
				break

	if is_own_village and target_vid == active_vid:
		# Aktif köyün kendisine dokunulursa köy içine geç
		get_tree().change_scene_to_file("res://scenes/Village.tscn")
		return

	var from_v: Dictionary = gs.get_active_village()
	send_troops_panel.show_target(from_v, target_v)


# ---------------------------------------------------------------- Birlik & Katır Hareket Çizgileri
func _find_any_village(vid: int, gs: Node) -> Dictionary:
	if gs == null:
		return {}
	var v: Dictionary = gs.get_village(vid)
	if not v.is_empty():
		return v
	if gs.world is Dictionary and gs.world.has("villages"):
		for w_v in gs.world["villages"]:
			if int(w_v.get("id", -1)) == vid:
				return w_v
	if _village_views.has(vid):
		var view = _village_views[vid]
		if view != null and "village_data" in view and not (view.village_data as Dictionary).is_empty():
			return view.village_data
	return {}


func _on_draw_movements() -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null or gs.movements.is_empty():
		return

	var active_v: Dictionary = gs.get_active_village() if gs.has_active_village() else {}
	var active_vid: int = int(active_v.get("id", -1))
	var player_name: String = str(gs.player.get("name", "Kral"))
	var now: int = int(Time.get_unix_time_from_system())

	for m in gs.movements:
		if typeof(m) != TYPE_DICTIONARY:
			continue

		var m_owner := str(m.get("owner", ""))
		var from_id := int(m.get("from_village_id", m.get("village_id", 0)))
		var to_id := int(m.get("to_village_id", 0))

		# Sadece gönderen oyuncunun görebilmesi kuralı
		var is_mine := (m_owner == player_name or from_id == active_vid or to_id == active_vid)
		if not is_mine:
			continue

		var origin_v: Dictionary = _find_any_village(from_id, gs)
		var target_v: Dictionary = _find_any_village(to_id, gs)
		var from_x := float(m.get("from_x", origin_v.get("x", -1)))
		var from_y := float(m.get("from_y", origin_v.get("y", -1)))
		var to_x := float(m.get("to_x", target_v.get("x", -1)))
		var to_y := float(m.get("to_y", target_v.get("y", -1)))

		if from_x < 0.0 or from_y < 0.0 or to_x < 0.0 or to_y < 0.0:
			continue

		var origin_pos := coord_to_world_pos(from_x, from_y)
		var target_pos := coord_to_world_pos(to_x, to_y)

		var m_type := str(m.get("type", "attack"))
		var m_state := str(m.get("state", "outgoing"))
		var is_returning := (m_state == "returning" or m_type == "return")
		var is_trade := (m_type == "trade")

		var depart_unix := int(m.get("depart_unix", now))
		var arrive_unix := int(m.get("arrive_unix", now + 60))
		var duration := maxi(1, arrive_unix - depart_unix)
		var progress := clampf(float(now - depart_unix) / float(duration), 0.0, 1.0)

		# Çizgi Rengi (Dönüş: Camgöbeği, Katır: Altın Amber, Saldırı: Parlak Turuncu Kırmızı)
		var line_color := Color(1.0, 0.35, 0.18, 0.95)
		if is_returning:
			line_color = Color(0.25, 0.85, 1.0, 0.95)
		elif is_trade:
			line_color = Color(1.0, 0.82, 0.22, 0.95)

		# 1) Rota çizgisi (çift katman parlama)
		var glow_col := line_color
		glow_col.a = 0.25
		movements_layer.draw_line(origin_pos, target_pos, glow_col, 10.0, true)
		movements_layer.draw_line(origin_pos, target_pos, line_color, 4.0, true)

		# 2) Rota üzerinde ilerleyen oklar
		var line_dir := (target_pos - origin_pos).normalized()
		var line_dist := origin_pos.distance_to(target_pos)
		if line_dist > 80.0:
			var step_dist := 160.0
			var curr_d := 80.0
			while curr_d < line_dist - 60.0:
				var arrow_pt := origin_pos + line_dir * curr_d
				var perp := Vector2(-line_dir.y, line_dir.x) * 6.0
				var p1 := arrow_pt - line_dir * 8.0 + perp
				var p2 := arrow_pt
				var p3 := arrow_pt - line_dir * 8.0 - perp
				movements_layer.draw_line(p1, p2, line_color, 3.0, true)
				movements_layer.draw_line(p2, p3, line_color, 3.0, true)
				curr_d += step_dist

		# 3) Hat üzerinde hareket eden birlik/katır konumu
		var current_march_pos := origin_pos.lerp(target_pos, progress)

		# 4) İlerleme Rozeti
		var token_radius := 28.0
		movements_layer.draw_circle(current_march_pos, token_radius + 4.0, Color(0, 0, 0, 0.6))
		movements_layer.draw_circle(current_march_pos, token_radius, Color(0.10, 0.09, 0.14, 0.96))
		movements_layer.draw_arc(current_march_pos, token_radius, 0.0, TAU, 32, line_color, 3.0, true)

		var icon_str := ""
		if is_returning:
			icon_str = ""
		elif is_trade:
			icon_str = ""

		movements_layer.draw_string(FontNunitoBold, current_march_pos + Vector2(-12, 8), icon_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 24)

		# 5) Tepedeki Kalan Varış Zamanı Plaketi (Büyük Punto, 3px Kontur, Kristal Netlik)
		var rem_secs := maxi(0, arrive_unix - now)
		var time_str := "%02d:%02d" % [rem_secs / 60, rem_secs % 60]
		var banner_txt := ""
		if is_returning:
			banner_txt = " Dönüş: " + time_str
		elif is_trade:
			banner_txt = " Katır: " + time_str
		else:
			banner_txt = " Varış: " + time_str

		var banner_w := 240.0
		var banner_h := 46.0
		var banner_rect := Rect2(current_march_pos.x - banner_w * 0.5, current_march_pos.y - 62.0, banner_w, banner_h)
		movements_layer.draw_rect(banner_rect, Color(0.08, 0.07, 0.12, 0.94), true)
		movements_layer.draw_rect(banner_rect, line_color, false, 2.5)
		movements_layer.draw_string_outline(FontNunitoBold, Vector2(current_march_pos.x - banner_w * 0.5, current_march_pos.y - 30.0), banner_txt, HORIZONTAL_ALIGNMENT_CENTER, int(banner_w), 24, 3, Color(0, 0, 0, 1.0))
		movements_layer.draw_string(FontNunitoBold, Vector2(current_march_pos.x - banner_w * 0.5, current_march_pos.y - 30.0), banner_txt, HORIZONTAL_ALIGNMENT_CENTER, int(banner_w), 24, Color(1.0, 0.95, 0.85))


# ---------------------------------------------------------------- Üst Bar Hareket Durumu
func _setup_movement_status_bar() -> void:
	movement_status_bar = PanelContainer.new()
	movement_status_bar.name = "MovementStatusBar"
	movement_status_bar.anchors_preset = PRESET_TOP_WIDE
	movement_status_bar.offset_left = 20.0
	movement_status_bar.offset_right = -20.0
	movement_status_bar.offset_top = 226.0
	movement_status_bar.offset_bottom = 276.0
	movement_status_bar.z_index = 950
	movement_status_bar.z_as_relative = false

	var bar_sb := StyleBoxFlat.new()
	bar_sb.bg_color = Color(0.10, 0.09, 0.14, 0.94)
	bar_sb.border_color = Color(0.85, 0.72, 0.42, 0.95)
	bar_sb.set_border_width_all(2)
	bar_sb.set_corner_radius_all(14)
	bar_sb.shadow_size = 8
	bar_sb.shadow_color = Color(0, 0, 0, 0.5)
	bar_sb.content_margin_left = 18
	bar_sb.content_margin_right = 18
	bar_sb.content_margin_top = 4
	bar_sb.content_margin_bottom = 4
	movement_status_bar.add_theme_stylebox_override("panel", bar_sb)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 16)
	movement_status_bar.add_child(hbox)

	movement_status_label = Label.new()
	movement_status_label.add_theme_font_override("font", FontNunitoBold)
	movement_status_label.add_theme_font_size_override("font_size", 20)
	movement_status_label.add_theme_constant_override("outline_size", 3)
	movement_status_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.98))
	movement_status_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	hbox.add_child(movement_status_label)

	var btn_track := Button.new()
	btn_track.text = " Takip Et"
	btn_track.custom_minimum_size = Vector2(120, 42)
	btn_track.add_theme_font_override("font", FontNunitoBold)
	btn_track.add_theme_font_size_override("font_size", 18)
	btn_track.pressed.connect(_on_track_movement_pressed)
	hbox.add_child(btn_track)

	var btn_detail := Button.new()
	btn_detail.text = " Detay & İptal"
	btn_detail.custom_minimum_size = Vector2(150, 42)
	btn_detail.add_theme_font_override("font", FontNunitoBold)
	btn_detail.add_theme_font_size_override("font_size", 18)
	btn_detail.pressed.connect(_on_details_status_bar_pressed)
	hbox.add_child(btn_detail)

	add_child(movement_status_bar)
	movement_status_bar.hide()


func _refresh_movement_status_bar() -> void:
	if movement_status_bar == null:
		return
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null:
		movement_status_bar.hide()
		return

	var active_v: Dictionary = gs.get_active_village() if gs.has_active_village() else {}
	var active_vid: int = int(active_v.get("id", -1))
	var player_name: String = str(gs.player.get("name", "Kral"))
	var now: int = int(Time.get_unix_time_from_system())

	var my_movements: Array = []
	for m in gs.movements:
		if typeof(m) != TYPE_DICTIONARY:
			continue
		var m_owner := str(m.get("owner", ""))
		var from_id := int(m.get("from_village_id", m.get("village_id", 0)))
		var to_id := int(m.get("to_village_id", 0))
		if m_owner == player_name or from_id == active_vid or to_id == active_vid:
			my_movements.append(m)

	if my_movements.is_empty():
		movement_status_bar.hide()
		var legend = get_node_or_null("Legend")
		if legend != null:
			legend.show()
		return

	var legend_node = get_node_or_null("Legend")
	if legend_node != null:
		legend_node.hide()

	movement_status_bar.show()
	var active_m: Dictionary = my_movements[0]
	for m in my_movements:
		var st := str(m.get("state", "outgoing"))
		var tp := str(m.get("type", ""))
		if st == "returning" or tp == "return":
			active_m = m
			break

	var m_type := str(active_m.get("type", "attack"))
	var m_state := str(active_m.get("state", "outgoing"))
	var is_returning := (m_state == "returning" or m_type == "return")
	var is_trade := (m_type == "trade")
	var arrive_unix := int(active_m.get("arrive_unix", now))
	var rem_secs := maxi(0, arrive_unix - now)
	var time_str := "%02d:%02d" % [rem_secs / 60, rem_secs % 60]

	if is_returning:
		movement_status_label.text = " Birlik Dönüş Yolunda! Üsse Kalan Süre: %s (Toplam %d)" % [time_str, my_movements.size()]
		movement_status_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	elif is_trade:
		movement_status_label.text = " Katır Kervanı Sevkiyatta! Kalan Süre: %s (Toplam %d)" % [time_str, my_movements.size()]
		movement_status_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	else:
		movement_status_label.text = " Ordu Seferde! Hedefe Kalan Süre: %s (Toplam %d)" % [time_str, my_movements.size()]
		movement_status_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))


func _on_track_movement_pressed() -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null or gs.movements.is_empty():
		return
	var m: Dictionary = gs.movements[0]
	for chk in gs.movements:
		if str(chk.get("state", "")) == "returning" or str(chk.get("type", "")) == "return":
			m = chk
			break
	var from_id := int(m.get("from_village_id", m.get("village_id", 0)))
	var to_id := int(m.get("to_village_id", 0))
	var origin_v: Dictionary = _find_any_village(from_id, gs)
	var target_v: Dictionary = _find_any_village(to_id, gs)
	if origin_v.is_empty() or target_v.is_empty():
		return
	var from_pos := coord_to_world_pos(float(origin_v.get("x", 100)), float(origin_v.get("y", 100)))
	var to_pos := coord_to_world_pos(float(target_v.get("x", 100)), float(target_v.get("y", 100)))

	var now := int(Time.get_unix_time_from_system())
	var depart_unix := int(m.get("depart_unix", now))
	var arrive_unix := int(m.get("arrive_unix", now + 60))
	var duration := maxi(1, arrive_unix - depart_unix)
	var progress := clampf(float(now - depart_unix) / float(duration), 0.0, 1.0)

	var march_pos := from_pos.lerp(to_pos, progress)
	_center_on_pos(march_pos, true)


# ---------------------------------------------------------------- Sefer Detay & İptal Modalı (Madde 3)
const UNIT_NAMES_MAP := {
	"farmer": "Köy Koruyucusu",
	"spear": "Silahtar",
	"sword": "Muhafız",
	"axe": "Baltacı",
	"bow": "Okçu",
	"spy": "Casus",
	"light": "Akıncı",
	"heavy": "Kara Şövalye",
	"ram": "Şahmerdan",
	"kata": "Mancınık",
	"snob": "Kont",
}


func _on_details_status_bar_pressed() -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null or gs.movements.is_empty():
		return
	var m: Dictionary = gs.movements[0]
	for chk in gs.movements:
		if str(chk.get("state", "")) == "outgoing" and str(chk.get("type", "")) != "return":
			m = chk
			break
	_open_movement_details(m)


func _check_movement_click(screen_click_pos: Vector2) -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null or gs.movements.is_empty():
		return

	var active_v: Dictionary = gs.get_active_village() if gs.has_active_village() else {}
	var active_vid: int = int(active_v.get("id", -1))
	var player_name: String = str(gs.player.get("name", "Kral"))
	var now: int = int(Time.get_unix_time_from_system())

	for m in gs.movements:
		if typeof(m) != TYPE_DICTIONARY:
			continue
		var m_owner := str(m.get("owner", ""))
		var from_id := int(m.get("from_village_id", m.get("village_id", 0)))
		var to_id := int(m.get("to_village_id", 0))
		if not (m_owner == player_name or from_id == active_vid or to_id == active_vid):
			continue

		var origin_v: Dictionary = _find_any_village(from_id, gs)
		var target_v: Dictionary = _find_any_village(to_id, gs)
		var from_x := float(m.get("from_x", origin_v.get("x", -1)))
		var from_y := float(m.get("from_y", origin_v.get("y", -1)))
		var to_x := float(m.get("to_x", target_v.get("x", -1)))
		var to_y := float(m.get("to_y", target_v.get("y", -1)))
		if from_x < 0.0 or from_y < 0.0 or to_x < 0.0 or to_y < 0.0:
			continue

		var origin_pos := coord_to_world_pos(from_x, from_y)
		var target_pos := coord_to_world_pos(to_x, to_y)
		var depart_unix := int(m.get("depart_unix", now))
		var arrive_unix := int(m.get("arrive_unix", now + 60))
		var duration := maxi(1, arrive_unix - depart_unix)
		var progress := clampf(float(now - depart_unix) / float(duration), 0.0, 1.0)
		var current_march_pos := origin_pos.lerp(target_pos, progress)

		var screen_march_pos := (current_march_pos - _camera_pos) * _zoom + map_container.size * 0.5
		var banner_w := 240.0 * _zoom
		var banner_h := 46.0 * _zoom
		var banner_rect := Rect2(screen_march_pos.x - banner_w * 0.5, screen_march_pos.y - 62.0 * _zoom, banner_w, banner_h)

		if screen_click_pos.distance_to(screen_march_pos) <= 55.0 or banner_rect.grow(12.0).has_point(screen_click_pos):
			_open_movement_details(m)
			return


func _create_movement_detail_panel() -> void:
	if movement_detail_panel != null:
		return

	movement_detail_panel = PanelContainer.new()
	movement_detail_panel.name = "MovementDetailModal"
	movement_detail_panel.custom_minimum_size = Vector2(980, 720)
	movement_detail_panel.size = Vector2(980, 720)
	movement_detail_panel.position = Vector2(50, 560)
	movement_detail_panel.z_index = 1100
	movement_detail_panel.z_as_relative = false
	movement_detail_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.11, 0.10, 0.15, 0.98)
	panel_sb.border_color = Color(0.85, 0.72, 0.42, 0.95)
	panel_sb.set_border_width_all(3)
	panel_sb.set_corner_radius_all(20)
	panel_sb.shadow_size = 20
	panel_sb.shadow_color = Color(0, 0, 0, 0.75)
	panel_sb.content_margin_left = 28
	panel_sb.content_margin_right = 28
	panel_sb.content_margin_top = 22
	panel_sb.content_margin_bottom = 24
	movement_detail_panel.add_theme_stylebox_override("panel", panel_sb)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 16)
	movement_detail_panel.add_child(main_vbox)

	# 1) Üst Başlık & Kapat Butonu
	var header_hbox := HBoxContainer.new()
	_detail_title_lbl = Label.new()
	_detail_title_lbl.text = "⚔️ Sefer Detayları"
	_detail_title_lbl.add_theme_font_override("font", FontNunitoBold)
	_detail_title_lbl.add_theme_font_size_override("font_size", 30)
	_detail_title_lbl.add_theme_constant_override("outline_size", 3)
	_detail_title_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
	_detail_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.75))
	_detail_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(_detail_title_lbl)

	var btn_close := Button.new()
	btn_close.text = "✕"
	btn_close.custom_minimum_size = Vector2(50, 50)
	btn_close.add_theme_font_override("font", FontNunitoBold)
	btn_close.add_theme_font_size_override("font_size", 28)
	btn_close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_close.pressed.connect(func(): movement_detail_panel.hide())
	header_hbox.add_child(btn_close)
	main_vbox.add_child(header_hbox)

	# 2) Rota ve Köy Bilgi Kartı
	var route_panel := PanelContainer.new()
	var route_sb := StyleBoxFlat.new()
	route_sb.bg_color = Color(0.08, 0.07, 0.10, 0.90)
	route_sb.border_color = Color(0.85, 0.72, 0.42, 0.60)
	route_sb.set_border_width_all(1)
	route_sb.set_corner_radius_all(14)
	route_sb.content_margin_left = 18
	route_sb.content_margin_right = 18
	route_sb.content_margin_top = 12
	route_sb.content_margin_bottom = 12
	route_panel.add_theme_stylebox_override("panel", route_sb)

	var route_vbox := VBoxContainer.new()
	route_vbox.add_theme_constant_override("separation", 6)

	_detail_route_lbl = Label.new()
	_detail_route_lbl.add_theme_font_override("font", FontNunitoBold)
	_detail_route_lbl.add_theme_font_size_override("font_size", 24)
	_detail_route_lbl.add_theme_constant_override("outline_size", 3)
	_detail_route_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
	_detail_route_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	route_vbox.add_child(_detail_route_lbl)

	_detail_status_lbl = Label.new()
	_detail_status_lbl.add_theme_font_override("font", FontNunitoBold)
	_detail_status_lbl.add_theme_font_size_override("font_size", 22)
	_detail_status_lbl.add_theme_constant_override("outline_size", 3)
	_detail_status_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
	route_vbox.add_child(_detail_status_lbl)

	route_panel.add_child(route_vbox)
	main_vbox.add_child(route_panel)

	# 3) Kalan Süre Kartı (Canlı Sayaç)
	var time_panel := PanelContainer.new()
	var time_sb := StyleBoxFlat.new()
	time_sb.bg_color = Color(0.06, 0.05, 0.08, 0.95)
	time_sb.border_color = Color(0.35, 0.85, 1.0, 0.85)
	time_sb.set_border_width_all(2)
	time_sb.set_corner_radius_all(14)
	time_sb.content_margin_left = 18
	time_sb.content_margin_right = 18
	time_sb.content_margin_top = 10
	time_sb.content_margin_bottom = 10
	time_panel.add_theme_stylebox_override("panel", time_sb)

	var time_vbox := VBoxContainer.new()
	time_vbox.add_theme_constant_override("separation", 4)

	_detail_timer_lbl = Label.new()
	_detail_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_timer_lbl.add_theme_font_override("font", FontNunitoBold)
	_detail_timer_lbl.add_theme_font_size_override("font_size", 36)
	_detail_timer_lbl.add_theme_constant_override("outline_size", 4)
	_detail_timer_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
	_detail_timer_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.40))
	time_vbox.add_child(_detail_timer_lbl)

	_detail_sub_timer_lbl = Label.new()
	_detail_sub_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_sub_timer_lbl.add_theme_font_override("font", FontNunitoBold)
	_detail_sub_timer_lbl.add_theme_font_size_override("font_size", 22)
	_detail_sub_timer_lbl.add_theme_constant_override("outline_size", 3)
	_detail_sub_timer_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
	_detail_sub_timer_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	time_vbox.add_child(_detail_sub_timer_lbl)

	time_panel.add_child(time_vbox)
	main_vbox.add_child(time_panel)

	# 4) Seferdeki Birlikler Başlığı ve Izgara
	var units_title := Label.new()
	units_title.text = " Seferdeki Birlikler / Sevkiyat:"
	units_title.add_theme_font_override("font", FontNunitoBold)
	units_title.add_theme_font_size_override("font_size", 24)
	units_title.add_theme_constant_override("outline_size", 3)
	units_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
	units_title.add_theme_color_override("font_color", Color(1.0, 0.90, 0.65))
	main_vbox.add_child(units_title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 180)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_units_grid = GridContainer.new()
	_detail_units_grid.columns = 2
	_detail_units_grid.add_theme_constant_override("h_separation", 16)
	_detail_units_grid.add_theme_constant_override("v_separation", 10)
	_detail_units_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_detail_units_grid)
	main_vbox.add_child(scroll)

	# 5) İptal Durum Bildirimi
	_detail_cancel_note = Label.new()
	_detail_cancel_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_cancel_note.add_theme_font_override("font", FontNunitoBold)
	_detail_cancel_note.add_theme_font_size_override("font_size", 22)
	_detail_cancel_note.add_theme_constant_override("outline_size", 3)
	_detail_cancel_note.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
	_detail_cancel_note.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0))
	main_vbox.add_child(_detail_cancel_note)

	# 6) Butonlar (İptal Et & Kapat)
	var btns_hbox := HBoxContainer.new()
	btns_hbox.add_theme_constant_override("separation", 16)

	_detail_btn_cancel = Button.new()
	_detail_btn_cancel.text = " Saldırıyı İptal Et (Geri Çağır)"
	_detail_btn_cancel.custom_minimum_size = Vector2(0, 56)
	_detail_btn_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_btn_cancel.add_theme_font_override("font", FontNunitoBold)
	_detail_btn_cancel.add_theme_font_size_override("font_size", 24)
	_detail_btn_cancel.add_theme_constant_override("outline_size", 3)
	_detail_btn_cancel.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
	_detail_btn_cancel.add_theme_color_override("font_color", Color(1.0, 0.95, 0.90))
	_detail_btn_cancel.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	_detail_btn_cancel.add_theme_color_override("font_pressed_color", Color(1.0, 0.92, 0.65))
	_detail_btn_cancel.add_theme_color_override("font_focus_color", Color(1.0, 0.95, 0.90))
	_detail_btn_cancel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var cancel_sb := StyleBoxFlat.new()
	cancel_sb.bg_color = Color(0.65, 0.15, 0.15, 0.95)
	cancel_sb.border_color = Color(1.0, 0.40, 0.35, 0.95)
	cancel_sb.set_border_width_all(2)
	cancel_sb.set_corner_radius_all(14)
	cancel_sb.shadow_size = 8
	cancel_sb.shadow_color = Color(0.4, 0, 0, 0.6)
	_detail_btn_cancel.add_theme_stylebox_override("normal", cancel_sb)

	var cancel_sb_h := cancel_sb.duplicate()
	cancel_sb_h.bg_color = Color(0.85, 0.20, 0.20, 1.0)
	_detail_btn_cancel.add_theme_stylebox_override("hover", cancel_sb_h)
	_detail_btn_cancel.add_theme_stylebox_override("pressed", cancel_sb_h)

	_detail_btn_cancel.pressed.connect(func(): _on_cancel_movement_pressed())
	btns_hbox.add_child(_detail_btn_cancel)

	var btn_dismiss := Button.new()
	btn_dismiss.text = "Kapat"
	btn_dismiss.custom_minimum_size = Vector2(200, 56)
	btn_dismiss.add_theme_font_override("font", FontNunitoBold)
	btn_dismiss.add_theme_font_size_override("font_size", 24)
	btn_dismiss.add_theme_constant_override("outline_size", 2)
	btn_dismiss.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	btn_dismiss.add_theme_color_override("font_color", Color(0.95, 0.90, 0.82))
	btn_dismiss.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	btn_dismiss.add_theme_color_override("font_pressed_color", Color(1.0, 0.95, 0.70))
	btn_dismiss.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_dismiss.pressed.connect(func(): movement_detail_panel.hide())
	btns_hbox.add_child(btn_dismiss)

	main_vbox.add_child(btns_hbox)
	add_child(movement_detail_panel)
	movement_detail_panel.hide()


func _open_movement_details(m: Dictionary) -> void:
	_create_movement_detail_panel()
	_detail_movement_ref = m
	_refresh_movement_detail_content()
	movement_detail_panel.show()
	movement_detail_panel.move_to_front()


func _refresh_movement_detail_content() -> void:
	if _detail_movement_ref.is_empty():
		return

	var m := _detail_movement_ref
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null

	var m_type := str(m.get("type", "attack"))
	var m_state := str(m.get("state", "outgoing"))
	var is_returning := (m_state == "returning" or m_type == "return")
	var is_trade := (m_type == "trade")

	if is_returning:
		_detail_title_lbl.text = " Birlik Dönüş Hareketi Detayı"
	elif is_trade:
		_detail_title_lbl.text = " Katır Kervanı Sevkiyat Detayı"
	else:
		_detail_title_lbl.text = " Ordu Seferi Detayları (Saldırı)"

	var from_id := int(m.get("from_village_id", m.get("village_id", 0)))
	var to_id := int(m.get("to_village_id", 0))
	var origin_v: Dictionary = _find_any_village(from_id, gs) if gs else {}
	var target_v: Dictionary = _find_any_village(to_id, gs) if gs else {}

	var orig_name: String = str(origin_v.get("name", "Köy"))
	var orig_x: int = int(origin_v.get("x", m.get("from_x", 0)))
	var orig_y: int = int(origin_v.get("y", m.get("from_y", 0)))

	var tgt_name: String = str(target_v.get("name", "Hedef"))
	var tgt_x: int = int(target_v.get("x", m.get("to_x", 0)))
	var tgt_y: int = int(target_v.get("y", m.get("to_y", 0)))

	if is_returning:
		_detail_route_lbl.text = " Konum: (%.1f|%.1f)   Üs: %s (%d|%d)" % [float(m.get("from_x", orig_x)), float(m.get("from_y", orig_y)), orig_name, orig_x, orig_y]
		_detail_status_lbl.text = "• Durum: Köye Geri Dönüyor"
		_detail_status_lbl.add_theme_color_override("font_color", Color(0.35, 0.90, 1.0))
	else:
		_detail_route_lbl.text = " Çıkış: %s (%d|%d)   Hedef: %s (%d|%d)" % [orig_name, orig_x, orig_y, tgt_name, tgt_x, tgt_y]
		_detail_status_lbl.text = "• Durum: Hedefe İlerliyor"
		_detail_status_lbl.add_theme_color_override("font_color", Color(1.0, 0.50, 0.30))

	_update_movement_detail_timer()

	for child in _detail_units_grid.get_children():
		child.queue_free()

	var units: Dictionary = m.get("units", {})
	var carry: Dictionary = m.get("carry", {})
	var has_items := false

	for u_key in ["farmer", "spear", "sword", "axe", "bow", "spy", "light", "heavy", "ram", "kata", "snob"]:
		var count := int(units.get(u_key, 0))
		if count > 0:
			has_items = true
			var pill := PanelContainer.new()
			var pill_sb := StyleBoxFlat.new()
			pill_sb.bg_color = Color(0.14, 0.13, 0.18, 0.90)
			pill_sb.border_color = Color(0.85, 0.72, 0.42, 0.75)
			pill_sb.set_border_width_all(1)
			pill_sb.set_corner_radius_all(10)
			pill_sb.content_margin_left = 14
			pill_sb.content_margin_right = 14
			pill_sb.content_margin_top = 8
			pill_sb.content_margin_bottom = 8
			pill.add_theme_stylebox_override("panel", pill_sb)

			var plbl := Label.new()
			var u_tr: String = UNIT_NAMES_MAP.get(u_key, u_key)
			plbl.text = " %s: %d" % [u_tr, count]
			plbl.add_theme_font_override("font", FontNunitoBold)
			plbl.add_theme_font_size_override("font_size", 22)
			plbl.add_theme_constant_override("outline_size", 3)
			plbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
			plbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
			pill.add_child(plbl)
			_detail_units_grid.add_child(pill)

	if is_trade or carry.size() > 0:
		for r_key in ["wood", "stone", "iron"]:
			var amt := int(carry.get(r_key, 0))
			if amt > 0:
				has_items = true
				var pill := PanelContainer.new()
				var pill_sb := StyleBoxFlat.new()
				pill_sb.bg_color = Color(0.14, 0.13, 0.18, 0.90)
				pill_sb.border_color = Color(0.85, 0.72, 0.42, 0.75)
				pill_sb.set_border_width_all(1)
				pill_sb.set_corner_radius_all(10)
				pill_sb.content_margin_left = 14
				pill_sb.content_margin_right = 14
				pill_sb.content_margin_top = 8
				pill_sb.content_margin_bottom = 8
				pill.add_theme_stylebox_override("panel", pill_sb)

				var plbl := Label.new()
				var r_tr := "Odun" if r_key == "wood" else ("Taş" if r_key == "stone" else "Demir")
				var r_icon := "" if r_key == "wood" else ("" if r_key == "stone" else "")
				plbl.text = "%s %s: %d" % [r_icon, r_tr, amt]
				plbl.add_theme_font_override("font", FontNunitoBold)
				plbl.add_theme_font_size_override("font_size", 22)
				plbl.add_theme_constant_override("outline_size", 3)
				plbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
				plbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.50))
				pill.add_child(plbl)
				_detail_units_grid.add_child(pill)

	if not has_items:
		var empty_lbl := Label.new()
		empty_lbl.text = "Birlik veya hammadde bilgisi yok."
		empty_lbl.add_theme_font_override("font", FontNunitoBold)
		empty_lbl.add_theme_font_size_override("font_size", 22)
		_detail_units_grid.add_child(empty_lbl)

	if is_returning:
		_detail_btn_cancel.hide()
		_detail_cancel_note.text = " Birlikler geri dönüş yolundadır, tekrar iptal edilemez."
		_detail_cancel_note.show()
	else:
		_detail_btn_cancel.show()
		_detail_cancel_note.text = " İptal edildiğinde birlikler bulundukları noktadan derhal üsse geri dönerler."
		_detail_cancel_note.show()


func _update_movement_detail_timer() -> void:
	if movement_detail_panel == null or not movement_detail_panel.visible or _detail_movement_ref.is_empty():
		return

	var m := _detail_movement_ref
	var now := int(Time.get_unix_time_from_system())
	var depart_unix := int(m.get("depart_unix", now))
	var arrive_unix := int(m.get("arrive_unix", now + 60))
	var duration := maxi(1, arrive_unix - depart_unix)
	var rem_secs := maxi(0, arrive_unix - now)
	var progress := clampf(float(now - depart_unix) / float(duration), 0.0, 1.0)

	var is_returning := (str(m.get("state", "")) == "returning" or str(m.get("type", "")) == "return")
	var target_label := "Üsse Varışa Kalan Süre:" if is_returning else "Hedefe Kalan Süre:"
	var time_str := "%02d:%02d" % [rem_secs / 60, rem_secs % 60]

	_detail_timer_lbl.text = "%s %s" % [target_label, time_str]
	_detail_sub_timer_lbl.text = "İlerleme: %%%d | Kalan: %d saniye" % [int(progress * 100.0), rem_secs]


func _on_cancel_movement_pressed() -> void:
	if _detail_movement_ref.is_empty():
		return
	var m := _detail_movement_ref
	var now := int(Time.get_unix_time_from_system())
	var depart_unix := int(m.get("depart_unix", now))
	var arrive_unix := int(m.get("arrive_unix", now + 60))
	var total_dur := maxi(1, arrive_unix - depart_unix)
	var elapsed := maxi(1, now - depart_unix)

	if elapsed >= total_dur:
		return

	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null:
		return

	var from_id := int(m.get("from_village_id", m.get("village_id", 0)))
	var to_id := int(m.get("to_village_id", 0))
	var origin_v: Dictionary = _find_any_village(from_id, gs)
	var target_v: Dictionary = _find_any_village(to_id, gs)

	var orig_x := float(m.get("from_x", origin_v.get("x", 100)))
	var orig_y := float(m.get("from_y", origin_v.get("y", 100)))
	var tgt_x := float(m.get("to_x", target_v.get("x", 100)))
	var tgt_y := float(m.get("to_y", target_v.get("y", 100)))

	var progress := clampf(float(elapsed) / float(total_dur), 0.0, 1.0)
	var curr_x := lerpf(orig_x, tgt_x, progress)
	var curr_y := lerpf(orig_y, tgt_y, progress)

	# Birlikler bulundukları noktadan köye geri dönmeye başlarlar.
	# Gidilen süre kadar dönüş süresi işletilir.
	var return_duration := elapsed
	var return_arrive_unix := now + return_duration

	m["state"] = "returning"
	m["type"] = "return"
	m["from_x"] = curr_x
	m["from_y"] = curr_y
	m["to_x"] = orig_x
	m["to_y"] = orig_y
	m["to_village_id"] = from_id
	m["from_village_id"] = 0
	m["village_id"] = from_id
	m["depart_unix"] = now
	m["arrive_unix"] = return_arrive_unix
	m["return_unix"] = return_arrive_unix

	_refresh_movement_detail_content()
	if movements_layer != null:
		movements_layer.queue_redraw()
	_refresh_movement_status_bar()

