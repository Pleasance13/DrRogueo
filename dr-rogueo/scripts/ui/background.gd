@tool
class_name Background
extends Sprite2D


# ============================================================
# WAVE
# ============================================================

@export_category("Wave")

@export_range(0.25, 8.0, 0.05)
var wave_width: float = 3.0:
	set(value):
		wave_width = value
		_update_shader()


@export_range(0.0, 0.1, 0.001)
var wave_depth: float = 0.025:
	set(value):
		wave_depth = value
		_update_shader()


@export_range(0.0, 2.0, 0.01)
var wave_speed: float = 0.25:
	set(value):
		wave_speed = value
		_update_shader()


# ============================================================
# CHECKERBOARD COLORS
# ============================================================
#
# These are the MANUAL colors.
#
# They are also used by the editor when previewing presets.
#
# IMPORTANT:
#
# In preset mode, these values are NOT considered the runtime
# source of truth.
# ============================================================

@export_category("Checkerboard")

@export
var light_color: Color = Color("#F8F8F8"):
	set(value):
		light_color = value
		_update_shader()


@export
var dark_color: Color = Color("#7C7C7C"):
	set(value):
		dark_color = value
		_update_shader()


# ============================================================
# COLOR MODE
# ============================================================

@export_category("Color Mode")

@export
var use_color_presets: bool = true


# ============================================================
# COLOR PRESETS
# ============================================================

@export_category("Color Presets")

@export
var color_presets: Array[BackgroundPreset] = []


# ============================================================
# SHADOW COLOR
# ============================================================

@export_category("Shadow")

@export
var shadow_color: Color = Color.BLACK:
	set(value):
		shadow_color = value
		_update_shader()


# ============================================================
# RUNTIME PRESET STATE
# ============================================================
#
# NONE of these variables are exported.
#
# Therefore:
#
# - Inspector preview cannot save them.
# - Saving the scene cannot change them.
# - Restarting the game starts with a fresh runtime state.
# ============================================================

var _runtime_preset_index: int = -1

var _runtime_initialized: bool = false


# ============================================================
# SHADING
# ============================================================

@export_category("Shading")

@export_range(-1.0, 1.0, 0.01)
var shade_brightness: float = 0.0:
	set(value):
		shade_brightness = value
		_update_shader()


@export_range(0.0, 3.0, 0.01)
var shade_contrast: float = 1.0:
	set(value):
		shade_contrast = value
		_update_shader()


@export_range(0.0, 1.0, 0.01)
var shade_strength: float = 0.45:
	set(value):
		shade_strength = value
		_update_shader()


# ============================================================
# DITHERING
# ============================================================

@export_category("Dithering")

enum DitherType {
	NONE,
	BAYER_2X2,
	BAYER_4X4,
	CHECKER
}


@export
var dither_type: DitherType = DitherType.BAYER_4X4:
	set(value):
		dither_type = value
		_update_shader()


@export_range(1, 8, 1)
var dither_scale: float = 1.0:
	set(value):
		dither_scale = value
		_update_shader()


# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	_update_shader()

	# --------------------------------------------------------
	# The editor should ONLY display the currently previewed
	# colors.
	# --------------------------------------------------------
	if Engine.is_editor_hint():
		return

	add_to_group("palette_source")

	# --------------------------------------------------------
	# Runtime initialization is deferred until the complete
	# scene tree has finished entering the scene.
	#
	# This prevents the serialized editor-preview colors from
	# being mistaken for the game's starting palette.
	# --------------------------------------------------------
	call_deferred(
		"_initialize_runtime"
	)


# ============================================================
# RUNTIME INITIALIZATION
# ============================================================

func _initialize_runtime() -> void:

	if Engine.is_editor_hint():
		return


	if _runtime_initialized:
		return


	_runtime_initialized = true


	# --------------------------------------------------------
	# Preset mode.
	# --------------------------------------------------------

	if use_color_presets:

		# Completely discard the editor preview state as the
		# runtime selection.
		_runtime_preset_index = -1

		apply_random_preset()

		return


	# --------------------------------------------------------
	# Manual mode.
	#
	# The serialized colors ARE the desired colors here.
	# --------------------------------------------------------

	_update_shader()


# ============================================================
# RANDOM PRESET
# ============================================================
#
# Picks a random preset.
#
# The previous RUNTIME preset is excluded.
#
# Editor previews have absolutely no effect on this.
# ============================================================


func apply_random_preset(
	category: BackgroundPreset.Category = BackgroundPreset.Category.NORMAL
) -> void:

	if not use_color_presets:
		return


	var valid_indices: Array[int] = []


	# --------------------------------------------------------
	# Find all valid preset entries matching the requested pool.
	# --------------------------------------------------------

	for i in range(color_presets.size()):

		var preset := color_presets[i]

		if preset != null and preset.category == category:
			valid_indices.append(i)


	if valid_indices.is_empty():
		return


	# --------------------------------------------------------
	# One preset.
	# --------------------------------------------------------

	if valid_indices.size() == 1:

		var only_index: int = valid_indices[0]

		_runtime_preset_index = only_index

		apply_preset(
			color_presets[only_index]
		)

		return


	# --------------------------------------------------------
	# Build a list excluding the previous RUNTIME preset.
	# --------------------------------------------------------

	var available_indices: Array[int] = []


	for index in valid_indices:

		if index != _runtime_preset_index:
			available_indices.append(index)


	# --------------------------------------------------------
	# Safety fallback.
	# --------------------------------------------------------

	if available_indices.is_empty():

		available_indices = valid_indices.duplicate()


	# --------------------------------------------------------
	# Choose the new runtime preset.
	# --------------------------------------------------------

	var new_index: int = available_indices[
		randi_range(
			0,
			available_indices.size() - 1
		)
	]


	_runtime_preset_index = new_index


	apply_preset(
		color_presets[new_index]
	)


# ============================================================
# PREVIEW PRESET
# ============================================================
#
# Called by the inspector Load button.
#
# IMPORTANT:
#
# This does NOT touch _runtime_preset_index.
#
# Therefore:
#
#     Preview purple in editor
#
# does NOT mean:
#
#     Game thinks purple was last used.
# ============================================================

func preview_preset(
	preset_index: int
) -> void:

	# --------------------------------------------------------
	# Editor-only operation.
	# --------------------------------------------------------

	if preset_index < 0:
		return


	if preset_index >= color_presets.size():
		return


	var preset := color_presets[preset_index]


	if preset == null:
		return


	# --------------------------------------------------------
	# Apply ONLY as an editor preview.
	#
	# Do not update _runtime_preset_index.
	# --------------------------------------------------------

	apply_preset(preset)


# ============================================================
# APPLY PRESET
# ============================================================
#
# Generic preset application.
#
# Used for editor previewing.
# ============================================================

signal palette_changed(light_color: Color, dark_color: Color, shadow_color: Color)

func apply_preset(preset: BackgroundPreset) -> void:
	if preset == null:
		return

	light_color = preset.light_color
	dark_color = preset.dark_color
	shadow_color = preset.shadow_color

	wave_width = preset.wave_width
	wave_depth = preset.wave_depth
	wave_speed = preset.wave_speed

	shade_brightness = preset.shade_brightness
	shade_contrast = preset.shade_contrast
	shade_strength = preset.shade_strength

	dither_type = preset.dither_type
	dither_scale = preset.dither_scale

	_update_shader()

	palette_changed.emit(light_color, dark_color, shadow_color)


# ============================================================
# GET PRESET COLOR
# ============================================================
#
# Useful to the inspector for displaying the three palette
# swatches beside each Load button.
# ============================================================

func get_preset_color(
	preset: BackgroundPreset,
	color_index: int
) -> Color:

	if preset == null:
		return Color.WHITE


	match color_index:

		0:
			return preset.light_color

		1:
			return preset.dark_color

		2:
			return preset.shadow_color


	return Color.WHITE


# ============================================================
# GET CURRENT RUNTIME PRESET INDEX
# ============================================================

func get_runtime_preset_index() -> int:

	return _runtime_preset_index


# ============================================================
# UPDATE SHADER
# ============================================================

func _update_shader() -> void:

	if not material:
		return


	if not material is ShaderMaterial:
		return


	var shader_material := material as ShaderMaterial


	shader_material.set_shader_parameter(
		"wave_width",
		wave_width
	)


	shader_material.set_shader_parameter(
		"wave_depth",
		wave_depth
	)


	shader_material.set_shader_parameter(
		"wave_speed",
		wave_speed
	)


	shader_material.set_shader_parameter(
		"light_color",
		light_color
	)


	shader_material.set_shader_parameter(
		"dark_color",
		dark_color
	)


	shader_material.set_shader_parameter(
		"shade_brightness",
		shade_brightness
	)


	shader_material.set_shader_parameter(
		"shade_contrast",
		shade_contrast
	)


	shader_material.set_shader_parameter(
		"shade_strength",
		shade_strength
	)


	shader_material.set_shader_parameter(
		"shadow_color",
		shadow_color
	)


	shader_material.set_shader_parameter(
		"dither_type",
		int(dither_type)
	)


	shader_material.set_shader_parameter(
		"dither_scale",
		dither_scale
	)
