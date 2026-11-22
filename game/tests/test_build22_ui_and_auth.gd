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
	# 3. ResourceBar Village Points Placement (Desktop & Dynamic Island)
	# ------------------------------------------------------------------
	var rbar_scene: PackedScene = load("res://ui/ResourceBar.tscn")
	var rbar := rbar_scene.instantiate() as PanelContainer
	rbar.size = Vector2(1080, 164)
	root.add_child(rbar)
	await process_frame
	await process_frame

	var left_col := rbar.find_child("VillageLeftCol", true, false) as VBoxContainer
	var v_info := rbar.find_child("VillageInfo", true, false) as HBoxContainer
	var pts_row := rbar.find_child("PointsRow", true, false) as HBoxContainer
	var pts_box := rbar.find_child("PointsBox", true, false) as Control
	var v_name_lbl := rbar.find_child("VillageName", true, false) as Label
	var res_row := rbar.find_child("ResourcesRow", true, false) as HBoxContainer
	_assert(left_col != null and v_info != null and pts_row != null and pts_box != null and v_name_lbl != null and res_row != null, "ResourceBar VillageLeftCol + PointsRow + PointsBox hierarchy found")
	if left_col != null and v_info != null and pts_row != null and pts_box != null and v_name_lbl != null and res_row != null:
		_assert(pts_box.get_parent() == pts_row, "PointsBox moved inside PointsRow")
		_assert(v_info.find_child("PointsBox", true, false) == null, "PointsBox no longer crowding VillageInfo row")
		_assert(pts_box.global_position.y >= v_name_lbl.global_position.y + v_name_lbl.size.y - 6.0, "Desktop: PointsBox positioned below VillageName (pts_y=%.1f, name_end=%.1f)" % [pts_box.global_position.y, v_name_lbl.global_position.y + v_name_lbl.size.y])
		_assert(pts_box.global_position.y + pts_box.size.y <= res_row.global_position.y + 4.0, "Desktop: PointsBox above ResourcesRow (pts_end=%.1f, res_y=%.1f)" % [pts_box.global_position.y + pts_box.size.y, res_row.global_position.y])

		gc.set("_test_island_width", 390.0)
		gc.set("_safe_top_px", 118.0)
		rbar.call("refresh")
		await process_frame
		await process_frame
		_assert(pts_box.global_position.y > v_name_lbl.global_position.y, "Dynamic Island: PointsBox below VillageName")
		_assert(pts_box.global_position.y + pts_box.size.y <= res_row.global_position.y + 6.0, "Dynamic Island: PointsBox above ResourcesRow")
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
