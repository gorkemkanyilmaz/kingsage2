extends Control
## MapVillageView — 2.5D Kartografik Harita Köyü Görseli (Taht ve Kılıç / A-HARITA).

signal clicked()

const Palette := preload("res://themes/Palette.gd")

var village_data: Dictionary = {}
var is_player: bool = false
var is_barbarian: bool = false

var _btn: Button
var _sprite: TextureRect
var _banner_icon: Label
var _label_name: Label
var _panel_info: PanelContainer


func _init() -> void:
	custom_minimum_size = Vector2(96, 96)
	size = Vector2(96, 96)
	mouse_filter = MOUSE_FILTER_PASS


func setup(v_data: Dictionary, is_own: bool, is_barb: bool) -> void:
	village_data = v_data
	is_player = is_own
	is_barbarian = is_barb
	_build_ui()


func _build_ui() -> void:
	if _btn != null:
		return

	# 1. Gölge
	var shadow := Panel.new()
	shadow.position = Vector2(16, 68)
	shadow.size = Vector2(64, 20)
	shadow.mouse_filter = MOUSE_FILTER_IGNORE
	var s_sb := StyleBoxFlat.new()
	s_sb.bg_color = Color(0.15, 0.12, 0.08, 0.35)
	s_sb.set_corner_radius_all(10)
	shadow.add_theme_stylebox_override("panel", s_sb)
	add_child(shadow)

	# 2. Kartografik Sprite
	_sprite = TextureRect.new()
	_sprite.position = Vector2(16, 12)
	_sprite.size = Vector2(64, 60)
	_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite.mouse_filter = MOUSE_FILTER_IGNORE

	var tex_path := "res://assets/sprites/icons/cartography/2x/castle.png"
	if is_player:
		tex_path = "res://assets/sprites/icons/cartography/2x/castleWide.png"
	elif is_barbarian:
		tex_path = "res://assets/sprites/icons/cartography/2x/tent.png"

	if ResourceLoader.exists(tex_path):
		_sprite.texture = load(tex_path)

	# Renk tonu
	if is_player:
		_sprite.modulate = Color(1.0, 0.95, 0.8) # Altın ışıltısı
	elif is_barbarian:
		_sprite.modulate = Color(0.8, 0.75, 0.7) # Çadır tonu
	else:
		_sprite.modulate = Color(0.9, 0.6, 0.6) # Düşman kalesi kırmızısı

	add_child(_sprite)

	# 3. Flama / Bayrak veya Taç İkonu
	_banner_icon = Label.new()
	_banner_icon.position = Vector2(36, -2)
	_banner_icon.add_theme_font_size_override("font_size", 16)
	_banner_icon.mouse_filter = MOUSE_FILTER_IGNORE
	if is_player:
		_banner_icon.text = "👑"
	elif is_barbarian:
		_banner_icon.text = "⛺"
	else:
		_banner_icon.text = "🚩"
	add_child(_banner_icon)

	# 4. Köy Bilgi Plaketi (Adı + Koordinat)
	_panel_info = PanelContainer.new()
	_panel_info.position = Vector2(-22, 74)
	_panel_info.custom_minimum_size = Vector2(140, 24)
	_panel_info.mouse_filter = MOUSE_FILTER_IGNORE

	var p_sb := StyleBoxFlat.new()
	p_sb.set_corner_radius_all(6)
	p_sb.content_margin_left = 4
	p_sb.content_margin_right = 4
	p_sb.content_margin_top = 1
	p_sb.content_margin_bottom = 1

	if is_player:
		p_sb.bg_color = Color(0.12, 0.28, 0.16, 0.88) # Koyu zümrüt
		p_sb.border_color = Color(0.85, 0.75, 0.35, 0.9) # Altın bordür
		p_sb.set_border_width_all(1)
	elif is_barbarian:
		p_sb.bg_color = Color(0.25, 0.22, 0.18, 0.85)
		p_sb.border_color = Color(0.5, 0.45, 0.4, 0.7)
		p_sb.set_border_width_all(1)
	else:
		p_sb.bg_color = Color(0.35, 0.14, 0.14, 0.88)
		p_sb.border_color = Color(0.8, 0.3, 0.3, 0.8)
		p_sb.set_border_width_all(1)

	_panel_info.add_theme_stylebox_override("panel", p_sb)

	var v_name: String = str(village_data.get("name", "Köy"))
	var vx: int = int(village_data.get("x", 0))
	var vy: int = int(village_data.get("y", 0))

	_label_name = Label.new()
	_label_name.text = "%s (%d|%d)" % [v_name, vx, vy]
	_label_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_name.add_theme_font_size_override("font_size", 11)
	_label_name.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	_panel_info.add_child(_label_name)
	add_child(_panel_info)

	# 5. Tıklama Butonu
	_btn = Button.new()
	_btn.anchors_preset = PRESET_FULL_RECT
	_btn.size = size
	_btn.theme_type_variation = "FlatButton"
	_btn.pressed.connect(func(): clicked.emit())
	_btn.mouse_entered.connect(_on_mouse_enter)
	_btn.mouse_exited.connect(_on_mouse_exit)
	add_child(_btn)


func _on_mouse_enter() -> void:
	var t := create_tween()
	t.tween_property(_sprite, "position:y", 6.0, 0.15).set_trans(Tween.TRANS_QUAD)
	t.parallel().tween_property(_sprite, "scale", Vector2(1.1, 1.1), 0.15)


func _on_mouse_exit() -> void:
	var t := create_tween()
	t.tween_property(_sprite, "position:y", 12.0, 0.15).set_trans(Tween.TRANS_QUAD)
	t.parallel().tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.15)


func get_button() -> Button:
	return _btn
