extends SceneTree
## App Store ekran görüntüleri için güncel oyun içi sahneleri yakalar.

const OUT_DIR := "c:/Users/Gorkem/Desktop/kingsage2/appstore/raw/"


func _ensure_autoload(node_name: String, script_path: String) -> Node:
	var existing = root.get_node_or_null(node_name)
	if existing != null:
		return existing
	var scr = load(script_path)
	var n: Node = scr.new() if scr != null else Node.new()
	n.name = node_name
	root.add_child(n)
	return n


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	var data_mgr = load("res://autoload/GameData.gd").get_singleton()
	data_mgr.load_all(true)

	_ensure_autoload("EventBus", "res://autoload/EventBus.gd")
	_ensure_autoload("GameConfig", "res://autoload/GameConfig.gd")
	var gs_node = _ensure_autoload("GameState", "res://autoload/GameState.gd")
	_ensure_autoload("GameClock", "res://autoload/GameClock.gd")
	_ensure_autoload("GameLoop", "res://scripts/core/GameLoop.gd")
	_ensure_autoload("SaveManager", "res://autoload/SaveManager.gd")
	_ensure_autoload("WorldManager", "res://autoload/WorldManager.gd")
	_ensure_autoload("AuthManager", "res://autoload/AuthManager.gd")
	_ensure_autoload("NetworkManager", "res://autoload/NetworkManager.gd")
	_ensure_autoload("VillageBackgroundCache", "res://autoload/VillageBackgroundCache.gd")
	var tm_node = _ensure_autoload("TutorialManager", "res://autoload/TutorialManager.gd")
	if tm_node != null and "tutorial_enabled_in_headless" in tm_node:
		tm_node.tutorial_enabled_in_headless = false
	var qm_node = _ensure_autoload("QuestManager", "res://autoload/QuestManager.gd")

	var world: Dictionary = load("res://scripts/world/WorldGenerator.gd").generate(4242, 100)
	var wg = load("res://scripts/world/WorldGenerator.gd")
	var vmodel = load("res://scripts/model/VillageModel.gd")

	# Ana oyuncu köyü (gelişmiş kale, çiftlik kapasitesi yüksek)
	var pv: Dictionary = vmodel.create(999, "Altın Kale", 100, 100, "Kral Alparslan", false)
	pv["is_bot"] = false
	pv["buildings"] = {
		"main": 12,
		"barracks": 10,
		"wood": 11,
		"stone": 10,
		"iron": 9,
		"storage": 12,
		"farm": 18,
		"hide": 3,
		"wall": 8,
		"market": 5,
		"garage": 5,
		"snob": 1,
		"smith": 2,
		"statue": 1
	}
	pv["resources"] = {"wood": 28450, "stone": 24220, "iron": 21890}
	pv["units"] = {"spear": 120, "sword": 85, "axe": 95, "bow": 60, "spy": 48, "light": 40, "heavy": 12, "ram": 6, "snob": 1}
	pv["researched"] = {"spear": true, "sword": true, "axe": true, "bow": true, "spy": true, "light": true, "heavy": true, "ram": true, "snob": true}
	pv["gold_armour"] = 2
	pv["points"] = 2840
	pv["protection_until"] = 0

	# İkinci fethedilmiş oyuncu köyü (haritada çakışmasız uzaklıkta)
	var pv2: Dictionary = vmodel.create(998, "Demir Hisar", 107, 105, "Kral Alparslan", false)
	pv2["is_bot"] = false
	pv2["buildings"]["main"] = 9
	pv2["buildings"]["barracks"] = 7
	pv2["buildings"]["farm"] = 14
	pv2["points"] = 1420
	pv2["protection_until"] = 0

	# Haritada var olan çakışmasız komşu köyleri hedef al (yeni üst üste binen köy ekleme!)
	var near_enemy: Dictionary = {}
	var near_ally: Dictionary = {}
	for v in world["villages"]:
		var vx := int(v.get("x", 0))
		var vy := int(v.get("y", 0))
		var dist: float = sqrt(pow(vx - 100, 2) + pow(vy - 100, 2))
		if dist >= 5.0 and dist <= 16.0:
			if near_enemy.is_empty():
				near_enemy = v
			elif near_ally.is_empty() and abs(vx - int(near_enemy.get("x", 0))) > 4:
				near_ally = v

	world["villages"].append(pv)
	world["villages"].append(pv2)
	world["tiles"][wg.tile_key(100, 100)] = 999
	world["tiles"][wg.tile_key(107, 105)] = 998

	var now := int(Time.get_unix_time_from_system())
	gs_node.world = world
	gs_node.villages = world["villages"].duplicate(true)
	gs_node.player = {
		"id": 1,
		"name": "Kral Alparslan",
		"points": 4260,
		"tutorial_completed": true,
		"quests": {
			"claimed": [
				"q_wood_stone", "q_barracks_lv2", "q_storage_farm_4", "q_hide_lv1",
				"q_wall_lv3", "q_infantry_15", "q_market_lv2", "q_spy_prereq",
				"q_send_spy", "q_raid_village", "q_axe_bow_30", "q_train_cavalry"
			],
			"stats": {
				"spies_sent": 3,
				"spies_resolved": 3,
				"raids_sent": 4,
				"raids_resolved": 4,
				"gold_armour_made": 2,
				"peak_spy": 48
			}
		}
	}
	gs_node.active_village_id = 999
	gs_node.queues = [
		{
			"id": 101,
			"village_id": 999,
			"type": "build",
			"key": "wall",
			"target_level": 9,
			"start_unix": now - 95,
			"finish_unix": now + 185
		},
		{
			"id": 102,
			"village_id": 999,
			"type": "train",
			"key": "light",
			"count": 12,
			"start_unix": now - 30,
			"finish_unix": now + 150
		}
	]

	var enemy_id := int(near_enemy.get("id", 1))
	var ally_id := int(near_ally.get("id", 2))
	gs_node.movements = [
		{
			"id": 1,
			"village_id": 999,
			"from_village_id": 999,
			"to_village_id": enemy_id,
			"type": "attack",
			"state": "outgoing",
			"owner": "Kral Alparslan",
			"units": {"axe": 65, "light": 35, "ram": 4, "snob": 1},
			"carry": {"wood": 0, "stone": 0, "iron": 0},
			"depart_unix": now - 40,
			"arrive_unix": now + 110
		},
		{
			"id": 2,
			"village_id": 999,
			"from_village_id": ally_id,
			"to_village_id": 999,
			"type": "return",
			"state": "returning",
			"owner": "Kral Alparslan",
			"units": {"light": 25},
			"carry": {"wood": 1200, "stone": 980, "iron": 640},
			"depart_unix": now - 60,
			"arrive_unix": now + 85
		},
		{
			"id": 3,
			"village_id": 999,
			"from_village_id": 999,
			"to_village_id": 998,
			"type": "trade",
			"state": "outgoing",
			"owner": "Kral Alparslan",
			"units": {},
			"carry": {"wood": 1500, "stone": 1200, "iron": 900},
			"depart_unix": now - 25,
			"arrive_unix": now + 130
		}
	]

	gs_node.reports = [
		{
			"type": "battle",
			"unix": now - 320,
			"village_id": 999,
			"unread": true,
			"data": {
				"attacker_name": "Kral Alparslan (Altın Kale)",
				"defender_name": "Lord Vaelen (Kuzey Kalesi)",
				"from_village_id": 999,
				"target_village_id": 997,
				"attacker_won": true,
				"is_raid": false,
				"conquered": true,
				"morale": 1.0,
				"luck": 0.14,
				"loyalty_before": 24,
				"loyalty_after": 0,
				"attacker_units": {"axe": 80, "light": 40, "ram": 6, "snob": 1},
				"attacker_losses": {"axe": 14, "light": 5, "ram": 1, "snob": 0},
				"attacker_alive": {"axe": 66, "light": 35, "ram": 5, "snob": 1},
				"defender_units": {"spear": 60, "sword": 45, "bow": 25},
				"defender_losses": {"spear": 60, "sword": 45, "bow": 25},
				"defender_alive": {"spear": 0, "sword": 0, "bow": 0},
				"loot": {"wood": 4200, "stone": 3850, "iron": 3120}
			}
		},
		{
			"type": "spy",
			"unix": now - 1800,
			"village_id": 999,
			"unread": false,
			"data": {"target": "Kuzey Kalesi", "success": true, "spies_sent": 40, "spies_lost": 2}
		}
	]

	# 1. Köy + Sol Üst Görev Takibi
	change_scene_to_file("res://scenes/Village.tscn")
	for i in range(16):
		await process_frame
	if qm_node != null and qm_node.has_method("set_expanded"):
		qm_node.set_expanded(true)
	for i in range(10):
		await process_frame
	_save_now("raw_01_village_quests.png")

	# 2. Kışla Asker Eğitimi
	var vil = current_scene
	if vil != null:
		var bp = vil.get_node_or_null("BuildingPanel")
		if bp != null:
			bp.show_building(pv, "barracks")
			bp.show()
			for i in range(8):
				await process_frame
			if bp.has_method("_switch_tab"):
				bp._switch_tab(2)
			for i in range(10):
				await process_frame
			_save_now("raw_02_barracks_train.png")
			bp.hide()

	# 3. Dünya Haritası + Canlı Seferler
	change_scene_to_file("res://scenes/WorldMap.tscn")
	for i in range(18):
		await process_frame
	_save_now("raw_03_world_map.png")

	# 4. Saldırı / Fetih Seferi Paneli
	var wm_node = current_scene
	if wm_node != null:
		var stp = wm_node.get_node_or_null("SendTroopsPanel")
		if stp != null:
			stp.show_target(pv, near_enemy)
			stp.show()
			for i in range(10):
				await process_frame
			_save_now("raw_04_send_attack_panel.png")
			stp.hide()

	# 5. Zafer & Fetih Raporu Detayı
	change_scene_to_file("res://scenes/Reports.tscn")
	for i in range(14):
		await process_frame
	var rep_scene = current_scene
	if rep_scene != null and rep_scene.has_method("_show_detail") and gs_node.reports.size() > 0:
		rep_scene._show_detail(gs_node.reports[0])
		for i in range(10):
			await process_frame
	_save_now("raw_05_reports_detail.png")

	print("APPSTORE RAW SCREENSHOTS v2 DONE -> ", OUT_DIR)
	quit(0)


func _save_now(file_name: String) -> void:
	var img: Image = root.get_texture().get_image()
	if img == null:
		print("HATA: görüntü alınamadı -> ", file_name)
		return
	var err := img.save_png(OUT_DIR + file_name)
	print("%s (err=%s, %s)" % [file_name, err, img.get_size()])
