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
#   3. After a short delay, the bridge grows outward from
#      the middle toward both endpoints simultaneously.
#   4. Once fully extended, the tether remains persistent if
#      the endpoint colors match.
#   5. If the endpoint colors do NOT match, the tether waits
#      briefly after fully extending, then breaks.
#
# A wall endpoint behaves like a mismatched color:
# it still fully deploys, then breaks.
#
# IMPORTANT:
#
# deploy() does not finish until the visual deployment is
# completely finished. Board.gd can therefore safely:
#
#     await tether.deploy(...)
#
# and know that the next pill will not spawn prematurely.
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
# SIGNALS
# ============================================================

signal deployment_finished


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
# deployment completes.
var colors_match := true

# Whether each endpoint hit the board edge instead of finding
# a colored cell.
var endpoint_a_hit_wall := false
var endpoint_b_hit_wall := false


# ============================================================
# DEPLOYMENT STATE
# ============================================================

var deploying := false
var deployment_timer := 0.0

var extension_started := false
var deploy_timer := 0.0

# Number of tether cells currently revealed.
#
# These cells are always centered around the middle of the
# tether and expand outward toward both endpoints.
var visible_cells := 0


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
	p_colors_match: bool,
	p_endpoint_a_hit_wall: bool = false,
	p_endpoint_b_hit_wall: bool = false
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

	endpoint_a_hit_wall = p_endpoint_a_hit_wall
	endpoint_b_hit_wall = p_endpoint_b_hit_wall

	deploying = true
	deployment_timer = 0.0

	extension_started = false
	deploy_timer = 0.0

	visible_cells = 0

	endpoint_check_timer = 0.0

	queue_redraw()


	# ========================================================
	# IMPORTANT:
	#
	# Wait here until the deployment has actually finished.
	#
	# This makes:
	#
	#     await tether.deploy(...)
	#
	# in Board.gd meaningful.
	# ========================================================

	await deployment_finished


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


			# Start at the middle.
			#
			# Odd-length tethers start with one center cell.
			# Even-length tethers start with two center cells.

			if tether_cells.size() % 2 == 1:

				visible_cells = 1

			else:

				visible_cells = 2


			queue_redraw()

		return


	# --------------------------------------------------------
	# EXTENSION
	# --------------------------------------------------------

	if not extension_started:
		return


	if visible_cells >= tether_cells.size():

		extension_started = false

		queue_redraw()


		# ----------------------------------------------------
		# MISMATCHED COLORS / WALL
		# ----------------------------------------------------
		#
		# The tether has now fully connected.
		# Give the player a brief moment to see it before
		# destroying it.
		# ----------------------------------------------------

		if not colors_match:

			await get_tree().create_timer(
				DEPLOY_COMPLETE_DELAY
			).timeout


			# The tether may already have been destroyed while
			# we were waiting.

			if not is_instance_valid(self):

				return


			break_tether()

			return


		# ----------------------------------------------------
		# VALID TETHER
		# ----------------------------------------------------
		#
		# It is now fully deployed and persistent.
		# Tell Board.gd it is safe to continue.
		# ----------------------------------------------------

		deployment_finished.emit()

		return


	deploy_timer += delta

	if deploy_timer < DEPLOY_INTERVAL:
		return


	deploy_timer -= DEPLOY_INTERVAL


	# --------------------------------------------------------
	# EXTEND OUTWARD FROM THE CENTER
	# --------------------------------------------------------
	#
	# Every tick adds one cell to each side.
	# --------------------------------------------------------

	visible_cells += 2

	if visible_cells > tether_cells.size():

		visible_cells = tether_cells.size()


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


	var total_cells := tether_cells.size()

	if total_cells <= 0:
		return


	if visible_cells <= 0:
		return


	var start_index := 0
	var end_index := total_cells - 1


	# --------------------------------------------------------
	# CALCULATE THE VISIBLE CENTER RANGE
	# --------------------------------------------------------

	if total_cells % 2 == 1:

		var center_index := total_cells / 2
		var half_visible := visible_cells / 2

		start_index = center_index - half_visible
		end_index = center_index + half_visible


	else:

		start_index = (
			(total_cells - visible_cells) / 2
		)

		end_index = (
			start_index +
			visible_cells -
			1
		)


	start_index = maxi(
		start_index,
		0
	)

	end_index = mini(
		end_index,
		total_cells - 1
	)


	# --------------------------------------------------------
	# DRAW VISIBLE CENTER RANGE
	# --------------------------------------------------------

	for i in range(
		start_index,
		end_index + 1
	):

		_draw_tether_segment(
			i,
			total_cells
		)


# ============================================================
# DRAW TETHER SEGMENT
# ============================================================

func _draw_tether_segment(
	index: int,
	total_cells: int
) -> void:

	var cell := tether_cells[index]

	var region: Rect2


	if index == 0:

		if orientation == Orientation.HORIZONTAL:

			region = REGION_HORIZONTAL_LEFT_END

		else:

			region = REGION_VERTICAL_TOP_END


	elif index == total_cells - 1:

		if orientation == Orientation.HORIZONTAL:

			region = REGION_HORIZONTAL_RIGHT_END

		else:

			region = REGION_VERTICAL_BOTTOM_END


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


	# --------------------------------------------------------
	# WALL ENDPOINTS
	# --------------------------------------------------------

	if not endpoint_a_hit_wall:

		if not board.is_cell_filled(endpoint_a):
			return false


	if not endpoint_b_hit_wall:

		if not board.is_cell_filled(endpoint_b):
			return false


	# --------------------------------------------------------
	# MISMATCHED COLORS
	# --------------------------------------------------------
	#
	# During deployment, mismatched endpoints are allowed.
	# They will break after deployment completes.
	# --------------------------------------------------------

	if not colors_match:
		return true


	# --------------------------------------------------------
	# MATCHING ENDPOINT COLOR VALIDATION
	# --------------------------------------------------------

	if not endpoint_a_hit_wall:

		if (
			board.get_color_at_cell(endpoint_a)
			!= tether_color
		):

			return false


	if not endpoint_b_hit_wall:

		if (
			board.get_color_at_cell(endpoint_b)
			!= tether_color
		):

			return false


	return true


# ============================================================
# BREAK TETHER
# ============================================================

func break_tether() -> void:

	deploying = false
	extension_started = false


	# --------------------------------------------------------
	# Tell deploy() that deployment is finished BEFORE
	# removing the tether from the board.
	# --------------------------------------------------------

	deployment_finished.emit()


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
