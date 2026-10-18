extends PanelContainer
## SendTroopsPanel — Birlik gönderme ve sefer paneli (A-ARAYUZ).

signal movement_dispatched(type: String, target_id: int)
signal closed()

const MovementScript := preload("res://scripts/sim/actions/Movement.gd")
const RulesEngineScript := preload("res://scripts/rules/RulesEngine.gd")
const TravelScript := preload("res://scripts/world/Travel.gd")
const Palette := preload("res://themes/Palette.gd")

var _from_village: Dictionary = {}
var _to_village: Dictionary = {}
var _unit_inputs: Dictionary = {}

@onready var title_label: Label = $VBox/Header/TitleLabel
@onready var target_info_label: Label = $VBox/TargetInfo
@onready var close_btn: Button = $VBox/Header/CloseButton
@onready var unit_container: VBoxContainer = $VBox/Scroll/UnitContainer
@onready var warning_label: Label = $VBox/WarningLabel
@onready var btn_attack: Button = $VBox/ActionButtons/BtnAttack
@onready var btn_raid: Button = $VBox/ActionButtons/BtnRaid


func _ready() -> void:
	close_btn.pressed.connect(func():
		hide()
		closed.emit())
	btn_attack.pressed.connect(func(): _dispatch(MovementScript.TYPE_ATTACK))
	btn_raid.pressed.connect(func(): _dispatch(MovementScript.TYPE_RAID))


func show_target(from_v: Dictionary, to_v: Dictionary) -> void:
	_from_village = from_v
	_to_village = to_v
	_populate_units()
	refresh()
	show()


func _populate_units() -> void:
	for child in unit_container.get_children():
		child.queue_free()
	_unit_inputs.clear()

	var available: Dictionary = _from_village.get("units", {})
	for u_key in ["farmer", "spear", "sword", "axe", "bow", "spy", "light", "heavy", "ram", "kata", "snob"]:
		var have: int = int(available.get(u_key, 0))
		var u_data: Dictionary = RulesEngineScript.unit_data(u_key)
		var u_name: String = str(u_data.get("name", u_key))

		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = "%s (Mevcut: %d)" % [u_name, have]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)

		var spin := SpinBox.new()
		spin.min_value = 0
		spin.max_value = have
		spin.value = 0
		spin.custom_minimum_size = Vector2(160, 48)
		spin.value_changed.connect(func(_val): refresh())
		row.add_child(spin)

		_unit_inputs[u_key] = spin
		unit_container.add_child(row)


func refresh() -> void:
	var from_x := int(_from_village.get("x", 0))
	var from_y := int(_from_village.get("y", 0))
	var to_x := int(_to_village.get("x", 0))
	var to_y := int(_to_village.get("y", 0))
	var dist := TravelScript.distance(from_x, from_y, to_x, to_y)

	target_info_label.text = "Hedef: %s (%d|%d) — Mesafe: %.1f alan" % [
		str(_to_village.get("name", "Köy")), to_x, to_y, dist
	]

	var selected_units: Dictionary = {}
	var total_selected := 0
	for u_key in _unit_inputs.keys():
		var count: int = int(_unit_inputs[u_key].value)
		if count > 0:
			selected_units[u_key] = count
			total_selected += count

	var barracks_lvl: int = int(_from_village.get("buildings", {}).get("barracks", 0))
	var min_units: int = RulesEngineScript.min_attack_units(barracks_lvl)

	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	var state: Dictionary = gs.to_dict() if gs != null else {}
	var now := int(Time.get_unix_time_from_system())

	var check: Dictionary = MovementScript.can_send(state, int(_from_village.get("id", -1)), int(_to_village.get("id", -1)), MovementScript.TYPE_ATTACK, selected_units, {}, now)

	if not bool(check.get("ok", false)):
		var code: String = str(check.get("code", ""))
		btn_attack.disabled = true
		btn_raid.disabled = true
		warning_label.show()
		if code == "min_units":
			warning_label.text = "⚠️ Asgari ordu şartı: En az %d birim seçmelisiniz (3 × Kışla)." % min_units
		elif code == "count_too_far":
			warning_label.text = "⚠️ Kont menzil dışı! Hedef 80 alandan uzak olamaz."
		elif code == "target_protected":
			warning_label.text = "⚠️ Hedef köy koruma altında."
		elif code == "units_empty":
			warning_label.text = "Sefer için birlik seçiniz."
		else:
			warning_label.text = "Uyarı: " + str(check.get("message", "Geçersiz gönderim"))
	else:
		warning_label.hide()
		btn_attack.disabled = false
		btn_raid.disabled = false


func _dispatch(type: String) -> void:
	var selected_units: Dictionary = {}
	for u_key in _unit_inputs.keys():
		var count: int = int(_unit_inputs[u_key].value)
		if count > 0:
			selected_units[u_key] = count

	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	var state: Dictionary = gs.to_dict() if gs != null else {}
	var now := int(Time.get_unix_time_from_system())

	var res: Dictionary = {}
	if type == MovementScript.TYPE_RAID:
		res = MovementScript.send_raid(state, int(_from_village["id"]), int(_to_village["id"]), selected_units, now)
	else:
		res = MovementScript.send_attack(state, int(_from_village["id"]), int(_to_village["id"]), selected_units, now)

	if bool(res.get("ok", false)) and gs != null:
		gs.from_dict(state)
		movement_dispatched.emit(type, int(_to_village["id"]))
		hide()
