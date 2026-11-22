extends SceneTree

const MovementScript := preload("res://scripts/sim/actions/Movement.gd")
const MapVillageViewScript := preload("res://scenes/map/MapVillageView.gd")
const ResourceBarScript := preload("res://ui/ResourceBar.gd")

var _pass_count := 0
var _fail_count := 0

func _init() -> void:
	print("--- TEST MAP AND ALLIANCE FEATURES START ---")
	_test_shield_badge_placement()
	_test_alliance_attack_restriction()
	_test_village_renaming_and_header_format()
	_test_world_map_legend_and_categories()
	print("--- TEST SUMMARY: PASS=%d, FAIL=%d ---" % [_pass_count, _fail_count])
	quit(0 if _fail_count == 0 else 1)

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_pass_count += 1
		print("✔ PASS: %s" % msg)
	else:
		_fail_count += 1
		printerr("❌ FAIL: %s" % msg)

func _test_shield_badge_placement() -> void:
	print("\n[1] Testing Shield Protection Badge & Aura Placement...")
	var now := int(Time.get_unix_time_from_system())
	var v_data := {
		"id": 1,
		"name": "Başkent",
		"owner": "Lord Gorkem",
		"x": 100,
		"y": 100,
		"buildings": {"main": 10},
		"protection_until_unix": now + 86400 * 5,
		"is_barbarian": false,
		"is_bot": false
	}

	var view = MapVillageViewScript.new()
	root.add_child(view)
	view.setup(v_data, true, false, "ASLAN")

	var badge: PanelContainer = null
	for child in view.get_children():
		if child is PanelContainer and child != view._info_card:
			badge = child
			break

	_assert(badge != null, "Shield badge exists on protected village")
	if badge != null:
		_assert(badge.position.y <= 10.0, "Shield badge is elevated up (y=%.1f <= 10.0)" % badge.position.y)
		var lbl: Label = badge.get_child(0) as Label
		_assert(lbl != null, "Shield badge label exists")
		if lbl != null:
			var font_size = lbl.get_theme_font_size("font_size")
			_assert(font_size >= 18, "Shield font size is enlarged (font_size=%d >= 18)" % font_size)
			_assert(lbl.text.contains("Koruma"), "Shield label text has 'Koruma'")

	var aura: Panel = view._shield_aura
	_assert(aura != null, "Shield aura panel exists")
	if aura != null and badge != null:
		_assert(badge.position.y < aura.position.y, "Shield badge (y=%.1f) does not overlap inside aura (y=%.1f)" % [badge.position.y, aura.position.y])

	view.queue_free()

func _test_alliance_attack_restriction() -> void:
	print("\n[2] Testing Alliance Attack Restrictions...")
	var state := {
		"alliances": [
			{
				"id": 1,
				"name": "Aslanlar Birliği",
				"tag": "ASLAN",
				"members": [
					{"name": "Lord Gorkem", "role": "leader"},
					{"name": "Lord Edward", "role": "member"}
				]
			}
		],
		"villages": [
			{
				"id": 10,
				"name": "Köy 1",
				"owner": "Lord Gorkem",
				"x": 100,
				"y": 100,
				"units": {"axe": 100, "spy": 10},
				"buildings": {"barracks": 1}
			},
			{
				"id": 20,
				"name": "Köy 2",
				"owner": "Lord Edward",
				"x": 102,
				"y": 100,
				"units": {"spear": 50},
				"buildings": {"barracks": 1}
			},
			{
				"id": 30,
				"name": "Düşman Köy",
				"owner": "Lord Charles",
				"x": 105,
				"y": 100,
				"units": {"spear": 50},
				"buildings": {"barracks": 1}
			}
		]
	}

	var now := int(Time.get_unix_time_from_system())

	# 1. Attack on ally
	var res_ally_attack = MovementScript.can_send(state, 10, 20, MovementScript.TYPE_ATTACK, {"axe": 10}, {}, now)
	_assert(not bool(res_ally_attack.get("ok", true)), "Attack on alliance member is blocked")
	_assert(str(res_ally_attack.get("code", "")) == "friendly_target", "Attack error code is 'friendly_target'")

	# 2. Spy on ally
	var res_ally_spy = MovementScript.can_send(state, 10, 20, MovementScript.TYPE_SPY, {"spy": 5}, {}, now)
	_assert(not bool(res_ally_spy.get("ok", true)), "Spy on alliance member is blocked")
	_assert(str(res_ally_spy.get("code", "")) == "friendly_target", "Spy error code is 'friendly_target'")

	# 3. Attack on enemy
	var res_enemy_attack = MovementScript.can_send(state, 10, 30, MovementScript.TYPE_ATTACK, {"axe": 10}, {}, now)
	_assert(bool(res_enemy_attack.get("ok", false)), "Attack on enemy village is allowed")

func _test_village_renaming_and_header_format() -> void:
	print("\n[3] Testing Village Renaming & ResourceBar Format...")
	var gs = null
	for child in root.get_children():
		if "GameState" in child.name:
			gs = child
			break
	if gs == null:
		var GSClass = load("res://autoload/GameState.gd")
		gs = GSClass.new()
		gs.name = "GameState"
		root.add_child(gs)

	var v1 := {
		"id": 1,
		"name": "Başkent",
		"owner": "Lord Gorkem",
		"x": 100,
		"y": 100,
		"points": 110,
		"resources": {"wood": 100, "stone": 100, "iron": 100},
		"buildings": {"storage": 1, "farm": 1}
	}
	gs.player = {"id": 1, "name": "Lord Gorkem", "points": 110}
	gs.villages = [v1]
	gs.active_village_id = 1

	var rbar_scene: PackedScene = load("res://ui/ResourceBar.tscn")
	var rbar = rbar_scene.instantiate()
	root.add_child(rbar)
	rbar.refresh()

	var lbl: Label = rbar.find_child("VillageName", true, false) as Label
	_assert(lbl != null, "VillageName label found")
	if lbl != null:
		_assert(lbl.text.contains("Lord Gorkem | 🏰 Başkent"), "Header matches format 'Lord Gorkem | 🏰 Başkent' (actual: %s)" % lbl.text)
		_assert(lbl.mouse_filter == Control.MOUSE_FILTER_STOP, "VillageName has MOUSE_FILTER_STOP for clicking")

	# Test rename
	var rename_ok: bool = gs.rename_village(1, "Baskent Yeni")
	_assert(rename_ok, "rename_village executed successfully")
	rbar.refresh()

	if lbl != null:
		_assert(lbl.text.contains("Lord Gorkem | 🏰 Baskent Yeni"), "Header reflects renamed village (actual: %s)" % lbl.text)

	# Second village test
	var v2 := {
		"id": 2,
		"name": "İkinci Köy",
		"owner": "Lord Gorkem",
		"x": 105,
		"y": 102,
		"points": 110,
		"resources": {"wood": 100, "stone": 100, "iron": 100},
		"buildings": {"storage": 1, "farm": 1}
	}
	gs.add_village(v2)
	gs.set_active_village(2)
	rbar.refresh()

	if lbl != null:
		_assert(lbl.text.contains("Lord Gorkem | 🏰 İkinci Köy"), "Second village header matches 'Lord Gorkem | 🏰 İkinci Köy' (actual: %s)" % lbl.text)

	rbar.queue_free()

func _test_world_map_legend_and_categories() -> void:
	print("\n[4] Testing WorldMap Legend (3 Categories, No Soyguncular)...")
	var map_scene: PackedScene = load("res://scenes/WorldMap.tscn")
	var map = map_scene.instantiate()
	root.add_child(map)

	var legend = map.get_node_or_null("Legend/HBox")
	_assert(legend != null, "Legend HBox found in WorldMap")
	if legend != null:
		var own_lbl = legend.get_node_or_null("Own")
		var ally_lbl = legend.get_node_or_null("Ally")
		var enemy_lbl = legend.get_node_or_null("Enemy")
		var barb_lbl = legend.get_node_or_null("Barb")

		_assert(own_lbl != null, "Legend contains 'Own' (Kendi Köyün)")
		_assert(ally_lbl != null, "Legend contains 'Ally' (İttifak Üyelerin)")
		_assert(enemy_lbl != null, "Legend contains 'Enemy' (Düşman)")
		_assert(barb_lbl == null, "Legend does NOT contain 'Barb' (Soyguncular kaldırıldı)")

	map.queue_free()
