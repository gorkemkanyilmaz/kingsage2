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
var _last_wall_unix: float = 0.0
var _manual_now_override: bool = false


func _init() -> void:
	# `--script` (headless) modunda `_ready()` gecikebilir; modüller erken yüklenir ki
	# testler ve erken sorgular `module_count()`'u hemen görebilsin.
	instance = self
	_load_modules()


func _ready() -> void:
	instance = self
	_now_unix = float(_initial_now())
	_last_wall_unix = float(Time.get_unix_time_from_system())
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

func sync_wall_clock_now(now_u: int = -1) -> void:
	var t := float(now_u if now_u > 0 else int(Time.get_unix_time_from_system()))
	_now_unix = t
	_last_wall_unix = t
	_auto_save_timer = 0.0


func _on_tick(delta_seconds: float) -> void:
	var real_now := float(Time.get_unix_time_from_system())
	var actual_delta := delta_seconds
	if not _manual_now_override and _last_wall_unix > 0.0 and real_now > _last_wall_unix:
		actual_delta = maxf(delta_seconds, real_now - _last_wall_unix)
	_last_wall_unix = real_now
	simulate(actual_delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		call_deferred("_on_tick", 0.0)
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		var sm := _autoload("SaveManager")
		if sm != null and sm.has_method("save_game"):
			sm.save_game()
		var wm := _autoload("WorldManager")
		if wm != null and wm.has_method("save_active_world"):
			wm.call("save_active_world", false, true)


func _next_sim_event_unix(state: Dictionary, max_unix: int) -> int:
	var earliest := max_unix
	var villages = state.get("villages", [])
	if typeof(villages) == TYPE_ARRAY:
		for v in villages:
			if typeof(v) != TYPE_DICTIONARY:
				continue
			for key in v:
				var val = v[key]
				if typeof(val) == TYPE_ARRAY:
					for item in val:
						if typeof(item) == TYPE_DICTIONARY and item.has("finish_unix"):
							var fu := int(item.get("finish_unix", 0))
							if fu > 0 and fu < earliest:
								earliest = fu
	var movements = state.get("movements", [])
	if typeof(movements) == TYPE_ARRAY:
		for mv in movements:
			if typeof(mv) == TYPE_DICTIONARY:
				var au := int(mv.get("arrive_unix", 0))
				if au > 0 and au < earliest:
					earliest = au
	return earliest


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
	var prev_now := _now_unix
	var real_now := int(Time.get_unix_time_from_system())
	if not _manual_now_override and _now_unix > 1500000000.0 and real_now > int(_now_unix):
		_now_unix = float(real_now)
	else:
		_now_unix += delta_seconds
	var now := int(floor(_now_unix + 0.5))
	var effective_delta: float = maxf(0.0, delta_seconds)

	var state: Dictionary = gs.as_live_dict() if gs.has_method("as_live_dict") else gs.to_dict()
	if typeof(state.get("world")) != TYPE_DICTIONARY:
		state["world"] = {}
	var world_dict := state["world"] as Dictionary
	world_dict["sim_now_unix"] = now

	if world_dict.has("starter_boost_until_unix"):
		var cfg := _autoload("GameConfig")
		if cfg != null and cfg.has_method("sync_from_world"):
			cfg.sync_from_world(world_dict, now)

	var events: Array = []
	if _manual_now_override or effective_delta <= 5.0:
		for script in _modules:
			var produced = script.process_tick(state, now, effective_delta)
			if typeof(produced) == TYPE_ARRAY:
				events.append_array(produced)
	else:
		# Uzun süreli arka plan / sekme duraklaması sonrası kronolojik telafi (gerçek duvar saatiyle)
		var cursor := int(floor(prev_now + 0.5))
		if cursor >= now:
			cursor = now
			for script in _modules:
				var produced_zero = script.process_tick(state, now, effective_delta)
				if typeof(produced_zero) == TYPE_ARRAY:
					events.append_array(produced_zero)
		else:
			var chunk_interval := maxi(60, int(effective_delta / 10.0))
			var bot_passes := 0
			var next_chunk := mini(now, cursor + chunk_interval)
			var iters := 0
			while cursor < now and iters < 60:
				iters += 1
				var next_ev := _next_sim_event_unix(state, now)
				var seg_end := mini(now, mini(next_ev, next_chunk))
				if seg_end < cursor:
					seg_end = cursor
				var seg_dt := float(seg_end - cursor)
				world_dict["sim_now_unix"] = seg_end
				for m_idx in range(_modules.size()):
					var is_bot_mod: bool = (m_idx < _loaded_paths.size() and str(_loaded_paths[m_idx]).ends_with("BotSimulator.gd"))
					if is_bot_mod:
						if bot_passes >= 3:
							continue
						bot_passes += 1
					var produced_seg = _modules[m_idx].process_tick(state, seg_end, seg_dt)
					if typeof(produced_seg) == TYPE_ARRAY:
						events.append_array(produced_seg)
				if seg_end >= next_chunk:
					next_chunk = mini(now, seg_end + chunk_interval)
				if seg_end == cursor:
					var check_next := _next_sim_event_unix(state, now)
					if check_next > cursor:
						continue
					seg_end = mini(now, next_chunk)
					if seg_end <= cursor:
						break
					cursor = seg_end
					continue
				cursor = seg_end
			if cursor < now:
				var rem_dt := float(now - cursor)
				world_dict["sim_now_unix"] = now
				for script in _modules:
					var produced_rem = script.process_tick(state, now, rem_dt)
					if typeof(produced_rem) == TYPE_ARRAY:
						events.append_array(produced_rem)

	var wm_sim := _autoload("WorldManager")
	if wm_sim != null:
		wm_sim.set("_suppress_tick_autosave", true)
	if gs.has_method("sync_from_live_dict"):
		gs.sync_from_live_dict(state, false)
	else:
		gs.from_dict(state)
	var has_bot_event := false
	for ev_chk in events:
		if typeof(ev_chk) == TYPE_DICTIONARY and str((ev_chk as Dictionary).get("type", "")).begins_with("bot_"):
			has_bot_event = true
			break
	_emit_events(events)
	if has_bot_event:
		var bus_bot := _autoload("EventBus")
		if bus_bot != null and bus_bot.has_signal("state_changed"):
			bus_bot.state_changed.emit()
	if wm_sim != null:
		wm_sim.set("_suppress_tick_autosave", false)

	# Periyodik otomatik kayıt (her 60 saniyede bir yerel disk damgası; buluta boşta HTTP isteği atmaz)
	# Manuel test zamanı (set_now_unix) kullanıldığında disk kaydıyla sim_now_unix'i bozma.
	if not _manual_now_override:
		_auto_save_timer += effective_delta
		if _auto_save_timer >= 60.0:
			_auto_save_timer = 0.0
			var sm = _autoload("SaveManager")
			if sm != null and sm.has_method("save_game"):
				sm.save_game(false, false)

	return events


# =============================================================================
#  Olay → EventBus köprüsü
# =============================================================================

func _emit_events(events: Array) -> void:
	var bus := _autoload("EventBus")
	if bus == null:
		return
	var wm := _autoload("WorldManager")
	if wm != null:
		wm.set("_suppress_tick_autosave", true)
	var needs_save := false
	var needs_immediate_conquest_save := false
	for e in events:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var ev := e as Dictionary
		var vid := int(ev.get("village_id", -1))
		match str(ev.get("type", "")):
			"building_completed":
				bus.building_completed.emit(vid, str(ev.get("key", "")), int(ev.get("level", 0)))
				if wm != null and wm.has_method("notify_local_mutation"):
					wm.call("notify_local_mutation")
				needs_save = true
				bus.state_changed.emit()
			"building_torn_down":
				bus.building_torn_down.emit(vid, str(ev.get("key", "")))
				if wm != null and wm.has_method("notify_local_teardown"):
					wm.call("notify_local_teardown", vid, str(ev.get("key", "")))
				needs_save = true
				bus.state_changed.emit()
			"realm_of_power_changed":
				bus.realm_of_power_changed.emit(vid, int(ev.get("value", 0)))
			"research_completed":
				bus.research_completed.emit(vid, str(ev.get("unit_key", ev.get("key", ""))))
				if wm != null and wm.has_method("notify_local_mutation"):
					wm.call("notify_local_mutation")
				needs_save = true
				bus.state_changed.emit()
			"unit_trained", "training_completed":
				bus.unit_trained.emit(vid, str(ev.get("unit_key", ev.get("key", ""))), int(ev.get("count", 0)))
				if wm != null and wm.has_method("notify_local_mutation"):
					wm.call("notify_local_mutation")
				needs_save = true
				bus.state_changed.emit()
			"village_conquered":
				var conq_owner := str(ev.get("new_owner", ev.get("owner", "")))
				if wm != null and wm.has_method("notify_local_conquest_mutation"):
					wm.call("notify_local_conquest_mutation", vid, conq_owner)
				elif wm != null and wm.has_method("notify_local_mutation"):
					wm.call("notify_local_mutation")
				bus.village_conquered.emit(vid, conq_owner)
				bus.state_changed.emit()
				needs_immediate_conquest_save = true
			"battle_resolved":
				if wm != null and wm.has_method("notify_local_mutation"):
					wm.call("notify_local_mutation")
				needs_save = true
				bus.battle_resolved.emit(ev)
				bus.report_created.emit(ev)
				bus.state_changed.emit()
			"spy_resolved":
				if wm != null and wm.has_method("notify_local_mutation"):
					wm.call("notify_local_mutation")
				needs_save = true
				bus.spy_mission_resolved.emit(ev)
				bus.report_created.emit(ev)
				bus.state_changed.emit()
			"movement_returned":
				if wm != null and wm.has_method("notify_local_mutation"):
					wm.call("notify_local_mutation")
				needs_save = true
				bus.army_returned.emit(ev)
				bus.resources_changed.emit(vid)
				bus.state_changed.emit()
			"trade_delivered":
				if wm != null and wm.has_method("notify_local_mutation"):
					wm.call("notify_local_mutation")
				needs_save = true
				bus.resources_changed.emit(vid)
				bus.state_changed.emit()
			"support_arrived":
				if wm != null and wm.has_method("notify_local_mutation"):
					wm.call("notify_local_mutation")
				needs_save = true
				bus.army_arrived.emit(ev)
				bus.state_changed.emit()
			_:
				pass
	if wm != null:
		wm.set("_suppress_tick_autosave", false)
		if needs_immediate_conquest_save and wm.has_method("save_active_world"):
			wm.call("save_active_world", true)
		elif needs_save:
			if wm.has_method("request_save_active_world"):
				wm.call("request_save_active_world", true)
			elif wm.has_method("save_active_world"):
				wm.call("save_active_world", true)


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
	_manual_now_override = true
