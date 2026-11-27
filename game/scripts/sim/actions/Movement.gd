extends RefCounted
## Movement.gd — hareket oluşturma / doğrulama (Taht ve Kılıç / **A-KESIF**).
##
## Sözleşme: `docs/19-MOTOR-API-SOZLESMESI.md` §3.3 (hareket şekli) + §2 (determinizm).
## Yolculuk süreleri/dönüş `game/scripts/world/Travel.gd`'den gelir (hazır modül, **kullan**).
##
## ## Emir türleri (`docs/09` §1)
##  • `attack`  — düşman köye askerî saldırı (fetih denemesi Kont ile).
##  • `raid`    — **talan**; yağma var, fetih yok (`is_raid`).
##  • `support` — kendi/dost köye destek (birlikler hedefte savunmada kalır).
##  • `trade`   — **katır** ile hammadde transferi (kendi/ittifak köyü).
##  • `spy`     — casusluk (normal / gizli).
##  • `return`  — dönen ordu/ganimet (varışta `Arrival`/`ActionSimulator` çözer).
##
## ## Doğrulanmış zorunlu kurallar
##  • **Min. saldırı birimi:** gönderilen ordu ≥ **3 × Kışla seviyesi** (aksi halde reddedilir).
##  • **Kont mesafesi:** ordu Kont içeriyorsa hedef, `GameConfig.count_max_distance`
##    (TR: **80 alan**) mesafesinden uzak olamaz (`docs/08` §4).
##  • **Koruma:** korumalı köye saldırı/casusluk reddedilir (`Protection`).
##  • **Kendi/ittifak köyüne saldırılamaz**; destek/ticaret yalnız kendi/ittifak köyüne.
##  • **İptal:** saldırı **30 dk**, katır **15 dk** içinde (`docs/09` §6).
##  • **10:1 oranı** aşılırsa saldıran **Kanun Kaçağı** olur (saldırı yine yapılır).
##
## ## Determinizm
## `battle_seed` her harekette saklanır ve **tamamen tamsayı matematiğiyle** türetilir
## (`derive_seed`); global `randi()` **yasaktır** (`docs/19` §2.3).

const Travel := preload("res://scripts/world/Travel.gd")
const RE := preload("res://scripts/rules/RulesEngine.gd")
const Protection := preload("res://scripts/sim/actions/Protection.gd")

# --- Tür sabitleri ----------------------------------------------------------
const TYPE_ATTACK := "attack"
const TYPE_RAID := "raid"
const TYPE_SUPPORT := "support"
const TYPE_TRADE := "trade"
const TYPE_SPY := "spy"
const TYPE_RETURN := "return"

const RESOURCES := ["wood", "stone", "iron"]
const UNIT_KEYS := [
	"farmer", "spear", "sword", "axe", "bow", "spy", "light", "heavy", "ram", "kata", "snob",
]

## Katır (ticaret) yolculuk hızı — **alan başına dakika**. `docs/14` §6.3'te kesin
## formül YOK; seçilen sabit (bkz. ASSUMPTIONS.md #4).
const DONKEY_MINUTES_PER_FIELD := 2.0

## Gizli casusluk yavaşlık çarpanı (`TASKS-CODE.md` T-8.1: "gizli = 3× yavaş").
const CREEPING_SPEED_MULTIPLIER := 3.0

## Ticaret için Market zorunlu mu? (`docs/14` §1: "Market binası zorunludur".)
const REQUIRE_MARKET_FOR_TRADE := true


# =============================================================================
#  Doğrulama (can_send)
# =============================================================================

## Bir emir gönderilebilir mi? Dönüş: `{"ok":bool,"code":String,"message":String}`.
## Kodlar: "" | unknown_village | same_village | bad_type | units_empty |
##          units_unavailable | min_units | friendly_target | target_protected |
##          count_too_far | foreign_target | resources_empty | resources_unavailable |
##          market_required
static func can_send(
	state: Dictionary,
	from_village_id: int,
	to_village_id: int,
	type: String,
	units: Dictionary = {},
	carry: Dictionary = {},
	now_unix: int = 0
) -> Dictionary:
	var origin := _find_village(state, from_village_id)
	if origin.is_empty():
		return _fail("unknown_village", "Kaynak köy bulunamadı.")
	var target := _find_village(state, to_village_id)
	if target.is_empty():
		return _fail("unknown_village", "Hedef köy bulunamadı.")
	if from_village_id == to_village_id:
		return _fail("same_village", "Bir köy kendine gönderim yapamaz.")

	match type:
		TYPE_ATTACK, TYPE_RAID:
			return _validate_attack(state, origin, target, units, now_unix)
		TYPE_SPY:
			return _validate_spy(state, origin, target, units, now_unix)
		TYPE_SUPPORT:
			return _validate_support(state, origin, target, units)
		TYPE_TRADE:
			return _validate_trade(state, origin, target, carry)
	return _fail("bad_type", "Bilinmeyen hareket türü: " + type)


static func _validate_attack(
	state: Dictionary, origin: Dictionary, target: Dictionary, units: Dictionary, now_unix: int
) -> Dictionary:
	var clean := normalize_units(units)
	if _sum(clean) <= 0:
		return _fail("units_empty", "Gönderilecek birlik yok.")
	var availability := _units_available(origin, clean)
	if not bool(availability.get("ok", false)):
		return availability

	# Min. saldırı birimi = 3 × Kışla seviyesi.
	var min_units := RE.min_attack_units(_building_level(origin, "barracks"))
	if _sum(clean) < min_units:
		return _fail("min_units", "Saldırı için gereken en az birim: %d (3 × Kışla)." % min_units)

	# Kendi/ittifak köyüne saldırılamaz.
	if _is_friendly(state, origin, target):
		return _fail("friendly_target", "Kendi/ittifak köyüne saldırılamaz.")

	# Koruma (yeni oyuncu faz 1).
	if Protection.is_attack_protected(target, now_unix):
		return _fail("target_protected", "Hedef köy saldırı koruması altında.")

	# Kont mesafesi.
	if int(clean.get("snob", 0)) > 0:
		var max_fields := float(_count_max_distance())
		if not Travel.within_max_fields(
			int(origin.get("x", 0)), int(origin.get("y", 0)),
			int(target.get("x", 0)), int(target.get("y", 0)), max_fields
		):
			return _fail("count_too_far", "Kont en fazla %d alan uzağa gönderilebilir." % int(max_fields))

	return _ok()


static func _validate_spy(
	state: Dictionary, origin: Dictionary, target: Dictionary, units: Dictionary, now_unix: int
) -> Dictionary:
	var clean := normalize_units(units)
	if int(clean.get("spy", 0)) <= 0:
		return _fail("units_empty", "Gönderilecek casus yok.")
	# Yalnızca casus gönderilir.
	for key in clean.keys():
		if str(key) != "spy":
			return _fail("bad_type", "Casuslukta yalnızca Casus gönderilebilir.")
	var availability := _units_available(origin, clean)
	if not bool(availability.get("ok", false)):
		return availability
	if Protection.is_attack_protected(target, now_unix):
		return _fail("target_protected", "Hedef köy saldırı koruması altında.")
	if _is_friendly(state, origin, target):
		return _fail("friendly_target", "Kendi/ittifak köyüne casus gönderilemez.")
	return _ok()


static func _validate_support(
	state: Dictionary, origin: Dictionary, target: Dictionary, units: Dictionary
) -> Dictionary:
	var clean := normalize_units(units)
	if _sum(clean) <= 0:
		return _fail("units_empty", "Gönderilecek birlik yok.")
	var availability := _units_available(origin, clean)
	if not bool(availability.get("ok", false)):
		return availability
	return _ok()


static func _is_real_player_target(target: Dictionary) -> bool:
	var owner := str(target.get("owner", "")).strip_edges().to_lower()
	return (
		not bool(target.get("is_bot", false))
		and not bool(target.get("is_barbarian", false))
		and not owner.is_empty()
		and owner != "barbar"
		and owner != "terk edilmiş"
		and owner != "terk edilmis"
		and owner != "soyguncular"
		and owner != "usta"
		and owner != "yabancı"
		and owner != "yabanci"
	)


static func _validate_trade(
	state: Dictionary, origin: Dictionary, target: Dictionary, carry: Dictionary
) -> Dictionary:
	var clean := normalize_resources(carry)
	if _sum(clean) <= 0:
		return _fail("resources_empty", "Gönderilecek hammadde yok.")
	var resources = origin.get("resources", {})
	if typeof(resources) != TYPE_DICTIONARY:
		return _fail("resources_unavailable", "Kaynak köyün hammaddesi yok.")
	for r in RESOURCES:
		if int((resources as Dictionary).get(r, 0)) < int(clean.get(r, 0)):
			return _fail("resources_unavailable", "Kaynak köyde yeterli hammadde yok.")
	if not _is_friendly(state, origin, target) and not _is_real_player_target(target):
		return _fail("foreign_target", "Ticaret yalnızca gerçek oyunculara, kendi veya müttefik köylerinize yapılabilir.")
	if REQUIRE_MARKET_FOR_TRADE and _building_level(origin, "market") < 1:
		return _fail("market_required", "Ticaret için Market (en az seviye 1) gerekir.")
	return _ok()


# =============================================================================
#  Gönderme
# =============================================================================

## Askerî saldırı (fetih denemesi Kont ile).
## `options`: {"seed":int} (determinizm için tohum geçersiz kılma).
## Dönüş: `{"ok","code","message","movement","events","outlawed"}`.
static func send_attack(
	state: Dictionary,
	from_village_id: int,
	to_village_id: int,
	units: Dictionary,
	now_unix: int,
	options: Dictionary = {}
) -> Dictionary:
	return _send_military(state, TYPE_ATTACK, from_village_id, to_village_id, units, now_unix, options)


## Talan (raid): yağma var, fetih yok.
static func send_raid(
	state: Dictionary,
	from_village_id: int,
	to_village_id: int,
	units: Dictionary,
	now_unix: int,
	options: Dictionary = {}
) -> Dictionary:
	return _send_military(state, TYPE_RAID, from_village_id, to_village_id, units, now_unix, options)


static func _send_military(
	state: Dictionary,
	type: String,
	from_village_id: int,
	to_village_id: int,
	units: Dictionary,
	now_unix: int,
	options: Dictionary
) -> Dictionary:
	var check := can_send(state, from_village_id, to_village_id, type, units, {}, now_unix)
	if not bool(check.get("ok", false)):
		return check

	if bool(options.get("include_lord", false)):
		var p_d = state.get("player", {})
		if typeof(p_d) == TYPE_DICTIONARY and typeof((p_d as Dictionary).get("lord")) == TYPE_DICTIONARY:
			var l_d := (p_d as Dictionary).get("lord") as Dictionary
			if int(l_d.get("injured_until_unix", 0)) > now_unix:
				return _fail("lord_injured", "Lord yaralı olduğu için sefere katılamaz.")

	var origin := _find_village(state, from_village_id)
	var target := _find_village(state, to_village_id)
	var clean := normalize_units(units)
	var effective_options := options.duplicate(true)
	if bool(effective_options.get("include_lord", false)) and is_lord_on_march(state, str(origin.get("owner", ""))):
		effective_options["include_lord"] = false
		effective_options.erase("lord_snapshot")
	_deduct_units(origin, clean)

	var movement := _build(state, type, origin, target, clean, _zero_carry(), now_unix, effective_options)
	_append_movement(state, movement)

	var events: Array = []
	# Saldırı → yeni oyuncu koruması biter (yalnızca oyuncu/NPC köye saldırıda).
	if not Protection.is_unprotected_kind(target):
		var protection_event := Protection.on_attack_sent(origin, now_unix)
		if not protection_event.is_empty():
			events.append(protection_event)

	# 10:1 oranı → Kanun Kaçağı (yalnızca gerçek oyuncu köylerine saldırıda uygulanır; haydut/barbar köylerde uygulanmaz).
	var result := {
		"ok": true, "code": "", "message": "",
		"movement": movement, "events": events, "outlawed": false,
	}
	if not Protection.is_unprotected_kind(target):
		var attacker_points := Protection.player_points(state, str(origin.get("owner", "")))
		var defender_points := int(target.get("points", 0))
		if Protection.ratio_exceeded(attacker_points, defender_points):
			var mark := Protection.mark_outlaw(state, origin, now_unix)
			result["outlawed"] = true
			events.append({
				"type": "outlawed",
				"village_id": from_village_id,
				"owner": str(origin.get("owner", "")),
				"until": int(mark.get("until", 0)),
				"days": int(mark.get("days", 0)),
			})
	return result


## Destek: birlikler hedefte **savunma** olarak konuşlanır (`docs/09` §4).
static func send_support(
	state: Dictionary,
	from_village_id: int,
	to_village_id: int,
	units: Dictionary,
	now_unix: int
) -> Dictionary:
	var check := can_send(state, from_village_id, to_village_id, TYPE_SUPPORT, units, {}, now_unix)
	if not bool(check.get("ok", false)):
		return check

	var origin := _find_village(state, from_village_id)
	var target := _find_village(state, to_village_id)
	var clean := normalize_units(units)
	_deduct_units(origin, clean)

	var movement := _build(state, TYPE_SUPPORT, origin, target, clean, _zero_carry(), now_unix, {})
	movement["from_village_name"] = str(origin.get("name", ""))
	_append_movement(state, movement)
	return {"ok": true, "code": "", "message": "", "movement": movement, "events": []}


## Konuşlanmış destek birliğini geri çeker (gönderen oyuncu) veya geri gönderir (destek alan köy sahibi).
## Birlikler `target_village_id` garnizonundan ve `support` listesinden düşülür, `from_village_id` köyüne
## bir `return` (geri dönüş) seferi başlatılır.
static func recall_support(
	state: Dictionary,
	target_village_id: int,
	from_village_id: int,
	now_unix: int,
	support_index: int = -1
) -> Dictionary:
	var target := _find_village(state, target_village_id)
	if target.is_empty():
		return _fail("target_not_found", "Destek köyü bulunamadı.")
	var origin := _find_village(state, from_village_id)
	var support_raw = target.get("support", null)
	if typeof(support_raw) != TYPE_ARRAY or (support_raw as Array).is_empty():
		return _fail("support_not_found", "Köyde geri çağrılacak destek birliği yok.")

	var sup_arr: Array = support_raw
	var match_idx := -1
	if support_index >= 0 and support_index < sup_arr.size():
		var cand = sup_arr[support_index]
		if typeof(cand) == TYPE_DICTIONARY and (from_village_id <= 0 or int((cand as Dictionary).get("from_village_id", 0)) == from_village_id):
			match_idx = support_index
	if match_idx < 0:
		for i in range(sup_arr.size()):
			var entry = sup_arr[i]
			if typeof(entry) == TYPE_DICTIONARY and int((entry as Dictionary).get("from_village_id", 0)) == from_village_id:
				match_idx = i
				break
	if match_idx < 0:
		return _fail("support_not_found", "Belirtilen köye ait destek birliği bulunamadı.")

	var sup_entry: Dictionary = sup_arr[match_idx]
	var actual_from_id := int(sup_entry.get("from_village_id", from_village_id))
	if origin.is_empty() and actual_from_id > 0:
		origin = _find_village(state, actual_from_id)

	var sup_units := normalize_units(sup_entry.get("units", {}))
	var target_units: Dictionary = target.get("units", {}) if typeof(target.get("units")) == TYPE_DICTIONARY else {}
	var returning_units: Dictionary = {}
	for u_key in sup_units.keys():
		var req_cnt := int(sup_units.get(u_key, 0))
		if req_cnt <= 0:
			continue
		var have_cnt := maxi(0, int(target_units.get(u_key, 0)))
		var take_cnt := mini(req_cnt, have_cnt) if have_cnt > 0 else req_cnt
		target_units[u_key] = maxi(0, have_cnt - req_cnt)
		if take_cnt > 0:
			returning_units[u_key] = take_cnt
	target["units"] = target_units

	var dismissed_key := "%d:%d" % [actual_from_id, int(sup_entry.get("arrive_unix", 0))]
	var dis_list: Array = target.get("dismissed_support_keys", []) if typeof(target.get("dismissed_support_keys")) == TYPE_ARRAY else []
	if not dis_list.has(dismissed_key):
		dis_list.append(dismissed_key)
	target["dismissed_support_keys"] = dis_list
	sup_arr.remove_at(match_idx)

	if _sum(returning_units) <= 0:
		return {"ok": true, "code": "", "message": "Destek kaydı temizlendi.", "movement": {}, "events": []}

	var from_x := int(target.get("x", 100))
	var from_y := int(target.get("y", 100))
	var to_x := int(origin.get("x", 100)) if not origin.is_empty() else from_x
	var to_y := int(origin.get("y", 100)) if not origin.is_empty() else from_y
	var slowest := Travel.slowest_speed(returning_units)
	var travel_secs := maxi(1, int(round(Travel.travel_seconds(from_x, from_y, to_x, to_y, slowest))))
	var mov_id := next_id(state)
	var ret_owner := str(origin.get("owner", str(sup_entry.get("owner", "")))) if not origin.is_empty() else str(sup_entry.get("owner", ""))

	var ret_movement := {
		"id": mov_id,
		"village_id": actual_from_id,
		"owner": ret_owner,
		"type": TYPE_RETURN,
		"state": "returning",
		"support_return": true,
		"from_village_id": target_village_id,
		"from_x": from_x,
		"from_y": from_y,
		"to_village_id": actual_from_id,
		"to_x": to_x,
		"to_y": to_y,
		"units": returning_units.duplicate(true),
		"carry": _zero_carry(),
		"depart_unix": now_unix,
		"arrive_unix": now_unix + travel_secs,
		"return_unix": now_unix + travel_secs,
		"base_travel_seconds": travel_secs,
	}
	_append_movement(state, ret_movement)
	return {
		"ok": true,
		"code": "",
		"message": "Destek birlikleri geri dönüşe geçti.",
		"movement": ret_movement,
		"events": [{
			"type": "support_recalled",
			"village_id": actual_from_id,
			"from_support_village_id": target_village_id,
			"units": returning_units.duplicate(true),
		}],
	}


## Ticaret (katır): hammadde transferi (`docs/14`). Kaynaklar gönderimde düşülür.
static func send_trade(
	state: Dictionary,
	from_village_id: int,
	to_village_id: int,
	resources: Dictionary,
	now_unix: int
) -> Dictionary:
	var check := can_send(state, from_village_id, to_village_id, TYPE_TRADE, {}, resources, now_unix)
	if not bool(check.get("ok", false)):
		return check

	var origin := _find_village(state, from_village_id)
	var target := _find_village(state, to_village_id)
	var clean := normalize_resources(resources)
	_deduct_resources(origin, clean)

	# Katır yolculuğu: bilinen birim hızı yok → seçilen katır hızı (bkz. ASSUMPTIONS.md #4).
	var movement := _build(
		state, TYPE_TRADE, origin, target, {}, clean, now_unix,
		{"slowest_unit_speed": DONKEY_MINUTES_PER_FIELD}
	)
	_append_movement(state, movement)
	return {"ok": true, "code": "", "message": "", "movement": movement, "events": []}


## Casusluk. `options`: {"seed":int, "creeping":bool} (gizli casusluk = 3× yavaş).
static func send_spy(
	state: Dictionary,
	from_village_id: int,
	to_village_id: int,
	units: Dictionary,
	now_unix: int,
	options: Dictionary = {}
) -> Dictionary:
	var check := can_send(state, from_village_id, to_village_id, TYPE_SPY, units, {}, now_unix)
	if not bool(check.get("ok", false)):
		return check

	var origin := _find_village(state, from_village_id)
	var target := _find_village(state, to_village_id)
	var clean := normalize_units(units)
	_deduct_units(origin, clean)

	var build_options := options.duplicate(true)
	if bool(options.get("creeping", false)):
		var spy_speed := RE.unit_speed("spy")
		if spy_speed <= 0.0:
			spy_speed = Travel.unit_minutes_per_field("spy")
		build_options["slowest_unit_speed"] = spy_speed * CREEPING_SPEED_MULTIPLIER

	var movement := _build(state, TYPE_SPY, origin, target, clean, _zero_carry(), now_unix, build_options)
	movement["creeping"] = bool(options.get("creeping", false))
	# Normal casusluk savunana görünür; gizli casusluk görünmez (units_espionage.txt).
	movement["visible_to_defender"] = not bool(options.get("creeping", false))
	_append_movement(state, movement)
	return {"ok": true, "code": "", "message": "", "movement": movement, "events": []}


# =============================================================================
#  İptal
# =============================================================================

## Bir hareketi iptal eder (saldırı 30 dk, katır 15 dk penceresi — `docs/09` §6).
## Bekleyen birlikler/hammaddeler kaynak köye **iade edilir**.
## Dönüş: `{"ok","code","message","movement","events"}`.
static func cancel(state: Dictionary, movement_id: int, now_unix: int) -> Dictionary:
	var movements = state.get("movements", null)
	if typeof(movements) != TYPE_ARRAY:
		return _fail("not_found", "Hareket bulunamadı.")
	var arr: Array = movements
	for i in range(arr.size()):
		var entry = arr[i]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var movement: Dictionary = entry
		if int(movement.get("id", -1)) != movement_id:
			continue
		if str(movement.get("state", "outgoing")) != "outgoing" or str(movement.get("type", "")) == TYPE_RETURN:
			return _fail("not_cancellable", "Yalnızca yolda olan emirler iptal edilebilir.")
		var is_trade := str(movement.get("type", "")) == TYPE_TRADE
		if not Travel.can_cancel(int(movement.get("depart_unix", 0)), now_unix, is_trade):
			return _fail("window_closed", "İptal süresi (%d dk) geçti." % int(Travel.cancel_window_seconds(is_trade) / 60.0))
		# İade.
		var origin := _find_village(state, int(movement.get("village_id", 0)))
		if not origin.is_empty():
			if is_trade:
				_add_resources(origin, movement.get("carry", {}))
			else:
				_add_units(origin, movement.get("units", {}))
		arr.remove_at(i)
		return {
			"ok": true, "code": "", "message": "Emir iptal edildi.",
			"movement": movement,
			"events": [{
				"type": "movement_cancelled",
				"village_id": int(movement.get("village_id", 0)),
				"movement_id": movement_id,
				"movement_type": str(movement.get("type", "")),
			}],
		}
	return _fail("not_found", "Hareket bulunamadı.")


# =============================================================================
#  Yardımcılar (kamu)
# =============================================================================

## Bu harekette kullanılacak bir sonraki hareket kimliği (mevcut en büyük + 1).
static func next_id(state: Dictionary) -> int:
	var max_id := 0
	var movements = state.get("movements", null)
	if typeof(movements) == TYPE_ARRAY:
		for entry in (movements as Array):
			if typeof(entry) == TYPE_DICTIONARY:
				var md := entry as Dictionary
				max_id = maxi(max_id, int(md.get("id", 0)))
				max_id = maxi(max_id, int(md.get("origin_movement_id", 0)))
	var w_val = state.get("world", null)
	if typeof(w_val) == TYPE_DICTIONARY:
		var w := w_val as Dictionary
		max_id = maxi(max_id, int(w.get("next_movement_id", 0)))
		var next_val := max_id + 1
		w["next_movement_id"] = next_val
		return next_val
	return max_id + 1


## Deterministik savaş tohumu (global `randi()` YASAK — docs/19 §2.3).
static func derive_seed(from_village_id: int, to_village_id: int, now_unix: int, movement_id: int) -> int:
	var h: int = from_village_id * 2654435761
	h += to_village_id * 40503
	h += now_unix * 97
	h += movement_id * 1000003
	var seed := h % 2147483647
	if seed < 0:
		seed += 2147483647
	return seed


## Ondalıklı/anlamsız değerleri kırpıp yalnızca **pozitif** birimleri döndürür.
static func normalize_units(raw: Dictionary) -> Dictionary:
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


## Hammadde sözlüğünü `{wood,stone,iron}` şeklinde normalize eder (negatif → 0).
static func normalize_resources(raw) -> Dictionary:
	var out := {"wood": 0, "stone": 0, "iron": 0}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	for r in RESOURCES:
		out[r] = maxi(0, int((raw as Dictionary).get(r, 0)))
	return out


## İki köy arasındaki alan mesafesi (Öklid).
static func distance_between(a: Dictionary, b: Dictionary) -> float:
	return Travel.distance(int(a.get("x", 0)), int(a.get("y", 0)), int(b.get("x", 0)), int(b.get("y", 0)))


# =============================================================================
#  İç yardımcılar
# =============================================================================

static func _build(
	state: Dictionary,
	type: String,
	origin: Dictionary,
	target: Dictionary,
	units: Dictionary,
	carry: Dictionary,
	now_unix: int,
	options: Dictionary
) -> Dictionary:
	var from_id := int(origin.get("id", 0))
	var to_id := int(target.get("id", 0))
	var movement_id := next_id(state)
	var seed_override := int(options.get("seed", -1))
	var battle_seed := seed_override if seed_override >= 0 else derive_seed(from_id, to_id, now_unix, movement_id)

	var data := {
		"id": movement_id,
		"village_id": from_id,
		"type": type,
		"from_village_id": from_id,
		"to_village_id": to_id,
		"from_x": int(origin.get("x", 0)),
		"from_y": int(origin.get("y", 0)),
		"to_x": int(target.get("x", 0)),
		"to_y": int(target.get("y", 0)),
		"units": units.duplicate(true),
		"carry": carry.duplicate(true),
		"depart_unix": now_unix,
		"battle_seed": battle_seed,
		"target_points": int(target.get("points", 0)),
	}
	if options.has("slowest_unit_speed"):
		data["slowest_unit_speed"] = float(options["slowest_unit_speed"])

	var movement := Travel.make_movement(data)
	movement["owner"] = str(origin.get("owner", ""))
	movement["include_lord"] = bool(options.get("include_lord", false))
	if typeof(options.get("lord_snapshot")) == TYPE_DICTIONARY:
		movement["lord_snapshot"] = (options["lord_snapshot"] as Dictionary).duplicate(true)
	return movement


static func _append_movement(state: Dictionary, movement: Dictionary) -> void:
	if typeof(state.get("movements")) != TYPE_ARRAY:
		state["movements"] = []
	(state["movements"] as Array).append(movement)


static func _find_village(state: Dictionary, village_id: int) -> Dictionary:
	var villages = state.get("villages", null)
	if typeof(villages) != TYPE_ARRAY:
		return {}
	for village in (villages as Array):
		if typeof(village) == TYPE_DICTIONARY and int((village as Dictionary).get("id", -1)) == village_id:
			return village
	return {}


static func _norm_owner(raw_name: String) -> String:
	var s := raw_name.strip_edges().to_lower()
	while s.find("  ") >= 0:
		s = s.replace("  ", " ")
	return s


## Kaynak ve hedef **aynı sahibe** mi ya da **aynı ittifakta** mı? (`docs/12` §7)
static func _is_friendly(state: Dictionary, origin: Dictionary, target: Dictionary) -> bool:
	var a := _norm_owner(str(origin.get("owner", "")))
	var b := _norm_owner(str(target.get("owner", "")))
	if a.is_empty() or b.is_empty():
		return false
	if a == b:
		return true
	return _share_alliance(state, a, b)


## Lord halihazırda gidiş/dönüş bir seferde mi? (Aynı anda yalnızca 1 sefere katılabilir; diğer ordular Lord olmadan çıkabilir.)
static func is_lord_on_march(state: Dictionary, owner_name: String) -> bool:
	var norm := _norm_owner(owner_name)
	var movs = state.get("movements", null)
	if typeof(movs) != TYPE_ARRAY:
		return false
	for raw_m in (movs as Array):
		if typeof(raw_m) != TYPE_DICTIONARY:
			continue
		var m := raw_m as Dictionary
		if not bool(m.get("include_lord", false)):
			continue
		if str(m.get("type", "")) == TYPE_SPY:
			continue
		var m_owner := _norm_owner(str(m.get("owner", "")))
		if norm.is_empty() or m_owner.is_empty() or m_owner == norm:
			return true
	return false


static func _share_alliance(state: Dictionary, a: String, b: String) -> bool:
	var na := _norm_owner(a)
	var nb := _norm_owner(b)
	if na.is_empty() or nb.is_empty():
		return false
	var alliances = state.get("alliances", null)
	if typeof(alliances) != TYPE_ARRAY:
		return false
	for alliance in (alliances as Array):
		if typeof(alliance) != TYPE_DICTIONARY:
			continue
		var members = (alliance as Dictionary).get("members", [])
		if typeof(members) != TYPE_ARRAY:
			continue
		var has_a := false
		var has_b := false
		for m in members:
			var m_name := ""
			if typeof(m) == TYPE_STRING:
				m_name = _norm_owner(str(m))
			elif typeof(m) == TYPE_DICTIONARY:
				m_name = _norm_owner(str((m as Dictionary).get("name", "")))
			if m_name == na:
				has_a = true
			if m_name == nb:
				has_b = true
		if has_a and has_b:
			return true
	return false


static func _units_available(origin: Dictionary, units: Dictionary) -> Dictionary:
	var have = origin.get("units", null)
	if typeof(have) != TYPE_DICTIONARY:
		return _fail("units_unavailable", "Kaynak köyde birlik yok.")
	for key in units.keys():
		if int((have as Dictionary).get(key, 0)) < int(units[key]):
			return _fail("units_unavailable", "%s: yeterli birlik yok." % str(key))
	return _ok()


static func _deduct_units(village: Dictionary, units: Dictionary) -> void:
	if typeof(village.get("units")) != TYPE_DICTIONARY:
		village["units"] = {}
	var have: Dictionary = village["units"]
	for key in units.keys():
		have[str(key)] = maxi(0, int(have.get(str(key), 0)) - int(units[key]))


static func _add_units(village: Dictionary, units: Dictionary) -> void:
	if typeof(village.get("units")) != TYPE_DICTIONARY:
		village["units"] = {}
	var have: Dictionary = village["units"]
	for key in units.keys():
		have[str(key)] = int(have.get(str(key), 0)) + int(units[key])


static func _deduct_resources(village: Dictionary, resources: Dictionary) -> void:
	if typeof(village.get("resources")) != TYPE_DICTIONARY:
		village["resources"] = {"wood": 0, "stone": 0, "iron": 0}
	var have: Dictionary = village["resources"]
	for r in RESOURCES:
		have[r] = maxi(0, int(have.get(r, 0)) - int(resources.get(r, 0)))


static func _add_resources(village: Dictionary, resources: Dictionary) -> void:
	if typeof(village.get("resources")) != TYPE_DICTIONARY:
		village["resources"] = {"wood": 0, "stone": 0, "iron": 0}
	var have: Dictionary = village["resources"]
	for r in RESOURCES:
		have[r] = int(have.get(r, 0)) + int(resources.get(r, 0))


static func _building_level(village: Dictionary, key: String) -> int:
	var b = village.get("buildings", null)
	if typeof(b) != TYPE_DICTIONARY:
		return 0
	return int((b as Dictionary).get(key, 0))


static func _count_max_distance() -> int:
	var cfg = null
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		cfg = (loop as SceneTree).root.get_node_or_null("GameConfig")
	if cfg != null:
		var value = cfg.get("count_max_distance")
		if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
			return int(value)
	return 80


static func _zero_carry() -> Dictionary:
	return {"wood": 0, "stone": 0, "iron": 0}


static func _sum(d: Dictionary) -> int:
	var total := 0
	for key in d.keys():
		total += int(d[key])
	return total


static func _ok() -> Dictionary:
	return {"ok": true, "code": "", "message": ""}


static func _fail(code: String, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}
