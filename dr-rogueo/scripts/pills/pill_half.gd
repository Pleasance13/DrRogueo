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


@export_group("Pill Half")

@export var pill_color: PillColor = PillColor.RED:
	set(value):
		pill_color = value
		_update_sprite()

@export var pill_state: PillState = PillState.TOP:
	set(value):
		pill_state = value
		_update_sprite()


@onready var sprite: Sprite2D = $Sprite2D


const SPRITE_SIZE := 8


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
# anyway, so there's nothing meaningful to overlay).
#
const DAMAGE_OVERLAY_FRAME_SIZE := 8


func _ready() -> void:
	_update_sprite()
	_update_damage_overlay()


func _update_sprite() -> void:
	if not is_inside_tree():
		return

	var sprite_node := get_node_or_null("Sprite2D") as Sprite2D
	if sprite_node == null:
		return

	var column := int(pill_color)
	var row := int(pill_state)

	sprite_node.region_enabled = true
	sprite_node.region_rect = Rect2(
		column * SPRITE_SIZE,
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
