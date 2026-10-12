shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
uniform sampler2D hair_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 hair_color : source_color = vec4(0.25,0.16,0.1,1.0);
void fragment() {
    vec4 strands = texture(hair_texture, UV);
    ALBEDO = hair_color.rgb * 0.8;
    ALPHA = strands.a;
    ROUGHNESS = 0.95;
    SPECULAR = 0.0;
}
