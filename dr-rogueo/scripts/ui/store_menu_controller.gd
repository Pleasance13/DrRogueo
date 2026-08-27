extends Node
class_name StoreMenuController


# ============================================================
# SETUP
# ============================================================

@export var current_path: NodePath

@export var owned_item_paths: Array[NodePath] = []

@export var owned_trait_paths: Array[NodePath] = []

@export var continue_button_path: NodePath

@export var buy_button_path: NodePath

@export var store_item_paths: Array[NodePath] = []


# ============================================================
# BUY / SELL BUTTON
# ============================================================

@export_group("Buy / Sell Button")

@export var buy_sell_texture: Texture2D


# ============================================================
# SIGNALS
# ============================================================

signal selection_changed(selection: MenuSelectable)

signal continue_pressed

signal purchase_started(item: Item)

signal purchase_completed(
	item: Item,
	owned_slot: int
)

signal sell_completed(
	item: Item,
	owned_slot: int
)


# ============================================================
# MENU REFERENCES
# ============================================================

var current: MenuSelectable

var owned_item_slots: Array[MenuSelectable] = []
var owned_trait_slots: Array[MenuSelectable] = []
var store_item_slots: Array[MenuSelectable] = []

var continue_button: MenuSelectable
var buy_button: MenuSelectable

var _last_owned_item: MenuSelectable
var _last_owned_trait: MenuSelectable


# ============================================================
# STORE
# ============================================================

var store: StoreController


# ============================================================
# TRANSACTION STATE
# ============================================================

enum TransactionMode {
	NONE,
	BUY_PLACEMENT,
	SELL_CONFIRM
}

var transaction_mode := TransactionMode.NONE

var purchased_item: Item = null

var selected_owned_slot := -1

# Remembers which store item was selected when a purchase began.
# This lets B return to that exact store slot.
var purchase_store_slot := -1

# Remembers which owned slot was selected when selling began.
# This lets B return to that exact owned item.
var sell_owned_slot := -1


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	current = get_node_or_null(
		current_path
	) as MenuSelectable


	continue_button = get_node_or_null(
		continue_button_path
	) as MenuSelectable


	buy_button = get_node_or_null(
		buy_button_path
	) as MenuSelectable


	for path in owned_item_paths:

		var slot := get_node_or_null(
			path
		) as MenuSelectable

		if slot:

			owned_item_slots.append(slot)


	for path in owned_trait_paths:

		var slot := get_node_or_null(
			path
		) as MenuSelectable

		if slot:

			owned_trait_slots.append(slot)


	for path in store_item_paths:

		var slot := get_node_or_null(
			path
		) as MenuSelectable

		if slot:

			store_item_slots.append(slot)


	if owned_item_slots.size() > 0:

		_last_owned_item = owned_item_slots[0]


	if owned_trait_slots.size() > 0:

		_last_owned_trait = owned_trait_slots[0]


	_update_button_visual()
	_update_highlights()


# ============================================================
# INPUT
# ============================================================

func _unhandled_input(
	event: InputEvent
) -> void:

	# --------------------------------------------------------
	# BACK / CANCEL
	# --------------------------------------------------------

	if event.is_action_pressed("ui_cancel"):

		_handle_cancel()

		return


	# --------------------------------------------------------
	# ACCEPT
	# --------------------------------------------------------

	if event.is_action_pressed("ui_accept"):

		_handle_accept()

		return


	# --------------------------------------------------------
	# DIRECTION
	# --------------------------------------------------------

	var dir: int = -1


	if event.is_action_pressed("ui_up"):

		dir = MenuSelectable.Dir.UP

	elif event.is_action_pressed("ui_down"):

		dir = MenuSelectable.Dir.DOWN

	elif event.is_action_pressed("ui_left"):

		dir = MenuSelectable.Dir.LEFT

	elif event.is_action_pressed("ui_right"):

		dir = MenuSelectable.Dir.RIGHT

	else:

		return


	_move(dir)


# ============================================================
# CANCEL / BACK
# ============================================================

func _handle_cancel() -> void:

	if current == null:
		return


	# --------------------------------------------------------
	# BUY PLACEMENT
	#
	# B cancels the placement and returns to the store item
	# that was purchased.
	# --------------------------------------------------------

	if transaction_mode == TransactionMode.BUY_PLACEMENT:

		_cancel_purchase()

		return


	# --------------------------------------------------------
	# SELL CONFIRM
	#
	# B cancels selling and returns to the owned item.
	# --------------------------------------------------------

	if transaction_mode == TransactionMode.SELL_CONFIRM:

		_cancel_sell()

		return


# ============================================================
# CANCEL PURCHASE
# ============================================================

func _cancel_purchase() -> void:

	transaction_mode = TransactionMode.NONE

	purchased_item = null

	selected_owned_slot = -1


	# Return to the exact store item that was purchased.
	if (
		purchase_store_slot >= 0
		and purchase_store_slot < store_item_slots.size()
	):

		_select(
			store_item_slots[
				purchase_store_slot
			]
		)

	elif store_item_slots.size() > 0:

		_select(
			store_item_slots[0]
		)


	purchase_store_slot = -1


# ============================================================
# CANCEL SELL
# ============================================================

func _cancel_sell() -> void:

	transaction_mode = TransactionMode.NONE

	selected_owned_slot = -1

	purchased_item = null


	# Return to the exact owned slot that was selected.
	if (
		sell_owned_slot >= 0
		and sell_owned_slot < owned_item_slots.size()
	):

		_select(
			owned_item_slots[
				sell_owned_slot
			]
		)

	elif owned_item_slots.size() > 0:

		_select(
			owned_item_slots[0]
		)


	sell_owned_slot = -1


# ============================================================
# ACCEPT
# ============================================================

func _handle_accept() -> void:

	if current == null:
		return


	# --------------------------------------------------------
	# BUY PLACEMENT
	# --------------------------------------------------------

	if transaction_mode == TransactionMode.BUY_PLACEMENT:

		if current in owned_item_slots:

			_equip_purchased_item(current)

		return


	# --------------------------------------------------------
	# SELL CONFIRM
	#
	# The only selectable thing during this state is the
	# BUY/SELL button.
	# --------------------------------------------------------

	if transaction_mode == TransactionMode.SELL_CONFIRM:

		if current == buy_button:

			_confirm_sell()

		return


	# --------------------------------------------------------
	# STORE ITEM
	# --------------------------------------------------------

	if current in store_item_slots:

		_try_select_store_item(current)

		return


	# --------------------------------------------------------
	# OWNED ITEM
	# --------------------------------------------------------

	if current in owned_item_slots:

		_try_select_owned_item(current)

		return


	# --------------------------------------------------------
	# BUY / SELL
	# --------------------------------------------------------

	if current == buy_button:

		_try_buy_or_sell()

		return


	# --------------------------------------------------------
	# CONTINUE
	# --------------------------------------------------------

	if current == continue_button:

		continue_pressed.emit()


# ============================================================
# NAVIGATION
# ============================================================

func _move(
	dir: int
) -> void:

	if current == null:
		return


	# --------------------------------------------------------
	# BUY PLACEMENT
	#
	# Only empty owned item slots are valid destinations.
	# --------------------------------------------------------

	if transaction_mode == TransactionMode.BUY_PLACEMENT:

		var next_owned := current.get_neighbor(
			dir
		) as MenuSelectable

		if next_owned and next_owned in owned_item_slots:

			var index := owned_item_slots.find(
				next_owned
			)

			if _is_owned_slot_empty(index):

				_select(next_owned)

		return


	# --------------------------------------------------------
	# SELL CONFIRM
	#
	# Completely confined to the BUY/SELL button.
	# --------------------------------------------------------

	if transaction_mode == TransactionMode.SELL_CONFIRM:

		return


	# --------------------------------------------------------
	# CONTINUE
	# --------------------------------------------------------

	if current == continue_button:

		if dir == MenuSelectable.Dir.UP:

			if _last_owned_item:

				_select(_last_owned_item)

			elif owned_item_slots.size() > 0:

				_select(
					owned_item_slots[0]
				)

			return


		if dir == MenuSelectable.Dir.DOWN:

			if _last_owned_trait:

				_select(_last_owned_trait)

			elif owned_trait_slots.size() > 0:

				_select(
					owned_trait_slots[0]
				)

			return


	# --------------------------------------------------------
	# NORMAL NAVIGATION
	# --------------------------------------------------------

	var next := current.get_neighbor(
		dir
	) as MenuSelectable

	if next:

		_select(next)


# ============================================================
# SELECT
# ============================================================

func _select(
	next: MenuSelectable
) -> void:

	if next == null:
		return


	# --------------------------------------------------------
	# BUY PLACEMENT
	#
	# Only empty owned item slots are legal.
	# --------------------------------------------------------

	if transaction_mode == TransactionMode.BUY_PLACEMENT:

		if next not in owned_item_slots:
			return


		var owned_index := owned_item_slots.find(
			next
		)


		if not _is_owned_slot_empty(
			owned_index
		):

			return


	# --------------------------------------------------------
	# SELL CONFIRM
	#
	# The only legal selection is the BUY/SELL button.
	# --------------------------------------------------------

	elif transaction_mode == TransactionMode.SELL_CONFIRM:

		if next != buy_button:
			return


	# --------------------------------------------------------
	# NORMAL MODE
	# --------------------------------------------------------

	else:

		if next not in owned_item_slots:

			selected_owned_slot = -1


	current = next


	if next in owned_item_slots:

		_last_owned_item = next


	if next in owned_trait_slots:

		_last_owned_trait = next


	_update_highlights()
	_update_button_visual()

	selection_changed.emit(current)


# ============================================================
# CHECK OWNED SLOT
# ============================================================

func _is_owned_slot_empty(
	index: int
) -> bool:

	if index < 0:
		return false


	if index >= Inventory.MAX_ITEMS:
		return false


	if index >= Inventory.items.size():
		return true


	return Inventory.items[index] == null


# ============================================================
# SELECT TRANSACTION BUTTON
# ============================================================

func _select_transaction_button() -> void:

	if buy_button == null:
		return


	current = buy_button

	_update_highlights()
	_update_button_visual()

	selection_changed.emit(current)


# ============================================================
# HIGHLIGHTS
# ============================================================

func _update_highlights() -> void:

	var root := get_parent()

	if root == null:
		return

	_update_highlights_recursive(root)


func _update_highlights_recursive(
	node: Node
) -> void:

	if node is MenuSelectable:

		_set_highlight(
			node as MenuSelectable,
			node == current
		)


	for child in node.get_children():

		_update_highlights_recursive(child)


func _set_highlight(
	selectable: MenuSelectable,
	shown: bool
) -> void:

	if selectable == null:
		return


	var highlight := selectable.get_node_or_null(
		"Highlight"
	) as CanvasItem

	if highlight:

		highlight.visible = shown


# ============================================================
# STORE SETUP
# ============================================================

func setup_store(
	store_controller: StoreController
) -> void:

	store = store_controller


	if not store.item_selected.is_connected(
		_on_store_item_selected
	):

		store.item_selected.connect(
			_on_store_item_selected
	)


# ============================================================
# STORE ITEM
# ============================================================

func _try_select_store_item(
	slot: MenuSelectable
) -> void:

	if store == null:
		return


	var index: int = store_item_slots.find(
		slot
	)

	if index < 0:
		return


	store.select_item_slot(index)


func _on_store_item_selected(
	item: Item
) -> void:

	if item == null:
		return


	transaction_mode = TransactionMode.NONE
	purchased_item = null
	selected_owned_slot = -1
	purchase_store_slot = -1
	sell_owned_slot = -1

	_select_transaction_button()


# ============================================================
# OWNED ITEM
# ============================================================

func _try_select_owned_item(
	slot: MenuSelectable
) -> void:

	if store == null:
		return


	var index: int = owned_item_slots.find(
		slot
	)

	if index < 0:
		return


	if index >= Inventory.items.size():
		return


	var item := Inventory.items[index]

	if item == null:
		return


	# --------------------------------------------------------
	# THIS IS NOW A DISTINCT SELL CONFIRM STATE.
	# --------------------------------------------------------

	selected_owned_slot = index

	sell_owned_slot = index

	transaction_mode = TransactionMode.SELL_CONFIRM

	purchased_item = null


	# Selecting an owned item moves to SELL.
	# It does NOT sell yet.
	_select_transaction_button()


# ============================================================
# BUY / SELL
# ============================================================

func _try_buy_or_sell() -> void:

	if selected_owned_slot >= 0:

		_confirm_sell()

		return


	_try_buy()


# ============================================================
# BUY
# ============================================================

func _try_buy() -> void:

	if store == null:
		return


	var item := _get_selected_store_item()

	if item == null:
		return


	# StoreController handles both real-board and F6-debug
	# coin sources.
	if store.get_coins() < item.cost:
		return


	var target := _first_empty_owned_slot()

	if target == null:
		return


	var purchased := store.buy_selected_item()

	if purchased == null:
		return


	purchased_item = purchased

	transaction_mode = TransactionMode.BUY_PLACEMENT

	selected_owned_slot = -1

	purchase_store_slot = store.last_selected_slot


	purchase_started.emit(
		purchased
	)


	_select(target)


# ============================================================
# FIRST EMPTY OWNED SLOT
# ============================================================

func _first_empty_owned_slot() -> MenuSelectable:

	var count: int = min(
		owned_item_slots.size(),
		Inventory.MAX_ITEMS
	)


	for i in count:

		if _is_owned_slot_empty(i):

			return owned_item_slots[i]


	return null


# ============================================================
# COMPLETE PURCHASE
# ============================================================

func _equip_purchased_item(
	slot: MenuSelectable
) -> void:

	if purchased_item == null:
		return


	if store == null:
		return


	var index: int = owned_item_slots.find(
		slot
	)

	if index < 0:
		return


	if index >= Inventory.MAX_ITEMS:
		return


	if index >= Inventory.items.size():
		return


	if Inventory.items[index] != null:
		return


	var item := purchased_item


	if not Inventory.add_item_to_slot(
		item,
		index
	):

		return


	# Store removes the exact store slot that was originally
	# purchased.
	store.complete_purchase(
		item,
		purchase_store_slot
	)


	purchase_completed.emit(
		item,
		index
	)


	purchased_item = null
	transaction_mode = TransactionMode.NONE
	selected_owned_slot = -1
	purchase_store_slot = -1


	if (
		store.last_selected_slot >= 0
		and store.last_selected_slot < store_item_slots.size()
	):

		_select(
			store_item_slots[
				store.last_selected_slot
			]
		)

	elif store_item_slots.size() > 0:

		_select(
			store_item_slots[0]
		)


# ============================================================
# SELL
# ============================================================

func _confirm_sell() -> void:

	if store == null:
		return


	if selected_owned_slot < 0:
		return


	if selected_owned_slot >= Inventory.items.size():
		return


	var slot: int = selected_owned_slot

	var item := Inventory.items[slot]

	if item == null:
		return


	# StoreController handles both real-board and standalone
	# debug coins.
	if not store.sell_item(slot):
		return


	sell_completed.emit(
		item,
		slot
	)


	selected_owned_slot = -1
	sell_owned_slot = -1
	transaction_mode = TransactionMode.NONE
	purchased_item = null


	# Keep selection on the slot that was just emptied.
	if slot < owned_item_slots.size():

		_select(
			owned_item_slots[slot]
		)


# ============================================================
# GET SELECTED STORE ITEM
# ============================================================

func _get_selected_store_item() -> Item:

	if store == null:
		return null


	if store.last_selected_slot < 0:
		return null


	if store.last_selected_slot >= store.store_items.size():
		return null


	return store.store_items[
		store.last_selected_slot
	]


# ============================================================
# BUTTON VISUAL
# ============================================================

func _update_button_visual() -> void:

	if buy_button == null:
		return


	if buy_sell_texture == null:
		return


	var column: int = 1
	var row: int = 0


	# --------------------------------------------------------
	# SELL
	# --------------------------------------------------------

	if selected_owned_slot >= 0:

		column = 1
		row = 1


	# --------------------------------------------------------
	# BUY
	# --------------------------------------------------------

	else:

		var item := _get_selected_store_item()

		if item != null:

			if store != null:

				if store.get_coins() >= item.cost:

					column = 0
					row = 1

				else:

					column = 0
					row = 0


	_set_button_sprite(
		column,
		row
	)


# ============================================================
# PRESSED BUTTON
# ============================================================

func _show_pressed_button() -> void:

	if buy_button == null:
		return


	if buy_sell_texture == null:
		return


	var column: int = 0
	var row: int = 2


	if selected_owned_slot >= 0:

		column = 1
		row = 2


	_set_button_sprite(
		column,
		row
	)


# ============================================================
# SET BUTTON SPRITE
# ============================================================

func _set_button_sprite(
	column: int,
	row: int
) -> void:

	if buy_button == null:
		return


	if buy_sell_texture == null:
		return


	var atlas := AtlasTexture.new()

	atlas.atlas = buy_sell_texture

	atlas.region = Rect2(
		column * 44,
		row * 29,
		44,
		29
	)


	buy_button.texture = atlas
