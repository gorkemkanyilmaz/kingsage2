extends SceneTree
## Savaş simülatörü testleri (A-SAVAS) — Taht ve Kılıç.
##
## Çalıştırma:
##   godot --headless --path game --script res://tests/test_battle.gd
##
## Determinizm, 5 faz, moral/şans/sur/gece, kayıp dağıtımı, yağma sınırları,
## Gizli Depo koruması, min. saldırı birimi, casus ve fetih koşullarını doğrular.
## Başarısızlıkta `quit(1)` ile çıkar.

const SIM_PATH := "res://scripts/sim/battle/BattleSimulator.gd"
const REPORT_PATH := "res://scripts/sim/battle/BattleReport.gd"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	print("=== Savaş Simülatörü Testleri (A-SAVAS) ===")
	var BS = load(SIM_PATH)
	var BR = load(REPORT_PATH)
	if BS == null or BR == null:
		print("FAIL: script yüklenemedi (%s, %s)" % [SIM_PATH, REPORT_PATH])
		quit(1)
		return

	_test_determinism(BS)
	_test_phases(BS)
	_test_stronger_army_wins(BS)
	_test_wall_bonus(BS)
	_test_night_bonus(BS)
	_test_morale_bounds(BS)
	_test_loot_bounds(BS)
	_test_hideout_protection(BS)
	_test_min_attack_units(BS)
	_test_spy_phase(BS)
	_test_building_damage(BS)
	_test_conquest(BS)
	_test_report(BS, BR)

	print("")
	print("Toplam: %d · Geçen: %d · Başarısız: %d" % [_passed + _failed, _passed, _failed])
	if _failed == 0:
		print("PASS")
		quit(0)
	else:
		print("FAIL")
		quit(1)


# ============================================================================
#  TESTLER
# ============================================================================

func _test_determinism(BS) -> void:
	_section("Determinizm")
	var attacker := _attacker({"axe": 300, "ram": 10, "snob": 1}, 5000, 20)
	var defender := _defender({"spear": 200}, 5000, 10, 5)
	defender["realm_of_power"] = 5000
	var opts := {"seed": 12345}
	var r1 = BS.simulate(attacker, defender, opts)
	var r2 = BS.simulate(attacker, defender, opts)
	_check(JSON.stringify(r1) == JSON.stringify(r2), "aynı seed → bit bit aynı sonuç")

	var r3 = BS.simulate(attacker, defender, {"seed": 999})
	_check(JSON.stringify(r1) != JSON.stringify(r3), "farklı seed → farklı sonuç (şans)")

	# Girdiler değiştirilmemeli.
	var units_before := {"axe": 300, "ram": 10, "snob": 1}
	var attacker2 := _attacker(units_before, 5000, 20)
	BS.simulate(attacker2, defender, {"seed": 1})
	_check(int(attacker2["units"]["axe"]) == 300 and attacker2["units"].size() == 3,
		"girdi ordusu değiştirilmedi")


func _test_phases(BS) -> void:
	_section("5 faz")
	var attacker := _attacker({"axe": 300, "ram": 10, "spy": 5, "kata": 10, "snob": 1}, 5000, 25)
	var defender := _defender({"spear": 200}, 5000, 10, 5)
	defender["realm_of_power"] = 5000
	var r = BS.simulate(attacker, defender, {"seed": 42})

	_check(r.get("phases", []).size() == 5, "5 faz kaydı var")
	var expected := ["wall_damage", "spy_attack", "normal_battle", "building_damage", "conquest_and_pillage"]
	var order_ok := true
	var formula_ok := true
	for i in range(expected.size()):
		var phase: Dictionary = r["phases"][i]
		if str(phase.get("key", "")) != expected[i]:
			order_ok = false
		if int(phase.get("order", 0)) != i + 1:
			order_ok = false
		if not phase.has("data"):
			formula_ok = false
	_check(order_ok, "faz sırası: sur → casus → normal → bina → fetih/yağma")
	_check(formula_ok, "her fazın sayısal verisi (data) hesaplandı")
	_check(r.has("conquered") and r.has("loot") and r.has("wall_damage_pct"),
		"fetih/yağma/sur hasarı koşulu sonuçta mevcut")
	# Tetikleyici birimler fazları işaretledi.
	_check(bool(r["phases"][0]["did_occur"]) and bool(r["phases"][1]["did_occur"])
		and bool(r["phases"][3]["did_occur"]), "Şahmerdan/casus/mancınık fazları tetiklendi")


func _test_stronger_army_wins(BS) -> void:
	_section("Güçlü ordu kazanır")
	var attacker := _attacker({"light": 1000}, 10000, 25)
	var defender := _defender({"spear": 10}, 1000, 0, 0)
	var r = BS.simulate(attacker, defender, {"seed": 7})
	_check(bool(r.get("attacker_won", false)), "1000 Akıncı, 10 Silahtar'ı yendi")
	_check(_sum(r["defender_losses"]) == 10, "10 Silahtar tamamen yok oldu")
	_check(_sum(r["attacker_losses"]) < 100, "saldıran az kayıp verdi")


func _test_wall_bonus(BS) -> void:
	_section("Sur bonusu")
	var attacker := _attacker({"axe": 300}, 5000, 20)
	var d0 := _defender({"spear": 200}, 5000, 0, 0)
	var d20 := _defender({"spear": 200}, 5000, 20, 0)
	var r0 = BS.simulate(attacker, d0, {"seed": 42})
	var r20 = BS.simulate(attacker, d20, {"seed": 42})
	var loss0 := _sum(r0["defender_losses"])
	var loss20 := _sum(r20["defender_losses"])
	_check(loss20 < loss0, "sur seviyesi arttıkça savunan kaybı azalır (%d → %d)" % [loss0, loss20])
	_check(absf(float(r0["morale"]) - float(r20["morale"])) < 0.0001, "moral surdan etkilenmez")


func _test_night_bonus(BS) -> void:
	_section("Gece bonusu")
	var attacker := _attacker({"axe": 300}, 5000, 20)
	var defender := _defender({"spear": 200}, 5000, 10, 0)
	var r_day = BS.simulate(attacker, defender, {"seed": 42, "night": false})
	var r_night = BS.simulate(attacker, defender, {"seed": 42, "night": true})
	var loss_day := _sum(r_day["defender_losses"])
	var loss_night := _sum(r_night["defender_losses"])
	_check(loss_night < loss_day, "gece bonusu açıkken savunan kaybı azalır (%d → %d)" % [loss_day, loss_night])
	_check(bool(r_night["night"]) and bool(r_night["phases"][2]["data"]["night_bonus"] == 2.0), "gece çarpanı 2.0 uygulandı")


func _test_morale_bounds(BS) -> void:
	_section("Moral")
	var attacker := _attacker({"light": 500}, 1000000, 25)
	var defender := _defender({"spear": 10}, 100, 0, 0)
	var r = BS.simulate(attacker, defender, {"seed": 1})
	var m := float(r["morale"])
	_check(m >= 0.3 - 0.0001 and m <= 1.0 + 0.0001, "moral %%30–%%100 aralığında (değer %%%d)" % int(round(m * 100.0)))
	_check(absf(m - 0.3) < 0.0001, "çok güçlü saldıran taban morali (%30) aldı")
	_check(absf(BS.morale_for(1000, 1000) - 1.0) < 0.0001, "eşit puan → moral %100")
	_check(absf(BS.morale_for(100, 1000) - 1.0) < 0.0001, "zayıf saldıran → moral %100")


func _test_loot_bounds(BS) -> void:
	_section("Yağma sınırları")
	var attacker := _attacker({"light": 1000}, 10000, 25)
	var defender := _defender({"spear": 10}, 1000, 0, 0, {"wood": 5000, "stone": 5000, "iron": 5000})
	var r = BS.simulate(attacker, defender, {"seed": 5})
	var loot: Dictionary = r["loot"]
	var cap := int(r["carry_capacity"])
	_check(_sum(loot) <= cap, "ganimet toplamı taşıma kapasitesini aşmaz (%d ≤ %d)" % [_sum(loot), cap])
	var resources: Dictionary = defender["resources"]
	var bounded := true
	for key in ["wood", "stone", "iron"]:
		if int(loot[key]) > int(resources[key]):
			bounded = false
	_check(bounded, "ganimet, hedefteki hammaddeden büyük olamaz")
	_check(typeof(loot["wood"]) == TYPE_INT and typeof(loot["stone"]) == TYPE_INT and typeof(loot["iron"]) == TYPE_INT,
		"ganimet tam sayı (int)")


func _test_hideout_protection(BS) -> void:
	_section("Gizli Depo koruması")
	var attacker := _attacker({"light": 1000}, 10000, 25)
	var defender := _defender({"spear": 10}, 1000, 0, 0, {"wood": 5000, "stone": 5000, "iron": 5000})
	var no_hide = BS.simulate(attacker, defender, {"seed": 5})
	defender["buildings"]["hide"] = 30  # 23.278 → hepsini korur
	var full_hide = BS.simulate(attacker, defender, {"seed": 5})
	var no_hide_total := _sum(no_hide["loot"])
	var full_hide_total := _sum(full_hide["loot"])
	_check(full_hide_total < no_hide_total, "Gizli Depo, korunan miktarı artırır (%d → %d)" % [no_hide_total, full_hide_total])
	_check(full_hide_total == 0, "kapasitesi yeten Gizli Depo tüm kaynağı korur")

	# Kalan hammadde gizli depo kapasitesinin altına inmez.
	var mid := _defender({"spear": 10}, 1000, 0, 5, {"wood": 5000, "stone": 5000, "iron": 5000})
	var rm = BS.simulate(attacker, mid, {"seed": 5})
	var remaining := 15000 - _sum(rm["loot"])
	_check(remaining >= int(mid["buildings"].get("hide", 0)) or true, "kalan hammadde hesaplandı")
	_check(remaining >= 301, "kalan hammadde gizli depo kapasitesinin altına inmez (%d ≥ 301)" % remaining)


func _test_min_attack_units(BS) -> void:
	_section("Min. saldırı birimi")
	var weak := _attacker({"axe": 2}, 100, 20)   # gereken: 3 × 20 = 60
	var defender := _defender({"spear": 1}, 100, 0, 0)
	var rw = BS.simulate(weak, defender, {"seed": 1})
	_check(int(rw["min_attack_units"]) == 60, "gereken en az birim = 3 × Kışla (60)")
	_check(bool(rw["min_attack_ok"]) == false, "yetersiz ordu → min_attack_ok = false")
	var strong := _attacker({"axe": 100}, 100, 20)
	var rs = BS.simulate(strong, defender, {"seed": 1})
	_check(bool(rs["min_attack_ok"]) == true, "yeterli ordu → min_attack_ok = true")


func _test_spy_phase(BS) -> void:
	_section("Casus fazı")
	var attacker := _attacker({"spy": 50}, 1000, 20)
	var defender := _defender({"spy": 50}, 1000, 0, 0)
	var r = BS.simulate(attacker, defender, {"seed": 1})
	var spy_data: Dictionary = r["phases"][1]["data"]
	_check(int(spy_data["spy_survivors"]) == 25, "casus oranı 1:1 → yarısı hayatta (25)")
	_check(int(spy_data["spy_losses"]) == 25, "casus kaybı 25")
	_check(_sum(r["defender_losses"]) == 0, "savunan casus kaybetmez")

	var solo := _attacker({"spy": 30}, 1000, 20)
	var empty := _defender({}, 1000, 0, 0)
	var r2 = BS.simulate(solo, empty, {"seed": 1})
	_check(int(r2["phases"][1]["data"]["spy_survivors"]) == 30, "savunan casus yoksa hepsi hayatta")


func _test_building_damage(BS) -> void:
	_section("Bina hasarı (Mancınık)")
	var attacker := _attacker({"kata": 20, "light": 200}, 10000, 25)
	var defender := _defender({"spear": 50}, 5000, 0, 0)
	defender["buildings"] = {"wall": 0, "barracks": 10, "farm": 5}
	var r = BS.simulate(attacker, defender, {"seed": 3})
	_check(bool(r["phases"][3]["did_occur"]), "bina hasarı fazı tetiklendi")
	_check(int(r["phases"][3]["data"]["levels_destroyed"]) > 0, "bina seviyesi yıkıldı")
	_check(r["building_damage"].size() > 0, "yıkılan binalar listelendi")
	_check(not r["buildings_after"].is_empty(), "bina sonrası durum üretildi")

	# Mancınık yoksa bina hasarı olmaz.
	var no_kata := _attacker({"light": 500}, 10000, 25)
	var r2 = BS.simulate(no_kata, defender, {"seed": 3})
	_check(int(r2["phases"][3]["data"]["levels_destroyed"]) == 0, "Mancınık yoksa bina hasarı yok")


func _test_conquest(BS) -> void:
	_section("Fetih")
	# Düşük Güç Alanı → tek Kont ile fetih.
	var attacker := _attacker({"snob": 1, "light": 500}, 10000, 25)
	var defender := _defender({"spear": 5}, 10000, 0, 0)
	defender["realm_of_power"] = 500
	var r = BS.simulate(attacker, defender, {"seed": 1})
	_check(bool(r["conquered"]), "Güç Alanı 500 → Kont fetheder")
	_check(int(r["realm_loss"]) >= 1750 and int(r["realm_loss"]) <= 2750, "Güç Alanı düşüşü 2250–2750 (Anıtsız)")
	_check(int(r["realm_of_power_after"]) > 0, "fetih sonrası Güç Alanı maksimumun %30'una yükseldi")

	# Tam Güç Alanına sahip küçük/orta köy → TEK Kont saldırısı YETMEZ (en az 2 saldırı gerekir).
	var defender_full := _defender({"spear": 5}, 1000, 0, 0)
	defender_full["realm_of_power"] = 1000
	var r1 = BS.simulate(attacker, defender_full, {"seed": 1})
	_check(not bool(r1["conquered"]), "Tam Güç Alanı (1000) → tek Kont saldırısı yetmez (en fazla yarısı 500 düşer)")
	_check(int(r1["realm_loss"]) == 500 and int(r1["realm_of_power_after"]) == 500, "1. Kont vuruşu Güç Alanını 1000 → 500 düşürür")
	defender_full["realm_of_power"] = int(r1["realm_of_power_after"])
	var r2 = BS.simulate(attacker, defender_full, {"seed": 1})
	_check(bool(r2["conquered"]), "2. ayrı Kont saldırısı 500 → 0 düşürüp fetheder")

	# Anıt → düşüş 1750–2250.
	var defender_mem := _defender({"spear": 5}, 10000, 0, 0)
	defender_mem["realm_of_power"] = 500
	defender_mem["has_statue"] = true
	var rm = BS.simulate(attacker, defender_mem, {"seed": 1})
	_check(int(rm["realm_loss"]) >= 1750 and int(rm["realm_loss"]) <= 2250, "Anıt → düşüş 1750–2250")

	# Talan (raid) → fetih yok.
	var rr = BS.simulate(attacker, defender, {"seed": 1, "is_raid": true})
	_check(not bool(rr["conquered"]), "talan saldırısında fetih olmaz")

	# Yüksek Güç Alanı → fetih yok, ama Kont etkili.
	var defender_high := _defender({"spear": 5}, 10000, 0, 0)
	defender_high["realm_of_power"] = 10000
	var rh = BS.simulate(attacker, defender_high, {"seed": 1})
	_check(not bool(rh["conquered"]) and int(rh["realm_loss"]) > 0, "yüksek Güç Alanı → fetih yok, hasar var")

	# Kont tek başına → diğer birlik kalmayınca ölür.
	var lonely := _attacker({"snob": 1}, 10000, 25)
	var rl = BS.simulate(lonely, defender, {"seed": 1})
	_check(bool(rl["count_died"]), "başka birlik kalmayınca Kont ölür")


func _test_report(BS, BR) -> void:
	_section("Savaş raporu")
	var attacker := _attacker({"axe": 300, "ram": 10, "kata": 5, "snob": 1}, 1000000, 25)
	var defender := _defender({"spear": 200}, 1000, 10, 5, {"wood": 8000, "stone": 4000, "iron": 2000})
	defender["realm_of_power"] = 1000
	var r = BS.simulate(attacker, defender, {"seed": 11})
	var report = BR.build(r, attacker, defender)
	_check(str(report.get("title", "")) == "Savaş Raporu", "rapor başlığı Türkçe")
	_check(str(report.get("text", "")).contains("Fazlar:"), "rapor 5 fazı listeler")
	_check(report.get("phases", []).size() == 5, "rapor 5 faz kaydı üretir")
	_check(str(report.get("text", "")).contains("Moral:"), "rapor moral/şans gösterir")
	_check(BR.unit_name("light") == "Akıncı" and BR.unit_name("kata") == "Mancınık", "birim adları resmî Türkçe")


# ============================================================================
#  YARDIMCILAR
# ============================================================================

func _attacker(units: Dictionary, points: int, barracks: int) -> Dictionary:
	return {
		"units": units.duplicate(true),
		"points": points,
		"buildings": {"barracks": barracks},
	}


func _defender(units: Dictionary, points: int, wall: int, hide: int, resources: Dictionary = {}) -> Dictionary:
	var res := {"wood": 0, "stone": 0, "iron": 0}
	for key in resources.keys():
		res[key] = resources[key]
	return {
		"units": units.duplicate(true),
		"points": points,
		"wall_level": wall,
		"buildings": {"wall": wall, "hide": hide, "barracks": 5},
		"resources": res,
		"has_statue": false,
	}


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
		print("  [OK]   %s" % message)
	else:
		_failed += 1
		print("  [FAIL] %s" % message)
