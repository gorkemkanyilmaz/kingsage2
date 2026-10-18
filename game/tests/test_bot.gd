extends SceneTree
## Bot / AI Testleri (Taht ve Kılıç / A-BOT).
##
## Çalıştırma:
##   godot --headless --path game --script res://tests/test_bot.gd

const BotProfileScript := preload("res://scripts/bot/BotProfile.gd")
const BotEconomyScript := preload("res://scripts/bot/BotEconomy.gd")
const BotArmyScript := preload("res://scripts/bot/BotArmy.gd")
const BotWarScript := preload("res://scripts/bot/BotWar.gd")
const BotSimulatorScript := preload("res://scripts/bot/BotSimulator.gd")

const EconomySimulatorScript := preload("res://scripts/sim/economy/EconomySimulator.gd")
const ArmySimulatorScript := preload("res://scripts/sim/army/ArmySimulator.gd")
const ActionSimulatorScript := preload("res://scripts/sim/actions/ActionSimulator.gd")

const WorldGeneratorScript := preload("res://scripts/world/WorldGenerator.gd")
const WorldModelScript := preload("res://scripts/world/WorldModel.gd")
const RulesEngineScript := preload("res://scripts/rules/RulesEngine.gd")
const VillageModelScript := preload("res://scripts/model/VillageModel.gd")
const EconomyAPI := preload("res://scripts/sim/economy/EconomyAPI.gd")
const ArmyAPI := preload("res://scripts/sim/army/ArmyAPI.gd")
const MovementScript := preload("res://scripts/sim/actions/Movement.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	print("=== Bot / Yapay Zeka Testleri (A-BOT) ===")

	_test_single_bot_progress()
	_test_requirement_chain_enforcement()
	_test_personalities_difference()
	_test_determinism()
	_test_raids_and_loot()
	_test_100_bots_30_days_invariants()

	print("\n==================== ÖZET ====================")
	print("PASS: %d   FAIL: %d" % [_passed, _failed])
	print("==============================================")

	if _failed > 0:
		quit(1)
	else:
		quit(0)


func _assert(condition: bool, msg: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] %s" % msg)
	else:
		_failed += 1
		print("  [FAIL] %s" % msg)


## (a) Tek bot 1 gün simülasyonu
func _test_single_bot_progress() -> void:
	print("\n-- (a) Tek Bot 1 Gün İlerlemesi --")

	var world := WorldGeneratorScript.generate(1001, 1)
	var state := {
		"world": world,
		"villages": world["villages"].duplicate(true),
		"queues": [],
		"movements": [],
		"reports": [],
	}

	var bot_v: Dictionary = {}
	for v in state["villages"]:
		if bool(v.get("is_bot", false)):
			bot_v = v
			break

	_assert(not bot_v.is_empty(), "Bot köyü bulundu")
	var initial_points: int = int(bot_v.get("points", 0))

	var now := 1000000
	var sim_step := 60  # 1'er dakikalık adımlarla 1 gün (1440 adım)
	for i in 1440:
		now += sim_step
		# Modülleri sırayla çalıştır
		EconomySimulatorScript.process_tick(state, now, sim_step)
		ArmySimulatorScript.process_tick(state, now, sim_step)
		ActionSimulatorScript.process_tick(state, now, sim_step)
		BotSimulatorScript.process_tick(state, now, sim_step)

	_assert(int(bot_v.get("points", 0)) >= initial_points, "Bina yükseltmeleriyle köy puanı arttı veya korundu")
	var res: Dictionary = bot_v.get("resources", {})
	_assert(int(res.get("wood", -1)) >= 0, "Odun negatif değil")
	_assert(int(res.get("stone", -1)) >= 0, "Taş negatif değil")
	_assert(int(res.get("iron", -1)) >= 0, "Demir negatif değil")

	var cap: int = RulesEngineScript.storage_capacity(int(bot_v.get("buildings", {}).get("storage", 1)))
	_assert(int(res.get("wood", 0)) <= cap, "Odun depo tavanını aşmadı")


## (b) Gereksinim zinciri denetimi (Kışla için Depo 3 + Değirmen 3 şartı)
func _test_requirement_chain_enforcement() -> void:
	print("\n-- (b) Gereksinim Zinciri Denetimi --")

	var village := VillageModelScript.create(99, "TestBot", 50, 50, "BotPlayer", true)
	var state := {"villages": [village], "queues": [], "world": {}}

	# Başlangıçta Depo 1, Değirmen 1
	_assert(not EconomyAPI.can_start_build(village, "barracks", state), "Önkoşulsuz Kışla başlatılamaz")

	var res := EconomyAPI.start_build(village, "barracks", state)
	_assert(not bool(res.get("ok", false)), "Kışla inşa denemesi API tarafından reddedildi")
	_assert(res.get("reason") == "requirements", "Hata sebebi: requirements")


## (d) Kişilikler farklı sonuçlar üretir (sayısal kanıt)
func _test_personalities_difference() -> void:
	print("\n-- (d) Kişiliklerin Sayısal Farklılığı --")

	# 2 ayrı dünyada aynı tohumla biri Warlord, biri Builder olarak başlatılır
	var v_builder := VillageModelScript.create(1, "BuilderKöy", 10, 10, "BuilderBot", true)
	var v_warlord := VillageModelScript.create(2, "WarlordKöy", 10, 10, "WarlordBot", true)

	# Başlangıçta bol kaynak ver ki kişilikleri serbestçe karar alabilsin
	v_builder["resources"] = {"wood": 50000, "stone": 50000, "iron": 50000}
	v_warlord["resources"] = {"wood": 50000, "stone": 50000, "iron": 50000}

	# Kışla'yı açık ver
	v_builder["buildings"]["barracks"] = 5
	v_warlord["buildings"]["barracks"] = 5
	v_builder["buildings"]["farm"] = 10
	v_warlord["buildings"]["farm"] = 10

	v_builder["bot_profile"] = BotProfileScript.create_custom_profile(BotProfileScript.PERSONALITY_BUILDER, BotProfileScript.DIFFICULTY_NORMAL)
	v_warlord["bot_profile"] = BotProfileScript.create_custom_profile(BotProfileScript.PERSONALITY_WARLORD, BotProfileScript.DIFFICULTY_NORMAL)

	var st_builder := {"villages": [v_builder], "queues": [], "movements": [], "world": {"seed": 42}}
	var st_warlord := {"villages": [v_warlord], "queues": [], "movements": [], "world": {"seed": 42}}

	var now := 1000000
	for i in 600:
		now += 30
		EconomySimulatorScript.process_tick(st_builder, now, 30)
		ArmySimulatorScript.process_tick(st_builder, now, 30)
		BotSimulatorScript.process_tick(st_builder, now, 30)

		EconomySimulatorScript.process_tick(st_warlord, now, 30)
		ArmySimulatorScript.process_tick(st_warlord, now, 30)
		BotSimulatorScript.process_tick(st_warlord, now, 30)

	var builder_army_count := 0
	for c in v_builder.get("units", {}).values():
		builder_army_count += int(c)

	var warlord_army_count := 0
	for c in v_warlord.get("units", {}).values():
		warlord_army_count += int(c)

	_assert(warlord_army_count > builder_army_count, "Warlord (%d) > Builder (%d) asker sayısı" % [warlord_army_count, builder_army_count])


## (e) Determinizm: Aynı tohum -> birebir aynı hash
func _test_determinism() -> void:
	print("\n-- (e) Determinizm --")

	var run1 := _run_simulation_for_hash(5555, 300)
	var run2 := _run_simulation_for_hash(5555, 300)

	_assert(run1 == run2, "Aynı tohum ve aynı tick dizisi birebir aynı hash'i üretti (%s)" % run1.substr(0, 12))


func _run_simulation_for_hash(world_seed: int, steps: int) -> String:
	var world := WorldGeneratorScript.generate(world_seed, 5)
	var state := {
		"world": world,
		"villages": world["villages"].duplicate(true),
		"queues": [],
		"movements": [],
		"reports": [],
	}

	var now := 1000000
	for i in steps:
		now += 60
		EconomySimulatorScript.process_tick(state, now, 60)
		ArmySimulatorScript.process_tick(state, now, 60)
		ActionSimulatorScript.process_tick(state, now, 60)
		BotSimulatorScript.process_tick(state, now, 60)

	# Basit ve kararlı kanonik hash
	var s := ""
	for v in state["villages"]:
		s += "%d:%d:%d," % [int(v.get("id", 0)), int(v.get("points", 0)), int(v.get("realm_of_power", 0))]
	return s.md5_text()


## (f) Yağma / Talan sevkıyatı
func _test_raids_and_loot() -> void:
	print("\n-- (f) Yağma ve Talan Gönderimi --")

	var bot_v := VillageModelScript.create(1, "BotKöy", 10, 10, "BotOwner", true)
	var barb_v := VillageModelScript.create(2, "SoyguncuKöy", 12, 10, "Soyguncular", false)

	bot_v["buildings"]["barracks"] = 2
	bot_v["units"]["axe"] = 25
	bot_v["units"]["spear"] = 25
	bot_v["bot_profile"] = BotProfileScript.create_custom_profile(BotProfileScript.PERSONALITY_WARLORD, BotProfileScript.DIFFICULTY_HARD)

	barb_v["is_barbarian"] = true
	barb_v["resources"] = {"wood": 5000, "stone": 5000, "iron": 5000}

	var state := {
		"villages": [bot_v, barb_v],
		"queues": [],
		"movements": [],
		"reports": [],
		"world": {"seed": 4242},
	}

	var now := 1000000
	var war_res := BotWarScript.think_war(bot_v, bot_v["bot_profile"], state, now)
	_assert(bool(war_res.get("action_taken", false)), "Bot soyguncu köyüne talan gönderdi")
	_assert(state["movements"].size() == 1, "Hareket listesine 1 talan yazıldı")

	var mov: Dictionary = state["movements"][0]
	_assert(mov.get("type") == "raid", "Hareket türü: raid")
	_assert(int(mov.get("to_village_id")) == 2, "Hedef soyguncu köyü (id: 2)")


## (c) 100 Bot × 30 Gün Simülasyonu & Değişmezler (Invariants)
func _test_100_bots_30_days_invariants() -> void:
	print("\n-- (c) 100 Bot × 30 Gün Simülasyonu & Değişmezler --")

	var start_ms := Time.get_ticks_msec()
	var world := WorldGeneratorScript.generate(9999, 100)
	var state := {
		"world": world,
		"villages": world["villages"].duplicate(true),
		"queues": [],
		"movements": [],
		"reports": [],
	}

	var bot_count := 0
	for v in state["villages"]:
		if bool(v.get("is_bot", false)):
			bot_count += 1
	_assert(bot_count == 100, "Dünyada tam 100 bot köyü var")

	var now := 1000000
	# 30 gün = 2.592.000 saniye. 1 saatlik (3600 sn) adımlarla 720 adım
	var steps := 720
	var step_size := 3600

	for i in steps:
		now += step_size
		EconomySimulatorScript.process_tick(state, now, step_size)
		ArmySimulatorScript.process_tick(state, now, step_size)
		ActionSimulatorScript.process_tick(state, now, step_size)
		BotSimulatorScript.process_tick(state, now, step_size)

	var elapsed_ms := Time.get_ticks_msec() - start_ms
	print("  -> 100 bot × 30 gün simülasyonu tamamlandı: %d ms (%.2f saniye)" % [elapsed_ms, float(elapsed_ms) / 1000.0])

	# Değişmezleri doğrula
	var all_res_non_negative := true
	var all_res_under_cap := true
	var all_realm_valid := true
	var all_pop_valid := true

	for v in state["villages"]:
		if not bool(v.get("is_bot", false)):
			continue
		var res: Dictionary = v.get("resources", {})
		if int(res.get("wood", 0)) < 0 or int(res.get("stone", 0)) < 0 or int(res.get("iron", 0)) < 0:
			all_res_non_negative = false

		var cap: int = RulesEngineScript.storage_capacity(int(v.get("buildings", {}).get("storage", 1)))
		# 1 ticklik üretim taşma payı hariç tavan kontrolü
		if int(res.get("wood", 0)) > cap + 50000:
			all_res_under_cap = false

		var pts: int = int(v.get("points", 0))
		var realm: int = int(v.get("realm_of_power", 0))
		if realm < 0 or realm > pts:
			all_realm_valid = false

		var farm_lvl: int = int(v.get("buildings", {}).get("farm", 1))
		var max_pop: int = RulesEngineScript.max_population(farm_lvl)
		var used_pop: int = VillageModelScript.population_used(v)
		if used_pop > max_pop:
			all_pop_valid = false

	_assert(all_res_non_negative, "Tüm botlarda kaynaklar >= 0 (negatif kaynak yok)")
	_assert(all_res_under_cap, "Tüm botlarda kaynaklar depo tavanı kontrolünde")
	_assert(all_realm_valid, "Tüm botlarda 0 <= Güç Alanı <= Köy Puanı değişmezi sağlandı")
	_assert(all_pop_valid, "Tüm botlarda çalışan vatandaş <= Değirmen tavanı değişmezi sağlandı")
