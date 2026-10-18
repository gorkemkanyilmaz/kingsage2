extends RefCounted
## EconomyAPI — ekonomi dış arayüzü (UI / A-ARAYUZ için) (Taht ve Kılıç / **A-EKONOMI**).
##
## Sahip: **A-EKONOMI** · Sözleşme: `docs/19-MOTOR-API-SOZLESMESI.md` §3.2, §7b.
## Bu katman, `BuildQueue` / `Production` / `Population` modüllerini **arayüz dostu**
## sarmalar ve gerekirse **canlı `GameState`** ile çalışır.
##
## ## `state` çözümlemesi
## Tüm fonksiyonlar opsiyonel bir `state` (kök durum sözlüğü) alır:
##  • **Verilirse** (boş değilse) doğrudan onunla çalışır → **test edilebilir / deterministik**.
##  • **Verilmezse** `GameState` autoload'undan **canlı görünüm** üretilir
##    (`{villages, queues, world}`). Bu bir **görünüm**tür: `villages`/`queues` dizileri
##    GameState'in **aynı referanslarıdır**, dolayısıyla ekleme/çıkarma GameState'e yansır.
##
## ## Zaman
## `start_build`, simülasyon saatini `state.world.sim_now_unix`'ten okur; yoksa gerçek unix'e
## düşer (`GameLoop` bu alanı her tick günceller; canlı oyunda ≈ gerçek zaman).

const BQ := preload("res://scripts/sim/economy/BuildQueue.gd")
const PROD := preload("res://scripts/sim/economy/Production.gd")
const POP := preload("res://scripts/sim/economy/Population.gd")
const ROP := preload("res://scripts/sim/economy/RealmOfPower.gd")


# =============================================================================
#  Durum / zaman çözümlemesi
# =============================================================================

static func _game_state() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("GameState")
	return null


static func _event_bus() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("EventBus")
	return null


## Verilen `state` boşsa GameState'ten canlı görünüm üretir.
static func resolve_state(state: Dictionary) -> Dictionary:
	if not state.is_empty():
		return state
	var gs := _game_state()
	if gs == null:
		return {"villages": [], "queues": [], "world": {}}
	var view := {
		"villages": gs.get("villages"),
		"queues": gs.get("queues"),
		"world": gs.get("world"),
	}
	if typeof(view["villages"]) != TYPE_ARRAY:
		view["villages"] = []
	if typeof(view["queues"]) != TYPE_ARRAY:
		view["queues"] = []
	if typeof(view["world"]) != TYPE_DICTIONARY:
		view["world"] = {}
	return view


## Simülasyon saati: `world.sim_now_unix` (varsa) yoksa gerçek unix.
static func sim_now(state: Dictionary) -> int:
	var world = state.get("world", null)
	if typeof(world) == TYPE_DICTIONARY and (world as Dictionary).has("sim_now_unix"):
		return int((world as Dictionary)["sim_now_unix"])
	return int(Time.get_unix_time_from_system())


# =============================================================================
#  Dış arayüz
# =============================================================================

## İnşa başlatır. Başarılıysa `building_started` + `resources_changed` olayları yayınlanır.
## `state` verilmezse GameState kullanılır.
static func start_build(village: Dictionary, key: String, state: Dictionary = {}) -> Dictionary:
	var st := resolve_state(state)
	var now := sim_now(st)
	var result := BQ.start_build(st, village, key, now)
	if bool(result.get("ok", false)):
		_emit_started(village, key, int(result.get("target_level", 0)))
		_emit_resources(int(village.get("id", -1)))
	return result


## İnşa başlatılabilir mi? (`BuildQueue.can_start`)
static func can_start_build(village: Dictionary, key: String, state: Dictionary = {}) -> bool:
	return bool(BQ.can_start(resolve_state(state), village, key).get("ok", false))


## İnşa başlatma ayrıntısı (neden/eksik/ek maliyet) — UI için.
static func build_details(village: Dictionary, key: String, state: Dictionary = {}) -> Dictionary:
	return BQ.can_start(resolve_state(state), village, key)


## Köyün kuyruğundaki bina işleri (sıralı).
static func queued_items(village: Dictionary, state: Dictionary = {}) -> Array:
	return BQ.items(resolve_state(state), int(village.get("id", -1)))


## Köyün anlık hammaddeleri (kopya).
static func available_resources(village: Dictionary) -> Dictionary:
	return PROD.ensure_resources(village).duplicate(true)


## Bir kuyruk öğesinin bitmesine kalan saniye (`now_unix` verilmezse sim/gerçek saat).
static func tick_eta(item: Dictionary, now_unix: int = -1) -> int:
	if item.is_empty():
		return 0
	var now := now_unix
	if now < 0:
		now = int(Time.get_unix_time_from_system())
	return maxi(0, int(item.get("finish_unix", 0)) - now)


## Kuyruk öğesini iptal eder (varsayılan: **geri ödeme YOK**, bkz. ASSUMPTIONS.md §3).
static func cancel_build(village: Dictionary, item_id: int, state: Dictionary = {}, refund: bool = false) -> Dictionary:
	var st := resolve_state(state)
	return BQ.cancel_build(st, int(village.get("id", -1)), item_id, refund, sim_now(st))


## Değirmen tavanı / boş vatandaş özeti.
static func population_summary(village: Dictionary) -> Dictionary:
	return {
		"max": POP.max_citizens(village),
		"used": POP.used_citizens(village),
		"free": POP.free_citizens(village),
	}


## Güç Alanı bilgisi (değer / tavan / saatlik kazanç).
static func realm_summary(village: Dictionary) -> Dictionary:
	return {
		"value": ROP.value(village),
		"cap": ROP.cap(village),
		"hourly_gain": ROP.hourly_gain(village),
	}


# =============================================================================
#  Olay köprüsü
# =============================================================================

static func _emit_started(village: Dictionary, key: String, level: int) -> void:
	var bus := _event_bus()
	if bus != null:
		bus.building_started.emit(int(village.get("id", -1)), key, level)


static func _emit_resources(village_id: int) -> void:
	var bus := _event_bus()
	if bus != null:
		bus.resources_changed.emit(village_id)
