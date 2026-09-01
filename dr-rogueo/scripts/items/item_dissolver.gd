class_name ItemDissolver
extends Item


# ============================================================
# DISSOLVER PILL (item)
# ============================================================
#
# A normal-falling, normal-matching pill. When either of its
# halves takes part in a valid match, BOTH of its halves clear
# together and every other pill half of its color currently on
# the board clears with it.
#
# Viruses are untouched by the global effect - only viruses
# that were part of the original match clear normally. See
# board.gd's _expand_matches_for_dissolvers() for the actual
# clearing logic; this class only carries the chosen color and
# store/UI metadata. The pill's own on-board look comes from
# PillHalf.is_dissolver (dissolve_pill.png), not from anything
# stored here.
#
# Three instances exist in the catalog (RED / YELLOW / BLUE),
# distinguished by id ("dissolver_red", etc).
#
# ============================================================

var dissolver_color: PillHalf.PillColor = PillHalf.PillColor.RED


func _init(
	color: PillHalf.PillColor = PillHalf.PillColor.RED
) -> void:

	dissolver_color = color

	var color_name := "RED"
	var icon_path := "res://art/ui/dissolve-icon-red.png"

	match color:

		PillHalf.PillColor.YELLOW:

			color_name = "(Y)"
			icon_path = "res://art/ui/dissolve-icon-yellow.png"

		PillHalf.PillColor.BLUE:

			color_name = "(B)"
			icon_path = "res://art/ui/dissolve-icon-blue.png"

		_:

			color_name = "(R)"


	id = "dissolver_%s" % color_name.to_lower()

	display_name = "DISSOLVER %s" % color_name

	rarity = Item.Rarity.UNCOMMON

	cost = 20

	sell_price = 10

	description = (
		"A %s pill. Once it lands in a valid match, every %s " +
		"pill half on the board clears along with it. Viruses " +
		"are untouched unless they were part of the original " +
		"match."
	) % [color_name.to_lower(), color_name.to_lower()]

	replaces_next_pill = true


	# --------------------------------------------------------
	# ICON (optional - safe to leave unassigned for now)
	# --------------------------------------------------------

	if ResourceLoader.exists(icon_path):

		icon = load(icon_path)
