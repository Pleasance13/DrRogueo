class_name BonusPongCombo
extends BonusChallenge

const REQUIRED_COMBO := 15


func _init() -> void:
	id = "pong_combo_15"
	display_name = "BONUS CHALLENGE"
	description = "Reach a combo of %d+ with PONG." % REQUIRED_COMBO
	reward_description = "PONG upgrade: 2x damage to boss viruses."


func can_appear(_board: DrRogueoBoard) -> bool:
	return Inventory.items.any(func(item): return item != null and item.id == "pong")


func on_event(_board: DrRogueoBoard, event_name: String, data: Dictionary) -> void:

	if event_name == "pong_combo":

		var combo: int = data.get("combo", 0)

		if combo >= REQUIRED_COMBO:
			status = Status.PASSED

		return

	if event_name == "level_cleared" and status == Status.ACTIVE:
		status = Status.FAILED


func grant_reward(_board: DrRogueoBoard) -> void:
	RunUpgrades.pong_boss_damage_multiplier = 2.0
