@tool
class_name Pill
extends Node2D


# ============================================================
# PILL
# ============================================================


enum Orientation {
	RIGHT,
	DOWN,
	LEFT,
	UP
}


enum PreviewState {
	CONNECTED,
	SEPARATED,
	BOTH_VANISHING,
	HALF_1_VANISHING,
	HALF_2_VANISHING
}


@export_group("Pill")

@export_enum("RED", "YELLOW", "BLUE")
var half_1_color: int = PillHalf.PillColor.RED:
	set(value):
		half_1_color = value
		_update_pill()


@export_enum("RED", "YELLOW", "BLUE")
var half_2_color: int = PillHalf.PillColor.BLUE:
	set(value):
		half_2_color = value
		_update_pill()


@export_enum("RIGHT", "DOWN", "LEFT", "UP")
var orientation: int = Orientation.RIGHT:
	set(value):
		orientation = value
		_update_pill()


@export_enum(
	"CONNECTED",
	"SEPARATED",
	"BOTH VANISHING",
	"HALF 1 VANISHING",
	"HALF 2 VANISHING"
)
var preview_state: int = PreviewState.CONNECTED:
	set(value):
		preview_state = value
		_update_pill()


# ============================================================
# TETHER
# ============================================================

@export_group("Tether")

@export var is_tether_pill := false:
	set(value):
		is_tether_pill = value
		_update_pill()


@export var tether_sprite_texture: Texture2D:
	set(value):
		tether_sprite_texture = value
		_update_pill()


# ============================================================
# SHIFT
# ============================================================

@export_group("Shift")

@export var is_shift_pill := false:
	set(value):
		is_shift_pill = value

		if not value:
			shift_vanishing = false

		_update_pill()


@export var shift_sprite_texture: Texture2D:
	set(value):
		shift_sprite_texture = value
		_update_pill()


# True while playing the brief "disappearing" frame right after
# a Shift Pill settles, before Board actually removes it and
# triggers the gravity shift. See Pill.play_shift_vanish().
var shift_vanishing := false


# ============================================================
# DISSOLVER
# ============================================================
#
# A Dissolver Pill falls, rotates, and matches exactly like a
# normal pill - it's just flagged so board.gd knows to trigger
# its global same-color clear when it lands in a match. Both
# halves always share half_1_color/half_2_color; board.gd sets
# them equal when it arms a Dissolver item.
#
# ============================================================

@export_group("Dissolver")

@export var is_dissolver_pill := false:
	set(value):
		is_dissolver_pill = value
		_update_pill()


# ============================================================
# GHOST
# ============================================================
#
# is_ghost_pill: whether this specific falling pill was armed
# with the Ghost Pill item (set by Board.arm_next_pill_item()).
# Gates whether pressing A does anything.
#
# is_ghosting: runtime state toggled by pressing A while this
# pill is falling. While true, the normal Half1/Half2 sprites
# are hidden and a dedicated ghost sprite is drawn instead
# (see _draw_ghost_pill()). Collision bypass itself lives in
# Board.can_pill_occupy() -- this is purely visual/state here.
#
# ============================================================

@export_group("Ghost")

@export var is_ghost_pill := false

@export var ghost_sprite_texture: Texture2D:
	set(value):
		ghost_sprite_texture = value
		queue_redraw()

var is_ghosting := false:
	set(value):
		is_ghosting = value
		_update_pill()


# ============================================================
# GHOST SPRITESHEET
# ============================================================
#
# ghost_pill.png is 16x32.
#
# Top half (y 0-15)   -> VERTICAL animation, two 8x16 frames
#                        side by side: [0,0] and [8,0].
#
# Bottom half (y 16-31) -> HORIZONTAL animation, two 16x8
#                          frames stacked: [0,16] and [0,24].
#
# There's no separate left/right or up/down art -- the same
# two frames are used regardless of which way the pill is
# actually facing, since the ghost silhouette covers the same
# footprint either way.
#
# ============================================================

const GHOST_VERTICAL_FRAME_0 := Rect2(0, 0, 8, 16)
const GHOST_VERTICAL_FRAME_1 := Rect2(8, 0, 8, 16)

const GHOST_HORIZONTAL_FRAME_0 := Rect2(0, 16, 16, 8)
const GHOST_HORIZONTAL_FRAME_1 := Rect2(0, 24, 16, 8)


# ============================================================
# CONSTANTS
# ============================================================

const CELL_SIZE := 8


# ============================================================
# TETHER SPRITESHEET
# ============================================================
#
# The tether sheet is 24x48.
#
# Each sprite is 8x8.
#
# These are the two sprites used for the falling/preview
# tether pill.
#
# Horizontal:
#   [0,24] [8,24]
#
# Vertical:
#   [0,0]
#   [0,8]
#
# ============================================================

const TETHER_HORIZONTAL_LEFT := Rect2(0, 24, 8, 8)
const TETHER_HORIZONTAL_RIGHT := Rect2(8, 24, 8, 8)

const TETHER_VERTICAL_TOP := Rect2(0, 0, 8, 8)
const TETHER_VERTICAL_BOTTOM := Rect2(0, 8, 8, 8)


# ============================================================
# SHIFT SPRITESHEET
# ============================================================
#
# 24x40 sheet, 8px cells. Each direction is ONE sprite spanning
# both cells of the pill (not two separate 8x8 halves).
#
# Vertical block (8 wide x 16 tall each), left-to-right:
#   UP DOWN VANISH
#
# Horizontal rows (16 wide x 8 tall each), top-to-bottom:
#   LEFT
#   RIGHT
#   VANISH
#
# ============================================================

const SHIFT_UP := Rect2(0, 0, 8, 16)
const SHIFT_DOWN := Rect2(8, 0, 8, 16)
const SHIFT_VANISH_VERTICAL := Rect2(16, 0, 8, 16)

const SHIFT_LEFT := Rect2(0, 16, 16, 8)
const SHIFT_RIGHT := Rect2(0, 24, 16, 8)
const SHIFT_VANISH_HORIZONTAL := Rect2(0, 32, 16, 8)


# ============================================================
# CHILD NODES
# ============================================================

var tether_sprite: Node2D



# ============================================================
# READY
# ============================================================

func _ready() -> void:

	_ensure_tether_sprite()

	if not Engine.is_editor_hint():

		if not AnimClock.frame_changed.is_connected(
			_on_anim_frame_changed
		):

			AnimClock.frame_changed.connect(
				_on_anim_frame_changed
			)

	_update_pill()


# ============================================================
# SHARED ANIM CLOCK
# ============================================================

func _on_anim_frame_changed(_frame: int) -> void:

	if is_ghosting:

		queue_redraw()


# ============================================================
# ENSURE TETHER SPRITE
# ============================================================

func _ensure_tether_sprite() -> void:

	if tether_sprite != null:
		return

	tether_sprite = Node2D.new()

	tether_sprite.name = "TetherSprite"

	add_child(tether_sprite)


# ============================================================
# SHIFT VANISH
# ============================================================

func play_shift_vanish() -> void:

	shift_vanishing = true

	queue_redraw()


# ============================================================
# VISUAL SETUP
# ============================================================

func _update_pill() -> void:

	if not is_inside_tree():
		return


	var half_1 := get_node_or_null("Half1") as PillHalf
	var half_2 := get_node_or_null("Half2") as PillHalf


	_ensure_tether_sprite()


	# ========================================================
	# TETHER VISUAL
	# ========================================================

	if is_tether_pill:

		if half_1 != null:
			half_1.visible = false

		if half_2 != null:
			half_2.visible = false

		tether_sprite.visible = true

		queue_redraw()

		return


	# ========================================================
	# SHIFT VISUAL
	# ========================================================

	if is_shift_pill:

		if half_1 != null:
			half_1.visible = false

		if half_2 != null:
			half_2.visible = false

		tether_sprite.visible = false

		queue_redraw()

		return


	# ========================================================
	# GHOST VISUAL
	# ========================================================

	if is_ghosting:

		if half_1 != null:
			half_1.visible = false

		if half_2 != null:
			half_2.visible = false

		tether_sprite.visible = false

		queue_redraw()

		return


	# ========================================================
	# NORMAL PILL VISUAL
	# ========================================================

	tether_sprite.visible = false


	if half_1 == null or half_2 == null:
		return


	half_1.visible = true
	half_2.visible = true


	half_1.pill_color = half_1_color
	half_2.pill_color = half_2_color

	# --------------------------------------------------------
	# DISSOLVER FLAG / OVERLAY
	# --------------------------------------------------------

	half_1.is_dissolver = is_dissolver_pill
	half_2.is_dissolver = is_dissolver_pill


	match orientation:

		Orientation.RIGHT:

			# [Half 1][Half 2]
			#
			# Origin is Half 1.

			half_1.position = Vector2(0, 0)
			half_2.position = Vector2(CELL_SIZE, 0)

			half_1.pill_state = PillHalf.PillState.LEFT
			half_2.pill_state = PillHalf.PillState.RIGHT


		Orientation.DOWN:

			# [Half 1]
			# [Half 2]
			#
			# Origin is Half 2.

			half_1.position = Vector2(0, -CELL_SIZE)
			half_2.position = Vector2(0, 0)

			half_1.pill_state = PillHalf.PillState.TOP
			half_2.pill_state = PillHalf.PillState.BOTTOM


		Orientation.LEFT:

			# [Half 2][Half 1]
			#
			# Origin is Half 2.

			half_2.position = Vector2(0, 0)
			half_1.position = Vector2(CELL_SIZE, 0)

			half_2.pill_state = PillHalf.PillState.LEFT
			half_1.pill_state = PillHalf.PillState.RIGHT


		Orientation.UP:

			# [Half 2]
			# [Half 1]
			#
			# Origin is Half 1.

			half_2.position = Vector2(0, -CELL_SIZE)
			half_1.position = Vector2(0, 0)

			half_2.pill_state = PillHalf.PillState.TOP
			half_1.pill_state = PillHalf.PillState.BOTTOM


	# ========================================================
	# PREVIEW STATE
	# ========================================================

	match preview_state:

		PreviewState.CONNECTED:
			pass


		PreviewState.SEPARATED:

			half_1.pill_state = PillHalf.PillState.SEPARATED
			half_2.pill_state = PillHalf.PillState.SEPARATED


		PreviewState.BOTH_VANISHING:

			half_1.pill_state = PillHalf.PillState.VANISHING
			half_2.pill_state = PillHalf.PillState.VANISHING


		PreviewState.HALF_1_VANISHING:

			half_1.pill_state = PillHalf.PillState.VANISHING


		PreviewState.HALF_2_VANISHING:

			half_2.pill_state = PillHalf.PillState.VANISHING


# ============================================================
# WRAP LAYOUT RESET
# ============================================================
#
# Called by Board when a Pacman-wrapped pill straddling the
# board edges moves back to a normal, non-wrapped position.
# Restores Half1/Half2 to their standard orientation-based
# layout, undoing any manual position override Board applied
# for the wrap-split visual (see
# DrRogueoBoard._apply_wrap_visual_offsets()).
# ============================================================

func reset_half_layout() -> void:

	_update_pill()


# ============================================================
# GHOST VISUAL
# ============================================================

func _update_ghost_visual() -> void:

	if not is_inside_tree():
		return

	var half_1 := get_node_or_null("Half1") as PillHalf
	var half_2 := get_node_or_null("Half2") as PillHalf

	var alpha := 0.45 if is_ghosting else 1.0

	if half_1 != null:
		half_1.modulate.a = alpha

	if half_2 != null:
		half_2.modulate.a = alpha


# ============================================================
# DRAW
# ============================================================

func _draw() -> void:

	if is_tether_pill:

		_draw_tether()

		return


	if is_shift_pill:

		_draw_shift()

		return


	if is_ghosting:

		_draw_ghost()

		return


func _draw_ghost() -> void:

	if ghost_sprite_texture == null:
		return


	var horizontal := (
		orientation == Orientation.RIGHT
		or orientation == Orientation.LEFT
	)


	var frame := 0

	if not Engine.is_editor_hint():

		frame = AnimClock.frame


	var region: Rect2
	var rect: Rect2


	if horizontal:

		region = (
			GHOST_HORIZONTAL_FRAME_1
			if frame == 1
			else GHOST_HORIZONTAL_FRAME_0
		)

		# Bounding box is the same whether it's RIGHT or LEFT --
		# both halves span x=0..16, y=0..8 either way.
		rect = Rect2(
			Vector2(0, 0),
			Vector2(CELL_SIZE * 2, CELL_SIZE)
		)

	else:

		region = (
			GHOST_VERTICAL_FRAME_1
			if frame == 1
			else GHOST_VERTICAL_FRAME_0
		)

		# Bounding box is the same whether it's DOWN or UP --
		# both halves span x=0..8, y=-8..8 either way.
		rect = Rect2(
			Vector2(0, -CELL_SIZE),
			Vector2(CELL_SIZE, CELL_SIZE * 2)
		)


	draw_texture_rect_region(
		ghost_sprite_texture,
		rect,
		region
	)


func _draw_tether() -> void:

	if tether_sprite_texture == null:
		return


	var region_1: Rect2
	var region_2: Rect2

	var position_1 := Vector2.ZERO
	var position_2 := Vector2.ZERO


	match orientation:

		Orientation.RIGHT:

			region_1 = TETHER_HORIZONTAL_LEFT
			region_2 = TETHER_HORIZONTAL_RIGHT

			position_1 = Vector2(0, 0)
			position_2 = Vector2(CELL_SIZE, 0)


		Orientation.LEFT:

			region_1 = TETHER_HORIZONTAL_LEFT
			region_2 = TETHER_HORIZONTAL_RIGHT

			position_1 = Vector2(0, 0)
			position_2 = Vector2(CELL_SIZE, 0)


		Orientation.DOWN:

			region_1 = TETHER_VERTICAL_TOP
			region_2 = TETHER_VERTICAL_BOTTOM

			position_1 = Vector2(0, -CELL_SIZE)
			position_2 = Vector2(0, 0)


		Orientation.UP:

			region_1 = TETHER_VERTICAL_BOTTOM
			region_2 = TETHER_VERTICAL_TOP

			position_1 = Vector2(0, 0)
			position_2 = Vector2(0, -CELL_SIZE)


	draw_texture_rect_region(
		tether_sprite_texture,
		Rect2(
			position_1,
			Vector2(CELL_SIZE, CELL_SIZE)
		),
		region_1
	)


	draw_texture_rect_region(
		tether_sprite_texture,
		Rect2(
			position_2,
			Vector2(CELL_SIZE, CELL_SIZE)
		),
		region_2
	)


func _draw_shift() -> void:

	if shift_sprite_texture == null:
		return


	var is_vertical := (
		orientation == Orientation.UP
		or orientation == Orientation.DOWN
	)


	var region: Rect2
	var dest_position: Vector2
	var dest_size: Vector2


	if is_vertical:

		dest_position = Vector2(0, -CELL_SIZE)
		dest_size = Vector2(CELL_SIZE, CELL_SIZE * 2)

		if shift_vanishing:

			region = SHIFT_VANISH_VERTICAL

		elif orientation == Orientation.UP:

			region = SHIFT_UP

		else:

			region = SHIFT_DOWN

	else:

		dest_position = Vector2(0, 0)
		dest_size = Vector2(CELL_SIZE * 2, CELL_SIZE)

		if shift_vanishing:

			region = SHIFT_VANISH_HORIZONTAL

		elif orientation == Orientation.LEFT:

			region = SHIFT_LEFT

		else:

			region = SHIFT_RIGHT


	draw_texture_rect_region(
		shift_sprite_texture,
		Rect2(
			dest_position,
			dest_size
		),
		region
	)


# ============================================================
# GRID POSITION
# ============================================================

# grid_position is the BOTTOM-LEFT cell of the pill footprint.
#
# RIGHT:
# [0][1]
#
# DOWN:
# [0]
# [1] ← origin
#
# LEFT:
# [0][1]
#
# UP:
# [0]
# [1] ← origin

func get_occupied_cells(
	grid_position: Vector2i
) -> Array[Vector2i]:

	var cells: Array[Vector2i] = []


	match orientation:

		Orientation.RIGHT:

			cells.append(grid_position)
			cells.append(
				grid_position + Vector2i(1, 0)
			)


		Orientation.DOWN:

			cells.append(
				grid_position + Vector2i(0, -1)
			)

			cells.append(grid_position)


		Orientation.LEFT:

			cells.append(grid_position)

			cells.append(
				grid_position + Vector2i(1, 0)
			)


		Orientation.UP:

			cells.append(grid_position)

			cells.append(
				grid_position + Vector2i(0, -1)
			)


	return cells


func get_half_1_cell(
	grid_position: Vector2i
) -> Vector2i:

	match orientation:

		Orientation.RIGHT:
			return grid_position


		Orientation.DOWN:
			return grid_position + Vector2i(0, -1)


		Orientation.LEFT:
			return grid_position + Vector2i(1, 0)


		Orientation.UP:
			return grid_position


	return grid_position


func get_half_2_cell(
	grid_position: Vector2i
) -> Vector2i:

	match orientation:

		Orientation.RIGHT:
			return grid_position + Vector2i(1, 0)


		Orientation.DOWN:
			return grid_position


		Orientation.LEFT:
			return grid_position


		Orientation.UP:
			return grid_position + Vector2i(0, -1)


	return grid_position


# ============================================================
# ROTATION
# ============================================================

func get_rotated_orientation() -> int:

	return (orientation + 1) % 4


func rotate_pill() -> void:

	orientation = get_rotated_orientation()


# ============================================================
# SEPARATION / VANISHING
# ============================================================

func separate() -> void:

	var half_1 := get_node_or_null("Half1") as PillHalf
	var half_2 := get_node_or_null("Half2") as PillHalf


	if half_1 == null or half_2 == null:
		return


	half_1.pill_state = PillHalf.PillState.SEPARATED
	half_2.pill_state = PillHalf.PillState.SEPARATED


func vanish_half(
	which_half: int
) -> void:

	var half_1 := get_node_or_null("Half1") as PillHalf
	var half_2 := get_node_or_null("Half2") as PillHalf


	if half_1 == null or half_2 == null:
		return


	if which_half == 1:

		half_1.pill_state = (
			PillHalf.PillState.VANISHING
		)


	elif which_half == 2:

		half_2.pill_state = (
			PillHalf.PillState.VANISHING
		)
