extends Control
## WorldMap — Dünya Haritası ve Sefer Sevk Ekranı (Taht ve Kılıç / A-ARAYUZ).

const TravelScript := preload("res://scripts/world/Travel.gd")
const ProtectionScript := preload("res://scripts/sim/actions/Protection.gd")
const Palette := preload("res://themes/Palette.gd")

@onready var resource_bar: PanelContainer = $ResourceBar
@onready var bottom_nav: PanelContainer = $BottomNav
@onready var send_troops_panel: PanelContainer = $SendTroopsPanel
@onready var map_scroll: ScrollContainer = $MapContainer/Scroll
@onready var village_grid_container: Control = $MapContainer/Scroll/GridControl
@onready var coord_x_input: SpinBox = $Header/HBox/CoordX
@onready var coord_y_input: SpinBox = $Header/HBox/CoordY
@onready var btn_goto: Button = $Header/HBox/BtnGoto

var _village_buttons: Dictionary = {}


func _ready() -> void:
	send_troops_panel.hide()
	btn_goto.pressed.connect(_on_goto_pressed)
	_build_map()


func _build_map() -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null:
		return

	var villages: Array = gs.villages
	var active_v: Dictionary = gs.get_active_village() if gs.has_active_village() else {}
	var center_x: int = int(active_v.get("x", 100))
	var center_y: int = int(active_v.get("y", 100))

	# Aktif köyün etrafındaki ±30 alanlık bölgedeki köyleri haritaya ekle
	var cell_size := 64.0

	for v in villages:
		if typeof(v) != TYPE_DICTIONARY:
			continue
		var vid: int = int(v.get("id", -1))
		var vx: int = int(v.get("x", 0))
		var vy: int = int(v.get("y", 0))

		var is_player: bool = (vid == int(active_v.get("id", -1)))
		var is_barb: bool = bool(v.get("is_barbarian", false)) or str(v.get("owner", "")) == "Soyguncular"

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(cell_size, cell_size)
		btn.position = Vector2(vx * cell_size, vy * cell_size)

		if is_player:
			btn.text = "👑"
			btn.modulate = Palette.c("kendi")
		elif is_barb:
			btn.text = "⛺"
			btn.modulate = Palette.c("notr")
		else:
			btn.text = "🏰"
			btn.modulate = Palette.c("dusman")

		btn.pressed.connect(func(): _on_village_clicked(v))
		village_grid_container.add_child(btn)
		_village_buttons[vid] = btn

	# Haritayı aktif köye ortala
	call_deferred("_center_on", center_x * cell_size, center_y * cell_size)


func _center_on(pos_x: float, pos_y: float) -> void:
	if map_scroll != null:
		map_scroll.scroll_horizontal = int(pos_x - 540)
		map_scroll.scroll_vertical = int(pos_y - 800)


func _on_goto_pressed() -> void:
	var target_x: float = coord_x_input.value * 64.0
	var target_y: float = coord_y_input.value * 64.0
	_center_on(target_x, target_y)


func _on_village_clicked(target_v: Dictionary) -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null or not gs.has_active_village():
		return

	var from_v: Dictionary = gs.get_active_village()
	send_troops_panel.show_target(from_v, target_v)
