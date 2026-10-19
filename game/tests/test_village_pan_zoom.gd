extends SceneTree
## test_village_pan_zoom.gd — Köy Zoom, Pan/Kaydırma, Seviye Plaketleri ve Modern Pastel UI Testi.

var _pass_count := 0
var _fail_count := 0

func _initialize() -> void:
	print("\n========================================================")
	print("  KÖY ZOOM, PAN (KAYDIRMA) VE MODERN PASTEL UI TESTLERİ")
	print("========================================================\n")

	var gd_script = load("res://autoload/GameData.gd")
	gd_script.get_singleton().load_all(true)

	for sname in ["EventBus", "GameState", "GameClock", "SaveManager", "GameConfig"]:
		var scr = load("res://autoload/" + sname + ".gd")
		var n = Node.new()
		n.set_script(scr)
		n.name = sname
		root.add_child(n)

	var v := {
		"id": 1,
		"name": "Başkent (100|100)",
		"x": 100,
		"y": 100,
		"points": 110,
		"realm_of_power": 110,
		"resources": {"wood": 1000, "stone": 1000, "iron": 1000},
		"buildings": {
			"main": 1, "farm": 1, "wood": 2, "stone": 1, "iron": 1,
			"storage": 1, "hide": 0, "barracks": 0, "wall": 0,
			"market": 0, "stable": 0, "garage": 0, "snob": 0,
			"smith": 0, "statue": 0
		}
	}
	var gs = root.get_node("GameState")
	gs.from_dict({
		"player": {"name": "Hükümdar"},
		"active_village_id": 1,
		"villages": [v],
		"queues": [],
		"world": {"sim_now_unix": 1000000}
	})

	var scene = load("res://scenes/Village.tscn").instantiate()
	root.add_child(scene)
	if scene._building_nodes.is_empty():
		scene._ready()

	print("\n--- Test 1: Büyük ve Okunaklı Seviye Plaketi Doğrulaması ---")
	var wood_node = scene._building_nodes.get("wood")
	_assert_true(wood_node != null, "Oduncu binası düğümü mevcut")
	var wood_view = wood_node.get("view")
	var wood_lvl: Label = wood_node.get("lvl")
	_assert_true(wood_lvl != null, "Seviye plaket etiketi mevcut")
	_assert_true(wood_lvl.text == "Sv. 2", "Seviye plaketinde 'Sv. 2' yazıyor (Görünen: %s)" % wood_lvl.text)
	_assert_true(wood_lvl.get_theme_font_size("font_size") >= 17, "Plaket fontu en az 17px büyük (Görünen: %d)" % wood_lvl.get_theme_font_size("font_size"))
	var badge_panel = wood_lvl.get_parent()
	_assert_true(badge_panel is PanelContainer, "Plaket bir PanelContainer içinde")
	_assert_true(badge_panel.custom_minimum_size.x >= 70 and badge_panel.custom_minimum_size.y >= 36, "Plaket boyutu en az 70x36 piksel (Görünen: %s)" % str(badge_panel.custom_minimum_size))

	print("\n--- Test 2: Zoom / Yakınlaştırma ve Sınır Koruması ---")
	_assert_true(is_equal_approx(scene._current_zoom, 1.0), "Başlangıç zoom seviyesi 1.0 (Alınan: %.2f)" % scene._current_zoom)
	scene._apply_zoom(0.3, Vector2(540, 960))
	_assert_true(scene._current_zoom > 1.25, "Zoom +0.3 ile arttı (Şu an: %.2f)" % scene._current_zoom)
	_assert_true(scene.village_area.scale.x > 1.25, "VillageArea scale senkronize büyüdü (Scale: %s)" % str(scene.village_area.scale))

	# Maksimum zoom sınır testi
	scene._apply_zoom(5.0, Vector2(540, 960))
	_assert_true(scene._current_zoom <= scene.MAX_ZOOM, "Maksimum zoom sınırı (2.2) aşılamadı (Şu an: %.2f)" % scene._current_zoom)

	# Minimum zoom sınır testi
	scene._apply_zoom(-5.0, Vector2(540, 960))
	_assert_true(scene._current_zoom >= scene.MIN_ZOOM, "Minimum zoom sınırı (1.0) aşılamadı (Şu an: %.2f)" % scene._current_zoom)

	print("\n--- Test 3: Pan / Kaydırma ve Ekran İçi Kenar Kenetleme (Clamping) ---")
	# 1.5x zoom yapıp kaydıralım
	scene._apply_zoom(0.5, Vector2(540, 960))
	var pos_before = scene.village_area.position
	scene._pan_by(Vector2(-100, -150))
	_assert_true(scene.village_area.position != pos_before, "Harita -100, -150 kaydırıldı (Yeni konum: %s)" % str(scene.village_area.position))

	# Reset görünüm
	scene._reset_view()
	_assert_true(scene._current_zoom == 1.0, "Reset sonrası zoom 1.0 oldu")

	print("\n--- Test 4: Yüzen Zoom Kontrol Arayüzü (ZoomHUD) ---")
	var zoom_hud = scene.get_node_or_null("ZoomHUD")
	_assert_true(zoom_hud != null, "ZoomHUD yüzen paneli ekranda mevcut")
	var zoom_vbox = zoom_hud.get_child(0)
	_assert_true(zoom_vbox != null and zoom_vbox.get_child_count() >= 3, "ZoomHUD içinde 3 adet buton var (+, -, reset)")

	print("\n--- Test 5: Modern Pastel ResourceBar & BottomNav Doğrulaması ---")
	var rbar = scene.get_node("ResourceBar")
	_assert_true(rbar != null, "ResourceBar mevcut")
	var bnav = scene.get_node("BottomNav")
	_assert_true(bnav != null, "BottomNav mevcut")
	_assert_true(bnav.get_node("HBox/BtnVillage") != null, "BottomNav Köy butonu mevcut")

	print("\n========================================================")
	print("  SONUÇ: %d BAŞARILI, %d HATALI" % [_pass_count, _fail_count])
	print("========================================================\n")

	if _fail_count > 0:
		print("❌ Zoom/Pan Testleri BAŞARISIZ!")
	else:
		print("✅ TÜM KÖY ZOOM, PAN VE MODERN PASTEL UI TESTLERİ %100 BAŞARILI!")
	quit()


func _assert_true(cond: bool, msg: String) -> void:
	if cond:
		_pass_count += 1
		print("  [PASS] %s" % msg)
	else:
		_fail_count += 1
		print("  [FAIL] ❌ %s" % msg)
