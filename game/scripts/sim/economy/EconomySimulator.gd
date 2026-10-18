extends RefCounted
## EconomySimulator — ekonomi tick orkestratörü (Taht ve Kılıç / **A-EKONOMI**).
##
## ## §7b Sim modül protokolü (`docs/19-MOTOR-API-SOZLESMESI.md` §7b)
## `GameLoop`, `MODULES` listesindeki her modülün `process_tick(state, now_unix, delta_seconds)`
## statik imzasını çağırır ve dönen olayları `EventBus` sinyallerine çevirir.
##
## ## Bu tick'te yapılanlar (deterministik sıra)
##   1. **Üretim:** her köy için hammadde üretimi (+ Depo tavanı) — `Production.produce`
##   2. **İnşaat:** tamamlanan bina işlerini uygula — `BuildQueue.advance`
##   3. **Güç Alanı:** saatlik %1 yenilenme — `RealmOfPower.regenerate`
##
## Sıra önemlidir: inşaat önce uygulanır ki Güç Alanı yenilenmesi **güncel** köy puanını
## (yeni tavanı) kullansın. Üretim ile inşaat birbirinden bağımsızdır.
##
## ## Determinizm (docs/19 §2)
## Tüm hesap int/float saf fonksiyonlardır; global `randi()` **kullanılmaz**. Aynı
## `(state, now_unix, delta_seconds)` her zaman aynı olayları üretir.

const PROD := preload("res://scripts/sim/economy/Production.gd")
const BQ := preload("res://scripts/sim/economy/BuildQueue.gd")
const ROP := preload("res://scripts/sim/economy/RealmOfPower.gd")
const POP := preload("res://scripts/sim/economy/Population.gd")


## Ekonomi tick'i. `state` = `GameState.to_dict()` çıktısı (yerinde güncellenir).
## Dönüş: bu tick'te oluşan olaylar (`docs/19` §7b).
static func process_tick(state: Dictionary, now_unix: int, delta_seconds: float) -> Array:
	var events := []
	if typeof(state) != TYPE_DICTIONARY:
		return events

	var villages = state.get("villages", [])
	if typeof(villages) != TYPE_ARRAY:
		return events

	# 1) Üretim (her köy).
	for v in (villages as Array):
		if typeof(v) != TYPE_DICTIONARY:
			continue
		PROD.produce(v as Dictionary, delta_seconds)

	# 2) İnşaat kuyruğu (tamamlananlar uygulanır).
	events.append_array(BQ.advance(state, now_unix))

	# 3) Güç Alanı yenilenmesi.
	for v in (villages as Array):
		if typeof(v) != TYPE_DICTIONARY:
			continue
		var village := v as Dictionary
		var before := int(village.get("realm_of_power", 0))
		var after := ROP.regenerate(village, delta_seconds)
		if after != before:
			events.append({
				"type": "realm_of_power_changed",
				"village_id": int(village.get("id", -1)),
				"value": after,
			})

	return events


# =============================================================================
#  Yardımcılar (A-ARAYUZ ve testler için)
# =============================================================================

## Tick başına üretim özeti (olay üretmeden; UI göstergeleri için).
static func production_summary(village: Dictionary) -> Dictionary:
	return {
		"hourly": PROD.hourly_production(village),
		"storage_capacity": PROD.storage_capacity(village),
		"hideout_capacity": PROD.hideout_capacity(village),
	}

## Değirmen tavanı / boş vatandaş özeti (UI için).
static func population_summary(village: Dictionary) -> Dictionary:
	return {
		"max": POP.max_citizens(village),
		"used": POP.used_citizens(village),
		"free": POP.free_citizens(village),
	}
