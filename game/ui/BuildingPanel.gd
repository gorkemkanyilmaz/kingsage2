extends PanelContainer
## BuildingPanel — Bina detay ve gereksinim zinciri paneli (A-ARAYUZ).

signal building_switched(building_key: String)
signal closed()

const RulesEngineScript := preload("res://scripts/rules/RulesEngine.gd")
const EconomyAPI := preload("res://scripts/sim/economy/EconomyAPI.gd")
const Palette := preload("res://themes/Palette.gd")
const GameLoopScript := preload("res://scripts/core/GameLoop.gd")

var _current_key: String = ""
var _village: Dictionary = {}

@onready var title_label: Label = $VBox/Header/TitleLabel
@onready var level_label: Label = $VBox/Header/LevelLabel
@onready var close_btn: Button = $VBox/Header/CloseButton

@onready var active_build_box: PanelContainer = $VBox/ActiveBuildBox
@onready var active_build_icon_lbl: Label = $VBox/ActiveBuildBox/HBox/IconLabel
@onready var active_build_time_lbl: Label = $VBox/ActiveBuildBox/HBox/TimeLabel
@onready var active_build_progress: ProgressBar = $VBox/ActiveBuildBox/HBox/ProgressBar
@onready var active_build_cancel_btn: Button = $VBox/ActiveBuildBox/HBox/CancelButton

@onready var cost_wood: Label = $VBox/CostContainer/WoodBox/Label
@onready var cost_stone: Label = $VBox/CostContainer/StoneBox/Label
@onready var cost_iron: Label = $VBox/CostContainer/IronBox/Label
@onready var time_label: Label = $VBox/MetaContainer/TimeLabel
@onready var extra_cost_label: Label = $VBox/MetaContainer/ExtraCostLabel

@onready var upgrade_btn: Button = $VBox/UpgradeButton
@onready var req_container: VBoxContainer = $VBox/RequirementSection/ReqScroll/ReqList
@onready var req_section: VBoxContainer = $VBox/RequirementSection


func _ensure_nodes() -> void:
	if title_label == null:
		title_label = $VBox/Header/TitleLabel
		level_label = $VBox/Header/LevelLabel
		close_btn = $VBox/Header/CloseButton
		cost_wood = $VBox/CostContainer/WoodBox/Label
		cost_stone = $VBox/CostContainer/StoneBox/Label
		cost_iron = $VBox/CostContainer/IronBox/Label
		time_label = $VBox/MetaContainer/TimeLabel
		extra_cost_label = $VBox/MetaContainer/ExtraCostLabel
		upgrade_btn = $VBox/UpgradeButton
		req_container = $VBox/RequirementSection/ReqScroll/ReqList
		req_section = $VBox/RequirementSection
	if active_build_box == null and has_node("VBox/ActiveBuildBox"):
		active_build_box = $VBox/ActiveBuildBox
		active_build_icon_lbl = $VBox/ActiveBuildBox/HBox/IconLabel
		active_build_time_lbl = $VBox/ActiveBuildBox/HBox/TimeLabel
		active_build_progress = $VBox/ActiveBuildBox/HBox/ProgressBar
		active_build_cancel_btn = $VBox/ActiveBuildBox/HBox/CancelButton


func _ready() -> void:
	_ensure_nodes()
	if not close_btn.pressed.is_connected(_on_close_pressed):
		close_btn.pressed.connect(_on_close_pressed)
	if not upgrade_btn.pressed.is_connected(_on_upgrade_pressed):
		upgrade_btn.pressed.connect(_on_upgrade_pressed)

	close_btn.pivot_offset = Vector2(24, 24)
	close_btn.mouse_entered.connect(func():
		var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(close_btn, "scale", Vector2(1.10, 1.10), 0.12)
	)
	close_btn.mouse_exited.connect(func():
		var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(close_btn, "scale", Vector2(1.0, 1.0), 0.12)
	)

	upgrade_btn.pivot_offset = Vector2(490, 42)
	upgrade_btn.button_down.connect(func():
		var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(upgrade_btn, "scale", Vector2(0.97, 0.97), 0.08)
	)
	upgrade_btn.button_up.connect(func():
		var tw = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(upgrade_btn, "scale", Vector2(1.0, 1.0), 0.2)
	)


func _process(_delta: float) -> void:
	if visible:
		_update_active_build_info()


func _on_close_pressed() -> void:
	hide()
	closed.emit()


func show_building(village: Dictionary, key: String) -> void:
	_ensure_nodes()
	_village = village
	_current_key = key
	refresh()
	show()


func _current_now() -> int:
	if GameLoopScript.instance != null and GameLoopScript.instance.now_unix() > 0:
		return GameLoopScript.instance.now_unix()
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs != null:
		var w = gs.world
		if typeof(w) == TYPE_DICTIONARY and (w as Dictionary).has("sim_now_unix"):
			return int((w as Dictionary)["sim_now_unix"])
	return int(Time.get_unix_time_from_system())


func _update_active_build_info() -> void:
	if active_build_box == null or _current_key.is_empty():
		return

	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null or not gs.has_active_village():
		active_build_box.hide()
		return

	var vid: int = gs.active_village_id
	var active_item: Dictionary = {}
	for item in gs.queues:
		if typeof(item) == TYPE_DICTIONARY and int(item.get("village_id", -1)) == vid and str(item.get("type", "")) == "build" and str(item.get("key", "")) == _current_key:
			active_item = item
			break

	if active_item.is_empty():
		active_build_box.hide()
		return

	active_build_box.show()
	var tgt: int = int(active_item.get("target_level", 1))
	var start: int = int(active_item.get("start_unix", 0))
	var finish: int = int(active_item.get("finish_unix", 0))

	var now := _current_now()

	var total_dur := maxi(1, finish - start)
	var rem := maxi(0, finish - now)

	active_build_icon_lbl.text = "🔨 İnşaat Sürüyor: Seviye %d" % tgt
	active_build_time_lbl.text = "Kalan: %02d:%02d" % [rem / 60, rem % 60]

	var pct := float(total_dur - rem) / float(total_dur) * 100.0
	active_build_progress.value = clampf(pct, 0.0, 100.0)

	var item_id: int = int(active_item.get("id", -1))
	var old_id = active_build_cancel_btn.get_meta("item_id", -1)
	if old_id != item_id:
		active_build_cancel_btn.set_meta("item_id", item_id)
		for conn in active_build_cancel_btn.pressed.get_connections():
			active_build_cancel_btn.pressed.disconnect(conn["callable"])
		active_build_cancel_btn.pressed.connect(_on_active_cancel_pressed.bind(item_id))


func _on_active_cancel_pressed(item_id: int) -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null or not gs.has_active_village():
		return
	var v: Dictionary = gs.get_active_village()
	var state: Dictionary = gs.to_dict()
	var res := EconomyAPI.cancel_build(v, item_id, state)
	if bool(res.get("ok", false)):
		gs.from_dict(state)
		_village = gs.get_active_village()
		var sm = Engine.get_main_loop().root.get_node_or_null("SaveManager") if Engine.get_main_loop() is SceneTree else null
		if sm != null:
			sm.save_game()
		var bus = Engine.get_main_loop().root.get_node_or_null("EventBus") if Engine.get_main_loop() is SceneTree else null
		if bus != null:
			if bus.has_signal("resources_changed"):
				bus.resources_changed.emit(gs.active_village_id)
			if bus.has_signal("state_changed"):
				bus.state_changed.emit()
	refresh()


func refresh() -> void:
	_ensure_nodes()
	if _current_key.is_empty():
		return

	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs != null and gs.has_active_village():
		_village = gs.get_active_village()

	if _village.is_empty():
		return

	var state: Dictionary = gs.to_dict() if gs != null else {}

	var b_data: Dictionary = RulesEngineScript.building_data(_current_key)
	var b_name: String = str(b_data.get("name", _current_key))
	var cur_lvl: int = int(_village.get("buildings", {}).get(_current_key, 0))
	var max_lvl: int = RulesEngineScript._max_level(_current_key)

	var details: Dictionary = EconomyAPI.build_details(_village, _current_key, state)
	var tgt_lvl: int = int(details.get("target_level", cur_lvl + 1))
	var total_cost: Dictionary = details.get("cost", {})
	var extra_pct: int = int(details.get("extra_percent", 0))

	# Bu binaya ait aktif inşaat var mı?
	var vid: int = int(_village.get("id", -1))
	var active_in_queue := false
	var active_tgt := 0
	if gs != null:
		for item in gs.queues:
			if typeof(item) == TYPE_DICTIONARY and int(item.get("village_id", -1)) == vid and str(item.get("type", "")) == "build" and str(item.get("key", "")) == _current_key:
				active_in_queue = true
				active_tgt = int(item.get("target_level", 0))
				break

	title_label.text = b_name
	if cur_lvl >= max_lvl and max_lvl > 0:
		level_label.text = "Seviye: %d / %d (Maksimum)" % [cur_lvl, max_lvl]
	elif active_in_queue:
		level_label.text = "Seviye: %d (İnşaat: Sv. %d ➔ Sıradaki: Sv. %d)" % [cur_lvl, active_tgt, tgt_lvl]
	else:
		level_label.text = "Seviye: %d  (Hedef: %d / %d)" % [cur_lvl, tgt_lvl, max_lvl]

	_update_active_build_info()

	cost_wood.text = str(int(total_cost.get("wood", 0)))
	cost_stone.text = str(int(total_cost.get("stone", 0)))
	cost_iron.text = str(int(total_cost.get("iron", 0)))

	var dur_secs: float = RulesEngineScript.build_seconds(_current_key, tgt_lvl)
	if active_in_queue:
		time_label.text = "Sıradaki İnşa Süresi: %d sn" % int(ceil(dur_secs))
	else:
		time_label.text = "İnşa Süresi: %d sn" % int(ceil(dur_secs))

	if extra_pct > 0:
		extra_cost_label.text = "⚠️ Kuyruk Ek Maliyeti: +%%%d" % extra_pct
		extra_cost_label.show()
	else:
		extra_cost_label.hide()

	# Gereksinim Zinciri Görünümü
	for child in req_container.get_children():
		req_container.remove_child(child)
		child.queue_free()

	var chain: Array = RulesEngineScript.requirement_chain(_village.get("buildings", {}), _current_key, tgt_lvl)
	var is_upgradable: bool = bool(details.get("ok", false))

	if is_upgradable:
		req_section.hide()
		offset_top = -520.0
		upgrade_btn.disabled = false
		if active_in_queue:
			upgrade_btn.text = "Sıraya Ekle (Seviye %d)" % tgt_lvl
		else:
			upgrade_btn.text = "Yükselt (Seviye %d)" % tgt_lvl

		var upg_sb := StyleBoxFlat.new()
		upg_sb.bg_color = Color(0.18, 0.60, 0.30, 1.0)
		upg_sb.border_color = Color(0.55, 0.90, 0.62, 1.0)
		upg_sb.border_width_top = 2
		upg_sb.border_width_bottom = 5
		upg_sb.border_width_left = 2
		upg_sb.border_width_right = 2
		upg_sb.corner_radius_top_left = 16
		upg_sb.corner_radius_top_right = 16
		upg_sb.corner_radius_bottom_right = 16
		upg_sb.corner_radius_bottom_left = 16
		upg_sb.shadow_color = Color(0.04, 0.22, 0.08, 0.45)
		upg_sb.shadow_size = 8
		upg_sb.shadow_offset = Vector2(0, 4)
		upg_sb.content_margin_top = 16
		upg_sb.content_margin_bottom = 16

		var upg_hover := StyleBoxFlat.new()
		upg_hover.bg_color = Color(0.22, 0.70, 0.36, 1.0)
		upg_hover.border_color = Color(0.75, 1.0, 0.80, 1.0)
		upg_hover.border_width_top = 2
		upg_hover.border_width_bottom = 5
		upg_hover.border_width_left = 2
		upg_hover.border_width_right = 2
		upg_hover.corner_radius_top_left = 16
		upg_hover.corner_radius_top_right = 16
		upg_hover.corner_radius_bottom_right = 16
		upg_hover.corner_radius_bottom_left = 16
		upg_hover.shadow_color = Color(0.06, 0.32, 0.12, 0.55)
		upg_hover.shadow_size = 12
		upg_hover.shadow_offset = Vector2(0, 4)
		upg_hover.content_margin_top = 16
		upg_hover.content_margin_bottom = 16

		upgrade_btn.add_theme_stylebox_override("normal", upg_sb)
		upgrade_btn.add_theme_stylebox_override("hover", upg_hover)
		upgrade_btn.add_theme_stylebox_override("pressed", upg_sb)
		upgrade_btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		upgrade_btn.add_theme_color_override("font_shadow_color", Color(0.04, 0.20, 0.08, 0.9))
		upgrade_btn.add_theme_constant_override("shadow_offset_y", 2)
	else:
		upgrade_btn.disabled = true
		var dis_sb := StyleBoxFlat.new()
		dis_sb.bg_color = Color(0.20, 0.19, 0.23, 0.95)
		dis_sb.border_color = Color(0.40, 0.38, 0.44, 0.70)
		dis_sb.border_width_top = 1
		dis_sb.border_width_bottom = 4
		dis_sb.border_width_left = 1
		dis_sb.border_width_right = 1
		dis_sb.corner_radius_top_left = 16
		dis_sb.corner_radius_top_right = 16
		dis_sb.corner_radius_bottom_right = 16
		dis_sb.corner_radius_bottom_left = 16
		dis_sb.content_margin_top = 16
		dis_sb.content_margin_bottom = 16

		upgrade_btn.add_theme_stylebox_override("normal", dis_sb)
		upgrade_btn.add_theme_stylebox_override("disabled", dis_sb)
		upgrade_btn.add_theme_color_override("font_color", Color(0.70, 0.68, 0.64))
		upgrade_btn.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.6))
		upgrade_btn.add_theme_constant_override("shadow_offset_y", 1)

		var reason: String = str(details.get("reason", ""))
		if reason == "max_level":
			upgrade_btn.text = "Maksimum Seviyeye Ulaşıldı"
			req_section.hide()
			offset_top = -520.0
		elif reason == "requirements" or reason == "locked":
			upgrade_btn.text = "Önkoşullar Karşılanmadı"
			req_section.show()
			offset_top = -880.0
			_populate_chain_list(chain)
		elif reason == "resources":
			upgrade_btn.text = "Yetersiz Hammadde"
			if details.get("missing", []).size() > 0:
				req_section.show()
				offset_top = -880.0
				_populate_chain_list(chain)
			else:
				req_section.hide()
				offset_top = -520.0
		elif reason == "citizens":
			upgrade_btn.text = "Yetersiz Vatandaş (Değirmen Gerek)"
			req_section.hide()
			offset_top = -520.0
		else:
			upgrade_btn.text = "Yükseltilemez"
			req_section.hide()
			offset_top = -520.0


func _populate_chain_list(chain: Array) -> void:
	for node in chain:
		if typeof(node) != TYPE_DICTIONARY:
			continue
		var req_dict: Dictionary = node
		var req_key: String = str(req_dict.get("key", ""))
		if req_key == _current_key:
			continue  # Kendisini listeleme

		var req_tgt: int = int(req_dict.get("level", 1))
		var req_cur: int = int(req_dict.get("current", 0))

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var req_b_data: Dictionary = RulesEngineScript.building_data(req_key)
		var req_name: String = str(req_b_data.get("name", req_key))

		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.text = "• %s (Gereken: %d, Şu an: %d)" % [req_name, req_tgt, req_cur]
		lbl.add_theme_font_size_override("font_size", 18)
		if req_cur >= req_tgt:
			lbl.add_theme_color_override("font_color", Color(0.48, 0.85, 0.58, 1)) # Pastel yeşil
		else:
			lbl.add_theme_color_override("font_color", Color(0.96, 0.55, 0.48, 1)) # Pastel mercan
		row.add_child(lbl)

		var goto_btn := Button.new()
		goto_btn.text = "Binaya Git ➔"
		goto_btn.custom_minimum_size = Vector2(150, 48)
		goto_btn.add_theme_font_size_override("font_size", 16)

		var btn_sb := StyleBoxFlat.new()
		btn_sb.bg_color = Color(0.85, 0.70, 0.38, 0.22)
		btn_sb.border_color = Color(0.92, 0.80, 0.45, 0.90)
		btn_sb.set_border_width_all(1)
		btn_sb.set_corner_radius_all(12)
		btn_sb.content_margin_left = 12
		btn_sb.content_margin_right = 12
		goto_btn.add_theme_stylebox_override("normal", btn_sb)
		goto_btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75))

		var btn_hover := StyleBoxFlat.new()
		btn_hover.bg_color = Color(0.85, 0.70, 0.38, 0.40)
		btn_hover.border_color = Color(1.0, 0.88, 0.55, 1.0)
		btn_hover.set_border_width_all(2)
		btn_hover.set_corner_radius_all(12)
		goto_btn.add_theme_stylebox_override("hover", btn_hover)
		goto_btn.add_theme_stylebox_override("pressed", btn_hover)

		goto_btn.pressed.connect(_on_goto_building.bind(req_key))
		row.add_child(goto_btn)

		req_container.add_child(row)


func _on_goto_building(target_key: String) -> void:
	_current_key = target_key
	refresh()
	building_switched.emit(target_key)


func _on_upgrade_pressed() -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null or not gs.has_active_village():
		return

	var vid: int = gs.active_village_id
	var state: Dictionary = gs.to_dict()

	var st_village: Dictionary = {}
	for sv in state.get("villages", []):
		if int(sv.get("id", -1)) == vid:
			st_village = sv
			break
	if st_village.is_empty():
		st_village = _village

	var res := EconomyAPI.start_build(st_village, _current_key, state)
	if bool(res.get("ok", false)):
		gs.from_dict(state)
		_village = gs.get_active_village()

		var sm = Engine.get_main_loop().root.get_node_or_null("SaveManager") if Engine.get_main_loop() is SceneTree else null
		if sm != null:
			sm.save_game()

		var bus = Engine.get_main_loop().root.get_node_or_null("EventBus") if Engine.get_main_loop() is SceneTree else null
		if bus != null:
			if bus.has_signal("building_started"):
				bus.building_started.emit(vid, _current_key, int(res.get("target_level", 0)))
			if bus.has_signal("resources_changed"):
				bus.resources_changed.emit(vid)
			if bus.has_signal("state_changed"):
				bus.state_changed.emit()

	refresh()
