extends SceneTree

func _initialize() -> void:
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_size = Vector2i(128, 64)
	var src := TileSetAtlasSource.new()
	src.texture_region_size = Vector2i(128, 64)
	var img := Image.create(256, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	src.texture = ImageTexture.create_from_image(img)
	src.create_tile(Vector2i(0, 0))
	var sid := ts.add_source(src, 0)
	var layer := TileMapLayer.new()
	layer.tile_set = ts
	print("tile_size=", ts.tile_size, " layertilesz=", layer.tile_set.tile_size)
	for p in [Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(2,0), Vector2i(0,2), Vector2i(1,1), Vector2i(2,1), Vector2i(-1,0)]:
		print(p, " -> ", layer.map_to_local(p))
	print("local_to_map(192,32)=", layer.local_to_map(Vector2(192, 32)))
	quit(0)
