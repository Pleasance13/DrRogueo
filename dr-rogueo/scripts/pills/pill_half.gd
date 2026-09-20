@tool
class_name PillHalf
extends Node2D


enum PillColor {
	RED,
	YELLOW,
	BLUE
}

enum PillState {
	TOP,
	BOTTOM,
	LEFT,
	RIGHT,
	SEPARATED,
	VANISHING
}

var partner_half: PillHalf = null


# ============================================================
# HP
# ============================================================
#
# Used by items that damage cells over multiple hits (e.g. the
# Pong Paddle ball) rather than clearing them outright. Normal
# match-based clearing ignores this entirely - it's only
# consulted by whatever's calling take_hit().
#
const MAX_HP := 3

var hp: int = MAX_HP


# Returns true if this hit broke the half (hp reached 0) - the
# caller is responsible for actually vanishing it.
func take_hit() -> bool:

	hp -= 1

	_update_damage_overlay()

	return hp <= 0


# Applies `amount` hits at once (e.g. a bomb blast dealing a
# flat burst of damage). Returns true if this call broke the
# half. Safe to call with amount >= current hp.
func deal_damage(amount: int) -> bool:

	var broke := false

	for _i in range(max(amount, 0)):

		if take_hit():

			broke = true

			break

	return broke


@export_group("Pill Half")

@export var pill_color: PillColor = PillColor.RED:
	set(value):
		pill_color = value
		_update_sprite()

@export var pill_state: PillState = PillState.TOP:
	set(value):
		pill_state = value
		_update_sprite()


# ============================================================
# DISSOLVER
# ============================================================
#
# Marks this half as belonging to a Dissolver Pill (see
# ItemDissolver / board.gd's _expand_matches_for_dissolvers).
#
# A dissolver half draws from a completely different
# spritesheet (dissolve_pill.png) with its own 2-frame idle
# animation, EXCEPT while VANISHING, where it falls back to
# the normal pill spritesheet's shared vanish frame for its
# color - the same trick Virus uses for its own vanish frame.
#
# ============================================================

@export_group("Dissolver")

@export var is_dissolver: bool = false:
	set(value):
		is_dissolver = value
		_update_sprite()


# ============================================================
# STONE (Boss 3 / Medusa petrify)
# ============================================================
#
# is_stone: the half is permanently petrified. It no longer
# takes part in color matching (board.gd's get_color_at_cell()
# treats a stone half as colorless), never falls under gravity
# (board.gd's gravity_unit_can_fall() excludes stone halves
# outright), and ignores Dissolver/Branch/Tetris entirely.
# It can still be cleared by direct-damage sources (Pong,
# Thwomp, bombs) via take_hit()/deal_damage(), and by
# Snipper (splits it to SEPARATED) + Sweep (clears SEPARATED
# cells), same as any other half.
#
# is_turning_to_stone: a brief transitional state (see
# petrify()) where the normal/dissolver sprite is still drawn
# underneath, with the stone spritesheet's second column
# overlaid on top as a "turning to stone" effect. Once the
# transition finishes, is_stone becomes true and the half
# switches fully to the stone sheet's first column.
#
# stone_pills.png layout: 2 columns x 6 rows, 8x8 cells
# (16x48 total) - same PillState row order as pills.png,
# but column 0 applies to EVERY color (there is no per-color
# stone art) and column 1 is the transition overlay frame.
#
# ============================================================

@export_group("Stone")

@export var is_stone: bool = false:
	set(value):
		is_stone = value
		_update_sprite()

@export var is_turning_to_stone: bool = false:
	set(value):
		is_turning_to_stone = value
		_update_sprite()

const STONE_TRANSITION_DURATION := 0.3

const STONE_COLUMN_FINAL := 0
const STONE_COLUMN_TRANSITION := 1


# Called by board.gd when Medusa's gaze lands on this half.
# Plays the transition overlay for `transition_duration`
# seconds, then locks the half into full stone. Also restores
# full HP, since a freshly-petrified half is undamaged.
func petrify(transition_duration: float = STONE_TRANSITION_DURATION) -> void:

	hp = MAX_HP

	is_turning_to_stone = true

	_update_damage_overlay()

	if transition_duration > 0.0 and is_inside_tree():

		await get_tree().create_timer(
			transition_duration,
			false
		).timeout

	if not is_instance_valid(self):
		return

	is_turning_to_stone = false
	is_stone = true


@onready var sprite: Sprite2D = $Sprite2D


const SPRITE_SIZE := 8


# ============================================================
# TEXTURES
# ============================================================

# Normal pill spritesheet: column = color, row = pill_state.
# Also supplies the shared VANISHING frame used by Dissolver
# halves.
const PILLS_TEXTURE_PATH := "res://art/pills/pills.png"

# Dissolver spritesheet (48x40, 8px cells). Layout:
#
#   row 0        -> vertical TOP,    6 cols = color*2 + anim_frame
#   row 1        -> vertical BOTTOM, 6 cols = color*2 + anim_frame
#   rows 2 & 3   -> horizontal LEFT+RIGHT (row = 2 + anim_frame),
#                   each color occupies a 16px-wide block:
#                     LEFT  at x = color*16
#                     RIGHT at x = color*16 + 8
#   row 4        -> SEPARATED,       6 cols = color*2 + anim_frame
#
# Orientation.RIGHT/LEFT both use the LEFT/RIGHT half states,
# and Orientation.UP/DOWN both use the TOP/BOTTOM half states -
# there's no separate "facing" art, matching how pill_state is
# already assigned by Pill.gd regardless of orientation.
#
const DISSOLVER_TEXTURE_PATH := "res://art/pills/dissolve_pill.png"

# Stone spritesheet (16x48, 8px cells). Column 0 = final stone
# look, column 1 = turning-to-stone overlay. Row = pill_state,
# same order as PILLS_TEXTURE_PATH. Applies to every color.
const STONE_TEXTURE_PATH := "res://art/pills/stone_pills.png"

var _pills_texture: Texture2D = null
var _dissolver_texture: Texture2D = null
var _stone_texture: Texture2D = null


func _get_pills_texture() -> Texture2D:

	if _pills_texture == null:
		_pills_texture = load(PILLS_TEXTURE_PATH)

	return _pills_texture


func _get_dissolver_texture() -> Texture2D:

	if _dissolver_texture == null:
		_dissolver_texture = load(DISSOLVER_TEXTURE_PATH)

	return _dissolver_texture


func _get_stone_texture() -> Texture2D:

	if _stone_texture == null and ResourceLoader.exists(STONE_TEXTURE_PATH):
		_stone_texture = load(STONE_TEXTURE_PATH)

	return _stone_texture


# ============================================================
# DAMAGE OVERLAY
# ============================================================
#
# 16×8 overlay, two 8×8 frames side by side:
#   left half  (x=0) -> after 1 hit
#   right half (x=8) -> after 2 hits
#
# Hidden at 0 hits (full hp) and at 3 hits (about to vanish -
# the caller switches pill_state to VANISHING at that point
# anyway, so there's nothing meaningful to overlay). Shared
# as-is by Dissolver halves that get hit by Pong instead of
# matching - no separate art needed. Stone halves use the same
# overlay for the same reason.
#
const DAMAGE_OVERLAY_FRAME_SIZE := 8


func _ready() -> void:

	_update_sprite()
	_update_damage_overlay()

	if not Engine.is_editor_hint():

		if not AnimClock.frame_changed.is_connected(_on_anim_frame_changed):

			AnimClock.frame_changed.connect(_on_anim_frame_changed)


# ============================================================
# SHARED ANIMATION CLOCK
# ============================================================

func _on_anim_frame_changed(_frame: int) -> void:

	if is_stone or is_turning_to_stone:

		# Stone (and its transition) has no idle animation -
		# nothing to refresh per-frame.
		return

	if not is_dissolver:
		return

	if pill_state == PillState.VANISHING:
		return

	_update_sprite()


# ============================================================
# SPRITE
# ============================================================

func _update_sprite() -> void:
	if not is_inside_tree():
		return

	var sprite_node := get_node_or_null("Sprite2D") as Sprite2D
	if sprite_node == null:
		return

	sprite_node.region_enabled = true

	if is_stone and pill_state != PillState.VANISHING:

		_apply_stone_region(sprite_node)

	elif is_dissolver and pill_state != PillState.VANISHING:

		_apply_dissolver_region(sprite_node)

	else:

		_apply_normal_region(sprite_node)

	_update_stone_transition_overlay()


func _apply_normal_region(sprite_node: Sprite2D) -> void:

	sprite_node.texture = _get_pills_texture()

	var column := int(pill_color)
	var row := int(pill_state)

	sprite_node.region_rect = Rect2(
		column * SPRITE_SIZE,
		row * SPRITE_SIZE,
		SPRITE_SIZE,
		SPRITE_SIZE
	)


func _apply_dissolver_region(sprite_node: Sprite2D) -> void:

	sprite_node.texture = _get_dissolver_texture()

	var color := int(pill_color)

	var frame := 0

	if not Engine.is_editor_hint():
		frame = AnimClock.frame

	match pill_state:

		PillState.TOP:

			sprite_node.region_rect = Rect2(
				(color * 2 + frame) * SPRITE_SIZE,
				0,
				SPRITE_SIZE,
				SPRITE_SIZE
			)

		PillState.BOTTOM:

			sprite_node.region_rect = Rect2(
				(color * 2 + frame) * SPRITE_SIZE,
				SPRITE_SIZE,
				SPRITE_SIZE,
				SPRITE_SIZE
			)

		PillState.LEFT:

			sprite_node.region_rect = Rect2(
				color * 16,
				(2 + frame) * SPRITE_SIZE,
				SPRITE_SIZE,
				SPRITE_SIZE
			)

		PillState.RIGHT:

			sprite_node.region_rect = Rect2(
				color * 16 + SPRITE_SIZE,
				(2 + frame) * SPRITE_SIZE,
				SPRITE_SIZE,
				SPRITE_SIZE
			)

		PillState.SEPARATED:

			sprite_node.region_rect = Rect2(
				(color * 2 + frame) * SPRITE_SIZE,
				4 * SPRITE_SIZE,
				SPRITE_SIZE,
				SPRITE_SIZE
			)

		_:

			# Safety net - shouldn't be reachable (VANISHING is
			# routed to _apply_normal_region by the caller).
			sprite_node.region_rect = Rect2(
				(color * 2 + frame) * SPRITE_SIZE,
				4 * SPRITE_SIZE,
				SPRITE_SIZE,
				SPRITE_SIZE
			)


# Column 0 of stone_pills.png, applies to every color - only
# pill_state (row) matters.
func _apply_stone_region(sprite_node: Sprite2D) -> void:

	var texture := _get_stone_texture()

	if texture == null:

		# Art not present yet - fall back to the normal sprite
		# rather than drawing nothing.
		_apply_normal_region(sprite_node)
		return

	sprite_node.texture = texture

	var row := int(pill_state)

	sprite_node.region_rect = Rect2(
		STONE_COLUMN_FINAL * SPRITE_SIZE,
		row * SPRITE_SIZE,
		SPRITE_SIZE,
		SPRITE_SIZE
	)


# ============================================================
# STONE TRANSITION OVERLAY
# ============================================================
#
# Drawn on top of whatever _update_sprite() already put on the
# main Sprite2D (normal or dissolver), using column 1 of
# stone_pills.png. Requires a "StoneOverlay" Sprite2D child in
# the scene (see pill.tscn edits) - mirrors how DamageOverlay
# already works.
# ============================================================

func _update_stone_transition_overlay() -> void:

	var overlay := get_node_or_null("StoneOverlay") as Sprite2D

	if overlay == null:
		return

	if not is_turning_to_stone:

		overlay.visible = false
		return

	var texture := _get_stone_texture()

	if texture == null:

		overlay.visible = false
		return

	overlay.visible = true
	overlay.region_enabled = true
	overlay.texture = texture

	var row := int(pill_state)

	overlay.region_rect = Rect2(
		STONE_COLUMN_TRANSITION * SPRITE_SIZE,
		row * SPRITE_SIZE,
		SPRITE_SIZE,
		SPRITE_SIZE
	)


func _update_damage_overlay() -> void:
	if not is_inside_tree():
		return

	var overlay := get_node_or_null("DamageOverlay") as Sprite2D
	if overlay == null:
		return

	var hits_taken := MAX_HP - hp

	if hits_taken <= 0 or hits_taken > 2:
		overlay.visible = false
		return

	overlay.visible = true
	overlay.region_enabled = true
	overlay.region_rect = Rect2(
		(hits_taken - 1) * DAMAGE_OVERLAY_FRAME_SIZE,
		0,
		DAMAGE_OVERLAY_FRAME_SIZE,
		DAMAGE_OVERLAY_FRAME_SIZE
	)
