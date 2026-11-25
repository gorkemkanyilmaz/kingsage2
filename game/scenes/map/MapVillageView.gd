extends Control
class_name MapVillageView
## MapVillageView — Detaylı izometrik harita köyü (Taht ve Kılıç / A-HARITA).
##
## Görseller:
##   • Kale Sv. < 5  -> gelismemis.png
##   • Kale Sv. 5-10 -> orta-gelismis.png
##   • Kale Sv. > 10 -> gelismis.png
##
## Yazılar:
##   • Kullanıcı İsmi ( Kral / ️ Sahip / ️ Soyguncular)
##   • Köy İsmi ve Koordinat (Başkent (100|100))
##   • Nunito-Bold, büyük punto ve 3px siyah kontur ile razor-sharp netlik.

signal clicked()

const TexGelismemis := preload("res://assets/sprites/map/gelismemis.png")
const TexOrtaGelismis := preload("res://assets/sprites/map/orta-gelismis.png")
const TexGelismis := preload("res://assets/sprites/map/gelismis.png")
const ProtectionScript := preload("res://scripts/sim/actions/Protection.gd")
const FontNunitoBold := preload("res://assets/fonts/Nunito-Bold.ttf")

const SPRITE_SIZE := Vector2(296, 296)
const TOTAL_SIZE := Vector2(360, 410)

var village_data: Dictionary = {}
var is_player: bool = false
var is_alliance_member: bool = false
var is_barbarian: bool = false
var alliance_tag: String = ""

var _btn: Button
var _selection_ring: Panel
var _shield_aura: Panel
var _shield_badge: PanelContainer
var _sprite: TextureRect
var _info_card: PanelContainer
var _owner_label: Label
var _name_coord_label: Label
var _hover_tween: Tween

static var _sb_aura: StyleBoxFlat
static var _sb_shield_badge: StyleBoxFlat
static var _sb_ring_player: StyleBoxFlat
static var _sb_ring_ally: StyleBoxFlat
static var _sb_card_player: StyleBoxFlat
static var _sb_card_ally: StyleBoxFlat
static var _sb_card_enemy: StyleBoxFlat


static func _ensure_shared_styles() -> void:
	if _sb_aura == null:
		_sb_aura = StyleBoxFlat.new()
		_sb_aura.draw_center = true
		_sb_aura.bg_color = Color(0.20, 0.65, 1.0, 0.04)
		_sb_aura.border_color = Color(0.40, 0.85, 1.0, 0.35)
		_sb_aura.set_border_width_all(2)
		_sb_aura.set_corner_radius_all(98)
		_sb_aura.shadow_size = 0
	if _sb_shield_badge == null:
		_sb_shield_badge = StyleBoxFlat.new()
		_sb_shield_badge.bg_color = Color(0.06, 0.16, 0.28, 0.94)
		_sb_shield_badge.border_color = Color(0.40, 0.88, 1.0, 0.85)
		_sb_shield_badge.set_border_width_all(2)
		_sb_shield_badge.border_width_bottom = 4
		_sb_shield_badge.set_corner_radius_all(10)
		_sb_shield_badge.shadow_size = 0
		_sb_shield_badge.content_margin_left = 10
		_sb_shield_badge.content_margin_right = 10
		_sb_shield_badge.content_margin_top = 4
		_sb_shield_badge.content_margin_bottom = 4
	if _sb_ring_player == null:
		_sb_ring_player = StyleBoxFlat.new()
		_sb_ring_player.draw_center = false
		_sb_ring_player.border_color = Color(1.0, 0.85, 0.20, 0.70)
		_sb_ring_player.set_border_width_all(2)
		_sb_ring_player.set_corner_radius_all(102)
		_sb_ring_player.shadow_size = 0
	if _sb_ring_ally == null:
		_sb_ring_ally = StyleBoxFlat.new()
		_sb_ring_ally.draw_center = false
		_sb_ring_ally.border_color = Color(0.35, 0.75, 1.0, 0.70)
		_sb_ring_ally.set_border_width_all(2)
		_sb_ring_ally.set_corner_radius_all(102)
		_sb_ring_ally.shadow_size = 0
	if _sb_card_player == null:
		_sb_card_player = StyleBoxFlat.new()
		_sb_card_player.bg_color = Color(0.10, 0.09, 0.13, 0.94)
		_sb_card_player.border_color = Color(1.0, 0.88, 0.40, 1.0)
		_sb_card_player.set_border_width_all(2)
		_sb_card_player.border_width_bottom = 4
		_sb_card_player.set_corner_radius_all(10)
		_sb_card_player.shadow_size = 0
		_sb_card_player.content_margin_left = 10
		_sb_card_player.content_margin_right = 10
		_sb_card_player.content_margin_top = 4
		_sb_card_player.content_margin_bottom = 4
	if _sb_card_ally == null:
		_sb_card_ally = _sb_card_player.duplicate() as StyleBoxFlat
		_sb_card_ally.border_color = Color(0.35, 0.75, 1.0, 1.0)
	if _sb_card_enemy == null:
		_sb_card_enemy = _sb_card_player.duplicate() as StyleBoxFlat
		_sb_card_enemy.border_color = Color(0.95, 0.45, 0.38, 0.95)


func _init() -> void:
	custom_minimum_size = TOTAL_SIZE
	size = TOTAL_SIZE
	mouse_filter = MOUSE_FILTER_PASS


func setup(v_data: Dictionary, is_own: bool, is_ally: bool = false, ally_tag: String = "") -> void:
	village_data = v_data
	is_player = is_own
	is_alliance_member = is_ally
	alliance_tag = ally_tag
	is_barbarian = false
	_build_ui()


func _build_ui() -> void:
	if _btn != null:
		return

	# 0) Şeffaf tıklama butonu (tüm kart yüzeyini kaplar, MOUSE_FILTER_PASS ile harita sürüklemeyi engellemez)
	_btn = Button.new()
	_btn.anchors_preset = PRESET_FULL_RECT
	_btn.size = size
	_btn.flat = true
	_btn.mouse_filter = MOUSE_FILTER_PASS
	_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty_sb := StyleBoxEmpty.new()
	_btn.add_theme_stylebox_override("normal", empty_sb)
	_btn.add_theme_stylebox_override("hover", empty_sb)
	_btn.add_theme_stylebox_override("pressed", empty_sb)
	_btn.add_theme_stylebox_override("focus", empty_sb)
	_btn.add_theme_stylebox_override("disabled", empty_sb)
	_btn.pressed.connect(func(): clicked.emit())
	_btn.mouse_entered.connect(_on_mouse_enter)
	_btn.mouse_exited.connect(_on_mouse_exit)
	add_child(_btn)

	# 1) Köy Görseli (2 KAT BÜYÜK - 296x296, Mipmap destekli ultra keskin)
	var buildings: Dictionary = village_data.get("buildings", {})
	var main_lvl: int = int(buildings.get("main", 1))

	_sprite = TextureRect.new()
	_sprite.custom_minimum_size = SPRITE_SIZE
	_sprite.size = SPRITE_SIZE
	_sprite.position = Vector2((size.x - SPRITE_SIZE.x) * 0.5, 8.0)
	_sprite.pivot_offset = SPRITE_SIZE * 0.5
	_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_sprite.mouse_filter = MOUSE_FILTER_IGNORE

	if main_lvl < 5:
		_sprite.texture = TexGelismemis
	elif main_lvl <= 10:
		_sprite.texture = TexOrtaGelismis
	else:
		_sprite.texture = TexGelismis

	add_child(_sprite)

	# 2) 15 Günlük Fetih Koruması Kalkanı (️ Haritada Işıldayan Koruma Kalkanı)
	var now_u := int(Time.get_unix_time_from_system())
	var is_shielded: bool = ProtectionScript.is_attack_protected(village_data, now_u) \
		or int(village_data.get("protection_until", 0)) > now_u \
		or int(village_data.get("protection_until_unix", 0)) > now_u
	_ensure_shared_styles()
	if is_shielded:
		_shield_aura = Panel.new()
		var aura_sz := Vector2(196, 196) # Tam köy yerleşimi çapı
		_shield_aura.custom_minimum_size = aura_sz
		_shield_aura.size = aura_sz
		_shield_aura.position = _sprite.position + (SPRITE_SIZE - aura_sz) * 0.5
		_shield_aura.mouse_filter = MOUSE_FILTER_IGNORE
		_shield_aura.add_theme_stylebox_override("panel", _sb_aura)
		add_child(_shield_aura)

		# Kalkan Rozeti: Kalkan dairesinin üstüne binmeyecek şekilde yukarı kaldırıldı ve büyütüldü
		_shield_badge = PanelContainer.new()
		_shield_badge.custom_minimum_size = Vector2(148, 38)
		_shield_badge.position = Vector2((size.x - 148.0) * 0.5, 4.0)
		_shield_badge.mouse_filter = MOUSE_FILTER_IGNORE
		_shield_badge.add_theme_stylebox_override("panel", _sb_shield_badge)

		var s_lbl := Label.new()
		s_lbl.text = "🛡️ Koruma"
		s_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		s_lbl.add_theme_font_override("font", FontNunitoBold)
		s_lbl.add_theme_font_size_override("font_size", 23)
		s_lbl.add_theme_constant_override("outline_size", 0)
		s_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		s_lbl.add_theme_color_override("font_color", Color(0.85, 0.96, 1.0))
		_shield_badge.add_child(s_lbl)
		add_child(_shield_badge)

	# 3) Halka: Kendi köyü için Altın halka, İttifak için Mavi halka
	if is_player or is_alliance_member:
		_selection_ring = Panel.new()
		var ring_sz := Vector2(204, 204)
		_selection_ring.custom_minimum_size = ring_sz
		_selection_ring.size = ring_sz
		_selection_ring.position = _sprite.position + (SPRITE_SIZE - ring_sz) * 0.5
		_selection_ring.mouse_filter = MOUSE_FILTER_IGNORE
		_selection_ring.add_theme_stylebox_override("panel", _sb_ring_player if is_player else _sb_ring_ally)
		add_child(_selection_ring)

	# 4) Bilgi Plaketi (3 Kategori: Kendi Köyün / İttifak Üyelerin / Düşman)
	_info_card = PanelContainer.new()
	_info_card.custom_minimum_size = Vector2(280, 76)
	_info_card.size = Vector2(280, 76)
	_info_card.position = Vector2((size.x - 280.0) * 0.5, 312.0)
	_info_card.pivot_offset = Vector2(140, 38)
	_info_card.mouse_filter = MOUSE_FILTER_IGNORE
	_info_card.add_theme_stylebox_override("panel", _sb_card_player if is_player else (_sb_card_ally if is_alliance_member else _sb_card_enemy))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = MOUSE_FILTER_IGNORE

	# Satır 1: Kullanıcı / Sahip İsmi
	var owner_name: String = str(village_data.get("owner", ""))
	if owner_name.is_empty():
		owner_name = "Lord Gorkem" if is_player else "Düşman"

	_owner_label = Label.new()
	if is_player:
		_owner_label.text = "👑 " + owner_name
		_owner_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
	elif is_alliance_member:
		var tag_prefix := ("[" + alliance_tag + "] ") if not alliance_tag.is_empty() else ""
		_owner_label.text = "🤝 " + tag_prefix + owner_name
		_owner_label.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	else:
		_owner_label.text = "⚔️ " + owner_name
		_owner_label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.60))

	_owner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_owner_label.add_theme_font_override("font", FontNunitoBold)
	_owner_label.add_theme_font_size_override("font_size", 24)
	_owner_label.add_theme_constant_override("outline_size", 1)
	_owner_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_owner_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	vbox.add_child(_owner_label)

	# Satır 2: Köy İsmi ve Koordinat
	var v_name: String = str(village_data.get("name", "Köy"))
	var vx: int = int(village_data.get("x", 0))
	var vy: int = int(village_data.get("y", 0))

	_name_coord_label = Label.new()
	_name_coord_label.text = "%s (%d|%d)" % [v_name, vx, vy]
	_name_coord_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_coord_label.add_theme_font_override("font", FontNunitoBold)
	_name_coord_label.add_theme_font_size_override("font_size", 27)
	_name_coord_label.add_theme_constant_override("outline_size", 1)
	_name_coord_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_name_coord_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	_name_coord_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))

	vbox.add_child(_name_coord_label)

	_info_card.add_child(vbox)
	add_child(_info_card)


func _on_mouse_enter() -> void:
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(_sprite, "scale", Vector2(1.08, 1.08), 0.15)
	_hover_tween.tween_property(_sprite, "position:y", 2.0, 0.15)
	_hover_tween.tween_property(_info_card, "scale", Vector2(1.04, 1.04), 0.15)


func _on_mouse_exit() -> void:
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.15)
	_hover_tween.tween_property(_sprite, "position:y", 6.0, 0.15)
	_hover_tween.tween_property(_info_card, "scale", Vector2(1.0, 1.0), 0.15)


func get_button() -> Button:
	return _btn
