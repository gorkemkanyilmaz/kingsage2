extends PanelContainer
## ResourceBar — Üst kaynak ve köy durumu çubuğu (Taht ve Kılıç / A-ARAYUZ).

const Palette := preload("res://themes/Palette.gd")
const RulesEngineScript := preload("res://scripts/rules/RulesEngine.gd")
const VillageModelScript := preload("res://scripts/model/VillageModel.gd")

@onready var village_name_label: Label = $HBox/VillageInfo/VillageName
@onready var points_label: Label = $HBox/VillageInfo/Points
@onready var wood_label: Label = $HBox/Resources/WoodBox/WoodLabel
@onready var stone_label: Label = $HBox/Resources/StoneBox/StoneLabel
@onready var iron_label: Label = $HBox/Resources/IronBox/IronLabel
@onready var storage_bar: ProgressBar = $HBox/StorageBox/StorageBar
@onready var storage_label: Label = $HBox/StorageBox/StorageLabel
@onready var citizens_label: Label = $HBox/CitizensBox/CitizensLabel
@onready var realm_label: Label = $HBox/RealmBox/RealmLabel


func _ready() -> void:
	var bus = Engine.get_main_loop().root.get_node_or_null("EventBus") if Engine.get_main_loop() is SceneTree else null
	if bus != null:
		if bus.has_signal("resources_changed") and not bus.resources_changed.is_connected(_on_resources_changed):
			bus.resources_changed.connect(_on_resources_changed)
		if bus.has_signal("building_completed") and not bus.building_completed.is_connected(_on_building_completed):
			bus.building_completed.connect(_on_building_completed)
		if bus.has_signal("realm_of_power_changed") and not bus.realm_of_power_changed.is_connected(_on_realm_changed):
			bus.realm_of_power_changed.connect(_on_realm_changed)
	refresh()


func _on_resources_changed(_village_id: int) -> void:
	refresh()


func _on_building_completed(_village_id: int, _key: String, _level: int) -> void:
	refresh()


func _on_realm_changed(_village_id: int, _val: int) -> void:
	refresh()


func refresh() -> void:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null or not gs.has_active_village():
		return

	var v: Dictionary = gs.get_active_village()
	var vid: int = int(v.get("id", 1))

	if village_name_label != null:
		village_name_label.text = "%s (%d|%d)" % [str(v.get("name", "Köy")), int(v.get("x", 0)), int(v.get("y", 0))]

	if points_label != null:
		points_label.text = "Puan: %d" % int(v.get("points", 0))

	var res: Dictionary = v.get("resources", {})
	if wood_label != null:
		wood_label.text = str(int(res.get("wood", 0)))
	if stone_label != null:
		stone_label.text = str(int(res.get("stone", 0)))
	if iron_label != null:
		iron_label.text = str(int(res.get("iron", 0)))

	var storage_lvl: int = int(v.get("buildings", {}).get("storage", 1))
	var storage_cap: int = RulesEngineScript.storage_capacity(storage_lvl)
	var max_res: int = maxi(int(res.get("wood", 0)), maxi(int(res.get("stone", 0)), int(res.get("iron", 0))))

	if storage_bar != null:
		storage_bar.max_value = storage_cap
		storage_bar.value = max_res
	if storage_label != null:
		storage_label.text = "Depo: %d" % storage_cap

	var farm_lvl: int = int(v.get("buildings", {}).get("farm", 1))
	var max_pop: int = RulesEngineScript.max_population(farm_lvl)
	var free_pop: int = VillageModelScript.population_free(v)
	if citizens_label != null:
		citizens_label.text = "Vatandaş: %d / %d" % [free_pop, max_pop]

	if realm_label != null:
		realm_label.text = "Güç Alanı: %d" % int(v.get("realm_of_power", 0))
