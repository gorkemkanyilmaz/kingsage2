class_name BotArmy
extends RefCounted
## BotArmy — Bot ordu araştırma ve eğitim kararları (Taht ve Kılıç / A-BOT).
##
## Zorunlu kural:
##  Botlar kuralları ASLA atlatamaz. Araştırma ve eğitim yalnız `ArmyAPI` üzerinden yapılır;
##  Kışla seviye şartı, vatandaş rezervi ve hammadde maliyetleri birebir uygulanır.

const RE := preload("res://scripts/rules/RulesEngine.gd")
const VM := preload("res://scripts/model/VillageModel.gd")
const ArmyAPI := preload("res://scripts/sim/army/ArmyAPI.gd")
const BotProfileScript := preload("res://scripts/bot/BotProfile.gd")

const RESEARCH_CANDIDATES := ["spear", "sword", "axe", "bow", "spy", "light", "heavy", "ram", "kata"]
const TRAINING_PREFERENCE := {
	BotProfileScript.PERSONALITY_BUILDER: ["spear", "sword"],
	BotProfileScript.PERSONALITY_TRADER: ["spear", "sword", "spy"],
	BotProfileScript.PERSONALITY_WARLORD: ["axe", "light", "spear", "sword", "bow", "ram"],
}


## Bot için araştırma veya eğitim kararı verir
## Dönüş: {"action_taken": bool, "type": String, "unit_key": String, "count": int}
static func think_army(village: Dictionary, profile: Dictionary, state: Dictionary, now_unix: int) -> Dictionary:
	var buildings: Dictionary = village.get("buildings", {})
	var barracks_lvl: int = int(buildings.get("barracks", 0))
	if barracks_lvl <= 0:
		return {"action_taken": false, "reason": "no_barracks"}

	# 1. Araştırma: Sırayla araştırılabilir olan birimi kontrol et
	for u_key in RESEARCH_CANDIDATES:
		if ArmyAPI.can_research(village, u_key, state):
			var res: Dictionary = ArmyAPI.start_research(village, u_key, state, now_unix)
			if bool(res.get("ok", false)):
				return {"action_taken": true, "type": "research", "unit_key": u_key, "count": 1}

	# 2. Eğitim: Hedef asker sayısına ulaşıldı mı?
	var personality: String = str(profile.get("personality", BotProfileScript.PERSONALITY_BUILDER))
	var target_army: int = int(profile.get("army_target", 30))
	var current_units: Dictionary = village.get("units", {})
	var total_units: int = 0
	for count in current_units.values():
		total_units += int(count)

	if total_units >= target_army:
		return {"action_taken": false, "reason": "army_target_reached"}

	var free_pop: int = VM.population_free(village)
	if free_pop <= 5:
		return {"action_taken": false, "reason": "low_population"}

	# Tercih sırasına göre uygun birimi eğit
	var prefs: Array = TRAINING_PREFERENCE.get(personality, ["spear", "sword"])
	for u_key in prefs:
		# Araştırılmış mı kontrol et
		var req_barracks: int = RE.research_requirement(u_key)
		if req_barracks > 0:
			var researched: Dictionary = village.get("researched", {})
			if not bool(researched.get(u_key, false)):
				continue

		# Uygun parti boyutu belirle (5, 3 veya 1)
		var batch_sizes: Array = [5, 3, 1]
		if personality == BotProfileScript.PERSONALITY_WARLORD:
			batch_sizes = [15, 10, 5, 2, 1]

		for batch in batch_sizes:
			if batch > free_pop:
				continue
			if ArmyAPI.can_train(village, u_key, batch, state):
				var res_train: Dictionary = ArmyAPI.start_training(village, u_key, batch, state, now_unix)
				if bool(res_train.get("ok", false)):
					return {"action_taken": true, "type": "train", "unit_key": u_key, "count": batch}

	return {"action_taken": false, "reason": "cannot_train_affordable"}
