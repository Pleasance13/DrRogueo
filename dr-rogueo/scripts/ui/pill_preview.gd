class_name PillPreview
extends Node2D


# ============================================================
# PILL PREVIEW (MARIO + THROW)
# ============================================================
#
# Owns both:
#   - Mario's throw / game-over sprite animation
#   - The pill/item "throw" arc from the preview box out to
#     its spawn cell on the board
#
# mario-pill-preview.png top row, 4x 40x40 frames:
#
#   0: idle / pill preview (default)
#   1: throw frame 1
#   2: throw frame 2
#   3: game over (loss only -- sticks, never reverts)
#
# Pill "rotation" during the throw is NOT a smooth transform
# spin -- pills are pixel art built from two 8x8 half-sprites,
# so an arbitrary-angle Node2D.rotation would look wrong
# (sub-pixel positions, mismatched silhouette). Instead this
# steps through the pill's own 4 orientation frames (RIGHT /
# DOWN / LEFT / UP) -- the exact same states the player cycles
# through by pressing rotate -- timed evenly across the throw.
#
# ============================================================

enum RotationDirection {
	CLOCKWISE,
	COUNTER_CLOCKWISE
}


@export var mario_path: NodePath = NodePath("PreviewBox/Mario")
@export var throw_origin_path: NodePath = NodePath("ThrowOrigin")

const FRAME_SIZE := 40

const FRAME_IDLE := 0
const FRAME_THROW_1 := 1
const FRAME_THROW_2 := 2
const FRAME_GAME_OVER := 3

@export_range(0.01, 1.0, 0.01)
var throw_frame_duration := 0.1


@export_group("Pill Throw")

@export_range(0.5, 20.0, 0.5)
var throw_rotations: float = 5.0

@export_range(0.0, 32.0, 1.0)
var throw_arc_height: float = 10.0

@export var throw_rotation_direction: RotationDirection = (
	RotationDirection.CLOCKWISE
)


var _mario_sprite: Sprite2D
var _throw_origin: Node2D

var _game_over_active := false

var _throw_active := false
var _throw_timer := 0.0
var _throw_frame_index := 0


# ============================================================
# LIFECYCLE
# ============================================================

func _ready() -> void:

	_mario_sprite = get_node_or_null(mario_path) as Sprite2D
	_throw_origin = get_node_or_null(throw_origin_path) as Node2D

	if _mario_sprite == null:

		push_warning(
			"PillPreview: could not find Mario sprite at: "
			+ str(mario_path)
		)

	if _throw_origin == null:

		push_warning(
			"PillPreview: could not find ThrowOrigin at: "
			+ str(throw_origin_path)
			+ " -- falling back to PillPreview's own position."
		)

	_set_frame(FRAME_IDLE)


func _process(delta: float) -> void:

	if not _throw_active:
		return

	_throw_timer += delta

	if _throw_timer < throw_frame_duration:
		return

	_throw_timer -= throw_frame_duration

	_throw_frame_index += 1

	if _throw_frame_index >= 2:

		_throw_active = false

		_set_frame(FRAME_IDLE)

		return

	_set_frame(FRAME_THROW_1 + _throw_frame_index)


# ============================================================
# MARIO THROW ANIM
# ============================================================

func _play_mario_throw() -> void:

	if _game_over_active:
		return

	_throw_active = true
	_throw_timer = 0.0
	_throw_frame_index = 0

	_set_frame(FRAME_THROW_1)


# ============================================================
# GAME OVER (LOSS ONLY)
# ============================================================

func play_game_over() -> void:

	_game_over_active = true
	_throw_active = false

	_set_frame(FRAME_GAME_OVER)


# ============================================================
# SET FRAME
# ============================================================

func _set_frame(frame_index: int) -> void:

	if _mario_sprite == null:
		return

	_mario_sprite.region_rect = Rect2(
		frame_index * FRAME_SIZE,
		0,
		FRAME_SIZE,
		FRAME_SIZE
	)


# ============================================================
# THROW TIMING / ORIGIN
# ============================================================

func get_throw_duration() -> float:

	return throw_frame_duration * 2.0


func get_throw_start_position() -> Vector2:

	if _throw_origin != null:
		return _throw_origin.global_position

	return global_position

# ============================================================
# THROW -- PILL (steps through orientation frames)
# ============================================================

func throw_pill(
	pill: Pill,
	target_global: Vector2
) -> void:

	if pill == null or not is_instance_valid(pill):
		return


	_play_mario_throw()


	var start_global := get_throw_start_position()
	var duration := get_throw_duration()

	var starting_orientation := pill.orientation

	var step_direction := (
		1
		if throw_rotation_direction == RotationDirection.CLOCKWISE
		else 3 # equivalent to -1 mod 4
	)

	var total_steps: int = maxi(
		1,
		int(round(throw_rotations * 4.0))
	)

	var step_interval := duration / float(total_steps)


	pill.global_position = start_global


	if duration <= 0.0:

		pill.orientation = starting_orientation
		pill.global_position = target_global

		return


	var elapsed := 0.0
	var step_timer := 0.0
	var steps_taken := 0


	while elapsed < duration:

		await get_tree().process_frame

		if not is_instance_valid(pill):
			return

		var delta := get_process_delta_time()

		elapsed += delta
		step_timer += delta


		var t: float = clamp(elapsed / duration, 0.0, 1.0)

		var base := start_global.lerp(target_global, t)

		var arc_offset := -throw_arc_height * sin(PI * t)

		pill.global_position = Vector2(
			floor(base.x),
			floor(base.y + arc_offset)
		)


		while (
			step_timer >= step_interval
			and steps_taken < total_steps
		):

			step_timer -= step_interval
			steps_taken += 1

			pill.orientation = (
				pill.orientation + step_direction
			) % 4


	if not is_instance_valid(pill):
		return

	pill.global_position = target_global

	# Always land back on the pill's original orientation --
	# the spin is a visual flourish, never a real state change.
	pill.orientation = starting_orientation


# ============================================================
# THROW -- PLAIN ICON (no rotation frames, e.g. Pong)
# ============================================================

func throw_icon(
	icon: Node2D,
	target_global: Vector2
) -> void:

	if icon == null or not is_instance_valid(icon):
		return


	_play_mario_throw()


	var start_global := get_throw_start_position()
	var duration := get_throw_duration()


	icon.global_position = start_global


	if duration <= 0.0:

		icon.global_position = target_global
		return


	var elapsed := 0.0


	while elapsed < duration:

		await get_tree().process_frame

		if not is_instance_valid(icon):
			return

		elapsed += get_process_delta_time()

		var t: float = clamp(elapsed / duration, 0.0, 1.0)

		var base := start_global.lerp(target_global, t)

		var arc_offset := -throw_arc_height * sin(PI * t)

		icon.global_position = Vector2(
			floor(base.x),
			floor(base.y + arc_offset)
		)


	if not is_instance_valid(icon):
		return

	icon.global_position = target_global
