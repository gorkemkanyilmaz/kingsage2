extends SceneTree
## test_region_and_map.gd — Harita Sıfırlama, 50 Bot, Yön Seçimi ve Oyuncu Köyü Doğrulama Testi.

func _initialize() -> void:
	print("==================================================")
	print("🧪 HARİTA, 50 BOT, GÜNEYDOĞU YÖN SEÇİMİ VE KÖY TESTİ")
	print("==================================================")

	var gs = root.get_node("GameState")
	var wm = root.get_node("WorldManager")
	var auth = root.get_node("AuthManager")

	auth.login_with_google("Lord Gorkem")

	# 1. Sıfırlama
	wm.reset_all_worlds()
	var w1_data = wm.load_world_dict(1)
	var vills: Array = w1_data["state"]["villages"]
	print("Dünya 1 başlangıç köy sayısı: %d" % vills.size())
	assert(vills.size() == 50, "Dünya 1 başlangıçta TAM 50 bot köyü içermelidir!")

	# 2. Lord Gorkem Güneydoğu bölgesini seçerek katılıyor (target: 165, 165)
	var target_x := 165
	var target_y := 165
	var join_ok = wm.join_world(1, "Lord Gorkem", target_x, target_y)
	assert(join_ok, "Lord Gorkem Dünya 1'e katılabilmeli!")

	# 3. Köy sayısı ve koordinat kontrolü
	w1_data = wm.load_world_dict(1)
	vills = w1_data["state"]["villages"]
	print("Dünya 1 katılım sonrası köy sayısı: %d" % vills.size())
	assert(vills.size() == 51, "Katılım sonrası tam 51 köy (50 bot + 1 Lord Gorkem) olmalı!")

	var p_vills = gs.get_player_villages()
	assert(p_vills.size() == 1, "Lord Gorkem'in tam 1 köyü olmalı!")
	var player_v: Dictionary = p_vills[0]
	print("Lord Gorkem köyü: ID %s, Adı: %s, Sahibi: %s, Koordinat: (%s|%s)" % [
		player_v.get("id"), player_v.get("name"), player_v.get("owner"), player_v.get("x"), player_v.get("y")
	])
	assert(player_v["owner"] == "Lord Gorkem", "Köy sahibi Lord Gorkem olmalı!")
	assert(int(player_v["id"]) == gs.active_village_id, "Aktif köy Lord Gorkem'in köyü olmalı!")
	var px := int(player_v.get("x", 0))
	var py := int(player_v.get("y", 0))
	assert(px >= 100 and py >= 100, "Köy Güneydoğu bölgesinde (x>=100, y>=100) olmalı! Bulunan: (%d|%d)" % [px, py])

	# 4. WorldMap sahnesi açıldığında köyün haritada varlığı ve odaklanması
	var map_scene = load("res://scenes/WorldMap.tscn").instantiate()
	root.add_child(map_scene)
	await process_frame

	print("WorldMap sahnesi başarıyla yüklendi!")
	var map_vills = gs.villages
	print("Haritadaki köy sayısı: %d" % map_vills.size())
	assert(map_vills.size() == 51, "Haritada da tam 51 köy (50 bot + 1 oyuncu) görünmeli!")

	var active_v = gs.get_active_village()
	assert(active_v["owner"] == "Lord Gorkem", "Haritada aktif seçili köy Lord Gorkem'e ait olmalı!")

	var sb_x = map_scene.get_node_or_null("Header/HBox/CoordX") as SpinBox
	var sb_y = map_scene.get_node_or_null("Header/HBox/CoordY") as SpinBox
	print("Harita başlangıç koordinat girdileri: X=%s, Y=%s" % [sb_x.value, sb_y.value])
	assert(int(sb_x.value) == px, "X koordinat girdisi oyuncunun köyüne odaklanmalı!")
	assert(int(sb_y.value) == py, "Y koordinat girdisi oyuncunun köyüne odaklanmalı!")

	# 5. Haritada oyuncu köyü MapVillageView nesnesinin setup doğrulaması
	assert(map_scene._village_views.has(int(player_v["id"])), "Haritada oyuncu köyü için MapVillageView üretilmiş olmalı!")
	var pv_view = map_scene._village_views[int(player_v["id"])]
	assert(pv_view.is_player == true, "Oyuncu köyü görselinde is_player = true olmalı!")

	map_scene.queue_free()
	print("==================================================")
	print("✅ TÜM KONTROLLER EKSİKSİZ VE MÜKEMMEL BAŞARIYLA GEÇTİ!")
	print("==================================================")
	quit(0)
