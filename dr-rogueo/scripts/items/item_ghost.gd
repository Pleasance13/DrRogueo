class_name ItemGhost
extends Item


# ============================================================
# GHOST PILL (item)
# ============================================================
#
# Attaches a one-time ghost ability to the NEXT pill rather
# than replacing it outright (unlike Tether). The pill keeps
# its normal random colors and still matches normally.
#
# While falling:
#   - Press A (ui_accept) to become a ghost. A ghosting pill
#     passes through existing pills/viruses/tethers and only
#     collides with the board's walls and floor.
#   - Press A again to re-solidify. Anything it's overlapping
#     when it re-solidifies (pill halves, viruses, tethers) is
#     destroyed and replaced by the pill.
#   - If it reaches the bottom of the board while still a
#     ghost, it automatically re-solidifies and settles there.
#
# The ability is single-use per pill: once solidified, the
# pill can no longer re-enter ghost mode.
#
# ============================================================

const GHOST_ICON_PATH := "res://art/ui/ghost-icon.png"


func _init() -> void:

	id = "ghost"

	display_name = "GHOST PILL"

	rarity = Item.Rarity.COMMON

	cost = 10

	sell_price = 5

	description = (
		"The next pill can turn into a ghost. Press A while " +
		"it falls to phase through pills and viruses; press A " +
		"again to re-solidify, replacing anything it's " +
		"overlapping. Hits the floor while ghosting and it " +
		"settles automatically."
	)

	replaces_next_pill = true

	icon = load(GHOST_ICON_PATH)


# ============================================================
# QUEUED
# ============================================================

func on_queue(board: DrRogueoBoard) -> void:

	# Board.arm_next_pill_item() handles flagging the pill.
	pass


# ============================================================
# USE
# ============================================================
#
# Not actually invoked through Inventory.fire_pending() --
# like Tether, the effect lives entirely on the Pill/Board
# side once armed. Kept for interface consistency.
# ============================================================

func use(board: DrRogueoBoard) -> bool:

	return true
