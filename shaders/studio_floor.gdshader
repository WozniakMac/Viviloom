shader_type spatial;
render_mode blend_mix, specular_disabled;
uniform vec4 floor_color : source_color = vec4(0.36,0.55,0.66,1.0);
varying vec2 floor_position;
void vertex() { floor_position = VERTEX.xz; }
void fragment() {
    ALBEDO = floor_color.rgb;
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
    // Local ground keeps contact shadows; the far floor blends into the backdrop.
    ALPHA = (1.0-smoothstep(0.7,2.8,length(floor_position))) * 0.7;
}
