@tool
extends Sprite2D

@export var animation_speed := 0.5

var current_frame := 0
var timer := 0.0


func _ready():
	region_enabled = true
	region_rect = Rect2(0, 0, 44, 25)
	set_process(true)


func _process(delta):
	timer += delta

	if timer >= animation_speed:
		timer -= animation_speed
		current_frame = (current_frame + 1) % 2

		region_rect.position.y = current_frame * 25
