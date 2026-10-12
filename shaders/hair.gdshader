shader_type spatial;
render_mode cull_disabled, alpha_to_coverage;
uniform sampler2D hair_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 hair_color : source_color = vec4(0.25,0.16,0.1,1.0);
uniform sampler2D hair_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool has_normal = false;
uniform float alpha_threshold = 0.25;
void fragment() {
    vec4 strands = texture(hair_texture, UV);
    float detail = dot(strands.rgb, vec3(0.2126,0.7152,0.0722));
    // Compress dark source texture values so black hair atlases retain strand detail.
    float strand_tone = clamp(pow(max(detail, 0.0), 0.35) * 2.0, 0.0, 1.0);
    ALBEDO = hair_color.rgb * mix(0.45, 1.35, strand_tone);
    if (has_normal) {
        NORMAL_MAP = texture(hair_normal, UV).rgb;
        NORMAL_MAP_DEPTH = 0.45;
    }
    ALPHA = strands.a;
    ALPHA_SCISSOR_THRESHOLD = alpha_threshold;
    ALPHA_ANTIALIASING_EDGE = alpha_threshold - 0.1;
    ALPHA_TEXTURE_COORDINATE = UV * vec2(textureSize(hair_texture, 0));
    ROUGHNESS = 0.72;
    SPECULAR = 0.18;
}

