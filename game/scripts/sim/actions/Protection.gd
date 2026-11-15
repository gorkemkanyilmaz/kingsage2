extends RefCounted
## Protection.gd — saldırı/fetih koruması ve 10:1 oranı (Taht ve Kılıç / **A-KESIF**).
##
## ## Kaynaklar (kaynakla doğrulanmış)
##  • `docs/11` §10 — Saldırı koruması: yeni oyuncu 5 gün, fetih koruması +7 gün,
##    genel **10:1** oranı, Kanun Kaçağı cezası **2 ay** (60 gün), terk edilmiş köyde koruma yok.
##  • `docs/09` §2 — saldırı koruması özeti.
##  • `docs/08` §4 — fetih koruması 7 gün; Kont mesafesi (bu dosyada değil, `Movement`'da).
##  • `game/data/rules/battle.json#attack_protection` — `new_player_attack_protection_days=5`,
##    `conquest_protection_days=7`, `max_ratio_attacker_defender=10.0`, `outlawed_penalty_days=60`.
##  • `game/autoload/GameConfig.gd` — `new_player_protection_days`, `conquest_protection_days`,
##    `max_attack_ratio`.
##
## ## Kurallar
##  1. **Yeni oyuncu koruması (faz 1) — 5 gün:** korumalı köye **saldırı reddedilir**.
##  2. **Fetih koruması (faz 2) — 7 gün:** ana yerleşim **fethedilemez**; Kont saldırabilir
##     ama **Güç Alanı düşmez** (bkz. `docs/11` §10.4).
##  3. **Terkedilmiş (soyguncu) ve bonus köylerde koruma YOKTUR** (`docs/11` §10.5,
##     `docs/09` §2). Köy türü ne olursa olsun koruma uygulanmaz.
##  4. **Maks. oran saldıran : savunan = 10 : 1.** Aşarsa saldıran **Kanun Kaçağı** olur
##     ve 10:1 korumasını **60 gün (2 ay)** kaybeder. Saldırı yine de yapılır
##     (`docs/11` §10.1/§10.6) — bu modül yalnızca **işaretler**.
##  5. Oyuncu **kendisi saldırırsa** yeni oyuncu koruması biter ve **fetih koruması başlar**
##     (`docs/11` §10.3). Bu geçiş `on_attack_sent()` ile uygulanır.
##
## ## Determinizm
## Bu dosya **saf**tır: rastgelelik yoktur, sistem saati okunmaz; tüm değerler
## `state`/`village` + `GameConfig`/`battle.json`'dan gelir (`docs/19` §2).

## Gün → saniye.
const DAY_SECONDS := 86400

## `GameConfig` yoksa kullanılacak yedekler (battle.json / docs ile aynı).
const DEFAULT_NEW_PLAYER_PROTECTION_DAYS := 15
const DEFAULT_CONQUEST_PROTECTION_DAYS := 15
const DEFAULT_MAX_RATIO := 10.0
const DEFAULT_OUTLAWED_PENALTY_DAYS := 60


# =============================================================================
#  GameConfig / battle.json erişimi
# =============================================================================

static func _config() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("GameConfig")
	return null


static func _game_data() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("GameData")
	return null


## `GameConfig` alanı sayısal ise float döndürür; değilse `fallback`.
static func _config_number(key: String, fallback: float) -> float:
	var cfg := _config()
	if cfg != null:
		var value = cfg.get(key)
		if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
			return float(value)
	return fallback


## `battle.json#attack_protection` sözlüğü (GameData yoksa `{}`).
static func _attack_protection() -> Dictionary:
	var gd := _game_data()
	if gd == null or not gd.has_method("get_rule"):
		return {}
	var battle = gd.get_rule("battle")
	if typeof(battle) != TYPE_DICTIONARY:
		return {}
	var ap = (battle as Dictionary).get("attack_protection", {})
	return ap if typeof(ap) == TYPE_DICTIONARY else {}


# =============================================================================
#  Eşikler (config → battle.json → yedek)
# =============================================================================

## Yeni oyuncu saldırı koruması (gün).
static func new_player_protection_days() -> int:
	var days := int(_config_number("new_player_protection_days", DEFAULT_NEW_PLAYER_PROTECTION_DAYS))
	if days <= 0:
		days = int(_attack_protection().get("new_player_attack_protection_days", DEFAULT_NEW_PLAYER_PROTECTION_DAYS))
	return maxi(0, days)


## Fetih koruması (gün).
static func conquest_protection_days() -> int:
	var days := int(_config_number("conquest_protection_days", DEFAULT_CONQUEST_PROTECTION_DAYS))
	if days <= 0:
		days = int(_attack_protection().get("conquest_protection_days", DEFAULT_CONQUEST_PROTECTION_DAYS))
	return maxi(0, days)


## Maksimum oran saldıran : savunan (varsayılan 10.0).
static func max_ratio() -> float:
	var ratio := _config_number("max_attack_ratio", DEFAULT_MAX_RATIO)
	if ratio <= 0.0:
		ratio = float(_attack_protection().get("max_ratio_attacker_defender", DEFAULT_MAX_RATIO))
	if ratio <= 0.0:
		ratio = DEFAULT_MAX_RATIO
	return ratio


## Kanun Kaçağı cezası (gün) — `battle.json` 60 (2 ay), yoksa 60.
static func outlawed_penalty_days() -> int:
	var days := int(_attack_protection().get("outlawed_penalty_days", DEFAULT_OUTLAWED_PENALTY_DAYS))
	return maxi(1, days)


# =============================================================================
#  Köy türü ve süre uygulaması
# =============================================================================

## Terkedilmiş (soyguncu) veya bonus köy → **koruma taşımaz** (`docs/11` §10.5).
static func is_unprotected_kind(village: Dictionary) -> bool:
	if bool(village.get("is_barbarian", false)):
		return true
	return not str(village.get("bonus_type", "")).is_empty()


## Köye **saldırı** yapılabilir mi? (Yeni oyuncu koruması — faz 1.)
static func is_attack_protected(village: Dictionary, now_unix: int) -> bool:
	if is_unprotected_kind(village):
		return false
	return int(village.get("protection_until", 0)) > now_unix


## Köy **fethedilemez** mi? (Fetih koruması — faz 2.)
static func is_conquest_protected(village: Dictionary, now_unix: int) -> bool:
	if is_unprotected_kind(village):
		return false
	return int(village.get("conquest_protection_until", 0)) > now_unix


## Yeni kurulan köye koruma sürelerini yazar: faz 1 = 5 gün, faz 2 = +7 gün.
## (`docs/11` §10.3–10.4)
static func apply_new_player_protection(village: Dictionary, now_unix: int) -> Dictionary:
	var phase1 := new_player_protection_days()
	var phase2 := conquest_protection_days()
	var protection_until := now_unix + phase1 * DAY_SECONDS
	var conquest_until := now_unix + (phase1 + phase2) * DAY_SECONDS
	village["protection_until"] = protection_until
	village["conquest_protection_until"] = conquest_until
	return {
		"protection_until": protection_until,
		"conquest_protection_until": conquest_until,
	}


## Oyuncu **saldırdığında** yeni oyuncu koruması biter, fetih koruması başlar
## (`docs/11` §10.3). Faz 1 zaten bitmişse hiçbir şey yapmaz.
## Dönüş: olay (boş = değişiklik yok).
static func on_attack_sent(village: Dictionary, now_unix: int) -> Dictionary:
	if is_unprotected_kind(village):
		return {}
	if int(village.get("protection_until", 0)) <= now_unix:
		return {}
	village["protection_until"] = 0
	village["protection_until_unix"] = 0
	var conquest_until := now_unix + conquest_protection_days() * DAY_SECONDS
	if int(village.get("conquest_protection_until", 0)) < conquest_until:
		village["conquest_protection_until"] = conquest_until
	return {
		"type": "protection_ended",
		"village_id": int(village.get("id", 0)),
		"conquest_protection_until": int(village.get("conquest_protection_until", 0)),
	}


# =============================================================================
#  10 : 1 oranı ve Kanun Kaçağı
# =============================================================================

## Bir sahibin **toplam puanı** (sahibin tüm köylerinin köy puanları toplamı).
## `docs/06` §2: moral ve oran **toplam puana** göre hesaplanır.
static func player_points(state: Dictionary, owner: String) -> int:
	if owner.is_empty():
		return 0
	var villages = state.get("villages", [])
	if typeof(villages) != TYPE_ARRAY:
		return 0
	var total := 0
	for village in (villages as Array):
		if typeof(village) != TYPE_DICTIONARY:
			continue
		if str((village as Dictionary).get("owner", "")) == owner:
			total += int((village as Dictionary).get("points", 0))
	return total


## Oran aşıldı mı? → saldıran puanı, savunan puanının `max_ratio` katından **büyük** olmalı.
static func ratio_exceeded(attacker_points: int, defender_points: int) -> bool:
	if attacker_points <= 0:
		return false
	if defender_points <= 0:
		return true
	return float(attacker_points) > max_ratio() * float(defender_points)


## Saldıran köy sahibini **Kanun Kaçağı** işaretler (ceza 2 ay = 60 gün).
## Köy sözlüğüne `outlaw_until` yazılır; `state.player` aynı sahibe aitse oraya da yazılır.
static func mark_outlaw(state: Dictionary, village: Dictionary, now_unix: int) -> Dictionary:
	var days := outlawed_penalty_days()
	var until := now_unix + days * DAY_SECONDS
	village["outlaw_until"] = until
	var player = state.get("player", null)
	if typeof(player) == TYPE_DICTIONARY:
		var p: Dictionary = player
		if str(p.get("name", "")) == str(village.get("owner", "")):
			p["outlaw_until"] = until
	return {"until": until, "days": days}


## Köy sahibi şu an Kanun Kaçağı mı?
static func is_outlawed(village: Dictionary, now_unix: int) -> bool:
	return int(village.get("outlaw_until", 0)) > now_unix
