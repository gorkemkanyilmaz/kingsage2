extends SceneTree

func _init() -> void:
	print("--- TEST BUILDING CLICK FIX START ---")

	var eb = root.get_node_or_null("EventBus")
	if eb == null:
		eb = load("res://autoload/EventBus.gd").new()
		eb.name = "EventBus"
		root.add_child(eb)

	var gc = root.get_node_or_null("GameConfig")
	if gc == null:
		gc = load("res://autoload/GameConfig.gd").new()
		gc.name = "GameConfig"
		root.add_child(gc)

	var gd = root.get_node_or_null("GameData")
	if gd == null:
		gd = load("res://autoload/GameData.gd").new()
		gd.name = "GameData"
		root.add_child(gd)

	var gs = root.get_node_or_null("GameState")
	if gs == null:
		gs = load("res://autoload/GameState.gd").new()
		gs.name = "GameState"
		root.add_child(gs)

	var sm = root.get_node_or_null("SaveManager")
	if sm == null:
		sm = load("res://autoload/SaveManager.gd").new()
		sm.name = "SaveManager"
		root.add_child(sm)

	var vmodel = load("res://scripts/model/VillageModel.gd")
	var p_v = vmodel.create(1, "Başkent", 100, 100, "Kral", false)
	gs.villages = [p_v]
	gs.active_village_id = 1

	var v_scene = load("res://scenes/Village.tscn")
	var v_inst = v_scene.instantiate()
	root.add_child(v_inst)
	v_inst._ready()

	var bp = v_inst.find_child("BuildingPanel", true, false)
	assert(bp != null, "BuildingPanel must exist in Village scene")
	assert(bp.visible == false, "BuildingPanel should initially be hidden")

	# Test every building
	var test_keys = ["main", "stone", "wood", "iron", "farm", "storage", "barracks", "stable"]
	for b_key in test_keys:
		var node_name = "BuildingView_" + b_key
		var bv = v_inst.find_child(node_name, true, false)
		assert(bv != null, "Node %s must exist in Village view" % node_name)

		var btn: Button = bv.get_button()
		assert(btn != null, "Button in %s must exist" % node_name)

		var expected_w = bv.size.x
		var expected_h = bv.size.y
		assert(abs(btn.size.x - expected_w) < 1.0, "Button width for %s must be %.1f, got %.1f" % [b_key, expected_w, btn.size.x])
		assert(abs(btn.size.y - expected_h) < 1.0, "Button height for %s must be %.1f, got %.1f" % [b_key, expected_h, btn.size.y])
		assert(btn.position == Vector2.ZERO, "Button position for %s must be (0, 0)" % b_key)

		# Hide panel before testing click
		bp.hide()

		# Simulate click on center of building
		var center_pos = bv.global_position + (bv.size * 0.5)
		var ev_press = InputEventMouseButton.new()
		ev_press.button_index = MOUSE_BUTTON_LEFT
		ev_press.pressed = true
		ev_press.position = bv.size * 0.5
		ev_press.global_position = center_pos
		bv._on_btn_gui_input(ev_press)

		var ev_release = InputEventMouseButton.new()
		ev_release.button_index = MOUSE_BUTTON_LEFT
		ev_release.pressed = false
		ev_release.position = ev_press.position
		ev_release.global_position = center_pos
		bv._on_btn_gui_input(ev_release)

		assert(bp.visible == true, "BuildingPanel must be visible after clicking center of %s!" % b_key)
		assert(bp._current_key == b_key, "BuildingPanel._current_key must be %s, got %s" % [b_key, bp._current_key])
		print("✔ Building %s: size %s -> button %s, center click opens panel successfully." % [b_key, bv.size, btn.size])

	print("--- ALL BUILDING CLICK TESTS PASSED ---")
	quit(0)
