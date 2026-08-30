class_name Trait
extends Resource

# ============================================================
# TRAIT (base class)
# ============================================================
#
# Traits are passive, always-on effects that stay in effect for
# as long as they're owned (see TraitInventory). Unlike Items,
# Traits are never "used" or consumed -- systems that care
# about a given trait (Board, etc.) just ask TraitInventory
# whether it's currently owned.
#
# ============================================================

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC
}

@export var rarity: Rarity = Rarity.COMMON
@export var rarity_weight: float = 1.0
@export var cost: int = 1
@export var sell_price: int = 1


func get_rarity_name() -> String:

	match rarity:
		Rarity.COMMON: return "COMMON"
		Rarity.UNCOMMON: return "UNCOMMON"
		Rarity.RARE: return "RARE"
		Rarity.EPIC: return "EPIC"

	return "COMMON"
