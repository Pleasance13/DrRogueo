@tool
class_name StoreController
extends Node2D

signal item_selected(item: Item)
signal closed


# ============================================================
# STORE SETUP
# ============================================================

@export_category("Store Setup")

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

@export var coin_label_path: NodePath = NodePath("Coins/Amount")


# ============================================================
# BACKGROUND
# ============================================================

@export_category("Background")

@export var background_path: NodePath = NodePath(
	"SubViewportContainer/SubViewport/Background"
)


# ============================================================
# COIN ICON
# ============================================================

@export_category("Coin Icon")

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
# ITEM ICON
# ============================================================

@export_category("Item Icon")

@export var item_icon_position := Vector2(6, 9):
	set(value):
		item_icon_position = value
		_queue_editor_preview_update()


# ============================================================
# SLOT LABEL OVERRIDES
# ============================================================

@export_category("Slot Labels")

@export var slot_labels: Array[String] = [
	"",
	"",
	"",
	"",
	"",
	""
]


# ============================================================
# ITEM LABEL
# ============================================================

@export_category("Item Label")

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

@export_category("Rarity")

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
# PRICE
# ============================================================

@export_category("Price")

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
# EDITOR PREVIEW
# ============================================================

const EDITOR_PREFIX := "StoreEditorPreview"

const EDITOR_PRICE_TEXT := "00"
const EDITOR_LABEL_TEXT := "ITEM NAME"
const EDITOR_RARITY_TEXT := "RARITY"

var _editor_preview_created := false
var _editor_preview_update_queued := false


# ============================================================
# RUNTIME
# ============================================================

var board: DrRogueoBoard
var menu: StoreMenuController
var store_items: Array[Item] = []

var selected_slot := -1
var last_selected_slot := -1

var highlighted_name_label: Label
var highlighted_rarity_label: Label


# ============================================================
# EDITOR
# ============================================================

func _enter_tree() -> void:

	if Engine.is_editor_hint():
		call_deferred("_ensure_editor_preview")


func _exit_tree() -> void:

	_editor_preview_created = false


func _process(_delta: float) -> void:

	if not Engine.is_editor_hint():
		return

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


	# --------------------------------------------------------
	# FIXED ITEM LABEL
	# --------------------------------------------------------

	var name_label := Label.new()

	name_label.name = EDITOR_PREFIX + "Label"
	name_label.text = EDITOR_LABEL_TEXT

	add_child(name_label)


	# --------------------------------------------------------
	# FIXED RARITY
	# --------------------------------------------------------

	var rarity_label := Label.new()

	rarity_label.name = EDITOR_PREFIX + "Rarity"
	rarity_label.text = EDITOR_RARITY_TEXT

	add_child(rarity_label)


	# --------------------------------------------------------
	# SLOT PREVIEWS
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

	_update_editor_preview()


func _create_editor_slot_preview(
	slot: Node2D,
	slot_index: int
) -> void:

	# --------------------------------------------------------
	# COIN
	# --------------------------------------------------------

	if coin_texture:

		var coin := _create_coin_animation()

		coin.name = (
			EDITOR_PREFIX
			+ "Coin"
			+ str(slot_index)
		)

		coin.position = _pixel_vector(
			coin_position
		)

		slot.add_child(coin)


	# --------------------------------------------------------
	# PRICE
	# --------------------------------------------------------

	var price_label := Label.new()

	price_label.name = (
		EDITOR_PREFIX
		+ "Price"
		+ str(slot_index)
	)

	price_label.text = EDITOR_PRICE_TEXT

	slot.add_child(price_label)


func _update_editor_preview() -> void:

	if not Engine.is_editor_hint():
		return

	if not is_inside_tree():
		return

	if not _editor_preview_created:

		_ensure_editor_preview()

		return


	# --------------------------------------------------------
	# FIXED ITEM LABEL
	# --------------------------------------------------------

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


	# --------------------------------------------------------
	# FIXED RARITY
	# --------------------------------------------------------

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
	# SLOT PREVIEWS
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


# ============================================================
# SHARED LABEL SETTINGS
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
# SETUP
# ============================================================

func setup(game_board: DrRogueoBoard) -> void:

	if Engine.is_editor_hint():
		return

	board = game_board

	_update_coin_display()
	_update_owned_visuals()


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


	randomize()


	_create_highlighted_info_labels()

	_roll_stock()

	_update_coin_display()
	_update_owned_visuals()


	if menu:

		_on_menu_selection_changed(
			menu.current
		)


	# --------------------------------------------------------
	# STORE BACKGROUND
	# --------------------------------------------------------

	call_deferred(
		"_apply_store_background"
	)


# ============================================================
# STORE BACKGROUND
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


	# --------------------------------------------------------
	# Tell the Background which preset pool it belongs to.
	# --------------------------------------------------------

	background.runtime_preset_category = (
		BackgroundPreset.Category.STORE
	)


	# --------------------------------------------------------
	# Select ONLY from the STORE preset pool.
	# --------------------------------------------------------

	background.apply_random_preset(
		BackgroundPreset.Category.STORE
	)


# ============================================================
# STOCK
# ============================================================

func _roll_stock() -> void:

	if Engine.is_editor_hint():
		return

	store_items.clear()

	var catalog := StoreCatalog.create_catalog()

	if catalog.is_empty():
		return


	for _i in item_slot_paths.size():

		var item := _random_item(catalog)

		if item:

			# Price and rarity come directly from the Item.
			# Store slots do NOT modify either value.

			store_items.append(item)


	_update_slot_visuals()


func _random_item(catalog: Array[Item]) -> Item:

	var valid_items: Array[Item] = []

	for item in catalog:

		if item:

			valid_items.append(item)


	if valid_items.is_empty():
		return null


	var index := randi_range(
		0,
		valid_items.size() - 1
	)


	return _fresh_item(
		valid_items[index].id
	)


func _fresh_item(id: String) -> Item:

	for item in StoreCatalog.create_catalog():

		if item.id == id:

			return item


	return null


# ============================================================
# STORE SLOT VISUALS
# ============================================================

func _update_slot_visuals() -> void:

	if Engine.is_editor_hint():
		return


	for i in item_slot_paths.size():

		var slot := get_node_or_null(
			item_slot_paths[i]
		) as Node2D

		if slot == null:
			continue


		for child in slot.get_children():

			if child.name.begins_with(
				"StoreVisual"
			):

				child.queue_free()


		if i >= store_items.size():
			continue


		if store_items[i] == null:
			continue


		_add_item_visuals(
			slot,
			store_items[i],
			"StoreVisual"
		)


	_update_highlighted_info()


func _add_item_visuals(
	slot: Node2D,
	item: Item,
	prefix: String
) -> void:

	# --------------------------------------------------------
	# ITEM ICON
	# --------------------------------------------------------

	if item.icon:

		var icon := Sprite2D.new()

		icon.name = prefix + "Icon"
		icon.texture = item.icon
		icon.centered = false

		icon.position = _pixel_vector(
			item_icon_position
		)

		slot.add_child(icon)


	# --------------------------------------------------------
	# COIN
	# --------------------------------------------------------

	if coin_texture:

		var coin := _create_coin_animation()

		coin.name = prefix + "Coin"

		coin.position = _pixel_vector(
			coin_position
		)

		slot.add_child(coin)


	# --------------------------------------------------------
	# PRICE
	# --------------------------------------------------------

	var price_label := Label.new()

	price_label.name = prefix + "Price"

	# Always two digits.
	#
	# Examples:
	#   5  -> 05
	#   8  -> 08
	#   15 -> 15
	#   99 -> 99

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


# ============================================================
# RUNTIME FIXED INFO
# ============================================================

func _create_highlighted_info_labels() -> void:

	# --------------------------------------------------------
	# ITEM LABEL
	# --------------------------------------------------------

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

	add_child(highlighted_name_label)


	# --------------------------------------------------------
	# RARITY
	# --------------------------------------------------------

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

	add_child(highlighted_rarity_label)


# ============================================================
# MENU HIGHLIGHT CHANGE
# ============================================================

func _on_menu_selection_changed(
	selection: MenuSelectable
) -> void:

	# --------------------------------------------------------
	# If we're highlighting a store item, update the
	# information panel to that item.
	#
	# If we move away from a store item, DO NOT hide it.
	#
	# The information therefore remains showing the current
	# OR last highlighted store item.
	# --------------------------------------------------------

	if selection == null:
		return


	var index := _get_store_slot_index(
		selection
	)


	if index >= 0:

		_show_highlighted_info(index)

		return


	# Non-store selection:
	# deliberately leave the current information visible.


func _get_store_slot_index(
	selection: MenuSelectable
) -> int:

	if menu == null:
		return -1

	return menu.store_item_slots.find(
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


	var display_name := item.display_name


	if index < slot_labels.size():

		if not slot_labels[index].is_empty():

			display_name = slot_labels[index]


	highlighted_name_label.text = display_name

	highlighted_rarity_label.text = (
		item.get_rarity_name()
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
# COIN ANIMATION
# ============================================================

func _build_coin_frames() -> SpriteFrames:

	var frames := SpriteFrames.new()

	if frames.has_animation("default"):

		frames.remove_animation(
			"default"
		)


	frames.add_animation("default")

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

	coin.sprite_frames = _build_coin_frames()
	coin.animation = "default"

	coin.play()

	return coin


# ============================================================
# PIXEL-PERFECT FONT
# ============================================================

func _pixel_vector(value: Vector2) -> Vector2:

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
# OWNED ITEMS
# ============================================================

func _update_owned_visuals() -> void:

	if Engine.is_editor_hint():
		return


	for i in owned_item_paths.size():

		var slot := get_node_or_null(
			owned_item_paths[i]
		) as Node2D

		if slot == null:
			continue


		for child in slot.get_children():

			if child.name.begins_with(
				"OwnedVisual"
			):

				child.queue_free()


		if i >= Inventory.items.size():
			continue


		if Inventory.items[i] == null:
			continue


		var item := Inventory.items[i]


		if item.icon:

			var icon := Sprite2D.new()

			icon.name = "OwnedVisualIcon"
			icon.texture = item.icon
			icon.centered = false
			icon.position = Vector2.ZERO

			slot.add_child(icon)


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

	if board == null:
		return null


	# Price comes directly from the Item.
	var price := item.cost


	if board.coins < price:
		return null


	if Inventory.items.find(null) == -1:
		return null


	board.coins -= price

	_update_coin_display()

	return item


func finish_purchase(
	owned_slot: int
) -> void:

	if selected_slot < 0:
		return

	if selected_slot >= store_items.size():
		return


	store_items[selected_slot] = null

	_update_slot_visuals()
	_update_owned_visuals()

	# If the purchased item was the currently displayed
	# information, leave the information visible as requested.
	#
	# It represents the current/last highlighted item.


# ============================================================
# COINS
# ============================================================

func _update_coin_display() -> void:

	if Engine.is_editor_hint():
		return


	var label := get_node_or_null(
		coin_label_path
	) as Label


	if label:

		label.text = str(
			board.coins if board else 0
		)


# ============================================================
# CLOSE
# ============================================================

func _on_continue_pressed() -> void:

	closed.emit()
