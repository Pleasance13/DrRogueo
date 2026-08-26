extends Node


# ============================================================
# INVENTORY
# ============================================================
#
# Holds up to MAX_ITEMS items.
#
# All items are queued when selected.
#
# Normal items:
#   - Are removed from inventory immediately.
#   - Wait in pending_item.
#   - Fire when the current pill settles.
#
# Items that replace the next pill:
#   - Are removed from inventory immediately.
#   - Are attached to the NEXT pill.
#   - Do not fire through pending_item.
#
# The current falling pill is NEVER modified by selecting
# an item.
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


func is_full() -> bool:

	return items.find(null) == -1


# ============================================================
# QUEUE ITEM
# ============================================================
#
# Selecting an item ALWAYS affects a future turn.
#
# The current falling pill is completely untouched.
#
# Items with replaces_next_pill:
#   Become attached to the NEXT pill.
#
# Other items:
#   Wait in pending_item and fire when the current pill settles.
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
	#
	# Example: Tether.
	#
	# The item is attached to the NEXT pill immediately, but
	# its actual effect does not happen until that pill is
	# deployed.
	# ========================================================

	if item.replaces_next_pill:

		# Don't allow another next-pill item to be attached
		# if one is already pending on the preview.
		if pending_item != null:
			return


		# Remove the item from inventory immediately.
		items[index] = null


		pending_item = item
		pending_item_slot = index


		item.on_queue(board)


		# Attach the item to the NEXT pill.
		if not board.arm_next_pill_item(item):

			# Failed to attach.
			items[index] = item

			pending_item = null
			pending_item_slot = -1

			inventory_changed.emit()
			pending_item_changed.emit()

			return


		# ====================================================
		# The NEXT pill now owns the item.
		#
		# It should NOT also remain in pending_item, because
		# Tether is deployed directly by the special pill.
		# ====================================================

		pending_item = null
		pending_item_slot = -1


		inventory_changed.emit()
		pending_item_changed.emit()

		return


	# ========================================================
	# NORMAL QUEUED ITEM
	# ========================================================
	#
	# Example: Pong.
	#
	# The item is removed from inventory now, but its effect
	# does NOT happen now.
	#
	# It waits until the current pill settles, at which point
	# the board calls fire_pending().
	# ========================================================

	if pending_item != null:
		return


	# Remove the item from inventory immediately.
	items[index] = null


	# Store it for the current pill's settlement.
	pending_item = item
	pending_item_slot = index


	inventory_changed.emit()
	pending_item_changed.emit()


# ============================================================
# PENDING STATE
# ============================================================

func has_pending() -> bool:

	return pending_item != null


# ============================================================
# GET PENDING ITEM
# ============================================================

func get_pending_item() -> Item:

	return pending_item


# ============================================================
# COMPLETE PENDING ITEM
# ============================================================
#
# Called by the board AFTER the current pill has settled.
#
# The item is removed from pending state and then activated.
# ============================================================

func fire_pending(board: DrRogueoBoard) -> bool:

	if pending_item == null:
		return false


	var item := pending_item


	pending_item = null
	pending_item_slot = -1


	var success := item.use(board)


	if not success:

		# The item was consumed from its original slot, so there
		# is nowhere meaningful to refund it.
		#
		# Items that need transactional behavior should handle
		# that explicitly before being consumed.

		push_warning(
			"Inventory: Pending item failed after being consumed."
		)


	pending_item_changed.emit()

	return success


# ============================================================
# CANCEL PENDING ITEM
# ============================================================
#
# Used for normal queued items that need to be cancelled
# before they fire.
#
# Next-pill items also have their preview state removed.
# ============================================================

func cancel_pending(board: DrRogueoBoard) -> void:

	if pending_item == null:
		return


	var item := pending_item

	var slot := pending_item_slot


	pending_item = null
	pending_item_slot = -1


	if slot >= 0 and slot < items.size():

		if items[slot] == null:

			items[slot] = item


	# Tell board to remove the special preview state.
	if board != null:

		board.clear_next_pill_item()


	inventory_changed.emit()
	pending_item_changed.emit()


# ============================================================
# RUN RESET
# ============================================================

func reset() -> void:

	items = [null, null, null]

	pending_item = null
	pending_item_slot = -1

	inventory_changed.emit()
	pending_item_changed.emit()
