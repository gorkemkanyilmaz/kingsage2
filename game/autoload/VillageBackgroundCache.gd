extends Node
## VillageBackgroundCache — 192 karelik (24 FPS, 8 sn) akıcı köy arka plan animasyonunu
## sıfır gecikme ile önbelleğe alıp hem Web'de (WASM) hem mobilde kesintisiz oynatan Autoload.

const FRAME_COUNT: int = 192
const TOTAL_FRAMES: int = 192
const FPS: float = 24.0
const TARGET_FPS: float = 24.0
const FRAME_DURATION: float = 1.0 / FPS
const LOOP_DURATION: float = float(FRAME_COUNT) / FPS
const FRAMES_PER_TICK: int = 6

var frames: Array[Texture2D] = []
var is_fully_loaded: bool = false
var _next_load_idx: int = 1


func _init() -> void:
	frames.resize(FRAME_COUNT)
	var first_tex := _load_texture("res://assets/sprites/village/animated_bg/f_000.webp")
	if first_tex != null:
		frames[0] = first_tex
	_next_load_idx = 1


func _ready() -> void:
	set_process(not is_fully_loaded)


func _process(_delta: float) -> void:
	if is_fully_loaded:
		set_process(false)
		return

	var count := 0
	while _next_load_idx < FRAME_COUNT and count < FRAMES_PER_TICK:
		if frames[_next_load_idx] == null:
			var path := "res://assets/sprites/village/animated_bg/f_%03d.webp" % _next_load_idx
			var tex := _load_texture(path)
			if tex != null:
				frames[_next_load_idx] = tex
			elif frames[0] != null:
				frames[_next_load_idx] = frames[0]
		_next_load_idx += 1
		count += 1

	if _next_load_idx >= FRAME_COUNT:
		is_fully_loaded = true
		set_process(false)


func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var res = ResourceLoader.load(path, "Texture2D")
		if res is Texture2D:
			return res
	var img := Image.new()
	if img.load(path) == OK:
		return ImageTexture.create_from_image(img)
	return null


func get_frame_count() -> int:
	return FRAME_COUNT


func get_frame(index: int) -> Texture2D:
	if frames.is_empty():
		return null
	var safe_idx: int = posmod(index, FRAME_COUNT)
	var tex: Texture2D = frames[safe_idx]
	if tex != null:
		return tex
	# Henüz arka planda yüklenmediyse anında yükle veya ilk kareyi döndür
	var path := "res://assets/sprites/village/animated_bg/f_%03d.webp" % safe_idx
	tex = _load_texture(path)
	if tex != null:
		frames[safe_idx] = tex
		return tex
	return frames[0]
