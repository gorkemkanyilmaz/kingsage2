extends SceneTree
## test_build27_features.gd — Build 27 Kapsamlı Doğrulama Paketi:
##   1) Kale (main) açıklamasında seviye bazlı inşaat hızlandırma listesi (Sv. 1 - 50, alt alta)
##   2) ResourceBar "Köyler Arası Geçiş Yap" butonu (>=2 köyde PointsBox yanında, header boyutunu bozmadan)
##   3) ResourceBar odun/taş/demir/depo/nüfus tooltip tekrar tıklayınca kapanma + auto-hide devamı
##   4) NotificationManager 5 Vezir bildirim kuralı (inşaat, saldırı raporu, tam depo, toggle, yönlendirme)

const RE := preload("res://scripts/rules/RulesEngine.gd")

var _passed: int = 0
var _failed: int = 0


func _assert(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("[PASS] ", label)
	else:
		_failed += 1
		printerr("[FAIL] ", label)


func _tick(frames: int = 3) -> void:
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
	var nm := root.get_node_or_null("NotificationManager")
	var tm := root.get_node_or_null("TutorialManager")
	var qm := root.get_node_or_null("QuestManager")

	_assert(gd != null and gc != null and gs != null and wm != null and auth != null and nm != null, "Core autoloads + NotificationManager ready")
	if gd != null and gd.has_method("load_all"):
		gd.call("load_all", true)
	if tm != null:
		tm.set("tutorial_enabled_in_headless", false)
	if qm != null:
		qm.set("quest_enabled_in_headless", false)

	wm.call("wipe_all_local_data")
	auth.call("clear_all_account_data")
	auth.call("login_with_apple", "Lord Build27", "b27@privaterelay.appleid.com", "apple_uid_b27")
	var joined: bool = bool(wm.call("join_world", 1, "Lord Build27", 120, 45))
	_assert(joined and bool(gs.call("has_active_village")), "World 1 joined")

	_test_castle_speedup_description(gs)
	await _test_multi_village_switch_button_and_tooltip_toggle(gc, gs)
	_test_notification_manager(gs, nm)

	wm.call("wipe_all_local_data")
	auth.call("clear_all_account_data")

	print("SONUC: %d BASARILI, %d BASARISIZ" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _collect_row_text(row: Node) -> String:
	var parts: Array[String] = []
	for lbl in row.find_children("*", "Label", true, false):
		parts.append((lbl as Label).text)
	return " | ".join(parts)


func _test_castle_speedup_description(gs: Node) -> void:
	print("\n--- 1) Kale (main) Seviye Bazlı İnşaat Hızlandırma Listesi ---")
	_assert(RE.castle_speedup_percent(1) == 0, "Kale Sv.1 hızlandırma = %0 (Süre %100)")
	_assert(RE.castle_speedup_percent(2) == 4, "Kale Sv.2 hızlandırma = %4 (Süre %96)")
	_assert(RE.castle_speedup_percent(15) == 42, "Kale Sv.15 hızlandırma = %42 (Süre %58)")
	_assert(RE.castle_speedup_percent(50) == 85, "Kale Sv.50 hızlandırma = %85 (Süre %15)")

	var bp_scene: PackedScene = load("res://ui/BuildingPanel.tscn")
	var bp: Control = bp_scene.instantiate() as Control
	root.add_child(bp)

	var v: Dictionary = gs.call("get_active_village")
	v["buildings"]["main"] = 1
	bp.call("show_building", v, "main")

	var desc_box := bp.find_child("BuildingDescriptionBox", true, false) as Control
	var spd_sec := bp.find_child("CastleSpeedupSection", true, false) as Control
	var spd_list := bp.find_child("CastleSpeedupList", true, false) as VBoxContainer
	_assert(desc_box != null and desc_box.visible, "Kale açıklaması kutusu görünür")
	_assert(spd_sec != null and spd_sec.visible, "Kale açıkken CastleSpeedupSection görünür")
	_assert(spd_list != null and spd_list.get_child_count() == 50, "Alt alta tüm 50 Kale seviyesi listelendi (adet=%d)" % (spd_list.get_child_count() if spd_list != null else -1))

	if spd_list != null and spd_list.get_child_count() == 50:
		var r1 := _collect_row_text(spd_list.get_child(0))
		var r2 := _collect_row_text(spd_list.get_child(1))
		var r15 := _collect_row_text(spd_list.get_child(14))
		var r50 := _collect_row_text(spd_list.get_child(49))
		_assert(r1.contains("Seviye 1") and r1.contains("Güncel") and r1.contains("%0"), "Sv.1 satırı doğru: %s" % r1)
		_assert(r2.contains("Seviye 2") and r2.contains("Sonraki") and r2.contains("%4"), "Sv.2 satırı doğru (%%4): %s" % r2)
		_assert(r15.contains("Seviye 15") and r15.contains("%42") and r15.contains("Yıkım"), "Sv.15 satırı doğru (%%42 + Yıkım): %s" % r15)
		_assert(r50.contains("Seviye 50") and r50.contains("%85"), "Sv.50 satırı doğru (%%85): %s" % r50)

	# Kale Sv.10 olunca güncel vurgusu Sv.10'a kaymalı
	v["buildings"]["main"] = 10
	bp.call("show_building", v, "main")
	if spd_list != null and spd_list.get_child_count() == 50:
		var r10 := _collect_row_text(spd_list.get_child(9))
		_assert(r10.contains("Seviye 10") and r10.contains("Güncel") and r10.contains("%29"), "Kale Sv.10 güncel vurgusu ve %%29 hızlandırma doğru: %s" % r10)

	# Diğer binalarda gizli olmalı
	bp.call("show_building", v, "wood")
	_assert(spd_sec != null and not spd_sec.visible, "Oduncu Kampı panelinde Kale hızlandırma listesi gizli")
	bp.call("show_building", v, "barracks")
	_assert(spd_sec != null and not spd_sec.visible, "Kışla panelinde Kale hızlandırma listesi gizli")

	bp.queue_free()


func _make_mouse_tap() -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	return ev


func _test_multi_village_switch_button_and_tooltip_toggle(gc: Node, gs: Node) -> void:
	print("\n--- 2) Çoklu Köy Geçiş Butonu & Maden Tooltip Toggle ---")
	var rbar_scene: PackedScene = load("res://ui/ResourceBar.tscn")
	var rbar := rbar_scene.instantiate() as PanelContainer
	rbar.size = Vector2(1080, 159)
	root.add_child(rbar)
	await _tick(3)

	var btn_sw := rbar.find_child("BtnSwitchVillage", true, false) as Button
	var pts_box := rbar.find_child("PointsBox", true, false) as Control
	var left_wrap := rbar.find_child("LeftWingWrap", true, false) as Control
	var left_wing := rbar.find_child("LeftWing", true, false) as Control
	var btn_dia := rbar.find_child("BtnDiamonds", true, false) as Control
	var wood_box := rbar.find_child("WoodBox", true, false) as Control
	var stone_box := rbar.find_child("StoneBox", true, false) as Control

	_assert(btn_sw != null, "BtnSwitchVillage ResourceBar içinde bulundu")
	_assert(btn_sw != null and not btn_sw.visible, "Tek köy varken 'Köyler Arası Geçiş Yap' butonu gizli")

	# 2. köyü ekle -> buton PointsBox yanında görünür olmalı
	var v1: Dictionary = gs.call("get_active_village")
	var v1_id := int(v1.get("id", -1))
	var v2 := {
		"id": 9201,
		"name": "Fetih Kalesi",
		"x": 144,
		"y": 62,
		"owner": str(v1.get("owner", "Lord Build27")),
		"points": 2450,
		"is_bot": false,
		"is_barbarian": false,
		"buildings": {"main": 12, "wood": 10, "stone": 10, "iron": 10, "storage": 12, "farm": 10},
		"resources": {"wood": 3000, "stone": 3000, "iron": 3000},
		"units": {},
	}
	gs.call("add_village", v2)
	v1["points"] = 1850
	rbar.call("refresh")
	await _tick(3)

	_assert(btn_sw != null and btn_sw.visible, "En az 2 köy varken BtnSwitchVillage görünür")
	_assert(pts_box != null and btn_sw != null and btn_sw.global_position.x >= pts_box.global_position.x + pts_box.size.x - 1.0,
		"BtnSwitchVillage puan kutusunun sağında konumlandı")

	# Dynamic Island sığma ve simetri testleri
	for s_top in [118.0, 148.0, 162.0]:
		gc.set("_test_island_width", 390.0)
		gc.set("_safe_top_px", s_top)
		rbar.size = Vector2(1080, 210)
		rbar.call("refresh")
		await _tick(3)
		var bar_h := float(rbar.call("get_bar_height"))
		var left_end := left_wrap.global_position.x + left_wrap.size.x
		var dia_x := btn_dia.global_position.x
		var lw_cy := left_wing.global_position.y + left_wing.size.y * 0.5
		var dia_cy := btn_dia.global_position.y + btn_dia.size.y * 0.5
		var sw_right := btn_sw.global_position.x + btn_sw.size.x
		_assert(bar_h <= 210.0, "DI(%.0f) bar yüksekliği bozulmadı (h=%.1f <= 210)" % [s_top, bar_h])
		_assert(left_end <= 368.0 and sw_right <= 372.0, "DI(%.0f) BtnSwitchVillage adaya taşmadı (sw_end=%.1f, left_end=%.1f)" % [s_top, sw_right, left_end])
		_assert(dia_x >= 714.0, "DI(%.0f) Elmas/Pazar dinamik adadan etkilenmedi" % s_top)
		_assert(absf(lw_cy - dia_cy) <= 3.0, "DI(%.0f) dikey simetri korundu (diff=%.1f)" % [s_top, absf(lw_cy - dia_cy)])

	gc.set("_test_island_width", -1.0)
	gc.set("_safe_top_px", 0.0)
	rbar.call("refresh")
	await _tick(2)

	# Butona basınca Köylerim modalı açılmalı ve köye tıklayınca aktif köy değişmeli
	btn_sw.pressed.emit()
	await _tick(2)
	var modal := rbar.get("_switcher_modal") as CanvasLayer
	_assert(modal != null and is_instance_valid(modal), "Köyler Arası Geçiş butonuna basınca VillageSwitcherModal açıldı")
	var k_btns: Array[Button] = []
	for b_node in modal.find_children("*", "Button", true, false):
		var b := b_node as Button
		if b.text == "Köye Geç":
			k_btns.append(b)
	_assert(k_btns.size() == 1, "Diğer köy için 'Köye Geç' seçeneği listelendi")
	if k_btns.size() >= 1:
		k_btns[0].pressed.emit()
		await _tick(3)
		_assert(int(gs.get("active_village_id")) == 9201, "Köye tıklandığında aktif köy 9201'e geçti (active=%d)" % int(gs.get("active_village_id")))
	_assert(rbar.get("_switcher_modal") == null or not is_instance_valid(rbar.get("_switcher_modal")), "Köy seçilince modal kapandı")

	# Şimdi modal satırına doğrudan dokunarak geri dönüşü (v1_id) test et
	btn_sw.pressed.emit()
	await _tick(2)
	var modal2 := rbar.get("_switcher_modal") as CanvasLayer
	if modal2 != null and is_instance_valid(modal2):
		var clicked_row := false
		for pc_node in modal2.find_children("*", "PanelContainer", true, false):
			var pc := pc_node as PanelContainer
			var txt := _collect_row_text(pc)
			if txt.contains("Başkent") and not txt.contains("Fetih Kalesi"):
				pc.gui_input.emit(_make_mouse_tap())
				clicked_row = true
				break
		await _tick(3)
		_assert(clicked_row and int(gs.get("active_village_id")) == v1_id, "Doğrudan köy satırına tıklanınca da köye geçiş yapıldı (active=%d)" % int(gs.get("active_village_id")))

	# 3) Maden Tooltip Toggle + Auto-Hide kontrolü
	rbar.call("_on_economy_box_gui_input", _make_mouse_tap(), "wood", wood_box)
	await _tick(1)
	var tt_layer1 = rbar.get("_tooltip_layer")
	_assert(tt_layer1 != null and is_instance_valid(tt_layer1) and str(rbar.get("_last_tooltip_key")) == "wood", "1. tıklamada ODUN bilgi ekranı açıldı")

	# Dokunma + emüle mouse aynı anda gelirse hemen kapanmamalı
	var touch_tap := InputEventScreenTouch.new()
	touch_tap.pressed = true
	rbar.call("_on_economy_box_gui_input", touch_tap, "wood", wood_box)
	await _tick(1)
	_assert(rbar.get("_tooltip_layer") == null, "Aynı madene (ODUN) 2. kez tıklanınca bilgi ekranı kapandı")

	# Aynı frame'deki emüle mouse yarışı 1. dokunmayı kapatmamalı
	rbar.call("_on_economy_box_gui_input", touch_tap, "wood", wood_box)
	rbar.call("_on_economy_box_gui_input", _make_mouse_tap(), "wood", wood_box)
	await _tick(1)
	_assert(rbar.get("_tooltip_layer") != null and str(rbar.get("_last_tooltip_key")) == "wood", "Tek dokunuş + emüle mouse yarışı bilgi ekranını erken kapatmadı")

	# Başka madene tıklayınca TAŞ'a geçmeli, TAŞ'a tekrar tıklayınca kapanmalı
	rbar.call("_on_economy_box_gui_input", _make_mouse_tap(), "stone", stone_box)
	await _tick(1)
	_assert(rbar.get("_tooltip_layer") != null and str(rbar.get("_last_tooltip_key")) == "stone", "Farklı madene (TAŞ) tıklanınca TAŞ bilgi ekranına geçildi")

	var tt_stone_layer := rbar.get("_tooltip_layer") as CanvasLayer
	var hide_timer: Timer = null
	for ch in tt_stone_layer.get_children():
		if ch is Timer:
			hide_timer = ch as Timer
			break
	_assert(hide_timer != null and hide_timer.wait_time >= 4.0, "Kendi kendine kaybolma zamanlayıcısı (auto-hide) aktif (%.1fs)" % (hide_timer.wait_time if hide_timer != null else 0.0))
	if hide_timer != null:
		hide_timer.timeout.emit()
		await _tick(2)
		_assert(rbar.get("_tooltip_layer") == null and str(rbar.get("_last_tooltip_key")) == "", "Auto-hide süresi dolunca tooltip kapandı ve anahtar sıfırlandı")

	rbar.queue_free()
	await _tick(2)


func _test_notification_manager(gs: Node, nm: Node) -> void:
	print("\n--- 3) Baş Vezir Bildirim Sistemi (NotificationManager) ---")
	var now_u := 1800000000
	var state := {
		"player": {"name": "Lord Build27"},
		"villages": [
			{
				"id": 10,
				"name": "Başkentim",
				"x": 100,
				"y": 100,
				"owner": "Lord Build27",
				"is_bot": false,
				"is_barbarian": false,
				"buildings": {"main": 5, "wood": 1, "stone": 1, "iron": 1, "storage": 1},
				"resources": {"wood": 980, "stone": 700, "iron": 100},
			},
			{
				"id": 20,
				"name": "Düşman Kalesi",
				"x": 110,
				"y": 105,
				"owner": "Düşman Baron",
				"is_bot": false,
				"is_barbarian": false,
				"buildings": {"main": 3, "wood": 1, "stone": 1, "iron": 1, "storage": 1},
				"resources": {"wood": 1000, "stone": 1000, "iron": 1000},
			},
			{
				"id": 11,
				"name": "Dolu Köy",
				"x": 115,
				"y": 110,
				"owner": "Lord Build27",
				"is_bot": false,
				"is_barbarian": false,
				"buildings": {"main": 3, "wood": 1, "stone": 1, "iron": 1, "storage": 1},
				"resources": {"wood": 1000, "stone": 1000, "iron": 1000},
			},
		],
		"queues": [
			{"id": 1, "village_id": 10, "type": "build", "key": "barracks", "target_level": 4, "finish_unix": now_u + 1800},
		],
		"movements": [
			# Kendi saldırımız hedefe varınca rapor bildirimine dönüşmeli
			{"id": 77, "from_village_id": 10, "to_village_id": 20, "type": "attack", "state": "outgoing", "arrive_unix": now_u + 900},
			# Düşman saldırısı (sunucu saldırı başladığında bildirir; yerel rapor olarak zamanlanmaz)
			{"id": 88, "from_village_id": 20, "to_village_id": 10, "type": "attack", "state": "outgoing", "arrive_unix": now_u + 600},
		],
	}

	var list: Array = nm.call("compute_local_notifications", state, now_u)
	var by_type: Dictionary = {}
	for it in list:
		by_type[str(it.get("type", ""))] = it

	_assert(list.size() == 3, "Tam olarak 3 gelecek yerel Vezir bildirimi üretildi (build_complete, attack_report, storage_full; dolu köy atlandı): adet=%d" % list.size())
	_assert(by_type.has("build_complete"), "İnşaat tamamlanma bildirimi üretildi")
	_assert(by_type.has("attack_report"), "Saldırı varışı / rapor bildirimi üretildi")
	_assert(by_type.has("storage_full"), "Tüm kaynaklar max depoya ulaşınca bildirimi üretildi")

	if by_type.has("build_complete"):
		var bn := by_type["build_complete"] as Dictionary
		_assert(int(bn["delay_seconds"]) == 1800 and str(bn["route"]) == "village" and str(bn["title"]).contains("Vezir") and str(bn["body"]).contains("Kışla"),
			"İnşaat bildirimi Vezir dilinde, doğru süre ve yönlendirmede: %s" % str(bn["body"]))
	if by_type.has("attack_report"):
		var an := by_type["attack_report"] as Dictionary
		_assert(int(an["delay_seconds"]) == 900 and str(an["route"]) == "reports" and str(an["body"]).contains("Düşman Kalesi"),
			"Rapor bildirimi doğru hedef ve rota ile üretildi: %s" % str(an["body"]))
	if by_type.has("storage_full"):
		var sn := by_type["storage_full"] as Dictionary
		# En yavaş dolan demir (100/1000) için süre Odun/Taş'tan belirgin şekilde uzun olmalı
		var expected_iron_rate := float(RE.production_per_hour("iron", 1)) / 3600.0
		var expected_max_sec := int(ceil(900.0 / expected_iron_rate))
		_assert(abs(int(sn["delay_seconds"]) - expected_max_sec) <= 5 and str(sn["route"]) == "village",
			"Tam depo bildirimi ÜÇ kaynağın tamamı dolduğunda (%ds, beklenen=%ds) çalacak şekilde hesaplandı" % [int(sn["delay_seconds"]), expected_max_sec])

	# İnşaat iptal edilince bildirim listeden düşmeli
	state["queues"] = []
	var list_after_cancel: Array = nm.call("compute_local_notifications", state, now_u)
	_assert(list_after_cancel.size() == 2, "İnşaat iptal edilince build_complete bildirimi planlamadan kaldırıldı")

	# Bildirim açılınca rota payload'ı kaydedilmeli
	nm.call("handle_opened_notification", {"route": "messages", "village_id": -1, "type": "incoming_message"}, false)
	_assert(str((nm.get("last_opened_payload") as Dictionary).get("route", "")) == "messages", "Bildirim açılışı 'messages' rotasını işledi")

	# Ayar kapatma/açma testi
	nm.call("set_notifications_enabled", false)
	_assert(not bool(nm.call("is_notifications_enabled")) and (nm.get("last_scheduled_notifications") as Array).is_empty(), "Bildirimler kapatılınca zamanlama temizlendi")
	nm.call("set_notifications_enabled", true)
	_assert(bool(nm.call("is_notifications_enabled")), "Bildirimler tekrar açılabildi")
