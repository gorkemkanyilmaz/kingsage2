extends RefCounted
## GoldArmour — **Kuyumcu** Altın Zırh üretimi (Taht ve Kılıç, A-ORDU).
##
## Kont (snob) **araştırılmaz**; **Köşk**'te **Altın Zırh** ile eğitilir (docs/05 §1,
## docs/08 §3, docs/04 §Goldsmith). Altın Zırh **Kuyumcu**'da (`smith`) üretilir.
##
## ⚠️ **Bilinmeyenler (ASSUMPTIONS.md #3, #4):**
##   • Altın Zırh'ın **temel maliyeti** hiçbir kaynakta yok → tek sabit `COST`.
##   • "Her yeni sette maliyet artar" denir ama **artış çarpanı** yok → tek sabit
##     `COST_GROWTH = 1.0` (yani artış **modellenmez**, sabit maliyet).
##   • Üretim **süresi** bilinmiyor → üretim **anlıktır** (`PRODUCTION_SECONDS = 0`).
##
## Köy alanları (bu modülün eklediği türetilmiş alanlar):
##   • `village.gold_armour`      → kullanılabilir zırh seti (int)
##   • `village.gold_armour_made` → toplam üretilmiş set (int, maliyet artışı için)

const RE := preload("res://scripts/rules/RulesEngine.gd")

## Tek sabit set maliyeti (Kont maliyetinin ~%10'u; gerekçe ASSUMPTIONS.md #3).
## ⚠️ Değer doğrulanmamıştır; oyun istemcisinden alınana kadar yer tutucudur.
const COST := {"wood": 12000, "stone": 10000, "iron": 8000}

## Set başına maliyet artış çarpanı. Çarpan bilinmiyor → tek sabit **1.0** (artış yok).
const COST_GROWTH := 1.0

## Üretim süresi (saniye). Bilinmiyor → **0** (anlık üretim).
const PRODUCTION_SECONDS := 0


# =============================================================================
#  Sorgu
# =============================================================================

## Kullanılabilir Altın Zırh seti sayısı.
static func available(village: Dictionary) -> int:
	return maxi(0, int(village.get("gold_armour", 0)))


## Bugüne kadar üretilmiş toplam set sayısı.
static func made(village: Dictionary) -> int:
	return maxi(0, int(village.get("gold_armour_made", 0)))


## Kuyumcu (`smith`) seviyesi (yoksa 0).
static func smith_level(village: Dictionary) -> int:
	var b = village.get("buildings", null)
	if typeof(b) != TYPE_DICTIONARY:
		return 0
	return int((b as Dictionary).get("smith", 0))


## **Bir** setin maliyeti. `COST_GROWTH = 1.0` olduğundan sabittir; formül,
## artış çarpanı doğrulanınca tek sabit değiştirilerek çalışsın diye yazılmıştır.
static func cost_per_set(village: Dictionary) -> Dictionary:
	var factor := pow(COST_GROWTH, float(made(village)))
	var out := {}
	for key in RE.UNIT_RESOURCES:
		out[key] = int(floor(float(COST.get(key, 0)) * factor + 0.5))
	return out


## `count` setin toplam maliyeti (maliyet artışı nötr → set × count).
static func total_cost(village: Dictionary, count: int) -> Dictionary:
	var out := {"wood": 0, "stone": 0, "iron": 0}
	if count <= 0:
		return out
	var one := cost_per_set(village)
	for key in RE.UNIT_RESOURCES:
		out[key] = int(one.get(key, 0)) * count
	return out


## Üretim mümkün mü? (Kuyumcu ≥ 1 + yeterli hammadde.)
static func can_produce(village: Dictionary, count: int = 1) -> bool:
	if count <= 0:
		return false
	if smith_level(village) < 1:
		return false
	var cost := total_cost(village, count)
	var res = village.get("resources", null)
	if typeof(res) != TYPE_DICTIONARY:
		return false
	for key in RE.UNIT_RESOURCES:
		if int((res as Dictionary).get(key, 0)) < int(cost.get(key, 0)):
			return false
	return true


# =============================================================================
#  Eylem
# =============================================================================

## Altın Zırh üretir: maliyeti düşer, stok artar. Başarı durumunu döndürür.
static func produce(village: Dictionary, count: int = 1) -> bool:
	if not can_produce(village, count):
		return false
	var cost := total_cost(village, count)
	var res = village.get("resources", {})
	for key in RE.UNIT_RESOURCES:
		(res as Dictionary)[key] = maxi(0, int((res as Dictionary).get(key, 0)) - int(cost.get(key, 0)))
	village["gold_armour"] = available(village) + count
	village["gold_armour_made"] = made(village) + count
	return true


## Set(ler)i tüketir (Kont eğitimi başlarken). Yetersizse `false`.
static func consume(village: Dictionary, count: int = 1) -> bool:
	if count <= 0 or available(village) < count:
		return false
	village["gold_armour"] = available(village) - count
	return true


## Set(ler)i iade eder (eğitim iptalinde).
static func refund(village: Dictionary, count: int = 1) -> void:
	if count <= 0:
		return
	village["gold_armour"] = available(village) + count
