extends Node
## GameClock — tick döngüsü ve offline hızlı-ileri (Taht ve Kılıç).
##
## Simülasyon sabit adımlarla ilerler (varsayılan 1 sn). Uygulama kapalıyken
## geçen süre kayıt dosyasındaki `last_saved_unix` damgasından hesaplanır ve
## açılışta `fast_forward()` ile telafi edilir.

signal tick(delta_seconds: float)
signal fast_forward_finished(elapsed_seconds: float)

## Tek bir simülasyon adımının süresi (saniye).
const TICK_INTERVAL := 1.0

## Offline telafide üretilecek en fazla adım sayısı. Uzun boşluklarda adım
## boyutu büyür (doğrusal sistemler integral alır), böylece açılış donmaz.
const MAX_CATCHUP_STEPS := 10000

## Hedef adaptif FPS seviyeleri (pil ve ısınma optimizasyonu).
const ADAPTIVE_ACTIVE_FPS := 60
const ADAPTIVE_MAP_MOV_IDLE_FPS := 15
const ADAPTIVE_IDLE_FPS := 12
const ADAPTIVE_STATIC_IDLE_FPS := 10
const ADAPTIVE_BACKGROUND_FPS := 2
const ADAPTIVE_BOOST_SECONDS := 1.5

var running := false
var adaptive_fps_enabled: bool = true

## Toplam oyun-içi geçen süre (saniye).
var elapsed_seconds := 0.0

var _accumulator := 0.0
var _fps_boost_remaining: float = ADAPTIVE_BOOST_SECONDS
var _fps_scene_check_accum: float = 0.0
var _current_target_fps: int = -1
var _app_backgrounded: bool = false


func _ready() -> void:
	start()
	if DisplayServer.get_name() != "headless":
		boost_fps(12.0)
	else:
		boost_fps()


func _input(event: InputEvent) -> void:
	if not adaptive_fps_enabled:
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseButton or event is InputEventKey:
		boost_fps()
	elif event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask != 0:
		boost_fps()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_app_backgrounded = true
		_apply_adaptive_fps(true)
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_app_backgrounded = false
		boost_fps()


func boost_fps(duration: float = ADAPTIVE_BOOST_SECONDS) -> void:
	_fps_boost_remaining = maxf(_fps_boost_remaining, maxf(0.1, duration))
	_apply_adaptive_fps(true)


func get_current_target_fps() -> int:
	return _current_target_fps


func _compute_adaptive_target_fps() -> int:
	if not adaptive_fps_enabled:
		return 0
	if _app_backgrounded:
		return ADAPTIVE_BACKGROUND_FPS
	if _fps_boost_remaining > 0.0:
		return ADAPTIVE_ACTIVE_FPS
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var st := loop as SceneTree
		var cur := st.current_scene
		if cur != null:
			var sname := str(cur.name)
			if sname == "Village":
				if cur.has_method("is_background_obscured") and bool(cur.call("is_background_obscured")):
					return ADAPTIVE_STATIC_IDLE_FPS
				return ADAPTIVE_IDLE_FPS
			if sname == "WorldMap":
				if cur.has_method("has_visible_movements"):
					return ADAPTIVE_MAP_MOV_IDLE_FPS if bool(cur.call("has_visible_movements")) else ADAPTIVE_STATIC_IDLE_FPS
				var gs: Node = st.root.get_node_or_null("GameState") if st.root != null else null
				if gs != null:
					var movs = gs.get("movements")
					if typeof(movs) == TYPE_ARRAY and not (movs as Array).is_empty():
						return ADAPTIVE_MAP_MOV_IDLE_FPS
				return ADAPTIVE_STATIC_IDLE_FPS
	return ADAPTIVE_STATIC_IDLE_FPS


func _apply_adaptive_fps(force: bool = false) -> void:
	var target := _compute_adaptive_target_fps()
	if not force and _current_target_fps == target:
		return
	_current_target_fps = target
	if DisplayServer.get_name() != "headless":
		Engine.max_fps = target


func _process(delta: float) -> void:
	if adaptive_fps_enabled:
		if _fps_boost_remaining > 0.0:
			_fps_boost_remaining = maxf(0.0, _fps_boost_remaining - maxf(delta, 0.0))
			if _fps_boost_remaining <= 0.0:
				_fps_scene_check_accum = 0.0
				_apply_adaptive_fps()
		_fps_scene_check_accum += maxf(delta, 0.0)
		if _fps_scene_check_accum >= 0.5:
			_fps_scene_check_accum = 0.0
			_apply_adaptive_fps()
	if not running:
		return
	_accumulator += delta
	var steps := 0
	while _accumulator >= TICK_INTERVAL and steps < 1000:
		_accumulator -= TICK_INTERVAL
		_step(TICK_INTERVAL)
		steps += 1


## Tek bir simülasyon adımı.
##
## **Aktif köy yoksa hiçbir şey yapmaz** (süre de ilerlemez, `tick` de yayınlanmaz)
## — bkz. T-2.12 kararı.
func _step(delta_seconds: float) -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null or not gs.has_active_village():
		return
	elapsed_seconds += delta_seconds
	var bus = Engine.get_main_loop().root.get_node_or_null("EventBus") if Engine.get_main_loop() is SceneTree else null
	if bus != null and bus.has_signal("tick"):
		bus.tick.emit(delta_seconds)
	tick.emit(delta_seconds)


func start() -> void:
	running = true


func stop() -> void:
	running = false
	_accumulator = 0.0


func reset() -> void:
	elapsed_seconds = 0.0
	_accumulator = 0.0


# --- Offline telafi ---------------------------------------------------------

## Verilen unix damgasından bu yana geçen saniyeyi döndürür (negatif olamaz).
func seconds_since(last_unix: int) -> float:
	var now := int(Time.get_unix_time_from_system())
	return maxf(0.0, float(now - last_unix))


## Kayıt dosyasındaki damgadan bu yana geçen süreyi hızlı-ileri ile telafi eder.
## Telafi edilen saniye sayısını döndürür.
func catch_up_from(last_unix: int) -> float:
	var elapsed := seconds_since(last_unix)
	if elapsed > 0.0:
		fast_forward(elapsed)
	return elapsed


## Geçen süreyi hızlı-ileri sarar.
##
## Kısa boşluklarda sabit `TICK_INTERVAL` adımları kullanılır. Uzun boşluklarda
## (ör. günlerce offline) adım boyutu büyütülür; doğrusal sistemler (üretim,
## depo taşması …) her adımda `delta_seconds × oran` integralini uygular ve
## açılış askıda kalmaz. Telafi edilen toplam süre `fast_forward_finished` ile
## bildirilir.
func fast_forward(seconds: float) -> void:
	if seconds <= 0.0:
		return
	var step_size: float = maxf(TICK_INTERVAL, seconds / float(MAX_CATCHUP_STEPS))
	var remaining := seconds
	var steps := 0
	while remaining > 0.0 and steps < MAX_CATCHUP_STEPS:
		var dt := minf(step_size, remaining)
		_step(dt)
		remaining -= dt
		steps += 1
	# Kayan nokta artığı olursa tamamla.
	if remaining > 0.0:
		_step(remaining)
	fast_forward_finished.emit(seconds)
	var bus = Engine.get_main_loop().root.get_node_or_null("EventBus") if Engine.get_main_loop() is SceneTree else null
	if bus != null and bus.has_signal("fast_forward_finished"):
		bus.fast_forward_finished.emit(seconds)
