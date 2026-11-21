extends Node
## GameConfig — sunucu (dünya) ayarları (Taht ve Kılıç).
##
## Kaynak: docs/10-HARITA-VE-DUNYA.md §5 ("World (Sunucu) Ayarları").
## TR ve EN dünyaları farklı olduğu için tüm ayarlar **veri olarak** tutulur ve
## JSON'a yazılıp okunabilir. Varsayılanlar TR dünyasına (World 59 TR) göredir:
## gece bonusu aktif (00:00–06:00), Kontun maksimum yolculuk mesafesi 80 alan.
##
## Not: EN dünyası baz alınacaksa `apply_profile("en")` çağrılır; bu da
##      `count_max_distance = 100` ve `night_bonus_enabled = false` yapar
##      (bkz. docs/TERIMLER.md §11, docs/10 §5).

const CONFIG_PATH := "user://taht_ve_kilic_config.json"

## Hazır dünya profilleri (TR / EN) veri dosyası.
const PROFILES_PATH := "res://data/world-profiles.json"

# --- Hız / üretim -----------------------------------------------------------

## İlk 7 gün hız artışı (7 × 86400 saniye, ×2 hız çarpanı).
const STARTER_BOOST_DAYS := 7
const STARTER_BOOST_SECONDS := 7 * 86400
const STARTER_BOOST_MULTIPLIER := 2.0

## Dünya hızı (üretim, inşaat süreleri vb. için çarpan). "Hız" (KingsAge s59-tr verileri 1× tabanında birebirdir; ilk 7 gün 2× aktiftir).
var speed: float = 1.0

## Birim hızı (orduların harita üzerinde ilerleme hızı). "Birim hızı".
var unit_speed: float = 1.0

# --- Gece bonusu ------------------------------------------------------------

## Savunanlar için gece bonusu. "Savunanlar için gece bonusu" (savunma ×2).
var night_bonus_enabled: bool = true

## Gece bonusu penceresi (yerel saat, [start_hour, end_hour)). TR: 00:00–06:00.
var night_bonus_window: Dictionary = {"start_hour": 0, "end_hour": 6}

## Gece bonusu çarpanı (savunma değerleri bu katsayıyla çarpılır).
var night_bonus_multiplier: float = 2.0

# --- Koruma süreleri --------------------------------------------------------

## Yeni oyuncular için saldırı koruması (gün).
var new_player_protection_days: int = 15

## Fetih Koruması (gün).
var conquest_protection_days: int = 15

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

# --- Dünya profili ----------------------------------------------------------

## Seçili dünya profili anahtarı ("tr" veya "en").
var current_profile: String = "tr"

# Yüklenen profiller: {profil_adı: {ayar: değer, ...}}
var _profiles: Dictionary = {}
var _default_profile: String = "tr"


static var instance: Node = null
static var _fallback: Node = null

static func get_singleton() -> Node:
	if instance != null:
		return instance
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var node: Node = (loop as SceneTree).root.get_node_or_null("GameConfig")
		if node != null:
			instance = node
			return instance
	if _fallback == null:
		var script = load("res://autoload/GameConfig.gd")
		_fallback = script.new()
	return _fallback


func _init() -> void:
	instance = self


func _ready() -> void:
	instance = self
	load_profiles()
	call_deferred("_setup_mobile_safe_area")
	# Kayıtlı ayar varsa onu yükle; yoksa varsayılan dünya profilini (TR) uygula.
	if FileAccess.file_exists(CONFIG_PATH) and load_from_file(CONFIG_PATH):
		return
	apply_profile(_default_profile)


# --- Mobil / iOS Güvenli Alan (Dynamic Island & Home Indicator) -------------

var _safe_bg_layer: CanvasLayer = null
var _safe_top_px: float = 0.0
var _safe_bottom_px: float = 0.0
var _safe_last_scene_id: int = 0
var _test_island_width: float = -1.0


func _setup_mobile_safe_area() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var tree := get_tree()
	if tree == null:
		return
	if not tree.tree_changed.is_connected(_on_tree_changed_safe_area):
		tree.tree_changed.connect(_on_tree_changed_safe_area)
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(_refresh_mobile_safe_area):
		vp.size_changed.connect(_refresh_mobile_safe_area)
	_refresh_mobile_safe_area()


func _on_tree_changed_safe_area() -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	var sid := tree.current_scene.get_instance_id()
	if sid != _safe_last_scene_id:
		_safe_last_scene_id = sid
		call_deferred("_refresh_mobile_safe_area")


func get_ios_safe_insets() -> Dictionary:
	if DisplayServer.get_name() == "headless":
		return {"top": 0.0, "bottom": 0.0}
	if not (OS.has_feature("ios") or OS.has_feature("android")):
		return {"top": 0.0, "bottom": 0.0}
	var vp := get_viewport()
	if vp == null:
		return {"top": 0.0, "bottom": 0.0}
	var win_size := DisplayServer.window_get_size()
	if win_size.x <= 0 or win_size.y <= 0:
		return {"top": 0.0, "bottom": 0.0}
	var safe := DisplayServer.get_display_safe_area()
	if safe.size.x <= 0 or safe.size.y <= 0:
		return {"top": 0.0, "bottom": 0.0}
	var vp_size := vp.get_visible_rect().size
	var scale_y: float = vp_size.y / float(win_size.y)
	var top_in: float = clampf(float(safe.position.y) * scale_y, 0.0, 180.0)
	var bot_raw: float = float(win_size.y - (safe.position.y + safe.size.y)) * scale_y
	var bot_in: float = clampf(bot_raw, 0.0, 110.0)
	return {"top": top_in, "bottom": bot_in}


func get_ios_safe_top() -> float:
	return _safe_top_px


func get_ios_safe_bottom() -> float:
	return _safe_bottom_px


func get_ios_dynamic_island_width() -> float:
	if _test_island_width >= 0.0:
		return _test_island_width
	if OS.get_name() == "iOS" and _safe_top_px >= 90.0:
		return 390.0
	return 0.0


func _refresh_mobile_safe_area() -> void:
	var insets := get_ios_safe_insets()
	_safe_top_px = float(insets.get("top", 0.0))
	_safe_bottom_px = float(insets.get("bottom", 0.0))
	var tree := get_tree()
	if tree == null:
		return
	var cur := tree.current_scene
	if cur is Control and (_safe_top_px > 0.0 or _safe_bottom_px > 0.0):
		var c := cur as Control
		var has_rbar := cur.has_node("ResourceBar")
		c.offset_top = 0.0 if has_rbar else _safe_top_px
		c.offset_bottom = -_safe_bottom_px
		if has_rbar:
			var rbar := cur.get_node_or_null("ResourceBar")
			if rbar != null and rbar.has_method("refresh"):
				rbar.call_deferred("refresh")
		if _safe_bg_layer == null:
			_safe_bg_layer = CanvasLayer.new()
			_safe_bg_layer.layer = -1
			_safe_bg_layer.name = "SafeAreaBackdrop"
			var rect := ColorRect.new()
			rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			rect.color = Color(0.06, 0.05, 0.08, 1.0)
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_safe_bg_layer.add_child(rect)
			add_child(_safe_bg_layer)
	elif cur is Control:
		var c := cur as Control
		c.offset_top = 0.0
		c.offset_bottom = 0.0


# --- Dünya profilleri -------------------------------------------------------

## `res://data/world-profiles.json` dosyasından profilleri okur.
func load_profiles(path: String = PROFILES_PATH) -> bool:
	if not FileAccess.file_exists(path):
		push_warning("GameConfig: dünya profilleri bulunamadı -> " + path)
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("GameConfig: dünya profilleri okunamadı -> " + path)
		return false
	var profiles = parsed.get("profiles", {})
	if typeof(profiles) != TYPE_DICTIONARY or (profiles as Dictionary).is_empty():
		push_warning("GameConfig: profil listesi boş -> " + path)
		return false
	_profiles = profiles
	var def := str(parsed.get("default_profile", "tr"))
	_default_profile = def if _profiles.has(def) else str(_profiles.keys()[0])
	return true


## Kullanılabilir profil adlarını (alfabetik) döndürür.
func get_profile_names() -> Array:
	if _profiles.is_empty():
		load_profiles()
	var names := _profiles.keys()
	names.sort()
	return names


## Profilin görünen adını (etiket) döndürür.
func get_profile_label(profile_name: String) -> String:
	return str((_profiles.get(profile_name, {}) as Dictionary).get("label", profile_name))


## Aktif profili okunabilir biçimde tanımlar (arayüz için).
func describe_profile() -> String:
	return "%s [%s]" % [get_profile_label(current_profile), current_profile]


## Verilen dünya profilini uygular (TR / EN). Başarı durumunu döndürür.
## Bilinmeyen profil adı verilirse hiçbir şey değişmez.
func apply_profile(profile_name: String) -> bool:
	if _profiles.is_empty():
		load_profiles()
	if not _profiles.has(profile_name):
		push_warning("GameConfig: bilinmeyen dünya profili -> " + profile_name)
		return false
	var profile: Dictionary = _profiles[profile_name]
	var settings: Dictionary = {}
	for key in profile.keys():
		if key == "label":
			continue
		settings[key] = profile[key]
	current_profile = profile_name
	from_dict(settings)
	return true


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


## Dünya/oyuncu meta verisinden hız ve ilk 7 gün 2x başlangıç bonusunu senkronize eder.
func sync_from_world(world_meta: Dictionary, now_unix: int = 0) -> void:
	if typeof(world_meta) != TYPE_DICTIONARY or world_meta.is_empty():
		return
	var check_now := now_unix if now_unix > 0 else int(Time.get_unix_time_from_system())
	var base_s := float(world_meta.get("base_speed", 1.0))
	var base_us := float(world_meta.get("base_unit_speed", 1.0))
	if is_starter_boost_active(world_meta, check_now):
		speed = maxf(base_s, STARTER_BOOST_MULTIPLIER)
		unit_speed = maxf(base_us, STARTER_BOOST_MULTIPLIER)
	else:
		speed = base_s if base_s > 0.0 else 1.0
		unit_speed = base_us if base_us > 0.0 else 1.0


## İlk 7 gün 2x hız bonusunun belirtilen unix zamanında aktif olup olmadığını döndürür.
func is_starter_boost_active(world_meta: Dictionary = {}, now_unix: int = 0) -> bool:
	return starter_boost_remaining_seconds(world_meta, now_unix) > 0


## İlk 7 gün 2x hız bonusundan kalan süreyi saniye cinsinden döndürür (yoksa 0).
func starter_boost_remaining_seconds(world_meta: Dictionary = {}, now_unix: int = 0) -> int:
	if typeof(world_meta) != TYPE_DICTIONARY or world_meta.is_empty():
		return 0
	var check_now := now_unix if now_unix > 0 else int(Time.get_unix_time_from_system())
	var boost_until := int(world_meta.get("starter_boost_until_unix", 0))
	if boost_until <= 0:
		var created := int(world_meta.get("player_joined_unix", world_meta.get("created_unix", 0)))
		if created > 0:
			boost_until = created + STARTER_BOOST_SECONDS
	if boost_until <= 0:
		return 0
	return maxi(0, boost_until - check_now)


# --- Serileştirme -----------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"profile": current_profile,
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
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var bus = (loop as SceneTree).root.get_node_or_null("EventBus")
		if bus != null and bus.has_signal("config_changed"):
			bus.config_changed.emit()


func _set_field(key: String, value) -> void:
	match key:
		"profile":
			current_profile = str(value)
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
	var cfg_dict: Dictionary = parsed
	# Hız çarpanı kullanıcı tarafından değiştirilemez; KingsAge profilinden sabitlenir.
	cfg_dict.erase("speed")
	cfg_dict.erase("unit_speed")
	from_dict(cfg_dict)
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


# --- Mobil Sanal Klavye & Odak Kapatma Yardımcıları ---------------------------

func _deferred_hide_virtual_keyboard() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.virtual_keyboard_hide()


var _last_touch_press_msec: int = 0
var _focus_guard_ctrl: Control = null
var _focus_guard_until_msec: int = 0


func mark_focus_guard(ctrl: Control, duration_ms: int = 450) -> void:
	_focus_guard_ctrl = ctrl
	_focus_guard_until_msec = Time.get_ticks_msec() + duration_ms


func dismiss_keyboard_for(target: Control = null) -> void:
	dismiss_virtual_keyboard(target)


func bind_keyboard_dismiss(ctrl: Control, on_submit: Callable = Callable(), numeric: bool = false) -> void:
	attach_mobile_keyboard_dismiss(ctrl, on_submit, numeric)


static func dismiss_virtual_keyboard(target: Control = null) -> void:
	if target != null and is_instance_valid(target):
		var par: Node = target.get_parent()
		if par is SpinBox:
			(par as SpinBox).apply()
		if target is SpinBox:
			(target as SpinBox).apply()
			var sb_le: LineEdit = (target as SpinBox).get_line_edit()
			if sb_le != null and sb_le.has_focus():
				sb_le.release_focus()
		elif target.has_focus():
			target.release_focus()
	if DisplayServer.get_name() != "headless":
		var loop := Engine.get_main_loop()
		if loop is SceneTree:
			var gc = loop.root.get_node_or_null("GameConfig")
			if gc != null and gc.has_method("_deferred_hide_virtual_keyboard"):
				gc.call_deferred("_deferred_hide_virtual_keyboard")
				return
		DisplayServer.virtual_keyboard_hide()


static func _extract_spin_digits(raw: String) -> String:
	var out: String = ""
	for i in range(raw.length()):
		var ch := raw.substr(i, 1)
		if ch >= "0" and ch <= "9":
			out += ch
	return out

static func _apply_spinbox_digits(sp: SpinBox, override_txt: String = "") -> void:
	if sp == null or not is_instance_valid(sp):
		return
	var le: LineEdit = sp.get_line_edit()
	var raw_txt: String = override_txt
	if raw_txt == "" and le != null and is_instance_valid(le):
		raw_txt = le.text
	var digits: String = _extract_spin_digits(raw_txt.strip_edges())
	var val: float = clampf(0.0, sp.min_value, sp.max_value)
	if digits != "":
		val = clampf(float(digits.to_int()), sp.min_value, sp.max_value)
	sp.value = val
	sp.apply()
	if le != null and is_instance_valid(le):
		var target_txt: String = str(int(sp.value))
		if le.text != target_txt:
			le.text = target_txt

static func attach_mobile_keyboard_dismiss(ctrl: Control, on_submit: Callable = Callable(), numeric: bool = false) -> void:
	if ctrl == null:
		return
	if ctrl is SpinBox:
		var sp := ctrl as SpinBox
		if not sp.has_meta("skip_live_update_on_text_changed"):
			sp.update_on_text_changed = true
		var le: LineEdit = sp.get_line_edit()
		if le != null:
			le.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
			le.focus_entered.connect(func():
				var gc_node: Node = get_singleton()
				if gc_node != null and gc_node.has_method("mark_focus_guard"):
					gc_node.call("mark_focus_guard", le, 450)
			)
			le.text_submitted.connect(func(txt: String):
				_apply_spinbox_digits(sp, txt)
				le.release_focus()
				dismiss_virtual_keyboard()
				if on_submit.is_valid():
					on_submit.call()
			)
			le.focus_exited.connect(func():
				_apply_spinbox_digits(sp, "")
				dismiss_virtual_keyboard()
			)
	elif ctrl is LineEdit:
		var le2 := ctrl as LineEdit
		if numeric:
			le2.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
		le2.focus_entered.connect(func():
			var gc_node: Node = get_singleton()
			if gc_node != null and gc_node.has_method("mark_focus_guard"):
				gc_node.call("mark_focus_guard", le2, 450)
		)
		le2.text_submitted.connect(func(txt: String):
			le2.release_focus()
			dismiss_virtual_keyboard()
			if on_submit.is_valid():
				on_submit.call(txt)
		)
		le2.focus_exited.connect(func():
			dismiss_virtual_keyboard()
		)
	elif ctrl is TextEdit:
		var te := ctrl as TextEdit
		te.focus_exited.connect(func():
			dismiss_virtual_keyboard()
		)


func _input(event: InputEvent) -> void:
	var is_headless := (DisplayServer.get_name() == "headless")
	if is_headless and not (event.has_meta("allow_headless_input_test")):
		return
	var now_ms := Time.get_ticks_msec()
	var tapped := false
	var tap_pos := Vector2.ZERO
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_last_touch_press_msec = now_ms
			tapped = true
			tap_pos = st.position
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			# Godot emulates MouseButton right after ScreenTouch at pre-lift coordinates; ignore it
			if _last_touch_press_msec > 0 and now_ms - _last_touch_press_msec < 200:
				return
			tapped = true
			tap_pos = mb.position
	if not tapped:
		return
	var vp := get_viewport()
	if vp == null:
		return
	var focus_owner: Control = vp.gui_get_focus_owner()
	if focus_owner == null or not is_instance_valid(focus_owner):
		return
	if not (focus_owner is LineEdit or focus_owner is TextEdit):
		return
	if focus_owner == _focus_guard_ctrl and now_ms <= _focus_guard_until_msec:
		return
	if focus_owner.get_global_rect().has_point(tap_pos):
		return
	if focus_owner.has_meta("keep_focus_controls"):
		var kf = focus_owner.get_meta("keep_focus_controls")
		if kf is Array:
			for c in kf:
				if c is Control and is_instance_valid(c) and (c as Control).is_visible_in_tree():
					if (c as Control).get_global_rect().has_point(tap_pos):
						return
	var par: Node = focus_owner.get_parent()
	if par is SpinBox:
		var sp := par as SpinBox
		if sp.get_global_rect().has_point(tap_pos):
			return
		_apply_spinbox_digits(sp, "")
	focus_owner.release_focus()
	call_deferred("_deferred_hide_virtual_keyboard")
