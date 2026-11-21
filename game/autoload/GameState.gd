extends Node
## GameState — kök oyun durumu (Taht ve Kılıç).
##
## Tüm oynanış verisi burada tutulur ve JSON'a serileştirilebilir.
## Simülasyon katmanları (ekonomi, ordu, savaş …) bu durumu okur/yazar;
## kalıcılık SaveManager üzerinden sağlanır.

## Yükleme sırasında varsayılan değerler (yeni oyun).
const START_RESOURCES := {"wood": 1000, "stone": 1000, "iron": 1000}

## Oyuncu bilgileri (ad, puan, koruma durumu, premium …).
var player: Dictionary = {}

## Oyuncunun köyleri.
var villages: Array = []

## Şu anda "aktif" (seçili) köyün kimliği; -1 = aktif köy yok.
## GameClock tick'i yalnızca aktif köy varken ilerletir.
var active_village_id: int = -1

## İnşaat / araştırma / eğitim kuyrukları.
var queues: Array = []

## Uçuştaki ordular, destekler ve ticaret (katır) hareketleri.
var movements: Array = []

## Raporlar (Savaş Raporu, Casusluk Raporu …).
var reports: Array = []

## Mesajlar.
var messages: Array = []

## İttifaklar (forum YOK).
var alliances: Array = []

## Dünya durumu (harita, zaman, sayaçlar).
var world: Dictionary = {}


func _ready() -> void:
	# Boş durumla başla; yükleme SaveManager/Boot tarafından yapılır.
	if player.is_empty() and villages.is_empty():
		reset()


func _event_bus() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("EventBus")
	return null


func _emit_state_changed() -> void:
	var eb := _event_bus()
	if eb != null and eb.has_signal("state_changed"):
		eb.state_changed.emit()


func _emit_resources_changed(vid: int) -> void:
	var eb := _event_bus()
	if eb != null and eb.has_signal("resources_changed"):
		eb.resources_changed.emit(vid)


func _emit_report_created(report) -> void:
	var eb := _event_bus()
	if eb != null and eb.has_signal("report_created"):
		eb.report_created.emit(report)


func _emit_message_created(message) -> void:
	var eb := _event_bus()
	if eb != null and eb.has_signal("message_created"):
		eb.message_created.emit(message)


func reset() -> void:
	player = {
		"id": 1,
		"name": "Lord Gorkem",
		"points": 0,
		"protection_until_unix": 0,
		"conquest_protection_until_unix": 0,
		"diamonds": 35,
		"scrolls": {},
		"premium": false,
	}
	villages = []
	active_village_id = -1
	queues = []
	movements = []
	reports = []
	messages = []
	alliances = []
	world = {
		"sim_time_seconds": 0.0,
		"last_saved_unix": int(Time.get_unix_time_from_system()),
	}
	_emit_state_changed()


# --- Yardımcılar: köy -------------------------------------------------------

func get_village(village_id: int) -> Dictionary:
	for village in villages:
		if int(village.get("id", -1)) == village_id:
			return village
	return {}


func get_village_index(village_id: int) -> int:
	for i in range(villages.size()):
		if int(villages[i].get("id", -1)) == village_id:
			return i
	return -1


func add_village(village: Dictionary) -> void:
	villages.append(village)
	# İlk köy eklendiğinde onu otomatik aktif yap.
	if active_village_id < 0:
		active_village_id = int(village.get("id", -1))
	_emit_state_changed()


func rename_village(vid: int, new_name: String) -> bool:
	var clean := new_name.strip_edges()
	if clean.is_empty():
		return false
	var now_u := int(Time.get_unix_time_from_system())
	var next_nu := now_u
	var next_seq := 1
	var found := false
	for v in villages:
		if typeof(v) == TYPE_DICTIONARY and int((v as Dictionary).get("id", -1)) == vid:
			var vd := v as Dictionary
			next_nu = maxi(now_u, int(vd.get("name_updated_unix", 0)) + 1)
			next_seq = int(vd.get("name_edit_seq", 0)) + 1
			vd["name"] = clean
			vd["name_updated_unix"] = next_nu
			vd["name_edit_seq"] = next_seq
			found = true
			break
	if world is Dictionary and world.has("villages"):
		for wv in world["villages"]:
			if typeof(wv) == TYPE_DICTIONARY and int((wv as Dictionary).get("id", -1)) == vid:
				var wvd := wv as Dictionary
				wvd["name"] = clean
				wvd["name_updated_unix"] = next_nu
				wvd["name_edit_seq"] = next_seq
				break
	if found:
		var loop := Engine.get_main_loop()
		if loop is SceneTree:
			var wm = (loop as SceneTree).root.get_node_or_null("WorldManager")
			if wm != null and wm.has_method("notify_local_mutation"):
				wm.call("notify_local_mutation")
			var sm = (loop as SceneTree).root.get_node_or_null("SaveManager")
			if sm != null:
				sm.save_game()
		_emit_state_changed()
	return found


func get_village_count() -> int:
	return villages.size()


# --- Yardımcılar: aktif köy ------------------------------------------------

## Şu anda aktif (seçili) köyü döndürür; yoksa boş sözlük.
func get_active_village() -> Dictionary:
	return get_village(active_village_id)


## Aktif köy var mı? (GameClock tick kapısı bunu kullanır.)
func has_active_village() -> bool:
	return not get_active_village().is_empty()


## Aktif köyü seçer.
func set_active_village(village_id: int) -> void:
	if active_village_id != village_id:
		active_village_id = village_id
		_emit_resources_changed(village_id)
		_emit_state_changed()


## Oyuncunun sahip olduğu tüm köyleri döndürür.
func get_player_villages() -> Array:
	var list: Array = []
	var p_name := str(player.get("name", "Kral")).strip_edges()
	for v in villages:
		if typeof(v) != TYPE_DICTIONARY:
			continue
		var vd: Dictionary = v
		if bool(vd.get("is_bot", false)) or bool(vd.get("is_barbarian", false)):
			continue
		var v_owner := str(vd.get("owner", "")).strip_edges()
		if not p_name.is_empty() and v_owner == p_name:
			list.append(v)
	return list



## Oyuncunun sonraki/önceki köyüne geçer (direction: +1 sonraki, -1 önceki).
func cycle_active_village(direction: int = 1) -> int:
	var p_vills := get_player_villages()
	if p_vills.is_empty():
		return -1
	if p_vills.size() == 1:
		set_active_village(int((p_vills[0] as Dictionary).get("id", -1)))
		return active_village_id

	var cur_idx := -1
	for i in range(p_vills.size()):
		if int((p_vills[i] as Dictionary).get("id", -1)) == active_village_id:
			cur_idx = i
			break

	var next_idx := 0
	if cur_idx >= 0:
		next_idx = posmod(cur_idx + direction, p_vills.size())
	var target_id := int((p_vills[next_idx] as Dictionary).get("id", -1))
	set_active_village(target_id)
	return target_id



# --- Yardımcılar: kaynak / vatandaş ----------------------------------------

## Köyün anlık hammaddelerini döndürür (yoksa boş sözlük).
func get_resources(village_id: int) -> Dictionary:
	return get_village(village_id).get("resources", {})


## Köyün hammaddelerini günceller ve olayı yayınlar.
func set_resources(village_id: int, resources: Dictionary) -> void:
	var village := get_village(village_id)
	if village.is_empty():
		return
	village["resources"] = resources
	_emit_resources_changed(village_id)
	_emit_state_changed()


# --- Yardımcılar: kuyruk / hareket / rapor ---------------------------------

func add_queue_item(item: Dictionary) -> void:
	queues.append(item)
	_emit_state_changed()


func add_movement(movement: Dictionary) -> void:
	movements.append(movement)
	_emit_state_changed()


func add_report(report) -> void:
	reports.append(report)
	_emit_report_created(report)
	_emit_state_changed()


func add_message(message) -> void:
	messages.append(message)
	_emit_message_created(message)
	_emit_state_changed()


# --- Serileştirme -----------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"player": player.duplicate(true),
		"villages": villages.duplicate(true),
		"active_village_id": active_village_id,
		"queues": queues.duplicate(true),
		"movements": movements.duplicate(true),
		"reports": reports.duplicate(true),
		"messages": messages.duplicate(true),
		"alliances": alliances.duplicate(true),
		"world": world.duplicate(true),
	}


func from_dict(data: Dictionary) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	player = _as_dict(data.get("player", {}))
	if not player.has("diamonds") or player.get("diamonds") == null:
		player["diamonds"] = 35
	else:
		player["diamonds"] = maxi(0, int(player.get("diamonds", 35)))
	if not player.has("scrolls") or typeof(player.get("scrolls")) != TYPE_DICTIONARY:
		player["scrolls"] = {}
	villages = _as_array(data.get("villages", []))
	if data.has("active_village_id"):
		active_village_id = int(data.get("active_village_id", -1))
	else:
		active_village_id = -1
		if not villages.is_empty() and typeof(villages[0]) == TYPE_DICTIONARY:
			active_village_id = int((villages[0] as Dictionary).get("id", -1))
	queues = _as_array(data.get("queues", []))
	movements = _as_array(data.get("movements", []))
	reports = _as_array(data.get("reports", []))
	messages = _as_array(data.get("messages", []))
	alliances = _as_array(data.get("alliances", []))
	world = _as_dict(data.get("world", {}))
	_emit_state_changed()
	return true


func _as_dict(value) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	return {}


func _as_array(value) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).duplicate(true)
	return []
