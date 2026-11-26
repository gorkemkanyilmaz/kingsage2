extends SceneTree
## test_build33_zero_thermal_perf.gd — Build 33 Isınma / Şarj / Kasma Kök Neden Optimizasyon Testleri:
## 1) VillageBackgroundCache: 96 kare (stride=2, 12 FPS, 8.0 sn döngü), trim_memory() & ensure_warming()
## 2) Village.gd: is_background_obscured() tam ekran modal / arkaplanda animasyonu durdurur, normalken akar
## 3) GameClock.gd: 60 / 15 / 12 / 10 / 2 FPS adaptif hedefleri + yabancı seferlerde harita 10 FPS'te kalır
## 4) shadow_size == 0 ve StyleBox önbelleği: MapVillageView (shared StyleBox) & BuildingView (zero realloc)
## 5) ResourceBar.gd: pasif 1 sn refresh() başlığı ve ProgressBar stilini gereksiz yeniden yazmaz
## 6) WorldMap.gd: yabancı seferler _had_movements_drawn = true yapmaz; kendi/gelen seferler çizer
## 7) SaveManager.save_game(false, false) ve ArmySimulator koşullu reconcile

const BuildingViewScript := preload("res://scenes/village/BuildingView.gd")
const MapVillageViewScript := preload("res://scenes/map/MapVillageView.gd")
const ArmySimScript := preload("res://scripts/sim/army/ArmySimulator.gd")

var _passed: int = 0
var _failed: int = 0


func _assert(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("[PASS] ", label)
	else:
		_failed += 1
		printerr("[FAIL] ", label)


func _tick(frames: int = 2) -> void:
	for _i in range(frames):
		await process_frame


func _initialize() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	var gd := root.get_node_or_null("GameData")
	var gc := root.get_node_or_null("GameConfig")
	var gs := root.get_node_or_null("GameState")
	var gclk := root.get_node_or_null("GameClock")
	var wm := root.get_node_or_null("WorldManager")
	var sm := root.get_node_or_null("SaveManager")
	var auth := root.get_node_or_null("AuthManager")
	var tm := root.get_node_or_null("TutorialManager")
	var qm := root.get_node_or_null("QuestManager")
	var bgc := root.get_node_or_null("VillageBackgroundCache")

	_assert(gd != null and gc != null and gs != null and gclk != null and wm != null and sm != null and auth != null and bgc != null, "Autoloads loaded")
	if gd != null and gd.has_method("load_all"):
		gd.call("load_all", true)
	if tm != null:
		tm.set("tutorial_enabled_in_headless", false)
	if qm != null:
		qm.set("quest_enabled_in_headless", false)

	wm.call("wipe_all_local_data")
	auth.call("clear_all_account_data")
	auth.call("login_with_apple", "Lord Build33", "b33@privaterelay.appleid.com", "apple_uid_b33")
	var joined: bool = bool(wm.call("join_world", 1, "Lord Build33", 100, 100))
	_assert(joined and bool(gs.call("has_active_village")), "World 1 joined cleanly")
	gs.player["tutorial_completed"] = true

	await _test_background_cache(bgc)
	await _test_shared_styles_and_shadows()
	await _test_village_pause_and_clock(gs, gclk, qm)
	await _test_worldmap_foreign_filter_and_clock(gs, gclk)
	await _test_resource_bar_caching(gs)
	await _test_save_and_army_reconcile(gs, sm)

	wm.call("wipe_all_local_data")
	print("\n=== TestBuild33ZeroThermalPerf: %d BASARILI, %d BASARISIZ ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_background_cache(bgc: Node) -> void:
	print("\n-- 1) VillageBackgroundCache --")
	_assert(int(bgc.get("FRAME_COUNT")) == 96, "FRAME_COUNT == 96")
	_assert(int(bgc.get("FRAME_STRIDE")) == 2, "FRAME_STRIDE == 2")
	_assert(is_equal_approx(float(bgc.get("FPS")), 12.0), "FPS == 12.0")
	_assert(is_equal_approx(float(bgc.get("LOOP_DURATION")), 8.0), "LOOP_DURATION == 8.0 sn")
	_assert(str(bgc.call("_frame_path", 0)).ends_with("f_000.webp"), "Frame 0 -> f_000.webp")
	_assert(str(bgc.call("_frame_path", 1)).ends_with("f_002.webp"), "Frame 1 -> f_002.webp")
	_assert(bgc.call("get_frame", 5) != null, "Frame 5 yüklenebiliyor")
	bgc.call("trim_memory")
	var arr: Array = bgc.get("frames")
	_assert(arr.size() == 96 and arr[0] != null and arr[5] == null, "trim_memory() frames[0]'ı koruyup frames[1..]'ı serbest bırakıyor")
	_assert(not bool(bgc.get("is_fully_loaded")), "trim_memory() is_fully_loaded = false yapıyor")
	bgc.call("ensure_warming")
	_assert(bgc.is_processing(), "ensure_warming() yeniden önbelleklemeyi başlatıyor")
	await _tick(1)


func _test_shared_styles_and_shadows() -> void:
	print("\n-- 2) Shared StyleBoxes & Zero Shadow Overdraw --")
	var mv1: Control = MapVillageViewScript.new()
	var mv2: Control = MapVillageViewScript.new()
	var vdata := {"id": 10, "name": "TestKöy", "owner": "Lord Build33", "x": 100, "y": 100, "points": 250, "buildings": {"main": 5}}
	mv1.call("setup", vdata, true, false, "")
	mv2.call("setup", vdata, true, false, "")
	root.add_child(mv1)
	root.add_child(mv2)
	await _tick(1)
	var card1: PanelContainer = mv1.get("_info_card")
	var card2: PanelContainer = mv2.get("_info_card")
	var sb1 := card1.get_theme_stylebox("panel") as StyleBoxFlat
	var sb2 := card2.get_theme_stylebox("panel") as StyleBoxFlat
	_assert(sb1 != null and sb1 == sb2, "MapVillageView bilgi kartları aynı paylaşılan StyleBoxFlat örneğini kullanıyor")
	_assert(sb1 != null and sb1.shadow_size == 0, "MapVillageView card shadow_size == 0")
	mv1.queue_free()
	mv2.queue_free()

	var bv: Control = BuildingViewScript.new()
	root.add_child(bv)
	bv.call("setup", "main", "Kale")
	bv.call("set_state", 2, false, true, 25.0, 120)
	var lb: PanelContainer = bv.get("_level_badge")
	var bsb1 := lb.get_theme_stylebox("panel") as StyleBoxFlat
	_assert(bsb1 != null and bsb1.shadow_size == 0, "BuildingView badge shadow_size == 0")
	bv.call("set_state", 2, false, true, 25.4, 119)
	var bsb2 := lb.get_theme_stylebox("panel") as StyleBoxFlat
	_assert(bsb1 == bsb2, "BuildingView inşaat ilerlerken StyleBox yeniden tahsis etmiyor")
	bv.call("_stop_hammer_anim")
	bv.queue_free()
	await _tick(1)


func _test_village_pause_and_clock(gs: Node, gclk: Node, qm: Node) -> void:
	print("\n-- 3) Village Arkaplan Duraklatma & GameClock --")
	var v_scene: PackedScene = load("res://scenes/Village.tscn")
	var v_node := v_scene.instantiate() as Control
	root.add_child(v_node)
	var prev_scene := current_scene
	current_scene = v_node
	await _tick(2)

	_assert(not bool(v_node.call("is_background_obscured")), "Köy görünürken arka plan duraklatılmıyor")
	gclk.set("_fps_boost_remaining", 0.0)
	gclk.call("_apply_adaptive_fps", true)
	_assert(int(gclk.call("get_current_target_fps")) == 12, "Köyde boştayken GameClock = 12 FPS")

	# BuildingPanel açıkken üst %40 görünür olduğu için arka plan DURMAMALI
	var bp: Control = v_node.get("building_panel")
	if bp != null:
		bp.call("show_building", gs.call("get_active_village"), "main")
		await _tick(1)
		_assert(not bool(v_node.call("is_background_obscured")), "BuildingPanel açıkken arka plan akmaya devam ediyor")
		bp.call("hide")

	# Uygulama arkaplanına alınınca arka plan adımı durmalı ve target FPS = 1
	gclk.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_assert(bool(v_node.call("is_background_obscured")), "Uygulama arkaplanındayken is_background_obscured() == true")
	_assert(int(gclk.call("get_current_target_fps")) == 1, "Uygulama arkaplanındayken GameClock = 1 FPS")
	var idx_paused_before: int = int(v_node.get("_bg_frame_idx"))
	v_node.call("_process", 0.25)
	_assert(int(v_node.get("_bg_frame_idx")) == idx_paused_before, "Arkaplandayken köy video karesi ilerletilmiyor")
	gclk.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	_assert(int(gclk.call("get_current_target_fps")) == 60, "Ön plana dönünce GameClock anında = 60 FPS")

	# Tam ekran Quest detail modalı varken arka plan durmalı ve FPS = 4
	if qm != null:
		var dmodal = qm.get("_detail_modal")
		if dmodal == null:
			qm.call("_build_ui")
			dmodal = qm.get("_detail_modal")
		if dmodal != null:
			dmodal.show()
		await _tick(1)
		_assert(bool(v_node.call("is_background_obscured")), "Tam ekran modal açıkken arka plan duraklatılıyor")
		gclk.set("_fps_boost_remaining", 0.0)
		gclk.call("_apply_adaptive_fps", true)
		_assert(int(gclk.call("get_current_target_fps")) == 4, "Tam ekran modal açıkken köy hedefi = 4 FPS")
		if dmodal != null:
			dmodal.hide()

	current_scene = prev_scene
	v_node.queue_free()
	await _tick(2)


func _test_worldmap_foreign_filter_and_clock(gs: Node, gclk: Node) -> void:
	print("\n-- 4) WorldMap Yabancı Sefer Filtresi & Çizim Kapısı --")
	var wm_scene: PackedScene = load("res://scenes/WorldMap.tscn")
	var wmap := wm_scene.instantiate() as Control
	root.add_child(wmap)
	var prev_scene := current_scene
	current_scene = wmap
	var now := int(Time.get_unix_time_from_system())
	# Yalnızca yabancı bir oyuncunun seferi (bizim köylerimizle ilgisiz)
	gs.movements = [{"id": 888, "type": "attack", "state": "outgoing", "owner": "YabanciBot", "from_village_id": 9901, "to_village_id": 9902, "arrive_unix": now + 300}]
	await _tick(2)
	wmap.call("_process", 0.2)
	_assert(not bool(wmap.call("has_visible_movements")), "Yabancı sefer has_visible_movements() = false dönüyor")
	_assert(not bool(wmap.get("_had_movements_drawn")), "Yabancı sefer varken WorldMap movements_layer yeniden çizilmiyor")
	gclk.set("_fps_boost_remaining", 0.0)
	gclk.call("_apply_adaptive_fps", true)
	_assert(int(gclk.call("get_current_target_fps")) == 4, "Yalnızca yabancı sefer varken Harita = 4 FPS")

	# Kendi seferimiz eklenince 10 FPS & çizim etkin
	var pv: Dictionary = gs.call("get_active_village")
	gs.movements = [{"id": 889, "type": "attack", "state": "outgoing", "owner": "Lord Build33", "from_village_id": int(pv.get("id", 1)), "to_village_id": 2, "arrive_unix": now + 300}]
	wmap.call("_process", 0.2)
	_assert(bool(wmap.call("has_visible_movements")), "Kendi seferimizde has_visible_movements() = true")
	_assert(bool(wmap.get("_had_movements_drawn")), "Kendi seferimizde movements_layer çiziliyor")
	gclk.call("_apply_adaptive_fps", true)
	_assert(int(gclk.call("get_current_target_fps")) == 10, "Görünür sefer varken Harita = 10 FPS")

	gs.movements = []
	current_scene = prev_scene
	wmap.queue_free()
	await _tick(2)


func _test_resource_bar_caching(gs: Node) -> void:
	print("\n-- 5) ResourceBar Önbellek Doğrulaması --")
	var rb_scene: PackedScene = load("res://ui/ResourceBar.tscn")
	var rb := rb_scene.instantiate() as PanelContainer
	root.add_child(rb)
	await _tick(2)
	rb.call("refresh")
	var hdr1: String = str(rb.get("_last_header_sig"))
	var lay1: String = str(rb.get("_last_layout_sig"))
	_assert(not hdr1.is_empty() and not lay1.is_empty(), "ResourceBar ilk refresh imzalarını önbelleğe aldı")
	var pv: Dictionary = gs.call("get_active_village")
	(pv["resources"] as Dictionary)["wood"] = int((pv["resources"] as Dictionary).get("wood", 0)) + 5
	rb.call("refresh")
	_assert(str(rb.get("_last_header_sig")) == hdr1, "Kaynak değişiminde başlık imzası bozulmadı (gereksiz reset_size atlandı)")
	var wood_sb_id := (rb.get("wood_bar") as ProgressBar).get_instance_id()
	_assert((rb.get("_last_gauge_sb_by_id") as Dictionary).has(wood_sb_id), "ResourceBar ProgressBar StyleBox referansı önbellekte")
	rb.queue_free()
	await _tick(1)


func _test_save_and_army_reconcile(gs: Node, sm: Node) -> void:
	print("\n-- 6) SaveManager & ArmySimulator Optimizasyonu --")
	var ok_local: bool = bool(sm.call("save_game", false, false))
	_assert(ok_local, "SaveManager.save_game(false, false) yerel disk kaydı başarılı")
	var pv: Dictionary = gs.call("get_active_village")
	var now := int(Time.get_unix_time_from_system())
	pv["units"] = {"spear": 0}
	pv["settlers_reserved"] = 10
	var state_dict: Dictionary = {
		"villages": [pv],
		"queues": [{"id": 500, "village_id": int(pv.get("id", 1)), "type": "train", "key": "spear", "count": 10, "settlers": 10, "finish_unix": now}],
	}
	var evs: Array = ArmySimScript.process_tick(state_dict, now, 1.0)
	_assert(evs.size() == 1 and int((pv["units"] as Dictionary).get("spear", 0)) == 10, "ArmySimulator eğitim tamamlandı olayını üretti")
	_assert(int(pv.get("settlers_reserved", -1)) == 0, "ArmySimulator eğitim bitince settlers_reserved doğru sıfırlandı")
