extends Node

# ============================================================
# TRAIT INVENTORY
# ============================================================
#
# Holds the run's currently-owned Traits. Fixed-size slots,
# mirroring Inventory's item slots (see scripts/items/inventory.gd).
#
# Traits are passive: there is no "use" step. Anything that
# cares whether a trait is active just calls has_trait(id).
#
# ============================================================

const MAX_TRAITS := 3

signal traits_changed

var traits: Array[Trait] = [null, null, null]


# ============================================================
# ADD / REMOVE
# ============================================================

func add_trait(trait_item: Trait) -> bool:

	var slot := traits.find(null)

	if slot == -1:
		return false

	traits[slot] = trait_item

	traits_changed.emit()

	return true


func add_trait_to_slot(
	trait_item: Trait,
	slot: int
) -> bool:

	if trait_item == null:
		return false

	if slot < 0 or slot >= traits.size():
		return false

	if traits[slot] != null:
		return false

	traits[slot] = trait_item

	traits_changed.emit()

	return true


func remove_trait_from_slot(
	slot: int
) -> bool:

	if slot < 0 or slot >= traits.size():
		return false

	if traits[slot] == null:
		return false

	traits[slot] = null

	traits_changed.emit()

	return true


func is_full() -> bool:

	return traits.find(null) == -1


# ============================================================
# QUERY
# ============================================================

func has_trait(trait_id: String) -> bool:

	for owned in traits:

		if owned != null and owned.id == trait_id:

			return true

	return false


func get_trait(trait_id: String) -> Trait:

	for owned in traits:

		if owned != null and owned.id == trait_id:

			return owned

	return null


# ============================================================
# RESET
# ============================================================

func reset() -> void:

	traits = [null, null, null]

	traits_changed.emit()
