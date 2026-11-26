extends SceneTree
## test_build40_upgrade_and_perf.gd — Build 40 Geliştirme & Isınma/Pil Optimizasyonu Testleri:
## 1) Parşömen tüketimi (x2 -> x1 -> 0 -> envanterden ve cüzdandan tamamen kalkması)
## 2) Hedef eşya slotunun boş başlaması, tıklama VE sürükle-bırak ile dolup boşalması
## 3) Ekipman geliştirme sonuçlarının konuşma balonu kuyruğuna düşmemesi
## 4) Mobil FPS, VillageBackgroundCache, MapVillageView shader-free doku ve ağ/poll aralıkları

const LordModelScript := preload("res://scripts/model/LordModel.gd")
const VM := preload("res://scripts/model/VillageModel.gd")
const LordModalScript := preload("res://ui/LordModal.gd")
const LordUpgradeModalScript := preload("res://ui/LordUpgradeModal.gd")
const MapVillageViewScript := preload("res://scenes/map/MapVillageView.gd")
const VillageScene := preload("res://scenes/Village.tscn")

var _passed: int = 0
var _failed: int = 0
var _fail_labels: Array[String] = []


func _initialize() -> void:
	await _run_all()
	print("")
	print("==================== BUILD 40 TEST ÖZETİ ====================")
	print("PASS: %d   FAIL: %d" % [_passed, _failed])
	if _failed > 0:
		for l in _fail_labels:
			print("  - ", l)
	print("=============================================================")
	quit(1 if _failed > 0 else 0)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("PASS: ", label)
	else:
		_failed += 1
		_fail_labels.append(label)
		printerr("FAIL: ", label)


func _run_all() -> void:
	var gs := root.get_node_or_null("GameState")
	var lm := root.get_node_or_null("LordManager")
	var sm := root.get_node_or_null("StoreManager")
	var gd := root.get_node_or_null("GameData")
	var gclk := root.get_node_or_null("GameClock")
	var bgc := root.get_node_or_null("VillageBackgroundCache")
	var wm := root.get_node_or_null("WorldManager")
	_check(gs != null and lm != null and sm != null and gclk != null and bgc != null and wm != null, "Gerekli autoloadlar yüklü")
	if gs == null or lm == null or sm == null:
		return

	if gd != null and gd.has_method("load_all"):
		gd.call("load_all", true)
	gs.call("reset")

	var home_v := VM.create(100, "Başkent", 100, 100, "Hero40", false)
	home_v["resources"] = {"wood": 50000, "stone": 50000, "iron": 50000}
	home_v["buildings"] = {"main": 10, "barracks": 5, "wall": 5, "farm": 10, "storage": 15, "market": 5}
	gs.set("villages", [home_v])
	gs.set("active_village_id", 100)
	gs.set("player", {
		"id": 1,
		"name": "Hero40",
		"diamonds": 25,
		"scrolls": {},
		"lord": LordModelScript.default_lord_state(),
	})

	var kit_res: Dictionary = lm.call("grant_tutorial_starter_kit")
	var sword_id := str(kit_res.get("sword_id", ""))
	_check(not sword_id.is_empty(), "Başlangıç kılıcı verildi")

	# Tutorial konuşmalarını temizle (geliştirme testinde sadece geliştirme etkisi ölçülecek)
	while int(lm.call("get_speech_count")) > 0:
		lm.call("dismiss_current_speech")

	# Toplam 2 parşömen yap (1 ekle + 1 hammadde ile al = 2)
	lm.call("add_upgrade_scrolls", 1)
	var buy_res: Dictionary = lm.call("buy_scroll_with_resources")
	_check(bool(buy_res.get("ok", false)) and int(lm.call("get_scroll_count")) == 2, "Toplam 2 Geliştirme Parşömeni hazır (x2)")

	# -------------------------------------------------------------------------
	# TEST 2: Hedef slot boş başlar + sürükle-bırak VE tıklama ile seçilir/temizlenir
	# -------------------------------------------------------------------------
	var u_mod := LordUpgradeModalScript.new()
	root.add_child(u_mod)
	u_mod.call("open_modal")
	await process_frame

	_check(str(u_mod.get("_selected_item_id")) == "", "Geliştirme ekranında Hedef Eşya slotu otomatik dolmuyor (boş başlıyor)")
	var t_name_lbl := u_mod.get("_target_name_lbl") as Label
	_check(t_name_lbl != null and t_name_lbl.text == "Boş Slot", "Boş slot etiketi görünüyor")

	var item_card := u_mod.find_child("InvItemCard_%s" % sword_id, true, false) as Control
	var target_slot := u_mod.find_child("TargetItemSlot", true, false) as Control
	_check(item_card != null and target_slot != null, "Envanterde sürüklenebilir eşya kartı ve bırakılabilir hedef slotu mevcut")
	if item_card != null and target_slot != null:
		var item_drag: Variant = item_card.call("_get_drag_data", Vector2(10, 10))
		_check(typeof(item_drag) == TYPE_DICTIONARY and str((item_drag as Dictionary).get("item_id", "")) == sword_id, "Eşya kartı sürükleme verisi üretiyor")
		target_slot.call("_drop_data", Vector2(10, 10), item_drag)
		await process_frame
		_check(str(u_mod.get("_selected_item_id")) == sword_id, "Sürüklenen eşya hedef slota yerleşti")

		# Hedef slota tıklayınca boşalmalı
		u_mod.call("_on_target_slot_cleared")
		await process_frame
		_check(str(u_mod.get("_selected_item_id")) == "", "Hedef slota tıklanınca eşya geri çıkartılıyor (boş slot)")

		# Envanterdeki eşyaya tıklayınca tekrar yerleşmeli
		u_mod.call("_on_inv_item_selected", sword_id)
		await process_frame
		_check(str(u_mod.get("_selected_item_id")) == sword_id, "Envanterdeki eşyaya tıklayınca hedef slota yerleşti")

	# -------------------------------------------------------------------------
	# TEST 1 & 3: Parşömen tüketimi x2 -> x1 -> 0 + Konuşma balonu eklenmemesi
	# -------------------------------------------------------------------------
	# 1. Geliştirme (+0 -> +1): Parşömen x2 -> x1'e düşmeli ve örs slotu boşalmalı
	var scroll_card := u_mod.find_child("InvUpgradeScrollCard", true, false) as Control
	_check(scroll_card != null, "Envanterde Geliştirme Parşömeni kartı görünür (x2)")
	if scroll_card != null:
		var sc_drag: Variant = scroll_card.call("_get_drag_data", Vector2(10, 10))
		var slots: Array = u_mod.get("_grid_slots")
		(slots[0] as Control).call("_drop_data", Vector2(10, 10), sc_drag)
		await process_frame

	u_mod.call("_execute_upgrade")
	await process_frame
	_check(int(lm.call("get_scroll_count")) == 1, "1. geliştirmeden sonra parşömen adedi x2 -> x1 düştü")
	_check(int(u_mod.get("_placed_scroll_slot")) == -1, "Geliştirme sonrası örsteki parşömen yuvası tüketilip boşaltıldı")
	_check(int(sm.call("get_scroll_count", "lord_upgrade_scroll")) == 1, "Cüzdan parşömen sayacı da 1'e düştü")
	_check(int(lm.call("get_speech_count")) == 0, "Başarılı geliştirme sonucu konuşma balonuna eklenmedi")

	# Modaldan çık-gir yapınca x1 görünmeli
	u_mod.call("close_modal")
	await process_frame
	u_mod.call("open_modal")
	await process_frame
	_check(u_mod.find_child("InvUpgradeScrollCard", true, false) != null, "Çıkıp girince x1 parşömen envanterde görünmeye devam ediyor")

	# 2. Geliştirme (+1 -> +2): Parşömen x1 -> 0 olmalı ve kart tamamen kalkmalı
	u_mod.call("_on_inv_item_selected", sword_id)
	u_mod.call("_on_inv_scroll_clicked")
	await process_frame
	u_mod.call("_execute_upgrade")
	await process_frame
	_check(int(lm.call("get_scroll_count")) == 0, "2. geliştirmeden sonra son parşömen tükendi (0)")
	_check(u_mod.find_child("InvUpgradeScrollCard", true, false) == null, "Parşömen 0 olunca Geliştirme envanterinden tamamen kalktı")
	_check(not ((gs.get("player") as Dictionary).get("scrolls", {}) as Dictionary).has("lord_upgrade_scroll"), "Cüzdandan lord_upgrade_scroll anahtarı temizlendi")

	var l_mod := LordModalScript.new()
	root.add_child(l_mod)
	l_mod.call("open_modal")
	await process_frame
	_check(l_mod.find_child("LordInvScrollCard", true, false) == null, "LordModal envanterinden de parşömen kalktı")

	# Başarısız/yanma geliştirmesinde de konuşma balonu eklenmemeli
	var ld_cur: Dictionary = lm.call("get_lord_state")
	var risk_item := LordModelScript.create_item("chest", "common", 4, 888)
	(ld_cur["inventory"] as Array).append(risk_item)
	lm.call("add_upgrade_scrolls", 1)
	var fail_res: Dictionary = lm.call("upgrade_item", str(risk_item["id"]), 100)
	_check(bool(fail_res.get("ok", false)) and bool(fail_res.get("destroyed", false)), "Başarısız geliştirme testi çalıştı")
	_check(int(lm.call("get_speech_count")) == 0, "Başarısız geliştirme sonucu da konuşma balonuna eklenmedi")

	u_mod.free()
	l_mod.free()

	# -------------------------------------------------------------------------
	# TEST 4: Isınma / Pil Optimizasyonu + Akıcı 12 FPS Animasyon Doğrulamaları
	# -------------------------------------------------------------------------
	_check(int(bgc.get("FRAME_COUNT")) == 96 and is_equal_approx(float(bgc.get("FPS")), 12.0) and int(bgc.get("LOW_MEM_STRIDE")) == 2 and int(bgc.get("FRAMES_PER_TICK")) == 1, "VillageBackgroundCache akıcı 96 kare / 12 FPS + nazik 1 kare/tick ısıtma modunda")
	_check(int(gclk.get("ADAPTIVE_IDLE_FPS")) == 12 and int(gclk.get("ADAPTIVE_STATIC_IDLE_FPS")) == 4 and int(gclk.get("ADAPTIVE_BACKGROUND_FPS")) == 1 and int(gclk.get("ADAPTIVE_MOBILE_TAP_FPS")) == 30 and int(gclk.get("ADAPTIVE_MOBILE_DRAG_FPS")) == 45, "GameClock akıcı Köy 12 FPS & derin mobil pil/ısınma FPS kademeleri aktif")
	_check(is_equal_approx(float(wm.get("CLOUD_POLL_INTERVAL_SEC")), 45.0), "WorldManager bulut yoklama aralığı 45 sn")

	# Beat-aliasing (kasma/atlama) regresyon testi: 12 FPS (83.3 ms) penceresinde hafif erken gelen 0.081 sn tick'lerde bile her kare akıcı +1 ilerlemeli
	(gs.get("player") as Dictionary)["tutorial_completed"] = true
	var v_scene := VillageScene.instantiate()
	root.add_child(v_scene)
	await process_frame
	v_scene.set("_bg_frame_idx", 0)
	v_scene.set("_bg_frame_timer", 0.0)
	v_scene.set("_obscured_cache", false)
	v_scene.set("_obscured_check_accum", 0.0)
	var smooth_every_tick := true
	for tick_i in range(1, 13):
		v_scene.call("_process", 0.081)
		if int(v_scene.get("_bg_frame_idx")) != tick_i:
			smooth_every_tick = false
			break
	_check(smooth_every_tick and int(v_scene.get("_bg_frame_idx")) == 12, "Köy arka planı 12 ardışık karede atlama/takılma olmadan akıcı ilerledi (12/12)")
	root.remove_child(v_scene)
	v_scene.queue_free()
	await process_frame

	bgc.call("trim_memory")
	_check(bool(bgc.get("_low_memory_mode")), "Bellek uyarısında düşük bellek modu aktif")
	for idx in range(0, 96, 4):
		bgc.call("get_frame", idx)
	_check(bgc.get_frame(3) != null, "Düşük bellek modunda da her zaman geçerli kare döner")

	var bandit_view := MapVillageViewScript.new()
	bandit_view.setup({"id": 901, "name": "Haydut Kampı", "owner": "Haydutlar", "x": 102, "y": 102, "is_bandit": true, "buildings": {"main": 3}}, false, false, "")
	root.add_child(bandit_view)
	await process_frame
	var b_sprite := bandit_view.get("_sprite") as TextureRect
	_check(b_sprite != null and b_sprite.material == null and b_sprite.texture != null, "Haydut köyü özel fragment shader olmadan önceden grileştirilmiş doku ile çiziliyor")
	bandit_view.free()
	await process_frame
