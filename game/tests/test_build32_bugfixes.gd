extends SceneTree
## Build 32 Bugfix Doğrulama Testi:
## 1) Çoklu köylü oyuncuda origin_movement_id çakışmasıyla yeni saldırı/casusun silinmemesi + yabancı 00:00 hareketlerinin gizlenmesi
## 2) Gelen saldırıda Köy UI kasma/ısınma optimizasyonu (gölge/StyleBox mutasyonu olmaması)
## 3) Gelen saldırı/casusun "Gelen Sevkiyat/Kervan" yerine "Gelen Saldırı/Casus" yazması ve birim sayısının gizlenmesi
## 4) Hareket Detay modalında düşman birliklerinin gizlenmesi, ekrana sığması ve Kapat butonunda yüksek kontrast
## 5) Saldıranın casus raporunda BottomNav okunmamış rozetinin okunduktan sonra 0'a düşmesi

const Movement := preload("res://scripts/sim/actions/Movement.gd")
const Arrival := preload("res://scripts/sim/actions/Arrival.gd")
const ActionSimulator := preload("res://scripts/sim/actions/ActionSimulator.gd")
const WorldMapScene := preload("res://scenes/WorldMap.tscn")
const VillageScene := preload("res://scenes/Village.tscn")
const ReportsScene := preload("res://scenes/Reports.tscn")
const BottomNavScene := preload("res://ui/BottomNav.tscn")

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
	print("=== TestBuild32Bugfixes başlıyor ===")
	_test_multi_village_movement_collision_and_flicker()
	_test_village_incoming_attack_perf_optimization()
	_test_incoming_attack_labels_and_masked_details_ui()
	_test_attacker_spy_report_read_status_and_badge()

	if _failures > 0:
		printerr("=== TestBuild32Bugfixes FAILED (%d/%d) ===" % [_failures, _checks])
		quit(1)
		return
	print("=== TestBuild32Bugfixes PASSED (%d/%d) ===" % [_checks, _checks])
	quit(0)


func _make_multi_village_state() -> Dictionary:
	var now_u := int(Time.get_unix_time_from_system())
	return {
		"world": {"speed": 1.0, "sim_now_unix": now_u},
		"player": {
			"id": 1,
			"name": "Lord Gorgi",
			"read_report_sigs": [],
			"deleted_report_sigs": [],
			"unread_toggled_sigs": [],
		},
		"villages": [
			{
				"id": 13,
				"name": "Baskent2",
				"owner": "Lord Gorgi",
				"is_bot": false,
				"is_barbarian": false,
				"is_conquered": true,
				"conquered_by": "Lord Gorgi",
				"x": 160,
				"y": 35,
				"loyalty": 100,
				"points": 800,
				"resources": {"wood": 5000, "stone": 5000, "iron": 5000},
				"buildings": {"main": 5, "barracks": 3, "storage": 5, "farm": 5},
				"units": {"spear": 200, "spy": 10, "axe": 100},
				"researched": {"farmer": true, "spear": true, "axe": true, "spy": true},
				"support": [],
			},
			{
				"id": 51,
				"name": "Baskentim",
				"owner": "Lord Gorgi",
				"is_bot": false,
				"is_barbarian": false,
				"x": 168,
				"y": 33,
				"loyalty": 100,
				"points": 1200,
				"resources": {"wood": 5000, "stone": 5000, "iron": 5000},
				"buildings": {"main": 6, "barracks": 4, "storage": 5, "farm": 5},
				"units": {"spear": 250, "spy": 15, "axe": 150},
				"researched": {"farmer": true, "spear": true, "axe": true, "spy": true},
				"support": [],
			},
			{
				"id": 52,
				"name": "Başkent",
				"owner": "Lord Morgi",
				"is_bot": false,
				"is_barbarian": false,
				"x": 165,
				"y": 42,
				"loyalty": 100,
				"points": 1910,
				"resources": {"wood": 8000, "stone": 8000, "iron": 8000},
				"buildings": {"main": 8, "barracks": 5, "storage": 7, "farm": 6},
				"units": {"spear": 400, "spy": 6, "heavy": 50},
				"researched": {"farmer": true, "spear": true, "spy": true, "heavy": true},
				"support": [],
			},
		],
		"movements": [
			# Başka oyuncunun (Lord Morgi) origin_movement_id=1 olan dönüş seferi
			{
				"id": 2,
				"village_id": 52,
				"owner": "Lord Morgi",
				"type": "return",
				"state": "returning",
				"origin_movement_id": 1,
				"battle_seed": 808338827,
				"from_village_id": 13,
				"to_village_id": 52,
				"from_x": 160,
				"from_y": 35,
				"to_x": 165,
				"to_y": 42,
				"depart_unix": now_u - 400,
				"arrive_unix": now_u - 10, # 00:00 süresi dolmuş
				"return_unix": now_u - 10,
				"units": {"spy": 6},
				"carry": {"wood": 0, "stone": 0, "iron": 0},
			}
		],
		"reports": [],
		"queues": [],
	}


func _test_multi_village_movement_collision_and_flicker() -> void:
	print("-- 1. Çoklu köylü oyuncuda origin_movement_id çakışması & yabancı 00:00 titremesi --")
	var gs = root.get_node_or_null("GameState")
	var wm = root.get_node_or_null("WorldManager")
	var st := _make_multi_village_state()
	var now_u := int(st["world"]["sim_now_unix"])

	# Lord Gorgi 51'den 52'ye yeni casus göndersin; Movement.next_id origin_movement_id=1 ile çakışmamalı
	var send_res := Movement.send_spy(st, 51, 52, {"spy": 3}, now_u)
	_assert(bool(send_res.get("ok", false)), "Yeni casus gönderildi")
	var new_mv: Dictionary = send_res.get("movement", {})
	var new_mid := int(new_mv.get("id", 0))
	_assert(new_mid >= 3, "Movement.next_id yabancı origin_movement_id=1/id=2 ile çakışmadı (id=%d)" % new_mid)

	gs.from_dict(st)
	gs.active_village_id = 51

	var wmap := WorldMapScene.instantiate()
	root.add_child(wmap)
	var visible_movs: Array = wmap._collect_my_movements(gs)
	_assert(visible_movs.size() == 1, "Haritada yalnızca Lord Gorgi'nin kendi aktif seferi görünüyor (yabancı 00:00 dönüşü gizli, count=%d)" % visible_movs.size())
	_assert(visible_movs.size() == 1 and int((visible_movs[0] as Dictionary).get("id", -1)) == new_mid, "Yeni gönderilen casus haritadan silinmedi")

	# Eski kayıtlardan kalan id=1 senaryosu bile gelse, kapsamlı key yüzünden silinmemeli
	var st2 := _make_multi_village_state()
	var legacy_mv: Dictionary = new_mv.duplicate(true)
	legacy_mv["id"] = 1
	(st2["movements"] as Array).append(legacy_mv)
	var merged: Array = wm._merge_player_and_remote_movements(st2["movements"], st2["movements"], "Lord Gorgi", {13: true, 51: true})
	_assert(merged.size() == 1 and int((merged[0] as Dictionary).get("from_village_id", -1)) == 51, "WorldManager: id=1 olsa bile başka oyuncunun origin_movement_id=1 dönüşü yeni saldırıyı silmiyor ve yabancı süresi dolmuş dönüş eleniyor")
	wmap.free()


func _test_village_incoming_attack_perf_optimization() -> void:
	print("-- 2. Gelen saldırıda Köy UI gölge/StyleBox optimizasyonu --")
	var gs = root.get_node_or_null("GameState")
	var st := _make_multi_village_state()
	var now_u := int(Time.get_unix_time_from_system())
	(st["movements"] as Array).append({
		"id": 9,
		"village_id": 52,
		"owner": "Lord Morgi",
		"type": "attack",
		"state": "outgoing",
		"from_village_id": 52,
		"to_village_id": 51,
		"from_x": 165,
		"from_y": 42,
		"to_x": 168,
		"to_y": 33,
		"depart_unix": now_u - 10,
		"arrive_unix": now_u + 300,
		"units": {"axe": 120},
		"carry": {"wood": 0, "stone": 0, "iron": 0},
	})
	gs.from_dict(st)
	gs.active_village_id = 51

	var vill := VillageScene.instantiate()
	root.add_child(vill)
	vill._update_incoming_attack_alarm(0.016, true)
	var frame_sb := vill._attack_red_frame.get_theme_stylebox("panel") as StyleBoxFlat
	_assert(frame_sb != null and frame_sb.shadow_size == 0 and not frame_sb.draw_center, "Tam ekran kırmızı çerçevede pahalı shadow_size=0")
	_assert(vill._attack_banner_sb != null and vill._attack_banner_sb.shadow_size == 0, "Alarm banner'ında pahalı blur shadow kaldırıldı")
	var bg_before: Color = vill._attack_banner_sb.bg_color
	vill._update_incoming_attack_alarm(0.15, false)
	_assert(vill._attack_banner_sb.bg_color == bg_before, "Alarm StyleBox rengi her karede mutasyona uğratılmıyor (tema yeniden çizimi yok)")
	vill.free()


func _test_incoming_attack_labels_and_masked_details_ui() -> void:
	print("-- 3 & 4. Gelen saldırı/casus etiketleri, gizli düşman birlikleri, modal boyutu ve Kapat kontrastı --")
	var gs = root.get_node_or_null("GameState")
	var st := _make_multi_village_state()
	var now_u := int(Time.get_unix_time_from_system())
	var inc_spy := {
		"id": 15,
		"village_id": 52,
		"owner": "Lord Morgi",
		"type": "spy",
		"state": "outgoing",
		"creeping": false,
		"from_village_id": 52,
		"to_village_id": 51,
		"from_x": 165,
		"from_y": 42,
		"to_x": 168,
		"to_y": 33,
		"depart_unix": now_u - 5,
		"arrive_unix": now_u + 400,
		"units": {"spy": 42},
		"carry": {"wood": 0, "stone": 0, "iron": 0},
	}
	st["movements"] = [inc_spy]
	gs.from_dict(st)
	gs.active_village_id = 51

	var wmap := WorldMapScene.instantiate()
	root.add_child(wmap)
	wmap._refresh_movement_status_bar()
	var top_txt := str(wmap.movement_status_label.text)
	var bot_txt := str(wmap.bottom_march_title_label.text)
	_assert(top_txt.find("Sevkiyat") == -1 and top_txt.find("Casus") != -1, "Gelen casus saldırısı üst çubukta 'Gelen Sevkiyat' değil 'Gelen Casus Saldırısı' yazar: " + top_txt)
	_assert(bot_txt.find("Kervan") == -1 and bot_txt.find("Gelen Casus") != -1, "Gelen casus saldırısı alt çubukta 'Gelen Kervan' değil 'Gelen Casus' yazar: " + bot_txt)

	# Şimdi gerçek bir düşman saldırısı ile Detay modalını kontrol edelim
	var inc_atk := inc_spy.duplicate(true)
	inc_atk["id"] = 16
	inc_atk["type"] = "attack"
	inc_atk["units"] = {"axe": 250, "heavy": 80}
	st["movements"] = [inc_atk]
	gs.from_dict(st)
	wmap._open_movement_details(inc_atk)

	var modal: PanelContainer = wmap.movement_detail_panel
	var vp: Vector2 = (wmap as Control).get_viewport_rect().size
	_assert(modal != null and modal.position.x >= 0.0 and modal.position.x + modal.size.x <= vp.x, "Hareket detay penceresi yatayda ekrana sığıyor (x=%.1f, w=%.1f, vp.x=%.1f)" % [modal.position.x, modal.size.x, vp.x])
	_assert(modal.position.y >= 0.0 and modal.position.y + modal.size.y <= vp.y, "Hareket detay penceresi dikeyde ekrana sığıyor (y=%.1f, h=%.1f, vp.y=%.1f)" % [modal.position.y, modal.size.y, vp.y])
	var mask_lbl := modal.find_child("MaskedEnemyIntelLabel", true, false) as Label
	_assert(mask_lbl != null, "Gelen saldırıda düşman birlik içeriği yerine gizlilik mesajı gösteriliyor")
	var all_lbl_texts := ""
	for node in modal.find_children("*", "Label", true, false):
		all_lbl_texts += " " + (node as Label).text
	_assert(all_lbl_texts.find("Baltacı") == -1 and all_lbl_texts.find("250") == -1 and all_lbl_texts.find("Kara Şövalye") == -1, "Savunan detay ekranında düşman birlik adları ve sayıları KESİNLİKLE görünmüyor")

	var dismiss_btn := modal.find_child("DetailDismissButton", true, false) as Button
	_assert(dismiss_btn != null, "Kapat butonu mevcut")
	if dismiss_btn != null:
		var d_sb := dismiss_btn.get_theme_stylebox("normal") as StyleBoxFlat
		var f_col := dismiss_btn.get_theme_color("font_color")
		_assert(d_sb != null and d_sb.bg_color.get_luminance() < 0.25 and f_col.get_luminance() > 0.85, "Kapat butonu koyu zemin + parlak beyaz yazı ile yüksek kontrastlı")
	wmap.free()


func _test_attacker_spy_report_read_status_and_badge() -> void:
	print("-- 5. Saldıranın casus raporunu okuyunca okundu düşmesi ve BottomNav rozetinin güncellenmesi --")
	var gs = root.get_node_or_null("GameState")
	var st := _make_multi_village_state()
	# Önce 52 -> 51 yeni bir casus gönderelim ve vardıralım (Arrival._spy_report_data from_village_id'yi de yazmalı)
	var send_res := Movement.send_spy(st, 51, 52, {"spy": 8}, 5000)
	_assert(bool(send_res.get("ok", false)), "Saldıran casus gönderdi")
	var mv: Dictionary = send_res.get("movement", {})
	ActionSimulator.process_tick(st, int(mv.get("arrive_unix", 5500)) + 1, 1.0)

	# Ek olarak eski formatta from_village_id eksik bir casus raporu da ekleyelim (geriye dönük uyumluluk testi)
	var legacy_spy_rep := {
		"id": 999,
		"type": "spy",
		"unix": 4000,
		"village_id": 51,
		"unread": true,
		"data": {
			"type": "spy",
			"target_village_id": 52,
			"target_name": "Başkent",
			"target_owner": "Lord Morgi",
			"spy_survivors": 5,
			"spy_losses": 0,
			"defence_spies": 0,
		}
	}
	(st["reports"] as Array).append(legacy_spy_rep)

	gs.from_dict(st)
	gs.active_village_id = 51

	var bnav := BottomNavScene.instantiate()
	root.add_child(bnav)
	bnav._update_report_badge()
	_assert(bnav.report_badge.visible and int(bnav.badge_label.text) == 2, "Saldıranda başlangıçta 2 okunmamış casus raporu rozeti var (okunan=%s)" % bnav.badge_label.text)

	var reps_ui := ReportsScene.instantiate()
	root.add_child(reps_ui)
	var att_new_rep: Dictionary = {}
	for r in gs.reports:
		if typeof(r) == TYPE_DICTIONARY and str((r as Dictionary).get("type", "")) == "spy" and int((r as Dictionary).get("id", 0)) != 999:
			att_new_rep = r
			break
	_assert(int((att_new_rep.get("data", {}) as Dictionary).get("from_village_id", 0)) == 51, "Yeni casus raporunda from_village_id mevcut")

	# Her iki casus raporunu saldıran okuyunca rozet 0'a düşmeli (eskiden legacy raporda 0 vs -1 yüzünden düşmüyordu!)
	reps_ui._set_report_read(att_new_rep, true)
	bnav._update_report_badge()
	_assert(bnav.report_badge.visible and int(bnav.badge_label.text) == 1, "İlk casus raporu okunduktan sonra sayaç 1'e düştü")
	reps_ui._set_report_read(legacy_spy_rep, true)
	bnav._update_report_badge()
	_assert(not bnav.report_badge.visible, "Eski format casus raporu okunduktan sonra BottomNav okunmamış rozeti tamamen kapandı (0)")

	reps_ui.free()
	bnav.free()
