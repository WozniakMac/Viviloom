shader_type spatial;
render_mode cull_disabled;
uniform sampler2D eye_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 eye_color : source_color = vec4(0.25,0.17,0.1,1.0);
void fragment() {
    vec4 texel = texture(eye_texture, UV);
    vec3 source = texel.rgb;
    ALPHA = texel.a;
    ALPHA_SCISSOR_THRESHOLD = 0.2;
    float luminance = dot(source, vec3(0.2126,0.7152,0.0722));
    float saturation = max(source.r,max(source.g,source.b))-min(source.r,min(source.g,source.b));
    float iris = smoothstep(0.03,0.12,saturation)*(1.0-smoothstep(0.42,0.72,luminance));
    ALBEDO = mix(source,eye_color.rgb*mix(0.6,2.0,luminance),iris);
    ROUGHNESS = 0.23;
    SPECULAR = 0.5;
}
