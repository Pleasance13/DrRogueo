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


func _init() -> void:
	id = "pong"
	display_name = "Pong Paddle"
	description = (
		"Summons a paddle at the top of the board that stays " +
		"until you miss. Move it with left/right; press down to " +
		"launch the ball into the board. 3 hits break a virus or " +
		"pill. Breaking a tile keeps a combo timer alive - let it " +
		"run out, or miss the ball, and the minigame ends. Pill " +
		"falling pauses the whole time."
	)


func use(board: DrRogueoBoard) -> bool:

	if board.pong_controller != null:
		return false

	board.start_pong_item()

	return true
