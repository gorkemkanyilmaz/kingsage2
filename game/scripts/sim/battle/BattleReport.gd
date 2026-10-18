class_name BattleReport
extends RefCounted
## Savaş Raporu üretici (Türkçe) — Taht ve Kılıç.
##
## `BattleSimulator.simulate()` sonucunu alır; **arayüzün/mesaj sisteminin**
## doğrudan kullanabileceği Türkçe metin ve yapısal veriyi üretir.
##
## Bağımsızdır (yalnızca saf metin/veri üretir): `BattleSimulator`'a derleme
## zamanında bağlanmaz; birim adları kendi tablosundadır. Terimler
## `docs/TERIMLER.md` ile birebir aynıdır.

const UNIT_NAMES_TR := {
	"farmer": "Köy Koruyucusu",
	"spear": "Silahtar",
	"sword": "Muhafız",
	"axe": "Baltacı",
	"bow": "Okçu",
	"spy": "Casus",
	"light": "Akıncı",
	"heavy": "Kara Şövalye",
	"ram": "Şahmerdan",
	"kata": "Mancınık",
	"snob": "Kont",
}

const RESOURCE_NAMES_TR := {"wood": "odun", "stone": "taş", "iron": "demir"}


## Birim anahtarının resmî Türkçe adını döndürür.
static func unit_name(key: String) -> String:
	return str(UNIT_NAMES_TR.get(key, key))


## `BattleSimulator.simulate()` sonucundan yapısal + metinsel rapor üretir.
## `attacker` / `defender` isteğe bağlıdır (isim/taraf bilgisi için).
static func build(result: Dictionary, attacker: Dictionary = {}, defender: Dictionary = {}) -> Dictionary:
	var attacker_won := bool(result.get("attacker_won", false))
	var outcome := "Saldıran kazandı" if attacker_won else "Savunan kazandı"
	if not attacker_won and _sum(result.get("attacker_losses", {})) == 0 and _sum(result.get("defender_losses", {})) == 0:
		outcome = "Muharebe olmadı"

	var morale := float(result.get("morale", 1.0))
	var luck := float(result.get("luck", 0.0))

	var lines := PackedStringArray()
	lines.append("Savaş Raporu")
	lines.append("Sonuç: %s" % outcome)
	lines.append("Moral: %%%d · Şans: %s%%%d" % [
		_round_half_up(morale * 100.0),
		"+" if luck >= 0.0 else "-",
		_round_half_up(absf(luck) * 100.0),
	])

	var phase_lines := PackedStringArray()
	var phases: Array = result.get("phases", [])
	for phase in phases:
		if typeof(phase) != TYPE_DICTIONARY:
			continue
		phase_lines.append(_phase_line(phase))
	lines.append("")
	lines.append("Fazlar:")
	for line in phase_lines:
		lines.append("  " + line)

	var attacker_losses: Dictionary = result.get("attacker_losses", {})
	var defender_losses: Dictionary = result.get("defender_losses", {})
	var lines_losses := "Saldıran kayıpları: %s" % _losses_text(attacker_losses)
	lines_losses += "\nSavunan kayıpları: %s" % _losses_text(defender_losses)

	var loot: Dictionary = result.get("loot", {})
	var loot_text := "Yağma: %s (taşıma kapasitesi %s · gizli depo %s)" % [
		_resources_text(loot),
		_format_int(int(result.get("carry_capacity", 0))),
		_format_int(int(result.get("hideout_capacity", 0))),
	]
	if _sum(loot) == 0:
		loot_text = "Yağma: yok (taşıma kapasitesi %s · gizli depo %s)" % [
			_format_int(int(result.get("carry_capacity", 0))),
			_format_int(int(result.get("hideout_capacity", 0))),
		]

	lines.append("")
	lines.append(lines_losses)
	lines.append(loot_text)
	lines.append(_conquest_text(result))

	var notes := PackedStringArray()
	if not bool(result.get("min_attack_ok", true)):
		notes.append("Uyarı: Saldırı için gereken en az birim (%s) karşılanmıyor." % _format_int(int(result.get("min_attack_units", 0))))
	if bool(result.get("is_raid", false)):
		notes.append("Bu bir talan (raid) saldırısıdır; fetih denenmez.")
	if bool(result.get("night", false)):
		notes.append("Gece bonusu etkindi (savunma gücü çarpanı uygulandı).")
	for note in notes:
		lines.append(note)

	var phases_data: Array = []
	for phase in phases:
		if typeof(phase) == TYPE_DICTIONARY:
			phases_data.append({
				"order": int(phase.get("order", 0)),
				"key": str(phase.get("key", "")),
				"name_tr": str(phase.get("name_tr", "")),
				"did_occur": bool(phase.get("did_occur", false)),
				"text": _phase_line(phase),
			})

	return {
		"title": "Savaş Raporu",
		"outcome": outcome,
		"attacker_won": attacker_won,
		"morale": morale,
		"luck": luck,
		"phases": phases_data,
		"attacker_losses_text": _losses_text(attacker_losses),
		"defender_losses_text": _losses_text(defender_losses),
		"loot_text": loot_text,
		"conquest_text": _conquest_text(result),
		"notes": notes,
		"text": "\n".join(lines),
	}


## Rapor yapısını tek bir metne çevirir.
static func to_text(report: Dictionary) -> String:
	return str(report.get("text", ""))


## Kısa tek satır özet (liste görünümü için).
static func summary_line(result: Dictionary) -> String:
	var outcome := "Saldıran kazandı" if bool(result.get("attacker_won", false)) else "Savunan kazandı"
	var lost := _sum(result.get("attacker_losses", {}))
	return "%s · saldıran kaybı %s · yağma %s" % [
		outcome, _format_int(lost), _resources_text(result.get("loot", {})),
	]


# --- İç yardımcılar ---------------------------------------------------------

static func _phase_line(phase: Dictionary) -> String:
	var order := int(phase.get("order", 0))
	var name_tr := str(phase.get("name_tr", ""))
	var did := bool(phase.get("did_occur", false))
	var data: Dictionary = phase.get("data", {})
	var detail := ""
	match str(phase.get("key", "")):
		"wall_damage":
			detail = "Şahmerdan %s · sur %d → %d (hasar %%%d)" % [
				_format_int(int(data.get("rams", 0))),
				int(data.get("wall_level_before", 0)),
				int(data.get("wall_level_after", 0)),
				_round_half_up(float(data.get("wall_damage_pct", 0.0))),
			]
		"spy_attack":
			detail = "Casus %s → hayatta %s (savunan casus %s)" % [
				_format_int(int(data.get("attack_spies", 0))),
				_format_int(int(data.get("spy_survivors", 0))),
				_format_int(int(data.get("defence_spies", 0))),
			]
		"normal_battle":
			detail = "saldırı %s ↔ savunma %s · %s" % [
				_format_int(int(floor(float(data.get("attack_value", 0.0))))),
				_format_int(int(floor(float(data.get("defence_value", 0.0))))),
				"Saldıran üstün" if bool(data.get("attacker_won", false)) else "Savunan üstün",
			]
		"building_damage":
			detail = "Mancınık %s · yıkılan seviye %s" % [
				_format_int(int(data.get("katas_alive", 0))),
				_format_int(int(data.get("levels_destroyed", 0))),
			]
		"conquest_and_pillage":
			detail = "yağma %s" % _resources_text(data.get("loot", {}))
			if bool(data.get("conquered", false)):
				detail += " · KÖY FETHEDİLDİ"
		_:
			detail = ""
	if not did:
		detail = "tetiklenmedi" + (" · " + detail if not detail.is_empty() else "")
	return "%d) %s — %s" % [order, name_tr, detail]


static func _losses_text(losses: Dictionary) -> String:
	var parts := PackedStringArray()
	var keys := losses.keys()
	keys.sort()
	for key in keys:
		var count := int(losses[key])
		if count > 0:
			parts.append("%s %s" % [_format_int(count), unit_name(str(key))])
	if parts.is_empty():
		return "yok"
	return ", ".join(parts)


static func _resources_text(resources: Dictionary) -> String:
	var parts := PackedStringArray()
	for key in ["wood", "stone", "iron"]:
		parts.append("%s %s" % [_format_int(int(resources.get(key, 0))), str(RESOURCE_NAMES_TR.get(key, key))])
	return ", ".join(parts)


static func _conquest_text(result: Dictionary) -> String:
	if not bool(result.get("attacker_won", false)):
		return "Fetih: saldıran kaybetti."
	if bool(result.get("is_raid", false)):
		return "Fetih: talan saldırısında fetih yok."
	var had := int(result.get("count_had", 0))
	if had <= 0:
		return "Fetih: orduda Kont yok."
	if bool(result.get("count_died", false)):
		return "Fetih: Kont muharebede öldü."
	if bool(result.get("conquered", false)):
		return "Fetih: başarılı — köy ele geçirildi (Güç Alanı %s seviyesine düştü)." % _format_int(int(result.get("realm_of_power_after", 0)))
	var realm_after := int(result.get("realm_of_power_after", -1))
	if realm_after >= 0:
		return "Fetih: Kont etkili (Güç Alanı -%s → %s)." % [
			_format_int(int(result.get("realm_loss", 0))),
			_format_int(realm_after),
		]
	return "Fetih: Kont hayatta; Güç Alanı düşürüldü (hedef değeri bilinmiyor)."


static func _sum(d: Dictionary) -> int:
	var total := 0
	for key in d.keys():
		total += int(d[key])
	return total


static func _format_int(value: int) -> String:
	var negative := value < 0
	var digits := str(absi(value))
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "." + out
	return ("-" if negative else "") + out


static func _round_half_up(x: float) -> int:
	return int(floor(x + 0.5))
