class_name StoreCatalog
extends RefCounted

# ============================================================
# STORE CATALOG
# ============================================================
#
# This defines which item TYPES are available in the store.
#
# Item properties such as:
#   - rarity
#   - rarity_weight
#   - default cost
#   - display name
#   - icon
#
# belong to the individual Item scripts.
#
# The store itself can override the price per slot through
# StoreController's Inspector settings.
# ============================================================

static func create_catalog() -> Array[Item]:
	return [
		_create_tether(),
		_create_pong(),
	]


static func _create_tether() -> Item:
	return ItemTether.new()


static func _create_pong() -> Item:
	return ItemPong.new()
