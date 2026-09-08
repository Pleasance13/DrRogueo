class_name BonusChallenge
extends Resource

# ============================================================
# BONUS CHALLENGE (base class)
# ============================================================
#
# Rolled once per level by BonusManager. Not accepted/declined -
# it's just active until it resolves. Subclasses override
# can_appear(), on_level_start(), and on_event().
#
# ============================================================

enum Status {
	INACTIVE,
	ACTIVE,
	PASSED,
	FAILED
}

@export var id: String = ""
@export var display_name: String = ""          # "BONUS CHALLENGE:" body text
@export_multiline var description: String = ""  # "Don't use any items."
@export_multiline var reward_description: String = "" # "Free RARE item next store visit."

var status: int = Status.INACTIVE


# Whether this challenge is even eligible to be rolled this
# level, given current board/inventory state.
func can_appear(board: DrRogueoBoard) -> bool:
	return true


# Called once when the challenge is chosen for a level. Reset
# any internal tracking here.
func on_level_start(board: DrRogueoBoard) -> void:
	status = Status.ACTIVE


# Generic event hook. event_name is a string like "item_used",
# "virus_cleared", "pong_combo", "level_cleared", etc. data is
# a Dictionary with whatever payload that event carries.
# Subclasses set status = PASSED / FAILED from here.
func on_event(_board: DrRogueoBoard, _event_name: String, _data: Dictionary) -> void:
	pass


# Called by BonusManager once, right when status flips to
# PASSED. Apply the permanent-for-this-run effect here (usually
# via RunUpgrades) rather than in on_event(), so it only ever
# fires exactly once.
func grant_reward(_board: DrRogueoBoard) -> void:
	pass


func get_status_text() -> String:
	match status:
		Status.ACTIVE: return "PENDING"
		Status.PASSED: return "PASSED"
		Status.FAILED: return "FAILED"
	return "-"
