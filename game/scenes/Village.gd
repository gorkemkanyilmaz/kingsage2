extends Control
## Village — 2.5D Köy Ekranı (Taht ve Kılıç / A-ARAYUZ).

const GameLoopScript := preload("res://scripts/core/GameLoop.gd")
const RulesEngineScript := preload("res://scripts/rules/RulesEngine.gd")
const Palette := preload("res://themes/Palette.gd")
const BuildingViewScript := preload("res://scenes/village/BuildingView.gd")

const EconomyAPIScript := preload("res://scripts/sim/economy/EconomyAPI.gd")

@onready var resource_bar: PanelContainer = $ResourceBar
@onready var bottom_nav: PanelContainer = $BottomNav
@onready var building_panel: PanelContainer = $BuildingPanel
@onready var village_viewport: Control = $VillageArea/BuildingsContainer
@onready var queue_hud: PanelContainer = $QueueHUD
@onready var queue_title: Label = $QueueHUD/VBox/TitleLabel
@onready var queue_list: VBoxContainer = $QueueHUD/VBox/QueueList

## 15 binanın köy peyzajındaki kesin piksel koordinatları (1080x1920)
const BUILDING_LAYOUT := {
	"main": Vector2(500, 100),       # Kale (Üst sarp kayalık şato)
	"snob": Vector2(480, 470),       # Köşk (Şato altındaki mavi çatılı soylu konağı)
	"farm": Vector2(100, 360),       # Değirmen (Sol üst buğday tarlasındaki yel değirmeni)
	"wood": Vector2(140, 750),       # Oduncu Kampı (Sol orman kenarı kütük kulübesi)
	"stone": Vector2(680, 600),      # Taş Ocağı (Sağ kayalık vinçli taş ocağı)
	"iron": Vector2(850, 640),       # Maden Ocağı (Dağ tüneli girişi ve raylar)
	"storage": Vector2(300, 890),    # Depo (Meydan solundaki büyük ahşap ambar)
	"garage": Vector2(480, 760),     # Simyager / Atölye (Pazarın arkasındaki taş ev)
	"market": Vector2(600, 840),     # Market / Pazar (Meydandaki tenteli pazar tezgahları)
	"smith": Vector2(760, 930),      # Kuyumcu / Demirci (Sağdaki bacalı taş demirci atölyesi)
	"statue": Vector2(490, 1010),    # Anıt (Meydan ortasındaki taş çeşme heykeli)
	"barracks": Vector2(180, 1160),  # Kışla (Sol alttaki kuleli askeri talim kışlası)
	"stable": Vector2(680, 1200),    # Katır Çiftliği (Sağ alttaki ahşap ahır ve at otlağı)
	"wall": Vector2(360, 1430),      # Sur ve Kapı (En alttaki taş köprü başı savunma surları)
	"hide": Vector2(320, 1060),      # Gizli Depo (Depo altındaki kiler/mahzen yapısı)
}

## 15 binanın etkileşim alanı boyutları ve seviye plaketi ofsetleri
const BUILDING_CONFIG := {
	"main": {"size": Vector2(260, 220), "badge": Vector2(140, 25)},
	"snob": {"size": Vector2(200, 170), "badge": Vector2(120, 20)},
	"farm": {"size": Vector2(200, 190), "badge": Vector2(120, 30)},
	"wood": {"size": Vector2(200, 170), "badge": Vector2(120, 20)},
	"stone": {"size": Vector2(200, 170), "badge": Vector2(120, 20)},
	"iron": {"size": Vector2(200, 180), "badge": Vector2(115, 20)},
	"storage": {"size": Vector2(220, 180), "badge": Vector2(130, 20)},
	"garage": {"size": Vector2(180, 160), "badge": Vector2(100, 20)},
	"market": {"size": Vector2(200, 170), "badge": Vector2(110, 20)},
	"smith": {"size": Vector2(200, 180), "badge": Vector2(110, 20)},
	"statue": {"size": Vector2(180, 160), "badge": Vector2(100, 20)},
	"barracks": {"size": Vector2(240, 190), "badge": Vector2(140, 25)},
	"stable": {"size": Vector2(220, 180), "badge": Vector2(130, 25)},
	"wall": {"size": Vector2(260, 200), "badge": Vector2(140, 30)},
	"hide": {"size": Vector2(170, 140), "badge": Vector2(95, 15)},
}

## Geriye dönük uyumluluk tablosu
const BUILDING_SPRITES := {}

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
var _zoom_hud: PanelContainer = null

var _game_loop: Node = null
var _building_nodes: Dictionary = {}


func _ensure_nodes() -> void:
	if building_panel == null and has_node("BuildingPanel"):
		resource_bar = $ResourceBar
		bottom_nav = $BottomNav
		building_panel = $BuildingPanel
		village_area = $VillageArea
		village_viewport = $VillageArea/BuildingsContainer
		queue_hud = $QueueHUD
		queue_title = $QueueHUD/VBox/TitleLabel
		queue_list = $QueueHUD/VBox/QueueList


func _ready() -> void:
	_ensure_nodes()
	_ensure_game_loop()
	_setup_queue_hud_styling()
	_setup_zoom_hud()
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


var _progress_timer: float = 0.0

func _process(delta: float) -> void:
	_update_queue_ui()
	_progress_timer += delta
	if _progress_timer >= 0.5:
		_progress_timer = 0.0
		_update_building_views_progress()


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
					var rem := maxi(0, f_u - now)
					var pct := clampf(float(dur - rem) / float(dur) * 100.0, 0.0, 100.0)
					b_view.set_state(b_view.current_level, false, true, pct, rem)


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
		var b_data: Dictionary = RulesEngineScript.building_data(b_key)
		var b_name: String = str(b_data.get("name", b_key))
		var cfg: Dictionary = BUILDING_CONFIG.get(b_key, {})
		var b_size: Vector2 = cfg.get("size", Vector2(180, 150))
		var badge_offset: Vector2 = cfg.get("badge", Vector2(-1, -1))

		var b_view = BuildingViewScript.new()
		b_view.name = "BuildingView_" + b_key
		b_view.position = pos
		b_view.setup(b_key, b_name, "", b_size, badge_offset)
		b_view.clicked.connect(func(): _on_building_selected(b_key))
		b_view.dragged.connect(_on_building_dragged)

		village_viewport.add_child(b_view)

		_building_nodes[b_key] = {
			"view": b_view,
			"btn": b_view.get_button(),
			"lvl": b_view.get_level_label(),
			"name": b_view.get_name_label()
		}


func _on_building_selected(key: String) -> void:
	_ensure_nodes()
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null or not gs.has_active_village():
		return
	var v: Dictionary = gs.get_active_village()
	building_panel.show_building(v, key)


func _on_building_completed(_village_id: int, key: String, level: int) -> void:
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
			var rem := maxi(0, f_u - now)
			var pct := clampf(float(dur - rem) / float(dur) * 100.0, 0.0, 100.0)
			upgrading_buildings[b_k] = {"progress": pct, "rem": rem}

	for b_key in _building_nodes.keys():
		var lvl: int = int(buildings.get(b_key, 0))
		var node_dict: Dictionary = _building_nodes[b_key]
		var b_view = node_dict.get("view")

		var is_locked: bool = false
		if lvl == 0:
			var missing: Array = RulesEngineScript.missing_requirements(buildings, b_key, 1)
			if not missing.is_empty():
				is_locked = true

		var is_upg: bool = upgrading_buildings.has(b_key)
		var pct: float = 0.0
		var rem_s: int = 0
		if is_upg:
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


func _setup_queue_hud_styling() -> void:
	if queue_hud != null:
		var q_sb := StyleBoxFlat.new()
		q_sb.bg_color = Color(0.14, 0.11, 0.08, 0.95)
		q_sb.border_color = Color(0.75, 0.60, 0.32, 1.0)
		q_sb.set_border_width_all(2)
		q_sb.set_corner_radius_all(14)
		q_sb.content_margin_left = 16
		q_sb.content_margin_top = 12
		q_sb.content_margin_right = 16
		q_sb.content_margin_bottom = 12
		q_sb.shadow_color = Color(0.04, 0.03, 0.02, 0.5)
		q_sb.shadow_size = 8
		queue_hud.add_theme_stylebox_override("panel", q_sb)
		if queue_title != null:
			queue_title.add_theme_color_override("font_color", Color(0.98, 0.92, 0.70))


func _create_queue_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var icon_name_lbl := Label.new()
	icon_name_lbl.name = "IconNameLabel"
	icon_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_name_lbl.add_theme_font_size_override("font_size", 16)
	icon_name_lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	row.add_child(icon_name_lbl)

	var time_lbl := Label.new()
	time_lbl.name = "TimeLabel"
	time_lbl.custom_minimum_size = Vector2(80, 0)
	time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time_lbl.add_theme_font_size_override("font_size", 16)
	time_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
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
	var c_sb := StyleBoxFlat.new()
	c_sb.bg_color = Color(0.4, 0.15, 0.15, 0.85)
	c_sb.border_color = Color(0.7, 0.25, 0.25, 0.8)
	c_sb.set_border_width_all(1)
	c_sb.set_corner_radius_all(8)
	cancel_btn.add_theme_stylebox_override("normal", c_sb)
	cancel_btn.add_theme_color_override("font_color", Color(1, 0.9, 0.9))
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


func _on_building_dragged(rel: Vector2) -> void:
	_pan_by(rel)


func _unhandled_input(event: InputEvent) -> void:
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
				_pan_start_pos = village_area.position if village_area != null else Vector2.ZERO
			else:
				_is_panning = false
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _is_panning:
			_pan_by(mm.relative)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_active_touches[st.index] = st.position
			if _active_touches.size() == 1:
				_is_panning = true
				_pan_start_mouse = st.position
				_pan_start_pos = village_area.position if village_area != null else Vector2.ZERO
			elif _active_touches.size() == 2:
				_is_panning = false
				var vals = _active_touches.values()
				_prev_touch_dist = (vals[0] as Vector2).distance_to(vals[1] as Vector2)
		else:
			_active_touches.erase(st.index)
			if _active_touches.size() < 2:
				_prev_touch_dist = 0.0
			if _active_touches.size() == 0:
				_is_panning = false
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if _active_touches.has(sd.index):
			_active_touches[sd.index] = sd.position
		if _active_touches.size() >= 2:
			var vals = _active_touches.values()
			var p0: Vector2 = vals[0]
			var p1: Vector2 = vals[1]
			var cur_dist: float = p0.distance_to(p1)
			if _prev_touch_dist > 0.0:
				var diff: float = cur_dist - _prev_touch_dist
				var focal: Vector2 = (p0 + p1) * 0.5
				_apply_zoom(diff * 0.003, focal)
			_prev_touch_dist = cur_dist
		elif _is_panning and _active_touches.size() == 1:
			_pan_by(sd.relative)


func _pan_by(rel: Vector2) -> void:
	if village_area == null:
		return
	village_area.position += rel
	_clamp_village_area()


func _apply_zoom(delta_zoom: float, focal: Vector2) -> void:
	if village_area == null:
		return
	var target_zoom := clampf(_current_zoom + delta_zoom, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(target_zoom, _current_zoom):
		return
	var ratio := target_zoom / _current_zoom
	var new_pos := focal - (focal - village_area.position) * ratio
	_current_zoom = target_zoom
	village_area.scale = Vector2(_current_zoom, _current_zoom)
	village_area.position = new_pos
	_clamp_village_area()


func _clamp_village_area() -> void:
	if village_area == null:
		return
	var vp_size := get_viewport_rect().size if is_inside_tree() else Vector2(1080, 1920)
	if vp_size.x <= 0 or vp_size.y <= 0:
		vp_size = Vector2(1080, 1920)
	var scaled_size := Vector2(1080, 1920) * _current_zoom

	var min_x := minf(0.0, vp_size.x - scaled_size.x)
	var max_x := maxf(0.0, (vp_size.x - scaled_size.x) * 0.5) if scaled_size.x <= vp_size.x else 0.0

	var min_y := minf(0.0, vp_size.y - scaled_size.y)
	var max_y := maxf(0.0, (vp_size.y - scaled_size.y) * 0.5) if scaled_size.y <= vp_size.y else 0.0

	village_area.position.x = clampf(village_area.position.x, min_x, max_x)
	village_area.position.y = clampf(village_area.position.y, min_y, max_y)


func _reset_view() -> void:
	if village_area == null:
		return
	var t := create_tween().set_parallel(true)
	t.tween_property(village_area, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(village_area, "position", Vector2.ZERO, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_current_zoom = 1.0


func _setup_zoom_hud() -> void:
	if _zoom_hud != null or has_node("ZoomHUD"):
		return
	_zoom_hud = PanelContainer.new()
	_zoom_hud.name = "ZoomHUD"
	_zoom_hud.position = Vector2(1080 - 78, 136)
	_zoom_hud.custom_minimum_size = Vector2(62, 170)
	_zoom_hud.size = Vector2(62, 170)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.11, 0.14, 0.88)
	sb.border_color = Color(0.85, 0.72, 0.42, 0.85)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.shadow_size = 10
	sb.shadow_color = Color(0, 0, 0, 0.4)
	_zoom_hud.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)

	var btn_in := Button.new()
	btn_in.text = "+"
	btn_in.custom_minimum_size = Vector2(46, 46)
	btn_in.add_theme_font_size_override("font_size", 24)
	btn_in.pressed.connect(func(): _apply_zoom(0.25, Vector2(540, 960)))
	vbox.add_child(btn_in)

	var btn_out := Button.new()
	btn_out.text = "−"
	btn_out.custom_minimum_size = Vector2(46, 46)
	btn_out.add_theme_font_size_override("font_size", 24)
	btn_out.pressed.connect(func(): _apply_zoom(-0.25, Vector2(540, 960)))
	vbox.add_child(btn_out)

	var btn_reset := Button.new()
	btn_reset.text = "⛶"
	btn_reset.custom_minimum_size = Vector2(46, 46)
	btn_reset.add_theme_font_size_override("font_size", 20)
	btn_reset.pressed.connect(_reset_view)
	vbox.add_child(btn_reset)

	_zoom_hud.add_child(vbox)
	add_child(_zoom_hud)
