class_name AllianceModel
extends RefCounted
## AllianceModel — İttifak sistemi veri modeli ve kuralları (docs/12-ITTIFAKLAR.md).
##
## Forum YOKTUR; bunun yerine canlı İttifak İçi Sohbet (Alliance Chat),
## iç duyurular, davet/katılma, üye yönetimi ve diplomasi bulunur.

const MAX_TAG_LENGTH := 6


static func _norm_name(raw: String) -> String:
	var s := raw.strip_edges().to_lower()
	while s.find("  ") >= 0:
		s = s.replace("  ", " ")
	return s


static func _matches(a: String, b: String) -> bool:
	var na := _norm_name(a)
	var nb := _norm_name(b)
	return not na.is_empty() and na == nb


static func is_founder(alliance: Dictionary, player_name: String) -> bool:
	if alliance.is_empty() or player_name.strip_edges().is_empty():
		return false
	var f_name := str(alliance.get("founder", "")).strip_edges()
	if not f_name.is_empty():
		return _matches(f_name, player_name)
	var l_name := str(alliance.get("leader", "")).strip_edges()
	return not l_name.is_empty() and _matches(l_name, player_name)


static func is_leader(alliance: Dictionary, player_name: String) -> bool:
	if alliance.is_empty() or player_name.strip_edges().is_empty():
		return false
	if is_founder(alliance, player_name):
		return true
	if _matches(str(alliance.get("leader", "")), player_name):
		return true
	for m in alliance.get("members", []):
		if typeof(m) == TYPE_DICTIONARY and _matches(str((m as Dictionary).get("name", "")), player_name):
			if bool((m as Dictionary).get("is_leader", false)):
				return true
	return false


static func _ensure_diplomacy(alliance: Dictionary) -> Dictionary:
	var diplo: Dictionary = alliance.get("diplomacy", {}) if typeof(alliance.get("diplomacy")) == TYPE_DICTIONARY else {}
	diplo.erase("nap")
	for lk in ["allies", "enemies", "ally_requests_in", "ally_requests_out"]:
		if typeof(diplo.get(lk)) != TYPE_ARRAY:
			diplo[lk] = []
	alliance["diplomacy"] = diplo
	return diplo


## Benzersiz bir kimlik üretir.
static func _generate_id(state: Dictionary) -> int:
	var max_id := 0
	for a in state.get("alliances", []):
		if typeof(a) == TYPE_DICTIONARY:
			var aid := int((a as Dictionary).get("id", 0))
			if aid > max_id:
				max_id = aid
	return max_id + 1


## Oyuncunun ait olduğu ittifakı döndürür (yoksa boş sözlük).
static func get_player_alliance(state: Dictionary, player_name: String) -> Dictionary:
	if player_name.is_empty():
		return {}
	for a in state.get("alliances", []):
		if typeof(a) != TYPE_DICTIONARY:
			continue
		for m in (a as Dictionary).get("members", []):
			if typeof(m) == TYPE_DICTIONARY and str((m as Dictionary).get("name", "")) == player_name:
				return a as Dictionary
	return {}


## Etikete göre ittifak arar.
static func find_by_tag(state: Dictionary, tag: String) -> Dictionary:
	var clean := tag.strip_edges().to_upper()
	for a in state.get("alliances", []):
		if typeof(a) == TYPE_DICTIONARY and str((a as Dictionary).get("tag", "")).to_upper() == clean:
			return a as Dictionary
	return {}


## İttifak oluşturur (docs/12 §3).
## Kural: İsim ve etiket benzersiz olmalı, etiket en fazla 6 karakter.
static func create_alliance(
	state: Dictionary,
	creator_name: String,
	name: String,
	tag: String,
	description: String = ""
) -> Dictionary:
	var clean_tag := tag.strip_edges().to_upper()
	var clean_name := name.strip_edges()

	if clean_tag.is_empty():
		return {"ok": false, "message": "İttifak etiketi boş olamaz."}
	if clean_tag.length() > MAX_TAG_LENGTH:
		return {"ok": false, "message": "İttifak etiketi en fazla %d karakter olabilir." % MAX_TAG_LENGTH}
	if clean_name.is_empty():
		return {"ok": false, "message": "İttifak ismi boş olamaz."}

	if not get_player_alliance(state, creator_name).is_empty():
		return {"ok": false, "message": "Zaten bir ittifakın üyesisiniz. Önce ayrılmalısınız."}

	# Benzersizlik kontrolü
	for a in state.get("alliances", []):
		if typeof(a) != TYPE_DICTIONARY:
			continue
		if str((a as Dictionary).get("tag", "")).to_upper() == clean_tag:
			return {"ok": false, "message": "Bu etiket (%s) zaten kullanımda." % clean_tag}
		if str((a as Dictionary).get("name", "")).to_lower() == clean_name.to_lower():
			return {"ok": false, "message": "Bu ittifak ismi (%s) zaten kullanımda." % clean_name}

	var now := int(Time.get_unix_time_from_system())
	var new_id := _generate_id(state)

	var creator_points := _calculate_player_points(state, creator_name)

	var alliance := {
		"id": new_id,
		"name": clean_name,
		"tag": clean_tag,
		"description": description.strip_edges(),
		"internal_announcement": "İttifakımıza hoş geldiniz! Birlikte güçlüyüz.",
		"founder": creator_name,
		"leader": creator_name,
		"created_unix": now,
		"members": [
			{
				"name": creator_name,
				"rank": "council_of_elders",
				"rank_title": "Kurucu Lider",
				"points": creator_points,
				"is_leader": true,
				"joined_unix": now,
				"rights": {
					"invitations": true,
					"diplomacy": true,
					"alliance_leader": true,
					"circular_mail": true
				}
			}
		],
		"invitations": [],
		"join_requests": [],
		"join_requests_updated_unix": now,
		"chat_messages": [
			{
				"sender": "Sistem",
				"text": "[%s] %s ittifakı kuruldu!" % [clean_tag, clean_name],
				"timestamp_unix": now
			}
		],
		"diplomacy": {
			"allies": [],
			"enemies": [],
			"ally_requests_in": [],
			"ally_requests_out": []
		},
		"diplomacy_updated_unix": now,
		"announcement_updated_unix": now
	}

	if typeof(state.get("alliances")) != TYPE_ARRAY:
		state["alliances"] = []
	(state["alliances"] as Array).append(alliance)

	return {"ok": true, "alliance": alliance}


## İttifak içi sohbet mesajı gönderir (docs/12 & kullanıcı isteği).
static func send_chat_message(
	state: Dictionary,
	alliance_id: int,
	sender_name: String,
	text: String
) -> Dictionary:
	var clean_text := text.strip_edges()
	if clean_text.is_empty():
		return {"ok": false, "message": "Mesaj boş olamaz."}

	var alliance: Dictionary = _find_alliance_by_id(state, alliance_id)
	if alliance.is_empty():
		return {"ok": false, "message": "İttifak bulunamadı."}

	# Gönderen üye mi?
	var is_member := false
	for m in alliance.get("members", []):
		if typeof(m) == TYPE_DICTIONARY and str((m as Dictionary).get("name", "")) == sender_name:
			is_member = true
			break
	if not is_member:
		return {"ok": false, "message": "Yalnızca ittifak üyeleri sohbete mesaj yazabilir."}

	if typeof(alliance.get("chat_messages")) != TYPE_ARRAY:
		alliance["chat_messages"] = []

	var now := int(Time.get_unix_time_from_system())
	var msg := {
		"sender": sender_name,
		"text": clean_text,
		"timestamp_unix": now
	}
	(alliance["chat_messages"] as Array).append(msg)
	return {"ok": true, "message_data": msg}


## Oyuncuya davet gönderir (docs/12 §5).
static func invite_player(
	state: Dictionary,
	alliance_id: int,
	inviter_name: String,
	target_player_name: String
) -> Dictionary:
	var clean_target := target_player_name.strip_edges()
	if clean_target.is_empty():
		return {"ok": false, "message": "Oyuncu adı boş olamaz."}

	var alliance: Dictionary = _find_alliance_by_id(state, alliance_id)
	if alliance.is_empty():
		return {"ok": false, "message": "İttifak bulunamadı."}

	# Hedef zaten herhangi bir ittifakta mı?
	if not get_player_alliance(state, clean_target).is_empty():
		return {"ok": false, "message": "%s zaten bir ittifak üyesi." % clean_target}

	if typeof(alliance.get("invitations")) != TYPE_ARRAY:
		alliance["invitations"] = []

	for inv in (alliance["invitations"] as Array):
		if typeof(inv) == TYPE_DICTIONARY and str((inv as Dictionary).get("player_name", "")) == clean_target:
			return {"ok": false, "message": "%s için zaten bekleyen bir davet var." % clean_target}

	var now := int(Time.get_unix_time_from_system())
	(alliance["invitations"] as Array).append({
		"player_name": clean_target,
		"invited_by": inviter_name,
		"created_unix": now
	})

	# Hedef oyuncunun gelen kutusuna davet mesajı ekle
	if typeof(state.get("messages")) != TYPE_ARRAY:
		state["messages"] = []
	(state["messages"] as Array).append({
		"id": now * 1000 + randi() % 1000,
		"from": "%s ([%s])" % [inviter_name, alliance.get("tag", "")],
		"to": clean_target,
		"subject": " İttifak Daveti: [%s]" % str(alliance.get("tag", "")),
		"body": "Sayın %s,\n\nSizi [%s] %s ittifakına katılmaya davet ediyoruz.\nİttifak sekmesinden daveti kabul edebilirsiniz." % [clean_target, alliance.get("tag", ""), alliance.get("name", "")],
		"created_unix": now,
		"read": false
	})

	return {"ok": true}


## Bekleyen daveti kabul eder.
static func accept_invitation(state: Dictionary, player_name: String, alliance_id: int) -> Dictionary:
	var alliance: Dictionary = _find_alliance_by_id(state, alliance_id)
	if alliance.is_empty():
		return {"ok": false, "message": "İttifak bulunamadı."}

	if not get_player_alliance(state, player_name).is_empty():
		return {"ok": false, "message": "Zaten bir ittifak üyesisiniz."}

	var invs: Array = alliance.get("invitations", [])
	var found_idx := -1
	for i in range(invs.size()):
		if typeof(invs[i]) == TYPE_DICTIONARY and str((invs[i] as Dictionary).get("player_name", "")) == player_name:
			found_idx = i
			break

	if found_idx >= 0:
		invs.remove_at(found_idx)

	_remove_player_join_requests_everywhere(state, player_name)

	var now := int(Time.get_unix_time_from_system())
	var pts := _calculate_player_points(state, player_name)

	var member := {
		"name": player_name,
		"rank": "member",
		"rank_title": "Savaşçı",
		"points": pts,
		"is_leader": false,
		"joined_unix": now,
		"rights": {"invitations": false, "diplomacy": false, "alliance_leader": false, "circular_mail": false}
	}
	(alliance["members"] as Array).append(member)

	# Sohbete sistem mesajı
	if typeof(alliance.get("chat_messages")) != TYPE_ARRAY:
		alliance["chat_messages"] = []
	(alliance["chat_messages"] as Array).append({
		"sender": "Sistem",
		"text": " %s ittifaka katıldı!" % player_name,
		"timestamp_unix": now
	})

	return {"ok": true}


## İttifaktan ayrılır (docs/12 §1).
static func leave_alliance(state: Dictionary, player_name: String) -> Dictionary:
	var alliance: Dictionary = get_player_alliance(state, player_name)
	if alliance.is_empty():
		return {"ok": false, "message": "Herhangi bir ittifak üyesi değilsiniz."}

	var members: Array = alliance.get("members", [])
	var m_idx := -1
	var was_leader := false
	for i in range(members.size()):
		var m: Dictionary = members[i]
		if str(m.get("name", "")) == player_name:
			m_idx = i
			was_leader = bool(m.get("is_leader", false))
			break

	if m_idx < 0:
		return {"ok": false, "message": "Üye kaydı bulunamadı."}

	members.remove_at(m_idx)

	var now := int(Time.get_unix_time_from_system())
	if members.is_empty():
		# Son üye ayrıldı → ittifak dağılır
		var all_allies: Array = state.get("alliances", [])
		var a_idx := all_allies.find(alliance)
		if a_idx >= 0:
			all_allies.remove_at(a_idx)
		return {"ok": true, "dissolved": true}

	if was_leader:
		# Yeni lider ilk üyeye devredilir
		var new_leader: Dictionary = members[0]
		new_leader["is_leader"] = true
		new_leader["rank"] = "council_of_elders"
		new_leader["rank_title"] = "Lider"
		alliance["leader"] = str(new_leader.get("name", ""))

	# Sohbete bildirim
	if typeof(alliance.get("chat_messages")) != TYPE_ARRAY:
		alliance["chat_messages"] = []
	(alliance["chat_messages"] as Array).append({
		"sender": "Sistem",
		"text": "🚪 %s ittifaktan ayrıldı." % player_name,
		"timestamp_unix": now
	})

	return {"ok": true}


## Üye atar (docs/12 §5).
static func kick_member(state: Dictionary, kicker_name: String, target_member_name: String) -> Dictionary:
	if kicker_name == target_member_name:
		return {"ok": false, "message": "Kendinizi atamazsınız; ayrılma seçeneğini kullanın."}

	var alliance: Dictionary = get_player_alliance(state, kicker_name)
	if alliance.is_empty():
		return {"ok": false, "message": "İttifak bulunamadı."}

	var is_leader := false
	for m in alliance.get("members", []):
		if str((m as Dictionary).get("name", "")) == kicker_name and bool((m as Dictionary).get("is_leader", false)):
			is_leader = true
			break
	if not is_leader:
		return {"ok": false, "message": "Yalnızca ittifak lideri üye atabilir."}

	var members: Array = alliance.get("members", [])
	var target_idx := -1
	for i in range(members.size()):
		if str((members[i] as Dictionary).get("name", "")) == target_member_name:
			target_idx = i
			break

	if target_idx < 0:
		return {"ok": false, "message": "Atılacak üye bulunamadı."}

	members.remove_at(target_idx)
	var now := int(Time.get_unix_time_from_system())
	(alliance["chat_messages"] as Array).append({
		"sender": "Sistem",
		"text": "⚠️ %s ittifaktan çıkarıldı." % target_member_name,
		"timestamp_unix": now
	})
	return {"ok": true}


## İç duyuruyu günceller — yalnızca İttifak Kurucu Lideri (docs/12 §4).
static func update_announcement(state: Dictionary, alliance_id: int, editor_name: String, text: String) -> Dictionary:
	var alliance: Dictionary = _find_alliance_by_id(state, alliance_id)
	if alliance.is_empty():
		return {"ok": false, "message": "İttifak bulunamadı."}
	if not is_founder(alliance, editor_name):
		return {"ok": false, "message": "Yalnızca ittifakı kuran lider iç duyuruyu güncelleyebilir."}
	alliance["internal_announcement"] = text.strip_edges()
	alliance["announcement_updated_unix"] = int(Time.get_unix_time_from_system())
	return {"ok": true}


static func search_alliances(state: Dictionary, exclude_alliance_id: int, query: String) -> Array:
	var q := query.strip_edges().to_lower()
	var results: Array = []
	for a in state.get("alliances", []):
		if typeof(a) != TYPE_DICTIONARY:
			continue
		var ad := a as Dictionary
		if int(ad.get("id", -1)) == exclude_alliance_id:
			continue
		if not q.is_empty():
			var nm := str(ad.get("name", "")).to_lower()
			var tg := str(ad.get("tag", "")).to_lower()
			if nm.find(q) < 0 and tg.find(q) < 0:
				continue
		results.append(ad)
	results.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return str(x.get("name", "")).to_lower() < str(y.get("name", "")).to_lower()
	)
	return results


static func _append_unique_tag(arr: Array, tag: String) -> void:
	var clean := tag.strip_edges().to_upper()
	if clean.is_empty():
		return
	for it in arr:
		if str(it).strip_edges().to_upper() == clean:
			return
	arr.append(clean)


static func _remove_tag(arr: Array, tag: String) -> void:
	var clean := tag.strip_edges().to_upper()
	for i in range(arr.size() - 1, -1, -1):
		if str(arr[i]).strip_edges().to_upper() == clean:
			arr.remove_at(i)


static func _has_tag(arr: Array, tag: String) -> bool:
	var clean := tag.strip_edges().to_upper()
	for it in arr:
		if str(it).strip_edges().to_upper() == clean:
			return true
	return false


static func _find_req_by_aid(arr: Array, aid: int, tag: String = "") -> int:
	var clean_tag := tag.strip_edges().to_upper()
	for i in range(arr.size()):
		if typeof(arr[i]) != TYPE_DICTIONARY:
			continue
		var rd := arr[i] as Dictionary
		if aid > 0 and int(rd.get("alliance_id", -1)) == aid:
			return i
		if not clean_tag.is_empty() and str(rd.get("tag", "")).strip_edges().to_upper() == clean_tag:
			return i
	return -1


static func _remove_req_by_aid(arr: Array, aid: int, tag: String = "") -> void:
	var clean_tag := tag.strip_edges().to_upper()
	for i in range(arr.size() - 1, -1, -1):
		if typeof(arr[i]) != TYPE_DICTIONARY:
			continue
		var rd := arr[i] as Dictionary
		var match_id := (aid > 0 and int(rd.get("alliance_id", -1)) == aid)
		var match_tag := (not clean_tag.is_empty() and str(rd.get("tag", "")).strip_edges().to_upper() == clean_tag)
		if match_id or match_tag:
			arr.remove_at(i)


static func _push_sys_chat(alliance: Dictionary, text: String, now_u: int) -> void:
	if typeof(alliance.get("chat_messages")) != TYPE_ARRAY:
		alliance["chat_messages"] = []
	(alliance["chat_messages"] as Array).append({
		"sender": "Sistem",
		"text": text,
		"timestamp_unix": now_u,
	})


static func send_ally_invite(state: Dictionary, from_alliance_id: int, actor_name: String, target_alliance_id: int) -> Dictionary:
	var from_a := _find_alliance_by_id(state, from_alliance_id)
	var target_a := _find_alliance_by_id(state, target_alliance_id)
	if from_a.is_empty() or target_a.is_empty():
		return {"ok": false, "message": "İttifak bulunamadı."}
	if not is_founder(from_a, actor_name):
		return {"ok": false, "message": "Diplomasi yönetimini yalnızca ittifakı kuran lider yapabilir."}
	if from_alliance_id == target_alliance_id:
		return {"ok": false, "message": "Kendi ittifakınıza davet gönderemezsiniz."}

	var f_diplo := _ensure_diplomacy(from_a)
	var t_diplo := _ensure_diplomacy(target_a)
	var from_tag := str(from_a.get("tag", "")).strip_edges().to_upper()
	var from_name := str(from_a.get("name", ""))
	var target_tag := str(target_a.get("tag", "")).strip_edges().to_upper()
	var target_name := str(target_a.get("name", ""))

	if _has_tag(f_diplo["allies"] as Array, target_tag):
		return {"ok": false, "message": "[%s] %s zaten müttefikiniz." % [target_tag, target_name]}
	if _find_req_by_aid(f_diplo["ally_requests_out"] as Array, target_alliance_id, target_tag) >= 0:
		return {"ok": false, "message": "[%s] %s ittifakına zaten bekleyen müttefiklik daveti gönderilmiş." % [target_tag, target_name]}
	if _find_req_by_aid(f_diplo["ally_requests_in"] as Array, target_alliance_id, target_tag) >= 0:
		return respond_ally_invite(state, from_alliance_id, actor_name, target_alliance_id, true)

	var now := int(Time.get_unix_time_from_system())
	(f_diplo["ally_requests_out"] as Array).append({
		"alliance_id": target_alliance_id,
		"tag": target_tag,
		"name": target_name,
		"sent_by": actor_name,
		"created_unix": now,
	})
	(t_diplo["ally_requests_in"] as Array).append({
		"alliance_id": from_alliance_id,
		"tag": from_tag,
		"name": from_name,
		"sent_by": actor_name,
		"created_unix": now,
	})
	from_a["diplomacy_updated_unix"] = now
	target_a["diplomacy_updated_unix"] = now

	var t_leader := str(target_a.get("founder", target_a.get("leader", ""))).strip_edges()
	if not t_leader.is_empty():
		if typeof(state.get("messages")) != TYPE_ARRAY:
			state["messages"] = []
		(state["messages"] as Array).append({
			"id": now * 1000 + 21,
			"from": "[%s] %s (%s)" % [from_tag, from_name, actor_name],
			"to": t_leader,
			"subject": "🤝 Müttefiklik Daveti: [%s] %s" % [from_tag, from_name],
			"body": "Sayın %s,\n\n[%s] %s ittifakı sizinle müttefik olmak istiyor. İttifak > Diplomasi sekmesinden daveti kabul veya reddedebilirsiniz." % [t_leader, from_tag, from_name],
			"created_unix": now,
			"read": false,
		})

	return {"ok": true, "message": "[%s] %s ittifakına müttefiklik daveti gönderildi." % [target_tag, target_name]}


static func cancel_ally_invite(state: Dictionary, from_alliance_id: int, actor_name: String, target_alliance_id: int) -> Dictionary:
	var from_a := _find_alliance_by_id(state, from_alliance_id)
	if from_a.is_empty():
		return {"ok": false, "message": "İttifak bulunamadı."}
	if not is_founder(from_a, actor_name):
		return {"ok": false, "message": "Diplomasi yönetimini yalnızca ittifakı kuran lider yapabilir."}
	var target_a := _find_alliance_by_id(state, target_alliance_id)
	var from_tag := str(from_a.get("tag", "")).strip_edges().to_upper()
	var target_tag := str(target_a.get("tag", "")).strip_edges().to_upper() if not target_a.is_empty() else ""
	var f_diplo := _ensure_diplomacy(from_a)
	_remove_req_by_aid(f_diplo["ally_requests_out"] as Array, target_alliance_id, target_tag)
	var now := int(Time.get_unix_time_from_system())
	from_a["diplomacy_updated_unix"] = now
	if not target_a.is_empty():
		var t_diplo := _ensure_diplomacy(target_a)
		_remove_req_by_aid(t_diplo["ally_requests_in"] as Array, from_alliance_id, from_tag)
		target_a["diplomacy_updated_unix"] = now
	return {"ok": true}


static func respond_ally_invite(state: Dictionary, my_alliance_id: int, actor_name: String, from_alliance_id: int, accept: bool) -> Dictionary:
	var my_a := _find_alliance_by_id(state, my_alliance_id)
	if my_a.is_empty():
		return {"ok": false, "message": "İttifak bulunamadı."}
	if not is_founder(my_a, actor_name):
		return {"ok": false, "message": "Müttefiklik davetlerini yalnızca ittifakı kuran lider yanıtlayabilir."}
	var from_a := _find_alliance_by_id(state, from_alliance_id)
	var my_tag := str(my_a.get("tag", "")).strip_edges().to_upper()
	var my_name := str(my_a.get("name", ""))
	var from_tag := str(from_a.get("tag", "")).strip_edges().to_upper() if not from_a.is_empty() else ""
	var from_name := str(from_a.get("name", "")) if not from_a.is_empty() else ""

	var my_diplo := _ensure_diplomacy(my_a)
	var req_idx := _find_req_by_aid(my_diplo["ally_requests_in"] as Array, from_alliance_id, from_tag)
	if req_idx < 0:
		return {"ok": false, "message": "Bekleyen müttefiklik daveti bulunamadı."}
	if from_tag.is_empty():
		var req_d: Dictionary = (my_diplo["ally_requests_in"] as Array)[req_idx]
		from_tag = str(req_d.get("tag", "")).strip_edges().to_upper()
		from_name = str(req_d.get("name", from_tag))

	_remove_req_by_aid(my_diplo["ally_requests_in"] as Array, from_alliance_id, from_tag)
	_remove_req_by_aid(my_diplo["ally_requests_out"] as Array, from_alliance_id, from_tag)
	var now := int(Time.get_unix_time_from_system())

	if accept:
		_remove_tag(my_diplo["enemies"] as Array, from_tag)
		_append_unique_tag(my_diplo["allies"] as Array, from_tag)
		_push_sys_chat(my_a, "🤝 [%s] %s ittifakı ile müttefik olundu!" % [from_tag, from_name], now)

	my_a["diplomacy_updated_unix"] = now

	if not from_a.is_empty():
		var f_diplo := _ensure_diplomacy(from_a)
		_remove_req_by_aid(f_diplo["ally_requests_out"] as Array, my_alliance_id, my_tag)
		_remove_req_by_aid(f_diplo["ally_requests_in"] as Array, my_alliance_id, my_tag)
		if accept:
			_remove_tag(f_diplo["enemies"] as Array, my_tag)
			_append_unique_tag(f_diplo["allies"] as Array, my_tag)
			_push_sys_chat(from_a, "🤝 [%s] %s müttefiklik davetinizi kabul etti!" % [my_tag, my_name], now)
		from_a["diplomacy_updated_unix"] = now

	return {
		"ok": true,
		"accepted": accept,
		"message": ("[%s] %s ile müttefiklik kuruldu!" if accept else "[%s] %s daveti reddedildi.") % [from_tag, from_name]
	}


static func remove_ally(state: Dictionary, my_alliance_id: int, actor_name: String, target_tag: String) -> Dictionary:
	var my_a := _find_alliance_by_id(state, my_alliance_id)
	if my_a.is_empty():
		return {"ok": false, "message": "İttifak bulunamadı."}
	if not is_founder(my_a, actor_name):
		return {"ok": false, "message": "Diplomasi yönetimini yalnızca ittifakı kuran lider yapabilir."}
	var clean_tag := target_tag.strip_edges().to_upper()
	var my_tag := str(my_a.get("tag", "")).strip_edges().to_upper()
	var my_diplo := _ensure_diplomacy(my_a)
	_remove_tag(my_diplo["allies"] as Array, clean_tag)
	var now := int(Time.get_unix_time_from_system())
	my_a["diplomacy_updated_unix"] = now
	_push_sys_chat(my_a, "💔 [%s] ile müttefiklik sonlandırıldı." % clean_tag, now)

	var target_a := find_by_tag(state, clean_tag)
	if not target_a.is_empty():
		var t_diplo := _ensure_diplomacy(target_a)
		_remove_tag(t_diplo["allies"] as Array, my_tag)
		target_a["diplomacy_updated_unix"] = now
		_push_sys_chat(target_a, "💔 [%s] %s müttefikliği sonlandırdı." % [my_tag, str(my_a.get("name", ""))], now)
	return {"ok": true}


static func declare_enemy(state: Dictionary, from_alliance_id: int, actor_name: String, target_alliance_id: int) -> Dictionary:
	var from_a := _find_alliance_by_id(state, from_alliance_id)
	var target_a := _find_alliance_by_id(state, target_alliance_id)
	if from_a.is_empty() or target_a.is_empty():
		return {"ok": false, "message": "İttifak bulunamadı."}
	if not is_founder(from_a, actor_name):
		return {"ok": false, "message": "Diplomasi yönetimini yalnızca ittifakı kuran lider yapabilir."}
	if from_alliance_id == target_alliance_id:
		return {"ok": false, "message": "Kendi ittifakınızı düşman ilan edemezsiniz."}

	var from_tag := str(from_a.get("tag", "")).strip_edges().to_upper()
	var from_name := str(from_a.get("name", ""))
	var target_tag := str(target_a.get("tag", "")).strip_edges().to_upper()
	var target_name := str(target_a.get("name", ""))
	var now := int(Time.get_unix_time_from_system())

	var f_diplo := _ensure_diplomacy(from_a)
	_remove_tag(f_diplo["allies"] as Array, target_tag)
	_remove_req_by_aid(f_diplo["ally_requests_out"] as Array, target_alliance_id, target_tag)
	_remove_req_by_aid(f_diplo["ally_requests_in"] as Array, target_alliance_id, target_tag)
	_append_unique_tag(f_diplo["enemies"] as Array, target_tag)
	from_a["diplomacy_updated_unix"] = now
	_push_sys_chat(from_a, "⚔️ [%s] %s ittifakı düşman ilan edildi!" % [target_tag, target_name], now)

	var t_diplo := _ensure_diplomacy(target_a)
	_remove_tag(t_diplo["allies"] as Array, from_tag)
	_remove_req_by_aid(t_diplo["ally_requests_in"] as Array, from_alliance_id, from_tag)
	_remove_req_by_aid(t_diplo["ally_requests_out"] as Array, from_alliance_id, from_tag)
	_append_unique_tag(t_diplo["enemies"] as Array, from_tag)
	target_a["diplomacy_updated_unix"] = now
	_push_sys_chat(target_a, "🚨 [%s] %s ittifakı sizi düşman ittifak ilan etti! Saldırılara karşı dikkatli olun." % [from_tag, from_name], now)

	# Karşı ittifaktaki TÜM üyelere mesaj kutusu uyarısı gönder
	if typeof(state.get("messages")) != TYPE_ARRAY:
		state["messages"] = []
	var msgs_arr: Array = state["messages"]
	var members: Array = target_a.get("members", []) if typeof(target_a.get("members")) == TYPE_ARRAY else []
	for idx in range(members.size()):
		var m = members[idx]
		var m_name := str((m as Dictionary).get("name", "")) if typeof(m) == TYPE_DICTIONARY else str(m)
		m_name = m_name.strip_edges()
		if m_name.is_empty():
			continue
		msgs_arr.append({
			"id": now * 1000 + 100 + idx,
			"from": "[%s] %s (Diplomasi)" % [from_tag, from_name],
			"to": m_name,
			"subject": "⚔️ Düşman İlanı: [%s] %s" % [from_tag, from_name],
			"body": "Dikkat Sayın %s,\n\n[%s] %s ittifakı ittifakınızı düşman ittifak ilan etti. Saldırılara karşı dikkatli olun ve köy savunmanızı güçlendirin!" % [m_name, from_tag, from_name],
			"created_unix": now,
			"read": false,
		})

	return {"ok": true, "message": "[%s] %s düşman ilan edildi ve tüm üyelerine uyarı gönderildi." % [target_tag, target_name]}


static func remove_enemy(state: Dictionary, my_alliance_id: int, actor_name: String, target_tag: String) -> Dictionary:
	var my_a := _find_alliance_by_id(state, my_alliance_id)
	if my_a.is_empty():
		return {"ok": false, "message": "İttifak bulunamadı."}
	if not is_founder(my_a, actor_name):
		return {"ok": false, "message": "Diplomasi yönetimini yalnızca ittifakı kuran lider yapabilir."}
	var clean_tag := target_tag.strip_edges().to_upper()
	var my_tag := str(my_a.get("tag", "")).strip_edges().to_upper()
	var my_diplo := _ensure_diplomacy(my_a)
	_remove_tag(my_diplo["enemies"] as Array, clean_tag)
	var now := int(Time.get_unix_time_from_system())
	my_a["diplomacy_updated_unix"] = now
	_push_sys_chat(my_a, "🏳️ [%s] ittifakı ile düşmanlık kaldırıldı." % clean_tag, now)

	var target_a := find_by_tag(state, clean_tag)
	if not target_a.is_empty():
		var t_diplo := _ensure_diplomacy(target_a)
		_remove_tag(t_diplo["enemies"] as Array, my_tag)
		target_a["diplomacy_updated_unix"] = now
	return {"ok": true}


## Diplomasi ilişkisi ekler veya kaldırır (docs/12 §7 — Saldırmazlık Paktı kaldırılmıştır).
## relation_type: "allies" | "enemies" | "none"
static func set_diplomacy(
	state: Dictionary,
	alliance_id: int,
	target_tag: String,
	relation_type: String
) -> Dictionary:
	var alliance: Dictionary = _find_alliance_by_id(state, alliance_id)
	if alliance.is_empty():
		return {"ok": false, "message": "İttifak bulunamadı."}
	if relation_type == "nap":
		return {"ok": false, "message": "Saldırmazlık Paktı kaldırılmıştır."}

	var clean_tag := target_tag.strip_edges().to_upper()
	if clean_tag == str(alliance.get("tag", "")).to_upper():
		return {"ok": false, "message": "Kendi ittifakınızla diplomasi yapamazsınız."}

	var diplo := _ensure_diplomacy(alliance)
	for list_key in ["allies", "enemies"]:
		_remove_tag(diplo[list_key] as Array, clean_tag)

	if relation_type != "none" and diplo.has(relation_type):
		_append_unique_tag(diplo[relation_type] as Array, clean_tag)

	alliance["diplomacy"] = diplo
	alliance["diplomacy_updated_unix"] = int(Time.get_unix_time_from_system())
	return {"ok": true}


# --- Yardımcılar -------------------------------------------------------------

static func _find_alliance_by_id(state: Dictionary, aid: int) -> Dictionary:
	for a in state.get("alliances", []):
		if typeof(a) == TYPE_DICTIONARY and int((a as Dictionary).get("id", -1)) == aid:
			return a as Dictionary
	return {}


static func _calculate_player_points(state: Dictionary, p_name: String) -> int:
	var total := 0
	for v in state.get("villages", []):
		if typeof(v) == TYPE_DICTIONARY and str((v as Dictionary).get("owner", "")) == p_name:
			total += int((v as Dictionary).get("points", 0))
	return maxi(total, 110)


static func _remove_player_join_requests_everywhere(state: Dictionary, player_name: String) -> void:
	var target_l := player_name.strip_edges().to_lower()
	if target_l.is_empty():
		return
	var now := int(Time.get_unix_time_from_system())
	for a in state.get("alliances", []):
		if typeof(a) != TYPE_DICTIONARY:
			continue
		var ad := a as Dictionary
		var jrs = ad.get("join_requests", [])
		if typeof(jrs) != TYPE_ARRAY:
			continue
		var arr := jrs as Array
		var removed := false
		for i in range(arr.size() - 1, -1, -1):
			if typeof(arr[i]) == TYPE_DICTIONARY and str((arr[i] as Dictionary).get("player_name", "")).strip_edges().to_lower() == target_l:
				arr.remove_at(i)
				removed = true
		if removed:
			ad["join_requests_updated_unix"] = now


static func has_pending_join_request(alliance: Dictionary, player_name: String) -> bool:
	var target_l := player_name.strip_edges().to_lower()
	if target_l.is_empty() or alliance.is_empty():
		return false
	var jrs = alliance.get("join_requests", [])
	if typeof(jrs) != TYPE_ARRAY:
		return false
	for r in (jrs as Array):
		if typeof(r) == TYPE_DICTIONARY and str((r as Dictionary).get("player_name", "")).strip_edges().to_lower() == target_l:
			return true
	return false


static func get_pending_join_request_count(state: Dictionary, player_name: String) -> int:
	var alliance := get_player_alliance(state, player_name)
	if alliance.is_empty() or not is_leader(alliance, player_name):
		return 0
	var jrs = alliance.get("join_requests", [])
	return (jrs as Array).size() if typeof(jrs) == TYPE_ARRAY else 0


static func request_join_alliance(state: Dictionary, player_name: String, alliance_id: int) -> Dictionary:
	var clean_p := player_name.strip_edges()
	if clean_p.is_empty():
		return {"ok": false, "message": "Oyuncu adı bulunamadı."}
	if not get_player_alliance(state, clean_p).is_empty():
		return {"ok": false, "message": "Zaten bir ittifak üyesisiniz."}
	var alliance := _find_alliance_by_id(state, alliance_id)
	if alliance.is_empty():
		return {"ok": false, "message": "İttifak bulunamadı."}
	if typeof(alliance.get("join_requests")) != TYPE_ARRAY:
		alliance["join_requests"] = []
	if has_pending_join_request(alliance, clean_p):
		return {"ok": false, "message": "Bu ittifaka zaten bekleyen bir isteğiniz var."}

	var now := int(Time.get_unix_time_from_system())
	var pts := _calculate_player_points(state, clean_p)
	(alliance["join_requests"] as Array).append({
		"player_name": clean_p,
		"points": pts,
		"created_unix": now,
	})
	alliance["join_requests_updated_unix"] = now

	var leader_n := str(alliance.get("leader", "")).strip_edges()
	if not leader_n.is_empty():
		if typeof(state.get("messages")) != TYPE_ARRAY:
			state["messages"] = []
		(state["messages"] as Array).append({
			"id": now * 1000 + 37,
			"from": clean_p,
			"to": leader_n,
			"subject": "📩 Katılma İsteği: [%s] %s" % [str(alliance.get("tag", "")), clean_p],
			"body": "Sayın %s,\n\n%s (%d Puan) [%s] %s ittifakınıza katılmak istiyor. İttifak > Davet & İstekler sekmesinden profilini inceleyip onaylayabilir veya reddedebilirsiniz." % [
				leader_n, clean_p, pts, str(alliance.get("tag", "")), str(alliance.get("name", ""))
			],
			"created_unix": now,
			"read": false,
		})

	return {"ok": true, "message": "[%s] %s ittifakına katılma isteği gönderildi." % [str(alliance.get("tag", "")), str(alliance.get("name", ""))]}


static func cancel_join_request(state: Dictionary, player_name: String, alliance_id: int) -> Dictionary:
	var alliance := _find_alliance_by_id(state, alliance_id)
	if alliance.is_empty():
		return {"ok": false, "message": "İttifak bulunamadı."}
	var target_l := player_name.strip_edges().to_lower()
	var jrs = alliance.get("join_requests", [])
	if typeof(jrs) != TYPE_ARRAY:
		return {"ok": false, "message": "Bekleyen istek bulunamadı."}
	var arr := jrs as Array
	for i in range(arr.size() - 1, -1, -1):
		if typeof(arr[i]) == TYPE_DICTIONARY and str((arr[i] as Dictionary).get("player_name", "")).strip_edges().to_lower() == target_l:
			arr.remove_at(i)
			alliance["join_requests_updated_unix"] = int(Time.get_unix_time_from_system())
			return {"ok": true, "message": "Katılma isteği iptal edildi."}
	return {"ok": false, "message": "Bekleyen istek bulunamadı."}


static func respond_join_request(
	state: Dictionary,
	alliance_id: int,
	leader_name: String,
	applicant_name: String,
	accept: bool
) -> Dictionary:
	var alliance := _find_alliance_by_id(state, alliance_id)
	if alliance.is_empty():
		return {"ok": false, "message": "İttifak bulunamadı."}
	if not is_leader(alliance, leader_name):
		return {"ok": false, "message": "Katılma isteklerini yalnızca ittifak lideri yanıtlayabilir."}
	var jrs = alliance.get("join_requests", [])
	if typeof(jrs) != TYPE_ARRAY:
		return {"ok": false, "message": "Bekleyen katılma isteği bulunamadı."}
	var app_clean := applicant_name.strip_edges()
	var app_l := app_clean.to_lower()
	var arr := jrs as Array
	var found_idx := -1
	var req_dict: Dictionary = {}
	for i in range(arr.size()):
		if typeof(arr[i]) == TYPE_DICTIONARY and str((arr[i] as Dictionary).get("player_name", "")).strip_edges().to_lower() == app_l:
			found_idx = i
			req_dict = arr[i] as Dictionary
			app_clean = str(req_dict.get("player_name", app_clean))
			break
	if found_idx < 0:
		return {"ok": false, "message": "Başvuru bulunamadı."}

	arr.remove_at(found_idx)
	var now := int(Time.get_unix_time_from_system())
	alliance["join_requests_updated_unix"] = now

	if not accept:
		if typeof(state.get("messages")) != TYPE_ARRAY:
			state["messages"] = []
		(state["messages"] as Array).append({
			"id": now * 1000 + 39,
			"from": "%s ([%s])" % [leader_name, str(alliance.get("tag", ""))],
			"to": app_clean,
			"subject": "❌ İttifak Başvurusu Reddedildi",
			"body": "Sayın %s,\n\n[%s] %s ittifakına yaptığınız katılma isteği ittifak lideri tarafından reddedildi." % [
				app_clean, str(alliance.get("tag", "")), str(alliance.get("name", ""))
			],
			"created_unix": now,
			"read": false,
		})
		return {"ok": true, "accepted": false, "message": "%s başvurusu reddedildi." % app_clean}

	if not get_player_alliance(state, app_clean).is_empty():
		return {"ok": false, "message": "%s zaten başka bir ittifaka katılmış." % app_clean}

	_remove_player_join_requests_everywhere(state, app_clean)
	var invs = alliance.get("invitations", [])
	if typeof(invs) == TYPE_ARRAY:
		var inv_arr := invs as Array
		for ii in range(inv_arr.size() - 1, -1, -1):
			if typeof(inv_arr[ii]) == TYPE_DICTIONARY and str((inv_arr[ii] as Dictionary).get("player_name", "")).strip_edges().to_lower() == app_l:
				inv_arr.remove_at(ii)

	var pts := _calculate_player_points(state, app_clean)
	(alliance["members"] as Array).append({
		"name": app_clean,
		"rank": "member",
		"rank_title": "Savaşçı",
		"points": pts,
		"is_leader": false,
		"joined_unix": now,
		"rights": {"invitations": false, "diplomacy": false, "alliance_leader": false, "circular_mail": false}
	})
	_push_sys_chat(alliance, "🎉 %s katılma isteğiyle ittifaka katıldı!" % app_clean, now)
	return {"ok": true, "accepted": true, "message": "%s ittifaka kabul edildi!" % app_clean}
