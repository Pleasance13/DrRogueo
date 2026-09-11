@tool
class_name Boss1Healthbar
extends Node2D

# ============================================================
# Boss 1 Healthbar
#
# Source art (boss_healthbar_solid.png) is a 140x35 sheet of
# four 35x35 single-color QUADRANTS (one quarter-circle each).
# We take one quadrant, mirror it into all four corners to
# build a full 70x70 circle at runtime, then apply the same
# radial "pie" mask shader used by the reusable item Timer
# (shaders/ui/timer.gdshader) to reveal it proportionally to
# current/max health.
#
# EDITOR PREVIEW: this node is @tool, so you can place it
# directly in any scene to see it render live. Use
# preview_health below to scrub the fill amount while editing.
# ============================================================

const TEXTURE_PATH := "res://art/ui/boss_healthbar_solid.png"
const SHADER_PATH := "res://shaders/ui/timer.gdshader"

const QUADRANT_SIZE := 35


@export_category("Gauge")

@export var max_health: int = 24

@export_range(0, 3, 1)
var quadrant_index: int = 0:
	set(value):
		quadrant_index = value
		_rebuild_texture()

@export var gauge_offset := Vector2(14, 5):
	set(value):
		gauge_offset = value
		_update_gauge_sprite()


@export_category("Editor Preview")

@export_range(0, 24, 1)
var preview_health: int = 24:
	set(value):
		preview_health = value

		if Engine.is_editor_hint():
			set_health(preview_health)


var _gauge_sprite: Sprite2D

var _built_texture: ImageTexture
var _built_quadrant_index := -1

var current_health: int = 24

var _initialized := false


# ============================================================
# LIFECYCLE
# ============================================================

func _ready() -> void:
	_create_nodes()
	set_health(preview_health if Engine.is_editor_hint() else current_health)


func _process(_delta: float) -> void:

	if Engine.is_editor_hint() and not _initialized:
		_create_nodes()


# ============================================================
# NODE SETUP
# ============================================================

func _create_nodes() -> void:

	if _gauge_sprite == null or not is_instance_valid(_gauge_sprite):

		_gauge_sprite = get_node_or_null("GaugeSprite") as Sprite2D

		if _gauge_sprite == null:

			_gauge_sprite = Sprite2D.new()
			_gauge_sprite.name = "GaugeSprite"
			_gauge_sprite.centered = false
			_gauge_sprite.region_enabled = false

			add_child(_gauge_sprite)

			if Engine.is_editor_hint() and is_inside_tree():
				_gauge_sprite.owner = get_tree().edited_scene_root

	if not (_gauge_sprite.material is ShaderMaterial):

		var mat := ShaderMaterial.new()

		mat.shader = load(SHADER_PATH)

		_gauge_sprite.material = mat

	_initialized = true

	_rebuild_texture()
	_update_gauge_sprite()


# ============================================================
# BUILD FULL CIRCLE FROM ONE QUADRANT
# ============================================================

func _rebuild_texture() -> void:

	if _gauge_sprite == null or not is_instance_valid(_gauge_sprite):
		return

	if _built_texture != null and _built_quadrant_index == quadrant_index:

		_gauge_sprite.texture = _built_texture

		return

	var texture := _build_full_circle_texture()

	if texture == null:
		return

	_built_texture = texture
	_built_quadrant_index = quadrant_index

	_gauge_sprite.texture = texture


func _build_full_circle_texture() -> ImageTexture:

	var sheet := load(TEXTURE_PATH) as Texture2D

	if sheet == null:
		return null

	var sheet_image := sheet.get_image()

	if sheet_image == null:
		return null

	if sheet_image.is_compressed():
		sheet_image.decompress()

	var format := sheet_image.get_format()

	var quad := Image.create(QUADRANT_SIZE, QUADRANT_SIZE, false, format)

	quad.blit_rect(
		sheet_image,
		Rect2i(quadrant_index * QUADRANT_SIZE, 0, QUADRANT_SIZE, QUADRANT_SIZE),
		Vector2i.ZERO
	)

	var flipped_h := _flipped_image(quad, true, false)
	var flipped_v := _flipped_image(quad, false, true)
	var flipped_hv := _flipped_image(quad, true, true)

	# Full circle diameter is ODD (2*35 - 1 = 69), not 70 --
	# each quadrant's inner edge (the straight side touching the
	# center) is a single shared pixel column/row, not two
	# separate ones. Overlapping placements below intentionally
	# redraw that shared line twice with identical content.
	var full_size := QUADRANT_SIZE * 2 - 1

	var full := Image.create(full_size, full_size, false, format)

	full.fill(Color(0, 0, 0, 0))

	var overlap := QUADRANT_SIZE - 1

	full.blit_rect(quad, Rect2i(0, 0, QUADRANT_SIZE, QUADRANT_SIZE), Vector2i(0, 0))
	full.blit_rect(flipped_h, Rect2i(0, 0, QUADRANT_SIZE, QUADRANT_SIZE), Vector2i(overlap, 0))
	full.blit_rect(flipped_hv, Rect2i(0, 0, QUADRANT_SIZE, QUADRANT_SIZE), Vector2i(overlap, overlap))
	full.blit_rect(flipped_v, Rect2i(0, 0, QUADRANT_SIZE, QUADRANT_SIZE), Vector2i(0, overlap))

	return ImageTexture.create_from_image(full)


func _flipped_image(source: Image, flip_h: bool, flip_v: bool) -> Image:

	var result := Image.create(
		source.get_width(),
		source.get_height(),
		false,
		source.get_format()
	)

	for y in source.get_height():

		for x in source.get_width():

			var src_x := (source.get_width() - 1 - x) if flip_h else x
			var src_y := (source.get_height() - 1 - y) if flip_v else y

			result.set_pixel(x, y, source.get_pixel(src_x, src_y))

	return result


func _update_gauge_sprite() -> void:

	if _gauge_sprite == null or not is_instance_valid(_gauge_sprite):
		return

	_gauge_sprite.position = gauge_offset


# ============================================================
# SET HEALTH
# ============================================================

func set_health(health: int) -> void:

	_create_nodes()

	current_health = clampi(health, 0, max_health)

	var fraction := 1.0

	if max_health > 0:
		fraction = float(current_health) / float(max_health)

	if _gauge_sprite != null:

		# At exactly 0 health, the pie shader's angle-zero seam
		# pixel stays visible (progress <= that angle is never
		# true for the single boundary pixel). Hide the sprite
		# outright instead of fighting the shader's boundary.
		_gauge_sprite.visible = current_health > 0

		if _gauge_sprite.material is ShaderMaterial:

			(_gauge_sprite.material as ShaderMaterial).set_shader_parameter(
				"progress",
				fraction
			)
