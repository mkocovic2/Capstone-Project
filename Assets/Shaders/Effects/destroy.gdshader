shader_type spatial;

// Use a NoiseTexture2D
uniform sampler2D noise_texture;
// Use a GradientTexture1D
uniform sampler2D burn_texture;
// Main texture for the object
uniform sampler2D albedo_texture : source_color;
// Change this value to dissolve the object
uniform float integrity: hint_range(0.0, 1.0) = 1.0;
// How large the burn is
uniform float burn_size: hint_range(1.0, 1.5) = 1.3;

// Inverse lerp function
// Converts the value v from the range [a, b] to the range [0, 1]
float inverse_lerp(float a, float b, float v) {
	return (v - a) / (b - a);
}

void fragment() {
	// Sample the noise texture
	// Remove the UV.y multiplication to dissolve uniformly across all sides
	float noise = texture(noise_texture, UV).r;

	// Sample the base color of the texture
	// The step function returns 1 when integrity > noise or 0 when integrity < noise
	vec4 base_color = texture(albedo_texture, UV) * step(noise, integrity);

	// Compute the UVs for the burn texture
	// Convert the range [integrity, integrity * burn_size] to a [0.0, 1.0] range
	vec2 burn_uv = vec2(inverse_lerp(integrity, integrity * burn_size, noise), 0.0);

	// Sample the burn texture using a higher edge in the step function
	vec4 burn_color = texture(burn_texture, burn_uv) * step(noise, integrity * burn_size);

	// Lerp between the end colors
	vec4 final_color = mix(burn_color, base_color, base_color.a);

	// Set spatial material properties
	ALBEDO = final_color.rgb;
	ALPHA = final_color.a;

	// Discard fully transparent fragments for better performance
	if (final_color.a < 0.01) {
		discard;
	}
}