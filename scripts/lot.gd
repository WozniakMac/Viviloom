class_name Lot
extends Node3D
## A rectangular lot made of 1 m tiles. Owns the walkability grid and pathfinding.

const CELL := 1.0
const SIM_RADIUS := 0.25

@export var size := Vector2i(24, 20)

var astar := AStarGrid2D.new()
var furniture: Array[Furniture] = []
var _ready_grid := false


func _ready() -> void:
	setup()
	_build_ground()


## Builds the walk grid. Safe to call more than once (tests call it without a scene tree).
func setup() -> void:
	if _ready_grid:
		return
	astar.region = Rect2i(Vector2i.ZERO, size)
	astar.cell_size = Vector2(CELL, CELL)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	_ready_grid = true


func cell_to_world(c: Vector2i) -> Vector3:
	return Vector3((c.x + 0.5) * CELL, 0.0, (c.y + 0.5) * CELL)


func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.z / CELL))


func center() -> Vector3:
	return Vector3(size.x * CELL * 0.5, 0.0, size.y * CELL * 0.5)


func contains_point(p: Vector3) -> bool:
	return astar.is_in_boundsv(world_to_cell(p))


func is_walkable(c: Vector2i) -> bool:
	return astar.is_in_boundsv(c) and not astar.is_point_solid(c)


func set_blocked(c: Vector2i, blocked: bool) -> void:
	if astar.is_in_boundsv(c):
		astar.set_point_solid(c, blocked)


func set_rect_blocked(rect: Rect2i, blocked: bool) -> void:
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			set_blocked(Vector2i(x, y), blocked)


## Closest walkable cell to `c` (searching outward ring by ring), or (-1,-1) if none.
func nearest_walkable(c: Vector2i, max_radius := 12) -> Vector2i:
	if is_walkable(c):
		return c
	for r in range(1, max_radius + 1):
		var best := Vector2i(-1, -1)
		var best_d := INF
		for x in range(c.x - r, c.x + r + 1):
			for y in range(c.y - r, c.y + r + 1):
				if maxi(absi(x - c.x), absi(y - c.y)) != r:
					continue
				var n := Vector2i(x, y)
				if is_walkable(n):
					var d := Vector2(n - c).length_squared()
					if d < best_d:
						best_d = d
						best = n
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)


## Returns smoothed waypoints from `from` to `to` (excluding `from`), or an empty array
## when the destination cannot be reached.
func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var start := nearest_walkable(world_to_cell(from))
	var goal_cell := world_to_cell(to)
	if not astar.is_in_boundsv(goal_cell) or start.x < 0:
		return PackedVector3Array()
	if not is_walkable(goal_cell):
		goal_cell = nearest_walkable(goal_cell)
		if goal_cell.x < 0:
			return PackedVector3Array()
		to = cell_to_world(goal_cell)
	var ids := astar.get_id_path(start, goal_cell)
	if ids.is_empty():
		return PackedVector3Array()

	var raw: Array[Vector3] = [Vector3(from.x, 0.0, from.z)]
	for i in range(1, ids.size() - 1):
		raw.append(cell_to_world(ids[i]))
	raw.append(Vector3(to.x, 0.0, to.z))

	# String-pulling: skip intermediate waypoints that have clear line of sight.
	var out := PackedVector3Array()
	var i := 0
	var last := raw.size() - 1
	while i < last:
		var j := last
		while j > i + 1 and not has_line_of_sight(raw[i], raw[j]):
			j -= 1
		out.append(raw[j])
		i = j
	return out


## True if a Sim-sized body can walk straight from a to b without touching blocked cells.
func has_line_of_sight(a: Vector3, b: Vector3) -> bool:
	var d := b - a
	d.y = 0.0
	var dist := d.length()
	if dist < 0.001:
		return true
	var perp := Vector3(-d.z, 0.0, d.x) / dist * SIM_RADIUS
	var steps := ceili(dist / 0.15)
	for k in range(steps + 1):
		var p := a.lerp(b, float(k) / steps)
		for off in [Vector3.ZERO, perp, -perp]:
			if not is_walkable(world_to_cell(p + off)):
				return false
	return true


func _build_ground() -> void:
	var lot_mesh := MeshInstance3D.new()
	lot_mesh.name = "LotGround"
	var plane := PlaneMesh.new()
	plane.size = Vector2(size.x * CELL, size.y * CELL)
	lot_mesh.mesh = plane
	lot_mesh.position = center()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/lot_ground.gdshader")
	lot_mesh.material_override = mat
	add_child(lot_mesh)

	# The neighbourhood around the lot, slightly darker and without a grid.
	var outer := MeshInstance3D.new()
	outer.name = "Surroundings"
	var outer_plane := PlaneMesh.new()
	outer_plane.size = Vector2(200, 200)
	outer.mesh = outer_plane
	outer.position = center() + Vector3(0, -0.02, 0)
	var outer_mat := StandardMaterial3D.new()
	outer_mat.albedo_color = Color(0.27, 0.42, 0.2)
	outer_mat.roughness = 1.0
	outer.material_override = outer_mat
	add_child(outer)

	# A sidewalk and road along the front of the lot.
	_add_strip("Sidewalk", Vector3(center().x, -0.01, size.y * CELL + 0.75), Vector2(200, 1.5), Color(0.72, 0.71, 0.68))
	_add_strip("Road", Vector3(center().x, -0.015, size.y * CELL + 5.0), Vector2(200, 7.0), Color(0.22, 0.22, 0.24))


func _add_strip(strip_name: String, pos: Vector3, strip_size: Vector2, color: Color) -> void:
	var m := MeshInstance3D.new()
	m.name = strip_name
	var p := PlaneMesh.new()
	p.size = strip_size
	m.mesh = p
	m.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	m.material_override = mat
	add_child(m)


## Places a simple box that blocks the tiles it covers (hedges, placeholder furniture).
func add_block(rect: Rect2i, height: float, color: Color, block_name := "Block") -> MeshInstance3D:
	set_rect_blocked(rect, true)
	var m := MeshInstance3D.new()
	m.name = block_name
	var box := BoxMesh.new()
	box.size = Vector3(rect.size.x * CELL - 0.06, height, rect.size.y * CELL - 0.06)
	m.mesh = box
	m.position = Vector3((rect.position.x + rect.size.x * 0.5) * CELL, height * 0.5, (rect.position.y + rect.size.y * 0.5) * CELL)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	m.material_override = mat
	add_child(m)
	return m


## Puts `f` on the lot with its footprint's top-left tile at `at_cell`.
func place_furniture(f: Furniture, at_cell: Vector2i, rot_steps := 0) -> void:
	f.rot_steps = posmod(rot_steps, 4)
	f.cell = at_cell
	var fp := f.rotated_footprint()
	f.position = Vector3((at_cell.x + fp.x * 0.5) * CELL, 0.0, (at_cell.y + fp.y * 0.5) * CELL)
	f.rotation.y = f.rot_steps * PI * 0.5
	if f.get_parent() == null:
		add_child(f)
	set_rect_blocked(f.footprint_rect(), true)
	furniture.append(f)


## A flat floor finish (does not block walking).
func add_floor(rect: Rect2i, color: Color) -> void:
	var m := MeshInstance3D.new()
	m.name = "Floor"
	var box := BoxMesh.new()
	box.size = Vector3(rect.size.x * CELL, 0.04, rect.size.y * CELL)
	m.mesh = box
	m.position = Vector3((rect.position.x + rect.size.x * 0.5) * CELL, 0.0, (rect.position.y + rect.size.y * 0.5) * CELL)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.6
	m.material_override = mat
	add_child(m)
