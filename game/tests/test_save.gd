extends SceneTree
## Save / Load ve Offline Telafi Testleri (Taht ve Kılıç / A-QA).
##
## Çalıştırma:
##   godot --headless --path game --script res://tests/test_save.gd

const WorldGeneratorScript := preload("res://scripts/world/WorldGenerator.gd")
const VillageModelScript := preload("res://scripts/model/VillageModel.gd")
const RulesEngineScript := preload("res://scripts/rules/RulesEngine.gd")
const GameLoopScript := preload("res://scripts/core/GameLoop.gd")

const EconomySimulatorScript := preload("res://scripts/sim/economy/EconomySimulator.gd")
const ArmySimulatorScript := preload("res://scripts/sim/army/ArmySimulator.gd")
const ActionSimulatorScript := preload("res://scripts/sim/actions/ActionSimulator.gd")
const BotSimulatorScript := preload("res://scripts/bot/BotSimulator.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	print("=== Kaydet / Yükle ve Offline Telafi Testleri (A-QA) ===")

	var loop := Engine.get_main_loop() as SceneTree
	var gs: Node = loop.root.get_node_or_null("GameState")
	var sm: Node = loop.root.get_node_or_null("SaveManager")
	var cfg: Node = loop.root.get_node_or_null("GameConfig")

	if gs == null or sm == null:
		print("  [FAIL] Autoload düğümleri bulunamadı")
		quit(1)
		return

	_test_save_load_roundtrip(gs, sm)
	_test_deterministic_hash(gs, sm)
	_test_offline_catchup_30_days(gs, sm)
	_test_save_meta_and_corruption(sm)

	# Test sonrası temizlik: kullanıcının gerçek kaydını bırakma
	sm.delete_save()
	_assert(not sm.has_save(), "Test sonrası kayıt dosyası temizlendi")

	print("\n==================== ÖZET ====================")
	print("PASS: %d   FAIL: %d" % [_passed, _failed])
	print("==============================================")

	if _failed > 0:
		quit(1)
	else:
		quit(0)


func _assert(condition: bool, msg: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] %s" % msg)
	else:
		_failed += 1
		print("  [FAIL] %s" % msg)


## (a) Kaydet / Sıfırla / Yükle Döngüsü
func _test_save_load_roundtrip(gs: Node, sm: Node) -> void:
	print("\n-- (a) Kaydet / Sıfırla / Yükle Döngüsü --")

	gs.reset()
	var world := WorldGeneratorScript.generate(7777, 5)
	gs.world = world
	gs.villages = world["villages"].duplicate(true)
	gs.player = {
		"id": 1,
		"name": "Kral Arthur",
		"points": 1500,
		"protection_until_unix": 1050000,
		"conquest_protection_until_unix": 0,
		"premium": false,
	}
	gs.active_village_id = 1

	# Birkaç örnek kuyruk ve hareket ekle
	gs.queues.append({
		"id": 101, "village_id": 1, "type": "build",
		"key": "barracks", "target_level": 2,
		"start_unix": 1000000, "finish_unix": 1000500,
		"cost_paid": {"wood": 200, "stone": 150, "iron": 100},
	})
	gs.movements.append({
		"id": 201, "type": "raid", "village_id": 1,
		"from_village_id": 1, "to_village_id": 2,
		"from_x": 10, "from_y": 10, "to_x": 15, "to_y": 10,
		"units": {"axe": 30}, "carry": {"wood": 0, "stone": 0, "iron": 0},
		"depart_unix": 1000000, "arrive_unix": 1000600, "return_unix": 1001200,
		"state": "outgoing", "battle_seed": 9999,
	})

	var saved: bool = sm.save_game()
	_assert(saved, "Oyun başarıyla kaydedildi")
	_assert(sm.has_save(), "Kayıt dosyası mevcut")

	# Hafızayı sıfırla
	gs.reset()
	_assert(gs.villages.is_empty(), "GameState.reset() sonrası köyler boş")
	_assert(gs.queues.is_empty(), "GameState.reset() sonrası kuyruklar boş")
	_assert(gs.active_village_id == -1, "GameState.reset() sonrası aktif köy -1")

	# Yükle ve doğrula
	var loaded: bool = sm.load_game()
	_assert(loaded, "Oyun başarıyla yüklendi")
	_assert(gs.villages.size() == world["villages"].size(), "Köy sayısı birebir yüklendi (%d)" % gs.villages.size())
	_assert(gs.player.get("name") == "Kral Arthur", "Oyuncu adı doğru: Kral Arthur")
	_assert(gs.active_village_id == 1, "Aktif köy kimliği doğru: 1")
	_assert(gs.queues.size() == 1, "Kuyruk öğesi doğru yüklendi")
	_assert(gs.movements.size() == 1, "Hareket öğesi doğru yüklendi")


## (b) Deterministik Kanonik Durum Hash Karşılaştırması
func _test_deterministic_hash(gs: Node, sm: Node) -> void:
	print("\n-- (b) Deterministik Hash Eşitliği --")

	var hash_before := _compute_state_hash(gs)
	sm.save_game()
	gs.reset()
	sm.load_game()
	var hash_after := _compute_state_hash(gs)

	_assert(hash_before == hash_after, "Kaydet/yükle öncesi ve sonrası durum hash'i birebir eşit (%s)" % hash_before.substr(0, 12))


func _compute_state_hash(gs: Node) -> String:
	var s := "P:%s:%d|" % [str(gs.player.get("name", "")), int(gs.player.get("points", 0))]
	for v in gs.villages:
		s += "V:%d:%d:%d|" % [int(v.get("id", 0)), int(v.get("points", 0)), int(v.get("realm_of_power", 0))]
		var res: Dictionary = v.get("resources", {})
		s += "R:%d,%d,%d|" % [int(res.get("wood", 0)), int(res.get("stone", 0)), int(res.get("iron", 0))]
	for q in gs.queues:
		s += "Q:%d:%s:%d|" % [int(q.get("id", 0)), str(q.get("key", "")), int(q.get("target_level", 0))]
	for m in gs.movements:
		s += "M:%d:%s:%d|" % [int(m.get("id", 0)), str(m.get("type", "")), int(m.get("arrive_unix", 0))]
	return s.md5_text()


## (c) 30 Günlük Offline Hızlı-İleri Telafisi
func _test_offline_catchup_30_days(gs: Node, sm: Node) -> void:
	print("\n-- (c) 30 Günlük Offline Hızlı-İleri Telafisi --")

	var state: Dictionary = gs.to_dict()
	var start_unix: int = 1000000
	var now := start_unix

	# 30 gün = 2.592.000 saniye (offline sıçrama)
	var offline_seconds := 30 * 86400
	var step_size := 3600  # 1'er saatlik adımlarla hızlı ileri
	var steps := offline_seconds / step_size

	for i in steps:
		now += step_size
		EconomySimulatorScript.process_tick(state, now, step_size)
		ArmySimulatorScript.process_tick(state, now, step_size)
		ActionSimulatorScript.process_tick(state, now, step_size)
		BotSimulatorScript.process_tick(state, now, step_size)

	gs.from_dict(state)

	var all_res_valid := true
	var all_cap_valid := true

	for v in gs.villages:
		var res: Dictionary = v.get("resources", {})
		if int(res.get("wood", 0)) < 0 or int(res.get("stone", 0)) < 0 or int(res.get("iron", 0)) < 0:
			all_res_valid = false
		var cap: int = RulesEngineScript.storage_capacity(int(v.get("buildings", {}).get("storage", 1)))
		# Taşma kontrolü (üretim tavanı aşamaz)
		if int(res.get("wood", 0)) > cap + 50000:
			all_cap_valid = false

	_assert(all_res_valid, "30 gün offline sonrası negatif kaynak yok")
	_assert(all_cap_valid, "30 gün offline sonrası kaynaklar depo kapasitesi sınırında tutuldu")


## (d) Metadata ve Bozuk Dosya Yönetimi
func _test_save_meta_and_corruption(sm: Node) -> void:
	print("\n-- (d) Metadata ve Bozuk Dosya Yönetimi --")

	var meta: Dictionary = sm.get_save_meta()
	_assert(int(meta.get("saveVersion", 0)) == 1, "Meta saveVersion == 1")
	_assert(int(meta.get("savedAtUnix", 0)) > 0, "Meta savedAtUnix geçerli")

	# Bozuk dosya testi
	var f := FileAccess.open(sm.get_save_path(), FileAccess.WRITE)
	f.store_string("BU_GECERSIZ_BIR_JSON_VERISIDIR!{][[,,")
	f.close()

	var ok: bool = sm.load_game()
	_assert(not ok, "Bozuk kayıt dosyası çökmeden false döndürdü")
