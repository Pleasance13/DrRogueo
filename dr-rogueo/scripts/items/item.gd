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
# ITEM TYPE
# ============================================================

# Items that replace the NEXT pill use this system.
#
# When selected:
#
#   current pill stays untouched
#   next preview is replaced
#
# The special pill then falls and can be steered like any
# other pill. use() is NOT called automatically when it spawns
# - it only fires via Inventory.fire_pending(), either because
# the player deployed it (a per-item input, e.g. Tether's A
# button) or because it locked into the board without being
# deployed. This is the only path allowed to call use(); no
# other code should call it directly.
@export var replaces_next_pill := false


# ============================================================
# LIFECYCLE HOOKS
# ============================================================

func on_queue(board: DrRogueoBoard) -> void:
	pass


# Called by Inventory.fire_pending() once the item's effect
# should actually resolve - either the player deployed it, or
# it locked into the board unused.
#
# Return false if the item failed and should be returned to
# inventory.
func use(board: DrRogueoBoard) -> bool:
	return true
