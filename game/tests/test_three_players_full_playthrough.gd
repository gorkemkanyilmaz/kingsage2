extends SceneTree
## test_three_players_full_playthrough.gd
## 3 farklı gerçek hesap (Lord Arthur, Lord Lancelot, Lord Mordred) ile aynı dünyada
## 100x test hızında uçtan uca tam oyun testi:
##   1. Tutorial'ı 3 hesap için baştan sona bitirme + UI/izlence kontrolleri
##   2. Görev sistemindeki (QuestManager) tüm 21 görevi 3 hesap için sırayla yapma & ödül alma
##   3. Altın Zırh + Kont üretip her hesap en az 3 köye ulaşana kadar köy fethetme (toplam 9+ köy)
##   4. İttifak kurulumu: 2 hesap ("Lord Arthur" + "Lord Lancelot") müttefik, 1 hesap ("Lord Mordred") tek
##   5. SendTroopsPanel / Alliance / Reports UI ve savaş mekaniği:
##      Destek, Casus, Yağma, PvP Saldırı & Birleşik Savunma akışları.

const VM := preload("res://scripts/model/VillageModel.gd")
const RE := preload("res://scripts/rules/RulesEngine.gd")
const EconomyAPI := preload("res://scripts/sim/economy/EconomyAPI.gd")
const EconomySimulator := preload("res://scripts/sim/economy/EconomySimulator.gd")
const ArmyAPI := preload("res://scripts/sim/army/ArmyAPI.gd")
const ArmySimulator := preload("res://scripts/sim/army/ArmySimulator.gd")
const Movement := preload("res://scripts/sim/actions/Movement.gd")
const ActionSimulator := preload("res://scripts/sim/actions/ActionSimulator.gd")
const AllianceModel := preload("res://scripts/model/AllianceModel.gd")
const WorldGenerator := preload("res://scripts/world/WorldGenerator.gd")
const SendTroopsScene := preload("res://ui/SendTroopsPanel.tscn")
const ReportsScene := preload("res://scenes/Reports.tscn")

const PLAYERS := [
	{"name": "Lord Arthur", "x": 100, "y": 100},
	{"name": "Lord Lancelot", "x": 118, "y": 100},
	{"name": "Lord Mordred", "x": 100, "y": 118},
]

var _passed: int = 0
var _failed: int = 0
var _fail_labels: Array[String] = []
var _findings: Array[String] = []
var _active_scene: Node = null
var _sim_now: int = 0


func _initialize() -> void:
	await _run_full_playthrough()
	print("")
	print("================ 3-OYUNCU 100x FULL PLAYTHROUGH ÖZET ================")
	print("PASS: %d   FAIL: %d" % [_passed, _failed])
	if not _findings.is_empty():
		print("Bulgular:")
		for f in _findings:
			print("  * ", f)
	if _failed > 0:
		print("Başarısız kontroller:")
		for lbl in _fail_labels:
			print("  - ", lbl)
	print("====================================================================")
	quit(1 if _failed > 0 else 0)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("PASS: ", label)
	else:
		_failed += 1
		_fail_labels.append(label)
		printerr("FAIL: ", label)


func _note(msg: String) -> void:
	_findings.append(msg)
	print("NOTE: ", msg)


func _tick(frames: int = 2) -> void:
	for _i in range(frames):
		await process_frame


func _swap_scene(res_path: String) -> Node:
	if _active_scene != null and is_instance_valid(_active_scene):
		root.remove_child(_active_scene)
		_active_scene.queue_free()
		_active_scene = null
		await _tick(2)
	var packed := load(res_path) as PackedScene
	if packed == null:
		return null
	var inst := packed.instantiate()
	root.add_child(inst)
	_active_scene = inst
	await _tick(3)
	return inst


func _clear_scene() -> void:
	if _active_scene != null and is_instance_valid(_active_scene):
		root.remove_child(_active_scene)
		_active_scene.queue_free()
		_active_scene = null
		await _tick(2)


func _sync_speed_100x(gc: Node, gs: Node) -> void:
	if gc != null:
		gc.set("speed", 100.0)
		gc.set("unit_speed", 100.0)
	if gs != null and typeof(gs.world) == TYPE_DICTIONARY:
		gs.world["speed"] = 100.0
		gs.world["unit_speed"] = 100.0
		gs.world["sim_now_unix"] = _sim_now


func _advance_sim(gs: Node, wm: Node, seconds: int, save_disk: bool = false) -> Array:
	var all_events: Array = []
	var st: Dictionary = gs.to_dict()
	if not (st.get("world") is Dictionary):
		st["world"] = {}
	st["world"]["speed"] = 100.0
	st["world"]["unit_speed"] = 100.0

	var step := maxi(1, seconds)
	_sim_now += step
	st["world"]["sim_now_unix"] = _sim_now
	st["world"]["last_saved_unix"] = _sim_now

	var eco_ev := EconomySimulator.process_tick(st, _sim_now, float(step))
	var army_ev := ArmySimulator.process_tick(st, _sim_now, float(step))
	var act_ev := ActionSimulator.process_tick(st, _sim_now, float(step))
	all_events.append_array(eco_ev)
	all_events.append_array(army_ev)
	all_events.append_array(act_ev)

	gs.from_dict(st)
	var eb := root.get_node_or_null("EventBus")
	if eb != null:
		for ev in all_events:
			if typeof(ev) != TYPE_DICTIONARY:
				continue
			var d: Dictionary = ev
			var et := str(d.get("type", ""))
			match et:
				"building_completed":
					if eb.has_signal("building_completed"):
						eb.emit_signal("building_completed", int(d.get("village_id", 0)), str(d.get("key", "")), int(d.get("level", 0)))
				"research_completed":
					if eb.has_signal("research_completed"):
						eb.emit_signal("research_completed", int(d.get("village_id", 0)), str(d.get("key", "")))
				"training_completed":
					if eb.has_signal("unit_trained"):
						eb.emit_signal("unit_trained", int(d.get("village_id", 0)), str(d.get("key", "")), int(d.get("count", 0)))
				"battle_resolved":
					if eb.has_signal("battle_resolved"):
						eb.emit_signal("battle_resolved", d)
				"spy_resolved":
					if eb.has_signal("spy_mission_resolved"):
						eb.emit_signal("spy_mission_resolved", d)
				"village_conquered":
					if eb.has_signal("village_conquered"):
						eb.emit_signal("village_conquered", int(d.get("village_id", 0)), str(d.get("new_owner", "")))
	if save_disk and wm != null and wm.has_method("save_active_world"):
		wm.call("save_active_world")
	return all_events


func _complete_all_queues(gs: Node, wm: Node, save_disk: bool = false) -> Array:
	var max_finish := _sim_now
	for q in gs.queues:
		if typeof(q) == TYPE_DICTIONARY:
			max_finish = maxi(max_finish, int((q as Dictionary).get("finish_unix", _sim_now)))
	var delta := maxi(1, max_finish - _sim_now + 2)
	return _advance_sim(gs, wm, delta, save_disk)


func _complete_all_movements(gs: Node, wm: Node, save_disk: bool = true) -> Array:
	var collected: Array = []
	for _round in range(6):
		var max_arr := _sim_now
		var found := false
		for m in gs.movements:
			if typeof(m) == TYPE_DICTIONARY:
				found = true
				max_arr = maxi(max_arr, int((m as Dictionary).get("arrive_unix", _sim_now)))
		if not found:
			break
		var delta := maxi(1, max_arr - _sim_now + 2)
		collected.append_array(_advance_sim(gs, wm, delta, save_disk))
	return collected


func _grant_resources_if_needed(gs: Node, v: Dictionary, wood: int, stone: int, iron: int) -> void:
	var r: Dictionary = v.get("resources", {})
	r["wood"] = maxi(int(r.get("wood", 0)), wood)
	r["stone"] = maxi(int(r.get("stone", 0)), stone)
	r["iron"] = maxi(int(r.get("iron", 0)), iron)
	v["resources"] = r
	gs._emit_resources_changed(int(v.get("id", -1)))


func _ensure_building_level(gs: Node, wm: Node, target_vid: int, bk: String, target_lvl: int) -> bool:
	var guard := 0
	while guard < 120:
		guard += 1
		var v: Dictionary = gs.get_village(target_vid)
		if v.is_empty():
			return false
		var bld: Dictionary = v.get("buildings", {})
		var cur := int(bld.get(bk, 0))
		if cur >= target_lvl:
			return true

		# Önce gereksinim zincirindeki eksik binaları veya yetersiz Depo/Değirmen kapasitesini çöz
		var next_lvl := cur + 1
		var missing := RE.missing_requirements(bld, bk, next_lvl)
		if not missing.is_empty():
			for m in missing:
				if typeof(m) == TYPE_DICTIONARY:
					var mk := str((m as Dictionary).get("building", ""))
					var ml := int((m as Dictionary).get("level", 1))
					if not _ensure_building_level(gs, wm, target_vid, mk, ml):
						return false
			continue

		var cost: Dictionary = RE.cost(bk, next_lvl)
		var max_cost := maxi(int(cost.get("wood", 0)), maxi(int(cost.get("stone", 0)), int(cost.get("iron", 0))))
		var stor_cap: int = RE.storage_capacity(int(bld.get("storage", 1)))
		if max_cost > stor_cap and bk != "storage":
			if not _ensure_building_level(gs, wm, target_vid, "storage", int(bld.get("storage", 1)) + 1):
				return false
			continue

		_grant_resources_if_needed(gs, v, int(cost.get("wood", 0)), int(cost.get("stone", 0)), int(cost.get("iron", 0)))
		var st: Dictionary = gs.to_dict()
		st["world"]["sim_now_unix"] = _sim_now
		st["world"]["speed"] = 100.0
		var st_v: Dictionary = {}
		for sv in st["villages"]:
			if int(sv.get("id", -1)) == target_vid:
				st_v = sv
				break
		var res: Dictionary = EconomyAPI.start_build(st_v, bk, st)
		if not bool(res.get("ok", false)):
			var reason := str(res.get("reason", ""))
			if reason == "queue_full":
				_complete_all_queues(gs, wm)
				continue
			if reason in ["not_enough_population", "not_enough_citizens", "no_population", "population", "citizens"]:
				if bk != "farm":
					if not _ensure_building_level(gs, wm, target_vid, "farm", int(bld.get("farm", 1)) + 1):
						return false
					continue
			_note("İnşaat başarısız [%s -> %s Lv.%d]: %s" % [str(v.get("owner", "")), bk, next_lvl, reason])
			return false
		gs.from_dict(st)
		_complete_all_queues(gs, wm)
	return int(gs.get_village(target_vid).get("buildings", {}).get(bk, 0)) >= target_lvl


func _ensure_research(gs: Node, wm: Node, vid: int, u_key: String) -> bool:
	var v: Dictionary = gs.get_village(vid)
	if v.is_empty():
		return false
	if RE.is_researched(v, u_key):
		return true
	var req_b := RE.research_requirement(u_key)
	if req_b > 0:
		if not _ensure_building_level(gs, wm, vid, "barracks", req_b):
			return false
	v = gs.get_village(vid)
	var cost := ArmyAPI.research_cost(u_key)
	_grant_resources_if_needed(gs, v, int(cost.get("wood", 0)), int(cost.get("stone", 0)), int(cost.get("iron", 0)))
	var st: Dictionary = gs.to_dict()
	st["world"]["sim_now_unix"] = _sim_now
	var st_v := {}
	for sv in st["villages"]:
		if int(sv.get("id", -1)) == vid:
			st_v = sv
			break
	var res := ArmyAPI.start_research(st_v, u_key, st, _sim_now)
	if not bool(res.get("ok", false)):
		_note("Araştırma hatası [%s]: %s" % [u_key, str(res.get("reason", ""))])
		return false
	gs.from_dict(st)
	_complete_all_queues(gs, wm)
	return RE.is_researched(gs.get_village(vid), u_key)


func _get_capital_village(gs: Node) -> Dictionary:
	var my_vills: Array = gs.get_player_villages()
	var best := {}
	var best_pts := -1
	for item in my_vills:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var v: Dictionary = item
		var pts := int(v.get("points", 0))
		if best.is_empty() or pts > best_pts:
			best = v
			best_pts = pts
	return best


func _train_units(gs: Node, wm: Node, vid: int, u_key: String, count: int) -> bool:
	if count <= 0:
		return true
	if u_key != "snob" and not _ensure_research(gs, wm, vid, u_key):
		return false
	var v: Dictionary = gs.get_village(vid)
	if u_key == "snob":
		if not _ensure_building_level(gs, wm, vid, "snob", 1):
			return false
		if not _ensure_building_level(gs, wm, vid, "smith", 1):
			return false
		v = gs.get_village(vid)
		var need_armour := maxi(0, count - ArmyAPI.gold_armour(v))
		if need_armour > 0:
			var g_cost := ArmyAPI.gold_armour_cost(v)
			_grant_resources_if_needed(
				gs, v,
				int(g_cost.get("wood", 0)) * need_armour,
				int(g_cost.get("stone", 0)) * need_armour,
				int(g_cost.get("iron", 0)) * need_armour
			)
			var st_g: Dictionary = gs.to_dict()
			for sv in st_g["villages"]:
				if int(sv.get("id", -1)) == vid:
					var ok_g := ArmyAPI.produce_gold_armour(sv, need_armour)
					if not ok_g:
						_note("Altın zırh üretilemedi")
						return false
					break
			gs.from_dict(st_g)
			v = gs.get_village(vid)

	var bld: Dictionary = v.get("buildings", {})
	var need_pop := count * RE.unit_settlers(u_key)
	while true:
		v = gs.get_village(vid)
		bld = v.get("buildings", {})
		var free_pop := RE.max_population(int(bld.get("farm", 1))) - VM.population_used(v) - ArmyAPI.army_settlers(v) - int(v.get("settlers_reserved", 0))
		if free_pop >= need_pop:
			break
		if not _ensure_building_level(gs, wm, vid, "farm", int(bld.get("farm", 1)) + 1):
			return false

	v = gs.get_village(vid)

	var u_cost := RE.unit_cost(u_key, count)
	_grant_resources_if_needed(gs, v, int(u_cost.get("wood", 0)), int(u_cost.get("stone", 0)), int(u_cost.get("iron", 0)))
	var st: Dictionary = gs.to_dict()
	st["world"]["sim_now_unix"] = _sim_now
	var st_v := {}
	for sv in st["villages"]:
		if int(sv.get("id", -1)) == vid:
			st_v = sv
			break
	var tr := ArmyAPI.start_training(st_v, u_key, count, st, _sim_now)
	if not bool(tr.get("ok", false)):
		_note("Eğitim başlatılamadı [%s x%d]: %s" % [u_key, count, str(tr.get("reason", ""))])
		return false
	gs.from_dict(st)
	_complete_all_queues(gs, wm)
	return int(gs.get_village(vid).get("units", {}).get(u_key, 0)) >= count


func _find_barbarian_target(gs: Node, origin_vid: int, max_dist: float = 75.0, exclude_vids: Array = []) -> Dictionary:
	var origin: Dictionary = gs.get_village(origin_vid)
	var ox := int(origin.get("x", 0))
	var oy := int(origin.get("y", 0))
	var best_barb: Dictionary = {}
	var best_barb_d := 999999.0
	var best_npc: Dictionary = {}
	var best_npc_d := 999999.0
	for v in gs.villages:
		if typeof(v) != TYPE_DICTIONARY:
			continue
		var vd: Dictionary = v
		var vid := int(vd.get("id", -1))
		if vid == origin_vid or (vid in exclude_vids):
			continue
		var is_barb := bool(vd.get("is_barbarian", false))
		var is_bot := bool(vd.get("is_bot", false))
		var is_bonus := not str(vd.get("bonus_type", "")).is_empty()
		if not is_barb and not is_bot and not is_bonus:
			continue
		if int(vd.get("protection_until", 0)) > _sim_now:
			continue
		var dx := float(int(vd.get("x", 0)) - ox)
		var dy := float(int(vd.get("y", 0)) - oy)
		var d := sqrt(dx * dx + dy * dy)
		if d <= max_dist:
			if is_barb and d < best_barb_d:
				best_barb_d = d
				best_barb = vd
			elif d < best_npc_d:
				best_npc_d = d
				best_npc = vd
	return best_barb if not best_barb.is_empty() else best_npc


func _run_tutorial_for_player(p_name: String, gs: Node, wm: Node, tm: Node, qm: Node) -> void:
	_check(wm.call("enter_world", 1, p_name), "%s Dünya 1'e giriş yaptı" % p_name)
	_sync_speed_100x(root.get_node_or_null("GameConfig"), gs)
	_check(not bool(gs.player.get("tutorial_completed", false)), "%s ilk girişte tutorial_completed=false (hesap izolasyonu)" % p_name)
	_check(qm.get_visible_quests(gs).size() > 0, "%s görev tanımları yüklü" % p_name)
	_check(not qm.is_quest_hud_visible(), "%s tutorial bitmeden görev HUD görünmez" % p_name)

	var village := await _swap_scene("res://scenes/Village.tscn")
	_check(village != null, "%s Village sahnesi açıldı" % p_name)
	tm.set("tutorial_enabled_in_headless", true)
	qm.set("quest_enabled_in_headless", true)
	await _tick(3)

	# Adım 0 -> 1 -> 2
	_check(tm.get_current_step() == 0, "%s Tutorial Adım 0 (WELCOME_INTRO)" % p_name)
	var step0_ctrl = tm.call("_resolve_target_control", village, "Village.tscn", gs)
	_check(step0_ctrl == tm.get("_btn_next"), "%s Adım 0'da Kale pasif, yalnızca Devam Et hedefli" % p_name)
	tm._on_next_pressed()
	await _tick(2)
	_check(tm.get_current_step() == 1, "%s Tutorial Adım 1 (RESOURCE_BAR_TOUR)" % p_name)
	tm._on_next_pressed()
	await _tick(2)
	_check(tm.get_current_step() == 2, "%s Tutorial Adım 2 (SELECT_MAIN_CASTLE)" % p_name)

	# Kale aç
	var bp = village.get("building_panel")
	bp.call("show_building", gs.get_active_village(), "main")
	await _tick(3)
	_check(tm.get_current_step() == 3, "%s Tutorial Adım 3 (INSPECT_MAIN_PANEL)" % p_name)
	tm._on_next_pressed()
	await _tick(2)
	_check(tm.get_current_step() == 4, "%s Tutorial Adım 4 (SELECT_WOOD_CAMP)" % p_name)

	# Oduncu aç & yükselt
	bp.call("show_building", gs.get_active_village(), "wood")
	await _tick(3)
	_check(tm.get_current_step() == 5, "%s Tutorial Adım 5 (UPGRADE_WOOD_CAMP)" % p_name)
	_ensure_building_level(gs, wm, gs.active_village_id, "wood", 2)
	await _tick(3)
	_check(tm.get_current_step() == 6, "%s Tutorial Adım 6 (CHECK_BARRACKS_REQS)" % p_name)
	tm._on_next_pressed()
	await _tick(2)
	_check(tm.get_current_step() == 7, "%s Tutorial Adım 7 (COMPLETE_BARRACKS_PREREQS)" % p_name)

	# Kışla önkoşulları (Depo 3, Değirmen 3)
	_ensure_building_level(gs, wm, gs.active_village_id, "storage", 3)
	_ensure_building_level(gs, wm, gs.active_village_id, "farm", 3)
	# Oduncu/bina panelinin kapalı olduğundan emin ol -> WorldMap aç
	if bp != null and bp.visible:
		bp.hide()
	await _tick(3)
	_check(tm.get_current_step() == 8, "%s Tutorial Adım 8 (OPEN_WORLD_MAP)" % p_name)

	# Dünya Haritası turu
	await _swap_scene("res://scenes/WorldMap.tscn")
	_check(tm.get_current_step() == 9, "%s Tutorial Adım 9 (WORLD_MAP_TOUR)" % p_name)
	tm._on_next_pressed()
	await _tick(2)
	_check(tm.get_current_step() == 10, "%s Tutorial Adım 10 (RETURN_FROM_MAP)" % p_name)
	await _swap_scene("res://scenes/Village.tscn")
	_check(tm.get_current_step() == 11, "%s Tutorial Adım 11 (OPEN_ALLIANCE)" % p_name)

	# İttifak turu
	await _swap_scene("res://scenes/Alliance.tscn")
	_check(tm.get_current_step() == 12, "%s Tutorial Adım 12 (ALLIANCE_TOUR)" % p_name)
	tm._on_next_pressed()
	await _tick(2)
	_check(tm.get_current_step() == 13, "%s Tutorial Adım 13 (RETURN_FROM_ALLIANCE)" % p_name)
	village = await _swap_scene("res://scenes/Village.tscn")
	_check(tm.get_current_step() == 14, "%s Tutorial Adım 14 (BUILD_BARRACKS_LV1)" % p_name)

	# Kışla Lv.1 kur
	_ensure_building_level(gs, wm, gs.active_village_id, "barracks", 1)
	await _tick(3)
	_check(tm.get_current_step() == 15, "%s Tutorial Adım 15 (RESEARCH_SPEAR)" % p_name)

	# Silahtar araştır
	_ensure_research(gs, wm, gs.active_village_id, "spear")
	await _tick(3)
	_check(tm.get_current_step() == 16, "%s Tutorial Adım 16 (TRAIN_10_SPEAR)" % p_name)

	# 10 Silahtar eğit
	_train_units(gs, wm, gs.active_village_id, "spear", 10)
	await _tick(4)
	_check(tm.get_current_step() == 17, "%s Tutorial Adım 17 (GRADUATION_MODAL)" % p_name)
	tm._on_graduation_finish_pressed()
	await _tick(2)

	_check(bool(gs.player.get("tutorial_completed", false)), "%s tutorial_completed=true oldu" % p_name)
	_check(bool(gs.player.get("tutorial_reward_claimed", false)), "%s tutorial graduation ödülü alındı" % p_name)
	_check(qm.is_quest_hud_visible(), "%s tutorial sonrası Görev HUD görünür oldu" % p_name)
	wm.call("save_active_world")
	await _clear_scene()


func _run_all_quests_for_player(p_name: String, gs: Node, wm: Node, qm: Node) -> void:
	_check(wm.call("enter_world", 1, p_name), "%s görevler için Dünya 1'e girdi" % p_name)
	_sync_speed_100x(root.get_node_or_null("GameConfig"), gs)
	var cap_vid := int(gs.active_village_id)
	var q_list: Array = qm.get_all_quest_defs()
	var claimed_init: Array = gs.player.get("quests", {}).get("claimed", [])
	_check(claimed_init.size() == 0, "%s görevlere 0/%d temiz başlangıçla girdi" % [p_name, q_list.size()])

	var barb := _find_barbarian_target(gs, cap_vid, 70.0)
	_check(not barb.is_empty(), "%s yakınında barbar hedef köy bulundu" % p_name)
	var barb_vid := int(barb.get("id", -1))

	for q in q_list:
		var qid := str(q.get("id", ""))
		var c_type := str(q.get("check_type", ""))
		match c_type:
			"wood_stone_levels":
				_ensure_building_level(gs, wm, cap_vid, "wood", 3)
				_ensure_building_level(gs, wm, cap_vid, "stone", 2)
			"building_level":
				var bk := str(q.get("building_key", ""))
				_ensure_building_level(gs, wm, cap_vid, bk, int(q.get("target", 1)))
			"storage_farm_4":
				# Çoklu hedef buton testi (Depo 4 olunca Depo butonu gider, Değirmen kalır)
				_ensure_building_level(gs, wm, cap_vid, "storage", 4)
				var acts_mid: Array = qm.get_pending_navigation_actions(q, gs)
				var has_storage_left := false
				var has_farm_left := false
				for a in acts_mid:
					if str(a.get("target", "")) == "storage":
						has_storage_left = true
					elif str(a.get("target", "")) == "farm":
						has_farm_left = true
				_check((not has_storage_left) and has_farm_left, "%s q_storage_farm_4: Depo=4 olunca yalnızca Değirmen butonu kaldı" % p_name)
				_ensure_building_level(gs, wm, cap_vid, "farm", 4)
			"building_min":
				var bk_m := str(q.get("building_key", ""))
				var min_l := int(q.get("min_level", 1))
				_ensure_building_level(gs, wm, cap_vid, bk_m, min_l)
			"infantry_count":
				_ensure_research(gs, wm, cap_vid, "sword")
				_train_units(gs, wm, cap_vid, "sword", 15)
			"spy_prereq":
				_ensure_building_level(gs, wm, cap_vid, "barracks", 4)
				_ensure_research(gs, wm, cap_vid, "spy")
			"unit_count_peak":
				var uk := str(q.get("unit_key", ""))
				var target_cnt := int(q.get("target", 1))
				var cur_cnt := int(gs.get_village(cap_vid).get("units", {}).get(uk, 0))
				if cur_cnt < target_cnt:
					_train_units(gs, wm, cap_vid, uk, target_cnt - cur_cnt)
			"stat_min":
				var sk := str(q.get("stat_key", ""))
				if sk == "spies_total":
					var st_s: Dictionary = gs.to_dict()
					var sr := Movement.send_spy(st_s, cap_vid, barb_vid, {"spy": 3}, _sim_now)
					_check(bool(sr.get("ok", false)), "%s casusluk görevi seferi gönderildi" % p_name)
					gs.from_dict(st_s)
					_complete_all_movements(gs, wm)
				elif sk == "raids_total":
					_train_units(gs, wm, cap_vid, "sword", 12)
					var min_u := ArmyAPI.min_attack_units(gs.get_village(cap_vid))
					var st_r: Dictionary = gs.to_dict()
					var rr := Movement.send_raid(st_r, cap_vid, barb_vid, {"spear": maxi(5, min_u / 2), "sword": maxi(5, min_u)}, _sim_now, {"seed": 11})
					_check(bool(rr.get("ok", false)), "%s yağma görevi seferi gönderildi [%s]" % [p_name, str(rr.get("code", ""))])
					gs.from_dict(st_r)
					_complete_all_movements(gs, wm)
				elif sk == "attacks_total":
					_train_units(gs, wm, cap_vid, "sword", 15)
					var min_a := ArmyAPI.min_attack_units(gs.get_village(cap_vid))
					var st_a: Dictionary = gs.to_dict()
					var ar := Movement.send_attack(st_a, cap_vid, barb_vid, {"sword": maxi(15, min_a)}, _sim_now, {"seed": 12})
					_check(bool(ar.get("ok", false)), "%s saldırı görevi seferi gönderildi [%s]" % [p_name, str(ar.get("code", ""))])
					gs.from_dict(st_a)
					_complete_all_movements(gs, wm)
			"axe_bow_count":
				_ensure_research(gs, wm, cap_vid, "axe")
				_ensure_research(gs, wm, cap_vid, "bow")
				_train_units(gs, wm, cap_vid, "axe", 20)
				_train_units(gs, wm, cap_vid, "bow", 15)
			"cavalry_count":
				_ensure_research(gs, wm, cap_vid, "light")
				_train_units(gs, wm, cap_vid, "light", 22)
			"siege_count":
				_ensure_research(gs, wm, cap_vid, "ram")
				_train_units(gs, wm, cap_vid, "ram", 6)
			"gold_armour_made":
				var v_ga: Dictionary = gs.get_village(cap_vid)
				var g_cost := ArmyAPI.gold_armour_cost(v_ga)
				_grant_resources_if_needed(gs, v_ga, int(g_cost.get("wood", 12000)), int(g_cost.get("stone", 10000)), int(g_cost.get("iron", 8000)))
				var st_ga: Dictionary = gs.to_dict()
				for sv in st_ga["villages"]:
					if int(sv.get("id", -1)) == cap_vid:
						ArmyAPI.produce_gold_armour(sv, 1)
						break
				gs.from_dict(st_ga)
			"conquer_village":
				# 2. köy fethi (yüksek ordu + Kont ile sadakati 0'a indir)
				var conq_target := _find_barbarian_target(gs, cap_vid, 70.0)
				_check(not conq_target.is_empty(), "%s fetih hedef köy bulundu" % p_name)
				var c_vid := int(conq_target.get("id", -1))
				_train_units(gs, wm, cap_vid, "axe", 80)
				var min_c := ArmyAPI.min_attack_units(gs.get_village(cap_vid))
				var attempts := 0
				while str(gs.get_village(c_vid).get("owner", "")) != p_name and attempts < 8:
					attempts += 1
					if int(gs.get_village(cap_vid).get("units", {}).get("snob", 0)) < 1:
						_train_units(gs, wm, cap_vid, "snob", 1)
					var have_axe := int(gs.get_village(cap_vid).get("units", {}).get("axe", 0))
					if have_axe < min_c + 40:
						_train_units(gs, wm, cap_vid, "axe", (min_c + 40) - have_axe)
					var st_c: Dictionary = gs.to_dict()
					var cr := Movement.send_attack(st_c, cap_vid, c_vid, {"axe": maxi(40, min_c), "snob": 1}, _sim_now, {"seed": 100 + attempts})
					if not bool(cr.get("ok", false)):
						_note("Fetih seferi hatası: %s" % str(cr.get("code", "")))
						break
					gs.from_dict(st_c)
					_complete_all_movements(gs, wm)
				_check(str(gs.get_village(c_vid).get("owner", "")) == p_name, "%s 2. köyünü fethetti (ID=%d)" % [p_name, c_vid])

		# Modal ve ödül alma kontrolü
		qm.open_quest_modal(qid)
		var prog: Dictionary = qm.get_quest_progress(qid, gs)
		_check(bool(prog.get("completed", false)), "%s görev tamamlandı: %s (%d/%d)" % [p_name, qid, int(prog.get("current", 0)), int(prog.get("target", 1))])
		_check(qm.claim_quest(qid, gs), "%s görev ödülü alındı: %s" % [p_name, qid])
		qm.close_quest_modal()

	var claimed_final: Array = gs.player.get("quests", {}).get("claimed", [])
	_check(claimed_final.size() == q_list.size(), "%s TÜM %d GÖREV TAMAMLANDI (%d/%d)" % [p_name, q_list.size(), claimed_final.size(), q_list.size()])
	wm.call("save_active_world")


func _conquer_to_three_villages(p_name: String, gs: Node, wm: Node) -> void:
	_check(wm.call("enter_world", 1, p_name), "%s 3. köy fethi için Dünya 1'e girdi" % p_name)
	_sync_speed_100x(root.get_node_or_null("GameConfig"), gs)
	var cap_v := _get_capital_village(gs)
	var cap_vid := int(cap_v.get("id", -1))
	gs.set_active_village(cap_vid)

	while gs.get_player_villages().size() < 3:
		var target := _find_barbarian_target(gs, cap_vid, 75.0)
		_check(not target.is_empty(), "%s için 3. fetih hedef köyü bulundu" % p_name)
		if target.is_empty():
			break
		var t_vid := int(target.get("id", -1))
		var min_c := ArmyAPI.min_attack_units(gs.get_village(cap_vid))
		var wave := 0
		while str(gs.get_village(t_vid).get("owner", "")) != p_name and wave < 8:
			wave += 1
			if int(gs.get_village(cap_vid).get("units", {}).get("snob", 0)) < 1:
				_train_units(gs, wm, cap_vid, "snob", 1)
			var have_axe := int(gs.get_village(cap_vid).get("units", {}).get("axe", 0))
			if have_axe < min_c + 40:
				_train_units(gs, wm, cap_vid, "axe", (min_c + 40) - have_axe)
			var st: Dictionary = gs.to_dict()
			var r := Movement.send_attack(st, cap_vid, t_vid, {"axe": maxi(40, min_c), "snob": 1}, _sim_now, {"seed": 200 + wave})
			_check(bool(r.get("ok", false)), "%s fetih dalgası #%d gönderildi" % [p_name, wave])
			gs.from_dict(st)
			_complete_all_movements(gs, wm)
		_check(str(gs.get_village(t_vid).get("owner", "")) == p_name, "%s yeni köyü fethetti (ID=%d)" % [p_name, t_vid])

	var my_vills: Array = gs.get_player_villages()
	_check(my_vills.size() >= 3, "%s en az 3 köye ulaştı (%d köy)" % [p_name, my_vills.size()])

	# Köyler arası geçiş (cycle_active_village)
	var v0 := int(my_vills[0]["id"])
	gs.set_active_village(v0)
	var v1: int = gs.cycle_active_village(1)
	var v2: int = gs.cycle_active_village(1)
	var v_back: int = gs.cycle_active_village(1)
	_check(v1 != v0 and v2 != v1 and v_back == v0, "%s köyler arası döngüsel geçiş 3 köyde de hatasız çalıştı" % p_name)
	wm.call("save_active_world")


func _run_full_playthrough() -> void:
	var gd := root.get_node_or_null("GameData")
	var gs := root.get_node_or_null("GameState")
	var wm := root.get_node_or_null("WorldManager")
	var tm := root.get_node_or_null("TutorialManager")
	var qm := root.get_node_or_null("QuestManager")
	var gc := root.get_node_or_null("GameConfig")

	_check(gd != null and gs != null and wm != null and tm != null and qm != null and gc != null, "Tüm çekirdek autoloadlar yüklü")
	if gd == null or gs == null or wm == null or tm == null or qm == null or gc == null:
		return

	gd.call("load_all", true)
	var orig_speed := float(gc.get("speed"))
	var orig_unit_speed := float(gc.get("unit_speed"))

	_sim_now = int(Time.get_unix_time_from_system())
	wm.call("reset_all_worlds")

	# 1) 3 farklı hesap aynı dünyada başlasın
	for p in PLAYERS:
		_check(wm.call("join_world", 1, p["name"], p["x"], p["y"]), "%s Dünya 1'e katıldı" % p["name"])

	# Mesafe kontrolü (>= MIN_VILLAGE_DISTANCE)
	_check(wm.call("enter_world", 1, "Lord Arthur"), "Mesafe kontrolü için dünyaya girildi")
	var p_vills := []
	for p in PLAYERS:
		for v in gs.villages:
			if typeof(v) == TYPE_DICTIONARY and str(v.get("owner", "")) == p["name"] and not bool(v.get("is_bot", false)):
				p_vills.append(v)
				break
	_check(p_vills.size() == 3, "3 hesabın başlangıç köyleri mevcut")
	for i in range(p_vills.size()):
		for j in range(i + 1, p_vills.size()):
			var d_ij := Vector2(int(p_vills[i]["x"]), int(p_vills[i]["y"])).distance_to(Vector2(int(p_vills[j]["x"]), int(p_vills[j]["y"])))
			_check(d_ij >= float(WorldGenerator.MIN_VILLAGE_DISTANCE), "Hesap köyleri arası minimum mesafe sağlandı (%.1f >= %d)" % [d_ij, WorldGenerator.MIN_VILLAGE_DISTANCE])

	# 2) Tutorial (3 hesap için baştan sona)
	for p in PLAYERS:
		await _run_tutorial_for_player(p["name"], gs, wm, tm, qm)

	# 3) Tüm 21 Görev (3 hesap için adım adım)
	for p in PLAYERS:
		_run_all_quests_for_player(p["name"], gs, wm, qm)

	# 4) Her 3 hesap en az 3 köye ulaşsın (toplam 9+ köy)
	for p in PLAYERS:
		_conquer_to_three_villages(p["name"], gs, wm)

	# 5) İttifak Kurulumu: Lord Arthur + Lord Lancelot -> Yuvarlak Masa [YM], Lord Mordred tek
	_check(wm.call("enter_world", 1, "Lord Arthur"), "Lord Arthur ittifak kurulumu için girdi")
	var st_al: Dictionary = gs.to_dict()
	var c_res := AllianceModel.create_alliance(st_al, "Lord Arthur", "Yuvarlak Masa", "YM", "Kraliyet İttifakı")
	_check(bool(c_res.get("ok", false)), "Lord Arthur 'Yuvarlak Masa [YM]' ittifakını kurdu")
	var ym_id := int(c_res.get("alliance", {}).get("id", -1))
	var inv_res := AllianceModel.invite_player(st_al, ym_id, "Lord Arthur", "Lord Lancelot")
	_check(bool(inv_res.get("ok", false)), "Lord Arthur, Lord Lancelot'a davet gönderdi")
	gs.from_dict(st_al)
	wm.call("save_active_world")

	_check(wm.call("enter_world", 1, "Lord Lancelot"), "Lord Lancelot daveti kabul etmek için girdi")
	var st_acc: Dictionary = gs.to_dict()
	var acc_res := AllianceModel.accept_invitation(st_acc, "Lord Lancelot", ym_id)
	_check(bool(acc_res.get("ok", false)), "Lord Lancelot ittifak davetini kabul etti")
	gs.from_dict(st_acc)
	wm.call("save_active_world")

	_check(AllianceModel.get_player_alliance(gs.to_dict(), "Lord Arthur").get("name", "") == "Yuvarlak Masa", "Arthur YM üyesi")
	_check(AllianceModel.get_player_alliance(gs.to_dict(), "Lord Lancelot").get("name", "") == "Yuvarlak Masa", "Lancelot YM üyesi")
	_check(AllianceModel.get_player_alliance(gs.to_dict(), "Lord Mordred").is_empty(), "Mordred tek başına (ittifaksız)")

	# 6) Karşılıklı Etkileşim + SendTroopsPanel UI Doğrulaması
	# Hedef köyler: Arthur köy[1], Lancelot köy[1], Mordred köy[1] (fethedilmiş uç köyler -> protection_until=0)
	_check(wm.call("enter_world", 1, "Lord Arthur"), "Arthur etkileşimler için girdi")
	_sync_speed_100x(gc, gs)
	var arthur_cap: Dictionary = _get_capital_village(gs)
	gs.set_active_village(int(arthur_cap.get("id", -1)))
	var lancelot_outpost := {}
	var mordred_outpost := {}
	for v in gs.villages:
		if typeof(v) == TYPE_DICTIONARY and int(v.get("protection_until", 0)) == 0:
			if str(v.get("owner", "")) == "Lord Lancelot" and lancelot_outpost.is_empty():
				lancelot_outpost = v
			elif str(v.get("owner", "")) == "Lord Mordred" and mordred_outpost.is_empty():
				mordred_outpost = v
	_check(not lancelot_outpost.is_empty() and not mordred_outpost.is_empty(), "Lancelot ve Mordred fethedilmiş uç köyleri mevcut")

	# Destek & Yağma & Casus & Saldırı birlikleri hazırla
	var min_arthur := ArmyAPI.min_attack_units(arthur_cap)
	_train_units(gs, wm, int(arthur_cap["id"]), "spear", 120)
	_train_units(gs, wm, int(arthur_cap["id"]), "sword", 120)
	_train_units(gs, wm, int(arthur_cap["id"]), "light", maxi(100, min_arthur + 10))
	arthur_cap = gs.get_village(int(arthur_cap["id"]))

	# SendTroopsPanel UI testi (Dost -> Destek butonu, Düşman -> Saldır + Yağmala butonları, Casus -> Casus Gönder)
	var stp := SendTroopsScene.instantiate()
	root.add_child(stp)
	await _tick(2)

	# Dost köye (Lancelot) tıklanınca:
	stp.call("show_target", arthur_cap, lancelot_outpost)
	stp._unit_inputs["spear"].value = 50
	stp.call("refresh")
	_check(stp.btn_support != null and stp.btn_support.visible and not stp.btn_support.disabled, "UI: Müttefik köyde 'Destek Gönder' butonu görünür ve aktif")
	_check(not stp.btn_attack.visible and not stp.btn_raid.visible, "UI: Müttefik köyde Saldır/Yağmala butonları gizli")
	# UI butonundan destek gönder
	stp.btn_support.emit_signal("pressed")
	await _tick(2)
	arthur_cap = gs.get_village(int(arthur_cap["id"]))

	# Kendi diğer köyüne tıklanınca 'Bu Köye Geç' butonu görünmeli
	var arthur_second: Dictionary = {}
	for pv in gs.get_player_villages():
		if int((pv as Dictionary).get("id", -1)) != int(arthur_cap["id"]):
			arthur_second = pv
			break
	if not arthur_second.is_empty():
		stp.call("show_target", arthur_cap, arthur_second)
		var sw_btn: Button = stp.get("_btn_switch_to_village")
		_check(sw_btn != null and sw_btn.visible, "UI: Kendi 2. köyünde 'Bu Köye Geç' butonu görünür")

	# Düşman köye (Mordred) yalnızca Casus seçilince:
	stp.call("show_target", arthur_cap, mordred_outpost)
	stp._unit_inputs["spy"].value = 10
	stp.call("refresh")
	_check(stp.btn_attack.visible and stp.btn_attack.text.contains("Casus"), "UI: Yalnız casus seçilince 'Casus Gönder' aktif")
	_check(not stp.btn_raid.visible, "UI: Yalnız casus seçilince Yağmala gizli")

	# Asgari ordu şartı (< 3 * Kışla): 50 Hafif Süvari ile kilitli olmalı
	stp._unit_inputs["spy"].value = 0
	stp._unit_inputs["light"].value = 50
	stp.call("refresh")
	_check(stp.btn_attack.visible and stp.btn_attack.disabled, "UI: Asgari ordu (%d) altında 'Saldır' butonu kilitli + uyarı aktif" % min_arthur)
	_check(stp.btn_raid.visible and stp.btn_raid.disabled and stp.warning_label.visible, "UI: Asgari ordu (%d) altında 'Yağmala' kilitli" % min_arthur)

	# Düşman köye (Mordred) asgari şart (>= 3 * Kışla) üzeri savaş birliği seçilince Saldır & Yağmala aktif:
	stp._unit_inputs["light"].value = maxi(95, min_arthur)
	stp.call("refresh")
	_check(stp.btn_attack.visible and not stp.btn_attack.disabled, "UI: Düşman köyde 'Saldır' butonu aktif")
	_check(stp.btn_raid.visible and not stp.btn_raid.disabled, "UI: Düşman köyde 'Yağmala' butonu aktif")
	var mv_before_raid: int = gs.movements.size()
	stp.btn_raid.emit_signal("pressed")
	await _tick(2)
	_check(gs.movements.size() == mv_before_raid + 1, "UI: Yağmala butonu seferi gerçekten başlattı")

	stp.queue_free()
	await _tick(2)

	# Hareketleri tamamla (Destek varışı + Yağma muharebesi & dönüş)
	_complete_all_movements(gs, wm)
	var lanc_after_sup: Dictionary = gs.get_village(int(lancelot_outpost["id"]))
	_check(int(lanc_after_sup.get("units", {}).get("spear", 0)) >= 50, "Arthur'un 50 Silahtar desteği Lancelot'un köyüne ulaştı")
	_check(lanc_after_sup.get("support", []).size() >= 1, "Lancelot köyünde destek kaydı oluştu")

	# Casusluk & PvP Büyük Saldırı (Lord Mordred -> Lord Lancelot'un destekli köyü)
	_check(wm.call("enter_world", 1, "Lord Mordred"), "Mordred saldırı & casusluk için girdi")
	_sync_speed_100x(gc, gs)
	var mord_cap: Dictionary = _get_capital_village(gs)
	gs.set_active_village(int(mord_cap.get("id", -1)))
	var mord_vid := int(mord_cap["id"])
	_train_units(gs, wm, mord_vid, "spy", 60)
	_train_units(gs, wm, mord_vid, "axe", 300)
	_train_units(gs, wm, mord_vid, "light", 100)
	_train_units(gs, wm, mord_vid, "ram", 20)

	# Casusluk gönder
	var st_spy: Dictionary = gs.to_dict()
	var spy_r := Movement.send_spy(st_spy, mord_vid, int(lancelot_outpost["id"]), {"spy": 30}, _sim_now, {"seed": 777})
	_check(bool(spy_r.get("ok", false)), "Mordred -> Lancelot casusluk seferi gönderildi [%s]" % str(spy_r.get("code", "")))
	gs.from_dict(st_spy)
	_complete_all_movements(gs, wm)

	# Normal PvP saldırı gönder (Mordred -> Lancelot'un destekli köyü)
	var lanc_units_before := int(gs.get_village(int(lancelot_outpost["id"])).get("units", {}).get("spear", 0))
	var st_atk: Dictionary = gs.to_dict()
	var atk_r := Movement.send_attack(st_atk, mord_vid, int(lancelot_outpost["id"]), {"axe": 250, "light": 80, "ram": 15}, _sim_now, {"seed": 888})
	_check(bool(atk_r.get("ok", false)), "Mordred -> Lancelot tam PvP saldırısı gönderildi [%s]" % str(atk_r.get("code", "")))
	gs.from_dict(st_atk)
	_complete_all_movements(gs, wm)

	var lanc_units_after := int(gs.get_village(int(lancelot_outpost["id"])).get("units", {}).get("spear", 0))
	_check(lanc_units_after < lanc_units_before, "Birleşik savunma çatışması gerçekleşti ve savunma/destek kayıpları işlendi (%d -> %d)" % [lanc_units_before, lanc_units_after])

	# Savaş raporunda gerçek Lord isimleri kontrolü + Reports sahne kontrolü
	var found_named_pvp := false
	var found_spy_rep := false
	for rep in gs.reports:
		if typeof(rep) != TYPE_DICTIONARY:
			continue
		var r: Dictionary = rep
		var rt := str(r.get("type", ""))
		var rd: Dictionary = r.get("data", {})
		if rt == "battle" and str(rd.get("attacker_name", "")) == "Lord Mordred" and str(rd.get("defender_name", "")) == "Lord Lancelot":
			found_named_pvp = true
		if rt == "spy" and int(rd.get("target_village_id", -1)) == int(lancelot_outpost["id"]):
			found_spy_rep = true
	_check(found_named_pvp, "PvP savaş raporunda gerçek isimler mevcut (Lord Mordred vs Lord Lancelot)")
	_check(found_spy_rep, "Casusluk raporu oluştu ve hedef istihbaratı içeriyor")

	# Raporlar + İttifak + Sıralama + Harita sahnelerini her hesapta açıp hata vermediğini doğrula
	for p in PLAYERS:
		wm.call("enter_world", 1, p["name"])
		var rep_scene := await _swap_scene("res://scenes/Reports.tscn")
		_check(rep_scene != null, "%s Reports sahnesi hatasız açıldı" % p["name"])
		var al_scene := await _swap_scene("res://scenes/Alliance.tscn")
		_check(al_scene != null, "%s Alliance sahnesi hatasız açıldı" % p["name"])
		var rk_scene := await _swap_scene("res://scenes/Ranking.tscn")
		_check(rk_scene != null, "%s Ranking sahnesi hatasız açıldı" % p["name"])
	await _clear_scene()

	# Test hızını normal üretim varsayılanına geri çek
	gc.set("speed", orig_speed)
	gc.set("unit_speed", orig_unit_speed)
