class_name GameSettings
extends RefCounted

# Persists the title-screen speed choice across the scene
# change into the game. Matches Board.FallSpeed (LOW=0,
# MEDIUM=1, HIGH=2).
static var selected_fall_speed: int = 0
