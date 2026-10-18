extends Node
## GameConfig — sunucu (dünya) ayarları (Taht ve Kılıç).
##
## Kaynak: docs/10-HARITA-VE-DUNYA.md §5 ("World (Sunucu) Ayarları").
## TR ve EN dünyaları farklı olduğu için tüm ayarlar **veri olarak** tutulur ve
## JSON'a yazılıp okunabilir. Varsayılanlar TR dünyasına (World 59 TR) göredir:
## gece bonusu aktif (00:00–06:00), Kontun maksimum yolculuk mesafesi 80 alan.
##
## Not: EN dünyası baz alınacaksa `count_max_distance = 100` ve
##      `night_bonus_enabled = false` yapılmalıdır (bkz. docs/TERIMLER.md §11).

const CONFIG_PATH := "user://taht_ve_kilic_config.json"

# --- Hız / üretim -----------------------------------------------------------

## Dünya hızı (üretim, inşaat süreleri vb. için çarpan). "Hız".
var speed: float = 4.0

## Birim hızı (orduların harita üzerinde ilerleme hızı). "Birim hızı".
var unit_speed: float = 4.0

# --- Gece bonusu ------------------------------------------------------------

## Savunanlar için gece bonusu. "Savunanlar için gece bonusu" (savunma ×2).
var night_bonus_enabled: bool = true

## Gece bonusu penceresi (yerel saat, [start_hour, end_hour)). TR: 00:00–06:00.
var night_bonus_window: Dictionary = {"start_hour": 0, "end_hour": 6}

## Gece bonusu çarpanı (savunma değerleri bu katsayıyla çarpılır).
var night_bonus_multiplier: float = 2.0

# --- Koruma süreleri --------------------------------------------------------

## Yeni oyuncular için saldırı koruması (gün).
var new_player_protection_days: int = 5

## Fetih Koruması (gün).
var conquest_protection_days: int = 7

# --- Saldırı sınırları ------------------------------------------------------

## Saldırı için gereken en az birim = bu faktör × Kışla seviyesi.
var min_attack_unit_factor: int = 3

## Maksimum oran saldıran : savunan (ihlalde kanun kaçağı / koruma kaybı).
var max_attack_ratio: int = 10

# --- Emir iptali ------------------------------------------------------------

## Saldırı iptal zamanı (dakika) — ordunun yolda olduğu sürede iptal edilebilir.
var attack_cancel_minutes: int = 30

## Katır (ticaret) iptal zamanı (dakika).
var donkey_cancel_minutes: int = 15

# --- Fetih / Kont -----------------------------------------------------------

## Kontun maksimum yolculuk mesafesi (alan). TR: 80, EN: 100.
var count_max_distance: int = 80

## Saat başına güç alanı artışı (Köy Puanının yüzdesi). TR: %1.
var realm_power_hourly_percent: float = 1.0

## Yabancı Kont yüzünden güç alanı kaybı (Anıt yokken).
var realm_loss_min: int = 2250
var realm_loss_max: int = 2750

## Yabancı Kont yüzünden güç alanı kaybı (Anıt varken).
var realm_loss_min_with_statue: int = 1750
var realm_loss_max_with_statue: int = 2250

# --- Davranış anahtarları (worldinfo) --------------------------------------

## Binayı yık aktif mi?
var tear_down_building: bool = true

## Bağımsız gelişen terkedilmiş köyler aktif mi?
var abandoned_independent_growth: bool = true

## Tatil bakıcısı aktif mi?
var holiday_replacement: bool = true

## Yön seçimi aktif mi?
var orientation_choice: bool = true


func _ready() -> void:
	# Kayıtlı ayar varsa onu yükle; yoksa varsayılanlar geçerli kalır.
	if FileAccess.file_exists(CONFIG_PATH):
		load_from_file(CONFIG_PATH)


# --- Yardımcılar ------------------------------------------------------------

## Verilen saatin gece bonusu penceresinde olup olmadığını döndürür.
func is_night_bonus_time(hour: int) -> bool:
	if not night_bonus_enabled:
		return false
	var start := int(night_bonus_window.get("start_hour", 0))
	var end := int(night_bonus_window.get("end_hour", 0))
	if start == end:
		return false
	var h: int = ((hour % 24) + 24) % 24
	if start < end:
		return h >= start and h < end
	# Gece yarısını aşan pencere (ör. 23 → 6).
	return h >= start or h < end


## Gece bonusu çarpanı (gece değilse 1.0).
func defense_multiplier_at(hour: int) -> float:
	return night_bonus_multiplier if is_night_bonus_time(hour) else 1.0


## Anıt (statue) durumuna göre güç alanı kaybı aralığını döndürür: [min, max].
func realm_loss_range(has_statue: bool) -> Array:
	if has_statue:
		return [realm_loss_min_with_statue, realm_loss_max_with_statue]
	return [realm_loss_min, realm_loss_max]


# --- Serileştirme -----------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"speed": speed,
		"unit_speed": unit_speed,
		"night_bonus_enabled": night_bonus_enabled,
		"night_bonus_window": night_bonus_window.duplicate(true),
		"night_bonus_multiplier": night_bonus_multiplier,
		"new_player_protection_days": new_player_protection_days,
		"conquest_protection_days": conquest_protection_days,
		"min_attack_unit_factor": min_attack_unit_factor,
		"max_attack_ratio": max_attack_ratio,
		"attack_cancel_minutes": attack_cancel_minutes,
		"donkey_cancel_minutes": donkey_cancel_minutes,
		"count_max_distance": count_max_distance,
		"realm_power_hourly_percent": realm_power_hourly_percent,
		"realm_loss_min": realm_loss_min,
		"realm_loss_max": realm_loss_max,
		"realm_loss_min_with_statue": realm_loss_min_with_statue,
		"realm_loss_max_with_statue": realm_loss_max_with_statue,
		"tear_down_building": tear_down_building,
		"abandoned_independent_growth": abandoned_independent_growth,
		"holiday_replacement": holiday_replacement,
		"orientation_choice": orientation_choice,
	}


func from_dict(data: Dictionary) -> void:
	for key in to_dict().keys():
		if data.has(key):
			_set_field(key, data[key])
	EventBus.config_changed.emit()


func _set_field(key: String, value) -> void:
	match key:
		"speed":
			speed = float(value)
		"unit_speed":
			unit_speed = float(value)
		"night_bonus_enabled":
			night_bonus_enabled = bool(value)
		"night_bonus_window":
			if typeof(value) == TYPE_DICTIONARY:
				night_bonus_window = value.duplicate(true)
		"night_bonus_multiplier":
			night_bonus_multiplier = float(value)
		"new_player_protection_days":
			new_player_protection_days = int(value)
		"conquest_protection_days":
			conquest_protection_days = int(value)
		"min_attack_unit_factor":
			min_attack_unit_factor = int(value)
		"max_attack_ratio":
			max_attack_ratio = int(value)
		"attack_cancel_minutes":
			attack_cancel_minutes = int(value)
		"donkey_cancel_minutes":
			donkey_cancel_minutes = int(value)
		"count_max_distance":
			count_max_distance = int(value)
		"realm_power_hourly_percent":
			realm_power_hourly_percent = float(value)
		"realm_loss_min":
			realm_loss_min = int(value)
		"realm_loss_max":
			realm_loss_max = int(value)
		"realm_loss_min_with_statue":
			realm_loss_min_with_statue = int(value)
		"realm_loss_max_with_statue":
			realm_loss_max_with_statue = int(value)
		"tear_down_building":
			tear_down_building = bool(value)
		"abandoned_independent_growth":
			abandoned_independent_growth = bool(value)
		"holiday_replacement":
			holiday_replacement = bool(value)
		"orientation_choice":
			orientation_choice = bool(value)
		_:
			pass


# --- Dosya işlemleri --------------------------------------------------------

## Ayarları JSON dosyasından yükler. Başarı durumunu döndürür.
func load_from_file(path: String = CONFIG_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return false
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("GameConfig: ayar dosyası ayrıştırılamadı -> " + path)
		return false
	from_dict(parsed)
	return true


## Ayarları JSON dosyasına yazar.
func save_to_file(path: String = CONFIG_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("GameConfig: ayar dosyası yazılamadı -> " + path)
		return false
	file.store_string(JSON.stringify(to_dict(), "\t"))
	file.close()
	return true
