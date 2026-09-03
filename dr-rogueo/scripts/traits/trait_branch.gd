class_name TraitBranch
extends Trait


# ============================================================
# BRANCH TRAIT
# ============================================================
#
# While owned, any normal 4+ match also clears every other
# same-colored pill half or virus that's orthogonally connected
# to the match, chaining outward as far as that color continues
# (a flood fill of the matched color's connected component).
#
# Tethers and empty cells stop the flood -- only PillHalf and
# Virus cells of the matching color propagate it further. There
# is no Pacman-wrap interaction: the flood does not wrap around
# the board edges even if Pacman is also owned.
#
# The actual expansion lives in board.gd (see
# DrRogueoBoard.has_branch_trait() /
# _expand_matches_for_branch_trait()). This class only carries
# store/UI metadata.
#
# ============================================================

const BRANCH_ICON_PATH := "res://art/ui/branch-icon.png"


func _init() -> void:

	id = "branch"

	display_name = "BRANCH"

	preview = Item._load_preview("res://art/ui/temp-preview.png")

	rarity = Trait.Rarity.UNCOMMON

	cost = 70

	sell_price = 35

	description = (
		"Any match of 4 or more also clears every same-" +
		"colored pill half or virus connected to it, " +
		"chaining outward as far as that color continues."
	)

	if ResourceLoader.exists(BRANCH_ICON_PATH):

		icon = load(BRANCH_ICON_PATH)
