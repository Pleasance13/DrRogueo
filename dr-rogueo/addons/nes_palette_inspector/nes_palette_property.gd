@tool
extends EditorProperty


const COLUMNS := 14
const SWATCH_SIZE := Vector2(16, 16)


var palette_grid: GridContainer
var buttons: Array[Button] = []

var updating := false


func _init() -> void:

	palette_grid = GridContainer.new()

	palette_grid.columns = COLUMNS

	palette_grid.add_theme_constant_override(
		"h_separation",
		1
	)

	palette_grid.add_theme_constant_override(
		"v_separation",
		1
	)


	add_child(palette_grid)


	for i in range(NESPalette.COLORS.size()):

		var color: Color = NESPalette.COLORS[i]


		var button := Button.new()

		button.custom_minimum_size = SWATCH_SIZE

		button.focus_mode = Control.FOCUS_NONE

		button.flat = false

		button.text = ""

		button.tooltip_text = (
			color.to_html(false).to_upper()
		)


		button.add_theme_stylebox_override(
			"normal",
			_make_style(
				color,
				1,
				Color(0.2, 0.2, 0.2)
			)
		)


		button.add_theme_stylebox_override(
			"hover",
			_make_style(
				color.lightened(0.15),
				2,
				Color.WHITE
			)
		)


		button.add_theme_stylebox_override(
			"pressed",
			_make_style(
				color,
				2,
				Color.WHITE
			)
		)


		button.add_theme_stylebox_override(
			"focus",
			_make_style(
				color,
				2,
				Color.WHITE
			)
		)


		button.pressed.connect(
			_on_color_pressed.bind(color)
		)


		palette_grid.add_child(button)

		buttons.append(button)


	set_bottom_editor(palette_grid)


# ============================================================
# STYLE
# ============================================================

func _make_style(
	color: Color,
	border_width: int,
	border_color: Color
) -> StyleBoxFlat:

	var style := StyleBoxFlat.new()

	style.bg_color = color


	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width


	style.border_color = border_color


	style.corner_radius_top_left = 1
	style.corner_radius_top_right = 1
	style.corner_radius_bottom_left = 1
	style.corner_radius_bottom_right = 1


	return style


# ============================================================
# COLOR PRESSED
# ============================================================

func _on_color_pressed(color: Color) -> void:

	if updating:
		return


	emit_changed(
		get_edited_property(),
		color
	)


# ============================================================
# UPDATE PROPERTY
# ============================================================

func _update_property() -> void:

	var edited_object := get_edited_object()

	if not is_instance_valid(edited_object):
		return


	var value = edited_object.get(
		get_edited_property()
	)


	# --------------------------------------------------------
	# This is the fix for the Nil -> Color error.
	#
	# Inspector properties can temporarily return null while
	# Godot is rebuilding the inspector. Do not force that
	# value into a Color variable.
	# --------------------------------------------------------

	if value == null:
		return


	if not value is Color:
		return


	var current_color: Color = value


	updating = true


	for i in range(buttons.size()):

		var button := buttons[i]

		var palette_color: Color = (
			NESPalette.COLORS[i]
		)


		if _colors_equal(
			current_color,
			palette_color
		):

			button.add_theme_stylebox_override(
				"normal",
				_make_style(
					palette_color,
					3,
					Color.WHITE
				)
			)

		else:

			button.add_theme_stylebox_override(
				"normal",
				_make_style(
					palette_color,
					1,
					Color(0.2, 0.2, 0.2)
				)
			)


	updating = false


# ============================================================
# COLOR COMPARISON
# ============================================================

func _colors_equal(
	a: Color,
	b: Color
) -> bool:

	return (
		is_equal_approx(a.r, b.r)
		and is_equal_approx(a.g, b.g)
		and is_equal_approx(a.b, b.b)
		and is_equal_approx(a.a, b.a)
	)
