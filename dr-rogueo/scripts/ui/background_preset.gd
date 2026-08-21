@tool
class_name BackgroundPreset
extends Resource


# ============================================================
# PRESET
# ============================================================

@export_category("Preset")

@export
var preset_name: String = "New Preset"


# ============================================================
# CATEGORY / POOL
# ============================================================
#
# Determines which random-pick pool this preset belongs to.
#
# Background.apply_random_preset(category) filters color_presets
# down to only entries matching the requested category before
# picking randomly.
# ============================================================

enum Category {
	NORMAL,
	BOSS,
	STORE
}

@export
var category: Category = Category.NORMAL


# ============================================================
# CHECKERBOARD COLORS
# ============================================================

@export_category("Checkerboard")

@export
var light_color: Color = Color("#F8F8F8")

@export
var dark_color: Color = Color("#7C7C7C")


# ============================================================
# SHADOW
# ============================================================

@export_category("Shadow")

@export
var shadow_color: Color = Color.BLACK


# ============================================================
# WAVE
# ============================================================

@export_category("Wave")

@export_range(0.25, 8.0, 0.05)
var wave_width: float = 3.0

@export_range(0.0, 0.1, 0.001)
var wave_depth: float = 0.025

@export_range(0.0, 2.0, 0.01)
var wave_speed: float = 0.25


# ============================================================
# SHADING
# ============================================================

@export_category("Shading")

@export_range(-1.0, 1.0, 0.01)
var shade_brightness: float = 0.0

@export_range(0.0, 3.0, 0.01)
var shade_contrast: float = 1.0

@export_range(0.0, 1.0, 0.01)
var shade_strength: float = 0.45


# ============================================================
# DITHERING
# ============================================================

@export_category("Dithering")

@export
var dither_type: Background.DitherType = Background.DitherType.BAYER_4X4

@export_range(1, 8, 1)
var dither_scale: float = 1.0
