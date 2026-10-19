extends PanelContainer
## BottomNav — Modern Alt Navigasyon Menüsü (Taht ve Kılıç / A-ARAYUZ).

signal tab_selected(tab_name: String)

@onready var btn_village: Button = $HBox/BtnVillage
@onready var btn_map: Button = $HBox/BtnMap
@onready var btn_reports: Button = $HBox/BtnReports
@onready var btn_ranking: Button = $HBox/BtnRanking
@onready var btn_menu: Button = $HBox/BtnMenu


func _ready() -> void:
	_style_buttons()
	btn_village.pressed.connect(func(): _on_tab_pressed("village", "res://scenes/Village.tscn"))
	btn_map.pressed.connect(func(): _on_tab_pressed("map", "res://scenes/WorldMap.tscn"))
	btn_reports.pressed.connect(func(): _on_tab_pressed("reports", "res://scenes/Reports.tscn"))
	btn_ranking.pressed.connect(func(): _on_tab_pressed("ranking", "res://scenes/Ranking.tscn"))
	btn_menu.pressed.connect(func(): _on_tab_pressed("settings", "res://scenes/Settings.tscn"))


func _style_buttons() -> void:
	var buttons = [btn_village, btn_map, btn_reports, btn_ranking, btn_menu]
	var cur_path := ""
	if get_tree() != null and get_tree().current_scene != null:
		cur_path = get_tree().current_scene.scene_file_path

	for btn in buttons:
		if btn == null:
			continue
		var is_active := false
		if cur_path.contains("Village") and btn == btn_village:
			is_active = true
		elif cur_path.contains("WorldMap") and btn == btn_map:
			is_active = true
		elif cur_path.contains("Reports") and btn == btn_reports:
			is_active = true
		elif cur_path.contains("Ranking") and btn == btn_ranking:
			is_active = true
		elif cur_path.contains("Settings") and btn == btn_menu:
			is_active = true

		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(16)
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8

		if is_active:
			# Aktif sekme: Zengin altın parıltılı asil çerçeve
			sb.bg_color = Color(0.85, 0.68, 0.30, 0.22)
			sb.border_color = Color(0.96, 0.84, 0.45, 1.0)
			sb.set_border_width_all(2)
			btn.add_theme_color_override("font_color", Color(1.0, 0.96, 0.82))
			btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
			btn.add_theme_constant_override("shadow_offset_y", 1)
			btn.modulate = Color(1, 1, 1, 1)
		else:
			# Pasif sekme: Zarif koyu antrasit zemin
			sb.bg_color = Color(1.0, 1.0, 1.0, 0.05)
			sb.border_color = Color(0.50, 0.45, 0.40, 0.35)
			sb.set_border_width_all(1)
			btn.add_theme_color_override("font_color", Color(0.82, 0.80, 0.76))
			btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
			btn.add_theme_constant_override("shadow_offset_y", 1)
			btn.modulate = Color(1, 1, 1, 1)

		btn.add_theme_stylebox_override("normal", sb)

		var sb_hover := StyleBoxFlat.new()
		sb_hover.bg_color = Color(0.92, 0.76, 0.36, 0.38)
		sb_hover.border_color = Color(1.0, 0.90, 0.55, 1.0)
		sb_hover.set_border_width_all(2)
		sb_hover.set_corner_radius_all(16)
		sb_hover.content_margin_top = 8
		sb_hover.content_margin_bottom = 8
		sb_hover.shadow_color = Color(0.95, 0.78, 0.32, 0.4)
		sb_hover.shadow_size = 8
		btn.add_theme_stylebox_override("hover", sb_hover)
		btn.add_theme_stylebox_override("pressed", sb_hover)

		btn.pivot_offset = Vector2(98, 48)
		if not btn.mouse_entered.is_connected(btn.set_meta.bind("hovered", true)):
			btn.mouse_entered.connect(func():
				var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.12)
			)
			btn.mouse_exited.connect(func():
				var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12)
			)
			btn.button_down.connect(func():
				var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tw.tween_property(btn, "scale", Vector2(0.96, 0.96), 0.08)
			)
			btn.button_up.connect(func():
				var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15)
			)


func _on_tab_pressed(tab_name: String, target_scene: String) -> void:
	tab_selected.emit(tab_name)
	var tree := get_tree()
	if tree != null and ResourceLoader.exists(target_scene):
		if tree.current_scene != null and tree.current_scene.scene_file_path != target_scene:
			tree.change_scene_to_file(target_scene)
