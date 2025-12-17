shader_type spatial;

render_mode unshaded, cull_disabled, depth_draw_always, skip_vertex_transform;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float threshold_shadow : hint_range(0.0, 1.0) = 0.33;
uniform float threshold_mid : hint_range(0.0, 1.0) = 0.66;

uniform vec3 color_shadow : source_color = vec3(0.0, 0.0, 0.0);
uniform vec3 color_mid : source_color = vec3(0.5, 0.5, 0.5);
uniform vec3 color_light : source_color = vec3(1.0, 1.0, 1.0);

uniform float posterize_levels : hint_range(1.0, 10.0) = 2.0;
uniform bool enable_posterize = true;

vec3 posterize(vec3 color, float levels) {
    return floor(color * levels) / levels;
}

void vertex() {
    VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec2 screen_uv = SCREEN_UV;
    vec4 screen_col = texture(SCREEN_TEXTURE, screen_uv);

    float brightness = dot(screen_col.rgb, vec3(0.299, 0.587, 0.114));
    vec3 tone_color;

    if (brightness < threshold_shadow) {
        tone_color = color_shadow;
    } else if (brightness < threshold_mid) {
        tone_color = color_mid;
    } else {
        tone_color = color_light;
    }

    vec3 posterized = enable_posterize ? posterize(screen_col.rgb, posterize_levels) : screen_col.rgb;
    vec3 final_color = mix(posterized, tone_color, 0.6);

    ALBEDO = final_color;
}
