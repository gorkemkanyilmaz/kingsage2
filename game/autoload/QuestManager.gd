extends CanvasLayer
## QuestManager — Tutorial sonrası devreye giren KingsAge tam kapsamlı Görev Sistemi (A-ARAYUZ).
##
## Özellikler:
##   * Tutorial tamamlandığında Village sahnesinin sol üst köşesinde (İttifak butonunun
##     tam ters tarafında) Kraliyet Görev Başlığı + aşağı açılan sıradaki ilk 3 görev görünür.
##   * Tüm ilerlemeler GameState.player["quests"] içinde saklanır ve canlı olarak X / Y formatında
##     (örn. 100 Casus üret -> 0/100 -> 50/100) takip edilir.
##   * Görev tamamlandığında "🎁 Ödülünü Al" butonu aktifleşir ve ödül oyuncunun köyüne aktarılır.
##   * Herhangi bir göreve tıklandığında Baş Vezir Görev Detay Penceresi açılarak ilgili bina,
##     asker veya KingsAge savaş/fetih mekaniğini ayrıntılı şekilde anlatır.

const RulesEngineScript := preload("res://scripts/rules/RulesEngine.gd")
const GameDataScript := preload("res://autoload/GameData.gd")
const AllianceModelScript := preload("res://scripts/model/AllianceModel.gd")

const FontNunitoBold := preload("res://assets/fonts/Nunito-Bold.ttf")
const FontNunitoSemiBold := preload("res://assets/fonts/Nunito-SemiBold.ttf")

const TexQuestIcon := preload("res://assets/sprites/ui/tutorial/quest_scroll_icon.png")
const TexVizier := preload("res://assets/sprites/ui/tutorial/vizier_portrait.png")
const TexRoyalSeal := preload("res://assets/sprites/ui/tutorial/royal_decree_seal.png")

const IconWood := preload("res://assets/sprites/ui/nano_banana/sharp_icon_wood.tres")
const IconStone := preload("res://assets/sprites/ui/nano_banana/sharp_icon_stone.tres")
const IconIron := preload("res://assets/sprites/ui/nano_banana/sharp_icon_iron.tres")

## Testler tarafından headless modda görev HUD'unu aktif etmek için kullanılır.
var quest_enabled_in_headless: bool = false

var _ui_built: bool = false
var _expanded: bool = true
var _open_modal_quest_id: String = ""
var _last_hud_sig: String = ""
var _has_claimable_quest: bool = false
var _hud_check_accum: float = 0.25
var _pulse_accum: float = 0.0
var _badge_tinted: bool = false
var _last_res_refresh_sec: float = -10.0
var _toast_until_sec: float = 0.0
var _elapsed_sec: float = 0.0
var _last_scene_id: int = 0
var _last_top_y: float = -1.0

# HUD Düğümleri
var _root_ctrl: Control
var _tracker_panel: VBoxContainer
var _btn_header: Button
var _header_icon: TextureRect
var _header_title: Label
var _header_badge: Label
var _header_chevron: Label
var _drawer_panel: PanelContainer
var _drawer_vbox: VBoxContainer
var _slot_nodes: Array[Dictionary] = []
var _empty_banner: Label

# Modal Düğümleri (Baş Vezir Görev Detayı)
var _modal_backdrop: ColorRect
var _modal_center: CenterContainer
var _detail_modal: PanelContainer
var _modal_seal: TextureRect
var _modal_category: Label
var _modal_title: Label
var _modal_close_top: Button
var _modal_vizier_text: RichTextLabel
var _modal_req_label: RichTextLabel
var _modal_prog_bar: ProgressBar
var _modal_prog_label: Label
var _modal_reward_row: HBoxContainer
var _modal_goto_box: VBoxContainer
var _modal_btn_goto: Button
var _modal_btn_claim: Button
var _modal_btn_close: Button

# Ödül bildirimi
var _toast_panel: PanelContainer
var _toast_label: Label


const TUTORIAL_QUEST_DEFS: Array[Dictionary] = [
	{
		"id": "q_tut_wood_2",
		"icon": "🪓",
		"category": "REHBER • EKONOMİ",
		"title": "Rehber: Oduncu Kampı Sv.2",
		"target": 2,
		"check_type": "building_level",
		"building_key": "wood",
		"goto_type": "building",
		"goto_target": "wood",
		"reward": {"wood": 200, "stone": 150, "iron": 100},
		"vizier_desc": "[b][color=#FFD86B]Lordum,[/color][/b] rehber adımını atladığınız için temel üretim görevini buradan sürdürüyoruz. [b]Oduncu Kampı[/b]'nızı [b]Seviye 2[/b]'ye yükselterek inşaat kerestesi gelirini artırın."
	},
	{
		"id": "q_tut_storage_farm_3",
		"icon": "🌾",
		"category": "REHBER • LOJİSTİK",
		"title": "Rehber: Depo & Değirmen Sv.3",
		"target": 2,
		"check_type": "storage_farm_3",
		"goto_type": "building",
		"goto_target": "storage",
		"reward": {"wood": 250, "stone": 250, "iron": 200},
		"vizier_desc": "[b][color=#FFD86B]Lordum,[/color][/b] Kışla inşa edebilmek ve kaynakları saklamak için [b]Depo[/b] ve [b]Değirmen[/b] binalarının ikisini de [b]Seviye 3[/b]'e çıkarın."
	},
	{
		"id": "q_tut_barracks_1",
		"icon": "🛡️",
		"category": "REHBER • ASKERİYE",
		"title": "Rehber: Kışla İnşa Et (Sv.1)",
		"target": 1,
		"check_type": "building_min",
		"building_key": "barracks",
		"min_level": 1,
		"goto_type": "building",
		"goto_target": "barracks",
		"reward": {"wood": 300, "stone": 250, "iron": 250},
		"vizier_desc": "[b][color=#FFD86B]Lordum,[/color][/b] ordu kurmanın ilk adımı [b]Kışla[/b] inşa etmektir. Köy meydanından Kışla'yı [b]Seviye 1[/b]'e yükseltin."
	},
	{
		"id": "q_tut_research_spear",
		"icon": "📜",
		"category": "REHBER • ARAŞTIRMA",
		"title": "Rehber: Silahtar Araştır",
		"target": 1,
		"check_type": "unit_researched",
		"unit_key": "spear",
		"goto_type": "barracks_research",
		"goto_target": "spear",
		"reward": {"wood": 250, "stone": 200, "iron": 250},
		"vizier_desc": "[b][color=#FFD86B]Lordum,[/color][/b] Kışla içinde [b]Birim Araştır[/b] sekmesine geçip ilk piyademiz olan [b]Silahtar[/b] birimini araştırın."
	},
	{
		"id": "q_tut_train_spear_10",
		"icon": "⚔️",
		"category": "REHBER • İLK ORDU",
		"title": "Rehber: 10 Silahtar Eğit",
		"target": 10,
		"check_type": "unit_count_peak",
		"unit_key": "spear",
		"goto_type": "barracks_train",
		"goto_target": "spear",
		"reward": {"wood": 400, "stone": 350, "iron": 350},
		"vizier_desc": "[b][color=#FFD86B]Lordum,[/color][/b] Kışla [b]Asker Eğit[/b] sekmesinden [b]10 Silahtar[/b] yetiştirerek krallığınızın ilk savunma muhafızlarını kurun!"
	},
]


const QUEST_DEFS: Array[Dictionary] = [
	{
		"id": "q_wood_stone_3",
		"icon": "🪓",
		"category": "EKONOMİ & ÜRETİM",
		"title": "Üretim Temelleri (Odun Sv.3 & Taş Sv.2)",
		"target": 2,
		"check_type": "wood_stone_levels",
		"goto_type": "building",
		"goto_target": "wood",
		"reward": {"wood": 400, "stone": 400, "iron": 250},
		"vizier_desc": "[b][color=#FFD86B]Lordum,[/color][/b] büyüyen bir krallığın kalbi hammadde ocaklarıdır. [b]Oduncu Kampı[/b] inşaatlar ve piyadeler için kereste; [b]Taş Ocağı[/b] ise sur ve binalar için taş blok sağlar.\n\nOduncu Kampı'nı [b]Seviye 3[/b]'e, Taş Ocağı'nı ise [b]Seviye 2[/b]'ye yükselterek saatlik gelirinizi güvence altına alın."
	},
	{
		"id": "q_iron_2",
		"icon": "⛏️",
		"category": "EKONOMİ & ÜRETİM",
		"title": "Demir Ocaklarını Ateşle (Sv.2)",
		"target": 2,
		"check_type": "building_level",
		"building_key": "iron",
		"goto_type": "building",
		"goto_target": "iron",
		"reward": {"wood": 450, "stone": 450, "iron": 400},
		"vizier_desc": "[b][color=#FFD86B]Lordum,[/color][/b] ağır zırhlı askerler, Baltacılar ve Süvariler için en kritik kaynak [b]Demir[/b]'dir. [b]Maden Ocağı[/b] ne kadar yüksek seviyede olursa işçiler o kadar derin damarlardan hızlı demir çıkarır."
	},
	{
		"id": "q_storage_farm_4",
		"icon": "🌾",
		"category": "LOJİSTİK & NÜFUS",
		"title": "Erzak ve Ambar (Depo & Değirmen Sv.4)",
		"target": 2,
		"check_type": "storage_farm_4",
		"goto_type": "building",
		"goto_target": "storage",
		"reward": {"wood": 700, "stone": 700, "iron": 550},
		"vizier_desc": "[b][color=#FFD86B]Lordum,[/color][/b] [b]Depo[/b] ambarlarınızın alabileceği maksimum Odun, Taş ve Demir sınırını belirler; dolarsa fazla üretim çöpe gider! [b]Değirmen[/b] ise köyünüzde çalışabilecek toplam işçi ve asker nüfusunu belirler. İkisini de [b]Seviye 4[/b]'e yükseltin."
	},
	{
		"id": "q_unlock_hide",
		"icon": "🕵️‍♂️",
		"category": "BİNA AÇMA • SAVUNMA",
		"title": "Gizli Depo İnşası (Aç)",
		"target": 1,
		"check_type": "building_min",
		"building_key": "hide",
		"min_level": 1,
		"goto_type": "building",
		"goto_target": "hide",
		"reward": {"wood": 600, "stone": 600, "iron": 500},
		"vizier_desc": "[b][color=#FFD86B]Lordum,[/color][/b] [b]Gizli Depo[/b], düşman saldırılarına ve yağmalara karşı hayati bir sigortadır. Burada saklanan hammaddeler yağmalanamaz ve [b]düşman casusları[/b] Gizli Depo'daki stokunuzu asla göremez!"
	},
	{
		"id": "q_unlock_wall",
		"icon": "🏰",
		"category": "BİNA AÇMA • SAVUNMA",
		"title": "Köy Surlarını Yükselt (Aç)",
		"target": 1,
		"check_type": "building_min",
		"building_key": "wall",
		"min_level": 1,
		"goto_type": "building",
		"goto_target": "wall",
		"reward": {"wood": 800, "stone": 1000, "iron": 600},
		"vizier_desc": "[b][color=#FFD86B]Lordum,[/color][/b] [b]Sur[/b] köyün temel savunmasını sağlar ve savunmadaki tüm askerlerinizin savaş gücünü seviye başına katlayarak artırır. Kışla Sv.1 mevcut olduğuna göre ilk taş surunuzu örün!"
	},
	{
		"id": "q_train_infantry_25",
		"icon": "⚔️",
		"category": "ORDU KURULUMU",
		"title": "Piyade Garnizonu (25 Piyade)",
		"target": 25,
		"check_type": "infantry_count",
		"goto_type": "barracks_train",
		"goto_target": "sword",
		"reward": {"wood": 1000, "stone": 900, "iron": 850},
		"vizier_desc": "[b][color=#FFD86B]Lordum,[/color][/b] saldırılara direnmek ve yağma seferlerine çıkmak için güçlü bir piyade birliği şart. Kışla'da [b]Silahtar[/b] veya [b]Muhafız[/b] araştırıp köyünüzdeki toplam piyade gücünü [b]25 askere[/b] çıkarın."
	},
	{
		"id": "q_storage_5",
		"icon": "🏛️",
		"category": "LOJİSTİK • ÖNKOŞUL",
		"title": "Büyük Ambar Hazırlığı (Depo Sv.5)",
		"target": 5,
		"check_type": "building_level",
		"building_key": "storage",
		"goto_type": "building",
		"goto_target": "storage",
		"reward": {"wood": 1100, "stone": 1100, "iron": 900},
		"vizier_desc": "[b][color=#FFD86B]Lordum,[/color][/b] tüccarların ve ticaret kervanlarının şehrimize girebilmesi için [b]Market[/b] inşa etmemiz şarttır. Market binasının önkoşulu [b]Depo Seviye 5[/b]'tir; ambarınızı büyütün!"
	},
	{
		"id": "q_unlock_market",
		"icon": "⚖️",
		"category": "BİNA AÇMA • TİCARET",
		"title": "Ticaret Kalbi: Market (Aç)",
		"target": 1,
		"check_type": "building_min",
		"building_key": "market",
		"min_level": 1,
		"goto_type": "building",
		"goto_target": "market",
		"reward": {"wood": 1200, "stone": 1200, "iron": 1000},
		"vizier_desc": "[b][color=#FFD86B]Lordum,[/color][/b] [b]Market[/b] diğer köylerle hammadde ticareti yapmanızı ve elinizdeki fazla kaynağı ihtiyacınız olanla takas etmenizi sağlar. Ayrıca ileride [b]Köşk[/b] kurmak için Market'in [b]Seviye 10[/b]'a ulaşması gerekecektir."
	},
	{
		"id": "q_unlock_stable",
		"icon": "🐴",
		"category": "BİNA AÇMA • TİCARET",
		"title": "Katır Çiftliği Kurulumu (Aç)",
		"target": 1,
		"check_type": "building_min",
		"building_key": "stable",
		"min_level": 1,
		"goto_type": "building",
		"goto_target": "stable",
		"reward": {"wood": 1400, "stone": 1400, "iron": 1200},
		"vizier_desc": "[b][color=#FFD86B]Lordum,[/color][/b] Market ticaretinin yükünü [b]Katır Çiftliği[/b]'nde yetişen yük katırları sırtlar! Yetiştirdiğiniz her katır tek seferde [b]1.000 birim hammadde[/b] taşıyabilir. Market Sv.1 ve Değirmen Sv.2 ile açılır."
	},
	{
		"id": "q_barracks_4_spy_res",
		"icon": "📜",
		"category": "İSTİHBARAT HAZIRLIĞI",
		"title": "Kışla Sv.4 & Casus Araştır",
		"target": 2,
		"check_type": "spy_prereq",
		"goto_type": "barracks_research",
		"goto_target": "spy",
		"reward": {"wood": 1600, "stone": 1600, "iron": 1400},
		"vizier_desc": "[b][color=#FFD86B]Lordum,[/color][/b] körü körüne saldırmak kraliyet ordusunu tuzağa düşürür! Kışla'yı [b]Seviye 4[/b]'e yükseltin ve 'Birim Araştır' sekmesinden [b]🕵️ Casus[/b] birimini araştırın."
	},
	{
		"id": "q_train_spy_5",
		"icon": "🕵️",
		"category": "İSTİHBARAT",
		"title": "İlk Casus Ekibi (5 Casus Üret)",
		"target": 5,
		"check_type": "unit_count_peak",
		"unit_key": "spy",
		"goto_type": "barracks_train",
		"goto_target": "spy",
		"reward": {"wood": 1800, "stone": 1500, "iron": 1500},
		"vizier_desc": "[b][color=#FFD86B]Lordum,[/color][/b] [b]Casuslar[/b] savaşmazlar; tek görevleri düşman köylerin içindeki kaynakları, bina seviyelerini ve savunma birliklerini gizlice gözlemleyip rapor getirmektir. Ayrıca köyünüzde duran casuslar düşman casuslarını yakalar!"
	},
	{
		"id": "q_spy_mission",
		"icon": "👁️",
		"category": "HARİTA OPERASYONU",
		"title": "Düşman Gözetleme (Casusluk Yap)",
		"target": 1,
		"check_type": "stat_min",
		"stat_key": "spies_total",
		"goto_type": "map",
		"goto_target": "",
		"reward": {"wood": 2200, "stone": 2200, "iron": 1800},
		"vizier_desc": "[b][color=#FFD86B]Lordum,[/color][/b] artık haritada gözlerimiz var! [b]Dünya Haritası[/b]'na geçin, komşu bir köye (Barbar veya rakip) dokunun ve [b]yalnızca Casus[/b] seçerek bir [b]Casusluk Seferi[/b] başlatın."
	},
	{
		"id": "q_research_axe",
		"icon": "🪓",
		"category": "SALDIRI HAZIRLIĞI",
		"title": "Baltacı Araştır (Hücum Piyadesi)",
		"target": 1,
		"check_type": "unit_researched",
		"unit_key": "axe",
		"goto_type": "barracks_research",
		"goto_target": "axe",
		"reward": {"wood": 6500, "stone": 3500, "iron": 4500},
		"vizier_desc": "[b][color=#FFD86B]Lordum,[/color][/b] casuslarımız hedef köylerin istihbaratını getirdi! Ganimet seferine çıkmadan önce yüksek hücum gücüne sahip [b]Baltacı[/b] birimini (Kışla Sv.2) araştırmalıyız. Kışla'da [b]Birim Araştır[/b] sekmesinden Baltacı'yı araştırın."
	},
	{
		"id": "q_train_axe_100",
		"icon": "⚔️",
		"category": "SALDIRI ORDUSU",
		"title": "100 Baltacı Üret (Hücum Ordusu)",
		"target": 100,
		"check_type": "unit_count_peak",
		"unit_key": "axe",
		"goto_type": "barracks_train",
		"goto_target": "axe",
		"reward": {"wood": 4500, "stone": 4000, "iron": 4500},
		"vizier_desc": "[b][color=#FFD86B]Lordum,[/color][/b] ilk büyük ganimet seferimizden zaferle ve dolu ambarlarla dönmek için güçlü bir vurucu orduya ihtiyacımız var! Kışla [b]Asker Eğit[/b] sekmesinden [b]100 adet Baltacı[/b] yetiştirin."
	},
	{
		"id": "q_raid_mission",
		"icon": "💰",
		"category": "SAVAŞ VE GANİMET",
		"title": "İlk Ganimet Seferini Başlat (Saldırı)",
		"target": 1,
		"check_type": "stat_min",
		"stat_key": "raids_total",
		"goto_type": "map",
		"goto_target": "",
		"reward": {"wood": 2800, "stone": 2800, "iron": 2400},
		"vizier_desc": "[b][color=#FFD86B]Lordum,[/color][/b] komşularınızdan ganimet (yağma) elde etmenin yolu [b]Saldır[/b] emrinden geçer! Ordunuz savaşı kazandığında sağ kalan birlikler düşman deposundan otomatik olarak [b]hammadde yağmalar[/b]. Haritadan bir köye [b]Saldır[/b] gönderin!"
	},
	{
		"id": "q_attack_mission",
		"icon": "⚔️",
		"category": "SAVAŞ VE FETİH",
		"title": "Köye Saldırı Düzenle",
		"target": 1,
		"check_type": "stat_min",
		"stat_key": "attacks_total",
		"goto_type": "map",
		"goto_target": "",
		"reward": {"wood": 3500, "stone": 3500, "iron": 3000},
		"vizier_desc": "[b][color=#FFD86B]Lordum,[/color][/b] [b]Saldırı[/b] komutu ordunuzun tamamının (%100 güçle) savunan birlikleri yok edene dek çarpışmasıdır. Minimum asker kuralı olan [b]3 × Kışla Seviyesi[/b] şartını sağlayarak bir köye Saldırı gönderin!"
	},
	{
		"id": "q_eco_mid_6",
		"icon": "⛏️",
		"category": "EKONOMİ & GÜÇLENME",
		"title": "Üretim Gücünü Katla (Ocaklar Sv.6)",
		"target": 3,
		"check_type": "res_all_level",
		"req_level": 6,
		"goto_type": "building",
		"goto_target": "wood",
		"reward": {"wood": 4000, "stone": 4000, "iron": 3500},
		"vizier_desc": "[b][color=#FFD86B]Lordum,[/color][/b] büyük süvari ve kuşatma ordularını beslemek için Oduncu Kampı, Taş Ocağı ve Maden Ocağı binalarının üçünü de [b]Seviye 6[/b]'ya çıkararak saatlik gelirinizi güvence altına alın."
	},
	{
		"id": "q_barracks_5_bow",
		"icon": "🏹",
		"category": "BİRLİK ÖNKOŞULU",
		"title": "Kışla Sv.5 & Okçu Araştır",
		"target": 2,
		"check_type": "unit_prereq",
		"req_barracks": 5,
		"unit_key": "bow",
		"goto_type": "barracks_research",
		"goto_target": "bow",
		"reward": {"wood": 4200, "stone": 4200, "iron": 3800},
		"vizier_desc": "[b][color=#FFD86B]Lordum,[/color][/b] surların ardını delecek ve kalemizi koruyacak [b]Okçu[/b] birliği için [b]Kışla Seviye 5[/b] şarttır. Kışla'yı yükseltip Okçu birimini araştırın."
	},
	{
		"id": "q_train_axe_bow",
		"icon": "🏹",
		"category": "ORDU ÇEŞİTLİLİĞİ",
		"title": "Baltacı & Okçu Birliği (30 Asker)",
		"target": 30,
		"check_type": "axe_bow_count",
		"goto_type": "barracks_train",
		"goto_target": "bow",
		"reward": {"wood": 4500, "stone": 4500, "iron": 4000},
		"vizier_desc": "[b][color=#FFD86B]Lordum,[/color][/b] [b]Baltacı[/b] (Kışla Sv.2) saldırı ordularının ağır yumruğudur; [b]Okçu[/b] (Kışla Sv.5) ise sur ardındaki savunmayı ateş yağmuruna tutar. Baltacı ve Okçu toplamınızı [b]30[/b]'a çıkarın!"
	},
	{
		"id": "q_join_or_create_alliance",
		"icon": "🤝",
		"category": "DİPLOMASİ • İTTİFAK",
		"title": "İttifak Kur veya Katıl",
		"target": 1,
		"check_type": "in_alliance",
		"goto_type": "alliance",
		"goto_target": "",
		"reward": {"wood": 5000, "stone": 5000, "iron": 4500},
		"vizier_desc": "[b][color=#FFD86B]Lordum,[/color][/b] tek bir kılıç krallık kurabilir ama ancak birlikten doğan güç imparatorluk yaşatır! Sağ üstteki [b]İTTİFAK[/b] ekranından yeni bir İttifak kurun veya mevcut bir ittifaka katılın."
	},
	{
		"id": "q_wall_5_farm_8",
		"icon": "🏰",
		"category": "TAHKİMAT & NÜFUS",
		"title": "Sur Sv.5 & Değirmen Sv.8",
		"target": 2,
		"check_type": "wall_farm_mid",
		"goto_type": "building",
		"goto_target": "wall",
		"reward": {"wood": 5500, "stone": 6000, "iron": 5000},
		"vizier_desc": "[b][color=#FFD86B]Lordum,[/color][/b] büyüyen ordular daha geniş tarlalar ve daha yüksek duvarlar ister. [b]Sur[/b] binasını [b]Seviye 5[/b]'e, [b]Değirmen[/b]'i ise [b]Seviye 8[/b]'e yükselterek savunma çarpanınızı ve nüfus kapasitenizi artırın."
	},
	{
		"id": "q_barracks_7_light",
		"icon": "🐎",
		"category": "SÜVARİ ÖNKOŞULU",
		"title": "Kışla Sv.7 & Akıncı Araştır",
		"target": 2,
		"check_type": "unit_prereq",
		"req_barracks": 7,
		"unit_key": "light",
		"goto_type": "barracks_research",
		"goto_target": "light",
		"reward": {"wood": 6500, "stone": 6000, "iron": 6000},
		"vizier_desc": "[b][color=#FFD86B]Lordum,[/color][/b] hızlı ganimet akınlarının belkemiği olan [b]Akıncı[/b] süvarisini açmak için [b]Kışla Seviye 7[/b] gereklidir. Kışla'yı yükseltin ve Akıncı birimini araştırın."
	},
	{
		"id": "q_train_cavalry",
		"icon": "🐎",
		"category": "SÜVARİ BİRLİKLERİ",
		"title": "Süvari Hücumu (20 Akıncı / Şövalye)",
		"target": 20,
		"check_type": "cavalry_count",
		"goto_type": "barracks_train",
		"goto_target": "light",
		"reward": {"wood": 7000, "stone": 6500, "iron": 6500},
		"vizier_desc": "[b][color=#FFD86B]Lordum,[/color][/b] [b]Akıncı[/b] (Kışla Sv.7) saat gibi hızlı akınlar yapıp bol ganimet taşır; [b]Kara Şövalye[/b] (Kışla Sv.16) ise en zırhlı elit süvaridir. Toplam [b]20 Süvari[/b] yetiştirin!"
	},
	{
		"id": "q_train_spy_100",
		"icon": "🦅",
		"category": "KRALİYET İSTİHBARATI",
		"title": "100 Casus Üret (Gölge Ordusu)",
		"target": 100,
		"check_type": "unit_count_peak",
		"unit_key": "spy",
		"goto_type": "barracks_train",
		"goto_target": "spy",
		"reward": {"wood": 12000, "stone": 10000, "iron": 10000},
		"vizier_desc": "[b][color=#FFD86B]Lordum,[/color][/b] büyük savaşlar başlamadan önce bilgi mutlak güçtür! Büyük kaleleri gözetlerken kayıp vermemek ve düşman casuslarını tamamen bozguna uğratmak için [b]100 Casus[/b] üretin."
	},
	{
		"id": "q_unlock_garage",
		"icon": "⚗️",
		"category": "BİNA AÇMA • TEKNOLOJİ",
		"title": "Simyager Laboratuvarı (Aç)",
		"target": 1,
		"check_type": "building_min",
		"building_key": "garage",
		"min_level": 1,
		"goto_type": "building",
		"goto_target": "garage",
		"reward": {"wood": 14000, "stone": 14000, "iron": 12000},
		"vizier_desc": "[b][color=#FFD86B]Lordum,[/color][/b] [b]Simyager[/b] (Kışla Sv.5 gerektirir) krallığınızın yüksek bilimler merkezidir. Fetih makamı [b]Köşk[/b]'ü inşa etmek için Simyager'i [b]Seviye 5[/b]'e kadar geliştirmeniz gerekecek!"
	},
	{
		"id": "q_storage_farm_12",
		"icon": "🌾",
		"category": "LOJİSTİK HAZIRLIĞI",
		"title": "İmparatorluk Ambarı (Depo & Değirmen Sv.12)",
		"target": 2,
		"check_type": "storage_farm_12",
		"goto_type": "building",
		"goto_target": "storage",
		"reward": {"wood": 15000, "stone": 15000, "iron": 13000},
		"vizier_desc": "[b][color=#FFD86B]Lordum,[/color][/b] kuşatma silahları, Köşk ve Altın Zırh yüksek kaynak rezervleri gerektirir. Hem [b]Depo[/b] hem de [b]Değirmen[/b] binalarını [b]Seviye 12[/b]'ye çıkararak ambarları genişletin."
	},
	{
		"id": "q_garage_5",
		"icon": "⚗️",
		"category": "TEKNOLOJİ • ÖNKOŞUL",
		"title": "Simyager Ustalaşması (Sv.5)",
		"target": 5,
		"check_type": "building_level",
		"building_key": "garage",
		"goto_type": "building",
		"goto_target": "garage",
		"reward": {"wood": 16000, "stone": 16000, "iron": 14000},
		"vizier_desc": "[b][color=#FFD86B]Lordum,[/color][/b] asilzadelerin makamı [b]Köşk[/b]'ü kurabilmenin son önkoşulu [b]Simyager Seviye 5[/b]'tir. Simyager laboratuvarını azami seviyeye ulaştırın."
	},
	{
		"id": "q_barracks_16_heavy",
		"icon": "🛡️",
		"category": "ELİT BİRLİK ÖNKOŞULU",
		"title": "Kışla Sv.16 & Kara Şövalye Araştır",
		"target": 2,
		"check_type": "unit_prereq",
		"req_barracks": 16,
		"unit_key": "heavy",
		"goto_type": "barracks_research",
		"goto_target": "heavy",
		"reward": {"wood": 17000, "stone": 17000, "iron": 15000},
		"vizier_desc": "[b][color=#FFD86B]Lordum,[/color][/b] ağır zırhlı elit süvari [b]Kara Şövalye[/b]'yi saflarınıza katmak ve kuşatma kışlasına yaklaşmak için [b]Kışla Seviye 16[/b]'ya çıkıp Kara Şövalye'yi araştırın."
	},
	{
		"id": "q_barracks_20_ram",
		"icon": "🐏",
		"category": "KUŞATMA ÖNKOŞULU",
		"title": "Kışla Sv.20 & Şahmerdan Araştır",
		"target": 2,
		"check_type": "unit_prereq",
		"req_barracks": 20,
		"unit_key": "ram",
		"goto_type": "barracks_research",
		"goto_target": "ram",
		"reward": {"wood": 18000, "stone": 18000, "iron": 16000},
		"vizier_desc": "[b][color=#FFD86B]Lordum,[/color][/b] yüksek surları yıkacak [b]Şahmerdan[/b] kuşatma koçbaşlarını üretebilmek için önce [b]Kışla Seviye 20[/b]'ye ulaşmalı ve Şahmerdan teknolojisini araştırmalısınız."
	},
	{
		"id": "q_siege_weapons",
		"icon": "🎯",
		"category": "KUŞATMA SANATI",
		"title": "Kuşatma Mühendisliği (5 Kuşatma)",
		"target": 5,
		"check_type": "siege_count",
		"goto_type": "barracks_train",
		"goto_target": "ram",
		"reward": {"wood": 18000, "stone": 18000, "iron": 16000},
		"vizier_desc": "[b][color=#FFD86B]Lordum,[/color][/b] [b]Şahmerdan[/b] (Kışla Sv.20) düşmanın koruyucu Surunu savaş sırasında yerle bir eder; [b]Mancınık[/b] (Kışla Sv.25) ise Kale veya Köşk gibi seçilen binaları yıkar. Toplam [b]5 adet Şahmerdan veya Mancınık[/b] üretin!"
	},
	{
		"id": "q_unlock_snob",
		"icon": "🏛️",
		"category": "BİNA AÇMA • ASALET",
		"title": "Asilzadelerin Makamı: Köşk (Aç)",
		"target": 1,
		"check_type": "building_min",
		"building_key": "snob",
		"min_level": 1,
		"goto_type": "building",
		"goto_target": "snob",
		"reward": {"wood": 28000, "stone": 32000, "iron": 28000},
		"vizier_desc": "[b][color=#FFD86B]Lordum,[/color][/b] [b]Köşk[/b] fetihlerinizin kalbidir! Yeni köyler ele geçirecek olan [b]👑 Kont[/b] birimleri yalnızca Köşk'te eğitilir.\n\nKurulabilmesi için [b]Simyager Sv.5[/b] (Kışla Sv.5 gerektirir) önkoşulunun tamamlanması gerekir. Her Kont, saldırdığı köyün Hakimiyet / Sadakat puanını düşürür!"
	},
	{
		"id": "q_unlock_smith",
		"icon": "🛡️",
		"category": "BİNA AÇMA • ZIRH",
		"title": "Altın Zırh Darphanesi: Kuyumcu (Aç)",
		"target": 1,
		"check_type": "building_min",
		"building_key": "smith",
		"min_level": 1,
		"goto_type": "building",
		"goto_target": "smith",
		"reward": {"wood": 32000, "stone": 42000, "iron": 36000},
		"vizier_desc": "[b][color=#FFD86B]Lordum,[/color][/b] bir asilzade zırhsız tahta çıkmaz! [b]Kuyumcu[/b] binasında Kont eğitebilmek için gereken değerli [b]Altın Zırh[/b] setleri basılır. [b]Köşk Sv.1[/b] tamamlandıktan sonra Kuyumcu'yu açabilirsiniz."
	},
	{
		"id": "q_mint_gold_armour",
		"icon": "🪙",
		"category": "FETİH HAZIRLIĞI",
		"title": "İlk Altın Zırhı Üret",
		"target": 1,
		"check_type": "gold_armour_made",
		"goto_type": "building",
		"goto_target": "smith",
		"reward": {"wood": 38000, "stone": 48000, "iron": 44000},
		"vizier_desc": "[b][color=#FFD86B]Lordum,[/color][/b] Kuyumcu hazır! Kuyumcu penceresini açarak [b]🛡️ Altın Zırh Üret[/b] butonuna basın ve ilk [b]Altın Zırh[/b] setini dövün. Her Kont için bir Altın Zırh gerekir."
	},
	{
		"id": "q_train_snob",
		"icon": "👑",
		"category": "FETİH HAZIRLIĞI",
		"title": "Asilzade: Kont Eğit (1 Kont)",
		"target": 1,
		"check_type": "unit_count_peak",
		"unit_key": "snob",
		"goto_type": "building",
		"goto_target": "snob",
		"reward": {"wood": 45000, "stone": 55000, "iron": 55000},
		"vizier_desc": "[b][color=#FFD86B]Lordum,[/color][/b] Altın Zırh hazır olduğuna göre artık [b]Köşk[/b]'ten ilk [b]👑 Kont[/b]'unuzu eğitebilirsiniz! Kont yanında güçlü bir koruma ordusuyla gönderilirse hayatta kaldığında düşman köyün Güç Alanını her vuruşta en fazla köyün maksimum puanının yarısı kadar ([b]2.250–2.750 puan[/b]; Anıt varsa [b]1.750–2.250[/b]) düşürür. Bu yüzden her fetih için en az [b]2 ayrı Kont saldırısı[/b] gerekir!"
	},
	{
		"id": "q_conquer_village",
		"icon": "🚩",
		"category": "BÜYÜK ZAFER • FETİH",
		"title": "Yeni Köy Fethet (2+ Köye Ulaş)",
		"target": 1,
		"check_type": "conquer_village",
		"goto_type": "map",
		"goto_target": "",
		"reward": {"wood": 80000, "stone": 80000, "iron": 80000},
		"vizier_desc": "[b][color=#FFD86B]Lordum,[/color][/b] tarih yazma vakti geldi! Haritadan seçtiğiniz bir köye [b]Kont eşliğinde[/b] ardı ardına Saldırı seferleri gönderin. Köyün Sadakati [b]0 veya altına[/b] düştüğünde Kont orada kalır ve köy sonsuza dek sizin olur!"
	},
	{
		"id": "q_unlock_statue",
		"icon": "🗽",
		"category": "BİNA AÇMA • İMPARATORLUK",
		"title": "Zaferin Sembolü: Anıt (Aç)",
		"target": 1,
		"check_type": "building_min",
		"building_key": "statue",
		"min_level": 1,
		"goto_type": "building",
		"goto_target": "statue",
		"reward": {"wood": 100000, "stone": 100000, "iron": 100000},
		"vizier_desc": "[b][color=#FFD86B]Lordum,[/color][/b] [b]Anıt[/b], köy meydanının ortasında yükselerek halkınıza ve düşmanlarınıza kudretinizi ilan eder (tüm diğer binalar son seviyeye ulaştığında açılır). [b]Anıt inşa edilen köyde savunma tahkimatı %50 artar![/b] İmparatorluğunuzu taçlandırın."
	},
]


func _ready() -> void:
	layer = 85
	visible = false
	_build_ui()
	_connect_signals()
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(_on_viewport_resized):
		vp.size_changed.connect(_on_viewport_resized)


func _on_viewport_resized() -> void:
	_sync_live_positions()


func _connect_signals() -> void:
	var bus := _bus()
	if bus == null:
		return
	if bus.has_signal("state_changed") and not bus.state_changed.is_connected(_on_game_event):
		bus.state_changed.connect(_on_game_event)
	if bus.has_signal("resources_changed") and not bus.resources_changed.is_connected(_on_resources_event):
		bus.resources_changed.connect(_on_resources_event)
	if bus.has_signal("building_completed") and not bus.building_completed.is_connected(_on_building_completed):
		bus.building_completed.connect(_on_building_completed)
	if bus.has_signal("research_completed") and not bus.research_completed.is_connected(_on_research_completed):
		bus.research_completed.connect(_on_research_completed)
	if bus.has_signal("unit_trained") and not bus.unit_trained.is_connected(_on_unit_trained):
		bus.unit_trained.connect(_on_unit_trained)
	if bus.has_signal("army_sent") and not bus.army_sent.is_connected(_on_army_sent):
		bus.army_sent.connect(_on_army_sent)
	if bus.has_signal("battle_resolved") and not bus.battle_resolved.is_connected(_on_battle_resolved):
		bus.battle_resolved.connect(_on_battle_resolved)
	if bus.has_signal("spy_mission_resolved") and not bus.spy_mission_resolved.is_connected(_on_spy_resolved):
		bus.spy_mission_resolved.connect(_on_spy_resolved)
	if bus.has_signal("village_conquered") and not bus.village_conquered.is_connected(_on_village_conquered):
		bus.village_conquered.connect(_on_village_conquered)


func _on_game_event() -> void:
	refresh_quests(false)


func _on_resources_event(_vid: int) -> void:
	if _elapsed_sec - _last_res_refresh_sec < 2.0 and _elapsed_sec >= _last_res_refresh_sec:
		return
	_last_res_refresh_sec = _elapsed_sec
	refresh_quests(false)


func _on_building_completed(_vid: int, _key: String, _lvl: int) -> void:
	refresh_quests(true)


func _on_research_completed(_vid: int, _u_key: String) -> void:
	refresh_quests(true)


func _on_unit_trained(vid: int, u_key: String, count: int) -> void:
	var gs := _gs()
	if gs != null and _is_player_village_id(gs, vid):
		var q_data := _ensure_quest_data(gs)
		var stats: Dictionary = q_data["stats"]
		var total_u := _count_player_unit(u_key, gs)
		var peak_k := "peak_" + u_key
		stats[peak_k] = maxi(int(stats.get(peak_k, 0)), maxi(total_u, count))
	refresh_quests(true)


func _on_army_sent(movement) -> void:
	if typeof(movement) != TYPE_DICTIONARY:
		return
	var mv := movement as Dictionary
	var gs := _gs()
	if gs == null:
		return
	var from_id := int(mv.get("from_village_id", mv.get("village_id", -1)))
	if not _is_player_village_id(gs, from_id):
		return
	_record_movement_stat(gs, mv)
	refresh_quests(true)


func _on_battle_resolved(ev) -> void:
	if typeof(ev) != TYPE_DICTIONARY:
		return
	var d := ev as Dictionary
	var gs := _gs()
	if gs == null:
		return
	var vid := int(d.get("village_id", d.get("from_village_id", -1)))
	if _is_player_village_id(gs, vid):
		var q_data := _ensure_quest_data(gs)
		var stats: Dictionary = q_data["stats"]
		if bool(d.get("is_raid", false)):
			stats["raids_resolved"] = int(stats.get("raids_resolved", 0)) + 1
		else:
			stats["attacks_resolved"] = int(stats.get("attacks_resolved", 0)) + 1
			stats["raids_resolved"] = int(stats.get("raids_resolved", 0)) + 1
	refresh_quests(true)


func _on_spy_resolved(ev) -> void:
	if typeof(ev) != TYPE_DICTIONARY:
		return
	var d := ev as Dictionary
	var gs := _gs()
	if gs == null:
		return
	var vid := int(d.get("village_id", d.get("from_village_id", -1)))
	if _is_player_village_id(gs, vid):
		var q_data := _ensure_quest_data(gs)
		var stats: Dictionary = q_data["stats"]
		stats["spies_resolved"] = int(stats.get("spies_resolved", 0)) + 1
	refresh_quests(true)


func _on_village_conquered(vid: int, new_owner_name: String) -> void:
	var gs := _gs()
	if gs == null:
		return
	var p_name := str(gs.player.get("name", ""))
	if (not p_name.is_empty() and new_owner_name == p_name) or _is_player_village_id(gs, vid):
		var q_data := _ensure_quest_data(gs)
		var stats: Dictionary = q_data["stats"]
		stats["villages_conquered"] = int(stats.get("villages_conquered", 0)) + 1
	refresh_quests(true)


func _process(delta: float) -> void:
	_elapsed_sec += delta

	if _toast_panel != null and _toast_panel.visible and _elapsed_sec >= _toast_until_sec:
		_toast_panel.hide()

	if DisplayServer.get_name() == "headless" and not quest_enabled_in_headless:
		if visible:
			visible = false
		return

	_hud_check_accum += maxf(delta, 0.0)
	if _hud_check_accum >= 0.25:
		_hud_check_accum = 0.0
		var should_show := is_quest_hud_visible()
		if visible != should_show:
			visible = should_show
			if should_show:
				_sync_live_positions()
				refresh_quests(true)

		if should_show or (_toast_panel != null and _toast_panel.visible):
			var loop := Engine.get_main_loop()
			var cur_sid := 0
			if loop is SceneTree and (loop as SceneTree).current_scene != null:
				cur_sid = (loop as SceneTree).current_scene.get_instance_id()
			var anchor_y := _get_top_anchor_y()
			if cur_sid != _last_scene_id or absf(anchor_y - _last_top_y) > 0.5:
				_last_scene_id = cur_sid
				_sync_live_positions()

	if visible and _tracker_panel != null:
		# Paneli ve başlığı yalnızca hazır ödül varsa önbellekli bayrak üzerinden parlat
		_update_claimable_pulse(delta)


func _update_claimable_pulse(delta: float = 0.0) -> void:
	if _btn_header == null or _header_badge == null:
		return
	if not _has_claimable_quest:
		if _badge_tinted:
			_header_badge.modulate = Color(1, 1, 1, 1)
			_badge_tinted = false
		_pulse_accum = 0.0
		return
	_pulse_accum += maxf(delta, 0.0)
	if _pulse_accum < 0.066 and _badge_tinted:
		return
	_pulse_accum = 0.0
	var w := 0.78 + 0.22 * sin(_elapsed_sec * 5.2)
	_header_badge.modulate = Color(w, 1.0, w, 1.0)
	_badge_tinted = true


# =============================================================================
#  SORGULAR VE DURUM YÖNETİMİ
# =============================================================================

func is_quest_hud_visible() -> bool:
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return false
	var st := loop as SceneTree
	var cur := st.current_scene
	if cur == null and st.root.get_child_count() > 0:
		cur = st.root.get_child(st.root.get_child_count() - 1)
	if cur == null or str(cur.name) != "Village":
		return false

	var gs := _gs()
	if gs == null or not gs.has_active_village():
		return false

	if not bool(gs.player.get("tutorial_completed", false)):
		return false

	var tm := _tm()
	if tm != null and tm.has_method("is_tutorial_active") and tm.is_tutorial_active():
		return false

	# BuildingPanel açıkken bile arka planda çakışmaması için: BuildingPanel üstte zaten kapatılana kadar modal yoksaTracker gösterilir; BuildingPanel tam panel ise gizlemek daha temiz!
	var bp = cur.get("building_panel")
	if bp != null and bp.visible:
		return false

	return true


func is_point_over_ui(pos: Vector2) -> bool:
	if not visible:
		return false
	if _detail_modal != null and _detail_modal.visible:
		return true
	if _tracker_panel != null and _tracker_panel.visible and _tracker_panel.get_global_rect().has_point(pos):
		return true
	return false


func is_expanded() -> bool:
	return _expanded


func set_expanded(p_expanded: bool) -> void:
	_expanded = p_expanded
	refresh_quests(true)


func get_all_quest_defs(gs_override: Node = null) -> Array:
	var gs := gs_override if gs_override != null else _gs()
	if gs != null and bool(gs.player.get("tutorial_skipped", false)):
		return TUTORIAL_QUEST_DEFS + QUEST_DEFS
	return QUEST_DEFS


func _ensure_quest_data(gs: Node) -> Dictionary:
	if not (gs.player.get("quests") is Dictionary):
		gs.player["quests"] = {"claimed": [], "stats": {}}
	var qd: Dictionary = gs.player["quests"]
	if not (qd.get("claimed") is Array):
		qd["claimed"] = []
	if not (qd.get("stats") is Dictionary):
		qd["stats"] = {}
	return qd


func _sync_live_stats(gs: Node) -> void:
	if gs == null:
		return
	var q_data := _ensure_quest_data(gs)
	var stats: Dictionary = q_data["stats"]

	for mv in gs.movements:
		if typeof(mv) == TYPE_DICTIONARY:
			var from_id := int((mv as Dictionary).get("from_village_id", (mv as Dictionary).get("village_id", -1)))
			if _is_player_village_id(gs, from_id):
				_record_movement_stat(gs, mv as Dictionary)

	# Raporlardan casus/yağma/saldırı geçmişini senkronize et
	var restart_cutoff := int(gs.player.get("restarted_unix", 0))
	for rep in gs.reports:
		if typeof(rep) != TYPE_DICTIONARY:
			continue
		var r := rep as Dictionary
		if restart_cutoff > 0 and int(r.get("unix", r.get("created_unix", 0))) < restart_cutoff:
			continue
		var r_type := str(r.get("type", ""))
		var owner_vid := int(r.get("village_id", r.get("from_village_id", -1)))
		if r_type == "spy" and _is_player_village_id(gs, owner_vid):
			stats["spies_resolved"] = maxi(1, int(stats.get("spies_resolved", 0)))
		elif r_type == "battle" and _is_player_village_id(gs, owner_vid):
			if bool(r.get("is_raid", false)):
				stats["raids_resolved"] = maxi(1, int(stats.get("raids_resolved", 0)))
			else:
				stats["attacks_resolved"] = maxi(1, int(stats.get("attacks_resolved", 0)))
				stats["raids_resolved"] = maxi(1, int(stats.get("raids_resolved", 0)))

	# Peak asker sayıları (askerler yola çıktığında sayaç geriye düşmesin)
	for u_key in ["spear", "axe", "spy", "snob"]:
		var u_k := str(u_key)
		var total_u := _count_player_unit(u_k, gs)
		var peak_k := "peak_" + u_k
		stats[peak_k] = maxi(int(stats.get(peak_k, 0)), total_u)


func _record_movement_stat(gs: Node, mv: Dictionary) -> void:
	var q_data := _ensure_quest_data(gs)
	var stats: Dictionary = q_data["stats"]
	if not (stats.get("counted_movement_ids") is Array):
		stats["counted_movement_ids"] = []
	var seen: Array = stats["counted_movement_ids"]

	var mv_id := str(mv.get("id", ""))
	if mv_id.is_empty() or mv_id == "0":
		mv_id = "%s_%d_%d_%d" % [
			str(mv.get("type", "")),
			int(mv.get("from_village_id", -1)),
			int(mv.get("to_village_id", -1)),
			int(mv.get("depart_unix", 0))
		]
	if seen.has(mv_id):
		return
	seen.append(mv_id)
	if seen.size() > 200:
		seen.remove_at(0)

	var m_type := str(mv.get("type", ""))
	match m_type:
		"spy":
			stats["spies_sent"] = int(stats.get("spies_sent", 0)) + 1
		"raid":
			stats["raids_sent"] = int(stats.get("raids_sent", 0)) + 1
		"attack":
			stats["attacks_sent"] = int(stats.get("attacks_sent", 0)) + 1
			stats["raids_sent"] = int(stats.get("raids_sent", 0)) + 1


func get_quest_def(quest_id: String) -> Dictionary:
	for q in get_all_quest_defs():
		if str(q.get("id", "")) == quest_id:
			return q
	return {}


func get_quest_progress(quest_id: String, gs_override: Node = null, skip_sync: bool = false) -> Dictionary:
	var gs := gs_override if gs_override != null else _gs()
	var q := get_quest_def(quest_id)
	if q.is_empty() or gs == null or not gs.has_active_village():
		return {"current": 0, "target": 1, "completed": false, "claimed": false}

	if not skip_sync:
		_sync_live_stats(gs)
	var q_data := _ensure_quest_data(gs)
	var claimed_arr: Array = q_data["claimed"]
	var stats: Dictionary = q_data["stats"]
	var is_claimed := claimed_arr.has(quest_id)

	var p_vills := _player_villages(gs)
	var active_v: Dictionary = gs.get_active_village()
	var bld: Dictionary = active_v.get("buildings", {})

	var target: int = maxi(1, int(q.get("target", 1)))
	var current: int = 0
	var c_type := str(q.get("check_type", ""))

	match c_type:
		"wood_stone_levels":
			var w_ok := 1 if _max_building_level(p_vills, "wood") >= 3 else 0
			var s_ok := 1 if _max_building_level(p_vills, "stone") >= 2 else 0
			current = w_ok + s_ok
		"building_level":
			var bk := str(q.get("building_key", ""))
			current = mini(target, _max_building_level(p_vills, bk))
		"storage_farm_3":
			var st3 := 1 if _max_building_level(p_vills, "storage") >= 3 else 0
			var fm3 := 1 if _max_building_level(p_vills, "farm") >= 3 else 0
			current = st3 + fm3
		"storage_farm_4":
			var st_ok := 1 if _max_building_level(p_vills, "storage") >= 4 else 0
			var fm_ok := 1 if _max_building_level(p_vills, "farm") >= 4 else 0
			current = st_ok + fm_ok
		"res_all_level":
			var rl := int(q.get("req_level", 6))
			var rw_ok := 1 if _max_building_level(p_vills, "wood") >= rl else 0
			var rs_ok := 1 if _max_building_level(p_vills, "stone") >= rl else 0
			var ri_ok := 1 if _max_building_level(p_vills, "iron") >= rl else 0
			current = rw_ok + rs_ok + ri_ok
		"unit_prereq":
			var req_b := maxi(1, int(q.get("req_barracks", 1)))
			var uk_p := str(q.get("unit_key", ""))
			var b_ok := 1 if _max_building_level(p_vills, "barracks") >= req_b else 0
			var r_ok := 1 if _any_village_researched(p_vills, uk_p) else 0
			current = b_ok + r_ok
		"in_alliance":
			var pname_a := str(gs.player.get("name", ""))
			var al := AllianceModelScript.get_player_alliance({"alliances": gs.alliances}, pname_a)
			current = 0 if al.is_empty() else 1
		"wall_farm_mid":
			var w_ok := 1 if _max_building_level(p_vills, "wall") >= 5 else 0
			var f_ok := 1 if _max_building_level(p_vills, "farm") >= 8 else 0
			current = w_ok + f_ok
		"storage_farm_12":
			var st12 := 1 if _max_building_level(p_vills, "storage") >= 12 else 0
			var fm12 := 1 if _max_building_level(p_vills, "farm") >= 12 else 0
			current = st12 + fm12
		"unit_researched":
			var uk_res := str(q.get("unit_key", ""))
			current = 1 if _any_village_researched(p_vills, uk_res) else 0
		"building_min":
			var bk := str(q.get("building_key", ""))
			var min_lvl := int(q.get("min_level", 1))
			current = 1 if _max_building_level(p_vills, bk) >= min_lvl else 0
		"infantry_count":
			current = mini(target, _count_player_unit("spear", gs) + _count_player_unit("sword", gs) + _count_player_unit("axe", gs))
		"spy_prereq":
			var b4 := 1 if _max_building_level(p_vills, "barracks") >= 4 else 0
			var res_spy := 1 if _any_village_researched(p_vills, "spy") else 0
			current = b4 + res_spy
		"unit_count_peak":
			var uk := str(q.get("unit_key", ""))
			var live_u := _count_player_unit(uk, gs)
			var peak_u := int(stats.get("peak_" + uk, 0))
			current = mini(target, maxi(live_u, peak_u))
		"stat_min":
			var sk := str(q.get("stat_key", ""))
			var val := 0
			match sk:
				"spies_total":
					val = maxi(int(stats.get("spies_sent", 0)), int(stats.get("spies_resolved", 0)))
				"raids_total":
					val = maxi(int(stats.get("raids_sent", 0)), int(stats.get("raids_resolved", 0)))
				"attacks_total":
					val = maxi(int(stats.get("attacks_sent", 0)), int(stats.get("attacks_resolved", 0)))
				_:
					val = int(stats.get(sk, 0))
			current = mini(target, val)
		"axe_bow_count":
			current = mini(target, _count_player_unit("axe", gs) + _count_player_unit("bow", gs))
		"cavalry_count":
			current = mini(target, _count_player_unit("light", gs) + _count_player_unit("heavy", gs))
		"siege_count":
			current = mini(target, _count_player_unit("ram", gs) + _count_player_unit("kata", gs))
		"gold_armour_made":
			var g_count := 0
			for v in p_vills:
				g_count += maxi(int((v as Dictionary).get("gold_armour", 0)), int((v as Dictionary).get("gold_armour_made", 0)))
			current = mini(target, g_count)
		"conquer_village":
			var conq := maxi(int(stats.get("villages_conquered", 0)), 1 if p_vills.size() >= 2 else 0)
			current = mini(target, conq)
		_:
			var fallback_bk := str(q.get("building_key", ""))
			if not fallback_bk.is_empty():
				current = mini(target, int(bld.get(fallback_bk, 0)))

	return {
		"current": current,
		"target": target,
		"completed": current >= target,
		"claimed": is_claimed,
	}


func get_visible_quests(gs_override: Node = null) -> Array:
	var gs := gs_override if gs_override != null else _gs()
	if gs == null or not gs.has_active_village():
		return []
	_sync_live_stats(gs)
	var out: Array = []
	var q_data := _ensure_quest_data(gs)
	var claimed_arr: Array = q_data["claimed"]

	for q in get_all_quest_defs(gs):
		var qid := str(q.get("id", ""))
		if claimed_arr.has(qid):
			continue
		out.append({
			"def": q,
			"progress": get_quest_progress(qid, gs, true),
		})
		if out.size() >= 3:
			break
	return out


func claim_quest(quest_id: String, gs_override: Node = null) -> bool:
	var gs := gs_override if gs_override != null else _gs()
	if gs == null or not gs.has_active_village():
		return false

	var q := get_quest_def(quest_id)
	if q.is_empty():
		return false

	var prog := get_quest_progress(quest_id, gs)
	if bool(prog.get("claimed", false)) or not bool(prog.get("completed", false)):
		return false

	var q_data := _ensure_quest_data(gs)
	var claimed_arr: Array = q_data["claimed"]
	claimed_arr.append(quest_id)

	var v: Dictionary = gs.get_active_village()
	var rew: Dictionary = q.get("reward", {})
	var add_w := int(rew.get("wood", 0))
	var add_s := int(rew.get("stone", 0))
	var add_i := int(rew.get("iron", 0))
	var res: Dictionary = v.get("resources", {})
	res["wood"] = int(res.get("wood", 0)) + add_w
	res["stone"] = int(res.get("stone", 0)) + add_s
	res["iron"] = int(res.get("iron", 0)) + add_i
	v["resources"] = res

	var vid := int(v.get("id", -1))
	gs._emit_resources_changed(vid)
	gs._emit_state_changed()

	var sm := _sm()
	if sm != null and sm.has_method("save_game"):
		sm.save_game()

	_show_toast("🎁 Görev Ödülü Alındı: +%s Odun  +%s Taş  +%s Demir" % [
		_fmt_num(add_w), _fmt_num(add_s), _fmt_num(add_i)
	])

	if _open_modal_quest_id == quest_id:
		close_quest_modal()

	refresh_quests(true)
	return true


# =============================================================================
#  UI OLUŞTURMA & YENİLEME
# =============================================================================

func _build_ui() -> void:
	if _ui_built:
		return
	_ui_built = true

	_root_ctrl = Control.new()
	_root_ctrl.name = "QuestRoot"
	_root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root_ctrl)

	# Sol üst panel (BtnAlliance'ın tam ters tarafı: left=20, top=bar_h+12)
	_tracker_panel = VBoxContainer.new()
	_tracker_panel.name = "QuestTrackerPanel"
	_tracker_panel.position = Vector2(20.0, _get_top_anchor_y())
	_tracker_panel.custom_minimum_size = Vector2(400.0, 0.0)
	_tracker_panel.size = Vector2(400.0, 60.0)
	_tracker_panel.add_theme_constant_override("separation", 6)
	_tracker_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_ctrl.add_child(_tracker_panel)

	_btn_header = Button.new()
	_btn_header.name = "BtnQuestHeader"
	_btn_header.custom_minimum_size = Vector2(400.0, 56.0)
	_btn_header.text = ""
	var h_sb := StyleBoxFlat.new()
	h_sb.bg_color = Color(0.08, 0.06, 0.09, 0.94)
	h_sb.border_color = Color(0.92, 0.76, 0.34, 0.98)
	h_sb.set_border_width_all(2)
	h_sb.set_corner_radius_all(14)
	h_sb.shadow_color = Color(0, 0, 0, 0.55)
	h_sb.shadow_size = 8
	var h_hover := h_sb.duplicate() as StyleBoxFlat
	h_hover.bg_color = Color(0.14, 0.11, 0.16, 0.98)
	h_hover.border_color = Color(1.0, 0.88, 0.48, 1.0)
	_btn_header.add_theme_stylebox_override("normal", h_sb)
	_btn_header.add_theme_stylebox_override("hover", h_hover)
	_btn_header.add_theme_stylebox_override("pressed", h_hover)
	_btn_header.pressed.connect(func():
		set_expanded(not _expanded)
	)
	_tracker_panel.add_child(_btn_header)

	var h_row := HBoxContainer.new()
	h_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	h_row.offset_left = 10
	h_row.offset_right = -12
	h_row.add_theme_constant_override("separation", 8)
	h_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_btn_header.add_child(h_row)

	_header_icon = TextureRect.new()
	_header_icon.texture = TexQuestIcon
	_header_icon.custom_minimum_size = Vector2(40, 40)
	_header_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_header_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_header_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_header_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h_row.add_child(_header_icon)

	_header_title = Label.new()
	_header_title.text = "GÖREVLER"
	_header_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_header_title.add_theme_font_override("font", FontNunitoBold)
	_header_title.add_theme_font_size_override("font_size", 25)
	_header_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.48))
	_header_title.add_theme_constant_override("outline_size", 2)
	_header_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_header_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h_row.add_child(_header_title)

	_header_badge = Label.new()
	_header_badge.name = "HeaderBadge"
	_header_badge.text = "0/%d" % QUEST_DEFS.size()
	_header_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_header_badge.add_theme_font_override("font", FontNunitoBold)
	_header_badge.add_theme_font_size_override("font_size", 23)
	_header_badge.add_theme_color_override("font_color", Color(0.85, 0.94, 1.0))
	var b_sb := StyleBoxFlat.new()
	b_sb.bg_color = Color(0.16, 0.24, 0.36, 0.95)
	b_sb.border_color = Color(0.48, 0.72, 0.95, 0.85)
	b_sb.set_border_width_all(1)
	b_sb.set_corner_radius_all(8)
	b_sb.content_margin_left = 8
	b_sb.content_margin_right = 8
	b_sb.content_margin_top = 2
	b_sb.content_margin_bottom = 2
	_header_badge.add_theme_stylebox_override("normal", b_sb)
	_header_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h_row.add_child(_header_badge)

	_header_chevron = Label.new()
	_header_chevron.text = "▼"
	_header_chevron.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_header_chevron.add_theme_font_override("font", FontNunitoBold)
	_header_chevron.add_theme_font_size_override("font_size", 22)
	_header_chevron.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45))
	_header_chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h_row.add_child(_header_chevron)

	# Aşağı açılan ilk 3 görev çekmecesi
	_drawer_panel = PanelContainer.new()
	_drawer_panel.name = "QuestDrawer"
	var d_sb := StyleBoxFlat.new()
	d_sb.bg_color = Color(0.06, 0.05, 0.08, 0.90)
	d_sb.border_color = Color(0.75, 0.58, 0.26, 0.85)
	d_sb.set_border_width_all(2)
	d_sb.set_corner_radius_all(14)
	d_sb.content_margin_left = 8
	d_sb.content_margin_right = 8
	d_sb.content_margin_top = 8
	d_sb.content_margin_bottom = 8
	d_sb.shadow_color = Color(0, 0, 0, 0.50)
	d_sb.shadow_size = 8
	_drawer_panel.add_theme_stylebox_override("panel", d_sb)
	_tracker_panel.add_child(_drawer_panel)

	_drawer_vbox = VBoxContainer.new()
	_drawer_vbox.name = "QuestList"
	_drawer_vbox.add_theme_constant_override("separation", 8)
	_drawer_panel.add_child(_drawer_vbox)

	for i in range(3):
		var slot := _create_quest_slot(i)
		_slot_nodes.append(slot)
		_drawer_vbox.add_child(slot["card"])

	_empty_banner = Label.new()
	_empty_banner.text = "👑 Tüm Krallık Görevleri Tamamlandı!"
	_empty_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_banner.add_theme_font_override("font", FontNunitoBold)
	_empty_banner.add_theme_font_size_override("font_size", 22)
	_empty_banner.add_theme_color_override("font_color", Color(0.55, 0.98, 0.65))
	_empty_banner.hide()
	_drawer_vbox.add_child(_empty_banner)

	# Baş Vezir Görev Detay Penceresi
	_build_detail_modal()

	# Ödül Bildirim Toast'u
	_toast_panel = PanelContainer.new()
	_toast_panel.name = "QuestRewardToast"
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.position = Vector2(210, 152)
	_toast_panel.custom_minimum_size = Vector2(660, 56)
	var t_sb := StyleBoxFlat.new()
	t_sb.bg_color = Color(0.10, 0.36, 0.16, 0.96)
	t_sb.border_color = Color(0.98, 0.84, 0.35, 1.0)
	t_sb.set_border_width_all(2)
	t_sb.set_corner_radius_all(14)
	t_sb.content_margin_left = 18
	t_sb.content_margin_right = 18
	t_sb.content_margin_top = 10
	t_sb.content_margin_bottom = 10
	_toast_panel.add_theme_stylebox_override("panel", t_sb)
	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_override("font", FontNunitoBold)
	_toast_label.add_theme_font_size_override("font_size", 24)
	_toast_label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.85))
	_toast_panel.add_child(_toast_label)
	_toast_panel.hide()
	_root_ctrl.add_child(_toast_panel)


func _create_quest_slot(idx: int) -> Dictionary:
	var card := PanelContainer.new()
	card.name = "QuestSlot_%d" % idx
	var c_sb := StyleBoxFlat.new()
	c_sb.bg_color = Color(0.13, 0.11, 0.15, 0.96)
	c_sb.border_color = Color(0.45, 0.38, 0.28, 0.90)
	c_sb.set_border_width_all(2)
	c_sb.set_corner_radius_all(10)
	c_sb.content_margin_left = 10
	c_sb.content_margin_right = 10
	c_sb.content_margin_top = 8
	c_sb.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", c_sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	card.add_child(vbox)

	# Üst satır: Görev Aç / Detay butonu + X/Y sayaç
	var top_btn := Button.new()
	top_btn.name = "QuestRowBtn_%d" % idx
	top_btn.flat = true
	top_btn.custom_minimum_size = Vector2(360, 34)
	top_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	vbox.add_child(top_btn)

	var top_hbox := HBoxContainer.new()
	top_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	top_hbox.add_theme_constant_override("separation", 6)
	top_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_btn.add_child(top_hbox)

	var title_lbl := Label.new()
	title_lbl.name = "TitleLabel"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.clip_text = true
	title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_override("font", FontNunitoBold)
	title_lbl.add_theme_font_size_override("font_size", 23)
	title_lbl.add_theme_color_override("font_color", Color(0.98, 0.94, 0.84))
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_hbox.add_child(title_lbl)

	var count_lbl := Label.new()
	count_lbl.name = "CountLabel"
	count_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_lbl.add_theme_font_override("font", FontNunitoBold)
	count_lbl.add_theme_font_size_override("font_size", 23)
	count_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.42))
	count_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_hbox.add_child(count_lbl)

	# İlerleme Çubuğu
	var pbar := ProgressBar.new()
	pbar.name = "ProgressBar"
	pbar.custom_minimum_size = Vector2(0, 10)
	pbar.show_percentage = false
	var pbg := StyleBoxFlat.new()
	pbg.bg_color = Color(0.06, 0.05, 0.08, 0.95)
	pbg.set_corner_radius_all(5)
	var pfg := StyleBoxFlat.new()
	pfg.bg_color = Color(0.92, 0.72, 0.24, 1.0)
	pfg.set_corner_radius_all(5)
	pbar.add_theme_stylebox_override("background", pbg)
	pbar.add_theme_stylebox_override("fill", pfg)
	pbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(pbar)

	# Alt bar: Ya "Detay için dokun (Vezir)" ipucu ya da "🎁 Ödülünü Al" butonu
	var hint_btn := Button.new()
	hint_btn.name = "DetailHintBtn_%d" % idx
	hint_btn.text = "📜 Vezir Açıklaması İçin Dokun ▸"
	hint_btn.flat = true
	hint_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	hint_btn.add_theme_font_override("font", FontNunitoSemiBold)
	hint_btn.add_theme_font_size_override("font_size", 20)
	hint_btn.add_theme_color_override("font_color", Color(0.72, 0.82, 0.94))
	vbox.add_child(hint_btn)

	var claim_btn := Button.new()
	claim_btn.name = "ClaimBtn_%d" % idx
	claim_btn.text = "🎁 Ödülünü Al"
	claim_btn.custom_minimum_size = Vector2(0, 38)
	claim_btn.add_theme_font_override("font", FontNunitoBold)
	claim_btn.add_theme_font_size_override("font_size", 23)
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.16, 0.56, 0.28, 1.0)
	csb.border_color = Color(0.98, 0.84, 0.36, 1.0)
	csb.set_border_width_all(2)
	csb.set_corner_radius_all(8)
	var c_hov := csb.duplicate() as StyleBoxFlat
	c_hov.bg_color = Color(0.22, 0.68, 0.36, 1.0)
	claim_btn.add_theme_stylebox_override("normal", csb)
	claim_btn.add_theme_stylebox_override("hover", c_hov)
	claim_btn.add_theme_stylebox_override("pressed", c_hov)
	claim_btn.add_theme_color_override("font_color", Color(1.0, 0.98, 0.90))
	claim_btn.hide()
	vbox.add_child(claim_btn)

	return {
		"card": card,
		"stylebox": c_sb,
		"pfg": pfg,
		"top_btn": top_btn,
		"hint_btn": hint_btn,
		"title_lbl": title_lbl,
		"count_lbl": count_lbl,
		"pbar": pbar,
		"claim_btn": claim_btn,
	}


func _build_detail_modal() -> void:
	_modal_backdrop = ColorRect.new()
	_modal_backdrop.name = "QuestModalBackdrop"
	_modal_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_backdrop.color = Color(0.02, 0.02, 0.04, 0.72)
	_modal_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_backdrop.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			close_quest_modal()
	)
	_modal_backdrop.hide()
	_root_ctrl.add_child(_modal_backdrop)

	_modal_center = CenterContainer.new()
	_modal_center.name = "QuestModalCenter"
	_modal_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal_center.hide()
	_root_ctrl.add_child(_modal_center)

	_detail_modal = PanelContainer.new()
	_detail_modal.name = "QuestDetailModal"
	_detail_modal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_detail_modal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_detail_modal.custom_minimum_size = Vector2(900, 0)
	var m_sb := StyleBoxFlat.new()
	m_sb.bg_color = Color(0.09, 0.08, 0.11, 0.98)
	m_sb.border_color = Color(0.95, 0.78, 0.34, 1.0)
	m_sb.set_border_width_all(3)
	m_sb.set_corner_radius_all(20)
	m_sb.content_margin_left = 26
	m_sb.content_margin_right = 26
	m_sb.content_margin_top = 22
	m_sb.content_margin_bottom = 22
	m_sb.shadow_color = Color(0, 0, 0, 0.75)
	m_sb.shadow_size = 18
	_detail_modal.add_theme_stylebox_override("panel", m_sb)
	_detail_modal.hide()
	_modal_center.add_child(_detail_modal)

	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 14)
	_detail_modal.add_child(mv)

	# Üst Başlık
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 12)
	mv.add_child(hdr)

	_modal_seal = TextureRect.new()
	_modal_seal.texture = TexRoyalSeal
	_modal_seal.custom_minimum_size = Vector2(54, 54)
	_modal_seal.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_modal_seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_modal_seal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hdr.add_child(_modal_seal)

	var t_vbox := VBoxContainer.new()
	t_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t_vbox.add_theme_constant_override("separation", 2)
	hdr.add_child(t_vbox)

	_modal_category = Label.new()
	_modal_category.add_theme_font_override("font", FontNunitoBold)
	_modal_category.add_theme_font_size_override("font_size", 22)
	_modal_category.add_theme_color_override("font_color", Color(0.65, 0.85, 1.0))
	t_vbox.add_child(_modal_category)

	_modal_title = Label.new()
	_modal_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modal_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_modal_title.add_theme_font_override("font", FontNunitoBold)
	_modal_title.add_theme_font_size_override("font_size", 32)
	_modal_title.add_theme_color_override("font_color", Color(1.0, 0.90, 0.52))
	t_vbox.add_child(_modal_title)

	_modal_close_top = Button.new()
	_modal_close_top.name = "ModalCloseTopBtn"
	_modal_close_top.text = "✕"
	_modal_close_top.custom_minimum_size = Vector2(52, 52)
	_modal_close_top.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_modal_close_top.add_theme_font_override("font", FontNunitoBold)
	_modal_close_top.add_theme_font_size_override("font_size", 28)
	_modal_close_top.pressed.connect(close_quest_modal)
	hdr.add_child(_modal_close_top)

	# Baş Vezir Açıklama Kutusu
	var speech_box := PanelContainer.new()
	var s_sb := StyleBoxFlat.new()
	s_sb.bg_color = Color(0.14, 0.12, 0.17, 0.98)
	s_sb.border_color = Color(0.75, 0.60, 0.30, 0.85)
	s_sb.set_border_width_all(2)
	s_sb.set_corner_radius_all(14)
	s_sb.content_margin_left = 16
	s_sb.content_margin_right = 16
	s_sb.content_margin_top = 14
	s_sb.content_margin_bottom = 14
	speech_box.add_theme_stylebox_override("panel", s_sb)
	mv.add_child(speech_box)

	var s_row := HBoxContainer.new()
	s_row.add_theme_constant_override("separation", 16)
	speech_box.add_child(s_row)

	var v_frame := PanelContainer.new()
	v_frame.custom_minimum_size = Vector2(128, 128)
	v_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var vf_sb := StyleBoxFlat.new()
	vf_sb.bg_color = Color(0.08, 0.06, 0.10, 1.0)
	vf_sb.border_color = Color(0.95, 0.78, 0.36, 1.0)
	vf_sb.set_border_width_all(2)
	vf_sb.set_corner_radius_all(14)
	v_frame.add_theme_stylebox_override("panel", vf_sb)
	s_row.add_child(v_frame)

	var v_tex := TextureRect.new()
	v_tex.texture = TexVizier
	v_tex.custom_minimum_size = Vector2(120, 120)
	v_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	v_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	v_frame.add_child(v_tex)

	var v_col := VBoxContainer.new()
	v_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v_col.add_theme_constant_override("separation", 6)
	s_row.add_child(v_col)

	var v_tag := Label.new()
	v_tag.text = "BAŞ VEZİRİN REHBERLİĞİ"
	v_tag.add_theme_font_override("font", FontNunitoBold)
	v_tag.add_theme_font_size_override("font_size", 22)
	v_tag.add_theme_color_override("font_color", Color(1.0, 0.84, 0.40))
	v_col.add_child(v_tag)

	_modal_vizier_text = RichTextLabel.new()
	_modal_vizier_text.name = "VizierExplanationLabel"
	_modal_vizier_text.bbcode_enabled = true
	_modal_vizier_text.fit_content = true
	_modal_vizier_text.scroll_active = false
	_modal_vizier_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modal_vizier_text.custom_minimum_size = Vector2(0, 110)
	_modal_vizier_text.add_theme_font_override("normal_font", FontNunitoSemiBold)
	_modal_vizier_text.add_theme_font_override("bold_font", FontNunitoBold)
	_modal_vizier_text.add_theme_font_size_override("normal_font_size", 26)
	_modal_vizier_text.add_theme_font_size_override("bold_font_size", 26)
	_modal_vizier_text.add_theme_color_override("default_color", Color(0.95, 0.92, 0.86))
	v_col.add_child(_modal_vizier_text)

	# Gereksinimler (Bina önkoşulları varsa canlı göster)
	_modal_req_label = RichTextLabel.new()
	_modal_req_label.name = "ModalReqLabel"
	_modal_req_label.bbcode_enabled = true
	_modal_req_label.fit_content = true
	_modal_req_label.scroll_active = false
	_modal_req_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modal_req_label.add_theme_font_override("normal_font", FontNunitoSemiBold)
	_modal_req_label.add_theme_font_override("bold_font", FontNunitoBold)
	_modal_req_label.add_theme_font_size_override("normal_font_size", 24)
	_modal_req_label.add_theme_font_size_override("bold_font_size", 24)
	_modal_req_label.add_theme_color_override("default_color", Color(0.86, 0.90, 0.98))
	mv.add_child(_modal_req_label)

	# İlerleme Satırı
	var prog_box := VBoxContainer.new()
	prog_box.add_theme_constant_override("separation", 6)
	mv.add_child(prog_box)

	_modal_prog_label = Label.new()
	_modal_prog_label.name = "ModalProgressLabel"
	_modal_prog_label.add_theme_font_override("font", FontNunitoBold)
	_modal_prog_label.add_theme_font_size_override("font_size", 26)
	_modal_prog_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	prog_box.add_child(_modal_prog_label)

	_modal_prog_bar = ProgressBar.new()
	_modal_prog_bar.custom_minimum_size = Vector2(0, 20)
	_modal_prog_bar.show_percentage = false
	var mp_bg := StyleBoxFlat.new()
	mp_bg.bg_color = Color(0.06, 0.05, 0.08, 0.95)
	mp_bg.border_color = Color(0.50, 0.42, 0.28, 0.85)
	mp_bg.set_border_width_all(1)
	mp_bg.set_corner_radius_all(10)
	var mp_fg := StyleBoxFlat.new()
	mp_fg.bg_color = Color(0.24, 0.78, 0.42, 1.0)
	mp_fg.set_corner_radius_all(9)
	_modal_prog_bar.add_theme_stylebox_override("background", mp_bg)
	_modal_prog_bar.add_theme_stylebox_override("fill", mp_fg)
	prog_box.add_child(_modal_prog_bar)

	# Ödül Rozetleri
	var rew_box := PanelContainer.new()
	var rw_sb := StyleBoxFlat.new()
	rw_sb.bg_color = Color(0.14, 0.13, 0.10, 0.95)
	rw_sb.border_color = Color(0.70, 0.56, 0.25, 0.85)
	rw_sb.set_border_width_all(1)
	rw_sb.set_corner_radius_all(12)
	rw_sb.content_margin_left = 14
	rw_sb.content_margin_right = 14
	rw_sb.content_margin_top = 10
	rw_sb.content_margin_bottom = 10
	rew_box.add_theme_stylebox_override("panel", rw_sb)
	mv.add_child(rew_box)

	_modal_reward_row = HBoxContainer.new()
	_modal_reward_row.add_theme_constant_override("separation", 18)
	rew_box.add_child(_modal_reward_row)

	# Dinamik Çoklu Hedef Yönlendirme Butonları (alt hedefler tamamlandıkça ayrı ayrı gizlenir)
	_modal_goto_box = VBoxContainer.new()
	_modal_goto_box.name = "ModalGotoBox"
	_modal_goto_box.add_theme_constant_override("separation", 10)
	_modal_goto_box.visible = false
	mv.add_child(_modal_goto_box)

	# Aksiyon Butonları
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 14)
	mv.add_child(btn_row)

	_modal_btn_goto = Button.new()
	_modal_btn_goto.name = "ModalGotoBtn"
	_modal_btn_goto.text = "🎯 Hedefe Git ➔"
	_modal_btn_goto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modal_btn_goto.custom_minimum_size = Vector2(0, 62)
	_modal_btn_goto.add_theme_font_override("font", FontNunitoBold)
	_modal_btn_goto.add_theme_font_size_override("font_size", 27)
	var g_sb := StyleBoxFlat.new()
	g_sb.bg_color = Color(0.18, 0.40, 0.68, 1.0)
	g_sb.border_color = Color(0.65, 0.85, 1.0, 1.0)
	g_sb.set_border_width_all(2)
	g_sb.set_corner_radius_all(14)
	_modal_btn_goto.add_theme_stylebox_override("normal", g_sb)
	_modal_btn_goto.add_theme_stylebox_override("hover", g_sb)
	_modal_btn_goto.add_theme_color_override("font_color", Color(1, 1, 1))
	_modal_btn_goto.pressed.connect(_on_modal_goto_pressed)
	btn_row.add_child(_modal_btn_goto)

	_modal_btn_claim = Button.new()
	_modal_btn_claim.name = "ModalClaimBtn"
	_modal_btn_claim.text = "🎁 Ödülünü Al"
	_modal_btn_claim.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modal_btn_claim.custom_minimum_size = Vector2(0, 62)
	_modal_btn_claim.add_theme_font_override("font", FontNunitoBold)
	_modal_btn_claim.add_theme_font_size_override("font_size", 28)
	var c_sb := StyleBoxFlat.new()
	c_sb.bg_color = Color(0.16, 0.58, 0.28, 1.0)
	c_sb.border_color = Color(0.98, 0.86, 0.36, 1.0)
	c_sb.set_border_width_all(2)
	c_sb.set_corner_radius_all(14)
	_modal_btn_claim.add_theme_stylebox_override("normal", c_sb)
	_modal_btn_claim.add_theme_stylebox_override("hover", c_sb)
	_modal_btn_claim.add_theme_color_override("font_color", Color(1, 0.98, 0.90))
	_modal_btn_claim.pressed.connect(func():
		if not _open_modal_quest_id.is_empty():
			claim_quest(_open_modal_quest_id)
	)
	btn_row.add_child(_modal_btn_claim)

	_modal_btn_close = Button.new()
	_modal_btn_close.name = "ModalCloseBtn"
	_modal_btn_close.text = "Kapat"
	_modal_btn_close.custom_minimum_size = Vector2(180, 62)
	_modal_btn_close.add_theme_font_override("font", FontNunitoBold)
	_modal_btn_close.add_theme_font_size_override("font_size", 26)
	_modal_btn_close.pressed.connect(close_quest_modal)
	btn_row.add_child(_modal_btn_close)
	_apply_detail_modal_widths()


func _apply_detail_modal_widths() -> float:
	var vp := get_viewport().get_visible_rect().size if get_viewport() != null else Vector2(1080, 1920)
	if vp.x < 100.0:
		vp = Vector2(1080, 1920)
	var w := clampf(vp.x - 80.0, 720.0, 940.0)
	var inner_w := w - 52.0
	if _detail_modal != null:
		_detail_modal.custom_minimum_size = Vector2(w, 0.0)
	if _modal_title != null:
		_modal_title.custom_minimum_size = Vector2(maxf(320.0, inner_w - 134.0), 0.0)
	if _modal_vizier_text != null:
		var vw := maxf(360.0, inner_w - 188.0)
		_modal_vizier_text.custom_minimum_size = Vector2(vw, 110.0)
		_modal_vizier_text.size.x = vw
	if _modal_req_label != null:
		var rw := maxf(400.0, inner_w - 8.0)
		_modal_req_label.custom_minimum_size = Vector2(rw, 0.0)
		_modal_req_label.size.x = rw
	return w


func _finalize_detail_modal_layout() -> void:
	if _detail_modal != null and _detail_modal.visible:
		_apply_detail_modal_widths()
		_detail_modal.reset_size()


func refresh_quests(force: bool = false) -> void:
	if not _ui_built:
		_build_ui()

	var gs := _gs()
	if gs == null or not gs.has_active_village():
		return

	var visible_list := get_visible_quests(gs)
	var q_data := _ensure_quest_data(gs)
	var claimed_cnt: int = (q_data["claimed"] as Array).size()

	var sig_parts: Array[String] = [str(_expanded), str(claimed_cnt)]
	var ready_cnt := 0
	for item in visible_list:
		var def: Dictionary = item["def"]
		var pr: Dictionary = item["progress"]
		if bool(pr.get("completed", false)):
			ready_cnt += 1
		sig_parts.append("%s:%d/%d" % [str(def["id"]), int(pr["current"]), int(pr["target"])])

	var sig := "|".join(sig_parts)
	_has_claimable_quest = (ready_cnt > 0)
	if not force and sig == _last_hud_sig:
		return
	_last_hud_sig = sig

	if _header_badge != null:
		if ready_cnt > 0:
			_header_badge.text = "🎁 %d Hazır" % ready_cnt
		else:
			_header_badge.text = "%d/%d" % [claimed_cnt, get_all_quest_defs(gs).size()]

	if _header_chevron != null:
		_header_chevron.text = "▲" if _expanded else "▼"

	if _drawer_panel != null:
		_drawer_panel.visible = _expanded

	if _expanded:
		var has_any := not visible_list.is_empty()
		_empty_banner.visible = not has_any
		for i in range(3):
			var slot: Dictionary = _slot_nodes[i]
			var card := slot["card"] as PanelContainer
			if i >= visible_list.size():
				card.hide()
				continue

			card.show()
			var def: Dictionary = visible_list[i]["def"]
			var pr: Dictionary = visible_list[i]["progress"]
			var qid := str(def["id"])
			var cur := int(pr["current"])
			var tgt := int(pr["target"])
			var completed := bool(pr["completed"])

			(slot["title_lbl"] as Label).text = "%s %s" % [str(def.get("icon", "📜")), str(def.get("title", ""))]
			var cnt_lbl := slot["count_lbl"] as Label
			cnt_lbl.text = "%d/%d" % [cur, tgt]
			cnt_lbl.add_theme_color_override("font_color", Color(0.46, 0.98, 0.56) if completed else Color(1.0, 0.86, 0.42))

			var pbar := slot["pbar"] as ProgressBar
			pbar.max_value = float(tgt)
			pbar.value = float(cur)
			var pfg := slot["pfg"] as StyleBoxFlat
			pfg.bg_color = Color(0.24, 0.85, 0.44, 1.0) if completed else Color(0.92, 0.72, 0.24, 1.0)

			var c_sb := slot["stylebox"] as StyleBoxFlat
			c_sb.border_color = Color(0.45, 0.92, 0.54, 1.0) if completed else Color(0.45, 0.38, 0.28, 0.90)
			c_sb.bg_color = Color(0.11, 0.18, 0.14, 0.96) if completed else Color(0.13, 0.11, 0.15, 0.96)

			var top_btn := slot["top_btn"] as Button
			var hint_btn := slot["hint_btn"] as Button
			var claim_btn := slot["claim_btn"] as Button

			_rebind_btn(top_btn, func(): open_quest_modal(qid))
			_rebind_btn(hint_btn, func(): open_quest_modal(qid))
			_rebind_btn(claim_btn, func(): claim_quest(qid))

			hint_btn.visible = not completed
			claim_btn.visible = completed

	if not _open_modal_quest_id.is_empty() and _detail_modal != null and _detail_modal.visible:
		open_quest_modal(_open_modal_quest_id)


func _rebind_btn(btn: BaseButton, cb: Callable) -> void:
	for conn in btn.pressed.get_connections():
		btn.pressed.disconnect(conn["callable"])
	btn.pressed.connect(cb)


func open_quest_modal(quest_id: String) -> void:
	if not _ui_built:
		_build_ui()
	var gs := _gs()
	var q := get_quest_def(quest_id)
	if q.is_empty() or gs == null or not gs.has_active_village():
		return

	_open_modal_quest_id = quest_id
	var pr := get_quest_progress(quest_id, gs)
	var cur := int(pr["current"])
	var tgt := int(pr["target"])
	var completed := bool(pr["completed"])

	_apply_detail_modal_widths()
	_modal_category.text = "%s  •  %s" % [str(q.get("icon", "📜")), str(q.get("category", "GÖREV"))]
	_modal_title.text = str(q.get("title", ""))
	_modal_vizier_text.text = str(q.get("vizier_desc", ""))

	# Dinamik bina gereksinim zinciri
	var req_text := ""
	var bk := str(q.get("building_key", ""))
	if bk.is_empty() and str(q.get("goto_type", "")) == "building":
		bk = str(q.get("goto_target", ""))
	if not bk.is_empty():
		var active_v: Dictionary = gs.get_active_village()
		var chain := RulesEngineScript.requirement_chain(active_v.get("buildings", {}), bk, 1)
		if chain.size() > 1:
			var parts: Array[String] = []
			for node in chain:
				if typeof(node) != TYPE_DICTIONARY:
					continue
				var rk := str((node as Dictionary).get("key", ""))
				if rk == bk:
					continue
				var rl := int((node as Dictionary).get("level", 1))
				var rc := int((node as Dictionary).get("current", 0))
				var rname := str(RulesEngineScript.building_data(rk).get("name", rk))
				var tick := "[color=#66FF88]✓[/color]" if rc >= rl else "[color=#FF9966]•[/color]"
				parts.append("%s %s Sv.%d (%d/%d)" % [tick, rname, rl, mini(rc, rl), rl])
			if not parts.is_empty():
				req_text = "[b]Önkoşullar:[/b]  " + "   |   ".join(parts)

	_modal_req_label.text = req_text
	_modal_req_label.visible = not req_text.is_empty()

	_modal_prog_label.text = "İlerleme Durumu:  %d / %d  %s" % [cur, tgt, "(Tamamlandı!)" if completed else ""]
	_modal_prog_label.add_theme_color_override("font_color", Color(0.45, 0.98, 0.56) if completed else Color(1.0, 0.88, 0.45))
	_modal_prog_bar.max_value = float(tgt)
	_modal_prog_bar.value = float(cur)

	for ch in _modal_reward_row.get_children():
		_modal_reward_row.remove_child(ch)
		ch.queue_free()

	var rw_title := Label.new()
	rw_title.text = "🎁 Görev Ödülü:"
	rw_title.add_theme_font_override("font", FontNunitoBold)
	rw_title.add_theme_font_size_override("font_size", 24)
	rw_title.add_theme_color_override("font_color", Color(1.0, 0.90, 0.50))
	_modal_reward_row.add_child(rw_title)

	var rew: Dictionary = q.get("reward", {})
	_add_reward_pill(IconWood, int(rew.get("wood", 0)))
	_add_reward_pill(IconStone, int(rew.get("stone", 0)))
	_add_reward_pill(IconIron, int(rew.get("iron", 0)))

	_modal_btn_claim.visible = completed
	var pending_actions := [] if completed else get_pending_navigation_actions(q, gs)
	for ch in _modal_goto_box.get_children():
		_modal_goto_box.remove_child(ch)
		ch.queue_free()

	if completed or pending_actions.is_empty():
		_modal_btn_goto.visible = false
		_modal_goto_box.visible = false
	elif pending_actions.size() == 1:
		var act0: Dictionary = pending_actions[0]
		_modal_btn_goto.text = str(act0.get("label", "🎯 Hedefe Git ➔"))
		_modal_btn_goto.visible = true
		_modal_goto_box.visible = false
	else:
		_modal_btn_goto.visible = false
		_modal_goto_box.visible = true
		for act in pending_actions:
			var act_dict: Dictionary = act
			var sub_btn := Button.new()
			sub_btn.text = str(act_dict.get("label", "🎯 Hedefe Git ➔"))
			sub_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sub_btn.custom_minimum_size = Vector2(0, 56)
			sub_btn.add_theme_font_override("font", FontNunitoBold)
			sub_btn.add_theme_font_size_override("font_size", 25)
			sub_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var sg_sb := StyleBoxFlat.new()
			sg_sb.bg_color = Color(0.18, 0.40, 0.68, 1.0)
			sg_sb.border_color = Color(0.65, 0.85, 1.0, 1.0)
			sg_sb.set_border_width_all(2)
			sg_sb.set_corner_radius_all(14)
			sub_btn.add_theme_stylebox_override("normal", sg_sb)
			sub_btn.add_theme_stylebox_override("hover", sg_sb)
			sub_btn.add_theme_color_override("font_color", Color(1, 1, 1))
			sub_btn.pressed.connect(func():
				close_quest_modal()
				_execute_navigation_action(act_dict)
			)
			_modal_goto_box.add_child(sub_btn)

	_modal_backdrop.show()
	if _modal_center != null:
		_modal_center.show()
	_detail_modal.show()
	_detail_modal.reset_size()
	call_deferred("_finalize_detail_modal_layout")


func _add_reward_pill(tex: Texture2D, amount: int) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	var tr := TextureRect.new()
	tr.texture = tex
	tr.custom_minimum_size = Vector2(30, 30)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hb.add_child(tr)
	var lbl := Label.new()
	lbl.text = _fmt_num(amount)
	lbl.add_theme_font_override("font", FontNunitoBold)
	lbl.add_theme_font_size_override("font_size", 25)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	hb.add_child(lbl)
	_modal_reward_row.add_child(hb)


func close_quest_modal() -> void:
	_open_modal_quest_id = ""
	if _modal_backdrop != null:
		_modal_backdrop.hide()
	if _modal_center != null:
		_modal_center.hide()
	if _detail_modal != null:
		_detail_modal.hide()


func _bname(b_key: String) -> String:
	return str(RulesEngineScript.building_data(b_key).get("name", b_key))


func _append_building_or_prereq_actions(out: Array, bld: Dictionary, bk: String, req_lvl: int) -> void:
	var cur_lvl := int(bld.get(bk, 0))
	var bname := _bname(bk)
	if cur_lvl < 1:
		var chain := RulesEngineScript.requirement_chain(bld, bk, 1)
		var unmet: Array = []
		for node in chain:
			if typeof(node) != TYPE_DICTIONARY:
				continue
			var rk := str((node as Dictionary).get("key", ""))
			if rk.is_empty() or rk == bk:
				continue
			var rl := int((node as Dictionary).get("level", 1))
			var rc := int((node as Dictionary).get("current", 0))
			if rc < rl:
				unmet.append({"building": rk, "level": rl, "current": rc})
		if unmet.is_empty():
			var missing := RulesEngineScript.missing_requirements(bld, bk, 1)
			for m in missing:
				if typeof(m) == TYPE_DICTIONARY:
					var mk := str((m as Dictionary).get("building", ""))
					var ml := int((m as Dictionary).get("level", 1))
					unmet.append({"building": mk, "level": ml, "current": int(bld.get(mk, 0))})
		if not unmet.is_empty():
			var added := 0
			for m in unmet:
				var mk := str((m as Dictionary).get("building", ""))
				var ml := int((m as Dictionary).get("level", 1))
				var mcur := int((m as Dictionary).get("current", 0))
				if mk.is_empty():
					continue
				out.append({
					"label": "🏛️ %s Binasına Git (Sv.%d/%d) ➔" % [_bname(mk), mcur, ml],
					"type": "building",
					"target": mk,
				})
				added += 1
				if added >= 3:
					break
			return
		out.append({
			"label": "🏛️ %s Binasına Git ➔" % bname,
			"type": "building",
			"target": bk,
		})
	elif cur_lvl < req_lvl:
		out.append({
			"label": "🏛️ %s Binasına Git (Sv.%d/%d) ➔" % [bname, cur_lvl, req_lvl],
			"type": "building",
			"target": bk,
		})


func get_pending_navigation_actions(quest_or_id, gs_override: Node = null) -> Array:
	var q: Dictionary = quest_or_id if typeof(quest_or_id) == TYPE_DICTIONARY else get_quest_def(str(quest_or_id))
	var gs := gs_override if gs_override != null else _gs()
	if q.is_empty() or gs == null or not gs.has_active_village():
		return []

	var p_vills := _player_villages(gs)
	var active_v: Dictionary = gs.get_active_village()
	var bld: Dictionary = active_v.get("buildings", {})
	var researched: Dictionary = active_v.get("researched", {})
	var c_type := str(q.get("check_type", ""))
	var out: Array = []

	match c_type:
		"wood_stone_levels":
			if _max_building_level(p_vills, "wood") < 3:
				out.append({
					"label": "🪓 Oduncu Kampına Git (Sv.%d/3) ➔" % int(bld.get("wood", 0)),
					"type": "building",
					"target": "wood",
				})
			if _max_building_level(p_vills, "stone") < 2:
				out.append({
					"label": "🪨 Taş Ocağına Git (Sv.%d/2) ➔" % int(bld.get("stone", 0)),
					"type": "building",
					"target": "stone",
				})
		"storage_farm_3":
			if _max_building_level(p_vills, "storage") < 3:
				out.append({
					"label": "🏛️ Depo Binasına Git (Sv.%d/3) ➔" % int(bld.get("storage", 0)),
					"type": "building",
					"target": "storage",
				})
			if _max_building_level(p_vills, "farm") < 3:
				out.append({
					"label": "🏛️ Değirmen Binasına Git (Sv.%d/3) ➔" % int(bld.get("farm", 0)),
					"type": "building",
					"target": "farm",
				})
		"storage_farm_4":
			if _max_building_level(p_vills, "storage") < 4:
				out.append({
					"label": "🏛️ Depo Binasına Git (Sv.%d/4) ➔" % int(bld.get("storage", 0)),
					"type": "building",
					"target": "storage",
				})
			if _max_building_level(p_vills, "farm") < 4:
				out.append({
					"label": "🏛️ Değirmen Binasına Git (Sv.%d/4) ➔" % int(bld.get("farm", 0)),
					"type": "building",
					"target": "farm",
				})
		"unit_researched":
			var u_rk := str(q.get("unit_key", "spear"))
			var u_req_dict: Dictionary = RulesEngineScript.unit_data(u_rk).get("requires", {}) if typeof(RulesEngineScript.unit_data(u_rk).get("requires")) == TYPE_DICTIONARY else {}
			var req_b_lvl := maxi(1, int(u_req_dict.get("barracks", 1)))
			if int(bld.get("barracks", 0)) < req_b_lvl:
				_append_building_or_prereq_actions(out, bld, "barracks", req_b_lvl)
			else:
				var u_rname := str(RulesEngineScript.unit_data(u_rk).get("name", u_rk))
				out.append({
					"label": "🔍 Kışla (%s Araştır) ➔" % u_rname,
					"type": "barracks_research",
					"target": u_rk,
				})
		"spy_prereq":
			if _max_building_level(p_vills, "barracks") < 4:
				out.append({
					"label": "🏛️ Kışla Geliştir (Sv.%d/4) ➔" % int(bld.get("barracks", 0)),
					"type": "building",
					"target": "barracks",
				})
			if not _any_village_researched(p_vills, "spy"):
				out.append({
					"label": "🔍 Kışla (Casus Araştır) ➔",
					"type": "barracks_research",
					"target": "spy",
				})
		"res_all_level":
			var rl := int(q.get("req_level", 6))
			if _max_building_level(p_vills, "wood") < rl:
				out.append({"label": "🪓 Oduncu Kampı (Sv.%d/%d) ➔" % [int(bld.get("wood", 0)), rl], "type": "building", "target": "wood"})
			if _max_building_level(p_vills, "stone") < rl:
				out.append({"label": "🪨 Taş Ocağı (Sv.%d/%d) ➔" % [int(bld.get("stone", 0)), rl], "type": "building", "target": "stone"})
			if _max_building_level(p_vills, "iron") < rl:
				out.append({"label": "⛏️ Maden Ocağı (Sv.%d/%d) ➔" % [int(bld.get("iron", 0)), rl], "type": "building", "target": "iron"})
		"unit_prereq":
			var req_b := maxi(1, int(q.get("req_barracks", 1)))
			var uk_p := str(q.get("unit_key", "spear"))
			if int(bld.get("barracks", 0)) < req_b:
				_append_building_or_prereq_actions(out, bld, "barracks", req_b)
			if not _any_village_researched(p_vills, uk_p):
				var uname_p := str(RulesEngineScript.unit_data(uk_p).get("name", uk_p))
				out.append({
					"label": "🔍 Kışla (%s Araştır) ➔" % uname_p,
					"type": "barracks_research",
					"target": uk_p,
				})
		"in_alliance":
			out.append({
				"label": "🛡️ İttifak Ekranına Git ➔",
				"type": "alliance",
				"target": "",
			})
		"wall_farm_mid":
			if _max_building_level(p_vills, "wall") < 5:
				_append_building_or_prereq_actions(out, bld, "wall", 5)
			if _max_building_level(p_vills, "farm") < 8:
				_append_building_or_prereq_actions(out, bld, "farm", 8)
		"storage_farm_12":
			if _max_building_level(p_vills, "storage") < 12:
				_append_building_or_prereq_actions(out, bld, "storage", 12)
			if _max_building_level(p_vills, "farm") < 12:
				_append_building_or_prereq_actions(out, bld, "farm", 12)
		"building_level":
			var bk := str(q.get("building_key", q.get("goto_target", "")))
			var req_lvl := int(q.get("target", 1))
			if _max_building_level(p_vills, bk) < req_lvl:
				_append_building_or_prereq_actions(out, bld, bk, req_lvl)
		"building_min":
			var bk := str(q.get("building_key", q.get("goto_target", "")))
			var req_lvl := int(q.get("min_level", 1))
			if _max_building_level(p_vills, bk) < req_lvl:
				_append_building_or_prereq_actions(out, bld, bk, req_lvl)
		"gold_armour_made":
			_append_building_or_prereq_actions(out, bld, "smith", 1)
		"unit_count_peak":
			var uk := str(q.get("unit_key", q.get("goto_target", "")))
			if uk == "snob":
				if int(bld.get("snob", 0)) < 1:
					_append_building_or_prereq_actions(out, bld, "snob", 1)
				else:
					if int(active_v.get("gold_armour", 0)) < 1 and int(bld.get("smith", 0)) >= 1:
						out.append({
							"label": "🛡️ Kuyumcu (Altın Zırh Üret) ➔",
							"type": "building",
							"target": "smith",
						})
					out.append({
						"label": "👑 Köşk Binasına Git (Kont Eğit) ➔",
						"type": "building",
						"target": "snob",
					})
			else:
				var u_req_dict2: Dictionary = RulesEngineScript.unit_data(uk).get("requires", {}) if typeof(RulesEngineScript.unit_data(uk).get("requires")) == TYPE_DICTIONARY else {}
				var req_b_lvl2 := maxi(1, int(u_req_dict2.get("barracks", 1)))
				if int(bld.get("barracks", 0)) < req_b_lvl2:
					_append_building_or_prereq_actions(out, bld, "barracks", req_b_lvl2)
				elif not uk.is_empty() and not bool(researched.get(uk, false)):
					var u_name := str(RulesEngineScript.unit_data(uk).get("name", uk))
					out.append({
						"label": "🔍 Kışla (%s Araştır) ➔" % u_name,
						"type": "barracks_research",
						"target": uk,
					})
				else:
					var u_name2 := str(RulesEngineScript.unit_data(uk).get("name", "Birim"))
					out.append({
						"label": "⚔️ Kışla (%s Eğit) ➔" % u_name2,
						"type": "barracks_train",
						"target": uk,
					})
		"infantry_count", "axe_bow_count", "cavalry_count", "siege_count":
			var gt := str(q.get("goto_target", "spear"))
			var gt_req: Dictionary = RulesEngineScript.unit_data(gt).get("requires", {}) if typeof(RulesEngineScript.unit_data(gt).get("requires")) == TYPE_DICTIONARY else {}
			var req_b_cnt := maxi(1, int(gt_req.get("barracks", 1)))
			if int(bld.get("barracks", 0)) < req_b_cnt:
				_append_building_or_prereq_actions(out, bld, "barracks", req_b_cnt)
			else:
				var uname := str(RulesEngineScript.unit_data(gt).get("name", "Kışla"))
				if not gt.is_empty() and not bool(researched.get(gt, false)):
					out.append({
						"label": "🔍 Kışla (%s Araştır) ➔" % uname,
						"type": "barracks_research",
						"target": gt,
					})
				else:
					out.append({
						"label": "⚔️ Kışla Binasına Git ➔",
						"type": str(q.get("goto_type", "barracks_train")),
						"target": gt,
					})
		"stat_min", "conquer_village":
			out.append({
				"label": "🗺️ Haritaya Git ➔",
				"type": "map",
				"target": "",
			})

	if out.is_empty():
		var pr := get_quest_progress(str(q.get("id", "")), gs)
		if not bool(pr.get("completed", false)):
			var fb_type := str(q.get("goto_type", "building"))
			var fb_target := str(q.get("goto_target", ""))
			var fb_lbl := "🗺️ Haritaya Git ➔" if fb_type == "map" else "🎯 Hedefe Git ➔"
			if fb_type == "building" and not fb_target.is_empty():
				fb_lbl = "🏛️ %s Binasına Git ➔" % _bname(fb_target)
			out.append({
				"label": fb_lbl,
				"type": fb_type,
				"target": fb_target,
			})
	return out


func _execute_navigation_action(action: Dictionary) -> void:
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return
	var st := loop as SceneTree
	var cur := st.current_scene
	if cur == null and st.root.get_child_count() > 0:
		cur = st.root.get_child(st.root.get_child_count() - 1)
	var gs := _gs()
	if gs == null or not gs.has_active_village():
		return

	var g_type := str(action.get("type", ""))
	var g_target := str(action.get("target", ""))

	match g_type:
		"building":
			if cur != null and cur.has_method("focus_building_for_tutorial"):
				cur.focus_building_for_tutorial(g_target)
			var bp = cur.get("building_panel") if cur != null else null
			if bp != null and bp.has_method("show_building"):
				bp.show_building(gs.get_active_village(), g_target)
		"barracks_research", "barracks_train":
			var v: Dictionary = gs.get_active_village()
			if cur != null and cur.has_method("focus_building_for_tutorial"):
				cur.focus_building_for_tutorial("barracks")
			var bp = cur.get("building_panel") if cur != null else null
			if bp != null and bp.has_method("show_building"):
				bp.show_building(v, "barracks")
				if int(v.get("buildings", {}).get("barracks", 0)) >= 1 and bp.has_method("switch_tab"):
					bp.switch_tab(1 if g_type == "barracks_research" else 2)
					if bp.has_method("scroll_to_unit_card") and not g_target.is_empty():
						bp.scroll_to_unit_card(g_target)
		"map":
			st.change_scene_to_file("res://scenes/WorldMap.tscn")
		"alliance":
			st.change_scene_to_file("res://scenes/Alliance.tscn")


func _on_modal_goto_pressed() -> void:
	if _open_modal_quest_id.is_empty():
		return
	var q := get_quest_def(_open_modal_quest_id)
	var actions := get_pending_navigation_actions(q) if not q.is_empty() else []
	close_quest_modal()
	if q.is_empty():
		return
	if not actions.is_empty():
		_execute_navigation_action(actions[0] as Dictionary)
	else:
		_execute_navigation_action({
			"type": str(q.get("goto_type", "")),
			"target": str(q.get("goto_target", ""))
		})


func _show_toast(msg: String) -> void:
	if _toast_panel == null or _toast_label == null:
		return
	_toast_label.text = msg
	_toast_panel.show()
	_toast_until_sec = _elapsed_sec + 3.8
	var vp := get_viewport().get_visible_rect().size
	if vp.x < 100.0:
		vp = Vector2(1080, 1920)
	_toast_panel.position = Vector2((vp.x - _toast_panel.size.x) * 0.5, _get_top_anchor_y())


# =============================================================================
#  YARDIMCILAR
# =============================================================================

func _safe_top_offset() -> float:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var gc = loop.root.get_node_or_null("GameConfig")
		if gc != null and gc.has_method("get_ios_safe_top"):
			return float(gc.get_ios_safe_top())
	return 0.0


func _get_top_anchor_y() -> float:
	var bar_h := 138.0 + _safe_top_offset()
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var st := loop as SceneTree
		var cur := st.current_scene
		if cur == null and st.root != null and st.root.get_child_count() > 0:
			cur = st.root.get_child(st.root.get_child_count() - 1)
		if cur != null:
			var rbar := cur.get_node_or_null("ResourceBar") as Control
			if rbar != null:
				if rbar.has_method("get_bar_height"):
					var bh := float(rbar.call("get_bar_height"))
					if bh > 10.0:
						bar_h = rbar.global_position.y + bh
				elif rbar.get_global_rect().size.y > 10.0:
					bar_h = rbar.get_global_rect().end.y
	return roundf(bar_h + 12.0)


func _sync_live_positions() -> void:
	var top_y := _get_top_anchor_y()
	_last_top_y = top_y
	if _tracker_panel != null:
		_tracker_panel.position = Vector2(20.0, top_y)
	if _toast_panel != null and _toast_panel.visible:
		var vp := get_viewport().get_visible_rect().size
		if vp.x < 100.0:
			vp = Vector2(1080, 1920)
		_toast_panel.position = Vector2(roundf((vp.x - _toast_panel.size.x) * 0.5), top_y)
	if _detail_modal != null and _detail_modal.visible:
		_apply_detail_modal_widths()
		_detail_modal.reset_size()


func _gs() -> Node:
	var loop := Engine.get_main_loop()
	return (loop as SceneTree).root.get_node_or_null("GameState") if loop is SceneTree else null


func _sm() -> Node:
	var loop := Engine.get_main_loop()
	return (loop as SceneTree).root.get_node_or_null("SaveManager") if loop is SceneTree else null


func _bus() -> Node:
	var loop := Engine.get_main_loop()
	return (loop as SceneTree).root.get_node_or_null("EventBus") if loop is SceneTree else null


func _tm() -> Node:
	var loop := Engine.get_main_loop()
	return (loop as SceneTree).root.get_node_or_null("TutorialManager") if loop is SceneTree else null


func _player_villages(gs: Node) -> Array:
	var p_name := str(gs.player.get("name", "")).strip_edges()
	var out: Array = []
	var has_named_human_village := false
	for item in gs.villages:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var v := item as Dictionary
		if bool(v.get("is_bot", false)) or bool(v.get("is_barbarian", false)):
			continue
		var vo := str(v.get("owner", "")).strip_edges()
		if not vo.is_empty() and vo != "Kral":
			has_named_human_village = true
		if not p_name.is_empty() and vo == p_name:
			out.append(v)
	if not p_name.is_empty() and (not out.is_empty() or has_named_human_village):
		return out
	for item in gs.villages:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var v := item as Dictionary
		if not bool(v.get("is_bot", true)) and not bool(v.get("is_barbarian", false)) and str(v.get("bonus_type", "")).is_empty():
			out.append(v)
	return out


func _is_player_village_id(gs: Node, vid: int) -> bool:
	for v in _player_villages(gs):
		if int((v as Dictionary).get("id", -1)) == vid:
			return true
	return false


func _max_building_level(p_vills: Array, b_key: String) -> int:
	var m := 0
	for v in p_vills:
		m = maxi(m, int((v as Dictionary).get("buildings", {}).get(b_key, 0)))
	return m


func _any_village_researched(p_vills: Array, u_key: String) -> bool:
	for v in p_vills:
		if RulesEngineScript.is_researched(v as Dictionary, u_key):
			return true
	return false


func _count_player_unit(u_key: String, gs: Node) -> int:
	var p_vills := _player_villages(gs)
	var total := 0
	for v in p_vills:
		total += int((v as Dictionary).get("units", {}).get(u_key, 0))
	# Yoldaki ordular da sayılsın
	for mv in gs.movements:
		if typeof(mv) != TYPE_DICTIONARY:
			continue
		var m := mv as Dictionary
		var fid := int(m.get("from_village_id", m.get("village_id", -1)))
		if _is_player_village_id(gs, fid):
			total += int(m.get("units", {}).get(u_key, 0))
	return total


func _fmt_num(val: int) -> String:
	var s := str(val)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0 and s[i - 1] != "-":
			out = "." + out
	return out
