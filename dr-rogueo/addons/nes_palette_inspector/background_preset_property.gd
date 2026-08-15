@tool
extends EditorProperty


var container: VBoxContainer
var updating := false


func _init() -> void:

	container = VBoxContainer.new()

	add_child(container)

	set_bottom_editor(container)


func _update_property() -> void:

	if updating:
		return

	if not is_instance_valid(get_edited_object()):
		return

	updating = true

	_rebuild()

	updating = false


func _rebuild() -> void:

	for child in container.get_children():
		child.queue_free()


	var background := get_edited_object() as Background

	if background == null:
		return


	var presets := background.color_presets


	if presets.is_empty():

		var empty_label := Label.new()

		empty_label.text = "No presets assigned."

		container.add_child(empty_label)

		return


	for i in range(presets.size()):

		var preset := presets[i]

		var row := HBoxContainer.new()

		row.custom_minimum_size.y = 28

		container.add_child(row)


		# ====================================================
		# PRESET NAME
		# ====================================================

		var name_label := Label.new()

		if preset != null:
			name_label.text = preset.preset_name
		else:
			name_label.text = "(Empty preset)"

		name_label.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)

		name_label.vertical_alignment = (
			VERTICAL_ALIGNMENT_CENTER
		)

		row.add_child(name_label)


		# ====================================================
		# COLOR PREVIEW
		# ====================================================

		if preset != null:

			var light_preview := ColorRect.new()

			light_preview.custom_minimum_size = Vector2(
				16,
				24
			)

			light_preview.color = preset.light_color

			light_preview.mouse_filter = (
				Control.MOUSE_FILTER_IGNORE
			)

			row.add_child(light_preview)


			var dark_preview := ColorRect.new()

			dark_preview.custom_minimum_size = Vector2(
				16,
				24
			)

			dark_preview.color = preset.dark_color

			dark_preview.mouse_filter = (
				Control.MOUSE_FILTER_IGNORE
			)

			row.add_child(dark_preview)


			var shadow_preview := ColorRect.new()

			shadow_preview.custom_minimum_size = Vector2(
				16,
				24
			)

			shadow_preview.color = preset.shadow_color

			shadow_preview.mouse_filter = (
				Control.MOUSE_FILTER_IGNORE
			)

			row.add_child(shadow_preview)


		# ====================================================
		# LOAD BUTTON
		# ====================================================

		var load_button := Button.new()

		load_button.text = "Load"

		load_button.custom_minimum_size.x = 60

		load_button.disabled = preset == null

		load_button.focus_mode = Control.FOCUS_NONE

		load_button.pressed.connect(
			_on_load_pressed.bind(i)
		)

		row.add_child(load_button)


func _on_load_pressed(index: int) -> void:

	if updating:
		return


	var background := (
		get_edited_object()
		as Background
	)

	if background == null:
		return


	if index < 0:
		return

	if index >= background.color_presets.size():
		return


	var preset := background.color_presets[index]

	if preset == null:
		return


	# ========================================================
	# APPLY PRESET TO THE ACTUAL BACKGROUND
	# ========================================================

	background.apply_preset(preset)

	background.current_preset_index = index
	background._last_preset_index = index


	# ========================================================
	# MAKE SURE THE VIEWPORT REFRESHES
	# ========================================================

	background.queue_redraw()

	background.notify_property_list_changed()


	# ========================================================
	# MARK THE SCENE AS MODIFIED
	# ========================================================

	var edited_object := get_edited_object()

	if edited_object != null:
		edited_object.emit_signal(
			"property_list_changed"
		)
