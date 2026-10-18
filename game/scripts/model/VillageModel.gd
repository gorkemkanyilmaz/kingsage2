class_name VillageModel
extends RefCounted
## VillageModel — köy veri şekli yardımcıları (statik, durumsuz).
##
## Sözleşme: `docs/19-MOTOR-API-SOZLESMESI.md` §5 ve §3.1 (köy şeması).
## Köyler **düz Dictionary**'dir; böylece `GameState.to_dict()/from_dict()` olduğu
## gibi çalışır. Bu sınıf şekli üretir ve türetilmiş alanları (puan, vatandaş,
## Anıt durumu) hesaplar; veriyi `GameData`'dan okur.

const _RulesEngine := preload("res://scripts/rules/RulesEngine.gd")

## Yeni oyun başlangıç hammaddesi (GameState.START_RESOURCES ile aynı).
const START_RESOURCES := {"wood": 1000, "stone": 1000, "iron": 1000}

## Serbest başlangıç binalarının başlangıç seviyesi.
## ⚠️ Yardım sitesinde "yeni köy hangi binalarla ve hangi seviyede başlar" yazmıyor;
## docs/19 §3.1 örneğinde (`"main": 1, "wood": 1`) olduğu gibi serbest başlangıç
## binaları **1** kabul edildi. Bkz. ASSUMPTIONS.md #6.
const START_LEVEL := 1


## GameData autoload düğümünü (yüklenmiş halde) döndürür; yoksa null.
static func _game_data() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var node: Node = (loop as SceneTree).root.get_node_or_null("GameData")
		if node != null:
			if not node.is_loaded():
				node.load_all()
			return node
	return null


# =============================================================================
#  §5  Köy model yardımcıları
# =============================================================================

## Yeni bir köy sözlüğü üretir (docs/19 §3.1 şeması).
static func create(id: int, name: String, x: int, y: int, owner: String, is_bot: bool) -> Dictionary:
	var gd := _game_data()
	var buildings := {}
	var units := {}
	if gd != null:
		for key in gd.get_all_building_keys():
			var k := str(key)
			buildings[k] = START_LEVEL if _RulesEngine.is_free_start(k) else 0
		for key in gd.get_all_unit_keys():
			units[str(key)] = 0
	var points := _RulesEngine.village_points(buildings)
	return {
		"id": id,
		"name": name,
		"x": x,
		"y": y,
		"owner": owner,
		"is_bot": is_bot,
		"is_barbarian": false,
		"buildings": buildings,
		"resources": START_RESOURCES.duplicate(true),
		"units": units,
		"researched": {},             # birim araştırma durumu (ödenen birimler) — docs/19 §3.1
		"realm_of_power": points,     # Güç Alanı: başlangıçta tam (= köy puanı); tavan = köy puanı
		"points": points,             # türetilmiş: Σ bina puanları
		"protection_until": 0,        # unix (yeni oyuncu koruması)
		"conquest_protection_until": 0,
		"bonus_type": "",             # "" | "wood" | "stone" | "iron" | "citizen" | "training" | "production"
		"bonus": {"wood": 1.0, "stone": 1.0, "iron": 1.0},  # savaş simülatörü girdisi (docs/19 §7)
		"has_statue": false,
	}


## Binanın mevcut seviyesi (yoksa 0).
static func building_level(village: Dictionary, key: String) -> int:
	var b = village.get("buildings", {})
	if typeof(b) != TYPE_DICTIONARY:
		return 0
	return int((b as Dictionary).get(key, 0))


## Binanın seviyesini ayarlar ve türetilmiş alanları (Anıt durumu, puan, Güç Alanı
## tavanı) tazeler.
static func set_building_level(village: Dictionary, key: String, level: int) -> void:
	if typeof(village.get("buildings")) != TYPE_DICTIONARY:
		village["buildings"] = {}
	(village["buildings"] as Dictionary)[key] = level
	village["has_statue"] = building_level(village, "statue") >= 1
	refresh_points(village)
	refresh_realm(village)


## Bina seviyelerinden Köy Puanını yeniden hesaplar, `points` alanına yazar ve döndürür.
static func refresh_points(village: Dictionary) -> int:
	var b = village.get("buildings", {})
	if typeof(b) != TYPE_DICTIONARY:
		b = {}
	var p := _RulesEngine.village_points(b)
	village["points"] = p
	return p


## Güç Alanı tavanını uygular: tavan = Köy Puanı (`points`).
## Değer 0 ile tavan arasına kırpılır; alan yoksa başlangıç olarak **tam** (= points) atanır.
## (Alanın saatte %1 artışı A-EKONOMI döngüsünün işidir.)
static func refresh_realm(village: Dictionary) -> void:
	var p := refresh_points(village)
	var cur := int(village.get("realm_of_power", p))
	village["realm_of_power"] = clampi(cur, 0, p)


## Bağlı (çalışan) vatandaş toplamı = Σ bina `workersTotal`.
static func population_used(village: Dictionary) -> int:
	var gd := _game_data()
	if gd == null:
		return 0
	var b = village.get("buildings", {})
	if typeof(b) != TYPE_DICTIONARY:
		return 0
	var total := 0
	for key in (b as Dictionary).keys():
		var lvl := int((b as Dictionary)[key])
		if lvl <= 0:
			continue
		var row: Dictionary = gd.get_building_level(str(key), lvl)
		total += int(row.get("workersTotal", 0))
	return total


## Boş vatandaş = Değirmen tavanı − bağlı vatandaş.
static func population_free(village: Dictionary) -> int:
	return _RulesEngine.max_population(building_level(village, "farm")) - population_used(village)


## Anıt dikildi mi? (alan veya türetilmiş statue seviyesi)
static func has_statue(village: Dictionary) -> bool:
	return bool(village.get("has_statue", false)) or building_level(village, "statue") >= 1


## Köy tam gelişmiş mi? (TÜM binalar maksimum seviyede)
static func is_developed(village: Dictionary) -> bool:
	var gd := _game_data()
	if gd == null:
		return false
	for key in gd.get_all_building_keys():
		var k := str(key)
		if building_level(village, k) < int(gd.get_max_level(k)):
			return false
	return true
