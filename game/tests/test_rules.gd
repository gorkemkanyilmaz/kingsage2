extends SceneTree
## test_rules.gd — Kural Motoru + Köy Modeli testleri (A-MOTOR).
##
## Çalıştırma (headless):
##   godot --headless --path game --script res://tests/test_rules.gd
##
## Not: `--script` modunda autoload global tanımlayıcıları (GameData, GameConfig)
## **çözülmez**; bu yüzden veriye sahne ağacı kökünden erişilir. `RulesEngine` /
## `VillageModel` global sınıf adları da yüklenmemiş olabileceğinden **preload**
## ile alınır.
##
## Başarısızlıkta `quit(1)` ile çıkar (CI uyumlu).

const RE := preload("res://scripts/rules/RulesEngine.gd")
const VM := preload("res://scripts/model/VillageModel.gd")

var _passed := 0
var _failed := 0
var _fail_labels: Array = []


# --- altyapı -----------------------------------------------------------------

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


func _max_buildings(gd: Node) -> Dictionary:
	var out := {}
	for key in gd.get_all_building_keys():
		out[str(key)] = int(gd.get_max_level(str(key)))
	return out


func _has_req(arr: Array, building: String, level: int) -> bool:
	for r in arr:
		if str(r.get("building", "")) == building and int(r.get("level", -1)) == level:
			return true
	return false


func _chain_keys(chain: Array) -> Array:
	var out := []
	for e in chain:
		out.append(str(e.get("key", "")))
	return out


func _find_entry(chain: Array, key: String) -> Dictionary:
	for e in chain:
		if str(e.get("key", "")) == key:
			return e
	return {}


## Zincirde her düğüm, (zincirde geçen) tüm önkoşullarından **sonra** mı?
func _is_topological(gd: Node, chain: Array) -> bool:
	var pos := {}
	for i in range(chain.size()):
		pos[str(chain[i].get("key", ""))] = i
	for i in range(chain.size()):
		var key := str(chain[i].get("key", ""))
		for r in RE.requirements(key, 1):
			var b := str(r.get("building", ""))
			if pos.has(b) and int(pos[b]) > i:
				return false
	return true


# --- ana akış ----------------------------------------------------------------

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

	print("=== Kural Motoru Testleri (A-MOTOR) ===")
	print("Veri: ", gd.summary())

	_test_costs_exact(gd)
	_test_requirements(gd)
	_test_requirement_chain(gd)
	_test_points(gd)
	_test_production_capacity(gd)
	_test_units(gd)
	_test_village_model(gd)
	_test_time_and_queue(gd)

	print("")
	print("==================== ÖZET ====================")
	print("PASS: %d   FAIL: %d" % [_passed, _failed])
	if _failed > 0:
		print("Başarısız testler:")
		for label in _fail_labels:
			print("  - ", label)
	print("==============================================")
	quit(1 if _failed > 0 else 0)


# --- 1) Maliyet birebirliği --------------------------------------------------

func _test_costs_exact(gd: Node) -> void:
	print("\n-- Maliyet birebirliği (data/buildings.json) --")
	var keys: Array = gd.get_all_building_keys()
	_check_eq(keys.size(), 15, "Bina sayısı = 15")

	var errors := 0
	var checks := 0
	for key in keys:
		var k := str(key)
		var maxl := int(gd.get_max_level(k))
		for lv in range(1, maxl + 1):
			var c := RE.cost(k, lv)
			var row: Dictionary = gd.get_building_level(k, lv)
			for r in ["wood", "stone", "iron"]:
				checks += 1
				if int(c.get(r, -1)) != int(row.get(r, -2)):
					errors += 1
					if errors <= 10:
						print("   ! %s L%d %s: rules=%s data=%s" % [k, lv, r, str(c.get(r)), str(row.get(r))])
	_check_eq(errors, 0, "cost() == buildings.json (hata 0; %d bina × seviye × 3 kaynak = %d kontrol)" % [keys.size(), checks])
	_check_eq(RE.cost("barracks", 1), {"wood": 180, "stone": 180, "iron": 120}, "Kışla L1 maliyeti")
	_check_eq(RE.cost("statue", 1), {"wood": 400000, "stone": 400000, "iron": 400000}, "Anıt L1 maliyeti")
	_check_eq(RE.cost_sum("wood", 0, 1), RE.cost("wood", 1), "cost_sum(0→1) == cost(1)")
	var s13 := RE.cost_sum("wood", 1, 3)
	var e13 := _add(RE.cost("wood", 2), RE.cost("wood", 3))
	_check_eq(s13, e13, "cost_sum(1→3) == cost(2)+cost(3)")


func _add(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := {}
	for k in a.keys():
		out[k] = int(a[k]) + int(b.get(k, 0))
	return out


# --- 2) Gereksinimler --------------------------------------------------------

func _test_requirements(gd: Node) -> void:
	print("\n-- Gereksinimler (can_build / missing_requirements) --")
	# Kışla ← Depo 3 + Değirmen 3
	var miss := RE.missing_requirements({}, "barracks", 3)
	_check_eq(miss.size(), 2, "Kışla eksik önkoşul sayısı = 2")
	_check(_has_req(miss, "storage", 3), "Kışla için Depo 3 eksik")
	_check(_has_req(miss, "farm", 3), "Kışla için Değirmen 3 eksik")
	_check(not RE.can_build({}, "barracks", 1), "Kışla önkoşulsuz inşa edilemez")
	_check(not RE.can_build({"storage": 3}, "barracks", 1), "Kışla: sadece Depo 3 yetmez")
	_check(RE.can_build({"storage": 3, "farm": 3}, "barracks", 1), "Kışla: Depo 3 + Değirmen 3 → inşa edilebilir")
	_check(RE.missing_requirements({"storage": 3, "farm": 3}, "barracks", 1).is_empty(), "Kışla: eksik önkoşul yok")

	# Sur ← Kışla 1
	var miss_wall := RE.missing_requirements({}, "wall", 1)
	_check(_has_req(miss_wall, "barracks", 1), "Sur için Kışla 1 eksik")
	_check(RE.can_build({"barracks": 1}, "wall", 1), "Sur: Kışla 1 → inşa edilebilir")

	# Gizli Depo ← Değirmen 3
	_check(not RE.can_build({"farm": 2}, "hide", 1), "Gizli Depo: Değirmen 2 yetmez")
	_check(RE.can_build({"farm": 3}, "hide", 1), "Gizli Depo: Değirmen 3 → inşa edilebilir")

	# Market ← Depo 5 ; Katır çiftliği ← Market 1 ; Simyager ← Kışla 5 ; Köşk ← Simyager 5 ; Kuyumcu ← Köşk 1
	_check(RE.can_build({"storage": 5}, "market", 1), "Market: Depo 5 → inşa edilebilir")
	_check(RE.can_build({"market": 1}, "stable", 1), "Katır çiftliği: Market 1 → inşa edilebilir")
	_check(RE.can_build({"barracks": 5}, "garage", 1), "Simyager: Kışla 5 → inşa edilebilir")
	_check(RE.can_build({"garage": 5}, "snob", 1), "Köşk: Simyager 5 → inşa edilebilir")
	_check(RE.can_build({"snob": 1}, "smith", 1), "Kuyumcu: Köşk 1 → inşa edilebilir")

	# Anıt ← TÜM binalar maksimum
	var full := _max_buildings(gd)
	var partial := full.duplicate(true)
	partial["barracks"] = int(gd.get_max_level("barracks")) - 1
	_check(not RE.can_build(partial, "statue", 1), "Anıt: bir bina 1 eksikse inşa edilemez")
	_check_eq(RE.requirements("statue", 1).size(), 14, "Anıt önkoşulu = 14 bina")
	_check(RE.can_build(full, "statue", 1), "Anıt: tüm binalar maksimum → inşa edilebilir")

	# Serbest başlangıç
	_check(RE.is_free_start("main") and RE.is_free_start("farm") and RE.is_free_start("storage"), "Serbest başlangıç binaları (Kale/Değirmen/Depo)")
	_check(not RE.is_free_start("barracks"), "Kışla serbest başlangıç değil")
	_check(RE.can_build({}, "main", 1), "Kale: serbest inşa edilebilir")

	# Maksimum seviye sınırı
	_check(not RE.can_build(full, "wall", 21), "Sur: maks. seviye (20) üstü reddedilir")
	_check(not RE.can_build({}, "bilinmeyen", 1), "Bilinmeyen bina reddedilir")


# --- 3) Gereksinim zinciri ---------------------------------------------------

func _test_requirement_chain(gd: Node) -> void:
	print("\n-- Gereksinim zinciri (zaman sıralı) --")
	# Kışla 3 ← Depo 3, Değirmen 3 (örnek: docs/19 §4.1)
	var chain := RE.requirement_chain({}, "barracks", 3)
	_check_eq(_chain_keys(chain), ["storage", "farm", "barracks"], "Kışla zinciri sırası: Depo → Değirmen → Kışla")
	_check_eq(int(_find_entry(chain, "storage").get("level", 0)), 3, "Zincir hedefi: Depo 3")
	_check_eq(int(_find_entry(chain, "farm").get("level", 0)), 3, "Zincir hedefi: Değirmen 3")
	_check_eq(int(_find_entry(chain, "barracks").get("level", 0)), 3, "Zincir hedefi: Kışla 3")
	_check_eq(int(_find_entry(chain, "farm").get("current", -1)), 0, "Zincir 'current' alanı (Değirmen 0)")
	_check(_is_topological(gd, chain), "Kışla zinciri topolojik")

	# Zincir, mevcut seviyeleri de doğru raporlar
	var chain2 := RE.requirement_chain({"storage": 2, "farm": 3}, "barracks", 3)
	_check_eq(int(_find_entry(chain2, "storage").get("current", -1)), 2, "Zincir 'current' (Depo 2)")
	_check_eq(int(_find_entry(chain2, "farm").get("current", -1)), 3, "Zincir 'current' (Değirmen 3)")

	# Sur 1 → Kışla 1 → Depo 3 + Değirmen 3 (geçişli zincir EKSİKSİZ olmalı)
	var wall_chain := RE.requirement_chain({}, "wall", 1)
	_check_eq(_chain_keys(wall_chain).size(), 4, "Sur zinciri 4 düğüm (Depo, Değirmen, Kışla, Sur)")
	_check(_has_node(wall_chain, "storage") and _has_node(wall_chain, "farm") and _has_node(wall_chain, "barracks") and _has_node(wall_chain, "wall"), "Sur zinciri eksiksiz (geçişli önkoşullar)")
	_check_eq(str(wall_chain[wall_chain.size() - 1].get("key", "")), "wall", "Sur zincirin sonunda")
	_check(_is_topological(gd, wall_chain), "Sur zinciri topolojik")

	# Anıt → 15 bina (14 önkoşul + Anıt)
	var schain := RE.requirement_chain({}, "statue", 1)
	_check_eq(schain.size(), 15, "Anıt zinciri 15 düğüm")
	_check_eq(str(schain[schain.size() - 1].get("key", "")), "statue", "Anıt zincirin sonunda")
	_check(_is_topological(gd, schain), "Anıt zinciri topolojik")

	# Serbest bina → yalnızca kendisi
	var main_chain := RE.requirement_chain({}, "main", 5)
	_check_eq(_chain_keys(main_chain), ["main"], "Kale zinciri yalnızca kendisi")

	_check(RE.requirement_chain({}, "bilinmeyen", 1).is_empty(), "Bilinmeyen bina → boş zincir")


func _has_node(chain: Array, key: String) -> bool:
	for e in chain:
		if str(e.get("key", "")) == key:
			return true
	return false


# --- 4) Puan ----------------------------------------------------------------

func _test_points(gd: Node) -> void:
	print("\n-- Puanlar --")
	var full := _max_buildings(gd)
	_check_eq(RE.village_points(full), 10000, "Tam gelişmiş köy puanı = 10000")
	_check_eq(RE.points_for("main", 50), 1000, "Kale L50 puanı = 1000")
	_check_eq(RE.points_for("statue", 1), 1000, "Anıt puanı = 1000")
	_check_eq(RE.points_for("farm", 50), 500, "Değirmen L50 puanı = 500")
	_check_eq(RE.points_for("wall", 20), 400, "Sur L20 puanı = 400")
	_check_eq(RE.points_for("main", 1), 20, "Kale L1 puanı = 20")

	_check_eq(RE.total_points([{"buildings": full}]), 10000, "Toplam puan (tek köy) = 10000")
	_check_eq(RE.total_points([]), 0, "Toplam puan (köy yok) = 0")
	var second := {"buildings": {"main": 1}}
	var two := RE.total_points([{"buildings": full}, second])
	_check_eq(two, 10000 + RE.village_points(second.get("buildings", {})) + 2500, "Toplam puan (2 köy) = Σ + 2500")


# --- 5) Üretim / kapasite / nüfus / sur -------------------------------------

func _test_production_capacity(gd: Node) -> void:
	print("\n-- Üretim / kapasite / nüfus / sur --")
	_check_eq(RE.storage_capacity(1), 1000, "Depo kapasitesi L1 = 1000")
	_check_eq(RE.storage_capacity(50), 950000, "Depo kapasitesi L50 = 950000")
	_check_eq(RE.hideout_capacity(30), 23278, "Gizli Depo kapasitesi L30 = 23278")
	_check_eq(RE.hideout_capacity(1), 150, "Gizli Depo kapasitesi L1 = 150")
	_check_eq(RE.max_population(50), 50000, "Maksimum vatandaş L50 = 50000")
	_check_eq(RE.max_population(1), 250, "Maksimum vatandaş L1 = 250")
	_check_eq(RE.donkey_capacity(30), 600, "Katır kapasitesi (Market L30) = 600")
	_check_eq(RE.donkey_capacity(1), 1, "Katır kapasitesi (Market L1) = 1")

	_check_eq(RE.wall_bonus_percent(0), 100, "Sur bonusu (sur yok) = 100")
	_check_eq(RE.wall_bonus_percent(1), 105, "Sur bonusu L1 = 105")
	_check_eq(RE.wall_bonus_percent(20), 220, "Sur bonusu L20 = 220")

	_check_eq(RE.production_per_hour("wood", 1), 120.0, "Odun üretimi L1 = 120/saat")
	_check_eq(RE.production_per_hour("stone", 10), 319.0, "Taş üretimi L10 = 319/saat")
	_check_eq(RE.production_per_hour("iron", 50), 24800.0, "Demir üretimi L50 = 24800/saat")
	_check_eq(RE.production_per_hour("farm", 5), 0.0, "Üretim olmayan bina = 0")
	_check_eq(RE.donkey_production_per_hour(30), 2000.0, "Katır üretimi L30 = 2000/saat")


# --- 6) Birimler ------------------------------------------------------------

func _test_units(gd: Node) -> void:
	print("\n-- Birimler --")
	_check_eq(RE.unit_cost("axe", 3), {"wood": 150, "stone": 120, "iron": 150}, "Baltacı 3× eğitim maliyeti")
	_check_eq(RE.unit_cost("snob", 1), {"wood": 120000, "stone": 100000, "iron": 80000}, "Kont 1× eğitim maliyeti")
	_check_eq(RE.unit_settlers("spy"), 2, "Casus vatandaşı = 2")
	_check_eq(RE.unit_settlers("snob"), 100, "Kont vatandaşı = 100")
	_check_eq(RE.unit_speed("spy"), 2, "Casus yavaşlık faktörü = 2")
	_check_eq(RE.unit_speed("ram"), 8, "Şahmerdan yavaşlık faktörü = 8")
	_check(RE.unit_speed("spy") < RE.unit_speed("ram"), "Casus, Şahmerdan'dan hızlı")
	_check_eq(RE.unit_carry("light"), 80, "Akıncı taşıma = 80")
	_check_eq(RE.unit_carry("spy"), 0, "Casus taşıma = 0")

	var cb := RE.unit_combat("heavy")
	_check_eq(int(cb.get("attack", 0)), 600, "Kara Şövalye saldırı = 600")
	_check_eq(int(cb.get("def_inf", 0)), 1500, "Kara Şövalye piyade savunması = 1500")
	_check_eq(int(cb.get("def_cav", 0)), 1000, "Kara Şövalye süvari savunması = 1000")
	_check_eq(int(cb.get("def_arch", 0)), 1000, "Kara Şövalye okçu savunması = 1000")

	_check_eq(RE.research_requirement("farmer"), 1, "Köy Koruyucusu araştırma: Kışla L1")
	_check_eq(RE.research_requirement("bow"), 5, "Okçu araştırma: Kışla L5")
	_check_eq(RE.research_requirement("kata"), 25, "Mancınık araştırma: Kışla L25")
	_check_eq(RE.research_requirement("snob"), 0, "Kont araştırılmaz (0)")

	_check(RE.is_researched({"barracks": 4}, "bow") == false, "Okçu Kışla L4'te araştırılmamış")
	_check(RE.is_researched({"barracks": 5}, "bow") == true, "Okçu Kışla L5'te araştırılmış")
	_check(RE.can_research({"barracks": 25}, "kata") == true, "Mancınık Kışla L25'te araştırılabilir")
	_check(RE.can_research({"barracks": 30}, "snob") == false, "Kont araştırılamaz")

	_check_eq(RE.research_cost("farmer"), {"wood": 10, "stone": 10, "iron": 10}, "Köy Koruyucusu araştırma maliyeti")
	_check_eq(RE.research_cost("snob"), {}, "Kont araştırma maliyeti yok")
	_check(RE.research_seconds("sword") > 0.0, "Muhafız araştırma süresi > 0")
	_check(RE.research_seconds("snob") == 0.0, "Kont araştırma süresi = 0")
	_check(RE.training_seconds("spear", 10) > RE.training_seconds("spear", 1), "Eğitim süresi adetle artar")
	_check(RE.training_seconds("snob", 1) > 0.0, "Kont eğitim süresi > 0")

	_check_eq(RE.min_attack_units(5), 15, "Min. saldırı birimi = 3 × Kışla(5)")
	_check_eq(RE.min_attack_units(0), 0, "Min. saldırı birimi = 0 (Kışla yok)")


# --- 7) Köy modeli -----------------------------------------------------------

func _test_village_model(gd: Node) -> void:
	print("\n-- Köy modeli (VillageModel) --")
	var v := VM.create(1, "Başkent", 100, 100, "Oyuncu", false)
	_check_eq(int(v.get("id", -1)), 1, "Köy id")
	_check_eq(str(v.get("name", "")), "Başkent", "Köy adı")
	_check_eq(int(v.get("x", -1)), 100, "Köy x")
	_check_eq(bool(v.get("is_bot", true)), false, "Köy is_bot")
	_check_eq(VM.building_level(v, "main"), 1, "Başkent: Kale L1")
	_check_eq(VM.building_level(v, "wood"), 1, "Başkent: Oduncu Kampı L1")
	_check_eq(VM.building_level(v, "barracks"), 0, "Başkent: Kışla L0")
	_check(not VM.is_developed(v), "Yeni köy tam gelişmiş değil")
	_check(not VM.has_statue(v), "Yeni köyde Anıt yok")

	var used := VM.population_used(v)
	_check(used > 0, "Yeni köyde çalışan vatandaş > 0")
	_check_eq(VM.population_free(v), RE.max_population(1) - used, "Boş vatandaş = Değirmen tavanı − bağlı")

	# Seviye ayarlama + türetilmiş alanlar
	var fv := v.duplicate(true)
	for key in gd.get_all_building_keys():
		VM.set_building_level(fv, str(key), int(gd.get_max_level(str(key))))
	_check(VM.is_developed(fv), "Tüm binalar maksimum → is_developed")
	_check(VM.has_statue(fv), "Tam gelişmiş köyde Anıt var")
	_check_eq(int(fv.get("points", -1)), 10000, "set_building_level puanı tazeler (10000)")
	_check_eq(RE.village_points(fv.get("buildings")), 10000, "Tam gelişmiş köy puanı = 10000")

	# Anıt seviyesinden türetme (alan olmadan)
	var sv := VM.create(2, "Test", 0, 0, "Bot", true)
	VM.set_building_level(sv, "statue", 1)
	_check(VM.has_statue(sv), "has_statue: statue L1'den türetildi")


# --- 8) Süre ve kuyruk -------------------------------------------------------

func _test_time_and_queue(gd: Node) -> void:
	print("\n-- Süre ve inşaat kuyruğu --")
	_check_eq(RE.queue_slots_free(), 3, "Ücretsiz kuyruk işi = 3")
	_check_eq(RE.queue_extra_cost_percent(0), 0, "Kuyruk 1. iş ek maliyet = 0")
	_check_eq(RE.queue_extra_cost_percent(1), 0, "Kuyruk 2. iş ek maliyet = 0")
	_check_eq(RE.queue_extra_cost_percent(2), 0, "Kuyruk 3. iş ek maliyet = 0")
	_check_eq(RE.queue_extra_cost_percent(3), 25, "Kuyruk 4. iş ek maliyet = 25")
	_check_eq(RE.queue_extra_cost_percent(4), 56, "Kuyruk 5. iş ek maliyet = 56")

	var bs1 := RE.build_seconds("wood", 1)
	var bs20 := RE.build_seconds("wood", 20)
	_check(typeof(bs1) == TYPE_FLOAT, "build_seconds float döndürür")
	_check(bs1 > 0.0 and bs20 > 0.0, "İnşaat süresi > 0")
	_check_eq(RE.build_seconds("wood", 0), 0.0, "Seviye 0 → inşaat süresi 0")
