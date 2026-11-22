extends Node
## WorldManager — Çoklu ve Kalıcı Dünyalar Yöneticisi (Taht ve Kılıç).
##
## Kurallar:
## 1. Dünya 1 kalıcı ve sabittir (tohum 1001).
## 2. Her dünya 50 standart bot ile başlar ve botlar normal oyuncu hızında gelişir.
## 3. Her dünya en fazla 100 gerçek oyuncu kabul eder (toplam 150 katılımcı).
## 4. 100 gerçek oyuncu dolduğunda sıradaki dünya (Dünya 2) açılır (o da 50 botla başlar).
## 5. Dünyalar asla rastgele sıfırlanmaz, kalıcı olarak yaşar.
## 6. Çevrimdışı geçen sürede madenler, inşaatlar, asker eğitimleri ve botlar simüle edilir.
## 7. Oyuncu bir dünyada köy sahibi değilse veya tüm köyleri fethedildiyse "DÜNYAYA KATIL"
##    ile yeni bir köy açabilir; köyü varsa "DÜNYAYA DEVAM ET" ile bağlanır.

const WorldGeneratorScript := preload("res://scripts/world/WorldGenerator.gd")
const VillageModelScript := preload("res://scripts/model/VillageModel.gd")
const ConqueredModalScript := preload("res://ui/ConqueredModal.gd")

const WORLDS_COUNT := 10
const BASE_SEED := 1000
const BOTS_PER_WORLD := 50
const MAX_REAL_PLAYERS_PER_WORLD := 100

const WORLDS_DIR := "user://worlds"
const META_FILE := "user://worlds_meta.json"
const EPOCH_FILE := "user://client_reset_epoch.txt"
const WEB_META_KEY := "tvk_worlds_meta"
const WEB_WORLD_PREFIX := "tvk_world_"
const WEB_EPOCH_KEY := "tvk_client_reset_epoch"
const CLIENT_RESET_EPOCH := 5

var current_world_id: int = 1
var worlds_meta: Array = []
var _last_autosave_unix: int = 0
var _last_cloud_save_unix: int = 0

const CLOUD_POLL_INTERVAL_SEC := 8.0
var _cloud_poll_accum: float = 0.0
var _cloud_poll_in_flight: bool = false
var _last_local_mutation_unix: int = 0
var _local_mutation_seq: int = 0
var _last_cloud_save_seq: int = 0
var _recent_teardown_until_unix: int = 0
var _wallet_lock_until_unix: int = 0
var _is_applying_cloud_sync: bool = false
var _suppress_reset_save: bool = false
var suppress_auto_conquered_prompt: bool = false


func notify_local_mutation() -> void:
	_local_mutation_seq += 1
	_last_local_mutation_unix = int(Time.get_unix_time_from_system())


func notify_local_teardown(_vid: int = -1, _key: String = "") -> void:
	notify_local_mutation()
	_recent_teardown_until_unix = int(Time.get_unix_time_from_system()) + 30


func notify_local_wallet_mutation() -> void:
	notify_local_mutation()
	var now := int(Time.get_unix_time_from_system())
	_wallet_lock_until_unix = now + 12


func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		_check_client_reset_epoch()
	_ensure_directory()
	if not _meta_exists():
		reset_all_worlds()
	else:
		_load_meta()
	_sync_save_fallback_to_world()
	var bus = Engine.get_main_loop().root.get_node_or_null("EventBus") if Engine.get_main_loop() is SceneTree else null
	if bus != null:
		if bus.has_signal("state_changed") and not bus.state_changed.is_connected(_on_state_changed_autosave):
			bus.state_changed.connect(_on_state_changed_autosave)
		if bus.has_signal("village_conquered") and not bus.village_conquered.is_connected(_on_village_conquered_signal):
			bus.village_conquered.connect(_on_village_conquered_signal)
		if bus.has_signal("building_started") and not bus.building_started.is_connected(_on_building_progress_event):
			bus.building_started.connect(_on_building_progress_event)
		if bus.has_signal("building_completed") and not bus.building_completed.is_connected(_on_building_completed_event):
			bus.building_completed.connect(_on_building_completed_event)
		if bus.has_signal("building_torn_down") and not bus.building_torn_down.is_connected(_on_building_torndown_event):
			bus.building_torn_down.connect(_on_building_torndown_event)
		if bus.has_signal("research_completed") and not bus.research_completed.is_connected(_on_research_completed_event):
			bus.research_completed.connect(_on_research_completed_event)
		if bus.has_signal("unit_trained") and not bus.unit_trained.is_connected(_on_building_progress_event):
			bus.unit_trained.connect(_on_building_progress_event)


func _check_client_reset_epoch() -> void:
	var stored_epoch := 0
	if FileAccess.file_exists(EPOCH_FILE):
		var rf := FileAccess.open(EPOCH_FILE, FileAccess.READ)
		if rf != null:
			stored_epoch = int(rf.get_as_text().strip_edges())
			rf.close()
	var web_ep := _web_get(WEB_EPOCH_KEY)
	if not web_ep.is_empty():
		stored_epoch = maxi(stored_epoch, int(web_ep.strip_edges()))
	if stored_epoch >= CLIENT_RESET_EPOCH:
		return

	# Tam sıfırlama: eski yerel dünya kayıtlarını, önbelleği ve eski oturumları temizle
	if DirAccess.dir_exists_absolute(WORLDS_DIR):
		var d := DirAccess.open(WORLDS_DIR)
		if d != null:
			d.list_dir_begin()
			var fname := d.get_next()
			while fname != "":
				if not d.current_is_dir():
					DirAccess.remove_absolute(ProjectSettings.globalize_path(WORLDS_DIR.path_join(fname)))
				fname = d.get_next()
			d.list_dir_end()
	for legacy_path in [META_FILE, "user://savegame.json", "user://auth_session.json"]:
		if FileAccess.file_exists(legacy_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(legacy_path))

	if OS.has_feature("web"):
		JavaScriptBridge.eval("""
(function(){
  try {
    var keys = [];
    for (var i = 0; i < window.localStorage.length; i++) {
      var k = window.localStorage.key(i);
      if (k && (k.indexOf('tvk_world_') === 0 || k === 'tvk_worlds_meta' || k === 'tvk_savegame_v1' || k === 'tvk_auth_session')) {
        keys.push(k);
      }
    }
    keys.forEach(function(k){ window.localStorage.removeItem(k); });
    if (typeof FS !== 'undefined' && FS.syncfs) { FS.syncfs(false, function(){}); }
  } catch(e) {}
})();
""", true)

	var auth := _find_autoload("AuthManager")
	if auth != null and auth.has_method("clear_session_only"):
		auth.clear_session_only()
	var gs := _find_game_state()
	if gs != null and gs.has_method("reset"):
		gs.reset()

	var wf := FileAccess.open(EPOCH_FILE, FileAccess.WRITE)
	if wf != null:
		wf.store_string(str(CLIENT_RESET_EPOCH))
		wf.close()
	_web_set(WEB_EPOCH_KEY, str(CLIENT_RESET_EPOCH))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		var gs = _find_game_state()
		if gs != null and gs.has_active_village():
			save_active_world()


func _on_building_progress_event(_a = null, _b = null, _c = null) -> void:
	if _is_applying_cloud_sync or _suppress_reset_save:
		return
	notify_local_mutation()


func _on_building_completed_event(_vid = -1, _key: String = "", _lvl: int = 0) -> void:
	if _is_applying_cloud_sync or _suppress_reset_save:
		return
	notify_local_mutation()
	var gs = _find_game_state()
	if gs != null and gs.has_active_village():
		_last_autosave_unix = int(Time.get_unix_time_from_system())
		save_active_world(true)


func _on_building_torndown_event(vid: int = -1, key: String = "") -> void:
	if _is_applying_cloud_sync or _suppress_reset_save:
		return
	notify_local_teardown(vid, key)
	var gs = _find_game_state()
	if gs != null and gs.has_active_village():
		_last_autosave_unix = int(Time.get_unix_time_from_system())
		save_active_world(true)


func _on_research_completed_event(_vid = -1, _key: String = "") -> void:
	if _is_applying_cloud_sync or _suppress_reset_save:
		return
	notify_local_mutation()
	var gs = _find_game_state()
	if gs != null and gs.has_active_village():
		_last_autosave_unix = int(Time.get_unix_time_from_system())
		save_active_world(true)


func _on_state_changed_autosave() -> void:
	if _is_applying_cloud_sync or _suppress_reset_save:
		return
	notify_local_mutation()
	var now := int(Time.get_unix_time_from_system())
	var gs = _find_game_state()
	if gs != null and gs.has_active_village():
		var force_cloud := (now - _last_autosave_unix >= 2)
		if force_cloud:
			_last_autosave_unix = now
		save_active_world(force_cloud)


func _cloud_enabled() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	return OS.has_feature("web") or OS.has_feature("ios") or OS.has_feature("android")


func _process(delta: float) -> void:
	if not _cloud_enabled() or _cloud_poll_in_flight:
		return
	var loop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return
	var net = loop.root.get_node_or_null("NetworkManager")
	if net == null or str(net.auth_token).is_empty():
		return
	_cloud_poll_accum += delta
	if _cloud_poll_accum < CLOUD_POLL_INTERVAL_SEC:
		return
	_cloud_poll_accum = 0.0
	var gs = _find_game_state()
	var has_active: bool = (gs != null and bool(gs.has_active_village()))
	if has_active and (_last_local_mutation_unix > _last_cloud_save_unix):
		save_active_world()
	elif net.has_method("pull_shared_world_from_cloud"):
		_cloud_poll_in_flight = true
		net.pull_shared_world_from_cloud(func(_ok: bool, _data: Dictionary):
			_cloud_poll_in_flight = false
		)


func cancel_pending_cloud_poll() -> void:
	_cloud_poll_in_flight = false
	_cloud_poll_accum = 0.0


func _web_set(key: String, val: String) -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("try{window.localStorage.setItem(" + JSON.stringify(key) + "," + JSON.stringify(val) + ");if(typeof FS!=='undefined'&&FS.syncfs){FS.syncfs(false,function(){});}}catch(e){}", true)


func _web_get(key: String) -> String:
	if not OS.has_feature("web"):
		return ""
	var res = JavaScriptBridge.eval("(function(){try{var v=window.localStorage.getItem(" + JSON.stringify(key) + ");return typeof v==='string'?v:'';}catch(e){return '';}})()", true)
	return str(res) if typeof(res) == TYPE_STRING else ""


func _norm_name(raw_name: String) -> String:
	var n := raw_name.strip_edges()
	while n.length() >= 10 and n.substr(0, 10).to_lower() == "lord lord ":
		n = n.substr(5).strip_edges()
	return n


func _matches_player(owner: String, target: String) -> bool:
	var a := _norm_name(owner).to_lower()
	var b := _norm_name(target).to_lower()
	return not b.is_empty() and a == b


func _ensure_directory() -> void:
	if not DirAccess.dir_exists_absolute(WORLDS_DIR):
		DirAccess.make_dir_recursive_absolute(WORLDS_DIR)


func _meta_exists() -> bool:
	if FileAccess.file_exists(META_FILE):
		return true
	return not _web_get(WEB_META_KEY).is_empty()


## Tüm dünyaları sıfırlar, Dünya 1'i 50 botla başlatır ve diğerlerini pasif yapar.
func reset_all_worlds() -> void:
	_ensure_directory()
	worlds_meta = []
	for i in range(1, WORLDS_COUNT + 1):
		var is_active := (i == 1)
		var w_meta := {
			"id": i,
			"name": "Dünya %d" % i,
			"is_active": is_active,
			"registered_real_players": 0,
			"max_real_players": MAX_REAL_PLAYERS_PER_WORLD,
			"bot_count": BOTS_PER_WORLD,
			"seed": BASE_SEED + i,
			"speed": 2.0,
			"unit_speed": 2.0,
			"starter_boost_days": 7,
		}
		worlds_meta.append(w_meta)

	_save_meta()

	# Dünya 1'i oluştur ve kaydet
	_create_and_save_world(1, BASE_SEED + 1, BOTS_PER_WORLD)
	current_world_id = 1


func _save_meta() -> void:
	var data := {
		"worlds": worlds_meta,
		"current_world_id": current_world_id,
		"updated_unix": int(Time.get_unix_time_from_system())
	}
	var file := FileAccess.open(META_FILE, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
	_web_set(WEB_META_KEY, JSON.stringify(data))


func _load_meta() -> void:
	if not _meta_exists():
		reset_all_worlds()
		return
	var text := ""
	if FileAccess.file_exists(META_FILE):
		text = FileAccess.get_file_as_string(META_FILE)
	if text.is_empty():
		text = _web_get(WEB_META_KEY)
		if not text.is_empty():
			var mf := FileAccess.open(META_FILE, FileAccess.WRITE)
			if mf != null:
				mf.store_string(text)
				mf.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		worlds_meta = parsed.get("worlds", [])
		current_world_id = int(parsed.get("current_world_id", 1))
	if worlds_meta.size() < WORLDS_COUNT:
		reset_all_worlds()


func get_world_file_path(world_id: int) -> String:
	return "%s/world_%d.json" % [WORLDS_DIR, world_id]


func get_worlds_meta() -> Array:
	if worlds_meta.is_empty():
		_load_meta()
	return worlds_meta


func get_world_meta(world_id: int) -> Dictionary:
	for w in worlds_meta:
		if int(w.get("id", -1)) == world_id:
			return w
	return {}


## Dünyanın diskteki (veya web localStorage'daki) kayıt dosyasını okur (varsa).
func load_world_dict(world_id: int) -> Dictionary:
	var path := get_world_file_path(world_id)
	var text := ""
	if FileAccess.file_exists(path):
		text = FileAccess.get_file_as_string(path)
	if text.is_empty():
		text = _web_get(WEB_WORLD_PREFIX + str(world_id))
		if not text.is_empty():
			_ensure_directory()
			var wf := FileAccess.open(path, FileAccess.WRITE)
			if wf != null:
				wf.store_string(text)
				wf.close()
	if text.is_empty():
		return {}
	var parsed = JSON.parse_string(text)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


## Dünyayı diske ve web localStorage'a kaydeder.
func save_world_dict(world_id: int, data: Dictionary) -> bool:
	_ensure_directory()
	var path := get_world_file_path(world_id)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("WorldManager: Dünya dosyası yazılamadı -> " + path)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	_web_set(WEB_WORLD_PREFIX + str(world_id), JSON.stringify(data))
	return true


## Bir dünyayı sıfırdan 50 botla oluşturur ve diske kaydeder.
func _create_and_save_world(world_id: int, seed_val: int, bot_count: int) -> Dictionary:
	var now := int(Time.get_unix_time_from_system())
	var gen_world: Dictionary = WorldGeneratorScript.generate(seed_val, bot_count, WorldGeneratorScript.SIZE, 0.0, 0.0)
	gen_world["created_unix"] = now
	gen_world["last_saved_unix"] = now
	gen_world["sim_now_unix"] = now
	gen_world["sim_time_seconds"] = 0.0
	gen_world["base_speed"] = 1.0
	gen_world["base_unit_speed"] = 1.0
	gen_world["starter_boost_days"] = 7
	gen_world["speed"] = 2.0
	gen_world["unit_speed"] = 2.0

	var alliances: Array = []

	var full_payload := {
		"world_id": world_id,
		"world_name": "Dünya %d" % world_id,
		"seed": seed_val,
		"created_unix": now,
		"last_saved_unix": now,
		"registered_real_players": [],
		"state": {
			"world": gen_world,
			"villages": gen_world.get("villages", []).duplicate(true),
			"queues": [],
			"movements": [],
			"reports": [],
			"messages": [],
			"alliances": alliances,
		}
	}

	save_world_dict(world_id, full_payload)
	return full_payload


## Oyuncunun bu dünyada yaşayan (fethedilmemiş) köyü var mı?
func has_player_village(world_id: int, player_name: String) -> bool:
	if player_name.strip_edges().is_empty():
		return false

	var gs = _find_game_state()
	if gs != null and gs.has_active_village() and current_world_id == world_id and int(gs.world.get("world_id", -1)) == world_id and _matches_player(str(gs.player.get("name", "")), player_name) and gs.villages != null and not gs.villages.is_empty():
		for v in gs.villages:
			if typeof(v) != TYPE_DICTIONARY:
				continue
			var v_dict: Dictionary = v
			if bool(v_dict.get("is_bot", false)) or bool(v_dict.get("is_barbarian", false)):
				continue
			if _matches_player(str(v_dict.get("owner", "")), player_name):
				return true

	var w_data := load_world_dict(world_id)
	if w_data.is_empty():
		return false
	var state: Dictionary = w_data.get("state", {})
	if _deduplicate_player_starter_villages(w_data):
		save_world_dict(world_id, w_data)
	var villages: Array = state.get("villages", [])
	for v in villages:
		if typeof(v) != TYPE_DICTIONARY:
			continue
		var v_dict: Dictionary = v
		if bool(v_dict.get("is_bot", false)) or bool(v_dict.get("is_barbarian", false)):
			continue
		var owner: String = str(v_dict.get("owner", ""))
		if _matches_player(owner, player_name):
			return true
	return false


## Oyuncu dünyada daha önce kayıt olmuş ama tüm köyleri gerçek bir fetihle kaybedilmiş mi?
func is_player_conquered(world_id: int, player_name: String) -> bool:
	var norm_p := _norm_name(player_name)
	if norm_p.is_empty():
		return false
	if has_player_village(world_id, norm_p):
		return false
	return not get_last_defeat_info(world_id, norm_p).is_empty()


func _world_has_player_village_in_dict(w_data: Dictionary, p_name: String) -> bool:
	if w_data.is_empty():
		return false
	var st: Dictionary = w_data.get("state", {}) if typeof(w_data.get("state")) == TYPE_DICTIONARY else {}
	var vills: Array = st.get("villages", []) if typeof(st.get("villages")) == TYPE_ARRAY else []
	for v in vills:
		if _is_real_player_village_dict(v) and _matches_player(str((v as Dictionary).get("owner", "")), p_name):
			return true
	return false


func _world_has_conquest_defeat_in_dict(w_data: Dictionary, p_name: String) -> bool:
	if w_data.is_empty() or _norm_name(p_name).is_empty():
		return false
	if _world_has_player_village_in_dict(w_data, p_name):
		return false
	var st: Dictionary = w_data.get("state", {}) if typeof(w_data.get("state")) == TYPE_DICTIONARY else {}
	var wd: Dictionary = st.get("world", {}) if typeof(st.get("world")) == TYPE_DICTIONARY else {}
	var profs: Dictionary = wd.get("player_profiles", {}) if typeof(wd.get("player_profiles")) == TYPE_DICTIONARY else {}
	for pk in profs.keys():
		if _matches_player(str(pk), p_name) and typeof(profs[pk]) == TYPE_DICTIONARY:
			var di = (profs[pk] as Dictionary).get("defeated_info", {})
			if typeof(di) == TYPE_DICTIONARY and not (di as Dictionary).is_empty():
				var c_str := str((di as Dictionary).get("conqueror", "")).strip_edges()
				if not c_str.is_empty() and not _matches_player(c_str, p_name):
					return true
	var reps: Array = st.get("reports", []) if typeof(st.get("reports")) == TYPE_ARRAY else []
	for r in reps:
		if typeof(r) != TYPE_DICTIONARY or str((r as Dictionary).get("type", "")) != "battle":
			continue
		var data: Dictionary = (r as Dictionary).get("data", {}) if typeof((r as Dictionary).get("data")) == TYPE_DICTIONARY else {}
		var atk_s := str(data.get("attacker_name", "")).strip_edges()
		if bool(data.get("conquered", false)) and _matches_player(str(data.get("defender_name", "")), p_name) and not atk_s.is_empty() and not _matches_player(atk_s, p_name):
			return true
	return false


## Oyuncunun en son hangi koordinatta ve kim tarafından fethedildiğini döndürür.
func get_last_defeat_info(world_id: int, player_name: String) -> Dictionary:
	var norm_p := _norm_name(player_name)
	if norm_p.is_empty():
		return {}
	if has_player_village(world_id, norm_p):
		return {}
	var w_data := load_world_dict(world_id)
	if w_data.is_empty():
		return {}
	var state: Dictionary = w_data.get("state", {}) if typeof(w_data.get("state")) == TYPE_DICTIONARY else {}
	var w_dict: Dictionary = state.get("world", {}) if typeof(state.get("world")) == TYPE_DICTIONARY else {}
	var profiles: Dictionary = w_dict.get("player_profiles", {}) if typeof(w_dict.get("player_profiles")) == TYPE_DICTIONARY else {}
	for pk in profiles.keys():
		if _matches_player(str(pk), norm_p) and typeof(profiles[pk]) == TYPE_DICTIONARY:
			var di = (profiles[pk] as Dictionary).get("defeated_info", {})
			if typeof(di) == TYPE_DICTIONARY and not (di as Dictionary).is_empty():
				var conq_str := str((di as Dictionary).get("conqueror", "")).strip_edges()
				if not conq_str.is_empty() and not _matches_player(conq_str, norm_p):
					return (di as Dictionary).duplicate(true)

	# Yedek: sunucu/dünya savaş raporlarından son fetih raporunu tara
	var reps: Array = state.get("reports", []) if typeof(state.get("reports")) == TYPE_ARRAY else []
	var latest_info := {}
	var latest_ts := -1
	for r in reps:
		if typeof(r) != TYPE_DICTIONARY:
			continue
		var rd: Dictionary = r
		if str(rd.get("type", "")) != "battle":
			continue
		var data: Dictionary = rd.get("data", {}) if typeof(rd.get("data")) == TYPE_DICTIONARY else {}
		if not bool(data.get("conquered", false)):
			continue
		var atk_name := str(data.get("attacker_name", "")).strip_edges()
		if _matches_player(str(data.get("defender_name", "")), norm_p) and not atk_name.is_empty() and not _matches_player(atk_name, norm_p):
			var r_ts := int(rd.get("unix", rd.get("created_unix", 0)))
			if r_ts >= latest_ts:
				latest_ts = r_ts
				var t_vid := int(data.get("target_village_id", -1))
				var vx := -1
				var vy := -1
				for v in state.get("villages", []):
					if typeof(v) == TYPE_DICTIONARY and int((v as Dictionary).get("id", -1)) == t_vid:
						vx = int((v as Dictionary).get("x", -1))
						vy = int((v as Dictionary).get("y", -1))
						break
				latest_info = {
					"conqueror": atk_name,
					"village_id": t_vid,
					"x": vx,
					"y": vy,
					"unix": r_ts,
				}
	return latest_info


## Tüm köyleri fethedilen oyuncuyu farklı bir lokasyonda sıfırdan başlatır.
func restart_after_conquest(world_id: int, player_name: String, target_x: int = -1, target_y: int = -1) -> bool:
	var norm_p := _norm_name(player_name)
	if norm_p.is_empty():
		norm_p = "Lord Gorkem"
	var def_info := get_last_defeat_info(world_id, norm_p)
	var prev_spot := Vector2i(int(def_info.get("x", -1)), int(def_info.get("y", -1)))

	var chosen_x := target_x
	var chosen_y := target_y
	if chosen_x < 1 or chosen_y < 1:
		var quadrants := [Vector2i(35, 35), Vector2i(165, 35), Vector2i(35, 165), Vector2i(165, 165)]
		if prev_spot.x >= 0 and prev_spot.y >= 0:
			var best_dist := -1.0
			var best_q: Vector2i = quadrants[0]
			for q in quadrants:
				var qv: Vector2i = q
				var d := Vector2(qv).distance_to(Vector2(prev_spot))
				if d > best_dist:
					best_dist = d
					best_q = qv
			chosen_x = best_q.x
			chosen_y = best_q.y
		else:
			var pick: Vector2i = quadrants[randi() % quadrants.size()]
			chosen_x = pick.x
			chosen_y = pick.y

	var ok := join_world(world_id, norm_p, chosen_x, chosen_y, prev_spot, true)
	if ok:
		suppress_auto_conquered_prompt = false
		var now := int(Time.get_unix_time_from_system())
		var gs = _find_game_state()
		if gs != null:
			gs.player["restarted_unix"] = now
			gs.player["tutorial_completed"] = false
			gs.player["tutorial_step"] = 0
			gs.player["tutorial_reward_claimed"] = false
			gs.player["quests"] = {"claimed": [], "stats": {}}
			var prof_w: Dictionary = gs.world.get("player_profiles", {}) if typeof(gs.world.get("player_profiles")) == TYPE_DICTIONARY else {}
			if prof_w.has(norm_p) and typeof(prof_w[norm_p]) == TYPE_DICTIONARY:
				(prof_w[norm_p] as Dictionary).erase("defeated_info")
		save_active_world()
		var sm = _find_autoload("SaveManager")
		if sm != null and sm.has_method("save_game"):
			sm.save_game()
		var loop = Engine.get_main_loop()
		if loop is SceneTree and (loop as SceneTree).root != null:
			ConqueredModalScript.dismiss((loop as SceneTree).root)
			var tm = _find_autoload("TutorialManager")
			if tm != null:
				tm.set("_current_step", 0)
				tm.set("_shown_step", -1)
				tm.set("_shown_substate", "")
				tm.set("_victory_reward_granted", false)
			var qm = _find_autoload("QuestManager")
			if qm != null and qm.has_method("refresh_quests"):
				qm.refresh_quests(true)
	return ok


## Oyuncunun bir dünyaya katılması (yeni köy açılması). Mevcut köyü varsa sıfırdan üzerine yazmaz!
func join_world(world_id: int, player_name: String, target_x: int = 100, target_y: int = 100, avoid_spot: Vector2i = Vector2i(-1, -1), allow_replace_existing: bool = false) -> bool:
	player_name = _norm_name(player_name)
	if player_name.is_empty():
		player_name = "Lord Gorkem"

	if not allow_replace_existing and has_player_village(world_id, player_name):
		return enter_world(world_id, player_name)

	var w_meta := get_world_meta(world_id)
	if w_meta.is_empty() and world_id == 1:
		_load_meta()
		w_meta = get_world_meta(world_id)
	if not bool(w_meta.get("is_active", false)) and world_id == 1:
		w_meta["is_active"] = true
	if not bool(w_meta.get("is_active", false)):
		push_error("WorldManager: Dünya %d şu an aktif değil!" % world_id)
		return false

	var w_data := load_world_dict(world_id)
	if w_data.is_empty():
		w_data = _create_and_save_world(world_id, int(w_meta.get("seed", BASE_SEED + world_id)), BOTS_PER_WORLD)

	var state: Dictionary = w_data.get("state", {})
	var world_dict: Dictionary = state.get("world", {})
	var tiles: Dictionary = world_dict.get("tiles", {})
	var villages_list: Array = state.get("villages", [])

	# Tek başlangıç köyü kuralı: Oyuncunun önceden kalma fethedilmemiş başlangıç köyleri varsa temizle
	var norm_join := _norm_name(player_name).to_lower()
	for i in range(villages_list.size() - 1, -1, -1):
		var ev = villages_list[i]
		if typeof(ev) != TYPE_DICTIONARY or int((ev as Dictionary).get("id", 0)) <= 0:
			villages_list.remove_at(i)
			continue
		var evd := ev as Dictionary
		if _is_real_player_village_dict(evd) and _norm_name(str(evd.get("owner", ""))).to_lower() == norm_join:
			villages_list.remove_at(i)

	# Seçilen bölgede (target_x, target_y) boş alan bul (önceki fethedilen koordinattan farklı)
	var search_tiles := tiles.duplicate()
	if avoid_spot.x >= 1 and avoid_spot.y >= 1:
		search_tiles[WorldGeneratorScript.tile_key(avoid_spot.x, avoid_spot.y)] = -999
	var free_spot: Vector2i = WorldGeneratorScript.find_free_spot(search_tiles, target_x, target_y, WorldGeneratorScript.SIZE)
	if free_spot.x < 0 or free_spot == avoid_spot:
		var alt_x := clampi(WorldGeneratorScript.SIZE + 1 - target_x, 10, WorldGeneratorScript.SIZE - 10)
		var alt_y := clampi(WorldGeneratorScript.SIZE + 1 - target_y, 10, WorldGeneratorScript.SIZE - 10)
		var alt_spot := WorldGeneratorScript.find_free_spot(search_tiles, alt_x, alt_y, WorldGeneratorScript.SIZE)
		free_spot = alt_spot if alt_spot.x >= 1 else Vector2i(alt_x, alt_y)

	var max_vid := 0
	for v in villages_list:
		var vid := int(v.get("id", 0))
		if vid > max_vid:
			max_vid = vid
	var player_vid: int = max_vid + 1
	var now := int(Time.get_unix_time_from_system())
	var player_v: Dictionary = VillageModelScript.create(player_vid, "Başkent", free_spot.x, free_spot.y, player_name, false)
	player_v["is_bot"] = false
	player_v["is_barbarian"] = false
	player_v["created_unix"] = now
	player_v["starter_boost_until_unix"] = now + (7 * 86400)
	player_v["protection_until"] = now + (15 * 86400)
	player_v["protection_until_unix"] = now + (15 * 86400)
	player_v["conquest_protection_until"] = now + (15 * 86400)
	player_v["conquest_protection_until_unix"] = now + (15 * 86400)

	villages_list.append(player_v)
	tiles[WorldGeneratorScript.tile_key(free_spot.x, free_spot.y)] = player_vid
	world_dict["tiles"] = tiles
	world_dict["villages"] = villages_list
	world_dict["base_speed"] = 1.0
	world_dict["base_unit_speed"] = 1.0
	world_dict["starter_boost_days"] = 7
	world_dict["player_joined_unix"] = now
	world_dict["starter_boost_until_unix"] = now + (7 * 86400)
	if typeof(world_dict.get("player_starter_boost")) != TYPE_DICTIONARY:
		world_dict["player_starter_boost"] = {}
	world_dict["player_starter_boost"][player_name] = {
		"created_unix": now,
		"starter_boost_until_unix": now + (7 * 86400),
	}
	world_dict["speed"] = 2.0
	world_dict["unit_speed"] = 2.0
	state["villages"] = villages_list
	state["world"] = world_dict
	_enforce_min_village_distance(w_data, player_vid)
	var placed_spot := Vector2i(int(player_v.get("x", free_spot.x)), int(player_v.get("y", free_spot.y)))
	state["active_village_id"] = player_vid
	_sync_player_profile_to_world(state)
	var loop_j = Engine.get_main_loop()
	var auth_j = loop_j.root.get_node_or_null("AuthManager") if loop_j is SceneTree else null
	var p_provider := str(auth_j.auth_provider) if (auth_j != null and bool(auth_j.is_logged_in)) else ""
	var p_auth_id := str(auth_j.user_id) if (auth_j != null and bool(auth_j.is_logged_in) and not str(auth_j.user_id).is_empty()) else ""
	var existing_profs: Dictionary = world_dict.get("player_profiles", {}) if typeof(world_dict.get("player_profiles")) == TYPE_DICTIONARY else {}
	var existing_prof: Dictionary = {}
	for pk in existing_profs.keys():
		if _matches_player(str(pk), player_name) and typeof(existing_profs[pk]) == TYPE_DICTIONARY:
			existing_prof = existing_profs[pk] as Dictionary
			break
	var gs_j := _find_game_state()
	var gs_same := (gs_j != null and _matches_player(str(gs_j.player.get("name", "")), player_name))
	var join_diamonds := 35
	if existing_prof.has("diamonds") and existing_prof.get("diamonds") != null:
		join_diamonds = maxi(0, int(existing_prof.get("diamonds", 35)))
	elif gs_same and gs_j.player.has("diamonds") and gs_j.player.get("diamonds") != null:
		join_diamonds = maxi(0, int(gs_j.player.get("diamonds", 35)))
	var join_scrolls: Dictionary = {}
	if typeof(existing_prof.get("scrolls")) == TYPE_DICTIONARY:
		join_scrolls = (existing_prof["scrolls"] as Dictionary).duplicate(true)
	elif gs_same and typeof(gs_j.player.get("scrolls")) == TYPE_DICTIONARY:
		join_scrolls = (gs_j.player["scrolls"] as Dictionary).duplicate(true)

	state["player"] = {
		"id": 1,
		"auth_id": p_auth_id,
		"provider": p_provider,
		"name": player_name,
		"points": int(player_v.get("points", 110)),
		"created_unix": now,
		"starter_boost_until_unix": now + (7 * 86400),
		"protection_until_unix": player_v["protection_until_unix"],
		"conquest_protection_until_unix": player_v["conquest_protection_until_unix"],
		"tutorial_completed": false,
		"tutorial_skipped": false,
		"tutorial_step": 0,
		"quests": {"claimed": [], "stats": {}},
		"gold_armour": 0,
		"diamonds": join_diamonds,
		"scrolls": join_scrolls,
		"premium": false,
	}
	_sync_player_profile_to_world(state)
	_sync_game_config_speed(state, now)

	# Gerçek oyuncu kaydı ve kapasite kontrolü
	var reg_list: Array = w_data.get("registered_real_players", [])
	if not (player_name in reg_list):
		reg_list.append(player_name)
		w_data["registered_real_players"] = reg_list
		w_meta["registered_real_players"] = reg_list.size()
		# Kapasite kontrolü: 100 gerçek oyuncu olduysa sıradaki dünyayı aç!
		if reg_list.size() >= MAX_REAL_PLAYERS_PER_WORLD:
			_unlock_next_world(world_id + 1)
		_save_meta()

	# Karşılama mesajı (Sadece ilk girişte tek bir kez, ittifak daveti olmadan)
	var msgs: Array = state.get("messages", [])
	var already_welcomed := false
	for m in msgs:
		if typeof(m) == TYPE_DICTIONARY and _matches_player(str(m.get("to", m.get("to_name", ""))), player_name) and _is_welcome_message_dict(m as Dictionary):
			already_welcomed = true
			break
	if not already_welcomed:
		msgs.append({
			"id": now * 1000 + 1,
			"from": "Taht ve Kılıç Konseyi",
			"to": player_name,
			"subject": "👑 Dünya %d'ye Hoş Geldiniz, Sayın Lord" % world_id,
			"body": "Selamlar Sayın %s,\n\nDünya %d topraklarına hoş geldiniz! 15 günlük fetih korumanız aktif durumdadır. Bu süre zarfında köylerinizi geliştirebilir ve ordunuzu kurabilirsiniz.\n\nKılıcınız keskin, krallığınız daim olsun.\n\nSaygılarımızla,\nTaht ve Kılıç Konseyi" % [player_name, world_id],
			"created_unix": now,
			"read": false
		})
		state["messages"] = msgs

	w_data["last_saved_unix"] = now
	save_world_dict(world_id, w_data)

	# GameState yüklemesi
	current_world_id = world_id
	_save_meta()
	_apply_to_game_state(w_data, player_name, player_vid)
	save_active_world()
	_last_local_mutation_unix = now
	var sm = Engine.get_main_loop().root.get_node_or_null("SaveManager") if Engine.get_main_loop() is SceneTree else null
	if sm != null and sm.has_method("save_game"):
		sm.save_game()
	if _cloud_enabled() and Engine.get_main_loop() is SceneTree:
		var net = Engine.get_main_loop().root.get_node_or_null("NetworkManager")
		if net != null and not str(net.auth_token).is_empty():
			net.api_join_world(world_id, placed_spot.x, placed_spot.y, Callable())
			_last_cloud_save_unix = now
			net.save_state_to_cloud(net.auth_token, w_data)
	return true


## Dünyaya devam et (var olan köyü ile oyuna bağlanma ve çevrimdışı telafi).
func enter_world(world_id: int, player_name: String) -> bool:
	player_name = _norm_name(player_name)
	if player_name.is_empty():
		player_name = "Lord Gorkem"

	var w_data := load_world_dict(world_id)
	if w_data.is_empty():
		return false

	var state: Dictionary = w_data.get("state", {})
	if _deduplicate_player_starter_villages(w_data):
		save_world_dict(world_id, w_data)
	var villages: Array = state.get("villages", [])

	# Oyuncunun aktif veya birincil köyünü bul (çoklu köy fethi sonrası seçili köy korunur)
	var profiles: Dictionary = state.get("world", {}).get("player_profiles", {}) if typeof(state.get("world")) == TYPE_DICTIONARY else {}
	var profile_active_id := -1
	for pk in profiles.keys():
		if _matches_player(str(pk), player_name) and typeof(profiles[pk]) == TYPE_DICTIONARY:
			profile_active_id = int((profiles[pk] as Dictionary).get("active_village_id", -1))
			break
	var saved_active_id := profile_active_id if profile_active_id > 0 else int(state.get("active_village_id", -1))
	var first_vid := -1
	var player_vid := -1
	for v in villages:
		if typeof(v) == TYPE_DICTIONARY:
			var vd: Dictionary = v
			if not bool(vd.get("is_bot", false)) and not bool(vd.get("is_barbarian", false)):
				if _matches_player(str(vd.get("owner", "")), player_name):
					var vid := int(vd.get("id", -1))
					if first_vid < 0:
						first_vid = vid
					if vid == saved_active_id:
						player_vid = vid
						break
	if player_vid < 0:
		player_vid = first_vid

	if player_vid < 0:
		return false

	var now := int(Time.get_unix_time_from_system())
	_ensure_starter_boost(state, int(w_data.get("created_unix", now)), now, player_name)
	_sync_game_config_speed(state, now)

	if _enforce_min_village_distance(w_data, player_vid):
		save_world_dict(world_id, w_data)

	current_world_id = world_id
	_save_meta()
	var saved_unix := int(w_data.get("last_saved_unix", 0))
	_apply_to_game_state(w_data, player_name, player_vid)

	# Offline telafi
	var sm = Engine.get_main_loop().root.get_node_or_null("SaveManager") if Engine.get_main_loop() is SceneTree else null
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if sm != null and gs != null:
		sm._apply_offline_catchup(gs, saved_unix)
		save_active_world()
		if sm.has_method("save_game"):
			sm.save_game()

	return true


func _sync_save_fallback_to_world() -> void:
	var loop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return
	var sm = loop.root.get_node_or_null("SaveManager")
	if sm == null or not sm.has_method("_read_raw_save_json"):
		return
	var raw: String = sm._read_raw_save_json()
	if raw.is_empty():
		return
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var saved_state: Dictionary = parsed.get("state", {})
	var saved_villages: Array = saved_state.get("villages", [])
	var has_human := false
	for v in saved_villages:
		if typeof(v) == TYPE_DICTIONARY and not bool(v.get("is_bot", false)) and not bool(v.get("is_barbarian", false)):
			has_human = true
			break
	if not has_human:
		return
	var w_id := int(saved_state.get("world", {}).get("world_id", current_world_id))
	if w_id < 1 or w_id > WORLDS_COUNT:
		w_id = 1
	var w_data := load_world_dict(w_id)
	var existing_villages: Array = w_data.get("state", {}).get("villages", []) if not w_data.is_empty() else []
	for v in existing_villages:
		if typeof(v) == TYPE_DICTIONARY and not bool(v.get("is_bot", false)) and not bool(v.get("is_barbarian", false)):
			return # Dünya dosyasında zaten gerçek oyuncu köyü var
	var payload := {
		"world_id": w_id,
		"world_name": "Dünya %d" % w_id,
		"seed": BASE_SEED + w_id,
		"created_unix": int(parsed.get("savedAtUnix", Time.get_unix_time_from_system())),
		"last_saved_unix": int(parsed.get("savedAtUnix", Time.get_unix_time_from_system())),
		"registered_real_players": [],
		"state": saved_state,
	}
	save_world_dict(w_id, payload)


## Sıradaki dünyayı aktifleştirir ve 50 botla başlatır.
func _unlock_next_world(next_id: int) -> void:
	if next_id > WORLDS_COUNT:
		return
	for w in worlds_meta:
		if int(w.get("id", -1)) == next_id:
			if not bool(w.get("is_active", false)):
				w["is_active"] = true
				_create_and_save_world(next_id, int(w.get("seed", BASE_SEED + next_id)), BOTS_PER_WORLD)
				print("[WorldManager] 🎉 Yeni Dünya Açıldı: Dünya %d!" % next_id)
			break
	_save_meta()


## İlk 7 gün 2x hız bonusunu oyuncu bazlı olarak dünya/oyuncu/köy verisinde garanti eder.
func _ensure_starter_boost(state: Dictionary, fallback_created_unix: int = 0, now_unix: int = 0, player_name: String = "") -> void:
	if typeof(state) != TYPE_DICTIONARY:
		return
	var now := now_unix if now_unix > 0 else int(Time.get_unix_time_from_system())
	if typeof(state.get("world")) != TYPE_DICTIONARY:
		state["world"] = {}
	var w_dict: Dictionary = state["world"]
	if typeof(state.get("player")) != TYPE_DICTIONARY:
		state["player"] = {}
	var p_dict: Dictionary = state["player"]

	var p_name := _norm_name(player_name if not player_name.is_empty() else str(p_dict.get("name", "")))
	var boost_until := 0
	var created := 0

	# 1) Oyuncu bazlı haritadan kontrol et.
	if not p_name.is_empty() and typeof(w_dict.get("player_starter_boost")) == TYPE_DICTIONARY:
		var psb: Dictionary = w_dict["player_starter_boost"]
		for k in psb.keys():
			if _matches_player(str(k), p_name) and typeof(psb[k]) == TYPE_DICTIONARY:
				var rec: Dictionary = psb[k]
				var rb := int(rec.get("starter_boost_until_unix", 0))
				var rc := int(rec.get("created_unix", 0))
				if rb <= 0 and rc > 0:
					rb = rc + (7 * 86400)
				if rb > 0:
					boost_until = rb
					created = rc if rc > 0 else rb - (7 * 86400)
					break

	# 2) Oyuncunun köy verilerinden kontrol et (ilk veya en güncel başlangıç damgası).
	var villages_val = state.get("villages", [])
	if boost_until <= 0 and not p_name.is_empty() and typeof(villages_val) == TYPE_ARRAY:
		for v in villages_val:
			if typeof(v) != TYPE_DICTIONARY:
				continue
			var vd: Dictionary = v
			if bool(vd.get("is_bot", false)) or bool(vd.get("is_barbarian", false)):
				continue
			if not _matches_player(str(vd.get("owner", "")), p_name):
				continue
			var vb := int(vd.get("starter_boost_until_unix", 0))
			var vc := int(vd.get("created_unix", 0))
			var vp := int(vd.get("protection_until_unix", 0))
			if vb > 0:
				boost_until = vb
				created = vc if vc > 0 else (vp - (15 * 86400) if vp > (15 * 86400) else vb - (7 * 86400))
				break
			elif vc > 0:
				created = vc
				boost_until = vc + (7 * 86400)
				break
			elif vp > (15 * 86400):
				created = vp - (15 * 86400)
				boost_until = created + (7 * 86400)
				break

	# 3) Aktif player sözlüğü aynı oyuncuya aitse buradan kontrol et.
	if boost_until <= 0 and (p_name.is_empty() or _matches_player(str(p_dict.get("name", "")), p_name)):
		var pb := int(p_dict.get("starter_boost_until_unix", 0))
		var pc := int(p_dict.get("created_unix", 0))
		if pb > 0:
			boost_until = pb
			created = pc if pc > 0 else pb - (7 * 86400)
		elif pc > 0:
			created = pc
			boost_until = pc + (7 * 86400)

	# 4) Yalnızca hiçbir oyuncu verisi yoksa dünya genel yedeğine düş.
	if boost_until <= 0:
		boost_until = int(w_dict.get("starter_boost_until_unix", 0))
		if boost_until <= 0:
			created = int(w_dict.get("player_joined_unix", w_dict.get("created_unix", fallback_created_unix)))
			if created <= 0:
				created = now
			boost_until = created + (7 * 86400)
	if created <= 0:
		created = boost_until - (7 * 86400)

	if not p_name.is_empty():
		if typeof(w_dict.get("player_starter_boost")) != TYPE_DICTIONARY:
			w_dict["player_starter_boost"] = {}
		w_dict["player_starter_boost"][p_name] = {
			"created_unix": created,
			"starter_boost_until_unix": boost_until,
		}
		if typeof(villages_val) == TYPE_ARRAY:
			for v in villages_val:
				if typeof(v) == TYPE_DICTIONARY:
					var vd: Dictionary = v
					if not bool(vd.get("is_bot", false)) and not bool(vd.get("is_barbarian", false)) and _matches_player(str(vd.get("owner", "")), p_name):
						if int(vd.get("created_unix", 0)) <= 0:
							vd["created_unix"] = created
						if int(vd.get("starter_boost_until_unix", 0)) <= 0:
							vd["starter_boost_until_unix"] = boost_until

	w_dict["player_joined_unix"] = created
	w_dict["starter_boost_until_unix"] = boost_until
	w_dict["starter_boost_days"] = 7
	if not w_dict.has("base_speed"):
		w_dict["base_speed"] = 1.0
	if not w_dict.has("base_unit_speed"):
		w_dict["base_unit_speed"] = 1.0
	p_dict["created_unix"] = created
	p_dict["starter_boost_until_unix"] = boost_until
	var is_active := now < boost_until
	w_dict["speed"] = 2.0 if is_active else float(w_dict.get("base_speed", 1.0))
	w_dict["unit_speed"] = 2.0 if is_active else float(w_dict.get("base_unit_speed", 1.0))


func _find_autoload(node_name: String) -> Node:
	if is_inside_tree() and get_tree() != null and get_tree().root != null:
		var t_node := get_tree().root.get_node_or_null(node_name)
		if t_node != null:
			return t_node
	var loop = Engine.get_main_loop()
	if loop is SceneTree and (loop as SceneTree).root != null:
		var l_node := (loop as SceneTree).root.get_node_or_null(node_name)
		if l_node != null:
			return l_node
	if get_parent() != null:
		return get_parent().get_node_or_null(node_name)
	return null


## GameConfig singleton'unu dünya meta verisinden hızıyla eşitler.
func _sync_game_config_speed(state: Dictionary, now_unix: int = 0) -> void:
	var gc := _find_autoload("GameConfig")
	if gc == null:
		return
	var w_dict: Dictionary = state.get("world", {}) if typeof(state.get("world")) == TYPE_DICTIONARY else {}
	if gc.has_method("sync_from_world"):
		gc.sync_from_world(w_dict, now_unix)


static func _report_sig_str(r: Dictionary) -> String:
	var rdata: Dictionary = r.get("data", {}) if typeof(r.get("data")) == TYPE_DICTIONARY else {}
	return "%s:%d:%d:%d:%d" % [
		str(r.get("type", "")),
		int(r.get("village_id", 0)),
		int(r.get("unix", r.get("created_unix", 0))),
		int(rdata.get("target_village_id", 0)),
		int(rdata.get("from_village_id", 0)),
	]


static func _norm_static_name(raw_name: String) -> String:
	var n := raw_name.strip_edges()
	while n.length() >= 10 and n.substr(0, 10).to_lower() == "lord lord ":
		n = n.substr(5).strip_edges()
	return n


static func _is_welcome_message_dict(m: Dictionary) -> bool:
	var subj := str(m.get("subject", "")).strip_edges().to_lower()
	var frm := str(m.get("from", m.get("from_name", ""))).strip_edges().to_lower()
	return (subj.contains("hoş geldiniz") or subj.contains("hos geldiniz")) and (frm.contains("konsey") or frm.contains("taht ve kılıç") or frm.contains("taht ve kilic"))


static func _message_sig_str(m: Dictionary) -> String:
	var to_n := _norm_static_name(str(m.get("to", m.get("to_name", "")))).to_lower()
	if _is_welcome_message_dict(m):
		return "welcome:" + to_n
	var from_n := _norm_static_name(str(m.get("from", m.get("from_name", "")))).to_lower()
	var subj := str(m.get("subject", "")).strip_edges().to_lower()
	var ts := int(m.get("created_unix", 0))
	return "%s|%s|%s|%d" % [from_n, to_n, subj, ts]


func _merge_string_sig_arrays(a_val, b_val, max_len: int = 400) -> Array:
	var seen: Dictionary = {}
	var out: Array = []
	for src in [a_val, b_val]:
		if typeof(src) == TYPE_ARRAY:
			for item in (src as Array):
				var s := str(item)
				if not s.is_empty() and not seen.has(s):
					seen[s] = true
					out.append(s)
	if out.size() > max_len:
		out = out.slice(out.size() - max_len)
	return out


func _merge_quests_dict(base_q: Dictionary, inc_q: Dictionary) -> Dictionary:
	var claimed := _merge_string_sig_arrays(base_q.get("claimed", []), inc_q.get("claimed", []), 200)
	var b_stats: Dictionary = base_q.get("stats", {}) if typeof(base_q.get("stats")) == TYPE_DICTIONARY else {}
	var i_stats: Dictionary = inc_q.get("stats", {}) if typeof(inc_q.get("stats")) == TYPE_DICTIONARY else {}
	var merged_stats: Dictionary = b_stats.duplicate(true)
	for sk in i_stats.keys():
		if str(sk) == "counted_movement_ids":
			merged_stats[sk] = _merge_string_sig_arrays(b_stats.get(sk, []), i_stats.get(sk, []), 200)
		else:
			var iv = i_stats[sk]
			if typeof(iv) == TYPE_INT or typeof(iv) == TYPE_FLOAT:
				var bv = b_stats.get(sk, 0)
				var bnum: int = int(bv) if (typeof(bv) == TYPE_INT or typeof(bv) == TYPE_FLOAT) else 0
				merged_stats[sk] = maxi(bnum, int(iv))
			elif not merged_stats.has(sk):
				merged_stats[sk] = iv.duplicate(true) if (typeof(iv) == TYPE_DICTIONARY or typeof(iv) == TYPE_ARRAY) else iv
	return {"claimed": claimed, "stats": merged_stats}


func _merge_profile_dicts(base_p: Dictionary, inc_p: Dictionary, prefer_inc_read: bool = true) -> Dictionary:
	if base_p.is_empty():
		return inc_p.duplicate(true)
	if inc_p.is_empty():
		return base_p.duplicate(true)
	var b_restart := int(base_p.get("restarted_unix", 0))
	var i_restart := int(inc_p.get("restarted_unix", 0))
	if i_restart > b_restart and i_restart > 0:
		var r_out := inc_p.duplicate(true)
		r_out["deleted_report_sigs"] = _merge_string_sig_arrays(base_p.get("deleted_report_sigs", []), inc_p.get("deleted_report_sigs", []))
		r_out["deleted_message_sigs"] = _merge_string_sig_arrays(base_p.get("deleted_message_sigs", []), inc_p.get("deleted_message_sigs", []))
		r_out["read_message_sigs"] = _merge_string_sig_arrays(base_p.get("read_message_sigs", []), inc_p.get("read_message_sigs", []))
		return r_out

	var out := base_p.duplicate(true)
	for k in inc_p.keys():
		var v = inc_p[k]
		if typeof(v) == TYPE_STRING and (v as String).is_empty() and out.has(k):
			continue
		out[k] = v.duplicate(true) if (typeof(v) == TYPE_DICTIONARY or typeof(v) == TYPE_ARRAY) else v
	out["restarted_unix"] = maxi(b_restart, i_restart)
	out["tutorial_completed"] = bool(base_p.get("tutorial_completed", false)) or bool(inc_p.get("tutorial_completed", false))
	out["tutorial_skipped"] = bool(base_p.get("tutorial_skipped", false)) or bool(inc_p.get("tutorial_skipped", false))
	out["tutorial_reward_claimed"] = bool(base_p.get("tutorial_reward_claimed", false)) or bool(inc_p.get("tutorial_reward_claimed", false))
	out["tutorial_step"] = maxi(int(base_p.get("tutorial_step", 0)), int(inc_p.get("tutorial_step", 0)))
	var bq: Dictionary = base_p.get("quests", {}) if typeof(base_p.get("quests")) == TYPE_DICTIONARY else {}
	var iq: Dictionary = inc_p.get("quests", {}) if typeof(inc_p.get("quests")) == TYPE_DICTIONARY else {}
	out["quests"] = _merge_quests_dict(bq, iq)
	out["deleted_report_sigs"] = _merge_string_sig_arrays(base_p.get("deleted_report_sigs", []), inc_p.get("deleted_report_sigs", []))
	var merged_reads := _merge_string_sig_arrays(base_p.get("read_report_sigs", []), inc_p.get("read_report_sigs", []))
	var unread_toggled := _merge_string_sig_arrays(base_p.get("unread_toggled_sigs", []), inc_p.get("unread_toggled_sigs", []), 200)
	var ut_set: Dictionary = {}
	var active_reads: Variant = inc_p.get("read_report_sigs", []) if prefer_inc_read else base_p.get("read_report_sigs", [])
	var ar_set: Dictionary = {}
	if typeof(active_reads) == TYPE_ARRAY:
		for rs in (active_reads as Array):
			ar_set[str(rs)] = true
	for us in unread_toggled:
		if not ar_set.has(str(us)):
			ut_set[str(us)] = true
	var final_reads: Array = []
	for rs2 in merged_reads:
		if not ut_set.has(str(rs2)):
			final_reads.append(str(rs2))
	var final_unreads: Array = []
	for us2 in unread_toggled:
		if not ar_set.has(str(us2)):
			final_unreads.append(str(us2))
	out["read_report_sigs"] = final_reads
	out["unread_toggled_sigs"] = final_unreads
	out["read_message_sigs"] = _merge_string_sig_arrays(base_p.get("read_message_sigs", []), inc_p.get("read_message_sigs", []))
	out["deleted_message_sigs"] = _merge_string_sig_arrays(base_p.get("deleted_message_sigs", []), inc_p.get("deleted_message_sigs", []))
	return out


func _apply_report_sigs_to_state(state_dict: Dictionary, player_name: String) -> void:
	if typeof(state_dict) != TYPE_DICTIONARY:
		return
	var p_dict: Dictionary = state_dict.get("player", {}) if typeof(state_dict.get("player")) == TYPE_DICTIONARY else {}
	var w_dict: Dictionary = state_dict.get("world", {}) if typeof(state_dict.get("world")) == TYPE_DICTIONARY else {}
	var profs: Dictionary = w_dict.get("player_profiles", {}) if typeof(w_dict.get("player_profiles")) == TYPE_DICTIONARY else {}
	var match_prof: Dictionary = {}
	for k in profs.keys():
		if _matches_player(str(k), player_name) and typeof(profs[k]) == TYPE_DICTIONARY:
			match_prof = profs[k] as Dictionary
			break
	var del_arr := _merge_string_sig_arrays(match_prof.get("deleted_report_sigs", []), p_dict.get("deleted_report_sigs", []))
	var read_arr := _merge_string_sig_arrays(match_prof.get("read_report_sigs", []), p_dict.get("read_report_sigs", []))
	var del_set: Dictionary = {}
	for ds in del_arr:
		del_set[str(ds)] = true
	var read_set: Dictionary = {}
	for rs in read_arr:
		read_set[str(rs)] = true
	if typeof(state_dict.get("reports")) == TYPE_ARRAY:
		var kept: Array = []
		for r in (state_dict["reports"] as Array):
			if typeof(r) != TYPE_DICTIONARY:
				continue
			var rd := r as Dictionary
			var rsig := _report_sig_str(rd)
			if del_set.has(rsig):
				continue
			if read_set.has(rsig):
				rd["unread"] = false
			kept.append(rd)
		state_dict["reports"] = kept
	_apply_message_sigs_to_state(state_dict, player_name)


func _apply_message_sigs_to_state(state_dict: Dictionary, player_name: String) -> void:
	if typeof(state_dict) != TYPE_DICTIONARY:
		return
	var p_dict: Dictionary = state_dict.get("player", {}) if typeof(state_dict.get("player")) == TYPE_DICTIONARY else {}
	var w_dict: Dictionary = state_dict.get("world", {}) if typeof(state_dict.get("world")) == TYPE_DICTIONARY else {}
	var profs: Dictionary = w_dict.get("player_profiles", {}) if typeof(w_dict.get("player_profiles")) == TYPE_DICTIONARY else {}
	var match_prof: Dictionary = {}
	for k in profs.keys():
		if _matches_player(str(k), player_name) and typeof(profs[k]) == TYPE_DICTIONARY:
			match_prof = profs[k] as Dictionary
			break
	var del_arr := _merge_string_sig_arrays(match_prof.get("deleted_message_sigs", []), p_dict.get("deleted_message_sigs", []))
	var read_arr := _merge_string_sig_arrays(match_prof.get("read_message_sigs", []), p_dict.get("read_message_sigs", []))
	var del_set: Dictionary = {}
	for ds in del_arr:
		del_set[str(ds)] = true
	var read_set: Dictionary = {}
	for rs in read_arr:
		read_set[str(rs)] = true
	if typeof(state_dict.get("messages")) == TYPE_ARRAY:
		var kept: Array = []
		var seen: Dictionary = {}
		for m in (state_dict["messages"] as Array):
			if typeof(m) != TYPE_DICTIONARY:
				continue
			var md := (m as Dictionary).duplicate(true)
			var to_n := str(md.get("to", md.get("to_name", ""))).strip_edges()
			var from_n := str(md.get("from", md.get("from_name", ""))).strip_edges()
			var is_own := _matches_player(to_n, player_name) or _matches_player(from_n, player_name)
			var msig := _message_sig_str(md)
			if is_own and del_set.has(msig):
				continue
			if is_own and read_set.has(msig):
				md["read"] = true
			if seen.has(msig):
				var prev := kept[int(seen[msig])] as Dictionary
				if bool(md.get("read", false)) or (is_own and read_set.has(msig)):
					prev["read"] = true
				continue
			seen[msig] = kept.size()
			kept.append(md)
		state_dict["messages"] = kept


## Oyuncu profilini (tutorial, görevler, altın zırh, seçili köy vb.) dünya haritasına yazar.
func _sync_player_profile_to_world(state_dict: Dictionary) -> void:
	if typeof(state_dict) != TYPE_DICTIONARY:
		return
	var p_raw = state_dict.get("player", {})
	if typeof(p_raw) != TYPE_DICTIONARY or (p_raw as Dictionary).is_empty():
		return
	var p: Dictionary = p_raw
	var p_name := _norm_name(str(p.get("name", "")))
	if p_name.is_empty():
		return
	if typeof(state_dict.get("world")) != TYPE_DICTIONARY:
		state_dict["world"] = {}
	var w_dict: Dictionary = state_dict["world"]
	if typeof(w_dict.get("player_profiles")) != TYPE_DICTIONARY:
		w_dict["player_profiles"] = {}
	var profiles: Dictionary = w_dict["player_profiles"]
	var existing_prof: Dictionary = {}
	for k in profiles.keys():
		if _matches_player(str(k), p_name) and typeof(profiles[k]) == TYPE_DICTIONARY:
			existing_prof = profiles[k] as Dictionary
			break
	var quests_copy: Dictionary = {"claimed": [], "stats": {}}
	if typeof(p.get("quests")) == TYPE_DICTIONARY:
		quests_copy = (p["quests"] as Dictionary).duplicate(true)
	var scrolls_copy: Dictionary = {}
	if typeof(p.get("scrolls")) == TYPE_DICTIONARY:
		scrolls_copy = (p["scrolls"] as Dictionary).duplicate(true)
	elif typeof(existing_prof.get("scrolls")) == TYPE_DICTIONARY:
		scrolls_copy = (existing_prof["scrolls"] as Dictionary).duplicate(true)
	var p_diamonds := maxi(0, int(p.get("diamonds", 35))) if (p.has("diamonds") and p.get("diamonds") != null) else (maxi(0, int(existing_prof.get("diamonds", 35))) if existing_prof.has("diamonds") and existing_prof.get("diamonds") != null else 35)
	var read_sigs := _merge_string_sig_arrays(p.get("read_report_sigs", []) if p.has("read_report_sigs") else existing_prof.get("read_report_sigs", []), [])
	var del_sigs := _merge_string_sig_arrays(existing_prof.get("deleted_report_sigs", []), p.get("deleted_report_sigs", []))
	var read_msg_sigs := _merge_string_sig_arrays(existing_prof.get("read_message_sigs", []), p.get("read_message_sigs", []))
	var del_msg_sigs := _merge_string_sig_arrays(existing_prof.get("deleted_message_sigs", []), p.get("deleted_message_sigs", []))
	var inc_prof := {
		"name": p_name,
		"provider": str(p.get("provider", existing_prof.get("provider", ""))),
		"auth_id": str(p.get("auth_id", existing_prof.get("auth_id", ""))),
		"points": int(p.get("points", 0)),
		"created_unix": int(p.get("created_unix", 0)),
		"starter_boost_until_unix": int(p.get("starter_boost_until_unix", 0)),
		"protection_until_unix": int(p.get("protection_until_unix", 0)),
		"conquest_protection_until_unix": int(p.get("conquest_protection_until_unix", 0)),
		"restarted_unix": int(p.get("restarted_unix", existing_prof.get("restarted_unix", 0))),
		"tutorial_completed": bool(p.get("tutorial_completed", false)),
		"tutorial_skipped": bool(p.get("tutorial_skipped", false)),
		"tutorial_step": int(p.get("tutorial_step", 0)),
		"tutorial_reward_claimed": bool(p.get("tutorial_reward_claimed", false)),
		"quests": quests_copy,
		"gold_armour": int(p.get("gold_armour", 0)),
		"diamonds": p_diamonds,
		"scrolls": scrolls_copy,
		"read_report_sigs": read_sigs,
		"deleted_report_sigs": del_sigs,
		"unread_toggled_sigs": _merge_string_sig_arrays(p.get("unread_toggled_sigs", []) if p.has("unread_toggled_sigs") else existing_prof.get("unread_toggled_sigs", []), [], 200),
		"read_message_sigs": read_msg_sigs,
		"deleted_message_sigs": del_msg_sigs,
		"active_village_id": int(state_dict.get("active_village_id", -1)),
	}
	var merged_prof := _merge_profile_dicts(existing_prof, inc_prof, p.has("read_report_sigs"))
	profiles[p_name] = merged_prof
	p["tutorial_completed"] = bool(merged_prof.get("tutorial_completed", false))
	p["tutorial_skipped"] = bool(merged_prof.get("tutorial_skipped", false))
	p["tutorial_reward_claimed"] = bool(merged_prof.get("tutorial_reward_claimed", false))
	p["tutorial_step"] = int(merged_prof.get("tutorial_step", 0))
	p["quests"] = (merged_prof["quests"] as Dictionary).duplicate(true)
	p["read_report_sigs"] = (merged_prof.get("read_report_sigs", []) as Array).duplicate(true)
	p["deleted_report_sigs"] = (merged_prof.get("deleted_report_sigs", []) as Array).duplicate(true)
	p["unread_toggled_sigs"] = (merged_prof.get("unread_toggled_sigs", []) as Array).duplicate(true)
	p["read_message_sigs"] = (merged_prof.get("read_message_sigs", []) as Array).duplicate(true)
	p["deleted_message_sigs"] = (merged_prof.get("deleted_message_sigs", []) as Array).duplicate(true)


## İlgili oyuncunun profilini dünya haritasından `state_dict["player"]` içine yükler.
func _restore_player_profile_from_world(state_dict: Dictionary, player_name: String) -> void:
	if typeof(state_dict) != TYPE_DICTIONARY:
		return
	var norm_p := _norm_name(player_name)
	if norm_p.is_empty():
		return
	var w_dict: Dictionary = state_dict.get("world", {}) if typeof(state_dict.get("world")) == TYPE_DICTIONARY else {}
	var profiles: Dictionary = w_dict.get("player_profiles", {}) if typeof(w_dict.get("player_profiles")) == TYPE_DICTIONARY else {}
	var found: Dictionary = {}
	for k in profiles.keys():
		if _matches_player(str(k), norm_p) and typeof(profiles[k]) == TYPE_DICTIONARY:
			found = (profiles[k] as Dictionary).duplicate(true)
			break
	var cur_p: Dictionary = state_dict.get("player", {}) if typeof(state_dict.get("player")) == TYPE_DICTIONARY else {}
	var cur_same := _matches_player(str(cur_p.get("name", "")), norm_p)
	if found.is_empty() and cur_same:
		found = cur_p.duplicate(true)
	var boost_rec: Dictionary = {}
	var psb: Dictionary = w_dict.get("player_starter_boost", {}) if typeof(w_dict.get("player_starter_boost")) == TYPE_DICTIONARY else {}
	for bk in psb.keys():
		if _matches_player(str(bk), norm_p) and typeof(psb[bk]) == TYPE_DICTIONARY:
			boost_rec = psb[bk]
			break
	var q_dict: Dictionary = {"claimed": [], "stats": {}}
	if typeof(found.get("quests")) == TYPE_DICTIONARY:
		q_dict = (found["quests"] as Dictionary).duplicate(true)
	var r_scrolls: Dictionary = {}
	if typeof(found.get("scrolls")) == TYPE_DICTIONARY:
		r_scrolls = (found["scrolls"] as Dictionary).duplicate(true)
	elif cur_same and typeof(cur_p.get("scrolls")) == TYPE_DICTIONARY:
		r_scrolls = (cur_p["scrolls"] as Dictionary).duplicate(true)
	var r_diamonds := 35
	if found.has("diamonds") and found.get("diamonds") != null:
		r_diamonds = maxi(0, int(found.get("diamonds", 35)))
	elif cur_same and cur_p.has("diamonds") and cur_p.get("diamonds") != null:
		r_diamonds = maxi(0, int(cur_p.get("diamonds", 35)))
	var r_read_sigs := _merge_string_sig_arrays(found.get("read_report_sigs", []), cur_p.get("read_report_sigs", []) if cur_same else [])
	var r_del_sigs := _merge_string_sig_arrays(found.get("deleted_report_sigs", []), cur_p.get("deleted_report_sigs", []) if cur_same else [])
	var r_read_msg_sigs := _merge_string_sig_arrays(found.get("read_message_sigs", []), cur_p.get("read_message_sigs", []) if cur_same else [])
	var r_del_msg_sigs := _merge_string_sig_arrays(found.get("deleted_message_sigs", []), cur_p.get("deleted_message_sigs", []) if cur_same else [])

	var tut_completed := bool(found.get("tutorial_completed", false)) or (cur_same and bool(cur_p.get("tutorial_completed", false)))
	var tut_skipped := bool(found.get("tutorial_skipped", false)) or (cur_same and bool(cur_p.get("tutorial_skipped", false)))
	var tut_reward_claimed := bool(found.get("tutorial_reward_claimed", false)) or (cur_same and bool(cur_p.get("tutorial_reward_claimed", false)))
	var tut_step := maxi(int(found.get("tutorial_step", 0)), int(cur_p.get("tutorial_step", 0)) if cur_same else 0)
	if not tut_completed:
		if tut_skipped or tut_reward_claimed or tut_step >= 18:
			tut_completed = true
		else:
			var owned_cnt := 0
			var v_arr = state_dict.get("villages", [])
			if typeof(v_arr) == TYPE_ARRAY:
				for item_v in (v_arr as Array):
					if _is_real_player_village_dict(item_v) and _matches_player(str((item_v as Dictionary).get("owner", "")), norm_p):
						owned_cnt += 1
						var vb: Dictionary = (item_v as Dictionary).get("buildings", {}) if typeof((item_v as Dictionary).get("buildings")) == TYPE_DICTIONARY else {}
						if tut_step == 0 and (int(vb.get("main", 1)) >= 4 or int(vb.get("stable", 0)) >= 1 or int(vb.get("market", 0)) >= 1 or int(vb.get("garage", 0)) >= 1 or int(vb.get("snob", 0)) >= 1):
							tut_completed = true
			if owned_cnt > 1:
				tut_completed = true

	var restored := {
		"id": 1,
		"name": norm_p,
		"auth_id": str(found.get("auth_id", cur_p.get("auth_id", "") if cur_same else "")),
		"provider": str(found.get("provider", cur_p.get("provider", "") if cur_same else "")),
		"points": int(found.get("points", 0)),
		"created_unix": int(found.get("created_unix", boost_rec.get("created_unix", 0))),
		"starter_boost_until_unix": int(found.get("starter_boost_until_unix", boost_rec.get("starter_boost_until_unix", 0))),
		"protection_until_unix": int(found.get("protection_until_unix", 0)),
		"conquest_protection_until_unix": int(found.get("conquest_protection_until_unix", 0)),
		"restarted_unix": maxi(int(found.get("restarted_unix", 0)), int(cur_p.get("restarted_unix", 0)) if cur_same else 0),
		"tutorial_completed": tut_completed,
		"tutorial_skipped": tut_skipped,
		"tutorial_step": tut_step,
		"tutorial_reward_claimed": tut_reward_claimed,
		"quests": q_dict,
		"gold_armour": int(found.get("gold_armour", 0)),
		"diamonds": r_diamonds,
		"scrolls": r_scrolls,
		"read_report_sigs": r_read_sigs,
		"deleted_report_sigs": r_del_sigs,
		"unread_toggled_sigs": _merge_string_sig_arrays(found.get("unread_toggled_sigs", []), cur_p.get("unread_toggled_sigs", []) if cur_same else [], 200),
		"read_message_sigs": r_read_msg_sigs,
		"deleted_message_sigs": r_del_msg_sigs,
		"premium": false,
	}
	state_dict["player"] = restored
	_apply_report_sigs_to_state(state_dict, norm_p)


## Aktif dünya durumunu GameState'e aktarır.
func _apply_to_game_state(w_data: Dictionary, player_name: String, active_vid: int) -> void:
	var gs = _find_game_state()
	if gs == null:
		return

	var state: Dictionary = (w_data.get("state", {}) as Dictionary).duplicate(true)
	var now := int(Time.get_unix_time_from_system())
	_restore_player_profile_from_world(state, player_name)
	_ensure_starter_boost(state, int(w_data.get("created_unix", now)), now, player_name)
	state["active_village_id"] = active_vid
	gs.from_dict(state)
	gs.player["name"] = player_name
	gs.player["id"] = 1
	var auth := _find_autoload("AuthManager")
	if auth != null and bool(auth.is_logged_in):
		gs.player["provider"] = str(auth.auth_provider)
		if not str(auth.user_id).is_empty():
			gs.player["auth_id"] = str(auth.user_id)
	gs.active_village_id = active_vid
	gs.world["world_id"] = current_world_id
	gs.world["world_name"] = "Dünya %d" % current_world_id
	_sync_game_config_speed({"world": gs.world}, now)

	# Oyuncunun toplam puanını hesapla
	var total_points := 0
	for v in gs.villages:
		if typeof(v) == TYPE_DICTIONARY:
			var vd: Dictionary = v
			if _matches_player(str(vd.get("owner", "")), player_name):
				total_points += int(vd.get("points", 110))
	gs.player["points"] = total_points


## Anlık GameState'i aktif dünya dosyasına kaydeder (force_cloud: bulut kaydını throttle'sız hemen gönder; allow_cloud: bulut HTTP çağrısına izin ver).
func save_active_world(force_cloud: bool = false, allow_cloud: bool = true) -> bool:
	if _suppress_reset_save:
		return false
	var gs = _find_game_state()
	if gs == null:
		return false
	if not gs.has_active_village() and gs.villages.is_empty():
		var cur_pname := str(gs.player.get("name", ""))
		if has_player_village(current_world_id, cur_pname):
			return false

	var w_data := load_world_dict(current_world_id)
	if w_data.is_empty():
		w_data = {
			"world_id": current_world_id,
			"world_name": "Dünya %d" % current_world_id,
			"seed": BASE_SEED + current_world_id,
			"created_unix": int(Time.get_unix_time_from_system()),
			"registered_real_players": [],
			"state": {}
		}

	var now := int(Time.get_unix_time_from_system())
	gs.world["last_saved_unix"] = now
	gs.world["sim_now_unix"] = maxi(int(gs.world.get("sim_now_unix", 0)), now)

	var prev_world: Dictionary = w_data.get("state", {}).get("world", {}) if typeof(w_data.get("state")) == TYPE_DICTIONARY and typeof(w_data.get("state", {}).get("world")) == TYPE_DICTIONARY else {}
	var next_state: Dictionary = gs.to_dict()
	if typeof(next_state.get("world")) != TYPE_DICTIONARY:
		next_state["world"] = {}
	var nw: Dictionary = next_state["world"]
	if typeof(prev_world.get("player_profiles")) == TYPE_DICTIONARY:
		var merged_p: Dictionary = (prev_world["player_profiles"] as Dictionary).duplicate(true)
		if typeof(nw.get("player_profiles")) == TYPE_DICTIONARY:
			for k in (nw["player_profiles"] as Dictionary).keys():
				merged_p[k] = nw["player_profiles"][k]
		nw["player_profiles"] = merged_p
	if typeof(prev_world.get("player_profiles")) == TYPE_DICTIONARY:
		var merged_p: Dictionary = (prev_world["player_profiles"] as Dictionary).duplicate(true)
		if typeof(nw.get("player_profiles")) == TYPE_DICTIONARY:
			for k in (nw["player_profiles"] as Dictionary).keys():
				merged_p[k] = nw["player_profiles"][k]
		nw["player_profiles"] = merged_p
	if typeof(prev_world.get("player_starter_boost")) == TYPE_DICTIONARY:
		var merged_b: Dictionary = (prev_world["player_starter_boost"] as Dictionary).duplicate(true)
		if typeof(nw.get("player_starter_boost")) == TYPE_DICTIONARY:
			for k in (nw["player_starter_boost"] as Dictionary).keys():
				merged_b[k] = nw["player_starter_boost"][k]
		nw["player_starter_boost"] = merged_b
	_sync_player_profile_to_world(next_state)

	w_data["last_saved_unix"] = now
	w_data["state"] = next_state
	if now < _wallet_lock_until_unix:
		w_data["wallet_authoritative"] = true

	var p_name := str(gs.player.get("name", "Lord Gorkem"))
	var reg_list: Array = w_data.get("registered_real_players", [])
	if not (p_name in reg_list):
		reg_list.append(p_name)
		w_data["registered_real_players"] = reg_list

	var ok := save_world_dict(current_world_id, w_data)
	if ok and allow_cloud and _cloud_enabled() and Engine.get_main_loop() is SceneTree:
		var net = Engine.get_main_loop().root.get_node_or_null("NetworkManager")
		if net != null and not str(net.auth_token).is_empty() and (force_cloud or (now - _last_cloud_save_unix) >= 2):
			_last_cloud_save_unix = now
			_last_cloud_save_seq = _local_mutation_seq
			net.save_state_to_cloud(net.auth_token, w_data, Callable(), _local_mutation_seq)
	return ok


func _is_real_player_village_dict(v) -> bool:
	if typeof(v) != TYPE_DICTIONARY:
		return false
	var vd: Dictionary = v
	var owner := _norm_name(str(vd.get("owner", "")))
	return (
		not bool(vd.get("is_bot", false))
		and not bool(vd.get("is_barbarian", false))
		and str(vd.get("bonus_type", "")).is_empty()
		and not owner.is_empty()
		and owner != "Barbar"
		and owner != "Terk Edilmiş"
		and owner != "Soyguncular"
		and owner != "Usta"
	)


func _sync_worlds_meta_from_server(meta_list, target_wid: int = -1, reg_count: int = -1) -> void:
	var changed := false
	if worlds_meta.is_empty():
		_load_meta()
	if typeof(meta_list) == TYPE_ARRAY and not (meta_list as Array).is_empty():
		for item in (meta_list as Array):
			if typeof(item) != TYPE_DICTIONARY:
				continue
			var sd: Dictionary = item
			var wid := int(sd.get("id", 0))
			if wid < 1 or wid > WORLDS_COUNT:
				continue
			for wm in worlds_meta:
				if typeof(wm) == TYPE_DICTIONARY and int((wm as Dictionary).get("id", 0)) == wid:
					var s_active := int(sd.get("is_active", 0)) != 0
					var s_reg := int(sd.get("registered_players", 0))
					if bool(wm.get("is_active", false)) != s_active:
						wm["is_active"] = s_active
						changed = true
					if int(wm.get("registered_real_players", 0)) != s_reg:
						wm["registered_real_players"] = s_reg
						changed = true
					break
	if target_wid >= 1 and target_wid <= WORLDS_COUNT and reg_count >= 0:
		for wm in worlds_meta:
			if typeof(wm) == TYPE_DICTIONARY and int((wm as Dictionary).get("id", 0)) == target_wid:
				if int(wm.get("registered_real_players", 0)) != reg_count:
					wm["registered_real_players"] = reg_count
					changed = true
				if reg_count >= MAX_REAL_PLAYERS_PER_WORLD:
					_unlock_next_world(target_wid + 1)
				break
	if changed:
		_save_meta()


func _preserve_monotonic_progress_from_local(target_w: Dictionary, local_w: Dictionary, p_name: String, prefer_cloud_read: bool = false) -> void:
	if local_w.is_empty() or target_w.is_empty():
		return
	var t_state: Dictionary = target_w.get("state", {}) if typeof(target_w.get("state")) == TYPE_DICTIONARY else {}
	var l_state: Dictionary = local_w.get("state", {}) if typeof(local_w.get("state")) == TYPE_DICTIONARY else {}
	if t_state.is_empty() or l_state.is_empty():
		return
	var t_world: Dictionary = t_state.get("world", {}) if typeof(t_state.get("world")) == TYPE_DICTIONARY else {}
	var l_world: Dictionary = l_state.get("world", {}) if typeof(l_state.get("world")) == TYPE_DICTIONARY else {}
	var t_profs: Dictionary = t_world.get("player_profiles", {}) if typeof(t_world.get("player_profiles")) == TYPE_DICTIONARY else {}
	var l_profs: Dictionary = l_world.get("player_profiles", {}) if typeof(l_world.get("player_profiles")) == TYPE_DICTIONARY else {}
	var l_prof: Dictionary = {}
	for pk in l_profs.keys():
		if _matches_player(str(pk), p_name) and typeof(l_profs[pk]) == TYPE_DICTIONARY:
			l_prof = l_profs[pk] as Dictionary
			break
	if l_prof.is_empty() and typeof(l_state.get("player")) == TYPE_DICTIONARY and _matches_player(str((l_state["player"] as Dictionary).get("name", "")), p_name):
		l_prof = l_state["player"] as Dictionary
	var t_pk := _norm_name(p_name)
	var t_prof: Dictionary = {}
	for pk in t_profs.keys():
		if _matches_player(str(pk), p_name) and typeof(t_profs[pk]) == TYPE_DICTIONARY:
			t_pk = str(pk)
			t_prof = t_profs[pk] as Dictionary
			break
	if t_prof.is_empty() and typeof(t_state.get("player")) == TYPE_DICTIONARY and _matches_player(str((t_state["player"] as Dictionary).get("name", "")), p_name):
		t_prof = t_state["player"] as Dictionary
	if not l_prof.is_empty() or not t_prof.is_empty():
		var merged_prof := _merge_profile_dicts(l_prof, t_prof, prefer_cloud_read) if prefer_cloud_read else _merge_profile_dicts(t_prof, l_prof, not prefer_cloud_read)
		if not t_pk.is_empty():
			t_profs[t_pk] = merged_prof
			t_world["player_profiles"] = t_profs
			t_state["world"] = t_world
		if typeof(t_state.get("player")) == TYPE_DICTIONARY and _matches_player(str((t_state["player"] as Dictionary).get("name", "")), p_name):
			t_state["player"] = _merge_profile_dicts(t_state["player"] as Dictionary, merged_prof, true)
	_apply_report_sigs_to_state(t_state, p_name)


func _preserve_own_village_progress_from_local(target_w: Dictionary, local_w: Dictionary, p_name: String) -> void:
	if target_w.is_empty() or local_w.is_empty():
		return
	var t_state: Dictionary = target_w.get("state", {}) if typeof(target_w.get("state")) == TYPE_DICTIONARY else {}
	var l_state: Dictionary = local_w.get("state", {}) if typeof(local_w.get("state")) == TYPE_DICTIONARY else {}
	var t_villages: Array = t_state.get("villages", []) if typeof(t_state.get("villages")) == TYPE_ARRAY else []
	var l_villages: Array = l_state.get("villages", []) if typeof(l_state.get("villages")) == TYPE_ARRAY else []
	if t_villages.is_empty() or l_villages.is_empty():
		return

	var l_by_id: Dictionary = {}
	for lv in l_villages:
		if _is_real_player_village_dict(lv) and _matches_player(str((lv as Dictionary).get("owner", "")), p_name):
			l_by_id[int((lv as Dictionary).get("id", 0))] = lv as Dictionary

	var now_u := int(Time.get_unix_time_from_system())
	var teardown_active := (now_u < _recent_teardown_until_unix)
	var protected_buildings: Dictionary = {}

	for tv in t_villages:
		if not (_is_real_player_village_dict(tv) and _matches_player(str((tv as Dictionary).get("owner", "")), p_name)):
			continue
		var tvd := tv as Dictionary
		var vid := int(tvd.get("id", 0))
		if not l_by_id.has(vid):
			continue
		var lvd: Dictionary = l_by_id[vid]

		if not teardown_active and typeof(lvd.get("buildings")) == TYPE_DICTIONARY:
			var lb: Dictionary = lvd["buildings"]
			if typeof(tvd.get("buildings")) != TYPE_DICTIONARY:
				tvd["buildings"] = {}
			var tb: Dictionary = tvd["buildings"]
			for bk in lb.keys():
				var l_lvl := int(lb.get(bk, 0))
				var t_lvl := int(tb.get(bk, 0))
				if l_lvl > t_lvl:
					tb[bk] = l_lvl
					if not protected_buildings.has(vid):
						protected_buildings[vid] = {}
					(protected_buildings[vid] as Dictionary)[str(bk)] = l_lvl
			tvd["points"] = maxi(int(tvd.get("points", 0)), int(lvd.get("points", 0)))

		var l_nu := int(lvd.get("name_updated_unix", 0))
		var t_nu := int(tvd.get("name_updated_unix", 0))
		var l_ns := int(lvd.get("name_edit_seq", 0))
		var t_ns := int(tvd.get("name_edit_seq", 0))
		var l_name := str(lvd.get("name", "")).strip_edges()
		if not l_name.is_empty() and (l_nu > t_nu or (l_nu == t_nu and l_ns > t_ns)):
			tvd["name"] = l_name
			tvd["name_updated_unix"] = l_nu
			tvd["name_edit_seq"] = l_ns

	if not protected_buildings.is_empty() and typeof(t_state.get("queues")) == TYPE_ARRAY:
		var cleaned_q: Array = []
		for q in (t_state["queues"] as Array):
			if typeof(q) == TYPE_DICTIONARY and str((q as Dictionary).get("type", "")) == "build":
				var qd := q as Dictionary
				var q_vid := int(qd.get("village_id", -1))
				var q_key := str(qd.get("key", ""))
				if protected_buildings.has(q_vid) and (protected_buildings[q_vid] as Dictionary).has(q_key):
					var min_done := int((protected_buildings[q_vid] as Dictionary)[q_key])
					if int(qd.get("target_level", 0)) <= min_done:
						continue
			cleaned_q.append(q)
		t_state["queues"] = cleaned_q


func _merge_shared_world_data(local_w: Dictionary, cloud_w: Dictionary, p_name: String, local_ts: int, cloud_ts: int, from_save_response: bool, req_seq: int = -1) -> Dictionary:
	var has_newer_local_mutation := (req_seq >= 0 and _local_mutation_seq > req_seq)
	var local_has_v := _world_has_player_village_in_dict(local_w, p_name) or has_player_village(int(cloud_w.get("world_id", 1)), p_name)
	var cloud_has_v := _world_has_player_village_in_dict(cloud_w, p_name)
	var cloud_conquered := _world_has_conquest_defeat_in_dict(cloud_w, p_name)
	var local_village_missing_in_cloud := (local_has_v and not cloud_has_v and not cloud_conquered)

	if local_w.is_empty() or not local_has_v:
		var out_c := cloud_w.duplicate(true)
		_preserve_monotonic_progress_from_local(out_c, local_w, p_name, true)
		_preserve_own_village_progress_from_local(out_c, local_w, p_name)
		return out_c

	# Eğer sunucu bu kaydedişten hemen sonra döndüyse ve yerel ekstra mutasyon olmadıysa sunucunun ortak dünyası kanoniktir.
	if from_save_response and not has_newer_local_mutation and not local_village_missing_in_cloud and _last_local_mutation_unix <= _last_cloud_save_unix:
		var out_s := cloud_w.duplicate(true)
		_preserve_monotonic_progress_from_local(out_s, local_w, p_name, true)
		_preserve_own_village_progress_from_local(out_s, local_w, p_name)
		return out_s

	# Yerel değişiklik sunucudan eskiyse veya eşitse doğrudan ortak dünyayı al (ama yerelde köy varken bulut boşsa köyü asla silme!).
	if cloud_ts >= local_ts and not from_save_response and not has_newer_local_mutation and not local_village_missing_in_cloud:
		var out_newer := cloud_w.duplicate(true)
		_preserve_monotonic_progress_from_local(out_newer, local_w, p_name, true)
		_preserve_own_village_progress_from_local(out_newer, local_w, p_name)
		return out_newer

	# Yerel durum sunucudan daha yeni ise: ortak dünyadaki diğer oyuncuları/ittifakları/mesajları al, kendi köylerimizi ve kuyruklarımızı koru!
	var merged: Dictionary = cloud_w.duplicate(true)
	var m_state: Dictionary = merged.get("state", {}) if typeof(merged.get("state")) == TYPE_DICTIONARY else {}
	var l_state: Dictionary = local_w.get("state", {}) if typeof(local_w.get("state")) == TYPE_DICTIONARY else {}
	var c_villages: Array = m_state.get("villages", []) if typeof(m_state.get("villages")) == TYPE_ARRAY else []
	var l_villages: Array = l_state.get("villages", []) if typeof(l_state.get("villages")) == TYPE_ARRAY else []

	# Sunucunun başka gerçek oyuncuya verdiği ID ile yerel ID çakışmış mı kontrol et
	var c_by_id: Dictionary = {}
	for v in c_villages:
		if typeof(v) == TYPE_DICTIONARY:
			c_by_id[int((v as Dictionary).get("id", 0))] = v

	var local_vids: Dictionary = {}
	var id_remapped_by_server := false
	for lv in l_villages:
		if _is_real_player_village_dict(lv) and _matches_player(str((lv as Dictionary).get("owner", "")), p_name):
			var lvid := int((lv as Dictionary).get("id", 0))
			local_vids[lvid] = true
			if c_by_id.has(lvid) and _is_real_player_village_dict(c_by_id[lvid]) and not _matches_player(str((c_by_id[lvid] as Dictionary).get("owner", "")), p_name):
				id_remapped_by_server = true
				break

	if id_remapped_by_server:
		return cloud_w.duplicate(true)

	# Kendi yerel köylerimizi koru, diğer gerçek oyuncuların köylerini cloud_w'den koru
	for lv in l_villages:
		if _is_real_player_village_dict(lv) and _matches_player(str((lv as Dictionary).get("owner", "")), p_name):
			c_by_id[int((lv as Dictionary).get("id", 0))] = (lv as Dictionary).duplicate(true)

	var combined_villages: Array = []
	for vid_k in c_by_id.keys():
		combined_villages.append(c_by_id[vid_k])
	combined_villages.sort_custom(func(a, b): return int(a.get("id", 0)) < int(b.get("id", 0)))
	m_state["villages"] = combined_villages
	_deduplicate_player_starter_villages(merged, int(l_state.get("active_village_id", -1)))
	combined_villages = m_state.get("villages", combined_villages)

	# Yerel kuyrukları koru, diğer köylerin sunucudaki kuyruklarını tut
	var c_queues: Array = m_state.get("queues", []) if typeof(m_state.get("queues")) == TYPE_ARRAY else []
	var l_queues: Array = l_state.get("queues", []) if typeof(l_state.get("queues")) == TYPE_ARRAY else []
	var combined_queues: Array = []
	for q in c_queues:
		if typeof(q) == TYPE_DICTIONARY and not local_vids.has(int((q as Dictionary).get("village_id", 0))):
			combined_queues.append((q as Dictionary).duplicate(true))
	for q in l_queues:
		if typeof(q) == TYPE_DICTIONARY and local_vids.has(int((q as Dictionary).get("village_id", 0))):
			combined_queues.append((q as Dictionary).duplicate(true))
	m_state["queues"] = combined_queues

	# Yerel seferleri (movements) koru, diğer oyuncuların sunucudaki seferlerini tut
	var c_movements: Array = m_state.get("movements", []) if typeof(m_state.get("movements")) == TYPE_ARRAY else []
	var l_movements: Array = l_state.get("movements", []) if typeof(l_state.get("movements")) == TYPE_ARRAY else []
	m_state["movements"] = _merge_player_and_remote_movements(l_movements, c_movements, p_name, local_vids)

	# Yerel yeni raporları koru, okunma & silinme durumlarını senkronize et
	var l_p_dict: Dictionary = l_state.get("player", {}) if typeof(l_state.get("player")) == TYPE_DICTIONARY else {}
	var m_p_dict: Dictionary = m_state.get("player", {}) if typeof(m_state.get("player")) == TYPE_DICTIONARY else {}
	var merged_read_arr := _merge_string_sig_arrays(l_p_dict.get("read_report_sigs", []) if l_p_dict.has("read_report_sigs") else m_p_dict.get("read_report_sigs", []), [])
	var merged_del_arr := _merge_string_sig_arrays(m_p_dict.get("deleted_report_sigs", []), l_p_dict.get("deleted_report_sigs", []))
	var local_read_sigs: Dictionary = {}
	for s in merged_read_arr:
		local_read_sigs[str(s)] = true
	var local_del_sigs: Dictionary = {}
	for ds in merged_del_arr:
		local_del_sigs[str(ds)] = true
	if typeof(l_state.get("reports")) == TYPE_ARRAY and typeof(m_state.get("reports")) == TYPE_ARRAY:
		var seen_r_ids: Dictionary = {}
		var comb_reps: Array = []
		for r in (m_state["reports"] as Array):
			if typeof(r) == TYPE_DICTIONARY:
				var r_key := _report_sig_str(r as Dictionary)
				if local_del_sigs.has(r_key):
					continue
				if not seen_r_ids.has(r_key):
					seen_r_ids[r_key] = true
					if local_read_sigs.has(r_key):
						(r as Dictionary)["unread"] = false
					comb_reps.append(r)
		for lr in (l_state["reports"] as Array):
			if typeof(lr) == TYPE_DICTIONARY:
				var lr_key := _report_sig_str(lr as Dictionary)
				if local_del_sigs.has(lr_key):
					continue
				if not seen_r_ids.has(lr_key):
					seen_r_ids[lr_key] = true
					if local_read_sigs.has(lr_key):
						(lr as Dictionary)["unread"] = false
					comb_reps.append((lr as Dictionary).duplicate(true))
		m_state["reports"] = comb_reps

	# Yerel ve bulut mesajlarını birleştir, okunma/silinme imzalarını uygula (mükerrer Hoş Geldiniz'leri önle)
	var m_p_msg_src: Dictionary = m_state.get("player", {}) if typeof(m_state.get("player")) == TYPE_DICTIONARY else {}
	var l_p_msg_src: Dictionary = l_state.get("player", {}) if typeof(l_state.get("player")) == TYPE_DICTIONARY else {}
	var merged_msg_read_arr := _merge_string_sig_arrays(m_p_msg_src.get("read_message_sigs", []), l_p_msg_src.get("read_message_sigs", []))
	var merged_msg_del_arr := _merge_string_sig_arrays(m_p_msg_src.get("deleted_message_sigs", []), l_p_msg_src.get("deleted_message_sigs", []))
	var msg_read_set: Dictionary = {}
	for mrs in merged_msg_read_arr:
		msg_read_set[str(mrs)] = true
	var msg_del_set: Dictionary = {}
	for mds in merged_msg_del_arr:
		msg_del_set[str(mds)] = true
	var comb_msgs: Array = []
	var seen_msg_idx: Dictionary = {}
	var m_msgs_raw: Array = m_state.get("messages", []) if typeof(m_state.get("messages")) == TYPE_ARRAY else []
	var l_msgs_raw: Array = l_state.get("messages", []) if typeof(l_state.get("messages")) == TYPE_ARRAY else []
	for src_m in m_msgs_raw + l_msgs_raw:
		if typeof(src_m) != TYPE_DICTIONARY:
			continue
		var mc := (src_m as Dictionary).duplicate(true)
		var msig := _message_sig_str(mc)
		var m_to := str(mc.get("to", mc.get("to_name", ""))).strip_edges()
		var m_from := str(mc.get("from", mc.get("from_name", ""))).strip_edges()
		var is_own_m := _matches_player(m_to, p_name) or _matches_player(m_from, p_name)
		if is_own_m and msg_del_set.has(msig):
			continue
		if is_own_m and msg_read_set.has(msig):
			mc["read"] = true
		if seen_msg_idx.has(msig):
			var prev_mc := comb_msgs[int(seen_msg_idx[msig])] as Dictionary
			if bool(mc.get("read", false)) or (is_own_m and msg_read_set.has(msig)):
				prev_mc["read"] = true
			continue
		seen_msg_idx[msig] = comb_msgs.size()
		comb_msgs.append(mc)
	m_state["messages"] = comb_msgs

	# Kendi yerel profilimizi koru (monotonik birleştirme ile), diğer profilleri sunucudan tut
	var m_world: Dictionary = m_state.get("world", {}) if typeof(m_state.get("world")) == TYPE_DICTIONARY else {}
	var l_world: Dictionary = l_state.get("world", {}) if typeof(l_state.get("world")) == TYPE_DICTIONARY else {}
	if typeof(l_world.get("player_profiles")) == TYPE_DICTIONARY and typeof(m_world.get("player_profiles")) == TYPE_DICTIONARY:
		for pk in (l_world["player_profiles"] as Dictionary).keys():
			if _matches_player(str(pk), p_name) and typeof(l_world["player_profiles"][pk]) == TYPE_DICTIONARY:
				var m_cur_p: Dictionary = m_world["player_profiles"].get(pk, {}) if typeof(m_world["player_profiles"].get(pk)) == TYPE_DICTIONARY else {}
				m_world["player_profiles"][pk] = _merge_profile_dicts(m_cur_p, l_world["player_profiles"][pk] as Dictionary, true)
	if typeof(l_state.get("player")) == TYPE_DICTIONARY and not (l_state["player"] as Dictionary).is_empty():
		var cur_mp: Dictionary = m_state.get("player", {}) if typeof(m_state.get("player")) == TYPE_DICTIONARY else {}
		m_state["player"] = _merge_profile_dicts(cur_mp, l_state["player"] as Dictionary, true)
	if int(l_state.get("active_village_id", -1)) > 0:
		m_state["active_village_id"] = int(l_state["active_village_id"])

	# Yerel yeni ittifaklar/sohbet/hareketler varsa birleştir
	var tiles: Dictionary = {}
	for v in combined_villages:
		if typeof(v) == TYPE_DICTIONARY:
			tiles[WorldGeneratorScript.tile_key(int(v.get("x", 1)), int(v.get("y", 1)))] = int(v.get("id", 0))
	m_world["tiles"] = tiles
	m_world["villages"] = combined_villages
	m_state["world"] = m_world
	merged["state"] = m_state
	merged["last_saved_unix"] = maxi(local_ts, cloud_ts)
	return merged


func _is_own_movement_dict(m: Dictionary, p_name: String, owned_vids: Dictionary) -> bool:
	var m_owner := str(m.get("owner", "")).strip_edges()
	if not m_owner.is_empty() and _matches_player(m_owner, p_name):
		return true
	var m_vid := int(m.get("village_id", -1))
	if owned_vids.has(m_vid):
		return true
	var is_ret := (str(m.get("state", "")) == "returning" or str(m.get("type", "")) == "return")
	if is_ret:
		return owned_vids.has(int(m.get("to_village_id", -1)))
	return owned_vids.has(int(m.get("from_village_id", -1)))


func _merge_player_and_remote_movements(local_movs: Array, remote_movs: Array, p_name: String, owned_vids: Dictionary) -> Array:
	var returned_origin_ids: Dictionary = {}
	var returned_seeds: Dictionary = {}
	for src_arr in [local_movs, remote_movs]:
		for item in src_arr:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			var md := item as Dictionary
			if str(md.get("state", "")) == "returning" or str(md.get("type", "")) == "return":
				var omid := int(md.get("origin_movement_id", 0))
				if omid > 0:
					returned_origin_ids[omid] = true
				var bseed := int(md.get("battle_seed", 0))
				if bseed > 0:
					returned_seeds[bseed] = true

	var out: Array = []
	var seen_keys: Dictionary = {}
	# Kendi hareketlerimizde yerel liste otoriterdir
	for lm in local_movs:
		if typeof(lm) != TYPE_DICTIONARY:
			continue
		var md := (lm as Dictionary).duplicate(true)
		if not _is_own_movement_dict(md, p_name, owned_vids):
			continue
		var is_ret := (str(md.get("state", "")) == "returning" or str(md.get("type", "")) == "return")
		var mid := int(md.get("id", 0))
		var bseed := int(md.get("battle_seed", 0))
		if not is_ret and ((mid > 0 and returned_origin_ids.has(mid)) or (bseed > 0 and returned_seeds.has(bseed))):
			continue
		var k := "own_%d_%s_%d" % [mid, "ret" if is_ret else "out", bseed]
		if not seen_keys.has(k):
			seen_keys[k] = true
			out.append(md)

	# Diğer oyuncuların hareketlerini sunucudan ekle
	for rm in remote_movs:
		if typeof(rm) != TYPE_DICTIONARY:
			continue
		var rmd := (rm as Dictionary).duplicate(true)
		if _is_own_movement_dict(rmd, p_name, owned_vids):
			continue
		var r_key := "rem_%d_%d_%s_%d" % [int(rmd.get("from_village_id", 0)), int(rmd.get("to_village_id", 0)), str(rmd.get("type", "")), int(rmd.get("depart_unix", 0))]
		if not seen_keys.has(r_key):
			seen_keys[r_key] = true
			out.append(rmd)
	return out


func _live_sync_game_state_from_world(merged_w: Dictionary, p_name: String) -> void:
	var gs = _find_game_state()
	if gs == null or not gs.has_active_village():
		return
	var w_id := int(merged_w.get("world_id", current_world_id))
	if w_id != current_world_id:
		return
	var st: Dictionary = merged_w.get("state", {}) if typeof(merged_w.get("state")) == TYPE_DICTIONARY else {}
	if st.is_empty():
		return

	_is_applying_cloud_sync = true
	var remote_villages: Array = st.get("villages", []) if typeof(st.get("villages")) == TYPE_ARRAY else []
	var prev_owned := false
	var prev_own_villages: Array = []
	for pv in gs.villages:
		if _is_real_player_village_dict(pv) and _matches_player(str((pv as Dictionary).get("owner", "")), p_name):
			prev_owned = true
			prev_own_villages.append((pv as Dictionary).duplicate(true))
	if not remote_villages.is_empty():
		var next_villages := remote_villages.duplicate(true)
		var remote_has_own := false
		for rv in next_villages:
			if _is_real_player_village_dict(rv) and _matches_player(str((rv as Dictionary).get("owner", "")), p_name):
				remote_has_own = true
				break
		if prev_owned and not remote_has_own and not is_player_conquered(w_id, p_name):
			for pvv in prev_own_villages:
				next_villages.append(pvv)
		gs.villages = next_villages
	var owns_active := false
	var first_owned_vid := -1
	var total_pts := 0
	for v in gs.villages:
		if _is_real_player_village_dict(v) and _matches_player(str((v as Dictionary).get("owner", "")), p_name):
			var vid := int((v as Dictionary).get("id", -1))
			if first_owned_vid < 0:
				first_owned_vid = vid
			if vid == gs.active_village_id:
				owns_active = true
			total_pts += int((v as Dictionary).get("points", 110))
	if not owns_active and first_owned_vid > 0:
		gs.active_village_id = first_owned_vid
	elif first_owned_vid < 0 and is_player_conquered(w_id, p_name):
		gs.active_village_id = -1
	gs.player["points"] = total_pts
	var now_sync := int(Time.get_unix_time_from_system())
	var wallet_locked := (now_sync < _wallet_lock_until_unix)
	if typeof(st.get("player")) == TYPE_DICTIONARY:
		var rp: Dictionary = st["player"]
		if _matches_player(str(rp.get("name", "")), p_name):
			if not wallet_locked:
				if rp.has("diamonds") and rp.get("diamonds") != null:
					gs.player["diamonds"] = maxi(0, int(rp.get("diamonds", 35)))
				if typeof(rp.get("scrolls")) == TYPE_DICTIONARY:
					gs.player["scrolls"] = (rp["scrolls"] as Dictionary).duplicate(true)
			var merged_live_p := _merge_profile_dicts(gs.player, rp, false)
			gs.player["tutorial_completed"] = bool(merged_live_p.get("tutorial_completed", false))
			gs.player["tutorial_skipped"] = bool(merged_live_p.get("tutorial_skipped", false))
			gs.player["tutorial_reward_claimed"] = bool(merged_live_p.get("tutorial_reward_claimed", false))
			gs.player["tutorial_step"] = int(merged_live_p.get("tutorial_step", 0))
			gs.player["quests"] = (merged_live_p["quests"] as Dictionary).duplicate(true)
			gs.player["read_report_sigs"] = (merged_live_p.get("read_report_sigs", []) as Array).duplicate(true)
			gs.player["deleted_report_sigs"] = (merged_live_p.get("deleted_report_sigs", []) as Array).duplicate(true)
			gs.player["read_message_sigs"] = (merged_live_p.get("read_message_sigs", []) as Array).duplicate(true)
			gs.player["deleted_message_sigs"] = (merged_live_p.get("deleted_message_sigs", []) as Array).duplicate(true)

	var owned_vids: Dictionary = {}
	for v in gs.villages:
		if _is_real_player_village_dict(v) and _matches_player(str((v as Dictionary).get("owner", "")), p_name):
			owned_vids[int((v as Dictionary).get("id", 0))] = true

	if typeof(st.get("alliances")) == TYPE_ARRAY:
		gs.alliances = (st["alliances"] as Array).duplicate(true)
	if typeof(st.get("movements")) == TYPE_ARRAY:
		if _last_local_mutation_unix > _last_cloud_save_unix or wallet_locked:
			gs.movements = _merge_player_and_remote_movements(gs.movements, st["movements"] as Array, p_name, owned_vids)
		else:
			# Yine de kendi aktif hareketlerimizde giden+dönen çakışmasını temizle
			var remote_movs := (st["movements"] as Array).duplicate(true)
			if not gs.movements.is_empty():
				gs.movements = _merge_player_and_remote_movements(gs.movements, remote_movs, p_name, owned_vids)
			else:
				gs.movements = remote_movs
	if typeof(st.get("queues")) == TYPE_ARRAY:
		var merged_queues: Array = []
		for lq in gs.queues:
			if typeof(lq) == TYPE_DICTIONARY and owned_vids.has(int((lq as Dictionary).get("village_id", 0))):
				merged_queues.append((lq as Dictionary).duplicate(true))
		for rq in (st["queues"] as Array):
			if typeof(rq) == TYPE_DICTIONARY and not owned_vids.has(int((rq as Dictionary).get("village_id", 0))):
				merged_queues.append((rq as Dictionary).duplicate(true))
		gs.queues = merged_queues
	if typeof(st.get("messages")) == TYPE_ARRAY:
		var msg_del_sync: Dictionary = {}
		if typeof(gs.player.get("deleted_message_sigs")) == TYPE_ARRAY:
			for mds in (gs.player["deleted_message_sigs"] as Array):
				msg_del_sync[str(mds)] = true
		var msg_read_sync: Dictionary = {}
		if typeof(gs.player.get("read_message_sigs")) == TYPE_ARRAY:
			for mrs in (gs.player["read_message_sigs"] as Array):
				msg_read_sync[str(mrs)] = true
		var sync_msgs: Array = []
		var seen_sync_msgs: Dictionary = {}
		for mm in (st["messages"] as Array):
			if typeof(mm) != TYPE_DICTIONARY:
				continue
			var mmd := (mm as Dictionary).duplicate(true)
			var msig := _message_sig_str(mmd)
			var m_to := str(mmd.get("to", mmd.get("to_name", ""))).strip_edges()
			var m_from := str(mmd.get("from", mmd.get("from_name", ""))).strip_edges()
			var is_own := _matches_player(m_to, p_name) or _matches_player(m_from, p_name)
			if is_own and msg_del_sync.has(msig):
				continue
			if is_own and msg_read_sync.has(msig):
				mmd["read"] = true
			if seen_sync_msgs.has(msig):
				var prev_mmd := sync_msgs[int(seen_sync_msgs[msig])] as Dictionary
				if bool(mmd.get("read", false)) or (is_own and msg_read_sync.has(msig)):
					prev_mmd["read"] = true
				continue
			seen_sync_msgs[msig] = sync_msgs.size()
			sync_msgs.append(mmd)
		gs.messages = sync_msgs
	if typeof(st.get("reports")) == TYPE_ARRAY:
		var sync_del_set: Dictionary = {}
		if typeof(gs.player.get("deleted_report_sigs")) == TYPE_ARRAY:
			for ds in (gs.player["deleted_report_sigs"] as Array):
				sync_del_set[str(ds)] = true
		var sync_read_set: Dictionary = {}
		if typeof(gs.player.get("read_report_sigs")) == TYPE_ARRAY:
			for rs in (gs.player["read_report_sigs"] as Array):
				sync_read_set[str(rs)] = true
		var sync_reps: Array = []
		for rr in (st["reports"] as Array):
			if typeof(rr) != TYPE_DICTIONARY:
				continue
			var rrd := (rr as Dictionary).duplicate(true)
			var rrsig := _report_sig_str(rrd)
			if sync_del_set.has(rrsig):
				continue
			if sync_read_set.has(rrsig):
				rrd["unread"] = false
			sync_reps.append(rrd)
		gs.reports = sync_reps
	if typeof(st.get("world")) == TYPE_DICTIONARY:
		var rw: Dictionary = st["world"]
		if typeof(rw.get("tiles")) == TYPE_DICTIONARY:
			gs.world["tiles"] = (rw["tiles"] as Dictionary).duplicate(true)
		if typeof(rw.get("player_profiles")) == TYPE_DICTIONARY:
			gs.world["player_profiles"] = (rw["player_profiles"] as Dictionary).duplicate(true)
		if typeof(rw.get("player_starter_boost")) == TYPE_DICTIONARY:
			gs.world["player_starter_boost"] = (rw["player_starter_boost"] as Dictionary).duplicate(true)
		for bk in ["starter_boost_until_unix", "player_joined_unix", "speed", "unit_speed"]:
			if rw.has(bk):
				gs.world[bk] = rw[bk]
		gs.world["villages"] = gs.villages
	_sync_game_config_speed({"world": gs.world, "player": gs.player}, int(Time.get_unix_time_from_system()))
	gs._emit_state_changed()
	_is_applying_cloud_sync = false
	if first_owned_vid < 0 and is_player_conquered(w_id, p_name):
		var bus = _find_autoload("EventBus")
		if bus != null and bus.has_signal("player_conquered"):
			bus.player_conquered.emit(w_id, p_name)
		maybe_show_conquered_modal_for_current_scene(w_id, p_name)


func _clear_defeated_info_for_player(w_data: Dictionary, p_name: String) -> bool:
	var norm_p := _norm_name(p_name)
	if w_data.is_empty() or norm_p.is_empty():
		return false
	var st: Dictionary = w_data.get("state", {}) if typeof(w_data.get("state")) == TYPE_DICTIONARY else {}
	var wd: Dictionary = st.get("world", {}) if typeof(st.get("world")) == TYPE_DICTIONARY else {}
	var profs: Dictionary = wd.get("player_profiles", {}) if typeof(wd.get("player_profiles")) == TYPE_DICTIONARY else {}
	var changed := false
	for pk in profs.keys():
		if _matches_player(str(pk), norm_p) and typeof(profs[pk]) == TYPE_DICTIONARY:
			if (profs[pk] as Dictionary).has("defeated_info"):
				(profs[pk] as Dictionary).erase("defeated_info")
				changed = true
	return changed


func _inject_server_village_into_world(w_data: Dictionary, sv_dict: Dictionary, p_name: String, res_data: Dictionary = {}) -> bool:
	if w_data.is_empty() or sv_dict.is_empty():
		return false
	var w_id := int(w_data.get("world_id", sv_dict.get("world_id", 1)))
	if w_id < 1 or w_id > WORLDS_COUNT:
		w_id = 1
	var state: Dictionary = w_data.get("state", {}) if typeof(w_data.get("state")) == TYPE_DICTIONARY else {}
	var world_dict: Dictionary = state.get("world", {}) if typeof(state.get("world")) == TYPE_DICTIONARY else {}
	var tiles: Dictionary = world_dict.get("tiles", {}) if typeof(world_dict.get("tiles")) == TYPE_DICTIONARY else {}
	var villages_list: Array = state.get("villages", []) if typeof(state.get("villages")) == TYPE_ARRAY else []

	var sv_id := int(sv_dict.get("id", 51))
	var vx := int(sv_dict.get("x", 100))
	var vy := int(sv_dict.get("y", 100))
	var v_name := str(sv_dict.get("name", "Başkent"))
	var player_v := VillageModelScript.create(sv_id, v_name, vx, vy, p_name, false)
	player_v["is_bot"] = false
	player_v["is_barbarian"] = false
	if typeof(sv_dict.get("buildings")) == TYPE_DICTIONARY and not (sv_dict["buildings"] as Dictionary).is_empty():
		player_v["buildings"] = (sv_dict["buildings"] as Dictionary).duplicate(true)
	if typeof(sv_dict.get("resources")) == TYPE_DICTIONARY and not (sv_dict["resources"] as Dictionary).is_empty():
		player_v["resources"] = (sv_dict["resources"] as Dictionary).duplicate(true)
	if typeof(sv_dict.get("units")) == TYPE_DICTIONARY and not (sv_dict["units"] as Dictionary).is_empty():
		player_v["units"] = (sv_dict["units"] as Dictionary).duplicate(true)
	player_v["points"] = int(sv_dict.get("points", player_v.get("points", 110)))
	var prot_u := int(sv_dict.get("protection_until_unix", 0))
	player_v["protection_until_unix"] = prot_u
	player_v["conquest_protection_until_unix"] = int(sv_dict.get("conquest_protection_until_unix", 0))
	var sv_created := int(sv_dict.get("created_unix", res_data.get("created_unix", 0)))
	if sv_created <= 0 and prot_u > (15 * 86400):
		sv_created = prot_u - (15 * 86400)
	var sv_boost_until := int(sv_dict.get("starter_boost_until_unix", res_data.get("starter_boost_until_unix", 0)))
	if sv_boost_until <= 0 and sv_created > 0:
		sv_boost_until = sv_created + (7 * 86400)
	if sv_created > 0:
		player_v["created_unix"] = sv_created
	if sv_boost_until > 0:
		player_v["starter_boost_until_unix"] = sv_boost_until

	var cleaned_vills: Array = []
	for existing_v in villages_list:
		if typeof(existing_v) == TYPE_DICTIONARY and int((existing_v as Dictionary).get("id", -1)) == sv_id:
			continue
		cleaned_vills.append(existing_v)
	cleaned_vills.append(player_v)

	tiles[WorldGeneratorScript.tile_key(vx, vy)] = sv_id
	world_dict["tiles"] = tiles
	world_dict["villages"] = cleaned_vills
	state["villages"] = cleaned_vills
	state["world"] = world_dict
	state["active_village_id"] = sv_id
	_ensure_starter_boost(state, sv_created, int(Time.get_unix_time_from_system()), p_name)
	w_data["state"] = state
	_clear_defeated_info_for_player(w_data, p_name)
	_enforce_min_village_distance(w_data, sv_id)
	var reg_list: Array = w_data.get("registered_real_players", []) if typeof(w_data.get("registered_real_players")) == TYPE_ARRAY else []
	if not (p_name in reg_list):
		reg_list.append(p_name)
		w_data["registered_real_players"] = reg_list
	w_data["last_saved_unix"] = maxi(int(w_data.get("last_saved_unix", 0)), int(sv_dict.get("last_calc_unix", Time.get_unix_time_from_system())))
	return true


func apply_cloud_sync(res_data: Dictionary, from_save_response: bool = false, req_seq: int = -1) -> bool:
	if _suppress_reset_save:
		return false
	var loop = Engine.get_main_loop()
	var auth = loop.root.get_node_or_null("AuthManager") if loop is SceneTree else null
	if from_save_response and auth != null and not bool(auth.is_logged_in):
		return false
	var raw_name: String = str(auth.display_name) if (auth != null and not str(auth.display_name).is_empty()) else str(res_data.get("display_name", "Lord Gorkem"))
	var p_name := _norm_name(raw_name)
	if p_name.is_empty():
		p_name = "Lord Gorkem"

	if res_data.has("worlds_meta"):
		_sync_worlds_meta_from_server(res_data.get("worlds_meta", []))

	var gs_sync := _find_game_state()
	var wallet_locked_now := (int(Time.get_unix_time_from_system()) < _wallet_lock_until_unix)
	if gs_sync != null and not from_save_response and not wallet_locked_now:
		if res_data.has("diamonds") and res_data.get("diamonds") != null:
			gs_sync.player["diamonds"] = maxi(0, int(res_data.get("diamonds", 35)))
		if typeof(res_data.get("scrolls")) == TYPE_DICTIONARY:
			gs_sync.player["scrolls"] = (res_data.get("scrolls") as Dictionary).duplicate(true)
		if res_data.has("diamonds") or res_data.has("scrolls"):
			gs_sync._emit_state_changed()

	var raw_cs = res_data.get("cloud_state", null)
	if raw_cs == null and res_data.has("state"):
		raw_cs = res_data.get("state", null)

	if typeof(raw_cs) == TYPE_DICTIONARY and not (raw_cs as Dictionary).is_empty():
		var cs_dict: Dictionary = raw_cs
		var w_id := int(cs_dict.get("world_id", cs_dict.get("world", {}).get("world_id", 1)))
		if w_id < 1 or w_id > WORLDS_COUNT:
			w_id = 1
		var cloud_w: Dictionary
		if cs_dict.has("state") and typeof(cs_dict.get("state")) == TYPE_DICTIONARY:
			cloud_w = cs_dict.duplicate(true)
		else:
			cloud_w = {
				"world_id": w_id,
				"world_name": "Dünya %d" % w_id,
				"seed": BASE_SEED + w_id,
				"created_unix": int(res_data.get("updated_unix", Time.get_unix_time_from_system())),
				"last_saved_unix": int(res_data.get("updated_unix", Time.get_unix_time_from_system())),
				"registered_real_players": [p_name],
				"state": cs_dict.duplicate(true),
			}
		var local_w := load_world_dict(w_id)
		var local_has := has_player_village(w_id, p_name)
		var local_ts := int(local_w.get("last_saved_unix", 0))
		var cloud_ts := int(cloud_w.get("last_saved_unix", res_data.get("updated_unix", 0)))

		# Anlık RAM GameState verisini yerel snapshot'a bindir ki az önce yapılan yükseltme/isim değişikliği disk gecikmesi yüzünden ezilmesin
		var effective_local_w := local_w.duplicate(true)
		var effective_local_ts := local_ts
		if gs_sync != null and gs_sync.has_active_village() and w_id == current_world_id:
			if effective_local_w.is_empty():
				effective_local_w = {
					"world_id": w_id,
					"world_name": "Dünya %d" % w_id,
					"seed": BASE_SEED + w_id,
					"last_saved_unix": int(Time.get_unix_time_from_system()),
					"registered_real_players": [p_name],
					"state": gs_sync.to_dict(),
				}
			else:
				effective_local_w["state"] = gs_sync.to_dict()
			effective_local_ts = maxi(local_ts, _last_local_mutation_unix)

		var merged_w := _merge_shared_world_data(effective_local_w, cloud_w, p_name, effective_local_ts, cloud_ts, from_save_response, req_seq)
		var cloud_had_player_v := _world_has_player_village_in_dict(cloud_w, p_name)
		var sv_fallback = res_data.get("server_village", null)
		if not _world_has_player_village_in_dict(merged_w, p_name) and typeof(sv_fallback) == TYPE_DICTIONARY and not (sv_fallback as Dictionary).is_empty() and not _world_has_conquest_defeat_in_dict(merged_w, p_name):
			_inject_server_village_into_world(merged_w, sv_fallback as Dictionary, p_name, res_data)
		if _world_has_player_village_in_dict(merged_w, p_name):
			_clear_defeated_info_for_player(merged_w, p_name)

		_deduplicate_player_starter_villages(merged_w)
		_enforce_min_village_distance(merged_w)
		save_world_dict(w_id, merged_w)
		var reg_arr: Array = merged_w.get("registered_real_players", []) if typeof(merged_w.get("registered_real_players")) == TYPE_ARRAY else []
		_sync_worlds_meta_from_server(res_data.get("worlds_meta", []), w_id, reg_arr.size())

		if not local_has and has_player_village(w_id, p_name):
			current_world_id = w_id
			_save_meta()

		_live_sync_game_state_from_world(merged_w, p_name)

		if gs_sync != null and not from_save_response and not wallet_locked_now:
			if res_data.has("diamonds") and res_data.get("diamonds") != null:
				gs_sync.player["diamonds"] = maxi(0, int(res_data.get("diamonds", 35)))
			if typeof(res_data.get("scrolls")) == TYPE_DICTIONARY:
				gs_sync.player["scrolls"] = (res_data.get("scrolls") as Dictionary).duplicate(true)
			if res_data.has("diamonds") or res_data.has("scrolls"):
				gs_sync._emit_state_changed()

		var has_newer_mut := (req_seq >= 0 and _local_mutation_seq > req_seq)
		var merged_has_player_v := _world_has_player_village_in_dict(merged_w, p_name)
		var needs_cloud_recover := ((local_has or merged_has_player_v) and not cloud_had_player_v and not _world_has_conquest_defeat_in_dict(cloud_w, p_name))
		if ((not from_save_response or has_newer_mut) and local_has and (effective_local_ts > cloud_ts or has_newer_mut)) or needs_cloud_recover:
			if _cloud_enabled() and loop is SceneTree:
				var net = loop.root.get_node_or_null("NetworkManager")
				if net != null and not str(net.auth_token).is_empty():
					_last_cloud_save_unix = int(Time.get_unix_time_from_system())
					_last_cloud_save_seq = _local_mutation_seq
					net.save_state_to_cloud(net.auth_token, merged_w, Callable(), _local_mutation_seq)
		return true

	var sv = res_data.get("server_village", null)
	if typeof(sv) == TYPE_DICTIONARY and not (sv as Dictionary).is_empty():
		var sv_dict: Dictionary = sv
		var w_id := int(sv_dict.get("world_id", 1))
		if w_id < 1 or w_id > WORLDS_COUNT:
			w_id = 1
		if has_player_village(w_id, p_name):
			return false
		var w_data := load_world_dict(w_id)
		if w_data.is_empty():
			w_data = _create_and_save_world(w_id, BASE_SEED + w_id, BOTS_PER_WORLD)
		_inject_server_village_into_world(w_data, sv_dict, p_name, res_data)
		save_world_dict(w_id, w_data)
		current_world_id = w_id
		_save_meta()
		return true

	# Sunucu henüz hiç dünya kaydı içermiyorsa ve oyuncunun yerelde bir köyü varsa buluta yükle
	if not from_save_response and has_player_village(current_world_id, p_name) and _cloud_enabled() and loop is SceneTree:
		var local_cur := load_world_dict(current_world_id)
		var net = loop.root.get_node_or_null("NetworkManager")
		if not local_cur.is_empty() and net != null and not str(net.auth_token).is_empty():
			_last_cloud_save_unix = int(Time.get_unix_time_from_system())
			net.save_state_to_cloud(net.auth_token, local_cur)

	return false


var game_state: Node = null


## Haritadaki tüm köylerin birbirine en az MIN_VILLAGE_DISTANCE mesafede olmasını sağlar.
## Önce öncelikli köy ve gerçek oyuncu köylerini yerleştirir; çakışan bot/barbar köyleri boş alana kaydırır.
func _enforce_min_village_distance(w_data: Dictionary, priority_vid: int = -1) -> bool:
	var state_val = w_data.get("state", {})
	if typeof(state_val) != TYPE_DICTIONARY:
		return false
	var state: Dictionary = state_val
	var villages_val = state.get("villages", [])
	if typeof(villages_val) != TYPE_ARRAY:
		return false
	var villages_list: Array = villages_val
	var world_val = state.get("world", {})
	if typeof(world_val) != TYPE_DICTIONARY:
		world_val = {}
		state["world"] = world_val
	var world_dict: Dictionary = world_val

	var world_size: int = int(world_dict.get("size", WorldGeneratorScript.SIZE))
	var min_dist: int = WorldGeneratorScript.MIN_VILLAGE_DISTANCE

	var ordered: Array = []
	for v in villages_list:
		if typeof(v) == TYPE_DICTIONARY and int(v.get("id", -1)) == priority_vid:
			ordered.append(v)
	for v in villages_list:
		if typeof(v) == TYPE_DICTIONARY and int(v.get("id", -1)) != priority_vid:
			if not bool(v.get("is_bot", false)) and not bool(v.get("is_barbarian", false)):
				ordered.append(v)
	for v in villages_list:
		if typeof(v) == TYPE_DICTIONARY and int(v.get("id", -1)) != priority_vid:
			if bool(v.get("is_bot", false)) or bool(v.get("is_barbarian", false)):
				ordered.append(v)

	var placed_tiles: Dictionary = {}
	var changed := false
	for v in ordered:
		var vd: Dictionary = v
		var vid := int(vd.get("id", 0))
		var vx := clampi(int(vd.get("x", 1)), 1, world_size)
		var vy := clampi(int(vd.get("y", 1)), 1, world_size)
		if not WorldGeneratorScript.is_spot_free_dist(placed_tiles, vx, vy, min_dist, world_size):
			var new_spot := WorldGeneratorScript.find_free_spot_with_dist(placed_tiles, vx, vy, min_dist, world_size)
			if new_spot.x < 1:
				new_spot = WorldGeneratorScript.find_free_spot_with_dist(placed_tiles, vx, vy, 1, world_size)
			if new_spot.x >= 1 and (new_spot.x != vx or new_spot.y != vy):
				vx = new_spot.x
				vy = new_spot.y
				vd["x"] = vx
				vd["y"] = vy
				changed = true
		placed_tiles[WorldGeneratorScript.tile_key(vx, vy)] = vid

	world_dict["tiles"] = placed_tiles
	world_dict["villages"] = villages_list
	return changed


## Her gerçek oyuncu için fethedilmemiş başlangıç köyü sayısını 1 ile sınırlar, id <= 0 geçersiz köyleri temizler.
func _deduplicate_player_starter_villages(w_data: Dictionary, preferred_vid: int = -1) -> bool:
	var state_val = w_data.get("state", {})
	if typeof(state_val) != TYPE_DICTIONARY:
		return false
	var state: Dictionary = state_val
	var villages_val = state.get("villages", [])
	if typeof(villages_val) != TYPE_ARRAY:
		return false
	var villages_list: Array = villages_val
	var changed := false

	var conquered_vids: Dictionary = {}
	var reps = state.get("reports", [])
	if typeof(reps) == TYPE_ARRAY:
		for r in (reps as Array):
			if typeof(r) == TYPE_DICTIONARY and str((r as Dictionary).get("type", "")) == "battle":
				var rdata = (r as Dictionary).get("data", {})
				if typeof(rdata) == TYPE_DICTIONARY and bool((rdata as Dictionary).get("conquered", false)):
					var tvid := int((rdata as Dictionary).get("target_village_id", -1))
					if tvid > 0:
						conquered_vids[tvid] = true

	var starters_by_owner: Dictionary = {}
	var clean_list: Array = []
	for item in villages_list:
		if typeof(item) != TYPE_DICTIONARY:
			changed = true
			continue
		var vd := item as Dictionary
		var vid := int(vd.get("id", 0))
		if vid <= 0:
			changed = true
			continue
		clean_list.append(vd)
		if _is_real_player_village_dict(vd):
			var ok := _norm_name(str(vd.get("owner", ""))).to_lower()
			var is_conq := conquered_vids.has(vid) or bool(vd.get("is_conquered", false)) or not str(vd.get("conquered_by", "")).is_empty()
			if not ok.is_empty() and not is_conq:
				if not starters_by_owner.has(ok):
					starters_by_owner[ok] = []
				(starters_by_owner[ok] as Array).append(vd)

	var drop_vids: Dictionary = {}
	var canonical_by_owner: Dictionary = {}
	for ok in starters_by_owner.keys():
		var arr: Array = starters_by_owner[ok]
		if arr.size() <= 1:
			canonical_by_owner[ok] = int((arr[0] as Dictionary).get("id", -1))
			continue
		changed = true
		var best_v: Dictionary = arr[0]
		for cand in arr:
			var cv := cand as Dictionary
			var cv_id := int(cv.get("id", 0))
			var bv_id := int(best_v.get("id", 0))
			if preferred_vid > 0 and cv_id == preferred_vid:
				best_v = cv
				break
			var cv_pts := int(cv.get("points", 110))
			var bv_pts := int(best_v.get("points", 110))
			if cv_pts > bv_pts or (cv_pts == bv_pts and cv_id < bv_id):
				best_v = cv
		var keep_id := int(best_v.get("id", -1))
		canonical_by_owner[ok] = keep_id
		for cand in arr:
			var cv_id := int((cand as Dictionary).get("id", -1))
			if cv_id != keep_id:
				drop_vids[cv_id] = true

	if changed or clean_list.size() != villages_list.size():
		var final_villages: Array = []
		var tiles: Dictionary = {}
		for v in clean_list:
			var vd := v as Dictionary
			var vid := int(vd.get("id", -1))
			if drop_vids.has(vid):
				continue
			final_villages.append(vd)
			tiles[WorldGeneratorScript.tile_key(int(vd.get("x", 1)), int(vd.get("y", 1)))] = vid
		state["villages"] = final_villages
		var w_dict = state.get("world", {})
		if typeof(w_dict) == TYPE_DICTIONARY:
			(w_dict as Dictionary)["villages"] = final_villages
			(w_dict as Dictionary)["tiles"] = tiles
		var cur_aid := int(state.get("active_village_id", -1))
		if drop_vids.has(cur_aid):
			var p_obj = state.get("player", {})
			var pname := _norm_name(str((p_obj as Dictionary).get("name", ""))).to_lower() if typeof(p_obj) == TYPE_DICTIONARY else ""
			if canonical_by_owner.has(pname):
				state["active_village_id"] = int(canonical_by_owner[pname])
	return changed


func _on_village_conquered_signal(vid: int, new_owner: String) -> void:
	var gs = _find_game_state()
	if gs == null:
		return
	var p_name := _norm_name(str(gs.player.get("name", "")))
	if p_name.is_empty() or p_name == "Kral":
		var auth = _find_autoload("AuthManager")
		if auth != null and not str(auth.display_name).is_empty():
			p_name = _norm_name(str(auth.display_name))
	if p_name.is_empty() or _matches_player(new_owner, p_name):
		return

	var remaining_owned := 0
	var conq_vx := -1
	var conq_vy := -1
	for v in gs.villages:
		if typeof(v) != TYPE_DICTIONARY:
			continue
		var vd: Dictionary = v
		if int(vd.get("id", -1)) == vid:
			conq_vx = int(vd.get("x", -1))
			conq_vy = int(vd.get("y", -1))
		if _is_real_player_village_dict(vd) and _matches_player(str(vd.get("owner", "")), p_name):
			remaining_owned += 1

	if remaining_owned > 0:
		return
	if gs.active_village_id != vid and not is_player_conquered(current_world_id, p_name):
		return

	if typeof(gs.world) != TYPE_DICTIONARY:
		gs.world = {}
	if typeof(gs.world.get("player_profiles")) != TYPE_DICTIONARY:
		gs.world["player_profiles"] = {}
	var profiles: Dictionary = gs.world["player_profiles"]
	var prof: Dictionary = profiles.get(p_name, {}) if typeof(profiles.get(p_name)) == TYPE_DICTIONARY else {}
	prof["defeated_info"] = {
		"conqueror": str(new_owner).strip_edges(),
		"village_id": vid,
		"x": conq_vx,
		"y": conq_vy,
		"unix": int(Time.get_unix_time_from_system()),
	}
	prof["active_village_id"] = -1
	prof["points"] = 0
	profiles[p_name] = prof

	gs.active_village_id = -1
	gs.player["points"] = 0
	suppress_auto_conquered_prompt = false
	save_active_world()

	var bus = _find_autoload("EventBus")
	if bus != null and bus.has_signal("player_conquered"):
		bus.player_conquered.emit(current_world_id, p_name)
	maybe_show_conquered_modal_for_current_scene(current_world_id, p_name, str(new_owner))


func maybe_show_conquered_modal_for_current_scene(world_id: int = -1, player_name: String = "", conqueror_name: String = "") -> bool:
	var loop = Engine.get_main_loop()
	if not (loop is SceneTree):
		return false
	var tree := loop as SceneTree
	if tree.current_scene == null:
		return false
	var s_name := str(tree.current_scene.name)
	var allowed_scenes := ["Village", "WorldMap", "Reports", "Ranking", "Alliance", "Settings", "VillageSelect"]
	if not (s_name in allowed_scenes):
		return false

	var wid := world_id if world_id > 0 else current_world_id
	var p_name := _norm_name(player_name)
	if p_name.is_empty():
		var auth = _find_autoload("AuthManager")
		if auth != null and not str(auth.display_name).is_empty():
			p_name = _norm_name(str(auth.display_name))
	if p_name.is_empty():
		var gs = _find_game_state()
		if gs != null:
			p_name = _norm_name(str(gs.player.get("name", "")))
	if p_name.is_empty():
		return false

	if s_name == "VillageSelect" and suppress_auto_conquered_prompt:
		return false

	if has_player_village(wid, p_name):
		return false
	if not is_player_conquered(wid, p_name) and conqueror_name.strip_edges().is_empty():
		return false

	var def_info := get_last_defeat_info(wid, p_name)
	var conq_by := conqueror_name.strip_edges()
	if conq_by.is_empty():
		conq_by = str(def_info.get("conqueror", "")).strip_edges()
	ConqueredModalScript.show_modal(wid, p_name, conq_by)
	return true


func _find_game_state() -> Node:
	if game_state != null and is_instance_valid(game_state):
		return game_state
	var loop = Engine.get_main_loop()
	if loop is SceneTree and loop.root != null:
		var n = loop.root.get_node_or_null("GameState")
		if n != null:
			game_state = n
			return n
	if is_inside_tree() and get_tree() != null and get_tree().root != null:
		var n = get_tree().root.get_node_or_null("GameState")
		if n != null:
			game_state = n
			return n
	if get_parent() != null:
		var p_node = get_parent().get_node_or_null("GameState")
		if p_node != null:
			game_state = p_node
			return p_node
	return null


func wipe_all_local_data() -> void:
	_suppress_reset_save = true
	_cloud_poll_in_flight = false
	_cloud_poll_accum = 0.0
	_local_mutation_seq += 1000
	_last_cloud_save_seq = _local_mutation_seq
	_last_local_mutation_unix = 0
	_last_cloud_save_unix = 0
	_last_autosave_unix = 0
	_wallet_lock_until_unix = 0
	_recent_teardown_until_unix = 0
	suppress_auto_conquered_prompt = true

	if DirAccess.dir_exists_absolute(WORLDS_DIR):
		var d := DirAccess.open(WORLDS_DIR)
		if d != null:
			d.list_dir_begin()
			var fname := d.get_next()
			while fname != "":
				if not d.current_is_dir():
					DirAccess.remove_absolute(ProjectSettings.globalize_path(WORLDS_DIR.path_join(fname)))
				fname = d.get_next()
			d.list_dir_end()

	for path in [
		META_FILE,
		"user://savegame.json",
		"user://taht_ve_kilic_save.json",
		"user://taht_ve_kilic_config.json",
		"user://auth_session.json",
		"user://account_profiles.json",
	]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	if OS.has_feature("web"):
		JavaScriptBridge.eval("""
(function(){
  try {
    var keys = [];
    for (var i = 0; i < window.localStorage.length; i++) {
      var k = window.localStorage.key(i);
      if (k && k.indexOf('tvk_') === 0 && k !== 'tvk_client_reset_epoch') {
        keys.push(k);
      }
    }
    keys.forEach(function(k){ window.localStorage.removeItem(k); });
    if (typeof FS !== 'undefined' && FS.syncfs) { FS.syncfs(false, function(){}); }
  } catch(e) {}
})();
""", true)

	var cfg := _find_autoload("GameConfig")
	if cfg != null and cfg.has_method("apply_profile"):
		cfg.call("apply_profile", "tr")

	var tut := _find_autoload("TutorialManager")
	if tut != null:
		tut.set("_active", false)
		tut.set("_shown_step", -1)
		tut.set("_shown_substate", "")
		tut.set("_victory_reward_granted", false)
		if tut.has_method("_set_overlay_visible"):
			tut.call("_set_overlay_visible", false)

	var net := _find_autoload("NetworkManager")
	if net != null:
		net.auth_token = ""

	var gs = _find_game_state()
	if gs != null and gs.has_method("reset"):
		gs.reset()

	reset_all_worlds()
	suppress_auto_conquered_prompt = false
	_suppress_reset_save = false

