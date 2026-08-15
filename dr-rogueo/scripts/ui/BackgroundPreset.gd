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
