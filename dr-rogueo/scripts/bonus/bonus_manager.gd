extends Node

# ============================================================
# BONUS MANAGER (autoload)
# ============================================================
#
# Owns the single active bonus challenge. Board calls
# start_stage() once at the top of every STAGE (including the
# very first one) and notify() at each relevant gameplay event.
# Challenges now span the full stage (all levels in it) rather
# than a single level -- they're only replaced when a new stage
# begins, not on every level transition within a stage.
# ============================================================

signal challenge_changed(challenge: BonusChallenge)
signal challenge_resolved(challenge: BonusChallenge)

var current_challenge: BonusChallenge = null


func start_stage(board: DrRogueoBoard) -> void:

	var candidates: Array[BonusChallenge] = []

	for challenge in BonusChallengeCatalog.create_catalog():

		if challenge.can_appear(board):
			candidates.append(challenge)

	if candidates.is_empty():

		current_challenge = null
		challenge_changed.emit(null)
		return

	current_challenge = candidates[
		randi_range(0, candidates.size() - 1)
	]

	current_challenge.on_stage_start(board)

	challenge_changed.emit(current_challenge)


func notify(board: DrRogueoBoard, event_name: String, data: Dictionary = {}) -> void:

	if current_challenge == null:
		return

	if current_challenge.status != BonusChallenge.Status.ACTIVE:
		return

	current_challenge.on_event(board, event_name, data)

	if current_challenge.status == BonusChallenge.Status.PASSED:

		current_challenge.grant_reward(board)
		challenge_resolved.emit(current_challenge)

	elif current_challenge.status == BonusChallenge.Status.FAILED:

		challenge_resolved.emit(current_challenge)


func get_display_text() -> String:

	if current_challenge == null:
		return ""

	return current_challenge.description


func get_reward_text() -> String:

	if current_challenge == null:
		return ""

	return current_challenge.reward_description


func get_status_text() -> String:

	if current_challenge == null:
		return "-"

	return current_challenge.get_status_text()


func get_status() -> int:

	if current_challenge == null:
		return -1

	return current_challenge.status
