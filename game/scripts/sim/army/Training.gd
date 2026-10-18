extends RefCounted
## Training — birim **eğitimi** ve **kovma (dismiss)** (Taht ve Kılıç, A-ORDU).
##
## Kurallar:
##   • Eğitim **araştırma tamamlandıktan sonra** Kışla'da yapılır (docs/05 §1).
##   • **Kont (snob)** istisnadır: **Köşk**'te, **Altın Zırh** ile eğitilir.
##   • Her birim `settlers` kadar **vatandaş** tüketir; yeterli boş vatandaş
##     yoksa eğitim **başlamaz** (docs/05 §1).
##   • Eğitim **sıralıdır**; iptal edilirse **vatandaş geri gelir** (docs/05 §1).
##   • **Bonus köy** (`bonus_type == "training"`): eğitim **%10 hızlı** → süre **×0.90**
##     (`TRAINING_BONUS_FACTOR`; docs/19 §3.1, Economicsiz — doğrudan köy sözlüğünden).
##
## Vatandaş muhasebesi: `VillageModel.population_used` yalnızca **binaların**
## vatandaşını sayar. Ordu vatandaşı ve **rezerve** edilen (henüz tamamlanmamış
## eğitim) vatandaş bu modülde ayrıca düşülür (`village.settlers_reserved`).
## Bkz. ASSUMPTIONS.md #6, #7.

const RE := preload("res://scripts/rules/RulesEngine.gd")
const VM := preload("res://scripts/model/VillageModel.gd")
const GA := preload("res://scripts/sim/army/GoldArmour.gd")

const TYPE_TRAIN := "train"

## Bonus köy eğitim hızlandırması: süre ×0.90 (−%10).
const TRAINING_BONUS_FACTOR := 0.90

## Bonus köy türü anahtarı (docs/19 §3.1).
const BONUS_TRAINING := "training"

const RESOURCES := ["wood", "stone", "iron"]

# --- Birim kural önbelleği (`rules/units.json`; eğitim binası & Altın Zırh bayrağı) ---
static var _rules: Dictionary = {}
static var _rules_ready := false


# =============================================================================
#  Birim kuralı (eğitim binası + Altın Zırh bayrağı)
# =============================================================================

static func _ensure_rules() -> void:
	if _rules_ready:
		return
	_rules_ready = true
	var path := "res://data/rules/units.json"
	if not FileAccess.file_exists(path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for u in (parsed as Dictionary).get("units", []):
		if typeof(u) == TYPE_DICTIONARY:
			_rules[str((u as Dictionary).get("key", ""))] = u


static func _unit_rule(unit_key: String) -> Dictionary:
	_ensure_rules()
	var rule = _rules.get(unit_key, {})
	return rule if typeof(rule) == TYPE_DICTIONARY else {}


## Eğitimin yapıldığı bina anahtarı ("barracks" | "snob").
static func training_building(unit_key: String) -> String:
	var training: Dictionary = _unit_rule(unit_key).get("training", {})
	return str(training.get("building", "barracks"))


## Bu birim Altın Zırh gerektirir mi? (yalnız Kont → `true`.)
static func requires_gold_armor(unit_key: String) -> bool:
	var training: Dictionary = _unit_rule(unit_key).get("training", {})
	return bool(training.get("requires_gold_armor", false))


# =============================================================================
#  Vatandaş muhasebesi
# =============================================================================

## Ordunun bağladığı vatandaş = Σ birim × `settlers`.
static func army_settlers(village: Dictionary) -> int:
	var units = village.get("units", null)
	if typeof(units) != TYPE_DICTIONARY:
		return 0
	var total := 0
	for key in (units as Dictionary).keys():
		total += RE.unit_settlers(str(key)) * int((units as Dictionary)[key])
	return total


## Devam eden eğitimler için rezerve edilmiş vatandaş.
static func settlers_reserved(village: Dictionary) -> int:
	return maxi(0, int(village.get("settlers_reserved", 0)))


## Ordu için kullanılabilir **boş** vatandaş =
## Değirmen tavanı − bina vatandaşı − ordu vatandaşı − rezerve.
## Negatif olabilir (aşırı rezervasyon); çağıran `army_capacity` ile kırpar.
static func free_citizens(village: Dictionary) -> int:
	var cap := RE.max_population(VM.building_level(village, "farm"))
	var used := VM.population_used(village)
	return cap - used - army_settlers(village) - settlers_reserved(village)


# =============================================================================
#  Süre
# =============================================================================

## `count` adet birimin eğitim süresi (saniye). Bonus köyde ×0.90.
static func training_seconds(village: Dictionary, unit_key: String, count: int) -> float:
	if count <= 0:
		return 0.0
	var building := training_building(unit_key)
	var level := maxi(1, _building_level(village, building))
	var seconds := RE.training_seconds(unit_key, count, level)
	if str(village.get("bonus_type", "")) == BONUS_TRAINING:
		seconds *= TRAINING_BONUS_FACTOR
	return seconds


# =============================================================================
#  Sorgu
# =============================================================================

## Eğitim başlatılamıyorsa **neden**ini döndürür; başlatılabilirse "".
## Nedenler: invalid_count · unknown_unit · not_researched · barracks_required ·
##           residence_required · no_gold_armour · not_enough_resources ·
##           not_enough_citizens
static func block_reason(village: Dictionary, unit_key: String, count: int, state: Dictionary = {}) -> String:
	if count <= 0:
		return "invalid_count"
	if _unit_rule(unit_key).is_empty():
		return "unknown_unit"

	if requires_gold_armor(unit_key):
		# Kont: araştırılmaz; Köşk + Altın Zırh ile eğitilir.
		if _building_level(village, "snob") < 1:
			return "residence_required"
		if GA.available(village) < count:
			return "no_gold_armour"
	else:
		if _building_level(village, "barracks") < 1:
			return "barracks_required"
		if not RE.is_researched(village, unit_key):
			return "not_researched"

	var cost := RE.unit_cost(unit_key, count)
	var res = village.get("resources", null)
	if typeof(res) != TYPE_DICTIONARY:
		return "not_enough_resources"
	for key in RESOURCES:
		if int((res as Dictionary).get(key, 0)) < int(cost.get(key, 0)):
			return "not_enough_resources"

	if free_citizens(village) < count * RE.unit_settlers(unit_key):
		return "not_enough_citizens"
	return ""


static func can_start(village: Dictionary, unit_key: String, count: int, state: Dictionary = {}) -> bool:
	return block_reason(village, unit_key, count, state).is_empty()


# =============================================================================
#  Eylem
# =============================================================================

## Eğitimi başlatır: bedeli düşer, vatandaşı **rezerve eder**, (Kont için) Altın
## Zırh'ı tüketir ve kuyruk öğesini `state.queues`e ekler.
## Dönüş: {"ok":bool, "reason":String, "queue":Dictionary}
static func start(village: Dictionary, unit_key: String, count: int, state: Dictionary, now_unix: int) -> Dictionary:
	var reason := block_reason(village, unit_key, count, state)
	if not reason.is_empty():
		return {"ok": false, "reason": reason, "queue": {}}

	var needs_armor := requires_gold_armor(unit_key)
	var settlers := count * RE.unit_settlers(unit_key)
	var cost := RE.unit_cost(unit_key, count)

	_pay(village, cost)
	if needs_armor:
		GA.consume(village, count)                       # maliyet zaten kontrol edildi
	village["settlers_reserved"] = settlers_reserved(village) + settlers

	var item := {
		"id": _next_id(state),
		"village_id": int(village.get("id", -1)),
		"type": TYPE_TRAIN,
		"key": unit_key,
		"count": count,
		"settlers": settlers,
		"gold_armour": count if needs_armor else 0,
		"start_unix": int(now_unix),
		"finish_unix": int(now_unix) + _duration_ticks(training_seconds(village, unit_key, count)),
		"cost_paid": cost.duplicate(true),
	}
	_append(state, item)
	return {"ok": true, "reason": "", "queue": item}


## Eğitilmiş birimleri dağıtır (**kov**): kaynak iadesi YOK, vatandaş serbest kalır.
## Gerçekten kovulan sayıyı döndürür.
static func dismiss(village: Dictionary, unit_key: String, count: int) -> int:
	if count <= 0:
		return 0
	var units = village.get("units", null)
	if typeof(units) != TYPE_DICTIONARY:
		return 0
	var have := maxi(0, int((units as Dictionary).get(unit_key, 0)))
	var removed := mini(count, have)
	(units as Dictionary)[unit_key] = have - removed
	return removed


## Devam eden bir eğitimi iptal eder: **vatandaş** rezervi ve **Altın Zırh** iade
## edilir. (Hammadde iadesi YOK — bkz. ASSUMPTIONS.md #8.)
## Dönüş: iptal gerçekleştiyse `true`.
static func cancel(village: Dictionary, item: Dictionary) -> bool:
	if typeof(item) != TYPE_DICTIONARY:
		return false
	if str(item.get("type", "")) != TYPE_TRAIN:
		return false
	var settlers := int(item.get("settlers", 0))
	if settlers > 0:
		village["settlers_reserved"] = maxi(0, settlers_reserved(village) - settlers)
	var armour := int(item.get("gold_armour", 0))
	if armour > 0:
		GA.refund(village, armour)
	return true


# =============================================================================
#  Yardımcılar
# =============================================================================

static func _building_level(village: Dictionary, key: String) -> int:
	var b = village.get("buildings", null)
	if typeof(b) != TYPE_DICTIONARY:
		return 0
	return int((b as Dictionary).get(key, 0))


static func _duration_ticks(seconds: float) -> int:
	return maxi(1, int(ceil(seconds)))


static func _pay(village: Dictionary, cost: Dictionary) -> void:
	var res = village.get("resources", null)
	if typeof(res) != TYPE_DICTIONARY:
		res = {}
		village["resources"] = res
	for key in RESOURCES:
		(res as Dictionary)[key] = maxi(0, int((res as Dictionary).get(key, 0)) - int(cost.get(key, 0)))


static func _append(state: Dictionary, item: Dictionary) -> void:
	if typeof(state) != TYPE_DICTIONARY:
		return
	var q = state.get("queues", null)
	if typeof(q) != TYPE_ARRAY:
		q = []
		state["queues"] = q
	(q as Array).append(item)


static func _next_id(state: Dictionary) -> int:
	var max_id := 0
	var q = state.get("queues", null)
	if typeof(q) == TYPE_ARRAY:
		for item in (q as Array):
			if typeof(item) == TYPE_DICTIONARY:
				max_id = maxi(max_id, int((item as Dictionary).get("id", 0)))
	return max_id + 1
