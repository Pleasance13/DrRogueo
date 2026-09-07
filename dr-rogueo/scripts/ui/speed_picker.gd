@tool
class_name SpeedPicker
extends Node2D

# ============================================================
# SPEED PICKER (title screen)
# ============================================================
#
# Cycles SLOW/MED/HIGH with ui_left/ui_right. Index matches
# Board.FallSpeed (LOW=0, MEDIUM=1, HIGH=2) 1:1.
# ============================================================

signal speed_changed(speed_index: int)

const LABELS := ["SLOW", "MED", "HIGH"]

@export_group("Text")
@export var label_font: Font:
	set(value):
		label_font = value
		_refresh()

@export_range(1, 32, 1)
var label_font_size := 8:
	set(value):
		label_font_size = value
		_refresh()

@export var label_position := Vector2.ZERO:
	set(value):
		label_position = value
		_refresh()

@export var label_size := Vector2(80, 16):
	set(value):
		label_size = value
		_refresh()

@export var label_alignment := HORIZONTAL_ALIGNMENT_CENTER:
	set(value):
		label_alignment = value
		_refresh()

@export_group("Colors")
@export var slow_color := Color.WHITE:
	set(value):
		slow_color = value
		_refresh()

@export var med_color := Color.WHITE:
	set(value):
		med_color = value
		_refresh()

@export var high_color := Color.WHITE:
	set(value):
		high_color = value
		_refresh()


var current_index := 0

var _label: Label


func _ready() -> void:

	_ensure_label()
	_refresh()

	if Engine.is_editor_hint():
		return

	set_process_unhandled_input(true)


func _ensure_label() -> void:

	if not is_inside_tree():
		return

	_label = get_node_or_null("SpeedLabel") as Label

	if _label == null:

		_label = Label.new()
		_label.name = "SpeedLabel"

		add_child(_label)

		if Engine.is_editor_hint():
			_label.owner = get_tree().edited_scene_root


func _unhandled_input(event: InputEvent) -> void:

	if Engine.is_editor_hint():
		return

	if event.is_action_pressed("ui_left"):
		_cycle(-1)

	elif event.is_action_pressed("ui_right"):
		_cycle(1)


func _cycle(direction: int) -> void:

	current_index = wrapi(
		current_index + direction,
		0,
		LABELS.size()
	)

	_refresh()

	speed_changed.emit(current_index)


func _refresh() -> void:

	_ensure_label()

	if _label == null:
		return

	_label.text = LABELS[current_index]

	_label.position = label_position
	_label.size = label_size
	_label.horizontal_alignment = label_alignment

	_label.add_theme_font_size_override(
		"font_size",
		label_font_size
	)

	_label.add_theme_color_override(
		"font_color",
		_get_color_for_index(current_index)
	)

	if label_font != null:

		_label.add_theme_font_override(
			"font",
			label_font
		)


func _get_color_for_index(index: int) -> Color:

	match index:
		0: return slow_color
		1: return med_color
		2: return high_color

	return Color.WHITE


func get_selected_fall_speed() -> int:

	return current_index
