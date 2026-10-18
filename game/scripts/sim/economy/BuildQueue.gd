extends RefCounted
## BuildQueue — inşa kuyruğu (3 ücretsiz slot, ek maliyet, süre, iptal, yıkım) (Taht ve Kılıç).
##
## Sahip: **A-EKONOMI** · Sözleşme: `docs/19-MOTOR-API-SOZLESMESI.md` §3.2, §4.1, §4.2, §7b.
## Kaynaklar: `docs/04` §3 (İnşaat Kuralları), `game/data/rules/time-factors.json`
## (`build_queue_extra_cost`), `game/data/rules/requirements.json`, `game/data/rules/costs.json`.
##
## ## Kural özeti
##  • **Sıralı ilerleme:** bir bina yalnızca **mevcut + 1** seviyeye yükseltilir
##    → `RulesEngine.can_upgrade_now()`. Kuyruktaki bekleyen işler de hesaba katılır
##    (aynı bina arka arkaya kuyruğa konabilir; hedef sıradaki boş seviyedir).
##  • **Gereksinim zinciri:** inşa başlatmadan önce önkoşullar `RulesEngine.missing_requirements()`
##    ile doğrulanır; **ihlal edilemez**.
##  • **Vatandaş:** hedef seviyenin bağladığı vatandaş (`workersLevel`) + kuyruktaki bekleyenler
##    Değirmen tavanını aşamaz (`Population`).
##  • **Kuyruk:** ilk **3 iş ücretsiz**; 4.+ iş için ek maliyet
##    `time-factors.json#build_queue_extra_cost` (`[0,0,0,25,56,95,144,205,281,376]`).
##  • **Zaman:** işler **sırayla** tamamlanır. Süre `RulesEngine.build_seconds(key, level)`.
##  • **İptal:** görev talimatına göre **geri ödeme YOK** (`cancel_build(..., refund=false)`).
##    ⚠️ `docs/04` §3.4 iade olduğunu söyler — **AÇIK SORU** (bkz. ASSUMPTIONS.md §3).
##  • **Yıkım:** Kale Lv15 + Simyager tekniği; hammadde iadesi **yok**, vatandaş geri gelir.
##
## ## Zaman modeli
## `start_unix` / `finish_unix` **simülasyon saatine** aittir (`GameLoop` bunu `world.sim_now_unix`
## altında ilerletir; canlı oyunda gerçek unix'e yakındır, offline hızlı-ileride delta ile
## ilerler). Böylece `GameClock.fast_forward()` tek yoluyla determinist kalır.

const RE := preload("res://scripts/rules/RulesEngine.gd")
const VM := preload("res://scripts/model/VillageModel.gd")
const POP := preload("res://scripts/sim/economy/Population.gd")
const PROD := preload("res://scripts/sim/economy/Production.gd")

const RESOURCES := ["wood", "stone", "iron"]

## Kuyruk öğesi türü (docs/19 §3.2).
const TYPE := "build"

## Sonsuz döngü koruması.
const MAX_STEPS := 100000


static func _game_data() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var node: Node = (loop as SceneTree).root.get_node_or_null("GameData")
		if node != null:
			if node.has_method("is_loaded") and not node.is_loaded():
				node.load_all()
			return node
	return null


static func _game_config() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("GameConfig")
	return null


static func _round_half_up(x: float) -> int:
	return int(floor(x + 0.5))


static func _max_level(key: String) -> int:
	var gd := _game_data()
	if gd == null:
		return 0
	return int(gd.get_max_level(key))


# =============================================================================
#  Durum erişimi
# =============================================================================

## `state.queues` dizisini garanti eder ve döndürür.
static func queues(state: Dictionary) -> Array:
	var q = state.get("queues", null)
	if typeof(q) != TYPE_ARRAY:
		q = []
		state["queues"] = q
	return q as Array


## Köyü kimliğiyle bulur; yoksa null.
static func _village_of(state: Dictionary, village_id: int) -> Dictionary:
	var villages = state.get("villages", [])
	if typeof(villages) != TYPE_ARRAY:
		return {}
	for v in (villages as Array):
		if typeof(v) == TYPE_DICTIONARY and int((v as Dictionary).get("id", -1)) == village_id:
			return v as Dictionary
	return {}


## Bir köyün kuyruk öğeleri (tür=build), `start_unix` sonra `id` ile sıralı.
static func items(state: Dictionary, village_id: int) -> Array:
	var out := []
	for item in queues(state):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if str((item as Dictionary).get("type", "")) != TYPE:
			continue
		if int((item as Dictionary).get("village_id", -1)) != village_id:
			continue
		out.append(item)
	out.sort_custom(func(a, b):
		var sa := int(a.get("start_unix", 0))
		var sb := int(b.get("start_unix", 0))
		if sa == sb:
			return int(a.get("id", 0)) < int(b.get("id", 0))
		return sa < sb)
	return out


## Kuyruktaki (henüz tamamlanmamış) bina işi sayısı.
static func pending_count(state: Dictionary, village_id: int) -> int:
	return items(state, village_id).size()


# =============================================================================
#  Hedef seviye & maliyet
# =============================================================================

## Köyün bina seviyeleri + kuyrukta bekleyen hedefler (projeksiyon).
## Aynı bina için birden çok iş varsa en yüksek hedef alınır.
static func projected_buildings(state: Dictionary, village: Dictionary) -> Dictionary:
	var out := {}
	var b = village.get("buildings", {})
	if typeof(b) == TYPE_DICTIONARY:
		for k in (b as Dictionary).keys():
			out[str(k)] = int((b as Dictionary)[k])
	var vid := int(village.get("id", -1))
	for item in items(state, vid):
		var k := str((item as Dictionary).get("key", ""))
		var lvl := int((item as Dictionary).get("target_level", 0))
		if not k.is_empty() and lvl > int(out.get(k, 0)):
			out[k] = lvl
	return out


## `key` binasının bir sonraki hedef seviyesi (= projeksiyondaki mevcut + 1).
static func next_target_level(state: Dictionary, village: Dictionary, key: String) -> int:
	return int(projected_buildings(state, village).get(key, 0)) + 1


## Kuyruğa eklenecek **sıradaki** işin ek maliyet yüzdesi (0 tabanlı indeks = pending_count).
static func extra_cost_percent(state: Dictionary, village_id: int) -> int:
	return RE.queue_extra_cost_percent(pending_count(state, village_id))


## Bir sonraki işin maliyeti (taban + kuyruk ek maliyeti), hammadde başına int.
static func next_cost(state: Dictionary, village: Dictionary, key: String) -> Dictionary:
	var tgt := next_target_level(state, village, key)
	var base := RE.cost(key, tgt)
	var pct := extra_cost_percent(state, int(village.get("id", -1)))
	var total := {}
	for r in RESOURCES:
		total[r] = int(base.get(r, 0)) + _round_half_up(float(base.get(r, 0)) * float(pct) / 100.0)
	return total


# =============================================================================
#  Başlatma kapısı
# =============================================================================

## İnşa başlatılabilir mi? Ayrıntılı sonuç döndürür (UI/ekonomi için).
## Dönüş: `{ ok, reason, target_level, extra_percent, base_cost, cost, missing, projected }`
##   `reason` ∈ {"ok","unknown_building","max_level","requirements","locked","citizens","resources"}
static func can_start(state: Dictionary, village: Dictionary, key: String) -> Dictionary:
	var projected := projected_buildings(state, village)
	var cur := int(projected.get(key, 0))
	var tgt := cur + 1
	var vid := int(village.get("id", -1))
	var result := {
		"ok": false,
		"reason": "",
		"target_level": tgt,
		"extra_percent": 0,
		"base_cost": {},
		"cost": {},
		"missing": [],
		"projected": projected,
	}

	var maxl := _max_level(key)
	if maxl <= 0:
		result["reason"] = "unknown_building"
		return result
	if cur >= maxl:
		result["reason"] = "max_level"
		return result

	var missing := RE.missing_requirements(projected, key, tgt)
	if not missing.is_empty():
		result["reason"] = "requirements"
		result["missing"] = missing
		return result

	# Sıralı ilerleme kapısı (savunma amaçlı ikinci kontrol).
	if not RE.can_upgrade_now(projected, key):
		result["reason"] = "locked"
		return result

	var pct := extra_cost_percent(state, vid)
	var base := RE.cost(key, tgt)
	var total := {}
	for r in RESOURCES:
		total[r] = int(base.get(r, 0)) + _round_half_up(float(base.get(r, 0)) * float(pct) / 100.0)
	result["extra_percent"] = pct
	result["base_cost"] = base
	result["cost"] = total

	if not POP.can_afford_citizens(state, village, key, tgt):
		result["reason"] = "citizens"
		return result

	var res = village.get("resources", {})
	if typeof(res) != TYPE_DICTIONARY:
		result["reason"] = "resources"
		return result
	for r in RESOURCES:
		if int((res as Dictionary).get(r, 0)) < int(total.get(r, 0)):
			result["reason"] = "resources"
			return result

	result["ok"] = true
	result["reason"] = "ok"
	return result


# =============================================================================
#  İnşa başlatma
# =============================================================================

## Kuyruğa yeni bir yükseltme ekler; maliyeti **hemen** düşer.
## `now_unix` = simülasyon saati (bkz. dosya başlığı).
## Dönüş: `{ ok, reason, item?, cost?, extra_percent?, target_level?, start_unix?, finish_unix? }`
static func start_build(state: Dictionary, village: Dictionary, key: String, now_unix: int) -> Dictionary:
	var check := can_start(state, village, key)
	if not bool(check.get("ok", false)):
		return {"ok": false, "reason": str(check.get("reason", "invalid")), "check": check}

	var tgt := int(check.get("target_level", 0))
	var cost: Dictionary = check.get("cost", {})
	if not PROD.spend(village, cost):
		return {"ok": false, "reason": "resources", "check": check}

	var vid := int(village.get("id", -1))
	var q := queues(state)
	var start := maxi(now_unix, _last_finish(state, vid))
	var duration := RE.build_seconds(key, tgt)
	var finish := start + _round_half_up(duration)

	var item := {
		"id": _next_id(q),
		"village_id": vid,
		"type": TYPE,
		"key": key,
		"target_level": tgt,
		"count": 0,
		"start_unix": start,
		"finish_unix": finish,
		"cost_paid": cost.duplicate(true),
	}
	q.append(item)

	return {
		"ok": true,
		"reason": "ok",
		"item": item,
		"cost": cost,
		"extra_percent": int(check.get("extra_percent", 0)),
		"target_level": tgt,
		"start_unix": start,
		"finish_unix": finish,
		"check": check,
	}


## Bir köyün kuyruğundaki en son bitiş zamanı (yoksa 0).
static func _last_finish(state: Dictionary, village_id: int) -> int:
	var last := 0
	for item in items(state, village_id):
		last = maxi(last, int((item as Dictionary).get("finish_unix", 0)))
	return last


## Kuyruktaki işleri `now_unix`'ten başlayarak yeniden zincirler (iptal sonrası).
static func reschedule(state: Dictionary, village_id: int, now_unix: int) -> void:
	var cursor := now_unix
	for item in items(state, village_id):
		var key := str((item as Dictionary).get("key", ""))
		var tgt := int((item as Dictionary).get("target_level", 0))
		var duration := RE.build_seconds(key, tgt)
		(item as Dictionary)["start_unix"] = cursor
		cursor += _round_half_up(duration)
		(item as Dictionary)["finish_unix"] = cursor


# =============================================================================
#  İlerleme (tick)
# =============================================================================

## Tamamlanan bina işlerini uygular ve olayları döndürür (`docs/19` §7b).
## Aynı anda birden çok iş tamamlanabilir (offline hızlı-ileri).
static func advance(state: Dictionary, now_unix: int) -> Array:
	var events := []
	var q := queues(state)
	var steps := 0
	while steps < MAX_STEPS:
		steps += 1
		var item := _next_completable(q, now_unix)
		if item.is_empty():
			break
		var vid := int(item.get("village_id", -1))
		var village := _village_of(state, vid)
		var item_id := int(item.get("id", -1))
		if village.is_empty():
			# Köy artık yok (fetih/terk) → öğeyi sessizce düşür (tutarlılık).
			_remove_by_id(q, item_id)
			continue
		var key := str(item.get("key", ""))
		var level := int(item.get("target_level", 0))
		VM.set_building_level(village, key, level)  # puan + Güç Alanı tavanını tazeler
		_remove_by_id(q, item_id)
		events.append({
			"type": "building_completed",
			"village_id": vid,
			"key": key,
			"level": level,
		})
	return events


## Tamamlanmaya hazır **sıradaki baş** öğeyi döndürür (her köy için en erken iş).
## Village bazında sırayı korur: bir köyün baş işi bitmemişse sonraki işleri beklemede kalır.
static func _next_completable(q: Array, now_unix: int) -> Dictionary:
	# Köy → en erken start_unix'li öğe
	var heads := {}
	for item in q:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if str((item as Dictionary).get("type", "")) != TYPE:
			continue
		var vid := int((item as Dictionary).get("village_id", -1))
		var cur = heads.get(vid, null)
		if cur == null or int((item as Dictionary).get("start_unix", 0)) < int((cur as Dictionary).get("start_unix", 0)):
			heads[vid] = item

	var best := {}
	for vid in heads.keys():
		var head: Dictionary = heads[vid]
		if int(head.get("finish_unix", 0)) > now_unix:
			continue
		if best.is_empty() or int(head.get("finish_unix", 0)) < int(best.get("finish_unix", 0)):
			best = head
	return best


static func _remove_by_id(q: Array, item_id: int) -> bool:
	for i in range(q.size()):
		var item = q[i]
		if typeof(item) == TYPE_DICTIONARY and int((item as Dictionary).get("id", -1)) == item_id:
			q.remove_at(i)
			return true
	return false


static func _next_id(q: Array) -> int:
	var max_id := 0
	for item in q:
		if typeof(item) == TYPE_DICTIONARY:
			max_id = maxi(max_id, int((item as Dictionary).get("id", 0)))
	return max_id + 1


# =============================================================================
#  İptal (geri ödeme YOK — AÇIK SORU; bkz. ASSUMPTIONS.md §3)
# =============================================================================

## Kuyruk öğesini iptal eder. **Varsayılan: geri ödeme YOK.**
## Dönüş: `{ ok, reason, item?, refunded }`
static func cancel_build(state: Dictionary, village_id: int, item_id: int, refund: bool = false, now_unix: int = 0) -> Dictionary:
	var q := queues(state)
	var idx := -1
	for i in range(q.size()):
		var item = q[i]
		if typeof(item) == TYPE_DICTIONARY and int((item as Dictionary).get("id", -1)) == item_id \
				and int((item as Dictionary).get("village_id", -1)) == village_id:
			idx = i
			break
	if idx < 0:
		return {"ok": false, "reason": "not_found", "refunded": {"wood": 0, "stone": 0, "iron": 0}}

	var item: Dictionary = q[idx]
	var refunded := {"wood": 0, "stone": 0, "iron": 0}
	if refund:
		var village := _village_of(state, village_id)
		if not village.is_empty():
			refunded = PROD.add(village, item.get("cost_paid", {}))

	q.remove_at(idx)
	reschedule(state, village_id, now_unix)
	return {"ok": true, "reason": "ok", "item": item, "refunded": refunded}


# =============================================================================
#  Yıkım (Tear down)
# =============================================================================

## Bina yıkar. Koşullar: Kale (main) ≥ 15 + Simyager tekniği + `GameConfig.tear_down_building`.
## **Hammadde iadesi YOK**; **vatandaş geri gelir** (bina `workersTotal`'ı serbest bırakır).
## Dönüş: `{ ok, reason, released_citizens }`
static func tear_down(state: Dictionary, village: Dictionary, key: String, technique_researched: bool = true) -> Dictionary:
	var result := {"ok": false, "reason": "", "released_citizens": 0}
	var gc := _game_config()
	if gc != null and not bool(gc.get("tear_down_building")):
		result["reason"] = "disabled"
		return result
	if VM.building_level(village, "main") < 15:
		result["reason"] = "castle_level"
		return result
	if not technique_researched:
		result["reason"] = "technique"
		return result
	var level := VM.building_level(village, key)
	if level <= 0:
		result["reason"] = "empty"
		return result
	var vid := int(village.get("id", -1))
	for item in items(state, vid):
		if str((item as Dictionary).get("key", "")) == key:
			result["reason"] = "busy"
			return result
	var released := POP.workers_total(key, level)
	VM.set_building_level(village, key, 0)
	result["ok"] = true
	result["reason"] = "ok"
	result["released_citizens"] = released
	return result
