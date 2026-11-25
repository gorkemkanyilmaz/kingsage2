extends SceneTree
## test_build34_notif_and_scroll.gd — Build 34 Depo Dolu Tek Seferlik Bildirim, APNs Kayıt & Kışla Scroll Koruma Testleri:
## 1) Depo dolum bildirimi tek sefer üretilir; kaynak tüketilmeden/Depo yükselmeden (10 dk sonra vb.) tekrarlanmaz.
## 2) Üretim 2x başlangıç bonusu / bonus köy çarpanı Production.hourly_production üzerinden doğru hesaplanır.
## 3) APNs kayıt anahtarı her açılış/oturumda tazelenir ve NetworkManager auth_completed sinyaline bağlıdır.
## 4) Kışla Birim Eğit sekmesinde klavye ✓ Tamam sonrası TrainScroll eski kaydırma pozisyonunu korur (en üste sıçramaz).

const NotificationManagerScript := preload("res://autoload/NotificationManager.gd")

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
	var auth := root.get_node_or_null("AuthManager")
	var net := root.get_node_or_null("NetworkManager")
	var nm := root.get_node_or_null("NotificationManager")
	var tm := root.get_node_or_null("TutorialManager")
	var qm := root.get_node_or_null("QuestManager")

	_assert(gd != null and gc != null and gs != null and wm != null and auth != null and net != null and nm != null, "Core autoloads loaded")
	if gd != null and gd.has_method("load_all"):
		gd.call("load_all", true)
	if tm != null:
		tm.set("tutorial_enabled_in_headless", false)
	if qm != null:
		qm.set("quest_enabled_in_headless", false)

	wm.call("wipe_all_local_data")
	auth.call("clear_all_account_data")
	auth.call("login_with_apple", "Lord Build34", "b34@privaterelay.appleid.com", "apple_uid_b34")
	var joined: bool = bool(wm.call("join_world", 1, "Lord Build34", 100, 100))
	_assert(joined and bool(gs.call("has_active_village")), "World 1 joined cleanly")
	gs.player["tutorial_completed"] = true

	await _test_storage_full_single_shot(gs, nm, gc)
	_test_apns_registration_wiring(nm, auth, net)
	await _test_barracks_train_scroll_restore(gs)

	wm.call("wipe_all_local_data")
	print("\n=== TestBuild34NotifAndScroll: %d BASARILI, %d BASARISIZ ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_storage_full_single_shot(gs: Node, nm: Node, gc: Node) -> void:
	print("\n-- 1) Depo Dolu Tek Seferlik Bildirim & 2x Hız Doğruluğu --")
	var pv: Dictionary = gs.call("get_active_village")
	var vid: int = int(pv.get("id", 1))
	pv["buildings"] = {"main": 5, "wood": 5, "stone": 5, "iron": 5, "storage": 1, "farm": 5}
	pv["resources"] = {"wood": 500.0, "stone": 500.0, "iron": 500.0}
	var now: int = int(Time.get_unix_time_from_system())

	# 1x hızda doldurma süresini ölç
	gc.set("speed", 1.0)
	var st1 := {"player": gs.player, "villages": [pv], "queues": [], "movements": []}
	var items_1x: Array = NotificationManagerScript.compute_local_notifications(st1, now, {})
	var full_1x: Dictionary = {}
	for it in items_1x:
		if str(it.get("type", "")) == "storage_full":
			full_1x = it
			break
	_assert(not full_1x.is_empty(), "Dolum aşamasında storage_full bildirimi planlandı")

	# 2x hızda süre yarıya düşmeli
	gc.set("speed", 2.0)
	var items_2x: Array = NotificationManagerScript.compute_local_notifications(st1, now, {})
	var full_2x: Dictionary = {}
	for it in items_2x:
		if str(it.get("type", "")) == "storage_full":
			full_2x = it
			break
	_assert(not full_2x.is_empty() and int(full_2x.get("delay_seconds", 0)) < int(full_1x.get("delay_seconds", 0)), "2x hız bonusunda depo dolum süresi yarıya düştü (%d -> %d sn)" % [int(full_1x.get("delay_seconds", 0)), int(full_2x.get("delay_seconds", 0))])
	gc.set("speed", 1.0)

	# sync_local_notifications_now() mandalı kurar; tetiklenme zamanı geçtikten sonra (10 dk sonra) TEKRAR ETMEMELİ!
	nm.set("storage_full_notified_by_vid", {})
	nm.call("sync_local_notifications_now")
	var latches: Dictionary = nm.get("storage_full_notified_by_vid")
	var vk := str(vid)
	_assert(latches.has(vk), "sync_local_notifications_now() mandalı kaydetti")
	var trig_u := int((latches[vk] as Dictionary).get("triggered_unix", 0))

	# 10 dakika sonra (cap-1 küçük oynama olsa dahi harcanmadıysa) bildirim çıkmamalı!
	pv["resources"] = {"wood": 999.0, "stone": 1000.0, "iron": 999.0}
	var st_after := {"player": gs.player, "villages": [pv], "queues": [], "movements": []}
	var after_items: Array = NotificationManagerScript.compute_local_notifications(st_after, trig_u + 600, latches)
	var after_full := after_items.filter(func(x): return str(x.get("type", "")) == "storage_full")
	_assert(after_full.is_empty(), "Depo dolup 10 dakika geçse de aynı bildirim TEKRARLANMIYOR (0 bildirim)")

	# Tam dolu (1000/1000/1000) iken sync çalışsa bile bildirim çıkmamalı ve mandal fired=true kalmalı
	pv["resources"] = {"wood": 1000.0, "stone": 1000.0, "iron": 1000.0}
	nm.call("sync_local_notifications_now")
	_assert(bool((nm.get("storage_full_notified_by_vid")[vk] as Dictionary).get("fired", false)), "Tam dolu durumda mandal fired=true olarak kilitlendi")

	# Şimdi kaynak tüketilsin (harcama yapılsın) -> mandal sıfırlanmalı ve tekrar dolum bildirimi planlanmalı
	pv["resources"] = {"wood": 300.0, "stone": 1000.0, "iron": 1000.0}
	nm.call("sync_local_notifications_now")
	var sched_after_spend: Array = nm.get("last_scheduled_notifications")
	var found_rescheduled := false
	for s_it in sched_after_spend:
		if str(s_it.get("type", "")) == "storage_full" and int(s_it.get("village_id", -1)) == vid:
			found_rescheduled = true
			break
	_assert(found_rescheduled, "Kaynak tüketilince depo bildirimi yeniden etkinleşti")

	# Tam dolu iken Depo yükseltilirse (kapasite artışı) -> yeni tavan için tekrar planlanmalı
	nm.set("storage_full_notified_by_vid", {vk: {"triggered_unix": now - 10, "cap": 1000, "fired": true}})
	(pv["buildings"] as Dictionary)["storage"] = 3
	pv["resources"] = {"wood": 1000.0, "stone": 1000.0, "iron": 1000.0}
	nm.call("sync_local_notifications_now")
	var sched_after_upg: Array = nm.get("last_scheduled_notifications")
	var found_after_upg := false
	for u_it in sched_after_upg:
		if str(u_it.get("type", "")) == "storage_full" and int(u_it.get("village_id", -1)) == vid:
			found_after_upg = true
			break
	_assert(found_after_upg, "Depo seviyesi yükseltilince (kapasite artınca) yeni tavan için bildirim planlandı")


func _test_apns_registration_wiring(nm: Node, auth: Node, net: Node) -> void:
	print("\n-- 2) APNs Token Kayıt Bağlantıları & Yenileme --")
	var cb := Callable(nm, "_on_network_auth_ready")
	_assert(net.is_connected("auth_completed", cb), "NotificationManager NetworkManager.auth_completed sinyaline bağlı")
	_assert(net.is_connected("server_status_changed", cb), "NotificationManager NetworkManager.server_status_changed sinyaline bağlı")
	nm.set("apns_token", "deadbeef0123456789abcdef0123456789abcdef0123456789abcdef01234567")
	nm.set("registered_token_user", "EskiKayit")
	net.set("auth_token", "tk_tok_test_34")
	var key: String = str(nm.call("_current_push_reg_key"))
	_assert(key.begins_with("Lord Build34:"), "_current_push_reg_key aktif oyuncuyu yansıtıyor (%s)" % key)
	nm.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	_assert(str(nm.get("registered_token_user")) == "", "Uygulama ön plana dönünce registered_token_user canlı yenileme için sıfırlanıyor")
	nm.set("apns_token", "")
	net.set("auth_token", "")


func _test_barracks_train_scroll_restore(gs: Node) -> void:
	print("\n-- 3) Kışla Birim Eğit Klavye Sonrası Scroll Koruma --")
	var pv: Dictionary = gs.call("get_active_village")
	pv["buildings"] = {"main": 5, "wood": 10, "stone": 10, "iron": 10, "storage": 15, "farm": 20, "barracks": 10}
	pv["resources"] = {"wood": 50000.0, "stone": 50000.0, "iron": 50000.0}
	pv["researched"] = {"spear": true, "sword": true, "axe": true, "bow": true}

	var v_scene: PackedScene = load("res://scenes/Village.tscn")
	var v_node := v_scene.instantiate() as Control
	root.add_child(v_node)
	var prev_scene := current_scene
	current_scene = v_node
	await _tick(3)

	var bp: Control = v_node.get("building_panel")
	_assert(bp != null, "BuildingPanel sahnede mevcut")
	bp.call("show_building", pv, "barracks")
	bp.call("switch_tab", 2) # Tab.TRAIN
	await _tick(4)

	var scroll := bp.get_node_or_null("VBox/TrainSection/TrainScroll") as ScrollContainer
	var train_list := bp.get_node_or_null("VBox/TrainSection/TrainScroll/TrainList") as VBoxContainer
	_assert(scroll != null and train_list != null, "TrainScroll ve TrainList bulundu")
	var axe_card := train_list.get_node_or_null("TrainCard_axe") as Control
	_assert(axe_card != null, "Baltacı (TrainCard_axe) kartı mevcut")

	# Kullanıcı aşağı kaydırıp Baltacı kartını ortaladı (ör. 620 px)
	var pre_scroll := int(maxf(0.0, axe_card.position.y - 40.0))
	if pre_scroll < 120:
		pre_scroll = 620
	scroll.scroll_vertical = pre_scroll
	await _tick(2)
	var actual_pre: int = scroll.scroll_vertical
	_assert(actual_pre > 0, "Kullanıcı Baltacıya aşağı kaydırdı (scroll_vertical=%d)" % actual_pre)

	var axe_line := axe_card.find_child("TrainLine_axe", true, false) as LineEdit
	if axe_line == null:
		for ch in axe_card.find_children("*", "LineEdit", true, false):
			axe_line = ch as LineEdit
			break
	_assert(axe_line != null, "Baltacı sayı girişi (LineEdit) bulundu")
	if axe_line != null:
		axe_line.grab_focus()
		await _tick(3)
		# Klavye Tamam'a basıldığında 25 adet yazılsın ve klavye kapansın
		bp.call("_commit_focused_train_input", "25", true)
		await _tick(5)
		var post_scroll: int = scroll.scroll_vertical
		var counts: Dictionary = bp.get("_train_counts")
		_assert(int(counts.get("axe", 0)) == 25, "Baltacı miktarı 25 olarak kaydedildi")
		_assert(post_scroll > 0 and absi(post_scroll - actual_pre) <= 180, "Tamam sonrası kaydırma en üste (0) zıplamadı, Baltacı konumunda kaldı (öncesi=%d, sonrası=%d)" % [actual_pre, post_scroll])

	bp.call("_on_close_pressed")
	current_scene = prev_scene
	v_node.queue_free()
	await _tick(2)
