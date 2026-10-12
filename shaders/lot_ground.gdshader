shader_type spatial;

// Lawn like the reference game's: soft patches of lighter and darker green with
// a little yellow, fine blade grain and gently bumped normals so it catches the
// light. The one-metre build grid only shows in Build mode (grid_strength).
uniform vec3 grass_color : source_color = vec3(0.36, 0.56, 0.26);
uniform vec3 dry_color : source_color = vec3(0.55, 0.58, 0.28);
uniform vec3 deep_color : source_color = vec3(0.2, 0.4, 0.17);
uniform float grid_strength : hint_range(0.0, 1.0) = 0.0;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int k = 0; k < 4; k++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world_pos.xz;
	// Big soft patches, then a sprinkle of dry tips.
	float patches = fbm(uv * 0.18);
	vec3 col = mix(deep_color, grass_color, smoothstep(0.25, 0.7, patches));
	col = mix(col, dry_color, smoothstep(0.62, 0.85, fbm(uv * 0.35 + 7.3)) * 0.45);
	// Blade grain: fine streaks that fade out with distance to avoid shimmer.
	float fine = noise(uv * vec2(38.0, 9.0)) * 0.6 + noise(uv * 70.0) * 0.4;
	float far = clamp(length(fwidth(uv)) * 6.0, 0.0, 1.0);
	col *= mix(0.86 + 0.24 * fine, 1.0, far);
	// Build grid.
	vec2 g = abs(fract(uv) - 0.5);
	vec2 w = fwidth(uv) * 1.5;
	vec2 lines = smoothstep(vec2(0.5) - w, vec2(0.5), g);
	float line = max(lines.x, lines.y);
	ALBEDO = mix(col, col * 0.55, line * grid_strength);
	// Slightly bumpy normals from the grain.
	float nx = noise(uv * 24.0 + vec2(0.5, 0.0)) - noise(uv * 24.0 - vec2(0.5, 0.0));
	float nz = noise(uv * 24.0 + vec2(0.0, 0.5)) - noise(uv * 24.0 - vec2(0.0, 0.5));
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(nx, 0.0, nz, 0.0)).xyz * 0.35 * (1.0 - far));
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
