extends Node


# ============================================================
# INVENTORY
# ============================================================

const MAX_ITEMS := 3


signal inventory_changed
signal pending_item_changed


# Fixed-size inventory slots.
var items: Array[Item] = [null, null, null]


# Item waiting to fire when the current pill settles.
var pending_item: Item = null

# Original inventory slot of pending item.
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


func add_item_to_slot(
	item: Item,
	slot: int
) -> bool:

	if item == null:
		return false

	if slot < 0 or slot >= items.size():
		return false

	if items[slot] != null:
		return false

	items[slot] = item

	inventory_changed.emit()

	return true


func remove_item_from_slot(
	slot: int
) -> bool:

	if slot < 0 or slot >= items.size():
		return false

	if items[slot] == null:
		return false

	items[slot] = null

	inventory_changed.emit()

	return true


func is_full() -> bool:

	return items.find(null) == -1


# ============================================================
# QUEUE ITEM
# ============================================================

func use_item(
	index: int,
	board: DrRogueoBoard
) -> void:

	if board == null:
		return

	if index < 0 or index >= items.size():
		return

	if items[index] == null:
		return


	var item := items[index]


	# ========================================================
	# NEXT-PILL ITEM
	# ========================================================

	if item.replaces_next_pill:

		if pending_item != null:
			return


		items[index] = null

		pending_item = item
		pending_item_slot = index

		item.on_queue(board)


		if not board.arm_next_pill_item(item):

			items[index] = item

			pending_item = null
			pending_item_slot = -1

			inventory_changed.emit()
			pending_item_changed.emit()

			return


		pending_item = null
		pending_item_slot = -1

		inventory_changed.emit()
		pending_item_changed.emit()

		return


	# ========================================================
	# NORMAL QUEUED ITEM
	# ========================================================

	if pending_item != null:
		return


	items[index] = null

	pending_item = item
	pending_item_slot = index

	inventory_changed.emit()
	pending_item_changed.emit()


# ============================================================
# PENDING STATE
# ============================================================

func has_pending() -> bool:

	return pending_item != null


func get_pending_item() -> Item:

	return pending_item


# ============================================================
# COMPLETE PENDING ITEM
# ============================================================

func fire_pending(
	board: DrRogueoBoard
) -> bool:

	if pending_item == null:
		return false


	var item := pending_item

	pending_item = null
	pending_item_slot = -1

	var success := item.use(board)

	if not success:

		push_warning(
			"Inventory: Pending item failed after being consumed."
		)

	pending_item_changed.emit()

	return success


# ============================================================
# CANCEL PENDING ITEM
# ============================================================

func cancel_pending(
	board: DrRogueoBoard
) -> void:

	if pending_item == null:
		return


	var item := pending_item
	var slot := pending_item_slot

	pending_item = null
	pending_item_slot = -1


	if slot >= 0 and slot < items.size():

		if items[slot] == null:

			items[slot] = item


	if board != null:

		board.clear_next_pill_item()


	inventory_changed.emit()
	pending_item_changed.emit()


# ============================================================
# RESET
# ============================================================

func reset() -> void:

	items = [null, null, null]

	pending_item = null
	pending_item_slot = -1

	inventory_changed.emit()
	pending_item_changed.emit()
