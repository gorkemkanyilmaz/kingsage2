extends SceneTree
## test_tutorial.gd — Baş Vezir Başlangıç Rehberi (Tutorial) E2E doğrulama testi.

const VM := preload("res://scripts/model/VillageModel.gd")
const RE := preload("res://scripts/rules/RulesEngine.gd")

var _passed: int = 0
var _failed: int = 0
var _fail_labels: Array[String] = []
var _active_scene: Node = null


func _initialize() -> void:
	await _run_tests()
	print("")
	print("==================== TUTORIAL E2E ÖZET ====================")
	print("PASS: %d   FAIL: %d" % [_passed, _failed])
	if _failed > 0:
		print("Başarısız kontroller:")
		for lbl in _fail_labels:
			print("  - ", lbl)
	print("===========================================================")
	quit(1 if _failed > 0 else 0)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("PASS: ", label)
	else:
		_failed += 1
		_fail_labels.append(label)
		printerr("FAIL: ", label)


func _tick(frames: int = 3) -> void:
	for _i in range(frames):
		await process_frame


func _swap_scene(res_path: String) -> Node:
	if _active_scene != null and is_instance_valid(_active_scene):
		root.remove_child(_active_scene)
		_active_scene.queue_free()
		_active_scene = null
		await _tick(2)
	var packed := load(res_path) as PackedScene
	if packed == null:
		return null
	var inst := packed.instantiate()
	root.add_child(inst)
	_active_scene = inst
	await _tick(3)
	return inst


func _press_button(btn: BaseButton) -> void:
	if btn == null:
		return
	btn.emit_signal("pressed")


func _click_building(village: Node, b_key: String) -> void:
	var bv = village.call("get_building_view", b_key) if village.has_method("get_building_view") else null
	_check(bv != null, "Bina görünümü mevcut: %s" % b_key)
	if bv != null and bv.has_signal("clicked"):
		bv.emit_signal("clicked")
	elif village.has_method("_on_building_clicked"):
		village.call("_on_building_clicked", b_key)
	elif village.get("building_panel") != null:
		var gs := root.get_node("GameState")
		village.get("building_panel").call("show_building", gs.call("get_active_village"), b_key)
	await _tick(3)


func _run_tests() -> void:
	var gd := root.get_node_or_null("GameData")
	var gs := root.get_node_or_null("GameState")
	var tm := root.get_node_or_null("TutorialManager")
	var gc := root.get_node_or_null("GameConfig")

	_check(gd != null and gs != null and tm != null, "Gerekli autoload düğümleri yüklü")
	if gd == null or gs == null or tm == null:
		return

	gd.call("load_all", true)
	if gc != null:
		gc.set("speed", 1.0)

	# Yeni oyuncu durumu oluştur (is_bot = false)
	var v := VM.create(1, "Başkent", 100, 100, "TestLord", false)
	v["resources"] = {"wood": 1000, "stone": 1000, "iron": 1000}
	v["buildings"] = {"main": 1, "stone": 1, "wood": 1, "iron": 1, "farm": 1, "storage": 1, "barracks": 0}
	v["researched"] = {}
	v["units"] = {}

	gs.set("villages", [v])
	gs.set("active_village_id", 1)
	gs.set("queues", [])
	gs.set("player", {
		"name": "TestLord",
		"alliance_id": -1,
		"tutorial_step": 0,
		"tutorial_completed": false,
		"tutorial_reward_claimed": false,
	})
	gs.set("world", {
		"id": 1,
		"name": "Dünya 1",
		"map_width": 200,
		"map_height": 200,
		"speed": 1.0,
		"sim_now_unix": int(Time.get_unix_time_from_system()),
	})

	tm.set("tutorial_enabled_in_headless", true)
	tm.call("start_tutorial")

	# 1. Village yükle ve Step 0 -> Step 1 -> Step 2 geçişlerini doğrula
	var village := await _swap_scene("res://scenes/Village.tscn")
	_check(village != null, "Village.tscn yüklendi")
	_check(tm.call("is_tutorial_active"), "Başlangıç rehberi yeni oyuncuda aktif")
	_check(int(tm.call("get_current_step")) == 0, "Adım 0 (WELCOME_INTRO) başladı")

	var btn_next := tm.get("_btn_next") as Button
	var btn_speedup := tm.get("_btn_speedup") as Button
	_press_button(btn_next)
	await _tick(2)
	_check(int(tm.call("get_current_step")) == 1, "Adım 1 (RESOURCE_BAR_TOUR) geçildi")

	_press_button(btn_next)
	await _tick(2)
	_check(int(tm.call("get_current_step")) == 2, "Adım 2 (SELECT_MAIN_CASTLE) geçildi")

	# 2. Kale seç ve paneli kapat (Adım 2 -> 3 -> 4)
	await _click_building(village, "main")
	_check(int(tm.call("get_current_step")) == 3, "Adım 3 (INSPECT_MAIN_PANEL) geçildi")

	var bp := village.get("building_panel") as Control
	_check(bp != null and bp.visible, "Kale için BuildingPanel açıldı")
	var close_btn := bp.get_node_or_null("VBox/Header/CloseButton") as BaseButton
	_press_button(close_btn)
	await _tick(2)
	_check(int(tm.call("get_current_step")) == 4, "Adım 4 (SELECT_WOOD_CAMP) geçildi")

	# 3. Oduncu seç ve Sv.2'ye yükselt (Adım 4 -> 5 -> 6)
	await _click_building(village, "wood")
	_check(int(tm.call("get_current_step")) == 5, "Adım 5 (UPGRADE_WOOD_CAMP) geçildi")
	var upg_btn := bp.get_node_or_null("VBox/UpgradeButton") as BaseButton
	_press_button(upg_btn)
	await _tick(2)
	_check(btn_speedup != null and btn_speedup.visible, "Oduncu inşaatında Kraliyet Fermanı butonu göründü")
	_press_button(btn_speedup)
	await _tick(3)
	var active_v: Dictionary = gs.call("get_active_village")
	_check(int(active_v["buildings"].get("wood", 0)) >= 2, "Oduncu Sv.2 tamamlandı")
	_check(int(tm.call("get_current_step")) == 6, "Adım 6 (CHECK_BARRACKS_REQS) geçildi")

	# 4. Kışla tıkla -> Gereksinim zinciri -> Depo Sv.3 & Değirmen Sv.3 (Adım 6 -> 7 -> 8)
	if bp.visible:
		_press_button(close_btn)
		await _tick(2)
	await _click_building(village, "barracks")
	_check(int(tm.call("get_current_step")) == 7, "Adım 7 (COMPLETE_BARRACKS_PREREQS) geçildi")

	var goto_sto := bp.find_child("GotoBtn_storage", true, false) as BaseButton
	_check(goto_sto != null, "Kışla gereksinim zincirinde GotoBtn_storage butonu bulundu")
	_press_button(goto_sto)
	await _tick(2)
	_check(str(bp.get("_current_key")) == "storage", "GotoBtn_storage tıklanınca Depo paneline geçildi")

	# Depo Lv.1 -> Lv.2 -> Lv.3
	for target_lvl in [2, 3]:
		_press_button(upg_btn)
		await _tick(2)
		_press_button(btn_speedup)
		await _tick(2)
	active_v = gs.call("get_active_village")
	_check(int(active_v["buildings"].get("storage", 0)) >= 3, "Depo Sv.3 tamamlandı")

	# Değirmen'i kapatıp aç ve Lv.2 -> Lv.3 yap
	if bp.visible:
		_press_button(close_btn)
		await _tick(2)
	await _click_building(village, "farm")
	for target_lvl in [2, 3]:
		_press_button(upg_btn)
		await _tick(2)
		_press_button(btn_speedup)
		await _tick(2)
	active_v = gs.call("get_active_village")
	_check(int(active_v["buildings"].get("farm", 0)) >= 3, "Değirmen Sv.3 tamamlandı")
	_check(not bp.visible, "Adım 8 geçişinde BuildingPanel otomatik kapandı")
	_check(int(tm.call("get_current_step")) == 8, "Adım 8 (OPEN_WORLD_MAP) geçildi")

	# 5. Dünya Haritası turu (Adım 8 -> 9 -> 10 -> 11)
	var wmap := await _swap_scene("res://scenes/WorldMap.tscn")
	_check(wmap != null, "WorldMap.tscn yüklendi")
	_check(int(tm.call("get_current_step")) == 9, "Adım 9 (WORLD_MAP_TOUR) geçildi")
	_press_button(btn_next)
	await _tick(2)
	_check(int(tm.call("get_current_step")) == 10, "Adım 10 (RETURN_FROM_MAP) geçildi")

	village = await _swap_scene("res://scenes/Village.tscn")
	_check(int(tm.call("get_current_step")) == 11, "Adım 11 (OPEN_ALLIANCE) geçildi")

	# 6. İttifak ekranı turu (Adım 11 -> 12 -> 13 -> 14)
	var alliance := await _swap_scene("res://scenes/Alliance.tscn")
	_check(alliance != null, "Alliance.tscn yüklendi")
	_check(int(tm.call("get_current_step")) == 12, "Adım 12 (ALLIANCE_TOUR) geçildi")
	_press_button(btn_next)
	await _tick(2)
	_check(int(tm.call("get_current_step")) == 13, "Adım 13 (RETURN_FROM_ALLIANCE) geçildi")

	village = await _swap_scene("res://scenes/Village.tscn")
	bp = village.get("building_panel") as Control
	upg_btn = bp.get_node_or_null("VBox/UpgradeButton") as BaseButton
	close_btn = bp.get_node_or_null("VBox/Header/CloseButton") as BaseButton
	_check(int(tm.call("get_current_step")) == 14, "Adım 14 (BUILD_BARRACKS_LV1) geçildi")

	# 7. Kışla Sv.1 inşa et (Adım 14 -> 15)
	await _click_building(village, "barracks")
	_press_button(upg_btn)
	await _tick(2)
	_press_button(btn_speedup)
	await _tick(3)
	active_v = gs.call("get_active_village")
	_check(int(active_v["buildings"].get("barracks", 0)) >= 1, "Kışla Sv.1 inşa edildi")
	_check(int(tm.call("get_current_step")) == 15, "Adım 15 (RESEARCH_SPEAR) geçildi")

	# 8. Araştırma sekmesi -> Silahtar araştır (Adım 15 -> 16)
	var tab_res := bp.get_node_or_null("VBox/TabBar/TabResearchBtn") as BaseButton
	_press_button(tab_res)
	await _tick(2)
	var res_btn := bp.find_child("ResearchBtn_spear", true, false) as BaseButton
	_check(res_btn != null, "ResearchBtn_spear butonu bulundu")
	_press_button(res_btn)
	await _tick(2)
	_check(btn_speedup.visible, "Silahtar araştırmasında Kraliyet Fermanı göründü")
	_press_button(btn_speedup)
	await _tick(3)
	active_v = gs.call("get_active_village")
	_check(RE.is_researched(active_v, "spear"), "Silahtar araştırması tamamlandı")
	_check(int(tm.call("get_current_step")) == 16, "Adım 16 (TRAIN_10_SPEAR) geçildi")

	# 9. Eğit sekmesi -> +10 ve Eğit -> 10 Silahtar tamamla (Adım 16 -> 17)
	var tab_train := bp.get_node_or_null("VBox/TabBar/TabTrainBtn") as BaseButton
	_press_button(tab_train)
	await _tick(2)
	var plus10 := bp.find_child("BtnPlus10_spear", true, false) as BaseButton
	var train_btn := bp.find_child("TrainBtn_spear", true, false) as BaseButton
	_check(plus10 != null and train_btn != null, "BtnPlus10_spear ve TrainBtn_spear butonları bulundu")
	var wood_before := int(active_v.get("resources", {}).get("wood", 0))
	_press_button(plus10)
	await _tick(1)
	_press_button(train_btn)
	await _tick(2)
	_press_button(btn_speedup)
	await _tick(3)

	active_v = gs.call("get_active_village")
	_check(int(active_v.get("units", {}).get("spear", 0)) >= 10, "En az 10 Silahtar eğitildi (%d)" % int(active_v.get("units", {}).get("spear", 0)))
	_check(int(tm.call("get_current_step")) == 17, "Adım 17 (GRADUATION_MODAL) geçildi")

	var vmodal := tm.get("_victory_modal") as Control
	_check(vmodal != null and vmodal.visible, "Mezuniyet ödül penceresi göründü")
	_check(bool(gs.get("player").get("tutorial_reward_claimed", false)), "Mezuniyet ödülü işaretlendi")
	var wood_after := int(active_v.get("resources", {}).get("wood", 0))
	_check(wood_after >= wood_before + 800, "Mezuniyet +1000 kaynak ödülü eklendi (öncesi=%d, sonrası=%d)" % [wood_before, wood_after])

	# 10. Bitir & Ayarlar'dan tekrar başlatmayı doğrula
	var btn_finish := tm.get("_btn_finish") as Button
	_press_button(btn_finish)
	await _tick(2)
	_check(bool(gs.get("player").get("tutorial_completed", false)), "tutorial_completed=true kaydedildi")
	_check(not tm.call("is_tutorial_active"), "Rehber tamamlandıktan sonra pasifleşti")

	var settings := await _swap_scene("res://scenes/Settings.tscn")
	_check(settings != null, "Settings.tscn yüklendi")
	var btn_replay := settings.find_child("BtnTutorialReplay", true, false) as Button
	_check(btn_replay != null, "Ayarlar ekranında BtnTutorialReplay butonu mevcut")
	tm.call("restart_tutorial")
	_check(int(tm.call("get_current_step")) == 0 and not bool(gs.get("player").get("tutorial_completed", true)), "restart_tutorial() rehberi 0. adıma sıfırladı")

	if _active_scene != null and is_instance_valid(_active_scene):
		root.remove_child(_active_scene)
		_active_scene.queue_free()
		_active_scene = null
