class_name BotWar
extends RefCounted
## BotWar — Bot savaş ve yağma/talan kararları (Taht ve Kılıç / A-BOT).
##
## Zorunlu kural:
##  Botlar kuralları ASLA atlatamaz.
##  - Hareket yalnız `Movement.send_raid()` üzerinden oluşturulur.
##  - Min. saldırı birimi (3 × Kışla) kuralına %100 uyulur.
##  - Yalnızca korumasız veya terkedilmiş (soyguncu) köyler yağmalanır.

const RE := preload("res://scripts/rules/RulesEngine.gd")
const MovementScript := preload("res://scripts/sim/actions/Movement.gd")
const ProtectionScript := preload("res://scripts/sim/actions/Protection.gd")
const TravelScript := preload("res://scripts/world/Travel.gd")
const BotProfileScript := preload("res://scripts/bot/BotProfile.gd")


static var peace_mode: bool = true


## Bot için yağma/talan kararı verir ve uygunsa başlatır.
## Dönüş: {"action_taken": bool, "target_id": int, "units": Dictionary}
static func think_war(village: Dictionary, profile: Dictionary, state: Dictionary, now_unix: int) -> Dictionary:
	if peace_mode:
		return {"action_taken": false, "reason": "bots_do_not_attack"}

	var buildings: Dictionary = village.get("buildings", {})
	var barracks_lvl: int = int(buildings.get("barracks", 0))
	var min_units: int = RE.min_attack_units(barracks_lvl)
	if min_units <= 0:
		min_units = 5  # Temel asgari eşik

	var current_units: Dictionary = village.get("units", {})
	var available_offensive := 0
	for u_key in ["axe", "light", "spear", "sword", "bow"]:
		available_offensive += int(current_units.get(u_key, 0))

	# Yeterli asker yoksa sefere çıkma
	if available_offensive < min_units:
		return {"action_taken": false, "reason": "not_enough_units"}

	# Hedef seçimi: Yakındaki terkedilmiş/soyguncu veya korumasız köyleri ara
	var target_village := _find_best_raid_target(village, state)
	if target_village.is_empty():
		return {"action_taken": false, "reason": "no_valid_target"}

	# Sefer ordusunu hazırla
	var personality: String = str(profile.get("personality", BotProfileScript.PERSONALITY_BUILDER))
	var raid_units: Dictionary = {}
	var total_selected := 0

	# Warlord daha fazla birlik gönderir, builder/trader temkinli tutar
	var send_ratio: float = 0.85 if personality == BotProfileScript.PERSONALITY_WARLORD else 0.50

	for u_key in ["axe", "light", "spear", "sword", "bow"]:
		var have: int = int(current_units.get(u_key, 0))
		if have > 0:
			var to_send: int = int(floor(have * send_ratio))
			if to_send > 0:
				raid_units[u_key] = to_send
				total_selected += to_send

	# Asgari saldırı birimi eşiğini tamamla
	if total_selected < min_units:
		for u_key in ["axe", "light", "spear", "sword", "bow"]:
			var have: int = int(current_units.get(u_key, 0))
			var already: int = int(raid_units.get(u_key, 0))
			var diff: int = have - already
			if diff > 0:
				var need: int = min_units - total_selected
				var take: int = mini(diff, need)
				raid_units[u_key] = already + take
				total_selected += take
				if total_selected >= min_units:
					break

	if total_selected < min_units:
		return {"action_taken": false, "reason": "cannot_satisfy_min_units"}

	# Hedefe talan gönder (can_send kontrolü ile doğrula)
	var from_id: int = int(village.get("id", -1))
	var to_id: int = int(target_village.get("id", -1))

	var check: Dictionary = MovementScript.can_send(state, from_id, to_id, MovementScript.TYPE_RAID, raid_units, {}, now_unix)
	if not bool(check.get("ok", false)):
		return {"action_taken": false, "reason": check.get("code", "validation_failed")}

	var res: Dictionary = MovementScript.send_raid(state, from_id, to_id, raid_units, now_unix)
	if bool(res.get("ok", false)):
		return {"action_taken": true, "target_id": to_id, "units": raid_units}

	return {"action_taken": false, "reason": res.get("code", "send_failed")}


static func _find_best_raid_target(origin: Dictionary, state: Dictionary) -> Dictionary:
	var villages: Array = state.get("villages", [])
	var from_id: int = int(origin.get("id", -1))
	var from_x: int = int(origin.get("x", 0))
	var from_y: int = int(origin.get("y", 0))

	var best_target: Dictionary = {}
	var best_dist: float = 999999.0

	for v in villages:
		if typeof(v) != TYPE_DICTIONARY:
			continue
		var target: Dictionary = v
		var to_id: int = int(target.get("id", -1))
		if to_id == from_id:
			continue

		# Yalnızca korumasız veya soyguncu/terkedilmiş köyler
		var is_barb: bool = bool(target.get("is_barbarian", false)) or str(target.get("owner", "")) == "Soyguncular" or not str(target.get("bonus_type", "")).is_empty()
		if not is_barb and not ProtectionScript.is_unprotected_kind(target):
			continue

		var dist: float = TravelScript.distance(from_x, from_y, int(target.get("x", 0)), int(target.get("y", 0)))
		# 40 alandan uzak hedeflere gitme (verimli talan menzili)
		if dist <= 40.0 and dist < best_dist:
			best_dist = dist
			best_target = target

	return best_target
