extends SceneTree
## test_two_players_conquest_100x.gd
## Dünya 1'de sanki 2 farklı telefondan aynı anda girilmiş gibi 2 gerçek oyuncu hesabı
## ("Sultan Alparslan" ve "Kont Godfrey") açarak 100x test hızında uçtan uca test:
##   1. Her iki oyuncu için Tutorial (Adım 0→17) UI etkileşimleriyle baştan sona tamamlanır.
##   2. Her iki oyuncu QuestManager'ın yönlendirdiği sırayla görevleri ve bina önkoşullarını
##      (ör. Köşk ← Simyager 5 ← Kışla 5 ← Depo 3 + Değirmen 3; Depo/vatandaş sınırı) yapar.
##   3. SendTroopsPanel'de ayrı 'Yağma' butonu olmadığı, yalnızca 'Saldır' butonuyla
##      saldırıldığında hem savaşıldığı hem ganimet yağmalandığı doğrulanır.
##   4. KingsAge fetih kuralları (15 gün saldırı/fetih koruması, tek Kont saldırısının
##      köyü asla fethedememesi, aynı dalgada 2 Kont bile olsa tek Kont etkisi, her dalgada
##      en fazla köy puanının yarısı / 2250-2750 düşüş, en az 2+ ayrı Kont saldırısıyla fetih,
##      fetih sonrası %30 Güç Alanı ve 15 gün fetih koruması) PvP savaşında doğrulanır.
##   5. Sultan Alparslan, Kont Godfrey'in köyünü kurallara uygun şekilde fetheder; çoklu köy
##      yönetimi ve fethedilen oyuncu durumu kontrol edilir.

const VM := preload("res://scripts/model/VillageModel.gd")
const RE := preload("res://scripts/rules/RulesEngine.gd")
const EconomyAPI := preload("res://scripts/sim/economy/EconomyAPI.gd")
const EconomySimulator := preload("res://scripts/sim/economy/EconomySimulator.gd")
const ArmyAPI := preload("res://scripts/sim/army/ArmyAPI.gd")
const ArmySimulator := preload("res://scripts/sim/army/ArmySimulator.gd")
const Movement := preload("res://scripts/sim/actions/Movement.gd")
const ActionSimulator := preload("res://scripts/sim/actions/ActionSimulator.gd")
const Protection := preload("res://scripts/sim/actions/Protection.gd")
const WorldGenerator := preload("res://scripts/world/WorldGenerator.gd")
const SendTroopsScene := preload("res://ui/SendTroopsPanel.tscn")
const ReportsScene := preload("res://scenes/Reports.tscn")

const P1_NAME := "Sultan Alparslan"
const P2_NAME := "Kont Godfrey"

var _passed: int = 0
var _failed: int = 0
var _fail_labels: Array[String] = []
var _findings: Array[String] = []
var _active_scene: Node = null
var _sim_now: int = 0
var _conquest_summary: String = ""


func _initialize() -> void:
	await _run_test()
	print("")
	print("============== 2-OYUNCU DÜNYA 1 (100x) FETİH ÖZETİ ==============")
	print("PASS: %d   FAIL: %d" % [_passed, _failed])
	if not _conquest_summary.is_empty():
		print("FETİH SONUCU: ", _conquest_summary)
	if not _findings.is_empty():
		print("Bulgular / UI Notları:")
		for f in _findings:
			print("  * ", f)
	if _failed > 0:
		print("Başarısız kontroller:")
		for lbl in _fail_labels:
			print("  - ", lbl)
	print("=================================================================")
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

	all_events.append_array(EconomySimulator.process_tick(st, _sim_now, float(step)))
	all_events.append_array(ArmySimulator.process_tick(st, _sim_now, float(step)))
	all_events.append_array(ActionSimulator.process_tick(st, _sim_now, float(step)))

	gs.from_dict(st)
	var eb := root.get_node_or_null("EventBus")
	if eb != null:
		for ev in all_events:
			if typeof(ev) != TYPE_DICTIONARY:
				continue
			var d: Dictionary = ev
			match str(d.get("type", "")):
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


func _ensure_resources_via_production_or_storage(gs: Node, wm: Node, vid: int, req_w: int, req_s: int, req_i: int) -> bool:
	var v: Dictionary = gs.get_village(vid)
	var needed_cap := maxi(req_w, maxi(req_s, req_i))
	# Depo tavanı gereken maliyetin altındaysa önce Depo yükselt (gerçek oyuncu gibi!)
	var guard := 0
	while RE.storage_capacity(int(v.get("buildings", {}).get("storage", 1))) < needed_cap and guard < 40:
		guard += 1
		var cur_sto := int(v.get("buildings", {}).get("storage", 1))
		if not _ensure_building_level(gs, wm, vid, "storage", cur_sto + 1):
			break
		v = gs.get_village(vid)

	# 100x hızında doğal üretimle kaynak birikmesini simüle et; gerekirse madenleri yükselt
	var wait_loops := 0
	while wait_loops < 24:
		v = gs.get_village(vid)
		var r: Dictionary = v.get("resources", {})
		if int(r.get("wood", 0)) >= req_w and int(r.get("stone", 0)) >= req_s and int(r.get("iron", 0)) >= req_i:
			return true
		_advance_sim(gs, wm, 3600 * 6, false)
		wait_loops += 1

	# Çok yüksek geç-oyun maliyetlerinde madenleri geliştirip tekrar simüle et
	for mine in ["wood", "stone", "iron"]:
		var ml := int(gs.get_village(vid).get("buildings", {}).get(mine, 1))
		if ml < 18:
			_ensure_building_level(gs, wm, vid, mine, mini(18, ml + 4))
	for _extra in range(48):
		v = gs.get_village(vid)
		var r2: Dictionary = v.get("resources", {})
		if int(r2.get("wood", 0)) >= req_w and int(r2.get("stone", 0)) >= req_s and int(r2.get("iron", 0)) >= req_i:
			return true
		_advance_sim(gs, wm, 3600 * 12, false)

	v = gs.get_village(vid)
	var r3: Dictionary = v.get("resources", {})
	return int(r3.get("wood", 0)) >= req_w and int(r3.get("stone", 0)) >= req_s and int(r3.get("iron", 0)) >= req_i


func _ensure_building_level(gs: Node, wm: Node, target_vid: int, bk: String, target_lvl: int) -> bool:
	var v: Dictionary = gs.get_village(target_vid)
	if v.is_empty():
		return false
	var safety := 0
	while int(gs.get_village(target_vid).get("buildings", {}).get(bk, 0)) < target_lvl and safety < 80:
		safety += 1
		v = gs.get_village(target_vid)
		var bld: Dictionary = v.get("buildings", {})
		var cur_lvl := int(bld.get(bk, 0))
		var next_lvl := cur_lvl + 1

		# Önkoşulları otomatik çöz (RulesEngine.missing_requirements)
		var missing := RE.missing_requirements(bld, bk, next_lvl)
		if not missing.is_empty():
			var progressed := false
			for m in missing:
				var req_bk := str(m.get("building", ""))
				var req_l := int(m.get("level", 1))
				if req_bk.is_empty():
					continue
				if _ensure_building_level(gs, wm, target_vid, req_bk, req_l):
					progressed = true
			if progressed:
				continue

		v = gs.get_village(target_vid)
		var cost: Dictionary = RE.cost(bk, next_lvl)
		if not _ensure_resources_via_production_or_storage(gs, wm, target_vid, int(cost.get("wood", 0)), int(cost.get("stone", 0)), int(cost.get("iron", 0))):
			_note("Yetersiz üretim/depo [%s -> %s Lv.%d]" % [str(v.get("owner", "")), bk, next_lvl])
			return false

		v = gs.get_village(target_vid)
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
	if req_b > 0 and not _ensure_building_level(gs, wm, vid, "barracks", req_b):
		return false
	var cost := ArmyAPI.research_cost(u_key)
	if not _ensure_resources_via_production_or_storage(gs, wm, vid, int(cost.get("wood", 0)), int(cost.get("stone", 0)), int(cost.get("iron", 0))):
		return false
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


func _train_units(gs: Node, wm: Node, vid: int, u_key: String, count: int) -> bool:
	if count <= 0:
		return true
	if u_key != "snob" and not _ensure_research(gs, wm, vid, u_key):
		return false
	if u_key == "snob":
		if not _ensure_building_level(gs, wm, vid, "snob", 1):
			return false
		if not _ensure_building_level(gs, wm, vid, "smith", 1):
			return false
		var v_chk: Dictionary = gs.get_village(vid)
		var need_armour := maxi(0, count - ArmyAPI.gold_armour(v_chk))
		if need_armour > 0:
			var g_cost := ArmyAPI.gold_armour_cost(v_chk)
			for _gi in range(need_armour):
				if not _ensure_resources_via_production_or_storage(gs, wm, vid, int(g_cost.get("wood", 12000)), int(g_cost.get("stone", 10000)), int(g_cost.get("iron", 8000))):
					return false
				var st_g: Dictionary = gs.to_dict()
				for sv in st_g["villages"]:
					if int(sv.get("id", -1)) == vid:
						ArmyAPI.produce_gold_armour(sv, 1)
						break
				gs.from_dict(st_g)

	var per_cost := RE.unit_cost(u_key, 1)
	var settlers_each := RE.unit_settlers(u_key)
	var remaining := count
	var loops := 0
	while remaining > 0 and loops < 100:
		loops += 1
		var batch := 1 if u_key == "snob" else mini(remaining, 25)
		var v_cur: Dictionary = gs.get_village(vid)
		var need_pop := settlers_each * batch
		var safety_pop := 0
		while ArmyAPI.army_capacity(v_cur) < need_pop and safety_pop < 25:
			safety_pop += 1
			var fl := int(v_cur.get("buildings", {}).get("farm", 1))
			if not _ensure_building_level(gs, wm, vid, "farm", fl + 1):
				break
			v_cur = gs.get_village(vid)

		if not _ensure_resources_via_production_or_storage(gs, wm, vid, int(per_cost.get("wood", 0)) * batch, int(per_cost.get("stone", 0)) * batch, int(per_cost.get("iron", 0)) * batch):
			return false

		var st_t: Dictionary = gs.to_dict()
		st_t["world"]["sim_now_unix"] = _sim_now
		var st_v := {}
		for sv in st_t["villages"]:
			if int(sv.get("id", -1)) == vid:
				st_v = sv
				break
		var tr := ArmyAPI.start_training(st_v, u_key, batch, st_t, _sim_now)
		if not bool(tr.get("ok", false)):
			var reason := str(tr.get("reason", ""))
			if reason == "queue_full":
				_complete_all_queues(gs, wm)
				continue
			_note("Birim eğitimi başarısız [%s x%d]: %s" % [u_key, batch, reason])
			return false
		gs.from_dict(st_t)
		_complete_all_queues(gs, wm)
		remaining -= batch
	return remaining <= 0


func _get_capital_village(gs: Node) -> Dictionary:
	var best := {}
	var best_pts := -1
	for item in gs.get_player_villages():
		if typeof(item) == TYPE_DICTIONARY:
			var v := item as Dictionary
			var pts := int(v.get("points", 0))
			if best.is_empty() or pts > best_pts:
				best = v
				best_pts = pts
	return best


func _find_barbarian_target(gs: Node, origin_vid: int, max_dist: float = 80.0) -> Dictionary:
	var orig: Dictionary = gs.get_village(origin_vid)
	var ox := int(orig.get("x", 0))
	var oy := int(orig.get("y", 0))
	var best := {}
	var best_d := 1e9
	for v in gs.villages:
		if typeof(v) != TYPE_DICTIONARY:
			continue
		var vd := v as Dictionary
		if not bool(vd.get("is_barbarian", false)) and not bool(vd.get("is_bot", false)):
			continue
		var d := Vector2(ox, oy).distance_to(Vector2(int(vd.get("x", 0)), int(vd.get("y", 0))))
		if d <= max_dist and d < best_d:
			best_d = d
			best = vd
	return best


func _press_btn(b: BaseButton) -> void:
	if b != null and not b.disabled:
		b.emit_signal("pressed")


func _click_building(village: Node, b_key: String) -> void:
	var bv = village.call("get_building_view", b_key) if village.has_method("get_building_view") else null
	if bv != null and bv.has_signal("clicked"):
		bv.emit_signal("clicked")
	await _tick(3)


func _run_tutorial_for_player(p_name: String, gs: Node, wm: Node, tm: Node, qm: Node) -> void:
	var gc := root.get_node_or_null("GameConfig")
	_check(wm.call("enter_world", 1, p_name), "%s Dünya 1'e giriş yaptı" % p_name)
	_sync_speed_100x(gc, gs)

	tm.set("tutorial_enabled_in_headless", true)
	qm.set("quests_enabled_in_headless", true)
	tm.call("restart_tutorial")

	var village := await _swap_scene("res://scenes/Village.tscn")
	_check(village != null, "%s Village.tscn açıldı" % p_name)
	_check(tm.call("is_tutorial_active"), "%s tutorial aktif" % p_name)

	# Adım 0 -> 1 -> 2 (Vezir tanıtımı)
	_press_btn(tm.get("_btn_next") as BaseButton)
	await _tick(2)
	_press_btn(tm.get("_btn_next") as BaseButton)
	await _tick(2)

	# Adım 2 -> 3 (Kale seç ve incele)
	await _click_building(village, "main")
	var bp := village.get("building_panel") as Control
	var upg_btn := bp.get_node_or_null("VBox/UpgradeButton") as BaseButton
	var close_btn := bp.get_node_or_null("VBox/Header/CloseButton") as BaseButton
	_press_btn(close_btn)
	await _tick(2)

	# Adım 4 -> 5 (Oduncu seç ve yükselt + Kraliyet Fermanı)
	await _click_building(village, "wood")
	_press_btn(upg_btn)
	await _tick(2)
	_press_btn(tm.get("_btn_speedup") as BaseButton)
	await _tick(3)

	# Adım 6 -> 7 (Kapat -> Kışla önkoşulları: Depo 3, Değirmen 3)
	if bp.visible:
		_press_btn(close_btn)
		await _tick(2)
	await _click_building(village, "barracks")
	var g_sto := bp.find_child("GotoBtn_storage", true, false) as BaseButton
	_press_btn(g_sto)
	await _tick(2)
	for _s in range(2):
		_press_btn(upg_btn)
		await _tick(2)
		_press_btn(tm.get("_btn_speedup") as BaseButton)
		await _tick(2)
	if bp.visible:
		_press_btn(close_btn)
		await _tick(2)
	await _click_building(village, "farm")
	for _f in range(2):
		_press_btn(upg_btn)
		await _tick(2)
		_press_btn(tm.get("_btn_speedup") as BaseButton)
		await _tick(2)

	# Adım 8 -> 13 (Harita ve İttifak turu)
	var wm_scene := await _swap_scene("res://scenes/WorldMap.tscn")
	_check(wm_scene != null, "%s WorldMap.tscn gezildi" % p_name)
	_press_btn(tm.get("_btn_next") as BaseButton)
	await _tick(2)
	village = await _swap_scene("res://scenes/Village.tscn")
	var ally_scene := await _swap_scene("res://scenes/Alliance.tscn")
	_check(ally_scene != null, "%s Alliance.tscn gezildi" % p_name)
	_press_btn(tm.get("_btn_next") as BaseButton)
	await _tick(2)
	village = await _swap_scene("res://scenes/Village.tscn")
	bp = village.get("building_panel") as Control
	upg_btn = bp.get_node_or_null("VBox/UpgradeButton") as BaseButton

	# Adım 14 -> 17 (Kışla kur, Silahtar araştır, 10 Silahtar eğit, mezun ol)
	await _click_building(village, "barracks")
	_press_btn(upg_btn)
	await _tick(2)
	_press_btn(tm.get("_btn_speedup") as BaseButton)
	await _tick(3)

	_press_btn(bp.get_node_or_null("VBox/TabBar/TabResearchBtn") as BaseButton)
	await _tick(2)
	_press_btn(bp.find_child("ResearchBtn_spear", true, false) as BaseButton)
	await _tick(2)
	_press_btn(tm.get("_btn_speedup") as BaseButton)
	await _tick(3)

	_press_btn(bp.get_node_or_null("VBox/TabBar/TabTrainBtn") as BaseButton)
	await _tick(2)
	_press_btn(bp.find_child("BtnPlus10_spear", true, false) as BaseButton)
	await _tick(2)
	_press_btn(bp.find_child("TrainBtn_spear", true, false) as BaseButton)
	await _tick(2)
	_press_btn(tm.get("_btn_speedup") as BaseButton)
	await _tick(3)

	_check(int(tm.call("get_current_step")) == 17, "%s Tutorial Adım 17 (Mezuniyet)'e ulaştı" % p_name)
	_press_btn(tm.get("_btn_finish") as BaseButton)
	await _tick(2)
	_check(bool(gs.player.get("tutorial_completed", false)), "%s Tutorial tamamen bitirildi" % p_name)
	await _clear_scene()
	wm.call("save_active_world")


func _play_quests_through_snob_prep(p_name: String, gs: Node, wm: Node, qm: Node) -> void:
	_check(wm.call("enter_world", 1, p_name), "%s görevler için Dünya 1'e girdi" % p_name)
	_sync_speed_100x(root.get_node_or_null("GameConfig"), gs)
	qm.set("quests_enabled_in_headless", true)

	var cap_v := _get_capital_village(gs)
	var cap_vid := int(cap_v.get("id", -1))
	gs.set_active_village(cap_vid)

	# Görev sırasını takip ederek q_conquer_village öncesine kadar tüm görevleri gerçek önkoşul çözümüyle tamamla
	var barb_v := _find_barbarian_target(gs, cap_vid, 60.0)
	var barb_vid := int(barb_v.get("id", -1))
	var q_list: Array = qm.get_all_quest_defs()
	for q_item in q_list:
		var q: Dictionary = q_item
		var qid := str(q.get("id", ""))
		if qid == "q_conquer_village" or qid == "q_unlock_statue":
			continue  # Fetih PvP'de yapılacak!

		# Görev önkoşul butonlarını doğrula
		var pending_acts: Array = qm.get_pending_navigation_actions(qid, gs)
		var c_type := str(q.get("check_type", ""))

		# Önce QuestManager'ın işaret ettiği eksik bina önkoşul hedeflerini kontrol et (ör. Köşk için Simyager/Kışla)
		if qid == "q_unlock_snob" and int(gs.get_village(cap_vid).get("buildings", {}).get("snob", 0)) < 1:
			var has_prereq_act := false
			for a in pending_acts:
				if str(a.get("target", "")) in ["garage", "barracks", "storage", "farm"]:
					has_prereq_act = true
			_check(has_prereq_act, "%s q_unlock_snob önkoşul binasına yönlendirdi (%s)" % [p_name, str(pending_acts)])

		match c_type:
			"wood_stone_levels":
				_ensure_building_level(gs, wm, cap_vid, "wood", 3)
				_ensure_building_level(gs, wm, cap_vid, "stone", 2)
			"storage_farm_4":
				_ensure_building_level(gs, wm, cap_vid, "storage", 4)
				_ensure_building_level(gs, wm, cap_vid, "farm", 4)
			"building_level":
				_ensure_building_level(gs, wm, cap_vid, str(q.get("building_key", "")), int(q.get("target", 1)))
			"building_min":
				_ensure_building_level(gs, wm, cap_vid, str(q.get("building_key", "")), int(q.get("min_level", 1)))
			"infantry_count":
				_ensure_research(gs, wm, cap_vid, "sword")
				_train_units(gs, wm, cap_vid, "sword", 18)
			"spy_prereq":
				_ensure_building_level(gs, wm, cap_vid, "barracks", 4)
				_ensure_research(gs, wm, cap_vid, "spy")
			"unit_researched":
				_ensure_research(gs, wm, cap_vid, str(q.get("unit_key", "")))
			"unit_count_peak":
				var uk := str(q.get("unit_key", ""))
				_ensure_research(gs, wm, cap_vid, uk)
				var tgt := int(q.get("target", 1))
				var cur := int(gs.get_village(cap_vid).get("units", {}).get(uk, 0))
				if cur < tgt:
					_train_units(gs, wm, cap_vid, uk, tgt - cur)
			"stat_min":
				var sk := str(q.get("stat_key", ""))
				if sk == "spies_total":
					var st_s: Dictionary = gs.to_dict()
					var sr := Movement.send_spy(st_s, cap_vid, barb_vid, {"spy": 4}, _sim_now)
					_check(bool(sr.get("ok", false)), "%s casusluk görevi seferi" % p_name)
					gs.from_dict(st_s)
					_complete_all_movements(gs, wm)
				elif sk == "raids_total" or sk == "attacks_total":
					# Ayrı Yağma butonu yok → normal Saldır hem savaşır hem yağmalar ve her iki görevi ilerletir!
					_train_units(gs, wm, cap_vid, "sword", 16)
					var min_u := ArmyAPI.min_attack_units(gs.get_village(cap_vid))
					var st_a: Dictionary = gs.to_dict()
					var ar := Movement.send_attack(st_a, cap_vid, barb_vid, {"sword": maxi(16, min_u)}, _sim_now, {"seed": 21})
					_check(bool(ar.get("ok", false)), "%s Saldır (ganimet) seferi gönderildi" % p_name)
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
				_ensure_resources_via_production_or_storage(gs, wm, cap_vid, int(g_cost.get("wood", 12000)), int(g_cost.get("stone", 10000)), int(g_cost.get("iron", 8000)))
				var st_ga: Dictionary = gs.to_dict()
				for sv in st_ga["villages"]:
					if int(sv.get("id", -1)) == cap_vid:
						ArmyAPI.produce_gold_armour(sv, 1)
						break
				gs.from_dict(st_ga)

		# Ödül al ve görev ödülünün bir sonraki üretim tick'inde SİLİNMEDİĞİNİ doğrula!
		var prog: Dictionary = qm.get_quest_progress(qid, gs)
		_check(bool(prog.get("completed", false)), "%s görev tamamlandı: %s" % [p_name, qid])
		var wood_pre_claim := int(gs.get_village(cap_vid).get("resources", {}).get("wood", 0))
		_check(qm.claim_quest(qid, gs), "%s görev ödülü alındı: %s" % [p_name, qid])
		var reward_w := int((q.get("reward", {}) as Dictionary).get("wood", 0))
		_advance_sim(gs, wm, 2, false)
		var wood_post_tick := int(gs.get_village(cap_vid).get("resources", {}).get("wood", 0))
		_check(wood_post_tick >= wood_pre_claim + reward_w, "%s görev ödülü (%s +%d) üretim tickinde korunuyor (Depo silmedi: %d)" % [p_name, qid, reward_w, wood_post_tick])

	wm.call("save_active_world")


func _run_test() -> void:
	var gd := root.get_node_or_null("GameData")
	var gs := root.get_node_or_null("GameState")
	var wm := root.get_node_or_null("WorldManager")
	var tm := root.get_node_or_null("TutorialManager")
	var qm := root.get_node_or_null("QuestManager")
	var gc := root.get_node_or_null("GameConfig")

	_check(gd != null and gs != null and wm != null and tm != null and qm != null and gc != null, "Çekirdek autoloadlar yüklü")
	if gd == null or gs == null or wm == null or tm == null or qm == null or gc == null:
		return

	gd.call("load_all", true)
	var orig_speed := float(gc.get("speed"))
	var orig_unit_speed := float(gc.get("unit_speed"))

	_sim_now = int(Time.get_unix_time_from_system())
	wm.call("reset_all_worlds")

	# 1. İki farklı telefondan Dünya 1'e katılım (Sultan Alparslan & Kont Godfrey)
	_check(wm.call("join_world", 1, P1_NAME, 100, 100), "%s Dünya 1'e katıldı" % P1_NAME)
	_check(wm.call("join_world", 1, P2_NAME, 115, 100), "%s Dünya 1'e katıldı" % P2_NAME)

	_check(wm.call("enter_world", 1, P1_NAME), "Dünya 1'de iki köy kontrolü")
	var p1_v := {}
	var p2_v := {}
	for v in gs.villages:
		if typeof(v) != TYPE_DICTIONARY or bool(v.get("is_bot", false)):
			continue
		if str(v.get("owner", "")) == P1_NAME:
			p1_v = v
		elif str(v.get("owner", "")) == P2_NAME:
			p2_v = v
	_check(not p1_v.is_empty() and not p2_v.is_empty(), "Her iki oyuncunun Dünya 1'de gerçek başlangıç köyü var")
	var dist_12 := Vector2(int(p1_v["x"]), int(p1_v["y"])).distance_to(Vector2(int(p2_v["x"]), int(p2_v["y"])))
	_check(dist_12 >= float(WorldGenerator.MIN_VILLAGE_DISTANCE) and dist_12 <= 80.0, "Köyler arası mesafe hem >= %d hem Kont menzilinde (%.1f)" % [WorldGenerator.MIN_VILLAGE_DISTANCE, dist_12])

	# 2. İki oyuncu için Tutorial
	await _run_tutorial_for_player(P1_NAME, gs, wm, tm, qm)
	await _run_tutorial_for_player(P2_NAME, gs, wm, tm, qm)

	# 2a) Tutorial sonrası (0. gün): 10 Silahtarla saldırı denense bile 15 günlük yeni oyuncu saldırı koruması engellemeli
	_check(wm.call("enter_world", 1, P1_NAME), "%s koruma testi için girdi" % P1_NAME)
	_sync_speed_100x(gc, gs)
	var st_day0: Dictionary = gs.to_dict()
	var day0_chk := Movement.can_send(st_day0, int(p1_v["id"]), int(p2_v["id"]), Movement.TYPE_ATTACK, {"spear": 10}, {}, _sim_now)
	_check(not bool(day0_chk.get("ok", true)) and str(day0_chk.get("code", "")) == "target_protected", "0. günde 15 günlük yeni oyuncu saldırı koruması aktif [%s]" % str(day0_chk.get("code", "")))

	# 3. İki oyuncu için Görev zinciri (Kont eğitimi dahil) + Depo/Ödül/Önkoşul kontrolleri
	await _play_quests_through_snob_prep(P1_NAME, gs, wm, qm)
	await _play_quests_through_snob_prep(P2_NAME, gs, wm, qm)

	# 4. Dünya 1 PvP Çarpışma + KingsAge Fetih Kuralları + SendTroopsPanel UI Doğrulaması
	_check(wm.call("enter_world", 1, P1_NAME), "%s PvP savaşı için Dünya 1'e girdi" % P1_NAME)
	_sync_speed_100x(gc, gs)
	p1_v = _get_capital_village(gs)
	var p1_vid := int(p1_v["id"])
	gs.set_active_village(p1_vid)

	# P2'nin başkent ID'sini tazele
	for v in gs.villages:
		if typeof(v) == TYPE_DICTIONARY and str(v.get("owner", "")) == P2_NAME and not bool(v.get("is_bot", false)):
			p2_v = v
			break
	var p2_vid := int(p2_v["id"])
	var p2_pts := int(p2_v.get("points", 0))
	_check(p2_pts >= 500, "%s köyü görevlerle gelişti (puan=%d)" % [P2_NAME, p2_pts])

	# 4a) Eğer geliştirme süreci 15 oyun gününü henüz geçmediyse 15 gün+1 sn simüle et; geçtiyse koruma doğal olarak bitmiş demektir
	var p2_prot_until := int(p2_v.get("protection_until", 0))
	var p2_conq_prot_until := int(p2_v.get("conquest_protection_until", 0))
	var need_adv := maxi(p2_prot_until, p2_conq_prot_until) - _sim_now + 5
	if need_adv > 0:
		_advance_sim(gs, wm, need_adv, true)

	# 4b) Kont Godfrey -> Sultan Alparslan casusluk ve keşif saldırısı (koruma süresi dolduktan sonra)
	_check(wm.call("enter_world", 1, P2_NAME), "%s karşı saldırı için girdi" % P2_NAME)
	_sync_speed_100x(gc, gs)
	_train_units(gs, wm, p2_vid, "light", 80)

	# 4c) P2 şimdi P1'i casuslasın ve keşif saldırısı yapsın
	var st_p2_war: Dictionary = gs.to_dict()
	var p2_spy := Movement.send_spy(st_p2_war, p2_vid, p1_vid, {"spy": 5}, _sim_now)
	_check(bool(p2_spy.get("ok", false)), "%s -> %s casusluk gönderdi" % [P2_NAME, P1_NAME])
	gs.from_dict(st_p2_war)
	_complete_all_movements(gs, wm)

	st_p2_war = gs.to_dict()
	var min_p2 := ArmyAPI.min_attack_units(gs.get_village(p2_vid))
	var p2_atk := Movement.send_attack(st_p2_war, p2_vid, p1_vid, {"light": maxi(40, min_p2)}, _sim_now, {"seed": 31})
	_check(bool(p2_atk.get("ok", false)), "%s -> %s keşif saldırısı gönderdi" % [P2_NAME, P1_NAME])
	gs.from_dict(st_p2_war)
	_complete_all_movements(gs, wm)

	# 4d) P1 güçlü taarruz ordusu ve çoklu dalga için 4 Kont hazırlasın
	_check(wm.call("enter_world", 1, P1_NAME), "%s büyük taarruz için girdi" % P1_NAME)
	_sync_speed_100x(gc, gs)
	gs.set_active_village(p1_vid)
	_train_units(gs, wm, p1_vid, "axe", 500)
	_train_units(gs, wm, p1_vid, "light", 220)
	_train_units(gs, wm, p1_vid, "ram", 25)
	_train_units(gs, wm, p1_vid, "snob", 4)
	p1_v = gs.get_village(p1_vid)
	p2_v = gs.get_village(p2_vid)
	_check(int(p1_v.get("units", {}).get("snob", 0)) >= 4, "%s en az 4 Kont eğitti" % P1_NAME)

	# 4e) SendTroopsPanel UI Doğrulaması: tek Saldır butonu var, ayrı Yağma butonu YOK!
	var stp := SendTroopsScene.instantiate()
	root.add_child(stp)
	await _tick(2)
	_check(stp.get_node_or_null("VBox/ActionButtons/BtnRaid") == null, "UI: SendTroopsPanel'de ayrı 'Yağma' (BtnRaid) butonu yok")
	stp.call("show_target", p1_v, p2_v)
	stp._unit_inputs["spy"].value = 5
	stp.call("refresh")
	_check(stp.btn_attack.visible and not stp.btn_attack.disabled and stp.btn_attack.text.contains("Casus"), "UI: Yalnız casusla 'Casus Gönder' aktif")
	stp.btn_attack.emit_signal("pressed")
	await _tick(2)
	_complete_all_movements(gs, wm)

	# P2'nin Güç Alanını fetih öncesi tam (puanına eşit veya yakın) hale getirip çoklu dalga kuralını test et
	p2_v = gs.get_village(p2_vid)
	var realm_before_wave1 := int(p2_v.get("realm_of_power", 0))
	var pts_now := int(p2_v.get("points", 0))
	_check(realm_before_wave1 >= int(floor(float(pts_now) * 0.90)), "Fetih öncesi %s köyünün Güç Alanı tam (%d / %d)" % [P2_NAME, realm_before_wave1, pts_now])

	# 4f) DALGA 1 (UI BtnAttack üzerinden!): 2 Kont BİRDEN gönderilse bile tek seferde fethedememeli ve düşüş <= puan/2 olmalı!
	p1_v = gs.get_village(p1_vid)
	p2_v = gs.get_village(p2_vid)
	stp.call("show_target", p1_v, p2_v)
	stp._unit_inputs["spy"].value = 0
	stp._unit_inputs["axe"].value = 350
	stp._unit_inputs["light"].value = 150
	stp._unit_inputs["ram"].value = 20
	stp._unit_inputs["snob"].value = 2  # Aynı saldırıda 2 Kont → etki yine maks 1 Kont kadar!
	stp.call("refresh")
	var w1_diag := "vis=%s dis=%s txt='%s' warn='%s' axe=%d snob=%d" % [
		str(stp.btn_attack.visible), str(stp.btn_attack.disabled), str(stp.btn_attack.text),
		str(stp.warning_label.text), int(p1_v.get("units", {}).get("axe", 0)), int(p1_v.get("units", {}).get("snob", 0))
	]
	_check(stp.btn_attack.visible and not stp.btn_attack.disabled and stp.btn_attack.text.contains("Saldır"), "UI: Tek 'Saldır' butonu aktif (%s)" % w1_diag)
	stp.btn_attack.emit_signal("pressed")
	await _tick(2)
	stp.queue_free()
	await _tick(2)

	var ev_w1 := _complete_all_movements(gs, wm)
	var w1_battle := {}
	for ev in ev_w1:
		if typeof(ev) == TYPE_DICTIONARY and str(ev.get("type", "")) == "battle_resolved":
			w1_battle = ev
			break
	p2_v = gs.get_village(p2_vid)
	var w1_loot_sum := int(w1_battle.get("loot", {}).get("wood", 0)) + int(w1_battle.get("loot", {}).get("stone", 0)) + int(w1_battle.get("loot", {}).get("iron", 0))
	_check(bool(w1_battle.get("attacker_won", false)), "Dalga 1: %s savaşı kazandı" % P1_NAME)
	_check(w1_loot_sum > 0, "Dalga 1: Tek 'Saldır' komutu kazanılınca otomatik yağma yaptı (ganimet=%d)" % w1_loot_sum)
	_check(not bool(w1_battle.get("conquered", false)) and str(p2_v.get("owner", "")) == P2_NAME, "Dalga 1: 2 Kont aynı dalgada olsa bile tek saldırı köyü FETHEDEMEDİ (KingsAge kuralı!)")
	var realm_after_w1 := int(p2_v.get("realm_of_power", 0))
	var expected_max_drop_w1 := mini(2750, int(floor(float(pts_now) / 2.0)))
	_check(realm_before_wave1 - realm_after_w1 <= expected_max_drop_w1 and realm_after_w1 > 0, "Dalga 1: Güç Alanı düşüşü kurallara uygun (%d → %d, maks düşüş %d)" % [realm_before_wave1, realm_after_w1, expected_max_drop_w1])

	# 4g) ARDIL DALGALAR (Dalga 2..N): Her biri ayrı Kont saldırısı olarak Güç Alanı 0'a inene kadar saldır!
	var waves := 1
	var conquered_ev := {}
	while str(gs.get_village(p2_vid).get("owner", "")) != P1_NAME and waves < 10:
		waves += 1
		p1_v = gs.get_village(p1_vid)
		var min_a := ArmyAPI.min_attack_units(p1_v)
		if int(p1_v.get("units", {}).get("snob", 0)) < 1:
			_train_units(gs, wm, p1_vid, "snob", 1)
		if int(gs.get_village(p1_vid).get("units", {}).get("axe", 0)) < maxi(100, min_a):
			_train_units(gs, wm, p1_vid, "axe", 150)
		var st_w: Dictionary = gs.to_dict()
		var wr := Movement.send_attack(st_w, p1_vid, p2_vid, {"axe": maxi(100, min_a), "snob": 1}, _sim_now, {"seed": 100 + waves})
		_check(bool(wr.get("ok", false)), "Dalga %d: Kont saldırısı gönderildi [%s]" % [waves, str(wr.get("code", ""))])
		gs.from_dict(st_w)
		var ev_wn := _complete_all_movements(gs, wm)
		for ev in ev_wn:
			if typeof(ev) == TYPE_DICTIONARY and str(ev.get("type", "")) == "village_conquered":
				conquered_ev = ev

	p2_v = gs.get_village(p2_vid)
	_check(waves >= 2, "Fetih en az 2 ayrı Kont saldırısı sürdü (toplam dalga=%d)" % waves)
	_check(str(p2_v.get("owner", "")) == P1_NAME and not conquered_ev.is_empty(), "%d. Kont saldırısı sonunda %s (%d), %s'in köyünü FETHETTİ!" % [waves, P1_NAME, p1_vid, P2_NAME])

	# Fetih sonrası kurallar: %30 Güç Alanı + fetih koruması + q_conquer_village tamamlandı + çoklu köy geçişi
	var expected_post_realm := int(floor(float(mini(int(p2_v.get("points", 0)), 10000)) * 0.30 + 0.5))
	var actual_post_realm := int(p2_v.get("realm_of_power", -1))
	_check(abs(actual_post_realm - expected_post_realm) <= 50, "Fetih sonrası Güç Alanı %%30'a ayarlandı (%d ~ %d)" % [actual_post_realm, expected_post_realm])
	_check(int(p2_v.get("conquest_protection_until", 0)) > _sim_now, "Fethedilen köye fetih koruması verildi")
	_check(bool(qm.get_quest_progress("q_conquer_village", gs).get("completed", false)), "%s q_conquer_village PvP fethi ile tamamlandı" % P1_NAME)
	_check(gs.get_player_villages().size() >= 2, "%s artık %d köy yönetiyor" % [P1_NAME, gs.get_player_villages().size()])

	var first_vid: int = gs.active_village_id
	var switched_vid: int = gs.cycle_active_village(1)
	_check(switched_vid != first_vid and switched_vid > 0, "Fetih sonrası köyler arası geçiş (%d → %d) hatasız çalıştı" % [first_vid, switched_vid])
	gs.set_active_village(first_vid)

	# Raporlar ekranı kontrolü
	var rep_scene := await _swap_scene("res://scenes/Reports.tscn")
	_check(rep_scene != null, "Reports.tscn PvP savaş raporlarıyla açıldı")
	await _clear_scene()

	wm.call("save_active_world")
	_check(bool(wm.call("is_player_conquered", 1, P2_NAME)), "WorldManager: %s tüm köylerini kaybetti (fethedildi)" % P2_NAME)

	_conquest_summary = "%s (%d dalga Kont saldırısıyla, başlangıç puanı %d) %s'in #%d nolu köyünü fethetti! Artık %s %d köy sahibi, %s fethedildi." % [
		P1_NAME, waves, p2_pts, P2_NAME, p2_vid, P1_NAME, gs.get_player_villages().size(), P2_NAME
	]

	# Üretim hızını temizle
	gc.set("speed", orig_speed)
	gc.set("unit_speed", orig_unit_speed)
	wm.call("reset_all_worlds")
