@tool
class_name DrRogueoBoard
extends Node2D


# ============================================================
# BOARD
# ============================================================

const BOARD_WIDTH := 8
const BOARD_HEIGHT := 16
const CELL_SIZE := 8

const BOARD_Y_OFFSET := 16


# ============================================================
# FALL SPEED
# ============================================================

enum FallSpeed {
	LOW,
	MEDIUM,
	HIGH
}

@export_category("Pill")

@export var pill_scene: PackedScene

@export_enum("LOW", "MEDIUM", "HIGH")
var fall_speed: int = FallSpeed.LOW


@export_category("Virus")

@export var virus_scene: PackedScene

@export_range(0, 20, 1)
var level: int = 0


# ============================================================
# BACKGROUND
# ============================================================

@export_category("Background")

@export var background: Background


# ============================================================
# FALL TIMINGS
# ============================================================

const FALL_FRAMES_LOW := 48
const FALL_FRAMES_MEDIUM := 32
const FALL_FRAMES_HIGH := 16


const VANISH_DURATION := 0.30


# ============================================================
# LEVEL TRANSITION
# ============================================================

const LEVEL_TRANSITION_DURATION := 2.0

var transition_layer: CanvasLayer
var transition_rect: ColorRect

var transitioning_level := false


# ============================================================
# RUNTIME STATE
# ============================================================

var current_pill: Pill
var next_pill: Pill

var current_grid_position := Vector2i.ZERO

var fall_timer := 0.0
var lock_timer := 0.0

var resolving_board := false


# Vector2i -> PillHalf
var occupied_cells: Dictionary = {}


# Vector2i -> Virus
var virus_cells: Dictionary = {}


# Node2D -> remaining time
var vanishing_halves: Dictionary = {}


var _z_was_pressed := false
var _x_was_pressed := false

var _soft_dropping := false


var rng := RandomNumberGenerator.new()


# ============================================================
# LIFECYCLE
# ============================================================

func _ready() -> void:

	if Engine.is_editor_hint():
		return

	rng.randomize()

	create_transition_overlay()

	# Starting level background.
	apply_new_level_background()

	# Create the preview first.
	create_next_preview()

	# Then turn that preview into the active pill.
	spawn_pill()

	# Finally populate the board.
	generate_starting_viruses()


# ============================================================
# PROCESS
# ============================================================

func _process(delta: float) -> void:

	if Engine.is_editor_hint():
		return

	# --------------------------------------------------------
	# VANISHING OBJECTS
	# --------------------------------------------------------

	if not vanishing_halves.is_empty():

		var finished_halves: Array[Node2D] = []

		for half in vanishing_halves.keys():

			if not is_instance_valid(half):
				finished_halves.append(half)
				continue

			vanishing_halves[half] -= delta

			if vanishing_halves[half] <= 0.0:
				finished_halves.append(half)

		for half in finished_halves:

			vanishing_halves.erase(half)

			if is_instance_valid(half):
				half.queue_free()


	# --------------------------------------------------------
	# LEVEL TRANSITION
	# --------------------------------------------------------

	if transitioning_level:
		return


	# --------------------------------------------------------
	# NO ACTIVE PILL
	# --------------------------------------------------------

	if current_pill == null:
		return


	# --------------------------------------------------------
	# BOARD RESOLUTION
	# --------------------------------------------------------

	if resolving_board:
		return


	_handle_input()


	var can_fall := can_pill_occupy(
		current_grid_position + Vector2i(0, 1)
	)


	# --------------------------------------------------------
	# FALLING
	# --------------------------------------------------------

	if can_fall:

			lock_timer = 0.0

			var interval := get_fall_interval()

			if Input.is_action_pressed("ui_down"):
				interval = get_soft_drop_interval()

			fall_timer = min(fall_timer, interval)

			fall_timer += delta

			if fall_timer >= interval:

				fall_timer -= interval

				try_move_pill(Vector2i(0, 1))

			return


	# --------------------------------------------------------
	# GROUNDED
	# --------------------------------------------------------

	fall_timer = 0.0

	lock_timer += delta

	if lock_timer >= get_lock_interval():
		settle_current_pill()


# ============================================================
# LEVEL TRANSITION OVERLAY
# ============================================================

func create_transition_overlay() -> void:

	transition_layer = CanvasLayer.new()

	transition_layer.name = "LevelTransitionLayer"

	transition_layer.layer = 100

	add_child(transition_layer)


	transition_rect = ColorRect.new()

	transition_rect.name = "BlackScreen"

	transition_rect.color = Color.BLACK

	transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	transition_rect.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	transition_rect.visible = false

	transition_layer.add_child(transition_rect)


func set_transition_black(black: bool) -> void:

	if transition_rect == null:
		return

	transition_rect.visible = black


# ============================================================
# BACKGROUND
# ============================================================

func apply_new_level_background() -> void:

	if background == null:

		push_warning(
			"Board: Background reference is NULL; cannot reroll background."
		)

		return


	print(
		"Board: Applying random background preset for level ",
		level
	)

	background.apply_random_preset()

	print(
		"Board: Background random preset call completed."
	)


# ============================================================
# LEVEL TRANSITION
# ============================================================

func advance_to_next_level() -> void:

	print(">>> ADVANCE TO NEXT LEVEL CALLED <<<")

	if transitioning_level:
		return


	transitioning_level = true


	# ========================================================
	# REMOVE ACTIVE PLAYER PILL
	# ========================================================

	if current_pill != null:

		current_pill.queue_free()

		current_pill = null


	# ========================================================
	# REMOVE NEXT PREVIEW
	# ========================================================

	if next_pill != null:

		next_pill.queue_free()

		next_pill = null


	# ========================================================
	# CLEAR ALL SETTLED PILLS
	# ========================================================

	clear_occupied_cells()


	# ========================================================
	# CLEAR ALL VIRUSES
	# ========================================================

	clear_virus_cells()


	# ========================================================
	# BLACK SCREEN
	# ========================================================

	set_transition_black(true)


	# ========================================================
	# WAIT
	# ========================================================

	await get_tree().create_timer(
		LEVEL_TRANSITION_DURATION
	).timeout


	# ========================================================
	# NEXT LEVEL
	# ========================================================

	level += 1


	# ========================================================
	# ROLL NEW BACKGROUND
	#
	# Screen is still black here.
	# ========================================================

	apply_new_level_background()


	# ========================================================
	# GENERATE NEW VIRUSES
	# ========================================================

	generate_starting_viruses()


	# ========================================================
	# IMPORTANT:
	#
	# The transition flag MUST be cleared BEFORE spawn_pill().
	#
	# spawn_pill() intentionally refuses to create a pill while
	# transitioning_level is true.
	# ========================================================

	transitioning_level = false


	# ========================================================
	# CREATE NEW PREVIEW
	# ========================================================

	create_next_preview()


	# ========================================================
	# CREATE NEW ACTIVE PLAYER PILL
	# ========================================================

	spawn_pill()


	# ========================================================
	# REVEAL NEW LEVEL
	# ========================================================

	set_transition_black(false)


# ============================================================
# CLEAR SETTLED PILLS
# ============================================================

func clear_occupied_cells() -> void:

	for half in occupied_cells.values():

		if is_instance_valid(half):

			half.queue_free()


	occupied_cells.clear()


# ============================================================
# FALL SPEED
# ============================================================

func get_fall_frames() -> int:

	match fall_speed:

		FallSpeed.LOW:
			return FALL_FRAMES_LOW

		FallSpeed.MEDIUM:
			return FALL_FRAMES_MEDIUM

		FallSpeed.HIGH:
			return FALL_FRAMES_HIGH

	return FALL_FRAMES_LOW


func get_fall_interval() -> float:

	return float(get_fall_frames()) / 60.0


func get_lock_interval() -> float:

	return get_fall_interval() * 0.5


const SOFT_DROP_FRAMES := 6

func get_soft_drop_interval() -> float:

	return float(SOFT_DROP_FRAMES) / 60.0


# ============================================================
# BOARD POSITIONING
# ============================================================

func grid_to_local(
	grid_position: Vector2i
) -> Vector2:

	var board_pixel_width := BOARD_WIDTH * CELL_SIZE
	var board_pixel_height := BOARD_HEIGHT * CELL_SIZE

	var top_left := Vector2(
		-board_pixel_width / 2.0,
		-board_pixel_height / 2.0 + BOARD_Y_OFFSET
	)

	return top_left + Vector2(
		grid_position.x * CELL_SIZE,
		grid_position.y * CELL_SIZE
	)


# ============================================================
# VIRUS PLACEMENT
# ============================================================

func place_virus(
	cell: Vector2i,
	color: PillHalf.PillColor
) -> Virus:

	if virus_scene == null:

		push_warning(
			"Board: No virus scene assigned."
		)

		return null


	if is_cell_filled(cell):
		return null


	var virus := virus_scene.instantiate() as Virus

	if virus == null:
		return null


	add_child(virus)

	virus.virus_color = color

	virus.position = grid_to_local(cell)

	virus_cells[cell] = virus

	return virus


# ============================================================
# STARTING VIRUSES
# ============================================================

const VIRUS_LEVEL_CAP := 20

const VIRUS_MIN_ROW := 8
const VIRUS_MAX_ROW := BOARD_HEIGHT - 1

const VIRUS_SAME_COLOR_DISTANCE := 2


func get_starting_virus_count() -> int:

	var clamped_level := clampi(
		level,
		0,
		VIRUS_LEVEL_CAP
	)

	return (clamped_level + 1) * 4


func generate_starting_viruses() -> void:

	if virus_scene == null:

		push_warning(
			"Board: No virus scene assigned."
		)

		return


	clear_virus_cells()


	var virus_count := get_starting_virus_count()

	var attempts := 0

	var max_attempts := virus_count * 100


	while virus_cells.size() < virus_count:

		attempts += 1

		if attempts > max_attempts:

			push_warning(
				"Board: Could not place all starting viruses."
			)

			break


		var cell := Vector2i(
			rng.randi_range(
				0,
				BOARD_WIDTH - 1
			),
			rng.randi_range(
				VIRUS_MIN_ROW,
				VIRUS_MAX_ROW
			)
		)


		if is_cell_filled(cell):
			continue


		var color := choose_starting_virus_color(
			virus_cells.size()
		)


		if not can_place_starting_virus(
			cell,
			color
		):

			continue


		place_virus(cell, color)


# ============================================================
# CLEAR VIRUSES
# ============================================================

func clear_virus_cells() -> void:

	for virus in virus_cells.values():

		if is_instance_valid(virus):

			virus.queue_free()


	virus_cells.clear()


# ============================================================
# VIRUS COLOR
# ============================================================

func choose_starting_virus_color(
	virus_index: int
) -> PillHalf.PillColor:

	match virus_index:

		0:
			return PillHalf.PillColor.YELLOW

		1:
			return PillHalf.PillColor.RED

		2:
			return PillHalf.PillColor.BLUE


	return random_pill_color()


# ============================================================
# VIRUS VALIDATION
# ============================================================

func can_place_starting_virus(
	cell: Vector2i,
	color: PillHalf.PillColor
) -> bool:

	var horizontal_check := cell + Vector2i(
		-VIRUS_SAME_COLOR_DISTANCE,
		0
	)


	if horizontal_check.x >= 0:

		if get_color_at_cell(horizontal_check) == color:
			return false


	var vertical_check := cell + Vector2i(
		0,
		-VIRUS_SAME_COLOR_DISTANCE
	)


	if vertical_check.y >= VIRUS_MIN_ROW:

		if get_color_at_cell(vertical_check) == color:
			return false


	return true


# ============================================================
# VIRUS COUNT
# ============================================================

func get_virus_count() -> int:

	return virus_cells.size()


# ============================================================
# PILL POSITION
# ============================================================

func update_pill_position() -> void:

	if current_pill == null:
		return


	current_pill.position = grid_to_local(
		current_grid_position
	)


# ============================================================
# RANDOM COLORS
# ============================================================

func random_pill_color() -> int:

	return rng.randi_range(
		PillHalf.PillColor.RED,
		PillHalf.PillColor.BLUE
	)


func randomize_pill_colors(
	pill: Pill
) -> void:

	if pill == null:
		return

	pill.half_1_color = random_pill_color()

	pill.half_2_color = random_pill_color()


# ============================================================
# NEXT PILL PREVIEW
# ============================================================

func create_next_preview() -> void:

	if pill_scene == null:

		push_warning(
			"Board: No pill scene assigned."
		)

		return


	if next_pill != null:

		next_pill.queue_free()

		next_pill = null


	next_pill = pill_scene.instantiate() as Pill


	if next_pill == null:

		push_error(
			"Board: Pill scene does not contain a Pill node."
		)

		return


	add_child(next_pill)


	next_pill.orientation = Pill.Orientation.RIGHT

	randomize_pill_colors(next_pill)


	var preview_position := Vector2i(
		BOARD_WIDTH / 2 - 1,
		-7
	)


	next_pill.position = grid_to_local(
		preview_position
	)


# ============================================================
# PILL SPAWNING
# ============================================================

func spawn_pill() -> void:

	# --------------------------------------------------------
	# DO NOT spawn during the black-screen transition.
	#
	# advance_to_next_level() now turns transitioning_level
	# OFF before calling this function.
	# --------------------------------------------------------

	if transitioning_level:
		return


	if pill_scene == null:

		push_warning(
			"Board: No pill scene assigned."
		)

		return


	# ========================================================
	# USE PREVIEW AS ACTIVE PILL
	# ========================================================

	if next_pill != null:

		current_pill = next_pill

		next_pill = null


	else:

		current_pill = (
			pill_scene.instantiate()
			as Pill
		)


		if current_pill == null:

			push_error(
				"Board: Pill scene does not contain a Pill node."
			)

			return


		add_child(current_pill)

		randomize_pill_colors(current_pill)


	# ========================================================
	# INITIAL PILL STATE
	# ========================================================

	current_pill.orientation = Pill.Orientation.RIGHT


	current_grid_position = Vector2i(
		BOARD_WIDTH / 2 - 1,
		0
	)


	fall_timer = 0.0
	lock_timer = 0.0


	update_pill_position()


	# ========================================================
	# MAKE NEXT PREVIEW
	# ========================================================

	create_next_preview()


# ============================================================
# INPUT
# ============================================================

func _handle_input() -> void:

	if Input.is_action_just_pressed("ui_left"):

		try_move_pill(
			Vector2i(-1, 0)
		)


	if Input.is_action_just_pressed("ui_right"):

		try_move_pill(
			Vector2i(1, 0)
		)

	if Input.is_action_just_pressed("ui_down"):

		if try_move_pill(Vector2i(0, 1)):

			fall_timer = 0.0

	if Input.is_key_pressed(KEY_Z):

		if not _z_was_pressed:

			_z_was_pressed = true

			try_rotate_pill_counter_clockwise()

	else:

		_z_was_pressed = false


	if Input.is_key_pressed(KEY_X):

		if not _x_was_pressed:

			_x_was_pressed = true

			try_rotate_pill()

	else:

		_x_was_pressed = false


# ============================================================
# MOVEMENT
# ============================================================

func try_move_pill(
	direction: Vector2i
) -> bool:

	if current_pill == null:
		return false


	var new_position := (
		current_grid_position + direction
	)


	if not can_pill_occupy(new_position):
		return false


	current_grid_position = new_position

	update_pill_position()


	if can_pill_occupy(
		current_grid_position + Vector2i(0, 1)
	):

		lock_timer = 0.0


	return true


# ============================================================
# CELL LOOKUP
# ============================================================

func is_cell_filled(
	cell: Vector2i
) -> bool:

	if occupied_cells.has(cell):
		return true


	if virus_cells.has(cell):
		return true


	return false


func get_color_at_cell(
	cell: Vector2i
) -> Variant:

	if occupied_cells.has(cell):

		var half: PillHalf = (
			occupied_cells[cell]
			as PillHalf
		)


		if half != null:
			return half.pill_color


	if virus_cells.has(cell):

		var virus: Virus = (
			virus_cells[cell]
			as Virus
		)


		if virus != null:
			return virus.virus_color


	return null


func can_pill_occupy(
	grid_position: Vector2i
) -> bool:

	if current_pill == null:
		return false


	var cells := current_pill.get_occupied_cells(
		grid_position
	)


	for cell in cells:

		if cell.x < 0:
			return false

		if cell.x >= BOARD_WIDTH:
			return false

		if cell.y < 0:
			return false

		if cell.y >= BOARD_HEIGHT:
			return false


		if is_cell_filled(cell):
			return false


	return true


# ============================================================
# ROTATION
# ============================================================

const ROTATION_KICKS := [0, -1, 1]


func try_rotate_pill() -> bool:

	return _try_rotate(1)


func try_rotate_pill_counter_clockwise() -> bool:

	return _try_rotate(3)


func _try_rotate(
	direction_steps: int
) -> bool:

	if current_pill == null:
		return false


	var old_orientation := current_pill.orientation


	var new_orientation := (
		old_orientation + direction_steps
	) % 4


	for kick in ROTATION_KICKS:

		var candidate_position := (
			current_grid_position
			+ Vector2i(kick, 0)
		)


		current_pill.orientation = new_orientation


		if can_pill_occupy(candidate_position):

			current_grid_position = candidate_position

			update_pill_position()

			lock_timer = 0.0

			return true


	current_pill.orientation = old_orientation

	return false


# ============================================================
# SETTLING
# ============================================================

func settle_current_pill() -> void:

	if current_pill == null:
		return


	var half_1 := (
		current_pill.get_node_or_null("Half1")
		as PillHalf
	)


	var half_2 := (
		current_pill.get_node_or_null("Half2")
		as PillHalf
	)


	if half_1 == null or half_2 == null:

		push_error(
			"Board: Current pill is missing Half1 or Half2."
		)

		return


	half_1.partner_half = half_2
	half_2.partner_half = half_1


	var half_1_cell := (
		current_pill.get_half_1_cell(
			current_grid_position
		)
	)


	var half_2_cell := (
		current_pill.get_half_2_cell(
			current_grid_position
		)
	)


	half_1.reparent(self, true)
	half_2.reparent(self, true)


	half_1.pill_state = get_settled_state_for_half(
		current_pill,
		1
	)


	half_2.pill_state = get_settled_state_for_half(
		current_pill,
		2
	)


	half_1.position = grid_to_local(
		half_1_cell
	)


	half_2.position = grid_to_local(
		half_2_cell
	)


	occupied_cells[half_1_cell] = half_1
	occupied_cells[half_2_cell] = half_2


	current_pill.queue_free()

	current_pill = null


	resolve_board()


# ============================================================
# SETTLED HALF STATE
# ============================================================

func get_settled_state_for_half(
	pill: Pill,
	which_half: int
) -> int:

	match pill.orientation:

		Pill.Orientation.RIGHT:

			if which_half == 1:
				return PillHalf.PillState.LEFT

			return PillHalf.PillState.RIGHT


		Pill.Orientation.DOWN:

			if which_half == 1:
				return PillHalf.PillState.TOP

			return PillHalf.PillState.BOTTOM


		Pill.Orientation.LEFT:

			if which_half == 1:
				return PillHalf.PillState.RIGHT

			return PillHalf.PillState.LEFT


		Pill.Orientation.UP:

			if which_half == 1:
				return PillHalf.PillState.BOTTOM

			return PillHalf.PillState.TOP


	return PillHalf.PillState.SEPARATED


# ============================================================
# MATCH RESOLUTION
# ============================================================

func resolve_board() -> void:

	if resolving_board:
		return


	resolving_board = true


	var level_cleared := await _resolve_matches_and_gravity()


	resolving_board = false


	if level_cleared:

		await advance_to_next_level()

		return


	spawn_pill()


# ============================================================
# RESOLVE MATCHES + GRAVITY
# ============================================================

func _resolve_matches_and_gravity() -> bool:

	while true:

		var matches := find_matches()


		if matches.is_empty():

			return false


		separate_partners_of_matches(matches)


		for cell in matches:

			var half: PillHalf = (
				occupied_cells.get(cell)
				as PillHalf
			)


			if half != null:

				half.pill_state = (
					PillHalf.PillState.VANISHING
				)

				occupied_cells.erase(cell)

				vanishing_halves[half] = (
					VANISH_DURATION
				)

				continue


			var virus: Virus = (
				virus_cells.get(cell)
				as Virus
			)


			if virus != null:

				virus.visual_state = (
					Virus.VisualState.VANISHING
				)

				virus_cells.erase(cell)

				vanishing_halves[virus] = (
					VANISH_DURATION
				)


		# ----------------------------------------------------
		# LEVEL CLEAR
		# ----------------------------------------------------

		if virus_cells.is_empty():

			await wait_for_vanishing_halves()

			return true


		# ----------------------------------------------------
		# GRAVITY
		# ----------------------------------------------------

		await apply_gravity()


		await wait_for_vanishing_halves()


	return false


# ============================================================
# SEPARATE MATCH PARTNERS
# ============================================================

func separate_partners_of_matches(
	matches: Array[Vector2i]
) -> void:

	for cell in matches:

		var half: PillHalf = (
			occupied_cells.get(cell)
			as PillHalf
		)


		if half == null:
			continue


		var partner := half.partner_half


		if partner == null:
			continue


		if matches_contain_half(
			matches,
			partner
		):

			continue


		partner.pill_state = (
			PillHalf.PillState.SEPARATED
		)


		partner.partner_half = null

		half.partner_half = null


# ============================================================
# MATCH CONTAINS HALF
# ============================================================

func matches_contain_half(
	matches: Array[Vector2i],
	target: PillHalf
) -> bool:

	for cell in matches:

		var half: PillHalf = (
			occupied_cells.get(cell)
			as PillHalf
		)


		if half == target:
			return true


	return false


# ============================================================
# FIND MATCHES
# ============================================================

func find_matches() -> Array[Vector2i]:

	var matched_cells: Dictionary = {}


	var cells_to_check: Array[Vector2i] = []


	for cell in occupied_cells.keys():

		cells_to_check.append(cell)


	for cell in virus_cells.keys():

		cells_to_check.append(cell)


	for cell in cells_to_check:

		var color: Variant = (
			get_color_at_cell(cell)
		)


		if color == null:
			continue


		# ----------------------------------------------------
		# HORIZONTAL
		# ----------------------------------------------------

		var horizontal: Array[Vector2i] = [
			cell,
			cell + Vector2i(1, 0),
			cell + Vector2i(2, 0),
			cell + Vector2i(3, 0)
		]


		if line_matches(
			horizontal,
			color
		):

			for match_cell in horizontal:

				matched_cells[match_cell] = true


		# ----------------------------------------------------
		# VERTICAL
		# ----------------------------------------------------

		var vertical: Array[Vector2i] = [
			cell,
			cell + Vector2i(0, 1),
			cell + Vector2i(0, 2),
			cell + Vector2i(0, 3)
		]


		if line_matches(
			vertical,
			color
		):

			for match_cell in vertical:

				matched_cells[match_cell] = true


	var result: Array[Vector2i] = []


	for cell in matched_cells.keys():

		result.append(cell)


	return result


# ============================================================
# LINE MATCH
# ============================================================

func line_matches(
	cells: Array[Vector2i],
	color: int
) -> bool:

	for cell in cells:

		if not is_cell_filled(cell):
			return false


		if get_color_at_cell(cell) != color:
			return false


	return true


# ============================================================
# WAIT FOR VANISHING
# ============================================================

func wait_for_vanishing_halves() -> void:

	while not vanishing_halves.is_empty():

		await get_tree().process_frame


# ============================================================
# GRAVITY
# ============================================================

func apply_gravity() -> void:

	while true:

		var units := build_gravity_units()


		units.sort_custom(
			func(
				a: Dictionary,
				b: Dictionary
			) -> bool:

				return (
					gravity_unit_lowest_row(a)
					>
					gravity_unit_lowest_row(b)
				)
		)


		var movable_units: Array[Dictionary] = []

		var moving_halves: Dictionary = {}


		for unit in units:

			if gravity_unit_can_fall(
				unit,
				moving_halves
			):

				movable_units.append(unit)


				var halves: Array[PillHalf] = (
					unit["halves"]
				)


				for half in halves:

					moving_halves[half] = true


		if movable_units.is_empty():
			break


		await get_tree().create_timer(
			get_gravity_interval()
		).timeout


		for unit in movable_units:

			move_gravity_unit(unit)


		await get_tree().process_frame


# ============================================================
# BUILD GRAVITY UNITS
# ============================================================

func build_gravity_units() -> Array[Dictionary]:

	var units: Array[Dictionary] = []

	var visited: Dictionary = {}


	for cell in occupied_cells.keys():

		var half: PillHalf = (
			occupied_cells[cell]
			as PillHalf
		)


		if half == null:
			continue


		if visited.has(half):
			continue


		var partner := half.partner_half


		if partner != null:

			var partner_cell: Variant = (
				find_half_cell(partner)
			)


			if partner_cell != null:

				var pair_cells: Array[Vector2i] = [
					cell,
					partner_cell
				]


				var pair_halves: Array[PillHalf] = [
					half,
					partner
				]


				units.append({
					"halves": pair_halves,
					"cells": pair_cells
				})


				visited[half] = true
				visited[partner] = true

				continue


		var solo_halves: Array[PillHalf] = [
			half
		]


		var solo_cells: Array[Vector2i] = [
			cell
		]


		units.append({
			"halves": solo_halves,
			"cells": solo_cells
		})


		visited[half] = true


	return units


# ============================================================
# GRAVITY INTERVAL
# ============================================================

func get_gravity_interval() -> float:

	return float(FALL_FRAMES_HIGH) / 100.0


# ============================================================
# FIND HALF CELL
# ============================================================

func find_half_cell(
	target: PillHalf
) -> Variant:

	if target == null:
		return null


	for cell in occupied_cells.keys():

		if occupied_cells[cell] == target:

			return cell


	return null


# ============================================================
# GRAVITY COLLISION
# ============================================================

func gravity_unit_can_fall(
	unit: Dictionary,
	moving_halves: Dictionary
) -> bool:

	var cells: Array[Vector2i] = (
		unit["cells"]
	)


	for cell in cells:

		var destination := (
			cell + Vector2i(0, 1)
		)


		if destination.y >= BOARD_HEIGHT:

			return false


		if virus_cells.has(destination):

			return false


		if occupied_cells.has(destination):

			var occupant: PillHalf = (
				occupied_cells[destination]
				as PillHalf
			)


			if unit_contains_half(
				unit,
				occupant
			):

				continue


			if moving_halves.has(occupant):

				continue


			return false


	return true


# ============================================================
# LOWEST UNIT ROW
# ============================================================

func gravity_unit_lowest_row(
	unit: Dictionary
) -> int:

	var cells: Array[Vector2i] = (
		unit["cells"]
	)


	var lowest := cells[0].y


	for cell in cells:

		if cell.y > lowest:

			lowest = cell.y


	return lowest


# ============================================================
# UNIT CONTAINS HALF
# ============================================================

func unit_contains_half(
	unit: Dictionary,
	target: PillHalf
) -> bool:

	var halves: Array[PillHalf] = (
		unit["halves"]
	)


	for half in halves:

		if half == target:

			return true


	return false


# ============================================================
# MOVE GRAVITY UNIT
# ============================================================

func move_gravity_unit(
	unit: Dictionary
) -> void:

	var halves: Array[PillHalf] = (
		unit["halves"]
	)


	var cells: Array[Vector2i] = (
		unit["cells"]
	)


	# --------------------------------------------------------
	# Remove old positions.
	# --------------------------------------------------------

	for cell in cells:

		occupied_cells.erase(cell)


	# --------------------------------------------------------
	# Calculate destinations.
	# --------------------------------------------------------

	var destination_cells: Array[Vector2i] = []


	for cell in cells:

		var destination := (
			cell + Vector2i(0, 1)
		)


		destination_cells.append(
			destination
		)


	# --------------------------------------------------------
	# Register destinations.
	# --------------------------------------------------------

	for i in range(halves.size()):

		var half: PillHalf = halves[i]

		var destination: Vector2i = (
			destination_cells[i]
		)


		occupied_cells[destination] = half


	# --------------------------------------------------------
	# Snap sprites.
	# --------------------------------------------------------

	for i in range(halves.size()):

		var half: PillHalf = halves[i]

		var destination: Vector2i = (
			destination_cells[i]
		)


		half.position = grid_to_local(
			destination
		)


# ============================================================
# DEBUG
# ============================================================

func get_occupied_cell_count() -> int:

	return occupied_cells.size()
