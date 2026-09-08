class_name PauseController
extends Node


@onready var board: DrRogueoBoard = get_parent().get_node("Board")

# Optional -- a second Clipboard instance (display_mode = BONUS)
# placed as a sibling of Board in main.tscn, initially hidden.
@onready var bonus_clipboard: Clipboard = get_parent().get_node_or_null("PauseBonusClipboard")


func _ready() -> void:

	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:

	if not Input.is_action_just_pressed("pause"):
		return


	if board == null:
		return


	if board.game_over:
		return


	if board.transitioning_level:
		return


	get_tree().paused = not get_tree().paused


	if board.pause_label != null:
		board.pause_label.visible = get_tree().paused


	if bonus_clipboard != null:

		bonus_clipboard.visible = get_tree().paused

		if get_tree().paused:

			bonus_clipboard.show_bonus_challenge(
				BonusManager.get_display_text(),
				BonusManager.get_reward_text()
			)
