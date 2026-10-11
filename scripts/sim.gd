class_name Sim
extends Node3D
## A simple stylised person. Walks along paths from its Lot and works through a queue
## of actions (walk somewhere, or use an object).

signal arrived
signal queue_changed
signal action_failed(message: String)

const MAX_QUEUE := 8
## Game minutes a Sim stands around before deciding something on their own.
const IDLE_BEFORE_AUTONOMY := 4.0


class SimAction:
	extends RefCounted
	var label: String
	var target := Vector3.ZERO
	var furniture: Furniture
	var interaction: Interaction
	var autonomous := false
	var started := false
	var performing := false
	var elapsed := 0.0
	var spot := Vector3.ZERO

	func progress() -> float:
		if not performing or interaction == null:
			return 0.0
		return clampf(elapsed / interaction.max_minutes, 0.0, 1.0)


@export var sim_name := "Alex"
@export var shirt_color := Color(0.22, 0.47, 0.82)
@export var pants_color := Color(0.18, 0.2, 0.28)
@export var skin_color := Color(0.87, 0.69, 0.55)
@export var walk_speed := 2.0

var lot: Lot
var needs := Needs.new()
var autonomy_enabled := true
var _idle_minutes := 0.0
var _rng := RandomNumberGenerator.new()
var queue: Array[SimAction] = []
var path := PackedVector3Array()
var _path_index := 0
var _walk_phase := 0.0
var _busy_phase := 0.0
var _swing := 0.0
var _pose := "stand"
var _selected := false

var _body: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _selection_ring: MeshInstance3D


func _ready() -> void:
	_build_visual()


func is_moving() -> bool:
	return _path_index < path.size()


func is_idle() -> bool:
	return queue.is_empty()


func current_action() -> SimAction:
	return queue[0] if not queue.is_empty() else null


## Starts walking to `target`. Returns false if there is no route.
func move_to(target: Vector3) -> bool:
	var p := lot.find_path(global_position, target)
	if p.is_empty():
		return false
	path = p
	_path_index = 0
	return true


func stop() -> void:
	path = PackedVector3Array()
	_path_index = 0


func set_selected(selected: bool) -> void:
	_selected = selected
	_selection_ring.visible = selected and _pose == "stand"


func queue_go(target: Vector3) -> bool:
	var a := SimAction.new()
	a.label = "Go Here"
	a.target = target
	return _enqueue(a)


func queue_interaction(f: Furniture, interaction: Interaction, autonomous := false) -> bool:
	var a := SimAction.new()
	a.label = interaction.name
	a.furniture = f
	a.interaction = interaction
	a.autonomous = autonomous
	return _enqueue(a)


## Cancels the action at `index`; a running one stops right away.
func cancel(index: int) -> void:
	if index < 0 or index >= queue.size():
		return
	var a := queue[index]
	if a.started:
		if a.performing:
			_end_perform(a)
		else:
			stop()
	queue.erase(a)
	queue_changed.emit()


func _enqueue(a: SimAction) -> bool:
	if not a.autonomous:
		# A direct order replaces whatever the Sim chose on their own.
		for i in range(queue.size() - 1, -1, -1):
			if queue[i].autonomous:
				cancel(i)
	if queue.size() >= MAX_QUEUE:
		action_failed.emit("%s's queue is full." % sim_name)
		return false
	queue.append(a)
	queue_changed.emit()
	return true


func _process(real_delta: float) -> void:
	var delta := Clock.scaled(real_delta)
	var cur := current_action()
	if cur != null and not cur.started:
		_start(cur)
		cur = current_action()

	var rates := {}
	if cur != null and cur.performing:
		rates = cur.interaction.rates
	needs.tick(Clock.game_delta, rates)

	_update_autonomy()
	var moving := _follow_path(delta)
	if cur != null and cur.started and not cur.performing and not is_moving():
		if cur.interaction == null:
			_complete(cur)
		else:
			_begin_perform(cur)
	elif cur != null and cur.performing:
		cur.elapsed += Clock.game_delta
		var full := cur.interaction.until_full != "" and needs.get_value(cur.interaction.until_full) >= 99.9
		if cur.elapsed >= cur.interaction.max_minutes or full:
			_end_perform(cur)
			_complete(cur)
	_animate(delta, moving, cur)


func _update_autonomy() -> void:
	if not queue.is_empty() or is_moving():
		_idle_minutes = 0.0
		return
	_idle_minutes += Clock.game_delta
	if not autonomy_enabled or _idle_minutes < IDLE_BEFORE_AUTONOMY:
		return
	_idle_minutes = 0.0
	var pick := Autonomy.choose(self, lot, _rng)
	if not pick.is_empty():
		queue_interaction(pick[0], pick[1], true)


func _start(a: SimAction) -> void:
	a.started = true
	if a.interaction == null:
		if not move_to(a.target):
			_fail(a, "%s can't get there." % sim_name)
		return
	var f := a.furniture
	if f.user != null and f.user != self:
		_fail(a, "The %s is in use." % f.display_name)
		return
	var best := PackedVector3Array()
	var best_len := INF
	for s in f.world_spots():
		if not lot.is_walkable(lot.world_to_cell(s)):
			continue
		var p := lot.find_path(global_position, s)
		if p.is_empty():
			continue
		var length := 0.0
		var prev := global_position
		for q in p:
			length += prev.distance_to(q)
			prev = q
		if length < best_len:
			best_len = length
			best = p
			a.spot = s
	if best.is_empty():
		_fail(a, "%s can't reach the %s." % [sim_name, f.display_name])
		return
	path = best
	_path_index = 0


func _begin_perform(a: SimAction) -> void:
	a.performing = true
	var f := a.furniture
	f.user = self
	var facing: Vector3
	if f.use_position != null:
		global_position = f.to_global(f.use_position)
		facing = f.global_basis * f.use_facing
	else:
		facing = f.global_position - global_position
	facing.y = 0.0
	if facing.length() > 0.01:
		rotation.y = atan2(-facing.x, -facing.z)
	_set_pose(a.interaction.pose)


func _end_perform(a: SimAction) -> void:
	if not a.performing:
		return
	a.performing = false
	a.furniture.user = null
	if a.furniture.use_position != null:
		global_position = a.spot
	_set_pose("stand")


func _complete(a: SimAction) -> void:
	queue.erase(a)
	queue_changed.emit()
	if a.interaction == null:
		arrived.emit()


func _fail(a: SimAction, message: String) -> void:
	queue.erase(a)
	queue_changed.emit()
	if not a.autonomous:
		action_failed.emit(message)


func _follow_path(delta: float) -> bool:
	if _path_index >= path.size():
		return false
	var target := path[_path_index]
	var to := target - global_position
	to.y = 0.0
	var step := walk_speed * delta
	if to.length() <= step:
		global_position = Vector3(target.x, 0.0, target.z)
		_path_index += 1
		if _path_index >= path.size():
			stop()
			return false
		return true
	var dir := to.normalized()
	global_position += dir * step
	_face(dir, delta)
	return true


func _face(dir: Vector3, delta: float) -> void:
	var desired := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, desired, 1.0 - exp(-14.0 * delta))


func _set_pose(p: String) -> void:
	_pose = p
	_selection_ring.visible = _selected and _pose == "stand"


func _animate(delta: float, moving: bool, cur: SimAction) -> void:
	var target_swing := 0.55 if moving else 0.0
	_swing = lerpf(_swing, target_swing, 1.0 - exp(-10.0 * delta))
	if moving:
		_walk_phase += delta * walk_speed * 3.6
	_busy_phase += delta * 8.0
	var s := sin(_walk_phase) * _swing
	var busy := cur != null and cur.performing and cur.interaction.busy_hands
	var arm_l := -s * 0.8
	var arm_r := s * 0.8
	if busy:
		arm_l = 0.9 + sin(_busy_phase) * 0.15
		arm_r = 0.9 - sin(_busy_phase) * 0.15
	match _pose:
		"sit":
			_body.rotation.x = 0.0
			_body.position.y = -0.45
			_leg_l.rotation.x = PI * 0.5
			_leg_r.rotation.x = PI * 0.5
		"lie":
			_body.rotation.x = PI * 0.5
			_body.position.y = 0.15
			_leg_l.rotation.x = 0.0
			_leg_r.rotation.x = 0.0
			arm_l = 0.0
			arm_r = 0.0
		_:
			_body.rotation.x = 0.0
			_body.position.y = absf(sin(_walk_phase)) * 0.035 * (_swing / 0.55)
			_leg_l.rotation.x = s
			_leg_r.rotation.x = -s
	_arm_l.rotation.x = arm_l
	_arm_r.rotation.x = arm_r


func _build_visual() -> void:
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)

	var shirt := _mat(shirt_color)
	var pants := _mat(pants_color)
	var skin := _mat(skin_color)

	_leg_l = _limb(Vector3(-0.1, 0.9, 0), 0.085, 0.9, pants)
	_leg_r = _limb(Vector3(0.1, 0.9, 0), 0.085, 0.9, pants)
	_arm_l = _limb(Vector3(-0.27, 1.42, 0), 0.06, 0.62, shirt)
	_arm_r = _limb(Vector3(0.27, 1.42, 0), 0.06, 0.62, shirt)

	var torso := MeshInstance3D.new()
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.2
	torso_mesh.height = 0.68
	torso.mesh = torso_mesh
	torso.scale = Vector3(1.0, 1.0, 0.7)
	torso.position = Vector3(0, 1.18, 0)
	torso.material_override = shirt
	_body.add_child(torso)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.14
	head_mesh.height = 0.3
	head.mesh = head_mesh
	head.position = Vector3(0, 1.66, 0)
	head.material_override = skin
	_body.add_child(head)

	var hair := MeshInstance3D.new()
	var hair_mesh := SphereMesh.new()
	hair_mesh.radius = 0.15
	hair_mesh.height = 0.2
	hair_mesh.is_hemisphere = true
	hair.mesh = hair_mesh
	hair.position = Vector3(0, 1.69, 0.015)
	hair.material_override = _mat(Color(0.25, 0.16, 0.1))
	_body.add_child(hair)

	# Nose, so facing direction is readable from the camera.
	var nose := MeshInstance3D.new()
	var nose_mesh := BoxMesh.new()
	nose_mesh.size = Vector3(0.04, 0.05, 0.05)
	nose.mesh = nose_mesh
	nose.position = Vector3(0, 1.64, -0.145)
	nose.material_override = skin
	_body.add_child(nose)

	_selection_ring = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.34
	ring.outer_radius = 0.42
	_selection_ring.mesh = ring
	_selection_ring.position.y = 0.02
	_selection_ring.scale.y = 0.15
	var ring_mat := _mat(Color(0.35, 0.95, 0.45))
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(0.2, 0.8, 0.3)
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_selection_ring.material_override = ring_mat
	_selection_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_selection_ring)


func _limb(pivot_pos: Vector3, radius: float, length: float, mat: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pivot_pos
	_body.add_child(pivot)
	var m := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = length
	m.mesh = capsule
	m.position = Vector3(0, -length * 0.5, 0)
	m.material_override = mat
	pivot.add_child(m)
	return pivot


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	return m
