extends SceneTree
## test_store_and_speedups.gd — Elmas Ekonomisi, Parşömen Hızlandırmaları, Kışla Scroll ve UI Okunaklılık Testleri.

const VM := preload("res://scripts/model/VillageModel.gd")
const RE := preload("res://scripts/rules/RulesEngine.gd")
const MovementScript := preload("res://scripts/sim/actions/Movement.gd")

var _passed: int = 0
var _failed: int = 0
var _fail_labels: Array[String] = []


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("PASS: ", label)
	else:
		_failed += 1
		_fail_labels.append(label)
		printerr("FAIL: ", label)


func _tick(frames: int = 2) -> void:
	for _i in range(frames):
		await process_frame


func _initialize() -> void:
	await _run_tests()
	print("")
	print("==================== STORE & SPEEDUPS ÖZET ====================")
	print("PASS: %d   FAIL: %d" % [_passed, _failed])
	if _failed > 0:
		for lbl in _fail_labels:
			print("  - ", lbl)
	print("===============================================================")
	quit(1 if _failed > 0 else 0)


func _run_tests() -> void:
	var gd := root.get_node_or_null("GameData")
	var gs := root.get_node_or_null("GameState")
	var store := root.get_node_or_null("StoreManager")
	var tm := root.get_node_or_null("TutorialManager")
	var qm := root.get_node_or_null("QuestManager")
	var gc := root.get_node_or_null("GameConfig")

	_check(gd != null and gs != null and store != null, "GameData, GameState ve StoreManager autoloadları yüklü")
	if gd == null or gs == null or store == null:
		return

	gd.call("load_all", true)
	if tm != null:
		tm.set("tutorial_enabled_in_headless", false)
	if qm != null:
		qm.set("quest_enabled_in_headless", false)
	if gc != null:
		gc.set("speed", 1.0)
		gc.set("unit_speed", 1.0)

	# 1. Başlangıç 35 Elmas & 4 kategori parşömen satın alma
	gs.call("reset")
	_check(int(store.call("get_diamonds")) == 35, "GameState.reset() sonrası başlangıç elması 35")

	var v1 := VM.create(101, "Başkent", 100, 100, "Lord Elmas", false)
	v1["buildings"] = {
		"main": 5, "wood": 3, "stone": 3, "iron": 3, "farm": 10, "storage": 10,
		"barracks": 5, "market": 2, "wall": 1, "hide": 1
	}
	v1["resources"] = {"wood": 50000, "stone": 50000, "iron": 50000}
	v1["researched"] = {"spear": true}
	v1["units"] = {"spear": 20}
	var v2 := VM.create(102, "Hedef Köy", 120, 100, "Düşman Lord", false)
	v2["protection_until"] = 0
	v2["units"] = {"spear": 0}
	v2["resources"] = {"wood": 100, "stone": 100, "iron": 100}

	gs.set("villages", [v1, v2])
	gs.set("active_village_id", 101)
	gs.set("queues", [])
	gs.set("movements", [])
	gs.set("reports", [])
	gs.player["name"] = "Lord Elmas"
	gs.player["tutorial_completed"] = true

	var r_over: Dictionary = store.call("buy_scroll", "march_60m", 2)  # 60 elmas > 35
	_check(not bool(r_over.get("ok", true)), "Yetersiz elmasta parşömen satın alma reddedildi (60 > 35)")

	var r_b30: Dictionary = store.call("buy_scroll", "build_30m", 1)  # 12 -> 23 kalır
	var r_r10: Dictionary = store.call("buy_scroll", "research_10m", 1)  # 6 -> 17 kalır
	var r_t10: Dictionary = store.call("buy_scroll", "train_10m", 1)  # 5 -> 12 kalır
	_check(bool(r_b30.get("ok", false)) and bool(r_r10.get("ok", false)) and bool(r_t10.get("ok", false)), "İnşaat/Araştırma/Eğitim parşömenleri elmasla satın alındı")
	_check(int(store.call("get_diamonds")) == 12, "Toplam 23 elmas harcanınca 12 elmas kaldı")

	# Test amaçlı 2 adet march_10m al (2*8 = 16 -> önce elmas ekle)
	gs.player["diamonds"] = 20
	var r_m10: Dictionary = store.call("buy_scroll", "march_10m", 2)
	_check(bool(r_m10.get("ok", false)) and int(store.call("get_scroll_count", "march_10m")) == 2, "2 adet Sefer Hızlandırma 10 Dk parşömeni satın alındı")

	# 2. İnşaat kuyruğunda kademeli taşma (cascading) testi: 10 dk + 10 dk iki inşaat -> tek 30 dk parşömeniyle ikisi de tamamlanmalı!
	var now := int(Time.get_unix_time_from_system())
	gs.queues = [
		{"id": 1, "village_id": 101, "type": "build", "key": "wood", "target_level": 4, "start_unix": now, "finish_unix": now + 600},
		{"id": 2, "village_id": 101, "type": "build", "key": "stone", "target_level": 4, "start_unix": now + 600, "finish_unix": now + 1200},
		{"id": 3, "village_id": 101, "type": "research", "key": "sword", "start_unix": now, "finish_unix": now + 500},
		{"id": 4, "village_id": 101, "type": "train", "key": "spear", "count": 5, "total_count": 5, "done_count": 0, "per_unit_seconds": 40.0, "start_unix": now, "finish_unix": now + 200},
	]
	var res_b: Dictionary = store.call("apply_scroll_to_queue", "build_30m", "build", 1)
	_check(bool(res_b.get("ok", false)) and bool(res_b.get("completed", false)), "30 Dk İnşaat parşömeni aktif inşaatları hızlandırdı")
	var av1: Dictionary = gs.call("get_active_village")
	_check(int(av1["buildings"].get("wood", 0)) >= 4 and int(av1["buildings"].get("stone", 0)) >= 4, "30 Dk parşömeni ardışık 2 inşaatı da kademeli tamamladı (wood=4, stone=4)")

	var res_r: Dictionary = store.call("apply_scroll_to_queue", "research_10m", "research", 3)
	_check(bool(res_r.get("ok", false)) and RE.is_researched(gs.call("get_active_village"), "sword"), "10 Dk Araştırma parşömeni Muhafız araştırmasını tamamladı")

	var res_t: Dictionary = store.call("apply_scroll_to_queue", "train_10m", "train", 4)
	_check(bool(res_t.get("ok", false)) and int(gs.call("get_active_village")["units"].get("spear", 0)) >= 25, "10 Dk Eğitim parşömeni 5 Silahtar eğitimini tamamladı (20 -> 25)")

	# 3. Sefer hızlandırma & dönüş süresi bütünlüğü (base_travel_seconds korunmalı!)
	var depart_u := now
	var base_travel := 1200  # 20 dakika
	gs.movements = [{
		"id": 9001,
		"village_id": 101,
		"from_village_id": 101,
		"to_village_id": 102,
		"from_x": 100, "from_y": 100,
		"to_x": 120, "to_y": 100,
		"type": "attack",
		"state": "outgoing",
		"owner": "Lord Elmas",
		"depart_unix": depart_u,
		"arrive_unix": depart_u + base_travel,
		"return_unix": depart_u + base_travel * 2,
		"units": {"spear": 10},
		"carry": {},
	}]
	var m_res1: Dictionary = store.call("apply_scroll_to_queue", "march_10m", "march", 9001)
	_check(bool(m_res1.get("ok", false)) and not bool(m_res1.get("completed", true)), "İlk 10 Dk Sefer parşömeni kalan süreyi 20 dk -> 10 dk'ya indirdi")
	_check(int(gs.movements[0].get("base_travel_seconds", 0)) == base_travel, "base_travel_seconds=1200 korundu")

	var m_res2: Dictionary = store.call("apply_scroll_to_queue", "march_10m", "march", 9001)
	_check(bool(m_res2.get("ok", false)) and bool(m_res2.get("completed", false)), "İkinci 10 Dk Sefer parşömeni orduyu hemen hedefe ulaştırdı")
	_check(gs.movements.size() == 1 and str(gs.movements[0].get("type", "")) == "return", "Hedefe varışta dönüş seferi (return) oluştu")
	if not gs.movements.is_empty():
		var ret_mv: Dictionary = gs.movements[0]
		var ret_dur := int(ret_mv.get("arrive_unix", 0)) - int(ret_mv.get("depart_unix", 0))
		_check(ret_dur == base_travel, "Gidiş hızlandırılmış olsa da dönüş süresi orijinal base_travel_seconds (%d sn) korundu (gelen: %d)" % [base_travel, ret_dur])

	# 4. Kaynak paketi (Elmas ile kaynak alma) + TRY fiyat etiketi + dönüş hareketi çoğalmama
	gs.player["diamonds"] = 100
	var av_pre: Dictionary = gs.call("get_active_village")
	av_pre["resources"] = {"wood": 100, "stone": 100, "iron": 100}
	var rp_res: Dictionary = store.call("buy_resource_pack", "res_wood_1000")
	_check(bool(rp_res.get("ok", false)) and int(gs.call("get_active_village")["resources"]["wood"]) == 1100, "1.000 Odun Sandığı elmasla alındı (wood 100 -> 1100)")
	_check(int(store.call("get_diamonds")) == 95, "Kaynak paketi 5 elmas düştü (100 -> 95)")
	var rp_fill_low: Dictionary = store.call("buy_resource_pack", "res_fill_storage")
	_check(not bool(rp_fill_low.get("ok", true)), "95 elmas ile Ambarları Doldur (100 Elmas) reddedildi")
	gs.player["diamonds"] = 100
	var rp_fill: Dictionary = store.call("buy_resource_pack", "res_fill_storage")
	var fill_cap := int(RE.storage_capacity(int(gs.call("get_active_village")["buildings"].get("storage", 1))))
	_check(bool(rp_fill.get("ok", false)) and int(gs.call("get_active_village")["resources"]["stone"]) == fill_cap, "Ambarları Doldur 100 elmasla depo kapasitesine (%d) tamamladı" % fill_cap)
	_check(int(store.call("get_diamonds")) == 0, "Ambarları Doldur sonrası 100 elmas düştü (100 -> 0)")
	gs.player["diamonds"] = 100
	var rp_full: Dictionary = store.call("buy_resource_pack", "res_fill_storage")
	_check(not bool(rp_full.get("ok", true)), "Depo tamamen doluyken kaynak paketi reddedildi")
	var pk_try := str(store.call("get_pack_price_label", store.call("get_pack_def", "diamonds_10")))
	_check(pk_try.contains("₺"), "Varsayılan para birimi TL (%s)" % pk_try)
	var ret_cnt := 0
	var out_cnt := 0
	for mm in gs.movements:
		if str(mm.get("type", "")) == "return":
			ret_cnt += 1
		else:
			out_cnt += 1
	_check(ret_cnt <= 1 and out_cnt == 0, "Hızlandırma sonrası yalnızca 1 dönüş hareketi var (giden yok)")

	# 5. Village.tscn + BuildingView + BuildingPanel + ResourceBar + MarketModal UI doğrulamaları
	var vil_scene := load("res://scenes/Village.tscn") as PackedScene
	var vil := vil_scene.instantiate() as Control
	root.add_child(vil)
	await _tick(3)

	var rbar := vil.get_node_or_null("ResourceBar")
	_check(rbar != null and rbar.has_method("get_bar_height") and float(rbar.call("get_bar_height")) >= 90.0, "ResourceBar yeni tasarımla yüklü ve get_bar_height() geçerli")
	_check(rbar.find_child("BtnMarket", true, false) != null, "ResourceBar sağ kanadında Elmas Pazarı butonu (BtnMarket) mevcut")
	var cit_lbl := rbar.find_child("CitizensLabel", true, false) as Label
	_check(cit_lbl != null and cit_lbl.text.contains("Boş") and not cit_lbl.text.contains("/"), "Vatandaş etiketi sade 'Boş' formatında (%s)" % (cit_lbl.text if cit_lbl else ""))

	# BuildingView sayaç hapı ve progressbar yüksekliği
	var bv = vil.call("get_building_view", "wood")
	_check(bv != null, "Oduncu BuildingView mevcut")
	if bv != null:
		bv.call("set_state", 3, false, true, 45.0, 125)
		await _tick(1)
		var pb := bv.get("_progress_bar") as ProgressBar
		var pill = bv.get("_countdown_pill")
		_check(pb != null and not pb.show_percentage and pb.size.y <= 14.0, "İnşaat ProgressBar ince ve yüzde gizli (h=%.1f)" % (pb.size.y if pb else -1.0))
		_check(pill != null and pill.visible, "İnşaat kalan süre dark/gold yüksek kontrastlı pill içinde gösteriliyor")

	# BuildingPanel Kışla Araştır & Eğit kaydırma filtresi + Hızlandır butonları
	var bp := vil.get("building_panel") as Control
	_check(bp != null, "BuildingPanel mevcut")
	if bp != null:
		bp.call("show_building", gs.call("get_active_village"), "barracks")
		await _tick(2)
		var res_scroll := bp.find_child("ResearchScroll", true, false) as ScrollContainer
		var tr_scroll := bp.find_child("TrainScroll", true, false) as ScrollContainer
		_check(res_scroll != null and res_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED and res_scroll.scroll_deadzone >= 10, "ResearchScroll yatay kilidi kapalı ve deadzone >= 10")
		_check(tr_scroll != null and tr_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED and tr_scroll.scroll_deadzone >= 10, "TrainScroll yatay kilidi kapalı ve deadzone >= 10")

		bp.call("_switch_tab", 1)
		await _tick(2)
		var res_list := bp.find_child("ResearchList", true, false)
		var res_cards_ok := res_list != null and res_list.get_child_count() > 0
		if res_cards_ok:
			for c in res_list.get_children():
				if c is PanelContainer and (c as Control).mouse_filter != Control.MOUSE_FILTER_PASS:
					res_cards_ok = false
					break
		_check(res_cards_ok, "Birim Araştır sekmesindeki tüm kartlar MOUSE_FILTER_PASS (kaydırma açık)")

		bp.call("_switch_tab", 2)
		await _tick(2)
		var tr_list := bp.find_child("TrainList", true, false)
		var tr_cards_ok := tr_list != null and tr_list.get_child_count() > 0
		if tr_cards_ok:
			for c in tr_list.get_children():
				if c is PanelContainer and (c as Control).mouse_filter != Control.MOUSE_FILTER_PASS:
					tr_cards_ok = false
					break
		_check(tr_cards_ok, "Birim Eğit sekmesindeki tüm kartlar MOUSE_FILTER_PASS (kaydırma açık)")

	# RoyalMarketModal aç & kapat kontrolü
	var mkt := store.call("open_market", vil, "diamonds") as Node
	await _tick(2)
	_check(mkt != null and root.get_node_or_null("RoyalMarketModal") != null, "StoreManager.open_market() RoyalMarketModal açıyor")
	if mkt != null:
		_check(mkt.find_child("BuyPackBtn_diamonds_1000", true, false) != null, "1000 Elmas paketi butonu pazarda listelendi")
		var cls_btn := mkt.find_child("MarketCloseBtn", true, false) as BaseButton
		_check(cls_btn != null, "Pazar kapatma butonu (MarketCloseBtn) mevcut")
		if cls_btn != null:
			cls_btn.emit_signal("pressed")
		else:
			mkt.queue_free()
		await _tick(2)

	vil.queue_free()
	await _tick(2)
