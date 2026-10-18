extends Control
## Village — 2.5D Köy Ekranı (Taht ve Kılıç / A-ARAYUZ).

const GameLoopScript := preload("res://scripts/core/GameLoop.gd")
const RulesEngineScript := preload("res://scripts/rules/RulesEngine.gd")
const Palette := preload("res://themes/Palette.gd")

@onready var resource_bar: PanelContainer = $ResourceBar
@onready var bottom_nav: PanelContainer = $BottomNav
@onready var building_panel: PanelContainer = $BuildingPanel
@onready var village_viewport: Control = $VillageArea/BuildingsContainer

## 15 binanın 2.5D izometrik koordinat haritası (1080x1920 dikey ekran merkezli)
const BUILDING_LAYOUT := {
	"main": Vector2(460, 480),       # Kale (Merkez tepe)
	"snob": Vector2(250, 430),       # Köşk
	"garage": Vector2(670, 430),     # Simyager
	"storage": Vector2(720, 620),    # Depo
	"hide": Vector2(870, 690),       # Gizli Depo
	"barracks": Vector2(750, 840),   # Kışla
	"stable": Vector2(620, 980),     # Katır çiftliği
	"farm": Vector2(180, 680),       # Değirmen
	"wood": Vector2(120, 920),       # Oduncu Kampı
	"stone": Vector2(850, 1020),     # Taş Ocağı
	"iron": Vector2(320, 1150),      # Maden Ocağı
	"market": Vector2(520, 1180),    # Market
	"smith": Vector2(680, 1220),     # Kuyumcu
	"statue": Vector2(470, 800),     # Anıt (Meydan)
	"wall": Vector2(460, 1420),      # Sur / Kapı
}

var _game_loop: Node = null
var _building_nodes: Dictionary = {}


func _ready() -> void:
	_ensure_game_loop()
	_setup_village_nodes()

	building_panel.hide()
	building_panel.building_switched.connect(_on_building_selected)

	var bus = Engine.get_main_loop().root.get_node_or_null("EventBus") if Engine.get_main_loop() is SceneTree else null
	if bus != null:
		if bus.has_signal("building_completed") and not bus.building_completed.is_connected(_on_building_completed):
			bus.building_completed.connect(_on_building_completed)

	refresh_all()


func _ensure_game_loop() -> void:
	if GameLoopScript.instance == null:
		_game_loop = GameLoopScript.new()
		add_child(_game_loop)


func _setup_village_nodes() -> void:
	for b_key in BUILDING_LAYOUT.keys():
		var pos: Vector2 = BUILDING_LAYOUT[b_key]

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(160, 120)
		btn.position = pos
		btn.theme_type_variation = "FlatButton"

		var vbox := VBoxContainer.new()
		vbox.anchors_preset = Control.PRESET_FULL_RECT
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER

		var b_data: Dictionary = RulesEngineScript.building_data(b_key)
		var b_name: String = str(b_data.get("name", b_key))

		var icon_lbl := Label.new()
		icon_lbl.text = _get_building_icon(b_key)
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.theme_override_font_sizes/font_size = 40
		vbox.add_child(icon_lbl)

		var name_lbl := Label.new()
		name_lbl.text = b_name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.theme_override_font_sizes/font_size = 18
		name_lbl.theme_override_colors/font_color = Palette.c("murekkep")
		vbox.add_child(name_lbl)

		var lvl_lbl := Label.new()
		lvl_lbl.text = "Sv. 0"
		lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lvl_lbl.theme_override_font_sizes/font_size = 16
		lvl_lbl.theme_override_colors/font_color = Palette.c("safir")
		vbox.add_child(lvl_lbl)

		btn.add_child(vbox)
		btn.pressed.connect(func(): _on_building_selected(b_key))

		village_viewport.add_child(btn)
		_building_nodes[b_key] = {"btn": btn, "lvl": lvl_lbl, "name": name_lbl}


func _on_building_selected(key: String) -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null or not gs.has_active_village():
		return
	var v: Dictionary = gs.get_active_village()
	building_panel.show_building(v, key)


func _on_building_completed(_village_id: int, _key: String, _level: int) -> void:
	refresh_all()
	if building_panel.visible:
		building_panel.refresh()


func refresh_all() -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null or not gs.has_active_village():
		return

	var v: Dictionary = gs.get_active_village()
	var buildings: Dictionary = v.get("buildings", {})

	for b_key in _building_nodes.keys():
		var lvl: int = int(buildings.get(b_key, 0))
		var node_dict: Dictionary = _building_nodes[b_key]
		var lvl_lbl: Label = node_dict["lvl"]
		lvl_lbl.text = "Sv. %d" % lvl
		if lvl > 0:
			lvl_lbl.modulate = Palette.c("basari")
		else:
			lvl_lbl.modulate = Palette.c("pasif")

	if resource_bar != null:
		resource_bar.refresh()


func _get_building_icon(key: String) -> String:
	match key:
		"main": return "🏰"
		"wood": return "🪓"
		"stone": return "⛏️"
		"iron": return "⚒️"
		"storage": return "📦"
		"hide": return "🗝️"
		"farm": return "🌾"
		"barracks": return "🛡️"
		"wall": return "🧱"
		"market": return "⚖️"
		"stable": return "🐴"
		"garage": return "🧪"
		"snob": return "👑"
		"smith": return "💍"
		"statue": return "🗿"
		_: return "🏠"
