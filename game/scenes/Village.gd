extends Control
## Village — 2.5D Köy Ekranı (Taht ve Kılıç / A-ARAYUZ).

const GameLoopScript := preload("res://scripts/core/GameLoop.gd")
const RulesEngineScript := preload("res://scripts/rules/RulesEngine.gd")
const Palette := preload("res://themes/Palette.gd")

const EconomyAPIScript := preload("res://scripts/sim/economy/EconomyAPI.gd")

@onready var resource_bar: PanelContainer = $ResourceBar
@onready var bottom_nav: PanelContainer = $BottomNav
@onready var building_panel: PanelContainer = $BuildingPanel
@onready var village_viewport: Control = $VillageArea/BuildingsContainer
@onready var queue_hud: PanelContainer = $QueueHUD
@onready var queue_title: Label = $QueueHUD/VBox/TitleLabel
@onready var queue_list: VBoxContainer = $QueueHUD/VBox/QueueList

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


func _ensure_nodes() -> void:
	if building_panel == null and has_node("BuildingPanel"):
		resource_bar = $ResourceBar
		bottom_nav = $BottomNav
		building_panel = $BuildingPanel
		village_viewport = $VillageArea/BuildingsContainer
		queue_hud = $QueueHUD
		queue_title = $QueueHUD/VBox/TitleLabel
		queue_list = $QueueHUD/VBox/QueueList


func _ready() -> void:
	_ensure_nodes()
	_ensure_game_loop()
	_setup_village_nodes()

	building_panel.hide()
	if not building_panel.building_switched.is_connected(_on_building_selected):
		building_panel.building_switched.connect(_on_building_selected)

	var bus = Engine.get_main_loop().root.get_node_or_null("EventBus") if Engine.get_main_loop() is SceneTree else null
	if bus != null:
		if bus.has_signal("building_completed") and not bus.building_completed.is_connected(_on_building_completed):
			bus.building_completed.connect(_on_building_completed)
		if bus.has_signal("building_started") and not bus.building_started.is_connected(_on_building_started):
			bus.building_started.connect(_on_building_started)
		if bus.has_signal("resources_changed") and not bus.resources_changed.is_connected(_on_resources_changed):
			bus.resources_changed.connect(_on_resources_changed)
		if bus.has_signal("state_changed") and not bus.state_changed.is_connected(_on_state_changed):
			bus.state_changed.connect(_on_state_changed)

	refresh_all()
	_update_queue_ui()


func _process(_delta: float) -> void:
	_update_queue_ui()


func _ensure_game_loop() -> void:
	if GameLoopScript.instance == null:
		_game_loop = GameLoopScript.new()
		add_child(_game_loop)
	var clock = Engine.get_main_loop().root.get_node_or_null("GameClock") if Engine.get_main_loop() is SceneTree else null
	if clock != null and clock.has_method("start"):
		if not bool(clock.get("running")):
			clock.start()


func _on_resources_changed(_village_id: int) -> void:
	refresh_all()


func _on_state_changed() -> void:
	refresh_all()
	_update_queue_ui()


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
		icon_lbl.add_theme_font_size_override("font_size", 40)
		vbox.add_child(icon_lbl)

		var name_lbl := Label.new()
		name_lbl.text = b_name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 18)
		name_lbl.add_theme_color_override("font_color", Palette.c("murekkep"))
		vbox.add_child(name_lbl)

		var lvl_lbl := Label.new()
		lvl_lbl.text = "Sv. 0"
		lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lvl_lbl.add_theme_font_size_override("font_size", 16)
		lvl_lbl.add_theme_color_override("font_color", Palette.c("safir"))
		vbox.add_child(lvl_lbl)

		btn.add_child(vbox)
		btn.pressed.connect(func(): _on_building_selected(b_key))

		village_viewport.add_child(btn)
		_building_nodes[b_key] = {"btn": btn, "lvl": lvl_lbl, "name": name_lbl}


func _on_building_selected(key: String) -> void:
	_ensure_nodes()
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null or not gs.has_active_village():
		return
	var v: Dictionary = gs.get_active_village()
	building_panel.show_building(v, key)


func _on_building_completed(_village_id: int, _key: String, _level: int) -> void:
	refresh_all()
	_update_queue_ui()
	if building_panel.visible:
		building_panel.refresh()
	var sm = Engine.get_main_loop().root.get_node_or_null("SaveManager") if Engine.get_main_loop() is SceneTree else null
	if sm != null:
		sm.save_game()


func refresh_all() -> void:
	_ensure_nodes()
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


func _on_building_started(_village_id: int, _key: String, _level: int) -> void:
	refresh_all()
	_update_queue_ui()
	if building_panel.visible:
		building_panel.refresh()


func _current_now() -> int:
	if GameLoopScript.instance != null and GameLoopScript.instance.now_unix() > 0:
		return GameLoopScript.instance.now_unix()
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs != null:
		var w = gs.world
		if typeof(w) == TYPE_DICTIONARY and (w as Dictionary).has("sim_now_unix"):
			return int((w as Dictionary)["sim_now_unix"])
	return int(Time.get_unix_time_from_system())


func _update_queue_ui() -> void:
	_ensure_nodes()
	if queue_hud == null:
		return
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null or not gs.has_active_village():
		queue_hud.hide()
		return

	var vid: int = gs.active_village_id
	var q_items: Array = []
	for item in gs.queues:
		if typeof(item) == TYPE_DICTIONARY and int(item.get("village_id", -1)) == vid and str(item.get("type", "")) == "build":
			q_items.append(item)

	if q_items.is_empty():
		queue_hud.hide()
		return

	queue_hud.show()
	queue_title.text = "🔨 Devam Eden İnşaatlar (%d/3)" % q_items.size()

	var now := _current_now()

	while queue_list.get_child_count() > q_items.size():
		var last = queue_list.get_child(queue_list.get_child_count() - 1)
		queue_list.remove_child(last)
		last.queue_free()

	while queue_list.get_child_count() < q_items.size():
		var row := _create_queue_row()
		queue_list.add_child(row)

	for i in range(q_items.size()):
		var item: Dictionary = q_items[i]
		var row: HBoxContainer = queue_list.get_child(i)
		_bind_queue_row(row, item, now)


func _create_queue_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var icon_name_lbl := Label.new()
	icon_name_lbl.name = "IconNameLabel"
	icon_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_name_lbl.add_theme_font_size_override("font_size", 16)
	icon_name_lbl.add_theme_color_override("font_color", Palette.c("murekkep"))
	row.add_child(icon_name_lbl)

	var time_lbl := Label.new()
	time_lbl.name = "TimeLabel"
	time_lbl.custom_minimum_size = Vector2(80, 0)
	time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time_lbl.add_theme_font_size_override("font_size", 16)
	time_lbl.add_theme_color_override("font_color", Palette.c("safir"))
	row.add_child(time_lbl)

	var progress := ProgressBar.new()
	progress.name = "ProgressBar"
	progress.custom_minimum_size = Vector2(100, 20)
	progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progress.show_percentage = false
	row.add_child(progress)

	var cancel_btn := Button.new()
	cancel_btn.name = "CancelButton"
	cancel_btn.text = "✕ İptal"
	cancel_btn.custom_minimum_size = Vector2(80, 36)
	row.add_child(cancel_btn)

	return row


func _bind_queue_row(row: HBoxContainer, item: Dictionary, now: int) -> void:
	var key: String = str(item.get("key", ""))
	var tgt: int = int(item.get("target_level", 1))
	var item_id: int = int(item.get("id", -1))

	var b_data := RulesEngineScript.building_data(key)
	var b_name := str(b_data.get("name", key))
	var icon := _get_building_icon(key)

	var start := int(item.get("start_unix", now))
	var finish := int(item.get("finish_unix", now))
	var total_dur := maxi(1, finish - start)
	var rem := maxi(0, finish - now)

	var icon_name_lbl: Label = row.get_node("IconNameLabel")
	var time_lbl: Label = row.get_node("TimeLabel")
	var progress: ProgressBar = row.get_node("ProgressBar")
	var cancel_btn: Button = row.get_node("CancelButton")

	icon_name_lbl.text = "%s %s (Sv. %d)" % [icon, b_name, tgt]
	time_lbl.text = "%02d:%02d" % [rem / 60, rem % 60]

	var pct := float(total_dur - rem) / float(total_dur) * 100.0
	progress.value = clampf(pct, 0.0, 100.0)

	var old_id = cancel_btn.get_meta("item_id", -1)
	if old_id != item_id:
		cancel_btn.set_meta("item_id", item_id)
		for conn in cancel_btn.pressed.get_connections():
			cancel_btn.pressed.disconnect(conn["callable"])
		cancel_btn.pressed.connect(_on_cancel_button_clicked.bind(item_id))


func _on_cancel_button_clicked(item_id: int) -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null or not gs.has_active_village():
		return
	var v: Dictionary = gs.get_active_village()
	var state: Dictionary = gs.to_dict()
	var res := EconomyAPIScript.cancel_build(v, item_id, state)
	if bool(res.get("ok", false)):
		gs.from_dict(state)
		var sm = Engine.get_main_loop().root.get_node_or_null("SaveManager") if Engine.get_main_loop() is SceneTree else null
		if sm != null:
			sm.save_game()
		var bus = Engine.get_main_loop().root.get_node_or_null("EventBus") if Engine.get_main_loop() is SceneTree else null
		if bus != null:
			if bus.has_signal("resources_changed"):
				bus.resources_changed.emit(gs.active_village_id)
			if bus.has_signal("state_changed"):
				bus.state_changed.emit()
		refresh_all()
		_update_queue_ui()
		if building_panel.visible:
			building_panel.refresh()
