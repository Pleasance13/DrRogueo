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

@export_group("Pill")

@export var pill_scene: PackedScene

@export_enum("LOW", "MEDIUM", "HIGH")
var fall_speed: int = FallSpeed.LOW


@export_group("Virus")

@export var virus_scene: PackedScene

@export_range(1, 20, 1)
var level: int = 1


# ============================================================
# BACKGROUND
# ============================================================

@export_group("Background")

@export var background: Background


# ============================================================
# ITEMS
# ============================================================

@export_group("Items")

@export var pong_sprite_texture: Texture2D

@export var tether_sprite_texture: Texture2D


# ============================================================
# STORE
# ============================================================

@export_group("Store")

@export var store_scene: PackedScene

# How many levels make up one stage. The store opens between
# every stage, and the background preset only rerolls at the
# start of a new stage (not every level).
const LEVELS_PER_STAGE := 5

const COINS_PER_VIRUS := 1

var coins := 0

# Coins earned so far during the CURRENT stage only. Reset to 0
# each time a new stage starts. Used to apply the OD-gauge coin
# multiplier when the stage ends (see _apply_stage_coin_multiplier).
var stage_coins_earned := 0

var store_controller: StoreController = null

var store_waiting := false


# ============================================================
# HUD
# ============================================================

@export_group("HUD")

@export var od_gauge_path: NodePath = NodePath("../OD-gauge")

@export var score_multiplier_path: NodePath = NodePath("../Score-multiplier")

@export var clipboard_path: NodePath = NodePath("../Clipboard")

var od_gauge: OverdoseGauge
var score_multiplier: ScoreMultiplier
var clipboard: Clipboard


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

@export_group("Game Over")

@export var game_over_font: Font

@export_range(1, 128, 1)
var game_over_font_size: int = 16

@export var game_over_font_color: Color = Color.WHITE

var game_over := false
var game_over_label: Label

# How long to wait on the GAME OVER screen before automatically
# bouncing back to the title screen (the player can also just
# press A / ui_accept to skip the wait).
const GAME_OVER_RETURN_DELAY := 5.0

const TITLE_SCENE_PATH := "res://scenes/ui/title_screen.tscn"

var game_over_timer := 0.0

var transition_layer: CanvasLayer
var transition_rect: ColorRect

# Shown on the black screen between levels ("STAGE # - LEVEL #"),
# using the same font options as game_over_label above. Stays up
# until the player presses A / ui_accept.
var level_transition_label: Label

var transitioning_level := false


# ============================================================
# RUNTIME STATE
# ============================================================

var current_pill: Pill
var next_pill: Pill

var next_item_preview: Sprite2D = null

# Item attached to the NEXT pill.
# This is intentionally generic so Tether, Pong, etc. can use
# the same replacement system.
var next_pill_item: Item = null

var current_grid_position := Vector2i.ZERO

var fall_timer := 0.0
var lock_timer := 0.0

var resolving_board := false

# Active Pong Paddle item minigame, or null when none is running.
var pong_controller: PongController = null

# Vector2i -> PillHalf
var occupied_cells: Dictionary = {}

# Vector2i -> Tether
var tether_cells: Dictionary = {}

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
	create_game_over_label()
	create_level_transition_label()

	# ========================================================
	# HUD NODES
	# ========================================================

	od_gauge = get_node_or_null(od_gauge_path) as OverdoseGauge

	score_multiplier = get_node_or_null(
		score_multiplier_path
	) as ScoreMultiplier

	clipboard = get_node_or_null(clipboard_path) as Clipboard

	# Starting level (stage 1) background.
	apply_new_level_background()

	$Items.set_board(self)

	Inventory.reset()

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

	if game_over:
		_process_game_over(delta)
		return

	# --------------------------------------------------------
	# HUD (kept live regardless of what state the board is in,
	# including during level/stage transitions).
	# --------------------------------------------------------

	update_hud()


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
	# PONG PADDLE ITEM ACTIVE
	# --------------------------------------------------------

	if is_instance_valid(pong_controller):
		return


	pong_controller = null


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


func trigger_game_over() -> void:

	if game_over:
		return


	game_over = true

	game_over_timer = 0.0

	print(">>> GAME OVER <<<")


	if current_pill != null:

		current_pill.queue_free()

		current_pill = null


	if next_pill != null:

		next_pill.queue_free()

		next_pill = null


	if next_item_preview != null:

		next_item_preview.queue_free()

		next_item_preview = null


	set_transition_black(true)


	if game_over_label != null:

		game_over_label.visible = true


func create_game_over_label() -> void:

	if transition_layer == null:
		return


	game_over_label = Label.new()

	game_over_label.name = "GameOverLabel"

	game_over_label.text = "GAME OVER"

	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	game_over_label.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	game_over_label.mouse_filter = Control.MOUSE_FILTER_IGNORE


	# ========================================================
	# FONT
	# ========================================================

	if game_over_font != null:

		game_over_label.add_theme_font_override(
			"font",
			game_over_font
		)


	game_over_label.add_theme_font_size_override(
		"font_size",
		game_over_font_size
	)


	game_over_label.add_theme_color_override(
		"font_color",
		game_over_font_color
	)


	game_over_label.visible = false

	transition_layer.add_child(game_over_label)


func create_level_transition_label() -> void:

	if transition_layer == null:
		return


	level_transition_label = Label.new()

	level_transition_label.name = "LevelTransitionLabel"

	level_transition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	level_transition_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	level_transition_label.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	level_transition_label.mouse_filter = Control.MOUSE_FILTER_IGNORE


	# ========================================================
	# FONT (same options as the GAME OVER label)
	# ========================================================

	if game_over_font != null:

		level_transition_label.add_theme_font_override(
			"font",
			game_over_font
		)


	level_transition_label.add_theme_font_size_override(
		"font_size",
		game_over_font_size
	)


	level_transition_label.add_theme_color_override(
		"font_color",
		game_over_font_color
	)


	level_transition_label.visible = false

	transition_layer.add_child(level_transition_label)


func _show_level_transition_label(stage: int, level_in_stage: int) -> void:

	if level_transition_label == null:
		return

	level_transition_label.text = (
		"STAGE %d - LEVEL %d" % [stage, level_in_stage]
	)

	level_transition_label.visible = true


func _hide_level_transition_label() -> void:

	if level_transition_label == null:
		return

	level_transition_label.visible = false


func _wait_for_accept() -> void:

	while not Input.is_action_just_pressed("ui_accept"):

		await get_tree().process_frame


func _process_game_over(delta: float) -> void:

	game_over_timer += delta

	if (
		game_over_timer >= GAME_OVER_RETURN_DELAY
		or Input.is_action_just_pressed("ui_accept")
	):

		return_to_title_screen()


func return_to_title_screen() -> void:

	get_tree().change_scene_to_file(TITLE_SCENE_PATH)


# ============================================================
# STAGES
# ============================================================
#
# "level" keeps counting up forever (1, 2, 3, ...) exactly as
# before, since virus difficulty scaling and the pong/tether
# grant cadence are both keyed off of it.
#
# Stage and level-within-stage are just derived from it.
#
# ============================================================

func get_stage() -> int:

	return ((level - 1) / LEVELS_PER_STAGE) + 1


func get_level_in_stage() -> int:

	return ((level - 1) % LEVELS_PER_STAGE) + 1


func is_stage_start(for_level: int = level) -> bool:

	return ((for_level - 1) % LEVELS_PER_STAGE) == 0


func get_fall_speed_name() -> String:

	match fall_speed:

		FallSpeed.LOW:
			return "LOW"

		FallSpeed.MEDIUM:
			return "MED"

		FallSpeed.HIGH:
			return "HIGH"

	return "LOW"


# ============================================================
# HUD
# ============================================================

func update_hud() -> void:

	var leftover := occupied_cells.size()

	if od_gauge != null:

		od_gauge.update_leftover(leftover)

	if score_multiplier != null:

		score_multiplier.set_multiplier(
			OverdoseGauge.multiplier_for_zone(
				OverdoseGauge.compute_zone(leftover)
			)
		)

	if clipboard != null:

		clipboard.update_stats(
			get_stage(),
			get_level_in_stage(),
			LEVELS_PER_STAGE,
			get_virus_count(),
			coins,
			get_fall_speed_name()
		)


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
	# SNAPSHOT LEFTOVER PILL HALVES
	# ========================================================
	#
	# Captured BEFORE clear_occupied_cells() wipes the board, so
	# the end-of-stage OD/coin multiplier reflects what was
	# actually left behind on this level.
	# ========================================================

	var leftover_halves_at_clear := occupied_cells.size()


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
	# CLEAR ALL SETTLED PILLS / TETHERS / VIRUSES
	# ========================================================

	clear_occupied_cells()

	clear_tether_cells()

	clear_virus_cells()


	# ========================================================
	# BLACK SCREEN
	# ========================================================

	set_transition_black(true)


	# ========================================================
	# WAS THIS THE LAST LEVEL OF A STAGE?
	# ========================================================
	#
	# Checked against the OLD level number, before incrementing.
	# ========================================================

	var completed_stage: bool = (level % LEVELS_PER_STAGE) == 0


	# ========================================================
	# NEXT LEVEL
	# ========================================================

	level += 1


	# ========================================================
	# STORE (BETWEEN STAGES)
	# ========================================================
	#
	# Applies the OD-gauge coin multiplier for the stage that
	# just ended, then shows the store and waits for Continue.
	# ========================================================

	if completed_stage:

		_apply_stage_coin_multiplier(leftover_halves_at_clear)

		# Reveal the screen so the store is actually visible --
		# otherwise it's stuck running behind the opaque
		# transition overlay (CanvasLayer, always on top).
		set_transition_black(false)

		await open_store()

		# Hide again while the next stage's board/background/
		# viruses get set up below.
		set_transition_black(true)


	# ========================================================
	# ROLL NEW BACKGROUND
	# ========================================================
	#
	# Only rerolls at the start of a new STAGE, not every level.
	# ========================================================

	if is_stage_start(level):

		apply_new_level_background()


	# ========================================================
	# GENERATE NEW VIRUSES
	# ========================================================

	generate_starting_viruses()


	# ========================================================
	# "STAGE # - LEVEL #" SCREEN (skipped when a stage just
	# ended, since the store already handles that hand-off).
	# ========================================================

	if not completed_stage:

		_show_level_transition_label(
			get_stage(),
			get_level_in_stage()
		)

		await _wait_for_accept()

		_hide_level_transition_label()


	# ========================================================
	# IMPORTANT:
	#
	# The transition flag MUST be cleared BEFORE spawn_pill().
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
# CLEAR TETHERS
# ============================================================

func clear_tether_cells() -> void:

	var tethers: Dictionary = {}

	for tether in tether_cells.values():

		if is_instance_valid(tether):

			tethers[tether] = true


	for tether in tethers.keys():

		if is_instance_valid(tether):

			tether.queue_free()


	tether_cells.clear()


# ============================================================
# VIRUS-CLEAR COIN REWARD
# ============================================================

func award_virus_coins() -> void:

	coins += COINS_PER_VIRUS

	stage_coins_earned += COINS_PER_VIRUS


# ============================================================
# STAGE-END COIN MULTIPLIER
# ============================================================

func _apply_stage_coin_multiplier(leftover_halves: int) -> void:

	var zone := OverdoseGauge.compute_zone(leftover_halves)

	var multiplier := OverdoseGauge.multiplier_for_zone(zone)

	var target := int(round(stage_coins_earned * multiplier))

	coins += (target - stage_coins_earned)

	stage_coins_earned = 0


# ============================================================
# STORE
# ============================================================

func open_store() -> void:

	if store_scene == null:

		push_warning(
			"Board: No store scene assigned; skipping store."
		)

		return


	var parent := get_parent()

	if parent == null:
		return


	var store_instance := store_scene.instantiate() as StoreController

	if store_instance == null:

		push_warning(
			"Board: store_scene does not contain a StoreController."
		)

		return


	parent.add_child(store_instance)

	store_instance.setup(self)


	await store_instance.closed


	if is_instance_valid(store_instance):

		store_instance.queue_free()


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


func local_to_grid(
	local_position: Vector2
) -> Vector2i:

	var top_left := grid_to_local(Vector2i.ZERO)

	var relative := local_position - top_left

	return Vector2i(
		int(floor(relative.x / CELL_SIZE)),
		int(floor(relative.y / CELL_SIZE))
	)


func get_board_pixel_rect() -> Rect2:

	return Rect2(
		grid_to_local(Vector2i.ZERO),
		Vector2(
			BOARD_WIDTH * CELL_SIZE,
			BOARD_HEIGHT * CELL_SIZE
		)
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
		1,
		VIRUS_LEVEL_CAP
	)

	return clamped_level * 4


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


	# ========================================================
	# CLEAN UP OLD PREVIEW
	# ========================================================

	if next_pill != null:

		next_pill.queue_free()

		next_pill = null


	if next_item_preview != null:

		next_item_preview.queue_free()

		next_item_preview = null


	# ========================================================
	# CREATE NORMAL PILL PREVIEW
	# ========================================================

	next_pill = pill_scene.instantiate() as Pill


	if next_pill == null:

		push_error(
			"Board: Pill scene does not contain a Pill node."
		)

		return


	add_child(next_pill)


	next_pill.orientation = Pill.Orientation.RIGHT

	next_pill.is_tether_pill = false

	randomize_pill_colors(next_pill)


	var preview_position := Vector2i(
		BOARD_WIDTH / 2 - 1,
		-7
	)


	next_pill.position = grid_to_local(
		preview_position
	)


	# ========================================================
	# ITEM PREVIEW
	# ========================================================
	#
	# If an item is queued for the next pill, hide the normal
	# pill and display the item's inventory icon in its place.
	#
	# ========================================================

	if next_pill_item != null:

		if next_pill_item.icon != null:

			next_item_preview = Sprite2D.new()

			next_item_preview.name = "NextItemPreview"
			next_item_preview.centered = false

			next_item_preview.texture = (
				next_pill_item.icon
			)

			next_item_preview.position = (
				grid_to_local(preview_position)
			)

			add_child(next_item_preview)

			next_pill.visible = false


# ============================================================
# PILL SPAWNING
# ============================================================

func spawn_pill() -> void:

	if transitioning_level:
		return


	if game_over:
		return


	if pill_scene == null:

		push_warning(
			"Board: No pill scene assigned."
		)

		return


	# ========================================================
	# REMOVE ITEM PREVIEW
	# ========================================================

	if next_item_preview != null:

		next_item_preview.queue_free()

		next_item_preview = null


	# ========================================================
	# PROMOTE PREVIEW TO CURRENT PILL
	# ========================================================

	if next_pill != null:

		current_pill = next_pill

		next_pill = null

		current_pill.visible = true

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
	# RESET ORIENTATION
	# ========================================================

	current_pill.orientation = Pill.Orientation.RIGHT

	current_pill.tether_sprite_texture = tether_sprite_texture


	# ========================================================
	# SPAWN POSITION
	# ========================================================

	current_grid_position = Vector2i(
		BOARD_WIDTH / 2 - 1,
		0
	)


	fall_timer = 0.0

	lock_timer = 0.0


	# ========================================================
	# GAME OVER CHECK
	# ========================================================
	#
	# The incoming pill must be able to occupy its actual
	# spawn cells. If either spawn cell is already occupied,
	# the board is full at the spawn point and the run ends.
	#
	# ========================================================

	if not can_pill_occupy(current_grid_position):

		trigger_game_over()

		return


	update_pill_position()


	# ========================================================
	# THE OLD PREVIEW HAS NOW BECOME THE ACTIVE PLAYER PILL.
	# ========================================================

	next_pill_item = null


	# ========================================================
	# CREATE A NEW NORMAL PREVIEW
	# ========================================================

	create_next_preview()


	# ========================================================
	# NOTE: We do NOT fire the item here.
	#
	# Next-pill items like Tether need the player to steer the
	# pill into position first. Firing happens only when the
	# player deploys it (see _handle_input) or when the pill
	# locks in without being deployed (see settle_current_pill),
	# both of which go through Inventory.fire_pending().
	#
	# ========================================================


# ============================================================
# INPUT
# ============================================================

func _handle_input() -> void:

	# ========================================================
	# TETHER PILL DEPLOYMENT
	# ========================================================
	#
	# A Tether pill is already consumed from the inventory.
	# Deployment does NOT require an inventory slot to be
	# selected.
	#
	# ========================================================

	if (
		current_pill != null
		and current_pill.is_tether_pill
		and Input.is_action_just_pressed("ui_accept")
	):

		if await deploy_tether(
			current_pill,
			current_grid_position,
			current_pill.orientation
		):

			resolve_board()

			return


	# ========================================================
	# NORMAL MOVEMENT
	# ========================================================

	if Input.is_action_just_pressed("ui_left"):

		try_move_pill(
			Vector2i(-1, 0)
		)


	if Input.is_action_just_pressed("ui_right"):

		try_move_pill(
			Vector2i(1, 0)
		)


	if Input.is_action_just_pressed("ui_down"):

		if try_move_pill(
			Vector2i(0, 1)
		):

			fall_timer = 0.0


	if Input.is_action_just_pressed("rotate_ccw"):

		try_rotate_pill_counter_clockwise()


	if Input.is_action_just_pressed("rotate_cw"):

		try_rotate_pill()


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

	if tether_cells.has(cell):
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

		# No hard roof: cell.y can go negative (e.g. rotating a
		# pill to vertical right at spawn, row 0) since nothing
		# in the game ever needs to fall or move upward past the
		# board's top edge.
		if cell.y >= BOARD_HEIGHT:
			return false


		if is_cell_filled(cell):
			return false


	return true


func arm_tether_pill() -> bool:

	if next_pill == null:
		return false


	next_pill.is_tether_pill = true

	return true


# ============================================================
# TETHER ITEM
# ============================================================

func deploy_tether(
	pill: Pill,
	grid_position: Vector2i,
	pill_orientation: int
) -> bool:

	if pill == null:
		return false


	if not pill.is_tether_pill:
		return false


	# ========================================================
	# DETERMINE TETHER DIRECTION
	# ========================================================

	var direction := Vector2i.ZERO

	var tether_orientation: int


	match pill_orientation:

		Pill.Orientation.RIGHT:

			direction = Vector2i(1, 0)

			tether_orientation = Tether.Orientation.HORIZONTAL


		Pill.Orientation.LEFT:

			direction = Vector2i(1, 0)

			tether_orientation = Tether.Orientation.HORIZONTAL


		Pill.Orientation.UP:

			direction = Vector2i(0, 1)

			tether_orientation = Tether.Orientation.VERTICAL


		Pill.Orientation.DOWN:

			direction = Vector2i(0, 1)

			tether_orientation = Tether.Orientation.VERTICAL


		_:

			return false


	# ========================================================
	# FIND THE TWO CELLS OCCUPIED BY THE TETHER PILL
	# ========================================================

	var pill_cells: Array[Vector2i] = (
		pill.get_occupied_cells(grid_position)
	)


	if pill_cells.size() != 2:
		return false


	var first_cell := pill_cells[0]

	var second_cell := pill_cells[1]


	# ========================================================
	# SORT CELLS ALONG THE TETHER AXIS
	# ========================================================

	var low_cell := first_cell

	var high_cell := second_cell


	if tether_orientation == Tether.Orientation.HORIZONTAL:

		if low_cell.x > high_cell.x:

			low_cell = second_cell

			high_cell = first_cell


	else:

		if low_cell.y > high_cell.y:

			low_cell = second_cell

			high_cell = first_cell


	# ========================================================
	# SEARCH OUTWARD FROM BOTH ENDS
	# ========================================================

	var negative_direction := -direction


	var endpoint_a_result: Variant = find_tether_endpoint(
		low_cell,
		negative_direction
	)


	var endpoint_b_result: Variant = find_tether_endpoint(
		high_cell,
		direction
	)


	# Null only happens when blocked by an existing tether --
	# that's still a hard failure to deploy at all.
	if endpoint_a_result == null or endpoint_b_result == null:

		print(
			"TETHER: could not find endpoints (blocked by tether). A=",
			endpoint_a_result,
			" B=",
			endpoint_b_result
		)

		return false


	var endpoint_a_data: Dictionary = endpoint_a_result

	var endpoint_b_data: Dictionary = endpoint_b_result


	var endpoint_a_cell: Vector2i = endpoint_a_data["cell"]

	var endpoint_b_cell: Vector2i = endpoint_b_data["cell"]


	var endpoint_a_hit_wall: bool = endpoint_a_data["hit_wall"]

	var endpoint_b_hit_wall: bool = endpoint_b_data["hit_wall"]

	print(
		"TETHER: endpoints found: ",
		endpoint_a_cell,
		" / ",
		endpoint_b_cell
	)

	# ========================================================
	# ENDPOINT COLORS
	# ========================================================

	var color_a: Variant = get_color_at_cell(
		endpoint_a_cell
	)


	var color_b: Variant = get_color_at_cell(
		endpoint_b_cell
	)


	# A wall hit is always treated as a mismatch, even if the
	# other side found a valid color.
	var colors_match: bool = (
		not endpoint_a_hit_wall
		and not endpoint_b_hit_wall
		and color_a != null
		and color_b != null
		and color_a == color_b
	)


	if not colors_match:

		print(
			"TETHER: broken -- wall=",
			endpoint_a_hit_wall,
			"/",
			endpoint_b_hit_wall,
			" colors=",
			color_a,
			" vs ",
			color_b
		)


	# ========================================================
	# BUILD MIDDLE CELLS
	# ========================================================

	var cells_to_create: Array[Vector2i] = []


	if tether_orientation == Tether.Orientation.HORIZONTAL:

		var start_x := mini(
			endpoint_a_cell.x,
			endpoint_b_cell.x
		)


		var end_x := maxi(
			endpoint_a_cell.x,
			endpoint_b_cell.x
		)


		# ----------------------------------------------------
		# A wall endpoint is an empty cell, not an occupant --
		# it should be included in the bridge itself so the
		# tether visually reaches all the way to the wall.
		# ----------------------------------------------------

		var range_start := start_x + 1

		if endpoint_a_hit_wall:

			range_start = start_x


		var range_end := end_x

		if endpoint_b_hit_wall:

			range_end = end_x + 1


		for x in range(
			range_start,
			range_end
		):

			var cell := Vector2i(
				x,
				endpoint_a_cell.y
			)


			# The cells occupied by the original falling
			# tether pill should already be clear.
			#
			# Any other obstruction makes this deployment invalid.

			if is_cell_filled(cell):

				return false


			cells_to_create.append(cell)


	else:

		var start_y := mini(
			endpoint_a_cell.y,
			endpoint_b_cell.y
		)


		var end_y := maxi(
			endpoint_a_cell.y,
			endpoint_b_cell.y
		)


		var range_start := start_y + 1

		if endpoint_a_hit_wall:

			range_start = start_y


		var range_end := end_y

		if endpoint_b_hit_wall:

			range_end = end_y + 1


		for y in range(
			range_start,
			range_end
		):

			var cell := Vector2i(
				endpoint_a_cell.x,
				y
			)


			if is_cell_filled(cell):

				return false


			cells_to_create.append(cell)


	# ========================================================
	# REQUIRE AT LEAST ONE BRIDGE CELL
	# ========================================================

	if cells_to_create.is_empty():

		return false


	# ========================================================
	# CREATE TETHER
	# ========================================================

	var tether := Tether.new()

	add_child(tether)


	for cell in cells_to_create:

		tether_cells[cell] = tether


	var texture := tether_sprite_texture

	if texture == null:

		push_warning(
			"Board: tether_sprite_texture is NULL."
		)

		return false


	# ========================================================
	# REMOVE THE FALLING TETHER PILL
	# ========================================================

	pill.queue_free()

	current_pill = null

	fall_timer = 0.0

	lock_timer = 0.0


	# ========================================================
	# START DEPLOYMENT
	# ========================================================

	var tether_color: int = PillHalf.PillColor.RED

	if color_a != null:

		tether_color = color_a

	elif color_b != null:

		tether_color = color_b


	await tether.deploy(
		self,
		cells_to_create,
		endpoint_a_cell,
		endpoint_b_cell,
		tether_orientation,
		tether_color,
		texture,
		pill_cells,
		colors_match,
		endpoint_a_hit_wall,
		endpoint_b_hit_wall
	)


	return true


func find_tether_endpoint(
	start_cell: Vector2i,
	direction: Vector2i
) -> Variant:

	var cell := start_cell + direction


	while (
		cell.x >= 0
		and cell.x < BOARD_WIDTH
		and cell.y >= 0
		and cell.y < BOARD_HEIGHT
	):

		# ----------------------------------------------------
		# TOP BOARD EDGE
		# ----------------------------------------------------
		#
		# Row 0 is treated as a wall endpoint rather than
		# a tether cell.
		#
		# This lets the tether visually reach the top border
		# while keeping row 0 free for the pill spawn.
		# ----------------------------------------------------

		if (
			direction == Vector2i(0, -1)
			and cell.y == 0
		):

			return {
				"cell": cell,
				"hit_wall": true
			}


		var color: Variant = get_color_at_cell(cell)


		if color != null:

			return {
				"cell": cell,
				"hit_wall": false
			}


		# ----------------------------------------------------
		# EXISTING TETHER
		# ----------------------------------------------------
		#
		# Tethers cannot be crossed or used as endpoints.
		# ----------------------------------------------------

		if tether_cells.has(cell):

			return null


		cell += direction


	# ========================================================
	# RAN OFF THE BOARD EDGE
	# ========================================================

	var wall_cell := cell - direction

	return {
		"cell": wall_cell,
		"hit_wall": true
	}


# ============================================================
# NEXT PILL ITEM
# ============================================================

func arm_next_pill_item(item: Item) -> bool:

	if item == null:
		return false

	if next_pill == null:
		return false

	if next_pill_item != null:
		return false


	next_pill_item = item


	# ========================================================
	# ITEM-SPECIFIC PILL STATE
	# ========================================================

	if item.id == "tether":

		next_pill.is_tether_pill = true

	else:

		next_pill.is_tether_pill = false


	# ========================================================
	# ITEM PREVIEW
	# ========================================================
	#
	# The normal pill preview is hidden and replaced by the
	# item's inventory icon.
	#
	# The actual next_pill remains underneath it so that when
	# it becomes the current pill, it can simply be made visible
	# again.
	#
	# ========================================================

	if next_item_preview != null:

		next_item_preview.queue_free()

		next_item_preview = null


	if item.icon != null:

		next_item_preview = Sprite2D.new()

		next_item_preview.name = "NextItemPreview"
		next_item_preview.centered = false

		next_item_preview.texture = item.icon

		next_item_preview.position = next_pill.position

		add_child(next_item_preview)

		next_pill.visible = false


	return true


func clear_next_pill_item() -> void:

	next_pill_item = null


	if next_item_preview != null:

		next_item_preview.queue_free()

		next_item_preview = null


	if next_pill != null:

		next_pill.visible = true

		next_pill.is_tether_pill = false

		next_pill.queue_redraw()


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
			current_grid_position +
			Vector2i(kick, 0)
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


	# ========================================================
	# UNDEPLOYED TETHER PILL
	# ========================================================

	if current_pill.is_tether_pill:

		current_pill.queue_free()

		current_pill = null

		fall_timer = 0.0
		lock_timer = 0.0

		next_pill_item = null

		spawn_pill()

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


	half_1.position = grid_to_local(half_1_cell)
	half_2.position = grid_to_local(half_2_cell)


	occupied_cells[half_1_cell] = half_1
	occupied_cells[half_2_cell] = half_2


	current_pill.queue_free()
	current_pill = null


	# ========================================================
	# PENDING ITEM
	# ========================================================

	var item_fired := false

	if Inventory.has_pending():

		item_fired = Inventory.fire_pending(self)

		if item_fired:

			fall_timer = 0.0
			lock_timer = 0.0


	# ========================================================
	# BOARD RESOLUTION
	# ========================================================
	#
	# Items such as Pong take over the game flow.
	# Tether is different: its item is attached to the NEXT
	# pill, so normal pill spawning should continue.
	#
	# ========================================================

	var should_spawn_next: bool = not item_fired

	resolve_board(should_spawn_next)


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

func resolve_board(spawn_next: bool = true) -> void:

	if resolving_board:
		return


	resolving_board = true


	var level_cleared := await _resolve_matches_and_gravity()


	resolving_board = false


	if level_cleared:

		await advance_to_next_level()

		return


	if spawn_next:
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

			# ========================================================
			# PILL HALF
			# ========================================================

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


			# ========================================================
			# VIRUS
			# ========================================================

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

				award_virus_coins()

				continue


			# ========================================================
			# TETHER
			# ========================================================

			var tether: Tether = (
				tether_cells.get(cell)
				as Tether
			)


			if tether != null:

				_remove_tether(tether)


		# ========================================================
		# WAIT FOR VANISHING
		# ========================================================

		await wait_for_vanishing_halves()


		# ========================================================
		# GRAVITY
		# ========================================================

		await apply_gravity()


		# ========================================================
		# LEVEL CLEAR
		# ========================================================

		if virus_cells.is_empty():

			return true


	# Godot requires an explicit return because this function
	# is typed as -> bool.
	return false


func _remove_tether(
	tether: Tether
) -> void:

	if tether == null:
		return


	var cells_to_remove: Array[Vector2i] = []


	for cell in tether_cells.keys():

		if tether_cells[cell] == tether:

			cells_to_remove.append(cell)


	for cell in cells_to_remove:

		tether_cells.erase(cell)


	if is_instance_valid(tether):

		tether.queue_free()


# ============================================================
# PONG PADDLE ITEM
# ============================================================

func start_pong_item() -> void:

	if is_instance_valid(pong_controller):
		return


	pong_controller = PongController.new()

	add_child(pong_controller)

	pong_controller.start(self)


func on_pong_missed() -> void:

	pong_controller = null


	if (
		current_pill == null
		and not transitioning_level
		and not resolving_board
	):

		spawn_pill()


func pong_break_cell(
	cell: Vector2i
) -> bool:

	if transitioning_level:
		return false


	if occupied_cells.has(cell):

		var half := occupied_cells[cell] as PillHalf


		if not is_instance_valid(half):

			occupied_cells.erase(cell)

			return false


		if not half.take_hit():
			return false


		occupied_cells.erase(cell)


		half.pill_state = PillHalf.PillState.VANISHING

		vanishing_halves[half] = VANISH_DURATION


		var partner := half.partner_half

		if is_instance_valid(partner):

			partner.partner_half = null
			half.partner_half = null

			partner.pill_state = (
				PillHalf.PillState.SEPARATED
			)

		else:

			half.partner_half = null


		_start_pong_break_resolution()

		return true


	if virus_cells.has(cell):

		var virus : Virus = virus_cells[cell] as Virus


		if not is_instance_valid(virus):

			virus_cells.erase(cell)

			return false


		if not virus.take_hit():
			return false


		virus_cells.erase(cell)

		virus.visual_state = (
			Virus.VisualState.VANISHING
		)

		vanishing_halves[virus] = VANISH_DURATION

		award_virus_coins()


		_start_pong_break_resolution()

		return true


	return false


func _start_pong_break_resolution() -> void:

	if resolving_board:
		return


	resolving_board = true

	_resolve_pong_break()


func _resolve_pong_break() -> void:

	await wait_for_vanishing_halves()


	var level_cleared := virus_cells.is_empty()


	if not level_cleared:

		await apply_gravity()

		await wait_for_vanishing_halves()

		level_cleared = await _resolve_matches_and_gravity()


	resolving_board = false


	if level_cleared:

		if is_instance_valid(pong_controller):

			var controller := pong_controller

			pong_controller = null

			controller.stop()


		await advance_to_next_level()


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

		var color: Variant = get_color_at_cell(cell)


		if color == null:
			continue


		# ----------------------------------------------------
		# Horizontal
		# ----------------------------------------------------

		var horizontal_result := find_line_match(
			cell,
			Vector2i(1, 0),
			color
		)


		if horizontal_result["matched"]:

			for match_cell in horizontal_result["cells"]:

				matched_cells[match_cell] = true

			for tether_cell in horizontal_result["tethers"]:

				matched_cells[tether_cell] = true


		# ----------------------------------------------------
		# Vertical
		# ----------------------------------------------------

		var vertical_result := find_line_match(
			cell,
			Vector2i(0, 1),
			color
		)


		if vertical_result["matched"]:

			for match_cell in vertical_result["cells"]:

				matched_cells[match_cell] = true

			for tether_cell in vertical_result["tethers"]:

				matched_cells[tether_cell] = true


	var result: Array[Vector2i] = []


	for cell in matched_cells.keys():

		result.append(cell)


	return result


func find_line_match(
	start_cell: Vector2i,
	direction: Vector2i,
	color: int
) -> Dictionary:

	var matched: Array[Vector2i] = []
	var traversed_tethers: Array[Vector2i] = []


	var cell := start_cell


	while (
		cell.x >= 0
		and cell.x < BOARD_WIDTH
		and cell.y >= 0
		and cell.y < BOARD_HEIGHT
	):

		var found_color : Variant = get_color_at_cell(cell)


		# ----------------------------------------------------
		# Colored cell
		# ----------------------------------------------------

		if found_color != null:

			if found_color != color:
				break

			matched.append(cell)

			cell += direction

			continue


		# ----------------------------------------------------
		# Tether
		# ----------------------------------------------------

		if tether_cells.has(cell):

			var tether := tether_cells[cell] as Tether

			if tether == null:
				break


			if not tether.connects_in_direction(
				cell,
				direction
			):

				break


			if tether.tether_color != color:
				break


			traversed_tethers.append(cell)

			cell += direction

			continue


		# ----------------------------------------------------
		# Empty cell
		# ----------------------------------------------------

		break


	if matched.size() >= 4:

		return {
			"matched": true,
			"cells": matched,
			"tethers": traversed_tethers
		}


	return {
		"matched": false,
		"cells": [],
		"tethers": []
	}


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

	var stale_cells: Array[Vector2i] = []


	for cell in occupied_cells.keys():

		var raw_half: Variant = occupied_cells[cell]


		if not is_instance_valid(raw_half):

			stale_cells.append(cell)

			continue


		var half: PillHalf = raw_half as PillHalf


		if half == null:

			stale_cells.append(cell)

			continue


		if visited.has(half):
			continue


		var partner: PillHalf = null


		if is_instance_valid(half.partner_half):

			partner = half.partner_half


		if partner != null:

			var partner_cell: Variant = find_half_cell(partner)


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


	for cell in stale_cells:

		occupied_cells.erase(cell)


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

	if not is_instance_valid(target):
		return null


	for cell in occupied_cells.keys():

		var raw_half: Variant = occupied_cells[cell]


		if not is_instance_valid(raw_half):
			continue


		var half: PillHalf = raw_half as PillHalf


		if half == target:

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


		if tether_cells.has(destination):

			return false


		if occupied_cells.has(destination):

			var raw_occupant: Variant = (
				occupied_cells[destination]
			)


			if not is_instance_valid(raw_occupant):

				occupied_cells.erase(destination)

				continue


			var occupant: PillHalf = (
				raw_occupant as PillHalf
			)


			if occupant == null:

				occupied_cells.erase(destination)

				continue


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


	for cell in cells:

		occupied_cells.erase(cell)


	var destination_cells: Array[Vector2i] = []


	for cell in cells:

		var destination := (
			cell + Vector2i(0, 1)
		)


		destination_cells.append(
			destination
		)


	for i in range(halves.size()):

		var half: PillHalf = halves[i]

		var destination: Vector2i = (
			destination_cells[i]
		)


		occupied_cells[destination] = half


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
