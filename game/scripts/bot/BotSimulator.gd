class_name BotSimulator
extends RefCounted
## BotSimulator — Bot yapay zeka simülasyon yöneticisi (§7b sim modülü).
##
## Taht ve Kılıç / A-BOT
##
## Bu modül, dünyadaki bot köylerini (`village.is_bot == true`) periyodik olarak yönetir.
## Botlar, oyuncuyla aynı kural motorunu ve API'lerini (`EconomyAPI`, `ArmyAPI`, `Movement`)
## kullanarak gerçekçi ve hilesiz bir şekilde gelişir.
##
## §7b Sim modül protokolü:
##   static func process_tick(state: Dictionary, now_unix: int, delta_seconds: float) -> Array

const BotProfileScript := preload("res://scripts/bot/BotProfile.gd")
const BotEconomyScript := preload("res://scripts/bot/BotEconomy.gd")
const BotArmyScript := preload("res://scripts/bot/BotArmy.gd")
const BotWarScript := preload("res://scripts/bot/BotWar.gd")


static func process_tick(state: Dictionary, now_unix: int, delta_seconds: float) -> Array:
	var villages: Array = state.get("villages", [])
	if villages.is_empty():
		return []

	var world: Dictionary = state.get("world", {})
	var world_seed: int = int(world.get("seed", 42))

	var events: Array = []

	for v in villages:
		if typeof(v) != TYPE_DICTIONARY:
			continue
		var village: Dictionary = v
		if not bool(village.get("is_bot", false)):
			continue

		var vid: int = int(village.get("id", 1))
		var profile: Dictionary = BotProfileScript.get_profile(village, world_seed)
		var think_interval: int = int(profile.get("think_interval", 120))

		var next_think: int = int(village.get("next_bot_think_unix", -1))
		if next_think < 0:
			# Başlangıçta tüm botların aynı saniyede yük bindirmesini önlemek için dağıt
			next_think = now_unix + (vid % 37)
			village["next_bot_think_unix"] = next_think

		if now_unix >= next_think:
			# 1. Ekonomi kararı (bina yükseltme)
			var econ_res := BotEconomyScript.think_build(village, profile, state)
			if bool(econ_res.get("action_taken", false)):
				events.append({
					"type": "bot_build_started",
					"village_id": vid,
					"building": econ_res.get("building", ""),
				})

			# 2. Askeri karar (araştırma / eğitim)
			var army_res := BotArmyScript.think_army(village, profile, state, now_unix)
			if bool(army_res.get("action_taken", false)):
				events.append({
					"type": "bot_army_action",
					"village_id": vid,
					"action": army_res.get("type", ""),
					"unit_key": army_res.get("unit_key", ""),
				})

			# 3. Savaş/Yağma kararı
			var war_res := BotWarScript.think_war(village, profile, state, now_unix)
			if bool(war_res.get("action_taken", false)):
				events.append({
					"type": "bot_raid_sent",
					"village_id": vid,
					"target_id": war_res.get("target_id", -1),
					"units": war_res.get("units", {}),
				})

			village["next_bot_think_unix"] = now_unix + think_interval

	return events
