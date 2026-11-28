extends Node2D
## VillageAmbientLayer — Sıfır doku değişimi & sıfır L2 cache savurganlığı ile akıcı 2D köy yaşam katmanı.
##
## Build 44 kök neden çözümü:
##   Eski 96 karelik tam ekran video değişimi yerine tek bir yüksek çözünürlüklü 1080×1920 temiz köy
##   peyzajı üzerinde yalnızca küçük hareketli Sprite2D katmanları (yel değirmeni kanatları + gölgesi,
##   oduncu & demirci baca dumanı, meydan çeşmesi & nehir su parıltısı) matematiksel olarak döndürülür.
##   Böylece görüntü cam gibi net kalır, GPU doldurma yükü <%2 olur ve iPhone 4-5 FPS düşmeden ısınmaz.

const TexWindmillBlades := preload("res://assets/sprites/village/windmill_blades.png")
const TexSmokePuff := preload("res://assets/sprites/village/smoke_puff.png")
const TexWaterGlint := preload("res://assets/sprites/village/water_glint.png")

## Yel değirmeni mil merkezi (1080×1920 yerel köy koordinatları)
const WINDMILL_HUB_POS := Vector2(213.0, 472.0)
const WINDMILL_SHADOW_OFFSET := Vector2(5.0, 9.0)
const WINDMILL_BLADE_SCALE := Vector2(1.0, 0.92)
## ~12 saniyede 1 tam tur (rad/sn) — kesintisiz ipeksi akıcılık
const WINDMILL_RAD_PER_SEC: float = 0.52

## Baca ağız koordinatları (1080×1920 yerel koordinatlar)
const LUMBER_CHIMNEY_POS := Vector2(278.0, 750.0)
const BLACKSMITH_CHIMNEY_POS := Vector2(964.0, 1002.0)

## Çeşme & nehir su parıltısı noktaları (1080×1920 yerel koordinatlar)
const WATER_GLINT_SPECS := [
	{"pos": Vector2(562.0, 1108.0), "scale": Vector2(0.55, 0.45), "phase": 0.0, "speed": 1.6},
	{"pos": Vector2(165.0, 1664.0), "scale": Vector2(1.35, 0.85), "phase": 1.7, "speed": 1.15},
	{"pos": Vector2(676.0, 1842.0), "scale": Vector2(1.50, 0.90), "phase": 3.4, "speed": 1.05},
]

var _windmill_angle: float = 0.65
var _windmill_shadow: Sprite2D = null
var _windmill_blades: Sprite2D = null
var _smoke_items: Array[Dictionary] = []
var _glint_items: Array[Dictionary] = []
var _ambient_paused: bool = false
var _elapsed_time: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_build_sprites()


func _build_sprites() -> void:
	if _windmill_blades != null:
		return

	_windmill_shadow = Sprite2D.new()
	_windmill_shadow.name = "WindmillBladesShadow"
	_windmill_shadow.texture = TexWindmillBlades
	_windmill_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_windmill_shadow.position = WINDMILL_HUB_POS + WINDMILL_SHADOW_OFFSET
	_windmill_shadow.scale = WINDMILL_BLADE_SCALE
	_windmill_shadow.rotation = _windmill_angle
	_windmill_shadow.modulate = Color(0.08, 0.06, 0.04, 0.28)
	add_child(_windmill_shadow)

	_windmill_blades = Sprite2D.new()
	_windmill_blades.name = "WindmillBlades"
	_windmill_blades.texture = TexWindmillBlades
	_windmill_blades.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_windmill_blades.position = WINDMILL_HUB_POS
	_windmill_blades.scale = WINDMILL_BLADE_SCALE
	_windmill_blades.rotation = _windmill_angle
	add_child(_windmill_blades)

	_add_chimney_plume(LUMBER_CHIMNEY_POS, "LumberSmoke", 4, 4.4, 24.0, 0.34, 0.42)
	_add_chimney_plume(BLACKSMITH_CHIMNEY_POS, "BlacksmithSmoke", 4, 4.8, 30.0, 0.38, 0.48)

	for i in range(WATER_GLINT_SPECS.size()):
		var spec: Dictionary = WATER_GLINT_SPECS[i]
		var sp := Sprite2D.new()
		sp.name = "WaterGlint_%d" % i
		sp.texture = TexWaterGlint
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sp.position = spec["pos"]
		sp.scale = spec["scale"]
		sp.modulate = Color(1.0, 1.0, 1.0, 0.22)
		add_child(sp)
		_glint_items.append({
			"node": sp,
			"base_pos": spec["pos"],
			"phase": float(spec["phase"]),
			"speed": float(spec["speed"]),
		})


func _add_chimney_plume(origin: Vector2, prefix: String, count: int, life_sec: float, rise_speed: float, start_scale: float, base_alpha: float) -> void:
	for i in range(count):
		var sp := Sprite2D.new()
		sp.name = "%s_%d" % [prefix, i]
		sp.texture = TexSmokePuff
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sp.position = origin
		add_child(sp)
		_smoke_items.append({
			"node": sp,
			"origin": origin,
			"age": (float(i) / float(count)) * life_sec,
			"life": life_sec,
			"rise_speed": rise_speed,
			"start_scale": start_scale,
			"base_alpha": base_alpha,
			"drift_x": 11.0 + float(i) * 1.4,
			"sway_phase": float(i) * 1.57,
		})


func _process(delta: float) -> void:
	if _ambient_paused:
		set_process(false)
		return
	var dt := clampf(delta, 0.0, 0.12)
	if dt <= 0.0:
		return
	_elapsed_time += dt

	_windmill_angle = fmod(_windmill_angle + WINDMILL_RAD_PER_SEC * dt, TAU)
	if _windmill_shadow != null:
		_windmill_shadow.rotation = _windmill_angle
	if _windmill_blades != null:
		_windmill_blades.rotation = _windmill_angle

	for item in _smoke_items:
		var sp: Sprite2D = item["node"]
		var life: float = float(item["life"])
		var age: float = fmod(float(item["age"]) + dt, life)
		item["age"] = age
		var t := age / life
		var origin: Vector2 = item["origin"]
		var rise: float = age * float(item["rise_speed"])
		var drift: float = t * t * float(item["drift_x"]) + sin(_elapsed_time * 1.3 + float(item["sway_phase"])) * 4.5 * t
		sp.position = origin + Vector2(drift, -rise)
		var sc: float = float(item["start_scale"]) + t * 0.62
		sp.scale = Vector2(sc, sc)
		var fade_in := clampf(t / 0.18, 0.0, 1.0)
		var fade_out := clampf(1.0 - maxf(0.0, t - 0.35) / 0.65, 0.0, 1.0)
		sp.modulate = Color(1.0, 1.0, 1.0, float(item["base_alpha"]) * fade_in * fade_out)

	for g in _glint_items:
		var gsp: Sprite2D = g["node"]
		var wave := 0.5 + 0.5 * sin(_elapsed_time * float(g["speed"]) + float(g["phase"]))
		var bpos: Vector2 = g["base_pos"]
		gsp.position = bpos + Vector2(sin(_elapsed_time * 0.8 + float(g["phase"])) * 4.0, 0.0)
		gsp.modulate = Color(1.0, 1.0, 1.0, 0.12 + 0.36 * wave)


func set_ambient_paused(paused: bool) -> void:
	if _ambient_paused == paused and is_processing() == (not paused):
		return
	_ambient_paused = paused
	set_process(not paused)


func is_ambient_paused() -> bool:
	return _ambient_paused


func get_windmill_angle() -> float:
	return _windmill_angle
