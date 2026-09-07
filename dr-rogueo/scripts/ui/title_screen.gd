extends Node2D

# ============================================================
# TITLE SCREEN
# ============================================================

const GAME_SCENE_PATH := "res://scenes/main.tscn"

@export var speed_picker_path: NodePath = NodePath("NewGame/Speed")

var speed_picker: SpeedPicker


func _ready() -> void:

	speed_picker = get_node_or_null(speed_picker_path) as SpeedPicker


func _process(_delta: float) -> void:

	if Input.is_action_just_pressed("ui_accept"):

		if speed_picker != null:

			GameSettings.selected_fall_speed = (
				speed_picker.get_selected_fall_speed()
			)

		start_game()


func start_game() -> void:

	get_tree().change_scene_to_file(GAME_SCENE_PATH)
