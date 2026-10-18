extends SceneTree
## Dünya / harita testleri — Taht ve Kılıç / **A-DUNYA** (SceneTree tabanlı).
##
## Çalıştırma:
## ```
## & $godot --headless --path '.\game' --script res://tests/test_world.gd
## ```
## Kapsam (`docs/19` §3.1/§5/§6, §8):
##  (a) aynı tohum → **aynı dünya** (hash eşit)   (b) farklı tohum → farklı dünya
##  (c) 200×200 sınırları içinde                  (d) koordinat çakışması yok
##  (e) `bot_count` kadar bot köyü                (f) bina seviyeleri geçerli (maks. aşımı yok)
##  (g) `travel_seconds` simetrik ve monoton
##  (h) **bonus köyler**: resmî 6 tip + sahibi 'Usta'
##  (i) **terkedilmiş köyler**: gelişmiş binalar + dolu `units` (soyguncular)
##  (j) `realm_of_power == points` (tüm köyler)   (k) kıta etiketleri (K00/K01/K10/K11, 499|506→K54)
## Başarısızlıkta `quit(1)`.
##
## **Negatif (kendi kendini sınama):** `FAIL` yolunu kanıtlamak için
## ```
## & $godot --headless --path '.\game' --script res://tests/test_world.gd -- force-fail
## ```
## → 1 kasıtlı hata üretir ve `EXIT=1` ile çıkar.

const WorldModelScript := preload("res://scripts/world/WorldModel.gd")
const WorldGeneratorScript := preload("res://scripts/world/WorldGenerator.gd")
const TravelScript := preload("res://scripts/world/Travel.gd")

const TEST_SEED := 4242
const OTHER_SEED := 9999
const TEST_BOT_COUNT := 100
const WORLD_SIZE := 200

## `docs/19` §3.1 köy şekli — **17 alan**.
const VILLAGE_FIELDS := [
	"id", "name", "x", "y", "owner", "is_bot", "is_barbarian", "buildings", "resources",
	"units", "researched", "realm_of_power", "points", "protection_until",
	"conquest_protection_until", "bonus_type", "has_statue",
]

var _pass := 0
var _fail := 0
var _failures: Array = []
var _game_data: Node = null


func _initialize() -> void:
	_prepare_data()
	print("=== Taht ve Kılıç — WorldModel testleri (A-DUNYA) ===")
	print("Godot %s · tohum=%d · bot=%d" % [Engine.get_version_info().get("string", "?"), TEST_SEED, TEST_BOT_COUNT])
	print("")

	var world: Dictionary = WorldModelScript.generate_world(TEST_SEED, TEST_BOT_COUNT)

	_test_constants()
	_test_bounds(world)
	_test_determinism()
	_test_different_seed()
	_test_no_collision(world)
	_test_counts(world)
	_test_barbarian_villages(world)
	_test_bonus_villages(world)
	_test_bonus_effects(world)
	_test_buildings(world)
	_test_resources_points_units(world)
	_test_contract_shape(world)
	_test_distance_and_travel()
	_test_travel_helpers()
	_test_find_free_spot(world)
	_test_neighbors(world)
	_test_minimap(world)
	_test_continents(world)
	_test_player_village(world)
	_test_movement_helpers()
	_test_edge_cases()
	_test_data_agreement()
	_test_rules_engine_alignment(world)
	_test_negative_path()

	_print_world_summary(world)
	_print_summary()
	quit(0 if _fail == 0 else 1)


## `-- force-fail` ile çağrılırsa kasıtlı bir hata üretir (FAIL → `quit(1)` yolunu kanıtlar).
func _test_negative_path() -> void:
	if not OS.get_cmdline_user_args().has("force-fail"):
		return
	_section("Negatif test (kasıtlı)")
	_check("kasıtlı başarısızlık → FAIL sayacı ve quit(1)",
		OS.get_cmdline_user_args().has("asla-gerçekleşmez"),
		"force-fail istendi")


# --- Hazırlık ---------------------------------------------------------------

func _prepare_data() -> void:
	# `--script` modunda autoload'ların `_ready()`'si `_initialize()`'tan sonra çalışabilir;
	# veri katmanını açıkça yüklüyoruz.
	_game_data = get_root().get_node_or_null(^"GameData")
	if _game_data != null and _game_data.has_method("load_all"):
		_game_data.load_all(true)


# --- Testler ----------------------------------------------------------------

func _test_constants() -> void:
	_section("Sabitler ve veri uyumu")
	_check("WorldModel.SIZE == 200", WorldModelScript.SIZE == WORLD_SIZE, "SIZE=%d" % WorldModelScript.SIZE)
	_check("WorldGenerator.SIZE == WorldModel.SIZE",
		WorldGeneratorScript.SIZE == WorldModelScript.SIZE,
		"gen=%d" % WorldGeneratorScript.SIZE)
	_check("kıta sabiti tutarlı",
		WorldGeneratorScript.CONTINENT_SIZE == WorldModelScript.CONTINENT_SIZE,
		"CONTINENT_SIZE=%d" % WorldModelScript.CONTINENT_SIZE)
	_check("15 bina anahtarı", WorldGeneratorScript.BUILDING_KEYS.size() == 15,
		"n=%d" % WorldGeneratorScript.BUILDING_KEYS.size())
	_check("11 birim anahtarı", WorldGeneratorScript.UNIT_KEYS.size() == 11,
		"n=%d" % WorldGeneratorScript.UNIT_KEYS.size())
	_check("6 resmî bonus tipi", WorldGeneratorScript.BONUS_TYPES.size() == 6,
		"%s" % [WorldGeneratorScript.BONUS_TYPES])
	_check("başlangıç puanı 110", WorldGeneratorScript.starting_points() == 110,
		"points=%d" % WorldGeneratorScript.starting_points())
	_check("§3.1 köy şekli 17 alan", VILLAGE_FIELDS.size() == 17, "n=%d" % VILLAGE_FIELDS.size())


func _test_bounds(world: Dictionary) -> void:
	_section("(c) Dünya boyutu ve koordinat sınırları")
	_check("size == 200", int(world.get("size", 0)) == WORLD_SIZE, "size=%s" % world.get("size"))
	var outside: Array = []
	for village in WorldModelScript.villages_of(world):
		var x := int(village.get("x", 0))
		var y := int(village.get("y", 0))
		if x < 1 or x > WORLD_SIZE or y < 1 or y > WORLD_SIZE:
			outside.append("%d|%d" % [x, y])
	_check("tüm köyler 1..200 içinde", outside.is_empty(), "ihlal=%d" % outside.size())
	_check("'tiles' anahtarları sınır içinde [örnek 5]",
		_strictly_inside(world, 5), "kontrol edilen=%d" % mini(5, WorldModelScript.tiles_of(world).size()))


func _test_determinism() -> void:
	_section("(a) Determinizm — aynı tohum → aynı dünya")
	var first: Dictionary = WorldModelScript.generate_world(TEST_SEED, TEST_BOT_COUNT)
	var second: Dictionary = WorldModelScript.generate_world(TEST_SEED, TEST_BOT_COUNT)
	var hash_first := WorldModelScript.world_hash(first)
	var hash_second := WorldModelScript.world_hash(second)
	_check("hash eşit", hash_first == hash_second, hash_first.substr(0, 16) + "…")
	_check("dünyalar birebir eşit", first == second, "köy=%d" % WorldModelScript.villages_of(first).size())
	var names_a: Array = []
	for village in WorldModelScript.villages_of(first):
		names_a.append(village.get("name"))
	var names_b: Array = []
	for village in WorldModelScript.villages_of(second):
		names_b.append(village.get("name"))
	_check("köy adları da aynı", names_a == names_b, "ilk=%s" % (names_a[0] if not names_a.is_empty() else "-"))
	# Üçüncü üretim: tohum aynı, nesne farklı → yine aynı
	var third: Dictionary = WorldModelScript.generate_world(TEST_SEED, TEST_BOT_COUNT)
	_check("üçüncü üretim de aynı hash",
		WorldModelScript.world_hash(third) == hash_first,
		WorldModelScript.world_hash(third).substr(0, 16) + "…")


func _test_different_seed() -> void:
	_section("(b) Farklı tohum → farklı dünya")
	var a: Dictionary = WorldModelScript.generate_world(TEST_SEED, TEST_BOT_COUNT)
	var b: Dictionary = WorldModelScript.generate_world(OTHER_SEED, TEST_BOT_COUNT)
	_check("hash farklı", WorldModelScript.world_hash(a) != WorldModelScript.world_hash(b))
	var coords_a: Array = []
	for village in WorldModelScript.villages_of(a):
		coords_a.append("%d|%d" % [village.get("x"), village.get("y")])
	var coords_b: Array = []
	for village in WorldModelScript.villages_of(b):
		coords_b.append("%d|%d" % [village.get("x"), village.get("y")])
	_check("yerleşimler farklı", coords_a != coords_b,
		"ortak=%d" % _intersection_count(coords_a, coords_b))


func _test_no_collision(world: Dictionary) -> void:
	_section("(d) Koordinat çakışması yok / 'tiles' tutarlı")
	var seen: Dictionary = {}
	var collisions: Array = []
	for village in WorldModelScript.villages_of(world):
		var key := WorldModelScript.tile_key(int(village.get("x", 0)), int(village.get("y", 0)))
		if seen.has(key):
			collisions.append(key)
		seen[key] = true
	_check("aynı konuma iki köy yok", collisions.is_empty(), "çakışma=%d" % collisions.size())
	_check("'tiles' sayısı == köy sayısı",
		WorldModelScript.tiles_of(world).size() == WorldModelScript.villages_of(world).size(),
		"tiles=%d köy=%d" % [WorldModelScript.tiles_of(world).size(), WorldModelScript.villages_of(world).size()])
	var mismatched := 0
	for village in WorldModelScript.villages_of(world):
		var x := int(village.get("x", 0))
		var y := int(village.get("y", 0))
		if WorldModelScript.village_id_at(world, x, y) != int(village.get("id", -1)):
			mismatched += 1
	_check("'tiles' → köy id eşleşiyor", mismatched == 0, "uyuşmaz=%d" % mismatched)


func _test_counts(world: Dictionary) -> void:
	_section("(e) Bot köyü sayısı")
	var counts: Dictionary = WorldModelScript.count_kinds(world)
	_check("bot köyü == bot_count (%d)" % TEST_BOT_COUNT,
		int(counts.get("bot", 0)) == TEST_BOT_COUNT,
		"bulunan=%d" % counts.get("bot", 0))
	_check("is_bot bayrağı sayısı da %d" % TEST_BOT_COUNT,
		WorldModelScript.villages_of_kind(world, "bot").size() == TEST_BOT_COUNT)
	_check("toplam köy == 210 (100 bot + 100 terkedilmiş + 10 bonus)",
		int(counts.get("total", 0)) == 210, "total=%d" % counts.get("total", 0))
	_check("id'ler tekil ve pozitif", _ids_unique(world))


func _test_barbarian_villages(world: Dictionary) -> void:
	_section("Terkedilmiş (soyguncu) köyler — resmî: bina inşa eder + askerî birim üretir")
	var barbarians: Array = WorldModelScript.villages_of_kind(world, "barbarian")
	_check("terkedilmiş köyler var", barbarians.size() > 0, "n=%d" % barbarians.size())

	var flags_ok := true
	var empty_garrison := 0
	var developed := 0
	var tier_ok := true
	var garrison_ok := true
	var forbidden_units := 0
	var points_sum := 0
	var tiers: Dictionary = {}
	for village in barbarians:
		if bool(village.get("is_bot", true)) or str(village.get("owner", "?")) != WorldGeneratorScript.BARBARIAN_OWNER:
			flags_ok = false
		if int(village.get("protection_until", -1)) != 0:
			flags_ok = false
		if not bool(village.get("is_barbarian", false)):
			flags_ok = false

		var buildings: Dictionary = village.get("buildings", {})
		# Soyguncular bina inşa eder → en az bir bina sv 1'in üstünde.
		var is_developed := false
		for key in WorldGeneratorScript.BUILDING_KEYS:
			if int(buildings.get(key, 0)) > 1:
				is_developed = true
		if is_developed:
			developed += 1
		# Kademe: çekirdek binalar eşit seviyede ve 1..BARBARIAN_MAX_TIER.
		var tier := int(buildings.get("main", 0))
		points_sum += int(village.get("points", 0))
		tiers[tier] = true
		if tier < 1 or tier > WorldGeneratorScript.BARBARIAN_MAX_TIER:
			tier_ok = false
		for key in ["main", "stone", "wood", "iron", "farm", "storage", "barracks", "wall", "hide"]:
			if int(buildings.get(key, -1)) != tier:
				tier_ok = false

		# Garnizon: normal 11 birim anahtarı, dolu, Kışla seviyesine uygun.
		var units: Dictionary = village.get("units", {})
		if WorldGeneratorScript.units_total(units) <= 0:
			empty_garrison += 1
		var researched: Dictionary = village.get("researched", {})
		for key in units.keys():
			if int(units[key]) <= 0:
				continue
			if not researched.has(str(key)):
				garrison_ok = false
			if int(WorldGeneratorScript.BARRACKS_REQUIREMENT.get(str(key), 999)) > int(buildings.get("barracks", 0)):
				garrison_ok = false
		for key in ["spy", "ram", "kata", "snob"]:
			if int(units.get(key, 0)) != 0:
				forbidden_units += 1

	_check("sahip 'Soyguncular', is_barbarian=true, is_bot=false, koruma 0", flags_ok)
	_check("terkedilmiş köylerin ordusu dolu (soyguncular birim üretir)", empty_garrison == 0,
		"boş=%d/%d" % [empty_garrison, barbarians.size()])
	_check("terkedilmiş köyler bina inşa etmiş (en az bir köy sv 1'in üstünde)", developed > 0,
		"gelişmiş=%d/%d" % [developed, barbarians.size()])
	var barbarian_avg_points := float(points_sum) / float(maxi(1, barbarians.size()))
	_check("terkedilmiş köyler ortalamada yeni köyden gelişmiş (puan ort. > %d)" % WorldGeneratorScript.starting_points(),
		barbarian_avg_points > float(WorldGeneratorScript.starting_points()),
		"ort=%.0f" % barbarian_avg_points)
	_check("gelişim kademeleri çeşitli (en az 3 farklı seviye)", tiers.size() >= 3,
		"farklı kademe=%d" % tiers.size())
	_check("gelişim kademesi tutarlı (çekirdek binalar eşit, 1..%d)" % WorldGeneratorScript.BARBARIAN_MAX_TIER,
		tier_ok)
	_check("garnizon Kışla seviyesine uygun + 'researched' kapsıyor", garrison_ok)
	_check("soyguncu garnizonunda casus/kuşatma/Kont yok", forbidden_units == 0,
		"ihlal=%d" % forbidden_units)

	# "Gelişmiş köyler daha güçlü": yüksek kademe → ortalama daha çok birim.
	var low_sum := 0
	var low_n := 0
	var high_sum := 0
	var high_n := 0
	for village in barbarians:
		var tier := int((village.get("buildings", {}) as Dictionary).get("main", 0))
		var total := WorldGeneratorScript.units_total(village.get("units", {}))
		if tier <= 3:
			low_sum += total
			low_n += 1
		elif tier >= 8:
			high_sum += total
			high_n += 1
	var low_avg := float(low_sum) / float(maxi(1, low_n))
	var high_avg := float(high_sum) / float(maxi(1, high_n))
	_check("gelişmiş köyler daha güçlü (yüksek kademe ortalaması > düşük)",
		high_n > 0 and low_n > 0 and high_avg > low_avg,
		"düşük ort=%.1f (n=%d) · yüksek ort=%.1f (n=%d)" % [low_avg, low_n, high_avg, high_n])

	# `kind_of` sınıflandırması `bonus_type`/bayraklardan türetilir.
	_check("terkedilmiş köy bonus tipi taşımıyor",
		_all_bonus_type_empty(barbarians))
	_check("count_kinds(barbarian) == bayrak sayısı",
		int(WorldModelScript.count_kinds(world).get("barbarian", 0)) == barbarians.size(),
		"%d / %d" % [WorldModelScript.count_kinds(world).get("barbarian", 0), barbarians.size()])


func _test_bonus_villages(world: Dictionary) -> void:
	_section("Bonus köyler — resmî 6 tip + sahip 'Usta'")
	var bonuses: Array = WorldModelScript.villages_of_kind(world, "bonus")
	_check("bonus köyler var", bonuses.size() > 0, "n=%d" % bonuses.size())

	var types: Dictionary = {}
	var owner_ok := true
	var flag_ok := true
	var typed_count := 0
	for village in WorldModelScript.villages_of(world):
		var bonus_type := WorldModelScript.bonus_type_of(village)
		if not bonus_type.is_empty():
			typed_count += 1
	for village in bonuses:
		var bonus_type := WorldModelScript.bonus_type_of(village)
		if str(village.get("owner", "")) != WorldGeneratorScript.BONUS_OWNER:
			owner_ok = false
		if not WorldGeneratorScript.BONUS_TYPES.has(bonus_type):
			owner_ok = false
		if bool(village.get("is_barbarian", true)) or bool(village.get("is_bot", true)):
			flag_ok = false
		types[bonus_type] = int(types.get(bonus_type, 0)) + 1

	_check("her bonus köyün sahibi 'Usta' ve tipi resmî 6 tipten biri", owner_ok,
		"tipler=%s" % [types.keys()])
	_check("bonus köyde is_barbarian=false, is_bot=false", flag_ok)
	_check("dünyada 6 bonus tipinin tamamı var (round-robin dağıtım)",
		types.size() == WorldGeneratorScript.BONUS_TYPES.size(),
		"bulunan=%d %s" % [types.size(), types.keys()])
	_check("bonus_type dolu köy sayısı == bonus köy sayısı", typed_count == bonuses.size(),
		"%d / %d" % [typed_count, bonuses.size()])
	_check("bonus olmayan köylerde bonus_type == ''", _bonus_type_iff_kind_bonus(world))


func _test_bonus_effects(world: Dictionary) -> void:
	_section("Bonus etkileri — resmî (+%10 / +%3)")
	var wood: Dictionary = WorldGeneratorScript.bonus_production_multipliers("wood")
	_check("'wood': odun ×1.10, taş/demir ×1.00",
		is_equal_approx(float(wood["wood"]), 1.10)
		and is_equal_approx(float(wood["stone"]), 1.0)
		and is_equal_approx(float(wood["iron"]), 1.0),
		"%s" % [wood])
	var production: Dictionary = WorldGeneratorScript.bonus_production_multipliers("production")
	_check("'production': tüm hammaddeler ×1.03",
		is_equal_approx(float(production["wood"]), 1.03)
		and is_equal_approx(float(production["stone"]), 1.03)
		and is_equal_approx(float(production["iron"]), 1.03),
		"%s" % [production])
	_check("bonus yok → ×1.00",
		is_equal_approx(float(WorldGeneratorScript.bonus_production_multipliers("")["wood"]), 1.0))
	_check("'citizen': vatandaş ×1.10 (diğerleri ×1.00)",
		is_equal_approx(WorldGeneratorScript.bonus_citizen_multiplier("citizen"), 1.10)
		and is_equal_approx(WorldGeneratorScript.bonus_citizen_multiplier("wood"), 1.0))
	_check("'training': eğitim hızı ×1.10 (süre bu değere bölünür)",
		is_equal_approx(WorldGeneratorScript.bonus_training_speed_multiplier("training"), 1.10)
		and is_equal_approx(WorldGeneratorScript.bonus_training_speed_multiplier("wood"), 1.0))
	_check("efekt metinleri dolu, bonus yokken boş",
		not WorldGeneratorScript.bonus_effect_text("wood").is_empty()
		and WorldGeneratorScript.bonus_effect_text("").is_empty())
	_check("geçersiz bonus tipi reddedilir",
		not WorldGeneratorScript.is_valid_bonus_type("hile")
		and WorldGeneratorScript.is_valid_bonus_type("")
		and WorldGeneratorScript.is_valid_bonus_type("production"))

	# Köy bazlı sarmalayıcılar tiple tutarlı mı?
	var consistent := true
	for village in WorldModelScript.villages_of_kind(world, "bonus"):
		var bonus_type := WorldModelScript.bonus_type_of(village)
		var multipliers: Dictionary = WorldModelScript.village_production_multipliers(village)
		match bonus_type:
			"wood":
				if not is_equal_approx(float(multipliers["wood"]), 1.10):
					consistent = false
			"stone":
				if not is_equal_approx(float(multipliers["stone"]), 1.10):
					consistent = false
			"iron":
				if not is_equal_approx(float(multipliers["iron"]), 1.10):
					consistent = false
			"production":
				if not is_equal_approx(float(multipliers["wood"]), 1.03):
					consistent = false
			_:
				if not is_equal_approx(float(multipliers["wood"]), 1.0):
					consistent = false
	_check("köy sarmalayıcıları 'bonus_type' ile tutarlı", consistent)
	var wood_villages: Array = WorldModelScript.villages_of_bonus_type(world, "wood")
	var wood_only := true
	for village in wood_villages:
		if WorldModelScript.bonus_type_of(village) != "wood":
			wood_only = false
	# Round-robin: tip i'nin sayısı = ceil(bonus_count / 6) (ilk `bonus_count % 6` tip bir fazla).
	var bonus_total := int(WorldModelScript.count_kinds(world).get("bonus", 0))
	var expected_wood := int(bonus_total / 6) + (1 if bonus_total % 6 > 0 else 0)
	_check("villages_of_bonus_type('wood') yalnızca wood köyleri (round-robin sayısı)",
		wood_only and wood_villages.size() == expected_wood,
		"n=%d beklenen=%d" % [wood_villages.size(), expected_wood])


func _test_buildings(world: Dictionary) -> void:
	_section("(f) Bina şekli ve seviye sınırları")
	var start_keys := ["main", "stone", "wood", "iron", "farm", "storage"]
	var bad_count := 0
	var wrong_type := 0
	var over_max := 0
	var start_ok := 0
	var start_total := 0
	for village in WorldModelScript.villages_of(world):
		var buildings: Dictionary = village.get("buildings", {})
		if buildings.size() != 15:
			bad_count += 1
		for key in WorldGeneratorScript.BUILDING_KEYS:
			if not buildings.has(key):
				bad_count += 1
				continue
			if typeof(buildings[key]) != TYPE_INT:
				wrong_type += 1
				continue
			var level := int(buildings[key])
			var top := WorldModelScript.max_level(key)
			if top > 0 and level > top:
				over_max += 1
		# Yalnızca **bot ve bonus** köyler başlangıç durumundadır (terkedilmişler gelişmiştir).
		if WorldModelScript.kind_of(village) != "barbarian":
			start_total += 1
			var is_start := true
			for key in WorldGeneratorScript.BUILDING_KEYS:
				var expected := 1 if key in start_keys else 0
				if int(buildings.get(key, -1)) != expected:
					is_start = false
			if is_start:
				start_ok += 1
	_check("her köyde 15 bina anahtarı", bad_count == 0, "sorun=%d" % bad_count)
	_check("bina seviyeleri int", wrong_type == 0, "sorun=%d" % wrong_type)
	_check("başlangıç binaları (bot+bonus): main/stone/wood/iron/farm/storage = 1, diğerleri 0",
		start_ok == start_total, "%d/%d" % [start_ok, start_total])
	_check("maks. seviye aşımı yok (terkedilmiş gelişimi dahil)", over_max == 0, "sorun=%d" % over_max)


func _test_resources_points_units(world: Dictionary) -> void:
	_section("Kaynak, puan, güç alanı ve birimler")
	var total := WorldModelScript.villages_of(world).size()
	var resources_ok := 0
	var points_match := 0
	var realm_match := 0
	var bot_units_zero := 0
	var bonus_units_zero := 0
	var bot_count := 0
	var bonus_count := 0
	for village in WorldModelScript.villages_of(world):
		var resources: Dictionary = village.get("resources", {})
		if resources.size() == 3 and int(resources.get("wood", -1)) == 1000 \
				and int(resources.get("stone", -1)) == 1000 and int(resources.get("iron", -1)) == 1000:
			resources_ok += 1
		if int(village.get("points", -1)) == WorldGeneratorScript.village_points(village.get("buildings", {})):
			points_match += 1
		if int(village.get("realm_of_power", -1)) == int(village.get("points", -2)):
			realm_match += 1
		var kind := WorldModelScript.kind_of(village)
		if kind == "bot":
			bot_count += 1
			if _all_zero(village.get("units", {})):
				bot_units_zero += 1
		elif kind == "bonus":
			bonus_count += 1
			if _all_zero(village.get("units", {})):
				bonus_units_zero += 1
	_check("kaynaklar {1000, 1000, 1000}", resources_ok == total, "%d/%d" % [resources_ok, total])
	_check("Köy Puanı == Σ bina puanı (tüm köyler)", points_match == total, "%d/%d" % [points_match, total])
	_check("Güç Alanı == Köy Puanı (tavan) — tüm köyler", realm_match == total, "%d/%d" % [realm_match, total])
	_check("bot köyleri ordusuz başlar (11 anahtar, hepsi 0)", bot_units_zero == bot_count,
		"%d/%d" % [bot_units_zero, bot_count])
	_check("bonus köyler ordusuz başlar (11 anahtar, hepsi 0)", bonus_units_zero == bonus_count,
		"%d/%d" % [bonus_units_zero, bonus_count])


func _test_contract_shape(world: Dictionary) -> void:
	_section("§3.1 köy şekli + validate_world()")
	var missing := 0
	var wrong_researched := 0
	for village in WorldModelScript.villages_of(world):
		for key in VILLAGE_FIELDS:
			if not village.has(key):
				missing += 1
		if typeof(village.get("researched")) != TYPE_DICTIONARY:
			wrong_researched += 1
	_check("17 sözleşme alanı eksiksiz", missing == 0, "eksik=%d" % missing)
	_check("'researched' her köyde sözlük", wrong_researched == 0, "sorun=%d" % wrong_researched)

	# Botlar taze başlar → hiçbir birim araştırılmamış.
	var bot_researched_empty := 0
	var bot_total := 0
	for village in WorldModelScript.villages_of_kind(world, "bot"):
		bot_total += 1
		if (village.get("researched", {}) as Dictionary).is_empty():
			bot_researched_empty += 1
	_check("bot köylerinde 'researched' boş (taze başlangıç)", bot_researched_empty == bot_total,
		"%d/%d" % [bot_researched_empty, bot_total])

	var problems: Array = WorldModelScript.validate_world(world)
	_check("validate_world() sorunsuz", problems.is_empty(),
		"sorun=%d %s" % [problems.size(), problems.slice(0, 3) if not problems.is_empty() else ""])

	var broken: Dictionary = world.duplicate(true)
	var first_village: Dictionary = WorldModelScript.villages_of(broken)[0]
	first_village["buildings"]["main"] = 999
	first_village["x"] = 500
	_check("validate_world() bozuk binayı + koordinatı yakalıyor",
		WorldModelScript.validate_world(broken).size() >= 2,
		"sorun=%d" % WorldModelScript.validate_world(broken).size())

	var broken_bonus: Dictionary = world.duplicate(true)
	var target: Dictionary = WorldModelScript.villages_of(broken_bonus)[0]
	target["bonus_type"] = "hile"
	target["realm_of_power"] = 999999
	_check("validate_world() geçersiz bonus_type + güç alanını yakalıyor",
		WorldModelScript.validate_world(broken_bonus).size() >= 2,
		"sorun=%d" % WorldModelScript.validate_world(broken_bonus).size())


func _test_distance_and_travel() -> void:
	_section("(g) Mesafe ve yolculuk süresi")
	_check("distance(0,0,3,4) == 5", is_equal_approx(WorldModelScript.distance(0, 0, 3, 4), 5.0),
		"%f" % WorldModelScript.distance(0, 0, 3, 4))
	_check("distance simetrik", WorldModelScript.distance(3, 7, 91, 4) == WorldModelScript.distance(91, 4, 3, 7))
	_check("distance aynı nokta == 0", WorldModelScript.distance(11, 12, 11, 12) == 0.0)
	var ab := WorldModelScript.travel_seconds(10, 20, 60, 90, 4.5)
	var ba := WorldModelScript.travel_seconds(60, 90, 10, 20, 4.5)
	_check("travel_seconds simetrik", ab == ba, "%.3f / %.3f" % [ab, ba])
	var near := WorldModelScript.travel_seconds(10, 20, 20, 20, 4.5)
	var far := WorldModelScript.travel_seconds(10, 20, 40, 20, 4.5)
	_check("mesafe ↑ → süre ↑ (monoton)", far > near, "%.1f < %.1f" % [near, far])
	var slow := WorldModelScript.travel_seconds(10, 20, 30, 20, 7.5)
	var fast := WorldModelScript.travel_seconds(10, 20, 30, 20, 2.25)
	_check("yavaş birim → uzun süre", slow > fast, "%.1f > %.1f" % [slow, fast])
	var expected := 20.0 * 5.0 * 60.0 / TravelScript.unit_speed_multiplier()
	_check("formül: 20 alan × 5 dk/alan × 60 sn",
		is_equal_approx(WorldModelScript.travel_seconds(0, 0, 20, 0, 5.0), expected),
		"%.1f sn" % WorldModelScript.travel_seconds(0, 0, 20, 0, 5.0))
	_check("hız 0 → süre 0 (yolculuk yok)",
		WorldModelScript.travel_seconds(0, 0, 20, 0, 0.0) == 0.0)
	_check("ondalıklı hız korunur (4.5 ≠ 4)",
		not is_equal_approx(WorldModelScript.travel_seconds(0, 0, 10, 0, 4.5),
			WorldModelScript.travel_seconds(0, 0, 10, 0, 4.0)),
		"%.1f vs %.1f" % [WorldModelScript.travel_seconds(0, 0, 10, 0, 4.5),
			WorldModelScript.travel_seconds(0, 0, 10, 0, 4.0)])


func _test_travel_helpers() -> void:
	_section("Travel yardımcıları")
	_check("en yavaş birim: kata (7.5)", is_equal_approx(TravelScript.slowest_speed({"spear": 5, "kata": 3}), 7.5),
		"%f" % TravelScript.slowest_speed({"spear": 5, "kata": 3}))
	_check("slowest_unit() == 'kata'", TravelScript.slowest_unit({"spear": 5, "kata": 3}) == "kata")
	_check("süvari ordusu: heavy (2.75)",
		is_equal_approx(TravelScript.slowest_speed({"light": 10, "heavy": 10}), 2.75))
	_check("boş ordu → 0", TravelScript.slowest_speed({}) == 0.0)
	_check("adet 0 olan birim yok sayılır",
		is_equal_approx(TravelScript.slowest_speed({"kata": 0, "spear": 2}), 4.5))
	_check("spear alan/dakika == 4.5", is_equal_approx(TravelScript.unit_minutes_per_field("spear"), 4.5),
		"%f" % TravelScript.unit_minutes_per_field("spear"))
	_check("snob alan/dakika == 8.75", is_equal_approx(TravelScript.unit_minutes_per_field("snob"), 8.75))
	_check("bilinmeyen birim → 0", TravelScript.unit_minutes_per_field("ejderha") == 0.0)
	_check("unit_speed çarpanı > 0", TravelScript.unit_speed_multiplier() > 0.0,
		"%.2f" % TravelScript.unit_speed_multiplier())
	_check("gidiş-dönüş = 2 × gidiş",
		is_equal_approx(TravelScript.round_trip_seconds(5, 5, 25, 25, 4.5),
			2.0 * TravelScript.travel_seconds(5, 5, 25, 25, 4.5)))
	var arrive := TravelScript.arrive_unix(1000, 90.4)
	_check("arrive_unix round_half_up", arrive == 1090, "%d" % arrive)


func _test_find_free_spot(world: Dictionary) -> void:
	_section("find_free_spot()")
	var start = world.get("player_start", {})
	var sx := int(start.get("x", -1))
	var sy := int(start.get("y", -1))
	_check("player_start sınır içinde", WorldModelScript.is_inside(sx, sy, WORLD_SIZE), "%d|%d" % [sx, sy])
	_check("player_start boş", WorldModelScript.is_tile_free(world, sx, sy), "%d|%d" % [sx, sy])
	var occupied: Dictionary = WorldModelScript.villages_of(world)[0]
	var spot := WorldModelScript.find_free_spot(world, int(occupied.get("x", 0)), int(occupied.get("y", 0)))
	_check("dolu alanda komşu boş alan döner",
		spot.x != int(occupied.get("x", 0)) or spot.y != int(occupied.get("y", 0)),
		"%d|%d" % [spot.x, spot.y])
	_check("dönen alan boş", spot.x > 0 and WorldModelScript.is_tile_free(world, spot.x, spot.y))
	var corner := WorldModelScript.find_free_spot(world, 500, 500)
	_check("sınır dışı istek 1..200'e kırpılır",
		corner.x >= 1 and corner.x <= WORLD_SIZE and corner.y >= 1 and corner.y <= WORLD_SIZE,
		"%d|%d" % [corner.x, corner.y])
	var free_tile := WorldModelScript.find_free_spot(world, sx, sy)
	_check("boş alanda aynı alan döner", free_tile == Vector2i(sx, sy), "%s" % free_tile)


func _test_neighbors(world: Dictionary) -> void:
	_section("Komşuluk listesi")
	var reference: Dictionary = WorldModelScript.villages_of(world)[0]
	var rx := int(reference.get("x", 0))
	var ry := int(reference.get("y", 0))
	var found: Array = WorldModelScript.neighbors(world, rx, ry, 20)
	_check("komşu listesi dolu", found.size() > 0, "n=%d" % found.size())
	var sorted_ok := true
	var previous := -1.0
	for village in found:
		var d := WorldModelScript.distance(rx, ry, int(village.get("x", 0)), int(village.get("y", 0)))
		if d < previous - 0.0001:
			sorted_ok = false
		previous = d
	_check("mesafeye göre artan sıralı", sorted_ok)
	var radius_ok := true
	for village in WorldModelScript.neighbors(world, rx, ry, 5):
		if WorldModelScript.distance(rx, ry, int(village.get("x", 0)), int(village.get("y", 0))) > 5.0001:
			radius_ok = false
	_check("yarıçap filtresi çalışıyor", radius_ok)
	var without_self: Array = WorldModelScript.neighbors(world, rx, ry, 0, false)
	var self_present := false
	for village in without_self:
		if int(village.get("id", -1)) == int(reference.get("id", -2)):
			self_present = true
	_check("include_self=false → kendisi listede değil", not self_present, "n=%d" % without_self.size())
	_check("limit=3 → 3 köy", WorldModelScript.neighbors(world, rx, ry, 0, true, 3).size() == 3)
	_check("village_at() doğru köyü veriyor",
		int(WorldModelScript.village_at(world, rx, ry).get("id", -1)) == int(reference.get("id", -2)))
	_check("boş alanda village_at() boş",
		WorldModelScript.village_at(world, int(world.get("player_start", {}).get("x", 1)),
			int(world.get("player_start", {}).get("y", 1))).is_empty())


func _test_minimap(world: Dictionary) -> void:
	_section("Miniharita verisi (ızgara → köy yoğunluğu)")
	var count := WorldModelScript.minimap_cell_count(world, 10)
	_check("ızgara 20×20 (200 / 10)", count == 20, "n=%d" % count)
	var density: Array = WorldModelScript.minimap_density(world, 10)
	_check("yoğunluk ızgarası 20 satır", density.size() == 20, "satır=%d" % density.size())
	var total := 0
	var peak := 0
	for row in density:
		for value in row:
			total += int(value)
			peak = maxi(peak, int(value))
	_check("yoğunluk toplamı == köy sayısı",
		total == WorldModelScript.villages_of(world).size(),
		"toplam=%d köy=%d" % [total, WorldModelScript.villages_of(world).size()])
	_check("yoğunluk kümelenmiş (en yoğun hücre > 1)", peak > 1, "tepe=%d" % peak)
	var kinds: Array = WorldModelScript.minimap_kind_grid(world, 10)
	var has_barbarian := false
	var has_bonus := false
	var has_bot := false
	for row in kinds:
		for value in row:
			if value == "barbarian":
				has_barbarian = true
			elif value == "bonus":
				has_bonus = true
			elif value == "bot":
				has_bot = true
	_check("tür ızgarası bot/terkedilmiş/bonus içeriyor", has_bot and has_barbarian and has_bonus,
		"bot=%s barbar=%s bonus=%s" % [has_bot, has_barbarian, has_bonus])


func _test_continents(world: Dictionary) -> void:
	_section("Kıtalar — docs/19 §6 / docs/10 §1")
	_check("docs/10 örneği: 499|506 → K54", WorldModelScript.continent_label(499, 506) == "K54",
		WorldModelScript.continent_label(499, 506))
	_check("(50,50) → K00", WorldModelScript.continent_label(50, 50) == "K00",
		WorldModelScript.continent_label(50, 50))
	_check("(150,50) → K01", WorldModelScript.continent_label(150, 50) == "K01",
		WorldModelScript.continent_label(150, 50))
	_check("(50,150) → K10", WorldModelScript.continent_label(50, 150) == "K10",
		WorldModelScript.continent_label(50, 150))
	_check("(150,150) → K11", WorldModelScript.continent_label(150, 150) == "K11",
		WorldModelScript.continent_label(150, 150))
	_check("continent_id(150,150) == 11", WorldModelScript.continent_id(150, 150) == 11,
		"id=%d" % WorldModelScript.continent_id(150, 150))
	_check("continent_of() == continent_label()",
		WorldModelScript.continent_of(120, 130) == WorldModelScript.continent_label(120, 130))
	var distribution: Dictionary = WorldModelScript.continent_distribution(world)
	_check("200×200 dünyada 4 kıta (K00/K01/K10/K11)",
		distribution.size() == 4 and distribution.keys() == ["K00", "K01", "K10", "K11"],
		"kıtalar=%s" % [distribution.keys()])
	var sum := 0
	for key in distribution.keys():
		sum += int(distribution[key])
	_check("kıta dağılımı toplamı == köy sayısı",
		sum == WorldModelScript.villages_of(world).size(), "toplam=%d" % sum)
	var in_continent: Array = WorldModelScript.continent_villages(world, 150, 150)
	_check("aynı kıta sorgusu (K11) köy döndürüyor", in_continent.size() > 0, "n=%d" % in_continent.size())


func _test_player_village(world: Dictionary) -> void:
	_section("Oyuncu köyü")
	var player: Dictionary = WorldModelScript.player_village(world)
	var points := int(player.get("points", -1))
	_check("id = 1", int(player.get("id", 0)) == 1)
	_check("is_bot=false, is_barbarian=false",
		not bool(player.get("is_bot", true)) and not bool(player.get("is_barbarian", true)))
	_check("dünyanın tiles'ına eklenmedi (üretici dokunmaz)",
		WorldModelScript.village_at(world, int(player.get("x", 0)), int(player.get("y", 0))).is_empty())
	_check("başlangıç binaları geçerli",
		int((player.get("buildings", {}) as Dictionary).get("main", -1)) == 1
		and int((player.get("buildings", {}) as Dictionary).get("statue", -1)) == 0)
	_check("Köy Puanı = 110", points == 110, "points=%d" % points)
	_check("Güç Alanı = Köy Puanı (oyuncu da tavanla başlar)",
		int(player.get("realm_of_power", -1)) == points, "realm=%s" % player.get("realm_of_power"))
	_check("bonus_type == '' ve researched == {}",
		str(player.get("bonus_type", "?")) == ""
		and (player.get("researched", {}) as Dictionary).is_empty())
	_check("koruma alanları 0 (oyun katmanı doldurur)",
		int(player.get("protection_until", -1)) == 0
		and int(player.get("conquest_protection_until", -1)) == 0)


func _test_movement_helpers() -> void:
	_section("Hareket yardımcıları — docs/19 §3.3 / docs/09 §6")
	var movement: Dictionary = TravelScript.make_movement({
		"id": 20, "village_id": 1, "type": "attack", "from_village_id": 1, "to_village_id": 5,
		"from_x": 100, "from_y": 100, "to_x": 140, "to_y": 100,
		"units": {"spear": 10, "kata": 2}, "depart_unix": 1000, "battle_seed": 12345,
		"target_points": 20,
	})
	_check("§3.3 alanları tam",
		movement.has("id") and movement.has("type") and movement.has("units") and movement.has("carry")
		and movement.has("depart_unix") and movement.has("arrive_unix") and movement.has("return_unix")
		and movement.has("state") and movement.has("battle_seed") and movement.has("target_points"))
	_check("en yavaş birim (kata) süreyi belirler",
		is_equal_approx(float(movement.get("arrive_unix", 0)), 1000.0 + round(40.0 * 7.5 * 60.0 / TravelScript.unit_speed_multiplier())),
		"arrive=%d" % movement.get("arrive_unix", 0))
	_check("dönüş = varış + gidiş", int(movement.get("return_unix", 0)) > int(movement.get("arrive_unix", 0)))
	_check("state == 'outgoing'", str(movement.get("state", "")) == "outgoing")
	_check("carry varsayılanı {0,0,0}", int((movement.get("carry", {}) as Dictionary).get("wood", -1)) == 0)
	_check("Kont mesafe kuralı (80 alan)", TravelScript.within_max_fields(100, 100, 160, 100, 80.0)
		and not TravelScript.within_max_fields(100, 100, 190, 100, 80.0))
	_check("iptal penceresi saldırı 30 dk", TravelScript.cancel_window_seconds(false) == 1800,
		"%d" % TravelScript.cancel_window_seconds(false))
	_check("iptal penceresi katır 15 dk", TravelScript.cancel_window_seconds(true) == 900,
		"%d" % TravelScript.cancel_window_seconds(true))
	_check("iptal edilebilir (5 dk sonra)", TravelScript.can_cancel(1000, 1300, false))
	_check("iptal edilemez (35 dk sonra)", not TravelScript.can_cancel(1000, 1000 + 35 * 60, false))


func _test_edge_cases() -> void:
	_section("Uç durumlar")
	var empty: Dictionary = WorldModelScript.generate_world(TEST_SEED, 0)
	var empty_counts: Dictionary = WorldModelScript.count_kinds(empty)
	_check("bot_count=0 → köy yok", int(empty_counts.get("bot", -1)) == 0
		and int(empty_counts.get("total", -1)) == 0)
	_check("bot_count=0 → dünya yine geçerli", WorldModelScript.validate_world(empty).is_empty(),
		"sorun=%d" % WorldModelScript.validate_world(empty).size())
	var one: Dictionary = WorldModelScript.generate_world(1, 1)
	_check("bot_count=1 → bot 1, terkedilmiş 1",
		int(WorldModelScript.count_kinds(one).get("bot", 0)) == 1
		and int(WorldModelScript.count_kinds(one).get("barbarian", 0)) == 1)
	var six: Dictionary = WorldModelScript.generate_world(3, 60)
	var six_types: Dictionary = {}
	for village in WorldModelScript.villages_of_kind(six, "bonus"):
		six_types[WorldModelScript.bonus_type_of(village)] = true
	_check("bot_count=60 → 6 bonus köy ve 6 tipin tamamı",
		WorldModelScript.villages_of_kind(six, "bonus").size() == 6 and six_types.size() == 6,
		"bonus=%d tip=%d" % [WorldModelScript.villages_of_kind(six, "bonus").size(), six_types.size()])
	var big: Dictionary = WorldModelScript.generate_world(7, 400)
	_check("bot_count=400 → hâlâ çakışma yok ve sınır içinde",
		WorldModelScript.validate_world(big).is_empty() and WorldModelScript.villages_of(big).size() == 840,
		"köy=%d" % WorldModelScript.villages_of(big).size())
	_check("negatif tohum çalışır", not WorldModelScript.generate_world(-5, 10).is_empty())
	_check("boş dünyada find_free_spot merkezi verir",
		WorldModelScript.find_free_spot({"size": 200, "villages": [], "tiles": {}}, 500, 500) == Vector2i(200, 200))
	_check("aynı tohum + farklı bot sayısı → farklı dünya",
		WorldModelScript.world_hash(WorldModelScript.generate_world(1, 10))
		!= WorldModelScript.world_hash(WorldModelScript.generate_world(1, 11)))


func _test_data_agreement() -> void:
	_section("Veri katmanı uyumu (GameData)")
	if _game_data == null:
		_check("GameData autoload mevcut", false, "bulunamadı")
		return
	var buildings: Array = _game_data.get_all_building_keys()
	var units: Array = _game_data.get_all_unit_keys()
	var keys_a := buildings.duplicate()
	var keys_b: Array = WorldGeneratorScript.BUILDING_KEYS.duplicate()
	keys_a.sort()
	keys_b.sort()
	_check("bina anahtarları data/buildings.json ile aynı", keys_a == keys_b,
		"data=%d model=%d" % [keys_a.size(), keys_b.size()])
	var units_a := units.duplicate()
	var units_b: Array = WorldGeneratorScript.UNIT_KEYS.duplicate()
	units_a.sort()
	units_b.sort()
	_check("birim anahtarları data/units.json ile aynı", units_a == units_b,
		"data=%d model=%d" % [units_a.size(), units_b.size()])
	var over_max := 0
	for key in WorldGeneratorScript.BUILDING_KEYS:
		if int(_game_data.get_max_level(key)) != int(WorldGeneratorScript.MAX_LEVELS.get(key, -1)):
			over_max += 1
	_check("maks. seviyeler data ile aynı", over_max == 0, "fark=%d" % over_max)

	# Puan tablosu: **bina × seviye** tam çapraz doğrulama (docs/15 §5.1 doğrusallık).
	var points_bad: Array = _points_mismatches()
	_check("POINTS_PER_LEVEL tablosu building-points.json ile birebir", points_bad.is_empty(),
		"ilk fark=%s" % (points_bad[0] if not points_bad.is_empty() else "yok"))
	var maxed: Dictionary = {}
	for key in WorldGeneratorScript.BUILDING_KEYS:
		maxed[key] = int(_game_data.get_max_level(key))
	_check("tam gelişmiş köy puanı = 10.000", WorldGeneratorScript.village_points(maxed) == 10000,
		"puan=%d" % WorldGeneratorScript.village_points(maxed))
	var data_points := 0
	for key in WorldGeneratorScript.START_BUILDINGS_LEVEL_1:
		data_points += int(_game_data.points_for(key, 1))
	_check("başlangıç puanı (110) building-points.json ile aynı",
		data_points == WorldGeneratorScript.starting_points(),
		"data=%d model=%d" % [data_points, WorldGeneratorScript.starting_points()])

	_check("birim hızları rules/units.json ile aynı", _speeds_match_rules())

	# Kışla gereksinimleri (soyguncu birim üretimi buna bağlı).
	var req_bad: Array = _requirement_mismatches()
	_check("BARRACKS_REQUIREMENT rules/units.json ile aynı", req_bad.is_empty(),
		"fark=%s" % [req_bad])
	_check("rules/units.json yüklendi (birim hızı kaynağı)",
		typeof(_game_data.get_rule("units")) == TYPE_DICTIONARY)


# --- Yardımcılar ------------------------------------------------------------

## `RulesEngine` (A-MOTOR) ile çapraz kontrol — **bilgi amaçlı**, çalışma zamanında yüklenir.
## `docs/19` §4.5: `unit_speed()` **ondalıklı alan/dakika** (float), `unit_mobility()` yuvarlanmış int.
func _test_rules_engine_alignment(world: Dictionary) -> void:
	_section("RulesEngine uyumu (çapraz modül, bilgi)")
	var path := "res://scripts/rules/RulesEngine.gd"
	if not ResourceLoader.exists(path):
		_info("RulesEngine.gd bulunamadı → çapraz kontrol atlandı")
		return
	var rules_engine = load(path)
	if rules_engine == null:
		_info("RulesEngine.gd yüklenemedi (başka ajan düzenliyor olabilir) → atlandı")
		return
	if not rules_engine.has_method("unit_speed"):
		_info("RulesEngine.unit_speed() yok → atlandı")
		return
	var speed_mismatch: Array = []
	var mobility_mismatch: Array = []
	var has_mobility: bool = rules_engine.has_method("unit_mobility")
	for key in WorldGeneratorScript.UNIT_KEYS:
		var engine_speed := float(rules_engine.unit_speed(key))
		var minutes := TravelScript.unit_minutes_per_field(key)
		if engine_speed > 0.0 and not is_equal_approx(engine_speed, minutes):
			speed_mismatch.append("%s engine=%.3f mod=%.3f" % [key, engine_speed, minutes])
		if has_mobility:
			if int(rules_engine.unit_mobility(key)) != int(round(minutes)):
				mobility_mismatch.append("%s mobility=%d round=%.2f" % [
					key, int(rules_engine.unit_mobility(key)), minutes])
	_check("RulesEngine.unit_speed() == Travel.unit_minutes_per_field() (ondalıklı alan/dk)",
		speed_mismatch.is_empty(), "uyuşmaz=%s" % [speed_mismatch])
	if has_mobility:
		_check("RulesEngine.unit_mobility() == round(alan/dakika)", mobility_mismatch.is_empty(),
			"uyuşmaz=%s" % [mobility_mismatch])
	if rules_engine.has_method("village_points"):
		var mismatched := 0
		for village in WorldModelScript.villages_of(world):
			if int(rules_engine.village_points(village.get("buildings", {}))) != int(village.get("points", -1)):
				mismatched += 1
		_check("RulesEngine.village_points() == üretilen 'points'", mismatched == 0,
			"uyuşmaz=%d" % mismatched)


func _points_mismatches() -> Array:
	var bad: Array = []
	if _game_data == null:
		return ["GameData yok"]
	for key in WorldGeneratorScript.BUILDING_KEYS:
		var top := int(_game_data.get_max_level(key))
		for level in range(1, top + 1):
			var expected := int(_game_data.points_for(key, level))
			var model := int(WorldGeneratorScript.POINTS_PER_LEVEL.get(key, 0)) * level
			if expected != model:
				bad.append("%s sv%d data=%d model=%d" % [key, level, expected, model])
	return bad


func _requirement_mismatches() -> Array:
	var bad: Array = []
	if _game_data == null or not _game_data.has_method("get_rule"):
		return ["GameData/rules yok"]
	var rules = _game_data.get_rule("units")
	if typeof(rules) != TYPE_DICTIONARY:
		return ["rules/units.json yok"]
	var requirements = (rules as Dictionary).get("research_requirements_barracks", {})
	if typeof(requirements) != TYPE_DICTIONARY:
		return ["research_requirements_barracks yok"]
	for key in (requirements as Dictionary).keys():
		var data_value := int((requirements as Dictionary)[key])
		var model_value := int(WorldGeneratorScript.BARRACKS_REQUIREMENT.get(str(key), -1))
		if data_value != model_value:
			bad.append("%s data=%d model=%d" % [key, data_value, model_value])
	return bad


func _speeds_match_rules() -> bool:
	if _game_data == null or not _game_data.has_method("get_rule"):
		return false
	var rules = _game_data.get_rule("units")
	if typeof(rules) != TYPE_DICTIONARY:
		return false
	for item in (rules as Dictionary).get("units", []) as Array:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var key := str((item as Dictionary).get("key", ""))
		var speed = (item as Dictionary).get("speed", {})
		if typeof(speed) != TYPE_DICTIONARY:
			continue
		var expected := float((speed as Dictionary).get("minutes_per_field", 0.0))
		if expected <= 0.0:
			continue
		if not is_equal_approx(TravelScript.unit_minutes_per_field(key), expected):
			print("      → uyuşmazlık: %s model=%.4f data=%.4f" % [key, TravelScript.unit_minutes_per_field(key), expected])
			return false
	return true


func _all_bonus_type_empty(villages: Array) -> bool:
	for village in villages:
		if not WorldModelScript.bonus_type_of(village).is_empty():
			return false
	return true


## `bonus_type` dolu ⟺ köy türü "bonus" (tek ayrım kaynağı; `docs/19` §3.1).
func _bonus_type_iff_kind_bonus(world: Dictionary) -> bool:
	for village in WorldModelScript.villages_of(world):
		var has_type := not WorldModelScript.bonus_type_of(village).is_empty()
		var is_bonus := WorldModelScript.kind_of(village) == "bonus"
		if has_type != is_bonus:
			return false
	return true


func _strictly_inside(world: Dictionary, sample: int) -> bool:
	var checked := 0
	for key in WorldModelScript.tiles_of(world).keys():
		var parts := str(key).split(",")
		if parts.size() != 2:
			return false
		if not WorldModelScript.is_inside(int(parts[0]), int(parts[1]), WORLD_SIZE):
			return false
		checked += 1
		if checked >= sample:
			break
	return true


func _all_zero(data: Dictionary) -> bool:
	for key in data.keys():
		if int(data[key]) != 0:
			return false
	return true


func _ids_unique(world: Dictionary) -> bool:
	var seen: Dictionary = {}
	for village in WorldModelScript.villages_of(world):
		var id := int(village.get("id", -1))
		if id <= 0 or seen.has(id):
			return false
		seen[id] = true
	return true


func _intersection_count(a: Array, b: Array) -> int:
	var count := 0
	for item in a:
		if b.has(item):
			count += 1
	return count


func _section(title: String) -> void:
	print("— %s" % title)


func _info(message: String) -> void:
	print("  BİLGİ %s" % message)


func _check(label: String, condition: bool, detail: String = "") -> bool:
	var suffix := "" if detail.is_empty() else "  [%s]" % detail
	if condition:
		_pass += 1
		print("  PASS  %s%s" % [label, suffix])
	else:
		_fail += 1
		_failures.append("%s%s" % [label, suffix])
		print("  FAIL  %s%s" % [label, suffix])
	return condition


func _print_world_summary(world: Dictionary) -> void:
	print("")
	print("=== Örnek dünya özeti (tohum=%d, bot=%d) ===" % [TEST_SEED, TEST_BOT_COUNT])
	var counts: Dictionary = WorldModelScript.count_kinds(world)
	print("  köy sayısı : %d  (bot %d · terkedilmiş %d · bonus %d)" % [
		counts.get("total", 0), counts.get("bot", 0), counts.get("barbarian", 0), counts.get("bonus", 0),
	])
	print("  kıta dağılımı: %s" % [WorldModelScript.continent_distribution(world)])
	# Bonus tip dağılımı
	var bonus_types: Dictionary = {}
	for village in WorldModelScript.villages_of_kind(world, "bonus"):
		var bonus_type := WorldModelScript.bonus_type_of(village)
		bonus_types[bonus_type] = int(bonus_types.get(bonus_type, 0)) + 1
	print("  bonus tipleri: %s" % [bonus_types])
	# Terkedilmiş köy gelişimi
	var barbarians: Array = WorldModelScript.villages_of_kind(world, "barbarian")
	var barb_points := 0
	var barb_units := 0
	var barb_max_points := 0
	for village in barbarians:
		barb_points += int(village.get("points", 0))
		barb_units += WorldGeneratorScript.units_total(village.get("units", {}))
		barb_max_points = maxi(barb_max_points, int(village.get("points", 0)))
	if not barbarians.is_empty():
		print("  soyguncular : %d köy · puan ort. %.0f (en büyük %d) · toplam garnizon %d birim" % [
			barbarians.size(), float(barb_points) / float(barbarians.size()), barb_max_points, barb_units,
		])
	var density: Array = WorldModelScript.minimap_density(world, 10)
	var peak := 0
	var empty_cells := 0
	for row in density:
		for value in row:
			peak = maxi(peak, int(value))
			if int(value) == 0:
				empty_cells += 1
	print("  miniharita : 20×20 hücre (10 alan) · en yoğun hücre %d köy · boş hücre %d" % [peak, empty_cells])
	var reference: Dictionary = WorldModelScript.villages_of(world)[0]
	var rx := int(reference.get("x", 0))
	var ry := int(reference.get("y", 0))
	print("  en yakın 3 komşu (%d|%d) : %s" % [rx, ry, _neighbor_brief(world, rx, ry, 3)])
	print("  örnek köy : %s" % [JSON.stringify(reference)])
	var barbarian_example := _richest_barbarian(barbarians)
	if not barbarian_example.is_empty():
		print("  örnek soyguncu köyü : %s" % [JSON.stringify(barbarian_example)])
	var bonus_example: Dictionary = WorldModelScript.villages_of_kind(world, "bonus")[0]
	print("  örnek bonus köyü : %s (%s)" % [
		JSON.stringify(bonus_example),
		WorldModelScript.bonus_effect_text(WorldModelScript.bonus_type_of(bonus_example)),
	])
	print("  örnek yolculuk: %d|%d → 150|150 · Silahtar %.2f saat · Akıncı %.2f saat · Mancınık %.2f saat (birim hızı ×%.1f)" % [
		rx, ry,
		WorldModelScript.travel_seconds(rx, ry, 150, 150, TravelScript.unit_minutes_per_field("spear")) / 3600.0,
		WorldModelScript.travel_seconds(rx, ry, 150, 150, TravelScript.unit_minutes_per_field("light")) / 3600.0,
		WorldModelScript.travel_seconds(rx, ry, 150, 150, TravelScript.unit_minutes_per_field("kata")) / 3600.0,
		TravelScript.unit_speed_multiplier(),
	])
	print("  dünya hash : %s" % WorldModelScript.world_hash(world))


## Puanı en yüksek terkedilmiş köy (örnek olarak yazdırılır).
func _richest_barbarian(barbarians: Array) -> Dictionary:
	var best: Dictionary = {}
	for village in barbarians:
		if best.is_empty() or int(village.get("points", 0)) > int(best.get("points", 0)):
			best = village
	return best


func _neighbor_brief(world: Dictionary, x: int, y: int, limit: int) -> String:
	var parts: Array = []
	for village in WorldModelScript.neighbors(world, x, y, 0, false, limit):
		parts.append("%s(%d|%d, %.1f)" % [
			village.get("name", "?"), village.get("x", 0), village.get("y", 0),
			WorldModelScript.distance(x, y, int(village.get("x", 0)), int(village.get("y", 0))),
		])
	return ", ".join(parts)


func _print_summary() -> void:
	print("")
	print("=== SONUÇ ===")
	print("  PASS: %d · FAIL: %d" % [_pass, _fail])
	if not _failures.is_empty():
		print("  Başarısız kontroller:")
		for failure in _failures:
			print("   - %s" % failure)
	print("  SONUÇ: %s" % ("PASS" if _fail == 0 else "FAIL"))
