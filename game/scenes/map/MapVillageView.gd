extends Control
## MapVillageView — 2.5D kartografik harita köyü (Taht ve Kılıç / A-HARITA).
##
## Haritadaki her köy, parşömen bir "jeton" (medallion) olarak çizilir:
##   • Açık parşömen disk + sahibine göre renkli halka (oyuncu=altın, soyguncu=taş, düşman=kırmızı)
##   • Kartografik mürekkep ikonu (kale / çadır / düşman kalesi)
##   • Sağ üstte flama (👑 / ⛺ / 🚩)
##   • Altta isim + koordinat plaketi
## Tıklama butonu tamamen şeffaftır; böylece görsellerin üstünü kapatmaz.

signal clicked()

const Palette := preload("res://themes/Palette.gd")

const TOKEN_SIZE := 72.0
const ICON_SIZE := 46.0
const PLATE_W := 156.0
const PLATE_H := 26.0

var village_data: Dictionary = {}
var is_player: bool = false
var is_barbarian: bool = false

var _btn: Button
var _token: Panel
var _sprite: TextureRect
var _banner_icon: Label
var _label_name: Label
var _panel_info: PanelContainer
var _hover_tween: Tween


func _init() -> void:
	custom_minimum_size = Vector2(96, 96)
	size = Vector2(96, 96)
	mouse_filter = MOUSE_FILTER_PASS


func setup(v_data: Dictionary, is_own: bool, is_barb: bool) -> void:
	village_data = v_data
	is_player = is_own
	is_barbarian = is_barb
	_build_ui()


# ---------------------------------------------------------------- renkler
func _accent_color() -> Color:
	if is_player:
		return Palette.c("altin")
	if is_barbarian:
		return Palette.c("tas_golge")
	return Palette.c("dusman")


func _plate_bg() -> Color:
	if is_player:
		return Color(0.10, 0.26, 0.15, 0.94)
	if is_barbarian:
		return Color(0.22, 0.19, 0.15, 0.92)
	return Color(0.34, 0.12, 0.12, 0.94)


func _disc_bg() -> Color:
	if is_player:
		return Color(0.99, 0.95, 0.82, 1.0)
	if is_barbarian:
		return Color(0.95, 0.91, 0.82, 1.0)
	return Color(0.99, 0.90, 0.86, 1.0)


# ---------------------------------------------------------------- kurulum
func _build_ui() -> void:
	if _btn != null:
		return

	# 0) Tamamen şeffaf tıklama katmanı (EN ALTA eklenir, görseli kapatmaz)
	_btn = Button.new()
	_btn.anchors_preset = PRESET_FULL_RECT
	_btn.size = size
	_btn.flat = true
	_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty_sb := StyleBoxEmpty.new()
	_btn.add_theme_stylebox_override("normal", empty_sb)
	_btn.add_theme_stylebox_override("hover", empty_sb)
	_btn.add_theme_stylebox_override("pressed", empty_sb)
	_btn.add_theme_stylebox_override("disabled", empty_sb)
	_btn.add_theme_stylebox_override("focus", empty_sb)
	_btn.pressed.connect(func(): clicked.emit())
	_btn.mouse_entered.connect(_on_mouse_enter)
	_btn.mouse_exited.connect(_on_mouse_exit)
	add_child(_btn)

	# 1) Zemin gölgesi
	var shadow := Panel.new()
	shadow.position = Vector2((size.x - 58.0) * 0.5, TOKEN_SIZE - 4.0)
	shadow.size = Vector2(58, 16)
	shadow.mouse_filter = MOUSE_FILTER_IGNORE
	var sh_sb := StyleBoxFlat.new()
	sh_sb.bg_color = Color(0.14, 0.10, 0.06, 0.34)
	sh_sb.set_corner_radius_all(8)
	shadow.add_theme_stylebox_override("panel", sh_sb)
	add_child(shadow)

	# 2) Parşömen disk + renkli halka
	_token = Panel.new()
	_token.position = Vector2((size.x - TOKEN_SIZE) * 0.5, 2)
	_token.size = Vector2(TOKEN_SIZE, TOKEN_SIZE)
	_token.pivot_offset = Vector2(TOKEN_SIZE, TOKEN_SIZE) * 0.5
	_token.mouse_filter = MOUSE_FILTER_IGNORE
	var token_sb := StyleBoxFlat.new()
	token_sb.bg_color = _disc_bg()
	token_sb.border_color = _accent_color()
	token_sb.set_border_width_all(3)
	token_sb.set_corner_radius_all(int(TOKEN_SIZE * 0.5))
	token_sb.shadow_color = Color(0.16, 0.11, 0.05, 0.42)
	token_sb.shadow_size = 7
	token_sb.shadow_offset = Vector2(0, 3)
	_token.add_theme_stylebox_override("panel", token_sb)
	add_child(_token)

	# 3) Kartografik mürekkep ikonu
	_sprite = TextureRect.new()
	_sprite.position = Vector2((size.x - ICON_SIZE) * 0.5, 2 + (TOKEN_SIZE - ICON_SIZE) * 0.5)
	_sprite.size = Vector2(ICON_SIZE, ICON_SIZE)
	_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite.mouse_filter = MOUSE_FILTER_IGNORE
	_sprite.pivot_offset = Vector2(ICON_SIZE, ICON_SIZE) * 0.5

	var tex_path := "res://assets/sprites/icons/cartography/2x/castle.png"
	if is_player:
		tex_path = "res://assets/sprites/icons/cartography/2x/castleWide.png"
	elif is_barbarian:
		tex_path = "res://assets/sprites/icons/cartography/2x/tent.png"
	if ResourceLoader.exists(tex_path):
		_sprite.texture = load(tex_path)
	# Mürekkep rengi: koyu kahve (siyah çizgi sanatı sıcak tona çekilir)
	_sprite.modulate = Color(0.23, 0.16, 0.09, 1.0) if is_player else Color(0.25, 0.20, 0.15, 1.0)
	add_child(_sprite)

	# 4) Flama / bayrak (diskin sağ üstü)
	_banner_icon = Label.new()
	_banner_icon.position = Vector2(size.x - 34.0, -10.0)
	_banner_icon.add_theme_font_size_override("font_size", 20)
	_banner_icon.add_theme_color_override("font_outline_color", Color(0.10, 0.07, 0.03, 0.9))
	_banner_icon.add_theme_constant_override("outline_size", 4)
	_banner_icon.mouse_filter = MOUSE_FILTER_IGNORE
	_banner_icon.pivot_offset = Vector2(10, 10)
	if is_player:
		_banner_icon.text = "👑"
	elif is_barbarian:
		_banner_icon.text = "⛺"
	else:
		_banner_icon.text = "🚩"
	add_child(_banner_icon)

	# 5) İsim + koordinat plaketi
	_panel_info = PanelContainer.new()
	_panel_info.position = Vector2((size.x - PLATE_W) * 0.5, TOKEN_SIZE + 6.0)
	_panel_info.custom_minimum_size = Vector2(PLATE_W, PLATE_H)
	_panel_info.size = Vector2(PLATE_W, PLATE_H)
	_panel_info.mouse_filter = MOUSE_FILTER_IGNORE

	var plate_sb := StyleBoxFlat.new()
	plate_sb.bg_color = _plate_bg()
	plate_sb.border_color = _accent_color()
	plate_sb.set_border_width_all(1)
	plate_sb.set_corner_radius_all(8)
	plate_sb.content_margin_left = 6
	plate_sb.content_margin_right = 6
	plate_sb.content_margin_top = 2
	plate_sb.content_margin_bottom = 2
	plate_sb.shadow_color = Color(0.10, 0.07, 0.03, 0.35)
	plate_sb.shadow_size = 3
	_panel_info.add_theme_stylebox_override("panel", plate_sb)

	var v_name: String = str(village_data.get("name", "Köy"))
	var vx: int = int(village_data.get("x", 0))
	var vy: int = int(village_data.get("y", 0))

	_label_name = Label.new()
	_label_name.text = "%s  (%d|%d)" % [v_name, vx, vy]
	_label_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label_name.add_theme_font_size_override("font_size", 12)
	_label_name.add_theme_color_override("font_color", Color(1, 0.98, 0.92, 1.0))
	_label_name.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.02, 0.85))
	_label_name.add_theme_constant_override("outline_size", 3)
	_panel_info.add_child(_label_name)
	add_child(_panel_info)


# ---------------------------------------------------------------- etkileşim
func _on_mouse_enter() -> void:
	_animate_lift(true)


func _on_mouse_exit() -> void:
	_animate_lift(false)


func _animate_lift(up: bool) -> void:
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	var dy := -5.0 if up else 0.0
	var sc := 1.07 if up else 1.0
	_hover_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(_token, "position:y", 2.0 + dy, 0.14)
	_hover_tween.tween_property(_sprite, "position:y", 2.0 + (TOKEN_SIZE - ICON_SIZE) * 0.5 + dy, 0.14)
	_hover_tween.tween_property(_banner_icon, "position:y", -10.0 + dy, 0.14)
	_hover_tween.tween_property(_token, "scale", Vector2(sc, sc), 0.14)
	_hover_tween.tween_property(_sprite, "scale", Vector2(sc, sc), 0.14)


func get_button() -> Button:
	return _btn
