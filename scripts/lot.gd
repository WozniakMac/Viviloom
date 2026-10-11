class_name Lot
extends Node3D
## A rectangular lot made of 1 m tiles. Owns walkability (blocked tiles plus walls on
## tile edges), pathfinding, furniture placement, and walls with doors.
##
## Wall edges are keyed Vector3i(x, y, axis):
##   axis 0: the edge along X at line z = y, spanning x..x+1 (between tiles (x,y-1) and (x,y))
##   axis 1: the edge along Z at line x = x, spanning y..y+1 (between tiles (x-1,y) and (x,y))

const CELL := 1.0
const SIM_RADIUS := 0.25
const WALL_HEIGHT := 2.8
const WALL_LOW := 0.3
const WALL_THICKNESS := 0.12
const DOOR_WIDTH := 0.9
const DOOR_HEIGHT := 2.1

enum WallView { UP, CUTAWAY, DOWN }

@export var size := Vector2i(24, 20)

var furniture: Array[Furniture] = []
## Sims currently on the lot (household and visitors), for socials and doors.
var sims: Array = []
## Vector3i edge -> wall Node3D.
var walls := {}
## Vector3i edge -> true for walls that have a door.
var doors := {}
var wall_view := WallView.CUTAWAY

var _blocked := {}
var _occupant := {}
var _astar := AStar2D.new()
var _dirty := true
var _interior := {}
var _rooms_dirty := true
var _wall_mat: StandardMaterial3D
var _door_mat: StandardMaterial3D


func _ready() -> void:
	_build_ground()


## Kept for callers that build a lot outside the scene tree (tests).
func setup() -> void:
	_dirty = true


func cell_to_world(c: Vector2i) -> Vector3:
	return Vector3((c.x + 0.5) * CELL, 0.0, (c.y + 0.5) * CELL)


func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.z / CELL))


func center() -> Vector3:
	return Vector3(size.x * CELL * 0.5, 0.0, size.y * CELL * 0.5)


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y


func contains_point(p: Vector3) -> bool:
	return in_bounds(world_to_cell(p))


func is_walkable(c: Vector2i) -> bool:
	return in_bounds(c) and not _blocked.has(c)


func set_blocked(c: Vector2i, blocked: bool) -> void:
	if not in_bounds(c):
		return
	if blocked:
		_blocked[c] = true
	else:
		_blocked.erase(c)
	_dirty = true


func set_rect_blocked(rect: Rect2i, blocked: bool) -> void:
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			set_blocked(Vector2i(x, y), blocked)


func furniture_at(c: Vector2i) -> Furniture:
	return _occupant.get(c)


# --- Edges and walls --------------------------------------------------------

## The edge between two orthogonally adjacent tiles.
static func edge_between(a: Vector2i, b: Vector2i) -> Vector3i:
	if b.x == a.x + 1:
		return Vector3i(b.x, a.y, 1)
	if b.x == a.x - 1:
		return Vector3i(a.x, a.y, 1)
	if b.y == a.y + 1:
		return Vector3i(a.x, b.y, 0)
	return Vector3i(a.x, a.y, 0)


func edge_in_bounds(e: Vector3i) -> bool:
	if e.z == 0:
		return e.x >= 0 and e.x < size.x and e.y >= 0 and e.y <= size.y
	return e.x >= 0 and e.x <= size.x and e.y >= 0 and e.y < size.y


func edge_center(e: Vector3i) -> Vector3:
	if e.z == 0:
		return Vector3((e.x + 0.5) * CELL, 0.0, e.y * CELL)
	return Vector3(e.x * CELL, 0.0, (e.y + 0.5) * CELL)


func edge_blocks(e: Vector3i) -> bool:
	return walls.has(e) and not doors.has(e)


## The tile edge closest to a ground point.
func edge_near(p: Vector3) -> Vector3i:
	var dx := absf(p.x - roundf(p.x))
	var dz := absf(p.z - roundf(p.z))
	if dx < dz:
		return Vector3i(roundi(p.x), floori(p.z), 1)
	return Vector3i(floori(p.x), roundi(p.z), 0)


## Whether a body could pass from tile a to neighbouring tile b, ignoring blocked tiles.
func _edge_clear(a: Vector2i, b: Vector2i) -> bool:
	var d := b - a
	if d == Vector2i.ZERO:
		return true
	if absi(d.x) + absi(d.y) == 1:
		return not edge_blocks(edge_between(a, b))
	var c1 := Vector2i(b.x, a.y)
	var c2 := Vector2i(a.x, b.y)
	var via1 := not edge_blocks(edge_between(a, c1)) and not edge_blocks(edge_between(c1, b))
	var via2 := not edge_blocks(edge_between(a, c2)) and not edge_blocks(edge_between(c2, b))
	return via1 or via2


## Whether a Sim can step from tile a to neighbouring tile b. Diagonal steps may not
## cut past blocked tiles or wall ends.
func can_step(a: Vector2i, b: Vector2i) -> bool:
	if not is_walkable(b):
		return false
	var d := b - a
	if absi(d.x) + absi(d.y) <= 1:
		return _edge_clear(a, b)
	var c1 := Vector2i(b.x, a.y)
	var c2 := Vector2i(a.x, b.y)
	if not is_walkable(c1) or not is_walkable(c2):
		return false
	for pair in [[a, c1], [c1, b], [a, c2], [c2, b]]:
		if edge_blocks(edge_between(pair[0], pair[1])):
			return false
	return true


## True if the straight segment a-b passes through a wall (doors count as open).
func crosses_wall(a: Vector3, b: Vector3) -> bool:
	var dist := Vector2(b.x - a.x, b.z - a.z).length()
	var steps := maxi(1, ceili(dist / 0.1))
	var prev := world_to_cell(a)
	for k in range(1, steps + 1):
		var c := world_to_cell(a.lerp(b, float(k) / steps))
		if c != prev:
			if not _edge_clear(prev, c):
				return true
			prev = c
	return false


func add_wall(e: Vector3i) -> bool:
	if walls.has(e) or not edge_in_bounds(e) or _edge_inside_furniture(e):
		return false
	walls[e] = _make_wall_visual(e, false)
	_dirty = true
	_rooms_dirty = true
	return true


func remove_wall(e: Vector3i) -> bool:
	if not walls.has(e):
		return false
	(walls[e] as Node3D).queue_free()
	walls.erase(e)
	doors.erase(e)
	_dirty = true
	_rooms_dirty = true
	return true


func add_door(e: Vector3i) -> bool:
	if not walls.has(e) or doors.has(e):
		return false
	(walls[e] as Node3D).queue_free()
	doors[e] = true
	walls[e] = _make_wall_visual(e, true)
	_dirty = true
	return true


## The edges of a straight wall run from grid vertex a towards vertex b, along
## whichever axis the drag mostly follows.
static func wall_run(a: Vector2i, b: Vector2i) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	if absi(b.x - a.x) >= absi(b.y - a.y):
		for x in range(mini(a.x, b.x), maxi(a.x, b.x)):
			out.append(Vector3i(x, a.y, 0))
	else:
		for y in range(mini(a.y, b.y), maxi(a.y, b.y)):
			out.append(Vector3i(a.x, y, 1))
	return out


func _edge_inside_furniture(e: Vector3i) -> bool:
	var a := Vector2i(e.x, e.y - 1) if e.z == 0 else Vector2i(e.x - 1, e.y)
	var b := Vector2i(e.x, e.y)
	return _occupant.has(a) and _occupant.get(a) == _occupant.get(b)


func _make_wall_visual(e: Vector3i, with_door: bool) -> Node3D:
	if _wall_mat == null:
		_wall_mat = StandardMaterial3D.new()
		_wall_mat.albedo_color = Color(0.9, 0.87, 0.8)
		_wall_mat.roughness = 0.9
		_door_mat = StandardMaterial3D.new()
		_door_mat.albedo_color = Color(0.48, 0.32, 0.2)
	var n := Node3D.new()
	n.name = "Wall"
	n.position = edge_center(e)
	if e.z == 1:
		n.rotation.y = PI * 0.5
	var full := CELL + WALL_THICKNESS
	if not with_door:
		_wall_box(n, Vector3(full, WALL_HEIGHT, WALL_THICKNESS), Vector3(0, WALL_HEIGHT * 0.5, 0), _wall_mat)
	else:
		var side := (full - DOOR_WIDTH) * 0.5
		var side_x := (DOOR_WIDTH + side) * 0.5
		_wall_box(n, Vector3(side, WALL_HEIGHT, WALL_THICKNESS), Vector3(-side_x, WALL_HEIGHT * 0.5, 0), _wall_mat)
		_wall_box(n, Vector3(side, WALL_HEIGHT, WALL_THICKNESS), Vector3(side_x, WALL_HEIGHT * 0.5, 0), _wall_mat)
		var lintel := WALL_HEIGHT - DOOR_HEIGHT
		_wall_box(n, Vector3(DOOR_WIDTH, lintel, WALL_THICKNESS), Vector3(0, DOOR_HEIGHT + lintel * 0.5, 0), _wall_mat)
		var hinge := Node3D.new()
		hinge.name = "DoorHinge"
		hinge.position = Vector3(-DOOR_WIDTH * 0.5, 0, 0)
		n.add_child(hinge)
		_wall_box(hinge, Vector3(DOOR_WIDTH - 0.02, DOOR_HEIGHT - 0.02, 0.05), Vector3(DOOR_WIDTH * 0.5, DOOR_HEIGHT * 0.5, 0), _door_mat)
		n.set_meta("hinge", hinge)
	add_child(n)
	return n


func _wall_box(parent: Node3D, box_size: Vector3, pos: Vector3, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = box_size
	m.mesh = box
	m.position = pos
	m.material_override = mat
	parent.add_child(m)


## Raises or lowers walls for the current view mode. In cutaway, a wall is lowered
## when the tile behind it (seen from the camera) is indoors, so rooms stay visible
## while outside-facing back walls stay up.
func update_walls(camera_pos: Vector3, focus: Vector3, delta: float) -> void:
	if _rooms_dirty:
		_compute_interior()
	var to_cam := camera_pos - focus
	var k := 1.0 - exp(-12.0 * delta)
	for e in walls:
		var low := wall_view == WallView.DOWN
		if wall_view == WallView.CUTAWAY:
			var far: Vector2i
			if e.z == 0:
				far = Vector2i(e.x, e.y - 1) if to_cam.z > 0.0 else Vector2i(e.x, e.y)
			else:
				far = Vector2i(e.x - 1, e.y) if to_cam.x > 0.0 else Vector2i(e.x, e.y)
			low = _interior.has(far)
		var target := (WALL_LOW / WALL_HEIGHT) if low else 1.0
		var n: Node3D = walls[e]
		n.scale.y = lerpf(n.scale.y, target, k)


func is_indoors(c: Vector2i) -> bool:
	if _rooms_dirty:
		_compute_interior()
	return _interior.has(c)


## Tiles that cannot be reached from the lot's border without crossing a wall
## (doors count as closed here) are indoors.
func _compute_interior() -> void:
	var outside := {}
	var stack: Array[Vector2i] = []
	for x in size.x:
		stack.append(Vector2i(x, 0))
		stack.append(Vector2i(x, size.y - 1))
	for y in size.y:
		stack.append(Vector2i(0, y))
		stack.append(Vector2i(size.x - 1, y))
	for c in stack:
		outside[c] = true
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if in_bounds(n) and not outside.has(n) and not walls.has(edge_between(c, n)):
				outside[n] = true
				stack.append(n)
	_interior.clear()
	for y in size.y:
		for x in size.x:
			if not outside.has(Vector2i(x, y)):
				_interior[Vector2i(x, y)] = true
	_rooms_dirty = false


## Swings doors open while someone is close to them.
func update_doors(people: Array[Vector3], delta: float) -> void:
	for e in doors:
		var hinge: Node3D = (walls[e] as Node3D).get_meta("hinge")
		var c := edge_center(e)
		var open := false
		for p in people:
			if Vector2(p.x - c.x, p.z - c.z).length() < 1.1:
				open = true
		hinge.rotation.y = lerpf(hinge.rotation.y, 1.5 if open else 0.0, 1.0 - exp(-8.0 * delta))


# --- Pathfinding ------------------------------------------------------------

func _id(c: Vector2i) -> int:
	return c.y * size.x + c.x


func _rebuild_graph() -> void:
	_astar.clear()
	_astar.reserve_space(size.x * size.y)
	for y in size.y:
		for x in size.x:
			_astar.add_point(_id(Vector2i(x, y)), Vector2(x, y))
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1)]
	for y in size.y:
		for x in size.x:
			var c := Vector2i(x, y)
			if not is_walkable(c):
				continue
			for d in dirs:
				var n := c + d
				if can_step(c, n):
					_astar.connect_points(_id(c), _id(n))
	_dirty = false


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
	if _dirty:
		_rebuild_graph()
	var start := nearest_walkable(world_to_cell(from))
	var goal_cell := world_to_cell(to)
	if not in_bounds(goal_cell) or start.x < 0:
		return PackedVector3Array()
	if not is_walkable(goal_cell):
		goal_cell = nearest_walkable(goal_cell)
		if goal_cell.x < 0:
			return PackedVector3Array()
		to = cell_to_world(goal_cell)
	var ids := _astar.get_id_path(_id(start), _id(goal_cell))
	if ids.is_empty():
		return PackedVector3Array()

	var raw: Array[Vector3] = [Vector3(from.x, 0.0, from.z)]
	for i in range(1, ids.size() - 1):
		var p := _astar.get_point_position(ids[i])
		raw.append(cell_to_world(Vector2i(int(p.x), int(p.y))))
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


## True if a Sim-sized body can walk straight from a to b without touching blocked
## tiles or passing through walls.
func has_line_of_sight(a: Vector3, b: Vector3) -> bool:
	var d := b - a
	d.y = 0.0
	var dist := d.length()
	if dist < 0.001:
		return true
	var perp := Vector3(-d.z, 0.0, d.x) / dist * SIM_RADIUS
	var steps := ceili(dist / 0.1)
	for off: Vector3 in [Vector3.ZERO, perp, -perp]:
		var prev := world_to_cell(a + off)
		for k in range(steps + 1):
			var c := world_to_cell(a.lerp(b, float(k) / steps) + off)
			if not is_walkable(c):
				return false
			if c != prev:
				if not can_step(prev, c):
					return false
				prev = c
	return true


# --- Furniture ----------------------------------------------------------------

## Snaps `f` into position without claiming its tiles (used for placement previews).
func position_furniture(f: Furniture, at_cell: Vector2i, rot_steps: int) -> void:
	f.rot_steps = posmod(rot_steps, 4)
	f.cell = at_cell
	var fp := f.rotated_footprint()
	f.position = Vector3((at_cell.x + fp.x * 0.5) * CELL, 0.0, (at_cell.y + fp.y * 0.5) * CELL)
	f.rotation.y = f.rot_steps * PI * 0.5


## Whether `f` fits with its top-left tile at `at_cell`: inside the lot, on free tiles and
## not straddling a wall. Tiles in `avoid` (where a Sim stands) count as taken.
func can_place(f: Furniture, at_cell: Vector2i, rot_steps: int, avoid: Array[Vector2i] = []) -> bool:
	var fp := f.footprint if posmod(rot_steps, 2) == 0 else Vector2i(f.footprint.y, f.footprint.x)
	var rect := Rect2i(at_cell, fp)
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var c := Vector2i(x, y)
			if not is_walkable(c) or avoid.has(c):
				return false
			if x + 1 < rect.end.x and walls.has(edge_between(c, Vector2i(x + 1, y))):
				return false
			if y + 1 < rect.end.y and walls.has(edge_between(c, Vector2i(x, y + 1))):
				return false
	return true


## Puts `f` on the lot with its footprint's top-left tile at `at_cell`.
func place_furniture(f: Furniture, at_cell: Vector2i, rot_steps := 0) -> void:
	position_furniture(f, at_cell, rot_steps)
	if f.get_parent() == null:
		add_child(f)
	var rect := f.footprint_rect()
	set_rect_blocked(rect, true)
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			_occupant[Vector2i(x, y)] = f
	furniture.append(f)


## Takes `f` off the grid; the node itself stays (e.g. while it is being moved).
func remove_furniture(f: Furniture) -> void:
	if not furniture.has(f):
		return
	var rect := f.footprint_rect()
	set_rect_blocked(rect, false)
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			_occupant.erase(Vector2i(x, y))
	furniture.erase(f)


# --- Ground and decoration --------------------------------------------------

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


## Places a simple box that blocks the tiles it covers (hedges, planters).
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
