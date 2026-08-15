shader_type canvas_item;


// ============================================================
// WAVE
// ============================================================

uniform float wave_width = 3.0;
uniform float wave_depth = 0.025;
uniform float wave_speed = 0.25;


// ============================================================
// CHECKERBOARD COLORS
// ============================================================

uniform vec4 light_color : source_color = vec4(1.0);
uniform vec4 dark_color : source_color = vec4(0.0);


// ============================================================
// SHADING
// ============================================================

uniform float shade_brightness = 0.0;
uniform float shade_contrast = 1.0;
uniform float shade_strength = 0.45;

uniform vec4 shadow_color : source_color = vec4(0.0);


// ============================================================
// DITHERING
// ============================================================

uniform int dither_type = 2;
uniform float dither_scale = 1.0;


// ============================================================
// NOISE
// ============================================================

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}


float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);

	f = f * f * (3.0 - 2.0 * f);

	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	return mix(
		mix(a, b, f.x),
		mix(c, d, f.x),
		f.y
	);
}


// ============================================================
// DITHER PATTERNS
// ============================================================

float bayer2(vec2 p) {
	int x = int(mod(p.x, 2.0));
	int y = int(mod(p.y, 2.0));

	int index = x + y * 2;

	if (index == 0) return 0.0 / 4.0;
	if (index == 1) return 2.0 / 4.0;
	if (index == 2) return 3.0 / 4.0;

	return 1.0 / 4.0;
}


float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));

	int index = x + y * 4;

	if (index == 0)  return 0.0 / 16.0;
	if (index == 1)  return 8.0 / 16.0;
	if (index == 2)  return 2.0 / 16.0;
	if (index == 3)  return 10.0 / 16.0;

	if (index == 4)  return 12.0 / 16.0;
	if (index == 5)  return 4.0 / 16.0;
	if (index == 6)  return 14.0 / 16.0;
	if (index == 7)  return 6.0 / 16.0;

	if (index == 8)  return 3.0 / 16.0;
	if (index == 9)  return 11.0 / 16.0;
	if (index == 10) return 1.0 / 16.0;
	if (index == 11) return 9.0 / 16.0;

	if (index == 12) return 15.0 / 16.0;
	if (index == 13) return 7.0 / 16.0;
	if (index == 14) return 13.0 / 16.0;

	return 5.0 / 16.0;
}


float checker_dither(vec2 p) {
	int x = int(mod(p.x, 2.0));
	int y = int(mod(p.y, 2.0));

	return ((x + y) % 2 == 0) ? 0.0 : 1.0;
}


float get_dither(vec2 pixel_pos) {

	pixel_pos = floor(pixel_pos / dither_scale);

	if (dither_type == 0) {
		return 1.0;
	}

	if (dither_type == 1) {
		return bayer2(pixel_pos);
	}

	if (dither_type == 2) {
		return bayer4(pixel_pos);
	}

	return checker_dither(pixel_pos);
}


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


	// --------------------------------------------------------
	// Wave noise
	// --------------------------------------------------------

	vec2 uv = original_uv;

	float t = TIME * wave_speed;

	// Higher width = wider waves.
	float noise_frequency = 12.0 / wave_width;

	float nx = noise(
		uv * noise_frequency +
		vec2(t, 0.0)
	);

	float ny = noise(
		uv * noise_frequency +
		vec2(0.0, t)
	);

	nx = nx * 2.0 - 1.0;
	ny = ny * 2.0 - 1.0;


	// --------------------------------------------------------
	// Warp texture
	// --------------------------------------------------------

	uv.x += nx * wave_depth;
	uv.y += ny * wave_depth;

	uv = clamp(uv, vec2(0.0), vec2(1.0));


	// --------------------------------------------------------
	// Convert B/W texture into chosen colors
	// --------------------------------------------------------

	vec4 source = texture(TEXTURE, uv);

	// The source texture is assumed to be pure black/white.
	// Using luminance lets either black or white represent
	// the two checkerboard states.
	float mask = dot(
		source.rgb,
		vec3(0.299, 0.587, 0.114)
	);

	vec4 tex = mix(
		dark_color,
		light_color,
		step(0.5, mask)
	);


	// --------------------------------------------------------
	// Deformation shading
	// --------------------------------------------------------

	float deformation = (nx + ny) * 0.5;

	float shade = deformation * 0.5 + 0.5;

	shade = (shade - 0.5) * shade_contrast + 0.5;

	shade += shade_brightness;

	shade = clamp(shade, 0.0, 1.0);

	float darkness = (1.0 - shade) * shade_strength;


	// --------------------------------------------------------
	// Uniform dither
	// --------------------------------------------------------

	float threshold = get_dither(source_pixel);

	if (threshold < darkness) {
		tex.rgb = mix(
			tex.rgb,
			shadow_color.rgb,
			shadow_color.a
		);
	}


	COLOR = tex;
}