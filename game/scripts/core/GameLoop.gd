extends Node
## GameLoop — simülasyon döngüsü (Taht ve Kılıç / **A-EKONOMI**).
##
## ## §7b Sim modül protokolü (`docs/19-MOTOR-API-SOZLESMESI.md` §7b)
## `GameClock.tick` sinyaline bağlanır; `MODULES` listesindeki her modülü **yol ile** yükler
## (`ResourceLoader.exists()` → yoksa **sessizce atlar**) ve her tick'te
## `process_tick(state, now_unix, delta_seconds)` çağırır. Dönen olayları `EventBus`
## sinyallerine çevirir. Modüller **birbirini beklemeden** yazılabilir.
##
## ## Offline hızlı-ileri (determinizm)
## `GameClock.fast_forward()`, `_step()` üzerinden `tick` yayar; bu yüzden offline telafi
## **aynı yolu** kullanır. `GameLoop` kendi **simülasyon saatini** (`_now_unix`) her tick
## `delta_seconds` kadar ilerletir ve `state.world.sim_now_unix`'e yazar; böylece inşa
## süreleri offline'da da doğru ilerler (gerçek zaman damgası donmuş olsa bile).
##
## ## Kullanım (A-ARAYUZ)
## ```gdscript
## var loop := preload("res://scripts/core/GameLoop.gd").new()
## add_child(loop)   # GameClock.tick'e bağlanır
## ```
##
## ⚠️ Bu düğüm **autoload değildir** (autoload A-HALKA'nın alanıdır). Ana sahne bir kez
## eklemelidir. Aynı anda iki örnek eklenirse tick iki kez işlenir → kaçının.

## Sim modül yolları (`docs/19` §7b). Var olmayan yollar sessizce atlanır.
const MODULES := [
	"res://scripts/sim/economy/EconomySimulator.gd",
	"res://scripts/sim/army/ArmySimulator.gd",
	"res://scripts/sim/actions/ActionSimulator.gd",
	"res://scripts/bot/BotSimulator.gd",
]

## Aktif GameLoop örneği (ekonomi API'si sim saatini buradan okuyabilir); yoksa null.
static var instance: Node = null

var _modules: Array = []
var _loaded_paths: Array = []
var _now_unix: float = 0.0
var _auto_save_timer: float = 0.0
var _connected := false


func _init() -> void:
	# `--script` (headless) modunda `_ready()` gecikebilir; modüller erken yüklenir ki
	# testler ve erken sorgular `module_count()`'u hemen görebilsin.
	instance = self
	_load_modules()


func _ready() -> void:
	instance = self
	_now_unix = float(_initial_now())
	if _modules.is_empty():
		_load_modules()
	_connect_clock()


func _exit_tree() -> void:
	var sm = _autoload("SaveManager")
	if sm != null and sm.has_method("save_game"):
		sm.save_game()
	if instance == self:
		instance = null


# =============================================================================
#  Kurulum
# =============================================================================

func _autoload(name: String) -> Node:
	if is_inside_tree() and get_tree() != null and get_tree().root != null:
		var n = get_tree().root.get_node_or_null(name)
		if n != null:
			return n
	var loop := Engine.get_main_loop()
	if loop is SceneTree and (loop as SceneTree).root != null:
		return (loop as SceneTree).root.get_node_or_null(name)
	return null


## Modülleri yola göre yükler; `ResourceLoader.exists()` false ise atlar.
func _load_modules() -> void:
	_modules.clear()
	_loaded_paths.clear()
	for path in MODULES:
		if ResourceLoader.exists(path):
			var script = load(path)
			if script != null:
				_modules.append(script)
				_loaded_paths.append(path)


func _connect_clock() -> void:
	if _connected:
		return
	var clock := _autoload("GameClock")
	if clock != null and clock.has_signal("tick") and not clock.tick.is_connected(_on_tick):
		clock.tick.connect(_on_tick)
		_connected = true


func _initial_now() -> int:
	var gs := _autoload("GameState")
	if gs != null:
		var world = gs.get("world")
		if typeof(world) == TYPE_DICTIONARY and (world as Dictionary).has("sim_now_unix"):
			return int((world as Dictionary)["sim_now_unix"])
	return int(Time.get_unix_time_from_system())


# =============================================================================
#  Döngü
# =============================================================================

func _on_tick(delta_seconds: float) -> void:
	simulate(delta_seconds)


## Bir simülasyon adımı: tüm modülleri çalıştırır, olayları yayınlar, durumu yazar.
## Dönen: bu adımda üretilen olaylar (test edilebilirlik için).
func simulate(delta_seconds: float) -> Array:
	var gs := _autoload("GameState")
	if gs == null:
		return []
	if _modules.is_empty():
		_load_modules()

	if _now_unix <= 0.0:
		_now_unix = float(_initial_now())
	var real_now := int(Time.get_unix_time_from_system())
	if _now_unix > 1500000000.0 and real_now > int(_now_unix):
		_now_unix = float(real_now)
	else:
		_now_unix += delta_seconds
	var now := int(floor(_now_unix + 0.5))

	var state: Dictionary = gs.to_dict()
	if typeof(state.get("world")) != TYPE_DICTIONARY:
		state["world"] = {}
	(state["world"] as Dictionary)["sim_now_unix"] = now

	var events: Array = []
	for script in _modules:
		var produced = script.process_tick(state, now, delta_seconds)
		if typeof(produced) == TYPE_ARRAY:
			events.append_array(produced)

	gs.from_dict(state)
	_emit_events(events)

	# Periyodik otomatik kayıt (her 30 saniyede bir son damga kaydedilir)
	_auto_save_timer += delta_seconds
	if _auto_save_timer >= 30.0:
		_auto_save_timer = 0.0
		var sm = _autoload("SaveManager")
		if sm != null and sm.has_method("save_game"):
			sm.save_game()

	return events


# =============================================================================
#  Olay → EventBus köprüsü
# =============================================================================

func _emit_events(events: Array) -> void:
	var bus := _autoload("EventBus")
	if bus == null:
		return
	for e in events:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var ev := e as Dictionary
		var vid := int(ev.get("village_id", -1))
		match str(ev.get("type", "")):
			"building_completed":
				bus.building_completed.emit(vid, str(ev.get("key", "")), int(ev.get("level", 0)))
			"building_torn_down":
				bus.building_torn_down.emit(vid, str(ev.get("key", "")))
			"realm_of_power_changed":
				bus.realm_of_power_changed.emit(vid, int(ev.get("value", 0)))
			"research_completed":
				bus.research_completed.emit(vid, str(ev.get("unit_key", ev.get("key", ""))))
			"unit_trained", "training_completed":
				bus.unit_trained.emit(vid, str(ev.get("unit_key", ev.get("key", ""))), int(ev.get("count", 0)))
			"village_conquered":
				bus.village_conquered.emit(vid, str(ev.get("owner", "")))
			"battle_resolved":
				bus.battle_resolved.emit(ev)
				bus.report_created.emit(ev)
				bus.state_changed.emit()
			"spy_resolved":
				bus.spy_mission_resolved.emit(ev)
				bus.report_created.emit(ev)
				bus.state_changed.emit()
			"movement_returned":
				bus.army_returned.emit(ev)
				bus.resources_changed.emit(vid)
				bus.state_changed.emit()
			"trade_delivered":
				bus.resources_changed.emit(vid)
				bus.state_changed.emit()
			"support_arrived":
				bus.army_arrived.emit(ev)
				bus.state_changed.emit()
			_:
				pass


# =============================================================================
#  Sorgular (UI / test)
# =============================================================================

## Şu anki simülasyon saati (unix benzeri int).
func now_unix() -> int:
	return int(floor(_now_unix + 0.5))


## Yüklenmiş modül yolları (test/teşhis).
func loaded_module_paths() -> Array:
	return _loaded_paths.duplicate()


## Yüklenen modül sayısı.
func module_count() -> int:
	return _modules.size()


## Sim saati elle ayarlar (kayıt yükleme / test).
func set_now_unix(value: int) -> void:
	_now_unix = float(value)
