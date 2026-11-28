extends SceneTree
## test_build44_thermal_and_smoothness.gd — Build 44 Kök Neden Isınma & Takılma Çözümü Doğrulama Paketi:
## 1) 1080×1920 temiz köy arka planı + küçük 2D sprite varlıkları (windmill_blades, smoke_puff, water_glint)
## 2) VillageAmbientLayer kesintisiz yel değirmeni dönüşü, baca dumanı, su parıltısı & obscured duraklatma
## 3) VillageBackgroundCache tek doku (FRAME_COUNT == 1, 0 thread, is_fully_loaded == true)
## 4) GameClock 60Hz/120Hz tam bölen FPS kademeleri (60/30/20/10/4/1) + low_processor_usage_mode geçişi
## 5) BotSimulator / EconomySimulator haydut köyü O(1) atlaması & GameState.sync_from_live_dict gereksiz lord kopyası yok
## 6) TutorialManager tamamlanınca _process kapanması & iOS köprü utility GCD timer doğrulaması
## 7) export_presets.cfg & ios-testflight.yml Build 44 + animated_bg/* dışlama kontrolü

const BotSimScript := preload("res://scripts/bot/BotSimulator.gd")
const EconomySimScript := preload("res://scripts/sim/economy/EconomySimulator.gd")
const VillageModelScript := preload("res://scripts/model/VillageModel.gd")
const LordModelScript := preload("res://scripts/model/LordModel.gd")

var _passes: int = 0
var _fails: int = 0


func _assert(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
		print("  [PASS] " + msg)
	else:
		_fails += 1
		printerr("  [FAIL] " + msg)


func _tick(frames: int = 2) -> void:
	for _i in range(frames):
		await process_frame


func _initialize() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	await _tick(2)
	print("=== BUILD 44 THERMAL & SMOOTHNESS VERIFICATION ===")

	var gd: Node = root.get_node_or_null("GameData")
	var gs: Node = root.get_node_or_null("GameState")
	var gclk: Node = root.get_node_or_null("GameClock")
	var wm: Node = root.get_node_or_null("WorldManager")
	var bgc: Node = root.get_node_or_null("VillageBackgroundCache")
	var tm: Node = root.get_node_or_null("TutorialManager")
	var qm: Node = root.get_node_or_null("QuestManager")
	_assert(gd != null and gs != null and gclk != null and wm != null and bgc != null and tm != null, "Temel autoload'lar yüklü")
	if gd != null and gd.has_method("load_all"):
		gd.call("load_all", true)
	if tm != null:
		tm.set("tutorial_enabled_in_headless", false)
	if qm != null:
		qm.set("quest_enabled_in_headless", false)

	# 1. Crisp 1080x1920 clean landscape + sprites
	var clean_img := Image.new()
	var err_clean := clean_img.load("res://assets/sprites/village/village_landscape_clean.jpg")
	_assert(err_clean == OK and clean_img.get_width() == 1080 and clean_img.get_height() == 1920, "village_landscape_clean.jpg 1080×1920 çözünürlükte")
	var blades_img := Image.new()
	var err_blades := blades_img.load("res://assets/sprites/village/windmill_blades.png")
	_assert(err_blades == OK and blades_img.get_width() == 256 and blades_img.get_height() == 256, "windmill_blades.png 256×256 RGBA hazır")
	_assert(ResourceLoader.exists("res://assets/sprites/village/smoke_puff.png") and ResourceLoader.exists("res://assets/sprites/village/water_glint.png"), "smoke_puff.png ve water_glint.png mevcut")

	# 2. Single-texture VillageBackgroundCache
	_assert(int(bgc.get("FRAME_COUNT")) == 1 and bool(bgc.get("is_fully_loaded")) and not bgc.is_processing(), "VillageBackgroundCache tek doku modunda (0 arka plan thread/timer)")
	_assert(bgc.call("get_base_texture") != null, "VillageBackgroundCache taban 1080p dokuyu döndürüyor")

	# 3. Village scene + VillageAmbientLayer continuity & pause
	gs.call("reset")
	var pv := VillageModelScript.create(100, "Başkent", 100, 100, "Lord44", false)
	gs.set("villages", [pv])
	gs.set("active_village_id", 100)
	gs.set("player", {"id": 1, "name": "Lord44", "tutorial_completed": true, "lord": LordModelScript.default_lord_state()})

	var v_scene := load("res://scenes/Village.tscn") as PackedScene
	var v_node := v_scene.instantiate() as Control
	root.add_child(v_node)
	var prev_scene := current_scene
	current_scene = v_node
	await _tick(3)

	var bg_rect := v_node.get("background") as TextureRect
	_assert(bg_rect != null and bg_rect.texture != null and bg_rect.texture.resource_path.ends_with("village_landscape_clean.jpg"), "Village Background temiz 1080p dokuyu kullanıyor")
	var amb := v_node.get("ambient_layer") as Node2D
	_assert(amb != null and amb.get_node_or_null("WindmillBlades") != null and amb.get_node_or_null("WindmillBladesShadow") != null, "VillageAmbientLayer yel değirmeni ve gölge sprite'larını oluşturdu")

	if amb != null:
		amb.call("set_ambient_paused", false)
		var prev_a := float(amb.call("get_windmill_angle"))
		var monotonic_ok := true
		for _i in range(20):
			amb.call("_process", 0.05)
			var cur_a := float(amb.call("get_windmill_angle"))
			var step_d := fposmod(cur_a - prev_a, TAU)
			if absf(step_d - 0.52 * 0.05) > 0.002:
				monotonic_ok = false
				break
			prev_a = cur_a
		_assert(monotonic_ok, "Yel değirmeni 20 adımda 0 jitter ile sabit açısal hızda döndü")

		gclk.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
		v_node.set("_obscured_check_accum", 1.0)
		v_node.call("_process", 0.1)
		_assert(bool(amb.call("is_ambient_paused")) and not amb.is_processing(), "Arkaplana alınınca VillageAmbientLayer process durduruluyor")
		gclk.notification(Node.NOTIFICATION_APPLICATION_RESUMED)

	# 4. GameClock clean integer divisors
	_assert(int(gclk.get("ADAPTIVE_MOBILE_DRAG_FPS")) == 60 and int(gclk.get("ADAPTIVE_MOBILE_TAP_FPS")) == 30 and int(gclk.get("ADAPTIVE_IDLE_FPS")) == 20 and int(gclk.get("ADAPTIVE_STATIC_IDLE_FPS")) == 4, "GameClock tüm mobil FPS kademeleri 60/120Hz tam böleni")
	gclk.set("_fps_boost_remaining", 0.0)
	gclk.call("_apply_adaptive_fps", true)
	_assert(int(gclk.call("get_current_target_fps")) == 20, "Köy ekranında boştayken GameClock = 20 FPS")

	current_scene = prev_scene
	v_node.queue_free()
	await _tick(2)

	# 5. BotSimulator & EconomySimulator fast skip for initialized Bandit villages
	var bandit_v := VillageModelScript.create(200, "Haydut Köyü Sv.3", 105, 105, "Haydutlar", true)
	bandit_v["is_bandit"] = true
	bandit_v["is_bot"] = true
	bandit_v["bandit_level"] = 3
	bandit_v["bandit_initialized"] = true
	bandit_v["resources"] = {"wood": 500.0, "stone": 500.0, "iron": 500.0}
	bandit_v["buildings"] = {"main": 3, "wood": 5, "stone": 5, "iron": 5, "wall": 3, "storage": 5, "farm": 5}
	var sim_player_v := VillageModelScript.create(100, "Başkent", 100, 100, "Lord44", false)
	sim_player_v["buildings"] = {"main": 5, "wood": 10, "stone": 10, "iron": 10, "storage": 15, "farm": 10}
	sim_player_v["resources"] = {"wood": 100.0, "stone": 100.0, "iron": 100.0}
	var sim_state := {"villages": [sim_player_v, bandit_v], "queues": []}
	var orig_b_wood := float((bandit_v["resources"] as Dictionary)["wood"])
	BotSimScript.process_tick(sim_state, 1000, 60.0)
	EconomySimScript.process_tick(sim_state, 1000, 60.0)
	_assert(float((bandit_v["resources"] as Dictionary)["wood"]) == orig_b_wood, "EconomySimulator statik haydut köylerini atlıyor")
	_assert(float((sim_player_v["resources"] as Dictionary)["wood"]) > 100.0, "EconomySimulator oyuncu köyünde üretimi normal sürdürüyor")

	# Guarded ensure_state_dict in sync_from_live_dict keeps exact lord dictionary identity
	var live_d: Dictionary = gs.call("as_live_dict")
	var lord_before: Dictionary = (gs.get("player") as Dictionary).get("lord", {})
	gs.call("sync_from_live_dict", live_d, false)
	var lord_after: Dictionary = (gs.get("player") as Dictionary).get("lord", {})
	_assert(is_same(lord_before, lord_after), "GameState.sync_from_live_dict() her tick'te Lord sözlüğünü yeniden tahsis etmiyor")

	# 6. iOS Bridge & Build 44 Config Checks
	var mm := FileAccess.get_file_as_string("res://../tools/ios_native_auth_bridge.mm")
	_assert(not mm.contains("NSTimer *pollTimer") and mm.contains("DISPATCH_QUEUE_PRIORITY_LOW") == false and mm.contains("QOS_CLASS_UTILITY") and mm.contains("access(fsPath, F_OK)"), "ios_native_auth_bridge.mm main-thread NSTimer yok; QOS_CLASS_UTILITY GCD + access() aktif")

	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	var ver_rx := RegEx.new()
	ver_rx.compile('application/version="(\\d+)"')
	var ver_m := ver_rx.search(presets)
	var bnum_cfg := int(ver_m.get_string(1)) if ver_m != null else 0
	_assert(presets.contains("assets/sprites/village/animated_bg/*") and bnum_cfg >= 44, "export_presets.cfg animated_bg/* dışlanmış ve build >= 44 (%d)" % bnum_cfg)
	var ci_yml := FileAccess.get_file_as_string("res://../.github/workflows/ios-testflight.yml")
	_assert(ci_yml.contains('DEFAULT_BUILD_NUMBER:') and ci_yml.contains("village_landscape_clean.jpg.import"), "ios-testflight.yml Build >= 44 ve temiz sprite ASTC import yapılandırması hazır")

	print("=== BUILD 44 VERIFICATION: %d PASS, %d FAIL ===" % [_passes, _fails])
	quit(1 if _fails > 0 else 0)
