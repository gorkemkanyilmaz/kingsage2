extends RefCounted
class_name WorldGenerator
## Deterministik dünya üreticisi — Taht ve Kılıç / **A-DUNYA**.
##
## `generate(seed, bot_count)` **aynı tohum için her zaman aynı dünyayı** üretir:
## yalnızca `RandomNumberGenerator` (+ `rng.seed`) kullanılır. **Global `randi()` / `Array.shuffle()`
## YASAK** (determinizmi bozar). Bkz. `docs/19` §2.3.
##
## Dünya: **200×200 alan** (`docs/19` §6), kıta = 100×100 alan → **4 kıta** (`docs/19` §6 kararı).
## Üretilen köyler `docs/19` §3.1 köy şekline **birebir** uyar (17 alan).
##
## Resmî kaynaklar:
##  • **Bonus köyler** (`research/text-tr/villages.txt`): her bonus köyün **tek** bonusu olur ve
##    başında **'Usta'** vardır. 6 tip: `wood|stone|iron` → +%10 ilgili hammadde,
##    `citizen` → +%10 vatandaş, `training` → +%10 hızlı eğitim, `production` → +%3 tüm hammaddeler.
##  • **Terkedilmiş köyler**: "Soyguncular köyün gelişimini devam ettirirler, **bina inşa ederler**
##    ve **askeri birimler oluştururlar**" → gelişmiş bina seviyeleri + normal 11 birim anahtarıyla ordu.
##
## Bilinmeyen oranlar ve seçilen sabitler: `game/scripts/world/ASSUMPTIONS.md`

const LordModelScript := preload("res://scripts/model/LordModel.gd")

## Dünya kenarı (alan). `WorldModel.SIZE` ile **aynı** olmalıdır (test doğrular).
const SIZE := 200

## Kıta kenarı (alan) — `docs/10` §1 / `docs/19` §6: resmî kaynak "100×100'lük bölüm bir kıtayı temsil eder".
const CONTINENT_SIZE := 100

## Yerleşim kümesi kenarı (alan). Köyler tek tek serpilmez; **kümeler** hâlinde yerleşir
## (KingsAge'de yerleşimler kıtalar içinde toplanır; miniharitada yoğunluk ancak böyle anlamlı olur).
const CLUSTER_SIZE := 25

## Bir köyün küme merkezinden en fazla sapması (± alan).
const CLUSTER_SPREAD := 18

## Küme merkezlerinin ızgara düzenini kırmak için ± sapma (alan).
const CLUSTER_JITTER := 3

## Aynı köy için yerleştirme denemesi (küme içinde).
const MAX_PLACEMENT_ATTEMPTS := 50


## Terkedilmiş (soyguncu) köy / bot köyü oranı. **VARSAYIM** (bkz. ASSUMPTIONS.md §4).
const BARBARIAN_RATIO := 1.0

## Bonus köy / bot köyü oranı. **VARSAYIM** (bkz. ASSUMPTIONS.md §4).
const BONUS_RATIO := 0.1

## Terkedilmiş köylerin sahibi (resmî terim: **Soyguncular**).
const BARBARIAN_OWNER := "Soyguncular"

## Bonus köylerin sahibi (resmî terim: **'Usta'**).
const BONUS_OWNER := "Usta"

## Bonus köy tipleri (`docs/19` §3.1) — her bonus köy **tek** tip taşır.
const BONUS_TYPES := ["wood", "stone", "iron", "citizen", "training", "production"]

## `wood|stone|iron` bonusunun ilgili hammadde çarpanı: +%10.
const BONUS_RESOURCE_PERCENT := 10

## `production` bonusu: **tüm** hammaddeler +%3.
const BONUS_PRODUCTION_PERCENT := 3

## `citizen` bonusu: +%10 vatandaş.
const BONUS_CITIZEN_PERCENT := 10

## `training` bonusu: birim eğitimi +%10 **daha hızlı** (süre bu çarpana bölünür).
const BONUS_TRAINING_PERCENT := 10

## Nötr hammadde çarpanları (bonus yoksa).
const NEUTRAL_PRODUCTION := {"wood": 1.0, "stone": 1.0, "iron": 1.0}

## İki köy arasındaki en az alan mesafesi (haritada 360x410px köy görünümü ve plaket çakışmasını önler).
const MIN_VILLAGE_DISTANCE := 9

## Yeni köyün hammaddeleri (`GameState.START_RESOURCES`).
const START_RESOURCES := {"wood": 1000, "stone": 1000, "iron": 1000}

## `docs/19` §3.1/§5: başlangıçta 1 olan **serbest** binalar; **diğerleri 0**.
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

## Bina başına **seviye başına** kümülatif puan (`data/building-points.json`, doğrusal:
## `puan(sv) = taban × sv` — `docs/15` §5.1). Tam gelişmiş köy = **10.000**.
const POINTS_PER_LEVEL := {
	"main": 20, "stone": 20, "wood": 20, "iron": 20, "storage": 20, "farm": 10,
	"barracks": 20, "wall": 20, "market": 20, "stable": 10, "hide": 10,
	"garage": 20, "snob": 100, "smith": 40, "statue": 1000,
}

## Birimin (Kışla) araştırma gereksinimi — `data/rules/units.json#research_requirements_barracks`.
## Soyguncular yalnızca **Kışla seviyesinin izin verdiği** birimleri üretebilir (resmî kaynak: "askeri
## birimler oluştururlar"). `snob` araştırılmaz (`not_researched_units`).
const BARRACKS_REQUIREMENT := {
	"farmer": 1, "spear": 1, "sword": 1, "axe": 2, "spy": 4, "bow": 5,
	"light": 7, "heavy": 16, "ram": 20, "kata": 25, "snob": 0,
}

## Terkedilmiş köylerin ulaşabileceği en yüksek **gelişim kademesi** (VARSAYIM: dağılım bilinmiyor).
const BARBARIAN_MAX_TIER := 10

## Terkedilmiş köyün "garnizon" birim ağırlıkları (0 = soyguncular bu birimi barındırmaz).
## Savunma odaklıdır; casus/kuşatma/Kont garnizonda tutulmaz. **VARSAYIM** (bkz. ASSUMPTIONS.md §4).
const BARBARIAN_UNIT_WEIGHTS := {
	"farmer": 4, "spear": 4, "sword": 3, "axe": 2, "bow": 3,
	"spy": 0, "light": 1, "heavy": 1, "ram": 0, "kata": 0, "snob": 0,
}

## Bir birim türünün garnizonda bulunma olasılığı (deterministik rng ile). **VARSAYIM**.
const BARBARIAN_UNIT_CHANCE := 0.6

## Köy adı heceleri (özgün, Türkçe) — `docs/18`.
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
static func generate(seed_value: int, bot_count: int, world_size: int = SIZE, barbarian_ratio: float = BARBARIAN_RATIO, bonus_ratio: float = BONUS_RATIO) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var bots := maxi(0, bot_count)
	var barbarians := maxi(0, int(round(float(bots) * barbarian_ratio)))
	var bonuses := maxi(0, int(round(float(bots) * bonus_ratio)))
	var total := bots + barbarians + bonuses

	var placements := _build_placements(bots, barbarians, bonuses)
	_shuffle(placements, rng)

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

	var max_coord := world_size - 1
	var current_min_dist := MIN_VILLAGE_DISTANCE
	for index in total:
		var placement: Dictionary = placements[index]
		var center: Vector2i = centers[int(cluster_order[index % cluster_order.size()])]
		var spot := Vector2i(-1, -1)
		if current_min_dist == MIN_VILLAGE_DISTANCE:
			spot = _spot_in_cluster(tiles, center, world_size, rng)
		if spot.x < 0:
			# Kümeler tükendiyse dünyanın herhangi bir yerinde ara (deterministik).
			spot = find_free_spot_with_dist(
				tiles,
				int(rng.randi_range(1, max_coord)),
				int(rng.randi_range(1, max_coord)),
				current_min_dist,
				world_size
			)
		if spot.x < 0 and current_min_dist > 1:
			# Çok yoğun dünyalarda (ör. bot_count=400 stres testi) doğrudan boş herhangi bir alan bul (O(1))
			current_min_dist = 1
			spot = find_free_spot_with_dist(
				tiles,
				int(rng.randi_range(1, max_coord)),
				int(rng.randi_range(1, max_coord)),
				1,
				world_size
			)
		if spot.x < 0:
			break  # dünya dolu — beklenmiyor (SIZE² >> köy sayısı)
		villages.append(_make_village(next_id, placement, spot.x, spot.y, rng, used_names, used_owners))
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


## Yeni köyün araştırma durumu: hiçbir birim araştırılmamış (`docs/19` §5: `researched = {}`).
static func starting_researched() -> Dictionary:
	return {}


## Yeni köyün hammaddeleri (kopya).
static func starting_resources() -> Dictionary:
	return START_RESOURCES.duplicate(true)


## Bina seviyelerinden **Köy Puanı** (`docs/15` §5.1: `Σ taban_puan × seviye`).
static func village_points(buildings: Dictionary) -> int:
	var total := 0
	for key in buildings.keys():
		total += int(POINTS_PER_LEVEL.get(str(key), 0)) * int(buildings[key])
	return total


## Yeni köyün Köy Puanı (serbest binalar sv 1) = **110**.
static func starting_points() -> int:
	return village_points(starting_buildings())


## Terkedilmiş köyün bina sözlüğü — gelişim kademesine göre (soyguncular **bina inşa eder**).
## Yalnızca çekirdek + Kışla + Sur + Gizli Depo gelişir; Market/Katır/Simyager/Köşk/Kuyumcu/Anıt = 0.
static func barbarian_buildings(tier: int) -> Dictionary:
	var buildings := {}
	for key in BUILDING_KEYS:
		buildings[key] = 0
	for key in ["main", "stone", "wood", "iron", "farm", "storage", "barracks", "wall", "hide"]:
		buildings[key] = clampi(tier, 1, int(MAX_LEVELS.get(key, 1)))
	return buildings


## Terkedilmiş köyün ordusu (11 normal birim anahtarı; özel "soyguncu" anahtarı **yoktur**).
## Miktar köyün gelişimine (kademe) göre ölçeklenir ve **deterministiktir**.
## Yalnızca Kışla seviyesinin izin verdiği birimler üretilir.
static func barbarian_units(tier: int, barracks_level: int, rng: RandomNumberGenerator) -> Dictionary:
	var units := starting_units()
	var eligible: Array = []
	for key in UNIT_KEYS:
		if int(BARBARIAN_UNIT_WEIGHTS.get(key, 0)) <= 0:
			continue
		if int(BARRACKS_REQUIREMENT.get(key, 999)) <= barracks_level:
			eligible.append(key)
	for key in eligible:
		if rng.randf() < BARBARIAN_UNIT_CHANCE:
			units[key] = _barbarian_unit_count(str(key), tier, rng)
	if units_total(units) == 0 and not eligible.is_empty():
		# Garnizon asla boş kalmaz.
		var pick := str(eligible[rng.randi_range(0, eligible.size() - 1)])
		units[pick] = _barbarian_unit_count(pick, tier, rng)
	return units


## Ordudaki toplam birim sayısı.
static func units_total(units: Dictionary) -> int:
	var total := 0
	for key in units.keys():
		total += int(units[key])
	return total


## Ordusu olan birimlerin `researched` sözlüğü (soyguncular ürettiği birimi "araştırmış" sayılır).
static func researched_for_units(units: Dictionary) -> Dictionary:
	var researched := {}
	for key in units.keys():
		if int(units[key]) > 0:
			researched[str(key)] = true
	return researched


# --- Bonus köyleri (resmî etkiler) ------------------------------------------

## Bonus tipinin **hammadde** çarpanları (`docs/19` §3.1).
## `wood|stone|iron` → ilgili kaynak +%10 · `production` → tümü +%3 · diğerleri → nötr.
static func bonus_production_multipliers(bonus_type: String) -> Dictionary:
	var multipliers := NEUTRAL_PRODUCTION.duplicate(true)
	if multipliers.has(bonus_type):
		multipliers[bonus_type] = 1.0 + float(BONUS_RESOURCE_PERCENT) / 100.0
	elif bonus_type == "production":
		var factor := 1.0 + float(BONUS_PRODUCTION_PERCENT) / 100.0
		for key in multipliers.keys():
			multipliers[key] = factor
	return multipliers


## `citizen` bonusu: vatandaş çarpanı (+%10), diğerleri 1.0.
static func bonus_citizen_multiplier(bonus_type: String) -> float:
	if bonus_type == "citizen":
		return 1.0 + float(BONUS_CITIZEN_PERCENT) / 100.0
	return 1.0


## `training` bonusu: eğitim **hız** çarpanı (+%10 hızlı) → eğitim **süresi** bu değere bölünür.
static func bonus_training_speed_multiplier(bonus_type: String) -> float:
	if bonus_type == "training":
		return 1.0 + float(BONUS_TRAINING_PERCENT) / 100.0
	return 1.0


## Bonus tipinin kısa Türkçe açıklaması (arayüz için).
static func bonus_effect_text(bonus_type: String) -> String:
	match bonus_type:
		"wood":
			return "Odun üretimi +%d" % BONUS_RESOURCE_PERCENT
		"stone":
			return "Taş üretimi +%d" % BONUS_RESOURCE_PERCENT
		"iron":
			return "Demir üretimi +%d" % BONUS_RESOURCE_PERCENT
		"citizen":
			return "Vatandaş sayısı +%d" % BONUS_CITIZEN_PERCENT
		"training":
			return "Birim eğitimi +%d daha hızlı" % BONUS_TRAINING_PERCENT
		"production":
			return "Tüm hammadde üretimi +%d" % BONUS_PRODUCTION_PERCENT
	return ""


## Bonus tipi geçerli mi? ("" = bonus yok.)
static func is_valid_bonus_type(bonus_type: String) -> bool:
	return bonus_type == "" or BONUS_TYPES.has(bonus_type)


# --- Yardımcılar: alan / konum ---------------------------------------------

## Alan anahtarı: `"x,y"` (JSON'a yazılabilir, deterministik).
static func tile_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]


static func is_inside(x: int, y: int, world_size: int = SIZE) -> bool:
	return x >= 1 and x <= world_size and y >= 1 and y <= world_size


## Alan boş mu? (Üzerinde köy yok + sınır içinde.)
static func is_spot_free(tiles: Dictionary, x: int, y: int, world_size: int = SIZE) -> bool:
	return is_spot_free_dist(tiles, x, y, MIN_VILLAGE_DISTANCE, world_size)


static func is_spot_free_dist(tiles: Dictionary, x: int, y: int, min_dist: int, world_size: int = SIZE) -> bool:
	if not is_inside(x, y, world_size):
		return false
	if tiles.has(tile_key(x, y)):
		return false
	if min_dist <= 1:
		return true
	var pad := min_dist - 1
	for dy in range(-pad, pad + 1):
		for dx in range(-pad, pad + 1):
			var tx := x + dx
			var ty := y + dy
			if tx < 1 or tx > world_size or ty < 1 or ty > world_size:
				continue
			if tiles.has(tile_key(tx, ty)):
				return false
	return true


static func find_free_spot_with_dist(tiles: Dictionary, x: int, y: int, min_dist: int, world_size: int = SIZE) -> Vector2i:
	var cx := clampi(x, 1, world_size)
	var cy := clampi(y, 1, world_size)
	if is_spot_free_dist(tiles, cx, cy, min_dist, world_size):
		return Vector2i(cx, cy)
	var max_r := mini(world_size, 80 if min_dist > 1 else world_size)
	for radius in range(1, max_r + 1):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var nx := cx + dx
				var ny := cy + dy
				if nx >= 1 and nx <= world_size and ny >= 1 and ny <= world_size:
					if is_spot_free_dist(tiles, nx, ny, min_dist, world_size):
						return Vector2i(nx, ny)
	# Güvenlik ağı: min_dist 1 iken tüm haritayı satır satır tara
	if min_dist <= 1:
		for ny in range(1, world_size + 1):
			for nx in range(1, world_size + 1):
				if is_spot_free_dist(tiles, nx, ny, min_dist, world_size):
					return Vector2i(nx, ny)
	return Vector2i(-1, -1)


## `(x, y)`'ye **en yakın boş alanı** bulur (`docs/19` §6). Halkalar hâlinde deterministik tarar.
## Dünya doluysa `Vector2i(-1, -1)` döner.
static func find_free_spot(tiles: Dictionary, x: int, y: int, world_size: int = SIZE) -> Vector2i:
	return find_free_spot_with_dist(tiles, x, y, MIN_VILLAGE_DISTANCE, world_size)


# --- Yardımcılar: sınıflandırma --------------------------------------------

## Köy türü: "bot" | "barbarian" | "bonus" | "player".
static func kind_of(village: Dictionary) -> String:
	if bool(village.get("is_barbarian", false)):
		return "barbarian"
	if not str(village.get("bonus_type", "")).is_empty():
		return "bonus"
	if bool(village.get("is_bot", false)):
		return "bot"
	return "player"


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

## Yerleştirme listesi: `[{"kind": "bot"|"barbarian"|"bonus", "bonus_type": ""|...}, ...]`
## Bonus tipleri sırayla (round-robin) dağıtılır → `bonus_count >= 6` ise **6 tipin tamamı** bulunur.
static func _build_placements(bots: int, barbarians: int, bonuses: int) -> Array:
	var placements: Array = []
	for i in bots:
		placements.append({"kind": "bot", "bonus_type": ""})
	for i in barbarians:
		placements.append({"kind": "barbarian", "bonus_type": ""})
	for i in bonuses:
		placements.append({"kind": "bonus", "bonus_type": str(BONUS_TYPES[i % BONUS_TYPES.size()])})
	return placements


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
	var max_coord := world_size - 1
	for attempt in MAX_PLACEMENT_ATTEMPTS:
		var x := clampi(center.x + rng.randi_range(-CLUSTER_SPREAD, CLUSTER_SPREAD), 1, max_coord)
		var y := clampi(center.y + rng.randi_range(-CLUSTER_SPREAD, CLUSTER_SPREAD), 1, max_coord)
		if is_spot_free(tiles, x, y, world_size):
			return Vector2i(x, y)
	return Vector2i(-1, -1)


## Terkedilmiş köyün gelişim kademesi (1..`BARBARIAN_MAX_TIER`). Küçük köyler daha sık:
## `tier = 1 + floor(randf()^1.5 × MAX)`. **Dağılım VARSAYIM** (kaynakta yok).
static func _barbarian_tier(rng: RandomNumberGenerator) -> int:
	var roll := pow(rng.randf(), 1.5)
	return clampi(1 + int(floor(roll * float(BARBARIAN_MAX_TIER))), 1, BARBARIAN_MAX_TIER)


static func _barbarian_unit_count(unit_key: String, tier: int, rng: RandomNumberGenerator) -> int:
	var weight := maxi(1, int(BARBARIAN_UNIT_WEIGHTS.get(unit_key, 1)))
	var roll := rng.randf_range(0.5, 1.5)
	return maxi(1, int(round(float(weight) * float(tier) * roll)))


static func _make_village(
	id: int,
	placement: Dictionary,
	x: int,
	y: int,
	rng: RandomNumberGenerator,
	used_names: Dictionary,
	used_owners: Dictionary
) -> Dictionary:
	var kind := str(placement.get("kind", "bot"))
	var is_barbarian := kind == "barbarian"
	var is_bonus := kind == "bonus"
	var is_bot := kind == "bot"
	var owner := BARBARIAN_OWNER
	var buildings := starting_buildings()
	var units := starting_units()
	var researched := starting_researched()
	var bonus_type := ""
	var is_bandit := false
	var bandit_level := 0
	var custom_name := _unique_name(rng, NAME_A, NAME_B, used_names, true)
	if is_bot:
		is_bandit = true
		bandit_level = clampi(1 + ((id * 7 + 3) % 10), 1, 10)
		var btmpl := LordModelScript.bandit_template(bandit_level)
		owner = str(btmpl.get("owner", "Haydutlar"))
		custom_name = str(btmpl.get("name", "Haydut Köyü Sv.%d" % bandit_level))
		buildings = (btmpl.get("buildings", buildings) as Dictionary).duplicate(true)
		units = (btmpl.get("units", units) as Dictionary).duplicate(true)
		researched = researched_for_units(units)
	elif is_bonus:
		owner = BONUS_OWNER
		bonus_type = str(placement.get("bonus_type", ""))
	elif is_barbarian:
		# Soyguncular: bina inşa eder ve askerî birim üretir.
		var tier := _barbarian_tier(rng)
		buildings = barbarian_buildings(tier)
		units = barbarian_units(tier, int(buildings.get("barracks", 0)), rng)
		researched = researched_for_units(units)
	var points := village_points(buildings)
	if is_bandit:
		points = int(LordModelScript.bandit_template(bandit_level).get("points", points))
	return {
		"id": id,
		"name": custom_name,
		"x": x,
		"y": y,
		"owner": owner,
		"is_bot": is_bot,
		"is_bandit": is_bandit,
		"bandit_level": bandit_level,
		"bandit_initialized": is_bandit,
		"is_barbarian": is_barbarian,
		"buildings": buildings,
		"resources": starting_resources(),
		"units": units,
		"researched": researched,
		"realm_of_power": points,
		"points": points,
		"protection_until": 0,
		"conquest_protection_until": 0,
		"bonus_type": bonus_type,
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
