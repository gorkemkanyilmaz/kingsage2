extends Node
## VillageBackgroundCache — 192 karelik (ilk 8 saniye, 24 FPS orijinal hız) köy arka plan
## videosunun arka plan iş parçacığında (background thread) sıfır gecikme (0-latency) ile
## önbelleğe alınmasını ve kesintisiz oynatılmasını sağlayan Autoload tekil yöneticisi.

const TOTAL_FRAMES: int = 96 # İlk 8 saniye (8 sn * 12 FPS = 96 kare, son 2 sn kırpıldı)
const TARGET_FPS: float = 12.0 # Akıcı video akış hızı (8 saniyede 96 kare kesintisiz loop)
const FRAME_DURATION: float = 1.0 / TARGET_FPS # 1.0 / 12.0 = ~0.0833 sn
const LOOP_DURATION: float = float(TOTAL_FRAMES) / TARGET_FPS # 96 / 12.0 = 8.0 sn

var _frames: Array[Texture2D] = []
var _thread: Thread = null
var _mutex: Mutex = Mutex.new()
var _is_fully_loaded: bool = false
var _thread_active: bool = false
var _should_stop: bool = false
var _loaded_count: int = 0


func _init() -> void:
	_frames.resize(TOTAL_FRAMES)
	# İlk kareyi anında hazırla (Köy ekranı açıldığında boş görünmemesi için <2ms)
	var first_frame_path := "res://assets/sprites/village/animated_bg/f_000.webp"
	if ResourceLoader.exists(first_frame_path):
		var tex0: Texture2D = load(first_frame_path)
		if tex0 != null:
			_frames[0] = tex0
			_loaded_count = 1


func _ready() -> void:
	# Kalan kareleri ana iş parçacığını ve render akışını ASLA kilitlemeyecek şekilde
	# arka plan iş parçacığında (dedicated background thread) asenkron yükle
	_start_background_loading()


func _start_background_loading() -> void:
	if _thread_active or _is_fully_loaded:
		return
	_thread_active = true
	_thread = Thread.new()
	_thread.start(_worker_load_frames)


func _worker_load_frames() -> void:
	for i in range(1, TOTAL_FRAMES):
		if _should_stop:
			break
		var frame_num := i * 2
		var path := "res://assets/sprites/village/animated_bg/f_%03d.webp" % frame_num
		if ResourceLoader.exists(path):
			var tex: Texture2D = load(path)
			if tex != null:
				_mutex.lock()
				_frames[i] = tex
				_loaded_count = i + 1
				_mutex.unlock()
		# Arka plan iş parçacığı işletim sistemi zamanlayıcısına hafif nefes payı verir
		OS.delay_msec(4)
	
	_mutex.lock()
	_is_fully_loaded = true
	_thread_active = false
	_mutex.unlock()


func get_frame_count() -> int:
	if _mutex == null:
		return 1
	_mutex.lock()
	var count := _loaded_count
	_mutex.unlock()
	return maxi(1, count)


func is_fully_loaded() -> bool:
	if _mutex == null:
		return false
	_mutex.lock()
	var loaded := _is_fully_loaded
	_mutex.unlock()
	return loaded


func get_frame(index: int) -> Texture2D:
	if _mutex == null:
		return null
	_mutex.lock()
	var count := _loaded_count
	if count <= 0:
		_mutex.unlock()
		return null
	var safe_idx: int = posmod(index, count)
	var tex: Texture2D = _frames[safe_idx]
	_mutex.unlock()
	return tex


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_should_stop = true
		if _thread != null and _thread.is_started():
			_thread.wait_to_finish()
