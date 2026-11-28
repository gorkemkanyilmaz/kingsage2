extends Node
## VillageBackgroundCache — Tek dokulu (1080×1920) yüksek netlikli ve sıfır VRAM savurganlıklı arka plan önbelleği.
##
## Build 44 kök neden çözümü:
##   Eski 96 karelik tam ekran video döngüsü (88.5 MB ASTC 4×4 -> L2 cache miss, LPDDR5 DRAM ısınması,
##   yükleme sırasında donma/takılma ve beat-aliasing) kaldırıldı.
##   Artık yalnızca 1 adet tam çözünürlüklü temiz köy peyzajı (`village_landscape_clean.jpg`, ~2.1 MB VRAM)
##   önbellekte tutulur; yel değirmeni dönüşü, baca dumanı ve su parıltısı GPU dostu küçük 2D sprite
##   katmanı (`VillageAmbientLayer`) ile kesintisiz ve sıfır ısınmayla oynatılır.

const FRAME_COUNT: int = 1
const TOTAL_FRAMES: int = 1
const FPS: float = 20.0
const TARGET_FPS: float = 20.0
const FRAME_DURATION: float = 1.0 / FPS
const LOOP_DURATION: float = 1.0
const FRAMES_PER_TICK: int = 1
const THREAD_PREFETCH_WINDOW: int = 1
const LOW_MEM_STRIDE: int = 1

const CLEAN_LANDSCAPE_PATH := "res://assets/sprites/village/village_landscape_clean.jpg"
const LEGACY_LANDSCAPE_PATH := "res://assets/sprites/village/village_landscape.jpg"

var frames: Array[Texture2D] = []
var is_fully_loaded: bool = true
var _low_memory_mode: bool = false
var _low_mem_ready: bool = true


func _init() -> void:
	frames.resize(FRAME_COUNT)
	var base_tex := _load_base_texture()
	frames[0] = base_tex
	is_fully_loaded = true
	_low_mem_ready = true


func _ready() -> void:
	set_process(false)


func _load_base_texture() -> Texture2D:
	for path in [CLEAN_LANDSCAPE_PATH, LEGACY_LANDSCAPE_PATH]:
		if ResourceLoader.exists(path):
			var res = ResourceLoader.load(path, "Texture2D")
			if res is Texture2D:
				return res
		var img := Image.new()
		if img.load(path) == OK:
			return ImageTexture.create_from_image(img)
	return null


func get_base_texture() -> Texture2D:
	if frames.is_empty():
		frames.resize(FRAME_COUNT)
	if frames[0] == null:
		frames[0] = _load_base_texture()
	return frames[0]


func _frame_path(_idx: int) -> String:
	return CLEAN_LANDSCAPE_PATH


func ensure_warming() -> void:
	get_base_texture()
	is_fully_loaded = true
	_low_mem_ready = true
	set_process(false)


func pause_warming() -> void:
	set_process(false)


func trim_memory() -> void:
	_low_memory_mode = true
	_low_mem_ready = true
	is_fully_loaded = true
	get_base_texture()
	set_process(false)


func get_frame_count() -> int:
	return FRAME_COUNT


func is_frame_ready(_index: int) -> bool:
	return get_base_texture() != null


func get_frame(_index: int = 0) -> Texture2D:
	return get_base_texture()
