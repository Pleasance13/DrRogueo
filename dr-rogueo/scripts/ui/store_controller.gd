@tool
class_name StoreController
extends Node2D


signal item_selected(item: Item)
signal trait_selected(trait_item: Trait)
signal closed


# ============================================================
# STORE SETUP
# ============================================================

@export_group("Store Setup")

@export var menu_controller_path: NodePath = NodePath("MenuController")

@export var item_slot_paths: Array[NodePath] = [
	NodePath("Items/Item1"),
	NodePath("Items/Item2"),
	NodePath("Items/Item3"),
	NodePath("Items/Item4"),
	NodePath("Items/Item5"),
	NodePath("Items/Item6")
]

@export var owned_item_paths: Array[NodePath] = [
	NodePath("OwnedItems/OwnedItem1"),
	NodePath("OwnedItems/OwnedItem2"),
	NodePath("OwnedItems/OwnedItem3")
]

@export var trait_slot_paths: Array[NodePath] = [
	NodePath("Traits/Trait1"),
	NodePath("Traits/Trait2"),
	NodePath("Traits/Trait3")
]

@export var owned_trait_paths: Array[NodePath] = [
	NodePath("OwnedTraits/OwnedTrait1"),
	NodePath("OwnedTraits/OwnedTrait2"),
	NodePath("OwnedTraits/OwnedTrait3")
]

@export var coin_label_path: NodePath = NodePath("Coins/Amount")

@export var clipboard_path: NodePath = NodePath("Clipboard")


# ============================================================
# DEBUG / STANDALONE F6 TESTING
# ============================================================

var debug_enabled := true

var debug_coins := 99
var debug_next_stage := 1

var debug_owned_slot_x := "__DEFAULT__"
var debug_owned_slot_y := "__DEFAULT__"
var debug_owned_slot_b := "__DEFAULT__"

var debug_store_slot_1 := "__DEFAULT__"
var debug_store_slot_2 := "__DEFAULT__"
var debug_store_slot_3 := "__DEFAULT__"
var debug_store_slot_4 := "__DEFAULT__"
var debug_store_slot_5 := "__DEFAULT__"
var debug_store_slot_6 := "__DEFAULT__"

var _debug_item_enum_signature := ""

const DEBUG_DEFAULT := "__DEFAULT__"


# ============================================================
# BACKGROUND
# ============================================================

@export_group("Background")

@export var background_path: NodePath = NodePath(
	"SubViewportContainer/SubViewport/Background"
)


# ============================================================
# RESTOCK BUTTON
# ============================================================

@export_group("Restock Button")

@export var restock_button_path: NodePath = NodePath("RestockButton")

@export var restock_price_font: Font:
	set(value):
		restock_price_font = value
		_queue_editor_preview_update()

@export_range(1, 32, 1)
var restock_price_font_size := 7:
	set(value):
		restock_price_font_size = value
		_queue_editor_preview_update()

@export var restock_price_color := Color.WHITE:
	set(value):
		restock_price_color = value
		_queue_editor_preview_update()

@export var restock_price_position := Vector2(24, 9):
	set(value):
		restock_price_position = value
		_queue_editor_preview_update()

@export var restock_price_size := Vector2(20, 10):
	set(value):
		restock_price_size = value
		_queue_editor_preview_update()

@export var restock_price_alignment := HORIZONTAL_ALIGNMENT_LEFT:
	set(value):
		restock_price_alignment = value
		_queue_editor_preview_update()


# ============================================================
# ITEM ICON
# ============================================================

@export_group("Item Icon")

@export var item_icon_position := Vector2(3, 4):
	set(value):
		item_icon_position = value
		_queue_editor_preview_update()


# ============================================================
# ITEM COIN ICON
# ============================================================

@export_group("Item Coin Icon")

@export var coin_texture: Texture2D:
	set(value):
		coin_texture = value
		_queue_editor_preview_update()

@export_range(1.0, 30.0, 1.0)
var coin_animation_fps := 8.0:
	set(value):
		coin_animation_fps = value
		_queue_editor_preview_update()

@export var coin_position := Vector2(39, 9):
	set(value):
		coin_position = value
		_queue_editor_preview_update()


# ============================================================
# ITEM PRICE
# ============================================================

@export_group("Item Price")

@export var price_font: Font:
	set(value):
		price_font = value
		_queue_editor_preview_update()

@export_range(1, 32, 1)
var price_font_size := 7:
	set(value):
		price_font_size = value
		_queue_editor_preview_update()

@export var price_color := Color.WHITE:
	set(value):
		price_color = value
		_queue_editor_preview_update()

@export var price_position := Vector2(39, 0):
	set(value):
		price_position = value
		_queue_editor_preview_update()

@export var price_size := Vector2(12, 10):
	set(value):
		price_size = value
		_queue_editor_preview_update()

@export var price_alignment := HORIZONTAL_ALIGNMENT_RIGHT:
	set(value):
		price_alignment = value
		_queue_editor_preview_update()


# ============================================================
# TRAIT ICON
# ============================================================

@export_group("Trait Icon")

@export var trait_icon_position := Vector2(6, 9):
	set(value):
		trait_icon_position = value
		_queue_editor_preview_update()


@export_group("Trait Coin Icon")

@export var trait_coin_position := Vector2(39, 9):
	set(value):
		trait_coin_position = value
		_queue_editor_preview_update()


@export_group("Trait Price")

@export var trait_price_position := Vector2(39, 0):
	set(value):
		trait_price_position = value
		_queue_editor_preview_update()


@export_group("Owned Trait Icon")

@export var owned_trait_icon_position := Vector2(7, 9):
	set(value):
		owned_trait_icon_position = value
		_queue_editor_preview_update()


# ============================================================
# ITEM LABEL
# ============================================================

@export_group("Item Label")

@export var label_font: Font:
	set(value):
		label_font = value
		_queue_editor_preview_update()

@export_range(1, 32, 1)
var label_font_size := 6:
	set(value):
		label_font_size = value
		_queue_editor_preview_update()

@export var label_color := Color.WHITE:
	set(value):
		label_color = value
		_queue_editor_preview_update()

@export var label_position := Vector2(0, 20):
	set(value):
		label_position = value
		_queue_editor_preview_update()

@export var label_size := Vector2(52, 12):
	set(value):
		label_size = value
		_queue_editor_preview_update()

@export var label_alignment := HORIZONTAL_ALIGNMENT_LEFT:
	set(value):
		label_alignment = value
		_queue_editor_preview_update()


# ============================================================
# RARITY
# ============================================================

@export_group("Rarity")

@export var rarity_font: Font:
	set(value):
		rarity_font = value
		_queue_editor_preview_update()

@export_range(1, 32, 1)
var rarity_font_size := 5:
	set(value):
		rarity_font_size = value
		_queue_editor_preview_update()

@export var rarity_color := Color.WHITE:
	set(value):
		rarity_color = value
		_queue_editor_preview_update()

@export var rarity_position := Vector2(0, 29):
	set(value):
		rarity_position = value
		_queue_editor_preview_update()

@export var rarity_size := Vector2(52, 10):
	set(value):
		rarity_size = value
		_queue_editor_preview_update()

@export var rarity_alignment := HORIZONTAL_ALIGNMENT_LEFT:
	set(value):
		rarity_alignment = value
		_queue_editor_preview_update()


# ============================================================
# EDITOR PREVIEW
# ============================================================

const EDITOR_PREFIX := "StoreEditorPreview"

const EDITOR_PRICE_TEXT := "00"
const EDITOR_LABEL_TEXT := "ITEM NAME"
const EDITOR_RARITY_TEXT := "RARITY"

var _editor_preview_created := false
var _editor_preview_update_queued := false


# ============================================================
# RESTOCK CONSTANTS
# ============================================================

const RESTOCK_BASE_COST := 1
const RESTOCK_MAX_COST := 5


# ============================================================
# RUNTIME
# ============================================================

var board: DrRogueoBoard
var menu: StoreMenuController
var store_items: Array[Item] = []

var restock_cost := RESTOCK_BASE_COST

var _restock_price_label: Label = null

var selected_slot := -1
var last_selected_slot := -1

var highlighted_name_label: Label
var highlighted_rarity_label: Label

var _standalone_debug_mode := false

# Tracks the exact visual nodes created for each store slot.
var _store_slot_visual_nodes: Array = []

# Tracks the exact visual node created for each owned-item slot.
var _owned_slot_visual_nodes: Array = []

# Temporary icon shown while choosing where to place
# a purchased item.
var _purchase_preview_icon: Sprite2D = null
var _purchase_preview_slot := -1

var store_traits: Array[Trait] = []

var selected_trait_slot := -1
var last_selected_trait_slot := -1

var _trait_slot_visual_nodes: Array = []
var _owned_trait_slot_visual_nodes: Array = []

var _trait_purchase_preview_icon: Sprite2D = null
var _trait_purchase_preview_slot := -1

# ============================================================
# CUSTOM INSPECTOR
# ============================================================

func _get_property_list() -> Array[Dictionary]:

	var properties: Array[Dictionary] = []

	# --------------------------------------------------------
	# CATEGORY
	# --------------------------------------------------------

	properties.append({
		"name": "Debug / F6 Testing",
		"type": TYPE_NIL,
		"usage": PROPERTY_USAGE_CATEGORY
	})


	# --------------------------------------------------------
	# DEBUG ENABLED
	# --------------------------------------------------------

	properties.append({
		"name": "debug_enabled",
		"type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT
	})


	# --------------------------------------------------------
	# DEBUG VALUES
	# --------------------------------------------------------

	var debug_value_usage := PROPERTY_USAGE_DEFAULT

	if not debug_enabled:
		debug_value_usage |= PROPERTY_USAGE_READ_ONLY


	properties.append({
		"name": "debug_coins",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0,9999,1",
		"usage": debug_value_usage
	})


	# --------------------------------------------------------
	# ITEM ENUM
	# --------------------------------------------------------

	var item_enum_hint := _get_debug_item_enum_hint()


	# --------------------------------------------------------
	# OWNED ITEMS
	# --------------------------------------------------------

	properties.append({
		"name": "debug_owned_slot_x",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": item_enum_hint,
		"usage": debug_value_usage
	})

	properties.append({
		"name": "debug_owned_slot_y",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": item_enum_hint,
		"usage": debug_value_usage
	})

	properties.append({
		"name": "debug_owned_slot_b",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": item_enum_hint,
		"usage": debug_value_usage
	})


	# --------------------------------------------------------
	# STORE ITEMS
	# --------------------------------------------------------

	properties.append({
		"name": "debug_store_slot_1",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": item_enum_hint,
		"usage": debug_value_usage
	})

	properties.append({
		"name": "debug_store_slot_2",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": item_enum_hint,
		"usage": debug_value_usage
	})

	properties.append({
		"name": "debug_store_slot_3",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": item_enum_hint,
		"usage": debug_value_usage
	})

	properties.append({
		"name": "debug_store_slot_4",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": item_enum_hint,
		"usage": debug_value_usage
	})

	properties.append({
		"name": "debug_store_slot_5",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": item_enum_hint,
		"usage": debug_value_usage
	})

	properties.append({
		"name": "debug_store_slot_6",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": item_enum_hint,
		"usage": debug_value_usage
	})


	# --------------------------------------------------------
	# NEXT STAGE
	# --------------------------------------------------------

	properties.append({
		"name": "debug_next_stage",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "1,999,1",
		"usage": debug_value_usage
	})


	return properties


func _get(property: StringName) -> Variant:

	match property:

		&"debug_enabled":
			return debug_enabled

		&"debug_coins":
			return debug_coins

		&"debug_owned_slot_x":
			return debug_owned_slot_x

		&"debug_owned_slot_y":
			return debug_owned_slot_y

		&"debug_owned_slot_b":
			return debug_owned_slot_b

		&"debug_store_slot_1":
			return debug_store_slot_1

		&"debug_store_slot_2":
			return debug_store_slot_2

		&"debug_store_slot_3":
			return debug_store_slot_3

		&"debug_store_slot_4":
			return debug_store_slot_4

		&"debug_store_slot_5":
			return debug_store_slot_5

		&"debug_store_slot_6":
			return debug_store_slot_6

		&"debug_next_stage":
			return debug_next_stage

	return null


func _set(property: StringName, value: Variant) -> bool:

	match property:

		&"debug_enabled":
			debug_enabled = bool(value)

			notify_property_list_changed()

			return true

		&"debug_coins":
			debug_coins = int(value)
			return true

		&"debug_owned_slot_x":
			debug_owned_slot_x = _debug_dropdown_value_to_id(
				str(value)
			)
			return true

		&"debug_owned_slot_y":
			debug_owned_slot_y = _debug_dropdown_value_to_id(
				str(value)
			)
			return true

		&"debug_owned_slot_b":
			debug_owned_slot_b = _debug_dropdown_value_to_id(
				str(value)
			)
			return true

		&"debug_store_slot_1":
			debug_store_slot_1 = _debug_dropdown_value_to_id(
				str(value)
			)
			return true

		&"debug_store_slot_2":
			debug_store_slot_2 = _debug_dropdown_value_to_id(
				str(value)
			)
			return true

		&"debug_store_slot_3":
			debug_store_slot_3 = _debug_dropdown_value_to_id(
				str(value)
			)
			return true

		&"debug_store_slot_4":
			debug_store_slot_4 = _debug_dropdown_value_to_id(
				str(value)
			)
			return true

		&"debug_store_slot_5":
			debug_store_slot_5 = _debug_dropdown_value_to_id(
				str(value)
			)
			return true

		&"debug_store_slot_6":
			debug_store_slot_6 = _debug_dropdown_value_to_id(
				str(value)
			)
			return true

		&"debug_next_stage":
			debug_next_stage = int(value)
			return true

	return false


func _get_debug_item_enum_hint() -> String:

	var options: Array[String] = [
		"Default",
		"None"
	]

	var catalog: Array[Item] = StoreCatalog.create_catalog()

	var used_names: Dictionary = {}

	for item in catalog:

		if item == null:
			continue

		var id: String = str(item.id)

		if id.is_empty():
			continue

		var display_name: String = str(item.display_name)

		if display_name.is_empty():
			display_name = id

		# If two items have the same display name, include the
		# ID so they can still be distinguished in the inspector.
		var option_name := display_name

		if used_names.has(option_name):

			option_name = "%s [%s]" % [
				display_name,
				id
			]

		used_names[option_name] = true

		options.append(option_name)

	return ",".join(options)


func _debug_dropdown_value_to_id(
	value: String
) -> String:

	value = value.strip_edges()

	# --------------------------------------------------------
	# DEFAULT
	#
	# Special internal value. This means:
	# "Do not interfere with this slot."
	# --------------------------------------------------------

	if value == "Default":
		return DEBUG_DEFAULT

	# --------------------------------------------------------
	# NONE
	#
	# Empty string is the internal representation for an
	# explicitly empty debug slot.
	# --------------------------------------------------------

	if value.is_empty() or value == "None":
		return ""

	var catalog: Array[Item] = StoreCatalog.create_catalog()

	for item in catalog:

		if item == null:
			continue

		var id := str(item.id)
		var display_name := str(item.display_name)

		# Normal display name match.
		if value == display_name:
			return id

		# Handles duplicate-name entries such as:
		# "PONG PILL [pong]"
		if value == "%s [%s]" % [
			display_name,
			id
		]:

			return id

		# Also accept the ID itself.
		if value == id:
			return id

	return ""


func _get_debug_item_enum_signature() -> String:

	var catalog: Array[Item] = StoreCatalog.create_catalog()

	var parts: Array[String] = []

	for item in catalog:

		if item == null:
			continue

		parts.append(
			"%s|%s" % [
				str(item.id),
				str(item.display_name)
			]
		)

	parts.sort()

	return ",".join(parts)


func _refresh_debug_item_dropdowns() -> void:

	if not Engine.is_editor_hint():
		return

	var signature := _get_debug_item_enum_signature()

	if signature == _debug_item_enum_signature:
		return

	_debug_item_enum_signature = signature

	notify_property_list_changed()


# ============================================================
# EDITOR
# ============================================================

func _enter_tree() -> void:

	if Engine.is_editor_hint():

		_debug_item_enum_signature = ""

		call_deferred(
			"_ensure_editor_preview"
		)

		call_deferred(
			"_refresh_debug_item_dropdowns"
		)


func _exit_tree() -> void:

	_editor_preview_created = false


func _process(_delta: float) -> void:

	if not Engine.is_editor_hint():
		return

	_refresh_debug_item_dropdowns()

	if _editor_preview_update_queued:

		_editor_preview_update_queued = false

		_update_editor_preview()


func _queue_editor_preview_update() -> void:

	if not Engine.is_editor_hint():
		return

	_editor_preview_update_queued = true


func _ensure_editor_preview() -> void:

	if not Engine.is_editor_hint():
		return

	if not is_inside_tree():
		return

	if _editor_preview_created:

		_update_editor_preview()

		return

	_create_editor_preview()



func _create_editor_preview() -> void:

	if not Engine.is_editor_hint():
		return

	if not is_inside_tree():
		return

	_editor_preview_created = true

	var name_label := get_node_or_null(
		EDITOR_PREFIX + "Label"
	) as Label

	if name_label == null:

		name_label = Label.new()
		name_label.name = EDITOR_PREFIX + "Label"

		add_child(name_label)

	name_label.text = EDITOR_LABEL_TEXT

	var rarity_label := get_node_or_null(
		EDITOR_PREFIX + "Rarity"
	) as Label

	if rarity_label == null:

		rarity_label = Label.new()
		rarity_label.name = EDITOR_PREFIX + "Rarity"

		add_child(rarity_label)

	rarity_label.text = EDITOR_RARITY_TEXT

	# --------------------------------------------------------
	# ITEM STORE SLOTS
	# --------------------------------------------------------

	for i in item_slot_paths.size():

		var slot := get_node_or_null(
			item_slot_paths[i]
		) as Node2D

		if slot == null:
			continue

		_create_editor_slot_preview(
			slot,
			i
		)

	# --------------------------------------------------------
	# TRAIT STORE SLOTS
	# --------------------------------------------------------

	for i in trait_slot_paths.size():

		var slot := get_node_or_null(
			trait_slot_paths[i]
		) as Node2D

		if slot == null:
			continue

		_create_editor_trait_slot_preview(
			slot,
			i
		)

	# --------------------------------------------------------
	# RESTOCK
	# --------------------------------------------------------

	var restock_slot := get_node_or_null(
		restock_button_path
	) as Node2D

	if restock_slot != null:

		_create_editor_restock_preview(
			restock_slot
		)

	_update_editor_preview()


func _create_editor_slot_preview(
	slot: Node2D,
	slot_index: int
) -> void:

	if coin_texture:

		var coin_name := (
			EDITOR_PREFIX
			+ "Coin"
			+ str(slot_index)
		)

		var coin := slot.get_node_or_null(
			coin_name
		) as AnimatedSprite2D

		if coin == null:

			coin = _create_coin_animation()
			coin.name = coin_name

			slot.add_child(coin)

		coin.position = _pixel_vector(
			coin_position
		)

	var price_name := (
		EDITOR_PREFIX
		+ "Price"
		+ str(slot_index)
	)

	var price_label := slot.get_node_or_null(
		price_name
	) as Label

	if price_label == null:

		price_label = Label.new()
		price_label.name = price_name

		slot.add_child(price_label)

	price_label.text = EDITOR_PRICE_TEXT


func _create_editor_trait_slot_preview(
	slot: Node2D,
	slot_index: int
) -> void:

	# --------------------------------------------------------
	# COIN
	# --------------------------------------------------------

	if coin_texture:

		var coin_name := (
			EDITOR_PREFIX
			+ "TraitCoin"
			+ str(slot_index)
		)

		var coin := slot.get_node_or_null(
			coin_name
		) as AnimatedSprite2D

		if coin == null:

			coin = _create_coin_animation()
			coin.name = coin_name

			slot.add_child(coin)

		coin.position = _pixel_vector(
			trait_coin_position
		)

	# --------------------------------------------------------
	# PRICE
	# --------------------------------------------------------

	var price_name := (
		EDITOR_PREFIX
		+ "TraitPrice"
		+ str(slot_index)
	)

	var price_label := slot.get_node_or_null(
		price_name
	) as Label

	if price_label == null:

		price_label = Label.new()
		price_label.name = price_name

		slot.add_child(price_label)

	price_label.text = EDITOR_PRICE_TEXT




func _create_editor_restock_preview(
	slot: Node2D
) -> void:

	var price_name := EDITOR_PREFIX + "RestockPrice"

	var price_label := slot.get_node_or_null(
		price_name
	) as Label

	if price_label == null:

		price_label = Label.new()
		price_label.name = price_name

		slot.add_child(price_label)

	price_label.text = "%d" % RESTOCK_BASE_COST


func _update_editor_preview() -> void:

	if not Engine.is_editor_hint():
		return

	if not is_inside_tree():
		return

	if not _editor_preview_created:

		_ensure_editor_preview()

		return

	var name_label := get_node_or_null(
		EDITOR_PREFIX + "Label"
	) as Label

	if name_label:

		name_label.text = EDITOR_LABEL_TEXT

		_apply_label_settings(
			name_label,
			label_position,
			label_size,
			label_alignment,
			label_font_size,
			label_color,
			label_font
		)

		name_label.visible = true

	var rarity_label := get_node_or_null(
		EDITOR_PREFIX + "Rarity"
	) as Label

	if rarity_label:

		rarity_label.text = EDITOR_RARITY_TEXT

		_apply_label_settings(
			rarity_label,
			rarity_position,
			rarity_size,
			rarity_alignment,
			rarity_font_size,
			rarity_color,
			rarity_font
		)

		rarity_label.visible = true

	# --------------------------------------------------------
	# RESTOCK PREVIEW
	# --------------------------------------------------------

	var restock_slot := get_node_or_null(
		restock_button_path
	) as Node2D

	if restock_slot != null:

		var restock_price := restock_slot.get_node_or_null(
			EDITOR_PREFIX + "RestockPrice"
		) as Label

		if restock_price:

			restock_price.text = "%d" % RESTOCK_BASE_COST

			_apply_label_settings(
				restock_price,
				restock_price_position,
				restock_price_size,
				restock_price_alignment,
				restock_price_font_size,
				restock_price_color,
				restock_price_font
			)

	# --------------------------------------------------------
	# ITEM STORE SLOTS
	# --------------------------------------------------------

	for i in item_slot_paths.size():

		var slot := get_node_or_null(
			item_slot_paths[i]
		) as Node2D

		if slot == null:
			continue

		var coin := slot.get_node_or_null(
			EDITOR_PREFIX + "Coin" + str(i)
		) as AnimatedSprite2D

		if coin:

			coin.position = _pixel_vector(
				coin_position
			)

			if coin_texture:

				coin.sprite_frames = (
					_build_coin_frames()
				)

				coin.animation = "default"
				coin.speed_scale = 1.0

				coin.play()

		var price_label := slot.get_node_or_null(
			EDITOR_PREFIX + "Price" + str(i)
		) as Label

		if price_label:

			price_label.text = EDITOR_PRICE_TEXT

			_apply_label_settings(
				price_label,
				price_position,
				price_size,
				price_alignment,
				price_font_size,
				price_color,
				price_font
			)

	# --------------------------------------------------------
	# TRAIT STORE SLOTS
	# --------------------------------------------------------

	for i in trait_slot_paths.size():

		var slot := get_node_or_null(
			trait_slot_paths[i]
		) as Node2D

		if slot == null:
			continue

		var coin := slot.get_node_or_null(
			EDITOR_PREFIX + "TraitCoin" + str(i)
		) as AnimatedSprite2D

		if coin:

			coin.position = _pixel_vector(
				trait_coin_position
			)

			if coin_texture:

				coin.sprite_frames = (
					_build_coin_frames()
				)

				coin.animation = "default"
				coin.speed_scale = 1.0

				coin.play()

		var price_label := slot.get_node_or_null(
			EDITOR_PREFIX + "TraitPrice" + str(i)
		) as Label

		if price_label:

			price_label.text = EDITOR_PRICE_TEXT

			_apply_label_settings(
				price_label,
				trait_price_position,
				price_size,
				price_alignment,
				price_font_size,
				price_color,
				price_font
			)


# ============================================================
# LABEL SETTINGS
# ============================================================

func _apply_label_settings(
	label: Label,
	position: Vector2,
	size: Vector2,
	alignment: HorizontalAlignment,
	font_size: int,
	color: Color,
	font: Font
) -> void:

	label.position = _pixel_vector(position)

	label.size = _pixel_vector(size)

	label.horizontal_alignment = alignment

	label.add_theme_font_size_override(
		"font_size",
		font_size
	)

	label.add_theme_color_override(
		"font_color",
		color
	)

	_apply_pixel_font(
		label,
		font
	)


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	if Engine.is_editor_hint():

		call_deferred(
			"_ensure_editor_preview"
		)

		return

	menu = get_node_or_null(
		menu_controller_path
	) as StoreMenuController

	if menu:

		menu.setup_store(self)

		menu.selection_changed.connect(
			_on_menu_selection_changed
		)

		menu.continue_pressed.connect(
			_on_continue_pressed
		)

	randomize()

	_create_highlighted_info_labels()

	# --------------------------------------------------------
	# Always create the normal store stock first.
	#
	# Debug "Default" means leave this stock alone.
	# --------------------------------------------------------

	_roll_stock()

	_roll_trait_stock()

	restock_cost = RESTOCK_BASE_COST

	_update_restock_visuals()

	# --------------------------------------------------------
	# Standalone F6 initialization is deferred so the scene
	# has finished entering the tree first.
	# --------------------------------------------------------

	call_deferred(
		"_initialize_standalone_debug"
	)

	_update_coin_display()
	
	_update_owned_visuals()

	_update_owned_trait_visuals()

	if menu:

		_on_menu_selection_changed(
			menu.current
		)

	call_deferred(
		"_apply_store_background"
	)


# ============================================================
# STANDALONE DEBUG INITIALIZATION
# ============================================================

func _initialize_standalone_debug() -> void:

	if Engine.is_editor_hint():
		return

	if board != null:
		return

	# --------------------------------------------------------
	# Debug disabled:
	#
	# F6 behaves exactly like a normal store.
	# --------------------------------------------------------

	if not debug_enabled:

		_standalone_debug_mode = false

		return

	_standalone_debug_mode = true

	# --------------------------------------------------------
	# COINS
	# --------------------------------------------------------

	_set_coins(
		debug_coins
	)

	# --------------------------------------------------------
	# INVENTORY
	#
	# DO NOT RESET INVENTORY.
	#
	# "Default" means debug does nothing to that slot.
	# We only modify slots that have an explicit debug value.
	# --------------------------------------------------------

	var owned_debug_values: Array[String] = [
		debug_owned_slot_x,
		debug_owned_slot_y,
		debug_owned_slot_b
	]

	for i in min(
		owned_debug_values.size(),
		Inventory.MAX_ITEMS
	):

		var debug_value := owned_debug_values[i].strip_edges()

		# ----------------------------------------------------
		# DEFAULT
		#
		# Do absolutely nothing.
		#
		# The existing inventory item remains untouched.
		# ----------------------------------------------------

		if debug_value == DEBUG_DEFAULT:
			continue

		# ----------------------------------------------------
		# NONE
		#
		# Explicitly empty this slot.
		# ----------------------------------------------------

		if debug_value.is_empty():

			Inventory.remove_item_from_slot(
				i
			)

			continue

		# ----------------------------------------------------
		# EXPLICIT ITEM
		#
		# Replace this slot with the requested item.
		# ----------------------------------------------------

		var item := _fresh_item(
			debug_value
		)

		if item == null:

			push_warning(
				"StoreController Debug: Could not find "
				+ "owned item ID: "
				+ debug_value
			)

			continue

		# Remove whatever is currently in this slot first.
		Inventory.remove_item_from_slot(
			i
		)

		Inventory.add_item_to_slot(
			item,
			i
		)

	# --------------------------------------------------------
	# STORE STOCK
	#
	# _roll_stock() already created the normal random stock.
	#
	# "Default" means leave the existing slot untouched.
	# Only explicit None/item values override the rolled stock.
	# --------------------------------------------------------

	var debug_store_values: Array[String] = [
		debug_store_slot_1,
		debug_store_slot_2,
		debug_store_slot_3,
		debug_store_slot_4,
		debug_store_slot_5,
		debug_store_slot_6
	]

	for i in debug_store_values.size():

		var debug_value := debug_store_values[i].strip_edges()

		# ----------------------------------------------------
		# DEFAULT
		#
		# Do absolutely nothing.
		#
		# The normally rolled store item remains untouched.
		# ----------------------------------------------------

		if debug_value == DEBUG_DEFAULT:
			continue

		# ----------------------------------------------------
		# NONE
		#
		# Explicitly empty this store slot.
		# ----------------------------------------------------

		if debug_value.is_empty():

			if i < store_items.size():

				store_items[i] = null

			else:

				while store_items.size() <= i:

					store_items.append(null)

			continue

		# ----------------------------------------------------
		# EXPLICIT ITEM
		#
		# Replace this store slot with the requested item.
		# ----------------------------------------------------

		var item := _fresh_item(
			debug_value
		)

		if item == null:

			push_warning(
				"StoreController Debug: Could not find "
				+ "store item ID: "
				+ debug_value
			)

			continue

		if i < store_items.size():

			store_items[i] = item

		else:

			while store_items.size() < i:

				store_items.append(null)

			store_items.append(item)

	_update_slot_visuals()

	_update_coin_display()

	_update_owned_visuals()

	if menu:

		_on_menu_selection_changed(
			menu.current
		)


# ============================================================
# BACKGROUND
# ============================================================

func _apply_store_background() -> void:

	if Engine.is_editor_hint():
		return

	var background := get_node_or_null(
		background_path
	) as Background

	if background == null:

		push_warning(
			"StoreController: Could not find Background at: "
			+ str(background_path)
		)

		return

	if not background.use_color_presets:

		push_warning(
			"StoreController: Background has "
			+ "use_color_presets disabled."
		)

		return

	background.runtime_preset_category = (
		BackgroundPreset.Category.STORE
	)

	background.apply_random_preset(
		BackgroundPreset.Category.STORE
	)


# ============================================================
# SETUP
# ============================================================

func setup(game_board: DrRogueoBoard) -> void:

	if Engine.is_editor_hint():
		return

	board = game_board

	# Once the real board exists, this is normal gameplay,
	# not standalone debug mode.
	_standalone_debug_mode = false

	_update_coin_display()

	_update_owned_visuals()

	_update_owned_trait_visuals()


# ============================================================
# COIN ACCESS
# ============================================================

func get_coins() -> int:

	if board != null:
		return board.coins

	# Debug coins are only valid in standalone debug mode.
	if _standalone_debug_mode and debug_enabled:
		return debug_coins

	# No real board and no active debug mode means there is no
	# real-game coin value to read.
	return 0


func set_coins(value: int) -> void:

	if board != null:

		board.coins = value

		return

	# Do not allow the debug value to act as a real coin store
	# when Debug Enabled is disabled.
	if _standalone_debug_mode and debug_enabled:

		debug_coins = value


func add_coins(amount: int) -> void:

	set_coins(
		get_coins() + amount
	)

	_update_coin_display()


func _set_coins(value: int) -> void:

	if board != null:

		board.coins = value

	elif _standalone_debug_mode and debug_enabled:

		debug_coins = value


# ============================================================
# STOCK
# ============================================================

func _roll_stock() -> void:

	if Engine.is_editor_hint():
		return

	store_items.clear()

	var catalog: Array[Item] = (
		StoreCatalog.create_catalog()
	)

	if catalog.is_empty():
		return

	for _i in item_slot_paths.size():

		var item := _random_item(
			catalog
		)

		if item:

			store_items.append(item)

		else:

			store_items.append(null)

	_update_slot_visuals()


func _random_item(
	catalog: Array[Item]
) -> Item:

	var valid_items: Array[Item] = []

	for item in catalog:

		if item:

			valid_items.append(item)

	if valid_items.is_empty():
		return null


	var total_weight := 0.0

	for item in valid_items:

		total_weight += item.get_shop_weight()


	if total_weight <= 0.0:

		var index: int = randi_range(
			0,
			valid_items.size() - 1
		)

		return _fresh_item(valid_items[index].id)


	var roll := randf() * total_weight

	var running := 0.0

	for item in valid_items:

		running += item.get_shop_weight()

		if roll < running:

			return _fresh_item(item.id)


	return _fresh_item(valid_items[-1].id)


func _fresh_item(id: String) -> Item:

	var clean_id := id.strip_edges()

	if clean_id.is_empty():
		return null

	var catalog: Array[Item] = (
		StoreCatalog.create_catalog()
	)

	# --------------------------------------------------------
	# Primary lookup: item ID.
	# --------------------------------------------------------

	for item in catalog:

		if item == null:
			continue

		if str(item.id) == clean_id:

			return item

	# --------------------------------------------------------
	# Fallback lookup: display name.
	# --------------------------------------------------------

	for item in catalog:

		if item == null:
			continue

		if str(item.display_name) == clean_id:

			return item

	return null


# ============================================================
# TRAIT STOCK
# ============================================================

func _roll_trait_stock() -> void:

	if Engine.is_editor_hint():
		return

	store_traits.clear()

	var catalog: Array[Trait] = (
		TraitCatalog.create_catalog()
	)

	if catalog.is_empty():
		return


	var available: Array[Trait] = []

	for trait_item in catalog:

		if trait_item:

			available.append(trait_item)


	for _i in trait_slot_paths.size():

		if available.is_empty():

			store_traits.append(null)

			continue


		var total_weight := 0.0

		for trait_item in available:

			total_weight += trait_item.get_shop_weight()


		var picked: Trait
		var picked_index := 0


		if total_weight <= 0.0:

			picked_index = randi_range(
				0,
				available.size() - 1
			)

			picked = available[picked_index]

		else:

			var roll := randf() * total_weight

			var running := 0.0

			picked = available[available.size() - 1]

			for i in range(available.size()):

				running += available[i].get_shop_weight()

				if roll < running:

					picked_index = i

					picked = available[i]

					break


		available.remove_at(picked_index)

		store_traits.append(
			_fresh_trait(picked.id)
		)

	_update_trait_slot_visuals()


func _fresh_trait(id: String) -> Trait:

	var clean_id := id.strip_edges()

	if clean_id.is_empty():
		return null

	var catalog: Array[Trait] = (
		TraitCatalog.create_catalog()
	)

	for trait_item in catalog:

		if trait_item == null:
			continue

		if str(trait_item.id) == clean_id:

			return trait_item

	for trait_item in catalog:

		if trait_item == null:
			continue

		if str(trait_item.display_name) == clean_id:

			return trait_item

	return null


	for trait_item in catalog:

		if trait_item == null:
			continue

		if str(trait_item.display_name) == clean_id:

			return trait_item

	return null


# ============================================================
# RESTOCK
# ============================================================

func restock() -> bool:

	if Engine.is_editor_hint():
		return false

	if get_coins() < restock_cost:
		return false

	set_coins(
		get_coins() - restock_cost
	)

	restock_cost = mini(
		restock_cost + 1,
		RESTOCK_MAX_COST
	)

	_roll_stock()

	_roll_trait_stock()

	_update_coin_display()

	_update_restock_visuals()

	return true


func _update_restock_visuals() -> void:

	if Engine.is_editor_hint():
		return

	var slot := get_node_or_null(
		restock_button_path
	) as Node2D

	if slot == null:
		return

	if _restock_price_label == null:

		_restock_price_label = Label.new()

		_restock_price_label.name = "RestockPrice"

		slot.add_child(_restock_price_label)

	_restock_price_label.text = "%d" % restock_cost

	_apply_label_settings(
		_restock_price_label,
		restock_price_position,
		restock_price_size,
		restock_price_alignment,
		restock_price_font_size,
		restock_price_color,
		restock_price_font
	)


# ============================================================
# STORE SLOT VISUALS
# ============================================================

func _update_slot_visuals() -> void:

	if Engine.is_editor_hint():
		return

	# Keep the tracking array the same length as the slot list.
	while _store_slot_visual_nodes.size() < item_slot_paths.size():

		_store_slot_visual_nodes.append([])

	for i in item_slot_paths.size():

		var slot := get_node_or_null(
			item_slot_paths[i]
		) as Node2D

		if slot == null:
			continue

		# ----------------------------------------------------
		# FREE EXACTLY WHAT WE CREATED LAST TIME
		# ----------------------------------------------------

		var old_nodes: Array = (
			_store_slot_visual_nodes[i]
		)

		for node in old_nodes:

			if is_instance_valid(node):

				node.free()

		_store_slot_visual_nodes[i] = []

		if i >= store_items.size():
			continue

		var item := store_items[i]

		if item == null:
			continue

		_add_item_visuals(
			slot,
			item,
			"StoreVisual",
			i
		)

	_update_highlighted_info()


func _add_item_visuals(
	slot: Node2D,
	item: Item,
	prefix: String,
	slot_index: int
) -> void:

	var created_nodes: Array = []

	if item.icon:

		var icon := Sprite2D.new()

		icon.name = prefix + "Icon"

		icon.texture = item.icon

		icon.centered = false

		icon.position = _pixel_vector(
			item_icon_position
		)

		slot.add_child(icon)

		created_nodes.append(icon)

	if coin_texture:

		var coin := _create_coin_animation()

		coin.name = prefix + "Coin"

		coin.position = _pixel_vector(
			coin_position
		)

		slot.add_child(coin)

		created_nodes.append(coin)

	var price_label := Label.new()

	price_label.name = prefix + "Price"

	price_label.text = "%02d" % item.cost

	_apply_label_settings(
		price_label,
		price_position,
		price_size,
		price_alignment,
		price_font_size,
		price_color,
		price_font
	)

	slot.add_child(price_label)

	created_nodes.append(price_label)

	_store_slot_visual_nodes[slot_index] = (
		created_nodes
	)


# ============================================================
# TRAIT SLOT VISUALS
# ============================================================

func _update_trait_slot_visuals() -> void:

	if Engine.is_editor_hint():
		return

	while _trait_slot_visual_nodes.size() < trait_slot_paths.size():

		_trait_slot_visual_nodes.append([])

	for i in trait_slot_paths.size():

		var slot := get_node_or_null(
			trait_slot_paths[i]
		) as Node2D

		if slot == null:
			continue

		var old_nodes: Array = (
			_trait_slot_visual_nodes[i]
		)

		for node in old_nodes:

			if is_instance_valid(node):

				node.free()

		_trait_slot_visual_nodes[i] = []

		if i >= store_traits.size():
			continue

		var trait_item := store_traits[i]

		if trait_item == null:
			continue

		_add_trait_visuals(
			slot,
			trait_item,
			"StoreTraitVisual",
			i
		)

	_update_highlighted_info()


func _add_trait_visuals(
	slot: Node2D,
	trait_item: Trait,
	prefix: String,
	slot_index: int
) -> void:

	var created_nodes: Array = []

	if trait_item.icon:

		var icon := Sprite2D.new()

		icon.name = prefix + "Icon"

		icon.texture = trait_item.icon

		icon.centered = false

		icon.position = _pixel_vector(
			trait_icon_position
		)

		slot.add_child(icon)

		created_nodes.append(icon)

	if coin_texture:

		var coin := _create_coin_animation()

		coin.name = prefix + "Coin"

		coin.position = _pixel_vector(
			trait_coin_position
		)

		slot.add_child(coin)

		created_nodes.append(coin)

	var price_label := Label.new()

	price_label.name = prefix + "Price"

	price_label.text = "%02d" % trait_item.cost

	_apply_label_settings(
		price_label,
		trait_price_position,
		price_size,
		price_alignment,
		price_font_size,
		price_color,
		price_font
	)

	slot.add_child(price_label)

	created_nodes.append(price_label)

	_trait_slot_visual_nodes[slot_index] = (
		created_nodes
	)


# ============================================================
# HIGHLIGHTED INFO
# ============================================================

func _create_highlighted_info_labels() -> void:

	highlighted_name_label = Label.new()

	highlighted_name_label.name = (
		"HighlightedItemLabel"
	)

	_apply_label_settings(
		highlighted_name_label,
		label_position,
		label_size,
		label_alignment,
		label_font_size,
		label_color,
		label_font
	)

	highlighted_name_label.visible = false

	add_child(
		highlighted_name_label
	)

	highlighted_rarity_label = Label.new()

	highlighted_rarity_label.name = (
		"HighlightedItemRarity"
	)

	_apply_label_settings(
		highlighted_rarity_label,
		rarity_position,
		rarity_size,
		rarity_alignment,
		rarity_font_size,
		rarity_color,
		rarity_font
	)

	highlighted_rarity_label.visible = false

	add_child(
		highlighted_rarity_label
	)


func _on_menu_selection_changed(
	selection: MenuSelectable
) -> void:

	if selection == null:
		return

	# --------------------------------------------------------
	# PURCHASE PLACEMENT (ITEM)
	# --------------------------------------------------------

	if (
		menu != null
		and menu.transaction_mode
		== StoreMenuController.TransactionMode.BUY_PLACEMENT
		and menu.transaction_kind
		== StoreMenuController.TransactionKind.ITEM
	):

		var owned_index := menu.owned_item_slots.find(
			selection
		)

		if owned_index >= 0:

			show_purchase_preview(
				menu.purchased_item,
				owned_index
			)

		return


	# --------------------------------------------------------
	# PURCHASE PLACEMENT (TRAIT)
	# --------------------------------------------------------

	if (
		menu != null
		and menu.transaction_mode
		== StoreMenuController.TransactionMode.BUY_PLACEMENT
		and menu.transaction_kind
		== StoreMenuController.TransactionKind.TRAIT
	):

		var owned_trait_index := menu.owned_trait_slots.find(
			selection
		)

		if owned_trait_index >= 0:

			show_trait_purchase_preview(
				menu.purchased_trait,
				owned_trait_index
			)

		return


	var index: int = _get_store_slot_index(
		selection
	)

	if index >= 0:

		_show_highlighted_info(
			index
		)

		return


	var trait_index: int = _get_store_trait_slot_index(
		selection
	)

	if trait_index >= 0:

		_show_highlighted_trait_info(
			trait_index
		)


func _get_store_slot_index(
	selection: MenuSelectable
) -> int:

	if menu == null:
		return -1

	return menu.store_item_slots.find(
		selection
	)


func _get_store_trait_slot_index(
	selection: MenuSelectable
) -> int:

	if menu == null:
		return -1

	return menu.store_trait_slots.find(
		selection
	)


func _show_highlighted_info(
	index: int
) -> void:

	if index < 0:
		return

	if index >= store_items.size():
		return

	var item := store_items[index]

	if item == null:
		return

	if highlighted_name_label == null:
		return

	if highlighted_rarity_label == null:
		return

	var display_name: String = (
		item.display_name
	)

	highlighted_name_label.text = (
		display_name
	)

	highlighted_rarity_label.text = (
		item.get_rarity_name()
	)

	highlighted_name_label.visible = true

	highlighted_rarity_label.visible = true


func _show_highlighted_trait_info(
	index: int
) -> void:

	if index < 0:
		return

	if index >= store_traits.size():
		return

	var trait_item := store_traits[index]

	if trait_item == null:
		return

	if highlighted_name_label == null:
		return

	if highlighted_rarity_label == null:
		return

	highlighted_name_label.text = (
		trait_item.display_name
	)

	highlighted_rarity_label.text = (
		trait_item.get_rarity_name()
	)

	highlighted_name_label.visible = true

	highlighted_rarity_label.visible = true


func _hide_highlighted_info() -> void:

	if highlighted_name_label:

		highlighted_name_label.visible = false

	if highlighted_rarity_label:

		highlighted_rarity_label.visible = false


func _update_highlighted_info() -> void:

	if menu == null:
		return

	if menu.current == null:
		return

	_on_menu_selection_changed(
		menu.current
	)


# ============================================================
# PURCHASE PLACEMENT PREVIEW
# ============================================================

func show_purchase_preview(
	item: Item,
	owned_slot: int
) -> void:

	if item == null:
		return

	if owned_slot < 0:
		return

	if owned_slot >= owned_item_paths.size():
		return

	var slot := get_node_or_null(
		owned_item_paths[owned_slot]
	) as Node2D

	if slot == null:
		return

	# --------------------------------------------------------
	# Create the temporary preview icon if necessary.
	# --------------------------------------------------------

	if _purchase_preview_icon == null:

		_purchase_preview_icon = Sprite2D.new()

		_purchase_preview_icon.name = (
			"PurchasePreviewIcon"
		)

		_purchase_preview_icon.centered = false

		slot.add_child(
			_purchase_preview_icon
		)

	# --------------------------------------------------------
	# If the highlight moved to another slot, move the preview
	# icon along with it.
	# --------------------------------------------------------

	elif _purchase_preview_icon.get_parent() != slot:

		_purchase_preview_icon.reparent(
			slot
		)

	_purchase_preview_icon.texture = item.icon

	_purchase_preview_icon.position = Vector2(4, 6)

	_purchase_preview_slot = owned_slot


func hide_purchase_preview() -> void:

	if _purchase_preview_icon:

		_purchase_preview_icon.free()

		_purchase_preview_icon = null

		_purchase_preview_slot = -1


# ============================================================
# TRAIT PURCHASE PLACEMENT PREVIEW
# ============================================================

func show_trait_purchase_preview(
	trait_item: Trait,
	owned_slot: int
) -> void:

	if trait_item == null:
		return

	if owned_slot < 0:
		return

	if owned_slot >= owned_trait_paths.size():
		return

	var slot := get_node_or_null(
		owned_trait_paths[owned_slot]
	) as Node2D

	if slot == null:
		return

	if _trait_purchase_preview_icon == null:

		_trait_purchase_preview_icon = Sprite2D.new()

		_trait_purchase_preview_icon.name = (
			"TraitPurchasePreviewIcon"
		)

		_trait_purchase_preview_icon.centered = false

		slot.add_child(
			_trait_purchase_preview_icon
		)

	elif _trait_purchase_preview_icon.get_parent() != slot:

		_trait_purchase_preview_icon.reparent(
			slot
		)

	_trait_purchase_preview_icon.texture = trait_item.icon

	_trait_purchase_preview_icon.position = _pixel_vector(
		owned_trait_icon_position
	)

	_trait_purchase_preview_slot = owned_slot


func hide_trait_purchase_preview() -> void:

	if _trait_purchase_preview_icon:

		_trait_purchase_preview_icon.free()

		_trait_purchase_preview_icon = null

		_trait_purchase_preview_slot = -1


# ============================================================
# COIN DISPLAY
# ============================================================

func _update_coin_display() -> void:

	if Engine.is_editor_hint():
		return

	var label := get_node_or_null(
		coin_label_path
	) as Label

	if label:

		label.text = str(
			get_coins()
		)

	_update_clipboard_display()


# ============================================================
# CLIPBOARD
# ============================================================

func _update_clipboard_display() -> void:

	if Engine.is_editor_hint():
		return

	var clipboard := get_node_or_null(
		clipboard_path
	) as Clipboard

	if clipboard == null:
		return

	clipboard.update_store_stats(
		_get_next_stage_number(),
		get_coins()
	)


func _get_next_stage_number() -> int:

	# board.level is already advanced to the UPCOMING level by
	# the time the store is opened.
	if board != null:

		return board.get_stage()

	# Debug next-stage value is only usable in standalone debug.
	if _standalone_debug_mode and debug_enabled:

		return debug_next_stage

	# Without a board or active debug mode, don't use the debug
	# value.
	return 1


# ============================================================
# OWNED ITEMS
# ============================================================

func _update_owned_visuals() -> void:

	if Engine.is_editor_hint():
		return

	while _owned_slot_visual_nodes.size() < owned_item_paths.size():

		_owned_slot_visual_nodes.append(null)

	for i in owned_item_paths.size():

		var slot := get_node_or_null(
			owned_item_paths[i]
		) as Node2D

		if slot == null:
			continue

		# ----------------------------------------------------
		# REMOVE ANY GENERATED OWNED/PURCHASE ICONS
		#
		# The inventory is the source of truth. We completely
		# rebuild the visual for this slot every time.
		# ----------------------------------------------------

		for child in slot.get_children():

			if (
				child.name == "OwnedVisualIcon"
				or child.name == "PurchasePreviewIcon"
			):

				child.free()

		_owned_slot_visual_nodes[i] = null

		# ----------------------------------------------------
		# EMPTY SLOT = NOTHING TO DRAW
		# ----------------------------------------------------

		if i >= Inventory.items.size():
			continue

		var item := Inventory.items[i]

		if item == null:
			continue

		if item.icon == null:
			continue

		# ----------------------------------------------------
		# DRAW THE ACTUAL OWNED ITEM
		# ----------------------------------------------------

		var icon := Sprite2D.new()

		icon.name = "OwnedVisualIcon"

		icon.texture = item.icon

		icon.centered = false

		icon.position = Vector2(4, 6)

		slot.add_child(icon)

		_owned_slot_visual_nodes[i] = icon


# ============================================================
# OWNED TRAITS
# ============================================================

func _update_owned_trait_visuals() -> void:

	if Engine.is_editor_hint():
		return

	while _owned_trait_slot_visual_nodes.size() < owned_trait_paths.size():

		_owned_trait_slot_visual_nodes.append(null)

	for i in owned_trait_paths.size():

		var slot := get_node_or_null(
			owned_trait_paths[i]
		) as Node2D

		if slot == null:
			continue

		for child in slot.get_children():

			if (
				child.name == "OwnedTraitVisualIcon"
				or child.name == "TraitPurchasePreviewIcon"
			):

				child.free()

		_owned_trait_slot_visual_nodes[i] = null

		if i >= TraitInventory.traits.size():
			continue

		var trait_item := TraitInventory.traits[i]

		if trait_item == null:
			continue

		if trait_item.icon == null:
			continue

		var icon := Sprite2D.new()

		icon.name = "OwnedTraitVisualIcon"

		icon.texture = trait_item.icon

		icon.centered = false

		icon.position = _pixel_vector(
			owned_trait_icon_position
		)

		slot.add_child(icon)

		_owned_trait_slot_visual_nodes[i] = icon


# ============================================================
# SELECTION
# ============================================================

func select_item_slot(index: int) -> void:

	if index < 0:
		return

	if index >= store_items.size():
		return

	if store_items[index] == null:
		return

	selected_slot = index

	last_selected_slot = index

	item_selected.emit(
		store_items[index]
	)


func select_trait_slot(index: int) -> void:

	if index < 0:
		return

	if index >= store_traits.size():
		return

	if store_traits[index] == null:
		return

	selected_trait_slot = index

	last_selected_trait_slot = index

	trait_selected.emit(
		store_traits[index]
	)


# ============================================================
# PURCHASE
# ============================================================

func buy_selected_item() -> Item:

	if selected_slot < 0:
		return null

	if selected_slot >= store_items.size():
		return null

	var item := store_items[selected_slot]

	if item == null:
		return null

	if get_coins() < item.cost:
		return null

	if Inventory.items.find(null) == -1:
		return null

	# IMPORTANT:
	# Do NOT deduct coins here.
	#
	# This function is now only used as a validation/access
	# function. The actual transaction happens when an owned
	# slot is confirmed.
	return item


func complete_purchase(
	item: Item,
	store_slot: int
) -> void:

	if item == null:
		return

	if store_slot < 0:
		return

	if store_slot >= store_items.size():
		return

	# --------------------------------------------------------
	# COMPLETE THE PURCHASE
	# --------------------------------------------------------

	set_coins(
		get_coins() - item.cost
	)

	_update_coin_display()

	# --------------------------------------------------------
	# REMOVE THE TEMPORARY PURCHASE PREVIEW
	# --------------------------------------------------------

	hide_purchase_preview()

	# --------------------------------------------------------
	# REMOVE THE EXACT STORE SLOT
	# --------------------------------------------------------

	store_items[store_slot] = null

	_update_slot_visuals()

	# Inventory was already updated by the menu controller.
	# Rebuild the owned visuals entirely from Inventory.items.
	_update_owned_visuals()


# ============================================================
# TRAIT PURCHASE
# ============================================================

func buy_selected_trait() -> Trait:

	if selected_trait_slot < 0:
		return null

	if selected_trait_slot >= store_traits.size():
		return null

	var trait_item := store_traits[selected_trait_slot]

	if trait_item == null:
		return null

	if get_coins() < trait_item.cost:
		return null

	if TraitInventory.traits.find(null) == -1:
		return null

	return trait_item


func complete_trait_purchase(
	trait_item: Trait,
	store_slot: int
) -> void:

	if trait_item == null:
		return

	if store_slot < 0:
		return

	if store_slot >= store_traits.size():
		return

	set_coins(
		get_coins() - trait_item.cost
	)

	_update_coin_display()

	hide_trait_purchase_preview()

	store_traits[store_slot] = null

	_update_trait_slot_visuals()

	_update_owned_trait_visuals()


# ============================================================
# SELL SUPPORT
# ============================================================

func sell_item(
	inventory_slot: int
) -> bool:

	if inventory_slot < 0:
		return false

	if inventory_slot >= Inventory.items.size():
		return false

	var item := Inventory.items[inventory_slot]

	if item == null:
		return false

	var sell_value: int = item.sell_price

	if not Inventory.remove_item_from_slot(
		inventory_slot
	):

		return false

	add_coins(
		sell_value
	)

	_update_coin_display()

	_update_owned_visuals()

	return true


func sell_trait(
	inventory_slot: int
) -> bool:

	if inventory_slot < 0:
		return false

	if inventory_slot >= TraitInventory.traits.size():
		return false

	var trait_item := TraitInventory.traits[inventory_slot]

	if trait_item == null:
		return false

	var sell_value: int = trait_item.sell_price

	if not TraitInventory.remove_trait_from_slot(
		inventory_slot
	):

		return false

	add_coins(
		sell_value
	)

	_update_coin_display()

	_update_owned_trait_visuals()

	return true


# ============================================================
# COIN ANIMATION
# ============================================================

func _build_coin_frames() -> SpriteFrames:

	var frames := SpriteFrames.new()

	if frames.has_animation("default"):

		frames.remove_animation(
			"default"
		)

	frames.add_animation(
		"default"
	)

	frames.set_animation_speed(
		"default",
		coin_animation_fps
	)

	frames.set_animation_loop(
		"default",
		true
	)

	if coin_texture:

		for frame_index in 6:

			var atlas := AtlasTexture.new()

			atlas.atlas = coin_texture

			atlas.region = Rect2(
				frame_index * 11,
				0,
				11,
				12
			)

			frames.add_frame(
				"default",
				atlas
			)

	return frames


func _create_coin_animation() -> AnimatedSprite2D:

	var coin := AnimatedSprite2D.new()

	coin.sprite_frames = (
		_build_coin_frames()
	)

	coin.animation = "default"

	coin.play()

	return coin


# ============================================================
# PIXEL PERFECT
# ============================================================

func _pixel_vector(
	value: Vector2
) -> Vector2:

	return Vector2(
		floor(value.x),
		floor(value.y)
	)


func _apply_pixel_font(
	label: Label,
	source_font: Font
) -> void:

	if source_font == null:
		return

	var font := source_font.duplicate()

	if font is FontFile:

		var pixel_font := font as FontFile

		pixel_font.antialiasing = (
			TextServer.FONT_ANTIALIASING_NONE
		)

		pixel_font.subpixel_positioning = (
			TextServer.SUBPIXEL_POSITIONING_DISABLED
		)

		pixel_font.oversampling = 1.0

	label.add_theme_font_override(
		"font",
		font
	)


# ============================================================
# CLOSE
# ============================================================

func _on_continue_pressed() -> void:

	closed.emit()
