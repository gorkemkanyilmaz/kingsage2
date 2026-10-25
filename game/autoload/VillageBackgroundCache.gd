extends Node
## VillageBackgroundCache — 24 karelik akıcı video döngüsünü (smooth video loop)
## sıfır gecikme (0-latency) ile önbelleğe alıp hem Web'de hem mobilde kesintisiz
## oynatan tekil yönetici (Autoload).

const TOTAL_FRAMES: int = 24
const TARGET_FPS: float = 10.0
const FRAME_DURATION: float = 1.0 / TARGET_FPS
const LOOP_DURATION: float = float(TOTAL_FRAMES) / TARGET_FPS

var _frames: Array[Texture2D] = []
var _is_fully_loaded: bool = false
var _loaded_count: int = 0


func _init() -> void:
	_frames.resize(TOTAL_FRAMES)
	for i in range(TOTAL_FRAMES):
		var frame_num := i * 4
		var path := "res://assets/sprites/village/animated_bg/f_%03d.webp" % frame_num
		if ResourceLoader.exists(path):
			var tex: Texture2D = load(path)
			if tex != null:
				_frames[i] = tex
				_loaded_count = i + 1
		elif i > 0 and _frames[0] != null:
			_frames[i] = _frames[0]
	_is_fully_loaded = true


func _ready() -> void:
	_is_fully_loaded = true


func get_frame_count() -> int:
	return maxi(1, _loaded_count)


func is_fully_loaded() -> bool:
	return _is_fully_loaded


func get_frame(index: int) -> Texture2D:
	if _frames.is_empty():
		return null
	var count := maxi(1, _loaded_count)
	var safe_idx: int = posmod(index, count)
	return _frames[safe_idx]
