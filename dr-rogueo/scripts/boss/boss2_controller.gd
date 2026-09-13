class_name Boss2Controller
extends Node2D


# ============================================================
# BOSS 2 - BUBBLE MAZE
# ============================================================
#
# The board is filled with solid bubbles, leaving a traversable
# corridor from the pill spawn area down to the boss.
#
# The corridor is deliberately constructed from long straight
# sections with 2x2 turning areas. This guarantees that a normal
# two-half pill can rotate through every corner.
#
# Boss 2 rules:
#
# - Spawn area is permanently clear: 2x3.
# - Boss area is permanently clear: 2x3.
# - Minimum straightaway length is 3 cells.
# - Bubbles are solid for normal board movement/gravity.
# - Bubbles do NOT count as Tetris cells.
# - Settled pill halves take 1 damage whenever a new pill spawns.
# - Pill halves have their normal 3 HP, so they survive 3 hits.
# - Maze regeneration never deletes settled pills.
#
# ============================================================


signal defeated_changed(is_defeated: bool)


const MAX_HEALTH := 24
const HIT_DAMAGE := 3

const BOSS_TEXTURE_PATH := "res://art/viruses/boss_2.png"
const MAGNIFIER_BOSS_TEXTURE_PATH := "res://art/viruses/boss_2_magnifier.png"
const GRADIENT_TEXTURE_PATH := "res://art/ui/magnifier_gradient.png"
const BUBBLE_TEXTURE_PATH := "res://art/board/boss_bubbles_green.png"

const DAMAGE_FLASH_DURATION := 0.45
const DEATH_FRAME_DURATION := 0.45

const BUBBLE_FRAME_SIZE := 8

const MAGNIFIER_GROUP := "boss_magnifier_slot"

# Every straight section must contain at least this many cells.
const MIN_STRAIGHTAWAY_LENGTH := 3

# The board is 8 columns wide, so the permanent openings are
# the middle two columns.
const OPENING_LEFT := 3
const OPENING_WIDTH := 2
const OPENING_TOP_HEIGHT := 3
const OPENING_BOTTOM_HEIGHT := 3


var board: DrRogueoBoard

var health := MAX_HEALTH
var defeated := false
var busy := false

var boss_col := 0
var boss_row := 0

# Vector2i -> true.
# The boss's own 2x2 body.
var footprint_cells: Dictionary = {}

# Vector2i -> Sprite2D
var bubble_cells: Dictionary = {}

# Vector2i -> int
# 0 = animation frames 0/1
# 1 = animation frames 2/3
var bubble_pair_type: Dictionary = {}

# Vector2i -> int
# 0 = starts on first frame of its pair
# 1 = starts on second frame of its pair
var bubble_frame_offset: Dictionary = {}

var boss_sprite: Sprite2D
var boss_anim_frame := 0

var healthbar: Boss1Healthbar

var _magnifier_root: Node2D
var _magnifier_boss: Sprite2D

# Used to detect the arrival of a new active pill.
var _last_seen_pill: Pill = null


@export_category("Magnifier Positions")
@export var magnifier_gradient_position: Vector2 = Vector2.ZERO
@export var magnifier_boss_position: Vector2 = Vector2.ZERO
@export var magnifier_healthbar_position: Vector2 = Vector2.ZERO


# ============================================================
# START
# ============================================================

func start(
	p_board: DrRogueoBoard,
	p_boss_col: int,
	p_boss_row: int
) -> void:

	_reset_runtime_boss()

	board = p_board
	boss_col = p_boss_col
	boss_row = p_boss_row

	health = MAX_HEALTH
	defeated = false
	busy = false
	boss_anim_frame = 0
	_last_seen_pill = null

	footprint_cells.clear()

	for col in range(boss_col, boss_col + 2):

		for row in range(boss_row, boss_row + 2):

			footprint_cells[Vector2i(col, row)] = true

	_create_boss_sprite(boss_col, boss_row)

	if not AnimClock.frame_changed.is_connected(
		_on_anim_frame_changed
	):

		AnimClock.frame_changed.connect(
			_on_anim_frame_changed
		)

	_create_magnifier_display()

	_regenerate_maze()


func _reset_runtime_boss() -> void:

	if AnimClock.frame_changed.is_connected(
		_on_anim_frame_changed
	):

		AnimClock.frame_changed.disconnect(
			_on_anim_frame_changed
		)

	if boss_sprite != null and is_instance_valid(boss_sprite):

		boss_sprite.queue_free()

	boss_sprite = null

	_clear_bubble_field()

	if _magnifier_root != null and is_instance_valid(_magnifier_root):

		_magnifier_root.queue_free()

	_magnifier_root = null
	_magnifier_boss = null
	healthbar = null

	footprint_cells.clear()

	_last_seen_pill = null


# ============================================================
# PROCESS
# ============================================================

func _process(_delta: float) -> void:

	if Engine.is_editor_hint():
		return

	if board == null or defeated:
		return

	var current := board.current_pill

	if current == null:
		return

	if not is_instance_valid(current):
		return

	# Only react when a genuinely new pill becomes active.
	if current == _last_seen_pill:
		return

	_last_seen_pill = current

	_damage_settled_pills()


# ============================================================
# SETTLED PILL DAMAGE
# ============================================================

func _damage_settled_pills() -> void:

	if board == null:
		return

	# Take a snapshot because occupied_cells can change while
	# we are removing destroyed halves.
	var occupied_snapshot: Array = board.occupied_cells.keys()

	for cell in occupied_snapshot:

		if not board.occupied_cells.has(cell):
			continue

		var half := board.occupied_cells[cell] as PillHalf

		if half == null:
			continue

		if not is_instance_valid(half):
			board.occupied_cells.erase(cell)
			continue

		if half.pill_state == PillHalf.PillState.VANISHING:
			continue

		var destroyed: bool = half.take_hit()

		if not destroyed:
			continue

		board.occupied_cells.erase(cell)

		half.pill_state = PillHalf.PillState.VANISHING

		board.vanishing_halves[half] = DrRogueoBoard.VANISH_DURATION


# ============================================================
# BOSS SPRITE
# ============================================================

func _place_at_boss_layer(sprite: Node) -> void:

	if board == null:
		return

	var target_index: int = min(
		4,
		board.get_child_count() - 1
	)

	if target_index >= 0:
		board.move_child(sprite, target_index)


func _create_boss_sprite(
	p_boss_col: int,
	p_boss_row: int
) -> void:

	boss_sprite = Sprite2D.new()

	boss_sprite.name = "Boss2Sprite"
	boss_sprite.centered = false
	boss_sprite.texture = load(BOSS_TEXTURE_PATH)

	boss_sprite.hframes = 2
	boss_sprite.vframes = 6
	boss_sprite.frame = 0

	boss_sprite.position = board.grid_to_local(
		Vector2i(p_boss_col, p_boss_row)
	)

	board.add_child(boss_sprite)

	_place_at_boss_layer(boss_sprite)


func _on_anim_frame_changed(frame: int) -> void:

	boss_anim_frame = frame

	if not busy:

		if boss_sprite != null:
			boss_sprite.frame = boss_anim_frame

		if _magnifier_boss != null:

			_magnifier_boss.frame = frame
			_magnifier_boss.position = magnifier_boss_position

	for cell in bubble_cells.keys():

		var sprite: Sprite2D = bubble_cells[cell]

		if not is_instance_valid(sprite):
			continue

		var pair: int = bubble_pair_type.get(cell, 0)
		var offset: int = bubble_frame_offset.get(cell, 0)

		var local_frame: int = (
			frame + offset
		) % 2

		sprite.region_rect = _bubble_region(
			pair,
			local_frame
		)


# ============================================================
# BUBBLE FIELD
# ============================================================

func _bubble_region(pair: int, frame: int) -> Rect2:

	var frame_index: int = (
		pair * 2
	) + frame

	return Rect2(
		frame_index * BUBBLE_FRAME_SIZE,
		0,
		BUBBLE_FRAME_SIZE,
		BUBBLE_FRAME_SIZE
	)


func _clear_bubble_field() -> void:

	for cell in bubble_cells.keys():

		if board != null:
			board.boss_maze_cells.erase(cell)

		var sprite: Sprite2D = bubble_cells[cell]

		if is_instance_valid(sprite):
			sprite.queue_free()

	bubble_cells.clear()
	bubble_pair_type.clear()
	bubble_frame_offset.clear()


func _place_bubble(cell: Vector2i) -> void:

	var texture := load(BUBBLE_TEXTURE_PATH)

	var sprite := Sprite2D.new()

	sprite.centered = false
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.position = board.grid_to_local(cell)

	board.add_child(sprite)

	_place_at_boss_layer(sprite)

	var pair: int = board.rng.randi_range(0, 1)

	# Randomly start either on the first or second frame of
	# the selected animation pair.
	var frame_offset: int = board.rng.randi_range(0, 1)

	bubble_pair_type[cell] = pair
	bubble_frame_offset[cell] = frame_offset

	var local_frame: int = (
		AnimClock.frame + frame_offset
	) % 2

	sprite.region_rect = _bubble_region(
		pair,
		local_frame
	)

	bubble_cells[cell] = sprite

	board.boss_maze_cells[cell] = true


func _apply_bubble_field(path_cells: Dictionary) -> void:

	_clear_bubble_field()

	for row in range(
		0,
		DrRogueoBoard.BOARD_HEIGHT
	):

		for col in range(
			0,
			DrRogueoBoard.BOARD_WIDTH
		):

			var cell := Vector2i(col, row)

			if footprint_cells.has(cell):
				continue

			if path_cells.has(cell):
				continue

			_place_bubble(cell)


# ============================================================
# PATH GENERATION
# ============================================================
#
# This is deliberately NOT a random cell-by-cell maze walker.
#
# The board is only 8x16, and we need a corridor that is:
#
# - guaranteed connected
# - guaranteed to reach both openings
# - guaranteed to have 2x2 corners
# - guaranteed to have straightaways >= 3 cells
# - guaranteed to leave one bubble cell between parallel runs
#
# The route is therefore built from long orthogonal sections.
#
# There are two equivalent routes:
#
# LEFT:
#
#   center
#      |
#      |
#   +--+
#   |
#   |
#   +------+
#          |
#          |
#       +--+
#       |
#       |
#       boss
#
# RIGHT is the mirror image.
#
# ============================================================

func _generate_path_cells() -> Dictionary:

	var path: Dictionary = {}

	var center_left := OPENING_LEFT
	var center_right := OPENING_LEFT + 1

	var outer_left := 0
	var outer_left_right := 1

	var outer_right := DrRogueoBoard.BOARD_WIDTH - 2
	var outer_right_right := DrRogueoBoard.BOARD_WIDTH - 1

	# --------------------------------------------------------
	# The route alternates between center -> outer -> opposite
	# outer -> center.
	#
	# The horizontal sections are 2 cells high, which provides
	# the 2x2 turning space required by a two-half pill.
	# --------------------------------------------------------

	var go_left: bool = board.rng.randi_range(0, 1) == 0

	if go_left:

		# Center vertical:
		# rows 0-3
		_add_vertical_segment(
			path,
			center_left,
			center_right,
			0,
			3
		)

		# First turn + horizontal:
		# rows 3-4, x 0-4
		_add_horizontal_segment(
			path,
			outer_left,
			center_right,
			3,
			4
		)

		# Left vertical:
		# rows 4-7
		_add_vertical_segment(
			path,
			outer_left,
			outer_left_right,
			4,
			7
		)

		# Second turn + horizontal:
		# rows 7-8, x 0-7
		_add_horizontal_segment(
			path,
			outer_left,
			outer_right_right,
			7,
			8
		)

		# Right vertical:
		# rows 8-10
		_add_vertical_segment(
			path,
			outer_right,
			outer_right_right,
			8,
			10
		)

		# Third turn + horizontal:
		# rows 10-11, x 3-7
		_add_horizontal_segment(
			path,
			center_left,
			outer_right_right,
			10,
			11
		)

		# Final center vertical:
		# rows 11-13
		_add_vertical_segment(
			path,
			center_left,
			center_right,
			11,
			13
		)

	else:

		# Center vertical:
		# rows 0-3
		_add_vertical_segment(
			path,
			center_left,
			center_right,
			0,
			3
		)

		# First turn + horizontal:
		# rows 3-4, x 3-7
		_add_horizontal_segment(
			path,
			center_left,
			outer_right_right,
			3,
			4
		)

		# Right vertical:
		# rows 4-7
		_add_vertical_segment(
			path,
			outer_right,
			outer_right_right,
			4,
			7
		)

		# Second turn + horizontal:
		# rows 7-8, x 0-7
		_add_horizontal_segment(
			path,
			outer_left,
			outer_right_right,
			7,
			8
		)

		# Left vertical:
		# rows 8-10
		_add_vertical_segment(
			path,
			outer_left,
			outer_left_right,
			8,
			10
		)

		# Third turn + horizontal:
		# rows 10-11, x 0-4
		_add_horizontal_segment(
			path,
			outer_left,
			center_right,
			10,
			11
		)

		# Final center vertical:
		# rows 11-13
		_add_vertical_segment(
			path,
			center_left,
			center_right,
			11,
			13
		)

	# --------------------------------------------------------
	# Permanently clear the complete 2x3 spawn opening.
	# --------------------------------------------------------

	for row in range(
		0,
		OPENING_TOP_HEIGHT
	):

		for col in range(
			OPENING_LEFT,
			OPENING_LEFT + OPENING_WIDTH
		):

			path[Vector2i(col, row)] = true

	# --------------------------------------------------------
	# Permanently clear the complete 2x3 boss opening.
	#
	# boss_row is 14, so this covers rows 13, 14 and 15.
	# --------------------------------------------------------

	for row in range(
		boss_row - 1,
		DrRogueoBoard.BOARD_HEIGHT
	):

		for col in range(
			boss_col,
			boss_col + 2
		):

			path[Vector2i(col, row)] = true

	return path


func _add_vertical_segment(
	path: Dictionary,
	left_col: int,
	right_col: int,
	top_row: int,
	bottom_row: int
) -> void:

	for row in range(
		top_row,
		bottom_row + 1
	):

		path[Vector2i(left_col, row)] = true
		path[Vector2i(right_col, row)] = true


func _add_horizontal_segment(
	path: Dictionary,
	left_col: int,
	right_col: int,
	top_row: int,
	bottom_row: int
) -> void:

	for col in range(
		left_col,
		right_col + 1
	):

		path[Vector2i(col, top_row)] = true
		path[Vector2i(col, bottom_row)] = true


func _regenerate_maze() -> void:

	if board == null:
		return

	# IMPORTANT:
	# Do NOT clear occupied_cells here.
	#
	# Settled pills are part of the player's current board state
	# and must survive maze regeneration.
	#
	# Only the temporary bubble field gets regenerated.

	var path_cells := _generate_path_cells()

	_apply_bubble_field(path_cells)


# ============================================================
# DAMAGE
# ============================================================

func try_handle_pill_landing(
	pill: Pill,
	grid_position: Vector2i
) -> bool:

	if defeated or busy or board == null:
		return false

	if pill == null or not is_instance_valid(pill):
		return false

	var half_1_cell := pill.get_half_1_cell(
		grid_position
	)

	var half_2_cell := pill.get_half_2_cell(
		grid_position
	)

	var lands_on_boss: bool = (
		footprint_cells.has(
			half_1_cell + Vector2i(0, 1)
		)
		or footprint_cells.has(
			half_2_cell + Vector2i(0, 1)
		)
	)

	if not lands_on_boss:
		return false

	busy = true

	_vanish_scoring_pill(
		pill,
		half_1_cell,
		half_2_cell
	)

	boss_sprite.frame = 2 + boss_anim_frame

	await board.get_tree().create_timer(
		DAMAGE_FLASH_DURATION
	).timeout

	await board.wait_for_vanishing_halves()

	await _finish_damage(HIT_DAMAGE)

	return true


func take_direct_damage(
	amount: int = HIT_DAMAGE
) -> void:

	if defeated or board == null or busy:
		return

	busy = true

	boss_sprite.frame = 2 + boss_anim_frame

	await board.get_tree().create_timer(
		DAMAGE_FLASH_DURATION
	).timeout

	await _finish_damage(amount)


func _vanish_scoring_pill(
	pill: Pill,
	half_1_cell: Vector2i,
	half_2_cell: Vector2i
) -> void:

	var half_1 := pill.get_node_or_null(
		"Half1"
	) as PillHalf

	var half_2 := pill.get_node_or_null(
		"Half2"
	) as PillHalf

	if board.has_pacman_trait():

		half_1_cell = board.wrap_cell_if_needed(
			half_1_cell
		)

		half_2_cell = board.wrap_cell_if_needed(
			half_2_cell
		)

	if half_1 != null:

		half_1.pill_state = (
			PillHalf.PillState.VANISHING
		)

		half_1.reparent(board, true)

		half_1.position = board.grid_to_local(
			half_1_cell
		)

		board.vanishing_halves[half_1] = (
			DrRogueoBoard.VANISH_DURATION
		)

	if half_2 != null:

		half_2.pill_state = (
			PillHalf.PillState.VANISHING
		)

		half_2.reparent(board, true)

		half_2.position = board.grid_to_local(
			half_2_cell
		)

		board.vanishing_halves[half_2] = (
			DrRogueoBoard.VANISH_DURATION
		)

	pill.queue_free()


func _finish_damage(amount: int) -> void:

	health -= amount

	if healthbar != null:
		healthbar.set_health(health)

	if health <= 0:

		await _play_death()

		busy = false

		return

	boss_sprite.frame = boss_anim_frame

	if _magnifier_boss != null:

		_magnifier_boss.position = (
			magnifier_boss_position
		)

		_magnifier_boss.frame = boss_anim_frame

	_regenerate_maze()

	busy = false


func _play_death() -> void:

	defeated = true

	var death_column := boss_anim_frame

	for row in range(2, 6):

		boss_sprite.frame = (
			row * 2
			+ death_column
		)

		await board.get_tree().create_timer(
			DEATH_FRAME_DURATION
		).timeout

	boss_sprite.visible = false

	_clear_bubble_field()

	defeated_changed.emit(true)


# ============================================================
# MAGNIFIER DISPLAY
# ============================================================

func _create_magnifier_display() -> void:

	var slot := board.get_tree().get_first_node_in_group(
		MAGNIFIER_GROUP
	) as Node2D

	if slot == null:

		push_warning(
			"Boss2Controller: no node in group '%s'."
			% MAGNIFIER_GROUP
		)

		return

	_magnifier_root = Node2D.new()
	_magnifier_root.name = (
		"Boss2MagnifierDisplay"
	)

	slot.add_child(_magnifier_root)

	var gradient := Sprite2D.new()
	gradient.name = "MagnifierGradient"
	gradient.centered = false
	gradient.texture = load(
		GRADIENT_TEXTURE_PATH
	)
	gradient.position = (
		magnifier_gradient_position
	)

	_magnifier_root.add_child(gradient)

	_magnifier_boss = Sprite2D.new()
	_magnifier_boss.name = "MagnifierBoss"
	_magnifier_boss.texture = load(
		MAGNIFIER_BOSS_TEXTURE_PATH
	)
	_magnifier_boss.hframes = 2
	_magnifier_boss.vframes = 1
	_magnifier_boss.centered = false
	_magnifier_boss.position = (
		magnifier_boss_position
	)
	_magnifier_boss.frame = boss_anim_frame

	_magnifier_root.add_child(
		_magnifier_boss
	)

	healthbar = Boss1Healthbar.new()
	healthbar.name = "Boss2Healthbar"
	healthbar.max_health = MAX_HEALTH
	healthbar.position = (
		magnifier_healthbar_position
	)

	_magnifier_root.add_child(healthbar)

	healthbar.set_health(health)


# ============================================================
# EXIT TREE
# ============================================================

func _exit_tree() -> void:

	if AnimClock.frame_changed.is_connected(
		_on_anim_frame_changed
	):

		AnimClock.frame_changed.disconnect(
			_on_anim_frame_changed
		)

	_clear_bubble_field()

	if _magnifier_root != null and is_instance_valid(
		_magnifier_root
	):

		_magnifier_root.queue_free()
