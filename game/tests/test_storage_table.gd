extends SceneTree

func _init() -> void:
	print("--- Depo Bilgi Tablosu Test Ediliyor ---")
	var GameDataScript = load("res://autoload/GameData.gd")
	GameDataScript.get_singleton().load_all(true)

	var panel_scene = load("res://ui/BuildingPanel.tscn")
	assert(panel_scene != null, "BuildingPanel sahnesi yüklenemedi")

	var panel = panel_scene.instantiate()
	root.add_child(panel)

	var gs = root.get_node_or_null("GameState")
	var mock_village_lvl1 = {
		"id": 1,
		"owner": "Kral",
		"buildings": {
			"storage": 1
		},
		"resources": {
			"wood": 500,
			"stone": 500,
			"iron": 500
		}
	}
	if gs != null:
		gs.villages.clear()
		gs.active_village_id = -1
		gs.add_village(mock_village_lvl1)

	panel.show_building(mock_village_lvl1, "storage")

	assert(panel._prod_box != null, "_prod_box oluşturulmalı")
	assert(panel._prod_box.visible == true, "Depo açıkken _prod_box görünür olmalı")
	assert(panel._prod_vbox != null, "_prod_vbox mevcut olmalı")

	var children = panel._prod_vbox.get_children()
	print("Depo Tablosu (Seviye 1) Satır Sayısı: ", children.size())
	assert(children.size() == 6, "1 Başlık + 1 Güncel + 4 Sonraki Seviye = 6 satır olmalı")

	# Başlık satırı
	var header = children[0]
	var h_labels = []
	for c in header.find_children("*", "Label", true, false):
		h_labels.append(c.text)
	print("Başlık Etiketleri: ", h_labels)
	assert(h_labels.size() > 0, "Başlık etiketi bulunmalı")
	assert(h_labels[0].contains("Deponun alabileceği"), "Başlık metni 'Deponun alabileceği' içermeli")

	# Güncel satırı (Lv1)
	var r_cur = children[1]
	var cur_labels = []
	for c in r_cur.find_children("*", "Label", true, false):
		cur_labels.append(c.text)
	print("Satır 1 (Güncel): ", cur_labels)
	assert(cur_labels.has("Güncel"), "İlk satır 'Güncel' olmalı")
	assert(cur_labels.has("1.000"), "Güncel seviye 1 kapasitesi '1.000' olmalı")

	# Sonraki seviyeler (Lv2-Lv5)
	var expected_levels = [
		{"name": "Seviye 2", "cap": "1.150"},
		{"name": "Seviye 3", "cap": "1.323"},
		{"name": "Seviye 4", "cap": "1.522"},
		{"name": "Seviye 5", "cap": "1.750"}
	]

	for i in range(4):
		var row = children[2 + i]
		var r_labels = []
		for c in row.find_children("*", "Label", true, false):
			r_labels.append(c.text)
		print("Satır %d: " % (i + 2), r_labels)
		assert(r_labels.has(expected_levels[i]["name"]), "%s etiketi bulunamadı" % expected_levels[i]["name"])
		assert(r_labels.has(expected_levels[i]["cap"]), "%s kapasitesi bulunamadı" % expected_levels[i]["cap"])

	# 2. Test Seviye 5
	print("\n--- Seviye 5 Depo Doğrulaması ---")
	if gs != null:
		var v = gs.get_active_village()
		var b = v.get("buildings", {})
		b["storage"] = 5
		v["buildings"] = b
		print("Doğrudan gs köy binaları: ", gs.get_active_village().get("buildings"))
		panel.show_building(v, "storage")
	else:
		mock_village_lvl1["buildings"]["storage"] = 5
		panel.show_building(mock_village_lvl1, "storage")

	var children5 = panel._prod_vbox.get_children()
	var cur5_labels = []
	for c in children5[1].find_children("*", "Label", true, false):
		cur5_labels.append(c.text)
	print("Seviye 5 Güncel Satırı: ", cur5_labels)
	assert(cur5_labels.has("1.750"), "Seviye 5 güncel kapasitesi 1.750 olmalı")

	var next5_row1 = []
	for c in children5[2].find_children("*", "Label", true, false):
		next5_row1.append(c.text)
	print("Seviye 6 Sonraki Satırı: ", next5_row1)
	assert(next5_row1.has("Seviye 6"), "Seviye 6 etiketi olmalı")
	assert(next5_row1.has("2.013"), "Seviye 6 kapasitesi 2.013 olmalı")

	print("\n✅ TÜM TESTLER BAŞARILI: Depo mevcut seviye ve sonraki 4 seviye tablosu kusursuz çalışıyor!")
	quit(0)
