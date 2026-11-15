class_name ActionSimulator
extends RefCounted
## ActionSimulator — hareket (saldırı/talan/destek/ticaret/casusluk) tick işleyicisi
## (Taht ve Kılıç / **A-KESIF**).
##
## Sözleşme: `docs/19-MOTOR-API-SOZLESMESI.md` §7b (sim modül protokolü) + §3.3 (hareket şekli).
##
## `game/scripts/core/GameLoop.gd` bu modülü **yol ile** yükler ve her tick çağırır:
##
##     static func process_tick(state, now_unix, delta_seconds) -> Array
##
## Bu modül **saf**tır: `GameState` autoload'una, EventBus'a veya başka bir dış duruma
## dokunmaz. Yalnızca verilen `state` sözlüğünü (referans) yerinde günceller ve bu
## tick'te **tamamlanan** işlerin olaylarını döndürür.
##
## ## İş akışı
##  • Varmış (`now_unix >= arrive_unix`) **giden** hareketler tek tek çözülür:
##    savaş/talan/destek/ticaret/casusluk → `Arrival.resolve()`.
##  • Çözüm bir **dönüş hareketi** üretirse (`type:"return"`, `state:"returning"`) durum
##    listesine eklenir; vardığında birlikler ve ganimet kaynak köye eklenir.
##  • **Dönüş süresi = gidiş süresi** ve ganimet dönüşte taşınır.
##
## ## Determinizm
## Rastgelelik yalnızca her hareketin **`battle_seed`**'iyle `BattleSimulator`'a aittir;
## global `randi()` **yasaktır** (`docs/19` §2.3). Aynı `state` + aynı tick → aynı sonuç.

const Arrival := preload("res://scripts/sim/actions/Arrival.gd")
const Movement := preload("res://scripts/sim/actions/Movement.gd")
const Protection := preload("res://scripts/sim/actions/Protection.gd")
const RE := preload("res://scripts/rules/RulesEngine.gd")

const RESOURCES := ["wood", "stone", "iron"]

## Kayıt/güvenlik: tek tick'te çözülecek azami hareket (sonsuz döngü koruması).
const MAX_PER_TICK := 100000

## Destek: hedefte biriken birliklerin kaydı bu anahtar altında tutulur.
const SUPPORT_KEY := "support"


# =============================================================================
#  §7b — Giriş noktası
# =============================================================================

## Bir simülasyon tick'ini işler.
##
## `state`          : kök durum (`GameState.to_dict()` şekli; "villages" + "movements").
## `now_unix`       : şimdiki unix damgası (int, saniye).
## `delta_seconds`  : bu adımın süresi (zamanlama `arrive_unix` tabanlı olduğundan
##                    protokol uyumu için alınır).
##
## Dönüş: bu tick'te **tamamlanan** işlerin olayları (`Array[Dictionary]`).
@warning_ignore("unused_parameter")
static func process_tick(state: Dictionary, now_unix: int, delta_seconds: float) -> Array:
	var events: Array = []
	if typeof(state) != TYPE_DICTIONARY:
		return events

	var movements_value = state.get("movements", null)
	if typeof(movements_value) != TYPE_ARRAY:
		state["movements"] = []
		return events
	var movements: Array = movements_value

	var remaining: Array = []
	var changed := false
	var processed := 0
	for entry in movements:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var movement: Dictionary = entry
		var arrive := int(movement.get("arrive_unix", 0))
		if arrive <= 0 or now_unix < arrive:
			remaining.append(movement)
			continue

		changed = true
		processed += 1
		if processed > MAX_PER_TICK:
			remaining.append(movement)
			continue

		if str(movement.get("type", "")) == "return":
			events.append(_resolve_return(state, movement, now_unix))
			continue

		var resolution := Arrival.resolve(state, movement, arrive)
		events.append_array(resolution.get("events", []))
		var return_movement = resolution.get("return", {})
		if typeof(return_movement) == TYPE_DICTIONARY and not (return_movement as Dictionary).is_empty():
			var ret_dict := return_movement as Dictionary
			var ret_arrive := int(ret_dict.get("arrive_unix", 0))
			if ret_arrive > 0 and ret_arrive <= now_unix:
				events.append(_resolve_return(state, ret_dict, ret_arrive))
			else:
				remaining.append(ret_dict)

	if changed:
		# Aynı dizi referansını koru (çağıran `state.movements`ı tutuyor olabilir).
		movements.clear()
		movements.append_array(remaining)

	return events


# =============================================================================
#  Dönüş çözümü
# =============================================================================

## Dönen ordu/ganimeti kaynak köye ekler.
## Olay: `{"type":"movement_returned","village_id":int,"movement_id":int,"units":{...},"carry":{...}}`
static func _resolve_return(state: Dictionary, movement: Dictionary, now_unix: int) -> Dictionary:
	var origin_id := int(movement.get("village_id", movement.get("to_village_id", 0)))
	var origin := _find_village(state, origin_id)
	var units = movement.get("units", {})
	var carry = movement.get("carry", {})
	var clean_units := _normalize_units(units)
	var clean_carry := _normalize_resources(carry)

	if not origin.is_empty():
		_add_units(origin, clean_units)
		_add_resources(origin, clean_carry)

	return {
		"type": "movement_returned",
		"village_id": origin_id,
		"movement_id": int(movement.get("id", 0)),
		"units": clean_units,
		"carry": clean_carry,
	}


# =============================================================================
#  Yardımcılar
# =============================================================================

static func _find_village(state: Dictionary, village_id: int) -> Dictionary:
	var villages = state.get("villages", null)
	if typeof(villages) != TYPE_ARRAY:
		return {}
	for village in (villages as Array):
		if typeof(village) == TYPE_DICTIONARY and int((village as Dictionary).get("id", -1)) == village_id:
			return village
	return {}


static func _add_units(village: Dictionary, units: Dictionary) -> void:
	if typeof(village.get("units")) != TYPE_DICTIONARY:
		village["units"] = {}
	var have: Dictionary = village["units"]
	for key in units.keys():
		have[str(key)] = int(have.get(str(key), 0)) + int(units[key])


static func _add_resources(village: Dictionary, resources: Dictionary) -> void:
	if typeof(village.get("resources")) != TYPE_DICTIONARY:
		village["resources"] = {"wood": 0, "stone": 0, "iron": 0}
	var have: Dictionary = village["resources"]
	var storage_lvl := 0
	var buildings = village.get("buildings", {})
	if typeof(buildings) == TYPE_DICTIONARY:
		storage_lvl = int((buildings as Dictionary).get("storage", 0))
	var storage_cap := RE.storage_capacity(storage_lvl) if storage_lvl > 0 else 0
	for r in RESOURCES:
		if storage_cap > 0:
			have[r] = mini(storage_cap, int(have.get(r, 0)) + int(resources.get(r, 0)))
		else:
			have[r] = int(have.get(r, 0)) + int(resources.get(r, 0))


static func _normalize_units(raw) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	var keys := (raw as Dictionary).keys()
	keys.sort()
	for key in keys:
		var count := int((raw as Dictionary)[key])
		if count > 0:
			out[str(key)] = count
	return out


static func _normalize_resources(raw) -> Dictionary:
	var out := {"wood": 0, "stone": 0, "iron": 0}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	for r in RESOURCES:
		out[r] = int((raw as Dictionary).get(r, 0))
	return out
