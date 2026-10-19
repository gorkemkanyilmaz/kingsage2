extends Control
## Reports — Raporlar ekranı (Taht ve Kılıç / A-ARAYUZ).

const Palette := preload("res://themes/Palette.gd")

const ICON_BATTLE := "res://assets/sprites/icons/cartography/2x/skull.png"
const ICON_SPY := "res://assets/sprites/icons/cartography/2x/watchtower.png"
const ICON_TRADE := "res://assets/sprites/icons/cartography/2x/chest.png"
const ICON_EMPTY := "res://assets/sprites/icons/cartography/2x/chest.png"

@onready var report_list: VBoxContainer = $Container/Scroll/List
@onready var detail_panel: PanelContainer = $DetailPanel
@onready var detail_text: Label = $DetailPanel/VBox/Scroll/DetailText
@onready var close_detail_btn: Button = $DetailPanel/VBox/CloseBtn


func _ready() -> void:
	detail_panel.hide()
	close_detail_btn.pressed.connect(func(): detail_panel.hide())
	_populate_reports()


func _populate_reports() -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null:
		return

	for child in report_list.get_children():
		child.queue_free()

	var reports: Array = gs.reports
	if reports.is_empty():
		report_list.add_child(_make_empty_state())
		return

	for rep in reports:
		if typeof(rep) != TYPE_DICTIONARY:
			continue
		var r: Dictionary = rep
		var type: String = str(r.get("type", "battle"))
		var title := "Savaş Raporu"
		var icon := ICON_BATTLE
		var accent := Palette.c("dusman")
		if type == "spy":
			title = "Casusluk Raporu"
			icon = ICON_SPY
			accent = Palette.c("dost")
		elif type == "trade":
			title = "Ticaret Teslimatı"
			icon = ICON_TRADE
			accent = Palette.c("basari")

		var subtitle := Time.get_datetime_string_from_unix_time(int(r.get("unix", 0)))
		report_list.add_child(_make_card(icon, title, subtitle, accent, func(): _show_detail(r)))


func _make_empty_state() -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(0, 620)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)

	if ResourceLoader.exists(ICON_EMPTY):
		var icon := TextureRect.new()
		icon.texture = load(ICON_EMPTY)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(0, 200)
		icon.modulate = Color(0.42, 0.32, 0.18, 0.45)
		box.add_child(icon)

	var lbl := Label.new()
	lbl.text = "Henüz okunmamış veya geçmiş rapor bulunmuyor."
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", Color(0.42, 0.36, 0.28))
	box.add_child(lbl)

	var hint := Label.new()
	hint.text = "Savaş, casusluk ve ticaret olayları burada listelenir."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(0.55, 0.50, 0.42))
	box.add_child(hint)
	return box


func _make_card(icon_path: String, title: String, subtitle: String, accent: Color, on_press: Callable) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 104)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.99, 0.96, 0.94)
	var accent_border := accent
	accent_border.a = 0.8
	sb.border_color = accent_border
	sb.set_border_width_all(1)
	sb.border_width_left = 12
	sb.corner_radius_top_left = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_right = 12
	sb.shadow_color = Color(0.42, 0.26, 0.16, 0.18)
	sb.shadow_size = 4
	sb.content_margin_left = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.content_margin_right = 14
	card.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card.add_child(row)

	if ResourceLoader.exists(icon_path):
		var icon := TextureRect.new()
		icon.texture = load(icon_path)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(64, 64)
		icon.modulate = Color(0.32, 0.24, 0.13, 0.9)
		row.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 2)
	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", 24)
	title_lbl.add_theme_color_override("font_color", Color(0.20, 0.16, 0.11))
	info.add_child(title_lbl)
	var sub_lbl := Label.new()
	sub_lbl.text = subtitle
	sub_lbl.add_theme_font_size_override("font_size", 18)
	sub_lbl.add_theme_color_override("font_color", Color(0.46, 0.40, 0.32))
	info.add_child(sub_lbl)
	row.add_child(info)

	var chevron := Label.new()
	chevron.text = "❯"
	chevron.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chevron.add_theme_font_size_override("font_size", 26)
	chevron.add_theme_color_override("font_color", Color(0.52, 0.44, 0.32))
	row.add_child(chevron)

	# Kartın tamamını tıklanabilir yapan şeffaf düğme
	var btn := Button.new()
	btn.flat = true
	var empty_sb := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty_sb)
	btn.add_theme_stylebox_override("hover", empty_sb)
	btn.add_theme_stylebox_override("pressed", empty_sb)
	btn.add_theme_stylebox_override("focus", empty_sb)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pressed.connect(on_press)
	card.add_child(btn)

	return card


func _show_detail(rep: Dictionary) -> void:
	var text := "Rapor Detayı:\n"
	text += "Tür: %s\n" % str(rep.get("type", ""))
	text += "Zaman: %s\n" % Time.get_datetime_string_from_unix_time(int(rep.get("unix", 0)))
	var data: Dictionary = rep.get("data", {})
	if not data.is_empty():
		text += "Veri:\n" + JSON.stringify(data, "  ")
	detail_text.text = text
	detail_panel.show()
