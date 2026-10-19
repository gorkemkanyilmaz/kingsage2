extends Control
## WorldDecor — Dünya haritası için parşömen/kartografi dekor katmanı.
##
## Harita zemini düz kalmıştı; bu katman tek bir `_draw()` içinde
## binlerce düğüm oluşturmadan haritaya "elle çizilmiş" bir doku kazandırır:
##   • Yumuşak su lekesi (radyal gradyan) → eski parşömen/aquarelle tonları
##   • Kıvrımlı nehirler (ince mürekkep + açık iç şerit)
##   • Göl ikonları (su lekesi + kartografi çizimi)
##   • Orman kümeleri (yosun lekesi + çam ikonları)
##   • Dağ sırtları (kahve leke + kaya ikonları)
##
## Köylerin ve suların üstüne ağaç/kaya konmaz. Tüm rastgelelikler sabit
## tohumludur; harita her açılışta aynı görünür.

const CELL := 96.0
const WORLD := 200
const SEED := 20240517

const TREE_PATHS := [
	"res://assets/sprites/icons/cartography/2x/treePines.png",
	"res://assets/sprites/icons/cartography/2x/treePinesSmall.png",
	"res://assets/sprites/icons/cartography/2x/treePineLarge.png",
	"res://assets/sprites/icons/cartography/2x/treePineTall.png",
	"res://assets/sprites/icons/cartography/2x/treePineTallLarge.png",
	"res://assets/sprites/icons/cartography/2x/treePineTallLow.png",
	"res://assets/sprites/icons/cartography/2x/treeTall.png",
]

const MOUNTAIN_PATHS := [
	"res://assets/sprites/icons/cartography/2x/rocksMountain.png",
	"res://assets/sprites/icons/cartography/2x/rocksTall.png",
	"res://assets/sprites/icons/cartography/2x/rocks.png",
	"res://assets/sprites/icons/cartography/2x/rocksA.png",
	"res://assets/sprites/icons/cartography/2x/rocksB.png",
]

const LAKE_PATHS := [
	"res://assets/sprites/icons/cartography/2x/lake.png",
	"res://assets/sprites/icons/cartography/2x/lakeRound.png",
]

var _village_cells: Dictionary = {}
var _water_cells: Dictionary = {}

var _stains: Array = []       # [Vector2 pos, Vector2 boyut, Color]
var _rivers: Array = []       # [PackedVector2Array]
var _lakes: Array = []        # [Vector2 pos, float boyut, int doku]
var _trees: Array = []        # [Vector2 pos, float boyut, int doku, float alfa]
var _mountains: Array = []    # [Vector2 pos, float boyut, int doku, float alfa]

var _tree_textures: Array = []
var _mount_textures: Array = []
var _lake_textures: Array = []
var _soft: GradientTexture2D = null


## Giriş noktası. `villages` dizi içindeki sözlüklerin x/y alanları kullanılır.
func setup(villages: Array) -> void:
	_mark_village_cells(villages)
	_load_textures()
	_build_soft_texture()

	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	_gen_stains(rng)
	_gen_rivers(rng)
	_gen_lakes(rng)
	_gen_forests(rng)
	_gen_mountains(rng)
	_gen_scatter(rng)

	queue_redraw()


# ---------------------------------------------------------------- hazırlık
func _mark_village_cells(villages: Array) -> void:
	for v in villages:
		if typeof(v) != TYPE_DICTIONARY:
			continue
		var vx: int = int(v.get("x", -999))
		var vy: int = int(v.get("y", -999))
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				_village_cells["%d,%d" % [vx + dx, vy + dy]] = true


func _load_textures() -> void:
	_tree_textures = _load_list(TREE_PATHS)
	_mount_textures = _load_list(MOUNTAIN_PATHS)
	_lake_textures = _load_list(LAKE_PATHS)


func _load_list(paths: Array) -> Array:
	var out: Array = []
	for p in paths:
		if ResourceLoader.exists(p):
			out.append(load(p))
	return out


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


func _cell(x: float, y: float) -> String:
	return "%d,%d" % [int(floor(x / CELL)), int(floor(y / CELL))]


func _cell_busy(x: float, y: float) -> bool:
	var key := _cell(x, y)
	return _village_cells.has(key) or _water_cells.has(key)


# ---------------------------------------------------------------- üreteçler
func _gen_stains(rng: RandomNumberGenerator) -> void:
	var tones := [
		Color(0.42, 0.47, 0.28),   # yosun
		Color(0.62, 0.47, 0.21),   # toprak/kehribar
		Color(0.55, 0.33, 0.20),   # pas
		Color(0.40, 0.50, 0.52),   # su grisi
		Color(0.70, 0.58, 0.32),   # altın toz
	]
	for i in range(95):
		var pos := Vector2(
			rng.randf_range(0.0, WORLD * CELL),
			rng.randf_range(0.0, WORLD * CELL)
		)
		var dim := Vector2.ONE * rng.randf_range(1000.0, 2900.0)
		var col: Color = tones[rng.randi_range(0, tones.size() - 1)]
		col.a = rng.randf_range(0.05, 0.12)
		_stains.append([pos, dim, col])


func _gen_rivers(rng: RandomNumberGenerator) -> void:
	for r in range(12):
		var points := PackedVector2Array()
		var x := rng.randf_range(4.0, WORLD - 4.0) * CELL
		var y := -CELL
		var drift := rng.randf_range(-0.9, 0.9)
		var phase := rng.randf_range(0.0, TAU)
		var wave_len := rng.randf_range(6.0, 11.0)
		var wave_amp := rng.randf_range(2.0, 4.2)
		while y < WORLD * CELL + CELL:
			points.append(Vector2(x, y))
			var wobble := sin(y / (CELL * wave_len) + phase) * CELL * wave_amp
			var wobble2 := sin(y / (CELL * 2.7) + phase * 1.7) * CELL * 0.35
			x = clampf(x + drift * CELL * 0.4 + (wobble + wobble2) * 0.30, 2.0 * CELL, WORLD * CELL - 2.0 * CELL)
			y += CELL * rng.randf_range(3.0, 6.0)
		_rivers.append(points)

		# nehir boyunca su hücrelerini işaretle (ağaç/dağ konmasın)
		for p in points:
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					_water_cells["%d,%d" % [int(p.x / CELL) + dx, int(p.y / CELL) + dy]] = true


func _gen_lakes(rng: RandomNumberGenerator) -> void:
	if _lake_textures.is_empty():
		return
	var placed := 0
	var tries := 0
	while placed < 26 and tries < 400:
		tries += 1
		var pos := Vector2(
			rng.randf_range(4.0, WORLD - 4.0) * CELL,
			rng.randf_range(4.0, WORLD - 4.0) * CELL
		)
		if _village_cells.has(_cell(pos.x, pos.y)):
			continue
		var dim := rng.randf_range(320.0, 720.0)
		var radius_cells := int(dim / CELL) + 2
		var blocked := false
		for dx in range(-radius_cells, radius_cells + 1):
			for dy in range(-radius_cells, radius_cells + 1):
				if _village_cells.has("%d,%d" % [int(pos.x / CELL) + dx, int(pos.y / CELL) + dy]):
					blocked = true
					break
			if blocked:
				break
		if blocked:
			continue
		_lakes.append([pos, dim, rng.randi_range(0, _lake_textures.size() - 1)])

		for dx in range(-radius_cells, radius_cells + 1):
			for dy in range(-radius_cells, radius_cells + 1):
				_water_cells["%d,%d" % [int(pos.x / CELL) + dx, int(pos.y / CELL) + dy]] = true
		placed += 1


func _gen_forests(rng: RandomNumberGenerator) -> void:
	if _tree_textures.is_empty():
		return
	for c in range(480):
		var center := Vector2(
			rng.randf_range(0.0, WORLD * CELL),
			rng.randf_range(0.0, WORLD * CELL)
		)
		var radius := rng.randf_range(1.0, 6.0) * CELL
		# orman altı yosun lekesi (üst üste binmiş 3 yumuşak leke → organik biçim)
		for j in range(3):
			var off := Vector2(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.4, 0.4)) * radius
			var moss := Color(0.34, 0.42, 0.24)
			moss.a = rng.randf_range(0.05, 0.11)
			_stains.append([center + off, Vector2.ONE * radius * rng.randf_range(1.8, 2.6), moss])

		var count := rng.randi_range(16, 34)
		for k in range(count):
			var ang := rng.randf_range(0.0, TAU)
			# Ağaçlar çoğunlukla kümenin çeperine dizilir → belirgin orman adacığı
			var rad := radius * (rng.randf_range(0.62, 1.0) if rng.randf() < 0.78 else sqrt(rng.randf()))
			var pos := center + Vector2(cos(ang), sin(ang)) * rad
			if pos.x < CELL or pos.y < CELL or pos.x > WORLD * CELL - CELL or pos.y > WORLD * CELL - CELL:
				continue
			if _cell_busy(pos.x, pos.y):
				continue
			var size := rng.randf_range(60.0, 118.0)
			var tex := rng.randi_range(0, _tree_textures.size() - 1)
			var alpha := rng.randf_range(0.48, 0.78)
			_trees.append([pos, size, tex, alpha])


func _gen_mountains(rng: RandomNumberGenerator) -> void:
	if _mount_textures.is_empty():
		return
	for r in range(200):
		var pos := Vector2(
			rng.randf_range(3.0, WORLD - 3.0) * CELL,
			rng.randf_range(3.0, WORLD - 3.0) * CELL
		)
		if _village_cells.has(_cell(pos.x, pos.y)):
			continue
		var ang := rng.randf_range(0.0, TAU)
		var length := rng.randi_range(3, 10)
		var ridge_color := Color(0.40, 0.32, 0.22)
		ridge_color.a = rng.randf_range(0.05, 0.09)
		_stains.append([pos, Vector2.ONE * length * CELL * 1.6, ridge_color])

		var dir := Vector2(cos(ang), sin(ang))
		var perp := Vector2(-dir.y, dir.x)
		for k in range(length):
			var p := pos + dir * (float(k) * CELL * 1.15) + perp * rng.randf_range(-CELL * 0.6, CELL * 0.6)
			if p.x < CELL or p.y < CELL or p.x > WORLD * CELL - CELL or p.y > WORLD * CELL - CELL:
				continue
			if _cell_busy(p.x, p.y):
				continue
			var size := rng.randf_range(130.0, 200.0)
			var tex := rng.randi_range(0, _mount_textures.size() - 1)
			var alpha := rng.randf_range(0.45, 0.70)
			_mountains.append([p, size, tex, alpha])


func _gen_scatter(rng: RandomNumberGenerator) -> void:
	# Ovalardaki tek tük ağaç ve kayalar (orman kümelerini dengeleyip
	# haritanın boş kalan bölgelerine doku verir).
	for i in range(1500):
		var pos := Vector2(
			rng.randf_range(0.0, WORLD * CELL),
			rng.randf_range(0.0, WORLD * CELL)
		)
		if _cell_busy(pos.x, pos.y):
			continue
		if rng.randf() < 0.78 and not _tree_textures.is_empty():
			var size := rng.randf_range(44.0, 78.0)
			var tex := rng.randi_range(0, _tree_textures.size() - 1)
			var alpha := rng.randf_range(0.22, 0.46)
			_trees.append([pos, size, tex, alpha])
		elif not _mount_textures.is_empty():
			var size := rng.randf_range(56.0, 96.0)
			var tex := rng.randi_range(0, _mount_textures.size() - 1)
			var alpha := rng.randf_range(0.20, 0.40)
			_mountains.append([pos, size, tex, alpha])


# ---------------------------------------------------------------- çizim
func _draw() -> void:
	# 1) Yumuşak parşömen lekeleri
	for s in _stains:
		draw_texture_rect(_soft, Rect2(s[0] - s[1] * 0.5, s[1]), false, s[2])

	# 2) Nehirler: kıyı gölgesi + su gövdesi + akış çentikleri
	for river in _rivers:
		draw_polyline(river, Color(0.36, 0.42, 0.46, 0.16), 30.0, true)
		draw_polyline(river, Color(0.72, 0.83, 0.87, 0.52), 14.0, true)
		draw_polyline(river, Color(0.42, 0.57, 0.66, 0.40), 8.0, true)
		for i in range(1, river.size() - 1, 2):
			var a: Vector2 = river[i - 1]
			var b: Vector2 = river[i + 1]
			var dirn := (b - a).normalized()
			var nrm := Vector2(-dirn.y, dirn.x)
			var c: Vector2 = river[i]
			draw_line(c - nrm * 7.0, c + nrm * 7.0, Color(0.34, 0.47, 0.55, 0.32), 2.0, true)

	# 3) Göller: su lekesi + kartografi çizimi
	for l in _lakes:
		var pos: Vector2 = l[0]
		var dim: float = l[1]
		draw_texture_rect(_soft, Rect2(pos - Vector2.ONE * dim * 0.85, Vector2.ONE * dim * 1.7), false, Color(0.44, 0.60, 0.66, 0.20))
		draw_texture_rect(_lake_textures[l[2]], Rect2(pos - Vector2.ONE * dim * 0.5, Vector2.ONE * dim), false, Color(0.30, 0.42, 0.48, 0.52))

	# 4) Ormanlar
	for t in _trees:
		draw_texture_rect(_tree_textures[t[2]], Rect2(t[0] - Vector2.ONE * t[1] * 0.5, Vector2.ONE * t[1]), false, Color(0.24, 0.30, 0.18, t[3]))

	# 5) Dağ sırtları
	for m in _mountains:
		draw_texture_rect(_mount_textures[m[2]], Rect2(m[0] - Vector2.ONE * m[1] * 0.5, Vector2.ONE * m[1]), false, Color(0.32, 0.27, 0.21, m[3]))
