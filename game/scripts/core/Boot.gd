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
	if "--selftest" in OS.get_cmdline_user_args():
		_selftest()


func _selftest() -> void:
	GameClock.stop()
	print("[SELFTEST] baslangic")
	var atk = GameData.get_unit("bow").get("attack")
	var mainwood = GameData.get_building_level("main", 1).get("wood")
	var base = GameData.get_rule("costs").get("base_level1_cost", {}).get("main", {}).get("wood")
	var gf = GameData.get_rule("costs").get("growth_factor_groups", {}).get("standard", {}).get("wood")
	var pts = GameData.points_for("main", 1)
	print("  TYPE_INT=", TYPE_INT, " TYPE_FLOAT=", TYPE_FLOAT)
	print("  attack = ", atk, " tip=", typeof(atk), " int mi=", typeof(atk) == TYPE_INT, " 150 mi=", atk == 150)
	print("  main.wood = ", mainwood, " tip=", typeof(mainwood))
	print("  costs.base main.wood = ", base, " tip=", typeof(base))
	print("  costs.growth standard.wood = ", gf, " tip=", typeof(gf), " float mi=", typeof(gf) == TYPE_FLOAT)
	print("  points_for = ", pts, " int mi=", typeof(pts) == TYPE_INT)
	print("  rules int alan=", GameData.get_rule("battle").get("known"), " tip=", typeof(GameData.get_rule("battle").get("known")))
	print("  profil listesi = ", GameConfig.get_profile_names())
	print("  EN uygula=", GameConfig.apply_profile("en"), " kont=", GameConfig.count_max_distance, " gece=", GameConfig.night_bonus_enabled)
	print("  TR uygula=", GameConfig.apply_profile("tr"), " kont=", GameConfig.count_max_distance, " gece=", GameConfig.night_bonus_enabled)
	print("  bilinmeyen profil=", GameConfig.apply_profile("zz"), " (beklenen false)")
	print("  aktif profil=", GameConfig.describe_profile())
	GameState.reset()
	GameClock.reset()
	var ticks := [0]
	var cb := func(_d): ticks[0] += 1
	GameClock.tick.connect(cb)
	GameClock.fast_forward(60.0)
	print("  aktif koy YOK -> elapsed=", GameClock.elapsed_seconds, " tick=", ticks[0], " (beklenen 0/0)")
	GameState.add_village({"id": 7, "name": "Başkent", "resources": {}})
	print("  aktif koy id=", GameState.active_village_id, " var mi=", GameState.has_active_village())
	GameClock.fast_forward(60.0)
	print("  aktif koy VAR -> elapsed=", GameClock.elapsed_seconds, " tick=", ticks[0], " (beklenen 60/60)")
	GameClock.tick.disconnect(cb)
	var d := GameState.to_dict()
	GameState.reset()
	GameState.from_dict(d)
	print("  state aktif koy=", GameState.active_village_id, " koy sayisi=", GameState.get_village_count())
	print("  state anahtarlari=", d.keys())
	print("[SELFTEST] bitti")


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
