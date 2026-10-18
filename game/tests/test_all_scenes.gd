extends SceneTree

func _init() -> void:
	print("=== Tüm Sahneleri ve UI Scriptlerini Doğrulama ===")
	var paths := [
		"res://autoload/EventBus.gd",
		"res://autoload/GameConfig.gd",
		"res://autoload/GameData.gd",
		"res://autoload/GameState.gd",
		"res://autoload/GameClock.gd",
		"res://autoload/SaveManager.gd",
		"res://scenes/MainMenu.tscn",
		"res://scenes/VillageSelect.tscn",
		"res://scenes/Village.tscn",
		"res://scenes/WorldMap.tscn",
		"res://scenes/Reports.tscn",
		"res://scenes/Ranking.tscn",
		"res://scenes/Settings.tscn",
		"res://ui/ResourceBar.tscn",
		"res://ui/BottomNav.tscn",
		"res://ui/BuildingPanel.tscn",
		"res://ui/SendTroopsPanel.tscn",
	]

	var fail_count := 0
	for p in paths:
		var res = load(p)
		if res == null:
			printerr("HATA: Yüklenemedi -> ", p)
			fail_count += 1
		else:
			print("OK: ", p)
			if p.ends_with(".tscn"):
				var node = res.instantiate()
				if node == null:
					printerr("HATA: Instantiate edilemedi -> ", p)
					fail_count += 1
				else:
					node.queue_free()

	if fail_count > 0:
		printerr("Toplam Hata: ", fail_count)
		quit(1)
	else:
		print("TÜM SAHNELER VE SCRIPTLER HATASIZ DERLENDİ!")
		quit(0)
