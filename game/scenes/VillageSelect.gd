extends Control
## VillageSelect — Başlangıç yönü ve köy seçimi ekranı (Taht ve Kılıç / A-ARAYUZ).

const WorldGeneratorScript := preload("res://scripts/world/WorldGenerator.gd")
const VillageModelScript := preload("res://scripts/model/VillageModel.gd")

@onready var btn_nw: Button = $Center/VBox/Grid/BtnNW
@onready var btn_ne: Button = $Center/VBox/Grid/BtnNE
@onready var btn_sw: Button = $Center/VBox/Grid/BtnSW
@onready var btn_se: Button = $Center/VBox/Grid/BtnSE
@onready var btn_random: Button = $Center/VBox/BtnRandom


func _ready() -> void:
	btn_nw.pressed.connect(func(): _start_game(25, 25))
	btn_ne.pressed.connect(func(): _start_game(175, 25))
	btn_sw.pressed.connect(func(): _start_game(25, 175))
	btn_se.pressed.connect(func(): _start_game(175, 175))
	btn_random.pressed.connect(func(): _start_game(100, 100))


func _start_game(target_x: int, target_y: int) -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null:
		return

	gs.reset()
	var seed_val := int(Time.get_unix_time_from_system())
	var world := WorldGeneratorScript.generate(seed_val, 100)
	var tiles: Dictionary = world.get("tiles", {})

	var free_spot: Vector2i = WorldGeneratorScript.find_free_spot(tiles, target_x, target_y, WorldGeneratorScript.SIZE)
	if free_spot.x < 0:
		free_spot = Vector2i(target_x, target_y)

	var player_vid := world["villages"].size() + 1
	var player_v: Dictionary = VillageModelScript.create(player_vid, "Başkent", free_spot.x, free_spot.y, "Oyuncu", false)
	player_v["is_bot"] = false

	world["villages"].append(player_v)
	world["tiles"][WorldGeneratorScript.tile_key(free_spot.x, free_spot.y)] = player_vid

	gs.world = world
	gs.villages = world["villages"].duplicate(true)
	gs.player = {
		"id": 1,
		"name": "Kral",
		"points": int(player_v.get("points", 110)),
		"protection_until_unix": int(Time.get_unix_time_from_system()) + (5 * 86400),
		"conquest_protection_until_unix": 0,
		"premium": false,
	}
	gs.active_village_id = player_vid

	var sm = Engine.get_main_loop().root.get_node_or_null("SaveManager") if Engine.get_main_loop() is SceneTree else null
	if sm != null:
		sm.save_game()

	get_tree().change_scene_to_file("res://scenes/Village.tscn")
