extends SceneTree
## test_v3_parity_fixes.gd — iOS/Vercel eşitleme ve 8 çekirdek düzeltme E2E doğrulama testi.

const VM := preload("res://scripts/model/VillageModel.gd")
const MovementScript := preload("res://scripts/sim/actions/Movement.gd")
const ActionSimulatorScript := preload("res://scripts/sim/actions/ActionSimulator.gd")
const TravelScript := preload("res://scripts/world/Travel.gd")
const RankingScript := preload("res://scenes/Ranking.gd")
const ReportsScript := preload("res://scenes/Reports.gd")

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

	# 4. Köy içi sıkı siyah-ekran önleme (aşırı yukarı/aşağı/sağ/sol kaydırma siyah boşluk göstermez)
	var vil_packed := load("res://scenes/Village.tscn") as PackedScene
	gs.villages = [VM.create(1, "Başkent", 100, 100, "Lord Scroll", false)]
	gs.active_village_id = 1
	var vil := vil_packed.instantiate() as Control
	root.add_child(vil)
	await process_frame
	var nav_h: float = float(vil.call("_get_bottom_nav_height"))
	var top_h: float = float(vil.call("_get_top_bar_height"))
	var vp_rect: Vector2 = vil.get_viewport_rect().size
	vil.call("_pan_by", Vector2(5000.0, 5000.0))
	var v_area: Control = vil.get("village_area") as Control
	_check(v_area.position.y <= top_h + 0.5, "Aşırı aşağı kaydırmada üstte siyah boşluk çıkmıyor (y=%.1f <= %.1f)" % [v_area.position.y, top_h])
	_check(v_area.position.x <= 0.5, "Aşırı sağa kaydırmada solda siyah boşluk çıkmıyor (x=%.1f)" % v_area.position.x)
	vil.call("_pan_by", Vector2(-5000.0, -5000.0))
	var bottom_edge: float = v_area.position.y + v_area.scale.y * 1920.0
	var right_edge: float = v_area.position.x + v_area.scale.x * 1080.0
	_check(bottom_edge >= vp_rect.y - nav_h - 0.5, "Aşırı yukarı kaydırmada altta siyah boşluk çıkmıyor (alt=%.1f >= %.1f)" % [bottom_edge, vp_rect.y - nav_h])
	_check(right_edge >= vp_rect.x - 0.5, "Aşırı sola kaydırmada sağda siyah boşluk çıkmıyor (sağ=%.1f >= %.1f)" % [right_edge, vp_rect.x])

	# 4b. Yürüyüş hızı 1.5x artışı doğrulaması
	var gc := root.get_node_or_null("GameConfig")
	if gc != null:
		gc.set("unit_speed", 1.0)
		_check(is_equal_approx(TravelScript.unit_speed_multiplier(), 1.5), "Taban yürüyüş hızı 1.5x aktif (%.2fx)" % TravelScript.unit_speed_multiplier())
		gc.set("unit_speed", 2.0)
		_check(is_equal_approx(TravelScript.unit_speed_multiplier(), 3.0), "7 günlük başlangıç bonusuyla yürüyüş hızı 3.0x aktif (%.2fx)" % TravelScript.unit_speed_multiplier())

	# 4c. İttifak gücü sıralaması (ittifak gücü = üye oyuncuların toplam gücü)
	var rank_state := {
		"villages": [
			{"id": 1, "owner": "Uye1", "points": 200, "x": 10, "y": 10, "name": "Koy1"},
			{"id": 2, "owner": "Uye2", "points": 150, "x": 20, "y": 20, "name": "Koy2"},
			{"id": 3, "owner": "Rakip1", "points": 420, "x": 30, "y": 30, "name": "Koy3"},
		],
		"alliances": [
			{"id": 10, "name": "İlk İttifak", "tag": "ILK", "leader": "Uye1", "members": [{"name": "Uye1"}, {"name": "Uye2"}]},
			{"id": 11, "name": "Dev İttifak", "tag": "DEV", "leader": "Rakip1", "members": [{"name": "Rakip1"}]},
		],
	}
	var a_ranks := RankingScript.compute_alliance_rankings(rank_state)
	_check(a_ranks.size() == 2 and str(a_ranks[0]["tag"]) == "DEV" and int(a_ranks[0]["total_power"]) == 420, "İttifak sıralamasında 420 P'lik DEV ittifakı 1. sırada")
	_check(str(a_ranks[1]["tag"]) == "ILK" and int(a_ranks[1]["total_power"]) == 350, "İttifak gücü içindeki üyelerin toplam gücü kadar (200+150=350 P)")

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

	# 6. Casusluk çift rapor önleme + okundu / sil kalıcılığı (Reports)
	var spy_r := {
		"type": "spy",
		"village_id": 1,
		"unix": now + 100,
		"unread": true,
		"data": {"from_village_id": 1, "target_village_id": 2, "attacker_name": "Saldiran", "defender_name": "Savunan"}
	}
	var spy_in := {
		"type": "spy_incoming",
		"village_id": 2,
		"unix": now + 100,
		"unread": true,
		"data": {"from_village_id": 1, "target_village_id": 2, "attacker_name": "Saldiran", "defender_name": "Savunan"}
	}
	_check(ReportsScript._report_belongs_to_player(spy_r, "Saldiran", [1]) and not ReportsScript._report_belongs_to_player(spy_in, "Saldiran", [1]), "Casusluk yapan yalnızca 1 spy raporu görür (spy_incoming gizli)")
	_check(not ReportsScript._report_belongs_to_player(spy_r, "Savunan", [2]) and ReportsScript._report_belongs_to_player(spy_in, "Savunan", [2]), "Casuslanan yalnızca spy_incoming raporu görür")

	gs.player = {"name": "Saldiran", "diamonds": 35}
	gs.villages = [VM.create(1, "SaldiranKoyu", 10, 10, "Saldiran", false), VM.create(2, "SavunanKoyu", 20, 20, "Savunan", false)]
	gs.reports = [spy_r, spy_in]
	var rep_scn := (load("res://scenes/Reports.tscn") as PackedScene).instantiate()
	root.add_child(rep_scn)
	await process_frame
	var rep_list := rep_scn.find_child("List", true, false) as VBoxContainer
	var sig_r: String = ReportsScript._report_sig(spy_r)
	_check(rep_list != null and rep_list.get_child_count() == 1, "Saldıran Reports listesinde tek casusluk kartı render edildi")
	rep_scn.call("_set_report_read", spy_r, true)
	_check(not bool(spy_r.get("unread", true)) and (gs.player.get("read_report_sigs", []) as Array).has(sig_r), "Rapor okundu olarak işaretlenip read_report_sigs dizisine kaydedildi")
	rep_scn.call("_set_report_read", spy_r, false)
	_check(bool(spy_r.get("unread", false)) and not (gs.player.get("read_report_sigs", []) as Array).has(sig_r), "Rapor tekrar okunmadı olarak işaretlenebildi")
	rep_scn.call("_delete_report", spy_r)
	await process_frame
	_check((gs.player.get("deleted_report_sigs", []) as Array).has(sig_r), "Silinen rapor deleted_report_sigs dizisinde kalıcılaştı")
	rep_scn.queue_free()
	await process_frame

	# 7. Baş Vezir Koruma Kalkanı saldırı uyarısı (SendTroopsPanel)
	var stp_scn := (load("res://ui/SendTroopsPanel.tscn") as PackedScene).instantiate()
	root.add_child(stp_scn)
	var v_prot := VM.create(201, "KorunmaliKoy", 30, 30, "KorunmaliLord", false)
	v_prot["protection_until"] = int(Time.get_unix_time_from_system()) + 72000
	v_prot["buildings"]["barracks"] = 1
	v_prot["units"]["spear"] = 20
	v_prot["units"]["spy"] = 5
	var v_real_t := VM.create(202, "RakipKoyu", 34, 30, "RakipLord", false)
	v_real_t["protection_until"] = 0
	var v_barb_t := VM.create(203, "Barbar Koyu", 38, 30, "Barbar", true)
	v_barb_t["is_barbarian"] = true
	stp_scn.call("show_target", v_prot, v_real_t)
	stp_scn._unit_inputs["spear"].value = 10
	stp_scn.call("refresh")
	_check(bool(stp_scn.call("will_drop_attacker_protection")), "Korumalı oyuncu gerçek köye saldırırken Vezir koruma uyarısı tetiklenir")
	stp_scn.btn_attack.emit_signal("pressed")
	await process_frame
	var warn_modal := stp_scn.find_child("VizierProtectionWarningModal", true, false)
	_check(warn_modal != null and is_instance_valid(warn_modal), "Saldır butonuna basınca Baş Vezir koruma kalkanı uyarısı modalı açıldı")
	stp_scn._unit_inputs["spear"].value = 0
	stp_scn._unit_inputs["spy"].value = 3
	stp_scn.call("refresh")
	_check(not bool(stp_scn.call("will_drop_attacker_protection")), "Yalnız casus gönderiminde koruma kalkanı uyarısı çıkmaz")
	stp_scn.call("show_target", v_prot, v_barb_t)
	stp_scn._unit_inputs["spear"].value = 10
	stp_scn.call("refresh")
	_check(not bool(stp_scn.call("will_drop_attacker_protection")), "Barbar köyüne saldırıda koruma kalkanı uyarısı çıkmaz")
	stp_scn.queue_free()
	await process_frame

	vil.queue_free()
	await process_frame
