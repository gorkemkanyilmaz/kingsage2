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
const WEB_META_KEY := "tvk_worlds_meta"
const WEB_WORLD_PREFIX := "tvk_world_"

var current_world_id: int = 1
var worlds_meta: Array = []
var _last_autosave_unix: int = 0
var _last_cloud_save_unix: int = 0

const CLOUD_POLL_INTERVAL_SEC := 8.0
var _cloud_poll_accum: float = 0.0
var _cloud_poll_in_flight: bool = false
var _last_local_mutation_unix: int = 0
var _is_applying_cloud_sync: bool = false
var suppress_auto_conquered_prompt: bool = false


func _ready() -> void:
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


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		var gs = _find_game_state()
		if gs != null and gs.has_active_village():
			save_active_world()


func _on_state_changed_autosave() -> void:
	if _is_applying_cloud_sync:
		return
	var now := int(Time.get_unix_time_from_system())
	_last_local_mutation_unix = now
	if now - _last_autosave_unix < 3:
		return
	var gs = _find_game_state()
	if gs != null and gs.has_active_village():
		_last_autosave_unix = now
		save_active_world()


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
	while n.begins_with("Lord Lord "):
		n = n.substr(5)
	return n


func _matches_player(owner: String, target: String) -> bool:
	var a := _norm_name(owner)
	var b := _norm_name(target)
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
	var gen_world: Dictionary = WorldGeneratorScript.generate(seed_val, bot_count, WorldGeneratorScript.SIZE)
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
	if gs != null and current_world_id == world_id and int(gs.world.get("world_id", -1)) == world_id and _matches_player(str(gs.player.get("name", "")), player_name) and gs.villages != null and not gs.villages.is_empty():
		for v in gs.villages:
			if typeof(v) != TYPE_DICTIONARY:
				continue
			var v_dict: Dictionary = v
			if bool(v_dict.get("is_bot", false)) or bool(v_dict.get("is_barbarian", false)):
				continue
			if _matches_player(str(v_dict.get("owner", "")), player_name):
				return true
		return false

	var w_data := load_world_dict(world_id)
	if w_data.is_empty():
		return false
	var state: Dictionary = w_data.get("state", {})
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


## Oyuncu dünyada daha önce kayıt olmuş ama tüm köyleri fethedilmiş mi?
func is_player_conquered(world_id: int, player_name: String) -> bool:
	var w_data := load_world_dict(world_id)
	if w_data.is_empty():
		return false
	var norm_p := _norm_name(player_name)
	var reg_list: Array = w_data.get("registered_real_players", [])
	for reg_name in reg_list:
		if _norm_name(str(reg_name)) == norm_p:
			return not has_player_village(world_id, norm_p)
	return false


## Oyuncunun en son hangi koordinatta ve kim tarafından fethedildiğini döndürür.
func get_last_defeat_info(world_id: int, player_name: String) -> Dictionary:
	var norm_p := _norm_name(player_name)
	var w_data := load_world_dict(world_id)
	if w_data.is_empty() or norm_p.is_empty():
		return {}
	var state: Dictionary = w_data.get("state", {}) if typeof(w_data.get("state")) == TYPE_DICTIONARY else {}
	var w_dict: Dictionary = state.get("world", {}) if typeof(state.get("world")) == TYPE_DICTIONARY else {}
	var profiles: Dictionary = w_dict.get("player_profiles", {}) if typeof(w_dict.get("player_profiles")) == TYPE_DICTIONARY else {}
	for pk in profiles.keys():
		if _matches_player(str(pk), norm_p) and typeof(profiles[pk]) == TYPE_DICTIONARY:
			var di = (profiles[pk] as Dictionary).get("defeated_info", {})
			if typeof(di) == TYPE_DICTIONARY and not (di as Dictionary).is_empty():
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
		if _matches_player(str(data.get("defender_name", "")), norm_p):
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
					"conqueror": str(data.get("attacker_name", "")),
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

	var ok := join_world(world_id, norm_p, chosen_x, chosen_y, prev_spot)
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


## Oyuncunun bir dünyaya katılması (yeni köy açılması).
func join_world(world_id: int, player_name: String, target_x: int = 100, target_y: int = 100, avoid_spot: Vector2i = Vector2i(-1, -1)) -> bool:
	player_name = _norm_name(player_name)
	if player_name.is_empty():
		player_name = "Lord Gorkem"

	var w_meta := get_world_meta(world_id)
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
		"tutorial_step": 0,
		"quests": {"claimed": [], "stats": {}},
		"gold_armour": 0,
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
		if typeof(m) == TYPE_DICTIONARY and str(m.get("to", "")) == player_name and str(m.get("subject", "")).contains("Hoş Geldiniz"):
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
	var quests_copy: Dictionary = {"claimed": [], "stats": {}}
	if typeof(p.get("quests")) == TYPE_DICTIONARY:
		quests_copy = (p["quests"] as Dictionary).duplicate(true)
	var prof := {
		"name": p_name,
		"provider": str(p.get("provider", "")),
		"auth_id": str(p.get("auth_id", "")),
		"points": int(p.get("points", 0)),
		"created_unix": int(p.get("created_unix", 0)),
		"starter_boost_until_unix": int(p.get("starter_boost_until_unix", 0)),
		"protection_until_unix": int(p.get("protection_until_unix", 0)),
		"conquest_protection_until_unix": int(p.get("conquest_protection_until_unix", 0)),
		"tutorial_completed": bool(p.get("tutorial_completed", false)),
		"tutorial_step": int(p.get("tutorial_step", 0)),
		"tutorial_reward_claimed": bool(p.get("tutorial_reward_claimed", false)),
		"quests": quests_copy,
		"gold_armour": int(p.get("gold_armour", 0)),
		"active_village_id": int(state_dict.get("active_village_id", -1)),
	}
	profiles[p_name] = prof


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
		"tutorial_completed": bool(found.get("tutorial_completed", false)),
		"tutorial_step": int(found.get("tutorial_step", 0)),
		"tutorial_reward_claimed": bool(found.get("tutorial_reward_claimed", false)),
		"quests": q_dict,
		"gold_armour": int(found.get("gold_armour", 0)),
		"premium": false,
	}
	state_dict["player"] = restored


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


## Anlık GameState'i aktif dünya dosyasına kaydeder.
func save_active_world() -> bool:
	var gs = _find_game_state()
	if gs == null:
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
	if typeof(prev_world.get("player_starter_boost")) == TYPE_DICTIONARY:
		var merged_b: Dictionary = (prev_world["player_starter_boost"] as Dictionary).duplicate(true)
		if typeof(nw.get("player_starter_boost")) == TYPE_DICTIONARY:
			for k in (nw["player_starter_boost"] as Dictionary).keys():
				merged_b[k] = nw["player_starter_boost"][k]
		nw["player_starter_boost"] = merged_b
	_sync_player_profile_to_world(next_state)

	w_data["last_saved_unix"] = now
	w_data["state"] = next_state

	var p_name := str(gs.player.get("name", "Lord Gorkem"))
	var reg_list: Array = w_data.get("registered_real_players", [])
	if not (p_name in reg_list):
		reg_list.append(p_name)
		w_data["registered_real_players"] = reg_list

	var ok := save_world_dict(current_world_id, w_data)
	if ok and _cloud_enabled() and Engine.get_main_loop() is SceneTree:
		var net = Engine.get_main_loop().root.get_node_or_null("NetworkManager")
		if net != null and not str(net.auth_token).is_empty() and (now - _last_cloud_save_unix) >= 3:
			_last_cloud_save_unix = now
			net.save_state_to_cloud(net.auth_token, w_data)
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


func _merge_shared_world_data(local_w: Dictionary, cloud_w: Dictionary, p_name: String, local_ts: int, cloud_ts: int, from_save_response: bool) -> Dictionary:
	if local_w.is_empty() or not has_player_village(int(cloud_w.get("world_id", 1)), p_name):
		return cloud_w.duplicate(true)

	# Eğer sunucu bu kaydedişten hemen sonra döndüyse ve yerel ekstra mutasyon olmadıysa sunucunun ortak dünyası kanoniktir.
	if from_save_response and _last_local_mutation_unix <= _last_cloud_save_unix:
		return cloud_w.duplicate(true)

	# Yerel değişiklik sunucudan eskiyse veya eşitse doğrudan ortak dünyayı al.
	if cloud_ts >= local_ts and not from_save_response:
		return cloud_w.duplicate(true)

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

	# Kendi yerel profilimizi koru, diğer profilleri sunucudan tut
	var m_world: Dictionary = m_state.get("world", {}) if typeof(m_state.get("world")) == TYPE_DICTIONARY else {}
	var l_world: Dictionary = l_state.get("world", {}) if typeof(l_state.get("world")) == TYPE_DICTIONARY else {}
	if typeof(l_world.get("player_profiles")) == TYPE_DICTIONARY and typeof(m_world.get("player_profiles")) == TYPE_DICTIONARY:
		for pk in (l_world["player_profiles"] as Dictionary).keys():
			if _matches_player(str(pk), p_name):
				m_world["player_profiles"][pk] = (l_world["player_profiles"][pk] as Dictionary).duplicate(true)
	if typeof(l_state.get("player")) == TYPE_DICTIONARY and not (l_state["player"] as Dictionary).is_empty():
		m_state["player"] = (l_state["player"] as Dictionary).duplicate(true)
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
	for pv in gs.villages:
		if _is_real_player_village_dict(pv) and _matches_player(str((pv as Dictionary).get("owner", "")), p_name):
			prev_owned = true
			break
	if not remote_villages.is_empty():
		gs.villages = remote_villages.duplicate(true)
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
	elif first_owned_vid < 0 and (prev_owned or is_player_conquered(w_id, p_name)):
		gs.active_village_id = -1
	gs.player["points"] = total_pts

	if typeof(st.get("alliances")) == TYPE_ARRAY:
		gs.alliances = (st["alliances"] as Array).duplicate(true)
	if typeof(st.get("movements")) == TYPE_ARRAY:
		gs.movements = (st["movements"] as Array).duplicate(true)
	if typeof(st.get("messages")) == TYPE_ARRAY:
		gs.messages = (st["messages"] as Array).duplicate(true)
	if typeof(st.get("reports")) == TYPE_ARRAY:
		gs.reports = (st["reports"] as Array).duplicate(true)
	if typeof(st.get("world")) == TYPE_DICTIONARY:
		var rw: Dictionary = st["world"]
		if typeof(rw.get("tiles")) == TYPE_DICTIONARY:
			gs.world["tiles"] = (rw["tiles"] as Dictionary).duplicate(true)
		if typeof(rw.get("player_profiles")) == TYPE_DICTIONARY:
			gs.world["player_profiles"] = (rw["player_profiles"] as Dictionary).duplicate(true)
		if typeof(rw.get("player_starter_boost")) == TYPE_DICTIONARY:
			gs.world["player_starter_boost"] = (rw["player_starter_boost"] as Dictionary).duplicate(true)
		gs.world["villages"] = gs.villages
	gs._emit_state_changed()
	_is_applying_cloud_sync = false
	if first_owned_vid < 0 and (prev_owned or is_player_conquered(w_id, p_name)):
		var bus = _find_autoload("EventBus")
		if bus != null and bus.has_signal("player_conquered"):
			bus.player_conquered.emit(w_id, p_name)
		maybe_show_conquered_modal_for_current_scene(w_id, p_name)


func apply_cloud_sync(res_data: Dictionary, from_save_response: bool = false) -> bool:
	var loop = Engine.get_main_loop()
	var auth = loop.root.get_node_or_null("AuthManager") if loop is SceneTree else null
	var raw_name: String = str(auth.display_name) if (auth != null and not str(auth.display_name).is_empty()) else str(res_data.get("display_name", "Lord Gorkem"))
	var p_name := _norm_name(raw_name)
	if p_name.is_empty():
		p_name = "Lord Gorkem"

	if res_data.has("worlds_meta"):
		_sync_worlds_meta_from_server(res_data.get("worlds_meta", []))

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

		var merged_w := _merge_shared_world_data(local_w, cloud_w, p_name, local_ts, cloud_ts, from_save_response)
		_enforce_min_village_distance(merged_w)
		save_world_dict(w_id, merged_w)
		var reg_arr: Array = merged_w.get("registered_real_players", []) if typeof(merged_w.get("registered_real_players")) == TYPE_ARRAY else []
		_sync_worlds_meta_from_server(res_data.get("worlds_meta", []), w_id, reg_arr.size())

		if not local_has and has_player_village(w_id, p_name):
			current_world_id = w_id
			_save_meta()

		_live_sync_game_state_from_world(merged_w, p_name)

		if not from_save_response and local_has and local_ts > cloud_ts and _cloud_enabled() and loop is SceneTree:
			var net = loop.root.get_node_or_null("NetworkManager")
			if net != null and not str(net.auth_token).is_empty():
				_last_cloud_save_unix = int(Time.get_unix_time_from_system())
				net.save_state_to_cloud(net.auth_token, merged_w)
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
		var state: Dictionary = w_data.get("state", {})
		var world_dict: Dictionary = state.get("world", {})
		var tiles: Dictionary = world_dict.get("tiles", {})
		var villages_list: Array = state.get("villages", [])

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

		villages_list.append(player_v)
		tiles[WorldGeneratorScript.tile_key(vx, vy)] = sv_id
		world_dict["tiles"] = tiles
		world_dict["villages"] = villages_list
		state["villages"] = villages_list
		state["world"] = world_dict
		state["active_village_id"] = sv_id
		_ensure_starter_boost(state, sv_created, int(Time.get_unix_time_from_system()), p_name)
		w_data["state"] = state
		_enforce_min_village_distance(w_data, sv_id)
		var reg_list: Array = w_data.get("registered_real_players", [])
		if not (p_name in reg_list):
			reg_list.append(p_name)
			w_data["registered_real_players"] = reg_list
		w_data["last_saved_unix"] = int(sv_dict.get("last_calc_unix", Time.get_unix_time_from_system()))
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

