class_name Sim
extends Node3D
## A simple stylised person. Walks along paths from its Lot and works through a queue
## of actions (walk somewhere, or use an object).

signal arrived
signal queue_changed
signal action_failed(message: String)
## Something worth telling the player (skill level, money earned...).
signal announced(message: String)
signal earned(amount: int)

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
@export var hair_color := Color(0.25, 0.16, 0.1)
@export var walk_speed := 2.0

var lot: Lot
var needs := Needs.new()
var emotions := Emotions.new()
var skills := Skills.new()
var traits: Array[String] = []
## trait -> game minutes until its periodic moodlet comes back.
var _trait_timers := {}
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
var _plumbob: MeshInstance3D
## Materials by part ("shirt", "pants", "skin", "hair") so the look can change later.
var _materials := {}


func _ready() -> void:
	_build_visual()
	skills.leveled_up.connect(func(s: String, l: int):
		announced.emit("%s reached %s level %d!" % [sim_name, Skills.label(s), l]))


## Recolours one part of the Sim: "shirt", "pants", "skin" or "hair".
func set_part_color(part: String, c: Color) -> void:
	match part:
		"shirt": shirt_color = c
		"pants": pants_color = c
		"skin": skin_color = c
		"hair": hair_color = c
	if _materials.has(part):
		(_materials[part] as StandardMaterial3D).albedo_color = c


## Replaces the Sim's traits and their lasting moodlets.
func set_traits(list: Array[String]) -> void:
	for t in traits:
		emotions.remove("trait_" + t)
	traits = list.duplicate()
	_trait_timers.clear()
	for t in traits:
		var info: Dictionary = Traits.INFO[t]
		if info.has("lasting"):
			var l: Array = info["lasting"]
			emotions.add("trait_" + t, l[0], l[1], l[2], l[3])
		if info.has("periodic"):
			# First occurrence comes partway through the cycle.
			_trait_timers[t] = info["periodic"][4] * 0.25


func _update_traits(minutes: float) -> void:
	for t in _trait_timers:
		_trait_timers[t] -= minutes
		if _trait_timers[t] <= 0.0:
			var p: Array = Traits.INFO[t]["periodic"]
			_trait_timers[t] += p[4]
			emotions.add("trait_" + t, p[0], p[1], p[2], p[3], p[5])


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


## Drops every queued action (used when entering build mode).
func clear_queue() -> void:
	while not queue.is_empty():
		cancel(queue.size() - 1)
	stop()


func stop() -> void:
	path = PackedVector3Array()
	_path_index = 0


func set_selected(selected: bool) -> void:
	_selected = selected
	_selection_ring.visible = selected and _pose == "stand"
	_plumbob.visible = selected


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
		_practise(cur.interaction, Clock.game_delta)
	needs.tick(Clock.game_delta, rates, Traits.decay_mult(traits))
	emotions.tick(Clock.game_delta)
	emotions.sync_needs(needs)
	_update_traits(Clock.game_delta)

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
		if cur.elapsed >= cur.interaction.max_minutes or full or _should_abandon(cur):
			_end_perform(cur, true)
			_complete(cur)
	_animate(delta, moving, cur)


## Sims drop something they chose themselves when another need becomes critical.
func _should_abandon(a: SimAction) -> bool:
	if not a.autonomous:
		return false
	for n in Needs.ORDER:
		if needs.get_value(n) < Needs.CRITICAL and a.interaction.rates.get(n, 0.0) <= 0.0:
			return true
	return false


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
		if not lot.is_walkable(lot.world_to_cell(s)) or lot.crosses_wall(s, f.global_position):
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


## Experience gained for `minutes` of an activity, sped up by traits and by feeling
## the emotion that suits the skill.
func skill_gain(interaction: Interaction, minutes: float) -> float:
	if interaction.skill == "":
		return 0.0
	var gain := interaction.skill_rate * minutes / 60.0 * Traits.skill_mult(traits, interaction.skill)
	if emotions.mood() == Skills.boosting_emotion(interaction.skill):
		gain *= Skills.EMOTION_BONUS
	return gain


func _practise(interaction: Interaction, minutes: float) -> void:
	if interaction.skill != "":
		skills.add_xp(interaction.skill, skill_gain(interaction, minutes))


## Moodlet and pay for an activity done long enough. Skill makes both better.
## Pay only comes when the activity is finished, not cancelled.
func _reward(i: Interaction, minutes_done: float, finished: bool) -> void:
	if minutes_done < i.reward_after():
		return
	var lvl := skills.level(i.skill) if i.skill != "" else 0
	if not i.moodlet.is_empty():
		var m := i.moodlet
		emotions.add(m[0], m[1], m[2] + lvl / 4, m[3], m[4], m[5])
	if i.earns > 0 and finished:
		var amount := i.earns + i.earns_per_level * lvl
		earned.emit(amount)
		announced.emit("%s sold their painting for §%d." % [sim_name, amount])


func _end_perform(a: SimAction, finished := false) -> void:
	if not a.performing:
		return
	_reward(a.interaction, a.elapsed, finished)
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
	# The plumbob floats over the head, spinning and bobbing even while paused.
	_plumbob.rotation.y += get_process_delta_time() * 1.8
	var head := _body.to_global(Vector3(0, 1.66, 0))
	_plumbob.global_position = head + Vector3(0, 0.55 + sin(Time.get_ticks_msec() * 0.003) * 0.04, 0)


func _build_visual() -> void:
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)

	var shirt := _mat(shirt_color)
	var pants := _mat(pants_color)
	var skin := _mat(skin_color)
	_materials = {"shirt": shirt, "pants": pants, "skin": skin, "hair": _mat(hair_color)}

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
	hair.material_override = _materials["hair"]
	_body.add_child(hair)

	# Face: eyes, brows and a mouth (the front of the head is -Z).
	for x in [-0.052, 0.052]:
		_face_part(SphereMesh.new(), Vector3(0.034, 0.03, 0.02), Vector3(x, 1.685, -0.128), Color(0.97, 0.97, 0.95))
		_face_part(SphereMesh.new(), Vector3(0.018, 0.02, 0.012), Vector3(x, 1.685, -0.139), Color(0.12, 0.08, 0.06))
		_face_part(BoxMesh.new(), Vector3(0.045, 0.01, 0.01), Vector3(x, 1.722, -0.13), Color(0.0, 0.0, 0.0), "hair")
	_face_part(BoxMesh.new(), Vector3(0.06, 0.012, 0.01), Vector3(0, 1.59, -0.13), Color(0.6, 0.25, 0.25))

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

	# The green diamond over the controlled Sim.
	_plumbob = MeshInstance3D.new()
	_plumbob.name = "Plumbob"
	var gem_mat := _mat(Color(0.3, 0.95, 0.35))
	gem_mat.emission_enabled = true
	gem_mat.emission = Color(0.15, 0.7, 0.2)
	gem_mat.roughness = 0.2
	for half in [1.0, -1.0]:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0 if half > 0.0 else 0.11
		cone.bottom_radius = 0.11 if half > 0.0 else 0.0
		cone.height = 0.2 if half > 0.0 else 0.13
		cone.radial_segments = 6
		cone.rings = 1
		var piece := MeshInstance3D.new()
		piece.mesh = cone
		piece.position.y = 0.1 * half if half > 0.0 else -0.065
		piece.material_override = gem_mat
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Layer 2 keeps the plumbob out of the portrait camera.
		piece.layers = 2
		_plumbob.add_child(piece)
	_plumbob.top_level = true
	_plumbob.visible = false
	add_child(_plumbob)


## Adds a small face feature; `part` makes it follow that part's colour.
func _face_part(mesh: PrimitiveMesh, scale_: Vector3, pos: Vector3, color: Color, part := "") -> void:
	if mesh is SphereMesh:
		(mesh as SphereMesh).radius = 0.5
		(mesh as SphereMesh).height = 1.0
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.scale = scale_
	m.position = pos
	m.material_override = _materials[part] if part != "" else _mat(color)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(m)


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
