extends CanvasLayer
## MarketModal — Kraliyet Pazarı: Hızlandırma Parşömenleri ve Elmas Paketleri.

const FontCinzelBold := preload("res://assets/fonts/Cinzel-Bold.ttf")
const FontNunitoBold := preload("res://assets/fonts/Nunito-Bold.ttf")
const FontNunitoSemiBold := preload("res://assets/fonts/Nunito-SemiBold.ttf")

const FALLBACK_PACKS: Array[Dictionary] = [
	{"id": "diamonds_10", "product_id": "com.tahtkilic.kingsage2.diamonds_10", "name": "Avuç Dolusu Elmas", "diamonds": 10, "badge": "Başlangıç", "usd": "$0.99", "eur": "€0.99", "try": "₺49,99"},
	{"id": "diamonds_50", "product_id": "com.tahtkilic.kingsage2.diamonds_50", "name": "Kese Elmas", "diamonds": 50, "badge": "+%10 Değer", "usd": "$4.99", "eur": "€5.99", "try": "₺249,99"},
	{"id": "diamonds_100", "product_id": "com.tahtkilic.kingsage2.diamonds_100", "name": "Hazine Sandığı", "diamonds": 100, "badge": "⭐ En Popüler", "usd": "$7.99", "eur": "€8.99", "try": "₺399,99"},
	{"id": "diamonds_250", "product_id": "com.tahtkilic.kingsage2.diamonds_250", "name": "Kraliyet Kasası", "diamonds": 250, "badge": "+%30 Değer", "usd": "$17.99", "eur": "€19.99", "try": "₺999,99"},
	{"id": "diamonds_1000", "product_id": "com.tahtkilic.kingsage2.diamonds_1000", "name": "İmparator Hazinesi", "diamonds": 1000, "badge": "👑 En İyi Değer", "usd": "$59.99", "eur": "€69.99", "try": "₺2.999,99"},
]

const FALLBACK_SCROLLS: Array[Dictionary] = [
	{"id": "build_10m", "category": "build", "seconds": 600, "cost_diamonds": 5, "name": "İnşaat 10 Dk"},
	{"id": "build_30m", "category": "build", "seconds": 1800, "cost_diamonds": 12, "name": "İnşaat 30 Dk"},
	{"id": "build_60m", "category": "build", "seconds": 3600, "cost_diamonds": 20, "name": "İnşaat 1 Saat"},
	{"id": "train_10m", "category": "train", "seconds": 600, "cost_diamonds": 5, "name": "Asker Eğitimi 10 Dk"},
	{"id": "train_30m", "category": "train", "seconds": 1800, "cost_diamonds": 12, "name": "Asker Eğitimi 30 Dk"},
	{"id": "train_60m", "category": "train", "seconds": 3600, "cost_diamonds": 20, "name": "Asker Eğitimi 1 Saat"},
	{"id": "research_10m", "category": "research", "seconds": 600, "cost_diamonds": 6, "name": "Araştırma 10 Dk"},
	{"id": "research_30m", "category": "research", "seconds": 1800, "cost_diamonds": 15, "name": "Araştırma 30 Dk"},
	{"id": "research_60m", "category": "research", "seconds": 3600, "cost_diamonds": 25, "name": "Araştırma 1 Saat"},
	{"id": "march_10m", "category": "march", "seconds": 600, "cost_diamonds": 8, "name": "Sefer Hızlandırma 10 Dk"},
	{"id": "march_30m", "category": "march", "seconds": 1800, "cost_diamonds": 18, "name": "Sefer Hızlandırma 30 Dk"},
	{"id": "march_60m", "category": "march", "seconds": 3600, "cost_diamonds": 30, "name": "Sefer Hızlandırma 1 Saat"},
]

const TABS := [
	{"key": "build", "label": "🔨 İnşaat"},
	{"key": "train", "label": "⚔️ Eğitim"},
	{"key": "research", "label": "🔬 Araştırma"},
	{"key": "march", "label": "🐴 Sefer"},
	{"key": "diamonds", "label": "💎 Elmas Al"},
]

var _ui_built: bool = false
var _current_tab: String = "build"
var _pending_pack_id: String = ""

var _card: PanelContainer = null
var _diamond_label: Label = null
var _currency_option: OptionButton = null
var _close_btn: Button = null
var _tab_buttons: Dictionary = {}
var _status_panel: PanelContainer = null
var _status_label: Label = null
var _scroll: ScrollContainer = null
var _content_list: VBoxContainer = null


func _ready() -> void:
	name = "RoyalMarketModal"
	layer = 160
	_ensure_ui()
	_connect_signals()
	_refresh_all()


func open_tab(tab_key: String = "build") -> void:
	_current_tab = tab_key if tab_key in ["build", "train", "research", "march", "diamonds"] else "build"
	_ensure_ui()
	_connect_signals()
	if _current_tab == "diamonds":
		var sm := _get_store_manager()
		if sm != null and sm.has_method("fetch_ios_products"):
			sm.call("fetch_ios_products")
	_refresh_all()


func select_tab(tab_key: String = "build") -> void:
	open_tab(tab_key)


func configure(tab_key: String = "build") -> void:
	open_tab(tab_key)


func _get_store_manager() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree and (loop as SceneTree).root != null:
		return (loop as SceneTree).root.get_node_or_null("StoreManager")
	return null


func _get_diamonds() -> int:
	var sm := _get_store_manager()
	if sm != null and sm.has_method("get_diamonds"):
		return int(sm.call("get_diamonds"))
	var loop := Engine.get_main_loop()
	if loop is SceneTree and (loop as SceneTree).root != null:
		var gs := (loop as SceneTree).root.get_node_or_null("GameState")
		if gs != null:
			return int(gs.player.get("diamonds", 35))
	return 35


func _get_scroll_count(scroll_id: String) -> int:
	var sm := _get_store_manager()
	if sm != null and sm.has_method("get_scroll_count"):
		return int(sm.call("get_scroll_count", scroll_id))
	var loop := Engine.get_main_loop()
	if loop is SceneTree and (loop as SceneTree).root != null:
		var gs := (loop as SceneTree).root.get_node_or_null("GameState")
		if gs != null and typeof(gs.player.get("scrolls")) == TYPE_DICTIONARY:
			return int((gs.player["scrolls"] as Dictionary).get(scroll_id, 0))
	return 0


func _get_scrolls_for_category(cat: String) -> Array:
	var sm := _get_store_manager()
	if sm != null and sm.has_method("get_scrolls_for_category"):
		var res = sm.call("get_scrolls_for_category", cat)
		if res is Array and not (res as Array).is_empty():
			return res
	var out: Array = []
	for s in FALLBACK_SCROLLS:
		if str(s.get("category", "")) == cat:
			out.append(s)
	return out


func _get_diamond_packs() -> Array:
	var sm := _get_store_manager()
	if sm != null:
		var raw = sm.get("DIAMOND_PACKS")
		if raw is Array and not (raw as Array).is_empty():
			return raw
	return FALLBACK_PACKS


func _get_pack_price_label(pack: Dictionary) -> String:
	var sm := _get_store_manager()
	if sm != null and sm.has_method("get_pack_price_label"):
		return str(sm.call("get_pack_price_label", pack))
	return str(pack.get("try", pack.get("usd", "$0.99")))


func _connect_signals() -> void:
	var sm := _get_store_manager()
	if sm != null:
		if sm.has_signal("diamonds_changed") and not sm.diamonds_changed.is_connected(_on_store_changed):
			sm.diamonds_changed.connect(_on_store_changed)
		if sm.has_signal("scrolls_changed") and not sm.scrolls_changed.is_connected(_on_store_dict_changed):
			sm.scrolls_changed.connect(_on_store_dict_changed)
		if sm.has_signal("products_updated") and not sm.products_updated.is_connected(_on_store_dict_changed):
			sm.products_updated.connect(_on_store_dict_changed)
		if sm.has_signal("purchase_completed") and not sm.purchase_completed.is_connected(_on_purchase_completed):
			sm.purchase_completed.connect(_on_purchase_completed)


func _on_store_changed(_amt: int) -> void:
	_refresh_diamond_pill()
	_refresh_list()


func _on_store_dict_changed(_d: Dictionary) -> void:
	_refresh_diamond_pill()
	_refresh_list()


func _on_purchase_completed(ok: bool, _product_id: String, diamonds_added: int, message: String) -> void:
	_pending_pack_id = ""
	if ok:
		_show_status("💎 +%d Elmas hesabınıza eklendi!" % diamonds_added, true)
	else:
		_show_status(message if not message.is_empty() else "Satın alma tamamlanamadı.", false)
	_refresh_all()


func _ensure_ui() -> void:
	if _ui_built:
		return
	_ui_built = true

	var vp_size := Vector2(1080.0, 1920.0)
	if is_inside_tree() and get_viewport() != null:
		var r := get_viewport().get_visible_rect().size
		if r.x >= 200.0 and r.y >= 200.0:
			vp_size = r

	var root_ctrl := Control.new()
	root_ctrl.name = "ModalRoot"
	root_ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root_ctrl)

	var dim := ColorRect.new()
	dim.name = "DimBackdrop"
	dim.color = Color(0.03, 0.02, 0.05, 0.86)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			queue_free()
	)
	root_ctrl.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	root_ctrl.add_child(center)

	var card_w := clampf(vp_size.x - 44.0, 500.0, 960.0)
	var card_h := clampf(vp_size.y - 160.0, 660.0, 1320.0)

	_card = PanelContainer.new()
	_card.name = "MarketCard"
	_card.custom_minimum_size = Vector2(card_w, card_h)
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color = Color(0.09, 0.08, 0.13, 0.99)
	card_sb.border_color = Color(0.92, 0.76, 0.36, 1.0)
	card_sb.set_border_width_all(3)
	card_sb.border_width_top = 5
	card_sb.set_corner_radius_all(20)
	card_sb.set_content_margin_all(22)
	card_sb.shadow_color = Color(0, 0, 0, 0.75)
	card_sb.shadow_size = 20
	_card.add_theme_stylebox_override("panel", card_sb)
	center.add_child(_card)

	var main_vb := VBoxContainer.new()
	main_vb.add_theme_constant_override("separation", 14)
	main_vb.mouse_filter = Control.MOUSE_FILTER_PASS
	_card.add_child(main_vb)

	# --- Header ---
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 10)
	hdr.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vb.add_child(hdr)

	var title_lbl := Label.new()
	title_lbl.name = "MarketTitleLabel"
	title_lbl.text = "👑 KRALİYET PAZARI"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.clip_text = true
	title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_lbl.add_theme_font_override("font", FontCinzelBold)
	title_lbl.add_theme_font_size_override("font_size", 28)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.56))
	title_lbl.add_theme_constant_override("outline_size", 0)
	title_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	hdr.add_child(title_lbl)

	var dia_pill := PanelContainer.new()
	dia_pill.name = "DiamondBalancePill"
	var dp_sb := StyleBoxFlat.new()
	dp_sb.bg_color = Color(0.12, 0.22, 0.42, 0.98)
	dp_sb.border_color = Color(0.55, 0.85, 1.0, 0.95)
	dp_sb.set_border_width_all(2)
	dp_sb.set_corner_radius_all(12)
	dp_sb.content_margin_left = 12
	dp_sb.content_margin_right = 12
	dp_sb.content_margin_top = 6
	dp_sb.content_margin_bottom = 6
	dia_pill.add_theme_stylebox_override("panel", dp_sb)
	hdr.add_child(dia_pill)

	_diamond_label = Label.new()
	_diamond_label.text = "💎 %d" % _get_diamonds()
	_diamond_label.add_theme_font_override("font", FontNunitoBold)
	_diamond_label.add_theme_font_size_override("font_size", 22)
	_diamond_label.add_theme_color_override("font_color", Color(0.90, 0.97, 1.0))
	_diamond_label.add_theme_constant_override("outline_size", 0)
	_diamond_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	dia_pill.add_child(_diamond_label)

	if OS.get_name() != "iOS":
		_currency_option = OptionButton.new()
		_currency_option.name = "CurrencySelector"
		_currency_option.custom_minimum_size = Vector2(118, 44)
		_currency_option.add_theme_font_override("font", FontNunitoBold)
		_currency_option.add_theme_font_size_override("font_size", 18)
		_currency_option.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82))
		_currency_option.add_item("₺ TRY", 0)
		_currency_option.add_item("$ USD", 1)
		_currency_option.add_item("€ EUR", 2)
		var cur_sb := StyleBoxFlat.new()
		cur_sb.bg_color = Color(0.16, 0.14, 0.22, 0.98)
		cur_sb.border_color = Color(0.75, 0.62, 0.34, 0.9)
		cur_sb.set_border_width_all(2)
		cur_sb.set_corner_radius_all(10)
		cur_sb.content_margin_left = 10
		cur_sb.content_margin_right = 10
		_currency_option.add_theme_stylebox_override("normal", cur_sb)
		_currency_option.add_theme_stylebox_override("hover", cur_sb)
		_currency_option.add_theme_stylebox_override("pressed", cur_sb)
		var sm := _get_store_manager()
		var pref := str(sm.get("preferred_currency")) if sm != null else "TRY"
		_currency_option.selected = 1 if pref == "USD" else (2 if pref == "EUR" else 0)
		_currency_option.item_selected.connect(_on_currency_selected)
		hdr.add_child(_currency_option)

	_close_btn = Button.new()
	_close_btn.name = "MarketCloseBtn"
	_close_btn.text = "✕"
	_close_btn.custom_minimum_size = Vector2(48, 48)
	_close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_close_btn.add_theme_font_override("font", FontNunitoBold)
	_close_btn.add_theme_font_size_override("font_size", 22)
	var cl_sb := StyleBoxFlat.new()
	cl_sb.bg_color = Color(0.55, 0.14, 0.16, 0.96)
	cl_sb.border_color = Color(0.95, 0.78, 0.40, 1.0)
	cl_sb.set_border_width_all(2)
	cl_sb.set_corner_radius_all(24)
	_close_btn.add_theme_stylebox_override("normal", cl_sb)
	var cl_h := cl_sb.duplicate() as StyleBoxFlat
	cl_h.bg_color = Color(0.72, 0.18, 0.20, 1.0)
	_close_btn.add_theme_stylebox_override("hover", cl_h)
	_close_btn.add_theme_stylebox_override("pressed", cl_h)
	_close_btn.add_theme_color_override("font_color", Color(1, 0.98, 0.94))
	_close_btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	_close_btn.pressed.connect(func(): queue_free())
	hdr.add_child(_close_btn)

	# --- 5 Category Tabs ---
	var tab_bar := HBoxContainer.new()
	tab_bar.name = "MarketTabBar"
	tab_bar.add_theme_constant_override("separation", 8)
	main_vb.add_child(tab_bar)

	for t in TABS:
		var t_key := str(t["key"])
		var btn := Button.new()
		btn.name = "TabMarket_" + t_key
		btn.text = str(t["label"])
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 50)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.add_theme_font_override("font", FontNunitoBold)
		btn.add_theme_font_size_override("font_size", 19)
		btn.add_theme_constant_override("outline_size", 0)
		btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		btn.pressed.connect(func():
			open_tab(t_key)
		)
		tab_bar.add_child(btn)
		_tab_buttons[t_key] = btn

	# --- Status Feedback Banner ---
	_status_panel = PanelContainer.new()
	_status_panel.name = "MarketStatusPanel"
	_status_panel.visible = false
	var st_sb := StyleBoxFlat.new()
	st_sb.bg_color = Color(0.12, 0.28, 0.16, 0.95)
	st_sb.border_color = Color(0.45, 0.90, 0.55, 1.0)
	st_sb.set_border_width_all(2)
	st_sb.set_corner_radius_all(10)
	st_sb.content_margin_left = 14
	st_sb.content_margin_right = 14
	st_sb.content_margin_top = 8
	st_sb.content_margin_bottom = 8
	_status_panel.add_theme_stylebox_override("panel", st_sb)
	main_vb.add_child(_status_panel)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_override("font", FontNunitoBold)
	_status_label.add_theme_font_size_override("font_size", 20)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.90))
	_status_label.add_theme_constant_override("outline_size", 0)
	_status_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	_status_panel.add_child(_status_label)

	# --- Scrollable Content ---
	_scroll = ScrollContainer.new()
	_scroll.name = "MarketScroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.scroll_deadzone = 12
	main_vb.add_child(_scroll)

	_content_list = VBoxContainer.new()
	_content_list.name = "MarketContentList"
	_content_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_list.mouse_filter = Control.MOUSE_FILTER_PASS
	_content_list.add_theme_constant_override("separation", 12)
	_scroll.add_child(_content_list)


func _on_currency_selected(idx: int) -> void:
	var code := "TRY"
	if idx == 1:
		code = "USD"
	elif idx == 2:
		code = "EUR"
	var sm := _get_store_manager()
	if sm != null:
		sm.set("preferred_currency", code)
	_refresh_list()


func _show_status(msg: String, is_ok: bool) -> void:
	if _status_panel == null or _status_label == null:
		return
	var st_sb := StyleBoxFlat.new()
	st_sb.bg_color = Color(0.12, 0.28, 0.16, 0.96) if is_ok else Color(0.38, 0.14, 0.14, 0.96)
	st_sb.border_color = Color(0.45, 0.92, 0.56, 1.0) if is_ok else Color(0.95, 0.42, 0.38, 1.0)
	st_sb.set_border_width_all(2)
	st_sb.set_corner_radius_all(10)
	st_sb.content_margin_left = 14
	st_sb.content_margin_right = 14
	st_sb.content_margin_top = 8
	st_sb.content_margin_bottom = 8
	_status_panel.add_theme_stylebox_override("panel", st_sb)
	_status_label.text = msg
	_status_panel.show()


func _refresh_all() -> void:
	_refresh_diamond_pill()
	_refresh_tabs()
	_refresh_list()


func _refresh_diamond_pill() -> void:
	if _diamond_label != null:
		_diamond_label.text = "💎 %d" % _get_diamonds()


func _refresh_tabs() -> void:
	for k in _tab_buttons.keys():
		var btn: Button = _tab_buttons[k]
		if btn == null:
			continue
		var active := (str(k) == _current_tab)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.32, 0.22, 0.10, 0.98) if active else Color(0.14, 0.12, 0.18, 0.95)
		sb.border_color = Color(1.0, 0.84, 0.36, 1.0) if active else Color(0.42, 0.38, 0.48, 0.75)
		sb.set_border_width_all(2)
		if active:
			sb.border_width_bottom = 4
		sb.set_corner_radius_all(12)
		sb.content_margin_left = 6
		sb.content_margin_right = 6
		btn.add_theme_stylebox_override("normal", sb)
		var hov := sb.duplicate() as StyleBoxFlat
		hov.bg_color = sb.bg_color.lightened(0.10)
		btn.add_theme_stylebox_override("hover", hov)
		btn.add_theme_stylebox_override("pressed", hov)
		btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.72) if active else Color(0.80, 0.78, 0.74))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))


func _refresh_list() -> void:
	if _content_list == null:
		return
	for c in _content_list.get_children():
		_content_list.remove_child(c)
		c.queue_free()

	if _current_tab == "diamonds":
		_populate_diamonds_tab()
	else:
		_populate_scrolls_tab(_current_tab)


func _populate_scrolls_tab(cat: String) -> void:
	var cat_desc := "Seçili kategorideki aktif veya sıradaki işlemleri hızlandırın. Artan süre sıradaki işe aktarılır."
	match cat:
		"build":
			cat_desc = "🔨 Bina inşaat sürelerini kısaltır. Artan süre inşaat kuyruğundaki sonraki binaya devreder."
		"train":
			cat_desc = "⚔️ Kışla ve Köşk asker eğitim sürelerini hızlandırır."
		"research":
			cat_desc = "🔬 Kışla birim araştırma sürelerini kısaltır."
		"march":
			cat_desc = "🐴 Gidiş veya dönüşteki ordu ve ticaret seferlerinin varış süresini kısaltır."

	var intro := PanelContainer.new()
	intro.mouse_filter = Control.MOUSE_FILTER_PASS
	var i_sb := StyleBoxFlat.new()
	i_sb.bg_color = Color(0.13, 0.11, 0.18, 0.94)
	i_sb.border_color = Color(0.55, 0.48, 0.34, 0.75)
	i_sb.set_border_width_all(1)
	i_sb.set_corner_radius_all(12)
	i_sb.set_content_margin_all(12)
	intro.add_theme_stylebox_override("panel", i_sb)
	var intro_lbl := Label.new()
	intro_lbl.text = cat_desc
	intro_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_lbl.add_theme_font_override("font", FontNunitoSemiBold)
	intro_lbl.add_theme_font_size_override("font_size", 19)
	intro_lbl.add_theme_color_override("font_color", Color(0.90, 0.87, 0.78))
	intro_lbl.add_theme_constant_override("outline_size", 0)
	intro_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	intro.add_child(intro_lbl)
	_content_list.add_child(intro)

	var diamonds := _get_diamonds()
	var scrolls := _get_scrolls_for_category(cat)

	for s_raw in scrolls:
		var s: Dictionary = s_raw
		var s_id := str(s.get("id", ""))
		var s_name := str(s.get("name", s_id))
		var secs := int(s.get("seconds", 600))
		var cost := int(s.get("cost_diamonds", 5))
		var owned := _get_scroll_count(s_id)
		var dur_label := "1 Saat" if secs >= 3600 else ("%d Dakika" % (secs / 60))

		var card := PanelContainer.new()
		card.name = "ScrollCard_" + s_id
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		var c_sb := StyleBoxFlat.new()
		c_sb.bg_color = Color(0.14, 0.12, 0.19, 0.98)
		c_sb.border_color = Color(0.75, 0.62, 0.32, 0.88)
		c_sb.set_border_width_all(2)
		c_sb.set_corner_radius_all(14)
		c_sb.content_margin_left = 16
		c_sb.content_margin_right = 16
		c_sb.content_margin_top = 14
		c_sb.content_margin_bottom = 14
		card.add_theme_stylebox_override("panel", c_sb)

		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_theme_constant_override("separation", 14)
		card.add_child(row)

		var icon_box := PanelContainer.new()
		icon_box.custom_minimum_size = Vector2(68, 68)
		icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic_sb := StyleBoxFlat.new()
		ic_sb.bg_color = Color(0.22, 0.17, 0.10, 0.98)
		ic_sb.border_color = Color(0.95, 0.78, 0.34, 0.95)
		ic_sb.set_border_width_all(2)
		ic_sb.set_corner_radius_all(12)
		icon_box.add_theme_stylebox_override("panel", ic_sb)
		var ic_lbl := Label.new()
		ic_lbl.text = "📜"
		ic_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ic_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ic_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic_lbl.add_theme_font_size_override("font_size", 32)
		icon_box.add_child(ic_lbl)
		row.add_child(icon_box)

		var info_vb := VBoxContainer.new()
		info_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vb.mouse_filter = Control.MOUSE_FILTER_PASS
		info_vb.add_theme_constant_override("separation", 4)
		row.add_child(info_vb)

		var name_lbl := Label.new()
		name_lbl.text = s_name
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_lbl.add_theme_font_override("font", FontNunitoBold)
		name_lbl.add_theme_font_size_override("font_size", 24)
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.94, 0.72))
		name_lbl.add_theme_constant_override("outline_size", 0)
		name_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		info_vb.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = "Süreyi %s azaltır • Fiyat: 💎 %d Elmas" % [dur_label, cost]
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		desc_lbl.add_theme_font_override("font", FontNunitoSemiBold)
		desc_lbl.add_theme_font_size_override("font_size", 18)
		desc_lbl.add_theme_color_override("font_color", Color(0.84, 0.82, 0.76))
		desc_lbl.add_theme_constant_override("outline_size", 0)
		desc_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		info_vb.add_child(desc_lbl)

		var inv_pill := PanelContainer.new()
		inv_pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		inv_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var iv_sb := StyleBoxFlat.new()
		iv_sb.bg_color = Color(0.12, 0.28, 0.16, 0.95) if owned > 0 else Color(0.18, 0.16, 0.24, 0.95)
		iv_sb.border_color = Color(0.45, 0.88, 0.52, 0.95) if owned > 0 else Color(0.42, 0.40, 0.50, 0.80)
		iv_sb.set_border_width_all(1)
		iv_sb.set_corner_radius_all(8)
		iv_sb.content_margin_left = 10
		iv_sb.content_margin_right = 10
		iv_sb.content_margin_top = 2
		iv_sb.content_margin_bottom = 2
		inv_pill.add_theme_stylebox_override("panel", iv_sb)
		var inv_lbl := Label.new()
		inv_lbl.text = "Sahip: %d adet" % owned
		inv_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inv_lbl.add_theme_font_override("font", FontNunitoBold)
		inv_lbl.add_theme_font_size_override("font_size", 17)
		inv_lbl.add_theme_color_override("font_color", Color(0.55, 0.96, 0.62) if owned > 0 else Color(0.75, 0.75, 0.82))
		inv_lbl.add_theme_constant_override("outline_size", 0)
		inv_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		inv_pill.add_child(inv_lbl)
		info_vb.add_child(inv_pill)

		var buy_btn := Button.new()
		buy_btn.name = "BuyScrollBtn_" + s_id
		buy_btn.text = "💎 %d Satın Al" % cost
		buy_btn.custom_minimum_size = Vector2(180, 56)
		buy_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		buy_btn.mouse_filter = Control.MOUSE_FILTER_PASS
		buy_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		buy_btn.add_theme_font_override("font", FontNunitoBold)
		buy_btn.add_theme_font_size_override("font_size", 20)
		buy_btn.add_theme_constant_override("outline_size", 0)
		buy_btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		var can_buy := diamonds >= cost
		var b_sb := StyleBoxFlat.new()
		b_sb.bg_color = Color(0.14, 0.34, 0.58, 1.0) if can_buy else Color(0.24, 0.20, 0.26, 0.95)
		b_sb.border_color = Color(0.58, 0.88, 1.0, 1.0) if can_buy else Color(0.45, 0.40, 0.50, 0.8)
		b_sb.set_border_width_all(2)
		b_sb.set_corner_radius_all(12)
		buy_btn.add_theme_stylebox_override("normal", b_sb)
		var b_hov := b_sb.duplicate() as StyleBoxFlat
		b_hov.bg_color = b_sb.bg_color.lightened(0.14)
		buy_btn.add_theme_stylebox_override("hover", b_hov)
		buy_btn.add_theme_stylebox_override("pressed", b_hov)
		buy_btn.add_theme_color_override("font_color", Color(1.0, 0.98, 0.94))
		buy_btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
		buy_btn.pressed.connect(_on_buy_scroll_pressed.bind(s_id, s_name, cost))
		row.add_child(buy_btn)

		_content_list.add_child(card)


func _on_buy_scroll_pressed(scroll_id: String, scroll_name: String, cost: int) -> void:
	var sm := _get_store_manager()
	if sm == null or not sm.has_method("buy_scroll"):
		_show_status("Mağaza servisi hazır değil.", false)
		return
	var res = sm.call("buy_scroll", scroll_id, 1)
	if typeof(res) == TYPE_DICTIONARY and bool((res as Dictionary).get("ok", false)):
		_show_status("✅ %s envanterinize eklendi!" % scroll_name, true)
		_refresh_all()
	else:
		var err := str((res as Dictionary).get("error", "")) if typeof(res) == TYPE_DICTIONARY else ""
		if _get_diamonds() < cost:
			_show_status("💎 Yetersiz elmas (%d gerekli). 'Elmas Al' sekmesinden edinebilirsiniz." % cost, false)
		else:
			_show_status(err if not err.is_empty() else "Parşömen satın alınamadı.", false)


func _populate_diamonds_tab() -> void:
	var packs := _get_diamond_packs()
	for p_raw in packs:
		var p: Dictionary = p_raw
		var p_id := str(p.get("id", ""))
		var p_name := str(p.get("name", p_id))
		var d_amt := int(p.get("diamonds", 0))
		var badge := str(p.get("badge", ""))
		var price_str := _get_pack_price_label(p)
		var is_featured := badge.contains("Popüler") or badge.contains("İyi Değer")

		var card := PanelContainer.new()
		card.name = "PackCard_" + p_id
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		var c_sb := StyleBoxFlat.new()
		c_sb.bg_color = Color(0.16, 0.14, 0.24, 0.98) if is_featured else Color(0.13, 0.12, 0.19, 0.98)
		c_sb.border_color = Color(0.98, 0.80, 0.34, 1.0) if is_featured else Color(0.45, 0.65, 0.90, 0.85)
		c_sb.set_border_width_all(3 if is_featured else 2)
		c_sb.set_corner_radius_all(14)
		c_sb.content_margin_left = 16
		c_sb.content_margin_right = 16
		c_sb.content_margin_top = 14
		c_sb.content_margin_bottom = 14
		card.add_theme_stylebox_override("panel", c_sb)

		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_theme_constant_override("separation", 14)
		card.add_child(row)

		var gem_box := PanelContainer.new()
		gem_box.custom_minimum_size = Vector2(74, 68)
		gem_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		gem_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var gb_sb := StyleBoxFlat.new()
		gb_sb.bg_color = Color(0.10, 0.22, 0.42, 0.98)
		gb_sb.border_color = Color(0.55, 0.86, 1.0, 0.95)
		gb_sb.set_border_width_all(2)
		gb_sb.set_corner_radius_all(12)
		gem_box.add_theme_stylebox_override("panel", gb_sb)
		var g_lbl := Label.new()
		g_lbl.text = "💎\n%d" % d_amt
		g_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		g_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		g_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g_lbl.add_theme_font_override("font", FontNunitoBold)
		g_lbl.add_theme_font_size_override("font_size", 18)
		g_lbl.add_theme_color_override("font_color", Color(0.92, 0.98, 1.0))
		g_lbl.add_theme_constant_override("outline_size", 0)
		g_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		gem_box.add_child(g_lbl)
		row.add_child(gem_box)

		var info_vb := VBoxContainer.new()
		info_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vb.mouse_filter = Control.MOUSE_FILTER_PASS
		info_vb.add_theme_constant_override("separation", 4)
		row.add_child(info_vb)

		var top_line := HBoxContainer.new()
		top_line.mouse_filter = Control.MOUSE_FILTER_PASS
		top_line.add_theme_constant_override("separation", 8)
		info_vb.add_child(top_line)

		var name_lbl := Label.new()
		name_lbl.text = p_name
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_lbl.add_theme_font_override("font", FontNunitoBold)
		name_lbl.add_theme_font_size_override("font_size", 24)
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.78))
		name_lbl.add_theme_constant_override("outline_size", 0)
		name_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		top_line.add_child(name_lbl)

		if not badge.is_empty():
			var b_pill := PanelContainer.new()
			b_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var bp_sb := StyleBoxFlat.new()
			bp_sb.bg_color = Color(0.86, 0.64, 0.16, 0.95) if is_featured else Color(0.20, 0.30, 0.44, 0.95)
			bp_sb.set_corner_radius_all(8)
			bp_sb.content_margin_left = 8
			bp_sb.content_margin_right = 8
			bp_sb.content_margin_top = 2
			bp_sb.content_margin_bottom = 2
			b_pill.add_theme_stylebox_override("panel", bp_sb)
			var b_lbl := Label.new()
			b_lbl.text = badge
			b_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b_lbl.add_theme_font_override("font", FontNunitoBold)
			b_lbl.add_theme_font_size_override("font_size", 15)
			b_lbl.add_theme_color_override("font_color", Color(0.10, 0.06, 0.02) if is_featured else Color(0.85, 0.93, 1.0))
			b_lbl.add_theme_constant_override("outline_size", 0)
			b_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
			b_pill.add_child(b_lbl)
			top_line.add_child(b_pill)

		var sub_lbl := Label.new()
		sub_lbl.text = "+%d Kraliyet Elması • Hızlandırma parşömenleri için" % d_amt
		sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sub_lbl.add_theme_font_override("font", FontNunitoSemiBold)
		sub_lbl.add_theme_font_size_override("font_size", 18)
		sub_lbl.add_theme_color_override("font_color", Color(0.78, 0.84, 0.92))
		sub_lbl.add_theme_constant_override("outline_size", 0)
		sub_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		info_vb.add_child(sub_lbl)

		var buy_btn := Button.new()
		buy_btn.name = "BuyPackBtn_" + p_id
		buy_btn.text = price_str if _pending_pack_id != p_id else "İşleniyor..."
		buy_btn.disabled = (_pending_pack_id == p_id)
		buy_btn.custom_minimum_size = Vector2(170, 56)
		buy_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		buy_btn.mouse_filter = Control.MOUSE_FILTER_PASS
		buy_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		buy_btn.add_theme_font_override("font", FontNunitoBold)
		buy_btn.add_theme_font_size_override("font_size", 22)
		buy_btn.add_theme_constant_override("outline_size", 0)
		buy_btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		var p_sb := StyleBoxFlat.new()
		p_sb.bg_color = Color(0.18, 0.56, 0.30, 1.0)
		p_sb.border_color = Color(0.56, 0.94, 0.66, 1.0)
		p_sb.set_border_width_all(2)
		p_sb.set_corner_radius_all(12)
		buy_btn.add_theme_stylebox_override("normal", p_sb)
		var p_hov := p_sb.duplicate() as StyleBoxFlat
		p_hov.bg_color = Color(0.24, 0.68, 0.38, 1.0)
		buy_btn.add_theme_stylebox_override("hover", p_hov)
		buy_btn.add_theme_stylebox_override("pressed", p_hov)
		buy_btn.add_theme_color_override("font_color", Color(1, 1, 1))
		buy_btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
		buy_btn.pressed.connect(_on_buy_pack_pressed.bind(p_id))
		row.add_child(buy_btn)

		_content_list.add_child(card)

	if OS.get_name() == "iOS":
		var restore_btn := Button.new()
		restore_btn.name = "RestorePurchasesBtn"
		restore_btn.text = "Satın Alımları Geri Yükle"
		restore_btn.custom_minimum_size = Vector2(0, 50)
		restore_btn.mouse_filter = Control.MOUSE_FILTER_PASS
		restore_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		restore_btn.add_theme_font_override("font", FontNunitoBold)
		restore_btn.add_theme_font_size_override("font_size", 20)
		var r_sb := StyleBoxFlat.new()
		r_sb.bg_color = Color(0.16, 0.14, 0.22, 0.95)
		r_sb.border_color = Color(0.58, 0.52, 0.38, 0.90)
		r_sb.set_border_width_all(2)
		r_sb.set_corner_radius_all(12)
		restore_btn.add_theme_stylebox_override("normal", r_sb)
		restore_btn.add_theme_color_override("font_color", Color(0.90, 0.88, 0.80))
		restore_btn.pressed.connect(_on_restore_pressed)
		_content_list.add_child(restore_btn)


func _on_buy_pack_pressed(pack_id: String) -> void:
	var sm := _get_store_manager()
	if sm == null or not sm.has_method("buy_diamond_pack"):
		_show_status("Satın alma servisi hazır değil.", false)
		return
	_pending_pack_id = pack_id
	_refresh_list()
	sm.call("buy_diamond_pack", pack_id, func(_ok: bool, _msg: String = ""):
		_pending_pack_id = ""
		_refresh_all()
	)


func _on_restore_pressed() -> void:
	var sm := _get_store_manager()
	if sm != null and sm.has_method("restore_ios_purchases"):
		_show_status("Satın alımlar kontrol ediliyor...", true)
		sm.call("restore_ios_purchases", func(_ok: bool, msg: String = ""):
			if not msg.is_empty():
				_show_status(msg, _ok)
			_refresh_all()
		)
