@tool
extends Node2D


# ============================================================
# ITEMS UI
# ============================================================


const SLOT_COUNT := 3


# ============================================================
# SPRITE SHEET LAYOUTS
# ============================================================

const SLOT_COL_X := [0, 28, 56]
const SLOT_COL_W := 28

const SLOT_ROW_Y := [0, 28]
const SLOT_ROW_H := [28, 28]


# ============================================================
# ITEM PREVIEW SPRITESHEET
# ============================================================

const PREVIEW_COL_X := [0, 79, 158, 237]
const PREVIEW_COL_W := 79
const PREVIEW_H := 79


# ============================================================
# USE BUTTON
# ============================================================

const BUTTON_UNPRESSED_RECT := Rect2(0, 0, 12, 11)
const BUTTON_PRESSED_RECT := Rect2(0, 12, 12, 11)


# ============================================================
# STATE
# ============================================================

var board: DrRogueoBoard

# -1 = nothing selected
#  0 = X
#  1 = Y
#  2 = B
var selected_slot := -1

var slot_sprites: Array[Sprite2D] = []


@onready var preview_sprite: Sprite2D = $"Item-Preview"
@onready var use_button_sprite: Sprite2D = $"Item-Preview/Item-Use-Button"


# ============================================================
# LIFECYCLE
# ============================================================

func _ready() -> void:

	_setup_slot_sprites()

	_setup_preview()
	_setup_use_button()

	# Timer starts hidden.
	set_timer_visible(false)

	if not Engine.is_editor_hint():

		Inventory.inventory_changed.connect(
			_on_inventory_changed
		)

		Inventory.pending_item_changed.connect(
			_on_inventory_changed
		)

		_refresh()


func set_board(p_board: DrRogueoBoard) -> void:

	board = p_board


# ============================================================
# TIMER
# ============================================================

func set_timer_visible(visible: bool) -> void:

	# Look the node up fresh rather than holding a cached
	# reference that could potentially become invalid.
	var timer_node := get_node_or_null("Timer")

	if timer_node == null:
		return

	if not is_instance_valid(timer_node):
		return

	timer_node.visible = visible


func set_timer_progress(progress: float) -> void:

	var timer_node := get_node_or_null("Timer")

	if timer_node == null:
		return

	if not is_instance_valid(timer_node):
		return

	var timer_sprite := timer_node as Sprite2D

	if timer_sprite == null:
		return

	var material := timer_sprite.material as ShaderMaterial

	if material == null:
		return

	material.set_shader_parameter(
		"progress",
		clamp(progress, 0.0, 1.0)
	)


# ============================================================
# EDITOR / RUNTIME SLOT SETUP
# ============================================================

func _setup_slot_sprites() -> void:

	slot_sprites.clear()


	var x_slot := get_node_or_null(
		"Item-Slots/Item-Slot-X"
	) as Sprite2D

	var y_slot := get_node_or_null(
		"Item-Slots/Item-Slot-Y"
	) as Sprite2D

	var b_slot := get_node_or_null(
		"Item-Slots/Item-Slot-B"
	) as Sprite2D


	if x_slot != null:
		slot_sprites.append(x_slot)

	if y_slot != null:
		slot_sprites.append(y_slot)

	if b_slot != null:
		slot_sprites.append(b_slot)


	# --------------------------------------------------------
	# Item icons
	# --------------------------------------------------------

	for slot in slot_sprites:

		var icon_sprite := (
			slot.get_node_or_null("ItemIcon")
			as Sprite2D
		)

		if icon_sprite == null:

			icon_sprite = Sprite2D.new()
			icon_sprite.name = "ItemIcon"
			icon_sprite.centered = true
			icon_sprite.position = Vector2(0, 0)

			slot.add_child(icon_sprite)

			if Engine.is_editor_hint():
				icon_sprite.owner = get_tree().edited_scene_root


	# --------------------------------------------------------
	# Force initial inactive state.
	# --------------------------------------------------------

	for i in range(slot_sprites.size()):

		_set_slot_frame(
			i,
			false
		)


# ============================================================
# SLOT FRAME
# ============================================================

func _set_slot_frame(
	slot: int,
	active: bool
) -> void:

	if slot < 0 or slot >= slot_sprites.size():
		return

	var row := 1 if active else 0

	slot_sprites[slot].region_enabled = true

	slot_sprites[slot].region_rect = Rect2(
		SLOT_COL_X[slot],
		SLOT_ROW_Y[row],
		SLOT_COL_W,
		SLOT_ROW_H[row]
	)


# ============================================================
# PREVIEW
# ============================================================

func _setup_preview() -> void:

	if preview_sprite == null:
		return

	preview_sprite.region_enabled = true

	preview_sprite.region_rect = Rect2(
		PREVIEW_COL_X[0],
		0,
		PREVIEW_COL_W,
		PREVIEW_H
	)

	preview_sprite.visible = true


# ============================================================
# USE BUTTON
# ============================================================

func _setup_use_button() -> void:

	if use_button_sprite == null:
		return

	use_button_sprite.region_enabled = true

	use_button_sprite.region_rect = (
		BUTTON_UNPRESSED_RECT
	)

	use_button_sprite.visible = true


# ============================================================
# INPUT
# ============================================================

func _input(event: InputEvent) -> void:

	if Engine.is_editor_hint():
		return

	if not (event is InputEventJoypadButton):
		return

	var btn_event := event as InputEventJoypadButton


	# --------------------------------------------------------
	# A
	# --------------------------------------------------------

	if btn_event.button_index == JOY_BUTTON_A:

		if btn_event.pressed:

			_set_use_button_pressed(true)
			_activate_selected()

		else:

			_set_use_button_pressed(false)

		return


	# --------------------------------------------------------
	# INVENTORY SLOTS
	# --------------------------------------------------------

	if not btn_event.pressed:
		return


	match btn_event.button_index:

		JOY_BUTTON_X:
			_toggle_slot(0)

		JOY_BUTTON_Y:
			_toggle_slot(1)

		JOY_BUTTON_B:
			_toggle_slot(2)


# ============================================================
# SLOT SELECTION
# ============================================================

func _toggle_slot(slot: int) -> void:

	if selected_slot == slot:

		selected_slot = -1

	else:

		selected_slot = slot


	_refresh()


# ============================================================
# USE BUTTON VISUAL
# ============================================================

func _set_use_button_pressed(pressed: bool) -> void:

	if use_button_sprite == null:
		return

	use_button_sprite.visible = true

	if pressed:

		use_button_sprite.region_rect = (
			BUTTON_PRESSED_RECT
		)

	else:

		use_button_sprite.region_rect = (
			BUTTON_UNPRESSED_RECT
		)


# ============================================================
# ACTIVATE ITEM
# ============================================================

func _activate_selected() -> void:

	if selected_slot < 0:
		return

	if selected_slot >= Inventory.items.size():
		return

	if Inventory.items[selected_slot] == null:
		return

	if board == null:

		push_warning(
			"Items UI: no board set, can't activate item."
		)

		return


	Inventory.use_item(
		selected_slot,
		board
	)

	selected_slot = -1

	_refresh()


# ============================================================
# INVENTORY SIGNAL
# ============================================================

func _on_inventory_changed() -> void:

	_refresh()


# ============================================================
# REFRESH
# ============================================================

func _refresh() -> void:

	if Engine.is_editor_hint():
		return

	for i in range(SLOT_COUNT):

		if i >= slot_sprites.size():
			continue

		_set_slot_frame(
			i,
			i == selected_slot
		)

		var icon_sprite := (
			slot_sprites[i].get_node_or_null("ItemIcon")
			as Sprite2D
		)

		if icon_sprite == null:
			continue

		var item: Item = (
			Inventory.items[i]
			if i < Inventory.items.size()
			else null
		)

		if item != null:

			icon_sprite.texture = item.icon
			icon_sprite.visible = item.icon != null

		else:

			icon_sprite.texture = null
			icon_sprite.visible = false


	# --------------------------------------------------------
	# PREVIEW
	# --------------------------------------------------------

	preview_sprite.visible = true
	preview_sprite.region_enabled = true

	var preview_frame := 0

	if (
		selected_slot >= 0
		and selected_slot < SLOT_COUNT
	):

		preview_frame = selected_slot + 1

	preview_sprite.region_rect = Rect2(
		PREVIEW_COL_X[preview_frame],
		0,
		PREVIEW_COL_W,
		PREVIEW_H
	)


	# --------------------------------------------------------
	# A BUTTON
	# --------------------------------------------------------

	use_button_sprite.visible = true
