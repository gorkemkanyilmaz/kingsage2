extends SceneTree

func _init() -> void:
	print("--- Starting Building Click Diagnostic ---")

	# Autoloads
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

	# Setup an active village
	var vmodel = load("res://scripts/model/VillageModel.gd")
	var p_v = vmodel.create(1, "Başkent", 100, 100, "Kral", false)
	gs.villages = [p_v]
	gs.active_village_id = 1

	var v_scene = load("res://scenes/Village.tscn")
	var v_inst = v_scene.instantiate()
	root.add_child(v_inst)
	v_inst._ready()


	print("Village scene instantiated and added to root")

	var bp = v_inst.find_child("BuildingPanel", true, false)
	print("BuildingPanel initial visibility: ", bp.visible)

	print("Village children count: ", v_inst.get_child_count())
	for c in v_inst.get_children():
		print("  v_inst child: ", c.name)

	var va = v_inst.get_node_or_null("VillageArea")
	print("VillageArea: ", va)
	if va != null:
		for c in va.get_children():
			print("    va child: ", c.name, " children: ", c.get_child_count())
			for grandchild in c.get_children():
				print("      gc child: ", grandchild.name)


	var bv_main = v_inst.find_child("BuildingView_main", true, false)
	if bv_main == null:
		print("FAIL: BuildingView_main NOT FOUND!")
		quit(1)
		return

	print("Found BuildingView_main: ", bv_main)
	print("BuildingView_main size: ", bv_main.size, " pos: ", bv_main.position)

	var btn = bv_main.get_button()
	print("Found button inside BuildingView_main: ", btn)
	print("Button mouse_filter: ", btn.mouse_filter)
	print("Button size: ", btn.size)

	# Connect to bv_main clicked signal to see if it fires
	var clicked_fired := false
	bv_main.clicked.connect(func():
		print("SIGNAL: bv_main.clicked FIRED!")
		clicked_fired = true
	)

	# Simulate a mouse press & release on the button
	print("Simulating mouse press on button...")
	var ev_press = InputEventMouseButton.new()
	ev_press.button_index = MOUSE_BUTTON_LEFT
	ev_press.pressed = true
	ev_press.position = Vector2(50, 50)
	ev_press.global_position = Vector2(50, 50)
	btn._gui_input(ev_press)

	print("Simulating mouse release on button...")
	var ev_release = InputEventMouseButton.new()
	ev_release.button_index = MOUSE_BUTTON_LEFT
	ev_release.pressed = false
	ev_release.position = Vector2(50, 50)
	ev_release.global_position = Vector2(50, 50)
	btn._gui_input(ev_release)

	print("clicked_fired: ", clicked_fired)
	print("BuildingPanel visibility after click: ", bp.visible)

	quit(0)
