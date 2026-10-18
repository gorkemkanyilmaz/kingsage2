extends PanelContainer
## BottomNav — Alt navigasyon menüsü (Taht ve Kılıç / A-ARAYUZ).

signal tab_selected(tab_name: String)

@onready var btn_village: Button = $HBox/BtnVillage
@onready var btn_map: Button = $HBox/BtnMap
@onready var btn_reports: Button = $HBox/BtnReports
@onready var btn_ranking: Button = $HBox/BtnRanking
@onready var btn_menu: Button = $HBox/BtnMenu


func _ready() -> void:
	btn_village.pressed.connect(func(): _on_tab_pressed("village", "res://scenes/Village.tscn"))
	btn_map.pressed.connect(func(): _on_tab_pressed("map", "res://scenes/WorldMap.tscn"))
	btn_reports.pressed.connect(func(): _on_tab_pressed("reports", "res://scenes/Reports.tscn"))
	btn_ranking.pressed.connect(func(): _on_tab_pressed("ranking", "res://scenes/Ranking.tscn"))
	btn_menu.pressed.connect(func(): _on_tab_pressed("settings", "res://scenes/Settings.tscn"))


func _on_tab_pressed(tab_name: String, target_scene: String) -> void:
	tab_selected.emit(tab_name)
	var tree := get_tree()
	if tree != null and ResourceLoader.exists(target_scene):
		# Eğer zaten o sahnede değilsek sahne değiştir
		if tree.current_scene != null and tree.current_scene.scene_file_path != target_scene:
			tree.change_scene_to_file(target_scene)
