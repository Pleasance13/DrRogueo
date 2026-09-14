class_name Boss2Controller
extends Node2D


# ============================================================
# BOSS 2 - VINE GAUNTLET / VIRUS SPITTER
# ============================================================
#
# Two repeating phases:
#
#   VINES -- small bubble globs sit on the board as cover.
#   Vines telegraph from a random board edge, then rapidly
#   grow across the board for 2 global-clock ticks.
#   Bubbles do NOT block vines; they only block player pills.
#   Settled pill halves in the vine's path ARE destroyed and
#   the vine pierces straight through them.
#   If the vine's line overlaps the currently FALLING pill
#   while extended, that pill is destroyed and the fight moves
#   to the VIRUSES phase.
#   Landing a pill on the boss itself deals damage, fully clears
#   the board (settled pills + bubbles), and rerolls fresh globs.
#
#   VIRUSES -- triggered only by getting hit by a vine. A
#   handful of normal viruses are spat from the boss toward
#   their landing cells while a horizontal guard vine blocks
#   the lower board. Clear every virus via normal matching to
#   retract the guard and return to VINES.
#
# ============================================================


signal defeated_changed(is_defeated: bool)


# ============================================================
# TUNING
# ============================================================

const MAX_HEALTH := 24
const HIT_DAMAGE := 3

const DAMAGE_FLASH_DURATION := 0.45
const DEATH_FRAME_DURATION := 0.45

# Spawn opening geometry (matches Board's spawn column).
const OPENING_LEFT := 3
const OPENING_WIDTH := 2
const OPENING_TOP_HEIGHT := 3

const GLOB_COUNT := 5
const GLOB_MIN_SIZE := 2
const GLOB_MAX_SIZE := 4

const VIRUS_PLACEMENT_INTERVAL := 0.12

# Bubble glob rows appear from bottom to top.
const GLOB_BUILD_ROW_INTERVAL := 0.045

# Visual layer values.
#
# Lower z means further behind.
# Bubbles and flying viruses sit behind the boss.
# Vines sit above bubbles so their telegraph can never be
# hidden by the bubble cover.
const BUBBLE_Z_INDEX := 10
const VINE_Z_INDEX := 20
const BOSS_Z_INDEX := 30

const TELEGRAPH_COLOR := Color(0.85, 0.15, 0.35, 1)
const ATTACK_COLOR := Color(0.65, 0.05, 0.1, 1)
const GUARD_COLOR := Color(0.35, 0.05, 0.45, 1)

const MAGNIFIER_GROUP := "boss_magnifier_slot"


# ============================================================
# INSPECTOR TUNING
# ============================================================

@export_category("Vine Tuning")

# Number of warning flashes before a vine attacks.
#
# Each flash is:
#   ON -> OFF
#
# So 2 = ON/OFF/ON/OFF/ATTACK.
@export_range(1, 10, 1)
var telegraph_flash_count: int = 2

# Vine extension speed in board cells per second.
#
# Example:
# 50 cells/sec means an 8-cell vine takes about 0.16 sec.
@export_range(1.0, 200.0, 1.0)
var vine_extend_speed: float = 50.0


@export_subgroup("Health Thresholds")

# Health fraction at which the boss leaves the HIGH tier.
@export_range(0.0, 1.0, 0.01)
var high_health_threshold: float = 0.66

# Health fraction at which the boss leaves the MEDIUM tier.
@export_range(0.0, 1.0, 0.01)
var medium_health_threshold: float = 0.33


@export_subgroup("Vine Counts")

@export_range(0, 8, 1)
var high_health_vine_count: int = 2

@export_range(0, 8, 1)
var medium_health_vine_count: int = 3

@export_range(0, 8, 1)
var low_health_vine_count: int = 4


@export_subgroup("Virus Counts")

@export_range(0, 16, 1)
var high_health_virus_count: int = 3

@export_range(0, 16, 1)
var medium_health_virus_count: int = 5

@export_range(0, 16, 1)
var low_health_virus_count: int = 7


@export_category("Virus Throw Tuning")

# Virus projectile speed in pixels per second.
@export_range(10.0, 1000.0, 5.0)
var virus_throw_speed: float = 100.0

# Height of the projectile arc in pixels.
@export_range(0.0, 32.0, 0.5)
var virus_throw_arc_height: float = 6.0

# Offset from the boss sprite's top-left corner.
#
# Default (8, 8) is the exact centre of the 16x16 boss.
@export var virus_throw_origin: Vector2 = Vector2(8.0, 8.0)


# ============================================================
# ASSETS
# ============================================================

@export_category("Textures")

@export var boss_texture_path: String = "res://art/viruses/boss_2.png"
@export var magnifier_boss_texture_path: String = "res://art/viruses/boss_2_magnifier.png"
@export var gradient_texture_path: String = "res://art/ui/magnifier_gradient.png"
@export var bubble_texture_path: String = "res://art/board/boss_bubbles_green.png"
@export var vine_texture_path: String = "res://art/board/vines.png"


@export_category("Magnifier Positions")

@export var magnifier_gradient_position: Vector2 = Vector2.ZERO
@export var magnifier_boss_position: Vector2 = Vector2.ZERO
@export var magnifier_healthbar_position: Vector2 = Vector2.ZERO


# ============================================================
# PHASE
# ============================================================

enum Phase {
	VINES,
	VIRUSES
}

var current_phase: int = Phase.VINES


# ============================================================
# STATE
# ============================================================

var board: DrRogueoBoard

var health := MAX_HEALTH
var defeated := false
var busy := false

var boss_col := 0
var boss_row := 0

# This rises by one row every time VIRUSES begins.
var guard_row := 0

var horizontal_row_min := 0
var horizontal_row_max := 0

var footprint_cells: Dictionary = {}

var active_vines: Array = []

# Vector2i -> Sprite2D
var bubble_cells: Dictionary = {}
var bubble_pair_type: Dictionary = {}
var bubble_frame_offset: Dictionary = {}

# Vector2i -> true
var guard_cells: Dictionary = {}
var _guard_visual: Node2D = null

var _phase_viruses_ready := false

var boss_sprite: Sprite2D
var boss_anim_frame := 0

var healthbar: Boss1Healthbar

var _magnifier_root: Node2D
var _magnifier_boss: Sprite2D

# Used to cancel an in-progress bubble build if the board resets.
var _bubble_build_generation := 0

# Number of times the VIRUSES phase has been entered.
# The first virus phase uses the normal position directly
# above the boss. Every later virus phase raises it by one.
var _virus_phase_count := 0


# ============================================================
# START / RESET
# ============================================================

func start(
	dr_board: DrRogueoBoard,
	p_boss_col: int,
	p_boss_row: int
) -> void:

	_reset_runtime_boss()

	board = dr_board
	boss_col = p_boss_col
	boss_row = p_boss_row

	# First virus phase will place the guard directly above
	# the boss. It gets raised by one row on subsequent phases.
	guard_row = boss_row - 1

	horizontal_row_min = OPENING_TOP_HEIGHT
	horizontal_row_max = boss_row - 2

	health = MAX_HEALTH
	defeated = false
	busy = false
	boss_anim_frame = 0
	current_phase = Phase.VINES
	_virus_phase_count = 0

	footprint_cells.clear()

	for col in range(boss_col, boss_col + 2):

		for row in range(boss_row, boss_row + 2):

			footprint_cells[Vector2i(col, row)] = true

	_create_boss_sprite(boss_col, boss_row)

	if not AnimClock.frame_changed.is_connected(_on_anim_frame_changed):

		AnimClock.frame_changed.connect(_on_anim_frame_changed)

	_create_magnifier_display()

	_spawn_bubble_globs()


func _reset_runtime_boss() -> void:

	_bubble_build_generation += 1

	if AnimClock.frame_changed.is_connected(_on_anim_frame_changed):

		AnimClock.frame_changed.disconnect(_on_anim_frame_changed)

	if boss_sprite != null and is_instance_valid(boss_sprite):

		boss_sprite.queue_free()

	boss_sprite = null

	_clear_all_vines()
	_clear_bubble_globs()
	_remove_guard_row()

	if _magnifier_root != null and is_instance_valid(_magnifier_root):

		_magnifier_root.queue_free()

	_magnifier_root = null
	_magnifier_boss = null
	healthbar = null

	footprint_cells.clear()

	_virus_phase_count = 0


# ============================================================
# PROCESS
# ============================================================

func _process(_delta: float) -> void:

	if Engine.is_editor_hint():
		return

	if board == null or defeated or busy:
		return

	if current_phase == Phase.VINES:

		_process_vine_phase()

	else:

		_process_virus_phase()


func _process_vine_phase() -> void:

	var pill := board.current_pill

	if pill == null or not is_instance_valid(pill):
		return

	for v in active_vines:

		if v.state != 1:
			continue

		if _pill_intersects_vine(v):

			_on_pill_hit_by_vine()

			return


func _process_virus_phase() -> void:

	if not _phase_viruses_ready:
		return

	if board.virus_cells.is_empty():

		_end_virus_phase()


# ============================================================
# ANIM CLOCK TICK
# ============================================================

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

		var local_frame: int = (frame + offset) % 2

		sprite.region_rect = _bubble_region(
			pair,
			local_frame
		)

	if defeated or busy or current_phase != Phase.VINES:
		return

	var finished: Array = []

	for v in active_vines:

		v.advance_tick()

		if v.state == 2:

			finished.append(v)

	for v in finished:

		active_vines.erase(v)

		if is_instance_valid(v):
			v.queue_free()

	_maintain_vine_count()


# ============================================================
# VINE TIER / SPAWNING
# ============================================================

func _health_fraction() -> float:

	return (
		float(health) / float(MAX_HEALTH)
		if MAX_HEALTH > 0
		else 1.0
	)


func _vine_count_for_tier() -> int:

	var fraction := _health_fraction()

	if fraction > high_health_threshold:
		return high_health_vine_count

	if fraction > medium_health_threshold:
		return medium_health_vine_count

	return low_health_vine_count


func _virus_count_for_tier() -> int:

	var fraction := _health_fraction()

	if fraction > high_health_threshold:
		return high_health_virus_count

	if fraction > medium_health_threshold:
		return medium_health_virus_count

	return low_health_virus_count


func _maintain_vine_count() -> void:

	var target := _vine_count_for_tier()

	var guard := 0

	while active_vines.size() < target and guard < 20:

		guard += 1

		var candidate: Variant = _pick_valid_vine_spot()

		if candidate == null:
			break

		_spawn_vine_at(candidate)


func _pick_valid_vine_spot() -> Variant:

	for attempt in range(20):

		var edge: int = board.rng.randi_range(0, 3)

		var orientation: int = 0 if edge <= 1 else 1

		var index: int

		if orientation == 0:

			if horizontal_row_max < horizontal_row_min:
				return null

			index = board.rng.randi_range(
				horizontal_row_min,
				horizontal_row_max
			)

		else:

			index = _pick_vertical_column()

		if index < 0:
			continue

		var duplicate := false

		for v in active_vines:

			var v_orientation: int = 0 if v.edge <= 1 else 1

			if (
				v_orientation == orientation
				and v.fixed_index == index
			):

				duplicate = true

				break

		if duplicate:
			continue

		return Vector2i(edge, index)

	return null


func _pick_vertical_column() -> int:

	var options: Array[int] = []

	for c in range(DrRogueoBoard.BOARD_WIDTH):

		if (
			c >= OPENING_LEFT
			and c < OPENING_LEFT + OPENING_WIDTH
		):

			continue

		options.append(c)

	if options.is_empty():
		return -1

	return options[
		board.rng.randi_range(
			0,
			options.size() - 1
		)
	]


func _spawn_vine_at(candidate: Vector2i) -> void:

	var v := Vine.new()

	v.controller = self
	v.edge = candidate.x
	v.fixed_index = candidate.y
	v.tip_cell = Vine.compute_tip_cell(
		v.edge,
		v.fixed_index
	)

	v.z_index = VINE_Z_INDEX

	board.add_child(v)

	_place_at_boss_layer(v)

	active_vines.append(v)

	v.queue_redraw()


func _clear_all_vines() -> void:

	for v in active_vines:

		if is_instance_valid(v):
			v.queue_free()

	active_vines.clear()


func _pill_intersects_vine(v) -> bool:

	var pill := board.current_pill

	var cells := pill.get_occupied_cells(
		board.current_grid_position
	)

	for cell in cells:

		var check_cell := cell

		if board.has_pacman_trait():

			check_cell = board.wrap_cell_if_needed(cell)

		if v.cells.has(check_cell):

			return true

	return false


func _on_pill_hit_by_vine() -> void:

	if (
		board.current_pill != null
		and is_instance_valid(board.current_pill)
	):

		board.current_pill.queue_free()
		board.current_pill = null

	_clear_all_vines()

	_start_virus_phase()


# ============================================================
# VINE INNER CLASS
# ============================================================

class Vine extends Node2D:

	const ATTACK_TICKS := 2

	# vines.png is a 3x2 spritesheet:
	#
	# [UP TIP]    [DOWN TIP]   [VERTICAL REPEAT]
	# [RIGHT TIP] [LEFT TIP]   [HORIZONTAL REPEAT]
	#
	# Every sprite is 8x8.

	const TIP_UP := 0
	const TIP_DOWN := 1
	const VERTICAL_REPEAT := 2

	const TIP_RIGHT := 3
	const TIP_LEFT := 4
	const HORIZONTAL_REPEAT := 5

	var controller
	var edge: int = 0
	var fixed_index: int = 0
	var tip_cell: Vector2i = Vector2i.ZERO

	var state: int = 0
	# 0 = TELEGRAPH
	# 1 = ATTACKING
	# 2 = DONE

	var tick_count: int = 0

	# Complete attack path.
	var cells: Array = []

	# Number of cells currently visible during rapid growth.
	var visible_count: int = 0
	var grow_elapsed := 0.0

	var vine_texture: Texture2D


	static func compute_tip_cell(
		p_edge: int,
		p_fixed_index: int
	) -> Vector2i:

		match p_edge:

			0:
				return Vector2i(
					0,
					p_fixed_index
				)

			1:
				return Vector2i(
					DrRogueoBoard.BOARD_WIDTH - 1,
					p_fixed_index
				)

			2:
				return Vector2i(
					p_fixed_index,
					0
				)

			3:
				return Vector2i(
					p_fixed_index,
					DrRogueoBoard.BOARD_HEIGHT - 1
				)

		return Vector2i.ZERO


	func _ready() -> void:

		vine_texture = load(
			controller.vine_texture_path
		)

		z_index = Boss2Controller.VINE_Z_INDEX

		set_process(true)


	func _process(delta: float) -> void:

		if state != 1:
			return

		if visible_count >= cells.size():
			return

		grow_elapsed += delta

		var total_duration: float = (
			float(cells.size())
			/ maxf(
				controller.vine_extend_speed,
				0.01
			)
		)

		var progress: float = clamp(
			grow_elapsed / total_duration,
			0.0,
			1.0
		)

		visible_count = clampi(
			int(ceil(
				float(cells.size()) * progress
			)),
			1,
			cells.size()
		)

		queue_redraw()


	func _direction_vector() -> Vector2i:

		match edge:

			0:
				return Vector2i(1, 0)

			1:
				return Vector2i(-1, 0)

			2:
				return Vector2i(0, 1)

			3:
				return Vector2i(0, -1)

		return Vector2i.ZERO


	func _tip_frame() -> int:

		match edge:

			0:
				return TIP_RIGHT

			1:
				return TIP_LEFT

			2:
				return TIP_DOWN

			3:
				return TIP_UP

		return TIP_RIGHT


	func _repeat_frame() -> int:

		if edge <= 1:

			return HORIZONTAL_REPEAT

		return VERTICAL_REPEAT


	func advance_tick() -> void:

		tick_count += 1

		if state == 0:

			# Each warning flash occupies two clock ticks:
			# visible, invisible.
			#
			# Example:
			# 2 flashes = 4 ticks
			# 3 flashes = 6 ticks
			var telegraph_ticks: int = (
				controller.telegraph_flash_count * 2
			)

			if tick_count >= telegraph_ticks:

				_resolve_attack()

				state = 1
				tick_count = 0
				visible_count = 1
				grow_elapsed = 0.0

			queue_redraw()

		elif state == 1:

			if tick_count >= ATTACK_TICKS:

				state = 2

			queue_redraw()


	func _resolve_attack() -> void:

		cells.clear()

		var board_ref: DrRogueoBoard = controller.board

		var cell := tip_cell
		var dir := _direction_vector()

		while true:

			if (
				cell.x < 0
				or cell.x >= DrRogueoBoard.BOARD_WIDTH
			):

				break

			if (
				cell.y < 0
				or cell.y >= DrRogueoBoard.BOARD_HEIGHT
			):

				break

			# Bubbles deliberately do NOT block vines.
			#
			# Other boss maze cells still can.
			if (
				board_ref.boss_maze_cells.has(cell)
				and not controller.bubble_cells.has(cell)
			):

				break

			if board_ref.boss_blocked_cells.has(cell):
				break

			cells.append(cell)

			if board_ref.occupied_cells.has(cell):

				board_ref.crush_cell(cell)

			cell += dir


	func _draw() -> void:

		if vine_texture == null:
			return

		if state == 0:

			# Telegraph:
			# The starting tip flashes on odd ticks.
			if tick_count % 2 == 1:

				_draw_vine_sprite(
					tip_cell,
					_tip_frame()
				)

		elif state == 1:

			if cells.is_empty():
				return

			var count: int = mini(
				visible_count,
				cells.size()
			)

			if count <= 0:
				return

			# The vine grows from its starting edge toward
			# the far end. The directional tip is always at
			# the leading end of the visible vine.
			for i in range(count):

				var cell: Vector2i = cells[i]

				if i == count - 1:

					_draw_vine_sprite(
						cell,
						_tip_frame()
					)

				else:

					_draw_vine_sprite(
						cell,
						_repeat_frame()
					)


	func _draw_vine_sprite(
		cell: Vector2i,
		frame: int
	) -> void:

		var top_left: Vector2 = (
			controller.board.grid_to_local(cell)
		)

		var source_rect := Rect2(
			(frame % 3) * 8,
			(frame / 3) * 8,
			8,
			8
		)

		draw_texture_rect_region(
			vine_texture,
			Rect2(
				top_left,
				Vector2(
					DrRogueoBoard.CELL_SIZE,
					DrRogueoBoard.CELL_SIZE
				)
			),
			source_rect
		)


# ============================================================
# VIRUS PHASE
# ============================================================

func _start_virus_phase() -> void:

	current_phase = Phase.VIRUSES
	_phase_viruses_ready = false

	# Phase transition: remove any settled player pills.
	_clear_all_settled_pills()

	_clear_bubble_globs()

	# The first virus phase starts directly above the boss.
	# Every later virus phase moves the guard one row upward.
	_virus_phase_count += 1

	var desired_guard_row: int = (
		boss_row
		- _virus_phase_count
	)

	# Keep the guard inside the playable board and leave at
	# least the normal opening area available for viruses.
	guard_row = maxi(
		OPENING_TOP_HEIGHT + 1,
		desired_guard_row
	)

	_add_guard_row()

	busy = true

	await _spawn_phase_viruses()

	if (
		board != null
		and not board.transitioning_level
		and not board.game_over
		and not defeated
	):

		board.spawn_pill()

	busy = false


func _spawn_phase_viruses() -> void:

	var count := _virus_count_for_tier()

	var placed := 0
	var attempts := 0
	var max_attempts := count * 30

	while placed < count and attempts < max_attempts:

		attempts += 1

		# As guard_row rises, this area naturally shrinks.
		if guard_row - 1 < OPENING_TOP_HEIGHT:
			break

		var cell := Vector2i(
			board.rng.randi_range(
				0,
				DrRogueoBoard.BOARD_WIDTH - 1
			),
			board.rng.randi_range(
				OPENING_TOP_HEIGHT,
				guard_row - 1
			)
		)

		if board.is_cell_filled(cell):
			continue

		var color: int = board.random_pill_color()

		var virus: Virus = board.place_virus(
			cell,
			color
		)

		if virus == null:
			continue

		placed += 1

		await _animate_virus_spit(
			virus,
			cell
		)

		if placed < count:

			await board.get_tree().create_timer(
				VIRUS_PLACEMENT_INTERVAL,
				false
			).timeout

	_phase_viruses_ready = true


func _animate_virus_spit(
	virus: Virus,
	target_cell: Vector2i
) -> void:

	if virus == null or not is_instance_valid(virus):
		return

	# The real gameplay virus has already been created at its
	# final board cell. Hide it while a separate visual copy
	# travels from the boss.
	virus.visible = false

	if board.virus_scene == null:

		virus.visible = true

		return

	var flying_virus: Virus = (
		board.virus_scene.instantiate()
		as Virus
	)

	if flying_virus == null:

		virus.visible = true

		return

	# Give the flying visual the exact same color.
	flying_virus.virus_color = virus.virus_color
	flying_virus.visual_state = Virus.VisualState.NORMAL

	# Keep the projectile behind the boss sprite.
	flying_virus.z_index = BUBBLE_Z_INDEX

	board.add_child(flying_virus)

	# --------------------------------------------------------
	# THROW ORIGIN
	# --------------------------------------------------------
	#
	# Editable from the Inspector.
	# Default (8,8) is the centre of the 16x16 boss.
	#
	var boss_top_left := board.grid_to_local(
		Vector2i(
			boss_col,
			boss_row
		)
	)

	var start_position := (
		boss_top_left
		+ virus_throw_origin
	)

	var target_position := board.grid_to_local(
		target_cell
	)

	flying_virus.position = start_position

	# --------------------------------------------------------
	# THROW SPEED
	# --------------------------------------------------------
	#
	# The duration is based on distance, so every projectile
	# travels at the same approximate speed regardless of
	# where its target happens to be.
	#
	var distance: float = start_position.distance_to(
		target_position
	)

	var throw_speed: float = maxf(
		virus_throw_speed,
		1.0
	)

	var throw_duration: float = maxf(
		distance / throw_speed,
		0.05
	)

	# --------------------------------------------------------
	# ARC
	# --------------------------------------------------------

	var control_point := (
		start_position.lerp(
			target_position,
			0.5
		)
		+ Vector2(
			0.0,
			-virus_throw_arc_height
		)
	)

	var elapsed := 0.0

	while elapsed < throw_duration:

		await get_tree().process_frame

		if not is_instance_valid(flying_virus):

			if is_instance_valid(virus):
				virus.visible = true

			return

		if get_tree().paused:
			continue

		elapsed += get_process_delta_time()

		var t: float = clamp(
			elapsed / throw_duration,
			0.0,
			1.0
		)

		# Quadratic Bezier arc.
		var a := start_position.lerp(
			control_point,
			t
		)

		var b := control_point.lerp(
			target_position,
			t
		)

		var position := a.lerp(
			b,
			t
		)

		flying_virus.position = Vector2(
			floor(position.x),
			floor(position.y)
		)

	if not is_instance_valid(flying_virus):

		if is_instance_valid(virus):
			virus.visible = true

		return

	# Snap to the target.
	flying_virus.position = target_position

	# Let the projectile visually arrive before swapping to
	# the real gameplay virus.
	await get_tree().process_frame

	if is_instance_valid(flying_virus):
		flying_virus.queue_free()

	if is_instance_valid(virus):

		virus.position = target_position
		virus.visible = true


func _add_guard_row() -> void:

	guard_cells.clear()

	for col in range(DrRogueoBoard.BOARD_WIDTH):

		var cell := Vector2i(
			col,
			guard_row
		)

		guard_cells[cell] = true
		board.boss_maze_cells[cell] = true

	_guard_visual = GuardBar.new()
	_guard_visual.controller = self
	_guard_visual.z_index = VINE_Z_INDEX

	board.add_child(_guard_visual)

	_place_at_boss_layer(_guard_visual)

	_guard_visual.queue_redraw()


func _remove_guard_row() -> void:

	for cell in guard_cells.keys():

		if board != null:
			board.boss_maze_cells.erase(cell)

	guard_cells.clear()

	if (
		_guard_visual != null
		and is_instance_valid(_guard_visual)
	):

		_guard_visual.queue_free()

	_guard_visual = null


func _end_virus_phase() -> void:

	# Phase transition: clear any settled player pills before
	# rebuilding the VINES board.
	_clear_all_settled_pills()

	current_phase = Phase.VINES

	_remove_guard_row()

	await _spawn_bubble_globs()


# ============================================================
# GUARD VINE
# ============================================================

class GuardBar extends Node2D:

	var controller
	var vine_texture: Texture2D

	const TIP_LEFT := 4
	const TIP_RIGHT := 3
	const HORIZONTAL_REPEAT := 5


	func _ready() -> void:

		vine_texture = load(
			controller.vine_texture_path
		)

		z_index = Boss2Controller.VINE_Z_INDEX


	func _draw() -> void:

		if vine_texture == null:
			return

		var width := DrRogueoBoard.BOARD_WIDTH

		for col in range(width):

			var cell := Vector2i(
				col,
				controller.guard_row
			)

			var frame := HORIZONTAL_REPEAT

			if col == 0:

				frame = TIP_LEFT

			elif col == width - 1:

				frame = TIP_RIGHT

			var top_left: Vector2 = (
				controller.board.grid_to_local(cell)
			)

			var source_rect := Rect2(
				(frame % 3) * 8,
				(frame / 3) * 8,
				8,
				8
			)

			draw_texture_rect_region(
				vine_texture,
				Rect2(
					top_left,
					Vector2(
						DrRogueoBoard.CELL_SIZE,
						DrRogueoBoard.CELL_SIZE
					)
				),
				source_rect
			)


# ============================================================
# BOSS-LANDING DAMAGE (VINES PHASE ONLY)
# ============================================================

func try_handle_pill_landing(
	pill: Pill,
	grid_position: Vector2i
) -> bool:

	if defeated or busy or board == null:
		return false

	if current_phase != Phase.VINES:
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

	await _apply_boss_damage(HIT_DAMAGE)

	return true


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

		half_1.reparent(
			board,
			true
		)

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

		half_2.reparent(
			board,
			true
		)

		half_2.position = board.grid_to_local(
			half_2_cell
		)

		board.vanishing_halves[half_2] = (
			DrRogueoBoard.VANISH_DURATION
		)

	pill.queue_free()


func _apply_boss_damage(amount: int) -> void:

	health -= amount

	if healthbar != null:
		healthbar.set_health(health)

	if health <= 0:

		await _play_death()

		busy = false

		return

	await _full_clear_and_reroll()

	boss_sprite.frame = boss_anim_frame

	if _magnifier_boss != null:

		_magnifier_boss.position = magnifier_boss_position
		_magnifier_boss.frame = boss_anim_frame

	busy = false


func _full_clear_and_reroll() -> void:

	_clear_all_vines()
	_clear_bubble_globs()
	_clear_all_settled_pills()

	await _spawn_bubble_globs()


func _clear_all_settled_pills() -> void:

	if board == null:
		return

	for cell in board.occupied_cells.keys().duplicate():

		board.crush_cell(cell)


func _play_death() -> void:

	defeated = true

	var death_column := boss_anim_frame

	for row in range(2, 6):

		boss_sprite.frame = row * 2 + death_column

		await board.get_tree().create_timer(
			DEATH_FRAME_DURATION
		).timeout

	boss_sprite.visible = false

	_clear_all_vines()
	_clear_bubble_globs()
	_remove_guard_row()

	defeated_changed.emit(true)


# ============================================================
# BUBBLE GLOBS
# ============================================================

func _cell_is_glob_eligible(cell: Vector2i) -> bool:

	if cell.x < 0 or cell.x >= DrRogueoBoard.BOARD_WIDTH:
		return false

	if cell.y < 0 or cell.y >= DrRogueoBoard.BOARD_HEIGHT:
		return false

	if cell.y < OPENING_TOP_HEIGHT:
		return false

	if footprint_cells.has(cell):
		return false

	# Keep the 2x2 area directly above the boss permanently
	# clear so bubbles can never visually cover the boss's
	# launching/entrance area.
	if _is_boss_clear_cell(cell):
		return false

	if board.is_cell_filled(cell):
		return false

	return true


func _is_boss_clear_cell(cell: Vector2i) -> bool:

	# Boss footprint:
	#
	#   XX
	#   XX
	#
	# Always keep the 2x2 area immediately above it clear:
	#
	#   ..
	#   ..
	#   XX
	#   XX
	#
	if (
		cell.x >= boss_col
		and cell.x < boss_col + 2
		and cell.y >= boss_row - 2
		and cell.y < boss_row
	):

		return true

	return false


func _spawn_bubble_globs() -> void:

	_bubble_build_generation += 1

	var generation := _bubble_build_generation

	busy = true

	var placed_globs := 0
	var attempts := 0
	var max_attempts := GLOB_COUNT * 20

	var spawned_cells: Array[Vector2i] = []

	while (
		placed_globs < GLOB_COUNT
		and attempts < max_attempts
	):

		attempts += 1

		var anchor := Vector2i(
			board.rng.randi_range(
				0,
				DrRogueoBoard.BOARD_WIDTH - 1
			),
			board.rng.randi_range(
				OPENING_TOP_HEIGHT,
				boss_row - 2
			)
		)

		if not _cell_is_glob_eligible(anchor):
			continue

		var glob_cells: Array[Vector2i] = [anchor]

		var glob_size: int = board.rng.randi_range(
			GLOB_MIN_SIZE,
			GLOB_MAX_SIZE
		)

		var frontier: Array[Vector2i] = [anchor]

		while (
			glob_cells.size() < glob_size
			and not frontier.is_empty()
		):

			var base: Vector2i = frontier[
				board.rng.randi_range(
					0,
					frontier.size() - 1
				)
			]

			var offsets: Array[Vector2i] = [
				Vector2i(1, 0),
				Vector2i(-1, 0),
				Vector2i(0, 1),
				Vector2i(0, -1)
			]

			offsets.shuffle()

			var grew := false

			for offset in offsets:

				var next_cell: Vector2i = base + offset

				if glob_cells.has(next_cell):
					continue

				if not _cell_is_glob_eligible(next_cell):
					continue

				glob_cells.append(next_cell)
				frontier.append(next_cell)

				grew = true

				break

			if not grew:

				frontier.erase(base)

		for cell in glob_cells:

			_place_bubble(
				cell,
				false
			)

			spawned_cells.append(cell)

		placed_globs += 1

	# Build the bubble field visually from the bottom of the
	# board upward. Every occupied cell in a given row appears
	# together before moving to the next row.
	for row in range(
		DrRogueoBoard.BOARD_HEIGHT - 1,
		OPENING_TOP_HEIGHT - 1,
		-1
	):

		if generation != _bubble_build_generation:
			return

		var row_had_bubbles := false

		for cell in spawned_cells:

			if cell.y != row:
				continue

			var sprite: Sprite2D = bubble_cells.get(
				cell,
				null
			)

			if (
				sprite == null
				or not is_instance_valid(sprite)
			):

				continue

			sprite.visible = true
			row_had_bubbles = true

		if not row_had_bubbles:
			continue

		await board.get_tree().create_timer(
			GLOB_BUILD_ROW_INTERVAL,
			false
		).timeout

	if generation == _bubble_build_generation:

		busy = false


func _clear_bubble_globs() -> void:

	_bubble_build_generation += 1

	for cell in bubble_cells.keys():

		if board != null:
			board.boss_maze_cells.erase(cell)

		var sprite: Sprite2D = bubble_cells[cell]

		if is_instance_valid(sprite):
			sprite.queue_free()

	bubble_cells.clear()
	bubble_pair_type.clear()
	bubble_frame_offset.clear()


func _place_bubble(
	cell: Vector2i,
	start_visible: bool = true
) -> void:

	var sprite := Sprite2D.new()

	sprite.centered = false
	sprite.texture = load(
		bubble_texture_path
	)

	sprite.region_enabled = true
	sprite.position = board.grid_to_local(cell)
	sprite.visible = start_visible

	sprite.z_index = BUBBLE_Z_INDEX

	board.add_child(sprite)

	_place_at_boss_layer(sprite)

	var pair: int = board.rng.randi_range(
		0,
		1
	)

	var frame_offset: int = board.rng.randi_range(
		0,
		1
	)

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


func _bubble_region(
	pair: int,
	frame: int
) -> Rect2:

	var frame_index: int = (
		pair * 2
	) + frame

	return Rect2(
		frame_index * 8,
		0,
		8,
		8
	)


# ============================================================
# BOSS SPRITE / LAYER
# ============================================================

func _place_at_boss_layer(sprite: Node) -> void:

	if board == null:
		return

	var target_index: int = min(
		4,
		board.get_child_count() - 1
	)

	if target_index >= 0:

		board.move_child(
			sprite,
			target_index
		)


func _create_boss_sprite(
	p_boss_col: int,
	p_boss_row: int
) -> void:

	boss_sprite = Sprite2D.new()

	boss_sprite.name = "Boss2Sprite"
	boss_sprite.centered = false

	boss_sprite.texture = load(
		boss_texture_path
	)

	boss_sprite.hframes = 2
	boss_sprite.vframes = 6
	boss_sprite.frame = 0

	boss_sprite.position = board.grid_to_local(
		Vector2i(
			p_boss_col,
			p_boss_row
		)
	)

	boss_sprite.z_index = BOSS_Z_INDEX

	board.add_child(boss_sprite)

	_place_at_boss_layer(boss_sprite)


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
	_magnifier_root.name = "Boss2MagnifierDisplay"

	slot.add_child(_magnifier_root)

	var gradient := Sprite2D.new()

	gradient.name = "MagnifierGradient"
	gradient.centered = false

	gradient.texture = load(
		gradient_texture_path
	)

	gradient.position = magnifier_gradient_position

	_magnifier_root.add_child(gradient)

	_magnifier_boss = Sprite2D.new()

	_magnifier_boss.name = "MagnifierBoss"

	_magnifier_boss.texture = load(
		magnifier_boss_texture_path
	)

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

	_bubble_build_generation += 1

	if AnimClock.frame_changed.is_connected(
		_on_anim_frame_changed
	):

		AnimClock.frame_changed.disconnect(
			_on_anim_frame_changed
		)

	_clear_all_vines()
	_clear_bubble_globs()
	_remove_guard_row()

	if (
		_magnifier_root != null
		and is_instance_valid(_magnifier_root)
	):

		_magnifier_root.queue_free()
