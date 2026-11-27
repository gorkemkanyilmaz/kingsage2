extends SceneTree
## Hareket sistemi testleri (A-KESIF) — Taht ve Kılıç.
##
## Çalıştırma:
##   godot --headless --path game --script res://tests/test_actions.gd
##
## Kapsam (görev doğrulaması):
##  (a) min. birlik altındaki saldırı reddedilir (3 × Kışla)
##  (b) korumalı köye saldırı reddedilir; terkedilmiş (soyguncu) köye izin verilir
##  (c) Kont 80 alan üstüne gönderilemez (Kont mesafesi)
##  (d) iptal 30/15 dk sınırında çalışır, sonrasında çalışmaz
##  (e) varışta savaş çözümlenir ve dönüş hareketi üretilir
##  (f) 10:1 oranı aşılırsa Kanun Kaçağı işaretlenir
##  (g) destek birlikleri hedefte görünür
##  (h) casusluk raporu üretilir
##  (i) aynı tohum → aynı sonuç (determinizm)
##
## Başarısızlıkta `quit(1)` ile çıkar (CI uyumlu).

const MovementScript := preload("res://scripts/sim/actions/Movement.gd")
const ActionSimulatorScript := preload("res://scripts/sim/actions/ActionSimulator.gd")
const ArrivalScript := preload("res://scripts/sim/actions/Arrival.gd")
const ProtectionScript := preload("res://scripts/sim/actions/Protection.gd")
const RE := preload("res://scripts/rules/RulesEngine.gd")
const BS := preload("res://scripts/sim/battle/BattleSimulator.gd")

const BUILDING_KEYS := [
	"barracks", "farm", "garage", "hide", "iron", "main", "market", "smith",
	"snob", "stable", "statue", "stone", "storage", "wall", "wood",
]
const UNIT_KEYS := [
	"farmer", "spear", "sword", "axe", "bow", "spy", "light", "heavy", "ram", "kata", "snob",
]

const NOW := 1000000
const MINUTE := 60

var _passed := 0
var _failed := 0


func _initialize() -> void:
	print("=== Hareket Sistemi Testleri (A-KESIF) ===")

	_test_min_units()
	_test_protection()
	_test_count_distance()
	_test_cancel()
	_test_battle_arrival()
	_test_return_home()
	_test_outlaw()
	_test_support()
	_test_spy()
	_test_spy_creeping()
	_test_spy_hideout()
	_test_spy_visibility()
	_test_spy_outside_units()
	_test_min_units_scope()
	_test_trade()
	_test_conquest()
	_test_conquest_protection()
	_test_determinism()
	_test_travel_symmetry()

	print("")
	print("Toplam: %d · Geçen: %d · Başarısız: %d" % [_passed + _failed, _passed, _failed])
	if _failed == 0:
		print("PASS")
		quit(0)
	else:
		print("FAIL")
		quit(1)


# ============================================================================
#  (a) Min. saldırı birimi = 3 × Kışla
# ============================================================================

func _test_min_units() -> void:
	_section("(a) Min. saldırı birimi (3 × Kışla)")

	var s := _state_two()
	_find_village(s, 1)["units"]["axe"] = 500
	# Kışla 20 → min 60 birim.
	var low := MovementScript.send_attack(s, 1, 2, {"axe": 2}, NOW)
	_check(not bool(low.get("ok", false)) and str(low.get("code", "")) == "min_units",
		"2 birim (< 60) → saldırı reddedildi [%s]" % str(low.get("code", "")))
	_check(s["movements"].is_empty(), "reddedilen saldırı hareket listesine yazılmadı")
	_check(int(_find_village(s, 1)["units"]["axe"]) == 500, "reddedilen saldırıda birlik düşülmedi")

	var boundary_low := MovementScript.send_attack(s, 1, 2, {"axe": 59}, NOW)
	_check(not bool(boundary_low.get("ok", false)) and str(boundary_low.get("code", "")) == "min_units",
		"59 birim (sınırın 1 altı) → reddedildi")

	var boundary_ok := MovementScript.send_attack(s, 1, 2, {"axe": 60}, NOW)
	_check(bool(boundary_ok.get("ok", false)), "60 birim (tam sınır) → kabul edildi")


# ============================================================================
#  (b) Koruma: korumalı köy reddedilir, soyguncu köyü serbest
# ============================================================================

func _test_protection() -> void:
	_section("(b) Koruma (yeni oyuncu 5 gün; soyguncu/bonus korumasız)")

	var s := _state_two()
	_find_village(s, 1)["units"]["axe"] = 500
	var target := _find_village(s, 2)
	target["protection_until"] = NOW + 86400  # 1 gün koruma

	var blocked := MovementScript.send_attack(s, 1, 2, {"axe": 100}, NOW)
	_check(not bool(blocked.get("ok", false)) and str(blocked.get("code", "")) == "target_protected",
		"korumalı köye saldırı reddedildi [%s]" % str(blocked.get("code", "")))

	# Soyguncu (terkedilmiş) köy: protection_until dolu olsa bile korumasız.
	var barbarian := _village(3, "Soyguncu Köyü", 120, 100, "Soyguncular", true,
		_buildings(10, 0, 5, 5), {"spear": 40})
	barbarian["is_barbarian"] = true
	barbarian["protection_until"] = NOW + 86400  # yok sayılmalı

	var s2 := _state_from([_own_origin(), barbarian])
	_find_village(s2, 1)["units"]["axe"] = 500
	var allowed := MovementScript.send_attack(s2, 1, 3, {"axe": 100}, NOW)
	_check(bool(allowed.get("ok", false)),
		"terkedilmiş (soyguncu) köye saldırı izinli [%s]" % str(allowed.get("code", "")))
	_check(ProtectionScript.is_unprotected_kind(barbarian), "soyguncu köy korumasız kabul edildi")

	# Bonus köy de korumasızdır.
	var bonus := _village(4, "Bonus Köy", 130, 100, "Usta", true, _buildings(5, 0, 0, 0), {"spear": 10})
	bonus["bonus_type"] = "wood"
	_check(not ProtectionScript.is_attack_protected(bonus, NOW), "bonus köy korumasız kabul edildi")


# ============================================================================
#  (c) Kont mesafesi ≤ 80 alan
# ============================================================================

func _test_count_distance() -> void:
	_section("(c) Kont mesafesi (≤ 80 alan)")

	var s := _state_two()
	_find_village(s, 1)["units"]["axe"] = 500
	_find_village(s, 1)["units"]["snob"] = 5

	# Hedefi uzağa taşı (127 alan).
	var far := _find_village(s, 2)
	far["x"] = 190
	far["y"] = 190
	var too_far := MovementScript.send_attack(s, 1, 2, {"axe": 100, "snob": 1}, NOW)
	_check(not bool(too_far.get("ok", false)) and str(too_far.get("code", "")) == "count_too_far",
		"Kont 127 alan → reddedildi [%s]" % str(too_far.get("code", "")))

	# Yakın hedef (20 alan) → izinli.
	var s2 := _state_two()
	_find_village(s2, 1)["units"]["axe"] = 500
	_find_village(s2, 1)["units"]["snob"] = 5
	var close := _find_village(s2, 2)
	close["x"] = 120
	close["y"] = 100
	var ok := MovementScript.send_attack(s2, 1, 2, {"axe": 100, "snob": 1}, NOW)
	_check(bool(ok.get("ok", false)), "Kont 20 alan → kabul edildi [%s]" % str(ok.get("code", "")))

	# Kontsuz ordu aynı uzaklıkta serbest.
	var s3 := _state_two()
	_find_village(s3, 1)["units"]["axe"] = 500
	var far3 := _find_village(s3, 2)
	far3["x"] = 190
	far3["y"] = 190
	var no_count := MovementScript.send_attack(s3, 1, 2, {"axe": 100}, NOW)
	_check(bool(no_count.get("ok", false)), "Kontsuz ordu uzak hedefe gidebilir")


# ============================================================================
#  (d) İptal: saldırı 30 dk, katır 15 dk
# ============================================================================

func _test_cancel() -> void:
	_section("(d) İptal süreleri (30 / 15 dk)")

	# Saldırı: 29 dk içinde iptal edilir, 31 dk sonra edilemez.
	var s := _state_two()
	_find_village(s, 1)["units"]["axe"] = 500
	var sent := MovementScript.send_attack(s, 1, 2, {"axe": 100}, NOW)
	var mid := int((sent["movement"] as Dictionary).get("id", 0))
	_check(int(_find_village(s, 1)["units"]["axe"]) == 400, "gönderimde 100 Baltacı düşüldü")

	var early := MovementScript.cancel(s, mid, NOW + 29 * MINUTE)
	_check(bool(early.get("ok", false)), "29 dk → saldırı iptal edildi")
	_check(int(_find_village(s, 1)["units"]["axe"]) == 500, "iptalde birlikler iade edildi")
	_check(s["movements"].is_empty(), "iptal edilen hareket listeden çıktı")

	var sent2 := MovementScript.send_attack(s, 1, 2, {"axe": 100}, NOW)
	var mid2 := int((sent2["movement"] as Dictionary).get("id", 0))
	var late := MovementScript.cancel(s, mid2, NOW + 31 * MINUTE)
	_check(not bool(late.get("ok", false)) and str(late.get("code", "")) == "window_closed",
		"31 dk → saldırı iptal edilemedi [%s]" % str(late.get("code", "")))
	_check(s["movements"].size() == 1, "süresi geçen hareket listede kaldı")

	# Katır (ticaret): 14 dk içinde iptal, 16 dk sonra edilemez.
	var own := _village(2, "İkinci Köy", 110, 100, "Kral", false, _buildings(0, 0, 0, 0), {})
	var t := _state_from([_own_origin(), own])
	_find_village(t, 1)["buildings"]["market"] = 1
	_find_village(t, 1)["resources"] = {"wood": 5000, "stone": 5000, "iron": 5000}
	var trade := MovementScript.send_trade(t, 1, 2, {"wood": 1000}, NOW)
	_check(bool(trade.get("ok", false)), "katır gönderildi [%s]" % str(trade.get("code", "")))
	_check(int(_find_village(t, 1)["resources"]["wood"]) == 4000, "gönderimde hammadde düşüldü")
	var tmid := int((trade["movement"] as Dictionary).get("id", 0))
	var t_early := MovementScript.cancel(t, tmid, NOW + 14 * MINUTE)
	_check(bool(t_early.get("ok", false)), "14 dk → katır iptal edildi")
	_check(int(_find_village(t, 1)["resources"]["wood"]) == 5000, "katır iptalinde hammadde iade edildi")

	var trade2 := MovementScript.send_trade(t, 1, 2, {"wood": 1000}, NOW)
	var tmid2 := int((trade2["movement"] as Dictionary).get("id", 0))
	var t_late := MovementScript.cancel(t, tmid2, NOW + 16 * MINUTE)
	_check(not bool(t_late.get("ok", false)) and str(t_late.get("code", "")) == "window_closed",
		"16 dk → katır iptal edilemedi [%s]" % str(t_late.get("code", "")))


# ============================================================================
#  (e) Varışta savaş çözümü + dönüş hareketi
# ============================================================================

func _test_battle_arrival() -> void:
	_section("(e) Varışta savaş çözülür + dönüş hareketi")

	var s := _state_two()
	_find_village(s, 1)["units"]["axe"] = 500
	var target := _find_village(s, 2)
	target["units"]["spear"] = 5
	target["resources"] = {"wood": 5000, "stone": 5000, "iron": 5000}

	var sent := MovementScript.send_attack(s, 1, 2, {"axe": 300}, NOW, {"seed": 12345})
	_check(bool(sent.get("ok", false)), "saldırı gönderildi")
	var mv: Dictionary = sent["movement"]
	_check(int(mv.get("battle_seed", 0)) == 12345, "battle_seed hareketle saklandı")

	var events := ActionSimulatorScript.process_tick(s, int(mv["arrive_unix"]), 1.0)
	var types := _event_types(events)
	_check(types.has("battle_resolved"), "varışta savaş çözümlendi (%s)" % str(types))
	_check(int(target["units"]["spear"]) == 0, "savunan birlikleri yok edildi")

	var returns := _movements_of_type(s, "return")
	_check(returns.size() == 1, "dönüş hareketi üretildi")
	var ret: Dictionary = returns[0]
	_check(int(ret.get("arrive_unix", 0)) - int(ret.get("depart_unix", 0))
		== int(mv.get("arrive_unix", 0)) - int(mv.get("depart_unix", 0)),
		"dönüş süresi = gidiş süresi")
	_check(_sum(ret["carry"]) > 0, "ganimet dönüşte taşınıyor (%d)" % _sum(ret["carry"]))


# ============================================================================
#  (e-2) Dönüş: birlikler ve ganimet eve döner
# ============================================================================

func _test_return_home() -> void:
	_section("(e) Dönüşte birlik + ganimet eve eklenir")

	var s := _state_two()
	_find_village(s, 1)["units"]["axe"] = 500
	_find_village(s, 1)["buildings"]["storage"] = 10
	var target := _find_village(s, 2)
	target["units"]["spear"] = 5
	target["resources"] = {"wood": 5000, "stone": 5000, "iron": 5000}

	var sent := MovementScript.send_attack(s, 1, 2, {"axe": 300}, NOW, {"seed": 999})
	var mv: Dictionary = sent["movement"]
	ActionSimulatorScript.process_tick(s, int(mv["arrive_unix"]), 1.0)

	var ret: Dictionary = _movements_of_type(s, "return")[0]
	var units_home := int(ret["units"].get("axe", 0))
	var loot: Dictionary = ret["carry"]
	var units_before := int(_find_village(s, 1)["units"]["axe"])
	var resources_before: Dictionary = _find_village(s, 1)["resources"].duplicate(true)

	var events := ActionSimulatorScript.process_tick(s, int(ret["arrive_unix"]), 1.0)
	_check(_event_types(events).has("movement_returned"), "dönüşte 'movement_returned' olayı")

	var origin := _find_village(s, 1)
	_check(int(origin["units"]["axe"]) == units_before + units_home,
		"hayatta kalan birlikler eve eklendi (%d + %d)" % [units_before, units_home])
	var resources_after: Dictionary = origin["resources"]
	var added_ok := true
	for r in ["wood", "stone", "iron"]:
		if int(resources_after[r]) != int(resources_before[r]) + int(loot[r]):
			added_ok = false
	_check(added_ok, "ganimet eve eklendi")
	_check(_movements_of_type(s, "return").is_empty(), "dönüş tamamlanınca listeden çıktı")


# ============================================================================
#  (f) 10:1 oranı → Kanun Kaçağı
# ============================================================================

func _test_outlaw() -> void:
	_section("(f) 10:1 oranı → Kanun Kaçağı (2 ay)")

	var s := _state_two()
	var origin := _find_village(s, 1)
	origin["units"]["axe"] = 500
	origin["points"] = 10000
	_find_village(s, 2)["points"] = 500  # 10000 > 10 × 500

	var res := MovementScript.send_attack(s, 1, 2, {"axe": 100}, NOW)
	_check(bool(res.get("ok", false)), "oran aşılsa da saldırı yapılır")
	_check(bool(res.get("outlawed", false)), "Kanun Kaçağı işaretlendi")
	_check(int(origin.get("outlaw_until", 0)) > NOW, "outlaw_until ileri bir tarihte")
	_check(int(origin.get("outlaw_until", 0)) - NOW == 60 * 86400, "ceza 60 gün (2 ay)")
	_check(str(s["player"].get("outlaw_until", 0)) != "0" and int(s["player"].get("outlaw_until", 0)) > NOW,
		"oyuncu (state.player) da Kanun Kaçağı")

	# Oran sınırı içindeyse Kanun Kaçağı olmaz.
	var s2 := _state_two()
	var origin2 := _find_village(s2, 1)
	origin2["units"]["axe"] = 500
	origin2["points"] = 1000
	_find_village(s2, 2)["points"] = 500  # 1000 < 10 × 500
	var ok := MovementScript.send_attack(s2, 1, 2, {"axe": 100}, NOW)
	_check(bool(ok.get("ok", false)) and not bool(ok.get("outlawed", false)), "oran sınırı içinde Kanun Kaçağı olunmaz")


# ============================================================================
#  (g) Destek: birlikler hedefte görünür
# ============================================================================

func _test_support() -> void:
	_section("(g) Destek birlikleri hedefte görünür")

	# Kendi köyüne destek.
	var own := _village(2, "İkinci Köy", 110, 100, "Kral", false, _buildings(0, 0, 0, 0), {})
	var s := _state_from([_own_origin(), own])
	_find_village(s, 1)["units"]["spear"] = 50

	var sent := MovementScript.send_support(s, 1, 2, {"spear": 50}, NOW)
	_check(bool(sent.get("ok", false)), "kendi köyüne destek gönderildi [%s]" % str(sent.get("code", "")))
	_check(int(_find_village(s, 1)["units"]["spear"]) == 0, "destek gönderilince birlik düşüldü")

	ActionSimulatorScript.process_tick(s, int(sent["movement"]["arrive_unix"]), 1.0)
	var target := _find_village(s, 2)
	_check(int(target["units"]["spear"]) == 50, "destek birlikleri hedefte görünür")
	_check(int(target.get("support", []).size()) == 1, "destek kaydı hedefte tutuluyor")
	_check(_movements_of_type(s, "return").is_empty(), "destek geri dönmez (hedefte konuşlanır)")

	# İttifak üyesine destek izinli, yabancıya değil.
	var ally := _village(3, "Müttefik Köy", 115, 100, "Dost", false, _buildings(0, 0, 0, 0), {})
	var s2 := _state_from([_own_origin(), ally])
	s2["alliances"] = [{"id": 1, "tag": "DOST", "members": ["Kral", "Dost"]}]
	_find_village(s2, 1)["units"]["spear"] = 20
	var ally_send := MovementScript.send_support(s2, 1, 3, {"spear": 20}, NOW)
	_check(bool(ally_send.get("ok", false)), "ittifak üyesine destek izinli")

	var enemy := _village(4, "Yabancı Köy", 120, 100, "Yabancı", false, _buildings(0, 0, 0, 0), {})
	var s3 := _state_from([_own_origin(), enemy])
	_find_village(s3, 1)["units"]["spear"] = 20
	var foreign := MovementScript.send_support(s3, 1, 4, {"spear": 20}, NOW)
	_check(bool(foreign.get("ok", false)),
		"yabancı/bot/barbar her köye destek izinli [%s]" % str(foreign.get("code", "")))

	# Kendi köyüne saldırı yasak.
	_find_village(s2, 1)["units"]["axe"] = 100
	var self_attack := MovementScript.send_attack(s2, 1, 3, {"axe": 100}, NOW)
	_check(not bool(self_attack.get("ok", false)) and str(self_attack.get("code", "")) in ["friendly_target", "min_units"],
		"ittifak üyesine saldırı yasak [%s]" % str(self_attack.get("code", "")))


# ============================================================================
#  (h) Casusluk raporu
# ============================================================================

func _test_spy() -> void:
	_section("(h) Casusluk raporu")

	var s := _state_two()
	_find_village(s, 1)["units"]["spy"] = 50
	var target := _find_village(s, 2)
	target["units"]["spear"] = 5
	target["resources"] = {"wood": 800, "stone": 600, "iron": 400}

	var sent := MovementScript.send_spy(s, 1, 2, {"spy": 10}, NOW)
	_check(bool(sent.get("ok", false)), "casus gönderildi [%s]" % str(sent.get("code", "")))
	var mv: Dictionary = sent["movement"]
	var events := ActionSimulatorScript.process_tick(s, int(mv["arrive_unix"]), 1.0)
	_check(_event_types(events).has("spy_resolved"), "casusluk çözümlendi")

	var reports: Array = s["reports"]
	var spy_report := _report_of_type(s, "spy")
	_check(not spy_report.is_empty(), "casusluk raporu (saldıran) üretildi")
	if not spy_report.is_empty():
		var data: Dictionary = spy_report.get("data", {})
		_check(data.has("resources") and int((data["resources"] as Dictionary).get("wood", 0)) == 800,
			"rapor hedefin kaynaklarını içeriyor")
		_check(data.has("units") and int((data["units"] as Dictionary).get("spear", 0)) == 5,
			"rapor hedefin birliklerini içeriyor")
		_check(int(data.get("spy_survivors", 0)) == 10, "savunan casus yok → tüm casuslar hayatta")
	_check(reports.size() >= 1, "en az bir rapor var")

	_check(int(target["units"]["spear"]) == 5, "casuslukta savunan birim kaybetmez")
	_check(_movements_of_type(s, "return").size() == 1, "casuslar döner (dönüş hareketi)")


# ============================================================================
#  (h-2) Gizli casusluk 3× yavaş
# ============================================================================

func _test_spy_creeping() -> void:
	_section("(h) Gizli casusluk 3× yavaş")

	var s := _state_two()
	_find_village(s, 1)["units"]["spy"] = 100
	var normal := MovementScript.send_spy(s, 1, 2, {"spy": 10}, NOW)
	var creeping := MovementScript.send_spy(s, 1, 2, {"spy": 10}, NOW, {"creeping": true})
	_check(bool(normal.get("ok", false)) and bool(creeping.get("ok", false)), "iki casusluk da gönderildi")
	var n_travel := int(normal["movement"]["arrive_unix"]) - int(normal["movement"]["depart_unix"])
	var c_travel := int(creeping["movement"]["arrive_unix"]) - int(creeping["movement"]["depart_unix"])
	_check(c_travel == 3 * n_travel, "gizli casusluk gidişi 3× uzun (%d → %d)" % [n_travel, c_travel])


# ============================================================================
#  (a-2) Gizli Depo casusluk raporunda kaynağı gizler
# ============================================================================

func _test_spy_hideout() -> void:
	_section("(a) Gizli Depo casusluk raporunda kaynağı (toplam havuz) gizler")

	# Somut örnek: 800/400/200 (toplam 1400), Gizli Depo sv5 (kapasite 301) → görünür 1099.
	var s := _state_two()
	_find_village(s, 1)["units"]["spy"] = 20
	var target := _find_village(s, 2)
	target["units"]["spear"] = 5
	target["resources"] = {"wood": 800, "stone": 400, "iron": 200}
	target["buildings"]["hide"] = 5  # Gizli Depo sv5

	var cap := RE.hideout_capacity(5)
	_check(cap == 301, "Gizli Depo sv5 kapasitesi 301 (%d)" % cap)

	var sent := MovementScript.send_spy(s, 1, 2, {"spy": 10}, NOW)
	ActionSimulatorScript.process_tick(s, int(sent["movement"]["arrive_unix"]), 1.0)
	var data: Dictionary = _report_of_type(s, "spy").get("data", {})
	var shown: Dictionary = data.get("resources", {})
	_check(int(data.get("actual_resources_total", 0)) == 1400, "gerçek toplam 1400")
	_check(int(data.get("visible_resources_total", 0)) == 1099, "görünür toplam 1099 (1400 − 301)")
	_check(int(data.get("hidden_amount", 0)) == 301, "gizlenen 301")
	_check(int(shown.get("wood", -1)) == 628, "görünür odun 628 (%d)" % int(shown.get("wood", -1)))
	_check(int(shown.get("stone", -1)) == 314, "görünür taş 314")
	_check(int(shown.get("iron", -1)) == 157, "görünür demir 157")
	_check(int(shown.get("wood", 0)) + int(shown.get("stone", 0)) + int(shown.get("iron", 0)) == 1099,
		"görünür kaynak toplamı korunuyor")

	# Yağma katmanıyla birebir aynı semantik: aynı toplamı dağıtan _compute_loot çıktısıyla eşit.
	# (Yağmada taşıma kapasitesi = görünür toplam alınırsa aynı dağıtım çıkar.)
	var loot_ref: Dictionary = BS._compute_loot(1099, {"wood": 800, "stone": 400, "iron": 200}, 301)
	_check(int(loot_ref.get("wood", -1)) == 628 and int(loot_ref.get("stone", -1)) == 314 and int(loot_ref.get("iron", -1)) == 157,
		"yağma dağıtımıyla aynı oran mantığı")
	_check(int(loot_ref.get("wood", 0)) == int(shown.get("wood", 0))
		and int(loot_ref.get("stone", 0)) == int(shown.get("stone", 0))
		and int(loot_ref.get("iron", 0)) == int(shown.get("iron", 0)),
		"casusluk raporu = yağma dağıtımı (birebir)")

	# Gizli Depo sonrası kaynak 0 ise (toplam ≤ kapasite) → üçü de 0 görünür.
	var z := _state_two()
	_find_village(z, 1)["units"]["spy"] = 20
	var z_target := _find_village(z, 2)
	z_target["units"]["spear"] = 5
	z_target["resources"] = {"wood": 120, "stone": 100, "iron": 50}  # toplam 270 ≤ 301
	z_target["buildings"]["hide"] = 5
	var z_sent := MovementScript.send_spy(z, 1, 2, {"spy": 10}, NOW)
	ActionSimulatorScript.process_tick(z, int(z_sent["movement"]["arrive_unix"]), 1.0)
	var z_data: Dictionary = _report_of_type(z, "spy").get("data", {})
	var z_shown: Dictionary = z_data.get("resources", {})
	_check(int(z_shown.get("wood", -1)) == 0 and int(z_shown.get("stone", -1)) == 0 and int(z_shown.get("iron", -1)) == 0,
		"toplam ≤ kapasite → üç kaynak da 0 görünür")
	_check(int(z_data.get("visible_resources_total", -1)) == 0, "görünür toplam 0")
	_check(int(z_data.get("hidden_amount", 0)) == 270, "gizlenen = gerçek toplam (270)")

	# Gizli Depo yoksa kaynak aynen görünür.
	var n := _state_two()
	_find_village(n, 1)["units"]["spy"] = 20
	_find_village(n, 2)["resources"] = {"wood": 800, "stone": 400, "iron": 200}
	var n_sent := MovementScript.send_spy(n, 1, 2, {"spy": 10}, NOW)
	ActionSimulatorScript.process_tick(n, int(n_sent["movement"]["arrive_unix"]), 1.0)
	var n_data: Dictionary = _report_of_type(n, "spy").get("data", {})
	_check(int((n_data.get("resources", {}) as Dictionary).get("wood", -1)) == 800,
		"Gizli Depo yoksa kaynak aynen görünür")


# ============================================================================
#  (b-2) Normal casusluk görünür, gizli casusluk görünmez
# ============================================================================

func _test_spy_visibility() -> void:
	_section("(b) Normal casusluk görünür (savunan rapor alır), gizli görünmez")

	# Normal casusluk: savunana görünür + savunan rapor alır.
	var s := _state_two()
	_find_village(s, 1)["units"]["spy"] = 50
	_find_village(s, 2)["units"]["spear"] = 5
	var normal := MovementScript.send_spy(s, 1, 2, {"spy": 10}, NOW)
	_check(bool((normal["movement"] as Dictionary).get("visible_to_defender", false)),
		"normal casusluk savunana görünür")
	ActionSimulatorScript.process_tick(s, int(normal["movement"]["arrive_unix"]), 1.0)
	_check(not _report_of_type(s, "spy_incoming").is_empty(),
		"normal casuslukta savunan rapor alır")

	# Gizli casusluk: savunana görünmez + savunan rapor ALMAZ.
	var g := _state_two()
	_find_village(g, 1)["units"]["spy"] = 50
	_find_village(g, 2)["units"]["spear"] = 5
	var creeping := MovementScript.send_spy(g, 1, 2, {"spy": 10}, NOW, {"creeping": true})
	_check(not bool((creeping["movement"] as Dictionary).get("visible_to_defender", true)),
		"gizli casusluk savunana görünmez")
	ActionSimulatorScript.process_tick(g, int(creeping["movement"]["arrive_unix"]), 1.0)
	_check(_report_of_type(g, "spy_incoming").is_empty(), "gizli casuslukta savunan rapor ALMAZ")
	_check(not _report_of_type(g, "spy").is_empty(), "gizli casuslukta saldıran yine rapor alır")


# ============================================================================
#  (c-2) Bilgi kademesi: normalde "dışarıdaki birlikler" var, gizlide yok
# ============================================================================

func _test_spy_outside_units() -> void:
	_section("(c) Normal raporda 'dışarıdaki birlikler' var, gizlide yok")

	var s := _state_two()
	_find_village(s, 1)["units"]["spy"] = 50
	_find_village(s, 2)["units"]["spear"] = 5
	# Hedef köyün dışarıda (yolda) bir ordusu olsun.
	s["movements"].append({
		"id": 999, "village_id": 2, "type": "raid", "from_village_id": 2, "to_village_id": 1,
		"units": {"axe": 7}, "depart_unix": NOW, "arrive_unix": NOW + 9999, "state": "outgoing",
	})
	var normal := MovementScript.send_spy(s, 1, 2, {"spy": 10}, NOW)
	ActionSimulatorScript.process_tick(s, int(normal["movement"]["arrive_unix"]), 1.0)
	var n_data: Dictionary = _report_of_type(s, "spy").get("data", {})
	_check(n_data.has("outside_units"), "normal raporda 'outside_units' alanı var")
	_check(int((n_data.get("outside_units", {}) as Dictionary).get("axe", 0)) == 7,
		"dışarıdaki 7 Baltacı raporlandı")

	var g := _state_two()
	_find_village(g, 1)["units"]["spy"] = 50
	_find_village(g, 2)["units"]["spear"] = 5
	g["movements"].append({
		"id": 999, "village_id": 2, "type": "raid", "from_village_id": 2, "to_village_id": 1,
		"units": {"axe": 7}, "depart_unix": NOW, "arrive_unix": NOW + 9999, "state": "outgoing",
	})
	var creeping := MovementScript.send_spy(g, 1, 2, {"spy": 10}, NOW, {"creeping": true})
	ActionSimulatorScript.process_tick(g, int(creeping["movement"]["arrive_unix"]), 1.0)
	var c_data: Dictionary = _report_of_type(g, "spy").get("data", {})
	_check(not c_data.has("outside_units"), "gizli raporda 'outside_units' YOK")


# ============================================================================
#  (d-2) Min. birlik kuralı yalnızca saldırı/talan
# ============================================================================

func _test_min_units_scope() -> void:
	_section("(d) Min. birlik kuralı yalnızca saldırı/talan")

	# _own_origin: Kışla 20 (min 60) + Market 1.
	var own := _village(2, "İkinci Köy", 110, 100, "Kral", false, _buildings(0, 0, 0, 0), {})
	var s := _state_from([_own_origin(), own])
	_find_village(s, 1)["units"]["spear"] = 1
	var support := MovementScript.send_support(s, 1, 2, {"spear": 1}, NOW)
	_check(bool(support.get("ok", false)),
		"1 birim destek min. eşiğe takılmaz [%s]" % str(support.get("code", "")))

	var s2 := _state_from([_own_origin(), own.duplicate(true)])
	_find_village(s2, 1)["resources"] = {"wood": 10, "stone": 10, "iron": 10}
	var trade := MovementScript.send_trade(s2, 1, 2, {"wood": 10}, NOW)
	_check(bool(trade.get("ok", false)),
		"küçük ticaret min. eşiğe takılmaz [%s]" % str(trade.get("code", "")))

	var s3 := _state_two()
	_find_village(s3, 1)["units"]["spy"] = 1
	var spy := MovementScript.send_spy(s3, 1, 2, {"spy": 1}, NOW)
	_check(bool(spy.get("ok", false)),
		"1 casus min. eşiğe takılmaz [%s]" % str(spy.get("code", "")))

	# Saldırı ise eşiğe takılır (kontrol).
	var s4 := _state_two()
	_find_village(s4, 1)["units"]["axe"] = 5
	var attack := MovementScript.send_attack(s4, 1, 2, {"axe": 5}, NOW)
	_check(not bool(attack.get("ok", false)) and str(attack.get("code", "")) == "min_units",
		"saldırı min. eşiğe takılır [%s]" % str(attack.get("code", "")))


# ============================================================================
#  Ticaret (katır) teslimi
# ============================================================================

func _test_trade() -> void:
	_section("Ticaret (katır) teslimi")

	var own := _village(2, "İkinci Köy", 110, 100, "Kral", false, _buildings(0, 0, 0, 0), {},
		{"wood": 100, "stone": 100, "iron": 100})
	var s := _state_from([_own_origin(), own])
	_find_village(s, 1)["buildings"]["market"] = 1
	_find_village(s, 1)["resources"] = {"wood": 5000, "stone": 5000, "iron": 5000}

	var sent := MovementScript.send_trade(s, 1, 2, {"wood": 1000, "stone": 400}, NOW)
	_check(bool(sent.get("ok", false)), "katır gönderildi [%s]" % str(sent.get("code", "")))
	ActionSimulatorScript.process_tick(s, int(sent["movement"]["arrive_unix"]), 1.0)

	var target := _find_village(s, 2)
	_check(int(target["resources"]["wood"]) == 1100, "hedefe odun teslim edildi (100 → 1100)")
	_check(int(target["resources"]["stone"]) == 500, "hedefe taş teslim edildi (100 → 500)")
	_check(_movements_of_type(s, "return").is_empty(), "katır geri dönmez")

	# Market yoksa ticaret reddedilir.
	var s2 := _state_from([_own_origin(), own.duplicate(true)])
	_find_village(s2, 1)["buildings"]["market"] = 0
	_find_village(s2, 1)["resources"] = {"wood": 5000, "stone": 5000, "iron": 5000}
	var no_market := MovementScript.send_trade(s2, 1, 2, {"wood": 100}, NOW)
	_check(not bool(no_market.get("ok", false)) and str(no_market.get("code", "")) == "market_required",
		"Market yoksa ticaret reddedildi [%s]" % str(no_market.get("code", "")))


# ============================================================================
#  Fetih (Kont → Güç Alanı 0)
# ============================================================================

func _test_conquest() -> void:
	_section("Fetih (Kont → Güç Alanı 0, en az 2 saldırı)")

	var s := _state_two()
	_find_village(s, 1)["units"]["axe"] = 500
	_find_village(s, 1)["units"]["snob"] = 3
	var target := _find_village(s, 2)
	target["points"] = 1000
	target["realm_of_power"] = 1000  # Tam güç alanı → tek Kont saldırısı YETMEZ!

	# 1. Kont saldırısı: maks yarı düşüş (1000 -> 500), fetih olmamalı
	var sent1 := MovementScript.send_attack(s, 1, 2, {"axe": 200, "snob": 1}, NOW, {"seed": 7})
	_check(bool(sent1.get("ok", false)), "1. fetih saldırısı gönderildi")
	var events1 := ActionSimulatorScript.process_tick(s, int(sent1["movement"]["arrive_unix"]), 1.0)
	_check(not _event_types(events1).has("village_conquered"), "1. Kont saldırısı tam köyü tek seferde FETHEDEMEZ")
	_check(int(target.get("realm_of_power", 0)) == 500, "1. Kont sonrası Güç Alanı yarıya (500) düştü")

	# 2. ayrı Kont saldırısı: kalan 500 -> 0 ve fetih tamamlanır
	target["units"]["spear"] = 0
	var arr1 := int(sent1["movement"]["arrive_unix"])
	var sent2 := MovementScript.send_attack(s, 1, 2, {"axe": 200, "snob": 1}, arr1 + 10, {"seed": 8})
	_check(bool(sent2.get("ok", false)), "2. fetih saldırısı gönderildi")
	var events2 := ActionSimulatorScript.process_tick(s, int(sent2["movement"]["arrive_unix"]), 1.0)
	_check(_event_types(events2).has("village_conquered"), "2. Kont saldırısıyla köy fethedildi")
	_check(str(target.get("owner", "")) == "Kral", "köyün sahibi saldırana geçti")
	_check(int(target.get("realm_of_power", 0)) > 0, "fetih sonrası Güç Alanı > 0")
	_check(int(target.get("conquest_protection_until", 0)) > 0, "fetih sonrası fetih koruması verildi")


func _test_conquest_protection() -> void:
	_section("Fetih koruması → Güç Alanı düşmez")

	var s := _state_two()
	_find_village(s, 1)["units"]["axe"] = 500
	_find_village(s, 1)["units"]["snob"] = 3
	var target := _find_village(s, 2)
	target["units"]["spear"] = 5
	target["points"] = 1000
	target["realm_of_power"] = 100
	target["conquest_protection_until"] = NOW + 86400

	var sent := MovementScript.send_attack(s, 1, 2, {"axe": 300, "snob": 1}, NOW, {"seed": 7})
	_check(bool(sent.get("ok", false)), "saldırı izinli (fetih koruması saldırıyı engellemez)")
	var events := ActionSimulatorScript.process_tick(s, int(sent["movement"]["arrive_unix"]), 1.0)
	var types := _event_types(events)
	_check(types.has("conquest_blocked"), "fetih engellendi olayı")
	_check(str(target.get("owner", "")) == "Düşman", "köy el değiştirmedi")
	_check(int(target.get("realm_of_power", 0)) == 100, "fetih korumasında Güç Alanı düşmedi")


# ============================================================================
#  (i) Determinizm
# ============================================================================

func _test_determinism() -> void:
	_section("(i) Determinizm (aynı tohum → aynı sonuç)")

	var s1 := _state_two()
	var s2 := _state_two()
	for s in [s1, s2]:
		_find_village(s, 1)["units"]["axe"] = 500
		var t := _find_village(s, 2)
		t["units"]["spear"] = 20
		t["resources"] = {"wood": 4000, "stone": 3000, "iron": 2000}
		MovementScript.send_attack(s, 1, 2, {"axe": 300}, NOW, {"seed": 4242})

	var mv1: Dictionary = s1["movements"][0]
	var mv2: Dictionary = s2["movements"][0]
	var e1 := ActionSimulatorScript.process_tick(s1, int(mv1["arrive_unix"]), 1.0)
	var e2 := ActionSimulatorScript.process_tick(s2, int(mv2["arrive_unix"]), 1.0)

	_check(JSON.stringify(e1) == JSON.stringify(e2), "aynı tohum → aynı olaylar")
	_check(JSON.stringify(s1["villages"]) == JSON.stringify(s2["villages"]), "aynı tohum → aynı köy durumu")
	_check(JSON.stringify(s1["movements"]) == JSON.stringify(s2["movements"]), "aynı tohum → aynı hareketler")

	# Farklı tohum → farklı (şans) sonuç olasılığı: en azından çökmemeli ve seed saklanmalı.
	var s3 := _state_two()
	_find_village(s3, 1)["units"]["axe"] = 500
	_find_village(s3, 2)["units"]["spear"] = 20
	MovementScript.send_attack(s3, 1, 2, {"axe": 300}, NOW, {"seed": 777})
	_check(int(s3["movements"][0]["battle_seed"]) == 777, "verilen tohum harekete yazıldı")


# ============================================================================
#  Yolculuk simetrisi (gidiş = dönüş)
# ============================================================================

func _test_travel_symmetry() -> void:
	_section("Yolculuk: gidiş = dönüş")

	var s := _state_two()
	_find_village(s, 1)["units"]["axe"] = 500
	_find_village(s, 2)["units"]["spear"] = 1
	var sent := MovementScript.send_attack(s, 1, 2, {"axe": 100}, NOW, {"seed": 5})
	var mv: Dictionary = sent["movement"]
	var travel := int(mv["arrive_unix"]) - int(mv["depart_unix"])
	_check(int(mv["return_unix"]) - int(mv["arrive_unix"]) == travel, "return_unix = arrive + gidiş süresi")

	# İptal iptal edilebilir pencere kapanınca çalışmaz (hareket hâlâ yolda).
	var c := MovementScript.cancel(s, int(mv["id"]), NOW + 10 * MINUTE)
	_check(bool(c.get("ok", false)), "10 dk içinde iptal edilebilir")


# ============================================================================
#  YARDIMCILAR
# ============================================================================

func _state_two() -> Dictionary:
	return _state_from([_own_origin(), _village(2, "Düşman Köyü", 110, 100, "Düşman", false, _buildings(0, 0, 0, 0), {})])


func _state_from(villages: Array) -> Dictionary:
	return {
		"player": {"id": 0, "name": "Kral", "points": 0},
		"villages": villages,
		"movements": [],
		"reports": [],
		"queues": [],
		"alliances": [],
	}


func _own_origin() -> Dictionary:
	return _village(1, "Başkent", 100, 100, "Kral", false, _buildings(20, 1, 0, 0), {})


func _village(
	id: int, name: String, x: int, y: int, owner: String, is_bot: bool,
	buildings: Dictionary, units: Dictionary, resources: Dictionary = {}
) -> Dictionary:
	var u := {}
	for key in UNIT_KEYS:
		u[key] = 0
	for key in units.keys():
		u[str(key)] = int(units[key])
	var r := {"wood": 1000, "stone": 1000, "iron": 1000}
	for key in resources.keys():
		r[str(key)] = int(resources[key])
	var points := RE.village_points(buildings)
	if points <= 0:
		points = 110
	return {
		"id": id, "name": name, "x": x, "y": y, "owner": owner, "is_bot": is_bot,
		"is_barbarian": false, "buildings": buildings, "resources": r, "units": u,
		"researched": {}, "realm_of_power": points, "points": points,
		"protection_until": 0, "conquest_protection_until": 0, "bonus_type": "", "has_statue": false,
	}


func _buildings(barracks: int, market: int = 0, hide: int = 0, wall: int = 0) -> Dictionary:
	var b := {}
	for key in BUILDING_KEYS:
		b[key] = 0
	for key in ["main", "stone", "wood", "iron", "farm", "storage"]:
		b[key] = 1
	b["barracks"] = barracks
	b["market"] = market
	b["hide"] = hide
	b["wall"] = wall
	return b


func _find_village(state: Dictionary, village_id: int) -> Dictionary:
	for village in state["villages"]:
		if int((village as Dictionary).get("id", -1)) == village_id:
			return village
	return {}


func _movements_of_type(state: Dictionary, type: String) -> Array:
	var out: Array = []
	for entry in state.get("movements", []):
		if typeof(entry) == TYPE_DICTIONARY and str((entry as Dictionary).get("type", "")) == type:
			out.append(entry)
	return out


func _event_types(events: Array) -> Array:
	var out: Array = []
	for event in events:
		if typeof(event) == TYPE_DICTIONARY:
			out.append(str((event as Dictionary).get("type", "")))
	return out


func _report_of_type(state: Dictionary, type: String) -> Dictionary:
	for entry in state.get("reports", []):
		if typeof(entry) == TYPE_DICTIONARY and str((entry as Dictionary).get("type", "")) == type:
			return entry
	return {}


func _sum(d: Dictionary) -> int:
	var total := 0
	for key in d.keys():
		total += int(d[key])
	return total


func _section(title: String) -> void:
	print("")
	print("-- %s" % title)


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] %s" % message)
	else:
		_failed += 1
		print("  [FAIL] %s" % message)
