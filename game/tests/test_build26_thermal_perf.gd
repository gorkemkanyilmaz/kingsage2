extends SceneTree
## test_build26_thermal_perf.gd — Build 26 Isınma / CPU-GPU-I/O Optimizasyonu Doğrulama Paketi:
## 1) GameClock adaptif FPS hedefleri (aktif dokunma=60, köy=30, harita sefersiz=20/seferli=30, arkaplan=5, headless max_fps=0)
## 2) GameLoop.simulate() in-place as_live_dict / sync_from_live_dict (sessiz tick'te state_changed spam yok, kaynak artar, olayda state_changed çalışır)
## 3) QuestManager önbellekli _has_claimable_quest parıltısı & _process maliyet temizliği
## 4) Village.gd 192-karelik hareketli arka planın canlı kaldığı + StyleBoxFlat önbelleği + throttled alarm
## 5) WorldMap / BottomNav / BuildingPanel önbellek & redraw kısıtlamaları
## 6) WorldManager değişmeyen bulut yoklamasını atlama & cüzdan değişikliği algılama

const GameLoopScript := preload("res://scripts/core/GameLoop.gd")
const EconomyAPI := preload("res://scripts/sim/economy/EconomyAPI.gd")

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
	var gclk := root.get_node_or_null("GameClock")
	var wm := root.get_node_or_null("WorldManager")
	var sm := root.get_node_or_null("StoreManager")
	var auth := root.get_node_or_null("AuthManager")
	var eb := root.get_node_or_null("EventBus")
	var tm := root.get_node_or_null("TutorialManager")
	var qm := root.get_node_or_null("QuestManager")
	var bgc := root.get_node_or_null("VillageBackgroundCache")

	_assert(gd != null and gc != null and gs != null and gclk != null and wm != null and sm != null and auth != null and eb != null and qm != null and bgc != null, "Core autoloads loaded")
	if gd != null and gd.has_method("load_all"):
		gd.call("load_all", true)
	if tm != null:
		tm.set("tutorial_enabled_in_headless", false)
	if qm != null:
		qm.set("quest_enabled_in_headless", false)

	wm.call("wipe_all_local_data")
	auth.call("clear_all_account_data")
	auth.call("login_with_apple", "Lord Build26", "b26@privaterelay.appleid.com", "apple_uid_b26")
	var joined: bool = bool(wm.call("join_world", 1, "Lord Build26", 100, 100))
	_assert(joined and bool(gs.call("has_active_village")), "World 1 joined cleanly")
	gs.player["tutorial_completed"] = true
	gs.player["tutorial_skipped"] = false

	await _test_adaptive_fps(gclk, gs)
	gclk.call("stop")
	await _test_gameloop_inplace_no_state_spam(gs, eb)
	gclk.call("start")
	await _test_village_quest_bottomnav_worldmap(gs, qm, bgc, wm)
	await _test_cloud_sync_skip_unchanged(gs, wm, eb)

	wm.call("wipe_all_local_data")
	print("\nSONUC: %d BASARILI, %d BASARISIZ" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_adaptive_fps(gclk: Node, gs: Node) -> void:
	print("\n--- 1) GameClock Adaptif FPS Testi ---")
	_assert(Engine.max_fps == 0, "Headless modda Engine.max_fps sınırsız (0) korunur")
	gclk.call("boost_fps", 2.0)
	_assert(int(gclk.call("get_current_target_fps")) == 60, "Etkileşim sonrası adaptif hedef = 60 FPS")

	# Statik/boş sahnede boost bitince 4 FPS (Build 40+ derin tasarruf)
	gclk.set("_fps_boost_remaining", 0.0)
	gclk.call("_apply_adaptive_fps", true)
	_assert(int(gclk.call("get_current_target_fps")) == 4, "Boost süresi dolunca statik sahne hedefi = 4 FPS")

	# Arka plana alınınca 1 FPS, geri gelince 60 FPS
	gclk.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_assert(int(gclk.call("get_current_target_fps")) == 1, "Uygulama arka plana geçince hedef = 1 FPS")
	gclk.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	_assert(int(gclk.call("get_current_target_fps")) == 60, "Uygulama ön plana dönünce hedef = 60 FPS")

	# ScreenTouch eventi tekrar 60 FPS boost verir
	gclk.set("_fps_boost_remaining", 0.0)
	gclk.call("_apply_adaptive_fps", true)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2(200, 400)
	gclk.call("_input", touch)
	_assert(int(gclk.call("get_current_target_fps")) == 60, "ScreenTouch etkileşimi hedefi tekrar 60 FPS yapar")
	var orig_movs: Array = gs.movements
	gs.movements = []
	await _tick(1)
	gs.movements = orig_movs


func _test_gameloop_inplace_no_state_spam(gs: Node, eb: Node) -> void:
	print("\n--- 2) GameLoop In-Place Tick & Sinyal Optimizasyonu Testi ---")
	var pv: Dictionary = gs.call("get_active_village")
	pv["buildings"] = {"main": 5, "wood": 10, "stone": 10, "iron": 10, "storage": 15, "farm": 10}
	pv["resources"] = {"wood": 500.0, "stone": 500.0, "iron": 500.0}
	var start_wood: float = float((pv["resources"] as Dictionary)["wood"])

	var gl := GameLoopScript.new()
	gl.name = "TestGameLoop26"
	root.add_child(gl)
	await _tick(1)

	var base_now: int = int(Time.get_unix_time_from_system())
	for raw_v in gs.villages:
		if typeof(raw_v) == TYPE_DICTIONARY:
			var vd := raw_v as Dictionary
			if bool(vd.get("is_bot", false)):
				vd["next_bot_think_unix"] = base_now + 3600

	var counts := {"res": 0, "state": 0}
	var on_res := func(_vid: int): counts["res"] += 1
	var on_state := func(): counts["state"] += 1
	eb.resources_changed.connect(on_res)
	eb.state_changed.connect(on_state)

	gl.set_now_unix(base_now)
	for _i in range(5):
		gl.simulate(10.0)

	var end_wood: float = float((pv["resources"] as Dictionary)["wood"])
	_assert(end_wood > start_wood, "Sessiz in-place tick sırasında odun üretimi arttı (%.2f -> %.2f)" % [start_wood, end_wood])
	_assert(int(counts["res"]) == 5, "Sessiz ticklerde resources_changed tam 5 kez yayınlandı (%d)" % int(counts["res"]))
	_assert(int(counts["state"]) == 0, "Sessiz ticklerde gereksiz state_changed yayını yapılmadı (count=%d)" % int(counts["state"]))

	# Şimdi anlık bitecek bir inşaat kuyruğu ekleyip yapısal olayda state_changed yayınlandığını doğrula
	var vid: int = int(pv.get("id", 1))
	gs.queues.append({
		"id": 9901,
		"village_id": vid,
		"type": "build",
		"key": "wood",
		"target_level": 11,
		"start_unix": base_now - 10,
		"finish_unix": base_now + 52,
	})
	gl.simulate(5.0)
	_assert(int((pv["buildings"] as Dictionary).get("wood", 10)) == 11, "In-place tick sırasında biten inşaat seviyesi güncellendi (10 -> 11)")
	_assert(int(counts["state"]) >= 1, "Yapısal olay (bina tamamlama) gerçekleştiğinde state_changed yayınlandı (%d)" % int(counts["state"]))

	eb.resources_changed.disconnect(on_res)
	eb.state_changed.disconnect(on_state)
	gl.queue_free()
	await _tick(2)


func _test_village_quest_bottomnav_worldmap(gs: Node, qm: Node, bgc: Node, _wm: Node) -> void:
	print("\n--- 3) Sahne & Arayüz Performans / Canlı Arka Plan Testleri ---")
	_assert(int(bgc.get("FRAME_COUNT")) == 1 and float(bgc.get("FPS")) == 20.0, "VillageBackgroundCache tek dokulu 1080p + 20 FPS ortam katmanı ayarını koruyor")

	# Village sahnesini aç ve current_scene yap (GameClock + QuestManager entegrasyonu için)
	var v_scene: PackedScene = load("res://scenes/Village.tscn")
	var v_node := v_scene.instantiate() as Control
	root.add_child(v_node)
	var prev_scene := current_scene
	current_scene = v_node
	qm.set("quest_enabled_in_headless", true)
	await _tick(3)

	var gclk := root.get_node_or_null("GameClock")
	gclk.set("_fps_boost_remaining", 0.0)
	gclk.call("_apply_adaptive_fps", true)
	_assert(int(gclk.call("get_current_target_fps")) == 20, "Köy sahnesinde boştayken hedef = 20 FPS (60/120 Hz tam bölen, sıfır judder)")

	# Hareketli yel değirmeninin VillageAmbientLayer._process içinde akıcı döndüğünü doğrula
	var amb: Node = v_node.get("ambient_layer")
	_assert(amb != null, "VillageAmbientLayer düğümü mevcut")
	var ang_before: float = float(amb.call("get_windmill_angle")) if amb != null else 0.0
	if amb != null:
		amb.call("_process", 0.12)
	var ang_after: float = float(amb.call("get_windmill_angle")) if amb != null else 0.0
	_assert(not is_equal_approx(ang_after, ang_before), "Yel değirmeni 2D ortam katmanında akıcı dönmeye devam etti (%.3f -> %.3f)" % [ang_before, ang_after])

	# QuestManager önbellekli parıltı bayrağını doğrula (hazır görev yoksa parıltı yok, varsa pulse aktif)
	qm.call("refresh_quests", true)
	var q_list_ctrl: Node = qm.get("_tracker_panel")
	_assert(q_list_ctrl != null, "QuestManager tracker UI kurulu")
	qm.set("_has_claimable_quest", false)
	qm.set("_badge_tinted", true)
	qm.call("_update_claimable_pulse", 0.1)
	_assert(not bool(qm.get("_badge_tinted")), "Hazır görev yokken QuestManager rozet parıltısı tek seferde sıfırlandı")
	qm.set("_has_claimable_quest", true)
	qm.call("_update_claimable_pulse", 0.1)
	_assert(bool(qm.get("_badge_tinted")), "Hazır görev varken QuestManager parıltısı önbellek bayrağıyla aktifleşti")

	# Village queue StyleBox önbelleği & alarm tarama durumu
	_assert(not bool(v_node.get("_alarm_visual_active")), "Saldırı yokken Village saldırı alarmı pasif (_alarm_visual_active=false)")
	var bpanel: Node = v_node.find_child("BuildingPanel", true, false)
	var pv: Dictionary = gs.call("get_active_village")
	if bpanel != null:
		bpanel.call("show_building", pv, "main")
		await _tick(2)
		_assert(bool(bpanel.get("visible")), "BuildingPanel as_live_dict görünümüyle hatasız açıldı")
		bpanel.call("hide")

	# BottomNav kontrolü
	var bnav: Node = v_node.find_child("BottomNav", true, false)
	if bnav != null:
		bnav.call("_process", 0.1)
		_assert(not bool(bnav.get("_has_incoming_alarm")) and not bool(bnav.get("_btn_tinted")), "Saldırı yokken BottomNav alarm animasyonu ve gereksiz modulate kapalı")

	# WorldMap kontrolü (0 hareket -> yeniden çizim yok, hareket varken 30 FPS & çizim var, StyleBox önbelleği)
	var wm_scene: PackedScene = load("res://scenes/WorldMap.tscn")
	var wmap := wm_scene.instantiate() as Control
	root.add_child(wmap)
	current_scene = wmap
	gs.movements = []
	await _tick(2)
	gclk.set("_fps_boost_remaining", 0.0)
	gclk.call("_apply_adaptive_fps", true)
	_assert(int(gclk.call("get_current_target_fps")) == 4, "Harita sahnesinde aktif sefer yokken hedef = 4 FPS")
	wmap.call("_process", 0.1)
	_assert(not bool(wmap.get("_had_movements_drawn")), "Sefer yokken WorldMap movements_layer gereksiz queue_redraw çalıştırmıyor")

	wmap.call("_ensure_map_speedup_styles")
	_assert(wmap.get("_map_speedup_have_sb") != null and wmap.get("_detail_speedup_have_sb") != null, "WorldMap hızlandırma StyleBoxFlat stilleri önbelleğe alındı")

	gs.movements = [{"id": 77, "type": "attack", "state": "outgoing", "from_village_id": int(pv.get("id", 1)), "to_village_id": 2, "arrive_unix": int(Time.get_unix_time_from_system()) + 300}]
	wmap.call("has_visible_movements")
	gclk.call("_apply_adaptive_fps", true)
	_assert(int(gclk.call("get_current_target_fps")) == 10, "Haritada aktif sefer varken hedef = 10 FPS")
	wmap.call("_process", 0.1)
	_assert(bool(wmap.get("_had_movements_drawn")), "Aktif sefer varken WorldMap hareket çizimi etkin")
	gs.movements = []
	wmap.call("_process", 0.1)
	_assert(not bool(wmap.get("_had_movements_drawn")), "Sefer bitince WorldMap çizim bayrağını sıfırladı")

	current_scene = prev_scene
	qm.set("quest_enabled_in_headless", false)
	wmap.queue_free()
	v_node.queue_free()
	await _tick(3)


func _test_cloud_sync_skip_unchanged(gs: Node, wm: Node, eb: Node) -> void:
	print("\n--- 4) Akıllı Bulut Yoklaması (Değişmeyen Veriyi Atlama) Testi ---")
	_assert(is_equal_approx(float(wm.get("CLOUD_POLL_INTERVAL_SEC")), 90.0), "WorldManager CLOUD_POLL_INTERVAL_SEC = 90.0 sn")
	var now: int = int(Time.get_unix_time_from_system()) + 50
	var snap: Dictionary = gs.to_dict()
	var cloud_resp := {
		"ok": true,
		"diamonds": 35,
		"scrolls": {},
		"updated_unix": now,
		"cloud_state": {
			"world_id": 1,
			"last_saved_unix": now,
			"registered_real_players": ["Lord Build26"],
			"state": snap,
		},
	}

	var st_emits := [0]
	var on_st := func(): st_emits[0] += 1
	eb.state_changed.connect(on_st)

	var ok1: bool = bool(wm.call("apply_cloud_sync", cloud_resp, false, -1))
	_assert(ok1, "İlk bulut yoklaması başarıyla uygulandı")
	var sig_map: Dictionary = wm.get("_last_cloud_poll_sig_by_world")
	_assert(not str(sig_map.get(1, "")).is_empty(), "İlk yoklama sonrası Dünya 1 önbellek imzası kaydedildi")

	var emits_before_dup: int = int(st_emits[0])
	var ok2: bool = bool(wm.call("apply_cloud_sync", cloud_resp, false, -1))
	_assert(ok2 and int(st_emits[0]) == emits_before_dup, "Değişmeyen tekrar bulut yoklaması merge/disk yazımı atladı (ek state_changed=0)")

	# Şimdi elmas ve updated_unix değişen yeni bir bulut cevabı gönder -> uygulanmalı!
	var cloud_resp_changed := cloud_resp.duplicate(true)
	cloud_resp_changed["diamonds"] = 99
	cloud_resp_changed["updated_unix"] = now + 10
	(cloud_resp_changed["cloud_state"] as Dictionary)["last_saved_unix"] = now + 10
	var ok3: bool = bool(wm.call("apply_cloud_sync", cloud_resp_changed, false, -1))
	_assert(ok3 and int(gs.player.get("diamonds", 0)) == 99 and int(st_emits[0]) > emits_before_dup, "Veri değiştiğinde bulut senkronizasyonu anında uygulandı (diamonds=99)")

	eb.state_changed.disconnect(on_st)
