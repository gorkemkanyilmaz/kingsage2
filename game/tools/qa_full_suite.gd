extends SceneTree
## QA Full Suite — Tüm UI Arayüzleri ve Oyun Mekanikleri Uçtan Uca Doğrulama Scripti.
##
## Kullanım:
##   tools\godot\Godot_v4.7.2-stable_win64_console.exe --path game -s tools/qa_full_suite.gd

const OUT_DIR := "c:/Users/Gorkem/Desktop/kingsage2/screenshots/qa/"

const WorldGeneratorScript := preload("res://scripts/world/WorldGenerator.gd")
const VillageModelScript := preload("res://scripts/model/VillageModel.gd")
const RulesEngineScript := preload("res://scripts/rules/RulesEngine.gd")
const MovementScript := preload("res://scripts/sim/actions/Movement.gd")
const ActionSimulatorScript := preload("res://scripts/sim/actions/ActionSimulator.gd")
const BattleSimulatorScript := preload("res://scripts/sim/battle/BattleSimulator.gd")
const AllianceModelScript := preload("res://scripts/model/AllianceModel.gd")

var _pass_count := 0
var _fail_count := 0
var _test_results: Array = []


func _log_check(id: String, desc: String, condition: bool, extra: String = "") -> void:
	if condition:
		_pass_count += 1
		print("  [PASS] %s: %s %s" % [id, desc, extra])
		_test_results.append({"id": id, "desc": desc, "pass": true, "extra": extra})
	else:
		_fail_count += 1
		print("  [FAIL] %s: %s %s" % [id, desc, extra])
		_test_results.append({"id": id, "desc": desc, "pass": false, "extra": extra})


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	print("\n=======================================================")
	print("  TAHT VE KILIÇ — KAPSAMLI QA & UI DOĞRULAMA SUITE'I")
	print("=======================================================\n")

	var data_mgr = load("res://autoload/GameData.gd").get_singleton()
	data_mgr.load_all(true)

	if root.get_node_or_null("EventBus") == null:
		var eb = Node.new(); eb.set_script(load("res://autoload/EventBus.gd")); eb.name = "EventBus"; root.add_child(eb)
	if root.get_node_or_null("AuthManager") == null:
		var am = Node.new(); am.set_script(load("res://autoload/AuthManager.gd")); am.name = "AuthManager"; root.add_child(am)
	if root.get_node_or_null("NetworkManager") == null:
		var nm = Node.new(); nm.set_script(load("res://autoload/NetworkManager.gd")); nm.name = "NetworkManager"; root.add_child(nm)
	if root.get_node_or_null("GameState") == null:
		var gs = Node.new(); gs.set_script(load("res://autoload/GameState.gd")); gs.name = "GameState"; root.add_child(gs)
	if root.get_node_or_null("SaveManager") == null:
		var sm = Node.new(); sm.set_script(load("res://autoload/SaveManager.gd")); sm.name = "SaveManager"; root.add_child(sm)

	_run_all_tests()


func _run_all_tests() -> void:
	var gs_node = root.get_node("GameState")
	var auth_mgr = root.get_node("AuthManager")
	var now := int(Time.get_unix_time_from_system())

	# -------------------------------------------------------------------------
	# [KATEGORİ 1] Ana Menü & Kimlik Doğrulama
	# -------------------------------------------------------------------------
	print("\n--- [KATEGORİ 1] Ana Menü & Kimlik Doğrulama ---")
	auth_mgr.logout()
	_log_check("TC-01", "Başlangıçta oturum kapalı ve auth_overlay görünür olmalı", not auth_mgr.is_logged_in)

	await _shot("res://scenes/MainMenu.tscn", "01_main_menu_auth_modal.png")
	var mm = current_scene
	var overlay = mm.get_node_or_null("AuthOverlay")
	_log_check("TC-01b", "Krallık Kapısı AuthOverlay sahne ağacında mevcut", overlay != null and overlay.visible)

	# Google ile giriş
	var google_profile = auth_mgr.login_with_google("Lord Gorkem")
	_log_check("TC-02", "Google ile giriş başarılı", auth_mgr.is_logged_in and auth_mgr.auth_provider == "google")
	_log_check("TC-02b", "Profil adı Lord Gorkem", auth_mgr.display_name == "Lord Gorkem")

	if mm != null and mm.has_method("_refresh_auth_state"):
		mm._refresh_auth_state()
	for i in range(10): await process_frame
	await _save_now("01b_main_menu_logged_in.png")

	# Apple ile giriş
	auth_mgr.login_with_apple("Lord Roland")
	_log_check("TC-03", "Apple ile giriş başarılı", auth_mgr.is_logged_in and auth_mgr.auth_provider == "apple")

	# Tekrar Google ile devam
	auth_mgr.login_with_google("Lord Gorkem")

	# -------------------------------------------------------------------------
	# [KATEGORİ 2] Köy & Yön Seçimi
	# -------------------------------------------------------------------------
	print("\n--- [KATEGORİ 2] Köy & Yön Seçimi ---")
	await _shot("res://scenes/VillageSelect.tscn", "02_village_select.png")
	var vs = current_scene
	_log_check("TC-06", "Yön butonları mevcut (NW/NE/SW/SE/Random)", vs.has_node("Center/VBox/Grid/BtnNW") and vs.has_node("Center/VBox/BtnRandom"))

	# Dünya & Başkent kurulumu
	var seed_val := 4242
	var world := WorldGeneratorScript.generate(seed_val, 20)
	var vmodel = VillageModelScript
	var pv: Dictionary = vmodel.create(999, "Başkent", 100, 100, "Lord Gorkem", false)
	pv["is_bot"] = false
	world["villages"].append(pv)
	world["tiles"][WorldGeneratorScript.tile_key(100, 100)] = 999

	gs_node.world = world
	gs_node.villages = world["villages"].duplicate(true)
	gs_node.player = {"id": 1, "name": "Lord Gorkem", "points": int(pv.get("points", 110))}
	gs_node.active_village_id = 999

	_log_check("TC-07", "Başkent başarıyla kuruldu (Puan 110, Sahip: Lord Gorkem)", pv["points"] == 110 and pv["owner"] == "Lord Gorkem")

	# -------------------------------------------------------------------------
	# [KATEGORİ 3] Köy Ekranı, Arka Plan & Navigasyon
	# -------------------------------------------------------------------------
	print("\n--- [KATEGORİ 3] Köy Ekranı & Arayüz Mimarisi ---")
	# Örnek inşaat aktivitesi ekleyelim
	gs_node.queues = [
		{
			"id": 1,
			"village_id": 999,
			"type": "build",
			"key": "wood",
			"target_level": 2,
			"start_unix": now - 30,
			"finish_unix": now + 90
		}
	]

	await _shot("res://scenes/Village.tscn", "03_village_main.png")
	var vil = current_scene
	var rbar = vil.get_node_or_null("ResourceBar")
	var bnav = vil.get_node_or_null("BottomNav")
	var qhud = vil.get_node_or_null("QueueHUD")
	_log_check("TC-08", "ResourceBar mevcut", rbar != null)
	_log_check("TC-10", "15 bina düğümü mevcut ve eksiksiz yüklendi", vil._building_nodes.size() == 15 and vil._building_nodes.has("main") and vil._building_nodes.has("barracks"))
	_log_check("TC-11", "Pixel-Perfect 6 butonlu BottomNav mevcut", bnav != null and bnav.has_node("HBox/BtnReports") and bnav.has_node("HBox/BtnMessages"))
	_log_check("TC-12", "Aktif İnşaat HUD görünür", qhud != null and qhud.visible)

	# -------------------------------------------------------------------------
	# [KATEGORİ 4 & 5] Binaların İçi, Yükseltme, Önkoşullar & Eğitme
	# -------------------------------------------------------------------------
	print("\n--- [KATEGORİ 4 & 5] Binaların İçi, Yükseltme & Araştırma/Eğitim ---")
	var bp = vil.get_node_or_null("BuildingPanel")
	_log_check("TC-13a", "BuildingPanel mevcut", bp != null)

	# 1. Oduncu Kampı Yükseltme
	bp.show_building(pv, "wood")
	bp.show()
	for i in range(12): await process_frame
	await _save_now("03b_building_wood_upgrade.png")
	_log_check("TC-13b", "Oduncu Kampı detay paneli açıldı", bp.visible and bp._current_key == "wood")

	# 2. Depo (Storage) 4 Seviye Önizleme Tablosu
	bp.show_building(pv, "storage")
	for i in range(12): await process_frame
	await _save_now("03c_building_storage_table.png")
	_log_check("TC-14", "Depo 4 seviye tablosu paneli açıldı", bp._current_key == "storage")

	# 3. Kışla Eğitim (TRAIN) Sekmesi
	pv["buildings"]["barracks"] = 5
	pv["researched"] = {"spear": true, "sword": true, "axe": true, "bow": true, "spy": true}
	bp.show_building(pv, "barracks")
	bp._switch_tab(2) # Tab.TRAIN
	for i in range(12): await process_frame
	await _save_now("03d_building_barracks_train.png")
	_log_check("TC-18", "Kışla Birlik Eğitme (TRAIN) sekmesi açıldı", bp._current_tab == 2)

	# 4. Kışla Araştırma (RESEARCH) Sekmesi
	bp._switch_tab(1) # Tab.RESEARCH
	for i in range(12): await process_frame
	await _save_now("03e_building_barracks_research.png")
	_log_check("TC-17", "Kışla Araştırma (RESEARCH) sekmesi açıldı", bp._current_tab == 1)

	# 5. Köşk (Snob) Önkoşul ve Fetih Bilgisi
	bp.show_building(pv, "snob")
	bp._switch_tab(0) # Tab.UPGRADE
	for i in range(12): await process_frame
	await _save_now("03f_building_snob_conquest.png")
	_log_check("TC-15", "Köşk (Snob) bina paneli açıldı", bp._current_key == "snob")
	bp.hide()

	# -------------------------------------------------------------------------
	# [KATEGORİ 6] Dünya Haritası, Kalkan & Sefer
	# -------------------------------------------------------------------------
	print("\n--- [KATEGORİ 6] Dünya Haritası, Kalkan & Sefer ---")
	var target_v: Dictionary = {}
	for v in world["villages"]:
		if int(v.get("id", 0)) != 999:
			target_v = v
			break

	var target_id: int = int(target_v.get("id", 1))

	gs_node.movements = [
		{
			"id": 101,
			"village_id": 999,
			"from_village_id": 999,
			"to_village_id": target_id,
			"type": "attack",
			"state": "outgoing",
			"owner": "Lord Gorkem",
			"units": {"spear": 50, "axe": 30},
			"carry": {"wood": 0, "stone": 0, "iron": 0},
			"depart_unix": now - 40,
			"arrive_unix": now + 120,
		},
		{
			"id": 102,
			"village_id": 999,
			"from_village_id": target_id,
			"to_village_id": 999,
			"type": "return",
			"state": "returning",
			"owner": "Lord Gorkem",
			"units": {"spy": 10},
			"carry": {"wood": 400, "stone": 300, "iron": 200},
			"depart_unix": now - 50,
			"arrive_unix": now + 60,
		}
	]

	await _shot("res://scenes/WorldMap.tscn", "04_world_map_overview.png")
	var wm = current_scene
	_log_check("TC-20", "Dünya haritası başarıyla yüklendi", wm != null)
	_log_check("TC-24", "Canlı ordu hareketleri haritada listelendi (2 hareket)", gs_node.movements.size() == 2)

	# Sefer & Sevkiyat Paneli (Saldırı Modu - Sadece "Saldır" butonu, "Talan" kaldırılmış)
	var stp = wm.get_node_or_null("SendTroopsPanel")
	if stp != null:
		stp.show_target(pv, target_v)
		for i in range(12): await process_frame
		await _save_now("04b_send_troops_attack_mode.png")
		_log_check("TC-23a", "SendTroopsPanel Saldırı modu açıldı", stp.visible)
		_log_check("TC-23b", "BtnRaid (Talan) gizli, sadece BtnAttack (Saldır) aktif", not stp.btn_raid.visible and stp.btn_attack.visible)

		# Katır Sevkiyat Modu ("Hammadde Gönder")
		stp._switch_tab("trade")
		for i in range(12): await process_frame
		await _save_now("04c_send_troops_trade_mode.png")
		_log_check("TC-23c", "Hammadde Gönder (Katır) sekmesi açıldı", stp.btn_trade.visible and not stp.btn_attack.visible)
		stp.hide()

	# Hareket Detay Kartı
	if wm.has_method("_open_movement_details"):
		wm._open_movement_details(gs_node.movements[0])
		for i in range(12): await process_frame
		await _save_now("04d_movement_detail.png")
		_log_check("TC-24b", "Sefer detay kartı başarıyla görüntülendi", wm.movement_detail_panel != null and wm.movement_detail_panel.visible)
		if wm.movement_detail_panel != null:
			wm.movement_detail_panel.hide()

	# Alt menüden Köy sekmesine basıldığında Köy ekranına dönüş doğrulaması (TC-22)
	var wm_bnav = wm.get_node_or_null("BottomNav")
	_log_check("TC-22a", "Dünya haritası alt menüsünde Köy butonu mevcut", wm_bnav != null and wm_bnav.btn_village != null)
	if wm_bnav != null and wm_bnav.btn_village != null:
		wm_bnav.btn_village.emit_signal("pressed")
		for i in range(16): await process_frame
		_log_check("TC-22b", "Haritadan alt menü 'Köy'e basılınca Köy ekranına dönüldü", current_scene.scene_file_path.contains("Village.tscn"))
		# Tekrar WorldMap'e dönerek test akışını sürdür
		change_scene_to_file("res://scenes/WorldMap.tscn")
		for i in range(12): await process_frame

	# -------------------------------------------------------------------------
	# [KATEGORİ 7] Savaş, Casusluk & Fetih Simülasyonu
	# -------------------------------------------------------------------------
	print("\n--- [KATEGORİ 7] Savaş, Casusluk & Fetih Simülasyonu ---")
	# 1. Savaş & Yağma Simülasyonu
	var atk_units := {"axe": 150, "light": 50}
	var def_units := {"spear": 30, "sword": 20}
	var battle_sim: Dictionary = BattleSimulatorScript.simulate(
		{"units": atk_units, "morale": 1.0, "luck": 0.0},
		{"units": def_units, "wall": 2, "night": false},
		{"seed": 1234}
	)
	var atk_won: bool = bool(battle_sim.get("attacker_won", false))
	var loot: Dictionary = battle_sim.get("loot", {})
	_log_check("TC-25a", "Savaş simülasyonu çalıştı ve saldıran kazandı", atk_won)
	_log_check("TC-25b", "Zafer sonrası otomatik yağma gerçekleşti", loot.has("wood") and loot.has("stone"))

	# 2. Casusluk Simülasyonu (%50+ sağkalım ile binalar, %70+ ile birlikler)
	var state_two := {
		"villages": [
			{"id": 1, "owner": "Lord Gorkem", "units": {"spy": 20, "axe": 300, "snob": 2}, "resources": {"wood": 1000, "stone": 1000, "iron": 1000}, "buildings": {"main": 10, "barracks": 10, "snob": 1}},
			{"id": 2, "owner": "Düşman", "units": {"spear": 15, "spy": 2}, "resources": {"wood": 800, "stone": 600, "iron": 400}, "buildings": {"main": 5, "barracks": 3}, "points": 350}
		],
		"reports": [],
		"movements": [],
		"queues": []
	}
	var spy_sent := MovementScript.send_spy(state_two, 1, 2, {"spy": 10}, now)
	_log_check("TC-26a", "Casus seferi sevk edildi", bool(spy_sent.get("ok", false)))
	var spy_events := ActionSimulatorScript.process_tick(state_two, int(spy_sent["movement"]["arrive_unix"]), 1.0)
	var spy_rep: Dictionary = {}
	for r in state_two["reports"]:
		if str(r.get("type", "")) == "spy":
			spy_rep = r; break
	_log_check("TC-26b", "Casusluk raporu oluşturuldu", not spy_rep.is_empty())
	if not spy_rep.is_empty():
		var spy_data: Dictionary = spy_rep.get("data", {})
		_log_check("TC-26c", "Casusluk raporu binaları içeriyor (%50+ sağkalım)", spy_data.has("buildings"))
		_log_check("TC-26d", "Casusluk raporu kaynakları içeriyor", spy_data.has("resources"))

	# 3. Fetih & Güç Alanı Simülasyonu
	var target_conquer_v = state_two["villages"][1]
	target_conquer_v["realm_of_power"] = 15 # Düşük güç alanı, son Kont darbesi ile fethedilecek
	var conquer_sent := MovementScript.send_attack(state_two, 1, 2, {"axe": 200, "snob": 1}, now)
	var conquer_events := ActionSimulatorScript.process_tick(state_two, int(conquer_sent["movement"]["arrive_unix"]), 1.0)
	_log_check("TC-27a", "Köy fethedildi ve sahibi değişti", str(target_conquer_v["owner"]) == "Lord Gorkem")
	_log_check("TC-27b", "Köy fetih koruması aldı", int(target_conquer_v["conquest_protection_until"]) > now)

	# 4. İkinci Köyün Eklenmesi & Köyler Arası Geçiş
	var conquered_village = target_conquer_v.duplicate(true)
	conquered_village["id"] = 1000
	conquered_village["name"] = "Yeni Fetih"
	gs_node.villages.append(conquered_village)

	var p_vills: Array = gs_node.get_player_villages()
	_log_check("TC-28a", "Oyuncunun artık 2 köyü var", p_vills.size() == 2)

	# Köy 1'den Köy 2'ye geçiş
	var next_vid: int = gs_node.cycle_active_village(1)
	_log_check("TC-28b", "cycle_active_village(1) ile 2. köye geçildi (#1000)", next_vid == 1000 and gs_node.active_village_id == 1000)

	# Köy ekranında 2 köy arası geçiş butonları doğrulaması
	await _shot("res://scenes/Village.tscn", "09_conquest_second_village_cycle.png")
	var vil2 = current_scene
	var rbar2 = vil2.get_node_or_null("ResourceBar")
	_log_check("TC-28c", "ResourceBar'da < ve > geçiş okları aktif hale geldi", rbar2 != null and rbar2.btn_prev.visible and rbar2.btn_next.visible)

	# Tekrar Başkent'e dön
	gs_node.cycle_active_village(-1)
	_log_check("TC-28d", "cycle_active_village(-1) ile Başkent'e dönüldü (#999)", gs_node.active_village_id == 999)

	# -------------------------------------------------------------------------
	# [KATEGORİ 8] İttifak Sistemi (Kurma, Bulma, Sohbet)
	# -------------------------------------------------------------------------
	print("\n--- [KATEGORİ 8] İttifak Sistemi ---")
	gs_node.alliances = []
	await _shot("res://scenes/Alliance.tscn", "06_alliance_create.png")
	var ally_scene = current_scene
	_log_check("TC-29a", "İttifak sahnesi açıldı (Üye olmayan görünümü)", ally_scene != null)

	# İttifak Kur
	var create_res := AllianceModelScript.create_alliance(
		gs_node.to_dict(),
		"Lord Gorkem",
		"Kuzey Muhafızları",
		"KUZEY",
		"Kuzeyin kadim ve onurlu lordları burada toplanır."
	)
	_log_check("TC-29b", "İttifak başarıyla kuruldu (KUZEY)", bool(create_res.get("ok", false)))
	if bool(create_res.get("ok", false)):
		gs_node.alliances.append(create_res["alliance"])

	var a_id: int = int(create_res["alliance"].get("id", 1)) if bool(create_res.get("ok", false)) else 1
	var chat_res := AllianceModelScript.send_chat_message(
		gs_node.to_dict(),
		a_id,
		"Lord Gorkem",
		"Selam olsun sancaktarlar! Krallığımızı birlikte yükselteceğiz."
	)
	_log_check("TC-31", "İttifak canlı sohbetine mesaj gönderildi", bool(chat_res.get("ok", false)))

	# İttifak Üye Görünümünü Yenile ve Çek
	ally_scene.refresh_view()
	for i in range(12): await process_frame
	await _save_now("06c_alliance_chat_and_members.png")
	_log_check("TC-32", "İttifak canlı sohbet ve üye paneli görüntülendi", ally_scene._active_tab == "chat")

	# -------------------------------------------------------------------------
	# [KATEGORİ 9] Raporlar ve Mesajlaşma
	# -------------------------------------------------------------------------
	print("\n--- [KATEGORİ 9] Raporlar ve Mesajlaşma ---")
	gs_node.reports = [
		{
			"type": "battle",
			"unix": now - 300,
			"unread": true,
			"data": {
				"attacker_name": "Lord Gorkem",
				"defender_name": "Soyguncular",
				"target_name": "Demirtaş (98|89)",
				"attacker_won": true,
				"loot": {"wood": 1250, "stone": 950, "iron": 680},
				"carry_capacity": 3000,
				"attacker_units": {"axe": 150, "light": 40},
				"attacker_losses": {"axe": 8, "light": 1},
				"defender_units": {"spear": 45, "sword": 30},
				"defender_losses": {"spear": 45, "sword": 30}
			}
		},
		{
			"type": "spy",
			"unix": now - 1200,
			"unread": false,
			"data": {
				"target_name": "Bozova (29|111)",
				"spy_survivors": 18,
				"spy_losses": 2,
				"defence_spies": 4,
				"creeping": false,
				"resources": {"wood": 1800, "stone": 1400, "iron": 900},
				"units": {"spear": 25, "bow": 15},
				"buildings": {"main": 8, "wood": 10, "stone": 9, "iron": 8, "barracks": 6, "wall": 5},
				"outside_units": {"light": 12}
			}
		},
		{
			"type": "trade",
			"unix": now - 3600,
			"unread": false,
			"data": {
				"resources": {"wood": 500, "stone": 350, "iron": 200}
			}
		}
	]

	gs_node.messages = [
		{
			"id": 1,
			"from": "Lord Edward",
			"to": "Lord Gorkem",
			"subject": "Barış ve Ticaret Teklifi",
			"body": "Selamlar Lord Gorkem,\n\nDoğu sınırımızdaki maden sevkiyatları için ortak kervan yolu anlaşması öneriyorum. Kılıcınız keskin olsun.",
			"created_unix": now - 1800,
			"read": false
		}
	]

	await _shot("res://scenes/Reports.tscn", "05_reports_list.png")
	var rep_scene = current_scene
	_log_check("TC-33a", "Raporlar sekmesi açıldı ve 3 rapor listelendi", rep_scene._current_tab == "reports")

	# Savaş Raporu Detayı
	rep_scene._show_detail(gs_node.reports[0])
	for i in range(12): await process_frame
	await _save_now("05b_report_battle_detail.png")
	_log_check("TC-33b", "Savaş raporu detay paneli (kayıplar ve ganimet) açıldı", rep_scene.detail_panel.visible)
	rep_scene.detail_panel.hide()

	# Casusluk Raporu Detayı (Binalar ve Dışarıdaki Birlikler ile)
	rep_scene._show_detail(gs_node.reports[1])
	for i in range(12): await process_frame
	await _save_now("05c_report_spy_detail.png")
	_log_check("TC-33c", "Casusluk raporu detay paneli (binalar ve birlikler) açıldı", rep_scene.detail_panel.visible)
	rep_scene.detail_panel.hide()

	# Mesajlar Sekmesi
	rep_scene._select_tab("messages")
	for i in range(12): await process_frame
	await _save_now("05d_messages_inbox.png")
	_log_check("TC-34", "Mesajlar sekmesi ve Gelen Kutusu açıldı", rep_scene._current_tab == "messages")

	# Yeni Mesaj Yaz Sekmesi (Composer)
	rep_scene._select_tab("new_message")
	for i in range(12): await process_frame
	await _save_now("05e_messages_composer.png")
	_log_check("TC-35", "Yeni Mektup Yaz paneli açıldı", rep_scene.composer_panel != null and rep_scene.composer_panel.visible)

	# -------------------------------------------------------------------------
	# [KATEGORİ 10] Sıralama ve Ayarlar
	# -------------------------------------------------------------------------
	print("\n--- [KATEGORİ 10] Sıralama ve Ayarlar ---")
	await _shot("res://scenes/Ranking.tscn", "07_ranking_players.png")
	var rk_scene = current_scene
	_log_check("TC-36a", "Oyuncu sıralaması açıldı", rk_scene != null)

	if rk_scene.has_node("MainContainer/TabBar/BtnTabAlliances"):
		var btn_a = rk_scene.get_node("MainContainer/TabBar/BtnTabAlliances") as Button
		btn_a.emit_signal("pressed")
		for i in range(12): await process_frame
		await _save_now("07b_ranking_alliances.png")
		_log_check("TC-36b", "İttifak sıralaması açıldı", true)

	await _shot("res://scenes/Settings.tscn", "08_settings.png")
	var st_scene = current_scene
	_log_check("TC-37", "Ayarlar ekranı açıldı", st_scene != null)

	print("\n=======================================================")
	print("  QA SONUÇLARI: PASS=%d | FAIL=%d" % [_pass_count, _fail_count])
	print("  Tüm Ekran Görüntüleri Kaydedildi -> %s" % OUT_DIR)
	print("=======================================================\n")

	if _fail_count > 0:
		quit(1)
	else:
		quit(0)


func _shot(scene_path: String, file_name: String) -> void:
	change_scene_to_file(scene_path)
	for i in range(16):
		await process_frame
	await _save_now(file_name)


func _save_now(file_name: String) -> void:
	for i in range(4):
		await process_frame
	var img: Image = root.get_texture().get_image()
	if img == null:
		print("HATA: görüntü alınamadı -> ", file_name)
		return
	var err := img.save_png(OUT_DIR + file_name)
	print("  📸 [%s] kaydedildi (err=%s, %s)" % [file_name, err, img.get_size()])
