@tool
extends Sprite2D

# ============================================================
# CHECKERBOARD COLORS
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
# INITIALIZATION
# ============================================================

func _ready() -> void:
	_update_shader()


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
		"light_color",
		light_color
	)

	shader_material.set_shader_parameter(
		"dark_color",
		dark_color
	)
