extends SceneTree
## test_village_ui_flow.gd — Köy Arayüzü (UI), Seviye Yükseltme, Hammadde Azalması,
## Canlı İnşaat Kuyruğu (QueueHUD), Süre Geri Sayımı ve İptal/İade Uçtan Uca Testi.

const GameStateScript := preload("res://autoload/GameState.gd")
const GameDataScript := preload("res://autoload/GameData.gd")
const GameConfigScript := preload("res://autoload/GameConfig.gd")
const RulesEngineScript := preload("res://scripts/rules/RulesEngine.gd")
const EconomyAPIScript := preload("res://scripts/sim/economy/EconomyAPI.gd")
const GameLoopScript := preload("res://scripts/core/GameLoop.gd")

var _pass_count := 0
var _fail_count := 0

func _initialize() -> void:
	print("\n========================================================")
	print("  KÖY UI SEVİYE YÜKSELTME, SÜRE VE HAMMADDE TESTLERİ")
	print("========================================================\n")

	# 1. Veri katmanını yükle
	GameDataScript.get_singleton().load_all(true)

	# 2. Olay ve durum altyapısını başlat
	_setup_singletons()

	# 3. Testleri sırayla yürüt
	_run_all_tests()

	print("\n========================================================")
	print("  SONUÇ: %d BAŞARILI, %d HATALI" % [_pass_count, _fail_count])
	print("========================================================\n")

	if _fail_count > 0:
		print("❌ UI Testleri BAŞARISIZ oldu!")
	else:
		print("✅ TÜM KÖY UI FONKSİYONLARI VE TESTLERİ EKSİKSİZ BAŞARILI!")

	var sm = root.get_node_or_null("SaveManager")
	if sm != null and sm.has_method("delete_save"):
		sm.delete_save()
	quit()


func _assert_true(cond: bool, msg: String) -> void:
	if cond:
		_pass_count += 1
		print("  [PASS] %s" % msg)
	else:
		_fail_count += 1
		print("  [FAIL] ❌ %s" % msg)


func _setup_singletons() -> void:
	# EventBus
	if root.get_node_or_null("EventBus") == null:
		var eb_script = load("res://autoload/EventBus.gd")
		var eb = Node.new()
		eb.set_script(eb_script)
		eb.name = "EventBus"
		root.add_child(eb)

	# GameState
	if root.get_node_or_null("GameState") == null:
		var gs_script = load("res://autoload/GameState.gd")
		var gs = Node.new()
		gs.set_script(gs_script)
		gs.name = "GameState"
		root.add_child(gs)

	# GameClock
	if root.get_node_or_null("GameClock") == null:
		var gc_script = load("res://autoload/GameClock.gd")
		var gc = Node.new()
		gc.set_script(gc_script)
		gc.name = "GameClock"
		root.add_child(gc)

	# SaveManager
	if root.get_node_or_null("SaveManager") == null:
		var sm_script = load("res://autoload/SaveManager.gd")
		var sm = Node.new()
		sm.set_script(sm_script)
		sm.name = "SaveManager"
		root.add_child(sm)

	# GameData
	if root.get_node_or_null("GameData") == null:
		var gd = GameDataScript.get_singleton()
		if gd.get_parent() == null:
			gd.name = "GameData"
			root.add_child(gd)

	# GameConfig
	if root.get_node_or_null("GameConfig") == null:
		var gc_cfg = GameConfigScript.get_singleton()
		if gc_cfg.get_parent() == null:
			gc_cfg.name = "GameConfig"
			root.add_child(gc_cfg)


func _init_test_state() -> Dictionary:
	var v := {
		"id": 1,
		"name": "Şanlı Köy",
		"x": 100,
		"y": 100,
		"points": 100,
		"realm_of_power": 50,
		"resources": {
			"wood": 1000,
			"stone": 1000,
			"iron": 1000
		},
		"buildings": {
			"main": 1,
			"wood": 1,
			"stone": 1,
			"iron": 1,
			"storage": 1,
			"farm": 1,
			"hide": 0,
			"barracks": 0,
			"wall": 0,
			"market": 0,
			"stable": 0,
			"garage": 0,
			"snob": 0,
			"smith": 0,
			"statue": 0
		}
	}
	var state := {
		"player": {"name": "TestOyuncu"},
		"active_village_id": 1,
		"villages": [v],
		"queues": [],
		"world": {"sim_now_unix": 1000000}
	}
	var gs = root.get_node_or_null("GameState")
	gs.from_dict(state)
	return state


func _run_all_tests() -> void:
	_init_test_state()

	# Village sahnesini oluştur
	var village_scene = load("res://scenes/Village.tscn")
	var village_inst = village_scene.instantiate()
	root.add_child(village_inst)
	if village_inst._building_nodes.is_empty():
		village_inst._ready()

	print("\n--- Test 1: Başlangıç Köy UI Durumu ---")
	var rbar = village_inst.get_node("ResourceBar")
	var qhud = village_inst.get_node("QueueHUD")
	var bpanel = village_inst.get_node("BuildingPanel")

	_assert_true(rbar != null, "ResourceBar mevcut")
	_assert_true(qhud != null, "QueueHUD mevcut")
	_assert_true(bpanel != null, "BuildingPanel mevcut")
	_assert_true(not qhud.visible, "Başlangıçta kuyruk boş olduğundan QueueHUD gizli")
	_assert_true(not bpanel.visible, "Başlangıçta BuildingPanel gizli")

	var wood_lbl: Label = rbar.wood_label if rbar.wood_label != null else rbar.get_node_or_null("VBox/BottomRow/WoodPill/WoodLabel")
	var stone_lbl: Label = rbar.stone_label if rbar.stone_label != null else rbar.get_node_or_null("VBox/BottomRow/StonePill/StoneLabel")
	var iron_lbl: Label = rbar.iron_label if rbar.iron_label != null else rbar.get_node_or_null("VBox/BottomRow/IronPill/IronLabel")
	_assert_true(wood_lbl != null and wood_lbl.text == "1000", "ResourceBar odun başlangıç değeri 1000")
	_assert_true(stone_lbl != null and stone_lbl.text == "1000", "ResourceBar taş başlangıç değeri 1000")
	_assert_true(iron_lbl != null and iron_lbl.text == "1000", "ResourceBar demir başlangıç değeri 1000")

	print("\n--- Test 2: Bina Seçimi ve BuildingPanel Açılışı (Oduncu Kampı) ---")
	village_inst._on_building_selected("wood")
	_assert_true(bpanel.visible, "Bina tıklandığında BuildingPanel açıldı")

	var title_lbl: Label = bpanel.get_node("VBox/Header/TitleLabel")
	var level_lbl: Label = bpanel.get_node("VBox/Header/LevelLabel")
	var upgrade_btn: Button = bpanel.get_node("VBox/UpgradeButton")
	var cost_wood: Label = bpanel.get_node("VBox/CostContainer/WoodBox/Label")
	var time_lbl: Label = bpanel.get_node("VBox/MetaContainer/TimeLabel")
	var active_box: PanelContainer = bpanel.get_node("VBox/ActiveBuildBox")

	var exp_dur = int(ceil(RulesEngineScript.build_seconds("wood", 2)))
	_assert_true(title_lbl.text == "Oduncu Kampı", "Panel başlığı doğru: %s" % title_lbl.text)
	_assert_true(level_lbl.text.contains("Seviye: 1"), "Seviye 1 gösteriliyor: %s" % level_lbl.text)
	_assert_true(int(cost_wood.text) == 35, "Seviye 2 için gereken odun 35 (Görünen: %s)" % cost_wood.text)
	_assert_true(time_lbl.text.contains("%d sn" % exp_dur), "İnşa süresi %d sn (Görünen: %s)" % [exp_dur, time_lbl.text])
	_assert_true(not upgrade_btn.disabled, "Yükselt butonu aktif")
	_assert_true(upgrade_btn.text == "Yükselt (Seviye 2)", "Buton metni 'Yükselt (Seviye 2)' (Görünen: %s)" % upgrade_btn.text)
	_assert_true(not active_box.visible, "Henüz inşaat başlamadığından panel içi ActiveBuildBox gizli")

	print("\n--- Test 3: Yükseltme Tıklanması, Hammadde Düşüşü ve QueueHUD Görünümü ---")
	bpanel._on_upgrade_pressed()

	# 1. Hammadde düşüşü doğrulaması (RulesEngine maliyetleri: W=35, S=64, I=47)
	var exp_wood = 1000 - 35
	var exp_stone = 1000 - 64
	var exp_iron = 1000 - 47
	var gs = root.get_node("GameState")
	var v_curr = gs.get_active_village()
	var res_curr = v_curr.get("resources", {})
	_assert_true(int(res_curr.get("wood", 0)) == exp_wood, "Köy odunu 1000 -> %d'e düştü (Şu an: %d)" % [exp_wood, int(res_curr.get("wood", 0))])
	_assert_true(int(res_curr.get("stone", 0)) == exp_stone, "Köy taşı 1000 -> %d'e düştü (Şu an: %d)" % [exp_stone, int(res_curr.get("stone", 0))])
	_assert_true(int(res_curr.get("iron", 0)) == exp_iron, "Köy demiri 1000 -> %d'e düştü (Şu an: %d)" % [exp_iron, int(res_curr.get("iron", 0))])

	# 2. ResourceBar anlık güncelleme doğrulaması
	rbar.refresh()
	_assert_true(wood_lbl.text == str(exp_wood), "ResourceBar odun etiketi anında %d oldu (Görünen: %s)" % [exp_wood, wood_lbl.text])
	_assert_true(stone_lbl.text == str(exp_stone), "ResourceBar taş etiketi anında %d oldu (Görünen: %s)" % [exp_stone, stone_lbl.text])
	_assert_true(iron_lbl.text == str(exp_iron), "ResourceBar demir etiketi anında %d oldu (Görünen: %s)" % [exp_iron, iron_lbl.text])

	# 3. QueueHUD doğrulaması (BuildingPanel kapalıyken görünür)
	bpanel.hide()
	village_inst._update_queue_ui()
	_assert_true(qhud.visible, "İnşaat başlayınca QueueHUD görünür oldu")
	var q_title: Label = village_inst.queue_title if village_inst.queue_title != null else qhud.get_node("VBox/TitleLabel")
	var q_list: VBoxContainer = village_inst.queue_list if village_inst.queue_list != null else qhud.get_node("VBox/QueueList")
	_assert_true(q_title.text.contains("(1)"), "QueueHUD başlığında (1) yazıyor: %s" % q_title.text)
	_assert_true(q_list != null and q_list.get_child_count() == 1, "QueueHUD içinde tam 1 satır var")

	var row0: HBoxContainer = q_list.get_child(0)
	var row0_name: Label = row0.get_node("IconNameLabel")
	var row0_time: Label = row0.get_node("TimeLabel")
	var row0_cancel: Button = row0.get_node("CancelButton")
	_assert_true(row0_name.text.contains("Oduncu Kampı") and row0_name.text.contains("Sv. 2"), "Kuyruk satırı adı doğru: %s" % row0_name.text)
	_assert_true(row0_time.text.contains(":") and not row0_time.text.begins_with("-"), "Kalan süre geçerli sayaç formatında: %s" % row0_time.text)
	_assert_true(row0_cancel != null, "İptal butonu mevcut")

	# 4. BuildingPanel içi aktif inşaat paneli ve sonraki hedef doğrulaması
	bpanel.show_building(gs.get_active_village(), "wood")
	bpanel.refresh()
	_assert_true(active_box.visible, "BuildingPanel içi ActiveBuildBox artık görünür")
	var act_icon_lbl: Label = active_box.get_node("HBox/IconLabel")
	var act_time_lbl: Label = active_box.get_node("HBox/TimeLabel")
	_assert_true(act_icon_lbl.text.contains("Seviye 2"), "Panel içi aktif inşaat hedef seviyesi 2: %s" % act_icon_lbl.text)
	_assert_true(act_time_lbl.text.contains(":") and act_time_lbl.text.contains("Kalan:"), "Panel içi aktif inşaat kalan süre formatı doğru: %s" % act_time_lbl.text)
	_assert_true(level_lbl.text.contains("İnşaat: Sv. 2 ➔ Sıradaki: Sv. 3"), "Seviye etiketi sıradaki hedefi gösteriyor: %s" % level_lbl.text)
	_assert_true(upgrade_btn.text == "Sıraya Ekle (Seviye 3)", "Buton 'Sıraya Ekle (Seviye 3)' oldu: %s" % upgrade_btn.text)

	print("\n--- Test 4: İkinci İnşaatı Kuyruğa Ekleme (Seviye 3) ---")
	bpanel._on_upgrade_pressed()
	bpanel.hide()
	village_inst._update_queue_ui()
	_assert_true(gs.queues.size() == 2, "GameState kuyruğunda 2 iş var")
	_assert_true(q_title.text.contains("(2)"), "QueueHUD başlığında (2) yazıyor: %s" % q_title.text)
	_assert_true(q_list.get_child_count() == 2, "QueueHUD içinde 2 satır gösteriliyor")

	var row1: HBoxContainer = q_list.get_child(1)
	var row1_name: Label = row1.get_node("IconNameLabel")
	_assert_true(row1_name.text.contains("Oduncu Kampı") and row1_name.text.contains("Sv. 3"), "2. satır Seviye 3 işi: %s" % row1_name.text)

	var wood_after_q2 = int(gs.get_active_village().get("resources", {}).get("wood", 0))
	_assert_true(wood_after_q2 < exp_wood, "İkinci iş eklenince odun daha da azaldı (Kalan: %d)" % wood_after_q2)

	print("\n--- Test 5: Kuyruktan UI İle İptal Etme ve Taban Hammadde İadesi ---")
	var item2_id = int(gs.queues[1].get("id", -1))
	village_inst._on_cancel_activity_clicked("build", item2_id)

	_assert_true(gs.queues.size() == 1, "İptal sonrası kuyrukta 1 iş kaldı")
	village_inst._update_queue_ui()
	_assert_true(q_list.get_child_count() == 1, "QueueHUD listesi 1 satıra düştü")

	var wood_after_cancel = int(gs.get_active_village().get("resources", {}).get("wood", 0))
	_assert_true(wood_after_cancel == exp_wood, "İkinci iş iptal edilince taban odun tam iade edildi (%d): %d" % [exp_wood, wood_after_cancel])

	print("\n--- Test 6: Sürenin Tamamlanması (Advance) ve Seviye 1 -> 2 Yükselmesi ---")
	# Simülasyon saatini inşa süresinden fazla (120 sn) ilerletelim
	var g_loop = village_inst._game_loop
	if g_loop == null:
		g_loop = GameLoopScript.new()
		village_inst.add_child(g_loop)

	# 120 saniyelik simülasyon adımı işlet
	var events = g_loop.simulate(float(exp_dur + 5))
	_assert_true(events.size() > 0, "Simülasyon adımı olay üretti")

	var comp_ev: Dictionary = {}
	for ev in events:
		if str(ev.get("type", "")) == "building_completed":
			comp_ev = ev
			break
	_assert_true(not comp_ev.is_empty(), "building_completed olayı üretildi")
	_assert_true(int(comp_ev.get("level", 0)) == 2, "Tamamlanan bina seviyesi 2")

	# Köy sahnesi ve BuildingPanel güncelleme kontrolü
	var v_finished = gs.get_active_village()
	var wood_level = int(v_finished.get("buildings", {}).get("wood", 0))
	_assert_true(wood_level == 2, "Köy verisinde Oduncu Kampı Seviye 2 oldu! (Alınan: %d)" % wood_level)

	village_inst.refresh_all()
	village_inst._update_queue_ui()
	var node_dict = village_inst._building_nodes["wood"]
	var village_lvl_lbl: Label = node_dict["lvl"]
	_assert_true(village_lvl_lbl.text == "Sv. 2", "Köy ekranındaki Oduncu butonu etiketi 'Sv. 2' oldu! (Görünen: %s)" % village_lvl_lbl.text)
	_assert_true(not qhud.visible, "Tüm işler bitince QueueHUD otomatik kapandı")

	bpanel.refresh()
	_assert_true(not active_box.visible, "İnşaat bitince panel içi ActiveBuildBox gizlendi")
	_assert_true(level_lbl.text.contains("Seviye: 2"), "BuildingPanel seviye etiketi Seviye 2'yi gösteriyor: %s" % level_lbl.text)
	_assert_true(upgrade_btn.text == "Yükselt (Seviye 3)", "Buton artık 'Yükselt (Seviye 3)' oldu: %s" % upgrade_btn.text)

	print("\n--- Test 7: Önkoşullar ve Gereksinim Zinciri Arayüzü ---")
	village_inst._on_building_selected("snob") # Köşk (Önkoşul: Simyager 5, Kışla 5 ...)
	_assert_true(upgrade_btn.disabled, "Önkoşulları sağlanmayan Köşk için Yükselt butonu devredışı")
	_assert_true(upgrade_btn.text == "Önkoşullar Karşılanmadı", "Buton metni 'Önkoşullar Karşılanmadı'")

	var req_sec = bpanel.get_node("VBox/RequirementSection")
	var req_list = bpanel.get_node("VBox/RequirementSection/ReqScroll/ReqList")
	_assert_true(req_sec.visible, "Gereksinim zinciri bölümü görünür")
	_assert_true(req_list.get_child_count() > 0, "Eksik önkoşul binaları listelendi (Toplam: %d)" % req_list.get_child_count())

	# "Binaya Git" butonuna tıklama simülasyonu
	var first_req_row: HBoxContainer = req_list.get_child(0)
	var goto_btn: Button = first_req_row.get_child(1)
	_assert_true(goto_btn != null and goto_btn.text.contains("Binaya Git"), "Binaya Git butonu mevcut")
	goto_btn.pressed.emit()
	_assert_true(bpanel._current_key != "snob", "Binaya Git tıklandığında panel hedef binaya geçiş yaptı: %s" % bpanel._current_key)

	# Temizlik
	village_inst.queue_free()
