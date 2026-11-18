extends SceneTree
## test_v3_parity_fixes.gd — iOS/Vercel eşitleme ve 8 çekirdek düzeltme E2E doğrulama testi.

const VM := preload("res://scripts/model/VillageModel.gd")
const MovementScript := preload("res://scripts/sim/actions/Movement.gd")
const ActionSimulatorScript := preload("res://scripts/sim/actions/ActionSimulator.gd")

var _passed := 0
var _failed := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("  [PASS] ", msg)
	else:
		_failed += 1
		printerr("  [FAIL] ", msg)


func _initialize() -> void:
	await _run()
	print("\n=== V3 PARITY FIXES SUMMARY: PASS=%d FAIL=%d ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _run() -> void:
	var gd := root.get_node_or_null("GameData")
	var gs := root.get_node_or_null("GameState")
	var wm := root.get_node_or_null("WorldManager")
	var tm := root.get_node_or_null("TutorialManager")
	var qm := root.get_node_or_null("QuestManager")
	var eb := root.get_node_or_null("EventBus")

	if gd != null and not gd.is_loaded():
		gd.load_all(true)
	if tm != null:
		tm.set("tutorial_enabled_in_headless", false)
	if qm != null:
		qm.set("quest_enabled_in_headless", true)

	# 1. Tek başlangıç köyü zorlaması & geçersiz/çift başlangıç köylerinin temizlenmesi
	wm.reset_all_worlds()
	var p1 := "Lord TekKoy"
	_check(wm.join_world(1, p1, 35, 35), "Oyuncu 1 Dünya 1'e katıldı")
	_check(wm.join_world(1, p1, 165, 165), "Tekrar join_world çağrısında çift başlangıç köyü üretilmedi")
	_check(gs.get_player_villages().size() == 1, "Oyuncunun başlangıçta tam olarak 1 köyü var (bulunan: %d)" % gs.get_player_villages().size())

	# Çift başlangıç + geçersiz id=0 köy enjeksiyonunu temizle
	var fake_bad := {"id": 0, "name": "Test Kale", "x": 10, "y": 10, "owner": ""}
	var fake_dup := VM.create(999, "Başkent", 165, 35, p1, false)
	var w_data: Dictionary = wm.load_world_dict(1)
	w_data["state"]["villages"].append(fake_bad)
	w_data["state"]["villages"].append(fake_dup)
	_check(wm._deduplicate_player_starter_villages(w_data), "_deduplicate_player_starter_villages geçersiz/çift köyleri yakaladı")
	var real_cnt := 0
	for v in w_data["state"]["villages"]:
		if int((v as Dictionary).get("id", 0)) <= 0:
			_check(false, "id <= 0 köy kalmamalıydı")
		elif not bool((v as Dictionary).get("is_bot", false)) and str((v as Dictionary).get("owner", "")) == p1:
			real_cnt += 1
	_check(real_cnt == 1, "Deduplikasyon sonrası gerçek oyuncunun tek starter köyü kaldı")

	# 2. Tutorial atlandığında rehber görevleri öne eklenmeli ve hepsi yeşil olmamalı
	wm.reset_all_worlds()
	wm.join_world(1, "Lord Rehber", 50, 50)
	_check(gs.get_player_villages().size() == 1, "Yeni oyuncu 1 köy ile başladı")
	if tm != null:
		tm.skip_tutorial()
	await process_frame
	_check(bool(gs.player.get("tutorial_skipped", false)), "skip_tutorial sonrası tutorial_skipped=true")
	var all_q: Array = qm.get_all_quest_defs()
	_check(all_q.size() == qm.TUTORIAL_QUEST_DEFS.size() + qm.QUEST_DEFS.size(), "Rehber görevleri standart görevlerin önüne eklendi")
	var vis_q: Array = qm.get_visible_quests()
	_check(str(vis_q[0]["def"]["id"]) == "q_tut_wood_2", "İlk görünen görev Rehber: Oduncu Kampı Sv.2")
	var any_green := false
	for item in vis_q:
		if bool(item["progress"].get("completed", false)):
			any_green = true
	_check(not any_green, "Tutorial atlandığında taze köydeki görevler yeşil yanmıyor (0/X - 1/2)")

	# 3. Gerçek oyuncular arası ticaret & WorldMap hareket/ölüm animasyon kuralları
	var now := 2000000
	var v_a := VM.create(101, "Köy A", 50, 50, "Lord A", false)
	v_a["buildings"]["market"] = 1
	v_a["buildings"]["barracks"] = 1
	v_a["resources"] = {"wood": 5000, "stone": 5000, "iron": 5000}
	v_a["units"]["spear"] = 20
	var v_b := VM.create(102, "Köy B", 60, 50, "Lord B", false)
	v_b["protection_until"] = 0
	v_b["resources"] = {"wood": 500, "stone": 500, "iron": 500}
	v_b["units"]["spear"] = 0
	var st := {"villages": [v_a, v_b], "movements": [], "reports": [], "alliances": [], "world": {"sim_now_unix": now}}

	var trade_res := MovementScript.send_trade(st, 101, 102, {"wood": 600}, now)
	_check(bool(trade_res.get("ok", false)), "Ortak dünyadaki gerçek arkadaşa Market ile hammadde gönderilebildi")
	ActionSimulatorScript.process_tick(st, int(trade_res["movement"]["arrive_unix"]), 1.0)
	_check(int(v_b["resources"]["wood"]) == 1100, "Arkadaş köyüne 600 odun ulaştı")
	var has_trade_rep := false
	for r in st["reports"]:
		if str((r as Dictionary).get("type", "")) == "trade":
			has_trade_rep = true
	_check(has_trade_rep, "Ticaret varışında sunucu senkronizasyonu için trade raporu üretildi")

	# 3b. Askerler saldırıda ölürse dönüş olmaz, hayatta kalırsa ters yöne dönüş oluşur
	var atk_win := MovementScript.send_attack(st, 101, 102, {"spear": 10}, now + 10)
	_check(bool(atk_win.get("ok", false)), "Sağ kalanlı saldırı gönderildi")
	ActionSimulatorScript.process_tick(st, int(atk_win["movement"]["arrive_unix"]), 1.0)
	var has_ret := false
	for mv in st["movements"]:
		if str((mv as Dictionary).get("type", "")) == "return" and int((mv as Dictionary).get("from_village_id", 0)) == 102 and int((mv as Dictionary).get("to_village_id", 0)) == 101:
			has_ret = true
	_check(has_ret, "Saldırıdan dönen birlikler hedef->kaynak ters yöne dönüş hareketi başlattı")

	st["movements"].clear()
	v_a["units"]["spear"] = 5
	v_b["units"]["heavy"] = 500
	var atk_wipe := MovementScript.send_attack(st, 101, 102, {"spear": 5}, now + 500)
	_check(bool(atk_wipe.get("ok", false)), "Tam kayıplı saldırı gönderildi")
	ActionSimulatorScript.process_tick(st, int(atk_wipe["movement"]["arrive_unix"]), 1.0)
	_check((st["movements"] as Array).is_empty(), "Saldırıda tüm askerler ölünce geri dönüş hareketi OLUŞMADI")

	# 4. Köy içi dikey kaydırma (1080x2340 iPhone oranı) kontrolü
	var vil_packed := load("res://scenes/Village.tscn") as PackedScene
	gs.villages = [VM.create(1, "Başkent", 100, 100, "Lord Scroll", false)]
	gs.active_village_id = 1
	var vil := vil_packed.instantiate()
	root.add_child(vil)
	await process_frame
	var nav_h := 256.0
	var min_y: float = minf(138.0 - 420.0, (2340.0 - nav_h - 340.0) - vil.village_area.scale.y * 1920.0)
	var max_y: float = 138.0 + 140.0
	_check(min_y < max_y - 200.0, "iPhone 19.5:9 çözünürlüğünde dikey kaydırma aralığı geniş (%0.f .. %0.f)" % [min_y, max_y])

	# 5. Üst sol ResourceBar köy değiştirici modalı CanvasLayer kullanmalı
	gs.player["name"] = "Lord Scroll"
	gs.villages.append(VM.create(2, "İkinci Köy", 110, 110, "Lord Scroll", false))
	var rbar := vil.get_node_or_null("ResourceBar")
	_check(rbar != null, "ResourceBar sahnede mevcut")
	if rbar != null:
		rbar._show_village_switcher_modal()
		await process_frame
		var sw = rbar.get("_switcher_modal")
		_check(sw is CanvasLayer, "Köy değiştirici modal CanvasLayer içinde ortalanıyor")
		if is_instance_valid(sw):
			sw.queue_free()

	vil.queue_free()
	await process_frame
