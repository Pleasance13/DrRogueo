class_name ItemTether
extends Item


# ============================================================
# TETHER PILL ITEM
# ============================================================

const TETHER_TEXTURE_PATH := "res://art/pills/tether_pill.png"
const TETHER_ICON_PATH := "res://art/ui/tether-icon.png"


func _init() -> void:

	id = "tether"

	display_name = "TETHER PILL"

	rarity = Item.Rarity.COMMON

	cost = 10

	sell_price = 5

	description = (
		"Creates a temporary bridge between the first matching " +
		"colored cells found on either side of the falling pill."
	)

	replaces_next_pill = true

	icon = load(TETHER_ICON_PATH)


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
# This is called ONLY after the tether pill has become the
# actual falling pill.
# ============================================================

func use(board: DrRogueoBoard) -> bool:

	if board == null:
		return false

	if board.current_pill == null:
		return false

	if not board.current_pill.is_tether_pill:
		return false


	return await board.deploy_tether(
		board.current_pill,
		board.current_grid_position,
		board.current_pill.orientation
	)
