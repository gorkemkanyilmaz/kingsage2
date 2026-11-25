extends HBoxContainer
## ResourcePill — Temiz, net ve profesyonel hammadde kapsülü (A-ARAYUZ).

@export var bg_color: Color = Color(0.12, 0.18, 0.14, 0.96)
@export var border_color: Color = Color(0.42, 0.78, 0.48, 0.95)
@export var corner_radius: int = 12
@export var border_width: int = 2


func _draw() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = border_color
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(corner_radius)
	sb.shadow_size = 0
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_offset = Vector2(0, 2)
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
