extends Node
## LordManager — Lord (Kahraman) durumu, 13 ekipman slotu, envanter tekilliği,
## +0..+8 geliştirme mekaniği, parşömen satın alma, yaralanma/iyileşme ve konuşma balonu kuyruğu.

signal lord_changed()
signal speech_queued(entry: Dictionary)
signal upgrade_finished(result: Dictionary)
signal lord_recovered()

const LordModelScript := preload("res://scripts/model/LordModel.gd")

const MAX_SPEECH_QUEUE := 12

var _tick_accum: float = 0.0
var _recovery_hook_connected: bool = false


func _ready() -> void:
	ensure_lord_state()
	call_deferred("_connect_hooks")


func _connect_hooks() -> void:
	if _recovery_hook_connected:
		return
	var eb := _autoload("EventBus")
	if eb != null and eb.has_signal("state_changed") and not eb.state_changed.is_connected(_on_state_changed):
		eb.state_changed.connect(_on_state_changed)
		_recovery_hook_connected = true


func _process(delta: float) -> void:
	_tick_accum += delta
	if _tick_accum < 5.0:
		return
	_tick_accum = 0.0
	var gs := _autoload("GameState")
	if gs == null or typeof(gs.get("player")) != TYPE_DICTIONARY:
		return
	var ld_raw = (gs.get("player") as Dictionary).get("lord")
	if typeof(ld_raw) != TYPE_DICTIONARY or int((ld_raw as Dictionary).get("injured_until_unix", 0)) <= 0:
		return
	tick_recovery()


func _autoload(node_name: String) -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree and (loop as SceneTree).root != null:
		return (loop as SceneTree).root.get_node_or_null(node_name)
	return null


func _now_unix() -> int:
	var real_now := int(Time.get_unix_time_from_system())
	var gs := _autoload("GameState")
	if gs != null and typeof(gs.get("world")) == TYPE_DICTIONARY:
		var w := gs.get("world") as Dictionary
		var sim_now := int(w.get("sim_now_unix", 0))
		if sim_now > real_now:
			return sim_now
	return real_now


func _persist_and_notify(emit_bus: bool = true) -> void:
	var gs := _autoload("GameState")
	if gs != null and typeof(gs.get("player")) == TYPE_DICTIONARY:
		var p := gs.get("player") as Dictionary
		var ld := ensure_lord_state()
		ld["updated_unix"] = _now_unix()
		p["lord"] = ld
		if typeof(p.get("scrolls")) != TYPE_DICTIONARY:
			p["scrolls"] = {}
		var sc_cnt := maxi(0, int(ld.get("upgrade_scrolls", 0)))
		var p_scrolls := p["scrolls"] as Dictionary
		if sc_cnt > 0:
			p_scrolls["lord_upgrade_scroll"] = sc_cnt
		else:
			p_scrolls.erase("lord_upgrade_scroll")
	var sm_store := _autoload("StoreManager")
	if sm_store != null and sm_store.has_method("_sync_cached_wallet"):
		sm_store.call("_sync_cached_wallet")
	var wm := _autoload("WorldManager")
	if wm != null and wm.has_method("notify_local_mutation"):
		wm.call("notify_local_mutation")
	if wm != null and wm.has_method("request_save_active_world"):
		wm.call("request_save_active_world", true)
	var sm := _autoload("SaveManager")
	if sm != null and sm.has_method("request_save_game"):
		sm.call("request_save_game")
	lord_changed.emit()
	if emit_bus:
		var eb := _autoload("EventBus")
		if eb != null and eb.has_signal("state_changed"):
			eb.state_changed.emit()


func _on_state_changed() -> void:
	var ld := ensure_lord_state()
	lord_changed.emit()
	var q := ld.get("speech_queue", []) as Array
	if not q.is_empty():
		speech_queued.emit(q[0] as Dictionary)


func ensure_lord_state() -> Dictionary:
	var gs := _autoload("GameState")
	if gs == null:
		return LordModelScript.default_lord_state()
	if typeof(gs.get("player")) != TYPE_DICTIONARY:
		gs.set("player", {})
	var p := gs.get("player") as Dictionary
	var cleaned := LordModelScript.ensure_state_dict(p.get("lord", null))
	p["lord"] = cleaned
	return cleaned


func get_lord_state() -> Dictionary:
	return ensure_lord_state()


func get_lord_stats() -> Dictionary:
	return LordModelScript.compute_lord_stats(ensure_lord_state())


func get_scroll_count() -> int:
	return maxi(0, int(ensure_lord_state().get("upgrade_scrolls", 0)))


func add_upgrade_scrolls(qty: int) -> int:
	if qty <= 0:
		return get_scroll_count()
	var ld := ensure_lord_state()
	ld["upgrade_scrolls"] = maxi(0, int(ld.get("upgrade_scrolls", 0))) + qty
	_persist_and_notify(true)
	return int(ld["upgrade_scrolls"])


func is_injured(now_u: int = 0) -> bool:
	var now := now_u if now_u > 0 else _now_unix()
	var ld := ensure_lord_state()
	return int(ld.get("injured_until_unix", 0)) > now


func get_injury_remaining_secs(now_u: int = 0) -> int:
	var now := now_u if now_u > 0 else _now_unix()
	var ld := ensure_lord_state()
	return maxi(0, int(ld.get("injured_until_unix", 0)) - now)


func get_equipped_item(slot_key: String) -> Dictionary:
	var ld := ensure_lord_state()
	var eq := ld.get("equipped", {}) as Dictionary
	var iid := str(eq.get(slot_key, ""))
	if iid.is_empty():
		return {}
	return LordModelScript.find_item_in_list(ld.get("inventory", []) as Array, iid)


func get_item_by_id(item_id: String) -> Dictionary:
	var ld := ensure_lord_state()
	return LordModelScript.find_item_in_list(ld.get("inventory", []) as Array, item_id)


func get_unequipped_items(slot_type_filter: String = "") -> Array[Dictionary]:
	return LordModelScript.get_unequipped_inventory(ensure_lord_state(), slot_type_filter)


func equip_item(slot_key: String, item_id: String) -> Dictionary:
	var ld := ensure_lord_state()
	var sdef := LordModelScript.get_slot_def(slot_key)
	if sdef.is_empty():
		return {"ok": false, "error": "Geçersiz ekipman slotu."}
	var item := LordModelScript.find_item_in_list(ld["inventory"] as Array, item_id)
	if item.is_empty():
		return {"ok": false, "error": "Eşya envanterde bulunamadı."}
	if str(item.get("slot_type", "")) != str(sdef.get("slot_type", "")):
		return {"ok": false, "error": "Bu eşya %s slotuna takılamaz." % str(sdef.get("name", slot_key))}

	var eq := ld["equipped"] as Dictionary
	# Aynı item başka slotta takılıysa önce oradan çıkar (kopyalama/çift takma imkansız)
	var old_slot := LordModelScript.equipped_slot_of(ld, item_id)
	if not old_slot.is_empty():
		eq[old_slot] = ""
	eq[slot_key] = item_id
	_persist_and_notify(false)
	return {"ok": true, "slot_key": slot_key, "item": item, "stats": LordModelScript.compute_lord_stats(ld)}


func unequip_slot(slot_key: String) -> Dictionary:
	var ld := ensure_lord_state()
	var sdef := LordModelScript.get_slot_def(slot_key)
	if sdef.is_empty():
		return {"ok": false, "error": "Geçersiz ekipman slotu."}
	var eq := ld["equipped"] as Dictionary
	var iid := str(eq.get(slot_key, ""))
	if iid.is_empty():
		return {"ok": false, "error": "Bu slotta takılı eşya yok."}
	eq[slot_key] = ""
	_persist_and_notify(false)
	return {"ok": true, "slot_key": slot_key, "stats": LordModelScript.compute_lord_stats(ld)}


func preview_upgrade(item_id: String) -> Dictionary:
	var ld := ensure_lord_state()
	var item := LordModelScript.find_item_in_list(ld["inventory"] as Array, item_id)
	if item.is_empty():
		return {"ok": false, "error": "Eşya bulunamadı."}
	if LordModelScript.is_item_equipped(ld, item_id):
		return {"ok": false, "error": "Takılı eşya geliştirilemez. Önce eşyayı çıkarın."}
	var cur_plus := int(item.get("plus", 0))
	if cur_plus >= LordModelScript.MAX_PLUS:
		return {"ok": false, "error": "Bu eşya maksimum (+%d) seviyede." % LordModelScript.MAX_PLUS}
	var next_plus := cur_plus + 1
	var rate := LordModelScript.upgrade_rate_for_plus(cur_plus)
	return {
		"ok": true,
		"item": item.duplicate(true),
		"cur_plus": cur_plus,
		"next_plus": next_plus,
		"rate": rate,
		"destroys_on_fail": rate < 100,
		"current_stats": LordModelScript.compute_item_stats(item, cur_plus),
		"preview_stats": LordModelScript.compute_item_stats(item, next_plus),
	}


func upgrade_item(item_id: String, force_roll: int = -1) -> Dictionary:
	var ld := ensure_lord_state()
	var inv := ld["inventory"] as Array
	var item_idx := -1
	for i in range(inv.size()):
		if typeof(inv[i]) == TYPE_DICTIONARY and str((inv[i] as Dictionary).get("id", "")) == item_id:
			item_idx = i
			break
	if item_idx < 0:
		return {"ok": false, "error": "Eşya envanterde bulunamadı."}
	if LordModelScript.is_item_equipped(ld, item_id):
		return {"ok": false, "error": "Takılı eşyalar geliştirilemez. Önce eşyayı çıkarın."}

	var item := inv[item_idx] as Dictionary
	var cur_plus := int(item.get("plus", 0))
	if cur_plus >= LordModelScript.MAX_PLUS:
		return {"ok": false, "error": "Eşya zaten maksimum (+%d) seviyede." % LordModelScript.MAX_PLUS}

	var scrolls := maxi(0, int(ld.get("upgrade_scrolls", 0)))
	if scrolls < 1:
		return {"ok": false, "error": "Envanterde Geliştirme Parşömeni yok."}

	var rate := LordModelScript.upgrade_rate_for_plus(cur_plus)
	var roll := force_roll
	if roll < 1 or roll > 100:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		roll = rng.randi_range(1, 100)

	# Önce parşömeni tüket (kopyalama koruması)
	var next_scrolls := maxi(0, scrolls - 1)
	ld["upgrade_scrolls"] = next_scrolls
	var gs := _autoload("GameState")
	if gs != null and typeof(gs.get("player")) == TYPE_DICTIONARY:
		var p := gs.get("player") as Dictionary
		if typeof(p.get("scrolls")) != TYPE_DICTIONARY:
			p["scrolls"] = {}
		var p_scrolls := p["scrolls"] as Dictionary
		if next_scrolls > 0:
			p_scrolls["lord_upgrade_scroll"] = next_scrolls
		else:
			p_scrolls.erase("lord_upgrade_scroll")

	var success := roll <= rate
	var res: Dictionary
	if success:
		var new_plus := cur_plus + 1
		item["plus"] = new_plus
		res = {
			"ok": true,
			"upgraded": true,
			"destroyed": false,
			"rate": rate,
			"roll": roll,
			"old_plus": cur_plus,
			"new_plus": new_plus,
			"scrolls_left": int(ld["upgrade_scrolls"]),
			"item": item.duplicate(true),
		}
	else:
		# Başarısız: eşya ve parşömen kalıcı olarak yanar/yok olur
		inv.remove_at(item_idx)
		res = {
			"ok": true,
			"upgraded": false,
			"destroyed": true,
			"rate": rate,
			"roll": roll,
			"old_plus": cur_plus,
			"new_plus": -1,
			"scrolls_left": int(ld["upgrade_scrolls"]),
			"item": item.duplicate(true),
		}

	if DisplayServer.get_name() != "headless":
		var net := _autoload("NetworkManager")
		if net != null and not str(net.get("auth_token")).is_empty() and net.has_method("api_request"):
			net.api_request("/api/store/use_scroll", HTTPClient.METHOD_POST, {
				"scroll_id": "lord_upgrade_scroll",
				"category": "lord",
			}, Callable())

	_persist_and_notify(true)
	upgrade_finished.emit(res)
	return res


func buy_scroll_with_resources() -> Dictionary:
	var gs := _autoload("GameState")
	if gs == null or not gs.has_method("get_active_village"):
		return {"ok": false, "error": "Aktif köy bulunamadı."}
	var v: Dictionary = gs.call("get_active_village")
	if v.is_empty():
		return {"ok": false, "error": "Aktif köy bulunamadı."}
	if typeof(v.get("resources")) != TYPE_DICTIONARY:
		return {"ok": false, "error": "Köy deposu hazır değil."}
	var res := v["resources"] as Dictionary
	var cost: Dictionary = LordModelScript.SCROLL_RESOURCE_COST
	for rk in ["wood", "stone", "iron"]:
		var need := int(cost.get(rk, 5000))
		var have := int(floor(float(res.get(rk, 0))))
		if have < need:
			return {"ok": false, "error": "Yetersiz hammadde! Her hammaddeden 5.000 adet gerekir."}

	for rk in ["wood", "stone", "iron"]:
		var need := int(cost.get(rk, 5000))
		res[rk] = maxi(0.0, float(res.get(rk, 0)) - float(need))

	var ld := ensure_lord_state()
	ld["upgrade_scrolls"] = maxi(0, int(ld.get("upgrade_scrolls", 0))) + 1
	var vid := int(v.get("id", -1))
	if gs.has_method("_emit_resources_changed"):
		gs.call("_emit_resources_changed", vid)
	_persist_and_notify(true)
	return {"ok": true, "scrolls_left": int(ld["upgrade_scrolls"]), "error": ""}


func grant_bandit_drop(bandit_level: int, village_name: String = "", seed_hint: int = 0) -> Dictionary:
	var ld := ensure_lord_state()
	var rng := RandomNumberGenerator.new()
	if seed_hint != 0:
		rng.seed = seed_hint
	else:
		rng.randomize()
	var seq := maxi(1, int(ld.get("next_item_seq", 1)))
	ld["next_item_seq"] = seq + 1
	var item := LordModelScript.roll_bandit_drop(bandit_level, rng, seq, village_name, _now_unix())
	(ld["inventory"] as Array).append(item)

	var prev_hi := int(ld.get("highest_bandit_cleared", 0))
	var lvl := clampi(bandit_level, 1, 10)
	if lvl > prev_hi:
		ld["highest_bandit_cleared"] = lvl
		if lvl < 10 and (lvl == 3 or lvl == 5 or lvl == 7):
			push_speech(
				"bandit_unlock",
				"Yeni Haydut Seviyesi!",
				"Sv.%d Haydut Köyünü aştın! Haritada Sv.%d+ köylerinden daha nadir ganimet düşürebilirsin." % [lvl, lvl + 1],
				"lord_screen",
				""
			)

	var rar_tr := LordModelScript.rarity_label(str(item.get("rarity", "common")))
	push_speech(
		"item_drop",
		"Yeni Ekipman Kazandın!",
		"%s yağmasından [%s] %s (+%d) elde ettin!" % [
			village_name if not village_name.is_empty() else ("Haydut Köyü Sv.%d" % lvl),
			rar_tr,
			str(item.get("name", "Ekipman")),
			int(item.get("plus", 0)),
		],
		"item_detail",
		str(item.get("id", ""))
	)
	_persist_and_notify(true)
	return item


func grant_minigame_accessory(slot_type: String = "", rarity: String = "uncommon", plus: int = 0) -> Dictionary:
	var ld := ensure_lord_state()
	var st := slot_type
	if not (st in LordModelScript.ACCESSORY_SLOTS):
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		st = LordModelScript.ACCESSORY_SLOTS[rng.randi_range(0, LordModelScript.ACCESSORY_SLOTS.size() - 1)]
	var seq := maxi(1, int(ld.get("next_item_seq", 1)))
	ld["next_item_seq"] = seq + 1
	var item := LordModelScript.create_item(st, rarity, plus, seq, "Mini Oyun Ödülü", _now_unix())
	(ld["inventory"] as Array).append(item)
	push_speech(
		"minigame_reward",
		"Mini Oyun Aksesuarı!",
		"[%s] %s (+%d) Lord envanterine eklendi!" % [
			LordModelScript.rarity_label(str(item.get("rarity", "uncommon"))),
			str(item.get("name", "Aksesuar")),
			int(item.get("plus", 0)),
		],
		"item_detail",
		str(item.get("id", ""))
	)
	_persist_and_notify(true)
	return item


func grant_tutorial_starter_kit() -> Dictionary:
	var ld := ensure_lord_state()
	if bool(ld.get("tutorial_kit_granted", false)):
		return {"ok": true, "already_granted": true, "sword_id": _find_starter_sword_id(ld)}

	ld["tutorial_kit_granted"] = true
	var seq := maxi(1, int(ld.get("next_item_seq", 1)))
	var sword := LordModelScript.create_item("sword", "common", 0, seq, "Eğitim Başlangıcı", _now_unix())
	sword["name"] = "Acemi Lord Kılıcı"
	seq += 1
	var helmet := LordModelScript.create_item("helmet", "common", 0, seq, "Eğitim Başlangıcı", _now_unix())
	seq += 1
	var chest := LordModelScript.create_item("chest", "common", 0, seq, "Eğitim Başlangıcı", _now_unix())
	seq += 1
	ld["next_item_seq"] = seq

	var inv := ld["inventory"] as Array
	inv.append(sword)
	inv.append(helmet)
	inv.append(chest)
	ld["upgrade_scrolls"] = maxi(1, int(ld.get("upgrade_scrolls", 0)) + 1)

	push_speech(
		"tutorial_gear",
		"Lord Teçhizatı Hazır!",
		"Başlangıç kılıcın, zırhın ve 1 Geliştirme Parşömenini kuşandırmak için bana dokun!",
		"lord_screen",
		str(sword.get("id", ""))
	)
	_persist_and_notify(true)
	return {"ok": true, "already_granted": false, "sword_id": str(sword.get("id", ""))}


func _find_starter_sword_id(ld: Dictionary) -> String:
	var inv := ld.get("inventory", []) as Array
	for it in inv:
		if typeof(it) == TYPE_DICTIONARY and str((it as Dictionary).get("slot_type", "")) == "sword":
			return str((it as Dictionary).get("id", ""))
	return ""


func injure_lord(loss_ratio: float = 0.5, now_u: int = 0) -> int:
	var now := now_u if now_u > 0 else _now_unix()
	var dur := clampi(
		int(round(lerpf(float(LordModelScript.INJURY_MIN_SECONDS), float(LordModelScript.INJURY_MAX_SECONDS), clampf(loss_ratio, 0.0, 1.0)))),
		LordModelScript.INJURY_MIN_SECONDS,
		LordModelScript.INJURY_MAX_SECONDS
	)
	var ld := ensure_lord_state()
	var until := now + dur
	ld["injured_until_unix"] = maxi(int(ld.get("injured_until_unix", 0)), until)
	ld["last_injury_duration"] = dur
	ld["recovery_notified_until"] = 0
	var mins := int(ceil(float(dur) / 60.0))
	push_speech(
		"lord_injured",
		"Lord Yaralandı!",
		"Savaşta ağır darbe aldım. Ekipmanlarım güvende ancak %d dakika iyileşmem gerekiyor." % mins,
		"lord_screen",
		""
	)
	_persist_and_notify(true)
	return int(ld["injured_until_unix"])


func tick_recovery(now_u: int = 0) -> bool:
	var gs := _autoload("GameState")
	if gs == null or typeof(gs.get("player")) != TYPE_DICTIONARY:
		return false
	var ld := ensure_lord_state()
	var until := int(ld.get("injured_until_unix", 0))
	if until <= 0:
		return false
	var now := now_u if now_u > 0 else _now_unix()
	if now < until:
		return false
	ld["injured_until_unix"] = 0
	ld["last_injury_duration"] = 0
	if int(ld.get("recovery_notified_until", 0)) != until:
		ld["recovery_notified_until"] = until
		push_speech(
			"lord_recovered",
			"Lord İyileşti!",
			"Yaralarım tamamen kapandı, tekrar seferlere liderlik etmeye hazırım!",
			"lord_screen",
			""
		)
	_persist_and_notify(true)
	lord_recovered.emit()
	return true


# --- Konuşma Balonu Bildirim Kuyruğu ---------------------------------------

func push_speech(type: String, title: String, text: String, target_action: String = "lord_screen", item_id: String = "") -> void:
	var ld := ensure_lord_state()
	var q := ld.get("speech_queue", []) as Array
	# Arka arkaya birebir aynı bildirimi tekrar kuyruğa sokma
	if not q.is_empty():
		var last := q[q.size() - 1] as Dictionary
		if str(last.get("type", "")) == type and str(last.get("text", "")) == text:
			return
	var entry := {
		"id": "%s_%d_%d" % [type, _now_unix(), q.size()],
		"type": type,
		"title": title,
		"text": text,
		"target_action": target_action,
		"item_id": item_id,
		"created_unix": _now_unix(),
	}
	q.append(entry)
	while q.size() > MAX_SPEECH_QUEUE:
		q.remove_at(0)
	speech_queued.emit(entry)
	lord_changed.emit()


func peek_speech() -> Dictionary:
	var ld := ensure_lord_state()
	var q := ld.get("speech_queue", []) as Array
	if q.is_empty():
		return {}
	return (q[0] as Dictionary).duplicate(true)


func dismiss_current_speech() -> void:
	var ld := ensure_lord_state()
	var q := ld.get("speech_queue", []) as Array
	if q.is_empty():
		return
	q.remove_at(0)
	_persist_and_notify(false)


func get_speech_count() -> int:
	var ld := ensure_lord_state()
	return (ld.get("speech_queue", []) as Array).size()


func get_combat_payload(now_u: int = 0) -> Dictionary:
	var ld := ensure_lord_state()
	var now := now_u if now_u > 0 else _now_unix()
	if int(ld.get("injured_until_unix", 0)) > now:
		return {"present": false}
	var st := LordModelScript.compute_lord_stats(ld)
	st["present"] = true
	return st
