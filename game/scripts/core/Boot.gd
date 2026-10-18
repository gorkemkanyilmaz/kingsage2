extends Control
## Boot — açılış sahnesi (Taht ve Kılıç).
##
## Veri katmanını (GameData) yükler ve **kanıt** olarak ekranda oyun başlığı ile
## yüklenen bina sayısını gösterir. Ayrıca oyun saatini (GameClock) başlatır.

@onready var _title_label: Label = $Margin/VBox/TitleLabel
@onready var _subtitle_label: Label = $Margin/VBox/SubtitleLabel
@onready var _status_label: Label = $Margin/VBox/StatusLabel
@onready var _detail_label: Label = $Margin/VBox/DetailLabel

const COLOR_OK := Color(0.611765, 0.933333, 0.694118)   # pastel yeşil
const COLOR_ERROR := Color(0.980392, 0.650980, 0.650980)  # pastel kırmızı


func _ready() -> void:
	_title_label.text = "Taht ve Kılıç"
	_subtitle_label.text = "Kralın tahtı, kılıcı ve köyü"
	_load_and_report()
	# Oyun döngüsünü başlat (tick + offline telafi kancası hazır).
	GameClock.start()

	# Başarılı yükleme sonrası Ana Menü'ye geçiş
	var timer := get_tree().create_timer(1.0)
	timer.timeout.connect(func():
		if ResourceLoader.exists("res://scenes/MainMenu.tscn"):
			get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)


func _load_and_report() -> void:
	var ok := GameData.load_all(true)
	var building_count := GameData.get_all_building_keys().size()

	if ok and building_count > 0:
		_status_label.text = "Veri katmanı hazır — %d bina yüklendi." % building_count
		_status_label.modulate = COLOR_OK
	else:
		_status_label.text = "Veri katmanı yüklenemedi!"
		_status_label.modulate = COLOR_ERROR

	_detail_label.text = GameData.summary()
	_detail_label.text += "\nDünya profili: " + GameConfig.describe_profile()

	if not GameData.load_errors.is_empty():
		_detail_label.text += "\nUyarı: " + _join_errors(GameData.load_errors)
		_detail_label.modulate = COLOR_ERROR

	# Açılış logu (veri katmanı kanıtı).
	print("[Boot] ", _status_label.text)
	print("[Boot] ", GameData.summary())
	print("[Boot] Dünya profili: ", GameConfig.describe_profile())
	if not GameData.load_errors.is_empty():
		print("[Boot] Uyarı: ", _join_errors(GameData.load_errors))


func _join_errors(errors: Array) -> String:
	var parts := PackedStringArray()
	for error in errors:
		parts.append(str(error))
	return ", ".join(parts)


func _unhandled_input(event: InputEvent) -> void:
	# Dokunma/tık ile veriyi yeniden yükle (hızlı doğrulama).
	if event is InputEventMouseButton and event.pressed:
		_load_and_report()
	elif event is InputEventScreenTouch and event.pressed:
		_load_and_report()
