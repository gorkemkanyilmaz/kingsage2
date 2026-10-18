extends RefCounted
class_name WorldModel
## Dünya / harita modeli — Taht ve Kılıç / **A-DUNYA**.
##
## **Sözleşme: `docs/19` §6** (imzalar birebir uyar; tek sapma `travel_seconds`'in
## `slowest_unit_speed` parametresinin `float` olmasıdır — gerekçe: birim hızları 4.5 / 2.25 / 2.75
## gibi ondalıklıdır ve `int` tipi sessizce kırpar. Bkz. `ASSUMPTIONS.md` §7).
##
## Kaynak: `docs/10` (harita, kıtalar, world ayarları), `docs/05` (birim hızları),
## `docs/09` (hareketler), `docs/19` §2 (determinizm) ve §3.1 (köy şekli).
##
## Üretim `WorldGenerator`'da, yolculuk `Travel`'da; bu dosya sözleşmedeki **dış API** ve
## harita sorgularıdır (mesafe, komşuluk, miniharita, doğrulama).
##
## İç bağımlılıklar `preload` ile alınır → global sınıf önbelleği (`.godot/`) tazelenmemiş olsa bile
## testler çalışır. Döngüsel bağımlılık yoktur (WorldModel → WorldGenerator / Travel, tersi değil).

const Generator := preload("res://scripts/world/WorldGenerator.gd")
const TravelHelper := preload("res://scripts/world/Travel.gd")

## Dünya kenarı (alan) — **karar: 200×200** (`docs/19` §6, `TASKS-CODE.md` S-8).
## `WorldGenerator.SIZE` ile aynı olmalıdır (test doğrular).
const SIZE := 200

## Kıta kenarı (alan) — `docs/10` §1: "Kıta (continent) = 100 × 100 alan".
## `WorldGenerator.CONTINENT_SIZE` ile aynı olmalıdır (test doğrular).
const CONTINENT_SIZE := 100

## Miniharitanın varsayılan ızgara hücresi (alan).
const DEFAULT_MINIMAP_CELL := 10

## Komşuluk sorgusunun varsayılan yarıçapı (alan).
const DEFAULT_NEIGHBOR_RADIUS := 10

## Yeni oyuncunun köy adı / sahibi (özgün, Türkçe).
const PLAYER_DEFAULT_NAME := "Başkent"
const PLAYER_DEFAULT_OWNER := "Kral"


# --- §6: Sözleşme imzaları --------------------------------------------------

## İki koordinat arasındaki Öklid mesafesi (alan).
static func distance(a_x: int, a_y: int, b_x: int, b_y: int) -> float:
	return TravelHelper.distance(a_x, a_y, b_x, b_y)


## Yolculuk süresi (saniye). `slowest_unit_speed` = ordudaki **en yavaş** birimin
## "alan başına dakika" değeri (`Travel.slowest_speed(units)`).
## `GameConfig.unit_speed` sonucu böler (`docs/19` §2.4).
static func travel_seconds(from_x: int, from_y: int, to_x: int, to_y: int, slowest_unit_speed: float) -> float:
	return TravelHelper.travel_seconds(from_x, from_y, to_x, to_y, slowest_unit_speed)


## Deterministik dünya üretimi. Dönüş: `WorldGenerator.generate()` (bkz. ASSUMPTIONS.md §5).
static func generate_world(seed: int, bot_count: int) -> Dictionary:
	return Generator.generate(seed, bot_count, SIZE)


## `(x, y)`'ye en yakın **boş** alan (`docs/19` §6). Dünya doluysa `Vector2i(-1, -1)`.
static func find_free_spot(world: Dictionary, x: int, y: int) -> Vector2i:
	return Generator.find_free_spot(tiles_of(world), x, y, size_of(world))


# --- Alan / koordinat yardımcıları -----------------------------------------

static func tile_key(x: int, y: int) -> String:
	return Generator.tile_key(x, y)


## Dünya kenarı (eksikse `SIZE`).
static func size_of(world: Dictionary) -> int:
	return int(world.get("size", SIZE))


## Dolu alanlar: `"x,y"` → köy id.
static func tiles_of(world: Dictionary) -> Dictionary:
	var tiles = world.get("tiles", {})
	return tiles if typeof(tiles) == TYPE_DICTIONARY else {}


static func is_inside(x: int, y: int, world_size: int = SIZE) -> bool:
	return Generator.is_inside(x, y, world_size)


## Alan dünyanın içinde ve boş mu?
static func is_tile_free(world: Dictionary, x: int, y: int) -> bool:
	return Generator.is_spot_free(tiles_of(world), x, y, size_of(world))


## Koordinattaki köyün id'si; yoksa 0.
static func village_id_at(world: Dictionary, x: int, y: int) -> int:
	return int(tiles_of(world).get(tile_key(x, y), 0))


## Koordinattaki köy; yoksa boş sözlük.
static func village_at(world: Dictionary, x: int, y: int) -> Dictionary:
	return get_village(world, village_id_at(world, x, y))


## Id ile köy; yoksa boş sözlük.
static func get_village(world: Dictionary, village_id: int) -> Dictionary:
	if village_id <= 0:
		return {}
	for village in villages_of(world):
		if typeof(village) == TYPE_DICTIONARY and int((village as Dictionary).get("id", -1)) == village_id:
			return village
	return {}


static func villages_of(world: Dictionary) -> Array:
	var list = world.get("villages", [])
	return list if typeof(list) == TYPE_ARRAY else []


## `id → köy` indeksi (kopya üretmez; köy sözlükleri paylaşılır).
static func villages_by_id(world: Dictionary) -> Dictionary:
	var index: Dictionary = {}
	for village in villages_of(world):
		if typeof(village) != TYPE_DICTIONARY:
			continue
		index[int((village as Dictionary).get("id", -1))] = village
	return index


# --- Sınıflandırma ----------------------------------------------------------

## Köy türü: "bot" | "barbarian" | "bonus" | "player".
static func kind_of(village: Dictionary) -> String:
	return Generator.kind_of(village)


## Tür sayımı. `{"bot","barbarian","bonus","total"}`.
static func count_kinds(world: Dictionary) -> Dictionary:
	return Generator.count_kinds(villages_of(world))


## Verilen türdeki köyler (id'ye göre artan). `kind` = "bot"|"barbarian"|"bonus"|"player"|"all".
static func villages_of_kind(world: Dictionary, kind: String) -> Array:
	var out: Array = []
	for village in villages_of(world):
		if typeof(village) != TYPE_DICTIONARY:
			continue
		if kind == "all" or kind_of(village) == kind:
			out.append(village)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("id", 0)) < int(b.get("id", 0)))
	return out


# --- Komşuluk ---------------------------------------------------------------

## `(x, y)` civarındaki köyler, **mesafeye göre artan** (eşitlikte id'ye göre) sıralı.
## `limit > 0` ise ilk `limit` köy döner.
static func neighbors(
	world: Dictionary,
	x: int,
	y: int,
	radius: int = DEFAULT_NEIGHBOR_RADIUS,
	include_self: bool = true,
	limit: int = 0
) -> Array:
	var found: Array = []
	for village in villages_of(world):
		if typeof(village) != TYPE_DICTIONARY:
			continue
		var vx := int((village as Dictionary).get("x", 0))
		var vy := int((village as Dictionary).get("y", 0))
		if not include_self and vx == x and vy == y:
			continue
		var d := distance(x, y, vx, vy)
		if radius > 0 and d > float(radius):
			continue
		found.append({"village": village, "distance": d})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da := float(a["distance"])
		var db := float(b["distance"])
		if not is_equal_approx(da, db):
			return da < db
		return int((a["village"] as Dictionary).get("id", 0)) < int((b["village"] as Dictionary).get("id", 0))
	)
	var out: Array = []
	for entry in found:
		if limit > 0 and out.size() >= limit:
			break
		out.append(entry["village"])
	return out


## Aynı kıtadaki köyler (`docs/10` §1).
static func continent_villages(world: Dictionary, x: int, y: int) -> Array:
	var id := continent_id(x, y)
	var out: Array = []
	for village in villages_of(world):
		if typeof(village) != TYPE_DICTIONARY:
			continue
		if continent_id(int((village as Dictionary).get("x", 0)), int((village as Dictionary).get("y", 0))) == id:
			out.append(village)
	return out


# --- Kıta -------------------------------------------------------------------

## Kıta numarası: `row * 10 + col`, `row = floor(y / 100)`, `col = floor(x / 100)`
## (`docs/10` §1 örneği: `499|506` → **K54**). Bkz. ASSUMPTIONS.md §2 (metin ile örnek çelişiyor).
static func continent_id(x: int, y: int) -> int:
	var col := int(floor(float(x) / float(CONTINENT_SIZE)))
	var row := int(floor(float(y) / float(CONTINENT_SIZE)))
	return row * 10 + col


## Kıta etiketi: "K54" (2 haneli, sıfır dolgulu).
static func continent_of(x: int, y: int) -> String:
	return "K%02d" % continent_id(x, y)


## Dünyadaki kıta dağılımı: `{"K00": n, ...}` (id'ye göre sıralı sözlük).
static func continent_distribution(world: Dictionary) -> Dictionary:
	var counts: Dictionary = {}
	for village in villages_of(world):
		if typeof(village) != TYPE_DICTIONARY:
			continue
		var label := continent_of(int((village as Dictionary).get("x", 0)), int((village as Dictionary).get("y", 0)))
		counts[label] = int(counts.get(label, 0)) + 1
	var labels := counts.keys()
	labels.sort()
	var ordered: Dictionary = {}
	for label in labels:
		ordered[label] = counts[label]
	return ordered


# --- Miniharita -------------------------------------------------------------

## Izgara → **köy yoğunluğu** (satır satır int dizisi). Toplam = köy sayısı.
## `cell_size` alan cinsindendir; hücre sayısı `ceil(size / cell_size)`.
static func minimap_density(world: Dictionary, cell_size: int = DEFAULT_MINIMAP_CELL) -> Array:
	var count := minimap_cell_count(world, cell_size)
	var grid: Array = []
	for _row in count:
		var line: Array = []
		for _col in count:
			line.append(0)
		grid.append(line)
	for village in villages_of(world):
		if typeof(village) != TYPE_DICTIONARY:
			continue
		var cell := _cell_of(int((village as Dictionary).get("x", 0)), int((village as Dictionary).get("y", 0)), cell_size)
		grid[cell.y][cell.x] = int(grid[cell.y][cell.x]) + 1
	return grid


## Izgara → hücrenin **baskın köy türü** ("none"|"barbarian"|"bonus"|"bot"|"player").
## Eşitlikte öncelik: barbarian > bonus > bot > player.
static func minimap_kind_grid(world: Dictionary, cell_size: int = DEFAULT_MINIMAP_CELL) -> Array:
	var count := minimap_cell_count(world, cell_size)
	var grid: Array = []
	var tally: Array = []
	for _row in count:
		var line: Array = []
		var line_tally: Array = []
		for _col in count:
			line.append("none")
			line_tally.append({"barbarian": 0, "bonus": 0, "bot": 0, "player": 0})
		grid.append(line)
		tally.append(line_tally)
	for village in villages_of(world):
		if typeof(village) != TYPE_DICTIONARY:
			continue
		var cell := _cell_of(int((village as Dictionary).get("x", 0)), int((village as Dictionary).get("y", 0)), cell_size)
		var kind := kind_of(village)
		var bucket: Dictionary = tally[cell.y][cell.x]
		if bucket.has(kind):
			bucket[kind] = int(bucket[kind]) + 1
	for gy in count:
		for gx in count:
			var bucket: Dictionary = tally[gy][gx]
			var best := "none"
			var best_count := 0
			for kind in ["barbarian", "bonus", "bot", "player"]:
				var kind_count := int(bucket.get(kind, 0))
				if kind_count > best_count:
					best_count = kind_count
					best = kind
			grid[gy][gx] = best
	return grid


## Miniharita ızgarasının kenar cinsinden hücre sayısı (`ceil(size / cell_size)`).
static func minimap_cell_count(world: Dictionary, cell_size: int = DEFAULT_MINIMAP_CELL) -> int:
	return int(ceil(float(size_of(world)) / float(maxi(1, cell_size))))


# --- Determinizm / bütünlük -------------------------------------------------

## Dünyanın deterministik parmak izi (aynı tohum → aynı hash).
static func world_hash(world: Dictionary) -> String:
	return var_to_bytes(world).hex_encode().sha256_text()


## Sözleşmeye (§3.1) göre doğrular; **sorun listesi** döner (boş = sağlam).
static func validate_world(world: Dictionary) -> Array:
	var problems: Array = []
	var size := size_of(world)
	if size <= 0:
		problems.append("dünya boyutu geçersiz: %d" % size)
	var villages := villages_of(world)
	if not world.has("villages"):
		problems.append("'villages' anahtarı yok")
	if not world.has("tiles"):
		problems.append("'tiles' anahtarı yok")
	var tiles := tiles_of(world)
	var seen_ids: Dictionary = {}
	var seen_coords: Dictionary = {}
	for village in villages:
		if typeof(village) != TYPE_DICTIONARY:
			problems.append("köy bir sözlük değil: %s" % [typeof(village)])
			continue
		var v: Dictionary = village
		for key in _VILLAGE_KEYS:
			if not v.has(key):
				problems.append("köy %s: '%s' alanı eksik" % [v.get("id", "?"), key])
		var id := int(v.get("id", -1))
		if id <= 0:
			problems.append("köy id'si geçersiz: %d" % id)
		if seen_ids.has(id):
			problems.append("köy id'si tekrar ediyor: %d" % id)
		seen_ids[id] = true
		var x := int(v.get("x", 0))
		var y := int(v.get("y", 0))
		if not is_inside(x, y, size):
			problems.append("köy %d: koordinat sınır dışı (%d|%d)" % [id, x, y])
		var coord := tile_key(x, y)
		if seen_coords.has(coord):
			problems.append("koordinat çakışması: %s (%d ve %d)" % [coord, seen_coords[coord], id])
		seen_coords[coord] = id
		if tiles.has(coord):
			if int(tiles[coord]) != id:
				problems.append("köy %d: 'tiles' kaydı uyuşmuyor (%s → %d)" % [id, coord, int(tiles[coord])])
		else:
			problems.append("köy %d: 'tiles' içinde kaydı yok (%s)" % [id, coord])
		_problems_for_buildings(id, v.get("buildings", {}), problems)
		_problems_for_number_map(id, "resources", v.get("resources", {}), _RESOURCE_KEYS, true, problems)
		_problems_for_number_map(id, "units", v.get("units", {}), Generator.UNIT_KEYS, true, problems)
		_problems_for_number_map(id, "bonus", v.get("bonus", {}), _RESOURCE_KEYS, false, problems)
		for flag in ["is_bot", "is_barbarian", "has_statue"]:
			if typeof(v.get(flag)) != TYPE_BOOL:
				problems.append("köy %d: '%s' bool değil" % [id, flag])
		for number in ["points", "realm_of_power", "protection_until", "conquest_protection_until"]:
			if typeof(v.get(number)) != TYPE_INT:
				problems.append("köy %d: '%s' int değil" % [id, number])
	if tiles.size() != villages.size():
		problems.append("'tiles' sayısı (%d) köy sayısına (%d) eşit değil" % [tiles.size(), villages.size()])
	for key in tiles.keys():
		var parts := str(key).split(",")
		if parts.size() != 2:
			problems.append("'tiles' anahtarı geçersiz: %s" % [key])
			continue
		var tx := int(parts[0])
		var ty := int(parts[1])
		if not is_inside(tx, ty, size):
			problems.append("'tiles' anahtarı sınır dışı: %s" % [key])
		if not seen_ids.has(int(tiles[key])):
			problems.append("'tiles' bilinmeyen köy id'sine işaret ediyor: %s → %d" % [key, int(tiles[key])])
	return problems


## Bina anahtarının maksimum seviyesi (`GameData` varsa oradan, yoksa `data/buildings.json` kopyası).
static func max_level(key: String) -> int:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		var data := tree.root.get_node_or_null(^"GameData")
		if data != null and data.has_method("get_max_level"):
			var value := int(data.get_max_level(key))
			if value > 0:
				return value
	return int(Generator.MAX_LEVELS.get(key, 0))


# --- Yeni oyuncu köyü -------------------------------------------------------

## Oyuncunun ilk köyünü (`docs/19` §3.1) üretir — `player_start` alanına kurulur.
## **Dünyaya eklenmez**; çağıran (`Boot`) `GameState.add_village()` ile ekler.
## `protection_until` 0 bırakılır: koruma süresi **oyun zamanı** ile `GameConfig`'ten hesaplanır
## (determinizm için üretici sistem saatini kullanmaz — bkz. ASSUMPTIONS.md §6).
static func player_village(
	world: Dictionary,
	name: String = PLAYER_DEFAULT_NAME,
	owner: String = PLAYER_DEFAULT_OWNER,
	village_id: int = 1
) -> Dictionary:
	var start = world.get("player_start", {"x": int(SIZE / 2.0), "y": int(SIZE / 2.0)})
	var spot := Vector2i(int(start.get("x", int(SIZE / 2.0))), int(start.get("y", int(SIZE / 2.0))))
	var points := Generator.starting_points()
	return {
		"id": village_id,
		"name": name,
		"x": spot.x,
		"y": spot.y,
		"owner": owner,
		"is_bot": false,
		"is_barbarian": false,
		"buildings": Generator.starting_buildings(),
		"resources": Generator.starting_resources(),
		"units": Generator.starting_units(),
		"realm_of_power": 0,
		"points": points,
		"protection_until": 0,
		"conquest_protection_until": 0,
		"bonus": Generator.neutral_bonus(),
		"has_statue": false,
	}


# --- İç yardımcılar ---------------------------------------------------------

const _VILLAGE_KEYS := [
	"id", "name", "x", "y", "owner", "is_bot", "is_barbarian", "buildings", "resources",
	"units", "realm_of_power", "points", "protection_until", "conquest_protection_until",
	"bonus", "has_statue",
]
const _RESOURCE_KEYS := ["wood", "stone", "iron"]


static func _cell_of(x: int, y: int, cell_size: int) -> Vector2i:
	var step := maxi(1, cell_size)
	return Vector2i(int((x - 1) / step), int((y - 1) / step))


static func _problems_for_buildings(id: int, raw, problems: Array) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		problems.append("köy %d: 'buildings' sözlük değil" % id)
		return
	var buildings: Dictionary = raw
	for key in Generator.BUILDING_KEYS:
		if not buildings.has(key):
			problems.append("köy %d: bina '%s' eksik" % [id, key])
			continue
		if typeof(buildings[key]) != TYPE_INT:
			problems.append("köy %d: bina '%s' int değil" % [id, key])
			continue
		var level := int(buildings[key])
		if level < 0:
			problems.append("köy %d: bina '%s' negatif (%d)" % [id, key, level])
		var top := max_level(key)
		if top > 0 and level > top:
			problems.append("köy %d: bina '%s' maksimum seviyeyi aşıyor (%d > %d)" % [id, key, level, top])
	if buildings.size() != Generator.BUILDING_KEYS.size():
		problems.append("köy %d: bina anahtar sayısı %d (beklenen %d)" % [id, buildings.size(), Generator.BUILDING_KEYS.size()])


## `raw` sözlüğünde `keys` anahtarları var mı ve sayısal mı? (`expect_int`: yalnızca int / int+float)
static func _problems_for_number_map(id: int, label: String, raw, keys: Array, expect_int: bool, problems: Array) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		problems.append("köy %d: '%s' sözlük değil" % [id, label])
		return
	var data: Dictionary = raw
	for key in keys:
		if not data.has(key):
			problems.append("köy %d: '%s.%s' eksik" % [id, label, key])
			continue
		var type := typeof(data[key])
		if type == TYPE_INT:
			continue
		if type == TYPE_FLOAT and not expect_int:
			continue
		problems.append("köy %d: '%s.%s' sayısal değil/yanlış tip (%s)" % [id, label, key, type])
