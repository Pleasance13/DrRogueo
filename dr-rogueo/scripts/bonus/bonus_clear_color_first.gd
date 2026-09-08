class_name BonusClearColorFirst
extends BonusChallenge

var target_color: PillHalf.PillColor


func _init(color: PillHalf.PillColor = PillHalf.PillColor.RED) -> void:

	target_color = color

	var color_name := "RED"

	match color:
		PillHalf.PillColor.YELLOW: color_name = "YELLOW"
		PillHalf.PillColor.BLUE: color_name = "BLUE"

	id = "clear_first_%s" % color_name.to_lower()
	display_name = "BONUS CHALLENGE"
	description = "Clear all %s viruses first." % color_name
	reward_description = "2x coin rewards for clearing %s viruses." % color_name


# ============================================================
# CAN APPEAR
# ============================================================
#
# Requires at least one virus of the target color AND at least
# one virus of a DIFFERENT color -- otherwise "first" is
# meaningless (nothing else to beat) and the challenge would
# auto-pass with zero effort.
# ============================================================

func can_appear(board: DrRogueoBoard) -> bool:

	var has_target := false
	var has_other := false

	for virus in board.virus_cells.values():

		if not is_instance_valid(virus):
			continue

		if virus.virus_color == target_color:
			has_target = true
		else:
			has_other = true

		if has_target and has_other:
			return true

	return false


func on_level_start(board: DrRogueoBoard) -> void:
	status = Status.ACTIVE


# ============================================================
# ON EVENT
# ============================================================
#
# Fails IMMEDIATELY the instant a non-target-color virus clears
# while a target-color virus still remains -- does not wait
# for level_cleared, since the player may keep playing the
# level long after the challenge is already unwinnable.
# ============================================================

func on_event(board: DrRogueoBoard, event_name: String, data: Dictionary) -> void:

	if event_name != "virus_cleared":
		return

	var color: int = data.get("color", -1)

	if color == target_color:

		if _target_color_all_cleared(board):

			status = Status.PASSED

		return

	# A different-colored virus just cleared. Only a failure if
	# the target color hasn't already been fully cleared (if it
	# has, this challenge already passed above and won't be
	# ACTIVE anymore, so this branch won't even run).
	if _target_color_remaining(board):

		status = Status.FAILED


func _target_color_remaining(board: DrRogueoBoard) -> bool:

	for virus in board.virus_cells.values():

		if is_instance_valid(virus) and virus.virus_color == target_color:
			return true

	return false


func _target_color_all_cleared(board: DrRogueoBoard) -> bool:

	return not _target_color_remaining(board)


func grant_reward(_board: DrRogueoBoard) -> void:
	RunUpgrades.virus_coin_multiplier[target_color] = 2.0
