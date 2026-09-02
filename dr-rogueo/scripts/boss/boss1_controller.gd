@tool
class_name Boss1Controller
extends Node2D


signal defeated_changed(is_defeated: bool)


const MAX_HEALTH := 8
const INDICATOR_TEXTURE_PATH := "res://art/board/boss_color_indicators.png"
const BOSS_TEXTURE_PATH := "res://art/viruses/boss_1.png"
const X_TEXTURE_PATH := "res://art/ui/x.png"

const CELL_SIZE := 8
const INDICATOR_FRAME_SIZE := 8

const DAMAGE_FLASH_DURATION := 0.45
const DEATH_FRAME_DURATION := 0.45

const MAGNIFIER_GROUP := "boss_magnifier_slot"
const GRADIENT_TEXTURE_PATH := "res://art/ui/magnifier_gradient.png"
const MAGNIFIER_BOSS_TEXTURE_PATH := "res://art/viruses/boss_1_magnifier.png"


var board: DrRogueoBoard

var health := MAX_HEALTH
var defeated := false
var busy := false

var left_cells: Array[Vector2i] = []
var right_cells: Array[Vector2i] = []

var indicator_colors: Dictionary = {}
var indicator_sprites: Dictionary = {}

var x_sprites: Dictionary = {}
var x_active: Dictionary = {}

var boss_sprite: Sprite2D
var boss_anim_frame := 0

var healthbar: Boss1Healthbar

var _magnifier_root: Node2D
var _magnifier_boss: Sprite2D


# ============================================================
# MAGNIFIER POSITIONS
# ============================================================

@export_category("Magnifier Positions")

@export var magnifier_gradient_position: Vector2 = Vector2.ZERO
@export var magnifier_boss_position: Vector2 = Vector2.ZERO
@export var magnifier_healthbar_position: Vector2 = Vector2.ZERO


# ============================================================
# MAGNIFIER PREVIEW
# ============================================================

@export_category("Magnifier Preview")

@export_range(0, 5, 1)
var magnifier_boss_frame: int = 0

@export_range(0, 8, 1)
var magnifier_health: int = 8


var _editor_magnifier_root: Node2D
var _editor_magnifier_gradient: Sprite2D
var _editor_magnifier_boss: Sprite2D
var _editor_magnifier_healthbar: Boss1Healthbar


# ============================================================
# READY / EDITOR
# ============================================================

func _ready() -> void:

	if Engine.is_editor_hint():
		call_deferred("_create_editor_magnifier_preview")


func _process(_delta: float) -> void:

	if not Engine.is_editor_hint():
		return

	if (
		_editor_magnifier_root == null
		or not is_instance_valid(_editor_magnifier_root)
	):
		_create_editor_magnifier_preview()
		return

	_update_editor_magnifier()


# ============================================================
# START BOSS
# ============================================================

func start(
	p_board: DrRogueoBoard,
	boss_col: int,
	boss_row: int
) -> void:

	_reset_runtime_boss()

	board = p_board
	health = MAX_HEALTH
	defeated = false
	busy = false
	boss_anim_frame = 0

	_build_indicator_cell_lists(boss_col)

	_create_boss_sprite(
		boss_col,
		boss_row
	)

	_create_indicator_sprites()
	_create_x_sprites()

	_roll_new_indicators()

	if not AnimClock.frame_changed.is_connected(
		_on_anim_frame_changed
	):
		AnimClock.frame_changed.connect(
			_on_anim_frame_changed
	)

	_create_magnifier_display()


# ============================================================
# RESET RUNTIME BOSS
# ============================================================

func _reset_runtime_boss() -> void:

	if AnimClock.frame_changed.is_connected(
		_on_anim_frame_changed
	):
		AnimClock.frame_changed.disconnect(
			_on_anim_frame_changed
	)

	if AnimClock.frame_changed.is_connected(
		_on_magnifier_frame_changed
	):
		AnimClock.frame_changed.disconnect(
			_on_magnifier_frame_changed
	)

	if boss_sprite != null and is_instance_valid(boss_sprite):
		boss_sprite.queue_free()

	boss_sprite = null

	for sprite in indicator_sprites.values():

		if is_instance_valid(sprite):
			sprite.queue_free()

	indicator_sprites.clear()

	for sprite in x_sprites.values():

		if is_instance_valid(sprite):
			sprite.queue_free()

	x_sprites.clear()
	x_active.clear()

	if (
		_magnifier_root != null
		and is_instance_valid(_magnifier_root)
	):
		_magnifier_root.queue_free()

	_magnifier_root = null
	_magnifier_boss = null

	healthbar = null

	left_cells.clear()
	right_cells.clear()
	indicator_colors.clear()


# ============================================================
# BUILD INDICATOR CELLS
# ============================================================

func _build_indicator_cell_lists(boss_col: int) -> void:

	left_cells.clear()
	right_cells.clear()

	var rows := [
		DrRogueoBoard.BOARD_HEIGHT - 2,
		DrRogueoBoard.BOARD_HEIGHT - 1
	]

	for row in rows:

		for col in range(0, boss_col):
			left_cells.append(
				Vector2i(col, row)
			)

		for col in range(
			boss_col + 2,
			DrRogueoBoard.BOARD_WIDTH
		):
			right_cells.append(
				Vector2i(col, row)
			)


func _all_indicator_cells() -> Array[Vector2i]:

	var all: Array[Vector2i] = []

	for cell in left_cells:
		all.append(cell)

	for cell in right_cells:
		all.append(cell)

	return all


# ============================================================
# BOSS VISUAL LAYER
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


# ============================================================
# BOSS SPRITE
# ============================================================

func _create_boss_sprite(
	boss_col: int,
	boss_row: int
) -> void:

	boss_sprite = Sprite2D.new()

	boss_sprite.name = "Boss1Sprite"
	boss_sprite.centered = false
	boss_sprite.texture = load(
		BOSS_TEXTURE_PATH
	)

	boss_sprite.hframes = 2
	boss_sprite.vframes = 6
	boss_sprite.frame = 0

	boss_sprite.position = board.grid_to_local(
		Vector2i(
			boss_col,
			boss_row
		)
	)

	board.add_child(boss_sprite)

	_place_at_boss_layer(boss_sprite)


# ============================================================
# GLOBAL ANIMATION FRAME
# ============================================================

func _on_anim_frame_changed(frame: int) -> void:

	boss_anim_frame = frame

	# --------------------------------------------------------
	# Boss animation
	# --------------------------------------------------------

	if not busy:

		if boss_sprite != null:
			boss_sprite.frame = boss_anim_frame

		if _magnifier_boss != null:

			_magnifier_boss.frame = frame
			_magnifier_boss.position = (
				magnifier_boss_position
			)

	# --------------------------------------------------------
	# X flashing
	#
	# Xs use a separate active state so that hiding the sprite
	# on the OFF frame does not permanently disable it.
	# --------------------------------------------------------

	for cell in x_sprites.keys():

		var x_sprite: Sprite2D = x_sprites[cell]

		if not is_instance_valid(x_sprite):
			continue

		var active: bool = x_active.get(
			cell,
			false
		)

		x_sprite.visible = (
			active
			and frame % 2 == 0
		)

	if not busy:
		_raise_visible_x_sprites()


# ============================================================
# INDICATOR SPRITES
# ============================================================

func _create_indicator_sprites() -> void:

	var texture := load(
		INDICATOR_TEXTURE_PATH
	)

	for cell in _all_indicator_cells():

		var sprite := Sprite2D.new()

		sprite.centered = false
		sprite.texture = texture
		sprite.region_enabled = true
		sprite.position = board.grid_to_local(cell)

		board.add_child(sprite)

		indicator_sprites[cell] = sprite

		_place_at_boss_layer(sprite)


# ============================================================
# X SPRITES
# ============================================================

func _create_x_sprites() -> void:

	var texture := load(
		X_TEXTURE_PATH
	)

	for cell in _all_indicator_cells():

		var sprite := Sprite2D.new()

		sprite.centered = false
		sprite.texture = texture
		sprite.visible = false
		sprite.position = board.grid_to_local(cell)

		board.add_child(sprite)

		x_sprites[cell] = sprite
		x_active[cell] = false


func _raise_visible_x_sprites() -> void:

	for cell in x_sprites.keys():

		var sprite: Sprite2D = x_sprites[cell]

		if sprite.visible:
			board.move_child(
				sprite,
				board.get_child_count() - 1
			)


# ============================================================
# ROLL INDICATORS
# ============================================================

func _roll_new_indicators() -> void:

	indicator_colors.clear()

	for cell in _all_indicator_cells():

		var color: int = board.rng.randi_range(
			PillHalf.PillColor.RED,
			PillHalf.PillColor.BLUE
		)

		indicator_colors[cell] = color

		_update_indicator_sprite(cell)

		x_active[cell] = false

		var x_sprite: Sprite2D = x_sprites.get(cell)

		if x_sprite != null:
			x_sprite.visible = false


# ============================================================
# UPDATE INDICATOR SPRITE
# ============================================================

func _update_indicator_sprite(
	cell: Vector2i
) -> void:

	var sprite: Sprite2D = indicator_sprites.get(
		cell
	)

	if sprite == null:
		return

	var color: int = indicator_colors.get(
		cell,
		PillHalf.PillColor.RED
	)

	sprite.region_rect = Rect2(
		color * INDICATOR_FRAME_SIZE,
		0,
		INDICATOR_FRAME_SIZE,
		INDICATOR_FRAME_SIZE
	)


# ============================================================
# CHECK INDICATORS
# ============================================================

func check_indicators() -> bool:

	if defeated or board == null:
		return false

	var all_correct := true
	var any_x_shown := false

	for cell in _all_indicator_cells():

		var required: int = indicator_colors.get(
			cell,
			-1
		)

		var filled := board.is_cell_filled(cell)

		var color: Variant = board.get_color_at_cell(
			cell
		)

		var x_sprite: Sprite2D = x_sprites.get(
			cell
		)

		# ----------------------------------------------------
		# Wrong color
		# ----------------------------------------------------

		if (
			filled
			and color != null
			and color != required
		):

			all_correct = false
			x_active[cell] = true

			if x_sprite != null:

				x_sprite.visible = (
					boss_anim_frame % 2 == 0
				)

				if x_sprite.visible:
					any_x_shown = true

		# ----------------------------------------------------
		# Correct / empty
		# ----------------------------------------------------

		else:

			if not filled:
				all_correct = false

			x_active[cell] = false

			if x_sprite != null:
				x_sprite.visible = false

	# --------------------------------------------------------
	# Keep visible Xs above the board pieces.
	# --------------------------------------------------------

	if any_x_shown:
		_raise_visible_x_sprites()

	# --------------------------------------------------------
	# All indicators satisfied.
	# --------------------------------------------------------

	if all_correct:

		await _deal_damage()
		return true

	return false


# ============================================================
# DEAL DAMAGE
# ============================================================

func _deal_damage() -> void:

	busy = true

	for cell in _all_indicator_cells():

		board.boss_clear_indicator_cell(cell)

	boss_sprite.frame = (
		2 + boss_anim_frame
	)

	await board.get_tree().create_timer(
		DAMAGE_FLASH_DURATION
	).timeout

	health -= 1

	if healthbar != null:
		healthbar.set_health(health)

	await board.wait_for_vanishing_halves()

	await board.apply_gravity()

	if health <= 0:

		await _play_death()
		return

	_roll_new_indicators()

	boss_sprite.frame = boss_anim_frame

	if _magnifier_boss != null:

		_magnifier_boss.position = (
			magnifier_boss_position
		)

		_magnifier_boss.frame = (
			boss_anim_frame
		)

	busy = false


# ============================================================
# DEATH
# ============================================================

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

	for sprite in indicator_sprites.values():
		sprite.visible = false

	for sprite in x_sprites.values():
		sprite.visible = false

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
			"Boss1Controller: no node in group '%s' -- "
			% MAGNIFIER_GROUP
			+ "add a Node2D under Magnifier in main.tscn "
			+ "and put it in that group."
		)

		return

	_magnifier_root = Node2D.new()
	_magnifier_root.name = (
		"Boss1MagnifierDisplay"
	)

	slot.add_child(_magnifier_root)

	# --------------------------------------------------------
	# Gradient
	# --------------------------------------------------------

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

	# --------------------------------------------------------
	# Boss
	# --------------------------------------------------------

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

	# --------------------------------------------------------
	# Healthbar
	# --------------------------------------------------------

	healthbar = Boss1Healthbar.new()

	healthbar.name = "Boss1Healthbar"
	healthbar.position = (
		magnifier_healthbar_position
	)

	_magnifier_root.add_child(
		healthbar
	)

	healthbar.set_health(health)

	# --------------------------------------------------------
	# Synchronize magnifier animation with AnimClock
	# --------------------------------------------------------

	if not AnimClock.frame_changed.is_connected(
		_on_magnifier_frame_changed
	):

		AnimClock.frame_changed.connect(
			_on_magnifier_frame_changed
	)


func _on_magnifier_frame_changed(
	frame: int
) -> void:

	if _magnifier_boss == null:
		return

	_magnifier_boss.position = (
		magnifier_boss_position
	)

	_magnifier_boss.frame = frame


# ============================================================
# EDITOR MAGNIFIER PREVIEW
# ============================================================

func _find_magnifier_slot_in_editor() -> Node2D:

	var scene_root := get_tree().edited_scene_root

	if scene_root == null:
		return null

	var nodes := scene_root.get_tree().get_nodes_in_group(
		MAGNIFIER_GROUP
	)

	for node in nodes:

		if node is Node2D:
			return node as Node2D

	return null


func _create_editor_magnifier_preview() -> void:

	if not Engine.is_editor_hint():
		return

	if (
		_editor_magnifier_root != null
		and is_instance_valid(
			_editor_magnifier_root
		)
	):
		return

	var slot := _find_magnifier_slot_in_editor()

	if slot == null:
		return

	_editor_magnifier_root = Node2D.new()
	_editor_magnifier_root.name = (
		"Boss1MagnifierPreview"
	)

	slot.add_child(
		_editor_magnifier_root
	)

	# --------------------------------------------------------
	# Gradient
	# --------------------------------------------------------

	_editor_magnifier_gradient = Sprite2D.new()

	_editor_magnifier_gradient.name = "Gradient"
	_editor_magnifier_gradient.centered = false
	_editor_magnifier_gradient.texture = load(
		GRADIENT_TEXTURE_PATH
	)

	_editor_magnifier_root.add_child(
		_editor_magnifier_gradient
	)

	# --------------------------------------------------------
	# Boss
	# --------------------------------------------------------

	_editor_magnifier_boss = Sprite2D.new()

	_editor_magnifier_boss.name = "Boss"
	_editor_magnifier_boss.centered = false
	_editor_magnifier_boss.texture = load(
		MAGNIFIER_BOSS_TEXTURE_PATH
	)

	_editor_magnifier_boss.hframes = 2
	_editor_magnifier_boss.vframes = 1

	_editor_magnifier_root.add_child(
		_editor_magnifier_boss
	)

	# --------------------------------------------------------
	# Healthbar
	# --------------------------------------------------------

	_editor_magnifier_healthbar = Boss1Healthbar.new()

	_editor_magnifier_healthbar.name = "Healthbar"

	_editor_magnifier_root.add_child(
		_editor_magnifier_healthbar
	)

	_update_editor_magnifier()


func _update_editor_magnifier() -> void:

	if not Engine.is_editor_hint():
		return

	if (
		_editor_magnifier_root == null
		or not is_instance_valid(
			_editor_magnifier_root
		)
	):
		return

	# --------------------------------------------------------
	# Gradient
	# --------------------------------------------------------

	if (
		_editor_magnifier_gradient != null
		and is_instance_valid(
			_editor_magnifier_gradient
		)
	):

		_editor_magnifier_gradient.position = (
			magnifier_gradient_position
		)

	# --------------------------------------------------------
	# Boss
	# --------------------------------------------------------

	if (
		_editor_magnifier_boss != null
		and is_instance_valid(
			_editor_magnifier_boss
		)
	):

		_editor_magnifier_boss.centered = false

		_editor_magnifier_boss.position = (
			magnifier_boss_position
		)

		_editor_magnifier_boss.frame = (
			magnifier_boss_frame
		)

	# --------------------------------------------------------
	# Healthbar
	# --------------------------------------------------------

	if (
		_editor_magnifier_healthbar != null
		and is_instance_valid(
			_editor_magnifier_healthbar
		)
	):

		_editor_magnifier_healthbar.position = (
			magnifier_healthbar_position
		)

		_editor_magnifier_healthbar.set_health(
			magnifier_health
		)


# ============================================================
# EXIT TREE
# ============================================================

func _exit_tree() -> void:

	if Engine.is_editor_hint():

		if (
			_editor_magnifier_root != null
			and is_instance_valid(
				_editor_magnifier_root
			)
		):

			_editor_magnifier_root.queue_free()

		_editor_magnifier_root = null
		_editor_magnifier_gradient = null
		_editor_magnifier_boss = null
		_editor_magnifier_healthbar = null

		return

	if AnimClock.frame_changed.is_connected(
		_on_anim_frame_changed
	):

		AnimClock.frame_changed.disconnect(
			_on_anim_frame_changed
	)

	if AnimClock.frame_changed.is_connected(
		_on_magnifier_frame_changed
	):

		AnimClock.frame_changed.disconnect(
			_on_magnifier_frame_changed
	)

	for sprite in x_sprites.values():

		if is_instance_valid(sprite):
			sprite.queue_free()

	x_sprites.clear()
	x_active.clear()

	if (
		_magnifier_root != null
		and is_instance_valid(
			_magnifier_root
		)
	):

		_magnifier_root.queue_free()
