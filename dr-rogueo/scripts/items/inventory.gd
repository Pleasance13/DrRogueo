extends Node


# ============================================================
# INVENTORY (autoload singleton)
# ============================================================
#
# Holds up to MAX_ITEMS items collected during a run.
#
# Register this script as an autoload named "Inventory"
# (Project Settings -> Autoload) so it's reachable from
# anywhere as `Inventory.xxx`, same as the prototype's global
# `run.inventory` state.
#
# UI hookup:
#   - Call Inventory.use_item(index, board) when a slot is
#     clicked. This QUEUES the item - it doesn't fire yet.
#   - Listen for `inventory_changed` / `pending_item_changed`
#     to redraw item slots and the "fires when this pill locks"
#     indicator.
#
# Board hookup (already wired into board.gd):
#   - DrRogueoBoard.settle_current_pill() calls
#     Inventory.fire_pending(self) right before resolving the
#     board, same timing as the prototype's lockPiece().
#
# ============================================================


const MAX_ITEMS := 3


signal inventory_changed

signal pending_item_changed


# Fixed-size, slot-indexed: items[i] is whatever occupies slot i
# (X/Y/B in the UI), or null if that slot is empty. Items stay
# put in their slot - using one only ever clears its own index,
# it never shifts the others down. Must stay the same size as
# items.gd's SLOT_COUNT.
var items: Array[Item] = [null, null, null]

var pending_item: Item = null

var pending_item_slot := -1


# ============================================================
# ADD / REMOVE
# ============================================================

func add_item(item: Item) -> bool:

	var slot := items.find(null)

	if slot == -1:
		return false

	items[slot] = item

	inventory_changed.emit()

	return true


func is_full() -> bool:
	return items.find(null) == -1


# ============================================================
# QUEUEING
# ============================================================
#
# Only one item can be queued at a time - while something's
# pending, other slots should render disabled in the UI (check
# has_pending() before calling this) so a player can't stack
# two effects onto the same pill drop.
#
func use_item(index: int, board: DrRogueoBoard) -> void:

	if pending_item != null:
		return

	if index < 0 or index >= items.size():
		return

	if items[index] == null:
		return

	pending_item = items[index]
	pending_item_slot = index

	items[index] = null

	pending_item.on_queue(board)

	inventory_changed.emit()
	pending_item_changed.emit()


func has_pending() -> bool:
	return pending_item != null


# ============================================================
# FIRING
# ============================================================
#
# Called by the board right before it resolves a locked pill.
# If the queued item's use() reports failure, it goes back into
# the inventory instead of being wasted.
#
func fire_pending(board: DrRogueoBoard) -> bool:

	if pending_item == null:
		return false

	var item := pending_item
	var slot := pending_item_slot

	pending_item = null
	pending_item_slot = -1

	var success := item.use(board)

	if not success:

		items[slot] = item

		inventory_changed.emit()


	pending_item_changed.emit()

	return success


# ============================================================
# RUN RESET
# ============================================================

func reset() -> void:

	items = [null, null, null]

	pending_item = null
	pending_item_slot = -1

	inventory_changed.emit()
	pending_item_changed.emit()
