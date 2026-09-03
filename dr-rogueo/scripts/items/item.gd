class_name Item
extends Resource

# ============================================================
# ITEM (base class)
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

# What the player gets back for selling this item at the store.
# Set independently per item (see each item's _init()) rather
# than derived from cost, so individual items can be tuned to
# sell for more/less than a straight fraction of their price.
@export var sell_price: int = 1

func get_rarity_name() -> String:
	match rarity:
		Rarity.COMMON: return "COMMON"
		Rarity.UNCOMMON: return "UNCOMMON"
		Rarity.RARE: return "RARE"
		Rarity.EPIC: return "EPIC"
	return "COMMON"


# ============================================================
# SHOP WEIGHT
# ============================================================
#
# Base odds by rarity tier. rarity_weight (export, default 1.0)
# multiplies on top of this, so individual items can still be
# tuned without touching every other item's numbers.
#
const RARITY_BASE_WEIGHT := {
	Rarity.COMMON: 5.0,
	Rarity.UNCOMMON: 4.0,
	Rarity.RARE: 2.0,
	Rarity.EPIC: 1.0
}

func get_shop_weight() -> float:
	return RARITY_BASE_WEIGHT.get(rarity, 1.0) * rarity_weight


@export var replaces_next_pill := false

func on_queue(board: DrRogueoBoard) -> void:
	pass

func use(board: DrRogueoBoard) -> bool:
	return true
