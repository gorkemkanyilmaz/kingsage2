extends Node
## SaveManager — yerel kaydet/yükle (Taht ve Kılıç).
##
## Tek oyunculu kayıt `user://` altında JSON olarak tutulur. Kayıt zarfı
## `saveVersion` alanı içerir; ileride şema değişince göç (migration) burada
## yapılır. Offline telafi için `savedAtUnix` damgası saklanır.

## Kayıt şeması sürümü. Şema değiştiğinde artırılır ve `_migrate()` güncellenir.
const SAVE_VERSION := 1

const SAVE_PATH := "user://taht_ve_kilic_save.json"


func _ready() -> void:
	pass


# --- Sorgu ------------------------------------------------------------------

func has_save() -> bool:
	var loop = Engine.get_main_loop()
	if loop is SceneTree:
		var wm = loop.root.get_node_or_null("WorldManager")
		var auth = loop.root.get_node_or_null("AuthManager")
		var p_name: String = auth.display_name if auth != null and not auth.display_name.is_empty() else "Lord Gorkem"
		if wm != null and wm.has_player_village(wm.current_world_id, p_name):
			return true
	return FileAccess.file_exists(SAVE_PATH)


func get_save_path() -> String:
	return SAVE_PATH


## Kayıt zarfının özet bilgilerini döndürür (yükleme yapmadan).
func get_save_meta() -> Dictionary:
	if not has_save():
		return {}
	if FileAccess.file_exists(SAVE_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
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

## Oyun durumunu ve ayarları kaydeder.
func save_game() -> bool:
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

	var loop = Engine.get_main_loop()
	if loop is SceneTree:
		var wm = loop.root.get_node_or_null("WorldManager")
		if wm != null and wm.has_method("save_active_world"):
			wm.save_active_world()

	var payload := {
		"saveVersion": SAVE_VERSION,
		"savedAtUnix": now,
		"savedAtIso": Time.get_datetime_string_from_system(),
		"state": gs.to_dict() if gs != null else {},
		"config": cfg.to_dict() if cfg != null else {},
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: kayıt dosyası açılamadı -> " + SAVE_PATH)
		if bus != null and bus.has_signal("error_occurred"):
			bus.error_occurred.emit("save_failed", "Kayıt dosyası yazılamadı.")
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()

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
		var p_name: String = auth.display_name if auth != null and not auth.display_name.is_empty() else "Lord Gorkem"
		if wm != null and wm.has_player_village(wm.current_world_id, p_name):
			return wm.enter_world(wm.current_world_id, p_name)

	if not FileAccess.file_exists(SAVE_PATH):
		return false

	var bus := _event_bus()
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
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
		for v in gs.villages:
			if typeof(v) == TYPE_DICTIONARY and (not bool(v.get("is_bot", true)) and not bool(v.get("is_barbarian", false))):
				if str(v.get("owner", "")) == "Kral" or str(v.get("owner", "")).is_empty():
					v["owner"] = p_name
		var saved_unix := int(parsed.get("savedAtUnix", 0))
		_apply_offline_catchup(gs, saved_unix)
	if cfg != null and typeof(parsed.get("config", {})) == TYPE_DICTIONARY:
		cfg.from_dict(parsed["config"])

	if bus != null and bus.has_signal("game_loaded"):
		bus.game_loaded.emit()
	return true


## Oyun kapalıyken geçen sürede hammadde üretimini, inşaat ve asker eğitim kuyruğunu telafi eder.
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

	# 1. Her köy için offline hammadde üretimi
	if ProdScript != null and gs.villages != null:
		for v in gs.villages:
			if typeof(v) == TYPE_DICTIONARY:
				ProdScript.produce(v as Dictionary, elapsed_seconds)

	# 2. Tamamlanan inşaatların uygulanması
	if BQScript != null:
		var state_dict: Dictionary = gs.to_dict()
		var events = BQScript.advance(state_dict, now)
		gs.from_dict(state_dict)
		for ev in events:
			if typeof(ev) == TYPE_DICTIONARY and bus != null and bus.has_signal("building_completed"):
				bus.building_completed.emit(int(ev.get("village_id", -1)), str(ev.get("key", "")), int(ev.get("level", 0)))

	# 3. Askeri eğitim ve araştırma kuyruklarının telafisi (10 dk offline kalan birlik hazır olsun kuralı)
	if ArmySimScript != null:
		var state_dict: Dictionary = gs.to_dict()
		var army_events = ArmySimScript.process_tick(state_dict, now, 0.0)
		gs.from_dict(state_dict)
		for ev in army_events:
			if typeof(ev) == TYPE_DICTIONARY and bus != null:
				var ev_type := str(ev.get("type", ""))
				var vid := int(ev.get("village_id", -1))
				if ev_type == "research_completed" and bus.has_signal("research_completed"):
					bus.research_completed.emit(vid, str(ev.get("unit_key", ev.get("key", ""))))
				elif ev_type in ["unit_trained", "training_completed"] and bus.has_signal("unit_trained"):
					bus.unit_trained.emit(vid, str(ev.get("unit_key", ev.get("key", ""))), int(ev.get("count", 0)))

	# 4. Askeri hareketlerin (saldırı/destek/dönüş) telafisi
	if ActionSimScript != null:
		var state_dict: Dictionary = gs.to_dict()
		var action_events = ActionSimScript.process_tick(state_dict, now, 0.0)
		gs.from_dict(state_dict)
		for ev in action_events:
			if typeof(ev) == TYPE_DICTIONARY and bus != null and bus.has_signal("report_created"):
				bus.report_created.emit(ev)

	# 5. Botların çevrimdışı gelişim kararları (hız düzeni normal oyuncu hızında)
	if BotSimScript != null:
		var state_dict: Dictionary = gs.to_dict()
		var steps: int = mini(10, int(elapsed_seconds / 120.0))
		var step_time := saved_unix
		for s in range(steps):
			step_time += int(elapsed_seconds / float(maxi(1, steps)))
			BotSimScript.process_tick(state_dict, step_time, 120.0)
		gs.from_dict(state_dict)

	gs.world["last_saved_unix"] = now
	gs.world["sim_now_unix"] = now

	if bus != null and bus.has_signal("resources_changed"):
		bus.resources_changed.emit(gs.active_village_id)


# --- Sil --------------------------------------------------------------------

func delete_save() -> bool:
	if not has_save():
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
