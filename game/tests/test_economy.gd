extends SceneTree
## test_economy.gd — Ekonomi + inşaat kuyruğu + puan + Güç Alanı testleri (**A-EKONOMI**).
##
## Çalıştırma (headless):
##   godot --headless --path game --script res://tests/test_economy.gd
##
## Kapsam (görev doğrulaması):
##   (a) 1 saatlik üretim beklenen değeri verir; Depo tavanı aşılmaz.
##   (b) Kuyruk: ilk 3 iş ücretsiz; 4. işte ek maliyet (+%25) doğru uygulanır.
##   (c) Sıralı ilerleme: bir bina yalnızca mevcut+1 seviyeye yükseltilir.
##   (d) Gereksinim ihlali reddedilir (Kışla ← Depo 3 + Değirmen 3).
##   (e) Offline hızlı-ileri: 30 günlük tick çökmez, kaynak/iş tutarlı.
##   (f) Güç Alanı saatte %1 artar; tavanı (köy puanı) aşmaz.
##   (g) Tam gelişmiş köy puanı = 10000.
##   (h) GameLoop (§7b) modülleri yükler ve tick'i işler.
##
## Başarısızlıkta `quit(1)` ile çıkar (CI uyumlu).

const RE := preload("res://scripts/rules/RulesEngine.gd")
const VM := preload("res://scripts/model/VillageModel.gd")
const ES := preload("res://scripts/sim/economy/EconomySimulator.gd")
const BQ := preload("res://scripts/sim/economy/BuildQueue.gd")
const PROD := preload("res://scripts/sim/economy/Production.gd")
const POP := preload("res://scripts/sim/economy/Population.gd")
const ROP := preload("res://scripts/sim/economy/RealmOfPower.gd")
const API := preload("res://scripts/sim/economy/EconomyAPI.gd")
const GAMELOOP_PATH := "res://scripts/core/GameLoop.gd"

const RESOURCES := ["wood", "stone", "iron"]
const T0 := 1700000000

var _passed := 0
var _failed := 0
var _fail_labels: Array = []


# =============================================================================
#  Altyapı
# =============================================================================

func _game_data() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("GameData")
	return null


func _game_config() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("GameConfig")
	return null


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("PASS: ", label)
	else:
		_failed += 1
		_fail_labels.append(label)
		print("FAIL: ", label)


func _check_eq(actual, expected, label: String) -> void:
	_check(actual == expected, "%s [beklenen=%s, gerçek=%s]" % [label, str(expected), str(actual)])


func _state(village: Dictionary) -> Dictionary:
	return {"villages": [village], "queues": [], "world": {}}


func _rich_village(id: int) -> Dictionary:
	var v := VM.create(id, "Test", 10, 10, "Oyuncu", false)
	v["resources"] = {"wood": 500000, "stone": 500000, "iron": 500000}
	VM.set_building_level(v, "storage", 50)  # tavan 950.000 → test kaynakları sığar
	return v


func _missing_has(missing: Array, building: String, level: int) -> bool:
	for m in missing:
		if str(m.get("building", "")) == building and int(m.get("level", -1)) == level:
			return true
	return false


func _sum(d: Dictionary) -> int:
	var total := 0
	for k in d.keys():
		total += int(d[k])
	return total


func _resource_ok(village: Dictionary) -> bool:
	var res = village.get("resources", {})
	var cap := PROD.storage_capacity(village)
	for r in RESOURCES:
		var value = res.get(r, null)
		if typeof(value) != TYPE_INT:
			return false
		if int(value) < 0:
			return false
		if cap > 0 and int(value) > cap:
			return false
	return true


# =============================================================================
#  Ana akış
# =============================================================================

func _initialize() -> void:
	var gd := _game_data()
	if gd == null:
		print("FAIL: GameData autoload düğümü bulunamadı.")
		quit(1)
		return
	gd.load_all(true)
	var gc := _game_config()
	if gc != null:
		gc.set("speed", 1.0)  # testleri hızdan bağımsız yap

	print("=== Ekonomi Testleri (A-EKONOMI) ===")
	print("Veri: ", gd.summary())

	_test_production(gd)
	_test_production_fractional()
	_test_queue_free_slots(gd)
	_test_sequential_progression(gd)
	_test_requirements(gd)
	_test_citizens()
	_test_offline_30_days(gd)
	_test_realm(gd)
	_test_points(gd)
	_test_tear_down(gd)
	_test_cancel_refund(gd)
	_test_economy_api(gd)
	_test_game_loop(gd)

	print("")
	print("==================== ÖZET ====================")
	print("PASS: %d   FAIL: %d" % [_passed, _failed])
	if _failed > 0:
		print("Başarısız testler:")
		for label in _fail_labels:
			print("  - ", label)
	print("==============================================")
	quit(1 if _failed > 0 else 0)


# =============================================================================
#  (a) Üretim + Depo tavanı
# =============================================================================

func _test_production(gd: Node) -> void:
	print("\n-- (a) Üretim & Depo tavanı --")
	var v := VM.create(1, "Üretim", 0, 0, "Oyuncu", false)
	v["resources"] = {"wood": 0, "stone": 0, "iron": 0}
	var st := _state(v)

	var events := ES.process_tick(st, T0, 3600.0)
	_check_eq(events.size(), 0, "1 saatlik üretim tick'i (olay yok; tamamlanan iş yok)")

	var exp_wood := RE.production_per_hour("wood", 1)
	_check_eq(int(v["resources"]["wood"]), int(exp_wood), "1 saat → odun = production_per_hour(wood,1) = 120")
	_check_eq(int(v["resources"]["stone"]), int(RE.production_per_hour("stone", 1)), "1 saat → taş = 120")
	_check_eq(int(v["resources"]["iron"]), int(RE.production_per_hour("iron", 1)), "1 saat → demir = 120")

	# Depo tavanı (hammadde başına) aşılmaz.
	var v2 := VM.create(2, "Tavan", 0, 0, "Oyuncu", false)
	v2["resources"] = {"wood": 990, "stone": 990, "iron": 990}
	var st2 := _state(v2)
	ES.process_tick(st2, T0, 3600.0)
	var cap := RE.storage_capacity(1)
	_check_eq(cap, 1000, "Depo L1 kapasitesi = 1000")
	_check_eq(int(v2["resources"]["wood"]), 1000, "Üretim tavanı aşamaz (990 + 120 → 1000)")
	_check(int(v2["resources"]["wood"]) <= cap, "Odun ≤ tavan")
	_check(_resource_ok(v2), "Kaynaklar [0, tavan] aralığında")

	# Üretim olmayan bina etkisiz; Gizli Depo kapasitesi erişilebilir.
	_check_eq(RE.production_per_hour("farm", 5), 0.0, "Üretim olmayan bina = 0")
	_check_eq(PROD.hideout_capacity(v), 0, "Gizli Depo yok → kapasite 0")
	VM.set_building_level(v, "hide", 30)
	_check_eq(PROD.hideout_capacity(v), 23278, "Gizli Depo L30 kapasitesi = 23278")

	# Bonus köy: +%10 ilgili hammadde.
	var vb := VM.create(3, "Bonus", 0, 0, "Usta", false)
	vb["bonus_type"] = "wood"
	_check_eq(PROD.bonus_multiplier(vb, "wood"), 1.10, "Bonus köy wood çarpanı = 1.10")
	_check_eq(PROD.bonus_multiplier(vb, "stone"), 1.0, "Bonus köy stone çarpanı = 1.0")
	vb["bonus_type"] = "production"
	_check(absf(PROD.bonus_multiplier(vb, "wood") - 1.03) < 0.0001, "Bonus köy production çarpanı = 1.03")


func _test_production_fractional() -> void:
	print("\n-- (a2) Kayan nokta telafisi (küçük tick'ler) --")
	var v := VM.create(4, "Kesir", 0, 0, "Oyuncu", false)
	v["resources"] = {"wood": 0, "stone": 0, "iron": 0}
	var st := _state(v)
	var total_gained := 0
	var steps := 100
	var dt := 36.0  # 100 × 36 s = 3600 s = 1 saat
	for i in range(steps):
		var r := PROD.produce(v, dt)
		total_gained += int(r["gained"]["wood"])
	_check(absf(float(total_gained) - 120.0) <= 1.0, "100 küçük tick toplamı ≈ 120 odun (gerçek %d)" % total_gained)
	_check(int(v["resources"]["wood"]) == total_gained, "Depo değeri biriken kazançla tutarlı")


# =============================================================================
#  (b) Kuyruk: 3 ücretsiz + ek maliyet
# =============================================================================

func _test_queue_free_slots(gd: Node) -> void:
	print("\n-- (b) Kuyruk: 3 ücretsiz, 4. işte ek maliyet --")
	_check_eq(RE.queue_slots_free(), 3, "Ücretsiz kuyruk işi = 3")

	var v := _rich_village(1)
	VM.set_building_level(v, "main", 1)
	var st := _state(v)

	var results := []
	for i in range(4):
		results.append(BQ.start_build(st, v, "main", T0))

	var all_ok := true
	for r in results:
		if not bool(r.get("ok", false)):
			all_ok = false
	_check(all_ok, "4 inşa işi de kuyruğa alındı")
	_check_eq(BQ.pending_count(st, 1), 4, "Kuyrukta 4 iş var")

	_check_eq(int(results[0].get("target_level", 0)), 2, "1. iş hedefi = 2 (mevcut+1)")
	_check_eq(int(results[1].get("target_level", 0)), 3, "2. iş hedefi = 3")
	_check_eq(int(results[2].get("target_level", 0)), 4, "3. iş hedefi = 4")
	_check_eq(int(results[3].get("target_level", 0)), 5, "4. iş hedefi = 5")

	_check_eq(int(results[0].get("extra_percent", -1)), 0, "1. iş ek maliyet = 0")
	_check_eq(int(results[1].get("extra_percent", -1)), 0, "2. iş ek maliyet = 0")
	_check_eq(int(results[2].get("extra_percent", -1)), 0, "3. iş ek maliyet = 0")
	_check_eq(int(results[3].get("extra_percent", -1)), 25, "4. iş ek maliyet = +25")

	# İlk 3 iş taban maliyet; 4. iş taban+%25.
	var base5 := RE.cost("main", 5)
	var expected4 := {}
	for r in RESOURCES:
		expected4[r] = int(base5.get(r, 0)) + int(floor(float(base5.get(r, 0)) * 0.25 + 0.5))
	_check_eq(results[0]["cost"], RE.cost("main", 2), "1. iş maliyeti = taban (main L2)")
	_check_eq(results[3]["cost"], expected4, "4. iş maliyeti = taban(main L5) + %25")

	# Harcama doğru: rezervden toplam maliyet düştü.
	var spent := 0
	for r in results:
		spent += _sum(r["cost"])
	var expected_remaining := 500000 * 3 - spent
	_check_eq(_sum(v["resources"]), expected_remaining, "Toplam maliyet rezervden düştü")

	# 5. iş (index 4) +%56; kuyrukta 5 iş varken sıradaki (6.) iş +%95.
	var r5 := BQ.start_build(st, v, "main", T0)
	_check_eq(int(r5.get("extra_percent", -1)), 56, "5. iş ek maliyet = +56")
	_check_eq(BQ.extra_cost_percent(st, 1), 95, "Kuyrukta 5 iş varken sıradaki (6.) ek maliyet = +95")


# =============================================================================
#  (c) Sıralı ilerleme
# =============================================================================

func _test_sequential_progression(gd: Node) -> void:
	print("\n-- (c) Sıralı ilerleme (mevcut+1) --")
	var v := _rich_village(1)
	VM.set_building_level(v, "wood", 1)
	var st := _state(v)

	_check_eq(BQ.next_target_level(st, v, "wood"), 2, "Boş kuyruk → hedef = mevcut+1 = 2")
	BQ.start_build(st, v, "wood", T0)
	_check_eq(BQ.next_target_level(st, v, "wood"), 3, "1 iş kuyrukta → hedef = 3")
	BQ.start_build(st, v, "wood", T0)
	_check_eq(BQ.next_target_level(st, v, "wood"), 4, "2 iş kuyrukta → hedef = 4")

	# Sıçrama yok: hedef, kuyruktaki en yüksek hedefin bir fazlasıdır.
	var projected := BQ.projected_buildings(st, v)
	_check_eq(int(projected.get("wood", 0)), 3, "Projeksiyon en yüksek kuyruk hedefini alır (3)")

	# Maksimum seviyede yükseltme reddedilir.
	var vmax := _rich_village(2)
	VM.set_building_level(vmax, "wall", 20)
	var stmax := _state(vmax)
	var check := BQ.can_start(stmax, vmax, "wall")
	_check(not bool(check.get("ok", true)), "Maks. seviyedeki bina yükseltilemez")
	_check_eq(str(check.get("reason", "")), "max_level", "Sebep = max_level")


# =============================================================================
#  (d) Gereksinim ihlali
# =============================================================================

func _test_requirements(gd: Node) -> void:
	print("\n-- (d) Gereksinim ihlali (Kışla ← Depo 3 + Değirmen 3) --")
	var v := _rich_village(1)
	VM.set_building_level(v, "storage", 2)
	VM.set_building_level(v, "farm", 2)
	var st := _state(v)

	var check := BQ.can_start(st, v, "barracks")
	_check(not bool(check.get("ok", true)), "Depo 2 + Değirmen 2 → Kışla inşa edilemez")
	_check_eq(str(check.get("reason", "")), "requirements", "Sebep = requirements")
	var missing: Array = check.get("missing", [])
	_check_eq(missing.size(), 2, "Eksik önkoşul = 2")
	_check(_missing_has(missing, "storage", 3), "Eksik: Depo 3")
	_check(_missing_has(missing, "farm", 3), "Eksik: Değirmen 3")

	var denied := BQ.start_build(st, v, "barracks", T0)
	_check(not bool(denied.get("ok", true)), "Gereksinim ihlalinde start_build reddeder")
	_check_eq(BQ.pending_count(st, 1), 0, "Reddedilen iş kuyruğa girmedi")

	# Önkoşullar sağlanınca inşa edilebilir.
	VM.set_building_level(v, "storage", 3)
	VM.set_building_level(v, "farm", 3)
	var ok := BQ.can_start(st, v, "barracks")
	_check(bool(ok.get("ok", false)), "Depo 3 + Değirmen 3 → Kışla inşa edilebilir")
	_check_eq(int(ok.get("target_level", 0)), 1, "Kışla hedef seviyesi = 1")

	# Geçişli zincir: Sur ← Kışla 1 (önce Kışla gerekir).
	var v2 := _rich_village(2)
	var wall := BQ.can_start(_state(v2), v2, "wall")
	_check(not bool(wall.get("ok", true)), "Sur, Kışla yokken inşa edilemez")
	_check(_missing_has(wall.get("missing", []), "barracks", 1), "Eksik: Kışla 1")


# =============================================================================
#  Vatandaş kısıtı
# =============================================================================

func _test_citizens() -> void:
	print("\n-- Vatandaş kısıtı (Değirmen tavanı) --")
	var v := VM.create(1, "Nüfus", 0, 0, "Oyuncu", false)
	# Değirmen'i düşük tut, kaynağı bol ver → vatandaş kısıtı tetiklensin.
	VM.set_building_level(v, "farm", 1)     # tavan 250
	VM.set_building_level(v, "barracks", 30)  # workersTotal yüksek (vatandaş bağlar)
	v["resources"] = {"wood": 500000, "stone": 500000, "iron": 500000}
	var used := POP.used_citizens(v)
	_check(used > 0, "Çalışan vatandaş > 0 (Kışla L30)")
	var free := POP.free_citizens(v)
	_check_eq(free, POP.max_citizens(v) - used, "Boş vatandaş = tavan − çalışan")

	# Kışla L30 çok vatandaş bağlar (used > max); Keresteci yükseltmesi vatandaş ister.
	var st := _state(v)
	var need := POP.workers_needed("wood", int(v["buildings"]["wood"]) + 1)
	_check(need > 0, "Keresteci yükseltmesi vatandaş bağlar (> 0)")
	_check(free < need, "Boş vatandaş yetersiz (free=%d < need=%d)" % [free, need])
	if free < need:
		var check := BQ.can_start(st, v, "wood")
		_check_eq(str(check.get("reason", "")), "citizens", "Boş vatandaş yetersiz → sebep = citizens")


# =============================================================================
#  (e) Offline hızlı-ileri: 30 gün
# =============================================================================

func _test_offline_30_days(gd: Node) -> void:
	print("\n-- (e) Offline hızlı-ileri: 30 gün --")
	var v := _rich_village(1)
	VM.set_building_level(v, "main", 1)
	VM.set_building_level(v, "wood", 1)
	var st := _state(v)
	BQ.start_build(st, v, "main", T0)
	BQ.start_build(st, v, "wood", T0)
	_check_eq(BQ.pending_count(st, 1), 2, "2 iş kuyruğa alındı")

	# GameClock.fast_forward ile aynı adım stratejisi (MAX_CATCHUP_STEPS = 10000).
	var seconds := 30.0 * 24.0 * 3600.0  # 2.592.000 s
	var max_steps := 10000
	var step := maxf(1.0, seconds / float(max_steps))
	var remaining := seconds
	var now := T0
	var steps := 0
	while remaining > 0.0 and steps < max_steps:
		var dt := minf(step, remaining)
		now += int(floor(dt + 0.5))
		ES.process_tick(st, now, dt)
		remaining -= dt
		steps += 1

	_check(true, "30 günlük tick döngüsü çökmedi (%d adım)" % steps)
	_check(BQ.pending_count(st, 1) == 0, "Kısa işler 30 gün içinde tamamlandı (kuyruk boş)")
	_check(VM.building_level(v, "main") >= 2, "Kale yükseldi (≥ 2)")
	_check(VM.building_level(v, "wood") >= 2, "Oduncu Kampı yükseldi (≥ 2)")
	_check(_resource_ok(v), "Kaynaklar int ve [0, tavan] aralığında")
	_check(int(v["resources"]["wood"]) > 500000, "30 gün üretim → odun arttı (500.000'den fazla)")
	_check_eq(int(v.get("points", -1)), RE.village_points(v["buildings"]), "Köy puanı bina seviyeleriyle tutarlı")

	# Tek dev adım da çökmemeli (en kötü durum).
	var v2 := _rich_village(2)
	v2["resources"] = {"wood": 0, "stone": 0, "iron": 0}
	var st2 := _state(v2)
	ES.process_tick(st2, T0, seconds)
	_check(_resource_ok(v2), "Tek dev adım (30 gün) tek seferde tutarlı")
	_check(int(v2["resources"]["wood"]) > 0, "Tek dev adım → odun üretildi")
	_check(int(v2["resources"]["wood"]) <= PROD.storage_capacity(v2), "Tek dev adım → tavan aşılmadı")


# =============================================================================
#  (f) Güç Alanı
# =============================================================================

func _test_realm(gd: Node) -> void:
	print("\n-- (f) Güç Alanı (realm of power) --")
	var v := VM.create(1, "Güç", 0, 0, "Oyuncu", false)
	var p := int(v.get("points", 0))
	_check(p > 0, "Köy puanı > 0 (%d)" % p)
	_check_eq(ROP.cap(v), p, "Tavan = köy puanı")

	v["realm_of_power"] = 0
	var gain1 := ROP.regenerate(v, 3600.0)
	var expected := int(floor(float(p) * 0.01 + 0.5))
	_check_eq(gain1, expected, "1 saat → +%%1 (beklenen %d)" % expected)
	_check_eq(ROP.hourly_gain(v), expected, "hourly_gain = tavan × %1")

	# Çok saat sonra tavanı aşmaz.
	for i in range(10000):
		ROP.regenerate(v, 3600.0)
	_check_eq(int(v["realm_of_power"]), p, "Uzun süre sonra Güç Alanı = tavan (aşılmaz)")
	_check(int(v["realm_of_power"]) <= p, "Güç Alanı ≤ köy puanı")

	# Tavanın üstüne elle yazılırsa kırpılır.
	v["realm_of_power"] = p + 500
	ROP.regenerate(v, 3600.0)
	_check_eq(int(v["realm_of_power"]), p, "Tavanı aşan değer kırpılır")

	# Kont düşüşü + yarı kapak.
	v["realm_of_power"] = p
	var drop := ROP.apply_count_drop(v, 2250, true)
	_check_eq(int(drop["applied"]), int(floor(float(p) / 2.0)), "Kont düşüşü tavanın yarısıyla sınırlı")
	_check(v["realm_of_power"] >= 0, "Güç Alanı negatife inmez")

	# Düşük alan → fetih.
	v["realm_of_power"] = 5
	var drop2 := ROP.apply_count_drop(v, 2250, true)
	_check_eq(int(v["realm_of_power"]), 0, "Düşük alan → 0")
	_check(bool(drop2["conquered"]), "Güç Alanı 0 → fetih işaretlendi")
	var after := ROP.on_conquered(v)
	_check_eq(after, int(floor(float(p) * 0.30 + 0.5)), "Fetih sonrası alan = maksimumun %30'u")

	# Tick üzerinden yenilenme olayı yayınlanır.
	var v3 := VM.create(2, "TickGüç", 0, 0, "Oyuncu", false)
	v3["realm_of_power"] = 0
	var st := _state(v3)
	var events := ES.process_tick(st, T0, 3600.0)
	var found := false
	for e in events:
		if str(e.get("type", "")) == "realm_of_power_changed":
			found = true
	_check(found, "Tick, realm_of_power_changed olayı üretti")


# =============================================================================
#  (g) Puan
# =============================================================================

func _test_points(gd: Node) -> void:
	print("\n-- (g) Puan --")
	var full := {}
	for key in gd.get_all_building_keys():
		full[str(key)] = int(gd.get_max_level(str(key)))
	_check_eq(RE.village_points(full), 10000, "Tam gelişmiş köy puanı = 10000")

	var v := VM.create(1, "TamGelişmiş", 0, 0, "Oyuncu", false)
	for key in gd.get_all_building_keys():
		VM.set_building_level(v, str(key), int(gd.get_max_level(str(key))))
	_check(VM.is_developed(v), "Tüm binalar maksimum → is_developed")
	_check_eq(int(v["points"]), 10000, "Köy puanı `points` alanına yazıldı (10000)")
	_check_eq(ROP.cap(v), 10000, "Güç Alanı tavanı = 10000 (puan tabanlı)")
	_check(int(v["realm_of_power"]) <= 10000, "Anlık Güç Alanı tavanı aşmaz")


# =============================================================================
#  Bina yıkımı
# =============================================================================

func _test_tear_down(gd: Node) -> void:
	print("\n-- Bina yıkımı (tear down) --")
	var v := VM.create(1, "Yıkım", 0, 0, "Oyuncu", false)
	VM.set_building_level(v, "main", 15)
	VM.set_building_level(v, "wall", 5)
	var st := _state(v)
	var before_used := POP.used_citizens(v)
	var res_before: Dictionary = v["resources"].duplicate(true)

	var r := BQ.tear_down(st, v, "wall")
	_check(bool(r.get("ok", false)), "Kale L15 → Sur yıkılabilir")
	_check_eq(VM.building_level(v, "wall"), 0, "Sur seviyesi 0")
	_check(int(r.get("released_citizens", 0)) > 0, "Vatandaş geri geldi (> 0)")
	_check(POP.used_citizens(v) < before_used, "Çalışan vatandaş azaldı")
	_check_eq(v["resources"], res_before, "Hammadde iadesi YOK")

	# Kale L15'ten düşükse yıkılamaz.
	var v2 := VM.create(2, "Zayıf", 0, 0, "Oyuncu", false)
	VM.set_building_level(v2, "main", 10)
	VM.set_building_level(v2, "farm", 5)
	var r2 := BQ.tear_down(_state(v2), v2, "farm")
	_check(not bool(r2.get("ok", true)), "Kale L10 → yıkılamaz")
	_check_eq(str(r2.get("reason", "")), "castle_level", "Sebep = castle_level")


# =============================================================================
#  İptal iadesi (taban iade / ek maliyet iade değil)
# =============================================================================

func _test_cancel_refund(gd: Node) -> void:
	print("\n-- İptal iadesi: taban iade, ek maliyet iade değil --")
	var v := _rich_village(1)
	VM.set_building_level(v, "main", 1)
	var st := _state(v)

	# 5 iş kuyruğa al: 4. iş +%25, 5. iş +%56 ek maliyet taşır.
	var results := []
	for i in range(5):
		results.append(BQ.start_build(st, v, "main", T0))
	_check_eq(BQ.pending_count(st, 1), 5, "Kuyrukta 5 iş var")

	# İptal edilecek iş: 4. iş (ek maliyetli, aradaki komut → diğerleri korunmalı).
	var victim_result: Dictionary = results[3]
	var victim: Dictionary = victim_result.get("item", {})
	var victim_id := int(victim.get("id", -1))
	var base_paid: Dictionary = victim.get("cost_paid", {})
	var extra_paid: Dictionary = victim.get("extra_paid", {})
	_check(int(victim_result.get("extra_percent", -1)) == 25, "İptal edilecek iş ek maliyet = +25")
	_check(_sum(extra_paid) > 0, "İptal edilecek işin extra_paid > 0")
	_check_eq(_sum(base_paid) + _sum(extra_paid), _sum(victim_result.get("cost", {})), "cost_paid + extra_paid = toplam maliyet")

	# İptal öncesi diğer işlerin (id, hedef) çiftleri.
	var before := []
	for it in BQ.items(st, 1):
		before.append([int(it.get("id", -1)), int(it.get("target_level", 0))])

	var res_before := _sum(v["resources"])
	var cancel := BQ.cancel_build(st, 1, victim_id, true, T0)
	_check(bool(cancel.get("ok", false)), "İptal başarılı")
	_check_eq(_sum(cancel.get("refunded", {})), _sum(base_paid), "Yalnız taban maliyet iade edildi")
	_check_eq(_sum(cancel.get("refunded_extra", {})), 0, "Ek maliyet iade edilmedi")
	_check_eq(_sum(cancel.get("forfeited", {})), _sum(extra_paid), "Kayıp = ek maliyet")
	_check_eq(_sum(v["resources"]), res_before + _sum(base_paid), "Kaynak yalnız taban kadar arttı")

	# Diğer işler bozulmadı: kimlik/hedef bilgisi korunur, kuyruk yeniden zincirlenir.
	_check_eq(BQ.pending_count(st, 1), 4, "Kuyrukta 4 iş kaldı")
	var after := []
	for it in BQ.items(st, 1):
		after.append([int(it.get("id", -1)), int(it.get("target_level", 0))])
	var expected := []
	for pair in before:
		if int(pair[0]) != victim_id:
			expected.append(pair)
	_check_eq(after, expected, "Diğer işlerin (id, hedef) bilgisi bozulmadı")

	var chain_ok := true
	var prev := -1
	for it in BQ.items(st, 1):
		var s := int(it.get("start_unix", -1))
		var f := int(it.get("finish_unix", -1))
		if s < prev or f <= s:
			chain_ok = false
		prev = f
	_check(chain_ok, "Kalan işler yeniden zincirlendi (start/finish artan)")

	# Ek maliyetsiz işte kayıp 0, iade = tam taban.
	var head: Dictionary = BQ.items(st, 1)[0]
	var c2 := BQ.cancel_build(st, 1, int(head.get("id", -1)), true, T0)
	_check_eq(_sum(c2.get("forfeited", {})), 0, "Ek maliyetsiz işte kayıp = 0")
	_check_eq(_sum(c2.get("refunded", {})), _sum(head.get("cost_paid", {})), "İade = cost_paid (tam taban)")

	# `refund=false` (eski davranış) → hiçbir şey iade edilmez.
	var v2 := _rich_village(2)
	VM.set_building_level(v2, "main", 1)
	var st2 := _state(v2)
	var r2 := BQ.start_build(st2, v2, "wood", T0)
	var it2: Dictionary = r2.get("item", {})
	var b2 := _sum(v2["resources"])
	var c3 := BQ.cancel_build(st2, 2, int(it2.get("id", -1)), false, T0)
	_check_eq(_sum(c3.get("refunded", {})), 0, "refund=false → iade yok")
	_check_eq(_sum(v2["resources"]), b2, "refund=false → kaynak değişmedi")


# =============================================================================
#  EconomyAPI dış arayüz
# =============================================================================

func _test_economy_api(gd: Node) -> void:
	print("\n-- EconomyAPI dış arayüz --")
	var v := _rich_village(1)
	VM.set_building_level(v, "main", 1)
	var st := _state(v)
	st["world"] = {"sim_now_unix": T0}

	_check(bool(API.can_start_build(v, "main", st)), "can_start_build(main) = true")
	var res := API.start_build(v, "main", st)
	_check(bool(res.get("ok", false)), "start_build(main) başarılı")
	_check_eq(API.queued_items(v, st).size(), 1, "queued_items = 1")

	var item: Dictionary = API.queued_items(v, st)[0]
	_check_eq(API.tick_eta(item, T0), int(item.get("finish_unix", 0)) - T0, "tick_eta = finish − now")
	_check(API.tick_eta(item, int(item["finish_unix"]) + 10) == 0, "Geçmişte kalan iş → 0")

	var ar := API.available_resources(v)
	_check(ar.has("wood") and ar.has("stone") and ar.has("iron"), "available_resources 3 hammadde içerir")

	var pop := API.population_summary(v)
	_check(int(pop.get("max", 0)) > 0, "population_summary.max > 0")
	var realm := API.realm_summary(v)
	_check_eq(int(realm.get("cap", -1)), int(v.get("points", 0)), "realm_summary.cap = köy puanı")

	# İptal: taban maliyet İADE, ek maliyet İADE DEĞİL (`docs/19` §3.2).
	var cost_paid_api: Dictionary = item.get("cost_paid", {})
	var res_before_cancel := _sum(v["resources"])
	var cancel := API.cancel_build(v, int(item.get("id", -1)), st)
	_check(bool(cancel.get("ok", false)), "İptal başarılı")
	_check_eq(_sum(cancel.get("refunded", {})), _sum(cost_paid_api), "İptal → taban maliyet iade edildi")
	_check_eq(_sum(cancel.get("refunded_extra", {})), 0, "İptal → ek maliyet iade edilmedi")
	_check_eq(_sum(v["resources"]), res_before_cancel + _sum(cost_paid_api), "Kaynak taban maliyet kadar arttı")
	_check_eq(API.queued_items(v, st).size(), 0, "İptal sonrası kuyruk boş")


# =============================================================================
#  (h) GameLoop
# =============================================================================

func _test_game_loop(gd: Node) -> void:
	print("\n-- (h) GameLoop (§7b) --")
	var script = load(GAMELOOP_PATH)
	if script == null:
		_check(false, "GameLoop.gd yüklenemedi")
		return
	var loop: Node = script.new()
	root.add_child(loop)

	_check(loop.module_count() >= 1, "GameLoop en az 1 modül yükledi (ekonomi)")
	var paths: Array = loop.loaded_module_paths()
	_check(paths.has("res://scripts/sim/economy/EconomySimulator.gd"), "EconomySimulator yüklendi")
	_check_eq(paths.size(), loop.module_count(), "module_count ile loaded_module_paths tutarlı")
	var all_exist := true
	for p in paths:
		if not ResourceLoader.exists(str(p)):
			all_exist = false
	_check(all_exist, "Var olmayan modül yolları sessizce atlandı (yüklenenlerin hepsi mevcut)")

	# GameState'e bir köy koy ve bir tick işle.
	var gs := root.get_node_or_null("GameState")
	if gs == null:
		_check(false, "GameState bulunamadı")
		loop.queue_free()
		return
	gs.reset()
	var v := VM.create(1, "Döngü", 5, 5, "Oyuncu", false)
	v["resources"] = {"wood": 0, "stone": 0, "iron": 0}
	gs.add_village(v)
	gs.set_active_village(1)

	loop.set_now_unix(T0)
	var events: Array = loop.simulate(3600.0)
	_check(typeof(events) == TYPE_ARRAY, "simulate() olay dizisi döndürdü")
	var stored: Dictionary = gs.get_village(1)
	_check_eq(int(stored["resources"]["wood"]), int(RE.production_per_hour("wood", 1)), "GameLoop tick'i üretimi GameState'e yazdı")

	# Kuyruk → tamamlanma olayı EventBus'a iletildi mi?
	var st := {"villages": gs.villages, "queues": gs.queues, "world": gs.world}
	VM.set_building_level(stored, "main", 1)
	stored["resources"] = {"wood": 500000, "stone": 500000, "iron": 500000}
	VM.set_building_level(stored, "storage", 50)
	API.start_build(stored, "main", st)
	var got := {"count": 0}
	var cbfn: Callable = func(vid, key, level): got["count"] = int(got["count"]) + 1
	var bus := root.get_node_or_null("EventBus")
	if bus == null:
		_check(false, "EventBus bulunamadı")
		loop.queue_free()
		return
	bus.building_completed.connect(cbfn)
	loop.simulate(100000.0)
	bus.building_completed.disconnect(cbfn)
	_check(int(got["count"]) >= 1, "building_completed olayı EventBus'a iletildi")

	loop.queue_free()
