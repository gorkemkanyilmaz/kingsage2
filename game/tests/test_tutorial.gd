extends SceneTree
## test_tutorial.gd — Baş Vezir Başlangıç Rehberi (Tutorial) E2E doğrulama testi.

const VM := preload("res://scripts/model/VillageModel.gd")
const RE := preload("res://scripts/rules/RulesEngine.gd")

var _passed: int = 0
var _failed: int = 0
var _fail_labels: Array[String] = []
var _active_scene: Node = null


func _initialize() -> void:
	await _run_tests()
	print("")
	print("==================== TUTORIAL E2E ÖZET ====================")
	print("PASS: %d   FAIL: %d" % [_passed, _failed])
	if _failed > 0:
		print("Başarısız kontroller:")
		for lbl in _fail_labels:
			print("  - ", lbl)
	print("===========================================================")
	quit(1 if _failed > 0 else 0)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("PASS: ", label)
	else:
		_failed += 1
		_fail_labels.append(label)
		printerr("FAIL: ", label)


func _tick(frames: int = 3) -> void:
	for _i in range(frames):
		await process_frame


func _swap_scene(res_path: String) -> Node:
	if _active_scene != null and is_instance_valid(_active_scene):
		root.remove_child(_active_scene)
		_active_scene.queue_free()
		_active_scene = null
		await _tick(2)
	var packed := load(res_path) as PackedScene
	if packed == null:
		return null
	var inst := packed.instantiate()
	root.add_child(inst)
	_active_scene = inst
	await _tick(3)
	return inst


func _press_button(btn: BaseButton) -> void:
	if btn == null:
		return
	btn.emit_signal("pressed")


func _click_building(village: Node, b_key: String) -> void:
	var bv = village.call("get_building_view", b_key) if village.has_method("get_building_view") else null
	_check(bv != null, "Bina görünümü mevcut: %s" % b_key)
	if bv != null and bv.has_signal("clicked"):
		bv.emit_signal("clicked")
	elif village.has_method("_on_building_clicked"):
		village.call("_on_building_clicked", b_key)
	elif village.get("building_panel") != null:
		var gs := root.get_node("GameState")
		village.get("building_panel").call("show_building", gs.call("get_active_village"), b_key)
	await _tick(3)


func _run_tests() -> void:
	var gd := root.get_node_or_null("GameData")
	var gs := root.get_node_or_null("GameState")
	var tm := root.get_node_or_null("TutorialManager")
	var gc := root.get_node_or_null("GameConfig")

	_check(gd != null and gs != null and tm != null, "Gerekli autoload düğümleri yüklü")
	if gd == null or gs == null or tm == null:
		return

	gd.call("load_all", true)
	if gc != null:
		gc.set("speed", 1.0)

	# Yeni oyuncu durumu oluştur (is_bot = false)
	var v := VM.create(1, "Başkent", 100, 100, "TestLord", false)
	v["resources"] = {"wood": 1000, "stone": 1000, "iron": 1000}
	v["buildings"] = {"main": 1, "stone": 1, "wood": 1, "iron": 1, "farm": 1, "storage": 1, "barracks": 0}
	v["researched"] = {}
	v["units"] = {}

	gs.set("villages", [v])
	gs.set("active_village_id", 1)
	gs.set("queues", [])
	gs.set("player", {
		"name": "TestLord",
		"alliance_id": -1,
		"tutorial_step": 0,
		"tutorial_completed": false,
		"tutorial_reward_claimed": false,
	})
	gs.set("world", {
		"id": 1,
		"name": "Dünya 1",
		"map_width": 200,
		"map_height": 200,
		"speed": 1.0,
		"sim_now_unix": int(Time.get_unix_time_from_system()),
	})

	tm.set("tutorial_enabled_in_headless", true)
	tm.call("start_tutorial")

	# 1. Village yükle ve Step 0 -> Step 1 -> Step 2 geçişlerini doğrula
	var village := await _swap_scene("res://scenes/Village.tscn")
	_check(village != null, "Village.tscn yüklendi")
	_check(tm.call("is_tutorial_active"), "Başlangıç rehberi yeni oyuncuda aktif")
	_check(int(tm.call("get_current_step")) == 0, "Adım 0 (WELCOME_INTRO) başladı")

	var btn_next := tm.get("_btn_next") as Button
	var btn_speedup := tm.get("_btn_speedup") as Button
	var step0_target = tm.call("_resolve_target_control", village, "Village.tscn", gs)
	_check(step0_target == btn_next, "Adım 0'da Kale spotlight yerine yalnızca 'Devam Et' hedeflendi (Kale pasif)")
	var dim_bottom := tm.get("_dim_bottom") as Control
	_check(dim_bottom != null and not dim_bottom.visible, "Adım 0'da köy arka planı tek parça pasif karartılmış")

	_press_button(btn_next)
	await _tick(2)
	_check(int(tm.call("get_current_step")) == 1, "Adım 1 (RESOURCE_BAR_TOUR) geçildi")

	_press_button(btn_next)
	await _tick(2)
	_check(int(tm.call("get_current_step")) == 2, "Adım 2 (SELECT_MAIN_CASTLE) geçildi")

	# 2. Kale seç ve paneli kapat (Adım 2 -> 3 -> 4)
	await _click_building(village, "main")
	_check(int(tm.call("get_current_step")) == 3, "Adım 3 (INSPECT_MAIN_PANEL) geçildi")

	var bp := village.get("building_panel") as Control
	_check(bp != null and bp.visible, "Kale için BuildingPanel açıldı")
	var close_btn := bp.get_node_or_null("VBox/Header/CloseButton") as BaseButton
	_press_button(close_btn)
	await _tick(2)
	_check(int(tm.call("get_current_step")) == 4, "Adım 4 (SELECT_WOOD_CAMP) geçildi")

	# 3. Oduncu seç ve Sv.2'ye yükselt (Adım 4 -> 5 -> Elmas Pazarı -> Parşömen -> Hızlandırma -> 6)
	var store := root.get_node_or_null("StoreManager")
	_check(store != null and int(store.call("get_diamonds")) == 35, "Yeni oyuncu başlangıçta 35 Elmas (💎) ile başladı")
	await _click_building(village, "wood")
	_check(int(tm.call("get_current_step")) == 5, "Adım 5 (UPGRADE_WOOD_CAMP) geçildi")
	var upg_btn := bp.get_node_or_null("VBox/UpgradeButton") as BaseButton
	_press_button(upg_btn)
	await _tick(2)
	var rbar_tut := village.get_node_or_null("ResourceBar")
	var btn_mkt_tut := rbar_tut.find_child("BtnMarket", true, false) as BaseButton if rbar_tut != null else null
	_check(btn_mkt_tut != null, "Üst barda 💎 Elmas Pazarı butonu mevcut")
	_check(tm.call("_resolve_target_control", village, "Village.tscn", gs) == btn_mkt_tut, "Oduncu inşaatında sağ üst 💎 Elmas Pazarı hedeflendi")
	if btn_mkt_tut != null:
		_press_button(btn_mkt_tut)
		await _tick(3)
	var mkt_modal := root.get_node_or_null("RoyalMarketModal")
	_check(mkt_modal != null, "Elmas Pazarı modalı açıldı")
	var buy_b10 := mkt_modal.find_child("BuyScrollBtn_build_10m", true, false) as BaseButton if mkt_modal != null else null
	_check(buy_b10 != null, "10 Dk İnşaat Parşömeni satın al butonu (BuyScrollBtn_build_10m) bulundu")
	_check(tm.call("_resolve_target_control", village, "Village.tscn", gs) == buy_b10, "Pazar içinde BuyScrollBtn_build_10m hedeflendi")
	if buy_b10 != null:
		_press_button(buy_b10)
		await _tick(2)
	_check(int(store.call("get_diamonds")) == 30 and int(store.call("get_scroll_count", "build_10m")) == 1, "5 Elmas ile 1 adet İnşaat 10 Dk parşömeni alındı (30 💎 kaldı)")
	var mkt_close := mkt_modal.find_child("MarketCloseBtn", true, false) as BaseButton if mkt_modal != null else null
	if mkt_close != null:
		_press_button(mkt_close)
		await _tick(2)
	var build_spd_btn := bp.find_child("BuildSpeedupButton", true, false) as BaseButton
	_check(build_spd_btn != null and build_spd_btn.visible, "İnşaat kutusunda BuildSpeedupButton görünüyor")
	if build_spd_btn != null:
		_press_button(build_spd_btn)
		await _tick(2)
	var spd_modal := root.get_node_or_null("SpeedupModal")
	_check(spd_modal != null, "Hızlandırma Parşömeni modalı (SpeedupModal) açıldı")
	var use_b10 := spd_modal.find_child("UseScrollBtn_build_10m", true, false) as BaseButton if spd_modal != null else null
	_check(use_b10 != null, "UseScrollBtn_build_10m butonu bulundu")
	_check(tm.call("_resolve_target_control", village, "Village.tscn", gs) == use_b10, "SpeedupModal içinde UseScrollBtn_build_10m hedeflendi")
	if use_b10 != null:
		_press_button(use_b10)
		await _tick(3)
	elif btn_speedup != null and btn_speedup.visible:
		_press_button(btn_speedup)
		await _tick(3)
	var active_v: Dictionary = gs.call("get_active_village")
	_check(int(active_v["buildings"].get("wood", 0)) >= 2, "Oduncu Sv.2 parşömen ile anında tamamlandı")
	_check(int(store.call("get_scroll_count", "build_10m")) == 0, "Kullanılan 10 Dk İnşaat parşömeni envanterden düştü")
	_check(int(tm.call("get_current_step")) == 6, "Adım 6 (CHECK_BARRACKS_REQS) geçildi")

	# 4. Oduncu paneli hala açıksa önce Kapat (✕) butonunu hedefle, kapanınca Kışla'yı hedefle
	_check(bp.visible and tm.call("_resolve_target_control", village, "Village.tscn", gs) == close_btn, "Adım 6'da Oduncu paneli açıkken CloseButton hedeflendi")
	if bp.visible:
		_press_button(close_btn)
		await _tick(2)
	var barracks_bv = village.call("get_building_view", "barracks")
	_check(tm.call("_resolve_target_control", village, "Village.tscn", gs) == barracks_bv, "Panel kapanınca Kışla hedefe geçti")
	await _click_building(village, "barracks")
	_check(int(tm.call("get_current_step")) == 7, "Adım 7 (COMPLETE_BARRACKS_PREREQS) geçildi")

	var goto_sto := bp.find_child("GotoBtn_storage", true, false) as BaseButton
	_check(goto_sto != null, "Kışla gereksinim zincirinde GotoBtn_storage butonu bulundu")
	_press_button(goto_sto)
	await _tick(2)
	_check(str(bp.get("_current_key")) == "storage", "GotoBtn_storage tıklanınca Depo paneline geçildi")

	# Depo Lv.1 -> Lv.2 -> Lv.3
	for target_lvl in [2, 3]:
		_press_button(upg_btn)
		await _tick(2)
		_press_button(btn_speedup)
		await _tick(2)
	active_v = gs.call("get_active_village")
	_check(int(active_v["buildings"].get("storage", 0)) >= 3, "Depo Sv.3 tamamlandı")
	var target_after_sto = tm.call("_resolve_target_control", village, "Village.tscn", gs)
	_check(target_after_sto == close_btn, "Depo Sv.3 tamamlanıp Değirmen < 3 iken Depo penceresini kapatma hedeflendi (Kışla'ya atlamadı)")

	# Değirmen Lv.3 olmadan yanlışlıkla BUILD_BARRACKS_LV1'e geçilse bile COMPLETE_BARRACKS_PREREQS'e geri dönmeli
	tm.set("_current_step", 14)
	await _tick(2)
	_check(int(tm.call("get_current_step")) == 7, "Değirmen Sv.3 yapılmadan Kışla adımına (14) izin verilmedi, Adım 7'ye geri döndü")

	# Değirmen'i kapatıp aç ve Lv.2 -> Lv.3 yap
	if bp.visible:
		_press_button(close_btn)
		await _tick(2)
	var farm_bv = village.call("get_building_view", "farm")
	_check(tm.call("_resolve_target_control", village, "Village.tscn", gs) == farm_bv, "Panel kapanınca Kışla yerine Değirmen hedefe geçti")
	await _click_building(village, "farm")
	for target_lvl in [2, 3]:
		_press_button(upg_btn)
		await _tick(2)
		_press_button(btn_speedup)
		await _tick(2)
	active_v = gs.call("get_active_village")
	_check(int(active_v["buildings"].get("farm", 0)) >= 3, "Değirmen Sv.3 tamamlandı")
	_check(not bp.visible, "Adım 8 geçişinde BuildingPanel otomatik kapandı")
	_check(int(tm.call("get_current_step")) == 8, "Adım 8 (OPEN_WORLD_MAP) geçildi")

	# 5. Dünya Haritası turu (Adım 8 -> 9 -> 10 -> 11)
	var wmap := await _swap_scene("res://scenes/WorldMap.tscn")
	_check(wmap != null, "WorldMap.tscn yüklendi")
	_check(int(tm.call("get_current_step")) == 9, "Adım 9 (WORLD_MAP_TOUR) geçildi")
	_press_button(btn_next)
	await _tick(2)
	_check(int(tm.call("get_current_step")) == 10, "Adım 10 (RETURN_FROM_MAP) geçildi")

	village = await _swap_scene("res://scenes/Village.tscn")
	_check(int(tm.call("get_current_step")) == 11, "Adım 11 (OPEN_ALLIANCE) geçildi")

	# 6. İttifak ekranı turu (Adım 11 -> 12 -> 13 -> 14)
	var alliance := await _swap_scene("res://scenes/Alliance.tscn")
	_check(alliance != null, "Alliance.tscn yüklendi")
	_check(int(tm.call("get_current_step")) == 12, "Adım 12 (ALLIANCE_TOUR) geçildi")
	_press_button(btn_next)
	await _tick(2)
	_check(int(tm.call("get_current_step")) == 13, "Adım 13 (RETURN_FROM_ALLIANCE) geçildi")

	village = await _swap_scene("res://scenes/Village.tscn")
	bp = village.get("building_panel") as Control
	upg_btn = bp.get_node_or_null("VBox/UpgradeButton") as BaseButton
	close_btn = bp.get_node_or_null("VBox/Header/CloseButton") as BaseButton
	_check(int(tm.call("get_current_step")) == 14, "Adım 14 (BUILD_BARRACKS_LV1) geçildi")

	# 7. Kışla Sv.1 inşa et (Adım 14 -> 15)
	await _click_building(village, "barracks")
	_press_button(upg_btn)
	await _tick(2)
	_press_button(btn_speedup)
	await _tick(3)
	active_v = gs.call("get_active_village")
	_check(int(active_v["buildings"].get("barracks", 0)) >= 1, "Kışla Sv.1 inşa edildi")
	_check(int(tm.call("get_current_step")) == 15, "Adım 15 (RESEARCH_SPEAR) geçildi")

	# 8. Araştırma sekmesi -> Silahtar araştır (Adım 15 -> 16)
	var tab_res := bp.get_node_or_null("VBox/TabBar/TabResearchBtn") as BaseButton
	_press_button(tab_res)
	await _tick(2)
	var res_btn := bp.find_child("ResearchBtn_spear", true, false) as BaseButton
	_check(res_btn != null, "ResearchBtn_spear butonu bulundu")
	_press_button(res_btn)
	await _tick(2)
	_check(btn_speedup.visible, "Silahtar araştırmasında Kraliyet Fermanı göründü")
	_press_button(btn_speedup)
	await _tick(3)
	active_v = gs.call("get_active_village")
	_check(RE.is_researched(active_v, "spear"), "Silahtar araştırması tamamlandı")
	_check(int(tm.call("get_current_step")) == 16, "Adım 16 (TRAIN_10_SPEAR) geçildi")

	# 9. Eğit sekmesi -> +10 ve Eğit -> 10 Silahtar tamamla (Adım 16 -> 17)
	var tab_train := bp.get_node_or_null("VBox/TabBar/TabTrainBtn") as BaseButton
	_press_button(tab_train)
	await _tick(2)
	var plus10 := bp.find_child("BtnPlus10_spear", true, false) as BaseButton
	var train_btn := bp.find_child("TrainBtn_spear", true, false) as BaseButton
	_check(plus10 != null and train_btn != null, "BtnPlus10_spear ve TrainBtn_spear butonları bulundu")
	var wood_before := int(active_v.get("resources", {}).get("wood", 0))
	_press_button(plus10)
	await _tick(2)
	var spin_spear := bp.find_child("Spin_spear", true, false) as SpinBox
	var eb := root.get_node_or_null("EventBus")
	if eb != null:
		eb.emit_signal("resources_changed", int(active_v["id"]))
		eb.emit_signal("state_changed")
	await _tick(3)
	_check(spin_spear != null and int(spin_spear.value) == 10, "Tick/sinyal sonrası Spin_spear=10 korundu (sıfırlanmadı)")
	_check(tm.call("_resolve_target_control", village, "Village.tscn", gs) == bp.find_child("TrainBtn_spear", true, false), "Sinyal sonrası el/kare hala Eğit butonunu hedefliyor (sola zıplamadı)")
	_press_button(bp.find_child("TrainBtn_spear", true, false) as BaseButton)
	await _tick(2)
	active_v = gs.call("get_active_village")
	wood_before = int(active_v.get("resources", {}).get("wood", 0))
	_press_button(btn_speedup)
	await _tick(3)

	active_v = gs.call("get_active_village")
	_check(int(active_v.get("units", {}).get("spear", 0)) >= 10, "En az 10 Silahtar eğitildi (%d)" % int(active_v.get("units", {}).get("spear", 0)))
	_check(int(tm.call("get_current_step")) == 17, "Adım 17 (LORD_EQUIP_TOUR) geçildi")

	# 10. Parmak güdümlü interaktif Lord ekranı + 3 +0 eşya hediyesi + ekipman kuşanma + elmasla parşömen + önizleme/iptal + +1 geliştirme + geri kuşanma + haydut anlatımı (Adım 17 -> 18 -> 19 -> 20)
	var lm := root.get_node_or_null("LordManager")
	_check(lm != null, "LordManager autoload yüklü")
	var ld_pre: Dictionary = lm.call("get_lord_state")
	_check((ld_pre.get("inventory", []) as Array).is_empty(), "LordModal açılmadan önce starter eşya henüz verilmedi")
	var btn_lord := village.find_child("BtnLord", true, false) as BaseButton
	_check(btn_lord != null and tm.call("_resolve_target_control", village, "Village.tscn", gs) == btn_lord, "Adım 17 parmak hedefi BtnLord butonunu gösteriyor")
	_press_button(btn_lord)
	await _tick(3)

	var lmod := village.find_child("LordModal", true, false) as CanvasLayer
	_check(lmod != null and lmod.visible, "BtnLord basılınca LordModal açıldı")
	_check(lmod.find_child("StarterGiftEffect", true, false) != null, "LordModal açılınca hediye efekt katmanı (StarterGiftEffect) oluştu")
	var btn_gift_ok := lmod.find_child("BtnGiftConfirm", true, false) as BaseButton
	_check(btn_gift_ok != null and tm.call("_resolve_target_control", village, "Village.tscn", gs) == btn_gift_ok, "İlk başta hediye 3 item popup'ında Tamam butonu hedefleniyor")
	_press_button(btn_gift_ok)
	await _tick(3)
	_check(not bool(lmod.call("is_starter_gift_open")), "Tamam'a basılınca hediye popup'ı kapandı")

	var ld_tut: Dictionary = lm.call("get_lord_state")
	var tut_inv: Array = ld_tut.get("inventory", [])
	_check(tut_inv.size() == 3 and int(ld_tut.get("upgrade_scrolls", 0)) == 0, "Lord envanterine tam 3 eşya ve 0 ücretsiz parşömen verildi")
	var sword_id := ""
	var boots_id := ""
	var earring_id := ""
	var all_plus_zero := true
	for it in tut_inv:
		if typeof(it) == TYPE_DICTIONARY:
			var d := it as Dictionary
			if int(d.get("plus", -1)) != 0:
				all_plus_zero = false
			match str(d.get("slot_type", "")):
				"sword": sword_id = str(d.get("id", ""))
				"boots": boots_id = str(d.get("id", ""))
				"earring": earring_id = str(d.get("id", ""))
	_check(all_plus_zero and not sword_id.is_empty() and not boots_id.is_empty() and not earring_id.is_empty(), "Gelen 3 eşya tam olarak Kılıç, Çizme, Küpe ve hepsi +0")

	for item_pair in [["sword", sword_id], ["boots", boots_id], ["earring", earring_id]]:
		var item_iid: String = str(item_pair[1])
		var inv_btn := lmod.find_child("LordInvItem_%s" % item_iid, true, false) as BaseButton
		_check(inv_btn != null and tm.call("_resolve_target_control", village, "Village.tscn", gs) == inv_btn, "Parmak hedefi envanterdeki %s (%s) kartını gösteriyor" % [str(item_pair[0]), item_iid])
		_press_button(inv_btn)
		await _tick(2)
		var btn_det_eq := lmod.find_child("BtnDetailEquip", true, false) as BaseButton
		_check(btn_det_eq != null and tm.call("_resolve_target_control", village, "Village.tscn", gs) == btn_det_eq, "Detay ekranında parmak 'Kuşan' butonunu gösteriyor (%s)" % str(item_pair[0]))
		_press_button(btn_det_eq)
		await _tick(3)

	_check(int(tm.call("get_current_step")) == 18, "Kılıç, Çizme ve Küpe kuşanılınca Adım 18 (LORD_UPGRADE_SWORD) geçildi")

	# Kılıcı Lord'un elinden çıkar -> Geliştirme ekranını aç
	var slot_sw := lmod.find_child("Slot_sword", true, false) as BaseButton
	_check(slot_sw != null and tm.call("_resolve_target_control", village, "Village.tscn", gs) == slot_sw, "Parmak hedefi takılı Kılıç slotunu (Slot_sword) gösteriyor")
	_press_button(slot_sw)
	await _tick(2)
	var btn_slot_un := lmod.find_child("BtnSlotUnequip", true, false) as BaseButton
	_check(btn_slot_un != null and tm.call("_resolve_target_control", village, "Village.tscn", gs) == btn_slot_un, "Parmak hedefi 'Eşyayı Çıkar' butonunu gösteriyor")
	_press_button(btn_slot_un)
	await _tick(3)

	var btn_open_upg := lmod.find_child("BtnOpenLordUpgrade", true, false) as BaseButton
	_check(btn_open_upg != null and tm.call("_resolve_target_control", village, "Village.tscn", gs) == btn_open_upg, "Parmak hedefi 'Ekipman Geliştir' butonunu gösteriyor")
	_press_button(btn_open_upg)
	await _tick(3)

	var umod := lmod.get("_upgrade_modal") as CanvasLayer
	_check(umod != null and umod.visible and str(umod.get("_selected_item_id")) == "", "Geliştirme ekranı boş Hedef Slot ile açıldı")

	# Kılıca tıkla -> Hedef Slota koy
	var sw_card := umod.find_child("InvItemCard_%s" % sword_id, true, false) as Control
	_check(sw_card != null and tm.call("_resolve_target_control", village, "Village.tscn", gs) == sw_card, "Parmak geliştirme envanterindeki +0 Kılıcı gösteriyor")
	sw_card.emit_signal("item_pressed", sword_id)
	await _tick(3)
	_check(str(umod.get("_selected_item_id")) == sword_id, "Tıklanan kılıç Hedef Eşya yuvasına yerleşti")

	# 5 Elmas ile Parşömen al -> Onayla -> Parşömen envantere gelsin (otomatik örse yerleşmesin)
	var dia_before := int(gs.get("player").get("diamonds", 0))
	var btn_buy_dia := umod.find_child("BtnBuyScrollDiamonds", true, false) as BaseButton
	_check(btn_buy_dia != null and tm.call("_resolve_target_control", village, "Village.tscn", gs) == btn_buy_dia, "Parmak '5 Elmas ile Satın Al' butonunu gösteriyor")
	_press_button(btn_buy_dia)
	await _tick(2)
	var btn_yes_dia := umod.find_child("BtnConfirmDialogYes", true, false) as BaseButton
	_check(btn_yes_dia != null and tm.call("_resolve_target_control", village, "Village.tscn", gs) == btn_yes_dia, "Parmak onay penceresinde 'Evet (5 Elmas)' butonunu gösteriyor")
	_press_button(btn_yes_dia)
	await _tick(3)
	_check(int(gs.get("player").get("diamonds", 0)) == dia_before - 5 and int(lm.call("get_scroll_count")) == 1, "5 Elmas düşüldü ve 1 Parşömen envantere alındı")
	_check(int(umod.get("_placed_scroll_slot")) == -1, "Elmas ile alınan parşömen örs yuvasına otomatik yerleşmedi, envanterde bekliyor")

	# Envanterden parşömene tıkla -> örs yuvasına koy
	var sc_inv_card := umod.find_child("InvUpgradeScrollCard", true, false) as Control
	_check(sc_inv_card != null and tm.call("_resolve_target_control", village, "Village.tscn", gs) == sc_inv_card, "Parmak envanterdeki Geliştirme Parşömenini gösteriyor")
	sc_inv_card.emit_signal("tile_pressed")
	await _tick(3)
	_check(int(umod.get("_placed_scroll_slot")) >= 0, "Parşömene tıklayınca 3x3 örs yuvasına yerleşti")

	# Önizle -> Açıklama -> İptal -> Geliştir
	var btn_pv := umod.find_child("BtnPreviewUpgrade", true, false) as BaseButton
	_check(btn_pv != null and tm.call("_resolve_target_control", village, "Village.tscn", gs) == btn_pv, "Parmak 'Önizle' butonunu gösteriyor")
	_press_button(btn_pv)
	await _tick(3)
	_check(bool(umod.get("_preview_active")), "Önizleme kutusu açıldı")
	var btn_cancel_pv := umod.find_child("BtnCancelPreview", true, false) as BaseButton
	_check(btn_cancel_pv != null and tm.call("_resolve_target_control", village, "Village.tscn", gs) == btn_cancel_pv, "Önizleme açıkken parmak 'İptal' butonunu gösteriyor")
	_press_button(btn_cancel_pv)
	await _tick(3)
	_check(not bool(umod.get("_preview_active")), "İptal butonuna basılınca önizleme kapandı")

	var btn_do_upg := umod.find_child("BtnDoUpgrade", true, false) as BaseButton
	_check(btn_do_upg != null and tm.call("_resolve_target_control", village, "Village.tscn", gs) == btn_do_upg, "Önizleme sonrası parmak 'GELİŞTİR' butonunu gösteriyor")
	_press_button(btn_do_upg)
	await _tick(3)
	_check(int((lm.call("get_item_by_id", sword_id) as Dictionary).get("plus", 0)) == 1 and int(lm.call("get_scroll_count")) == 0, "Tutorial kılıcı +0 → +1 seviyesine yükseltildi ve parşömen tüketildi")

	# Geliştirme ekranını kapat -> Lord ekranında +1 kılıcı tekrar kuşan
	var btn_close_upg := umod.find_child("BtnCloseUpgrade", true, false) as BaseButton
	_check(btn_close_upg != null and tm.call("_resolve_target_control", village, "Village.tscn", gs) == btn_close_upg, "+1 sonrası parmak Örs Kapat (✕) butonunu gösteriyor")
	_press_button(btn_close_upg)
	await _tick(3)

	var sw_inv_plus1 := lmod.find_child("LordInvItem_%s" % sword_id, true, false) as BaseButton
	_check(sw_inv_plus1 != null and tm.call("_resolve_target_control", village, "Village.tscn", gs) == sw_inv_plus1, "Lord ekranında parmak +1 Kılıcı gösteriyor")
	_press_button(sw_inv_plus1)
	await _tick(2)
	var btn_det_eq2 := lmod.find_child("BtnDetailEquip", true, false) as BaseButton
	_check(btn_det_eq2 != null and tm.call("_resolve_target_control", village, "Village.tscn", gs) == btn_det_eq2, "+1 Kılıç detayında parmak 'Kuşan' butonunu gösteriyor")
	_press_button(btn_det_eq2)
	await _tick(3)

	_check(int(tm.call("get_current_step")) == 19, "+1 Kılıç tekrar kuşanılınca Adım 19 (LORD_CLOSE_AND_OPEN_MAP) geçildi")
	var btn_close_lord := lmod.find_child("BtnCloseLordModal", true, false) as BaseButton
	_check(btn_close_lord != null and tm.call("_resolve_target_control", village, "Village.tscn", gs) == btn_close_lord, "Adım 19 önce Lord ekranını kapatmayı hedefliyor")
	_press_button(btn_close_lord)
	await _tick(3)
	var btn_map_tut := village.find_child("BtnMap", true, false) as BaseButton
	_check(btn_map_tut != null and tm.call("_resolve_target_control", village, "Village.tscn", gs) == btn_map_tut, "Lord kapanınca parmak alt menüdeki Harita butonunu gösteriyor")

	var map_tut := await _swap_scene("res://scenes/WorldMap.tscn")
	await _tick(3)
	_check(int(tm.call("get_current_step")) == 20, "Haritaya geçince Adım 20 (LORD_BANDIT_MAP_TOUR) geçildi")
	var dial_lbl := tm.get("_dialogue_label") as RichTextLabel
	_check(dial_lbl != null and "Haydut" in dial_lbl.text and "seviye" in dial_lbl.text, "Adım 20 Haydut Köylerinden yüksek seviyeye göre ekipman düşme anlatımını içeriyor")
	var bandit_rect: Rect2 = map_tut.call("get_tutorial_bandit_screen_rect")
	_check(bandit_rect.size.x >= 50.0, "Harita üzerinde haydut köyü odak karesi hesaplandı")
	var btn_next_bandit := tm.get("_btn_next") as BaseButton
	_check(btn_next_bandit != null and tm.call("_resolve_target_control", map_tut, "WorldMap.tscn", gs) == btn_next_bandit, "Adım 20 devam butonu hedefleniyor")
	_press_button(btn_next_bandit)
	await _tick(3)
	_check(int(tm.call("get_current_step")) == 21, "Adım 21 (RETURN_FROM_BANDIT_MAP) geçildi")

	village = await _swap_scene("res://scenes/Village.tscn")
	await _tick(3)
	_check(int(tm.call("get_current_step")) == 22, "Köy'e dönünce Adım 22 (QUEST_BAR_TOUR) geçildi")
	var qm := root.get_node_or_null("QuestManager")
	_check(qm != null and bool(qm.call("is_quest_hud_visible")), "Görevler barı Adım 22'de görünür oldu")
	var q_hdr_btn := qm.call("get_header_button") as BaseButton
	_check(q_hdr_btn != null and tm.call("_resolve_target_control", village, "Village.tscn", gs) == q_hdr_btn, "Sol üst GÖREVLER barı parmakla hedefleniyor")
	_press_button(q_hdr_btn)
	await _tick(3)
	_check(bool(qm.call("is_expanded")), "GÖREVLER barı tıklanınca açıldı")
	var btn_finish_q := tm.get("_btn_next") as BaseButton
	_check(btn_finish_q != null and btn_finish_q.visible, "Görevler barı açılınca Eğitimi Tamamla butonu göründü")
	_press_button(btn_finish_q)
	await _tick(3)
	_check(int(tm.call("get_current_step")) == 23, "Adım 23 (GRADUATION_MODAL) geçildi")

	var vmodal := tm.get("_victory_modal") as Control
	_check(vmodal != null and vmodal.visible, "Mezuniyet ödül penceresi göründü")
	_check(bool(gs.get("player").get("tutorial_reward_claimed", false)), "Mezuniyet ödülü işaretlendi")
	var wood_after := int(active_v.get("resources", {}).get("wood", 0))
	_check(wood_after >= wood_before + 800, "Mezuniyet +1000 kaynak ödülü eklendi (öncesi=%d, sonrası=%d)" % [wood_before, wood_after])

	# 10. Bitir & Ayarlar'dan tekrar başlatmayı doğrula
	var btn_finish := tm.get("_btn_finish") as Button
	_press_button(btn_finish)
	await _tick(2)
	_check(bool(gs.get("player").get("tutorial_completed", false)), "tutorial_completed=true kaydedildi")
	_check(not tm.call("is_tutorial_active"), "Rehber tamamlandıktan sonra pasifleşti")

	var settings := await _swap_scene("res://scenes/Settings.tscn")
	_check(settings != null, "Settings.tscn yüklendi")
	var btn_replay := settings.find_child("BtnTutorialReplay", true, false) as Button
	_check(btn_replay == null, "Ayarlar ekranından BtnTutorialReplay kaldırıldı (Build 22+)")
	tm.call("restart_tutorial")
	_check(int(tm.call("get_current_step")) == 0 and not bool(gs.get("player").get("tutorial_completed", true)), "restart_tutorial() rehberi 0. adıma sıfırladı")

	if _active_scene != null and is_instance_valid(_active_scene):
		root.remove_child(_active_scene)
		_active_scene.queue_free()
		_active_scene = null
