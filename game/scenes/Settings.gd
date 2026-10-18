extends Control
## Settings — Ayarlar ekranı (Taht ve Kılıç / A-ARAYUZ).

@onready var profile_option: OptionButton = $Center/VBox/ProfileRow/Option
@onready var speed_spin: SpinBox = $Center/VBox/SpeedRow/Spin
@onready var btn_back: Button = $Center/VBox/BtnBack
@onready var btn_main_menu: Button = $Center/VBox/BtnMainMenu


func _ready() -> void:
	profile_option.clear()
	profile_option.add_item("Türkiye (TR) — Gece Bonusu 00:00-06:00, Kont 80 Alan", 0)
	profile_option.add_item("Global (EN) — Gece Bonusu Yok, Kont 100 Alan", 1)

	var cfg = Engine.get_main_loop().root.get_node_or_null("GameConfig") if Engine.get_main_loop() is SceneTree else null
	if cfg != null:
		var prof: String = str(cfg.get("world_profile", "tr"))
		profile_option.selected = 1 if prof == "en" else 0
		speed_spin.value = float(cfg.get("game_speed", 1.0))

	profile_option.item_selected.connect(_on_profile_selected)
	speed_spin.value_changed.connect(_on_speed_changed)

	btn_back.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/Village.tscn"))

	btn_main_menu.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))


func _on_profile_selected(idx: int) -> void:
	var cfg = Engine.get_main_loop().root.get_node_or_null("GameConfig") if Engine.get_main_loop() is SceneTree else null
	if cfg != null:
		var prof_name := "en" if idx == 1 else "tr"
		cfg.apply_profile(prof_name)


func _on_speed_changed(val: float) -> void:
	var cfg = Engine.get_main_loop().root.get_node_or_null("GameConfig") if Engine.get_main_loop() is SceneTree else null
	if cfg != null:
		cfg.game_speed = val
