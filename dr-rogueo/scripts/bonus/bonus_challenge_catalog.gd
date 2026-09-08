class_name BonusChallengeCatalog
extends RefCounted

# ============================================================
# BONUS CHALLENGE CATALOG
# ============================================================
#
# Mirrors StoreCatalog/TraitCatalog. Add new challenge types
# here.
# ============================================================

static func create_catalog() -> Array[BonusChallenge]:
	return [
		BonusNoItems.new(),
		BonusPongCombo.new(),
		BonusClearColorFirst.new(PillHalf.PillColor.RED),
		BonusClearColorFirst.new(PillHalf.PillColor.YELLOW),
		BonusClearColorFirst.new(PillHalf.PillColor.BLUE),
	]
