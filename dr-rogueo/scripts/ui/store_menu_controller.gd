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

@export var restock_button_path: NodePath

@export var store_item_paths: Array[NodePath] = []

@export var store_trait_paths: Array[NodePath] = []


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

signal trait_purchase_started(trait_item: Trait)

signal trait_purchase_completed(
	trait_item: Trait,
	owned_slot: int
)

signal trait_sell_completed(
	trait_item: Trait,
	owned_slot: int
)


# ============================================================
# MENU REFERENCES
# ============================================================

var current: MenuSelectable

var owned_item_slots: Array[MenuSelectable] = []
var owned_trait_slots: Array[MenuSelectable] = []
var store_item_slots: Array[MenuSelectable] = []
var store_trait_slots: Array[MenuSelectable] = []

var continue_button: MenuSelectable
var buy_button: MenuSelectable
var restock_button: MenuSelectable

var _last_owned_item: MenuSelectable
var _last_owned_trait: MenuSelectable


# ============================================================
# STORE
# ============================================================

var store: StoreController


# ============================================================
# TRANSACTION STATE
# ============================================================
#
# TransactionMode tracks WHICH STEP of a buy/sell is active.
# TransactionKind tracks WHETHER that step applies to an Item
# or a Trait. Splitting it this way avoids needing four
# separate transaction states.
#
# ============================================================

enum TransactionMode {
	NONE,
	BUY_PLACEMENT,
	SELL_CONFIRM
}

enum TransactionKind {
	ITEM,
	TRAIT
}

var transaction_mode := TransactionMode.NONE
var transaction_kind: TransactionKind = TransactionKind.ITEM

var purchased_item: Item = null
var selected_owned_slot := -1
var purchase_store_slot := -1
var sell_owned_slot := -1

var purchased_trait: Trait = null
var selected_owned_trait_slot := -1
var purchase_trait_store_slot := -1
var sell_owned_trait_slot := -1


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


	restock_button = get_node_or_null(
		restock_button_path
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


	for path in store_trait_paths:

		var slot := get_node_or_null(
			path
		) as MenuSelectable

		if slot:

			store_trait_slots.append(slot)


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
	# STORE SELECTION NOT YET CONFIRMED AS A PURCHASE
	#
	# The player picked an item/trait off the shelf (which
	# moves focus to the BUY/SELL button) but hasn't pressed
	# Accept on THAT yet to actually buy it. Cancelling here
	# just returns focus to the exact store slot -- no coins
	# spent, no stock touched, nothing to roll back.
	# --------------------------------------------------------

	if (
		transaction_mode == TransactionMode.NONE
		and current == buy_button
	):

		_cancel_store_selection()

		return


	if transaction_mode == TransactionMode.BUY_PLACEMENT:

		if transaction_kind == TransactionKind.ITEM:

			_cancel_purchase()

		else:

			_cancel_trait_purchase()

		return


	if transaction_mode == TransactionMode.SELL_CONFIRM:

		if transaction_kind == TransactionKind.ITEM:

			_cancel_sell()

		else:

			_cancel_trait_sell()

		return


# ============================================================
# CANCEL STORE SELECTION (PRE-PURCHASE)
# ============================================================

func _cancel_store_selection() -> void:

	if transaction_kind == TransactionKind.TRAIT:

		if (
			store != null
			and store.last_selected_trait_slot >= 0
			and store.last_selected_trait_slot < store_trait_slots.size()
		):

			_select(
				store_trait_slots[
					store.last_selected_trait_slot
				]
			)

		elif store_trait_slots.size() > 0:

			_select(
				store_trait_slots[0]
			)

		return


	if (
		store != null
		and store.last_selected_slot >= 0
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
# CANCEL PURCHASE (ITEM)
# ============================================================

func _cancel_purchase() -> void:

	transaction_mode = TransactionMode.NONE

	purchased_item = null

	selected_owned_slot = -1


	if store != null:

		store.hide_purchase_preview()


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
# CANCEL PURCHASE (TRAIT)
# ============================================================

func _cancel_trait_purchase() -> void:

	transaction_mode = TransactionMode.NONE

	purchased_trait = null

	selected_owned_trait_slot = -1


	if store != null:

		store.hide_trait_purchase_preview()


	if (
		purchase_trait_store_slot >= 0
		and purchase_trait_store_slot < store_trait_slots.size()
	):

		_select(
			store_trait_slots[
				purchase_trait_store_slot
			]
		)

	elif store_trait_slots.size() > 0:

		_select(
			store_trait_slots[0]
		)


	purchase_trait_store_slot = -1


# ============================================================
# CANCEL SELL (ITEM)
# ============================================================

func _cancel_sell() -> void:

	transaction_mode = TransactionMode.NONE

	selected_owned_slot = -1

	purchased_item = null


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
# CANCEL SELL (TRAIT)
# ============================================================

func _cancel_trait_sell() -> void:

	transaction_mode = TransactionMode.NONE

	selected_owned_trait_slot = -1

	purchased_trait = null


	if (
		sell_owned_trait_slot >= 0
		and sell_owned_trait_slot < owned_trait_slots.size()
	):

		_select(
			owned_trait_slots[
				sell_owned_trait_slot
			]
		)

	elif owned_trait_slots.size() > 0:

		_select(
			owned_trait_slots[0]
		)


	sell_owned_trait_slot = -1


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

		if transaction_kind == TransactionKind.ITEM:

			if current in owned_item_slots:

				_equip_purchased_item(current)

		else:

			if current in owned_trait_slots:

				_equip_purchased_trait(current)

		return


	# --------------------------------------------------------
	# SELL CONFIRM
	# --------------------------------------------------------

	if transaction_mode == TransactionMode.SELL_CONFIRM:

		if current == buy_button:

			if transaction_kind == TransactionKind.ITEM:

				_confirm_sell()

			else:

				_confirm_trait_sell()

		return


	# --------------------------------------------------------
	# RESTOCK
	# --------------------------------------------------------

	if current == restock_button:

		_try_restock()

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
	# STORE TRAIT
	# --------------------------------------------------------

	if current in store_trait_slots:

		_try_select_store_trait(current)

		return


	# --------------------------------------------------------
	# OWNED TRAIT
	# --------------------------------------------------------

	if current in owned_trait_slots:

		_try_select_owned_trait(current)

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
# RESTOCK
# ============================================================

func _try_restock() -> void:

	if store == null:
		return

	if transaction_mode != TransactionMode.NONE:
		return

	store.restock()


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
	# Only empty owned slots (item or trait, depending on
	# transaction_kind) are valid destinations.
	# --------------------------------------------------------

	if transaction_mode == TransactionMode.BUY_PLACEMENT:

		var owned_slots := (
			owned_item_slots
			if transaction_kind == TransactionKind.ITEM
			else owned_trait_slots
		)

		var next_owned := _find_next_empty_owned_slot(
			current,
			dir
		)

		if next_owned:

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
# FIND NEXT EMPTY OWNED SLOT (SKIPPING FILLED ONES)
# ============================================================

func _find_next_empty_owned_slot(
	from: MenuSelectable,
	dir: int
) -> MenuSelectable:

	var owned_slots := (
		owned_item_slots
		if transaction_kind == TransactionKind.ITEM
		else owned_trait_slots
	)

	var node := from

	var visited: Dictionary = {}


	while true:

		var next := node.get_neighbor(dir) as MenuSelectable

		if next == null:

			return null


		if visited.has(next):

			return null

		visited[next] = true


		var index := owned_slots.find(next)

		if index == -1:

			return null


		var slot_empty := (
			_is_owned_slot_empty(index)
			if transaction_kind == TransactionKind.ITEM
			else _is_owned_trait_slot_empty(index)
		)

		if slot_empty:

			return next


		node = next

	return null


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
	# Only empty owned slots of the matching kind are legal.
	# --------------------------------------------------------

	if transaction_mode == TransactionMode.BUY_PLACEMENT:

		var owned_slots := (
			owned_item_slots
			if transaction_kind == TransactionKind.ITEM
			else owned_trait_slots
		)

		if next not in owned_slots:
			return


		var owned_index := owned_slots.find(
			next
		)


		var slot_empty := (
			_is_owned_slot_empty(owned_index)
			if transaction_kind == TransactionKind.ITEM
			else _is_owned_trait_slot_empty(owned_index)
		)

		if not slot_empty:

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


		if next not in owned_trait_slots:

			selected_owned_trait_slot = -1


	current = next


	if next in owned_item_slots:

		_last_owned_item = next


	if next in owned_trait_slots:

		_last_owned_trait = next


	_update_highlights()
	_update_button_visual()

	selection_changed.emit(current)


# ============================================================
# CHECK OWNED SLOT (ITEM)
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
# CHECK OWNED SLOT (TRAIT)
# ============================================================

func _is_owned_trait_slot_empty(
	index: int
) -> bool:

	if index < 0:
		return false


	if index >= TraitInventory.MAX_TRAITS:
		return false


	if index >= TraitInventory.traits.size():
		return true


	return TraitInventory.traits[index] == null


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


	if not store.trait_selected.is_connected(
		_on_store_trait_selected
	):

		store.trait_selected.connect(
			_on_store_trait_selected
	)


# ============================================================
# RESET TRANSACTION STATE
# ============================================================

func _reset_transaction_state() -> void:

	transaction_mode = TransactionMode.NONE

	purchased_item = null
	selected_owned_slot = -1
	purchase_store_slot = -1
	sell_owned_slot = -1

	purchased_trait = null
	selected_owned_trait_slot = -1
	purchase_trait_store_slot = -1
	sell_owned_trait_slot = -1


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


	_reset_transaction_state()

	transaction_kind = TransactionKind.ITEM

	_select_transaction_button()


# ============================================================
# STORE TRAIT
# ============================================================

func _try_select_store_trait(
	slot: MenuSelectable
) -> void:

	if store == null:
		return


	var index: int = store_trait_slots.find(
		slot
	)

	if index < 0:
		return


	store.select_trait_slot(index)


func _on_store_trait_selected(
	trait_item: Trait
) -> void:

	if trait_item == null:
		return


	_reset_transaction_state()

	transaction_kind = TransactionKind.TRAIT

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


	selected_owned_trait_slot = -1

	selected_owned_slot = index

	sell_owned_slot = index

	transaction_mode = TransactionMode.SELL_CONFIRM
	transaction_kind = TransactionKind.ITEM

	purchased_item = null


	_select_transaction_button()


# ============================================================
# OWNED TRAIT
# ============================================================

func _try_select_owned_trait(
	slot: MenuSelectable
) -> void:

	if store == null:
		return


	var index: int = owned_trait_slots.find(
		slot
	)

	if index < 0:
		return


	if index >= TraitInventory.traits.size():
		return


	var trait_item := TraitInventory.traits[index]

	if trait_item == null:
		return


	selected_owned_slot = -1

	selected_owned_trait_slot = index

	sell_owned_trait_slot = index

	transaction_mode = TransactionMode.SELL_CONFIRM
	transaction_kind = TransactionKind.TRAIT

	purchased_trait = null


	_select_transaction_button()


# ============================================================
# BUY / SELL
# ============================================================

func _try_buy_or_sell() -> void:

	if selected_owned_slot >= 0:

		_confirm_sell()

		return


	if selected_owned_trait_slot >= 0:

		_confirm_trait_sell()

		return


	if transaction_kind == TransactionKind.TRAIT:

		_try_buy_trait()

		return


	_try_buy()


# ============================================================
# BUY (ITEM)
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
	transaction_kind = TransactionKind.ITEM

	selected_owned_slot = -1

	purchase_store_slot = store.last_selected_slot


	purchase_started.emit(
		purchased
	)


	_select(target)


# ============================================================
# BUY (TRAIT)
# ============================================================

func _try_buy_trait() -> void:

	if store == null:
		return


	var trait_item := _get_selected_store_trait()

	if trait_item == null:
		return


	if store.get_coins() < trait_item.cost:
		return


	var target := _first_empty_owned_trait_slot()

	if target == null:
		return


	var purchased := store.buy_selected_trait()

	if purchased == null:
		return


	purchased_trait = purchased

	transaction_mode = TransactionMode.BUY_PLACEMENT
	transaction_kind = TransactionKind.TRAIT

	selected_owned_trait_slot = -1

	purchase_trait_store_slot = store.last_selected_trait_slot


	trait_purchase_started.emit(
		purchased
	)


	_select(target)


# ============================================================
# FIRST EMPTY OWNED SLOT (ITEM)
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
# FIRST EMPTY OWNED SLOT (TRAIT)
# ============================================================

func _first_empty_owned_trait_slot() -> MenuSelectable:

	var count: int = min(
		owned_trait_slots.size(),
		TraitInventory.MAX_TRAITS
	)


	for i in count:

		if _is_owned_trait_slot_empty(i):

			return owned_trait_slots[i]


	return null


# ============================================================
# COMPLETE PURCHASE (ITEM)
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
# COMPLETE PURCHASE (TRAIT)
# ============================================================

func _equip_purchased_trait(
	slot: MenuSelectable
) -> void:

	if purchased_trait == null:
		return


	if store == null:
		return


	var index: int = owned_trait_slots.find(
		slot
	)

	if index < 0:
		return


	if index >= TraitInventory.MAX_TRAITS:
		return


	if index >= TraitInventory.traits.size():
		return


	if TraitInventory.traits[index] != null:
		return


	var trait_item := purchased_trait


	if not TraitInventory.add_trait_to_slot(
		trait_item,
		index
	):

		return


	store.complete_trait_purchase(
		trait_item,
		purchase_trait_store_slot
	)


	trait_purchase_completed.emit(
		trait_item,
		index
	)


	purchased_trait = null
	transaction_mode = TransactionMode.NONE
	selected_owned_trait_slot = -1
	purchase_trait_store_slot = -1


	if (
		store.last_selected_trait_slot >= 0
		and store.last_selected_trait_slot < store_trait_slots.size()
	):

		_select(
			store_trait_slots[
				store.last_selected_trait_slot
			]
		)

	elif store_trait_slots.size() > 0:

		_select(
			store_trait_slots[0]
		)


# ============================================================
# SELL (ITEM)
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


	if slot < owned_item_slots.size():

		_select(
			owned_item_slots[slot]
		)


# ============================================================
# SELL (TRAIT)
# ============================================================

func _confirm_trait_sell() -> void:

	if store == null:
		return


	if selected_owned_trait_slot < 0:
		return


	if selected_owned_trait_slot >= TraitInventory.traits.size():
		return


	var slot: int = selected_owned_trait_slot

	var trait_item := TraitInventory.traits[slot]

	if trait_item == null:
		return


	if not store.sell_trait(slot):
		return


	trait_sell_completed.emit(
		trait_item,
		slot
	)


	selected_owned_trait_slot = -1
	sell_owned_trait_slot = -1
	transaction_mode = TransactionMode.NONE
	purchased_trait = null


	if slot < owned_trait_slots.size():

		_select(
			owned_trait_slots[slot]
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
# GET SELECTED STORE TRAIT
# ============================================================

func _get_selected_store_trait() -> Trait:

	if store == null:
		return null


	if store.last_selected_trait_slot < 0:
		return null


	if store.last_selected_trait_slot >= store.store_traits.size():
		return null


	return store.store_traits[
		store.last_selected_trait_slot
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

	if selected_owned_slot >= 0 or selected_owned_trait_slot >= 0:

		column = 1
		row = 1


	# --------------------------------------------------------
	# BUY
	# --------------------------------------------------------

	else:

		if transaction_kind == TransactionKind.TRAIT:

			var trait_item := _get_selected_store_trait()

			if trait_item != null and store != null:

				if store.get_coins() >= trait_item.cost:

					column = 0
					row = 1

				else:

					column = 0
					row = 0

		else:

			var item := _get_selected_store_item()

			if item != null and store != null:

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


	if selected_owned_slot >= 0 or selected_owned_trait_slot >= 0:

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
