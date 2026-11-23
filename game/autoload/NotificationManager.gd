extends Node
## NotificationManager — Baş Vezir Bildirim Sistemi (iOS Native APNs/Local/BGTask + Web Notification API).
##
## Desteklenen 5 bildirim olayı (yalnızca oyun arka plandayken / kapalıyken kullanıcıya gösterilir):
##   1. Başka bir oyuncu saldırı başlattığında (sunucu APNs push + BGAppRefresh + Web)
##   2. Bir bina inşaatı tamamlandığında (zamanlanmış yerel bildirim)
##   3. Oyuncunun gönderdiği saldırı / casusluk hedefe ulaşıp rapor çıktığında (zamanlanmış yerel bildirim)
##   4. Oyuncuya yeni bir mektup/mesaj geldiğinde (sunucu APNs push + BGAppRefresh + Web)
##   5. Bir köydeki Odun, Taş ve Demir kaynaklarının tümü azami Depo kapasitesine ulaştığında (zamanlanmış yerel bildirim)

const RulesEngineScript := preload("res://scripts/rules/RulesEngine.gd")
const GameLoopScript := preload("res://scripts/core/GameLoop.gd")
const ReportsSceneScript := preload("res://scenes/Reports.gd")

const SETTINGS_FILE := "user://notif_settings.json"
const NOTIF_REQ_USER_PATH := "user://native_notif_req.json"
const NOTIF_STATUS_USER_PATH := "user://native_notif_status.json"
const NOTIF_OPENED_USER_PATH := "user://native_notif_opened.json"
## Web (Vercel tarayıcı) sürümünde bildirim gösterilmez; bildirimler yalnızca native iOS uygulamasında çalışır.
const WEB_NOTIFICATIONS_ENABLED := false

const DEFAULT_FALLBACK_NAMES := {
	"main": "Kale",
	"stone": "Taş Ocağı",
	"wood": "Oduncu Kampı",
	"iron": "Maden Ocağı",
	"storage": "Depo",
	"hide": "Gizli Depo",
	"farm": "Değirmen",
	"barracks": "Kışla",
	"wall": "Sur",
	"market": "Market",
	"stable": "Katır Çiftliği",
	"garage": "Simyager",
	"snob": "Köşk",
	"smith": "Kuyumcu",
	"statue": "Anıt",
}

signal settings_changed(enabled: bool)
signal notification_opened(payload: Dictionary)

var notifications_enabled: bool = true
var permission_requested: bool = false
var permission_granted: bool = false
var apns_token: String = ""
var apns_sandbox: bool = false
var registered_token_user: String = ""
var last_scheduled_notifications: Array[Dictionary] = []
var last_opened_payload: Dictionary = {}

var _resync_timer: Timer = null
var _ios_status_timer: Timer = null
var _req_seq: int = 0
var _perm_prompt_scheduled: bool = false
var _last_sync_hash: String = ""
var _known_web_server_notifs: Dictionary = {}
var _pending_open_payload: Dictionary = {}


func _ready() -> void:
	_load_settings()
	_connect_signals()
	call_deferred("_post_ready_setup")


func _autoload(node_name: String) -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree and (loop as SceneTree).root != null:
		return (loop as SceneTree).root.get_node_or_null(node_name)
	return null


func _connect_signals() -> void:
	var eb := _autoload("EventBus")
	if eb != null:
		for sig_name in [
			"building_started",
			"building_completed",
			"building_torn_down",
			"army_sent",
			"movement_cancelled",
			"state_changed",
			"game_loaded",
		]:
			if eb.has_signal(sig_name):
				var cb := Callable(self, "_on_any_state_event")
				if not eb.is_connected(sig_name, cb):
					eb.connect(sig_name, cb)
	var sm := _autoload("StoreManager")
	if sm != null and sm.has_signal("scroll_used"):
		var scb := Callable(self, "_on_any_state_event")
		if not sm.scroll_used.is_connected(scb):
			sm.scroll_used.connect(scb)
	var auth := _autoload("AuthManager")
	if auth != null and auth.has_signal("auth_state_changed"):
		var acb := Callable(self, "_on_auth_state_changed")
		if not auth.auth_state_changed.is_connected(acb):
			auth.auth_state_changed.connect(acb)


func _post_ready_setup() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _is_ios_device():
		_send_ios_notif_req({"action": "clear_badge"})
		_check_opened_notification_ipc()
		_start_ios_status_poll()
	if notifications_enabled:
		request_resync(0.6)
		_schedule_permission_prompt_if_ready()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if DisplayServer.get_name() != "headless" and is_inside_tree():
			sync_local_notifications_now()
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if DisplayServer.get_name() != "headless" and is_inside_tree():
			if _is_ios_device():
				_send_ios_notif_req({"action": "clear_badge"})
				_check_opened_notification_ipc()
				_poll_ios_status_once()
			request_resync(0.5)


func _is_ios_device() -> bool:
	return OS.get_name() == "iOS" and DisplayServer.get_name() != "headless"


func _on_auth_state_changed(logged_in: bool, _profile: Dictionary) -> void:
	if logged_in:
		_push_bg_fetch_config_to_ios()
		_try_register_push_token_on_server()
		_schedule_permission_prompt_if_ready()
		request_resync(0.8)


func _on_any_state_event(_a = null, _b = null, _c = null, _d = null) -> void:
	if DisplayServer.get_name() == "headless":
		return
	_flush_pending_open_payload()
	_schedule_permission_prompt_if_ready()
	request_resync(1.2)


func _flush_pending_open_payload() -> void:
	if _pending_open_payload.is_empty():
		return
	var gs := _autoload("GameState")
	if gs == null or not gs.has_method("has_active_village") or not bool(gs.call("has_active_village")):
		return
	var p := _pending_open_payload.duplicate(true)
	_pending_open_payload.clear()
	call_deferred("handle_opened_notification", p, true)


# =============================================================================
#  Ayarlar & İzin
# =============================================================================

func is_notifications_enabled() -> bool:
	return notifications_enabled


func set_notifications_enabled(enabled: bool) -> void:
	notifications_enabled = enabled
	_save_settings()
	settings_changed.emit(notifications_enabled)
	if not notifications_enabled:
		last_scheduled_notifications.clear()
		_last_sync_hash = ""
		if DisplayServer.get_name() != "headless":
			_clear_all_platform_notifications()
			_push_bg_fetch_config_to_ios()
			_unregister_push_token_on_server()
	else:
		if DisplayServer.get_name() != "headless":
			request_permission(true)
			_push_bg_fetch_config_to_ios()
			_try_register_push_token_on_server()
		sync_local_notifications_now()


func request_permission(force_prompt: bool = false) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not notifications_enabled:
		return
	if permission_requested and not force_prompt and permission_granted:
		return
	permission_requested = true
	_save_settings()
	if _is_ios_device():
		_send_ios_notif_req({"action": "request_permission"})
		_start_ios_status_poll()
	elif OS.has_feature("web") and WEB_NOTIFICATIONS_ENABLED:
		JavaScriptBridge.eval("""
			(function() {
				if (typeof Notification !== 'undefined' && Notification.permission === 'default' && Notification.requestPermission) {
					try { Notification.requestPermission().catch(function(){}); } catch(e) {}
				}
			})();
		""")


func _schedule_permission_prompt_if_ready() -> void:
	if _perm_prompt_scheduled or not notifications_enabled or permission_requested:
		return
	if DisplayServer.get_name() == "headless":
		return
	var gs := _autoload("GameState")
	if gs == null or not gs.has_method("has_active_village") or not bool(gs.call("has_active_village")):
		return
	var tm := _autoload("TutorialManager")
	if tm != null and tm.has_method("is_tutorial_active") and bool(tm.call("is_tutorial_active")):
		return
	_perm_prompt_scheduled = true
	var tree := get_tree()
	if tree != null:
		tree.create_timer(2.0).timeout.connect(func():
			if is_instance_valid(self):
				request_permission(false)
		)


func _load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_FILE):
		var txt := FileAccess.get_file_as_string(SETTINGS_FILE)
		var parsed = JSON.parse_string(txt)
		if typeof(parsed) == TYPE_DICTIONARY:
			var d := parsed as Dictionary
			notifications_enabled = bool(d.get("enabled", true))
			permission_requested = bool(d.get("permission_requested", false))
			permission_granted = bool(d.get("permission_granted", false))
			apns_token = str(d.get("apns_token", ""))
			apns_sandbox = bool(d.get("apns_sandbox", false))
			registered_token_user = str(d.get("registered_token_user", ""))


func _save_settings() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var payload := {
		"enabled": notifications_enabled,
		"permission_requested": permission_requested,
		"permission_granted": permission_granted,
		"apns_token": apns_token,
		"apns_sandbox": apns_sandbox,
		"registered_token_user": registered_token_user,
	}
	var f := FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(payload))
		f.close()


# =============================================================================
#  5 Yerel / Zamanlanmış Vezir Bildirimlerinin Hesabı
# =============================================================================

static func _norm_owner(raw: String) -> String:
	var n := raw.strip_edges()
	while n.length() >= 10 and n.substr(0, 10).to_lower() == "lord lord ":
		n = n.substr(5).strip_edges()
	return n.to_lower()


static func _building_tr_name(key: String) -> String:
	var gd = Engine.get_main_loop().root.get_node_or_null("GameData") if Engine.get_main_loop() is SceneTree else null
	if gd != null and gd.has_method("get_building_name"):
		var n := str(gd.call("get_building_name", key)).strip_edges()
		if not n.is_empty() and n != key:
			return n
	return str(DEFAULT_FALLBACK_NAMES.get(key, key.capitalize()))


static func _fmt_cap_num(val: int) -> String:
	if absi(val) < 1000:
		return str(val)
	var s := str(absi(val))
	var out := ""
	var c := 0
	for idx in range(s.length() - 1, -1, -1):
		out = s[idx] + out
		c += 1
		if c % 3 == 0 and idx > 0:
			out = "." + out
	return ("-" + out) if val < 0 else out


## Verilen oyun durumu için gelecekte çalacak tüm Baş Vezir bildirimlerini üretir.
## Kapsam:
##   - build_complete: Oyuncunun köyündeki her inşaat kuyruğu bittiğinde
##   - attack_report: Oyuncunun gönderdiği saldırı/akın/casusluk hedef köye ulaşıp rapor oluştuğunda
##   - storage_full: Bir köyde Odun, Taş ve Demir kaynaklarının TÜMÜ max Depo seviyesine ulaştığında
static func compute_local_notifications(state: Dictionary, now_unix: int) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	if typeof(state) != TYPE_DICTIONARY or state.is_empty():
		return items

	var player_dict: Dictionary = state.get("player", {}) if typeof(state.get("player")) == TYPE_DICTIONARY else {}
	var p_low := _norm_owner(str(player_dict.get("name", "")))
	var villages_raw = state.get("villages", [])
	var villages_arr: Array = villages_raw if typeof(villages_raw) == TYPE_ARRAY else []

	var v_by_id: Dictionary = {}
	var player_vids: Dictionary = {}
	for v_item in villages_arr:
		if typeof(v_item) != TYPE_DICTIONARY:
			continue
		var vd := v_item as Dictionary
		var vid := int(vd.get("id", -1))
		if vid < 0:
			continue
		v_by_id[vid] = vd
		if bool(vd.get("is_bot", false)) or bool(vd.get("is_barbarian", false)):
			continue
		var v_owner := _norm_owner(str(vd.get("owner", "")))
		if p_low.is_empty() or v_owner == p_low:
			player_vids[vid] = vd

	if player_vids.is_empty():
		return items

	# 1) İnşaat Tamamlanma Bildirimleri
	var queues_raw = state.get("queues", [])
	var queues_arr: Array = queues_raw if typeof(queues_raw) == TYPE_ARRAY else []
	for q_item in queues_arr:
		if typeof(q_item) != TYPE_DICTIONARY:
			continue
		var q := q_item as Dictionary
		if str(q.get("type", "")) != "build":
			continue
		var q_vid := int(q.get("village_id", -1))
		if not player_vids.has(q_vid):
			continue
		var finish_u := int(q.get("finish_unix", 0))
		var delay_s := finish_u - now_unix
		if delay_s <= 1:
			continue
		var vd := player_vids[q_vid] as Dictionary
		var v_name := str(vd.get("name", "Köyünüz"))
		var b_key := str(q.get("key", ""))
		var b_name := _building_tr_name(b_key)
		var tgt_lvl := int(q.get("target_level", 1))
		items.append({
			"id": "tvk_build_%d_%s_%d" % [q_vid, b_key, tgt_lvl],
			"type": "build_complete",
			"trigger_unix": finish_u,
			"delay_seconds": delay_s,
			"title": "📜 Baş Vezir: İnşaat Tamamlandı!",
			"body": "Lordum, %s köyündeki %s (Sv. %d) yükseldi! Ustalarınız yeni inşaat emri bekliyor — hemen tahtınıza dönün!" % [v_name, b_name, tgt_lvl],
			"route": "village",
			"village_id": q_vid,
		})

	# 2) Saldırı Karşı Köye Ulaştığında (Rapor Oluştuğunda) Bildirim
	var movs_raw = state.get("movements", [])
	var movs_arr: Array = movs_raw if typeof(movs_raw) == TYPE_ARRAY else []
	for m_item in movs_arr:
		if typeof(m_item) != TYPE_DICTIONARY:
			continue
		var m := m_item as Dictionary
		var m_state := str(m.get("state", "outgoing"))
		var m_type := str(m.get("type", ""))
		if m_state == "returning" or m_type == "return":
			continue
		if not (m_type in ["attack", "raid", "spy"]):
			continue
		var from_vid := int(m.get("from_village_id", m.get("village_id", -1)))
		if not player_vids.has(from_vid):
			continue
		var arrive_u := int(m.get("arrive_unix", 0))
		var delay_s := arrive_u - now_unix
		if delay_s <= 1:
			continue
		var to_vid := int(m.get("to_village_id", -1))
		var tv := v_by_id.get(to_vid, {}) as Dictionary
		var target_label := "%s (%d|%d)" % [str(tv.get("name", "Düşman Köyü")), int(tv.get("x", 0)), int(tv.get("y", 0))] if not tv.is_empty() else "hedef köye"
		var m_id := int(m.get("id", 0))
		var title_txt := "⚔️ Baş Vezir: Savaş Raporunuz Hazır!"
		var body_txt := "Lordum, ordunuz %s hedefine ulaştı ve çarpışma raporu masanıza geldi! Zaferi ve ganimeti görmek için tıklayın!" % target_label
		if m_type == "raid":
			title_txt = "💰 Baş Vezir: Yağma Raporunuz Hazır!"
			body_txt = "Lordum, akıncılarınız %s köyüne vardı! Yağma raporunu ve toplanan ganimeti inceleyin!" % target_label
		elif m_type == "spy":
			title_txt = "🕵️ Baş Vezir: Casusluk Raporunuz Hazır!"
			body_txt = "Lordum, casusunuz %s köyünden istihbarat getirdi! Sırları görmek için raporu hemen okuyun!" % target_label
		items.append({
			"id": "tvk_atk_%d_%d_%d" % [from_vid, to_vid, arrive_u] if m_id <= 0 else "tvk_atk_%d_%d" % [m_id, arrive_u],
			"type": "attack_report",
			"trigger_unix": arrive_u,
			"delay_seconds": delay_s,
			"title": title_txt,
			"body": body_txt,
			"route": "reports",
			"village_id": from_vid,
		})

	# 3) Tüm Kaynaklar (Odun + Taş + Demir) Max Depo Seviyesine Ulaştığında Bildirim
	for p_vid in player_vids.keys():
		var vd := player_vids[p_vid] as Dictionary
		var blds: Dictionary = vd.get("buildings", {}) if typeof(vd.get("buildings")) == TYPE_DICTIONARY else {}
		var res: Dictionary = vd.get("resources", {}) if typeof(vd.get("resources")) == TYPE_DICTIONARY else {}
		var st_lvl := maxi(1, int(blds.get("storage", 1)))
		var cap := maxi(1000, int(RulesEngineScript.storage_capacity(st_lvl)))

		var all_already_full := true
		var max_fill_sec := 0
		var impossible := false
		for rk in ["wood", "stone", "iron"]:
			var cur_val := float(res.get(rk, 0.0))
			if cur_val >= float(cap):
				continue
			all_already_full = false
			var b_lvl := int(blds.get(rk, 0))
			var per_hr := float(RulesEngineScript.production_per_hour(rk, b_lvl))
			var per_sec := per_hr / 3600.0
			if per_sec <= 0.0:
				impossible = true
				break
			var rem_sec := int(ceil((float(cap) - cur_val) / per_sec))
			if rem_sec > max_fill_sec:
				max_fill_sec = rem_sec

		if impossible or all_already_full:
			continue
		if max_fill_sec > 10 and max_fill_sec <= 30 * 86400:
			var v_name := str(vd.get("name", "Köyünüz"))
			items.append({
				"id": "tvk_full_%d" % int(p_vid),
				"type": "storage_full",
				"trigger_unix": now_unix + max_fill_sec,
				"delay_seconds": max_fill_sec,
				"title": "🏛️ Baş Vezir: Ambarlarınız Taşıyor!",
				"body": "Lordum, %s köyünüzde Odun, Taş ve Demir ambarları tamamen doldu (%s)! Üretim boşa gitmeden harcayın ya da Depo'yu yükseltin!" % [v_name, _fmt_cap_num(cap)],
				"route": "village",
				"village_id": int(p_vid),
			})

	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("delay_seconds", 0)) < int(b.get("delay_seconds", 0))
	)
	if items.size() > 40:
		items.resize(40)
	return items


func request_resync(delay_sec: float = 1.2) -> void:
	if not notifications_enabled:
		return
	if _resync_timer == null:
		_resync_timer = Timer.new()
		_resync_timer.one_shot = true
		_resync_timer.timeout.connect(sync_local_notifications_now)
		add_child(_resync_timer)
	_resync_timer.start(maxf(0.1, delay_sec))


func sync_local_notifications_now() -> void:
	if not notifications_enabled:
		last_scheduled_notifications.clear()
		if DisplayServer.get_name() != "headless":
			_clear_all_platform_notifications()
		return
	var gs := _autoload("GameState")
	if gs == null or not gs.has_method("has_active_village") or not bool(gs.call("has_active_village")):
		return
	var now_u := int(Time.get_unix_time_from_system())
	if GameLoopScript.instance != null and GameLoopScript.instance.now_unix() > 0:
		var sim_u := int(GameLoopScript.instance.now_unix())
		if absi(sim_u - now_u) <= 300:
			now_u = sim_u
	var state: Dictionary = gs.as_live_dict() if gs.has_method("as_live_dict") else gs.to_dict()
	var items := compute_local_notifications(state, now_u)
	last_scheduled_notifications = items

	if DisplayServer.get_name() == "headless":
		return

	var sig_parts: Array[String] = []
	for it in items:
		var trig_u := int(it.get("trigger_unix", 0))
		if str(it.get("type", "")) == "storage_full":
			trig_u = (trig_u / 30) * 30
		sig_parts.append("%s@%d" % [str(it.get("id", "")), trig_u])
	var sig := "|".join(sig_parts)
	if sig == _last_sync_hash:
		return
	_last_sync_hash = sig

	if _is_ios_device():
		_send_ios_notif_req({
			"action": "sync_local",
			"items": items,
		})
	elif OS.has_feature("web") and WEB_NOTIFICATIONS_ENABLED:
		_sync_web_local_timers(items)


func _clear_all_platform_notifications() -> void:
	if _is_ios_device():
		_send_ios_notif_req({"action": "clear_all_local"})
	elif OS.has_feature("web"):
		JavaScriptBridge.eval("""
			(function() {
				if (window.__tvkNotifTimers) {
					window.__tvkNotifTimers.forEach(function(id) { clearTimeout(id); });
				}
				window.__tvkNotifTimers = [];
			})();
		""")


# =============================================================================
#  Web Notification API Desteği
# =============================================================================

func _sync_web_local_timers(items: Array[Dictionary]) -> void:
	var json_items := JSON.stringify(items)
	var js := """
		(function() {
			if (window.__tvkNotifTimers) {
				window.__tvkNotifTimers.forEach(function(id) { clearTimeout(id); });
			}
			window.__tvkNotifTimers = [];
			if (typeof Notification === 'undefined' || Notification.permission !== 'granted') return;
			var items = %s;
			items.forEach(function(it) {
				var ms = Math.max(1000, Number(it.delay_seconds || 0) * 1000);
				if (ms > 2147000000) return;
				var tid = setTimeout(function() {
					if (!document.hidden) return;
					try {
						var n = new Notification(String(it.title || 'Baş Vezir'), {
							body: String(it.body || ''),
							tag: String(it.id || 'tvk')
						});
						n.onclick = function() {
							try { window.focus(); } catch(e) {}
							window.__tvkLastOpenedNotif = {
								route: String(it.route || 'village'),
								village_id: Number(it.village_id || -1),
								type: String(it.type || '')
							};
							n.close();
						};
					} catch(e) {}
				}, ms);
				window.__tvkNotifTimers.push(tid);
			});
		})();
	""" % json_items
	JavaScriptBridge.eval(js)


func notify_web_background_event(notif_type: String, title: String, body: String, route: String = "village", village_id: int = -1, dedup_key: String = "") -> void:
	if not notifications_enabled:
		return
	if not WEB_NOTIFICATIONS_ENABLED:
		return
	if not OS.has_feature("web") or DisplayServer.get_name() == "headless":
		return
	var dkey := dedup_key if not dedup_key.is_empty() else ("%s|%s|%s" % [notif_type, title, body])
	if _known_web_server_notifs.has(dkey):
		return
	_known_web_server_notifs[dkey] = true
	if _known_web_server_notifs.size() > 150:
		_known_web_server_notifs.clear()
		_known_web_server_notifs[dkey] = true
	var payload_str := JSON.stringify({
		"title": title,
		"body": body,
		"tag": dkey,
		"route": route,
		"village_id": village_id,
		"type": notif_type,
	})
	JavaScriptBridge.eval("""
		(function() {
			if (typeof Notification === 'undefined' || Notification.permission !== 'granted') return;
			if (!document.hidden) return;
			var p = %s;
			try {
				var n = new Notification(String(p.title || 'Baş Vezir'), { body: String(p.body || ''), tag: String(p.tag || 'tvk') });
				n.onclick = function() {
					try { window.focus(); } catch(e) {}
					window.__tvkLastOpenedNotif = { route: p.route, village_id: p.village_id, type: p.type };
					n.close();
				};
			} catch(e) {}
		})();
	""" % payload_str)


# =============================================================================
#  Bildirime Tıklayınca Oyun İçi Yönlendirme
# =============================================================================

func handle_opened_notification(payload: Dictionary, change_scene: bool = true) -> void:
	if typeof(payload) != TYPE_DICTIONARY or payload.is_empty():
		return
	last_opened_payload = payload.duplicate(true)
	notification_opened.emit(last_opened_payload)
	var route := str(payload.get("route", "village")).strip_edges().to_lower()
	var vid := int(payload.get("village_id", -1))
	var gs := _autoload("GameState")
	if vid > 0 and gs != null and gs.has_method("get_player_villages"):
		for pv in gs.call("get_player_villages"):
			if typeof(pv) == TYPE_DICTIONARY and int((pv as Dictionary).get("id", -1)) == vid:
				gs.call("set_active_village", vid)
				break
	if not change_scene or not is_inside_tree() or get_tree() == null:
		return
	if gs == null or not gs.has_method("has_active_village") or not bool(gs.call("has_active_village")):
		_pending_open_payload = last_opened_payload.duplicate(true)
		return
	if route == "messages":
		ReportsSceneScript.initial_tab = "messages"
		get_tree().change_scene_to_file("res://scenes/Reports.tscn")
	elif route == "reports":
		ReportsSceneScript.initial_tab = "reports"
		get_tree().change_scene_to_file("res://scenes/Reports.tscn")
	elif route == "village":
		if gs != null and gs.has_method("has_active_village") and bool(gs.call("has_active_village")):
			get_tree().change_scene_to_file("res://scenes/Village.tscn")


# =============================================================================
#  iOS Native Bridge IPC & APNs Token Kaydı
# =============================================================================

func _candidate_ipc_paths(user_path: String, file_name: String) -> Array[String]:
	var paths: Array[String] = [user_path]
	var docs_dir := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if not docs_dir.is_empty():
		paths.append(docs_dir.path_join(file_name))
	return paths


func _send_ios_notif_req(payload: Dictionary) -> void:
	if not _is_ios_device():
		return
	_req_seq += 1
	var data := payload.duplicate(true)
	data["req_id"] = "notif_%d_%d" % [int(Time.get_unix_time_from_system()), _req_seq]
	var json_str := JSON.stringify(data)
	for path in _candidate_ipc_paths(NOTIF_REQ_USER_PATH, "native_notif_req.json"):
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f != null:
			f.store_string(json_str)
			f.close()


func _read_ipc_json(user_path: String, file_name: String, remove_after: bool) -> Dictionary:
	for path in _candidate_ipc_paths(user_path, file_name):
		if FileAccess.file_exists(path):
			var txt := FileAccess.get_file_as_string(path)
			var parsed = JSON.parse_string(txt)
			if remove_after:
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			if typeof(parsed) == TYPE_DICTIONARY:
				return parsed as Dictionary
	return {}


func _start_ios_status_poll() -> void:
	if not _is_ios_device():
		return
	if _ios_status_timer == null:
		_ios_status_timer = Timer.new()
		_ios_status_timer.wait_time = 2.0
		_ios_status_timer.timeout.connect(_poll_ios_status_once)
		add_child(_ios_status_timer)
	if _ios_status_timer.is_stopped():
		_ios_status_timer.start()


func _poll_ios_status_once() -> void:
	if not _is_ios_device():
		return
	_check_opened_notification_ipc()
	var st := _read_ipc_json(NOTIF_STATUS_USER_PATH, "native_notif_status.json", false)
	if st.is_empty():
		return
	var auth_status := str(st.get("auth_status", ""))
	if auth_status == "authorized" or auth_status == "provisional":
		if not permission_granted:
			permission_granted = true
			_save_settings()
	elif auth_status == "denied":
		permission_granted = false
		_save_settings()
	var tok := str(st.get("device_token", "")).strip_edges()
	var sb := bool(st.get("sandbox", false))
	if not tok.is_empty() and (tok != apns_token or sb != apns_sandbox):
		apns_token = tok
		apns_sandbox = sb
		_save_settings()
		_try_register_push_token_on_server()
	if not apns_token.is_empty() and not registered_token_user.is_empty() and _ios_status_timer != null:
		_ios_status_timer.stop()


func _check_opened_notification_ipc() -> void:
	if not _is_ios_device():
		return
	var opened := _read_ipc_json(NOTIF_OPENED_USER_PATH, "native_notif_opened.json", true)
	if not opened.is_empty():
		call_deferred("handle_opened_notification", opened, true)


func _push_bg_fetch_config_to_ios() -> void:
	if not _is_ios_device():
		return
	var net := _autoload("NetworkManager")
	var auth := _autoload("AuthManager")
	var srv := str(net.get("server_url")) if net != null else "https://92.5.113.251.nip.io/tahtkilic"
	var tok := str(net.get("auth_token")) if net != null else ""
	if tok.is_empty() and auth != null:
		tok = str(auth.get("auth_token"))
	_send_ios_notif_req({
		"action": "configure_bg_fetch",
		"server_url": srv,
		"auth_token": tok,
		"enabled": notifications_enabled and not tok.is_empty(),
	})


func _try_register_push_token_on_server() -> void:
	if not notifications_enabled or apns_token.is_empty():
		return
	if DisplayServer.get_name() == "headless":
		return
	var net := _autoload("NetworkManager")
	var auth := _autoload("AuthManager")
	if net == null or not net.has_method("api_request"):
		return
	var tok := str(net.get("auth_token"))
	if tok.is_empty() or auth == null or not bool(auth.get("is_logged_in")):
		return
	var u_name := str(auth.get("display_name"))
	if registered_token_user == ("%s:%s:%s" % [u_name, apns_token, str(apns_sandbox)]):
		return
	net.call("api_request", "/api/notifications/register", HTTPClient.METHOD_POST, {
		"platform": "ios",
		"token": apns_token,
		"sandbox": apns_sandbox,
	}, func(ok: bool, _res: Dictionary):
		if ok and is_instance_valid(self):
			registered_token_user = "%s:%s:%s" % [u_name, apns_token, str(apns_sandbox)]
			_save_settings()
	)


func _unregister_push_token_on_server() -> void:
	var net := _autoload("NetworkManager")
	if net == null or not net.has_method("api_request"):
		return
	var tok := str(net.get("auth_token"))
	if tok.is_empty():
		return
	net.call("api_request", "/api/notifications/unregister", HTTPClient.METHOD_POST, {
		"token": apns_token,
	}, Callable())
	registered_token_user = ""
	_save_settings()


func on_user_logout() -> void:
	if DisplayServer.get_name() != "headless":
		_unregister_push_token_on_server()
		_clear_all_platform_notifications()
		_send_ios_notif_req({
			"action": "configure_bg_fetch",
			"server_url": "",
			"auth_token": "",
			"enabled": false,
		})
	registered_token_user = ""
	_last_sync_hash = ""
	last_scheduled_notifications.clear()
	_save_settings()
