extends SceneTree
## test_build24_features.gd — Build 24 Kapsamlı Doğrulama Paketi:
## 1) ResourceBar (Desktop + Dynamic Island 118/148/162):
##    - Köy adı sağa girintili, ✏️ ikonu hemen yanında (gereksiz boşluk yok)
##    - PointsBox (👑 P) hemen köy adının altında, boşluksuz
##    - ResourcesRow hemen altında, köy alanı vakit kaybetmeden başlar
##    - Elmas & Pazar butonları hem genişlikte hem yükseklikte büyümüş ve Dynamic Island arkasına girmez
## 2) Köy ekranında yatay kaydırma kilitli (sadece dikey kaydırma aktif), en sola yaslı -> Maden ocağı tam görünür
## 3) İttifak kurulduğunda bayat cloud poll / state_changed yüzünden İttifak Kur ekranına geri sekmez
## 4) Kışla Akıncı Süvari (light) eğitim & nüfus hesabı: ResourceBar == Kışla tutarlılığı + sızmış settlers_reserved onarımı

const VM := preload("res://scripts/model/VillageModel.gd")
const RE := preload("res://scripts/rules/RulesEngine.gd")
const EconomyAPI := preload("res://scripts/sim/economy/EconomyAPI.gd")
const ArmyAPI := preload("res://scripts/sim/army/ArmyAPI.gd")
const ArmySim := preload("res://scripts/sim/army/ArmySimulator.gd")

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
	var eb := root.get_node_or_null("EventBus")
	var tm := root.get_node_or_null("TutorialManager")
	var qm := root.get_node_or_null("QuestManager")

	_assert(gd != null and gc != null and gs != null and wm != null and auth != null and eb != null, "Core autoloads ready")
	if gd != null and gd.has_method("load_all"):
		gd.call("load_all", true)
	if tm != null:
		tm.set("tutorial_enabled_in_headless", false)
	if qm != null:
		qm.set("quest_enabled_in_headless", false)

	wm.call("wipe_all_local_data")
	auth.call("clear_all_account_data")
	auth.call("login_with_apple", "Lord Build24", "b24@privaterelay.appleid.com", "apple_uid_b24")
	var joined: bool = bool(wm.call("join_world", 1, "Lord Build24", 168, 33))
	_assert(joined and bool(gs.call("has_active_village")), "World 1 joined")

	var pv: Dictionary = gs.call("get_active_village")
	pv["name"] = "Baskentim"
	pv["x"] = 168
	pv["y"] = 33
	pv["points"] = 1550
	pv["buildings"] = {
		"main": 10, "farm": 8, "wood": 6, "stone": 6, "iron": 6,
		"storage": 28, "hide": 1, "barracks": 7, "wall": 5,
		"market": 1, "stable": 2, "garage": 5, "snob": 1, "smith": 1
	}
	pv["researched"] = {"farmer": true, "spear": true, "sword": true, "axe": true, "spy": true, "bow": true, "light": true}
	pv["resources"] = {"wood": 29000, "stone": 23000, "iron": 28000}
	pv["units"] = {}
	pv["settlers_reserved"] = 600 # Bilerek sızdırılmış eski rezerv!
	gs.queues = []
	gs.player["diamonds"] = 345
	gs.player["tutorial_completed"] = true

	await _test_header_layout(gc)
	await _test_village_horizontal_lock()
	await _test_alliance_create_antiflicker(wm, gs, eb)
	await _test_barracks_light_and_population_parity(gs, pv)

	wm.call("wipe_all_local_data")
	auth.call("clear_all_account_data")

	print("SONUC: %d BASARILI, %d BASARISIZ" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_header_layout(gc: Node) -> void:
	print("\n--- 1) Header (ResourceBar) Build 24 Yerleşim Testleri ---")
	var rbar_scene: PackedScene = load("res://ui/ResourceBar.tscn")
	var rbar := rbar_scene.instantiate() as PanelContainer
	rbar.size = Vector2(1080, 159)
	root.add_child(rbar)
	await _tick(3)

	var left_wrap := rbar.find_child("LeftWingWrap", true, false) as Control
	var left_wing := rbar.find_child("LeftWing", true, false) as Control
	var v_info := rbar.find_child("VillageInfo", true, false) as Control
	var v_name := rbar.find_child("VillageName", true, false) as Label
	var btn_ren := rbar.find_child("BtnRenameVillage", true, false) as Control
	var pts_box := rbar.find_child("PointsBox", true, false) as Control
	var res_row := rbar.find_child("ResourcesRow", true, false) as Control
	var btn_dia := rbar.find_child("BtnDiamonds", true, false) as Control
	var btn_mkt := rbar.find_child("BtnMarket", true, false) as Control

	_assert(left_wrap != null and left_wing != null and v_info != null and v_name != null and btn_ren != null and pts_box != null and res_row != null and btn_dia != null and btn_mkt != null, "ResourceBar tüm düğümler bulundu")

	for s_top in [118.0, 148.0, 162.0]:
		gc.set("_test_island_width", 390.0)
		gc.set("_safe_top_px", s_top)
		rbar.size = Vector2(1080, 210)
		rbar.call("refresh")
		await _tick(3)

		var bar_h := float(rbar.call("get_bar_height"))
		var name_x := v_name.global_position.x
		var gap_ren := btn_ren.global_position.x - (v_name.global_position.x + v_name.size.x)
		var gap_pts := pts_box.global_position.y - (v_info.global_position.y + v_info.size.y)
		var left_end := left_wrap.global_position.x + left_wrap.size.x
		var dia_x := btn_dia.global_position.x
		var res_y := res_row.global_position.y
		var lw_cy := left_wing.global_position.y + left_wing.size.y * 0.5
		var dia_cy := btn_dia.global_position.y + btn_dia.size.y * 0.5

		_assert(name_x >= 40.0, "DI(%.0f): Köy ismi köşeden sağa kaydırılmış (x=%.1f >= 40)" % [s_top, name_x])
		_assert(gap_ren >= 0.0 and gap_ren <= 16.0, "DI(%.0f): Kalem ikonu köy isminin hemen yanında (gap=%.1f <= 16)" % [s_top, gap_ren])
		_assert(gap_pts >= -2.0 and gap_pts <= 10.0, "DI(%.0f): Puan kutusu hemen köy isminin altında (gap=%.1f)" % [s_top, gap_pts])
		_assert(res_y >= 104.0 and res_y <= 142.0, "DI(%.0f): Hammaddeler hemen adanın/puanın altında, boş bant yok (res_y=%.1f)" % [s_top, res_y])
		_assert(bar_h <= 210.0, "DI(%.0f): Bar yüksekliği sıkı ve köy ekranı hemen başlıyor (h=%.1f <= 210)" % [s_top, bar_h])
		_assert(btn_dia.size.x >= 170.0 and btn_dia.size.y >= 70.0, "DI(%.0f): Elmas butonu genişletilip yükseltildi (%s)" % [s_top, str(btn_dia.size)])
		_assert(btn_mkt.size.x >= 172.0 and btn_mkt.size.y >= 70.0, "DI(%.0f): Pazar butonu genişletilip yükseltildi (%s)" % [s_top, str(btn_mkt.size)])
		_assert(dia_x >= 714.0, "DI(%.0f): Elmas/Pazar dinamik adanın arkasında değil (x=%.1f >= 714)" % [s_top, dia_x])
		_assert(left_end <= 368.0, "DI(%.0f): Sol kanat dinamik adaya çarpmıyor (end=%.1f <= 368)" % [s_top, left_end])
		_assert(absf(lw_cy - dia_cy) <= 3.0, "DI(%.0f): Sol sütun ile sağ butonlar dikey simetrik (diff=%.1f)" % [s_top, absf(lw_cy - dia_cy)])

	gc.set("_test_island_width", -1.0)
	gc.set("_safe_top_px", 0.0)
	rbar.queue_free()
	await _tick(2)


func _test_village_horizontal_lock() -> void:
	print("\n--- 2) Köy Yatay Kaydırma Kilidi & Maden Ocağı Görünürlüğü ---")
	var vil_scene: PackedScene = load("res://scenes/Village.tscn")
	for vp_sz in [Vector2(1080, 2343), Vector2(1080, 1920)]:
		var holder := Control.new()
		holder.position = Vector2.ZERO
		holder.size = vp_sz
		root.add_child(holder)
		var vil := vil_scene.instantiate() as Control
		holder.add_child(vil)
		await _tick(4)

		var va := vil.get("village_area") as Control
		_assert(va != null, "VillageArea (%s) yüklü" % str(vp_sz))
		if va != null:
			var scaled_w: float = 1080.0 * va.scale.x
			var expected_x: float = (vp_sz.x - scaled_w) * 0.5 if scaled_w <= vp_sz.x + 1.0 else (vp_sz.x - scaled_w)
			_assert(absf(va.position.x - expected_x) <= 1.5, "Viewport %s başlangıç X en sola sabit (x=%.1f, exp=%.1f)" % [str(vp_sz), va.position.x, expected_x])

			var y_before: float = va.position.y
			vil.call("_pan_by", Vector2(200.0, 0.0))
			_assert(absf(va.position.x - expected_x) <= 1.5, "Viewport %s sağa yatay pan kilitli (x=%.1f)" % [str(vp_sz), va.position.x])
			vil.call("_pan_by", Vector2(-200.0, -140.0))
			_assert(absf(va.position.x - expected_x) <= 1.5, "Viewport %s sola yatay pan kilitli (x=%.1f)" % [str(vp_sz), va.position.x])
			_assert(va.position.y < y_before, "Viewport %s dikey kaydırma (yukarı/aşağı) serbest (%.1f -> %.1f)" % [str(vp_sz), y_before, va.position.y])

			var bv_iron := vil.call("get_building_view", "iron") as Control
			_assert(bv_iron != null, "Maden ocağı düğümü bulundu")
			if bv_iron != null:
				var plate := bv_iron.get("_name_plate") as Control
				var rect_end: float = plate.get_global_rect().end.x if plate != null else bv_iron.get_global_rect().end.x
				_assert(rect_end <= vp_sz.x + 1.0, "Viewport %s Maden ocağı yazısı tamamen ekranda (end_x=%.1f <= %.1f)" % [str(vp_sz), rect_end, vp_sz.x])

		vil.queue_free()
		holder.queue_free()
		await _tick(2)


func _test_alliance_create_antiflicker(wm: Node, gs: Node, eb: Node) -> void:
	print("\n--- 3) İttifak Kurma Titreme (Flicker) Koruması Testleri ---")
	var ally_scene: PackedScene = load("res://scenes/Alliance.tscn")
	var ally := ally_scene.instantiate() as Control
	ally.size = Vector2(1080, 1920)
	root.add_child(ally)
	await _tick(3)

	var name_inp := ally.find_child("AllianceNameInput", true, false) as LineEdit
	var tag_inp := ally.find_child("AllianceTagInput", true, false) as LineEdit
	var desc_inp := ally.find_child("AllianceDescInput", true, false) as TextEdit
	var create_btn: Button = null
	for b in ally.find_children("*", "Button", true, false):
		if (b as Button).text.contains("İttifakı Kur"):
			create_btn = b as Button
			break

	_assert(name_inp != null and tag_inp != null and desc_inp != null and create_btn != null, "İttifak kurma formu hazır")
	if name_inp != null and tag_inp != null and desc_inp != null and create_btn != null:
		name_inp.text = "Aslanlar Birligi"
		tag_inp.text = "ASLAN"
		desc_inp.text = "Güç bizde"
		create_btn.emit_signal("pressed")
		await _tick(2)

		_assert(bool(ally.get("_is_member_view_rendered")), "İttifak kurulduktan hemen sonra üye görünümü aktif")
		_assert((gs.alliances as Array).size() == 1, "GameState içinde ittifak oluşturuldu")

		# Sunucudan gecikmiş / bayat (alliances=[]) bir GET poll cevabı gelmiş gibi simüle et!
		var cur_seq: int = int(wm.get("_local_mutation_seq"))
		var stale_poll := {
			"cloud_state": {
				"world_id": 1,
				"last_saved_unix": int(Time.get_unix_time_from_system()) + 5,
				"state": {
					"villages": (gs.villages as Array).duplicate(true),
					"queues": [],
					"alliances": [],
					"player": {"name": "Lord Build24"},
					"active_village_id": int(gs.active_village_id),
				}
			},
			"updated_unix": int(Time.get_unix_time_from_system()) + 5,
		}
		wm.call("apply_cloud_sync", stale_poll, false, maxi(0, cur_seq - 2))
		eb.emit_signal("state_changed")
		await _tick(3)

		_assert((gs.alliances as Array).size() == 1, "Bayat cloud poll GameState.alliances dizisini sıfırlamadı!")
		_assert(bool(ally.get("_is_member_view_rendered")), "Bayat cloud poll Alliance ekranını 'İttifak Kur' ekranına geri döndürmedi!")

		# Kendi save cevabı dönünce kilidin temizlendiğini doğrula
		var ack_save := {
			"cloud_state": {
				"world_id": 1,
				"last_saved_unix": int(Time.get_unix_time_from_system()) + 6,
				"state": gs.to_dict(),
			},
			"updated_unix": int(Time.get_unix_time_from_system()) + 6,
		}
		wm.call("apply_cloud_sync", ack_save, true, cur_seq)
		_assert(int(wm.get("_alliance_lock_until_unix")) == 0, "Sunucu save onayı sonrası ittifak kilidi temizlendi")

		# Ayrılma sonrası bayat poll eski ittifakı geri getirmemeli
		var leave_btn: Button = null
		for b in ally.find_children("*", "Button", true, false):
			if (b as Button).text.contains("Ayrıl"):
				leave_btn = b as Button
				break
		_assert(leave_btn != null, "Ayrıl butonu bulundu")
		if leave_btn != null:
			leave_btn.emit_signal("pressed")
			await _tick(2)
			_assert((gs.alliances as Array).is_empty() and not bool(ally.get("_is_member_view_rendered")), "Ayrılma sonrası üye olunmayan görünüme geçildi")
			var old_seq: int = int(wm.get("_local_mutation_seq")) - 1
			var stale_member_poll := {
				"cloud_state": {
					"world_id": 1,
					"last_saved_unix": int(Time.get_unix_time_from_system()) + 10,
					"state": {
						"villages": (gs.villages as Array).duplicate(true),
						"queues": [],
						"alliances": [{"id": 1, "name": "Aslanlar Birligi", "tag": "ASLAN", "leader": "Lord Build24", "members": [{"name": "Lord Build24", "is_leader": true}]}],
						"player": {"name": "Lord Build24"},
						"active_village_id": int(gs.active_village_id),
					}
				},
				"updated_unix": int(Time.get_unix_time_from_system()) + 10,
			}
			wm.call("apply_cloud_sync", stale_member_poll, false, old_seq)
			eb.emit_signal("state_changed")
			await _tick(2)
			_assert((gs.alliances as Array).is_empty(), "Ayrılma kilidi bayat poll'un eski ittifakı geri yüklemesini engelledi")

	ally.queue_free()
	await _tick(2)


func _test_barracks_light_and_population_parity(gs: Node, pv: Dictionary) -> void:
	print("\n--- 4) Kışla Akıncı Süvari & Nüfus Tutarlılığı Testleri ---")
	var rbar_scene: PackedScene = load("res://ui/ResourceBar.tscn")
	var rbar := rbar_scene.instantiate() as PanelContainer
	root.add_child(rbar)
	var bpanel_scene: PackedScene = load("res://ui/BuildingPanel.tscn")
	var bpanel := bpanel_scene.instantiate() as PanelContainer
	root.add_child(bpanel)
	await _tick(3)

	bpanel.call("show_building", pv, "barracks")
	bpanel.call("_on_tab_train_pressed")
	rbar.call("refresh")
	await _tick(2)

	var max_light := int(bpanel.call("_calculate_max_trainable", "light"))
	var free_after_heal := ArmyAPI.army_capacity(pv, {"queues": gs.queues})
	var pop_rbar := EconomyAPI.population_summary(pv, {"queues": gs.queues})
	var expected_free := RE.max_population(8) - VM.population_used(pv)

	_assert(int(pv.get("settlers_reserved", -1)) == 0, "Boş kuyruk varken sızmış settlers_reserved=600 otomatik 0'a onarıldı")
	_assert(free_after_heal == expected_free and int(pop_rbar.get("free", -1)) == expected_free, "ResourceBar (%d Boş) ile Kışla (%d Müsait) yüzde100 eşit" % [int(pop_rbar.get("free", -1)), free_after_heal])
	_assert(max_light >= 20, "29k/23k/28k kaynak + %d boş nüfus ile >=20 Akıncı Süvari üretilebilir (maks=%d)" % [free_after_heal, max_light])

	var spin := bpanel.find_child("Spin_light", true, false) as SpinBox
	var train_btn := bpanel.find_child("TrainBtn_light", true, false) as Button
	_assert(spin != null and train_btn != null, "Akıncı Süvari (light) Spin_light ve TrainBtn_light bulundu")
	if spin != null and train_btn != null:
		spin.value = 20
		await _tick(1)
		_assert(not train_btn.disabled, "20 Akıncı Süvari için Eğit butonu aktif")
		train_btn.emit_signal("pressed")
		await _tick(2)

		var pv_now: Dictionary = gs.call("get_active_village")
		var pop_after := EconomyAPI.population_summary(pv_now, {"queues": gs.queues})
		var cit_lbl := bpanel.get("citizen_label") as Label
		var rbar_cit := rbar.get("citizens_label") as Label
		_assert(int(pv_now.get("settlers_reserved", 0)) == 80, "20 Akıncı Süvari sonrası 80 nüfus rezerve edildi")
		_assert(int(pop_after.get("free", -1)) == expected_free - 80, "Rezerv sonrası ResourceBar boş nüfus 80 azaldı (%d)" % int(pop_after.get("free", -1)))
		_assert(rbar_cit != null and rbar_cit.text == ("%d Boş" % (expected_free - 80)), "Üst bar yazısı doğru: %s" % (rbar_cit.text if rbar_cit else ""))
		_assert(cit_lbl != null and cit_lbl.text.contains("Müsait Vatandaş: %d" % (expected_free - 80)), "Kışla yazısı üst barla eşleşti: %s" % (cit_lbl.text if cit_lbl else ""))

	# Eski tipte "settlers" alanı eksik kuyruk öğesi tamamlanınca da rezerv sızmamalı
	var st_sim: Dictionary = gs.to_dict()
	st_sim["queues"].append({
		"id": 9999,
		"village_id": int(pv["id"]),
		"type": "train",
		"key": "light",
		"count": 5,
		"finish_unix": 1000,
	})
	ArmySim.process_tick(st_sim, 9999999999, 1.0)
	gs.from_dict(st_sim)
	var pv_fin: Dictionary = gs.call("get_active_village")
	_assert(int(pv_fin.get("units", {}).get("light", 0)) == 25, "Tüm Akıncı Süvariler tamamlandı (25 Adet)")
	_assert(int(pv_fin.get("settlers_reserved", -1)) == 0, "Eğitim bitince settlers_reserved 0'a sıfırlandı")

	# Mevcut ordu Değirmen kapasitesini doldurunca HEM ResourceBar HEM Kışla 0 göstermeli
	pv_fin["units"]["spear"] = expected_free - 100
	var pop_full := EconomyAPI.population_summary(pv_fin, {"queues": gs.queues})
	var cap_full := ArmyAPI.army_capacity(pv_fin, {"queues": gs.queues})
	_assert(int(pop_full.get("free", -1)) == 0 and cap_full == 0, "Ordu nüfusu doluyken ResourceBar (0) == Kışla (0) tutarlı")

	bpanel.queue_free()
	rbar.queue_free()
	await _tick(2)
