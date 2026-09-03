class_name PauseController
extends Node


@onready var board: DrRogueoBoard = get_parent().get_node("Board")


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
