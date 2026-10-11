shader_type spatial;

// Grass with a subtle one-metre tile grid, so the lot reads as a buildable grid.
uniform vec3 grass_color : source_color = vec3(0.36, 0.56, 0.26);
uniform float grid_strength : hint_range(0.0, 1.0) = 0.4;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world_pos.xz;
	vec2 g = abs(fract(uv) - 0.5);
	vec2 w = fwidth(uv) * 1.5;
	vec2 lines = smoothstep(vec2(0.5) - w, vec2(0.5), g);
	float line = max(lines.x, lines.y);
	float noise = hash(floor(uv * 2.0)) * 0.025 - 0.0125;
	vec3 col = grass_color + noise;
	ALBEDO = mix(col, col * 0.55, line * grid_strength);
	ROUGHNESS = 0.95;
}
