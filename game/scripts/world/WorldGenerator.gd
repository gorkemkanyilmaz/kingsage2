extends RefCounted
class_name WorldGenerator
## Deterministik dünya üreticisi — Taht ve Kılıç / **A-DUNYA**.
##
## `generate(seed, bot_count)` **aynı tohum için her zaman aynı dünyayı** üretir:
## yalnızca `RandomNumberGenerator` (+ `rng.seed`) kullanılır. **Global `randi()` / `Array.shuffle()`
## YASAK** (determinizmi bozar). Bkz. `docs/19` §2.3.
##
## Dünya: **200×200 alan** (`docs/19` §6 kararı), kıta = 100×100 alan (`docs/10` §1).
## Üretilen köyler `docs/19` §3.1 köy şekline birebir uyar.
##
## Bilinmeyen oranlar ve seçilen sabitler: `game/scripts/world/ASSUMPTIONS.md`

## Dünya kenarı (alan). `WorldModel.SIZE` ile **aynı** olmalıdır (test doğrular).
const SIZE := 200

## Kıta kenarı (alan) — `docs/10` §1: "Kıta (continent) = 100 × 100 alan".
const CONTINENT_SIZE := 100

## Yerleşim kümesi kenarı (alan). Köyler tek tek serpilmez; **kümeler** hâlinde yerleşir
## (KingsAge'de yerleşimler kıtalar içinde toplanır). Küme merkezleri düzenli ızgaradadır.
const CLUSTER_SIZE := 25

## Bir köyün küme merkezinden en fazla sapması (± alan).
const CLUSTER_SPREAD := 9

## Küme merkezlerinin ızgara düzenini kırmak için ± sapma (alan).
const CLUSTER_JITTER := 3

## Aynı köy için yerleştirme denemesi (küme içinde).
const MAX_PLACEMENT_ATTEMPTS := 40

## Terkedilmiş (soyguncu) köy / bot köyü oranı. **VARSAYIM** (bkz. ASSUMPTIONS.md §4).
const BARBARIAN_RATIO := 1.0

## Bonus köy / bot köyü oranı. **VARSAYIM** (bkz. ASSUMPTIONS.md §4).
const BONUS_RATIO := 0.1

## Bonus köyün yükselttiği kaynağın çarpanı. **VARSAYIM** (bkz. ASSUMPTIONS.md §4) — gerçek KingsAge
## değeri bilinmiyor. Nötr değer 1.0'dır.
const BONUS_MULTIPLIER := 1.25

## Bonus köyde yükseltilebilecek kaynaklar (`docs/10` §2: bonus yerleşim "altın parıltı").
const BONUS_RESOURCES := ["wood", "stone", "iron"]

## İki köy arasındaki en az alan mesafesi. 1 = yalnızca **aynı alan** yasak (`docs/10`'da minimum yok).
const MIN_VILLAGE_DISTANCE := 1

## Terkedilmiş köylerin sahibi yoktur (soyguncular `docs/10`/`TERIMLER.md` §4).
const BARBARIAN_OWNER := ""

## Bonus köyün sahibi resmî TR terimdir: "Usta" (`docs/TERIMLER.md` §4).
const BONUS_OWNER := "Usta"

## Yeni köyün hammaddeleri (`GameState.START_RESOURCES`).
const START_RESOURCES := {"wood": 1000, "stone": 1000, "iron": 1000}

## `docs/19` §3.1: başlangıçta 1 olan binalar; **diğerleri 0**.
const START_BUILDINGS_LEVEL_1 := ["main", "stone", "wood", "iron", "farm", "storage"]

## 15 bina anahtarı — `data/buildings.json` sırası (alfabetik).
const BUILDING_KEYS := [
	"barracks", "farm", "garage", "hide", "iron", "main", "market", "smith",
	"snob", "stable", "statue", "stone", "storage", "wall", "wood",
]

## 11 birim anahtarı — `data/rules/units.json#unit_keys` sırası.
const UNIT_KEYS := [
	"farmer", "spear", "sword", "axe", "bow", "spy", "light", "heavy", "ram", "kata", "snob",
]

## Bina maksimum seviyeleri — `data/buildings.json#maxLevel` (doğrulama yedeği).
const MAX_LEVELS := {
	"barracks": 30, "farm": 50, "garage": 5, "hide": 30, "iron": 50, "main": 50,
	"market": 30, "smith": 5, "snob": 10, "stable": 30, "statue": 1, "stone": 50,
	"storage": 50, "wall": 20, "wood": 50,
}

## Başlangıç binalarının (sv 1) kümülatif puanı — `data/building-points.json` level 1.
## main 20 + stone 20 + wood 20 + iron 20 + storage 20 + farm 10 = **110**.
const POINTS_AT_LEVEL_1 := {"main": 20, "stone": 20, "wood": 20, "iron": 20, "farm": 10, "storage": 20}

## Nötr bonus çarpanları (`docs/19` §3.1).
const NEUTRAL_BONUS := {"wood": 1.0, "stone": 1.0, "iron": 1.0}

## Köy adı heceleri (özgün, Türkçe) — `docs/18` §"özgün isimlendirme".
const NAME_A := [
	"Ak", "Al", "Boz", "Demir", "Gök", "Kara", "Kızıl", "Sarı", "Taş", "Yeşil",
	"Gümüş", "Kurt", "Kartal", "Şahin", "Ateş", "Deniz", "Ay", "Gün", "Er", "Yıldız",
]
const NAME_B := [
	"kale", "hisar", "tepe", "ova", "çayır", "bağ", "çeşme", "dere", "kent", "konak",
	"burç", "orman", "yurt", "taş", "pınar",
]

## Bot oyuncu adları (özgün, Türkçe).
const OWNER_A := [
	"Demir", "Kurt", "Alp", "Bora", "Cengiz", "Ege", "Emre", "Kaan", "Mert", "Sarp",
	"Tuna", "Yavuz", "Barış", "Doğan", "Kerem", "Ozan", "Tolga", "Yiğit", "Arda", "Serkan",
]
const OWNER_B := ["Bey", "Han", "Ağa", "Paşa", "Kral"]


# --- Ana giriş --------------------------------------------------------------

## Deterministik dünya üretir. Dönüş sözlüğü:
## ```
## {
##   "size": 200,                      # dünya kenarı (alan)
##   "seed": <tohum>,
##   "villages": [ ... ],              # docs/19 §3.1 köy sözlükleri (id'ye göre artan)
##   "tiles": { "x,y": <village_id> }, # dolu alanlar (String anahtar → köy id)
##   "player_start": {"x":..,"y":..},  # oyuncunun kurulabileceği en yakın boş alan (merkez civarı)
##   "counts": {"bot":n,"barbarian":n,"bonus":n,"total":n}
## }
## ```
## `counts.bot` **her zaman** istenen `bot_count` kadardır.
static func generate(seed_value: int, bot_count: int, world_size: int = SIZE) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var bots := maxi(0, bot_count)
	var barbarians := maxi(0, int(round(float(bots) * BARBARIAN_RATIO)))
	var bonuses := maxi(0, int(round(float(bots) * BONUS_RATIO)))
	var total := bots + barbarians + bonuses

	var kinds := _build_kinds(bots, barbarians, bonuses)
	_shuffle(kinds, rng)

	var centers := _cluster_centers(world_size, rng)
	var cluster_order: Array = []
	for i in centers.size():
		cluster_order.append(i)
	_shuffle(cluster_order, rng)

	var tiles: Dictionary = {}
	var villages: Array = []
	var used_names: Dictionary = {}
	var used_owners: Dictionary = {}
	var next_id := 1

	for index in total:
		var kind := str(kinds[index])
		var center: Vector2i = centers[int(cluster_order[index % cluster_order.size()])]
		var spot := _spot_in_cluster(tiles, center, world_size, rng)
		if spot.x < 0:
			# Kümeler tükendiyse dünyanın herhangi bir yerinde ara (deterministik).
			spot = find_free_spot(
				tiles,
				int(rng.randi_range(1, world_size)),
				int(rng.randi_range(1, world_size)),
				world_size
			)
		if spot.x < 0:
			break  # dünya dolu — beklenmiyor (SIZE² >> köy sayısı)
		villages.append(_make_village(next_id, kind, spot.x, spot.y, rng, used_names, used_owners))
		tiles[tile_key(spot.x, spot.y)] = next_id
		next_id += 1

	var start := find_free_spot(tiles, int(world_size / 2.0), int(world_size / 2.0), world_size)
	return {
		"size": world_size,
		"seed": seed_value,
		"villages": villages,
		"tiles": tiles,
		"player_start": {"x": start.x, "y": start.y},
		"counts": count_kinds(villages),
	}


# --- Köy şekli (docs/19 §3.1) ----------------------------------------------

## Yeni köyün bina sözlüğü: `main, stone, wood, iron, farm, storage` = 1; diğerleri 0.
static func starting_buildings() -> Dictionary:
	var buildings := {}
	for key in BUILDING_KEYS:
		buildings[key] = 1 if key in START_BUILDINGS_LEVEL_1 else 0
	return buildings


## Yeni köyün ordusu: 11 birim anahtarı, hepsi 0 (`docs/19` §3.1).
static func starting_units() -> Dictionary:
	var units := {}
	for key in UNIT_KEYS:
		units[key] = 0
	return units


## Yeni köyün hammaddeleri (kopya).
static func starting_resources() -> Dictionary:
	return START_RESOURCES.duplicate(true)


## Yeni köyün Köy Puanı (sv 1 başlangıç binaları) = 110.
static func starting_points() -> int:
	var total := 0
	for key in POINTS_AT_LEVEL_1.keys():
		total += int(POINTS_AT_LEVEL_1[key])
	return total


## Bonus köy çarpanları: `resource_key` 1.25, diğerleri 1.0 (`docs/19` §3.1).
static func bonus_multipliers(resource_key: String) -> Dictionary:
	var bonus := NEUTRAL_BONUS.duplicate(true)
	if bonus.has(resource_key):
		bonus[resource_key] = BONUS_MULTIPLIER
	return bonus


static func neutral_bonus() -> Dictionary:
	return NEUTRAL_BONUS.duplicate(true)


# --- Yardımcılar: alan / konum ---------------------------------------------

## Alan anahtarı: `"x,y"` (JSON'a yazılabilir, deterministik).
static func tile_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]


static func is_inside(x: int, y: int, world_size: int = SIZE) -> bool:
	return x >= 1 and x <= world_size and y >= 1 and y <= world_size


## Alan boş mu? (Üzerinde köy yok + sınır içinde.)
static func is_spot_free(tiles: Dictionary, x: int, y: int, world_size: int = SIZE) -> bool:
	if not is_inside(x, y, world_size):
		return false
	if tiles.has(tile_key(x, y)):
		return false
	if MIN_VILLAGE_DISTANCE <= 1:
		return true
	var pad := MIN_VILLAGE_DISTANCE - 1
	for dy in range(-pad, pad + 1):
		for dx in range(-pad, pad + 1):
			if dx == 0 and dy == 0:
				continue
			if tiles.has(tile_key(x + dx, y + dy)):
				return false
	return true


## `(x, y)`'ye **en yakın boş alanı** bulur (`docs/19` §6). Halkalar hâlinde deterministik tarar.
## Dünya doluysa `Vector2i(-1, -1)` döner.
static func find_free_spot(tiles: Dictionary, x: int, y: int, world_size: int = SIZE) -> Vector2i:
	var cx := clampi(x, 1, world_size)
	var cy := clampi(y, 1, world_size)
	if is_spot_free(tiles, cx, cy, world_size):
		return Vector2i(cx, cy)
	for radius in range(1, world_size + 1):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				if is_spot_free(tiles, cx + dx, cy + dy, world_size):
					return Vector2i(cx + dx, cy + dy)
	# Güvenlik ağı: satır satır tara (yalnızca çok yoğun dünyalarda gerekir).
	for ny in range(1, world_size + 1):
		for nx in range(1, world_size + 1):
			if is_spot_free(tiles, nx, ny, world_size):
				return Vector2i(nx, ny)
	return Vector2i(-1, -1)


# --- Yardımcılar: sınıflandırma --------------------------------------------

## Köy türü: "bot" | "barbarian" | "bonus" | "player".
static func kind_of(village: Dictionary) -> String:
	if bool(village.get("is_barbarian", false)):
		return "barbarian"
	var bonus = village.get("bonus", {})
	if typeof(bonus) == TYPE_DICTIONARY and not is_neutral_bonus(bonus):
		return "bonus"
	if bool(village.get("is_bot", false)):
		return "bot"
	return "player"


static func is_neutral_bonus(bonus: Dictionary) -> bool:
	for key in bonus.keys():
		if not is_equal_approx(float(bonus[key]), 1.0):
			return false
	return true


## Köy listesinin tür sayımı: `{"bot":n,"barbarian":n,"bonus":n,"total":n}`.
static func count_kinds(villages: Array) -> Dictionary:
	var counts := {"bot": 0, "barbarian": 0, "bonus": 0, "total": villages.size()}
	for village in villages:
		if typeof(village) != TYPE_DICTIONARY:
			continue
		var kind := kind_of(village)
		if counts.has(kind):
			counts[kind] = int(counts[kind]) + 1
	return counts


# --- İç yardımcılar ---------------------------------------------------------

static func _build_kinds(bots: int, barbarians: int, bonuses: int) -> Array:
	var kinds: Array = []
	for i in bots:
		kinds.append("bot")
	for i in barbarians:
		kinds.append("barbarian")
	for i in bonuses:
		kinds.append("bonus")
	return kinds


## Fisher–Yates; **global rng değil**, verilen `RandomNumberGenerator` kullanılır.
static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = items[i]
		items[i] = items[j]
		items[j] = tmp


static func _cluster_centers(world_size: int, rng: RandomNumberGenerator) -> Array:
	var centers: Array = []
	var half := int(CLUSTER_SIZE / 2.0)
	var i := 0
	while i * CLUSTER_SIZE + half <= world_size:
		var j := 0
		while j * CLUSTER_SIZE + half <= world_size:
			var cx := i * CLUSTER_SIZE + half + rng.randi_range(-CLUSTER_JITTER, CLUSTER_JITTER)
			var cy := j * CLUSTER_SIZE + half + rng.randi_range(-CLUSTER_JITTER, CLUSTER_JITTER)
			centers.append(Vector2i(clampi(cx, 1, world_size), clampi(cy, 1, world_size)))
			j += 1
		i += 1
	return centers


static func _spot_in_cluster(tiles: Dictionary, center: Vector2i, world_size: int, rng: RandomNumberGenerator) -> Vector2i:
	for attempt in MAX_PLACEMENT_ATTEMPTS:
		var x := clampi(center.x + rng.randi_range(-CLUSTER_SPREAD, CLUSTER_SPREAD), 1, world_size)
		var y := clampi(center.y + rng.randi_range(-CLUSTER_SPREAD, CLUSTER_SPREAD), 1, world_size)
		if is_spot_free(tiles, x, y, world_size):
			return Vector2i(x, y)
	return Vector2i(-1, -1)


static func _make_village(
	id: int,
	kind: String,
	x: int,
	y: int,
	rng: RandomNumberGenerator,
	used_names: Dictionary,
	used_owners: Dictionary
) -> Dictionary:
	var is_barbarian := kind == "barbarian"
	var is_bonus := kind == "bonus"
	var is_bot := kind == "bot"
	var owner := BARBARIAN_OWNER
	if is_bot:
		owner = _owner_name(rng, used_owners)
	elif is_bonus:
		owner = BONUS_OWNER
	var bonus := neutral_bonus()
	if is_bonus:
		bonus = bonus_multipliers(str(BONUS_RESOURCES[rng.randi_range(0, BONUS_RESOURCES.size() - 1)]))
	var points := starting_points()
	return {
		"id": id,
		"name": _unique_name(rng, NAME_A, NAME_B, used_names, true),
		"x": x,
		"y": y,
		"owner": owner,
		"is_bot": is_bot,
		"is_barbarian": is_barbarian,
		"buildings": starting_buildings(),
		"resources": starting_resources(),
		"units": starting_units(),
		"realm_of_power": points,
		"points": points,
		"protection_until": 0,
		"conquest_protection_until": 0,
		"bonus": bonus,
		"has_statue": false,
	}


static func _owner_name(rng: RandomNumberGenerator, used_owners: Dictionary) -> String:
	return _unique_name(rng, OWNER_A, OWNER_B, used_owners, false)


static func _unique_name(
	rng: RandomNumberGenerator,
	part_a: Array,
	part_b: Array,
	used: Dictionary,
	joined: bool
) -> String:
	var separator := "" if joined else " "
	for attempt in 12:
		var name := "%s%s%s" % [part_a[rng.randi_range(0, part_a.size() - 1)], separator, part_b[rng.randi_range(0, part_b.size() - 1)]]
		if not used.has(name):
			used[name] = true
			return name
	var base := "%s%s%s" % [part_a[rng.randi_range(0, part_a.size() - 1)], separator, part_b[rng.randi_range(0, part_b.size() - 1)]]
	var suffix := 2
	while used.has("%s %d" % [base, suffix]):
		suffix += 1
	var final_name := "%s %d" % [base, suffix]
	used[final_name] = true
	return final_name
