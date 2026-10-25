extends SceneTree

func _init() -> void:
	print("--- Testing WorldGenerator Performance & Distance ---")
	var WorldGen = load("res://scripts/world/WorldGenerator.gd")

	for test_dist in [4, 5, 6]:
		var t0 := Time.get_ticks_msec()
		var tiles := {}
		var villages: Array = []
		var placed: Array = []
		var rng := RandomNumberGenerator.new()
		rng.seed = 4242

		var total := 210
		var world_size := 200
		var cluster_size := 25
		var cluster_spread := 11
		var centers: Array = []
		var half := int(cluster_size / 2.0)
		var i := 0
		while i * cluster_size + half <= world_size:
			var j := 0
			while j * cluster_size + half <= world_size:
				var cx := i * cluster_size + half + rng.randi_range(-3, 3)
				var cy := j * cluster_size + half + rng.randi_range(-3, 3)
				centers.append(Vector2i(clampi(cx, 1, world_size), clampi(cy, 1, world_size)))
				j += 1
			i += 1

		var cluster_order: Array = []
		for idx in centers.size():
			cluster_order.append(idx)
		for idx in range(cluster_order.size() - 1, 0, -1):
			var jdx := rng.randi_range(0, idx)
			var tmp = cluster_order[idx]
			cluster_order[idx] = cluster_order[jdx]
			cluster_order[jdx] = tmp

		# Helper to check distance against placed
		for idx in total:
			var center: Vector2i = centers[int(cluster_order[idx % cluster_order.size()])]
			var found := Vector2i(-1, -1)
			for attempt in 50:
				var rx := clampi(center.x + rng.randi_range(-cluster_spread, cluster_spread), 1, world_size)
				var ry := clampi(center.y + rng.randi_range(-cluster_spread, cluster_spread), 1, world_size)
				var ok := true
				for p in placed:
					if absi((p as Vector2i).x - rx) < test_dist and absi((p as Vector2i).y - ry) < test_dist:
						ok = false
						break
				if ok:
					found = Vector2i(rx, ry)
					break
			if found.x < 0:
				# fallback random scan
				for attempt in 200:
					var rx := rng.randi_range(1, world_size)
					var ry := rng.randi_range(1, world_size)
					var ok := true
					for p in placed:
						if absi((p as Vector2i).x - rx) < test_dist and absi((p as Vector2i).y - ry) < test_dist:
							ok = false
							break
					if ok:
						found = Vector2i(rx, ry)
						break
			if found.x >= 0:
				placed.append(found)

		var t1 := Time.get_ticks_msec()
		print("Dist ", test_dist, " placed: ", placed.size(), " / 210 in ", (t1 - t0), " ms")

	quit(0)
