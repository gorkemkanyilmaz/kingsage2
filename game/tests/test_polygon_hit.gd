extends SceneTree

class CustomHitButton extends Button:
	var click_polygon: PackedVector2Array = []
	
	func _has_point(point: Vector2) -> bool:
		if click_polygon.is_empty():
			return Rect2(Vector2.ZERO, size).has_point(point)
		return Geometry2D.is_point_in_polygon(point, click_polygon)

func _init() -> void:
	print("--- Running Polygon Hit Test ---")
	var btn := CustomHitButton.new()
	btn.size = Vector2(100, 100)
	# Triangle: (0, 0), (100, 0), (0, 100)
	btn.click_polygon = PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(0, 100)])
	
	# Inside triangle: (10, 10)
	var in_pt := Vector2(10, 10)
	assert(btn._has_point(in_pt) == true, "(10, 10) should be inside")
	
	# Outside triangle but inside (100, 100) rect: (80, 80)
	var out_pt := Vector2(80, 80)
	assert(btn._has_point(out_pt) == false, "(80, 80) should be outside")
	
	print("[PASS] CustomHitButton._has_point accurately checks polygon!")
	quit(0)
