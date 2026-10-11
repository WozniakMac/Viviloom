extends SceneTree
## Headless logic tests. Run with:
##   Godot_console.exe --headless --path . -s res://tests/run_tests.gd

var _failures := 0


func _init() -> void:
	_test_path_avoids_obstacles()
	_test_unreachable_goal()
	_test_blocked_goal_snaps_to_neighbour()
	print("TESTS %s (%d failures)" % ["PASSED" if _failures == 0 else "FAILED", _failures])
	quit(1 if _failures > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL: ", msg)


func _make_lot() -> Lot:
	var lot := Lot.new()
	lot.size = Vector2i(16, 16)
	lot.setup()
	return lot


func _test_path_avoids_obstacles() -> void:
	var lot := _make_lot()
	lot.set_rect_blocked(Rect2i(6, 0, 1, 12), true)
	var from := lot.cell_to_world(Vector2i(2, 2))
	var to := lot.cell_to_world(Vector2i(10, 2))
	var path := lot.find_path(from, to)
	_check(not path.is_empty(), "path around wall exists")
	var prev := from
	for p in path:
		_check(lot.has_line_of_sight(prev, p), "segment %s -> %s is clear" % [prev, p])
		prev = p
	_check(prev.distance_to(to) < 0.01, "path ends at target")
	lot.free()


func _test_unreachable_goal() -> void:
	var lot := _make_lot()
	lot.set_rect_blocked(Rect2i(9, 9, 5, 1), true)
	lot.set_rect_blocked(Rect2i(9, 13, 5, 1), true)
	lot.set_rect_blocked(Rect2i(9, 10, 1, 3), true)
	lot.set_rect_blocked(Rect2i(13, 10, 1, 3), true)
	var path := lot.find_path(lot.cell_to_world(Vector2i(1, 1)), lot.cell_to_world(Vector2i(11, 11)))
	_check(path.is_empty(), "enclosed cell is unreachable")
	lot.free()


func _test_blocked_goal_snaps_to_neighbour() -> void:
	var lot := _make_lot()
	lot.set_blocked(Vector2i(5, 5), true)
	var path := lot.find_path(lot.cell_to_world(Vector2i(1, 1)), lot.cell_to_world(Vector2i(5, 5)))
	_check(not path.is_empty(), "clicking an obstacle walks next to it")
	if not path.is_empty():
		var end_cell := lot.world_to_cell(path[path.size() - 1])
		_check(end_cell != Vector2i(5, 5) and lot.is_walkable(end_cell), "ends on a free cell")
	lot.free()
