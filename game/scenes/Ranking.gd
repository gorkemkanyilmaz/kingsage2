extends Control
## Ranking — Oyuncu ve Köy Sıralaması (Taht ve Kılıç / A-ARAYUZ).

const Palette := preload("res://themes/Palette.gd")

const ROW_H := 84.0
const MEDALS := [
	Color(0.85, 0.66, 0.22),   # altın
	Color(0.72, 0.73, 0.76),   # gümüş
	Color(0.72, 0.45, 0.24),   # bronz
]

@onready var ranking_list: VBoxContainer = $Container/Scroll/List
@onready var btn_alliance: Button = $Header/HBox/BtnAlliance if has_node("Header/HBox/BtnAlliance") else null


func _ready() -> void:
	if btn_alliance != null:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.18, 0.25, 0.38, 0.95)
		sb.border_color = Color(0.50, 0.80, 1.0, 0.95)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(12)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		btn_alliance.add_theme_stylebox_override("normal", sb)
		var h_sb = sb.duplicate() as StyleBoxFlat
		h_sb.bg_color = Color(0.24, 0.35, 0.52, 1.0)
		btn_alliance.add_theme_stylebox_override("hover", h_sb)
		btn_alliance.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
		btn_alliance.pressed.connect(func():
			get_tree().change_scene_to_file("res://scenes/Alliance.tscn")
		)
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

	var active_id: int = int(gs.active_village_id)
	var player_name := str(gs.player.get("name", "Kral"))
	var rank := 1
	for v in villages:
		if rank > 50:
			break
		ranking_list.add_child(_make_row(rank, v, active_id, player_name))
		rank += 1


func _make_row(rank: int, v: Dictionary, active_id: int, player_name: String = "") -> PanelContainer:
	var is_player: bool = (int(v.get("id", -1)) == active_id) or (not player_name.is_empty() and str(v.get("owner", "")) == player_name)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, ROW_H)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.86, 0.95, 0.80, 0.85) if is_player else (Color(1.0, 0.99, 0.96, 0.92) if rank % 2 == 1 else Color(0.96, 0.92, 0.83, 0.92))
	sb.border_color = Palette.c("altin") if is_player else Color(0.62, 0.53, 0.40, 0.45)
	sb.set_border_width_all(3 if is_player else 1)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 12
	sb.content_margin_right = 16
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card.add_child(row)

	# Sıra madalyonu
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(64, 64)
	var bsb := StyleBoxFlat.new()
	if rank <= 3:
		bsb.bg_color = MEDALS[rank - 1]
		bsb.border_color = Palette.darken(MEDALS[rank - 1], 0.35)
	else:
		bsb.bg_color = Color(0.90, 0.86, 0.78)
		bsb.border_color = Color(0.62, 0.53, 0.40, 0.6)
	bsb.set_border_width_all(2)
	bsb.set_corner_radius_all(32)
	badge.add_theme_stylebox_override("panel", bsb)
	var badge_lbl := Label.new()
	badge_lbl.text = str(rank)
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_lbl.add_theme_font_size_override("font_size", 26)
	badge_lbl.add_theme_color_override("font_color", Color(1, 0.99, 0.94) if rank <= 3 else Color(0.26, 0.20, 0.12))
	badge.add_child(badge_lbl)
	row.add_child(badge)

	# Köy adı ve sahibi
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	var name_lbl := Label.new()
	name_lbl.text = str(v.get("name", "Köy"))
	name_lbl.add_theme_font_size_override("font_size", 24)
	name_lbl.add_theme_color_override("font_color", Color(0.20, 0.16, 0.11))
	info.add_child(name_lbl)

	var owner_lbl := Label.new()
	var owner := str(v.get("owner", "Bilinmeyen"))
	owner_lbl.text = "%s   (%d|%d)" % [owner, int(v.get("x", 0)), int(v.get("y", 0))]
	owner_lbl.add_theme_font_size_override("font_size", 18)
	owner_lbl.add_theme_color_override("font_color", Color(0.44, 0.38, 0.30))
	info.add_child(owner_lbl)
	row.add_child(info)

	# Puan
	var pts_lbl := Label.new()
	pts_lbl.text = "%d" % int(v.get("points", 0))
	pts_lbl.add_theme_font_size_override("font_size", 28)
	pts_lbl.add_theme_color_override("font_color", Color(0.42, 0.30, 0.12) if rank <= 3 else Color(0.30, 0.24, 0.16))
	pts_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(pts_lbl)

	if is_player:
		var you := Label.new()
		you.text = "SEN"
		you.add_theme_font_size_override("font_size", 16)
		you.add_theme_color_override("font_color", Color(0.25, 0.45, 0.15))
		you.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(you)

	return card
