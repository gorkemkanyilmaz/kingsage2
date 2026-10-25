extends PanelContainer
## SendTroopsPanel — Birlik ve Hammadde Sevk Paneli (Taht ve Kılıç / A-ARAYUZ).

signal movement_dispatched(type: String, target_id: int)
signal closed()

const MovementScript := preload("res://scripts/sim/actions/Movement.gd")
const RulesEngineScript := preload("res://scripts/rules/RulesEngine.gd")
const TravelScript := preload("res://scripts/world/Travel.gd")
const FontNunitoBold := preload("res://assets/fonts/Nunito-Bold.ttf")

var _from_village: Dictionary = {}
var _to_village: Dictionary = {}
var _unit_inputs: Dictionary = {}
var _resource_inputs: Dictionary = {}
var _current_tab: String = "troops" # "troops" | "trade"

@onready var title_label: Label = $VBox/Header/TitleLabel
@onready var close_btn: Button = $VBox/Header/CloseButton

# Hedef Köy Bilgileri
@onready var target_header_label: Label = $VBox/TargetCard/TargetDetailsVBox/TargetHeaderLabel
@onready var owner_label: Label = $VBox/TargetCard/TargetDetailsVBox/TargetSubGrid/OwnerLabel
@onready var alliance_label: Label = $VBox/TargetCard/TargetDetailsVBox/TargetSubGrid/AllianceLabel
@onready var points_label: Label = $VBox/TargetCard/TargetDetailsVBox/TargetSubGrid/PointsLabel
@onready var distance_label: Label = $VBox/TargetCard/TargetDetailsVBox/TargetSubGrid/DistanceLabel
@onready var target_info_label: Label = $VBox/TargetInfo

# Sekme / Geçiş Butonu
@onready var btn_tab_trade: Button = $VBox/ModeTabs/BtnTabTrade

# Birlik Bölümü
@onready var scroll_troops: ScrollContainer = $VBox/Scroll
@onready var unit_container: VBoxContainer = $VBox/Scroll/UnitContainer

# Ticaret Bölümü
@onready var trade_container: VBoxContainer = $VBox/TradeContainer
@onready var wood_row: HBoxContainer = $VBox/TradeContainer/WoodRow
@onready var stone_row: HBoxContainer = $VBox/TradeContainer/StoneRow
@onready var iron_row: HBoxContainer = $VBox/TradeContainer/IronRow

# Zaman & Uyarı
@onready var estimate_label: Label = $VBox/EstimateCard/EstimateLabel
@onready var warning_label: Label = $VBox/WarningLabel

# Aksiyon Butonları
@onready var action_buttons_box: HBoxContainer = $VBox/ActionButtons
@onready var btn_raid: Button = $VBox/ActionButtons/BtnRaid
@onready var btn_attack: Button = $VBox/ActionButtons/BtnAttack
@onready var btn_trade: Button = $VBox/ActionButtons/BtnTrade


func _ready() -> void:
	close_btn.pressed.connect(func():
		hide()
		closed.emit()
	)
	btn_attack.pressed.connect(func(): _dispatch(MovementScript.TYPE_ATTACK))
	btn_raid.pressed.connect(func(): _dispatch(MovementScript.TYPE_RAID))
	btn_trade.pressed.connect(func(): _dispatch(MovementScript.TYPE_TRADE))

	btn_tab_trade.pressed.connect(func():
		if _current_tab == "troops":
			_switch_tab("trade")
		else:
			_switch_tab("troops")
	)

	_setup_fonts_and_styles()


func _style_spinbox(spin: SpinBox) -> void:
	var le := spin.get_line_edit()
	if le != null:
		le.alignment = HORIZONTAL_ALIGNMENT_CENTER
		le.add_theme_font_override("font", FontNunitoBold)
		le.add_theme_font_size_override("font_size", 24)
		le.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
		var sb_box := StyleBoxFlat.new()
		sb_box.bg_color = Color(0.14, 0.12, 0.18, 0.95)
		sb_box.border_color = Color(0.85, 0.72, 0.42, 0.85)
		sb_box.set_border_width_all(2)
		sb_box.set_corner_radius_all(10)
		le.add_theme_stylebox_override("normal", sb_box)
		le.add_theme_stylebox_override("focus", sb_box)


func _style_all_button(btn: Button) -> void:
	btn.add_theme_font_override("font", FontNunitoBold)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color(0.18, 0.12, 0.05))
	var b_sb := StyleBoxFlat.new()
	b_sb.bg_color = Color(0.92, 0.78, 0.44, 1.0)
	b_sb.border_color = Color(0.40, 0.30, 0.14, 0.95)
	b_sb.set_border_width_all(2)
	b_sb.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", b_sb)
	btn.add_theme_stylebox_override("hover", b_sb)
	btn.add_theme_stylebox_override("pressed", b_sb)


func _style_action_button(btn: Button) -> void:
	if btn == null:
		return
	btn.add_theme_font_override("font", FontNunitoBold)
	btn.add_theme_font_size_override("font_size", 24)
	btn.remove_theme_constant_override("outline_size")
	btn.remove_theme_color_override("font_outline_color")
	btn.add_theme_color_override("font_color", Color(0.20, 0.14, 0.08, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(0.12, 0.08, 0.04, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.12, 0.08, 0.04, 1.0))
	btn.add_theme_color_override("font_focus_color", Color(0.20, 0.14, 0.08, 1.0))
	btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.52, 0.48, 1.0))

	var sb_norm := StyleBoxFlat.new()
	sb_norm.bg_color = Color(0.949, 0.894, 0.784, 1.0)
	sb_norm.border_color = Color(0.604, 0.392, 0.216, 1.0)
	sb_norm.set_border_width_all(2)
	sb_norm.border_width_bottom = 3
	sb_norm.set_corner_radius_all(12)
	sb_norm.content_margin_left = 18.0
	sb_norm.content_margin_right = 18.0
	sb_norm.content_margin_top = 10.0
	sb_norm.content_margin_bottom = 10.0
	sb_norm.shadow_color = Color(0.3, 0.2, 0.1, 0.3)
	sb_norm.shadow_size = 4
	sb_norm.shadow_offset = Vector2(0, 2)

	var sb_hover := sb_norm.duplicate() as StyleBoxFlat
	sb_hover.bg_color = Color(0.984, 0.914, 0.788, 1.0)
	sb_hover.border_color = Color(0.70, 0.45, 0.25, 1.0)

	var sb_pressed := sb_norm.duplicate() as StyleBoxFlat
	sb_pressed.bg_color = Color(0.902, 0.824, 0.682, 1.0)
	sb_pressed.border_width_top = 3
	sb_pressed.border_width_bottom = 2

	var sb_disabled := sb_norm.duplicate() as StyleBoxFlat
	sb_disabled.bg_color = Color(0.851, 0.878, 0.918, 0.85)
	sb_disabled.border_color = Color(0.725, 0.749, 0.800, 0.85)

	btn.add_theme_stylebox_override("normal", sb_norm)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	btn.add_theme_stylebox_override("focus", sb_hover)
	btn.add_theme_stylebox_override("disabled", sb_disabled)


func _setup_fonts_and_styles() -> void:
	title_label.add_theme_font_override("font", FontNunitoBold)
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.add_theme_constant_override("outline_size", 3)
	title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.98))
	title_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.80))

	target_header_label.add_theme_font_override("font", FontNunitoBold)
	target_header_label.add_theme_font_size_override("font_size", 28)
	target_header_label.add_theme_constant_override("outline_size", 4)
	target_header_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
	target_header_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	target_header_label.add_theme_constant_override("shadow_offset_y", 2)
	target_header_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))

	owner_label.add_theme_font_override("font", FontNunitoBold)
	owner_label.add_theme_font_size_override("font_size", 24)
	owner_label.add_theme_constant_override("outline_size", 3)
	owner_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
	owner_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	owner_label.add_theme_constant_override("shadow_offset_y", 2)
	owner_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))

	alliance_label.add_theme_font_override("font", FontNunitoBold)
	alliance_label.add_theme_font_size_override("font_size", 24)
	alliance_label.add_theme_constant_override("outline_size", 3)
	alliance_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
	alliance_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	alliance_label.add_theme_constant_override("shadow_offset_y", 2)
	alliance_label.add_theme_color_override("font_color", Color(0.70, 0.88, 1.0))

	points_label.add_theme_font_override("font", FontNunitoBold)
	points_label.add_theme_font_size_override("font_size", 24)
	points_label.add_theme_constant_override("outline_size", 3)
	points_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
	points_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	points_label.add_theme_constant_override("shadow_offset_y", 2)
	points_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))

	distance_label.add_theme_font_override("font", FontNunitoBold)
	distance_label.add_theme_font_size_override("font_size", 24)
	distance_label.add_theme_constant_override("outline_size", 3)
	distance_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
	distance_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	distance_label.add_theme_constant_override("shadow_offset_y", 2)
	distance_label.add_theme_color_override("font_color", Color(0.55, 0.95, 0.65))

	estimate_label.add_theme_font_override("font", FontNunitoBold)
	estimate_label.add_theme_font_size_override("font_size", 24)
	estimate_label.add_theme_constant_override("outline_size", 4)
	estimate_label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 1.0))
	estimate_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	estimate_label.add_theme_constant_override("shadow_offset_y", 2)
	estimate_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.78, 1.0))

	warning_label.add_theme_font_override("font", FontNunitoBold)
	warning_label.add_theme_font_size_override("font_size", 24)
	warning_label.add_theme_constant_override("outline_size", 3)
	warning_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.98))
	warning_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.35))

	for btn in [btn_raid, btn_attack, btn_trade, btn_tab_trade]:
		_style_action_button(btn)


func show_target(from_v: Dictionary, to_v: Dictionary) -> void:
	_from_village = from_v
	_to_village = to_v
	_populate_target_info()
	_populate_units()
	_populate_resources()
	_switch_tab("troops")
	refresh()
	show()


func _populate_target_info() -> void:
	var to_name: String = str(_to_village.get("name", "Köy"))
	var to_x: int = int(_to_village.get("x", 0))
	var to_y: int = int(_to_village.get("y", 0))
	var from_x: int = int(_from_village.get("x", 0))
	var from_y: int = int(_from_village.get("y", 0))
	var dist: float = TravelScript.distance(from_x, from_y, to_x, to_y)

	target_header_label.text = " %s (%d|%d)" % [to_name, to_x, to_y]
	target_info_label.text = "Hedef: %s (%d|%d) — Mesafe: %.1f alan" % [to_name, to_x, to_y, dist]

	var owner_name: String = str(_to_village.get("owner", ""))
	if owner_name.is_empty():
		owner_name = "Düşman"
	owner_label.text = " Sahip: %s" % owner_name

	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	var state: Dictionary = gs.to_dict() if gs != null else {}
	var from_owner := str(_from_village.get("owner", gs.player.get("name", "Lord Gorkem") if gs != null else ""))
	var is_ally: bool = MovementScript._share_alliance(state, from_owner, owner_name)

	var alliance_name: String = str(_to_village.get("alliance", ""))
	if alliance_name.is_empty() and gs != null:
		for a in state.get("alliances", []):
			if typeof(a) == TYPE_DICTIONARY:
				for m in (a as Dictionary).get("members", []):
					var m_name: String = str(m) if typeof(m) == TYPE_STRING else str((m as Dictionary).get("name", ""))
					if m_name == owner_name:
						alliance_name = "[%s] %s" % [str((a as Dictionary).get("tag", "")), str((a as Dictionary).get("name", ""))]
						break
	if alliance_name.is_empty():
		alliance_name = "İttifak Yok"

	if is_ally:
		alliance_label.text = "️ İttifak: %s (Müttefik)" % alliance_name
		alliance_label.add_theme_color_override("font_color", Color(0.40, 0.85, 1.0))
	else:
		alliance_label.text = "️ İttifak: %s" % alliance_name
		alliance_label.remove_theme_color_override("font_color")

	var points: int = int(_to_village.get("points", 0))
	points_label.text = " Puan: %d" % points

	distance_label.text = " Mesafe: %.1f alan" % dist


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
		row.add_theme_constant_override("separation", 14)

		var lbl := Label.new()
		lbl.text = "%s (Mevcut: %d)" % [u_name, have]
		lbl.add_theme_font_override("font", FontNunitoBold)
		lbl.add_theme_font_size_override("font_size", 24)
		lbl.add_theme_constant_override("outline_size", 3)
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.98))
		lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
		lbl.add_theme_constant_override("shadow_offset_y", 2)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.86) if have > 0 else Color(0.85, 0.82, 0.76))
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)

		var spin := SpinBox.new()
		spin.min_value = 0
		spin.max_value = have
		spin.value = 0
		spin.custom_minimum_size = Vector2(150, 52)
		_style_spinbox(spin)
		spin.value_changed.connect(func(_val): refresh())
		row.add_child(spin)

		var btn_all := Button.new()
		btn_all.text = "Tümü"
		btn_all.custom_minimum_size = Vector2(90, 52)
		_style_all_button(btn_all)
		btn_all.pressed.connect(func():
			spin.value = have
			refresh()
		)
		row.add_child(btn_all)

		_unit_inputs[u_key] = spin
		unit_container.add_child(row)


func _populate_resources() -> void:
	for row in [wood_row, stone_row, iron_row]:
		for child in row.get_children():
			child.queue_free()
	_resource_inputs.clear()

	var res_data := [
		{"key": "wood", "name": " Odun", "row": wood_row, "color": Color(0.48, 0.95, 0.52)},
		{"key": "stone", "name": " Taş", "row": stone_row, "color": Color(0.95, 0.90, 0.85)},
		{"key": "iron", "name": "️ Demir", "row": iron_row, "color": Color(0.65, 0.88, 1.0)},
	]

	var res_dict: Dictionary = _from_village.get("resources", {})
	for item in res_data:
		var r_key: String = item["key"]
		var r_name: String = item["name"]
		var r_row: HBoxContainer = item["row"]
		var have: int = int(res_dict.get(r_key, 0))

		var lbl := Label.new()
		lbl.text = "%s (Mevcut: %d)" % [r_name, have]
		lbl.add_theme_font_override("font", FontNunitoBold)
		lbl.add_theme_font_size_override("font_size", 24)
		lbl.add_theme_constant_override("outline_size", 3)
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.98))
		lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
		lbl.add_theme_constant_override("shadow_offset_y", 2)
		lbl.add_theme_color_override("font_color", item["color"])
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r_row.add_child(lbl)

		var spin := SpinBox.new()
		spin.min_value = 0
		spin.max_value = have
		spin.value = 0
		spin.step = 50.0
		spin.custom_minimum_size = Vector2(160, 52)
		_style_spinbox(spin)
		spin.value_changed.connect(func(_val): refresh())
		r_row.add_child(spin)

		var btn_all := Button.new()
		btn_all.text = "Tümü"
		btn_all.custom_minimum_size = Vector2(90, 52)
		_style_all_button(btn_all)
		btn_all.pressed.connect(func():
			spin.value = have
			refresh()
		)
		r_row.add_child(btn_all)

		_resource_inputs[r_key] = spin


func _switch_tab(tab: String) -> void:
	_current_tab = tab
	if tab == "troops":
		scroll_troops.show()
		trade_container.hide()
		btn_raid.hide()
		btn_attack.show()
		btn_trade.hide()
		btn_tab_trade.text = " Hammadde Gönder (Katır)"
	else:
		scroll_troops.hide()
		trade_container.show()
		btn_raid.hide()
		btn_attack.hide()
		btn_trade.show()
		btn_tab_trade.text = "️ Birlik Gönder (Saldırı)"
	refresh()


func refresh() -> void:
	var from_x := int(_from_village.get("x", 0))
	var from_y := int(_from_village.get("y", 0))
	var to_x := int(_to_village.get("x", 0))
	var to_y := int(_to_village.get("y", 0))
	var dist := TravelScript.distance(from_x, from_y, to_x, to_y)

	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	var state: Dictionary = gs.to_dict() if gs != null else {}
	var now := int(Time.get_unix_time_from_system())

	if _current_tab == "troops":
		_refresh_troops_mode(state, from_x, from_y, to_x, to_y, dist, now)
	else:
		_refresh_trade_mode(state, from_x, from_y, to_x, to_y, dist, now)


func _refresh_troops_mode(state: Dictionary, from_x: int, from_y: int, to_x: int, to_y: int, dist: float, now: int) -> void:
	var selected_units: Dictionary = {}
	var total_selected := 0
	for u_key in _unit_inputs.keys():
		var count: int = int(_unit_inputs[u_key].value)
		if count > 0:
			selected_units[u_key] = count
			total_selected += count

	# Zaman Tahmini (En Yavaş Birim Kuralı)
	if total_selected > 0:
		var slowest_speed: float = TravelScript.slowest_speed(selected_units)
		var slowest_key: String = TravelScript.slowest_unit(selected_units)
		var slowest_name: String = str(RulesEngineScript.unit_data(slowest_key).get("name", slowest_key))
		var travel_secs: float = TravelScript.travel_seconds(from_x, from_y, to_x, to_y, slowest_speed)
		var arrive_unix: int = now + int(travel_secs)

		var mm := int(travel_secs / 60.0)
		var ss := int(travel_secs) % 60
		var dt := Time.get_time_dict_from_unix_time(arrive_unix)

		estimate_label.text = "⏱️ En Yavaş Birim: %s (%.1f dk/alan)  |  ⏳ Yolculuk: %02d:%02d  |   Varış: %02d:%02d:%02d" % [
			slowest_name, slowest_speed, mm, ss, dt["hour"], dt["minute"], dt["second"]
		]
	else:
		estimate_label.text = "⏱️ En Yavaş Birim: —  |  ⏳ Yolculuk Süresi: 00:00  |   Varış Saati: --:--:--"

	var barracks_lvl: int = int(_from_village.get("buildings", {}).get("barracks", 0))
	var min_units: int = RulesEngineScript.min_attack_units(barracks_lvl)

	var is_only_spies: bool = total_selected > 0 and int(selected_units.get("spy", 0)) == total_selected
	var check_type: String = MovementScript.TYPE_SPY if is_only_spies else MovementScript.TYPE_ATTACK
	btn_attack.text = "️ Casus Gönder" if is_only_spies else "️ Saldır"

	var check: Dictionary = MovementScript.can_send(state, int(_from_village.get("id", -1)), int(_to_village.get("id", -1)), check_type, selected_units, {}, now)

	if not bool(check.get("ok", false)):
		var code: String = str(check.get("code", ""))
		btn_attack.disabled = true
		btn_raid.disabled = true
		warning_label.show()
		if code == "min_units":
			warning_label.text = "️ Asgari ordu şartı: En az %d birim seçmelisiniz (3 × Kışla)." % min_units
		elif code == "count_too_far":
			warning_label.text = "️ Kont menzil dışı! Hedef 80 alandan uzak olamaz."
		elif code == "target_protected":
			warning_label.text = "️ Hedef köy koruma altında."
		elif code == "friendly_target":
			warning_label.text = "️ İttifak Kuralı: Kendi veya ittifak üyesi köylere saldıramazsınız!"
		elif code == "units_empty":
			warning_label.text = "Sefer için birlik seçiniz."
		else:
			warning_label.text = "Uyarı: " + str(check.get("message", "Geçersiz gönderim"))
	else:
		warning_label.hide()
		btn_attack.disabled = false
		btn_raid.disabled = false


func _refresh_trade_mode(state: Dictionary, from_x: int, from_y: int, to_x: int, to_y: int, dist: float, now: int) -> void:
	var carry: Dictionary = {}
	var total_res := 0
	for r_key in _resource_inputs.keys():
		var val: int = int(_resource_inputs[r_key].value)
		if val > 0:
			carry[r_key] = val
			total_res += val

	var donkey_speed: float = MovementScript.DONKEY_MINUTES_PER_FIELD # 2.0 dk/alan
	var travel_secs: float = TravelScript.travel_seconds(from_x, from_y, to_x, to_y, donkey_speed)
	var arrive_unix: int = now + int(travel_secs)
	var mm := int(travel_secs / 60.0)
	var ss := int(travel_secs) % 60
	var dt := Time.get_time_dict_from_unix_time(arrive_unix)

	estimate_label.text = " Katır Hızı: %.1f dk/alan  |  ⏳ Yolculuk: %02d:%02d  |   Varış: %02d:%02d:%02d" % [
		donkey_speed, mm, ss, dt["hour"], dt["minute"], dt["second"]
	]

	if total_res <= 0:
		warning_label.show()
		warning_label.text = "Sevk edilecek hammadde miktarını giriniz."
		btn_trade.disabled = true
		return

	var check: Dictionary = MovementScript.can_send(state, int(_from_village.get("id", -1)), int(_to_village.get("id", -1)), MovementScript.TYPE_TRADE, {}, carry, now)

	if not bool(check.get("ok", false)):
		warning_label.show()
		var code: String = str(check.get("code", ""))
		if code == "foreign_target":
			warning_label.text = "️ Ticaret yalnız kendi köylerinize veya müttefiklere yapılabilir."
		elif code == "market_required":
			warning_label.text = "️ Ticaret için Market binası (en az Sv. 1) gereklidir."
		else:
			warning_label.text = "Uyarı: " + str(check.get("message", "Geçersiz hammadde sevki"))
		btn_trade.disabled = true
	else:
		warning_label.hide()
		btn_trade.disabled = false


func _dispatch(type: String) -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	var state: Dictionary = gs.to_dict() if gs != null else {}
	var now := int(Time.get_unix_time_from_system())
	var res: Dictionary = {}

	if type == MovementScript.TYPE_TRADE:
		var carry: Dictionary = {}
		for r_key in _resource_inputs.keys():
			var val: int = int(_resource_inputs[r_key].value)
			if val > 0:
				carry[r_key] = val
		res = MovementScript.send_trade(state, int(_from_village["id"]), int(_to_village["id"]), carry, now)
	elif type == MovementScript.TYPE_RAID:
		var selected_units: Dictionary = {}
		for u_key in _unit_inputs.keys():
			var count: int = int(_unit_inputs[u_key].value)
			if count > 0:
				selected_units[u_key] = count
		res = MovementScript.send_raid(state, int(_from_village["id"]), int(_to_village["id"]), selected_units, now)
	else:
		var selected_units: Dictionary = {}
		var total_selected := 0
		for u_key in _unit_inputs.keys():
			var count: int = int(_unit_inputs[u_key].value)
			if count > 0:
				selected_units[u_key] = count
				total_selected += count

		var is_only_spies: bool = total_selected > 0 and int(selected_units.get("spy", 0)) == total_selected
		if is_only_spies:
			res = MovementScript.send_spy(state, int(_from_village["id"]), int(_to_village["id"]), selected_units, now)
		else:
			res = MovementScript.send_attack(state, int(_from_village["id"]), int(_to_village["id"]), selected_units, now)

	if bool(res.get("ok", false)) and gs != null:
		gs.from_dict(state)
		movement_dispatched.emit(type, int(_to_village["id"]))
		hide()
