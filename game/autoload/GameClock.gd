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

var running := false

## Toplam oyun-içi geçen süre (saniye).
var elapsed_seconds := 0.0

var _accumulator := 0.0


func _process(delta: float) -> void:
	if not running:
		return
	_accumulator += delta
	var steps := 0
	while _accumulator >= TICK_INTERVAL and steps < 1000:
		_accumulator -= TICK_INTERVAL
		_step(TICK_INTERVAL)
		steps += 1


## Tek bir simülasyon adımı.
func _step(delta_seconds: float) -> void:
	elapsed_seconds += delta_seconds
	EventBus.tick.emit(delta_seconds)
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
	EventBus.fast_forward_finished.emit(seconds)
