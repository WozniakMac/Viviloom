shader_type spatial;
render_mode cull_disabled;
uniform sampler2D fabric_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D fabric_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool has_normal = false;
uniform vec4 fabric_color : source_color = vec4(1.0);
void fragment() {
    vec4 source = texture(fabric_texture, UV);
    float blue = smoothstep(0.02, 0.13, source.b-source.r) * smoothstep(-0.03, 0.08, source.b-source.g);
    float luminance = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
    ALBEDO = mix(source.rgb, fabric_color.rgb * clamp(luminance / 0.25, 0.3, 1.8), blue);
    ROUGHNESS = 0.85;
    if (has_normal) NORMAL_MAP = texture(fabric_normal, UV).rgb;
}

