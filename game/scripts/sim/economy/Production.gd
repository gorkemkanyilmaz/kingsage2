extends RefCounted
## Production — saatlik hammadde üretimi, Depo tavanı ve Gizli Depo (Taht ve Kılıç).
##
## Sahip: **A-EKONOMI** · Sözleşme: `docs/19-MOTOR-API-SOZLESMESI.md` §4.3, §7b.
## Kural verisi (tek doğruluk kaynağı): `game/data/rules/production.json`
##   • `curves.raw_material_production.values` → Oduncu Kampı / Taş ocağı / Maden ocağı (kesin tablo)
##   • `curves.warehouse_capacity.values`      → Depo kapasitesi (hammadde BAŞINA)
##   • `curves.hideout_capacity.values`        → Gizli Depo (talandan korunan miktar)
##
## ## Determinizm (docs/19 §2)
## Tüm kaynak değerleri **int**; üretim hızları **float**. Yuvarlama `round_half_up`.
## Global `randi()` **kullanılmaz** — tüm hesap saf fonksiyondur.
##
## ## Kesir telafisi (önemli)
## Küçük tick'lerde (ör. 1 sn) tek bir tick'in üretimi 1 birimin altında kalır. Her tick'te
## `round_half_up` yapılsa üretim tamamen kaybolurdu. Bu yüzden **kayan nokta artığı**
## (`_prod_frac`) köy sözlüğünde saklanır ve bir sonraki tick'e devredilir; böylece
## offline hızlı-ileride (binlerce küçük tick) toplam üretim doğru kalır. Artık alanı
## köy veri şeklinin **iç alanıdır** (bkz. ASSUMPTIONS.md §4) ve `_` ile işaretlenmiştir.

const RE := preload("res://scripts/rules/RulesEngine.gd")

## Hammadde sırası her yerde sabittir (docs/19 §1.3).
const RESOURCES := ["wood", "stone", "iron"]

## Bir saatin saniyesi.
const SECONDS_PER_HOUR := 3600.0

## Üretim artığı (kayan nokta) alanı — köy sözlüğünde saklanır.
const FRAC_KEY := "_prod_frac"


# =============================================================================
#  Yardımcılar
# =============================================================================

static func _game_data() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var node: Node = (loop as SceneTree).root.get_node_or_null("GameData")
		if node != null:
			if node.has_method("is_loaded") and not node.is_loaded():
				node.load_all()
			return node
	return null


static func _round_half_up(x: float) -> int:
	return int(floor(x + 0.5))


## Köyün hammadde sözlüğünü garanti eder (yoksa oluşturur, eksik anahtarları 0 yapar).
static func ensure_resources(village: Dictionary) -> Dictionary:
	var res = village.get("resources", null)
	if typeof(res) != TYPE_DICTIONARY:
		res = {}
		village["resources"] = res
	for r in RESOURCES:
		if not (res as Dictionary).has(r):
			(res as Dictionary)[r] = 0
	return res as Dictionary


## Üretim artığı sözlüğünü garanti eder.
static func _frac(village: Dictionary) -> Dictionary:
	var frac = village.get(FRAC_KEY, null)
	if typeof(frac) != TYPE_DICTIONARY:
		frac = {}
		village[FRAC_KEY] = frac
	for r in RESOURCES:
		if not (frac as Dictionary).has(r):
			(frac as Dictionary)[r] = 0.0
	return frac as Dictionary


static func _level(village: Dictionary, key: String) -> int:
	var b = village.get("buildings", {})
	if typeof(b) != TYPE_DICTIONARY:
		return 0
	return int((b as Dictionary).get(key, 0))


# =============================================================================
#  Bonus köy çarpanları (docs/02 §4, docs/19 §3.1)
# =============================================================================

## Bonus köy çarpanı: `wood|stone|iron` → ilgili hammadde **+%10**; `production` → tümü **+%3**.
## Ayrıca köyde açık bir `bonus` sözlüğü varsa (VillageModel) onunla da çarpılır.
static func bonus_multiplier(village: Dictionary, resource: String) -> float:
	var m := 1.0
	var bonus = village.get("bonus", null)
	if typeof(bonus) == TYPE_DICTIONARY:
		var raw = (bonus as Dictionary).get(resource, 1.0)
		if typeof(raw) == TYPE_INT or typeof(raw) == TYPE_FLOAT:
			m *= float(raw)
	var bonus_type := str(village.get("bonus_type", ""))
	if bonus_type == resource:
		m *= 1.10
	elif bonus_type == "production":
		m *= 1.03
	return m


# =============================================================================
#  Kapasite
# =============================================================================

## Depo toplam hammadde kapasitesi (**hammadde başına** üst sınır).
static func storage_capacity(village: Dictionary) -> int:
	return RE.storage_capacity(_level(village, "storage"))


## Gizli Depo kapasitesi (talan/casusluktan korunan miktar).
static func hideout_capacity(village: Dictionary) -> int:
	return RE.hideout_capacity(_level(village, "hide"))


## Hammaddelerin kırpıldığı üst sınır (= Depo kapasitesi).
static func resource_cap(village: Dictionary) -> int:
	return storage_capacity(village)


# =============================================================================
#  Üretim
# =============================================================================

## Saatlik hammadde üretimi (bonus + `GameConfig.speed` dahil), hammadde başına float.
static func hourly_production(village: Dictionary) -> Dictionary:
	var out := {"wood": 0.0, "stone": 0.0, "iron": 0.0}
	for r in RESOURCES:
		var base := RE.production_per_hour(r, _level(village, r))
		out[r] = base * bonus_multiplier(village, r)
	return out


## Saatlik toplam üretim (3 hammadde; bilgi amaçlı).
static func total_hourly_production(village: Dictionary) -> float:
	var rates := hourly_production(village)
	var total := 0.0
	for r in RESOURCES:
		total += float(rates.get(r, 0.0))
	return total


## `delta_seconds` boyunca üretimi uygular; köyün `resources` sözlüğünü **yerinde** günceller.
##
## Dönüş: `{ "gained": {wood,stone,iron}, "capped": bool }`
##   • `gained`  → bu tick'te depoya **gerçekten eklenen** (tavan nedeniyle kaybolan hariç).
##   • `capped`  → en az bir hammadde tavana ulaştı (üretim kayboldu).
static func produce(village: Dictionary, delta_seconds: float) -> Dictionary:
	var gained := {"wood": 0, "stone": 0, "iron": 0}
	if delta_seconds <= 0.0:
		return {"gained": gained, "capped": false}

	var res := ensure_resources(village)
	var frac := _frac(village)
	var cap := storage_capacity(village)
	var rates := hourly_production(village)
	var capped := false

	for r in RESOURCES:
		var rate := float(rates.get(r, 0.0)) / SECONDS_PER_HOUR  # birim / saniye
		var acc := float(frac.get(r, 0.0)) + rate * delta_seconds
		var whole := int(floor(acc))
		acc -= float(whole)

		var old := int(res.get(r, 0))
		if cap > 0 and old >= cap:
			# Depo tavanı zaten doluysa (görev ödülü/ticaret fazlası vb.) mevcut stoku silme; yeni üretimi durdur.
			frac[r] = 0.0
			gained[r] = 0
			continue
		var value := old + whole
		if cap > 0 and value >= cap:
			value = cap
			acc = 0.0
			if whole > 0:
				capped = true
		res[r] = value
		frac[r] = acc
		gained[r] = value - old

	return {"gained": gained, "capped": capped}


## Hammaddeyi `[0, cap]` aralığına kırpar (dış müdahalelerden sonra güvenlik ağı).
static func clamp_resources(village: Dictionary) -> void:
	var res := ensure_resources(village)
	var cap := storage_capacity(village)
	if cap <= 0:
		return
	for r in RESOURCES:
		res[r] = clampi(int(res.get(r, 0)), 0, cap)


## Kaynakları harcar (yetersizse false döner, hiçbir şey değişmez).
static func spend(village: Dictionary, cost: Dictionary) -> bool:
	var res := ensure_resources(village)
	for r in RESOURCES:
		if int(res.get(r, 0)) < int(cost.get(r, 0)):
			return false
	for r in RESOURCES:
		res[r] = int(res.get(r, 0)) - int(cost.get(r, 0))
	return true


## Kaynakları ekler (Depo tavanına kırpar). Gerçekten eklenen miktarı döndürür.
static func add(village: Dictionary, amount: Dictionary) -> Dictionary:
	var res := ensure_resources(village)
	var cap := storage_capacity(village)
	var added := {"wood": 0, "stone": 0, "iron": 0}
	for r in RESOURCES:
		var old := int(res.get(r, 0))
		var value := old + int(amount.get(r, 0))
		if cap > 0 and value > cap:
			value = cap
		res[r] = value
		added[r] = value - old
	return added
