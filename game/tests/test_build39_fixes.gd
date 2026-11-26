extends SceneTree
## test_build39_fixes.gd — Build 39 Düzeltmeleri E2E doğrulama testleri:
## 1) Parşömenlerin LordModal & LordUpgradeModal envanterinde görünmesi + sürükle/bırak ve çıkış-giriş
## 2) Ortadaki Lord görselinde takılı eşya katmanı (overlay) olmaması
## 3) Geliştirme ekranında "Hammadde İle Satın Al" ve "5 Elmas ile Satın Al" (+ elmas onay/yetersiz elmas pazar akışı)
## 4) Haydut raporu ganimet kartında hammaddelerin altında ortalanmış item gösterimi
## 5) Sefer/casusluk yoldayken aynı köyden sınırsız eşzamanlı saldırı, casusluk, destek ve hammadde gönderimi

const LordModelScript := preload("res://scripts/model/LordModel.gd")
const MovementScript := preload("res://scripts/sim/actions/Movement.gd")
const VM := preload("res://scripts/model/VillageModel.gd")
const LordModalScript := preload("res://ui/LordModal.gd")
const LordUpgradeModalScript := preload("res://ui/LordUpgradeModal.gd")
const MarketModalScript := preload("res://ui/MarketModal.gd")
const ReportsScript := preload("res://scenes/Reports.gd")

var _passed: int = 0
var _failed: int = 0
var _fail_labels: Array[String] = []


func _initialize() -> void:
	await _run_all()
	print("")
	print("==================== BUILD 39 FIX TEST ÖZETİ ====================")
	print("PASS: %d   FAIL: %d" % [_passed, _failed])
	if _failed > 0:
		for l in _fail_labels:
			print("  - ", l)
	print("=================================================================")
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
	_check(gs != null and lm != null and sm != null and gd != null, "Gerekli autoloadlar yüklü")
	if gs == null or lm == null or sm == null:
		return

	if gd.has_method("load_all"):
		gd.call("load_all", true)
	gs.call("reset")

	var home_v := VM.create(100, "Başkent", 100, 100, "Hero39", false)
	home_v["resources"] = {"wood": 30000, "stone": 30000, "iron": 30000}
	home_v["buildings"] = {"main": 10, "barracks": 5, "wall": 5, "farm": 10, "storage": 15, "market": 5}
	home_v["units"] = {"spear": 80, "sword": 60, "axe": 120, "bow": 50, "spy": 40, "light": 40}

	var bandit_1 := VM.create(201, "Haydut Kampı I", 102, 100, "Haydutlar", true)
	bandit_1["is_bandit"] = true
	bandit_1["protection_until"] = 0
	bandit_1["protection_until_unix"] = 0

	var bandit_2 := VM.create(202, "Haydut Kampı II", 104, 101, "Haydutlar", true)
	bandit_2["is_bandit"] = true
	bandit_2["protection_until"] = 0
	bandit_2["protection_until_unix"] = 0

	var ally_v := VM.create(203, "Müttefik Kale", 101, 103, "MüttefikKral", false)
	ally_v["protection_until"] = 0
	ally_v["protection_until_unix"] = 0

	gs.set("villages", [home_v, bandit_1, bandit_2, ally_v])
	gs.set("active_village_id", 100)
	gs.set("alliances", [{
		"id": 1,
		"name": "Kuzey Birliği",
		"tag": "KZB",
		"members": [{"name": "Hero39", "role": "leader"}, {"name": "MüttefikKral", "role": "member"}],
	}])
	gs.set("player", {
		"id": 1,
		"name": "Hero39",
		"diamonds": 10,
		"scrolls": {},
		"lord": LordModelScript.default_lord_state(),
	})

	var kit_res: Dictionary = lm.call("grant_tutorial_starter_kit")
	var sword_id := str(kit_res.get("sword_id", ""))
	_check(not sword_id.is_empty(), "Başlangıç kılıcı ve parşömen verildi")
	var eq_sw: Dictionary = lm.call("equip_item", "sword", sword_id)
	_check(bool(eq_sw.get("ok", false)), "Başlangıç kılıcı Lord'a takıldı (ortadaki görsel temiz kalmalı)")

	# -------------------------------------------------------------------------
	# TEST 1 & 2: LordModal temiz orta portre + envanterde parşömen görünürlüğü
	# -------------------------------------------------------------------------
	var l_mod := LordModalScript.new()
	root.add_child(l_mod)
	l_mod.call("open_modal")
	await process_frame

	var hero_frame := l_mod.get("_hero_frame") as Control
	var has_gear_overlay := false
	if hero_frame != null:
		has_gear_overlay = hero_frame.find_child("gear_bar_panel", true, false) != null
		for child in hero_frame.find_children("*", "HBoxContainer", true, false):
			has_gear_overlay = true
	_check(not has_gear_overlay, "Ortadaki Lord portresinin üzerinde takılı eşya katmanı/barı bulunmuyor")
	_check(l_mod.get("_hero_gear_overlay_box") == null, "LordModal _hero_gear_overlay_box kaldırılmış")

	var lord_inv_scroll := l_mod.find_child("LordInvScrollCard", true, false) as Button
	_check(lord_inv_scroll != null and lord_inv_scroll.visible, "LordModal envanterinde Geliştirme Parşömeni kartı görünür")

	# -------------------------------------------------------------------------
	# TEST 1 & 3: LordUpgradeModal çıkış-giriş + sürükle/bırak + 2 satın alma butonu
	# -------------------------------------------------------------------------
	# Kullanıcı senaryosu: 0 parşömenle aç -> 1 adet satın al -> çıkıp tekrar gir -> inventory'de x1 görünür & sürüklenir
	var ld_state: Dictionary = lm.call("get_lord_state")
	ld_state["upgrade_scrolls"] = 0
	var p_map: Dictionary = gs.get("player")
	(p_map["scrolls"] as Dictionary)["lord_upgrade_scroll"] = 0

	var u_mod := LordUpgradeModalScript.new()
	root.add_child(u_mod)
	u_mod.call("open_modal")
	await process_frame

	var btn_res := u_mod.find_child("BtnBuyScrollResources", true, false) as Button
	var btn_dia := u_mod.find_child("BtnBuyScrollDiamonds", true, false) as Button
	_check(btn_res != null and "Hammadde" in btn_res.text, "Hammadde İle Satın Al butonu mevcut")
	_check(btn_dia != null and "5 Elmas" in btn_dia.text, "5 Elmas ile Satın Al butonu mevcut")

	# 1 parşömen hammadde ile al, modaldan çık ve tekrar gir
	var res_buy: Dictionary = lm.call("buy_scroll_with_resources")
	_check(bool(res_buy.get("ok", false)) and int(lm.call("get_scroll_count")) == 1, "Hammadde ile 1 parşömen satın alındı")
	u_mod.call("close_modal")
	await process_frame
	u_mod.call("open_modal")
	await process_frame

	var inv_scroll_card := u_mod.find_child("InvUpgradeScrollCard", true, false) as Control
	_check(inv_scroll_card != null and inv_scroll_card.visible, "Çıkıp tekrar girince Geliştirme Parşömeni envanter ızgarasında görünüyor (x1)")
	if inv_scroll_card != null:
		var drag_payload: Variant = inv_scroll_card.call("_get_drag_data", Vector2(10, 10))
		_check(typeof(drag_payload) == TYPE_DICTIONARY and str((drag_payload as Dictionary).get("kind", "")) == "upgrade_scroll", "Envanterdeki parşömen kartı sürükleme verisi üretiyor")
		var slots: Array = u_mod.get("_grid_slots")
		_check(slots.size() == 9, "3x3 örs slotları hazır")
		if slots.size() == 9:
			var slot4 := slots[4] as Control
			slot4.call("_drop_data", Vector2(10, 10), drag_payload)
			await process_frame
			_check(int(u_mod.get("_placed_scroll_slot")) == 4, "Sürüklenen parşömen örs yuvasına (slot 4) yerleşti")

	# 5 Elmas ile satın alma: diamonds == 10 >= 5 => Onay penceresi çıkar => Evet deyince 5 elmas düşer ve parşömen +1 olur
	var sc_before_dia := int(lm.call("get_scroll_count"))
	u_mod.call("_on_buy_scroll_diamonds_pressed")
	await process_frame
	var yes_btn := u_mod.find_child("BtnConfirmDialogYes", true, false) as Button
	_check(yes_btn != null, "Elmas yeterliyken '5 Elmas kullanılacaktır' onay penceresi açıldı")
	if yes_btn != null:
		yes_btn.pressed.emit()
		await process_frame
	_check(int(sm.call("get_diamonds")) == 5, "Evet onayından sonra 5 elmas düşüldü (10 -> 5)")
	_check(int(lm.call("get_scroll_count")) == sc_before_dia + 1, "Elmas onayından sonra parşömen sayısı +1 arttı")

	# Elmas yetersiz (< 5): Pazarda 'diamonds' sekmesini açma sinyali tetiklenmeli
	var p_dict: Dictionary = gs.get("player")
	p_dict["diamonds"] = 3
	var market_dia_flag: Dictionary = {"fired": false}
	u_mod.open_market_diamonds_requested.connect(func(): market_dia_flag["fired"] = true)
	u_mod.call("_on_buy_scroll_diamonds_pressed")
	await process_frame
	_check(bool(market_dia_flag["fired"]), "Elmas < 5 iken Elmas Satın Alma Pazar ekranı sinyali tetiklendi")

	var mk := MarketModalScript.new()
	root.add_child(mk)
	mk.call("open_tab", "diamonds")
	await process_frame
	_check(str(mk.get("_current_tab")) == "diamonds", "MarketModal 'diamonds' (Elmas Al) sekmesinde doğrudan açılıyor")

	u_mod.queue_free()
	l_mod.queue_free()
	mk.queue_free()

	# -------------------------------------------------------------------------
	# TEST 4: Haydut Saldırı Raporunda Ganimet Kartının Altında Ortalanmış Eşya
	# -------------------------------------------------------------------------
	var rep := ReportsScript.new()
	var dropped := LordModelScript.create_item("chest", "common", 0, 999)
	var loot_card := rep.call("_make_loot_card", {"wood": 250, "stone": 180, "iron": 90}, 1200, dropped) as PanelContainer
	_check(loot_card != null, "Reports._make_loot_card oluşturuldu")
	if loot_card != null:
		var loot_item_card := loot_card.find_child("LootDroppedItemCard", true, false)
		var loot_item_icon := loot_card.find_child("LootDroppedItemIcon", true, false) as TextureRect
		var loot_item_name := loot_card.find_child("LootDroppedItemName", true, false) as Label
		_check(loot_item_card != null, "Düşen ekipman ganimet kartının içinde gösteriliyor")
		_check(loot_item_icon != null and loot_item_icon.texture != null, "Ganimet kartındaki düşen ekipman ikonu yüklü")
		_check(loot_item_name != null and str(dropped.get("name", "")) in loot_item_name.text, "Ganimet kartındaki düşen ekipman adı doğru")
		loot_card.free()
	rep.free()

	# -------------------------------------------------------------------------
	# TEST 5: Sınırsız Eşzamanlı Sefer (Saldırı + Casus + Destek + Ticaret + Saldırı)
	# -------------------------------------------------------------------------
	var state_d: Dictionary = gs.call("to_dict")
	var now_u := int(Time.get_unix_time_from_system())
	var m1 := MovementScript.send_attack(state_d, 100, 201, {"axe": 30}, now_u, {"include_lord": true})
	var m2 := MovementScript.send_spy(state_d, 100, 202, {"spy": 10}, now_u)
	var m3 := MovementScript.send_support(state_d, 100, 203, {"spear": 20}, now_u)
	var m4 := MovementScript.send_trade(state_d, 100, 203, {"wood": 500, "stone": 500, "iron": 500}, now_u)
	var m5 := MovementScript.send_attack(state_d, 100, 202, {"axe": 25, "light": 10}, now_u, {"include_lord": true})

	_check(bool(m1.get("ok", false)) and bool(m2.get("ok", false)) and bool(m3.get("ok", false)) and bool(m4.get("ok", false)) and bool(m5.get("ok", false)),
		"Aynı köyden aynı saniyede Saldırı + Casus + Destek + Ticaret + 2. Saldırı eşzamanlı gönderilebiliyor")
	var all_movs: Array = state_d.get("movements", [])
	_check(all_movs.size() == 5, "5 eşzamanlı hareketin tümü listede (%d)" % all_movs.size())
	_check(bool((m1.get("movement", {}) as Dictionary).get("include_lord", false)) and not bool((m5.get("movement", {}) as Dictionary).get("include_lord", true)),
		"Lord yalnızca 1. saldırıya katıldı, 2. saldırı Lordsüz devam etti")

	gs.call("from_dict", state_d)
	var home_after: Dictionary = gs.call("get_village", 100)
	_check(int((home_after.get("units", {}) as Dictionary).get("axe", -1)) == 65, "Kalan Baltacı sayısı doğru düşüldü (120 - 30 - 25 = 65)")
	_check(int((home_after.get("units", {}) as Dictionary).get("spy", -1)) == 30, "Kalan Casus sayısı doğru düşüldü (40 - 10 = 30)")
	_check(int((home_after.get("units", {}) as Dictionary).get("spear", -1)) == 60, "Kalan Silahtar sayısı doğru düşüldü (80 - 20 = 60)")

	# WorldMap katman & tıklama önceliği doğrulaması (bottom_march_bar asla SendTroopsPanel'i örtmez)
	var wm_scene := load("res://scenes/WorldMap.tscn") as PackedScene
	var wmap := wm_scene.instantiate()
	root.add_child(wmap)
	await process_frame

	var b_bar := wmap.get("bottom_march_bar") as Control
	var st_panel := wmap.get("send_troops_panel") as Control
	_check(b_bar != null and b_bar.visible, "Sefer varken WorldMap bottom_march_bar görünüyor")
	_check(st_panel != null and st_panel.get_index() > b_bar.get_index(), "SendTroopsPanel düğüm sırası olarak bottom_march_bar üstünde (tıklamaları engellemez)")

	wmap.call("_on_village_clicked", bandit_2)
	await process_frame
	_check(st_panel.visible and not b_bar.visible, "Başka köye tıklanınca SendTroopsPanel açılıyor ve bottom_march_bar gizleniyor")
	var lord_chk := st_panel.find_child("ChkIncludeLord", true, false) as CheckBox
	_check(lord_chk != null and lord_chk.disabled and not lord_chk.button_pressed, "Lord seferdeyken SendTroopsPanel Lord kutusu devre dışı kalıyor ama saldırı engellenmiyor")
	var atk_btn := st_panel.find_child("BtnAttack", true, false) as Button
	var sp_inputs: Dictionary = st_panel.get("_unit_inputs")
	if sp_inputs.has("axe"):
		(sp_inputs["axe"] as SpinBox).value = 20
	st_panel.call("refresh")
	await process_frame
	_check(atk_btn != null and not atk_btn.disabled, "Mevcut birlik seçilince 2. saldırı butonu aktif oluyor")
	wmap.free()
	await process_frame
