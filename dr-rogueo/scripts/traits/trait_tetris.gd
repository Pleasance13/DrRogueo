class_name TraitTetris
extends Trait


# ============================================================
# TETRIS TRAIT
# ============================================================
#
# While owned, any completely full row -- every one of its
# BOARD_WIDTH cells occupied by a pill half, a virus, or a
# tether, regardless of color -- clears entirely on its own,
# independent of normal color-matching.
#
# Checked every time matches/gravity resolve (see
# DrRogueoBoard._find_full_rows_for_tetris_trait(), called
# from _resolve_matches_and_gravity()), so a row completed
# mid-cascade (e.g. gravity dropping something into the last
# open cell of a row) triggers it too.
#
# This class only carries store/UI metadata; the actual row
# check lives in board.gd.
#
# ============================================================

const TETRIS_ICON_PATH := "res://art/ui/tetris-icon.png"


func _init() -> void:

	id = "tetris"

	display_name = "TETRIS"

	preview = Item._load_preview("res://art/ui/temp-preview.png")

	rarity = Trait.Rarity.EPIC

	cost = 90

	sell_price = 45

	description = (
		"Any completely full row clears on its own, " +
		"regardless of color -- pill halves, viruses, and " +
		"tethers all count."
	)

	if ResourceLoader.exists(TETRIS_ICON_PATH):

		icon = load(TETRIS_ICON_PATH)
