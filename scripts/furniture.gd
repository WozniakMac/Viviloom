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
## Extra places for more Sims at once (the other side of a double bed, more
## swimmers); everyone using the object, in slot order.
var extra_positions: Array[Vector3] = []
var users: Array = []


func capacity() -> int:
	return 1 + extra_positions.size()


func has_room_for(s: Node3D) -> bool:
	users = users.filter(func(u): return is_instance_valid(u))
	return users.has(s) or users.size() < capacity()


## Takes a place on the object; returns the local position for that place.
func claim(s: Node3D) -> Variant:
	if not users.has(s):
		users.append(s)
	user = s
	_update_covers.call_deferred()
	var slot := users.find(s)
	if slot == 0 or extra_positions.is_empty():
		return use_position
	return extra_positions[mini(slot - 1, extra_positions.size() - 1)]


func release(s: Node3D) -> void:
	users.erase(s)
	user = users[0] if not users.is_empty() else null
	_update_covers()


## Beds show their duvet over anyone lying in them.
func _update_covers() -> void:
	var covers := get_node_or_null("Covers") as Node3D
	if covers != null:
		covers.visible = not users.is_empty()
## Colour swatch (0 = the original colours).
var variant := 0
## Material name -> its own copy and original colour, for recolouring.
var _recolor := {}

## Swatches: the main material family -> colours for variants 1.. (0 is original).
const SWATCHES := {
	"fabric": [Color(0.85, 0.45, 0.5), Color(0.9, 0.72, 0.3), Color(0.5, 0.68, 0.45), Color(0.3, 0.3, 0.35), Color(0.55, 0.4, 0.7)],
	"wood": [Color(0.8, 0.66, 0.46), Color(0.32, 0.2, 0.12), Color(0.94, 0.93, 0.9), Color(0.16, 0.16, 0.18), Color(0.45, 0.62, 0.72)],
	"white": [Color(0.75, 0.82, 0.9), Color(0.95, 0.85, 0.6), Color(0.2, 0.2, 0.22), Color(0.72, 0.85, 0.7), Color(0.9, 0.6, 0.6)],
	"car": [Color(0.2, 0.4, 0.8), Color(0.95, 0.95, 0.95), Color(0.15, 0.15, 0.17), Color(0.95, 0.75, 0.2), Color(0.3, 0.6, 0.35)],
}
const MATERIAL_FAMILY := {
	"FabricBlue": "fabric", "FabricTeal": "fabric", "FabricGrey": "fabric",
	"Wood": "wood", "WoodLight": "wood", "Cabinet": "white", "White": "white", "CarBody": "car",
}
## Messes (dirty dishes, puddles) sit on a tile without blocking it.
var blocks := true
## Hangs on a wall: `cell` is the tile it faces and `rot_steps` which edge of
## that tile it hangs on (0 north, 1 west, 2 south, 3 east).
var wall_mounted := false
## Broken objects can only be repaired until fixed.
var broken := false
var _smoke: CPUParticles3D
## The interaction offered while broken.
static var repair_interaction: Interaction


func _ready() -> void:
	if is_in_group("lamps"):
		set_lit(Daylight.lit_now and not Daylight.power_off)


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
## Breaks or fixes the object; broken ones puff dark smoke.
func set_broken(b: bool) -> void:
	broken = b
	if b and _smoke == null:
		_smoke = CPUParticles3D.new()
		_smoke.amount = 14
		_smoke.lifetime = 1.6
		_smoke.position = Vector3(0, height, 0)
		_smoke.direction = Vector3.UP
		_smoke.spread = 20.0
		_smoke.initial_velocity_min = 0.3
		_smoke.initial_velocity_max = 0.6
		_smoke.gravity = Vector3(0, 0.2, 0)
		_smoke.scale_amount_min = 0.15
		_smoke.scale_amount_max = 0.35
		var puff := SphereMesh.new()
		puff.radius = 0.5
		puff.height = 1.0
		_smoke.mesh = puff
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.2, 0.2, 0.22, 0.55)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_smoke.material_override = m
		add_child(_smoke)
	if _smoke != null:
		_smoke.emitting = b
		_smoke.visible = b


## What can be done with the object right now (just Repair while broken).
func available_interactions() -> Array[Interaction]:
	if not broken:
		var on: bool = get_meta("on", false)
		return interactions.filter(func(i: Interaction): return not (i.needs_on and not on) and not (i.needs_off and on))
	if repair_interaction == null:
		repair_interaction = Interaction.new("Repair", {"fun": 4.0}, 60.0, "", "stand", true).practices("handiness", 80.0).grants("handy", "confident", 1, "Handy", "Fixed it all by themselves.", 180.0)
		repair_interaction.fixes = true
	var out: Array[Interaction] = [repair_interaction]
	return out


## Effects of finishing an interaction (switching the stereo on or off).
func apply_effect(e: String) -> void:
	match e:
		"stereo_on":
			set_meta("on", true)
			var player := get_node_or_null("Music") as AudioStreamPlayer3D
			if player == null:
				player = AudioStreamPlayer3D.new()
				player.name = "Music"
				player.position.y = 0.4
				player.unit_size = 5.0
				player.max_db = -4.0
				add_child(player)
			player.stream = Sfx.stream("music_build", true)
			player.play()
		"stereo_off":
			set_meta("on", false)
			var player := get_node_or_null("Music") as AudioStreamPlayer3D
			if player != null:
				player.stop()


## The swatch colours available for this object, or empty if it has none.
func swatch_colors() -> Array:
	_collect_recolor()
	for name in _recolor:
		return [_recolor[name][1]] + SWATCHES[MATERIAL_FAMILY[name]]
	return []


func _collect_recolor() -> void:
	if not _recolor.is_empty():
		return
	for c in find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i) as BaseMaterial3D
			if m == null or not MATERIAL_FAMILY.has(m.resource_name):
				continue
			if not _recolor.has(m.resource_name):
				var own := m.duplicate() as BaseMaterial3D
				_recolor[m.resource_name] = [own, m.albedo_color]
			mi.set_surface_override_material(i, _recolor[m.resource_name][0])
		break
	# Only the first (main) recolourable material family is changed.
	var first := ""
	for name in _recolor:
		if first == "":
			first = name
	for name in _recolor.keys():
		if MATERIAL_FAMILY[name] != MATERIAL_FAMILY[first]:
			_recolor.erase(name)


## Applies colour swatch `v` (0 restores the original colours).
func set_variant(v: int) -> void:
	_collect_recolor()
	if _recolor.is_empty():
		return
	variant = v
	for name in _recolor:
		var orig: Color = _recolor[name][1]
		var fam: Array = SWATCHES[MATERIAL_FAMILY[name]]
		var col: Color = orig if v <= 0 else fam[(v - 1) % fam.size()]
		(_recolor[name][0] as BaseMaterial3D).albedo_color = col


func set_ghost(ghost: bool) -> void:
	for c in find_children("*", "MeshInstance3D", true, false):
		(c as MeshInstance3D).transparency = 0.45 if ghost else 0.0
