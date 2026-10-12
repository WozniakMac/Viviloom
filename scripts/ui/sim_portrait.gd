class_name SimPortrait
extends TextureRect
## A live, circular head-and-shoulders portrait of a Sim with a coloured ring. Its
## own camera sees only Sims (Sim.PORTRAIT_LAYER) against a soft blue background,
## and follows the face whether the Sim stands, sits or lies down.

var sim: Sim:
	set(v):
		sim = v
		_update_camera()
var ring_color := Color.WHITE:
	set(v):
		ring_color = v
		if _mat != null:
			_mat.set_shader_parameter("ring_color", v)

var _cam: Camera3D
var _mat: ShaderMaterial
static var _shader: Shader


func _init() -> void:
	# Update after the Sims have moved and animated this frame, or a walking Sim
	# slides out of frame.
	process_priority = 1000
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var vp := SubViewport.new()
	vp.size = Vector2i(256, 256)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_2X
	add_child(vp)
	_cam = Camera3D.new()
	_cam.fov = 30.0
	_cam.near = 0.05
	_cam.far = 30.0
	_cam.cull_mask = Sim.PORTRAIT_LAYER
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.78, 0.88, 0.97)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.88, 0.95)
	env.ambient_light_energy = 0.8
	_cam.environment = env
	vp.add_child(_cam)
	# A soft fill light travels with the camera so the face reads at night.
	var fill := OmniLight3D.new()
	fill.omni_range = 1.6
	fill.light_energy = 0.7
	fill.light_color = Color(1.0, 0.96, 0.9)
	_cam.add_child(fill)
	_cam.current = true
	texture = vp.get_texture()
	if _shader == null:
		_shader = Shader.new()
		_shader.code = """
shader_type canvas_item;
uniform vec4 ring_color : source_color = vec4(1.0);
void fragment() {
	float d = distance(UV, vec2(0.5));
	vec4 tex = texture(TEXTURE, UV);
	float inside = 1.0 - smoothstep(0.425, 0.435, d);
	float ring = smoothstep(0.425, 0.435, d) * (1.0 - smoothstep(0.49, 0.5, d));
	vec3 col = mix(tex.rgb, ring_color.rgb, ring);
	COLOR = vec4(col, max(inside, ring) * COLOR.a);
}
"""
	_mat = ShaderMaterial.new()
	_mat.shader = _shader
	_mat.set_shader_parameter("ring_color", ring_color)
	material = _mat


func _process(_delta: float) -> void:
	_update_camera()


func _update_camera() -> void:
	if sim == null or not is_instance_valid(sim) or not sim.is_inside_tree() or _cam == null or not _cam.is_inside_tree():
		return
	var body := sim.get_node_or_null("Body") as Node3D
	if body == null:
		return
	# Follow the body when lying or swimming, but not the small leans and sways of
	# walk styles, so the face stays centred.
	var upright := absf(body.rotation.x) < 0.5
	var basis := (sim.global_basis if upright else body.global_basis).orthonormalized()
	var head := body.to_global(Vector3(0, 1.62, 0))
	var skel := sim.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel != null and upright:
		var bi := skel.find_bone("head")
		if bi >= 0:
			# The real head (walk cycles bob and sway it), a little above the neck joint.
			head = skel.global_transform * skel.get_bone_global_pose(bi).origin + Vector3.UP * 0.1 * sim.size_scale()
	var face := basis * Vector3.FORWARD
	var up := basis * Vector3.UP
	var side := face.cross(up).normalized()
	var k := sim.size_scale()
	var eye := head + (face * 1.05 + side * 0.3 + up * 0.08) * k
	_cam.look_at_from_position(eye, head - up * 0.06 * k, up)
