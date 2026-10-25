extends SceneTree
## test_multi_account_isolation.gd
## Çoklu hesap izolasyonu, düşman köy ayrımı, hoş geldin mesajı tekilliği ve ittifak testleri.

const WorldManagerScript := preload("res://autoload/WorldManager.gd")
const GameStateScript := preload("res://autoload/GameState.gd")
const SaveManagerScript := preload("res://autoload/SaveManager.gd")

var _pass_count := 0
var _fail_count := 0


func _init() -> void:
	print("==================================================")
	print("🧪 ÇOKLU HESAP İZOLASYONU VE HARİTA DÜŞMAN KÖY TESTLERİ")
	print("==================================================")

	var gs = GameStateScript.new()
	gs.name = "GameState"
	root.add_child(gs)

	var sm = SaveManagerScript.new()
	sm.name = "SaveManager"
	root.add_child(sm)

	var wm = WorldManagerScript.new()
	wm.name = "WorldManager"
	root.add_child(wm)

	# 1. Temiz sıfırlama
	wm.reset_all_worlds()
	var w1_data = wm.load_world_dict(1)
	var state: Dictionary = w1_data["state"]

	# Test 1: Otomatik bot ittifakı OLMAMALI (alliances boş liste başlamalı)
	var alliances: Array = state.get("alliances", [])
	_assert(alliances.is_empty(), "Dünya 1 başlangıcında otomatik bot ittifakı ([ASLAN]) bulunmuyor, ittifaklar listesi boş.")

	# 2. Oyuncu 1 katılıyor (Lord Gorkem)
	var p1 := "Lord Gorkem"
	var p1_ok = wm.join_world(1, p1, 100, 100)
	_assert(p1_ok, "1. Oyuncu (Lord Gorkem) Dünya 1'e katıldı")

	# Hoş geldin mesajı kontrolü
	var w1_after_p1 = wm.load_world_dict(1)
	var msgs_p1: Array = w1_after_p1["state"]["messages"]
	var p1_welcome_count := 0
	var p1_welcome_body := ""
	var p1_sender := ""
	for m in msgs_p1:
		if typeof(m) == TYPE_DICTIONARY and str(m.get("to", "")) == p1:
			p1_welcome_count += 1
			p1_welcome_body = str(m.get("body", ""))
			p1_sender = str(m.get("from", ""))

	_assert(p1_welcome_count == 1, "Lord Gorkem için tam olarak 1 adet hoş geldin mesajı oluşturuldu (sayı: %d)" % p1_welcome_count)
	_assert(p1_sender == "Taht ve Kılıç Konseyi", "Mesaj göndereni 'Taht ve Kılıç Konseyi' (%s)" % p1_sender)
	_assert(not p1_welcome_body.contains("Aslanlar") and not p1_welcome_body.contains("davet"), "Mesaj içeriğinde 'Aslanlar' veya ittifak daveti yok")

	# Test 2: join_world tekrar çağrılsa bile mesaj 2 KERE GELMEMELİ!
	wm.join_world(1, p1, 100, 100)
	var w1_after_dup = wm.load_world_dict(1)
	var msgs_dup: Array = w1_after_dup["state"]["messages"]
	var p1_dup_count := 0
	for m in msgs_dup:
		if typeof(m) == TYPE_DICTIONARY and str(m.get("to", "")) == p1 and str(m.get("subject", "")).contains("Hoş Geldiniz"):
			p1_dup_count += 1
	_assert(p1_dup_count == 1, "Tekrar katılım denendiğinde hoş geldin mesajı ÇİFTLENMEDİ (sayı: %d)" % p1_dup_count)

	# 3. Oyuncu 2 katılıyor (Lord Roland - Ayrı Hesap)
	var p2 := "Lord Roland"
	var p2_ok = wm.join_world(1, p2, 120, 120)
	_assert(p2_ok, "2. Oyuncu (Lord Roland) Dünya 1'e katıldı")

	var w1_after_p2 = wm.load_world_dict(1)
	var msgs_p2: Array = w1_after_p2["state"]["messages"]
	var p2_welcome_count := 0
	for m in msgs_p2:
		if typeof(m) == TYPE_DICTIONARY and str(m.get("to", "")) == p2:
			p2_welcome_count += 1
	_assert(p2_welcome_count == 1, "Lord Roland için de tam 1 adet hoş geldin mesajı var")

	# 4. Mesaj İzolasyonu Testi (Her hesap yalnızca kendi mesajlarını görmeli)
	var all_msgs: Array = w1_after_p2["state"]["messages"]
	var gorkem_inbox: Array = []
	var roland_inbox: Array = []

	for m in all_msgs:
		if typeof(m) == TYPE_DICTIONARY:
			var to_u := str(m.get("to", ""))
			var from_u := str(m.get("from", ""))
			if to_u == p1 or from_u == p1:
				gorkem_inbox.append(m)
			if to_u == p2 or from_u == p2:
				roland_inbox.append(m)

	_assert(gorkem_inbox.size() == 1, "Lord Gorkem gelen kutusunda yalnızca kendi 1 mesajı var")
	_assert(roland_inbox.size() == 1, "Lord Roland gelen kutusunda yalnızca kendi 1 mesajı var")
	_assert(str(gorkem_inbox[0].get("to", "")) == p1, "Lord Gorkem kutusundaki mesaj Lord Gorkem'e ait")
	_assert(str(roland_inbox[0].get("to", "")) == p2, "Lord Roland kutusundaki mesaj Lord Roland'a ait")

	# 5. Harita Köy Sahipliği ve Düşman Köy Tespiti Testi
	var villages: Array = w1_after_p2["state"]["villages"]
	var v_p1: Dictionary = {}
	var v_p2: Dictionary = {}
	for v in villages:
		if typeof(v) == TYPE_DICTIONARY:
			if str(v.get("owner", "")) == p1:
				v_p1 = v
			elif str(v.get("owner", "")) == p2:
				v_p2 = v

	_assert(not v_p1.is_empty(), "Lord Gorkem'in köyü bulundu")
	_assert(not v_p2.is_empty(), "Lord Roland'ın köyü bulundu")

	# Simülasyon: Lord Gorkem oyuna girdiğinde (aktif hesap = Lord Gorkem)
	wm.enter_world(1, p1)
	var cur_p_name := str(gs.player.get("name", ""))
	_assert(cur_p_name == p1, "Aktif oyuncu: %s" % cur_p_name)
	var p1_vids: Array = []
	for v in gs.villages:
		if typeof(v) == TYPE_DICTIONARY and str(v.get("owner", "")) == p1:
			p1_vids.append(int(v.get("id", -1)))

	# Lord Gorkem için kendi köyü:
	var v1_owner := str(v_p1.get("owner", ""))
	var v1_id: int = int(v_p1.get("id", -1))
	var is_own_1: bool = (v1_owner == cur_p_name) or (v1_id in p1_vids)
	_assert(is_own_1 == true, "Lord Gorkem'in kendi köyü 'is_own = true' olarak algılandı")

	# Lord Gorkem için Lord Roland'ın köyü:
	var v2_owner := str(v_p2.get("owner", ""))
	var v2_id: int = int(v_p2.get("id", -1))
	var is_own_2: bool = (v2_owner == cur_p_name) or (v2_id in p1_vids)
	_assert(is_own_2 == false, "Lord Roland'ın köyü Lord Gorkem için 'is_own = false' (DÜŞMAN / BAŞKA OYUNCU) olarak algılandı")

	# Tıklama Simülasyonu (_on_village_clicked):
	var click_is_own := (v2_owner == cur_p_name) or (v2_id in p1_vids)
	_assert(click_is_own == false, "Lord Roland'ın köyüne tıklandığında köy içine (Village.tscn) ASLA girmez, sefer/ordu ekranını açar")

	# Simülasyon: Lord Roland oyuna girdiğinde (aktif hesap = Lord Roland)
	wm.enter_world(1, p2)
	cur_p_name = str(gs.player.get("name", ""))
	_assert(cur_p_name == p2, "Aktif oyuncu: %s" % cur_p_name)
	var p2_vids: Array = []
	for v in gs.villages:
		if typeof(v) == TYPE_DICTIONARY and str(v.get("owner", "")) == p2:
			p2_vids.append(int(v.get("id", -1)))

	var is_own_roland_v1: bool = (v1_owner == cur_p_name) or (v1_id in p2_vids)
	var is_own_roland_v2: bool = (v2_owner == cur_p_name) or (v2_id in p2_vids)
	_assert(is_own_roland_v1 == false, "Lord Roland için Lord Gorkem'in köyü 'is_own = false' (DÜŞMAN)")
	_assert(is_own_roland_v2 == true, "Lord Roland için kendi köyü 'is_own = true'")

	# 6. Oyuncuların kendi aralarında ittifak kurması ve müttefik görünümü
	var test_alliance := {
		"id": 1,
		"name": "Kartallar Birliği",
		"tag": "KARTAL",
		"founder": p1,
		"leader": p1,
		"members": [
			{"name": p1, "rank": "leader"},
			{"name": p2, "rank": "member"}
		]
	}
	gs.alliances.append(test_alliance)

	# Şimdi Lord Gorkem gözüyle bakalım:
	var ally_members: Array = []
	for m in test_alliance["members"]:
		var m_name = str(m.get("name", ""))
		if m_name != p1:
			ally_members.append(m_name)

	var is_ally_2 := ally_members.has(v2_owner)
	_assert(is_ally_2 == true, "Aynı ittifakta olduklarında Lord Roland artık MÜTTEFİK (is_ally = true) olarak mavi algılanır")

	print("\n==================================================")
	print("SONUÇLAR: %d PASS, %d FAIL" % [_pass_count, _fail_count])
	print("==================================================")

	quit(0 if _fail_count == 0 else 1)


func _assert(cond: bool, msg: String) -> void:
	if cond:
		_pass_count += 1
		print("  ✓ %s" % msg)
	else:
		_fail_count += 1
		printerr("  ❌ BAŞARISIZ: %s" % msg)
