extends SceneTree
## test_build22_ui_and_auth.gd — Build 22 Headless Verification for:
## 1) Alliance Create Input Keyboard/Focus Stability
## 2) Quest Vezir Detail Modal Non-Stretched Height & Width
## 3) ResourceBar Village Points Placement Below Village Name (Desktop & Dynamic Island)
## 4) Settings Removal of BtnTutorialReplay
## 5) WorldManager / AuthManager / NetworkManager Fast Relogin & Lock Guard Improvements

var _passed := 0
var _failed := 0


func _assert(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("  [OK] %s" % msg)
	else:
		_failed += 1
		print("  [FAIL] %s" % msg)


func _root_node(node_name: String) -> Node:
	return root.get_node_or_null(node_name)


func _init() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	print("==================================================")
	print("  E2E: BUILD 22 UI, LAYOUT & FAST RELOGIN FIXES")
	print("==================================================")

	var wm := _root_node("WorldManager")
	var auth := _root_node("AuthManager")
	var gs := _root_node("GameState")
	var eb := _root_node("EventBus")
	var gc := _root_node("GameConfig")
	var qm := _root_node("QuestManager")
	var net := _root_node("NetworkManager")
	_assert(wm != null and auth != null and gs != null and eb != null and gc != null and qm != null and net != null, "All required autoloads present")
	if wm == null or auth == null or gs == null or eb == null or gc == null or qm == null or net == null:
		quit(1)
		return

	wm.call("wipe_all_local_data")
	auth.call("clear_all_account_data")
	auth.call("login_with_apple", "Lord Build22Test", "b22@privaterelay.appleid.com", "apple_uid_b22")
	_assert(str(auth.get("provider_uid")) == "apple_uid_b22", "AuthManager tracks provider_uid")
	var joined: bool = bool(wm.call("join_world", 1, "Lord Build22Test", 45, 45))
	_assert(joined and bool(gs.call("has_active_village")), "Joined World 1 with active village")

	# ------------------------------------------------------------------
	# 1. Alliance Create Screen Input Focus / Keyboard Stability
	# ------------------------------------------------------------------
	var ally_scene: PackedScene = load("res://scenes/Alliance.tscn")
	var ally_inst := ally_scene.instantiate() as Control
	ally_inst.size = Vector2(1080, 1920)
	root.add_child(ally_inst)
	await process_frame
	await process_frame

	var name_inp := ally_inst.find_child("AllianceNameInput", true, false) as LineEdit
	var tag_inp := ally_inst.find_child("AllianceTagInput", true, false) as LineEdit
	var desc_inp := ally_inst.find_child("AllianceDescInput", true, false) as TextEdit
	_assert(name_inp != null and tag_inp != null and desc_inp != null, "Alliance create inputs exist")
	if name_inp != null and tag_inp != null and desc_inp != null:
		name_inp.text = "Kraliyet Muhafızları"
		tag_inp.text = "KM"
		desc_inp.text = "Birlikte güçlüyüz"
		name_inp.grab_focus()
		await process_frame
		_assert(root.gui_get_focus_owner() == name_inp, "AllianceNameInput retains focus")

		for _i in range(5):
			eb.emit_signal("state_changed")
		await process_frame
		_assert(is_instance_valid(name_inp) and name_inp.is_inside_tree(), "AllianceNameInput was NOT destroyed on EventBus.state_changed")
		_assert(name_inp.text == "Kraliyet Muhafızları", "AllianceNameInput draft text preserved across state_changed")
		_assert(root.gui_get_focus_owner() == name_inp, "AllianceNameInput still owns focus after 5 state_changed emits")

		var tag_rect := tag_inp.get_global_rect()
		var touch_ev := InputEventScreenTouch.new()
		touch_ev.pressed = true
		touch_ev.position = tag_rect.get_center()
		touch_ev.set_meta("allow_headless_input_test", true)
		gc._input(touch_ev)
		await process_frame
		_assert(root.gui_get_focus_owner() == name_inp, "Tapping another text input does not release focus/hide keyboard prematurely")
		_assert(bool(gc.call("_has_visible_text_input_at", root, tag_rect.get_center())), "_has_visible_text_input_at detects visible LineEdit target")

	ally_inst.queue_free()
	await process_frame

	# ------------------------------------------------------------------
	# 2. Quest Vezir Modal Sizing (Not Full-Screen Stretched)
	# ------------------------------------------------------------------
	qm.set("quest_enabled_in_headless", true)
	qm.call("open_quest_modal", "q_wood_stone_3")
	await process_frame
	await process_frame

	var modal_center := qm.get("_modal_center") as CenterContainer
	var detail_modal := qm.get("_detail_modal") as PanelContainer
	var vizier_lbl := qm.get("_modal_vizier_text") as RichTextLabel
	var req_lbl := qm.get("_modal_req_label") as RichTextLabel
	_assert(modal_center != null and modal_center.visible and detail_modal != null and detail_modal.visible, "Quest modal and CenterContainer are visible")
	if detail_modal != null and vizier_lbl != null:
		_assert(detail_modal.get_parent() == modal_center, "QuestDetailModal is centered inside QuestModalCenter")
		_assert(detail_modal.size.x >= 720.0 and detail_modal.size.x <= 940.0, "QuestDetailModal width valid: %.1f" % detail_modal.size.x)
		_assert(detail_modal.size.y >= 300.0 and detail_modal.size.y < 1200.0, "QuestDetailModal height compact (not full-screen): %.1f" % detail_modal.size.y)
		_assert(vizier_lbl.size.x >= 350.0, "VizierExplanationLabel wrapped at valid width: %.1f" % vizier_lbl.size.x)

	qm.call("open_quest_modal", "q_unlock_snob")
	await process_frame
	await process_frame
	if detail_modal != null and req_lbl != null:
		_assert(req_lbl.visible and req_lbl.size.x >= 380.0, "ModalReqLabel visible & valid width: %.1f" % req_lbl.size.x)
		_assert(detail_modal.size.y < 1300.0, "Prerequisite quest modal height compact: %.1f" % detail_modal.size.y)
	qm.call("close_quest_modal")

	# ------------------------------------------------------------------
	# 3. ResourceBar Symmetry + Village Points Placement (Desktop & Dynamic Island)
	# ------------------------------------------------------------------
	var rbar_scene: PackedScene = load("res://ui/ResourceBar.tscn")
	var rbar := rbar_scene.instantiate() as PanelContainer
	rbar.size = Vector2(1080, 177)
	root.add_child(rbar)
	await process_frame
	await process_frame

	var vbox_rb := rbar.get_node_or_null("VBox") as VBoxContainer
	var top_row := rbar.find_child("TopRow", true, false) as HBoxContainer
	var left_wing := rbar.find_child("LeftWing", true, false) as VBoxContainer
	var v_info := rbar.find_child("VillageInfo", true, false) as HBoxContainer
	var pts_row := rbar.find_child("PointsRow", true, false) as HBoxContainer
	var pts_box := rbar.find_child("PointsBox", true, false) as Control
	var v_name_lbl := rbar.find_child("VillageName", true, false) as Label
	var res_row := rbar.find_child("ResourcesRow", true, false) as HBoxContainer
	var btn_dia := rbar.find_child("BtnDiamonds", true, false) as Control
	var btn_mkt := rbar.find_child("BtnMarket", true, false) as Control
	_assert(vbox_rb != null and top_row != null and left_wing != null and v_info != null and pts_row != null and pts_box != null and v_name_lbl != null and res_row != null and btn_dia != null and btn_mkt != null, "ResourceBar TopRow/LeftWing + PointsRow + ResourcesRow hierarchy found")
	if vbox_rb != null and top_row != null and left_wing != null and v_info != null and pts_row != null and pts_box != null and v_name_lbl != null and res_row != null and btn_dia != null and btn_mkt != null:
		_assert(v_info.get_parent() == left_wing and pts_row.get_parent() == left_wing and pts_box.get_parent() == pts_row, "VillageInfo + PointsRow stacked cleanly inside LeftWing")
		_assert(v_info.find_child("PointsBox", true, false) == null, "PointsBox no longer inside VillageInfo")
		var d_cy := left_wing.global_position.y + left_wing.size.y * 0.5
		var dia_cy := btn_dia.global_position.y + btn_dia.size.y * 0.5
		var mkt_cy := btn_mkt.global_position.y + btn_mkt.size.y * 0.5
		_assert(absf(d_cy - dia_cy) <= 3.0 and absf(d_cy - mkt_cy) <= 3.0, "Desktop: LeftWing horizontally symmetrical with BtnDiamonds/BtnMarket (diff=%.1f, %.1f)" % [absf(d_cy - dia_cy), absf(d_cy - mkt_cy)])
		_assert(pts_box.global_position.y >= v_name_lbl.global_position.y + v_name_lbl.size.y - 2.0, "Desktop: PointsBox positioned below VillageName (pts_y=%.1f, name_end=%.1f)" % [pts_box.global_position.y, v_name_lbl.global_position.y + v_name_lbl.size.y])
		_assert(pts_box.global_position.y + pts_box.size.y <= res_row.global_position.y + 4.0, "Desktop: PointsBox above ResourcesRow (pts_end=%.1f, res_y=%.1f)" % [pts_box.global_position.y + pts_box.size.y, res_row.global_position.y])

		for safe_top_val in [118.0, 162.0]:
			gc.set("_test_island_width", 390.0)
			gc.set("_safe_top_px", safe_top_val)
			rbar.call("refresh")
			await process_frame
			await process_frame
			var isl_v_cy := left_wing.global_position.y + left_wing.size.y * 0.5
			var isl_d_cy := btn_dia.global_position.y + btn_dia.size.y * 0.5
			var isl_m_cy := btn_mkt.global_position.y + btn_mkt.size.y * 0.5
			_assert(absf(isl_v_cy - isl_d_cy) <= 3.0 and absf(isl_v_cy - isl_m_cy) <= 3.0, "Dynamic Island (%.0f): LeftWing aligned symmetrically with BtnDiamonds/BtnMarket (diff=%.1f, %.1f)" % [safe_top_val, absf(isl_v_cy - isl_d_cy), absf(isl_v_cy - isl_m_cy)])
			_assert(pts_box.global_position.y >= v_name_lbl.global_position.y + v_name_lbl.size.y - 2.0, "Dynamic Island (%.0f): PointsBox below VillageName" % safe_top_val)
			_assert(pts_box.global_position.y + pts_box.size.y <= res_row.global_position.y + 4.0, "Dynamic Island (%.0f): PointsBox above ResourcesRow" % safe_top_val)
		gc.set("_test_island_width", -1.0)
		gc.set("_safe_top_px", 0.0)

	rbar.queue_free()
	await process_frame

	# ------------------------------------------------------------------
	# 4. Settings: BtnTutorialReplay Removed
	# ------------------------------------------------------------------
	var sett_scene: PackedScene = load("res://scenes/Settings.tscn")
	var sett := sett_scene.instantiate() as Control
	root.add_child(sett)
	await process_frame
	_assert(sett.find_child("BtnTutorialReplay", true, false) == null, "BtnTutorialReplay removed from Settings")
	_assert(sett.find_child("BtnLogout", true, false) != null and sett.find_child("BtnDeleteAccount", true, false) != null, "BtnLogout and BtnDeleteAccount intact in Settings")
	sett.queue_free()
	await process_frame

	# ------------------------------------------------------------------
	# 5. Fast Relogin & Save Guard Helpers
	# ------------------------------------------------------------------
	wm.set("_wallet_lock_until_unix", 0)
	var saved_ok: bool = bool(wm.call("save_active_world", true, false))
	_assert(saved_ok, "save_active_world(true, false) succeeded locally")
	var wd_no_lock: Dictionary = wm.call("load_world_dict", 1)
	_assert(not bool(wd_no_lock.get("wallet_authoritative", false)), "force_cloud autosave without wallet lock does NOT mark wallet_authoritative")

	wm.call("notify_local_wallet_mutation")
	wm.call("save_active_world", true, false)
	var wd_with_lock: Dictionary = wm.call("load_world_dict", 1)
	_assert(bool(wd_with_lock.get("wallet_authoritative", false)), "save_active_world marks wallet_authoritative only during wallet lock")

	_assert(wm.has_method("cancel_pending_cloud_poll") and net.has_method("cancel_background_requests"), "Pending poll / background request cancellation methods available")
	auth.call("logout")
	_assert(not bool(auth.get("is_logged_in")) and str(auth.get("provider_uid")).is_empty(), "Logout clears session & provider_uid cleanly")

	wm.call("wipe_all_local_data")
	auth.call("clear_all_account_data")

	print("--------------------------------------------------")
	print("  SONUC: %d BASARILI, %d BASARISIZ" % [_passed, _failed])
	print("==================================================")
	quit(1 if _failed > 0 else 0)
