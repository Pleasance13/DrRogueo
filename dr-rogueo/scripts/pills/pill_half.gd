@tool
class_name PillHalf
extends Node2D


enum PillColor {
	RED,
	YELLOW,
	BLUE
}

enum PillState {
	TOP,
	BOTTOM,
	LEFT,
	RIGHT,
	SEPARATED,
	VANISHING
}

var partner_half: PillHalf = null

@export_category("Pill Half")

@export var pill_color: PillColor = PillColor.RED:
	set(value):
		pill_color = value
		_update_sprite()

@export var pill_state: PillState = PillState.TOP:
	set(value):
		pill_state = value
		_update_sprite()


@onready var sprite: Sprite2D = $Sprite2D


const SPRITE_SIZE := 8


func _ready() -> void:
	_update_sprite()


func _update_sprite() -> void:
	if not is_inside_tree():
		return

	var sprite_node := get_node_or_null("Sprite2D") as Sprite2D
	if sprite_node == null:
		return

	var column := int(pill_color)
	var row := int(pill_state)

	sprite_node.region_enabled = true
	sprite_node.region_rect = Rect2(
		column * SPRITE_SIZE,
		row * SPRITE_SIZE,
		SPRITE_SIZE,
		SPRITE_SIZE
	)
