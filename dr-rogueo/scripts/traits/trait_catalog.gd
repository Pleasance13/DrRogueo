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
		_create_pacman(),
		_create_branch(),
		_create_tetris()
	]


static func _create_pacman() -> Trait:
	return TraitPacman.new()


static func _create_branch() -> Trait:
	return TraitBranch.new()


static func _create_tetris() -> Trait:
	return TraitTetris.new()
