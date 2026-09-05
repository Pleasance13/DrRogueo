class_name ItemThwomp
extends Item


# ============================================================
# THWOMP (item)
# ============================================================
#
# Never becomes a two-half Pill. Once queued, spawn_pill() hands
# off directly to a ThwompController (see
# scripts/board/thwomp_controller.gd), mirroring how Pong is
# special-cased. The controller owns positioning, falling,
# crushing, boss damage, and vanishing.
#
# ============================================================

const THWOMP_ICON_PATH := "res://art/ui/thwomp-icon.png"


func _init() -> void:

	id = "thwomp"

	display_name = "THWOMP"

	preview = Item._load_preview("res://art/ui/temp-preview.png")

	rarity = Item.Rarity.EPIC

	cost = 45

	sell_price = 22

	description = (
		"A 3-wide Thwomp waits at the top of the board. Move it " +
		"with left/right, then press A to slam it down, crushing " +
		"everything in its columns. Lands a hit on the boss if " +
		"it comes down on top of it."
	)

	replaces_next_pill = true

	if ResourceLoader.exists(THWOMP_ICON_PATH):

		icon = load(THWOMP_ICON_PATH)


func on_queue(board: DrRogueoBoard) -> void:

	pass


func use(board: DrRogueoBoard) -> bool:

	if board == null:
		return false

	if board.thwomp_controller != null:
		return false

	board.start_thwomp_item()

	return true
