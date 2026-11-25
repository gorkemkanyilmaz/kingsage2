extends RefCounted
## IncomingAttackAlert — Düşman saldırısı algılama, Baş Vezir panik uyarısı ve canlı geri sayım yardımcısı.

const TexVizier := preload("res://assets/sprites/ui/tutorial/vizier_portrait.png")
const FontCinzelBold := preload("res://assets/fonts/Cinzel-Bold.ttf")
const FontNunitoBold := preload("res://assets/fonts/Nunito-Bold.ttf")
const FontNunitoSemiBold := preload("res://assets/fonts/Nunito-SemiBold.ttf")

const LAYER_NAME := "VizierAttackAlertLayer"

static var _acked_sigs: Dictionary = {}


static func reset_ack_state() -> void:
	_acked_sigs.clear()


static func _norm_name(raw_name: String) -> String:
	var n := raw_name.strip_edges()
	while n.length() >= 10 and n.substr(0, 10).to_lower() == "lord lord ":
		n = n.substr(5).strip_edges()
	return n.to_lower()


static func _scene_tree(host: Node = null) -> SceneTree:
	if host != null and host.is_inside_tree() and host.get_tree() != null:
		return host.get_tree()
	var loop := Engine.get_main_loop()
	return loop as SceneTree if loop is SceneTree else null


static func get_incoming_attacks(gs: Node, now_unix: int, only_village_id: int = -1) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if gs == null:
		return result
	var movs = gs.get("movements")
	if typeof(movs) != TYPE_ARRAY or (movs as Array).is_empty():
		return result

	var player_dict: Dictionary = gs.get("player") if typeof(gs.get("player")) == TYPE_DICTIONARY else {}
	var p_norm := _norm_name(str(player_dict.get("name", "")))
	var active_vid := int(gs.get("active_village_id"))

	var owned_vids: Dictionary = {}
	var village_by_id: Dictionary = {}
	if active_vid > 0:
		owned_vids[active_vid] = true

	var vills = gs.get("villages")
	if typeof(vills) == TYPE_ARRAY:
		for raw_v in (vills as Array):
			if typeof(raw_v) != TYPE_DICTIONARY:
				continue
			var vd := raw_v as Dictionary
			var vid := int(vd.get("id", -1))
			if vid > 0:
				village_by_id[vid] = vd
			if bool(vd.get("is_bot", false)) or bool(vd.get("is_barbarian", false)):
				continue
			var v_owner := _norm_name(str(vd.get("owner", "")))
			if not p_norm.is_empty() and not v_owner.is_empty() and v_owner == p_norm:
				owned_vids[vid] = true

	if owned_vids.is_empty():
		return result

	var returned_origin_keys: Dictionary = {}
	var returned_seed_keys: Dictionary = {}
	for raw_m in (movs as Array):
		if typeof(raw_m) != TYPE_DICTIONARY:
			continue
		var md := raw_m as Dictionary
		if str(md.get("state", "")) == "returning" or str(md.get("type", "")) == "return":
			var ret_home_vid := int(md.get("to_village_id", md.get("village_id", 0)))
			var omid := int(md.get("origin_movement_id", 0))
			if omid > 0:
				returned_origin_keys["%d:%d" % [ret_home_vid, omid]] = true
			var bseed := int(md.get("battle_seed", 0))
			if bseed > 0:
				returned_seed_keys["%d:%d" % [ret_home_vid, bseed]] = true

	var seen_sigs: Dictionary = {}
	for raw_m in (movs as Array):
		if typeof(raw_m) != TYPE_DICTIONARY:
			continue
		var m := raw_m as Dictionary
		var m_type := str(m.get("type", ""))
		var m_state := str(m.get("state", ""))
		if m_state != "outgoing":
			continue
		if not (m_type in ["attack", "raid", "spy"]):
			continue
		if m_type == "spy" and bool(m.get("creeping", false)):
			continue

		var to_id := int(m.get("to_village_id", -1))
		var from_id := int(m.get("from_village_id", -1))
		if to_id <= 0 or not owned_vids.has(to_id):
			continue
		if only_village_id > 0 and to_id != only_village_id:
			continue
		if from_id == to_id or (from_id > 0 and owned_vids.has(from_id)):
			continue
		var m_owner := _norm_name(str(m.get("owner", "")))
		if not p_norm.is_empty() and not m_owner.is_empty() and m_owner == p_norm:
			continue

		var mid := int(m.get("id", 0))
		var bseed := int(m.get("battle_seed", 0))
		if (mid > 0 and returned_origin_keys.has("%d:%d" % [from_id, mid])) or (bseed > 0 and returned_seed_keys.has("%d:%d" % [from_id, bseed])):
			continue

		var arr_u := int(m.get("arrive_unix", 0))
		if arr_u <= now_unix:
			continue
		var dep_u := int(m.get("depart_unix", now_unix))
		var rem_sec := maxi(0, arr_u - now_unix)
		var rem_min := maxi(1, int(ceil(float(rem_sec) / 60.0)))
		var sig := "%d_%d_%d_%d" % [mid, from_id, to_id, arr_u]
		if seen_sigs.has(sig):
			continue
		seen_sigs[sig] = true

		var from_v: Dictionary = village_by_id.get(from_id, {})
		var to_v: Dictionary = village_by_id.get(to_id, {})
		var attacker_name := str(m.get("owner", from_v.get("owner", "Düşman Lord"))).strip_edges()
		if attacker_name.is_empty():
			attacker_name = "Düşman Lord"
		var from_v_name := str(from_v.get("name", "Köy #%d" % from_id))
		var from_x := int(m.get("from_x", from_v.get("x", 0)))
		var from_y := int(m.get("from_y", from_v.get("y", 0)))
		var to_v_name := str(to_v.get("name", "Köyünüz"))

		result.append({
			"sig": sig,
			"id": mid,
			"type": m_type,
			"from_village_id": from_id,
			"to_village_id": to_id,
			"depart_unix": dep_u,
			"arrive_unix": arr_u,
			"remaining_sec": rem_sec,
			"remaining_min": rem_min,
			"attacker_name": attacker_name,
			"from_village_name": from_v_name,
			"from_coords": "(%d|%d)" % [from_x, from_y],
			"to_village_name": to_v_name,
			"is_active_village": (to_id == active_vid),
		})

	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("arrive_unix", 0)) < int(b.get("arrive_unix", 0))
	)
	return result


static func has_unacknowledged(incoming: Array[Dictionary]) -> bool:
	for item in incoming:
		var sig := str(item.get("sig", ""))
		if not sig.is_empty() and not _acked_sigs.has(sig):
			return true
	return false


static func acknowledge_all(incoming: Array[Dictionary]) -> void:
	for item in incoming:
		var sig := str(item.get("sig", ""))
		if not sig.is_empty():
			_acked_sigs[sig] = true


static func fmt_countdown(secs: int) -> String:
	var s := maxi(0, secs)
	var h := s / 3600
	var m := (s % 3600) / 60
	var rem := s % 60
	if h > 0:
		return "%02d:%02d:%02d" % [h, m, rem]
	return "%02d:%02d" % [m, rem]


static func format_vizier_bbcode(incoming: Array[Dictionary]) -> String:
	if incoming.is_empty():
		return ""
	var first := incoming[0]
	var rem_sec := int(first.get("remaining_sec", 0))
	var rem_min := int(first.get("remaining_min", 1))
	var att_type := str(first.get("type", "attack"))
	var kind_label := "Casus Seferi" if att_type == "spy" else ("Talan Saldırısı" if att_type == "raid" else "Kuşatma Saldırısı")

	var time_line := ""
	if rem_sec < 60:
		time_line = "[b][color=#FF4D4D]⏳ Saldırının ulaşmasına 1 dakikadan az (%d saniye) kaldı![/color][/b]" % rem_sec
	else:
		time_line = "[b][color=#FFD86B]⏳ Saldırının ulaşmasına %d dakika kaldı (%s).[/color][/b]" % [rem_min, fmt_countdown(rem_sec)]

	var multi_line := ""
	if incoming.size() > 1:
		multi_line = "\n[color=#FF9999]⚠️ Toplam %d düşman ordusu köylerinize ilerliyor![/color]" % incoming.size()

	return (
		"[b][color=#FF5555]Lordum, size yaklaşan bir saldırı var![/color][/b]\n\n"
		+ time_line
		+ "\n\n"
		+ "[color=#EFE6D5]• [b]Saldıran:[/b] %s (%s %s)\n" % [str(first.get("attacker_name", "Düşman")), str(first.get("from_village_name", "")), str(first.get("from_coords", ""))]
		+ "• [b]Hedef Köy:[/b] %s (%s)[/color]" % [str(first.get("to_village_name", "Köyünüz")), kind_label]
		+ multi_line
		+ "\n\n[color=#D8CCB8][i]Derhal Sur ve Kışla savunmanızı güçlendirin, gerekirse ittifaktan destek isteyin![/i][/color]"
	)


static func get_open_modal(host: Node = null) -> CanvasLayer:
	var tree := _scene_tree(host)
	if tree == null or tree.root == null:
		return null
	var root_target := tree.current_scene if tree.current_scene != null else tree.root
	var found := root_target.get_node_or_null(LAYER_NAME) as CanvasLayer
	if found == null and tree.root != root_target:
		found = tree.root.get_node_or_null(LAYER_NAME) as CanvasLayer
	return found


static func close_modal(host: Node = null) -> void:
	var existing := get_open_modal(host)
	if existing != null and is_instance_valid(existing):
		existing.queue_free()


static func show_modal(host: Node, incoming: Array[Dictionary], is_on_village: bool = true) -> CanvasLayer:
	if incoming.is_empty():
		close_modal(host)
		return null
	var tree := _scene_tree(host)
	if tree == null or tree.root == null:
		return null
	var root_target := tree.current_scene if tree.current_scene != null else tree.root

	acknowledge_all(incoming)

	var existing := get_open_modal(host)
	if existing != null and is_instance_valid(existing):
		var body_existing := existing.find_child("VizierAlertBody", true, false) as RichTextLabel
		if body_existing != null:
			body_existing.text = format_vizier_bbcode(incoming)
		return existing

	var layer := CanvasLayer.new()
	layer.name = LAYER_NAME
	layer.layer = 132
	root_target.add_child(layer)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.14, 0.01, 0.01, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)

	var vp_size := tree.root.get_visible_rect().size
	if vp_size.x < 100.0:
		vp_size = Vector2(1080.0, 1920.0)
	var card_w := clampf(vp_size.x - 64.0, 620.0, 880.0)
	var inner_w := card_w - 56.0
	var text_w := maxf(300.0, inner_w - 156.0)

	var card := PanelContainer.new()
	card.name = "VizierAlertCard"
	card.custom_minimum_size = Vector2(card_w, 0.0)
	card.size = Vector2(card_w, 0.0)
	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color = Color(0.13, 0.05, 0.06, 0.99)
	card_sb.border_color = Color(0.98, 0.24, 0.20, 0.98)
	card_sb.set_border_width_all(3)
	card_sb.border_width_top = 6
	card_sb.set_corner_radius_all(20)
	card_sb.content_margin_left = 28
	card_sb.content_margin_right = 28
	card_sb.content_margin_top = 24
	card_sb.content_margin_bottom = 24
	card_sb.shadow_color = Color(0.75, 0.04, 0.04, 0.78)
	card_sb.shadow_size = 0
	card.add_theme_stylebox_override("panel", card_sb)
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	card.add_child(vb)

	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 12)
	vb.add_child(hdr)

	var title := Label.new()
	title.name = "VizierAlertTitle"
	title.text = "🚨 BAŞ VEZİR — ACİL SALDIRI ALARMI!"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.custom_minimum_size = Vector2(inner_w - 60.0, 0.0)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_override("font", FontCinzelBold)
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", Color(1.0, 0.42, 0.36))
	title.add_theme_constant_override("outline_size", 2)
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.01, 0.01, 0.95))
	hdr.add_child(title)

	var close_x := Button.new()
	close_x.text = "✕"
	close_x.custom_minimum_size = Vector2(46, 46)
	var x_sb := StyleBoxFlat.new()
	x_sb.bg_color = Color(0.38, 0.12, 0.12, 0.96)
	x_sb.border_color = Color(0.95, 0.40, 0.35, 0.95)
	x_sb.set_border_width_all(2)
	x_sb.set_corner_radius_all(10)
	close_x.add_theme_stylebox_override("normal", x_sb)
	close_x.add_theme_font_override("font", FontNunitoBold)
	close_x.add_theme_font_size_override("font_size", 22)
	close_x.add_theme_color_override("font_color", Color(1.0, 0.92, 0.92))
	close_x.pressed.connect(func():
		if is_instance_valid(layer):
			layer.queue_free()
	)
	hdr.add_child(close_x)

	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 18)
	vb.add_child(mid)

	var port_frame := PanelContainer.new()
	port_frame.custom_minimum_size = Vector2(138, 138)
	port_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var p_sb := StyleBoxFlat.new()
	p_sb.bg_color = Color(0.10, 0.05, 0.06, 0.98)
	p_sb.border_color = Color(0.95, 0.72, 0.28, 0.96)
	p_sb.set_border_width_all(3)
	p_sb.set_corner_radius_all(16)
	p_sb.set_content_margin_all(4)
	port_frame.add_theme_stylebox_override("panel", p_sb)
	mid.add_child(port_frame)

	var portrait := TextureRect.new()
	portrait.texture = TexVizier
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.custom_minimum_size = Vector2(126, 126)
	port_frame.add_child(portrait)

	var body_rtl := RichTextLabel.new()
	body_rtl.name = "VizierAlertBody"
	body_rtl.bbcode_enabled = true
	body_rtl.fit_content = true
	body_rtl.scroll_active = false
	body_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_rtl.custom_minimum_size = Vector2(text_w, 0.0)
	body_rtl.size = Vector2(text_w, 0.0)
	body_rtl.add_theme_font_override("normal_font", FontNunitoSemiBold)
	body_rtl.add_theme_font_override("bold_font", FontNunitoBold)
	body_rtl.add_theme_font_size_override("normal_font_size", 22)
	body_rtl.add_theme_font_size_override("bold_font_size", 24)
	body_rtl.add_theme_color_override("default_color", Color(0.96, 0.92, 0.86))
	body_rtl.text = format_vizier_bbcode(incoming)
	mid.add_child(body_rtl)

	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_END
	btns.add_theme_constant_override("separation", 12)
	vb.add_child(btns)

	var nav_btn := Button.new()
	nav_btn.name = "BtnInspectIncoming"
	nav_btn.custom_minimum_size = Vector2(220, 52)
	nav_btn.text = "🗺️ Haritada Gör" if is_on_village else "🏰 Köye Dön & Savun"
	var nav_sb := StyleBoxFlat.new()
	nav_sb.bg_color = Color(0.16, 0.24, 0.40, 0.98)
	nav_sb.border_color = Color(0.92, 0.76, 0.34, 0.96)
	nav_sb.set_border_width_all(2)
	nav_sb.set_corner_radius_all(12)
	nav_btn.add_theme_stylebox_override("normal", nav_sb)
	nav_btn.add_theme_font_override("font", FontNunitoBold)
	nav_btn.add_theme_font_size_override("font_size", 21)
	nav_btn.add_theme_color_override("font_color", Color(0.98, 0.95, 0.86))
	nav_btn.pressed.connect(func():
		if is_instance_valid(layer):
			layer.queue_free()
		var t := _scene_tree(host)
		if t != null:
			t.change_scene_to_file("res://scenes/WorldMap.tscn" if is_on_village else "res://scenes/Village.tscn")
	)
	btns.add_child(nav_btn)

	var ok_btn := Button.new()
	ok_btn.name = "BtnAckAttackAlert"
	ok_btn.custom_minimum_size = Vector2(260, 52)
	ok_btn.text = "🛡️ Savunmaya Geç (Anladım)"
	var ok_sb := StyleBoxFlat.new()
	ok_sb.bg_color = Color(0.72, 0.14, 0.14, 0.98)
	ok_sb.border_color = Color(1.0, 0.65, 0.38, 0.98)
	ok_sb.set_border_width_all(2)
	ok_sb.set_corner_radius_all(12)
	ok_btn.add_theme_stylebox_override("normal", ok_sb)
	ok_btn.add_theme_font_override("font", FontNunitoBold)
	ok_btn.add_theme_font_size_override("font_size", 21)
	ok_btn.add_theme_color_override("font_color", Color(1.0, 0.97, 0.92))
	ok_btn.pressed.connect(func():
		if is_instance_valid(layer):
			layer.queue_free()
	)
	btns.add_child(ok_btn)

	var timer := Timer.new()
	timer.wait_time = 0.5
	timer.one_shot = false
	timer.timeout.connect(func():
		if not is_instance_valid(layer) or not is_instance_valid(body_rtl):
			return
		var t := _scene_tree(layer)
		if t == null or t.root == null:
			return
		var gs_node := t.root.get_node_or_null("GameState")
		if gs_node == null:
			return
		var now_u := int(Time.get_unix_time_from_system())
		var gl_loop := load("res://scripts/core/GameLoop.gd")
		if gl_loop != null and gl_loop.instance != null and gl_loop.instance.has_method("now_unix"):
			var gl_u := int(gl_loop.instance.now_unix())
			if gl_u > 0:
				now_u = gl_u
		var live_inc := get_incoming_attacks(gs_node, now_u)
		if live_inc.is_empty():
			layer.queue_free()
			return
		body_rtl.text = format_vizier_bbcode(live_inc)
		acknowledge_all(live_inc)
	)
	layer.add_child(timer)
	timer.start()

	return layer
