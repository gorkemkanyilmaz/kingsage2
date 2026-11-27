extends SceneTree
## Build 43 Comprehensive Verification Suite
## Tüm 13 Build 43 özelliğini ve hata düzeltmesini uçtan uca doğrular.

var _passes := 0
var _fails := 0


func _assert(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
		print("  [PASS] " + msg)
	else:
		_fails += 1
		printerr("  [FAIL] " + msg)


func _tick(frames: int = 3) -> void:
	for _i in range(frames):
		await process_frame


func _init() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	await _tick(3)
	print("=== BUILD 43 VERIFICATION SUITE ===")

	var gs: Node = root.get_node_or_null("GameState")
	var wm: Node = root.get_node_or_null("WorldManager")
	var sm: Node = root.get_node_or_null("StoreManager")
	var tm: Node = root.get_node_or_null("TutorialManager")
	var gc: Node = root.get_node_or_null("GameClock")
	var gcfg: Node = root.get_node_or_null("GameConfig")

	_assert(gs != null and wm != null and sm != null and tm != null and gc != null and gcfg != null, "Temel autoload'lar yüklü")
	var RulesEngineScript := load("res://scripts/rules/RulesEngine.gd")
	var ProtectionScript := load("res://scripts/sim/actions/Protection.gd")
	var MovementScript := load("res://scripts/sim/actions/Movement.gd")
	var EconomyAPI := load("res://scripts/sim/economy/EconomyAPI.gd")
	var AllianceModelScript := load("res://scripts/model/AllianceModel.gd")
	var VillageModelScript := load("res://scripts/model/VillageModel.gd")
	var gd: Node = root.get_node_or_null("GameData")
	if gd != null and gd.has_method("load_all"):
		gd.call("load_all", true)
	gs.call("reset")

	var v: Dictionary = VillageModelScript.create(100, "Başkent", 100, 100, "Lord Test43", false)
	v["buildings"]["barracks"] = 1
	gs.villages = [v]
	gs.active_village_id = 100
	gs.player["name"] = "Lord Test43"
	gs.player["tutorial_completed"] = true
	gs.player["tutorial_step"] = 23
	var vid: int = 100

	# ------------------------------------------------------------------
	# 1. Bandit Village Attack Protection (#5)
	# ------------------------------------------------------------------
	print("--- 1. Haydut Köyü Koruma Testi ---")
	var bandit_v := {"id": 9901, "x": 102, "y": 102, "owner": "Haydut", "name": "Haydut Kampı", "points": 20, "is_bandit": true, "is_bot": true, "is_barbarian": false, "bonus_type": ""}
	_assert(ProtectionScript.is_unprotected_kind(bandit_v), "Haydut köyü is_unprotected_kind=true döner")
	var now_u: int = int(Time.get_unix_time_from_system())
	v["protection_until"] = now_u + 86400 * 3
	v["protection_until_unix"] = now_u + 86400 * 3
	v["units"] = {"spear": 40, "sword": 20}
	var st_prot: Dictionary = gs.to_dict()
	st_prot["villages"].append(bandit_v)
	var atk_res: Dictionary = MovementScript.send_attack(st_prot, vid, 9901, {"spear": 10}, now_u, {})
	_assert(bool(atk_res.get("ok", false)), "Haydut köyüne saldırı gönderildi")
	_assert(not bool(atk_res.get("outlawed", true)), "Haydut köyüne saldırı Kanun Kaçağı yapmaz")
	var orig_after := {}
	for vv in st_prot["villages"]:
		if int(vv.get("id", -1)) == vid:
			orig_after = vv
			break
	_assert(int(orig_after.get("protection_until", 0)) > now_u, "Haydut köyüne saldırı yeni oyuncu korumasını iptal etmedi")

	var stp_scene := load("res://ui/SendTroopsPanel.tscn") as PackedScene
	var stp: Control = stp_scene.instantiate()
	root.add_child(stp)
	stp.set("_from_village", v)
	stp.set("_to_village", bandit_v)
	_assert(not bool(stp.call("will_drop_attacker_protection", MovementScript.TYPE_ATTACK, {"spear": 10}, now_u)), "SendTroopsPanel haydut saldırısında koruma uyarısı çıkarmaz")
	stp.queue_free()

	# ------------------------------------------------------------------
	# 2. Gizli Depo 5-level tablosu (#1) + Kışla 19 Exact Storage (#9)
	#    + Barracks Queue Overflow (#8) + Köşk Kont Red & Eğitiliyor (#10)
	# ------------------------------------------------------------------
	print("--- 2. BuildingPanel Testleri (#1, #8, #9, #10) ---")
	var village_scene := load("res://scenes/Village.tscn") as PackedScene
	var village_inst: Control = village_scene.instantiate()
	root.add_child(village_inst)
	await _tick(3)

	var bp: Control = village_inst.get("building_panel")
	_assert(bp != null, "BuildingPanel mevcut")

	# #1 Gizli Depo 5 seviye tablosu
	v["buildings"]["hide"] = 2
	bp.call("show_building", v, "hide")
	await _tick(2)
	var hide_cur := bp.find_child("HideCurrentRow", true, false)
	var hide_next3 := bp.find_child("HideNextRow_3", true, false)
	var hide_next6 := bp.find_child("HideNextRow_6", true, false)
	_assert(hide_cur != null and hide_next3 != null and hide_next6 != null, "Gizli Depo güncel + sonraki 4 seviye satırları oluştu")

	# #9 Kışla Sv.19 Depo gereken tam seviye kontrolü
	v["buildings"]["main"] = 20
	v["buildings"]["farm"] = 30
	v["buildings"]["storage"] = 14
	v["buildings"]["barracks"] = 19
	v["resources"] = {"wood": 6000, "stone": 6000, "iron": 6000}
	bp.call("show_building", v, "barracks")
	await _tick(2)
	var det20: Dictionary = RulesEngineScript.cost("barracks", 20)
	var max_res20: int = maxi(int(det20.get("wood", 0)), maxi(int(det20.get("stone", 0)), int(det20.get("iron", 0))))
	var expected_sto := 15
	while expected_sto < 30 and RulesEngineScript.storage_capacity(expected_sto) < max_res20:
		expected_sto += 1
	var req_btn_txt := str((bp.get("upgrade_btn") as Button).text)
	_assert(("Sv.%d" % expected_sto) in req_btn_txt, "Kışla Sv.19 gereken tam Depo seviyesini en başta gösterir (%s)" % req_btn_txt)

	# #8 Kuyruğa 5-6 bina eklenince BuildingPanel ekran dışına taşmıyor
	v["buildings"]["barracks"] = 1
	v["buildings"]["storage"] = 25
	v["buildings"]["farm"] = 25
	v["resources"] = {"wood": 500000, "stone": 500000, "iron": 500000}
	gs.queues = []
	for _q in range(6):
		bp.call("show_building", gs.get_active_village(), "barracks")
		bp.call("_on_upgrade_pressed")
	await _tick(2)
	var vp_rect := village_inst.get_viewport_rect().size
	if bp.size.x > vp_rect.x + 1.0 or bp.size.y > vp_rect.y:
		var vbox_dbg := bp.get_node_or_null("VBox")
		if vbox_dbg != null:
			for ch_d in vbox_dbg.get_children():
				if ch_d is Control and (ch_d as Control).visible:
					print("    [BP_CHILD] ", ch_d.name, " min=", (ch_d as Control).get_combined_minimum_size(), " sz=", (ch_d as Control).size)
	var vbox_bp: Control = bp.get_node_or_null("VBox") as Control
	var vbox_min := vbox_bp.get_combined_minimum_size() if vbox_bp != null else bp.size
	_assert(bp.size.x <= vp_rect.x + 1.0 and vbox_min.x <= 1048.0 and bp.position.y >= 100.0, "6 kuyruktan sonra BuildingPanel ekrandan taşmıyor (size=%s, vbox_min=%s, pos=%s)" % [str(bp.size), str(vbox_min), str(bp.position)])

	# #10 Köşk yetersiz kırmızı + Kont Eğitiliyor geri sayımı
	gs.queues = []
	v = gs.get_active_village()
	v["buildings"]["snob"] = 1
	v["buildings"]["smith"] = 1
	v["buildings"]["market"] = 10
	v["gold_armour"] = 0
	v["resources"] = {"wood": 1000, "stone": 50000, "iron": 50000}
	bp.call("show_building", v, "snob")
	await _tick(2)
	var snob_cost_rtl := bp.find_child("SnobCostRichLabel", true, false) as RichTextLabel
	_assert(snob_cost_rtl != null and "#FF5C5C" in snob_cost_rtl.text, "Köşk yetersiz gereksinimler kırmızı (#FF5C5C) vurgulanıyor")

	v = gs.get_active_village()
	v["gold_armour"] = 1
	v["resources"] = {"wood": 200000, "stone": 200000, "iron": 200000}
	bp.call("show_building", v, "snob")
	bp.call("_on_train_snob_pressed")
	await _tick(2)
	var snob_btn := bp.find_child("TrainSnobBtn", true, false) as Button
	_assert(snob_btn != null and "Kont Eğitiliyor" in snob_btn.text, "Kont eğitimde iken 'Altın Zırh Gerekli' yerine 'Kont Eğitiliyor' gösterilir (%s)" % (snob_btn.text if snob_btn != null else "null"))

	# ------------------------------------------------------------------
	# 3. Market Locked Blue Blink (#4a) & Swinging Hammer (#4b) & Speech Close (#12)
	# ------------------------------------------------------------------
	print("--- 3. Market Mavi Yanıp Sönme (#4) & Speech Close (#12) ---")
	v = gs.get_active_village()
	v["buildings"]["market"] = 0
	v["buildings"]["storage"] = 1
	gs.queues = [{"id": 901, "village_id": vid, "type": "build", "key": "iron", "target_level": 2, "start_unix": now_u - 5, "finish_unix": now_u + 55}]
	village_inst.call("refresh_all")
	var mkt_view: Node = village_inst.call("get_building_view", "market")
	_assert(mkt_view != null and bool(mkt_view.get("is_locked")), "Seviye 0 Market kilitli (is_locked=true)")
	village_inst.call("_update_building_views_progress")
	_assert(bool(mkt_view.get("is_locked")), "_update_building_views_progress sonrasında kilitli Market mavi '+'ya dönmüyor")

	var iron_view: Node = village_inst.call("get_building_view", "iron")
	_assert(iron_view != null and iron_view.get("_hammer_tween") == null, "Yükseltme sırasında dönen sağ çekiç tween'i yok (alt çekiç rozeti kalır)")

	var speech_close := village_inst.find_child("BtnCloseSpeechBubble", true, false) as Button
	_assert(speech_close != null and speech_close.text == "×" and speech_close.custom_minimum_size.x >= 40.0, "Lord konuşma balonu kapatma butonu '×' ve >=40px boyutta")

	# ------------------------------------------------------------------
	# 4. Queued Build Survival vs Cloud Sync (#6) & Değirmen Lv.20 Scroll (#11)
	# ------------------------------------------------------------------
	print("--- 4. Kuyruk Koruma (#6) & Değirmen Sv.20 Scroll (#11) ---")
	v = gs.get_active_village()
	v["buildings"]["iron"] = 5
	v["buildings"]["barracks"] = 4
	v["buildings"]["storage"] = 20
	v["buildings"]["farm"] = 20
	v["resources"] = {"wood": 200000, "stone": 200000, "iron": 200000}
	gs.queues = []
	var b_state: Dictionary = gs.to_dict()
	var bv := {}
	for sv in b_state["villages"]:
		if int(sv.get("id", -1)) == vid:
			bv = sv
			break
	var q1: Dictionary = EconomyAPI.start_build(bv, "iron", b_state)
	var q2: Dictionary = EconomyAPI.start_build(bv, "barracks", b_state)
	gs.from_dict(b_state)
	wm.notify_local_mutation()
	_assert(bool(q1.get("ok", false)) and bool(q2.get("ok", false)) and gs.queues.size() == 2, "Demir 6 ve Kışla 5 sıraya eklendi")
	var cloud_poll_w := {"world_id": 1, "last_saved_unix": now_u + 5, "state": {"villages": [bv.duplicate(true)], "queues": [q1["item"].duplicate(true)]}}
	var local_w_chk := {"world_id": 1, "last_saved_unix": now_u, "state": gs.to_dict()}
	wm.call("_preserve_own_village_progress_from_local", cloud_poll_w, local_w_chk, "Lord Test43")
	_assert((cloud_poll_w["state"]["queues"] as Array).size() == 2, "Eski bulut anketi yeni eklenen Kışla 5 kuyruğunu silmedi")

	# Değirmen Lv.20 speedup scroll stuck check (#11)
	var scroll_now: int = int(sm.call("_current_sim_now"))
	gs.queues = [
		{"id": 501, "village_id": vid, "type": "build", "key": "iron", "target_level": 6, "start_unix": scroll_now - 10, "finish_unix": scroll_now + 120},
		{"id": 502, "village_id": vid, "type": "build", "key": "farm", "target_level": 20, "start_unix": scroll_now + 120, "finish_unix": scroll_now + 750},
	]
	gs.player["scrolls"] = {"build_10m": 2}
	var sp1: Dictionary = sm.call("apply_scroll_to_queue", "build_10m", "build", 501)
	var after_scroll_now: int = int(sm.call("_current_sim_now"))
	_assert(bool(sp1.get("ok", false)), "İlk inşaata 10dk hızlandırma parşömeni uygulandı")
	_assert(gs.queues.size() == 1, "İlk inşaat tamamlandı, sırada Değirmen Lv.20 başa geçti")
	if gs.queues.size() == 1:
		var head_q: Dictionary = gs.queues[0]
		_assert(int(head_q.get("start_unix", 0)) <= after_scroll_now and int(head_q.get("finish_unix", 0)) > int(head_q.get("start_unix", 0)), "Başa geçen Değirmen Lv.20 start_unix <= now ve geri sayımı aktif (donmadı)")

	# ------------------------------------------------------------------
	# 5. Alliance Join Requests & Red Notification Badge (#7)
	# ------------------------------------------------------------------
	print("--- 5. İttifak Katılma İsteği & Kırmızı Bildirim (#7) ---")
	var a_state: Dictionary = gs.to_dict()
	a_state["alliances"] = []
	var c_ally: Dictionary = AllianceModelScript.create_alliance(a_state, "Lord Test43", "Kraliyet Aslanları", "KRL", "Güçlü birlik")
	_assert(bool(c_ally.get("ok", false)), "İttifak oluşturuldu")
	var aid_c: int = int((c_ally.get("alliance", {}) as Dictionary).get("id", 1))
	a_state["villages"].append({"id": 8801, "name": "Aday Kale", "x": 110, "y": 110, "owner": "Lord Aday", "points": 450, "is_bot": false, "is_barbarian": false})
	var j_req: Dictionary = AllianceModelScript.request_join_alliance(a_state, "Lord Aday", aid_c)
	_assert(bool(j_req.get("ok", false)), "Dış oyuncu ittifaka katılma isteği gönderebildi")
	var jr_cnt: int = AllianceModelScript.get_pending_join_request_count(a_state, "Lord Test43")
	_assert(jr_cnt == 1, "Lider için bekleyen istek sayısı=1")

	gs.from_dict(a_state)
	village_inst.call("_update_alliance_badge")
	var ally_badge := village_inst.find_child("AllianceNotifBadge", true, false) as Control
	var ally_cnt_lbl := ally_badge.find_child("CountLabel", true, false) as Label if ally_badge != null else null
	_assert(ally_badge != null and ally_badge.visible and ally_cnt_lbl != null and ally_cnt_lbl.text == "1", "Köy ekranı İttifak butonunda kırmızı bildirim rozeti '1' görünüyor")

	var resp_ok: Dictionary = AllianceModelScript.respond_join_request(a_state, aid_c, "Lord Test43", "Lord Aday", true)
	_assert(bool(resp_ok.get("ok", false)) and AllianceModelScript.get_pending_join_request_count(a_state, "Lord Test43") == 0, "Lider katılma isteğini onayladı ve istek sayısı 0 oldu")
	_assert(not AllianceModelScript.get_player_alliance(a_state, "Lord Aday").is_empty(), "Onaylanan oyuncu ittifaka katıldı")

	# ------------------------------------------------------------------
	# 6. Thermal Config Verification (#13) + Smooth Tutorial Finger (#2)
	# ------------------------------------------------------------------
	print("--- 6. Termal & Tutorial FPS Kontrolü (#2, #13) ---")
	_assert(int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 60)) <= 15, "physics_ticks_per_second <= 15")
	gs.player["tutorial_completed"] = false
	gs.player["tutorial_step"] = 2
	tm.tutorial_enabled_in_headless = true
	tm.set("_active", true)
	_assert(int(gc.call("_compute_adaptive_target_fps")) == 30, "Tutorial aktifken parmak akıcılığı için adaptive FPS=30")
	tm.set("_active", false)

	# Tüm .tscn ve .tres dosyalarında shadow_size = 0 kontrolü
	var bad_shadows: Array[String] = []
	for p_path in ["res://themes/TahtVeKilic.tres", "res://ui/BuildingPanel.tscn", "res://ui/ResourceBar.tscn", "res://ui/BottomNav.tscn", "res://ui/SendTroopsPanel.tscn", "res://scenes/WorldMap.tscn", "res://scenes/Ranking.tscn", "res://scenes/Reports.tscn", "res://scenes/Settings.tscn"]:
		var f := FileAccess.open(p_path, FileAccess.READ)
		if f != null:
			var txt := f.get_as_text()
			f.close()
			var re := RegEx.new()
			re.compile("shadow_size\\s*=\\s*[1-9]")
			if re.search(txt) != null:
				bad_shadows.append(p_path)
	_assert(bad_shadows.is_empty(), "Tüm UI sahnelerinde ve temada shadow_size=0 (kalan=%s)" % str(bad_shadows))

	village_inst.queue_free()
	await _tick(2)

	print("=== BUILD 43 SUMMARY: PASS=%d FAIL=%d ===" % [_passes, _fails])
	quit(1 if _fails > 0 else 0)
