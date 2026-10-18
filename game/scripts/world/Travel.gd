extends RefCounted
class_name Travel
## Yolculuk (seyahat) süresi ve hareket yardımcıları — Taht ve Kılıç / **A-DUNYA**.
##
## Kaynak ve kararlar:
##  • `docs/10` §5 — "Birim hızı" (unit run time) ayarı; Kontun maks. yolculuk mesafesi (TR 80 / EN 100).
##  • `docs/05` §2 — birim hızı **"alan başına dakika"** (küçük = hızlı); kesin değerler
##    genel tablodaki yuvarlanmış "Mobility" değil, detay sayfasındaki kesin değerdir.
##  • `docs/09` §6 — iptal süreleri (saldırı 30 dk, katır 15 dk).
##  • `docs/19` §2.4/§6 — `GameConfig.unit_speed` yolculuk sürelerini **böler**; global `randi()` YASAK.
##
## Formül:
##     saniye = mesafe(alan) × en_yavaş_birim(alan/dakika) × 60 / GameConfig.unit_speed
##
## Bilinmeyenler ve seçilen sabitler: `game/scripts/world/ASSUMPTIONS.md`

## Alan başına dakika cinsinden birim hızları (`game/data/rules/units.json` → `speed.minutes_per_field`).
## Veri katmanı yüklenmemişse (ör. `--script` erken aşaması) bu tablo kullanılır. Değerler UYDURULMADI;
## `data/units.json` referans sayfalarından **birebir** alınmıştır.
const UNIT_MINUTES_PER_FIELD_FALLBACK := {
	"farmer": 5.0,
	"spear": 4.5,
	"sword": 5.5,
	"axe": 4.5,
	"bow": 4.5,
	"spy": 2.25,
	"light": 2.5,
	"heavy": 2.75,
	"ram": 7.5,
	"kata": 7.5,
	"snob": 8.75,
}

## Dakika → saniye.
const SECONDS_PER_MINUTE := 60.0

## İptal penceresi yedekleri (dk) — `docs/09` §6 / `GameConfig`.
const ATTACK_CANCEL_MINUTES_FALLBACK := 30
const DONKEY_CANCEL_MINUTES_FALLBACK := 15

## Mesafesi/hızı 0 olan ordular için dönen süre (yolculuk yok).
const NO_TRAVEL := 0.0


# --- Mesafe -----------------------------------------------------------------

## İki koordinat arasındaki Öklid mesafesi (alan cinsinden, float).
## Karar: KingsAge mesafeyi alan cinsinden hesaplar; yuvarlama yok (bkz. ASSUMPTIONS.md).
static func distance(a_x: int, a_y: int, b_x: int, b_y: int) -> float:
	var dx := float(b_x - a_x)
	var dy := float(b_y - a_y)
	return sqrt(dx * dx + dy * dy)


# --- Yolculuk süresi --------------------------------------------------------

## Yolculuk süresi (saniye).
##
## `slowest_unit_speed`  = ordudaki **en yavaş** birimin **alan başına dakika** değeri
##                          (`unit_minutes_per_field()` / `slowest_speed()`).
## `GameConfig.unit_speed` sonucu **böler** (`docs/19` §2.4).
##
## NOT (imza sapması): `docs/19` §6 bu parametreyi `int` olarak yazar. Birim hızları
## 4.5 / 2.25 / 2.75 gibi **ondalıklı** olduğu için `int` tipi değeri sessizce kırpar
## (4.5 → 4) ve süreleri %10+ saptırır. Bu yüzden parametre `float` alınmıştır;
## isim ve konum sözleşmeye birebir uyar. Bkz. ASSUMPTIONS.md §7 (AÇIK SORU).
static func travel_seconds(from_x: int, from_y: int, to_x: int, to_y: int, slowest_unit_speed: float) -> float:
	if slowest_unit_speed <= 0.0:
		return NO_TRAVEL
	return seconds_for_fields(distance(from_x, from_y, to_x, to_y), slowest_unit_speed)


## Verilen alan mesafesi + alan/dakika hızı için süre (saniye).
static func seconds_for_fields(fields: float, minutes_per_field: float) -> float:
	if fields <= 0.0 or minutes_per_field <= 0.0:
		return NO_TRAVEL
	return fields * minutes_per_field * SECONDS_PER_MINUTE / unit_speed_multiplier()


## Gidiş–dönüş toplam süresi (saniye).
static func round_trip_seconds(from_x: int, from_y: int, to_x: int, to_y: int, slowest_unit_speed: float) -> float:
	return travel_seconds(from_x, from_y, to_x, to_y, slowest_unit_speed) * 2.0


## `GameConfig.unit_speed` (yolculuk sürelerini böler). Autoload yoksa 1.0.
## "Hız" (`GameConfig.speed`) yolculuğa **uygulanmaz** — o ekonomi sürelerini etkiler
## (bkz. ASSUMPTIONS.md §3).
static func unit_speed_multiplier() -> float:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return 1.0
	var config := tree.root.get_node_or_null(^"GameConfig")
	if config == null:
		return 1.0
	var raw = config.get("unit_speed")
	if typeof(raw) != TYPE_FLOAT and typeof(raw) != TYPE_INT:
		return 1.0
	var value := float(raw)
	return value if value > 0.0 else 1.0


# --- Birim hızı -------------------------------------------------------------

## Birimin alan başına dakika hızı. Kaynak sırası:
##   1) `res://data/rules/units.json` → `units[].speed.minutes_per_field` (kanonik)
##   2) `res://data/units.json` → `speed` metni ("4.5 Alan başına dakika") başındaki sayı
##   3) `UNIT_MINUTES_PER_FIELD_FALLBACK` (aynı değerlerin gömülü kopyası)
static func unit_minutes_per_field(unit_key: String) -> float:
	var from_rules := _minutes_per_field_from_rules(unit_key)
	if from_rules > 0.0:
		return from_rules
	var from_units := _minutes_per_field_from_units_json(unit_key)
	if from_units > 0.0:
		return from_units
	return float(UNIT_MINUTES_PER_FIELD_FALLBACK.get(unit_key, 0.0))


## Ordudaki **en yavaş** birimin alan/dakika değeri (`docs/05`: yavaşlık = en yavaş birim).
## Boş/bilinmeyen ordu → 0.0 (yolculuk yok). Bilinmeyen anahtarlar yok sayılır.
static func slowest_speed(units: Dictionary) -> float:
	var slowest := 0.0
	for key in units.keys():
		if int(units[key]) <= 0:
			continue
		var minutes := unit_minutes_per_field(str(key))
		if minutes > slowest:
			slowest = minutes
	return slowest


## Orduda en yavaş birimi (anahtar) döndürür; ordu boşsa "".
static func slowest_unit(units: Dictionary) -> String:
	var slowest_key := ""
	var slowest := 0.0
	for key in units.keys():
		if int(units[key]) <= 0:
			continue
		var minutes := unit_minutes_per_field(str(key))
		if minutes > slowest or (minutes == slowest and slowest_key != "" and str(key) < slowest_key):
			slowest = minutes
			slowest_key = str(key)
	return slowest_key


## Ordunun gidebileceği alan sayısı içinde hedef var mı? (Kont için 80/100 alan kuralı.)
static func within_max_fields(from_x: int, from_y: int, to_x: int, to_y: int, max_fields: float) -> bool:
	if max_fields <= 0.0:
		return true
	return distance(from_x, from_y, to_x, to_y) <= max_fields


# --- Zaman / hareket yardımcıları -------------------------------------------

## Saniye cinsinden süreyi unix zaman damgasına çevirir (round_half_up, `docs/19` §2.1–2.2).
static func arrive_unix(depart_unix: int, seconds: float) -> int:
	return depart_unix + int(floor(seconds + 0.5))


## İptal penceresi (saniye): saldırı 30 dk, katır (ticaret) 15 dk (`docs/09` §6).
static func cancel_window_seconds(is_trade: bool = false) -> int:
	var config := _config_node()
	var key := "donkey_cancel_minutes" if is_trade else "attack_cancel_minutes"
	var fallback := DONKEY_CANCEL_MINUTES_FALLBACK if is_trade else ATTACK_CANCEL_MINUTES_FALLBACK
	var minutes := fallback
	if config != null:
		var raw = config.get(key)
		if typeof(raw) == TYPE_INT or typeof(raw) == TYPE_FLOAT:
			minutes = int(raw)
	return minutes * 60


## Hareket hâlâ iptal edilebilir mi? (`docs/09` §6)
static func can_cancel(depart_unix: int, now_unix: int, is_trade: bool = false) -> bool:
	if now_unix < depart_unix:
		return true
	return (now_unix - depart_unix) < cancel_window_seconds(is_trade)


## `docs/19` §3.3 hareket sözlüğünü **saf veri** olarak üretir (zaman alanları hesaplanır).
##
## Beklenen `data` anahtarları (hepsi opsiyonel, varsayılanları vardır):
##   id, village_id, type ("attack"|"raid"|"support"|"trade"|"spy"|"return"), from_village_id,
##   to_village_id, from_x, from_y, to_x, to_y, units, carry, depart_unix, battle_seed,
##   target_points, slowest_unit_speed (verilmezse `units`'ten hesaplanır)
##
## NOT: Yalnızca **süreleri** hesaplar; savaş/talan sonucuna dokunmaz (o `A-SAVAS`/`A-KESIF` işi).
static func make_movement(data: Dictionary) -> Dictionary:
	var units: Dictionary = data.get("units", {})
	var slowest := float(data.get("slowest_unit_speed", slowest_speed(units)))
	var from_x := int(data.get("from_x", 0))
	var from_y := int(data.get("from_y", 0))
	var to_x := int(data.get("to_x", 0))
	var to_y := int(data.get("to_y", 0))
	var depart := int(data.get("depart_unix", 0))
	var travel := travel_seconds(from_x, from_y, to_x, to_y, slowest)
	return {
		"id": int(data.get("id", 0)),
		"village_id": int(data.get("village_id", 0)),
		"type": str(data.get("type", "attack")),
		"from_village_id": int(data.get("from_village_id", 0)),
		"to_village_id": int(data.get("to_village_id", 0)),
		"to_x": to_x,
		"to_y": to_y,
		"units": units.duplicate(true),
		"carry": (data.get("carry", {"wood": 0, "stone": 0, "iron": 0}) as Dictionary).duplicate(true),
		"depart_unix": depart,
		"arrive_unix": arrive_unix(depart, travel),
		"return_unix": arrive_unix(depart, travel * 2.0),
		"state": "outgoing",
		"battle_seed": int(data.get("battle_seed", 0)),
		"target_points": int(data.get("target_points", 0)),
	}


# --- İç yardımcılar ---------------------------------------------------------

static func _config_node() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(^"GameConfig")


static func _game_data_node() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(^"GameData")


static func _minutes_per_field_from_rules(unit_key: String) -> float:
	var data := _game_data_node()
	if data == null or not data.has_method("get_rule"):
		return 0.0
	var rules = data.get_rule("units")
	if typeof(rules) != TYPE_DICTIONARY:
		return 0.0
	for item in (rules as Dictionary).get("units", []) as Array:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if str((item as Dictionary).get("key", "")) != unit_key:
			continue
		var speed = (item as Dictionary).get("speed", {})
		if typeof(speed) == TYPE_DICTIONARY:
			var value := float((speed as Dictionary).get("minutes_per_field", 0.0))
			if value > 0.0:
				return value
	return 0.0


static func _minutes_per_field_from_units_json(unit_key: String) -> float:
	var data := _game_data_node()
	if data == null or not data.has_method("get_unit"):
		return 0.0
	var unit = data.get_unit(unit_key)
	if typeof(unit) != TYPE_DICTIONARY:
		return 0.0
	# Örnek: "4.5 Alan başına dakika" → 4.5 (`String.to_float()` baştaki sayıyı okur).
	return str((unit as Dictionary).get("speed", "")).to_float()
