extends SceneTree
## test_army.gd — Ordu: araştırma / eğitim / Altın Zırh / Kont testleri (A-ORDU).
##
## Çalıştırma (headless):
##   godot --headless --path game --script res://tests/test_army.gd
##
## Not: `--script` modunda autoload global tanımlayıcıları (GameData, GameConfig)
## **çözülmez**; veri sahne ağacı kökünden alınır ve modüller **yol ile preload**
## edilir (global sınıf önbelleği boş olabilir — docs/19 §7b).
##
## Doğrulananlar:
##  (a) Kışla 1 iken Okçu araştırılamaz, Kışla 5 iken araştırılır.
##  (b) Araştırma bedeli düşülür, `researched` işaretlenir, tekrar araştırılamaz.
##  (c) Eğitim vatandaş tüketir; yetersiz vatandaşta reddedilir.
##  (d) Eğitim süresi > 0 ve adetle artar.
##  (e) Dismiss vatandaşı geri verir; iptal (cancel) rezervi çözer.
##  (f) min_attack_units = 3 × Kışla seviyesi.
##  (g) Kont yalnızca Altın Zırh + Köşk ile eğitilir.
##  (h) `training` bonuslu köyde eğitim süresi %10 kısalır.
##
## Başarısızlıkta `quit(1)` ile çıkar (CI uyumlu).

const RE := preload("res://scripts/rules/RulesEngine.gd")
const VM := preload("res://scripts/model/VillageModel.gd")
const API := preload("res://scripts/sim/army/ArmyAPI.gd")
const SIM := preload("res://scripts/sim/army/ArmySimulator.gd")

var _passed := 0
var _failed := 0
var _fail_labels: Array = []
var _vid := 0


# =============================================================================
#  Altyapı
# =============================================================================

func _initialize() -> void:
	var gd := _game_data()
	if gd == null:
		print("FAIL: GameData autoload düğümü bulunamadı.")
		quit(1)
		return
	gd.load_all(true)
	var gc := _game_config()
	if gc != null:
		gc.set("speed", 1.0)  # testleri hızdan bağımsız yap

	print("=== Ordu Testleri (A-ORDU) ===")
	print("Veri: ", gd.summary())

	_test_research_gate()
	_test_research_flow()
	_test_training_citizens()
	_test_training_time()
	_test_dismiss_and_cancel()
	_test_min_attack_units()
	_test_count_and_gold_armour()
	_test_training_bonus()

	print("")
	print("==================== ÖZET ====================")
	print("PASS: %d   FAIL: %d" % [_passed, _failed])
	if _failed > 0:
		print("Başarısız testler:")
		for label in _fail_labels:
			print("  - ", label)
	print("==============================================")
	quit(1 if _failed > 0 else 0)


func _game_data() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("GameData")
	return null


func _game_config() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("GameConfig")
	return null


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("PASS: ", label)
	else:
		_failed += 1
		_fail_labels.append(label)
		print("FAIL: ", label)


func _check_eq(actual, expected, label: String) -> void:
	_check(actual == expected, "%s [beklenen=%s, gerçek=%s]" % [label, str(expected), str(actual)])


## Test köyü: Kışla + Değirmen seviyesi, kaynak ve araştırma durumu ayarlanır.
func _village(barracks_level: int, farm_level: int, res_each: int, researched: Dictionary = {}) -> Dictionary:
	_vid += 1
	var v := VM.create(_vid, "Test%d" % _vid, 10, 10, "Oyuncu", false)
	VM.set_building_level(v, "barracks", barracks_level)
	VM.set_building_level(v, "farm", farm_level)
	v["resources"] = {"wood": res_each, "stone": res_each, "iron": res_each}
	v["researched"] = researched.duplicate(true)
	return v


func _state_for(village: Dictionary) -> Dictionary:
	return {"villages": [village], "queues": []}


# =============================================================================
#  (a) Araştırma kapısı — Kışla seviyesi
# =============================================================================

func _test_research_gate() -> void:
	print("\n-- (a) Araştırma kapısı (Kışla seviyesi) --")
	var v := _village(1, 50, 1000000)
	_check(not API.can_research(v, "bow"), "Kışla 1: Okçu araştırılamaz")
	_check(API.research_block_reason(v, "bow") == "barracks_too_low", "Kışla 1 red nedeni = barracks_too_low")

	VM.set_building_level(v, "barracks", 4)
	_check(not API.can_research(v, "bow"), "Kışla 4: Okçu araştırılamaz (5 gerekir)")
	VM.set_building_level(v, "barracks", 5)
	_check(API.can_research(v, "bow"), "Kışla 5: Okçu araştırılabilir")

	# Araştırma durumu Kışla seviyesinden TÜRETİLMEZ
	_check(not RE.is_researched(v, "bow"), "Kışla yüksek olsa da researched boş → araştırılmamış")
	_check(not API.can_research(v, "snob"), "Kont araştırılamaz")
	_check(API.research_requirement("axe") == 2 and API.research_requirement("spy") == 4, "Baltacı=2, Casus=4")
	_check(API.research_requirement("heavy") == 16 and API.research_requirement("kata") == 25, "Kara Şövalye=16, Mancınık=25")


# =============================================================================
#  (b) Araştırma akışı — bedel + researched + tekrar yok
# =============================================================================

func _test_research_flow() -> void:
	print("\n-- (b) Araştırma akışı (bedel + researched) --")
	var v := _village(1, 50, 1000000)
	var st := _state_for(v)
	var cost := API.research_cost("spear")
	var before := {"wood": int(v["resources"]["wood"]), "stone": int(v["resources"]["stone"]), "iron": int(v["resources"]["iron"])}

	var r: Dictionary = API.start_research(v, "spear", st, 1000)
	_check(bool(r.get("ok", false)), "Silahtar araştırması başladı")
	_check_eq(int(v["resources"]["wood"]), before["wood"] - int(cost["wood"]), "Araştırma odunu düşüldü")
	_check_eq(int(v["resources"]["stone"]), before["stone"] - int(cost["stone"]), "Araştırma taşı düşüldü")
	_check_eq(int(v["resources"]["iron"]), before["iron"] - int(cost["iron"]), "Araştırma demiri düşüldü")
	_check_eq((st["queues"] as Array).size(), 1, "Araştırma kuyruğa eklendi")
	_check(not API.can_research(v, "spear", st), "Bekleyen araştırma varken tekrar başlatılamaz")
	_check(not RE.is_researched(v, "spear"), "Henüz tamamlanmadı → researched false")

	var finish := int(r["queue"]["finish_unix"])
	var ev0: Array = SIM.process_tick(st, finish - 1, 1.0)
	_check(ev0.is_empty() and not RE.is_researched(v, "spear"), "Süre dolmadan tamamlanmaz")

	var ev: Array = SIM.process_tick(st, finish, 1.0)
	_check(ev.size() == 1 and str(ev[0]["type"]) == "research_completed", "Süre dolunca research_completed olayı")
	_check(RE.is_researched(v, "spear"), "researched[spear] = true")
	_check((st["queues"] as Array).is_empty(), "Tamamlanan öğe kuyruktan çıktı")
	_check(not API.can_research(v, "spear", st), "Araştırılmış birim tekrar araştırılamaz")
	_check_eq(int(v["resources"]["wood"]), before["wood"] - int(cost["wood"]), "Tamamlanınca bedel iade edilmez")

	# Kaynak yetersizse araştırma reddedilir
	var poor := _village(1, 50, 10)
	_check(API.research_block_reason(poor, "sword") == "not_enough_resources", "Kaynak yok → araştırılamaz")


# =============================================================================
#  (c) Eğitim — vatandaş tüketimi ve reddi
# =============================================================================

func _test_training_citizens() -> void:
	print("\n-- (c) Eğitim vatandaş tüketimi --")
	var v := _village(1, 1, 1000000, {"spear": true, "heavy": true})
	var st := _state_for(v)
	_check(API.army_capacity(v) > 0, "Başlangıç ordu kapasitesi > 0")
	var cap0 := API.army_capacity(v)

	var r: Dictionary = API.start_training(v, "spear", 10, st, 1000)
	_check(bool(r.get("ok", false)), "10 Silahtar eğitimi başladı")
	_check_eq(API.army_capacity(v), cap0 - 10, "Eğitim vatandaşı rezerve eder (kapasite −10)")

	# Vatandaş yetersiz → reddedilir
	var big: Dictionary = API.start_training(v, "heavy", 1000, st, 1000)  # 1000 × 6 = 6000 vatandaş
	_check(not bool(big.get("ok", false)), "Aşırı kalabalık eğitim reddedildi")
	_check_eq(str(big.get("reason", "")), "not_enough_citizens", "Red nedeni = not_enough_citizens")

	# Kaynak yetersiz → reddedilir
	var poor := _village(1, 50, 5, {"spear": true})
	var st2 := _state_for(poor)
	var r2: Dictionary = API.start_training(poor, "spear", 10, st2, 1000)
	_check(not bool(r2.get("ok", false)), "Kaynak yetersiz → eğitim reddedildi")
	_check_eq(str(r2.get("reason", "")), "not_enough_resources", "Red nedeni = not_enough_resources")

	# Araştırılmamış birim eğitilemez
	var un := _village(5, 50, 1000000, {})
	_check_eq(API.training_block_reason(un, "bow", 1), "not_researched", "Araştırılmamış Okçu eğitilemez")


# =============================================================================
#  (d) Eğitim süresi
# =============================================================================

func _test_training_time() -> void:
	print("\n-- (d) Eğitim süresi --")
	var v := _village(5, 50, 1000000, {"spear": true})
	var t1 := API.training_seconds(v, "spear", 1)
	var t10 := API.training_seconds(v, "spear", 10)
	_check(t1 > 0.0, "Eğitim süresi > 0")
	_check(t10 > t1, "Eğitim süresi adetle artar")
	_check(API.research_seconds(v, "bow") > 0.0, "Araştırma süresi > 0")


# =============================================================================
#  (e) Dismiss (kov) + iptal (cancel)
# =============================================================================

func _test_dismiss_and_cancel() -> void:
	print("\n-- (e) Dismiss (kov) + iptal --")
	var v := _village(1, 50, 1000000, {"spear": true})
	v["units"]["spear"] = 10
	var free_before := API.army_capacity(v)
	_check_eq(API.dismiss(v, "spear", 4), 4, "4 Silahtar kovuldu")
	_check_eq(int(v["units"]["spear"]), 6, "Kalan Silahtar = 6")
	_check_eq(API.army_capacity(v), free_before + 4, "Kovulunca vatandaş geri gelir (+4)")
	_check_eq(API.dismiss(v, "spear", 999), 6, "Kalan kadarı kovulur (6)")
	_check_eq(int(v["units"]["spear"]), 0, "Ordu boşaldı")
	_check_eq(API.dismiss(v, "spear", 1), 0, "Birim yokken kovma = 0")

	# İptal: vatandaş rezervi çözülür
	var v2 := _village(1, 50, 1000000, {"spear": true})
	var st := _state_for(v2)
	var cap0 := API.army_capacity(v2)
	var r: Dictionary = API.start_training(v2, "spear", 5, st, 1000)
	_check_eq(API.army_capacity(v2), cap0 - 5, "Eğitim 5 vatandaş rezerve etti")
	_check(API.cancel_training(v2, int(r["queue"]["id"]), st), "Eğitim iptal edildi")
	_check_eq(API.army_capacity(v2), cap0, "İptalde vatandaş geri geldi")
	_check((st["queues"] as Array).is_empty(), "İptal edilen öğe kuyruktan çıktı")

	# İptal: araştırma kuyruğu
	var v3 := _village(1, 50, 1000000)
	var st3 := _state_for(v3)
	var rr: Dictionary = API.start_research(v3, "sword", st3, 1000)
	_check(API.cancel_research(v3, int(rr["queue"]["id"]), st3), "Araştırma iptal edildi")
	_check((st3["queues"] as Array).is_empty(), "Araştırma kuyruğu boşaldı")


# =============================================================================
#  (f) Min. saldırı birimi
# =============================================================================

func _test_min_attack_units() -> void:
	print("\n-- (f) Min. saldırı birimi --")
	var v := _village(7, 50, 1000000)
	_check_eq(API.min_attack_units(v), 21, "min_attack_units = 3 × Kışla(7) = 21")
	_check(API.can_attack(v, {"axe": 21}), "21 Baltacı → saldırı mümkün")
	_check(not API.can_attack(v, {"axe": 20}), "20 Baltacı → yetersiz")
	_check(not API.can_attack(v, {}), "Boş ordu → saldırı yok")

	VM.set_building_level(v, "barracks", 0)
	_check_eq(API.min_attack_units(v), 0, "Kışla 0 → min. saldırı birimi 0")


# =============================================================================
#  (g) Kont + Altın Zırh (Kuyumcu) + Köşk
# =============================================================================

func _test_count_and_gold_armour() -> void:
	print("\n-- (g) Kont + Altın Zırh --")
	var v := _village(1, 50, 100000000, {})
	VM.set_building_level(v, "snob", 0)
	VM.set_building_level(v, "smith", 0)
	var st := _state_for(v)

	_check(not API.can_research(v, "snob"), "Kont araştırılamaz")
	_check_eq(API.training_block_reason(v, "snob", 1, st), "residence_required", "Köşk yok → residence_required")
	_check(not API.produce_gold_armour(v, 1), "Kuyumcu yok → Altın Zırh üretilemez")

	VM.set_building_level(v, "snob", 1)
	_check_eq(API.training_block_reason(v, "snob", 1, st), "no_gold_armour", "Köşk var, Altın Zırh yok → no_gold_armour")
	_check(not bool(API.start_training(v, "snob", 1, st, 5000).get("ok", false)), "Altın Zırh'sız Kont eğitimi reddedildi")

	VM.set_building_level(v, "smith", 1)
	_check(API.produce_gold_armour(v, 1), "Kuyumcu 1 → Altın Zırh üretildi")
	_check_eq(API.gold_armour(v), 1, "Altın Zırh stoğu = 1")
	_check(API.can_train(v, "snob", 1, st), "Köşk 1 + Altın Zırh → Kont eğitilebilir")

	var r: Dictionary = API.start_training(v, "snob", 1, st, 5000)
	_check(bool(r.get("ok", false)), "Kont eğitimi başladı")
	_check_eq(API.gold_armour(v), 0, "Kont eğitimi Altın Zırh'ı tüketir")

	var ev: Array = SIM.process_tick(st, int(r["queue"]["finish_unix"]), 1.0)
	_check(ev.size() == 1 and str(ev[0]["type"]) == "training_completed", "Kont eğitimi tamamlandı")
	_check_eq(int(v["units"]["snob"]), 1, "Köyde 1 Kont var")


# =============================================================================
#  (h) Bonus köy (training) → süre %10 kısa
# =============================================================================

func _test_training_bonus() -> void:
	print("\n-- (h) Bonus köy (eğitim %10 hızlı) --")
	var a := _village(5, 50, 1000000, {"spear": true})
	var b := _village(5, 50, 1000000, {"spear": true})
	b["bonus_type"] = "training"

	var ta := API.training_seconds(a, "spear", 10)
	var tb := API.training_seconds(b, "spear", 10)
	_check(absf(tb / ta - 0.9) < 1e-9, "Bonus köyde eğitim süresi %10 kısa (×0.90)")
	_check(absf(API.research_seconds(b, "spear") - API.research_seconds(a, "spear")) < 1e-9, "Bonus araştırmayı etkilemez")

	var sa := _state_for(a)
	var sb := _state_for(b)
	var ra: Dictionary = API.start_training(a, "spear", 10, sa, 10000)
	var rb: Dictionary = API.start_training(b, "spear", 10, sb, 10000)
	var da := int(ra["queue"]["finish_unix"]) - 10000
	var db := int(rb["queue"]["finish_unix"]) - 10000
	_check(db < da, "Bonus köyde bitiş daha erken")
	_check(absf(float(db) / float(da) - 0.9) < 0.02, "Bitiş süresi oranı ≈ 0.90")
