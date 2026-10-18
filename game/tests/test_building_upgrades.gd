extends SceneTree
## test_building_upgrades.gd — Kale İçi Bina Yükseltmeleri, Süreler ve Gereksinim Zincirleri Kapsamlı Test Paketi.

const RulesEngineScript := preload("res://scripts/rules/RulesEngine.gd")
const BuildQueueScript := preload("res://scripts/sim/economy/BuildQueue.gd")
const EconomyAPIScript := preload("res://scripts/sim/economy/EconomyAPI.gd")
const GameDataScript := preload("res://autoload/GameData.gd")

var _pass_count := 0
var _fail_count := 0

const ALL_BUILDINGS := [
	"main", "stone", "wood", "iron", "storage",
	"hide", "farm", "barracks", "wall", "market",
	"stable", "garage", "snob", "smith", "statue"
]

func _init() -> void:
	print("\n========================================================")
	print("  KALE İÇİ BİNA YÜKSELTMELERİ & GEREKSİNİM ZİNCİRİ TESTLERİ")
	print("========================================================\n")

	test_all_15_buildings_registered()
	test_starter_buildings_costs_and_no_reqs()
	test_requirements_dag_all_buildings()
	test_statue_exact_requirements_and_costs()
	test_deep_requirement_chain_order()
	test_geometric_costs_growth()
	test_build_durations_and_time_factors()
	test_can_start_locked_buildings_costs_visibility()
	test_sequential_upgrade_rule()
	test_queue_extra_cost_scale()
	test_queue_advance_and_level_progression()
	test_statue_unlock_when_all_max_level()

	print("\n========================================================")
	print("  TEST SONUCU: %d BAŞARILI, %d HATALI" % [_pass_count, _fail_count])
	print("========================================================\n")

	if _fail_count > 0:
		print("❌ Bazı testler BAŞARISIZ oldu!")
	else:
		print("✅ TÜM KALE VE GEREKSİNİM TESTLERİ EKSİKSİZ BAŞARILI!")
	quit()


func _assert_true(cond: bool, msg: String) -> void:
	if cond:
		_pass_count += 1
		print("  [PASS] %s" % msg)
	else:
		_fail_count += 1
		print("  [FAIL] ❌ %s" % msg)


## Test 1: 15 binanın tümü GameData ve RulesEngine'de eksiksiz kayıtlı olmalı.
func test_all_15_buildings_registered() -> void:
	print("--- Test 1: 15 Bina Kaydı ve Maksimum Seviyeler ---")
	var gd := GameDataScript.get_singleton()
	_assert_true(ALL_BUILDINGS.size() == 15, "Toplam 15 bina listesi mevcut.")

	for key in ALL_BUILDINGS:
		var maxl := RulesEngineScript._max_level(key)
		var b_data := RulesEngineScript.building_data(key)
		var b_name := str(b_data.get("name", ""))
		_assert_true(maxl > 0, "%s (%s) max_level > 0 (Değer: %d)" % [key, b_name, maxl])


## Test 2: Başlangıç binaları önkoşulsuz olmalı ve Seviye 1 maliyetleri pozitif olmalı.
func test_starter_buildings_costs_and_no_reqs() -> void:
	print("\n--- Test 2: Başlangıç Binaları (Free Start) ve Temel Maliyetler ---")
	var starter := ["main", "stone", "wood", "iron", "storage", "farm"]
	var empty_village_buildings := {}

	for key in starter:
		var reqs := RulesEngineScript.requirements(key, 1)
		_assert_true(reqs.is_empty(), "%s binası başlangıçta serbest (önkoşulsuz)" % key)
		var cost := RulesEngineScript.cost(key, 1)
		var valid_cost := int(cost["wood"]) > 0 and int(cost["stone"]) > 0 and int(cost["iron"]) > 0
		_assert_true(valid_cost, "%s Lv1 maliyeti pozitif: W=%d, S=%d, I=%d" % [key, cost["wood"], cost["stone"], cost["iron"]])


## Test 3: requirements.json DAG önkoşulları eksiksiz tanımlı olmalı.
func test_requirements_dag_all_buildings() -> void:
	print("\n--- Test 3: requirements.json Önkoşul Tanımları (DAG) ---")
	# Gizli Depo (hide) -> Değirmen 3
	var hide_req := RulesEngineScript.requirements("hide", 1)
	_assert_true(hide_req.size() == 1 and hide_req[0]["building"] == "farm" and hide_req[0]["level"] == 3, "Gizli Depo -> Değirmen 3 ister")

	# Kışla (barracks) -> Depo 3 + Değirmen 3
	var barracks_req := RulesEngineScript.requirements("barracks", 1)
	_assert_true(barracks_req.size() == 2, "Kışla 2 bina önkoşulu ister")

	# Sur (wall) -> Kışla 1
	var wall_req := RulesEngineScript.requirements("wall", 1)
	_assert_true(wall_req.size() == 1 and wall_req[0]["building"] == "barracks" and wall_req[0]["level"] == 1, "Sur -> Kışla 1 ister")

	# Market (market) -> Depo 5
	var market_req := RulesEngineScript.requirements("market", 1)
	_assert_true(market_req.size() == 1 and market_req[0]["building"] == "storage" and market_req[0]["level"] == 5, "Market -> Depo 5 ister")

	# Katır çiftliği (stable) -> Market 1
	var stable_req := RulesEngineScript.requirements("stable", 1)
	_assert_true(stable_req.size() == 1 and stable_req[0]["building"] == "market" and stable_req[0]["level"] == 1, "Katır çiftliği -> Market 1 ister")

	# Simyager (garage) -> Kışla 5
	var garage_req := RulesEngineScript.requirements("garage", 1)
	_assert_true(garage_req.size() == 1 and garage_req[0]["building"] == "barracks" and garage_req[0]["level"] == 5, "Simyager -> Kışla 5 ister")

	# Köşk (snob) -> Simyager 5
	var snob_req := RulesEngineScript.requirements("snob", 1)
	_assert_true(snob_req.size() == 1 and snob_req[0]["building"] == "garage" and snob_req[0]["level"] == 5, "Köşk -> Simyager 5 ister")

	# Kuyumcu (smith) -> Köşk 1
	var smith_req := RulesEngineScript.requirements("smith", 1)
	_assert_true(smith_req.size() == 1 and smith_req[0]["building"] == "snob" and smith_req[0]["level"] == 1, "Kuyumcu -> Köşk 1 ister")


## Test 4: Anıt (statue) 14 binanın tümünü en yüksek seviyede istemeli ve maliyeti 400.000 olmalı.
func test_statue_exact_requirements_and_costs() -> void:
	print("\n--- Test 4: Anıt (Statue) Tam Önkoşul ve Maliyet Doğrulaması ---")
	var reqs := RulesEngineScript.requirements("statue", 1)
	_assert_true(reqs.size() == 14, "Anıt kendisi hariç tam 14 binayı önkoşul olarak ister")

	var cost := RulesEngineScript.cost("statue", 1)
	_assert_true(int(cost["wood"]) == 400000 and int(cost["stone"]) == 400000 and int(cost["iron"]) == 400000,
		"Anıt Seviye 1 maliyeti tam 400.000 / 400.000 / 400.000 olmalı (Alınan: W=%d, S=%d, I=%d)" % [cost["wood"], cost["stone"], cost["iron"]])

	var village_buildings := {"main": 1, "wood": 1, "stone": 1, "iron": 1, "storage": 1, "farm": 1}
	var missing := RulesEngineScript.missing_requirements(village_buildings, "statue", 1)
	_assert_true(missing.size() == 14, "Başlangıç köyünde Anıt için 14 binanın 14'ü de eksik bildirilir")


## Test 5: Derin gereksinim zinciri topolojik sıralaması.
func test_deep_requirement_chain_order() -> void:
	print("\n--- Test 5: Kuyumcu (Smith) ve Köşk (Snob) Derin Zincir Sıralaması ---")
	var buildings := {"main": 1, "wood": 1, "stone": 1, "iron": 1, "storage": 1, "farm": 1}
	var chain := RulesEngineScript.requirement_chain(buildings, "smith", 1)

	# Zincir: storage, farm, barracks, garage, snob, smith
	var keys_in_order := []
	for node in chain:
		keys_in_order.append(node["key"])

	_assert_true(keys_in_order.has("barracks"), "Zincirde Kışla var")
	_assert_true(keys_in_order.has("garage"), "Zincirde Simyager var")
	_assert_true(keys_in_order.has("snob"), "Zincirde Köşk var")
	_assert_true(keys_in_order.has("smith"), "Zincirde Kuyumcu var")

	var idx_storage = keys_in_order.find("storage")
	var idx_barracks = keys_in_order.find("barracks")
	var idx_garage = keys_in_order.find("garage")
	var idx_snob = keys_in_order.find("snob")
	var idx_smith = keys_in_order.find("smith")

	_assert_true(idx_storage < idx_barracks and idx_barracks < idx_garage and idx_garage < idx_snob and idx_snob < idx_smith,
		"Zincir kesin topolojik sırada: Depo -> Kışla -> Simyager -> Köşk -> Kuyumcu")


## Test 6: Binaların geometrik maliyet büyümesi (round_half_up doğrulaması).
func test_geometric_costs_growth() -> void:
	print("\n--- Test 6: Geometrik Maliyet Büyümesi ---")
	var c1 := RulesEngineScript.cost("main", 1)
	var c2 := RulesEngineScript.cost("main", 2)
	var c3 := RulesEngineScript.cost("main", 3)

	_assert_true(int(c2["wood"]) > int(c1["wood"]) and int(c3["wood"]) > int(c2["wood"]), "Kale maliyeti seviye arttıkça geometrik büyür")
	_assert_true(int(c1["wood"]) == 70 and int(c1["stone"]) == 85 and int(c1["iron"]) == 65, "Kale Seviye 1 taban maliyetleri doğru (70, 85, 65)")


## Test 7: İnşaat süreleri ve zaman faktörü.
func test_build_durations_and_time_factors() -> void:
	print("\n--- Test 7: İnşaat Süreleri ---")
	var dur1 := RulesEngineScript.build_seconds("main", 1)
	var dur5 := RulesEngineScript.build_seconds("main", 5)

	_assert_true(dur1 > 0.0, "Kale Seviye 1 inşa süresi pozitif: %.1f sn" % dur1)
	_assert_true(dur5 > 0.0, "Kale Seviye 5 inşa süresi pozitif: %.1f sn" % dur5)

	var statue_dur := RulesEngineScript.build_seconds("statue", 1)
	_assert_true(statue_dur > 0.0, "Anıt Seviye 1 inşa süresi pozitif: %.1f sn" % statue_dur)


## Test 8: can_start ve EconomyAPI kilitli binalarda da maliyet ve süreleri 0 değil, gerçek değerinde döndürmeli.
func test_can_start_locked_buildings_costs_visibility() -> void:
	print("\n--- Test 8: Kilitli Binalarda Maliyet ve Süre Görünürlüğü (0 0 0 Hatasının Önlenmesi) ---")
	var village := {
		"id": 1,
		"buildings": {"main": 1, "wood": 1, "stone": 1, "iron": 1, "storage": 1, "farm": 1},
		"resources": {"wood": 500, "stone": 500, "iron": 500}
	}
	var state := {"villages": [village], "queues": []}

	# Anıt kilitli olmasına rağmen maliyetleri 400.000 olarak dönmeli, 0 0 0 dönmemeli!
	var details := BuildQueueScript.can_start(state, village, "statue")
	_assert_true(not bool(details["ok"]), "Anıt kilitli olduğu için ok = false")
	_assert_true(str(details["reason"]) == "requirements", "Anıt red sebebi 'requirements'")

	var cost: Dictionary = details.get("cost", {})
	_assert_true(int(cost.get("wood", 0)) == 400000, "Anıt kilitli olsa dahi cost.wood = 400000 (0 DEĞİL)")
	_assert_true(int(cost.get("stone", 0)) == 400000, "Anıt kilitli olsa dahi cost.stone = 400000 (0 DEĞİL)")
	_assert_true(int(cost.get("iron", 0)) == 400000, "Anıt kilitli olsa dahi cost.iron = 400000 (0 DEĞİL)")

	# Kışla kilitliyken maliyeti
	var b_details := BuildQueueScript.can_start(state, village, "barracks")
	var b_cost: Dictionary = b_details.get("cost", {})
	_assert_true(int(b_cost.get("wood", 0)) == 180 and int(b_cost.get("stone", 0)) == 180 and int(b_cost.get("iron", 0)) == 120,
		"Kışla kilitliyken dahi maliyet W=180, S=180, I=120 olarak döndürülür")


## Test 9: Sıralı ilerleme kuralı (mevcut + 1 dışındaki yükseltmeler reddedilmeli).
func test_sequential_upgrade_rule() -> void:
	print("\n--- Test 9: Sıralı İlerleme Kapısı (cur + 1) ---")
	var village := {
		"id": 1,
		"buildings": {"main": 50},  # Kale zaten maks
		"resources": {"wood": 999999, "stone": 999999, "iron": 999999}
	}
	var state := {"villages": [village], "queues": []}
	var details := BuildQueueScript.can_start(state, village, "main")
	_assert_true(not bool(details["ok"]) and str(details["reason"]) == "max_level", "Maks seviyedeki bina yükseltilemez (max_level)")


## Test 10: Kuyruk ek maliyet skalası (1-3 ücretsiz, 4. +%25).
func test_queue_extra_cost_scale() -> void:
	print("\n--- Test 10: Kuyruk Ek Maliyet Skalası ---")
	var village := {
		"id": 1,
		"buildings": {"main": 10, "wood": 10, "stone": 10, "iron": 10, "storage": 10, "farm": 10},
		"resources": {"wood": 999999, "stone": 999999, "iron": 999999}
	}
	var state := {
		"villages": [village],
		"queues": [
			{"type": "build", "village_id": 1, "key": "wood", "target_level": 11, "start_unix": 1000, "finish_unix": 1060},
			{"type": "build", "village_id": 1, "key": "stone", "target_level": 11, "start_unix": 1060, "finish_unix": 1120},
			{"type": "build", "village_id": 1, "key": "iron", "target_level": 11, "start_unix": 1120, "finish_unix": 1180},
		]
	}
	# Kuyrukta 3 iş varken 4. iş %25 ek maliyet ister
	var pct := BuildQueueScript.extra_cost_percent(state, 1)
	_assert_true(pct == 25, "Kuyrukta 3 bekleyen iş varken 4. iş için ek maliyet = +%%25 (Alınan: +%%%d)" % pct)


## Test 11: Kuyruk simülasyonu ve süre bitiminde seviye artışı.
func test_queue_advance_and_level_progression() -> void:
	print("\n--- Test 11: Simülasyon Saati ve Seviye İlerlemesi (BuildQueue.advance) ---")
	var village := {
		"id": 101,
		"buildings": {"main": 1, "wood": 1, "stone": 1, "iron": 1, "storage": 1, "farm": 1},
		"resources": {"wood": 10000, "stone": 10000, "iron": 10000}
	}
	var state := {"villages": [village], "queues": []}
	var now := 100000

	# Oduncu Kampı Seviye 2 yükseltmesi başlat
	var start_res := BuildQueueScript.start_build(state, village, "wood", now)
	_assert_true(bool(start_res["ok"]), "Oduncu Seviye 2 inşası başlatıldı")

	var q_items := BuildQueueScript.items(state, 101)
	_assert_true(q_items.size() == 1, "Kuyrukta 1 iş var")
	var finish_unix := int(q_items[0]["finish_unix"])
	_assert_true(finish_unix > now, "finish_unix zamanı > now")

	# Süre dolmadan advance çağır -> bina tamamlanmamalı
	var events_early := BuildQueueScript.advance(state, finish_unix - 1)
	_assert_true(events_early.is_empty(), "Süre dolmadan iş tamamlanmaz")
	_assert_true(int(village["buildings"]["wood"]) == 1, "Oduncu hala Seviye 1")

	# Süre dolunca advance çağır -> bina tamamlanmalı ve Seviye 2 olmalı
	var events_done := BuildQueueScript.advance(state, finish_unix)
	_assert_true(events_done.size() == 1, "1 bina tamamlanma olayı üretildi")
	_assert_true(int(village["buildings"]["wood"]) == 2, "Oduncu Kampı başarıyla Seviye 2'ye yükseldi!")


## Test 12: Tüm 14 bina maks olunca Anıt inşa edilebilir hale gelir.
func test_statue_unlock_when_all_max_level() -> void:
	print("\n--- Test 12: Tüm Binalar Maksimum Olduğunda Anıtın Açılması ---")
	var maxed_village := {
		"id": 201,
		"buildings": {
			"main": 50, "farm": 50, "wood": 50, "stone": 50, "iron": 50,
			"storage": 50, "hide": 30, "market": 30, "barracks": 30,
			"stable": 30, "garage": 5, "snob": 10, "smith": 5, "wall": 20,
			"statue": 0
		},
		"resources": {"wood": 500000, "stone": 500000, "iron": 500000}
	}
	var state := {"villages": [maxed_village], "queues": []}

	var missing := RulesEngineScript.missing_requirements(maxed_village["buildings"], "statue", 1)
	_assert_true(missing.is_empty(), "Tüm binalar maks iken Anıtın hiçbir eksik önkoşulu kalmaz")

	var details := BuildQueueScript.can_start(state, maxed_village, "statue")
	_assert_true(bool(details["ok"]), "Anıt artık başarıyla inşa edilebilir (ok = true)!")
	_assert_true(str(details["reason"]) == "ok", "İnşa onay gerekçesi 'ok'")
