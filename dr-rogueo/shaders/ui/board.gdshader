shader_type canvas_item;

// ============================================================
// CHECKERBOARD COLORS
// ============================================================

uniform vec4 light_color : source_color = vec4(1.0);
uniform vec4 dark_color : source_color = vec4(0.0);

// ============================================================
// FRAGMENT
// ============================================================

void fragment() {

	// --------------------------------------------------------
	// Original UV
	// --------------------------------------------------------

	vec2 original_uv = UV;

	vec2 texture_size = vec2(textureSize(TEXTURE, 0));

	// Pixel coordinate before any warping.
	vec2 source_pixel = floor(
		original_uv * texture_size
	);

	vec2 uv = original_uv;

	// --------------------------------------------------------
	// Sample texture
	// --------------------------------------------------------

	vec4 source = texture(TEXTURE, uv);

	// --------------------------------------------------------
	// Only replace PURE black and PURE white.
	// Everything else remains untouched.
	// --------------------------------------------------------

	if (source.rgb == vec3(0.0)) {
		COLOR = vec4(dark_color.rgb, source.a);
	}
	else if (source.rgb == vec3(1.0)) {
		COLOR = vec4(light_color.rgb, source.a);
	}
	else {
		COLOR = source;
	}
}