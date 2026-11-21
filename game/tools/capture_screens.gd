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

	# Farklı kale seviyelerindeki köyleri (3 seviye görseli) test etmek için komşu köylere seviye atayalım
	for v in world["villages"]:
		var vx: int = int(v.get("x", 0))
		var vy: int = int(v.get("y", 0))
		if vx == 106 and vy == 106:
			v["buildings"]["main"] = 8 # Seviye 5-10 -> orta-gelismis.png
		elif vx == 94 and vy == 93:
			v["buildings"]["main"] = 14 # Seviye >10 -> gelismis.png

	var gs_node = root.get_node("GameState")
	gs_node.world = world
	gs_node.villages = world["villages"].duplicate(true)
	gs_node.player = {"id": 1, "name": "Kral", "points": int(pv.get("points", 110)), "diamonds": 35, "tutorial_completed": true, "tutorial_skipped": false}
	gs_node.active_village_id = 999
	var wm_auto = root.get_node_or_null("WorldManager")
	if wm_auto != null:
		wm_auto.set("suppress_auto_conquered_prompt", true)
		wm_auto.set("current_world_id", 1)

	# Rapor kartlarını denetlemek için örnek kayıtlar (gerçek oyun formatında)
	var now := int(Time.get_unix_time_from_system())
	gs_node.reports = [
		{"type": "battle", "village_id": 999, "unix": now - 600, "unread": true, "data": {"from_village_id": 999, "target_village_id": 2, "attacker_name": "Kral", "target_name": "Erkonak", "attacker_won": true}},
		{"type": "spy", "village_id": 999, "unix": now - 5400, "unread": false, "data": {"from_village_id": 999, "target_village_id": 3, "attacker_name": "Kral", "target_name": "Kuzeykamp", "sonuc": "basarili"}},
		{"type": "trade", "village_id": 999, "unix": now - 9000, "unread": false, "data": {"from_village_id": 999, "target_village_id": 4, "resources": {"wood": 250, "stone": 100}}},
	]
	gs_node.messages = [
		{"id": 1, "from": "Baron Roland", "to": "Kral", "subject": "Saldırmazlık Paktı", "body": "Sayın Kral, sınır komşuluğumuz adına barış öneririm.", "created_unix": now - 1200, "read": false}
	]

	# Aktif inşaat örneği (İnşaat sürüyor: Seviye 2 Kalan: 01:20 görsel denetimi)
	gs_node.queues = [
		{
			"id": 1,
			"village_id": 999,
			"type": "build",
			"key": "wood",
			"target_level": 2,
			"start_unix": now - 60,
			"finish_unix": now + 80
		}
	]

	await _shot("res://scenes/MainMenu.tscn", "01_main_menu.png")
	await _shot("res://scenes/VillageSelect.tscn", "02_village_select.png")
	await _shot("res://scenes/Village.tscn", "03_village.png")

	# Bina paneli görüntüleri (Oduncu yükseltme & Köşk önkoşul zinciri)
	var vil = current_scene
	if vil != null:
		var bp = vil.get_node_or_null("BuildingPanel")
		if bp != null:
			bp.show_building(pv, "wood")
			bp.show()
			for i in range(8):
				await process_frame
			_save_now("03b_building_panel_wood.png")

			bp.show_building(pv, "snob")
			bp.show()
			for i in range(8):
				await process_frame
			_save_now("03c_building_panel_reqs.png")

			bp.show_building(pv, "barracks")
			bp.show()
			for i in range(8):
				await process_frame
			_save_now("03d_building_panel_barracks.png")

			bp.call("switch_tab", 2)
			for i in range(6):
				await process_frame
			var le_s: LineEdit = bp.find_child("QtyEdit_spear", true, false) as LineEdit
			if le_s != null:
				le_s.grab_focus()
				le_s.text = "100"
				le_s.text_changed.emit("100")
			for i in range(8):
				await process_frame
			_save_now("03e_barracks_train_keyboard.png")
			bp.hide()

	# Canlı birlik ve katır hareketlerini haritada görselleştirmek için hareketler ekleyelim
	var near_v1: Dictionary = {}
	var near_v2: Dictionary = {}
	for v in world["villages"]:
		var vx: int = int(v.get("x", 0))
		var vy: int = int(v.get("y", 0))
		if vx == 94 and vy == 93:
			near_v1 = v
		elif vx == 106 and vy == 106:
			near_v2 = v
	if near_v1.is_empty() and world["villages"].size() > 1:
		near_v1 = world["villages"][1]
	if near_v2.is_empty() and world["villages"].size() > 2:
		near_v2 = world["villages"][2]

	var v1_id: int = int(near_v1.get("id", 1))
	var v2_id: int = int(near_v2.get("id", 2))

	gs_node.movements = [
		{
			"id": 1,
			"village_id": 999,
			"from_village_id": 999,
			"to_village_id": v1_id,
			"type": "attack",
			"state": "outgoing",
			"owner": "Kral",
			"units": {"bow": 50, "spear": 30},
			"carry": {"wood": 0, "stone": 0, "iron": 0},
			"depart_unix": now - 35,
			"arrive_unix": now + 115,
		},
		{
			"id": 2,
			"village_id": 999,
			"from_village_id": v2_id,
			"to_village_id": 999,
			"type": "return",
			"state": "returning",
			"owner": "Kral",
			"units": {"light": 20},
			"carry": {"wood": 300, "stone": 150, "iron": 80},
			"depart_unix": now - 45,
			"arrive_unix": now + 75,
		},
		{
			"id": 3,
			"village_id": 999,
			"from_village_id": 999,
			"to_village_id": v2_id,
			"type": "trade",
			"state": "outgoing",
			"owner": "Kral",
			"units": {},
			"carry": {"wood": 500, "stone": 350, "iron": 200},
			"depart_unix": now - 20,
			"arrive_unix": now + 140,
		}
	]

	await _shot("res://scenes/WorldMap.tscn", "04_world_map.png")

	# Sefer ve Sevkiyat panelinin açık halini de yakalayalım
	var wm_node = current_scene
	if wm_node != null:
		var stp = wm_node.get_node_or_null("SendTroopsPanel")
		if stp != null and not near_v1.is_empty():
			stp.show_target(pv, near_v1)
			for i in range(8):
				await process_frame
			_save_now("04c_send_troops_panel.png")

			stp._switch_tab("trade")
			for i in range(8):
				await process_frame
			stp.hide()

		if wm_node != null and gs_node.movements.size() > 0:
			wm_node._open_movement_details(gs_node.movements[0])
			for i in range(8):
				await process_frame
			_save_now("04e_movement_detail_panel.png")
			if wm_node.movement_detail_panel != null:
				wm_node.movement_detail_panel.hide()

	# Farklı bir bölgeye kaydırılmış harita (göl ve kenar denetimi)
	var wm = current_scene
	if wm != null:
		var sc = wm.get_node_or_null("MapContainer/Scroll")
		if sc != null:
			sc.scroll_horizontal = 24 * 96
			sc.scroll_vertical = 150 * 96
			for i in range(8):
				await process_frame
			_save_now("04b_world_map_bolge.png")

	var rep_sc = load("res://scenes/Reports.gd")
	if rep_sc != null:
		rep_sc.initial_tab = "reports"
	await _shot("res://scenes/Reports.tscn", "05_reports.png")
	if rep_sc != null:
		rep_sc.initial_tab = "messages"
	await _shot("res://scenes/Reports.tscn", "05b_messages.png")
	await _shot("res://scenes/Ranking.tscn", "06_ranking.png")
	await _shot("res://scenes/Settings.tscn", "07_settings.png")

	var mkt_modal = load("res://ui/MarketModal.gd").new()
	root.add_child(mkt_modal)
	mkt_modal.open_tab("build")
	for i in range(8):
		await process_frame
	_save_now("08_market_modal.png")
	mkt_modal.queue_free()

	var spd_modal = load("res://ui/SpeedupModal.gd").new()
	root.add_child(spd_modal)
	spd_modal.configure("build", 1, "Oduncu Kampı (Sv. 2)")
	for i in range(8):
		await process_frame
	_save_now("09_speedup_modal.png")
	spd_modal.queue_free()

	# Profil açılır menüsü açıkken (PopupMenu teması denetimi)
	var st = current_scene
	if st != null:
		var opt = st.get_node_or_null("Center/VBox/ProfileRow/Option")
		if opt != null:
			opt.get_popup().popup(Rect2i(Vector2i(140, 820), Vector2i(760, 320)))
			for i in range(8):
				await process_frame
			var pp = opt.get_popup()
			print("POPUP embedded=", pp.is_embedded(), " font=", pp.get_theme_font_size("font_size"), " panel=", pp.get_theme_stylebox("panel"))
			_save_now("07b_settings_profil.png")

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
