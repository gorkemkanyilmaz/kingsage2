extends Node
## VillageBackgroundCache — 48 karelik (6 FPS, 8 sn — kaynak 192 kareden her 4. kare)
## akıcı köy arka plan animasyonunu çeyrek VRAM ve çeyrek decode maliyetiyle oynatan Autoload.

const SOURCE_FRAME_COUNT: int = 192
const FRAME_STRIDE: int = 4
const FRAME_COUNT: int = 48
const TOTAL_FRAMES: int = 48
const FPS: float = 6.0
const TARGET_FPS: float = 6.0
const FRAME_DURATION: float = 1.0 / FPS
const LOOP_DURATION: float = float(FRAME_COUNT) / FPS
const FRAMES_PER_TICK: int = 2
const THREAD_PREFETCH_WINDOW: int = 3
const LOW_MEM_STRIDE: int = 4
const MAX_MAIN_THREAD_COLLECT_USEC: int = 2500

var frames: Array[Texture2D] = []
var is_fully_loaded: bool = false
var _next_load_idx: int = 1
var _next_request_idx: int = 1
var _requested_flags: PackedByteArray = PackedByteArray()
var _low_memory_mode: bool = false
var _playhead_idx: int = 0
var _low_mem_ready: bool = false


func _init() -> void:
	frames.resize(FRAME_COUNT)
	_requested_flags.resize(FRAME_COUNT)
	var first_tex := _load_texture("res://assets/sprites/village/animated_bg/f_000.webp")
	if first_tex != null:
		frames[0] = first_tex
	_requested_flags[0] = 1
	_next_load_idx = 1
	_next_request_idx = 1


func _ready() -> void:
	set_process(false)


func _frame_path(idx: int) -> String:
	return "res://assets/sprites/village/animated_bg/f_%03d.webp" % (posmod(idx, FRAME_COUNT) * FRAME_STRIDE)


func ensure_warming() -> void:
	if _low_memory_mode:
		if not _low_mem_ready:
			_queue_threaded_prefetch()
			set_process(true)
		return
	if not is_fully_loaded:
		_queue_threaded_prefetch()
		set_process(true)


func pause_warming() -> void:
	set_process(false)


func trim_memory() -> void:
	if frames.size() != FRAME_COUNT:
		frames.resize(FRAME_COUNT)
	if _requested_flags.size() != FRAME_COUNT:
		_requested_flags.resize(FRAME_COUNT)
	for i in range(1, FRAME_COUNT):
		if i % LOW_MEM_STRIDE != 0:
			frames[i] = null
			_requested_flags[i] = 0
	if frames[0] == null:
		var first_tex := _load_texture(_frame_path(0))
		if first_tex != null:
			frames[0] = first_tex
	_requested_flags[0] = 1
	_next_load_idx = 1
	_next_request_idx = 1
	_low_memory_mode = true
	_low_mem_ready = _check_low_mem_loaded()
	is_fully_loaded = false
	set_process(not _low_mem_ready)


func _check_low_mem_loaded() -> bool:
	for idx in range(0, FRAME_COUNT, LOW_MEM_STRIDE):
		if frames[idx] == null:
			return false
	return true


func _notification(what: int) -> void:
	if what == NOTIFICATION_OS_MEMORY_WARNING:
		trim_memory()


func _queue_threaded_prefetch() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _low_memory_mode:
		var queued := 0
		for idx in range(0, FRAME_COUNT, LOW_MEM_STRIDE):
			if queued >= THREAD_PREFETCH_WINDOW:
				break
			if frames[idx] == null and _requested_flags[idx] == 0:
				var lp := _frame_path(idx)
				if ResourceLoader.exists(lp) and ResourceLoader.load_threaded_request(lp, "Texture2D") == OK:
					_requested_flags[idx] = 1
					queued += 1
		return
	var target_end := mini(FRAME_COUNT, _next_load_idx + THREAD_PREFETCH_WINDOW)
	while _next_request_idx < target_end:
		if frames[_next_request_idx] == null and _requested_flags[_next_request_idx] == 0:
			var path := _frame_path(_next_request_idx)
			if ResourceLoader.exists(path):
				var err := ResourceLoader.load_threaded_request(path, "Texture2D")
				if err == OK:
					_requested_flags[_next_request_idx] = 1
		_next_request_idx += 1


func _process(_delta: float) -> void:
	if _low_memory_mode:
		if _low_mem_ready or _check_low_mem_loaded():
			_low_mem_ready = true
			set_process(false)
			return
		var is_hl := (DisplayServer.get_name() == "headless")
		if not is_hl:
			_queue_threaded_prefetch()
		var lm_start := Time.get_ticks_usec()
		var lm_cnt := 0
		for idx in range(0, FRAME_COUNT, LOW_MEM_STRIDE):
			if lm_cnt >= FRAMES_PER_TICK:
				break
			if frames[idx] != null:
				continue
			var lp := _frame_path(idx)
			if is_hl or _requested_flags[idx] == 0:
				var stex := _load_texture(lp)
				if stex != null:
					frames[idx] = stex
				lm_cnt += 1
			else:
				var st_l := ResourceLoader.load_threaded_get_status(lp)
				if st_l == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
					break
				elif st_l == ResourceLoader.THREAD_LOAD_LOADED:
					var lres = ResourceLoader.load_threaded_get(lp)
					if lres is Texture2D:
						frames[idx] = lres
					lm_cnt += 1
				else:
					_requested_flags[idx] = 0
					lm_cnt += 1
			if not is_hl and (Time.get_ticks_usec() - lm_start) >= MAX_MAIN_THREAD_COLLECT_USEC:
				break
		_low_mem_ready = _check_low_mem_loaded()
		if _low_mem_ready:
			set_process(false)
		return

	if is_fully_loaded:
		set_process(false)
		return

	var is_headless := (DisplayServer.get_name() == "headless")
	if not is_headless:
		_queue_threaded_prefetch()

	var start_usec := Time.get_ticks_usec()
	var count := 0
	while _next_load_idx < FRAME_COUNT and count < FRAMES_PER_TICK:
		if frames[_next_load_idx] != null:
			_next_load_idx += 1
			continue

		var path := _frame_path(_next_load_idx)
		if is_headless or _requested_flags[_next_load_idx] == 0:
			var sync_tex := _load_texture(path)
			frames[_next_load_idx] = sync_tex if sync_tex != null else frames[0]
			_next_load_idx += 1
			count += 1
		else:
			var status := ResourceLoader.load_threaded_get_status(path)
			if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				# Arka plan iş parçacığı henüz çözüyorsa ana thread'i ASLA bloklama
				break
			elif status == ResourceLoader.THREAD_LOAD_LOADED:
				var res = ResourceLoader.load_threaded_get(path)
				if res is Texture2D:
					frames[_next_load_idx] = res
				else:
					var fallback_tex := _load_texture(path)
					frames[_next_load_idx] = fallback_tex if fallback_tex != null else frames[0]
				_next_load_idx += 1
				count += 1
			else:
				var err_tex := _load_texture(path)
				frames[_next_load_idx] = err_tex if err_tex != null else frames[0]
				_next_load_idx += 1
				count += 1

		if not is_headless and (Time.get_ticks_usec() - start_usec) >= MAX_MAIN_THREAD_COLLECT_USEC:
			break

	if not is_headless:
		_queue_threaded_prefetch()

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


func is_frame_ready(index: int) -> bool:
	if frames.is_empty():
		return false
	var safe_idx: int = posmod(index, FRAME_COUNT)
	if frames[safe_idx] != null:
		return true
	if DisplayServer.get_name() == "headless":
		return true
	if _requested_flags[safe_idx] == 1:
		var path := _frame_path(safe_idx)
		if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED:
			var res = ResourceLoader.load_threaded_get(path)
			if res is Texture2D:
				frames[safe_idx] = res
				return true
	return false


func get_frame(index: int) -> Texture2D:
	if frames.is_empty():
		return null
	var safe_idx: int = posmod(index, FRAME_COUNT)
	if _low_memory_mode:
		safe_idx = int(safe_idx / LOW_MEM_STRIDE) * LOW_MEM_STRIDE
	_playhead_idx = safe_idx
	var tex: Texture2D = frames[safe_idx]
	if tex != null:
		return tex
	var path := _frame_path(safe_idx)
	if DisplayServer.get_name() != "headless":
		if _requested_flags[safe_idx] == 1 and ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED:
			var threaded_res = ResourceLoader.load_threaded_get(path)
			if threaded_res is Texture2D:
				frames[safe_idx] = threaded_res
				return threaded_res
		elif _requested_flags[safe_idx] == 0 and ResourceLoader.exists(path):
			if ResourceLoader.load_threaded_request(path, "Texture2D") == OK:
				_requested_flags[safe_idx] = 1
		# Ana thread'de senkron disk yüklemesi yapıp takılmaya yol açmak yerine son hazır kareyi döndür
		var fallback_idx := clampi(_next_load_idx - 1, 0, FRAME_COUNT - 1)
		if frames[fallback_idx] != null:
			return frames[fallback_idx]
		return frames[0]
	tex = _load_texture(path)
	if tex != null:
		frames[safe_idx] = tex
		return tex
	return frames[0]
