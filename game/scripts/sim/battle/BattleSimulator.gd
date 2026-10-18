class_name BattleSimulator
extends RefCounted
## 5 fazlı savaş simülatörü (Taht ve Kılıç).
##
## **Saf fonksiyon** — girdi → sonuç. `GameState`'e dokunmaz, hiçbir dış durumu
## değiştirmez; yalnızca `simulate()` çağrıldığında `res://data/**` altındaki
## kural/veri dosyalarını (bir kez, önbelleğe) okur. Böylece test edilebilir ve
## deterministiktir (bkz. docs/19-MOTOR-API-SOZLESMESI.md §7 ve §2).
##
## Faz sırası (docs/06-SAVAS-SISTEMI.md §1, game/data/rules/battle.json#phases):
##   1) Sura zarar verilmesi      (Şahmerdan / ram)
##   2) Casus Saldırısı           (Casus / spy)
##   3) Normal Asker Saldırısı    (moral + şans + sur + gece)
##   4) Binalara zarar            (Mancınık / kata)
##   5) Fetihler ve Yağma         (Kont / snob + taşıma kapasitesi)
##
## Bilinmeyen formüller (battle.json `known:false`) uydurulmaz; tek bir sabit/formül
## seçilir ve `ASSUMPTIONS.md` içinde gerekçesiyle belgelenir.

# --- Veri yolları -----------------------------------------------------------
const RULES_UNITS := "res://data/rules/units.json"
const RULES_BATTLE := "res://data/rules/battle.json"
const RULES_PRODUCTION := "res://data/rules/production.json"
const DATA_UNITS := "res://data/units.json"

# --- Bilinmeyen formüller için SEÇİLEN sabitler (bkz. ASSUMPTIONS.md) --------
## Faz 1 — Şahmerdan sur hasarı: hasar% = 100 × ram / (ram + sur_sv × K).
## K büyüdükçe daha kalın sur daha az hasar alır; sur 0 → %100.
const RAM_WALL_DAMAGE_FACTOR := 2.0
## Faz 4 — her hayatta kalan Mancınık, (savunan kayıp oranı) kadar bina seviyesi yıkar.
const KATA_LEVELS_PER_KATA := 1.0
## Moral eğrisi: her 1 puan-oranı birimi için moral düşüşü (0.1 → oran 8'de taban %30).
const MORALE_CURVE_SLOPE := 0.1

# --- Varsayılan (dosya okunamazsa kullanılacak) sabitler ---------------------
const DEFAULT_WALL_PERCENT := [
	100.0, 105.0, 109.0, 114.0, 118.0, 123.0, 128.0, 133.0, 138.0, 143.0,
	149.0, 155.0, 161.0, 168.0, 174.0, 181.0, 188.0, 196.0, 204.0, 212.0, 220.0,
]
const DEFAULT_HIDEOUT_VALUES := [
	150, 179, 212, 253, 301, 358, 426, 507, 603, 718,
	854, 1017, 1210, 1439, 1713, 2038, 2426, 2887, 3435, 4088,
	4864, 5789, 6888, 8197, 9755, 11608, 13814, 16438, 19562, 23278,
]

# --- Önbellek ---------------------------------------------------------------
static var _loaded := false
static var _units: Dictionary = {}          # key -> {"attack","def_inf","def_cav","def_arch","carry","class"}
static var _names: Dictionary = {}          # key -> Türkçe ad
static var _wall_percent: Array = []        # [0..20] savunma takviyesi yüzdesi
static var _hideout_values: Array = []      # [0..29] Gizli Depo kapasitesi (sv=index+1)

# --- Yüklenen/config'e bağlı eşikler ---------------------------------------
static var _morale_min: float = 0.3
static var _morale_max: float = 1.0
static var _luck_min: float = -0.25
static var _luck_max: float = 0.25
static var _night_multiplier: float = 2.0
static var _memorial_bonus: float = 0.5
static var _barracks_factor: int = 3
static var _count_death_ratio: float = 0.5
static var _realm_loss_normal: Array = [2250, 2750]
static var _realm_loss_memorial: Array = [1750, 2250]
static var _realm_max_points: int = 10000
static var _post_conquest_percent: int = 30

const UNIT_KEYS := [
	"farmer", "spear", "sword", "axe", "bow", "spy",
	"light", "heavy", "ram", "kata", "snob",
]


# ============================================================================
#  GİRİŞ NOKTASI
# ============================================================================

## Muharebeyi 5 fazda çözer.
##
## attacker/defender: {"units":{...}, "wall_level":int, "buildings":{...},
##                     "bonus":{...}, "has_statue":bool, "points":int}
## options: {"seed":int, "night":bool, "speed":float, "raider_points":int, "is_raid":bool}
## Dönüş: {"phases":[...], "attacker_losses":{...}, "defender_losses":{...},
##         "wall_damage_pct":float, "loot":{...}, "conquered":bool,
##         "morale":float, "luck":float, ... (ek alanlar)}
static func simulate(attacker: Dictionary, defender: Dictionary, options: Dictionary = {}) -> Dictionary:
	_ensure_data()

	# --- Determinizm: tohum YALNIZCA options.seed'den gelir (global randi() YASAK).
	var rng := RandomNumberGenerator.new()
	rng.seed = int(options.get("seed", 0))

	var is_raid := bool(options.get("is_raid", false))
	var night_active := bool(options.get("night", false))
	var night_mult := float(options.get("night_multiplier", _night_multiplier))

	# --- Girdiler (girdiler ASLA değiştirilmez; kopyalar üzerinde çalışılır).
	var atk_units := _normalize_units(attacker.get("units", {}))
	var def_units := _normalize_units(defender.get("units", {}))
	var def_buildings: Dictionary = _as_dict(defender.get("buildings", {}))
	var def_resources := _normalize_resources(defender.get("resources", {}))
	var def_has_statue := _has_statue(defender)
	var atk_points := int(attacker.get("points", 0))
	var raider_points := int(options.get("raider_points", 0))
	if raider_points > 0:
		atk_points = raider_points
	var def_points := int(defender.get("points", 0))

	# --- Min. saldırı birimi kontrolü: 3 × Kışla seviyesi (battle.json#min_attack_units).
	var barracks_level := _barracks_level(attacker)
	var min_units: int = _barracks_factor * maxi(0, barracks_level)
	var total_attacker_units := _sum_counts(atk_units)
	var min_attack_ok := total_attacker_units >= min_units

	# ========================================================================
	#  FAZ 1 — Sura zarar verilmesi (Şahmerdan)
	# ========================================================================
	var ram_count := int(atk_units.get("ram", 0))
	var wall_level := _wall_level(defender)
	var wall_damage_pct := 0.0
	if ram_count > 0:
		wall_damage_pct = _ram_wall_damage_pct(ram_count, wall_level)
	var effective_wall := _round_half_up(float(wall_level) * (1.0 - wall_damage_pct / 100.0))
	effective_wall = clampi(effective_wall, 0, 20)

	# ========================================================================
	#  FAZ 2 — Casus Saldırısı (Casus)
	# ========================================================================
	var spy_count := int(atk_units.get("spy", 0))
	var def_spy := int(def_units.get("spy", 0))
	var spy_survivors := 0
	if spy_count > 0:
		spy_survivors = _spy_survivors(spy_count, def_spy)
	var spy_losses := spy_count - spy_survivors

	# ========================================================================
	#  FAZ 3 — Normal Asker Saldırısı
	# ========================================================================
	# Casuslar faz 2'de işini yapıp ayrılır; normal asker savaşına katılmazlar.
	var attack_pool := _without_key(atk_units, "spy")
	var class_attack := _class_attack_totals(attack_pool)
	var attack_raw := 0.0
	for bucket in class_attack.keys():
		attack_raw += float(class_attack[bucket])

	var morale := _morale(atk_points, def_points)
	var luck := rng.randf_range(_luck_min, _luck_max)
	var attack_value := attack_raw * morale * (1.0 + luck)

	var wall_bonus := _wall_bonus_factor(effective_wall)
	var memorial_bonus := 1.0 + _memorial_bonus if def_has_statue else 1.0
	var night_bonus := night_mult if night_active else 1.0
	var defence_mult := wall_bonus * memorial_bonus * night_bonus

	var defence_raw := _defence_raw(def_units, class_attack, attack_raw)
	var defence_value := defence_raw * defence_mult

	var total_power := attack_value + defence_value
	var attacker_loss_frac := 0.0
	var defender_loss_frac := 0.0
	if total_power > 0.0:
		attacker_loss_frac = defence_value / total_power
		defender_loss_frac = attack_value / total_power
	var attacker_won := attack_value > defence_value

	# --- Kayıplar (int; oran bazlı)
	var attacker_losses := _distribute_losses(atk_units, attacker_loss_frac)
	if spy_losses > 0:
		attacker_losses["spy"] = int(attacker_losses.get("spy", 0)) + spy_losses
	# Sadece > 0 olanlar raporda tutulur.
	attacker_losses = _positive_only(attacker_losses)
	var defender_losses := _positive_only(_distribute_losses(def_units, defender_loss_frac))

	var attacker_alive := _subtract(atk_units, attacker_losses)
	var defender_alive := _subtract(def_units, defender_losses)

	# ========================================================================
	#  FAZ 4 — Binalara zarar (Mancınık)
	# ========================================================================
	var kata_alive := int(attacker_alive.get("kata", 0))
	var damage_data := {"levels_destroyed": 0, "damaged": [], "buildings_after": {}}
	if attacker_won and kata_alive > 0 and not def_buildings.is_empty():
		var levels_to_destroy := _round_half_up(float(kata_alive) * KATA_LEVELS_PER_KATA * defender_loss_frac)
		damage_data = _apply_building_damage(def_buildings, levels_to_destroy)

	# ========================================================================
	#  FAZ 5 — Fetihler ve Yağma
	# ========================================================================
	var hideout_capacity := _hideout_capacity(defender, def_buildings)
	var carry_capacity := _carry_capacity(attacker_alive)
	var loot := {"wood": 0, "stone": 0, "iron": 0}
	if attacker_won:
		loot = _compute_loot(carry_capacity, def_resources, hideout_capacity)

	# --- Kont / fetih
	var snob_count := int(atk_units.get("snob", 0))
	var snob_alive := int(attacker_alive.get("snob", 0))
	var total_lost := _sum_counts(attacker_losses)
	var loss_ratio := 0.0
	if total_attacker_units > 0:
		loss_ratio = float(total_lost) / float(total_attacker_units)
	var others_alive := _sum_counts(_without_key(attacker_alive, "snob"))
	var battle_occured := total_attacker_units > 0 and _sum_counts(def_units) > 0
	var count_dies := loss_ratio >= _count_death_ratio
	if battle_occured and others_alive <= 0:
		count_dies = true
	var count_survived := snob_alive > 0 and not count_dies

	var realm_loss := 0
	var realm_after := -1
	var conquered := false
	if attacker_won and count_survived and not is_raid:
		var loss_range: Array = _realm_loss_memorial if def_has_statue else _realm_loss_normal
		var lo := int(loss_range[0])
		var hi: int = maxi(lo, int(loss_range[1]))
		realm_loss = rng.randi_range(lo, hi)
		realm_loss = mini(realm_loss, int(_realm_max_points / 2))  # cap: maks/2
		var current := int(defender.get("realm_of_power", -1))
		if current >= 0:
			realm_after = maxi(0, current - realm_loss)
			if realm_after <= 0:
				conquered = true
				var max_pts: int = mini(maxi(0, def_points), _realm_max_points)
				realm_after = _round_half_up(float(max_pts) * float(_post_conquest_percent) / 100.0)

	# ========================================================================
	#  Faz kayıtları
	# ========================================================================
	var phases: Array = []
	phases.append({
		"order": 1, "key": "wall_damage", "name_tr": "Sura zarar verilmesi",
		"did_occur": ram_count > 0,
		"data": {
			"rams": ram_count,
			"wall_level_before": wall_level,
			"wall_level_after": effective_wall,
			"wall_damage_pct": wall_damage_pct,
		},
	})
	phases.append({
		"order": 2, "key": "spy_attack", "name_tr": "Casus Saldırısı",
		"did_occur": spy_count > 0,
		"data": {
			"attack_spies": spy_count,
			"defence_spies": def_spy,
			"spy_survivors": spy_survivors,
			"spy_losses": spy_losses,
		},
	})
	phases.append({
		"order": 3, "key": "normal_battle", "name_tr": "Normal Asker Saldırısı",
		"did_occur": total_power > 0.0,
		"data": {
			"attack_raw": attack_raw,
			"attack_value": attack_value,
			"defence_raw": defence_raw,
			"defence_value": defence_value,
			"morale": morale,
			"luck": luck,
			"wall_bonus": wall_bonus,
			"memorial_bonus": memorial_bonus,
			"night_bonus": night_bonus,
			"attacker_won": attacker_won,
		},
	})
	phases.append({
		"order": 4, "key": "building_damage", "name_tr": "Binalara zarar",
		"did_occur": kata_alive > 0 and attacker_won,
		"data": {
			"katas_alive": kata_alive,
			"levels_destroyed": int(damage_data.get("levels_destroyed", 0)),
			"damaged": damage_data.get("damaged", []),
		},
	})
	phases.append({
		"order": 5, "key": "conquest_and_pillage", "name_tr": "Fetihler ve Yağma",
		"did_occur": attacker_won,
		"data": {
			"loot": loot.duplicate(),
			"carry_capacity": carry_capacity,
			"hideout_capacity": hideout_capacity,
			"count_alive": snob_alive,
			"count_died": count_dies,
			"count_consumed": conquered,
			"realm_loss": realm_loss,
			"realm_of_power_after": realm_after,
			"conquered": conquered,
		},
	})

	# ========================================================================
	#  Sonuç
	# ========================================================================
	return {
		# --- sözleşme (docs/19 §7)
		"phases": phases,
		"attacker_losses": attacker_losses,
		"defender_losses": defender_losses,
		"wall_damage_pct": wall_damage_pct,
		"loot": loot,
		"conquered": conquered,
		"morale": morale,
		"luck": luck,
		# --- ek yardımcı alanlar
		"attacker_won": attacker_won,
		"attacker_alive": attacker_alive,
		"defender_alive": defender_alive,
		"wall_level_before": wall_level,
		"wall_level_after": effective_wall,
		"building_damage": damage_data.get("damaged", []),
		"buildings_after": damage_data.get("buildings_after", {}),
		"carry_capacity": carry_capacity,
		"hideout_capacity": hideout_capacity,
		"realm_loss": realm_loss,
		"realm_of_power_after": realm_after,
		"count_survived": count_survived,
		"count_died": count_dies,
		"count_had": snob_count,
		"min_attack_units": min_units,
		"min_attack_ok": min_attack_ok,
		"total_attacker_units": total_attacker_units,
		"is_raid": is_raid,
		"night": night_active,
		"seed": int(options.get("seed", 0)),
	}


# ============================================================================
#  FAZ YARDIMCILARI
# ============================================================================

## Faz 1: Şahmerdan sur hasarı yüzdesi (bkz. ASSUMPTIONS.md #1).
static func _ram_wall_damage_pct(ram_count: int, wall_level: int) -> float:
	if ram_count <= 0:
		return 0.0
	var denom := float(ram_count) + float(maxi(0, wall_level)) * RAM_WALL_DAMAGE_FACTOR
	if denom <= 0.0:
		return 0.0
	return minf(100.0, 100.0 * float(ram_count) / denom)


## Faz 2: Hayatta kalan casus sayısı (bkz. ASSUMPTIONS.md #5).
static func _spy_survivors(attack_spies: int, defence_spies: int) -> int:
	if attack_spies <= 0:
		return 0
	var total := attack_spies + maxi(0, defence_spies)
	if total <= 0:
		return attack_spies
	var ratio := float(attack_spies) / float(total)
	return clampi(_round_half_up(float(attack_spies) * ratio), 0, attack_spies)


## Faz 3: Birim sınıfına göre toplam saldırı (infantry / archer / cavalry).
static func _class_attack_totals(pool: Dictionary) -> Dictionary:
	var buckets := {"infantry": 0.0, "archer": 0.0, "cavalry": 0.0}
	var keys := pool.keys()
	keys.sort()
	for key in keys:
		var count := int(pool[key])
		if count <= 0:
			continue
		var st := _stats(str(key))
		var attack := float(st.attack) * float(count)
		buckets[_class_bucket(str(st["class"]))] += attack
	return buckets


## Faz 3: Savunanın ağırlıklı savunma değeri (saldırı kompozisyonuna göre).
static func _defence_raw(def_units: Dictionary, class_attack: Dictionary, attack_raw: float) -> float:
	if attack_raw <= 0.0:
		return 0.0
	var w_inf := float(class_attack.get("infantry", 0.0)) / attack_raw
	var w_arch := float(class_attack.get("archer", 0.0)) / attack_raw
	var w_cav := float(class_attack.get("cavalry", 0.0)) / attack_raw
	var total := 0.0
	var keys := def_units.keys()
	keys.sort()
	for key in keys:
		var count := int(def_units[key])
		if count <= 0:
			continue
		var st := _stats(str(key))
		var weighted := w_inf * float(st.def_inf) + w_cav * float(st.def_cav) + w_arch * float(st.def_arch)
		total += weighted * float(count)
	return total


## Oran bazlı kayıp dağıtımı (bkz. ASSUMPTIONS.md #4). Tüm kayıplar int.
static func _distribute_losses(units: Dictionary, loss_fraction: float) -> Dictionary:
	var losses := {}
	if loss_fraction <= 0.0:
		return losses
	var keys := units.keys()
	keys.sort()
	for key in keys:
		var count := int(units[key])
		if count <= 0:
			continue
		var lost := _round_half_up(float(count) * loss_fraction)
		lost = clampi(lost, 0, count)
		if lost > 0:
			losses[key] = lost
	return losses


# ============================================================================
#  YAĞMA
# ============================================================================

## Taşıma kapasitesi = hayatta kalan birimlerin taşıma kapasiteleri toplamı.
static func _carry_capacity(alive_units: Dictionary) -> int:
	var total := 0
	var keys := alive_units.keys()
	keys.sort()
	for key in keys:
		var count := int(alive_units[key])
		if count <= 0:
			continue
		total += int(_stats(str(key)).carry) * count
	return total


## Yağma: gizli depo kadar korunur; kalan, taşıma kapasitesine kadar alınır.
static func _compute_loot(capacity: int, resources: Dictionary, hideout_capacity: int) -> Dictionary:
	var loot := {"wood": 0, "stone": 0, "iron": 0}
	if capacity <= 0:
		return loot
	var total := int(resources.get("wood", 0)) + int(resources.get("stone", 0)) + int(resources.get("iron", 0))
	if total <= 0:
		return loot
	var protected := mini(maxi(0, hideout_capacity), total)
	var lootable := total - protected
	var take := mini(capacity, lootable)
	if take <= 0:
		return loot
	# En büyük kalan yöntemiyle hammadde tiplerine oransal dağıtım.
	var types := ["wood", "stone", "iron"]
	var remainders := {}
	var allocated := 0
	for t in types:
		var raw := float(take) * float(int(resources.get(t, 0))) / float(total)
		var base := int(floor(raw))
		base = mini(base, int(resources.get(t, 0)))
		loot[t] = base
		remainders[t] = raw - float(base)
		allocated += base
	# Kalanı büyük ondalıklıdan başlayarak dağıt (eşitlikte tip sırası korunur).
	while allocated < take:
		var best := ""
		var best_rem := -1.0
		for t in types:
			var rem := float(remainders.get(t, 0.0))
			if rem > best_rem and int(loot[t]) < int(resources.get(t, 0)):
				best_rem = rem
				best = t
		if best == "":
			break
		loot[best] = int(loot[best]) + 1
		remainders[best] = -1.0
		allocated += 1
	return loot


# ============================================================================
#  BİNA HASARI (FAZ 4)
# ============================================================================

## Savunanın binalarından (sur hariç) `levels` kadar seviye yıkar.
## Deterministik sıra: en yüksek seviyeli bina önce; eşitlikte anahtar adı (A→Z).
static func _apply_building_damage(buildings: Dictionary, levels: int) -> Dictionary:
	var after := buildings.duplicate(true)
	var levels_destroyed := 0
	var remaining := maxi(0, levels)
	var guard := 0
	while remaining > 0 and guard < 100000:
		guard += 1
		var best_key := ""
		var best_level := 0
		var keys := after.keys()
		keys.sort()
		for key in keys:
			if str(key) == "wall":
				continue  # Sur, Faz 1'de ele alınır.
			var lvl := int(after[key])
			if lvl > best_level:
				best_level = lvl
				best_key = str(key)
		if best_key.is_empty() or best_level <= 0:
			break
		after[best_key] = best_level - 1
		remaining -= 1
		levels_destroyed += 1
	var damaged: Array = []
	var orig_keys := buildings.keys()
	orig_keys.sort()
	for key in orig_keys:
		var before := int(buildings[key])
		var now := int(after.get(key, before))
		if now != before:
			damaged.append({"key": str(key), "from": before, "to": now})
	return {"levels_destroyed": levels_destroyed, "damaged": damaged, "buildings_after": after}


# ============================================================================
#  MORAL / BONUSLAR
# ============================================================================

## Moral: saldıran puanı savunandan yüksekse düşer; %30–%100 aralığında kalır.
## Seçilen tek eğri: morale = clamp(1 - 0.1 × (oran - 1), 0.3, 1.0). (ASSUMPTIONS.md #3)
static func morale_for(attacker_points: int, defender_points: int) -> float:
	return _morale(attacker_points, defender_points)


static func _morale(attacker_points: int, defender_points: int) -> float:
	if attacker_points <= 0 or defender_points <= 0:
		return _morale_max
	if attacker_points <= defender_points:
		return _morale_max
	var ratio := float(attacker_points) / float(defender_points)
	var m := _morale_max - MORALE_CURVE_SLOPE * (ratio - 1.0)
	return clampf(m, _morale_min, _morale_max)


## Sur bonusu çarpanı (ör. sur 20 → 2.20). production.json tablosu esas alınır.
static func wall_bonus_factor(wall_level: int) -> float:
	_ensure_data()
	return _wall_bonus_factor(wall_level)


static func _wall_bonus_factor(wall_level: int) -> float:
	if _wall_percent.is_empty():
		return 1.0
	var lvl := clampi(wall_level, 0, _wall_percent.size() - 1)
	return float(_wall_percent[lvl]) / 100.0


## Verilen Kışla seviyesi için gereken en az saldırı birimi (3 × Kışla).
static func min_attack_units_for(barracks_level: int) -> int:
	_ensure_data()
	return _barracks_factor * maxi(0, barracks_level)


## Gizli Depo kapasitesi: önce açık `hideout_capacity`, sonra `buildings.hide`
## seviyesinden production.json tablosu, en son doküman eğrisi.
static func hideout_capacity_for(defender: Dictionary) -> int:
	_ensure_data()
	return _hideout_capacity(defender, _as_dict(defender.get("buildings", {})))


static func _hideout_capacity(defender: Dictionary, buildings: Dictionary) -> int:
	if defender.has("hideout_capacity"):
		return maxi(0, int(defender["hideout_capacity"]))
	var level := maxi(0, int(buildings.get("hide", 0)))
	if level <= 0:
		return 0
	if not _hideout_values.is_empty():
		var idx := clampi(level - 1, 0, _hideout_values.size() - 1)
		return int(_hideout_values[idx])
	return _round_half_up(150.0 * pow(1.19, float(level - 1)))


# ============================================================================
#  GİRDİ YARDIMCILARI
# ============================================================================

static func _normalize_units(raw) -> Dictionary:
	var out := {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	var keys := (raw as Dictionary).keys()
	keys.sort()
	for key in keys:
		var count := int(raw[key])
		if count > 0:
			out[str(key)] = count
	return out


static func _normalize_resources(raw) -> Dictionary:
	var out := {"wood": 0, "stone": 0, "iron": 0}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	for key in ["wood", "stone", "iron"]:
		out[key] = maxi(0, int((raw as Dictionary).get(key, 0)))
	return out


static func _wall_level(defender: Dictionary) -> int:
	if defender.has("wall_level"):
		return maxi(0, int(defender["wall_level"]))
	var buildings := _as_dict(defender.get("buildings", {}))
	return maxi(0, int(buildings.get("wall", 0)))


static func _barracks_level(attacker: Dictionary) -> int:
	if attacker.has("barracks_level"):
		return maxi(0, int(attacker["barracks_level"]))
	var buildings := _as_dict(attacker.get("buildings", {}))
	return maxi(0, int(buildings.get("barracks", 0)))


static func _has_statue(defender: Dictionary) -> bool:
	if bool(defender.get("has_statue", false)):
		return true
	var buildings := _as_dict(defender.get("buildings", {}))
	return int(buildings.get("statue", 0)) >= 1


static func _as_dict(value) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return value
	return {}


static func _without_key(units: Dictionary, key: String) -> Dictionary:
	var out := {}
	var keys := units.keys()
	keys.sort()
	for k in keys:
		if str(k) == key:
			continue
		out[k] = units[k]
	return out


static func _subtract(total: Dictionary, losses: Dictionary) -> Dictionary:
	var out := {}
	var keys := total.keys()
	keys.sort()
	for key in keys:
		var remaining := int(total[key]) - int(losses.get(key, 0))
		if remaining > 0:
			out[key] = remaining
	return out


static func _positive_only(d: Dictionary) -> Dictionary:
	var out := {}
	var keys := d.keys()
	keys.sort()
	for key in keys:
		var value := int(d[key])
		if value > 0:
			out[key] = value
	return out


static func _sum_counts(d: Dictionary) -> int:
	var total := 0
	for key in d.keys():
		total += int(d[key])
	return total


static func _class_bucket(unit_class: String) -> String:
	match unit_class:
		"archer":
			return "archer"
		"cavalry":
			return "cavalry"
		_:
			# infantry + siege + special → piyade savunmasına karşı savaşır.
			return "infantry"


## GDScript: 0.5 yukarı yuvarlama (docs/19 §2.1).
static func _round_half_up(x: float) -> int:
	return int(floor(x + 0.5))


# ============================================================================
#  VERİ YÜKLEME
# ============================================================================

static func _ensure_data() -> void:
	if _loaded:
		return
	_loaded = true
	_install_defaults()
	_load_units_data()
	_load_rules_data()


static func _install_defaults() -> void:
	_wall_percent = DEFAULT_WALL_PERCENT.duplicate()
	_hideout_values = DEFAULT_HIDEOUT_VALUES.duplicate()
	_morale_min = 0.3
	_morale_max = 1.0
	_luck_min = -0.25
	_luck_max = 0.25
	_night_multiplier = 2.0
	_memorial_bonus = 0.5
	_barracks_factor = 3
	_count_death_ratio = 0.5
	_realm_loss_normal = [2250, 2750]
	_realm_loss_memorial = [1750, 2250]
	_realm_max_points = 10000
	_post_conquest_percent = 30
	_units = _default_unit_stats()
	_names = _default_unit_names()


static func _load_units_data() -> void:
	var rules = _read_json(RULES_UNITS)
	if typeof(rules) == TYPE_DICTIONARY:
		var list = (rules as Dictionary).get("units", [])
		if typeof(list) == TYPE_ARRAY:
			for item in list:
				if typeof(item) != TYPE_DICTIONARY:
					continue
				var key := str(item.get("key", ""))
				if key.is_empty():
					continue
				var combat := _as_dict(item.get("combat", {}))
				_units[key] = {
					"attack": int(combat.get("attack", 0)),
					"def_inf": int(combat.get("defence_infantry", 0)),
					"def_cav": int(combat.get("defence_cavalry", 0)),
					"def_arch": int(combat.get("defence_archer", 0)),
					"carry": int(item.get("carry_capacity", 0)),
					"class": str(item.get("unit_class", "infantry")),
				}
				if item.has("name_tr") and not str(item["name_tr"]).is_empty():
					_names[key] = str(item["name_tr"])
	# Eksik birimleri game/data/units.json ile tamamla.
	var base = _read_json(DATA_UNITS)
	if typeof(base) == TYPE_DICTIONARY:
		var combat_list = (base as Dictionary).get("combat", [])
		if typeof(combat_list) == TYPE_ARRAY:
			for item in combat_list:
				if typeof(item) != TYPE_DICTIONARY:
					continue
				var key := str(item.get("key", ""))
				if key.is_empty():
					continue
				var existing: Dictionary = _units.get(key, {})
				if existing.is_empty():
					_units[key] = {
						"attack": int(item.get("attack", 0)),
						"def_inf": int(item.get("defenceInf", 0)),
						"def_cav": int(item.get("defenceCav", 0)),
						"def_arch": int(item.get("defenceArch", 0)),
						"carry": int(item.get("loadCapacity", 0)),
						"class": "infantry",
					}
				if not _names.has(key) or str(_names[key]).is_empty():
					_names[key] = str(item.get("name", key))


static func _load_rules_data() -> void:
	# --- production.json: sur bonusu + gizli depo tabloları
	var prod = _read_json(RULES_PRODUCTION)
	if typeof(prod) == TYPE_DICTIONARY:
		var tables := _as_dict((prod as Dictionary).get("tables", {}))
		var wall_table := _as_dict(tables.get("wall_defence_bonus_percent", {}))
		var wall_values = wall_table.get("values_percent", [])
		if typeof(wall_values) == TYPE_ARRAY and (wall_values as Array).size() >= 21:
			var parsed: Array = []
			for value in wall_values:
				parsed.append(float(value))
			_wall_percent = parsed
		var hide_table := _as_dict(tables.get("hideout_capacity", {}))
		var hide_values = hide_table.get("values", [])
		if typeof(hide_values) == TYPE_ARRAY and (hide_values as Array).size() >= 30:
			var parsed_hide: Array = []
			for value in hide_values:
				parsed_hide.append(int(value))
			_hideout_values = parsed_hide

	# --- battle.json: sabitler
	var battle = _read_json(RULES_BATTLE)
	if typeof(battle) != TYPE_DICTIONARY:
		return
	var b: Dictionary = battle
	var morale := _as_dict(b.get("morale", {}))
	_morale_min = float(morale.get("min", _morale_min))
	_morale_max = float(morale.get("max", _morale_max))
	var luck := _as_dict(b.get("luck", {}))
	_luck_min = float(luck.get("min", _luck_min))
	_luck_max = float(luck.get("max", _luck_max))
	var night := _as_dict(b.get("night_bonus", {}))
	_night_multiplier = float(night.get("multiplier", _night_multiplier))
	var memorial := _as_dict(b.get("memorial", {}))
	_memorial_bonus = float(memorial.get("fortification_bonus", _memorial_bonus))
	var min_units := _as_dict(b.get("min_attack_units", {}))
	_barracks_factor = int(min_units.get("barracks_factor", _barracks_factor))
	var count := _as_dict(b.get("count", {}))
	var death := _as_dict(count.get("death_condition", {}))
	_count_death_ratio = float(death.get("attacker_loss_ratio_threshold", _count_death_ratio))
	var realm := _as_dict(b.get("realm_of_power", {}))
	var loss_normal := _as_dict(realm.get("loss_foreign_count", {}))
	if not loss_normal.is_empty():
		_realm_loss_normal = [int(loss_normal.get("min", 2250)), int(loss_normal.get("max", 2750))]
	var loss_memorial := _as_dict(realm.get("loss_foreign_count_memorial", {}))
	if not loss_memorial.is_empty():
		_realm_loss_memorial = [int(loss_memorial.get("min", 1750)), int(loss_memorial.get("max", 2250))]
	_realm_max_points = int(realm.get("max_village_points", _realm_max_points))
	_post_conquest_percent = int(realm.get("post_conquest_percent_of_max", _post_conquest_percent))


static func _read_json(path: String):
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return null
	return JSON.parse_string(text)


static func _stats(key: String) -> Dictionary:
	_ensure_data()
	var st: Dictionary = _units.get(key, {})
	if st.is_empty():
		return {"attack": 0, "def_inf": 0, "def_cav": 0, "def_arch": 0, "carry": 0, "class": "infantry"}
	return st


static func unit_name(key: String) -> String:
	_ensure_data()
	return str(_names.get(key, key))


# --- Varsayılan tablolar (dosyalar okunamazsa) ------------------------------

static func _default_unit_stats() -> Dictionary:
	return {
		"farmer": {"attack": 20, "def_inf": 40, "def_cav": 30, "def_arch": 5, "carry": 5, "class": "infantry"},
		"spear": {"attack": 50, "def_inf": 100, "def_cav": 200, "def_arch": 300, "carry": 25, "class": "infantry"},
		"sword": {"attack": 100, "def_inf": 300, "def_cav": 100, "def_arch": 200, "carry": 15, "class": "infantry"},
		"axe": {"attack": 350, "def_inf": 70, "def_cav": 50, "def_arch": 50, "carry": 10, "class": "infantry"},
		"bow": {"attack": 150, "def_inf": 400, "def_cav": 150, "def_arch": 100, "carry": 10, "class": "archer"},
		"spy": {"attack": 1, "def_inf": 10, "def_cav": 5, "def_arch": 7, "carry": 0, "class": "special"},
		"light": {"attack": 900, "def_inf": 200, "def_cav": 300, "def_arch": 300, "carry": 80, "class": "cavalry"},
		"heavy": {"attack": 600, "def_inf": 1500, "def_cav": 1000, "def_arch": 1000, "carry": 50, "class": "cavalry"},
		"ram": {"attack": 100, "def_inf": 100, "def_cav": 200, "def_arch": 20, "carry": 0, "class": "siege"},
		"kata": {"attack": 500, "def_inf": 400, "def_cav": 100, "def_arch": 200, "carry": 0, "class": "siege"},
		"snob": {"attack": 100, "def_inf": 300, "def_cav": 100, "def_arch": 200, "carry": 0, "class": "special"},
	}


static func _default_unit_names() -> Dictionary:
	return {
		"farmer": "Köy Koruyucusu", "spear": "Silahtar", "sword": "Muhafız",
		"axe": "Baltacı", "bow": "Okçu", "spy": "Casus", "light": "Akıncı",
		"heavy": "Kara Şövalye", "ram": "Şahmerdan", "kata": "Mancınık",
		"snob": "Kont",
	}
