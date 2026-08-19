@tool
class_name Virus
extends Node2D


# ============================================================
# VIRUS
# ============================================================

enum VisualState {
	NORMAL,
	VANISHING
}


@export var virus_color: PillHalf.PillColor = PillHalf.PillColor.RED:
	set(value):
		virus_color = value
		update_visual()


# ============================================================
# HP
# ============================================================
#
# See PillHalf.hp for the full explanation - same mechanism,
# used by items like the Pong Paddle ball.
#
const MAX_HP := 3

var hp: int = MAX_HP


func take_hit() -> bool:

	hp -= 1

	update_visual()

	return hp <= 0


@export var visual_state: VisualState = VisualState.NORMAL:
	set(value):
		visual_state = value
		update_visual()


# ============================================================
# TEXTURES
# ============================================================

# The virus spritesheet.
#
# 3 columns × 6 rows
# 24 × 48 pixels
#
# Rows are grouped in damage-tier pairs (each pair is the
# existing 2-frame idle animation for that tier):
#   rows 0-1 -> normal (0 hits)
#   rows 2-3 -> 1 hit
#   rows 4-5 -> 2 hits
#
@export_category("Textures")

@export var virus_sprite_texture: Texture2D:
	set(value):
		virus_sprite_texture = value
		update_visual()


# The PillHalf spritesheet.
#
# 3 columns × 6 rows
# 24 × 48 pixels
#
# Only used for VANISHING.
@export var pill_sprite_texture: Texture2D:
	set(value):
		pill_sprite_texture = value
		update_visual()


# ============================================================
# SPRITE
# ============================================================

@onready var sprite: Sprite2D = $Sprite2D


# ============================================================
# ANIMATION
# ============================================================

const ANIMATION_INTERVAL := 0.30

var animation_timer := 0.0
var animation_frame := 0


# ============================================================
# SPRITE SIZE
# ============================================================

const SPRITE_SIZE := 8


# ============================================================
# LIFECYCLE
# ============================================================

func _ready() -> void:
	update_visual()


func _process(delta: float) -> void:

	if visual_state != VisualState.NORMAL:
		return

	animation_timer += delta

	if animation_timer >= ANIMATION_INTERVAL:

		animation_timer -= ANIMATION_INTERVAL

		animation_frame = 1 - animation_frame

		update_visual()


# ============================================================
# VISUAL
# ============================================================

func update_visual() -> void:

	var virus_sprite := get_node_or_null("Sprite2D") as Sprite2D

	if virus_sprite == null:
		return


	# ========================================================
	# VANISHING
	# ========================================================

	if visual_state == VisualState.VANISHING:

		if pill_sprite_texture == null:
			return

		virus_sprite.texture = pill_sprite_texture

		# The pill texture is 24×48, so don't use the virus
		# sheet's 3×2 frame configuration.
		virus_sprite.hframes = 1
		virus_sprite.vframes = 1
		virus_sprite.frame = 0

		virus_sprite.region_enabled = true

		var column := int(virus_color)

		virus_sprite.region_rect = Rect2(
			column * SPRITE_SIZE,
			int(PillHalf.PillState.VANISHING) * SPRITE_SIZE,
			SPRITE_SIZE,
			SPRITE_SIZE
		)

		return


	# ========================================================
	# NORMAL
	# ========================================================

	if virus_sprite_texture == null:
		return

	virus_sprite.texture = virus_sprite_texture

	virus_sprite.region_enabled = false

	virus_sprite.hframes = 3
	virus_sprite.vframes = 6

	virus_sprite.frame = get_sprite_frame()


# ============================================================
# SPRITE FRAME
# ============================================================
#
# Virus spritesheet (6 rows: 3 damage tiers × 2 idle frames):
#
#     ┌────────┬────────┬────────┐
#     │ RED 1  │YELLOW 1│ BLUE 1 │  tier 0 (normal), anim 0
#     ├────────┼────────┼────────┤
#     │ RED 2  │YELLOW 2│ BLUE 2 │  tier 0 (normal), anim 1
#     ├────────┼────────┼────────┤
#     │ RED 1  │YELLOW 1│ BLUE 1 │  tier 1 (1 hit), anim 0
#     ├────────┼────────┼────────┤
#     │ RED 2  │YELLOW 2│ BLUE 2 │  tier 1 (1 hit), anim 1
#     ├────────┼────────┼────────┤
#     │ RED 1  │YELLOW 1│ BLUE 1 │  tier 2 (2 hits), anim 0
#     ├────────┼────────┼────────┤
#     │ RED 2  │YELLOW 2│ BLUE 2 │  tier 2 (2 hits), anim 1
#     └────────┴────────┴────────┘
#
# Godot frame numbering:
#
#      0   1   2
#      3   4   5
#      6   7   8
#      9  10  11
#     12  13  14
#     15  16  17
#
# ============================================================

func get_sprite_frame() -> int:

	var column := int(virus_color)

	# 0 = normal, 1 = 1 hit, 2 = 2 hits. The 3rd hit breaks the
	# virus outright (visual_state switches to VANISHING before
	# this is ever consulted), so this never needs to go past 2.
	var damage_tier: int = clamp(MAX_HP - hp, 0, 2)

	var anim_row: int = 0 if animation_frame == 0 else 1

	var row: int = damage_tier * 2 + anim_row

	return row * 3 + column
