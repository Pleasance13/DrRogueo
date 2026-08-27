shader_type canvas_item;

// Reveals the sprite from the BOTTOM upward.
//
// fill = 0.0 -> nothing visible
// fill = 1.0 -> fully visible
//
// Used by the OD gauge so the thermometer sprite fills up from
// its base as the overdose level rises.
uniform float fill : hint_range(0.0, 1.0) = 1.0;

void fragment() {

	vec4 tex = texture(TEXTURE, UV);

	// UV.y is 0 at the top of the sprite and 1 at the bottom.
	// Distance from the bottom is (1.0 - UV.y).
	float distance_from_bottom = 1.0 - UV.y;

	// HARD PIXEL CUT.
	// No smoothstep or derivative-based antialiasing, to match
	// the project's other pixel-art shaders.
	if (distance_from_bottom > fill) {

		COLOR = vec4(0.0);

	} else {

		COLOR = tex;
	}
}
