extends CanvasLayer
## TutorialManager — Baş Vezir Etkileşimli Başlangıç Rehberi (FTUE).
##
## Oyuna yeni başlayan oyunculara Baş Vezir eşliğinde konuşma balonu, dinamik
## spotlight odaklama ve yanıp sönen parmak işaretiyle:
##   1. Köy Düzeni & Üst Kaynak Çubuğu (Adım 0–3)
##   2. Ekonomi & Önkoşul Zinciri: Oduncu Kampı + Depo Sv.3 + Değirmen Sv.3 (Adım 4–7)
##   3. Dünya Haritası (Adım 8–10)
##   4. İttifak Sistemi (Adım 11–13)
##   5. Kışla İnşası, Silahtar Araştırması ve 10 Silahtar Eğitimi (Adım 14–17)
## süreçlerini adım adım öğretir.

const RulesEngineScript := preload("res://scripts/rules/RulesEngine.gd")
const EconomySimulatorScript := preload("res://scripts/sim/economy/EconomySimulator.gd")
const ArmySimulatorScript := preload("res://scripts/sim/army/ArmySimulator.gd")
const GameLoopScript := preload("res://scripts/core/GameLoop.gd")

const FontCinzelBold := preload("res://assets/fonts/Cinzel-Bold.ttf")
const FontNunitoBold := preload("res://assets/fonts/Nunito-Bold.ttf")
const FontNunitoSemiBold := preload("res://assets/fonts/Nunito-SemiBold.ttf")

const TexVizier := preload("res://assets/sprites/ui/tutorial/vizier_portrait.png")
const TexPointerHand := preload("res://assets/sprites/ui/tutorial/pointer_hand.png")
const TexRoyalSeal := preload("res://assets/sprites/ui/tutorial/royal_decree_seal.png")

enum Step {
	WELCOME_INTRO = 0,
	RESOURCE_BAR_TOUR = 1,
	SELECT_MAIN_CASTLE = 2,
	INSPECT_MAIN_PANEL = 3,
	SELECT_WOOD_CAMP = 4,
	UPGRADE_WOOD_CAMP = 5,
	CHECK_BARRACKS_REQS = 6,
	COMPLETE_BARRACKS_PREREQS = 7,
	OPEN_WORLD_MAP = 8,
	WORLD_MAP_TOUR = 9,
	RETURN_FROM_MAP = 10,
	OPEN_ALLIANCE = 11,
	ALLIANCE_TOUR = 12,
	RETURN_FROM_ALLIANCE = 13,
	BUILD_BARRACKS_LV1 = 14,
	RESEARCH_SPEAR = 15,
	TRAIN_10_SPEAR = 16,
	GRADUATION_MODAL = 17,
}

const TOTAL_VISIBLE_STEPS := 17
const TRACKED_SCENES := ["Village.tscn", "WorldMap.tscn", "Alliance.tscn"]

## Testler tarafından headless modda öğreticiyi açmak için kullanılır.
var tutorial_enabled_in_headless: bool = false

var _ui_built: bool = false
var _active: bool = false
var _current_step: int = Step.WELCOME_INTRO
var _shown_step: int = -1
var _shown_substate: String = ""
var _last_scene_path: String = ""
var _anim_time: float = 0.0
var _skip_confirm_until: float = 0.0
var _typewriter_tween: Tween = null
var _victory_reward_granted: bool = false

# UI Düğümleri
var _root_ctrl: Control
var _dim_top: ColorRect
var _dim_bottom: ColorRect
var _dim_left: ColorRect
var _dim_right: ColorRect
var _target_fx: Control
var _hand_sprite: TextureRect
var _hand_hint_pill: PanelContainer
var _hand_hint_label: Label

var _vizier_card: PanelContainer
var _vizier_portrait_box: PanelContainer
var _vizier_portrait: TextureRect
var _chapter_label: Label
var _step_label: Label
var _progress_bar: ProgressBar
var _btn_skip: Button
var _title_label: Label
var _dialogue_label: RichTextLabel
var _objective_panel: PanelContainer
var _objective_label: Label
var _action_row: HBoxContainer
var _btn_next: Button
var _btn_speedup: Button

var _victory_backdrop: ColorRect
var _victory_modal: PanelContainer
var _btn_finish: Button

var _current_target_rect: Rect2 = Rect2()
var _current_has_target: bool = false
var _last_valid_target_rect: Rect2 = Rect2()
var _last_valid_target_step: int = -1


class TargetFXDrawer extends Control:
	var target_rect: Rect2 = Rect2()
	var has_target: bool = false
	var anim_time: float = 0.0

	func _draw() -> void:
		if not has_target or target_rect.size.x <= 2.0 or target_rect.size.y <= 2.0:
			return
		var blink: float = 0.5 + 0.5 * sin(anim_time * 6.5)
		var pulse_grow: float = 4.0 + 7.0 * blink
		var box := target_rect.grow(pulse_grow)

		# Dış yumuşak altın hale (yanıp sönen)
		var halo := box.grow(6.0)
		draw_rect(halo, Color(1.0, 0.82, 0.25, 0.14 + 0.18 * blink), false, 6.0)

		# Ana parlak çerçeve
		var border_col := Color(1.0, 0.88, 0.38, 0.72 + 0.28 * blink)
		draw_rect(box, border_col, false, 3.5)

		# 4 Köşe süslü nişangah dirsekleri
		var clen := clampf(minf(box.size.x, box.size.y) * 0.26, 16.0, 38.0)
		var ccol := Color(1.0, 0.96, 0.65, 0.85 + 0.15 * blink)
		var w := 5.0
		var x0 := box.position.x
		var y0 := box.position.y
		var x1 := box.end.x
		var y1 := box.end.y
		# Sol üst
		draw_line(Vector2(x0, y0), Vector2(x0 + clen, y0), ccol, w)
		draw_line(Vector2(x0, y0), Vector2(x0, y0 + clen), ccol, w)
		# Sağ üst
		draw_line(Vector2(x1, y0), Vector2(x1 - clen, y0), ccol, w)
		draw_line(Vector2(x1, y0), Vector2(x1, y0 + clen), ccol, w)
		# Sol alt
		draw_line(Vector2(x0, y1), Vector2(x0 + clen, y1), ccol, w)
		draw_line(Vector2(x0, y1), Vector2(x0, y1 - clen), ccol, w)
		# Sağ alt
		draw_line(Vector2(x1, y1), Vector2(x1 - clen, y1), ccol, w)
		draw_line(Vector2(x1, y1), Vector2(x1, y1 - clen), ccol, w)

		# Hedef merkezinde genişleyen sonar dalgası
		var center := target_rect.get_center()
		# Geniş butonlarda metni kapatmamak için merkez nişangahını gizle; yalnız altın çerçeve + parmak yeter
		if not (target_rect.size.x >= 360.0 and target_rect.size.y <= 76.0):
			var ripple_t := fposmod(anim_time * 1.15, 1.0)
			var max_r := clampf(minf(target_rect.size.x, target_rect.size.y) * 0.45, 22.0, 56.0)
			var rad := lerpf(8.0, max_r, ripple_t)
			var r_col := Color(1.0, 0.90, 0.40, (1.0 - ripple_t) * 0.85)
			draw_arc(center, rad, 0.0, TAU, 36, r_col, 3.0)
			draw_circle(center, 7.0 + 3.0 * blink, Color(1.0, 0.94, 0.55, 0.55 + 0.35 * blink))


func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_set_overlay_visible(false)


# =============================================================================
#  UI OLUŞTURMA
# =============================================================================

func _build_ui() -> void:
	if _ui_built:
		return
	_ui_built = true

	_root_ctrl = Control.new()
	_root_ctrl.name = "TutorialRoot"
	_root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root_ctrl)

	# 4-panelli Spotlight Karartma Katmanı (tıklamaları engellemez)
	_dim_top = _make_dim_rect("DimTop")
	_dim_bottom = _make_dim_rect("DimBottom")
	_dim_left = _make_dim_rect("DimLeft")
	_dim_right = _make_dim_rect("DimRight")
	_root_ctrl.add_child(_dim_top)
	_root_ctrl.add_child(_dim_bottom)
	_root_ctrl.add_child(_dim_left)
	_root_ctrl.add_child(_dim_right)

	# Baş Vezir Konuşma Kartı
	_build_vizier_card()

	# Mezuniyet / Zafer Modalı (en üst katmanlardan biri, efektin altında veya tam ortada)
	_build_victory_modal()

	# Hedef Parlama & Nișangah Çizici (Vezir kartının üzerindeki butonları da işaretleyebilsin)
	_target_fx = TargetFXDrawer.new()
	_target_fx.name = "TargetFX"
	_target_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_target_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_ctrl.add_child(_target_fx)

	# Yanıp Sönen & İşaret Eden Kraliyet Eldiveni
	_hand_sprite = TextureRect.new()
	_hand_sprite.name = "PointerHand"
	_hand_sprite.texture = TexPointerHand
	_hand_sprite.custom_minimum_size = Vector2(98, 98)
	_hand_sprite.size = Vector2(98, 98)
	_hand_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hand_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hand_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_ctrl.add_child(_hand_sprite)

	# Parmak İpucu Etiketi
	_hand_hint_pill = PanelContainer.new()
	_hand_hint_pill.name = "HandHintPill"
	_hand_hint_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pill_sb := StyleBoxFlat.new()
	pill_sb.bg_color = Color(0.11, 0.08, 0.05, 0.96)
	pill_sb.border_color = Color(1.0, 0.84, 0.36, 1.0)
	pill_sb.set_border_width_all(2)
	pill_sb.set_corner_radius_all(12)
	pill_sb.content_margin_left = 14
	pill_sb.content_margin_right = 14
	pill_sb.content_margin_top = 6
	pill_sb.content_margin_bottom = 6
	pill_sb.shadow_color = Color(0, 0, 0, 0.65)
	pill_sb.shadow_size = 8
	_hand_hint_pill.add_theme_stylebox_override("panel", pill_sb)

	_hand_hint_label = Label.new()
	_hand_hint_label.text = "Dokunun"
	_hand_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand_hint_label.add_theme_font_override("font", FontNunitoBold)
	_hand_hint_label.add_theme_font_size_override("font_size", 21)
	_hand_hint_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.56))
	_hand_hint_label.add_theme_constant_override("outline_size", 0)
	_hand_hint_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	_hand_hint_pill.add_child(_hand_hint_label)
	_root_ctrl.add_child(_hand_hint_pill)


func _make_dim_rect(node_name: String) -> ColorRect:
	var r := ColorRect.new()
	r.name = node_name
	r.color = Color(0.015, 0.015, 0.04, 0.54)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _build_vizier_card() -> void:
	_vizier_card = PanelContainer.new()
	_vizier_card.name = "VizierCard"
	_vizier_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_vizier_card.size = Vector2(1040, 330)
	_vizier_card.position = Vector2(20, 148)

	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color = Color(0.09, 0.08, 0.12, 0.96)
	card_sb.border_color = Color(0.92, 0.76, 0.36, 0.98)
	card_sb.set_border_width_all(3)
	card_sb.set_corner_radius_all(20)
	card_sb.content_margin_left = 20
	card_sb.content_margin_right = 20
	card_sb.content_margin_top = 16
	card_sb.content_margin_bottom = 16
	card_sb.shadow_color = Color(0, 0, 0, 0.72)
	card_sb.shadow_size = 18
	card_sb.shadow_offset = Vector2(0, 6)
	_vizier_card.add_theme_stylebox_override("panel", card_sb)
	_root_ctrl.add_child(_vizier_card)

	var main_hbox := HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 18)
	main_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vizier_card.add_child(main_hbox)

	# Sol Sütun: Baş Vezir Portresi + Unvan Şeridi
	var left_col := VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 8)
	left_col.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	left_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_hbox.add_child(left_col)

	_vizier_portrait_box = PanelContainer.new()
	_vizier_portrait_box.custom_minimum_size = Vector2(148, 148)
	_vizier_portrait_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p_sb := StyleBoxFlat.new()
	p_sb.bg_color = Color(0.14, 0.10, 0.07, 1.0)
	p_sb.border_color = Color(0.96, 0.80, 0.38, 1.0)
	p_sb.set_border_width_all(3)
	p_sb.set_corner_radius_all(16)
	p_sb.content_margin_left = 4
	p_sb.content_margin_right = 4
	p_sb.content_margin_top = 4
	p_sb.content_margin_bottom = 4
	_vizier_portrait_box.add_theme_stylebox_override("panel", p_sb)
	left_col.add_child(_vizier_portrait_box)

	_vizier_portrait = TextureRect.new()
	_vizier_portrait.texture = TexVizier
	_vizier_portrait.custom_minimum_size = Vector2(138, 138)
	_vizier_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vizier_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_vizier_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vizier_portrait_box.add_child(_vizier_portrait)

	var nameplate := PanelContainer.new()
	nameplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var np_sb := StyleBoxFlat.new()
	np_sb.bg_color = Color(0.45, 0.10, 0.12, 0.98)
	np_sb.border_color = Color(0.92, 0.76, 0.38, 0.95)
	np_sb.set_border_width_all(2)
	np_sb.set_corner_radius_all(10)
	np_sb.content_margin_left = 8
	np_sb.content_margin_right = 8
	np_sb.content_margin_top = 4
	np_sb.content_margin_bottom = 4
	nameplate.add_theme_stylebox_override("panel", np_sb)
	left_col.add_child(nameplate)

	var np_lbl := Label.new()
	np_lbl.text = "BAŞ VEZİR"
	np_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	np_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	np_lbl.add_theme_font_override("font", FontCinzelBold)
	np_lbl.add_theme_font_size_override("font_size", 17)
	np_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.62))
	np_lbl.add_theme_constant_override("outline_size", 0)
	np_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	nameplate.add_child(np_lbl)

	# Sağ Sütun: Konuşma Balonu İçeriği
	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.add_theme_constant_override("separation", 10)
	right_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_hbox.add_child(right_col)

	# Üst Bilgi Satırı: Bölüm + Adım İlerleme + Atla Butonu
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 10)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_col.add_child(top_bar)

	var chap_pill := PanelContainer.new()
	chap_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ch_sb := StyleBoxFlat.new()
	ch_sb.bg_color = Color(0.22, 0.17, 0.08, 0.95)
	ch_sb.border_color = Color(0.85, 0.70, 0.35, 0.90)
	ch_sb.set_border_width_all(1)
	ch_sb.set_corner_radius_all(8)
	ch_sb.content_margin_left = 10
	ch_sb.content_margin_right = 10
	ch_sb.content_margin_top = 4
	ch_sb.content_margin_bottom = 4
	chap_pill.add_theme_stylebox_override("panel", ch_sb)
	top_bar.add_child(chap_pill)

	_chapter_label = Label.new()
	_chapter_label.text = "BÖLÜM 1/5 • KÖY DÜZENİ"
	_chapter_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chapter_label.add_theme_font_override("font", FontNunitoBold)
	_chapter_label.add_theme_font_size_override("font_size", 17)
	_chapter_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.48))
	_chapter_label.add_theme_constant_override("outline_size", 0)
	_chapter_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	chap_pill.add_child(_chapter_label)

	_step_label = Label.new()
	_step_label.text = "1/17"
	_step_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_step_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_step_label.add_theme_font_override("font", FontNunitoBold)
	_step_label.add_theme_font_size_override("font_size", 18)
	_step_label.add_theme_color_override("font_color", Color(0.82, 0.80, 0.74))
	_step_label.add_theme_constant_override("outline_size", 0)
	_step_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	top_bar.add_child(_step_label)

	_btn_skip = Button.new()
	_btn_skip.name = "BtnSkipTutorial"
	_btn_skip.text = "Atla ✕"
	_btn_skip.custom_minimum_size = Vector2(96, 36)
	_btn_skip.add_theme_font_override("font", FontNunitoBold)
	_btn_skip.add_theme_font_size_override("font_size", 17)
	_btn_skip.add_theme_constant_override("outline_size", 0)
	_btn_skip.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	_btn_skip.add_theme_color_override("font_color", Color(0.86, 0.78, 0.72))
	_btn_skip.add_theme_color_override("font_hover_color", Color(1.0, 0.90, 0.82))
	var sk_sb := StyleBoxFlat.new()
	sk_sb.bg_color = Color(0.20, 0.16, 0.22, 0.9)
	sk_sb.border_color = Color(0.50, 0.44, 0.52, 0.7)
	sk_sb.set_border_width_all(1)
	sk_sb.set_corner_radius_all(8)
	sk_sb.content_margin_left = 10
	sk_sb.content_margin_right = 10
	_btn_skip.add_theme_stylebox_override("normal", sk_sb)
	_btn_skip.add_theme_stylebox_override("hover", sk_sb)
	_btn_skip.add_theme_stylebox_override("pressed", sk_sb)
	_btn_skip.pressed.connect(_on_skip_pressed)
	top_bar.add_child(_btn_skip)

	# İlerleme Çubuğu
	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(0, 7)
	_progress_bar.max_value = TOTAL_VISIBLE_STEPS
	_progress_bar.value = 1
	_progress_bar.show_percentage = false
	_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.16, 0.14, 0.20, 1.0)
	pb_bg.set_corner_radius_all(4)
	var pb_fill := StyleBoxFlat.new()
	pb_fill.bg_color = Color(0.95, 0.76, 0.28, 1.0)
	pb_fill.set_corner_radius_all(4)
	_progress_bar.add_theme_stylebox_override("background", pb_bg)
	_progress_bar.add_theme_stylebox_override("fill", pb_fill)
	right_col.add_child(_progress_bar)

	# Başlık
	_title_label = Label.new()
	_title_label.text = "Taht ve Kılıç'a Hoş Geldiniz"
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.add_theme_font_override("font", FontCinzelBold)
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.58))
	_title_label.add_theme_constant_override("outline_size", 0)
	_title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	right_col.add_child(_title_label)

	# Vezir Konuşma Metni (net, gölgesiz, vurgulu BBCode)
	_dialogue_label = RichTextLabel.new()
	_dialogue_label.bbcode_enabled = true
	_dialogue_label.fit_content = true
	_dialogue_label.scroll_active = false
	_dialogue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialogue_label.custom_minimum_size = Vector2(760, 0)
	_dialogue_label.add_theme_font_override("normal_font", FontNunitoSemiBold)
	_dialogue_label.add_theme_font_override("bold_font", FontNunitoBold)
	_dialogue_label.add_theme_font_size_override("normal_font_size", 22)
	_dialogue_label.add_theme_font_size_override("bold_font_size", 22)
	_dialogue_label.add_theme_color_override("default_color", Color(0.96, 0.94, 0.88))
	_dialogue_label.add_theme_constant_override("outline_size", 0)
	right_col.add_child(_dialogue_label)

	# Görev Şeridi
	_objective_panel = PanelContainer.new()
	_objective_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var obj_sb := StyleBoxFlat.new()
	obj_sb.bg_color = Color(0.16, 0.13, 0.09, 0.95)
	obj_sb.border_color = Color(0.95, 0.78, 0.34, 0.95)
	obj_sb.border_width_left = 4
	obj_sb.border_width_top = 1
	obj_sb.border_width_right = 1
	obj_sb.border_width_bottom = 1
	obj_sb.set_corner_radius_all(10)
	obj_sb.content_margin_left = 14
	obj_sb.content_margin_right = 14
	obj_sb.content_margin_top = 8
	obj_sb.content_margin_bottom = 8
	_objective_panel.add_theme_stylebox_override("panel", obj_sb)
	right_col.add_child(_objective_panel)

	_objective_label = Label.new()
	_objective_label.text = "Görev: ..."
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_label.custom_minimum_size = Vector2(740, 0)
	_objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objective_label.add_theme_font_override("font", FontNunitoBold)
	_objective_label.add_theme_font_size_override("font_size", 21)
	_objective_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.50))
	_objective_label.add_theme_constant_override("outline_size", 0)
	_objective_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	_objective_panel.add_child(_objective_label)

	# Eylem Butonları Satırı
	_action_row = HBoxContainer.new()
	_action_row.add_theme_constant_override("separation", 12)
	_action_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_col.add_child(_action_row)

	_btn_speedup = Button.new()
	_btn_speedup.name = "BtnRoyalDecree"
	_btn_speedup.text = "⚡ Kraliyet Fermanı: Hemen Tamamla"
	_btn_speedup.icon = TexRoyalSeal
	_btn_speedup.expand_icon = true
	_btn_speedup.custom_minimum_size = Vector2(0, 54)
	_btn_speedup.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_action_button(_btn_speedup, Color(0.14, 0.48, 0.28, 1.0), Color(0.58, 0.94, 0.68, 1.0), Color(1, 1, 1))
	_btn_speedup.pressed.connect(_on_speedup_pressed)
	_btn_speedup.hide()
	_action_row.add_child(_btn_speedup)

	_btn_next = Button.new()
	_btn_next.name = "BtnTutorialNext"
	_btn_next.text = "Devam Et ➔"
	_btn_next.custom_minimum_size = Vector2(220, 54)
	_btn_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_action_button(_btn_next, Color(0.74, 0.54, 0.16, 1.0), Color(1.0, 0.88, 0.48, 1.0), Color(1.0, 0.98, 0.92))
	_btn_next.pressed.connect(_on_next_pressed)
	_btn_next.hide()
	_action_row.add_child(_btn_next)


func _style_action_button(btn: Button, bg: Color, border: Color, font_col: Color) -> void:
	btn.add_theme_font_override("font", FontNunitoBold)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_constant_override("outline_size", 1)
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	btn.add_theme_color_override("font_color", font_col)
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.95, 0.72))

	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.border_width_bottom = 4
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 6

	var sb_h := sb.duplicate() as StyleBoxFlat
	sb_h.bg_color = bg.lightened(0.14)
	var sb_p := sb.duplicate() as StyleBoxFlat
	sb_p.bg_color = bg.darkened(0.15)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_stylebox_override("pressed", sb_p)


func _build_victory_modal() -> void:
	_victory_backdrop = ColorRect.new()
	_victory_backdrop.name = "VictoryBackdrop"
	_victory_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_victory_backdrop.color = Color(0.01, 0.01, 0.03, 0.78)
	_victory_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_victory_backdrop.hide()
	_root_ctrl.add_child(_victory_backdrop)

	_victory_modal = PanelContainer.new()
	_victory_modal.name = "VictoryModal"
	_victory_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_victory_modal.custom_minimum_size = Vector2(920, 0)
	var m_sb := StyleBoxFlat.new()
	m_sb.bg_color = Color(0.10, 0.08, 0.13, 0.98)
	m_sb.border_color = Color(0.96, 0.80, 0.36, 1.0)
	m_sb.set_border_width_all(4)
	m_sb.set_corner_radius_all(24)
	m_sb.content_margin_left = 34
	m_sb.content_margin_right = 34
	m_sb.content_margin_top = 30
	m_sb.content_margin_bottom = 30
	m_sb.shadow_color = Color(0, 0, 0, 0.85)
	m_sb.shadow_size = 24
	_victory_modal.add_theme_stylebox_override("panel", m_sb)
	_victory_modal.hide()
	_root_ctrl.add_child(_victory_modal)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	_victory_modal.add_child(vbox)

	# Üst Arma & Portre İkilisi
	var crest_row := HBoxContainer.new()
	crest_row.alignment = BoxContainer.ALIGNMENT_CENTER
	crest_row.add_theme_constant_override("separation", 24)
	vbox.add_child(crest_row)

	var v_pic := TextureRect.new()
	v_pic.texture = TexVizier
	v_pic.custom_minimum_size = Vector2(140, 140)
	v_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	v_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crest_row.add_child(v_pic)

	var seal_pic := TextureRect.new()
	seal_pic.texture = TexRoyalSeal
	seal_pic.custom_minimum_size = Vector2(156, 156)
	seal_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	seal_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crest_row.add_child(seal_pic)

	var h_title := Label.new()
	h_title.text = "TEBRİKLER LORDUM! HAZIRSINIZ!"
	h_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h_title.add_theme_font_override("font", FontCinzelBold)
	h_title.add_theme_font_size_override("font_size", 32)
	h_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.42))
	h_title.add_theme_constant_override("outline_size", 0)
	h_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	vbox.add_child(h_title)

	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.custom_minimum_size = Vector2(820, 0)
	body.add_theme_font_override("normal_font", FontNunitoSemiBold)
	body.add_theme_font_override("bold_font", FontNunitoBold)
	body.add_theme_font_size_override("normal_font_size", 23)
	body.add_theme_font_size_override("bold_font_size", 23)
	body.add_theme_color_override("default_color", Color(0.95, 0.93, 0.88))
	body.text = "[b][color=#FFD86B]Lordum,[/color][/b] ilk birlikleriniz olan [b][color=#78F096]10 Silahtar[/color][/b] kışla avlusunda saf tuttu! Artık krallığınızı yönetmek için gereken her temeli öğrendiniz:"
	vbox.add_child(body)

	var checklist := PanelContainer.new()
	var cl_sb := StyleBoxFlat.new()
	cl_sb.bg_color = Color(0.14, 0.12, 0.18, 0.96)
	cl_sb.border_color = Color(0.45, 0.78, 0.52, 0.75)
	cl_sb.set_border_width_all(2)
	cl_sb.set_corner_radius_all(14)
	cl_sb.content_margin_left = 20
	cl_sb.content_margin_right = 20
	cl_sb.content_margin_top = 14
	cl_sb.content_margin_bottom = 14
	checklist.add_theme_stylebox_override("panel", cl_sb)
	vbox.add_child(checklist)

	var cl_lbl := Label.new()
	cl_lbl.text = "✓ Köy Düzeni & 15 Bina Stratejisi\n✓ Hammadde Ekonomisi & Gereksinim Zinciri (Depo & Değirmen Sv.3)\n✓ Dünya Haritası, Barbar Yağması & Sefer Yönetimi\n✓ İttifak Merkezi & Diplomasi\n✓ Kışla Kurulumu & 10 Silahtar Ordusu"
	cl_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cl_lbl.custom_minimum_size = Vector2(780, 0)
	cl_lbl.add_theme_font_override("font", FontNunitoSemiBold)
	cl_lbl.add_theme_font_size_override("font_size", 22)
	cl_lbl.add_theme_color_override("font_color", Color(0.84, 0.96, 0.86))
	cl_lbl.add_theme_constant_override("outline_size", 0)
	cl_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	checklist.add_child(cl_lbl)

	var reward_box := PanelContainer.new()
	var rw_sb := StyleBoxFlat.new()
	rw_sb.bg_color = Color(0.22, 0.16, 0.08, 0.95)
	rw_sb.border_color = Color(1.0, 0.84, 0.36, 0.95)
	rw_sb.set_border_width_all(2)
	rw_sb.set_corner_radius_all(14)
	rw_sb.content_margin_left = 18
	rw_sb.content_margin_right = 18
	rw_sb.content_margin_top = 12
	rw_sb.content_margin_bottom = 12
	reward_box.add_theme_stylebox_override("panel", rw_sb)
	vbox.add_child(reward_box)

	var rw_lbl := Label.new()
	rw_lbl.text = "🎁 Kraliyet Hazine Ödülü: +1.000 Odun • +1.000 Taş • +1.000 Demir"
	rw_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rw_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rw_lbl.custom_minimum_size = Vector2(780, 0)
	rw_lbl.add_theme_font_override("font", FontNunitoBold)
	rw_lbl.add_theme_font_size_override("font_size", 23)
	rw_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.45))
	rw_lbl.add_theme_constant_override("outline_size", 0)
	rw_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	reward_box.add_child(rw_lbl)

	_btn_finish = Button.new()
	_btn_finish.name = "BtnTutorialFinish"
	_btn_finish.text = "⚔️ Hükmetmeye Başla!"
	_btn_finish.custom_minimum_size = Vector2(0, 68)
	_style_action_button(_btn_finish, Color(0.18, 0.56, 0.30, 1.0), Color(0.62, 0.95, 0.70, 1.0), Color(1, 1, 1))
	_btn_finish.add_theme_font_size_override("font_size", 26)
	_btn_finish.pressed.connect(_on_graduation_finish_pressed)
	vbox.add_child(_btn_finish)


# =============================================================================
#  YAŞAM DÖNGÜSÜ & DURUM SENKRONİZASYONU
# =============================================================================

func is_tutorial_active() -> bool:
	return _active


func get_current_step() -> int:
	return _current_step


func start_tutorial() -> void:
	if not _ui_built:
		_build_ui()
	var gs := _gs()
	if gs != null:
		gs.player["tutorial_completed"] = false
		gs.player["tutorial_step"] = Step.WELCOME_INTRO
	_current_step = Step.WELCOME_INTRO
	_shown_step = -1
	_shown_substate = ""
	_victory_reward_granted = false
	_active = true
	_save_game()
	_refresh_tutorial(true)


func restart_tutorial() -> void:
	start_tutorial()


func skip_tutorial() -> void:
	var gs := _gs()
	if gs != null:
		gs.player["tutorial_completed"] = true
		gs.player["tutorial_step"] = Step.GRADUATION_MODAL
	_active = false
	_set_overlay_visible(false)
	_save_game()


func _set_overlay_visible(p_vis: bool) -> void:
	if _root_ctrl != null:
		_root_ctrl.visible = p_vis
	visible = p_vis


func _gs() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree and (loop as SceneTree).root != null:
		return (loop as SceneTree).root.get_node_or_null("GameState")
	return null


func _save_game() -> void:
	var loop := Engine.get_main_loop()
	if loop is SceneTree and (loop as SceneTree).root != null:
		var sm := (loop as SceneTree).root.get_node_or_null("SaveManager")
		if sm != null and sm.has_method("save_game"):
			sm.save_game()


func _current_scene_node() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	if tree.current_scene != null:
		return tree.current_scene
	if tutorial_enabled_in_headless and tree.root != null:
		for c in tree.root.get_children():
			var fname := c.scene_file_path.get_file()
			if fname in TRACKED_SCENES:
				return c
	return null


func _current_scene_name(scene_node: Node) -> String:
	if scene_node == null:
		return ""
	var fname := scene_node.scene_file_path.get_file()
	if not fname.is_empty():
		return fname
	return str(scene_node.name) + ".tscn"


func _process(delta: float) -> void:
	_anim_time += delta

	if _btn_skip != null and _skip_confirm_until > 0.0 and _anim_time > _skip_confirm_until:
		_skip_confirm_until = 0.0
		_btn_skip.text = "Atla ✕"

	if DisplayServer.get_name() == "headless" and not tutorial_enabled_in_headless:
		if visible:
			_set_overlay_visible(false)
		return

	var scene_node := _current_scene_node()
	var scene_name := _current_scene_name(scene_node)
	var gs := _gs()

	if gs == null or not gs.has_active_village() or not (scene_name in TRACKED_SCENES):
		_active = false
		_set_overlay_visible(false)
		return

	if bool(gs.player.get("tutorial_completed", false)):
		_active = false
		_set_overlay_visible(false)
		return

	if not _active or scene_name != _last_scene_path:
		_last_scene_path = scene_name
		_sync_from_gamestate(gs)
		_active = true
		_shown_step = -1
		_shown_substate = ""
		if scene_name == "Village.tscn" and _current_step == Step.SELECT_MAIN_CASTLE:
			if scene_node.has_method("focus_building_for_tutorial"):
				scene_node.focus_building_for_tutorial("main")

	_evaluate_progression(scene_node, scene_name, gs)

	if not _active:
		_set_overlay_visible(false)
		return

	_set_overlay_visible(true)
	_refresh_tutorial(false, scene_node, scene_name, gs)
	_update_visual_animations(delta, scene_node, scene_name, gs)


func _sync_from_gamestate(gs: Node) -> void:
	_current_step = clampi(int(gs.player.get("tutorial_step", Step.WELCOME_INTRO)), 0, Step.GRADUATION_MODAL)
	_victory_reward_granted = bool(gs.player.get("tutorial_reward_claimed", false))


func _advance_to(next_step: int, gs: Node, scene_node: Node = null) -> void:
	if _current_step == next_step:
		return
	_current_step = clampi(next_step, 0, Step.GRADUATION_MODAL)
	if gs != null:
		gs.player["tutorial_step"] = _current_step
		_save_game()
	_shown_step = -1
	_shown_substate = ""
	if scene_node != null and scene_node.has_method("focus_building_for_tutorial"):
		match _current_step:
			Step.SELECT_MAIN_CASTLE:
				scene_node.focus_building_for_tutorial("main")
			Step.SELECT_WOOD_CAMP:
				scene_node.focus_building_for_tutorial("wood")
			Step.CHECK_BARRACKS_REQS, Step.BUILD_BARRACKS_LV1, Step.RESEARCH_SPEAR, Step.TRAIN_10_SPEAR:
				scene_node.focus_building_for_tutorial("barracks")
	if _current_step == Step.OPEN_WORLD_MAP and scene_node != null:
		var bp = scene_node.get("building_panel")
		if bp != null and bp.visible:
			bp.hide()


func _ensure_min_resources(v: Dictionary, need_w: int, need_s: int, need_i: int) -> void:
	if v.is_empty():
		return
	var res: Dictionary = v.get("resources", {})
	var cw := int(res.get("wood", 0))
	var cs := int(res.get("stone", 0))
	var ci := int(res.get("iron", 0))
	if cw < need_w or cs < need_s or ci < need_i:
		res["wood"] = maxi(cw, need_w)
		res["stone"] = maxi(cs, need_s)
		res["iron"] = maxi(ci, need_i)
		v["resources"] = res
		var gs := _gs()
		if gs != null:
			gs._emit_resources_changed(int(v.get("id", -1)))


func _active_queues(gs: Node, q_type_filter: String = "") -> Array:
	var out: Array = []
	if gs == null:
		return out
	var vid: int = int(gs.active_village_id)
	for item in gs.queues:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if int((item as Dictionary).get("village_id", -1)) != vid:
			continue
		var qt := str((item as Dictionary).get("type", ""))
		if q_type_filter.is_empty() or qt == q_type_filter:
			out.append(item)
	out.sort_custom(func(a, b): return int(a.get("finish_unix", 0)) < int(b.get("finish_unix", 0)))
	return out


func _queued_unit_count(gs: Node, u_key: String) -> int:
	var total := 0
	for item in _active_queues(gs, "train"):
		if str((item as Dictionary).get("key", "")) == u_key:
			total += int((item as Dictionary).get("count", 0))
	return total


func _evaluate_progression(scene_node: Node, scene_name: String, gs: Node) -> void:
	var v: Dictionary = gs.get_active_village()
	if v.is_empty():
		return
	var bld: Dictionary = v.get("buildings", {})
	var bp = scene_node.get("building_panel") if scene_node != null else null
	var bp_visible: bool = (bp != null and bp.visible)
	var bp_key: String = str(bp.get("_current_key")) if bp_visible else ""

	# Yanlış sahnede kalınmışsa yumuşak kurtarma
	if scene_name == "Village.tscn":
		if _current_step == Step.WORLD_MAP_TOUR:
			_advance_to(Step.OPEN_WORLD_MAP, gs, scene_node)
			return
		elif _current_step == Step.RETURN_FROM_MAP:
			_advance_to(Step.OPEN_ALLIANCE, gs, scene_node)
			return
		elif _current_step == Step.ALLIANCE_TOUR:
			_advance_to(Step.OPEN_ALLIANCE, gs, scene_node)
			return
		elif _current_step == Step.RETURN_FROM_ALLIANCE:
			_advance_to(Step.BUILD_BARRACKS_LV1, gs, scene_node)
			return

	match _current_step:
		Step.SELECT_MAIN_CASTLE:
			if scene_name == "Village.tscn" and bp_visible and bp_key == "main":
				_advance_to(Step.INSPECT_MAIN_PANEL, gs, scene_node)

		Step.INSPECT_MAIN_PANEL:
			if scene_name == "Village.tscn" and not bp_visible:
				_advance_to(Step.SELECT_WOOD_CAMP, gs, scene_node)

		Step.SELECT_WOOD_CAMP:
			if int(bld.get("wood", 0)) >= 2:
				_advance_to(Step.CHECK_BARRACKS_REQS, gs, scene_node)
			elif scene_name == "Village.tscn" and bp_visible and bp_key == "wood":
				_advance_to(Step.UPGRADE_WOOD_CAMP, gs, scene_node)

		Step.UPGRADE_WOOD_CAMP:
			if int(bld.get("wood", 0)) >= 2:
				_advance_to(Step.CHECK_BARRACKS_REQS, gs, scene_node)

		Step.CHECK_BARRACKS_REQS:
			if int(bld.get("storage", 0)) >= 3 and int(bld.get("farm", 0)) >= 3:
				_advance_to(Step.OPEN_WORLD_MAP, gs, scene_node)
			elif scene_name == "Village.tscn" and bp_visible and bp_key == "barracks":
				_advance_to(Step.COMPLETE_BARRACKS_PREREQS, gs, scene_node)

		Step.COMPLETE_BARRACKS_PREREQS:
			if _active_queues(gs, "build").is_empty():
				_ensure_min_resources(v, 300, 350, 300)
			if int(bld.get("storage", 0)) >= 3 and int(bld.get("farm", 0)) >= 3:
				_advance_to(Step.OPEN_WORLD_MAP, gs, scene_node)

		Step.OPEN_WORLD_MAP:
			if scene_name == "WorldMap.tscn":
				_advance_to(Step.WORLD_MAP_TOUR, gs, scene_node)

		Step.RETURN_FROM_MAP:
			if scene_name == "Village.tscn":
				_advance_to(Step.OPEN_ALLIANCE, gs, scene_node)

		Step.OPEN_ALLIANCE:
			if scene_name == "Alliance.tscn":
				_advance_to(Step.ALLIANCE_TOUR, gs, scene_node)

		Step.RETURN_FROM_ALLIANCE:
			if scene_name == "Village.tscn":
				_advance_to(Step.BUILD_BARRACKS_LV1, gs, scene_node)

		Step.BUILD_BARRACKS_LV1:
			if int(bld.get("barracks", 0)) >= 1:
				_advance_to(Step.RESEARCH_SPEAR, gs, scene_node)
			elif _active_queues(gs, "build").is_empty():
				_ensure_min_resources(v, 250, 250, 200)

		Step.RESEARCH_SPEAR:
			if RulesEngineScript.is_researched(v, "spear"):
				_advance_to(Step.TRAIN_10_SPEAR, gs, scene_node)
			elif _active_queues(gs, "research").is_empty():
				_ensure_min_resources(v, 100, 100, 100)

		Step.TRAIN_10_SPEAR:
			var spear_cnt := int(v.get("units", {}).get("spear", 0))
			if spear_cnt >= 10:
				_advance_to(Step.GRADUATION_MODAL, gs, scene_node)
			elif _active_queues(gs, "train").is_empty():
				_ensure_min_resources(v, 260, 160, 360)


# =============================================================================
#  ADIM İÇERİĞİ VE HEDEF ÇÖZÜMLEME
# =============================================================================

func _compute_substate(scene_node: Node, scene_name: String, gs: Node) -> String:
	var v: Dictionary = gs.get_active_village()
	var bld: Dictionary = v.get("buildings", {})
	var bp = scene_node.get("building_panel") if scene_node != null else null
	var bp_vis: bool = (bp != null and bp.visible)
	var bp_key: String = str(bp.get("_current_key")) if bp_vis else ""
	var bp_tab: int = int(bp.get("_current_tab")) if bp_vis else -1
	var spin_val: int = 0
	if bp_vis and _current_step == Step.TRAIN_10_SPEAR:
		var sp := bp.find_child("Spin_spear", true, false) as SpinBox
		if sp != null:
			spin_val = int(sp.value)
	var q_build := _active_queues(gs, "build").size()
	var q_res := _active_queues(gs, "research").size()
	var q_train := _active_queues(gs, "train").size()
	return "%s|%s|%d|%d|%d|%d|%d|%d|%d|%d" % [
		scene_name, bp_key, bp_tab,
		int(bld.get("storage", 0)), int(bld.get("farm", 0)),
		int(bld.get("barracks", 0)), q_build, q_res, q_train, spin_val
	]


func _refresh_tutorial(force: bool, scene_node: Node = null, scene_name: String = "", gs: Node = null) -> void:
	if not _ui_built:
		_build_ui()
	if gs == null:
		gs = _gs()
	if gs == null or not gs.has_active_village():
		return
	if scene_node == null:
		scene_node = _current_scene_node()
		scene_name = _current_scene_name(scene_node)

	var sub := _compute_substate(scene_node, scene_name, gs)
	if not force and _shown_step == _current_step and _shown_substate == sub:
		return

	var step_changed := (_shown_step != _current_step)
	_shown_step = _current_step
	_shown_substate = sub

	if _current_step == Step.GRADUATION_MODAL:
		_show_graduation_modal(gs)
		return
	else:
		_victory_backdrop.hide()
		_victory_modal.hide()
		_vizier_card.show()

	var info := _get_step_copy(scene_node, scene_name, gs)
	_chapter_label.text = str(info["chapter"])
	_step_label.text = "%d / %d" % [mini(_current_step + 1, TOTAL_VISIBLE_STEPS), TOTAL_VISIBLE_STEPS]
	_progress_bar.value = float(mini(_current_step + 1, TOTAL_VISIBLE_STEPS))
	_title_label.text = str(info["title"])
	_objective_label.text = "🎯 Görev: " + str(info["objective"])

	var bbcode_txt := str(info["dialogue"])
	if step_changed:
		_dialogue_label.text = bbcode_txt
		_start_typewriter()
	elif _dialogue_label.text != bbcode_txt:
		_dialogue_label.text = bbcode_txt
		_dialogue_label.visible_ratio = 1.0

	var next_lbl := str(info.get("next_text", ""))
	if next_lbl.is_empty():
		_btn_next.hide()
	else:
		_btn_next.text = next_lbl
		_btn_next.show()

	var q_all := _active_queues(gs)
	if not q_all.is_empty():
		var head: Dictionary = q_all[0]
		var qt := str(head.get("type", ""))
		match qt:
			"build":
				_btn_speedup.text = "⚡ Kraliyet Fermanı: İnşaatı Tamamla"
			"research":
				_btn_speedup.text = "⚡ Kraliyet Fermanı: Araştırmayı Tamamla"
			"train":
				_btn_speedup.text = "⚡ Kraliyet Fermanı: Eğitimi Tamamla"
			_:
				_btn_speedup.text = "⚡ Kraliyet Fermanı: Hemen Tamamla"
		_btn_speedup.show()
	else:
		_btn_speedup.hide()

	_hand_hint_label.text = str(info.get("hint", "Dokunun"))


func _start_typewriter() -> void:
	if _typewriter_tween != null and _typewriter_tween.is_valid():
		_typewriter_tween.kill()
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		_dialogue_label.visible_ratio = 1.0
		return
	_dialogue_label.visible_ratio = 0.0
	_typewriter_tween = create_tween()
	_typewriter_tween.tween_property(_dialogue_label, "visible_ratio", 1.0, 0.42)


func _get_step_copy(scene_node: Node, _scene_name: String, gs: Node) -> Dictionary:
	var v: Dictionary = gs.get_active_village()
	var bld: Dictionary = v.get("buildings", {})
	var bp = scene_node.get("building_panel") if scene_node != null else null
	var bp_vis: bool = (bp != null and bp.visible)
	var bp_key: String = str(bp.get("_current_key")) if bp_vis else ""
	var bp_tab: int = int(bp.get("_current_tab")) if bp_vis else -1

	match _current_step:
		Step.WELCOME_INTRO:
			return {
				"chapter": "BÖLÜM 1/5 • KÖY DÜZENİ",
				"title": "Sancağınız Altında Yeni Bir Başlangıç",
				"dialogue": "[b][color=#FFD86B]Lordum,[/color][/b] Taht ve Kılıç diyarına hoş geldiniz! Köyümüzü büyütüp [b][color=#78F096]10 Silahtar[/color][/b] yetiştirinceye kadar size bizzat rehberlik edeceğim.",
				"objective": "Başlamak için 'Devam Et' düğmesine dokunun.",
				"next_text": "Devam Et ➔",
				"hint": "Başla"
			}

		Step.RESOURCE_BAR_TOUR:
			return {
				"chapter": "BÖLÜM 1/5 • KÖY DÜZENİ",
				"title": "Hazine, Depo ve Nüfus Dengesi",
				"dialogue": "[b][color=#FFD86B]Lordum,[/color][/b] üst şeritte sırasıyla [b]Odun, Taş, Demir[/b] stokunuz, [b]Depo tavanınız[/b] ve Değirmen'in besleyeceği [b]Boş Vatandaş[/b] sayınız yer alır.",
				"objective": "Kaynak çubuğunu inceleyin ve devam edin.",
				"next_text": "Anladım ➔",
				"hint": "Devam Et"
			}

		Step.SELECT_MAIN_CASTLE:
			if bp_vis and bp_key != "main":
				return {
					"chapter": "BÖLÜM 1/5 • KÖY DÜZENİ",
					"title": "Açık Pencereyi Kapatın",
					"dialogue": "[b][color=#FFD86B]Lordum,[/color][/b] önce açık olan bina penceresini sağ üstteki [b][color=#FFD86B]✕ (Kapat)[/color][/b] butonuna basarak kapatın.",
					"objective": "Sağ üstteki Kapat (✕) butonuna dokunun.",
					"next_text": "",
					"hint": "Pencereyi Kapat"
				}
			return {
				"chapter": "BÖLÜM 1/5 • KÖY DÜZENİ",
				"title": "Köy Yerleşimi ve Kale",
				"dialogue": "[b][color=#FFD86B]Lordum,[/color][/b] dağ yamacında [b]odun, taş ve demir[/b] ocakları; meydanda [b]Depo, Değirmen ve Kışla[/b]; zirvede ise tüm inşaatları hızlandıran [b]Kale[/b] bulunur.",
				"objective": "Köyün kalbi olan Kale'ye dokunun.",
				"next_text": "",
				"hint": "Kale'ye Dokun"
			}

		Step.INSPECT_MAIN_PANEL:
			return {
				"chapter": "BÖLÜM 1/5 • KÖY DÜZENİ",
				"title": "Bina Yönetim Paneli",
				"dialogue": "[b][color=#FFD86B]Lordum,[/color][/b] her binaya tıkladığınızda mevcut seviye, inşaat maliyeti ve üretim tabloları açılır. Şimdi paneli kapatıp üretime geçelim.",
				"objective": "Sağ üstteki Kapat (✕) düğmesine dokunun.",
				"next_text": "Kapat ve Devam Et ➔",
				"hint": "Paneli Kapat"
			}

		Step.SELECT_WOOD_CAMP:
			if bp_vis and bp_key != "wood":
				return {
					"chapter": "BÖLÜM 2/5 • EKONOMİ",
					"title": "Açık Pencereyi Kapatın",
					"dialogue": "[b][color=#FFD86B]Lordum,[/color][/b] Oduncu Kampı'na geçmeden önce açık olan bina penceresini sağ üstteki [b][color=#FFD86B]✕ (Kapat)[/color][/b] butonuna tıklayarak kapatın.",
					"objective": "Sağ üstteki Kapat (✕) butonuna dokunun.",
					"next_text": "",
					"hint": "Pencereyi Kapat"
				}
			return {
				"chapter": "BÖLÜM 2/5 • EKONOMİ",
				"title": "Hammadde Üretimini Artırmak",
				"dialogue": "[b][color=#FFD86B]Lordum,[/color][/b] askerlerimizin ve yeni binalarımızın kesintisiz keresteye ihtiyacı var. Sol orman kenarındaki [b][color=#FFD86B]Oduncu Kampı[/color][/b]'nı seçelim.",
				"objective": "Oduncu Kampı binasına dokunun.",
				"next_text": "",
				"hint": "Oduncu Kampı"
			}

		Step.UPGRADE_WOOD_CAMP:
			var wood_q := _active_queues(gs, "build")
			if not wood_q.is_empty():
				return {
					"chapter": "BÖLÜM 2/5 • EKONOMİ",
					"title": "Kraliyet Fermanı ile Hızlandırın",
					"dialogue": "[b][color=#FFD86B]Lordum,[/color][/b] inşaat sıraya alındı! Rehber süresince Kraliyet Hazinesi'nden [b][color=#78F096]ücretsiz tamamlama[/color][/b] yetkinizi kullanabilirsiniz.",
					"objective": "'Kraliyet Fermanı: İnşaatı Tamamla' butonuna dokunun.",
					"next_text": "",
					"hint": "Hemen Tamamla"
				}
			return {
				"chapter": "BÖLÜM 2/5 • EKONOMİ",
				"title": "Oduncu Kampını Seviye 2'ye Yükseltin",
				"dialogue": "[b][color=#FFD86B]Lordum,[/color][/b] Seviye 2 saatlik üretimi [b]120'den 134'e[/b] çıkarır. İnşaatı başlatmak için yeşil yükseltme butonuna dokunun.",
				"objective": "Oduncu Kampı'nı Seviye 2'ye yükseltin.",
				"next_text": "",
				"hint": "Yükselt (Sv. 2)"
			}

		Step.CHECK_BARRACKS_REQS:
			if bp_vis and bp_key != "barracks":
				return {
					"chapter": "BÖLÜM 2/5 • GEREKSİNİM ZİNCİRİ",
					"title": "Önce Oduncu Kampını Kapatın",
					"dialogue": "[b][color=#FFD86B]Lordum,[/color][/b] Oduncu Kampı Seviye 2 tamamlandı! Şimdi Kışla alanını görebilmek için sağ üstteki [b][color=#FFD86B]✕ (Kapat)[/color][/b] butonuna basarak bu pencereyi kapatın.",
					"objective": "Sağ üstteki Kapat (✕) butonuna dokunun.",
					"next_text": "",
					"hint": "Pencereyi Kapat"
				}
			return {
				"chapter": "BÖLÜM 2/5 • GEREKSİNİM ZİNCİRİ",
				"title": "Asker Yetiştirmek İçin Kışla",
				"dialogue": "[b][color=#FFD86B]Lordum,[/color][/b] ordumuzun belkemiği Silahtarları yetiştirmek için [b][color=#FFD86B]Kışla[/color][/b] kurmalıyız. Önce Kışla'nın hangi önkoşulları istediğine bakalım.",
				"objective": "Sol alttaki Kışla alanına dokunun.",
				"next_text": "",
				"hint": "Kışla'ya Dokun"
			}

		Step.COMPLETE_BARRACKS_PREREQS:
			var sto_lvl := int(bld.get("storage", 0))
			var frm_lvl := int(bld.get("farm", 0))
			var progress_str := "Depo (%d/3) • Değirmen (%d/3)" % [mini(sto_lvl, 3), mini(frm_lvl, 3)]
			if not _active_queues(gs, "build").is_empty():
				return {
					"chapter": "BÖLÜM 2/5 • GEREKSİNİM ZİNCİRİ",
					"title": "Altyapı İnşaatı Sürüyor",
					"dialogue": "[b][color=#FFD86B]Lordum,[/color][/b] ustalarımız gece gündüz çalışıyor. [b]Kraliyet Fermanı[/b] mührüne dokunarak inşaatı anında bitirebilirsiniz.",
					"objective": "%s — Ferman ile inşaatı tamamlayın." % progress_str,
					"next_text": "",
					"hint": "Hemen Tamamla"
				}
			if sto_lvl < 3:
				if bp_vis and bp_key == "barracks":
					return {
						"chapter": "BÖLÜM 2/5 • GEREKSİNİM ZİNCİRİ",
						"title": "Önkoşul Zinciri: Depo Sv. 3",
						"dialogue": "[b][color=#FFD86B]Lordum,[/color][/b] Kışla için [b]Depo Sv. 3[/b] ve [b]Değirmen Sv. 3[/b] şarttır. Aşağıdaki zincirden [b]'Binaya Git'[/b] ile doğrudan Depo'ya geçebilirsiniz!",
						"objective": "%s — Depo için 'Binaya Git ➔' butonuna dokunun." % progress_str,
						"next_text": "",
						"hint": "Binaya Git"
					}
				elif bp_vis and bp_key == "storage":
					return {
						"chapter": "BÖLÜM 2/5 • GEREKSİNİM ZİNCİRİ",
						"title": "Depoyu Güçlendiriyoruz",
						"dialogue": "[b][color=#FFD86B]Lordum,[/color][/b] Depo büyüdükçe daha çok hammadde saklarız. Şimdi [b]Seviye %d[/b] inşaatını başlatın!" % (sto_lvl + 1),
						"objective": "%s — Depo'yu yükseltin (Hedef: Sv. 3)." % progress_str,
						"next_text": "",
						"hint": "Depo Yükselt"
					}
				return {
					"chapter": "BÖLÜM 2/5 • GEREKSİNİM ZİNCİRİ",
					"title": "Hedef: Depo Seviye 3",
					"dialogue": "[b][color=#FFD86B]Lordum,[/color][/b] Kışla önkoşullarını tamamlamak için köy meydanındaki [b][color=#FFD86B]Depo[/color][/b] binasını açalım.",
					"objective": "%s — Köyde Depo binasına dokunun." % progress_str,
					"next_text": "",
					"hint": "Depo'ya Dokun"
				}
			# sto >= 3, farm < 3
			if bp_vis and bp_key == "barracks":
				return {
					"chapter": "BÖLÜM 2/5 • GEREKSİNİM ZİNCİRİ",
					"title": "İkinci Önkoşul: Değirmen Sv. 3",
					"dialogue": "[b][color=#FFD86B]Lordum,[/color][/b] Depo hazır! Şimdi vatandaş kapasitesi için zincirden [b]Değirmen[/b] binasına geçelim.",
					"objective": "%s — Değirmen için 'Binaya Git ➔' butonuna dokunun." % progress_str,
					"next_text": "",
					"hint": "Binaya Git"
				}
			elif bp_vis and bp_key == "farm":
				return {
					"chapter": "BÖLÜM 2/5 • GEREKSİNİM ZİNCİRİ",
					"title": "Değirmeni Büyütüyoruz",
					"dialogue": "[b][color=#FFD86B]Lordum,[/color][/b] Değirmen ne kadar büyükse o kadar çok asker besleriz! [b]Seviye %d[/b] inşaatını başlatın." % (frm_lvl + 1),
					"objective": "%s — Değirmen'i yükseltin (Hedef: Sv. 3)." % progress_str,
					"next_text": "",
					"hint": "Değirmen Yükselt"
				}
			return {
				"chapter": "BÖLÜM 2/5 • GEREKSİNİM ZİNCİRİ",
				"title": "Hedef: Değirmen Seviye 3",
				"dialogue": "[b][color=#FFD86B]Lordum,[/color][/b] harika! Şimdi sol üstteki [b][color=#FFD86B]Değirmen[/color][/b]'i seçip Seviye 3'e ulaştıralım.",
				"objective": "%s — Köyde Değirmen binasına dokunun." % progress_str,
				"next_text": "",
				"hint": "Değirmen'e Dokun"
			}

		Step.OPEN_WORLD_MAP:
			return {
				"chapter": "BÖLÜM 3/5 • DÜNYA HARİTASI",
				"title": "Sınırlarımızın Ötesini Keşfedin",
				"dialogue": "[b][color=#FFD86B]Lordum,[/color][/b] Kışla önkoşulları tamamlandı! Asker yetiştirmeden önce komşu köyleri ve yağma fırsatlarını [b][color=#FFD86B]Dünya Haritası[/color][/b]'nda görelim.",
				"objective": "Alt menüden 'Harita' sekmesine dokunun.",
				"next_text": "",
				"hint": "Harita Sekmesi"
			}

		Step.WORLD_MAP_TOUR:
			return {
				"chapter": "BÖLÜM 3/5 • DÜNYA HARİTASI",
				"title": "Köyler, Mesafe ve Sefer Düzeni",
				"dialogue": "[b][color=#FFD86B]Lordum,[/color][/b] ortadaki altın çerçeveli yerleşim sizin köyünüzdür. Gri [b]Barbar Köyleri[/b] yağma için idealdir; komşularla aramızda güvenli mesafe vardır. İstediğiniz köye tıklayıp [b]Saldırı, Casus veya Destek[/b] gönderebilirsiniz.",
				"objective": "Haritayı inceledikten sonra devam edin.",
				"next_text": "Anladım ➔",
				"hint": "Devam Et"
			}

		Step.RETURN_FROM_MAP:
			return {
				"chapter": "BÖLÜM 3/5 • DÜNYA HARİTASI",
				"title": "Diplomasi Hazırlığı",
				"dialogue": "[b][color=#FFD86B]Lordum,[/color][/b] diyarda tek başımıza değiliz. Şimdi köyümüze dönüp [b]İttifak Sistemi[/b]'ni tanıyalım.",
				"objective": "Alt menüden 'Köy' sekmesine dokunun.",
				"next_text": "",
				"hint": "Köye Dön"
			}

		Step.OPEN_ALLIANCE:
			return {
				"chapter": "BÖLÜM 4/5 • İTTİFAK SİSTEMİ",
				"title": "Birlikten Kuvvet Doğar",
				"dialogue": "[b][color=#FFD86B]Lordum,[/color][/b] güçlü ittifaklar savaşlarda omuz omuza çarpışır ve köyleri korur. Sağ üstteki [b][color=#78C8FF]İttifak[/color][/b] kapısını aralayalım.",
				"objective": "Sağ üstteki 'İttifak' butonuna dokunun.",
				"next_text": "",
				"hint": "İttifak Merkezi"
			}

		Step.ALLIANCE_TOUR:
			return {
				"chapter": "BÖLÜM 4/5 • İTTİFAK SİSTEMİ",
				"title": "İttifak Kurma, Katılma ve Sohbet",
				"dialogue": "[b][color=#FFD86B]Lordum,[/color][/b] buradan kendi [b]İttifakınızı Kurabilir[/b] (isim ve 6 harfli etiket) veya [b]İttifak Bul & Davetler[/b] sekmesinden güçlü birliklere katılıp ortak sohbetten sefer planlayabilirsiniz!",
				"objective": "İttifak ekranını inceleyin ve devam edin.",
				"next_text": "Devam Et ➔",
				"hint": "Devam Et"
			}

		Step.RETURN_FROM_ALLIANCE:
			return {
				"chapter": "BÖLÜM 4/5 • İTTİFAK SİSTEMİ",
				"title": "Artık Ordu Zamanı!",
				"dialogue": "[b][color=#FFD86B]Lordum,[/color][/b] diplomasiyi öğrendiniz! Şimdi köyümüze dönüp [b]Kışla[/b]'yı kuralım ve ilk ordumuzu toplayalım.",
				"objective": "Alt menüden 'Köy' sekmesine dokunun.",
				"next_text": "",
				"hint": "Köye Dön"
			}

		Step.BUILD_BARRACKS_LV1:
			if not _active_queues(gs, "build").is_empty():
				return {
					"chapter": "BÖLÜM 5/5 • KIŞLA VE ORDU",
					"title": "Kışla İnşası Başladı!",
					"dialogue": "[b][color=#FFD86B]Lordum,[/color][/b] Kışla taşları döşeniyor! Kraliyet Fermanı ile inşaatı hemen tamamlayın.",
					"objective": "'Kraliyet Fermanı' ile Kışla Sv. 1'i tamamlayın.",
					"next_text": "",
					"hint": "Hemen Tamamla"
				}
			if bp_vis and bp_key == "barracks":
				return {
					"chapter": "BÖLÜM 5/5 • KIŞLA VE ORDU",
					"title": "Kışlayı İnşa Edin",
					"dialogue": "[b][color=#FFD86B]Lordum,[/color][/b] tüm önkoşullar yeşil yandı! Şimdi [b]Seviye 1 Kışla[/b] inşaatını başlatın.",
					"objective": "'Yükselt (Seviye 1)' butonuna dokunun.",
					"next_text": "",
					"hint": "Kışla İnşa Et"
				}
			return {
				"chapter": "BÖLÜM 5/5 • KIŞLA VE ORDU",
				"title": "Kışla İnşaatını Başlatın",
				"dialogue": "[b][color=#FFD86B]Lordum,[/color][/b] Depo ve Değirmen hazır. Sol alttaki [b][color=#FFD86B]Kışla[/color][/b] alanına tıklayıp binamızı kuralım!",
				"objective": "Köyde Kışla alanına dokunun.",
				"next_text": "",
				"hint": "Kışla'ya Dokun"
			}

		Step.RESEARCH_SPEAR:
			if not _active_queues(gs, "research").is_empty():
				return {
					"chapter": "BÖLÜM 5/5 • KIŞLA VE ORDU",
					"title": "Silahtar Araştırması Sürüyor",
					"dialogue": "[b][color=#FFD86B]Lordum,[/color][/b] talim subayları mızrak taktiklerini derliyor. Ferman ile araştırmayı tamamlayın!",
					"objective": "'Kraliyet Fermanı' ile araştırmayı tamamlayın.",
					"next_text": "",
					"hint": "Hemen Tamamla"
				}
			if not bp_vis or bp_key != "barracks":
				return {
					"chapter": "BÖLÜM 5/5 • KIŞLA VE ORDU",
					"title": "Birim Araştırması",
					"dialogue": "[b][color=#FFD86B]Lordum,[/color][/b] bir asker türünü eğitebilmek için önce Kışla'da araştırmamız gerekir. [b]Kışla[/b]'yı açalım.",
					"objective": "Köyde Kışla binasına dokunun.",
					"next_text": "",
					"hint": "Kışla'yı Aç"
				}
			if bp_tab != 1: # BuildingPanel.Tab.RESEARCH
				return {
					"chapter": "BÖLÜM 5/5 • KIŞLA VE ORDU",
					"title": "Araştırma Sekmesine Geçin",
					"dialogue": "[b][color=#FFD86B]Lordum,[/color][/b] Kışla'nın üst sekmelerinden [b]'📜 Birim Araştır'[/b] bölümüne dokunarak askeri teknolojileri açın.",
					"objective": "'Birim Araştır' sekmesine dokunun.",
					"next_text": "",
					"hint": "Araştır Sekmesi"
				}
			return {
				"chapter": "BÖLÜM 5/5 • KIŞLA VE ORDU",
				"title": "Silahtar Birliğini Araştırın",
				"dialogue": "[b][color=#FFD86B]Lordum,[/color][/b] [b]🛡️ Silahtar[/b] hızlı, ekonomik ve köyümüzün ilk savunma kalkanıdır. Araştırmayı başlatın!",
				"objective": "Silahtar satırındaki '🔬 Araştır' butonuna dokunun.",
				"next_text": "",
				"hint": "Silahtar Araştır"
			}

		Step.TRAIN_10_SPEAR:
			var have := int(v.get("units", {}).get("spear", 0))
			var queued := _queued_unit_count(gs, "spear")
			var needed := maxi(0, 10 - have)
			if not _active_queues(gs, "train").is_empty():
				return {
					"chapter": "BÖLÜM 5/5 • 10 SİLAHTAR",
					"title": "Silahtarlar Silah Başına!",
					"dialogue": "[b][color=#FFD86B]Lordum,[/color][/b] eğitim davulları çalıyor! İlk birliğimizi hemen kışla avlusuna çağırmak için Fermanı kullanın.",
					"objective": "Eğitimi tamamlamak için 'Kraliyet Fermanı'na dokunun (%d/10)." % mini(10, have + queued),
					"next_text": "",
					"hint": "Hemen Tamamla"
				}
			if not bp_vis or bp_key != "barracks":
				return {
					"chapter": "BÖLÜM 5/5 • 10 SİLAHTAR",
					"title": "İlk Ordumuzu Toplayalım",
					"dialogue": "[b][color=#FFD86B]Lordum,[/color][/b] Silahtar araştırıldı! Şimdi [b]10 adet Silahtar[/b] eğitmek için Kışla'yı açalım.",
					"objective": "Köyde Kışla binasına dokunun (%d/10 Silahtar)." % have,
					"next_text": "",
					"hint": "Kışla'yı Aç"
				}
			if bp_tab != 2: # BuildingPanel.Tab.TRAIN
				return {
					"chapter": "BÖLÜM 5/5 • 10 SİLAHTAR",
					"title": "Eğitim Sekmesine Geçin",
					"dialogue": "[b][color=#FFD86B]Lordum,[/color][/b] üst sekmeden [b]'⚔️ Birim Eğit'[/b] bölümüne geçerek Silahtar yetiştirmeye başlayabilirsiniz.",
					"objective": "'Birim Eğit' sekmesine dokunun (%d/10 Silahtar)." % have,
					"next_text": "",
					"hint": "Eğitim Sekmesi"
				}
			var spin_val := 0
			var sp := bp.find_child("Spin_spear", true, false) as SpinBox
			if sp != null:
				spin_val = int(sp.value)
			if spin_val < needed:
				return {
					"chapter": "BÖLÜM 5/5 • 10 SİLAHTAR",
					"title": "Silahtar Sayısını Belirleyin",
					"dialogue": "[b][color=#FFD86B]Lordum,[/color][/b] Silahtar kartındaki [b]+10[/b] hızlı seçme butonuna basarak tam [b]10 Silahtar[/b] seçin.",
					"objective": "Silahtar miktarını %d yapın (+10 butonuna dokunun)." % needed,
					"next_text": "",
					"hint": "+10 Seçin"
				}
			return {
				"chapter": "BÖLÜM 5/5 • 10 SİLAHTAR",
				"title": "Eğitimi Başlatın!",
				"dialogue": "[b][color=#FFD86B]Lordum,[/color][/b] [b]%d Silahtar[/b] için kılıçlar ve kalkanlar hazır! Yeşil '⚔️ Eğit' butonuna basarak emri verin." % spin_val,
				"objective": "Silahtar kartındaki '⚔️ Eğit' butonuna dokunun.",
				"next_text": "",
				"hint": "10 Silahtar Eğit"
			}

	return {
		"chapter": "TAHT VE KILIÇ",
		"title": "Rehber",
		"dialogue": "[b][color=#FFD86B]Lordum,[/color][/b] sıradaki göreve geçebilirsiniz.",
		"objective": "Devam edin.",
		"next_text": "Devam Et ➔",
		"hint": "Dokunun"
	}


# =============================================================================
#  CANLI HEDEF BULMA & ANIMASYON DÖNGÜSÜ
# =============================================================================

func _resolve_target_control(scene_node: Node, scene_name: String, gs: Node) -> Control:
	if _current_step == Step.GRADUATION_MODAL:
		return null

	# Aktif kuyruk varsa ve Royal Decree hızlandırma butonu görünürse doğrudan onu işaret et
	if _btn_speedup != null and _btn_speedup.visible and _current_step in [
		Step.UPGRADE_WOOD_CAMP,
		Step.COMPLETE_BARRACKS_PREREQS,
		Step.BUILD_BARRACKS_LV1,
		Step.RESEARCH_SPEAR,
		Step.TRAIN_10_SPEAR,
	]:
		return _btn_speedup

	var v: Dictionary = gs.get_active_village() if gs != null else {}
	var bld: Dictionary = v.get("buildings", {})
	var bp = scene_node.get("building_panel") if scene_node != null else null
	var bp_vis: bool = (bp != null and bp.visible)
	var bp_key: String = str(bp.get("_current_key")) if bp_vis else ""
	var bp_tab: int = int(bp.get("_current_tab")) if bp_vis else -1

	match _current_step:
		Step.WELCOME_INTRO:
			return _btn_next

		Step.RESOURCE_BAR_TOUR:
			if scene_node != null and scene_node.has_node("ResourceBar"):
				return scene_node.get_node("ResourceBar") as Control
			return _btn_next

		Step.SELECT_MAIN_CASTLE:
			if bp_vis and bp_key != "main":
				return bp.get_node_or_null("VBox/Header/CloseButton") as Control
			return _building_view_ctrl(scene_node, "main")

		Step.INSPECT_MAIN_PANEL:
			if bp_vis and bp.has_node("VBox/Header/CloseButton"):
				return bp.get_node("VBox/Header/CloseButton") as Control
			return _btn_next

		Step.SELECT_WOOD_CAMP:
			if bp_vis and bp_key != "wood":
				return bp.get_node_or_null("VBox/Header/CloseButton") as Control
			return _building_view_ctrl(scene_node, "wood")

		Step.UPGRADE_WOOD_CAMP:
			if bp_vis and bp_key == "wood":
				return bp.get_node_or_null("VBox/UpgradeButton") as Control
			if bp_vis:
				return bp.get_node_or_null("VBox/Header/CloseButton") as Control
			return _building_view_ctrl(scene_node, "wood")

		Step.CHECK_BARRACKS_REQS:
			if bp_vis and bp_key != "barracks":
				return bp.get_node_or_null("VBox/Header/CloseButton") as Control
			return _building_view_ctrl(scene_node, "barracks")

		Step.COMPLETE_BARRACKS_PREREQS:
			var sto_lvl := int(bld.get("storage", 0))
			var need_key := "storage" if sto_lvl < 3 else "farm"
			if bp_vis and bp_key == "barracks":
				var gbtn := bp.find_child("GotoBtn_" + need_key, true, false) as Control
				if gbtn != null and gbtn.visible:
					return gbtn
			if bp_vis and bp_key == need_key:
				return bp.get_node_or_null("VBox/UpgradeButton") as Control
			if bp_vis:
				return bp.get_node_or_null("VBox/Header/CloseButton") as Control
			return _building_view_ctrl(scene_node, need_key)

		Step.OPEN_WORLD_MAP:
			if bp_vis:
				return bp.get_node_or_null("VBox/Header/CloseButton") as Control
			return _bottom_nav_btn(scene_node, "BtnMap")

		Step.WORLD_MAP_TOUR:
			if scene_name == "WorldMap.tscn" and scene_node != null and scene_node.has_node("Legend"):
				return scene_node.get_node("Legend") as Control
			return _btn_next

		Step.RETURN_FROM_MAP:
			return _bottom_nav_btn(scene_node, "BtnVillage")

		Step.OPEN_ALLIANCE:
			if bp_vis:
				return bp.get_node_or_null("VBox/Header/CloseButton") as Control
			if scene_node != null and scene_node.has_node("BtnAlliance"):
				return scene_node.get_node("BtnAlliance") as Control

		Step.ALLIANCE_TOUR:
			if scene_name == "Alliance.tscn" and scene_node != null and scene_node.has_node("MainContainer/Header"):
				return scene_node.get_node("MainContainer/Header") as Control
			return _btn_next

		Step.RETURN_FROM_ALLIANCE:
			return _bottom_nav_btn(scene_node, "BtnVillage")

		Step.BUILD_BARRACKS_LV1:
			if bp_vis and bp_key == "barracks":
				return bp.get_node_or_null("VBox/UpgradeButton") as Control
			if bp_vis:
				return bp.get_node_or_null("VBox/Header/CloseButton") as Control
			return _building_view_ctrl(scene_node, "barracks")

		Step.RESEARCH_SPEAR:
			if not bp_vis:
				return _building_view_ctrl(scene_node, "barracks")
			if bp_key != "barracks":
				return bp.get_node_or_null("VBox/Header/CloseButton") as Control
			if bp_tab != 1:
				return bp.get_node_or_null("VBox/TabBar/TabResearchBtn") as Control
			if bp.has_method("scroll_to_unit_card"):
				bp.scroll_to_unit_card("spear")
			return bp.find_child("ResearchBtn_spear", true, false) as Control

		Step.TRAIN_10_SPEAR:
			if not bp_vis:
				return _building_view_ctrl(scene_node, "barracks")
			if bp_key != "barracks":
				return bp.get_node_or_null("VBox/Header/CloseButton") as Control
			if bp_tab != 2:
				return bp.get_node_or_null("VBox/TabBar/TabTrainBtn") as Control
			if bp.has_method("scroll_to_unit_card"):
				bp.scroll_to_unit_card("spear")
			var have := int(v.get("units", {}).get("spear", 0))
			var needed := maxi(1, 10 - have)
			var sp := bp.find_child("Spin_spear", true, false) as SpinBox
			var cur_val := int(sp.value) if sp != null else 0
			if cur_val < needed:
				if needed <= 4:
					return bp.find_child("BtnPlus1_spear", true, false) as Control
				elif needed <= 9:
					return bp.find_child("BtnPlus5_spear", true, false) as Control
				return bp.find_child("BtnPlus10_spear", true, false) as Control
			return bp.find_child("TrainBtn_spear", true, false) as Control

	return _btn_next


func _building_view_ctrl(scene_node: Node, b_key: String) -> Control:
	if scene_node == null:
		return null
	if scene_node.has_method("get_building_view"):
		var bv = scene_node.get_building_view(b_key)
		if bv is Control:
			return bv as Control
	return scene_node.find_child("BuildingView_" + b_key, true, false) as Control


func _bottom_nav_btn(scene_node: Node, btn_name: String) -> Control:
	if scene_node == null:
		return null
	var bnav := scene_node.get_node_or_null("BottomNav")
	if bnav == null:
		return null
	return bnav.find_child(btn_name, true, false) as Control


func _update_visual_animations(delta: float, scene_node: Node, scene_name: String, gs: Node) -> void:
	var vp_rect := get_viewport().get_visible_rect()
	var vp_size := vp_rect.size
	if vp_size.x <= 10.0 or vp_size.y <= 10.0:
		vp_size = Vector2(1080.0, 1920.0)

	if _current_step == Step.GRADUATION_MODAL:
		_dim_top.hide()
		_dim_bottom.hide()
		_dim_left.hide()
		_dim_right.hide()
		_target_fx.has_target = false
		_target_fx.queue_redraw()
		_hand_sprite.hide()
		_hand_hint_pill.hide()
		var min_sz := _victory_modal.get_combined_minimum_size()
		var m_size := Vector2(920.0, clampf(min_sz.y, 580.0, 960.0))
		_victory_modal.size = m_size
		_victory_modal.position = Vector2((vp_size.x - m_size.x) * 0.5, (vp_size.y - m_size.y) * 0.5)
		return

	if _last_valid_target_step != _current_step:
		_last_valid_target_step = _current_step
		_last_valid_target_rect = Rect2()

	var target_ctrl := _resolve_target_control(scene_node, scene_name, gs)
	var has_target := (target_ctrl != null and target_ctrl.is_inside_tree() and target_ctrl.visible)
	var t_rect := Rect2()
	if has_target:
		t_rect = target_ctrl.get_global_rect()
		if t_rect.size.x < 12.0 or t_rect.size.y < 12.0 or (t_rect.position.length_squared() < 2.0 and target_ctrl != _dim_top):
			if _last_valid_target_rect.size.x >= 12.0 and _last_valid_target_rect.size.y >= 12.0:
				t_rect = _last_valid_target_rect
			else:
				has_target = false
		else:
			_last_valid_target_rect = t_rect

	# Baş Vezir kartını hedefi veya açık BuildingPanel'i kapatmayacak şekilde konumlandır
	var bp = scene_node.get("building_panel") if scene_node != null else null
	var bp_vis: bool = (bp != null and bp.visible)
	var card_w := clampf(vp_size.x - 36.0, 560.0, 1044.0)
	_vizier_card.custom_minimum_size = Vector2(card_w, 0.0)
	var min_card_h := _vizier_card.get_combined_minimum_size().y
	var card_h := clampf(min_card_h, 250.0, 390.0)
	_vizier_card.size = Vector2(card_w, card_h)

	var dock_bottom := false
	if bp_vis:
		dock_bottom = false
	elif _current_step in [Step.WELCOME_INTRO, Step.WORLD_MAP_TOUR, Step.ALLIANCE_TOUR, Step.RESOURCE_BAR_TOUR, Step.SELECT_MAIN_CASTLE, Step.OPEN_ALLIANCE]:
		dock_bottom = true
	elif has_target and target_ctrl != _btn_next and target_ctrl != _btn_speedup:
		dock_bottom = (t_rect.get_center().y < vp_size.y * 0.44)

	var safe_top := 0.0
	var safe_bottom := 0.0
	var gc_node = Engine.get_main_loop().root.get_node_or_null("GameConfig") if Engine.get_main_loop() is SceneTree else null
	if gc_node != null:
		if gc_node.has_method("get_ios_safe_top"):
			safe_top = float(gc_node.get_ios_safe_top())
		if gc_node.has_method("get_ios_safe_bottom"):
			safe_bottom = float(gc_node.get_ios_safe_bottom())
	var target_card_y := (146.0 + safe_top) if not dock_bottom else clampf(vp_size.y - 266.0 - safe_bottom - card_h, 520.0, vp_size.y - safe_bottom - card_h - 20.0)
	var target_card_x := (vp_size.x - card_w) * 0.5
	if _vizier_card.position.distance_to(Vector2(target_card_x, target_card_y)) > 260.0 or DisplayServer.get_name() == "headless":
		_vizier_card.position = Vector2(target_card_x, target_card_y)
	else:
		_vizier_card.position = _vizier_card.position.lerp(Vector2(target_card_x, target_card_y), clampf(delta * 14.0, 0.0, 1.0))

	# Tour adımlarında (Karşılama / Harita / İttifak / ResourceBar): spotlight büyük alanı aydınlatırken parmağı 'Devam Et' butonuna tut
	var passive_welcome := (_current_step == Step.WELCOME_INTRO)
	var spotlight_rect := t_rect
	var finger_ctrl := target_ctrl
	if _current_step in [Step.WELCOME_INTRO, Step.RESOURCE_BAR_TOUR, Step.WORLD_MAP_TOUR, Step.ALLIANCE_TOUR] and _btn_next != null and _btn_next.visible:
		finger_ctrl = _btn_next
		t_rect = _btn_next.get_global_rect()

	# Vezir portre çerçevesinde hafif canlı altın parıltı
	if _vizier_portrait_box != null:
		var pulse_g := 0.94 + 0.06 * sin(_anim_time * 2.4)
		_vizier_portrait_box.self_modulate = Color(pulse_g, pulse_g, pulse_g, 1.0)

	# Spotlight karartma panelleri: İlk sahnede köy/Kale tamamen pasif karartılmış kalsın
	if passive_welcome:
		_dim_top.show()
		_dim_top.position = Vector2.ZERO
		_dim_top.size = vp_size
		_dim_bottom.hide()
		_dim_left.hide()
		_dim_right.hide()
	elif has_target:
		var hole := spotlight_rect.grow(10.0).intersection(Rect2(Vector2.ZERO, vp_size))
		_dim_top.show()
		_dim_bottom.show()
		_dim_left.show()
		_dim_right.show()
		_dim_top.position = Vector2.ZERO
		_dim_top.size = Vector2(vp_size.x, hole.position.y)
		_dim_bottom.position = Vector2(0.0, hole.end.y)
		_dim_bottom.size = Vector2(vp_size.x, maxf(0.0, vp_size.y - hole.end.y))
		_dim_left.position = Vector2(0.0, hole.position.y)
		_dim_left.size = Vector2(hole.position.x, hole.size.y)
		_dim_right.position = Vector2(hole.end.x, hole.position.y)
		_dim_right.size = Vector2(maxf(0.0, vp_size.x - hole.end.x), hole.size.y)
	else:
		_dim_top.hide()
		_dim_bottom.hide()
		_dim_left.hide()
		_dim_right.hide()

	# Hedef çizici & Yanıp Sönen Parmak Eldiveni
	var finger_rect := t_rect if (finger_ctrl != null and finger_ctrl.is_inside_tree() and finger_ctrl.visible) else Rect2()
	if has_target and finger_rect.size.x > 12.0 and finger_rect.size.y > 12.0:
		_current_has_target = true
		_current_target_rect = finger_rect
		_target_fx.has_target = true
		_target_fx.target_rect = finger_rect
		_target_fx.anim_time = _anim_time
		_target_fx.queue_redraw()

		var blink_wave := 0.5 + 0.5 * sin(_anim_time * 7.2)
		var poke := pow(0.5 + 0.5 * sin(_anim_time * 5.8), 1.4) * 18.0
		var center := finger_rect.get_center()
		var is_card_btn := (finger_ctrl == _btn_next or finger_ctrl == _btn_speedup)
		var aim_pt := Vector2(finger_rect.position.x + finger_rect.size.x * 0.74, center.y + 8.0) if is_card_btn else center

		# Yanıp sönen altın parıltı ve saydamlık salınımı
		var flash := 0.90 + 0.35 * blink_wave
		_hand_sprite.modulate = Color(flash, flash, 0.72 + 0.28 * blink_wave, 0.58 + 0.42 * blink_wave)
		_hand_sprite.show()

		var flip := (aim_pt.x > vp_size.x - 125.0)
		_hand_sprite.flip_h = flip
		# İşaret parmağı ucu (98x98 boyutunda ~ (10, 11) veya çevrilince (88, 11))
		var tip_offset := Vector2(88.0 if flip else 10.0, 11.0)
		var poke_dir := Vector2(-0.707, 0.707) if flip else Vector2(0.707, 0.707)
		var hand_pos := (aim_pt - tip_offset) + poke_dir * poke
		hand_pos.x = clampf(hand_pos.x, 4.0, vp_size.x - 102.0)
		hand_pos.y = clampf(hand_pos.y, 4.0, vp_size.y - 102.0)
		_hand_sprite.position = hand_pos

		# Yüzen İpucu Baloncuğu (kart içi butonlarda metni kapatmamak için gizle)
		if is_card_btn:
			_hand_hint_pill.hide()
		else:
			_hand_hint_pill.show()
			var pill_size := _hand_hint_pill.size
			if pill_size.x < 40.0:
				pill_size = Vector2(160.0, 42.0)
			var pill_x := clampf(center.x - pill_size.x * 0.5, 12.0, vp_size.x - pill_size.x - 12.0)
			var pill_y := finger_rect.position.y - pill_size.y - 14.0
			if pill_y < 14.0:
				pill_y = finger_rect.end.y + 18.0
			pill_y = clampf(pill_y, 12.0, vp_size.y - pill_size.y - 12.0)
			_hand_hint_pill.position = Vector2(pill_x, pill_y)
			_hand_hint_pill.modulate = Color(1.0, 1.0, 1.0, 0.85 + 0.15 * blink_wave)
	else:
		_current_has_target = false
		_target_fx.has_target = false
		_target_fx.queue_redraw()
		_hand_sprite.hide()
		_hand_hint_pill.hide()


# =============================================================================
#  MEZUNİYET / ÖDÜL EKRANI VE BUTON OLAYLARI
# =============================================================================

func _show_graduation_modal(gs: Node) -> void:
	_victory_backdrop.show()
	_victory_modal.show()
	_vizier_card.hide()
	_dim_top.hide()
	_dim_bottom.hide()
	_dim_left.hide()
	_dim_right.hide()
	_hand_sprite.hide()
	_hand_hint_pill.hide()
	_target_fx.has_target = false
	_target_fx.queue_redraw()

	if not _victory_reward_granted and gs != null and not bool(gs.player.get("tutorial_reward_claimed", false)):
		_victory_reward_granted = true
		var v: Dictionary = gs.get_active_village()
		if not v.is_empty():
			var res: Dictionary = v.get("resources", {})
			res["wood"] = int(res.get("wood", 0)) + 1000
			res["stone"] = int(res.get("stone", 0)) + 1000
			res["iron"] = int(res.get("iron", 0)) + 1000
			v["resources"] = res
			gs.player["tutorial_reward_claimed"] = true
			gs._emit_resources_changed(int(v.get("id", -1)))
			_save_game()


func _on_next_pressed() -> void:
	var gs := _gs()
	if gs == null:
		return
	var scene_node := _current_scene_node()
	match _current_step:
		Step.WELCOME_INTRO:
			_advance_to(Step.RESOURCE_BAR_TOUR, gs, scene_node)
		Step.RESOURCE_BAR_TOUR:
			_advance_to(Step.SELECT_MAIN_CASTLE, gs, scene_node)
		Step.INSPECT_MAIN_PANEL:
			if scene_node != null:
				var bp = scene_node.get("building_panel")
				if bp != null and bp.visible:
					bp.hide()
			_advance_to(Step.SELECT_WOOD_CAMP, gs, scene_node)
		Step.WORLD_MAP_TOUR:
			_advance_to(Step.RETURN_FROM_MAP, gs, scene_node)
		Step.ALLIANCE_TOUR:
			_advance_to(Step.RETURN_FROM_ALLIANCE, gs, scene_node)
		_:
			_advance_to(_current_step + 1, gs, scene_node)


func _on_skip_pressed() -> void:
	if DisplayServer.get_name() != "headless" and _skip_confirm_until <= _anim_time:
		_skip_confirm_until = _anim_time + 3.2
		_btn_skip.text = "Emin misin?"
		return
	skip_tutorial()


func _on_speedup_pressed() -> void:
	complete_active_queue_instantly()


func _on_graduation_finish_pressed() -> void:
	var gs := _gs()
	if gs != null:
		gs.player["tutorial_completed"] = true
		gs.player["tutorial_step"] = Step.GRADUATION_MODAL
	_active = false
	_victory_backdrop.hide()
	_victory_modal.hide()
	_set_overlay_visible(false)
	_save_game()


## Baş Vezir 'Kraliyet Fermanı' yardımcısı: aktif kuyruktaki ilk işi simülasyon saatine çekerek hemen tamamlar.
func complete_active_queue_instantly() -> bool:
	var gs := _gs()
	if gs == null or not gs.has_active_village():
		return false
	var vid: int = gs.active_village_id
	var now: int = int(Time.get_unix_time_from_system())
	if GameLoopScript.instance != null and GameLoopScript.instance.now_unix() > 0:
		now = GameLoopScript.instance.now_unix()
	elif gs.world is Dictionary and (gs.world as Dictionary).has("sim_now_unix"):
		now = int((gs.world as Dictionary)["sim_now_unix"])

	var q_list := _active_queues(gs)
	if q_list.is_empty():
		return false

	var head: Dictionary = q_list[0]
	var head_type := str(head.get("type", ""))
	var finish := int(head.get("finish_unix", now))
	var delta_shift := maxi(0, finish - now)

	if head_type == "build":
		# İnşaat kuyruğu sıralıdır: yalnızca ilk inşaatı tamamla, arkadakileri zaman çizelgesinde öne çek
		for item in gs.queues:
			if typeof(item) == TYPE_DICTIONARY and int((item as Dictionary).get("village_id", -1)) == vid and str((item as Dictionary).get("type", "")) == "build":
				(item as Dictionary)["start_unix"] = maxi(1, int((item as Dictionary).get("start_unix", now)) - delta_shift)
				(item as Dictionary)["finish_unix"] = maxi(1, int((item as Dictionary).get("finish_unix", now)) - delta_shift)
		head["finish_unix"] = now - 1
	else:
		head["finish_unix"] = now - 1

	# Simülasyonu işlet ki canonical olaylar (building_completed / research_completed / unit_trained) yayınlansın
	if GameLoopScript.instance != null and GameLoopScript.instance.has_method("simulate"):
		GameLoopScript.instance.simulate(0.1)
	else:
		var state: Dictionary = gs.to_dict()
		if typeof(state.get("world")) != TYPE_DICTIONARY:
			state["world"] = {}
		(state["world"] as Dictionary)["sim_now_unix"] = now
		var ev1 := EconomySimulatorScript.process_tick(state, now, 0.1)
		var ev2 := ArmySimulatorScript.process_tick(state, now, 0.1)
		gs.from_dict(state)
		_emit_sim_events_fallback(ev1 + ev2)

	# Açık BuildingPanel ve Village görünümünü güncelle
	var scene_node := _current_scene_node()
	if scene_node != null:
		if scene_node.has_method("refresh_all"):
			scene_node.refresh_all()
		var bp = scene_node.get("building_panel")
		if bp != null and bp.visible and bp.has_method("refresh"):
			bp.refresh()

	_save_game()
	_shown_substate = ""
	return true


func _emit_sim_events_fallback(events: Array) -> void:
	var loop := Engine.get_main_loop()
	var bus = (loop as SceneTree).root.get_node_or_null("EventBus") if loop is SceneTree else null
	if bus == null:
		return
	for ev in events:
		if typeof(ev) != TYPE_DICTIONARY:
			continue
		var d := ev as Dictionary
		match str(d.get("type", "")):
			"building_completed":
				if bus.has_signal("building_completed"):
					bus.building_completed.emit(int(d.get("village_id", -1)), str(d.get("key", "")), int(d.get("level", 0)))
			"research_completed":
				if bus.has_signal("research_completed"):
					bus.research_completed.emit(int(d.get("village_id", -1)), str(d.get("key", "")))
			"training_completed":
				if bus.has_signal("unit_trained"):
					bus.unit_trained.emit(int(d.get("village_id", -1)), str(d.get("key", "")), int(d.get("count", 0)))
