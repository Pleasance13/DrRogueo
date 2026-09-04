@tool
extends Node2D


# ============================================================
# BLINK SETTINGS
# ============================================================

@export var blink_min_interval := 2.0
@export var blink_max_interval := 5.0
@export var blink_duration := 0.2


# ============================================================
# NODES
# ============================================================

@onready var blink: Sprite2D = $Blink


# ============================================================
# BLINK STATE
# ============================================================

var blink_timer := 0.0
var blink_duration_timer := 0.0
var is_blinking := false


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	if not blink:
		return

	blink.visible = false
	blink_timer = randf_range(blink_min_interval, blink_max_interval)


# ============================================================
# PROCESS
# ============================================================

func _process(delta: float) -> void:
	if not blink:
		return

	if is_blinking:
		blink_duration_timer -= delta

		if blink_duration_timer <= 0.0:
			is_blinking = false
			blink.visible = false

	else:
		blink_timer -= delta

		if blink_timer <= 0.0:
			start_blink()


# ============================================================
# START BLINK
# ============================================================

func start_blink() -> void:
	is_blinking = true
	blink_duration_timer = blink_duration
	blink.visible = true

	blink_timer = randf_range(blink_min_interval, blink_max_interval)
