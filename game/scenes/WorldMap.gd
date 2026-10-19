extends Control
## WorldMap — Dünya Haritası ve Sefer Sevk Ekranı (Taht ve Kılıç / A-ARAYUZ).

const TravelScript := preload("res://scripts/world/Travel.gd")
const ProtectionScript := preload("res://scripts/sim/actions/Protection.gd")
const Palette := preload("res://themes/Palette.gd")
const MapVillageViewScript := preload("res://scenes/map/MapVillageView.gd")
const WorldDecorScript := preload("res://scenes/map/WorldDecor.gd")
const MapRulerScript := preload("res://scenes/map/MapRuler.gd")

@onready var resource_bar: PanelContainer = $ResourceBar
@onready var bottom_nav: PanelContainer = $BottomNav
@onready var send_troops_panel: PanelContainer = $SendTroopsPanel
@onready var map_scroll: ScrollContainer = $MapContainer/Scroll
@onready var village_grid_container: Control = $MapContainer/Scroll/GridControl
@onready var coord_x_input: SpinBox = $Header/HBox/CoordX
@onready var coord_y_input: SpinBox = $Header/HBox/CoordY
@onready var btn_goto: Button = $Header/HBox/BtnGoto

const CELL_SIZE := 96.0

var _village_buttons: Dictionary = {}
var _decorations_built: bool = false


func _ready() -> void:
	send_troops_panel.hide()
	btn_goto.pressed.connect(_on_goto_pressed)
	_style_header()
	_build_map()
	_add_map_overlays()


func _build_map() -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null:
		return

	# Grid boyutunu dinamik ayarla
	village_grid_container.custom_minimum_size = Vector2(200 * CELL_SIZE, 200 * CELL_SIZE)

	# 1. Parşömen/kartografi dekor katmanı (en altta)
	_build_decor_layer()

	# 2. Koordinat ızgarası
	_build_grid_overlay()

	var villages: Array = gs.villages
	var active_v: Dictionary = gs.get_active_village() if gs.has_active_village() else {}
	var center_x: int = int(active_v.get("x", 100))
	var center_y: int = int(active_v.get("y", 100))

	for v in villages:
		if typeof(v) != TYPE_DICTIONARY:
			continue
		var vid: int = int(v.get("id", -1))
		var vx: int = int(v.get("x", 0))
		var vy: int = int(v.get("y", 0))

		var is_player: bool = (vid == int(active_v.get("id", -1)))
		var is_barb: bool = bool(v.get("is_barbarian", false)) or str(v.get("owner", "")) == "Soyguncular"

		var v_view = MapVillageViewScript.new()
		v_view.position = Vector2(vx * CELL_SIZE, vy * CELL_SIZE)
		v_view.setup(v, is_player, is_barb)
		v_view.clicked.connect(func(): _on_village_clicked(v))

		village_grid_container.add_child(v_view)
		_village_buttons[vid] = v_view.get_button()

	# Haritayı aktif köye ortala
	call_deferred("_center_on", center_x * CELL_SIZE, center_y * CELL_SIZE)


func _build_decor_layer() -> void:
	if _decorations_built:
		return
	_decorations_built = true

	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null

	var decor := WorldDecorScript.new()
	decor.name = "WorldDecor"
	decor.mouse_filter = MOUSE_FILTER_IGNORE
	decor.custom_minimum_size = Vector2(200 * CELL_SIZE, 200 * CELL_SIZE)
	decor.size = decor.custom_minimum_size
	village_grid_container.add_child(decor)
	decor.setup(gs.villages if gs != null else [])


func _build_grid_overlay() -> void:
	var grid := Control.new()
	grid.name = "GridOverlay"
	grid.mouse_filter = MOUSE_FILTER_IGNORE
	village_grid_container.add_child(grid)

	var line_col := Color(0.42, 0.31, 0.16, 0.14)
	var world_px := 200.0 * CELL_SIZE

	for i in range(0, 201, 10):
		var vline := ColorRect.new()
		vline.color = line_col
		vline.position = Vector2(i * CELL_SIZE, 0)
		vline.size = Vector2(2, world_px)
		vline.mouse_filter = MOUSE_FILTER_IGNORE
		grid.add_child(vline)

		var hline := ColorRect.new()
		hline.color = line_col
		hline.position = Vector2(0, i * CELL_SIZE)
		hline.size = Vector2(world_px, 2)
		hline.mouse_filter = MOUSE_FILTER_IGNORE
		grid.add_child(hline)


func _add_map_overlays() -> void:
	# Pusula gülü (sabit, haritayla kaymaz)
	var compass_path := "res://assets/sprites/icons/cartography/2x/compass.png"
	if ResourceLoader.exists(compass_path):
		var compass := TextureRect.new()
		compass.name = "Compass"
		compass.texture = load(compass_path)
		compass.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		compass.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		compass.position = Vector2(1080 - 176, 300)
		compass.size = Vector2(128, 128)
		compass.modulate = Color(0.32, 0.24, 0.12, 0.55)
		compass.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(compass)

	# Harita çerçevesi + koordinat cetveli (haritayla kaymaz)
	var map_container: Control = $MapContainer
	var ruler = MapRulerScript.new()
	ruler.name = "MapRuler"
	ruler.map_scroll = map_scroll
	map_container.add_child(ruler)


	# "Köyüme dön" yüzen düğmesi
	var back_btn := Button.new()
	back_btn.name = "CenterHomeBtn"
	back_btn.text = "⌖ Köyüm"
	back_btn.add_theme_font_size_override("font_size", 18)
	back_btn.custom_minimum_size = Vector2(150, 56)
	back_btn.size = Vector2(150, 56)
	back_btn.position = Vector2(1080 - 176, 1920 - 116 - 74)
	back_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.11, 0.14, 0.92)
	sb.border_color = Color(0.85, 0.72, 0.42, 0.95)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 8
	back_btn.add_theme_stylebox_override("normal", sb)
	var sb_h := sb.duplicate()
	sb_h.bg_color = Color(0.22, 0.18, 0.12, 0.96)
	back_btn.add_theme_stylebox_override("hover", sb_h)
	back_btn.add_theme_stylebox_override("pressed", sb_h)
	back_btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.70))
	back_btn.pressed.connect(_center_on_home)
	add_child(back_btn)


func _style_header() -> void:
	# Başlık: kartografik serif (Cinzel) + parşömen tonu
	var title: Label = $Header/HBox/Title
	title.text = "Dünya Haritası"
	var cinzel := load("res://assets/fonts/Cinzel-Bold.ttf")
	if cinzel != null:
		title.add_theme_font_override("font", cinzel)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.66))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	title.add_theme_constant_override("shadow_offset_y", 2)

	# Koordinat kutuları: koyu, altın çerçeveli "harita aleti" görünümü
	for sb in [coord_x_input, coord_y_input]:
		_style_spinbox(sb)

	# "Git" düğmesi: altın parşömen düğmesi
	var goto_btn: Button = $Header/HBox/BtnGoto
	goto_btn.text = "Git  ➤"
	goto_btn.add_theme_font_size_override("font_size", 22)
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = Color(0.85, 0.72, 0.42, 0.95)
	gsb.border_color = Color(0.36, 0.27, 0.14, 0.9)
	gsb.set_border_width_all(2)
	gsb.set_corner_radius_all(12)
	gsb.shadow_color = Color(0, 0, 0, 0.35)
	gsb.shadow_size = 5
	var gsb_h := gsb.duplicate()
	gsb_h.bg_color = Color(0.95, 0.83, 0.53, 1.0)
	goto_btn.add_theme_stylebox_override("normal", gsb)
	goto_btn.add_theme_stylebox_override("hover", gsb_h)
	goto_btn.add_theme_stylebox_override("pressed", gsb)
	goto_btn.add_theme_color_override("font_color", Color(0.20, 0.15, 0.07))
	goto_btn.add_theme_color_override("font_hover_color", Color(0.14, 0.10, 0.05))


func _style_spinbox(sb: SpinBox) -> void:
	var le := sb.get_line_edit()
	le.add_theme_font_size_override("font_size", 22)
	le.add_theme_color_override("font_color", Color(1.0, 0.92, 0.66))
	le.add_theme_color_override("caret_color", Color(1.0, 0.92, 0.66))
	le.add_theme_constant_override("caret_width", 2)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.07, 0.06, 0.09, 0.85)
	normal.border_color = Color(0.85, 0.72, 0.42, 0.35)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(10)
	normal.content_margin_left = 14
	normal.content_margin_right = 12
	le.add_theme_stylebox_override("normal", normal)
	var focus := normal.duplicate()
	focus.border_color = Color(1.0, 0.92, 0.65, 0.95)
	le.add_theme_stylebox_override("focus", focus)
	# Ok ikonlarını gizle (koyu zeminde beyaz çentiği önler; tekerlek adımı sürer)
	var img := Image.create_empty(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var tex := ImageTexture.create_from_image(img)
	sb.add_theme_icon_override("updown", tex)
	sb.add_theme_icon_override("up", tex)
	sb.add_theme_icon_override("down", tex)



func _center_on_home() -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null or not gs.has_active_village():
		return
	var v: Dictionary = gs.get_active_village()
	_center_on(int(v.get("x", 100)) * CELL_SIZE, int(v.get("y", 100)) * CELL_SIZE)


func _center_on(pos_x: float, pos_y: float) -> void:
	if map_scroll != null:
		map_scroll.scroll_horizontal = int(pos_x - 540)
		map_scroll.scroll_vertical = int(pos_y - 800)


func _on_goto_pressed() -> void:
	var target_x: float = coord_x_input.value * CELL_SIZE
	var target_y: float = coord_y_input.value * CELL_SIZE
	_center_on(target_x, target_y)


func _on_village_clicked(target_v: Dictionary) -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null or not gs.has_active_village():
		return

	var from_v: Dictionary = gs.get_active_village()
	send_troops_panel.show_target(from_v, target_v)
