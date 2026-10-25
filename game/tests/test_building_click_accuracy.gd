extends SceneTree

func _init() -> void:
	print("========================================================")
	print("  BİNA TIKLAMA HASSASİYETİ VE POLİGON AYRIŞTIRMA TESTİ")
	print("========================================================")

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

	var bp = v_inst.find_child("BuildingPanel", true, false)
	assert(bp != null, "BuildingPanel bulunamadı!")

	var bv_garage = v_inst.find_child("BuildingView_garage", true, false)
	var bv_market = v_inst.find_child("BuildingView_market", true, false)

	assert(bv_garage != null, "BuildingView_garage bulunamadı!")
	assert(bv_market != null, "BuildingView_market bulunamadı!")

	print("Simyager pos: ", bv_garage.position, " size: ", bv_garage.size)
	print("Market pos: ", bv_market.position, " size: ", bv_market.size)

	# Test 1: Simyager Merkezine Tıklama
	var clicked = {"key": ""}
	bv_garage.clicked.connect(func(): clicked["key"] = "garage")
	bv_market.clicked.connect(func(): clicked["key"] = "market")

	var garage_center_local = bv_garage.size * 0.5
	var ev_press = InputEventMouseButton.new()
	ev_press.button_index = MOUSE_BUTTON_LEFT
	ev_press.pressed = true
	ev_press.position = garage_center_local
	ev_press.global_position = bv_garage.global_position + garage_center_local
	bv_garage._on_btn_gui_input(ev_press)

	var ev_release = InputEventMouseButton.new()
	ev_release.button_index = MOUSE_BUTTON_LEFT
	ev_release.pressed = false
	ev_release.position = garage_center_local
	ev_release.global_position = bv_garage.global_position + garage_center_local
	bv_garage._on_btn_gui_input(ev_release)

	assert(clicked["key"] == "garage", "Simyager tıklandığında Simyager açılmalı! Alınan: " + str(clicked["key"]))
	print("  [PASS] Simyager merkezine tıklandığında doğru şekilde Simyager seçildi.")

	# Test 2: Eski Çakışma Bölgesine Tıklama (Simyager'in sağ tarafı)
	# Global koordinat (620, 810) -> Simyager pos=(530, 716), Market pos=(602, 784)
	# Bu nokta Simyager için yerel (90, 94), Market için yerel (18, 26)
	var test_global_pos = Vector2(620, 810)
	var pt_in_garage = test_global_pos - bv_garage.position
	var pt_in_market = test_global_pos - bv_market.position

	var garage_has = bv_garage._has_point(pt_in_garage)
	var market_has = bv_market._has_point(pt_in_market)

	print("Nokta (620, 810) Simyager poligonunda mı? ", garage_has)
	print("Nokta (620, 810) Market poligonunda mı? ", market_has)

	assert(garage_has == true, "(620, 810) Simyager poligonunun içinde olmalıdır!")
	assert(market_has == false, "(620, 810) Market poligonunun DIŞINDA olmalıdır (çakışma sıfırlandı)!")
	print("  [PASS] Eski çakışma noktasında Market poligonu 'false' dönüyor, Simyager korundu!")

	# Test 3: Market Merkezine Tıklama
	clicked["key"] = ""
	var market_center_local = bv_market.size * 0.5
	var ev_m_press = InputEventMouseButton.new()
	ev_m_press.button_index = MOUSE_BUTTON_LEFT
	ev_m_press.pressed = true
	ev_m_press.position = market_center_local
	ev_m_press.global_position = bv_market.global_position + market_center_local
	bv_market._on_btn_gui_input(ev_m_press)

	var ev_m_release = InputEventMouseButton.new()
	ev_m_release.button_index = MOUSE_BUTTON_LEFT
	ev_m_release.pressed = false
	ev_m_release.position = market_center_local
	ev_m_release.global_position = bv_market.global_position + market_center_local
	bv_market._on_btn_gui_input(ev_m_release)

	assert(clicked["key"] == "market", "Market tıklandığında Market açılmalı! Alınan: " + str(clicked["key"]))
	print("  [PASS] Market merkezine tıklandığında doğru şekilde Market seçildi.")

	# Test 4: 15 Binanın Tamamının Varlığı ve Hitbox Poligon Kontrolü
	for b_key in v_inst.BUILDING_LAYOUT.keys():
		var bv = v_inst.find_child("BuildingView_" + b_key, true, false)
		assert(bv != null, "Bina düğümü mevcut: " + b_key)
		assert(bv.get_button() != null, "Bina butonu mevcut: " + b_key)
		assert(bv._has_point(bv.size * 0.5) == true, "Bina merkez noktası poligon içinde olmalı: " + b_key)

	print("  [PASS] 15 binanın tamamı kusursuz poligon hitbox'larına sahip.")
	print("========================================================")
	print("  TÜM BİNA TIKLAMA VE AYRIŞTIRMA TESTLERİ BAŞARILI!")
	print("========================================================")
	quit(0)
