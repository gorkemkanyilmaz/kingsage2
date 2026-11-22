extends SceneTree
## test_build23_features.gd — Build 23 Kapsamlı Doğrulama Paketi:
## 1) ResourceBar sol/sağ dikey simetri + Puan rozeti yerleşimi (Desktop & Dynamic Island 118/162)
## 2) KingsAge bina yükseltme süreleri (Kale zaman faktörü, kademe sırası, 2x başlangıç bonusu ayrımı)
## 3) Tüm ambarları doldur = 100 Elmas (StoreManager & MarketModal)
## 4) Köy ekranında dikey dokunmatik kaydırma sonrası yanlışlıkla bina tıklanmaması
## 5) Gelen saldırı kırmızı yanıp sönme + "Lordum, size yaklaşan bir saldırı var!" Vezir alarmı

const VM := preload("res://scripts/model/VillageModel.gd")
const RE := preload("res://scripts/rules/RulesEngine.gd")
const BQ := preload("res://scripts/sim/economy/BuildQueue.gd")
const IncomingAttackAlert := preload("res://ui/IncomingAttackAlert.gd")

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
	var tm := root.get_node_or_null("TutorialManager")
	var qm := root.get_node_or_null("QuestManager")
	var store := root.get_node_or_null("StoreManager")

	_assert(gd != null and gc != null and gs != null and store != null, "Core autoloads ready")
	if gd != null and gd.has_method("load_all"):
		gd.call("load_all", true)
	if tm != null:
		tm.set("tutorial_enabled_in_headless", false)
	if qm != null:
		qm.set("quest_enabled_in_headless", false)

	gs.call("reset")
	var pv := VM.create(201, "KralKoyu", 100, 100, "Lord Gorkem", false)
	pv["buildings"] = {
		"main": 1, "wood": 1, "stone": 1, "iron": 1, "farm": 5, "storage": 5,
		"barracks": 1, "market": 1, "wall": 1
	}
	pv["resources"] = {"wood": 50000, "stone": 50000, "iron": 50000}
	var enemy_v := VM.create(202, "DusmanKalesi", 104, 100, "Kara Lord", false)
	gs.villages = [pv, enemy_v]
	gs.active_village_id = 201
	gs.player["name"] = "Lord Gorkem"
	gs.player["tutorial_completed"] = true
	gs.player["diamonds"] = 200
	gs.queues = []
	gs.movements = []
	gs.reports = []
	gs.messages = []

	await _test_resourcebar_symmetry(gc)
	_test_kingsage_build_times(gc, gs)
	await _test_warehouse_fill_100_diamonds(store, gs)
	await _test_scroll_drag_vs_tap_and_attack_alarm(gs)

	print("SONUC: %d BASARILI, %d BASARISIZ" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_resourcebar_symmetry(gc: Node) -> void:
	print("\n--- 1) ResourceBar Sol/Sağ Simetri Testleri ---")
	var rbar_scene: PackedScene = load("res://ui/ResourceBar.tscn")
	var rbar := rbar_scene.instantiate() as PanelContainer
	rbar.size = Vector2(1080, 177)
	root.add_child(rbar)
	await _tick(3)

	var top_row := rbar.find_child("TopRow", true, false) as HBoxContainer
	var v_info := rbar.find_child("VillageInfo", true, false) as HBoxContainer
	var v_name := rbar.find_child("VillageName", true, false) as Label
	var pts_row := rbar.find_child("PointsRow", true, false) as HBoxContainer
	var pts_box := rbar.find_child("PointsBox", true, false) as Control
	var res_row := rbar.find_child("ResourcesRow", true, false) as HBoxContainer
	var btn_dia := rbar.find_child("BtnDiamonds", true, false) as Control
	var btn_mkt := rbar.find_child("BtnMarket", true, false) as Control

	_assert(top_row != null and v_info != null and v_name != null and pts_row != null and pts_box != null and res_row != null and btn_dia != null and btn_mkt != null, "ResourceBar tüm düğümler mevcut")
	if v_info != null and btn_dia != null and btn_mkt != null and pts_box != null and res_row != null:
		_assert(v_info.get_parent() == top_row, "VillageInfo doğrudan TopRow içinde")
		var v_cy := v_info.global_position.y + v_info.size.y * 0.5
		var d_cy := btn_dia.global_position.y + btn_dia.size.y * 0.5
		var m_cy := btn_mkt.global_position.y + btn_mkt.size.y * 0.5
		_assert(absf(v_cy - d_cy) <= 2.0 and absf(v_cy - m_cy) <= 2.0, "Desktop dikey merkez hizası eşit (v=%.1f, d=%.1f, m=%.1f)" % [v_cy, d_cy, m_cy])
		_assert(pts_box.global_position.y >= v_name.global_position.y + v_name.size.y - 2.0, "Desktop PointsBox köy adının altında")
		_assert(pts_box.global_position.y + pts_box.size.y <= res_row.global_position.y + 4.0, "Desktop PointsBox kaynak satırının üstünde")

		for s_top in [118.0, 162.0]:
			gc.set("_test_island_width", 390.0)
			gc.set("_safe_top_px", s_top)
			rbar.call("refresh")
			await _tick(3)
			var iv_cy := v_info.global_position.y + v_info.size.y * 0.5
			var id_cy := btn_dia.global_position.y + btn_dia.size.y * 0.5
			var im_cy := btn_mkt.global_position.y + btn_mkt.size.y * 0.5
			_assert(absf(iv_cy - id_cy) <= 2.0 and absf(iv_cy - im_cy) <= 2.0, "Dynamic Island (safe_top=%.0f) sol/sağ simetri korundu (diff=%.1f, %.1f)" % [s_top, absf(iv_cy - id_cy), absf(iv_cy - im_cy)])
			_assert(pts_box.global_position.y >= v_name.global_position.y + v_name.size.y - 2.0, "Dynamic Island (%.0f) PointsBox köy adı altında" % s_top)
			_assert(pts_box.global_position.y + pts_box.size.y <= res_row.global_position.y + 4.0, "Dynamic Island (%.0f) PointsBox kaynaklar üstünde" % s_top)

		gc.set("_test_island_width", -1.0)
		gc.set("_safe_top_px", 0.0)

	rbar.queue_free()
	await _tick(2)


func _test_kingsage_build_times(gc: Node, gs: Node) -> void:
	print("\n--- 2) KingsAge Bina Yükseltme Süreleri & Kale Zaman Faktörü Testleri ---")
	gc.set("speed", 1.0)
	var t1 := RE.build_seconds("wood", 1, 1)
	var t2 := RE.build_seconds("wood", 2, 1)
	var t10 := RE.build_seconds("wood", 10, 1)
	var t20 := RE.build_seconds("wood", 20, 1)
	var t30 := RE.build_seconds("wood", 30, 1)
	var t50 := RE.build_seconds("wood", 50, 1)
	_assert(t1 < t2 and t2 < t10 and t10 < t20 and t20 < t30 and t30 < t50,
		"Sabit Kale Sv.1 iken süre seviye arttıkça kesin artar (%.0f < %.0f < %.0f < %.0f < %.0f < %.0f)" % [t1, t2, t10, t20, t30, t50])
	_assert(t20 > 1800.0 and t50 > 36000.0, "Yüksek seviyeler gerçekçi KingsAge süresinde (Sv20=%.0fs, Sv50=%.0fs)" % [t20, t50])

	var t20_c20 := RE.build_seconds("wood", 20, 20)
	var t20_c50 := RE.build_seconds("wood", 20, 50)
	var ratio_c20 := t20_c20 / t20
	var ratio_c50 := t20_c50 / t20
	_assert(absf(ratio_c20 - 0.48) < 0.015, "Kale Sv.20 zaman faktörü %48 uygulanıyor (oran=%.3f)" % ratio_c20)
	_assert(absf(ratio_c50 - 0.15) < 0.015, "Kale Sv.50 zaman faktörü %15 uygulanıyor (oran=%.3f)" % ratio_c50)

	_assert(RE.build_seconds("storage", 5, 5) < RE.build_seconds("wood", 5, 5), "Depo süresi Oduncu'dan kısa")
	_assert(RE.build_seconds("wood", 5, 5) < RE.build_seconds("main", 5, 5), "Oduncu süresi Kale'den kısa")
	_assert(RE.build_seconds("main", 5, 5) < RE.build_seconds("barracks", 5, 5), "Kale süresi Kışla'dan kısa")
	_assert(RE.build_seconds("barracks", 5, 5) < RE.build_seconds("garage", 5, 5), "Kışla süresi Simyager'den kısa")
	_assert(RE.build_seconds("garage", 5, 5) < RE.build_seconds("smith", 5, 5), "Simyager süresi Kuyumcu'dan kısa")
	_assert(RE.build_seconds("smith", 5, 5) < RE.build_seconds("snob", 5, 5), "Kuyumcu süresi Köşk'ten kısa")
	_assert(RE.build_seconds("snob", 1, 50) < RE.build_seconds("statue", 1, 50), "Anıt süresi en uzun")

	gc.set("speed", 2.0)
	var t20_2x := RE.build_seconds("wood", 20, 1)
	_assert(is_equal_approx(t20_2x, t20 * 0.5), "2x başlangıç bonusu tüm inşaat sürelerini ayrı olarak yarıya indirir (1x=%.1f, 2x=%.1f)" % [t20, t20_2x])
	gc.set("speed", 1.0)

	var v_c1 := VM.create(301, "C1", 10, 10, "T", false)
	v_c1["buildings"]["main"] = 1
	v_c1["resources"] = {"wood": 99999, "stone": 99999, "iron": 99999}
	var st1 := {"villages": [v_c1], "queues": []}
	var r_c1 := BQ.start_build(st1, v_c1, "wood", 1000)

	var v_c20 := VM.create(302, "C20", 12, 10, "T", false)
	v_c20["buildings"]["main"] = 20
	v_c20["resources"] = {"wood": 99999, "stone": 99999, "iron": 99999}
	var st20 := {"villages": [v_c20], "queues": []}
	var r_c20 := BQ.start_build(st20, v_c20, "wood", 1000)
	var d_c1 := int(r_c1["finish_unix"]) - int(r_c1["start_unix"])
	var d_c20 := int(r_c20["finish_unix"]) - int(r_c20["start_unix"])
	_assert(d_c20 < d_c1, "BuildQueue.start_build() köyün Kale seviyesini hesaba katarak hızlandırır (C1=%ds > C20=%ds)" % [d_c1, d_c20])


func _test_warehouse_fill_100_diamonds(store: Node, gs: Node) -> void:
	print("\n--- 3) Ambarları Doldur = 100 Elmas Testleri ---")
	var def: Dictionary = store.call("get_resource_pack_def", "res_fill_storage")
	_assert(int(def.get("cost_diamonds", 0)) == 100, "StoreManager res_fill_storage fiyatı 100 Elmas")
	var av: Dictionary = gs.call("get_active_village")
	av["resources"] = {"wood": 100, "stone": 100, "iron": 100}
	gs.player["diamonds"] = 99
	var r_fail: Dictionary = store.call("buy_resource_pack", "res_fill_storage")
	_assert(not bool(r_fail.get("ok", true)), "99 elmas ile Ambarları Doldur reddedildi")
	gs.player["diamonds"] = 120
	var r_ok: Dictionary = store.call("buy_resource_pack", "res_fill_storage")
	_assert(bool(r_ok.get("ok", false)) and int(store.call("get_diamonds")) == 20, "120 elmas ile Ambarları Doldur başarılı ve 100 elmas düştü (20 kaldı)")

	var mkt_script := load("res://ui/MarketModal.gd")
	var mkt_packs: Array = mkt_script.FALLBACK_RESOURCE_PACKS
	var found_fill_cost := -1
	for p in mkt_packs:
		if str(p.get("id", "")) == "res_fill_storage":
			found_fill_cost = int(p.get("cost_diamonds", -1))
	_assert(found_fill_cost == 100, "MarketModal FALLBACK_RESOURCE_PACKS res_fill_storage fiyatı 100 Elmas")


func _test_scroll_drag_vs_tap_and_attack_alarm(gs: Node) -> void:
	print("\n--- 4 & 5) Dokunmatik Kaydırma İzolasyonu & Gelen Saldırı Alarmı Testleri ---")
	IncomingAttackAlert.reset_ack_state()
	var vil_scene: PackedScene = load("res://scenes/Village.tscn")
	var vil := vil_scene.instantiate() as Control
	vil.size = Vector2(1080, 1920)
	root.add_child(vil)
	await _tick(4)

	var bpanel := vil.get("building_panel") as Control
	var bv_barracks := vil.call("get_building_view", "barracks") as Control
	_assert(bpanel != null and bv_barracks != null, "Village scene + Barracks BuildingView yüklü")
	if bpanel != null and bv_barracks != null:
		bpanel.hide()
		var b_btn: Control = bv_barracks.call("get_button") as Control
		var local_c := bv_barracks.size * 0.5
		var screen_start := bv_barracks.get_global_transform_with_canvas() * local_c

		# 4a) Dikey parmak kaydırma + iOS emulated mouse release simülasyonu -> panel AÇILMAMALI
		var st_down := InputEventScreenTouch.new()
		st_down.index = 0
		st_down.pressed = true
		st_down.position = screen_start
		vil._input(st_down)
		var st_btn_down := st_down.duplicate() as InputEventScreenTouch
		st_btn_down.position = local_c
		bv_barracks.call("_on_btn_gui_input", st_btn_down)

		for step_i in range(1, 5):
			var cur_scr := screen_start + Vector2(0.0, -14.0 * float(step_i))
			var sd := InputEventScreenDrag.new()
			sd.index = 0
			sd.position = cur_scr
			sd.relative = Vector2(0.0, -14.0)
			vil._input(sd)
			var sd_btn := sd.duplicate() as InputEventScreenDrag
			sd_btn.position = local_c
			bv_barracks.call("_on_btn_gui_input", sd_btn)

		var st_up := InputEventScreenTouch.new()
		st_up.index = 0
		st_up.pressed = false
		st_up.position = screen_start + Vector2(0.0, -56.0)
		vil._input(st_up)
		var st_btn_up := st_up.duplicate() as InputEventScreenTouch
		st_btn_up.position = local_c
		bv_barracks.call("_on_btn_gui_input", st_btn_up)

		# iOS'un sentezlediği gecikmeli mouse release olayını da simüle et
		var em_up := InputEventMouseButton.new()
		em_up.button_index = MOUSE_BUTTON_LEFT
		em_up.pressed = false
		em_up.position = local_c
		em_up.global_position = st_up.position
		bv_barracks.call("_on_btn_gui_input", em_up)
		await _tick(2)
		_assert(not bpanel.visible, "Dikey parmak kaydırmada (56px) bina tıklanmadı ve BuildingPanel açılmadı")

		# 4b) Cooldown sonrası temiz tek dokunuş -> BuildingPanel AÇILMALI
		vil.set("_last_gesture_end_ms", -10000)
		var tap_down := InputEventScreenTouch.new()
		tap_down.index = 0
		tap_down.pressed = true
		tap_down.position = local_c
		bv_barracks.call("_on_btn_gui_input", tap_down)
		var tap_up := InputEventScreenTouch.new()
		tap_up.index = 0
		tap_up.pressed = false
		tap_up.position = local_c + Vector2(1.0, 2.0)
		bv_barracks.call("_on_btn_gui_input", tap_up)
		await _tick(2)
		_assert(bpanel.visible, "Kaydırmasız temiz dokunuşta BuildingPanel normal açıldı")
		bpanel.hide()

	# 5) Gelen düşman saldırısı: kırmızı yanıp sönme + Vezir panik uyarısı + kalan dakika
	var overlay := vil.get("_attack_alarm_overlay") as Control
	var banner := vil.get("_attack_alarm_banner") as Button
	_assert(overlay != null and not overlay.visible, "Başlangıçta kırmızı saldırı alarmı gizli")

	var now_u := int(vil.call("_current_now"))
	gs.movements = [{
		"id": 7771,
		"village_id": 202,
		"from_village_id": 202,
		"to_village_id": 201,
		"from_x": 104, "from_y": 100,
		"to_x": 100, "to_y": 100,
		"type": "attack",
		"state": "outgoing",
		"owner": "Kara Lord",
		"depart_unix": now_u - 30,
		"arrive_unix": now_u + 720,
		"units": {"axe": 25},
	}]
	vil.call("_update_incoming_attack_alarm", 0.22)
	await _tick(3)

	var v_area := vil.get("village_area") as Control
	var red_tint := vil.get("_attack_red_tint") as ColorRect
	_assert(overlay != null and overlay.visible, "Saldırı yola çıkınca kırmızı alarm katmanı aktif")
	_assert(red_tint != null and red_tint.color.a > 0.0, "Kırmızı yanıp sönme opaklığı pozitif (a=%.2f)" % (red_tint.color.a if red_tint else 0.0))
	_assert(v_area != null and v_area.modulate.g < 0.99, "Köy görünümü kırmızı tona yanıp söndü")
	_assert(banner != null and banner.visible and banner.text.contains("12 dk"), "Üst saldırı alarm bandı kalan dakikayı gösteriyor: %s" % (banner.text if banner else ""))

	var modal := IncomingAttackAlert.get_open_modal(vil)
	_assert(modal != null, "Baş Vezir saldırı uyarı penceresi otomatik açıldı")
	if modal != null:
		var body := modal.find_child("VizierAlertBody", true, false) as RichTextLabel
		_assert(body != null and body.text.contains("Lordum, size yaklaşan bir saldırı var!"), "Vezir metni 'Lordum, size yaklaşan bir saldırı var!' içeriyor")
		_assert(body != null and body.text.contains("12 dakika"), "Vezir metni kalan dakikayı ('12 dakika') içeriyor")
		var btn_ack := modal.find_child("BtnAckAttackAlert", true, false) as BaseButton
		_assert(btn_ack != null, "Vezir modalında 'Savunmaya Geç (Anladım)' butonu mevcut")
		if btn_ack != null:
			btn_ack.emit_signal("pressed")
		await _tick(3)

	vil.call("_update_incoming_attack_alarm", 0.25)
	await _tick(2)
	_assert(IncomingAttackAlert.get_open_modal(vil) == null, "Onaylandıktan sonra aynı saldırı için modal tekrar fırlamıyor")
	_assert(overlay != null and overlay.visible, "Onay sonrası saldırı varana kadar kırmızı yanıp sönme devam ediyor")

	# İkinci yeni saldırı -> Vezir tekrar açılmalı
	gs.movements.append({
		"id": 7772,
		"village_id": 202,
		"from_village_id": 202,
		"to_village_id": 201,
		"from_x": 104, "from_y": 100,
		"to_x": 100, "to_y": 100,
		"type": "raid",
		"state": "outgoing",
		"owner": "Kara Lord",
		"depart_unix": now_u,
		"arrive_unix": now_u + 300,
		"units": {"light": 15},
	})
	vil.call("_update_incoming_attack_alarm", 0.25)
	await _tick(3)
	_assert(IncomingAttackAlert.get_open_modal(vil) != null, "Yeni 2. saldırıda Vezir uyarısı tekrar açıldı")

	# Saldırılar bitince her şey normale dönmeli
	gs.movements = []
	vil.call("_update_incoming_attack_alarm", 0.1)
	await _tick(3)
	_assert(overlay != null and not overlay.visible, "Saldırı kalmayınca kırmızı alarm gizlendi")
	_assert(banner != null and not banner.visible, "Saldırı kalmayınca alarm bandı gizlendi")
	_assert(v_area != null and v_area.modulate == Color.WHITE, "Köy görünümü normal renge (WHITE) döndü")
	_assert(IncomingAttackAlert.get_open_modal(vil) == null, "Saldırı kalmayınca açık Vezir modalı kapandı")

	vil.queue_free()
	await _tick(2)
