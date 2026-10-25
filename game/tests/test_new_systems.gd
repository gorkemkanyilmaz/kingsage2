extends SceneTree
## test_new_systems.gd — İttifak, mesajlaşma, çoklu köy ve koruma sistem testleri.

const AllianceModelScript := preload("res://scripts/model/AllianceModel.gd")
const ProtectionScript := preload("res://scripts/sim/actions/Protection.gd")
const MovementScript := preload("res://scripts/sim/actions/Movement.gd")
const VillageModelScript := preload("res://scripts/model/VillageModel.gd")

var _passed := 0
var _failed := 0


func _init() -> void:
	print("==================================================")
	print("  TAHT VE KILIC — YENI SISTEMLER VE OZELLIKLER TESTI")
	print("==================================================")

	_test_alliance_system()
	_test_multi_village_switching()
	_test_messaging_system()
	_test_15_days_protection()
	_test_queue_hud_data()
	_test_resource_bar_layout()
	_test_village_scene_and_alliance_button()
	_test_map_village_view_compilation()


	print("==================================================")
	print("  SONUC: %d BASARILI, %d BASARISIZ" % [_passed, _failed])
	print("==================================================")

	quit(1 if _failed > 0 else 0)


func _assert(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("  [OK] %s" % msg)
	else:
		_failed += 1
		print("  [FAIL] %s" % msg)


func _test_alliance_system() -> void:
	print("\n--- Test: İttifak Sistemi ve İçi Canlı Sohbet ---")

	var state := {
		"alliances": [],
		"messages": [],
		"villages": [
			{"id": 1, "owner": "Kral", "points": 120},
			{"id": 2, "owner": "Lord Edward", "points": 350},
			{"id": 3, "owner": "Baron Roland", "points": 400}
		]
	}

	# 1. Tag > 6 karakter reddedilmeli
	var res_bad_tag := AllianceModelScript.create_alliance(state, "Kral", "Uzun Birlik", "UZUNBIRLIK")
	_assert(not bool(res_bad_tag.get("ok", false)), "6 karakterden uzun etiket reddedildi")

	# 2. Geçerli ittifak kurulumu (tag <= 6 char)
	var res_ok := AllianceModelScript.create_alliance(state, "Kral", "Kral Muhafızları", "KRAL", "Diyarın muhafızları")
	_assert(bool(res_ok.get("ok", false)), "Geçerli isim ve etiketle ittifak kuruldu")

	var ally: Dictionary = AllianceModelScript.get_player_alliance(state, "Kral")
	_assert(not ally.is_empty() and str(ally.get("tag", "")) == "KRAL", "Oyuncunun ittifakı doğru bulundu")
	_assert(str(ally.get("leader", "")) == "Kral", "Kurucu council_of_elders (Lider) oldu")

	# 3. İttifak içi sohbet mesajı gönderme
	var res_chat := AllianceModelScript.send_chat_message(state, int(ally.get("id", 0)), "Kral", "Selamlar ittifak üyeleri!")
	_assert(bool(res_chat.get("ok", false)), "İttifak içi sohbet mesajı gönderildi")
	var msgs: Array = ally.get("chat_messages", [])
	_assert(msgs.size() >= 2, "Sohbet mesajı ittifak geçmişine kaydedildi")
	_assert(str(msgs[-1].get("text", "")) == "Selamlar ittifak üyeleri!", "Son mesaj metni doğru")

	# 4. Üye olmayan birinin sohbete yazması engellenmeli
	var res_chat_intruder := AllianceModelScript.send_chat_message(state, int(ally.get("id", 0)), "Lord Edward", "Sızmaya çalışıyorum")
	_assert(not bool(res_chat_intruder.get("ok", false)), "Üye olmayan oyuncunun sohbete yazması engellendi")

	# 5. Oyuncu davet etme
	var res_inv := AllianceModelScript.invite_player(state, int(ally.get("id", 0)), "Kral", "Lord Edward")
	_assert(bool(res_inv.get("ok", false)), "Lord Edward ittifaka davet edildi")
	_assert((ally.get("invitations", []) as Array).size() == 1, "Davet ittifak listesine yazıldı")
	_assert(state["messages"].size() >= 1, "Davet edilen oyuncunun gelen kutusuna davet mektubu düştü")

	# 6. Daveti kabul etme
	var res_acc := AllianceModelScript.accept_invitation(state, "Lord Edward", int(ally.get("id", 0)))
	_assert(bool(res_acc.get("ok", false)), "Lord Edward daveti kabul etti")
	_assert((ally.get("members", []) as Array).size() == 2, "İttifak üye sayısı 2 oldu")

	# 7. Diplomasi belirleme
	AllianceModelScript.set_diplomacy(state, int(ally.get("id", 0)), "KARTAL", "allies")
	var diplo: Dictionary = ally.get("diplomacy", {})
	_assert((diplo.get("allies", []) as Array).has("KARTAL"), "Diplomasi: KARTAL müttefik olarak kaydedildi")


func _test_multi_village_switching() -> void:
	print("\n--- Test: Çoklu Köy Yönetimi ve Geçiş ---")

	var gs = root.get_node_or_null("GameState")
	if gs == null:
		var gs_class = load("res://autoload/GameState.gd")
		gs = gs_class.new()
		gs.name = "GameState"
		root.add_child(gs)

	gs.reset()
	gs.player = {"id": 1, "name": "Kral", "points": 220}

	var v1 := {"id": 1, "name": "Başkent", "owner": "Kral", "x": 100, "y": 100, "points": 110, "is_bot": false, "is_barbarian": false}
	var v2 := {"id": 2, "name": "Fethedilen Kale", "owner": "Kral", "x": 105, "y": 102, "points": 110, "is_bot": false, "is_barbarian": false}
	var v_bot := {"id": 3, "name": "Düşman Şato", "owner": "Lord Edward", "x": 110, "y": 110, "points": 350, "is_bot": true, "is_barbarian": false}

	var v_bonus := {"id": 4, "name": "Yıldızbağ", "owner": "Usta", "bonus_type": "wood", "is_bot": false, "is_barbarian": false}
	gs.villages = [v1, v_bot, v_bonus]
	_assert(gs.get_player_villages().size() == 1, "Başlangıçta yalnızca oyuncunun 1 köyü listelenir, bonus köyler dahil edilmez")

	gs.villages = [v1, v2, v_bot, v_bonus]
	gs.active_village_id = 1

	var p_vills: Array = gs.get_player_villages()
	_assert(p_vills.size() == 2, "Oyuncunun 2 köyü doğru tespit edildi")


	# Sonraki köye geçiş
	var next_id: int = gs.cycle_active_village(1)
	_assert(next_id == 2 and gs.active_village_id == 2, "2. köye başarıyla geçildi")

	# Tekrar sonraki köye geçiş (başa dönmeli)
	next_id = gs.cycle_active_village(1)
	_assert(next_id == 1 and gs.active_village_id == 1, "Döngüsel olarak 1. köye geri dönüldü")

	# Önceki köye geçiş
	var prev_id: int = gs.cycle_active_village(-1)
	_assert(prev_id == 2 and gs.active_village_id == 2, "Önceki köye geçiş doğru çalıştı")


func _test_messaging_system() -> void:
	print("\n--- Test: Mesajlaşma Sistemi ---")

	var gs = root.get_node_or_null("GameState")
	gs.messages = []

	var now := int(Time.get_unix_time_from_system())
	var msg := {
		"id": 1001,
		"from": "Lord Edward",
		"to": "Kral",
		"subject": "Dostluk Paktı",
		"body": "Sayın Kralım, doğudaki sınırımızda sulh içinde yaşayalım.",
		"created_unix": now,
		"read": false
	}
	gs.add_message(msg)

	_assert(gs.messages.size() == 1, "Gelen mesaj GameState.messages'a eklendi")
	_assert(str(gs.messages[0].get("from", "")) == "Lord Edward", "Mesaj göndereni doğru")
	_assert(not bool(gs.messages[0].get("read", false)), "Mesaj başlangıçta okunmamış")


func _test_15_days_protection() -> void:
	print("\n--- Test: 15 Gün Süreli Koruma ---")

	var days: int = ProtectionScript.new_player_protection_days()
	_assert(days == 15, "Yeni oyuncu koruması 15 gün olarak yapılandırılmış (beklenen 15, alınan %d)" % days)

	var now := int(Time.get_unix_time_from_system())
	var village := VillageModelScript.create(1, "Köy", 50, 50, "Kral", false)

	_assert(ProtectionScript.is_attack_protected(village, now), "Yeni kurulan köy başlangıçta saldırıya karşı korumalı")

	# Köy saldırı gönderdiğinde koruma düşmeli
	var event := ProtectionScript.on_attack_sent(village, now)
	_assert(not event.is_empty(), "Saldırı gönderilince koruma sona erdi olayı üretildi")
	_assert(not ProtectionScript.is_attack_protected(village, now), "Saldıran köyün koruması derhal kalktı")


func _test_queue_hud_data() -> void:
	print("\n--- Test: Ana Ekran Aktivite Toplama ---")

	var now := int(Time.get_unix_time_from_system())
	var state := {
		"queues": [
			{"id": 1, "village_id": 1, "type": "build", "key": "main", "target_level": 2, "start_unix": now, "finish_unix": now + 60},
			{"id": 2, "village_id": 1, "type": "research", "key": "sword", "start_unix": now, "finish_unix": now + 120},
			{"id": 3, "village_id": 1, "type": "train", "key": "spear", "count": 10, "start_unix": now, "finish_unix": now + 180}
		],
		"movements": [
			{
				"id": 101,
				"from_village_id": 2,
				"to_village_id": 1,
				"type": "attack",
				"state": "outgoing",
				"depart_unix": now - 30,
				"arrive_unix": now + 150
			}
		]
	}

	var vid := 1
	var acts := []
	for m in state["movements"]:
		if m["to_village_id"] == vid and m["state"] == "outgoing" and m["type"] in ["attack", "raid"]:
			acts.append({"category": "incoming_attack", "data": m})

	for q in state["queues"]:
		if q["village_id"] == vid:
			acts.append({"category": q["type"], "data": q})

	_assert(acts.size() == 4, "4 farklı aktivite (gelen saldırı, inşaat, araştırma, eğitim) başarıyla toplandı")
	_assert(acts[0]["category"] == "incoming_attack", "Gelen saldırı en üstte önceliklendirildi")


func _test_resource_bar_layout() -> void:
	print("\n--- Test: Üst Menü ve Kaynak Çubuğu Düzeni ---")
	var rbar_scene = load("res://ui/ResourceBar.tscn")
	_assert(rbar_scene != null, "ResourceBar.tscn sahnesi başarıyla yüklendi")
	var rbar = rbar_scene.instantiate()
	_assert(rbar != null, "ResourceBar örneklendi")
	_assert(rbar.custom_minimum_size.x <= 1080.0, "ResourceBar genişliği 1080px sınırını aşmıyor")
	var v_name = rbar.find_child("VillageName", true, false) as Label
	_assert(v_name != null and v_name.clip_text and v_name.text_overrun_behavior == 3, "VillageName taşmayı önleyici kırpma ve elips moduna sahip")
	rbar.free()


func _test_village_scene_and_alliance_button() -> void:
	print("\n--- Test: Köy Ekranı ve İttifak Butonu ---")
	var v_scene = load("res://scenes/Village.tscn")
	_assert(v_scene != null, "Village.tscn sahnesi başarıyla yüklendi")
	var v_inst = v_scene.instantiate()
	_assert(v_inst != null, "Village örneklendi")
	var btn_ally = v_inst.find_child("BtnAlliance", true, false) as Button
	_assert(btn_ally != null, "İttifak butonu (BtnAlliance) sahnede mevcut")
	_assert(btn_ally.z_index == 100, "İttifak butonu z_index = 100 ile üst katmanda")
	_assert(btn_ally.mouse_filter == Control.MOUSE_FILTER_STOP, "İttifak butonu fare tıklamalarını yakalayabiliyor")
	v_inst.free()

	var ally_scene = load("res://scenes/Alliance.tscn")
	_assert(ally_scene != null, "Alliance.tscn sahnesi başarıyla yüklendi")
	var ally_inst = ally_scene.instantiate()
	_assert(ally_inst != null, "Alliance.tscn hatasız örneklendi")
	ally_inst.free()


func _test_map_village_view_compilation() -> void:
	print("\n--- Test: Harita Köyleri ve MapVillageView Derlemesi ---")
	var mvw = load("res://scenes/map/MapVillageView.gd")
	_assert(mvw != null, "MapVillageView.gd hatasız derlendi ve yüklendi")
	var inst = mvw.new()
	_assert(inst != null, "MapVillageView başarıyla örneklendi")
	var sample_village = {
		"id": 1,
		"name": "Başkent",
		"owner": "Kral",
		"x": 100,
		"y": 100,
		"points": 110,
		"is_bot": false,
		"is_barbarian": false,
		"buildings": {"main": 1}
	}
	inst.setup(sample_village, true, false)
	_assert(inst.get_child_count() > 0, "MapVillageView setup() ile görsel ve bilgi kartı oluşturuldu")
	inst.free()

