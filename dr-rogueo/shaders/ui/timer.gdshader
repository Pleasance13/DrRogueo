shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 1.0;

void fragment() {

	vec4 tex = texture(TEXTURE, UV);

	vec2 center = vec2(0.5, 0.5);
	vec2 offset = UV - center;

	float angle = atan(-offset.y, offset.x);

	float normalized_angle = (angle + PI) / (2.0 * PI);

	normalized_angle = fract(
		normalized_angle + 0.25
	);

	// HARD PIXEL CUT.
	// No smoothstep or derivative-based antialiasing.
	if (normalized_angle > progress) {

		COLOR = vec4(0.0);

	} else {

		COLOR = tex;
	}
}