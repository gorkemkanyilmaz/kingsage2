extends RefCounted
## RealmOfPower — Güç Alanı (Realm of Power) yenilenmesi ve Kont düşüşü (Taht ve Kılıç).
##
## Sahip: **A-EKONOMI** · Sözleşme: `docs/19-MOTOR-API-SOZLESMESI.md` §3.1, §7b.
## Kaynaklar: `docs/08` §1–§2, `docs/15` §5.3, `game/data/rules/battle.json#realm_of_power`,
## `GameConfig.realm_power_hourly_percent` (TR: %1), `GameConfig.realm_loss_*`.
##
## ## Kurallar (kaynakla doğrulanmış)
##  • Güç Alanı **0 … Köy Puanı** arasındadır; **tavan = köy puanı** (asla 10.000'i geçemez).
##  • Değer tavanın altındaysa **saatte tavanın %1'i** kadar artar.
##  • Yabancı **Kont** saldırısı değeri düşürür (2250–2750; Anıt varsa 1750–2250).
##    Düşüş **miktarı** A-SAVAS tarafından hesaplanır (şans/seed determinizmi orada);
##    bu modül yalnızca sonucu **uygular** ve **0'a inince fethi işaretler**.
##  • Fetih sonrası yeni sahibin Güç Alanı **maksimumun %30'una** yükselir (`docs/08` §2).
##  • **Kapak:** saldırı başına bir Kont, tavanın **en fazla yarısı** kadar düşürebilir (`docs/08` §2).
##
## ## Determinizm
## Rastgelelik **yoktur**: buradaki tüm fonksiyonlar saf ve deterministiktir (`randi()` yasak).
## Yüzdeleri/katsayıları `GameConfig`'ten okur.

const VM := preload("res://scripts/model/VillageModel.gd")

## Yenilenme artığı (kayan nokta) alanı — köy sözlüğünde saklanır.
const FRAC_KEY := "_realm_frac"

const SECONDS_PER_HOUR := 3600.0

## Fetih sonrası Güç Alanı oranı (maksimumun %30'u — `docs/08` §2).
const POST_CONQUEST_RATIO := 0.30


static func _game_config() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("GameConfig")
	return null


static func _round_half_up(x: float) -> int:
	return int(floor(x + 0.5))


# =============================================================================
#  Tavan / oran
# =============================================================================

## Güç Alanı tavanı = Köy Puanı.
static func cap(village: Dictionary) -> int:
	var p = village.get("points", null)
	if typeof(p) == TYPE_INT or typeof(p) == TYPE_FLOAT:
		return maxi(0, int(p))
	var b = village.get("buildings", {})
	if typeof(b) != TYPE_DICTIONARY:
		return 0
	# Puan alanı yoksa binalardan türet (VillageModel.refresh_points yan etkisi olmadan).
	var total := 0
	var gd := _game_data()
	if gd != null:
		for k in (b as Dictionary).keys():
			total += int(gd.points_for(str(k), int((b as Dictionary)[k])))
	return total


static func _game_data() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var node: Node = (loop as SceneTree).root.get_node_or_null("GameData")
		if node != null:
			if node.has_method("is_loaded") and not node.is_loaded():
				node.load_all()
			return node
	return null


## Saatlik yenilenme yüzdesi (`GameConfig.realm_power_hourly_percent`; varsayılan %1).
static func hourly_percent() -> float:
	var gc := _game_config()
	if gc == null:
		return 1.0
	var v = gc.get("realm_power_hourly_percent")
	if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
		var p := float(v)
		return p if p >= 0.0 else 1.0
	return 1.0


## Saatlik yenilenme miktarı (int) = tavan × yüzde / 100.
static func hourly_gain(village: Dictionary) -> int:
	return _round_half_up(float(cap(village)) * hourly_percent() / 100.0)


# =============================================================================
#  Değer erişimi
# =============================================================================

## Güç Alanının geçerli (0…tavan) değeri.
static func value(village: Dictionary) -> int:
	return clampi(int(village.get("realm_of_power", 0)), 0, cap(village))


## Değeri doğrudan atar (0…tavan aralığına kırpar) ve döndürür.
static func set_value(village: Dictionary, v: int) -> int:
	var clamped := clampi(v, 0, cap(village))
	village["realm_of_power"] = clamped
	return clamped


## Alanı tavana (tam) doldurur.
static func fill(village: Dictionary) -> int:
	return set_value(village, cap(village))


# =============================================================================
#  Yenilenme (regen)
# =============================================================================

## `delta_seconds` boyunca Güç Alanını **saatte %1** hızıyla yeniler; yeni değeri döndürür.
## Kayan nokta artığı (`_realm_frac`) köy sözlüğünde saklanır → küçük tick'ler kayıpsız birikir.
static func regenerate(village: Dictionary, delta_seconds: float) -> int:
	var tavan := cap(village)
	var cur := value(village)
	if delta_seconds <= 0.0 or tavan <= 0 or cur >= tavan:
		# Tavanda → artık birikmedi; değeri tavana sabitle.
		village["realm_of_power"] = clampi(cur, 0, tavan)
		if cur >= tavan:
			village[FRAC_KEY] = 0.0
		return int(village["realm_of_power"])

	var rate := float(tavan) * hourly_percent() / 100.0 / SECONDS_PER_HOUR  # puan / saniye
	var acc := float(village.get(FRAC_KEY, 0.0)) + rate * delta_seconds
	var whole := int(floor(acc))
	acc -= float(whole)

	var new_value := clampi(cur + whole, 0, tavan)
	village["realm_of_power"] = new_value
	if new_value >= tavan:
		acc = 0.0
	village[FRAC_KEY] = acc
	return new_value


# =============================================================================
#  Kont düşüşü (yabancı Kont) — miktar A-SAVAS'tan gelir
# =============================================================================

## Kont düşüşünü uygular. `enforce_half_cap` true ise (`docs/08` §2) tek saldırıda düşüş
## tavanın **yarısıyla** sınırlanır.
## Dönüş: `{ value_before, value_after, applied, conquered }`
static func apply_count_drop(village: Dictionary, amount: int, enforce_half_cap: bool = true) -> Dictionary:
	var tavan := cap(village)
	var before := value(village)
	var drop := maxi(0, amount)
	if enforce_half_cap:
		drop = mini(drop, int(floor(float(tavan) / 2.0)))
	var after := clampi(before - drop, 0, tavan)
	village["realm_of_power"] = after
	if after <= 0:
		village[FRAC_KEY] = 0.0
	return {
		"value_before": before,
		"value_after": after,
		"applied": before - after,
		"conquered": after <= 0,
	}


## Kont düşüş aralığı: `[min, max]`. Anıt varsa daha düşük aralık (`docs/08` §2).
## ⚠️ Rastgele seçim **yapmaz** (determinizm); bir seçim üretmek A-SAVAS'ın `battle_seed`
## tabanlı `RandomNumberGenerator`'ına aittir.
static func loss_range(has_statue: bool) -> Array:
	var gc := _game_config()
	if gc != null and gc.has_method("realm_loss_range"):
		return gc.realm_loss_range(has_statue)
	return [2250, 2750] if not has_statue else [1750, 2250]


# =============================================================================
#  Fetih sonrası
# =============================================================================

## Fetih sonrası yeni sahibin Güç Alanı = **maksimumun %30'u** (`docs/08` §2).
static func on_conquered(village: Dictionary) -> int:
	return set_value(village, _round_half_up(float(cap(village)) * POST_CONQUEST_RATIO))


## Güç Alanı sıfır mı (fetih koşulu)?
static func is_depleted(village: Dictionary) -> bool:
	return value(village) <= 0
