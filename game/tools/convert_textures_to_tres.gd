extends SceneTree

func _init() -> void:
	print("=== Converting nano_banana sharp PNGs to .tres ImageTextures with Mipmaps ===")
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
		if not dir.current_is_dir() and file_name.ends_with(".png") and file_name.begins_with("sharp_"):
			var png_path = dir_path + "/" + file_name
			var tres_path = dir_path + "/" + file_name.trim_suffix(".png") + ".tres"
			var img = Image.load_from_file(png_path)
			if img != null:
				# Generate mipmaps for smooth scaling without pixelation or blur
				var m_err = img.generate_mipmaps()
				var tex = ImageTexture.create_from_image(img)
				var err = ResourceSaver.save(tex, tres_path)
				if err == OK:
					print("Converted with mipmaps: ", file_name, " (", img.get_size(), ") -> ", tres_path)
					count += 1
				else:
					printerr("Failed to save: ", tres_path, " err: ", err)
			else:
				printerr("Failed to load image: ", png_path)
		file_name = dir.get_next()
	dir.list_dir_end()
	print("Successfully converted ", count, " sharp textures to .tres with mipmaps!")
	quit(0)
