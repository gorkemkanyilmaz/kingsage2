extends SceneTree
## App Store Build 43 ekran görüntüleri için güncel oyun içi sahneleri yakalar.

const OUT_DIR := "c:/Users/Gorkem/Desktop/kingsage2/appstore/raw/"
const LordModelScript := preload("res://scripts/model/LordModel.gd")


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
	var wm_node = _ensure_autoload("WorldManager", "res://autoload/WorldManager.gd")
	if wm_node != null:
		wm_node.set("suppress_auto_conquered_prompt", true)
		wm_node.set("current_world_id", 1)
	_ensure_autoload("AuthManager", "res://autoload/AuthManager.gd")
	_ensure_autoload("NetworkManager", "res://autoload/NetworkManager.gd")
	_ensure_autoload("VillageBackgroundCache", "res://autoload/VillageBackgroundCache.gd")
	var lm_node = _ensure_autoload("LordManager", "res://autoload/LordManager.gd")
	_ensure_autoload("StoreManager", "res://autoload/StoreManager.gd")
	var tm_node = _ensure_autoload("TutorialManager", "res://autoload/TutorialManager.gd")
	if tm_node != null and "tutorial_enabled_in_headless" in tm_node:
		tm_node.tutorial_enabled_in_headless = false
	var qm_node = _ensure_autoload("QuestManager", "res://autoload/QuestManager.gd")

	var wg = load("res://scripts/world/WorldGenerator.gd")
	var vmodel = load("res://scripts/model/VillageModel.gd")
	var world: Dictionary = wg.generate(4242, 100)

	# Ana oyuncu köyü (gelişmiş kale, çiftlik kapasitesi yüksek)
	var pv: Dictionary = vmodel.create(999, "Altın Kale", 100, 100, "Kral Alparslan", false)
	pv["is_bot"] = false
	pv["buildings"] = {
		"main": 14,
		"barracks": 11,
		"wood": 12,
		"stone": 11,
		"iron": 10,
		"storage": 13,
		"farm": 19,
		"hide": 4,
		"wall": 9,
		"market": 6,
		"garage": 6,
		"snob": 1,
		"smith": 3,
		"statue": 1
	}
	pv["resources"] = {"wood": 34820, "stone": 29450, "iron": 26190}
	pv["units"] = {"spear": 140, "sword": 95, "axe": 115, "bow": 75, "spy": 48, "light": 46, "heavy": 16, "ram": 8, "kata": 4, "snob": 1}
	pv["researched"] = {"spear": true, "sword": true, "axe": true, "bow": true, "spy": true, "light": true, "heavy": true, "ram": true, "kata": true, "snob": true}
	pv["gold_armour"] = 2
	pv["points"] = 3420
	pv["protection_until"] = 0

	# İkinci fethedilmiş oyuncu köyü
	var pv2: Dictionary = vmodel.create(998, "Demir Hisar", 107, 105, "Kral Alparslan", false)
	pv2["is_bot"] = false
	pv2["buildings"]["main"] = 9
	pv2["buildings"]["barracks"] = 7
	pv2["buildings"]["farm"] = 14
	pv2["points"] = 1420
	pv2["protection_until"] = 0

	# Haritada tüm bot köylerini Haydut Köyü'ne çevir ve komşu köy çakışmalarını temizle
	var bs_sim = load("res://scripts/bot/BotSimulator.gd")
	if bs_sim != null and bs_sim.has_method("ensure_bandit_villages"):
		bs_sim.ensure_bandit_villages(world)
	var near_bandit: Dictionary = {}
	var near_ally: Dictionary = {}
	for v in world["villages"]:
		var vx := int(v.get("x", 0))
		var vy := int(v.get("y", 0))
		var dist: float = sqrt(pow(vx - 100, 2) + pow(vy - 100, 2))
		if dist > 0.5 and dist < 5.5:
			# Merkez Altın Kale etiketiyle çakışmaması için çok yakın komşuları az ötele
			v["x"] = vx + (6 if vx >= 100 else -6)
			v["y"] = vy + (5 if vy >= 100 else -5)
			vx = int(v["x"])
			vy = int(v["y"])
			dist = sqrt(pow(vx - 100, 2) + pow(vy - 100, 2))
		if dist >= 5.5 and dist <= 15.0:
			if near_bandit.is_empty():
				v["is_bot"] = true
				v["is_bandit"] = true
				v["bandit_level"] = 8
				v["name"] = "Haydut Köyü Sv.8"
				v["owner"] = "Haydutlar"
				near_bandit = v
			elif near_ally.is_empty() and abs(vx - int(near_bandit.get("x", 0))) > 5:
				v["owner"] = "Komutan Batur"
				v["name"] = "Güneş Burcu"
				v["is_bot"] = false
				v["is_bandit"] = false
				near_ally = v
		if bool(v.get("is_bot", false)) and not bool(v.get("is_bandit", false)):
			v["is_bandit"] = true
			v["owner"] = "Haydutlar"

	world["villages"].append(pv)
	world["villages"].append(pv2)
	world["tiles"][wg.tile_key(100, 100)] = 999
	world["tiles"][wg.tile_key(107, 105)] = 998

	var now := int(Time.get_unix_time_from_system())
	gs_node.world = world
	gs_node.villages = world["villages"].duplicate(true)

	# İttifak, liderlik tacı, iç duyuru, diplomasi ve bekleyen 2 katılma isteği kur
	var all_list: Array = [
		{
			"id": 1,
			"name": "Kızıl Sancak",
			"tag": "KZL",
			"founder": "Kral Alparslan",
			"leader": "Kral Alparslan",
			"description": "Orta Çağ'ın en güçlü Türk ittifakı.",
			"internal_announcement": "Bu gece 22:00'da Sv.8 Haydut Köylerine eşzamanlı akın düzenliyoruz. Tüm üyeler destek birliklerini hazır tutsun!",
			"members": [
				{"name": "Kral Alparslan", "is_leader": true, "rank": "council_of_elders", "rank_title": "Kurucu Lider", "points": 4840},
				{"name": "Komutan Batur", "is_leader": false, "rank": "commander", "rank_title": "Savaş Komutanı", "points": 3190},
				{"name": "Atabey Ertuğrul", "is_leader": false, "rank": "warrior", "rank_title": "Şövalye", "points": 2480},
				{"name": "Bozkurt Kağan", "is_leader": false, "rank": "warrior", "rank_title": "Akıncı", "points": 1920},
			],
			"diplomacy": {"allies": ["TRK"], "enemies": ["KRG"], "ally_requests_in": [], "ally_requests_out": []},
			"join_requests": [
				{"player_name": "Gazi Demir", "points": 1640, "created_unix": now - 900},
				{"player_name": "Yavuz Alp", "points": 1280, "created_unix": now - 360},
			],
			"chat_messages": [
				{"sender": "Komutan Batur", "text": "Sv.8 haydut kampından nadir Kraliyet Kılıcı düşürdüm!", "timestamp_unix": now - 420},
				{"sender": "Kral Alparslan", "text": "Harika, ittifak duyurusunu kontrol edin. Katılma isteklerini onaylıyorum.", "timestamp_unix": now - 140},
			],
		},
		{
			"id": 2,
			"name": "Turan Birliği",
			"tag": "TRK",
			"founder": "Oğuz Han",
			"leader": "Oğuz Han",
			"members": [{"name": "Oğuz Han", "is_leader": true, "points": 4120}],
			"diplomacy": {"allies": ["KZL"], "enemies": [], "ally_requests_in": [], "ally_requests_out": []},
			"join_requests": [],
		},
		{
			"id": 3,
			"name": "Kuzey Lejyonu",
			"tag": "KRG",
			"founder": "Lord Vaelen",
			"leader": "Lord Vaelen",
			"members": [{"name": "Lord Vaelen", "is_leader": true, "points": 3650}],
			"diplomacy": {"allies": [], "enemies": ["KZL"], "ally_requests_in": [], "ally_requests_out": []},
			"join_requests": [],
		},
	]
	gs_node.alliances = all_list
	world["alliances"] = all_list.duplicate(true)

	# Lord ekipmanları (13 slot dolu + geliştirme için +6 Nadir Kılıç envanterde + 4 parşömen)
	var lord_inv: Array = []
	var lord_eq: Dictionary = LordModelScript.default_equipped_map()
	var slot_specs := [
		["sword", "sword", "rare", 7, "Kraliyet Kılıcı"],
		["shield", "shield", "rare", 6, "Aslan Yeleli Kalkan"],
		["helmet", "helmet", "rare", 6, "Taht Muhafız Miğferi"],
		["chest", "chest", "rare", 7, "İmparator Zırhı"],
		["pants", "pants", "uncommon", 5, "Şövalye Zırh Pantolonu"],
		["gloves", "gloves", "uncommon", 5, "Çelik Zırh Eldiveni"],
		["boots", "boots", "uncommon", 6, "Kraliyet Çizmesi"],
		["earring_1", "earring", "rare", 5, "Yakut Kraliyet Küpesi"],
		["earring_2", "earring", "uncommon", 5, "Altın Savaş Küpesi"],
		["necklace", "necklace", "rare", 6, "Zafer Kolyesi"],
		["ring_1", "ring", "rare", 6, "Hükümdar Yüzüğü"],
		["ring_2", "ring", "uncommon", 5, "Cesaret Yüzüğü"],
		["belt", "belt", "rare", 5, "Kuşatma Kemeri"],
	]
	var seq := 1
	for sp in slot_specs:
		var iid := "appstore_eq_%d" % seq
		lord_inv.append({
			"id": iid,
			"slot_type": sp[1],
			"name": sp[4],
			"rarity": sp[2],
			"plus": sp[3],
			"source": "Haydut Köyü Sv.8",
			"obtained_unix": now - 3600,
		})
		lord_eq[sp[0]] = iid
		seq += 1

	var anvil_sword_id := "appstore_anvil_sword"
	lord_inv.append({
		"id": anvil_sword_id,
		"slot_type": "sword",
		"name": "Kraliyet Kılıcı",
		"rarity": "rare",
		"plus": 6,
		"source": "Haydut Köyü Sv.8",
		"obtained_unix": now - 300,
	})
	var extra_boots_id := "appstore_inv_shield"
	lord_inv.append({
		"id": extra_boots_id,
		"slot_type": "shield",
		"name": "Sancak Kalkanı",
		"rarity": "uncommon",
		"plus": 4,
		"source": "Haydut Köyü Sv.6",
		"obtained_unix": now - 900,
	})

	gs_node.player = {
		"id": 1,
		"name": "Kral Alparslan",
		"points": 4840,
		"diamonds": 85,
		"tutorial_completed": true,
		"wallet": {"diamonds": 85, "lord_upgrade_scroll": 4},
		"lord": {
			"version": 1,
			"injured_until_unix": 0,
			"last_injury_duration": 0,
			"recovery_notified_until": 0,
			"equipped": lord_eq,
			"inventory": lord_inv,
			"next_item_seq": seq + 5,
			"upgrade_scrolls": 4,
			"speech_queue": [],
			"highest_bandit_cleared": 8,
			"tutorial_kit_granted": true,
			"updated_unix": now,
		},
		"quests": {
			"claimed": [
				"q_wood_stone_3", "q_barracks_lv2", "q_storage_farm_4", "q_hide_lv1",
				"q_wall_lv3", "q_infantry_15", "q_market_lv2", "q_spy_prereq",
				"q_spy_bandit", "q_attack_bandit", "q_axe_bow_30", "q_train_cavalry"
			],
			"stats": {
				"spies_sent": 4,
				"spies_resolved": 4,
				"raids_sent": 6,
				"raids_resolved": 6,
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
			"target_level": 10,
			"start_unix": now - 95,
			"finish_unix": now + 185
		},
		{
			"id": 102,
			"village_id": 999,
			"type": "train",
			"key": "light",
			"count": 15,
			"start_unix": now - 30,
			"finish_unix": now + 150
		}
	]

	var bandit_id := int(near_bandit.get("id", 1))
	var ally_id := int(near_ally.get("id", 2))
	gs_node.movements = [
		{
			"id": 1,
			"village_id": 999,
			"from_village_id": 999,
			"to_village_id": bandit_id,
			"type": "attack",
			"state": "outgoing",
			"owner": "Kral Alparslan",
			"units": {"axe": 75, "light": 36, "ram": 4, "snob": 1},
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
			"unix": now - 240,
			"village_id": 999,
			"unread": true,
			"data": {
				"attacker_name": "Kral Alparslan (Altın Kale)",
				"defender_name": "Haydutlar (Haydut Köyü Sv.8)",
				"from_village_id": 999,
				"target_village_id": bandit_id,
				"is_bandit": true,
				"bandit_level": 8,
				"attacker_won": true,
				"is_raid": false,
				"conquered": false,
				"morale": 1.0,
				"luck": 0.14,
				"attacker_units": {"axe": 90, "light": 42, "bow": 50, "ram": 6},
				"attacker_losses": {"axe": 11, "light": 4, "bow": 6, "ram": 0},
				"attacker_alive": {"axe": 79, "light": 38, "bow": 44, "ram": 6},
				"defender_units": {"spear": 65, "sword": 48, "bow": 30},
				"defender_losses": {"spear": 65, "sword": 48, "bow": 30},
				"defender_alive": {"spear": 0, "sword": 0, "bow": 0},
				"loot": {"wood": 6400, "stone": 5850, "iron": 5120},
				"dropped_item": {
					"id": "drop_preview_rare",
					"slot_type": "sword",
					"name": "Kraliyet Kılıcı",
					"rarity": "rare",
					"plus": 0,
					"source": "Haydut Köyü Sv.8"
				}
			}
		}
	]

	if lm_node != null and lm_node.has_method("ensure_lord_state"):
		lm_node.call("ensure_lord_state")

	# 1. Köy + Sol Görevler + Lord Butonu + İttifak Bildirim Rozeti
	change_scene_to_file("res://scenes/Village.tscn")
	for i in range(18):
		await process_frame
	if qm_node != null and qm_node.has_method("set_expanded"):
		qm_node.set_expanded(true)
	for i in range(10):
		await process_frame
	_save_now("raw_01_village_lord_quests.png")

	# 2. Lord 13-Slot Ekipman Ekranı
	var vil = current_scene
	if vil != null and vil.has_method("open_lord_modal"):
		vil.call("open_lord_modal")
		for i in range(12):
			await process_frame
		_save_now("raw_02_lord_equipment.png")

		# 3. Örs +0..+8 Ekipman Geliştirme Ekranı (parşömen yuvaya koyulu)
		vil.call("open_lord_modal", "upgrade_screen", anvil_sword_id)
		for i in range(10):
			await process_frame
		var lm_modal = vil.get("_lord_modal")
		if lm_modal != null:
			var up_modal = lm_modal.get("_upgrade_modal")
			if up_modal != null:
				up_modal.set("_placed_scroll_slot", 0)
				if up_modal.has_method("_refresh_all"):
					up_modal.call("_refresh_all")
				for i in range(8):
					await process_frame
				_save_now("raw_03_lord_upgrade_anvil.png")
				if up_modal.has_method("close_modal"):
					up_modal.call("close_modal")
			if lm_modal.has_method("close_modal"):
				lm_modal.call("close_modal")

		# 5. Kışla Asker Eğitimi & Kategorize Birlik Görünümü
		var bp = vil.get_node_or_null("BuildingPanel")
		if bp != null:
			bp.show_building(pv, "barracks")
			bp.show()
			for i in range(8):
				await process_frame
			if bp.has_method("switch_tab"):
				bp.switch_tab(2)
			for i in range(10):
				await process_frame
			_save_now("raw_05_barracks_army.png")
			bp.hide()

	# 4. Dünya Haritası + Haydut Köyleri & Seferler
	change_scene_to_file("res://scenes/WorldMap.tscn")
	for i in range(20):
		await process_frame
	_save_now("raw_04_world_map_bandits.png")

	# 6. İttifak Ekranı (Kurucu Lider, İç Duyuru, Diplomasi & Katılma İstekleri Uyarısı)
	change_scene_to_file("res://scenes/Alliance.tscn")
	for i in range(14):
		await process_frame
	var al_scene = current_scene
	if al_scene != null:
		al_scene.set("_active_tab", "diplomacy")
		if al_scene.has_method("refresh_view"):
			al_scene.call("refresh_view")
		for i in range(10):
			await process_frame
	_save_now("raw_06_alliance_diplomacy.png")

	# 7. Haydut Köyü Zafer & Nadir Eşya Düşme Raporu (Ganimet + Kazanılan Ekipman görünür)
	change_scene_to_file("res://scenes/Reports.tscn")
	for i in range(14):
		await process_frame
	var rep_scene = current_scene
	if rep_scene != null and rep_scene.has_method("_show_detail") and gs_node.reports.size() > 0:
		rep_scene._show_detail(gs_node.reports[0])
		for i in range(10):
			await process_frame
		var dp = rep_scene.get("detail_panel")
		if dp != null:
			for ch in dp.find_children("*", "ScrollContainer", true, false):
				if ch is ScrollContainer:
					(ch as ScrollContainer).scroll_vertical = 520
			for i in range(6):
				await process_frame
	_save_now("raw_07_bandit_loot_report.png")

	print("APPSTORE BUILD 43 RAW SCREENSHOTS DONE -> ", OUT_DIR)
	quit(0)


func _save_now(file_name: String) -> void:
	var img: Image = root.get_texture().get_image()
	if img == null:
		print("HATA: görüntü alınamadı -> ", file_name)
		return
	var err := img.save_png(OUT_DIR + file_name)
	print("%s (err=%s, %s)" % [file_name, err, img.get_size()])
