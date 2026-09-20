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
#   TELEGRAPH  -- boss flashes a warning for
#                 telegraph_flash_count on/off flashes (same
#                 AnimClock-tick pattern as Boss2's Vine).
#                 Safe zones (step 3b) appear at the start of
#                 this state and persist through ATTACKING.
#   ATTACKING  -- boss and gaze switch to their attack frames.
#                 The gaze resolves: if the current falling
#                 pill is NOT protected (step 3b), it is turned
#                 to stone in place (Board.petrify_current_pill())
#                 and a new pill spawns immediately. Regardless
#                 of whether the pill was hit, every EXISTING
#                 stone half on the board takes 1 chip of damage
#                 (Board.chip_damage_existing_stone()) as a
#                 built-in pressure-release valve, per design.
#                 The attack visuals remain visible for
#                 gaze_attack_duration, then the cycle returns
#                 to WAITING.
#
# Same 2x2 footprint/placement convention as Boss1/Boss2. Health/
# damage also follows the same MAX_HEALTH/HIT_DAMAGE pattern --
# Medusa is damaged only by bombs (step 3c), not by
# color-matching or landing a pill on her.
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
# Each flash is ON -> OFF, so 3 = ON/OFF/ON/OFF/ON/OFF/ATTACK.
@export_range(1, 10, 1)
var telegraph_flash_count: int = 3

# How long the actual gaze attack remains visible.
@export_range(0.05, 2.0, 0.05)
var gaze_attack_duration: float = 2.00


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

const CONVEYOR_FRAME_SIZE := 8
const CONVEYOR_ANIMATION_FRAMES := 2


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
# The attack frame is the TOP cell of column 2.
#
const BOSS_FRAME_SIZE := Vector2i(16, 16)
const BOSS_SHEET_WIDTH := 48
const BOSS_SHEET_HEIGHT := 96

const BOSS_ATTACK_COLUMN := 2
const BOSS_ATTACK_ROW := 0


const GAZE_OVERLAY_FRAME_SIZE := Vector2i(26, 23)
const GAZE_OVERLAY_TELEGRAPH_FRAME := 0
const GAZE_OVERLAY_ATTACK_FRAME := 1


@export_group("Magnifier Positions")

@export var magnifier_gradient_position: Vector2 = Vector2.ZERO
@export var magnifier_boss_position: Vector2 = Vector2.ZERO
@export var magnifier_healthbar_position: Vector2 = Vector2.ZERO


@export_group("Gaze Overlay Position")
#
# The overlay is bigger than the 2x2 boss footprint, so its
# position is independently adjustable relative to the boss.
#
# The overlay is a child of boss_sprite, so this is NOT
# grid/cell-based positioning.

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

	if not AnimClock.frame_changed.is_connected(_on_anim_frame_changed):

		AnimClock.frame_changed.connect(_on_anim_frame_changed)

	# Conveyors run for the entire fight.
	board.conveyor_columns = [0, DrRogueoBoard.BOARD_WIDTH - 1]
	board.conveyor_interval = conveyor_interval
	_create_conveyor_visuals()


func _reset_runtime_boss() -> void:

	if AnimClock.frame_changed.is_connected(_on_anim_frame_changed):

		AnimClock.frame_changed.disconnect(_on_anim_frame_changed)

	if boss_sprite != null and is_instance_valid(boss_sprite):
		boss_sprite.queue_free()

	boss_sprite = null

	if gaze_overlay_sprite != null and is_instance_valid(gaze_overlay_sprite):
		gaze_overlay_sprite.queue_free()

	gaze_overlay_sprite = null

	if _magnifier_root != null and is_instance_valid(_magnifier_root):
		_magnifier_root.queue_free()

	_magnifier_root = null
	_magnifier_boss = null
	healthbar = null

	footprint_cells.clear()

	if board != null:
		board.conveyor_columns = []

	_clear_conveyor_visuals()


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

			sprite.name = "Boss3Conveyor_%d_%d" % [column, row]
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
			sprite.z_index = 0

			board.add_child(sprite)

			conveyor_sprites[cell] = sprite

	_update_conveyor_visuals(0)


func _update_conveyor_visuals(frame: int) -> void:

	var conveyor_frame: int = frame % CONVEYOR_ANIMATION_FRAMES
	var source_x: int = conveyor_frame * CONVEYOR_FRAME_SIZE

	for sprite_variant in conveyor_sprites.values():

		var sprite := sprite_variant as Sprite2D

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

		var sprite := sprite_variant as Sprite2D

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

		gaze_overlay_sprite.frame = GAZE_OVERLAY_TELEGRAPH_FRAME
		gaze_overlay_sprite.visible = true


func _on_anim_frame_changed(frame: int) -> void:

	_update_conveyor_visuals(frame)

	boss_anim_frame = frame

	if not busy:

		# Do not allow the normal animation clock to overwrite
		# Medusa's attack pose while ATTACKING.
		if boss_sprite != null and gaze_state != GazeState.ATTACKING:
			_set_boss_sprite_frame()

		if _magnifier_boss != null:

			_magnifier_boss.frame = frame
			_magnifier_boss.position = magnifier_boss_position

	if defeated or busy:
		return

	if gaze_state != GazeState.TELEGRAPH:
		return

	_telegraph_tick_count += 1

	if gaze_overlay_sprite != null:

		gaze_overlay_sprite.frame = GAZE_OVERLAY_TELEGRAPH_FRAME
		gaze_overlay_sprite.visible = (frame == 0)

	var telegraph_ticks: int = telegraph_flash_count * 2

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
		gaze_overlay_sprite.frame = GAZE_OVERLAY_ATTACK_FRAME
		gaze_overlay_sprite.visible = true

	var freshly_stoned_cells: Dictionary = {}

	if not _current_pill_is_protected():
		freshly_stoned_cells = _cells_current_pill_would_occupy()
		board.petrify_current_pill()

	var settled_stoned_cells: Dictionary = board.petrify_settled_pills()

	for cell in settled_stoned_cells:
		freshly_stoned_cells[cell] = true

	board.chip_damage_existing_stone(freshly_stoned_cells)
	board.apply_gravity()
	_clear_safe_zones()


func _cells_current_pill_would_occupy() -> Dictionary:

	var result: Dictionary = {}

	if board.current_pill == null:
		return result

	for cell in board.current_pill.get_occupied_cells(
		board.current_grid_position
	):

		var check_cell := cell

		if board.has_pacman_trait():
			check_cell = board.wrap_cell_if_needed(cell)

		result[check_cell] = true

	return result


# Whether the falling pill dodges this gaze. TODO (step 3b):
# replace this stub with the real check -- both halves
# overlapping matching-color safe-zone indicators (answer 9/18),
# OR the pill currently carrying the temporary post-safe-zone
# shield (answer 20). Until 3b lands, every attack connects.
func _current_pill_is_protected() -> bool:

	return false


# TODO (step 3b).
func _spawn_safe_zones() -> void:

	pass


# TODO (step 3b).
func _clear_safe_zones() -> void:

	pass


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

	var fraction := _health_fraction()

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

	var target_index: int = min(4, board.get_child_count() - 1)

	if target_index >= 0:

		board.move_child(sprite, target_index)


func _create_boss_sprite() -> void:

	boss_sprite = Sprite2D.new()

	boss_sprite.name = "Boss3Sprite"
	boss_sprite.centered = false

	if ResourceLoader.exists(boss_texture_path):
		boss_sprite.texture = load(boss_texture_path)

	boss_sprite.region_enabled = true

	boss_sprite.region_rect = Rect2(
		0,
		0,
		BOSS_SHEET_WIDTH,
		BOSS_SHEET_HEIGHT
	)

	boss_sprite.position = board.grid_to_local(
		Vector2i(boss_col, boss_row)
	)

	boss_sprite.z_index = 30

	board.add_child(boss_sprite)
	_place_at_boss_layer(boss_sprite)

	_set_boss_sprite_frame()


func _set_boss_sprite_frame() -> void:

	if boss_sprite == null:
		return

	var damage_tier: int = clampi(
		(MAX_HEALTH - health) * 3 / maxi(MAX_HEALTH, 1),
		0,
		2
	)

	var anim_column: int = 0 if boss_anim_frame == 0 else 1

	var source_x: int = anim_column * BOSS_FRAME_SIZE.x
	var source_y: int = damage_tier * BOSS_FRAME_SIZE.y

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

	gaze_overlay_sprite.name = "MedusaGazeOverlay"
	gaze_overlay_sprite.centered = false
	gaze_overlay_sprite.visible = false

	if ResourceLoader.exists(gaze_overlay_texture_path):
		gaze_overlay_sprite.texture = load(gaze_overlay_texture_path)

	gaze_overlay_sprite.hframes = 2
	gaze_overlay_sprite.vframes = 1
	gaze_overlay_sprite.frame = GAZE_OVERLAY_TELEGRAPH_FRAME

	# This is local to boss_sprite, not board/grid space.
	gaze_overlay_sprite.position = gaze_overlay_position
	gaze_overlay_sprite.scale = gaze_overlay_scale

	# The overlay is a child of the boss, so it follows Medusa.
	boss_sprite.add_child(gaze_overlay_sprite)

	# Relative to boss_sprite's z_index of 30.
	gaze_overlay_sprite.z_index = 1


# ============================================================
# DAMAGE / DEATH
# ============================================================

func take_direct_damage(amount: int = 1) -> void:

	if defeated or board == null or busy:
		return

	busy = true

	if boss_sprite != null:

		# Show the current damage-tier frame while flashing.
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

		_magnifier_boss.position = magnifier_boss_position
		_magnifier_boss.frame = boss_anim_frame

	busy = false


func _play_death() -> void:

	defeated = true

	var death_column: int = boss_anim_frame

	for row in range(2, 6):

		var source_x: int = death_column * BOSS_FRAME_SIZE.x
		var source_y: int = row * BOSS_FRAME_SIZE.y

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
	_magnifier_root.name = "Boss3MagnifierDisplay"

	slot.add_child(_magnifier_root)

	var gradient := Sprite2D.new()

	gradient.name = "MagnifierGradient"
	gradient.centered = false

	if ResourceLoader.exists(gradient_texture_path):
		gradient.texture = load(gradient_texture_path)

	gradient.position = magnifier_gradient_position

	_magnifier_root.add_child(gradient)

	_magnifier_boss = Sprite2D.new()

	_magnifier_boss.name = "MagnifierBoss"

	if ResourceLoader.exists(magnifier_boss_texture_path):
		_magnifier_boss.texture = load(magnifier_boss_texture_path)

	_magnifier_boss.hframes = 2
	_magnifier_boss.vframes = 1
	_magnifier_boss.centered = false
	_magnifier_boss.position = magnifier_boss_position
	_magnifier_boss.frame = boss_anim_frame

	_magnifier_root.add_child(_magnifier_boss)

	healthbar = Boss1Healthbar.new()

	healthbar.name = "Boss3Healthbar"
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

	if board != null:
		board.conveyor_columns = []

	_clear_conveyor_visuals()

	if _magnifier_root != null and is_instance_valid(_magnifier_root):

		_magnifier_root.queue_free()
