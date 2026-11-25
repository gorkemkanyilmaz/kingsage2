extends PanelContainer
## BuildingPanel — Bina detay, gereksinim zinciri, birim araştırma ve eğitim paneli (A-ARAYUZ).

signal building_switched(building_key: String)
signal closed()

const RulesEngineScript := preload("res://scripts/rules/RulesEngine.gd")
const EconomyAPI := preload("res://scripts/sim/economy/EconomyAPI.gd")
const Palette := preload("res://themes/Palette.gd")
const GameLoopScript := preload("res://scripts/core/GameLoop.gd")
const ArmyAPI := preload("res://scripts/sim/army/ArmyAPI.gd")
const GameDataScript := preload("res://autoload/GameData.gd")
const VillageModel := preload("res://scripts/model/VillageModel.gd")

const IconWood := preload("res://assets/sprites/ui/nano_banana/sharp_icon_wood.tres")
const IconStone := preload("res://assets/sprites/ui/nano_banana/sharp_icon_stone.tres")
const IconIron := preload("res://assets/sprites/ui/nano_banana/sharp_icon_iron.tres")
const IconCitizens := preload("res://assets/sprites/ui/nano_banana/sharp_icon_citizens.tres")
const IconStorage := preload("res://assets/sprites/ui/nano_banana/sharp_icon_storage.tres")
const IconCastleCrest := preload("res://assets/sprites/ui/nano_banana/sharp_icon_castle_crest.tres")
const FontNunitoBold := preload("res://assets/fonts/Nunito-Bold.ttf")
const FontNunitoSemiBold := preload("res://assets/fonts/Nunito-SemiBold.ttf")

enum Tab { UPGRADE, RESEARCH, TRAIN }
var _current_tab: Tab = Tab.UPGRADE
var _current_key: String = ""
var _village: Dictionary = {}
var _train_counts: Dictionary = {}

const BARRACKS_UNITS := ["farmer", "spear", "sword", "axe", "spy", "bow", "light", "heavy", "ram", "kata"]
const UNIT_CLASS_NAMES := {
	"farmer": "Piyade",
	"spear": "Piyade",
	"sword": "Piyade",
	"axe": "Piyade",
	"bow": "Okçu",
	"spy": "Özel / Casus",
	"light": "Hafif Süvari",
	"heavy": "Ağır Süvari",
	"ram": "Kuşatma (Sur Yıkıcı)",
	"kata": "Kuşatma (Bina Yıkıcı)"
}
const UNIT_ICONS := {
	"farmer": "⚔️",
	"spear": "🛡️",
	"sword": "⚔️",
	"axe": "⚔️",
	"bow": "🏹",
	"spy": "🕵️",
	"light": "🐎",
	"heavy": "♞",
	"ram": "🏛️",
	"kata": "🎯"
}

const BUILDING_DESCRIPTIONS := {
	"main": "Kale yerleşimin can damarıdır. Kale ne kadar büyükse, o kadar çok inşaat ustasına çalışma imkanı sağlanır. Böylece binalar daha hızlı bitirilebilir. Kale 15. seviyeye ulaştığında, binaları yıkabilirsiniz.",
	"stone": "Taş ocağında, devasa kaya parçaları parçalanır. Taş ocağını geliştirdiğin ölçüde daha çok taş işçisi çalıştırabilir ve daha hızlı taş blok üretebilirsin.",
	"wood": "Odun yerleşiminin en fazla ihtiyaç duyduğu hammaddedir. Oduncu kampının geliştirilmesi, odun kesmek için daha fazla işçi çalıştırabilmeni sağlar.",
	"iron": "Demir madeninde, yerden demir çıkarılıp işlenir. Demir madenin ne kadar büyükse, işçilerinde o kadar çok demir çıkarır.",
	"storage": "Hammaddeler; rüzgar ve kötü hava şartlarından korunmaları için depoya saklanırlar. Depoda herzaman yeterince yer olduğu kontrol edilmelidir, aksi halde önemli hammaddeler kaybolabilir.",
	"hide": "Köylerindeki vatandaşlar her zaman kendi evlerini savunamazlar. Hazinelerini gizli depolarda saklamalarının nedeni budur. Bu gizli depolar, hırsızların ellerinden ve casusların gözlerinden uzak yerlerdir.",
	"farm": "Alanın verimliliği değirmene bağlıdır. Un, değirmencinin vatandaşlarınızı beslemesini sağlar, böylece hiç kimse açlıktan ölmek zorunda kalmaz. Tüm işçileriniz ve askerleriniz beslenmek zorundadır.",
	"barracks": "Kışlada, disiplin ve taktik öğretimi için, katı kurallar ve acımasız bir davranış biçimi hüküm sürer. Savaşçılar, krallarına sadakatle hizmet etmek için burada yetiştirilirler. Kışlanı geliştirerek, daha modern birimlere sahip olabilirsin.",
	"wall": "Güçlü surlar sayesinde vatandaşlarınız aç kurtlardan ve saldıran diğer düşmanlardan korunurlar. Köy savunulacağı zaman surun gücü (kademesine bağlı olarak), köydeki birliklerinizin de gücünü etkiler.",
	"stable": "Katır çiftliğinde, senin için birçok eşya taşıyabilecek yeni hayvanlar yetişir. Daha büyük çiftlik yaparsan, daha çok katır yetiştirebilirsin.",
	"market": "Market renkli hareketliliklerin yaşandığı yerdir. Uzak ve yakın yerlerden satıcılar buraya ticaret yapmaya gelirler. Eşyalar katırlarla taşınır. Market ne kadar genişlerse, yapabileceğin ticaret kapasitesi o kadar artar.",
	"garage": "Simyagerin mutfağında harikulade araştırmalar yapılır. Laboratuvarınız büyüdükçe krallığınıza kalıcı üstünlük sağlayan yeni teknikler geliştirebilirsiniz.",
	"snob": "Kontlar, krallığının fetih işlerini senin adına yoluna koyan sadık vatandaşlarındır. Yeni bir yerleşimi fethetmek için burada Kont yetiştirebilirsin.",
	"smith": "Kuyumcuda yeni Kontları göreve atamak için gerekli olan değerli altın zırhları üretebilirsin.",
	"statue": "Muhteşem bir heykel, şehrin merkezindeki meydanda durur ve şehir halkına sürekli sizin muazzam büyüklüğünüzü hatırlatır. Heykel sayesinde savunma tahkimatı %50 artar."
}

var _desc_box: PanelContainer = null
var _desc_label: Label = null
var _prod_box: PanelContainer = null
var _prod_vbox: VBoxContainer = null
var _special_box: PanelContainer = null
var _special_vbox: VBoxContainer = null
var _last_research_sig: String = ""
var _last_train_sig: String = ""
var _last_prod_table_sig: String = ""
var _last_special_box_sig: String = ""
var _last_tab_style_sig: String = ""
var _last_speedup_sig_by_btn: Dictionary = {}
var _in_action_emit: bool = false
var _active_info_accum: float = 0.0
var _tab_act_sb: StyleBox = null
var _tab_inact_sb: StyleBox = null
var _cached_upg_norm_sb: StyleBoxFlat = null
var _cached_upg_hover_sb: StyleBoxFlat = null
var _cached_upg_pressed_sb: StyleBoxFlat = null
var _cached_upg_dis_sb: StyleBoxFlat = null

# Header nodes
@onready var title_label: Label = $VBox/Header/TitleLabel
@onready var level_label: Label = $VBox/Header/LevelLabel
@onready var close_btn: Button = $VBox/Header/CloseButton

# TabBar nodes
@onready var tab_bar: HBoxContainer = $VBox/TabBar
@onready var tab_upgrade_btn: Button = $VBox/TabBar/TabUpgradeBtn
@onready var tab_research_btn: Button = $VBox/TabBar/TabResearchBtn
@onready var tab_train_btn: Button = $VBox/TabBar/TabTrainBtn

# Locked Banner
@onready var locked_banner: PanelContainer = $VBox/LockedBanner
@onready var build_barracks_btn: Button = $VBox/LockedBanner/VBox/BuildBarracksButton

# Upgrade nodes
@onready var active_build_box: PanelContainer = $VBox/ActiveBuildBox
@onready var active_build_icon_lbl: Label = $VBox/ActiveBuildBox/HBox/IconLabel
@onready var active_build_time_lbl: Label = $VBox/ActiveBuildBox/HBox/TimeLabel
@onready var active_build_progress: ProgressBar = $VBox/ActiveBuildBox/HBox/ProgressBar
@onready var active_build_speedup_btn: Button = $VBox/ActiveBuildBox/HBox/BuildSpeedupButton if has_node("VBox/ActiveBuildBox/HBox/BuildSpeedupButton") else null
@onready var active_build_cancel_btn: Button = $VBox/ActiveBuildBox/HBox/CancelButton

@onready var cost_wood: Label = $VBox/CostContainer/WoodBox/Label
@onready var cost_stone: Label = $VBox/CostContainer/StoneBox/Label
@onready var cost_iron: Label = $VBox/CostContainer/IronBox/Label
@onready var time_label: Label = $VBox/MetaContainer/TimeLabel
@onready var extra_cost_label: Label = $VBox/MetaContainer/ExtraCostLabel

@onready var upgrade_btn: Button = $VBox/UpgradeButton
@onready var req_container: VBoxContainer = $VBox/RequirementSection/ReqScroll/ReqList
@onready var req_section: VBoxContainer = $VBox/RequirementSection

# Research nodes
@onready var research_section: VBoxContainer = $VBox/ResearchSection
@onready var active_research_box: PanelContainer = $VBox/ResearchSection/ActiveResearchBox
@onready var active_research_icon_lbl: Label = $VBox/ResearchSection/ActiveResearchBox/HBox/IconLabel
@onready var active_research_time_lbl: Label = $VBox/ResearchSection/ActiveResearchBox/HBox/TimeLabel
@onready var active_research_progress: ProgressBar = $VBox/ResearchSection/ActiveResearchBox/HBox/ProgressBar
@onready var active_research_speedup_btn: Button = $VBox/ResearchSection/ActiveResearchBox/HBox/ResearchSpeedupButton if has_node("VBox/ResearchSection/ActiveResearchBox/HBox/ResearchSpeedupButton") else null
@onready var active_research_cancel_btn: Button = $VBox/ResearchSection/ActiveResearchBox/HBox/CancelButton
@onready var research_list: VBoxContainer = $VBox/ResearchSection/ResearchScroll/ResearchList

# Train nodes
@onready var train_section: VBoxContainer = $VBox/TrainSection
@onready var active_train_box: PanelContainer = $VBox/TrainSection/ActiveTrainBox
@onready var train_queue_list: VBoxContainer = $VBox/TrainSection/ActiveTrainBox/VBox/QueueList
@onready var citizen_label: Label = $VBox/TrainSection/CitizenInfoBar/CitizenLabel
@onready var train_list: VBoxContainer = $VBox/TrainSection/TrainScroll/TrainList

var _cached_speedup_have_sb: StyleBoxFlat = null
var _cached_speedup_have_hover: StyleBoxFlat = null
var _cached_speedup_buy_sb: StyleBoxFlat = null
var _cached_speedup_buy_hover: StyleBoxFlat = null
var _cached_train_pb_bg: StyleBoxFlat = null
var _cached_train_pb_fg: StyleBoxFlat = null
var _cached_train_cancel_sb: StyleBoxFlat = null
var _cached_train_cancel_hover: StyleBoxFlat = null
var _kb_preview_bar: PanelContainer = null
var _kb_preview_label: Label = null
var _kb_preview_value_lbl: Label = null
var _kb_preview_done_btn: Button = null
var _focused_train_unit: String = ""
var _focused_train_line: LineEdit = null
var _focused_train_spin: SpinBox = null
var _kb_scroll_done_for: String = ""
var _kb_was_open_on_mobile: bool = false
var _train_scroll_orig_min_h: float = 480.0
var _pre_kb_scroll_y: int = -1
var _post_kb_restore_scroll_y: int = -1
var _post_kb_restore_unit: String = ""


func _ensure_nodes() -> void:
	if title_label == null and has_node("VBox/Header/TitleLabel"):
		title_label = $VBox/Header/TitleLabel
		level_label = $VBox/Header/LevelLabel
		close_btn = $VBox/Header/CloseButton

	if tab_bar == null and has_node("VBox/TabBar"):
		tab_bar = $VBox/TabBar
		tab_upgrade_btn = $VBox/TabBar/TabUpgradeBtn
		tab_research_btn = $VBox/TabBar/TabResearchBtn
		tab_train_btn = $VBox/TabBar/TabTrainBtn

	if locked_banner == null and has_node("VBox/LockedBanner"):
		locked_banner = $VBox/LockedBanner
		build_barracks_btn = $VBox/LockedBanner/VBox/BuildBarracksButton

	if cost_wood == null and has_node("VBox/CostContainer/WoodBox/Label"):
		cost_wood = $VBox/CostContainer/WoodBox/Label
		cost_stone = $VBox/CostContainer/StoneBox/Label
		cost_iron = $VBox/CostContainer/IronBox/Label
		time_label = $VBox/MetaContainer/TimeLabel
		extra_cost_label = $VBox/MetaContainer/ExtraCostLabel
		upgrade_btn = $VBox/UpgradeButton
		req_container = $VBox/RequirementSection/ReqScroll/ReqList
		req_section = $VBox/RequirementSection

	if active_build_box == null and has_node("VBox/ActiveBuildBox"):
		active_build_box = $VBox/ActiveBuildBox
		active_build_icon_lbl = $VBox/ActiveBuildBox/HBox/IconLabel
		active_build_time_lbl = $VBox/ActiveBuildBox/HBox/TimeLabel
		active_build_progress = $VBox/ActiveBuildBox/HBox/ProgressBar
		active_build_speedup_btn = $VBox/ActiveBuildBox/HBox/BuildSpeedupButton if has_node("VBox/ActiveBuildBox/HBox/BuildSpeedupButton") else null
		active_build_cancel_btn = $VBox/ActiveBuildBox/HBox/CancelButton

	if research_section == null and has_node("VBox/ResearchSection"):
		research_section = $VBox/ResearchSection
		active_research_box = $VBox/ResearchSection/ActiveResearchBox
		active_research_icon_lbl = $VBox/ResearchSection/ActiveResearchBox/HBox/IconLabel
		active_research_time_lbl = $VBox/ResearchSection/ActiveResearchBox/HBox/TimeLabel
		active_research_progress = $VBox/ResearchSection/ActiveResearchBox/HBox/ProgressBar
		active_research_speedup_btn = $VBox/ResearchSection/ActiveResearchBox/HBox/ResearchSpeedupButton if has_node("VBox/ResearchSection/ActiveResearchBox/HBox/ResearchSpeedupButton") else null
		active_research_cancel_btn = $VBox/ResearchSection/ActiveResearchBox/HBox/CancelButton
		research_list = $VBox/ResearchSection/ResearchScroll/ResearchList

	if train_section == null and has_node("VBox/TrainSection"):
		train_section = $VBox/TrainSection
		active_train_box = $VBox/TrainSection/ActiveTrainBox
		train_queue_list = $VBox/TrainSection/ActiveTrainBox/VBox/QueueList
		citizen_label = $VBox/TrainSection/CitizenInfoBar/CitizenLabel
		train_list = $VBox/TrainSection/TrainScroll/TrainList

	_configure_scroll_containers()
	_ensure_description_and_production_nodes()
	_ensure_kb_preview_bar()


static func _extract_train_digits(raw: String) -> String:
	var out: String = ""
	for i in range(raw.length()):
		var ch := raw.substr(i, 1)
		if ch >= "0" and ch <= "9":
			out += ch
	return out


func _ensure_kb_preview_bar() -> void:
	if _kb_preview_bar != null or train_section == null:
		return
	_kb_preview_bar = PanelContainer.new()
	_kb_preview_bar.name = "TrainKeyboardPreviewBar"
	_kb_preview_bar.visible = false
	_kb_preview_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_kb_preview_bar.custom_minimum_size = Vector2(0, 78)
	var ksb := StyleBoxFlat.new()
	ksb.bg_color = Color(0.11, 0.10, 0.16, 0.99)
	ksb.border_color = Color(1.0, 0.84, 0.34, 1.0)
	ksb.set_border_width_all(2)
	ksb.border_width_bottom = 3
	ksb.set_corner_radius_all(14)
	ksb.content_margin_left = 14
	ksb.content_margin_right = 14
	ksb.content_margin_top = 10
	ksb.content_margin_bottom = 10
	ksb.shadow_color = Color(0, 0, 0, 0.65)
	ksb.shadow_size = 0
	_kb_preview_bar.add_theme_stylebox_override("panel", ksb)

	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 12)
	_kb_preview_bar.add_child(hbox)

	_kb_preview_label = Label.new()
	_kb_preview_label.name = "PreviewText"
	_kb_preview_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_kb_preview_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_kb_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_kb_preview_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kb_preview_label.add_theme_font_override("font", FontNunitoBold)
	_kb_preview_label.add_theme_font_size_override("font_size", 24)
	_kb_preview_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.78))
	hbox.add_child(_kb_preview_label)

	var val_pill := PanelContainer.new()
	val_pill.name = "PreviewValuePill"
	val_pill.custom_minimum_size = Vector2(124, 52)
	val_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	val_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vsb := StyleBoxFlat.new()
	vsb.bg_color = Color(0.05, 0.06, 0.11, 1.0)
	vsb.border_color = Color(1.0, 0.86, 0.36, 0.95)
	vsb.set_border_width_all(2)
	vsb.set_corner_radius_all(10)
	vsb.content_margin_left = 10
	vsb.content_margin_right = 10
	val_pill.add_theme_stylebox_override("panel", vsb)
	hbox.add_child(val_pill)

	_kb_preview_value_lbl = Label.new()
	_kb_preview_value_lbl.name = "PreviewValue"
	_kb_preview_value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kb_preview_value_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_kb_preview_value_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kb_preview_value_lbl.add_theme_font_override("font", FontNunitoBold)
	_kb_preview_value_lbl.add_theme_font_size_override("font_size", 30)
	_kb_preview_value_lbl.add_theme_color_override("font_color", Color(0.55, 0.98, 0.68))
	val_pill.add_child(_kb_preview_value_lbl)

	_kb_preview_done_btn = Button.new()
	_kb_preview_done_btn.name = "BtnTrainKbDone"
	_kb_preview_done_btn.text = "✓ Tamam"
	_kb_preview_done_btn.custom_minimum_size = Vector2(142, 54)
	_kb_preview_done_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_kb_preview_done_btn.add_theme_font_override("font", FontNunitoBold)
	_kb_preview_done_btn.add_theme_font_size_override("font_size", 25)
	_kb_preview_done_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	_kb_preview_done_btn.add_theme_constant_override("outline_size", 2)
	_kb_preview_done_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = Color(0.16, 0.60, 0.31, 1.0)
	dsb.border_color = Color(0.64, 0.96, 0.72, 1.0)
	dsb.set_border_width_all(2)
	dsb.set_corner_radius_all(11)
	var dsb_hov := dsb.duplicate() as StyleBoxFlat
	dsb_hov.bg_color = Color(0.22, 0.70, 0.38, 1.0)
	_kb_preview_done_btn.add_theme_stylebox_override("normal", dsb)
	_kb_preview_done_btn.add_theme_stylebox_override("hover", dsb_hov)
	_kb_preview_done_btn.add_theme_stylebox_override("pressed", dsb_hov)
	_kb_preview_done_btn.pressed.connect(func():
		_commit_focused_train_input("__FROM_LINE__", true)
	)
	hbox.add_child(_kb_preview_done_btn)

	train_section.add_child(_kb_preview_bar)
	var scroll_idx := train_section.get_node_or_null("TrainScroll").get_index() if train_section.has_node("TrainScroll") else train_section.get_child_count() - 1
	train_section.move_child(_kb_preview_bar, clampi(scroll_idx, 0, train_section.get_child_count() - 1))


func _commit_focused_train_input(override_txt: String = "__FROM_LINE__", release_kb: bool = true) -> int:
	if _focused_train_unit.is_empty():
		return 0
	var u_key := _focused_train_unit
	var target_spin := _focused_train_spin
	var target_line := _focused_train_line
	var src := override_txt
	if src == "__FROM_LINE__":
		src = target_line.text if (target_line != null and is_instance_valid(target_line)) else str(int(target_spin.value) if target_spin != null and is_instance_valid(target_spin) else 0)
	var digits := _extract_train_digits(src.strip_edges())
	var new_val := clampi(digits.to_int(), 0, 99999) if not digits.is_empty() else 0
	_train_counts[u_key] = new_val
	if target_spin != null and is_instance_valid(target_spin):
		target_spin.value = float(new_val)
	if target_line != null and is_instance_valid(target_line):
		target_line.text = str(new_val) if new_val > 0 else ""
	if train_list != null:
		var card := train_list.get_node_or_null("TrainCard_" + u_key)
		if card != null and card.has_meta("update_calc"):
			var cb = card.get_meta("update_calc")
			if cb is Callable:
				(cb as Callable).call()
	if release_kb:
		var sc_cur := get_node_or_null("VBox/TrainSection/TrainScroll") as ScrollContainer
		var restore_y := _pre_kb_scroll_y
		if restore_y < 0 and sc_cur != null:
			restore_y = sc_cur.scroll_vertical
		_pre_kb_scroll_y = -1
		if _current_tab == Tab.TRAIN and restore_y >= 0:
			_post_kb_restore_scroll_y = maxi(0, restore_y)
			_post_kb_restore_unit = u_key
		else:
			_post_kb_restore_scroll_y = -1
			_post_kb_restore_unit = ""
		_focused_train_unit = ""
		_focused_train_line = null
		_focused_train_spin = null
		_kb_scroll_done_for = ""
		_kb_was_open_on_mobile = false
		if target_line != null and is_instance_valid(target_line) and target_line.has_focus():
			target_line.release_focus()
		_restore_keyboard_lift()
		if _current_tab == Tab.TRAIN:
			offset_top = -1150.0
			_update_active_train_info()
			_apply_post_kb_scroll_restore(false)
			call_deferred("_deferred_post_kb_scroll_restore")
		var gc: Node = Engine.get_main_loop().root.get_node_or_null("GameConfig") if Engine.get_main_loop() is SceneTree else null
		if gc != null and gc.has_method("dismiss_virtual_keyboard"):
			gc.call("dismiss_virtual_keyboard")
	return new_val


func _update_kb_preview(override_txt: String = "__FROM_LINE__") -> void:
	_ensure_kb_preview_bar()
	if _kb_preview_bar == null or _kb_preview_label == null:
		return
	if _focused_train_unit.is_empty() or _focused_train_line == null or not is_instance_valid(_focused_train_line):
		_kb_preview_bar.hide()
		return
	var u_name: String = GameDataScript.get_singleton().get_unit_name(_focused_train_unit)
	var u_icon: String = str(UNIT_ICONS.get(_focused_train_unit, "⚔️"))
	var raw_in := _focused_train_line.text if override_txt == "__FROM_LINE__" else override_txt
	var digits := _extract_train_digits(raw_in.strip_edges())
	var cnt := clampi(digits.to_int(), 0, 99999) if not digits.is_empty() else 0
	if _kb_preview_value_lbl != null:
		_kb_preview_value_lbl.text = _format_number(cnt) if cnt > 0 else "0"
	if cnt > 0:
		var barracks_lvl := int(_village.get("buildings", {}).get("barracks", 1))
		var tot_sec := int(ceil(RulesEngineScript.training_seconds(_focused_train_unit, cnt, barracks_lvl)))
		_kb_preview_label.text = "%s %s — %s Adet\n⏱️ Süre: %s" % [u_icon, u_name, _format_number(cnt), _fmt_duration(tot_sec)]
	else:
		_kb_preview_label.text = "%s %s — Miktar Yazın\nKlavyeden sayı girip ✓ Tamam'a basın" % [u_icon, u_name]
	_kb_preview_bar.show()


func _update_keyboard_lift() -> void:
	if not visible or _current_tab != Tab.TRAIN:
		_restore_keyboard_lift()
		return
	if _focused_train_line == null or not is_instance_valid(_focused_train_line) or not _focused_train_line.has_focus():
		return
	if active_train_box != null:
		active_train_box.hide()
	var scroll := get_node_or_null("VBox/TrainSection/TrainScroll") as ScrollContainer
	if scroll != null and scroll.custom_minimum_size.y > 115.0:
		_train_scroll_orig_min_h = scroll.custom_minimum_size.y
		scroll.custom_minimum_size.y = 110.0
	var vp := get_viewport()
	var vp_h: float = vp.get_visible_rect().size.y if vp != null else 1920.0
	if vp_h <= 10.0:
		vp_h = 1920.0
	var kb_px: int = DisplayServer.virtual_keyboard_get_height() if DisplayServer.get_name() != "headless" else 0
	if kb_px > 0:
		_kb_was_open_on_mobile = true
	elif _kb_was_open_on_mobile and (OS.has_feature("ios") or OS.has_feature("android")):
		_kb_was_open_on_mobile = false
		_commit_focused_train_input("__FROM_LINE__", true)
		return
	var win_h: float = float(DisplayServer.window_get_size().y) if DisplayServer.get_name() != "headless" else vp_h
	var kb_vp_h: float = (float(kb_px) * vp_h / maxf(1.0, win_h)) if kb_px > 0 else 0.0
	if OS.has_feature("ios") or OS.has_feature("android") or DisplayServer.is_touchscreen_available():
		kb_vp_h = maxf(kb_vp_h, vp_h * 0.48)
	if kb_vp_h <= 10.0:
		kb_vp_h = 256.0
	var top_limit: float = 160.0
	var par: Node = get_parent()
	if par != null:
		var rbar: Node = par.get_node_or_null("ResourceBar")
		if rbar != null and rbar.has_method("get_bar_height"):
			top_limit = maxf(top_limit, float(rbar.call("get_bar_height")) + 12.0)
	var bottom_off: float = minf(-256.0, -kb_vp_h - 18.0)
	var desired_h: float = clampf(vp_h + bottom_off - top_limit, 360.0, 820.0)
	offset_bottom = bottom_off
	offset_top = bottom_off - desired_h
	if _kb_scroll_done_for != _focused_train_unit and train_list != null:
		_kb_scroll_done_for = _focused_train_unit
		var target_u := _focused_train_unit
		call_deferred("_deferred_scroll_to_train_card", target_u)


func _deferred_scroll_to_train_card(u_key: String) -> void:
	if not visible or _current_tab != Tab.TRAIN or train_list == null:
		return
	var scroll := get_node_or_null("VBox/TrainSection/TrainScroll") as ScrollContainer
	var card := train_list.get_node_or_null("TrainCard_" + u_key) as Control
	if scroll != null and card != null:
		var row_node := card.find_child("TrainInputRow_" + u_key, true, false) as Control
		var row_bottom := card.position.y + (row_node.position.y + row_node.size.y if row_node != null else card.size.y)
		var visible_h := maxf(140.0, scroll.size.y)
		var desired := maxf(card.position.y - 8.0, row_bottom - visible_h + 26.0)
		scroll.scroll_vertical = int(maxf(0.0, desired))
		call_deferred("_align_train_scroll_pass", u_key)


func _align_train_scroll_pass(u_key: String) -> void:
	if not visible or _current_tab != Tab.TRAIN or train_list == null or _focused_train_unit != u_key:
		return
	var scroll := get_node_or_null("VBox/TrainSection/TrainScroll") as ScrollContainer
	var card := train_list.get_node_or_null("TrainCard_" + u_key) as Control
	if scroll != null and card != null:
		var row_node := card.find_child("TrainInputRow_" + u_key, true, false) as Control
		var row_bottom := card.position.y + (row_node.position.y + row_node.size.y if row_node != null else card.size.y)
		var visible_h := maxf(140.0, scroll.size.y)
		var desired := maxf(card.position.y - 8.0, row_bottom - visible_h + 26.0)
		scroll.scroll_vertical = int(maxf(0.0, desired))


func _restore_keyboard_lift() -> void:
	_kb_was_open_on_mobile = false
	var scroll := get_node_or_null("VBox/TrainSection/TrainScroll") as ScrollContainer
	if scroll != null and scroll.custom_minimum_size.y < _train_scroll_orig_min_h:
		scroll.custom_minimum_size.y = _train_scroll_orig_min_h
	if _kb_preview_bar != null:
		_kb_preview_bar.hide()
	if absf(offset_bottom - (-256.0)) > 0.5:
		offset_bottom = -256.0


func _deferred_post_kb_scroll_restore() -> void:
	_apply_post_kb_scroll_restore(false)
	call_deferred("_apply_post_kb_scroll_restore", true)


func _apply_post_kb_scroll_restore(clear_after: bool = false) -> void:
	if not visible or _current_tab != Tab.TRAIN or _post_kb_restore_scroll_y < 0:
		if clear_after:
			_post_kb_restore_scroll_y = -1
			_post_kb_restore_unit = ""
		return
	var scroll := get_node_or_null("VBox/TrainSection/TrainScroll") as ScrollContainer
	if scroll != null:
		var target_y := maxi(0, _post_kb_restore_scroll_y)
		if train_list != null and not _post_kb_restore_unit.is_empty():
			var card := train_list.get_node_or_null("TrainCard_" + _post_kb_restore_unit) as Control
			if card != null and scroll.size.y > 40.0:
				var vis_h := scroll.size.y
				if card.position.y + card.size.y < float(target_y) + 40.0 or card.position.y > float(target_y) + vis_h - 40.0:
					var row_node := card.find_child("TrainInputRow_" + _post_kb_restore_unit, true, false) as Control
					var row_bottom := card.position.y + (row_node.position.y + row_node.size.y if row_node != null else card.size.y)
					target_y = int(maxf(0.0, maxf(card.position.y - 12.0, row_bottom - vis_h + 24.0)))
		scroll.scroll_vertical = target_y
	if clear_after:
		_post_kb_restore_scroll_y = -1
		_post_kb_restore_unit = ""


func _ensure_description_and_production_nodes() -> void:
	if not has_node("VBox"):
		return
	var vbox: VBoxContainer = $VBox

	if _desc_box == null:
		_desc_box = PanelContainer.new()
		_desc_box.name = "BuildingDescriptionBox"
		var desc_sb := StyleBoxFlat.new()
		desc_sb.bg_color = Color(0.14, 0.12, 0.16, 0.95)
		desc_sb.border_color = Color(0.85, 0.72, 0.42, 0.80)
		desc_sb.set_border_width_all(2)
		desc_sb.set_corner_radius_all(14)
		desc_sb.content_margin_left = 18
		desc_sb.content_margin_right = 18
		desc_sb.content_margin_top = 12
		desc_sb.content_margin_bottom = 12
		desc_sb.shadow_color = Color(0, 0, 0, 0.4)
		desc_sb.shadow_size = 0
		_desc_box.add_theme_stylebox_override("panel", desc_sb)

		_desc_label = Label.new()
		_desc_label.name = "DescriptionLabel"
		_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_desc_label.add_theme_font_override("font", FontNunitoSemiBold)
		_desc_label.add_theme_font_size_override("font_size", 26)
		_desc_label.add_theme_color_override("font_color", Color(0.95, 0.90, 0.78, 1.0))
		_desc_label.add_theme_constant_override("outline_size", 0)
		_desc_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		_desc_box.add_child(_desc_label)

		vbox.add_child(_desc_box)
		vbox.move_child(_desc_box, 2)

	if _prod_box == null:
		_prod_box = PanelContainer.new()
		_prod_box.name = "ProductionTableBox"
		var prod_sb := StyleBoxFlat.new()
		prod_sb.bg_color = Color(0.94, 0.87, 0.73, 0.98) # Görsel 1'deki orijinal altın parşömen
		prod_sb.border_color = Color(0.60, 0.44, 0.24, 1.0)
		prod_sb.set_border_width_all(2)
		prod_sb.set_corner_radius_all(14)
		prod_sb.content_margin_left = 14
		prod_sb.content_margin_right = 14
		prod_sb.content_margin_top = 10
		prod_sb.content_margin_bottom = 10
		prod_sb.shadow_color = Color(0, 0, 0, 0.35)
		prod_sb.shadow_size = 0
		_prod_box.add_theme_stylebox_override("panel", prod_sb)

		_prod_vbox = VBoxContainer.new()
		_prod_vbox.name = "ProductionVBox"
		_prod_vbox.add_theme_constant_override("separation", 4)
		_prod_box.add_child(_prod_vbox)

		vbox.add_child(_prod_box)
		vbox.move_child(_prod_box, 3)

	if _special_box == null:
		_special_box = PanelContainer.new()
		_special_box.name = "SpecialBuildingActionBox"
		var sp_sb := StyleBoxFlat.new()
		sp_sb.bg_color = Color(0.14, 0.11, 0.16, 0.96)
		sp_sb.border_color = Color(0.92, 0.75, 0.32, 0.90)
		sp_sb.set_border_width_all(2)
		sp_sb.set_corner_radius_all(14)
		sp_sb.content_margin_left = 18
		sp_sb.content_margin_right = 18
		sp_sb.content_margin_top = 14
		sp_sb.content_margin_bottom = 14
		sp_sb.shadow_color = Color(0, 0, 0, 0.45)
		sp_sb.shadow_size = 0
		_special_box.add_theme_stylebox_override("panel", sp_sb)

		_special_vbox = VBoxContainer.new()
		_special_vbox.name = "SpecialActionVBox"
		_special_vbox.add_theme_constant_override("separation", 10)
		_special_box.add_child(_special_vbox)
		_special_box.hide()

		vbox.add_child(_special_box)
		vbox.move_child(_special_box, 4)


func _get_speed_mult() -> float:
	var loop := Engine.get_main_loop()
	if loop is SceneTree and (loop as SceneTree).root != null:
		var gc := (loop as SceneTree).root.get_node_or_null("GameConfig")
		if gc != null and gc.has_method("get_speed"):
			return float(gc.call("get_speed"))
	return 1.0


func _update_production_table(cur_lvl: int) -> void:
	if _prod_box == null or _prod_vbox == null:
		return

	if not (_current_key in ["wood", "stone", "iron", "storage", "main"]):
		_prod_box.hide()
		return

	_prod_box.show()
	var spd_mult: float = _get_speed_mult()
	var prod_sig := "%s:%d:%d" % [_current_key, cur_lvl, int(round(spd_mult * 100.0))]
	if prod_sig == _last_prod_table_sig and _prod_vbox.get_child_count() > 0:
		return
	_last_prod_table_sig = prod_sig

	for child in _prod_vbox.get_children():
		_prod_vbox.remove_child(child)
		child.queue_free()

	if _current_key == "storage":
		_build_storage_table(cur_lvl)
	elif _current_key == "main":
		_build_castle_speedup_table(cur_lvl)
	else:
		_build_mine_production_table(cur_lvl)


func _build_castle_speedup_table(cur_lvl: int) -> void:
	# 1. Başlık Satırı (İnşaat Hızı | hızlanma | inşa süresi)
	var header_panel := PanelContainer.new()
	var h_sb := StyleBoxFlat.new()
	h_sb.bg_color = Color(0.85, 0.74, 0.56, 0.95)
	h_sb.set_corner_radius_all(8)
	h_sb.content_margin_left = 14
	h_sb.content_margin_right = 14
	h_sb.content_margin_top = 8
	h_sb.content_margin_bottom = 8
	header_panel.add_theme_stylebox_override("panel", h_sb)

	var h_row := HBoxContainer.new()
	var col1_lbl := Label.new()
	col1_lbl.text = "İnşaat Hızı"
	col1_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col1_lbl.add_theme_font_override("font", FontNunitoBold)
	col1_lbl.add_theme_font_size_override("font_size", 28)
	col1_lbl.add_theme_color_override("font_color", Color(0.12, 0.08, 0.04))
	h_row.add_child(col1_lbl)

	var col2_lbl := Label.new()
	col2_lbl.text = "hızlanma"
	col2_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col2_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col2_lbl.add_theme_font_override("font", FontNunitoBold)
	col2_lbl.add_theme_font_size_override("font_size", 28)
	col2_lbl.add_theme_color_override("font_color", Color(0.12, 0.08, 0.04))
	h_row.add_child(col2_lbl)

	var col3_lbl := Label.new()
	col3_lbl.text = "inşa süresi"
	col3_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col3_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col3_lbl.add_theme_font_override("font", FontNunitoBold)
	col3_lbl.add_theme_font_size_override("font_size", 28)
	col3_lbl.add_theme_color_override("font_color", Color(0.12, 0.08, 0.04))
	h_row.add_child(col3_lbl)

	header_panel.add_child(h_row)
	_prod_vbox.add_child(header_panel)

	# 2. Güncel Satırı (Canlı turuncu-altın şerit, maden tablolarıyla birebir aynı)
	var active_lvl: int = maxi(1, cur_lvl)
	var cur_pct: int = RulesEngineScript.castle_speedup_percent(active_lvl)
	var cur_tf: int = RulesEngineScript.castle_time_factor_percent(active_lvl)
	var current_panel := _make_castle_speed_row("Güncel", IconCastleCrest, cur_pct, cur_tf, true)
	_prod_vbox.add_child(current_panel)

	# 3. Gelecek 4 Seviye
	var start_next_lvl := active_lvl + 1
	for i in range(4):
		var lvl := start_next_lvl + i
		if lvl > 50:
			break
		var pct := RulesEngineScript.castle_speedup_percent(lvl)
		var tf := RulesEngineScript.castle_time_factor_percent(lvl)
		var lvl_panel := _make_castle_speed_row("Seviye %d" % lvl, IconCastleCrest, pct, tf, false)
		_prod_vbox.add_child(lvl_panel)


func _make_castle_speed_row(label_text: String, icon_tex: Texture2D, speedup_pct: int, time_factor_pct: int, is_highlighted: bool) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	if is_highlighted:
		sb.bg_color = Color(0.98, 0.76, 0.36, 0.90) # Canlı altın-turuncu vurgu
		sb.border_color = Color(0.85, 0.58, 0.18, 0.95)
		sb.set_border_width_all(1)
	else:
		sb.bg_color = Color(0.95, 0.89, 0.77, 0.65)
		sb.border_color = Color(0.80, 0.72, 0.58, 0.50)
		sb.border_width_bottom = 1
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	pc.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	# Sütun 1: Seviye İsmi
	var c1 := Label.new()
	c1.text = label_text
	c1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c1.add_theme_font_override("font", FontNunitoBold)
	c1.add_theme_font_size_override("font_size", 26)
	c1.add_theme_color_override("font_color", Color(0.12, 0.08, 0.04))
	row.add_child(c1)

	# Sütun 2: Hızlandırma Yüzdesi (Simge + +%X)
	var c2 := HBoxContainer.new()
	c2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c2.alignment = BoxContainer.ALIGNMENT_CENTER
	c2.add_theme_constant_override("separation", 8)
	if icon_tex != null:
		var tr := TextureRect.new()
		tr.texture = icon_tex
		tr.custom_minimum_size = Vector2(28, 28)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		c2.add_child(tr)
	var spd_lbl := Label.new()
	spd_lbl.text = ("+%%%d" % speedup_pct) if speedup_pct > 0 else "%0"
	spd_lbl.add_theme_font_override("font", FontNunitoBold)
	spd_lbl.add_theme_font_size_override("font_size", 26)
	spd_lbl.add_theme_color_override("font_color", Color(0.12, 0.08, 0.04))
	c2.add_child(spd_lbl)
	row.add_child(c2)

	# Sütun 3: Kalan İnşa Süresi Yüzdesi (%100 -> %15)
	var c3 := HBoxContainer.new()
	c3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c3.alignment = BoxContainer.ALIGNMENT_CENTER
	var tf_lbl := Label.new()
	tf_lbl.text = "%%%d" % time_factor_pct
	tf_lbl.add_theme_font_override("font", FontNunitoBold)
	tf_lbl.add_theme_font_size_override("font_size", 26)
	tf_lbl.add_theme_color_override("font_color", Color(0.12, 0.08, 0.04))
	c3.add_child(tf_lbl)
	row.add_child(c3)

	pc.add_child(row)
	return pc


func _build_storage_table(cur_lvl: int) -> void:
	# 1. Başlık Satırı (Deponun alabileceği hammadde ayrı ayrı)
	var header_panel := PanelContainer.new()
	var h_sb := StyleBoxFlat.new()
	h_sb.bg_color = Color(0.85, 0.74, 0.56, 0.95)
	h_sb.set_corner_radius_all(8)
	h_sb.content_margin_left = 14
	h_sb.content_margin_right = 14
	h_sb.content_margin_top = 8
	h_sb.content_margin_bottom = 8
	header_panel.add_theme_stylebox_override("panel", h_sb)

	var h_row := HBoxContainer.new()
	var col1_lbl := Label.new()
	col1_lbl.text = "Deponun alabileceği\nhammadde ayrı ayrı"
	col1_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col1_lbl.add_theme_font_override("font", FontNunitoBold)
	col1_lbl.add_theme_font_size_override("font_size", 26)
	col1_lbl.add_theme_color_override("font_color", Color(0.12, 0.08, 0.04))
	h_row.add_child(col1_lbl)

	var col2_spacer := Control.new()
	col2_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_row.add_child(col2_spacer)

	header_panel.add_child(h_row)
	_prod_vbox.add_child(header_panel)

	# 2. Güncel Satırı (Canlı turuncu-altın şerit)
	var active_lvl: int = maxi(1, cur_lvl)
	var cur_cap: int = RulesEngineScript.storage_capacity(active_lvl)
	var current_panel := _make_storage_row("Güncel", IconStorage, cur_cap, true)
	_prod_vbox.add_child(current_panel)

	# 3. Sonraki 4 Seviye
	var start_next_lvl := active_lvl + 1
	for i in range(4):
		var lvl := start_next_lvl + i
		if lvl > 50:
			break
		var cap := RulesEngineScript.storage_capacity(lvl)
		var lvl_panel := _make_storage_row("Seviye %d" % lvl, IconStorage, cap, false)
		_prod_vbox.add_child(lvl_panel)


func _make_storage_row(label_text: String, icon_tex: Texture2D, capacity: int, is_highlighted: bool) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	if is_highlighted:
		sb.bg_color = Color(0.98, 0.76, 0.36, 0.90) # Canlı altın-turuncu vurgu
		sb.border_color = Color(0.85, 0.58, 0.18, 0.95)
		sb.set_border_width_all(1)
	else:
		sb.bg_color = Color(0.95, 0.89, 0.77, 0.65)
		sb.border_color = Color(0.80, 0.72, 0.58, 0.50)
		sb.border_width_bottom = 1
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	pc.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	# Sütun 1: Seviye İsmi
	var c1 := Label.new()
	c1.text = label_text
	c1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c1.add_theme_font_override("font", FontNunitoBold)
	c1.add_theme_font_size_override("font_size", 26)
	c1.add_theme_color_override("font_color", Color(0.12, 0.08, 0.04))
	row.add_child(c1)

	# Sütun 2: Depo Kapasitesi (Simge + Sayı)
	var c2 := HBoxContainer.new()
	c2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c2.alignment = BoxContainer.ALIGNMENT_BEGIN
	c2.add_theme_constant_override("separation", 10)
	if icon_tex != null:
		var tr := TextureRect.new()
		tr.texture = icon_tex
		tr.custom_minimum_size = Vector2(28, 28)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		c2.add_child(tr)
	var cap_lbl := Label.new()
	cap_lbl.text = _format_number(capacity)
	cap_lbl.add_theme_font_override("font", FontNunitoBold)
	cap_lbl.add_theme_font_size_override("font_size", 26)
	cap_lbl.add_theme_color_override("font_color", Color(0.12, 0.08, 0.04))
	c2.add_child(cap_lbl)
	row.add_child(c2)

	pc.add_child(row)
	return pc


func _build_mine_production_table(cur_lvl: int) -> void:
	# Kaynak simgesi seçimi
	var res_icon: Texture2D = IconWood
	if _current_key == "stone":
		res_icon = IconStone
	elif _current_key == "iron":
		res_icon = IconIron

	# 1. Başlık Satırı (Üretim | saatlik | günlük)
	var header_panel := PanelContainer.new()
	var h_sb := StyleBoxFlat.new()
	h_sb.bg_color = Color(0.85, 0.74, 0.56, 0.95)
	h_sb.set_corner_radius_all(8)
	h_sb.content_margin_left = 14
	h_sb.content_margin_right = 14
	h_sb.content_margin_top = 8
	h_sb.content_margin_bottom = 8
	header_panel.add_theme_stylebox_override("panel", h_sb)

	var h_row := HBoxContainer.new()
	var col1_lbl := Label.new()
	col1_lbl.text = "Üretim"
	col1_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col1_lbl.add_theme_font_override("font", FontNunitoBold)
	col1_lbl.add_theme_font_size_override("font_size", 28)
	col1_lbl.add_theme_color_override("font_color", Color(0.12, 0.08, 0.04))
	h_row.add_child(col1_lbl)

	var col2_lbl := Label.new()
	var cur_speed_mult: float = _get_speed_mult()
	col2_lbl.text = "saatlik (%dx Bonus)" % int(round(cur_speed_mult)) if cur_speed_mult > 1.01 else "saatlik"
	col2_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col2_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col2_lbl.add_theme_font_override("font", FontNunitoBold)
	col2_lbl.add_theme_font_size_override("font_size", 28)
	col2_lbl.add_theme_color_override("font_color", Color(0.12, 0.08, 0.04))
	h_row.add_child(col2_lbl)

	var col3_lbl := Label.new()
	col3_lbl.text = "günlük"
	col3_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col3_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col3_lbl.add_theme_font_override("font", FontNunitoBold)
	col3_lbl.add_theme_font_size_override("font_size", 28)
	col3_lbl.add_theme_color_override("font_color", Color(0.12, 0.08, 0.04))
	h_row.add_child(col3_lbl)

	header_panel.add_child(h_row)
	_prod_vbox.add_child(header_panel)

	# 2. Güncel Satırı (Canlı turuncu-altın şerit, Görsel 1 ile birebir aynı)
	var cur_hourly: int
	if cur_lvl == 0:
		cur_hourly = 108
	else:
		cur_hourly = int(round(RulesEngineScript.production_per_hour(_current_key, cur_lvl)))
	var cur_daily: int = cur_hourly * 24

	var current_panel := _make_prod_row("Güncel", res_icon, cur_hourly, cur_daily, true)
	_prod_vbox.add_child(current_panel)

	# 3. Gelecek 4 Seviye
	var start_next_lvl := 1 if cur_lvl == 0 else (cur_lvl + 1)
	for i in range(4):
		var lvl := start_next_lvl + i
		if lvl > 50:
			break
		var hr := int(round(RulesEngineScript.production_per_hour(_current_key, lvl)))
		var dl := hr * 24
		var lvl_panel := _make_prod_row("Seviye %d" % lvl, res_icon, hr, dl, false)
		_prod_vbox.add_child(lvl_panel)


func _make_prod_row(label_text: String, icon_tex: Texture2D, hourly: int, daily: int, is_highlighted: bool) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	if is_highlighted:
		sb.bg_color = Color(0.98, 0.76, 0.36, 0.90) # Canlı altın-turuncu vurgu
		sb.border_color = Color(0.85, 0.58, 0.18, 0.95)
		sb.set_border_width_all(1)
	else:
		sb.bg_color = Color(0.95, 0.89, 0.77, 0.65)
		sb.border_color = Color(0.80, 0.72, 0.58, 0.50)
		sb.border_width_bottom = 1
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	pc.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	# Sütun 1: Seviye İsmi
	var c1 := Label.new()
	c1.text = label_text
	c1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c1.add_theme_font_override("font", FontNunitoBold)
	c1.add_theme_font_size_override("font_size", 26)
	c1.add_theme_color_override("font_color", Color(0.12, 0.08, 0.04))
	row.add_child(c1)

	# Sütun 2: Saatlik (Simge + Sayı)
	var c2 := HBoxContainer.new()
	c2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c2.alignment = BoxContainer.ALIGNMENT_CENTER
	c2.add_theme_constant_override("separation", 8)
	if icon_tex != null:
		var tr := TextureRect.new()
		tr.texture = icon_tex
		tr.custom_minimum_size = Vector2(28, 28)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		c2.add_child(tr)
	var hr_lbl := Label.new()
	hr_lbl.text = _format_number(hourly)
	hr_lbl.add_theme_font_override("font", FontNunitoBold)
	hr_lbl.add_theme_font_size_override("font_size", 26)
	hr_lbl.add_theme_color_override("font_color", Color(0.12, 0.08, 0.04))
	c2.add_child(hr_lbl)
	row.add_child(c2)

	# Sütun 3: Günlük (Simge + Sayı)
	var c3 := HBoxContainer.new()
	c3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c3.alignment = BoxContainer.ALIGNMENT_CENTER
	c3.add_theme_constant_override("separation", 8)
	if icon_tex != null:
		var tr3 := TextureRect.new()
		tr3.texture = icon_tex
		tr3.custom_minimum_size = Vector2(28, 28)
		tr3.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr3.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		c3.add_child(tr3)
	var dl_lbl := Label.new()
	dl_lbl.text = _format_number(daily)
	dl_lbl.add_theme_font_override("font", FontNunitoBold)
	dl_lbl.add_theme_font_size_override("font_size", 26)
	dl_lbl.add_theme_color_override("font_color", Color(0.12, 0.08, 0.04))
	c3.add_child(dl_lbl)
	row.add_child(c3)

	pc.add_child(row)
	return pc


func _format_number(val: int) -> String:
	var s := str(val)
	var result := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		result = s[i] + result
		count += 1
		if count % 3 == 0 and i > 0 and s[i - 1] != "-":
			result = "." + result
	return result


func _ready() -> void:
	_ensure_nodes()
	_configure_scroll_containers()
	if close_btn != null and not close_btn.pressed.is_connected(_on_close_pressed):
		close_btn.pressed.connect(_on_close_pressed)
	if upgrade_btn != null and not upgrade_btn.pressed.is_connected(_on_upgrade_pressed):
		upgrade_btn.pressed.connect(_on_upgrade_pressed)

	if tab_upgrade_btn != null and not tab_upgrade_btn.pressed.is_connected(_on_tab_upgrade_pressed):
		tab_upgrade_btn.pressed.connect(_on_tab_upgrade_pressed)
	if tab_research_btn != null and not tab_research_btn.pressed.is_connected(_on_tab_research_pressed):
		tab_research_btn.pressed.connect(_on_tab_research_pressed)
	if tab_train_btn != null and not tab_train_btn.pressed.is_connected(_on_tab_train_pressed):
		tab_train_btn.pressed.connect(_on_tab_train_pressed)
	if build_barracks_btn != null and not build_barracks_btn.pressed.is_connected(_on_tab_upgrade_pressed):
		build_barracks_btn.pressed.connect(_on_tab_upgrade_pressed)

	if close_btn != null:
		close_btn.pivot_offset = Vector2(24, 24)
		close_btn.mouse_entered.connect(func():
			var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(close_btn, "scale", Vector2(1.10, 1.10), 0.12)
		)
		close_btn.mouse_exited.connect(func():
			var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(close_btn, "scale", Vector2(1.0, 1.0), 0.12)
		)

	if upgrade_btn != null:
		upgrade_btn.pivot_offset = Vector2(490, 42)
		upgrade_btn.button_down.connect(func():
			var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(upgrade_btn, "scale", Vector2(0.97, 0.97), 0.08)
		)
		upgrade_btn.button_up.connect(func():
			var tw = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(upgrade_btn, "scale", Vector2(1.0, 1.0), 0.2)
		)

	# EventBus & StoreManager listeners for reactive UI
	var bus = Engine.get_main_loop().root.get_node_or_null("EventBus") if Engine.get_main_loop() is SceneTree else null
	if bus != null:
		if bus.has_signal("research_completed") and not bus.research_completed.is_connected(_on_bus_research_completed):
			bus.research_completed.connect(_on_bus_research_completed)
		if bus.has_signal("unit_trained") and not bus.unit_trained.is_connected(_on_bus_unit_trained):
			bus.unit_trained.connect(_on_bus_unit_trained)
		if bus.has_signal("resources_changed") and not bus.resources_changed.is_connected(_on_bus_resources_changed):
			bus.resources_changed.connect(_on_bus_resources_changed)
		if bus.has_signal("state_changed") and not bus.state_changed.is_connected(_on_bus_state_changed):
			bus.state_changed.connect(_on_bus_state_changed)

	var sm := _get_store_manager()
	if sm != null and sm.has_signal("scrolls_changed") and not sm.scrolls_changed.is_connected(_on_scrolls_changed):
		sm.scrolls_changed.connect(_on_scrolls_changed)


func _get_store_manager() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree and (loop as SceneTree).root != null:
		return (loop as SceneTree).root.get_node_or_null("StoreManager")
	return null


func _on_scrolls_changed(_scrolls: Dictionary) -> void:
	if visible:
		_update_active_build_info()
		_update_active_research_info()
		_update_active_train_info()


func _configure_scroll_containers() -> void:
	for sc_path in ["VBox/RequirementSection/ReqScroll", "VBox/ResearchSection/ResearchScroll", "VBox/TrainSection/TrainScroll"]:
		var sc := get_node_or_null(sc_path) as ScrollContainer
		if sc != null:
			sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sc.scroll_deadzone = 12


func _fmt_duration(secs: int) -> String:
	var s := maxi(0, secs)
	var sm := _get_store_manager()
	if sm != null and sm.has_method("format_duration"):
		return str(sm.call("format_duration", s))
	var h := s / 3600
	var m := (s % 3600) / 60
	var rem := s % 60
	if h > 0:
		return "%02d:%02d:%02d" % [h, m, rem]
	return "%02d:%02d" % [m, rem]


func _ensure_speedup_styles() -> void:
	if _cached_speedup_have_sb == null:
		_cached_speedup_have_sb = StyleBoxFlat.new()
		_cached_speedup_have_sb.bg_color = Color(0.16, 0.44, 0.24, 0.98)
		_cached_speedup_have_sb.border_color = Color(0.95, 0.80, 0.36, 0.98)
		_cached_speedup_have_sb.set_border_width_all(2)
		_cached_speedup_have_sb.set_corner_radius_all(12)
		_cached_speedup_have_sb.content_margin_left = 10
		_cached_speedup_have_sb.content_margin_right = 10
		_cached_speedup_have_hover = _cached_speedup_have_sb.duplicate() as StyleBoxFlat
		_cached_speedup_have_hover.bg_color = Color(0.22, 0.56, 0.32, 1.0)
	if _cached_speedup_buy_sb == null:
		_cached_speedup_buy_sb = StyleBoxFlat.new()
		_cached_speedup_buy_sb.bg_color = Color(0.12, 0.25, 0.46, 0.98)
		_cached_speedup_buy_sb.border_color = Color(0.92, 0.76, 0.34, 0.96)
		_cached_speedup_buy_sb.set_border_width_all(2)
		_cached_speedup_buy_sb.set_corner_radius_all(12)
		_cached_speedup_buy_sb.content_margin_left = 10
		_cached_speedup_buy_sb.content_margin_right = 10
		_cached_speedup_buy_hover = _cached_speedup_buy_sb.duplicate() as StyleBoxFlat
		_cached_speedup_buy_hover.bg_color = Color(0.18, 0.34, 0.60, 1.0)


func _apply_speedup_btn_style(btn: Button, category: String) -> void:
	if btn == null:
		return
	_ensure_speedup_styles()
	var sm := _get_store_manager()
	var count := 0
	if sm != null and sm.has_method("get_category_scroll_total"):
		count = int(sm.call("get_category_scroll_total", category))
	var sig := "%s:%d" % [category, count]
	var bid := btn.get_instance_id()
	if str(_last_speedup_sig_by_btn.get(bid, "")) == sig:
		return
	_last_speedup_sig_by_btn[bid] = sig
	btn.text = "⚡ Hızlandır (%d)" % count if count > 0 else "🛒 Parşömen Al"
	var sb_n := _cached_speedup_have_sb if count > 0 else _cached_speedup_buy_sb
	var sb_h := _cached_speedup_have_hover if count > 0 else _cached_speedup_buy_hover
	btn.add_theme_stylebox_override("normal", sb_n)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_stylebox_override("pressed", sb_h)
	btn.add_theme_color_override("font_color", Color(1.0, 0.96, 0.84))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.92, 0.62))


func _open_speedup(category: String, target_id: Variant, title_text: String) -> void:
	var sm := _get_store_manager()
	if sm != null and sm.has_method("open_speedup_modal"):
		sm.call("open_speedup_modal", self, category, target_id, title_text)
	elif sm != null and sm.has_method("open_market"):
		sm.call("open_market", self, category)


func _on_bus_research_completed(_vid: int, _ukey: String) -> void:
	if visible:
		refresh()


func _on_bus_unit_trained(_vid: int, _ukey: String, _count: int) -> void:
	if visible and not _in_action_emit:
		_last_special_box_sig = ""
		refresh()


func _on_bus_resources_changed(_vid: int) -> void:
	if visible and not _in_action_emit:
		refresh()


func _on_bus_state_changed() -> void:
	if visible and not _in_action_emit:
		_last_special_box_sig = ""
		refresh()


func _process(delta: float) -> void:
	if not visible:
		if _focused_train_line != null or absf(offset_bottom - (-256.0)) > 0.5:
			_focused_train_unit = ""
			_focused_train_line = null
			_focused_train_spin = null
			_kb_scroll_done_for = ""
			_restore_keyboard_lift()
		_active_info_accum = 0.0
		return
	if _current_tab == Tab.TRAIN:
		_update_keyboard_lift()
	elif absf(offset_bottom - (-256.0)) > 0.5 or _kb_was_open_on_mobile:
		_restore_keyboard_lift()
	_active_info_accum += maxf(delta, 0.0)
	if _active_info_accum < 0.5:
		return
	_active_info_accum = 0.0
	if _current_tab == Tab.UPGRADE:
		_update_active_build_info()
	elif _current_tab == Tab.RESEARCH:
		_update_active_research_info()
	elif _current_tab == Tab.TRAIN:
		_update_active_train_info()


func _on_close_pressed() -> void:
	_focused_train_unit = ""
	_focused_train_line = null
	_focused_train_spin = null
	_kb_scroll_done_for = ""
	_pre_kb_scroll_y = -1
	_post_kb_restore_scroll_y = -1
	_post_kb_restore_unit = ""
	_restore_keyboard_lift()
	hide()
	closed.emit()


func _on_tab_upgrade_pressed() -> void:
	_pre_kb_scroll_y = -1
	_post_kb_restore_scroll_y = -1
	_post_kb_restore_unit = ""
	_current_tab = Tab.UPGRADE
	refresh()


func _on_tab_research_pressed() -> void:
	_pre_kb_scroll_y = -1
	_post_kb_restore_scroll_y = -1
	_post_kb_restore_unit = ""
	_current_tab = Tab.RESEARCH
	refresh()


func _on_tab_train_pressed() -> void:
	_current_tab = Tab.TRAIN
	refresh()


func is_train_input_focused() -> bool:
	return _focused_train_line != null and is_instance_valid(_focused_train_line) and _focused_train_line.has_focus()


func switch_tab(tab_idx: int) -> void:
	_switch_tab(tab_idx)


func _switch_tab(tab_idx: int) -> void:
	match tab_idx:
		0, Tab.UPGRADE: _on_tab_upgrade_pressed()
		1, Tab.RESEARCH: _on_tab_research_pressed()
		2, Tab.TRAIN: _on_tab_train_pressed()


func show_building(village: Dictionary, key: String) -> void:
	_ensure_nodes()
	_pre_kb_scroll_y = -1
	_post_kb_restore_scroll_y = -1
	_post_kb_restore_unit = ""
	_village = village
	_current_key = key
	_current_tab = Tab.UPGRADE
	_last_research_sig = ""
	_last_train_sig = ""
	_last_prod_table_sig = ""
	_last_special_box_sig = ""
	refresh()
	show()


func _current_now() -> int:
	if GameLoopScript.instance != null and GameLoopScript.instance.now_unix() > 0:
		return GameLoopScript.instance.now_unix()
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs != null:
		var w = gs.world
		if typeof(w) == TYPE_DICTIONARY and (w as Dictionary).has("sim_now_unix"):
			return int((w as Dictionary)["sim_now_unix"])
	return int(Time.get_unix_time_from_system())


func _update_tab_buttons_styling(barracks_level: int) -> void:
	if tab_bar == null:
		return
	var tab_sig := "%d:%d" % [int(_current_tab), 1 if barracks_level >= 1 else 0]
	if tab_sig == _last_tab_style_sig and _tab_act_sb != null:
		return
	_last_tab_style_sig = tab_sig

	if _tab_act_sb == null and tab_upgrade_btn != null:
		_tab_act_sb = tab_upgrade_btn.get_theme_stylebox("normal")
	if _tab_inact_sb == null and tab_research_btn != null:
		_tab_inact_sb = tab_research_btn.get_theme_stylebox("normal")
	var s_act = _tab_act_sb
	var s_inact = _tab_inact_sb

	tab_upgrade_btn.add_theme_stylebox_override("normal", s_act if _current_tab == Tab.UPGRADE else s_inact)
	tab_upgrade_btn.add_theme_color_override("font_color", Color(1.0, 0.98, 0.90) if _current_tab == Tab.UPGRADE else Color(0.80, 0.76, 0.70))
	tab_upgrade_btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	tab_upgrade_btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.95, 0.75))
	tab_upgrade_btn.add_theme_color_override("font_focus_color", Color(1.0, 0.98, 0.90))

	tab_research_btn.add_theme_stylebox_override("normal", s_act if _current_tab == Tab.RESEARCH else s_inact)
	tab_research_btn.add_theme_color_override("font_color", Color(1.0, 0.98, 0.90) if _current_tab == Tab.RESEARCH else Color(0.80, 0.76, 0.70))
	tab_research_btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	tab_research_btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.95, 0.75))
	tab_research_btn.add_theme_color_override("font_focus_color", Color(1.0, 0.98, 0.90))

	tab_train_btn.add_theme_stylebox_override("normal", s_act if _current_tab == Tab.TRAIN else s_inact)
	tab_train_btn.add_theme_color_override("font_color", Color(1.0, 0.98, 0.90) if _current_tab == Tab.TRAIN else Color(0.80, 0.76, 0.70))
	tab_train_btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	tab_train_btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.95, 0.75))
	tab_train_btn.add_theme_color_override("font_focus_color", Color(1.0, 0.98, 0.90))

	for btn in [tab_upgrade_btn, tab_research_btn, tab_train_btn]:
		if btn != null:
			btn.add_theme_font_override("font", FontNunitoBold)
			btn.add_theme_font_size_override("font_size", 30)
			btn.add_theme_constant_override("outline_size", 3)
			btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
			btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
			btn.add_theme_constant_override("shadow_offset_y", 2)

	if barracks_level < 1:
		tab_research_btn.text = "🔒 Birim Araştır"
		tab_train_btn.text = "🔒 Birim Eğit"
	else:
		tab_research_btn.text = "📜 Birim Araştır"
		tab_train_btn.text = "⚔️ Birim Eğit"


func refresh() -> void:
	_ensure_nodes()
	if _current_key.is_empty():
		return

	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs != null and gs.has_active_village():
		_village = gs.get_active_village()

	if _village.is_empty():
		return

	var state: Dictionary = (gs.as_live_dict() if gs.has_method("as_live_dict") else gs.to_dict()) if gs != null else {}
	var b_data: Dictionary = RulesEngineScript.building_data(_current_key)
	var b_name: String = str(b_data.get("name", _current_key))
	var cur_lvl: int = int(_village.get("buildings", {}).get(_current_key, 0))
	var max_lvl: int = RulesEngineScript._max_level(_current_key)

	title_label.text = b_name

	# Otantik bina açıklaması gösterimi (KingsAge orijinal raporları)
	if _desc_label != null and _desc_box != null:
		var desc: String = BUILDING_DESCRIPTIONS.get(_current_key, "")
		if desc.is_empty():
			_desc_box.hide()
		else:
			_desc_label.text = desc
			_desc_box.show()

	# Taş Ocağı, Oduncu Kampı, Maden Ocağı, Depo ve Kale için üretim / kapasite / hızlanma tablosu
	if _current_tab == Tab.UPGRADE and _current_key in ["wood", "stone", "iron", "storage", "main"]:
		_update_production_table(cur_lvl)
	else:
		if _prod_box != null:
			_prod_box.hide()

	# Kuyumcu (Altın Zırh), Köşk (Kont Eğitimi) ve Kışla (Köy Garnizonu & Destek Birlikleri) özel aksiyon kutusu
	if _current_tab == Tab.UPGRADE and ((_current_key in ["smith", "snob"] and cur_lvl >= 1) or (_current_key == "barracks" and cur_lvl >= 1)):
		_update_special_building_actions(cur_lvl)
	else:
		if _special_box != null:
			_special_box.hide()

	if _current_key == "barracks":
		tab_bar.show()
		_update_tab_buttons_styling(cur_lvl)
		if cur_lvl < 1 and _current_tab != Tab.UPGRADE:
			locked_banner.show()
			_set_upgrade_nodes_visible(false)
			research_section.hide()
			train_section.hide()
			offset_top = -680.0
			level_label.text = "Henüz İnşa Edilmedi (Seviye 0)"
			return
		else:
			locked_banner.hide()
	else:
		tab_bar.hide()
		locked_banner.hide()
		_current_tab = Tab.UPGRADE

	# Process active tab view
	if _current_tab == Tab.UPGRADE:
		locked_banner.hide()
		research_section.hide()
		train_section.hide()
		_set_upgrade_nodes_visible(true)
		_refresh_upgrade_view(state, cur_lvl, max_lvl)
	elif _current_tab == Tab.RESEARCH:
		locked_banner.hide()
		_set_upgrade_nodes_visible(false)
		train_section.hide()
		research_section.show()
		if _prod_box != null:
			_prod_box.hide()
		if _desc_box != null:
			_desc_box.hide()
		level_label.text = "Kışla Seviyesi: %d / %d" % [cur_lvl, max_lvl]
		offset_top = -1100.0
		_populate_research_list()
		_update_active_research_info()
	elif _current_tab == Tab.TRAIN:
		locked_banner.hide()
		_set_upgrade_nodes_visible(false)
		research_section.hide()
		train_section.show()
		if _prod_box != null:
			_prod_box.hide()
		if _desc_box != null:
			_desc_box.hide()
		level_label.text = "Kışla Seviyesi: %d / %d" % [cur_lvl, max_lvl]
		if _focused_train_line == null or not is_instance_valid(_focused_train_line) or not _focused_train_line.has_focus():
			_restore_keyboard_lift()
			offset_top = -1150.0
		_populate_train_list()
		_update_active_train_info()
		_update_keyboard_lift()


func _set_upgrade_nodes_visible(p_visible: bool) -> void:
	if has_node("VBox/CostContainer"):
		$VBox/CostContainer.visible = p_visible
	if has_node("VBox/MetaContainer"):
		$VBox/MetaContainer.visible = p_visible
	if upgrade_btn != null:
		upgrade_btn.visible = p_visible
	if req_section != null and not p_visible:
		req_section.hide()
	if active_build_box != null and not p_visible:
		active_build_box.hide()


## Tutorial ve odaklama yardımcısı: araştırma veya eğitim sekmesindeki birim kartına kaydırır.
func scroll_to_unit_card(u_key: String) -> void:
	_ensure_nodes()
	if _current_tab == Tab.RESEARCH and research_list != null:
		var scroll := get_node_or_null("VBox/ResearchSection/ResearchScroll") as ScrollContainer
		var card := research_list.get_node_or_null("ResearchCard_" + u_key) as Control
		if scroll != null and card != null:
			var target_y := int(maxf(0.0, card.position.y - 16.0))
			if abs(scroll.scroll_vertical - target_y) > 4:
				scroll.scroll_vertical = target_y
	elif _current_tab == Tab.TRAIN and train_list != null:
		var scroll := get_node_or_null("VBox/TrainSection/TrainScroll") as ScrollContainer
		var card := train_list.get_node_or_null("TrainCard_" + u_key) as Control
		if scroll != null and card != null:
			var target_y := int(maxf(0.0, card.position.y - 16.0))
			if abs(scroll.scroll_vertical - target_y) > 4:
				scroll.scroll_vertical = target_y


# =============================================================================
#  BİNA YÜKSELTME SEKMESİ (UPGRADE TAB)
# =============================================================================

func _refresh_upgrade_view(state: Dictionary, cur_lvl: int, max_lvl: int) -> void:
	var details: Dictionary = EconomyAPI.build_details(_village, _current_key, state)
	var tgt_lvl: int = int(details.get("target_level", cur_lvl + 1))
	var total_cost: Dictionary = details.get("cost", {})
	var extra_pct: int = int(details.get("extra_percent", 0))
	var is_res_bldg: bool = (_current_key in ["wood", "stone", "iron", "storage"])

	var vid: int = int(_village.get("id", -1))
	var active_in_queue := false
	var active_tgt := 0
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs != null:
		for item in gs.queues:
			if typeof(item) == TYPE_DICTIONARY and int(item.get("village_id", -1)) == vid and str(item.get("type", "")) == "build" and str(item.get("key", "")) == _current_key:
				active_in_queue = true
				active_tgt = int(item.get("target_level", 0))
				break

	if cur_lvl >= max_lvl and max_lvl > 0:
		level_label.text = "Seviye: %d / %d (Maksimum)" % [cur_lvl, max_lvl]
	elif active_in_queue:
		level_label.text = "Seviye: %d (İnşaat: Sv. %d ➔ Sıradaki: Sv. %d)" % [cur_lvl, active_tgt, tgt_lvl]
	else:
		level_label.text = "Seviye: %d  (Hedef: %d / %d)" % [cur_lvl, tgt_lvl, max_lvl]

	_update_active_build_info()

	var res_dict: Dictionary = _village.get("resources", {})
	var cur_w: int = int(res_dict.get("wood", 0))
	var cur_s: int = int(res_dict.get("stone", 0))
	var cur_i: int = int(res_dict.get("iron", 0))
	var req_w: int = int(total_cost.get("wood", 0))
	var req_s: int = int(total_cost.get("stone", 0))
	var req_i: int = int(total_cost.get("iron", 0))

	cost_wood.text = str(req_w)
	cost_stone.text = str(req_s)
	cost_iron.text = str(req_i)

	cost_wood.add_theme_color_override("font_color", Color(1.0, 0.42, 0.42, 1.0) if cur_w < req_w else Color(1.0, 1.0, 1.0, 1.0))
	cost_stone.add_theme_color_override("font_color", Color(1.0, 0.42, 0.42, 1.0) if cur_s < req_s else Color(1.0, 1.0, 1.0, 1.0))
	cost_iron.add_theme_color_override("font_color", Color(1.0, 0.42, 0.42, 1.0) if cur_i < req_i else Color(1.0, 1.0, 1.0, 1.0))

	var proj_blds: Dictionary = details.get("projected", _village.get("buildings", {})) if typeof(details.get("projected")) == TYPE_DICTIONARY else (_village.get("buildings", {}) as Dictionary)
	var castle_lvl := maxi(1, int(proj_blds.get("main", 1)))
	var dur_secs: float = RulesEngineScript.build_seconds(_current_key, tgt_lvl, castle_lvl)
	var dur_str: String = _format_time_str(int(ceil(dur_secs)))
	var boost_note := ""
	var gc = Engine.get_main_loop().root.get_node_or_null("GameConfig") if Engine.get_main_loop() is SceneTree else null
	if gs != null and gc != null and gc.has_method("is_starter_boost_active") and bool(gc.call("is_starter_boost_active", gs.world)):
		boost_note = " (2× Başlangıç Hızı)"
	if active_in_queue:
		time_label.text = "Sıradaki İnşa Süresi: %s%s" % [dur_str, boost_note]
	else:
		time_label.text = "İnşa Süresi: %s%s" % [dur_str, boost_note]

	if extra_pct > 0:
		extra_cost_label.text = "⚠️ Kuyruk Ek Maliyeti: +%%%d" % extra_pct
		extra_cost_label.show()
	else:
		extra_cost_label.hide()

	var chain: Array = RulesEngineScript.requirement_chain(_village.get("buildings", {}), _current_key, tgt_lvl)
	var is_upgradable: bool = bool(details.get("ok", false))
	var has_tall_box: bool = is_res_bldg or (_current_key == "main") or (_special_box != null and _special_box.visible)

	if is_upgradable:
		_clear_req_container()
		req_section.hide()
		offset_top = -980.0 if has_tall_box else -680.0
		upgrade_btn.disabled = false
		upgrade_btn.text = ("Sıraya Ekle (Seviye %d)" if active_in_queue else "Yükselt (Seviye %d)") % tgt_lvl

		if _cached_upg_norm_sb == null:
			_cached_upg_norm_sb = StyleBoxFlat.new()
			_cached_upg_norm_sb.bg_color = Color(0.18, 0.60, 0.30, 1.0)
			_cached_upg_norm_sb.border_color = Color(0.55, 0.90, 0.62, 1.0)
			_cached_upg_norm_sb.border_width_top = 2
			_cached_upg_norm_sb.border_width_bottom = 5
			_cached_upg_norm_sb.border_width_left = 2
			_cached_upg_norm_sb.border_width_right = 2
			_cached_upg_norm_sb.set_corner_radius_all(16)
			_cached_upg_norm_sb.shadow_color = Color(0.04, 0.22, 0.08, 0.45)
			_cached_upg_norm_sb.shadow_size = 0
			_cached_upg_norm_sb.shadow_offset = Vector2(0, 4)
			_cached_upg_norm_sb.content_margin_top = 16
			_cached_upg_norm_sb.content_margin_bottom = 16

			_cached_upg_hover_sb = StyleBoxFlat.new()
			_cached_upg_hover_sb.bg_color = Color(0.22, 0.70, 0.36, 1.0)
			_cached_upg_hover_sb.border_color = Color(0.75, 1.0, 0.80, 1.0)
			_cached_upg_hover_sb.border_width_top = 2
			_cached_upg_hover_sb.border_width_bottom = 5
			_cached_upg_hover_sb.border_width_left = 2
			_cached_upg_hover_sb.border_width_right = 2
			_cached_upg_hover_sb.set_corner_radius_all(16)
			_cached_upg_hover_sb.shadow_color = Color(0.06, 0.32, 0.12, 0.55)
			_cached_upg_hover_sb.shadow_size = 0
			_cached_upg_hover_sb.shadow_offset = Vector2(0, 4)
			_cached_upg_hover_sb.content_margin_top = 16
			_cached_upg_hover_sb.content_margin_bottom = 16

			_cached_upg_pressed_sb = StyleBoxFlat.new()
			_cached_upg_pressed_sb.bg_color = Color(0.12, 0.46, 0.22, 1.0)
			_cached_upg_pressed_sb.border_color = Color(0.95, 0.85, 0.45, 1.0)
			_cached_upg_pressed_sb.border_width_top = 4
			_cached_upg_pressed_sb.border_width_bottom = 2
			_cached_upg_pressed_sb.border_width_left = 2
			_cached_upg_pressed_sb.border_width_right = 2
			_cached_upg_pressed_sb.set_corner_radius_all(16)
			_cached_upg_pressed_sb.content_margin_top = 16
			_cached_upg_pressed_sb.content_margin_bottom = 16

		upgrade_btn.add_theme_stylebox_override("normal", _cached_upg_norm_sb)
		upgrade_btn.add_theme_stylebox_override("hover", _cached_upg_hover_sb)
		upgrade_btn.add_theme_stylebox_override("pressed", _cached_upg_pressed_sb)
		upgrade_btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		upgrade_btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
		upgrade_btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.95, 0.70))
		upgrade_btn.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 1.0))
		upgrade_btn.add_theme_constant_override("outline_size", 3)
		upgrade_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		upgrade_btn.add_theme_color_override("font_shadow_color", Color(0.04, 0.20, 0.08, 0.9))
		upgrade_btn.add_theme_constant_override("shadow_offset_y", 2)
		upgrade_btn.add_theme_font_size_override("font_size", 32)
	else:
		upgrade_btn.disabled = true
		if _cached_upg_dis_sb == null:
			_cached_upg_dis_sb = StyleBoxFlat.new()
			_cached_upg_dis_sb.bg_color = Color(0.20, 0.19, 0.23, 0.95)
			_cached_upg_dis_sb.border_color = Color(0.40, 0.38, 0.44, 0.70)
			_cached_upg_dis_sb.border_width_top = 1
			_cached_upg_dis_sb.border_width_bottom = 4
			_cached_upg_dis_sb.border_width_left = 1
			_cached_upg_dis_sb.border_width_right = 1
			_cached_upg_dis_sb.set_corner_radius_all(16)
			_cached_upg_dis_sb.content_margin_top = 16
			_cached_upg_dis_sb.content_margin_bottom = 16

		upgrade_btn.add_theme_stylebox_override("normal", _cached_upg_dis_sb)
		upgrade_btn.add_theme_stylebox_override("disabled", _cached_upg_dis_sb)
		upgrade_btn.add_theme_color_override("font_color", Color(0.85, 0.82, 0.78))
		upgrade_btn.add_theme_color_override("font_disabled_color", Color(0.85, 0.82, 0.78))
		upgrade_btn.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.6))
		upgrade_btn.add_theme_constant_override("shadow_offset_y", 1)
		upgrade_btn.add_theme_font_size_override("font_size", 32)

		var reason: String = str(details.get("reason", ""))
		if reason == "max_level":
			upgrade_btn.text = "Maksimum Seviyeye Ulaşıldı"
			_clear_req_container()
			req_section.hide()
			offset_top = -980.0 if has_tall_box else -680.0
		elif reason == "requirements" or reason == "locked":
			upgrade_btn.text = "Önkoşullar Karşılanmadı"
			req_section.show()
			offset_top = -1280.0 if has_tall_box else -1020.0
			_populate_chain_list(chain)
		elif reason == "resources":
			var sto_lvl: int = int(_village.get("buildings", {}).get("storage", 1))
			var sto_cap: int = RulesEngineScript.storage_capacity(sto_lvl)
			var max_req_res: int = maxi(req_w, maxi(req_s, req_i))
			if sto_cap > 0 and max_req_res > sto_cap and _current_key != "storage":
				upgrade_btn.text = "Depo Kapasitesi Yetersiz (Depo Yükselt)"
				req_section.show()
				offset_top = -1280.0 if has_tall_box else -1020.0
				_populate_chain_list([{"key": "storage", "level": sto_lvl + 1, "current": sto_lvl}])
			else:
				upgrade_btn.text = "Yetersiz Hammadde"
				if details.get("missing", []).size() > 0:
					req_section.show()
					offset_top = -1280.0 if has_tall_box else -1020.0
					_populate_chain_list(chain)
				else:
					_clear_req_container()
					req_section.hide()
					offset_top = -980.0 if has_tall_box else -680.0
		elif reason == "citizens":
			upgrade_btn.text = "Yetersiz Vatandaş (Değirmen Gerek)"
			var frm_lvl: int = int(_village.get("buildings", {}).get("farm", 1))
			req_section.show()
			offset_top = -1280.0 if has_tall_box else -1020.0
			_populate_chain_list([{"key": "farm", "level": frm_lvl + 1, "current": frm_lvl}])
		else:
			upgrade_btn.text = "Yükseltilemez"
			_clear_req_container()
			req_section.hide()
			offset_top = -980.0 if has_tall_box else -680.0


func _clear_req_container() -> void:
	if req_container == null:
		return
	for child in req_container.get_children():
		req_container.remove_child(child)
		child.queue_free()


func _populate_chain_list(chain: Array) -> void:
	if req_container == null:
		return
	var valid_rows: Array[Dictionary] = []
	var wanted_names: Array[String] = []
	for node in chain:
		if typeof(node) != TYPE_DICTIONARY:
			continue
		var req_dict: Dictionary = node
		var req_key: String = str(req_dict.get("key", ""))
		if req_key.is_empty() or req_key == _current_key:
			continue
		valid_rows.append(req_dict)
		wanted_names.append("ReqRow_" + req_key)

	# Mevcut satırların sırası ve anahtarları birebir aynıysa düğümleri silip yeniden yaratma (parmak sıçramasını önler)
	var existing_children := req_container.get_children()
	var can_reuse := (existing_children.size() == wanted_names.size())
	if can_reuse:
		for idx in range(wanted_names.size()):
			if existing_children[idx].name != wanted_names[idx]:
				can_reuse = false
				break

	if can_reuse:
		for idx in range(valid_rows.size()):
			var req_dict: Dictionary = valid_rows[idx]
			var req_key: String = str(req_dict.get("key", ""))
			var req_tgt: int = int(req_dict.get("level", 1))
			var req_cur: int = int(req_dict.get("current", 0))
			var req_b_data: Dictionary = RulesEngineScript.building_data(req_key)
			var req_name: String = str(req_b_data.get("name", req_key))
			var row_node := existing_children[idx] as HBoxContainer
			if row_node != null and row_node.get_child_count() > 0 and row_node.get_child(0) is Label:
				var lbl_existing := row_node.get_child(0) as Label
				lbl_existing.text = "• %s (Gereken: %d, Şu an: %d)" % [req_name, req_tgt, req_cur]
				lbl_existing.add_theme_color_override("font_color", Color(0.50, 0.92, 0.55, 1) if req_cur >= req_tgt else Color(0.98, 0.72, 0.56, 1))
		return

	_clear_req_container()
	for req_dict in valid_rows:
		var req_key: String = str(req_dict.get("key", ""))

		var req_tgt: int = int(req_dict.get("level", 1))
		var req_cur: int = int(req_dict.get("current", 0))

		var row := HBoxContainer.new()
		row.name = "ReqRow_" + req_key
		row.add_theme_constant_override("separation", 12)

		var req_b_data: Dictionary = RulesEngineScript.building_data(req_key)
		var req_name: String = str(req_b_data.get("name", req_key))

		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.text = "• %s (Gereken: %d, Şu an: %d)" % [req_name, req_tgt, req_cur]
		lbl.add_theme_font_override("font", FontNunitoSemiBold)
		lbl.add_theme_font_size_override("font_size", 25)
		lbl.add_theme_constant_override("outline_size", 0)
		lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		lbl.add_theme_color_override("font_color", Color(0.50, 0.92, 0.55, 1) if req_cur >= req_tgt else Color(0.98, 0.72, 0.56, 1))
		row.add_child(lbl)

		var goto_btn := Button.new()
		goto_btn.name = "GotoBtn_" + req_key
		goto_btn.text = "Binaya Git ➔"
		goto_btn.custom_minimum_size = Vector2(175, 52)
		goto_btn.add_theme_font_override("font", FontNunitoBold)
		goto_btn.add_theme_font_size_override("font_size", 24)
		goto_btn.add_theme_constant_override("outline_size", 1)
		goto_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		goto_btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		goto_btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		goto_btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
		goto_btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.95, 0.75))
		goto_btn.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 1.0))

		var btn_sb := StyleBoxFlat.new()
		btn_sb.bg_color = Color(0.18, 0.36, 0.64, 0.98)
		btn_sb.border_color = Color(0.95, 0.82, 0.48, 1.0)
		btn_sb.set_border_width_all(2)
		btn_sb.set_corner_radius_all(12)
		btn_sb.content_margin_left = 14
		btn_sb.content_margin_right = 14
		btn_sb.shadow_size = 0
		btn_sb.shadow_color = Color(0, 0, 0, 0.6)
		goto_btn.add_theme_stylebox_override("normal", btn_sb)

		var btn_hover := StyleBoxFlat.new()
		btn_hover.bg_color = Color(0.24, 0.48, 0.84, 1.0)
		btn_hover.border_color = Color(1.0, 0.92, 0.60, 1.0)
		btn_hover.set_border_width_all(2)
		btn_hover.set_corner_radius_all(12)
		btn_hover.shadow_size = 0
		btn_hover.shadow_color = Color(0, 0, 0, 0.8)

		var btn_pressed := StyleBoxFlat.new()
		btn_pressed.bg_color = Color(0.12, 0.26, 0.48, 1.0)
		btn_pressed.border_color = Color(1.0, 0.95, 0.70, 1.0)
		btn_pressed.set_border_width_all(2)
		btn_pressed.set_corner_radius_all(12)

		goto_btn.add_theme_stylebox_override("hover", btn_hover)
		goto_btn.add_theme_stylebox_override("pressed", btn_pressed)

		goto_btn.pressed.connect(_on_goto_building.bind(req_key))
		row.add_child(goto_btn)

		req_container.add_child(row)


func _on_goto_building(target_key: String) -> void:
	_current_key = target_key
	_current_tab = Tab.UPGRADE
	_last_prod_table_sig = ""
	_last_special_box_sig = ""
	refresh()
	building_switched.emit(target_key)


func _update_active_build_info() -> void:
	if active_build_box == null or _current_key.is_empty():
		return

	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null or not gs.has_active_village():
		active_build_box.hide()
		return

	var vid: int = gs.active_village_id
	var active_item: Dictionary = {}
	for item in gs.queues:
		if typeof(item) == TYPE_DICTIONARY and int(item.get("village_id", -1)) == vid and str(item.get("type", "")) == "build" and str(item.get("key", "")) == _current_key:
			active_item = item
			break

	if active_item.is_empty():
		active_build_box.hide()
		return

	active_build_box.show()
	var tgt: int = int(active_item.get("target_level", 1))
	var start: int = int(active_item.get("start_unix", 0))
	var finish: int = int(active_item.get("finish_unix", 0))
	var now := _current_now()

	var total_dur := maxi(1, finish - start)
	var is_active := (now >= start)
	var rem := maxi(0, finish - now) if is_active else total_dur
	var pct := clampf(float(total_dur - rem) / float(total_dur) * 100.0, 0.0, 100.0) if is_active else 0.0

	if is_active:
		active_build_icon_lbl.text = "🔨 İnşaat Sürüyor: Seviye %d" % tgt
		active_build_time_lbl.text = "Kalan: %s" % _fmt_duration(rem)
		active_build_time_lbl.add_theme_color_override("font_color", Color(0.42, 0.90, 1.0))
	else:
		active_build_icon_lbl.text = "⏳ Sırada Bekliyor: Seviye %d" % tgt
		active_build_time_lbl.text = "Süre: %s (Sırada)" % _fmt_duration(rem)
		active_build_time_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.40))

	active_build_progress.value = pct

	var item_id: int = int(active_item.get("id", -1))
	if active_build_speedup_btn != null:
		_apply_speedup_btn_style(active_build_speedup_btn, "build")
		var old_sp_id = active_build_speedup_btn.get_meta("item_id", -1)
		if old_sp_id != item_id:
			active_build_speedup_btn.set_meta("item_id", item_id)
			for conn in active_build_speedup_btn.pressed.get_connections():
				active_build_speedup_btn.pressed.disconnect(conn["callable"])
			active_build_speedup_btn.pressed.connect(_open_speedup.bind("build", item_id, active_build_icon_lbl.text))

	var old_id = active_build_cancel_btn.get_meta("item_id", -1)
	if old_id != item_id:
		active_build_cancel_btn.set_meta("item_id", item_id)
		for conn in active_build_cancel_btn.pressed.get_connections():
			active_build_cancel_btn.pressed.disconnect(conn["callable"])
		active_build_cancel_btn.pressed.connect(_on_active_cancel_pressed.bind(item_id))


func _on_active_cancel_pressed(item_id: int) -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null or not gs.has_active_village():
		return
	var v: Dictionary = gs.get_active_village()
	var state: Dictionary = gs.to_dict()
	var res := EconomyAPI.cancel_build(v, item_id, state)
	if bool(res.get("ok", false)):
		gs.from_dict(state)
		_village = gs.get_active_village()
		var sm = Engine.get_main_loop().root.get_node_or_null("SaveManager") if Engine.get_main_loop() is SceneTree else null
		if sm != null:
			if sm.has_method("request_save_game"):
				sm.call("request_save_game")
			else:
				sm.save_game()
		var bus = Engine.get_main_loop().root.get_node_or_null("EventBus") if Engine.get_main_loop() is SceneTree else null
		if bus != null:
			_in_action_emit = true
			if bus.has_signal("resources_changed"):
				bus.resources_changed.emit(gs.active_village_id)
			if bus.has_signal("state_changed"):
				bus.state_changed.emit()
			_in_action_emit = false
	refresh()


func _on_upgrade_pressed() -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null or not gs.has_active_village():
		return

	var vid: int = gs.active_village_id
	var state: Dictionary = gs.to_dict()

	var st_village: Dictionary = {}
	for sv in state.get("villages", []):
		if int(sv.get("id", -1)) == vid:
			st_village = sv
			break
	if st_village.is_empty():
		st_village = _village

	var res := EconomyAPI.start_build(st_village, _current_key, state)
	if bool(res.get("ok", false)):
		gs.from_dict(state)
		_village = gs.get_active_village()

		var sm = Engine.get_main_loop().root.get_node_or_null("SaveManager") if Engine.get_main_loop() is SceneTree else null
		if sm != null:
			if sm.has_method("request_save_game"):
				sm.call("request_save_game")
			else:
				sm.save_game()

		var bus = Engine.get_main_loop().root.get_node_or_null("EventBus") if Engine.get_main_loop() is SceneTree else null
		if bus != null:
			_in_action_emit = true
			if bus.has_signal("building_started"):
				bus.building_started.emit(vid, _current_key, int(res.get("target_level", 0)))
			if bus.has_signal("resources_changed"):
				bus.resources_changed.emit(vid)
			if bus.has_signal("state_changed"):
				bus.state_changed.emit()
			_in_action_emit = false

	refresh()


# =============================================================================
#  BİRİM ARAŞTIRMA SEKMESİ (RESEARCH TAB)
# =============================================================================

func _format_time_str(seconds: int) -> String:
	var h := seconds / 3600
	var m := (seconds % 3600) / 60
	var s := seconds % 60
	if h > 0:
		return "%d sa %d dk %d sn" % [h, m, s]
	elif m > 0:
		return "%d dk %d sn" % [m, s]
	else:
		return "%d sn" % s


func _populate_research_list() -> void:
	if research_list == null:
		return

	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	var state: Dictionary = (gs.as_live_dict() if gs.has_method("as_live_dict") else gs.to_dict()) if gs != null else {}
	var vid := int(_village.get("id", -1))
	var cur_barracks_lvl := int(_village.get("buildings", {}).get("barracks", 0))

	var active_research_unit := ""
	if gs != null:
		for item in gs.queues:
			if typeof(item) == TYPE_DICTIONARY and int(item.get("village_id", -1)) == vid and str(item.get("type", "")) == "research":
				active_research_unit = str(item.get("key", ""))
				break

	if research_list.get_child_count() != BARRACKS_UNITS.size():
		for child in research_list.get_children():
			research_list.remove_child(child)
			child.queue_free()

		var card_sb := StyleBoxFlat.new()
		card_sb.bg_color = Color(0.12, 0.11, 0.15, 0.98)
		card_sb.border_color = Color(0.48, 0.42, 0.34, 0.9)
		card_sb.set_border_width_all(2)
		card_sb.set_corner_radius_all(14)
		card_sb.content_margin_left = 16
		card_sb.content_margin_top = 14
		card_sb.content_margin_right = 16
		card_sb.content_margin_bottom = 14

		var b_sb_done := StyleBoxFlat.new()
		b_sb_done.bg_color = Color(0.12, 0.28, 0.16, 0.95)
		b_sb_done.border_color = Color(0.40, 0.85, 0.50, 0.9)
		b_sb_done.set_border_width_all(2)
		b_sb_done.set_corner_radius_all(12)

		var b_sb_prog := StyleBoxFlat.new()
		b_sb_prog.bg_color = Color(0.12, 0.22, 0.35, 0.95)
		b_sb_prog.border_color = Color(0.45, 0.78, 1.0, 0.9)
		b_sb_prog.set_border_width_all(2)
		b_sb_prog.set_corner_radius_all(12)

		var r_sb := StyleBoxFlat.new()
		r_sb.bg_color = Color(0.20, 0.58, 0.32, 1.0)
		r_sb.border_color = Color(0.60, 0.95, 0.70, 1.0)
		r_sb.set_border_width_all(2)
		r_sb.set_corner_radius_all(12)
		r_sb.shadow_size = 0
		r_sb.shadow_color = Color(0, 0, 0, 0.4)
		var r_pressed := r_sb.duplicate() as StyleBoxFlat
		r_pressed.bg_color = Color(0.12, 0.45, 0.22, 1.0)
		r_pressed.border_color = Color(1.0, 0.90, 0.50, 1.0)

		var d_sb := StyleBoxFlat.new()
		d_sb.bg_color = Color(0.18, 0.17, 0.20, 0.9)
		d_sb.border_color = Color(0.38, 0.35, 0.42, 0.75)
		d_sb.set_border_width_all(2)
		d_sb.set_corner_radius_all(12)

		for u_key in BARRACKS_UNITS:
			var u_name: String = GameDataScript.get_singleton().get_unit_name(u_key)
			var u_icon: String = UNIT_ICONS.get(u_key, "⚔️")
			var u_class: String = UNIT_CLASS_NAMES.get(u_key, "Piyade")
			var req_barracks := RulesEngineScript.research_requirement(u_key)
			var r_cost := RulesEngineScript.research_cost(u_key)

			var card := PanelContainer.new()
			card.name = "ResearchCard_" + u_key
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			card.mouse_filter = Control.MOUSE_FILTER_PASS
			card.add_theme_stylebox_override("panel", card_sb)

			var vbox := VBoxContainer.new()
			vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			vbox.mouse_filter = Control.MOUSE_FILTER_PASS
			vbox.add_theme_constant_override("separation", 8)
			card.add_child(vbox)

			var top_row := HBoxContainer.new()
			top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			top_row.mouse_filter = Control.MOUSE_FILTER_PASS
			top_row.add_theme_constant_override("separation", 10)

			var name_lbl := Label.new()
			name_lbl.text = "%s %s" % [u_icon, u_name]
			name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			name_lbl.add_theme_font_override("font", FontNunitoBold)
			name_lbl.add_theme_font_size_override("font_size", 28)
			name_lbl.add_theme_constant_override("outline_size", 0)
			name_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82))
			name_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
			top_row.add_child(name_lbl)

			var class_badge := Label.new()
			class_badge.text = "[%s]" % u_class
			class_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			class_badge.add_theme_font_override("font", FontNunitoSemiBold)
			class_badge.add_theme_font_size_override("font_size", 22)
			class_badge.add_theme_constant_override("outline_size", 0)
			class_badge.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
			class_badge.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0))
			top_row.add_child(class_badge)

			var spacer := Control.new()
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			top_row.add_child(spacer)

			var req_lbl := Label.new()
			req_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			req_lbl.add_theme_font_override("font", FontNunitoBold)
			req_lbl.add_theme_font_size_override("font_size", 24)
			req_lbl.add_theme_constant_override("outline_size", 0)
			req_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
			top_row.add_child(req_lbl)
			vbox.add_child(top_row)

			var combat := RulesEngineScript.unit_combat(u_key)
			var spd := RulesEngineScript.unit_speed(u_key)
			var carry := RulesEngineScript.unit_carry(u_key)
			var settlers := RulesEngineScript.unit_settlers(u_key)

			var stats_lbl := Label.new()
			stats_lbl.text = "⚔️ Saldırı: %d  |  🛡️ Sav: %d (Süv:%d / Okç:%d)  |  ⏱️ Hız: %.1f dk/alan  |  🎒 Taşıma: %d  |  👥 Nüfus: %d" % [
				combat.attack, combat.def_inf, combat.def_cav, combat.def_arch, spd, carry, settlers
			]
			stats_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			stats_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			stats_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stats_lbl.add_theme_font_override("font", FontNunitoSemiBold)
			stats_lbl.add_theme_font_size_override("font_size", 22)
			stats_lbl.add_theme_constant_override("outline_size", 0)
			stats_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
			stats_lbl.add_theme_color_override("font_color", Color(0.90, 0.88, 0.82))
			vbox.add_child(stats_lbl)

			var bottom_row := HBoxContainer.new()
			bottom_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bottom_row.mouse_filter = Control.MOUSE_FILTER_PASS
			bottom_row.add_theme_constant_override("separation", 12)

			var cost_hbox := HBoxContainer.new()
			cost_hbox.add_theme_constant_override("separation", 12)
			cost_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cost_hbox.mouse_filter = Control.MOUSE_FILTER_PASS

			var w_req := int(r_cost.get("wood", 0))
			var s_req := int(r_cost.get("stone", 0))
			var i_req := int(r_cost.get("iron", 0))
			var w_pill := _create_mini_resource_pill(IconWood, w_req, -1)
			var s_pill := _create_mini_resource_pill(IconStone, s_req, -1)
			var i_pill := _create_mini_resource_pill(IconIron, i_req, -1)
			cost_hbox.add_child(w_pill)
			cost_hbox.add_child(s_pill)
			cost_hbox.add_child(i_pill)

			var time_info := Label.new()
			time_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
			time_info.add_theme_font_override("font", FontNunitoBold)
			time_info.add_theme_font_size_override("font_size", 23)
			time_info.add_theme_constant_override("outline_size", 2)
			time_info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
			time_info.add_theme_color_override("font_color", Color(0.95, 0.90, 0.80))
			time_info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			cost_hbox.add_child(time_info)
			bottom_row.add_child(cost_hbox)

			var status_badge := Label.new()
			status_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			status_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			status_badge.custom_minimum_size = Vector2(185, 52)
			status_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			status_badge.add_theme_font_override("font", FontNunitoBold)
			status_badge.add_theme_font_size_override("font_size", 26)
			status_badge.add_theme_constant_override("outline_size", 3)
			status_badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
			bottom_row.add_child(status_badge)

			var res_btn := Button.new()
			res_btn.name = "ResearchBtn_" + u_key
			res_btn.custom_minimum_size = Vector2(185, 52)
			res_btn.mouse_filter = Control.MOUSE_FILTER_PASS
			res_btn.add_theme_font_override("font", FontNunitoBold)
			res_btn.add_theme_font_size_override("font_size", 26)
			res_btn.add_theme_constant_override("outline_size", 3)
			res_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
			res_btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
			res_btn.add_theme_constant_override("shadow_offset_y", 2)
			res_btn.pressed.connect(_on_start_research_pressed.bind(u_key))
			bottom_row.add_child(res_btn)

			vbox.add_child(bottom_row)
			research_list.add_child(card)

			var w_lbl := w_pill.get_node("AmtLabel") as Label
			var s_lbl := s_pill.get_node("AmtLabel") as Label
			var i_lbl := i_pill.get_node("AmtLabel") as Label
			var update_fn := func(b_lvl: int, act_unit: String, cur_state: Dictionary):
				var res_dict: Dictionary = _village.get("resources", {})
				var cur_w: int = int(res_dict.get("wood", 0))
				var cur_s: int = int(res_dict.get("stone", 0))
				var cur_i: int = int(res_dict.get("iron", 0))

				if b_lvl >= req_barracks:
					req_lbl.text = "✓ Kışla Sv. %d" % req_barracks
					req_lbl.add_theme_color_override("font_color", Color(0.45, 0.95, 0.56))
				else:
					req_lbl.text = "✗ Kışla Sv. %d Gerekli" % req_barracks
					req_lbl.add_theme_color_override("font_color", Color(1.0, 0.55, 0.48))

				w_lbl.add_theme_color_override("font_color", Color(1.0, 0.42, 0.38) if cur_w < w_req else Color(1.0, 1.0, 1.0))
				s_lbl.add_theme_color_override("font_color", Color(1.0, 0.42, 0.38) if cur_s < s_req else Color(1.0, 1.0, 1.0))
				i_lbl.add_theme_color_override("font_color", Color(1.0, 0.42, 0.38) if cur_i < i_req else Color(1.0, 1.0, 1.0))

				var r_secs := int(ceil(RulesEngineScript.research_seconds(u_key, b_lvl)))
				time_info.text = "⏱️ %s" % _format_time_str(r_secs)

				var is_res := RulesEngineScript.is_researched(_village, u_key)
				if is_res:
					status_badge.show()
					status_badge.text = "✓ Araştırıldı"
					status_badge.add_theme_color_override("font_color", Color(0.40, 0.95, 0.55))
					status_badge.add_theme_stylebox_override("normal", b_sb_done)
					res_btn.hide()
				elif act_unit == u_key:
					status_badge.show()
					status_badge.text = "⏳ Araştırılıyor..."
					status_badge.add_theme_color_override("font_color", Color(0.50, 0.90, 1.0))
					status_badge.add_theme_stylebox_override("normal", b_sb_prog)
					res_btn.hide()
				else:
					status_badge.hide()
					res_btn.show()
					var can_res := ArmyAPI.can_research(_village, u_key, cur_state)
					var reason := ArmyAPI.research_block_reason(_village, u_key, cur_state)
					if can_res:
						res_btn.disabled = false
						res_btn.text = "🔬 Araştır"
						res_btn.add_theme_stylebox_override("normal", r_sb)
						res_btn.add_theme_stylebox_override("hover", r_sb)
						res_btn.add_theme_stylebox_override("pressed", r_pressed)
						res_btn.add_theme_color_override("font_color", Color(1, 1, 1))
						res_btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
						res_btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.95, 0.75))
						res_btn.add_theme_color_override("font_focus_color", Color(1, 1, 1))
					else:
						res_btn.disabled = true
						res_btn.add_theme_stylebox_override("normal", d_sb)
						res_btn.add_theme_stylebox_override("disabled", d_sb)
						res_btn.add_theme_color_override("font_color", Color(0.70, 0.68, 0.65))
						if reason == "barracks_too_low":
							res_btn.text = "Kışla Sv. %d Gerekli" % req_barracks
						elif reason == "research_in_progress":
							res_btn.text = "Sırada İş Var"
						elif reason == "not_enough_resources":
							res_btn.text = "Yetersiz Kaynak"
						else:
							res_btn.text = "Araştırılamaz"

			card.set_meta("update_research_card", update_fn)

	var res_chk: Dictionary = _village.get("resources", {})
	var cw_r := int(res_chk.get("wood", 0))
	var cs_r := int(res_chk.get("stone", 0))
	var ci_r := int(res_chk.get("iron", 0))
	var res_sig_parts: Array[String] = ["%d:%d:%s:%d" % [vid, cur_barracks_lvl, active_research_unit, int(round(_get_speed_mult() * 100.0))]]
	for uk_sig in BARRACKS_UNITS:
		var is_r := 1 if RulesEngineScript.is_researched(_village, uk_sig) else 0
		var rc := RulesEngineScript.research_cost(uk_sig)
		var wf := 1 if cw_r >= int(rc.get("wood", 0)) else 0
		var sf := 1 if cs_r >= int(rc.get("stone", 0)) else 0
		var ifl := 1 if ci_r >= int(rc.get("iron", 0)) else 0
		res_sig_parts.append("%s=%d%d%d%d" % [uk_sig, is_r, wf, sf, ifl])
	var next_res_sig := "|".join(res_sig_parts)
	if next_res_sig == _last_research_sig and research_list.get_child_count() == BARRACKS_UNITS.size():
		return
	_last_research_sig = next_res_sig

	for child in research_list.get_children():
		if child.has_meta("update_research_card"):
			var cb = child.get_meta("update_research_card")
			if cb is Callable:
				(cb as Callable).call(cur_barracks_lvl, active_research_unit, state)


func _create_mini_resource_pill(icon_tex: Texture2D, req_amount: int, cur_amount: int) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 6)

	var icon_rect := TextureRect.new()
	icon_rect.texture = icon_tex
	icon_rect.custom_minimum_size = Vector2(28, 28)
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(icon_rect)

	var lbl := Label.new()
	lbl.name = "AmtLabel"
	lbl.text = str(req_amount)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_override("font", FontNunitoBold)
	lbl.add_theme_font_size_override("font_size", 23)
	lbl.add_theme_constant_override("outline_size", 0)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	if cur_amount >= 0 and cur_amount < req_amount:
		lbl.add_theme_color_override("font_color", Color(1.0, 0.42, 0.38))
	else:
		lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	box.add_child(lbl)

	return box


func _update_active_research_info() -> void:
	if active_research_box == null:
		return

	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null or not gs.has_active_village():
		active_research_box.hide()
		return

	var vid: int = gs.active_village_id
	var active_item: Dictionary = {}
	for item in gs.queues:
		if typeof(item) == TYPE_DICTIONARY and int(item.get("village_id", -1)) == vid and str(item.get("type", "")) == "research":
			active_item = item
			break

	if active_item.is_empty():
		active_research_box.hide()
		return

	active_research_box.show()
	var u_key := str(active_item.get("key", ""))
	var u_name: String = GameDataScript.get_singleton().get_unit_name(u_key)
	var start := int(active_item.get("start_unix", 0))
	var finish := int(active_item.get("finish_unix", 0))
	var now := _current_now()

	var total_dur := maxi(1, finish - start)
	var rem := maxi(0, finish - now)

	active_research_icon_lbl.text = "🔬 Araştırma Sürüyor: %s" % u_name
	active_research_time_lbl.text = "Kalan: %s" % _fmt_duration(rem)

	var pct := float(total_dur - rem) / float(total_dur) * 100.0
	active_research_progress.value = clampf(pct, 0.0, 100.0)

	var item_id: int = int(active_item.get("id", -1))
	if active_research_speedup_btn != null:
		_apply_speedup_btn_style(active_research_speedup_btn, "research")
		var old_sp_id = active_research_speedup_btn.get_meta("item_id", -1)
		if old_sp_id != item_id:
			active_research_speedup_btn.set_meta("item_id", item_id)
			for conn in active_research_speedup_btn.pressed.get_connections():
				active_research_speedup_btn.pressed.disconnect(conn["callable"])
			active_research_speedup_btn.pressed.connect(_open_speedup.bind("research", item_id, active_research_icon_lbl.text))

	var old_id = active_research_cancel_btn.get_meta("item_id", -1)
	if old_id != item_id:
		active_research_cancel_btn.set_meta("item_id", item_id)
		for conn in active_research_cancel_btn.pressed.get_connections():
			active_research_cancel_btn.pressed.disconnect(conn["callable"])
		active_research_cancel_btn.pressed.connect(_on_cancel_research_pressed.bind(item_id))


func _on_start_research_pressed(unit_key: String) -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null or not gs.has_active_village():
		return

	var vid: int = gs.active_village_id
	var state: Dictionary = gs.as_live_dict() if gs.has_method("as_live_dict") else gs.to_dict()
	var now := _current_now()

	var st_village: Dictionary = {}
	for sv in state.get("villages", []):
		if int(sv.get("id", -1)) == vid:
			st_village = sv
			break
	if st_village.is_empty():
		st_village = _village

	var res := ArmyAPI.start_research(st_village, unit_key, state, now)
	if bool(res.get("ok", false)):
		_last_research_sig = ""
		_last_train_sig = ""
		if gs.has_method("sync_from_live_dict"):
			gs.sync_from_live_dict(state)
		else:
			gs.from_dict(state)
		_village = gs.get_active_village()

		var sm = Engine.get_main_loop().root.get_node_or_null("SaveManager") if Engine.get_main_loop() is SceneTree else null
		if sm != null:
			if sm.has_method("request_save_game"):
				sm.call("request_save_game")
			else:
				sm.save_game()

		var bus = Engine.get_main_loop().root.get_node_or_null("EventBus") if Engine.get_main_loop() is SceneTree else null
		if bus != null:
			_in_action_emit = true
			if bus.has_signal("research_started"):
				bus.research_started.emit(vid, unit_key)
			if bus.has_signal("resources_changed"):
				bus.resources_changed.emit(vid)
			if bus.has_signal("state_changed"):
				bus.state_changed.emit()
			_in_action_emit = false

	refresh()


func _on_cancel_research_pressed(queue_id: int) -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null or not gs.has_active_village():
		return

	var vid: int = gs.active_village_id
	var state: Dictionary = gs.as_live_dict() if gs.has_method("as_live_dict") else gs.to_dict()

	var st_village: Dictionary = {}
	for sv in state.get("villages", []):
		if int(sv.get("id", -1)) == vid:
			st_village = sv
			break
	if st_village.is_empty():
		st_village = _village

	var ok := ArmyAPI.cancel_research(st_village, queue_id, state)
	if ok:
		_last_research_sig = ""
		if gs.has_method("sync_from_live_dict"):
			gs.sync_from_live_dict(state)
		else:
			gs.from_dict(state)
		_village = gs.get_active_village()

		var sm = Engine.get_main_loop().root.get_node_or_null("SaveManager") if Engine.get_main_loop() is SceneTree else null
		if sm != null:
			if sm.has_method("request_save_game"):
				sm.call("request_save_game")
			else:
				sm.save_game()

		var bus = Engine.get_main_loop().root.get_node_or_null("EventBus") if Engine.get_main_loop() is SceneTree else null
		if bus != null:
			_in_action_emit = true
			if bus.has_signal("resources_changed"):
				bus.resources_changed.emit(vid)
			if bus.has_signal("state_changed"):
				bus.state_changed.emit()
			_in_action_emit = false

	refresh()


# =============================================================================
#  BİRİM EĞİTİMİ SEKMESİ (TRAIN TAB)
# =============================================================================

func _train_state_ctx() -> Dictionary:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs != null and not gs.villages.is_empty():
		var vid := int(_village.get("id", -1))
		for gv in gs.villages:
			if typeof(gv) == TYPE_DICTIONARY and (is_same(_village, gv) or int((gv as Dictionary).get("id", -1)) == vid):
				_village = gv as Dictionary
				return {"queues": gs.queues}
	return {}


func _calculate_max_trainable(u_key: String) -> int:
	var st_ctx := _train_state_ctx()
	var res = _village.get("resources", {})
	var cur_w := int(res.get("wood", 0))
	var cur_s := int(res.get("stone", 0))
	var cur_i := int(res.get("iron", 0))

	var single_cost := RulesEngineScript.unit_cost(u_key, 1)
	var u_w := maxi(1, int(single_cost.get("wood", 0)))
	var u_s := maxi(1, int(single_cost.get("stone", 0)))
	var u_i := maxi(1, int(single_cost.get("iron", 0)))
	var u_settlers := maxi(1, RulesEngineScript.unit_settlers(u_key))

	var free_cit := ArmyAPI.army_capacity(_village, st_ctx)

	var limit_w := cur_w / u_w
	var limit_s := cur_s / u_s
	var limit_i := cur_i / u_i
	var limit_cit := free_cit / u_settlers

	return maxi(0, mini(mini(limit_w, limit_s), mini(limit_i, limit_cit)))


func _populate_train_list() -> void:
	if train_list == null:
		return

	var st_ctx := _train_state_ctx()
	var cur_barracks_lvl := int(_village.get("buildings", {}).get("barracks", 0))
	var free_cit := ArmyAPI.army_capacity(_village, st_ctx)
	var farm_lvl := VillageModel.building_level(_village, "farm")
	var max_pop := RulesEngineScript.max_population(farm_lvl)
	if str(_village.get("bonus_type", "")) == "citizen":
		max_pop = int(floor(float(max_pop) * 1.10 + 0.5))
	var bld_pop := VillageModel.population_used(_village)
	var army_pop := ArmyAPI.army_settlers(_village)
	var resv_pop := int(_village.get("settlers_reserved", 0))

	if citizen_label != null:
		citizen_label.text = "👥 Müsait Vatandaş: %d  |  Bina: %d • Ordu: %d • Eğitim: %d  (Kapasite: %d)" % [
			free_cit, bld_pop, army_pop, resv_pop, max_pop
		]

	var sig_parts: Array[String] = [str(cur_barracks_lvl)]
	for u_key in BARRACKS_UNITS:
		sig_parts.append("%s:%d" % [
			u_key,
			1 if RulesEngineScript.is_researched(_village, u_key) else 0
		])
	var train_sig := "|".join(sig_parts)
	var has_focused_train := (_focused_train_line != null and is_instance_valid(_focused_train_line) and _focused_train_line.has_focus())
	if (train_sig == _last_train_sig or has_focused_train) and train_list.get_child_count() == BARRACKS_UNITS.size():
		for child in train_list.get_children():
			if child.has_meta("update_calc"):
				var cb = child.get_meta("update_calc")
				if cb is Callable:
					(cb as Callable).call()
		return
	_last_train_sig = train_sig

	for child in train_list.get_children():
		train_list.remove_child(child)
		child.queue_free()

	for u_key in BARRACKS_UNITS:
		var u_name: String = GameDataScript.get_singleton().get_unit_name(u_key)
		var u_icon: String = UNIT_ICONS.get(u_key, "⚔️")
		var u_class: String = UNIT_CLASS_NAMES.get(u_key, "Piyade")
		var is_researched := RulesEngineScript.is_researched(_village, u_key)
		var req_barracks := RulesEngineScript.research_requirement(u_key)

		var card := PanelContainer.new()
		card.name = "TrainCard_" + u_key
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		var card_sb := StyleBoxFlat.new()
		card_sb.bg_color = Color(0.12, 0.11, 0.15, 0.98)
		card_sb.border_color = Color(0.48, 0.42, 0.34, 0.9)
		card_sb.set_border_width_all(2)
		card_sb.set_corner_radius_all(14)
		card_sb.content_margin_left = 16
		card_sb.content_margin_top = 14
		card_sb.content_margin_right = 16
		card_sb.content_margin_bottom = 14
		card.add_theme_stylebox_override("panel", card_sb)

		var vbox := VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.mouse_filter = Control.MOUSE_FILTER_PASS
		vbox.add_theme_constant_override("separation", 10)
		card.add_child(vbox)

		# Top row: Unit icon, name, class badge, existing troop count
		var top_row := HBoxContainer.new()
		top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_row.mouse_filter = Control.MOUSE_FILTER_PASS
		top_row.add_theme_constant_override("separation", 10)

		var name_lbl := Label.new()
		name_lbl.text = "%s %s" % [u_icon, u_name]
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_lbl.add_theme_font_override("font", FontNunitoBold)
		name_lbl.add_theme_font_size_override("font_size", 30)
		name_lbl.add_theme_constant_override("outline_size", 0)
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82))
		name_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		top_row.add_child(name_lbl)

		var class_badge := Label.new()
		class_badge.text = "[%s]" % u_class
		class_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		class_badge.add_theme_font_override("font", FontNunitoSemiBold)
		class_badge.add_theme_font_size_override("font_size", 24)
		class_badge.add_theme_constant_override("outline_size", 0)
		class_badge.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		class_badge.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0))
		top_row.add_child(class_badge)

		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top_row.add_child(spacer)

		var have_units := int(_village.get("units", {}).get(u_key, 0))
		var have_lbl := Label.new()
		have_lbl.text = "Mevcut: %d Adet" % have_units
		have_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		have_lbl.add_theme_font_override("font", FontNunitoBold)
		have_lbl.add_theme_font_size_override("font_size", 27)
		have_lbl.add_theme_constant_override("outline_size", 0)
		have_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
		have_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		top_row.add_child(have_lbl)

		vbox.add_child(top_row)

		if not is_researched:
			# Unresearched notice
			var lock_row := HBoxContainer.new()
			lock_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lock_row.mouse_filter = Control.MOUSE_FILTER_PASS
			lock_row.add_theme_constant_override("separation", 14)

			var lock_lbl := Label.new()
			lock_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lock_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lock_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lock_lbl.text = "🔒 Bu birim henüz araştırılmadı. (Gereken: Kışla Seviye %d)" % req_barracks
			lock_lbl.add_theme_font_override("font", FontNunitoSemiBold)
			lock_lbl.add_theme_font_size_override("font_size", 25)
			lock_lbl.add_theme_constant_override("outline_size", 0)
			lock_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
			lock_lbl.add_theme_color_override("font_color", Color(0.95, 0.65, 0.50))
			lock_row.add_child(lock_lbl)

			var goto_res_btn := Button.new()
			goto_res_btn.name = "GotoResearchBtn_" + u_key
			goto_res_btn.text = "Birim Araştır ➔"
			goto_res_btn.mouse_filter = Control.MOUSE_FILTER_PASS
			goto_res_btn.custom_minimum_size = Vector2(185, 52)
			goto_res_btn.add_theme_font_override("font", FontNunitoBold)
			goto_res_btn.add_theme_font_size_override("font_size", 26)
			goto_res_btn.add_theme_constant_override("outline_size", 3)
			goto_res_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
			goto_res_btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
			goto_res_btn.add_theme_constant_override("shadow_offset_y", 2)
			goto_res_btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
			goto_res_btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
			goto_res_btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.95, 0.75))
			goto_res_btn.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 1.0))

			var g_sb := StyleBoxFlat.new()
			g_sb.bg_color = Color(0.20, 0.38, 0.62, 0.95)
			g_sb.border_color = Color(0.65, 0.85, 1.0, 0.95)
			g_sb.set_border_width_all(2)
			g_sb.set_corner_radius_all(12)
			g_sb.shadow_size = 0
			g_sb.shadow_color = Color(0, 0, 0, 0.4)
			var g_pressed := g_sb.duplicate() as StyleBoxFlat
			g_pressed.bg_color = Color(0.12, 0.28, 0.50, 1.0)
			g_pressed.border_color = Color(1.0, 0.92, 0.60, 1.0)
			goto_res_btn.add_theme_stylebox_override("normal", g_sb)
			goto_res_btn.add_theme_stylebox_override("hover", g_sb)
			goto_res_btn.add_theme_stylebox_override("pressed", g_pressed)
			goto_res_btn.pressed.connect(_on_tab_research_pressed)
			lock_row.add_child(goto_res_btn)

			vbox.add_child(lock_row)
			var locked_update := func():
				have_lbl.text = "Mevcut: %d Adet" % int(_village.get("units", {}).get(u_key, 0))
			card.set_meta("update_calc", locked_update)
		else:
			# Combat stats line
			var combat := RulesEngineScript.unit_combat(u_key)
			var spd := RulesEngineScript.unit_speed(u_key)
			var carry := RulesEngineScript.unit_carry(u_key)

			var stats_lbl := Label.new()
			stats_lbl.text = "Saldırı: %d | Savunma (Piy:%d / Süv:%d / Okç:%d) | Hız: %.1f dk | Taşıma: %d" % [
				combat.attack, combat.def_inf, combat.def_cav, combat.def_arch, spd, carry
			]
			stats_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			stats_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			stats_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stats_lbl.add_theme_font_override("font", FontNunitoBold)
			stats_lbl.add_theme_font_size_override("font_size", 23)
			stats_lbl.add_theme_constant_override("outline_size", 2)
			stats_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
			stats_lbl.add_theme_color_override("font_color", Color(0.90, 0.88, 0.82))
			vbox.add_child(stats_lbl)

			# Single cost line with sharp icons and numbers
			var single_cost := RulesEngineScript.unit_cost(u_key, 1)
			var single_sec := int(ceil(RulesEngineScript.training_seconds(u_key, 1, cur_barracks_lvl)))
			var single_settler := RulesEngineScript.unit_settlers(u_key)

			var cost_row := HBoxContainer.new()
			cost_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cost_row.mouse_filter = Control.MOUSE_FILTER_PASS
			cost_row.add_theme_constant_override("separation", 12)

			var cost_title := Label.new()
			cost_title.text = "Birim Başı:"
			cost_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cost_title.add_theme_font_override("font", FontNunitoBold)
			cost_title.add_theme_font_size_override("font_size", 24)
			cost_title.add_theme_constant_override("outline_size", 3)
			cost_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
			cost_title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.80))
			cost_row.add_child(cost_title)

			var w_pill := _create_mini_resource_pill(IconWood, int(single_cost.get("wood", 0)), -1)
			var s_pill := _create_mini_resource_pill(IconStone, int(single_cost.get("stone", 0)), -1)
			var i_pill := _create_mini_resource_pill(IconIron, int(single_cost.get("iron", 0)), -1)
			var c_pill := _create_mini_resource_pill(IconCitizens, single_settler, -1)
			cost_row.add_child(w_pill)
			cost_row.add_child(s_pill)
			cost_row.add_child(i_pill)
			cost_row.add_child(c_pill)

			var time_info := Label.new()
			time_info.text = "⏱️ %s" % _format_time_str(single_sec)
			time_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
			time_info.add_theme_font_override("font", FontNunitoBold)
			time_info.add_theme_font_size_override("font_size", 24)
			time_info.add_theme_constant_override("outline_size", 2)
			time_info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
			time_info.add_theme_color_override("font_color", Color(0.92, 0.88, 0.80))
			time_info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			cost_row.add_child(time_info)

			vbox.add_child(cost_row)

			# Training input controls
			var input_row := HBoxContainer.new()
			input_row.name = "TrainInputRow_" + u_key
			input_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			input_row.mouse_filter = Control.MOUSE_FILTER_PASS
			input_row.add_theme_constant_override("separation", 8)

			# Quick buttons (+1, +5, +10, Maks)
			var btn_p1 := _create_quick_button("+1")
			btn_p1.name = "BtnPlus1_" + u_key
			var btn_p5 := _create_quick_button("+5")
			btn_p5.name = "BtnPlus5_" + u_key
			var btn_p10 := _create_quick_button("+10")
			btn_p10.name = "BtnPlus10_" + u_key
			var btn_max := _create_quick_button("Maks")
			btn_max.name = "BtnMax_" + u_key

			input_row.add_child(btn_p1)
			input_row.add_child(btn_p5)
			input_row.add_child(btn_p10)
			input_row.add_child(btn_max)

			# Visible pure LineEdit for mobile-safe numeric entry (keeps empty text "" for 0 so iOS keyboard starts clean)
			var qty_edit := LineEdit.new()
			qty_edit.name = "QtyEdit_" + u_key
			var init_cnt := int(_train_counts.get(u_key, 0))
			qty_edit.text = str(init_cnt) if init_cnt > 0 else ""
			qty_edit.placeholder_text = "0"
			qty_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
			qty_edit.select_all_on_focus = true
			qty_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
			qty_edit.custom_minimum_size = Vector2(126, 54)
			qty_edit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			qty_edit.mouse_filter = Control.MOUSE_FILTER_STOP
			qty_edit.add_theme_font_override("font", FontNunitoBold)
			qty_edit.add_theme_font_size_override("font_size", 28)
			qty_edit.add_theme_constant_override("outline_size", 2)
			qty_edit.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
			qty_edit.add_theme_color_override("font_color", Color(1.0, 0.97, 0.88))
			qty_edit.add_theme_color_override("font_placeholder_color", Color(0.88, 0.85, 0.78, 0.92))
			var qe_sb := StyleBoxFlat.new()
			qe_sb.bg_color = Color(0.06, 0.07, 0.12, 0.98)
			qe_sb.border_color = Color(0.78, 0.65, 0.32, 0.92)
			qe_sb.set_border_width_all(2)
			qe_sb.set_corner_radius_all(10)
			qe_sb.content_margin_left = 8
			qe_sb.content_margin_right = 8
			var qe_foc := qe_sb.duplicate() as StyleBoxFlat
			qe_foc.bg_color = Color(0.08, 0.10, 0.18, 1.0)
			qe_foc.border_color = Color(1.0, 0.86, 0.36, 1.0)
			qe_foc.set_border_width_all(3)
			qty_edit.add_theme_stylebox_override("normal", qe_sb)
			qty_edit.add_theme_stylebox_override("focus", qe_foc)
			_ensure_kb_preview_bar()
			if _kb_preview_bar != null:
				qty_edit.set_meta("keep_focus_controls", [_kb_preview_bar])
			input_row.add_child(qty_edit)

			# Hidden backing SpinBox kept in sync for quick +/- buttons and automated tests
			var spin := SpinBox.new()
			spin.name = "Spin_" + u_key
			spin.visible = false
			spin.min_value = 0
			spin.max_value = 99999
			spin.step = 1
			spin.value = int(_train_counts.get(u_key, 0))
			spin.custom_minimum_size = Vector2(0, 0)
			input_row.add_child(spin)

			var s_line := qty_edit
			var gc_sp: Node = Engine.get_main_loop().root.get_node_or_null("GameConfig") if Engine.get_main_loop() is SceneTree else null
			if gc_sp != null and gc_sp.has_method("bind_keyboard_dismiss"):
				gc_sp.call("bind_keyboard_dismiss", qty_edit, Callable(), true)

			var train_btn := Button.new()
			train_btn.name = "TrainBtn_" + u_key
			train_btn.text = "⚔️ Eğit"
			train_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			train_btn.custom_minimum_size = Vector2(150, 54)
			train_btn.mouse_filter = Control.MOUSE_FILTER_PASS
			train_btn.add_theme_font_override("font", FontNunitoBold)
			train_btn.add_theme_font_size_override("font_size", 26)
			train_btn.add_theme_constant_override("outline_size", 3)
			train_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
			train_btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
			train_btn.add_theme_constant_override("shadow_offset_y", 2)

			var t_sb := StyleBoxFlat.new()
			t_sb.bg_color = Color(0.20, 0.58, 0.32, 1.0)
			t_sb.border_color = Color(0.60, 0.95, 0.70, 1.0)
			t_sb.set_border_width_all(2)
			t_sb.set_corner_radius_all(12)
			t_sb.shadow_size = 0
			t_sb.shadow_color = Color(0, 0, 0, 0.4)
			var t_pressed := t_sb.duplicate() as StyleBoxFlat
			t_pressed.bg_color = Color(0.12, 0.45, 0.22, 1.0)
			t_pressed.border_color = Color(1.0, 0.90, 0.50, 1.0)
			train_btn.add_theme_stylebox_override("normal", t_sb)
			train_btn.add_theme_stylebox_override("hover", t_sb)
			train_btn.add_theme_stylebox_override("pressed", t_pressed)
			train_btn.add_theme_color_override("font_color", Color(1, 1, 1))
			train_btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
			train_btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.95, 0.75))
			train_btn.add_theme_color_override("font_focus_color", Color(1, 1, 1))

			var t_dis := StyleBoxFlat.new()
			t_dis.bg_color = Color(0.18, 0.17, 0.20, 0.9)
			t_dis.border_color = Color(0.35, 0.32, 0.38, 0.7)
			t_dis.set_border_width_all(2)
			t_dis.set_corner_radius_all(12)
			train_btn.add_theme_stylebox_override("disabled", t_dis)

			input_row.add_child(train_btn)
			vbox.add_child(input_row)

			# Calculation summary line
			var calc_summary := Label.new()
			calc_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			calc_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			calc_summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
			calc_summary.add_theme_font_override("font", FontNunitoBold)
			calc_summary.add_theme_font_size_override("font_size", 24)
			calc_summary.add_theme_constant_override("outline_size", 3)
			calc_summary.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
			calc_summary.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
			calc_summary.add_theme_constant_override("shadow_offset_y", 2)
			vbox.add_child(calc_summary)

			# Dynamic update closure (in-place updates, zero card rebuilds)
			var update_calc = func():
				have_lbl.text = "Mevcut: %d Adet" % int(_village.get("units", {}).get(u_key, 0))
				var c := int(spin.value)
				if s_line != null and is_instance_valid(s_line) and s_line.has_focus():
					var fdigits := _extract_train_digits(s_line.text.strip_edges())
					c = clampi(fdigits.to_int(), 0, 99999) if not fdigits.is_empty() else 0
				_train_counts[u_key] = c
				var max_train := _calculate_max_trainable(u_key)
				var tot_cost := RulesEngineScript.unit_cost(u_key, c)
				var tot_sec := int(ceil(RulesEngineScript.training_seconds(u_key, c, cur_barracks_lvl)))
				var tot_cit := c * single_settler

				if c == 0:
					calc_summary.text = "Eğitilecek miktarı seçin. (Maksimum üretilebilir: %d Adet)" % max_train
					calc_summary.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
					train_btn.disabled = true
					train_btn.text = "⚔️ Eğit"
				else:
					var can_t := (c <= max_train and c > 0)
					calc_summary.text = "Toplam (%d Adet): %d Odun, %d Taş, %d Demir | %d Nüfus | ⏱️ %s" % [
						c, int(tot_cost.get("wood", 0)), int(tot_cost.get("stone", 0)), int(tot_cost.get("iron", 0)),
						tot_cit, _format_time_str(tot_sec)
					]
					if can_t:
						calc_summary.add_theme_color_override("font_color", Color(0.45, 0.98, 0.58))
						train_btn.disabled = false
						train_btn.text = "⚔️ Eğit (%d Adet)" % c
					else:
						calc_summary.add_theme_color_override("font_color", Color(1.0, 0.45, 0.42))
						train_btn.disabled = true
						var avail_cit := ArmyAPI.army_capacity(_village, _train_state_ctx())
						if tot_cit > avail_cit:
							train_btn.text = "Yetersiz Nüfus (%d/%d)" % [avail_cit, tot_cit]
						else:
							train_btn.text = "Yetersiz Hammadde"

			update_calc.call()
			card.set_meta("update_calc", update_calc)

			if s_line != null:
				s_line.focus_entered.connect(func():
					var gc_f: Node = Engine.get_main_loop().root.get_node_or_null("GameConfig") if Engine.get_main_loop() is SceneTree else null
					if gc_f != null and gc_f.has_method("mark_focus_guard"):
						gc_f.call("mark_focus_guard", s_line, 500)
					_kb_was_open_on_mobile = false
					if s_line.text.strip_edges() == "0":
						s_line.text = ""
					elif not s_line.text.is_empty():
						s_line.call_deferred("select_all")
					_focused_train_unit = u_key
					_focused_train_spin = spin
					_focused_train_line = s_line
					_kb_scroll_done_for = ""
					var sc_pre := get_node_or_null("VBox/TrainSection/TrainScroll") as ScrollContainer
					if sc_pre != null and _pre_kb_scroll_y < 0:
						_pre_kb_scroll_y = sc_pre.scroll_vertical
					_post_kb_restore_scroll_y = -1
					_post_kb_restore_unit = ""
					if active_train_box != null:
						active_train_box.hide()
					_update_kb_preview(s_line.text)
					_update_keyboard_lift()
				)
				s_line.text_changed.connect(func(new_txt: String):
					var digits := _extract_train_digits(new_txt.strip_edges())
					var parsed := clampi(digits.to_int(), 0, 99999) if not digits.is_empty() else 0
					_train_counts[u_key] = parsed
					spin.set_value_no_signal(float(parsed))
					update_calc.call()
					if _focused_train_unit == u_key:
						_update_kb_preview(digits)
				)
				s_line.text_submitted.connect(func(sub_txt: String):
					if _focused_train_unit == u_key:
						_commit_focused_train_input(sub_txt, true)
					else:
						var digits := _extract_train_digits(sub_txt.strip_edges())
						var parsed := clampi(digits.to_int(), 0, 99999) if not digits.is_empty() else 0
						_train_counts[u_key] = parsed
						spin.value = float(parsed)
						s_line.text = str(parsed) if parsed > 0 else ""
						update_calc.call()
				)
				s_line.focus_exited.connect(func():
					if _focused_train_line == s_line:
						_commit_focused_train_input(s_line.text, true)
					else:
						var digits := _extract_train_digits(s_line.text.strip_edges())
						var parsed := clampi(digits.to_int(), 0, 99999) if not digits.is_empty() else 0
						_train_counts[u_key] = parsed
						spin.value = float(parsed)
						s_line.text = str(parsed) if parsed > 0 else ""
						update_calc.call()
				)

			spin.value_changed.connect(func(v: float):
				if s_line != null and is_instance_valid(s_line) and not s_line.has_focus():
					s_line.text = str(int(v)) if int(v) > 0 else ""
				update_calc.call()
				if _focused_train_unit == u_key:
					if _focused_train_line != null and is_instance_valid(_focused_train_line) and _focused_train_line.has_focus():
						var fd := _extract_train_digits(_focused_train_line.text.strip_edges())
						var cur_i := fd.to_int() if not fd.is_empty() else 0
						if cur_i != int(v):
							return
					_update_kb_preview(str(int(v)))
			)
			btn_p1.pressed.connect(func(): spin.value += 1)
			btn_p5.pressed.connect(func(): spin.value += 5)
			btn_p10.pressed.connect(func(): spin.value += 10)
			btn_max.pressed.connect(func(): spin.value = _calculate_max_trainable(u_key))

			train_btn.pressed.connect(func():
				if _focused_train_unit == u_key and _focused_train_line != null and is_instance_valid(_focused_train_line):
					_commit_focused_train_input(_focused_train_line.text, true)
				elif s_line != null and is_instance_valid(s_line):
					var fd := _extract_train_digits(s_line.text.strip_edges())
					if not fd.is_empty():
						spin.value = clampf(float(fd.to_int()), spin.min_value, spin.max_value)
				var gc_tr: Node = Engine.get_main_loop().root.get_node_or_null("GameConfig") if Engine.get_main_loop() is SceneTree else null
				if gc_tr != null and gc_tr.has_method("dismiss_keyboard_for"):
					gc_tr.call("dismiss_keyboard_for", s_line if s_line != null else train_btn)
				var c := int(spin.value)
				if c > 0:
					_on_start_train_pressed(u_key, c)
			)

		train_list.add_child(card)


func _create_quick_button(btn_text: String) -> Button:
	var btn := Button.new()
	btn.text = btn_text
	btn.custom_minimum_size = Vector2(68, 54)
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	btn.add_theme_font_override("font", FontNunitoBold)
	btn.add_theme_font_size_override("font_size", 26)
	btn.add_theme_constant_override("outline_size", 3)
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	btn.add_theme_constant_override("shadow_offset_y", 2)
	btn.add_theme_color_override("font_color", Color(1.0, 0.96, 0.88))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.88, 0.45))

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.20, 0.17, 0.24, 0.98)
	sb.border_color = Color(0.70, 0.60, 0.45, 0.95)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.shadow_size = 0
	sb.shadow_color = Color(0, 0, 0, 0.5)

	var sb_hover := StyleBoxFlat.new()
	sb_hover.bg_color = Color(0.28, 0.24, 0.32, 1.0)
	sb_hover.border_color = Color(1.0, 0.88, 0.55, 1.0)
	sb_hover.set_border_width_all(2)
	sb_hover.set_corner_radius_all(12)
	sb_hover.shadow_size = 0
	sb_hover.shadow_color = Color(0, 0, 0, 0.6)

	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_hover)

	return btn


func _ensure_train_queue_styles() -> void:
	if _cached_train_pb_bg == null:
		_cached_train_pb_bg = StyleBoxFlat.new()
		_cached_train_pb_bg.bg_color = Color(0.08, 0.07, 0.10, 0.95)
		_cached_train_pb_bg.border_color = Color(0.50, 0.42, 0.30, 0.8)
		_cached_train_pb_bg.set_border_width_all(1)
		_cached_train_pb_bg.set_corner_radius_all(6)
	if _cached_train_pb_fg == null:
		_cached_train_pb_fg = StyleBoxFlat.new()
		_cached_train_pb_fg.bg_color = Color(0.20, 0.80, 0.42, 1.0)
		_cached_train_pb_fg.set_corner_radius_all(5)
	if _cached_train_cancel_sb == null:
		_cached_train_cancel_sb = StyleBoxFlat.new()
		_cached_train_cancel_sb.bg_color = Color(0.68, 0.18, 0.15, 0.95)
		_cached_train_cancel_sb.border_color = Color(0.98, 0.55, 0.45, 0.95)
		_cached_train_cancel_sb.set_border_width_all(2)
		_cached_train_cancel_sb.set_corner_radius_all(10)
		_cached_train_cancel_hover = _cached_train_cancel_sb.duplicate() as StyleBoxFlat
		_cached_train_cancel_hover.bg_color = Color(0.84, 0.24, 0.20, 1.0)


func _update_active_train_info() -> void:
	if active_train_box == null or train_queue_list == null:
		return

	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null or not gs.has_active_village():
		active_train_box.hide()
		return

	var vid: int = gs.active_village_id
	var train_items: Array = []
	for item in gs.queues:
		if typeof(item) == TYPE_DICTIONARY and int(item.get("village_id", -1)) == vid and str(item.get("type", "")) == "train":
			train_items.append(item)

	if _current_tab == Tab.TRAIN and _focused_train_line != null and is_instance_valid(_focused_train_line) and _focused_train_line.has_focus():
		active_train_box.hide()
		return

	if train_items.is_empty():
		active_train_box.hide()
		return

	active_train_box.show()
	_ensure_train_queue_styles()
	var now := _current_now()

	while train_queue_list.get_child_count() < train_items.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		var name_lbl := Label.new()
		name_lbl.name = "NameLabel"
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.clip_text = true
		name_lbl.add_theme_font_override("font", FontNunitoBold)
		name_lbl.add_theme_font_size_override("font_size", 24)
		name_lbl.add_theme_constant_override("outline_size", 2)
		name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.50))
		row.add_child(name_lbl)

		var time_lbl := Label.new()
		time_lbl.name = "TimeLabel"
		time_lbl.add_theme_font_override("font", FontNunitoBold)
		time_lbl.add_theme_font_size_override("font_size", 24)
		time_lbl.add_theme_constant_override("outline_size", 2)
		time_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		time_lbl.add_theme_color_override("font_color", Color(0.42, 0.90, 1.0))
		row.add_child(time_lbl)

		var prog := ProgressBar.new()
		prog.name = "ProgressBar"
		prog.custom_minimum_size = Vector2(110, 26)
		prog.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		prog.show_percentage = false
		prog.add_theme_stylebox_override("background", _cached_train_pb_bg)
		prog.add_theme_stylebox_override("fill", _cached_train_pb_fg)
		row.add_child(prog)

		var s_btn := Button.new()
		s_btn.name = "TrainSpeedupButton"
		s_btn.text = "⚡ Hızlandır"
		s_btn.custom_minimum_size = Vector2(165, 48)
		s_btn.add_theme_font_override("font", FontNunitoBold)
		s_btn.add_theme_font_size_override("font_size", 21)
		s_btn.add_theme_constant_override("outline_size", 2)
		s_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		row.add_child(s_btn)

		var c_btn := Button.new()
		c_btn.name = "CancelButton"
		c_btn.text = "✕ İptal"
		c_btn.custom_minimum_size = Vector2(96, 48)
		c_btn.add_theme_font_override("font", FontNunitoBold)
		c_btn.add_theme_font_size_override("font_size", 22)
		c_btn.add_theme_constant_override("outline_size", 2)
		c_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		c_btn.add_theme_stylebox_override("normal", _cached_train_cancel_sb)
		c_btn.add_theme_stylebox_override("hover", _cached_train_cancel_hover)
		c_btn.add_theme_stylebox_override("pressed", _cached_train_cancel_hover)
		c_btn.add_theme_color_override("font_color", Color(1, 1, 1))
		row.add_child(c_btn)

		train_queue_list.add_child(row)

	while train_queue_list.get_child_count() > train_items.size():
		var ch = train_queue_list.get_child(train_queue_list.get_child_count() - 1)
		train_queue_list.remove_child(ch)
		ch.queue_free()

	for i in range(train_items.size()):
		var item: Dictionary = train_items[i]
		var row: HBoxContainer = train_queue_list.get_child(i)

		var u_key := str(item.get("key", ""))
		var count := int(item.get("count", 0))
		var u_name: String = GameDataScript.get_singleton().get_unit_name(u_key)
		var start := int(item.get("start_unix", 0))
		var finish := int(item.get("finish_unix", 0))
		var total_dur := maxi(1, finish - start)
		var rem := maxi(0, finish - now)

		var name_lbl: Label = row.get_node("NameLabel")
		var label_title := "⚔️ %d %s" % [count, u_name]
		name_lbl.text = label_title

		var time_lbl: Label = row.get_node("TimeLabel")
		time_lbl.text = _fmt_duration(rem)

		var prog: ProgressBar = row.get_node("ProgressBar")
		prog.value = clampf(float(total_dur - rem) / float(total_dur) * 100.0, 0.0, 100.0)

		var q_id: int = int(item.get("id", -1))
		var s_btn: Button = row.get_node_or_null("TrainSpeedupButton") as Button
		if s_btn != null:
			_apply_speedup_btn_style(s_btn, "train")
			var old_sp_key = str(s_btn.get_meta("sp_key", ""))
			var next_sp_key := "%d_%s" % [q_id, label_title]
			if old_sp_key != next_sp_key:
				s_btn.set_meta("sp_key", next_sp_key)
				for conn in s_btn.pressed.get_connections():
					s_btn.pressed.disconnect(conn["callable"])
				s_btn.pressed.connect(_open_speedup.bind("train", q_id, label_title))

		var c_btn: Button = row.get_node("CancelButton")
		var old_id = c_btn.get_meta("item_id", -1)
		if old_id != q_id:
			c_btn.set_meta("item_id", q_id)
			for conn in c_btn.pressed.get_connections():
				c_btn.pressed.disconnect(conn["callable"])
			c_btn.pressed.connect(_on_cancel_train_pressed.bind(q_id))


func _on_start_train_pressed(unit_key: String, count: int) -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null or not gs.has_active_village():
		return

	var vid: int = gs.active_village_id
	var state: Dictionary = gs.to_dict()
	var now := _current_now()

	var st_village: Dictionary = {}
	for sv in state.get("villages", []):
		if int(sv.get("id", -1)) == vid:
			st_village = sv
			break
	if st_village.is_empty():
		st_village = _village

	var res := ArmyAPI.start_training(st_village, unit_key, count, state, now)
	if bool(res.get("ok", false)):
		gs.from_dict(state)
		_village = gs.get_active_village()

		# Reset input count
		_train_counts[unit_key] = 0
		_last_train_sig = ""

		var sm = Engine.get_main_loop().root.get_node_or_null("SaveManager") if Engine.get_main_loop() is SceneTree else null
		if sm != null:
			if sm.has_method("request_save_game"):
				sm.call("request_save_game")
			else:
				sm.save_game()

		var bus = Engine.get_main_loop().root.get_node_or_null("EventBus") if Engine.get_main_loop() is SceneTree else null
		if bus != null:
			_in_action_emit = true
			if bus.has_signal("unit_training_started"):
				bus.unit_training_started.emit(vid, unit_key, count)
			if bus.has_signal("resources_changed"):
				bus.resources_changed.emit(vid)
			if bus.has_signal("state_changed"):
				bus.state_changed.emit()
			_in_action_emit = false

	refresh()


func _on_cancel_train_pressed(queue_id: int) -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null or not gs.has_active_village():
		return

	var vid: int = gs.active_village_id
	var state: Dictionary = gs.to_dict()

	var st_village: Dictionary = {}
	for sv in state.get("villages", []):
		if int(sv.get("id", -1)) == vid:
			st_village = sv
			break
	if st_village.is_empty():
		st_village = _village

	var ok := ArmyAPI.cancel_training(st_village, queue_id, state)
	if ok:
		_last_train_sig = ""
		gs.from_dict(state)
		_village = gs.get_active_village()

		var sm = Engine.get_main_loop().root.get_node_or_null("SaveManager") if Engine.get_main_loop() is SceneTree else null
		if sm != null:
			if sm.has_method("request_save_game"):
				sm.call("request_save_game")
			else:
				sm.save_game()

		var bus = Engine.get_main_loop().root.get_node_or_null("EventBus") if Engine.get_main_loop() is SceneTree else null
		if bus != null:
			_in_action_emit = true
			if bus.has_signal("resources_changed"):
				bus.resources_changed.emit(vid)
			if bus.has_signal("state_changed"):
				bus.state_changed.emit()
			_in_action_emit = false

	refresh()


# =============================================================================
#  KUYUMCU (ALTIN ZIRH) VE KÖŞK (KONT EĞİTİMİ) ÖZEL AKSİYONLARI
# =============================================================================

func _compute_special_box_sig(state: Dictionary, cur_w: int, cur_s: int, cur_i: int) -> String:
	var vid := int(_village.get("id", -1))
	if _current_key == "smith":
		var avail_armour := ArmyAPI.gold_armour(_village)
		var g_cost := ArmyAPI.gold_armour_cost(_village)
		var can_mint := (cur_w >= int(g_cost.get("wood", 12000)) and cur_s >= int(g_cost.get("stone", 10000)) and cur_i >= int(g_cost.get("iron", 8000)))
		return "smith:%d:%d:%d" % [vid, avail_armour, 1 if can_mint else 0]
	elif _current_key == "snob":
		var snob_count := int(_village.get("units", {}).get("snob", 0))
		var avail_armour := ArmyAPI.gold_armour(_village)
		var can_snob := ArmyAPI.can_train(_village, "snob", 1, state)
		var reason := ArmyAPI.training_block_reason(_village, "snob", 1, state)
		return "snob:%d:%d:%d:%d:%s" % [vid, snob_count, avail_armour, 1 if can_snob else 0, reason]
	elif _current_key == "barracks":
		var u_str := JSON.stringify(_village.get("units", {}))
		var sup_str := JSON.stringify(_village.get("support", []))
		var out_parts: Array[String] = []
		var v_arr: Array = state.get("villages", []) if typeof(state.get("villages")) == TYPE_ARRAY else []
		for v_raw in v_arr:
			if typeof(v_raw) == TYPE_DICTIONARY:
				var vd := v_raw as Dictionary
				var ovid := int(vd.get("id", -1))
				if ovid != vid and typeof(vd.get("support")) == TYPE_ARRAY:
					for s_it in (vd["support"] as Array):
						if typeof(s_it) == TYPE_DICTIONARY and int((s_it as Dictionary).get("from_village_id", -1)) == vid:
							out_parts.append("%d:%s" % [ovid, JSON.stringify((s_it as Dictionary).get("units", {}))])
		return "barracks:%d:%s:%s:%s" % [vid, u_str, sup_str, "|".join(out_parts)]
	return ""


func _update_special_building_actions(_cur_lvl: int) -> void:
	if _special_box == null or _special_vbox == null:
		return
	_special_box.show()
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	var state: Dictionary = (gs.as_live_dict() if gs.has_method("as_live_dict") else gs.to_dict()) if gs != null else {}
	var res_dict: Dictionary = _village.get("resources", {})
	var cur_w := int(res_dict.get("wood", 0))
	var cur_s := int(res_dict.get("stone", 0))
	var cur_i := int(res_dict.get("iron", 0))

	var spec_sig := _compute_special_box_sig(state, cur_w, cur_s, cur_i)
	if not spec_sig.is_empty() and spec_sig == _last_special_box_sig and _special_vbox.get_child_count() > 0:
		return
	_last_special_box_sig = spec_sig

	for ch in _special_vbox.get_children():
		_special_vbox.remove_child(ch)
		ch.queue_free()

	if _current_key == "smith":
		var avail_armour := ArmyAPI.gold_armour(_village)
		var g_cost := ArmyAPI.gold_armour_cost(_village)
		var req_w := int(g_cost.get("wood", 12000))
		var req_s := int(g_cost.get("stone", 10000))
		var req_i := int(g_cost.get("iron", 8000))

		var hdr := Label.new()
		hdr.text = "🛡️ Altın Zırh Darphanesi   •   Mevcut Stok: %d Set" % avail_armour
		hdr.add_theme_font_override("font", FontNunitoBold)
		hdr.add_theme_font_size_override("font_size", 28)
		hdr.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
		_special_vbox.add_child(hdr)

		var cost_lbl := Label.new()
		cost_lbl.text = "1 Set Maliyeti: %s Odun  •  %s Taş  •  %s Demir" % [
			_format_number(req_w), _format_number(req_s), _format_number(req_i)
		]
		cost_lbl.add_theme_font_override("font", FontNunitoSemiBold)
		cost_lbl.add_theme_font_size_override("font_size", 24)
		cost_lbl.add_theme_color_override("font_color", Color(0.92, 0.88, 0.80))
		_special_vbox.add_child(cost_lbl)

		var mint_btn := Button.new()
		mint_btn.name = "MintGoldArmourBtn"
		mint_btn.custom_minimum_size = Vector2(0, 62)
		mint_btn.add_theme_font_override("font", FontNunitoBold)
		mint_btn.add_theme_font_size_override("font_size", 28)
		var can_mint := (cur_w >= req_w and cur_s >= req_s and cur_i >= req_i)
		mint_btn.disabled = not can_mint
		mint_btn.text = "🛡️ Altın Zırh Üret (+1 Set)" if can_mint else "Yetersiz Hammadde (Altın Zırh)"
		var msb := StyleBoxFlat.new()
		msb.bg_color = Color(0.65, 0.48, 0.14, 1.0) if can_mint else Color(0.22, 0.20, 0.24, 0.9)
		msb.border_color = Color(1.0, 0.88, 0.42, 1.0) if can_mint else Color(0.45, 0.42, 0.48, 0.7)
		msb.set_border_width_all(2)
		msb.set_corner_radius_all(12)
		mint_btn.add_theme_stylebox_override("normal", msb)
		mint_btn.add_theme_stylebox_override("hover", msb)
		mint_btn.add_theme_stylebox_override("disabled", msb)
		mint_btn.add_theme_color_override("font_color", Color(1, 0.98, 0.90) if can_mint else Color(0.75, 0.72, 0.68))
		mint_btn.pressed.connect(_on_mint_gold_armour_pressed)
		_special_vbox.add_child(mint_btn)

	elif _current_key == "snob":
		var snob_count := int(_village.get("units", {}).get("snob", 0))
		var avail_armour := ArmyAPI.gold_armour(_village)
		var s_cost := RulesEngineScript.unit_cost("snob", 1)
		var req_w := int(s_cost.get("wood", 40000))
		var req_s := int(s_cost.get("stone", 50000))
		var req_i := int(s_cost.get("iron", 50000))

		var hdr := Label.new()
		hdr.text = "👑 Köşk — Kont Eğitimi   •   Mevcut Kont: %d  |  Altın Zırh: %d" % [snob_count, avail_armour]
		hdr.add_theme_font_override("font", FontNunitoBold)
		hdr.add_theme_font_size_override("font_size", 28)
		hdr.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
		_special_vbox.add_child(hdr)

		var cost_lbl := Label.new()
		cost_lbl.text = "Maliyet: %s Odun, %s Taş, %s Demir  •  100 Vatandaş  •  1 Altın Zırh" % [
			_format_number(req_w), _format_number(req_s), _format_number(req_i)
		]
		cost_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cost_lbl.add_theme_font_override("font", FontNunitoSemiBold)
		cost_lbl.add_theme_font_size_override("font_size", 24)
		cost_lbl.add_theme_color_override("font_color", Color(0.92, 0.88, 0.80))
		_special_vbox.add_child(cost_lbl)

		var can_snob := ArmyAPI.can_train(_village, "snob", 1, state)
		var reason := ArmyAPI.training_block_reason(_village, "snob", 1, state)
		var snob_btn := Button.new()
		snob_btn.name = "TrainSnobBtn"
		snob_btn.custom_minimum_size = Vector2(0, 62)
		snob_btn.add_theme_font_override("font", FontNunitoBold)
		snob_btn.add_theme_font_size_override("font_size", 28)
		snob_btn.disabled = not can_snob
		if can_snob:
			snob_btn.text = "👑 Kont Eğit (1 Adet)"
		elif reason == "no_gold_armour":
			snob_btn.text = "🛡️ Altın Zırh Gerekli (Kuyumcu'dan Üret)"
		elif reason == "not_enough_citizens":
			snob_btn.text = "👥 100 Boş Vatandaş Gerekli"
		else:
			snob_btn.text = "Yetersiz Hammadde / Önkoşul"

		var ssb := StyleBoxFlat.new()
		ssb.bg_color = Color(0.20, 0.54, 0.30, 1.0) if can_snob else Color(0.22, 0.20, 0.24, 0.9)
		ssb.border_color = Color(0.65, 0.95, 0.72, 1.0) if can_snob else Color(0.45, 0.42, 0.48, 0.7)
		ssb.set_border_width_all(2)
		ssb.set_corner_radius_all(12)
		snob_btn.add_theme_stylebox_override("normal", ssb)
		snob_btn.add_theme_stylebox_override("hover", ssb)
		snob_btn.add_theme_stylebox_override("disabled", ssb)
		snob_btn.add_theme_color_override("font_color", Color(1, 1, 1) if can_snob else Color(0.75, 0.72, 0.68))
		snob_btn.pressed.connect(_on_train_snob_pressed)
		_special_vbox.add_child(snob_btn)

	elif _current_key == "barracks":
		_build_barracks_garrison_and_support_view(state)


func _format_unit_breakdown_line(u_dict: Dictionary) -> String:
	var parts: Array[String] = []
	for u_key in ["farmer", "spear", "sword", "axe", "bow", "spy", "light", "heavy", "ram", "kata", "snob"]:
		var cnt := int(u_dict.get(u_key, 0))
		if cnt > 0:
			var u_name: String = GameDataScript.get_singleton().get_unit_name(u_key)
			var u_ico: String = str(UNIT_ICONS.get(u_key, "⚔️"))
			parts.append("%s %s %s" % [u_ico, _format_number(cnt), u_name])
	return "  •  ".join(parts)


func _build_barracks_garrison_and_support_view(state: Dictionary) -> void:
	var active_vid := int(_village.get("id", -1))
	var total_units: Dictionary = (_village.get("units", {}) as Dictionary).duplicate(true) if typeof(_village.get("units")) == TYPE_DICTIONARY else {}
	var support_list: Array = _village.get("support", []) if typeof(_village.get("support")) == TYPE_ARRAY else []

	# Köydeki gelen desteklerin toplamını hesapla -> köyün kendi askerlerini ayır
	var incoming_support_sum: Dictionary = {}
	for entry_raw in support_list:
		if typeof(entry_raw) != TYPE_DICTIONARY:
			continue
		var entry := entry_raw as Dictionary
		var s_u: Dictionary = entry.get("units", {}) if typeof(entry.get("units")) == TYPE_DICTIONARY else {}
		for uk in s_u.keys():
			var c := int(s_u.get(uk, 0))
			if c > 0:
				incoming_support_sum[str(uk)] = int(incoming_support_sum.get(str(uk), 0)) + c

	var own_units: Dictionary = {}
	for uk in ["farmer", "spear", "sword", "axe", "bow", "spy", "light", "heavy", "ram", "kata", "snob"]:
		var tot_c := int(total_units.get(uk, 0))
		var sup_c := int(incoming_support_sum.get(uk, 0))
		var own_c := maxi(0, tot_c - sup_c)
		if own_c > 0:
			own_units[uk] = own_c

	# Bu köyden başka köylere gönderilmiş ve orada konuşlanmış dış destekleri bul
	var outgoing_supports: Array[Dictionary] = []
	var villages_arr: Array = state.get("villages", []) if typeof(state.get("villages")) == TYPE_ARRAY else []
	var villages_by_id: Dictionary = {}
	for v_raw in villages_arr:
		if typeof(v_raw) == TYPE_DICTIONARY:
			var vd := v_raw as Dictionary
			var vid := int(vd.get("id", -1))
			villages_by_id[vid] = vd
			if vid != active_vid and typeof(vd.get("support")) == TYPE_ARRAY:
				var o_sups: Array = vd["support"]
				for s_idx in range(o_sups.size()):
					var s_it = o_sups[s_idx]
					if typeof(s_it) == TYPE_DICTIONARY and int((s_it as Dictionary).get("from_village_id", -1)) == active_vid:
						outgoing_supports.append({
							"target_village_id": vid,
							"target_village_name": str(vd.get("name", "Köy #%d" % vid)),
							"target_owner": str(vd.get("owner", "")),
							"support_index": s_idx,
							"units": (s_it as Dictionary).get("units", {}),
						})

	var hdr := Label.new()
	hdr.text = "🏰 KÖY GARNİZONU VE DESTEK BİRLİKLERİ"
	hdr.add_theme_font_override("font", FontNunitoBold)
	hdr.add_theme_font_size_override("font_size", 26)
	hdr.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	_special_vbox.add_child(hdr)

	var scroll := ScrollContainer.new()
	scroll.name = "BarracksGarrisonScroll"
	scroll.custom_minimum_size = Vector2(0, 176 if (not support_list.is_empty() or not outgoing_supports.is_empty()) else 118)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_special_vbox.add_child(scroll)

	var list_vb := VBoxContainer.new()
	list_vb.name = "GarrisonListVBox"
	list_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vb.add_theme_constant_override("separation", 8)
	scroll.add_child(list_vb)

	# 1. Köyün Kendi Mevcut Askerleri
	var own_line := _format_unit_breakdown_line(own_units)
	var own_lbl := Label.new()
	own_lbl.name = "OwnGarrisonUnitsLabel"
	own_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	own_lbl.add_theme_font_override("font", FontNunitoBold)
	own_lbl.add_theme_font_size_override("font_size", 22)
	own_lbl.add_theme_color_override("font_color", Color(0.95, 0.93, 0.86))
	own_lbl.text = "🏠 Köyün Kendi Birlikleri: " + (own_line if not own_line.is_empty() else "Mevcut asker yok")
	list_vb.add_child(own_lbl)

	# 2. Başka Köylerden Gelen Destek Birlikleri (Oyuncu Adı + Geri Gönder Butonu)
	for s_idx in range(support_list.size()):
		var s_raw = support_list[s_idx]
		if typeof(s_raw) != TYPE_DICTIONARY:
			continue
		var s_entry := s_raw as Dictionary
		var from_vid := int(s_entry.get("from_village_id", 0))
		var from_v: Dictionary = villages_by_id.get(from_vid, {})
		var sup_owner := str(s_entry.get("owner", from_v.get("owner", "Müttefik"))).strip_edges()
		if sup_owner.is_empty():
			sup_owner = str(from_v.get("owner", "Müttefik"))
		var sup_vname := str(s_entry.get("from_village_name", from_v.get("name", "Köy #%d" % from_vid))).strip_edges()
		var s_units: Dictionary = s_entry.get("units", {}) if typeof(s_entry.get("units")) == TYPE_DICTIONARY else {}
		var s_line := _format_unit_breakdown_line(s_units)
		if s_line.is_empty():
			continue

		var row := HBoxContainer.new()
		row.name = "IncomingSupportRow_%d" % s_idx
		row.add_theme_constant_override("separation", 10)
		var s_lbl := Label.new()
		s_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		s_lbl.add_theme_font_override("font", FontNunitoSemiBold)
		s_lbl.add_theme_font_size_override("font_size", 21)
		s_lbl.add_theme_color_override("font_color", Color(0.58, 0.90, 1.0))
		s_lbl.text = "🛡️ Destek — %s (%s): %s" % [sup_owner, sup_vname, s_line]
		row.add_child(s_lbl)

		var btn_back := Button.new()
		btn_back.name = "SendBackSupportBtn_%d" % s_idx
		btn_back.text = "↩ Geri Gönder"
		btn_back.custom_minimum_size = Vector2(168, 44)
		btn_back.add_theme_font_override("font", FontNunitoBold)
		btn_back.add_theme_font_size_override("font_size", 20)
		var bsb := StyleBoxFlat.new()
		bsb.bg_color = Color(0.48, 0.16, 0.16, 0.96)
		bsb.border_color = Color(0.95, 0.56, 0.44, 0.95)
		bsb.set_border_width_all(2)
		bsb.set_corner_radius_all(10)
		btn_back.add_theme_stylebox_override("normal", bsb)
		btn_back.add_theme_stylebox_override("hover", bsb)
		btn_back.add_theme_color_override("font_color", Color(1.0, 0.94, 0.90))
		btn_back.pressed.connect(_on_recall_or_return_support_pressed.bind(active_vid, from_vid, s_idx))
		row.add_child(btn_back)
		list_vb.add_child(row)

	# 3. Bu Köyden Başka Köylere Gönderilen Dış Destekler (Oyuncu Adı + Geri Çek Butonu)
	for out_idx in range(outgoing_supports.size()):
		var out_item: Dictionary = outgoing_supports[out_idx]
		var t_vid := int(out_item.get("target_village_id", 0))
		var t_vname := str(out_item.get("target_village_name", "Köy"))
		var t_owner := str(out_item.get("target_owner", "Oyuncu"))
		var s_idx2 := int(out_item.get("support_index", -1))
		var o_units: Dictionary = out_item.get("units", {}) if typeof(out_item.get("units")) == TYPE_DICTIONARY else {}
		var o_line := _format_unit_breakdown_line(o_units)
		if o_line.is_empty():
			continue

		var row_out := HBoxContainer.new()
		row_out.name = "OutgoingSupportRow_%d" % out_idx
		row_out.add_theme_constant_override("separation", 10)
		var o_lbl := Label.new()
		o_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		o_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		o_lbl.add_theme_font_override("font", FontNunitoSemiBold)
		o_lbl.add_theme_font_size_override("font_size", 21)
		o_lbl.add_theme_color_override("font_color", Color(0.98, 0.84, 0.52))
		o_lbl.text = "🚩 Dışarıdaki Desteğimiz → %s (%s): %s" % [t_owner, t_vname, o_line]
		row_out.add_child(o_lbl)

		var btn_recall := Button.new()
		btn_recall.name = "RecallSupportBtn_%d" % t_vid
		btn_recall.text = "↩ Geri Çek"
		btn_recall.custom_minimum_size = Vector2(154, 44)
		btn_recall.add_theme_font_override("font", FontNunitoBold)
		btn_recall.add_theme_font_size_override("font_size", 20)
		var rsb := StyleBoxFlat.new()
		rsb.bg_color = Color(0.18, 0.36, 0.56, 0.96)
		rsb.border_color = Color(0.58, 0.86, 1.0, 0.95)
		rsb.set_border_width_all(2)
		rsb.set_corner_radius_all(10)
		btn_recall.add_theme_stylebox_override("normal", rsb)
		btn_recall.add_theme_stylebox_override("hover", rsb)
		btn_recall.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
		btn_recall.pressed.connect(_on_recall_or_return_support_pressed.bind(t_vid, active_vid, s_idx2))
		row_out.add_child(btn_recall)
		list_vb.add_child(row_out)

	# 4. En Altta Toplam Askeri Birlik Bilgisi (Kendi + Gelen Tüm Destekler)
	var tot_panel := PanelContainer.new()
	tot_panel.name = "TotalGarrisonSummaryPanel"
	var t_sb := StyleBoxFlat.new()
	t_sb.bg_color = Color(0.10, 0.22, 0.14, 0.96)
	t_sb.border_color = Color(0.48, 0.88, 0.56, 0.95)
	t_sb.set_border_width_all(1)
	t_sb.set_corner_radius_all(10)
	t_sb.content_margin_left = 12
	t_sb.content_margin_right = 12
	t_sb.content_margin_top = 6
	t_sb.content_margin_bottom = 6
	tot_panel.add_theme_stylebox_override("panel", t_sb)
	var tot_line := _format_unit_breakdown_line(total_units)
	var tot_lbl := Label.new()
	tot_lbl.name = "TotalGarrisonUnitsLabel"
	tot_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tot_lbl.add_theme_font_override("font", FontNunitoBold)
	tot_lbl.add_theme_font_size_override("font_size", 22)
	tot_lbl.add_theme_color_override("font_color", Color(0.65, 1.0, 0.72))
	tot_lbl.text = "⚔️ Toplam Askeri Birlik (Köy + Destek): " + (tot_line if not tot_line.is_empty() else "0 Asker")
	tot_panel.add_child(tot_lbl)
	_special_vbox.add_child(tot_panel)


func _on_recall_or_return_support_pressed(target_vid: int, from_vid: int, sup_idx: int) -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null:
		return
	var state: Dictionary = gs.to_dict()
	var now := _current_now()
	var MovementScript := load("res://scripts/sim/actions/Movement.gd")
	if MovementScript == null:
		return
	var res: Dictionary = MovementScript.recall_support(state, target_vid, from_vid, now, sup_idx)
	if bool(res.get("ok", false)):
		_last_special_box_sig = ""
		gs.from_dict(state)
		_village = gs.get_active_village()
		var wm = Engine.get_main_loop().root.get_node_or_null("WorldManager") if Engine.get_main_loop() is SceneTree else null
		if wm != null and wm.has_method("notify_local_mutation"):
			wm.call("notify_local_mutation")
		if wm != null and wm.has_method("request_save_active_world"):
			wm.call("request_save_active_world", true)
		var sm = Engine.get_main_loop().root.get_node_or_null("SaveManager") if Engine.get_main_loop() is SceneTree else null
		if sm != null:
			if sm.has_method("request_save_game"):
				sm.call("request_save_game")
			elif sm.has_method("save_game"):
				sm.call("save_game")
		var bus = Engine.get_main_loop().root.get_node_or_null("EventBus") if Engine.get_main_loop() is SceneTree else null
		if bus != null and bus.has_signal("state_changed"):
			_in_action_emit = true
			bus.state_changed.emit()
			_in_action_emit = false
		refresh()


func _on_mint_gold_armour_pressed() -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null or not gs.has_active_village():
		return
	var vid: int = gs.active_village_id
	var state: Dictionary = gs.to_dict()
	var st_village: Dictionary = {}
	for sv in state.get("villages", []):
		if int(sv.get("id", -1)) == vid:
			st_village = sv
			break
	if st_village.is_empty():
		return
	if ArmyAPI.produce_gold_armour(st_village, 1):
		_last_special_box_sig = ""
		gs.from_dict(state)
		_village = gs.get_active_village()
		var sm = Engine.get_main_loop().root.get_node_or_null("SaveManager") if Engine.get_main_loop() is SceneTree else null
		if sm != null:
			if sm.has_method("request_save_game"):
				sm.call("request_save_game")
			else:
				sm.save_game()
		var bus = Engine.get_main_loop().root.get_node_or_null("EventBus") if Engine.get_main_loop() is SceneTree else null
		if bus != null:
			_in_action_emit = true
			if bus.has_signal("resources_changed"):
				bus.resources_changed.emit(vid)
			if bus.has_signal("state_changed"):
				bus.state_changed.emit()
			_in_action_emit = false
	refresh()


func _on_train_snob_pressed() -> void:
	_on_start_train_pressed("snob", 1)
