class_name BotEconomy
extends RefCounted
## BotEconomy — Bot ekonomi ve bina inşa kararları (Taht ve Kılıç / A-BOT).
##
## Zorunlu kural:
##  Botlar kuralları ASLA atlatamaz. İnşaat başlatma yalnız `EconomyAPI.start_build()`
##  üzerinden yapılır; gereksinim zinciri, hammadde ve vatandaş kontrolleri birebir geçerlidir.

const RE := preload("res://scripts/rules/RulesEngine.gd")
const VM := preload("res://scripts/model/VillageModel.gd")
const EconomyAPI := preload("res://scripts/sim/economy/EconomyAPI.gd")
const BotProfileScript := preload("res://scripts/bot/BotProfile.gd")

const CORE_RESOURCES := ["wood", "stone", "iron"]


## Bot için inşa kararı verir ve uygunsa başlatır.
## Dönüş: {"action_taken": bool, "building": String, "result": Dictionary}
static func think_build(village: Dictionary, profile: Dictionary, state: Dictionary) -> Dictionary:
	var queued: Array = EconomyAPI.queued_items(village, state)
	# Ek maliyet slotlarına girmemek için ücretsiz 3 slot ile sınırla (veya profiline göre)
	var max_queue: int = 3 if profile.get("difficulty") == BotProfileScript.DIFFICULTY_HARD else 2
	if queued.size() >= max_queue:
		return {"action_taken": false, "reason": "queue_full"}

	var buildings: Dictionary = village.get("buildings", {})
	var free_pop: int = VM.population_free(village)

	# 1. Vatandaş kritik eşikte mi? (Değirmen önceliği)
	if free_pop <= 15:
		if _try_build(village, "farm", state):
			return {"action_taken": true, "building": "farm"}

	# 2. Hammadde taşma riski var mı? (Depo önceliği)
	var storage_lvl: int = int(buildings.get("storage", 1))
	var storage_cap: int = RE.storage_capacity(storage_lvl)
	var res: Dictionary = village.get("resources", {})
	var max_res: int = maxi(int(res.get("wood", 0)), maxi(int(res.get("stone", 0)), int(res.get("iron", 0))))
	if max_res >= int(storage_cap * 0.85):
		if _try_build(village, "storage", state):
			return {"action_taken": true, "building": "storage"}

	# 3. Kişilik odaklı öncelik listesi
	var personality: String = str(profile.get("personality", BotProfileScript.PERSONALITY_BUILDER))
	var candidate_list: Array = BotProfileScript.PRIORITY_BUILDINGS.get(personality, [])

	for b_key in candidate_list:
		var target_lvl: int = int(buildings.get(b_key, 0)) + 1
		# Eksik önkoşulları kontrol et
		var missing: Array = RE.missing_requirements(buildings, b_key, target_lvl)
		if not missing.is_empty():
			# Önce en acil eksik önkoşulu inşa etmeye çalış
			for req in missing:
				var req_key: String = str(req.get("building", ""))
				if _try_build(village, req_key, state):
					return {"action_taken": true, "building": req_key}
			continue

		# Doğrudan adayı yükseltmeyi dene
		if _try_build(village, b_key, state):
			return {"action_taken": true, "building": b_key}

	# 4. Hiçbiri olmadıysa temel hammadde binalarından birini dene
	for res_b in CORE_RESOURCES:
		if _try_build(village, res_b, state):
			return {"action_taken": true, "building": res_b}

	return {"action_taken": false, "reason": "no_affordable_candidate"}


static func _try_build(village: Dictionary, key: String, state: Dictionary) -> bool:
	if not EconomyAPI.can_start_build(village, key, state):
		return false
	var res: Dictionary = EconomyAPI.start_build(village, key, state)
	return bool(res.get("ok", false))
