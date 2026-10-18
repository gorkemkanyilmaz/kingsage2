extends SceneTree
## Dünya / harita testleri — Taht ve Kılıç / **A-DUNYA** (SceneTree tabanlı).
##
## Çalıştırma:
## ```
## & $godot --headless --path '.\game' --script res://tests/test_world.gd
## ```
## Kapsam (`docs/19` §6, §8):
##  (a) aynı tohum → **aynı dünya** (hash eşit)   (b) farklı tohum → farklı dünya
##  (c) 200×200 sınırları içinde                  (d) koordinat çakışması yok
##  (e) `bot_count` kadar bot köyü                (f) bina seviyeleri geçerli (maks. aşımı yok)
##  (g) `travel_seconds` simetrik ve monoton
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
	_test_barbarian_and_bonus(world)
	_test_buildings(world)
	_test_resources_and_units(world)
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
	_test_rules_engine_alignment()
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
	_check("başlangıç puanı 110", WorldGeneratorScript.starting_points() == 110,
		"points=%d" % WorldGeneratorScript.starting_points())


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


func _test_barbarian_and_bonus(world: Dictionary) -> void:
	_section("Terkedilmiş (soyguncu) ve bonus köyler — docs/10")
	var barbarians: Array = WorldModelScript.villages_of_kind(world, "barbarian")
	var bonuses: Array = WorldModelScript.villages_of_kind(world, "bonus")
	_check("terkedilmiş köyler var", barbarians.size() > 0, "n=%d" % barbarians.size())
	_check("bonus köyler var", bonuses.size() > 0, "n=%d" % bonuses.size())
	var barb_ok := true
	for village in barbarians:
		if bool(village.get("is_bot", true)) or str(village.get("owner", "?")) != "":
			barb_ok = false
	_check("terkedilmiş köyde is_bot=false, sahip boş", barb_ok)
	var bonus_ok := true
	for village in bonuses:
		var bonus: Dictionary = village.get("bonus", {})
		var raised := 0
		for key in bonus.keys():
			if not is_equal_approx(float(bonus[key]), 1.0):
				raised += 1
		if raised != 1 or str(village.get("owner", "")) != "Usta":
			bonus_ok = false
	_check("bonus köyde tek kaynak çarpanı != 1.0 ve sahip 'Usta'", bonus_ok,
		"örn=%s" % (bonuses[0].get("bonus") if not bonuses.is_empty() else "-"))


func _test_buildings(world: Dictionary) -> void:
	_section("(f) Bina şekli ve seviye sınırları")
	var start_keys := ["main", "stone", "wood", "iron", "farm", "storage"]
	var bad_count := 0
	var bad_start := 0
	var over_max := 0
	var wrong_type := 0
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
			var expected := 1 if key in start_keys else 0
			if level != expected:
				bad_start += 1
			var top := WorldModelScript.max_level(key)
			if top > 0 and level > top:
				over_max += 1
	_check("her köyde 15 bina anahtarı", bad_count == 0, "sorun=%d" % bad_count)
	_check("bina seviyeleri int", wrong_type == 0, "sorun=%d" % wrong_type)
	_check("başlangıç binaları (main/stone/wood/iron/farm/storage = 1, diğerleri 0)",
		bad_start == 0, "sorun=%d" % bad_start)
	_check("maks. seviye aşımı yok", over_max == 0, "sorun=%d" % over_max)


func _test_resources_and_units(world: Dictionary) -> void:
	_section("Kaynak, birim, puan ve güç alanı")
	var res_ok := 0
	var units_ok := 0
	var points_ok := 0
	var total := WorldModelScript.villages_of(world).size()
	for village in WorldModelScript.villages_of(world):
		var resources: Dictionary = village.get("resources", {})
		if resources.size() == 3 and int(resources.get("wood", -1)) == 1000 \
				and int(resources.get("stone", -1)) == 1000 and int(resources.get("iron", -1)) == 1000:
			res_ok += 1
		var units: Dictionary = village.get("units", {})
		if units.size() == 11 and _all_zero(units):
			units_ok += 1
		if int(village.get("points", -1)) == 110:
			points_ok += 1
	_check("kaynaklar {1000, 1000, 1000}", res_ok == total, "%d/%d" % [res_ok, total])
	_check("11 birim anahtarı, hepsi 0", units_ok == total, "%d/%d" % [units_ok, total])
	_check("Köy Puanı = 110", points_ok == total, "%d/%d" % [points_ok, total])
	var realm_ok := true
	for village in WorldModelScript.villages_of(world):
		if int(village.get("realm_of_power", -1)) != 110:
			realm_ok = false
	_check("Güç Alanı = 110 (NPC köyleri tam güç alanıyla başlar)", realm_ok)


func _test_contract_shape(world: Dictionary) -> void:
	_section("§3.1 köy şekli + validate_world()")
	var required := [
		"id", "name", "x", "y", "owner", "is_bot", "is_barbarian", "buildings", "resources",
		"units", "realm_of_power", "points", "protection_until", "conquest_protection_until",
		"bonus", "has_statue",
	]
	var missing := 0
	for village in WorldModelScript.villages_of(world):
		for key in required:
			if not village.has(key):
				missing += 1
	_check("16 sözleşme alanı eksiksiz", missing == 0, "eksik=%d" % missing)
	var problems: Array = WorldModelScript.validate_world(world)
	_check("validate_world() sorunsuz", problems.is_empty(),
		"sorun=%d %s" % [problems.size(), problems.slice(0, 3) if not problems.is_empty() else ""])
	var broken: Dictionary = world.duplicate(true)
	var first_village: Dictionary = WorldModelScript.villages_of(broken)[0]
	first_village["buildings"]["main"] = 999
	first_village["x"] = 500
	_check("validate_world() bozuk dünyayı yakalıyor",
		WorldModelScript.validate_world(broken).size() >= 2,
		"sorun=%d" % WorldModelScript.validate_world(broken).size())


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
	_section("Kıtalar — docs/10 §1")
	_check("docs/10 örneği: 499|506 → K54", WorldModelScript.continent_of(499, 506) == "K54",
		WorldModelScript.continent_of(499, 506))
	_check("continent_id(150,150) == 11", WorldModelScript.continent_id(150, 150) == 11,
		"id=%d" % WorldModelScript.continent_id(150, 150))
	var distribution: Dictionary = WorldModelScript.continent_distribution(world)
	_check("200×200 dünyada 4 kıta", distribution.size() == 4, "kıtalar=%s" % [distribution.keys()])
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
	_check("id = 1", int(player.get("id", 0)) == 1)
	_check("is_bot=false, is_barbarian=false",
		not bool(player.get("is_bot", true)) and not bool(player.get("is_barbarian", true)))
	_check("dünyanın tiles'ına eklenmedi (üretici dokunmaz)",
		WorldModelScript.village_at(world, int(player.get("x", 0)), int(player.get("y", 0))).is_empty())
	_check("başlangıç binaları geçerli",
		int((player.get("buildings", {}) as Dictionary).get("main", -1)) == 1
		and int((player.get("buildings", {}) as Dictionary).get("statue", -1)) == 0)
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
	_check("bot_count=0 → bot köyü yok", int(WorldModelScript.count_kinds(empty).get("bot", -1)) == 0)
	_check("bot_count=0 → dünya yine geçerli", WorldModelScript.validate_world(empty).is_empty(),
		"sorun=%d" % WorldModelScript.validate_world(empty).size())
	var one: Dictionary = WorldModelScript.generate_world(1, 1)
	_check("bot_count=1 → bot 1, terkedilmiş 1", int(WorldModelScript.count_kinds(one).get("bot", 0)) == 1
		and int(WorldModelScript.count_kinds(one).get("barbarian", 0)) == 1)
	var big: Dictionary = WorldModelScript.generate_world(7, 400)
	_check("bot_count=400 → hâlâ çakışma yok ve sınır içinde",
		WorldModelScript.validate_world(big).is_empty() and WorldModelScript.villages_of(big).size() == 840,
		"köy=%d" % WorldModelScript.villages_of(big).size())
	_check("negatif tohum çalışır", not WorldModelScript.generate_world(-5, 10).is_empty())
	_check("boş dünyada find_free_spot merkezi verir",
		WorldModelScript.find_free_spot({"size": 200, "villages": [], "tiles": {}}, 500, 500) == Vector2i(200, 200))


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
	var data_points := 0
	for key in WorldGeneratorScript.START_BUILDINGS_LEVEL_1:
		data_points += int(_game_data.points_for(key, 1))
	_check("başlangıç puanı (110) building-points.json ile aynı",
		data_points == WorldGeneratorScript.starting_points(), "data=%d model=%d" % [data_points, WorldGeneratorScript.starting_points()])
	_check("birim hızları rules/units.json ile aynı", _speeds_match_rules())
	var data_carry := false
	if _game_data.has_method("get_rule"):
		data_carry = typeof(_game_data.get_rule("units")) == TYPE_DICTIONARY
	_check("rules/units.json yüklendi (birim hızı kaynağı)", data_carry)


# --- Yardımcılar ------------------------------------------------------------

## `RulesEngine` (A-MOTOR) ile çapraz kontrol — **bilgi amaçlı**, çalışma zamanında yüklenir.
## `RulesEngine.unit_speed()` **yuvarlanmış "mobility"** (int) döndürür; bu modül ise yolculukta
## **kesin alan/dakika** değerini kullanır (`docs/05` §2). İlişki: `mobility == round(alan/dakika)`.
## (bkz. ASSUMPTIONS.md §7 / AÇIK SORU #10)
func _test_rules_engine_alignment() -> void:
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
	var mismatched: Array = []
	for key in WorldGeneratorScript.UNIT_KEYS:
		var mobility := int(rules_engine.unit_speed(key))
		var minutes := TravelScript.unit_minutes_per_field(key)
		if mobility <= 0:
			continue
		if int(round(minutes)) != mobility:
			mismatched.append("%s mobility=%d alan/dk=%.2f" % [key, mobility, minutes])
	_check("RulesEngine.unit_speed() == round(alan/dakika) — mobility yuvarlanmış", mismatched.is_empty(),
		"uyuşmaz=%s" % [mismatched] if not mismatched.is_empty() else "11 birim")


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
	print("  örnek yolculuk: %d|%d → 150|150 · Silahtar %.2f saat · Akıncı %.2f saat · Mancınık %.2f saat (birim hızı ×%.1f)" % [
		rx, ry,
		WorldModelScript.travel_seconds(rx, ry, 150, 150, TravelScript.unit_minutes_per_field("spear")) / 3600.0,
		WorldModelScript.travel_seconds(rx, ry, 150, 150, TravelScript.unit_minutes_per_field("light")) / 3600.0,
		WorldModelScript.travel_seconds(rx, ry, 150, 150, TravelScript.unit_minutes_per_field("kata")) / 3600.0,
		TravelScript.unit_speed_multiplier(),
	])
	print("  dünya hash : %s" % WorldModelScript.world_hash(world))


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
