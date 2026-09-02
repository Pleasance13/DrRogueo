@tool
class_name Boss1Healthbar
extends Node2D

# ============================================================
# Boss 1 Healthbar
#
# 8-segment ring from boss_healthbar.png
# 4 color columns x 2 row templates
# Each template is 35x35 pixels.
#
# Sprites are NOT centered.
# Their position is their TOP-LEFT corner.
# ============================================================

const TEXTURE_PATH := "res://art/ui/boss_healthbar.png"
const SEGMENT_SIZE := 35
const COLOR_COLUMN := 0 # 0=purple, 1=red, 2=yellow, 3=blue


# [row_template, flip_h, flip_v] per segment 1..8
const SEGMENT_DATA := [
	[0, true, false],   # 1
	[1, true, false],   # 2
	[1, true, true],    # 3
	[0, true, true],    # 4
	[0, false, true],   # 5
	[1, false, true],   # 6
	[1, false, false],  # 7
	[0, false, false],  # 8
]


# ============================================================
# SEGMENT POSITIONS
#
# These are TOP-LEFT positions because centered = false.
# Edit these directly in the Inspector while looking at the
# healthbar in the 2D editor.
# ============================================================

@export_category("Segment Positions")

@export var segment_1_position := Vector2(48, 5):
	set(value):
		segment_1_position = value
		_update_segment_position(0, value)

@export var segment_2_position := Vector2(48, 5):
	set(value):
		segment_2_position = value
		_update_segment_position(1, value)

@export var segment_3_position := Vector2(48, 39):
	set(value):
		segment_3_position = value
		_update_segment_position(2, value)

@export var segment_4_position := Vector2(48, 39):
	set(value):
		segment_4_position = value
		_update_segment_position(3, value)

@export var segment_5_position := Vector2(14, 39):
	set(value):
		segment_5_position = value
		_update_segment_position(4, value)

@export var segment_6_position := Vector2(14, 39):
	set(value):
		segment_6_position = value
		_update_segment_position(5, value)

@export var segment_7_position := Vector2(14, 5):
	set(value):
		segment_7_position = value
		_update_segment_position(6, value)

@export var segment_8_position := Vector2(14, 5):
	set(value):
		segment_8_position = value
		_update_segment_position(7, value)


var segments: Array[Sprite2D] = []
var _initialized := false


func _ready() -> void:
	_create_segments()


func _process(_delta: float) -> void:
	# @tool scripts can have their properties changed in the
	# editor without _ready() being called again.
	if Engine.is_editor_hint() and not _initialized:
		_create_segments()


func _create_segments() -> void:

	# Don't create duplicates.
	for child in get_children():
		if child is Sprite2D and child.name.begins_with("Segment"):
			child.queue_free()

	segments.clear()

	var texture := load(TEXTURE_PATH)

	if texture == null:
		return

	var positions := [
		segment_1_position,
		segment_2_position,
		segment_3_position,
		segment_4_position,
		segment_5_position,
		segment_6_position,
		segment_7_position,
		segment_8_position,
	]

	for i in range(8):

		var data: Array = SEGMENT_DATA[i]
		var sprite := Sprite2D.new()

		sprite.name = "Segment%d" % (i + 1)

		sprite.texture = texture
		sprite.region_enabled = true

		sprite.region_rect = Rect2(
			COLOR_COLUMN * SEGMENT_SIZE,
			data[0] * SEGMENT_SIZE,
			SEGMENT_SIZE,
			SEGMENT_SIZE
		)

		# IMPORTANT:
		# The sprite's position is its TOP-LEFT corner.
		sprite.centered = false

		sprite.flip_h = data[1]
		sprite.flip_v = data[2]

		sprite.position = positions[i]

		add_child(sprite)
		segments.append(sprite)

		# Runtime-only healthbar starts fully visible.
		sprite.visible = true

	_initialized = true


func _update_segment_position(index: int, position: Vector2) -> void:

	if index < 0 or index >= segments.size():
		return

	if is_instance_valid(segments[index]):
		segments[index].position = position


func set_health(health: int) -> void:

	# In the editor, make all segments visible so we can actually
	# see and position the complete ring.
	if Engine.is_editor_hint():
		for sprite in segments:
			if is_instance_valid(sprite):
				sprite.visible = true
		return

	for i in range(segments.size()):
		segments[i].visible = i >= (8 - health)
