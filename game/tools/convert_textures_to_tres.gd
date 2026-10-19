extends SceneTree

func _init() -> void:
	print("=== Converting nano_banana PNGs to .tres ImageTextures ===")
	var dir_path = "res://assets/sprites/ui/nano_banana"
	var dir = DirAccess.open(dir_path)
	if dir == null:
		printerr("Cannot open directory: ", dir_path)
		quit(1)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	var count = 0
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".png"):
			var png_path = dir_path + "/" + file_name
			var tres_path = dir_path + "/" + file_name.trim_suffix(".png") + ".tres"
			var img = Image.load_from_file(png_path)
			if img != null:
				var tex = ImageTexture.create_from_image(img)
				var err = ResourceSaver.save(tex, tres_path)
				if err == OK:
					print("Converted: ", file_name, " -> ", tres_path)
					count += 1
				else:
					printerr("Failed to save: ", tres_path, " err: ", err)
			else:
				printerr("Failed to load image: ", png_path)
		file_name = dir.get_next()
	dir.list_dir_end()
	print("Successfully converted ", count, " textures to .tres!")
	quit(0)
