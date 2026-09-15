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
#   grow across the board. Only a vine that is STILL actively
#   extending is lethal to the falling pill -- once a vine has
#   finished growing it becomes SOLID (the pill can land on top
#   of it and rest there safely). Bubbles do NOT block vines;
#   they only block player pills. Settled pill halves in the
#   vine's path ARE destroyed and the vine pierces straight
#   through them.
#   Landing a pill on the boss itself deals damage, fully clears
#   the board (settled pills + bubbles), and rerolls fresh globs.
#
#   Vines now RETRACT after their attack instead of disappearing.
#   The next wave's wait interval begins only after every vine
#   from the previous wave has completely retracted. A vine's
#   solid collision shrinks along with its retraction, so a pill
#   resting on top of one keeps falling as it pulls back.
#
#   VIRUSES -- triggered only by getting impaled by an
#   extending (still-growing) vine. A handful of normal viruses
#   are spat from the boss toward their landing cells while a
#   stack of horizontal guard vines blocks the lower board. Each
#   time the virus phase is entered, the FULL stack of guard
#   vines for however many times this has happened so far is
#   rebuilt -- one vine directly above the boss, another above
#   that, and so on -- alternating which side each layer extends
#   from. When every virus is cleared, the whole stack retracts
#   back the way each vine came before the fight returns to
#   VINES.
#
#   Two permanent bubble columns flank the boss's own 2x2
#   footprint (its full row-span, one column either side) in
#   BOTH phases, signalling that a pill can't be snuck in next
#   to the boss to score a hit. Normal bubble globs may occupy
#   the middle of the board, but each generated layout is
#   tested with a two-cell-wide pill before it is accepted, so
#   at least one complete route to the boss is always preserved.
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
var telegraph_flash_count: int = 3

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


@export_subgroup("Vine Attack Pacing")

@export_range(0.0, 10.0, 0.05)
var high_health_vine_interval: float = 0.5

@export_range(0.0, 10.0, 0.05)
var medium_health_vine_interval: float = 0.25

@export_range(0.0, 10.0, 0.05)
var low_health_vine_interval: float = 0.0


@export_subgroup("Vine Retraction")

@export_range(1.0, 200.0, 1.0)
var vine_retract_speed: float = 50.0


@export_subgroup("Virus Counts")

@export_range(1, 12, 1)
var high_health_virus_count: int = 4

@export_range(1, 12, 1)
var medium_health_virus_count: int = 6

@export_range(1, 12, 1)
var low_health_virus_count: int = 8


@export_subgroup("Guard Vine Stack")

# Maximum number of horizontal guard-vine layers that can
# exist during the virus phase, regardless of how many
# virus phases have occurred.
@export_range(1, 16, 1)
var max_guard_vine_layers: int = 7


@export_category("Virus Throw Tuning")

@export_range(10.0, 1000.0, 5.0)
var virus_throw_speed: float = 300.0

@export_range(0.0, 32.0, 0.5)
var virus_throw_arc_height: float = 16.0

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

var guard_row := 0

var horizontal_row_min := 0
var horizontal_row_max := 0

var footprint_cells: Dictionary = {}

var active_vines: Array = []

# Vine -> Array[Vector2i] currently registered as solid in
# board.boss_maze_cells. Kept so we can diff each frame and
# only touch the cells that actually changed.
var _vine_solid_cells: Dictionary = {}

var _vine_spawn_timer := 0.0
var _vine_waiting_for_next_wave := false
var _applying_vine_retraction_gravity := false

var bubble_cells: Dictionary = {}
var bubble_pair_type: Dictionary = {}
var bubble_frame_offset: Dictionary = {}

var _side_bubble_cells: Dictionary = {}

# One GuardVine per accumulated layer. Layer 0 sits directly
# above the boss (row boss_row - 1), layer 1 above that, etc.
# The whole stack is rebuilt every time the virus phase starts
# and retracted together when it ends.
var _guard_vines: Array = []
var guard_cells: Dictionary = {}

var _phase_viruses_ready := false

var boss_sprite: Sprite2D
var boss_anim_frame := 0

var healthbar: Boss1Healthbar

var _magnifier_root: Node2D
var _magnifier_boss: Sprite2D

var _bubble_build_generation := 0

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

	guard_row = boss_row - 1

	horizontal_row_min = OPENING_TOP_HEIGHT
	horizontal_row_max = boss_row - 2

	health = MAX_HEALTH
	defeated = false
	busy = false
	boss_anim_frame = 0
	current_phase = Phase.VINES
	_virus_phase_count = 0
	_vine_spawn_timer = 0.0
	_vine_waiting_for_next_wave = false

	footprint_cells.clear()

	for col in range(boss_col, boss_col + 2):

		for row in range(boss_row, boss_row + 2):

			footprint_cells[Vector2i(col, row)] = true

	_create_boss_sprite(boss_col, boss_row)

	if not AnimClock.frame_changed.is_connected(_on_anim_frame_changed):

		AnimClock.frame_changed.connect(_on_anim_frame_changed)

	_create_magnifier_display()

	_create_boss_side_bubbles()

	_spawn_bubble_globs()


func _reset_runtime_boss() -> void:

	_bubble_build_generation += 1

	if AnimClock.frame_changed.is_connected(_on_anim_frame_changed):

		AnimClock.frame_changed.disconnect(
			_on_anim_frame_changed
		)

	if boss_sprite != null and is_instance_valid(boss_sprite):

		boss_sprite.queue_free()

	boss_sprite = null

	_clear_all_vines()
	_clear_bubble_globs(true)
	_remove_guard_vine_immediate()

	_vine_solid_cells.clear()

	if _magnifier_root != null and is_instance_valid(_magnifier_root):

		_magnifier_root.queue_free()

	_magnifier_root = null
	_magnifier_boss = null
	healthbar = null

	footprint_cells.clear()

	_virus_phase_count = 0
	_vine_spawn_timer = 0.0
	_vine_waiting_for_next_wave = false


# ============================================================
# PROCESS
# ============================================================

func _process(delta: float) -> void:

	if Engine.is_editor_hint():
		return

	if board == null:
		return

	# Vine collision needs to stay accurate regardless of the
	# controller's busy state, since a Vine keeps animating its
	# own extend/retract on its own _process() either way.
	_update_vine_solid_cells()

	if defeated or busy:
		return

	if current_phase == Phase.VINES:

		_process_vine_phase(delta)

	else:

		_process_virus_phase()


func _process_vine_phase(delta: float) -> void:

	# Do not start another vine wave while the board is
	# resolving the gravity caused by the previous wave's
	# retraction.
	if _applying_vine_retraction_gravity:
		return

	var pill := board.current_pill

	if pill != null and is_instance_valid(pill):

		for v in active_vines:

			if not v.is_still_growing():
				continue

			if _pill_intersects_vine(v):

				_on_pill_hit_by_vine()

				return

	if not active_vines.is_empty():
		return

	if not _vine_waiting_for_next_wave:

		_spawn_vine_wave()

		if active_vines.is_empty():
			return

		_vine_waiting_for_next_wave = false

		return

	_vine_spawn_timer -= delta

	if _vine_spawn_timer > 0.0:
		return

	_spawn_vine_wave()

	if not active_vines.is_empty():

		_vine_waiting_for_next_wave = false


func _spawn_vine_wave() -> void:

	var wave_count := _vine_count_for_tier()

	if wave_count <= 0:
		return

	for i in range(wave_count):

		var candidate: Variant = _pick_valid_vine_spot()

		if candidate == null:
			continue

		_spawn_vine_at(candidate)


func _process_virus_phase() -> void:

	if not _phase_viruses_ready:
		return

	if board.virus_cells.is_empty():

		_end_virus_phase()


# ============================================================
# VINE COLLISION (SOLID GROUND ONCE FULLY EXTENDED)
# ============================================================
#
# Diffs every active vine's current solid-cell set against what
# was registered last frame, adding/removing cells from
# board.boss_maze_cells as needed. A cell that's also covered
# by a bubble is left alone either way -- it's already solid
# via the bubble, and we must never erase a bubble's own
# registration when a vine's solidity there goes away.
# ============================================================

func _update_vine_solid_cells() -> void:

	var still_active: Dictionary = {}

	for v in active_vines:

		if not is_instance_valid(v):
			continue

		still_active[v] = true

		var new_solid: Array = v.get_solid_cells()
		var old_solid: Array = _vine_solid_cells.get(v, [])

		if new_solid == old_solid:
			continue

		var new_set: Dictionary = {}

		for cell in new_solid:
			new_set[cell] = true

		for cell in old_solid:

			if new_set.has(cell):
				continue

			if bubble_cells.has(cell):
				continue

			board.boss_maze_cells.erase(cell)

		for cell in new_solid:

			if bubble_cells.has(cell):
				continue

			board.boss_maze_cells[cell] = true

		_vine_solid_cells[v] = new_solid

	for v in _vine_solid_cells.keys().duplicate():

		if still_active.has(v):
			continue

		var stale_solid: Array = _vine_solid_cells[v]

		for cell in stale_solid:

			if bubble_cells.has(cell):
				continue

			board.boss_maze_cells.erase(cell)

		_vine_solid_cells.erase(v)


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

	for v in active_vines:

		if not is_instance_valid(v):
			continue

		if v.state == 0 or v.state == 1:
			v.advance_tick()


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


func _vine_interval_for_tier() -> float:

	var fraction := _health_fraction()

	if fraction > high_health_threshold:
		return high_health_vine_interval

	if fraction > medium_health_threshold:
		return medium_health_vine_interval

	return low_health_vine_interval


func _virus_count_for_tier() -> int:

	var fraction := _health_fraction()

	if fraction > high_health_threshold:
		return high_health_virus_count

	if fraction > medium_health_threshold:
		return medium_health_virus_count

	return low_health_virus_count


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


func _on_vine_finished_retracting(v) -> void:

	if active_vines.has(v):

		active_vines.erase(v)

	if _vine_solid_cells.has(v):

		var stale_solid: Array = _vine_solid_cells[v]

		for cell in stale_solid:

			if board != null and not bubble_cells.has(cell):

				board.boss_maze_cells.erase(cell)

		_vine_solid_cells.erase(v)

	if is_instance_valid(v):

		v.queue_free()

	# The LAST vine to retract is the point at which all of
	# the temporary vine supports are gone. Now let the normal
	# board gravity system resolve anything that was resting
	# on those vines.
	if active_vines.is_empty():

		_vine_waiting_for_next_wave = true
		_vine_spawn_timer = _vine_interval_for_tier()

		_apply_gravity_after_vine_retraction()


func _apply_gravity_after_vine_retraction() -> void:

	if _applying_vine_retraction_gravity:
		return

	if board == null:
		return

	_applying_vine_retraction_gravity = true

	# Let all pills fall now that the vines are gone.
	await board.apply_gravity()

	_applying_vine_retraction_gravity = false

	# Check whether a settled pill has fallen directly onto the boss.
	await _check_settled_pill_touching_boss()


func _check_settled_pill_touching_boss() -> void:

	if defeated or busy:
		return

	if board == null:
		return

	if current_phase != Phase.VINES:
		return

	var checked_halves: Array[PillHalf] = []

	for cell in board.occupied_cells:

		var cell_position: Vector2i = cell

		# A pill touches the boss when its cell is directly
		# above one of the boss footprint cells.
		var cell_below: Vector2i = (
			cell_position + Vector2i(0, 1)
		)

		if not footprint_cells.has(cell_below):
			continue

		var half := (
			board.occupied_cells[cell_position]
			as PillHalf
		)

		if half == null:
			continue

		if checked_halves.has(half):
			continue

		checked_halves.append(half)

		var other_half: PillHalf = half.partner_half

		if other_half != null:
			checked_halves.append(other_half)

		# Find the actual board cells occupied by this pill.
		var half_1_cell: Vector2i = cell_position
		var half_2_cell: Vector2i = cell_position

		if other_half != null:

			for other_cell in board.occupied_cells:

				var other_occupied_half := (
					board.occupied_cells[other_cell]
					as PillHalf
				)

				if other_occupied_half == other_half:
					half_2_cell = other_cell
					break

		# The scoring helper expects the Pill node, but this pill
		# may no longer have the Pill node as its parent after settling.
		var pill: Pill = null

		if half.get_parent() is Pill:
			pill = half.get_parent() as Pill

		elif other_half != null and other_half.get_parent() is Pill:
			pill = other_half.get_parent() as Pill

		# If the Pill node still exists, use the normal scoring path.
		if pill != null:

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

			return

		# If the settled halves are no longer parented to a Pill,
		# handle the halves directly.
		busy = true

		_vanish_settled_boss_pill(
			half,
			other_half,
			half_1_cell,
			half_2_cell
		)

		boss_sprite.frame = 2 + boss_anim_frame

		await board.get_tree().create_timer(
			DAMAGE_FLASH_DURATION
		).timeout

		await board.wait_for_vanishing_halves()

		await _apply_boss_damage(HIT_DAMAGE)

		return


func _vanish_settled_boss_pill(
	half_1: PillHalf,
	half_2: PillHalf,
	half_1_cell: Vector2i,
	half_2_cell: Vector2i
) -> void:

	if half_1 != null:

		board.occupied_cells.erase(
			half_1_cell
		)

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

	if half_2 != null and half_2 != half_1:

		board.occupied_cells.erase(
			half_2_cell
		)

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


func _check_for_settled_pill_boss_landing() -> void:

	if board == null:
		return

	if defeated:
		return

	# The pill must have a half in the row immediately above
	# the boss, over one of the boss's two columns.
	#
	# This is the same physical scoring position used by
	# try_handle_pill_landing().
	var scoring_cells: Array[Vector2i] = []

	for col in range(
		boss_col,
		boss_col + 2
	):

		scoring_cells.append(
			Vector2i(
				col,
				boss_row - 1
			)
		)

	var checked_pills: Dictionary = {}

	for cell in scoring_cells:

		var half: PillHalf = board.occupied_cells.get(
			cell,
			null
		)

		if half == null:
			continue

		if not is_instance_valid(half):
			continue

		# Settled halves should belong to their Pill node.
		var pill := half.get_parent() as Pill

		if pill == null:
			continue

		if not is_instance_valid(pill):
			continue

		# A two-cell pill can touch the boss with either half,
		# so only process each Pill once.
		if checked_pills.has(pill):
			continue

		checked_pills[pill] = true

		var half_1_cell := Vector2i(-999, -999)
		var half_2_cell := Vector2i(-999, -999)

		# The Pill's actual settled position is represented by
		# its occupied cells, so locate both halves directly
		# from occupied_cells instead of assuming a particular
		# local transform.
		for occupied_cell in board.occupied_cells.keys():

			var occupied_half: PillHalf = (
				board.occupied_cells[occupied_cell]
			)

			if occupied_half == null:
				continue

			if not is_instance_valid(occupied_half):
				continue

			if occupied_half.get_parent() != pill:
				continue

			if occupied_half == pill.get_node_or_null("Half1"):
				half_1_cell = occupied_cell

			elif occupied_half == pill.get_node_or_null("Half2"):
				half_2_cell = occupied_cell

		var lands_on_boss := (
			footprint_cells.has(
				half_1_cell + Vector2i(0, 1)
			)
			or footprint_cells.has(
				half_2_cell + Vector2i(0, 1)
			)
		)

		if not lands_on_boss:
			continue

		busy = true

		_vanish_scoring_pill(
			pill,
			half_1_cell,
			half_2_cell
		)

		if boss_sprite != null:
			boss_sprite.frame = 2 + boss_anim_frame

		await board.get_tree().create_timer(
			DAMAGE_FLASH_DURATION
		).timeout

		await board.wait_for_vanishing_halves()

		await _apply_boss_damage(HIT_DAMAGE)

		return


func _clear_all_vines() -> void:

	for v in active_vines:

		if _vine_solid_cells.has(v):

			var stale_solid: Array = _vine_solid_cells[v]

			for cell in stale_solid:

				if board != null and not bubble_cells.has(cell):

					board.boss_maze_cells.erase(cell)

			_vine_solid_cells.erase(v)

		if is_instance_valid(v):
			v.queue_free()

	active_vines.clear()

	_vine_waiting_for_next_wave = false
	_vine_spawn_timer = 0.0


func _pill_intersects_vine(v) -> bool:

	var pill := board.current_pill

	var cells := pill.get_occupied_cells(
		board.current_grid_position
	)

	var visible_cells: Array = v.cells.slice(
		0,
		v.visible_count
	)

	for cell in cells:

		var check_cell := cell

		if board.has_pacman_trait():

			check_cell = board.wrap_cell_if_needed(cell)

		if visible_cells.has(check_cell):

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
	# 1 = ATTACKING / EXTENDING
	# 2 = RETRACTING
	# 3 = DONE

	var tick_count: int = 0

	var cells: Array = []

	var visible_count: int = 0

	var grow_elapsed := 0.0
	var retract_elapsed := 0.0

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


	func _duration() -> float:

		return (
			float(cells.size())
			/ maxf(controller.vine_extend_speed, 0.01)
		)


	func _retract_duration() -> float:

		return (
			float(cells.size())
			/ maxf(controller.vine_retract_speed, 0.01)
		)


	func start_retract() -> void:

		if state == 2 or state == 3:
			return

		state = 2
		retract_elapsed = 0.0

		visible_count = cells.size()

		queue_redraw()


	func _process(delta: float) -> void:

		if state == 1:

			if visible_count >= cells.size():
				return

			grow_elapsed += delta

			var total_duration: float = _duration()

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

			return


		if state == 2:

			if cells.is_empty():

				state = 3

				controller._on_vine_finished_retracting(self)

				return

			retract_elapsed += delta

			var total_duration: float = _retract_duration()

			var progress: float = clamp(
				retract_elapsed / total_duration,
				0.0,
				1.0
			)

			visible_count = clampi(
				cells.size()
				- int(ceil(
					float(cells.size()) * progress
				)),
				0,
				cells.size()
			)

			queue_redraw()

			if progress >= 1.0:

				state = 3
				visible_count = 0

				queue_redraw()

				controller._on_vine_finished_retracting(self)


	func is_still_growing() -> bool:

		return (
			state == 1
			and visible_count < cells.size()
		)


	# ========================================================
	# SOLID CELLS
	# ========================================================
	#
	# A vine is only lethal (impale-able) while it is actively
	# growing -- see is_still_growing(). Once it has finished
	# extending, it becomes solid ground: the falling pill can
	# rest on top of it instead of dying, and the collision
	# shrinks in step with its retraction so anything resting
	# on it keeps falling as it pulls back.
	# ========================================================

	func get_solid_cells() -> Array:

		if cells.is_empty():
			return []

		if state == 1 and visible_count >= cells.size():

			return cells.duplicate()

		if state == 2:

			return cells.slice(0, visible_count)

		return []


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

		if state == 0:

			var telegraph_ticks: int = (
				controller.telegraph_flash_count * 2
			)

			tick_count += 1

			if tick_count >= telegraph_ticks:

				_resolve_attack()

				state = 1
				tick_count = 0
				visible_count = 1
				grow_elapsed = 0.0

			queue_redraw()

		elif state == 1:

			tick_count += 1

			if tick_count >= ATTACK_TICKS:

				if visible_count >= cells.size():

					start_retract()

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

			if tick_count % 2 == 1:

				_draw_vine_sprite(
					tip_cell,
					_tip_frame()
				)

			return


		if state == 1 or state == 2:

			if cells.is_empty():
				return

			var count: int = mini(
				visible_count,
				cells.size()
			)

			if count <= 0:
				return

			for i in range(count):

				var cell: Vector2i = cells[i]

				if state == 1:

					# EXTENSION:
					# The leading tip is the far end of the
					# currently visible vine.
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

				else:

					# RETRACTION:
					#
					# IMPORTANT:
					# The tip remains at the LEADING/FAR END
					# of the visible vine, exactly as it did
					# during extension.
					#
					# The visible section simply gets shorter
					# from the far end back toward the wall.
					#
					# Right-origin example:
					#
					# <-------|
					#  <------|
					#   <-----|
					#    <----|
					#     <---|
					#      <--|
					#       <-|
					#        <|
					#
					# Left-origin is the mirror image.
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

	busy = true

	current_phase = Phase.VIRUSES
	_phase_viruses_ready = false

	_clear_all_settled_pills()

	_clear_bubble_globs()

	_virus_phase_count += 1

	await _spawn_guard_vine_stack()

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

	flying_virus.virus_color = virus.virus_color
	flying_virus.visual_state = Virus.VisualState.NORMAL

	flying_virus.z_index = BUBBLE_Z_INDEX

	board.add_child(flying_virus)

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

	flying_virus.position = target_position

	await get_tree().process_frame

	if is_instance_valid(flying_virus):
		flying_virus.queue_free()

	if is_instance_valid(virus):

		virus.position = target_position
		virus.visible = true


# ============================================================
# GUARD VINE STACK
# ============================================================
#
# Rebuilt from scratch every time the virus phase is entered.
# Layer 0 always sits directly above the boss (row
# boss_row - 1); each subsequent layer sits one row higher,
# alternating which side it extends from. All layers grow in
# sequentially, and the whole stack retracts together when the
# virus phase ends -- see _retract_and_remove_guard_vine().
# ============================================================

func _spawn_guard_vine_stack() -> void:

	guard_cells.clear()
	_guard_vines.clear()

	# Each virus phase normally adds one more guard-vine layer.
	# However, the stack has an inspector-controlled maximum
	# so it cannot grow indefinitely during a boss fight.
	var count: int = clampi(
		_virus_phase_count,
		1,
		max_guard_vine_layers
	)

	var topmost_row: int = maxi(
		boss_row - count,
		OPENING_TOP_HEIGHT + 1
	)

	guard_row = topmost_row

	for i in range(count):

		var row: int = maxi(
			boss_row - 1 - i,
			topmost_row
		)

		var side: int = i % 2

		var vine := GuardVine.new()

		vine.controller = self
		vine.row = row
		vine.side = side
		vine.z_index = VINE_Z_INDEX

		board.add_child(vine)

		_place_at_boss_layer(vine)

		_guard_vines.append(vine)

		for col in range(DrRogueoBoard.BOARD_WIDTH):

			var cell := Vector2i(col, row)

			guard_cells[cell] = true
			board.boss_maze_cells[cell] = true

		vine.start_extend()

		await vine.extension_finished


func _retract_and_remove_guard_vine() -> void:

	var vines_to_retract: Array = _guard_vines.duplicate()

	# Start every guard vine retracting at the same time.
	for vine in vines_to_retract:

		if vine != null and is_instance_valid(vine):

			vine.start_retract()

	# Wait until every vine has actually finished retracting.
	#
	# Do NOT await each retraction_finished signal individually.
	# A signal may have been emitted before we reach that await.
	while true:

		var any_retracting := false

		for vine in vines_to_retract:

			if vine != null and is_instance_valid(vine):

				if vine.retracting:

					any_retracting = true

					break

		if not any_retracting:
			break

		await get_tree().process_frame

	# Remove all guard-vine collision registrations.
	for cell in guard_cells.keys():

		if board != null:

			board.boss_maze_cells.erase(cell)

	guard_cells.clear()

	# Remove the visual vine nodes.
	for vine in vines_to_retract:

		if vine != null and is_instance_valid(vine):

			vine.queue_free()

	_guard_vines.clear()


func _remove_guard_vine_immediate() -> void:

	for cell in guard_cells.keys():

		if board != null:
			board.boss_maze_cells.erase(cell)

	guard_cells.clear()

	for vine in _guard_vines:

		if vine != null and is_instance_valid(vine):

			vine.queue_free()

	_guard_vines.clear()


# ============================================================
# GUARD VINE
# ============================================================

class GuardVine extends Node2D:

	signal extension_finished
	signal retraction_finished

	const TIP_LEFT := 4
	const TIP_RIGHT := 3
	const HORIZONTAL_REPEAT := 5

	var controller
	var row: int = 0
	var side: int = 0

	var vine_texture: Texture2D

	var total_cells: int = DrRogueoBoard.BOARD_WIDTH
	var visible_count: int = 0

	var growing := false
	var retracting := false
	var elapsed := 0.0


	func _ready() -> void:

		vine_texture = load(
			controller.vine_texture_path
		)

		z_index = Boss2Controller.VINE_Z_INDEX

		set_process(true)


	func _duration() -> float:

		return (
			float(total_cells)
			/ maxf(controller.vine_extend_speed, 0.01)
		)


	func start_extend() -> void:

		visible_count = 0
		elapsed = 0.0
		growing = true
		retracting = false

		queue_redraw()



	func start_retract() -> void:

		# Already fully retracted.
		if not growing and not retracting and visible_count <= 0:

			retraction_finished.emit()

			return

		visible_count = total_cells
		elapsed = 0.0
		retracting = true
		growing = false

		queue_redraw()


	func _process(delta: float) -> void:

		if growing:

			elapsed += delta

			var progress: float = clamp(
				elapsed / _duration(),
				0.0,
				1.0
			)

			visible_count = clampi(
				int(ceil(float(total_cells) * progress)),
				1,
				total_cells
			)

			queue_redraw()

			if progress >= 1.0:

				growing = false
				visible_count = total_cells

				extension_finished.emit()

		elif retracting:

			elapsed += delta

			var progress: float = clamp(
				elapsed / _duration(),
				0.0,
				1.0
			)

			visible_count = clampi(
				total_cells
				- int(floor(float(total_cells) * progress)),
				0,
				total_cells
			)

			queue_redraw()

			if progress >= 1.0:

				retracting = false
				visible_count = 0

				queue_redraw()

				retraction_finished.emit()


	func _draw() -> void:

		if vine_texture == null:
			return

		if visible_count <= 0:
			return

		if growing:

			for i in range(visible_count):

				var col: int = (
					i
					if side == 0
					else (total_cells - 1 - i)
				)

				var frame := HORIZONTAL_REPEAT

				if i == visible_count - 1:

					frame = (
						TIP_RIGHT
						if side == 0
						else TIP_LEFT
					)

				_draw_cell(col, frame)

			return


		# ----------------------------------------------------
		# RETRACTING
		# ----------------------------------------------------
		#
		# Same visual orientation as the extending vine.
		#
		# The visible vine is still ordered from its entry
		# edge toward its leading tip. As visible_count gets
		# smaller, the far/leading end moves back toward the
		# entry edge.
		#
		# RIGHT -> LEFT:
		#
		# <-------|
		#  <------|
		#   <-----|
		#    <----|
		#     <---|
		#      <--|
		#       <-|
		#        <|
		#
		# LEFT -> RIGHT is the mirror image.
		#
		# Therefore the tip remains at the FAR END of the
		# visible vine -- exactly the same rule as extension.
		# ----------------------------------------------------

		for i in range(visible_count):

			var col: int = (
				i
				if side == 0
				else (total_cells - 1 - i)
			)

			var frame := HORIZONTAL_REPEAT

			if i == visible_count - 1:

				frame = (
					TIP_RIGHT
					if side == 0
					else TIP_LEFT
				)

			_draw_cell(col, frame)


	func _draw_cell(
		col: int,
		frame: int
	) -> void:

		var cell := Vector2i(
			col,
			row
		)

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


func _end_virus_phase() -> void:

	busy = true

	_clear_all_settled_pills()

	current_phase = Phase.VINES

	await _retract_and_remove_guard_vine()

	# Rebuild the bubble cover for the normal vine phase.
	await _spawn_bubble_globs()

	# Explicitly release the boss controller.
	# This is intentionally here rather than relying only
	# on _spawn_bubble_globs() to reset it.
	busy = false


# ============================================================
# BOSS-LANDING DAMAGE
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
	_clear_bubble_globs(true)
	_remove_guard_vine_immediate()

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

	if _is_boss_clear_cell(cell):
		return false

	if board.is_cell_filled(cell):
		return false

	return true


func _is_boss_clear_cell(cell: Vector2i) -> bool:

	if (
		cell.x >= boss_col
		and cell.x < boss_col + 2
		and cell.y >= boss_row - 2
		and cell.y < boss_row
	):

		return true

	return false


# ============================================================
# PERMANENT SIDE BUBBLES
# ============================================================

func _create_boss_side_bubbles() -> void:

	var candidates: Array[Vector2i] = []

	for row in range(boss_row, boss_row + 2):

		for col in range(DrRogueoBoard.BOARD_WIDTH):

			# Skip the two cells occupied by the 2x2 boss.
			if col >= boss_col and col <= boss_col + 1:
				continue

			candidates.append(Vector2i(col, row))

	for cell in candidates:

		if cell.x < 0 or cell.x >= DrRogueoBoard.BOARD_WIDTH:
			continue

		if cell.y < 0 or cell.y >= DrRogueoBoard.BOARD_HEIGHT:
			continue

		if board.is_cell_filled(cell):
			continue

		_place_bubble(cell, true)

		_side_bubble_cells[cell] = true


func _spawn_bubble_globs() -> void:

	_bubble_build_generation += 1

	var generation := _bubble_build_generation

	busy = true

	var selected_globs: Array[Array] = []

	# --------------------------------------------------------
	# Build random glob layouts until one leaves a valid route
	# for the TWO-CELL-WIDE pill.
	# --------------------------------------------------------

	var layout_found := false

	const MAX_LAYOUT_ATTEMPTS := 200

	for layout_attempt in range(MAX_LAYOUT_ATTEMPTS):

		if generation != _bubble_build_generation:
			return

		var candidate_globs: Array[Array] = []

		var placed_globs := 0
		var attempts := 0
		var max_attempts := GLOB_COUNT * 20

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

			# Don't overlap another candidate glob.
			if _candidate_glob_contains(
				candidate_globs,
				anchor
			):

				continue

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

					var next_cell: Vector2i = (
						base + offset
					)

					if glob_cells.has(next_cell):
						continue

					if _candidate_glob_contains(
						candidate_globs,
						next_cell
					):

						continue

					if not _cell_is_glob_eligible(next_cell):
						continue

					glob_cells.append(next_cell)
					frontier.append(next_cell)

					grew = true

					break

				if not grew:

					frontier.erase(base)

			# Only accept a glob if we actually got a useful
			# connected group.
			if glob_cells.size() <= 0:
				continue

			candidate_globs.append(glob_cells)
			placed_globs += 1

		# We only want a full set of globs.
		if placed_globs < GLOB_COUNT:
			continue

		if _two_cell_pill_can_reach_boss(
			candidate_globs
		):

			selected_globs = candidate_globs
			layout_found = true

			break

	# --------------------------------------------------------
	# Extremely unlikely fallback.
	#
	# If random generation somehow fails 200 times, create
	# no globs rather than ever creating an unwinnable layout.
	# --------------------------------------------------------

	if not layout_found:

		selected_globs.clear()

	# --------------------------------------------------------
	# NOW actually place the chosen layout.
	#
	# Nothing was added to the board while we were testing,
	# so failed layouts never affect board collision.
	# --------------------------------------------------------

	var spawned_cells: Array[Vector2i] = []

	for glob in selected_globs:

		for cell in glob:

			_place_bubble(
				cell,
				false
			)

			spawned_cells.append(cell)

	# --------------------------------------------------------
	# Animate bubbles from bottom to top.
	# --------------------------------------------------------

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


func _candidate_glob_contains(
	globs: Array,
	cell: Vector2i
) -> bool:

	for glob in globs:

		if glob.has(cell):
			return true

	return false


func _two_cell_pill_can_reach_boss(
	globs: Array
) -> bool:

	var blocked: Dictionary = {}

	# --------------------------------------------------------
	# Existing board obstacles.
	#
	# These are included because the route needs to remain
	# usable in the actual board, not merely in an imaginary
	# empty board.
	# --------------------------------------------------------

	for cell in board.boss_maze_cells.keys():

		blocked[cell] = true

	# Candidate bubbles are not placed yet, so add them
	# manually to the temporary collision map.
	for glob in globs:

		for cell in glob:

			blocked[cell] = true

	# Settled pills also block movement.
	for cell in board.occupied_cells.keys():

		blocked[cell] = true

	# The boss itself is obviously not traversable.
	for cell in footprint_cells.keys():

		blocked[cell] = true

	# The cells immediately above the boss must remain usable
	# because that is where the pill reaches the boss.
	for cell in _boss_approach_cells():

		blocked.erase(cell)

	# --------------------------------------------------------
	# A state consists of:
	#
	#   x, y, orientation
	#
	# orientation 0 = horizontal pill
	# orientation 1 = vertical pill
	#
	# This is important: we are NOT checking whether a single
	# cell can squeeze through. The entire two-cell pill must
	# fit.
	# --------------------------------------------------------

	var queue: Array = []
	var visited: Dictionary = {}

	# Start with every possible two-cell pill position that
	# can exist immediately below the spawn opening.
	for state in _two_cell_pill_start_states(blocked):

		var key := _pill_route_state_key(state)

		if visited.has(key):
			continue

		visited[key] = true
		queue.append(state)

	# --------------------------------------------------------
	# BFS through all possible pill positions.
	#
	# Horizontal movement, vertical movement and rotation are
	# all represented as state changes.
	# --------------------------------------------------------

	var head := 0

	while head < queue.size():

		var state: Vector3i = queue[head]
		head += 1

		var anchor := Vector2i(
			state.x,
			state.y
		)

		var orientation := state.z

		var cells := _route_pill_cells(
			anchor,
			orientation
		)

		# Reaching a position immediately above the boss counts
		# as success. The actual landing code then handles the
		# final downward step onto the boss.
		if _pill_can_score_from_cells(cells):
			return true

		# ----------------------------------------------------
		# Four-directional movement.
		# ----------------------------------------------------

		var movement_offsets: Array[Vector2i] = [
			Vector2i(1, 0),
			Vector2i(-1, 0),
			Vector2i(0, 1),
			Vector2i(0, -1)
		]

		for offset in movement_offsets:

			var next_anchor := anchor + offset

			if not _route_pill_fits(
				next_anchor,
				orientation,
				blocked
			):

				continue

			var next_state := Vector3i(
				next_anchor.x,
				next_anchor.y,
				orientation
			)

			var next_key := _pill_route_state_key(
				next_state
			)

			if visited.has(next_key):
				continue

			visited[next_key] = true
			queue.append(next_state)

		# ----------------------------------------------------
		# Rotation.
		#
		# We allow both orientations as long as the resulting
		# two-cell pill fits.
		# ----------------------------------------------------

		var rotated_orientation := (
			1
			if orientation == 0
			else 0
		)

		if _route_pill_fits(
			anchor,
			rotated_orientation,
			blocked
		):

			var rotated_state := Vector3i(
				anchor.x,
				anchor.y,
				rotated_orientation
			)

			var rotated_key := _pill_route_state_key(
				rotated_state
			)

			if not visited.has(rotated_key):

				visited[rotated_key] = true
				queue.append(rotated_state)

	return false


func _boss_approach_cells() -> Array[Vector2i]:

	var result: Array[Vector2i] = []

	# A horizontal pill can enter across either of the two
	# cells directly above the boss.
	#
	# These are the cells:
	#
	#       [ ][ ]
	#       [B][B]
	#       [B][B]
	#
	# The pill needs to be able to occupy the row immediately
	# above the boss.
	for col in range(
		boss_col,
		boss_col + 2
	):

		var cell := Vector2i(
			col,
			boss_row - 1
		)

		if (
			cell.x >= 0
			and cell.x < DrRogueoBoard.BOARD_WIDTH
			and cell.y >= 0
			and cell.y < DrRogueoBoard.BOARD_HEIGHT
		):

			result.append(cell)

	return result


func _two_cell_pill_start_states(
	blocked: Dictionary
) -> Array[Vector3i]:

	var result: Array[Vector3i] = []

	# The pill enters through the normal two-column opening.
	#
	# We test several rows around the opening rather than
	# assuming one exact spawn coordinate, because the board's
	# actual spawn position can be slightly above the visible
	# playfield.

	var start_rows: Array[int] = [
		OPENING_TOP_HEIGHT - 1,
		OPENING_TOP_HEIGHT,
		OPENING_TOP_HEIGHT + 1
	]

	# Horizontal orientation.
	for row in start_rows:

		var horizontal_anchor := Vector2i(
			OPENING_LEFT,
			row
		)

		if _route_pill_fits(
			horizontal_anchor,
			0,
			blocked
		):

			result.append(
				Vector3i(
					horizontal_anchor.x,
					horizontal_anchor.y,
					0
				)
			)

	# Vertical orientation.
	#
	# The anchor is the first/upper cell of the pill.
	for row in start_rows:

		var vertical_anchor := Vector2i(
			OPENING_LEFT,
			row
		)

		if _route_pill_fits(
			vertical_anchor,
			1,
			blocked
		):

			result.append(
				Vector3i(
					vertical_anchor.x,
					vertical_anchor.y,
					1
				)
			)

	return result


func _route_pill_cells(
	anchor: Vector2i,
	orientation: int
) -> Array[Vector2i]:

	if orientation == 0:

		return [
			anchor,
			anchor + Vector2i(1, 0)
		]

	return [
		anchor,
		anchor + Vector2i(0, 1)
	]


func _route_pill_fits(
	anchor: Vector2i,
	orientation: int,
	blocked: Dictionary
) -> bool:

	var cells := _route_pill_cells(
		anchor,
		orientation
	)

	for cell in cells:

		# Allow the pill to exist in the spawn area above
		# the visible board.
		if cell.y < OPENING_TOP_HEIGHT:

			if (
				cell.x < 0
				or cell.x >= DrRogueoBoard.BOARD_WIDTH
			):

				return false

			continue

		if (
			cell.x < 0
			or cell.x >= DrRogueoBoard.BOARD_WIDTH
			or cell.y < 0
			or cell.y >= DrRogueoBoard.BOARD_HEIGHT
		):

			return false

		if blocked.has(cell):
			return false

	return true


func _pill_can_score_from_cells(
	cells: Array[Vector2i]
) -> bool:

	for cell in cells:

		# The pill is in the row immediately above the boss.
		if cell.y != boss_row - 1:
			continue

		if (
			cell.x >= boss_col
			and cell.x < boss_col + 2
		):

			return true

	return false


func _pill_route_state_key(
	state: Vector3i
) -> String:

	return "%d,%d,%d" % [
		state.x,
		state.y,
		state.z
	]


func _clear_bubble_globs(include_persistent: bool = false) -> void:

	_bubble_build_generation += 1

	var cells_to_remove: Array[Vector2i] = []

	for cell in bubble_cells.keys():

		if not include_persistent and _side_bubble_cells.has(cell):
			continue

		cells_to_remove.append(cell)

	for cell in cells_to_remove:

		if board != null:
			board.boss_maze_cells.erase(cell)

		var sprite: Sprite2D = bubble_cells[cell]

		if is_instance_valid(sprite):
			sprite.queue_free()

		bubble_cells.erase(cell)
		bubble_pair_type.erase(cell)
		bubble_frame_offset.erase(cell)

	if include_persistent:

		_side_bubble_cells.clear()


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
	_clear_bubble_globs(true)
	_remove_guard_vine_immediate()

	_vine_solid_cells.clear()

	if (
		_magnifier_root != null
		and is_instance_valid(_magnifier_root)
	):

		_magnifier_root.queue_free()
