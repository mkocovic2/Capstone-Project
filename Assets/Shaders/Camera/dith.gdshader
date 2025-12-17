shader_type spatial;
render_mode unshaded;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform vec4 level1 : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 level2 : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 level3 : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 level4 : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform float threshold1 : hint_range(0.0, 1.0) = 0.1;
uniform float threshold2 : hint_range(0.0, 1.0) = 0.4;
uniform float threshold3 : hint_range(0.0, 1.0) = 0.6;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 screen_color = texture(SCREEN_TEXTURE, uv).rgb;

	float rgb_avg = (screen_color.r + screen_color.g + screen_color.b) / 3.0;

	if (rgb_avg < threshold1) {
		ALBEDO = level1.rgb;
	} else if (rgb_avg < threshold2) {
		ALBEDO = level2.rgb;
	} else if (rgb_avg < threshold3) {
		ALBEDO = level3.rgb;
	} else {
		ALBEDO = level4.rgb;
	}
}