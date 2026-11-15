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
var _tab_act_sb: StyleBox = null
var _tab_inact_sb: StyleBox = null

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
@onready var active_research_cancel_btn: Button = $VBox/ResearchSection/ActiveResearchBox/HBox/CancelButton
@onready var research_list: VBoxContainer = $VBox/ResearchSection/ResearchScroll/ResearchList

# Train nodes
@onready var train_section: VBoxContainer = $VBox/TrainSection
@onready var active_train_box: PanelContainer = $VBox/TrainSection/ActiveTrainBox
@onready var train_queue_list: VBoxContainer = $VBox/TrainSection/ActiveTrainBox/VBox/QueueList
@onready var citizen_label: Label = $VBox/TrainSection/CitizenInfoBar/CitizenLabel
@onready var train_list: VBoxContainer = $VBox/TrainSection/TrainScroll/TrainList


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
		active_build_cancel_btn = $VBox/ActiveBuildBox/HBox/CancelButton

	if research_section == null and has_node("VBox/ResearchSection"):
		research_section = $VBox/ResearchSection
		active_research_box = $VBox/ResearchSection/ActiveResearchBox
		active_research_icon_lbl = $VBox/ResearchSection/ActiveResearchBox/HBox/IconLabel
		active_research_time_lbl = $VBox/ResearchSection/ActiveResearchBox/HBox/TimeLabel
		active_research_progress = $VBox/ResearchSection/ActiveResearchBox/HBox/ProgressBar
		active_research_cancel_btn = $VBox/ResearchSection/ActiveResearchBox/HBox/CancelButton
		research_list = $VBox/ResearchSection/ResearchScroll/ResearchList

	if train_section == null and has_node("VBox/TrainSection"):
		train_section = $VBox/TrainSection
		active_train_box = $VBox/TrainSection/ActiveTrainBox
		train_queue_list = $VBox/TrainSection/ActiveTrainBox/VBox/QueueList
		citizen_label = $VBox/TrainSection/CitizenInfoBar/CitizenLabel
		train_list = $VBox/TrainSection/TrainScroll/TrainList

	_ensure_description_and_production_nodes()


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
		desc_sb.shadow_size = 6
		_desc_box.add_theme_stylebox_override("panel", desc_sb)

		_desc_label = Label.new()
		_desc_label.name = "DescriptionLabel"
		_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_desc_label.add_theme_font_override("font", FontNunitoSemiBold)
		_desc_label.add_theme_font_size_override("font_size", 24)
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
		prod_sb.shadow_size = 6
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
		sp_sb.shadow_size = 8
		_special_box.add_theme_stylebox_override("panel", sp_sb)

		_special_vbox = VBoxContainer.new()
		_special_vbox.name = "SpecialActionVBox"
		_special_vbox.add_theme_constant_override("separation", 10)
		_special_box.add_child(_special_vbox)
		_special_box.hide()

		vbox.add_child(_special_box)
		vbox.move_child(_special_box, 4)


func _update_production_table(cur_lvl: int) -> void:
	if _prod_box == null or _prod_vbox == null:
		return

	if not (_current_key in ["wood", "stone", "iron", "storage"]):
		_prod_box.hide()
		return

	_prod_box.show()
	for child in _prod_vbox.get_children():
		_prod_vbox.remove_child(child)
		child.queue_free()

	if _current_key == "storage":
		_build_storage_table(cur_lvl)
	else:
		_build_mine_production_table(cur_lvl)


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
	col1_lbl.add_theme_font_size_override("font_size", 24)
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
	c1.add_theme_font_size_override("font_size", 24)
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
	cap_lbl.add_theme_font_size_override("font_size", 24)
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
	col1_lbl.add_theme_font_size_override("font_size", 26)
	col1_lbl.add_theme_color_override("font_color", Color(0.12, 0.08, 0.04))
	h_row.add_child(col1_lbl)

	var col2_lbl := Label.new()
	col2_lbl.text = "saatlik"
	col2_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col2_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col2_lbl.add_theme_font_override("font", FontNunitoBold)
	col2_lbl.add_theme_font_size_override("font_size", 26)
	col2_lbl.add_theme_color_override("font_color", Color(0.12, 0.08, 0.04))
	h_row.add_child(col2_lbl)

	var col3_lbl := Label.new()
	col3_lbl.text = "günlük"
	col3_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col3_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col3_lbl.add_theme_font_override("font", FontNunitoBold)
	col3_lbl.add_theme_font_size_override("font_size", 26)
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
	c1.add_theme_font_size_override("font_size", 24)
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
	hr_lbl.add_theme_font_size_override("font_size", 24)
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
	dl_lbl.add_theme_font_size_override("font_size", 24)
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

	# EventBus listeners for reactive UI
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


func _on_bus_research_completed(_vid: int, _ukey: String) -> void:
	if visible:
		refresh()


func _on_bus_unit_trained(_vid: int, _ukey: String, _count: int) -> void:
	if visible:
		refresh()


func _on_bus_resources_changed(_vid: int) -> void:
	if visible:
		refresh()


func _on_bus_state_changed() -> void:
	if visible:
		refresh()


func _process(_delta: float) -> void:
	if not visible:
		return
	if _current_tab == Tab.UPGRADE:
		_update_active_build_info()
	elif _current_tab == Tab.RESEARCH:
		_update_active_research_info()
	elif _current_tab == Tab.TRAIN:
		_update_active_train_info()


func _on_close_pressed() -> void:
	hide()
	closed.emit()


func _on_tab_upgrade_pressed() -> void:
	_current_tab = Tab.UPGRADE
	refresh()


func _on_tab_research_pressed() -> void:
	_current_tab = Tab.RESEARCH
	refresh()


func _on_tab_train_pressed() -> void:
	_current_tab = Tab.TRAIN
	refresh()


func switch_tab(tab_idx: int) -> void:
	_switch_tab(tab_idx)


func _switch_tab(tab_idx: int) -> void:
	match tab_idx:
		0, Tab.UPGRADE: _on_tab_upgrade_pressed()
		1, Tab.RESEARCH: _on_tab_research_pressed()
		2, Tab.TRAIN: _on_tab_train_pressed()


func show_building(village: Dictionary, key: String) -> void:
	_ensure_nodes()
	_village = village
	_current_key = key
	_current_tab = Tab.UPGRADE
	_last_research_sig = ""
	_last_train_sig = ""
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

	if _tab_act_sb == null or _tab_inact_sb == null:
		var act_sb := preload("res://ui/BuildingPanel.tscn").instantiate()
		_tab_act_sb = act_sb.get_node("VBox/TabBar/TabUpgradeBtn").get_theme_stylebox("normal")
		_tab_inact_sb = act_sb.get_node("VBox/TabBar/TabResearchBtn").get_theme_stylebox("normal")
		act_sb.queue_free()
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
			btn.add_theme_font_size_override("font_size", 28)
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

	var state: Dictionary = gs.to_dict() if gs != null else {}
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

	# Taş Ocağı, Oduncu Kampı, Maden Ocağı ve Depo için üretim / kapasite tablosu
	if _current_tab == Tab.UPGRADE and _current_key in ["wood", "stone", "iron", "storage"]:
		_update_production_table(cur_lvl)
	else:
		if _prod_box != null:
			_prod_box.hide()

	# Kuyumcu (Altın Zırh) ve Köşk (Kont Eğitimi) özel aksiyon kutusu
	if _current_tab == Tab.UPGRADE and _current_key in ["smith", "snob"] and cur_lvl >= 1:
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
		offset_top = -1150.0
		_populate_train_list()
		_update_active_train_info()


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

	var dur_secs: float = RulesEngineScript.build_seconds(_current_key, tgt_lvl)
	if active_in_queue:
		time_label.text = "Sıradaki İnşa Süresi: %d sn" % int(ceil(dur_secs))
	else:
		time_label.text = "İnşa Süresi: %d sn" % int(ceil(dur_secs))

	if extra_pct > 0:
		extra_cost_label.text = "⚠️ Kuyruk Ek Maliyeti: +%%%d" % extra_pct
		extra_cost_label.show()
	else:
		extra_cost_label.hide()

	# Requirement chain
	for child in req_container.get_children():
		req_container.remove_child(child)
		child.queue_free()

	var chain: Array = RulesEngineScript.requirement_chain(_village.get("buildings", {}), _current_key, tgt_lvl)
	var is_upgradable: bool = bool(details.get("ok", false))
	var has_tall_box: bool = is_res_bldg or (_special_box != null and _special_box.visible)

	if is_upgradable:
		req_section.hide()
		offset_top = -980.0 if has_tall_box else -680.0
		upgrade_btn.disabled = false
		upgrade_btn.text = ("Sıraya Ekle (Seviye %d)" if active_in_queue else "Yükselt (Seviye %d)") % tgt_lvl

		var upg_sb := StyleBoxFlat.new()
		upg_sb.bg_color = Color(0.18, 0.60, 0.30, 1.0)
		upg_sb.border_color = Color(0.55, 0.90, 0.62, 1.0)
		upg_sb.border_width_top = 2
		upg_sb.border_width_bottom = 5
		upg_sb.border_width_left = 2
		upg_sb.border_width_right = 2
		upg_sb.set_corner_radius_all(16)
		upg_sb.shadow_color = Color(0.04, 0.22, 0.08, 0.45)
		upg_sb.shadow_size = 8
		upg_sb.shadow_offset = Vector2(0, 4)
		upg_sb.content_margin_top = 16
		upg_sb.content_margin_bottom = 16

		var upg_hover := StyleBoxFlat.new()
		upg_hover.bg_color = Color(0.22, 0.70, 0.36, 1.0)
		upg_hover.border_color = Color(0.75, 1.0, 0.80, 1.0)
		upg_hover.border_width_top = 2
		upg_hover.border_width_bottom = 5
		upg_hover.border_width_left = 2
		upg_hover.border_width_right = 2
		upg_hover.set_corner_radius_all(16)
		upg_hover.shadow_color = Color(0.06, 0.32, 0.12, 0.55)
		upg_hover.shadow_size = 12
		upg_hover.shadow_offset = Vector2(0, 4)
		upg_hover.content_margin_top = 16
		upg_hover.content_margin_bottom = 16

		var upg_pressed := StyleBoxFlat.new()
		upg_pressed.bg_color = Color(0.12, 0.46, 0.22, 1.0)
		upg_pressed.border_color = Color(0.95, 0.85, 0.45, 1.0)
		upg_pressed.border_width_top = 4
		upg_pressed.border_width_bottom = 2
		upg_pressed.border_width_left = 2
		upg_pressed.border_width_right = 2
		upg_pressed.set_corner_radius_all(16)
		upg_pressed.content_margin_top = 16
		upg_pressed.content_margin_bottom = 16

		upgrade_btn.add_theme_stylebox_override("normal", upg_sb)
		upgrade_btn.add_theme_stylebox_override("hover", upg_hover)
		upgrade_btn.add_theme_stylebox_override("pressed", upg_pressed)
		upgrade_btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		upgrade_btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
		upgrade_btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.95, 0.70))
		upgrade_btn.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 1.0))
		upgrade_btn.add_theme_constant_override("outline_size", 3)
		upgrade_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		upgrade_btn.add_theme_color_override("font_shadow_color", Color(0.04, 0.20, 0.08, 0.9))
		upgrade_btn.add_theme_constant_override("shadow_offset_y", 2)
		upgrade_btn.add_theme_font_size_override("font_size", 30)
	else:
		upgrade_btn.disabled = true
		var dis_sb := StyleBoxFlat.new()
		dis_sb.bg_color = Color(0.20, 0.19, 0.23, 0.95)
		dis_sb.border_color = Color(0.40, 0.38, 0.44, 0.70)
		dis_sb.border_width_top = 1
		dis_sb.border_width_bottom = 4
		dis_sb.border_width_left = 1
		dis_sb.border_width_right = 1
		dis_sb.set_corner_radius_all(16)
		dis_sb.content_margin_top = 16
		dis_sb.content_margin_bottom = 16

		upgrade_btn.add_theme_stylebox_override("normal", dis_sb)
		upgrade_btn.add_theme_stylebox_override("disabled", dis_sb)
		upgrade_btn.add_theme_color_override("font_color", Color(0.85, 0.82, 0.78))
		upgrade_btn.add_theme_color_override("font_disabled_color", Color(0.85, 0.82, 0.78))
		upgrade_btn.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.6))
		upgrade_btn.add_theme_constant_override("shadow_offset_y", 1)
		upgrade_btn.add_theme_font_size_override("font_size", 30)

		var reason: String = str(details.get("reason", ""))
		if reason == "max_level":
			upgrade_btn.text = "Maksimum Seviyeye Ulaşıldı"
			req_section.hide()
			offset_top = -980.0 if has_tall_box else -680.0
		elif reason == "requirements" or reason == "locked":
			upgrade_btn.text = "Önkoşullar Karşılanmadı"
			req_section.show()
			offset_top = -1280.0 if has_tall_box else -1020.0
			_populate_chain_list(chain)
		elif reason == "resources":
			upgrade_btn.text = "Yetersiz Hammadde"
			if details.get("missing", []).size() > 0:
				req_section.show()
				offset_top = -1280.0 if has_tall_box else -1020.0
				_populate_chain_list(chain)
			else:
				req_section.hide()
				offset_top = -980.0 if has_tall_box else -680.0
		elif reason == "citizens":
			upgrade_btn.text = "Yetersiz Vatandaş (Değirmen Gerek)"
			req_section.hide()
			offset_top = -980.0 if has_tall_box else -680.0
		else:
			upgrade_btn.text = "Yükseltilemez"
			req_section.hide()
			offset_top = -980.0 if has_tall_box else -680.0


func _populate_chain_list(chain: Array) -> void:
	for node in chain:
		if typeof(node) != TYPE_DICTIONARY:
			continue
		var req_dict: Dictionary = node
		var req_key: String = str(req_dict.get("key", ""))
		if req_key == _current_key:
			continue

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
		lbl.add_theme_font_size_override("font_size", 23)
		lbl.add_theme_constant_override("outline_size", 0)
		lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		lbl.add_theme_color_override("font_color", Color(0.50, 0.92, 0.55, 1) if req_cur >= req_tgt else Color(0.98, 0.72, 0.56, 1))
		row.add_child(lbl)

		var goto_btn := Button.new()
		goto_btn.name = "GotoBtn_" + req_key
		goto_btn.text = "Binaya Git ➔"
		goto_btn.custom_minimum_size = Vector2(175, 52)
		goto_btn.add_theme_font_override("font", FontNunitoBold)
		goto_btn.add_theme_font_size_override("font_size", 22)
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
		btn_sb.shadow_size = 4
		btn_sb.shadow_color = Color(0, 0, 0, 0.6)
		goto_btn.add_theme_stylebox_override("normal", btn_sb)

		var btn_hover := StyleBoxFlat.new()
		btn_hover.bg_color = Color(0.24, 0.48, 0.84, 1.0)
		btn_hover.border_color = Color(1.0, 0.92, 0.60, 1.0)
		btn_hover.set_border_width_all(2)
		btn_hover.set_corner_radius_all(12)
		btn_hover.shadow_size = 6
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
		active_build_time_lbl.text = "Kalan: %02d:%02d" % [rem / 60, rem % 60]
		active_build_time_lbl.add_theme_color_override("font_color", Color(0.42, 0.90, 1.0))
	else:
		active_build_icon_lbl.text = "⏳ Sırada Bekliyor: Seviye %d" % tgt
		active_build_time_lbl.text = "Süre: %02d:%02d (Sırada)" % [rem / 60, rem % 60]
		active_build_time_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.40))

	active_build_progress.value = pct

	var item_id: int = int(active_item.get("id", -1))
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
			sm.save_game()
		var bus = Engine.get_main_loop().root.get_node_or_null("EventBus") if Engine.get_main_loop() is SceneTree else null
		if bus != null:
			if bus.has_signal("resources_changed"):
				bus.resources_changed.emit(gs.active_village_id)
			if bus.has_signal("state_changed"):
				bus.state_changed.emit()
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
			sm.save_game()

		var bus = Engine.get_main_loop().root.get_node_or_null("EventBus") if Engine.get_main_loop() is SceneTree else null
		if bus != null:
			if bus.has_signal("building_started"):
				bus.building_started.emit(vid, _current_key, int(res.get("target_level", 0)))
			if bus.has_signal("resources_changed"):
				bus.resources_changed.emit(vid)
			if bus.has_signal("state_changed"):
				bus.state_changed.emit()

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
	var state: Dictionary = gs.to_dict() if gs != null else {}
	var vid := int(_village.get("id", -1))
	var cur_barracks_lvl := int(_village.get("buildings", {}).get("barracks", 0))

	# Active research item in queue
	var active_research_unit := ""
	if gs != null:
		for item in gs.queues:
			if typeof(item) == TYPE_DICTIONARY and int(item.get("village_id", -1)) == vid and str(item.get("type", "")) == "research":
				active_research_unit = str(item.get("key", ""))
				break

	var sig_parts: Array[String] = [str(cur_barracks_lvl), active_research_unit]
	for u_key in BARRACKS_UNITS:
		sig_parts.append("%s:%d:%d:%s" % [
			u_key,
			1 if RulesEngineScript.is_researched(_village, u_key) else 0,
			1 if ArmyAPI.can_research(_village, u_key, state) else 0,
			ArmyAPI.research_block_reason(_village, u_key, state)
		])
	var res_sig := "|".join(sig_parts)
	if res_sig == _last_research_sig and research_list.get_child_count() == BARRACKS_UNITS.size():
		return
	_last_research_sig = res_sig

	for child in research_list.get_children():
		research_list.remove_child(child)
		child.queue_free()

	for u_key in BARRACKS_UNITS:
		var u_name: String = GameDataScript.get_singleton().get_unit_name(u_key)
		var u_icon: String = UNIT_ICONS.get(u_key, "⚔️")
		var u_class: String = UNIT_CLASS_NAMES.get(u_key, "Piyade")

		var req_barracks := RulesEngineScript.research_requirement(u_key)
		var is_researched := RulesEngineScript.is_researched(_village, u_key)
		var r_cost := RulesEngineScript.research_cost(u_key)
		var r_secs := int(ceil(RulesEngineScript.research_seconds(u_key, cur_barracks_lvl)))

		var res_dict: Dictionary = _village.get("resources", {})
		var cur_w: int = int(res_dict.get("wood", 0))
		var cur_s: int = int(res_dict.get("stone", 0))
		var cur_i: int = int(res_dict.get("iron", 0))

		var card := PanelContainer.new()
		card.name = "ResearchCard_" + u_key
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
		vbox.add_theme_constant_override("separation", 8)
		card.add_child(vbox)

		# Top row: Unit icon, name, class badge, requirement
		var top_row := HBoxContainer.new()
		top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_row.add_theme_constant_override("separation", 10)

		var name_lbl := Label.new()
		name_lbl.text = "%s %s" % [u_icon, u_name]
		name_lbl.add_theme_font_override("font", FontNunitoBold)
		name_lbl.add_theme_font_size_override("font_size", 26)
		name_lbl.add_theme_constant_override("outline_size", 0)
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82))
		name_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		top_row.add_child(name_lbl)

		var class_badge := Label.new()
		class_badge.text = "[%s]" % u_class
		class_badge.add_theme_font_override("font", FontNunitoSemiBold)
		class_badge.add_theme_font_size_override("font_size", 20)
		class_badge.add_theme_constant_override("outline_size", 0)
		class_badge.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		class_badge.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0))
		top_row.add_child(class_badge)

		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_row.add_child(spacer)

		var req_lbl := Label.new()
		req_lbl.add_theme_font_override("font", FontNunitoBold)
		req_lbl.add_theme_font_size_override("font_size", 22)
		req_lbl.add_theme_constant_override("outline_size", 0)
		req_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		if cur_barracks_lvl >= req_barracks:
			req_lbl.text = "✓ Kışla Sv. %d" % req_barracks
			req_lbl.add_theme_color_override("font_color", Color(0.45, 0.95, 0.56))
		else:
			req_lbl.text = "✗ Kışla Sv. %d Gerekli" % req_barracks
			req_lbl.add_theme_color_override("font_color", Color(1.0, 0.55, 0.48))
		top_row.add_child(req_lbl)

		vbox.add_child(top_row)

		# Combat stats line
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
		stats_lbl.add_theme_font_override("font", FontNunitoSemiBold)
		stats_lbl.add_theme_font_size_override("font_size", 20)
		stats_lbl.add_theme_constant_override("outline_size", 0)
		stats_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		stats_lbl.add_theme_color_override("font_color", Color(0.90, 0.88, 0.82))
		vbox.add_child(stats_lbl)

		# Cost row and action button
		var bottom_row := HBoxContainer.new()
		bottom_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bottom_row.add_theme_constant_override("separation", 12)

		# Cost items
		var cost_hbox := HBoxContainer.new()
		cost_hbox.add_theme_constant_override("separation", 12)
		cost_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var w_pill := _create_mini_resource_pill(IconWood, int(r_cost.get("wood", 0)), cur_w)
		var s_pill := _create_mini_resource_pill(IconStone, int(r_cost.get("stone", 0)), cur_s)
		var i_pill := _create_mini_resource_pill(IconIron, int(r_cost.get("iron", 0)), cur_i)
		cost_hbox.add_child(w_pill)
		cost_hbox.add_child(s_pill)
		cost_hbox.add_child(i_pill)

		var time_info := Label.new()
		time_info.text = "⏱️ %s" % _format_time_str(r_secs)
		time_info.add_theme_font_override("font", FontNunitoBold)
		time_info.add_theme_font_size_override("font_size", 21)
		time_info.add_theme_constant_override("outline_size", 2)
		time_info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		time_info.add_theme_color_override("font_color", Color(0.95, 0.90, 0.80))
		time_info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cost_hbox.add_child(time_info)

		bottom_row.add_child(cost_hbox)

		# Button or Status Badge
		if is_researched:
			var badge := Label.new()
			badge.text = "✓ Araştırıldı"
			badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			badge.custom_minimum_size = Vector2(185, 52)
			badge.add_theme_font_override("font", FontNunitoBold)
			badge.add_theme_font_size_override("font_size", 24)
			badge.add_theme_constant_override("outline_size", 3)
			badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
			badge.add_theme_color_override("font_color", Color(0.40, 0.95, 0.55))
			var b_sb := StyleBoxFlat.new()
			b_sb.bg_color = Color(0.12, 0.28, 0.16, 0.95)
			b_sb.border_color = Color(0.40, 0.85, 0.50, 0.9)
			b_sb.set_border_width_all(2)
			b_sb.set_corner_radius_all(12)
			badge.add_theme_stylebox_override("normal", b_sb)
			bottom_row.add_child(badge)
		elif active_research_unit == u_key:
			var badge := Label.new()
			badge.text = "⏳ Araştırılıyor..."
			badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			badge.custom_minimum_size = Vector2(185, 52)
			badge.add_theme_font_override("font", FontNunitoBold)
			badge.add_theme_font_size_override("font_size", 24)
			badge.add_theme_constant_override("outline_size", 3)
			badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
			badge.add_theme_color_override("font_color", Color(0.50, 0.90, 1.0))
			var b_sb := StyleBoxFlat.new()
			b_sb.bg_color = Color(0.12, 0.22, 0.35, 0.95)
			b_sb.border_color = Color(0.45, 0.78, 1.0, 0.9)
			b_sb.set_border_width_all(2)
			b_sb.set_corner_radius_all(12)
			badge.add_theme_stylebox_override("normal", b_sb)
			bottom_row.add_child(badge)
		else:
			var res_btn := Button.new()
			res_btn.name = "ResearchBtn_" + u_key
			res_btn.custom_minimum_size = Vector2(185, 52)
			res_btn.add_theme_font_override("font", FontNunitoBold)
			res_btn.add_theme_font_size_override("font_size", 24)
			res_btn.add_theme_constant_override("outline_size", 3)
			res_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
			res_btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
			res_btn.add_theme_constant_override("shadow_offset_y", 2)

			var can_res := ArmyAPI.can_research(_village, u_key, state)
			var reason := ArmyAPI.research_block_reason(_village, u_key, state)

			if can_res:
				res_btn.text = "🔬 Araştır"
				var r_sb := StyleBoxFlat.new()
				r_sb.bg_color = Color(0.20, 0.58, 0.32, 1.0)
				r_sb.border_color = Color(0.60, 0.95, 0.70, 1.0)
				r_sb.set_border_width_all(2)
				r_sb.set_corner_radius_all(12)
				r_sb.shadow_size = 4
				r_sb.shadow_color = Color(0, 0, 0, 0.4)
				var r_pressed := r_sb.duplicate() as StyleBoxFlat
				r_pressed.bg_color = Color(0.12, 0.45, 0.22, 1.0)
				r_pressed.border_color = Color(1.0, 0.90, 0.50, 1.0)
				res_btn.add_theme_stylebox_override("normal", r_sb)
				res_btn.add_theme_stylebox_override("hover", r_sb)
				res_btn.add_theme_stylebox_override("pressed", r_pressed)
				res_btn.add_theme_color_override("font_color", Color(1, 1, 1))
				res_btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
				res_btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.95, 0.75))
				res_btn.add_theme_color_override("font_focus_color", Color(1, 1, 1))
				res_btn.pressed.connect(_on_start_research_pressed.bind(u_key))
			else:
				res_btn.disabled = true
				var d_sb := StyleBoxFlat.new()
				d_sb.bg_color = Color(0.18, 0.17, 0.20, 0.9)
				d_sb.border_color = Color(0.38, 0.35, 0.42, 0.75)
				d_sb.set_border_width_all(2)
				d_sb.set_corner_radius_all(12)
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

			bottom_row.add_child(res_btn)

		vbox.add_child(bottom_row)
		research_list.add_child(card)


func _create_mini_resource_pill(icon_tex: Texture2D, req_amount: int, cur_amount: int) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)

	var icon_rect := TextureRect.new()
	icon_rect.texture = icon_tex
	icon_rect.custom_minimum_size = Vector2(28, 28)
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(icon_rect)

	var lbl := Label.new()
	lbl.text = str(req_amount)
	lbl.add_theme_font_override("font", FontNunitoBold)
	lbl.add_theme_font_size_override("font_size", 21)
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
	active_research_time_lbl.text = "Kalan: %02d:%02d" % [rem / 60, rem % 60]

	var pct := float(total_dur - rem) / float(total_dur) * 100.0
	active_research_progress.value = clampf(pct, 0.0, 100.0)

	var item_id: int = int(active_item.get("id", -1))
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
	var state: Dictionary = gs.to_dict()
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
		gs.from_dict(state)
		_village = gs.get_active_village()

		var sm = Engine.get_main_loop().root.get_node_or_null("SaveManager") if Engine.get_main_loop() is SceneTree else null
		if sm != null:
			sm.save_game()

		var bus = Engine.get_main_loop().root.get_node_or_null("EventBus") if Engine.get_main_loop() is SceneTree else null
		if bus != null:
			if bus.has_signal("research_started"):
				bus.research_started.emit(vid, unit_key)
			if bus.has_signal("resources_changed"):
				bus.resources_changed.emit(vid)
			if bus.has_signal("state_changed"):
				bus.state_changed.emit()

	refresh()


func _on_cancel_research_pressed(queue_id: int) -> void:
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

	var ok := ArmyAPI.cancel_research(st_village, queue_id, state)
	if ok:
		gs.from_dict(state)
		_village = gs.get_active_village()

		var sm = Engine.get_main_loop().root.get_node_or_null("SaveManager") if Engine.get_main_loop() is SceneTree else null
		if sm != null:
			sm.save_game()

		var bus = Engine.get_main_loop().root.get_node_or_null("EventBus") if Engine.get_main_loop() is SceneTree else null
		if bus != null:
			if bus.has_signal("resources_changed"):
				bus.resources_changed.emit(vid)
			if bus.has_signal("state_changed"):
				bus.state_changed.emit()

	refresh()


# =============================================================================
#  BİRİM EĞİTİMİ SEKMESİ (TRAIN TAB)
# =============================================================================

func _calculate_max_trainable(u_key: String) -> int:
	var res = _village.get("resources", {})
	var cur_w := int(res.get("wood", 0))
	var cur_s := int(res.get("stone", 0))
	var cur_i := int(res.get("iron", 0))

	var single_cost := RulesEngineScript.unit_cost(u_key, 1)
	var u_w := maxi(1, int(single_cost.get("wood", 0)))
	var u_s := maxi(1, int(single_cost.get("stone", 0)))
	var u_i := maxi(1, int(single_cost.get("iron", 0)))
	var u_settlers := maxi(1, RulesEngineScript.unit_settlers(u_key))

	var free_cit := ArmyAPI.army_capacity(_village)

	var limit_w := cur_w / u_w
	var limit_s := cur_s / u_s
	var limit_i := cur_i / u_i
	var limit_cit := free_cit / u_settlers

	return maxi(0, mini(mini(limit_w, limit_s), mini(limit_i, limit_cit)))


func _populate_train_list() -> void:
	if train_list == null:
		return

	var cur_barracks_lvl := int(_village.get("buildings", {}).get("barracks", 0))
	var free_cit := ArmyAPI.army_capacity(_village)
	var farm_lvl := VillageModel.building_level(_village, "farm")
	var max_pop := RulesEngineScript.max_population(farm_lvl)

	if citizen_label != null:
		citizen_label.text = "👥 Müsait Vatandaş: %d  (Toplam Değirmen Kapasitesi: %d)" % [free_cit, max_pop]

	var sig_parts: Array[String] = [str(cur_barracks_lvl)]
	for u_key in BARRACKS_UNITS:
		sig_parts.append("%s:%d:%d" % [
			u_key,
			1 if RulesEngineScript.is_researched(_village, u_key) else 0,
			int(_village.get("units", {}).get(u_key, 0))
		])
	var train_sig := "|".join(sig_parts)
	if train_sig == _last_train_sig and train_list.get_child_count() == BARRACKS_UNITS.size():
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
		var card_sb := StyleBoxFlat.new()
		card_sb.bg_color = Color(0.12, 0.11, 0.15, 0.98)
		card_sb.border_color = Color(0.48, 0.42, 0.34, 0.9)
		card_sb.set_border_width_all(2)
		card_sb.set_corner_radius_all(14)
		card_sb.content_margin_left = 18
		card_sb.content_margin_top = 16
		card_sb.content_margin_right = 18
		card_sb.content_margin_bottom = 16
		card.add_theme_stylebox_override("panel", card_sb)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 10)
		card.add_child(vbox)

		# Top row: Unit icon, name, class badge, existing troop count
		var top_row := HBoxContainer.new()
		top_row.add_theme_constant_override("separation", 12)

		var name_lbl := Label.new()
		name_lbl.text = "%s %s" % [u_icon, u_name]
		name_lbl.add_theme_font_override("font", FontNunitoBold)
		name_lbl.add_theme_font_size_override("font_size", 28)
		name_lbl.add_theme_constant_override("outline_size", 0)
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82))
		name_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		top_row.add_child(name_lbl)

		var class_badge := Label.new()
		class_badge.text = "[%s]" % u_class
		class_badge.add_theme_font_override("font", FontNunitoSemiBold)
		class_badge.add_theme_font_size_override("font_size", 22)
		class_badge.add_theme_constant_override("outline_size", 0)
		class_badge.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		class_badge.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0))
		top_row.add_child(class_badge)

		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_row.add_child(spacer)

		var have_units := int(_village.get("units", {}).get(u_key, 0))
		var have_lbl := Label.new()
		have_lbl.text = "Mevcut: %d Adet" % have_units
		have_lbl.add_theme_font_override("font", FontNunitoBold)
		have_lbl.add_theme_font_size_override("font_size", 26)
		have_lbl.add_theme_constant_override("outline_size", 0)
		have_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
		have_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		top_row.add_child(have_lbl)

		vbox.add_child(top_row)

		if not is_researched:
			# Unresearched notice
			var lock_row := HBoxContainer.new()
			lock_row.add_theme_constant_override("separation", 14)

			var lock_lbl := Label.new()
			lock_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lock_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lock_lbl.text = "🔒 Bu birim henüz araştırılmadı. (Gereken: Kışla Seviye %d)" % req_barracks
			lock_lbl.add_theme_font_override("font", FontNunitoSemiBold)
			lock_lbl.add_theme_font_size_override("font_size", 23)
			lock_lbl.add_theme_constant_override("outline_size", 0)
			lock_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
			lock_lbl.add_theme_color_override("font_color", Color(0.95, 0.65, 0.50))
			lock_row.add_child(lock_lbl)

			var goto_res_btn := Button.new()
			goto_res_btn.name = "GotoResearchBtn_" + u_key
			goto_res_btn.text = "Birim Araştır ➔"
			goto_res_btn.custom_minimum_size = Vector2(185, 52)
			goto_res_btn.add_theme_font_override("font", FontNunitoBold)
			goto_res_btn.add_theme_font_size_override("font_size", 24)
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
			g_sb.shadow_size = 4
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
		else:
			# Combat stats line
			var combat := RulesEngineScript.unit_combat(u_key)
			var spd := RulesEngineScript.unit_speed(u_key)
			var carry := RulesEngineScript.unit_carry(u_key)

			var stats_lbl := Label.new()
			stats_lbl.text = "Saldırı: %d | Savunma (Piy:%d / Süv:%d / Okç:%d) | Hız: %.1f dk | Taşıma: %d" % [
				combat.attack, combat.def_inf, combat.def_cav, combat.def_arch, spd, carry
			]
			stats_lbl.add_theme_font_override("font", FontNunitoBold)
			stats_lbl.add_theme_font_size_override("font_size", 22)
			stats_lbl.add_theme_constant_override("outline_size", 2)
			stats_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
			stats_lbl.add_theme_color_override("font_color", Color(0.90, 0.88, 0.82))
			vbox.add_child(stats_lbl)

			# Single cost line with sharp icons and numbers
			var single_cost := RulesEngineScript.unit_cost(u_key, 1)
			var single_sec := int(ceil(RulesEngineScript.training_seconds(u_key, 1, cur_barracks_lvl)))
			var single_settler := RulesEngineScript.unit_settlers(u_key)

			var cost_row := HBoxContainer.new()
			cost_row.add_theme_constant_override("separation", 14)

			var cost_title := Label.new()
			cost_title.text = "Birim Başı:"
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
			input_row.add_theme_constant_override("separation", 10)

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

			# SpinBox for quantity
			var spin := SpinBox.new()
			spin.name = "Spin_" + u_key
			spin.min_value = 0
			spin.max_value = 99999
			spin.step = 1
			spin.value = int(_train_counts.get(u_key, 0))
			spin.custom_minimum_size = Vector2(135, 54)
			spin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var s_line := spin.get_line_edit()
			if s_line != null:
				s_line.alignment = HORIZONTAL_ALIGNMENT_CENTER
				s_line.add_theme_font_override("font", FontNunitoBold)
				s_line.add_theme_font_size_override("font_size", 26)
				s_line.add_theme_constant_override("outline_size", 2)
				s_line.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
			input_row.add_child(spin)

			var train_btn := Button.new()
			train_btn.name = "TrainBtn_" + u_key
			train_btn.text = "⚔️ Eğit"
			train_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			train_btn.custom_minimum_size = Vector2(160, 54)
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
			t_sb.shadow_size = 6
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
			calc_summary.add_theme_font_override("font", FontNunitoBold)
			calc_summary.add_theme_font_size_override("font_size", 24)
			calc_summary.add_theme_constant_override("outline_size", 3)
			calc_summary.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
			calc_summary.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
			calc_summary.add_theme_constant_override("shadow_offset_y", 2)
			vbox.add_child(calc_summary)

			# Dynamic update closure
			var update_calc = func():
				var c := int(spin.value)
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
						train_btn.text = "Yetersiz Kaynak / Nüfus"

			update_calc.call()
			card.set_meta("update_calc", update_calc)

			spin.value_changed.connect(func(_val): update_calc.call())
			btn_p1.pressed.connect(func(): spin.value += 1)
			btn_p5.pressed.connect(func(): spin.value += 5)
			btn_p10.pressed.connect(func(): spin.value += 10)
			btn_max.pressed.connect(func(): spin.value = _calculate_max_trainable(u_key))

			train_btn.pressed.connect(func():
				var c := int(spin.value)
				if c > 0:
					_on_start_train_pressed(u_key, c)
			)

		train_list.add_child(card)


func _create_quick_button(btn_text: String) -> Button:
	var btn := Button.new()
	btn.text = btn_text
	btn.custom_minimum_size = Vector2(76, 54)
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
	sb.shadow_size = 4
	sb.shadow_color = Color(0, 0, 0, 0.5)

	var sb_hover := StyleBoxFlat.new()
	sb_hover.bg_color = Color(0.28, 0.24, 0.32, 1.0)
	sb_hover.border_color = Color(1.0, 0.88, 0.55, 1.0)
	sb_hover.set_border_width_all(2)
	sb_hover.set_corner_radius_all(12)
	sb_hover.shadow_size = 6
	sb_hover.shadow_color = Color(0, 0, 0, 0.6)

	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_hover)

	return btn


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

	if train_items.is_empty():
		active_train_box.hide()
		return

	active_train_box.show()
	var now := _current_now()

	# Rebuild or update rows
	while train_queue_list.get_child_count() < train_items.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)

		var name_lbl := Label.new()
		name_lbl.name = "NameLabel"
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
		prog.custom_minimum_size = Vector2(150, 26)
		prog.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		prog.show_percentage = false
		var p_bg := StyleBoxFlat.new()
		p_bg.bg_color = Color(0.08, 0.07, 0.10, 0.95)
		p_bg.border_color = Color(0.50, 0.42, 0.30, 0.8)
		p_bg.set_border_width_all(1)
		p_bg.set_corner_radius_all(6)
		var p_fg := StyleBoxFlat.new()
		p_fg.bg_color = Color(0.20, 0.80, 0.42, 1.0)
		p_fg.set_corner_radius_all(5)
		prog.add_theme_stylebox_override("background", p_bg)
		prog.add_theme_stylebox_override("fill", p_fg)
		row.add_child(prog)

		var c_btn := Button.new()
		c_btn.name = "CancelButton"
		c_btn.text = "✕ İptal"
		c_btn.custom_minimum_size = Vector2(110, 48)
		c_btn.add_theme_font_override("font", FontNunitoBold)
		c_btn.add_theme_font_size_override("font_size", 22)
		c_btn.add_theme_constant_override("outline_size", 2)
		c_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		var c_sb := StyleBoxFlat.new()
		c_sb.bg_color = Color(0.68, 0.18, 0.15, 0.95)
		c_sb.border_color = Color(0.98, 0.55, 0.45, 0.95)
		c_sb.set_border_width_all(2)
		c_sb.set_corner_radius_all(10)
		c_sb.shadow_size = 4
		c_btn.add_theme_stylebox_override("normal", c_sb)
		c_btn.add_theme_stylebox_override("hover", c_sb)
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
		name_lbl.text = "⚔️ %d %s" % [count, u_name]

		var time_lbl: Label = row.get_node("TimeLabel")
		time_lbl.text = "%02d:%02d" % [rem / 60, rem % 60]

		var prog: ProgressBar = row.get_node("ProgressBar")
		prog.value = clampf(float(total_dur - rem) / float(total_dur) * 100.0, 0.0, 100.0)

		var c_btn: Button = row.get_node("CancelButton")
		var q_id: int = int(item.get("id", -1))
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
			sm.save_game()

		var bus = Engine.get_main_loop().root.get_node_or_null("EventBus") if Engine.get_main_loop() is SceneTree else null
		if bus != null:
			if bus.has_signal("unit_training_started"):
				bus.unit_training_started.emit(vid, unit_key, count)
			if bus.has_signal("resources_changed"):
				bus.resources_changed.emit(vid)
			if bus.has_signal("state_changed"):
				bus.state_changed.emit()

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
			sm.save_game()

		var bus = Engine.get_main_loop().root.get_node_or_null("EventBus") if Engine.get_main_loop() is SceneTree else null
		if bus != null:
			if bus.has_signal("resources_changed"):
				bus.resources_changed.emit(vid)
			if bus.has_signal("state_changed"):
				bus.state_changed.emit()

	refresh()


# =============================================================================
#  KUYUMCU (ALTIN ZIRH) VE KÖŞK (KONT EĞİTİMİ) ÖZEL AKSİYONLARI
# =============================================================================

func _update_special_building_actions(_cur_lvl: int) -> void:
	if _special_box == null or _special_vbox == null:
		return
	for ch in _special_vbox.get_children():
		_special_vbox.remove_child(ch)
		ch.queue_free()

	_special_box.show()
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	var state: Dictionary = gs.to_dict() if gs != null else {}
	var res_dict: Dictionary = _village.get("resources", {})
	var cur_w := int(res_dict.get("wood", 0))
	var cur_s := int(res_dict.get("stone", 0))
	var cur_i := int(res_dict.get("iron", 0))

	if _current_key == "smith":
		var avail_armour := ArmyAPI.gold_armour(_village)
		var g_cost := ArmyAPI.gold_armour_cost(_village)
		var req_w := int(g_cost.get("wood", 30000))
		var req_s := int(g_cost.get("stone", 50000))
		var req_i := int(g_cost.get("iron", 40000))

		var hdr := Label.new()
		hdr.text = "🛡️ Altın Zırh Darphanesi   •   Mevcut Stok: %d Set" % avail_armour
		hdr.add_theme_font_override("font", FontNunitoBold)
		hdr.add_theme_font_size_override("font_size", 26)
		hdr.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
		_special_vbox.add_child(hdr)

		var cost_lbl := Label.new()
		cost_lbl.text = "1 Set Maliyeti: %s Odun  •  %s Taş  •  %s Demir" % [
			_format_number(req_w), _format_number(req_s), _format_number(req_i)
		]
		cost_lbl.add_theme_font_override("font", FontNunitoSemiBold)
		cost_lbl.add_theme_font_size_override("font_size", 22)
		cost_lbl.add_theme_color_override("font_color", Color(0.92, 0.88, 0.80))
		_special_vbox.add_child(cost_lbl)

		var mint_btn := Button.new()
		mint_btn.name = "MintGoldArmourBtn"
		mint_btn.custom_minimum_size = Vector2(0, 62)
		mint_btn.add_theme_font_override("font", FontNunitoBold)
		mint_btn.add_theme_font_size_override("font_size", 26)
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
		hdr.add_theme_font_size_override("font_size", 26)
		hdr.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
		_special_vbox.add_child(hdr)

		var cost_lbl := Label.new()
		cost_lbl.text = "Maliyet: %s Odun, %s Taş, %s Demir  •  100 Vatandaş  •  1 Altın Zırh" % [
			_format_number(req_w), _format_number(req_s), _format_number(req_i)
		]
		cost_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cost_lbl.add_theme_font_override("font", FontNunitoSemiBold)
		cost_lbl.add_theme_font_size_override("font_size", 22)
		cost_lbl.add_theme_color_override("font_color", Color(0.92, 0.88, 0.80))
		_special_vbox.add_child(cost_lbl)

		var can_snob := ArmyAPI.can_train(_village, "snob", 1, state)
		var reason := ArmyAPI.training_block_reason(_village, "snob", 1, state)
		var snob_btn := Button.new()
		snob_btn.name = "TrainSnobBtn"
		snob_btn.custom_minimum_size = Vector2(0, 62)
		snob_btn.add_theme_font_override("font", FontNunitoBold)
		snob_btn.add_theme_font_size_override("font_size", 26)
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
		gs.from_dict(state)
		_village = gs.get_active_village()
		var sm = Engine.get_main_loop().root.get_node_or_null("SaveManager") if Engine.get_main_loop() is SceneTree else null
		if sm != null:
			sm.save_game()
		var bus = Engine.get_main_loop().root.get_node_or_null("EventBus") if Engine.get_main_loop() is SceneTree else null
		if bus != null:
			if bus.has_signal("resources_changed"):
				bus.resources_changed.emit(vid)
			if bus.has_signal("state_changed"):
				bus.state_changed.emit()
	refresh()


func _on_train_snob_pressed() -> void:
	_on_start_train_pressed("snob", 1)
