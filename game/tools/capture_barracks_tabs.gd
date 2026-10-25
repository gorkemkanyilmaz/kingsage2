extends SceneTree

const OUT_DIR := "c:/Users/Gorkem/Desktop/kingsage2/screenshots/"

func _initialize() -> void:
	print("=== Capturing Barracks Multi-Tab Screenshots ===")
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	var data_mgr = load("res://autoload/GameData.gd").get_singleton()
	data_mgr.load_all(true)

	if root.get_node_or_null("EventBus") == null:
		var eb = Node.new(); eb.set_script(load("res://autoload/EventBus.gd")); eb.name = "EventBus"; root.add_child(eb)
	if root.get_node_or_null("GameState") == null:
		var gs = Node.new(); gs.set_script(load("res://autoload/GameState.gd")); gs.name = "GameState"; root.add_child(gs)

	var vmodel = load("res://scripts/model/VillageModel.gd")
	var pv: Dictionary = vmodel.create(999, "Başkent", 100, 100, "Kral", false)
	pv["is_bot"] = false
	pv["buildings"]["barracks"] = 5
	pv["buildings"]["farm"] = 15
	pv["buildings"]["storage"] = 15
	pv["resources"] = {"wood": 25000, "stone": 20000, "iron": 18000}
	pv["researched"] = {"spear": true, "sword": true, "farmer": true}
	pv["units"] = {"spear": 30, "sword": 15, "farmer": 50}

	var gs_node = root.get_node("GameState")
	gs_node.world = {"villages": [pv], "tiles": {}}
	gs_node.villages = [pv]
	gs_node.player = {"id": 1, "name": "Kral", "points": 500}
	gs_node.active_village_id = 999
	gs_node.queues = []

	change_scene_to_file("res://scenes/Village.tscn")
	for i in range(16):
		await process_frame

	var vil = current_scene
	var bp = vil.get_node_or_null("BuildingPanel")

	if bp != null:
		# 1. Kışla - Tab 1: Bina Yükselt
		bp.show_building(pv, "barracks")
		bp._on_tab_upgrade_pressed()
		for i in range(12):
			await process_frame
		_save_now("barracks_tab1_upgrade.png")

		# 2. Kışla - Tab 2: Birim Araştır
		bp._on_tab_research_pressed()
		for i in range(12):
			await process_frame
		_save_now("barracks_tab2_research.png")

		# 3. Kışla - Tab 3: Birim Eğit
		bp._on_tab_train_pressed()
		for i in range(12):
			await process_frame
		_save_now("barracks_tab3_train.png")

	print("TAMAMLANDI!")
	quit(0)


func _save_now(file_name: String) -> void:
	var img: Image = root.get_texture().get_image()
	if img == null:
		print("HATA: görüntü alınamadı -> ", file_name)
		return
	var err := img.save_png(OUT_DIR + file_name)
	print("%s kaydedildi (err=%s, %s)" % [file_name, err, img.get_size()])
