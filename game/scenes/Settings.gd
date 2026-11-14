extends Control
## Settings — Ayarlar ekranı (Taht ve Kılıç / A-ARAYUZ).

@onready var profile_option: OptionButton = $Center/VBox/ProfileRow/Option
@onready var btn_tutorial: Button = $Center/VBox/BtnTutorialReplay
@onready var btn_back: Button = $Center/VBox/BtnBack
@onready var btn_main_menu: Button = $Center/VBox/BtnMainMenu


func _ready() -> void:
	profile_option.clear()
	profile_option.add_item("Türkiye (TR) — Gece Bonusu 00:00-06:00, Kont 80 Alan", 0)
	profile_option.add_item("Global (EN) — Gece Bonusu Yok, Kont 100 Alan", 1)

	# Açılır liste ayrı bir Window olduğundan temayı miras almaz; elle bağla.
	profile_option.get_popup().theme = load("res://themes/TahtVeKilic.tres")

	var cfg = Engine.get_main_loop().root.get_node_or_null("GameConfig") if Engine.get_main_loop() is SceneTree else null
	if cfg != null:
		var prof: String = str(cfg.get("current_profile"))
		profile_option.selected = 1 if prof == "en" else 0

	if not profile_option.item_selected.is_connected(_on_profile_selected):
		profile_option.item_selected.connect(_on_profile_selected)

	if btn_tutorial != null and not btn_tutorial.pressed.is_connected(_on_btn_tutorial_pressed):
		btn_tutorial.pressed.connect(_on_btn_tutorial_pressed)

	if not btn_back.pressed.is_connected(_on_btn_back_pressed):
		btn_back.pressed.connect(_on_btn_back_pressed)

	if not btn_main_menu.pressed.is_connected(_on_btn_main_menu_pressed):
		btn_main_menu.pressed.connect(_on_btn_main_menu_pressed)


func _on_btn_tutorial_pressed() -> void:
	var tm = Engine.get_main_loop().root.get_node_or_null("TutorialManager") if Engine.get_main_loop() is SceneTree else null
	if tm != null and tm.has_method("restart_tutorial"):
		tm.restart_tutorial()
	get_tree().change_scene_to_file("res://scenes/Village.tscn")


func _on_btn_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Village.tscn")


func _on_btn_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/VillageSelect.tscn")


func _on_profile_selected(idx: int) -> void:
	var cfg = Engine.get_main_loop().root.get_node_or_null("GameConfig") if Engine.get_main_loop() is SceneTree else null
	if cfg != null and cfg.has_method("apply_profile"):
		var prof_name := "en" if idx == 1 else "tr"
		cfg.apply_profile(prof_name)
