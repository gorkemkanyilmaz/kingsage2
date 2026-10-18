extends RefCounted
## Population — Değirmen (farm) → maksimum vatandaş ve bina vatandaş tüketimi (Taht ve Kılıç).
##
## Sahip: **A-EKONOMI** · Sözleşme: `docs/19-MOTOR-API-SOZLESMESI.md` §4.3, §5, §7b.
## Kaynaklar: `docs/03` §1/§4, `docs/04` §5, `game/data/rules/production.json`
## (`curves.mill_max_citizens`), `game/data/buildings.json` (`workersLevel` / `workersTotal`).
##
## ## Model (kaynakla doğrulanmış)
##  • **Toplam vatandaş** yalnızca Değirmen seviyesiyle belirlenir:
##      `max = RulesEngine.max_population(farm_level)` (maks 50.000).
##  • **Çalışan (bağlı) vatandaş** = Σ bina `workersTotal` (kümülatif). Bkz. `VillageModel.population_used`.
##  • **Boş vatandaş** = `max − çalışan`. Boş vatandaş yoksa **inşa/eğitim bloke** olur.
##  • Yükseltme, hedef seviyenin **`workersLevel`** kadarını (o seviyede eklenen) bağlar.
##  • Vatandaş **tükenmez, bağlanır**; bina/birlik yok olunca serbest kalır.
##  • Bonus köy `citizen` → **+%10** maksimum vatandaş (docs/02 §4).
##
## Birimlerin (ordu) bağladığı vatandaş **A-ORDU**'nun işidir; bu modül yalnızca **bina**
## vatandaşını hesaba katar (`VillageModel.population_used` ile aynı tanım).

const RE := preload("res://scripts/rules/RulesEngine.gd")
const VM := preload("res://scripts/model/VillageModel.gd")


static func _game_data() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var node: Node = (loop as SceneTree).root.get_node_or_null("GameData")
		if node != null:
			if node.has_method("is_loaded") and not node.is_loaded():
				node.load_all()
			return node
	return null


static func _round_half_up(x: float) -> int:
	return int(floor(x + 0.5))


# =============================================================================
#  Değirmen → maksimum vatandaş
# =============================================================================

## Değirmenin sağladığı maksimum vatandaş (bonus `citizen` → +%10).
static func max_citizens(village: Dictionary) -> int:
	var base := RE.max_population(VM.building_level(village, "farm"))
	if str(village.get("bonus_type", "")) == "citizen":
		base = _round_half_up(float(base) * 1.10)
	return base


## Çalışan (bağlı) vatandaş = Σ bina `workersTotal`.
static func used_citizens(village: Dictionary) -> int:
	return VM.population_used(village)


## Boş vatandaş = maksimum − çalışan. Negatif olabilir (aşırı bağlanma durumu).
static func free_citizens(village: Dictionary) -> int:
	return max_citizens(village) - used_citizens(village)


# =============================================================================
#  Bina vatandaş tüketimi
# =============================================================================

## `key` binasının `level` seviyesinde **eklediği** vatandaş (`workersLevel`).
## Bilinmeyen bina/seviye → 0.
static func workers_needed(key: String, level: int) -> int:
	var gd := _game_data()
	if gd == null or level < 1:
		return 0
	var row: Dictionary = gd.get_building_level(key, level)
	return int(row.get("workersLevel", 0))


## `key` binasının `level` seviyesindeki **kümülatif** vatandaş (`workersTotal`).
static func workers_total(key: String, level: int) -> int:
	var gd := _game_data()
	if gd == null or level < 1:
		return 0
	var row: Dictionary = gd.get_building_level(key, level)
	return int(row.get("workersTotal", 0))


# =============================================================================
#  Kuyruk ile birlikte vatandaş kontrolü
# =============================================================================

## Bir köyün kuyruğundaki (henüz uygulanmamış) bina işlerinin bağlayacağı vatandaş toplamı.
## `state.queues` içindeki `type=="build"` + aynı `village_id` öğeleri sayılır.
static func pending_workers(state: Dictionary, village: Dictionary) -> int:
	var vid := int(village.get("id", -1))
	var queues = state.get("queues", [])
	if typeof(queues) != TYPE_ARRAY:
		return 0
	var total := 0
	for item in (queues as Array):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if str((item as Dictionary).get("type", "")) != "build":
			continue
		if int((item as Dictionary).get("village_id", -1)) != vid:
			continue
		total += workers_needed(str((item as Dictionary).get("key", "")), int((item as Dictionary).get("target_level", 0)))
	return total


## Yeni bir yükseltme (`key`, `target_level`) için boş vatandaş yeterli mi?
## Kuyruktaki bekleyen işler de hesaba katılır: `used + pending + need ≤ max`.
static func can_afford_citizens(state: Dictionary, village: Dictionary, key: String, target_level: int) -> bool:
	var need := workers_needed(key, target_level)
	var used := used_citizens(village)
	var pending := pending_workers(state, village)
	return used + pending + need <= max_citizens(village)
