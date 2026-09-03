@tool
class_name Background
extends Node2D


# ============================================================
# CHECKERBOARD
# ============================================================

@export_group("Checkerboard")

@export var checkerboard_path: NodePath = NodePath("Checkerboard")


# ============================================================
# WAVE
# ============================================================

@export_group("Wave")

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

@export_group("Color Mode")

@export
var use_color_presets: bool = true


# ============================================================
# COLOR PRESETS
# ============================================================

@export_group("Color Presets")

@export
var color_presets: Array[BackgroundPreset] = []


# ============================================================
# SHADOW COLOR
# ============================================================

@export_group("Shadow")

@export
var shadow_color: Color = Color.BLACK:
	set(value):
		shadow_color = value
		_update_shader()


# ============================================================
# RUNTIME PRESET
# ============================================================

@export_group("Runtime")

@export
var runtime_preset_category: BackgroundPreset.Category = (
	BackgroundPreset.Category.NORMAL
)


# ============================================================
# RUNTIME PRESET STATE
# ============================================================

var _runtime_preset_index: int = -1
var _runtime_initialized: bool = false


# ============================================================
# SHADER TIME
# ============================================================

var _shader_time: float = 0.0


# ============================================================
# SHADING
# ============================================================

@export_group("Shading")

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

@export_group("Dithering")

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
	# Editor only displays the currently previewed colors.
	# --------------------------------------------------------

	if Engine.is_editor_hint():
		return


	add_to_group("palette_source")


	# --------------------------------------------------------
	# Runtime initialization is deferred until the complete
	# scene tree has finished entering the scene.
	# --------------------------------------------------------

	call_deferred(
		"_initialize_runtime"
	)


# ============================================================
# PROCESS
# ============================================================

func _process(delta: float) -> void:

	if Engine.is_editor_hint():
		return


	# --------------------------------------------------------
	# Advance our own shader clock.
	#
	# This node uses the normal PAUSABLE process mode, so
	# this automatically stops when the SceneTree is paused.
	# --------------------------------------------------------

	_shader_time += delta

	_update_shader_time()


# ============================================================
# GET CHECKERBOARD
# ============================================================

func _get_checkerboard() -> Sprite2D:

	var checkerboard := get_node_or_null(
		checkerboard_path
	) as Sprite2D

	if checkerboard == null:

		push_warning(
			"Background: Could not find Checkerboard Sprite2D at: "
			+ str(checkerboard_path)
		)

	return checkerboard


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

		_runtime_preset_index = -1

		apply_random_preset(
			runtime_preset_category
		)

		return


	# --------------------------------------------------------
	# Manual mode.
	# --------------------------------------------------------

	_update_shader()


# ============================================================
# RANDOM PRESET
# ============================================================

func apply_random_preset(
	category: BackgroundPreset.Category = BackgroundPreset.Category.NORMAL
) -> void:

	if not use_color_presets:
		return


	var valid_indices: Array[int] = []


	# --------------------------------------------------------
	# Find presets belonging to the requested pool.
	# --------------------------------------------------------

	for i in range(color_presets.size()):

		var preset := color_presets[i]

		if preset != null and preset.category == category:

			valid_indices.append(i)


	if valid_indices.is_empty():

		push_warning(
			"Background: No presets found for category: "
			+ str(category)
		)

		return


	# --------------------------------------------------------
	# Only one preset in this pool.
	# --------------------------------------------------------

	if valid_indices.size() == 1:

		var only_index: int = valid_indices[0]

		_runtime_preset_index = only_index

		apply_preset(
			color_presets[only_index]
		)

		return


	# --------------------------------------------------------
	# Exclude previous runtime preset.
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
	# Choose new preset.
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

func preview_preset(
	preset_index: int
) -> void:

	if preset_index < 0:
		return

	if preset_index >= color_presets.size():
		return


	var preset := color_presets[preset_index]

	if preset == null:
		return


	apply_preset(preset)


# ============================================================
# APPLY PRESET
# ============================================================

signal palette_changed(
	light_color: Color,
	dark_color: Color,
	shadow_color: Color
)


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


	palette_changed.emit(
		light_color,
		dark_color,
		shadow_color
	)


# ============================================================
# GET PRESET COLOR
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
# UPDATE SHADER TIME
# ============================================================

func _update_shader_time() -> void:

	var checkerboard := _get_checkerboard()

	if checkerboard == null:
		return


	var material := checkerboard.material

	if not material:
		return

	if not material is ShaderMaterial:
		return


	var shader_material := material as ShaderMaterial


	shader_material.set_shader_parameter(
		"shader_time",
		_shader_time
	)


# ============================================================
# UPDATE SHADER
# ============================================================

func _update_shader() -> void:

	var checkerboard := _get_checkerboard()

	if checkerboard == null:
		return


	var material := checkerboard.material

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
		"shader_time",
		_shader_time
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
