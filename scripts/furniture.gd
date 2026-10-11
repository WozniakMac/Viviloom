class_name Furniture
extends Node3D
## A placeable object occupying a rectangle of tiles. Local +Z is the object's front.
## The node origin sits at the centre of its footprint.

var kind: String
var display_name: String
## Footprint in tiles before rotation (x = width, y = depth).
var footprint := Vector2i.ONE
## Quarter turns counter-clockwise seen from above.
var rot_steps := 0
## Top-left tile of the (rotated) footprint on the lot.
var cell := Vector2i.ZERO
var height := 1.0
var price := 0
var interactions: Array[Interaction] = []
## Local positions where a Sim stands to start using the object.
var spots: Array[Vector3] = []
## Optional local position the Sim moves onto while using it (bed, toilet, chair).
var use_position: Variant = null
## Local direction the Sim faces while at `use_position`.
var use_facing := Vector3(0, 0, 1)
var user: Node3D = null


func _ready() -> void:
	if is_in_group("lamps"):
		set_lit(Daylight.lit_now)


## For lamps: turns the light and the glowing shade on or off.
func set_lit(on: bool) -> void:
	var glow := get_node_or_null("Glow") as OmniLight3D
	if glow != null:
		glow.visible = on
	var shade := get_node_or_null("Shade") as MeshInstance3D
	if shade != null:
		var mat := shade.material_override as StandardMaterial3D
		mat.emission_enabled = on
		mat.emission = Color(1.0, 0.8, 0.5)
		mat.emission_energy_multiplier = 1.4


func rotated_footprint() -> Vector2i:
	return footprint if rot_steps % 2 == 0 else Vector2i(footprint.y, footprint.x)


func footprint_rect() -> Rect2i:
	return Rect2i(cell, rotated_footprint())


func world_spots() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for s in spots:
		out.append(to_global(s))
	return out


func add_box(size: Vector3, center: Vector3, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	m.mesh = box
	m.position = center
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.7
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material_override = mat
	add_child(m)
	return m


## Adds a click target covering the footprint, so the object can be picked with a ray.
func build_collider() -> void:
	var body := StaticBody3D.new()
	body.set_meta("furniture", self)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(footprint.x - 0.1, height, footprint.y - 0.1)
	shape.shape = box
	shape.position = Vector3(0, height * 0.5, 0)
	body.add_child(shape)
	add_child(body)


## See-through look while the object is being placed or moved.
func set_ghost(ghost: bool) -> void:
	for c in find_children("*", "MeshInstance3D", true, false):
		(c as MeshInstance3D).transparency = 0.45 if ghost else 0.0
