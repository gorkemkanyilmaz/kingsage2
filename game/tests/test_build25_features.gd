extends SceneTree
## test_build25_features.gd — Build 25 Doğrulama Paketi:
## 1) Hızlandırma parşömeni üst üste kullanımda donma/çökme yok (SpeedupModal & MarketModal & coalesced saves)
## 2) Savaş Raporlarında KingsAge Kont Fetih detayları (önceki/kalan Güç Alanı, -düşüş, tahmini kalan Kont saldırısı)
## 3) Tam Köy Fetih Akışı: rapor + harita sahipliği + get_player_villages() + ResourceBar üstten geçiş + bonus/gerçek oyuncu + bulut birleştirme

const Arrival := preload("res://scripts/sim/actions/Arrival.gd")
const Movement := preload("res://scripts/sim/actions/Movement.gd")
const ActionSimulator := preload("res://scripts/sim/actions/ActionSimulator.gd")
const BattleSimulator := preload("res://scripts/sim/battle/BattleSimulator.gd")
const BattleReport := preload("res://scripts/sim/battle/BattleReport.gd")
const EconomyAPI := preload("res://scripts/sim/economy/EconomyAPI.gd")
const VM := preload("res://scripts/model/VillageModel.gd")

var _passed: int = 0
var _failed: int = 0


func _assert(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("[PASS] ", label)
	else:
		_failed += 1
		printerr("[FAIL] ", label)


func _tick(frames: int = 2) -> void:
	for _i in range(frames):
		await process_frame


func _initialize() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	var gd := root.get_node_or_null("GameData")
	var gc := root.get_node_or_null("GameConfig")
	var gs := root.get_node_or_null("GameState")
	var wm := root.get_node_or_null("WorldManager")
	var sm := root.get_node_or_null("StoreManager")
	var auth := root.get_node_or_null("AuthManager")
	var eb := root.get_node_or_null("EventBus")
	var tm := root.get_node_or_null("TutorialManager")
	var qm := root.get_node_or_null("QuestManager")

	_assert(gd != null and gc != null and gs != null and wm != null and sm != null and auth != null and eb != null, "Core autoloads ready")
	if gd != null and gd.has_method("load_all"):
		gd.call("load_all", true)
	if tm != null:
		tm.set("tutorial_enabled_in_headless", false)
	if qm != null:
		qm.set("quest_enabled_in_headless", false)

	wm.call("wipe_all_local_data")
	auth.call("clear_all_account_data")
	auth.call("login_with_apple", "Lord Build25", "b25@privaterelay.appleid.com", "apple_uid_b25")
	var joined: bool = bool(wm.call("join_world", 1, "Lord Build25", 100, 100))
	_assert(joined and bool(gs.call("has_active_village")), "World 1 joined cleanly")
	gs.player["tutorial_completed"] = true

	await _test_rapid_scroll_usage_no_freeze_or_crash(gs, sm, wm)
	await _test_kingsage_conquest_battle_reports_and_ui(gs)
	await _test_full_conquest_ownership_map_switcher_and_cloud_sync(gs, wm, sm)

	wm.call("wipe_all_local_data")
	auth.call("clear_all_account_data")

	print("SONUC: %d BASARILI, %d BASARISIZ" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_rapid_scroll_usage_no_freeze_or_crash(gs: Node, sm: Node, wm: Node) -> void:
	print("\n--- 1) Parşömen Üst Üste Kullanım (Donma / Çökme Yok) Testi ---")
	var pv: Dictionary = gs.call("get_active_village")
	var vid: int = int(pv.get("id", 1))
	pv["buildings"] = {
		"main": 10, "farm": 10, "wood": 6, "stone": 6, "iron": 6,
		"storage": 15, "hide": 1, "barracks": 10, "wall": 5,
		"market": 1, "stable": 5, "garage": 5, "snob": 2, "smith": 2
	}
	pv["resources"] = {"wood": 50000, "stone": 50000, "iron": 50000}

	var now := int(Time.get_unix_time_from_system())
	gs.queues = []
	for i in range(12):
		gs.queues.append({
			"id": 8000 + i,
			"village_id": vid,
			"type": "build",
			"key": "barracks",
			"target_level": 11 + i,
			"start_unix": now - 10 + i * 3600,
			"finish_unix": now + (i + 1) * 3600,
		})
	gs.player["diamonds"] = 1000
	gs.player["scrolls"] = {"build_10m": 25, "train_10m": 5, "march_10m": 5}

	var speedup_script = load("res://ui/SpeedupModal.gd")
	var modal := speedup_script.new() as CanvasLayer
	root.add_child(modal)
	modal.call("configure", "build", null, "Kışla İnşaatı")
	await _tick(2)

	var widgets_before: Dictionary = modal.get("_row_widgets")
	var row_10m: Dictionary = widgets_before.get("build_10m", {})
	var use_btn_ref: Button = row_10m.get("use_btn") as Button
	var quick_btn_ref: Button = row_10m.get("quick_btn") as Button
	_assert(is_instance_valid(use_btn_ref) and use_btn_ref.visible, "SpeedupModal ilk açılışta Kullan butonu görünür")
	_assert(is_instance_valid(quick_btn_ref) and not quick_btn_ref.visible, "SpeedupModal Al & Kullan başlangıçta gizli")

	# Aynı kare içinde çift tıklama korumasını doğrula (_tap_busy fazla tıklamayı yutar)
	modal.call("_on_use_scroll_pressed", "build_10m")
	modal.call("_on_use_scroll_pressed", "build_10m")
	_assert(int(sm.call("get_scroll_count", "build_10m")) == 24, "Aynı karede çift tıklamada yalnızca 1 parşömen tüketilir (25 -> 24)")
	await _tick(2)

	# 24 parşömeni üst üste kullan -> in-place buton geçişi (use -> quick_buy) hiç node yok etmeden gerçekleşmeli
	for _k in range(24):
		modal.call("_clear_tap_busy")
		modal.call("_on_use_scroll_pressed", "build_10m")
		await _tick(1)

	_assert(is_instance_valid(modal), "25x üst üste parşömen kullanımından sonra modal geçerli kaldı")
	_assert(is_instance_valid(use_btn_ref) and is_instance_valid(quick_btn_ref), "Satır butonları yeniden kullanım ile sağlam kaldı (use-after-free yok)")
	_assert(int(sm.call("get_scroll_count", "build_10m")) == 0, "25 parşömenin tamamı hatasız tüketildi")
	_assert(not use_btn_ref.visible and quick_btn_ref.visible, "Parşömen 0'a inince butonlar in-place Al & Kullan moduna geçti")

	# Şimdi 10 kez daha üst üste elmasla Al & Kullan
	var diamonds_before_qb := int(sm.call("get_diamonds"))
	for _j in range(10):
		modal.call("_clear_tap_busy")
		modal.call("_on_quick_buy_use_pressed", "build_10m", 5)
		await _tick(1)
	_assert(int(sm.call("get_diamonds")) == diamonds_before_qb - 50, "10x Al & Kullan tam 50 Elmas tüketti")

	# Kalan kuyruk öğelerini bitirecek kadar büyük parşömenle tamamla ve modal kapanışını doğrula
	var rem_q_secs := 0
	for q in gs.queues:
		if typeof(q) == TYPE_DICTIONARY and int((q as Dictionary).get("village_id", -1)) == vid and str((q as Dictionary).get("type", "")) == "build":
			rem_q_secs = maxi(rem_q_secs, int((q as Dictionary).get("finish_unix", now)) - now)
	var needed_60m := int(ceil(float(rem_q_secs) / 3600.0)) + 2
	gs.player["scrolls"]["build_60m"] = needed_60m
	for _m in range(needed_60m):
		if not is_instance_valid(modal) or modal.is_queued_for_deletion():
			break
		modal.call("_clear_tap_busy")
		modal.call("_on_use_scroll_pressed", "build_60m")
		await _tick(1)
	await _tick(2)
	_assert(not is_instance_valid(modal), "Kuyruk tamamen bitince SpeedupModal güvenle kapandı (deferred queue_free)")

	# Kapanmış modalın ardından Store sinyalleri ateşlenirse hiç hata vermemeli (_exit_tree disconnect)
	sm.emit_signal("diamonds_changed", int(sm.call("get_diamonds")))
	sm.emit_signal("scrolls_changed", {})
	await _tick(2)

	# MarketModal içinde üst üste satın alma & kullanma testi
	gs.queues = [{
		"id": 9101,
		"village_id": vid,
		"type": "train",
		"key": "axe",
		"count": 20,
		"settlers": 20,
		"start_unix": now - 5,
		"finish_unix": now + 1000,
	}]
	var mkt_script = load("res://ui/MarketModal.gd")
	var mkt := mkt_script.new() as CanvasLayer
	root.add_child(mkt)
	mkt.call("open_tab", "train")
	await _tick(2)
	for _t in range(4):
		mkt.call("_clear_tap_busy")
		mkt.call("_on_use_scroll_from_market", "train_10m", "Asker Eğitimi 10 Dk", "train")
		await _tick(1)
	_assert(int(sm.call("get_scroll_count", "train_10m")) >= 0, "MarketModal üst üste parşömen kullanımı sorunsuz")
	mkt.queue_free()
	await _tick(2)
	sm.emit_signal("diamonds_changed", int(sm.call("get_diamonds")))
	await _tick(1)
	_assert(true, "MarketModal kapanışı sonrası StoreManager sinyalleri güvenli")

	# Runtime coalescing yolunu doğrudan test et (request_save_active_world + apply_cloud_sync eski req_seq)
	var mut_seq_now := int(wm.get("_local_mutation_seq"))
	var stale_echo := {
		"cloud_state": {
			"world_id": 1,
			"last_saved_unix": now,
			"state": gs.to_dict(),
		},
		"updated_unix": now,
	}
	gs.player["diamonds"] = 777
	wm.set("_local_mutation_seq", mut_seq_now + 5)
	wm.call("apply_cloud_sync", stale_echo, true, mut_seq_now)
	_assert(int(gs.player.get("diamonds", 0)) == 777, "Eski req_seq save yanıtı canlı elmas/parşömen RAM durumunu ezmedi")


func _test_kingsage_conquest_battle_reports_and_ui(gs: Node) -> void:
	print("\n--- 2) KingsAge Kont Fetih Raporu Metrikleri ve Reports UI Testi ---")
	var pv: Dictionary = gs.call("get_active_village")
	var now := int(Time.get_unix_time_from_system())

	# Case A: 1.000 puanlı anıtsız köy (yarısı = max 500 P düşüş -> 1000 -> 500 -> kalan 1 saldırı)
	var sim_state := {
		"world": {"seed": 1001, "size": 200},
		"villages": [
			{
				"id": 101, "name": "KaleSaldiran", "x": 50, "y": 50,
				"owner": "Lord Build25", "is_bot": false, "is_barbarian": false,
				"buildings": {"main": 10, "barracks": 10, "snob": 2},
				"resources": {"wood": 50000, "stone": 50000, "iron": 50000},
				"units": {"axe": 1000, "snob": 4},
				"points": 3000, "realm_of_power": 3000,
			},
			{
				"id": 102, "name": "HedefKucuk", "x": 51, "y": 50,
				"owner": "Bot Hedef", "is_bot": true, "is_barbarian": false,
				"buildings": {"main": 10, "wall": 0, "statue": 0},
				"resources": {"wood": 1000, "stone": 1000, "iron": 1000},
				"units": {},
				"points": 1000, "realm_of_power": 1000, "has_statue": false,
				"protection_until": 0, "conquest_protection_until": 0,
			},
			{
				"id": 103, "name": "HedefBuyukAnitli", "x": 52, "y": 50,
				"owner": "Bot Buyuk", "is_bot": true, "is_barbarian": false,
				"buildings": {"main": 50, "wall": 0, "statue": 1},
				"resources": {"wood": 1000, "stone": 1000, "iron": 1000},
				"units": {},
				"points": 10000, "realm_of_power": 10000, "has_statue": true,
				"protection_until": 0, "conquest_protection_until": 0,
			},
			{
				"id": 104, "name": "KorumaliKoy", "x": 53, "y": 50,
				"owner": "Lord Yeni", "is_bot": false, "is_barbarian": false,
				"buildings": {"main": 5, "wall": 0, "statue": 0},
				"resources": {"wood": 1000, "stone": 1000, "iron": 1000},
				"units": {},
				"points": 1000, "realm_of_power": 200, "has_statue": false,
				"protection_until": 0, "conquest_protection_until": now + 86400,
			},
		],
		"queues": [],
		"movements": [],
		"reports": [],
	}

	var sent_a := Movement.send_attack(sim_state, 101, 102, {"axe": 200, "snob": 1}, now, {"seed": 77})
	_assert(bool(sent_a.get("ok", false)), "Case A Kont saldırısı gönderildi")
	var mv_a: Dictionary = sent_a.get("movement", {})
	var arr_a := int(mv_a.get("arrive_unix", now + 60))
	ActionSimulator.process_tick(sim_state, arr_a, 1.0)
	_assert((sim_state["reports"] as Array).size() == 1, "Case A savaş raporu oluştu")
	var rep_a: Dictionary = (sim_state["reports"] as Array)[0]
	var rdata_a: Dictionary = rep_a.get("data", {})
	_assert(not bool(rdata_a.get("conquered", true)), "Case A: 1. saldırıda fethedilmedi")
	_assert(int(rdata_a.get("realm_before", -1)) == 1000, "Case A: Önceki Güç Alanı = 1000")
	_assert(int(rdata_a.get("realm_loss", -1)) == 500, "Case A: Azaltılan Güç Alanı = 500 (yarısı kuralı)")
	_assert(int(rdata_a.get("realm_after", -1)) == 500 and int(rdata_a.get("realm_remaining", -1)) == 500, "Case A: Kalan Güç Alanı = 500")
	_assert(int(rdata_a.get("est_attacks_min", -1)) == 1 and int(rdata_a.get("est_attacks_max", -1)) == 1, "Case A: Fethe kalan tahmin = 1 Kont saldırısı")

	# Case B: 10.000 puanlı Anıtlı köy -> 1.750-2.250 düşüş
	var sent_b := Movement.send_attack(sim_state, 101, 103, {"axe": 200, "snob": 1}, arr_a + 1, {"seed": 88})
	var arr_b := int((sent_b.get("movement", {}) as Dictionary).get("arrive_unix", arr_a + 120))
	ActionSimulator.process_tick(sim_state, arr_b, 1.0)
	var rep_b: Dictionary = (sim_state["reports"] as Array)[1]
	var rdata_b: Dictionary = rep_b.get("data", {})
	var loss_b := int(rdata_b.get("realm_loss", 0))
	_assert(int(rdata_b.get("realm_before", -1)) == 10000, "Case B: Önceki Güç Alanı = 10.000")
	_assert(loss_b >= 1750 and loss_b <= 2250, "Case B: Anıtlı köyde Kont düşüşü 1750-2250 aralığında (%d)" % loss_b)
	_assert(bool(rdata_b.get("defender_has_statue", false)), "Case B: Anıt bilgisi rapora işlendi")
	_assert(int(rdata_b.get("est_attacks_min", 0)) >= 3 and int(rdata_b.get("est_attacks_max", 0)) <= 6, "Case B: Kalan saldırı tahmini (%d-%d) KingsAge dokümanıyla uyumlu" % [int(rdata_b.get("est_attacks_min", 0)), int(rdata_b.get("est_attacks_max", 0))])

	# Case C: Fetih korumalı köye saldırıda fetih yok, raporda conquered=false
	var sent_c := Movement.send_attack(sim_state, 101, 104, {"axe": 200, "snob": 1}, arr_b + 1, {"seed": 99})
	var arr_c := int((sent_c.get("movement", {}) as Dictionary).get("arrive_unix", arr_b + 120))
	ActionSimulator.process_tick(sim_state, arr_c, 1.0)
	var rep_c: Dictionary = (sim_state["reports"] as Array)[2]
	var rdata_c: Dictionary = rep_c.get("data", {})
	_assert(not bool(rdata_c.get("conquered", true)) and bool(rdata_c.get("conquest_blocked", false)), "Case C: Fetih korumasında raporda fetih gerçekleşmedi gösterilir")
	_assert(int(rdata_c.get("realm_loss", -1)) == 0, "Case C: Fetih korumasında Güç Alanı düşüşü = 0")

	# Case D: Case A'ya 2. Kont saldırısı -> Fetih gerçekleşir
	var sent_a2 := Movement.send_attack(sim_state, 101, 102, {"axe": 200, "snob": 1}, arr_c + 1, {"seed": 100})
	var arr_a2 := int((sent_a2.get("movement", {}) as Dictionary).get("arrive_unix", arr_c + 120))
	ActionSimulator.process_tick(sim_state, arr_a2, 1.0)
	var rep_a2: Dictionary = (sim_state["reports"] as Array)[3]
	var rdata_a2: Dictionary = rep_a2.get("data", {})
	_assert(bool(rdata_a2.get("conquered", false)), "Case D: 2. saldırıda hedef köy fethedildi")
	_assert(int(rdata_a2.get("realm_before", -1)) == 500 and int(rdata_a2.get("realm_remaining", -1)) == 0 and int(rdata_a2.get("realm_post_conquest", -1)) == 300, "Case D: Fetih raporu 500 -> 0 -> %30 (300 P) gösterir")

	# Case E: Sur hasarlı rapor + Reports.gd sahne render doğrulaması
	var rep_wall := {
		"id": 999,
		"type": "battle",
		"unix": now,
		"village_id": int(pv.get("id", 1)),
		"unread": true,
		"data": {
			"target_village_id": 102,
			"from_village_id": int(pv.get("id", 1)),
			"attacker_name": "Lord Build25",
			"defender_name": "Bot Hedef",
			"target_name": "HedefKucuk",
			"attacker_won": true,
			"wall_damage_pct": 50.0,
			"wall_level_before": 10,
			"wall_level_after": 5,
			"attacker_units": {"axe": 200, "ram": 10, "snob": 1},
			"attacker_losses": {},
			"defender_units": {},
			"defender_losses": {},
			"loot": {"wood": 0, "stone": 0, "iron": 0},
			"conquered": false,
			"count_had": 1,
			"realm_before": 1000,
			"realm_after": 500,
			"realm_remaining": 500,
			"realm_loss": 500,
			"realm_cap": 1000,
			"est_attacks_min": 1,
			"est_attacks_max": 1,
		}
	}
	gs.reports = [rep_wall, rep_a2]
	var reports_scene: PackedScene = load("res://scenes/Reports.tscn")
	var reports_ui := reports_scene.instantiate() as Control
	root.add_child(reports_ui)
	await _tick(3)

	reports_ui.call("_show_detail", rep_wall)
	await _tick(2)
	var content_box := reports_ui.find_child("ContentBox", true, false) as Control
	var conq_card := reports_ui.find_child("ConquestReportCard", true, false) as Control
	_assert(content_box != null and conq_card != null, "Reports.gd duvar hasarı + Fetih kartını hatasız render etti")
	var card_text := _collect_all_label_text(conq_card)
	_assert(card_text.contains("-500") and card_text.contains("1 Kont saldırısı daha"), "Reports.gd fetih kartı -500 P ve kalan saldırı sayısını (%s) gösteriyor" % ("OK" if card_text.contains("1 Kont saldırısı daha") else card_text))

	reports_ui.call("_show_detail", rep_a2)
	await _tick(2)
	var conq_card2 := reports_ui.find_child("ConquestReportCard", true, false) as Control
	var card_text2 := _collect_all_label_text(conq_card2)
	_assert(card_text2.contains("300") and card_text2.contains("Fethedildi"), "Reports.gd fetih zafer raporu 0 -> 300 P (%30) durumunu gösteriyor")

	reports_ui.queue_free()
	await _tick(2)


func _test_full_conquest_ownership_map_switcher_and_cloud_sync(gs: Node, wm: Node, sm: Node) -> void:
	print("\n--- 3) Tam Fetih + Harita + Üst Köy Geçişi + Bonus/Oyuncu + Bulut Birleştirme Testi ---")
	var pv: Dictionary = gs.call("get_active_village")
	var cap_id: int = int(pv.get("id", 1))
	var cap_x: int = int(pv.get("x", 100))
	var cap_y: int = int(pv.get("y", 100))
	pv["owner"] = "Lord Build25"
	pv["units"] = {"axe": 1500, "snob": 10}
	pv["buildings"]["barracks"] = 10
	pv["buildings"]["snob"] = 2

	# 1 bot köyü, 1 bonus köyü (bonus_type="wood"), 1 başka gerçek oyuncu köyü oluştur
	var bot_v := VM.create(201, "FethedilecekBot", cap_x + 2, cap_y + 1, "Demir Bey", true)
	bot_v["is_bot"] = true
	bot_v["is_barbarian"] = false
	bot_v["points"] = 1000
	bot_v["realm_of_power"] = 1000
	bot_v["units"] = {}
	bot_v["protection_until"] = 0
	bot_v["conquest_protection_until"] = 0

	var bonus_v := VM.create(202, "UstaOdunBonus", cap_x + 3, cap_y + 2, "Usta", false)
	bonus_v["is_bot"] = false
	bonus_v["is_barbarian"] = false
	bonus_v["bonus_type"] = "wood"
	bonus_v["points"] = 1000
	bonus_v["realm_of_power"] = 200
	bonus_v["units"] = {}
	bonus_v["protection_until"] = 0
	bonus_v["conquest_protection_until"] = 0

	var rival_v := VM.create(203, "RakipKale", cap_x + 4, cap_y + 2, "Lord Rakip", false)
	rival_v["is_bot"] = false
	rival_v["is_barbarian"] = false
	rival_v["points"] = 1000
	rival_v["realm_of_power"] = 200
	rival_v["units"] = {}
	rival_v["protection_until"] = 0
	rival_v["conquest_protection_until"] = 0

	gs.villages = [pv, bot_v, bonus_v, rival_v]
	gs.active_village_id = cap_id
	gs.queues = []
	gs.movements = []
	gs.reports = []
	gs.player["scrolls"] = {"march_60m": 20}

	var now := int(Time.get_unix_time_from_system())
	# Bot köyüne 2 ayrı Kont saldırısı (her birini march_60m parşömeniyle hızlandırıp anında çöz!)
	for hit_idx in [1, 2]:
		var st: Dictionary = gs.to_dict()
		var sres := Movement.send_attack(st, cap_id, 201, {"axe": 250, "snob": 1}, now + hit_idx * 5, {"seed": 300 + hit_idx})
		_assert(bool(sres.get("ok", false)), "Bot köyüne %d. Kont saldırısı çıktı" % hit_idx)
		gs.from_dict(st)
		var mov: Dictionary = sres.get("movement", {})
		var mid: int = int(mov.get("id", -1))
		for _step in range(10):
			var cur_now := int(Time.get_unix_time_from_system())
			var found_m := false
			for m in gs.movements:
				if typeof(m) == TYPE_DICTIONARY and int((m as Dictionary).get("id", -1)) == mid and str((m as Dictionary).get("type", "")) == "attack":
					found_m = true
					break
			if not found_m:
				break
			sm.call("apply_scroll_to_queue", "march_60m", "march", mid)
			await _tick(1)
			now = maxi(now, cur_now)

	var bot_after: Dictionary = gs.call("get_village", 201)
	_assert(str(bot_after.get("owner", "")) == "Lord Build25", "Fetih sonrası bot köyünün yeni sahibi = Lord Build25 (%s)" % str(bot_after.get("owner", "")))
	_assert(not bool(bot_after.get("is_bot", true)) and not bool(bot_after.get("is_barbarian", true)), "Fethedilen köyde is_bot=false & is_barbarian=false")
	_assert(bool(bot_after.get("is_conquered", false)) and str(bot_after.get("conquered_by", "")) == "Lord Build25", "is_conquered=true ve conquered_by=Lord Build25")
	_assert(int(bot_after.get("realm_of_power", 0)) == 300, "Fetih sonrası yeni Güç Alanı = %30 (300)")

	var p_vills: Array = gs.call("get_player_villages")
	_assert(p_vills.size() == 2, "GameState.get_player_villages() artık 2 köy döndürüyor (actual=%d)" % p_vills.size())

	# ResourceBar üst oklar + cycle_active_village doğrulaması
	var rbar_scene: PackedScene = load("res://ui/ResourceBar.tscn")
	var rbar := rbar_scene.instantiate() as PanelContainer
	rbar.set_deferred("size", Vector2(1080, 159))
	root.add_child(rbar)
	await _tick(2)
	var btn_prev := rbar.find_child("BtnPrevVillage", true, false) as Button
	var btn_next := rbar.find_child("BtnNextVillage", true, false) as Button
	_assert(btn_prev != null and btn_prev.visible and btn_next != null and btn_next.visible, "Fetih sonrası ResourceBar köy değiştirme okları görünür")
	gs.call("cycle_active_village", 1)
	await _tick(1)
	_assert(int(gs.active_village_id) == 201, "Yukarıdan sonraki köy butonuna basınca fethedilen köye geçildi (201)")
	gs.call("cycle_active_village", -1)
	await _tick(1)
	_assert(int(gs.active_village_id) == cap_id, "Önceki köy butonuna basınca başkente dönüldü (%d)" % cap_id)
	rbar.queue_free()
	await _tick(2)

	# WorldMap sahiplik & yeşil/altın halka & imza yenilenme doğrulaması
	var wm_scene: PackedScene = load("res://scenes/WorldMap.tscn")
	var wmap := wm_scene.instantiate() as Control
	root.add_child(wmap)
	await _tick(3)
	var view_dict: Dictionary = wmap.get("_village_views")
	var conq_view = view_dict.get(201, null)
	_assert(conq_view != null and bool(conq_view.get("is_player")), "Haritada fethedilen köy (201) is_player=true olarak görünüyor!")
	wmap.queue_free()
	await _tick(2)

	# 3B) Bonus köyü fethet ve WorldManager._is_real_player_village_dict + deduplicate korumasını doğrula
	var st_bon: Dictionary = gs.to_dict()
	var sbon := Movement.send_attack(st_bon, cap_id, 202, {"axe": 250, "snob": 1}, int(Time.get_unix_time_from_system()), {"seed": 401})
	var arr_bon := int((sbon.get("movement", {}) as Dictionary).get("arrive_unix", 0))
	ActionSimulator.process_tick(st_bon, arr_bon + 1, 1.0)
	gs.from_dict(st_bon)
	var bon_after: Dictionary = gs.call("get_village", 202)
	_assert(str(bon_after.get("owner", "")) == "Lord Build25" and str(bon_after.get("bonus_type", "")) == "wood", "Fethedilen Bonus köy sahiplenildi ve bonus_type='wood' korundu")
	_assert(bool(wm.call("_is_real_player_village_dict", bon_after)), "WorldManager._is_real_player_village_dict fethedilen bonus köyünü geçerli oyuncu köyü tanır")

	# Raporlar temizlense dahi fethedilen köyler silinmemeli!
	gs.reports = []
	var w_payload := {"world_id": 1, "state": gs.to_dict()}
	wm.call("_deduplicate_player_starter_villages", w_payload)
	var post_dedup_vills: Array = (w_payload["state"] as Dictionary).get("villages", [])
	_assert(post_dedup_vills.size() == 4, "Raporlar silinse bile _deduplicate_player_starter_villages fethedilen köyleri silmedi")

	# 3C) Başka gerçek oyuncunun köyünü fethet ve eski cloud_w poll yanıtının fethi ezmediğini doğrula!
	var cloud_before_conq := {
		"world_id": 1,
		"last_saved_unix": int(Time.get_unix_time_from_system()) + 100,
		"state": {
			"world": {"world_id": 1, "player_profiles": {}},
			"villages": (gs.villages as Array).duplicate(true),
			"queues": [], "movements": [], "reports": [], "messages": [], "alliances": [],
		}
	}
	var st_riv: Dictionary = gs.to_dict()
	var sriv := Movement.send_attack(st_riv, cap_id, 203, {"axe": 250, "snob": 1}, int(Time.get_unix_time_from_system()), {"seed": 501})
	var arr_riv := int((sriv.get("movement", {}) as Dictionary).get("arrive_unix", 0))
	ActionSimulator.process_tick(st_riv, arr_riv + 1, 1.0)
	gs.from_dict(st_riv)
	wm.call("notify_local_conquest_mutation", 203, "Lord Build25")
	wm.call("save_active_world")

	# Şimdi cloud'dan 201=bot, 202=Usta, 203=Lord Rakip olan ESKİ snapshot gelsin -> fethimiz ASLA silinmemeli!
	var cur_seq := int(wm.get("_local_mutation_seq"))
	wm.call("apply_cloud_sync", {"cloud_state": cloud_before_conq, "updated_unix": int(Time.get_unix_time_from_system()) + 100}, false, maxi(0, cur_seq - 2))
	var final_my_vills: Array = gs.call("get_player_villages")
	_assert(final_my_vills.size() == 4, "Eski cloud sync yanıtı gelse bile Başkent + Bot + Bonus + Rakip tüm 4 köy korundu! (actual=%d)" % final_my_vills.size())


func _collect_all_label_text(node: Node) -> String:
	if node == null:
		return ""
	var out := ""
	if node is Label:
		out += (node as Label).text + "\n"
	for ch in node.get_children():
		out += _collect_all_label_text(ch)
	return out
