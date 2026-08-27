@tool
class_name ScoreMultiplier
extends Node2D


# ============================================================
# SCORE MULTIPLIER
# ============================================================
#
# Displays the current end-of-stage coin multiplier, driven by
# the OD gauge's zone. Picks the matching frame out of the
# scorex-values.png spritesheet (3 columns x 2 rows, 27x27):
#
#     0x    0.5x  1x
#     1.5x  2x    3x
#
# ============================================================

@export var value_sprite_path: NodePath = NodePath("ScoreX-Value")

const FRAME_SIZE := 27


var _value_sprite: Sprite2D

var current_multiplier := 1.5


# ============================================================
# LIFECYCLE
# ============================================================

func _ready() -> void:

	_value_sprite = get_node_or_null(value_sprite_path) as Sprite2D

	set_multiplier(current_multiplier)


# ============================================================
# SET MULTIPLIER
# ============================================================

func set_multiplier(multiplier: float) -> void:

	current_multiplier = multiplier

	if _value_sprite == null:
		return

	var frame := _frame_for_multiplier(multiplier)

	_value_sprite.region_rect = Rect2(
		frame.x * FRAME_SIZE,
		frame.y * FRAME_SIZE,
		FRAME_SIZE,
		FRAME_SIZE
	)


# ============================================================
# FRAME LOOKUP
# ============================================================

func _frame_for_multiplier(multiplier: float) -> Vector2i:

	# Snap to the nearest supported value.

	if multiplier >= 1.25:
		return Vector2i(0, 1) # 1.5x

	if multiplier >= 0.75:
		return Vector2i(2, 0) # 1x

	if multiplier >= 0.25:
		return Vector2i(1, 0) # 0.5x

	return Vector2i(0, 0) # 0x
