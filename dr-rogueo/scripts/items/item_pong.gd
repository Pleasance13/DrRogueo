class_name ItemPong
extends Item


# ============================================================
# PONG PADDLE (item)
# ============================================================
#
# Summons the Pong Paddle minigame (see pong_controller.gd).
# Firing while one is already active fails harmlessly and the
# item returns to the inventory.
#
# ============================================================

const PONG_TEXTURE_PATH := "res://art/pills/pong.png"
const PONG_ICON_PATH := "res://art/ui/pong-icon.png"

func _init() -> void:

	id = "pong"

	display_name = "PONG PILL"

	preview = Item._load_preview("res://art/ui/pong-preview.png")

	rarity = Item.Rarity.EPIC

	cost = 50

	sell_price = 25

	description = (
		"Summons a paddle at the top of the board. " +
		"Move it with left/right; press A to launch " +
		"the ball into the board. 3 hits break a virus or " +
		"pill. Breaking a tile keeps a combo timer alive - let it " +
		"run out, or miss the ball, and the minigame ends."
	)

	#replaces_next_pill = true

	icon = load(PONG_ICON_PATH)


func use(board: DrRogueoBoard) -> bool:

	if board.pong_controller != null:
		return false

	board.start_pong_item()

	return true
