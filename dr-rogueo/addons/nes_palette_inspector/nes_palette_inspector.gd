@tool
extends EditorInspectorPlugin


const NESPaletteProperty = preload(
	"res://addons/nes_palette_inspector/nes_palette_property.gd"
)


# ============================================================
# CAN HANDLE
# ============================================================

func _can_handle(object: Object) -> bool:

	return (
		object is Background
		or object is BackgroundPreset
	)


# ============================================================
# PARSE PROPERTY
# ============================================================

func _parse_property(
	object: Object,
	type: Variant.Type,
	name: String,
	hint_type: PropertyHint,
	hint_string: String,
	usage_flags: int,
	wide: bool
) -> bool:

	# ========================================================
	# BACKGROUND PRESET BUTTONS
	# ========================================================
	#
	# We intercept NOTHING about the actual array editor.
	#
	# Returning false lets Godot draw its normal
	# Array[BackgroundPreset] property.
	#
	# We add our preview controls immediately afterward.
	# ========================================================

	if (
		object is Background
		and name == "color_presets"
	):

		_add_preset_preview_controls(
			object as Background
		)

		return false


	# ========================================================
	# NES PALETTE COLORS
	# ========================================================

	if (
		(
			name == "shadow_color"
			or name == "light_color"
			or name == "dark_color"
		)
		and type == TYPE_COLOR
	):

		var property_editor := NESPaletteProperty.new()

		add_property_editor(
			name,
			property_editor
		)

		return true


	return false


# ============================================================
# PRESET PREVIEW CONTROLS
# ============================================================

func _add_preset_preview_controls(
	background: Background
) -> void:

	if background == null:
		return


	if background.color_presets.is_empty():
		return


	var outer_container := VBoxContainer.new()

	outer_container.name = "PresetPreviewControls"


	# --------------------------------------------------------
	# Header
	# --------------------------------------------------------

	var header := Label.new()

	header.text = "Preview Presets"

	header.add_theme_font_size_override(
		"font_size",
		12
	)

	outer_container.add_child(header)


	# --------------------------------------------------------
	# One row per preset
	# --------------------------------------------------------

	for i in range(background.color_presets.size()):

		var preset := background.color_presets[i]

		if preset == null:
			continue


		var row := HBoxContainer.new()

		row.custom_minimum_size = Vector2(
			0,
			26
		)


		# ====================================================
		# LIGHT COLOR SWATCH
		# ====================================================

		var light_swatch := ColorRect.new()

		light_swatch.color = preset.light_color

		light_swatch.custom_minimum_size = Vector2(
			22,
			22
		)

		row.add_child(light_swatch)


		# ====================================================
		# DARK COLOR SWATCH
		# ====================================================

		var dark_swatch := ColorRect.new()

		dark_swatch.color = preset.dark_color

		dark_swatch.custom_minimum_size = Vector2(
			22,
			22
		)

		row.add_child(dark_swatch)


		# ====================================================
		# SHADOW COLOR SWATCH
		# ====================================================

		var shadow_swatch := ColorRect.new()

		shadow_swatch.color = preset.shadow_color

		shadow_swatch.custom_minimum_size = Vector2(
			22,
			22
		)

		row.add_child(shadow_swatch)


		# ====================================================
		# PRESET NAME
		# ====================================================

		var name_label := Label.new()

		var preset_name := preset.preset_name

		if preset_name.is_empty():
			preset_name = "Preset %d" % (i + 1)


		name_label.text = preset_name

		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

		name_label.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)

		row.add_child(name_label)


		# ====================================================
		# LOAD BUTTON
		# ====================================================

		var button := Button.new()

		button.text = "Load"

		button.custom_minimum_size = Vector2(
			70,
			24
		)

		button.focus_mode = Control.FOCUS_NONE


		button.pressed.connect(
			_on_load_preset_pressed.bind(
				background,
				i
			)
		)


		row.add_child(button)


		outer_container.add_child(row)


	add_custom_control(outer_container)


# ============================================================
# LOAD PRESET
# ============================================================

func _on_load_preset_pressed(
	background: Background,
	index: int
) -> void:

	if not is_instance_valid(background):
		return


	if index < 0:
		return


	if index >= background.color_presets.size():
		return


	var preset := background.color_presets[index]

	if preset == null:
		return


	background.preview_preset(index)

	background.queue_redraw()
