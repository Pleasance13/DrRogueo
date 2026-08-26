extends Node
class_name StoreMenuController

## Store navigation + purchase flow.
## The controller owns selection/highlights and delegates actual purchases
## to StoreMenuController's store data logic.

@export var current_path: NodePath
@export var owned_item_paths: Array[NodePath] = []
@export var owned_trait_paths: Array[NodePath] = []
@export var continue_button_path: NodePath
@export var buy_button_path: NodePath
@export var store_item_paths: Array[NodePath] = []

signal selection_changed(selection: MenuSelectable)
signal continue_pressed
signal purchase_started(item: Item)
signal purchase_completed(item: Item, owned_slot: int)

var current: MenuSelectable
var owned_item_slots: Array[MenuSelectable] = []
var owned_trait_slots: Array[MenuSelectable] = []
var store_item_slots: Array[MenuSelectable] = []
var continue_button: MenuSelectable
var buy_button: MenuSelectable

var _last_owned_item: MenuSelectable
var _last_owned_trait: MenuSelectable

# 0 = normal shopping, 1 = choosing an owned item slot after purchase.
var purchase_mode := false
var purchased_item: Item = null

# Filled by the store controller after ready.
var store: StoreController

func _ready() -> void:
	current = get_node_or_null(current_path) as MenuSelectable
	continue_button = get_node_or_null(continue_button_path) as MenuSelectable
	buy_button = get_node_or_null(buy_button_path) as MenuSelectable

	for p in owned_item_paths:
		var slot := get_node_or_null(p) as MenuSelectable
		if slot:
			owned_item_slots.append(slot)

	for p in owned_trait_paths:
		var slot := get_node_or_null(p) as MenuSelectable
		if slot:
			owned_trait_slots.append(slot)

	for p in store_item_paths:
		var slot := get_node_or_null(p) as MenuSelectable
		if slot:
			store_item_slots.append(slot)

	if owned_item_slots.size() > 0:
		_last_owned_item = owned_item_slots[0]
	if owned_trait_slots.size() > 0:
		_last_owned_trait = owned_trait_slots[0]

	# Make sure the initial selection is visibly highlighted immediately.
	_update_highlights()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_handle_accept()
		return

	var dir := -1
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

func _handle_accept() -> void:
	if not current:
		return

	if purchase_mode:
		if current in owned_item_slots:
			_equip_purchased_item(current)
		return

	if current in store_item_slots:
		_try_select_store_item(current)
		return

	if current == buy_button:
		_try_buy()
		return

	if current == continue_button:
		continue_pressed.emit()

func _move(dir: int) -> void:
	if not current:
		return

	# During the equip step, navigation is restricted to owned item slots.
	if purchase_mode:
		var next_owned := current.get_neighbor(dir) as MenuSelectable
		if next_owned and next_owned in owned_item_slots:
			_select(next_owned)
			return
		return

	# Continue has stateful vertical navigation in both directions.
	if current == continue_button:
		if dir == MenuSelectable.Dir.UP:
			if _last_owned_item:
				_select(_last_owned_item)
			elif owned_item_slots.size() > 0:
				_select(owned_item_slots[0])
			return

		if dir == MenuSelectable.Dir.DOWN:
			if _last_owned_trait:
				_select(_last_owned_trait)
			elif owned_trait_slots.size() > 0:
				_select(owned_trait_slots[0])
			return

	var next := current.get_neighbor(dir) as MenuSelectable
	if next:
		_select(next)

func _select(next: MenuSelectable) -> void:
	current = next

	if next in owned_item_slots:
		_last_owned_item = next
	if next in owned_trait_slots:
		_last_owned_trait = next

	_update_highlights()
	selection_changed.emit(current)

func _update_highlights() -> void:
	# Hide/show every selectable's child Highlight, including bottles,
	# traits, Restock, Buy, Continue, store slots and owned slots.
	var root := get_parent()
	if root == null:
		return

	_update_highlights_recursive(root)

func _update_highlights_recursive(node: Node) -> void:
	if node is MenuSelectable:
		_set_highlight(node as MenuSelectable, node == current)

	for child in node.get_children():
		_update_highlights_recursive(child)

func _set_highlight(selectable: MenuSelectable, shown: bool) -> void:
	if not selectable:
		return
	var highlight := selectable.get_node_or_null("Highlight") as CanvasItem
	if highlight:
		highlight.visible = shown

func setup_store(store_controller: StoreController) -> void:
	store = store_controller
	store.item_selected.connect(_on_store_item_selected)

func _try_select_store_item(slot: MenuSelectable) -> void:
	if store == null:
		return
	store.select_item_slot(store_item_slots.find(slot))

func _on_store_item_selected(item: Item) -> void:
	if item == null:
		return
	# Selecting a store item only moves to Buy; it does not purchase yet.
	if buy_button:
		_select(buy_button)

func _try_buy() -> void:
	if store == null:
		return

	var item := store.buy_selected_item()
	if item == null:
		return

	purchased_item = item
	purchase_mode = true
	purchase_started.emit(item)

	# Start at the first empty owned item slot if possible.
	var target := _first_empty_owned_slot()
	if target == null and owned_item_slots.size() > 0:
		target = owned_item_slots[0]
	if target:
		_select(target)

func _first_empty_owned_slot() -> MenuSelectable:
	if store == null:
		return null
	for i in range(min(owned_item_slots.size(), Inventory.MAX_ITEMS)):
		if Inventory.items[i] == null:
			return owned_item_slots[i]
	return null

func _equip_purchased_item(slot: MenuSelectable) -> void:
	if purchased_item == null or store == null:
		return

	var index := owned_item_slots.find(slot)
	if index < 0 or index >= Inventory.MAX_ITEMS:
		return

	if Inventory.items[index] != null:
		return

	if not Inventory.add_item_to_slot(purchased_item, index):
		return

	store.finish_purchase(index)
	purchase_completed.emit(purchased_item, index)
	purchased_item = null
	purchase_mode = false

	# Return to the item that was just purchased so another A can buy again.
	if store.last_selected_slot >= 0 and store.last_selected_slot < store_item_slots.size():
		_select(store_item_slots[store.last_selected_slot])
	elif store_item_slots.size() > 0:
		_select(store_item_slots[0])
