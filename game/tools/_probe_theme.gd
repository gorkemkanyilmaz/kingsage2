extends SceneTree

func _initialize() -> void:
	var t = load("res://themes/TahtVeKilic.tres")
	print("theme=", t)
	print("opt style=", t.get_stylebox("normal", "OptionButton"))
	print("popup panel=", t.get_stylebox("panel", "PopupMenu"))
	var scene = load("res://scenes/Settings.tscn").instantiate()
	root.add_child(scene)
	scene._ready()
	var opt = scene.get_node("Center/VBox/ProfileRow/Option")
	var pop = opt.get_popup()
	print("popup theme=", pop.theme)
	print("popup panel resolved=", pop.get_theme_stylebox("panel"))
	print("popup font size=", pop.get_theme_font_size("font_size"))
	print("popup type=", pop.get_class(), " embedded=", pop.is_embedded())
	quit(0)
