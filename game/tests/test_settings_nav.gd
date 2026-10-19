extends SceneTree
## Settings Navigation Test — Ayarlar ekranı butonları ve navigasyon testi.

func _initialize() -> void:
	print("--- Ayarlar Ekranı Navigasyon Testi Başlıyor ---")
	var scene = load("res://scenes/Settings.tscn").instantiate()
	root.add_child(scene)
	scene._ready()

	var btn_back: Button = scene.get_node_or_null("Center/VBox/BtnBack")
	var btn_main_menu: Button = scene.get_node_or_null("Center/VBox/BtnMainMenu")

	assert(btn_back != null, "BtnBack (Köye Dön) butonu mevcut olmalı")
	assert(btn_main_menu != null, "BtnMainMenu (Ana Menü) butonu mevcut olmalı")
	assert(btn_back.pressed.get_connections().size() > 0, "BtnBack pressed sinyali bağlı olmalı")
	assert(btn_main_menu.pressed.get_connections().size() > 0, "BtnMainMenu pressed sinyali bağlı olmalı")

	print("[PASS] BtnBack ve BtnMainMenu butonları mevcut ve sinyalleri bağlı.")
	print("✅ AYARLAR NAVİGASYON TESTİ %100 BAŞARILI!")
	quit(0)
