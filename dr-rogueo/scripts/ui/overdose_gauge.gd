@tool
class_name OverdoseGauge
extends Node2D


# ============================================================
# OVERDOSE GAUGE
# ============================================================
#
# Reflects how many leftover (unmatched) pill halves are
# currently sitting on the board. The more leftovers, the
# higher the gauge climbs -- and the worse the end-of-stage
# coin multiplier gets.
#
#   GREEN   (0 leftover halves)   -> 1.5x coins
#   YELLOW  (1 - 10)              -> 1.0x coins
#   ORANGE  (11 - 30)             -> 0.5x coins
#   RED     (31+)                 -> 0.0x coins, warning flashes
#
# The gauge sprite (OD-gauge.png) is a single pre-baked
# gradient texture, colored bottom-to-top:
#
#   rows 48-72 (25px) -> green
#   rows 32-47 (16px) -> yellow
#   rows 16-31 (16px) -> orange
#   rows  0-15 (16px) -> red / bulb
#
# A vertical_fill.gdshader on the gauge sprite reveals it from
# the bottom upward, so the fill fraction is computed to line
# up with those baked-in band boundaries.
#
# ============================================================

signal zone_changed(zone: int)

enum Zone {
	GREEN,
	YELLOW,
	ORANGE,
	RED
}


# ============================================================
# BAND BOUNDARIES (fraction of gauge height, from the bottom)
# ============================================================

const GREEN_TOP := 25.0 / 73.0
const YELLOW_TOP := 41.0 / 73.0
const ORANGE_TOP := 57.0 / 73.0
const RED_TOP := 1.0


# ============================================================
# LEFTOVER-HALVES THRESHOLDS
# ============================================================

const YELLOW_MAX := 10
const ORANGE_MAX := 30

# How many MORE leftover halves past the red threshold it takes
# to visually saturate the gauge at fully red (i.e. leftover
# halves of ORANGE_MAX + 1 + RED_SATURATION_SPAN or more shows
# a completely full gauge).
const RED_SATURATION_SPAN := 0


# ============================================================
# NODES
# ============================================================

@export_group("Nodes")

@export var gauge_path: NodePath = NodePath("OD-Gauge")

@export var warning_path: NodePath = NodePath("Warning")


# ============================================================
# WARNING FLASH
# ============================================================

@export_group("Warning Flash")

@export_range(0.05, 2.0, 0.01)
var warning_flash_interval := 0.5


# ============================================================
# RUNTIME
# ============================================================

var _gauge_sprite: Sprite2D
var _warning_sprite: Sprite2D

var _warning_timer := 0.0

var current_zone: int = Zone.GREEN
var current_leftover: int = 0


# ============================================================
# LIFECYCLE
# ============================================================

func _ready() -> void:

	_gauge_sprite = get_node_or_null(gauge_path) as Sprite2D
	_warning_sprite = get_node_or_null(warning_path) as Sprite2D

	if _warning_sprite != null:
		_warning_sprite.visible = false

	update_leftover(0)


func _process(delta: float) -> void:

	if Engine.is_editor_hint():
		return

	if _warning_sprite == null:
		return

	if current_zone != Zone.RED:
		return

	# ------------------------------------------------------
	# FLASH WHILE IN THE RED ZONE
	# ------------------------------------------------------

	_warning_timer += delta

	if _warning_timer >= warning_flash_interval:

		_warning_timer -= warning_flash_interval

		_warning_sprite.visible = not _warning_sprite.visible


# ============================================================
# UPDATE FROM LEFTOVER PILL HALVES
# ============================================================

func update_leftover(leftover_halves: int) -> void:

	current_leftover = leftover_halves

	var zone := compute_zone(leftover_halves)

	_apply_fill(compute_fill(leftover_halves))

	if zone == current_zone:
		return

	current_zone = zone

	zone_changed.emit(zone)

	if zone != Zone.RED and _warning_sprite != null:

		_warning_sprite.visible = false

		_warning_timer = 0.0


func _apply_fill(fill: float) -> void:

	if _gauge_sprite == null:
		return

	var material := _gauge_sprite.material

	if not (material is ShaderMaterial):
		return

	(material as ShaderMaterial).set_shader_parameter(
		"fill",
		fill
	)


# ============================================================
# ZONE / FILL / MULTIPLIER
# (STATIC -- SAFE TO USE FOR SCORING WITHOUT TOUCHING THE LIVE NODE)
# ============================================================

static func compute_zone(leftover_halves: int) -> int:

	if leftover_halves <= 0:
		return Zone.GREEN

	if leftover_halves <= YELLOW_MAX:
		return Zone.YELLOW

	if leftover_halves <= ORANGE_MAX:
		return Zone.ORANGE

	return Zone.RED


static func compute_fill(leftover_halves: int) -> float:

	if leftover_halves <= 0:
		return GREEN_TOP

	if leftover_halves <= YELLOW_MAX:

		var t := float(leftover_halves) / float(YELLOW_MAX)

		return lerp(GREEN_TOP, YELLOW_TOP, t)


	if leftover_halves <= ORANGE_MAX:

		var t := float(leftover_halves - YELLOW_MAX) / float(ORANGE_MAX - YELLOW_MAX)

		return lerp(YELLOW_TOP, ORANGE_TOP, t)


	var t := clampf(
		float(leftover_halves - ORANGE_MAX) / float(RED_SATURATION_SPAN),
		0.0,
		1.0
	)

	return lerp(ORANGE_TOP, RED_TOP, t)


static func multiplier_for_zone(zone: int) -> float:

	match zone:

		Zone.GREEN:
			return 1.5

		Zone.YELLOW:
			return 1.0

		Zone.ORANGE:
			return 0.5

		Zone.RED:
			return 0.0

	return 1.0


func get_coin_multiplier() -> float:

	return multiplier_for_zone(current_zone)
