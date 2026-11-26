extends SceneTree
## test_quest_system.gd — KingsAge Görev Sistemi (QuestManager) + Kuyumcu/Köşk UI E2E testi.

const VM := preload("res://scripts/model/VillageModel.gd")

var _passed: int = 0
var _failed: int = 0
var _fail_labels: Array[String] = []
var _active_scene: Node = null


func _initialize() -> void:
	await _run_tests()
	print("")
	print("==================== QUEST SYSTEM E2E ÖZET ====================")
	print("PASS: %d   FAIL: %d" % [_passed, _failed])
	if _failed > 0:
		print("Başarısız kontroller:")
		for lbl in _fail_labels:
			print("  - ", lbl)
	print("===============================================================")
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


func _run_tests() -> void:
	var gd := root.get_node_or_null("GameData")
	var gs := root.get_node_or_null("GameState")
	var tm := root.get_node_or_null("TutorialManager")
	var qm := root.get_node_or_null("QuestManager")
	var eb := root.get_node_or_null("EventBus")

	_check(gd != null and gs != null and tm != null and qm != null, "Gerekli autoload düğümleri yüklü")
	if gd == null or gs == null or qm == null:
		return

	gd.call("load_all", true)
	qm.set("quest_enabled_in_headless", true)
	if tm != null:
		tm.set("tutorial_enabled_in_headless", false)

	var v := VM.create(1, "Başkent", 100, 100, "TestLord", false)
	v["resources"] = {"wood": 500000, "stone": 500000, "iron": 500000}
	v["buildings"] = {
		"main": 20, "stone": 1, "wood": 2, "iron": 1,
		"farm": 30, "storage": 45, "barracks": 25,
		"hide": 0, "wall": 0, "market": 10, "stable": 0,
		"garage": 5, "snob": 0, "smith": 0, "statue": 0
	}
	v["researched"] = {"spear": true, "sword": true, "axe": true, "bow": true, "spy": true, "light": true, "ram": true}
	v["units"] = {"spear": 10}

	var v2 := VM.create(2, "RakipKoy", 102, 102, "RakipKral", false)
	var v_bandit := VM.create(99, "Haydut Kampı", 104, 104, "Haydutlar", false)
	v_bandit["is_bandit"] = true
	v_bandit["is_bot"] = true

	gs.set("villages", [v, v2, v_bandit])
	gs.set("active_village_id", 1)
	gs.set("queues", [])
	gs.set("movements", [])
	gs.set("reports", [])
	gs.set("player", {
		"id": 1,
		"name": "TestLord",
		"alliance_id": -1,
		"tutorial_step": 0,
		"tutorial_completed": false,
	})
	gs.set("world", {"id": 1, "speed": 1.0, "sim_now_unix": int(Time.get_unix_time_from_system())})

	var village := await _swap_scene("res://scenes/Village.tscn")
	_check(village != null, "Village.tscn yüklendi")

	# 1. Tutorial bitmeden Görev HUD gizli olmalı
	_check(not qm.call("is_quest_hud_visible") and not qm.visible, "Tutorial bitmeden Quest HUD gizli")

	# 2. Tutorial tamamlanınca Quest HUD sol üstte aktifleşmeli (İttifak butonunun tersi)
	gs.player["tutorial_completed"] = true
	gs.player["tutorial_step"] = 17
	await _tick(3)
	_check(qm.call("is_quest_hud_visible") and qm.visible, "Tutorial bittikten sonra Quest HUD aktif")

	var tracker := qm.get("_tracker_panel") as Control
	var btn_alliance := village.get_node_or_null("BtnAlliance") as Control
	_check(tracker != null and btn_alliance != null and tracker.position.x < btn_alliance.position.x, "Görev paneli İttifak butonunun tam ters tarafında sol üstte konumlandı")

	# 3. Sıradaki ilk 3 görev aşağı açılarak gözükmeli
	var vis_quests: Array = qm.call("get_visible_quests")
	_check(vis_quests.size() == 3, "Sıradaki ilk 3 görev görünüyor (%d/3)" % vis_quests.size())
	_check(str(vis_quests[0]["def"]["id"]) == "q_wood_stone_3", "İlk aktif görev: q_wood_stone_3")

	# Aç / kapat düğmesi
	qm.call("set_expanded", false)
	await _tick(1)
	_check(not (qm.get("_drawer_panel") as Control).visible, "Görev çekmecesi kapatılabiliyor")
	qm.call("set_expanded", true)
	await _tick(1)
	_check((qm.get("_drawer_panel") as Control).visible, "Görev çekmecesi tekrar aşağı açılıyor")

	# 4. Göreve tıklayınca Vezir açıklamalı modal açılmalı
	qm.call("open_quest_modal", "q_unlock_snob")
	await _tick(2)
	var d_modal := qm.get("_detail_modal") as Control
	var v_expl := qm.get("_modal_vizier_text") as RichTextLabel
	_check(d_modal != null and d_modal.visible, "Göreve tıklandığında Vezir detay penceresi açıldı")
	_check(v_expl != null and v_expl.text.contains("Köşk") and v_expl.text.contains("Kont"), "Vezir Köşk'ün ne işe yaradığını detaylı açıklıyor")
	qm.call("close_quest_modal")
	await _tick(1)

	# 5. Ödülünü Al akışı: q_wood_stone_3 (wood=3, stone=2 yapınca 2/2 olmalı)
	var active_v: Dictionary = gs.call("get_active_village")
	var wood_before := int(active_v["resources"]["wood"])
	_check(not qm.call("claim_quest", "q_wood_stone_3"), "Koşul sağlanmadan ödül alınamaz")
	active_v["buildings"]["wood"] = 3
	active_v["buildings"]["stone"] = 2
	if eb != null:
		eb.emit_signal("building_completed", 1, "stone", 2)
	await _tick(2)
	var p0: Dictionary = qm.call("get_quest_progress", "q_wood_stone_3")
	_check(int(p0["current"]) == 2 and bool(p0["completed"]), "q_wood_stone_3 ilerlemesi 2/2 tamamlandı")
	var slot0_claim := (qm.get("_slot_nodes")[0]["claim_btn"]) as Button
	_check(slot0_claim != null and slot0_claim.visible, "Tamamlanan görevde 'Ödülünü Al' butonu belirdi")
	_check(qm.call("claim_quest", "q_wood_stone_3"), "Ödülünü Al işlemi başarılı")
	_check(int(active_v["resources"]["wood"]) == wood_before + 400, "Görev ödülü (+400 Odun) köye eklendi")
	vis_quests = qm.call("get_visible_quests")
	_check(str(vis_quests[0]["def"]["id"]) == "q_iron_2", "Ödül alındıktan sonra sıradaki görev liste başına kaydı")

	# 6. 100 Casus Üret: 0/100 -> 50/100 -> 100/100 canlı ilerleme testi
	var spy_0: Dictionary = qm.call("get_quest_progress", "q_train_spy_100")
	_check(int(spy_0["current"]) == 0 and int(spy_0["target"]) == 100, "100 Casus görevi başlangıçta 0/100")
	active_v["units"]["spy"] = 50
	if eb != null:
		eb.emit_signal("unit_trained", 1, "spy", 50)
	await _tick(2)
	var spy_50: Dictionary = qm.call("get_quest_progress", "q_train_spy_100")
	_check(int(spy_50["current"]) == 50 and not bool(spy_50["completed"]), "50 Casus üretilince 50/100 olarak güncellendi")
	active_v["units"]["spy"] = 100
	if eb != null:
		eb.emit_signal("unit_trained", 1, "spy", 50)
	await _tick(2)
	var spy_100: Dictionary = qm.call("get_quest_progress", "q_train_spy_100")
	_check(int(spy_100["current"]) == 100 and bool(spy_100["completed"]), "100 Casus üretilince 100/100 tamamlandı")

	# 7. Casusluk, Yağma, Saldırı ve Haydut Köyü seferleri
	_check(not bool(qm.call("get_quest_progress", "q_spy_bandit")["completed"]), "Haydut Casusluk görevi başlangıçta tamamlanmamış")
	_check(not bool(qm.call("get_quest_progress", "q_attack_bandit")["completed"]), "Haydut Saldırı görevi başlangıçta tamamlanmamış")
	if eb != null:
		eb.emit_signal("army_sent", {"id": 901, "type": "spy", "from_village_id": 1, "to_village_id": 2})
		eb.emit_signal("army_sent", {"id": 902, "type": "raid", "from_village_id": 1, "to_village_id": 2})
		eb.emit_signal("army_sent", {"id": 903, "type": "attack", "from_village_id": 1, "to_village_id": 2})
	await _tick(2)
	_check(bool(qm.call("get_quest_progress", "q_spy_mission")["completed"]), "Casusluk seferi görevi tamamlandı")
	_check(bool(qm.call("get_quest_progress", "q_raid_mission")["completed"]), "Yağma seferi görevi tamamlandı")
	_check(bool(qm.call("get_quest_progress", "q_attack_mission")["completed"]), "Köye Saldırı görevi tamamlandı")
	_check(not bool(qm.call("get_quest_progress", "q_spy_bandit")["completed"]), "Normal köye casusluk Haydut Casusluk görevini tamamlamadı")
	_check(not bool(qm.call("get_quest_progress", "q_attack_bandit")["completed"]), "Normal köye saldırı Haydut Saldırı görevini tamamlamadı")
	if eb != null:
		eb.emit_signal("army_sent", {"id": 904, "type": "spy", "from_village_id": 1, "to_village_id": 99})
		eb.emit_signal("army_sent", {"id": 905, "type": "attack", "from_village_id": 1, "to_village_id": 99})
	await _tick(2)
	_check(bool(qm.call("get_quest_progress", "q_spy_bandit")["completed"]), "Haydut Köyüne casusluk gönderilince q_spy_bandit tamamlandı")
	_check(bool(qm.call("get_quest_progress", "q_attack_bandit")["completed"]), "Haydut Köyüne saldırı gönderilince q_attack_bandit tamamlandı")

	# 8. Kuyumcu (Altın Zırh) ve Köşk (Kont Eğitimi) UI + Köy Fethi testi
	active_v = gs.call("get_active_village")
	active_v["buildings"]["smith"] = 1
	active_v["buildings"]["snob"] = 1
	var bp = village.get("building_panel")
	_check(bp != null, "BuildingPanel erişilebilir")
	if bp != null:
		bp.call("show_building", active_v, "smith")
		await _tick(2)
		var mint_btn := bp.find_child("MintGoldArmourBtn", true, false) as BaseButton
		_check(mint_btn != null and not mint_btn.disabled, "Kuyumcu'da 'Altın Zırh Üret' butonu aktif")
		mint_btn.emit_signal("pressed")
		await _tick(2)
		active_v = gs.call("get_active_village")
		_check(int(active_v.get("gold_armour", 0)) >= 1, "Altın Zırh üretildi")
		_check(bool(qm.call("get_quest_progress", "q_mint_gold_armour")["completed"]), "q_mint_gold_armour görevi tamamlandı")

		active_v["resources"] = {"wood": 400000, "stone": 400000, "iron": 400000}
		bp.call("show_building", active_v, "snob")
		await _tick(2)
		var train_snob_btn := bp.find_child("TrainSnobBtn", true, false) as BaseButton
		var snob_btn_txt := (train_snob_btn as Button).text if train_snob_btn != null else "null"
		_check(train_snob_btn != null and not train_snob_btn.disabled, "Köşk'te 'Kont Eğit' butonu aktif (%s)" % snob_btn_txt)
		bp.hide()
		await _tick(2)

	active_v = gs.call("get_active_village")
	active_v["units"]["snob"] = 1
	if eb != null:
		eb.emit_signal("unit_trained", 1, "snob", 1)
		eb.emit_signal("village_conquered", 2, "TestLord")
	await _tick(2)
	_check(bool(qm.call("get_quest_progress", "q_train_snob")["completed"]), "q_train_snob (Kont üret) tamamlandı")
	_check(bool(qm.call("get_quest_progress", "q_conquer_village")["completed"]), "q_conquer_village (Köy Fethet) tamamlandı")

	# 9. Anıt (q_unlock_statue) tamamlama ve ödül alma testi
	active_v = gs.call("get_active_village")
	active_v["buildings"]["statue"] = 1
	if eb != null:
		eb.emit_signal("building_completed", 1, "statue", 1)
	await _tick(2)
	_check(bool(qm.call("get_quest_progress", "q_unlock_statue")["completed"]), "q_unlock_statue (Anıt aç) tamamlandı")
	_check(qm.call("claim_quest", "q_unlock_statue"), "q_unlock_statue ödülü alınabildi")

	# 10. Dinamik çoklu görev hedef yönlendirme butonları testi (tamamlanan alt hedef gizlenmeli)
	var qdefs: Array = qm.call("get_all_quest_defs")
	var idx_spy := -1
	var idx_axe_r := -1
	var idx_axe_t := -1
	var idx_spy_bandit := -1
	var idx_atk_bandit := -1
	var idx_raid := -1
	var idx_attack := -1
	var idx_stor5 := -1
	var idx_mkt := -1
	var idx_b5_bow := -1
	var idx_axebow := -1
	var idx_b7_light := -1
	var idx_cav := -1
	var idx_b20_ram := -1
	var idx_siege := -1
	var idx_gar5 := -1
	var idx_snob := -1
	var idx_ally := -1
	for qi in range(qdefs.size()):
		match str(qdefs[qi].get("id", "")):
			"q_spy_mission": idx_spy = qi
			"q_research_axe": idx_axe_r = qi
			"q_train_axe_100": idx_axe_t = qi
			"q_spy_bandit": idx_spy_bandit = qi
			"q_attack_bandit": idx_atk_bandit = qi
			"q_raid_mission": idx_raid = qi
			"q_attack_mission": idx_attack = qi
			"q_storage_5": idx_stor5 = qi
			"q_unlock_market": idx_mkt = qi
			"q_barracks_5_bow": idx_b5_bow = qi
			"q_train_axe_bow": idx_axebow = qi
			"q_barracks_7_light": idx_b7_light = qi
			"q_train_cavalry": idx_cav = qi
			"q_barracks_20_ram": idx_b20_ram = qi
			"q_siege_weapons": idx_siege = qi
			"q_garage_5": idx_gar5 = qi
			"q_unlock_snob": idx_snob = qi
			"q_join_or_create_alliance": idx_ally = qi
	_check(idx_axe_r > idx_spy and idx_axe_t > idx_axe_r and idx_raid > idx_axe_t, "Baltacı Araştır + 100 Baltacı Üret görevleri 'İlk Ganimet Seferi'nden ÖNCE geliyor")
	_check(idx_spy_bandit >= 0 and idx_atk_bandit > idx_spy_bandit and idx_atk_bandit < idx_raid and idx_raid < idx_attack, "Haydut Casusluk & Hayduta Saldır görevleri diğer oyuncuya saldırı görevlerinin ÖNÜNDE yer alıyor")
	_check(idx_stor5 >= 0 and idx_stor5 < idx_mkt, "Depo Sv.5 görevi Market açma görevinden ÖNCE geliyor")
	_check(idx_b5_bow >= 0 and idx_b5_bow < idx_axebow, "Kışla Sv.5 & Okçu Araştır görevi Baltacı & Okçu eğitiminden ÖNCE geliyor")
	_check(idx_b7_light >= 0 and idx_b7_light < idx_cav, "Kışla Sv.7 & Akıncı Araştır görevi Süvari eğitiminden ÖNCE geliyor")
	_check(idx_b20_ram >= 0 and idx_b20_ram < idx_siege, "Kışla Sv.20 & Şahmerdan Araştır görevi Kuşatma üretiminden ÖNCE geliyor")
	_check(idx_gar5 >= 0 and idx_gar5 < idx_snob, "Simyager Sv.5 görevi Köşk açma görevinden ÖNCE geliyor")
	_check(idx_ally >= 0, "İttifak kur/katıl görevi kampanyada tanımlı")
	_check(int(qm.call("get_quest_progress", "q_train_axe_100")["target"]) == 100, "100 Baltacı görevi hedefi 100")

	var AllianceMod := preload("res://scripts/model/AllianceModel.gd")
	var st_al: Dictionary = gs.call("to_dict")
	AllianceMod.create_alliance(st_al, str(gs.player.get("name", "TestLord")), "Test Birligi", "TST", "Aciklama")
	gs.call("from_dict", st_al)
	_check(bool(qm.call("get_quest_progress", "q_join_or_create_alliance")["completed"]), "İttifak kurulunca q_join_or_create_alliance tamamlanıyor")

	active_v = gs.call("get_active_village")
	active_v["buildings"]["wood"] = 1
	active_v["buildings"]["stone"] = 1
	var ws_actions_both: Array = qm.call("get_pending_navigation_actions", "q_wood_stone_3", gs)
	_check(ws_actions_both.size() == 2, "q_wood_stone_3 başlangıçta 2 ayrı yönlendirme butonu döndürüyor")
	active_v["buildings"]["wood"] = 3
	var ws_actions_one: Array = qm.call("get_pending_navigation_actions", "q_wood_stone_3", gs)
	_check(ws_actions_one.size() == 1 and str(ws_actions_one[0].get("target", "")) == "stone", "Odun Lv.3 olunca Odun butonu kalktı, yalnızca Taş Ocağı kaldı")

	active_v["buildings"]["storage"] = 2
	active_v["buildings"]["farm"] = 2
	var sf_actions_both: Array = qm.call("get_pending_navigation_actions", "q_storage_farm_4", gs)
	_check(sf_actions_both.size() == 2, "q_storage_farm_4 (Depo & Değirmen Lv.4) 2 ayrı buton döndürüyor")
	active_v["buildings"]["storage"] = 4
	var sf_actions_one: Array = qm.call("get_pending_navigation_actions", "q_storage_farm_4", gs)
	_check(sf_actions_one.size() == 1 and str(sf_actions_one[0].get("target", "")) == "farm", "Depo Lv.4 olunca Depo butonu kalktı, yalnızca Değirmen kaldı")
	active_v["buildings"]["farm"] = 4
	var sf_actions_done: Array = qm.call("get_pending_navigation_actions", "q_storage_farm_4", gs)
	_check(sf_actions_done.is_empty(), "Depo ve Değirmen Lv.4 olunca yönlendirme kalmadı")

	active_v["buildings"]["barracks"] = 2
	active_v["buildings"]["garage"] = 2
	active_v["buildings"]["snob"] = 0
	var snob_prereqs: Array = qm.call("get_pending_navigation_actions", "q_unlock_snob", gs)
	_check(snob_prereqs.size() == 2, "q_unlock_snob eksik önkoşullar için ayrı yönlendirme butonları üretti (Kışla + Simyager)")
	active_v["buildings"]["barracks"] = 5
	var snob_prereqs_one: Array = qm.call("get_pending_navigation_actions", "q_unlock_snob", gs)
	_check(snob_prereqs_one.size() == 1 and str(snob_prereqs_one[0].get("target", "")) == "garage", "Kışla Lv.5 olunca Kışla butonu kalktı, yalnızca Simyager kaldı")

	if _active_scene != null and is_instance_valid(_active_scene):
		root.remove_child(_active_scene)
		_active_scene.queue_free()
		_active_scene = null
