shader_type spatial;
render_mode cull_disabled, alpha_to_coverage;
uniform sampler2D hair_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 hair_color : source_color = vec4(0.25,0.16,0.1,1.0);
uniform sampler2D hair_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool has_normal = false;
uniform sampler2D hair_detail_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool has_detail = false;
uniform float alpha_threshold = 0.25;
uniform float detail_strength = 0.40;
uniform float normal_depth = 0.30;
uniform float roughness = 0.64;
uniform float specular = 0.24;
uniform float anisotropy = 0.25;
void fragment() {
    vec4 strands = texture(hair_texture, UV);
    float detail = dot(strands.rgb, vec3(0.2126,0.7152,0.0722));
    // Compress dark source texture values so black hair atlases retain strand detail.
    float strand_tone = clamp(pow(max(detail, 0.0), 0.35) * 2.0, 0.0, 1.0);
    float tone = mix(0.45, 1.35, strand_tone);
    if (has_detail) {
        vec4 clumps = texture(hair_detail_texture, UV);
        float clump_luma = dot(clumps.rgb, vec3(0.2126,0.7152,0.0722));
        float clump_tone = clamp(sqrt(max(clump_luma,0.001) / 0.16),0.45,1.6);
        // AI color is supplemental. Original atlas alone controls the cutout.
        tone = mix(tone,clump_tone,smoothstep(0.25,0.9,clumps.a) * detail_strength);
    }
    ALBEDO = hair_color.rgb * tone;
    if (has_normal) {
        NORMAL_MAP = texture(hair_normal, UV).rgb;
        NORMAL_MAP_DEPTH = normal_depth;
    }
    ALPHA = strands.a;
    ALPHA_SCISSOR_THRESHOLD = alpha_threshold;
    ALPHA_ANTIALIASING_EDGE = alpha_threshold - 0.1;
    ALPHA_TEXTURE_COORDINATE = UV * vec2(textureSize(hair_texture, 0));
    ROUGHNESS = roughness;
    SPECULAR = specular;
    ANISOTROPY = anisotropy;
    ANISOTROPY_FLOW = vec2(0.0,1.0);
}

