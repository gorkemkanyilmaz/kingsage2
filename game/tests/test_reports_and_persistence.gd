extends SceneTree
## test_reports_and_persistence.gd — Build #14 Regresyon Testi:
## 1) Rapor okundu -> BottomNav rozetinin düşmesi + silinen raporun çıkış/giriş ve cloud sync sonrası geri gelmemesi
## 2) Tutorial ve Görevlerin logout -> relogin sonrası sıfırlanmaması (ve çift ödül verilmemesi)
## 3) Kışla asker eğitimi SpinBox odakta Canlı Miktar Göstergesi ve panel kaldırma

const VillageModel := preload("res://scripts/model/VillageModel.gd")

func _fail(msg: String) -> void:
	printerr("[FAIL] test_reports_and_persistence: ", msg)
	quit(1)


func _assert(cond: bool, msg: String) -> void:
	if not cond:
		_fail(msg)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var gd = root.get_node_or_null("GameData")
	if gd != null and not gd.is_loaded():
		gd.load_all()
	var gs = root.get_node_or_null("GameState")
	var wm = root.get_node_or_null("WorldManager")
	var auth = root.get_node_or_null("AuthManager")
	var qm = root.get_node_or_null("QuestManager")
	var tm = root.get_node_or_null("TutorialManager")
	var reports_scene_res: PackedScene = load("res://scenes/Reports.tscn")
	var bpanel_scene_res: PackedScene = load("res://ui/BuildingPanel.tscn")
	var bnav_scene_res: PackedScene = load("res://ui/BottomNav.tscn")

	_assert(gs != null and wm != null and auth != null and qm != null and tm != null, "Autoloadlar eksik")

	# 1. Temiz test oyuncusu ve dünya kurulumu
	var test_name := "Lord PersistTester"
	wm.reset_all_worlds()
	auth.is_logged_in = true
	auth.auth_provider = "apple"
	auth.display_name = test_name
	auth.user_id = "apple_test_persist_14"

	_assert(wm.join_world(1, test_name, 100, 100), "Dünya 1'e katılım başarısız")
	var v: Dictionary = gs.get_active_village()
	var vid := int(v.get("id", -1))
	_assert(vid > 0, "Aktif köy oluşmalıydı")

	# 2. Tutorial & Görevlerin tamamlanması ve kaydedilmesi
	gs.player["tutorial_completed"] = true
	gs.player["tutorial_step"] = 18
	gs.player["tutorial_reward_claimed"] = true
	v["buildings"]["wood"] = 3
	v["buildings"]["barracks"] = 1
	v["researched"] = {"spear": true}
	v["resources"]["wood"] = 5000
	v["resources"]["stone"] = 5000
	v["resources"]["iron"] = 5000
	gs.player["quests"] = {"claimed": ["q_eco_3"], "stats": {"raids_sent": 1}}

	# 4 okunmamış rapor ekle
	var base_t := int(Time.get_unix_time_from_system())
	gs.reports.clear()
	for i in range(4):
		gs.reports.append({
			"id": 5000 + i,
			"type": "battle",
			"unix": base_t + i,
			"village_id": vid,
			"unread": true,
			"data": {
				"type": "battle",
				"attacker_name": test_name,
				"defender_name": "Barbar Köyü",
				"attacker_won": true,
				"from_village_id": vid,
				"target_village_id": 10 + i,
			},
		})
	wm.save_active_world(true)

	# 3. BottomNav + Reports: Raporları okuma ve silme rozeti temizlemeli
	var bnav: Control = bnav_scene_res.instantiate()
	root.add_child(bnav)
	await process_frame
	var badge_lbl: Label = bnav.get_node_or_null("HBox/BtnReports/ReportBadge/BadgeLabel") as Label
	var badge_panel: Control = bnav.get_node_or_null("HBox/BtnReports/ReportBadge") as Control
	_assert(badge_panel != null and badge_panel.visible and badge_lbl != null and badge_lbl.text == "4", "4 okunmamış rapor gösterilmeliydi: %s" % [badge_lbl.text if badge_lbl != null else "null"])

	var reps_ui: Control = reports_scene_res.instantiate()
	root.add_child(reps_ui)
	await process_frame
	reps_ui.call("_show_detail", gs.reports[0])
	await process_frame
	_assert(badge_panel.visible and badge_lbl.text == "3", "1 rapor okununca rozet 3 olmalıydı: %s" % badge_lbl.text)

	reps_ui.call("_mark_all_reports_read")
	await process_frame
	_assert(not badge_panel.visible, "Tüm raporlar okunduktan sonra rozet gizlenmeliydi")

	var rep_to_del: Dictionary = gs.reports[0]
	var del_ts := int(rep_to_del.get("unix", 0))
	reps_ui.call("_delete_report", rep_to_del)
	await process_frame

	# 4. Hesaptan çık -> tekrar gir + bayat/resurrection cloud sync gelirse bile hem tutorial/görevler hem silinen/okunan raporlar korunmalı!
	var world_snap: Dictionary = wm.load_world_dict(1).duplicate(true)
	auth.logout()
	_assert(not gs.has_active_village(), "Logout sonrası GameState temizlenmeliydi")

	# Eski dünyadaki silinmiş raporu taşıyan bir bulut sync simüle et
	var stale_cloud: Dictionary = world_snap.duplicate(true)
	stale_cloud["last_saved_unix"] = int(world_snap.get("last_saved_unix", 0)) + 10
	stale_cloud["state"]["reports"].append({
		"id": 5000,
		"type": "battle",
		"unix": del_ts,
		"village_id": vid,
		"unread": true,
		"data": {
			"type": "battle",
			"attacker_name": test_name,
			"defender_name": "Barbar Köyü",
			"attacker_won": true,
			"from_village_id": vid,
			"target_village_id": 10,
		},
	})
	stale_cloud["state"]["world"]["player_profiles"][test_name]["tutorial_completed"] = false
	stale_cloud["state"]["world"]["player_profiles"][test_name]["quests"] = {"claimed": [], "stats": {}}
	stale_cloud["state"]["world"]["player_profiles"][test_name]["deleted_report_sigs"] = []

	auth.is_logged_in = true
	auth.display_name = test_name
	wm.apply_cloud_sync({"cloud_state": stale_cloud})
	_assert(wm.enter_world(1, test_name), "Tekrar girişte enter_world başarısız")
	await process_frame

	_assert(bool(gs.player.get("tutorial_completed", false)), "Çıkış/giriş sonrası tutorial_completed true kalmalıydı!")
	var claimed_after: Array = gs.player.get("quests", {}).get("claimed", [])
	_assert(claimed_after.has("q_eco_3"), "Çıkış/giriş sonrası görevler sıfırlanmamalıydı: %s" % [str(claimed_after)])
	_assert(not qm.claim_quest("q_eco_3", gs), "Daha önce alınan görev ödülü tekrar alınamamalı!")

	for r in gs.reports:
		if typeof(r) == TYPE_DICTIONARY and int((r as Dictionary).get("unix", 0)) == del_ts:
			_fail("Silinen rapor cloud sync / tekrar giriş sonrası geri geldi!")
	_assert(not badge_panel.visible, "Okunmuş/silinmiş raporlardan sonra BottomNav rozeti 0 kalmalıydı")

	# 5. BuildingPanel Train SpinBox Canlı Miktar Göstergesi testi
	var bp: Control = bpanel_scene_res.instantiate()
	root.add_child(bp)
	await process_frame
	bp.call("show_building", gs.get_active_village(), "barracks")
	bp.call("switch_tab", 2)
	await process_frame
	var spin: SpinBox = bp.find_child("Spin_spear", true, false) as SpinBox
	_assert(spin != null, "Spin_spear bulunamadı")
	var le := spin.get_line_edit()
	_assert(le != null, "SpinBox LineEdit bulunamadı")
	le.grab_focus()
	le.focus_entered.emit()
	var kb_bar: Control = bp.find_child("TrainKeyboardPreviewBar", true, false) as Control
	var kb_lbl: Label = bp.find_child("PreviewText", true, false) as Label
	le.text = "100"
	le.text_changed.emit("100")
	await process_frame
	_assert(kb_bar != null and kb_bar.visible, "Klavye önizleme çubuğu odakta görünür olmalıydı")
	_assert(kb_lbl != null and kb_lbl.text.contains("100"), "Klavye önizleme çubuğu 100 değerini anlık göstermeliydi: %s" % [kb_lbl.text if kb_lbl != null else ""])
	le.focus_exited.emit()
	await process_frame
	_assert(not kb_bar.visible, "Odak çıkınca klavye önizleme çubuğu gizlenmeliydi")

	print("[PASS] test_reports_and_persistence: tüm kalıcılık, rapor ve eğitim klavyesi kontrolleri geçti!")
	quit(0)
