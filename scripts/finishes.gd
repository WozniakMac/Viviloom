class_name Finishes
extends RefCounted
## Wall paints/wallpapers and floor coverings for build mode. Patterns are drawn by
## shaders, so each finish is just a colour, a pattern number and a price.

## [name, colour, pattern, price per wall or tile]. Wall patterns: 0 paint,
## 1 striped wallpaper, 2 wainscot panelling, 3 brick.
const WALLS := [
	["Cream Paint", Color(0.92, 0.89, 0.82), 0, 0],
	["Sky Paint", Color(0.7, 0.82, 0.92), 0, 2],
	["Sage Paint", Color(0.7, 0.8, 0.66), 0, 2],
	["Blush Paint", Color(0.94, 0.78, 0.76), 0, 2],
	["Sunny Stripes", Color(0.96, 0.86, 0.55), 1, 5],
	["Mint Stripes", Color(0.66, 0.86, 0.78), 1, 5],
	["Navy Panelling", Color(0.3, 0.38, 0.55), 2, 8],
	["White Panelling", Color(0.95, 0.95, 0.93), 2, 8],
	["Red Brick", Color(0.66, 0.33, 0.24), 3, 10],
]
## Floor patterns: 0 plain, 1 wood planks, 2 square tiles, 3 carpet, 4 checker.
const FLOORS := [
	["Oak Planks", Color(0.62, 0.46, 0.3), 1, 4],
	["Pale Planks", Color(0.8, 0.68, 0.5), 1, 4],
	["Walnut Planks", Color(0.4, 0.27, 0.18), 1, 5],
	["White Tiles", Color(0.92, 0.92, 0.9), 2, 5],
	["Slate Tiles", Color(0.42, 0.45, 0.5), 2, 5],
	["Checker", Color(0.9, 0.9, 0.88), 4, 6],
	["Blue Carpet", Color(0.36, 0.5, 0.72), 3, 3],
	["Rose Carpet", Color(0.82, 0.55, 0.6), 3, 3],
	["Concrete", Color(0.66, 0.66, 0.64), 0, 1],
]
const WINDOW_PRICE := 90

static var _wall_shader: Shader
static var _floor_shader: Shader
static var _wall_mats := {}


static func wall_material(style: int) -> ShaderMaterial:
	style = clampi(style, 0, WALLS.size() - 1)
	if _wall_mats.has(style):
		return _wall_mats[style]
	if _wall_shader == null:
		_wall_shader = Shader.new()
		_wall_shader.code = """
shader_type spatial;
uniform vec3 base_color : source_color;
uniform int pattern = 0;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec3 c = base_color;
	float along = wp.x + wp.z;
	if (pattern == 1) {
		float s = step(0.5, fract(along * 4.0));
		c = mix(c, c * 0.88 + vec3(0.06), s);
	} else if (pattern == 2) {
		if (wp.y < 0.95) {
			c = c * 0.85;
			float groove = smoothstep(0.0, 0.02, abs(fract(along * 3.0) - 0.5) - 0.47);
			c *= 1.0 - groove * 0.25;
		}
		c *= 1.0 - smoothstep(0.93, 0.95, wp.y) * (1.0 - smoothstep(0.97, 0.99, wp.y)) * 0.3;
	} else if (pattern == 3) {
		float row = floor(wp.y / 0.12);
		float x = along / 0.25 + mod(row, 2.0) * 0.5;
		float mortar = max(step(0.9, fract(wp.y / 0.12)), step(0.94, fract(x)));
		float jitter = fract(sin(dot(vec2(floor(x), row), vec2(12.9898, 78.233))) * 43758.5453);
		c = mix(c * (0.88 + 0.2 * jitter), vec3(0.85, 0.82, 0.76), mortar);
	}
	// A darker skirting board along the bottom.
	c *= 1.0 - (1.0 - smoothstep(0.08, 0.1, wp.y)) * 0.35;
	ALBEDO = c;
	ROUGHNESS = 0.85;
}
"""
	var m := ShaderMaterial.new()
	m.shader = _wall_shader
	m.set_shader_parameter("base_color", WALLS[style][1])
	m.set_shader_parameter("pattern", WALLS[style][2])
	_wall_mats[style] = m
	return m


static func floor_material() -> ShaderMaterial:
	if _floor_shader == null:
		_floor_shader = Shader.new()
		_floor_shader.code = """
shader_type spatial;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	// Vertex colours arrive as sRGB.
	vec3 c = pow(COLOR.rgb, vec3(2.2));
	int pattern = int(COLOR.a * 8.0 + 0.5);
	vec2 p = wp.xz;
	float rough = 0.7;
	if (pattern == 1) {
		// Planks 0.2 m wide with staggered ends.
		float row = floor(p.y / 0.2);
		float x = p.x / 1.2 + hash(vec2(row, 1.0));
		float plank = floor(x);
		c *= 0.86 + 0.22 * hash(vec2(plank, row));
		c *= 0.94 + 0.06 * sin(p.x * 40.0 + hash(vec2(row, plank)) * 20.0);
		float seam = max(step(0.96, fract(p.y / 0.2)), step(0.985, fract(x)));
		c *= 1.0 - seam * 0.35;
		rough = 0.45;
	} else if (pattern == 2 || pattern == 4) {
		vec2 t = p / 0.5;
		float grout = max(step(0.95, fract(t.x)), step(0.95, fract(t.y)));
		if (pattern == 4 && mod(floor(t.x) + floor(t.y), 2.0) > 0.5) c = vec3(0.12, 0.12, 0.14);
		c = mix(c, vec3(0.75, 0.74, 0.7), grout);
		rough = 0.25;
	} else if (pattern == 3) {
		c *= 0.92 + 0.12 * hash(floor(p * 60.0));
		rough = 1.0;
	}
	ALBEDO = c;
	ROUGHNESS = rough;
}
"""
	var m := ShaderMaterial.new()
	m.shader = _floor_shader
	return m


static func wall_name(style: int) -> String:
	return WALLS[style][0]


static func floor_name(style: int) -> String:
	return FLOORS[style][0]
