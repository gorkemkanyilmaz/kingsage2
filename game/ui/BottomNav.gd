extends PanelContainer
## BottomNav — Modern Alt Navigasyon Menüsü (Taht ve Kılıç / A-ARAYUZ).
## Birebir ahşap oyma dokusu ve 6 adet zengin buton yuvası (Köy, Harita, Rapor, Mesajlar, Sıra, Menü).

signal tab_selected(tab_name: String)

@onready var btn_village: Button = $HBox/BtnVillage
@onready var btn_map: Button = $HBox/BtnMap
@onready var btn_reports: Button = $HBox/BtnReports
@onready var btn_messages: Button = $HBox/BtnMessages
@onready var btn_ranking: Button = $HBox/BtnRanking
@onready var btn_menu: Button = $HBox/BtnMenu

@onready var report_badge: PanelContainer = $HBox/BtnReports/ReportBadge
@onready var badge_label: Label = $HBox/BtnReports/ReportBadge/BadgeLabel
@onready var message_badge: PanelContainer = $HBox/BtnMessages/MessageBadge
@onready var message_badge_label: Label = $HBox/BtnMessages/MessageBadge/BadgeLabel


const FontNunitoBold: Font = preload("res://assets/fonts/Nunito-Bold.ttf")


func _ready() -> void:
	_style_buttons()
	_setup_badge_labels()
	btn_village.pressed.connect(func(): _on_tab_pressed("village", "res://scenes/Village.tscn"))
	btn_map.pressed.connect(func(): _on_tab_pressed("map", "res://scenes/WorldMap.tscn"))
	btn_reports.pressed.connect(func():
		var reports_script = load("res://scenes/Reports.gd")
		if reports_script:
			reports_script.initial_tab = "reports"
		_on_tab_pressed("reports", "res://scenes/Reports.tscn")
	)
	btn_messages.pressed.connect(func():
		var reports_script = load("res://scenes/Reports.gd")
		if reports_script:
			reports_script.initial_tab = "messages"
		_on_tab_pressed("messages", "res://scenes/Reports.tscn")
	)
	btn_ranking.pressed.connect(func(): _on_tab_pressed("ranking", "res://scenes/Ranking.tscn"))
	btn_menu.pressed.connect(func(): _on_tab_pressed("settings", "res://scenes/Settings.tscn"))

	_update_badges()

	var eb = Engine.get_main_loop().root.get_node_or_null("EventBus") if Engine.get_main_loop() is SceneTree else null
	if eb != null:
		if eb.has_signal("report_created") and not eb.report_created.is_connected(_on_event_update):
			eb.report_created.connect(_on_event_update)
		if eb.has_signal("message_created") and not eb.message_created.is_connected(_on_event_update):
			eb.message_created.connect(_on_event_update)
		if eb.has_signal("state_changed") and not eb.state_changed.is_connected(_on_event_update):
			eb.state_changed.connect(_on_event_update)


func _setup_badge_labels() -> void:
	for lbl in [badge_label, message_badge_label]:
		if lbl != null:
			lbl.add_theme_font_override("font", FontNunitoBold)
			lbl.add_theme_font_size_override("font_size", 22)
			lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
			lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
			lbl.add_theme_constant_override("shadow_offset_y", 1)


func _on_event_update(_arg = null) -> void:
	_update_badges()


func update_badge() -> void:
	_update_badges()


func _update_badges() -> void:
	_update_report_badge()
	_update_message_badge()


func _update_report_badge() -> void:
	if report_badge == null:
		report_badge = get_node_or_null("HBox/BtnReports/ReportBadge")
	if badge_label == null and report_badge != null:
		badge_label = report_badge.get_node_or_null("BadgeLabel")

	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null:
		if report_badge != null:
			report_badge.visible = false
		return

	var player_name := str(gs.player.get("name", "Kral"))
	var player_vids: Array = []
	if "villages" in gs and gs.villages is Array:
		for v in gs.villages:
			if typeof(v) == TYPE_DICTIONARY and str((v as Dictionary).get("owner", "")) == player_name:
				player_vids.append(int((v as Dictionary).get("id", -1)))

	var unread := 0
	if "reports" in gs and gs.reports is Array:
		for rep in gs.reports:
			if typeof(rep) == TYPE_DICTIONARY and bool((rep as Dictionary).get("unread", false)):
				var r := rep as Dictionary
				var vid := int(r.get("village_id", -1))
				var rdata = r.get("data", {})
				var a_owner := ""
				var d_owner := ""
				var f_vid := -1
				var t_vid := -1
				if typeof(rdata) == TYPE_DICTIONARY:
					a_owner = str(rdata.get("attacker_name", rdata.get("attacker_owner", "")))
					d_owner = str(rdata.get("defender_name", ""))
					f_vid = int(rdata.get("from_village_id", -1))
					t_vid = int(rdata.get("target_village_id", -1))
				if vid in player_vids or f_vid in player_vids or t_vid in player_vids or a_owner == player_name or d_owner == player_name:
					unread += 1

	if report_badge != null:
		report_badge.visible = (unread > 0)
		if badge_label != null:
			_setup_badge_labels()
			badge_label.text = str(unread) if unread <= 99 else "99+"


func _update_message_badge() -> void:
	if message_badge == null:
		message_badge = get_node_or_null("HBox/BtnMessages/MessageBadge")
	if message_badge_label == null and message_badge != null:
		message_badge_label = message_badge.get_node_or_null("BadgeLabel")

	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null:
		if message_badge != null:
			message_badge.visible = false
		return

	var player_name := str(gs.player.get("name", "Kral"))
	var unread_msg := 0
	if "messages" in gs and gs.messages is Array:
		for msg in gs.messages:
			if typeof(msg) == TYPE_DICTIONARY:
				var m := msg as Dictionary
				if str(m.get("to", "")) == player_name and not bool(m.get("read", true)):
					unread_msg += 1

	if message_badge != null:
		message_badge.visible = (unread_msg > 0)
		if message_badge_label != null:
			_setup_badge_labels()
			message_badge_label.text = str(unread_msg) if unread_msg <= 99 else "99+"


func _style_buttons() -> void:
	var buttons = [btn_village, btn_map, btn_reports, btn_messages, btn_ranking, btn_menu]
	var cur_path := ""
	var current_scene: Node = null
	if is_inside_tree() and get_tree() != null and get_tree().current_scene != null:
		current_scene = get_tree().current_scene
		cur_path = current_scene.scene_file_path

	for btn in buttons:
		if btn == null:
			continue
		var is_active := false
		if cur_path.contains("Village") and btn == btn_village:
			is_active = true
		elif cur_path.contains("WorldMap") and btn == btn_map:
			is_active = true
		elif cur_path.contains("Reports"):
			var tab = current_scene.get("_current_tab") if current_scene != null else "reports"
			if (tab == "messages" or tab == "new_message") and btn == btn_messages:
				is_active = true
			elif tab != "messages" and tab != "new_message" and btn == btn_reports:
				is_active = true
		elif (cur_path.contains("Ranking") or cur_path.contains("Alliance")) and btn == btn_ranking:
			is_active = true
		elif cur_path.contains("Settings") and btn == btn_menu:
			is_active = true

		var empty_sb := StyleBoxEmpty.new()
		var active_sb := StyleBoxFlat.new()
		active_sb.set_corner_radius_all(14)
		active_sb.bg_color = Color(1.0, 0.85, 0.35, 0.12)
		active_sb.border_color = Color(1.0, 0.85, 0.40, 0.85)
		active_sb.set_border_width_all(2)
		active_sb.shadow_color = Color(1.0, 0.8, 0.2, 0.35)
		active_sb.shadow_size = 6

		var hover_sb := StyleBoxFlat.new()
		hover_sb.set_corner_radius_all(14)
		hover_sb.bg_color = Color(1.0, 0.90, 0.45, 0.16)
		hover_sb.border_color = Color(1.0, 0.90, 0.50, 0.80)
		hover_sb.set_border_width_all(2)
		hover_sb.shadow_color = Color(1.0, 0.85, 0.3, 0.4)
		hover_sb.shadow_size = 8

		if is_active:
			btn.add_theme_stylebox_override("normal", active_sb)
		else:
			btn.add_theme_stylebox_override("normal", empty_sb)

		btn.add_theme_stylebox_override("hover", hover_sb)
		btn.add_theme_stylebox_override("pressed", active_sb)
		btn.add_theme_stylebox_override("focus", empty_sb)

		btn.pivot_offset = Vector2(80, 124)
		if not btn.is_connected("mouse_entered", Callable(self, "_on_btn_mouse_entered").bind(btn)):
			btn.mouse_entered.connect(_on_btn_mouse_entered.bind(btn))
			btn.mouse_exited.connect(_on_btn_mouse_exited.bind(btn))
			btn.button_down.connect(_on_btn_button_down.bind(btn))
			btn.button_up.connect(_on_btn_button_up.bind(btn))


func _on_btn_mouse_entered(btn: Button) -> void:
	if btn == null or not is_instance_valid(btn): return
	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2(1.03, 1.03), 0.12)


func _on_btn_mouse_exited(btn: Button) -> void:
	if btn == null or not is_instance_valid(btn): return
	var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12)


func _on_btn_button_down(btn: Button) -> void:
	if btn == null or not is_instance_valid(btn): return
	var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2(0.97, 0.97), 0.08)


func _on_btn_button_up(btn: Button) -> void:
	if btn == null or not is_instance_valid(btn): return
	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15)


func _on_tab_pressed(tab_name: String, target_scene: String) -> void:
	tab_selected.emit(tab_name)
	var wm = Engine.get_main_loop().root.get_node_or_null("WorldManager") if Engine.get_main_loop() is SceneTree else null
	if wm != null and wm.has_method("save_active_world"):
		wm.save_active_world()
	var tree := get_tree()
	if tree != null:
		var current = tree.current_scene
		if current != null and current.scene_file_path == target_scene:
			if target_scene.contains("Reports"):
				if current.has_method("_select_tab"):
					current._select_tab(tab_name)
					_style_buttons()
			return

		if ResourceLoader.exists(target_scene):
			tree.change_scene_to_file(target_scene)
