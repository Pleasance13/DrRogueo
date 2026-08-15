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
# BACKGROUND LINK
# ============================================================

@export_category("Background Link")

@export var background: Background


# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:

	_update_shader()

	if Engine.is_editor_hint():
		return

	call_deferred("_connect_to_background")


func _connect_to_background() -> void:

	var found_background := (
		get_tree().get_first_node_in_group("palette_source")
		as Background
	)

	if found_background == null:
		push_warning("BoardFrame: No background found in scene tree.")
		return

	found_background.palette_changed.connect(_on_palette_changed)

	_on_palette_changed(
		found_background.light_color,
		found_background.dark_color,
		found_background.shadow_color
	)


func _on_palette_changed(
	new_light_color: Color,
	_new_dark_color: Color,
	_new_shadow_color: Color
) -> void:

	light_color = new_light_color


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
