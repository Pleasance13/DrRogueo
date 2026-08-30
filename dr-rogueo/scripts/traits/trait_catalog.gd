class_name TraitCatalog
extends RefCounted

# ============================================================
# TRAIT CATALOG
# ============================================================
#
# Defines which Trait TYPES exist, exactly like StoreCatalog
# does for Items. The store's actual trait shelf (once wired)
# will roll from this list.
# ============================================================

static func create_catalog() -> Array[Trait]:
	return [
		_create_pacman()
	]


static func _create_pacman() -> Trait:
	return TraitPacman.new()
