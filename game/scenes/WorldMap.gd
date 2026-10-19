extends Control
## WorldMap — Dünya Haritası ve Sefer Sevk Ekranı (Taht ve Kılıç / A-ARAYUZ).

const TravelScript := preload("res://scripts/world/Travel.gd")
const ProtectionScript := preload("res://scripts/sim/actions/Protection.gd")
const Palette := preload("res://themes/Palette.gd")
const MapVillageViewScript := preload("res://scenes/map/MapVillageView.gd")

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
	_build_map()


func _build_map() -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null:
		return

	# Grid boyutunu dinamik ayarla
	village_grid_container.custom_minimum_size = Vector2(200 * CELL_SIZE, 200 * CELL_SIZE)

	# 1. Doğal harita dekorasyonu (Ormanlar ve Dağlar)
	_build_nature_decorations()

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


func _build_nature_decorations() -> void:
	if _decorations_built:
		return
	_decorations_built = true

	var nature_container := Control.new()
	nature_container.name = "NatureContainer"
	nature_container.mouse_filter = MOUSE_FILTER_IGNORE
	village_grid_container.add_child(nature_container)

	# Deterministik pseudo-random doğa varlıkları (Ormanlar, Dağlar)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var pine_tex: Texture2D = load("res://assets/sprites/icons/cartography/2x/treePines.png") if ResourceLoader.exists("res://assets/sprites/icons/cartography/2x/treePines.png") else null
	var rock_tex: Texture2D = load("res://assets/sprites/icons/cartography/2x/rocksMountain.png") if ResourceLoader.exists("res://assets/sprites/icons/cartography/2x/rocksMountain.png") else null

	for i in range(80):
		var nx := rng.randi_range(60, 140)
		var ny := rng.randi_range(60, 140)
		var is_rock := (rng.randf() > 0.6)

		var deco := TextureRect.new()
		deco.texture = rock_tex if (is_rock and rock_tex != null) else pine_tex
		if deco.texture == null:
			continue
		deco.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		deco.size = Vector2(48, 48)
		deco.position = Vector2(nx * CELL_SIZE + rng.randf_range(10, 40), ny * CELL_SIZE + rng.randf_range(10, 40))
		deco.modulate = Color(0.35, 0.45, 0.30, 0.65) if not is_rock else Color(0.45, 0.40, 0.35, 0.70)
		deco.mouse_filter = MOUSE_FILTER_IGNORE
		nature_container.add_child(deco)


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
