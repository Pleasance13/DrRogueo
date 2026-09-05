class_name ThwompController
extends Node2D


# ============================================================
# THWOMP (controller)
# ============================================================
#
# thwomp.png: 24x72, three 24x24 frames stacked vertically --
#   frame 0 (y=0)  -> default (hovering / falling / after settle)
#   frame 1 (y=24) -> impact / hit-stop
#   frame 2 (y=48) -> vanishing
#
# Each 24x24 frame is 3 columns x 3 rows of 8x8 cells. Drawing
# is done manually (_draw(), not a plain Sprite2D) so each of
# the 3 footprint COLUMNS can be sliced out and independently
# offset when the Pacman trait wraps one or more of them around
# the board edge -- exactly the same technique Pill.gd uses for
# the Shift Pill's wrap-split visual.
#
# `col` is the LOGICAL leftmost footprint column and is allowed
# to drift outside [0, BOARD_WIDTH) while Pacman is owned; it is
# only ever wrapped at the point of use (collision, crushing,
# boss check, drawing), never clamped or normalized in place.
#
# ============================================================

const FOOTPRINT := 3

const ROW_FALL_INTERVAL := 0.04
const HIT_STOP_DURATION := 0.07
const IMPACT_SETTLE_DELAY := 0.15
const SIT_DURATION := 0.75
const VANISH_DURATION := 0.3

const ROW_SHAKE_INTENSITY := 1
const IMPACT_SHAKE_INTENSITY := 2.0
const IMPACT_SHAKE_DURATION := 0.4

const HORIZONTAL_REPEAT_INTERVAL := 0.12

const FRAME_SIZE := 24
const CELL_SIZE := 8

const REGION_DEFAULT := Rect2(0, 0, FRAME_SIZE, FRAME_SIZE)
const REGION_IMPACT := Rect2(0, FRAME_SIZE, FRAME_SIZE, FRAME_SIZE)
const REGION_VANISH := Rect2(0, FRAME_SIZE * 2, FRAME_SIZE, FRAME_SIZE)


var board: DrRogueoBoard

var col := 0
var positioning := true

var _left_hold_timer := 0.0
var _right_hold_timer := 0.0

var thwomp_texture: Texture2D
var current_frame_region := REGION_DEFAULT


# ============================================================
# START
# ============================================================

func start(p_board: DrRogueoBoard) -> void:

	board = p_board

	col = clampi(
		DrRogueoBoard.BOARD_WIDTH / 2 - 1,
		0,
		DrRogueoBoard.BOARD_WIDTH - FOOTPRINT
	)

	thwomp_texture = board.thwomp_sprite_texture

	current_frame_region = REGION_DEFAULT

	positioning = true

	_update_position(0.0)


func _set_frame(region: Rect2) -> void:

	current_frame_region = region

	queue_redraw()


# ============================================================
# COLUMNS (WRAP-AWARE)
# ============================================================

func _pacman_active() -> bool:

	return board != null and board.has_pacman_trait()


# Real on-board column for footprint offset (0..FOOTPRINT-1),
# used for collision / crushing / boss checks.
func _real_col(offset: int) -> int:

	var raw := col + offset

	if _pacman_active():

		return wrapi(raw, 0, DrRogueoBoard.BOARD_WIDTH)

	return raw


func _footprint_cols() -> Array[int]:

	var cols: Array[int] = []

	for offset in range(FOOTPRINT):

		cols.append(_real_col(offset))

	return cols


# ============================================================
# POSITION
# ============================================================
#
# Anchored using the LOGICAL (possibly out-of-range) leftmost
# column -- grid_to_local() is pure linear math, so this still
# produces a coherent position even when col has drifted past
# either edge under Pacman. Per-column wrap correction happens
# separately in _draw().
# ============================================================

func _update_position(top_row_offset: float) -> void:

	var base := board.grid_to_local(Vector2i(col, 0))

	position = Vector2(
		base.x,
		base.y + top_row_offset * DrRogueoBoard.CELL_SIZE
	)

	queue_redraw()


# ============================================================
# POSITIONING INPUT (HOLD-REPEAT)
# ============================================================

func _process(delta: float) -> void:

	if not positioning:
		return


	if Input.is_action_just_pressed("item_use"):

		positioning = false

		_fall()

		return


	if Input.is_action_just_pressed("ui_left"):

		_move(-1)

		_left_hold_timer = 0.0

	elif Input.is_action_pressed("ui_left"):

		_left_hold_timer += delta

		if _left_hold_timer >= HORIZONTAL_REPEAT_INTERVAL:

			_left_hold_timer -= HORIZONTAL_REPEAT_INTERVAL

			_move(-1)

	else:

		_left_hold_timer = 0.0


	if Input.is_action_just_pressed("ui_right"):

		_move(1)

		_right_hold_timer = 0.0

	elif Input.is_action_pressed("ui_right"):

		_right_hold_timer += delta

		if _right_hold_timer >= HORIZONTAL_REPEAT_INTERVAL:

			_right_hold_timer -= HORIZONTAL_REPEAT_INTERVAL

			_move(1)

	else:

		_right_hold_timer = 0.0


func _move(step: int) -> void:

	if _pacman_active():

		col += step

	else:

		col = clampi(
			col + step,
			0,
			DrRogueoBoard.BOARD_WIDTH - FOOTPRINT
		)

	_update_position(0.0)


# ============================================================
# DRAW (PER-COLUMN WRAP SPLIT)
# ============================================================

func _draw() -> void:

	if thwomp_texture == null:
		return


	for offset in range(FOOTPRINT):

		var slice_region := Rect2(
			current_frame_region.position.x + offset * CELL_SIZE,
			current_frame_region.position.y,
			CELL_SIZE,
			FRAME_SIZE
		)

		var dest_position := (
			Vector2(offset * CELL_SIZE, 0)
			+ _wrap_offset_for_column(offset)
		)

		draw_texture_rect_region(
			thwomp_texture,
			Rect2(
				dest_position,
				Vector2(CELL_SIZE, FRAME_SIZE)
			),
			slice_region
		)


# Returns the visual x-offset needed to draw column `offset`
# at its wrapped position instead of its logical (possibly
# off-board) one. Zero when that column doesn't need wrapping.
func _wrap_offset_for_column(offset: int) -> Vector2:

	if not _pacman_active():
		return Vector2.ZERO


	var logical_col := col + offset

	if logical_col >= 0 and logical_col < DrRogueoBoard.BOARD_WIDTH:

		return Vector2.ZERO


	var wrapped_col := wrapi(
		logical_col,
		0,
		DrRogueoBoard.BOARD_WIDTH
	)

	return (
		board.grid_to_local(Vector2i(wrapped_col, 0))
		- board.grid_to_local(Vector2i(logical_col, 0))
	)


# ============================================================
# FALL (ROW BY ROW, WITH HIT-STOP)
# ============================================================

func _fall() -> void:

	var target_top_row := DrRogueoBoard.BOARD_HEIGHT - FOOTPRINT

	var current_top_row := 0


	while current_top_row < target_top_row:

		current_top_row += 1

		_update_position(float(current_top_row))


		var leading_row := current_top_row + FOOTPRINT - 1

		var hit := _crush_row_if_occupied(leading_row)


		if hit:

			_set_frame(REGION_IMPACT)

			board.do_screen_shake(
				ROW_SHAKE_INTENSITY,
				HIT_STOP_DURATION
			)

			await get_tree().create_timer(
				HIT_STOP_DURATION
			).timeout

			_set_frame(REGION_DEFAULT)

		else:

			await get_tree().create_timer(
				ROW_FALL_INTERVAL
			).timeout


	await _impact()


# Crushes every occupied cell in `row` across the current
# footprint columns (wrap-resolved). Returns true if anything
# was actually there to crush (used to trigger hit-stop).
func _crush_row_if_occupied(row: int) -> bool:

	if row < 0 or row >= DrRogueoBoard.BOARD_HEIGHT:
		return false

	var hit := false

	for real_col in _footprint_cols():

		var cell := Vector2i(real_col, row)

		if board.is_cell_filled(cell):

			hit = true

		board.crush_cell(cell)

	return hit


# ============================================================
# IMPACT (BOTTOM OF BOARD)
# ============================================================

func _impact() -> void:

	_set_frame(REGION_IMPACT)

	board.do_screen_shake(
		IMPACT_SHAKE_INTENSITY,
		IMPACT_SHAKE_DURATION
	)

	await _check_boss_hit()

	await get_tree().create_timer(IMPACT_SETTLE_DELAY).timeout

	_set_frame(REGION_DEFAULT)

	await get_tree().create_timer(SIT_DURATION).timeout

	await _vanish()


func _check_boss_hit() -> void:

	if board.boss_controller == null:
		return

	if board.boss_controller.defeated:
		return

	var hit := false

	for real_col in _footprint_cols():

		for row in range(DrRogueoBoard.BOARD_HEIGHT):

			if board.boss_blocked_cells.has(Vector2i(real_col, row)):

				hit = true

				break

		if hit:
			break

	if not hit:
		return

	await board.boss_controller.take_direct_damage(1)


# ============================================================
# VANISH
# ============================================================

func _vanish() -> void:

	_set_frame(REGION_VANISH)

	await get_tree().create_timer(VANISH_DURATION).timeout

	board.on_thwomp_finished()

	queue_free()
