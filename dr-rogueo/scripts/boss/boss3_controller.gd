class_name Boss3Controller
extends Node2D


# ============================================================
# BOSS 3 - MEDUSA (GAZE / PETRIFY)
# ============================================================
#
# Single repeating cycle:
#
#   WAITING    -- normal play, timer counting down to the next
#                 gaze attack.
#
#   TELEGRAPH  -- boss flashes a warning for
#                 telegraph_flash_count on/off flashes.
#                 Safe zones appear here and remain visible
#                 through the entire attack.
#
#   ATTACKING  -- boss and gaze switch to their attack frames.
#                 The current pill is petrified unless it has
#                 temporary Medusa protection.
#
# Safe zones provide the six unordered two-color combinations:
#
#   RR  YY  BB
#   RY  RB  YB
#
# A mixed-color combination does NOT care which color is first
# conceptually, but the actual pill halves MUST occupy the
# matching colored indicator cells.
#
# Example:
#
#   RED BLUE
#    R    B     = safe
#
#   RED BLUE
#    B    R     = NOT safe
#
# The player simply rotates the pill correctly.
#
# Safe-zone cells may overlap to form arbitrary shapes:
# L shapes, T shapes, zigzags, etc.
#
# Existing stone-damage behavior is intentionally preserved.
#
# ============================================================


signal defeated_changed(is_defeated: bool)


# ============================================================
# TUNING
# ============================================================

const MAX_HEALTH := 24

const DAMAGE_FLASH_DURATION := 0.45
const DEATH_FRAME_DURATION := 0.45

const MAGNIFIER_GROUP := "boss_magnifier_slot"


@export_group("Gaze Tuning")

# Number of warning flashes before the gaze attack resolves.
# Each flash is ON -> OFF.
@export_range(1, 10, 1)
var telegraph_flash_count: int = 3

@export_range(0, 30, 1)
var spawn_pause_last_flashes: int = 3

# How long the actual gaze attack remains visible.
@export_range(0.05, 2.0, 0.05)
var gaze_attack_duration: float = 2.00


@export_subgroup("Safe Zones")

# How long a pill remains protected after it leaves a valid
# safe-zone position.
@export_range(0.0, 5.0, 0.05)
var safe_zone_protection_duration: float = 0.75

# More attempts give the random generator more opportunities
# to find a compact layout that covers all six combinations.
@export_range(1, 30, 1)
var safe_zone_generation_attempts: int = 12


@export_subgroup("Health Thresholds")

@export_range(0.0, 1.0, 0.01)
var high_health_threshold: float = 0.66

@export_range(0.0, 1.0, 0.01)
var medium_health_threshold: float = 0.33


@export_subgroup("Attack Interval (seconds between gazes)")

@export_range(0.0, 30.0, 0.1)
var high_health_attack_interval: float = 8.0

@export_range(0.0, 30.0, 0.1)
var medium_health_attack_interval: float = 6.0

@export_range(0.0, 30.0, 0.1)
var low_health_attack_interval: float = 4.0


@export_group("Conveyor Tuning")

@export_range(0.02, 2.0, 0.01)
var conveyor_interval: float = 0.2


# ============================================================
# ASSETS
# ============================================================

@export_group("Textures")

@export var boss_texture_path: String = "res://art/viruses/boss_3.png"
@export var magnifier_boss_texture_path: String = "res://art/viruses/boss_3_magnifier.png"
@export var gradient_texture_path: String = "res://art/ui/magnifier_gradient.png"
@export var conveyor_texture_path: String = "res://art/board/conveyor.png"

# Boss1's three-color indicator sheet.
const SAFE_ZONE_TEXTURE_PATH := "res://art/board/boss_color_indicators.png"

const CONVEYOR_FRAME_SIZE := 8
const CONVEYOR_ANIMATION_FRAMES := 2

const SAFE_ZONE_FRAME_SIZE := 8


# Telegraph/attack gaze overlay.
#
# Sheet is 52x23:
#
#   column 0 = telegraph
#   column 1 = attack
#
@export var gaze_overlay_texture_path: String = "res://art/viruses/boss_3_attack.png"


# Boss sheet is 48x96:
#
#   3 columns x 6 rows
#
#   Column 0 = normal animation frame 0
#   Column 1 = normal animation frame 1
#   Column 2 = attack frame
#
const BOSS_FRAME_SIZE := Vector2i(16, 16)
const BOSS_SHEET_WIDTH := 48
const BOSS_SHEET_HEIGHT := 96

const BOSS_ATTACK_COLUMN := 2
const BOSS_ATTACK_ROW := 0


const GAZE_OVERLAY_FRAME_SIZE := Vector2i(26, 23)
const GAZE_OVERLAY_TELEGRAPH_FRAME := 0
const GAZE_OVERLAY_ATTACK_FRAME := 1


# ============================================================
# GHOST PROTECTION VISUAL
# ============================================================
#
# This deliberately uses the existing Ghost Pill outline art.
#
# ghost_pill.png:
#
#   vertical outline:
#       frame 0 = x16..24, y0..16
#       frame 1 = x24..32, y0..16
#
#   horizontal outline:
#       frame 0 = x16..32, y16..24
#       frame 1 = x16..32, y24..32
#
# ============================================================

const GHOST_OUTLINE_VERTICAL_FRAME_0 := Rect2(16, 0, 8, 16)
const GHOST_OUTLINE_VERTICAL_FRAME_1 := Rect2(24, 0, 8, 16)

const GHOST_OUTLINE_HORIZONTAL_FRAME_0 := Rect2(16, 16, 16, 8)
const GHOST_OUTLINE_HORIZONTAL_FRAME_1 := Rect2(16, 24, 16, 8)

const CELL_SIZE := 8


# ============================================================
# MAGNIFIER POSITIONS
# ============================================================

@export_group("Magnifier Positions")

@export var magnifier_gradient_position: Vector2 = Vector2.ZERO
@export var magnifier_boss_position: Vector2 = Vector2.ZERO
@export var magnifier_healthbar_position: Vector2 = Vector2.ZERO


# ============================================================
# GAZE OVERLAY POSITION
# ============================================================

@export_group("Gaze Overlay Position")

@export var gaze_overlay_position: Vector2 = Vector2i(-6, -8)
@export var gaze_overlay_scale: Vector2 = Vector2.ONE


# ============================================================
# STATE
# ============================================================

enum GazeState {
	WAITING,
	TELEGRAPH,
	ATTACKING
}


var board: DrRogueoBoard

var health := MAX_HEALTH
var defeated := false
var busy := false

var boss_col := 0
var boss_row := 0

var footprint_cells: Dictionary = {}

var gaze_state: int = GazeState.WAITING

var _wait_timer := 0.0
var _telegraph_tick_count := 0
var _attack_timer := 0.0

var boss_sprite: Sprite2D
var boss_anim_frame := 0

var gaze_overlay_sprite: Sprite2D

var healthbar: Boss1Healthbar

var _magnifier_root: Node2D
var _magnifier_boss: Sprite2D

var conveyor_sprites: Dictionary = {}


# ============================================================
# SAFE ZONE RUNTIME
# ============================================================

# cell -> PillHalf.PillColor
var safe_zone_colors: Dictionary = {}

# cell -> Sprite2D
var safe_zone_sprites: Dictionary = {}

# The current pill that owns the temporary protection.
var _protected_pill: Pill = null

# Remaining protection time.
var _safe_zone_protection_timer: float = 0.0

# White Ghost-style outline drawn over the protected pill.
var _protection_visual: Sprite2D = null


# ============================================================
# SAFE-ZONE GENERATION CACHE
# ============================================================
#
# These values depend only on the current board state.
# They do NOT change while a single safe-zone layout is being
# generated, so calculate them once instead of rescanning the
# board for every candidate.
#
var _safe_zone_hard_blocked_cache: Dictionary = {}
var _safe_zone_occupancy_cost_cache: Dictionary = {}
var _safe_zone_reachability_cache: Dictionary = {}
var _safe_zone_open_space_ratio_cache: float = 0.0


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

	health = MAX_HEALTH
	defeated = false
	busy = false
	boss_anim_frame = 0

	gaze_state = GazeState.WAITING
	_wait_timer = _attack_interval_for_tier()
	_telegraph_tick_count = 0
	_attack_timer = 0.0

	footprint_cells.clear()

	for col in range(boss_col, boss_col + 2):

		for row in range(boss_row, boss_row + 2):

			footprint_cells[Vector2i(col, row)] = true

	_create_boss_sprite()
	_create_gaze_overlay_sprite()
	_create_magnifier_display()

	if not AnimClock.frame_changed.is_connected(
		_on_anim_frame_changed
	):

		AnimClock.frame_changed.connect(
			_on_anim_frame_changed
	)

	# Conveyors run for the entire fight.
	board.conveyor_columns = [
		0,
		DrRogueoBoard.BOARD_WIDTH - 1
	]

	board.conveyor_interval = conveyor_interval

	_create_conveyor_visuals()


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

	if gaze_overlay_sprite != null and is_instance_valid(
		gaze_overlay_sprite
	):

		gaze_overlay_sprite.queue_free()

	gaze_overlay_sprite = null

	if (
		_magnifier_root != null
		and is_instance_valid(_magnifier_root)
	):

		_magnifier_root.queue_free()

	_magnifier_root = null
	_magnifier_boss = null
	healthbar = null

	footprint_cells.clear()

	if board != null:
		board.conveyor_columns = []

	_clear_conveyor_visuals()
	_clear_safe_zones()
	_clear_safe_zone_generation_cache()

	_protected_pill = null
	_safe_zone_protection_timer = 0.0

	if _protection_visual != null and is_instance_valid(
		_protection_visual
	):

		_protection_visual.queue_free()

	_protection_visual = null


# ============================================================
# CONVEYOR VISUALS
# ============================================================

func _create_conveyor_visuals() -> void:

	_clear_conveyor_visuals()

	if board == null:
		return

	if not ResourceLoader.exists(conveyor_texture_path):

		push_warning(
			"Boss3Controller: conveyor texture not found: %s"
			% conveyor_texture_path
		)

		return

	var texture: Texture2D = load(conveyor_texture_path)

	for column in board.conveyor_columns:

		for row in range(DrRogueoBoard.BOARD_HEIGHT):

			var cell := Vector2i(column, row)

			var sprite := Sprite2D.new()

			sprite.name = "Boss3Conveyor_%d_%d" % [
				column,
				row
			]

			sprite.texture = texture
			sprite.centered = false
			sprite.region_enabled = true

			sprite.region_rect = Rect2(
				0,
				0,
				CONVEYOR_FRAME_SIZE,
				CONVEYOR_FRAME_SIZE
			)

			sprite.position = board.grid_to_local(cell)

			# Conveyors should remain behind board pieces.
			sprite.z_index = 0

			board.add_child(sprite)

			conveyor_sprites[cell] = sprite

	_update_conveyor_visuals(0)


func _update_conveyor_visuals(frame: int) -> void:

	var conveyor_frame: int = (
		frame % CONVEYOR_ANIMATION_FRAMES
	)

	var source_x: int = (
		conveyor_frame * CONVEYOR_FRAME_SIZE
	)

	for sprite_variant in conveyor_sprites.values():

		var sprite: Sprite2D = (
			sprite_variant as Sprite2D
		)

		if sprite == null or not is_instance_valid(sprite):
			continue

		sprite.region_rect = Rect2(
			source_x,
			0,
			CONVEYOR_FRAME_SIZE,
			CONVEYOR_FRAME_SIZE
		)


func _clear_conveyor_visuals() -> void:

	for sprite_variant in conveyor_sprites.values():

		var sprite: Sprite2D = (
			sprite_variant as Sprite2D
		)

		if sprite != null and is_instance_valid(sprite):
			sprite.queue_free()

	conveyor_sprites.clear()


# ============================================================
# PROCESS
# ============================================================

func _process(delta: float) -> void:

	if Engine.is_editor_hint():
		return

	if board == null:
		return

	if defeated or busy:
		return

	_update_safe_zone_protection(delta)

	match gaze_state:

		GazeState.WAITING:

			_process_waiting(delta)

		GazeState.TELEGRAPH:

			# Telegraph timing is driven by AnimClock.
			pass

		GazeState.ATTACKING:

			_process_attacking(delta)


func _process_waiting(delta: float) -> void:

	_wait_timer -= delta

	if _wait_timer > 0.0:
		return

	_start_telegraph()


func _process_attacking(delta: float) -> void:

	_attack_timer -= delta

	if _attack_timer > 0.0:
		return

	if gaze_overlay_sprite != null:
		gaze_overlay_sprite.visible = false

	gaze_state = GazeState.WAITING
	_wait_timer = _attack_interval_for_tier()

	_set_boss_sprite_frame()

	# Safe zones only exist for the telegraph + attack.
	_clear_safe_zones()

	if board != null:

		board.boss_attack_pause = false

		if board.boss_attack_spawn_pending:

			board.boss_attack_spawn_pending = false
			board.spawn_pill()


func _start_telegraph() -> void:

	gaze_state = GazeState.TELEGRAPH
	_telegraph_tick_count = 0

	_spawn_safe_zones()

	if gaze_overlay_sprite != null:

		gaze_overlay_sprite.frame = (
			GAZE_OVERLAY_TELEGRAPH_FRAME
		)

		gaze_overlay_sprite.visible = true


func _on_anim_frame_changed(frame: int) -> void:

	_update_conveyor_visuals(frame)

	boss_anim_frame = frame

	if not busy:

		# Do not allow the normal animation clock to overwrite
		# Medusa's attack pose while ATTACKING.
		if (
			boss_sprite != null
			and gaze_state != GazeState.ATTACKING
		):

			_set_boss_sprite_frame()

		if _magnifier_boss != null:

			_magnifier_boss.frame = frame
			_magnifier_boss.position = (
				magnifier_boss_position
			)

	# --------------------------------------------------------
	# Safe-zone flashing / attack visibility
	# --------------------------------------------------------

	if gaze_state == GazeState.TELEGRAPH:

		_set_safe_zone_visibility(frame == 0)

	elif gaze_state == GazeState.ATTACKING:

		_set_safe_zone_visibility(true)

	if defeated or busy:
		return

	if gaze_state != GazeState.TELEGRAPH:
		return

	_telegraph_tick_count += 1

	if gaze_overlay_sprite != null:

		gaze_overlay_sprite.frame = (
			GAZE_OVERLAY_TELEGRAPH_FRAME
		)

		gaze_overlay_sprite.visible = (
			frame == 0
		)

	# --------------------------------------------------------
	# Pause new pill spawning during the final
	# configurable number of telegraph flashes.
	# --------------------------------------------------------

	var pause_flashes: int = clamp(
		spawn_pause_last_flashes,
		0,
		telegraph_flash_count
	)

	var pause_ticks: int = pause_flashes * 2

	if board != null:

		if pause_ticks > 0:

			var telegraph_ticks: int = (
				telegraph_flash_count * 2
			)

			var pause_start_tick: int = (
				telegraph_ticks - pause_ticks
			)

			board.boss_attack_pause = (
				_telegraph_tick_count > pause_start_tick
			)

		else:

			board.boss_attack_pause = false

	var telegraph_ticks: int = (
		telegraph_flash_count * 2
	)

	if _telegraph_tick_count >= telegraph_ticks:

		_resolve_gaze_attack()


# ============================================================
# GAZE ATTACK RESOLUTION
# ============================================================

func _resolve_gaze_attack() -> void:

	gaze_state = GazeState.ATTACKING
	_attack_timer = gaze_attack_duration

	if board != null:
		board.boss_attack_pause = true

	if boss_sprite != null:
		_set_boss_attack_frame()

	if gaze_overlay_sprite != null:

		gaze_overlay_sprite.frame = (
			GAZE_OVERLAY_ATTACK_FRAME
		)

		gaze_overlay_sprite.visible = true

	# The safe zones deliberately remain visible here.
	# They are cleared when the attack duration finishes.

	var freshly_stoned_cells: Dictionary = {}

	if not _current_pill_is_protected():

		freshly_stoned_cells = (
			_cells_current_pill_would_occupy()
		)

		board.petrify_current_pill()

	var settled_stoned_cells: Dictionary = (
		board.petrify_settled_pills()
	)

	for cell in settled_stoned_cells:

		freshly_stoned_cells[cell] = true

	# EXISTING stone damage remains exactly where it was.
	#
	# Newly petrified cells are excluded by
	# freshly_stoned_cells.
	board.chip_damage_existing_stone(
		freshly_stoned_cells
	)

	board.apply_gravity()


func _cells_current_pill_would_occupy() -> Dictionary:

	var result: Dictionary = {}

	if board.current_pill == null:
		return result

	for cell in board.current_pill.get_occupied_cells(
		board.current_grid_position
	):

		var check_cell: Vector2i = cell

		if board.has_pacman_trait():

			check_cell = (
				board.wrap_cell_if_needed(cell)
			)

		result[check_cell] = true

	return result


# ============================================================
# SAFE-ZONE PROTECTION
# ============================================================

func _current_pill_is_protected() -> bool:

	if board == null:
		return false

	_refresh_pill_protection_from_position()

	return (
		_safe_zone_protection_timer > 0.0
		and _protected_pill == board.current_pill
	)


func _update_safe_zone_protection(
	delta: float
) -> void:

	if board == null:
		return

	var current_pill: Pill = board.current_pill

	# Protection belongs to the specific pill. If Board has
	# spawned a new pill, never transfer the old shield.
	if current_pill != _protected_pill:

		_protected_pill = current_pill
		_safe_zone_protection_timer = 0.0

	if _safe_zone_protection_timer > 0.0:

		_safe_zone_protection_timer = maxf(
			0.0,
			_safe_zone_protection_timer - delta
		)

	if (
		current_pill != null
		and (
			gaze_state == GazeState.TELEGRAPH
			or gaze_state == GazeState.ATTACKING
		)
	):

		_refresh_pill_protection_from_position()

	# The visual is always evaluated from the same timer that
	# determines whether the pill is actually protected.
	#
	# This means the outline remains visible for the entire
	# protection window and disappears exactly when protection
	# expires.
	_update_protection_visual()


func _refresh_pill_protection_from_position() -> void:

	if board == null:
		return

	var pill: Pill = board.current_pill

	if pill == null:
		return

	if pill != _protected_pill:
		return

	if _pill_currently_overlaps_matching_safe_zone():

		_safe_zone_protection_timer = (
			safe_zone_protection_duration
		)


func _pill_currently_overlaps_matching_safe_zone() -> bool:

	if board == null:
		return false

	var pill: Pill = board.current_pill

	if pill == null:
		return false

	var half_1_cell: Vector2i = (
		pill.get_half_1_cell(
			board.current_grid_position
		)
	)

	var half_2_cell: Vector2i = (
		pill.get_half_2_cell(
			board.current_grid_position
		)
	)

	if board.has_pacman_trait():

		half_1_cell = (
			board.wrap_cell_if_needed(
				half_1_cell
			)
		)

		half_2_cell = (
			board.wrap_cell_if_needed(
				half_2_cell
			)
		)

	if not safe_zone_colors.has(half_1_cell):
		return false

	if not safe_zone_colors.has(half_2_cell):
		return false

	var half_1_color: int = (
		pill.half_1_color
	)

	var half_2_color: int = (
		pill.half_2_color
	)

	var safe_1_color: int = (
		safe_zone_colors[half_1_cell]
	)

	var safe_2_color: int = (
		safe_zone_colors[half_2_cell]
	)

	# THIS is the important directional part:
	#
	# Half 1 must be on the matching Half-1 color cell.
	# Half 2 must be on the matching Half-2 color cell.
	#
	# Therefore R/B over R/B is safe,
	# while B/R over R/B is not.
	return (
		half_1_color == safe_1_color
		and half_2_color == safe_2_color
	)


# ============================================================
# PROTECTION VISUAL
# ============================================================

func _update_protection_visual() -> void:

	if board == null:
		return

	var pill: Pill = board.current_pill

	var should_show: bool = (
		pill != null
		and pill == _protected_pill
		and _safe_zone_protection_timer > 0.0
	)

	if not should_show:

		if (
			_protection_visual != null
			and is_instance_valid(_protection_visual)
		):

			_protection_visual.visible = false

		return

	if pill.ghost_sprite_texture == null:
		return

	if _protection_visual == null:

		_protection_visual = Sprite2D.new()

		_protection_visual.name = (
			"MedusaProtectionOutline"
		)

		_protection_visual.centered = false
		_protection_visual.region_enabled = true

		pill.add_child(_protection_visual)

	elif _protection_visual.get_parent() != pill:

		_protection_visual.reparent(pill)

	_protection_visual.texture = (
		pill.ghost_sprite_texture
	)

	var horizontal: bool = (
		pill.orientation == Pill.Orientation.RIGHT
		or pill.orientation == Pill.Orientation.LEFT
	)

	if horizontal:

		_protection_visual.region_rect = (
			GHOST_OUTLINE_HORIZONTAL_FRAME_1
			if AnimClock.frame == 1
			else GHOST_OUTLINE_HORIZONTAL_FRAME_0
		)

		_protection_visual.position = Vector2(
			0,
			0
		)

	else:

		_protection_visual.region_rect = (
			GHOST_OUTLINE_VERTICAL_FRAME_1
			if AnimClock.frame == 1
			else GHOST_OUTLINE_VERTICAL_FRAME_0
		)

		_protection_visual.position = Vector2(
			0,
			-CELL_SIZE
		)

	_protection_visual.visible = true

	# Keep the protection outline on top of the pill's own
	# visual children.
	pill.move_child(
		_protection_visual,
		pill.get_child_count() - 1
	)


# ============================================================
# SAFE-ZONE GENERATION
# ============================================================

func _spawn_safe_zones() -> void:

	_clear_safe_zones()
	_clear_safe_zone_generation_cache()

	if board == null:
		return

	# --------------------------------------------------------
	# Cache the board analysis ONCE.
	#
	# This is the important performance fix. The old generator
	# repeatedly scanned the entire 8x16 board while evaluating
	# every possible candidate for every combination.
	# --------------------------------------------------------

	_build_safe_zone_generation_cache()

	var best_layout: Dictionary = {}
	var best_score: float = INF

	for _attempt in range(
		safe_zone_generation_attempts
	):

		var attempt_layout: Dictionary = {}
		var attempt_score: float = 0.0

		safe_zone_colors.clear()

		var combinations: Array[Vector2i] = (
			_safe_zone_combinations()
		)

		combinations.shuffle()

		var success: bool = true

		for combination in combinations:

			var required_a: int = combination.x
			var required_b: int = combination.y

			# Another placement may already have produced this
			# combination through an overlapping shape.
			if _safe_zone_has_combination(
				required_a,
				required_b
			):

				continue

			var candidate: Dictionary = (
				_choose_safe_zone_candidate(
					required_a,
					required_b
				)
			)

			if candidate.is_empty():

				success = false
				break

			var cell_a: Vector2i = (
				candidate["cell_a"]
			)

			var cell_b: Vector2i = (
				candidate["cell_b"]
			)

			var color_a: int = (
				candidate["color_a"]
			)

			var color_b: int = (
				candidate["color_b"]
			)

			safe_zone_colors[cell_a] = color_a
			safe_zone_colors[cell_b] = color_b

			attempt_score += float(
				candidate["score"]
			)

		if not success:
			continue

		if not _safe_zone_covers_all_combinations():
			continue

		attempt_layout = (
			safe_zone_colors.duplicate()
		)

		if (
			best_layout.is_empty()
			or attempt_score < best_score
		):

			best_layout = attempt_layout
			best_score = attempt_score

	# Restore the best layout found.
	safe_zone_colors.clear()

	for cell in best_layout.keys():

		var color: int = best_layout[cell]

		safe_zone_colors[cell] = color

	_create_safe_zone_sprites()


func _safe_zone_combinations() -> Array[Vector2i]:

	return [
		Vector2i(
			PillHalf.PillColor.RED,
			PillHalf.PillColor.RED
		),

		Vector2i(
			PillHalf.PillColor.YELLOW,
			PillHalf.PillColor.YELLOW
		),

		Vector2i(
			PillHalf.PillColor.BLUE,
			PillHalf.PillColor.BLUE
		),

		Vector2i(
			PillHalf.PillColor.RED,
			PillHalf.PillColor.YELLOW
		),

		Vector2i(
			PillHalf.PillColor.RED,
			PillHalf.PillColor.BLUE
		),

		Vector2i(
			PillHalf.PillColor.YELLOW,
			PillHalf.PillColor.BLUE
		)
	]


func _build_safe_zone_generation_cache() -> void:

	_safe_zone_hard_blocked_cache.clear()
	_safe_zone_occupancy_cost_cache.clear()
	_safe_zone_reachability_cache.clear()

	var usable_cells: int = 0
	var open_cells: int = 0

	# --------------------------------------------------------
	# First pass:
	# hard blockers + occupancy cost
	# --------------------------------------------------------

	for row in range(DrRogueoBoard.BOARD_HEIGHT):

		for col in range(DrRogueoBoard.BOARD_WIDTH):

			var cell := Vector2i(
				col,
				row
			)

			var hard_blocked: bool = false

			# Safe zones should never occupy the top row.
			if cell.y == 0:

				hard_blocked = true

			elif footprint_cells.has(cell):

				hard_blocked = true

			elif board.conveyor_columns.has(cell.x):

				hard_blocked = true

			elif board.is_cell_filled(cell):

				# The current falling pill deliberately does
				# not count as a blocker because it isn't in
				# occupied_cells.
				if not board.occupied_cells.has(cell):

					hard_blocked = true

			_safe_zone_hard_blocked_cache[cell] = (
				hard_blocked
			)

			if hard_blocked:

				_safe_zone_occupancy_cost_cache[cell] = 0.0
				continue

			usable_cells += 1

			if not board.occupied_cells.has(cell):

				open_cells += 1

				_safe_zone_occupancy_cost_cache[cell] = 0.0
				continue

			var half: PillHalf = (
				board.occupied_cells[cell]
				as PillHalf
			)

			if (
				half != null
				and (
					half.is_stone
					or half.is_turning_to_stone
				)
			):

				_safe_zone_occupancy_cost_cache[cell] = 500.0

			else:

				_safe_zone_occupancy_cost_cache[cell] = 35.0

	# --------------------------------------------------------
	# Open-space ratio only needs to be calculated once.
	# --------------------------------------------------------

	if usable_cells <= 0:

		_safe_zone_open_space_ratio_cache = 0.0

	else:

		_safe_zone_open_space_ratio_cache = (
			float(open_cells)
			/ float(usable_cells)
		)

	# --------------------------------------------------------
	# Second pass:
	# reachability from above.
	#
	# Calculate from top to bottom so each cell can use the
	# already-known state of every cell above it.
	# --------------------------------------------------------

	for col in range(DrRogueoBoard.BOARD_WIDTH):

		for row in range(DrRogueoBoard.BOARD_HEIGHT):

			var cell := Vector2i(
				col,
				row
			)

			if _safe_zone_hard_blocked_cache.get(
				cell,
				false
			):

				_safe_zone_reachability_cache[cell] = 0.0
				continue

			if row <= 0:

				_safe_zone_reachability_cache[cell] = 1.0
				continue

			var score: float = 0.0
			var checked: int = 0

			for above_row in range(row):

				var above := Vector2i(
					col,
					above_row
				)

				checked += 1

				if _safe_zone_hard_blocked_cache.get(
					above,
					false
				):

					continue

				if board.occupied_cells.has(above):

					var half: PillHalf = (
						board.occupied_cells[above]
						as PillHalf
					)

					if (
						half != null
						and (
							half.is_stone
							or half.is_turning_to_stone
						)
					):

						continue

					score += 0.35

				else:

					score += 1.0

			if checked <= 0:

				_safe_zone_reachability_cache[cell] = 1.0

			else:

				_safe_zone_reachability_cache[cell] = (
					score / float(checked)
				)


func _choose_safe_zone_candidate(
	required_a: int,
	required_b: int
) -> Dictionary:

	var best_candidate: Dictionary = {}
	var best_score: float = INF

	var open_ratio: float = (
		_safe_zone_open_space_ratio()
	)

	var spread_weight: float = lerpf(
		1.0,
		8.0,
		clampf(open_ratio, 0.0, 1.0)
	)

	var directions: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(0, 1)
	]

	for row in range(DrRogueoBoard.BOARD_HEIGHT):

		for col in range(DrRogueoBoard.BOARD_WIDTH):

			var cell_a := Vector2i(
				col,
				row
			)

			for direction in directions:

				var cell_b: Vector2i = (
					cell_a + direction
				)

				if not _safe_zone_pair_in_bounds(
					cell_a,
					cell_b
				):

					continue

				# Same-color combos have only one useful
				# assignment. Mixed combos may be assigned either
				# way around the pair.
				var assignments: Array[Vector2i] = []

				assignments.append(
					Vector2i(
						required_a,
						required_b
					)
				)

				if required_a != required_b:

					assignments.append(
						Vector2i(
							required_b,
							required_a
						)
					)

				for assignment in assignments:

					var color_a: int = assignment.x
					var color_b: int = assignment.y

					if not _safe_zone_pair_colors_compatible(
						cell_a,
						cell_b,
						color_a,
						color_b
					):

						continue

					var score: float = (
						_safe_zone_pair_occupancy_cost(
							cell_a,
							cell_b
						)
					)

					var new_cell_count: int = 0

					if not safe_zone_colors.has(cell_a):
						new_cell_count += 1

					if not safe_zone_colors.has(cell_b):
						new_cell_count += 1

					# Compact overlap becomes more attractive as
					# space gets tight.
					score += (
						float(new_cell_count) * 2.0
					)

					var spread_distance: float = (
						_safe_zone_pair_spread_distance(
							cell_a,
							cell_b
						)
					)

					score -= (
						spread_distance
						* spread_weight
					)

					var reachability: float = (
						(
							_safe_zone_cell_reachability(
								cell_a
							)
							+
							_safe_zone_cell_reachability(
								cell_b
							)
						)
						* 0.5
					)

					# Prefer cells with clearer routes down from
					# the top of the board.
					score -= reachability * 18.0

					# Small random component keeps repeated attacks
					# from producing the exact same arrangement
					# when the board state is similar.
					score += board.rng.randf() * 1.5

					if score < best_score:

						best_score = score

						best_candidate = {
							"cell_a": cell_a,
							"cell_b": cell_b,
							"color_a": color_a,
							"color_b": color_b,
							"score": score
						}

	return best_candidate


func _safe_zone_pair_in_bounds(
	cell_a: Vector2i,
	cell_b: Vector2i
) -> bool:

	if (
		cell_a.x < 0
		or cell_a.x >= DrRogueoBoard.BOARD_WIDTH
		or cell_a.y < 0
		or cell_a.y >= DrRogueoBoard.BOARD_HEIGHT
	):

		return false

	if (
		cell_b.x < 0
		or cell_b.x >= DrRogueoBoard.BOARD_WIDTH
		or cell_b.y < 0
		or cell_b.y >= DrRogueoBoard.BOARD_HEIGHT
	):

		return false

	return true


func _safe_zone_pair_colors_compatible(
	cell_a: Vector2i,
	cell_b: Vector2i,
	color_a: int,
	color_b: int
) -> bool:

	if _safe_zone_cell_hard_blocked(cell_a):
		return false

	if _safe_zone_cell_hard_blocked(cell_b):
		return false

	if (
		safe_zone_colors.has(cell_a)
		and int(safe_zone_colors[cell_a]) != color_a
	):

		return false

	if (
		safe_zone_colors.has(cell_b)
		and int(safe_zone_colors[cell_b]) != color_b
	):

		return false

	return true


func _safe_zone_cell_hard_blocked(
	cell: Vector2i
) -> bool:

	if _safe_zone_hard_blocked_cache.has(cell):

		return bool(
			_safe_zone_hard_blocked_cache[cell]
		)

	# Fallback for safety if this gets called before the cache
	# is built.
	if footprint_cells.has(cell):
		return true

	if board.conveyor_columns.has(cell.x):
		return true

	if board.is_cell_filled(cell):

		if not board.occupied_cells.has(cell):
			return true

	return false


func _safe_zone_pair_occupancy_cost(
	cell_a: Vector2i,
	cell_b: Vector2i
) -> float:

	return (
		_safe_zone_cell_occupancy_cost(cell_a)
		+
		_safe_zone_cell_occupancy_cost(cell_b)
	)


func _safe_zone_cell_occupancy_cost(
	cell: Vector2i
) -> float:

	if _safe_zone_occupancy_cost_cache.has(cell):

		return float(
			_safe_zone_occupancy_cost_cache[cell]
		)

	# Fallback for safety if this gets called before the cache
	# is built.
	if not board.occupied_cells.has(cell):
		return 0.0

	var half: PillHalf = (
		board.occupied_cells[cell]
		as PillHalf
	)

	if (
		half != null
		and (
			half.is_stone
			or half.is_turning_to_stone
		)
	):

		return 500.0

	return 35.0


func _safe_zone_open_space_ratio() -> float:

	return _safe_zone_open_space_ratio_cache


func _safe_zone_pair_spread_distance(
	cell_a: Vector2i,
	cell_b: Vector2i
) -> float:

	if safe_zone_colors.is_empty():
		return 0.0

	var minimum_distance: int = 999999

	for existing_cell_variant in safe_zone_colors.keys():

		var existing_cell: Vector2i = (
			existing_cell_variant
		)

		var distance_a: int = (
			abs(cell_a.x - existing_cell.x)
			+ abs(cell_a.y - existing_cell.y)
		)

		var distance_b: int = (
			abs(cell_b.x - existing_cell.x)
			+ abs(cell_b.y - existing_cell.y)
		)

		minimum_distance = mini(
			minimum_distance,
			mini(
				distance_a,
				distance_b
			)
		)

	return float(minimum_distance)


func _safe_zone_cell_reachability(
	cell: Vector2i
) -> float:

	if _safe_zone_reachability_cache.has(cell):

		return float(
			_safe_zone_reachability_cache[cell]
		)

	# Fallback for safety if this gets called before the cache
	# is built.
	if cell.y <= 0:
		return 1.0

	var score: float = 0.0
	var checked: int = 0

	for row in range(cell.y):

		var above := Vector2i(
			cell.x,
			row
		)

		checked += 1

		if _safe_zone_cell_hard_blocked(above):
			continue

		if board.occupied_cells.has(above):

			var half: PillHalf = (
				board.occupied_cells[above]
				as PillHalf
			)

			if (
				half != null
				and (
					half.is_stone
					or half.is_turning_to_stone
				)
			):

				continue

			score += 0.35

		else:

			score += 1.0

	if checked <= 0:
		return 1.0

	return score / float(checked)


func _safe_zone_has_combination(
	color_a: int,
	color_b: int
) -> bool:

	var wanted_low: int = mini(
		color_a,
		color_b
	)

	var wanted_high: int = maxi(
		color_a,
		color_b
	)

	for cell_variant in safe_zone_colors.keys():

		var cell: Vector2i = cell_variant

		var right := Vector2i(
			cell.x + 1,
			cell.y
		)

		var down := Vector2i(
			cell.x,
			cell.y + 1
		)

		for neighbor in [right, down]:

			if not safe_zone_colors.has(neighbor):
				continue

			var first_color: int = (
				safe_zone_colors[cell]
			)

			var second_color: int = (
				safe_zone_colors[neighbor]
			)

			var low: int = mini(
				first_color,
				second_color
			)

			var high: int = maxi(
				first_color,
				second_color
			)

			if (
				low == wanted_low
				and high == wanted_high
			):

				return true

	return false


func _safe_zone_covers_all_combinations() -> bool:

	for combination in _safe_zone_combinations():

		if not _safe_zone_has_combination(
			combination.x,
			combination.y
		):

			return false

	return true


# ============================================================
# SAFE-ZONE SPRITES
# ============================================================

func _create_safe_zone_sprites() -> void:

	_clear_safe_zone_sprites_only()

	if board == null:
		return

	if not ResourceLoader.exists(
		SAFE_ZONE_TEXTURE_PATH
	):

		push_warning(
			"Boss3Controller: safe-zone texture not found: %s"
			% SAFE_ZONE_TEXTURE_PATH
		)

		return

	var texture: Texture2D = load(
		SAFE_ZONE_TEXTURE_PATH
	)

	for cell_variant in safe_zone_colors.keys():

		var cell: Vector2i = cell_variant
		var color: int = (
			safe_zone_colors[cell]
		)

		var sprite := Sprite2D.new()

		sprite.name = (
			"Boss3SafeZone_%d_%d"
			% [cell.x, cell.y]
		)

		sprite.centered = false
		sprite.texture = texture
		sprite.region_enabled = true

		sprite.region_rect = Rect2(
			color * SAFE_ZONE_FRAME_SIZE,
			0,
			SAFE_ZONE_FRAME_SIZE,
			SAFE_ZONE_FRAME_SIZE
		)

		sprite.position = board.grid_to_local(cell)

		# Safe-zone indicators should sit behind the falling
		# pill, but above the conveyor art.
		sprite.z_index = 2

		board.add_child(sprite)

		safe_zone_sprites[cell] = sprite

	_set_safe_zone_visibility(
		AnimClock.frame == 0
	)


func _set_safe_zone_visibility(
	visible: bool
) -> void:

	for sprite_variant in safe_zone_sprites.values():

		var sprite: Sprite2D = (
			sprite_variant as Sprite2D
		)

		if (
			sprite != null
			and is_instance_valid(sprite)
		):

			sprite.visible = visible


func _clear_safe_zone_sprites_only() -> void:

	for sprite_variant in safe_zone_sprites.values():

		var sprite: Sprite2D = (
			sprite_variant as Sprite2D
		)

		if (
			sprite != null
			and is_instance_valid(sprite)
		):

			sprite.queue_free()

	safe_zone_sprites.clear()


func _clear_safe_zones() -> void:

	_clear_safe_zone_sprites_only()
	safe_zone_colors.clear()


func _clear_safe_zone_generation_cache() -> void:

	_safe_zone_hard_blocked_cache.clear()
	_safe_zone_occupancy_cost_cache.clear()
	_safe_zone_reachability_cache.clear()
	_safe_zone_open_space_ratio_cache = 0.0


# ============================================================
# HEALTH TIER HELPERS
# ============================================================

func _health_fraction() -> float:

	return (
		float(health) / float(MAX_HEALTH)
		if MAX_HEALTH > 0
		else 1.0
	)


func _attack_interval_for_tier() -> float:

	var fraction: float = _health_fraction()

	if fraction > high_health_threshold:
		return high_health_attack_interval

	if fraction > medium_health_threshold:
		return medium_health_attack_interval

	return low_health_attack_interval


# ============================================================
# BOSS SPRITE / OVERLAY / LAYER
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


func _create_boss_sprite() -> void:

	boss_sprite = Sprite2D.new()

	boss_sprite.name = "Boss3Sprite"
	boss_sprite.centered = false

	if ResourceLoader.exists(
		boss_texture_path
	):

		boss_sprite.texture = load(
			boss_texture_path
		)

	boss_sprite.region_enabled = true

	boss_sprite.region_rect = Rect2(
		0,
		0,
		BOSS_SHEET_WIDTH,
		BOSS_SHEET_HEIGHT
	)

	boss_sprite.position = board.grid_to_local(
		Vector2i(
			boss_col,
			boss_row
		)
	)

	boss_sprite.z_index = 30

	board.add_child(boss_sprite)
	_place_at_boss_layer(boss_sprite)

	_set_boss_sprite_frame()


func _set_boss_sprite_frame() -> void:

	if boss_sprite == null:
		return

	var damage_tier: int = clampi(
		(
			(MAX_HEALTH - health)
			* 3
			/ maxi(MAX_HEALTH, 1)
		),
		0,
		2
	)

	var anim_column: int = (
		0
		if boss_anim_frame == 0
		else 1
	)

	var source_x: int = (
		anim_column * BOSS_FRAME_SIZE.x
	)

	var source_y: int = (
		damage_tier * BOSS_FRAME_SIZE.y
	)

	boss_sprite.region_rect = Rect2(
		source_x,
		source_y,
		BOSS_FRAME_SIZE.x,
		BOSS_FRAME_SIZE.y
	)


func _set_boss_attack_frame() -> void:

	if boss_sprite == null:
		return

	boss_sprite.region_rect = Rect2(
		BOSS_ATTACK_COLUMN * BOSS_FRAME_SIZE.x,
		BOSS_ATTACK_ROW * BOSS_FRAME_SIZE.y,
		BOSS_FRAME_SIZE.x,
		BOSS_FRAME_SIZE.y
	)


func _create_gaze_overlay_sprite() -> void:

	gaze_overlay_sprite = Sprite2D.new()

	gaze_overlay_sprite.name = (
		"MedusaGazeOverlay"
	)

	gaze_overlay_sprite.centered = false
	gaze_overlay_sprite.visible = false

	if ResourceLoader.exists(
		gaze_overlay_texture_path
	):

		gaze_overlay_sprite.texture = load(
			gaze_overlay_texture_path
		)

	gaze_overlay_sprite.hframes = 2
	gaze_overlay_sprite.vframes = 1

	gaze_overlay_sprite.frame = (
		GAZE_OVERLAY_TELEGRAPH_FRAME
	)

	gaze_overlay_sprite.position = (
		gaze_overlay_position
	)

	gaze_overlay_sprite.scale = (
		gaze_overlay_scale
	)

	# The overlay is a child of the boss, so it follows Medusa.
	boss_sprite.add_child(
		gaze_overlay_sprite
	)

	gaze_overlay_sprite.z_index = 1


# ============================================================
# DAMAGE / DEATH
# ============================================================

func take_direct_damage(
	amount: int = 1
) -> void:

	if defeated or board == null or busy:
		return

	busy = true

	if boss_sprite != null:

		_set_boss_sprite_frame()

	await board.get_tree().create_timer(
		DAMAGE_FLASH_DURATION
	).timeout

	health -= amount

	if healthbar != null:
		healthbar.set_health(health)

	if health <= 0:

		await _play_death()

		busy = false

		return

	if boss_sprite != null:
		_set_boss_sprite_frame()

	if _magnifier_boss != null:

		_magnifier_boss.position = (
			magnifier_boss_position
		)

		_magnifier_boss.frame = (
			boss_anim_frame
		)

	busy = false


func _play_death() -> void:

	defeated = true

	var death_column: int = (
		boss_anim_frame
	)

	for row in range(2, 6):

		var source_x: int = (
			death_column * BOSS_FRAME_SIZE.x
		)

		var source_y: int = (
			row * BOSS_FRAME_SIZE.y
		)

		if boss_sprite != null:

			boss_sprite.region_rect = Rect2(
				source_x,
				source_y,
				BOSS_FRAME_SIZE.x,
				BOSS_FRAME_SIZE.y
			)

		await board.get_tree().create_timer(
			DEATH_FRAME_DURATION
		).timeout

	if boss_sprite != null:
		boss_sprite.visible = false

	if gaze_overlay_sprite != null:
		gaze_overlay_sprite.visible = false

	_clear_safe_zones()

	board.conveyor_columns = []
	_clear_conveyor_visuals()

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
			"Boss3Controller: no node in group '%s'."
			% MAGNIFIER_GROUP
		)

		return

	_magnifier_root = Node2D.new()
	_magnifier_root.name = (
		"Boss3MagnifierDisplay"
	)

	slot.add_child(_magnifier_root)

	var gradient := Sprite2D.new()

	gradient.name = "MagnifierGradient"
	gradient.centered = false

	if ResourceLoader.exists(
		gradient_texture_path
	):

		gradient.texture = load(
			gradient_texture_path
		)

	gradient.position = (
		magnifier_gradient_position
	)

	_magnifier_root.add_child(gradient)

	_magnifier_boss = Sprite2D.new()

	_magnifier_boss.name = "MagnifierBoss"

	if ResourceLoader.exists(
		magnifier_boss_texture_path
	):

		_magnifier_boss.texture = load(
			magnifier_boss_texture_path
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

	healthbar.name = "Boss3Healthbar"
	healthbar.max_health = MAX_HEALTH
	healthbar.position = (
		magnifier_healthbar_position
	)

	_magnifier_root.add_child(
		healthbar
	)

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

	if board != null:
		board.conveyor_columns = []

	_clear_conveyor_visuals()
	_clear_safe_zones()

	if (
		_protection_visual != null
		and is_instance_valid(_protection_visual)
	):

		_protection_visual.queue_free()

	_protection_visual = null

	if (
		_magnifier_root != null
		and is_instance_valid(_magnifier_root)
	):

		_magnifier_root.queue_free()
