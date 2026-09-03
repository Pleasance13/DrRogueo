class_name ItemSnipper
extends Item


# ============================================================
# SNIPPER (item)
# ============================================================
#
# Never becomes a falling pill (no replaces_next_pill, no
# spritesheet) - just an inventory icon. Fires the instant the
# CURRENT pill settles: every still-connected pill half pair on
# the board is split into two independent SEPARATED halves.
# Gravity resolves, then matches resolve, before the next pill
# is allowed to spawn - see DrRogueoBoard.use_snipper_item().
#
# ============================================================

const SNIPPER_ICON_PATH := "res://art/ui/snipper-icon.png"


func _init() -> void:

	id = "snipper"

	display_name = "SNIPPER"

	preview = Item._load_preview("res://art/ui/snipper-preview.png")

	rarity = Item.Rarity.COMMON

	cost = 10

	sell_price = 5

	description = (
		"Splits every connected pill on the board into its " +
		"two independent halves."
	)

	if ResourceLoader.exists(SNIPPER_ICON_PATH):

		icon = load(SNIPPER_ICON_PATH)


func use(board: DrRogueoBoard) -> bool:

	if board == null:
		return false

	return board.use_snipper_item()
