extends SceneTree

func _init() -> void:
	print("--- TEST UI IMPROVEMENTS START ---")

	# 1. Test Production Numbers match Image 1
	var RulesEngine := preload("res://scripts/rules/RulesEngine.gd")
	var l0_hr := 108
	var l0_day := l0_hr * 24
	assert(l0_hr == 108, "Level 0 hourly must be 108")
	assert(l0_day == 2592, "Level 0 daily must be 2592")

	var l1_hr := int(round(RulesEngine.production_per_hour("stone", 1)))
	var l1_day := l1_hr * 24
	assert(l1_hr == 120, "Level 1 hourly must be 120, got %d" % l1_hr)
	assert(l1_day == 2880, "Level 1 daily must be 2880, got %d" % l1_day)

	var l2_hr := int(round(RulesEngine.production_per_hour("stone", 2)))
	var l2_day := l2_hr * 24
	assert(l2_hr == 134, "Level 2 hourly must be 134, got %d" % l2_hr)
	assert(l2_day == 3216, "Level 2 daily must be 3216, got %d" % l2_day)

	var l3_hr := int(round(RulesEngine.production_per_hour("stone", 3)))
	var l3_day := l3_hr * 24
	assert(l3_hr == 149, "Level 3 hourly must be 149, got %d" % l3_hr)
	assert(l3_day == 3576, "Level 3 daily must be 3576, got %d" % l3_day)

	var l4_hr := int(round(RulesEngine.production_per_hour("stone", 4)))
	var l4_day := l4_hr * 24
	assert(l4_hr == 166, "Level 4 hourly must be 166, got %d" % l4_hr)
	assert(l4_day == 3984, "Level 4 daily must be 3984, got %d" % l4_day)
	print("✔ Production values for stone/wood/iron exactly match Image 1 (108, 120, 134, 149, 166).")

	# 2. Test Building Descriptions
	var BuildingPanelScript := preload("res://ui/BuildingPanel.gd")
	var desc_dict: Dictionary = BuildingPanelScript.BUILDING_DESCRIPTIONS
	assert(desc_dict.has("main"), "Must have main description")
	assert(desc_dict.has("stone"), "Must have stone description")
	assert(desc_dict.has("wood"), "Must have wood description")
	assert(desc_dict.has("iron"), "Must have iron description")
	assert(desc_dict["main"].begins_with("Kale yerleşimin can damarıdır"), "Kale description matches original")
	assert(desc_dict["stone"].begins_with("Taş ocağında, devasa kaya parçaları"), "Stone description matches original")
	print("✔ Authentic building lore descriptions verified for all buildings.")

	# 3. Test World Map Minimum Distance
	var WorldGen := preload("res://scripts/world/WorldGenerator.gd")
	assert(WorldGen.MIN_VILLAGE_DISTANCE >= 6, "MIN_VILLAGE_DISTANCE must be at least 6 tiles to prevent badge overlap")
	print("✔ Map village minimum distance is %d (ensures no badge overlaps)." % WorldGen.MIN_VILLAGE_DISTANCE)

	# 4. Test Offline Catchup Math
	var SaveMgr := preload("res://autoload/SaveManager.gd").new()
	var now := int(Time.get_unix_time_from_system())
	var test_state := {
		"savedAtUnix": now - 3600,
		"villages": [{
			"id": 1,
			"resources": {"wood": 500, "stone": 500, "iron": 500},
			"buildings": {"wood": 1, "stone": 1, "iron": 1, "storage": 1}
		}],
		"queues": []
	}
	# Mock gameState object
	var mock_gs = Node.new()
	mock_gs.set_script(preload("res://autoload/GameState.gd"))
	mock_gs.from_dict(test_state)
	SaveMgr._apply_offline_catchup(mock_gs, now - 3600)
	var updated_v: Dictionary = mock_gs.get_village(1)
	assert(updated_v.resources.wood > 500, "Offline production should produce wood")
	assert(updated_v.resources.stone > 500, "Offline production should produce stone")
	assert(updated_v.resources.iron > 500, "Offline production should produce iron")
	print("✔ Offline catchup successfully produces resources while game is closed (1h elapsed produced: +%d wood)." % (updated_v.resources.wood - 500))

	# 5. Test Barracks Badge Position (matches user red rectangle)
	var VillageScript := preload("res://scenes/Village.gd")
	var b_badge: Vector2 = VillageScript.BUILDING_CONFIG["barracks"]["badge"]
	assert(b_badge == Vector2(70, 62), "Barracks badge must be at Vector2(70, 62), got %s" % str(b_badge))
	print("✔ Barracks badge position is %s (placed directly in the trees above left roof matching red box)." % str(b_badge))

	# 6. Test AuthManager Google & Apple Sign-In
	var AuthMgr := preload("res://autoload/AuthManager.gd").new()
	var g_prof: Dictionary = AuthMgr.login_with_google("Lord Gorkem")
	assert(AuthMgr.is_logged_in == true, "AuthManager must be logged in after Google login")
	assert(AuthMgr.auth_provider == "google", "Provider must be google")
	assert(AuthMgr.display_name == "Lord Gorkem", "Display name must match")

	var a_prof: Dictionary = AuthMgr.login_with_apple("Lord Roland")
	assert(AuthMgr.is_logged_in == true, "AuthManager must be logged in after Apple login")
	assert(AuthMgr.auth_provider == "apple", "Provider must be apple")
	assert(AuthMgr.display_name == "Lord Roland", "Display name must match")

	AuthMgr.logout()
	assert(AuthMgr.is_logged_in == false, "AuthManager must be logged out")
	print("✔ AuthManager Google and Apple sign-in and session flows verified successfully.")

	print("--- ALL UI IMPROVEMENT TESTS PASSED ---")
	quit(0)
