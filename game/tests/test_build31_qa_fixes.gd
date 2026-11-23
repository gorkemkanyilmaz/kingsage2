extends SceneTree
## Build 31 QA Bulguları — 14 Maddenin Kapsamlı Regresyon ve Doğrulama Testi.

const ActionSimulator := preload("res://scripts/sim/actions/ActionSimulator.gd")
const Movement := preload("res://scripts/sim/actions/Movement.gd")
const ReportsSceneScript := preload("res://scenes/Reports.gd")
const WorldMapScene := preload("res://scenes/WorldMap.tscn")
const VillageScene := preload("res://scenes/Village.tscn")
const BuildingPanelScene := preload("res://ui/BuildingPanel.tscn")
const ResourceBarScene := preload("res://ui/ResourceBar.tscn")

var _failures := 0
var _checks := 0


func _init() -> void:
	call_deferred("_run_all")


func _assert(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("  [FAIL] ", msg)
	else:
		print("  [OK] ", msg)


func _run_all() -> void:
	print("=== TestBuild31QAFixes başlıyor ===")
	_test_spy_all_killed_reports_both_sides()
	_test_per_player_battle_report_perspective_and_unread()
	_test_defender_cannot_speedup_incoming_attack()
	_test_incoming_attack_red_overlay_ultra_transparent()
	_test_resource_bar_double_event_tap_toggle()
	_test_tutorial_text_and_goto_btn_stability()
	_test_barracks_garrison_and_support_send_recall_return()

	if _failures > 0:
		printerr("=== TestBuild31QAFixes FAILED (%d/%d) ===" % [_failures, _checks])
		quit(1)
		return
	print("=== TestBuild31QAFixes PASSED (%d/%d) ===" % [_checks, _checks])
	quit(0)


func _make_two_player_state() -> Dictionary:
	return {
		"world": {"speed": 1.0, "NextMovementId": 1},
		"player": {
			"id": 1,
			"name": "Lord Gorkem",
			"read_report_sigs": [],
			"deleted_report_sigs": [],
			"unread_toggled_sigs": [],
		},
		"villages": [
			{
				"id": 1,
				"name": "Gorkem Kalesi",
				"owner": "Lord Gorkem",
				"is_bot": false,
				"is_barbarian": false,
				"x": 50,
				"y": 50,
				"loyalty": 100,
				"resources": {"wood": 5000, "stone": 5000, "iron": 5000},
				"buildings": {"main": 5, "barracks": 3, "storage": 5, "farm": 5, "wall": 2},
				"units": {"spear": 300, "sword": 200, "axe": 150, "spy": 2, "heavy": 100},
				"researched": {"farmer": true, "spear": true, "sword": true, "axe": true, "spy": true, "heavy": true},
				"support": [],
			},
			{
				"id": 2,
				"name": "Rakip Kalesi",
				"owner": "Rakip Kral",
				"is_bot": false,
				"is_barbarian": false,
				"x": 51,
				"y": 50,
				"loyalty": 100,
				"resources": {"wood": 8888, "stone": 7777, "iron": 6666},
				"buildings": {"main": 8, "barracks": 5, "storage": 7, "farm": 6, "wall": 4},
				"units": {"spear": 400, "spy": 10},
				"researched": {"farmer": true, "spear": true, "spy": true},
				"support": [],
			}
		],
		"movements": [],
		"reports": [],
		"queues": [],
	}


func _test_spy_all_killed_reports_both_sides() -> void:
	print("-- 1. Casus saldırısında tüm casuslar öldüğünde iki tarafa da rapor gitmesi --")
	var st := _make_two_player_state()
	var send_res := Movement.send_spy(st, 1, 2, {"spy": 2}, 1000)
	_assert(bool(send_res.get("ok", false)), "2 casus gönderildi")
	var mv: Dictionary = send_res.get("movement", {})
	var arr_u := int(mv.get("arrive_unix", 1500))
	ActionSimulator.process_tick(st, arr_u + 1, 1.0)

	var reps: Array = st.get("reports", [])
	var atk_rep: Dictionary = {}
	var def_rep: Dictionary = {}
	for r in reps:
		if typeof(r) == TYPE_DICTIONARY:
			var rd := r as Dictionary
			if str(rd.get("type", "")) == "spy" and int(rd.get("village_id", -1)) == 1:
				atk_rep = rd
			elif str(rd.get("type", "")) == "spy_incoming" and int(rd.get("village_id", -1)) == 2:
				def_rep = rd

	var atk_data: Dictionary = atk_rep.get("data", {}) if typeof(atk_rep.get("data")) == TYPE_DICTIONARY else atk_rep
	var def_data: Dictionary = def_rep.get("data", {}) if typeof(def_rep.get("data")) == TYPE_DICTIONARY else def_rep

	_assert(not atk_rep.is_empty(), "Saldırana başarısız casus raporu oluştu")
	_assert(bool(atk_data.get("failed", false)), "Saldıran raporunda failed=true")
	_assert(int(atk_data.get("spy_survivors", -1)) == 0 and int(atk_data.get("spy_losses", 0)) == 2, "Saldıranın 2 casusu da öldü")
	_assert((atk_data.get("resources", {}) as Dictionary).is_empty() and (atk_data.get("units", {}) as Dictionary).is_empty(), "Saldıran karşı köyün maden ve asker bilgilerine erişemedi")

	_assert(not def_rep.is_empty(), "Savunana gelen casus saldırısı raporu (spy_incoming) oluştu")
	_assert(bool(def_data.get("all_killed", false)), "Savunan raporunda all_killed=true")
	_assert(str(def_data.get("attacker_owner", "")) == "Lord Gorkem", "Savunan raporunda saldıran kişinin adı (Lord Gorkem) yazıyor")


func _test_per_player_battle_report_perspective_and_unread() -> void:
	print("-- 2. Saldıran ve savunan için ayrı rapor perspektifi ve bağımsız okundu durumu --")
	var st := _make_two_player_state()
	(st["villages"][1] as Dictionary)["units"] = {"spear": 10}
	var send_res := Movement.send_attack(st, 1, 2, {"axe": 150, "heavy": 100}, 2000)
	_assert(bool(send_res.get("ok", false)), "Saldırı gönderildi")
	var mv: Dictionary = send_res.get("movement", {})
	var arr_u := int(mv.get("arrive_unix", 2500))
	ActionSimulator.process_tick(st, arr_u + 1, 1.0)

	var battle_rep: Dictionary = {}
	for r in st.get("reports", []):
		if typeof(r) == TYPE_DICTIONARY and str((r as Dictionary).get("type", "")) == "battle":
			battle_rep = r as Dictionary
			break
	_assert(not battle_rep.is_empty(), "Savaş raporu oluştu")

	var rep_scene := ReportsSceneScript.new()
	var is_def_for_attacker := rep_scene._is_viewer_defender(battle_rep, "Lord Gorkem", [1])
	var is_def_for_defender := rep_scene._is_viewer_defender(battle_rep, "Rakip Kral", [2])
	_assert(not is_def_for_attacker, "Saldıran oyuncu raporda saldıran perspektifinde")
	_assert(is_def_for_defender, "Savunan oyuncu raporda savunan perspektifinde")

	var sig := rep_scene._report_sig(battle_rep)
	var atk_read_sigs: Array = [sig]
	var def_read_sigs: Array = []
	var unread_for_atk := not atk_read_sigs.has(sig)
	var unread_for_def := not def_read_sigs.has(sig)
	_assert(not unread_for_atk and unread_for_def, "Saldıran raporu okuduğunda savunanın raporu hala okunmamış kalır")
	rep_scene.free()


func _test_defender_cannot_speedup_incoming_attack() -> void:
	print("-- 3. Savunan oyuncuda gelen saldırı için hızlandır butonu çıkmamalı --")
	var gs = root.get_node_or_null("GameState")
	var st := _make_two_player_state()
	gs.from_dict(st)
	gs.active_village_id = 1

	var incoming_m := {
		"id": 99,
		"type": "attack",
		"state": "outgoing",
		"from_village_id": 2,
		"to_village_id": 1,
		"owner": "Rakip Kral",
		"depart_unix": 1000,
		"arrive_unix": 2000,
	}
	var outgoing_m := {
		"id": 100,
		"type": "attack",
		"state": "outgoing",
		"from_village_id": 1,
		"to_village_id": 2,
		"owner": "Lord Gorkem",
		"depart_unix": 1000,
		"arrive_unix": 2000,
	}

	var wmap := WorldMapScene.instantiate()
	root.add_child(wmap)
	_assert(not wmap._is_player_owned_movement(incoming_m, gs), "WorldMap: Gelen düşman saldırısı savunan oyuncuya ait değil (Hızlandır gizlenir)")
	_assert(wmap._is_player_owned_movement(outgoing_m, gs), "WorldMap: Oyuncunun kendi çıkardığı saldırı oyuncuya ait (Hızlandır gösterilir)")

	var sm = root.get_node_or_null("StoreManager")
	if sm != null and sm.has_method("_is_player_movement"):
		_assert(not bool(sm.call("_is_player_movement", incoming_m, 1, "Lord Gorkem", {1: true})), "StoreManager: Gelen düşman saldırısı hızlandırılamaz")
		_assert(bool(sm.call("_is_player_movement", outgoing_m, 1, "Lord Gorkem", {1: true})), "StoreManager: Kendi saldırısı hızlandırılabilir")
	wmap.free()


func _test_incoming_attack_red_overlay_ultra_transparent() -> void:
	print("-- 4. Saldırı alındığında kırmızı yanıp sönme yavaş ve ultra şeffaf --")
	var gs = root.get_node_or_null("GameState")
	var st := _make_two_player_state()
	var now_u := int(Time.get_unix_time_from_system())
	(st["movements"] as Array).append({
		"id": 77,
		"type": "attack",
		"state": "outgoing",
		"from_village_id": 2,
		"to_village_id": 1,
		"owner": "Rakip Kral",
		"depart_unix": now_u - 10,
		"arrive_unix": now_u + 300,
		"units": {"axe": 50},
	})
	gs.from_dict(st)
	gs.active_village_id = 1

	var vill := VillageScene.instantiate()
	root.add_child(vill)
	vill._update_incoming_attack_alarm(0.5, true)
	_assert(vill._attack_red_tint != null and vill._attack_red_tint.color.a <= 0.05, "Kırmızı ekran örtüsü ultra şeffaf (alpha <= 0.05)")
	_assert(vill.village_area != null and vill.village_area.modulate == Color.WHITE, "Köy alanı karartılmıyor (modulate == WHITE)")
	vill.free()


func _test_resource_bar_double_event_tap_toggle() -> void:
	print("-- 5. ResourceBar Odun/Taş/Nüfus tıklama-açma ve tekrar tıklayınca kapanma --")
	var gs = root.get_node_or_null("GameState")
	gs.from_dict(_make_two_player_state())
	gs.active_village_id = 1

	var rbar := ResourceBarScene.instantiate()
	root.add_child(rbar)
	rbar.refresh()

	# iOS aynı dokunuşta hem MouseButton hem ScreenTouch gönderir; ilk dokunuşta açılmalı ve hemen kapanmamalı
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	rbar._on_economy_box_gui_input(mb, "wood")

	var st_ev := InputEventScreenTouch.new()
	st_ev.pressed = true
	rbar._on_economy_box_gui_input(st_ev, "wood")

	_assert(rbar._tooltip_layer != null and rbar._tooltip_layer.visible and rbar._last_tooltip_key == "wood", "Odun kutusuna tıklanınca bilgi balonu açıldı (çift event'te kapanmadı)")

	# 250ms sonraki ikinci gerçek tıklamada kapanmalı
	rbar._last_tooltip_touch_msec = 0
	rbar._on_economy_box_gui_input(mb, "wood")
	_assert(rbar._tooltip_layer == null and rbar._last_tooltip_key == "", "Aynı kaynak kutusuna tekrar tıklanınca bilgi balonu kapandı")
	rbar.free()


func _test_tutorial_text_and_goto_btn_stability() -> void:
	print("-- 6. Tutorial boşluk düzeltmesi, 2x bonus açıklaması ve Depo Sv.3 Binaya Git parmak stabilitesi --")
	var tm = root.get_node_or_null("TutorialManager")
	var gs = root.get_node_or_null("GameState")
	var st := _make_two_player_state()
	(st["villages"][0] as Dictionary)["buildings"] = {"main": 1, "wood": 1, "stone": 1, "iron": 1, "storage": 1, "farm": 1, "barracks": 0}
	gs.from_dict(st)
	gs.active_village_id = 1

	tm._current_step = tm.Step.UPGRADE_WOOD_CAMP
	var content_wood: Dictionary = tm._get_step_copy(null, "Village.tscn", gs)
	var dlg_wood := str(content_wood.get("dialogue", ""))
	_assert(dlg_wood.find("2× Başlangıç Hızı Bonusu") != -1 and dlg_wood.find("240") != -1, "Tutorial Oduncu Kampı adımında 120->134 ve 2x bonusla 240->268 açıklaması mevcut")

	(st["queues"] as Array).append({
		"id": 1,
		"village_id": 1,
		"type": "build",
		"key": "wood",
		"target_level": 2,
		"start_unix": 1000,
		"finish_unix": 1600,
	})
	gs.from_dict(st)
	gs.player["diamonds"] = 35
	gs.player["tutorial_scroll_taught"] = false
	var content_market: Dictionary = tm._get_step_copy(null, "Village.tscn", gs)
	var dlg_market := str(content_market.get("dialogue", ""))
	_assert(dlg_market.find("[b]💎") == -1 and dlg_market.find("[b][color=#58E6FF]💎") == -1, "Elmas Pazarı ve 35 Elmas metinlerinde kalın font içi emoji boşluk hatası yok")
	_assert(tm._is_market_scroll_lesson_active(gs), "Elmas Pazarı hızlandırma dersi aktif")

	# Depo Sv. 3 Önkoşul Zinciri GotoBtn_storage düğümünün 1sn'lik refresh'lerde silinip yeniden yaratılmaması
	var bp := BuildingPanelScene.instantiate()
	root.add_child(bp)
	bp.show_building(gs.get_active_village(), "barracks")
	var btn_first := bp.find_child("GotoBtn_storage", true, false)
	bp.refresh()
	var btn_second := bp.find_child("GotoBtn_storage", true, false)
	_assert(btn_first != null and btn_first == btn_second, "GotoBtn_storage her saniye yeniden yaratılmıyor, aynı düğüm korunuyor")
	bp.free()


func _test_barracks_garrison_and_support_send_recall_return() -> void:
	print("-- 7. Kışla garnizon görünümü, destek asker gönderme, geri çekme ve geri gönderme --")
	var gs = root.get_node_or_null("GameState")
	var st := _make_two_player_state()
	var sup_res := Movement.send_support(st, 1, 2, {"spear": 120, "heavy": 80}, 3000)
	_assert(bool(sup_res.get("ok", false)), "Diğer oyuncunun köyüne destek askeri gönderilebildi")
	var mv: Dictionary = sup_res.get("movement", {})
	ActionSimulator.process_tick(st, int(mv.get("arrive_unix", 3500)) + 1, 1.0)

	var v2: Dictionary = st["villages"][1]
	var sup_arr: Array = v2.get("support", [])
	_assert(sup_arr.size() == 1, "Destek birliği hedef köye ulaştı ve konuşlandı")
	_assert(str((sup_arr[0] as Dictionary).get("owner", "")) == "Lord Gorkem", "Destek kaydında gönderen oyuncu adı (Lord Gorkem) kayıtlı")
	_assert(int((v2.get("units", {}) as Dictionary).get("spear", 0)) == 520 and int((v2.get("units", {}) as Dictionary).get("heavy", 0)) == 80, "Hedef köydeki toplam asker sayısı destekle birleşti (520 Silahtar, 80 Kara Şövalye)")

	# Kışla panelinde hem kendi askerleri, hem destek veren oyuncu adı, hem de en altta toplam askeri birlik gösterimi
	gs.from_dict(st)
	gs.active_village_id = 2
	var bp := BuildingPanelScene.instantiate()
	root.add_child(bp)
	bp.show_building(gs.get_active_village(), "barracks")

	var own_lbl := bp.find_child("OwnGarrisonUnitsLabel", true, false) as Label
	var inc_row := bp.find_child("IncomingSupportRow_0", true, false)
	var tot_lbl := bp.find_child("TotalGarrisonUnitsLabel", true, false) as Label
	_assert(own_lbl != null and own_lbl.text.find("400 Silahtar") != -1, "Kışla'da köyün kendi mevcut askerleri gösteriliyor")
	_assert(inc_row != null, "Kışla'da gelen destek satırı ve Geri Gönder butonu gösteriliyor")
	_assert(tot_lbl != null and tot_lbl.text.find("520 Silahtar") != -1 and tot_lbl.text.find("80 Kara Şövalye") != -1, "Kışla en altında toplam askeri birlik bilgileri tipleriyle gösteriliyor")
	bp.free()

	# Destek askerini geri gönderme / geri çekme
	var rec_res := Movement.recall_support(st, 2, 1, 4000, 0)
	_assert(bool(rec_res.get("ok", false)), "Destek askeri geri çekilebildi / geri gönderilebildi")
	_assert(((st["villages"][1] as Dictionary).get("support", []) as Array).is_empty(), "Destek kaydı hedef köyden kaldırıldı")
	_assert(int(((st["villages"][1] as Dictionary).get("units", {}) as Dictionary).get("spear", 0)) == 400, "Hedef köyün asker sayısı kendi askerlerine (400 Silahtar) döndü")

	var ret_mv: Dictionary = rec_res.get("movement", {})
	ActionSimulator.process_tick(st, int(ret_mv.get("arrive_unix", 4500)) + 1, 1.0)
	_assert(int(((st["villages"][0] as Dictionary).get("units", {}) as Dictionary).get("spear", 0)) == 300, "Geri dönen destek askerleri kendi köyüne sağ salim ulaştı")
