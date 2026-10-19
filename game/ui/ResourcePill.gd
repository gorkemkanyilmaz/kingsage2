extends HBoxContainer
## ResourcePill — Temiz ve profesyonel hammadde kapsülü (A-ARAYUZ).

@export var bg_color: Color = Color(0.14, 0.22, 0.16, 0.90)
@export var border_color: Color = Color(0.38, 0.70, 0.42, 0.85)
@export var corner_radius: int = 10


func _draw() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = border_color
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(corner_radius)
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
