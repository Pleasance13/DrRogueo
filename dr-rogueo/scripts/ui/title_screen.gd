extends Node2D

# ============================================================
# TITLE SCREEN
# ============================================================
#
# Waits for the player to press A (ui_accept) and then starts
# a new run.
#
# TODO: once the speed/options select screen exists, this
# should send the player there instead of straight into the
# game. For now we skip straight to Stage 1 / Level 1 / Low
# speed, which are the Board's defaults.

const GAME_SCENE_PATH := "res://scenes/main.tscn"


func _process(_delta: float) -> void:

	if Input.is_action_just_pressed("ui_accept"):

		start_game()


func start_game() -> void:

	get_tree().change_scene_to_file(GAME_SCENE_PATH)
