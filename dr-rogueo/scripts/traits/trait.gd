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
@export var preview: Texture2D   # NEW

const TEMP_PREVIEW_PATH := "res://art/ui/temp-preview.png"

static func _load_preview(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return load(TEMP_PREVIEW_PATH)

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


const RARITY_BASE_WEIGHT := {
	Rarity.COMMON: 5.0,
	Rarity.UNCOMMON: 4.0,
	Rarity.RARE: 2.0,
	Rarity.EPIC: 1.0
}

func get_shop_weight() -> float:
	return RARITY_BASE_WEIGHT.get(rarity, 1.0) * rarity_weight
