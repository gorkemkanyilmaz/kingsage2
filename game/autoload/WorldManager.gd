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


func _ready() -> void:
	_ensure_directory()
	if not _meta_exists():
		reset_all_worlds()
	else:
		_load_meta()
	_sync_save_fallback_to_world()
	var bus = Engine.get_main_loop().root.get_node_or_null("EventBus") if Engine.get_main_loop() is SceneTree else null
	if bus != null and bus.has_signal("state_changed") and not bus.state_changed.is_connected(_on_state_changed_autosave):
		bus.state_changed.connect(_on_state_changed_autosave)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		var gs = _find_game_state()
		if gs != null and gs.has_active_village():
			save_active_world()


func _on_state_changed_autosave() -> void:
	var now := int(Time.get_unix_time_from_system())
	if now - _last_autosave_unix < 3:
		return
	var gs = _find_game_state()
	if gs != null and gs.has_active_village():
		_last_autosave_unix = now
		save_active_world()


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
	gen_world["last_saved_unix"] = now
	gen_world["sim_now_unix"] = now
	gen_world["sim_time_seconds"] = 0.0

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


## Oyuncunun bir dünyaya katılması (yeni köy açılması).
func join_world(world_id: int, player_name: String, target_x: int = 100, target_y: int = 100) -> bool:
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

	# Seçilen bölgede (target_x, target_y) boş alan bul
	var free_spot: Vector2i = WorldGeneratorScript.find_free_spot(tiles, target_x, target_y, WorldGeneratorScript.SIZE)
	if free_spot.x < 0:
		free_spot = Vector2i(target_x, target_y)

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
	player_v["protection_until"] = now + (15 * 86400)
	player_v["protection_until_unix"] = now + (15 * 86400)
	player_v["conquest_protection_until"] = now + (15 * 86400)
	player_v["conquest_protection_until_unix"] = now + (15 * 86400)

	villages_list.append(player_v)
	tiles[WorldGeneratorScript.tile_key(free_spot.x, free_spot.y)] = player_vid
	world_dict["tiles"] = tiles
	world_dict["villages"] = villages_list
	state["villages"] = villages_list
	state["world"] = world_dict
	state["active_village_id"] = player_vid
	state["player"] = {
		"id": 1,
		"name": player_name,
		"points": int(player_v.get("points", 110)),
		"protection_until_unix": player_v["protection_until_unix"],
		"conquest_protection_until_unix": player_v["conquest_protection_until_unix"],
		"premium": false,
	}

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
	var sm = Engine.get_main_loop().root.get_node_or_null("SaveManager") if Engine.get_main_loop() is SceneTree else null
	if sm != null and sm.has_method("save_game"):
		sm.save_game()
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

	# Oyuncunun birincil aktif köyünü bul
	var player_vid := -1
	for v in villages:
		if typeof(v) == TYPE_DICTIONARY:
			var vd: Dictionary = v
			if not bool(vd.get("is_bot", false)) and not bool(vd.get("is_barbarian", false)):
				if _matches_player(str(vd.get("owner", "")), player_name):
					player_vid = int(vd.get("id", -1))
					break

	if player_vid < 0:
		return false

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


## Aktif dünya durumunu GameState'e aktarır.
func _apply_to_game_state(w_data: Dictionary, player_name: String, active_vid: int) -> void:
	var gs = _find_game_state()
	if gs == null:
		return

	var state: Dictionary = w_data.get("state", {})
	gs.from_dict(state)
	gs.player["name"] = player_name
	gs.player["id"] = 1
	gs.active_village_id = active_vid
	gs.world["world_id"] = current_world_id
	gs.world["world_name"] = "Dünya %d" % current_world_id

	# Oyuncunun toplam puanını hesapla
	var total_points := 0
	for v in gs.villages:
		if typeof(v) == TYPE_DICTIONARY:
			var vd: Dictionary = v
			if str(vd.get("owner", "")) == player_name:
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
	gs.world["sim_now_unix"] = now

	w_data["last_saved_unix"] = now
	w_data["state"] = gs.to_dict()

	var p_name := str(gs.player.get("name", "Lord Gorkem"))
	var reg_list: Array = w_data.get("registered_real_players", [])
	if not (p_name in reg_list):
		reg_list.append(p_name)
		w_data["registered_real_players"] = reg_list

	return save_world_dict(current_world_id, w_data)


var game_state: Node = null


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

