extends RefCounted
## Research — birim **araştırma** eylemi (Taht ve Kılıç, A-ORDU).
##
## Kural (docs/19 §4.5, ASSUMPTIONS.md #4): araştırma **gerçek bir eylemdir**.
## Bedeli ödenir, süre geçer ve **bir kez** yapılır → `village.researched[unit] = true`.
## Araştırma durumu **Kışla seviyesinden TÜRETİLEMEZ**; mutlaka `researched` bayrağına bakılır.
##
## Kışla gereksinimleri (kaynak: `game/data/rules/units.json#research_requirements_barracks`,
## `RulesEngine.research_requirement`): Silahtar/Mızrakçı/Muhafız = 1 · Baltacı = 2 ·
## Casus = 4 · Okçu = 5 · Akıncı = 7 · Kara Şövalye = 16 · Şahmerdan = 20 · Mancınık = 25.
## **Kont (snob) araştırılmaz** (Köşk'te Altın Zırh ile eğitilir).
##
## Bu sınıf saf/durumsuzdur; verdiği köy sözlüğünü yerinde günceller ve bir kuyruk
## öğesi üretir (kuyruk yönetimi `ArmySimulator` / `GameLoop`'a aittir).

const RE := preload("res://scripts/rules/RulesEngine.gd")

const TYPE_RESEARCH := "research"


# =============================================================================
#  Sorgu
# =============================================================================

## Birimin araştırılması için gereken Kışla seviyesi (0 = araştırılmaz → Kont).
static func required_barracks(unit_key: String) -> int:
	return RE.research_requirement(unit_key)


## Araştırma süresi (saniye): `RulesEngine.research_seconds(unit, Kışla seviyesi)`.
static func research_seconds(village: Dictionary, unit_key: String) -> float:
	return RE.research_seconds(unit_key, _barracks_level(village))


## Bu köyde bekleyen bir araştırma var mı? `unit_key` boşsa herhangi biri sayılır.
static func has_pending(state: Dictionary, village_id: int, unit_key: String = "") -> bool:
	if typeof(state) != TYPE_DICTIONARY:
		return false
	var queues_value = state.get("queues", null)
	if typeof(queues_value) != TYPE_ARRAY:
		return false
	for item in (queues_value as Array):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = item
		if str(entry.get("type", "")) != TYPE_RESEARCH:
			continue
		if int(entry.get("village_id", -1)) != village_id:
			continue
		if unit_key.is_empty() or str(entry.get("key", "")) == unit_key:
			return true
	return false


## Araştırma başlatılamıyorsa **neden**ini döndürür; başlatılabilirse "".
## Nedenler: not_researchable · already_researched · barracks_too_low ·
##           research_in_progress · not_enough_resources
static func block_reason(village: Dictionary, unit_key: String, state: Dictionary = {}) -> String:
	if required_barracks(unit_key) <= 0:
		return "not_researchable"          # Kont vb.
	if RE.is_researched(village, unit_key):
		return "already_researched"
	if _barracks_level(village) < required_barracks(unit_key):
		return "barracks_too_low"

	var village_id := int(village.get("id", -1))
	if not state.is_empty() and has_pending(state, village_id):
		return "research_in_progress"      # Kışla'da tek araştırma (bkz. ASSUMPTIONS.md #5)

	var cost := RE.research_cost(unit_key)
	if cost.is_empty():
		return "not_researchable"
	var res = village.get("resources", null)
	if typeof(res) != TYPE_DICTIONARY:
		return "not_enough_resources"
	for r in RE.UNIT_RESOURCES:
		if int((res as Dictionary).get(r, 0)) < int(cost.get(r, 0)):
			return "not_enough_resources"
	return ""


## Araştırma başlatılabilir mi? (`RulesEngine.can_research` + kuyruk kontrolü.)
static func can_start(village: Dictionary, unit_key: String, state: Dictionary = {}) -> bool:
	return block_reason(village, unit_key, state).is_empty()


# =============================================================================
#  Eylem
# =============================================================================

## Araştırmayı başlatır: bedeli düşer, kuyruk öğesini (`state.queues`e) ekler.
## Dönüş: {"ok":bool, "reason":String, "queue":Dictionary}
static func start(village: Dictionary, unit_key: String, state: Dictionary, now_unix: int) -> Dictionary:
	var reason := block_reason(village, unit_key, state)
	if not reason.is_empty():
		return {"ok": false, "reason": reason, "queue": {}}

	var cost := RE.research_cost(unit_key)
	_pay(village, cost)

	var item := {
		"id": _next_id(state),
		"village_id": int(village.get("id", -1)),
		"type": TYPE_RESEARCH,
		"key": unit_key,
		"count": 0,
		"start_unix": int(now_unix),
		"finish_unix": int(now_unix) + duration_ticks(research_seconds(village, unit_key)),
		"cost_paid": cost.duplicate(true),
	}
	_append(state, item)
	return {"ok": true, "reason": "", "queue": item}


# =============================================================================
#  Paylaşılan yardımcılar (Training.gd de benzerlerini kullanır)
# =============================================================================

## Kışla seviyesi (yoksa 0).
static func _barracks_level(village: Dictionary) -> int:
	var b = village.get("buildings", null)
	if typeof(b) != TYPE_DICTIONARY:
		return 0
	return int((b as Dictionary).get("barracks", 0))


## Saniyeyi kuyruk için tamsayı tick'e çevirir (yukarı yuvarla, en az 1).
static func duration_ticks(seconds: float) -> int:
	return maxi(1, int(ceil(seconds)))


## Hammadde maliyetini köyden düşer (negatife inmez).
static func _pay(village: Dictionary, cost: Dictionary) -> void:
	var res = village.get("resources", null)
	if typeof(res) != TYPE_DICTIONARY:
		res = {}
		village["resources"] = res
	for r in RE.UNIT_RESOURCES:
		(res as Dictionary)[r] = maxi(0, int((res as Dictionary).get(r, 0)) - int(cost.get(r, 0)))


## Kuyruğa öğe ekler (state.queues yoksa oluşturur).
static func _append(state: Dictionary, item: Dictionary) -> void:
	if typeof(state) != TYPE_DICTIONARY:
		return
	var q = state.get("queues", null)
	if typeof(q) != TYPE_ARRAY:
		q = []
		state["queues"] = q
	(q as Array).append(item)


## Kuyruk için sıradaki benzersiz kimlik (deterministik: max(id)+1).
static func _next_id(state: Dictionary) -> int:
	var max_id := 0
	var q = state.get("queues", null)
	if typeof(q) == TYPE_ARRAY:
		for item in (q as Array):
			if typeof(item) == TYPE_DICTIONARY:
				max_id = maxi(max_id, int((item as Dictionary).get("id", 0)))
	return max_id + 1
