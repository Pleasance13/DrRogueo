@tool
class_name Pill
extends Node2D


enum Orientation {
	RIGHT,
	DOWN,
	LEFT,
	UP
}


enum PreviewState {
	CONNECTED,
	SEPARATED,
	BOTH_VANISHING,
	HALF_1_VANISHING,
	HALF_2_VANISHING
}


@export_category("Pill")

@export_enum("RED", "YELLOW", "BLUE")
var half_1_color: int = PillHalf.PillColor.RED:
	set(value):
		half_1_color = value
		_update_pill()


@export_enum("RED", "YELLOW", "BLUE")
var half_2_color: int = PillHalf.PillColor.BLUE:
	set(value):
		half_2_color = value
		_update_pill()


@export_enum("RIGHT", "DOWN", "LEFT", "UP")
var orientation: int = Orientation.RIGHT:
	set(value):
		orientation = value
		_update_pill()


@export_enum(
	"CONNECTED",
	"SEPARATED",
	"BOTH VANISHING",
	"HALF 1 VANISHING",
	"HALF 2 VANISHING"
)
var preview_state: int = PreviewState.CONNECTED:
	set(value):
		preview_state = value
		_update_pill()


const CELL_SIZE := 8


func _ready() -> void:
	_update_pill()


# ============================================================
# VISUAL SETUP
# ============================================================

func _update_pill() -> void:
	if not is_inside_tree():
		return

	var half_1 := get_node_or_null("Half1") as PillHalf
	var half_2 := get_node_or_null("Half2") as PillHalf

	if half_1 == null or half_2 == null:
		return

	half_1.pill_color = half_1_color
	half_2.pill_color = half_2_color

	match orientation:
		Orientation.RIGHT:
			# [Half 1][Half 2]
			# Origin is Half 1 (bottom-left).
			half_1.position = Vector2(0, 0)
			half_2.position = Vector2(CELL_SIZE, 0)

			half_1.pill_state = PillHalf.PillState.LEFT
			half_2.pill_state = PillHalf.PillState.RIGHT

		Orientation.DOWN:
			# [Half 1]
			# [Half 2]
			# Origin is Half 2 (bottom-left).
			half_1.position = Vector2(0, -CELL_SIZE)
			half_2.position = Vector2(0, 0)

			half_1.pill_state = PillHalf.PillState.TOP
			half_2.pill_state = PillHalf.PillState.BOTTOM

		Orientation.LEFT:
			# [Half 2][Half 1]
			# Origin is Half 2 (bottom-left).
			half_2.position = Vector2(0, 0)
			half_1.position = Vector2(CELL_SIZE, 0)

			half_2.pill_state = PillHalf.PillState.LEFT
			half_1.pill_state = PillHalf.PillState.RIGHT

		Orientation.UP:
			# [Half 2]
			# [Half 1]
			# Origin is Half 1 (bottom-left).
			half_2.position = Vector2(0, -CELL_SIZE)
			half_1.position = Vector2(0, 0)

			half_2.pill_state = PillHalf.PillState.TOP
			half_1.pill_state = PillHalf.PillState.BOTTOM

	# Preview state overrides connected-end sprites.
	match preview_state:
		PreviewState.CONNECTED:
			pass

		PreviewState.SEPARATED:
			half_1.pill_state = PillHalf.PillState.SEPARATED
			half_2.pill_state = PillHalf.PillState.SEPARATED

		PreviewState.BOTH_VANISHING:
			half_1.pill_state = PillHalf.PillState.VANISHING
			half_2.pill_state = PillHalf.PillState.VANISHING

		PreviewState.HALF_1_VANISHING:
			half_1.pill_state = PillHalf.PillState.VANISHING

		PreviewState.HALF_2_VANISHING:
			half_2.pill_state = PillHalf.PillState.VANISHING


# ============================================================
# GRID POSITION
# ============================================================

# grid_position is the BOTTOM-LEFT cell of the pill footprint.
#
# RIGHT:
# [0][1]
#
# DOWN:
# [0]
# [1] ← origin
#
# LEFT:
# [0][1]
#
# UP:
# [0]
# [1] ← origin

func get_occupied_cells(grid_position: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []

	match orientation:
		Orientation.RIGHT:
			cells.append(grid_position)
			cells.append(grid_position + Vector2i(1, 0))

		Orientation.DOWN:
			cells.append(grid_position + Vector2i(0, -1))
			cells.append(grid_position)

		Orientation.LEFT:
			cells.append(grid_position)
			cells.append(grid_position + Vector2i(1, 0))

		Orientation.UP:
			cells.append(grid_position)
			cells.append(grid_position + Vector2i(0, -1))

	return cells


func get_half_1_cell(grid_position: Vector2i) -> Vector2i:
	match orientation:
		Orientation.RIGHT:
			return grid_position

		Orientation.DOWN:
			return grid_position + Vector2i(0, -1)

		Orientation.LEFT:
			return grid_position + Vector2i(1, 0)

		Orientation.UP:
			return grid_position

	return grid_position


func get_half_2_cell(grid_position: Vector2i) -> Vector2i:
	match orientation:
		Orientation.RIGHT:
			return grid_position + Vector2i(1, 0)

		Orientation.DOWN:
			return grid_position

		Orientation.LEFT:
			return grid_position

		Orientation.UP:
			return grid_position + Vector2i(0, -1)

	return grid_position


# ============================================================
# ROTATION
# ============================================================

func get_rotated_orientation() -> int:
	return (orientation + 1) % 4


func rotate_pill() -> void:
	orientation = get_rotated_orientation()


# ============================================================
# SEPARATION / VANISHING
# ============================================================

func separate() -> void:
	var half_1 := get_node_or_null("Half1") as PillHalf
	var half_2 := get_node_or_null("Half2") as PillHalf

	if half_1 == null or half_2 == null:
		return

	half_1.pill_state = PillHalf.PillState.SEPARATED
	half_2.pill_state = PillHalf.PillState.SEPARATED


func vanish_half(which_half: int) -> void:
	var half_1 := get_node_or_null("Half1") as PillHalf
	var half_2 := get_node_or_null("Half2") as PillHalf

	if half_1 == null or half_2 == null:
		return

	if which_half == 1:
		half_1.pill_state = PillHalf.PillState.VANISHING

	elif which_half == 2:
		half_2.pill_state = PillHalf.PillState.VANISHING
