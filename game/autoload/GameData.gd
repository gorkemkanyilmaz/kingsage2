extends Node
## GameData — statik oyun verisi yükleyici ve sorgu API'si (Taht ve Kılıç).
##
## Yüklenen dosyalar:
##   res://data/buildings.json        — 15 bina (tam seviye tabloları)
##   res://data/units.json            — 11 birim (istatistik + gereksinimler)
##   res://data/building-points.json  — bina puan tablosu (kümülatif)
##   res://data/rules/*.json          — kural motoru verisi (A-KURAL; OPSİYONEL)
##
## `rules/` klasörü başka bir ajan tarafından sonradan doldurulacaktır; yoksa
## sessizce atlanır ve `get_rule()` boş sözlük döndürür.

const BUILDINGS_PATH := "res://data/buildings.json"
const UNITS_PATH := "res://data/units.json"
const POINTS_PATH := "res://data/building-points.json"
const RULES_DIR := "res://data/rules"

# key (String) -> bina sözlüğü
var _buildings: Dictionary = {}
var _building_order: Array = []

# key (String) -> birim sözlüğü
var _units: Dictionary = {}
var _unit_order: Array = []

# level (int) -> {"main": puan, "wood": puan, ...} (kümülatif bina puanı)
var _points_by_level: Dictionary = {}
# key (String) -> binanın ulaşabileceği maksimum puan (tablodaki en büyük değer)
var _points_max: Dictionary = {}

# kural adı (String) -> yüklenen JSON içeriği (Dictionary veya Array)
var _rules: Dictionary = {}

var _loaded := false
var load_errors: Array = []


func _ready() -> void:
	# Otomatik yükleme: veri katmanı hazır olsun. Boot ayrıca load_all() çağırır.
	load_all()


# --- Yükleme ----------------------------------------------------------------

## Tüm veriyi yükler. Zaten yüklüyse tekrar okumaz.
func load_all(force: bool = false) -> bool:
	if _loaded and not force:
		return true
	load_errors.clear()
	_loaded = false

	var ok := true
	ok = _load_buildings() and ok
	ok = _load_units() and ok
	ok = _load_points() and ok
	_load_rules()  # opsiyonel — hata sayılmaz

	if not ok:
		push_error("GameData: temel veri dosyalarından biri yüklenemedi.")
	_loaded = ok
	return ok


func _read_json(path: String):
	if not FileAccess.file_exists(path):
		load_errors.append("Dosya bulunamadı: " + path)
		return null
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		load_errors.append("Boş dosya: " + path)
		return null
	var parsed = JSON.parse_string(text)
	if parsed == null:
		load_errors.append("JSON ayrıştırma hatası: " + path)
		return null
	return parsed


func _load_buildings() -> bool:
	var data = _read_json(BUILDINGS_PATH)
	if typeof(data) != TYPE_ARRAY:
		load_errors.append("buildings.json bir dizi olmalı.")
		return false
	_buildings.clear()
	_building_order.clear()
	for item in data:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var key := str(item.get("key", ""))
		if key.is_empty():
			continue
		_buildings[key] = item
		_building_order.append(key)
	return _buildings.size() > 0


func _load_units() -> bool:
	var data = _read_json(UNITS_PATH)
	var list: Array = []
	if typeof(data) == TYPE_DICTIONARY:
		list = data.get("units", [])
	elif typeof(data) == TYPE_ARRAY:
		list = data
	else:
		load_errors.append("units.json beklenen biçimde değil.")
		return false
	_units.clear()
	_unit_order.clear()
	for item in list:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var key := str(item.get("key", ""))
		if key.is_empty():
			continue
		_units[key] = item
		_unit_order.append(key)
	return _units.size() > 0


func _load_points() -> bool:
	var data = _read_json(POINTS_PATH)
	if typeof(data) != TYPE_DICTIONARY:
		load_errors.append("building-points.json bir sözlük olmalı.")
		return false
	var levels: Array = data.get("levels", [])
	_points_by_level.clear()
	_points_max.clear()
	for row in levels:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var lvl := int(row.get("level", 0))
		if lvl <= 0:
			continue
		_points_by_level[lvl] = row
		for key in row.keys():
			if key == "level":
				continue
			var value := int(row[key])
			if value > int(_points_max.get(key, 0)):
				_points_max[key] = value
	return _points_by_level.size() > 0


func _load_rules() -> void:
	_rules.clear()
	if not DirAccess.dir_exists_absolute(RULES_DIR):
		return  # A-KURAL henüz eklemedi — sessizce atla.
	var dir := DirAccess.open(RULES_DIR)
	if dir == null:
		return
	for file_name in dir.get_files():
		if not file_name.to_lower().ends_with(".json"):
			continue
		var path := RULES_DIR.path_join(file_name)
		var parsed = _read_json(path)
		if parsed == null:
			continue
		_rules[file_name.get_basename()] = parsed


# --- Sorgu API'si: binalar --------------------------------------------------

func get_building(key: String) -> Dictionary:
	return _buildings.get(key, {})


func get_building_name(key: String) -> String:
	return str(get_building(key).get("name", key))


func get_all_building_keys() -> Array:
	return _building_order.duplicate()


func get_building_count() -> int:
	return _buildings.size()


func get_max_level(key: String) -> int:
	return int(get_building(key).get("maxLevel", 0))


## Binanın belirli seviyesinin tam tablo satırını döndürür (1 tabanlı).
func get_building_level(key: String, level: int) -> Dictionary:
	var levels: Array = get_building(key).get("levels", [])
	if level < 1 or level > levels.size():
		return {}
	return levels[level - 1]


func get_building_requirements(key: String) -> Array:
	return get_building(key).get("requirements", [])


# --- Sorgu API'si: birimler -------------------------------------------------

func get_unit(key: String) -> Dictionary:
	return _units.get(key, {})


func get_unit_name(key: String) -> String:
	return str(get_unit(key).get("name", key))


func get_all_unit_keys() -> Array:
	return _unit_order.duplicate()


func get_unit_count() -> int:
	return _units.size()


# --- Sorgu API'si: puanlar --------------------------------------------------

## Bir binanın verilen seviyedeki (kümülatif) bina puanını döndürür.
func points_for(key: String, level: int) -> int:
	var row: Dictionary = _points_by_level.get(level, {})
	if row.is_empty():
		return 0
	return int(row.get(key, 0))


## Binanın ulaşabileceği maksimum bina puanı (tam gelişmiş köy toplamı = 10.000).
func max_points_for(key: String) -> int:
	return int(_points_max.get(key, 0))


## Verilen seviye satırındaki tüm binaların puan toplamı.
func level_points_total(level: int) -> int:
	var row: Dictionary = _points_by_level.get(level, {})
	var total := 0
	for key in row.keys():
		if key == "level":
			continue
		total += int(row[key])
	return total


## Puan tablosunda kayıtlı seviye numaralarını döndürür.
func get_point_levels() -> Array:
	var levels := _points_by_level.keys()
	levels.sort()
	return levels


# --- Sorgu API'si: kurallar (A-KURAL) --------------------------------------

func has_rules() -> bool:
	return not _rules.is_empty()


func get_rule(rule_name: String):
	return _rules.get(rule_name, {})


func get_rule_names() -> Array:
	return _rules.keys()


# --- Durum ------------------------------------------------------------------

func is_loaded() -> bool:
	return _loaded


## Boot ekranı için kısa özet metni.
func summary() -> String:
	return "Bina: %d · Birim: %d · Puan tablosu: %d seviye · Kural dosyası: %d" % [
		get_building_count(),
		get_unit_count(),
		get_point_levels().size(),
		_rules.size(),
	]
