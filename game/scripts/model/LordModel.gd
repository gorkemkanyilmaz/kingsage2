class_name LordModel
extends RefCounted
## LordModel — Lord (Kahraman) 13 ekipman slotu, stat hesaplama, +0..+8 geliştirme,
## Haydut Köyü şablonları ve ganimet düşürme kuralları.
##
## Tamamen saf (pure) yardımcı sınıftır; GameState / SaveManager ile doğrudan
## birleştirilebilir ve deterministik/izole test edilebilir.

const BASE_HP := 500
const BASE_ATTACK := 120
const BASE_DEFENSE := 100

const MAX_PLUS := 8
const MAX_ITEM_BONUS_PCT := 50.0
const MAX_TOTAL_ARMY_BONUS_PCT := 35.0

const INJURY_MIN_SECONDS := 1800   # 30 dakika
const INJURY_MAX_SECONDS := 3600   # 60 dakika

const SCROLL_DIAMOND_COST := 5
const SCROLL_RESOURCE_COST := {
	"wood": 5000,
	"stone": 5000,
	"iron": 5000,
}

## +0->+1 .. +7->+8 başarı oranları (%)
const UPGRADE_RATES := {
	0: 100,
	1: 100,
	2: 100,
	3: 80,
	4: 60,
	5: 40,
	6: 20,
	7: 10,
}

## 13 ekipman slotu — Knight Online yerleşim düzeniyle birebir uyumlu.
const SLOTS: Array[Dictionary] = [
	{"key": "earring_1", "slot_type": "earring", "name": "Küpe 1", "short": "Küpe", "side": "left", "order": 0},
	{"key": "necklace", "slot_type": "necklace", "name": "Kolye", "short": "Kolye", "side": "left", "order": 1},
	{"key": "helmet", "slot_type": "helmet", "name": "Kask", "short": "Kask", "side": "left", "order": 2},
	{"key": "chest", "slot_type": "chest", "name": "Göğüslük", "short": "Göğüs", "side": "left", "order": 3},
	{"key": "pants", "slot_type": "pants", "name": "Pantolon", "short": "Pant.", "side": "left", "order": 4},
	{"key": "gloves", "slot_type": "gloves", "name": "Eldiven", "short": "Eldiv.", "side": "left", "order": 5},
	{"key": "boots", "slot_type": "boots", "name": "Ayakkabı", "short": "Çizme", "side": "left", "order": 6},
	{"key": "earring_2", "slot_type": "earring", "name": "Küpe 2", "short": "Küpe", "side": "right", "order": 0},
	{"key": "ring_1", "slot_type": "ring", "name": "Yüzük 1", "short": "Yüzük", "side": "right", "order": 1},
	{"key": "ring_2", "slot_type": "ring", "name": "Yüzük 2", "short": "Yüzük", "side": "right", "order": 2},
	{"key": "belt", "slot_type": "belt", "name": "Kemer", "short": "Kemer", "side": "right", "order": 3},
	{"key": "shield", "slot_type": "shield", "name": "Kalkan", "short": "Kalkan", "side": "right", "order": 4},
	{"key": "sword", "slot_type": "sword", "name": "Kılıç", "short": "Kılıç", "side": "right", "order": 5},
]

const BATTLE_DROP_SLOTS: Array[String] = [
	"helmet", "chest", "pants", "gloves", "boots", "sword", "shield",
]

const ACCESSORY_SLOTS: Array[String] = [
	"earring", "ring", "necklace", "belt",
]

const RARITY_DEFS := {
	"common": {"name": "Sıradan", "mult": 1.0, "color_hex": "#b8c0cc"},
	"uncommon": {"name": "Gelişmiş", "mult": 1.6, "color_hex": "#4cd964"},
	"rare": {"name": "Nadir", "mult": 2.5, "color_hex": "#c084fc"},
}

## Standart (+0..+8) temel yüzde eğrisi: common +1 = %2.0, rare (2.5x) +8 = %50.0.
const BASE_PLUS_PCT := [1.0, 2.0, 3.5, 5.0, 7.0, 9.5, 12.5, 16.0, 20.0]

const SLOT_WEIGHTS := {
	"sword": 1.00,
	"chest": 0.90,
	"shield": 0.85,
	"helmet": 0.70,
	"pants": 0.70,
	"gloves": 0.55,
	"boots": 0.55,
	"necklace": 0.65,
	"belt": 0.65,
	"earring": 0.50,
	"ring": 0.50,
}

const ITEM_NAMES_BY_TYPE := {
	"sword": {"common": "Çelik Kılıç", "uncommon": "Şövalye Kılıcı", "rare": "Kraliyet Kılıcı"},
	"shield": {"common": "Demir Kalkan", "uncommon": "Sancak Kalkanı", "rare": "Aslan Yeleli Kalkan"},
	"helmet": {"common": "Demir Başlık", "uncommon": "Savaşçı Miğferi", "rare": "Taht Muhafız Miğferi"},
	"chest": {"common": "Deri Göğüslük", "uncommon": "Örgü Zırh", "rare": "Kraliyet Plaka Zırhı"},
	"pants": {"common": "Demir Dizlik", "uncommon": "Çelik Bacak Zırhı", "rare": "Ejderha Pullu Pantolon"},
	"gloves": {"common": "Deri Eldiven", "uncommon": "Çelik Eldiven", "rare": "Zafer Eldiveni"},
	"boots": {"common": "Savaş Çizmesi", "uncommon": "Çelik Çizme", "rare": "Rüzgar Çizmesi"},
	"earring": {"common": "Bakır Küpe", "uncommon": "Gümüş Savaş Küpesi", "rare": "Yakut Lord Küpesi"},
	"ring": {"common": "Demir Yüzük", "uncommon": "Altın Mühür Yüzüğü", "rare": "Zümrüt Hükümdar Yüzüğü"},
	"necklace": {"common": "Bronz Kolye", "uncommon": "Gümüş Tılsım", "rare": "Safir Kraliyet Kolyesi"},
	"belt": {"common": "Deri Kemer", "uncommon": "Zırhlı Savaş Kemeri", "rare": "Altın Aslan Kemeri"},
}

const ARMY_BONUS_POOL := {
	"sword": "infantry_atk_pct",
	"helmet": "archer_atk_pct",
	"chest": "army_hp_pct",
	"pants": "cavalry_def_pct",
	"gloves": "infantry_atk_pct",
	"boots": "cavalry_def_pct",
	"shield": "cavalry_def_pct",
	"earring": "archer_atk_pct",
	"ring": "infantry_atk_pct",
	"necklace": "army_hp_pct",
	"belt": "army_hp_pct",
}

const ICON_PATHS := {
	"portrait_btn": "res://assets/sprites/lord/lord_portrait_btn.png",
	"hero_full": "res://assets/sprites/lord/lord_hero_full.png",
	"upgrade_scroll": "res://assets/sprites/lord/upgrade_scroll.png",
	"sword": "res://assets/sprites/lord/item_sword.png",
	"shield": "res://assets/sprites/lord/item_shield.png",
	"helmet": "res://assets/sprites/lord/item_helmet.png",
	"chest": "res://assets/sprites/lord/item_chest.png",
	"pants": "res://assets/sprites/lord/item_pants.png",
	"gloves": "res://assets/sprites/lord/item_gloves.png",
	"boots": "res://assets/sprites/lord/item_boots.png",
	"earring": "res://assets/sprites/lord/item_earring.png",
	"ring": "res://assets/sprites/lord/item_ring.png",
	"necklace": "res://assets/sprites/lord/item_necklace.png",
	"belt": "res://assets/sprites/lord/item_belt.png",
}


static func default_equipped_map() -> Dictionary:
	var m := {}
	for s in SLOTS:
		m[str(s["key"])] = ""
	return m


static func default_lord_state() -> Dictionary:
	return {
		"version": 1,
		"injured_until_unix": 0,
		"last_injury_duration": 0,
		"recovery_notified_until": 0,
		"equipped": default_equipped_map(),
		"inventory": [],
		"next_item_seq": 1,
		"upgrade_scrolls": 0,
		"speech_queue": [],
		"highest_bandit_cleared": 0,
		"tutorial_kit_granted": false,
		"updated_unix": 0,
	}


static func ensure_state_dict(raw) -> Dictionary:
	var d := default_lord_state()
	if typeof(raw) != TYPE_DICTIONARY:
		return d
	var src := raw as Dictionary
	d["version"] = int(src.get("version", 1))
	d["injured_until_unix"] = maxi(0, int(src.get("injured_until_unix", 0)))
	d["last_injury_duration"] = maxi(0, int(src.get("last_injury_duration", 0)))
	d["recovery_notified_until"] = maxi(0, int(src.get("recovery_notified_until", 0)))
	d["next_item_seq"] = maxi(1, int(src.get("next_item_seq", 1)))
	d["upgrade_scrolls"] = maxi(0, int(src.get("upgrade_scrolls", 0)))
	d["highest_bandit_cleared"] = maxi(0, int(src.get("highest_bandit_cleared", 0)))
	d["tutorial_kit_granted"] = bool(src.get("tutorial_kit_granted", false))
	d["updated_unix"] = maxi(0, int(src.get("updated_unix", 0)))

	var eq := default_equipped_map()
	var src_eq = src.get("equipped", {})
	if typeof(src_eq) == TYPE_DICTIONARY:
		for sk in eq.keys():
			eq[sk] = str((src_eq as Dictionary).get(sk, ""))
	d["equipped"] = eq

	var inv: Array = []
	var seen_ids := {}
	var src_inv = src.get("inventory", [])
	if typeof(src_inv) == TYPE_ARRAY:
		for it in (src_inv as Array):
			if typeof(it) != TYPE_DICTIONARY:
				continue
			var clean := sanitize_item(it as Dictionary)
			var iid := str(clean.get("id", ""))
			if iid.is_empty() or seen_ids.has(iid):
				continue
			seen_ids[iid] = true
			inv.append(clean)
	d["inventory"] = inv

	# Yetim (envanterde bulunmayan) veya çift takılı slot referanslarını temizle (tekillik garantisi).
	var used_ids := {}
	for s in SLOTS:
		var sk := str(s["key"])
		var iid := str(eq.get(sk, ""))
		if iid.is_empty() or not seen_ids.has(iid) or used_ids.has(iid):
			eq[sk] = ""
			continue
		var item_obj := find_item_in_list(inv, iid)
		if str(item_obj.get("slot_type", "")) != str(s["slot_type"]):
			eq[sk] = ""
			continue
		used_ids[iid] = true

	var q: Array = []
	var src_q = src.get("speech_queue", [])
	if typeof(src_q) == TYPE_ARRAY:
		for msg in (src_q as Array):
			if typeof(msg) == TYPE_DICTIONARY:
				q.append((msg as Dictionary).duplicate(true))
	d["speech_queue"] = q
	return d


static func sanitize_item(raw: Dictionary) -> Dictionary:
	var slot_type := str(raw.get("slot_type", "sword")).strip_edges().to_lower()
	if not SLOT_WEIGHTS.has(slot_type):
		slot_type = "sword"
	var rarity := str(raw.get("rarity", "common")).strip_edges().to_lower()
	if not RARITY_DEFS.has(rarity):
		rarity = "common"
	var plus := clampi(int(raw.get("plus", 0)), 0, MAX_PLUS)
	var default_name := str(ITEM_NAMES_BY_TYPE.get(slot_type, {}).get(rarity, "Lord Ekipmanı"))
	var item_name := str(raw.get("name", default_name)).strip_edges()
	if item_name.is_empty():
		item_name = default_name
	return {
		"id": str(raw.get("id", "")),
		"slot_type": slot_type,
		"name": item_name,
		"rarity": rarity,
		"plus": plus,
		"source": str(raw.get("source", "")),
		"obtained_unix": int(raw.get("obtained_unix", 0)),
	}


static func get_slot_def(slot_key: String) -> Dictionary:
	for s in SLOTS:
		if str(s["key"]) == slot_key:
			return s
	return {}


static func slot_type_name(slot_type: String) -> String:
	match slot_type:
		"earring": return "Küpe"
		"necklace": return "Kolye"
		"helmet": return "Kask"
		"chest": return "Göğüslük"
		"pants": return "Pantolon"
		"gloves": return "Eldiven"
		"boots": return "Ayakkabı"
		"ring": return "Yüzük"
		"belt": return "Kemer"
		"shield": return "Kalkan"
		"sword": return "Kılıç"
	return slot_type


static func icon_path_for(slot_type: String) -> String:
	return str(ICON_PATHS.get(slot_type, ICON_PATHS["sword"]))


static func rarity_label(rarity: String) -> String:
	return str((RARITY_DEFS.get(rarity, RARITY_DEFS["common"]) as Dictionary).get("name", "Sıradan"))


static func rarity_color(rarity: String) -> Color:
	return Color.html(str((RARITY_DEFS.get(rarity, RARITY_DEFS["common"]) as Dictionary).get("color_hex", "#b8c0cc")))


static func upgrade_rate_for_plus(cur_plus: int) -> int:
	if cur_plus >= MAX_PLUS or cur_plus < 0:
		return 0
	return int(UPGRADE_RATES.get(cur_plus, 0))


static func compute_item_stats(item: Dictionary, plus_override: int = -1) -> Dictionary:
	if item.is_empty():
		return {
			"attack": 0, "defense": 0, "hp": 0,
			"attack_pct": 0.0, "defense_pct": 0.0,
			"army_bonus_type": "", "army_bonus_pct": 0.0,
		}
	var slot_type := str(item.get("slot_type", "sword"))
	var rarity := str(item.get("rarity", "common"))
	var plus := clampi(plus_override if plus_override >= 0 else int(item.get("plus", 0)), 0, MAX_PLUS)
	var r_mult := float((RARITY_DEFS.get(rarity, RARITY_DEFS["common"]) as Dictionary).get("mult", 1.0))
	var base_pct := float(BASE_PLUS_PCT[plus])
	var s_weight := float(SLOT_WEIGHTS.get(slot_type, 0.7))

	var atk_pct := 0.0
	var def_pct := 0.0
	var flat_atk := 0
	var flat_def := 0
	var flat_hp := 0

	if slot_type == "sword":
		atk_pct = clampf(snappedf(base_pct * r_mult, 0.1), 0.5, MAX_ITEM_BONUS_PCT)
		flat_atk = int(round(12.0 * (1.0 + float(plus) * 0.65) * r_mult))
		flat_hp = int(round(15.0 * (1.0 + float(plus) * 0.35) * r_mult))
	elif slot_type in ["helmet", "chest", "pants", "gloves", "boots", "shield"]:
		def_pct = clampf(snappedf(base_pct * r_mult * s_weight, 0.1), 0.5, MAX_ITEM_BONUS_PCT)
		flat_def = int(round(10.0 * s_weight * (1.0 + float(plus) * 0.65) * r_mult))
		flat_hp = int(round(42.0 * s_weight * (1.0 + float(plus) * 0.55) * r_mult))
		if slot_type == "shield" or slot_type == "gloves":
			flat_atk = int(round(3.0 * (1.0 + float(plus) * 0.4) * r_mult))
	else:
		# Aksesuarlar (küpe, yüzük, kolye, kemer): dengeli ATK/DEF + yüksek HP
		atk_pct = clampf(snappedf(base_pct * r_mult * 0.45 * s_weight, 0.1), 0.2, MAX_ITEM_BONUS_PCT)
		def_pct = clampf(snappedf(base_pct * r_mult * 0.45 * s_weight, 0.1), 0.2, MAX_ITEM_BONUS_PCT)
		flat_atk = int(round(6.0 * (1.0 + float(plus) * 0.5) * r_mult))
		flat_def = int(round(6.0 * (1.0 + float(plus) * 0.5) * r_mult))
		flat_hp = int(round(50.0 * s_weight * (1.0 + float(plus) * 0.6) * r_mult))

	# Özel ordu bonusu: nadir/gelişmiş ekipmanlar ve aksesuarlar sınırlı ordu bonusu verir
	var army_type := str(ARMY_BONUS_POOL.get(slot_type, ""))
	var army_pct := 0.0
	if rarity == "rare":
		army_pct = snappedf(minf(6.0, (0.8 + float(plus) * 0.45) * s_weight), 0.1)
	elif rarity == "uncommon" and plus >= 1:
		army_pct = snappedf(minf(3.5, (0.4 + float(plus) * 0.30) * s_weight), 0.1)
	elif slot_type in ACCESSORY_SLOTS:
		army_pct = snappedf(minf(2.5, (0.3 + float(plus) * 0.22)), 0.1)

	return {
		"attack": flat_atk,
		"defense": flat_def,
		"hp": flat_hp,
		"attack_pct": atk_pct,
		"defense_pct": def_pct,
		"army_bonus_type": army_type if army_pct > 0.0 else "",
		"army_bonus_pct": army_pct,
	}


static func compute_lord_stats(lord_state: Dictionary) -> Dictionary:
	var eq: Dictionary = lord_state.get("equipped", {}) if typeof(lord_state.get("equipped")) == TYPE_DICTIONARY else {}
	var inv: Array = lord_state.get("inventory", []) if typeof(lord_state.get("inventory")) == TYPE_ARRAY else []

	var flat_hp := 0
	var flat_atk := 0
	var flat_def := 0
	var sum_atk_pct := 0.0
	var sum_def_pct := 0.0
	var inf_atk_pct := 0.0
	var arch_atk_pct := 0.0
	var cav_def_pct := 0.0
	var army_hp_pct := 0.0
	var equipped_count := 0

	for s in SLOTS:
		var sk := str(s["key"])
		var iid := str(eq.get(sk, ""))
		if iid.is_empty():
			continue
		var item := find_item_in_list(inv, iid)
		if item.is_empty():
			continue
		equipped_count += 1
		var st := compute_item_stats(item)
		flat_hp += int(st.get("hp", 0))
		flat_atk += int(st.get("attack", 0))
		flat_def += int(st.get("defense", 0))
		sum_atk_pct += float(st.get("attack_pct", 0.0))
		sum_def_pct += float(st.get("defense_pct", 0.0))
		var ab_type := str(st.get("army_bonus_type", ""))
		var ab_pct := float(st.get("army_bonus_pct", 0.0))
		match ab_type:
			"infantry_atk_pct": inf_atk_pct += ab_pct
			"archer_atk_pct": arch_atk_pct += ab_pct
			"cavalry_def_pct": cav_def_pct += ab_pct
			"army_hp_pct": army_hp_pct += ab_pct

	var total_hp := BASE_HP + flat_hp
	var total_atk := int(round(float(BASE_ATTACK + flat_atk) * (1.0 + sum_atk_pct / 100.0)))
	var total_def := int(round(float(BASE_DEFENSE + flat_def) * (1.0 + sum_def_pct / 100.0)))

	inf_atk_pct = minf(MAX_TOTAL_ARMY_BONUS_PCT, snappedf(inf_atk_pct, 0.1))
	arch_atk_pct = minf(MAX_TOTAL_ARMY_BONUS_PCT, snappedf(arch_atk_pct, 0.1))
	cav_def_pct = minf(MAX_TOTAL_ARMY_BONUS_PCT, snappedf(cav_def_pct, 0.1))
	army_hp_pct = minf(MAX_TOTAL_ARMY_BONUS_PCT, snappedf(army_hp_pct, 0.1))

	return {
		"hp": total_hp,
		"attack": total_atk,
		"defense": total_def,
		"attack_pct": snappedf(sum_atk_pct, 0.1),
		"defense_pct": snappedf(sum_def_pct, 0.1),
		"infantry_atk_pct": inf_atk_pct,
		"archer_atk_pct": arch_atk_pct,
		"cavalry_def_pct": cav_def_pct,
		"army_hp_pct": army_hp_pct,
		"equipped_count": equipped_count,
		"total_power": total_atk + total_def + int(round(float(total_hp) * 0.2)),
	}


static func find_item_in_list(inv: Array, item_id: String) -> Dictionary:
	if item_id.is_empty():
		return {}
	for it in inv:
		if typeof(it) == TYPE_DICTIONARY and str((it as Dictionary).get("id", "")) == item_id:
			return it as Dictionary
	return {}


static func is_item_equipped(lord_state: Dictionary, item_id: String) -> bool:
	if item_id.is_empty():
		return false
	var eq = lord_state.get("equipped", {})
	if typeof(eq) != TYPE_DICTIONARY:
		return false
	for k in (eq as Dictionary).keys():
		if str((eq as Dictionary)[k]) == item_id:
			return true
	return false


static func equipped_slot_of(lord_state: Dictionary, item_id: String) -> String:
	if item_id.is_empty():
		return ""
	var eq = lord_state.get("equipped", {})
	if typeof(eq) != TYPE_DICTIONARY:
		return ""
	for k in (eq as Dictionary).keys():
		if str((eq as Dictionary)[k]) == item_id:
			return str(k)
	return ""


static func get_unequipped_inventory(lord_state: Dictionary, slot_type_filter: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var inv = lord_state.get("inventory", [])
	if typeof(inv) != TYPE_ARRAY:
		return out
	for it in (inv as Array):
		if typeof(it) != TYPE_DICTIONARY:
			continue
		var d := it as Dictionary
		var iid := str(d.get("id", ""))
		if iid.is_empty() or is_item_equipped(lord_state, iid):
			continue
		if not slot_type_filter.is_empty() and str(d.get("slot_type", "")) != slot_type_filter:
			continue
		out.append(d)
	return out


static func create_item(slot_type: String, rarity: String, plus: int, seq: int, source: String = "", now_unix: int = 0) -> Dictionary:
	var st := slot_type if SLOT_WEIGHTS.has(slot_type) else "sword"
	var rar := rarity if RARITY_DEFS.has(rarity) else "common"
	var p := clampi(plus, 0, MAX_PLUS)
	var nm := str(ITEM_NAMES_BY_TYPE.get(st, {}).get(rar, "Lord Ekipmanı"))
	return {
		"id": "itm_%d_%s" % [maxi(1, seq), st],
		"slot_type": st,
		"name": nm,
		"rarity": rar,
		"plus": p,
		"source": source,
		"obtained_unix": now_unix,
	}


static func roll_bandit_drop(bandit_level: int, rng: RandomNumberGenerator, seq: int, village_name: String = "", now_unix: int = 0) -> Dictionary:
	var lvl := clampi(bandit_level, 1, 10)
	var slot_idx := rng.randi_range(0, BATTLE_DROP_SLOTS.size() - 1)
	var slot_type := BATTLE_DROP_SLOTS[slot_idx]

	var roll := rng.randf() * 100.0
	var rarity := "common"
	# Nadir eşyalar ileri seviye haydut köylerinde (Lv >= 6) %10 ihtimal ile düşer
	if lvl >= 6 and roll < 10.0:
		rarity = "rare"
	else:
		var uncommon_chance := 15.0 + float(lvl) * 3.0  # Lv1=%18 .. Lv10=%45
		if roll < (10.0 if lvl >= 6 else 0.0) + uncommon_chance:
			rarity = "uncommon"

	var plus := 0
	if lvl >= 8:
		plus = rng.randi_range(0, 2)
	elif lvl >= 5:
		plus = rng.randi_range(0, 1)

	var src := "Haydut Köyü Sv.%d" % lvl
	if not village_name.is_empty():
		src = "%s (Sv.%d)" % [village_name, lvl]
	return create_item(slot_type, rarity, plus, seq, src, now_unix)


## Dengeli Haydut Köyü seviye havuzu (Sv.1-2-3-4 başlangıç erişimi bol, 1..10 arası tüm seviyeler dağılımlı)
const BANDIT_LEVEL_POOL: Array[int] = [1, 2, 1, 2, 3, 1, 2, 4, 3, 5, 6, 7, 8, 9, 10, 4]


static func bandit_level_for_village(v: Dictionary) -> int:
	if v.has("bandit_level") and int(v.get("bandit_level", 0)) > 0:
		return clampi(int(v.get("bandit_level", 1)), 1, 10)
	var vid := maxi(1, int(v.get("id", 1)))
	return BANDIT_LEVEL_POOL[posmod(vid - 1, BANDIT_LEVEL_POOL.size())]


static func bandit_template(level: int) -> Dictionary:
	var lvl := clampi(level, 1, 10)
	var wall_lvl := mini(16, lvl + (1 if lvl >= 5 else 0))
	var farmer := 6 + lvl * 4
	var spear := 4 + lvl * 6
	var sword := (lvl * 4) if lvl >= 2 else 0
	var axe := (lvl * 3) if lvl >= 4 else 0
	var bow := (lvl * 5) if lvl >= 3 else 0
	var heavy := ((lvl - 5) * 3) if lvl >= 6 else 0
	var units := {
		"farmer": farmer,
		"spear": spear,
		"sword": sword,
		"axe": axe,
		"bow": bow,
		"spy": 2 + lvl,
		"light": 0,
		"heavy": heavy,
		"ram": 0,
		"kata": 0,
		"snob": 0,
	}
	var b_buildings := {
		"main": lvl + 1,
		"stone": lvl,
		"wood": lvl,
		"iron": lvl,
		"farm": lvl + 2,
		"storage": lvl + 1,
		"barracks": mini(20, 1 + lvl * 2),
		"wall": wall_lvl,
		"hide": mini(15, lvl),
		"market": 0,
		"stable": 0,
		"smith": 0,
		"garage": 0,
		"snob": 0,
		"statue": 0,
	}
	var pts := 120 + lvl * 220
	var lord_atk := 75 + lvl * 22
	var lord_def := 70 + lvl * 24
	var lord_hp := 360 + lvl * 85
	return {
		"bandit_level": lvl,
		"name": "Haydut Köyü Sv.%d" % lvl,
		"owner": "Haydutlar",
		"wall_level": wall_lvl,
		"units": units,
		"buildings": b_buildings,
		"points": pts,
		"lord": {
			"present": true,
			"name": "Haydut Reisi Sv.%d" % lvl,
			"hp": lord_hp,
			"attack": lord_atk,
			"defense": lord_def,
			"attack_pct": float(lvl) * 1.5,
			"defense_pct": float(lvl) * 1.5,
			"infantry_atk_pct": 0.0,
			"archer_atk_pct": 0.0,
			"cavalry_def_pct": 0.0,
			"army_hp_pct": 0.0,
		},
	}


static func army_bonus_label(ab_type: String) -> String:
	match ab_type:
		"infantry_atk_pct": return "Piyade Saldırısı"
		"archer_atk_pct": return "Okçu Saldırısı"
		"cavalry_def_pct": return "Süvari Savunması"
		"army_hp_pct": return "Ordu HP"
	return ab_type


static func format_item_short_bonus(item: Dictionary, plus_override: int = -1) -> String:
	var st := compute_item_stats(item, plus_override)
	var parts: Array[String] = []
	var ap := float(st.get("attack_pct", 0.0))
	var dp := float(st.get("defense_pct", 0.0))
	if ap > 0.0:
		parts.append("Saldırı +%%%.1f" % ap)
	if dp > 0.0:
		parts.append("Savunma +%%%.1f" % dp)
	var hp := int(st.get("hp", 0))
	if hp > 0:
		parts.append("HP +%d" % hp)
	var ab_t := str(st.get("army_bonus_type", ""))
	var ab_p := float(st.get("army_bonus_pct", 0.0))
	if not ab_t.is_empty() and ab_p > 0.0:
		parts.append("%s +%%%.1f" % [army_bonus_label(ab_t), ab_p])
	return " · ".join(parts)
