class_name Tether
extends Node2D


# ============================================================
# TETHER
# ============================================================
#
# Persistent bridge between two colored endpoints.
#
# Deployment:
#
#   1. Tether pill disappears.
#   2. Tether ends show their DEPLOYING sprites.
#   3. After a short delay, the bridge extends outward from
#      both endpoints simultaneously.
#   4. Once fully extended, the tether remains persistent if
#      the endpoint colors match.
#   5. If the endpoint colors do NOT match, the tether waits
#      briefly after fully extending, then breaks.
#
# If either endpoint pill is destroyed, the tether breaks.
#
# ============================================================


enum Orientation {
	HORIZONTAL,
	VERTICAL
}


const DEPLOYING_DURATION := 0.18
const DEPLOY_INTERVAL := 0.08
const DEPLOY_COMPLETE_DELAY := 0.18

const CELL_SIZE := 8


# ============================================================
# SPRITESHEET REGIONS
# ============================================================

const REGION_VERTICAL_TOP_PILL := Rect2(0, 0, 8, 8)
const REGION_VERTICAL_BOTTOM_PILL := Rect2(0, 8, 8, 8)

const REGION_VERTICAL_TOP_DEPLOYING := Rect2(8, 0, 8, 8)
const REGION_VERTICAL_BOTTOM_DEPLOYING := Rect2(8, 8, 8, 8)

const REGION_VERTICAL_TOP_DEPLOYED := Rect2(16, 0, 8, 8)
const REGION_VERTICAL_BOTTOM_DEPLOYED := Rect2(16, 8, 8, 8)

const REGION_VERTICAL_TOP_END := Rect2(0, 16, 8, 8)
const REGION_VERTICAL_MIDDLE := Rect2(8, 16, 8, 8)
const REGION_VERTICAL_BOTTOM_END := Rect2(16, 16, 8, 8)


const REGION_HORIZONTAL_LEFT_PILL := Rect2(0, 24, 8, 8)
const REGION_HORIZONTAL_RIGHT_PILL := Rect2(8, 24, 8, 8)

const REGION_HORIZONTAL_LEFT_DEPLOYING := Rect2(0, 32, 8, 8)
const REGION_HORIZONTAL_RIGHT_DEPLOYING := Rect2(8, 32, 8, 8)

const REGION_HORIZONTAL_LEFT_END := Rect2(16, 24, 8, 8)
const REGION_HORIZONTAL_RIGHT_END := Rect2(16, 40, 8, 8)

const REGION_HORIZONTAL_MIDDLE := Rect2(16, 32, 8, 8)

const REGION_HORIZONTAL_LEFT_DEPLOYED := Rect2(0, 40, 8, 8)
const REGION_HORIZONTAL_RIGHT_DEPLOYED := Rect2(8, 40, 8, 8)


# ============================================================
# STATE
# ============================================================

var board: DrRogueoBoard

var tether_cells: Array[Vector2i] = []

var endpoint_a := Vector2i.ZERO
var endpoint_b := Vector2i.ZERO

var orientation: int = Orientation.HORIZONTAL

var tether_color: PillHalf.PillColor

var texture: Texture2D

var original_pill_cells: Array[Vector2i] = []

# Whether the two endpoint colors matched when deployed.
#
# A mismatched tether still fully deploys, but breaks after
# the deployment completes.
var colors_match := true


# ============================================================
# DEPLOYMENT STATE
# ============================================================

var deploying := false
var deployment_timer := 0.0

var extension_started := false
var deploy_timer := 0.0

var cells_from_start := 0
var cells_from_end := 0


# ============================================================
# ENDPOINT MONITORING
# ============================================================

const ENDPOINT_CHECK_INTERVAL := 0.05

var endpoint_check_timer := 0.0


# ============================================================
# DEPLOY
# ============================================================

func deploy(
	dr_board: DrRogueoBoard,
	p_cells: Array[Vector2i],
	p_endpoint_a: Vector2i,
	p_endpoint_b: Vector2i,
	p_orientation: int,
	p_color: PillHalf.PillColor,
	p_texture: Texture2D,
	p_original_pill_cells: Array[Vector2i],
	p_colors_match: bool
) -> void:

	board = dr_board

	tether_cells = p_cells.duplicate()

	endpoint_a = p_endpoint_a
	endpoint_b = p_endpoint_b

	orientation = p_orientation

	tether_color = p_color

	texture = p_texture

	original_pill_cells = (
		p_original_pill_cells.duplicate()
	)

	colors_match = p_colors_match

	deploying = true
	deployment_timer = 0.0

	extension_started = false
	deploy_timer = 0.0

	cells_from_start = 0
	cells_from_end = 0

	endpoint_check_timer = 0.0

	queue_redraw()


# ============================================================
# PROCESS
# ============================================================

func _process(delta: float) -> void:

	# --------------------------------------------------------
	# ENDPOINT MONITORING
	# --------------------------------------------------------

	endpoint_check_timer += delta

	if endpoint_check_timer >= ENDPOINT_CHECK_INTERVAL:

		endpoint_check_timer = 0.0

		if not _endpoints_are_valid():

			break_tether()

			return


	# --------------------------------------------------------
	# DEPLOYING
	# --------------------------------------------------------

	if deploying:

		deployment_timer += delta

		if deployment_timer >= DEPLOYING_DURATION:

			deploying = false
			extension_started = true
			deploy_timer = 0.0

			queue_redraw()

		return


	# --------------------------------------------------------
	# EXTENSION
	# --------------------------------------------------------

	if not extension_started:
		return


	if (
		cells_from_start +
		cells_from_end
		>= tether_cells.size()
	):

		extension_started = false

		queue_redraw()


		# ----------------------------------------------------
		# MISMATCHED COLORS
		# ----------------------------------------------------
		#
		# The tether has now fully connected. Give the player
		# a brief moment to see it before destroying it.
		#
		# ----------------------------------------------------

		if not colors_match:

			await get_tree().create_timer(
				DEPLOY_COMPLETE_DELAY
			).timeout

			# The tether may already have been destroyed while
			# we were waiting.
			if is_instance_valid(self):

				break_tether()

		return


	deploy_timer += delta

	if deploy_timer < DEPLOY_INTERVAL:
		return


	deploy_timer -= DEPLOY_INTERVAL


	# --------------------------------------------------------
	# EXTEND FROM BOTH ENDS SIMULTANEOUSLY
	# --------------------------------------------------------

	if (
		cells_from_start +
		cells_from_end
		< tether_cells.size()
	):

		cells_from_start += 1


	if (
		cells_from_start +
		cells_from_end
		< tether_cells.size()
	):

		cells_from_end += 1


	queue_redraw()


# ============================================================
# DRAW
# ============================================================

func _draw() -> void:

	if texture == null:
		return


	if deploying:

		_draw_deploying_pill()

		return


	var visible_count := mini(
		cells_from_start +
		cells_from_end,
		tether_cells.size()
	)


	if visible_count <= 0:
		return


	# --------------------------------------------------------
	# DRAW VISIBLE TETHER
	# --------------------------------------------------------

	for i in range(visible_count):

		var cell := tether_cells[i]

		var region: Rect2


		# First visible cell is the left/top end.

		if i == 0:

			if orientation == Orientation.HORIZONTAL:

				region = REGION_HORIZONTAL_LEFT_END

			else:

				region = REGION_VERTICAL_TOP_END


		# Last visible cell is the right/bottom end.

		elif i == visible_count - 1:

			if orientation == Orientation.HORIZONTAL:

				region = REGION_HORIZONTAL_RIGHT_END

			else:

				region = REGION_VERTICAL_BOTTOM_END


		# Everything between the ends is middle.

		else:

			region = REGION_FOR_MIDDLE()


		_draw_region_at_cell(
			region,
			cell
		)


# ============================================================
# DEPLOYING PILL
# ============================================================

func _draw_deploying_pill() -> void:

	if original_pill_cells.size() != 2:
		return


	var first := original_pill_cells[0]
	var second := original_pill_cells[1]


	if orientation == Orientation.HORIZONTAL:

		var left_cell := first
		var right_cell := second


		if left_cell.x > right_cell.x:

			left_cell = second
			right_cell = first


		_draw_region_at_cell(
			REGION_HORIZONTAL_LEFT_DEPLOYING,
			left_cell
		)

		_draw_region_at_cell(
			REGION_HORIZONTAL_RIGHT_DEPLOYING,
			right_cell
		)


	else:

		var top_cell := first
		var bottom_cell := second


		if top_cell.y > bottom_cell.y:

			top_cell = second
			bottom_cell = first


		_draw_region_at_cell(
			REGION_VERTICAL_TOP_DEPLOYING,
			top_cell
		)

		_draw_region_at_cell(
			REGION_VERTICAL_BOTTOM_DEPLOYING,
			bottom_cell
		)


# ============================================================
# MIDDLE REGION
# ============================================================

func REGION_FOR_MIDDLE() -> Rect2:

	if orientation == Orientation.HORIZONTAL:

		return REGION_HORIZONTAL_MIDDLE

	return REGION_VERTICAL_MIDDLE


# ============================================================
# DRAW REGION AT BOARD CELL
# ============================================================

func _draw_region_at_cell(
	region: Rect2,
	cell: Vector2i
) -> void:

	if board == null:
		return


	var local_position := (
		board.grid_to_local(cell) -
		position
	)


	draw_texture_rect_region(
		texture,
		Rect2(
			local_position,
			Vector2(
				CELL_SIZE,
				CELL_SIZE
			)
		),
		region
	)


# ============================================================
# ENDPOINT VALIDATION
# ============================================================

func _endpoints_are_valid() -> bool:

	if board == null:
		return false


	if not board.is_cell_filled(endpoint_a):
		return false


	if not board.is_cell_filled(endpoint_b):
		return false


	# --------------------------------------------------------
	# During deployment, the endpoints are allowed to have
	# different colors. That's the whole point of the
	# mismatch behavior.
	#
	# Once deployment has completed, a mismatched tether is
	# already scheduled to break.
	# --------------------------------------------------------

	if not colors_match:
		return true


	if board.get_color_at_cell(endpoint_a) != tether_color:
		return false


	if board.get_color_at_cell(endpoint_b) != tether_color:
		return false


	return true


# ============================================================
# BREAK TETHER
# ============================================================

func break_tether() -> void:

	deploying = false
	extension_started = false

	if board != null:

		board._remove_tether(self)

	else:

		tether_cells.clear()

		queue_free()


# ============================================================
# DIRECTION
# ============================================================

func connects_in_direction(
	cell: Vector2i,
	direction: Vector2i
) -> bool:

	if orientation == Orientation.HORIZONTAL:

		return (
			direction == Vector2i(-1, 0)
			or
			direction == Vector2i(1, 0)
		)


	if orientation == Orientation.VERTICAL:

		return (
			direction == Vector2i(0, -1)
			or
			direction == Vector2i(0, 1)
		)


	return false
