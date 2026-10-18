class_name ArmyAPI
extends RefCounted
## ArmyAPI — Ordu araştırma/eğitim **dış arayüzü** (Taht ve Kılıç, A-ORDU).
##
## `Research` / `Training` / `GoldArmour` iç mantığını tek, kararlı bir yüzeyden
## sunar; böylece `GameLoop`, UI ve testler aynı çağrıları kullanır. Tüm
## fonksiyonlar **saf**tır (GameState/EventBus'a dokunmaz); verilen köy/state
## sözlüklerini yerinde günceller.
##
## Kullanım akışı (özet):
##     var res := ArmyAPI.start_research(village, "sword", state, now_unix)
##     var tr  := ArmyAPI.start_training(village, "sword", 10, state, now_unix)
##     # ... her tick:
##     var events := ArmySimulator.process_tick(state, now_unix, delta_seconds)

const RE := preload("res://scripts/rules/RulesEngine.gd")
const Research := preload("res://scripts/sim/army/Research.gd")
const Training := preload("res://scripts/sim/army/Training.gd")
const GoldArmour := preload("res://scripts/sim/army/GoldArmour.gd")


# =============================================================================
#  Araştırma
# =============================================================================

## Birim şu an araştırılabilir mi? (Kışla seviyesi + henüz araştırılmamış + bedel
## + `state` verilirse bekleyen araştırma yok.)
static func can_research(village: Dictionary, unit_key: String, state: Dictionary = {}) -> bool:
	return Research.can_start(village, unit_key, state)


## Araştırma başlatılamıyorsa nedenini döndürür ("" = başlatılabilir).
static func research_block_reason(village: Dictionary, unit_key: String, state: Dictionary = {}) -> String:
	return Research.block_reason(village, unit_key, state)


## Araştırma süresi (saniye), mevcut Kışla seviyesine göre.
static func research_seconds(village: Dictionary, unit_key: String) -> float:
	return Research.research_seconds(village, unit_key)


## Birimin araştırma maliyeti {"wood","stone","iron"} (araştırılmazsa {}).
static func research_cost(unit_key: String) -> Dictionary:
	return RE.research_cost(unit_key)


## Birimin araştırılması için gereken Kışla seviyesi (0 = araştırılmaz).
static func research_requirement(unit_key: String) -> int:
	return RE.research_requirement(unit_key)


## Araştırmayı başlatır (bedel düşer, kuyruk öğesi döner/eklenir).
## Dönüş: {"ok":bool, "reason":String, "queue":Dictionary}
static func start_research(village: Dictionary, unit_key: String, state: Dictionary = {}, now_unix: int = 0) -> Dictionary:
	return Research.start(village, unit_key, state, now_unix)


## Devam eden bir araştırmayı iptal eder (kimliğe göre). Bulunursa `true`.
## NOT: Araştırma hammadde iadesi yapılmaz (bkz. ASSUMPTIONS.md #8).
static func cancel_research(village: Dictionary, queue_id: int, state: Dictionary) -> bool:
	return _cancel(village, queue_id, state, Research.TYPE_RESEARCH, false)


# =============================================================================
#  Eğitim
# =============================================================================

## Birim şu an eğitilebilir mi? (araştırılmış / Köşk+Altın Zırh / bedel / vatandaş)
static func can_train(village: Dictionary, unit_key: String, count: int, state: Dictionary = {}) -> bool:
	return Training.can_start(village, unit_key, count, state)


## Eğitim başlatılamıyorsa nedenini döndürür ("" = başlatılabilir).
static func training_block_reason(village: Dictionary, unit_key: String, count: int, state: Dictionary = {}) -> String:
	return Training.block_reason(village, unit_key, count, state)


## `count` adet birimin eğitim süresi (saniye); bonus köyde ×0.90.
static func training_seconds(village: Dictionary, unit_key: String, count: int) -> float:
	return Training.training_seconds(village, unit_key, count)


## Eğitimi başlatır (bedel + vatandaş rezervi [+ Altın Zırh], kuyruk öğesi).
## Dönüş: {"ok":bool, "reason":String, "queue":Dictionary}
static func start_training(village: Dictionary, unit_key: String, count: int, state: Dictionary = {}, now_unix: int = 0) -> Dictionary:
	return Training.start(village, unit_key, count, state, now_unix)


## Devam eden bir eğitimi iptal eder (vatandaş + Altın Zırh iade edilir). Bulunursa `true`.
static func cancel_training(village: Dictionary, queue_id: int, state: Dictionary) -> bool:
	return _cancel(village, queue_id, state, Training.TYPE_TRAIN, true)


## Eğitilmiş birimleri **kovar**; vatandaş serbest kalır (kaynak iadesi YOK).
## Kovulan sayıyı döndürür.
static func dismiss(village: Dictionary, unit_key: String, count: int) -> int:
	return Training.dismiss(village, unit_key, count)


# =============================================================================
#  Ordu özetleri / limitler
# =============================================================================

## Köydeki toplam birim sayısı.
static func total_units(village: Dictionary) -> int:
	var units = village.get("units", null)
	if typeof(units) != TYPE_DICTIONARY:
		return 0
	var total := 0
	for key in (units as Dictionary).keys():
		total += int((units as Dictionary)[key])
	return total


## Ordunun kullanabileceği **kalan vatandaş kapasitesi** (≥ 0).
static func army_capacity(village: Dictionary) -> int:
	return maxi(0, Training.free_citizens(village))


## Ordunun bağladığı vatandaş sayısı (Σ birim × settlers).
static func army_settlers(village: Dictionary) -> int:
	return Training.army_settlers(village)


## Saldırı için gereken **en az birim** = 3 × Kışla seviyesi (docs/05 §1).
static func min_attack_units(village: Dictionary) -> int:
	return RE.min_attack_units(_building_level(village, "barracks"))


## Verilen orduyu göndermek mümkün mü? (Σ birim ≥ 3 × Kışla ve en az 1 birim.)
static func can_attack(village: Dictionary, units: Dictionary) -> bool:
	if typeof(units) != TYPE_DICTIONARY:
		return false
	var total := 0
	for key in (units as Dictionary).keys():
		total += int((units as Dictionary)[key])
	if total <= 0:
		return false
	return total >= min_attack_units(village)


# =============================================================================
#  Altın Zırh (Kuyumcu) — Kont için
# =============================================================================

## Kullanılabilir Altın Zırh seti sayısı.
static func gold_armour(village: Dictionary) -> int:
	return GoldArmour.available(village)


## Kuyumcu'da Altın Zırh üretir (Kuyumcu ≥ 1 + hammadde). Başarı durumunu döndürür.
static func produce_gold_armour(village: Dictionary, count: int = 1) -> bool:
	return GoldArmour.produce(village, count)


## Bir setin (güncel) maliyeti.
static func gold_armour_cost(village: Dictionary) -> Dictionary:
	return GoldArmour.cost_per_set(village)


# =============================================================================
#  İç yardımcılar
# =============================================================================

static func _cancel(village: Dictionary, queue_id: int, state: Dictionary, type: String, refund: bool) -> bool:
	if typeof(state) != TYPE_DICTIONARY:
		return false
	var queues_value = state.get("queues", null)
	if typeof(queues_value) != TYPE_ARRAY:
		return false
	var queues: Array = queues_value
	for i in range(queues.size()):
		var item = queues[i]
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = item
		if int(entry.get("id", -1)) != queue_id:
			continue
		if str(entry.get("type", "")) != type:
			continue
		if refund:
			Training.cancel(village, entry)
		queues.remove_at(i)
		return true
	return false


static func _building_level(village: Dictionary, key: String) -> int:
	var b = village.get("buildings", null)
	if typeof(b) != TYPE_DICTIONARY:
		return 0
	return int((b as Dictionary).get(key, 0))
