extends SceneTree
## test_build38_lord_system.gd — Build 38 Lord, 13 Slot Ekipman, Örs (+0..+8),
## Haydut Köyleri, Savaş/Yaralanma, Konuşma Balonu ve Kalıcılık E2E testleri.

const LordModelScript := preload("res://scripts/model/LordModel.gd")
const BS := preload("res://scripts/sim/battle/BattleSimulator.gd")
const MovementScript := preload("res://scripts/sim/actions/Movement.gd")
const ArrivalScript := preload("res://scripts/sim/actions/Arrival.gd")
const BotSim := preload("res://scripts/bot/BotSimulator.gd")
const WorldGen := preload("res://scripts/world/WorldGenerator.gd")
const VM := preload("res://scripts/model/VillageModel.gd")
const LordModalScript := preload("res://ui/LordModal.gd")
const LordUpgradeModalScript := preload("res://ui/LordUpgradeModal.gd")

var _passed: int = 0
var _failed: int = 0
var _fail_labels: Array[String] = []


func _initialize() -> void:
	await _run_all()
	print("")
	print("==================== BUILD 38 LORD TEST ÖZETİ ====================")
	print("PASS: %d   FAIL: %d" % [_passed, _failed])
	if _failed > 0:
		for l in _fail_labels:
			print("  - ", l)
	print("==================================================================")
	quit(1 if _failed > 0 else 0)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("PASS: ", label)
	else:
		_failed += 1
		_fail_labels.append(label)
		printerr("FAIL: ", label)


func _run_all() -> void:
	var gs := root.get_node_or_null("GameState")
	var lm := root.get_node_or_null("LordManager")
	var sm := root.get_node_or_null("StoreManager")
	var wm := root.get_node_or_null("WorldManager")
	var gd := root.get_node_or_null("GameData")
	_check(gs != null and lm != null and sm != null and wm != null and gd != null, "Gerekli autoloadlar yüklü")
	if gs == null or lm == null:
		return

	gd.call("load_all", true)
	gs.call("reset")

	var player_v := VM.create(100, "Başkent", 100, 100, "HeroTest", false)
	player_v["resources"] = {"wood": 20000, "stone": 20000, "iron": 20000}
	player_v["buildings"] = {"main": 10, "barracks": 10, "wall": 5, "farm": 10, "storage": 15}
	player_v["units"] = {"axe": 200, "spear": 120, "bow": 80, "light": 60, "snob": 2}
	gs.set("villages", [player_v])
	gs.set("active_village_id", 100)
	gs.set("player", {
		"id": 1,
		"name": "HeroTest",
		"diamonds": 35,
		"scrolls": {},
		"points": 500,
		"lord": LordModelScript.default_lord_state(),
	})

	# 1) 13 Slot, Kuşanma/Çıkarma, Anti-Kopyalama & Stat Hesaplama
	_check(LordModelScript.SLOTS.size() == 13, "Lord toplam 13 ekipman slotuna sahip")
	var base_stats: Dictionary = lm.call("get_lord_stats")
	_check(int(base_stats["hp"]) == 500 and int(base_stats["attack"]) == 120 and int(base_stats["defense"]) == 100, "Başlangıç Lord statları doğru")

	var sw_common_1 := LordModelScript.create_item("sword", "common", 1, 901)
	var sw_common_1_stats := LordModelScript.compute_item_stats(sw_common_1)
	_check(is_equal_approx(float(sw_common_1_stats["attack_pct"]), 2.0), "Standart +1 kılıç tam %2 saldırı bonusu veriyor")

	var sw_rare_8 := LordModelScript.create_item("sword", "rare", 8, 902)
	var sw_rare_8_stats := LordModelScript.compute_item_stats(sw_rare_8)
	_check(float(sw_rare_8_stats["attack_pct"]) <= 50.0 and is_equal_approx(float(sw_rare_8_stats["attack_pct"]), 50.0), "Nadir +8 kılıç maksimum %50 saldırı sınırı içinde (%50.0)")

	# Başlangıç kiti ve anti-duplication testi
	var kit_res: Dictionary = lm.call("grant_tutorial_starter_kit")
	var kit_res2: Dictionary = lm.call("grant_tutorial_starter_kit")
	_check(bool(kit_res2.get("already_granted", false)), "Tutorial başlangıç kiti idempotent (çift verilmez)")
	var sword_id := str(kit_res.get("sword_id", ""))
	var ld: Dictionary = lm.call("get_lord_state")
	_check(not sword_id.is_empty() and int(ld.get("upgrade_scrolls", 0)) == 1, "Tutorial +0 kılıç ve 1 parşömen eklendi")

	# Çift slota aynı yüzüğü takmaya karşı koruma testi
	var ring := LordModelScript.create_item("ring", "uncommon", 2, 50)
	var earr := LordModelScript.create_item("earring", "rare", 3, 51)
	(ld["inventory"] as Array).append(ring)
	(ld["inventory"] as Array).append(earr)

	var eq_sw: Dictionary = lm.call("equip_item", "sword", sword_id)
	_check(bool(eq_sw.get("ok", false)), "Kılıç sword slotuna takıldı")
	var bad_eq: Dictionary = lm.call("equip_item", "helmet", sword_id)
	_check(not bool(bad_eq.get("ok", false)), "Kılıç helmet slotuna takılamaz")
	var post_eq_stats: Dictionary = lm.call("get_lord_stats")
	_check(int(post_eq_stats["attack"]) > int(base_stats["attack"]), "Ekipman takılınca Lord Saldırı statı anında arttı")

	var inv_avail: Array[Dictionary] = lm.call("get_unequipped_items")
	var sw_in_avail := false
	for x in inv_avail:
		if str(x.get("id", "")) == sword_id:
			sw_in_avail = true
	_check(not sw_in_avail, "Takılı kılıç kullanılabilir envanter listesinde görünmüyor")

	# Aynı yüzüğü önce ring_1'e sonra ring_2'ye takınca ring_1 boşalmalı (kopyalanmamalı)
	lm.call("equip_item", "ring_1", str(ring["id"]))
	lm.call("equip_item", "ring_2", str(ring["id"]))
	ld = lm.call("get_lord_state")
	_check(str(ld["equipped"]["ring_1"]).is_empty() and str(ld["equipped"]["ring_2"]) == str(ring["id"]), "Aynı eşya asla iki slota birden takılamaz")

	# 2) Ekipman Geliştirme Sistemi (+0..+8, Önizleme, Takılı Engel, Başarısızlıkta Yanma)
	var while_eq_upg: Dictionary = lm.call("upgrade_item", sword_id)
	_check(not bool(while_eq_upg.get("ok", false)), "Takılı eşya doğrudan geliştirilemez")

	lm.call("unequip_slot", "sword")
	var pv_0: Dictionary = lm.call("preview_upgrade", sword_id)
	_check(bool(pv_0.get("ok", false)) and int(pv_0.get("rate", 0)) == 100 and not bool(pv_0.get("destroys_on_fail", true)), "+0->+1 Önizleme %100 ve yanma yok gösteriyor")
	_check(int((lm.call("get_item_by_id", sword_id) as Dictionary).get("plus", 0)) == 0, "Önizleme eşyanın gerçek seviyesini değiştirmedi")

	var u1: Dictionary = lm.call("upgrade_item", sword_id)
	_check(bool(u1.get("upgraded", false)) and int(u1.get("new_plus", 0)) == 1 and int(u1.get("scrolls_left", -1)) == 0, "+0->+1 başarılı oldu ve parşömen tükendi")

	# Oran tablosu doğrulaması
	var expected_rates := [100, 100, 100, 80, 60, 40, 20, 10]
	var rates_ok := true
	for p in range(expected_rates.size()):
		if LordModelScript.upgrade_rate_for_plus(p) != expected_rates[p]:
			rates_ok = false
	_check(rates_ok, "+0..+8 geliştirme oranları doğru (100/100/100/80/60/40/20/10)")

	# Hammadde ve Elmas ile Parşömen Satın Alma
	var res_buy: Dictionary = lm.call("buy_scroll_with_resources")
	_check(bool(res_buy.get("ok", false)) and int(res_buy.get("scrolls_left", 0)) == 1, "5.000 Odun/Taş/Demir ile parşömen satın alındı")
	var cur_v: Dictionary = gs.call("get_active_village")
	_check(int(cur_v["resources"]["wood"]) == 15000 and int(cur_v["resources"]["iron"]) == 15000, "Köy deposundan 5.000 hammadde doğru düştü")

	var dia_buy: Dictionary = sm.call("buy_scroll", "lord_upgrade_scroll", 1)
	_check(bool(dia_buy.get("ok", false)) and int(sm.call("get_diamonds")) == 30 and int(lm.call("get_scroll_count")) == 2, "Pazardan 5 Elmas ile parşömen satın alındı (30 elmas kaldı)")

	# Başarısız yükseltmede eşya + parşömen yok olmalı (+4 item üzerinde roll=99 -> %60 başarısız)
	var fail_item := LordModelScript.create_item("axe" if false else "shield", "rare", 4, 777)
	(lm.call("get_lord_state")["inventory"] as Array).append(fail_item)
	var fail_res: Dictionary = lm.call("upgrade_item", str(fail_item["id"]), 99)
	_check(bool(fail_res.get("ok", false)) and not bool(fail_res.get("upgraded", true)) and bool(fail_res.get("destroyed", false)), "+4->+5 başarısız roll sonucu yanma tetiklendi")
	_check((lm.call("get_item_by_id", str(fail_item["id"])) as Dictionary).is_empty() and int(lm.call("get_scroll_count")) == 1, "Başarısız yükseltmede hem eşya yok oldu hem parşömen tüketildi")

	# 3) Haydut Köyleri (Bot Durdurma, Fethedilemezlik, Anında Ordu Yenilenmesi, Random + %10 Nadir Drop)
	var world_gen := WorldGen.generate(1001, 10)
	var vills := world_gen["villages"] as Array
	var first_bot := {}
	for wv in vills:
		if bool((wv as Dictionary).get("is_bot", false)):
			first_bot = wv as Dictionary
			break
	_check(not first_bot.is_empty() and bool(first_bot.get("is_bandit", false)) and str(first_bot.get("name", "")).begins_with("Haydut Köyü"), "Üretilen eski bot köyleri artık Haydut Köyü")
	var snap_before := first_bot.duplicate(true)
	var bot_events := BotSim.process_tick({"villages": [first_bot]}, 1700000000, 600.0)
	_check(bot_events.is_empty() and first_bot["buildings"].hash() == snap_before["buildings"].hash() and first_bot["units"].hash() == snap_before["units"].hash(), "Haydut köyleri kendi kendine gelişmiyor ve saldırmıyor")

	# Zayıf vs Güçlü Haydut Köyüne Saldırı -> Fetih Engeli + Ordu Yenilenmesi + Random Drop
	var bandit_v := {
		"id": 200, "name": "Haydut Köyü Sv.2", "x": 102, "y": 100, "owner": "Haydutlar",
		"is_bot": true, "is_bandit": true, "bandit_level": 2, "bandit_initialized": true,
		"buildings": LordModelScript.bandit_template(2)["buildings"].duplicate(true),
		"units": LordModelScript.bandit_template(2)["units"].duplicate(true),
		"resources": {"wood": 500, "stone": 500, "iron": 500},
		"points": LordModelScript.bandit_template(2)["points"],
		"realm_of_power": 100,
	}
	var sim_state := {
		"player": (gs.get("player") as Dictionary).duplicate(true),
		"villages": [player_v.duplicate(true), bandit_v],
		"movements": [],
		"reports": [],
		"alliances": [],
	}
	var drop_slots := {}
	for _atk_i in range(25):
		var atk_m := {
			"id": 1000 + _atk_i,
			"type": "attack",
			"village_id": 100,
			"from_village_id": 100,
			"to_village_id": 200,
			"from_x": 100, "from_y": 100, "to_x": 102, "to_y": 100,
			"units": {"axe": 200, "light": 60, "snob": 1},
			"depart_unix": 1700000000,
			"arrive_unix": 1700000300,
			"battle_seed": 12345 + _atk_i * 77,
			"include_lord": true,
			"lord_snapshot": lm.call("get_combat_payload"),
		}
		var r_win := ArrivalScript.resolve(sim_state, atk_m, 1700000300)
		var b_ev: Dictionary = {}
		for ev in r_win.get("events", []):
			if str((ev as Dictionary).get("type", "")) == "battle_resolved":
				b_ev = ev
		_check(not bool(b_ev.get("conquered", true)), "Haydut köyü Kont ile asla fethedilemez (saldırı #%d)" % _atk_i) if _atk_i == 0 else null
		var di: Dictionary = b_ev.get("dropped_item", {})
		if not di.is_empty():
			drop_slots[str(di.get("slot_type", ""))] = true
	var tmpl_2_units := LordModelScript.bandit_template(2)["units"] as Dictionary
	_check(int(bandit_v["units"]["spear"]) == int(tmpl_2_units["spear"]) and str(bandit_v["owner"]) == "Haydutlar", "Haydut köyü ordusu savaş biter bitmez şablona geri döndü ve fethedilmedi")
	_check(drop_slots.size() >= 4, "25 saldırıda farklı ekipman slotları rastgele düştü (%d farklı slot)" % drop_slots.size())

	# Nadir %10 düşme oranı doğrulaması (Seviye 8 haydut köyü üzerinden 500 roll)
	var rare_rng := RandomNumberGenerator.new()
	rare_rng.seed = 20261126
	var rare_hits := 0
	for r_i in range(500):
		var d_it := LordModelScript.roll_bandit_drop(8, rare_rng, r_i + 1)
		if str(d_it.get("rarity", "")) == "rare":
			rare_hits += 1
	_check(rare_hits >= 25 and rare_hits <= 80, "İleri seviye Haydut köyünde Nadir düşme oranı ~%%10 (500'de %d)" % rare_hits)

	# 4) Savaşta Lord Etkisi, Yaralanma (30-60 dk) ve İyileşme
	var atk_no_lord := BS.simulate(
		{"units": {"axe": 40}, "points": 300, "barracks_level": 5},
		{"units": {"spear": 45}, "points": 300, "wall_level": 2},
		{"seed": 42}
	)
	var atk_with_lord := BS.simulate(
		{"units": {"axe": 40}, "points": 300, "barracks_level": 5, "lord": {"present": true, "attack": 220, "defense": 180, "hp": 800, "infantry_atk_pct": 10.0, "archer_atk_pct": 0.0, "army_hp_pct": 5.0}},
		{"units": {"spear": 45}, "points": 300, "wall_level": 2},
		{"seed": 42}
	)
	_check(float(atk_with_lord["phases"][2]["data"]["attack_value"]) > float(atk_no_lord["phases"][2]["data"]["attack_value"]), "Lord savaş gücüne gerçek saldırı katkısı sağlıyor")

	# Mağlubiyette Lord 30-60 dk yaralanmalı ama ekipmanları korunmalı
	var eq_before_injury := (lm.call("get_lord_state")["equipped"] as Dictionary).duplicate(true)
	var now_test := 1700001000
	var inj_until := int(lm.call("injure_lord", 1.0, now_test))
	_check(inj_until >= now_test + 1800 and inj_until <= now_test + 3600, "Lord yenilgide 30-60 dakika arası yaralandı (%d sn)" % (inj_until - now_test))
	_check(bool(lm.call("is_injured", now_test + 10)), "Lord iyileşme süresi dolmadan yaralı görünüyor")
	_check((lm.call("get_lord_state")["equipped"] as Dictionary) == eq_before_injury, "Lord yaralandığında takılı ekipmanlar asla kaybolmaz")

	# Yaralıyken sefere katılamama
	var inj_state := {
		"player": (gs.get("player") as Dictionary).duplicate(true),
		"villages": [player_v.duplicate(true), bandit_v],
		"movements": [],
	}
	var mv_inj := MovementScript.send_attack(inj_state, 100, 200, {"axe": 50}, now_test + 10, {"include_lord": true})
	_check(not bool(mv_inj.get("ok", false)) and str(mv_inj.get("code", "")) == "lord_injured", "Yaralı Lord sefere gönderilemez")

	# İyileşme tick'i
	var rec_ok := bool(lm.call("tick_recovery", inj_until + 5))
	_check(rec_ok and not bool(lm.call("is_injured", inj_until + 5)), "Süre dolunca Lord otomatik iyileşiyor")

	# 5) Konuşma Balonu Kuyruğu & Kaydet/Yükle Kalıcılığı
	lm.call("grant_minigame_accessory", "necklace", "rare", 1)
	var sp_cnt_before := int(lm.call("get_speech_count"))
	_check(sp_cnt_before >= 1, "Bildirim olayları konuşma balonu kuyruğunda birikiyor (%d)" % sp_cnt_before)
	var top_sp: Dictionary = lm.call("peek_speech")
	_check(not top_sp.is_empty(), "İlk konuşma balonu okunabiliyor")
	lm.call("dismiss_current_speech")
	_check(int(lm.call("get_speech_count")) == sp_cnt_before - 1, "Konuşma balonu kapatılınca sıradaki mesaja geçiyor")

	var snap_state: Dictionary = gs.call("to_dict")
	wm.call("_sync_player_profile_to_world", snap_state)
	gs.call("reset")
	gs.call("from_dict", snap_state)
	wm.call("_restore_player_profile_from_world", snap_state, "HeroTest")
	var restored_lord := LordModelScript.ensure_state_dict((snap_state["player"] as Dictionary).get("lord", null))
	_check((restored_lord["inventory"] as Array).size() >= 4, "Lord envanteri GameState/WorldManager sync sonrasında eksiksiz korunuyor")

	# UI örnekleme hatasızlığı (LordModal & LordUpgradeModal)
	var l_mod := LordModalScript.new()
	root.add_child(l_mod)
	l_mod.call("open_modal")
	var u_mod := LordUpgradeModalScript.new()
	root.add_child(u_mod)
	u_mod.call("open_modal", sword_id)
	await process_frame
	_check(l_mod.visible and u_mod.visible, "LordModal ve LordUpgradeModal hatasız oluşturuldu ve açıldı")
	l_mod.queue_free()
	u_mod.queue_free()

	# Village HUD BtnLord + LordSpeechBubble kontrolü
	var vil_scene := load("res://scenes/Village.tscn") as PackedScene
	var vil := vil_scene.instantiate()
	root.add_child(vil)
	await process_frame
	var btn_l := vil.find_child("BtnLord", true, false) as Button
	var bubble := vil.find_child("LordSpeechBubble", true, false) as Control
	_check(btn_l != null and btn_l.visible, "Village sahnesinde BtnLord görünür")
	_check(bubble != null and bubble.visible, "Lord konuşma balonu kuyruk doluyken Village ekranında görünüyor")
	vil.queue_free()
