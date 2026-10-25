extends SceneTree
## Gerçek Oyuncu Test Ajanı (Player Simulation Agent Test).
##
## Bir insan oyuncunun yapabileceği tüm eylemleri ve kontrolleri uçtan uca simüle eder:
##  1. Yeni Oyun başlatma & yön seçimi (Kuzeybatı)
##  2. Başarısız olması gereken eylemler (Önkoşulsuz Kışla, yetersiz kaynakla bina)
##  3. Köy ekonomisini büyütme (Depo -> Değirmen -> Kışla -> Oduncu/Taş/Maden)
##  4. Kuyruk ek maliyeti (+%25) ve iptal iade kuralı
##  5. Başarısız olması gereken eğitimler (Araştırılmamış Okçu, aşırı nüfus)
##  6. Birim araştırmaları (Okçu, Casus) ve ordu eğitimi
##  7. Başarısız olması gereken seferler (Min. birlik kuralı, Kont 80 alan sınırı)
##  8. Casusluk görevi ve gözlem raporu incelemesi
##  9. Soyguncu köyüne talan, 5 fazlı muharebe, ganimet ve eve dönüş
## 10. Arayüz butonları, sahneler ve sistem değişmezleri

const WorldGeneratorScript := preload("res://scripts/world/WorldGenerator.gd")
const VillageModelScript := preload("res://scripts/model/VillageModel.gd")
const RulesEngineScript := preload("res://scripts/rules/RulesEngine.gd")
const EconomySimulatorScript := preload("res://scripts/sim/economy/EconomySimulator.gd")
const ArmySimulatorScript := preload("res://scripts/sim/army/ArmySimulator.gd")
const ActionSimulatorScript := preload("res://scripts/sim/actions/ActionSimulator.gd")

const EconomyAPI := preload("res://scripts/sim/economy/EconomyAPI.gd")
const ArmyAPI := preload("res://scripts/sim/army/ArmyAPI.gd")
const MovementScript := preload("res://scripts/sim/actions/Movement.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	print("================================================================")
	print("       GERÇEK OYUNCU TEST AJANI (PLAYER AGENT SIMULATION)")
	print("================================================================")

	_run_player_journey()

	print("\n==================== TEST SONUÇLARI ====================")
	print("TOPLAM BAŞARILI (PASS): %d" % _passed)
	print("TOPLAM BAŞARISIZ (FAIL): %d" % _failed)
	print("========================================================")

	if _failed > 0:
		quit(1)
	else:
		quit(0)


func _assert(condition: bool, msg: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] %s" % msg)
	else:
		_failed += 1
		printerr("  [FAIL] %s" % msg)


func _step_sim(state: Dictionary, now_unix: int, delta: float) -> Array:
	if typeof(state.get("world")) == TYPE_DICTIONARY:
		state["world"]["sim_now_unix"] = now_unix
	var events: Array = []
	events.append_array(EconomySimulatorScript.process_tick(state, now_unix, delta))
	events.append_array(ArmySimulatorScript.process_tick(state, now_unix, delta))
	events.append_array(ActionSimulatorScript.process_tick(state, now_unix, delta))
	return events


func _run_player_journey() -> void:
	# -------------------------------------------------------------------------
	# 1. BÖLÜM: Yeni Oyun ve Başlangıç Yönü Seçimi
	# -------------------------------------------------------------------------
	print("\n--- [1] Yeni Oyun Başlatma & Yön Seçimi (Kuzeybatı) ---")
	var seed_val := 887766
	var world := WorldGeneratorScript.generate(seed_val, 100)
	var tiles: Dictionary = world.get("tiles", {})

	# Oyuncu Kuzeybatı (25, 25) bölgesini seçer
	var spot := WorldGeneratorScript.find_free_spot(tiles, 25, 25, WorldGeneratorScript.SIZE)
	_assert(spot.x >= 0 and spot.y >= 0, "Kuzeybatı bölgesinde boş koordinat bulundu: (%d|%d)" % [spot.x, spot.y])

	var player_vid: int = world["villages"].size() + 1
	var player_v: Dictionary = VillageModelScript.create(player_vid, "Şanlı Başkent", spot.x, spot.y, "Oyuncu", false)
	player_v["is_bot"] = false
	world["villages"].append(player_v)
	world["tiles"][WorldGeneratorScript.tile_key(spot.x, spot.y)] = player_vid

	var state: Dictionary = {
		"version": 1,
		"world": world,
		"villages": world["villages"].duplicate(true),
		"queues": [],
		"movements": [],
		"reports": [],
		"player": {
			"id": 1,
			"name": "Kral Arthur",
			"points": 110,
			"protection_until_unix": 1000000 + (5 * 86400),
			"conquest_protection_until_unix": 0,
			"premium": false,
		},
		"active_village_id": player_vid,
	}

	# Referans köyü state["villages"] içinden bağla
	for v in state["villages"]:
		if int(v.get("id", -1)) == player_vid:
			player_v = v
			break

	var now := 1000000
	state["world"]["sim_now_unix"] = now

	_assert(player_v["resources"]["wood"] == 1000, "Başlangıç odun: 1000")
	_assert(player_v["resources"]["stone"] == 1000, "Başlangıç taş: 1000")
	_assert(player_v["resources"]["iron"] == 1000, "Başlangıç demir: 1000")
	_assert(player_v["buildings"]["main"] == 1, "Başlangıç Kale seviyesi: 1")
	_assert(player_v["buildings"]["storage"] == 1, "Başlangıç Depo seviyesi: 1 (kapasite 1000)")
	_assert(player_v["buildings"]["farm"] == 1, "Başlangıç Değirmen seviyesi: 1 (vatandaş 250)")

	# -------------------------------------------------------------------------
	# 2. BÖLÜM: Başarısız Olması Gereken Eylemler (Negative Testing)
	# -------------------------------------------------------------------------
	print("\n--- [2] Başarısız Olması Gereken İnşaat Denemeleri (Kural Motoru Koruması) ---")

	# (a) Önkoşulsuz Kışla denemesi (Depo 3 + Değirmen 3 olmadan inşa EDİLEMEZ)
	var try_barracks := EconomyAPI.start_build(player_v, "barracks", state)
	_assert(not bool(try_barracks.get("ok", false)), "Kışla önkoşulsuz inşa edilemedi (beklenen red)")
	_assert(str(try_barracks.get("reason", "")) == "requirements", "Red sebebi doğru: 'requirements'")

	# (b) Yetersiz hammadde ile pahalı bina denemesi (Köşk seviye 1)
	var try_snob := EconomyAPI.start_build(player_v, "snob", state)
	_assert(not bool(try_snob.get("ok", false)), "Yetersiz hammadde ile Köşk inşa edilemedi (beklenen red)")
	_assert(str(try_snob.get("reason", "")) in ["requirements", "resources"], "Red sebebi doğru ('requirements' veya 'resources')")

	# -------------------------------------------------------------------------
	# 3. BÖLÜM: Köyü Adım Adım Büyütme (Ekonomi & İnşaat)
	# -------------------------------------------------------------------------
	print("\n--- [3] Köyü Büyütme: Önkoşulları Sırayla Tamamlama ---")

	# Depo Seviye 2 inşa et
	var b_depo2 = EconomyAPI.start_build(player_v, "storage", state)
	_assert(bool(b_depo2.get("ok", false)), "Depo Seviye 2 inşaatı başlatıldı")
	var fin_depo2: int = int(b_depo2.get("item", {}).get("finish_unix", now + 100))
	now = fin_depo2 + 1
	_step_sim(state, now, 1.0)
	_assert(int(player_v["buildings"]["storage"]) == 2, "Depo Seviye 2 tamamlandı")

	# Depo Seviye 3 inşa et
	var b_depo3 = EconomyAPI.start_build(player_v, "storage", state)
	_assert(bool(b_depo3.get("ok", false)), "Depo Seviye 3 inşaatı başlatıldı")
	var fin_depo3: int = int(b_depo3.get("item", {}).get("finish_unix", now + 100))
	now = fin_depo3 + 1
	_step_sim(state, now, 1.0)
	_assert(int(player_v["buildings"]["storage"]) == 3, "Depo Seviye 3 tamamlandı (Önkoşul 1/2 sağlandı)")

	# Değirmen Seviye 2 inşa et
	var b_farm2 = EconomyAPI.start_build(player_v, "farm", state)
	_assert(bool(b_farm2.get("ok", false)), "Değirmen Seviye 2 inşaatı başlatıldı")
	var fin_farm2: int = int(b_farm2.get("item", {}).get("finish_unix", now + 100))
	now = fin_farm2 + 1
	_step_sim(state, now, 1.0)
	_assert(int(player_v["buildings"]["farm"]) == 2, "Değirmen Seviye 2 tamamlandı")

	# Değirmen Seviye 3 inşa et
	var b_farm3 = EconomyAPI.start_build(player_v, "farm", state)
	_assert(bool(b_farm3.get("ok", false)), "Değirmen Seviye 3 inşaatı başlatıldı")
	var fin_farm3: int = int(b_farm3.get("item", {}).get("finish_unix", now + 100))
	now = fin_farm3 + 1
	_step_sim(state, now, 1.0)
	_assert(int(player_v["buildings"]["farm"]) == 3, "Değirmen Seviye 3 tamamlandı (Önkoşul 2/2 sağlandı)")

	# Artık Kışla inşa edilebilir olmalıdır!
	var b_barracks = EconomyAPI.start_build(player_v, "barracks", state)
	_assert(bool(b_barracks.get("ok", false)), "Önkoşullar tamamlanınca Kışla Seviye 1 başarıyla başlatıldı!")
	var fin_barracks: int = int(b_barracks.get("item", {}).get("finish_unix", now + 300))
	now = fin_barracks + 1
	_step_sim(state, now, 1.0)
	_assert(int(player_v["buildings"]["barracks"]) == 1, "Kışla Seviye 1 tamamlandı!")

	# Oduncu, Taş ve Maden ocaklarını büyüt
	var b_wood = EconomyAPI.start_build(player_v, "wood", state)
	now = int(b_wood.get("item", {}).get("finish_unix", now + 200)) + 1
	_step_sim(state, now, 1.0)

	var b_stone = EconomyAPI.start_build(player_v, "stone", state)
	now = int(b_stone.get("item", {}).get("finish_unix", now + 200)) + 1
	_step_sim(state, now, 1.0)

	var b_iron = EconomyAPI.start_build(player_v, "iron", state)
	now = int(b_iron.get("item", {}).get("finish_unix", now + 200)) + 1
	_step_sim(state, now, 1.0)

	_assert(int(player_v["buildings"]["wood"]) >= 2, "Oduncu kampı yükseltildi (sv >= 2)")
	_assert(int(player_v["buildings"]["stone"]) >= 2, "Taş ocağı yükseltildi (sv >= 2)")
	_assert(int(player_v["buildings"]["iron"]) >= 2, "Maden ocağı yükseltildi (sv >= 2)")

	# -------------------------------------------------------------------------
	# 4. BÖLÜM: Kuyruk Ek Maliyeti (+%25) ve İptal İade Kuralı
	# -------------------------------------------------------------------------
	print("\n--- [4] Kuyruk Ek Maliyeti ve İptal İade Doğrulaması ---")
	player_v["buildings"]["storage"] = 20
	player_v["buildings"]["farm"] = 20
	player_v["resources"]["wood"] = 2000
	player_v["resources"]["stone"] = 2000
	player_v["resources"]["iron"] = 2000

	# 3 ücretsiz kuyruk işi doldur
	EconomyAPI.start_build(player_v, "wood", state)
	EconomyAPI.start_build(player_v, "wood", state)
	EconomyAPI.start_build(player_v, "wood", state)

	# 4. iş ek maliyetli olmalı
	var job4 = EconomyAPI.start_build(player_v, "wood", state)
	_assert(bool(job4.get("ok", false)), "4. inşaat işi sıraya alındı")
	_assert(int(job4.get("extra_percent", 0)) == 25, "4. iş için +%25 kuyruk ek maliyeti uygulandı")

	var q_item: Dictionary = job4.get("item", {})
	var wood_before: int = int(player_v["resources"]["wood"])
	var cancel_res = EconomyAPI.cancel_build(player_v, int(q_item.get("id", 0)), state)
	_assert(bool(cancel_res.get("ok", false)), "Kuyruk işi iptal edildi")

	var wood_refunded: int = int(cancel_res.get("refunded_base", {}).get("wood", 0))
	var wood_forfeited: int = int(cancel_res.get("forfeited", {}).get("wood", 0))
	_assert(wood_refunded > 0 and wood_forfeited > 0, "Yalnızca taban maliyet iade edildi (ek maliyet yandı)")

	# Kuyruktaki kalan işleri tamamla
	now += 20000
	_step_sim(state, now, 20000.0)

	# -------------------------------------------------------------------------
	# 5. BÖLÜM: Ordu Eğitimi & Araştırma (Negative & Positive)
	# -------------------------------------------------------------------------
	print("\n--- [5] Ordu Eğitimi ve Araştırma Testleri ---")
	# (a) Araştırılmamış birim eğitimi başarısız olmalı
	var try_train_bow := ArmyAPI.start_training(player_v, "bow", 10, state, now)
	_assert(not bool(try_train_bow.get("ok", false)), "Araştırılmamış Okçu eğitimi reddedildi (beklenen red)")

	# (b) Vatandaş kapasitesini aşan eğitim başarısız olmalı
	var try_overpop := ArmyAPI.start_training(player_v, "spear", 10000, state, now)
	_assert(not bool(try_overpop.get("ok", false)), "Vatandaş kapasitesini aşan eğitim reddedildi (beklenen red)")

	# Kışla seviye 5 yap
	player_v["buildings"]["barracks"] = 5
	player_v["buildings"]["farm"] = 25
	player_v["buildings"]["storage"] = 30
	player_v["resources"] = {"wood": 50000, "stone": 50000, "iron": 50000}
	_assert(int(player_v["buildings"]["barracks"]) >= 5, "Kışla Seviye 5 yapıldı")

	# Okçu araştırması başlat ve bitir
	var res_bow = ArmyAPI.start_research(player_v, "bow", state, now)
	_assert(bool(res_bow.get("ok", false)), "Okçu araştırması başlatıldı")
	var fin_res_bow: int = int(res_bow.get("queue", {}).get("finish_unix", now + 500))
	now = fin_res_bow + 1
	_step_sim(state, now, 1.0)
	_assert(bool(player_v.get("researched", {}).get("bow", false)), "Okçu araştırması tamamlandı")

	# Casus araştırması başlat ve bitir
	var res_spy = ArmyAPI.start_research(player_v, "spy", state, now)
	_assert(bool(res_spy.get("ok", false)), "Casus araştırması başlatıldı")
	var fin_res_spy: int = int(res_spy.get("queue", {}).get("finish_unix", now + 500))
	now = fin_res_spy + 1
	_step_sim(state, now, 1.0)
	_assert(bool(player_v.get("researched", {}).get("spy", false)), "Casus araştırması tamamlandı")

	# 100 Okçu ve 20 Casus eğit
	var tr_bow = ArmyAPI.start_training(player_v, "bow", 100, state, now)
	_assert(bool(tr_bow.get("ok", false)), "100 Okçu eğitimi kuyruğa alındı")
	var fin_tr_bow: int = int(tr_bow.get("queue", {}).get("finish_unix", now + 3600))
	now = fin_tr_bow + 1
	_step_sim(state, now, 1.0)
	_assert(int(player_v.get("units", {}).get("bow", 0)) == 100, "100 Okçu başarıyla eğitildi ve köyde")

	var tr_spy = ArmyAPI.start_training(player_v, "spy", 20, state, now)
	_assert(bool(tr_spy.get("ok", false)), "20 Casus eğitimi kuyruğa alındı")
	var fin_tr_spy: int = int(tr_spy.get("queue", {}).get("finish_unix", now + 3600))
	now = fin_tr_spy + 1
	_step_sim(state, now, 1.0)
	_assert(int(player_v.get("units", {}).get("spy", 0)) == 20, "20 Casus başarıyla eğitildi ve köyde")

	# -------------------------------------------------------------------------
	# 6. BÖLÜM: Sefer Gönderme Kuralları (Negative Testing)
	# -------------------------------------------------------------------------
	print("\n--- [6] Sefer Gönderme Kuralları ve Asgari Ordu Kapısı ---")
	var target_barb: Dictionary = {}
	for v in state.get("villages", []):
		if str(v.get("owner", "")) == "Soyguncular" or bool(v.get("is_barbarian", false)):
			target_barb = v
			break
	_assert(not target_barb.is_empty(), "Hedef soyguncu köyü bulundu: %s (id: %d)" % [target_barb["name"], target_barb["id"]])

	var target_id: int = int(target_barb["id"])
	var p_id: int = int(player_v["id"])

	# (a) Asgari birlik kuralı (Kışla 5 iken 3 × 5 = 15 okçu şarttır; 5 okçu REDDEDİLMELİDİR)
	var check_under_min = MovementScript.can_send(state, p_id, target_id, MovementScript.TYPE_ATTACK, {"bow": 5}, {}, now)
	_assert(not bool(check_under_min.get("ok", false)), "Asgari birlik kuralı altı (5 < 15) sefer reddedildi (beklenen red)")
	_assert(str(check_under_min.get("code", "")) == "min_units", "Red kodu doğru: 'min_units'")

	# (b) Kont 80 alan mesafe kapısı testi (Köyde 1 Kont olsun)
	player_v["units"]["snob"] = 1
	var far_target: Dictionary = VillageModelScript.create(9999, "Uzak Kale", spot.x + 90, spot.y + 90, "Düşman", false)
	far_target["protection_until"] = 0
	far_target["conquest_protection_until"] = 0
	state["villages"].append(far_target)
	var check_far_count = MovementScript.can_send(state, p_id, 9999, MovementScript.TYPE_ATTACK, {"snob": 1, "bow": 20}, {}, now)
	_assert(not bool(check_far_count.get("ok", false)), "80 alandan uzak hedefe Kont gönderilemedi (beklenen red)")
	_assert(str(check_far_count.get("code", "")) == "count_too_far", "Red kodu doğru: 'count_too_far'")

	# -------------------------------------------------------------------------
	# 7. BÖLÜM: Casusluk / Gözlem Görevi ve Rapor İncelenmesi
	# -------------------------------------------------------------------------
	print("\n--- [7] Casusluk / Gözlem Görevi ve Gözlem Raporu ---")
	var spy_dispatch = MovementScript.send_spy(state, p_id, target_id, {"spy": 10}, now, {"creeping": false})
	_assert(bool(spy_dispatch.get("ok", false)), "10 Casus ile gözlem görevi başlatıldı")
	_assert(int(player_v["units"]["spy"]) == 10, "Görevdeki casuslar köyden düşüldü (20 -> 10)")

	var spy_mov: Dictionary = spy_dispatch.get("movement", {})
	var arrive_spy: int = int(spy_mov.get("arrive_unix", now + 3600))
	now = arrive_spy + 1
	_step_sim(state, now, 1.0)

	# Dönüş hareketini bul ve varışına ilerle
	for m in state.get("movements", []):
		if str(m.get("type", "")) == "return" and int(m.get("to_village_id", 0)) == p_id:
			now = int(m.get("arrive_unix", now + 3600)) + 1
			_step_sim(state, now, 1.0)
			break

	var spy_reports = state.get("reports", []).filter(func(r): return r.get("type") == "spy")
	_assert(spy_reports.size() > 0, "Gözlem raporu başarıyla oluşturuldu (rapor sayısı: %d)" % spy_reports.size())
	var s_rep: Dictionary = spy_reports[spy_reports.size() - 1]
	_assert(str(s_rep.get("type", "")) == "spy", "Üretilen rapor türü 'spy' (casusluk)")
	var rep_data: Dictionary = s_rep.get("data", {})
	_assert(rep_data.has("buildings") or rep_data.has("resources"), "Gözlem raporu hedef köyün bina veya hammadde verisini içeriyor")
	_assert(int(player_v["units"]["spy"]) == 20, "Dönen casuslar köye başarıyla geri katıldı (10 -> 20)")

	# -------------------------------------------------------------------------
	# 8. BÖLÜM: Yağma / Talan Görevi, 5 Fazlı Savaş ve Ganimet Dönüşü
	# -------------------------------------------------------------------------
	print("\n--- [8] Talan Görevi, Deterministik Savaş ve Ganimet Dönüşü ---")
	target_barb["resources"] = {"wood": 5000, "stone": 5000, "iron": 5000}
	player_v["units"]["bow"] = 200
	var raid_dispatch = MovementScript.send_raid(state, p_id, target_id, {"bow": 150}, now)
	_assert(bool(raid_dispatch.get("ok", false)), "150 Okçu ile soyguncu köyüne talan gönderildi")
	_assert(int(player_v["units"]["bow"]) == 50, "Gönderilen okçular köyden düşüldü (200 -> 50)")

	var raid_mov: Dictionary = raid_dispatch.get("movement", {})
	var arrive_raid: int = int(raid_mov.get("arrive_unix", now + 3600))
	now = arrive_raid + 1
	_step_sim(state, now, 1.0)

	# Dönüş hareketini bul ve varışına ilerle
	for m in state.get("movements", []):
		if str(m.get("type", "")) == "return" and int(m.get("to_village_id", 0)) == p_id:
			now = int(m.get("arrive_unix", now + 3600)) + 1
			_step_sim(state, now, 1.0)
			break

	var battle_reports = state.get("reports", []).filter(func(r): return r.get("type") == "battle")
	_assert(battle_reports.size() > 0, "Savaş raporu başarıyla üretildi")
	var b_rep: Dictionary = battle_reports[battle_reports.size() - 1]
	var b_data: Dictionary = b_rep.get("data", {})
	var outcome: String = str(b_data.get("outcome", ""))
	_assert(outcome in ["Saldıran kazandı", "Savunan kazandı"], "Savaş simülasyonu 5 fazı başarıyla sonuçlandırdı: '%s'" % outcome)
	_assert(b_data.has("phases"), "Savaş raporu muharebe fazı dökümünü içeriyor")
	_assert(int(player_v["units"]["bow"]) >= 50, "Sağ kalan ordu köye başarıyla geri döndü")

	# -------------------------------------------------------------------------
	# 9. BÖLÜM: UI Buton & Sahne Bütünlüğü Testi
	# -------------------------------------------------------------------------
	print("\n--- [9] Tüm Arayüz Butonları ve Ekran Bütünlüğü Testi ---")
	# 1. MainMenu butonları
	var mm_scene = load("res://scenes/MainMenu.tscn").instantiate()
	_assert(mm_scene.has_node("Center/VBox/BtnNewGame"), "MainMenu 'Yeni Oyun' butonu mevcut ve tıklanabilir")
	_assert(mm_scene.has_node("Center/VBox/BtnContinue"), "MainMenu 'Devam Et' butonu mevcut ve tıklanabilir")
	_assert(mm_scene.has_node("Center/VBox/BtnSettings"), "MainMenu 'Ayarlar' butonu mevcut ve tıklanabilir")
	mm_scene.queue_free()

	# 2. VillageSelect butonları (5 yön butonu)
	var vs_scene = load("res://scenes/VillageSelect.tscn").instantiate()
	_assert(vs_scene.has_node("Center/VBox/Grid/BtnNW"), "VillageSelect Kuzeybatı (NW) butonu mevcut")
	_assert(vs_scene.has_node("Center/VBox/Grid/BtnNE"), "VillageSelect Kuzeydoğu (NE) butonu mevcut")
	_assert(vs_scene.has_node("Center/VBox/Grid/BtnSW"), "VillageSelect Güneybatı (SW) butonu mevcut")
	_assert(vs_scene.has_node("Center/VBox/Grid/BtnSE"), "VillageSelect Güneydoğu (SE) butonu mevcut")
	_assert(vs_scene.has_node("Center/VBox/BtnRandom"), "VillageSelect Rastgele butonu mevcut")
	vs_scene.queue_free()

	# 3. BottomNav 5 sekme butonu
	var nav_scene = load("res://ui/BottomNav.tscn").instantiate()
	_assert(nav_scene.has_node("HBox/BtnVillage"), "BottomNav Köy butonu mevcut")
	_assert(nav_scene.has_node("HBox/BtnMap"), "BottomNav Harita butonu mevcut")
	_assert(nav_scene.has_node("HBox/BtnReports"), "BottomNav Raporlar butonu mevcut")
	_assert(nav_scene.has_node("HBox/BtnRanking"), "BottomNav Sıralama butonu mevcut")
	_assert(nav_scene.has_node("HBox/BtnMenu"), "BottomNav Ayarlar butonu mevcut")
	nav_scene.queue_free()

	# 4. BuildingPanel butonları
	var bp_scene = load("res://ui/BuildingPanel.tscn").instantiate()
	_assert(bp_scene.has_node("VBox/Header/CloseButton"), "BuildingPanel Kapat butonu mevcut")
	_assert(bp_scene.has_node("VBox/UpgradeButton"), "BuildingPanel Yükselt butonu mevcut")
	bp_scene.queue_free()

	# 5. WorldMap & SendTroopsPanel butonları
	var wm_scene = load("res://scenes/WorldMap.tscn").instantiate()
	_assert(wm_scene.has_node("Header/HBox/BtnGoto"), "WorldMap Koordinata Git butonu mevcut")
	_assert(wm_scene.has_node("SendTroopsPanel/VBox/ActionButtons/BtnAttack"), "Sefer Saldırı butonu mevcut")
	_assert(wm_scene.has_node("SendTroopsPanel/VBox/ActionButtons/BtnRaid"), "Sefer Talan butonu mevcut")
	wm_scene.queue_free()

	# -------------------------------------------------------------------------
	# 10. BÖLÜM: Sistem Değişmezleri (Invariants)
	# -------------------------------------------------------------------------
	print("\n--- [10] Tüm İşlemler Sonrası Sistem Değişmezleri (Invariants) ---")
	_assert(int(player_v["resources"]["wood"]) >= 0, "Değişmez: Odun >= 0")
	_assert(int(player_v["resources"]["stone"]) >= 0, "Değişmez: Taş >= 0")
	_assert(int(player_v["resources"]["iron"]) >= 0, "Değişmez: Demir >= 0")
	var cap: int = RulesEngineScript.storage_capacity(int(player_v["buildings"]["storage"]))
	_assert(int(player_v["resources"]["wood"]) <= cap, "Değişmez: Odun <= Depo Tavanı (%d)" % cap)
	var max_pop: int = RulesEngineScript.max_population(int(player_v["buildings"]["farm"]))
	var used_pop: int = VillageModelScript.population_used(player_v)
	_assert(used_pop <= max_pop, "Değişmez: Çalışan vatandaş (%d) <= Değirmen Tavanı (%d)" % [used_pop, max_pop])
	_assert(0 <= int(player_v.get("realm_of_power", 0)) and int(player_v.get("realm_of_power", 0)) <= int(player_v.get("points", 110)), "Değişmez: 0 <= Güç Alanı <= Köy Puanı")
