extends PanelContainer
## SendTroopsPanel — Birlik ve Hammadde Sevk Paneli (Taht ve Kılıç / A-ARAYUZ).

signal movement_dispatched(type: String, target_id: int)
signal closed()

const MovementScript := preload("res://scripts/sim/actions/Movement.gd")
const RulesEngineScript := preload("res://scripts/rules/RulesEngine.gd")
const TravelScript := preload("res://scripts/world/Travel.gd")
const ProtectionScript := preload("res://scripts/sim/actions/Protection.gd")
const LordModelScript := preload("res://scripts/model/LordModel.gd")
const FontNunitoBold := preload("res://assets/fonts/Nunito-Bold.ttf")
const FontCinzelBold := preload("res://assets/fonts/Cinzel-Bold.ttf")
const TexVizier := preload("res://assets/sprites/ui/tutorial/vizier_portrait.png")
const TexRoyalSeal := preload("res://assets/sprites/ui/tutorial/royal_decree_seal.png")

var _from_village: Dictionary = {}
var _to_village: Dictionary = {}
var _unit_inputs: Dictionary = {}
var _resource_inputs: Dictionary = {}
var _current_tab: String = "troops" # "troops" | "trade"
var _btn_switch_to_village: Button = null
var _lord_row: PanelContainer = null
var _lord_check: CheckBox = null
var _lord_status_label: Label = null
var btn_support: Button = null
var _protection_modal: CanvasLayer = null

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
@onready var btn_attack: Button = $VBox/ActionButtons/BtnAttack
@onready var btn_trade: Button = $VBox/ActionButtons/BtnTrade


func _ready() -> void:
	close_btn.pressed.connect(func():
		hide()
		closed.emit()
	)
	btn_attack.pressed.connect(func(): _dispatch(MovementScript.TYPE_ATTACK))
	btn_trade.pressed.connect(func(): _dispatch(MovementScript.TYPE_TRADE))

	btn_support = Button.new()
	btn_support.name = "BtnSupport"
	btn_support.text = "🛡️ Destek Gönder"
	btn_support.custom_minimum_size = btn_attack.custom_minimum_size
	btn_support.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_support.hide()
	btn_support.pressed.connect(func(): _dispatch(MovementScript.TYPE_SUPPORT))
	action_buttons_box.add_child(btn_support)

	btn_tab_trade.pressed.connect(func():
		if _current_tab == "troops":
			_switch_tab("trade")
		else:
			_switch_tab("troops")
	)

	_setup_fonts_and_styles()


func _style_spinbox(spin: SpinBox) -> void:
	spin.update_on_text_changed = true
	var le := spin.get_line_edit()
	if le != null:
		le.alignment = HORIZONTAL_ALIGNMENT_CENTER
		le.add_theme_font_override("font", FontNunitoBold)
		le.add_theme_font_size_override("font_size", 26)
		le.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
		var sb_box := StyleBoxFlat.new()
		sb_box.bg_color = Color(0.14, 0.12, 0.18, 0.95)
		sb_box.border_color = Color(0.85, 0.72, 0.42, 0.85)
		sb_box.set_border_width_all(2)
		sb_box.set_corner_radius_all(10)
		le.add_theme_stylebox_override("normal", sb_box)
		le.add_theme_stylebox_override("focus", sb_box)
	var gc_sp: Node = Engine.get_main_loop().root.get_node_or_null("GameConfig") if Engine.get_main_loop() is SceneTree else null
	if gc_sp != null and gc_sp.has_method("bind_keyboard_dismiss"):
		gc_sp.call("bind_keyboard_dismiss", spin, Callable(), true)


func _style_all_button(btn: Button) -> void:
	btn.add_theme_font_override("font", FontNunitoBold)
	btn.add_theme_font_size_override("font_size", 24)
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
	btn.add_theme_font_size_override("font_size", 26)
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
	sb_norm.shadow_size = 0
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
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_constant_override("outline_size", 3)
	title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.98))
	title_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.80))

	target_header_label.add_theme_font_override("font", FontNunitoBold)
	target_header_label.add_theme_font_size_override("font_size", 30)
	target_header_label.add_theme_constant_override("outline_size", 4)
	target_header_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
	target_header_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	target_header_label.add_theme_constant_override("shadow_offset_y", 2)
	target_header_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))

	owner_label.add_theme_font_override("font", FontNunitoBold)
	owner_label.add_theme_font_size_override("font_size", 26)
	owner_label.add_theme_constant_override("outline_size", 3)
	owner_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
	owner_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	owner_label.add_theme_constant_override("shadow_offset_y", 2)
	owner_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))

	alliance_label.add_theme_font_override("font", FontNunitoBold)
	alliance_label.add_theme_font_size_override("font_size", 26)
	alliance_label.add_theme_constant_override("outline_size", 3)
	alliance_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
	alliance_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	alliance_label.add_theme_constant_override("shadow_offset_y", 2)
	alliance_label.add_theme_color_override("font_color", Color(0.70, 0.88, 1.0))

	points_label.add_theme_font_override("font", FontNunitoBold)
	points_label.add_theme_font_size_override("font_size", 26)
	points_label.add_theme_constant_override("outline_size", 3)
	points_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
	points_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	points_label.add_theme_constant_override("shadow_offset_y", 2)
	points_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))

	distance_label.add_theme_font_override("font", FontNunitoBold)
	distance_label.add_theme_font_size_override("font_size", 26)
	distance_label.add_theme_constant_override("outline_size", 3)
	distance_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
	distance_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	distance_label.add_theme_constant_override("shadow_offset_y", 2)
	distance_label.add_theme_color_override("font_color", Color(0.55, 0.95, 0.65))

	estimate_label.add_theme_font_override("font", FontNunitoBold)
	estimate_label.add_theme_font_size_override("font_size", 26)
	estimate_label.add_theme_constant_override("outline_size", 4)
	estimate_label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 1.0))
	estimate_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	estimate_label.add_theme_constant_override("shadow_offset_y", 2)
	estimate_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.78, 1.0))

	warning_label.add_theme_font_override("font", FontNunitoBold)
	warning_label.add_theme_font_size_override("font_size", 26)
	warning_label.add_theme_constant_override("outline_size", 3)
	warning_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.98))
	warning_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.35))

	for btn in [btn_attack, btn_trade, btn_tab_trade]:
		_style_action_button(btn)
	if btn_support != null:
		_style_action_button(btn_support)


func _ensure_switch_button() -> void:
	if _btn_switch_to_village != null and is_instance_valid(_btn_switch_to_village):
		return
	var vbox := get_node_or_null("VBox") as VBoxContainer
	if vbox == null:
		return
	_btn_switch_to_village = Button.new()
	_btn_switch_to_village.name = "BtnSwitchToVillage"
	_btn_switch_to_village.text = "🏰 Bu Köye Geç (Aktif Köy Yap)"
	_btn_switch_to_village.custom_minimum_size = Vector2(0, 56)
	_btn_switch_to_village.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_btn_switch_to_village.add_theme_font_override("font", FontNunitoBold)
	_btn_switch_to_village.add_theme_font_size_override("font_size", 26)
	_btn_switch_to_village.add_theme_color_override("font_color", Color(1.0, 0.98, 0.90))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.45, 0.24, 0.98)
	sb.border_color = Color(0.45, 0.92, 0.55, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	_btn_switch_to_village.add_theme_stylebox_override("normal", sb)
	var h_sb := sb.duplicate() as StyleBoxFlat
	h_sb.bg_color = Color(0.22, 0.56, 0.30, 1.0)
	_btn_switch_to_village.add_theme_stylebox_override("hover", h_sb)
	_btn_switch_to_village.add_theme_stylebox_override("pressed", h_sb)
	_btn_switch_to_village.pressed.connect(func():
		var target_id := int(_to_village.get("id", -1))
		var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
		if gs != null and target_id > 0 and gs.has_method("set_active_village"):
			gs.set_active_village(target_id)
		var wm = Engine.get_main_loop().root.get_node_or_null("WorldManager") if Engine.get_main_loop() is SceneTree else null
		if wm != null and wm.has_method("save_active_world"):
			wm.save_active_world()
		hide()
		closed.emit()
		var tree = Engine.get_main_loop() as SceneTree
		if tree != null:
			tree.change_scene_to_file("res://scenes/Village.tscn")
	)
	vbox.add_child(_btn_switch_to_village)
	vbox.move_child(_btn_switch_to_village, mini(3, vbox.get_child_count() - 1))


func show_target(from_v: Dictionary, to_v: Dictionary) -> void:
	_from_village = from_v
	_to_village = to_v
	_ensure_switch_button()
	if _btn_switch_to_village != null:
		var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
		var p_name := str(gs.player.get("name", "")) if gs != null else ""
		var target_id := int(to_v.get("id", -1))
		var from_id := int(from_v.get("id", -1))
		var norm_p := p_name.strip_edges().to_lower()
		var norm_o := str(to_v.get("owner", "")).strip_edges().to_lower()
		var is_own := (not bool(to_v.get("is_bot", false)) and not bool(to_v.get("is_barbarian", false)) and not norm_p.is_empty() and norm_o == norm_p)
		if not is_own and gs != null and gs.has_method("get_player_villages"):
			for pv in gs.get_player_villages():
				if int((pv as Dictionary).get("id", -1)) == target_id:
					is_own = true
					break
		_btn_switch_to_village.visible = (is_own and target_id != from_id)
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
	var is_bandit := bool(_to_village.get("is_bandit", false)) or bool(_to_village.get("is_bot", false))

	target_header_label.text = " %s (%d|%d)" % [to_name, to_x, to_y]
	if is_bandit:
		var blvl := LordModelScript.bandit_level_for_village(_to_village)
		target_info_label.text = "🏴 Haydut Köyü Sv.%d (%d|%d) — Fethedilemez · Ekipman Düşer · Mesafe: %.1f alan" % [blvl, to_x, to_y, dist]
	else:
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
		alliance_label.text = " İttifak: %s (Müttefik)" % alliance_name
		alliance_label.add_theme_color_override("font_color", Color(0.40, 0.85, 1.0))
	else:
		alliance_label.text = " İttifak: %s" % alliance_name
		alliance_label.remove_theme_color_override("font_color")

	var points: int = int(_to_village.get("points", 0))
	points_label.text = " Puan: %d" % points

	distance_label.text = " Mesafe: %.1f alan" % dist


func _ensure_lord_row() -> void:
	if _lord_row != null and is_instance_valid(_lord_row):
		return
	var vbox := get_node_or_null("VBox") as VBoxContainer
	if vbox == null:
		return
	_lord_row = PanelContainer.new()
	_lord_row.name = "LordMarchCard"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.11, 0.19, 0.95)
	sb.border_color = Color(0.86, 0.70, 0.34, 0.85)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	_lord_row.add_theme_stylebox_override("panel", sb)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	_lord_row.add_child(hb)

	_lord_check = CheckBox.new()
	_lord_check.name = "ChkIncludeLord"
	_lord_check.text = "👑 Lord'u Sefere Dahil Et"
	_lord_check.button_pressed = true
	_lord_check.add_theme_font_override("font", FontNunitoBold)
	_lord_check.add_theme_font_size_override("font_size", 24)
	_lord_check.add_theme_color_override("font_color", Color(1.0, 0.93, 0.65))
	hb.add_child(_lord_check)

	_lord_status_label = Label.new()
	_lord_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lord_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lord_status_label.add_theme_font_override("font", FontNunitoBold)
	_lord_status_label.add_theme_font_size_override("font_size", 21)
	hb.add_child(_lord_status_label)

	vbox.add_child(_lord_row)
	vbox.move_child(_lord_row, scroll_troops.get_index())


func _refresh_lord_row(is_friendly: bool) -> void:
	_ensure_lord_row()
	if _lord_row == null:
		return
	if _current_tab != "troops" or is_friendly:
		_lord_row.hide()
		return
	_lord_row.show()
	var lm: Node = Engine.get_main_loop().root.get_node_or_null("LordManager") if Engine.get_main_loop() is SceneTree else null
	if lm != null and lm.has_method("is_injured") and bool(lm.call("is_injured")):
		var rem := int(lm.call("get_injury_remaining_secs"))
		var mins := int(ceil(float(rem) / 60.0))
		_lord_check.button_pressed = false
		_lord_check.disabled = true
		_lord_status_label.text = "🩸 Lord Yaralı (~%d dk)" % maxi(1, mins)
		_lord_status_label.add_theme_color_override("font_color", Color(1.0, 0.52, 0.48))
	else:
		_lord_check.disabled = false
		var st: Dictionary = lm.call("get_lord_stats") if lm != null else LordModelScript.compute_lord_stats({})
		_lord_status_label.text = "⚔️ %d · 🛡️ %d · ❤️ %d" % [int(st.get("attack", 120)), int(st.get("defense", 100)), int(st.get("hp", 500))]
		_lord_status_label.add_theme_color_override("font_color", Color(0.60, 0.95, 0.68))


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
		lbl.add_theme_font_size_override("font_size", 26)
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
		{"key": "iron", "name": " Demir", "row": iron_row, "color": Color(0.65, 0.88, 1.0)},
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
		lbl.add_theme_font_size_override("font_size", 26)
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


func _is_target_friendly() -> bool:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	var state: Dictionary = gs.to_dict() if gs != null else {}
	return MovementScript._is_friendly(state, _from_village, _to_village)


func _is_target_supportable() -> bool:
	return int(_from_village.get("id", -1)) != int(_to_village.get("id", -2))


func _switch_tab(tab: String) -> void:
	_current_tab = tab
	if tab == "troops":
		scroll_troops.show()
		trade_container.hide()
		btn_trade.hide()
		if _is_target_friendly():
			btn_attack.hide()
			if btn_support != null:
				btn_support.show()
		else:
			btn_attack.show()
			if btn_support != null:
				btn_support.visible = _is_target_supportable()
		btn_tab_trade.text = " Hammadde Gönder (Katır)"
	else:
		scroll_troops.hide()
		trade_container.show()
		btn_attack.hide()
		if btn_support != null:
			btn_support.hide()
		btn_trade.show()
		btn_tab_trade.text = " Birlik Gönder (Saldırı / Destek)"
	refresh()


func _effective_now(state: Dictionary) -> int:
	var real_now := int(Time.get_unix_time_from_system())
	var w = state.get("world", {})
	var sim_now := int((w as Dictionary).get("sim_now_unix", 0)) if typeof(w) == TYPE_DICTIONARY else 0
	return maxi(real_now, sim_now)


func refresh() -> void:
	var from_x := int(_from_village.get("x", 0))
	var from_y := int(_from_village.get("y", 0))
	var to_x := int(_to_village.get("x", 0))
	var to_y := int(_to_village.get("y", 0))
	var dist := TravelScript.distance(from_x, from_y, to_x, to_y)

	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	var state: Dictionary = gs.to_dict() if gs != null else {}
	var now := _effective_now(state)

	if _current_tab == "troops":
		_refresh_troops_mode(state, from_x, from_y, to_x, to_y, dist, now)
	else:
		_refresh_lord_row(true)
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

		estimate_label.text = " En Yavaş: %s (%.1f dk/alan · %.1fx Hız)  |  Yolculuk: %02d:%02d  |  Varış: %02d:%02d:%02d" % [
			slowest_name, slowest_speed, TravelScript.unit_speed_multiplier(), mm, ss, dt["hour"], dt["minute"], dt["second"]
		]
	else:
		estimate_label.text = " En Yavaş Birim: —  |   Yolculuk Süresi: 00:00  |   Varış Saati: --:--:--"

	var barracks_lvl: int = int(_from_village.get("buildings", {}).get("barracks", 0))
	var min_units: int = RulesEngineScript.min_attack_units(barracks_lvl)
	var from_id := int(_from_village.get("id", -1))
	var to_id := int(_to_village.get("id", -1))
	var is_friendly := MovementScript._is_friendly(state, _from_village, _to_village)
	_refresh_lord_row(is_friendly)

	if is_friendly:
		btn_attack.hide()
		if btn_support != null:
			btn_support.show()
		var sup_check: Dictionary = MovementScript.can_send(state, from_id, to_id, MovementScript.TYPE_SUPPORT, selected_units, {}, now)
		if not bool(sup_check.get("ok", false)):
			if btn_support != null:
				btn_support.disabled = true
			warning_label.show()
			var scode := str(sup_check.get("code", ""))
			if scode == "units_empty":
				warning_label.text = "Destek için birlik seçiniz."
			else:
				warning_label.text = "Uyarı: " + str(sup_check.get("message", "Geçersiz destek gönderimi"))
		else:
			if btn_support != null:
				btn_support.disabled = false
			warning_label.hide()
		return

	var can_support_target := _is_target_supportable()
	if btn_support != null:
		if can_support_target:
			btn_support.show()
			var sup_chk2: Dictionary = MovementScript.can_send(state, from_id, to_id, MovementScript.TYPE_SUPPORT, selected_units, {}, now)
			btn_support.disabled = not bool(sup_chk2.get("ok", false))
		else:
			btn_support.hide()
	var is_only_spies: bool = total_selected > 0 and int(selected_units.get("spy", 0)) == total_selected
	var check_type: String = MovementScript.TYPE_SPY if is_only_spies else MovementScript.TYPE_ATTACK
	btn_attack.show()
	btn_attack.text = "🕵️ Casus Gönder" if is_only_spies else "⚔️ Saldır"

	var check: Dictionary = MovementScript.can_send(state, from_id, to_id, check_type, selected_units, {}, now)

	if not bool(check.get("ok", false)):
		var code: String = str(check.get("code", ""))
		btn_attack.disabled = true
		warning_label.show()
		if code == "min_units":
			warning_label.text = "Asgari ordu şartı: En az %d birim seçmelisiniz (3 * Kışla)." % min_units
		elif code == "count_too_far":
			warning_label.text = "Kont menzil dışı! Hedef 80 alandan uzak olamaz."
		elif code == "target_protected":
			warning_label.text = "Hedef köy koruma altında."
		elif code == "friendly_target":
			warning_label.text = "İttifak Kuralı: Kendi veya ittifak üyesi köylere saldıramazsınız!"
		elif code == "units_empty":
			warning_label.text = "Sefer için birlik seçiniz."
		else:
			warning_label.text = "Uyarı: " + str(check.get("message", "Geçersiz gönderim"))
	else:
		warning_label.hide()
		btn_attack.disabled = false


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

	estimate_label.text = " Katır Hızı: %.1f dk/alan (%.1fx Hız)  |  Yolculuk: %02d:%02d  |  Varış: %02d:%02d:%02d" % [
		donkey_speed, TravelScript.unit_speed_multiplier(), mm, ss, dt["hour"], dt["minute"], dt["second"]
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
			warning_label.text = " Ticaret yalnızca gerçek oyunculara, kendi veya müttefik köylerinize yapılabilir."
		elif code == "market_required":
			warning_label.text = " Ticaret için Market binası (en az Sv. 1) gereklidir."
		else:
			warning_label.text = "Uyarı: " + str(check.get("message", "Geçersiz hammadde sevki"))
		btn_trade.disabled = true
	else:
		warning_label.hide()
		btn_trade.disabled = false


func _collect_selected_units() -> Dictionary:
	var selected_units: Dictionary = {}
	for u_key in _unit_inputs.keys():
		var count: int = int(_unit_inputs[u_key].value)
		if count > 0:
			selected_units[u_key] = count
	return selected_units


func _sum_units_dict(u_dict: Dictionary) -> int:
	var tot := 0
	for k in u_dict.keys():
		tot += int(u_dict[k])
	return tot


func _attacker_protection_until() -> int:
	return maxi(int(_from_village.get("protection_until", 0)), int(_from_village.get("protection_until_unix", 0)))


func will_drop_attacker_protection(type: String, selected_units: Dictionary, now: int) -> bool:
	if type != MovementScript.TYPE_ATTACK and type != MovementScript.TYPE_RAID:
		return false
	var tot := _sum_units_dict(selected_units)
	if tot <= 0 or int(selected_units.get("spy", 0)) == tot:
		return false
	if ProtectionScript.is_unprotected_kind(_from_village):
		return false
	if _attacker_protection_until() <= now:
		return false
	if ProtectionScript.is_unprotected_kind(_to_village):
		return false
	return true


func _fmt_shield_duration(secs: int) -> String:
	var s := maxi(0, secs)
	var days := s / 86400
	var hrs := (s % 86400) / 3600
	var mins := (s % 3600) / 60
	if days > 0:
		return "%d gün %d sa" % [days, hrs]
	if hrs > 0:
		return "%d sa %d dk" % [hrs, mins]
	return "%d dk" % maxi(1, mins)


func _show_vizier_protection_warning(attack_type: String, remaining_secs: int) -> void:
	if is_instance_valid(_protection_modal):
		_protection_modal.queue_free()
	var loop := Engine.get_main_loop()
	var host: Node = null
	if loop is SceneTree:
		host = (loop as SceneTree).current_scene if (loop as SceneTree).current_scene != null else (loop as SceneTree).root
	if host == null:
		host = self

	var layer := CanvasLayer.new()
	layer.name = "VizierProtectionWarningModal"
	layer.layer = 170
	_protection_modal = layer
	host.add_child(layer)

	var root_ctrl := Control.new()
	root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(root_ctrl)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.02, 0.05, 0.84)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root_ctrl.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.add_child(center)

	var card := PanelContainer.new()
	card.name = "VizierProtectionCard"
	card.custom_minimum_size = Vector2(780, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.08, 0.12, 0.99)
	sb.border_color = Color(0.95, 0.68, 0.24, 1.0)
	sb.set_border_width_all(3)
	sb.border_width_top = 6
	sb.set_corner_radius_all(20)
	sb.set_content_margin_all(24)
	sb.shadow_color = Color(0, 0, 0, 0.80)
	sb.shadow_size = 0
	card.add_theme_stylebox_override("panel", sb)
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	card.add_child(vb)

	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 12)
	vb.add_child(hdr)

	var seal := TextureRect.new()
	seal.texture = TexRoyalSeal
	seal.custom_minimum_size = Vector2(46, 46)
	seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	seal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hdr.add_child(seal)

	var title := Label.new()
	title.text = "BAŞ VEZİR UYARISI • KORUMA KALKANI"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_override("font", FontCinzelBold)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.36))
	hdr.add_child(title)

	var body_hb := HBoxContainer.new()
	body_hb.add_theme_constant_override("separation", 18)
	vb.add_child(body_hb)

	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(132, 132)
	portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pf_sb := StyleBoxFlat.new()
	pf_sb.bg_color = Color(0.08, 0.06, 0.10, 1.0)
	pf_sb.border_color = Color(0.92, 0.74, 0.32, 0.98)
	pf_sb.set_border_width_all(3)
	pf_sb.set_corner_radius_all(16)
	pf_sb.set_content_margin_all(4)
	portrait_frame.add_theme_stylebox_override("panel", pf_sb)
	body_hb.add_child(portrait_frame)

	var portrait := TextureRect.new()
	portrait.texture = TexVizier
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait_frame.add_child(portrait)

	var msg_lbl := RichTextLabel.new()
	msg_lbl.bbcode_enabled = true
	msg_lbl.fit_content = true
	msg_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	msg_lbl.custom_minimum_size = Vector2(540, 120)
	msg_lbl.add_theme_font_override("normal_font", FontNunitoBold)
	msg_lbl.add_theme_font_override("bold_font", FontNunitoBold)
	msg_lbl.add_theme_font_size_override("normal_font_size", 23)
	msg_lbl.add_theme_font_size_override("bold_font_size", 23)
	msg_lbl.add_theme_color_override("default_color", Color(0.96, 0.93, 0.86))
	msg_lbl.text = "[b][color=#FFD86B]Lordum,[/color][/b] köyünüz şu anda [color=#66EE88]Yeni Oyuncu Koruma Kalkanı[/color] altındadır (Kalan: [b]%s[/b]).\n\n[color=#FF8877]Bu saldırıyı gerçekleştirirseniz üzerindeki koruma kalkanı kaldırılacaktır[/color] ve diğer oyuncular köyünüze saldırabilecektir!\n\nYine de seferi başlatmak istiyor musunuz?" % _fmt_shield_duration(remaining_secs)
	body_hb.add_child(msg_lbl)

	var btn_hb := HBoxContainer.new()
	btn_hb.add_theme_constant_override("separation", 14)
	vb.add_child(btn_hb)

	var btn_cancel := Button.new()
	btn_cancel.name = "BtnCancelProtectionWarning"
	btn_cancel.text = "🛡️ Vazgeç (Kalkanı Koru)"
	btn_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_cancel.custom_minimum_size = Vector2(0, 60)
	btn_cancel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_cancel.add_theme_font_override("font", FontNunitoBold)
	btn_cancel.add_theme_font_size_override("font_size", 23)
	var bc_sb := StyleBoxFlat.new()
	bc_sb.bg_color = Color(0.16, 0.34, 0.24, 0.98)
	bc_sb.border_color = Color(0.50, 0.90, 0.60, 1.0)
	bc_sb.set_border_width_all(2)
	bc_sb.set_corner_radius_all(12)
	btn_cancel.add_theme_stylebox_override("normal", bc_sb)
	btn_cancel.add_theme_stylebox_override("hover", bc_sb)
	btn_cancel.add_theme_color_override("font_color", Color(0.96, 1.0, 0.96))
	btn_cancel.pressed.connect(func():
		if is_instance_valid(layer):
			layer.queue_free()
	)
	btn_hb.add_child(btn_cancel)

	var btn_confirm := Button.new()
	btn_confirm.name = "BtnConfirmProtectionWarning"
	btn_confirm.text = "⚔️ Kalkanı Kaldır ve Saldır"
	btn_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_confirm.custom_minimum_size = Vector2(0, 60)
	btn_confirm.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_confirm.add_theme_font_override("font", FontNunitoBold)
	btn_confirm.add_theme_font_size_override("font_size", 23)
	var ba_sb := StyleBoxFlat.new()
	ba_sb.bg_color = Color(0.58, 0.16, 0.16, 0.98)
	ba_sb.border_color = Color(0.98, 0.72, 0.36, 1.0)
	ba_sb.set_border_width_all(2)
	ba_sb.set_corner_radius_all(12)
	btn_confirm.add_theme_stylebox_override("normal", ba_sb)
	btn_confirm.add_theme_stylebox_override("hover", ba_sb)
	btn_confirm.add_theme_color_override("font_color", Color(1.0, 0.95, 0.90))
	btn_confirm.pressed.connect(func():
		if is_instance_valid(layer):
			layer.queue_free()
		_dispatch(attack_type, true)
	)
	btn_hb.add_child(btn_confirm)


func _dispatch(type: String, protection_confirmed: bool = false) -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	var state: Dictionary = gs.to_dict() if gs != null else {}
	var now := _effective_now(state)
	var res: Dictionary = {}

	if type == MovementScript.TYPE_TRADE:
		var carry: Dictionary = {}
		for r_key in _resource_inputs.keys():
			var val: int = int(_resource_inputs[r_key].value)
			if val > 0:
				carry[r_key] = val
		res = MovementScript.send_trade(state, int(_from_village["id"]), int(_to_village["id"]), carry, now)
	elif type == MovementScript.TYPE_RAID:
		if MovementScript._is_friendly(state, _from_village, _to_village):
			warning_label.show()
			warning_label.text = "İttifak Kuralı: İttifak üyeleri birbirlerine saldıramaz!"
			return
		var selected_units := _collect_selected_units()
		if not protection_confirmed and will_drop_attacker_protection(type, selected_units, now):
			_show_vizier_protection_warning(type, _attacker_protection_until() - now)
			return
		res = MovementScript.send_raid(state, int(_from_village["id"]), int(_to_village["id"]), selected_units, now)
	elif type == MovementScript.TYPE_SUPPORT:
		var selected_units := _collect_selected_units()
		res = MovementScript.send_support(state, int(_from_village["id"]), int(_to_village["id"]), selected_units, now)
	else:
		if MovementScript._is_friendly(state, _from_village, _to_village):
			warning_label.show()
			warning_label.text = "İttifak Kuralı: İttifak üyeleri birbirlerine saldıramaz!"
			return
		var selected_units := _collect_selected_units()
		var total_selected := _sum_units_dict(selected_units)
		var is_only_spies: bool = total_selected > 0 and int(selected_units.get("spy", 0)) == total_selected
		var atk_opts := {}
		if _lord_check != null and not _lord_check.disabled and _lord_check.button_pressed:
			var lm2: Node = Engine.get_main_loop().root.get_node_or_null("LordManager") if Engine.get_main_loop() is SceneTree else null
			atk_opts["include_lord"] = true
			if lm2 != null and lm2.has_method("get_combat_payload"):
				atk_opts["lord_snapshot"] = lm2.call("get_combat_payload", now)
		if is_only_spies:
			res = MovementScript.send_spy(state, int(_from_village["id"]), int(_to_village["id"]), selected_units, now)
		else:
			if not protection_confirmed and will_drop_attacker_protection(MovementScript.TYPE_ATTACK, selected_units, now):
				_show_vizier_protection_warning(MovementScript.TYPE_ATTACK, _attacker_protection_until() - now)
				return
			res = MovementScript.send_attack(state, int(_from_village["id"]), int(_to_village["id"]), selected_units, now, atk_opts)

	if bool(res.get("ok", false)) and gs != null:
		gs.from_dict(state)
		var wm = Engine.get_main_loop().root.get_node_or_null("WorldManager") if Engine.get_main_loop() is SceneTree else null
		if wm != null:
			if wm.has_method("notify_local_mutation"):
				wm.call("notify_local_mutation")
			if wm.has_method("cancel_pending_cloud_poll"):
				wm.call("cancel_pending_cloud_poll")
		var net = Engine.get_main_loop().root.get_node_or_null("NetworkManager") if Engine.get_main_loop() is SceneTree else null
		if net != null and net.has_method("cancel_background_requests"):
			net.call("cancel_background_requests")
		if wm != null and wm.has_method("save_active_world"):
			wm.save_active_world(true)
		else:
			var sm = Engine.get_main_loop().root.get_node_or_null("SaveManager") if Engine.get_main_loop() is SceneTree else null
			if sm != null and sm.has_method("save_game"):
				sm.save_game()
		var bus = Engine.get_main_loop().root.get_node_or_null("EventBus") if Engine.get_main_loop() is SceneTree else null
		if bus != null and bus.has_signal("army_sent"):
			var mv: Dictionary = res.get("movement", {})
			if mv.is_empty():
				mv = {"type": type, "from_village_id": int(_from_village.get("id", -1)), "to_village_id": int(_to_village.get("id", -1))}
			bus.army_sent.emit(mv)
		movement_dispatched.emit(type, int(_to_village["id"]))
		hide()
