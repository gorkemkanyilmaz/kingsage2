extends SceneTree
## test_logout_relogin_and_messages.gd — Logout -> Apple Re-Login, Brand-New Account Join,
## and Message Deduplication / Persistent Read / Delete E2E Verification.

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
	print("  E2E: LOGOUT -> APPLE RELOGIN & MESSAGES PERSISTENCE")
	print("==================================================")

	var wm := _root_node("WorldManager")
	var auth := _root_node("AuthManager")
	var gs := _root_node("GameState")
	var sm := _root_node("SaveManager")
	_assert(wm != null and auth != null and gs != null and sm != null, "Autoloads loaded")
	if wm == null or auth == null or gs == null or sm == null:
		quit(1)
		return

	wm.call("wipe_all_local_data")
	auth.call("clear_all_account_data")

	# 1. Brand-new Apple user first login + World 1 join
	var prof1: Dictionary = auth.call("login_with_apple", "Lord Gorgi", "gorgi@icloud.com", "apple_uid_gorgi")
	_assert(bool(prof1.get("is_logged_in", false)) and str(auth.get("display_name")) == "Lord Gorgi", "Apple login succeeded for Lord Gorgi")
	_assert(not bool(wm.call("has_player_village", 1, "Lord Gorgi")), "Brand-new account has no village before joining")
	_assert(not bool(wm.call("is_player_conquered", 1, "Lord Gorgi")), "Brand-new account is NOT conquered")

	var joined: bool = bool(wm.call("join_world", 1, "Lord Gorgi", 35, 35))
	_assert(joined, "Brand-new account cleanly joined World 1")
	_assert(bool(wm.call("has_player_village", 1, "Lord Gorgi")), "has_player_village true after World 1 join")
	_assert(bool(gs.call("has_active_village")), "GameState has active village")
	var active_vid := int(gs.get("active_village_id"))
	gs.call("rename_village", active_vid, "BaşkentTest")

	# Inject 3 duplicate welcome messages to reproduce production bug
	var base_ts := int(Time.get_unix_time_from_system())
	gs.set("messages", [
		{"id": 1, "from": "Taht ve Kılıç Konseyi", "to": "Lord Gorgi", "subject": "🛡️ Dünya 1'ye Hoş Geldiniz, Sayın Lord", "body": "1", "created_unix": base_ts - 120, "read": false},
		{"id": 2, "from": "Taht ve Kılıç Konseyi", "to": "Lord Gorgi", "subject": "👑 Dünya 1'ye Hoş Geldiniz, Sayın Lord", "body": "2", "created_unix": base_ts - 60, "read": false},
		{"id": 3, "from": "Taht ve Kılıç Konseyi", "to": "Lord Gorgi", "subject": "👑 Dünya 1'ye Hoş Geldiniz, Sayın Lord", "body": "3", "created_unix": base_ts, "read": false},
	])
	wm.call("notify_local_mutation")
	wm.call("save_active_world", false)

	# 2. Verify Reports scene deduplicates 3 welcome messages into 1, marks read, deletes
	var reports_scene: PackedScene = load("res://scenes/Reports.tscn")
	var reports_inst = reports_scene.instantiate()
	reports_inst.set("_current_tab", "messages")
	reports_inst.get_script().set("initial_tab", "messages")
	root.add_child(reports_inst)
	await process_frame

	var list_vb := reports_inst.get("report_list") as VBoxContainer
	_assert(list_vb != null and list_vb.get_child_count() == 1, "Reports messages list deduplicated 3 welcome messages into 1 card (count=%d)" % (list_vb.get_child_count() if list_vb != null else -1))

	var bnav_scene: PackedScene = load("res://ui/BottomNav.tscn")
	var bnav_inst = bnav_scene.instantiate()
	root.add_child(bnav_inst)
	bnav_inst.call("_update_badges")
	var badge_lbl := bnav_inst.get("message_badge_label") as Label
	_assert(badge_lbl != null and badge_lbl.text == "1", "BottomNav message badge shows '1' instead of '3' (text=%s)" % (badge_lbl.text if badge_lbl != null else "null"))

	# Mark welcome message read via Reports._show_message_detail
	var msg_dict: Dictionary = gs.get("messages")[0]
	reports_inst.call("_show_message_detail", msg_dict)
	bnav_inst.call("_update_badges")
	var msg_badge := bnav_inst.get("message_badge") as Control
	_assert(msg_badge != null and not msg_badge.visible, "Message badge cleared after reading message")

	# Simulate stale cloud sync bringing unread welcome copies back -> must stay read & 1 copy!
	var stale_cloud := wm.call("load_world_dict", 1) as Dictionary
	var sc_state: Dictionary = (stale_cloud.get("state", {}) as Dictionary).duplicate(true)
	sc_state["messages"] = [
		{"id": 11, "from": "Taht ve Kılıç Konseyi", "to": "Lord Gorgi", "subject": "👑 Dünya 1'ye Hoş Geldiniz, Sayın Lord", "body": "Stale", "created_unix": base_ts + 50, "read": false},
		{"id": 12, "from": "Taht ve Kılıç Konseyi", "to": "Lord Gorgi", "subject": "🛡️ Dünya 1'ye Hoş Geldiniz, Sayın Lord", "body": "Stale2", "created_unix": base_ts + 60, "read": false},
	]
	wm.call("apply_cloud_sync", {"ok": true, "display_name": "Lord Gorgi", "cloud_state": sc_state, "updated_unix": base_ts + 100})
	bnav_inst.call("_update_badges")
	_assert(not msg_badge.visible, "Welcome message stays read after stale cloud sync")
	_assert((gs.get("messages") as Array).size() == 1, "Messages stay deduplicated (size=1) after stale cloud sync")

	# Delete message via Reports._delete_message -> stale sync must NOT bring it back
	reports_inst.call("_delete_message", (gs.get("messages") as Array)[0])
	_assert((gs.get("messages") as Array).is_empty(), "Message deleted locally")
	wm.call("apply_cloud_sync", {"ok": true, "display_name": "Lord Gorgi", "cloud_state": sc_state, "updated_unix": base_ts + 200})
	_assert((gs.get("messages") as Array).is_empty(), "Deleted message stays deleted even after stale cloud sync")

	reports_inst.queue_free()
	bnav_inst.queue_free()

	# 3. Full Logout -> VillageSelect -> Apple Re-Login flow
	auth.call("logout")
	_assert(not bool(auth.get("is_logged_in")), "AuthManager logged out")
	_assert(not bool(gs.call("has_active_village")), "GameState cleared after logout")

	# Stale post-logout cloud save response arriving AFTER logout must be ignored
	var ignored_post_logout: bool = bool(wm.call("apply_cloud_sync", {"ok": true, "cloud_state": sc_state, "updated_unix": base_ts + 300}, true, 1))
	_assert(not ignored_post_logout, "Late post-logout save response safely ignored instead of overwriting under Lord Gorkem")

	# Now load VillageSelect and run Apple re-login with server cloud payload (even if cloud payload had stale defeated_info!)
	var vs_scene: PackedScene = load("res://scenes/VillageSelect.tscn")
	var vs_inst = vs_scene.instantiate()
	root.add_child(vs_inst)
	await process_frame

	# Check SaveManager.has_save guard when a stale raw save without this user's village exists
	_assert(not bool(sm.call("_raw_save_has_player_village", "Lord SomeoneElse")), "_raw_save_has_player_village rejects other players")

	# Simulate server response on Apple re-login for Lord Gorgi (with server_village fallback + stale defeated_info trap)
	var sv_payload := {
		"id": active_vid,
		"world_id": 1,
		"name": "BaşkentTest",
		"x": 35,
		"y": 35,
		"owner": "Lord Gorgi",
		"points": 110,
	}
	var poison_cloud := (wm.call("load_world_dict", 1) as Dictionary).duplicate(true)
	var pw_st: Dictionary = poison_cloud.get("state", {})
	var pw_wd: Dictionary = pw_st.get("world", {})
	var pw_profs: Dictionary = pw_wd.get("player_profiles", {})
	if pw_profs.has("Lord Gorgi"):
		(pw_profs["Lord Gorgi"] as Dictionary)["defeated_info"] = {"conqueror": ""}
	# Even remove village from cloud_state.villages to verify server_village rescue works!
	var filtered_vs: Array = []
	for vv in pw_st.get("villages", []):
		if typeof(vv) == TYPE_DICTIONARY and int((vv as Dictionary).get("id", -1)) != active_vid:
			filtered_vs.append(vv)
	pw_st["villages"] = filtered_vs

	auth.set("is_logged_in", true)
	auth.set("auth_provider", "apple")
	auth.set("display_name", "Lord Gorgi")
	auth.set("user_id", "apple_uid_gorgi")
	wm.call("apply_cloud_sync", {"ok": true, "display_name": "Lord Gorgi", "cloud_state": poison_cloud, "server_village": sv_payload, "updated_unix": base_ts + 400})

	_assert(bool(wm.call("has_player_village", 1, "Lord Gorgi")), "After Apple re-login: has_player_village(1, 'Lord Gorgi') == true")
	_assert(not bool(wm.call("is_player_conquered", 1, "Lord Gorgi")), "After Apple re-login: is_player_conquered(1, 'Lord Gorgi') == false")
	_assert(not bool(wm.call("maybe_show_conquered_modal_for_current_scene", 1, "Lord Gorgi")), "ConqueredModal blocked when player owns living village")

	var entered: bool = bool(wm.call("enter_world", 1, "Lord Gorgi"))
	_assert(entered, "enter_world(1, 'Lord Gorgi') succeeds immediately after Apple re-login")
	_assert(bool(gs.call("has_active_village")), "GameState has active village after re-entering world")
	var av: Dictionary = gs.call("get_active_village")
	_assert(str(av.get("name", "")) == "BaşkentTest", "Village name 'BaşkentTest' preserved across logout -> Apple re-login")
	_assert(_root_node("ConqueredOverlay") == null, "Zero ConqueredOverlay present on screen")

	vs_inst.queue_free()
	wm.call("wipe_all_local_data")
	auth.call("clear_all_account_data")

	print("==================================================")
	print("  SONUC: %d BASARILI, %d BASARISIZ" % [_passed, _failed])
	print("==================================================")
	quit(1 if _failed > 0 else 0)
