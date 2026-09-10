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
	description = "CLEAR ALL %s VIRUSES FIRST IN EACH LEVEL THIS STAGE." % color_name
	reward_description = "2x COIN REWARDS FOR CLEARING %s VIRUSES." % color_name


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


func on_stage_start(board: DrRogueoBoard) -> void:
	status = Status.ACTIVE


# ============================================================
# ON EVENT
# ============================================================
#
# Fails IMMEDIATELY the instant a non-target-color virus clears
# while a target-color virus still remains -- does not wait
# for stage_cleared, since the player may keep playing long
# after the challenge is already unwinnable.
# ============================================================

func on_event(board: DrRogueoBoard, event_name: String, data: Dictionary) -> void:

	# The challenge now spans the whole stage. It only ever
	# PASSES once the entire stage clears without a failure
	# having happened in any of its levels -- stays ACTIVE
	# (shown as PENDING) through every level in between.
	if event_name == "stage_cleared":

		status = Status.PASSED

		return

	if event_name != "virus_cleared":
		return

	var color: int = data.get("color", -1)

	if color == target_color:
		return

	# A different-colored virus just cleared in the CURRENT
	# level. Still a per-level check -- virus_cells reflects
	# only the level in progress -- but a failure here now
	# fails the whole stage's challenge, since status is no
	# longer reset until the next stage begins.
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
