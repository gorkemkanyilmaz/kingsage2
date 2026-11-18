extends Control
## VillageSelect — "DÜNYA SEÇİMİ" ve Ana Giriş Ekranı (Taht ve Kılıç).
##
## Oyun doğrudan bu ekrandan başlar.
## Üstte Google/Apple giriş bilgisi (ProfileBar), ortada 10 Dünya listelenir.
## Giriş yapılmamışsa "Krallık Kapısı" doğrulama penceresi görüntülenir.
## Eski ara menü ("Yeni Oyun / Devam Et") ve menüye dönüş butonu kaldırılmıştır.

const FontNunitoBold: Font = preload("res://assets/fonts/Nunito-Bold.ttf")
const FontCinzelBold: Font = preload("res://assets/fonts/Cinzel-Bold.ttf")

const ROW_X_LEFT := 230
const ROW_X_BTN := 530
const ROW_Y_START_BANNER := 460
const ROW_Y_START_BTN := 465
const ROW_Y_STEP := 110
const ROW_BANNER_SIZE := Vector2(295, 100)
const ROW_BTN_SIZE := Vector2(305, 90)

@onready var background_rect: TextureRect = $Background
@onready var rows_container: Control = $RowsContainer
@onready var center_modal: CenterContainer = $Center
@onready var card_panel: Panel = $Center/CardPanel
@onready var region_title: Label = $Center/VBox/Title
@onready var region_desc: Label = $Center/VBox/Desc
@onready var btn_nw: Button = $Center/VBox/Grid/BtnNW
@onready var btn_ne: Button = $Center/VBox/Grid/BtnNE
@onready var btn_sw: Button = $Center/VBox/Grid/BtnSW
@onready var btn_se: Button = $Center/VBox/Grid/BtnSE
@onready var btn_random: Button = $Center/VBox/BtnRandom
@onready var btn_cancel: Button = $Center/VBox/BtnCancel

var _profile_bar: PanelContainer
var _btn_profile_continue: Button
var _auth_overlay: Control
var _name_input: LineEdit
var _status_lbl: Label
var _world_buttons: Dictionary = {}
var _selected_world_id: int = 1
static var _boot_splash_shown: bool = false


func _ready() -> void:
	var root = Engine.get_main_loop().root if Engine.get_main_loop() is SceneTree else null
	var gd = root.get_node_or_null("GameData") if root != null else null
	if gd != null and not gd.is_loaded():
		gd.load_all()
	var gc = root.get_node_or_null("GameClock") if root != null else null
	if gc != null and not gc.running:
		gc.start()

	_setup_profile_bar()
	_setup_auth_overlay()
	_setup_region_modal()
	_maybe_show_boot_splash()
	_refresh_auth_state()
	if _world_buttons.is_empty():
		_build_world_rows()
	_on_viewport_resized()
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(_on_viewport_resized):
		vp.size_changed.connect(_on_viewport_resized)
	if not resized.is_connected(_on_viewport_resized):
		resized.connect(_on_viewport_resized)
	var net = root.get_node_or_null("NetworkManager") if root != null else null
	if net != null:
		if net.has_signal("auth_completed") and not net.auth_completed.is_connected(_on_cloud_sync_finished):
			net.auth_completed.connect(_on_cloud_sync_finished)
		if net.has_signal("sync_completed") and not net.sync_completed.is_connected(_on_cloud_sync_finished):
			net.sync_completed.connect(_on_cloud_sync_finished)
		if net.has_signal("server_status_changed") and not net.server_status_changed.is_connected(_on_server_status_changed):
			net.server_status_changed.connect(_on_server_status_changed)
		if net.has_method("check_server") and net.get("is_server_reachable") == false and net.get_script().is_cloud_sync_enabled():
			net.check_server()
	_update_server_status_ui()


func _on_server_status_changed(_reachable: bool, _data: Dictionary) -> void:
	_update_server_status_ui()


func _update_server_status_ui() -> void:
	if _status_lbl == null:
		return
	var root = Engine.get_main_loop().root if Engine.get_main_loop() is SceneTree else null
	var net = root.get_node_or_null("NetworkManager") if root != null else null
	if net == null:
		return
	if bool(net.get("is_server_reachable")):
		_status_lbl.text = "● Sunucu Çevrimiçi — Google veya Apple ile giriş yapın."
		_status_lbl.add_theme_color_override("font_color", Color(0.55, 0.90, 0.60))
	else:
		_status_lbl.text = "Google veya Apple ile giriş yapıp Dünya 1'e katılın."
		_status_lbl.add_theme_color_override("font_color", Color(0.72, 0.68, 0.62))


func _on_cloud_sync_finished(success: bool, _data: Dictionary) -> void:
	if not success or not is_inside_tree():
		return
	_build_world_rows()
	_update_profile_continue_button()
	_check_conquered_state()
	_update_server_status_ui()


func _is_authenticated() -> bool:
	var root = Engine.get_main_loop().root if Engine.get_main_loop() is SceneTree else null
	var auth = root.get_node_or_null("AuthManager") if root != null else null
	return bool(auth.is_logged_in) if auth != null else false


func _get_player_name() -> String:
	var root = Engine.get_main_loop().root if Engine.get_main_loop() is SceneTree else null
	var auth = root.get_node_or_null("AuthManager") if root != null else null
	if auth != null and not auth.display_name.is_empty():
		return auth.display_name
	var gs = root.get_node_or_null("GameState") if root != null else null
	if gs != null and not str(gs.player.get("name", "")).is_empty() and str(gs.player.get("name", "")) != "Kral":
		return str(gs.player.get("name"))
	return "Lord Gorkem"


func _sync_player_name() -> void:
	var root = Engine.get_main_loop().root if Engine.get_main_loop() is SceneTree else null
	var auth = root.get_node_or_null("AuthManager") if root != null else null
	var gs = root.get_node_or_null("GameState") if root != null else null
	if auth != null and gs != null and not auth.display_name.is_empty():
		gs.player["name"] = auth.display_name


func _refresh_auth_state() -> void:
	var root = Engine.get_main_loop().root if Engine.get_main_loop() is SceneTree else null
	var auth = root.get_node_or_null("AuthManager") if root != null else null
	var is_logged := bool(auth.is_logged_in) if auth != null else false

	if is_logged:
		if _auth_overlay != null:
			_auth_overlay.hide()
		if _profile_bar != null:
			_profile_bar.show()
			var lbl = _profile_bar.get_node_or_null("HBox/ProfileLabel") as Label
			if lbl != null and auth != null:
				var prov_name := "Google" if auth.auth_provider == "google" else "Apple"
				var title_name := str(auth.display_name).strip_edges()
				while title_name.begins_with("Lord Lord "):
					title_name = title_name.substr(5)
				if not title_name.begins_with("Lord "):
					title_name = "Lord " + title_name
				lbl.text = "%s (%s)" % [title_name, prov_name]
		_sync_player_name()
		_build_world_rows()
		_update_profile_continue_button()
		call_deferred("_check_conquered_state")
	else:
		if _profile_bar != null:
			_profile_bar.hide()
		if _btn_profile_continue != null:
			_btn_profile_continue.hide()
		if _auth_overlay != null:
			_auth_overlay.show()


# =============================================================================
#  Üst Profil Çubuğu (Ana Menüdeki Giriş Bilgisi)
# =============================================================================

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
	sb.bg_color = Color(0.10, 0.08, 0.14, 0.92)
	sb.border_color = Color(0.85, 0.72, 0.40, 0.95)
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
	p_lbl.text = "Lord Gorkem (Google)"
	p_lbl.add_theme_font_override("font", FontCinzelBold)
	p_lbl.add_theme_font_size_override("font_size", 24)
	p_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65))
	p_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(p_lbl)

	_btn_profile_continue = Button.new()
	_btn_profile_continue.name = "BtnProfileContinue"
	_btn_profile_continue.text = "▶ Oyuna Devam Et"
	_btn_profile_continue.custom_minimum_size = Vector2(210, 44)
	_btn_profile_continue.visible = false
	_btn_profile_continue.add_theme_font_override("font", FontNunitoBold)
	_btn_profile_continue.add_theme_font_size_override("font_size", 19)
	_btn_profile_continue.add_theme_color_override("font_color", Color(1.0, 0.95, 0.78))
	_btn_profile_continue.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var c_sb := StyleBoxFlat.new()
	c_sb.bg_color = Color(0.14, 0.42, 0.22, 0.92)
	c_sb.border_color = Color(0.88, 0.75, 0.35, 0.95)
	c_sb.set_border_width_all(2)
	c_sb.set_corner_radius_all(10)
	c_sb.set_content_margin_all(8)
	_btn_profile_continue.add_theme_stylebox_override("normal", c_sb)
	var c_hover := c_sb.duplicate() as StyleBoxFlat
	c_hover.bg_color = Color(0.20, 0.54, 0.30, 0.98)
	_btn_profile_continue.add_theme_stylebox_override("hover", c_hover)
	_btn_profile_continue.add_theme_stylebox_override("pressed", c_hover)
	_btn_profile_continue.pressed.connect(_on_profile_continue_pressed)
	hbox.add_child(_btn_profile_continue)

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


# =============================================================================
#  Kimlik Doğrulama Modal Penceresi (Krallık Kapısı)
# =============================================================================

func _setup_auth_overlay() -> void:
	_auth_overlay = Control.new()
	_auth_overlay.name = "AuthOverlay"
	add_child(_auth_overlay)
	_auth_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_auth_overlay.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_auth_overlay.grow_vertical = Control.GROW_DIRECTION_BOTH
	_auth_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	# Koyu karartma arka planı
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.06, 0.88)
	_auth_overlay.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.grow_horizontal = Control.GROW_DIRECTION_BOTH
	dim.grow_vertical = Control.GROW_DIRECTION_BOTH
	dim.mouse_filter = Control.MOUSE_FILTER_STOP

	# Ortalanmış Medieval Kart
	var center := CenterContainer.new()
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
	subtitle.text = "Devam etmek için telefonunuzun Apple Hesabı (Face ID) veya Google Hesabı ile oturum açın:"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_override("font", FontNunitoBold)
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", Color(0.85, 0.80, 0.72))
	vb.add_child(subtitle)

	var sep1 := HSeparator.new()
	vb.add_child(sep1)

	# Gizli geriye dönük uyumluluk alanı (manuel Lord adı kutusu kaldırıldı — gerçek Google/Apple hesabı ile giriş)
	_name_input = LineEdit.new()
	_name_input.visible = false
	_name_input.text = ""
	vb.add_child(_name_input)

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


func _maybe_show_boot_splash() -> void:
	if _boot_splash_shown or DisplayServer.get_name() == "headless":
		_boot_splash_shown = true
		return
	_boot_splash_shown = true

	var splash := CanvasLayer.new()
	splash.name = "DiyarBootSplash"
	splash.layer = 200
	add_child(splash)

	var bg := ColorRect.new()
	bg.color = Color(0.055, 0.047, 0.078, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	splash.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	splash.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 18)
	center.add_child(vb)

	var icon_tex := load("res://assets/icons/app_icon_180.png")
	if icon_tex is Texture2D:
		var tr := TextureRect.new()
		tr.texture = icon_tex
		tr.custom_minimum_size = Vector2(180, 180)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vb.add_child(tr)

	var title_lbl := Label.new()
	title_lbl.text = "TAHT VE KILIÇ"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_override("font", FontCinzelBold)
	title_lbl.add_theme_font_size_override("font_size", 46)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.81, 0.40, 1.0))
	vb.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "Diyar hazırlanıyor..."
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_override("font", FontNunitoBold)
	sub_lbl.add_theme_font_size_override("font_size", 24)
	sub_lbl.add_theme_color_override("font_color", Color(0.78, 0.75, 0.67, 1.0))
	vb.add_child(sub_lbl)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(360, 14)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 10.0
	var pbg := StyleBoxFlat.new()
	pbg.bg_color = Color(0.10, 0.08, 0.13, 1.0)
	pbg.border_color = Color(0.42, 0.33, 0.15, 1.0)
	pbg.set_border_width_all(1)
	pbg.set_corner_radius_all(8)
	var pfg := StyleBoxFlat.new()
	pfg.bg_color = Color(0.90, 0.75, 0.33, 1.0)
	pfg.set_corner_radius_all(8)
	bar.add_theme_stylebox_override("background", pbg)
	bar.add_theme_stylebox_override("fill", pfg)
	vb.add_child(bar)

	var tw := create_tween()
	tw.tween_property(bar, "value", 100.0, 0.72).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(bg, "modulate:a", 0.0, 0.22)
	tw.parallel().tween_property(center, "modulate:a", 0.0, 0.22)
	tw.tween_callback(func():
		if is_instance_valid(splash):
			splash.queue_free()
	)


func _do_login(provider: String) -> void:
	var desired_name := _name_input.text.strip_edges() if _name_input != null else ""

	var auth = Engine.get_main_loop().root.get_node_or_null("AuthManager") if Engine.get_main_loop() is SceneTree else null
	if auth != null and auth.has_method("authenticate_with_provider"):
		auth.authenticate_with_provider(provider, desired_name, self, func(prof: Dictionary):
			if not bool(prof.get("is_logged_in", false)):
				return
			var canonical_name := str(prof.get("name", desired_name))
			if canonical_name.is_empty():
				canonical_name = "Lord Gorkem" if provider == "google" else "Lord Roland"
			var net = Engine.get_main_loop().root.get_node_or_null("NetworkManager") if Engine.get_main_loop() is SceneTree else null
			if net != null:
				net.login_online(provider, canonical_name)
			_refresh_auth_state()
		)
		return

	if desired_name.is_empty():
		desired_name = "Lord Gorkem" if provider == "google" else "Lord Roland"
	var net = Engine.get_main_loop().root.get_node_or_null("NetworkManager") if Engine.get_main_loop() is SceneTree else null
	if net != null:
		net.login_online(provider, desired_name)

	_refresh_auth_state()


# =============================================================================
#  10 Dünya Sıralaması ve Butonları
# =============================================================================

func _build_world_rows() -> void:
	for child in rows_container.get_children():
		rows_container.remove_child(child)
		child.queue_free()
	_world_buttons.clear()

	var root = Engine.get_main_loop().root if Engine.get_main_loop() is SceneTree else null
	var wm = root.get_node_or_null("WorldManager") if root != null else null
	var p_name := _get_player_name()

	var vp_size := size if (is_inside_tree() and size.x > 0.0 and size.y > 0.0) else (get_viewport_rect().size if is_inside_tree() else Vector2(1080.0, 1920.0))
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		vp_size = Vector2(1080.0, 1920.0)
	rows_container.position = Vector2.ZERO
	rows_container.scale = Vector2(vp_size.x / 1080.0, vp_size.y / 1920.0)
	_update_profile_continue_button()

	for i in range(1, 11):
		var y_banner := ROW_Y_START_BANNER + (i - 1) * ROW_Y_STEP
		var y_btn := ROW_Y_START_BTN + (i - 1) * ROW_Y_STEP
		var is_active := false
		var has_village := false

		if wm != null:
			var w_meta = wm.get_world_meta(i)
			is_active = bool(w_meta.get("is_active", false))
			if is_active:
				has_village = wm.has_player_village(i, p_name)
		else:
			is_active = (i == 1)

		if is_active:
			# Aktif Dünya: Sol canlı banner (da tıklanabilir) ve Sağ altın buton
			var action_cb: Callable = _on_continue_world.bind(i) if has_village else _on_join_world.bind(i)

			var banner_btn := TextureButton.new()
			banner_btn.name = "Banner_%d" % i
			banner_btn.position = Vector2(ROW_X_LEFT, y_banner)
			banner_btn.size = ROW_BANNER_SIZE
			banner_btn.ignore_texture_size = true
			banner_btn.stretch_mode = TextureButton.STRETCH_SCALE
			banner_btn.disabled = false
			banner_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var banner_path := "res://assets/sprites/ui/banner_world_%d_active.png" % i
			if ResourceLoader.exists(banner_path):
				var b_tex := load(banner_path)
				banner_btn.texture_normal = b_tex
				banner_btn.texture_hover = b_tex
				banner_btn.texture_pressed = b_tex
			banner_btn.pressed.connect(action_cb)
			rows_container.add_child(banner_btn)

			var btn := TextureButton.new()
			btn.name = "BtnWorld_%d" % i
			btn.position = Vector2(ROW_X_BTN, y_btn)
			btn.size = ROW_BTN_SIZE
			btn.ignore_texture_size = true
			btn.stretch_mode = TextureButton.STRETCH_SCALE
			btn.disabled = false
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

			if has_village:
				btn.texture_normal = load("res://assets/sprites/ui/btn_devam_active.png")
				btn.texture_hover = load("res://assets/sprites/ui/btn_devam_hover.png")
				btn.texture_pressed = load("res://assets/sprites/ui/btn_devam_pressed.png")
			else:
				btn.texture_normal = load("res://assets/sprites/ui/btn_katil_active.png")
				btn.texture_hover = load("res://assets/sprites/ui/btn_katil_hover.png")
				btn.texture_pressed = load("res://assets/sprites/ui/btn_katil_pressed.png")
			btn.pressed.connect(action_cb)

			rows_container.add_child(btn)
			_world_buttons[i] = btn
		else:
			# Pasif Gri Dünya: Arka planda gri olarak basılıdır, üzerine tıklanamaz buton yerleştirilir
			var btn := TextureButton.new()
			btn.name = "BtnWorld_%d" % i
			btn.position = Vector2(ROW_X_BTN, y_btn)
			btn.size = ROW_BTN_SIZE
			btn.disabled = true
			btn.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
			rows_container.add_child(btn)
			_world_buttons[i] = btn


func _on_viewport_resized() -> void:
	if rows_container == null:
		return
	var vp_size := size if (is_inside_tree() and size.x > 0.0 and size.y > 0.0) else (get_viewport_rect().size if is_inside_tree() else Vector2(1080.0, 1920.0))
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return
	rows_container.position = Vector2.ZERO
	rows_container.scale = Vector2(vp_size.x / 1080.0, vp_size.y / 1920.0)


func _update_profile_continue_button() -> void:
	if _btn_profile_continue == null:
		return
	var root = Engine.get_main_loop().root if Engine.get_main_loop() is SceneTree else null
	var wm = root.get_node_or_null("WorldManager") if root != null else null
	var sm = root.get_node_or_null("SaveManager") if root != null else null
	var auth = root.get_node_or_null("AuthManager") if root != null else null
	var p_name: String = auth.display_name if (auth != null and not str(auth.display_name).is_empty()) else "Lord Gorkem"
	var is_conquered: bool = (wm != null and wm.has_method("is_player_conquered") and bool(wm.is_player_conquered(wm.current_world_id, p_name)))
	var has_v := false
	if wm != null and wm.has_player_village(wm.current_world_id, p_name):
		has_v = true
	elif not is_conquered and sm != null and sm.has_save():
		has_v = true
	_btn_profile_continue.visible = has_v


func _check_conquered_state() -> void:
	if not is_inside_tree() or not _is_authenticated():
		return
	var root = Engine.get_main_loop().root if Engine.get_main_loop() is SceneTree else null
	var wm = root.get_node_or_null("WorldManager") if root != null else null
	if wm == null:
		return
	var p_name := _get_player_name()
	if wm.is_player_conquered(wm.current_world_id, p_name):
		wm.maybe_show_conquered_modal_for_current_scene(wm.current_world_id, p_name)


func _on_profile_continue_pressed() -> void:
	var root = Engine.get_main_loop().root if Engine.get_main_loop() is SceneTree else null
	var wm = root.get_node_or_null("WorldManager") if root != null else null
	var sm = root.get_node_or_null("SaveManager") if root != null else null
	var auth = root.get_node_or_null("AuthManager") if root != null else null
	var p_name: String = auth.display_name if (auth != null and not str(auth.display_name).is_empty()) else "Lord Gorkem"
	if wm != null and wm.has_player_village(wm.current_world_id, p_name):
		if wm.enter_world(wm.current_world_id, p_name):
			get_tree().change_scene_to_file("res://scenes/Village.tscn")
			return
	if sm != null and sm.has_save() and sm.load_game():
		get_tree().change_scene_to_file("res://scenes/Village.tscn")


# =============================================================================
#  Bölge ve Yön Seçim Modalı (↖ Kuzeybatı, ↗ Kuzeydoğu, ↙ Güneybatı, ↘ Güneydoğu, 🎲 Rastgele)
# =============================================================================

func _setup_region_modal() -> void:
	if center_modal == null:
		return
	center_modal.hide()

	if card_panel != null:
		var c_sb := StyleBoxFlat.new()
		c_sb.bg_color = Color(0.10, 0.08, 0.14, 0.96)
		c_sb.border_color = Color(0.85, 0.72, 0.40, 1.0)
		c_sb.set_border_width_all(3)
		c_sb.set_corner_radius_all(20)
		c_sb.shadow_color = Color(0, 0, 0, 0.7)
		c_sb.shadow_size = 16
		card_panel.add_theme_stylebox_override("panel", c_sb)

	if region_title != null:
		region_title.add_theme_font_override("font", FontCinzelBold)
		region_title.add_theme_font_size_override("font_size", 42)
		region_title.add_theme_color_override("font_color", Color(1.0, 0.90, 0.50))
		region_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
		region_title.add_theme_constant_override("outline_size", 4)

	if region_desc != null:
		region_desc.add_theme_font_override("font", FontNunitoBold)
		region_desc.add_theme_font_size_override("font_size", 22)
		region_desc.add_theme_color_override("font_color", Color(0.88, 0.84, 0.76))

	var dir_buttons := [btn_nw, btn_ne, btn_sw, btn_se]
	for b in dir_buttons:
		if b == null:
			continue
		b.add_theme_font_override("font", FontNunitoBold)
		b.add_theme_font_size_override("font_size", 26)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var b_sb := StyleBoxFlat.new()
		b_sb.bg_color = Color(0.18, 0.15, 0.24, 0.95)
		b_sb.border_color = Color(0.75, 0.62, 0.35, 0.9)
		b_sb.set_border_width_all(2)
		b_sb.set_corner_radius_all(14)
		b_sb.set_content_margin_all(12)
		b.add_theme_stylebox_override("normal", b_sb)
		b.add_theme_color_override("font_color", Color(1.0, 0.92, 0.70))
		var b_h = b_sb.duplicate() as StyleBoxFlat
		b_h.bg_color = Color(0.28, 0.22, 0.38, 1.0)
		b_h.border_color = Color(1.0, 0.85, 0.45, 1.0)
		b.add_theme_stylebox_override("hover", b_h)
		b.add_theme_stylebox_override("pressed", b_h)

	if btn_random != null:
		btn_random.add_theme_font_override("font", FontNunitoBold)
		btn_random.add_theme_font_size_override("font_size", 28)
		btn_random.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var r_sb := StyleBoxFlat.new()
		r_sb.bg_color = Color(0.24, 0.18, 0.32, 0.95)
		r_sb.border_color = Color(0.95, 0.80, 0.45, 1.0)
		r_sb.set_border_width_all(2)
		r_sb.set_corner_radius_all(16)
		r_sb.set_content_margin_all(14)
		btn_random.add_theme_stylebox_override("normal", r_sb)
		btn_random.add_theme_color_override("font_color", Color(1.0, 0.95, 0.80))
		var r_h = r_sb.duplicate() as StyleBoxFlat
		r_h.bg_color = Color(0.36, 0.28, 0.48, 1.0)
		r_h.border_color = Color(1.0, 0.90, 0.55, 1.0)
		btn_random.add_theme_stylebox_override("hover", r_h)
		btn_random.add_theme_stylebox_override("pressed", r_h)

	if btn_cancel != null:
		btn_cancel.add_theme_font_override("font", FontNunitoBold)
		btn_cancel.add_theme_font_size_override("font_size", 22)
		btn_cancel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var c_btn_sb := StyleBoxFlat.new()
		c_btn_sb.bg_color = Color(0.14, 0.12, 0.16, 0.9)
		c_btn_sb.border_color = Color(0.50, 0.42, 0.38, 0.8)
		c_btn_sb.set_border_width_all(1)
		c_btn_sb.set_corner_radius_all(12)
		c_btn_sb.set_content_margin_all(10)
		btn_cancel.add_theme_stylebox_override("normal", c_btn_sb)
		btn_cancel.add_theme_color_override("font_color", Color(0.75, 0.70, 0.65))

	if btn_nw != null and not btn_nw.pressed.is_connected(_on_nw_pressed):
		btn_nw.pressed.connect(_on_nw_pressed)
	if btn_ne != null and not btn_ne.pressed.is_connected(_on_ne_pressed):
		btn_ne.pressed.connect(_on_ne_pressed)
	if btn_sw != null and not btn_sw.pressed.is_connected(_on_sw_pressed):
		btn_sw.pressed.connect(_on_sw_pressed)
	if btn_se != null and not btn_se.pressed.is_connected(_on_se_pressed):
		btn_se.pressed.connect(_on_se_pressed)
	if btn_random != null and not btn_random.pressed.is_connected(_on_random_pressed):
		btn_random.pressed.connect(_on_random_pressed)
	if btn_cancel != null and not btn_cancel.pressed.is_connected(_on_cancel_pressed):
		btn_cancel.pressed.connect(_on_cancel_pressed)


func _on_nw_pressed() -> void:
	_select_direction(35, 35)


func _on_ne_pressed() -> void:
	_select_direction(165, 35)


func _on_sw_pressed() -> void:
	_select_direction(35, 165)


func _on_se_pressed() -> void:
	_select_direction(165, 165)


func _on_random_pressed() -> void:
	var options := [Vector2i(35, 35), Vector2i(165, 35), Vector2i(35, 165), Vector2i(165, 165)]
	var pick: Vector2i = options[randi() % options.size()]
	_select_direction(pick.x, pick.y)


func _on_cancel_pressed() -> void:
	if center_modal != null:
		center_modal.hide()


var _joining_in_flight: bool = false


func _select_direction(target_x: int, target_y: int) -> void:
	if _joining_in_flight:
		return
	if not _is_authenticated():
		if _auth_overlay != null:
			_auth_overlay.show()
		return

	var root = Engine.get_main_loop().root if Engine.get_main_loop() is SceneTree else null
	var wm = root.get_node_or_null("WorldManager") if root != null else null
	var net = root.get_node_or_null("NetworkManager") if root != null else null
	var auth = root.get_node_or_null("AuthManager") if root != null else null
	var p_name := _get_player_name()

	if net != null and net.get_script() != null and net.get_script().is_cloud_sync_enabled() and str(net.auth_token).is_empty() and auth != null and bool(auth.is_logged_in):
		_joining_in_flight = true
		if region_desc != null:
			region_desc.text = "Sunucuya bağlanılıyor, lütfen bekleyin..."
		var prov: String = str(auth.auth_provider) if not str(auth.auth_provider).is_empty() else "google"
		net.login_online(prov, p_name, func(_ok: bool, _res: Dictionary):
			_joining_in_flight = false
			if is_inside_tree():
				_complete_select_direction(target_x, target_y)
		)
		return

	_complete_select_direction(target_x, target_y)


func _complete_select_direction(target_x: int, target_y: int) -> void:
	var root = Engine.get_main_loop().root if Engine.get_main_loop() is SceneTree else null
	var wm = root.get_node_or_null("WorldManager") if root != null else null
	var p_name := _get_player_name()

	if wm != null:
		var was_conquered := bool(wm.has_method("is_player_conquered") and wm.is_player_conquered(_selected_world_id, p_name))
		var already_has := (not was_conquered) and bool(wm.has_method("has_player_village") and wm.has_player_village(_selected_world_id, p_name))
		var success: bool
		if already_has:
			success = wm.enter_world(_selected_world_id, p_name)
		elif was_conquered:
			success = wm.restart_after_conquest(_selected_world_id, p_name, target_x, target_y)
		else:
			success = wm.join_world(_selected_world_id, p_name, target_x, target_y)
		if success:
			get_tree().change_scene_to_file("res://scenes/Village.tscn")
	else:
		push_error("WorldManager bulunamadı!")


func _on_join_world(world_id: int) -> void:
	if not _is_authenticated():
		if _auth_overlay != null:
			_auth_overlay.show()
		return

	_selected_world_id = world_id
	if region_title != null:
		region_title.text = "Başlangıç Yönü Seçin"
	if region_desc != null:
		region_desc.text = "Dünya %d topraklarında krallığınız kuruluyor.\nHaritada yerleşmek istediğiniz yönü seçin:" % world_id

	if center_modal != null:
		center_modal.show()
	else:
		_select_direction(100, 100)


func _on_continue_world(world_id: int) -> void:
	if not _is_authenticated():
		if _auth_overlay != null:
			_auth_overlay.show()
		return

	var root = Engine.get_main_loop().root if Engine.get_main_loop() is SceneTree else null
	var wm = root.get_node_or_null("WorldManager") if root != null else null
	var p_name := _get_player_name()

	if wm != null:
		var success: bool = wm.enter_world(world_id, p_name)
		if success:
			get_tree().change_scene_to_file("res://scenes/Village.tscn")
		else:
			# Köyü bulunamadıysa (veya fethedildiyse) yön seçimi aç
			_on_join_world(world_id)
	else:
		push_error("WorldManager bulunamadı!")
