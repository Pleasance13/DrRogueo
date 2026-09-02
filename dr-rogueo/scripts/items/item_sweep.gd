class_name ItemSweep
extends Item


# ============================================================
# SWEEP (item)
# ============================================================
#
# Never becomes a falling pill (no replaces_next_pill, no
# spritesheet) - just an inventory icon. Fires the instant the
# CURRENT pill settles: every currently SEPARATED pill half on
# the board is cleared (viruses and connected pill halves are
# untouched). Clears cascade row-by-row, top to bottom. Gravity
# and any resulting matches resolve before the next pill spawns
# - see DrRogueoBoard.use_sweep_item().
#
# ============================================================

const SWEEP_ICON_PATH := "res://art/ui/sweep-icon.png"


func _init() -> void:

	id = "sweep"

	display_name = "SWEEP"

	rarity = Item.Rarity.UNCOMMON

	cost = 20

	sell_price = 10

	description = (
		"Clears every separated (unpaired) pill half on the " +
		"board, cascading top to bottom. Viruses and connected " +
		"pill halves are untouched."
	)

	if ResourceLoader.exists(SWEEP_ICON_PATH):

		icon = load(SWEEP_ICON_PATH)


func use(board: DrRogueoBoard) -> bool:

	if board == null:
		return false

	return board.use_sweep_item()
