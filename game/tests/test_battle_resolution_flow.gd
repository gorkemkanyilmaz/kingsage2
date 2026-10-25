extends SceneTree
## test_battle_resolution_flow.gd — Tam Savaş Çözümleme, Rapor, Ganimet ve Bildirim Rozeti Testi

var _passed := 0
var _failed := 0


func _initialize() -> void:
	print("=== Savaş Çözümleme, Rapor ve Bildirim Rozeti Doğrulama Testi ===")
	_test_flow()
	print("\n====================")
	print("TOPLAM BAŞARILI: %d" % _passed)
	print("TOPLAM BAŞARISIZ: %d" % _failed)
	if _failed == 0:
		print("✅ TÜM SAVAŞ VE RAPOR MEKANİKLERİ BAŞARIYLA DOĞRULANDI!")
	else:
		print("❌ TESTLERDE HATA OLUŞTU!")
	quit(_failed)


func _assert(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("  [PASS] %s" % msg)
	else:
		_failed += 1
		print("  [FAIL] ❌ %s" % msg)


func _test_flow() -> void:
	var EventBusScript = load("res://autoload/EventBus.gd")
	var GameStateScript = load("res://autoload/GameState.gd")
	var GameClockScript = load("res://autoload/GameClock.gd")
	var GameConfigScript = load("res://autoload/GameConfig.gd")
	var GameDataScript = load("res://autoload/GameData.gd")
	var GameLoopScript = load("res://scripts/core/GameLoop.gd")
	var MovementScript = load("res://scripts/sim/actions/Movement.gd")
	var ActionSimulatorScript = load("res://scripts/sim/actions/ActionSimulator.gd")
	var RulesEngine = load("res://scripts/rules/RulesEngine.gd")
	var BottomNavScene = load("res://ui/BottomNav.tscn")
	var ReportsScene = load("res://scenes/Reports.tscn")

	# 1. Singleton kurulumları
	var eb = root.get_node_or_null("EventBus")
	if eb == null:
		eb = Node.new()
		eb.set_script(EventBusScript)
		eb.name = "EventBus"
		root.add_child(eb)

	var gs = root.get_node_or_null("GameState")
	if gs == null:
		gs = Node.new()
		gs.set_script(GameStateScript)
		gs.name = "GameState"
		root.add_child(gs)

	var gc = root.get_node_or_null("GameClock")
	if gc == null:
		gc = Node.new()
		gc.set_script(GameClockScript)
		gc.name = "GameClock"
		root.add_child(gc)

	var gd = GameDataScript.get_singleton()
	if gd.get_parent() == null:
		gd.name = "GameData"
		root.add_child(gd)

	var gcfg = GameConfigScript.get_singleton()
	if gcfg.get_parent() == null:
		gcfg.name = "GameConfig"
		root.add_child(gcfg)

	# 2. Test durumu: Oyuncu köyü (Depo Lv 2: 1200 cap) ve Terkedilmiş Hedef köy
	var v_player = {
		"id": 1, "name": "Oyuncu Köyü", "x": 100, "y": 100, "owner": "Kral", "is_bot": false,
		"is_barbarian": false, "buildings": {"main": 1, "storage": 2, "barracks": 10},
		"resources": {"wood": 1000, "stone": 1000, "iron": 1000},
		"units": {"axe": 200},
		"researched": {}, "realm_of_power": 100, "points": 100,
		"protection_until": 0, "conquest_protection_until": 0, "bonus_type": "", "has_statue": false,
	}
	var v_target = {
		"id": 2, "name": "Soyguncu Köyü", "x": 102, "y": 100, "owner": "", "is_bot": false,
		"is_barbarian": true, "buildings": {"storage": 5},
		"resources": {"wood": 4000, "stone": 4000, "iron": 4000},
		"units": {"spear": 5},
		"researched": {}, "realm_of_power": 50, "points": 50,
		"protection_until": 0, "conquest_protection_until": 0, "bonus_type": "", "has_statue": false,
	}
	var state = {
		"player": {"id": 1, "name": "Kral", "points": 100},
		"active_village_id": 1,
		"villages": [v_player, v_target],
		"movements": [], "reports": [], "queues": [], "alliances": [],
		"world": {"sim_now_unix": 1000000}
	}
	gs.from_dict(state)

	# 3. BottomNav UI örneği
	var bottom_nav = BottomNavScene.instantiate()
	root.add_child(bottom_nav)
	if bottom_nav.report_badge == null:
		bottom_nav._ready()
	_assert(bottom_nav.report_badge != null, "BottomNav içinde ReportBadge mevcut")
	_assert(not bottom_nav.report_badge.visible, "Başlangıçta rapor olmadığından rozet gizli")

	# 4. Ordu seferi gönder
	print("\n--- Sefer Gönderme ---")
	var now := 1000000
	var send_res = MovementScript.send_attack(state, 1, 2, {"axe": 100}, now, {"seed": 1234})
	_assert(bool(send_res.get("ok", false)), "100 Baltacı ile saldırı gönderildi")
	gs.from_dict(state)

	var mv: Dictionary = state["movements"][0]
	var arrive_unix: int = int(mv["arrive_unix"])
	_assert(arrive_unix > now, "Varış zamanı gelecekte (%d > %d)" % [arrive_unix, now])

	# 5. GameLoop ile varış anına simülasyon işlet
	print("\n--- Varış Anı ve Savaşın Çözümlenmesi (00:00) ---")
	var loop = root.get_node_or_null("GameLoop")
	if loop == null:
		loop = GameLoopScript.new()
		root.add_child(loop)
	loop.set_now_unix(now)

	# Varış anına atla
	var travel_time: float = float(arrive_unix - now)
	var events: Array = loop.simulate(travel_time)
	_assert(events.size() > 0, "Varış anında simülasyon olay üretti")

	var has_battle := false
	for e in events:
		if typeof(e) == TYPE_DICTIONARY and str(e.get("type", "")) == "battle_resolved":
			has_battle = true
			break
	_assert(has_battle, "Saldırı gerçekleşti ve 'battle_resolved' olayı yayınlandı")

	# Rapor oluşturuldu mu?
	_assert(gs.reports.size() == 1, "GameState içine savaş raporu eklendi (Rapor sayısı: %d)" % gs.reports.size())
	var rep: Dictionary = gs.reports[0]
	_assert(bool(rep.get("unread", false)), "Yeni gelen rapor 'unread' (okunmamış) işaretli")

	# Rozet güncellendi mi?
	bottom_nav.update_badge()
	_assert(bottom_nav.report_badge.visible, "BottomNav rapor butonunda kırmızı bildirim rozeti göründü")
	_assert(bottom_nav.badge_label.text == "(1)", "Bildirim rozeti metni '(1)' (Görünen: %s)" % bottom_nav.badge_label.text)

	# Ganimet ve dönüş hareketi oluştu mu?
	print("\n--- Sağ Kalan Birlikler ve Ganimet Dönüş Hareketi ---")
	var return_mvs: Array = []
	for m in gs.movements:
		if typeof(m) == TYPE_DICTIONARY and (str(m.get("state", "")) == "returning" or str(m.get("type", "")) == "return"):
			return_mvs.append(m)
	_assert(return_mvs.size() == 1, "Sağ kalan ordu ganimet ile geri dönüş hareketine başladı")

	var ret_mv: Dictionary = return_mvs[0]
	var carry: Dictionary = ret_mv.get("carry", {})
	var total_loot: int = int(carry.get("wood", 0)) + int(carry.get("stone", 0)) + int(carry.get("iron", 0))
	_assert(total_loot > 0, "Taşınan ganimet mevcut (Toplam ganimet: %d)" % total_loot)

	# 6. Köye varış simülasyonu
	print("\n--- Köye Geri Dönüş ve Depo Oranında Hammadde Kazanımı ---")
	var return_arrive: int = int(ret_mv["arrive_unix"])
	var return_dur: float = float(return_arrive - arrive_unix)

	var p_village_before = gs.get_active_village()
	var wood_before = int(p_village_before["resources"]["wood"])
	var storage_cap = RulesEngine.storage_capacity(2) # Depo Lv2 = 1150
	_assert(storage_cap == 1150, "Depo Seviye 2 kapasitesi doğrulaması (1150)")

	loop.simulate(return_dur)

	var p_village_after = gs.get_active_village()
	var wood_after = int(p_village_after["resources"]["wood"])
	_assert(wood_after == storage_cap, "Ganimet depoyu aştığında depo kapasitesinde (1150) kırpıldı: %d" % wood_after)
	_assert(int(p_village_after["units"]["axe"]) > 0, "Sağ kalan baltacılar köye geri katıldı")

	# 7. Raporlar Ekranı ve Okuma İşlemi
	print("\n--- Rapor Okuma ve Bildirim Rozetinin Kapanması ---")
	var reports_ui = ReportsScene.instantiate()
	root.add_child(reports_ui)

	# Raporu tıkla ve oku
	var current_rep: Dictionary = gs.reports[0]
	reports_ui._show_detail(current_rep)
	_assert(not bool(current_rep.get("unread", true)), "Rapor açılınca okunmuş ('unread'=false) olarak işaretlendi")

	# Bildirim rozeti kayboldu mu?
	bottom_nav.update_badge()
	_assert(not bottom_nav.report_badge.visible, "Okunmamış rapor kalmadığında bildirim rozeti kayboldu")

	# Temizlik
	bottom_nav.queue_free()
	reports_ui.queue_free()
	loop.queue_free()
