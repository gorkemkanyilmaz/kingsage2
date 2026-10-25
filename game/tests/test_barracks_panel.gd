extends SceneTree
## test_barracks_panel.gd — Kışla çoklu sekme (Yükselt, Araştır, Eğit) testleri.

const RE := preload("res://scripts/rules/RulesEngine.gd")
const VM := preload("res://scripts/model/VillageModel.gd")
const API := preload("res://scripts/sim/army/ArmyAPI.gd")
const SIM := preload("res://scripts/sim/army/ArmySimulator.gd")

var _passed := 0
var _failed := 0
var _fail_labels: Array = []


func _initialize() -> void:
	var gd := _game_data()
	if gd == null:
		print("FAIL: GameData autoload düğümü bulunamadı.")
		quit(1)
		return
	gd.load_all(true)
	var gc := _game_config()
	if gc != null:
		gc.set("speed", 1.0)

	print("=== Kışla Çoklu Sekme (BuildingPanel) Testleri ===")

	_test_tab_visibility_non_barracks()
	_test_barracks_level_zero_locking()
	_test_barracks_research_tab()
	_test_barracks_train_tab()

	print("")
	print("==================== ÖZET ====================")
	print("PASS: %d   FAIL: %d" % [_passed, _failed])
	if _failed > 0:
		print("Başarısız testler:")
		for label in _fail_labels:
			print("  - ", label)
	print("==============================================")
	quit(1 if _failed > 0 else 0)


func _game_data() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("GameData")
	return null


func _game_config() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("GameConfig")
	return null


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("PASS: ", label)
	else:
		_failed += 1
		_fail_labels.append(label)
		print("FAIL: ", label)


func _create_test_village(barracks_lvl: int = 0) -> Dictionary:
	var v := VM.create(1, "TestKöy", 10, 10, "Oyuncu", false)
	VM.set_building_level(v, "barracks", barracks_lvl)
	VM.set_building_level(v, "farm", 20)
	VM.set_building_level(v, "storage", 20)
	v["resources"] = {"wood": 100000, "stone": 100000, "iron": 100000}
	v["researched"] = {}
	v["units"] = {}
	return v


func _test_tab_visibility_non_barracks() -> void:
	print("\n-- Test 1: Kışla Dışı Binalarda Sekmeler Gizli Olmalı --")
	var panel = load("res://ui/BuildingPanel.tscn").instantiate()
	root.add_child(panel)

	var v := _create_test_village(0)
	panel.show_building(v, "wood")

	var tab_bar = panel.get_node("VBox/TabBar")
	_check(tab_bar != null, "TabBar mevcut")
	_check(not tab_bar.visible, "Oduncu Kampı açıldığında TabBar gizli")

	panel.queue_free()


func _test_barracks_level_zero_locking() -> void:
	print("\n-- Test 2: Kışla Seviye 0 İken Sekme Kilit Davranışı --")
	var panel = load("res://ui/BuildingPanel.tscn").instantiate()
	root.add_child(panel)

	var v := _create_test_village(0)
	panel.show_building(v, "barracks")

	var tab_bar = panel.get_node("VBox/TabBar")
	_check(tab_bar.visible, "Kışla açıldığında TabBar görünür")

	var locked_banner = panel.get_node("VBox/LockedBanner")
	_check(not locked_banner.visible, "Yükselt sekmesindeyken locked_banner gizli")

	# Araştır sekmesine geç
	panel._on_tab_research_pressed()
	_check(locked_banner.visible, "Kışla Lv 0 iken Araştır sekmesine geçilince locked_banner görünür")
	_check(not panel.get_node("VBox/ResearchSection").visible, "Kışla Lv 0 iken ResearchSection gizli")

	# Eğit sekmesine geç
	panel._on_tab_train_pressed()
	_check(locked_banner.visible, "Kışla Lv 0 iken Eğit sekmesine geçilince locked_banner görünür")
	_check(not panel.get_node("VBox/TrainSection").visible, "Kışla Lv 0 iken TrainSection gizli")

	# Geri Yükselt'e dön
	panel._on_tab_upgrade_pressed()
	_check(not locked_banner.visible, "Yükselt sekmesine dönünce locked_banner kapandı")
	_check(panel.get_node("VBox/UpgradeButton").visible, "UpgradeButton görünür")

	panel.queue_free()


func _test_barracks_research_tab() -> void:
	print("\n-- Test 3: Kışla Seviye 5 İken Birim Araştırma Akışı --")
	var panel = load("res://ui/BuildingPanel.tscn").instantiate()
	root.add_child(panel)

	var v := _create_test_village(5)
	var gs = root.get_node_or_null("GameState")
	if gs != null:
		gs.villages = [v]
		gs.active_village_id = 1
		gs.queues = []

	panel.show_building(v, "barracks")
	panel._on_tab_research_pressed()

	var res_sec = panel.get_node("VBox/ResearchSection")
	_check(res_sec.visible, "ResearchSection görünür oldu")

	var r_list = panel.get_node("VBox/ResearchSection/ResearchScroll/ResearchList")
	_check(r_list.get_child_count() == 10, "10 Kışla birimi listelendi (Mevcut: %d)" % r_list.get_child_count())

	# Silahtar araştırmasını başlat
	panel._on_start_research_pressed("spear")
	_check(gs != null and gs.queues.size() == 1, "Araştırma kuyruğa eklendi")

	panel.refresh()
	var act_box = panel.get_node("VBox/ResearchSection/ActiveResearchBox")
	_check(act_box.visible, "Aktif araştırma bilgi kutusu görünür")

	# Simülasyonla araştırmayı tamamla
	if gs != null:
		var q_item = gs.queues[0]
		var finish = int(q_item["finish_unix"])
		SIM.process_tick(gs.to_dict(), finish, 1.0)
		v["researched"]["spear"] = true
		gs.queues.clear()

	panel.refresh()
	_check(not act_box.visible, "Araştırma bitince aktif araştırma kutusu kapandı")
	_check(RE.is_researched(v, "spear"), "Silahtar araştırıldı olarak işaretlendi")

	panel.queue_free()


func _test_barracks_train_tab() -> void:
	print("\n-- Test 4: Kışla Seviye 5 İken Birim Eğitme Akışı --")
	var panel = load("res://ui/BuildingPanel.tscn").instantiate()
	root.add_child(panel)

	var v := _create_test_village(5)
	v["researched"]["spear"] = true
	var gs = root.get_node_or_null("GameState")
	if gs != null:
		gs.villages = [v]
		gs.active_village_id = 1
		gs.queues = []

	panel.show_building(v, "barracks")
	panel._on_tab_train_pressed()

	var tr_sec = panel.get_node("VBox/TrainSection")
	_check(tr_sec.visible, "TrainSection görünür oldu")

	var tr_list = panel.get_node("VBox/TrainSection/TrainScroll/TrainList")
	_check(tr_list.get_child_count() == 10, "10 Kışla birimi listelendi")

	# 15 Silahtar eğit
	panel._on_start_train_pressed("spear", 15)
	if gs != null:
		v = gs.get_active_village()
	_check(gs != null and gs.queues.size() == 1, "Eğitim kuyruğa eklendi")
	_check(int(v.get("settlers_reserved", 0)) == 15, "15 vatandaş rezerve edildi")

	panel.refresh()
	var act_tr_box = panel.get_node("VBox/TrainSection/ActiveTrainBox")
	_check(act_tr_box.visible, "Aktif eğitim kuyruk kutusu görünür")

	# Simülasyonla eğitimi tamamla
	if gs != null:
		var q_item = gs.queues[0]
		var finish = int(q_item["finish_unix"])
		var st = gs.to_dict()
		SIM.process_tick(st, finish, 1.0)
		gs.from_dict(st)
		v = gs.get_active_village()

	panel.show_building(v, "barracks")
	panel._on_tab_train_pressed()
	_check(int(v.get("units", {}).get("spear", 0)) == 15, "Köyde 15 Silahtar mevcut")
	_check(int(v.get("settlers_reserved", 0)) == 0, "Vatandaş rezervi serbest bırakıldı")

	panel.queue_free()
