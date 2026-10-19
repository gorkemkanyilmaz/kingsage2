extends SceneTree
## Tüm ana ekranların ekran görüntüsünü alır (görsel denetim için).
## Kullanım: Godot_v4.7.2-stable_win64_console.exe --path .\game --script res://tools/capture_screens.gd

const OUT_DIR := "c:/Users/Gorkem/Desktop/kingsage2/screenshots/"

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	var data_mgr = load("res://autoload/GameData.gd").get_singleton()
	data_mgr.load_all(true)

	if root.get_node_or_null("EventBus") == null:
		var eb = Node.new(); eb.set_script(load("res://autoload/EventBus.gd")); eb.name = "EventBus"; root.add_child(eb)
	if root.get_node_or_null("GameState") == null:
		var gs = Node.new(); gs.set_script(load("res://autoload/GameState.gd")); gs.name = "GameState"; root.add_child(gs)

	# Dünya + oyuncu köyü kur
	var world = load("res://scripts/world/WorldGenerator.gd").generate(4242, 100)
	var vmodel = load("res://scripts/model/VillageModel.gd")
	var pv: Dictionary = vmodel.create(999, "Başkent", 100, 100, "Kral", false)
	pv["is_bot"] = false
	world["villages"].append(pv)
	world["tiles"][load("res://scripts/world/WorldGenerator.gd").tile_key(100, 100)] = 999

	var gs_node = root.get_node("GameState")
	gs_node.world = world
	gs_node.villages = world["villages"].duplicate(true)
	gs_node.player = {"id": 1, "name": "Kral", "points": int(pv.get("points", 110))}
	gs_node.active_village_id = 999

	await _shot("res://scenes/MainMenu.tscn", "01_main_menu.png")
	await _shot("res://scenes/VillageSelect.tscn", "02_village_select.png")
	await _shot("res://scenes/Village.tscn", "03_village.png")
	await _shot("res://scenes/WorldMap.tscn", "04_world_map.png")

	# Farklı bir bölgeye kaydırılmış harita (cetvel/vinyet denetimi)
	var wm = current_scene
	if wm != null:
		var sc = wm.get_node_or_null("MapContainer/Scroll")
		if sc != null:
			sc.scroll_horizontal = 24 * 96
			sc.scroll_vertical = 150 * 96
			for i in range(8):
				await process_frame
			_save_now("04b_world_map_bolge.png")

	await _shot("res://scenes/Reports.tscn", "05_reports.png")
	await _shot("res://scenes/Ranking.tscn", "06_ranking.png")
	await _shot("res://scenes/Settings.tscn", "07_settings.png")

	print("TÜM EKRAN GÖRÜNTÜLERİ ALINDI -> ", OUT_DIR)
	quit(0)


func _shot(scene_path: String, file_name: String) -> void:
	change_scene_to_file(scene_path)
	for i in range(12):
		await process_frame
	_save_now(file_name)


func _save_now(file_name: String) -> void:
	var img: Image = root.get_texture().get_image()
	if img == null:
		print("HATA: görüntü alınamadı -> ", file_name)
		return
	var err := img.save_png(OUT_DIR + file_name)
	print("%s (err=%s, %s)" % [file_name, err, img.get_size()])
