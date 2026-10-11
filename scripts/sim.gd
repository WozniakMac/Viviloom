class_name Sim
extends Node3D
## A simple stylised person that walks along paths computed by its Lot.

signal arrived

@export var sim_name := "Alex"
@export var shirt_color := Color(0.22, 0.47, 0.82)
@export var pants_color := Color(0.18, 0.2, 0.28)
@export var skin_color := Color(0.87, 0.69, 0.55)
@export var walk_speed := 2.0

var lot: Lot
var path := PackedVector3Array()
var _path_index := 0
var _walk_phase := 0.0
var _swing := 0.0

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
	_selection_ring.visible = selected


func _process(delta: float) -> void:
	var moving := false
	if _path_index < path.size():
		var target := path[_path_index]
		var to := target - global_position
		to.y = 0.0
		var step := walk_speed * delta
		if to.length() <= step:
			global_position = Vector3(target.x, 0.0, target.z)
			_path_index += 1
			moving = _path_index < path.size()
			if not moving:
				stop()
				arrived.emit()
		else:
			var dir := to.normalized()
			global_position += dir * step
			_face(dir, delta)
			moving = true
	_animate(delta, moving)


func _face(dir: Vector3, delta: float) -> void:
	var desired := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, desired, 1.0 - exp(-14.0 * delta))


func _animate(delta: float, moving: bool) -> void:
	var target_swing := 0.55 if moving else 0.0
	_swing = lerpf(_swing, target_swing, 1.0 - exp(-10.0 * delta))
	if moving:
		_walk_phase += delta * walk_speed * 3.6
	var s := sin(_walk_phase) * _swing
	_leg_l.rotation.x = s
	_leg_r.rotation.x = -s
	_arm_l.rotation.x = -s * 0.8
	_arm_r.rotation.x = s * 0.8
	_body.position.y = absf(sin(_walk_phase)) * 0.035 * (_swing / 0.55)


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
