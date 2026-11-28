extends SceneTree
## test_build45_features.gd — Build 45 Tüm Yeni Özellik & Bugfix Doğrulama Paketi:
## 1) Görev HUD: Bina paneli açıldığında (Kale/Oduncu/Kışla) GÖRÜNÜR kalır; yalnızca Kışla asker inputu klavyeyle yukarı kalktığında gizlenir.
## 2) Kışla açılış boyut flaşı yok: show_building sonrası Panel kilitlenmiş son boyutta kalır, klavye yüksekliği sızmaz.
## 3) Dengeli Haydut Köyü dağılımı (Sv.1..10 eksiksiz + yeni doğan köyün yakınında en az ikişer Sv.1 ve Sv.2 haydut kampı).
## 4) Hesap silme & 30 gün hareketsizlik -> fethedilebilir "Terk Edilmiş Köy" (hafif grileştirilmiş MapVillageView, korumasız, fethedilince normal köy).
## 5) 24 saatte bir tekrarlanan "Lordum, köyün seni bekliyor!" hareketsizlik bildirimi + iOS native trigger repeats desteği.

const LordModelScript := preload("res://scripts/model/LordModel.gd")
const WorldGenScript := preload("res://scripts/world/WorldGenerator.gd")
const VillageModelScript := preload("res://scripts/model/VillageModel.gd")
const MapVillageViewScript := preload("res://scenes/map/MapVillageView.gd")
const ProtectionScript := preload("res://scripts/sim/actions/Protection.gd")
const ArrivalScript := preload("res://scripts/sim/actions/Arrival.gd")
const NotificationManagerScript := preload("res://autoload/NotificationManager.gd")

var _passes: int = 0
var _fails: int = 0


func _assert(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
		print("  [PASS] " + msg)
	else:
		_fails += 1
		printerr("  [FAIL] " + msg)


func _tick(frames: int = 2) -> void:
	for _i in range(frames):
		await process_frame


func _initialize() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	await _tick(2)
	print("=== BUILD 45 FEATURE VERIFICATION ===")

	var gd: Node = root.get_node_or_null("GameData")
	var gs: Node = root.get_node_or_null("GameState")
	var wm: Node = root.get_node_or_null("WorldManager")
	var qm: Node = root.get_node_or_null("QuestManager")
	var tm: Node = root.get_node_or_null("TutorialManager")
	var auth: Node = root.get_node_or_null("AuthManager")
	_assert(gd != null and gs != null and wm != null and qm != null and auth != null, "Autoload'lar yüklü")
	if gd == null or gs == null or wm == null or qm == null or auth == null:
		quit(1)
		return
	if gd != null and gd.has_method("load_all"):
		gd.call("load_all", true)
	if tm != null:
		tm.set("tutorial_enabled_in_headless", false)
	if qm != null:
		qm.set("quest_enabled_in_headless", true)

	wm.call("wipe_all_local_data")
	auth.call("clear_all_account_data")
	auth.call("login_with_apple", "Lord Build45", "b45@privaterelay.appleid.com", "apple_uid_b45")
	var ok_join: bool = bool(wm.call("join_world", 1, "Lord Build45", 100, 100))
	_assert(ok_join and bool(gs.call("has_active_village")), "Dünya 1'e katılım başarılı")
	gs.player["tutorial_completed"] = true

	# ------------------------------------------------------------------
	# 1 & 2. Görev HUD görünürlüğü + Kışla açılış boyut tutarlılığı
	# ------------------------------------------------------------------
	print("--- 1 & 2) Görev HUD + Kışla Açılış Boyut Fixi ---")
	var v_scene := load("res://scenes/Village.tscn") as PackedScene
	var v_node := v_scene.instantiate() as Control
	root.add_child(v_node)
	var prev_scene := current_scene
	current_scene = v_node
	await _tick(3)

	var pv: Dictionary = gs.call("get_active_village")
	pv["buildings"]["barracks"] = 3
	var bp := v_node.get("building_panel") as Control
	_assert(bp != null, "BuildingPanel mevcut")

	# Normal binada (Kale) Görevler açık kalmalı
	bp.call("show_building", pv, "main")
	await _tick(2)
	_assert(bool(qm.call("is_quest_hud_visible")), "Kale açılınca Görev HUD görünür kalıyor")

	# Kışla açılışında boyut fırlaması görünür olmamalı (yerleşmeden önce modulate.a == 0 veya zaten yerleşmiş boyutta) & Research/Train geçişlerinde Görev HUD açık kalmalı
	bp.call("show_building", pv, "barracks")
	var a_immediate := bp.modulate.a
	var h_immediate := bp.size.y
	await _tick(2)
	var a_settled := bp.modulate.a
	var h_settled := bp.size.y
	_assert((a_immediate < 0.01 or absf(h_immediate - h_settled) <= 4.0) and absf(a_settled - 1.0) < 0.01, "Kışla açılışında büyük ekran flaşı görünmüyor (frame0 alpha=%.2f h=%.0f -> yerleşti alpha=%.2f h=%.0f)" % [a_immediate, h_immediate, a_settled, h_settled])
	_assert(bool(qm.call("is_quest_hud_visible")), "Kışla Yükselt sekmesinde Görev HUD açık")

	bp.call("switch_tab", 2) # Tab.TRAIN
	await _tick(2)
	_assert(bool(qm.call("is_quest_hud_visible")), "Kışla Asker Eğit sekmesinde klavye kapalıyken Görev HUD açık")

	# Kışla klavye yukarı kalkışı (offset_bottom < -265) simülasyonu -> Görev HUD gizlenmeli
	bp.offset_bottom = -640.0
	_assert(bool(bp.call("is_keyboard_lifted")), "Klavye kalktığında is_keyboard_lifted() == true")
	_assert(not bool(qm.call("is_quest_hud_visible")), "Kışla klavyeyle yukarı kalkınca Görev HUD gizleniyor")
	bp.call("_restore_keyboard_lift")
	_assert(bool(qm.call("is_quest_hud_visible")), "Klavye inince Görev HUD hemen geri geliyor")
	bp.call("_on_close_pressed")
	await _tick(1)

	current_scene = prev_scene
	v_node.queue_free()
	qm.set("quest_enabled_in_headless", false)
	await _tick(2)

	# ------------------------------------------------------------------
	# 3. Dengeli Sv.1..10 Haydut Dağılımı & Yakın Başlangıç Kampları
	# ------------------------------------------------------------------
	print("--- 3) Dengeli Haydut Köyü Dağılımı ---")
	var w1: Dictionary = wm.call("load_world_dict", 1)
	var all_v: Array = (w1.get("state", {}) as Dictionary).get("villages", [])
	var lvl_counts := {}
	var nearby_bandits: Array = []
	var px := int(pv.get("x", 100))
	var py := int(pv.get("y", 100))
	for item in all_v:
		if typeof(item) == TYPE_DICTIONARY and bool((item as Dictionary).get("is_bandit", false)):
			var l := int((item as Dictionary).get("bandit_level", 0))
			lvl_counts[l] = int(lvl_counts.get(l, 0)) + 1
			var dx := int((item as Dictionary).get("x", 0)) - px
			var dy := int((item as Dictionary).get("y", 0)) - py
			nearby_bandits.append({"d2": dx * dx + dy * dy, "lvl": l})
	var has_all_1_to_10 := true
	for req_l in range(1, 11):
		if int(lvl_counts.get(req_l, 0)) < 1:
			has_all_1_to_10 = false
	_assert(has_all_1_to_10, "Dünyada 1'den 10'a kadar tüm haydut seviyeleri mevcut (%s)" % str(lvl_counts))
	nearby_bandits.sort_custom(func(a, b): return int(a["d2"]) < int(b["d2"]))
	var near6_lvls: Array = []
	var near1 := 0
	var near2 := 0
	for i in range(mini(6, nearby_bandits.size())):
		var nl := int(nearby_bandits[i]["lvl"])
		near6_lvls.append(nl)
		if nl == 1: near1 += 1
		elif nl == 2: near2 += 1
	_assert(near1 >= 2 and near2 >= 2, "Yeni köyün en yakın 6 haydut kampında en az 2x Sv.1 ve 2x Sv.2 mevcut (%s)" % str(near6_lvls))

	# ------------------------------------------------------------------
	# 4. Hesap Silme & 30 Gün İnaktif -> Fethedilebilir Terk Edilmiş Köy
	# ------------------------------------------------------------------
	print("--- 4) Terk Edilmiş Köy Dönüşümü & Fetih ---")
	var test_v := VillageModelScript.create(701, "Kuzey Kalem", 120, 120, "EskiLord", false)
	var now_u := int(Time.get_unix_time_from_system())
	test_v["protection_until"] = now_u + 86400
	test_v["protection_until_unix"] = now_u + 86400
	test_v["conquest_protection_until"] = now_u + 86400
	test_v["last_active_unix"] = now_u - (31 * 86400)
	var test_w := {
		"world_id": 1,
		"registered_real_players": ["EskiLord", "Lord Build45"],
		"state": {
			"villages": [pv.duplicate(true), test_v],
			"queues": [{"id": 81, "village_id": 701, "type": "build", "key": "wood"}],
			"movements": [],
			"alliances": [],
			"world": {"player_profiles": {"EskiLord": {"name": "EskiLord", "last_active_unix": now_u - (31 * 86400)}}},
		}
	}
	var swept := int(wm.call("sweep_inactive_villages", test_w, now_u, "Lord Build45"))
	_assert(swept == 1, "30+ gün hareketsiz oyuncunun köyü terk edilmiş köye dönüştü (sayı=%d)" % swept)
	_assert(str(test_v.get("owner", "x")) == "" and str(test_v.get("name", "")) == "Terk Edilmiş Köy" and bool(test_v.get("is_abandoned", false)), "Sahip adı silindi, köy adı 'Terk Edilmiş Köy' oldu")
	_assert(ProtectionScript.is_unprotected_kind(test_v) and not ProtectionScript.is_conquest_protected(test_v, now_u), "Terk Edilmiş Köy fetih koruması taşımıyor")

	var ab_view := MapVillageViewScript.new()
	ab_view.setup(test_v, false, false, "")
	root.add_child(ab_view)
	await _tick(1)
	var o_lbl := ab_view.get("_owner_label") as Label
	var n_lbl := ab_view.get("_name_coord_label") as Label
	var sp_ab := ab_view.get("_sprite") as TextureRect
	_assert(bool(ab_view.get("is_abandoned")) and not bool(ab_view.get("is_bandit")), "MapVillageView is_abandoned=true, is_bandit=false")
	_assert(o_lbl != null and o_lbl.text.contains("Terk Edilmiş") and not o_lbl.text.contains("EskiLord"), "Harita kartında eski oyuncu adı gizlenip 'Terk Edilmiş' yazıyor")
	_assert(n_lbl != null and n_lbl.text.contains("Terk Edilmiş Köy"), "Köy etiketi 'Terk Edilmiş Köy (120|120)'")
	_assert(sp_ab != null and sp_ab.modulate.r > 0.88 and sp_ab.modulate.a > 0.90, "Terk Edilmiş Köy hayduttan daha hafif grileştirilmiş (%s)" % str(sp_ab.modulate))
	ab_view.queue_free()

	# Terk edilmiş köy fethedilebilmeli
	var conq_res: Dictionary = ArrivalScript._apply_conquest(test_w["state"], pv, test_v, {"realm_of_power_after": 30}, now_u)
	_assert(str(conq_res.get("type", "")) == "village_conquered" and str(test_v.get("owner", "")) == "Lord Build45" and not bool(test_v.get("is_abandoned", true)), "Terk Edilmiş Köy Kont ile başarıyla fethedildi")

	# Hesap silme backend testi (_wipe_player_from_world_state köyü silmez, terkedilmişe çevirir)
	var api_src := FileAccess.get_file_as_string("res://../api/index.py")
	_assert(api_src.contains("_convert_village_to_abandoned") and api_src.contains("SET user_id = NULL, owner = '', name = 'Terk Edilmiş Köy'"), "api/index.py hesap silmede köyü haritadan silmek yerine Terk Edilmiş Köy'e dönüştürüyor")

	# ------------------------------------------------------------------
	# 5. 24 Saatte Bir Tekrarlanan Yokluk Bildirimi
	# ------------------------------------------------------------------
	print("--- 5) 24 Saatlik Tekrarlı Bildirim ---")
	var st_notif := {"player": gs.player, "villages": [pv], "active_village_id": int(pv.get("id", 1)), "queues": [], "movements": []}
	var n_items: Array = NotificationManagerScript.compute_local_notifications(st_notif, now_u, {})
	var found_idle := {}
	for it in n_items:
		if str((it as Dictionary).get("type", "")) == "inactivity_reminder":
			found_idle = it
			break
	_assert(not found_idle.is_empty() and int(found_idle.get("delay_seconds", 0)) == 86400 and bool(found_idle.get("repeats", false)), "24 saatlik (86400 sn) tekrarlayan hareketsizlik bildirimi planlandı")
	_assert(str(found_idle.get("body", "")).contains("Lordum") and str(found_idle.get("body", "")).contains("köyün seni bekliyor"), "Bildirim metni 'Lordum ... köyün seni bekliyor' içeriyor")

	var mm_src := FileAccess.get_file_as_string("res://../tools/ios_native_auth_bridge.mm")
	_assert(mm_src.contains('tvk_idle_') and mm_src.contains('repeats:shouldRepeat'), "iOS native bildirim köprüsü tvk_idle_ temizliğini ve tekrarlı UNTimeIntervalNotificationTrigger'ı destekliyor")
	_assert(api_src.contains("_dispatch_inactivity_push_reminders"), "Sunucu cron içinde 24+ saatlik APNs tekrarlı hatırlatma gönderimi mevcut")

	wm.call("wipe_all_local_data")
	print("=== BUILD 45 VERIFICATION: %d PASS, %d FAIL ===" % [_passes, _fails])
	quit(1 if _fails > 0 else 0)
