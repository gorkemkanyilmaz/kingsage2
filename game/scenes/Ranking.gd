extends Control
## Ranking — Oyuncu ve Köy Sıralaması (Taht ve Kılıç / A-ARAYUZ).

@onready var ranking_list: VBoxContainer = $Container/Scroll/List


func _ready() -> void:
	_populate_rankings()


func _populate_rankings() -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null:
		return

	for child in ranking_list.get_children():
		child.queue_free()

	var villages: Array = gs.villages.duplicate(true)
	villages.sort_custom(func(a, b):
		return int(a.get("points", 0)) > int(b.get("points", 0)))

	var rank := 1
	for v in villages:
		if rank > 50:
			break
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 72)

		var rank_lbl := Label.new()
		rank_lbl.custom_minimum_size = Vector2(80, 0)
		rank_lbl.text = "#%d" % rank
		rank_lbl.theme_override_font_sizes/font_size = 24
		row.add_child(rank_lbl)

		var name_lbl := Label.new()
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.text = "%s (%s)" % [str(v.get("name", "Köy")), str(v.get("owner", "Bilinmeyen"))]
		name_lbl.theme_override_font_sizes/font_size = 22
		row.add_child(name_lbl)

		var pts_lbl := Label.new()
		pts_lbl.text = "%d Puan" % int(v.get("points", 0))
		pts_lbl.theme_override_font_sizes/font_size = 22
		row.add_child(pts_lbl)

		ranking_list.add_child(row)
		rank += 1
