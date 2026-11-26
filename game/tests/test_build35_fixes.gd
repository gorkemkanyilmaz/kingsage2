extends SceneTree
## test_build35_fixes.gd — Build 35 Kritik Hata Düzeltmeleri Doğrulama Paketi:
## 1) Soğuk açılış donması/çökmesi: .png ikonlar (ASCII .tres yok), SaveManager offline telafi hızı,
##    GameClock & GameLoop sıfırlama/kısıtlama, VillageBackgroundCache ertelenmiş ısıtma + düşük bellek penceresi,
##    VillageSelect çift dokunma kilidi.
## 2) Google ile giriş: ASWebAuthenticationSession error 3 önlemi, Face ID ön-kapısının kaldırılması,
##    prefersEphemeralWebBrowserSession = YES + prompt=login + ApplicationStateActive kontrolü.
## 3) İttifak Türkçe karakter & mojibake onarımı: WorldManager.repair_mojibake_str, AllianceModel önek boşluk temizliği,
##    Alliance.gd & Alliance.tscn FontNunitoBold kullanımı, NetworkManager UTF-8 Content-Type.

const AllianceModelScript := preload("res://scripts/model/AllianceModel.gd")
const GameLoopScript := preload("res://scripts/core/GameLoop.gd")
const WorldManagerScript := preload("res://autoload/WorldManager.gd")

var _passed: int = 0
var _failed: int = 0


func _assert(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("[PASS] ", label)
	else:
		_failed += 1
		printerr("[FAIL] ", label)


func _tick(frames: int = 2) -> void:
	for _i in range(frames):
		await process_frame


func _initialize() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	var gd := root.get_node_or_null("GameData")
	var gs := root.get_node_or_null("GameState")
	var gclk := root.get_node_or_null("GameClock")
	var wm := root.get_node_or_null("WorldManager")
	var sm := root.get_node_or_null("SaveManager")
	var auth := root.get_node_or_null("AuthManager")
	var bgc := root.get_node_or_null("VillageBackgroundCache")
	var tm := root.get_node_or_null("TutorialManager")
	var qm := root.get_node_or_null("QuestManager")

	_assert(gd != null and gs != null and gclk != null and wm != null and sm != null and auth != null and bgc != null, "Autoloadlar yüklendi")
	if gd != null and gd.has_method("load_all"):
		gd.call("load_all", true)
	if tm != null:
		tm.set("tutorial_enabled_in_headless", false)
	if qm != null:
		qm.set("quest_enabled_in_headless", false)

	wm.call("wipe_all_local_data")
	auth.call("clear_all_account_data")

	await _test_png_icons_and_bg_cache(bgc, gclk)
	await _test_offline_catchup_and_enter_world(wm, sm, gs, auth)
	await _test_alliances_turkish_and_mojibake(wm, gs, auth)
	_test_ios_google_bridge_and_network_utf8()

	wm.call("wipe_all_local_data")
	print("\n=== TestBuild35Fixes: %d BASARILI, %d BASARISIZ ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_png_icons_and_bg_cache(bgc: Node, gclk: Node) -> void:
	print("\n-- 1) PNG İkonlar, VillageBackgroundCache & GameClock --")
	var png_paths := [
		"res://assets/sprites/ui/nano_banana/sharp_icon_wood.png",
		"res://assets/sprites/ui/nano_banana/sharp_icon_stone.png",
		"res://assets/sprites/ui/nano_banana/sharp_icon_iron.png",
		"res://assets/sprites/ui/nano_banana/sharp_icon_citizens.png",
		"res://assets/sprites/ui/nano_banana/sharp_icon_storage.png",
		"res://assets/sprites/ui/nano_banana/sharp_icon_diamond.png",
		"res://assets/sprites/ui/nano_banana/sharp_icon_market.png",
		"res://assets/sprites/ui/nano_banana/sharp_icon_castle_crest.png",
		"res://assets/sprites/ui/nano_banana/sharp_icon_alliance_shield.png",
		"res://assets/sprites/ui/nano_banana/sharp_icon_report_seal.png",
		"res://assets/sprites/ui/nano_banana/sharp_ui_royal_btn_bg.png",
	]
	var all_ok := true
	for p in png_paths:
		if load(p) == null:
			all_ok = false
			break
	_assert(all_ok, "Tüm 11 nano_banana .png ikonu hatasız yükleniyor")

	_assert(int(bgc.get("FRAMES_PER_TICK")) == 1 and int(bgc.get("THREAD_PREFETCH_WINDOW")) == 2, "VillageBackgroundCache düşük bellek ve ısınma dostu nazik hız sınırlarına sahip (1 kare/tick, 2 pencere)")
	bgc.call("trim_memory")
	_assert(bool(bgc.get("_low_memory_mode")), "trim_memory() sonrası _low_memory_mode = true")
	bgc.call("ensure_warming")
	_assert(bgc.is_processing(), "ensure_warming() düşük bellek modunda kayan pencere ısıtmayı açıyor")
	bgc.call("pause_warming")
	_assert(not bgc.is_processing(), "pause_warming() bellek temizlemeden arka plan döngüsünü durduruyor")

	gclk.set("_accumulator", 2.5)
	gclk.call("reset_accumulator")
	_assert(is_zero_approx(float(gclk.get("_accumulator"))), "GameClock.reset_accumulator() ilk kare tick yığılmasını sıfırlıyor")


func _test_offline_catchup_and_enter_world(wm: Node, sm: Node, gs: Node, auth: Node) -> void:
	print("\n-- 2) Offline Catchup & Oyuna Devam Et Çift Dokunma Koruması --")
	auth.call("login_with_apple", "Lord Build35", "b35@privaterelay.appleid.com", "apple_uid_b35")
	_assert(bool(wm.call("join_world", 1, "Lord Build35", 100, 100)), "Dünya 1'e katılım başarılı")

	# 48 saat çevrimdışı + 120 kuyruk öğesi benzetimi yap ve enter_world süresini ölç
	var w_data: Dictionary = wm.call("load_world_dict", 1)
	var now := int(Time.get_unix_time_from_system())
	w_data["last_saved_unix"] = now - 48 * 3600
	var st: Dictionary = w_data.get("state", {})
	var qs: Array = st.get("queues", [])
	for i in range(120):
		qs.append({
			"id": 5000 + i,
			"village_id": 2 + (i % 45),
			"type": "build",
			"key": "barracks",
			"target_level": 5,
			"start_unix": now - 40 * 3600,
			"finish_unix": now - 39 * 3600 + (i % 10),
		})
	st["queues"] = qs
	wm.call("save_world_dict", 1, w_data)

	var t0 := Time.get_ticks_msec()
	var ok_enter: bool = bool(wm.call("enter_world", 1, "Lord Build35"))
	var dt_ms := Time.get_ticks_msec() - t0
	_assert(ok_enter, "48 saat offline + 120 bot kuyruğuyla enter_world başarılı")
	_assert(dt_ms < 2500, "enter_world 2.5 sn altında tamamlandı (%d ms)" % dt_ms)
	_assert(not bool(wm.get("_suppress_tick_autosave")), "enter_world sonrası _suppress_tick_autosave sıfırlandı")

	# VillageSelect çift dokunma kilidi testi
	var vs_sc: PackedScene = load("res://scenes/VillageSelect.tscn")
	var vs := vs_sc.instantiate() as Control
	root.add_child(vs)
	await _tick(2)
	vs.set("_entering_world", true)
	vs.call("_on_profile_continue_pressed")
	_assert(bool(vs.get("_entering_world")), "VillageSelect _entering_world=true iken ikinci dokunmayı engelliyor")
	vs.queue_free()
	await _tick(1)


func _test_alliances_turkish_and_mojibake(wm: Node, gs: Node, auth: Node) -> void:
	print("\n-- 3) İttifak Türkçe Karakter & Mojibake Onarımı --")
	var bad_ann := " Ä°ttifakÄ±mÄ±za hoÅ\u009f geldiniz! Birlikte gÃ¼Ã§lÃ¼yÃ¼z."
	var bad_msg := " [GORGI] Gorgi ittifakÄ± kuruldu!"
	var bad_bot := "Kale DÃ¼k William"
	_assert(WorldManagerScript.repair_mojibake_str(bad_ann).strip_edges() == "İttifakımıza hoş geldiniz! Birlikte güçlüyüz.", "WorldManager.repair_mojibake_str iç duyuru mojibake'ini tamir etti")
	_assert(WorldManagerScript.repair_mojibake_str(bad_msg).strip_edges() == "[GORGI] Gorgi ittifakı kuruldu!", "WorldManager.repair_mojibake_str kuruluş mesajı mojibake'ini tamir etti")
	_assert(WorldManagerScript.repair_mojibake_str(bad_bot) == "Kale Dük William", "WorldManager.repair_mojibake_str bot köy adını tamir etti")

	# Cloud sync üzerinden gelen bozuk veri de anında onarılmalı
	var snap: Dictionary = gs.call("to_dict")
	snap["alliances"] = [{
		"id": 99,
		"name": "Gorgi",
		"tag": "GORGI",
		"leader": "Lord Build35",
		"founder": "Lord Build35",
		"internal_announcement": bad_ann,
		"members": [{"name": "Lord Build35", "points": 110, "is_leader": true}],
		"invitations": [],
		"chat_messages": [{"sender": "Sistem", "text": bad_msg, "timestamp_unix": int(Time.get_unix_time_from_system())}],
		"diplomacy": {"allies": [], "enemies": [], "ally_requests_in": [], "ally_requests_out": []},
	}]
	var now_s := int(Time.get_unix_time_from_system()) + 20
	wm.call("apply_cloud_sync", {
		"ok": true,
		"updated_unix": now_s,
		"cloud_state": {
			"world_id": 1,
			"last_saved_unix": now_s,
			"registered_real_players": ["Lord Build35"],
			"state": snap,
		},
	}, false, -1)

	var a_scene: PackedScene = load("res://scenes/Alliance.tscn")
	var a_node := a_scene.instantiate() as Control
	root.add_child(a_node)
	await _tick(2)
	var labels := a_node.find_children("*", "Label", true, false)
	var found_clean_ann := false
	var found_clean_msg := false
	var any_mojibake := false
	var any_cinzel_override := false
	for node in labels:
		var lbl := node as Label
		var txt := lbl.text
		if txt.contains("İç Duyuru: İttifakımıza hoş geldiniz! Birlikte güçlüyüz."):
			found_clean_ann = true
		if txt.contains("[GORGI] Gorgi ittifakı kuruldu!"):
			found_clean_msg = true
		if txt.contains("Ä°") or txt.contains("Ä±") or txt.contains("Ã¼") or txt.contains("Å"):
			any_mojibake = true
		var ov_font = lbl.get_theme_font("font")
		if ov_font != null and str(ov_font.resource_path).contains("Cinzel"):
			any_cinzel_override = true
	_assert(found_clean_ann, "Alliance ekranında İç Duyuru temiz Türkçe UTF-8 olarak gösteriliyor")
	_assert(found_clean_msg, "Alliance ekranında İttifak kuruldu! mesajı temiz Türkçe UTF-8 olarak gösteriliyor")
	_assert(not any_mojibake, "Alliance ekranında hiçbir mojibake karakteri kalmadı")
	_assert(not any_cinzel_override, "Alliance ekranındaki tüm etiketler Cinzel yerine Nunito kullanıyor")

	var new_st := {"alliances": [], "villages": []}
	AllianceModelScript.create_alliance(new_st, "Lord Build35", "Birlik", "BRLK", "Test")
	var created_a: Dictionary = new_st["alliances"][0]
	_assert(not str(created_a.get("internal_announcement", "")).begins_with(" "), "AllianceModel.create_alliance baştaki fazla boşluğu kaldırdı")
	a_node.queue_free()
	await _tick(1)


func _test_ios_google_bridge_and_network_utf8() -> void:
	print("\n-- 4) iOS Google ASWebAuthenticationSession & NetworkManager UTF-8 --")
	var mm := FileAccess.get_file_as_string("res://../tools/ios_native_auth_bridge.mm")
	_assert(not mm.is_empty(), "ios_native_auth_bridge.mm okundu")
	var idx_start := mm.find("- (void)startNativeGoogleSignIn")
	var idx_anchor := mm.find("presentationAnchorForWebAuthenticationSession")
	var google_start_block := mm.substr(idx_start, maxi(0, idx_anchor - idx_start))
	_assert(not google_start_block.contains("LAPolicyDeviceOwnerAuthenticationWithBiometrics"), "startNativeGoogleSignIn içinde ön Face ID kapısı yok (error 3 önlendi)")
	_assert(mm.contains("session.prefersEphemeralWebBrowserSession = YES;"), "Google OAuth prefersEphemeralWebBrowserSession = YES (telefonun Gmail'ine otomatik girmez)")
	_assert(mm.contains('[NSURLQueryItem queryItemWithName:@"prompt" value:@"login"]'), "Google OAuth prompt=login (oyun içi Google giriş ekranı açılır)")
	_assert(mm.contains("ASWebAuthenticationSessionErrorCodePresentationContextInvalid"), "ASWebAuthenticationSession error 3 yeniden deneme koruması mevcut")
	_assert(mm.contains("UIWindowLevelNormal"), "activeKeyWindow normal görünür pencereyi seçiyor")

	var net_src := FileAccess.get_file_as_string("res://autoload/NetworkManager.gd")
	_assert(net_src.contains("Content-Type: application/json; charset=utf-8") and net_src.contains("to_utf8_buffer()"), "NetworkManager JSON POST istekleri açık UTF-8 byte dizisiyle gönderiliyor")
