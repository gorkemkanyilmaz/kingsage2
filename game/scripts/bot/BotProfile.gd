class_name BotProfile
extends RefCounted
## BotProfile — Bot kişilikleri ve zorluk dereceleri (Taht ve Kılıç / A-BOT).
##
## Determinizm:
##  Her botun kişiliği ve rastgeleliği `(world_seed, village_id)` çiftinden türetilir.
##  Global `randi()` veya determinizmi bozan hiçbir rastgelelik kullanılmaz.

const DIFFICULTY_EASY := "easy"
const DIFFICULTY_NORMAL := "normal"
const DIFFICULTY_HARD := "hard"

const PERSONALITY_BUILDER := "builder"
const PERSONALITY_TRADER := "trader"
const PERSONALITY_WARLORD := "warlord"

const DIFFICULTIES := [DIFFICULTY_EASY, DIFFICULTY_NORMAL, DIFFICULTY_HARD]
const PERSONALITIES := [PERSONALITY_BUILDER, PERSONALITY_TRADER, PERSONALITY_WARLORD]

## Düşünme/karar aralıkları (saniye cinsinden)
const THINK_INTERVALS := {
	DIFFICULTY_EASY: 300,    # 5 dakikada bir
	DIFFICULTY_NORMAL: 120,  # 2 dakikada bir
	DIFFICULTY_HARD: 60,     # 1 dakikada bir
}

## Öncelikli bina listeleri
const PRIORITY_BUILDINGS := {
	PERSONALITY_BUILDER: [
		"wood", "stone", "iron", "main", "farm", "storage",
		"wood", "stone", "iron", "hide", "wall", "barracks"
	],
	PERSONALITY_TRADER: [
		"wood", "stone", "iron", "market", "storage", "hide",
		"farm", "main", "stable", "wood", "stone", "iron"
	],
	PERSONALITY_WARLORD: [
		"storage", "farm", "barracks", "wall", "wood", "stone", "iron",
		"barracks", "smith", "wall", "farm", "main", "barracks"
	],
}

## Birlik üretim hedefleri (maksimum tutulacak aktif asker sayısı)
const ARMY_TARGETS := {
	PERSONALITY_BUILDER: 15,
	PERSONALITY_TRADER: 30,
	PERSONALITY_WARLORD: 120,
}


## Belirli bir köy için tohumdan deterministik profil üretir
static func get_profile(village: Dictionary, world_seed: int) -> Dictionary:
	# Eğer köyde önceden atanmış özel profil varsa onu kullan
	if village.has("bot_profile") and typeof(village["bot_profile"]) == TYPE_DICTIONARY:
		return village["bot_profile"]
	
	var vid := int(village.get("id", 1))
	var h: int = ((world_seed ^ 0x3f12a9c5) + vid * 2654435761) & 0x7fffffff
	var diff_idx: int = h % 3
	var pers_idx: int = (int(h / 3)) % 3
	
	var profile := {
		"difficulty": DIFFICULTIES[diff_idx],
		"personality": PERSONALITIES[pers_idx],
		"seed": h,
		"think_interval": THINK_INTERVALS[DIFFICULTIES[diff_idx]],
		"army_target": ARMY_TARGETS[PERSONALITIES[pers_idx]],
	}
	return profile


## Testler veya özel senaryolar için profil oluşturucu
static func create_custom_profile(personality: String, difficulty: String = DIFFICULTY_NORMAL) -> Dictionary:
	var pers := personality if personality in PERSONALITIES else PERSONALITY_BUILDER
	var diff := difficulty if difficulty in DIFFICULTIES else DIFFICULTY_NORMAL
	return {
		"difficulty": diff,
		"personality": pers,
		"seed": 12345,
		"think_interval": THINK_INTERVALS.get(diff, 120),
		"army_target": ARMY_TARGETS.get(pers, 30),
	}
