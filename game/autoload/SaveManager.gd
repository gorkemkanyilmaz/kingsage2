extends Node
## SaveManager — yerel kaydet/yükle (Taht ve Kılıç).
##
## Tek oyunculu kayıt `user://` altında JSON olarak tutulur. Kayıt zarfı
## `saveVersion` alanı içerir; ileride şema değişince göç (migration) burada
## yapılır. Offline telafi için `savedAtUnix` damgası saklanır.

## Kayıt şeması sürümü. Şema değiştiğinde artırılır ve `_migrate()` güncellenir.
const SAVE_VERSION := 1

const SAVE_PATH := "user://taht_ve_kilic_save.json"


func _ready() -> void:
	pass


# --- Sorgu ------------------------------------------------------------------

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func get_save_path() -> String:
	return SAVE_PATH


## Kayıt zarfının özet bilgilerini döndürür (yükleme yapmadan).
func get_save_meta() -> Dictionary:
	if not has_save():
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return {
		"saveVersion": int(parsed.get("saveVersion", 0)),
		"savedAtUnix": int(parsed.get("savedAtUnix", 0)),
		"savedAtIso": str(parsed.get("savedAtIso", "")),
	}


# --- Kaydet -----------------------------------------------------------------

## Oyun durumunu ve ayarları kaydeder.
func save_game() -> bool:
	var now := int(Time.get_unix_time_from_system())
	# Offline telafi damgasını güncelle.
	GameState.world["last_saved_unix"] = now
	GameState.world["sim_time_seconds"] = GameClock.elapsed_seconds

	var payload := {
		"saveVersion": SAVE_VERSION,
		"savedAtUnix": now,
		"savedAtIso": Time.get_datetime_string_from_system(),
		"state": GameState.to_dict(),
		"config": GameConfig.to_dict(),
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: kayıt dosyası açılamadı -> " + SAVE_PATH)
		EventBus.error_occurred.emit("save_failed", "Kayıt dosyası yazılamadı.")
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()

	EventBus.game_saved.emit()
	return true


# --- Yükle ------------------------------------------------------------------

## Kayıt varsa durumu ve ayarları yükler. Başarı durumunu döndürür.
func load_game() -> bool:
	if not has_save():
		return false

	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveManager: kayıt dosyası bozuk -> " + SAVE_PATH)
		EventBus.error_occurred.emit("load_failed", "Kayıt dosyası okunamadı.")
		return false

	var version := int(parsed.get("saveVersion", 0))
	if version > SAVE_VERSION:
		push_warning("SaveManager: kayıt sürümü (%d) oyundan yeni (%d)." % [version, SAVE_VERSION])
	parsed = _migrate(parsed, version)

	if typeof(parsed.get("state", {})) == TYPE_DICTIONARY:
		GameState.from_dict(parsed["state"])
	if typeof(parsed.get("config", {})) == TYPE_DICTIONARY:
		GameConfig.from_dict(parsed["config"])

	EventBus.game_loaded.emit()
	return true


# --- Sil --------------------------------------------------------------------

func delete_save() -> bool:
	if not has_save():
		return false
	var dir := DirAccess.open("user://")
	if dir == null:
		return false
	return dir.remove(SAVE_PATH.get_file()) == OK


# --- Göç (migration) --------------------------------------------------------

## Eski kayıt şemalarını günceller. Şu an sürüm 1 tek başlangıç noktasıdır.
func _migrate(payload: Dictionary, from_version: int) -> Dictionary:
	# Örnek iskelet: if from_version < 2: ...
	payload["saveVersion"] = SAVE_VERSION
	return payload
