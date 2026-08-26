class_name Item
extends Resource

# ============================================================
# ITEM (base class)
# ============================================================

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D

# ============================================================
# SHOP DATA
# ============================================================

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC
}

@export var rarity: Rarity = Rarity.COMMON
@export var rarity_weight: float = 1.0
@export var cost: int = 1

func get_rarity_name() -> String:
	match rarity:
		Rarity.COMMON: return "COMMON"
		Rarity.UNCOMMON: return "UNCOMMON"
		Rarity.RARE: return "RARE"
		Rarity.EPIC: return "EPIC"
	return "COMMON"

@export var replaces_next_pill := false

func on_queue(board: DrRogueoBoard) -> void:
	pass

func use(board: DrRogueoBoard) -> bool:
	return true
