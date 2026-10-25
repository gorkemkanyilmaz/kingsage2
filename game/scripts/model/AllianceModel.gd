class_name AllianceModel
extends RefCounted
## AllianceModel — İttifak sistemi veri modeli ve kuralları (docs/12-ITTIFAKLAR.md).
##
## Forum YOKTUR; bunun yerine canlı İttifak İçi Sohbet (Alliance Chat),
## iç duyurular, davet/katılma, üye yönetimi ve diplomasi bulunur.

const MAX_TAG_LENGTH := 6


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
		"internal_announcement": " İttifakımıza hoş geldiniz! Birlikte güçlüyüz.",
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
		"chat_messages": [
			{
				"sender": "Sistem",
				"text": " [%s] %s ittifakı kuruldu!" % [clean_tag, clean_name],
				"timestamp_unix": now
			}
		],
		"diplomacy": {
			"allies": [],
			"nap": [],
			"enemies": []
		}
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


## İç duyuruyu günceller (docs/12 §4).
static func update_announcement(state: Dictionary, alliance_id: int, editor_name: String, text: String) -> Dictionary:
	var alliance: Dictionary = _find_alliance_by_id(state, alliance_id)
	if alliance.is_empty():
		return {"ok": false, "message": "İttifak bulunamadı."}
	alliance["internal_announcement"] = text.strip_edges()
	return {"ok": true}


## Diplomasi ilişkisi ekler veya kaldırır (docs/12 §7).
## relation_type: "allies" | "nap" | "enemies" | "none"
static func set_diplomacy(
	state: Dictionary,
	alliance_id: int,
	target_tag: String,
	relation_type: String
) -> Dictionary:
	var alliance: Dictionary = _find_alliance_by_id(state, alliance_id)
	if alliance.is_empty():
		return {"ok": false, "message": "İttifak bulunamadı."}

	var clean_tag := target_tag.strip_edges().to_upper()
	if clean_tag == str(alliance.get("tag", "")).to_upper():
		return {"ok": false, "message": "Kendi ittifakınızla diplomasi yapamazsınız."}

	var diplo: Dictionary = alliance.get("diplomacy", {})
	for list_key in ["allies", "nap", "enemies"]:
		if typeof(diplo.get(list_key)) != TYPE_ARRAY:
			diplo[list_key] = []
		var arr: Array = diplo[list_key]
		var idx := arr.find(clean_tag)
		if idx >= 0:
			arr.remove_at(idx)

	if relation_type != "none" and diplo.has(relation_type):
		(diplo[relation_type] as Array).append(clean_tag)

	alliance["diplomacy"] = diplo
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
