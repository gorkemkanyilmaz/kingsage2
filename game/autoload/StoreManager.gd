extends Node
## StoreManager — Elmas, Hızlandırma Parşömenleri ve iOS StoreKit IAP Yöneticisi (Taht ve Kılıç).

signal diamonds_changed(amount: int)
signal scrolls_changed(scrolls: Dictionary)
signal scroll_purchased(scroll_id: String, qty: int)
signal scroll_used(category: String, scroll_id: String, seconds_reduced: int)
signal resources_purchased(pack_id: String, added_resources: Dictionary)
signal purchase_completed(ok: bool, product_id: String, diamonds_added: int, message: String)
signal products_updated(products: Dictionary)

const GameLoopScript := preload("res://scripts/core/GameLoop.gd")
const RulesEngineScript := preload("res://scripts/rules/RulesEngine.gd")

const STARTER_DIAMONDS := 35

const DIAMOND_PACKS: Array[Dictionary] = [
	{
		"id": "diamonds_10",
		"product_id": "com.tahtkilic.kingsage2.diamonds_10",
		"name": "Avuç Dolusu Elmas",
		"diamonds": 10,
		"badge": "Başlangıç",
		"usd": "$0.99",
		"eur": "€0.99",
		"try": "₺49,99",
	},
	{
		"id": "diamonds_50",
		"product_id": "com.tahtkilic.kingsage2.diamonds_50",
		"name": "Kese Elmas",
		"diamonds": 50,
		"badge": "+%10 Değer",
		"usd": "$4.99",
		"eur": "€5.99",
		"try": "₺249,99",
	},
	{
		"id": "diamonds_100",
		"product_id": "com.tahtkilic.kingsage2.diamonds_100",
		"name": "Hazine Sandığı",
		"diamonds": 100,
		"badge": "⭐ En Popüler",
		"usd": "$7.99",
		"eur": "€8.99",
		"try": "₺399,99",
	},
	{
		"id": "diamonds_250",
		"product_id": "com.tahtkilic.kingsage2.diamonds_250",
		"name": "Kraliyet Kasası",
		"diamonds": 250,
		"badge": "+%30 Değer",
		"usd": "$17.99",
		"eur": "€19.99",
		"try": "₺999,99",
	},
	{
		"id": "diamonds_1000",
		"product_id": "com.tahtkilic.kingsage2.diamonds_1000",
		"name": "İmparator Hazinesi",
		"diamonds": 1000,
		"badge": "👑 En İyi Değer",
		"usd": "$59.99",
		"eur": "€69.99",
		"try": "₺2.999,99",
	},
]

const SPEEDUP_SCROLLS: Array[Dictionary] = [
	{
		"id": "build_10m",
		"category": "build",
		"seconds": 600,
		"cost_diamonds": 5,
		"name": "İnşaat 10 Dk",
		"description": "Aktif inşaat süresini 10 dakika kısaltır.",
	},
	{
		"id": "build_30m",
		"category": "build",
		"seconds": 1800,
		"cost_diamonds": 12,
		"name": "İnşaat 30 Dk",
		"description": "Aktif inşaat süresini 30 dakika kısaltır.",
	},
	{
		"id": "build_60m",
		"category": "build",
		"seconds": 3600,
		"cost_diamonds": 20,
		"name": "İnşaat 1 Saat",
		"description": "Aktif inşaat süresini 1 saat kısaltır.",
	},
	{
		"id": "train_10m",
		"category": "train",
		"seconds": 600,
		"cost_diamonds": 5,
		"name": "Asker Eğitimi 10 Dk",
		"description": "Asker eğitim süresini 10 dakika kısaltır.",
	},
	{
		"id": "train_30m",
		"category": "train",
		"seconds": 1800,
		"cost_diamonds": 12,
		"name": "Asker Eğitimi 30 Dk",
		"description": "Asker eğitim süresini 30 dakika kısaltır.",
	},
	{
		"id": "train_60m",
		"category": "train",
		"seconds": 3600,
		"cost_diamonds": 20,
		"name": "Asker Eğitimi 1 Saat",
		"description": "Asker eğitim süresini 1 saat kısaltır.",
	},
	{
		"id": "research_10m",
		"category": "research",
		"seconds": 600,
		"cost_diamonds": 6,
		"name": "Araştırma 10 Dk",
		"description": "Birim araştırma süresini 10 dakika kısaltır.",
	},
	{
		"id": "research_30m",
		"category": "research",
		"seconds": 1800,
		"cost_diamonds": 15,
		"name": "Araştırma 30 Dk",
		"description": "Birim araştırma süresini 30 dakika kısaltır.",
	},
	{
		"id": "research_60m",
		"category": "research",
		"seconds": 3600,
		"cost_diamonds": 25,
		"name": "Araştırma 1 Saat",
		"description": "Birim araştırma süresini 1 saat kısaltır.",
	},
	{
		"id": "march_10m",
		"category": "march",
		"seconds": 600,
		"cost_diamonds": 8,
		"name": "Sefer Hızlandırma 10 Dk",
		"description": "Ordu yürüyüş veya dönüş süresini 10 dakika kısaltır.",
	},
	{
		"id": "march_30m",
		"category": "march",
		"seconds": 1800,
		"cost_diamonds": 18,
		"name": "Sefer Hızlandırma 30 Dk",
		"description": "Ordu yürüyüş veya dönüş süresini 30 dakika kısaltır.",
	},
	{
		"id": "march_60m",
		"category": "march",
		"seconds": 3600,
		"cost_diamonds": 30,
		"name": "Sefer Hızlandırma 1 Saat",
		"description": "Ordu yürüyüş veya dönüş süresini 1 saat kısaltır.",
	},
]

const RESOURCE_PACKS: Array[Dictionary] = [
	{
		"id": "res_wood_1000",
		"name": "1.000 Odun Sandığı",
		"cost_diamonds": 5,
		"wood": 1000,
		"stone": 0,
		"iron": 0,
		"fill_storage": false,
		"badge": "🪵 Kereste",
		"description": "Aktif köy ambarına anında +1.000 Odun ekler.",
	},
	{
		"id": "res_stone_1000",
		"name": "1.000 Taş Sandığı",
		"cost_diamonds": 5,
		"wood": 0,
		"stone": 1000,
		"iron": 0,
		"fill_storage": false,
		"badge": "🪨 Taş Blok",
		"description": "Aktif köy ambarına anında +1.000 Taş ekler.",
	},
	{
		"id": "res_iron_1000",
		"name": "1.000 Demir Sandığı",
		"cost_diamonds": 5,
		"wood": 0,
		"stone": 0,
		"iron": 1000,
		"fill_storage": false,
		"badge": "⛏️ Cevher",
		"description": "Aktif köy ambarına anında +1.000 Demir ekler.",
	},
	{
		"id": "res_bundle_1500",
		"name": "Kraliyet Erzak Paketi (+1.500 Tümü)",
		"cost_diamonds": 12,
		"wood": 1500,
		"stone": 1500,
		"iron": 1500,
		"fill_storage": false,
		"badge": "⭐ Avantajlı",
		"description": "Aktif köye +1.500 Odun, +1.500 Taş ve +1.500 Demir ekler.",
	},
	{
		"id": "res_bundle_5000",
		"name": "İmparatorluk Hazine Kervanı (+5.000 Tümü)",
		"cost_diamonds": 35,
		"wood": 5000,
		"stone": 5000,
		"iron": 5000,
		"fill_storage": false,
		"badge": "👑 Büyük Paket",
		"description": "Aktif köye +5.000 Odun, +5.000 Taş ve +5.000 Demir ekler.",
	},
	{
		"id": "res_fill_storage",
		"name": "Ambarları Doldur (%100 Tam Depo)",
		"cost_diamonds": 25,
		"wood": 0,
		"stone": 0,
		"iron": 0,
		"fill_storage": true,
		"badge": "🏛️ Tam Kapasite",
		"description": "Aktif köyün Odun, Taş ve Demir ambarlarını Depo kapasitesinin %100'üne doldurur.",
	},
]

const IAP_REQ_USER_PATH := "user://native_iap_req.json"
const IAP_RES_USER_PATH := "user://native_iap_res.json"
const IAP_PRODUCTS_USER_PATH := "user://native_iap_products.json"

var preferred_currency: String = "TRY"  # "TRY" | "USD" | "EUR"
var localized_prices: Dictionary = {}

var _processed_transactions: Dictionary = {}
var _sandbox_tx_seq: int = 0
var _req_seq: int = 0
var _iap_poll_timer: Timer = null
var _products_poll_timer: Timer = null
var _last_seen_diamonds: int = -1
var _last_seen_scrolls_json: String = ""
var _suppress_bus_sync: bool = false


func _ready() -> void:
	var bus := _autoload("EventBus")
	if bus != null:
		if bus.has_signal("state_changed") and not bus.state_changed.is_connected(_on_external_state_changed):
			bus.state_changed.connect(_on_external_state_changed)
		if bus.has_signal("game_loaded") and not bus.game_loaded.is_connected(_on_external_state_changed):
			bus.game_loaded.connect(_on_external_state_changed)
	_sync_cached_wallet()
	if OS.get_name() == "iOS" and DisplayServer.get_name() != "headless":
		call_deferred("fetch_ios_products")


func _autoload(node_name: String) -> Node:
	if is_inside_tree() and get_tree() != null and get_tree().root != null:
		var n := get_tree().root.get_node_or_null(node_name)
		if n != null:
			return n
	var loop := Engine.get_main_loop()
	if loop is SceneTree and (loop as SceneTree).root != null:
		return (loop as SceneTree).root.get_node_or_null(node_name)
	return null


func _scene_root(parent_node: Node = null) -> Node:
	if parent_node != null and parent_node.is_inside_tree() and parent_node.get_tree() != null:
		return parent_node.get_tree().root
	if is_inside_tree() and get_tree() != null:
		return get_tree().root
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root
	return parent_node


func _game_state() -> Node:
	return _autoload("GameState")


func _ensure_player_wallet(gs: Node) -> void:
	if gs == null:
		return
	var p = gs.get("player")
	if typeof(p) != TYPE_DICTIONARY:
		p = {}
		gs.set("player", p)
	var player_dict := p as Dictionary
	if not player_dict.has("diamonds") or player_dict.get("diamonds") == null:
		player_dict["diamonds"] = STARTER_DIAMONDS
	else:
		player_dict["diamonds"] = maxi(0, int(player_dict.get("diamonds", STARTER_DIAMONDS)))
	if not player_dict.has("scrolls") or typeof(player_dict.get("scrolls")) != TYPE_DICTIONARY:
		player_dict["scrolls"] = {}


func _sync_cached_wallet() -> void:
	var d := get_diamonds()
	var s := _normalized_scrolls()
	var s_json := JSON.stringify(s)
	var d_changed := (_last_seen_diamonds != -1 and d != _last_seen_diamonds)
	var s_changed := (not _last_seen_scrolls_json.is_empty() and s_json != _last_seen_scrolls_json)
	_last_seen_diamonds = d
	_last_seen_scrolls_json = s_json
	if d_changed:
		diamonds_changed.emit(d)
	if s_changed:
		scrolls_changed.emit(s)


func _on_external_state_changed() -> void:
	if _suppress_bus_sync:
		return
	_sync_cached_wallet()


func _normalized_scrolls() -> Dictionary:
	var gs := _game_state()
	if gs == null:
		return {}
	var p = gs.get("player")
	if typeof(p) != TYPE_DICTIONARY:
		return {}
	var raw_scrolls = (p as Dictionary).get("scrolls", {})
	if typeof(raw_scrolls) != TYPE_DICTIONARY:
		return {}
	var out: Dictionary = {}
	for k in (raw_scrolls as Dictionary).keys():
		var cnt := maxi(0, int((raw_scrolls as Dictionary)[k]))
		if cnt > 0:
			out[str(k)] = cnt
	return out


func get_diamonds() -> int:
	var gs := _game_state()
	if gs == null:
		return STARTER_DIAMONDS
	var p = gs.get("player")
	if typeof(p) != TYPE_DICTIONARY:
		return STARTER_DIAMONDS
	var player_dict := p as Dictionary
	if not player_dict.has("diamonds") or player_dict.get("diamonds") == null:
		return STARTER_DIAMONDS
	return maxi(0, int(player_dict.get("diamonds", STARTER_DIAMONDS)))


func get_scrolls() -> Dictionary:
	return _normalized_scrolls()


func get_scroll_count(scroll_id: String) -> int:
	var gs := _game_state()
	if gs == null:
		return 0
	var p = gs.get("player")
	if typeof(p) != TYPE_DICTIONARY:
		return 0
	var raw_scrolls = (p as Dictionary).get("scrolls", {})
	if typeof(raw_scrolls) != TYPE_DICTIONARY:
		return 0
	return maxi(0, int((raw_scrolls as Dictionary).get(scroll_id, 0)))


func get_category_scroll_total(category: String) -> int:
	var total := 0
	for s in SPEEDUP_SCROLLS:
		if str(s.get("category", "")) == category:
			total += get_scroll_count(str(s.get("id", "")))
	return total


func get_scrolls_for_category(category: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s in SPEEDUP_SCROLLS:
		if str(s.get("category", "")) == category:
			out.append(s.duplicate(true))
	return out


func get_scroll_def(scroll_id: String) -> Dictionary:
	for s in SPEEDUP_SCROLLS:
		if str(s.get("id", "")) == scroll_id:
			return s.duplicate(true)
	return {}


func get_pack_def(pack_id_or_product_id: String) -> Dictionary:
	for p in DIAMOND_PACKS:
		if str(p.get("id", "")) == pack_id_or_product_id or str(p.get("product_id", "")) == pack_id_or_product_id:
			return p.duplicate(true)
	return {}


func get_resource_packs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for rp in RESOURCE_PACKS:
		out.append(rp.duplicate(true))
	return out


func get_resource_pack_def(pack_id: String) -> Dictionary:
	for rp in RESOURCE_PACKS:
		if str(rp.get("id", "")) == pack_id:
			return rp.duplicate(true)
	return {}


func get_pack_price_label(pack: Dictionary, currency_override: String = "") -> String:
	var cur := currency_override.strip_edges().to_upper()
	if cur.is_empty():
		cur = preferred_currency.strip_edges().to_upper()
	var pid := str(pack.get("product_id", ""))
	if OS.get_name() == "iOS" and localized_prices.has(pid):
		var loc := str(localized_prices.get(pid, "")).strip_edges()
		if not loc.is_empty():
			if cur == "TRY" and (loc.contains("₺") or loc.to_upper().contains("TL") or loc.to_upper().contains("TRY")):
				return loc
			if cur == "USD" and loc.contains("$"):
				return loc
			if cur == "EUR" and loc.contains("€"):
				return loc
	match cur:
		"USD":
			return str(pack.get("usd", "$0.99"))
		"EUR":
			return str(pack.get("eur", "€0.99"))
		_:
			return str(pack.get("try", "₺49,99"))


static func format_duration(secs: int) -> String:
	var s := maxi(0, secs)
	if s >= 3600:
		var h := s / 3600
		var m := (s % 3600) / 60
		var rem := s % 60
		return "%02d:%02d:%02d" % [h, m, rem]
	return "%02d:%02d" % [s / 60, s % 60]


func _emit_wallet_and_state(save_now: bool = true) -> void:
	var wm := _autoload("WorldManager")
	if wm != null and wm.has_method("notify_local_wallet_mutation"):
		wm.call("notify_local_wallet_mutation")
	if save_now:
		if wm != null and wm.has_method("save_active_world"):
			wm.call("save_active_world", true)
		var sm := _autoload("SaveManager")
		if sm != null and sm.has_method("save_game"):
			sm.save_game()
	var d := get_diamonds()
	var s := _normalized_scrolls()
	_last_seen_diamonds = d
	_last_seen_scrolls_json = JSON.stringify(s)
	diamonds_changed.emit(d)
	scrolls_changed.emit(s)
	var bus := _autoload("EventBus")
	if bus != null and bus.has_signal("state_changed"):
		_suppress_bus_sync = true
		bus.state_changed.emit()
		_suppress_bus_sync = false


func _current_sim_now() -> int:
	var wall_now := int(Time.get_unix_time_from_system())
	var best_now := wall_now
	if GameLoopScript.instance != null:
		var gl_now := int(GameLoopScript.instance.now_unix())
		if gl_now > 0:
			best_now = maxi(best_now, gl_now)
	var gs := _game_state()
	if gs != null and typeof(gs.get("world")) == TYPE_DICTIONARY:
		var w := gs.get("world") as Dictionary
		if w.has("sim_now_unix"):
			best_now = maxi(best_now, int(w.get("sim_now_unix", 0)))
	return best_now


func buy_scroll(scroll_id: String, qty: int = 1) -> Dictionary:
	if qty < 1:
		return {"ok": false, "error": "Geçersiz parşömen adedi."}
	var def := get_scroll_def(scroll_id)
	if def.is_empty():
		return {"ok": false, "error": "Bilinmeyen parşömen: %s" % scroll_id}
	var gs := _game_state()
	if gs == null:
		return {"ok": false, "error": "Oyun durumu hazır değil."}
	_ensure_player_wallet(gs)
	var player_dict := gs.get("player") as Dictionary
	var cur_diamonds := maxi(0, int(player_dict.get("diamonds", STARTER_DIAMONDS)))
	var total_cost := int(def.get("cost_diamonds", 0)) * qty
	if cur_diamonds < total_cost:
		return {"ok": false, "error": "Yetersiz elmas (Gereken: %d, Mevcut: %d)." % [total_cost, cur_diamonds]}

	var scrolls_dict := player_dict.get("scrolls") as Dictionary
	var new_diamonds := cur_diamonds - total_cost
	var new_count := maxi(0, int(scrolls_dict.get(scroll_id, 0))) + qty
	player_dict["diamonds"] = new_diamonds
	scrolls_dict[scroll_id] = new_count

	_suppress_bus_sync = true
	_emit_wallet_and_state(true)
	_suppress_bus_sync = false
	scroll_purchased.emit(scroll_id, qty)

	# Çevrimiçi ise sunucuda da eşitle
	if DisplayServer.get_name() != "headless":
		var net := _autoload("NetworkManager")
		if net != null and not str(net.get("auth_token")).is_empty() and net.has_method("api_request"):
			net.api_request("/api/store/buy_scroll", HTTPClient.METHOD_POST, {
				"scroll_id": scroll_id,
				"qty": qty,
			}, Callable())

	return {
		"ok": true,
		"error": "",
		"diamonds": new_diamonds,
		"count": new_count,
	}


func buy_resource_pack(pack_id: String) -> Dictionary:
	var def := get_resource_pack_def(pack_id)
	if def.is_empty():
		return {"ok": false, "error": "Bilinmeyen kaynak paketi: %s" % pack_id}
	var gs := _game_state()
	if gs == null or not gs.has_method("get_active_village"):
		return {"ok": false, "error": "Aktif köy bulunamadı."}
	var v: Dictionary = gs.call("get_active_village")
	if v.is_empty():
		return {"ok": false, "error": "Aktif köy bulunamadı."}

	_ensure_player_wallet(gs)
	var player_dict := gs.get("player") as Dictionary
	var cur_diamonds := maxi(0, int(player_dict.get("diamonds", STARTER_DIAMONDS)))
	var cost := int(def.get("cost_diamonds", 5))
	if cur_diamonds < cost:
		return {"ok": false, "error": "Yetersiz elmas (Gereken: %d, Mevcut: %d)." % [cost, cur_diamonds]}

	var blds: Dictionary = v.get("buildings", {}) if typeof(v.get("buildings")) == TYPE_DICTIONARY else {}
	var storage_lvl := maxi(1, int(blds.get("storage", blds.get("warehouse", 1))))
	var cap := maxi(1000, int(RulesEngineScript.storage_capacity(storage_lvl)))
	var res: Dictionary = v.get("resources", {}) if typeof(v.get("resources")) == TYPE_DICTIONARY else {"wood": 0, "stone": 0, "iron": 0}

	var is_fill := bool(def.get("fill_storage", false))
	var added := {"wood": 0, "stone": 0, "iron": 0}
	var total_added := 0
	for rk in ["wood", "stone", "iron"]:
		var cur_val := maxi(0, int(res.get(rk, 0)))
		var req_add := int(def.get(rk, 0))
		var next_val := cur_val
		if is_fill:
			next_val = maxi(cur_val, cap)
		elif req_add > 0:
			next_val = mini(cap, cur_val + req_add)
		var diff := maxi(0, next_val - cur_val)
		added[rk] = diff
		total_added += diff

	if total_added <= 0:
		return {"ok": false, "error": "Depo tamamen dolu (%d / %d)! Önce Depo'yu yükseltin veya kaynak harcayın." % [cap, cap]}

	for rk in ["wood", "stone", "iron"]:
		if int(added[rk]) > 0:
			res[rk] = maxi(0, int(res.get(rk, 0))) + int(added[rk])
	v["resources"] = res

	var new_diamonds := cur_diamonds - cost
	player_dict["diamonds"] = new_diamonds

	var vid := int(v.get("id", gs.get("active_village_id")))
	var bus := _autoload("EventBus")
	if bus != null and bus.has_signal("resources_changed"):
		bus.resources_changed.emit(vid)

	_emit_wallet_and_state(true)
	resources_purchased.emit(pack_id, added)

	if DisplayServer.get_name() != "headless":
		var net := _autoload("NetworkManager")
		if net != null and not str(net.get("auth_token")).is_empty() and net.has_method("api_request"):
			net.api_request("/api/store/buy_resources", HTTPClient.METHOD_POST, {
				"pack_id": pack_id,
				"village_id": vid,
			}, Callable())

	return {
		"ok": true,
		"error": "",
		"diamonds": new_diamonds,
		"added_resources": added,
		"resources": res.duplicate(true),
		"storage_cap": cap,
	}


func apply_scroll_to_queue(scroll_id: String, category: String, target_id: Variant = null) -> Dictionary:
	var def := get_scroll_def(scroll_id)
	if def.is_empty():
		return {"ok": false, "error": "Bilinmeyen parşömen."}
	var def_cat := str(def.get("category", ""))
	if def_cat != category:
		return {"ok": false, "error": "Parşömen kategorisi eşleşmiyor."}
	var gs := _game_state()
	if gs == null:
		return {"ok": false, "error": "Oyun durumu hazır değil."}
	_ensure_player_wallet(gs)
	if get_scroll_count(scroll_id) < 1:
		return {"ok": false, "error": "Bu parşömenden envanterde yok."}

	var scroll_secs := maxi(1, int(def.get("seconds", 0)))
	var now := _current_sim_now()

	if category in ["build", "train", "research"]:
		return _apply_scroll_to_village_queue(gs, scroll_id, category, scroll_secs, target_id, now)
	if category == "march":
		return _apply_scroll_to_march(gs, scroll_id, scroll_secs, target_id, now)

	return {"ok": false, "error": "Desteklenmeyen hızlandırma kategorisi."}


func _find_queue_target_index(items: Array, target_id: Variant) -> int:
	if target_id == null:
		return 0
	if typeof(target_id) == TYPE_STRING and str(target_id).strip_edges().is_empty():
		return 0
	var tgt_str := str(target_id)
	var is_num := (typeof(target_id) == TYPE_INT or typeof(target_id) == TYPE_FLOAT)
	var tgt_int := int(target_id) if is_num else -999999

	for i in range(items.size()):
		var it := items[i] as Dictionary
		if it.has("id"):
			if str(it.get("id", "")) == tgt_str:
				return i
			if is_num and int(it.get("id", -999999)) == tgt_int:
				return i
	if typeof(target_id) == TYPE_STRING:
		for i in range(items.size()):
			var it := items[i] as Dictionary
			if str(it.get("key", "")) == tgt_str:
				return i
	if is_num and tgt_int >= 0 and tgt_int < items.size():
		return tgt_int
	return -1


func _apply_scroll_to_village_queue(gs: Node, scroll_id: String, category: String, scroll_secs: int, target_id: Variant, now: int) -> Dictionary:
	var active_vid := int(gs.get("active_village_id"))
	var queues_raw = gs.get("queues")
	if typeof(queues_raw) != TYPE_ARRAY:
		return {"ok": false, "error": "Aktif kuyruk bulunamadı."}

	var matching: Array = []
	for item in (queues_raw as Array):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var d := item as Dictionary
		if int(d.get("village_id", -1)) == active_vid and str(d.get("type", "")) == category:
			matching.append(d)

	if matching.is_empty():
		return {"ok": false, "error": "Bu kategoride aktif kuyruk öğesi yok."}

	matching.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa := int(a.get("start_unix", 0))
		var sb := int(b.get("start_unix", 0))
		if sa != sb:
			return sa < sb
		var fa := int(a.get("finish_unix", 0))
		var fb := int(b.get("finish_unix", 0))
		if fa != fb:
			return fa < fb
		return int(a.get("id", 0)) < int(b.get("id", 0))
	)

	var start_idx := _find_queue_target_index(matching, target_id)
	if start_idx < 0:
		return {"ok": false, "error": "Hedef kuyruk öğesi bulunamadı."}

	var pool := scroll_secs
	var total_reduced := 0
	var saved_so_far := 0
	var any_completed := false

	for i in range(start_idx, matching.size()):
		var item := matching[i] as Dictionary
		var old_start := int(item.get("start_unix", now))
		var old_finish := int(item.get("finish_unix", now))

		if i > start_idx and saved_so_far > 0 and old_start > now:
			var shift := mini(saved_so_far, old_start - now)
			old_start -= shift
			old_finish = maxi(old_start, old_finish - shift)
			item["start_unix"] = old_start
			item["finish_unix"] = old_finish

		if pool > 0:
			var eff_start := maxi(now, old_start)
			var cur_rem := maxi(0, old_finish - eff_start)
			var rem_secs := mini(cur_rem, pool)
			var new_finish := old_finish - rem_secs
			if cur_rem <= pool:
				new_finish = mini(new_finish, now)
				if eff_start <= now:
					any_completed = true
			new_finish = maxi(1, new_finish)
			item["finish_unix"] = new_finish
			pool -= rem_secs
			total_reduced += rem_secs
			saved_so_far += rem_secs

			if new_finish <= now:
				any_completed = true

	if total_reduced <= 0 and not any_completed:
		return {"ok": false, "error": "Kısaltılacak süre bulunamadı."}

	_consume_scroll(gs, scroll_id, category, target_id, active_vid)
	if any_completed:
		_trigger_simulation(gs, now)

	_emit_wallet_and_state(true)
	scroll_used.emit(category, scroll_id, total_reduced)
	return {
		"ok": true,
		"error": "",
		"reduced_seconds": total_reduced,
		"completed": any_completed,
	}


func _norm_player_name(raw_name: String) -> String:
	var n := raw_name.strip_edges()
	while n.to_lower().begins_with("lord lord "):
		n = n.substr(5).strip_edges()
	return n.to_lower()


func _is_player_movement(m: Dictionary, active_vid: int, player_name: String, owned_vids: Dictionary = {}) -> bool:
	var owner := _norm_player_name(str(m.get("owner", "")))
	var p_norm := _norm_player_name(player_name)
	var m_state := str(m.get("state", "outgoing"))
	var m_type := str(m.get("type", ""))
	var is_ret := (m_state == "returning" or m_type == "return")
	if not p_norm.is_empty() and not owner.is_empty() and owner == p_norm:
		return true
	var v_id := int(m.get("village_id", -1))
	var f_id := int(m.get("from_village_id", -1))
	var t_id := int(m.get("to_village_id", -1))
	if not owned_vids.is_empty():
		if owned_vids.has(v_id):
			return true
		if not is_ret and owned_vids.has(f_id):
			return true
		if is_ret and owned_vids.has(t_id):
			return true
	if active_vid > 0:
		if v_id == active_vid:
			return true
		if not is_ret and f_id == active_vid:
			return true
		if is_ret and t_id == active_vid:
			return true
	return false


func _apply_scroll_to_march(gs: Node, scroll_id: String, scroll_secs: int, target_id: Variant, now: int) -> Dictionary:
	var movements_raw = gs.get("movements")
	if typeof(movements_raw) != TYPE_ARRAY:
		return {"ok": false, "error": "Aktif sefer bulunamadı."}

	var active_vid := int(gs.get("active_village_id"))
	var player_dict: Dictionary = gs.get("player") if typeof(gs.get("player")) == TYPE_DICTIONARY else {}
	var player_name := str(player_dict.get("name", "")).strip_edges()
	var owned_vids: Dictionary = {}
	if gs.has_method("get_player_villages"):
		for pv in gs.call("get_player_villages"):
			if typeof(pv) == TYPE_DICTIONARY:
				owned_vids[int((pv as Dictionary).get("id", -1))] = true
	if active_vid > 0:
		owned_vids[active_vid] = true

	var candidates: Array = []
	for mv in (movements_raw as Array):
		if typeof(mv) != TYPE_DICTIONARY:
			continue
		var m := mv as Dictionary
		if _is_player_movement(m, active_vid, player_name, owned_vids):
			candidates.append(m)

	if candidates.is_empty():
		return {"ok": false, "error": "Hızlandırılacak aktif sefer bulunamadı."}

	var target_m: Dictionary = {}
	if target_id == null or (typeof(target_id) == TYPE_STRING and str(target_id).strip_edges().is_empty()):
		target_m = candidates[0] as Dictionary
	else:
		var tgt_str := str(target_id)
		var is_num := (typeof(target_id) == TYPE_INT or typeof(target_id) == TYPE_FLOAT)
		var tgt_int := int(target_id) if is_num else -999999
		for mv in candidates:
			var m := mv as Dictionary
			if m.has("id") and (str(m.get("id", "")) == tgt_str or (is_num and int(m.get("id", -999999)) == tgt_int)):
				target_m = m
				break
		if target_m.is_empty() and is_num and tgt_int >= 0 and tgt_int < candidates.size():
			target_m = candidates[tgt_int] as Dictionary
		if target_m.is_empty():
			target_m = candidates[0] as Dictionary

	var depart_u := int(target_m.get("depart_unix", 0))
	var old_arrive := int(target_m.get("arrive_unix", 0))
	if not target_m.has("base_travel_seconds"):
		target_m["base_travel_seconds"] = maxi(1, old_arrive - depart_u)

	var cur_rem := maxi(0, old_arrive - now)
	var applied := mini(cur_rem, scroll_secs)
	if applied <= 0 and old_arrive > now:
		applied = mini(old_arrive - now, scroll_secs)

	var new_arrive := maxi(1, old_arrive - applied)
	if new_arrive <= now:
		new_arrive = now
	var is_returning := (str(target_m.get("state", "")) == "returning" or str(target_m.get("type", "")) == "return")
	target_m["arrive_unix"] = new_arrive
	target_m["depart_unix"] = depart_u - applied
	target_m["return_unix"] = new_arrive if is_returning else (new_arrive + int(target_m["base_travel_seconds"]))

	var completed := (new_arrive <= now)
	var used_mid: Variant = target_m.get("id", target_id)
	_consume_scroll(gs, scroll_id, "march", used_mid, active_vid)
	if completed:
		_trigger_simulation(gs, now)

	_emit_wallet_and_state(true)
	scroll_used.emit("march", scroll_id, applied)
	return {
		"ok": true,
		"error": "",
		"reduced_seconds": applied,
		"completed": completed,
	}


func _consume_scroll(gs: Node, scroll_id: String, category: String = "", target_id: Variant = null, village_id: int = -1) -> void:
	_ensure_player_wallet(gs)
	var player_dict := gs.get("player") as Dictionary
	var scrolls_dict := player_dict.get("scrolls") as Dictionary
	var next_cnt := maxi(0, int(scrolls_dict.get(scroll_id, 0)) - 1)
	if next_cnt > 0:
		scrolls_dict[scroll_id] = next_cnt
	else:
		scrolls_dict.erase(scroll_id)
	if DisplayServer.get_name() != "headless":
		var net := _autoload("NetworkManager")
		if net != null and not str(net.get("auth_token")).is_empty() and net.has_method("api_request"):
			net.api_request("/api/store/use_scroll", HTTPClient.METHOD_POST, {
				"scroll_id": scroll_id,
				"category": category,
				"target_id": target_id,
				"village_id": village_id,
			}, Callable())


func _trigger_simulation(gs: Node, now: int) -> void:
	if GameLoopScript.instance != null and GameLoopScript.instance.now_unix() > 0:
		var gl_now := int(GameLoopScript.instance.now_unix())
		var dt := maxf(0.1, float(now - gl_now) + 0.1)
		GameLoopScript.instance.simulate(dt)

	# Hala now veya öncesinde bitmesi gereken hareket/kuyruk kaldıysa doğrudan simüle et
	var needs_direct := false
	if typeof(gs.get("movements")) == TYPE_ARRAY:
		for m in (gs.get("movements") as Array):
			if typeof(m) == TYPE_DICTIONARY and int((m as Dictionary).get("arrive_unix", now + 999)) <= now:
				needs_direct = true
				break
	if not needs_direct and typeof(gs.get("queues")) == TYPE_ARRAY:
		for q in (gs.get("queues") as Array):
			if typeof(q) == TYPE_DICTIONARY and int((q as Dictionary).get("finish_unix", now + 999)) <= now:
				needs_direct = true
				break
	if not needs_direct and GameLoopScript.instance != null and GameLoopScript.instance.now_unix() > 0:
		return

	var st: Dictionary = gs.call("to_dict")
	if typeof(st.get("world")) != TYPE_DICTIONARY:
		st["world"] = {}
	(st["world"] as Dictionary)["sim_now_unix"] = now

	var events: Array = []
	for path in [
		"res://scripts/sim/economy/EconomySimulator.gd",
		"res://scripts/sim/army/ArmySimulator.gd",
		"res://scripts/sim/actions/ActionSimulator.gd",
	]:
		if ResourceLoader.exists(path):
			var scr = load(path)
			if scr != null and scr.has_method("process_tick"):
				var ev = scr.process_tick(st, now, 0.1)
				if typeof(ev) == TYPE_ARRAY:
					events.append_array(ev)

	gs.call("from_dict", st)
	_emit_fallback_events(events)


func _emit_fallback_events(events: Array) -> void:
	var bus := _autoload("EventBus")
	if bus == null:
		return
	for e in events:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var ev := e as Dictionary
		var vid := int(ev.get("village_id", -1))
		match str(ev.get("type", "")):
			"building_completed":
				if bus.has_signal("building_completed"):
					bus.building_completed.emit(vid, str(ev.get("key", "")), int(ev.get("level", 0)))
			"research_completed":
				if bus.has_signal("research_completed"):
					bus.research_completed.emit(vid, str(ev.get("unit_key", ev.get("key", ""))))
			"unit_trained", "training_completed":
				if bus.has_signal("unit_trained"):
					bus.unit_trained.emit(vid, str(ev.get("unit_key", ev.get("key", ""))), int(ev.get("count", 0)))
			"battle_resolved":
				if bus.has_signal("battle_resolved"):
					bus.battle_resolved.emit(ev)
				if bus.has_signal("report_created"):
					bus.report_created.emit(ev)
			"spy_resolved":
				if bus.has_signal("spy_mission_resolved"):
					bus.spy_mission_resolved.emit(ev)
				if bus.has_signal("report_created"):
					bus.report_created.emit(ev)
			"movement_returned":
				if bus.has_signal("army_returned"):
					bus.army_returned.emit(ev)
				if bus.has_signal("resources_changed"):
					bus.resources_changed.emit(vid)
			"support_arrived":
				if bus.has_signal("army_arrived"):
					bus.army_arrived.emit(ev)
			"trade_delivered":
				if bus.has_signal("resources_changed"):
					bus.resources_changed.emit(vid)


func _docs_path_for(file_name: String) -> String:
	var home_dir := OS.get_environment("HOME").strip_edges()
	if home_dir.is_empty():
		return ""
	return home_dir.path_join("Documents").path_join(file_name)


func _write_iap_ipc_file(user_path: String, file_name: String, payload: Dictionary) -> void:
	var json_str := JSON.stringify(payload)
	var f := FileAccess.open(user_path, FileAccess.WRITE)
	if f != null:
		f.store_string(json_str)
		f.close()
	var docs_p := _docs_path_for(file_name)
	if not docs_p.is_empty():
		var abs_user := ProjectSettings.globalize_path(user_path)
		if docs_p != abs_user:
			var df := FileAccess.open(docs_p, FileAccess.WRITE)
			if df != null:
				df.store_string(json_str)
				df.close()


func _remove_iap_ipc_files(user_path: String, file_name: String) -> void:
	var abs_user := ProjectSettings.globalize_path(user_path)
	var docs_p := _docs_path_for(file_name)
	for p in [user_path, abs_user, docs_p]:
		if not p.is_empty() and FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _read_and_consume_iap_ipc_file(user_path: String, file_name: String) -> Dictionary:
	var found_path := ""
	var abs_user := ProjectSettings.globalize_path(user_path)
	var docs_p := _docs_path_for(file_name)
	if FileAccess.file_exists(user_path):
		found_path = user_path
	elif not docs_p.is_empty() and FileAccess.file_exists(docs_p):
		found_path = docs_p
	if found_path.is_empty():
		return {}
	var rf := FileAccess.open(found_path, FileAccess.READ)
	var txt := rf.get_as_text() if rf != null else ""
	if rf != null:
		rf.close()
	_remove_iap_ipc_files(user_path, file_name)
	if txt.is_empty():
		return {}
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed as Dictionary
	return {}


func fetch_ios_products() -> void:
	if OS.get_name() != "iOS" or DisplayServer.get_name() == "headless":
		products_updated.emit(localized_prices.duplicate(true))
		return

	_req_seq += 1
	var req_id := "prod_%d_%d" % [int(Time.get_unix_time_from_system()), _req_seq]
	_remove_iap_ipc_files(IAP_PRODUCTS_USER_PATH, "native_iap_products.json")
	var pids: Array = []
	for p in DIAMOND_PACKS:
		pids.append(str(p.get("product_id", "")))
	_write_iap_ipc_file(IAP_REQ_USER_PATH, "native_iap_req.json", {
		"action": "fetch_products",
		"req_id": req_id,
		"product_ids": pids,
	})

	if _products_poll_timer != null and is_instance_valid(_products_poll_timer):
		_products_poll_timer.stop()
		_products_poll_timer.queue_free()
	_products_poll_timer = Timer.new()
	_products_poll_timer.wait_time = 0.25
	var ticks := [0]
	_products_poll_timer.timeout.connect(func():
		ticks[0] += 1
		if ticks[0] > 80:
			if _products_poll_timer != null and is_instance_valid(_products_poll_timer):
				_products_poll_timer.stop()
				_products_poll_timer.queue_free()
				_products_poll_timer = null
			return
		var data := _read_and_consume_iap_ipc_file(IAP_PRODUCTS_USER_PATH, "native_iap_products.json")
		if data.is_empty():
			return
		var raw_prods = data.get("products", data)
		if typeof(raw_prods) == TYPE_DICTIONARY:
			for pid_k in (raw_prods as Dictionary).keys():
				var val = (raw_prods as Dictionary)[pid_k]
				if typeof(val) == TYPE_STRING:
					localized_prices[str(pid_k)] = str(val)
				elif typeof(val) == TYPE_DICTIONARY:
					var vd := val as Dictionary
					var ps := str(vd.get("price_string", vd.get("price", ""))).strip_edges()
					if not ps.is_empty():
						localized_prices[str(pid_k)] = ps
			products_updated.emit(localized_prices.duplicate(true))
		if _products_poll_timer != null and is_instance_valid(_products_poll_timer):
			_products_poll_timer.stop()
			_products_poll_timer.queue_free()
			_products_poll_timer = null
	)
	add_child(_products_poll_timer)
	_products_poll_timer.start()


func buy_diamond_pack(pack_id: String, callback: Callable = Callable()) -> void:
	var pack := get_pack_def(pack_id)
	if pack.is_empty():
		var err_msg := "Bilinmeyen elmas paketi."
		purchase_completed.emit(false, pack_id, 0, err_msg)
		_invoke_purchase_callback(callback, false, pack_id, 0, err_msg)
		return

	var product_id := str(pack.get("product_id", ""))
	if OS.get_name() == "iOS" and DisplayServer.get_name() != "headless":
		_start_ios_iap_request("purchase", pack, callback)
		return

	_sandbox_tx_seq += 1
	var tx_id := "sandbox_%s_%d_%d" % [str(pack.get("id", "")), int(Time.get_unix_time_from_system()), _sandbox_tx_seq]
	if DisplayServer.get_name() == "headless":
		_credit_iap_locally(pack, tx_id, "Satın alma tamamlandı (test).", callback)
		return

	_verify_and_credit_iap(pack, tx_id, "sandbox_web_desktop", "web_sandbox", callback)


func restore_ios_purchases(callback: Callable = Callable()) -> void:
	if OS.get_name() != "iOS" or DisplayServer.get_name() == "headless":
		var msg := "Geri yüklenecek iOS satın alımı bulunamadı."
		purchase_completed.emit(true, "", 0, msg)
		_invoke_purchase_callback(callback, true, "", 0, msg)
		return
	_start_ios_iap_request("restore", {}, callback)


func _start_ios_iap_request(action: String, pack: Dictionary, callback: Callable) -> void:
	_req_seq += 1
	var req_id := "iap_%d_%d" % [int(Time.get_unix_time_from_system()), _req_seq]
	var product_id := str(pack.get("product_id", ""))
	_remove_iap_ipc_files(IAP_RES_USER_PATH, "native_iap_res.json")

	var req_payload := {
		"action": action,
		"req_id": req_id,
	}
	if not product_id.is_empty():
		req_payload["product_id"] = product_id
		req_payload["pack_id"] = str(pack.get("id", ""))
	_write_iap_ipc_file(IAP_REQ_USER_PATH, "native_iap_req.json", req_payload)

	if _iap_poll_timer != null and is_instance_valid(_iap_poll_timer):
		_iap_poll_timer.stop()
		_iap_poll_timer.queue_free()
	_iap_poll_timer = Timer.new()
	_iap_poll_timer.wait_time = 0.2
	var ticks := [0]
	_iap_poll_timer.timeout.connect(func():
		ticks[0] += 1
		if ticks[0] > 600:
			_stop_iap_poll_timer()
			var t_msg := "App Store işlemi zaman aşımına uğradı."
			purchase_completed.emit(false, product_id, 0, t_msg)
			_invoke_purchase_callback(callback, false, product_id, 0, t_msg)
			return
		var data := _read_and_consume_iap_ipc_file(IAP_RES_USER_PATH, "native_iap_res.json")
		if data.is_empty():
			return
		var res_req_id := str(data.get("req_id", ""))
		if not res_req_id.is_empty() and res_req_id != req_id:
			return
		_stop_iap_poll_timer()

		if action == "restore":
			_handle_ios_restore_response(data, callback)
			return

		if bool(data.get("ok", false)):
			var tx_id := str(data.get("transaction_id", "")).strip_edges()
			if tx_id.is_empty():
				_sandbox_tx_seq += 1
				tx_id = "ios_%s_%d_%d" % [str(pack.get("id", "")), int(Time.get_unix_time_from_system()), _sandbox_tx_seq]
			var receipt := str(data.get("receipt_data", data.get("jws_representation", "")))
			var resolved_pid := str(data.get("product_id", product_id))
			var resolved_pack := get_pack_def(resolved_pid)
			if resolved_pack.is_empty():
				resolved_pack = pack
			_verify_and_credit_iap(resolved_pack, tx_id, receipt, "ios_storekit", callback)
		else:
			var err_msg := str(data.get("error", "Satın alma iptal edildi."))
			purchase_completed.emit(false, product_id, 0, err_msg)
			_invoke_purchase_callback(callback, false, product_id, 0, err_msg)
	)
	add_child(_iap_poll_timer)
	_iap_poll_timer.start()


func _stop_iap_poll_timer() -> void:
	if _iap_poll_timer != null and is_instance_valid(_iap_poll_timer):
		_iap_poll_timer.stop()
		_iap_poll_timer.queue_free()
	_iap_poll_timer = null


func _handle_ios_restore_response(data: Dictionary, callback: Callable) -> void:
	if not bool(data.get("ok", false)):
		var err_msg := str(data.get("error", "Satın alımlar geri yüklenemedi."))
		purchase_completed.emit(false, "", 0, err_msg)
		_invoke_purchase_callback(callback, false, "", 0, err_msg)
		return
	var tx_list: Array = []
	for key in ["transactions", "restored", "restored_products", "product_ids"]:
		if typeof(data.get(key)) == TYPE_ARRAY:
			tx_list = data.get(key) as Array
			break
	if tx_list.is_empty():
		var empty_msg := "Geri yüklenecek satın alım bulunamadı."
		purchase_completed.emit(true, "", 0, empty_msg)
		_invoke_purchase_callback(callback, true, "", 0, empty_msg)
		return
	var msg := "%d satın alım kontrol edildi." % tx_list.size()
	purchase_completed.emit(true, "", 0, msg)
	_invoke_purchase_callback(callback, true, "", 0, msg)


func _has_processed_tx(tx_id: String) -> bool:
	if tx_id.is_empty():
		return false
	if _processed_transactions.has(tx_id):
		return true
	var gs := _game_state()
	if gs != null and typeof(gs.get("player")) == TYPE_DICTIONARY:
		var p := gs.get("player") as Dictionary
		var tx_map = p.get("iap_transactions", {})
		if typeof(tx_map) == TYPE_DICTIONARY and (tx_map as Dictionary).has(tx_id):
			return true
	return false


func _mark_processed_tx(tx_id: String) -> void:
	if tx_id.is_empty():
		return
	_processed_transactions[tx_id] = true
	var gs := _game_state()
	if gs != null:
		_ensure_player_wallet(gs)
		var p := gs.get("player") as Dictionary
		if typeof(p.get("iap_transactions")) != TYPE_DICTIONARY:
			p["iap_transactions"] = {}
		(p["iap_transactions"] as Dictionary)[tx_id] = int(Time.get_unix_time_from_system())


func _credit_iap_locally(pack: Dictionary, tx_id: String, message: String, callback: Callable) -> void:
	var product_id := str(pack.get("product_id", ""))
	var add_amt := int(pack.get("diamonds", 0))
	if _has_processed_tx(tx_id):
		purchase_completed.emit(true, product_id, 0, "Bu işlem zaten hesaba işlendi.")
		_invoke_purchase_callback(callback, true, product_id, 0, "Bu işlem zaten hesaba işlendi.")
		return

	var gs := _game_state()
	if gs != null:
		_ensure_player_wallet(gs)
		var p := gs.get("player") as Dictionary
		p["diamonds"] = maxi(0, int(p.get("diamonds", STARTER_DIAMONDS))) + add_amt
	_mark_processed_tx(tx_id)
	_emit_wallet_and_state(true)
	purchase_completed.emit(true, product_id, add_amt, message)
	_invoke_purchase_callback(callback, true, product_id, add_amt, message)


func _verify_and_credit_iap(pack: Dictionary, tx_id: String, receipt: String, platform_name: String, callback: Callable) -> void:
	var product_id := str(pack.get("product_id", ""))
	var pack_id := str(pack.get("id", ""))
	var add_amt := int(pack.get("diamonds", 0))
	if _has_processed_tx(tx_id):
		purchase_completed.emit(true, product_id, 0, "Bu işlem zaten hesaba işlendi.")
		_invoke_purchase_callback(callback, true, product_id, 0, "Bu işlem zaten hesaba işlendi.")
		return

	var net := _autoload("NetworkManager")
	if net == null or str(net.get("auth_token")).is_empty() or not net.has_method("api_request"):
		_credit_iap_locally(pack, tx_id, "+%d 💎 Elmas hesabınıza eklendi!" % add_amt, callback)
		return

	net.api_request("/api/store/verify_iap", HTTPClient.METHOD_POST, {
		"product_id": product_id,
		"pack_id": pack_id,
		"transaction_id": tx_id,
		"platform": platform_name,
		"receipt_data": receipt,
	}, func(success: bool, res_json: Dictionary):
		if success and bool(res_json.get("ok", false)):
			var server_diamonds := int(res_json.get("diamonds", -1))
			var added := int(res_json.get("added", add_amt))
			var gs := _game_state()
			if gs != null and server_diamonds >= 0:
				_ensure_player_wallet(gs)
				var p := gs.get("player") as Dictionary
				p["diamonds"] = server_diamonds
				if typeof(res_json.get("scrolls")) == TYPE_DICTIONARY:
					p["scrolls"] = (res_json.get("scrolls") as Dictionary).duplicate(true)
			elif not _has_processed_tx(tx_id) and gs != null:
				_ensure_player_wallet(gs)
				var p2 := gs.get("player") as Dictionary
				p2["diamonds"] = maxi(0, int(p2.get("diamonds", STARTER_DIAMONDS))) + added
			_mark_processed_tx(tx_id)
			_emit_wallet_and_state(true)
			var ok_msg := "+%d 💎 Elmas hesabınıza eklendi!" % added if added > 0 else "Satın alma doğrulandı."
			purchase_completed.emit(true, product_id, added, ok_msg)
			_invoke_purchase_callback(callback, true, product_id, added, ok_msg)
		else:
			# Ağ / sunucu geçici hatasında yerel olarak ekle (idempotent tx_id ile)
			_credit_iap_locally(pack, tx_id, "+%d 💎 Elmas eklendi (çevrimdışı doğrulama)." % add_amt, callback)
	)


func _invoke_purchase_callback(callback: Callable, ok: bool, product_id: String, diamonds_added: int, message: String) -> void:
	if not callback.is_valid():
		return
	var argc := callback.get_argument_count()
	match argc:
		0:
			callback.call()
		1:
			callback.call(ok)
		2:
			callback.call(ok, message)
		3:
			callback.call(ok, diamonds_added, message)
		_:
			callback.call(ok, product_id, diamonds_added, message)


func open_market(parent_node: Node, initial_tab: String = "build") -> Node:
	var host := _scene_root(parent_node)
	if host != null and host.has_node("RoyalMarketModal"):
		var existing := host.get_node("RoyalMarketModal")
		if existing.has_method("open_tab"):
			existing.call("open_tab", initial_tab)
		elif existing.has_method("select_tab"):
			existing.call("select_tab", initial_tab)
		elif existing.has_method("set_tab"):
			existing.call("set_tab", initial_tab)
		return existing

	if not ResourceLoader.exists("res://ui/MarketModal.gd"):
		push_warning("StoreManager: res://ui/MarketModal.gd bulunamadı.")
		return null
	var script := load("res://ui/MarketModal.gd")
	if script == null:
		return null
	var modal: Node = script.new()
	if modal == null:
		return null
	if host != null:
		host.add_child(modal)
	elif parent_node != null:
		parent_node.add_child(modal)
	if modal.has_method("open_tab"):
		modal.call("open_tab", initial_tab)
	elif modal.has_method("select_tab"):
		modal.call("select_tab", initial_tab)
	elif modal.has_method("configure"):
		modal.call("configure", initial_tab)
	elif modal.has_method("setup"):
		modal.call("setup", initial_tab)
	return modal


func open_speedup_modal(parent_node: Node, category: String, target_id: Variant = null, title_text: String = "") -> Node:
	var host := _scene_root(parent_node)
	if host != null and host.has_node("SpeedupModal"):
		var prev := host.get_node("SpeedupModal")
		if is_instance_valid(prev):
			prev.queue_free()

	if not ResourceLoader.exists("res://ui/SpeedupModal.gd"):
		push_warning("StoreManager: res://ui/SpeedupModal.gd bulunamadı.")
		return null
	var script := load("res://ui/SpeedupModal.gd")
	if script == null:
		return null
	var modal: Node = script.new()
	if modal == null:
		return null
	if host != null:
		host.add_child(modal)
	elif parent_node != null:
		parent_node.add_child(modal)
	if modal.has_method("configure"):
		modal.call("configure", category, target_id, title_text)
	elif modal.has_method("setup"):
		modal.call("setup", category, target_id, title_text)
	return modal
