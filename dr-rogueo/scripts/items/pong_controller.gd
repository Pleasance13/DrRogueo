class_name PongController
extends Node2D


# ============================================================
# PONG PADDLE (minigame controller)
# ============================================================


var board: DrRogueoBoard


# ============================================================
# TUNING
# ============================================================

const PADDLE_WIDTH := 24.0
const PADDLE_HEIGHT := 8.0

const BALL_RADIUS := 4.0

const PADDLE_SPEED := 80.0
const BALL_LAUNCH_VY := 90.0
const BALL_LAUNCH_VX_RANGE := 35.0

const MAX_STEP_DISTANCE := DrRogueoBoard.CELL_SIZE / 3.0

const HIT_COOLDOWN := 0.25
const COMBO_TIMER_DURATION := 5.0

const PADDLE_MAX_BOUNCE_ANGLE_DEG := 60.0

# Prevents the ball from getting stuck in a long, near-horizontal
# wall-to-wall loop. Walls (unlike cells or the paddle) never
# perturb the bounce angle - they just flip one axis - so nothing
# else naturally breaks a shallow angle out of that pattern.
const MIN_WALL_BOUNCE_ANGLE_DEG := 20.0


# ============================================================
# STATE
# ============================================================

var paddle_x := 0.0
var paddle_y := 0.0

var ball_released := false
var ball_position := Vector2.ZERO
var ball_velocity := Vector2.ZERO

var hit_cooldowns: Dictionary = {}

var combo_timer := -1.0

var active := false


# ============================================================
# SPRITES
# ============================================================

# This Control acts purely as a visual clipping mask.
# Its rectangle exactly matches the board, so Pong objects can
# logically cross the Pacman wrap boundary without ever being
# drawn outside the board.
var clip_container: Control

var paddle_sprite: Sprite2D
var ball_sprite: Sprite2D

# "Ghost" copies shown only while the real sprite overlaps a
# board edge under the Pacman trait, offset by one board-width
# so the sprite appears to continuously pass through the wall
# rather than teleport.
var paddle_ghost_sprite: Sprite2D
var ball_ghost_sprite: Sprite2D


# ============================================================
# TIMER
# ============================================================

var _expiring := false


# ============================================================
# LIFECYCLE
# ============================================================

func start(p_board: DrRogueoBoard) -> void:

	board = p_board

	active = true

	_setup_sprites()

	var bounds := board.get_board_pixel_rect()

	paddle_x = (
		bounds.position.x +
		(bounds.size.x - PADDLE_WIDTH) / 2.0
	)

	paddle_y = board.grid_to_local(
		Vector2i(0, 1)
	).y

	ball_released = false

	combo_timer = -1.0

	hit_cooldowns.clear()

	_expiring = false

	_update_paddle_sprite()

	# --------------------------------------------------------
	# SHOW REUSABLE ITEM TIMER
	# --------------------------------------------------------

	_set_timer_visible(true)

	# Start at a completely full timer.
	_update_timer_visual()


# ============================================================
# PACMAN WRAP
# ============================================================

func _pacman_active() -> bool:

	if board == null:
		return false

	if not is_instance_valid(board):
		return false

	return board.has_pacman_trait()


# Keeps a continuous logical x position from drifting more than
# a board-width beyond the visible range, without ever snapping
# it into a fully "clamped" state -- it can still float slightly
# past either edge so the clipping container can hide the part
# outside the board.
func _wrap_position_x(x: float, bounds: Rect2) -> float:

	var left: float = bounds.position.x
	var width: float = bounds.size.x

	if x < left - width * 0.5:
		return x + width

	if x > left + width * 1.5:
		return x - width

	return x


# Given a value and a reference point it's being compared
# against, returns whichever of {value, value - board_width,
# value + board_width} sits closest to the reference. Used so
# paddle-catch and cell collision still work correctly while
# the ball is floating in "extended" coordinate space near a
# wrap boundary.
func _nearest_wrapped_x(
	value: float,
	reference: float,
	board_width: float
) -> float:

	var best: float = value
	var best_dist: float = abs(value - reference)

	var candidate_low: float = value - board_width
	var dist_low: float = abs(candidate_low - reference)

	if dist_low < best_dist:
		best = candidate_low
		best_dist = dist_low

	var candidate_high: float = value + board_width
	var dist_high: float = abs(candidate_high - reference)

	if dist_high < best_dist:
		best = candidate_high
		best_dist = dist_high

	return best


# ============================================================
# TIMER DISPLAY
# ============================================================

func _set_timer_visible(visible: bool) -> void:

	if board == null:
		return

	if not is_instance_valid(board):
		return

	var items := board.get_node_or_null("Items")

	if items == null:
		return

	if not is_instance_valid(items):
		return

	if items.has_method("set_timer_visible"):

		items.set_timer_visible(visible)


func _update_timer_visual() -> void:

	if board == null:
		return

	if not is_instance_valid(board):
		return

	var items := board.get_node_or_null("Items")

	if items == null:
		return

	if not is_instance_valid(items):
		return

	if items.has_method("set_timer_progress"):

		var progress: float = 1.0

		if combo_timer >= 0.0:

			progress = clamp(
				combo_timer / COMBO_TIMER_DURATION,
				0.0,
				1.0
			)

		items.set_timer_progress(progress)


# ============================================================
# SPRITE SETUP
# ============================================================

func _setup_sprites() -> void:

	# --------------------------------------------------------
	# CLIPPING CONTAINER
	# --------------------------------------------------------
	#
	# The container sits exactly over the board's pixel
	# rectangle. clip_contents causes everything inside it to
	# be visually cut off at the board edges.
	#
	# The Pong sprites are children of this Control, so they can
	# still move beyond its boundaries while only the portion
	# inside the board is rendered.
	# --------------------------------------------------------

	clip_container = Control.new()

	var bounds := board.get_board_pixel_rect()

	clip_container.position = bounds.position
	clip_container.size = bounds.size

	clip_container.clip_contents = true

	add_child(clip_container)


	# --------------------------------------------------------
	# PADDLE
	# --------------------------------------------------------

	paddle_sprite = Sprite2D.new()

	paddle_sprite.texture = board.pong_sprite_texture

	paddle_sprite.centered = false

	paddle_sprite.region_enabled = true

	paddle_sprite.region_rect = Rect2(
		0,
		0,
		PADDLE_WIDTH,
		PADDLE_HEIGHT
	)

	clip_container.add_child(paddle_sprite)


	# --------------------------------------------------------
	# PADDLE GHOST
	# --------------------------------------------------------

	paddle_ghost_sprite = Sprite2D.new()

	paddle_ghost_sprite.texture = board.pong_sprite_texture

	paddle_ghost_sprite.centered = false

	paddle_ghost_sprite.region_enabled = true

	paddle_ghost_sprite.region_rect = Rect2(
		0,
		0,
		PADDLE_WIDTH,
		PADDLE_HEIGHT
	)

	paddle_ghost_sprite.visible = false

	clip_container.add_child(paddle_ghost_sprite)


	# --------------------------------------------------------
	# BALL
	# --------------------------------------------------------

	ball_sprite = Sprite2D.new()

	ball_sprite.texture = board.pong_sprite_texture

	ball_sprite.centered = true

	ball_sprite.region_enabled = true

	ball_sprite.region_rect = Rect2(
		0,
		16,
		BALL_RADIUS * 2.0,
		BALL_RADIUS * 2.0
	)

	ball_sprite.visible = false

	clip_container.add_child(ball_sprite)


	# --------------------------------------------------------
	# BALL GHOST
	# --------------------------------------------------------

	ball_ghost_sprite = Sprite2D.new()

	ball_ghost_sprite.texture = board.pong_sprite_texture

	ball_ghost_sprite.centered = true

	ball_ghost_sprite.region_enabled = true

	ball_ghost_sprite.region_rect = Rect2(
		0,
		16,
		BALL_RADIUS * 2.0,
		BALL_RADIUS * 2.0
	)

	ball_ghost_sprite.visible = false

	clip_container.add_child(ball_ghost_sprite)


func is_active() -> bool:

	return active


# ============================================================
# PROCESS
# ============================================================

func _process(delta: float) -> void:

	if not active:
		return


	_update_input()


	# Keep the timer visualized even before the ball launches.
	_update_timer_visual()


	if not ball_released:
		return


	_update_combo_timer(delta)

	if not active:
		return


	_update_hit_cooldowns(delta)

	_step_ball(delta)

	if active:

		_update_ball_sprite()

		_update_vanishing_frames()


# ============================================================
# INPUT
# ============================================================

func _update_input() -> void:

	var delta := get_process_delta_time()

	var bounds := board.get_board_pixel_rect()


	if Input.is_action_pressed("ui_left"):

		paddle_x -= PADDLE_SPEED * delta


	if Input.is_action_pressed("ui_right"):

		paddle_x += PADDLE_SPEED * delta


	if _pacman_active():

		paddle_x = _wrap_position_x(paddle_x, bounds)

	else:

		paddle_x = clamp(
			paddle_x,
			bounds.position.x,
			bounds.position.x +
			bounds.size.x -
			PADDLE_WIDTH
		)


	_update_paddle_sprite()


	if (
		not ball_released
		and Input.is_action_just_pressed("ui_down")
	):

		_release_ball()


func _release_ball() -> void:

	ball_released = true

	ball_position = Vector2(
		paddle_x +
		PADDLE_WIDTH / 2.0,
		paddle_y +
		PADDLE_HEIGHT +
		BALL_RADIUS +
		2.0
	)

	ball_velocity = Vector2(
		randf_range(
			-BALL_LAUNCH_VX_RANGE,
			BALL_LAUNCH_VX_RANGE
		),
		BALL_LAUNCH_VY
	)

	ball_sprite.visible = true

	_update_ball_sprite()


# ============================================================
# COMBO TIMER
# ============================================================

func _update_combo_timer(delta: float) -> void:

	if combo_timer < 0.0:
		return


	combo_timer -= delta

	_update_timer_visual()


	if combo_timer <= 0.0:

		_miss()


# ============================================================
# HIT COOLDOWNS
# ============================================================

func _update_hit_cooldowns(delta: float) -> void:

	for cell in hit_cooldowns.keys():

		hit_cooldowns[cell] -= delta

		if hit_cooldowns[cell] <= 0.0:

			hit_cooldowns.erase(cell)


# ============================================================
# BALL PHYSICS
# ============================================================

func _step_ball(delta: float) -> void:

	var bounds := board.get_board_pixel_rect()

	var pacman_wrap: bool = _pacman_active()

	var total_distance := (
		ball_velocity.length() * delta
	)

	var steps: Variant = max(
		1,
		int(
			ceil(
				total_distance /
				MAX_STEP_DISTANCE
			)
		)
	)

	var step_dt := (
		delta / float(steps)
	)


	for step in range(steps):

		ball_position += (
			ball_velocity * step_dt
		)


		# ----------------------------------------------------
		# HORIZONTAL WALLS / PACMAN WRAP
		# ----------------------------------------------------

		if pacman_wrap:

			# Pass through instead of bouncing -- the ball is
			# allowed to float slightly beyond either edge.
			# The clipping container hides the part outside
			# the board while the ghost sprite shows the
			# corresponding part entering from the other side.
			ball_position.x = _wrap_position_x(
				ball_position.x,
				bounds
			)

		else:

			if (
				ball_position.x - BALL_RADIUS <
				bounds.position.x
			):

				ball_position.x = (
					bounds.position.x +
					BALL_RADIUS
				)

				ball_velocity.x = -ball_velocity.x

				ball_velocity = _steepen_shallow_wall_bounce(
					ball_velocity
				)


			if (
				ball_position.x + BALL_RADIUS >
				bounds.position.x +
				bounds.size.x
			):

				ball_position.x = (
					bounds.position.x +
					bounds.size.x -
					BALL_RADIUS
				)

				ball_velocity.x = -ball_velocity.x

				ball_velocity = _steepen_shallow_wall_bounce(
					ball_velocity
				)


		# ----------------------------------------------------
		# FLOOR (unaffected by Pacman -- vertical never wraps)
		# ----------------------------------------------------

		if (
			ball_position.y + BALL_RADIUS >
			bounds.position.y +
			bounds.size.y
		):

			ball_position.y = (
				bounds.position.y +
				bounds.size.y -
				BALL_RADIUS
			)

			ball_velocity.y = -ball_velocity.y


		# ----------------------------------------------------
		# PADDLE CATCH
		# ----------------------------------------------------

		if ball_velocity.y < 0.0:

			# While wrapping, compare against whichever copy of
			# the ball's x (real / -width / +width) is actually
			# closest to the paddle.
			var check_x: float = ball_position.x

			if pacman_wrap:

				check_x = _nearest_wrapped_x(
					ball_position.x,
					paddle_x + PADDLE_WIDTH / 2.0,
					bounds.size.x
				)


			var paddle_closest: Vector2 = Vector2(
				clamp(
					check_x,
					paddle_x,
					paddle_x + PADDLE_WIDTH
				),
				clamp(
					ball_position.y,
					paddle_y,
					paddle_y + PADDLE_HEIGHT
				)
			)

			var paddle_offset: Vector2 = (
				Vector2(check_x, ball_position.y) - paddle_closest
			)

			var paddle_dist: float = paddle_offset.length()

			if paddle_dist <= BALL_RADIUS:

				# A genuine face hit is when the ball's x is
				# already within the paddle's width.
				var hit_face: bool = (
					check_x >= paddle_x
					and
					check_x <=
					paddle_x + PADDLE_WIDTH
				)

				if hit_face:

					var hit_pos: float = clamp(
						(
							check_x -
							(
								paddle_x +
								PADDLE_WIDTH / 2.0
							)
						)
						/
						(PADDLE_WIDTH / 2.0),
						-1.0,
						1.0
					)

					var incoming_speed: float = (
						ball_velocity.length()
					)

					var speed: float = (
						incoming_speed
						if incoming_speed > 0.0
						else BALL_LAUNCH_VY
					)

					var max_bounce_angle: float = deg_to_rad(
						PADDLE_MAX_BOUNCE_ANGLE_DEG
					)

					var angle: float = (
						hit_pos * max_bounce_angle
					)

					# Paddle sits near the TOP of the board,
					# so "away from paddle" is +y (downward).
					ball_velocity = Vector2(
						sin(angle) * speed,
						cos(angle) * speed
					)

					ball_position.y = (
						paddle_y +
						PADDLE_HEIGHT +
						BALL_RADIUS +
						1.0
					)

				else:

					# Side/corner graze.
					var paddle_normal: Vector2 = (
						paddle_offset / paddle_dist
						if paddle_dist > 0.0001
						else Vector2(0.0, 1.0)
					)

					if (
						ball_velocity.dot(paddle_normal)
						< 0.0
					):

						ball_velocity = (
							ball_velocity.bounce(
								paddle_normal
							)
						)

					var paddle_overlap: float = (
						BALL_RADIUS - paddle_dist
					)

					if paddle_overlap > 0.0:

						ball_position += (
							paddle_normal *
							(paddle_overlap + 1.0)
						)


		# ----------------------------------------------------
		# MISS
		# ----------------------------------------------------

		if (
			ball_velocity.y < 0.0
			and
			ball_position.y - BALL_RADIUS <
			paddle_y
		):

			_miss()

			return


		# ----------------------------------------------------
		# CELL COLLISION
		# ----------------------------------------------------

		_check_cell_collision()

		if not active:
			return


# ============================================================
# WALL BOUNCE ANGLE
# ============================================================

func _steepen_shallow_wall_bounce(
	velocity: Vector2
) -> Vector2:

	var speed: float = velocity.length()

	if speed <= 0.0:
		return velocity

	var min_ratio: float = sin(
		deg_to_rad(MIN_WALL_BOUNCE_ANGLE_DEG)
	)

	var vy_ratio: float = abs(velocity.y) / speed

	if vy_ratio >= min_ratio:
		return velocity

	# Ball moving perfectly horizontal (vy == 0.0) has no sign
	# to preserve - default to heading back down into the board.
	var vy_sign: float = (
		1.0 if velocity.y >= 0.0 else -1.0
	)

	var vx_sign: float = (
		1.0 if velocity.x >= 0.0 else -1.0
	)

	var new_vy: float = speed * min_ratio * vy_sign

	var new_vx_mag: float = sqrt(
		max(speed * speed - new_vy * new_vy, 0.0)
	)

	return Vector2(
		new_vx_mag * vx_sign,
		new_vy
	)


# ============================================================
# CELL COLLISION
# ============================================================

func _check_cell_collision() -> void:

	var pacman_wrap: bool = _pacman_active()

	var min_cell := board.local_to_grid(
		ball_position -
		Vector2(BALL_RADIUS, BALL_RADIUS)
	)

	var max_cell := board.local_to_grid(
		ball_position +
		Vector2(BALL_RADIUS, BALL_RADIUS)
	)


	for row in range(
		min_cell.y,
		max_cell.y + 1
	):

		for col in range(
			min_cell.x,
			max_cell.x + 1
		):

			var raw_cell := Vector2i(col, row)

			var cell := raw_cell

			if pacman_wrap:

				cell = board.wrap_cell_if_needed(raw_cell)


			if not board.is_cell_filled(cell):
				continue


			var cell_size := float(DrRogueoBoard.CELL_SIZE)

			var cell_top_left := board.grid_to_local(cell)


			if pacman_wrap:

				cell_top_left.x = _nearest_wrapped_x(
					cell_top_left.x,
					ball_position.x,
					board.get_board_pixel_rect().size.x
				)


			var closest := Vector2(
				clamp(
					ball_position.x,
					cell_top_left.x,
					cell_top_left.x + cell_size
				),
				clamp(
					ball_position.y,
					cell_top_left.y,
					cell_top_left.y + cell_size
				)
			)


			var offset := (
				ball_position - closest
			)

			var dist := offset.length()


			if dist > BALL_RADIUS:
				continue


			# ------------------------------------------------
			# DAMAGE
			# ------------------------------------------------

			if not hit_cooldowns.has(cell):

				hit_cooldowns[cell] = HIT_COOLDOWN

				var broke := (
					board.pong_break_cell(cell)
				)


				if broke:

					combo_timer = (
						COMBO_TIMER_DURATION
					)

					_update_timer_visual()


			# ------------------------------------------------
			# BOUNCE
			# ------------------------------------------------

			var normal := (
				offset / dist
				if dist > 0.0001
				else Vector2(0.0, -1.0)
			)

			if ball_velocity.dot(normal) < 0.0:

				ball_velocity = (
					ball_velocity.bounce(normal)
				)

			var overlap := (
				BALL_RADIUS - dist
			)

			if overlap > 0.0:

				ball_position += (
					normal *
					(overlap + 1.0)
				)

			return


# ============================================================
# SPRITES
# ============================================================

func _update_paddle_sprite() -> void:

	if paddle_sprite == null:
		return

	if clip_container == null:
		return

	var bounds := board.get_board_pixel_rect()

	# Sprite positions are relative to the clipping container,
	# whose origin is the board's top-left corner.
	paddle_sprite.position = Vector2(
		paddle_x - bounds.position.x,
		paddle_y - bounds.position.y
	)


	if not _pacman_active():

		if paddle_ghost_sprite != null:

			paddle_ghost_sprite.visible = false

		return


	var width := bounds.size.x

	var ghost_x: float = 0.0

	var needs_ghost := false


	if paddle_x < bounds.position.x:

		ghost_x = paddle_x + width

		needs_ghost = true

	elif paddle_x + PADDLE_WIDTH > bounds.position.x + width:

		ghost_x = paddle_x - width

		needs_ghost = true


	if paddle_ghost_sprite == null:
		return


	if needs_ghost:

		paddle_ghost_sprite.position = Vector2(
			ghost_x - bounds.position.x,
			paddle_y - bounds.position.y
		)

		paddle_ghost_sprite.visible = true

	else:

		paddle_ghost_sprite.visible = false


func _update_ball_sprite() -> void:

	if ball_sprite == null:
		return

	if clip_container == null:
		return

	var bounds := board.get_board_pixel_rect()

	# Sprite position is relative to the clipping container.
	ball_sprite.position = (
		ball_position - bounds.position
	)


	if not _pacman_active():

		if ball_ghost_sprite != null:

			ball_ghost_sprite.visible = false

		return


	var width := bounds.size.x

	var ghost_x: float = 0.0

	var needs_ghost := false


	if ball_position.x - BALL_RADIUS < bounds.position.x:

		ghost_x = ball_position.x + width

		needs_ghost = true

	elif ball_position.x + BALL_RADIUS > bounds.position.x + width:

		ghost_x = ball_position.x - width

		needs_ghost = true


	if ball_ghost_sprite == null:
		return


	if needs_ghost:

		ball_ghost_sprite.position = Vector2(
			ghost_x - bounds.position.x,
			ball_position.y - bounds.position.y
		)

		ball_ghost_sprite.visible = ball_sprite.visible

	else:

		ball_ghost_sprite.visible = false


# ============================================================
# VANISHING FRAMES
# ============================================================

func set_expiring(expiring: bool) -> void:

	if expiring == _expiring:
		return


	_expiring = expiring


	if paddle_sprite != null:

		paddle_sprite.region_rect.position.y = (
			PADDLE_HEIGHT
			if expiring
			else 0.0
		)

	if paddle_ghost_sprite != null:

		paddle_ghost_sprite.region_rect.position.y = (
			PADDLE_HEIGHT
			if expiring
			else 0.0
		)


	if ball_sprite != null:

		ball_sprite.region_rect.position.x = (
			BALL_RADIUS * 2.0
			if expiring
			else 0.0
		)

	if ball_ghost_sprite != null:

		ball_ghost_sprite.region_rect.position.x = (
			BALL_RADIUS * 2.0
			if expiring
			else 0.0
		)


func _update_vanishing_frames() -> void:

	pass


# ============================================================
# ENDING
# ============================================================

func _cleanup_sprites() -> void:

	if paddle_sprite != null:

		paddle_sprite.queue_free()

		paddle_sprite = null

	if paddle_ghost_sprite != null:

		paddle_ghost_sprite.queue_free()

		paddle_ghost_sprite = null


	if ball_sprite != null:

		ball_sprite.queue_free()

		ball_sprite = null

	if ball_ghost_sprite != null:

		ball_ghost_sprite.queue_free()

		ball_ghost_sprite = null


	if clip_container != null:

		clip_container.queue_free()

		clip_container = null


func stop() -> void:

	if not active:
		return

	active = false

	_cleanup_sprites()

	queue_free()


func _miss() -> void:

	active = false

	# Hide the reusable timer when Pong naturally ends.
	_set_timer_visible(false)

	_cleanup_sprites()

	var b := board

	queue_free()

	if b != null:

		b.on_pong_missed()
