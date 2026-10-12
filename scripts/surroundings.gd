class_name Surroundings
extends Node3D
## The street around the lot: neighbours' houses with gardens on both sides and
## across the road, street trees, streetlamps that light up at night, and low
## hills on the horizon. Purely decoration; built once.

const HOUSE_COLORS := [Color(0.93, 0.88, 0.78), Color(0.72, 0.82, 0.9), Color(0.95, 0.8, 0.72), Color(0.8, 0.88, 0.75), Color(0.96, 0.94, 0.9)]
const ROOF_COLORS := [Color(0.35, 0.28, 0.3), Color(0.55, 0.3, 0.25), Color(0.3, 0.35, 0.45), Color(0.4, 0.38, 0.35)]

var _tree_scene: PackedScene
## Shared glass for the neighbours' windows, which glow warmly after dark.
var _glass_mat: StandardMaterial3D
var _rng := RandomNumberGenerator.new()


## A streetlamp in the "lamps" group so Daylight switches it on at dusk.
class StreetLamp:
	extends Node3D
	var _light: OmniLight3D
	var _bulb_mat: StandardMaterial3D

	func _init() -> void:
		var pole := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.06
		cyl.bottom_radius = 0.09
		cyl.height = 4.0
		pole.mesh = cyl
		pole.position.y = 2.0
		var pm := StandardMaterial3D.new()
		pm.albedo_color = Color(0.18, 0.2, 0.22)
		pm.metallic = 0.6
		pole.material_override = pm
		add_child(pole)
		var bulb := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.22
		sph.height = 0.44
		bulb.mesh = sph
		bulb.position.y = 4.05
		_bulb_mat = StandardMaterial3D.new()
		_bulb_mat.albedo_color = Color(0.95, 0.93, 0.85)
		bulb.material_override = _bulb_mat
		add_child(bulb)
		_light = OmniLight3D.new()
		_light.position.y = 3.9
		_light.light_color = Color(1.0, 0.85, 0.6)
		_light.light_energy = 2.0
		_light.omni_range = 9.0
		_light.visible = false
		add_child(_light)
		add_to_group("lamps")

	func _ready() -> void:
		set_lit(Daylight.lit_now)

	func set_lit(on: bool) -> void:
		_light.visible = on
		_bulb_mat.emission_enabled = on
		_bulb_mat.emission = Color(1.0, 0.85, 0.55)
		_bulb_mat.emission_energy_multiplier = 2.0


func build(lot_size: Vector2i) -> void:
	_rng.seed = 42
	_glass_mat = StandardMaterial3D.new()
	_glass_mat.albedo_color = Color(0.55, 0.7, 0.85)
	_glass_mat.roughness = 0.1
	add_to_group("lamps")
	set_lit(Daylight.lit_now)
	if ResourceLoader.exists("res://assets/objects/tree.glb"):
		_tree_scene = load("res://assets/objects/tree.glb")
	var w := float(lot_size.x)
	var d := float(lot_size.y)
	var road_z := d + 5.0
	# Neighbours either side, and three across the road.
	_house(Vector3(-w * 0.5 - 4.0, 0, d * 0.45), false)
	_house(Vector3(w * 1.5 + 4.0, 0, d * 0.45), true)
	for k in 3:
		_house(Vector3(-w * 0.6 + k * (w + 6.0), 0, road_z + 16.0), k % 2 == 0, true)
	# Street trees and lamps along the pavement on both sides of the road.
	for k in 11:
		var x := -40.0 + k * 10.0
		_lamp(Vector3(x + 5.0, 0, d + 1.3))
		_lamp(Vector3(x, 0, road_z + 4.3))
		if absf(x - w * 0.5) > 6.0:
			_tree(Vector3(x, 0, d + 1.6), 0.9)
		_tree(Vector3(x + 4.0, 0, road_z + 5.0), 1.0)
	# Woods behind the lots and hills on the horizon.
	for k in 40:
		_tree(Vector3(_rng.randf_range(-60, 90), 0, _rng.randf_range(-40, -6)), _rng.randf_range(1.0, 1.8))
	for k in 6:
		var hill := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = _rng.randf_range(30, 45)
		s.height = s.radius * 2.0
		hill.mesh = s
		hill.scale = Vector3(1.6, 0.35, 1.0)
		hill.position = Vector3(-80 + k * 45.0, -6.0, -95.0 + _rng.randf_range(-10, 10))
		var hm := StandardMaterial3D.new()
		hm.albedo_color = Color(0.32, 0.5, 0.3).lerp(Color(0.45, 0.6, 0.55), _rng.randf())
		hm.roughness = 1.0
		hill.material_override = hm
		add_child(hill)


func set_lit(on: bool) -> void:
	_glass_mat.emission_enabled = on
	_glass_mat.emission = Color(1.0, 0.78, 0.45)
	_glass_mat.emission_energy_multiplier = 1.3


func _tree(at: Vector3, s: float) -> void:
	if _tree_scene == null:
		return
	var t := _tree_scene.instantiate() as Node3D
	t.position = at
	t.scale = Vector3.ONE * s
	t.rotation.y = _rng.randf() * TAU
	add_child(t)


func _lamp(at: Vector3) -> void:
	var l := StreetLamp.new()
	l.position = at
	add_child(l)


## A simple two-storey-ish family house with a gable roof, windows, a door, a path
## and a garden tree. `across` turns houses on the far side of the road to face it.
func _house(center: Vector3, mirror: bool, across := false) -> void:
	var root := Node3D.new()
	root.position = center
	if across:
		root.rotation.y = PI
	add_child(root)
	var size := Vector3(_rng.randf_range(10, 13), _rng.randf_range(3.0, 5.6), _rng.randf_range(8, 10))
	var wall_col: Color = HOUSE_COLORS[_rng.randi() % HOUSE_COLORS.size()]
	var roof_col: Color = ROOF_COLORS[_rng.randi() % ROOF_COLORS.size()]
	_box(root, size, Vector3(0, size.y * 0.5, 0), wall_col)
	_box(root, Vector3(size.x + 0.3, 0.3, size.z + 0.3), Vector3(0, 0.15, 0), wall_col.darkened(0.25))
	# Gable roof along X.
	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(size.z + 1.2, size.z * 0.42, size.x + 1.0)
	roof.mesh = prism
	roof.rotation.y = PI * 0.5
	roof.position = Vector3(0, size.y + size.z * 0.21, 0)
	var rm := StandardMaterial3D.new()
	rm.albedo_color = roof_col
	rm.roughness = 0.8
	roof.material_override = rm
	root.add_child(roof)
	# Front (+Z) windows and door.
	var front := size.z * 0.5 + 0.02
	for x in [-size.x * 0.32, size.x * 0.32]:
		_box(root, Vector3(1.4, 1.2, 0.08), Vector3(x, 1.6, front), Color.WHITE, _glass_mat)
		_box(root, Vector3(1.6, 0.12, 0.14), Vector3(x, 0.95, front), Color.WHITE)
		if size.y > 4.5:
			_box(root, Vector3(1.4, 1.1, 0.08), Vector3(x, 3.9, front), Color.WHITE, _glass_mat)
	var door_x := -size.x * 0.05 if mirror else size.x * 0.05
	_box(root, Vector3(1.1, 2.2, 0.1), Vector3(door_x, 1.1, front), Color(0.45, 0.28, 0.2))
	# A path to the pavement and a tree in the garden.
	_box(root, Vector3(1.2, 0.03, 6.0), Vector3(door_x, 0.015, front + 3.0), Color(0.75, 0.73, 0.68))
	_tree(root.to_global(Vector3(size.x * 0.4 * (1 if mirror else -1), 0, front + 3.5)), 0.9)


func _box(parent: Node3D, s: Vector3, pos: Vector3, col: Color, shared: Material = null) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = s
	m.mesh = b
	m.position = pos
	if shared != null:
		m.material_override = shared
	else:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = col
		mat.roughness = 0.85
		m.material_override = mat
	parent.add_child(m)
