extends Node
## SaveManager — yerel kaydet/yükle (Taht ve Kılıç).
##
## Tek oyunculu kayıt `user://` altında JSON olarak tutulur. Kayıt zarfı
## `saveVersion` alanı içerir; ileride şema değişince göç (migration) burada
## yapılır. Offline telafi için `savedAtUnix` damgası saklanır.

## Kayıt şeması sürümü. Şema değiştiğinde artırılır ve `_migrate()` güncellenir.
const SAVE_VERSION := 1

const SAVE_PATH := "user://taht_ve_kilic_save.json"
const WEB_SAVE_KEY := "tvk_save_game"

var _saving_now: bool = false
var _save_dirty: bool = false
var _save_debounce_timer: Timer = null


func _ready() -> void:
	pass


func _web_set(key: String, val: String) -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("try{window.localStorage.setItem(" + JSON.stringify(key) + "," + JSON.stringify(val) + ");if(typeof FS!=='undefined'&&FS.syncfs){FS.syncfs(false,function(){});}}catch(e){}", true)


func _web_get(key: String) -> String:
	if not OS.has_feature("web"):
		return ""
	var res = JavaScriptBridge.eval("(function(){try{var v=window.localStorage.getItem(" + JSON.stringify(key) + ");return typeof v==='string'?v:'';}catch(e){return '';}})()", true)
	return str(res) if typeof(res) == TYPE_STRING else ""


func _web_remove(key: String) -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("try{window.localStorage.removeItem(" + JSON.stringify(key) + ");if(typeof FS!=='undefined'&&FS.syncfs){FS.syncfs(false,function(){});}}catch(e){}", true)


func _read_raw_save_json() -> String:
	if FileAccess.file_exists(SAVE_PATH):
		return FileAccess.get_file_as_string(SAVE_PATH)
	var web_text := _web_get(WEB_SAVE_KEY)
	if not web_text.is_empty():
		var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(web_text)
			f.close()
	return web_text


# --- Sorgu ------------------------------------------------------------------

func _raw_save_has_player_village(player_name: String) -> bool:
	var raw := _read_raw_save_json()
	if raw.is_empty():
		return false
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var st: Variant = (parsed as Dictionary).get("state", {})
	if typeof(st) != TYPE_DICTIONARY:
		return false
	var vills: Variant = (st as Dictionary).get("villages", [])
	if typeof(vills) != TYPE_ARRAY:
		return false
	var target_l := player_name.strip_edges().to_lower()
	for v in (vills as Array):
		if typeof(v) != TYPE_DICTIONARY:
			continue
		var vd := v as Dictionary
		if bool(vd.get("is_bot", false)) or bool(vd.get("is_barbarian", false)):
			continue
		var ow_l := str(vd.get("owner", "")).strip_edges().to_lower()
		if not target_l.is_empty() and ow_l == target_l:
			return true
	return false


func has_save() -> bool:
	var loop = Engine.get_main_loop()
	if loop is SceneTree:
		var wm = loop.root.get_node_or_null("WorldManager")
		var auth = loop.root.get_node_or_null("AuthManager")
		if auth != null and auth.is_logged_in and wm != null and not auth.display_name.is_empty():
			if wm.has_player_village(wm.current_world_id, auth.display_name):
				return true
			if wm.is_player_conquered(wm.current_world_id, auth.display_name):
				return false
			return _raw_save_has_player_village(auth.display_name)
	return not _read_raw_save_json().is_empty()


func get_save_path() -> String:
	return SAVE_PATH


## Kayıt zarfının özet bilgilerini döndürür (yükleme yapmadan).
func get_save_meta() -> Dictionary:
	if not has_save():
		return {}
	var raw := _read_raw_save_json()
	if not raw.is_empty():
		var parsed = JSON.parse_string(raw)
		if typeof(parsed) == TYPE_DICTIONARY:
			return {
				"saveVersion": int(parsed.get("saveVersion", 0)),
				"savedAtUnix": int(parsed.get("savedAtUnix", 0)),
				"savedAtIso": str(parsed.get("savedAtIso", "")),
			}
	return {
		"saveVersion": SAVE_VERSION,
		"savedAtUnix": int(Time.get_unix_time_from_system()),
		"savedAtIso": Time.get_datetime_string_from_system(),
	}


func _game_state() -> Node:
	var loop = Engine.get_main_loop()
	return loop.root.get_node_or_null("GameState") if loop is SceneTree else null


func _game_clock() -> Node:
	var loop = Engine.get_main_loop()
	return loop.root.get_node_or_null("GameClock") if loop is SceneTree else null


func _game_config() -> Node:
	var loop = Engine.get_main_loop()
	return loop.root.get_node_or_null("GameConfig") if loop is SceneTree else null


func _event_bus() -> Node:
	var loop = Engine.get_main_loop()
	return loop.root.get_node_or_null("EventBus") if loop is SceneTree else null


# --- Kaydet -----------------------------------------------------------------

## Çalışma zamanında hızlı peş peşe mutasyonlarda disk/JSON yükünü birleştirir; headless testlerde anında yazar.
func request_save_game() -> void:
	if DisplayServer.get_name() == "headless":
		save_game(true)
		return
	_save_dirty = true
	if _save_debounce_timer == null or not is_instance_valid(_save_debounce_timer):
		_save_debounce_timer = Timer.new()
		_save_debounce_timer.one_shot = true
		_save_debounce_timer.wait_time = 0.6
		_save_debounce_timer.timeout.connect(func():
			if _save_dirty:
				save_game(true)
		)
		add_child(_save_debounce_timer)
	_save_debounce_timer.start(0.6)


## Oyun durumunu ve ayarları kaydeder.
func save_game(skip_world_save: bool = false, allow_cloud: bool = true) -> bool:
	if _saving_now:
		return true
	_saving_now = true
	_save_dirty = false
	if _save_debounce_timer != null and is_instance_valid(_save_debounce_timer):
		_save_debounce_timer.stop()

	var gs := _game_state()
	var gc := _game_clock()
	var cfg := _game_config()
	var bus := _event_bus()

	var now := int(Time.get_unix_time_from_system())
	if gs != null:
		# Offline telafi damgasını güncelle.
		gs.world["last_saved_unix"] = now
		if gc != null:
			gs.world["sim_time_seconds"] = gc.elapsed_seconds

	if not skip_world_save:
		var loop = Engine.get_main_loop()
		if loop is SceneTree:
			var wm = loop.root.get_node_or_null("WorldManager")
			if wm != null and not bool(wm.get("_saving_active_world")) and wm.has_method("save_active_world"):
				wm.save_active_world(false, allow_cloud)

	var state_payload: Dictionary = {}
	if gs != null:
		state_payload = gs.as_live_dict() if gs.has_method("as_live_dict") else gs.to_dict()
	var payload := {
		"saveVersion": SAVE_VERSION,
		"savedAtUnix": now,
		"savedAtIso": Time.get_datetime_string_from_system(),
		"state": state_payload,
		"config": cfg.to_dict() if cfg != null else {},
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		_saving_now = false
		push_error("SaveManager: kayıt dosyası açılamadı -> " + SAVE_PATH)
		if bus != null and bus.has_signal("error_occurred"):
			bus.error_occurred.emit("save_failed", "Kayıt dosyası yazılamadı.")
		return false
	var compact_json := JSON.stringify(payload)
	file.store_string(compact_json)
	file.close()
	_web_set(WEB_SAVE_KEY, compact_json)
	_saving_now = false

	if bus != null and bus.has_signal("game_saved"):
		bus.game_saved.emit()
	return true


# --- Yükle ------------------------------------------------------------------

## Kayıt varsa durumu ve ayarları yükler. Başarı durumunu döndürür.
func load_game() -> bool:
	var loop = Engine.get_main_loop()
	if loop is SceneTree:
		var wm = loop.root.get_node_or_null("WorldManager")
		var auth = loop.root.get_node_or_null("AuthManager")
		if auth != null and auth.is_logged_in and wm != null and not auth.display_name.is_empty():
			if wm.has_player_village(wm.current_world_id, auth.display_name):
				return wm.enter_world(wm.current_world_id, auth.display_name)
			if wm.is_player_conquered(wm.current_world_id, auth.display_name):
				return false

	var raw := _read_raw_save_json()
	if raw.is_empty():
		return false

	var bus := _event_bus()
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveManager: kayıt dosyası bozuk -> " + SAVE_PATH)
		if bus != null and bus.has_signal("error_occurred"):
			bus.error_occurred.emit("load_failed", "Kayıt dosyası okunamadı.")
		return false

	var version := int(parsed.get("saveVersion", 0))
	if version > SAVE_VERSION:
		push_warning("SaveManager: kayıt sürümü (%d) oyundan yeni (%d)." % [version, SAVE_VERSION])
	parsed = _migrate(parsed, version)

	var gs := _game_state()
	var cfg := _game_config()
	var loaded_now := int(Time.get_unix_time_from_system())
	if gs != null and typeof(parsed.get("state", {})) == TYPE_DICTIONARY:
		gs.from_dict(parsed["state"])
		var auth = Engine.get_main_loop().root.get_node_or_null("AuthManager") if Engine.get_main_loop() is SceneTree else null
		var p_name := ""
		if auth != null and auth.is_logged_in and not auth.display_name.is_empty():
			p_name = auth.display_name
		elif not str(gs.player.get("name", "")).is_empty() and str(gs.player.get("name", "")) != "Kral":
			p_name = str(gs.player.get("name"))
		else:
			p_name = "Lord Gorkem"
		gs.player["name"] = p_name
		if auth != null and auth.is_logged_in:
			if str(gs.player.get("auth_id", "")).is_empty():
				gs.player["auth_id"] = auth.user_id
			if str(gs.player.get("provider", "")).is_empty():
				gs.player["provider"] = auth.auth_provider
			if not gs.world.has("starter_boost_until_unix"):
				var created_u := int(gs.player.get("created_unix", loaded_now))
				gs.player["created_unix"] = created_u
				gs.world["starter_boost_until_unix"] = created_u + 7 * 86400
				gs.world["starter_boost_days"] = 7
				gs.world["base_speed"] = float(gs.world.get("base_speed", 1.0))
				gs.world["base_unit_speed"] = float(gs.world.get("base_unit_speed", 1.0))
		for v in gs.villages:
			if typeof(v) == TYPE_DICTIONARY and (not bool(v.get("is_bot", true)) and not bool(v.get("is_barbarian", false))):
				if str(v.get("owner", "")) == "Kral" or str(v.get("owner", "")).is_empty():
					v["owner"] = p_name
		if not gs.has_active_village():
			var p_low := p_name.strip_edges().to_lower()
			for v in gs.villages:
				if typeof(v) != TYPE_DICTIONARY:
					continue
				var vd := v as Dictionary
				if bool(vd.get("is_bot", false)) or bool(vd.get("is_barbarian", false)):
					continue
				if str(vd.get("owner", "")).strip_edges().to_lower() == p_low:
					gs.active_village_id = int(vd.get("id", -1))
					break
		if not gs.has_active_village():
			return false
		if cfg != null and gs.world.has("starter_boost_until_unix") and cfg.has_method("sync_from_world"):
			cfg.sync_from_world(gs.world, loaded_now)
		var saved_unix := int(parsed.get("savedAtUnix", 0))
		_apply_offline_catchup(gs, saved_unix)
		var TrainingScript := load("res://scripts/sim/army/Training.gd")
		if TrainingScript != null:
			TrainingScript.reconcile_state_settlers_reserved({"villages": gs.villages, "queues": gs.queues})
	if cfg != null and typeof(parsed.get("config", {})) == TYPE_DICTIONARY:
		cfg.from_dict(parsed["config"])
		if gs != null and gs.world.has("starter_boost_until_unix") and cfg.has_method("sync_from_world"):
			cfg.sync_from_world(gs.world, loaded_now)

	if bus != null and bus.has_signal("game_loaded"):
		bus.game_loaded.emit()
	return true


## Oyun kapalıyken geçen sürede hammadde üretimini, inşaat ve asker eğitim kuyruğunu telafi eder.
func _next_catchup_timestamp(state_dict: Dictionary, max_unix: int) -> int:
	var earliest := max_unix
	var villages = state_dict.get("villages", [])
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
	var movements = state_dict.get("movements", [])
	if typeof(movements) == TYPE_ARRAY:
		for mv in movements:
			if typeof(mv) == TYPE_DICTIONARY:
				var au := int(mv.get("arrive_unix", 0))
				if au > 0 and au < earliest:
					earliest = au
	return earliest


func _apply_offline_catchup(gs: Node, saved_unix: int) -> void:
	var now := int(Time.get_unix_time_from_system())
	if saved_unix <= 0:
		saved_unix = int(gs.world.get("last_saved_unix", 0))
	if saved_unix <= 0 or now <= saved_unix:
		return

	var elapsed_seconds := float(now - saved_unix)
	print("[SaveManager] Offline geçen süre telafi ediliyor: %d saniye (%.1f saat)" % [int(elapsed_seconds), elapsed_seconds / 3600.0])

	var ProdScript = load("res://scripts/sim/economy/Production.gd")
	var BQScript = load("res://scripts/sim/economy/BuildQueue.gd")
	var ArmySimScript = load("res://scripts/sim/army/ArmySimulator.gd")
	var ActionSimScript = load("res://scripts/sim/actions/ActionSimulator.gd")
	var BotSimScript = load("res://scripts/bot/BotSimulator.gd")
	var bus := _event_bus()

	var state_dict: Dictionary = gs.to_dict()
	var build_events: Array = []
	var army_events: Array = []
	var action_events: Array = []
	var human_vids: Dictionary = {}
	for v_item in state_dict.get("villages", []):
		if typeof(v_item) == TYPE_DICTIONARY:
			var vd_h := v_item as Dictionary
			if not bool(vd_h.get("is_bot", false)) and not bool(vd_h.get("is_barbarian", false)):
				human_vids[int(vd_h.get("id", -1))] = true

	var bot_interval := maxi(600, int(elapsed_seconds / 3.0))
	var bot_passes := 0
	var cursor := saved_unix
	var last_bot_t := saved_unix
	var next_bot_t := mini(now, saved_unix + bot_interval)
	var iters := 0

	while cursor < now and iters < 120:
		iters += 1
		var next_ev := _next_catchup_timestamp(state_dict, now)
		var seg_end := mini(now, mini(next_ev, next_bot_t))
		if seg_end < cursor:
			seg_end = cursor

		var seg_dt := float(seg_end - cursor)
		if seg_dt > 0.0 and ProdScript != null:
			for v in state_dict.get("villages", []):
				if typeof(v) == TYPE_DICTIONARY:
					ProdScript.produce(v as Dictionary, seg_dt)

		if BQScript != null:
			var bev = BQScript.advance(state_dict, seg_end)
			if typeof(bev) == TYPE_ARRAY:
				build_events.append_array(bev)

		if ArmySimScript != null:
			var aev = ArmySimScript.process_tick(state_dict, seg_end, 0.0)
			if typeof(aev) == TYPE_ARRAY:
				army_events.append_array(aev)

		if ActionSimScript != null:
			var actev = ActionSimScript.process_tick(state_dict, seg_end, 0.0)
			if typeof(actev) == TYPE_ARRAY:
				action_events.append_array(actev)

		if (seg_end >= next_bot_t or seg_end == now) and bot_passes < 3:
			if BotSimScript != null and seg_end > last_bot_t:
				BotSimScript.process_tick(state_dict, seg_end, float(seg_end - last_bot_t))
				bot_passes += 1
			last_bot_t = seg_end
			next_bot_t = mini(now, seg_end + bot_interval)

		if seg_end == cursor:
			var check_next := _next_catchup_timestamp(state_dict, now)
			if check_next > cursor:
				# Aynı saniyede kalan diğer olaylar temizlendi; sonraki olaya atlamak için döngü devam eder
				continue
			seg_end = mini(now, next_bot_t)
			if seg_end <= cursor:
				break
			cursor = seg_end
			continue
		cursor = seg_end

	if cursor < now:
		var rem_dt := float(now - cursor)
		if rem_dt > 0.0 and ProdScript != null:
			for v in state_dict.get("villages", []):
				if typeof(v) == TYPE_DICTIONARY:
					ProdScript.produce(v as Dictionary, rem_dt)
		if BQScript != null:
			var bev2 = BQScript.advance(state_dict, now)
			if typeof(bev2) == TYPE_ARRAY:
				build_events.append_array(bev2)
		if ArmySimScript != null:
			var aev2 = ArmySimScript.process_tick(state_dict, now, 0.0)
			if typeof(aev2) == TYPE_ARRAY:
				army_events.append_array(aev2)
		if ActionSimScript != null:
			var actev2 = ActionSimScript.process_tick(state_dict, now, 0.0)
			if typeof(actev2) == TYPE_ARRAY:
				action_events.append_array(actev2)

	gs.from_dict(state_dict)

	if bus != null:
		for ev in build_events:
			if typeof(ev) == TYPE_DICTIONARY and bus.has_signal("building_completed"):
				var b_vid := int(ev.get("village_id", -1))
				if human_vids.has(b_vid):
					bus.building_completed.emit(b_vid, str(ev.get("key", "")), int(ev.get("level", 0)))
		for ev in army_events:
			if typeof(ev) == TYPE_DICTIONARY:
				var ev_type := str(ev.get("type", ""))
				var vid := int(ev.get("village_id", -1))
				if not human_vids.has(vid):
					continue
				if ev_type == "research_completed" and bus.has_signal("research_completed"):
					bus.research_completed.emit(vid, str(ev.get("unit_key", ev.get("key", ""))))
				elif ev_type in ["unit_trained", "training_completed"] and bus.has_signal("unit_trained"):
					bus.unit_trained.emit(vid, str(ev.get("unit_key", ev.get("key", ""))), int(ev.get("count", 0)))
		for ev in action_events:
			if typeof(ev) == TYPE_DICTIONARY:
				if str(ev.get("type", "")) == "village_conquered" and bus.has_signal("village_conquered"):
					bus.village_conquered.emit(int(ev.get("village_id", -1)), str(ev.get("new_owner", ev.get("owner", ""))))
				elif bus.has_signal("report_created"):
					bus.report_created.emit(ev)

	gs.world["last_saved_unix"] = now
	gs.world["sim_now_unix"] = now

	if bus != null and bus.has_signal("resources_changed"):
		bus.resources_changed.emit(gs.active_village_id)


# --- Sil --------------------------------------------------------------------

func delete_save() -> bool:
	_web_remove(WEB_SAVE_KEY)
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var dir := DirAccess.open("user://")
	if dir == null:
		return false
	return dir.remove(SAVE_PATH.get_file()) == OK


# --- Göç (migration) --------------------------------------------------------

## Eski kayıt şemalarını günceller. Şu an sürüm 1 tek başlangıç noktasıdır.
func _migrate(payload: Dictionary, from_version: int) -> Dictionary:
	# Örnek iskelet: if from_version < 2: ...
	payload["saveVersion"] = SAVE_VERSION
	return payload
