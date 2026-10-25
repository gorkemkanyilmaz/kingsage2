extends SceneTree

func _init() -> void:
	print("Capturing World Select screen...")
	var scene = load("res://scenes/VillageSelect.tscn").instantiate()
	root.add_child(scene)
	
	# Wait a couple frames for layout
	await process_frame
	await process_frame
	await process_frame

	var img = root.get_texture().get_image()
	var out_path = "res://scratch/world_select_preview.png"
	img.save_png(out_path)
	print("Saved preview to: ", out_path)
	quit(0)
