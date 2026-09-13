class_name Boss2Controller
extends Node2D

# ============================================================
# BOSS 2 - BUBBLE MAZE
# ============================================================
#
# Same board position/animation rig as Boss1Controller, but the
# damage method is different: the whole board (minus the boss's
# own 2x2 footprint) fills with impassible bubbles, with a
# randomly-generated 1-2 cell wide corridor carved from directly
# above the boss up to the pill spawn column. Landing a pill
# directly on top of the boss deals HIT_DAMAGE and the maze
# regenerates (harder as health drops).
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


var board: DrRogueoBoard

var health := MAX_HEALTH
var defeated := false
var busy := false

var boss_col := 0
var boss_row := 0

# Vector2i -> true. The boss's own 2x2 body (never bubbled).
var footprint_cells: Dictionary = {}

# Vector2i -> Sprite2D
var bubble_cells: Dictionary = {}
# Vector2i -> int (0 = frames 0/1 pair, 1 = frames 2/3 pair)
var bubble_pair_type: Dictionary = {}

var boss_sprite: Sprite2D
var boss_anim_frame := 0

var healthbar: Boss1Healthbar

var _magnifier_root: Node2D
var _magnifier_boss: Sprite2D


@export_category("Magnifier Positions")
@export var magnifier_gradient_position: Vector2 = Vector2.ZERO
@export var magnifier_boss_position: Vector2 = Vector2.ZERO
@export var magnifier_healthbar_position: Vector2 = Vector2.ZERO


# ============================================================
# START
# ============================================================

func start(p_board: DrRogueoBoard, p_boss_col: int, p_boss_row: int) -> void:

	_reset_runtime_boss()

	board = p_board
	boss_col = p_boss_col
	boss_row = p_boss_row

	health = MAX_HEALTH
	defeated = false
	busy = false
	boss_anim_frame = 0

	footprint_cells.clear()

	for col in range(boss_col, boss_col + 2):
		for row in range(boss_row, boss_row + 2):
			footprint_cells[Vector2i(col, row)] = true

	_create_boss_sprite(boss_col, boss_row)

	if not AnimClock.frame_changed.is_connected(_on_anim_frame_changed):
		AnimClock.frame_changed.connect(_on_anim_frame_changed)

	_create_magnifier_display()

	_regenerate_maze()


func _reset_runtime_boss() -> void:

	if AnimClock.frame_changed.is_connected(_on_anim_frame_changed):
		AnimClock.frame_changed.disconnect(_on_anim_frame_changed)

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


# ============================================================
# BOSS SPRITE (identical layout to Boss1)
# ============================================================

func _place_at_boss_layer(sprite: Node) -> void:

	if board == null:
		return

	var target_index: int = min(4, board.get_child_count() - 1)

	if target_index >= 0:
		board.move_child(sprite, target_index)


func _create_boss_sprite(p_boss_col: int, p_boss_row: int) -> void:

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

		sprite.region_rect = _bubble_region(pair, frame)


# ============================================================
# BUBBLE FIELD
# ============================================================

func _bubble_region(pair: int, frame: int) -> Rect2:

	var frame_index: int = (pair * 2) + frame

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

	bubble_pair_type[cell] = pair

	sprite.region_rect = _bubble_region(pair, AnimClock.frame)

	bubble_cells[cell] = sprite
	board.boss_maze_cells[cell] = true


func _apply_bubble_field(windows: Dictionary) -> void:

	_clear_bubble_field()

	for row in range(0, DrRogueoBoard.BOARD_HEIGHT):

		for col in range(0, DrRogueoBoard.BOARD_WIDTH):

			var cell := Vector2i(col, row)

			if footprint_cells.has(cell):
				continue

			if _cell_is_in_path(cell, windows, row):
				continue

			_place_bubble(cell)


func _cell_is_in_path(
	cell: Vector2i,
	windows: Dictionary,
	row: int
) -> bool:

	if not windows.has(row):
		return false

	var window: Dictionary = windows[row]

	return (
		cell.x >= window["left"]
		and cell.x < window["left"] + window["width"]
	)


# ============================================================
# PATH GENERATION
# ============================================================
#
# Walks a 1-2 cell wide corridor from directly above the boss
# (forced 2-wide, aligned to the boss's own columns) up to the
# pill spawn row (also forced 2-wide, same columns). Every turn
# forces a 2x2 pivot (this row AND the row it came from) so a
# pill always has room to rotate through a direction change.
#
# `difficulty` is 0.0 (full health, easy) .. 1.0 (near death,
# hard): more turns and thinner corridors at higher difficulty.
#
# ============================================================

func _generate_path_windows(difficulty: float) -> Dictionary:

	var windows: Dictionary = {}

	var boss_top_row: int = boss_row - 1
	var spawn_row: int = 0

	windows[boss_top_row] = {"left": boss_col, "width": 2}
	windows[spawn_row] = {"left": boss_col, "width": 2}

	var turn_chance: float = lerpf(0.12, 0.5, difficulty)
	var wide_chance: float = lerpf(0.8, 0.3, difficulty)

	var current_left: int = boss_col

	for row in range(boss_top_row - 1, spawn_row - 1, -1):

		var steps_remaining: int = row - spawn_row
		var distance: int = boss_col - current_left

		var must_home: bool = absi(distance) >= steps_remaining

		var width: int = 2 if randf() < wide_chance else 1
		var max_left: int = DrRogueoBoard.BOARD_WIDTH - width

		var new_left: int = current_left

		if must_home:

			new_left = current_left + signi(distance)

			if new_left != current_left:

				width = 2
				max_left = DrRogueoBoard.BOARD_WIDTH - width

				if windows.has(row + 1):
					windows[row + 1]["width"] = 2

		elif randf() < turn_chance:

			width = 2
			max_left = DrRogueoBoard.BOARD_WIDTH - width

			if windows.has(row + 1):
				windows[row + 1]["width"] = 2

			var shift: int = [-1, 1][randi_range(0, 1)]
			var candidate: int = current_left + shift

			if absi(boss_col - candidate) < steps_remaining:
				new_left = candidate

		new_left = clampi(new_left, 0, max_left)

		windows[row] = {"left": new_left, "width": width}

		current_left = new_left

	return windows


func _regenerate_maze() -> void:

	if board == null:
		return

	board.clear_occupied_cells()

	var difficulty: float = 1.0 - (float(health) / float(MAX_HEALTH))

	var windows := _generate_path_windows(difficulty)

	_apply_bubble_field(windows)


# ============================================================
# DAMAGE
# ============================================================

func try_handle_pill_landing(pill: Pill, grid_position: Vector2i) -> bool:

	if defeated or busy or board == null:
		return false

	if pill == null or not is_instance_valid(pill):
		return false

	var half_1_cell := pill.get_half_1_cell(grid_position)
	var half_2_cell := pill.get_half_2_cell(grid_position)

	var lands_on_boss: bool = (
		footprint_cells.has(half_1_cell + Vector2i(0, 1))
		or footprint_cells.has(half_2_cell + Vector2i(0, 1))
	)

	if not lands_on_boss:
		return false

	busy = true

	_vanish_scoring_pill(pill, half_1_cell, half_2_cell)

	boss_sprite.frame = 2 + boss_anim_frame

	await board.get_tree().create_timer(DAMAGE_FLASH_DURATION).timeout

	await board.wait_for_vanishing_halves()

	await _finish_damage(HIT_DAMAGE)

	return true


func take_direct_damage(amount: int = HIT_DAMAGE) -> void:

	if defeated or board == null or busy:
		return

	busy = true

	boss_sprite.frame = 2 + boss_anim_frame

	await board.get_tree().create_timer(DAMAGE_FLASH_DURATION).timeout

	await _finish_damage(amount)


func _vanish_scoring_pill(
	pill: Pill,
	half_1_cell: Vector2i,
	half_2_cell: Vector2i
) -> void:

	var half_1 := pill.get_node_or_null("Half1") as PillHalf
	var half_2 := pill.get_node_or_null("Half2") as PillHalf

	if board.has_pacman_trait():
		half_1_cell = board.wrap_cell_if_needed(half_1_cell)
		half_2_cell = board.wrap_cell_if_needed(half_2_cell)

	if half_1 != null:

		half_1.pill_state = PillHalf.PillState.VANISHING
		half_1.reparent(board, true)
		half_1.position = board.grid_to_local(half_1_cell)
		board.vanishing_halves[half_1] = DrRogueoBoard.VANISH_DURATION

	if half_2 != null:

		half_2.pill_state = PillHalf.PillState.VANISHING
		half_2.reparent(board, true)
		half_2.position = board.grid_to_local(half_2_cell)
		board.vanishing_halves[half_2] = DrRogueoBoard.VANISH_DURATION

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

		_magnifier_boss.position = magnifier_boss_position
		_magnifier_boss.frame = boss_anim_frame

	_regenerate_maze()

	busy = false


func _play_death() -> void:

	defeated = true

	var death_column := boss_anim_frame

	for row in range(2, 6):

		boss_sprite.frame = row * 2 + death_column

		await board.get_tree().create_timer(DEATH_FRAME_DURATION).timeout

	boss_sprite.visible = false

	_clear_bubble_field()

	defeated_changed.emit(true)


# ============================================================
# MAGNIFIER DISPLAY (identical pattern to Boss1Controller)
# ============================================================

func _create_magnifier_display() -> void:

	var slot := board.get_tree().get_first_node_in_group(MAGNIFIER_GROUP) as Node2D

	if slot == null:

		push_warning(
			"Boss2Controller: no node in group '%s'." % MAGNIFIER_GROUP
		)

		return

	_magnifier_root = Node2D.new()
	_magnifier_root.name = "Boss2MagnifierDisplay"

	slot.add_child(_magnifier_root)

	var gradient := Sprite2D.new()
	gradient.name = "MagnifierGradient"
	gradient.centered = false
	gradient.texture = load(GRADIENT_TEXTURE_PATH)
	gradient.position = magnifier_gradient_position

	_magnifier_root.add_child(gradient)

	_magnifier_boss = Sprite2D.new()
	_magnifier_boss.name = "MagnifierBoss"
	_magnifier_boss.texture = load(MAGNIFIER_BOSS_TEXTURE_PATH)
	_magnifier_boss.hframes = 2
	_magnifier_boss.vframes = 1
	_magnifier_boss.centered = false
	_magnifier_boss.position = magnifier_boss_position
	_magnifier_boss.frame = boss_anim_frame

	_magnifier_root.add_child(_magnifier_boss)

	healthbar = Boss1Healthbar.new()
	healthbar.name = "Boss2Healthbar"
	healthbar.max_health = MAX_HEALTH
	healthbar.position = magnifier_healthbar_position

	_magnifier_root.add_child(healthbar)

	healthbar.set_health(health)


# ============================================================
# EXIT TREE
# ============================================================

func _exit_tree() -> void:

	if AnimClock.frame_changed.is_connected(_on_anim_frame_changed):
		AnimClock.frame_changed.disconnect(_on_anim_frame_changed)

	_clear_bubble_field()

	if _magnifier_root != null and is_instance_valid(_magnifier_root):
		_magnifier_root.queue_free()
