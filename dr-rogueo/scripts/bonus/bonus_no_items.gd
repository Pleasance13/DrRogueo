class_name BonusNoItems
extends BonusChallenge


func _init() -> void:
	id = "no_items"
	display_name = "BONUS CHALLENGE"
	description = "Don't use any items."
	reward_description = "Free EPIC item next store visit."


func can_appear(_board: DrRogueoBoard) -> bool:

	for item in Inventory.items:

		if item != null:
			return true

	return false


func on_level_start(board: DrRogueoBoard) -> void:
	status = Status.ACTIVE


func on_event(_board: DrRogueoBoard, event_name: String, _data: Dictionary) -> void:

	if event_name == "item_used":
		status = Status.FAILED
		return

	if event_name == "level_cleared":
		status = Status.PASSED


func grant_reward(_board: DrRogueoBoard) -> void:
	RunUpgrades.free_epic_item_next_store = true
