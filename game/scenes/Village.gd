extends Control
## Village — 2.5D Köy Ekranı (Taht ve Kılıç / A-ARAYUZ).

const GameLoopScript := preload("res://scripts/core/GameLoop.gd")
const RulesEngineScript := preload("res://scripts/rules/RulesEngine.gd")
const Palette := preload("res://themes/Palette.gd")
const BuildingViewScript := preload("res://scenes/village/BuildingView.gd")

const EconomyAPIScript := preload("res://scripts/sim/economy/EconomyAPI.gd")
const ArmyAPIScript := preload("res://scripts/sim/army/ArmyAPI.gd")
const MovementScript := preload("res://scripts/sim/actions/Movement.gd")
const GameDataScript := preload("res://autoload/GameData.gd")

@onready var resource_bar: PanelContainer = $ResourceBar
@onready var bottom_nav: PanelContainer = $BottomNav
@onready var building_panel: PanelContainer = $BuildingPanel
@onready var village_viewport: Control = $VillageArea/BuildingsContainer
@onready var queue_hud: PanelContainer = $QueueHUD
@onready var queue_title: Label = $QueueHUD/VBox/TitleLabel
@onready var queue_list: VBoxContainer = $QueueHUD/VBox/Scroll/QueueList if has_node("QueueHUD/VBox/Scroll/QueueList") else ($QueueHUD/VBox/QueueList if has_node("QueueHUD/VBox/QueueList") else null)
@onready var background: TextureRect = $VillageArea/Background
@onready var btn_alliance: Button = $BtnAlliance if has_node("BtnAlliance") else (find_child("BtnAlliance", true, false) as Button)


## 15 binanın köy peyzajındaki kesin piksel koordinatları (1080x1920)
const BUILDING_LAYOUT := {
	"main": Vector2(400, 26),        # Kale (Üst sarp kayalık şato)
	"snob": Vector2(384, 432),       # Köşk (Şato altındaki soylu konağı ve bahçesi)
	"farm": Vector2(62, 316),        # Değirmen (Sol üst buğday tarlası ve yel değirmeni)
	"wood": Vector2(60, 688),        # Oduncu Kampı (Sol orman kenarı kütük kulübesi)
	"stone": Vector2(692, 534),      # Taş Ocağı (Sağ kayalık vinçli taş ocağı)
	"iron": Vector2(922, 550),       # Maden Ocağı (Dağ tüneli girişi ve raylar)
	"storage": Vector2(300, 830),    # Depo (Meydan solundaki büyük ahşap ambar)
	"garage": Vector2(530, 716),     # Simyager / Atölye (Pazar arkasındaki taş ev)
	"market": Vector2(602, 784),     # Market / Pazar (Meydandaki tenteli pazar tezgahları)
	"smith": Vector2(798, 892),      # Kuyumcu / Demirci (Sağdaki bacalı taş demirci atölyesi)
	"statue": Vector2(528, 978),     # Anıt (Meydan ortasındaki taş çeşme heykeli)
	"barracks": Vector2(126, 1078),  # Kışla (Sol alttaki kuleli askeri talim kışlası)
	"stable": Vector2(662, 1134),    # Katır Çiftliği (Ahşap ahır ve çitli otlak alanı)
	"wall": Vector2(474, 1406),      # Sur ve Kapı (En alttaki taş savunma surları)
	"hide": Vector2(372, 1030),      # Gizli Depo (Depo yanındaki kiler/mahzen yapısı)
}

## 15 binanın etkileşim alanı boyutları, seviye plaketi ofsetleri ve çokgen (poligon) hitbox koordinatları
const BUILDING_CONFIG := {
	"main": {
		"size": Vector2(462, 388),
		"badge": Vector2(196, 25),
		"polygon": [Vector2(0, 2), Vector2(460, 0), Vector2(462, 386), Vector2(2, 388)]
	},
	"snob": {
		"size": Vector2(432, 276),
		"badge": Vector2(181, 15),
		"polygon": [Vector2(180, 0), Vector2(432, 76), Vector2(250, 276), Vector2(0, 158)]
	},
	"farm": {
		"size": Vector2(278, 302),
		"badge": Vector2(145, 20),
		"polygon": [Vector2(0, 0), Vector2(0, 302), Vector2(278, 302), Vector2(278, 0)]
	},
	"wood": {
		"size": Vector2(372, 316),
		"badge": Vector2(151, 15),
		"polygon": [Vector2(140, 0), Vector2(372, 120), Vector2(194, 316), Vector2(0, 202)]
	},
	"stone": {
		"size": Vector2(208, 232),
		"badge": Vector2(95, 15),
		"polygon": [Vector2(130, 0), Vector2(208, 48), Vector2(140, 232), Vector2(0, 154)]
	},
	"iron": {
		"size": Vector2(150, 306),
		"badge": Vector2(40, 20),
		"polygon": [Vector2(2, 0), Vector2(150, 2), Vector2(148, 306), Vector2(0, 304)]
	},
	"storage": {
		"size": Vector2(266, 192),
		"badge": Vector2(98, 15),
		"polygon": [Vector2(266, 90), Vector2(140, 192), Vector2(0, 152), Vector2(154, 0)]
	},
	"garage": {
		"size": Vector2(134, 182),
		"badge": Vector2(32, 15),
		"polygon": [Vector2(2, 0), Vector2(134, 2), Vector2(86, 182), Vector2(0, 162)]
	},
	"market": {
		"size": Vector2(252, 240),
		"badge": Vector2(91, 20),
		"polygon": [Vector2(96, 0), Vector2(252, 64), Vector2(134, 240), Vector2(0, 158)]
	},
	"smith": {
		"size": Vector2(240, 228),
		"badge": Vector2(85, 20),
		"polygon": [Vector2(40, 0), Vector2(240, 2), Vector2(238, 228), Vector2(0, 226)]
	},
	"statue": {
		"size": Vector2(138, 174),
		"badge": Vector2(34, 15),
		"polygon": [Vector2(2, 0), Vector2(138, 16), Vector2(122, 174), Vector2(0, 172)]
	},
	"barracks": {
		"size": Vector2(472, 348),
		"badge": Vector2(70, 62),
		"polygon": [Vector2(162, 0), Vector2(472, 174), Vector2(268, 348), Vector2(0, 176)]
	},
	"stable": {
		"size": Vector2(352, 270),
		"badge": Vector2(141, 15),
		"polygon": [Vector2(12, 2), Vector2(350, 0), Vector2(352, 268), Vector2(0, 270)]
	},
	"wall": {
		"size": Vector2(140, 126),
		"badge": Vector2(35, 15),
		"polygon": [Vector2(0, 2), Vector2(138, 0), Vector2(140, 126), Vector2(2, 126)]
	},
	"hide": {
		"size": Vector2(130, 116),
		"badge": Vector2(30, 15),
		"polygon": [Vector2(0, 20), Vector2(128, 0), Vector2(130, 116), Vector2(4, 86)]
	},
}

## Geriye dönük uyumluluk tablosu
const BUILDING_SPRITES := {}

const BASE_OFFSET_Y: float = 138.0

@onready var village_area: Control = $VillageArea

# Zoom & Pan Durum Değişkenleri
const MIN_ZOOM: float = 1.0
const MAX_ZOOM: float = 2.2
var _current_zoom: float = 1.0
var _is_panning: bool = false
var _pan_start_mouse: Vector2 = Vector2.ZERO
var _pan_start_pos: Vector2 = Vector2.ZERO
var _active_touches: Dictionary = {}
var _prev_touch_dist: float = 0.0
var _prev_pinch_mid: Vector2 = Vector2.ZERO
var _touch_start_pos: Vector2 = Vector2.ZERO
var _touch_drag_total: float = 0.0
var _was_gesture: bool = false
var _last_touch_ms: int = -10000
var _overscan_bg: ColorRect = null

var _game_loop: Node = null
var _building_nodes: Dictionary = {}


func _ensure_nodes() -> void:
	if btn_alliance == null:
		btn_alliance = get_node_or_null("BtnAlliance") if has_node("BtnAlliance") else (find_child("BtnAlliance", true, false) as Button)
	if building_panel == null and has_node("BuildingPanel"):
		resource_bar = $ResourceBar
		bottom_nav = $BottomNav
		building_panel = $BuildingPanel
		village_area = $VillageArea
		village_viewport = $VillageArea/BuildingsContainer
		queue_hud = find_child("QueueHUD", true, false) as PanelContainer
		queue_title = find_child("TitleLabel", true, false) as Label
		queue_list = find_child("QueueList", true, false) as VBoxContainer
		if has_node("Background"):
			background = $Background
		elif has_node("VillageArea/Background"):
			background = $VillageArea/Background


func _style_alliance_btn() -> void:
	if btn_alliance == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.18, 0.28, 0.95)
	sb.border_color = Color(0.45, 0.75, 1.0, 0.95)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 6
	btn_alliance.add_theme_stylebox_override("normal", sb)
	var h_sb = sb.duplicate() as StyleBoxFlat
	h_sb.bg_color = Color(0.18, 0.28, 0.44, 1.0)
	h_sb.border_color = Color(0.70, 0.90, 1.0, 1.0)
	btn_alliance.add_theme_stylebox_override("hover", h_sb)
	btn_alliance.add_theme_stylebox_override("pressed", h_sb)
	btn_alliance.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	btn_alliance.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	btn_alliance.add_theme_constant_override("shadow_offset_y", 2)


func _on_alliance_btn_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Alliance.tscn")


func _ready() -> void:
	_ensure_nodes()
	_ensure_game_loop()
	_setup_queue_hud_styling()
	_setup_village_nodes()

	if btn_alliance == null:
		btn_alliance = get_node_or_null("BtnAlliance") if has_node("BtnAlliance") else (find_child("BtnAlliance", true, false) as Button)

	if btn_alliance != null:
		btn_alliance.z_index = 100
		btn_alliance.z_as_relative = false
		btn_alliance.mouse_filter = Control.MOUSE_FILTER_STOP
		_style_alliance_btn()
		if not btn_alliance.pressed.is_connected(_on_alliance_btn_pressed):
			btn_alliance.pressed.connect(_on_alliance_btn_pressed)

	_setup_overscan_bg()

	# Arka plan ve binalar ResourceBar (138px) bitiminden başlar, kale tamamen görünür
	if village_area != null:
		village_area.position = Vector2(0.0, BASE_OFFSET_Y)
		_clamp_village_area()
		var vp := get_viewport()
		if vp != null and not vp.size_changed.is_connected(_clamp_village_area):
			vp.size_changed.connect(_clamp_village_area)

	building_panel.hide()
	if not building_panel.building_switched.is_connected(_on_building_selected):
		building_panel.building_switched.connect(_on_building_selected)
	if not building_panel.visibility_changed.is_connected(_on_building_panel_visibility_changed):
		building_panel.visibility_changed.connect(_on_building_panel_visibility_changed)

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
	_init_animated_background()


func _on_building_panel_visibility_changed() -> void:
	if building_panel != null and not building_panel.visible:
		_update_queue_ui()


var _progress_timer: float = 0.0
var _bg_frame_idx: int = 0
var _bg_frame_timer: float = 0.0
const BG_TOTAL_FRAMES: int = 192 # 192 kare, 24 FPS = kesintisiz 8.0 saniyelik orijinal akıcı döngü
const BG_FPS: float = 24.0
const BG_FRAME_TIME: float = 1.0 / BG_FPS
const BG_LOOP_DURATION: float = float(BG_TOTAL_FRAMES) / BG_FPS


func _init_animated_background() -> void:
	if background == null:
		return
	var cache = Engine.get_main_loop().root.get_node_or_null("VillageBackgroundCache") if Engine.get_main_loop() is SceneTree else null
	if cache != null:
		var tex = cache.get_frame(_bg_frame_idx)
		if tex != null:
			background.texture = tex
	elif ResourceLoader.exists("res://assets/sprites/village/animated_bg/f_000.webp"):
		background.texture = load("res://assets/sprites/village/animated_bg/f_000.webp")


func _process(delta: float) -> void:
	_update_queue_ui()
	_progress_timer += delta
	if _progress_timer >= 0.5:
		_progress_timer = 0.0
		_update_building_views_progress()

	# Arka plan animasyonu: İlk 8 saniye (192 kare, 24 FPS) döngüsü — son 2 saniye kırpılmış orijinal hız
	if background != null:
		_bg_frame_timer += delta
		if _bg_frame_timer >= BG_FRAME_TIME:
			var steps: int = int(_bg_frame_timer / BG_FRAME_TIME)
			_bg_frame_timer = fposmod(_bg_frame_timer, BG_FRAME_TIME)
			var cache = Engine.get_main_loop().root.get_node_or_null("VillageBackgroundCache") if Engine.get_main_loop() is SceneTree else null
			if cache != null:
				var total: int = mini(BG_TOTAL_FRAMES, cache.get_frame_count())
				if total > 0:
					_bg_frame_idx = (_bg_frame_idx + steps) % total
					var tex = cache.get_frame(_bg_frame_idx)
					if tex != null:
						background.texture = tex


func _update_building_views_progress() -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null or not gs.has_active_village():
		return
	var now := _current_now()
	for item in gs.queues:
		if typeof(item) == TYPE_DICTIONARY and int(item.get("village_id", -1)) == gs.active_village_id and str(item.get("type", "")) == "build":
			var b_k: String = str(item.get("key", ""))
			if _building_nodes.has(b_k):
				var b_view = _building_nodes[b_k].get("view")
				if b_view != null and b_view.has_method("set_state"):
					var s_u := int(item.get("start_unix", now))
					var f_u := int(item.get("finish_unix", now))
					var dur := maxi(1, f_u - s_u)
					var is_active := (now >= s_u)
					var rem := maxi(0, f_u - now) if is_active else dur
					var pct := clampf(float(dur - rem) / float(dur) * 100.0, 0.0, 100.0) if is_active else 0.0
					b_view.set_state(b_view.current_level, false, is_active, pct, rem)


func _ensure_game_loop() -> void:
	if GameLoopScript.instance == null:
		_game_loop = GameLoopScript.new()
		add_child(_game_loop)
	var clock = Engine.get_main_loop().root.get_node_or_null("GameClock") if Engine.get_main_loop() is SceneTree else null
	if clock != null and clock.has_method("start"):
		if not bool(clock.get("running")):
			clock.start()


func _on_resources_changed(village_id: int) -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null or not gs.has_active_village() or village_id != gs.active_village_id:
		return
	refresh_all()


func _on_state_changed() -> void:
	refresh_all()
	_update_queue_ui()


func _setup_village_nodes() -> void:
	if not _building_nodes.is_empty():
		return
	for b_key in BUILDING_LAYOUT.keys():
		var pos: Vector2 = BUILDING_LAYOUT[b_key]
		var b_data: Dictionary = RulesEngineScript.building_data(b_key)
		var b_name: String = str(b_data.get("name", b_key))
		var cfg: Dictionary = BUILDING_CONFIG.get(b_key, {})
		var b_size: Vector2 = cfg.get("size", Vector2(180, 150))
		var badge_offset: Vector2 = cfg.get("badge", Vector2(-1, -1))
		var poly: Array = cfg.get("polygon", [])
		var packed_poly := PackedVector2Array(poly)

		var b_view = BuildingViewScript.new()
		b_view.name = "BuildingView_" + b_key
		b_view.position = pos
		b_view.setup(b_key, b_name, "", b_size, badge_offset, packed_poly)
		b_view.clicked.connect(_on_building_selected.bind(b_key))
		b_view.dragged.connect(_on_building_dragged)

		village_viewport.add_child(b_view)

		_building_nodes[b_key] = {
			"view": b_view,
			"btn": b_view.get_button(),
			"lvl": b_view.get_level_label(),
			"name": b_view.get_name_label()
		}


func _get_game_state() -> Node:
	if get_parent() != null and get_parent().has_node("GameState"):
		return get_parent().get_node("GameState")
	if is_inside_tree():
		if has_node("/root/GameState"):
			return get_node("/root/GameState")
		var tree = get_tree()
		if tree != null and tree.root != null and tree.root.has_node("GameState"):
			return tree.root.get_node("GameState")
	var loop = Engine.get_main_loop()
	if loop is SceneTree and (loop as SceneTree).root != null and (loop as SceneTree).root.has_node("GameState"):
		return (loop as SceneTree).root.get_node("GameState")
	return null


func _on_building_selected(key: String) -> void:
	_ensure_nodes()
	var gs = _get_game_state()
	if gs == null or not gs.has_active_village():
		return
	var v: Dictionary = gs.get_active_village()
	building_panel.show_building(v, key)


func _on_building_completed(village_id: int, key: String, level: int) -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null or not gs.has_active_village():
		return
	# Sadece oyuncunun aktif köyü için seviye kutlaması ve yenileme yapılır
	if village_id != gs.active_village_id:
		return

	if _building_nodes.has(key):
		var b_view = _building_nodes[key].get("view")
		if b_view != null and b_view.has_method("trigger_level_up"):
			b_view.trigger_level_up(level)

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
	var now := _current_now()

	var upgrading_buildings: Dictionary = {}
	for item in gs.queues:
		if typeof(item) == TYPE_DICTIONARY and int(item.get("village_id", -1)) == gs.active_village_id and str(item.get("type", "")) == "build":
			var b_k: String = str(item.get("key", ""))
			var s_u := int(item.get("start_unix", now))
			var f_u := int(item.get("finish_unix", now))
			var dur := maxi(1, f_u - s_u)
			var is_active := (now >= s_u)
			var rem := maxi(0, f_u - now) if is_active else dur
			var pct := clampf(float(dur - rem) / float(dur) * 100.0, 0.0, 100.0) if is_active else 0.0
			upgrading_buildings[b_k] = {"active": is_active, "progress": pct, "rem": rem}

	for b_key in _building_nodes.keys():
		var lvl: int = int(buildings.get(b_key, 0))
		var node_dict: Dictionary = _building_nodes[b_key]
		var b_view = node_dict.get("view")

		var is_locked: bool = false
		if lvl == 0:
			var missing: Array = RulesEngineScript.missing_requirements(buildings, b_key, 1)
			if not missing.is_empty():
				is_locked = true

		var has_entry: bool = upgrading_buildings.has(b_key)
		var is_upg: bool = has_entry and bool(upgrading_buildings[b_key].get("active", false))
		var pct: float = 0.0
		var rem_s: int = 0
		if has_entry:
			pct = float(upgrading_buildings[b_key]["progress"])
			rem_s = int(upgrading_buildings[b_key]["rem"])

		if b_view != null and b_view.has_method("set_state"):
			b_view.set_state(lvl, is_locked, is_upg, pct, rem_s)
		else:
			var lvl_lbl: Label = node_dict.get("lvl")
			if lvl_lbl != null:
				lvl_lbl.text = "Sv. %d" % lvl

	if resource_bar != null:
		resource_bar.refresh()


func _get_building_icon(key: String) -> String:
	match key:
		"main": return ""
		"wood": return ""
		"stone": return ""
		"iron": return ""
		"storage": return ""
		"hide": return ""
		"farm": return ""
		"barracks": return ""
		"wall": return ""
		"market": return ""
		"stable": return ""
		"garage": return ""
		"snob": return ""
		"smith": return ""
		"statue": return ""
		_: return ""


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
	if building_panel != null and building_panel.visible:
		queue_hud.hide()
		return
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null or not gs.has_active_village():
		queue_hud.hide()
		return

	var vid: int = gs.active_village_id
	var activities: Array = []
	var now := _current_now()

	# 1) Gelen Saldırılar / Akınlar ( En yüksek öncelik)
	var incoming_count := 0
	for m in gs.movements:
		if typeof(m) == TYPE_DICTIONARY:
			var to_id = int((m as Dictionary).get("to_village_id", -1))
			var m_type = str((m as Dictionary).get("type", ""))
			var m_state = str((m as Dictionary).get("state", ""))
			if to_id == vid and m_state == "outgoing" and (m_type in ["attack", "raid", "spy"]):
				activities.append({
					"category": "incoming_attack",
					"type": m_type,
					"data": m
				})
				incoming_count += 1

	# 2) Çıkan Askeri Seferler
	for m in gs.movements:
		if typeof(m) == TYPE_DICTIONARY:
			var from_id = int((m as Dictionary).get("from_village_id", -1))
			var m_state = str((m as Dictionary).get("state", ""))
			if from_id == vid and (m_state == "outgoing" or m_state == "returning"):
				activities.append({
					"category": "outgoing_attack",
					"type": str((m as Dictionary).get("type", "attack")),
					"data": m
				})

	# 3) Devam eden İnşaatlar
	for item in gs.queues:
		if typeof(item) == TYPE_DICTIONARY and int((item as Dictionary).get("village_id", -1)) == vid:
			var q_type = str((item as Dictionary).get("type", ""))
			if q_type == "build":
				activities.append({
					"category": "build",
					"type": "build",
					"data": item
				})
			elif q_type == "research":
				activities.append({
					"category": "research",
					"type": "research",
					"data": item
				})
			elif q_type == "train":
				activities.append({
					"category": "train",
					"type": "train",
					"data": item
				})

	if activities.is_empty():
		queue_hud.hide()
		return

	queue_hud.show()
	if incoming_count > 0:
		queue_title.text = " ALARM: %d Düşman Saldırısı! | Aktiviteler (%d)" % [incoming_count, activities.size()]
		queue_title.add_theme_color_override("font_color", Color(1.0, 0.40, 0.40))
	else:
		queue_title.text = " Aktiviteler ve Askeri Durum (%d)" % activities.size()
		queue_title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))

	while queue_list.get_child_count() > activities.size():
		var last = queue_list.get_child(queue_list.get_child_count() - 1)
		queue_list.remove_child(last)
		last.queue_free()

	while queue_list.get_child_count() < activities.size():
		var row := _create_queue_row()
		queue_list.add_child(row)

	for i in range(activities.size()):
		var act: Dictionary = activities[i]
		var row: HBoxContainer = queue_list.get_child(i)
		_bind_queue_row(row, act, now)


func _setup_queue_hud_styling() -> void:
	if queue_hud != null:
		var q_sb := StyleBoxFlat.new()
		q_sb.bg_color = Color(0.12, 0.10, 0.14, 0.98)
		q_sb.border_color = Color(0.92, 0.76, 0.36, 1.0)
		q_sb.set_border_width_all(2)
		q_sb.set_corner_radius_all(16)
		q_sb.content_margin_left = 20
		q_sb.content_margin_top = 16
		q_sb.content_margin_right = 20
		q_sb.content_margin_bottom = 16
		q_sb.shadow_color = Color(0, 0, 0, 0.6)
		q_sb.shadow_size = 10
		queue_hud.add_theme_stylebox_override("panel", q_sb)
		if queue_title != null:
			queue_title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
			queue_title.add_theme_font_size_override("font_size", 24)
			queue_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.98))
			queue_title.add_theme_constant_override("shadow_offset_y", 2)


func _create_queue_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)

	var icon_name_lbl := Label.new()
	icon_name_lbl.name = "IconNameLabel"
	icon_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_name_lbl.add_theme_font_size_override("font_size", 24)
	icon_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.88))
	icon_name_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.98))
	icon_name_lbl.add_theme_constant_override("shadow_offset_y", 2)
	row.add_child(icon_name_lbl)

	var time_lbl := Label.new()
	time_lbl.name = "TimeLabel"
	time_lbl.custom_minimum_size = Vector2(90, 0)
	time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time_lbl.add_theme_font_size_override("font_size", 24)
	time_lbl.add_theme_color_override("font_color", Color(0.42, 0.90, 1.0))
	time_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.98))
	time_lbl.add_theme_constant_override("shadow_offset_y", 2)
	row.add_child(time_lbl)

	var progress := ProgressBar.new()
	progress.name = "ProgressBar"
	progress.custom_minimum_size = Vector2(130, 24)
	progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progress.show_percentage = false
	var p_bg := StyleBoxFlat.new()
	p_bg.bg_color = Color(0.08, 0.07, 0.10, 0.95)
	p_bg.border_color = Color(0.50, 0.42, 0.30, 0.8)
	p_bg.set_border_width_all(1)
	p_bg.set_corner_radius_all(8)
	var p_fg := StyleBoxFlat.new()
	p_fg.bg_color = Color(0.20, 0.80, 0.42, 1.0)
	p_fg.set_corner_radius_all(7)
	progress.add_theme_stylebox_override("background", p_bg)
	progress.add_theme_stylebox_override("fill", p_fg)
	row.add_child(progress)

	var cancel_btn := Button.new()
	cancel_btn.name = "CancelButton"
	cancel_btn.text = "X İptal"
	cancel_btn.custom_minimum_size = Vector2(110, 44)
	cancel_btn.add_theme_font_size_override("font_size", 20)
	var c_sb := StyleBoxFlat.new()
	c_sb.bg_color = Color(0.68, 0.18, 0.15, 0.95)
	c_sb.border_color = Color(0.98, 0.55, 0.45, 0.95)
	c_sb.set_border_width_all(2)
	c_sb.set_corner_radius_all(12)
	cancel_btn.add_theme_stylebox_override("normal", c_sb)
	cancel_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	cancel_btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	cancel_btn.add_theme_constant_override("shadow_offset_y", 2)
	row.add_child(cancel_btn)

	return row


func _bind_queue_row(row: HBoxContainer, activity: Dictionary, now: int) -> void:
	var category: String = str(activity.get("category", ""))
	var data: Dictionary = activity.get("data", {})
	var icon_name_lbl: Label = row.get_node("IconNameLabel")
	var time_lbl: Label = row.get_node("TimeLabel")
	var progress: ProgressBar = row.get_node("ProgressBar")
	var cancel_btn: Button = row.get_node("CancelButton")

	var item_id: int = int(data.get("id", -1))
	var meta_key := "%s_%d" % [category, item_id]

	match category:
		"incoming_attack":
			var from_id := int(data.get("from_village_id", 0))
			var arr_u := int(data.get("arrive_unix", now))
			var dep_u := int(data.get("depart_unix", now))
			var rem := maxi(0, arr_u - now)
			var total_dur := maxi(1, arr_u - dep_u)
			var pct := clampf(float(total_dur - rem) / float(total_dur) * 100.0, 0.0, 100.0)

			icon_name_lbl.text = " DÜŞMAN SALDIRISI! (#%d)" % from_id
			icon_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.40, 0.40))
			time_lbl.text = "%02d:%02d" % [rem / 60, rem % 60]
			time_lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
			progress.value = pct

			cancel_btn.text = " Alarm!"
			cancel_btn.disabled = true
			var dis_sb := StyleBoxFlat.new()
			dis_sb.bg_color = Color(0.40, 0.12, 0.12, 0.8)
			dis_sb.border_color = Color(0.80, 0.30, 0.30, 0.8)
			dis_sb.set_border_width_all(2)
			dis_sb.set_corner_radius_all(10)
			cancel_btn.add_theme_stylebox_override("disabled", dis_sb)

		"outgoing_attack":
			var to_id := int(data.get("to_village_id", 0))
			var m_state := str(data.get("state", "outgoing"))
			var target_u := int(data.get("arrive_unix", now)) if m_state == "outgoing" else int(data.get("return_unix", now))
			var dep_u := int(data.get("depart_unix", now))
			var rem := maxi(0, target_u - now)
			var total_dur := maxi(1, target_u - dep_u)
			var pct := clampf(float(total_dur - rem) / float(total_dur) * 100.0, 0.0, 100.0)

			if m_state == "returning":
				icon_name_lbl.text = "Ordu Dönüyor (#%d)" % to_id
				icon_name_lbl.add_theme_color_override("font_color", Color(0.80, 0.85, 0.95))
			else:
				icon_name_lbl.text = "Sefer: Hedef Köy #%d" % to_id
				icon_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.40))

			time_lbl.text = "%02d:%02d" % [rem / 60, rem % 60]
			time_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.40))
			progress.value = pct

			var can_cancel := (m_state == "outgoing" and (now - dep_u) <= 90)
			cancel_btn.text = "Çek" if can_cancel else "Seferde"
			cancel_btn.disabled = not can_cancel

			var old_meta = cancel_btn.get_meta("act_key", "")
			if old_meta != meta_key:
				cancel_btn.set_meta("act_key", meta_key)
				for conn in cancel_btn.pressed.get_connections():
					cancel_btn.pressed.disconnect(conn["callable"])
				if can_cancel:
					cancel_btn.pressed.connect(_on_cancel_activity_clicked.bind("outgoing_attack", item_id))

		"build":
			var key: String = str(data.get("key", ""))
			var tgt: int = int(data.get("target_level", 1))
			var b_data := RulesEngineScript.building_data(key)
			var b_name := str(b_data.get("name", key))

			var start := int(data.get("start_unix", now))
			var finish := int(data.get("finish_unix", now))
			var total_dur := maxi(1, finish - start)
			var is_active := (now >= start)
			var rem := maxi(0, finish - now) if is_active else total_dur
			var pct := clampf(float(total_dur - rem) / float(total_dur) * 100.0, 0.0, 100.0) if is_active else 0.0

			icon_name_lbl.text = "%s (Sv. %d)" % [b_name, tgt]
			icon_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.88))
			if is_active:
				time_lbl.text = "%02d:%02d" % [rem / 60, rem % 60]
				time_lbl.add_theme_color_override("font_color", Color(0.42, 0.90, 1.0))
			else:
				time_lbl.text = "Sırada (%02d:%02d)" % [rem / 60, rem % 60]
				time_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.40))

			progress.value = pct
			cancel_btn.text = "İptal"
			cancel_btn.disabled = false

			var old_meta = cancel_btn.get_meta("act_key", "")
			if old_meta != meta_key:
				cancel_btn.set_meta("act_key", meta_key)
				for conn in cancel_btn.pressed.get_connections():
					cancel_btn.pressed.disconnect(conn["callable"])
				cancel_btn.pressed.connect(_on_cancel_activity_clicked.bind("build", item_id))

		"research":
			var u_key: String = str(data.get("key", ""))
			var u_name: String = GameDataScript.get_singleton().get_unit_name(u_key)
			var start := int(data.get("start_unix", now))
			var finish := int(data.get("finish_unix", now))
			var total_dur := maxi(1, finish - start)
			var rem := maxi(0, finish - now)
			var pct := clampf(float(total_dur - rem) / float(total_dur) * 100.0, 0.0, 100.0)

			icon_name_lbl.text = "%s (Araştırma)" % u_name
			icon_name_lbl.add_theme_color_override("font_color", Color(0.55, 0.90, 1.0))
			time_lbl.text = "%02d:%02d" % [rem / 60, rem % 60]
			time_lbl.add_theme_color_override("font_color", Color(0.42, 0.90, 1.0))

			progress.value = pct
			cancel_btn.text = "İptal"
			cancel_btn.disabled = false

			var old_meta = cancel_btn.get_meta("act_key", "")
			if old_meta != meta_key:
				cancel_btn.set_meta("act_key", meta_key)
				for conn in cancel_btn.pressed.get_connections():
					cancel_btn.pressed.disconnect(conn["callable"])
				cancel_btn.pressed.connect(_on_cancel_activity_clicked.bind("research", item_id))

		"train":
			var u_key: String = str(data.get("key", ""))
			var u_name: String = GameDataScript.get_singleton().get_unit_name(u_key)
			var count: int = int(data.get("count", 0))
			var start := int(data.get("start_unix", now))
			var finish := int(data.get("finish_unix", now))
			var total_dur := maxi(1, finish - start)
			var rem := maxi(0, finish - now)
			var pct := clampf(float(total_dur - rem) / float(total_dur) * 100.0, 0.0, 100.0)

			icon_name_lbl.text = "%d %s (Eğitim)" % [count, u_name]
			icon_name_lbl.add_theme_color_override("font_color", Color(0.60, 1.0, 0.65))
			time_lbl.text = "%02d:%02d" % [rem / 60, rem % 60]
			time_lbl.add_theme_color_override("font_color", Color(0.50, 0.95, 0.60))

			progress.value = pct
			cancel_btn.text = "İptal"
			cancel_btn.disabled = false

			var old_meta = cancel_btn.get_meta("act_key", "")
			if old_meta != meta_key:
				cancel_btn.set_meta("act_key", meta_key)
				for conn in cancel_btn.pressed.get_connections():
					cancel_btn.pressed.disconnect(conn["callable"])
				cancel_btn.pressed.connect(_on_cancel_activity_clicked.bind("train", item_id))


func _on_cancel_activity_clicked(category: String, item_id: int) -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null or not gs.has_active_village():
		return
	var v: Dictionary = gs.get_active_village()
	var state: Dictionary = gs.to_dict()
	var ok := false

	match category:
		"build":
			var res := EconomyAPIScript.cancel_build(v, item_id, state)
			ok = bool(res.get("ok", false))
		"research":
			var st_v: Dictionary = {}
			for sv in state.get("villages", []):
				if int((sv as Dictionary).get("id", -1)) == gs.active_village_id:
					st_v = sv
					break
			if st_v.is_empty():
				st_v = v
			ok = ArmyAPIScript.cancel_research(st_v, item_id, state)
		"train":
			var st_v: Dictionary = {}
			for sv in state.get("villages", []):
				if int((sv as Dictionary).get("id", -1)) == gs.active_village_id:
					st_v = sv
					break
			if st_v.is_empty():
				st_v = v
			ok = ArmyAPIScript.cancel_training(st_v, item_id, state)
		"outgoing_attack":
			var now := _current_now()
			var res := MovementScript.cancel(state, item_id, now)
			ok = bool(res.get("ok", false))

	if ok:
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
		if building_panel != null and building_panel.visible:
			building_panel.refresh()



func _setup_overscan_bg() -> void:
	if _overscan_bg != null and is_instance_valid(_overscan_bg):
		return
	var bg_fill := ColorRect.new()
	bg_fill.name = "OverscanBg"
	bg_fill.color = Color(0.055, 0.075, 0.055, 1.0)
	bg_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_fill)
	move_child(bg_fill, 0)
	_overscan_bg = bg_fill


func _on_building_dragged(rel: Vector2) -> void:
	if _is_recent_touch():
		return
	_pan_by(rel)


func _is_recent_touch() -> bool:
	if not _active_touches.is_empty():
		return true
	return (Time.get_ticks_msec() - _last_touch_ms) < 250


func _cancel_all_building_presses() -> void:
	for k in _building_nodes:
		var v = _building_nodes[k].get("view")
		if v != null and v.has_method("cancel_press"):
			v.cancel_press()


func _is_point_over_hud(pos: Vector2) -> bool:
	var hud_nodes: Array = [resource_bar, bottom_nav, btn_alliance]
	if building_panel != null and building_panel.visible:
		hud_nodes.append(building_panel)
	if queue_hud != null and queue_hud.visible:
		hud_nodes.append(queue_hud)
	for n in hud_nodes:
		if n is Control and (n as Control).visible:
			if (n as Control).get_global_rect().has_point(pos):
				return true
	var qm = Engine.get_main_loop().root.get_node_or_null("QuestManager") if Engine.get_main_loop() is SceneTree else null
	if qm != null and qm.has_method("is_point_over_ui") and qm.is_point_over_ui(pos):
		return true
	return false


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		_last_touch_ms = Time.get_ticks_msec()
		if st.pressed:
			if _active_touches.is_empty() and _is_point_over_hud(st.position):
				return
			_active_touches[st.index] = st.position
			if _active_touches.size() == 1:
				_is_panning = false
				_was_gesture = false
				_touch_start_pos = st.position
				_touch_drag_total = 0.0
			elif _active_touches.size() >= 2:
				_is_panning = false
				_was_gesture = true
				_cancel_all_building_presses()
				var vals = _active_touches.values()
				var p0: Vector2 = vals[0]
				var p1: Vector2 = vals[1]
				_prev_touch_dist = p0.distance_to(p1)
				_prev_pinch_mid = (p0 + p1) * 0.5
				get_viewport().set_input_as_handled()
		else:
			var had_touch := _active_touches.has(st.index)
			_active_touches.erase(st.index)
			if _active_touches.size() < 2:
				_prev_touch_dist = 0.0
			if _active_touches.is_empty():
				var handled := _was_gesture
				_is_panning = false
				_was_gesture = false
				if handled and had_touch:
					get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_last_touch_ms = Time.get_ticks_msec()
		if not _active_touches.has(sd.index):
			return
		_active_touches[sd.index] = sd.position
		if _active_touches.size() >= 2:
			_cancel_all_building_presses()
			var vals = _active_touches.values()
			var p0: Vector2 = vals[0]
			var p1: Vector2 = vals[1]
			var cur_dist: float = p0.distance_to(p1)
			var cur_mid: Vector2 = (p0 + p1) * 0.5
			if _prev_touch_dist > 1.0:
				var pan_delta := cur_mid - _prev_pinch_mid
				if pan_delta.length_squared() > 0.0:
					_pan_by(pan_delta)
				var scale_ratio := cur_dist / _prev_touch_dist
				var target := clampf(_current_zoom * scale_ratio, MIN_ZOOM, MAX_ZOOM)
				_apply_zoom(target - _current_zoom, cur_mid)
			_prev_touch_dist = cur_dist
			_prev_pinch_mid = cur_mid
			_was_gesture = true
			get_viewport().set_input_as_handled()
		elif _active_touches.size() == 1:
			_touch_drag_total += sd.relative.length()
			if _is_panning or _touch_drag_total > 14.0 or _touch_start_pos.distance_to(sd.position) > 14.0:
				if not _is_panning:
					_is_panning = true
					_was_gesture = true
					_cancel_all_building_presses()
				_pan_by(sd.relative)
				get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _is_recent_touch():
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_apply_zoom(0.12, mb.position)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_apply_zoom(-0.12, mb.position)
		elif mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_is_panning = true
				_pan_start_mouse = mb.position
				_pan_start_pos = village_area.position if village_area != null else Vector2(0.0, BASE_OFFSET_Y)
			else:
				_is_panning = false
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _is_panning:
			_pan_by(mm.relative)


func _get_base_scale(vp_size: Vector2) -> float:
	var nav_h := bottom_nav.size.y if (bottom_nav != null and bottom_nav.size.y > 0.0) else 256.0
	var v_cover := (vp_size.y - nav_h - BASE_OFFSET_Y) / 1920.0
	var h_cover := (vp_size.x / 1080.0) if vp_size.x <= vp_size.y * 0.85 else 1.0
	return maxf(1.0, maxf(h_cover, v_cover))


func _effective_zoom() -> float:
	var vp_size := get_viewport_rect().size if is_inside_tree() else Vector2(1080.0, 1920.0)
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		vp_size = Vector2(1080.0, 1920.0)
	return _get_base_scale(vp_size) * _current_zoom


func _pan_by(rel: Vector2) -> void:
	if village_area == null:
		return
	village_area.position += rel
	_clamp_village_area()


func _apply_zoom(delta_zoom: float, focal: Vector2) -> void:
	if village_area == null:
		return
	var old_eff := _effective_zoom()
	var target_zoom := clampf(_current_zoom + delta_zoom, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(target_zoom, _current_zoom):
		return
	_current_zoom = target_zoom
	var new_eff := _effective_zoom()
	var ratio := new_eff / maxf(0.001, old_eff)
	var new_pos := focal - (focal - village_area.position) * ratio
	village_area.scale = Vector2(new_eff, new_eff)
	village_area.position = new_pos
	_clamp_village_area()


func _clamp_village_area() -> void:
	if village_area == null:
		return
	var vp_size := get_viewport_rect().size if is_inside_tree() else Vector2(1080.0, 1920.0)
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		vp_size = Vector2(1080.0, 1920.0)
	var eff := _effective_zoom()
	var scaled_size := Vector2(1080.0, 1920.0) * eff
	village_area.scale = Vector2(eff, eff)

	var min_x: float
	var max_x: float
	if scaled_size.x <= vp_size.x:
		var center_x := (vp_size.x - scaled_size.x) * 0.5
		min_x = center_x
		max_x = center_x
	else:
		min_x = vp_size.x - scaled_size.x
		max_x = 0.0

	var nav_h := bottom_nav.size.y if (bottom_nav != null and bottom_nav.size.y > 0.0) else 256.0
	var min_y := minf(BASE_OFFSET_Y, (vp_size.y - nav_h) - scaled_size.y)
	var max_y := BASE_OFFSET_Y

	village_area.position.x = clampf(village_area.position.x, min_x, max_x)
	village_area.position.y = clampf(village_area.position.y, min_y, max_y)


func _reset_view() -> void:
	_current_zoom = 1.0
	if village_area != null:
		var vp_size := get_viewport_rect().size if is_inside_tree() else Vector2(1080.0, 1920.0)
		var eff := _effective_zoom()
		var center_x := (vp_size.x - 1080.0 * eff) * 0.5
		village_area.scale = Vector2(eff, eff)
		village_area.position = Vector2(center_x, BASE_OFFSET_Y)
		_clamp_village_area()


## Tutorial ve yardımcı erişim: bina anahtarına göre BuildingView Control düğümünü döndürür.
func get_building_view(b_key: String) -> Control:
	if _building_nodes.has(b_key):
		return _building_nodes[b_key].get("view", null) as Control
	return null


## Tutorial hedef binayı güvenli yakınlaştırma (1.0×) ve görünür alan içinde konumlandırır.
func focus_building_for_tutorial(b_key: String) -> void:
	_ensure_nodes()
	if village_area == null:
		return
	_current_zoom = 1.0
	var vp_size := get_viewport_rect().size if is_inside_tree() else Vector2(1080.0, 1920.0)
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		vp_size = Vector2(1080.0, 1920.0)
	var eff := _effective_zoom()
	var center_x := (vp_size.x - 1080.0 * eff) * 0.5
	village_area.scale = Vector2(eff, eff)
	village_area.position = Vector2(center_x, BASE_OFFSET_Y)
	_clamp_village_area()

	var b_view := get_building_view(b_key)
	if b_view != null:
		var grect := b_view.get_global_rect()
		var safe_top := BASE_OFFSET_Y + 12.0
		var safe_bot := vp_size.y - 260.0
		if grect.end.y > safe_bot:
			village_area.position.y -= (grect.end.y - safe_bot + 24.0)
		elif grect.position.y < safe_top:
			village_area.position.y += (safe_top - grect.position.y + 12.0)
		_clamp_village_area()
