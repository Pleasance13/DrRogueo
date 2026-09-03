@tool
class_name Clipboard
extends Node2D


# ============================================================
# CLIPBOARD
# ============================================================
#
# Displays the run's live stats on the clipboard sprite.
#
# Two modes, set per-instance in the Inspector:
#
#   GAME  -- shows:
#           Stage
#           Level
#           Virus
#           Coin
#           Speed
#
#   STORE -- shows:
#           Next Stage
#           Coin
#
# A third overlay -- ITEM DESCRIPTION -- can be shown on top of
# either mode (see show_description() / hide_description()).
#
# Item descriptions have their OWN independent typography:
#   - Header font
#   - Header font size
#   - Header color
#   - Header alignment
#   - Header line spacing
#   - Value font
#   - Value font size
#   - Value color
#   - Value alignment
#   - Value line spacing
#
# GAME descriptions use the full available description area
# with NO clipping or scrolling.
#
# STORE descriptions are clipped to description_value_size and
# scroll vertically when the text is too tall.
#
# Every HEADER and VALUE is its own Label.
#
# ============================================================


enum DisplayMode {
	GAME,
	STORE
}


@export var display_mode: DisplayMode = DisplayMode.GAME:
	set(value):
		display_mode = value
		_queue_style_refresh()


# ============================================================
# HEADER TEXT STYLE
# ============================================================

@export_group("Header Text")

@export var header_font: Font:
	set(value):
		header_font = value
		_queue_style_refresh()

@export_range(1, 32, 1)
var header_font_size := 6:
	set(value):
		header_font_size = value
		_queue_style_refresh()

@export var header_color := Color.BLACK:
	set(value):
		header_color = value
		_queue_style_refresh()

@export var header_alignment := HORIZONTAL_ALIGNMENT_LEFT:
	set(value):
		header_alignment = value
		_queue_style_refresh()

@export var header_size := Vector2(76, 10):
	set(value):
		header_size = value
		_queue_style_refresh()


# ============================================================
# VALUE TEXT STYLE
# ============================================================

@export_group("Value Text")

@export var value_font: Font:
	set(value):
		value_font = value
		_queue_style_refresh()

@export_range(1, 32, 1)
var value_font_size := 6:
	set(value):
		value_font_size = value
		_queue_style_refresh()

@export var value_color := Color.BLACK:
	set(value):
		value_color = value
		_queue_style_refresh()

@export var value_alignment := HORIZONTAL_ALIGNMENT_LEFT:
	set(value):
		value_alignment = value
		_queue_style_refresh()

@export var value_size := Vector2(76, 10):
	set(value):
		value_size = value
		_queue_style_refresh()


# ============================================================
# GAME HEADER POSITIONS
# ============================================================

@export_group("Game Header Positions")

@export var stage_header_position := Vector2(108, 30):
	set(value):
		stage_header_position = value
		_queue_style_refresh()

@export var level_header_position := Vector2(108, 46):
	set(value):
		level_header_position = value
		_queue_style_refresh()

@export var virus_header_position := Vector2(108, 62):
	set(value):
		virus_header_position = value
		_queue_style_refresh()

@export var coin_header_position := Vector2(108, 78):
	set(value):
		coin_header_position = value
		_queue_style_refresh()

@export var speed_header_position := Vector2(108, 94):
	set(value):
		speed_header_position = value
		_queue_style_refresh()


# ============================================================
# GAME VALUE POSITIONS
# ============================================================

@export_group("Game Value Positions")

@export var stage_value_position := Vector2(108, 30):
	set(value):
		stage_value_position = value
		_queue_style_refresh()

@export var level_value_position := Vector2(108, 46):
	set(value):
		level_value_position = value
		_queue_style_refresh()

@export var virus_value_position := Vector2(108, 62):
	set(value):
		virus_value_position = value
		_queue_style_refresh()

@export var coin_value_position := Vector2(108, 78):
	set(value):
		coin_value_position = value
		_queue_style_refresh()

@export var speed_value_position := Vector2(108, 94):
	set(value):
		speed_value_position = value
		_queue_style_refresh()


# ============================================================
# STORE HEADER POSITIONS
# ============================================================

@export_group("Store Header Positions")

@export var next_stage_header_position := Vector2(108, 46):
	set(value):
		next_stage_header_position = value
		_queue_style_refresh()

@export var store_coin_header_position := Vector2(108, 78):
	set(value):
		store_coin_header_position = value
		_queue_style_refresh()


# ============================================================
# STORE VALUE POSITIONS
# ============================================================

@export_group("Store Value Positions")

@export var next_stage_value_position := Vector2(108, 46):
	set(value):
		next_stage_value_position = value
		_queue_style_refresh()

@export var store_coin_value_position := Vector2(108, 78):
	set(value):
		store_coin_value_position = value
		_queue_style_refresh()


# ============================================================
# ITEM DESCRIPTION -- HEADER TEXT STYLE
# ============================================================
#
# Completely independent from the normal Header Text settings.
#
# ============================================================

@export_group("Item Description Header")

@export var description_header_font: Font:
	set(value):
		description_header_font = value
		_queue_style_refresh()

@export_range(1, 32, 1)
var description_header_font_size := 6:
	set(value):
		description_header_font_size = value
		_queue_style_refresh()

@export var description_header_color := Color.BLACK:
	set(value):
		description_header_color = value
		_queue_style_refresh()

@export var description_header_alignment := HORIZONTAL_ALIGNMENT_LEFT:
	set(value):
		description_header_alignment = value
		_queue_style_refresh()

@export_range(0, 32, 1)
var description_header_line_spacing := 0:
	set(value):
		description_header_line_spacing = value
		_queue_style_refresh()

@export var description_header_position := Vector2(108, 30):
	set(value):
		description_header_position = value
		_queue_style_refresh()

@export var description_header_size := Vector2(76, 10):
	set(value):
		description_header_size = value
		_queue_style_refresh()


# ============================================================
# ITEM DESCRIPTION -- VALUE TEXT STYLE
# ============================================================
#
# Completely independent from the normal Value Text settings.
#
# description_value_size is the visible description area in
# STORE mode.
#
# In GAME mode, the label is allowed to grow vertically beyond
# this height so the complete description can be displayed.
#
# ============================================================

@export_group("Item Description Value")

@export var description_value_font: Font:
	set(value):
		description_value_font = value
		_queue_style_refresh()

@export_range(1, 32, 1)
var description_value_font_size := 6:
	set(value):
		description_value_font_size = value
		_queue_style_refresh()

@export var description_value_color := Color.BLACK:
	set(value):
		description_value_color = value
		_queue_style_refresh()

@export var description_value_alignment := HORIZONTAL_ALIGNMENT_LEFT:
	set(value):
		description_value_alignment = value
		_queue_style_refresh()

@export_range(0, 32, 1)
var description_value_line_spacing := 0:
	set(value):
		description_value_line_spacing = value
		_queue_style_refresh()

@export var description_value_position := Vector2(108, 46):
	set(value):
		description_value_position = value
		_queue_style_refresh()

@export var description_value_size := Vector2(76, 40):
	set(value):
		description_value_size = value
		_queue_style_refresh()


# ============================================================
# STORE DESCRIPTION SCROLL SETTINGS
# ============================================================

@export_group("Store Description Scrolling")

@export_range(1.0, 32.0, 1.0)
var description_scroll_step := 8.0

@export_range(0.05, 5.0, 0.05)
var description_scroll_interval := 1.2

@export_range(0.0, 5.0, 0.05)
var description_scroll_end_pause := 1.0


# ============================================================
# RUNTIME LABELS
# ============================================================

var stage_header_label: Label
var stage_value_label: Label

var level_header_label: Label
var level_value_label: Label

var virus_header_label: Label
var virus_value_label: Label

var coin_header_label: Label
var coin_value_label: Label

var speed_header_label: Label
var speed_value_label: Label

var next_stage_header_label: Label
var next_stage_value_label: Label

var store_coin_header_label: Label
var store_coin_value_label: Label

var description_header_label: Label
var description_clip: Control
var description_value_label: Label

var _style_refresh_queued := false


# ============================================================
# DESCRIPTION SCROLL STATE
# ============================================================

var _description_active := false
var _description_scroll_timer := 0.0
var _description_pausing := false


# ============================================================
# LIFECYCLE
# ============================================================

func _ready() -> void:

	_ensure_labels()
	_refresh_style()

	if Engine.is_editor_hint():

		_set_editor_placeholder_text()


func _process(delta: float) -> void:

	if _style_refresh_queued:

		_style_refresh_queued = false

		_refresh_style()


	if not Engine.is_editor_hint():

		# Only STORE descriptions scroll.
		if _description_active and display_mode == DisplayMode.STORE:

			_process_description_scroll(delta)


func _queue_style_refresh() -> void:

	# Property setters can fire before _ready().
	# Defer styling until the next process frame so all exported
	# properties have their actual values.
	_style_refresh_queued = true


# ============================================================
# EDITOR PLACEHOLDERS
# ============================================================

func _set_editor_placeholder_text() -> void:

	match display_mode:

		DisplayMode.STORE:

			next_stage_header_label.text = "NXT STAGE"
			next_stage_value_label.text = "2"

			store_coin_header_label.text = "COIN"
			store_coin_value_label.text = "00"

		_:

			stage_header_label.text = "STAGE"
			stage_value_label.text = "1"

			level_header_label.text = "LEVEL"
			level_value_label.text = "1/5"

			virus_header_label.text = "VIRUS"
			virus_value_label.text = "04"

			coin_header_label.text = "COIN"
			coin_value_label.text = "00"

			speed_header_label.text = "LOW"


# ============================================================
# LABEL CREATION
# ============================================================

func _ensure_labels() -> void:

	if stage_header_label == null:
		stage_header_label = _create_label("StageHeaderLabel")

	if stage_value_label == null:
		stage_value_label = _create_label("StageValueLabel")

	if level_header_label == null:
		level_header_label = _create_label("LevelHeaderLabel")

	if level_value_label == null:
		level_value_label = _create_label("LevelValueLabel")

	if virus_header_label == null:
		virus_header_label = _create_label("VirusHeaderLabel")

	if virus_value_label == null:
		virus_value_label = _create_label("VirusValueLabel")

	if coin_header_label == null:
		coin_header_label = _create_label("CoinHeaderLabel")

	if coin_value_label == null:
		coin_value_label = _create_label("CoinValueLabel")

	if speed_header_label == null:
		speed_header_label = _create_label("SpeedHeaderLabel")

	if speed_value_label == null:
		speed_value_label = _create_label("SpeedValueLabel")

	if next_stage_header_label == null:
		next_stage_header_label = _create_label("NextStageHeaderLabel")

	if next_stage_value_label == null:
		next_stage_value_label = _create_label("NextStageValueLabel")

	if store_coin_header_label == null:
		store_coin_header_label = _create_label("StoreCoinHeaderLabel")

	if store_coin_value_label == null:
		store_coin_value_label = _create_label("StoreCoinValueLabel")

	# --------------------------------------------------------
	# ITEM DESCRIPTION
	# --------------------------------------------------------

	if description_header_label == null:

		description_header_label = _create_label(
			"DescriptionHeaderLabel"
		)

	if description_clip == null:

		description_clip = Control.new()

		description_clip.name = "DescriptionClip"

		description_clip.clip_contents = true

		add_child(description_clip)

	if description_value_label == null:

		description_value_label = Label.new()

		description_value_label.name = "DescriptionValueLabel"

		description_value_label.autowrap_mode = (
			TextServer.AUTOWRAP_WORD
		)

		description_clip.add_child(
			description_value_label
		)


func _create_label(label_name: String) -> Label:

	var label := Label.new()

	label.name = label_name

	add_child(label)

	return label


# ============================================================
# STYLE
# ============================================================

func _refresh_style() -> void:

	_ensure_labels()

	# GAME
	_apply_header_settings(
		stage_header_label,
		stage_header_position
	)

	_apply_value_settings(
		stage_value_label,
		stage_value_position
	)

	_apply_header_settings(
		level_header_label,
		level_header_position
	)

	_apply_value_settings(
		level_value_label,
		level_value_position
	)

	_apply_header_settings(
		virus_header_label,
		virus_header_position
	)

	_apply_value_settings(
		virus_value_label,
		virus_value_position
	)

	_apply_header_settings(
		coin_header_label,
		coin_header_position
	)

	_apply_value_settings(
		coin_value_label,
		coin_value_position
	)

	_apply_header_settings(
		speed_header_label,
		speed_header_position
	)

	_apply_value_settings(
		speed_value_label,
		speed_value_position
	)

	# STORE
	_apply_header_settings(
		next_stage_header_label,
		next_stage_header_position
	)

	_apply_value_settings(
		next_stage_value_label,
		next_stage_value_position
	)

	_apply_header_settings(
		store_coin_header_label,
		store_coin_header_position
	)

	_apply_value_settings(
		store_coin_value_label,
		store_coin_value_position
	)

	# ITEM DESCRIPTION
	_apply_description_header_settings()
	_style_description_value()

	_apply_display_mode()


# ============================================================
# HEADER STYLE
# ============================================================

func _apply_header_settings(
	label: Label,
	position_value: Vector2,
	size_value: Vector2 = header_size
) -> void:

	if label == null:
		return

	label.position = _pixel_vector(position_value)
	label.size = size_value

	label.horizontal_alignment = header_alignment

	label.add_theme_font_size_override(
		"font_size",
		header_font_size
	)

	label.add_theme_color_override(
		"font_color",
		header_color
	)

	_apply_pixel_font(
		label,
		header_font
	)


# ============================================================
# VALUE STYLE
# ============================================================

func _apply_value_settings(
	label: Label,
	position_value: Vector2
) -> void:

	if label == null:
		return

	label.position = _pixel_vector(position_value)
	label.size = value_size

	label.horizontal_alignment = value_alignment

	label.add_theme_font_size_override(
		"font_size",
		value_font_size
	)

	label.add_theme_color_override(
		"font_color",
		value_color
	)

	_apply_pixel_font(
		label,
		value_font
	)


# ============================================================
# ITEM DESCRIPTION HEADER STYLE
# ============================================================

func _apply_description_header_settings() -> void:

	if description_header_label == null:
		return

	description_header_label.position = _pixel_vector(
		description_header_position
	)

	description_header_label.size = description_header_size

	description_header_label.horizontal_alignment = (
		description_header_alignment
	)

	description_header_label.add_theme_font_size_override(
		"font_size",
		description_header_font_size
	)

	description_header_label.add_theme_color_override(
		"font_color",
		description_header_color
	)

	description_header_label.add_theme_constant_override(
		"line_spacing",
		description_header_line_spacing
	)

	_apply_pixel_font(
		description_header_label,
		description_header_font
	)


# ============================================================
# DESCRIPTION VALUE STYLE
# ============================================================
#
# STORE:
#   DescriptionValueLabel lives inside DescriptionClip.
#   The clip provides the fixed visible area.
#
# GAME:
#   DescriptionValueLabel is moved directly under Clipboard.
#   Its height is expanded to fit the complete description.
#
# ============================================================

func _style_description_value() -> void:

	if description_value_label == null:
		return

	# --------------------------------------------------------
	# Common typography
	# --------------------------------------------------------

	description_value_label.horizontal_alignment = (
		description_value_alignment
	)

	description_value_label.add_theme_font_size_override(
		"font_size",
		description_value_font_size
	)

	description_value_label.add_theme_color_override(
		"font_color",
		description_value_color
	)

	description_value_label.add_theme_constant_override(
		"line_spacing",
		description_value_line_spacing
	)

	description_value_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD
	)

	_apply_pixel_font(
		description_value_label,
		description_value_font
	)

	# --------------------------------------------------------
	# GAME MODE
	# --------------------------------------------------------
	#
	# No clipping. The label gets enough height for its full
	# wrapped text.
	#
	# --------------------------------------------------------

	if display_mode == DisplayMode.GAME:

		if description_value_label.get_parent() != self:

			description_clip.remove_child(
				description_value_label
			)

			add_child(description_value_label)

		description_value_label.position = _pixel_vector(
			description_value_position
		)

		description_value_label.custom_minimum_size = Vector2(
			description_value_size.x,
			0
		)

		# Give the label a width for word wrapping. Its height
		# is allowed to expand to the full description.
		description_value_label.size = Vector2(
			description_value_size.x,
			max(
				description_value_size.y,
				description_value_label.get_minimum_size().y
			)
		)

		description_clip.position = _pixel_vector(
			description_value_position
		)

		description_clip.size = description_value_size

		return

	# --------------------------------------------------------
	# STORE MODE
	# --------------------------------------------------------
	#
	# Fixed clipping area and scrolling.
	#
	# --------------------------------------------------------

	if description_value_label.get_parent() != description_clip:

		if description_value_label.get_parent() != null:

			description_value_label.get_parent().remove_child(
				description_value_label
			)

		description_clip.add_child(
			description_value_label
		)

	description_clip.position = _pixel_vector(
		description_value_position
	)

	description_clip.size = description_value_size

	description_value_label.position = Vector2.ZERO

	# Fixed width so autowrap works.
	# Height is allowed to grow so we can measure the complete
	# description for scrolling.
	description_value_label.custom_minimum_size = Vector2(
		description_value_size.x,
		0
	)

	description_value_label.size = Vector2(
		description_value_size.x,
		max(
			description_value_label.size.y,
			description_value_label.get_minimum_size().y
		)
	)


func _pixel_vector(value: Vector2) -> Vector2:

	return Vector2(
		floor(value.x),
		floor(value.y)
	)


# ============================================================
# DISPLAY MODE
# ============================================================
#
# The single source of truth for which labels are visible.
#
# ============================================================

func _apply_display_mode() -> void:

	_ensure_labels()

	# --------------------------------------------------------
	# ITEM DESCRIPTION OVERRIDES EVERYTHING ELSE.
	# --------------------------------------------------------

	if _description_active:

		stage_header_label.visible = false
		stage_value_label.visible = false

		level_header_label.visible = false
		level_value_label.visible = false

		virus_header_label.visible = false
		virus_value_label.visible = false

		coin_header_label.visible = false
		coin_value_label.visible = false

		speed_header_label.visible = false
		speed_value_label.visible = false

		next_stage_header_label.visible = false
		next_stage_value_label.visible = false

		store_coin_header_label.visible = false
		store_coin_value_label.visible = false

		description_header_label.visible = true
		description_value_label.visible = true

		# The clip itself is only needed for STORE mode.
		description_clip.visible = (
			display_mode == DisplayMode.STORE
		)

		return

	description_header_label.visible = false
	description_value_label.visible = false
	description_clip.visible = false


	match display_mode:

		DisplayMode.STORE:

			# Hide all GAME labels.
			stage_header_label.visible = false
			stage_value_label.visible = false

			level_header_label.visible = false
			level_value_label.visible = false

			virus_header_label.visible = false
			virus_value_label.visible = false

			coin_header_label.visible = false
			coin_value_label.visible = false

			speed_header_label.visible = false
			speed_value_label.visible = false

			# Show STORE labels.
			next_stage_header_label.visible = true
			next_stage_value_label.visible = true

			store_coin_header_label.visible = true
			store_coin_value_label.visible = true

		_:

			# Show GAME labels.
			stage_header_label.visible = true
			stage_value_label.visible = true

			level_header_label.visible = true
			level_value_label.visible = true

			virus_header_label.visible = true
			virus_value_label.visible = true

			coin_header_label.visible = true
			coin_value_label.visible = true

			speed_header_label.visible = true
			speed_value_label.visible = true

			# Hide STORE labels.
			next_stage_header_label.visible = false
			next_stage_value_label.visible = false

			store_coin_header_label.visible = false
			store_coin_value_label.visible = false


# ============================================================
# PIXEL-PERFECT FONT
# ============================================================

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
# STAT UPDATES -- GAME MODE
# ============================================================

func update_stats(
	stage: int,
	level_in_stage: int,
	levels_per_stage: int,
	virus_count: int,
	coin_count: int,
	speed_name: String
) -> void:

	if Engine.is_editor_hint():
		return

	_ensure_labels()

	stage_header_label.text = "STAGE"
	stage_value_label.text = "%d" % stage

	level_header_label.text = "LEVEL"
	level_value_label.text = "%d/%d" % [
		level_in_stage,
		levels_per_stage
	]

	virus_header_label.text = "VIRUS"
	virus_value_label.text = "%02d" % virus_count

	coin_header_label.text = "COIN"
	coin_value_label.text = "%02d" % coin_count

	speed_header_label.text = "%s" % speed_name


# ============================================================
# STAT UPDATES -- STORE MODE
# ============================================================

func update_store_stats(
	next_stage: int,
	coin_count: int
) -> void:

	if Engine.is_editor_hint():
		return

	_ensure_labels()

	next_stage_header_label.text = "NXT STAGE"
	next_stage_value_label.text = "%d" % next_stage

	store_coin_header_label.text = "COIN"
	store_coin_value_label.text = "%02d" % coin_count


# ============================================================
# ITEM DESCRIPTION -- SHOW / HIDE
# ============================================================
#
# item_name is shown as the header; description as the value.
#
# STORE mode:
#   Description is clipped and scrolls if necessary.
#
# GAME mode:
#   Description is displayed in full with no scrolling.
#
# ============================================================

func show_description(
	item_name: String,
	description: String
) -> void:

	if Engine.is_editor_hint():
		return

	_ensure_labels()

	description_header_label.text = item_name
	description_value_label.text = description

	description_value_label.position = Vector2.ZERO

	_description_active = true

	_description_scroll_timer = 0.0
	_description_pausing = false

	# Recalculate the description label after changing its text.
	_style_description_value()

	_apply_display_mode()


func hide_description() -> void:

	if Engine.is_editor_hint():
		return

	_description_active = false

	_description_scroll_timer = 0.0
	_description_pausing = false

	_apply_display_mode()


# ============================================================
# ITEM DESCRIPTION -- STORE SCROLL
# ============================================================

func _process_description_scroll(delta: float) -> void:

	if description_value_label == null:
		return

	# Scrolling is only used in STORE mode.
	if display_mode != DisplayMode.STORE:
		return

	var natural_max_scroll: float = max(
		0.0,
		description_value_label.get_minimum_size().y
		- description_value_size.y
	)

	if natural_max_scroll <= 0.0:
		return

	_description_scroll_timer += delta

	if _description_pausing:

		if _description_scroll_timer >= description_scroll_end_pause:

			description_value_label.position.y = 0.0

			_description_scroll_timer = 0.0

			_description_pausing = false

		return

	if _description_scroll_timer < description_scroll_interval:
		return

	_description_scroll_timer = 0.0

	# --------------------------------------------------------
	# Always scroll by the exact configured step.
	#
	# The final stopping point is rounded UP to the next
	# complete step so the last movement is the same distance
	# as every other movement.
	#
	# Example:
	#
	#   Natural distance = 29 px
	#   Step             = 8 px
	#   Final distance   = 32 px
	#
	# This gives:
	#   8 -> 8 -> 8 -> 8
	# --------------------------------------------------------

	var total_scroll_distance: float = (
		ceil(natural_max_scroll / description_scroll_step)
		* description_scroll_step
	)

	var next_y: float = (
		description_value_label.position.y
		- description_scroll_step
	)

	if -next_y >= total_scroll_distance - 0.001:

		description_value_label.position.y = -total_scroll_distance

		_description_pausing = true

	else:

		description_value_label.position.y = next_y
