class_name BuildMode
extends Node
## Build/buy mode: place, move, rotate and sell furniture, draw walls, add doors.
## Time is paused while it is open. It has its own tool bar along the bottom.

signal funds_changed(funds: int)
signal notice(text: String)

enum Tool { MOVE, WALL, DOOR, DELETE, PLACE }

var lot: Lot
var sim: Sim
var camera: Camera3D
var active := false
var tool := Tool.MOVE
var funds := 20000

var _held: Furniture = null
var _held_is_new := false
var _held_from := Vector2i.ZERO
var _held_from_rot := 0
var _held_rot := 0
var _held_cell := Vector2i.ZERO
var _wall_start: Variant = null
var _wall_end := Vector2i.ZERO
var _speed_before := 1

var _footprint: MeshInstance3D
var _footprint_mat: StandardMaterial3D
var _wall_preview: MeshInstance3D
var _edge_marker: MeshInstance3D
var _ui: CanvasLayer
var _tool_buttons := {}


func _ready() -> void:
	_footprint = _overlay_box(Color(0.3, 0.9, 0.4, 0.45))
	_footprint_mat = _footprint.material_override
	_wall_preview = _overlay_box(Color(0.4, 0.7, 1.0, 0.55))
	_edge_marker = _overlay_box(Color(1.0, 0.85, 0.3, 0.7))
	_build_ui()
	_set_visible(false)


func enter() -> void:
	if active:
		return
	active = true
	_speed_before = maxi(Clock.speed, 1)
	Clock.set_speed(0)
	sim.clear_queue()
	set_tool(Tool.MOVE)
	_set_visible(true)


func exit() -> void:
	if not active:
		return
	_cancel_held()
	_wall_start = null
	active = false
	_set_visible(false)
	Clock.set_speed(_speed_before)


func set_tool(t: Tool) -> void:
	if t != Tool.PLACE:
		_cancel_held()
	_wall_start = null
	tool = t
	for k in _tool_buttons:
		(_tool_buttons[k] as Button).button_pressed = (k == t)
	_refresh_overlays(null)


## Starts placing a new object of `kind` from the catalogue.
func start_place(kind: String) -> void:
	set_tool(Tool.PLACE)
	var price: int = Catalog.INFO[kind][1]
	if price > funds:
		notice.emit("Not enough funds for the %s." % Catalog.INFO[kind][0])
		return
	var f := Catalog.create(kind)
	lot.add_child(f)
	_pick_up(f, true)


func handle_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_refresh_overlays(_ground((event as InputEventMouseMotion).position))
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var p: Variant = _ground(mb.position)
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_on_press(p, mb.position)
			elif tool == Tool.WALL and _wall_start != null:
				_finish_wall()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if _held != null:
				_cancel_held()
			_wall_start = null
			_refresh_overlays(p)
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		match (event as InputEventKey).keycode:
			KEY_R, KEY_PERIOD:
				_rotate_held(1)
			KEY_COMMA:
				_rotate_held(-1)
			KEY_DELETE, KEY_BACKSPACE:
				if _held != null:
					_sell(_held)
			KEY_ESCAPE:
				_cancel_held()
				_wall_start = null
				_refresh_overlays(null)


func _on_press(p: Variant, screen_pos: Vector2) -> void:
	if p == null:
		return
	var pt: Vector3 = p
	match tool:
		Tool.MOVE, Tool.PLACE:
			if _held != null:
				_drop()
			elif tool == Tool.MOVE:
				var f := _furniture_under(screen_pos)
				if f != null:
					_pick_up(f, false)
		Tool.WALL:
			_wall_start = _vertex(pt)
			_wall_end = _wall_start
		Tool.DOOR:
			var e := lot.edge_near(pt)
			if not lot.walls.has(e):
				notice.emit("Doors go on walls.")
			elif lot.doors.has(e):
				pass
			elif _spend(Catalog.DOOR_PRICE):
				lot.add_door(e)
		Tool.DELETE:
			var f := _furniture_under(screen_pos)
			if f != null:
				lot.remove_furniture(f)
				_sell(f)
			else:
				var e := lot.edge_near(pt)
				if lot.walls.has(e):
					_earn(Catalog.WALL_PRICE + (Catalog.DOOR_PRICE if lot.doors.has(e) else 0))
					lot.remove_wall(e)
	_refresh_overlays(p)


func _finish_wall() -> void:
	var built := 0
	for e in Lot.wall_run(_wall_start, _wall_end):
		if lot.walls.has(e) or not lot.edge_in_bounds(e):
			continue
		if funds < Catalog.WALL_PRICE:
			notice.emit("Out of funds.")
			break
		if lot.add_wall(e):
			_spend(Catalog.WALL_PRICE)
			built += 1
	_wall_start = null
	_wall_preview.visible = false


func _pick_up(f: Furniture, is_new: bool) -> void:
	_held = f
	_held_is_new = is_new
	_held_from = f.cell
	_held_from_rot = f.rot_steps
	_held_rot = f.rot_steps
	if not is_new:
		lot.remove_furniture(f)
	f.set_ghost(true)


func _drop() -> void:
	if not _can_drop():
		notice.emit("That doesn't fit there.")
		return
	if _held_is_new and not _spend(_held.price):
		return
	lot.place_furniture(_held, _held_cell, _held_rot)
	_held.set_ghost(false)
	_held = null
	if tool == Tool.PLACE:
		set_tool(Tool.MOVE)


func _cancel_held() -> void:
	if _held == null:
		return
	if _held_is_new:
		_held.queue_free()
	else:
		lot.place_furniture(_held, _held_from, _held_from_rot)
		_held.set_ghost(false)
	_held = null
	_footprint.visible = false


func _sell(f: Furniture) -> void:
	_earn(f.price)
	if f == _held:
		_held = null
		_footprint.visible = false
	f.queue_free()


func _rotate_held(dir: int) -> void:
	if _held == null:
		return
	_held_rot = posmod(_held_rot + dir, 4)
	lot.position_furniture(_held, _held_cell, _held_rot)
	_update_footprint()


func _can_drop() -> bool:
	var avoid: Array[Vector2i] = [lot.world_to_cell(sim.global_position)]
	return lot.can_place(_held, _held_cell, _held_rot, avoid)


func _refresh_overlays(p: Variant) -> void:
	_edge_marker.visible = false
	_wall_preview.visible = false
	if not active:
		return
	if _held != null and p != null:
		var pt: Vector3 = p
		var fp := _held.footprint if _held_rot % 2 == 0 else Vector2i(_held.footprint.y, _held.footprint.x)
		_held_cell = Vector2i(floori(pt.x - fp.x * 0.5 + 0.5), floori(pt.z - fp.y * 0.5 + 0.5))
		lot.position_furniture(_held, _held_cell, _held_rot)
		_update_footprint()
	if p == null:
		return
	var at: Vector3 = p
	match tool:
		Tool.WALL:
			if _wall_start != null:
				_wall_end = _vertex(at)
				var run := Lot.wall_run(_wall_start, _wall_end)
				if not run.is_empty():
					var a := lot.edge_center(run[0])
					var b := lot.edge_center(run[run.size() - 1])
					var horizontal := run[0].z == 0
					var length := run.size() * Lot.CELL
					_wall_preview.position = (a + b) * 0.5 + Vector3(0, Lot.WALL_HEIGHT * 0.5, 0)
					_wall_preview.scale = Vector3(length + Lot.WALL_THICKNESS, Lot.WALL_HEIGHT, Lot.WALL_THICKNESS) if horizontal \
						else Vector3(Lot.WALL_THICKNESS, Lot.WALL_HEIGHT, length + Lot.WALL_THICKNESS)
					_wall_preview.visible = true
			else:
				_show_vertex(_vertex(at))
		Tool.DOOR, Tool.DELETE:
			var e := lot.edge_near(at)
			if lot.walls.has(e):
				var c := lot.edge_center(e)
				_edge_marker.position = c + Vector3(0, 0.05, 0)
				_edge_marker.scale = Vector3(1.0, 0.08, 0.3) if e.z == 0 else Vector3(0.3, 0.08, 1.0)
				_edge_marker.visible = true


func _update_footprint() -> void:
	var fp := _held.rotated_footprint()
	_footprint.position = Vector3(_held_cell.x + fp.x * 0.5, 0.03, _held_cell.y + fp.y * 0.5)
	_footprint.scale = Vector3(fp.x - 0.05, 0.02, fp.y - 0.05)
	_footprint_mat.albedo_color = Color(0.3, 0.9, 0.4, 0.45) if _can_drop() else Color(0.95, 0.25, 0.2, 0.45)
	_footprint.visible = true


func _show_vertex(v: Vector2i) -> void:
	_edge_marker.position = Vector3(v.x, 0.05, v.y)
	_edge_marker.scale = Vector3(0.25, 0.1, 0.25)
	_edge_marker.visible = true


func _vertex(p: Vector3) -> Vector2i:
	return Vector2i(clampi(roundi(p.x), 0, lot.size.x), clampi(roundi(p.z), 0, lot.size.y))


func _spend(amount: int) -> bool:
	if amount > funds:
		notice.emit("Not enough funds.")
		return false
	funds -= amount
	funds_changed.emit(funds)
	return true


func _earn(amount: int) -> void:
	funds += amount
	funds_changed.emit(funds)


func _ground(screen_pos: Vector2) -> Variant:
	var origin := camera.project_ray_origin(screen_pos)
	return Plane(Vector3.UP, 0.0).intersects_ray(origin, camera.project_ray_normal(screen_pos))


func _furniture_under(screen_pos: Vector2) -> Furniture:
	var origin := camera.project_ray_origin(screen_pos)
	var q := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(screen_pos) * 500.0)
	var hit := lot.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or not (hit.collider as Object).has_meta("furniture"):
		return null
	return (hit.collider as Object).get_meta("furniture") as Furniture


func _overlay_box(color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = BoxMesh.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.visible = false
	add_child(m)
	return m


func _set_visible(v: bool) -> void:
	_ui.visible = v
	if not v:
		_footprint.visible = false
		_wall_preview.visible = false
		_edge_marker.visible = false


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.13, 0.2, 0.92)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.position.y = -16
	_ui.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 6)
	vbox.add_child(tools)
	var tool_defs := [
		[Tool.MOVE, "Move", "Pick up an object; click to put it down. R / , . rotate, Delete sells"],
		[Tool.WALL, "Wall", "Drag along the grid to build walls ($%d each)" % Catalog.WALL_PRICE],
		[Tool.DOOR, "Door", "Click a wall to add a door ($%d)" % Catalog.DOOR_PRICE],
		[Tool.DELETE, "Sell", "Click an object or a wall to remove it for a refund"],
	]
	for d in tool_defs:
		var b := Button.new()
		b.text = d[1]
		b.tooltip_text = d[2]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(80, 32)
		b.pressed.connect(set_tool.bind(d[0]))
		tools.add_child(b)
		_tool_buttons[d[0]] = b

	var items := HBoxContainer.new()
	items.add_theme_constant_override("separation", 6)
	vbox.add_child(items)
	for kind in Catalog.KINDS:
		var b := Button.new()
		b.text = "%s\n$%d" % [Catalog.INFO[kind][0], Catalog.INFO[kind][1]]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(110, 48)
		b.pressed.connect(start_place.bind(kind))
		items.add_child(b)

	var help := Label.new()
	help.text = "Right-click or Esc: cancel   R: rotate   Delete: sell held object   F1: back to live mode"
	help.add_theme_font_size_override("font_size", 12)
	help.modulate = Color(1, 1, 1, 0.7)
	vbox.add_child(help)
