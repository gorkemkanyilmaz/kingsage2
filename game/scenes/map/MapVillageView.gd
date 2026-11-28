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
const LordModelScript := preload("res://scripts/model/LordModel.gd")
const FontNunitoBold := preload("res://assets/fonts/Nunito-Bold.ttf")

const SPRITE_SIZE := Vector2(296, 296)
const TOTAL_SIZE := Vector2(360, 410)

var village_data: Dictionary = {}
var is_player: bool = false
var is_alliance_member: bool = false
var is_barbarian: bool = false
var is_bandit: bool = false
var is_abandoned: bool = false
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
static var _sb_card_bandit: StyleBoxFlat
static var _sb_card_abandoned: StyleBoxFlat
static var _bandit_tex_cache: Dictionary = {}
static var _abandoned_tex_cache: Dictionary = {}


static func _desaturate_bandit_texture(src_tex: Texture2D) -> Texture2D:
	return _desaturate_texture_variant(src_tex, _bandit_tex_cache, 0.82, 0.92, 0.72)


static func _desaturate_abandoned_texture(src_tex: Texture2D) -> Texture2D:
	return _desaturate_texture_variant(src_tex, _abandoned_tex_cache, 0.92, 0.48, 0.92)


static func _desaturate_texture_variant(src_tex: Texture2D, cache: Dictionary, luma_scale: float, desat_mix: float, alpha_scale: float) -> Texture2D:
	if src_tex == null:
		return null
	var key := src_tex.resource_path
	if not key.is_empty() and cache.has(key):
		return cache[key] as Texture2D
	var img: Image = src_tex.get_image()
	if img == null:
		return src_tex
	img = img.duplicate() as Image
	if img.is_compressed():
		if img.decompress() != OK:
			return src_tex
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	for py in range(h):
		for px in range(w):
			var c: Color = img.get_pixel(px, py)
			var g: float = c.r * 0.299 + c.g * 0.587 + c.b * 0.114
			var target_g: float = g * luma_scale
			img.set_pixel(px, py, Color(
				lerpf(c.r, target_g, desat_mix),
				lerpf(c.g, target_g, desat_mix),
				lerpf(c.b, target_g, desat_mix),
				c.a * alpha_scale
			))
	var out_tex := ImageTexture.create_from_image(img)
	if not key.is_empty():
		cache[key] = out_tex
	return out_tex


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
	if _sb_card_bandit == null:
		_sb_card_bandit = _sb_card_player.duplicate() as StyleBoxFlat
		_sb_card_bandit.bg_color = Color(0.14, 0.14, 0.16, 0.88)
		_sb_card_bandit.border_color = Color(0.56, 0.56, 0.60, 0.85)
	if _sb_card_abandoned == null:
		_sb_card_abandoned = _sb_card_player.duplicate() as StyleBoxFlat
		_sb_card_abandoned.bg_color = Color(0.14, 0.13, 0.15, 0.90)
		_sb_card_abandoned.border_color = Color(0.72, 0.70, 0.66, 0.92)


func _init() -> void:
	custom_minimum_size = TOTAL_SIZE
	size = TOTAL_SIZE
	mouse_filter = MOUSE_FILTER_PASS


func setup(v_data: Dictionary, is_own: bool, is_ally: bool = false, ally_tag: String = "") -> void:
	village_data = v_data
	is_player = is_own
	is_alliance_member = is_ally
	alliance_tag = ally_tag
	is_bandit = (not is_own) and (bool(v_data.get("is_bandit", false)) or bool(v_data.get("is_bot", false)))
	var o_low := str(v_data.get("owner", "")).strip_edges().to_lower()
	is_abandoned = (not is_own) and (not is_bandit) and (
		bool(v_data.get("is_abandoned", false))
		or bool(v_data.get("is_barbarian", false))
		or o_low in ["", "barbar", "terk edilmiş", "terk edilmis", "terk edilmiş köy"]
	)
	is_barbarian = is_abandoned
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

	_ensure_shared_styles()
	if is_bandit:
		_sprite.material = null
		var d_tex := _desaturate_bandit_texture(_sprite.texture)
		if d_tex != null:
			_sprite.texture = d_tex
		_sprite.modulate = Color(0.84, 0.84, 0.88, 0.90)
	elif is_abandoned:
		_sprite.material = null
		var a_tex := _desaturate_abandoned_texture(_sprite.texture)
		if a_tex != null:
			_sprite.texture = a_tex
		_sprite.modulate = Color(0.92, 0.92, 0.94, 0.96)

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
	var card_style := _sb_card_player if is_player else (_sb_card_ally if is_alliance_member else (_sb_card_bandit if is_bandit else (_sb_card_abandoned if is_abandoned else _sb_card_enemy)))
	_info_card.add_theme_stylebox_override("panel", card_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = MOUSE_FILTER_IGNORE

	# Satır 1: Kullanıcı / Sahip İsmi
	var owner_name: String = str(village_data.get("owner", ""))
	if owner_name.is_empty():
		owner_name = "Lord Gorkem" if is_player else ("Terk Edilmiş" if is_abandoned else "Düşman")

	var bandit_lvl := LordModelScript.bandit_level_for_village(village_data) if is_bandit else 0

	_owner_label = Label.new()
	if is_player:
		_owner_label.text = "👑 " + owner_name
		_owner_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
	elif is_alliance_member:
		var tag_prefix := ("[" + alliance_tag + "] ") if not alliance_tag.is_empty() else ""
		_owner_label.text = "🤝 " + tag_prefix + owner_name
		_owner_label.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	elif is_bandit:
		_owner_label.text = "🏴 Haydut Köyü • Sv.%d" % bandit_lvl
		_owner_label.add_theme_color_override("font_color", Color(0.76, 0.78, 0.82))
	elif is_abandoned:
		_owner_label.text = "🏚️ Terk Edilmiş"
		_owner_label.add_theme_color_override("font_color", Color(0.84, 0.82, 0.78))
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
	var v_name: String = "Terk Edilmiş Köy" if is_abandoned else str(village_data.get("name", "Köy"))
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
