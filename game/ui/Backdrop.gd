extends Control
## Backdrop — Menü ve panel ekranları için ortak "parşömen" atmosferi.
##
## Düz krem zemini tek başına yavan duruyordu. Bu katman:
##   • Sıcak parşömen dokusunu (döşenmiş) hafif saydam çizer,
##   • Köşelere yumuşak aquarelle lekeleri ve kenar vinyeti ekler,
##   • Ortaya büyük, soluk bir arma/ikon filigranı basar.
##
## Kullanım: Sahnedeki `Background` düğümünün hemen ardına bir `Control`
## ekleyip bu betiği bağlayın; arzu edilen `@export` alanlarını ayarlayın.

@export var tint := Color(0.949020, 0.894118, 0.784314, 1.0)
@export var show_texture := true
@export var texture_alpha := 0.28
@export var show_emblem := true
@export var emblem_path := "res://assets/sprites/icons/cartography/2x/castleWide.png"
@export var emblem_alpha := 0.10
@export var emblem_size := 420.0
## Filigranın merkezi (0..1 arası normalize konum).
@export var emblem_center := Vector2(0.5, 0.30)

const PARCH := "res://assets/sprites/map/cartography-textures/parchmentAncient.png"

var _parch: Texture2D = null
var _emblem: Texture2D = null
var _soft: GradientTexture2D = null


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	if show_texture and ResourceLoader.exists(PARCH):
		_parch = load(PARCH)
	if show_emblem and ResourceLoader.exists(emblem_path):
		_emblem = load(emblem_path)
	_build_soft_texture()
	resized.connect(queue_redraw)


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


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	draw_rect(Rect2(Vector2.ZERO, size), tint)

	if _parch != null:
		draw_texture_rect(_parch, Rect2(Vector2.ZERO, size), true, Color(1, 1, 1, texture_alpha))

	# Yumuşak aquarelle lekeleri (sabit konumlar → her açılışta aynı)
	var spots := [
		[Vector2(0.14, 0.16), 1500.0, Color(0.62, 0.47, 0.21, 0.055)],
		[Vector2(0.88, 0.10), 1200.0, Color(0.42, 0.47, 0.28, 0.06)],
		[Vector2(0.10, 0.82), 1300.0, Color(0.55, 0.33, 0.20, 0.05)],
		[Vector2(0.92, 0.88), 1600.0, Color(0.70, 0.58, 0.32, 0.06)],
		[Vector2(0.50, 0.52), 2000.0, Color(0.40, 0.50, 0.52, 0.035)],
	]
	for s in spots:
		var center: Vector2 = Vector2(s[0].x * size.x, s[0].y * size.y)
		var dim: float = s[1]
		draw_texture_rect(_soft, Rect2(center - Vector2.ONE * dim * 0.5, Vector2.ONE * dim), false, s[2])

	# Kenar vinyeti
	var vc := Color(0.32, 0.23, 0.12, 0.12)
	var vs := Vector2(1500, 1500)
	draw_texture_rect(_soft, Rect2(Vector2(-vs.x * 0.5, -vs.y * 0.5), vs), false, vc)
	draw_texture_rect(_soft, Rect2(Vector2(size.x - vs.x * 0.5, -vs.y * 0.5), vs), false, vc)
	draw_texture_rect(_soft, Rect2(Vector2(-vs.x * 0.5, size.y - vs.y * 0.5), vs), false, vc)
	draw_texture_rect(_soft, Rect2(Vector2(size.x - vs.x * 0.5, size.y - vs.y * 0.5), vs), false, vc)

	# Arma filigranı
	if _emblem != null:
		var center2 := Vector2(emblem_center.x * size.x, emblem_center.y * size.y)
		draw_texture_rect(_emblem, Rect2(center2 - Vector2.ONE * emblem_size * 0.5, Vector2.ONE * emblem_size), false, Color(0.30, 0.22, 0.12, emblem_alpha))
