class_name ArmySimulator
extends RefCounted
## ArmySimulator — Ordu araştırma/eğitim kuyruğu tick işleyicisi (Taht ve Kılıç).
##
## Sözleşme: `docs/19-MOTOR-API-SOZLESMESI.md` §7b (sim modül protokolü).
## `GameLoop` bu modülü **yol ile** yükler ve her tick çağırır:
##
##     static func process_tick(state, now_unix, delta_seconds) -> Array
##
## Bu modül **saf**tır: `GameState` autoload'una, EventBus'a veya başka bir dış
## duruma dokunmaz. Yalnızca verilen `state` sözlüğünü (referans) yerinde günceller
## ve bu tick'te **tamamlanan** işlerin olaylarını döndürür. Determinizmi bozacak
## global `randi()` / `Time` çağrısı **yoktur** (docs/19 §2).
##
## İşlediği kuyruk tipleri (docs/19 §3.2):
##   • "research" → tamamlanınca `village.researched[key] = true`
##   • "train"    → tamamlanınca `village.units[key] += count` (+ vatandaş rezervi çözülür)
##
## Zamanlama `finish_unix` (unix damgası, int) tabanlıdır; `delta_seconds` yalnızca
## protokol uyumu için alınır (bu modül birikimli üretim yapmaz).

const RE := preload("res://scripts/rules/RulesEngine.gd")

const TYPE_RESEARCH := "research"
const TYPE_TRAIN := "train"


# =============================================================================
#  §7b — Giriş noktası
# =============================================================================

## Bir simülasyon tick'ini işler.
##
## `state`          : kök durum (GameState.to_dict() şekli; "villages" + "queues").
## `now_unix`       : şimdiki unix damgası (int, saniye).
## `delta_seconds`  : bu adımın süresi (protokol gereği alınır; kuyruk `finish_unix`
##                    tabanlı olduğundan burada kullanılmaz).
##
## Dönüş: bu tick'te **tamamlanan** işlerin olay sözlükleri:
##   {"type":"research_completed","village_id":int,"key":String}
##   {"type":"training_completed","village_id":int,"key":String,"count":int}
@warning_ignore("unused_parameter")
static func process_tick(state: Dictionary, now_unix: int, delta_seconds: float) -> Array:
	var events: Array = []
	if typeof(state) != TYPE_DICTIONARY:
		return events

	var queues_value = state.get("queues", null)
	if typeof(queues_value) != TYPE_ARRAY:
		state["queues"] = []
		return events
	var queues: Array = queues_value

	var remaining: Array = []
	var changed := false
	for item in queues:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = item
		var type := str(entry.get("type", ""))
		if type != TYPE_RESEARCH and type != TYPE_TRAIN:
			remaining.append(entry)
			continue
		var finish := int(entry.get("finish_unix", 0))
		if finish <= 0 or now_unix < finish:
			remaining.append(entry)
			continue
		events.append(_complete(state, entry))
		changed = true

	if changed:
		# Aynı dizi referansını koru (çağıran `state.queues`ı tutuyor olabilir).
		queues.clear()
		queues.append_array(remaining)

	return events


# =============================================================================
#  Tamamlama
# =============================================================================

## Kuyruk öğesini uygular ve olayını döndürür.
static func _complete(state: Dictionary, item: Dictionary) -> Dictionary:
	var village_id := int(item.get("village_id", -1))
	var key := str(item.get("key", ""))
	var type := str(item.get("type", ""))
	var village := _find_village(state, village_id)

	if type == TYPE_RESEARCH:
		if not village.is_empty() and not key.is_empty():
			var researched = village.get("researched", null)
			if typeof(researched) != TYPE_DICTIONARY:
				researched = {}
				village["researched"] = researched
			(researched as Dictionary)[key] = true
		return {
			"type": "research_completed",
			"village_id": village_id,
			"key": key,
		}

	# train
	var count := int(item.get("count", 0))
	if not village.is_empty() and not key.is_empty() and count > 0:
		var units = village.get("units", null)
		if typeof(units) != TYPE_DICTIONARY:
			units = {}
			village["units"] = units
		(units as Dictionary)[key] = int((units as Dictionary).get(key, 0)) + count
		var reserved := int(item.get("settlers", 0))
		if reserved > 0:
			village["settlers_reserved"] = maxi(0, int(village.get("settlers_reserved", 0)) - reserved)
	return {
		"type": "training_completed",
		"village_id": village_id,
		"key": key,
		"count": count,
	}


## `state.villages` içinden kimliğe göre köyü döndürür (yoksa boş sözlük).
static func _find_village(state: Dictionary, village_id: int) -> Dictionary:
	var villages_value = state.get("villages", null)
	if typeof(villages_value) != TYPE_ARRAY:
		return {}
	for v in (villages_value as Array):
		if typeof(v) == TYPE_DICTIONARY and int((v as Dictionary).get("id", -1)) == village_id:
			return v
	return {}


# =============================================================================
#  Yardımcılar (diğer modüller de kullanır)
# =============================================================================

## Bu tick'te tamamlanma anı geçmiş mi? (UI/ilerleme çubuğu için bilgi amaçlı.)
static func is_finished(item: Dictionary, now_unix: int) -> bool:
	var finish := int(item.get("finish_unix", 0))
	return finish > 0 and now_unix >= finish
