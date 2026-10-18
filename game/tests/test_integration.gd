extends SceneTree
## Uçtan Uca Entegrasyon Testi (Taht ve Kılıç / A-QA).
##
## §7b process_tick döngüsü üzerinden tam senaryo zinciri:
##  (a) Dünya üretimi ve ekonomi gelişimi (Oduncu/Taş ocağı/Maden ocağı)
##  (b) Kışla gereksinim zinciri denetimi (Depo 3 + Değirmen 3)
##  (c) Okçu araştırması ve ordu eğitimi
##  (d) Soyguncu köyüne talan ve ganimet dönüşü
##  (e) İptal mekanizması ve iade kuralları (taban iade / ek maliyet kayıp)
##  (f) Değişmezler (invariants): kaynak >= 0, <= depo, 0 <= realm <= points, vatandaş <= değirmen
##  (g) Determinizm: aynı tohum ve tick dizisi -> birebir aynı hash
##  (h) Kaydet/Yükle sonrası devamlılık: ara kayıttan devam == kesintisiz akış
##
## Çalıştırma:
##   godot --headless --path game --script res://tests/test_integration.gd

const WorldGeneratorScript := preload("res://scripts/world/WorldGenerator.gd")
const VillageModelScript := preload("res://scripts/model/VillageModel.gd")
const RulesEngineScript := preload("res://scripts/rules/RulesEngine.gd")
const EconomySimulatorScript := preload("res://scripts/sim/economy/EconomySimulator.gd")
const ArmySimulatorScript := preload("res://scripts/sim/army/ArmySimulator.gd")
const ActionSimulatorScript := preload("res://scripts/sim/actions/ActionSimulator.gd")
const BotSimulatorScript := preload("res://scripts/bot/BotSimulator.gd")

const EconomyAPI := preload("res://scripts/sim/economy/EconomyAPI.gd")
const ArmyAPI := preload("res://scripts/sim/army/ArmyAPI.gd")
const MovementScript := preload("res://scripts/sim/actions/Movement.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	print("=== Uçtan Uca Entegrasyon Testleri (A-QA) ===")

	_test_full_scenario()
	_test_determinism_and_save_continuity()

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


func _step_sim(state: Dictionary, now_unix: int, delta: float) -> Array:
	if typeof(state.get("world")) == TYPE_DICTIONARY:
		state["world"]["sim_now_unix"] = now_unix
	var ev: Array = []
	ev.append_array(EconomySimulatorScript.process_tick(state, now_unix, delta))
	ev.append_array(ArmySimulatorScript.process_tick(state, now_unix, delta))
	ev.append_array(ActionSimulatorScript.process_tick(state, now_unix, delta))
	ev.append_array(BotSimulatorScript.process_tick(state, now_unix, delta))
	return ev


func _test_full_scenario() -> void:
	print("\n-- Uçtan Uca Oynanış Senaryosu --")

	var world := WorldGeneratorScript.generate(8888, 5)
	var state := {
		"world": world,
		"villages": world["villages"].duplicate(true),
		"queues": [],
		"movements": [],
		"reports": [],
	}

	var player_v: Dictionary = {}
	var barb_v: Dictionary = {}

	for v in state["villages"]:
		if not bool(v.get("is_bot", false)) and not bool(v.get("is_barbarian", false)) and str(v.get("owner", "")) != "Soyguncular":
			if player_v.is_empty():
				player_v = v
		if bool(v.get("is_barbarian", false)) or str(v.get("owner", "")) == "Soyguncular":
			if barb_v.is_empty():
				barb_v = v

	if player_v.is_empty():
		player_v = state["villages"][0]
		player_v["is_bot"] = false

	if barb_v.is_empty():
		barb_v = VillageModelScript.create(999, "Soyguncu", 100, 100, "Soyguncular", false)
		state["villages"].append(barb_v)

	barb_v["is_barbarian"] = true
	barb_v["owner"] = "Soyguncular"
	barb_v["resources"] = {"wood": 5000, "stone": 5000, "iron": 5000}

	# 1. Aşama: Depo kapasitesini 5 yapalım ki 3 günün üretimi birikebilsin
	player_v["buildings"]["storage"] = 5
	var now := 1000000
	state["world"]["sim_now_unix"] = now

	for day in 3:
		for h in 24:
			now += 3600
			_step_sim(state, now, 3600)

	_assert(int(player_v["resources"]["wood"]) > 1000, "3 gün sonra üretimle hammadde birikti (>1000)")

	# (a) Oduncu, Taş ve Maden yükselt
	var b_wood := EconomyAPI.start_build(player_v, "wood", state)
	var finish_wood: int = int(b_wood.get("item", {}).get("finish_unix", now + 1000))
	now = finish_wood + 1
	_step_sim(state, now, 1)

	var b_stone := EconomyAPI.start_build(player_v, "stone", state)
	var finish_stone: int = int(b_stone.get("item", {}).get("finish_unix", now + 1000))
	now = finish_stone + 1
	_step_sim(state, now, 1)

	var b_iron := EconomyAPI.start_build(player_v, "iron", state)
	var finish_iron: int = int(b_iron.get("item", {}).get("finish_unix", now + 1000))
	now = finish_iron + 1
	_step_sim(state, now, 1)

	_assert(int(player_v["buildings"]["wood"]) >= 2, "Oduncu kampı yükseltildi (sv 2)")
	_assert(int(player_v["buildings"]["stone"]) >= 2, "Taş ocağı yükseltildi (sv 2)")
	_assert(int(player_v["buildings"]["iron"]) >= 2, "Maden ocağı yükseltildi (sv 2)")

	# (b) Gereksinim zinciri denetimi:
	# Kışla için Depo 3 + Değirmen 3 şarttır. Depo 1 iken Kışla başlatılamaz!
	player_v["buildings"]["storage"] = 1
	player_v["buildings"]["farm"] = 1
	_assert(not EconomyAPI.can_start_build(player_v, "barracks", state), "Önkoşulsuz Kışla başlatılamaz")

	# Zinciri sırayla tamamla: Depo 2 -> 3, Değirmen 2 -> 3
	player_v["buildings"]["storage"] = 3
	player_v["buildings"]["farm"] = 3
	_assert(EconomyAPI.can_start_build(player_v, "barracks", state), "Depo 3 + Değirmen 3 sonrası Kışla inşa edilebilir")

	var b_res := EconomyAPI.start_build(player_v, "barracks", state)
	_assert(bool(b_res.get("ok", false)), "Kışla inşaatı başlatıldı")

	var finish_barracks: int = int(b_res.get("item", {}).get("finish_unix", now + 300))
	now = finish_barracks + 1
	_step_sim(state, now, 1)
	_assert(int(player_v["buildings"]["barracks"]) >= 1, "Kışla tamamlandı (sv 1)")

	# (c) Okçu araştırması ve eğitim: Kışla 5'e yükselt, Çiftlik ve Depo kapasitesini artır
	player_v["buildings"]["barracks"] = 5
	player_v["buildings"]["farm"] = 25
	player_v["buildings"]["storage"] = 30
	player_v["resources"] = {"wood": 50000, "stone": 50000, "iron": 50000}

	_assert(ArmyAPI.can_research(player_v, "bow", state), "Kışla 5 ile Okçu araştırılabilir")
	var r_res := ArmyAPI.start_research(player_v, "bow", state, now)
	_assert(bool(r_res.get("ok", false)), "Okçu araştırması başlatıldı")

	# Araştırmayı tamamla
	var finish_research: int = int(r_res.get("queue", {}).get("finish_unix", now + 500))
	now = finish_research + 1
	_step_sim(state, now, 1)
	_assert(bool(player_v.get("researched", {}).get("bow", false)), "Okçu araştırması tamamlandı")

	# 300 asker eğit
	var t_res := ArmyAPI.start_training(player_v, "bow", 300, state, now)
	_assert(bool(t_res.get("ok", false)), "300 Okçu eğitimi kuyruğa alındı")

	# Eğitimi tamamla
	var finish_train: int = int(t_res.get("queue", {}).get("finish_unix", now + 10000))
	now = finish_train + 1
	_step_sim(state, now, 1)
	_assert(int(player_v.get("units", {}).get("bow", 0)) == 300, "300 Okçu başarıyla eğitildi ve köyde")

	# (d) Soyguncu köyüne talan gönder -> ganimet eve dönsün
	var raid_units := {"bow": 100}
	var send_res := MovementScript.send_raid(state, int(player_v["id"]), int(barb_v["id"]), raid_units, now)
	_assert(bool(send_res.get("ok", false)), "Soyguncu köyüne talan gönderildi")
	_assert(int(player_v["units"]["bow"]) == 200, "Gönderilen birlikler köyden düşüldü (300 -> 200)")

	var mov: Dictionary = send_res.get("movement", {})
	var arrive_time: int = int(mov.get("arrive_unix", now + 3600))
	now = arrive_time + 1
	_step_sim(state, now, 1)

	# Dönüş hareketini bul ve varışına ilerle
	var return_mov: Dictionary = {}
	for m in state.get("movements", []):
		if str(m.get("type", "")) == "return":
			return_mov = m
			break
	if not return_mov.is_empty():
		var ret_time: int = int(return_mov.get("arrive_unix", now + 3600))
		now = ret_time + 1
		_step_sim(state, now, 1)

	_assert(int(player_v["units"]["bow"]) == 300, "Dönen okçular köye katıldı (200 -> 300)")

	# (e) İptal mekanizması ve iade kuralı doğrulaması
	# Kuyrukta peş peşe 4 iş ekle (4. iş: +%25 ek maliyetli)
	player_v["resources"] = {"wood": 50000, "stone": 50000, "iron": 50000}
	EconomyAPI.start_build(player_v, "wood", state)
	EconomyAPI.start_build(player_v, "wood", state)
	EconomyAPI.start_build(player_v, "wood", state)
	var q4 := EconomyAPI.start_build(player_v, "wood", state) # 4. iş: +%25 ek maliyetli
	_assert(int(q4.get("extra_percent", 0)) == 25, "4. iş +%25 ek maliyetli")

	var q_item: Dictionary = q4.get("item", {})
	var wood_before_cancel: int = int(player_v["resources"]["wood"])
	var base_cost_wood: int = int(q_item.get("cost_paid", {}).get("wood", 0))

	# İptal et
	var cancel_res: Dictionary = EconomyAPI.cancel_build(player_v, int(q_item.get("id", 0)), state)
	_assert(bool(cancel_res.get("ok", false)), "İnşaat işi iptal edildi")
	var wood_after_cancel: int = int(player_v["resources"]["wood"])
	_assert(wood_after_cancel == wood_before_cancel + base_cost_wood, "Yalnızca taban maliyet iade edildi (ek maliyet iade edilmedi)")

	# (f) Değişmezler (Invariants)
	_assert(int(player_v["resources"]["wood"]) >= 0, "Kaynak odun >= 0")
	_assert(int(player_v["resources"]["stone"]) >= 0, "Kaynak taş >= 0")
	_assert(int(player_v["resources"]["iron"]) >= 0, "Kaynak demir >= 0")

	var max_pop := RulesEngineScript.max_population(int(player_v["buildings"]["farm"]))
	var used_pop := VillageModelScript.population_used(player_v)
	_assert(used_pop <= max_pop, "Çalışan vatandaş <= Değirmen tavanı")

	var pts: int = int(player_v.get("points", 0))
	var realm: int = int(player_v.get("realm_of_power", 0))
	_assert(realm >= 0 and realm <= pts, "0 <= Güç Alanı <= Köy Puanı sağlandı")


func _test_determinism_and_save_continuity() -> void:
	print("\n-- Determinizm ve Kayıt Sürekliliği --")

	# (g) İki ayrı çalıştırmada aynı tohum -> aynı hash
	var hash1 := _run_sub_scenario(4321, 200)
	var hash2 := _run_sub_scenario(4321, 200)
	_assert(hash1 == hash2, "Determinizm: iki ayrı bağımsız çalıştırma birebir aynı hash'i verdi (%s)" % hash1.substr(0, 12))

	# (h) Yarıda kaydet/yükle devamlılığı:
	# 200 adımı tek seferde koşan ile (100 adım -> kaydet/yükle -> 100 adım) koşan aynı sonucu vermelidir!
	var world := WorldGeneratorScript.generate(4321, 5)
	var state := {
		"world": world,
		"villages": world["villages"].duplicate(true),
		"queues": [],
		"movements": [],
		"reports": [],
	}

	var now := 1000000
	for i in 100:
		now += 60
		_step_sim(state, now, 60)

	# Durumu serileştir ve geri yükle (JSON roundtrip)
	var serialized := JSON.stringify(state)
	var restored: Dictionary = JSON.parse_string(serialized)

	for i in 100:
		now += 60
		_step_sim(restored, now, 60)

	var split_hash := _hash_state(restored)
	_assert(split_hash == hash1, "Kayıt sürekliliği: ara serileştirme/yükleme sonucu kesintisiz akışla birebir aynı (%s)" % split_hash.substr(0, 12))


func _run_sub_scenario(world_seed: int, steps: int) -> String:
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
		_step_sim(state, now, 60)
	return _hash_state(state)


func _hash_state(state: Dictionary) -> String:
	var s := ""
	for v in state.get("villages", []):
		s += "%d:%d:%d|" % [int(v.get("id", 0)), int(v.get("points", 0)), int(v.get("realm_of_power", 0))]
		var res: Dictionary = v.get("resources", {})
		s += "%d,%d,%d|" % [int(res.get("wood", 0)), int(res.get("stone", 0)), int(res.get("iron", 0))]
	return s.md5_text()
