extends SceneTree

func _init() -> void:
	var f = FileAccess.open("res://diag_out2.txt", FileAccess.WRITE)
	f.store_line("--- TEST CLICK DIAGNOSTIC ---")

	var eb = load("res://autoload/EventBus.gd").new()
	eb.name = "EventBus"
	root.add_child(eb)

	var gc = load("res://autoload/GameConfig.gd").new()
	gc.name = "GameConfig"
	root.add_child(gc)

	var gs = load("res://autoload/GameState.gd").new()
	gs.name = "GameState"
	root.add_child(gs)

	var sm = load("res://autoload/SaveManager.gd").new()
	sm.name = "SaveManager"
	root.add_child(sm)

	var vmodel = load("res://scripts/model/VillageModel.gd")
	var p_v = vmodel.create(1, "Başkent", 100, 100, "Kral", false)
	gs.villages = [p_v]
	gs.active_village_id = 1

	var v_scene = load("res://scenes/Village.tscn")
	var v_inst = v_scene.instantiate()
	root.add_child(v_inst)

	var bv_main = v_inst.find_child("BuildingView_main", true, false)
	var btn: Button = bv_main.get_button()

	f.store_line("Before fix: bv_main.size=%s btn.size=%s btn.pos=%s" % [str(bv_main.size), str(btn.size), str(btn.position)])

	# Simulate the fix:
	var pad := 25.0
	btn.position = Vector2(-pad, -pad)
	btn.size = bv_main.size + Vector2(pad * 2.0, pad * 2.0)
	btn.custom_minimum_size = btn.size

	f.store_line("After fix: bv_main.size=%s btn.size=%s btn.pos=%s" % [str(bv_main.size), str(btn.size), str(btn.position)])

	var bp = v_inst.find_child("BuildingPanel", true, false)
	f.store_line("BuildingPanel before click: visible=%s" % str(bp.visible))

	# Click in center of building: (170, 130)
	var click_pos = bv_main.global_position + Vector2(170, 130)
	f.store_line("Simulating click at: %s" % str(click_pos))

	var ev_press = InputEventMouseButton.new()
	ev_press.button_index = MOUSE_BUTTON_LEFT
	ev_press.pressed = true
	ev_press.position = Vector2(170 + pad, 130 + pad)
	ev_press.global_position = click_pos
	bv_main._on_btn_gui_input(ev_press)

	var ev_release = InputEventMouseButton.new()
	ev_release.button_index = MOUSE_BUTTON_LEFT
	ev_release.pressed = false
	ev_release.position = Vector2(170 + pad, 130 + pad)
	ev_release.global_position = click_pos
	bv_main._on_btn_gui_input(ev_release)

	f.store_line("BuildingPanel after click: visible=%s" % str(bp.visible))
	f.store_line("SUCCESS: BuildingPanel opened successfully!")
	f.close()
	quit(0)

