extends Node

# ============================================================
# ANIM CLOCK
# ============================================================
#
# Single shared timer driving every plain two-frame idle
# animation in the game (Virus idle animation, Dissolver Pill
# idle animation, etc). One global clock instead of a
# per-node timer keeps every instance of these animations
# perfectly in sync, and gives us ONE place to retune speed.
#
# ============================================================

signal frame_changed(frame: int)

const INTERVAL := 0.30

var frame := 0

var _timer := 0.0


func _process(delta: float) -> void:

	_timer += delta

	if _timer >= INTERVAL:

		_timer -= INTERVAL

		frame = 1 - frame

		frame_changed.emit(frame)
