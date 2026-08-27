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
# Every HEADER and VALUE is its own Label.
#
# This means headers and values can independently have:
#   - Position
#   - Font
#   - Font size
#   - Color
#   - Alignment
#   - Size
#
# The game/store update functions remain unchanged.
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
#
# Position of each header label in GAME mode.
#
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
#
# Position of each value label in GAME mode.
#
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
#
# These are completely independent from the GAME positions.
#
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
#
# These are completely independent from both GAME positions
# and STORE header positions.
#
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

var _style_refresh_queued := false


# ============================================================
# LIFECYCLE
# ============================================================

func _ready() -> void:

	_ensure_labels()
	_refresh_style()

	if Engine.is_editor_hint():

		_set_editor_placeholder_text()


func _process(_delta: float) -> void:

	if not _style_refresh_queued:
		return

	_style_refresh_queued = false

	_refresh_style()


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

			speed_header_label.text = "SPEED"
			speed_value_label.text = "LOW"


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

	_apply_display_mode()


# ============================================================
# HEADER STYLE
# ============================================================

func _apply_header_settings(
	label: Label,
	position_value: Vector2
) -> void:

	if label == null:
		return

	label.position = _pixel_vector(position_value)
	label.size = header_size

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

	speed_header_label.text = "SPEED"
	speed_value_label.text = "%s" % speed_name


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
