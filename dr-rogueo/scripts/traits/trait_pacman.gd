class_name TraitPacman
extends Trait

# ============================================================
# PACMAN TRAIT
# ============================================================
#
# While owned, the board's left and right edges wrap into each
# other for matching purposes -- a color run can continue off
# the right edge and pick back up on the left edge (and vice
# versa), like the tunnels in Pac-Man.
#
# The actual wrap behavior lives in board.gd (see
# DrRogueoBoard.has_pacman_trait() / find_line_match()). This
# class only carries store/UI metadata.
#
# ============================================================

const PACMAN_ICON_PATH := "res://art/ui/pacman-icon.png"


func _init() -> void:

	id = "pacman"

	display_name = "PACMAN"

	rarity = Trait.Rarity.RARE

	cost = 80

	sell_price = 40

	description = (
		"The board's left and right walls wrap into each " +
		"other. A color run can continue off one edge and " +
		"pick back up on the other."
	)

	if ResourceLoader.exists(PACMAN_ICON_PATH):

		icon = load(PACMAN_ICON_PATH)
