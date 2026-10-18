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


## Yeni/boş bir oyuna döner.
func reset() -> void:
	player = {
		"id": 0,
		"name": "Kral",
		"points": 0,
		"protection_until_unix": 0,
		"conquest_protection_until_unix": 0,
		"premium": false,
	}
	villages = []
	queues = []
	movements = []
	reports = []
	messages = []
	alliances = []
	world = {
		"sim_time_seconds": 0.0,
		"last_saved_unix": int(Time.get_unix_time_from_system()),
	}
	EventBus.state_changed.emit()


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
	EventBus.state_changed.emit()


func get_village_count() -> int:
	return villages.size()


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
	EventBus.resources_changed.emit(village_id)
	EventBus.state_changed.emit()


# --- Yardımcılar: kuyruk / hareket / rapor ---------------------------------

func add_queue_item(item: Dictionary) -> void:
	queues.append(item)
	EventBus.state_changed.emit()


func add_movement(movement: Dictionary) -> void:
	movements.append(movement)
	EventBus.state_changed.emit()


func add_report(report) -> void:
	reports.append(report)
	EventBus.report_created.emit(report)
	EventBus.state_changed.emit()


func add_message(message) -> void:
	messages.append(message)
	EventBus.message_created.emit(message)
	EventBus.state_changed.emit()


# --- Serileştirme -----------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"player": player.duplicate(true),
		"villages": villages.duplicate(true),
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
	villages = _as_array(data.get("villages", []))
	queues = _as_array(data.get("queues", []))
	movements = _as_array(data.get("movements", []))
	reports = _as_array(data.get("reports", []))
	messages = _as_array(data.get("messages", []))
	alliances = _as_array(data.get("alliances", []))
	world = _as_dict(data.get("world", {}))
	EventBus.state_changed.emit()
	return true


func _as_dict(value) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	return {}


func _as_array(value) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).duplicate(true)
	return []
