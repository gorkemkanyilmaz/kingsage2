extends Control
## Reports — Raporlar ekranı (Taht ve Kılıç / A-ARAYUZ).

@onready var report_list: VBoxContainer = $Container/Scroll/List
@onready var detail_panel: PanelContainer = $DetailPanel
@onready var detail_text: Label = $DetailPanel/VBox/Scroll/DetailText
@onready var close_detail_btn: Button = $DetailPanel/VBox/CloseBtn


func _ready() -> void:
	detail_panel.hide()
	close_detail_btn.pressed.connect(func(): detail_panel.hide())
	_populate_reports()


func _populate_reports() -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null:
		return

	for child in report_list.get_children():
		child.queue_free()

	var reports: Array = gs.reports
	if reports.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Henüz okunmamış veya geçmiş rapor bulunmuyor."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		report_list.add_child(empty_lbl)
		return

	for rep in reports:
		if typeof(rep) != TYPE_DICTIONARY:
			continue
		var r: Dictionary = rep
		var type: String = str(r.get("type", "battle"))
		var title: String = "📜 Savaş Raporu"
		if type == "spy":
			title = "👁️ Casusluk Raporu"
		elif type == "trade":
			title = "⚖️ Ticaret Teslimatı"

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 80)
		btn.text = "%s — %s" % [title, Time.get_datetime_string_from_unix_time(int(r.get("unix", 0)))]
		btn.pressed.connect(func(): _show_detail(r))
		report_list.add_child(btn)


func _show_detail(rep: Dictionary) -> void:
	var text := "Rapor Detayı:\n"
	text += "Tür: %s\n" % str(rep.get("type", ""))
	text += "Zaman: %s\n" % Time.get_datetime_string_from_unix_time(int(rep.get("unix", 0)))
	var data: Dictionary = rep.get("data", {})
	if not data.is_empty():
		text += "Veri:\n" + JSON.stringify(data, "  ")
	detail_text.text = text
	detail_panel.show()
