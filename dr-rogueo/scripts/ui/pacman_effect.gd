@tool
extends Sprite2D

# ============================================================
# PACMAN EFFECT OVERLAY
# ============================================================
#
# Purely visual: shows the two-frame tunnel-wrap overlay
# whenever the Pacman trait is currently owned, hidden
# otherwise.
#
# Sits as a static child of the Board scene so it renders
# under any dynamically-added pills/viruses/items -- those are
# always add_child()'d onto Board at runtime, which appends
# them after this node in draw order.
#
# ============================================================

func _ready() -> void:

	hframes = 2
	vframes = 1

	visible = false

	if Engine.is_editor_hint():
		return

	if not AnimClock.frame_changed.is_connected(_on_anim_frame_changed):

		AnimClock.frame_changed.connect(_on_anim_frame_changed)

	frame = AnimClock.frame

	if not TraitInventory.traits_changed.is_connected(_on_traits_changed):

		TraitInventory.traits_changed.connect(_on_traits_changed)

	_on_traits_changed()


func _on_anim_frame_changed(new_frame: int) -> void:

	frame = new_frame


func _on_traits_changed() -> void:

	visible = TraitInventory.has_trait("pacman")
