extends RefCounted
## Arrival.gd — varışta çözümleme + dönüş hareketi üretimi (Taht ve Kılıç / **A-KESIF**).
##
## Sözleşme: `docs/19-MOTOR-API-SOZLESMESI.md` §3.3 (hareket) + §7 (savaş imzası) + §2 (determinizm).
## Savaş **hazır** `BattleSimulator.simulate()` ile çözülür; rapor metni `BattleReport`'tan gelir.
##
## ## Varışta ne olur?
##  • `attack`  → 5 fazlı muharebe → savunan kayıpları (birim/bina) uygulanır, ganimet alınır,
##    fetih denenir → **dönüş hareketi** (hayatta kalan birlikler + ganimet).
##  • `raid`    → muharebe + yağma; **fetih yok** → dönüş hareketi.
##  • `spy`     → casus fazı (A-SAVAS) → başarılıysa **casusluk raporu**; casuslar döner.
##  • `support` → birlikler hedefte **savunma** olarak kalır (`docs/09` §4).
##  • `trade`   → hammaddeler hedefe teslim edilir; katır **kaybolur** (`docs/14` §5).
##
## ## Dönüş
## **Dönüş süresi = gidiş süresi** (`docs/19` §6 kararı): dönüş hareketinin süresi, gidiş
## hareketinin süresinden kopyalanır (hayatta kalan ordunun kompozisyonu değişse bile).
## Ganimet **dönüşte** taşınır ve dönüşte kaynak köye eklenir (`docs/09` §5).
##
## ## Determinizm
## Tüm rastgelelik `movement.battle_seed` ile tohumlanan `BattleSimulator`'a aittir;
## bu modül global `randi()` **kullanmaz** (`docs/19` §2.3).

const RE := preload("res://scripts/rules/RulesEngine.gd")
const BS := preload("res://scripts/sim/battle/BattleSimulator.gd")
const BR := preload("res://scripts/sim/battle/BattleReport.gd")
const Protection := preload("res://scripts/sim/actions/Protection.gd")
const LordModelScript := preload("res://scripts/model/LordModel.gd")

const RESOURCES := ["wood", "stone", "iron"]

## Fetih sonrası Güç Alanı = maksimumun %30'u (`docs/08` §2).
const POST_CONQUEST_RATIO := 0.30


# =============================================================================
#  Giriş noktası
# =============================================================================

## Varmış bir hareketi çözer.
## Dönüş: `{"events": Array[Dictionary], "return": Dictionary}` (`return` boş = dönüş yok).
static func resolve(state: Dictionary, movement: Dictionary, now_unix: int) -> Dictionary:
	var type := str(movement.get("type", ""))
	match type:
		"attack", "raid":
			return _resolve_battle(state, movement, now_unix, type == "raid")
		"spy":
			return _resolve_spy(state, movement, now_unix)
		"support":
			return _resolve_support(state, movement, now_unix)
		"trade":
			return _resolve_trade(state, movement, now_unix)
	return {"events": [], "return": {}}


# =============================================================================
#  Savaş / talan (attack, raid)
# =============================================================================

static func _norm_owner_arr(raw: String) -> String:
	var s := raw.strip_edges().to_lower()
	while s.find("  ") >= 0:
		s = s.replace("  ", " ")
	return s


static func _is_friendly_at_arrival(state: Dictionary, origin: Dictionary, target: Dictionary) -> bool:
	var a := _norm_owner_arr(str(origin.get("owner", "")))
	var b := _norm_owner_arr(str(target.get("owner", "")))
	if a.is_empty() or b.is_empty():
		return false
	if a == b:
		return true
	var alliances = state.get("alliances", null)
	if typeof(alliances) != TYPE_ARRAY:
		return false
	for ally in (alliances as Array):
		if typeof(ally) != TYPE_DICTIONARY:
			continue
		var mems = (ally as Dictionary).get("members", [])
		if typeof(mems) != TYPE_ARRAY:
			continue
		var has_a := false
		var has_b := false
		for m in mems:
			var mn := _norm_owner_arr(str((m as Dictionary).get("name", ""))) if typeof(m) == TYPE_DICTIONARY else _norm_owner_arr(str(m))
			if mn == a:
				has_a = true
			if mn == b:
				has_b = true
		if has_a and has_b:
			return true
	return false


static func _resolve_battle(
	state: Dictionary, movement: Dictionary, now_unix: int, is_raid: bool
) -> Dictionary:
	var from_id := int(movement.get("from_village_id", movement.get("village_id", 0)))
	var to_id := int(movement.get("to_village_id", 0))
	var origin := _find_village(state, from_id)
	var target := _find_village(state, to_id)
	var units := _normalize_units(movement.get("units", {}))

	# Hedef yok olduysa veya artık aynı/ittifak üyesi ise → savaş yapılmaz, ordu geri döner.
	if origin.is_empty() or target.is_empty() or _is_friendly_at_arrival(state, origin, target):
		return _fizzle(state, movement, origin, units)

	var is_bandit := bool(target.get("is_bandit", false)) or bool(target.get("is_bot", false))
	var bandit_lvl := LordModelScript.bandit_level_for_village(target) if is_bandit else 0

	var attacker := _attacker_payload(state, origin, units, movement, now_unix)
	var defender := _defender_payload(state, target, movement, is_bandit, bandit_lvl, now_unix)
	var options := {
		"seed": int(movement.get("battle_seed", 0)),
		"is_raid": is_raid,
		"night": _is_night(now_unix),
		"speed": _speed(),
		"raider_points": int(attacker.get("points", 0)),
	}
	var result: Dictionary = BS.simulate(attacker, defender, options)

	# --- Savunan kayıpları (birim + destek kayıtları) ---
	var def_losses = result.get("defender_losses", {})
	var def_before := _normalize_units(target.get("units", {}))
	_subtract_units(target, def_losses)
	_subtract_support_losses(target, def_before, def_losses)

	# --- Bina hasarı (kalıcı, haydut köylerinde şablona sıfırlanır) ---
	var buildings_after = result.get("buildings_after", {})
	if not is_bandit and typeof(buildings_after) == TYPE_DICTIONARY and not (buildings_after as Dictionary).is_empty():
		target["buildings"] = (buildings_after as Dictionary).duplicate(true)
		_refresh_points(target)
	var points := int(target.get("points", 0))

	# --- Yağma (gizli depo zaten A-SAVAS'ta düşülür) ---
	var loot := _normalize_resources(result.get("loot", {}))
	_subtract_resources(target, loot)

	# --- Haydut Köyü: asla fethedilemez ve ordusu savaş bitince anında yenilenir ---
	if is_bandit:
		var tmpl := LordModelScript.bandit_template(bandit_lvl)
		target["is_bandit"] = true
		target["is_bot"] = true
		target["bandit_level"] = bandit_lvl
		target["bandit_initialized"] = true
		target["owner"] = str(tmpl.get("owner", "Haydutlar"))
		target["units"] = (tmpl.get("units", {}) as Dictionary).duplicate(true)
		target["buildings"] = (tmpl.get("buildings", {}) as Dictionary).duplicate(true)
		target["points"] = int(tmpl.get("points", points))
		target["realm_of_power"] = int(tmpl.get("points", points))
		points = int(target["points"])

	# --- Fetih / Güç Alanı ---
	var conquest_protected := Protection.is_conquest_protected(target, now_unix)
	var conquered := bool(result.get("conquered", false)) and not is_raid and not conquest_protected and not is_bandit
	var count_survived := bool(result.get("count_survived", false))
	var conquest_blocked := conquest_protected and not is_raid and bool(result.get("attacker_won", false)) and count_survived

	var events: Array = []
	if conquered:
		var conquest_event := _apply_conquest(state, origin, target, result, now_unix)
		events.append(conquest_event)
	else:
		if conquest_blocked:
			events.append({
				"type": "conquest_blocked",
				"village_id": to_id,
				"reason": "conquest_protection",
			})
		var realm_after := int(result.get("realm_of_power_after", -1))
		if is_bandit:
			target["realm_of_power"] = points
		elif not conquest_protected and realm_after >= 0:
			target["realm_of_power"] = clampi(realm_after, 0, maxi(0, points))
		else:
			target["realm_of_power"] = clampi(int(target.get("realm_of_power", maxi(0, points))), 0, maxi(0, points))

	# --- Haydut Köyü Rastgele Ekipman Düşürme & Lord Yaralanma ---
	var dropped_item: Dictionary = {}
	var atk_is_player := _is_state_player_village(state, origin)
	var def_is_player := (not is_bandit) and _is_state_player_village(state, target)
	if is_bandit and bool(result.get("attacker_won", false)) and atk_is_player:
		dropped_item = _grant_bandit_drop_in_state(state, bandit_lvl, str(target.get("name", "")), now_unix)
		if not dropped_item.is_empty():
			events.append({
				"type": "lord_item_dropped",
				"village_id": from_id,
				"bandit_level": bandit_lvl,
				"item": dropped_item.duplicate(true),
			})

	if bool(result.get("attacker_lord_injured", false)) and atk_is_player:
		var injured_until := _injure_player_lord_in_state(state, float(result.get("attacker_loss_frac", 1.0)), now_unix)
		events.append({"type": "lord_injured", "village_id": from_id, "injured_until_unix": injured_until})
	if bool(result.get("defender_lord_injured", false)) and def_is_player:
		var def_injured_until := _injure_player_lord_in_state(state, float(result.get("defender_loss_frac", 1.0)), now_unix)
		events.append({"type": "lord_injured", "village_id": to_id, "injured_until_unix": def_injured_until})

	# --- Savaş raporu ---
	var rep_data := _battle_report_data(result, attacker, defender, movement, is_raid, conquered, conquest_blocked, target)
	if not dropped_item.is_empty():
		rep_data["dropped_item"] = dropped_item.duplicate(true)
	if is_bandit:
		rep_data["is_bandit"] = true
		rep_data["bandit_level"] = bandit_lvl
	_add_report(state, "battle", from_id, now_unix, rep_data)

	events.append({
		"type": "battle_resolved",
		"village_id": from_id,
		"target_village_id": to_id,
		"attacker_won": bool(result.get("attacker_won", false)),
		"is_raid": is_raid,
		"loot": loot.duplicate(true),
		"conquered": conquered,
		"is_bandit": is_bandit,
		"bandit_level": bandit_lvl,
		"dropped_item": dropped_item.duplicate(true),
		"attacker_losses": (result.get("attacker_losses", {}) as Dictionary).duplicate(true),
		"defender_losses": (result.get("defender_losses", {}) as Dictionary).duplicate(true),
	})

	# --- Dönüş: hayatta kalan birlikler (fetih başarılıysa 1 Kont köyü yönetmek için kalır) + ganimet ---
	var survivors := _normalize_units(result.get("attacker_alive", {}))
	if conquered and int(survivors.get("snob", 0)) > 0:
		var rem_snob := int(survivors.get("snob", 0)) - 1
		if rem_snob > 0:
			survivors["snob"] = rem_snob
		else:
			survivors.erase("snob")
	var return_movement := _make_return(state, movement, origin, survivors, loot)
	return {"events": events, "return": return_movement}


## Fetih: köyün sahibi saldırana geçer, Güç Alanı maksimumun %30'una yükselir.
static func _apply_conquest(
	state: Dictionary, origin: Dictionary, target: Dictionary, result: Dictionary, now_unix: int
) -> Dictionary:
	var target_id := int(target.get("id", 0))
	var points := int(target.get("points", 0))
	var realm_after := int(result.get("realm_of_power_after", -1))
	if realm_after < 0:
		realm_after = int(floor(float(points) * POST_CONQUEST_RATIO + 0.5))
	var former_owner := str(target.get("owner", ""))
	var new_owner := str(origin.get("owner", "")).strip_edges()
	var origin_is_bot := bool(origin.get("is_bot", false))
	if new_owner.is_empty() and not origin_is_bot and typeof(state.get("player")) == TYPE_DICTIONARY:
		new_owner = str((state["player"] as Dictionary).get("name", "")).strip_edges()
	var cprot_until := now_unix + Protection.conquest_protection_days() * Protection.DAY_SECONDS
	target["owner"] = new_owner
	target["is_bot"] = origin_is_bot
	target["is_barbarian"] = false
	target["is_abandoned"] = false
	target.erase("abandoned_unix")
	target["is_conquered"] = true
	target["conquered_by"] = new_owner
	target["conquered_unix"] = now_unix
	target["last_active_unix"] = now_unix
	target["former_owner"] = former_owner
	var cur_tname := str(target.get("name", "")).strip_edges()
	if cur_tname.is_empty() or cur_tname == "Terk Edilmiş Köy":
		target["name"] = "Fethedilen Köy"
	target["protection_until"] = 0
	target["protection_until_unix"] = 0
	target["conquest_protection_until"] = cprot_until
	target["conquest_protection_until_unix"] = cprot_until
	target["realm_of_power"] = clampi(realm_after, 0, maxi(0, points))
	target["support"] = []
	target["settlers_reserved"] = 0
	target.erase("next_bot_think_unix")

	# Eski sahibine ait bekleyen kuyrukları temizle (köy el değiştirdi).
	var queues = state.get("queues", null)
	if typeof(queues) == TYPE_ARRAY:
		var q_arr := queues as Array
		for i in range(q_arr.size() - 1, -1, -1):
			var q = q_arr[i]
			if typeof(q) == TYPE_DICTIONARY and int((q as Dictionary).get("village_id", -1)) == target_id:
				q_arr.remove_at(i)

	if typeof(state.get("world")) == TYPE_DICTIONARY and (state["world"] as Dictionary).has("villages"):
		(state["world"] as Dictionary)["villages"] = state.get("villages", [])

	return {
		"type": "village_conquered",
		"village_id": target_id,
		"former_owner": former_owner,
		"owner": new_owner,
		"new_owner": new_owner,
		"realm_of_power": int(target.get("realm_of_power", 0)),
	}


# =============================================================================
#  Casusluk (spy)
# =============================================================================

static func _resolve_spy(state: Dictionary, movement: Dictionary, now_unix: int) -> Dictionary:
	var from_id := int(movement.get("from_village_id", movement.get("village_id", 0)))
	var to_id := int(movement.get("to_village_id", 0))
	var origin := _find_village(state, from_id)
	var target := _find_village(state, to_id)
	var units := _normalize_units(movement.get("units", {}))
	var creeping := bool(movement.get("creeping", false))
	movement["visible_to_defender"] = not creeping

	if origin.is_empty() or target.is_empty():
		return _fizzle(state, movement, origin, units)

	var attacker := _attacker_payload(state, origin, units)
	var defender := _defender_payload(state, target, movement)
	var result: Dictionary = BS.simulate(attacker, defender, {
		"seed": int(movement.get("battle_seed", 0)),
		"is_raid": false,
		"night": _is_night(now_unix),
		"speed": _speed(),
	})

	var spy_data := _spy_phase_data(result)
	var survivors := int(spy_data.get("spy_survivors", 0))
	var losses := int(spy_data.get("spy_losses", 0))
	var defence_spies := int(spy_data.get("defence_spies", 0))
	var success := survivors > 0
	# Normal casusluk GÖRÜNÜR → savunan rapor alır; tüm casuslar yakalanıp öldürüldüğünde de savunan haberdar olur.
	var defender_notified := (not creeping) or (not success)

	var events: Array = [{
		"type": "spy_resolved",
		"village_id": from_id,
		"target_village_id": to_id,
		"success": success,
		"survivors": survivors,
		"losses": losses,
		"defence_spies": defence_spies,
		"creeping": creeping,
		"visible_to_defender": not creeping,
		"defender_notified": defender_notified,
	}]

	if success:
		_add_report(state, "spy", from_id, now_unix,
			_spy_report_data(state, target, defender, spy_data, movement, creeping))
		# Normal casuslukta savunan da (saldırıldığına dair) rapor alır.
		if defender_notified:
			_add_report(state, "spy_incoming", to_id, now_unix,
				_spy_incoming_data(target, origin, spy_data, movement))
	else:
		# Tüm casuslar öldü: saldırana başarısız casusluk raporu (hiçbir askeri/maden bilgisi olmadan), savunana yakalama raporu.
		_add_report(state, "spy", from_id, now_unix, {
			"from_village_id": from_id,
			"from_name": str(origin.get("name", "")),
			"attacker_owner": str(origin.get("owner", "")),
			"target_village_id": to_id,
			"target_name": str(target.get("name", "")),
			"defender_name": str(target.get("owner", "")),
			"spy_survivors": 0,
			"spy_losses": losses,
			"defence_spies": 0,
			"creeping": creeping,
			"failed": true,
		})
		_add_report(state, "spy_incoming", to_id, now_unix,
			_spy_incoming_data(target, origin, spy_data, movement))

	var survivors_units := {}
	if survivors > 0:
		survivors_units["spy"] = survivors
	var return_movement := _make_return(state, movement, origin, survivors_units, _zero_carry())
	return {"events": events, "return": return_movement}


# =============================================================================
#  Destek (support)
# =============================================================================

static func _resolve_support(state: Dictionary, movement: Dictionary, now_unix: int) -> Dictionary:
	var from_id := int(movement.get("from_village_id", movement.get("village_id", 0)))
	var to_id := int(movement.get("to_village_id", 0))
	var origin := _find_village(state, from_id)
	var target := _find_village(state, to_id)
	var units := _normalize_units(movement.get("units", {}))

	if target.is_empty():
		# Hedef yok → birlikler eve döner.
		return _fizzle(state, movement, origin, units)

	# Birlikler hedefte **savunma** olarak durur (birleşik savunma).
	_add_units(target, units)
	var support_list = target.get("support", null)
	if typeof(support_list) != TYPE_ARRAY:
		support_list = []
		target["support"] = support_list
	var orig_owner := str(origin.get("owner", str(movement.get("owner", "")))) if not origin.is_empty() else str(movement.get("owner", ""))
	var orig_vname := str(origin.get("name", "")) if not origin.is_empty() else str(movement.get("from_village_name", ""))
	(support_list as Array).append({
		"from_village_id": from_id,
		"from_village_name": orig_vname,
		"owner": orig_owner,
		"village_id": to_id,
		"units": units.duplicate(true),
		"arrive_unix": now_unix,
	})

	return {"events": [{
		"type": "support_arrived",
		"village_id": to_id,
		"from_village_id": from_id,
		"units": units.duplicate(true),
	}], "return": {}}


# =============================================================================
#  Ticaret (trade)
# =============================================================================

static func _resolve_trade(state: Dictionary, movement: Dictionary, now_unix: int) -> Dictionary:
	var from_id := int(movement.get("from_village_id", movement.get("village_id", 0)))
	var to_id := int(movement.get("to_village_id", 0))
	var origin := _find_village(state, from_id)
	var target := _find_village(state, to_id)
	var carry := _normalize_resources(movement.get("carry", {}))

	if target.is_empty():
		# Hedef yok → hammadde kaynak köye iade edilir (katır kayıp).
		if not origin.is_empty():
			_add_resources(origin, carry)
		return {"events": [{
			"type": "trade_failed",
			"village_id": from_id,
			"target_village_id": to_id,
			"resources": carry.duplicate(true),
		}], "return": {}}

	_add_resources(target, carry)
	_add_report(state, "trade", from_id, now_unix, {
		"type": "trade",
		"from_village_id": from_id,
		"target_village_id": to_id,
		"resources": carry.duplicate(true),
	})
	return {"events": [{
		"type": "trade_delivered",
		"village_id": to_id,
		"from_village_id": from_id,
		"resources": carry.duplicate(true),
	}], "return": {}}


# =============================================================================
#  Yardımcılar
# =============================================================================

static func _make_return(
	state: Dictionary, movement: Dictionary, origin: Dictionary, units: Dictionary, carry: Dictionary
) -> Dictionary:
	if _sum(units) <= 0 and _sum(carry) <= 0:
		return {}
	var origin_id := int(movement.get("village_id", movement.get("from_village_id", 0)))
	var depart := int(movement.get("arrive_unix", 0))
	var travel := int(movement.get("base_travel_seconds", maxi(0, depart - int(movement.get("depart_unix", 0)))))
	return {
		"id": _next_movement_id(state),
		"origin_movement_id": int(movement.get("id", 0)),
		"village_id": origin_id,
		"type": "return",
		"from_village_id": int(movement.get("to_village_id", 0)),
		"from_x": int(movement.get("to_x", 0)),
		"from_y": int(movement.get("to_y", 0)),
		"to_village_id": origin_id,
		"to_x": int(origin.get("x", 0)) if not origin.is_empty() else 0,
		"to_y": int(origin.get("y", 0)) if not origin.is_empty() else 0,
		"units": units.duplicate(true),
		"carry": carry.duplicate(true),
		"depart_unix": depart,
		"arrive_unix": depart + travel,
		"return_unix": depart + travel,
		"state": "returning",
		"battle_seed": int(movement.get("battle_seed", 0)),
		"target_points": int(movement.get("target_points", 0)),
		"owner": str(origin.get("owner", "")) if not origin.is_empty() else "",
	}


## Hedef/kaynak köy yok ise ordu (varsa) eve döner.
static func _fizzle(
	state: Dictionary, movement: Dictionary, origin: Dictionary, units: Dictionary
) -> Dictionary:
	var return_movement := {}
	if not origin.is_empty() and _sum(units) > 0:
		return_movement = _make_return(state, movement, origin, units, _zero_carry())
	return {"events": [{
		"type": "movement_fizzled",
		"village_id": int(movement.get("village_id", 0)),
		"movement_id": int(movement.get("id", 0)),
	}], "return": return_movement}


static func _is_state_player_village(state: Dictionary, village: Dictionary) -> bool:
	if bool(village.get("is_bot", false)) or bool(village.get("is_barbarian", false)) or bool(village.get("is_bandit", false)):
		return false
	var p = state.get("player", {})
	if typeof(p) != TYPE_DICTIONARY:
		return false
	var p_name := _norm_owner_arr(str((p as Dictionary).get("name", "")))
	var v_name := _norm_owner_arr(str(village.get("owner", "")))
	return (not p_name.is_empty()) and (v_name == p_name)


static func _player_lord_combat_payload(state: Dictionary, now_unix: int) -> Dictionary:
	var p = state.get("player", {})
	if typeof(p) != TYPE_DICTIONARY:
		return {"present": false}
	var ld := LordModelScript.ensure_state_dict((p as Dictionary).get("lord", null))
	if int(ld.get("injured_until_unix", 0)) > now_unix:
		return {"present": false}
	var st := LordModelScript.compute_lord_stats(ld)
	st["present"] = true
	return st


static func _push_speech_to_state_lord(ld: Dictionary, type: String, title: String, text: String, target_action: String, item_id: String, now_unix: int) -> void:
	var q: Array = ld.get("speech_queue", []) if typeof(ld.get("speech_queue")) == TYPE_ARRAY else []
	q.append({
		"id": "%s_%d_%d" % [type, now_unix, q.size()],
		"type": type,
		"title": title,
		"text": text,
		"target_action": target_action,
		"item_id": item_id,
		"created_unix": now_unix,
	})
	while q.size() > 12:
		q.remove_at(0)
	ld["speech_queue"] = q


static func _grant_bandit_drop_in_state(state: Dictionary, bandit_level: int, village_name: String, now_unix: int) -> Dictionary:
	if typeof(state.get("player")) != TYPE_DICTIONARY:
		return {}
	var p := state["player"] as Dictionary
	var ld := LordModelScript.ensure_state_dict(p.get("lord", null))
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var seq := maxi(1, int(ld.get("next_item_seq", 1)))
	ld["next_item_seq"] = seq + 1
	var item := LordModelScript.roll_bandit_drop(bandit_level, rng, seq, village_name, now_unix)
	(ld["inventory"] as Array).append(item)
	var lvl := clampi(bandit_level, 1, 10)
	var prev_hi := int(ld.get("highest_bandit_cleared", 0))
	if lvl > prev_hi:
		ld["highest_bandit_cleared"] = lvl
		if lvl < 10 and (lvl == 3 or lvl == 5 or lvl == 7):
			_push_speech_to_state_lord(
				ld, "bandit_unlock", "Yeni Haydut Seviyesi!",
				"Sv.%d Haydut Köyünü aştın! Haritada Sv.%d+ köylerinden daha nadir ganimet düşürebilirsin." % [lvl, lvl + 1],
				"lord_screen", "", now_unix
			)
	_push_speech_to_state_lord(
		ld, "item_drop", "Yeni Ekipman Kazandın!",
		"%s yağmasından [%s] %s (+%d) elde ettin!" % [
			village_name if not village_name.is_empty() else ("Haydut Köyü Sv.%d" % lvl),
			LordModelScript.rarity_label(str(item.get("rarity", "common"))),
			str(item.get("name", "Ekipman")),
			int(item.get("plus", 0)),
		],
		"item_detail", str(item.get("id", "")), now_unix
	)
	ld["updated_unix"] = now_unix
	p["lord"] = ld
	return item


static func _injure_player_lord_in_state(state: Dictionary, loss_ratio: float, now_unix: int) -> int:
	if typeof(state.get("player")) != TYPE_DICTIONARY:
		return 0
	var p := state["player"] as Dictionary
	var ld := LordModelScript.ensure_state_dict(p.get("lord", null))
	var dur := clampi(
		int(round(lerpf(float(LordModelScript.INJURY_MIN_SECONDS), float(LordModelScript.INJURY_MAX_SECONDS), clampf(loss_ratio, 0.0, 1.0)))),
		LordModelScript.INJURY_MIN_SECONDS,
		LordModelScript.INJURY_MAX_SECONDS
	)
	var until := maxi(int(ld.get("injured_until_unix", 0)), now_unix + dur)
	ld["injured_until_unix"] = until
	ld["last_injury_duration"] = dur
	ld["recovery_notified_until"] = 0
	var mins := int(ceil(float(dur) / 60.0))
	_push_speech_to_state_lord(
		ld, "lord_injured", "Lord Yaralandı!",
		"Savaşta ağır darbe aldım. Ekipmanlarım güvende ancak %d dakika iyileşmem gerekiyor." % mins,
		"lord_screen", "", now_unix
	)
	ld["updated_unix"] = now_unix
	p["lord"] = ld
	return until


static func _attacker_payload(state: Dictionary, origin: Dictionary, units: Dictionary, movement: Dictionary = {}, now_unix: int = 0) -> Dictionary:
	var owner := str(origin.get("owner", ""))
	var atk_lord: Dictionary = {"present": false}
	if bool(movement.get("include_lord", false)):
		var snap = movement.get("lord_snapshot", {})
		if typeof(snap) == TYPE_DICTIONARY and not (snap as Dictionary).is_empty():
			atk_lord = (snap as Dictionary).duplicate(true)
			atk_lord["present"] = true
		elif _is_state_player_village(state, origin):
			atk_lord = _player_lord_combat_payload(state, now_unix)
	return {
		"name": owner if not owner.is_empty() else "Saldıran",
		"village_name": str(origin.get("name", "")),
		"units": units.duplicate(true),
		"buildings": (origin.get("buildings", {}) as Dictionary).duplicate(true) if typeof(origin.get("buildings")) == TYPE_DICTIONARY else {},
		"points": Protection.player_points(state, owner),
		"realm_of_power": int(origin.get("realm_of_power", 0)),
		"has_statue": bool(origin.get("has_statue", false)),
		"barracks_level": _building_level(origin, "barracks"),
		"lord": atk_lord,
	}


static func _defender_payload(state: Dictionary, target: Dictionary, movement: Dictionary, is_bandit: bool = false, bandit_lvl: int = 0, now_unix: int = 0) -> Dictionary:
	var buildings = target.get("buildings", {})
	var def_points := int(movement.get("target_points", 0))
	if def_points <= 0:
		def_points = int(target.get("points", 0))
	var def_owner := str(target.get("owner", ""))
	var raw_rop := int(target.get("realm_of_power", -1))
	if not target.has("realm_of_power") or raw_rop < 0:
		raw_rop = mini(maxi(0, def_points), 10000)
	var def_lord: Dictionary = {"present": false}
	if is_bandit:
		def_lord = (LordModelScript.bandit_template(bandit_lvl).get("lord", {"present": true}) as Dictionary).duplicate(true)
		def_lord["present"] = true
	elif _is_state_player_village(state, target):
		def_lord = _player_lord_combat_payload(state, now_unix)
	return {
		"name": def_owner if not def_owner.is_empty() else "Savunan",
		"village_name": str(target.get("name", "")),
		"units": _normalize_units(target.get("units", {})),
		"buildings": (buildings as Dictionary).duplicate(true) if typeof(buildings) == TYPE_DICTIONARY else {},
		"wall_level": _building_level(target, "wall"),
		"has_statue": bool(target.get("has_statue", false)),
		"points": def_points,
		"realm_of_power": raw_rop,
		"resources": _normalize_resources(target.get("resources", {})),
		"lord": def_lord,
	}


## `BattleSimulator` sonucundan casus fazı verisi.
static func _spy_phase_data(result: Dictionary) -> Dictionary:
	for phase in result.get("phases", []):
		if typeof(phase) == TYPE_DICTIONARY and str((phase as Dictionary).get("key", "")) == "spy_attack":
			var data = (phase as Dictionary).get("data", {})
			return data if typeof(data) == TYPE_DICTIONARY else {}
	return {}


static func _battle_report_data(
	result: Dictionary, attacker: Dictionary, defender: Dictionary, movement: Dictionary, is_raid: bool,
	actual_conquered: bool = false, conquest_blocked: bool = false, target: Dictionary = {}
) -> Dictionary:
	var raw_copy: Dictionary = result.duplicate(true)
	raw_copy["conquered"] = actual_conquered
	raw_copy["conquest_blocked"] = conquest_blocked
	var realm_before := int(result.get("realm_of_power_before", int(defender.get("realm_of_power", 0))))
	var realm_cap := maxi(1, int(result.get("realm_cap", mini(maxi(1, int(defender.get("points", 0))), 10000))))
	var realm_half_cap := maxi(1, int(result.get("realm_half_cap", int(floor(float(realm_cap) / 2.0)))))
	var realm_drop_min := int(result.get("realm_drop_min", mini(1750, realm_half_cap)))
	var realm_drop_max := int(result.get("realm_drop_max", mini(2750, realm_half_cap)))
	var has_statue := bool(result.get("defender_has_statue", bool(defender.get("has_statue", false))))
	var realm_after := int(target.get("realm_of_power", result.get("realm_of_power_after", 0))) if not target.is_empty() else int(result.get("realm_of_power_after", 0))
	var realm_loss := 0 if conquest_blocked else int(result.get("realm_loss_applied", result.get("realm_loss", 0)))
	var realm_remaining := 0 if actual_conquered else maxi(0, realm_after)
	var realm_post_conquest := realm_after if actual_conquered else -1
	var est_min := 0
	var est_max := 0
	if not actual_conquered and realm_remaining > 0:
		est_min = maxi(1, int(ceil(float(realm_remaining) / float(maxi(1, realm_drop_max)))))
		est_max = maxi(1, int(ceil(float(realm_remaining) / float(maxi(1, realm_drop_min)))))
	if conquest_blocked:
		raw_copy["realm_loss"] = 0
		raw_copy["realm_loss_applied"] = 0
		raw_copy["realm_of_power_after"] = realm_after
		raw_copy["est_attacks_min"] = est_min
		raw_copy["est_attacks_max"] = est_max
		raw_copy["realm_before"] = realm_before

	var built: Dictionary = BR.build(raw_copy, attacker, defender)
	var data: Dictionary = built.duplicate(true)
	data["type"] = "battle"
	data["target_village_id"] = int(movement.get("to_village_id", 0))
	data["from_village_id"] = int(movement.get("from_village_id", 0))
	data["target_name"] = str(defender.get("village_name", ""))
	data["from_name"] = str(attacker.get("village_name", ""))
	data["attacker_name"] = str(attacker.get("name", "Saldıran"))
	data["defender_name"] = str(defender.get("name", "Savunan"))
	data["attacker_village_name"] = str(attacker.get("village_name", ""))
	data["defender_village_name"] = str(defender.get("village_name", ""))
	data["is_raid"] = is_raid
	data["attacker_units"] = (attacker.get("units", {}) as Dictionary).duplicate(true)
	data["defender_units"] = (defender.get("units", {}) as Dictionary).duplicate(true)
	data["attacker_losses"] = (result.get("attacker_losses", {}) as Dictionary).duplicate(true)
	data["defender_losses"] = (result.get("defender_losses", {}) as Dictionary).duplicate(true)
	data["attacker_alive"] = (result.get("attacker_alive", {}) as Dictionary).duplicate(true)
	data["defender_alive"] = (result.get("defender_alive", {}) as Dictionary).duplicate(true)
	data["loot"] = _normalize_resources(result.get("loot", {}))
	data["carry_capacity"] = int(result.get("carry_capacity", 0))
	data["conquered"] = actual_conquered
	data["conquest_blocked"] = conquest_blocked
	data["conquest_blocked_reason"] = "conquest_protection" if conquest_blocked else ""
	data["count_had"] = int(result.get("count_had", int((attacker.get("units", {}) as Dictionary).get("snob", 0))))
	data["count_survived"] = bool(result.get("count_survived", false))
	data["count_died"] = bool(result.get("count_died", false))
	data["wall_damage_pct"] = float(result.get("wall_damage_pct", 0.0))
	data["wall_level_before"] = int(result.get("wall_level_before", 0))
	data["wall_level_after"] = int(result.get("wall_level_after", 0))
	data["realm_before"] = maxi(0, realm_before)
	data["realm_after"] = maxi(0, realm_after)
	data["realm_remaining"] = realm_remaining
	data["realm_post_conquest"] = realm_post_conquest
	data["realm_loss"] = maxi(0, realm_loss)
	data["realm_cap"] = realm_cap
	data["realm_half_cap"] = realm_half_cap
	data["realm_drop_min"] = realm_drop_min
	data["realm_drop_max"] = realm_drop_max
	data["defender_has_statue"] = has_statue
	data["est_attacks_min"] = est_min
	data["est_attacks_max"] = est_max
	data["realm_hourly_regen"] = int(floor(float(realm_cap) * 0.01 + 0.5))
	data["raw"] = raw_copy
	return data


## Casusluk raporu — hedefin **kaynakları + birlikleri** (açığa çıkarma yok).
## Gizli Depo **casuslara karşı da** korur (kaynak: `buildings.txt`); korunan miktar
## **üç hammaddenin toplamından** düşülür (`production.json` → `hideout_capacity.unit
## = "resource_total"`), yağma ile **birebir aynı** semantik (bkz. `_visible_resources`).
## Bilgi kademesi: **normal** raporda **dışarıdaki birlikler** vardır, **gizli**de yoktur
## (kaynak: `units_espionage.txt`).
static func _spy_report_data(
	state: Dictionary, target: Dictionary, defender: Dictionary,
	spy_data: Dictionary, movement: Dictionary, creeping: bool
) -> Dictionary:
	var actual := _normalize_resources(target.get("resources", {}))
	var units := _normalize_units(target.get("units", {}))
	var hideout := _hideout_capacity(defender, target)
	var visible := _visible_resources(actual, hideout)
	var actual_total := _sum(actual)
	var visible_total := _sum(visible)
	var data := {
		"type": "spy",
		"from_village_id": int(movement.get("from_village_id", movement.get("village_id", 0))),
		"attacker_owner": str(movement.get("owner", "")),
		"target_village_id": int(target.get("id", 0)),
		"target_name": str(target.get("name", "")),
		"target_owner": str(target.get("owner", "")),
		"resources": visible,
		"actual_resources_total": actual_total,
		"hidden_amount": actual_total - visible_total,
		"hideout_capacity": hideout,
		"visible_resources_total": visible_total,
		"units": units,
		"spy_survivors": int(spy_data.get("spy_survivors", 0)),
		"spy_losses": int(spy_data.get("spy_losses", 0)),
		"defence_spies": int(spy_data.get("defence_spies", 0)),
		"creeping": creeping,
	}

	var survivors_cnt: int = int(spy_data.get("spy_survivors", 0))
	var losses_cnt: int = int(spy_data.get("spy_losses", 0))
	var total_spies: int = maxi(1, survivors_cnt + losses_cnt)
	var surv_ratio: float = float(survivors_cnt) / float(total_spies)

	# KingsAge: %50+ casus sağ kalırsa bina seviyeleri keşfedilir
	if surv_ratio >= 0.5:
		data["buildings"] = (target.get("buildings", {}) as Dictionary).duplicate(true) if typeof(target.get("buildings")) == TYPE_DICTIONARY else {}

	# KingsAge: %70+ casus sağ kalırsa ve normal casusluk ise dışarıdaki birlikler keşfedilir
	if surv_ratio >= 0.7 and not creeping:
		data["outside_units"] = _collect_outside_units(state, int(target.get("id", 0)))
	return data


## Gizli Depo'nun casusluk raporunda **görünen** kaynakları: korunan miktar üç
## hammaddenin **toplamından** düşülür, kalan **en büyük kalan yöntemiyle** oransal
## dağıtılır. `toplam ≤ kapasite` ise üç kaynak da 0 görünür.
##
## NOT (kod tekrarı): Algoritma `BattleSimulator._compute_loot` ile **aynı çıktıyı**
## verecek şekilde burada yeniden yazılmıştır (bkz. ASSUMPTIONS.md §3) — gizli
## modül API'sine bağımlı olmamak için kasıtlı; test bunu yağma çıktısıyla doğrular.
static func _visible_resources(resources: Dictionary, capacity: int) -> Dictionary:
	var out := {"wood": 0, "stone": 0, "iron": 0}
	var total := int(resources.get("wood", 0)) + int(resources.get("stone", 0)) + int(resources.get("iron", 0))
	if total <= 0:
		return out
	var take := total - clampi(capacity, 0, total)
	if take <= 0:
		return out
	var types := ["wood", "stone", "iron"]
	var remainders := {}
	var allocated := 0
	for t in types:
		var raw := float(take) * float(int(resources.get(t, 0))) / float(total)
		var base := int(floor(raw))
		base = mini(base, int(resources.get(t, 0)))
		out[t] = base
		remainders[t] = raw - float(base)
		allocated += base
	while allocated < take:
		var best := ""
		var best_rem := -1.0
		for t in types:
			var rem := float(remainders.get(t, 0.0))
			if rem > best_rem and int(out[t]) < int(resources.get(t, 0)):
				best_rem = rem
				best = t
		if best == "":
			break
		out[best] = int(out[best]) + 1
		remainders[best] = -1.0
		allocated += 1
	return out


## Normal casuslukta **savunanın** aldığı rapor (saldırı görünür — `units_espionage.txt`).
static func _spy_incoming_data(
	target: Dictionary, origin: Dictionary, spy_data: Dictionary, movement: Dictionary
) -> Dictionary:
	var surv := int(spy_data.get("spy_survivors", 0))
	return {
		"type": "spy_incoming",
		"village_id": int(target.get("id", 0)),
		"from_village_id": int(origin.get("id", 0)),
		"from_name": str(origin.get("name", "")),
		"attacker_village_id": int(origin.get("id", 0)),
		"attacker_village_name": str(origin.get("name", "")),
		"attacker_owner": str(origin.get("owner", "")),
		"target_village_id": int(target.get("id", 0)),
		"target_name": str(target.get("name", "")),
		"defender_name": str(target.get("owner", "")),
		"spy_survivors": surv,
		"spy_losses": int(spy_data.get("spy_losses", 0)),
		"defence_spies": int(spy_data.get("defence_spies", 0)),
		"creeping": bool(movement.get("creeping", false)),
		"all_killed": (surv <= 0),
	}


## Gizli Depo kapasitesi (casusluk raporu). Öncelik: köyün `hide` seviyesi
## (`RulesEngine.hideout_capacity`), yoksa `BattleSimulator` (aynı tablo).
static func _hideout_capacity(defender: Dictionary, target: Dictionary) -> int:
	var level := _building_level(target, "hide")
	if level > 0:
		return maxi(0, RE.hideout_capacity(level))
	return maxi(0, BS.hideout_capacity_for(defender))


## Hedef köyün **dışarıdaki birlikleri**: yolda olan (giden) orduları + başka
## köylere gönderdiği destek birlikleri. (Normal casusluk raporu.)
static func _collect_outside_units(state: Dictionary, village_id: int) -> Dictionary:
	var out: Dictionary = {}
	if village_id <= 0:
		return out
	var movements = state.get("movements", null)
	if typeof(movements) == TYPE_ARRAY:
		for entry in (movements as Array):
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var m: Dictionary = entry
			var origin_id := int(m.get("village_id", m.get("from_village_id", 0)))
			if origin_id != village_id:
				continue
			var type := str(m.get("type", ""))
			if type == "return" or type == "trade":
				continue
			_merge_units(out, m.get("units", {}))
	var villages = state.get("villages", null)
	if typeof(villages) == TYPE_ARRAY:
		for village in (villages as Array):
			if typeof(village) != TYPE_DICTIONARY:
				continue
			var support = (village as Dictionary).get("support", null)
			if typeof(support) != TYPE_ARRAY:
				continue
			for item in (support as Array):
				if typeof(item) != TYPE_DICTIONARY:
					continue
				if int((item as Dictionary).get("from_village_id", 0)) == village_id:
					_merge_units(out, (item as Dictionary).get("units", {}))
	return out


static func _merge_units(target: Dictionary, raw) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		return
	for key in (raw as Dictionary).keys():
		var count := int((raw as Dictionary)[key])
		if count > 0:
			target[str(key)] = int(target.get(str(key), 0)) + count


static func _add_report(state: Dictionary, type: String, village_id: int, now_unix: int, data: Dictionary) -> void:
	if typeof(state.get("reports")) != TYPE_ARRAY:
		state["reports"] = []
	(state["reports"] as Array).append({
		"id": _next_report_id(state),
		"type": type,
		"unix": now_unix,
		"village_id": village_id,
		"unread": true,
		"data": data,
	})


static func _next_report_id(state: Dictionary) -> int:
	var max_id := 0
	var reports = state.get("reports", null)
	if typeof(reports) == TYPE_ARRAY:
		for entry in (reports as Array):
			if typeof(entry) == TYPE_DICTIONARY:
				max_id = maxi(max_id, int((entry as Dictionary).get("id", 0)))
	return max_id + 1


static func _next_movement_id(state: Dictionary) -> int:
	var max_id := 0
	var movements = state.get("movements", null)
	if typeof(movements) == TYPE_ARRAY:
		for entry in (movements as Array):
			if typeof(entry) == TYPE_DICTIONARY:
				max_id = maxi(max_id, int((entry as Dictionary).get("id", 0)))
	return max_id + 1


static func _refresh_points(village: Dictionary) -> void:
	var buildings = village.get("buildings", {})
	if typeof(buildings) != TYPE_DICTIONARY:
		return
	var points := RE.village_points(buildings)
	if points > 0:
		village["points"] = points


static func _find_village(state: Dictionary, village_id: int) -> Dictionary:
	var villages = state.get("villages", null)
	if typeof(villages) != TYPE_ARRAY:
		return {}
	for village in (villages as Array):
		if typeof(village) == TYPE_DICTIONARY and int((village as Dictionary).get("id", -1)) == village_id:
			return village
	return {}


static func _building_level(village: Dictionary, key: String) -> int:
	var b = village.get("buildings", null)
	if typeof(b) != TYPE_DICTIONARY:
		return 0
	return int((b as Dictionary).get(key, 0))


static func _subtract_units(village: Dictionary, losses) -> void:
	if typeof(village.get("units")) != TYPE_DICTIONARY:
		return
	var units: Dictionary = village["units"]
	if typeof(losses) != TYPE_DICTIONARY:
		return
	for key in (losses as Dictionary).keys():
		units[str(key)] = maxi(0, int(units.get(str(key), 0)) - int((losses as Dictionary)[key]))


static func _subtract_support_losses(target: Dictionary, units_before: Dictionary, losses) -> void:
	var support_list = target.get("support", null)
	if typeof(support_list) != TYPE_ARRAY or (support_list as Array).is_empty():
		return
	if typeof(losses) != TYPE_DICTIONARY:
		return
	var remaining_units: Dictionary = target.get("units", {})
	var arr: Array = support_list
	for i in range(arr.size() - 1, -1, -1):
		var item = arr[i]
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = item
		var s_units = entry.get("units", null)
		if typeof(s_units) != TYPE_DICTIONARY:
			continue
		var u_dict: Dictionary = s_units
		var total_left := 0
		for uk in u_dict.keys():
			var key := str(uk)
			var sup_have := maxi(0, int(u_dict.get(key, 0)))
			var tot_before := maxi(0, int(units_before.get(key, 0)))
			var lost_total := maxi(0, int((losses as Dictionary).get(key, 0)))
			if sup_have > 0 and tot_before > 0 and lost_total > 0:
				var sup_lost := int(round(float(sup_have) * float(lost_total) / float(tot_before)))
				sup_have = maxi(0, sup_have - mini(sup_have, sup_lost))
			var cap_left := maxi(0, int(remaining_units.get(key, 0)))
			sup_have = mini(sup_have, cap_left)
			u_dict[key] = sup_have
			total_left += sup_have
		if total_left <= 0:
			arr.remove_at(i)


static func _add_units(village: Dictionary, units: Dictionary) -> void:
	if typeof(village.get("units")) != TYPE_DICTIONARY:
		village["units"] = {}
	var have: Dictionary = village["units"]
	for key in units.keys():
		have[str(key)] = int(have.get(str(key), 0)) + int(units[key])


static func _subtract_resources(village: Dictionary, resources: Dictionary) -> void:
	if typeof(village.get("resources")) != TYPE_DICTIONARY:
		return
	var have: Dictionary = village["resources"]
	for r in RESOURCES:
		have[r] = maxi(0, int(have.get(r, 0)) - int(resources.get(r, 0)))


static func _add_resources(village: Dictionary, resources: Dictionary) -> void:
	if typeof(village.get("resources")) != TYPE_DICTIONARY:
		village["resources"] = {"wood": 0, "stone": 0, "iron": 0}
	var have: Dictionary = village["resources"]
	for r in RESOURCES:
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
		out[r] = maxi(0, int((raw as Dictionary).get(r, 0)))
	return out


static func _zero_carry() -> Dictionary:
	return {"wood": 0, "stone": 0, "iron": 0}


static func _sum(d: Dictionary) -> int:
	var total := 0
	for key in d.keys():
		total += int(d[key])
	return total


static func _speed() -> float:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var cfg = (loop as SceneTree).root.get_node_or_null("GameConfig")
		if cfg != null:
			var value = cfg.get("speed")
			if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
				var s := float(value)
				return s if s > 0.0 else 1.0
	return 1.0


## Gece bonusu penceresinde miyiz? (Sunucu ayarına göre.) UTC saati kullanılır (bkz. ASSUMPTIONS.md #6).
static func _is_night(now_unix: int) -> bool:
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return false
	var cfg = (loop as SceneTree).root.get_node_or_null("GameConfig")
	if cfg == null or not cfg.has_method("is_night_bonus_time"):
		return false
	var dt := Time.get_datetime_dict_from_unix_time(now_unix)
	return bool(cfg.is_night_bonus_time(int(dt.get("hour", 0))))
