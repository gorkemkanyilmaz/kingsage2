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
const FontCinzelBold := preload("res://assets/fonts/Cinzel-Bold.ttf")
const FontNunitoBold := preload("res://assets/fonts/Nunito-Bold.ttf")
const AllianceModelScript := preload("res://scripts/model/AllianceModel.gd")
const IconAllianceShield := preload("res://assets/sprites/ui/nano_banana/sharp_icon_alliance_shield.png")
const TexRoyalBtnBg := preload("res://assets/sprites/ui/nano_banana/sharp_ui_royal_btn_bg.png")
const IconScrollBuild := preload("res://assets/sprites/ui/nano_banana/sharp_scroll_build.png")
const IconScrollTrain := preload("res://assets/sprites/ui/nano_banana/sharp_scroll_train.png")
const IconScrollResearch := preload("res://assets/sprites/ui/nano_banana/sharp_scroll_research.png")
const IconScrollMarch := preload("res://assets/sprites/ui/nano_banana/sharp_scroll_march.png")
const IconReportSeal := preload("res://assets/sprites/ui/nano_banana/sharp_icon_report_seal.png")
const TexLordPortraitBtn := preload("res://assets/sprites/lord/lord_portrait_btn.png")
const LordModalScript := preload("res://ui/LordModal.gd")
const MarketModalScript := preload("res://ui/MarketModal.gd")

@onready var resource_bar: PanelContainer = $ResourceBar
@onready var bottom_nav: PanelContainer = $BottomNav
@onready var building_panel: PanelContainer = $BuildingPanel
@onready var village_viewport: Control = $VillageArea/BuildingsContainer
@onready var queue_hud: PanelContainer = $QueueHUD
@onready var queue_title: Label = $QueueHUD/VBox/TitleLabel
@onready var queue_list: VBoxContainer = $QueueHUD/VBox/Scroll/QueueList if has_node("QueueHUD/VBox/Scroll/QueueList") else ($QueueHUD/VBox/QueueList if has_node("QueueHUD/VBox/QueueList") else null)
@onready var background: TextureRect = $VillageArea/Background
@onready var btn_alliance: Button = $BtnAlliance if has_node("BtnAlliance") else (find_child("BtnAlliance", true, false) as Button)
@onready var btn_lord: Button = $BtnLord if has_node("BtnLord") else (find_child("BtnLord", true, false) as Button)


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
		"badge": Vector2(26, 20),
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

const BASE_OFFSET_Y: float = 116.0

const IncomingAttackAlert := preload("res://ui/IncomingAttackAlert.gd")

@onready var village_area: Control = $VillageArea

# Zoom & Pan Durum Değişkenleri
const MIN_ZOOM: float = 1.0
const MAX_ZOOM: float = 2.2
const TOUCH_PAN_DEADZONE: float = 10.0
var _current_zoom: float = 1.0
var _is_panning: bool = false
var _pan_start_mouse: Vector2 = Vector2.ZERO
var _pan_start_pos: Vector2 = Vector2.ZERO
var _active_touches: Dictionary = {}
var _prev_touch_dist: float = 0.0
var _prev_pinch_mid: Vector2 = Vector2.ZERO
var _touch_start_pos: Vector2 = Vector2.ZERO
var _touch_start_area_pos: Vector2 = Vector2.ZERO
var _touch_drag_total: float = 0.0
var _mouse_drag_total: float = 0.0
var _was_gesture: bool = false
var _last_touch_ms: int = -10000
var _last_gesture_end_ms: int = -10000
var _overscan_bg: ColorRect = null

# Gelen Saldırı Kırmızı Yanıp Sönme & Alarm Arayüzü
var _attack_alarm_overlay: Control = null
var _attack_red_tint: ColorRect = null
var _attack_red_frame: Panel = null
var _attack_alarm_banner: Button = null
var _attack_banner_sb: StyleBoxFlat = null
var _attack_flash_time: float = 0.0
var _alarm_visual_accum: float = 0.0
var _last_alarm_banner_text: String = ""

var _game_loop: Node = null
var _building_nodes: Dictionary = {}

var _q_pb_bg: StyleBoxFlat = null
var _q_pb_fg: StyleBoxFlat = null
var _q_cancel_norm: StyleBoxFlat = null
var _q_cancel_hover: StyleBoxFlat = null
var _q_cancel_pressed: StyleBoxFlat = null
var _q_cancel_dis: StyleBoxFlat = null
var _q_speedup_have_sb: StyleBoxFlat = null
var _q_speedup_have_hover: StyleBoxFlat = null
var _q_speedup_buy_sb: StyleBoxFlat = null
var _q_speedup_buy_hover: StyleBoxFlat = null
var _q_row_card_sbs: Dictionary = {}
var _cached_gs: Node = null
var _cached_bg_cache: Node = null
var _queue_ui_accum: float = 0.0
var _alarm_scan_accum: float = 0.0
var _cached_incoming_attacks: Array[Dictionary] = []
var _alarm_visual_active: bool = false
var _lord_name_lbl: Label = null
var _lord_status_badge: PanelContainer = null
var _lord_status_lbl: Label = null
var _lord_notif_dot: Panel = null
var _lord_speech_bubble: PanelContainer = null
var _lord_speech_title: Label = null
var _lord_speech_text: Label = null
var _lord_modal: CanvasLayer = null
var _lord_market_modal: CanvasLayer = null
var _lord_hud_accum: float = 0.0
var _obscured_cache: bool = false
var _obscured_check_accum: float = 0.25
var _bg_warming_paused: bool = false
var _alliance_notif_badge: PanelContainer = null
var _alliance_notif_lbl: Label = null
var _last_alliance_badge_cnt: int = -1


func _ensure_nodes() -> void:
	if btn_alliance == null:
		btn_alliance = get_node_or_null("BtnAlliance") if has_node("BtnAlliance") else (find_child("BtnAlliance", true, false) as Button)
	if btn_lord == null:
		btn_lord = get_node_or_null("BtnLord") if has_node("BtnLord") else (find_child("BtnLord", true, false) as Button)
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
	btn_alliance.text = "İTTİFAK"
	btn_alliance.icon = IconAllianceShield
	btn_alliance.expand_icon = true
	btn_alliance.add_theme_constant_override("icon_max_width", 30)
	btn_alliance.add_theme_font_override("font", FontCinzelBold)
	btn_alliance.add_theme_font_size_override("font_size", 23)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.16, 0.27, 0.94)
	sb.border_color = Color(0.86, 0.70, 0.34, 0.88)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 12
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.shadow_color = Color(0, 0, 0, 0.50)
	sb.shadow_size = 0
	var hov := sb.duplicate() as StyleBoxFlat
	hov.bg_color = Color(0.15, 0.24, 0.39, 0.98)
	hov.border_color = Color(0.98, 0.84, 0.44, 1.0)
	btn_alliance.add_theme_stylebox_override("normal", sb)
	btn_alliance.add_theme_stylebox_override("hover", hov)
	btn_alliance.add_theme_stylebox_override("pressed", hov)
	btn_alliance.add_theme_color_override("font_color", Color(0.98, 0.93, 0.72))
	btn_alliance.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.88))
	btn_alliance.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
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
		_ensure_alliance_notif_badge()
		_update_alliance_badge()
		if not btn_alliance.pressed.is_connected(_on_alliance_btn_pressed):
			btn_alliance.pressed.connect(_on_alliance_btn_pressed)

	_setup_lord_hud()

	_setup_overscan_bg()
	_ensure_attack_alarm_ui()

	# Arka plan ve binalar dinamik ResourceBar altından başlar; yatayda en sola (sağ kenar tam görünür) kenetlenir
	_sync_top_bar_layout()
	if village_area != null:
		var init_vp := _get_view_size()
		var init_eff := _effective_zoom()
		village_area.position = Vector2(_get_locked_x(init_vp, Vector2(1080.0, 1920.0) * init_eff), _get_top_bar_height())
		_clamp_village_area()
		var vp := get_viewport()
		if vp != null and not vp.size_changed.is_connected(_on_layout_resized):
			vp.size_changed.connect(_on_layout_resized)
	if not resized.is_connected(_on_layout_resized):
		resized.connect(_on_layout_resized)
	if resource_bar != null and not resource_bar.resized.is_connected(_on_layout_resized):
		resource_bar.resized.connect(_on_layout_resized)

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


	var gs_init = _resolve_game_state()
	if gs_init != null:
		_rendered_village_id = int(gs_init.active_village_id)

	refresh_all()
	_update_queue_ui()
	_update_incoming_attack_alarm(0.0, true)
	_init_animated_background()

	var wm_init = Engine.get_main_loop().root.get_node_or_null("WorldManager") if Engine.get_main_loop() is SceneTree else null
	if wm_init != null and gs_init != null and not gs_init.has_active_village():
		var p_init := str(gs_init.player.get("name", ""))
		var auth_init = Engine.get_main_loop().root.get_node_or_null("AuthManager") if Engine.get_main_loop() is SceneTree else null
		if auth_init != null and not str(auth_init.display_name).is_empty():
			p_init = str(auth_init.display_name)
		var recovered_v := false
		if wm_init.has_method("has_player_village"):
			var cand_worlds: Array = [wm_init.current_world_id]
			for wid_i in range(1, 11):
				if wid_i != wm_init.current_world_id:
					cand_worlds.append(wid_i)
			for wid_cand in cand_worlds:
				if wm_init.has_player_village(int(wid_cand), p_init) and not wm_init.is_player_conquered(int(wid_cand), p_init):
					if wm_init.enter_world(int(wid_cand), p_init):
						_rendered_village_id = int(gs_init.active_village_id)
						refresh_all()
						_update_queue_ui()
						recovered_v = true
						break
		if not recovered_v:
			if wm_init.is_player_conquered(wm_init.current_world_id, p_init) and wm_init.has_method("maybe_show_conquered_modal_for_current_scene"):
				wm_init.call_deferred("maybe_show_conquered_modal_for_current_scene", wm_init.current_world_id, p_init)
			elif DisplayServer.get_name() != "headless":
				get_tree().call_deferred("change_scene_to_file", "res://scenes/VillageSelect.tscn")
	elif wm_init != null and gs_init != null:
		var p_init := str(gs_init.player.get("name", ""))
		if wm_init.is_player_conquered(wm_init.current_world_id, p_init) and wm_init.has_method("maybe_show_conquered_modal_for_current_scene"):
			wm_init.call_deferred("maybe_show_conquered_modal_for_current_scene", wm_init.current_world_id, p_init)


func _exit_tree() -> void:
	if _cached_bg_cache != null and is_instance_valid(_cached_bg_cache) and _cached_bg_cache.has_method("pause_warming"):
		_cached_bg_cache.call("pause_warming")
	var wm = Engine.get_main_loop().root.get_node_or_null("WorldManager") if Engine.get_main_loop() is SceneTree else null
	if wm != null and wm.has_method("save_active_world"):
		wm.save_active_world()


func _on_building_panel_visibility_changed() -> void:
	if building_panel != null and not building_panel.visible:
		_update_queue_ui()


var _progress_timer: float = 0.0
var _bg_frame_idx: int = 0
var _bg_frame_timer: float = 0.0
var _rendered_village_id: int = -1
var _last_buildings_refresh_sig: String = ""
const BG_TOTAL_FRAMES: int = 96 # 96 kare (her 2. kare), 12 FPS = 8.0 saniyelik akıcı döngü & yarı VRAM
const BG_FPS: float = 12.0
const BG_FRAME_TIME: float = 1.0 / BG_FPS
const BG_LOOP_DURATION: float = float(BG_TOTAL_FRAMES) / BG_FPS
const BG_CADENCE_JITTER_SEC: float = 0.008


func _resolve_game_state() -> Node:
	if _cached_gs != null and is_instance_valid(_cached_gs):
		return _cached_gs
	var loop := Engine.get_main_loop()
	if loop is SceneTree and (loop as SceneTree).root != null:
		_cached_gs = (loop as SceneTree).root.get_node_or_null("GameState")
	return _cached_gs


func _init_animated_background() -> void:
	if background == null:
		return
	var loop := Engine.get_main_loop()
	if loop is SceneTree and (loop as SceneTree).root != null:
		_cached_bg_cache = (loop as SceneTree).root.get_node_or_null("VillageBackgroundCache")
	if _cached_bg_cache != null:
		var tex = _cached_bg_cache.get_frame(_bg_frame_idx)
		if tex != null:
			background.texture = tex
		if DisplayServer.get_name() == "headless":
			if _cached_bg_cache.has_method("ensure_warming"):
				_cached_bg_cache.call("ensure_warming")
		elif is_inside_tree() and get_tree() != null:
			var bgc_ref := _cached_bg_cache
			get_tree().create_timer(0.25).timeout.connect(func():
				if is_instance_valid(self) and is_inside_tree() and bgc_ref != null and is_instance_valid(bgc_ref) and bgc_ref.has_method("ensure_warming"):
					bgc_ref.call("ensure_warming")
			)
	elif ResourceLoader.exists("res://assets/sprites/village/animated_bg/f_000.webp"):
		background.texture = load("res://assets/sprites/village/animated_bg/f_000.webp")


func is_background_obscured() -> bool:
	if not is_visible_in_tree():
		return true
	var loop := Engine.get_main_loop()
	if loop is SceneTree and (loop as SceneTree).root != null:
		var root_node := (loop as SceneTree).root
		var gclk := root_node.get_node_or_null("GameClock")
		if gclk != null and bool(gclk.get("_app_backgrounded")):
			return true
		var qm := root_node.get_node_or_null("QuestManager")
		if qm != null:
			var q_modal = qm.get("_detail_modal")
			if q_modal is Control and (q_modal as Control).visible:
				return true
			elif q_modal is CanvasLayer and (q_modal as CanvasLayer).visible:
				return true
		for modal_name in ["MarketModal", "RoyalMarketModal", "LordModal", "LordUpgradeModal", "StoreModal", "SpeedupModal", "IncomingAttackAlertModal", "ConqueredModal"]:
			var m_local := get_node_or_null(modal_name)
			if m_local != null and bool(m_local.get("visible")):
				return true
			var m_root := root_node.get_node_or_null(modal_name)
			if m_root != null and bool(m_root.get("visible")):
				return true
	return false


func _is_background_obscured_cached(delta: float) -> bool:
	_obscured_check_accum += maxf(delta, 0.0)
	if _obscured_check_accum >= 0.25:
		_obscured_check_accum = 0.0
		_obscured_cache = is_background_obscured()
	return _obscured_cache


func _process(delta: float) -> void:
	var dt := maxf(delta, 0.0)
	_queue_ui_accum += dt
	if _queue_ui_accum >= 1.0:
		_queue_ui_accum = 0.0
		_update_queue_ui()
		_update_building_views_progress()
		_update_alliance_badge()
	_lord_hud_accum += dt
	if _lord_hud_accum >= 5.0:
		_lord_hud_accum = 0.0
		var lm_chk: Node = Engine.get_main_loop().root.get_node_or_null("LordManager") if Engine.get_main_loop() is SceneTree else null
		if lm_chk != null and lm_chk.has_method("is_injured") and bool(lm_chk.call("is_injured")):
			_refresh_lord_hud()
	_update_incoming_attack_alarm(dt, false)

	var obscured := _is_background_obscured_cached(dt)
	if _cached_bg_cache != null and is_instance_valid(_cached_bg_cache):
		if obscured and not _bg_warming_paused and _cached_bg_cache.has_method("pause_warming"):
			_cached_bg_cache.call("pause_warming")
			_bg_warming_paused = true
		elif not obscured and _bg_warming_paused and _cached_bg_cache.has_method("ensure_warming"):
			_cached_bg_cache.call("ensure_warming")
			_bg_warming_paused = false

	# Arka plan animasyonu: Tam ekran modal/arkaplanda duraklat, görünürken 12 FPS (8 sn döngü) akıcı oynat
	if background != null and not obscured:
		_bg_frame_timer += dt
		if _bg_frame_timer >= BG_FRAME_TIME - BG_CADENCE_JITTER_SEC:
			var steps: int = maxi(1, int(floor((_bg_frame_timer + BG_CADENCE_JITTER_SEC) / BG_FRAME_TIME)))
			_bg_frame_timer = maxf(0.0, _bg_frame_timer - float(steps) * BG_FRAME_TIME)
			if _cached_bg_cache == null or not is_instance_valid(_cached_bg_cache):
				var loop := Engine.get_main_loop()
				if loop is SceneTree and (loop as SceneTree).root != null:
					_cached_bg_cache = (loop as SceneTree).root.get_node_or_null("VillageBackgroundCache")
			if _cached_bg_cache != null:
				var total: int = mini(BG_TOTAL_FRAMES, _cached_bg_cache.get_frame_count())
				if total > 0:
					if DisplayServer.get_name() == "headless" or bool(_cached_bg_cache.get("is_fully_loaded")) or bool(_cached_bg_cache.get("_low_mem_ready")):
						var step_clamped := mini(steps, 2) if DisplayServer.get_name() != "headless" else steps
						_bg_frame_idx = (_bg_frame_idx + step_clamped) % total
						var tex = _cached_bg_cache.get_frame(_bg_frame_idx)
						if tex != null and background.texture != tex:
							background.texture = tex
					else:
						var next_idx := (_bg_frame_idx + 1) % total
						if _cached_bg_cache.has_method("is_frame_ready") and bool(_cached_bg_cache.call("is_frame_ready", next_idx)):
							_bg_frame_idx = next_idx
							var tex_ready = _cached_bg_cache.get_frame(_bg_frame_idx)
							if tex_ready != null and background.texture != tex_ready:
								background.texture = tex_ready


func _update_building_views_progress() -> void:
	var gs = _resolve_game_state()
	if gs == null or not gs.has_active_village() or gs.queues.is_empty():
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
					b_view.set_state(b_view.current_level, b_view.is_locked, is_active, pct, rem)


func _ensure_game_loop() -> void:
	if GameLoopScript.instance == null:
		_game_loop = GameLoopScript.new()
		add_child(_game_loop)
	elif GameLoopScript.instance.has_method("sync_wall_clock_now"):
		GameLoopScript.instance.call("sync_wall_clock_now")
	var clock = Engine.get_main_loop().root.get_node_or_null("GameClock") if Engine.get_main_loop() is SceneTree else null
	if clock != null and clock.has_method("start"):
		if not bool(clock.get("running")):
			clock.start()


func _on_resources_changed(village_id: int) -> void:
	var gs = _resolve_game_state()
	if gs == null or not gs.has_active_village() or village_id != gs.active_village_id:
		return
	# ResourceBar zaten EventBus.resources_changed sinyaline doğrudan bağlıdır ve Village._process
	# aktif inşaat ilerlemelerini 0.5sn'de bir günceller. Pasif 1sn kaynak tick'lerinde yalnızca
	# bina seviyeleri veya inşaat kuyruğu değiştiyse 15 BuildingView'u baştan yenile.
	var v: Dictionary = gs.get_active_village()
	var blds: Dictionary = v.get("buildings", {}) if typeof(v.get("buildings")) == TYPE_DICTIONARY else {}
	var b_q_count := 0
	for item in gs.queues:
		if typeof(item) == TYPE_DICTIONARY and int((item as Dictionary).get("village_id", -1)) == village_id and str((item as Dictionary).get("type", "")) == "build":
			b_q_count += 1
	var b_sig := "%d:%d:%d:%d:%d:%d" % [
		village_id,
		b_q_count,
		int(blds.get("main", 0)),
		int(blds.get("barracks", 0)),
		int(blds.get("storage", 0)),
		blds.hash()
	]
	if b_sig != _last_buildings_refresh_sig:
		_last_buildings_refresh_sig = b_sig
		refresh_all()


func _on_state_changed() -> void:
	var gs = _resolve_game_state()
	if gs != null and int(gs.active_village_id) != _rendered_village_id:
		_rendered_village_id = int(gs.active_village_id)
		if building_panel != null and building_panel.visible:
			building_panel.hide()
	refresh_all()
	_update_queue_ui()
	_update_incoming_attack_alarm(0.0, true)


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
	var loop := Engine.get_main_loop()
	if loop is SceneTree and (loop as SceneTree).root != null and (loop as SceneTree).root.has_node("GameState"):
		return (loop as SceneTree).root.get_node("GameState")
	return null


func _on_building_selected(key: String) -> void:
	if _is_panning or _was_gesture or (Time.get_ticks_msec() - _last_gesture_end_ms) < 280:
		return
	_ensure_nodes()
	if building_panel != null and building_panel.visible and building_panel.has_method("is_train_input_focused") and bool(building_panel.call("is_train_input_focused")):
		return
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
	_update_incoming_attack_alarm(0.0, true)
	if building_panel.visible:
		building_panel.refresh()
	var sm = Engine.get_main_loop().root.get_node_or_null("SaveManager") if Engine.get_main_loop() is SceneTree else null
	if sm != null:
		if sm.has_method("request_save_game"):
			sm.call("request_save_game")
		else:
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
	_update_alliance_badge()


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
	_update_incoming_attack_alarm(0.0, true)
	if building_panel.visible:
		building_panel.refresh()


func _current_now() -> int:
	var best := int(Time.get_unix_time_from_system())
	if GameLoopScript.instance != null and GameLoopScript.instance.now_unix() > 0:
		best = maxi(best, GameLoopScript.instance.now_unix())
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs != null:
		var w = gs.world
		if typeof(w) == TYPE_DICTIONARY and (w as Dictionary).has("sim_now_unix"):
			best = maxi(best, int((w as Dictionary)["sim_now_unix"]))
	return best


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
	var returned_origin_keys: Dictionary = {}
	var returned_seed_keys: Dictionary = {}
	for m in gs.movements:
		if typeof(m) == TYPE_DICTIONARY:
			var md_chk := m as Dictionary
			if str(md_chk.get("state", "")) == "returning" or str(md_chk.get("type", "")) == "return":
				var ret_home_vid := int(md_chk.get("to_village_id", md_chk.get("village_id", 0)))
				var omid := int(md_chk.get("origin_movement_id", 0))
				if omid > 0:
					returned_origin_keys["%d:%d" % [ret_home_vid, omid]] = true
				var bseed := int(md_chk.get("battle_seed", 0))
				if bseed > 0:
					returned_seed_keys["%d:%d" % [ret_home_vid, bseed]] = true

	for m in gs.movements:
		if typeof(m) == TYPE_DICTIONARY:
			var md_inc := m as Dictionary
			var to_id = int(md_inc.get("to_village_id", -1))
			var from_id_inc = int(md_inc.get("from_village_id", -1))
			var m_type = str(md_inc.get("type", ""))
			var m_state = str(md_inc.get("state", ""))
			if m_type == "spy" and bool(md_inc.get("creeping", false)):
				continue
			if to_id == vid and from_id_inc != vid and m_state == "outgoing" and (m_type in ["attack", "raid", "spy"]):
				activities.append({
					"category": "incoming_attack",
					"type": m_type,
					"data": m
				})
				incoming_count += 1

	# 2) Çıkan ve Dönen Askeri Seferler
	var seen_act_movs: Dictionary = {}
	for m in gs.movements:
		if typeof(m) == TYPE_DICTIONARY:
			var m_dict := m as Dictionary
			var from_id := int(m_dict.get("from_village_id", -1))
			var to_id := int(m_dict.get("to_village_id", -1))
			var vill_id := int(m_dict.get("village_id", -1))
			var m_state := str(m_dict.get("state", ""))
			var m_type := str(m_dict.get("type", "attack"))
			var is_ret := (m_state == "returning" or m_type == "return")
			var mid := int(m_dict.get("id", 0))
			var bseed := int(m_dict.get("battle_seed", 0))
			if not is_ret and ((mid > 0 and returned_origin_keys.has("%d:%d" % [from_id, mid])) or (bseed > 0 and returned_seed_keys.has("%d:%d" % [from_id, bseed]))):
				continue
			if (from_id == vid and not is_ret and m_state == "outgoing") or (is_ret and (to_id == vid or vill_id == vid)):
				var act_dedup_k := "%d_%s_%d" % [mid, "ret" if is_ret else "out", bseed]
				if mid > 0 and seen_act_movs.has(act_dedup_k):
					continue
				seen_act_movs[act_dedup_k] = true
				activities.append({
					"category": "outgoing_attack",
					"type": m_type,
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


func _ensure_queue_styles() -> void:
	if _q_pb_bg == null:
		_q_pb_bg = StyleBoxFlat.new()
		_q_pb_bg.bg_color = Color(0.08, 0.07, 0.10, 0.95)
		_q_pb_bg.border_color = Color(0.50, 0.42, 0.30, 0.8)
		_q_pb_bg.set_border_width_all(1)
		_q_pb_bg.set_corner_radius_all(8)
	if _q_pb_fg == null:
		_q_pb_fg = StyleBoxFlat.new()
		_q_pb_fg.bg_color = Color(0.20, 0.80, 0.42, 1.0)
		_q_pb_fg.set_corner_radius_all(7)
	if _q_cancel_norm == null:
		_q_cancel_norm = StyleBoxFlat.new()
		_q_cancel_norm.bg_color = Color(0.68, 0.18, 0.15, 0.95)
		_q_cancel_norm.border_color = Color(0.98, 0.55, 0.45, 0.95)
		_q_cancel_norm.set_border_width_all(2)
		_q_cancel_norm.set_corner_radius_all(12)
		_q_cancel_hover = _q_cancel_norm.duplicate() as StyleBoxFlat
		_q_cancel_hover.bg_color = Color(0.84, 0.24, 0.20, 1.0)
		_q_cancel_hover.border_color = Color(1.0, 0.72, 0.62, 1.0)
		_q_cancel_pressed = _q_cancel_norm.duplicate() as StyleBoxFlat
		_q_cancel_pressed.bg_color = Color(0.50, 0.12, 0.10, 1.0)
	if _q_cancel_dis == null:
		_q_cancel_dis = StyleBoxFlat.new()
		_q_cancel_dis.bg_color = Color(0.26, 0.14, 0.14, 0.78)
		_q_cancel_dis.border_color = Color(0.55, 0.30, 0.30, 0.72)
		_q_cancel_dis.set_border_width_all(2)
		_q_cancel_dis.set_corner_radius_all(12)
	if _q_speedup_have_sb == null:
		_q_speedup_have_sb = StyleBoxFlat.new()
		_q_speedup_have_sb.bg_color = Color(0.16, 0.44, 0.24, 0.98)
		_q_speedup_have_sb.border_color = Color(0.95, 0.80, 0.36, 0.98)
		_q_speedup_have_sb.set_border_width_all(2)
		_q_speedup_have_sb.set_corner_radius_all(12)
		_q_speedup_have_hover = _q_speedup_have_sb.duplicate() as StyleBoxFlat
		_q_speedup_have_hover.bg_color = Color(0.22, 0.56, 0.32, 1.0)
	if _q_speedup_buy_sb == null:
		_q_speedup_buy_sb = StyleBoxFlat.new()
		_q_speedup_buy_sb.bg_color = Color(0.12, 0.25, 0.46, 0.98)
		_q_speedup_buy_sb.border_color = Color(0.92, 0.76, 0.34, 0.96)
		_q_speedup_buy_sb.set_border_width_all(2)
		_q_speedup_buy_sb.set_corner_radius_all(12)
		_q_speedup_buy_hover = _q_speedup_buy_sb.duplicate() as StyleBoxFlat
		_q_speedup_buy_hover.bg_color = Color(0.18, 0.34, 0.60, 1.0)


func _fmt_duration(secs: int) -> String:
	var s := maxi(0, secs)
	var sm = Engine.get_main_loop().root.get_node_or_null("StoreManager") if Engine.get_main_loop() is SceneTree else null
	if sm != null and sm.has_method("format_duration"):
		return str(sm.call("format_duration", s))
	var h := s / 3600
	var m := (s % 3600) / 60
	var rem := s % 60
	if h > 0:
		return "%02d:%02d:%02d" % [h, m, rem]
	return "%02d:%02d" % [m, rem]


func _apply_queue_speedup_style(btn: Button, category: String) -> void:
	_ensure_queue_styles()
	var sm = Engine.get_main_loop().root.get_node_or_null("StoreManager") if Engine.get_main_loop() is SceneTree else null
	var count := 0
	if sm != null and sm.has_method("get_category_scroll_total"):
		count = int(sm.call("get_category_scroll_total", category))
	btn.text = "⚡ Hızlandır (%d)" % count if count > 0 else "🛒 Parşömen Al"
	var sb_n := _q_speedup_have_sb if count > 0 else _q_speedup_buy_sb
	var sb_h := _q_speedup_have_hover if count > 0 else _q_speedup_buy_hover
	btn.add_theme_stylebox_override("normal", sb_n)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_stylebox_override("pressed", sb_h)


func _open_queue_speedup(category: String, target_id: Variant, title_text: String) -> void:
	var sm = Engine.get_main_loop().root.get_node_or_null("StoreManager") if Engine.get_main_loop() is SceneTree else null
	if sm != null and sm.has_method("open_speedup_modal"):
		sm.call("open_speedup_modal", self, category, target_id, title_text)
	elif sm != null and sm.has_method("open_market"):
		sm.call("open_market", self, category)


func _setup_queue_hud_styling() -> void:
	_ensure_queue_styles()
	if queue_hud != null:
		var q_sb := StyleBoxFlat.new()
		q_sb.bg_color = Color(0.08, 0.07, 0.11, 0.97)
		q_sb.border_color = Color(0.90, 0.74, 0.34, 0.96)
		q_sb.set_border_width_all(2)
		q_sb.border_width_top = 4
		q_sb.set_corner_radius_all(18)
		q_sb.content_margin_left = 18
		q_sb.content_margin_top = 14
		q_sb.content_margin_right = 18
		q_sb.content_margin_bottom = 14
		q_sb.shadow_color = Color(0, 0, 0, 0.72)
		q_sb.shadow_size = 0
		queue_hud.add_theme_stylebox_override("panel", q_sb)
		if queue_title != null:
			queue_title.text = "⚔️ AKTİVİTELER VE ASKERİ DURUM"
			queue_title.add_theme_font_override("font", FontCinzelBold)
			queue_title.add_theme_color_override("font_color", Color(1.0, 0.91, 0.56))
			queue_title.add_theme_font_size_override("font_size", 23)
			queue_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.98))
			queue_title.add_theme_constant_override("shadow_offset_y", 2)


func _draw_queue_row(row: HBoxContainer) -> void:
	if row == null:
		return
	var accent: Color = row.get_meta("accent_color", Color(0.90, 0.74, 0.34))
	var card_sb: StyleBoxFlat = _q_row_card_sbs.get(accent, null) as StyleBoxFlat
	if card_sb == null:
		card_sb = StyleBoxFlat.new()
		card_sb.bg_color = Color(0.13, 0.11, 0.17, 0.95)
		card_sb.border_color = Color(accent.r * 0.75, accent.g * 0.75, accent.b * 0.75, 0.65)
		card_sb.set_border_width_all(1)
		card_sb.set_corner_radius_all(10)
		_q_row_card_sbs[accent] = card_sb
	row.draw_style_box(card_sb, Rect2(Vector2(-6.0, -4.0), row.size + Vector2(12.0, 8.0)))
	row.draw_rect(Rect2(Vector2(-6.0, -2.0), Vector2(5.0, row.size.y + 4.0)), accent)


func _create_queue_row() -> HBoxContainer:
	_ensure_queue_styles()
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 52)
	row.add_theme_constant_override("separation", 10)
	row.set_meta("accent_color", Color(0.90, 0.74, 0.34))
	row.draw.connect(_draw_queue_row.bind(row))

	var cat_icon := TextureRect.new()
	cat_icon.name = "CategoryIcon"
	cat_icon.custom_minimum_size = Vector2(30, 30)
	cat_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cat_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cat_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cat_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cat_icon.texture = IconScrollBuild
	row.add_child(cat_icon)

	var icon_name_lbl := Label.new()
	icon_name_lbl.name = "IconNameLabel"
	icon_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_name_lbl.clip_text = true
	icon_name_lbl.add_theme_font_size_override("font_size", 23)
	icon_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.88))
	icon_name_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.98))
	icon_name_lbl.add_theme_constant_override("shadow_offset_y", 2)
	row.add_child(icon_name_lbl)

	var time_lbl := Label.new()
	time_lbl.name = "TimeLabel"
	time_lbl.custom_minimum_size = Vector2(96, 0)
	time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time_lbl.add_theme_font_size_override("font_size", 23)
	time_lbl.add_theme_color_override("font_color", Color(0.42, 0.90, 1.0))
	time_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.98))
	time_lbl.add_theme_constant_override("shadow_offset_y", 2)
	row.add_child(time_lbl)

	var progress := ProgressBar.new()
	progress.name = "ProgressBar"
	progress.custom_minimum_size = Vector2(92, 22)
	progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progress.show_percentage = false
	progress.add_theme_stylebox_override("background", _q_pb_bg)
	progress.add_theme_stylebox_override("fill", _q_pb_fg)
	row.add_child(progress)

	var speedup_btn := Button.new()
	speedup_btn.name = "SpeedupButton"
	speedup_btn.text = "⚡ Hızlandır"
	speedup_btn.custom_minimum_size = Vector2(154, 42)
	speedup_btn.add_theme_font_size_override("font_size", 22)
	speedup_btn.add_theme_stylebox_override("normal", _q_speedup_have_sb)
	speedup_btn.add_theme_stylebox_override("hover", _q_speedup_have_hover)
	speedup_btn.add_theme_stylebox_override("pressed", _q_speedup_have_hover)
	speedup_btn.add_theme_color_override("font_color", Color(1.0, 0.96, 0.86))
	speedup_btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	speedup_btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.92, 0.62))
	speedup_btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	speedup_btn.add_theme_constant_override("shadow_offset_y", 2)
	row.add_child(speedup_btn)

	var cancel_btn := Button.new()
	cancel_btn.name = "CancelButton"
	cancel_btn.text = "X İptal"
	cancel_btn.custom_minimum_size = Vector2(90, 42)
	cancel_btn.add_theme_font_size_override("font_size", 22)
	cancel_btn.add_theme_stylebox_override("normal", _q_cancel_norm)
	cancel_btn.add_theme_stylebox_override("hover", _q_cancel_hover)
	cancel_btn.add_theme_stylebox_override("pressed", _q_cancel_pressed)
	cancel_btn.add_theme_stylebox_override("disabled", _q_cancel_dis)
	cancel_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	cancel_btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	cancel_btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.92, 0.72))
	cancel_btn.add_theme_color_override("font_disabled_color", Color(0.82, 0.72, 0.72))
	cancel_btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	cancel_btn.add_theme_constant_override("shadow_offset_y", 2)
	row.add_child(cancel_btn)

	return row


func _bind_queue_row(row: HBoxContainer, activity: Dictionary, now: int) -> void:
	var category: String = str(activity.get("category", ""))
	var data: Dictionary = activity.get("data", {})
	var cat_icon: TextureRect = row.get_node_or_null("CategoryIcon") as TextureRect
	var icon_name_lbl: Label = row.get_node("IconNameLabel")
	var time_lbl: Label = row.get_node("TimeLabel")
	var progress: ProgressBar = row.get_node("ProgressBar")
	var speedup_btn: Button = row.get_node_or_null("SpeedupButton") as Button
	var cancel_btn: Button = row.get_node("CancelButton")
	var accent_col := Color(0.90, 0.74, 0.34)
	match category:
		"incoming_attack":
			accent_col = Color(0.95, 0.34, 0.32)
			if cat_icon != null: cat_icon.texture = IconReportSeal
		"outgoing_attack":
			accent_col = Color(0.96, 0.68, 0.28)
			if cat_icon != null: cat_icon.texture = IconScrollMarch
		"research":
			accent_col = Color(0.42, 0.80, 1.0)
			if cat_icon != null: cat_icon.texture = IconScrollResearch
		"train":
			accent_col = Color(0.40, 0.90, 0.56)
			if cat_icon != null: cat_icon.texture = IconScrollTrain
		_:
			accent_col = Color(0.94, 0.76, 0.34)
			if cat_icon != null: cat_icon.texture = IconScrollBuild
	var prev_accent: Variant = row.get_meta("accent_color", Color(-1, -1, -1, -1))
	if not (prev_accent is Color) or (prev_accent as Color) != accent_col:
		row.set_meta("accent_color", accent_col)
		row.queue_redraw()

	var item_id: int = int(data.get("id", -1))
	var meta_key := "%s_%d" % [category, item_id]
	var speedup_cat := ""

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
			time_lbl.text = _fmt_duration(rem)
			time_lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
			progress.value = pct

			cancel_btn.text = "Alarm!"
			cancel_btn.disabled = true
			if speedup_btn != null:
				speedup_btn.hide()

		"outgoing_attack":
			speedup_cat = "march"
			var to_id := int(data.get("to_village_id", 0))
			var from_id := int(data.get("from_village_id", 0))
			var m_state := str(data.get("state", "outgoing"))
			var m_type := str(data.get("type", "attack"))
			var is_ret := (m_state == "returning" or m_type == "return")
			var target_u := int(data.get("return_unix", data.get("arrive_unix", now))) if is_ret else int(data.get("arrive_unix", now))
			var dep_u := int(data.get("depart_unix", now))
			var rem := maxi(0, target_u - now)
			var total_dur := maxi(1, target_u - dep_u)
			var pct := clampf(float(total_dur - rem) / float(total_dur) * 100.0, 0.0, 100.0)

			if is_ret:
				icon_name_lbl.text = "↩ Ordu Dönüyor (#%d)" % (from_id if from_id > 0 else to_id)
				icon_name_lbl.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0))
			else:
				icon_name_lbl.text = "⚔️ Sefer: Köy #%d" % to_id
				icon_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.40))

			time_lbl.text = _fmt_duration(rem)
			time_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.40))
			progress.value = pct

			var can_cancel := (not is_ret and m_state == "outgoing" and (now - dep_u) <= 90)
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
			speedup_cat = "build"
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

			var next_txt := "%s (Sv. %d)" % [b_name, tgt]
			if icon_name_lbl.text != next_txt:
				icon_name_lbl.text = next_txt
				icon_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.88))
			var t_str := _fmt_duration(rem) if is_active else ("Sıra (%s)" % _fmt_duration(rem))
			if time_lbl.text != t_str:
				time_lbl.text = t_str
				time_lbl.add_theme_color_override("font_color", Color(0.42, 0.90, 1.0) if is_active else Color(1.0, 0.85, 0.40))

			if absf(progress.value - pct) > 0.25:
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
			speedup_cat = "research"
			var u_key: String = str(data.get("key", ""))
			var u_name: String = GameDataScript.get_singleton().get_unit_name(u_key)
			var start := int(data.get("start_unix", now))
			var finish := int(data.get("finish_unix", now))
			var total_dur := maxi(1, finish - start)
			var rem := maxi(0, finish - now)
			var pct := clampf(float(total_dur - rem) / float(total_dur) * 100.0, 0.0, 100.0)

			icon_name_lbl.text = "%s (Araştırma)" % u_name
			icon_name_lbl.add_theme_color_override("font_color", Color(0.55, 0.90, 1.0))
			time_lbl.text = _fmt_duration(rem)
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
			speedup_cat = "train"
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
			time_lbl.text = _fmt_duration(rem)
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

	if speedup_btn != null and not speedup_cat.is_empty():
		speedup_btn.show()
		_apply_queue_speedup_style(speedup_btn, speedup_cat)
		var sp_meta_key := "%s_%d_%s" % [speedup_cat, item_id, icon_name_lbl.text]
		if str(speedup_btn.get_meta("sp_key", "")) != sp_meta_key:
			speedup_btn.set_meta("sp_key", sp_meta_key)
			for conn in speedup_btn.pressed.get_connections():
				speedup_btn.pressed.disconnect(conn["callable"])
			speedup_btn.pressed.connect(_open_queue_speedup.bind(speedup_cat, item_id, icon_name_lbl.text))


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
	_mouse_drag_total += rel.length()
	if _mouse_drag_total > TOUCH_PAN_DEADZONE:
		_last_gesture_end_ms = Time.get_ticks_msec()
		_cancel_all_building_presses()
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
	if _attack_alarm_banner != null and _attack_alarm_banner.visible:
		hud_nodes.append(_attack_alarm_banner)
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
				_touch_start_area_pos = village_area.position if village_area != null else Vector2.ZERO
				_touch_drag_total = 0.0
			elif _active_touches.size() >= 2:
				_is_panning = false
				_was_gesture = true
				_last_gesture_end_ms = Time.get_ticks_msec()
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
				var area_moved := village_area != null and village_area.position.distance_to(_touch_start_area_pos) > 4.0
				var moved := _touch_drag_total > TOUCH_PAN_DEADZONE or _touch_start_pos.distance_to(st.position) > TOUCH_PAN_DEADZONE or area_moved
				var handled := _was_gesture or _is_panning or moved
				if handled:
					_last_gesture_end_ms = Time.get_ticks_msec()
					_cancel_all_building_presses()
				_is_panning = false
				_was_gesture = false
				_touch_drag_total = 0.0
				if handled and had_touch:
					get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_last_touch_ms = Time.get_ticks_msec()
		if not _active_touches.has(sd.index):
			return
		_active_touches[sd.index] = sd.position
		if _active_touches.size() >= 2:
			_last_gesture_end_ms = Time.get_ticks_msec()
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
			if _is_panning or _touch_drag_total > TOUCH_PAN_DEADZONE or _touch_start_pos.distance_to(sd.position) > TOUCH_PAN_DEADZONE:
				if not _is_panning:
					_is_panning = true
					_was_gesture = true
					_cancel_all_building_presses()
				_last_gesture_end_ms = Time.get_ticks_msec()
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
				_mouse_drag_total = 0.0
				_pan_start_mouse = mb.position
				_pan_start_pos = village_area.position if village_area != null else Vector2(0.0, BASE_OFFSET_Y)
			else:
				if _mouse_drag_total > TOUCH_PAN_DEADZONE:
					_last_gesture_end_ms = Time.get_ticks_msec()
					_cancel_all_building_presses()
				_is_panning = false
				_mouse_drag_total = 0.0
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _is_panning:
			_mouse_drag_total += mm.relative.length()
			if _mouse_drag_total > TOUCH_PAN_DEADZONE:
				_last_gesture_end_ms = Time.get_ticks_msec()
				_cancel_all_building_presses()
			_pan_by(mm.relative)


func _get_view_size() -> Vector2:
	if size.x > 0.0 and size.y > 0.0:
		return size
	if is_inside_tree():
		var vp := get_viewport_rect().size
		if vp.x > 0.0 and vp.y > 0.0:
			return vp
	return Vector2(1080.0, 1920.0)


func _sync_top_bar_layout() -> void:
	var top_h := _get_top_bar_height()
	if btn_alliance != null:
		btn_alliance.offset_top = top_h + 14.0
		btn_alliance.offset_bottom = top_h + 70.0
	if btn_lord != null:
		btn_lord.offset_top = top_h + 80.0
		btn_lord.offset_bottom = top_h + 178.0
	if _lord_speech_bubble != null:
		_lord_speech_bubble.offset_top = top_h + 84.0
		_lord_speech_bubble.offset_bottom = top_h + 220.0
	if _attack_alarm_banner != null:
		_attack_alarm_banner.offset_top = top_h + 84.0
		_attack_alarm_banner.offset_bottom = top_h + 138.0
		_attack_alarm_banner.offset_left = -280.0
		_attack_alarm_banner.offset_right = 120.0


func _ensure_attack_alarm_ui() -> void:
	if _attack_alarm_overlay == null:
		_attack_alarm_overlay = Control.new()
		_attack_alarm_overlay.name = "AttackAlarmOverlay"
		_attack_alarm_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		_attack_alarm_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_attack_alarm_overlay.z_index = 45
		_attack_alarm_overlay.visible = false
		add_child(_attack_alarm_overlay)

		_attack_red_tint = ColorRect.new()
		_attack_red_tint.name = "AttackRedTint"
		_attack_red_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
		_attack_red_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_attack_red_tint.color = Color(0.88, 0.04, 0.04, 0.0)
		_attack_alarm_overlay.add_child(_attack_red_tint)

		_attack_red_frame = Panel.new()
		_attack_red_frame.name = "AttackRedFrame"
		_attack_red_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		_attack_red_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fsb := StyleBoxFlat.new()
		fsb.draw_center = false
		fsb.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		fsb.border_color = Color(1.0, 0.12, 0.12, 1.0)
		fsb.set_border_width_all(10)
		fsb.shadow_size = 0
		_attack_red_frame.add_theme_stylebox_override("panel", fsb)
		_attack_alarm_overlay.add_child(_attack_red_frame)

	if _attack_alarm_banner == null:
		_attack_alarm_banner = Button.new()
		_attack_alarm_banner.name = "AttackAlarmBanner"
		_attack_alarm_banner.z_index = 110
		_attack_alarm_banner.z_as_relative = false
		_attack_alarm_banner.anchor_left = 0.5
		_attack_alarm_banner.anchor_right = 0.5
		_attack_alarm_banner.anchor_top = 0.0
		_attack_alarm_banner.anchor_bottom = 0.0
		_attack_alarm_banner.offset_left = -300.0
		_attack_alarm_banner.offset_right = 300.0
		var top_h := _get_top_bar_height()
		_attack_alarm_banner.offset_top = top_h + 84.0
		_attack_alarm_banner.offset_bottom = top_h + 138.0
		_attack_alarm_banner.visible = false
		_attack_alarm_banner.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_attack_banner_sb = StyleBoxFlat.new()
		_attack_banner_sb.bg_color = Color(0.72, 0.08, 0.08, 0.96)
		_attack_banner_sb.border_color = Color(1.0, 0.55, 0.38, 1.0)
		_attack_banner_sb.set_border_width_all(3)
		_attack_banner_sb.set_corner_radius_all(14)
		_attack_banner_sb.shadow_size = 0
		var bhov := _attack_banner_sb.duplicate() as StyleBoxFlat
		bhov.bg_color = Color(0.84, 0.12, 0.12, 1.0)
		bhov.border_color = Color(1.0, 0.82, 0.46, 1.0)
		_attack_alarm_banner.add_theme_stylebox_override("normal", _attack_banner_sb)
		_attack_alarm_banner.add_theme_stylebox_override("hover", bhov)
		_attack_alarm_banner.add_theme_stylebox_override("pressed", bhov)
		_attack_alarm_banner.add_theme_font_override("font", FontCinzelBold)
		_attack_alarm_banner.add_theme_font_size_override("font_size", 21)
		_attack_alarm_banner.add_theme_color_override("font_color", Color(1.0, 0.96, 0.92))
		_attack_alarm_banner.pressed.connect(_on_attack_alarm_banner_pressed)
		add_child(_attack_alarm_banner)


func _on_attack_alarm_banner_pressed() -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null:
		return
	var incoming := IncomingAttackAlert.get_incoming_attacks(gs, _current_now())
	if not incoming.is_empty():
		IncomingAttackAlert.show_modal(self, incoming, true)


func _update_incoming_attack_alarm(delta: float, force_scan: bool = false) -> void:
	_ensure_attack_alarm_ui()
	var gs = _resolve_game_state()
	if gs == null or not gs.has_active_village():
		_cached_incoming_attacks.clear()
		_alarm_visual_accum = 0.0
		_last_alarm_banner_text = ""
		if _alarm_visual_active:
			_alarm_visual_active = false
			if _attack_alarm_overlay != null:
				_attack_alarm_overlay.visible = false
			if _attack_alarm_banner != null:
				_attack_alarm_banner.visible = false
			if village_area != null:
				village_area.modulate = Color.WHITE
			IncomingAttackAlert.close_modal(self)
		return

	_alarm_scan_accum += maxf(delta, 0.0)
	var scan_interval := 0.75 if not _cached_incoming_attacks.is_empty() else 1.5
	if force_scan or _alarm_scan_accum >= scan_interval:
		_alarm_scan_accum = 0.0
		_cached_incoming_attacks = IncomingAttackAlert.get_incoming_attacks(gs, _current_now())
	var incoming := _cached_incoming_attacks
	if incoming.is_empty():
		_attack_flash_time = 0.0
		_alarm_visual_accum = 0.0
		_last_alarm_banner_text = ""
		if _alarm_visual_active:
			_alarm_visual_active = false
			if _attack_alarm_overlay != null:
				_attack_alarm_overlay.visible = false
			if _attack_alarm_banner != null:
				_attack_alarm_banner.visible = false
			if village_area != null:
				village_area.modulate = Color.WHITE
			IncomingAttackAlert.close_modal(self)
		return

	var dt_pos := maxf(delta, 0.0)
	_attack_flash_time += dt_pos
	_alarm_visual_accum += dt_pos
	if _alarm_visual_active and not force_scan and _alarm_visual_accum < 0.10:
		return
	_alarm_visual_accum = 0.0
	_alarm_visual_active = true

	var pulse := 0.5 + 0.5 * sin(_attack_flash_time * 1.8)

	if _attack_alarm_overlay != null:
		_attack_alarm_overlay.visible = true
	if _attack_red_tint != null:
		_attack_red_tint.color = Color(0.88, 0.04, 0.04, lerpf(0.008, 0.042, pulse))
	if _attack_red_frame != null:
		_attack_red_frame.modulate.a = lerpf(0.08, 0.24, pulse)
	if village_area != null:
		village_area.modulate = Color.WHITE

	var first := incoming[0]
	var rem_sec := int(first.get("remaining_sec", 0))
	var rem_min := int(first.get("remaining_min", 1))
	if _attack_alarm_banner != null:
		_attack_alarm_banner.visible = true
		var next_banner_txt := (
			"🚨 SALDIRI ALARMI! < 1 dk (%ds) — Vezir Detayı" % rem_sec
			if rem_sec < 60
			else "🚨 SALDIRI ALARMI! %d dk kaldı (%s) — Vezir" % [rem_min, IncomingAttackAlert.fmt_countdown(rem_sec)]
		)
		if next_banner_txt != _last_alarm_banner_text:
			_last_alarm_banner_text = next_banner_txt
			_attack_alarm_banner.text = next_banner_txt
		_attack_alarm_banner.self_modulate = Color(1.0, lerpf(0.88, 1.0, pulse), lerpf(0.88, 1.0, pulse), 1.0)

	var tm: Node = Engine.get_main_loop().root.get_node_or_null("TutorialManager") if Engine.get_main_loop() is SceneTree else null
	var tut_active: bool = tm != null and tm.has_method("is_tutorial_active") and bool(tm.call("is_tutorial_active"))
	if not tut_active and IncomingAttackAlert.has_unacknowledged(incoming):
		IncomingAttackAlert.show_modal(self, incoming, true)


func _on_layout_resized() -> void:
	_sync_top_bar_layout()
	_clamp_village_area()


func _get_top_bar_height() -> float:
	if resource_bar != null:
		if resource_bar.has_method("get_bar_height"):
			return float(resource_bar.call("get_bar_height"))
		if resource_bar.size.y > 0.0:
			return resource_bar.size.y
	return BASE_OFFSET_Y


func _get_bottom_nav_height() -> float:
	if bottom_nav != null and bottom_nav.size.y > 0.0:
		return bottom_nav.size.y
	return 256.0


func _get_base_scale(vp_size: Vector2) -> float:
	var top_h := _get_top_bar_height()
	var nav_h := _get_bottom_nav_height()
	var vis_h := maxf(320.0, vp_size.y - nav_h - top_h)
	var v_cover := (vis_h + 280.0) / 1920.0
	var h_cover := vp_size.x / 1080.0
	return maxf(1.0, maxf(h_cover, v_cover))


func _effective_zoom() -> float:
	return _get_base_scale(_get_view_size()) * _current_zoom


func _get_locked_x(vp_size: Vector2, scaled_size: Vector2) -> float:
	if scaled_size.x <= vp_size.x + 1.0:
		return (vp_size.x - scaled_size.x) * 0.5
	return vp_size.x - scaled_size.x


func _pan_by(rel: Vector2) -> void:
	if village_area == null:
		return
	# Sağa/sola yatay kaydırma devre dışı — yalnızca dikey (yukarı/aşağı) kaydırma yapılır.
	village_area.position.y += rel.y
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
	var vp_size := _get_view_size()
	var eff := _effective_zoom()
	var scaled_size := Vector2(1080.0, 1920.0) * eff
	village_area.scale = Vector2(eff, eff)

	var top_h := _get_top_bar_height()
	var nav_h := _get_bottom_nav_height()
	var min_y := (vp_size.y - nav_h + 4.0) - scaled_size.y
	var max_y := maxf(0.0, top_h - 2.0)
	if min_y > max_y:
		var mid_y := top_h + ((vp_size.y - nav_h - top_h) - scaled_size.y) * 0.5
		min_y = mid_y
		max_y = mid_y

	village_area.position.x = _get_locked_x(vp_size, scaled_size)
	village_area.position.y = clampf(village_area.position.y, min_y, max_y)


func _reset_view() -> void:
	_current_zoom = 1.0
	if village_area != null:
		var vp_size := _get_view_size()
		var eff := _effective_zoom()
		var locked_x := _get_locked_x(vp_size, Vector2(1080.0, 1920.0) * eff)
		village_area.scale = Vector2(eff, eff)
		village_area.position = Vector2(locked_x, _get_top_bar_height())
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
	var vp_size := _get_view_size()
	var top_h := _get_top_bar_height()
	var nav_h := _get_bottom_nav_height()
	var eff := _effective_zoom()
	var locked_x := _get_locked_x(vp_size, Vector2(1080.0, 1920.0) * eff)
	village_area.scale = Vector2(eff, eff)
	village_area.position = Vector2(locked_x, top_h)
	_clamp_village_area()

	var b_view := get_building_view(b_key)
	if b_view != null:
		var grect := b_view.get_global_rect()
		var safe_top := top_h + 12.0
		var safe_bot := vp_size.y - nav_h - 4.0
		if grect.end.y > safe_bot:
			village_area.position.y -= (grect.end.y - safe_bot + 24.0)
		elif grect.position.y < safe_top:
			village_area.position.y += (safe_top - grect.position.y + 12.0)
		_clamp_village_area()


# =============================================================================
#  LORD BUTONU, KONUŞMA BALONU & MODALLAR (Build 38)
# =============================================================================

func _setup_lord_hud() -> void:
	if btn_lord == null:
		btn_lord = get_node_or_null("BtnLord") if has_node("BtnLord") else (find_child("BtnLord", true, false) as Button)
	if btn_lord != null:
		btn_lord.z_index = 100
		btn_lord.z_as_relative = false
		btn_lord.mouse_filter = Control.MOUSE_FILTER_STOP
		_style_lord_btn()
		if not btn_lord.pressed.is_connected(_on_lord_btn_pressed):
			btn_lord.pressed.connect(_on_lord_btn_pressed)

	_ensure_lord_speech_bubble()
	var lm: Node = Engine.get_main_loop().root.get_node_or_null("LordManager") if Engine.get_main_loop() is SceneTree else null
	if lm != null:
		if lm.has_signal("lord_changed") and not lm.lord_changed.is_connected(_refresh_lord_hud):
			lm.lord_changed.connect(_refresh_lord_hud)
		if lm.has_signal("speech_queued") and not lm.speech_queued.is_connected(_on_lord_speech_queued):
			lm.speech_queued.connect(_on_lord_speech_queued)
		if lm.has_signal("lord_recovered") and not lm.lord_recovered.is_connected(_refresh_lord_hud):
			lm.lord_recovered.connect(_refresh_lord_hud)
	_refresh_lord_hud()


func _style_lord_btn() -> void:
	if btn_lord == null:
		return
	btn_lord.text = ""
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.09, 0.16, 0.96)
	sb.border_color = Color(0.95, 0.78, 0.34, 0.96)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 10
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	var hov := sb.duplicate() as StyleBoxFlat
	hov.bg_color = Color(0.18, 0.14, 0.25, 0.99)
	hov.border_color = Color(1.0, 0.88, 0.45, 1.0)
	btn_lord.add_theme_stylebox_override("normal", sb)
	btn_lord.add_theme_stylebox_override("hover", hov)
	btn_lord.add_theme_stylebox_override("pressed", hov)

	if btn_lord.get_node_or_null("LordContent") != null:
		return

	var hb := HBoxContainer.new()
	hb.name = "LordContent"
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.add_theme_constant_override("separation", 10)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_lord.add_child(hb)

	var pic_box := PanelContainer.new()
	pic_box.custom_minimum_size = Vector2(72, 72)
	pic_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pic_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.06, 0.05, 0.09, 1.0)
	psb.border_color = Color(0.92, 0.76, 0.34, 0.92)
	psb.set_border_width_all(2)
	psb.set_corner_radius_all(12)
	psb.set_content_margin_all(2)
	pic_box.add_theme_stylebox_override("panel", psb)
	hb.add_child(pic_box)

	var pic := TextureRect.new()
	pic.texture = TexLordPortraitBtn
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic_box.add_child(pic)

	var tx_vb := VBoxContainer.new()
	tx_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tx_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	tx_vb.add_theme_constant_override("separation", 2)
	tx_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(tx_vb)

	var l_tag := Label.new()
	l_tag.text = "LORD"
	l_tag.add_theme_font_override("font", FontCinzelBold)
	l_tag.add_theme_font_size_override("font_size", 18)
	l_tag.add_theme_color_override("font_color", Color(1.0, 0.86, 0.38))
	l_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tx_vb.add_child(l_tag)

	_lord_name_lbl = Label.new()
	_lord_name_lbl.name = "LordPlayerName"
	_lord_name_lbl.text = "Hükümdar"
	_lord_name_lbl.clip_text = true
	_lord_name_lbl.add_theme_font_override("font", FontCinzelBold)
	_lord_name_lbl.add_theme_font_size_override("font_size", 20)
	_lord_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.88))
	_lord_name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tx_vb.add_child(_lord_name_lbl)

	_lord_status_badge = PanelContainer.new()
	_lord_status_badge.name = "LordInjuredBadge"
	_lord_status_badge.visible = false
	_lord_status_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.62, 0.12, 0.14, 0.96)
	bsb.border_color = Color(1.0, 0.50, 0.45, 1.0)
	bsb.set_border_width_all(1)
	bsb.set_corner_radius_all(6)
	bsb.content_margin_left = 6
	bsb.content_margin_right = 6
	_lord_status_badge.add_theme_stylebox_override("panel", bsb)
	tx_vb.add_child(_lord_status_badge)

	_lord_status_lbl = Label.new()
	_lord_status_lbl.text = "🩸 Yaralı"
	_lord_status_lbl.add_theme_font_size_override("font_size", 14)
	_lord_status_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.92))
	_lord_status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lord_status_badge.add_child(_lord_status_lbl)

	_lord_notif_dot = Panel.new()
	_lord_notif_dot.name = "LordNotifDot"
	_lord_notif_dot.visible = false
	_lord_notif_dot.custom_minimum_size = Vector2(18, 18)
	_lord_notif_dot.size = Vector2(18, 18)
	_lord_notif_dot.position = Vector2(6, 6)
	_lord_notif_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = Color(1.0, 0.78, 0.14, 1.0)
	dsb.border_color = Color(0.12, 0.08, 0.02, 1.0)
	dsb.set_border_width_all(2)
	dsb.set_corner_radius_all(9)
	_lord_notif_dot.add_theme_stylebox_override("panel", dsb)
	btn_lord.add_child(_lord_notif_dot)


func _ensure_lord_speech_bubble() -> void:
	if _lord_speech_bubble != null and is_instance_valid(_lord_speech_bubble):
		return
	_lord_speech_bubble = PanelContainer.new()
	_lord_speech_bubble.name = "LordSpeechBubble"
	_lord_speech_bubble.visible = false
	_lord_speech_bubble.z_index = 105
	_lord_speech_bubble.z_as_relative = false
	_lord_speech_bubble.anchor_left = 1.0
	_lord_speech_bubble.anchor_right = 1.0
	_lord_speech_bubble.anchor_top = 0.0
	_lord_speech_bubble.anchor_bottom = 0.0
	var top_h := _get_top_bar_height()
	_lord_speech_bubble.offset_left = -630.0
	_lord_speech_bubble.offset_right = -256.0
	_lord_speech_bubble.offset_top = top_h + 84.0
	_lord_speech_bubble.offset_bottom = top_h + 220.0
	_lord_speech_bubble.mouse_filter = Control.MOUSE_FILTER_STOP

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.09, 0.16, 0.97)
	sb.border_color = Color(0.96, 0.80, 0.36, 1.0)
	sb.set_border_width_all(2)
	sb.border_width_right = 4
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(10)
	_lord_speech_bubble.add_theme_stylebox_override("panel", sb)
	add_child(_lord_speech_bubble)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	_lord_speech_bubble.add_child(vb)

	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 6)
	vb.add_child(hdr)

	_lord_speech_title = Label.new()
	_lord_speech_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lord_speech_title.clip_text = true
	_lord_speech_title.add_theme_font_override("font", FontCinzelBold)
	_lord_speech_title.add_theme_font_size_override("font_size", 18)
	_lord_speech_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.44))
	hdr.add_child(_lord_speech_title)

	var btn_x := Button.new()
	btn_x.name = "BtnCloseSpeechBubble"
	btn_x.text = "×"
	btn_x.custom_minimum_size = Vector2(44, 40)
	btn_x.clip_text = false
	btn_x.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_x.add_theme_font_override("font", FontNunitoBold)
	btn_x.add_theme_font_size_override("font_size", 26)
	var xsb := StyleBoxFlat.new()
	xsb.bg_color = Color(0.62, 0.14, 0.16, 0.98)
	xsb.border_color = Color(0.95, 0.56, 0.54, 0.95)
	xsb.set_border_width_all(1)
	xsb.set_corner_radius_all(8)
	xsb.set_content_margin_all(2)
	var xsb_h := xsb.duplicate() as StyleBoxFlat
	xsb_h.bg_color = Color(0.78, 0.20, 0.22, 1.0)
	btn_x.add_theme_stylebox_override("normal", xsb)
	btn_x.add_theme_stylebox_override("hover", xsb_h)
	btn_x.add_theme_stylebox_override("pressed", xsb_h)
	btn_x.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	btn_x.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	btn_x.add_theme_color_override("font_pressed_color", Color(1.0, 0.95, 0.80, 1.0))
	btn_x.pressed.connect(_on_speech_bubble_dismiss)
	hdr.add_child(btn_x)

	var click_btn := Button.new()
	click_btn.name = "BtnOpenSpeechTarget"
	click_btn.flat = true
	click_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	click_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	click_btn.pressed.connect(_on_speech_bubble_pressed)
	vb.add_child(click_btn)

	_lord_speech_text = Label.new()
	_lord_speech_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lord_speech_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lord_speech_text.add_theme_font_size_override("font_size", 17)
	_lord_speech_text.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	_lord_speech_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	click_btn.add_child(_lord_speech_text)


func _on_lord_speech_queued(_entry: Dictionary) -> void:
	_refresh_lord_hud()


func _refresh_lord_hud() -> void:
	var gs := _resolve_game_state()
	if _lord_name_lbl != null and gs != null and typeof(gs.player) == TYPE_DICTIONARY:
		var pn := str(gs.player.get("name", "Hükümdar")).strip_edges()
		if pn.is_empty():
			pn = "Hükümdar"
		_lord_name_lbl.text = pn

	var lm: Node = Engine.get_main_loop().root.get_node_or_null("LordManager") if Engine.get_main_loop() is SceneTree else null
	if lm == null:
		return
	var injured := bool(lm.call("is_injured"))
	if _lord_status_badge != null and _lord_status_lbl != null:
		_lord_status_badge.visible = injured
		if injured:
			var rem := int(lm.call("get_injury_remaining_secs"))
			var mins := int(ceil(float(rem) / 60.0))
			_lord_status_lbl.text = "🩸 %d dk" % maxi(1, mins)

	var q_cnt := int(lm.call("get_speech_count"))
	if _lord_notif_dot != null:
		_lord_notif_dot.visible = q_cnt > 0

	if _lord_speech_bubble != null:
		if q_cnt > 0 and not is_background_obscured():
			var entry: Dictionary = lm.call("peek_speech")
			_lord_speech_title.text = str(entry.get("title", "Lord"))
			_lord_speech_text.text = str(entry.get("text", ""))
			_lord_speech_bubble.show()
		else:
			_lord_speech_bubble.hide()


func _ensure_alliance_notif_badge() -> void:
	if btn_alliance == null or (_alliance_notif_badge != null and is_instance_valid(_alliance_notif_badge)):
		return
	var b := PanelContainer.new()
	b.name = "AllianceNotifBadge"
	b.visible = false
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.anchor_top = 0.0
	b.anchor_bottom = 0.0
	b.offset_left = -24.0
	b.offset_right = 6.0
	b.offset_top = -10.0
	b.offset_bottom = 20.0
	b.custom_minimum_size = Vector2(30, 30)
	var b_sb := StyleBoxFlat.new()
	b_sb.bg_color = Color(0.90, 0.14, 0.14, 1.0)
	b_sb.border_color = Color(1.0, 0.92, 0.88, 1.0)
	b_sb.set_border_width_all(2)
	b_sb.set_corner_radius_all(15)
	b_sb.set_content_margin_all(2)
	b_sb.shadow_size = 0
	b.add_theme_stylebox_override("panel", b_sb)

	var lbl := Label.new()
	lbl.name = "CountLabel"
	lbl.text = "0"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_override("font", FontNunitoBold)
	lbl.add_theme_font_size_override("font_size", 17)
	lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	b.add_child(lbl)

	btn_alliance.add_child(b)
	_alliance_notif_badge = b
	_alliance_notif_lbl = lbl


func _update_alliance_badge() -> void:
	if btn_alliance == null:
		return
	_ensure_alliance_notif_badge()
	if _alliance_notif_badge == null or _alliance_notif_lbl == null:
		return
	var gs := _resolve_game_state()
	var cnt := 0
	if gs != null and typeof(gs.player) == TYPE_DICTIONARY:
		var p_name := str(gs.player.get("name", "")).strip_edges()
		if not p_name.is_empty():
			var st: Dictionary = {"alliances": gs.alliances}
			cnt = AllianceModelScript.get_pending_join_request_count(st, p_name)
	if cnt == _last_alliance_badge_cnt:
		return
	_last_alliance_badge_cnt = cnt
	_alliance_notif_badge.visible = cnt > 0
	if cnt > 0:
		_alliance_notif_lbl.text = "99+" if cnt > 99 else str(cnt)


func _on_speech_bubble_dismiss() -> void:
	var lm: Node = Engine.get_main_loop().root.get_node_or_null("LordManager") if Engine.get_main_loop() is SceneTree else null
	if lm != null:
		lm.call("dismiss_current_speech")
	_refresh_lord_hud()


func _on_speech_bubble_pressed() -> void:
	var lm: Node = Engine.get_main_loop().root.get_node_or_null("LordManager") if Engine.get_main_loop() is SceneTree else null
	var action := ""
	var item_id := ""
	if lm != null:
		var entry: Dictionary = lm.call("peek_speech")
		action = str(entry.get("target_action", "lord_screen"))
		item_id = str(entry.get("item_id", ""))
		lm.call("dismiss_current_speech")
	_refresh_lord_hud()
	open_lord_modal(action, item_id)


func _on_lord_btn_pressed() -> void:
	open_lord_modal()


func open_lord_modal(focus_action: String = "", focus_item_id: String = "") -> void:
	if _lord_modal == null or not is_instance_valid(_lord_modal):
		_lord_modal = LordModalScript.new()
		_lord_modal.name = "LordModal"
		if _lord_modal.has_signal("open_market_lord_requested"):
			_lord_modal.connect("open_market_lord_requested", open_market_lord_tab)
		if _lord_modal.has_signal("open_market_diamonds_requested"):
			_lord_modal.connect("open_market_diamonds_requested", open_market_diamonds_tab)
		add_child(_lord_modal)
	_lord_modal.call("open_modal", focus_action, focus_item_id)


func open_market_lord_tab() -> void:
	if _lord_market_modal == null or not is_instance_valid(_lord_market_modal):
		_lord_market_modal = MarketModalScript.new()
		add_child(_lord_market_modal)
	_lord_market_modal.call("open_tab", "lord")


func open_market_diamonds_tab() -> void:
	if _lord_market_modal == null or not is_instance_valid(_lord_market_modal):
		_lord_market_modal = MarketModalScript.new()
		add_child(_lord_market_modal)
	_lord_market_modal.call("open_tab", "diamonds")

