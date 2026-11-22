extends Control
## Settings — Ayarlar ve Hesap Yönetimi Ekranı (Taht ve Kılıç / Royal Dark-Gold Tema).

const FontCinzelBold: Font = preload("res://assets/fonts/Cinzel-Bold.ttf")
const FontNunitoBold: Font = preload("res://assets/fonts/Nunito-Bold.ttf")
const FontNunitoSemiBold: Font = preload("res://assets/fonts/Nunito-SemiBold.ttf")

@onready var resource_bar: Control = get_node_or_null("ResourceBar") as Control
@onready var header_panel: Control = get_node_or_null("Header") as Control
@onready var scroll_center: ScrollContainer = get_node_or_null("Center") as ScrollContainer
@onready var profile_option: OptionButton = find_child("Option", true, false) as OptionButton
@onready var account_info_lbl: Label = find_child("AccountInfo", true, false) as Label
@onready var btn_logout: Button = find_child("BtnLogout", true, false) as Button
@onready var btn_back: Button = find_child("BtnBack", true, false) as Button
@onready var btn_main_menu: Button = find_child("BtnMainMenu", true, false) as Button
@onready var btn_delete_account: Button = find_child("BtnDeleteAccount", true, false) as Button
@onready var bottom_nav: Control = get_node_or_null("BottomNav") as Control

var _delete_modal: CanvasLayer = null


func _autoload(node_name: String) -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree and (loop as SceneTree).root != null:
		return (loop as SceneTree).root.get_node_or_null(node_name)
	return null


func _ready() -> void:
	_apply_royal_styles()
	_sync_layout_bounds()
	if not resized.is_connected(_sync_layout_bounds):
		resized.connect(_sync_layout_bounds)
	if resource_bar != null and not resource_bar.resized.is_connected(_sync_layout_bounds):
		resource_bar.resized.connect(_sync_layout_bounds)

	_refresh_account_info()

	if profile_option != null:
		profile_option.clear()
		profile_option.add_item("Türkiye (TR) — Gece Bonusu 00:00-06:00, Kont 80 Alan", 0)
		profile_option.add_item("Global (EN) — Gece Bonusu Yok, Kont 100 Alan", 1)
		_style_option_button(profile_option)
		var cfg := _autoload("GameConfig")
		if cfg != null:
			var prof: String = str(cfg.get("current_profile"))
			profile_option.selected = 1 if prof == "en" else 0
		if not profile_option.item_selected.is_connected(_on_profile_selected):
			profile_option.item_selected.connect(_on_profile_selected)

	if btn_logout != null and not btn_logout.pressed.is_connected(_on_btn_logout_pressed):
		btn_logout.pressed.connect(_on_btn_logout_pressed)

	if btn_back != null and not btn_back.pressed.is_connected(_on_btn_back_pressed):
		btn_back.pressed.connect(_on_btn_back_pressed)

	if btn_main_menu != null and not btn_main_menu.pressed.is_connected(_on_btn_main_menu_pressed):
		btn_main_menu.pressed.connect(_on_btn_main_menu_pressed)

	if btn_delete_account != null and not btn_delete_account.pressed.is_connected(_on_btn_delete_account_pressed):
		btn_delete_account.pressed.connect(_on_btn_delete_account_pressed)


func _sync_layout_bounds() -> void:
	var gs := _autoload("GameState")
	var has_village := (gs != null and gs.has_method("has_active_village") and bool(gs.call("has_active_village")))
	var top_y := 16.0
	var gc := _autoload("GameConfig")
	var safe_top := float(gc.call("get_ios_safe_top")) if (gc != null and gc.has_method("get_ios_safe_top")) else 0.0

	if resource_bar != null:
		resource_bar.visible = has_village
		if has_village:
			var bar_h := 116.0
			if resource_bar.has_method("get_bar_height"):
				bar_h = float(resource_bar.call("get_bar_height"))
			elif resource_bar.size.y > 0.0:
				bar_h = resource_bar.size.y
			top_y = bar_h + 10.0
		else:
			top_y = maxf(24.0, safe_top + 14.0)
	else:
		top_y = maxf(24.0, safe_top + 14.0)

	var hdr_h := 88.0
	if header_panel != null:
		header_panel.offset_top = top_y
		header_panel.offset_bottom = top_y + hdr_h

	if scroll_center != null:
		scroll_center.offset_top = top_y + hdr_h + 14.0
		scroll_center.offset_bottom = -258.0 if (bottom_nav != null and bottom_nav.visible) else -28.0


func _refresh_account_info() -> void:
	if account_info_lbl == null:
		return
	var auth := _autoload("AuthManager")
	var gs := _autoload("GameState")
	var wm := _autoload("WorldManager")

	var p_name := "Misafir Hükümdar"
	var prov_str := "Yerel Oturum"
	var is_logged := false
	if auth != null:
		is_logged = bool(auth.get("is_logged_in"))
		var dn := str(auth.get("display_name")).strip_edges()
		if not dn.is_empty():
			p_name = dn
		var pv := str(auth.get("auth_provider")).strip_edges().to_lower()
		if pv == "apple":
			prov_str = "Apple ID"
		elif pv == "google":
			prov_str = "Google Hesabı"

	if p_name == "Misafir Hükümdar" and gs != null and typeof(gs.get("player")) == TYPE_DICTIONARY:
		var gp: String = str((gs.get("player") as Dictionary).get("name", "")).strip_edges()
		if not gp.is_empty():
			p_name = gp

	var wid := int(wm.get("current_world_id")) if wm != null and wm.get("current_world_id") != null else 1
	var v_text := "Aktif Köy: Yok"
	var v_count := 0
	if gs != null and gs.has_method("get_player_villages"):
		var pv_list: Array = gs.call("get_player_villages")
		v_count = pv_list.size()
	if gs != null and gs.has_method("get_active_village"):
		var av: Dictionary = gs.call("get_active_village")
		if not av.is_empty():
			v_text = "Aktif Köy: %s (%d|%d) • Toplam %d Köy" % [
				str(av.get("name", "Başkent")),
				int(av.get("x", 0)),
				int(av.get("y", 0)),
				maxi(1, v_count),
			]

	account_info_lbl.text = "%s  •  %s  •  Dünya %d\n%s" % [p_name, prov_str, wid, v_text]
	if btn_logout != null:
		btn_logout.visible = is_logged


func _style_btn(btn: Button, bg: Color, border: Color, font_col: Color = Color(0.99, 0.96, 0.88)) -> void:
	if btn == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.border_width_bottom = 3
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(0, 2)

	var sb_hov := sb.duplicate() as StyleBoxFlat
	sb_hov.bg_color = bg.lightened(0.12)
	sb_hov.border_color = border.lightened(0.18)

	var sb_dis := sb.duplicate() as StyleBoxFlat
	sb_dis.bg_color = bg.darkened(0.35)
	sb_dis.border_color = border.darkened(0.35)

	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb_hov)
	btn.add_theme_stylebox_override("pressed", sb_hov)
	btn.add_theme_stylebox_override("focus", sb)
	btn.add_theme_stylebox_override("disabled", sb_dis)
	btn.add_theme_font_override("font", FontNunitoBold)
	btn.add_theme_color_override("font_color", font_col)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_disabled_color", Color(0.65, 0.63, 0.60))
	btn.add_theme_constant_override("outline_size", 2)
	btn.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.05, 0.95))


func _style_option_button(opt: OptionButton) -> void:
	if opt == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.12, 0.18, 0.98)
	sb.border_color = Color(0.84, 0.68, 0.34, 0.92)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	var sb_hov := sb.duplicate() as StyleBoxFlat
	sb_hov.bg_color = Color(0.19, 0.17, 0.25, 1.0)
	sb_hov.border_color = Color(0.96, 0.82, 0.44, 1.0)
	opt.add_theme_stylebox_override("normal", sb)
	opt.add_theme_stylebox_override("hover", sb_hov)
	opt.add_theme_stylebox_override("pressed", sb_hov)
	opt.add_theme_stylebox_override("focus", sb)
	opt.add_theme_font_override("font", FontNunitoBold)
	opt.add_theme_color_override("font_color", Color(0.98, 0.94, 0.84))
	opt.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.90))
	var pop := opt.get_popup()
	if pop != null:
		var pop_sb := StyleBoxFlat.new()
		pop_sb.bg_color = Color(0.10, 0.09, 0.14, 0.99)
		pop_sb.border_color = Color(0.86, 0.70, 0.34, 0.96)
		pop_sb.set_border_width_all(2)
		pop_sb.set_corner_radius_all(10)
		pop_sb.set_content_margin_all(10)
		pop.add_theme_stylebox_override("panel", pop_sb)
		pop.add_theme_font_override("font", FontNunitoBold)
		pop.add_theme_font_size_override("font_size", 22)
		pop.add_theme_color_override("font_color", Color(0.96, 0.92, 0.82))
		pop.add_theme_color_override("font_hover_color", Color(1.0, 0.90, 0.50))


func _apply_royal_styles() -> void:
	_style_btn(btn_logout, Color(0.24, 0.20, 0.30, 0.98), Color(0.76, 0.62, 0.32, 0.90))
	_style_btn(btn_back, Color(0.14, 0.38, 0.22, 0.98), Color(0.46, 0.84, 0.54, 0.95))
	_style_btn(btn_main_menu, Color(0.15, 0.20, 0.34, 0.98), Color(0.68, 0.76, 0.94, 0.88))
	_style_btn(btn_delete_account, Color(0.48, 0.11, 0.13, 0.98), Color(0.94, 0.34, 0.34, 0.96), Color(1.0, 0.92, 0.90))


func _on_btn_logout_pressed() -> void:
	var auth := _autoload("AuthManager")
	if auth != null and auth.has_method("logout"):
		auth.call("logout")
	get_tree().change_scene_to_file("res://scenes/VillageSelect.tscn")


func _on_btn_back_pressed() -> void:
	var gs := _autoload("GameState")
	if gs != null and gs.has_method("has_active_village") and bool(gs.call("has_active_village")):
		get_tree().change_scene_to_file("res://scenes/Village.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/VillageSelect.tscn")


func _on_btn_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/VillageSelect.tscn")


func _on_profile_selected(idx: int) -> void:
	var cfg := _autoload("GameConfig")
	if cfg != null and cfg.has_method("apply_profile"):
		var prof_name := "en" if idx == 1 else "tr"
		cfg.apply_profile(prof_name)
		if cfg.has_method("save_to_file"):
			cfg.call("save_to_file")


func _on_btn_delete_account_pressed() -> void:
	_show_delete_account_modal()


func _show_delete_account_modal() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var root := tree.current_scene if tree.current_scene != null else tree.root
	if root == null:
		return
	if is_instance_valid(_delete_modal):
		var old_m := _delete_modal
		_delete_modal = null
		if old_m.get_parent() != null:
			old_m.get_parent().remove_child(old_m)
		old_m.queue_free()

	var layer := CanvasLayer.new()
	layer.name = "DeleteAccountConfirmModal"
	layer.layer = 160
	_delete_modal = layer
	root.add_child(layer)

	var close_modal := func():
		if _delete_modal == layer:
			_delete_modal = null
		if is_instance_valid(layer):
			layer.queue_free()

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.02, 0.04, 0.84)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(740, 0)
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.11, 0.07, 0.09, 0.99)
	csb.border_color = Color(0.92, 0.30, 0.30, 0.98)
	csb.set_border_width_all(3)
	csb.set_corner_radius_all(20)
	csb.set_content_margin_all(28)
	csb.shadow_color = Color(0, 0, 0, 0.65)
	csb.shadow_size = 14
	card.add_theme_stylebox_override("panel", csb)
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	card.add_child(vb)

	var title := Label.new()
	title.text = "⚠️ HESABI KALICI OLARAK SİL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_override("font", FontCinzelBold)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.56, 0.50))
	vb.add_child(title)

	var body := Label.new()
	body.text = "Bu işlem sonucunda hesabınız, mevcut tüm köyleriniz, binalarınız, askerleriniz, raporlarınız, mesajlarınız, elmaslarınız ve tüm oyun ayarlarınız hem sunucudan hem de cihazınızdan kalıcı olarak silinecektir.\n\nEmin misiniz?"
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(660, 0)
	body.add_theme_font_override("font", FontNunitoSemiBold)
	body.add_theme_font_size_override("font_size", 23)
	body.add_theme_color_override("font_color", Color(0.95, 0.91, 0.88))
	vb.add_child(body)

	var status_lbl := Label.new()
	status_lbl.text = ""
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_lbl.add_theme_font_override("font", FontNunitoBold)
	status_lbl.add_theme_font_size_override("font_size", 22)
	status_lbl.add_theme_color_override("font_color", Color(1.0, 0.78, 0.42))
	vb.add_child(status_lbl)

	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 16)
	vb.add_child(hb)

	var cancel_btn := Button.new()
	cancel_btn.text = "Vazgeç"
	cancel_btn.custom_minimum_size = Vector2(240, 68)
	_style_btn(cancel_btn, Color(0.20, 0.19, 0.26, 0.98), Color(0.66, 0.60, 0.48, 0.90))
	cancel_btn.add_theme_font_size_override("font_size", 24)
	cancel_btn.pressed.connect(close_modal)
	hb.add_child(cancel_btn)

	var confirm_btn := Button.new()
	confirm_btn.text = "Evet, Hesabı Sil"
	confirm_btn.custom_minimum_size = Vector2(280, 68)
	_style_btn(confirm_btn, Color(0.62, 0.12, 0.14, 0.99), Color(1.0, 0.42, 0.40, 1.0))
	confirm_btn.add_theme_font_size_override("font_size", 24)
	hb.add_child(confirm_btn)

	confirm_btn.pressed.connect(func():
		cancel_btn.disabled = true
		confirm_btn.disabled = true
		confirm_btn.text = "Siliniyor..."
		status_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45))
		status_lbl.text = "Hesap, tüm köyler ve ayarlar siliniyor..."

		var wm := _autoload("WorldManager")
		if wm != null:
			wm.set("_suppress_reset_save", true)

		var finalize_local_wipe := func():
			var auth := _autoload("AuthManager")
			if auth != null and auth.has_method("clear_all_account_data"):
				auth.call("clear_all_account_data")
			if wm != null and wm.has_method("wipe_all_local_data"):
				wm.call("wipe_all_local_data")
			close_modal.call()
			if is_inside_tree() and get_tree() != null:
				get_tree().change_scene_to_file("res://scenes/VillageSelect.tscn")

		var net := _autoload("NetworkManager")
		if net != null and net.has_method("delete_account_online"):
			net.call("delete_account_online", func(ok: bool, res_data: Dictionary):
				if not is_instance_valid(layer):
					return
				if ok:
					finalize_local_wipe.call()
				else:
					if wm != null:
						wm.set("_suppress_reset_save", false)
					cancel_btn.disabled = false
					confirm_btn.disabled = false
					confirm_btn.text = "Evet, Hesabı Sil"
					status_lbl.add_theme_color_override("font_color", Color(1.0, 0.44, 0.40))
					var det := str(res_data.get("detail", "")).strip_edges()
					status_lbl.text = det if not det.is_empty() else "⚠️ Sunucuya ulaşılamadı. İnternet bağlantınızı kontrol edip tekrar deneyin."
			)
		else:
			finalize_local_wipe.call()
	)
