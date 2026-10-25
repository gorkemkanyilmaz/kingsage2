extends Control
## MainMenu — Ana Menü ekranı (Taht ve Kılıç / A-ARAYUZ).
## Zorunlu Google ve Apple ile kimlik doğrulama & Çevrimiçi Sunucu Entegrasyonu.

const FontNunitoBold: Font = preload("res://assets/fonts/Nunito-Bold.ttf")
const FontCinzelBold: Font = preload("res://assets/fonts/Cinzel-Bold.ttf")

@onready var btn_new_game: Button = $Center/VBox/BtnNewGame
@onready var btn_continue: Button = $Center/VBox/BtnContinue
@onready var btn_settings: Button = $Center/VBox/BtnSettings
@onready var btn_quit: Button = $Center/VBox/BtnQuit

var _auth_overlay: Control
var _profile_bar: Control
var _name_input: LineEdit
var _status_lbl: Label


func _ready() -> void:
	var root = Engine.get_main_loop().root if Engine.get_main_loop() is SceneTree else null
	var gd = root.get_node_or_null("GameData") if root != null else null
	if gd != null and not gd.is_loaded():
		gd.load_all()
	var gc = root.get_node_or_null("GameClock") if root != null else null
	if gc != null and not gc.running:
		gc.start()

	var sm = root.get_node_or_null("SaveManager") if root != null else null
	var has_save: bool = bool(sm.has_save()) if sm != null else false

	btn_continue.disabled = not has_save

	btn_new_game.pressed.connect(func():
		if not _is_authenticated():
			_show_auth_modal()
			return
		_sync_player_name()
		get_tree().change_scene_to_file("res://scenes/VillageSelect.tscn")
	)

	btn_continue.pressed.connect(func():
		if not _is_authenticated():
			_show_auth_modal()
			return
		if sm != null and sm.load_game():
			_sync_player_name()
			get_tree().change_scene_to_file("res://scenes/Village.tscn")
	)

	btn_settings.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/Settings.tscn")
	)

	btn_quit.pressed.connect(func():
		get_tree().quit(0)
	)

	_setup_profile_bar()
	_setup_auth_overlay()
	_refresh_auth_state()


func _is_authenticated() -> bool:
	var auth = Engine.get_main_loop().root.get_node_or_null("AuthManager") if Engine.get_main_loop() is SceneTree else null
	return bool(auth.is_logged_in) if auth != null else false


func _sync_player_name() -> void:
	var auth = Engine.get_main_loop().root.get_node_or_null("AuthManager") if Engine.get_main_loop() is SceneTree else null
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if auth != null and gs != null and not auth.display_name.is_empty():
		gs.player["name"] = auth.display_name


func _refresh_auth_state() -> void:
	var auth = Engine.get_main_loop().root.get_node_or_null("AuthManager") if Engine.get_main_loop() is SceneTree else null
	var is_logged := bool(auth.is_logged_in) if auth != null else false

	if is_logged:
		if _auth_overlay != null:
			_auth_overlay.hide()
		if _profile_bar != null:
			_profile_bar.show()
			var lbl = _profile_bar.get_node_or_null("HBox/ProfileLabel") as Label
			if lbl != null and auth != null:
				var prov_name := "Google" if auth.auth_provider == "google" else "Apple"
				lbl.text = "Lord %s (%s)" % [auth.display_name, prov_name]
		_sync_player_name()
	else:
		if _profile_bar != null:
			_profile_bar.hide()
		_show_auth_modal()


func _show_auth_modal() -> void:
	if _auth_overlay != null:
		_auth_overlay.show()


func _setup_profile_bar() -> void:
	_profile_bar = PanelContainer.new()
	_profile_bar.name = "ProfileBar"
	_profile_bar.custom_minimum_size = Vector2(0, 68)
	add_child(_profile_bar)
	_profile_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_profile_bar.offset_left = 32
	_profile_bar.offset_top = 48
	_profile_bar.offset_right = -32
	_profile_bar.offset_bottom = 120

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.08, 0.14, 0.90)
	sb.border_color = Color(0.85, 0.72, 0.40, 0.90)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(14)
	_profile_bar.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.name = "HBox"
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	_profile_bar.add_child(hbox)

	var p_lbl := Label.new()
	p_lbl.name = "ProfileLabel"
	p_lbl.text = "Lord Edward (Google)"
	p_lbl.add_theme_font_override("font", FontCinzelBold)
	p_lbl.add_theme_font_size_override("font_size", 24)
	p_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65))
	p_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(p_lbl)

	var server_dot := Label.new()
	server_dot.text = "500 CCU Bulut (Aktif)"
	server_dot.add_theme_font_override("font", FontNunitoBold)
	server_dot.add_theme_font_size_override("font_size", 20)
	server_dot.add_theme_color_override("font_color", Color(0.40, 0.95, 0.55))
	hbox.add_child(server_dot)

	var btn_logout := Button.new()
	btn_logout.text = "Çıkış"
	btn_logout.custom_minimum_size = Vector2(120, 44)
	btn_logout.add_theme_font_override("font", FontNunitoBold)
	btn_logout.add_theme_font_size_override("font_size", 20)
	btn_logout.add_theme_color_override("font_color", Color(1, 0.8, 0.8))

	var l_sb := StyleBoxFlat.new()
	l_sb.bg_color = Color(0.45, 0.15, 0.15, 0.85)
	l_sb.border_color = Color(0.85, 0.35, 0.35, 0.90)
	l_sb.set_border_width_all(1)
	l_sb.set_corner_radius_all(10)
	l_sb.set_content_margin_all(8)
	btn_logout.add_theme_stylebox_override("normal", l_sb)

	btn_logout.pressed.connect(func():
		var auth = Engine.get_main_loop().root.get_node_or_null("AuthManager") if Engine.get_main_loop() is SceneTree else null
		if auth != null:
			auth.logout()
		_refresh_auth_state()
	)
	hbox.add_child(btn_logout)


func _setup_auth_overlay() -> void:
	_auth_overlay = Control.new()
	_auth_overlay.name = "AuthOverlay"
	_auth_overlay.custom_minimum_size = Vector2(1080, 1920)
	add_child(_auth_overlay)
	_auth_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_auth_overlay.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_auth_overlay.grow_vertical = Control.GROW_DIRECTION_BOTH
	_auth_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	# Koyu karartma arka planı
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.06, 0.88)
	dim.custom_minimum_size = Vector2(1080, 1920)
	_auth_overlay.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.grow_horizontal = Control.GROW_DIRECTION_BOTH
	dim.grow_vertical = Control.GROW_DIRECTION_BOTH
	dim.mouse_filter = Control.MOUSE_FILTER_STOP

	# Ortalanmış Medieval Kart
	var center := CenterContainer.new()
	center.custom_minimum_size = Vector2(1080, 1920)
	_auth_overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	center.mouse_filter = Control.MOUSE_FILTER_PASS

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(760, 820)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.10, 0.16, 0.98)
	sb.border_color = Color(0.88, 0.74, 0.42, 1.0)
	sb.set_border_width_all(3)
	sb.border_width_top = 6
	sb.set_corner_radius_all(24)
	sb.set_content_margin_all(36)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 20
	sb.shadow_offset = Vector2(0, 8)
	card.add_theme_stylebox_override("panel", sb)
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 24)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vb)

	# Başlık
	var crown_container := CenterContainer.new()
	crown_container.custom_minimum_size = Vector2(0, 64)
	var crown := TextureRect.new()
	crown.texture = load("res://assets/sprites/icons/board-game/128px/crown_a.png")
	crown.custom_minimum_size = Vector2(64, 64)
	crown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crown.modulate = Color(1.0, 0.85, 0.40)
	crown_container.add_child(crown)
	vb.add_child(crown_container)

	var title := Label.new()
	title.text = "KRALLIK KAPISI"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", FontCinzelBold)
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.68))
	vb.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Krallığınıza erişmek ve köyünüzü yönetmek için lütfen bir hesapla giriş yapın:"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_override("font", FontNunitoBold)
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", Color(0.85, 0.80, 0.72))
	vb.add_child(subtitle)

	var sep1 := HSeparator.new()
	vb.add_child(sep1)

	# Lord Adı Girişi
	var name_box := VBoxContainer.new()
	name_box.add_theme_constant_override("separation", 8)
	var name_lbl := Label.new()
	name_lbl.text = "Lord Ünvanınız (İsim):"
	name_lbl.add_theme_font_override("font", FontNunitoBold)
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.90, 0.80))
	name_box.add_child(name_lbl)

	_name_input = LineEdit.new()
	_name_input.placeholder_text = "Örn: Lord Gorkem"
	_name_input.text = _get_player_name()
	_name_input.custom_minimum_size = Vector2(0, 58)
	_name_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_input.add_theme_font_override("font", FontNunitoBold)
	_name_input.add_theme_font_size_override("font_size", 24)
	_name_input.add_theme_color_override("font_color", Color(1.0, 0.96, 0.90))
	_name_input.add_theme_color_override("font_selected_color", Color(1.0, 1.0, 1.0))
	_name_input.add_theme_color_override("selection_color", Color(0.28, 0.42, 0.72, 0.90))
	_name_input.add_theme_color_override("caret_color", Color(1.0, 0.85, 0.40))
	var inp_sb := StyleBoxFlat.new()
	inp_sb.bg_color = Color(0.06, 0.05, 0.08, 0.95)
	inp_sb.border_color = Color(0.65, 0.52, 0.35, 0.9)
	inp_sb.set_border_width_all(2)
	inp_sb.set_corner_radius_all(12)
	inp_sb.set_content_margin_all(12)
	_name_input.add_theme_stylebox_override("normal", inp_sb)
	_name_input.add_theme_stylebox_override("focus", inp_sb)
	name_box.add_child(_name_input)
	vb.add_child(name_box)

	# Giriş Butonları (Google & Apple)
	var btn_google := Button.new()
	btn_google.text = "Google ile Giriş Yap"
	btn_google.custom_minimum_size = Vector2(0, 68)
	btn_google.add_theme_font_override("font", FontNunitoBold)
	btn_google.add_theme_font_size_override("font_size", 26)
	btn_google.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var g_sb := StyleBoxFlat.new()
	g_sb.bg_color = Color(0.95, 0.95, 0.95, 1.0)
	g_sb.border_color = Color(0.85, 0.70, 0.35, 1.0)
	g_sb.set_border_width_all(2)
	g_sb.set_corner_radius_all(14)
	g_sb.set_content_margin_all(14)
	btn_google.add_theme_stylebox_override("normal", g_sb)
	btn_google.add_theme_color_override("font_color", Color(0.15, 0.15, 0.20))
	var g_hover := g_sb.duplicate() as StyleBoxFlat
	g_hover.bg_color = Color(1.0, 1.0, 1.0, 1.0)
	btn_google.add_theme_stylebox_override("hover", g_hover)
	btn_google.add_theme_color_override("font_hover_color", Color(0.05, 0.05, 0.10))
	var g_pressed := g_sb.duplicate() as StyleBoxFlat
	g_pressed.bg_color = Color(0.88, 0.88, 0.88, 1.0)
	btn_google.add_theme_stylebox_override("pressed", g_pressed)
	btn_google.add_theme_color_override("font_pressed_color", Color(0.15, 0.15, 0.20))
	btn_google.pressed.connect(func(): _do_login("google"))
	vb.add_child(btn_google)

	var btn_apple := Button.new()
	btn_apple.text = "Apple ile Giriş Yap"
	btn_apple.custom_minimum_size = Vector2(0, 68)
	btn_apple.add_theme_font_override("font", FontNunitoBold)
	btn_apple.add_theme_font_size_override("font_size", 26)
	btn_apple.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var a_sb := StyleBoxFlat.new()
	a_sb.bg_color = Color(0.02, 0.02, 0.04, 1.0)
	a_sb.border_color = Color(0.75, 0.75, 0.85, 1.0)
	a_sb.set_border_width_all(2)
	a_sb.set_corner_radius_all(14)
	a_sb.set_content_margin_all(14)
	btn_apple.add_theme_stylebox_override("normal", a_sb)
	btn_apple.add_theme_color_override("font_color", Color(0.98, 0.98, 1.0))
	var a_hover := a_sb.duplicate() as StyleBoxFlat
	a_hover.bg_color = Color(0.10, 0.10, 0.15, 1.0)
	btn_apple.add_theme_stylebox_override("hover", a_hover)
	btn_apple.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	var a_pressed := a_sb.duplicate() as StyleBoxFlat
	a_pressed.bg_color = Color(0.0, 0.0, 0.0, 1.0)
	btn_apple.add_theme_stylebox_override("pressed", a_pressed)
	btn_apple.add_theme_color_override("font_pressed_color", Color(0.90, 0.90, 0.95))
	btn_apple.pressed.connect(func(): _do_login("apple"))
	vb.add_child(btn_apple)

	_status_lbl = Label.new()
	_status_lbl.text = "Taht ve Kılıç sisteminde yalnızca Google ve Apple girişi geçerlidir."
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_lbl.add_theme_font_size_override("font_size", 20)
	_status_lbl.add_theme_color_override("font_color", Color(0.65, 0.62, 0.58))
	vb.add_child(_status_lbl)


func _do_login(provider: String) -> void:
	var desired_name := _name_input.text.strip_edges()
	if desired_name.is_empty():
		desired_name = "Lord Edward" if provider == "google" else "Lord Roland"

	var auth = Engine.get_main_loop().root.get_node_or_null("AuthManager") if Engine.get_main_loop() is SceneTree else null
	if auth != null:
		if provider == "google":
			auth.login_with_google(desired_name)
		else:
			auth.login_with_apple(desired_name)

	var net = Engine.get_main_loop().root.get_node_or_null("NetworkManager") if Engine.get_main_loop() is SceneTree else null
	if net != null:
		net.login_online(provider, desired_name)

	_refresh_auth_state()
