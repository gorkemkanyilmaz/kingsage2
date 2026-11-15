extends SceneTree
## test_world_manager.gd — Çoklu Dünya ve Kalıcı Dünya Sistemi Testi.

const WorldManagerScript := preload("res://autoload/WorldManager.gd")
const SaveManagerScript := preload("res://autoload/SaveManager.gd")
const GameStateScript := preload("res://autoload/GameState.gd")
const GameConfigScript := preload("res://autoload/GameConfig.gd")
const ArmySimScript := preload("res://scripts/sim/army/ArmySimulator.gd")

var _pass_count := 0
var _fail_count := 0


func _init() -> void:
	print("==================================================")
	print("🧪 DÜNYA SİSTEMİ & OFFLINE SİMÜLASYON TESTLERİ BAŞLIYOR")
	print("==================================================")

	var gc = GameConfigScript.new()
	gc.name = "GameConfig"
	root.add_child(gc)

	var gs = GameStateScript.new()
	gs.name = "GameState"
	root.add_child(gs)

	var sm = SaveManagerScript.new()
	sm.name = "SaveManager"
	root.add_child(sm)

	var wm = WorldManagerScript.new()
	wm.name = "WorldManager"
	root.add_child(wm)

	# 1. Temiz sıfırlama testi
	wm.reset_all_worlds()
	var metas = wm.get_worlds_meta()
	_assert(metas.size() == 10, "10 adet dünya meta bilgisi mevcut")
	_assert(metas[0]["is_active"] == true, "Dünya 1 varsayılan olarak AKTİF")
	_assert(metas[0]["seed"] == 1001, "Dünya 1 tohumu 1001 (sabit)")
	_assert(metas[0]["bot_count"] == 50, "Dünya 1 tam 50 bot ile başlar")
	_assert(metas[0]["max_real_players"] == 100, "Dünya 1 kapasitesi 100 gerçek oyuncu")

	for i in range(1, 10):
		_assert(metas[i]["is_active"] == false, "Dünya %d varsayılan olarak PASİF / KAPALI" % (i + 1))

	# 2. Dünya 1'deki bot sayısı kontrolü
	var w1_data = wm.load_world_dict(1)
	_assert(not w1_data.is_empty(), "Dünya 1 kayıt dosyası başarıyla yüklendi")
	var villages = w1_data["state"]["villages"]
	var bot_villages := 0
	for v in villages:
		if bool(v.get("is_bot", false)):
			bot_villages += 1
	_assert(bot_villages == 50, "Dünya 1 içerisinde tam 50 adet bot köyü mevcut (%d)" % bot_villages)

	# 3. Oyuncu katılım öncesi ve sonrası durum kontrolü
	var test_player := "Lord Test"
	_assert(not wm.has_player_village(1, test_player), "Oyuncu henüz katılmadan önce has_player_village = false (DÜNYAYA KATIL)")

	var join_ok = wm.join_world(1, test_player)
	_assert(join_ok, "Oyuncu Dünya 1'e başarıyla katıldı")
	_assert(wm.has_player_village(1, test_player), "Oyuncu katıldıktan sonra has_player_village = true (DÜNYAYA DEVAM ET)")

	var p_villages = gs.get_player_villages()
	_assert(p_villages.size() == 1, "Oyuncunun 1 adet başlangıç köyü oluşturuldu")
	_assert(p_villages[0]["owner"] == test_player, "Köyün sahibi doğru ayarlandı (%s)" % test_player)
	_assert(not bool(p_villages[0]["is_bot"]), "Oyuncu köyü bot değildir")

	# 4. Fetih durumu (tüm köyleri kaybedilirse DÜNYAYA KATIL'a dönmeli)
	var active_vid = gs.active_village_id
	p_villages[0]["owner"] = "Düşman Bot" # Simüle fetih
	_assert(not wm.has_player_village(1, test_player), "Köyleri fethedilen oyuncu için has_player_village = false (Tekrar DÜNYAYA KATIL)")

	# Tekrar katılabilmeli (yeni köy açabilmeli)
	var rejoin_ok = wm.join_world(1, test_player)
	_assert(rejoin_ok, "Tüm köylerini kaybeden oyuncu tekrar katılarak yeni köy açabildi")
	_assert(wm.has_player_village(1, test_player), "Yeniden katılan oyuncunun tekrar yaşayan köyü var")

	# 5. Offline telafi testi (10 dakikalık asker eğitimi)
	var now = int(Time.get_unix_time_from_system())
	var v_dict = gs.get_active_village()
	var initial_spear = int(v_dict["units"].get("spear", 0))

	# 600 saniye sonra (10 dakika) bitecek bir mızraklı eğitimi kuyruğa ekle
	gs.queues.append({
		"type": "train",
		"village_id": gs.active_village_id,
		"key": "spear",
		"count": 50,
		"finish_unix": now - 10 # 10 saniye önce bitti simülasyonu
	})

	# Offline catchup uygula
	sm._apply_offline_catchup(gs, now - 600)
	var after_v_dict = gs.get_active_village()
	var after_spear = int(after_v_dict["units"].get("spear", 0))
	_assert(after_spear == initial_spear + 50, "10 dakika offline kalan oyuncunun asker eğitimi hazır (%d -> %d)" % [initial_spear, after_spear])

	# 6. Kapasite dolunca Dünya 2'nin açılması testi
	var w1_meta = wm.get_world_meta(1)
	for p_idx in range(1, 101):
		var dummy_p := "Player_%d" % p_idx
		if not (dummy_p in w1_data["registered_real_players"]):
			w1_data["registered_real_players"].append(dummy_p)
	w1_meta["registered_real_players"] = 100
	wm._save_meta()
	wm._unlock_next_world(2)

	var w2_meta = wm.get_world_meta(2)
	_assert(w2_meta["is_active"] == true, "Dünya 1 100 oyuncuya ulaşınca Dünya 2 AKTİF oldu")
	_assert(w2_meta["bot_count"] == 50, "Dünya 2 de 50 bot standardı ile başladı")
	var w2_data = wm.load_world_dict(2)
	_assert(not w2_data.is_empty(), "Dünya 2 dosyası başarıyla üretildi")

	# 7. Oyuncu bazlı ilk 7 gün 2x başlangıç hızı izolasyonu
	wm.reset_all_worlds()
	var boost_now := int(Time.get_unix_time_from_system())
	var old_world_created := boost_now - (20 * 86400)
	var old_player_start := boost_now - (10 * 86400)

	var w1_boost := wm.load_world_dict(1)
	w1_boost["created_unix"] = old_world_created
	w1_boost["state"]["world"]["created_unix"] = old_world_created
	wm.save_world_dict(1, w1_boost)

	_assert(wm.join_world(1, "Lord Eski", 80, 80), "Eski oyuncu (Lord Eski) Dünya 1'e katıldı")
	var w1_old := wm.load_world_dict(1)
	var old_state: Dictionary = w1_old["state"]
	var old_w: Dictionary = old_state["world"]
	old_w["created_unix"] = old_world_created
	old_w["player_joined_unix"] = old_player_start
	old_w["starter_boost_until_unix"] = old_player_start + (7 * 86400)
	if typeof(old_w.get("player_starter_boost")) != TYPE_DICTIONARY:
		old_w["player_starter_boost"] = {}
	old_w["player_starter_boost"]["Lord Eski"] = {
		"created_unix": old_player_start,
		"starter_boost_until_unix": old_player_start + (7 * 86400),
	}
	for v in old_state.get("villages", []):
		if typeof(v) == TYPE_DICTIONARY and str(v.get("owner", "")) == "Lord Eski":
			v["created_unix"] = old_player_start
			v["starter_boost_until_unix"] = old_player_start + (7 * 86400)
			v["protection_until_unix"] = old_player_start + (15 * 86400)
	wm.save_world_dict(1, w1_old)

	_assert(wm.join_world(1, "Lord Yeni", 120, 120), "Yeni oyuncu (Lord Yeni) 20 günlük Dünya 1'e katıldı")
	_assert(is_equal_approx(gc.speed, 2.0), "Yeni oyuncu için speed = 2.0 (sunucu 20 günlük olsa bile)")
	_assert(is_equal_approx(gc.unit_speed, 2.0), "Yeni oyuncu için unit_speed = 2.0")
	_assert(gc.is_starter_boost_active(gs.world), "Yeni oyuncu için starter_boost aktif = true")

	_assert(wm.enter_world(1, "Lord Eski"), "Eski oyuncu (Lord Eski) dünyaya yeniden girdi")
	_assert(is_equal_approx(gc.speed, 1.0), "10 gün önce başlayan eski oyuncu için speed = 1.0 (süresi dolmuş)")
	_assert(is_equal_approx(gc.unit_speed, 1.0), "10 gün önce başlayan eski oyuncu için unit_speed = 1.0")
	_assert(not gc.is_starter_boost_active(gs.world), "Eski oyuncu için starter_boost aktif = false")

	_assert(wm.enter_world(1, "Lord Yeni"), "Yeni oyuncu (Lord Yeni) dünyaya yeniden girdi")
	_assert(is_equal_approx(gc.speed, 2.0), "Yeni oyuncu tekrar girdiğinde speed = 2.0 korundu")
	_assert(is_equal_approx(gc.unit_speed, 2.0), "Yeni oyuncu tekrar girdiğinde unit_speed = 2.0 korundu")
	_assert(gc.is_starter_boost_active(gs.world), "Yeni oyuncu tekrar girdiğinde starter_boost hala aktif = true")

	print("\n==================================================")
	print("SONUÇLAR: %d PASS, %d FAIL" % [_pass_count, _fail_count])
	print("==================================================")

	quit(0 if _fail_count == 0 else 1)


func _assert(cond: bool, msg: String) -> void:
	if cond:
		_pass_count += 1
		print("  ✅ PASS: %s" % msg)
	else:
		_fail_count += 1
		print("  ❌ FAIL: %s" % msg)
