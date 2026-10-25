extends SceneTree

func _init() -> void:
	print("=== Live Screenshot Capture with BuildingPanel Open ===")
	var data_mgr = load("res://autoload/GameData.gd").get_singleton()
	data_mgr.load_all(true)

	if root.get_node_or_null("EventBus") == null:
		var eb = Node.new()
		eb.set_script(load("res://autoload/EventBus.gd"))
		eb.name = "EventBus"
		root.add_child(eb)

	if root.get_node_or_null("GameState") == null:
		var gs = Node.new()
		gs.set_script(load("res://autoload/GameState.gd"))
		gs.name = "GameState"
		root.add_child(gs)

	var v = {
		"id": 1,
		"name": "Başkent",
		"x": 100,
		"y": 100,
		"points": 110,
		"resources": {"wood": 1000, "stone": 1000, "iron": 1000},
		"buildings": {"wood": 1, "stone": 1, "iron": 1, "storage": 1, "farm": 1, "main": 1}
	}
	var gs_node = root.get_node("GameState")
	gs_node.from_dict({
		"player": {"name": "TestOyuncu"},
		"active_village_id": 1,
		"villages": [v],
		"queues": [],
		"world": {"sim_now_unix": 1000000}
	})

	change_scene_to_file("res://scenes/Village.tscn")

	# Wait for scene tree to initialize and run _ready()
	for i in range(5):
		await process_frame

	var vil = current_scene
	var bpanel = vil.get_node("BuildingPanel")
	bpanel.hide()

	for i in range(15):
		await process_frame

	# 1. Village screen with animations and ResourceBar (Puan: 110, Depo: 1000)
	var img1 = root.get_texture().get_image()
	if img1 != null:
		img1.save_png("c:/Users/Gorkem/Desktop/kingsage2/screenshot_village_animated.png")
		print("Saved screenshot_village_animated.png")

	# 2. BuildingPanel for 'wood' (Seviye 1, Hedef 2)
	bpanel.show_building(v, "wood")
	bpanel.show()
	for i in range(5):
		await process_frame

	var img2 = root.get_texture().get_image()
	if img2 != null:
		img2.save_png("c:/Users/Gorkem/Desktop/kingsage2/screenshot_ui_revised.png")
		print("Saved screenshot_ui_revised.png")

	# 3. BuildingPanel for 'snob' (Önkoşul zinciri: 'Önce şunlar gerekli', 'Binaya Git ➔')
	bpanel.show_building(v, "snob")
	bpanel.show()
	for i in range(5):
		await process_frame

	var img3 = root.get_texture().get_image()
	if img3 != null:
		img3.save_png("c:/Users/Gorkem/Desktop/kingsage2/screenshot_building_panel_reqs.png")
		print("Saved screenshot_building_panel_reqs.png")

	quit(0)
