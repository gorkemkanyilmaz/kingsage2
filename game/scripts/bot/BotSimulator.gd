class_name BotSimulator
extends RefCounted
## BotSimulator — Tüm eski bot köylerini sabit Haydut Köyü'ne dönüştürür ve korur.
##
## Taht ve Kılıç (Build 38+):
##   • Bot köyleri artık kendi kendine gelişmez, bina basmaz ve kimseye saldırmaz.
##   • Her bot köyü (`is_bot == true`), seviyesine (1..10) uygun sabit bir garnizon,
##     sur ve Haydut Reisi (Lord) barındıran bir Haydut Köyü'dür (`is_bandit = true`).
##   • Asla fethedilemez; saldırı sonunda ordusu anında eski haline döner.

const LordModelScript := preload("res://scripts/model/LordModel.gd")


static func ensure_bandit_village(village: Dictionary) -> bool:
	if typeof(village) != TYPE_DICTIONARY:
		return false
	if not bool(village.get("is_bot", false)) and not bool(village.get("is_bandit", false)):
		return false
	var lvl := LordModelScript.bandit_level_for_village(village)
	var tmpl := LordModelScript.bandit_template(lvl)
	var changed := false
	if not bool(village.get("is_bandit", false)) or int(village.get("bandit_level", 0)) != lvl:
		changed = true
	village["is_bandit"] = true
	village["is_bot"] = true
	village["is_barbarian"] = false
	village["bandit_level"] = lvl
	village["owner"] = str(tmpl.get("owner", "Haydutlar"))
	var cur_name := str(village.get("name", ""))
	if not cur_name.begins_with("Haydut Köyü"):
		village["name"] = str(tmpl.get("name", "Haydut Köyü Sv.%d" % lvl))
		changed = true
	var tmpl_b: Dictionary = tmpl.get("buildings", {}) as Dictionary
	var blds: Dictionary = village.get("buildings", {}) if typeof(village.get("buildings")) == TYPE_DICTIONARY else {}
	if int(blds.get("wall", -1)) != int(tmpl_b.get("wall", 1)) or not village.has("bandit_initialized"):
		village["buildings"] = tmpl_b.duplicate(true)
		village["units"] = (tmpl.get("units", {}) as Dictionary).duplicate(true)
		village["points"] = int(tmpl.get("points", 300))
		village["realm_of_power"] = int(tmpl.get("points", 300))
		village["bandit_initialized"] = true
		changed = true
	village["protection_until"] = 0
	village["protection_until_unix"] = 0
	village["conquest_protection_until"] = 0
	village["conquest_protection_until_unix"] = 0
	return changed


static func process_tick(state: Dictionary, _now_unix: int, _delta_seconds: float) -> Array:
	var villages = state.get("villages", [])
	if typeof(villages) != TYPE_ARRAY:
		return []
	for v in (villages as Array):
		if typeof(v) != TYPE_DICTIONARY:
			continue
		var vd := v as Dictionary
		if bool(vd.get("is_bandit", false)) and bool(vd.get("bandit_initialized", false)):
			continue
		if bool(vd.get("is_bot", false)) or bool(vd.get("is_bandit", false)):
			ensure_bandit_village(vd)
	return []
