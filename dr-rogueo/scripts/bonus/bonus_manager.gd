extends Node

# ============================================================
# BONUS MANAGER (autoload)
# ============================================================
#
# Owns the single active bonus challenge. Board calls
# start_level() at the top of every level (including level 1)
# and notify() at each relevant gameplay event. Challenges are
# never stacked - one per level, replaced fresh each level even
# if the previous one is still "active" (challenges are scoped
# to a single level unless a subclass says otherwise).
# ============================================================

signal challenge_changed(challenge: BonusChallenge)
signal challenge_resolved(challenge: BonusChallenge)

var current_challenge: BonusChallenge = null


func start_level(board: DrRogueoBoard) -> void:

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

	current_challenge.on_level_start(board)

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
