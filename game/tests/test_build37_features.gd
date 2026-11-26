extends SceneTree

const RE := preload("res://scripts/rules/RulesEngine.gd")
const VM := preload("res://scripts/model/VillageModel.gd")
const BS := preload("res://scripts/sim/battle/BattleSimulator.gd")
const AM := preload("res://scripts/model/AllianceModel.gd")
const MOV := preload("res://scripts/sim/actions/Movement.gd")
const ARR := preload("res://scripts/sim/actions/Arrival.gd")
const WM_SCRIPT := preload("res://autoload/WorldManager.gd")

var _passed := 0
var _failed := 0


func _assert(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("PASS: ", msg)
	else:
		_failed += 1
		push_error("FAIL: " + msg)
		print("FAIL: ", msg)


func _tick(n: int = 2) -> void:
	for _i in range(n):
		await process_frame


func _initialize() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	var gd = root.get_node_or_null("GameData")
	if gd != null and gd.has_method("load_all"):
		gd.load_all(true)
	var gc = root.get_node_or_null("GameConfig")
	if gc != null:
		gc.set("speed", 1.0)
	var wm = root.get_node_or_null("WorldManager")
	if wm != null:
		wm.set("_suppress_reset_save", true)

	await _test_resources_continuity_and_sync()
	await _test_mill_population_table()
	_test_kingsage_battle_loss_rule()
	await _test_alliance_diplomacy_crown_and_no_ff()
	await _test_support_to_all_villages()
	await _test_barracks_categorized_garrison()

	print("")
	print("BUILD 37 TEST OZETI: %d BASARILI, %d BASARISIZ" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _test_resources_continuity_and_sync() -> void:
	print("\n-- 1. Hammadde Üretim Sürekliliği & Bulut Çakışma Koruması --")
	var gs = root.get_node_or_null("GameState")
	var sm = root.get_node_or_null("SaveManager")
	var wm = root.get_node_or_null("WorldManager")
	_assert(gs != null and sm != null and wm != null, "Autoloadlar mevcut")

	var now := int(Time.get_unix_time_from_system())
	var v := VM.create(51, "Baskent2", 100, 100, "TestLord", false)
	VM.set_building_level(v, "wood", 10)
	VM.set_building_level(v, "stone", 10)
	VM.set_building_level(v, "iron", 10)
	VM.set_building_level(v, "storage", 15)
	v["resources"] = {"wood": 500, "stone": 500, "iron": 500}
	v["last_resource_unix"] = now - 3600

	gs.villages = [v]
	gs.active_village_id = 51
	gs.player["name"] = "TestLord"
	gs.world["last_saved_unix"] = now

	# Başka bir oyuncu world.last_saved_unix'i şimdiye çekse bile köyün last_resource_unix'ine göre telafi yapılmalı
	sm._apply_offline_catchup(gs, now)
	var after_v: Dictionary = gs.get_village(51)
	_assert(int(after_v["resources"]["wood"]) > 750, "last_resource_unix (1 saat geri) telafi edildi -> odun=%d" % int(after_v["resources"]["wood"]))
	_assert(int(after_v.get("last_resource_unix", 0)) >= now, "last_resource_unix güncellendi")

	# WorldManager._preserve_own_village_progress_from_local canlı yerel hammaddeleri eski bulut anketinden korumalı
	var local_v := after_v.duplicate(true)
	local_v["resources"] = {"wood": 2400, "stone": 2300, "iron": 2200}
	local_v["last_resource_unix"] = now + 20
	var cloud_v := after_v.duplicate(true)
	cloud_v["resources"] = {"wood": 0, "stone": 0, "iron": 0}
	cloud_v["last_resource_unix"] = now
	var target_w := {"world_id": 1, "state": {"villages": [cloud_v], "reports": [], "queues": []}}
	var local_w := {"world_id": 1, "state": {"villages": [local_v], "reports": [], "queues": []}}
	wm._preserve_own_village_progress_from_local(target_w, local_w, "TestLord")
	var preserved: Dictionary = target_w["state"]["villages"][0]
	_assert(int(preserved["resources"]["wood"]) == 2400, "Canlı hammadde bulut anketinde sıfırlanmadı (2400)")


func _test_mill_population_table() -> void:
	print("\n-- 2. Değirmen Seviye / Kullanılan Nüfus Tablosu --")
	var gs = root.get_node_or_null("GameState")
	var v := VM.create(52, "DeğirmenKöy", 102, 102, "TestLord", false)
	VM.set_building_level(v, "main", 8)
	VM.set_building_level(v, "farm", 5) # maks 385
	VM.set_building_level(v, "barracks", 6)
	v["units"] = {"axe": 200, "spear": 50}
	gs.villages = [v]
	gs.queues = []
	gs.active_village_id = 52

	var panel = load("res://ui/BuildingPanel.tscn").instantiate()
	root.add_child(panel)
	panel.show_building(v, "farm")
	await _tick(2)

	var cur_row = panel.find_child("MillCurrentRow", true, false)
	var next_row = panel.find_child("MillNextRow_6", true, false)
	var next_row_9 = panel.find_child("MillNextRow_9", true, false)
	_assert(cur_row != null and next_row != null and next_row_9 != null, "Değirmen güncel ve sonraki 4 seviye satırları oluşturuldu")

	var found_ratio := false
	for lbl in panel.find_children("*", "Label", true, false):
		var t := (lbl as Label).text
		if t.contains("/ 385"):
			found_ratio = true
			break
	_assert(found_ratio, "Değirmen satırında 'kullanılan / 385' formatı gösteriliyor")
	panel.queue_free()


func _test_kingsage_battle_loss_rule() -> void:
	print("\n-- 3. KingsAge Savaş Kuralı (Kaybeden Ordu Tamamen Yok Olur) --")
	var atk := {"units": {"axe": 20, "spear": 15}, "buildings": {"barracks": 5}, "points": 1000}
	var dfn := {"units": {"sword": 80, "spear": 60}, "wall_level": 10, "buildings": {"wall": 10}, "has_statue": false, "points": 1200}
	var res := BS.simulate(atk, dfn, {"seed": 77})
	_assert(not bool(res.get("attacker_won", true)), "35 asker güçlü savunmaya karşı kaybetti")
	var atk_alive: Dictionary = res.get("attacker_alive", {})
	var surv_tot := 0
	for k in atk_alive.keys():
		surv_tot += int(atk_alive[k])
	_assert(surv_tot == 0, "Kaybeden 35 askerin tamamı öldü (0 sağ kalan)")

	# Casuslar Faz 2'de bağımsız çözülür
	var spy_atk := {"units": {"axe": 10, "spy": 20}, "buildings": {"barracks": 3}, "points": 1000}
	var spy_res := BS.simulate(spy_atk, dfn, {"seed": 77})
	_assert(int(spy_res["attacker_losses"].get("axe", 0)) == 10, "Kaybeden normal askerler %100 öldü")
	_assert(int(spy_res["attacker_alive"].get("spy", 0)) == 20, "Savunanda casus yokken saldıran casuslar Faz 2'den sağ çıktı")


func _test_alliance_diplomacy_crown_and_no_ff() -> void:
	print("\n-- 4. İttifak Diplomasi, Lider Tacı, Kurucu İç Duyuru & Dost Ateşi Yasağı --")
	var st := {
		"villages": [
			VM.create(1, "Köy A", 10, 10, "KurucuA", false),
			VM.create(2, "Köy B", 12, 10, "ÜyeA", false),
			VM.create(3, "Köy C", 15, 10, "KurucuB", false),
			VM.create(4, "Köy D", 16, 10, "ÜyeB", false),
		],
		"alliances": [],
		"messages": [],
		"movements": [],
		"queues": [],
	}
	st["villages"][0]["units"] = {"axe": 100}
	st["villages"][0]["buildings"]["barracks"] = 3

	var r_a := AM.create_alliance(st, "KurucuA", "Aslanlar", "ASLAN", "Birlik")
	var r_b := AM.create_alliance(st, "KurucuB", "Kartallar", "KRTL", "Güç")
	_assert(bool(r_a.get("ok", false)) and bool(r_b.get("ok", false)), "İki test ittifakı kuruldu")
	var a1: Dictionary = r_a["alliance"]
	var a2: Dictionary = r_b["alliance"]
	_assert(not (a1["diplomacy"] as Dictionary).has("nap"), "Saldırmazlık Paktı (nap) diplomasi yapısından kaldırıldı")

	# Üye ekle ve birbirine saldırı yasağını doğrula (büyük/küçük harf duyarsız)
	AM.invite_player(st, int(a1["id"]), "KurucuA", "ÜyeA")
	AM.accept_invitation(st, "ÜyeA", int(a1["id"]))
	AM.invite_player(st, int(a2["id"]), "KurucuB", "ÜyeB")
	AM.accept_invitation(st, "ÜyeB", int(a2["id"]))

	st["villages"][1]["owner"] = "  üyea " # büyük/küçük harf & boşluk varyasyonu
	var atk_check := MOV.send_attack(st, 1, 2, {"axe": 50}, 1000)
	_assert(not bool(atk_check.get("ok", false)) and str(atk_check.get("code", "")) == "friendly_target", "İttifak üyesine saldırı kesinlikle engellendi")

	# Varış anında da (sonradan ittifaka girmişse) savaş gerçekleşmez
	var arr_res := ARR.resolve(st, {"id": 99, "type": "attack", "from_village_id": 1, "to_village_id": 2, "units": {"axe": 20}}, 2000)
	_assert(str(arr_res.get("return", {}).get("type", "")) == "return", "Varış anında ittifak üyesiyse savaş yapılmayıp ordu geri döner")

	# Kurucu olmayan üye iç duyuru veya diplomasi değiştiremez
	var bad_ann := AM.update_announcement(st, int(a1["id"]), "ÜyeA", "Yetkisiz")
	_assert(not bool(bad_ann.get("ok", false)), "Kurucu olmayan üye iç duyuru güncelleyemedi")
	var ok_ann := AM.update_announcement(st, int(a1["id"]), "KurucuA", "Yeni İç Duyuru Test")
	_assert(bool(ok_ann.get("ok", false)) and str(a1["internal_announcement"]) == "Yeni İç Duyuru Test", "Kurucu lider iç duyuruyu güncelledi")

	# İttifak arama + Müttefik daveti + Kabul
	var found := AM.search_alliances(st, int(a1["id"]), "kartal")
	_assert(found.size() == 1 and str(found[0]["tag"]) == "KRTL", "İttifak adı araması çalışıyor")

	var bad_inv := AM.send_ally_invite(st, int(a1["id"]), "ÜyeA", int(a2["id"]))
	_assert(not bool(bad_inv.get("ok", false)), "Kurucu olmayan üye müttefik daveti gönderemedi")
	var ok_inv := AM.send_ally_invite(st, int(a1["id"]), "KurucuA", int(a2["id"]))
	_assert(bool(ok_inv.get("ok", false)), "Kurucu lider müttefik daveti gönderdi")
	var ok_acc := AM.respond_ally_invite(st, int(a2["id"]), "KurucuB", int(a1["id"]), true)
	_assert(bool(ok_acc.get("ok", false)), "Karşı ittifak kurucusu müttefiklik davetini kabul etti")
	_assert(AM._has_tag(a1["diplomacy"]["allies"], "KRTL") and AM._has_tag(a2["diplomacy"]["allies"], "ASLAN"), "Her iki ittifak karşılıklı müttefik oldu")

	# Düşman ilanı tüm hedef ittifak üyelerine uyarı mesajı göndermeli
	var msg_before := (st["messages"] as Array).size()
	var en_res := AM.declare_enemy(st, int(a1["id"]), "KurucuA", int(a2["id"]))
	_assert(bool(en_res.get("ok", false)), "Düşman ittifak ilan edildi")
	var notified_targets: Dictionary = {}
	for m in (st["messages"] as Array).slice(msg_before):
		if str(m.get("subject", "")).contains("Düşman İlanı"):
			notified_targets[str(m.get("to", ""))] = str(m.get("body", ""))
	_assert(notified_targets.has("KurucuB") and notified_targets.has("ÜyeB"), "Düşman ilanında hedef ittifaktaki TÜM üyelere mesaj gitti")

	# UI kontrolü: Lider sohbet mesajında taç, NAP metni yok, Düzenle butonu görünür
	AM.send_chat_message(st, int(a1["id"]), "KurucuA", "Selam savaşçılar!")
	var gs = root.get_node_or_null("GameState")
	gs.from_dict(st)
	gs.player["name"] = "KurucuA"
	var a_scene = load("res://scenes/Alliance.tscn").instantiate()
	root.add_child(a_scene)
	await _tick(2)
	var has_crown := false
	for lbl in a_scene.find_children("*", "Label", true, false):
		if (lbl as Label).text.contains("👑 KurucuA"):
			has_crown = true
	_assert(has_crown, "İttifak sohbetinde lider adının yanında 👑 Kral Tacı çıktı")
	_assert(a_scene.find_child("EditAnnouncementBtn", true, false) != null, "Kurucu lider için İç Duyuru Düzenle butonu mevcut")

	# Diplomasi sekmesine geçip NAP olmadığını ve arama alanının bulunduğunu doğrula
	a_scene._active_tab = "diplomacy"
	a_scene.refresh_view()
	await _tick(2)
	var has_nap_txt := false
	for lbl in a_scene.find_children("*", "Label", true, false):
		if (lbl as Label).text.to_lower().contains("saldırmazlık") or (lbl as Label).text.to_lower().contains("nap"):
			has_nap_txt = true
	_assert(not has_nap_txt, "Diplomasi sekmesinde Saldırmazlık Paktı / NAP tamamen kaldırıldı")
	_assert(a_scene.find_child("DiplomacySearchInput", true, false) != null, "Diplomasi sekmesinde İttifak arama kutusu mevcut")
	a_scene.queue_free()


func _test_support_to_all_villages() -> void:
	print("\n-- 5. Haritadaki Her Köye Destek Gönderme --")
	var own_v := VM.create(10, "Merkez", 50, 50, "TestLord", false)
	own_v["units"] = {"spear": 40}
	var bot_v := VM.create(11, "Kale Baron", 55, 50, "Baron Bot", true)
	var barb_v := VM.create(12, "Barbar Kampı", 56, 51, "Barbar", false)
	barb_v["is_barbarian"] = true
	var st := {"villages": [own_v, bot_v, barb_v], "alliances": [], "movements": []}
	_assert(bool(MOV.can_send(st, 10, 11, MOV.TYPE_SUPPORT, {"spear": 10}, {}, 1000).get("ok", false)), "Bot köye destek gönderimi izinli")
	_assert(bool(MOV.can_send(st, 10, 12, MOV.TYPE_SUPPORT, {"spear": 10}, {}, 1000).get("ok", false)), "Barbar köye destek gönderimi izinli")

	var panel = load("res://ui/SendTroopsPanel.tscn").instantiate()
	root.add_child(panel)
	panel.show_target(own_v, bot_v)
	await _tick(2)
	var sup_btn := panel.find_child("BtnSupport", true, false) as Button
	_assert(sup_btn != null and sup_btn.visible, "Bot köye tıklandığında Destek Gönder butonu görünür")
	panel.queue_free()


func _test_barracks_categorized_garrison() -> void:
	print("\n-- 6. Kışla Kategorize Askeri Birlik Gösterimi --")
	var gs = root.get_node_or_null("GameState")
	var v := VM.create(60, "KışlaKöy", 80, 80, "TestLord", false)
	VM.set_building_level(v, "barracks", 25)
	VM.set_building_level(v, "farm", 30)
	v["units"] = {"spear": 40, "axe": 25, "bow": 15, "spy": 5, "light": 12, "ram": 4}
	v["researched"] = {"spear": true, "sword": true, "axe": true, "bow": true, "spy": true, "light": true, "ram": true}
	gs.villages = [v]
	gs.active_village_id = 60

	var panel = load("res://ui/BuildingPanel.tscn").instantiate()
	root.add_child(panel)
	panel.show_building(v, "barracks")
	await _tick(2)

	_assert(panel.find_child("OwnCatHeader_infantry", true, false) != null, "Piyade kategorisi kartı oluştu")
	_assert(panel.find_child("OwnCatHeader_ranged_recon", true, false) != null, "Menzilli & Keşif kategorisi kartı oluştu")
	_assert(panel.find_child("OwnCatHeader_cavalry", true, false) != null, "Süvari kategorisi kartı oluştu")
	_assert(panel.find_child("OwnCatHeader_siege_special", true, false) != null, "Kuşatma & Özel kategorisi kartı oluştu")
	_assert(panel.find_child("OwnUnitCard_light", true, false) != null, "Birim kartı (Akıncı) oluştu")
	var tot_lbl := panel.find_child("TotalGarrisonUnitsLabel", true, false) as Label
	_assert(tot_lbl != null and tot_lbl.text.contains("101"), "Toplam Garnizon özeti (101 Asker) doğru")
	panel.queue_free()
