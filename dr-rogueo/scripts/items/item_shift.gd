class_name ItemShift
extends Item


# ============================================================
# SHIFT PILL (item)
# ============================================================
#
# Falls and rotates like a normal pill. Whatever orientation it
# is locked in at determines the shift direction. The instant it
# settles, board-wide gravity flips to that direction until
# everything that can move has stopped, then reverts to normal
# downward gravity until everything resettles.
#
# See Board.settle_current_pill() / Board.start_shift() for the
# actual mechanic - this class just describes/spawns the item.
#
# ============================================================

const SHIFT_ICON_PATH := "res://art/ui/shift-icon.png"


func _init() -> void:

	id = "shift"

	display_name = "SHIFT PILL"

	rarity = Item.Rarity.UNCOMMON

	cost = 20

	sell_price = 10

	description = (
		"Rotate it like a normal pill before it lands. The " +
		"instant it settles, gravity shifts board-wide toward " +
		"the arrow until everything stops moving, then reverts " +
		"back to normal gravity."
	)

	replaces_next_pill = true

	icon = load(SHIFT_ICON_PATH)


# ============================================================
# QUEUED
# ============================================================

func on_queue(board: DrRogueoBoard) -> void:

	# The board handles the actual preview conversion.
	pass


# ============================================================
# USE
# ============================================================
#
# Shift Pill fires automatically when it settles (see
# Board.settle_current_pill() / Board.start_shift()), never via
# a manual use() call - replaces_next_pill items never go
# through Inventory.fire_pending(). Kept as a safe no-op in case
# that ever changes.
# ============================================================

func use(board: DrRogueoBoard) -> bool:

	return true
