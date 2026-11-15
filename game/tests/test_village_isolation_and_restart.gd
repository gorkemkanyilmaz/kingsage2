extends SceneTree
## test_village_isolation_and_restart.gd — Köy bazlı izolasyon ve tüm köyler fethedildiğinde "Oyuna Tekrar Başla" E2E testi.

var _passed := 0
var _failed := 0

const EconomyAPIScript := preload("res://scripts/sim/economy/EconomyAPI.gd")
const ArmyAPIScript := preload("res://scripts/sim/army/ArmyAPI.gd")
const VillageModelScript := preload("res://scripts/model/VillageModel.gd")


func _check(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("  [PASS] ", msg)
	else:
		_failed += 1
		push_error("  [FAIL] " + msg)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== KÖY İZOLASYONU & FETİH SONRASI YENİDEN BAŞLAMA TESTİ ===")

	var gd := root.get_node("GameData")
	if gd != null and not gd.is_loaded():
		gd.load_all()
	var gs := root.get_node("GameState")
	var wm := root.get_node("WorldManager")
	var sm := root.get_node("SaveManager")
	var auth := root.get_node("AuthManager")
	var eb := root.get_node("EventBus")

	# ------------------------------------------------------------------
	# 1. Aynı oyuncunun 2 köyü arasındaki tam izolasyon (Bina / Araştırma / Eğitim)
	# ------------------------------------------------------------------
	wm.reset_all_worlds()
	var p_multi := "Lord CiftKoy"
	_check(wm.join_world(1, p_multi, 40, 40), "Oyuncu 1 Dünya 1'e katıldı")
	_check(wm.enter_world(1, p_multi), "Oyuncu 1 dünyaya girdi")

	var v1_id := int(gs.active_village_id)
	var v2 := VillageModelScript.create(9001, "Fethedilen İkinci Köy", 80, 80, p_multi, false)
	gs.villages.append(v2)
	var v2_id := 9001

	# V1 ve V2'ye bina + kaynak ver
	var state: Dictionary = gs.to_dict()
	var st_v1 := {}
	var st_v2 := {}
	for sv in state["villages"]:
		if int(sv.get("id", -1)) == v1_id:
			st_v1 = sv
		elif int(sv.get("id", -1)) == v2_id:
			st_v2 = sv

	st_v1["buildings"]["barracks"] = 3
	st_v1["resources"] = {"wood": 5000, "stone": 5000, "iron": 5000}
	st_v2["buildings"]["barracks"] = 3
	st_v2["resources"] = {"wood": 5000, "stone": 5000, "iron": 5000}
	var v2_wood_before_all := int(st_v2["buildings"]["wood"])
	var v2_main_before := int(st_v2["buildings"]["main"])

	# V1'de Oduncu yükselt, Baltacı (axe) araştır ve 5 Silahtar (spear) eğit
	var b_res := EconomyAPIScript.start_build(st_v1, "wood", state)
	_check(bool(b_res.get("ok", false)), "Köy 1'de Oduncu yükseltme başlatıldı")
	st_v1["researched"]["spear"] = true
	var r_res := ArmyAPIScript.start_research(st_v1, "axe", state, 1000)
	_check(bool(r_res.get("ok", false)), "Köy 1'de Baltacı araştırması başlatıldı")
	var t_res := ArmyAPIScript.start_training(st_v1, "spear", 5, state, 1000)
	_check(bool(t_res.get("ok", false)), "Köy 1'de 5 Silahtar eğitimi başlatıldı")

	# Simülasyonu ilerlet (tüm kuyruklar bitsin)
	var EconSim := load("res://scripts/sim/economy/EconomySimulator.gd")
	var ArmySim := load("res://scripts/sim/army/ArmySimulator.gd")
	var finish_now := int(Time.get_unix_time_from_system()) + 1000000
	EconSim.process_tick(state, finish_now, 10.0)
	ArmySim.process_tick(state, finish_now, 10.0)

	_check(int(st_v1["buildings"]["wood"]) == v2_wood_before_all + 1, "Köy 1 Oduncu seviyesi arttı")
	_check(int(st_v2["buildings"]["wood"]) == v2_wood_before_all, "Köy 2 Oduncu seviyesi DEĞİŞMEDİ")
	_check(int(st_v2["buildings"]["main"]) == v2_main_before, "Köy 2 Kale seviyesi DEĞİŞMEDİ")
	_check(bool(st_v1.get("researched", {}).get("axe", false)), "Köy 1'de Baltacı araştırıldı")
	_check(not bool(st_v2.get("researched", {}).get("axe", false)), "Köy 2'de Baltacı ARAŞTIRILMADI (her köyün araştırması ayrı)")
	_check(int(st_v1.get("units", {}).get("spear", 0)) == 5, "Köy 1'de 5 Silahtar üretildi")
	_check(int(st_v2.get("units", {}).get("spear", 0)) == 0, "Köy 2'de asker sayısı DEĞİŞMEDİ (0)")
	_check(int(st_v2["resources"]["wood"]) == 5000, "Köy 2 hammaddeleri DEĞİŞMEDİ (5000)")

	# ------------------------------------------------------------------
	# 2. İki telefon / iki oyuncu izolasyonu + Tüm köylerin fethi -> Yeniden Başla UI akışı
	# ------------------------------------------------------------------
	wm.reset_all_worlds()
	var p1 := "Lord Fatih"
	var p2 := "Lord Yenik"
	_check(wm.join_world(1, p1, 35, 35), "Telefon 1 (%s) Dünya 1'e katıldı" % p1)
	_check(wm.join_world(1, p2, 165, 165), "Telefon 2 (%s) Dünya 1'e katıldı" % p2)

	# AuthManager'ı P2 olarak ayarla ve Village sahnesini aç (gerçek telefon görünümü)
	if auth != null:
		auth.is_logged_in = true
		auth.auth_provider = "google"
		auth.display_name = p2
		auth.user_id = "test_p2_uid"
	_check(wm.enter_world(1, p2), "Telefon 2 (%s) dünyaya bağlandı" % p2)

	var p2_old_vid := int(gs.active_village_id)
	var p2_old_v: Dictionary = gs.get_active_village()
	var p2_old_x := int(p2_old_v.get("x", -1))
	var p2_old_y := int(p2_old_v.get("y", -1))
	_check(p2_old_vid > 0 and p2_old_x > 0, "P2 başlangıç köyü aktif (%d|%d)" % [p2_old_x, p2_old_y])

	# Birkaç bina / görev / tutorial ilerlemesi simüle edelim (yeniden başlayınca sıfırlandığını kanıtlamak için)
	p2_old_v["buildings"]["main"] = 4
	gs.player["tutorial_completed"] = true
	gs.player["quests"] = {"claimed": ["q_upgrade_castle_3"], "stats": {"spies_sent": 2}}
	wm.save_active_world()
	sm.save_game()
	_check(sm.has_save(), "Fetih öncesi P2 SaveManager.has_save() == true")

	var v_scene: PackedScene = load("res://scenes/Village.tscn")
	var v_inst: Control = v_scene.instantiate()
	root.add_child(v_inst)
	set_current_scene(v_inst)
	await create_timer(0.1).timeout

	# P1, P2'nin son (tek) köyünü fethetsin!
	p2_old_v["owner"] = p1
	p2_old_v["protection_until"] = 0
	p2_old_v["realm_of_power"] = 40
	eb.village_conquered.emit(p2_old_vid, p1)
	await create_timer(0.15).timeout

	_check(bool(wm.is_player_conquered(1, p2)), "WorldManager: P2 tüm köylerini kaybetti (is_player_conquered == true)")
	_check(int(gs.active_village_id) == -1, "GameState: tüm köyler kaybedilince active_village_id == -1")
	_check(not bool(sm.has_save()), "SaveManager: tüm köyler fethedilince bayat kayda devam engellendi (has_save == false)")

	var modal := root.get_node_or_null("ConqueredOverlay")
	_check(modal != null and is_instance_valid(modal), "Tüm köyler kaybedilince 'ConqueredOverlay' ekranı açıldı")
	if modal != null:
		var title_lbl := modal.find_child("TitleLabel", true, false) as Label
		var desc_lbl := modal.find_child("DescLabel", true, false) as Label
		var btn_restart := modal.find_child("BtnRestartGame", true, false) as Button
		_check(title_lbl != null and title_lbl.text.contains("KAYBETTİNİZ"), "Başlık 'TÜM KÖYLERİNİZİ KAYBETTİNİZ!' görüntülendi")
		_check(desc_lbl != null and desc_lbl.text.contains(p1), "Açıklamada fetheden oyuncu (%s) bilgisi yer aldı" % p1)
		_check(btn_restart != null and btn_restart.text.contains("Oyuna Tekrar Başla"), "'Oyuna Tekrar Başla' butonu mevcut")

		# 'Oyuna Tekrar Başla' butonuna tıkla (varsayılan Rastgele Farklı Lokasyon seçili)
		if btn_restart != null:
			btn_restart.pressed.emit()
		await create_timer(0.25).timeout

	_check(root.get_node_or_null("ConqueredOverlay") == null, "Yeniden başlandıktan sonra ConqueredOverlay kapandı")
	_check(not bool(wm.is_player_conquered(1, p2)), "Yeniden başladıktan sonra is_player_conquered == false")
	_check(bool(wm.has_player_village(1, p2)), "P2 yeni köyüne sahip")

	var p2_new_vid := int(gs.active_village_id)
	var p2_new_v: Dictionary = gs.get_active_village()
	var p2_new_x := int(p2_new_v.get("x", -1))
	var p2_new_y := int(p2_new_v.get("y", -1))
	var dist := Vector2(p2_old_x, p2_old_y).distance_to(Vector2(p2_new_x, p2_new_y))
	_check(p2_new_vid != p2_old_vid and p2_new_vid > 0, "Yeni köy ID (%d) eski fethedilen köyden (%d) farklı" % [p2_new_vid, p2_old_vid])
	_check(dist >= 20.0, "Yeni lokasyon (%d|%d) eski lokasyondan (%d|%d) tamamen farklı (mesafe=%.1f)" % [p2_new_x, p2_new_y, p2_old_x, p2_old_y, dist])
	_check(int(p2_new_v.get("buildings", {}).get("main", 0)) == 1, "Yeni köy Kale Lv.1 olarak sıfırdan başladı")
	_check(int(p2_new_v.get("buildings", {}).get("barracks", -1)) == 0, "Yeni köyde Kışla Lv.0 olarak sıfırdan başladı")
	_check(int(p2_new_v.get("resources", {}).get("wood", 0)) == 1000, "Yeni köy hammaddeleri sıfırdan 1000 olarak verildi")
	_check(not bool(gs.player.get("tutorial_completed", true)), "Tutorial sıfırdan tekrar başlatıldı")
	_check((gs.player.get("quests", {}).get("claimed", []) as Array).is_empty(), "Görevler sıfırlandı")

	# P1'in kendi köyü ve fethettiği P2 eski köyü aynen korunuyor olmalı
	var p1_owned := 0
	for wv in wm.load_world_dict(1).get("state", {}).get("villages", []):
		if typeof(wv) == TYPE_DICTIONARY and str(wv.get("owner", "")) == p1:
			p1_owned += 1
	_check(p1_owned == 2, "P1'in 2 köyü (kendi + fethettiği eski P2 köyü) korundu (sahip=%d)" % p1_owned)

	# Temizlik
	var tm := root.get_node_or_null("TutorialManager")
	if tm != null and tm.has_method("skip_tutorial"):
		tm.skip_tutorial()
	var left_modal := root.get_node_or_null("ConqueredOverlay")
	if left_modal != null:
		left_modal.queue_free()
	if current_scene != null and is_instance_valid(current_scene):
		current_scene.queue_free()

	print("\n=== SONUÇ: PASS=%d FAIL=%d ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
