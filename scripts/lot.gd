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
const WINDOW_WIDTH := 0.8
const WINDOW_SILL := 0.85
const WINDOW_TOP := 2.1

enum WallView { UP, CUTAWAY, DOWN }

@export var size := Vector2i(24, 20)
## 0 for the ground floor, 1 for the storey above (which sits WALL_HEIGHT up and
## is only walkable where it has floor).
var level := 0

var furniture: Array[Furniture] = []
## Sims currently on the lot (household and visitors), for socials and doors.
var sims: Array = []
## Vector3i edge -> wall Node3D.
var walls := {}
## Vector3i edge -> true for walls that have a door.
var doors := {}
## Vector3i edge -> true for walls with a window.
var windows := {}
## Vector3i edge -> Finishes.WALLS index (missing = the default paint).
var wall_styles := {}
## Edge -> picket fence node; gates are fence edges Sims can walk through.
var fences := {}
## Lot traits (see LotTraits) for the home; community lots have none.
var lot_traits: Array = []
var gates := {}
const FENCE_HEIGHT := 0.9
## Vector2i tile -> Finishes.FLOORS index.
var floor_tiles := {}
var _floor_mesh: MeshInstance3D
## Pools: Rect2i -> their Pool object; tiles under a pool have no ground.
var pools := {}
var _ground_mesh: MeshInstance3D
var _pool_mesh: MeshInstance3D
var _water_mesh: MeshInstance3D
const POOL_DEPTH := 1.4
const WATER_LEVEL := -0.15
## A gable roof over the indoor area, shown with walls up.
var _roof: MeshInstance3D
var wall_view := WallView.CUTAWAY

var _blocked := {}
var _occupant := {}
var _astar := AStar2D.new()
var _dirty := true
var _interior := {}
var _rooms_dirty := true
var _frame_mat: StandardMaterial3D
var _glass_mat: StandardMaterial3D
## Floors and decorative blocks added by a house layout, removed by clear_build().
var _built: Array[Node3D] = []
var _door_mat: StandardMaterial3D


func _ready() -> void:
	if level == 0:
		_build_ground()


## Height of this level's floor in the world.
func base_y() -> float:
	return level * WALL_HEIGHT


## Kept for callers that build a lot outside the scene tree (tests).
func setup() -> void:
	_dirty = true


func cell_to_world(c: Vector2i) -> Vector3:
	return Vector3((c.x + 0.5) * CELL, base_y(), (c.y + 0.5) * CELL)


func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.z / CELL))


func center() -> Vector3:
	return Vector3(size.x * CELL * 0.5, 0.0, size.y * CELL * 0.5)


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y


func contains_point(p: Vector3) -> bool:
	return in_bounds(world_to_cell(p))


func is_walkable(c: Vector2i) -> bool:
	if level > 0 and not floor_tiles.has(c):
		return false
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
	return (walls.has(e) and not doors.has(e)) or (fences.has(e) and not gates.has(e))


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
	if walls.has(e) or fences.has(e) or not edge_in_bounds(e) or _edge_inside_furniture(e):
		return false
	walls[e] = _make_wall_visual(e, false)
	_dirty = true
	_rooms_dirty = true
	return true


func remove_wall(e: Vector3i) -> bool:
	if not walls.has(e):
		return false
	(walls[e] as Node3D).queue_free()
	for f in furniture.duplicate():
		if f.wall_mounted and wall_edge_for(f.cell, f.rot_steps) == e:
			remove_furniture(f)
			f.queue_free()
	walls.erase(e)
	doors.erase(e)
	windows.erase(e)
	wall_styles.erase(e)
	_dirty = true
	_rooms_dirty = true
	return true


## A low white picket fence along an edge (not on walls). Fences block walking but
## don't count as room walls and are never cut away.
func add_fence(e: Vector3i) -> bool:
	if fences.has(e) or walls.has(e) or not edge_in_bounds(e):
		return false
	fences[e] = _make_fence_visual(e, false)
	_dirty = true
	return true


func remove_fence(e: Vector3i) -> bool:
	if not fences.has(e):
		return false
	(fences[e] as Node3D).queue_free()
	fences.erase(e)
	gates.erase(e)
	_dirty = true
	return true


## Turns a fence segment into a swinging gate.
func add_gate(e: Vector3i) -> bool:
	if not fences.has(e) or gates.has(e):
		return false
	gates[e] = true
	(fences[e] as Node3D).queue_free()
	fences[e] = _make_fence_visual(e, true)
	_dirty = true
	return true


func _make_fence_visual(e: Vector3i, gate: bool) -> Node3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.97, 0.97, 0.95)
	mat.roughness = 0.7
	var n := Node3D.new()
	n.name = "Fence"
	n.position = edge_center(e)
	if e.z == 1:
		n.rotation.y = PI * 0.5
	# Corner posts with little caps.
	for px in [-0.5, 0.5]:
		_wall_box(n, Vector3(0.1, FENCE_HEIGHT + 0.08, 0.1), Vector3(px, (FENCE_HEIGHT + 0.08) * 0.5, 0), mat)
		_wall_box(n, Vector3(0.13, 0.04, 0.13), Vector3(px, FENCE_HEIGHT + 0.1, 0), mat)
	var holder := n
	if gate:
		var hinge := Node3D.new()
		hinge.name = "GateHinge"
		hinge.position = Vector3(-0.45, 0, 0)
		n.add_child(hinge)
		n.set_meta("hinge", hinge)
		holder = hinge
	var ox := 0.45 if gate else 0.0
	# Two rails and pointed pickets.
	for ry in [0.25, FENCE_HEIGHT - 0.2]:
		_wall_box(holder, Vector3(0.9, 0.06, 0.03), Vector3(ox, ry, 0.03), mat)
	for k in 6:
		var x := -0.375 + k * 0.15
		_wall_box(holder, Vector3(0.08, FENCE_HEIGHT - 0.05, 0.025), Vector3(ox + x, (FENCE_HEIGHT - 0.05) * 0.5, 0), mat)
		var tip := MeshInstance3D.new()
		var pr := PrismMesh.new()
		pr.size = Vector3(0.08, 0.07, 0.025)
		tip.mesh = pr
		tip.position = Vector3(ox + x, FENCE_HEIGHT - 0.015, 0)
		tip.material_override = mat
		holder.add_child(tip)
	add_child(n)
	return n


func add_door(e: Vector3i) -> bool:
	if not walls.has(e) or doors.has(e):
		return false
	windows.erase(e)
	doors[e] = true
	_refresh_wall(e)
	_dirty = true
	return true


## Puts a window in a wall (walls with doors can't have one).
func add_window(e: Vector3i) -> bool:
	if not walls.has(e) or doors.has(e) or windows.has(e):
		return false
	windows[e] = true
	_refresh_wall(e)
	return true


func paint_wall(e: Vector3i, style: int) -> bool:
	if not walls.has(e) or wall_styles.get(e, 0) == style:
		return false
	wall_styles[e] = style
	_refresh_wall(e)
	return true


## Rebuilds a wall's visual after a door, window or paint change, keeping its
## current cutaway height.
func _refresh_wall(e: Vector3i) -> void:
	var old := walls[e] as Node3D
	var h := old.scale.y
	old.queue_free()
	walls[e] = _make_wall_visual(e, doors.has(e))
	(walls[e] as Node3D).scale.y = h


# --- Floors -----------------------------------------------------------------

func set_floor(c: Vector2i, style: int) -> void:
	if in_bounds(c):
		floor_tiles[c] = style
	_rebuild_floor()


## Removes floor tiles (a stairwell on an upper level).
func clear_floor(rect: Rect2i) -> void:
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			floor_tiles.erase(Vector2i(x, y))
	_rebuild_floor()


## Builds one mesh for all floor tiles; the colour carries the finish and pattern.
func _rebuild_floor() -> void:
	_dirty = true
	if _floor_mesh == null:
		_floor_mesh = MeshInstance3D.new()
		_floor_mesh.name = "Floors"
		_floor_mesh.material_override = Finishes.floor_material()
		add_child(_floor_mesh)
	if floor_tiles.is_empty():
		_floor_mesh.mesh = null
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for c in floor_tiles:
		var f: Array = Finishes.FLOORS[clampi(floor_tiles[c], 0, Finishes.FLOORS.size() - 1)]
		var col: Color = f[1]
		col.a = float(f[2]) / 8.0
		st.set_color(col)
		var x0: float = c.x * CELL
		var z0: float = c.y * CELL
		var y := 0.021
		var a := Vector3(x0, y, z0)
		var b := Vector3(x0 + CELL, y, z0)
		var d := Vector3(x0, y, z0 + CELL)
		var e := Vector3(x0 + CELL, y, z0 + CELL)
		for v in [a, b, e, a, e, d]:
			st.add_vertex(v)
	_floor_mesh.mesh = st.commit()


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
	if _door_mat == null:
		_door_mat = StandardMaterial3D.new()
		_door_mat.albedo_color = Color(0.48, 0.32, 0.2)
		_frame_mat = StandardMaterial3D.new()
		_frame_mat.albedo_color = Color(0.96, 0.96, 0.94)
		_glass_mat = StandardMaterial3D.new()
		_glass_mat.albedo_color = Color(0.7, 0.85, 0.95, 0.3)
		_glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glass_mat.roughness = 0.05
		_glass_mat.metallic_specular = 1.0
	var wall_mat: Material = Finishes.wall_material(wall_styles.get(e, 0))
	var n := Node3D.new()
	n.name = "Wall"
	n.position = edge_center(e)
	if e.z == 1:
		n.rotation.y = PI * 0.5
	var full := CELL + WALL_THICKNESS
	if windows.has(e) and not with_door:
		# Sill, header and side posts around a framed pane.
		var w := WINDOW_WIDTH
		var side := (full - w) * 0.5
		var side_x := (w + side) * 0.5
		_wall_box(n, Vector3(full, WINDOW_SILL, WALL_THICKNESS), Vector3(0, WINDOW_SILL * 0.5, 0), wall_mat)
		var top := WALL_HEIGHT - WINDOW_TOP
		_wall_box(n, Vector3(full, top, WALL_THICKNESS), Vector3(0, WINDOW_TOP + top * 0.5, 0), wall_mat)
		var mid_h := WINDOW_TOP - WINDOW_SILL
		var mid_y := WINDOW_SILL + mid_h * 0.5
		_wall_box(n, Vector3(side, mid_h, WALL_THICKNESS), Vector3(-side_x, mid_y, 0), wall_mat)
		_wall_box(n, Vector3(side, mid_h, WALL_THICKNESS), Vector3(side_x, mid_y, 0), wall_mat)
		_wall_box(n, Vector3(w, mid_h, 0.02), Vector3(0, mid_y, 0), _glass_mat)
		for fx in [-w * 0.5, 0.0, w * 0.5]:
			_wall_box(n, Vector3(0.04, mid_h, WALL_THICKNESS + 0.03), Vector3(fx, mid_y, 0), _frame_mat)
		for fy in [WINDOW_SILL, WINDOW_TOP]:
			_wall_box(n, Vector3(w + 0.04, 0.04, WALL_THICKNESS + 0.06), Vector3(0, fy, 0), _frame_mat)
	elif not with_door:
		_wall_box(n, Vector3(full, WALL_HEIGHT, WALL_THICKNESS), Vector3(0, WALL_HEIGHT * 0.5, 0), wall_mat)
	else:
		var side := (full - DOOR_WIDTH) * 0.5
		var side_x := (DOOR_WIDTH + side) * 0.5
		_wall_box(n, Vector3(side, WALL_HEIGHT, WALL_THICKNESS), Vector3(-side_x, WALL_HEIGHT * 0.5, 0), wall_mat)
		_wall_box(n, Vector3(side, WALL_HEIGHT, WALL_THICKNESS), Vector3(side_x, WALL_HEIGHT * 0.5, 0), wall_mat)
		var lintel := WALL_HEIGHT - DOOR_HEIGHT
		_wall_box(n, Vector3(DOOR_WIDTH, lintel, WALL_THICKNESS), Vector3(0, DOOR_HEIGHT + lintel * 0.5, 0), wall_mat)
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
	if _roof != null:
		_roof.visible = wall_view == WallView.UP
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
	_rebuild_roof()


## Covers the bounding box of the indoor tiles with a gable roof whose ridge runs
## along the longer side, with a small overhang.
## Roof shapes: gable (two slopes), hip (four), flat, or none at all.
enum RoofStyle { GABLE, HIP, FLAT, NONE }
const ROOF_STYLE_NAMES: Array[String] = ["Gable", "Hip", "Flat", "No Roof"]
const ROOF_COLORS: Array = [
	["Cocoa Shingle", Color(0.36, 0.27, 0.27)],
	["Slate", Color(0.3, 0.34, 0.42)],
	["Terracotta", Color(0.66, 0.33, 0.22)],
	["Forest", Color(0.24, 0.36, 0.27)],
	["Sandstone", Color(0.72, 0.64, 0.5)],
	["Charcoal", Color(0.16, 0.16, 0.18)],
]
const ROOF_PRICE := 100
var roof_style := RoofStyle.GABLE
var roof_color := 0


func set_roof(style: int, color: int) -> void:
	roof_style = style as RoofStyle
	roof_color = clampi(color, 0, ROOF_COLORS.size() - 1)
	_rebuild_roof()


func _rebuild_roof() -> void:
	if _roof == null:
		_roof = MeshInstance3D.new()
		_roof.name = "Roof"
		var m := ShaderMaterial.new()
		m.shader = Shader.new()
		m.shader.code = """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 shingle = vec3(0.36, 0.27, 0.27);
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec3 c = shingle;
	if (COLOR.r > 0.5) {
		c = vec3(0.92, 0.89, 0.82);
	} else if (COLOR.g > 0.5) {
		c = mix(shingle, vec3(0.75), 0.55);
	} else {
		float row = fract(wp.y * 5.0);
		float x = fract((wp.x + wp.z) * 2.5 + floor(wp.y * 5.0) * 0.5);
		c *= 0.9 + 0.12 * step(0.5, x);
		c *= 1.0 - smoothstep(0.85, 1.0, row) * 0.35;
	}
	ALBEDO = pow(c, vec3(2.2));
	ROUGHNESS = 0.8;
}
"""
		_roof.material_override = m
		add_child(_roof)
	(_roof.material_override as ShaderMaterial).set_shader_parameter("shingle", ROOF_COLORS[roof_color][1])
	if _interior.is_empty() or roof_style == RoofStyle.NONE:
		_roof.mesh = null
		return
	var lo := Vector2i(size.x, size.y)
	var hi := Vector2i(-1, -1)
	for c in _interior:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	var oh := 0.4 if roof_style != RoofStyle.FLAT else 0.15
	var x0 := lo.x * CELL - oh
	var x1 := (hi.x + 1) * CELL + oh
	var z0 := lo.y * CELL - oh
	var z1 := (hi.y + 1) * CELL + oh
	var along_x := (x1 - x0) >= (z1 - z0)
	# Work in (u along the ridge, v across it) and map back to the lot.
	var u0 := x0 if along_x else z0
	var u1 := x1 if along_x else z1
	var v0 := z0 if along_x else x0
	var v1 := z1 if along_x else x1
	var span := v1 - v0
	var h := WALL_HEIGHT
	var rise := span * 0.4
	var vm := (v0 + v1) * 0.5
	var um := (u0 + u1) * 0.5
	var at := func(u: float, y: float, v: float) -> Vector3:
		return Vector3(u, y, v) if along_x else Vector3(v, y, u)
	var centre: Vector3 = at.call(um, h - 2.0, vm)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shingle := Color.BLACK
	var gable := Color.WHITE
	var flat := Color(0, 1, 0)
	match roof_style:
		RoofStyle.GABLE:
			var a: Vector3 = at.call(u0, h, v0)
			var b: Vector3 = at.call(u1, h, v0)
			var c: Vector3 = at.call(u1, h + rise, vm)
			var d: Vector3 = at.call(u0, h + rise, vm)
			var e: Vector3 = at.call(u0, h, v1)
			var f: Vector3 = at.call(u1, h, v1)
			_quad_out(st, a, b, c, d, shingle, centre)
			_quad_out(st, f, e, d, c, shingle, centre)
			_tri_out(st, at.call(u0 + oh, h, v0 + oh), at.call(u0 + oh, h, v1 - oh), at.call(u0 + oh, h + rise, vm), gable, centre)
			_tri_out(st, at.call(u1 - oh, h, v1 - oh), at.call(u1 - oh, h, v0 + oh), at.call(u1 - oh, h + rise, vm), gable, centre)
		RoofStyle.HIP:
			var inset := minf(span * 0.5, (u1 - u0) * 0.5)
			var r0: Vector3 = at.call(u0 + inset, h + rise, vm)
			var r1: Vector3 = at.call(u1 - inset, h + rise, vm)
			var a: Vector3 = at.call(u0, h, v0)
			var b: Vector3 = at.call(u1, h, v0)
			var e: Vector3 = at.call(u0, h, v1)
			var f: Vector3 = at.call(u1, h, v1)
			_quad_out(st, a, b, r1, r0, shingle, centre)
			_quad_out(st, f, e, r0, r1, shingle, centre)
			_tri_out(st, e, a, r0, shingle, centre)
			_tri_out(st, b, f, r1, shingle, centre)
		RoofStyle.FLAT:
			var t := h + 0.18
			var a: Vector3 = at.call(u0, t, v0)
			var b: Vector3 = at.call(u1, t, v0)
			var c: Vector3 = at.call(u1, t, v1)
			var d: Vector3 = at.call(u0, t, v1)
			_quad_out(st, a, b, c, d, flat, centre)
			var down := Vector3(0, -0.22, 0)
			_quad_out(st, a, b, b + down, a + down, gable, centre)
			_quad_out(st, b, c, c + down, b + down, gable, centre)
			_quad_out(st, c, d, d + down, c + down, gable, centre)
			_quad_out(st, d, a, a + down, d + down, gable, centre)
	st.generate_normals()
	_roof.mesh = st.commit()


## A triangle wound so its face points away from `centre` (for proper lighting).
func _tri_out(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color, centre: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.dot((a + b + c) / 3.0 - centre) < 0.0:
		_tri(st, a, c, b, col)
	else:
		_tri(st, a, b, c, col)


func _quad_out(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, centre: Vector3) -> void:
	_tri_out(st, a, b, c, col, centre)
	_tri_out(st, a, c, d, col, centre)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	_tri(st, a, b, c, col)
	_tri(st, a, c, d, col)


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	for v in [a, b, c]:
		st.set_color(col)
		st.add_vertex(v)


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
	for e in gates:
		var gh: Node3D = (fences[e] as Node3D).get_meta("hinge")
		var gc := edge_center(e)
		var gate_open := false
		for p in people:
			if Vector2(p.x - gc.x, p.z - gc.z).length() < 0.9:
				gate_open = true
		gh.rotation.y = lerpf(gh.rotation.y, 1.4 if gate_open else 0.0, 1.0 - exp(-8.0 * delta))


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

	var raw: Array[Vector3] = [Vector3(from.x, base_y(), from.z)]
	for i in range(1, ids.size() - 1):
		var p := _astar.get_point_position(ids[i])
		raw.append(cell_to_world(Vector2i(int(p.x), int(p.y))))
	raw.append(Vector3(to.x, base_y(), to.z))

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
## The wall edge a wall-mounted object at `cell`/`rot` hangs on.
static func wall_edge_for(cell: Vector2i, rot: int) -> Vector3i:
	match posmod(rot, 4):
		0:
			return Vector3i(cell.x, cell.y, 0)
		1:
			return Vector3i(cell.x, cell.y, 1)
		2:
			return Vector3i(cell.x, cell.y + 1, 0)
		_:
			return Vector3i(cell.x + 1, cell.y, 1)


## Whether a wall-mounted object fits: a plain wall (no door or window) with
## nothing else hanging on that side.
func can_hang(f: Furniture, cell: Vector2i, rot: int) -> bool:
	var e := wall_edge_for(cell, rot)
	if not walls.has(e) or doors.has(e) or windows.has(e):
		return false
	for o in furniture:
		if o != f and o.wall_mounted and o.cell == cell and o.rot_steps == posmod(rot, 4):
			return false
	return true


func position_furniture(f: Furniture, at_cell: Vector2i, rot_steps: int) -> void:
	f.rot_steps = posmod(rot_steps, 4)
	f.cell = at_cell
	if f.wall_mounted:
		# Against the wall, at eye level, facing into the tile.
		var c := Vector3((at_cell.x + 0.5) * CELL, 1.45, (at_cell.y + 0.5) * CELL)
		var back := Vector3.FORWARD.rotated(Vector3.UP, f.rot_steps * PI * 0.5)
		f.position = c + back * (CELL * 0.5 - WALL_THICKNESS * 0.5 - 0.03)
		f.rotation.y = f.rot_steps * PI * 0.5
		return
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
	if not f.blocks or f.wall_mounted:
		furniture.append(f)
		return
	var rect := f.footprint_rect()
	set_rect_blocked(rect, true)
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			_occupant[Vector2i(x, y)] = f
	furniture.append(f)


## Removes every wall, door, floor, decoration and object, leaving an empty lot.
func clear_build() -> void:
	for f in furniture.duplicate():
		remove_furniture(f)
		f.queue_free()
	for e in walls.keys():
		remove_wall(e)
	for e in fences.keys():
		remove_fence(e)
	roof_style = RoofStyle.GABLE
	roof_color = 0
	lot_traits = []
	floor_tiles.clear()
	_rebuild_floor()
	pools.clear()
	_rebuild_pools()
	for n in _built:
		if n.has_meta("blocks"):
			set_rect_blocked(n.get_meta("blocks"), false)
		n.queue_free()
	_built.clear()
	_dirty = true
	_rooms_dirty = true


## Takes `f` off the grid; the node itself stays (e.g. while it is being moved).
## Messes on the lot right now.
func messes() -> Array[Furniture]:
	var out: Array[Furniture] = []
	for f in furniture:
		if Catalog.MESSES.has(f.kind):
			out.append(f)
	return out


## Leaves a mess (Catalog.MESSES kind) on the nearest free tile to `near`.
func add_mess(kind: String, near: Vector3) -> Furniture:
	var c := nearest_walkable(world_to_cell(near))
	var m := Catalog.create(kind)
	place_furniture(m, c, 0)
	return m


func remove_furniture(f: Furniture) -> void:
	if not furniture.has(f):
		return
	if not f.blocks or f.wall_mounted:
		furniture.erase(f)
		return
	var rect := f.footprint_rect()
	set_rect_blocked(rect, false)
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			_occupant.erase(Vector2i(x, y))
	furniture.erase(f)


# --- Ground and decoration --------------------------------------------------

func _build_ground() -> void:
	_ground_mesh = MeshInstance3D.new()
	_ground_mesh.name = "LotGround"
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/lot_ground.gdshader")
	_ground_mesh.material_override = mat
	add_child(_ground_mesh)
	_rebuild_ground()

	# The neighbourhood around the lot, slightly darker and without a grid; it
	# leaves a hole where the lot is so pools can be dug.
	var outer := MeshInstance3D.new()
	outer.name = "Surroundings"
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var w := size.x * CELL
	var d := size.y * CELL
	for r in [Rect2(-100, -100, w + 200, 100), Rect2(-100, d, w + 200, 100), Rect2(-100, 0, 100, d), Rect2(w, 0, 100, d)]:
		_quad_xz(st, r, -0.02)
	outer.mesh = st.commit()
	var outer_mat := StandardMaterial3D.new()
	outer_mat.albedo_color = Color(0.27, 0.42, 0.2)
	outer_mat.roughness = 1.0
	outer.material_override = outer_mat
	add_child(outer)


func _quad_xz(st: SurfaceTool, r: Rect2, y: float) -> void:
	var a := Vector3(r.position.x, y, r.position.y)
	var b := Vector3(r.end.x, y, r.position.y)
	var c := Vector3(r.end.x, y, r.end.y)
	var d := Vector3(r.position.x, y, r.end.y)
	for v in [a, b, c, a, c, d]:
		st.add_vertex(v)


func is_pool(c: Vector2i) -> bool:
	for r in pools:
		if (r as Rect2i).has_point(c):
			return true
	return false


## Grass on every tile that isn't dug out for a pool.
func _rebuild_ground() -> void:
	if _ground_mesh == null:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for y in size.y:
		for x in size.x:
			if not is_pool(Vector2i(x, y)):
				_quad_xz(st, Rect2(x * CELL, y * CELL, CELL, CELL), 0.0)
	_ground_mesh.mesh = st.commit()


## Digs a pool over `rect` (tiles must be free). Returns the Pool object.
func add_pool(rect: Rect2i) -> Furniture:
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			if not in_bounds(Vector2i(x, y)) or not is_walkable(Vector2i(x, y)) or is_pool(Vector2i(x, y)):
				return null
	var pool := Catalog.create("pool")
	pool.footprint = rect.size
	pool.build_collider()
	# Ladders/steps on every side: Sims climb in from the nearest edge.
	pool.spots.clear()
	var half := Vector2(rect.size) * 0.5
	pool.spots.append(Vector3(0, 0, half.y + 0.5))
	pool.spots.append(Vector3(0, 0, -half.y - 0.5))
	pool.spots.append(Vector3(half.x + 0.5, 0, 0))
	pool.spots.append(Vector3(-half.x - 0.5, 0, 0))
	place_furniture(pool, rect.position, 0)
	pools[rect] = pool
	_rebuild_pools()
	return pool


func remove_pool(pool: Furniture) -> void:
	for r in pools.keys():
		if pools[r] == pool:
			pools.erase(r)
	remove_furniture(pool)
	pool.queue_free()
	_rebuild_pools()


## Tiled pool walls and floor, stone coping round the edge, and the water.
func _rebuild_pools() -> void:
	_rebuild_ground()
	if _pool_mesh == null:
		_pool_mesh = MeshInstance3D.new()
		_pool_mesh.name = "PoolShell"
		_pool_mesh.material_override = Finishes.pool_material()
		add_child(_pool_mesh)
		_water_mesh = MeshInstance3D.new()
		_water_mesh.name = "Water"
		_water_mesh.material_override = Finishes.water_material()
		_water_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_water_mesh)
	if pools.is_empty():
		_pool_mesh.mesh = null
		_water_mesh.mesh = null
		return
	var shell := SurfaceTool.new()
	shell.begin(Mesh.PRIMITIVE_TRIANGLES)
	var water := SurfaceTool.new()
	water.begin(Mesh.PRIMITIVE_TRIANGLES)
	water.set_normal(Vector3.UP)
	var stone := Color(0.9, 0.88, 0.82)
	var tile := Color(0.55, 0.8, 0.92)
	for r in pools:
		var rect := r as Rect2i
		var x0 := rect.position.x * CELL
		var z0 := rect.position.y * CELL
		var x1 := rect.end.x * CELL
		var z1 := rect.end.y * CELL
		var bottom := -POOL_DEPTH
		shell.set_color(tile)
		shell.set_normal(Vector3.UP)
		for v in [Vector3(x0, bottom, z0), Vector3(x1, bottom, z0), Vector3(x1, bottom, z1), Vector3(x0, bottom, z0), Vector3(x1, bottom, z1), Vector3(x0, bottom, z1)]:
			shell.add_vertex(v)
		# Four inner walls, facing into the pool.
		var walls_in := [
			[Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3.BACK],
			[Vector3(x1, 0, z1), Vector3(x0, 0, z1), Vector3.FORWARD],
			[Vector3(x0, 0, z1), Vector3(x0, 0, z0), Vector3.RIGHT],
			[Vector3(x1, 0, z0), Vector3(x1, 0, z1), Vector3.LEFT],
		]
		for wl in walls_in:
			var a: Vector3 = wl[0]
			var b: Vector3 = wl[1]
			shell.set_normal(wl[2])
			var ab := Vector3(b.x, bottom, b.z)
			var aa := Vector3(a.x, bottom, a.z)
			for v in [a, b, ab, a, ab, aa]:
				shell.add_vertex(v)
		# Coping: a raised stone rim round the edge.
		shell.set_color(stone)
		shell.set_normal(Vector3.UP)
		var cw := 0.28
		for rim in [Rect2(x0 - cw, z0 - cw, x1 - x0 + cw * 2, cw), Rect2(x0 - cw, z1, x1 - x0 + cw * 2, cw),
				Rect2(x0 - cw, z0, cw, z1 - z0), Rect2(x1, z0, cw, z1 - z0)]:
			_quad_xz(shell, rim, 0.05)
		_quad_xz(water, Rect2(x0, z0, x1 - x0, z1 - z0), WATER_LEVEL)
	_pool_mesh.mesh = shell.commit()
	_water_mesh.mesh = water.commit()

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
	m.set_meta("blocks", rect)
	add_child(m)
	_built.append(m)
	return m


## Covers a rectangle of tiles with a floor finish (Finishes.FLOORS index).
func add_floor(rect: Rect2i, style: int) -> void:
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			if in_bounds(Vector2i(x, y)):
				floor_tiles[Vector2i(x, y)] = style
	_rebuild_floor()
