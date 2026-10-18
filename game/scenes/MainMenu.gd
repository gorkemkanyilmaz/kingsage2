extends Control
## MainMenu — Ana Menü ekranı (Taht ve Kılıç / A-ARAYUZ).

@onready var btn_new_game: Button = $Center/VBox/BtnNewGame
@onready var btn_continue: Button = $Center/VBox/BtnContinue
@onready var btn_settings: Button = $Center/VBox/BtnSettings
@onready var btn_quit: Button = $Center/VBox/BtnQuit


func _ready() -> void:
	var sm = Engine.get_main_loop().root.get_node_or_null("SaveManager") if Engine.get_main_loop() is SceneTree else null
	var has_save: bool = bool(sm.has_save()) if sm != null else false

	btn_continue.disabled = not has_save

	btn_new_game.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/VillageSelect.tscn"))

	btn_continue.pressed.connect(func():
		if sm != null and sm.load_game():
			get_tree().change_scene_to_file("res://scenes/Village.tscn"))

	btn_settings.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/Settings.tscn"))

	btn_quit.pressed.connect(func():
		get_tree().quit(0))
