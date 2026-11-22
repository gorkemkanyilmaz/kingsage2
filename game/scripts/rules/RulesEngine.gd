class_name RulesEngine
extends RefCounted
## RulesEngine — Taht ve Kılıç kural sorgu motoru (statik, durumsuz).
##
## Sözleşme: `docs/19-MOTOR-API-SOZLESMESI.md` §4. Bu sınıf **hiçbir durum tutmaz**;
## tüm cevaplar `GameData` autoload'undan okunan kural verisinden üretilir:
##   • `res://data/buildings.json`        → bina seviye tabloları (maliyet/işçi/puan)
##   • `res://data/building-points.json`  → kümülatif bina puanları
##   • `res://data/rules/costs.json`      → büyüme faktörleri + seviye-1 temel maliyet
##   • `res://data/rules/requirements.json` → gereksinim DAG'ı (önkoşul zinciri)
##   • `res://data/rules/production.json` → üretim/kapasite/vatandaş/katır/sur tabloları
##   • `res://data/rules/time-factors.json` → zaman faktörü serileri + kuyruk ek maliyeti
##   • `res://data/rules/battle.json`     → savaş sabitleri (min. saldırı birimi)
##   • `res://data/rules/units.json`      → birim maliyet/istatistik/araştırma/eğitim
##
## ## Neden `root.get_node("GameData")`?
## `godot --headless --script res://tests/…gd` ile çalıştırıldığında autoload'lar
## sahne ağacına **node olarak** eklenir, ancak derleme anında **global tanımlayıcı**
## olarak çözülmez ("Identifier not found: GameData"). Bu yüzden veriye her zaman
## `Engine.get_main_loop()` → `root.get_node("GameData")` üzerinden erişilir; bu yol
## hem normal oyunda hem de başsız (headless) testte çalışır.
##
## ## Bilinmeyenler
## Bilinmeyen formüller **uydurulmaz**; tek bir sabit seçilir ve gerekçesiyle
## `res://scripts/rules/ASSUMPTIONS.md` içinde listelenir.

const RESOURCES := ["wood", "stone", "iron"]
const UNIT_RESOURCES := ["wood", "stone", "iron"]

## Kraliyet KingsAge inşaat süresi tabanı (1× dünya hızı, Kale Sv. 1 = %100 faktöründe).
## Seviye arttıkça üstel büyür; köyün Kale ('main') seviyesi arttıkça zaman faktörü (%100 -> %15) ile kısalır.
const BUILDING_TIME_SPEC := {
	"wood":     {"base": 240.0,   "growth": 1.15},
	"stone":    {"base": 240.0,   "growth": 1.15},
	"iron":     {"base": 240.0,   "growth": 1.15},
	"storage":  {"base": 210.0,   "growth": 1.15},
	"farm":     {"base": 240.0,   "growth": 1.15},
	"main":     {"base": 300.0,   "growth": 1.15},
	"hide":     {"base": 180.0,   "growth": 1.16},
	"wall":     {"base": 360.0,   "growth": 1.20},
	"market":   {"base": 360.0,   "growth": 1.17},
	"barracks": {"base": 420.0,   "growth": 1.18},
	"stable":   {"base": 420.0,   "growth": 1.17},
	"garage":   {"base": 900.0,   "growth": 1.30},
	"smith":    {"base": 1800.0,  "growth": 1.35},
	"snob":     {"base": 3600.0,  "growth": 1.28},
	"statue":   {"base": 86400.0, "growth": 1.00},
}

## Geriye dönük uyumluluk sabiti.
const BASE_BUILD_SECONDS := 240.0


# =============================================================================
#  İç yardımcılar: veri erişimi
# =============================================================================

const GameDataScript := preload("res://autoload/GameData.gd")
const GameConfigScript := preload("res://autoload/GameConfig.gd")

## GameData singleton'ını döndürür (otomatik yüklenmiş halde).
static func _game_data() -> Node:
	return GameDataScript.get_singleton()


## GameConfig singleton'ını döndürür.
static func _game_config() -> Node:
	return GameConfigScript.get_singleton()


## Sunucu hızı (üretimi çarpar, süreleri böler). Varsayılan 1.0.
static func _speed() -> float:
	var gc := _game_config()
	if gc == null:
		return 1.0
	var s := float(gc.get("speed"))
	return s if s > 0.0 else 1.0


## `res://data/rules/<name>.json` içeriğini (normalize edilmiş) döndürür.
static func _rule(name: String) -> Dictionary:
	var gd := _game_data()
	if gd == null:
		return {}
	var value = gd.get_rule(name)
	return value if typeof(value) == TYPE_DICTIONARY else {}


## Yuvarlama: round_half_up = floor(x + 0.5). (docs/19 §2.1)
static func _round_half_up(x: float) -> int:
	return int(floor(x + 0.5))


## Binanın maksimum seviyesi (0 = bilinmeyen bina).
static func _max_level(key: String) -> int:
	var gd := _game_data()
	if gd == null:
		return 0
	return int(gd.get_max_level(key))


## Binanın metadata/tanım sözlüğünü döndürür (GameData.get_building sarmalayıcısı).
static func building_data(key: String) -> Dictionary:
	var gd := _game_data()
	return gd.get_building(key) if gd != null else {}


## Birimin metadata/tanım sözlüğünü döndürür (GameData.get_unit sarmalayıcısı).
static func unit_data(key: String) -> Dictionary:
	var gd := _game_data()
	return gd.get_unit(key) if gd != null else {}


# =============================================================================
#  4.1  Maliyet ve gereksinim
# =============================================================================

## Bir binanın belirli seviyeye çıkma maliyeti: {"wood","stone","iron"}.
## Formül (costs.json): round_half_up(base * growth_factor ** (level-1)).
static func cost(key: String, level: int) -> Dictionary:
	var out := {"wood": 0, "stone": 0, "iron": 0}
	if level < 1:
		return out
	var costs := _rule("costs")
	var base_all: Dictionary = costs.get("base_level1_cost", {})
	if not base_all.has(key):
		return out
	var base: Dictionary = base_all[key]
	var group := str((costs.get("building_group", {}) as Dictionary).get(key, ""))
	var groups: Dictionary = costs.get("growth_factor_groups", {})
	var factors: Dictionary = groups.get(group, {})
	for r in RESOURCES:
		var b := float(base.get(r, 0))
		var f := float(factors.get(r, 1.0))
		out[r] = _round_half_up(b * pow(f, float(level - 1)))
	return out


## `from_level` seviyesinden `to_level` seviyesine yükseltmenin toplam maliyeti.
## (from_level hariç, to_level dahil: cost(from+1) + … + cost(to))
static func cost_sum(key: String, from_level: int, to_level: int) -> Dictionary:
	var out := {"wood": 0, "stone": 0, "iron": 0}
	for lv in range(from_level + 1, to_level + 1):
		var c := cost(key, lv)
		for r in RESOURCES:
			out[r] += int(c.get(r, 0))
	return out


## Bina serbest başlangıçtadır (önkoşul istemez → requirements.free_start_buildings).
static func is_free_start(key: String) -> bool:
	var reqs := _rule("requirements")
	var free: Array = reqs.get("free_start_buildings", [])
	return free.has(key)


## requirements.json `buildings` dizisini key→kayıt sözlüğüne çevirir.
static func _requirements_map() -> Dictionary:
	var reqs := _rule("requirements")
	var out := {}
	for body in reqs.get("buildings", []):
		if typeof(body) == TYPE_DICTIONARY:
			out[str(body.get("key", ""))] = body
	return out


## Binanın `requires` listesini [{building,level}] olarak döndürür (önkoşullar).
## Anıt (statue) için liste, kendisi hariç 14 binayı maks. seviyede ister.
static func requirements(key: String, target_level: int) -> Array:
	var out := []
	var map := _requirements_map()
	if not map.has(key):
		return out
	var body: Dictionary = map[key]
	for r in body.get("requires", []):
		if typeof(r) == TYPE_DICTIONARY:
			out.append({"building": str(r.get("building", "")), "level": int(r.get("level", 0))})
	return out


## Karşılanmayan **doğrudan** önkoşullar [{building,level}] (JSON sırasında).
## Örn. Kışla için: [{storage,3},{farm,3}].
static func missing_requirements(buildings: Dictionary, key: String, target_level: int) -> Array:
	var out := []
	for r in requirements(key, target_level):
		var have := int(buildings.get(r["building"], 0))
		if have < int(r["level"]):
			out.append(r)
	return out


## Bina hedef seviyeye çıkarılabilir mi? (Tüm doğrudan önkoşullar sağlanmalı ve
## hedef seviye 1..max_level aralığında olmalı.)
static func can_build(buildings: Dictionary, key: String, target_level: int) -> bool:
	var maxl := _max_level(key)
	if maxl <= 0:
		return false
	if target_level < 1 or target_level > maxl:
		return false
	return missing_requirements(buildings, key, target_level).is_empty()


## **SIRALI İLERLEME** kapısı (A-EKONOMI inşa başlatmadan ÖNCE çağırır):
## hedef = mevcut + 1 olmalı, `mevcut < max_level` olmalı ve önkoşullar sağlanmalı.
static func can_upgrade_now(buildings: Dictionary, key: String) -> bool:
	var maxl := _max_level(key)
	if maxl <= 0:
		return false
	var cur := int(buildings.get(key, 0))
	if cur < 0:
		cur = 0
	if cur >= maxl:
		return false
	return can_build(buildings, key, cur + 1)


## Hedefe ulaşmak için gereken **tam** zincir: hedef + tüm geçişli önkoşullar,
## **topolojik** sırada (önce önkoşullar). Her giriş: {key, level, current}.
## Aynı bina birden çok yoldan gerekli olursa **en yüksek** seviye alınır.
static func requirement_chain(buildings: Dictionary, key: String, target_level: int) -> Array:
	var maxl := _max_level(key)
	if maxl <= 0:
		return []
	var tl := clampi(target_level, 1, maxl)
	var map := _requirements_map()

	# 1) Her bina için gereken en yüksek seviyeyi (fixpoint) hesapla.
	var required := {key: tl}
	var queue: Array = [key]
	while not queue.is_empty():
		var cur := str(queue.pop_front())
		var body: Dictionary = map.get(cur, {})
		for r in body.get("requires", []):
			if typeof(r) != TYPE_DICTIONARY:
				continue
			var b := str(r.get("building", ""))
			var lv := int(r.get("level", 0))
			if b.is_empty():
				continue
			if lv > int(required.get(b, 0)):
				required[b] = lv
				queue.append(b)

	# 2) Topolojik sıra (DFS son-sıra: önkoşullar önce).
	var order := []
	_dfs_order(key, map, {}, order)

	# 3) Sonucu üret.
	var out := []
	for k in order:
		out.append({
			"key": k,
			"level": int(required.get(k, tl)),
			"current": int(buildings.get(k, 0)),
		})
	return out


## `requires` DAG'ında son-sıra (post-order) DFS.
static func _dfs_order(node: String, map: Dictionary, visited: Dictionary, order: Array) -> void:
	if visited.has(node):
		return
	visited[node] = true
	var body: Dictionary = map.get(node, {})
	for r in body.get("requires", []):
		if typeof(r) == TYPE_DICTIONARY:
			_dfs_order(str(r.get("building", "")), map, visited, order)
	order.append(node)


# =============================================================================
#  4.2  Süre (bilinmeyen taban → ASSUMPTIONS.md)
# =============================================================================

## `time-factors.json` zaman faktörü serisini döndürür (yüzde listesi).
static func _time_factor_series(building: String) -> Array:
	var tf := _rule("time-factors")
	var col: Dictionary = (tf.get("time_factor_column", {}) as Dictionary).get(building, {})
	return col.get("values_percent", [])


## Zaman faktörü yüzdesi (indeks = level-1; aralık dışında en yakın uca kırpılır).
static func _time_factor_percent(building: String, level: int) -> float:
	var vals := _time_factor_series(building)
	if vals.is_empty():
		return 100.0
	var i := clampi(level - 1, 0, vals.size() - 1)
	return float(vals[i])


## Verilen Kale (`main`) seviyesindeki inşaat süresi çarpanı yüzdesi (%100..%15).
static func castle_time_factor_percent(level: int) -> int:
	return int(round(_time_factor_percent("main", maxi(1, level))))


## Verilen Kale (`main`) seviyesinde Sv. 1'e kıyasla inşaat hızlandırma yüzdesi (%0..%85).
static func castle_speedup_percent(level: int) -> int:
	return maxi(0, 100 - castle_time_factor_percent(level))


## İnşaat süresi (saniye).
## Her bina türünün 1× dünya hızında temel süresi ve üstel büyümesi uygulanır;
## köyün Kale (`main`) seviyesine karşılık gelen zaman faktörü (%100..%15) ve `_speed()` (ilk 7 gün 2× dahil) uygulanır.
static func build_seconds(key: String, level: int, castle_level: int = 1) -> float:
	if level < 1:
		return 0.0
	var spec: Dictionary = BUILDING_TIME_SPEC.get(key, {"base": 240.0, "growth": 1.15})
	var base_sec := float(spec.get("base", 240.0))
	var growth := float(spec.get("growth", 1.15))
	var eff_castle := maxi(1, castle_level)
	var tf := _time_factor_percent("main", eff_castle)
	return base_sec * pow(growth, float(level - 1)) * (tf / 100.0) / _speed()


## Kuyruktaki (queue_index+1). işin **ek maliyet yüzdesi** ([0,0,0,25,56,…]).
## 0 tabanlı indeks; tablo dışında son değere kırpılır.
static func queue_extra_cost_percent(queue_index: int) -> int:
	var tf := _rule("time-factors")
	var cfg: Dictionary = tf.get("build_queue_extra_cost", {})
	var vals: Array = cfg.get("values_percent", [])
	if vals.is_empty():
		return 0
	var i := clampi(queue_index, 0, vals.size() - 1)
	return int(vals[i])


## Ücretsiz kuyruk işi sayısı (time-factors.json → free_jobs; varsayılan 3).
static func queue_slots_free() -> int:
	var tf := _rule("time-factors")
	var cfg: Dictionary = tf.get("build_queue_extra_cost", {})
	return int(cfg.get("free_jobs", 3))


# =============================================================================
#  4.3  Üretim / kapasite / nüfus
# =============================================================================

## `production.json#curves.<name>.values` (kesin tablo) dizisini döndürür.
static func _curve_values(name: String) -> Array:
	var prod := _rule("production")
	var curve: Dictionary = (prod.get("curves", {}) as Dictionary).get(name, {})
	return curve.get("values", [])


## Eğriden seviye değeri (1 tabanlı); aralık dışında 0.
static func _curve_value(name: String, level: int) -> int:
	var vals := _curve_values(name)
	if level < 1 or level > vals.size():
		return 0
	return int(vals[level - 1])


## `production.json#tables.<name>.values_percent` dizisini döndürür.
static func _table_percent_values(name: String) -> Array:
	var prod := _rule("production")
	var tbl: Dictionary = (prod.get("tables", {}) as Dictionary).get(name, {})
	return tbl.get("values_percent", [])


## `production.json#tables.<name>.values` dizisini döndürür.
static func _table_values(name: String) -> Array:
	var prod := _rule("production")
	var tbl: Dictionary = (prod.get("tables", {}) as Dictionary).get(name, {})
	return tbl.get("values", [])


## Saatlik hammadde üretimi (Oduncu Kampı / Taş ocağı / Maden ocağı). Sunucu hızıyla çarpılır.
static func production_per_hour(key: String, level: int) -> float:
	var prod := _rule("production")
	var curve: Dictionary = (prod.get("curves", {}) as Dictionary).get("raw_material_production", {})
	var applies: Array = curve.get("applies_to", [])
	if not applies.has(key):
		return 0.0
	return float(_curve_value("raw_material_production", level)) * _speed()


## Depo (storage) toplam hammadde kapasitesi.
static func storage_capacity(level: int) -> int:
	return _curve_value("warehouse_capacity", level)


## Gizli Depo (hide) kapasitesi.
static func hideout_capacity(level: int) -> int:
	return _curve_value("hideout_capacity", level)


## Değirmenin sağladığı maksimum vatandaş sayısı.
static func max_population(farm_level: int) -> int:
	return _curve_value("mill_max_citizens", farm_level)


## Katır çiftliğinin saatlik katır üretimi. Sunucu hızıyla çarpılır.
static func donkey_production_per_hour(stable_level: int) -> float:
	return float(_curve_value("donkey_production", stable_level)) * _speed()


## Market seviyesinin belirlediği maksimum katır sayısı.
static func donkey_capacity(market_level: int) -> int:
	var vals := _table_values("market_donkey_capacity")
	if market_level < 1 or market_level > vals.size():
		return 0
	return int(vals[market_level - 1])


## Sur'un savunmaya verdiği takviye yüzdesi (0 = sur yok → 100).
static func wall_bonus_percent(wall_level: int) -> int:
	var vals := _table_percent_values("wall_defence_bonus_percent")
	if vals.is_empty():
		return 100
	var i := clampi(wall_level, 0, vals.size() - 1)
	return int(vals[i])


# =============================================================================
#  4.4  Puan
# =============================================================================

## Bir binanın verilen seviyedeki (kümülatif) bina puanı.
static func points_for(key: String, level: int) -> int:
	var gd := _game_data()
	if gd == null:
		return 0
	return int(gd.points_for(key, level))


## Köy Puanı = Σ bina puanları (tam gelişmiş köy = 10.000).
static func village_points(buildings: Dictionary) -> int:
	var gd := _game_data()
	if gd == null:
		return 0
	var total := 0
	for key in buildings.keys():
		total += int(gd.points_for(str(key), int(buildings[key])))
	return total


## Toplam Puan = Σ köy puanları + 2.500 × (köy sayısı − 1).
static func total_points(villages: Array) -> int:
	var n := villages.size()
	if n <= 0:
		return 0
	var total := 0
	for v in villages:
		if typeof(v) == TYPE_DICTIONARY:
			total += village_points((v as Dictionary).get("buildings", {}))
	total += 2500 * (n - 1)
	return total


# =============================================================================
#  4.5  Birim
# =============================================================================

## `rules/units.json` içindeki birim kaydını döndürür.
static func _unit_rule(unit_key: String) -> Dictionary:
	var units := _rule("units")
	for u in units.get("units", []):
		if typeof(u) == TYPE_DICTIONARY and str(u.get("key", "")) == unit_key:
			return u
	return {}


## `count` adet birimin toplam eğitim maliyeti {"wood","stone","iron"}.
static func unit_cost(unit_key: String, count: int) -> Dictionary:
	var out := {"wood": 0, "stone": 0, "iron": 0}
	var c: Dictionary = _unit_rule(unit_key).get("cost", {})
	for r in UNIT_RESOURCES:
		out[r] = int(c.get(r, 0)) * count
	return out


## Birimin bağladığı vatandaş sayısı.
static func unit_settlers(unit_key: String) -> int:
	return int(_unit_rule(unit_key).get("settlers", 0))


## Birimin yavaşlık faktörü: **alan/dakika** (FLOAT, kesin yuvarlanmamış değer).
## Küçük = hızlı. NOT: int kırpma yolculuk süresinde %11 hataya yol açıyordu (A-DUNYA).
static func unit_speed(unit_key: String) -> float:
	var sp: Dictionary = _unit_rule(unit_key).get("speed", {})
	return float(sp.get("minutes_per_field", 0.0))


## Resmî "Hareketlilik" değeri (int) — bilgi amaçlı (yolculuk için `unit_speed` kullanılır).
static func unit_mobility(unit_key: String) -> int:
	var sp: Dictionary = _unit_rule(unit_key).get("speed", {})
	return int(sp.get("mobility", 0))


## Birimin taşıma kapasitesi (yağma).
static func unit_carry(unit_key: String) -> int:
	return int(_unit_rule(unit_key).get("carry_capacity", 0))


## Birimin muharebe değerleri: {"attack","def_inf","def_cav","def_arch"}.
static func unit_combat(unit_key: String) -> Dictionary:
	var cb: Dictionary = _unit_rule(unit_key).get("combat", {})
	return {
		"attack": int(cb.get("attack", 0)),
		"def_inf": int(cb.get("defence_infantry", 0)),
		"def_cav": int(cb.get("defence_cavalry", 0)),
		"def_arch": int(cb.get("defence_archer", 0)),
	}


## Birimin araştırılması için gereken Kışla seviyesi (0 = araştırılmaz → Kont).
static func research_requirement(unit_key: String) -> int:
	var units := _rule("units")
	var map: Dictionary = units.get("research_requirements_barracks", {})
	return int(map.get(unit_key, 0))


## Birim **araştırılmış** mı? → `village.researched[unit_key]`.
## Araştırma gerçek bir eylemdir: bedeli ödenir ve **bir kez** yapılır; bu yüzden
## **Kışla seviyesinden türetilemez**, mutlaka `researched` sözlüğüne bakılır.
static func is_researched(village: Dictionary, unit_key: String) -> bool:
	var r = village.get("researched", {})
	if typeof(r) != TYPE_DICTIONARY:
		return false
	return bool((r as Dictionary).get(unit_key, false))


## Birim şu an araştırılabilir mi?
## Koşullar: araştırılabilir birim + Kışla seviyesi yeterli + **henüz araştırılmamış**
## + köyün hammaddesi araştırma maliyetini karşılıyor.
static func can_research(village: Dictionary, unit_key: String) -> bool:
	var need := research_requirement(unit_key)
	if need <= 0:
		return false
	if is_researched(village, unit_key):
		return false
	var b = village.get("buildings", {})
	if typeof(b) != TYPE_DICTIONARY or int((b as Dictionary).get("barracks", 0)) < need:
		return false
	var c := research_cost(unit_key)
	if c.is_empty():
		return false
	var res = village.get("resources", {})
	if typeof(res) != TYPE_DICTIONARY:
		return false
	for r in UNIT_RESOURCES:
		if int((res as Dictionary).get(r, 0)) < int(c.get(r, 0)):
			return false
	return true


## Birimin araştırma maliyeti {"wood","stone","iron"} (araştırılmazsa {}).
static func research_cost(unit_key: String) -> Dictionary:
	var res: Dictionary = _unit_rule(unit_key).get("research", {})
	var c = res.get("cost", null)
	if typeof(c) != TYPE_DICTIONARY:
		return {}
	var out := {"wood": 0, "stone": 0, "iron": 0}
	for r in UNIT_RESOURCES:
		out[r] = int((c as Dictionary).get(r, 0))
	return out


## Araştırma süresi (saniye). `building_level` = Kışla seviyesi; `-1` verilirse
## birimin **minimum gereken** Kışla seviyesi kullanılır.
## Bkz. ASSUMPTIONS.md #2.
static func research_seconds(unit_key: String, building_level: int = -1) -> float:
	var res: Dictionary = _unit_rule(unit_key).get("research", {})
	var base = res.get("base_time_seconds", null)
	if base == null:
		return 0.0
	var lvl := building_level
	if lvl < 0:
		var need := research_requirement(unit_key)
		lvl = need if need > 0 else 1
	var tf := _time_factor_percent("barracks", lvl)
	return float(base) * (tf / 100.0) / _speed()


## `count` adet birimin eğitim süresi (saniye). `building_level` = ilgili bina
## seviyesi (Kışla; Kont için Köşk); `-1` verilirse minimum ilgili bina seviyesi.
## Bkz. ASSUMPTIONS.md #3.
static func training_seconds(unit_key: String, count: int, building_level: int = -1) -> float:
	var tr: Dictionary = _unit_rule(unit_key).get("training", {})
	var base = tr.get("base_time_seconds", null)
	if base == null:
		return 0.0
	var building := str(tr.get("building", "barracks"))
	var series := "snob" if building == "snob" else "barracks"
	var lvl := building_level
	if lvl < 0:
		var need := research_requirement(unit_key)
		lvl = need if need > 0 else 1
	var tf := _time_factor_percent(series, lvl)
	return float(base) * float(count) * (tf / 100.0) / _speed()


## Saldırı için gereken minimum birim sayısı = barracks_factor × Kışla seviyesi.
static func min_attack_units(barracks_level: int) -> int:
	var battle := _rule("battle")
	var cfg: Dictionary = battle.get("min_attack_units", {})
	var factor := int(cfg.get("barracks_factor", 3))
	return factor * barracks_level
