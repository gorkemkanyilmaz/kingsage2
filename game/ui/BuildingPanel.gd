extends PanelContainer
## BuildingPanel — Bina detay ve gereksinim zinciri paneli (A-ARAYUZ).

signal building_switched(building_key: String)
signal closed()

const RulesEngineScript := preload("res://scripts/rules/RulesEngine.gd")
const EconomyAPI := preload("res://scripts/sim/economy/EconomyAPI.gd")
const Palette := preload("res://themes/Palette.gd")

var _current_key: String = ""
var _village: Dictionary = {}

@onready var title_label: Label = $VBox/Header/TitleLabel
@onready var level_label: Label = $VBox/Header/LevelLabel
@onready var close_btn: Button = $VBox/Header/CloseButton

@onready var cost_wood: Label = $VBox/CostContainer/WoodBox/Label
@onready var cost_stone: Label = $VBox/CostContainer/StoneBox/Label
@onready var cost_iron: Label = $VBox/CostContainer/IronBox/Label
@onready var time_label: Label = $VBox/MetaContainer/TimeLabel
@onready var extra_cost_label: Label = $VBox/MetaContainer/ExtraCostLabel

@onready var upgrade_btn: Button = $VBox/UpgradeButton
@onready var req_container: VBoxContainer = $VBox/RequirementSection/ReqList
@onready var req_section: VBoxContainer = $VBox/RequirementSection


func _ready() -> void:
	close_btn.pressed.connect(func():
		hide()
		closed.emit())
	upgrade_btn.pressed.connect(_on_upgrade_pressed)


func show_building(village: Dictionary, key: String) -> void:
	_village = village
	_current_key = key
	refresh()
	show()


func refresh() -> void:
	if _current_key.is_empty() or _village.is_empty():
		return

	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	var state: Dictionary = gs.to_dict() if gs != null else {}

	var b_data: Dictionary = RulesEngineScript.building_data(_current_key)
	var b_name: String = str(b_data.get("name", _current_key))
	var cur_lvl: int = int(_village.get("buildings", {}).get(_current_key, 0))
	var tgt_lvl: int = cur_lvl + 1

	title_label.text = b_name
	level_label.text = "Seviye: %d  (Hedef: %d)" % [cur_lvl, tgt_lvl]

	var details: Dictionary = EconomyAPI.build_details(_village, _current_key, state)
	var base_cost: Dictionary = details.get("base_cost", {})
	var total_cost: Dictionary = details.get("cost", {})
	var extra_pct: int = int(details.get("extra_percent", 0))

	cost_wood.text = str(int(total_cost.get("wood", 0)))
	cost_stone.text = str(int(total_cost.get("stone", 0)))
	cost_iron.text = str(int(total_cost.get("iron", 0)))

	var dur_secs: float = RulesEngineScript.build_seconds(_current_key, tgt_lvl)
	time_label.text = "İnşa Süresi: %d sn" % int(ceil(dur_secs))

	if extra_pct > 0:
		extra_cost_label.text = "⚠️ Kuyruk Ek Maliyeti: +%%%d" % extra_pct
		extra_cost_label.show()
	else:
		extra_cost_label.hide()

	# Gereksinim Zinciri Görünümü
	for child in req_container.get_children():
		child.queue_free()

	var chain: Array = RulesEngineScript.requirement_chain(_village.get("buildings", {}), _current_key, tgt_lvl)
	var is_upgradable: bool = bool(details.get("ok", false))

	if is_upgradable:
		req_section.hide()
		upgrade_btn.disabled = false
		upgrade_btn.text = "Yükselt (Seviye %d)" % tgt_lvl
	else:
		upgrade_btn.disabled = true
		var reason: String = str(details.get("reason", ""))
		if reason == "resources":
			upgrade_btn.text = "Yetersiz Hammadde"
			req_section.hide()
		elif reason == "citizens":
			upgrade_btn.text = "Yetersiz Vatandaş (Değirmen Gerek)"
			req_section.hide()
		elif reason == "requirements" or reason == "locked":
			upgrade_btn.text = "Önkoşullar Karşılanmadı"
			req_section.show()
			_populate_chain_list(chain)
		else:
			upgrade_btn.text = "Yükseltilemez"
			req_section.hide()


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
		var req_b_data: Dictionary = RulesEngineScript.building_data(req_key)
		var req_name: String = str(req_b_data.get("name", req_key))

		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.text = "• %s (Gereken: %d, Şu an: %d)" % [req_name, req_tgt, req_cur]
		if req_cur >= req_tgt:
			lbl.modulate = Palette.c("basari")
		else:
			lbl.modulate = Palette.c("hata")
		row.add_child(lbl)

		var goto_btn := Button.new()
		goto_btn.text = "Binaya Git ➔"
		goto_btn.custom_minimum_size = Vector2(140, 48)
		goto_btn.pressed.connect(func():
			_current_key = req_key
			refresh()
			building_switched.emit(req_key))
		row.add_child(goto_btn)

		req_container.add_child(row)


func _on_upgrade_pressed() -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	var state: Dictionary = gs.to_dict() if gs != null else {}

	var res := EconomyAPI.start_build(_village, _current_key, state)
	if bool(res.get("ok", false)) and gs != null:
		gs.from_dict(state)
		if gs.has_active_village():
			_village = gs.get_active_village()
	refresh()
