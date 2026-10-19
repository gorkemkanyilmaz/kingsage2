extends Control
## MapRuler — Dünya haritasının sabit HUD katmanı.
##
## Haritanın kenarlarına kartografik bir çerçeve ve koordinat cetveli çizer.
## Cetvel, `ScrollContainer`'ın kaydırma değerlerine göre canlı güncellenir;
## böylece oyuncu nerede olduğunu her zaman görebilir. Fare olaylarını yutar
## değil (`MOUSE_FILTER_IGNORE`), altındaki harita normal çalışır.

const CELL := 96.0
const STEP := 10  ## Her 10 karede bir etiket/çentik

const INK := Color(0.36, 0.27, 0.14, 0.62)
const INK_SOFT := Color(0.36, 0.27, 0.14, 0.30)

var map_scroll: ScrollContainer = null

var _soft: GradientTexture2D = null


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_process(false)
	_build_soft_texture()
	resized.connect(queue_redraw)
	if get_parent() is Control:
		(get_parent() as Control).resized.connect(_fit_to_parent)
	_fit_to_parent()
	call_deferred("_fit_to_parent")
	if map_scroll != null:
		map_scroll.get_h_scroll_bar().value_changed.connect(_on_scroll_changed)
		map_scroll.get_v_scroll_bar().value_changed.connect(_on_scroll_changed)


func _fit_to_parent() -> void:
	# Boyutu doğrudan ebeveynden al (Control konteyner değil, anchors çalışmaz).
	if get_parent() is Control:
		var p := get_parent() as Control
		position = Vector2.ZERO
		size = p.size
	queue_redraw()


func _build_soft_texture() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	_soft = GradientTexture2D.new()
	_soft.gradient = grad
	_soft.width = 128
	_soft.height = 128
	_soft.fill = GradientTexture2D.FILL_RADIAL
	_soft.fill_from = Vector2(0.5, 0.5)
	_soft.fill_to = Vector2(0.5, 0.0)


func _on_scroll_changed(_value: float) -> void:
	queue_redraw()


func _draw() -> void:
	if map_scroll == null or size.x <= 0.0 or size.y <= 0.0:
		return

	var ox := -float(map_scroll.scroll_horizontal)
	var oy := -float(map_scroll.scroll_vertical)
	var font := get_theme_default_font()
	var font_size := 20

	# --- Kenar vinyeti (sabit, harita parşömenini çerçeveler) ---
	if _soft != null:
		var vs := Vector2(1100, 1100)
		var vc := Color(0.32, 0.23, 0.12, 0.13)
		draw_texture_rect(_soft, Rect2(Vector2(-vs.x * 0.5, -vs.y * 0.5), vs), false, vc)
		draw_texture_rect(_soft, Rect2(Vector2(size.x - vs.x * 0.5, -vs.y * 0.5), vs), false, vc)
		draw_texture_rect(_soft, Rect2(Vector2(-vs.x * 0.5, size.y - vs.y * 0.5), vs), false, vc)
		draw_texture_rect(_soft, Rect2(Vector2(size.x - vs.x * 0.5, size.y - vs.y * 0.5), vs), false, vc)

	# --- Cetvel şeritleri (yazılar haritanın üstünde okunaklı olsun) ---
	draw_rect(Rect2(0, 0, size.x, 54), Color(0.94, 0.89, 0.76, 0.78), true)
	draw_rect(Rect2(0, 0, 54, size.y), Color(0.94, 0.89, 0.76, 0.78), true)
	draw_rect(Rect2(0, 0, size.x, 54), Color(0.36, 0.27, 0.14, 0.22), false, 2.0)
	draw_rect(Rect2(0, 0, 54, size.y), Color(0.36, 0.27, 0.14, 0.22), false, 2.0)

	# --- Çerçeve (çift çizgi, köşe vurguları) ---
	draw_rect(Rect2(8, 8, size.x - 16, size.y - 16), INK_SOFT, false, 5.0)
	draw_rect(Rect2(15, 15, size.x - 30, size.y - 30), Color(0.36, 0.27, 0.14, 0.16), false, 1.0)
	_draw_corner(Vector2(8, 8))
	_draw_corner(Vector2(size.x - 8, 8))
	_draw_corner(Vector2(8, size.y - 8))
	_draw_corner(Vector2(size.x - 8, size.y - 8))

	# --- Üst cetvel (X koordinatları) ---
	var first_i := int(floor(((-ox) / CELL) / float(STEP))) - 1
	var last_i := first_i + int(size.x / CELL / float(STEP)) + 3
	for i in range(first_i, last_i):
		var cell_x := i * STEP
		if cell_x < 0 or cell_x > 200:
			continue
		var sx := float(cell_x) * CELL + ox
		if sx < 20.0 or sx > size.x - 20.0:
			continue
		draw_line(Vector2(sx, 9), Vector2(sx, 26), INK, 2.0)
		_label(font, Vector2(sx + 5.0, 46.0), str(cell_x), font_size)

	# --- Sol cetvel (Y koordinatları) ---
	var first_j := int(floor(((-oy) / CELL) / float(STEP))) - 1
	var last_j := first_j + int(size.y / CELL / float(STEP)) + 3
	for j in range(first_j, last_j):
		var cell_y := j * STEP
		if cell_y < 0 or cell_y > 200:
			continue
		var sy := float(cell_y) * CELL + oy
		if sy < 20.0 or sy > size.y - 20.0:
			continue
		draw_line(Vector2(9, sy), Vector2(26, sy), INK, 2.0)
		_label(font, Vector2(30.0, sy + 7.0), str(cell_y), font_size)

	# --- Alt-sol "bölge" rozeti ---
	var center_cx := int(((-ox) + size.x * 0.5) / CELL)
	var center_cy := int(((-oy) + size.y * 0.5) / CELL)
	var badge_text := "Bölge  %d | %d" % [center_cx, center_cy]
	var bw := font.get_string_size(badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 30.0
	var bh := 46.0
	var bpos := Vector2(24.0, size.y - 24.0 - bh)
	draw_rect(Rect2(bpos, Vector2(bw, bh)), Color(0.10, 0.09, 0.12, 0.62), true)
	draw_rect(Rect2(bpos, Vector2(bw, bh)), Color(0.85, 0.72, 0.42, 0.75), false, 2.0)
	_label(font, bpos + Vector2(15.0, 32.0), badge_text, font_size, Color(1.0, 0.93, 0.72, 0.95))


## Cetvel yazıları haritanın üstüne bindiği için açık parşömen konturuyla çizilir.
func _label(font: Font, pos: Vector2, text: String, font_size: int, col: Color = INK) -> void:
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0.94, 0.88, 0.74, 0.9))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)


func _draw_corner(at: Vector2) -> void:
	var hx := 1.0 if at.x < size.x * 0.5 else -1.0
	var hy := 1.0 if at.y < size.y * 0.5 else -1.0
	draw_line(at, at + Vector2(34.0 * hx, 0.0), INK, 3.0)
	draw_line(at, at + Vector2(0.0, 34.0 * hy), INK, 3.0)
