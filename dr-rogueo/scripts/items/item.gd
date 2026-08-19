class_name Item
extends Resource


# ============================================================
# ITEM (base class)
# ============================================================
#
# Extend this to add a new inventory item. Override use() (and
# on_queue() if the item needs to roll/prepare something ahead
# of time) to implement its behavior. See item_pong.gd for an
# example.
#
# Items are data + behavior together (a Resource with an
# override-able use() function), matching the prototype's
# MODIFIER_POOL entries but as proper Godot objects instead of
# a plain array of dictionaries.
#
# ============================================================


@export var id: String = ""

@export var display_name: String = ""

@export_multiline var description: String = ""

@export var icon: Texture2D


# ============================================================
# LIFECYCLE HOOKS
# ============================================================

# Called the instant the item is queued (clicked in the
# inventory UI), before it actually fires on the next pill
# lock. Override for items that need to roll something ahead of
# time so a UI preview can show the real result immediately
# (Twin Bond in the prototype did this for its rolled colors).
func on_queue(board: DrRogueoBoard) -> void:
	pass


# Called when the queued item actually fires, right before the
# board resolves the pill that just locked. Return false if the
# use failed and the item should go back into the inventory
# instead of being consumed (e.g. no valid target was available).
func use(board: DrRogueoBoard) -> bool:
	return true
