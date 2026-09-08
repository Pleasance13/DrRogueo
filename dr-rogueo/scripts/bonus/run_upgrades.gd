extends Node

# ============================================================
# RUN UPGRADES (autoload)
# ============================================================
#
# Permanent-for-this-run effects granted by passed bonus
# challenges. Reset once per NEW RUN (title screen -> level 1),
# never between levels/stages within the same run.
#
# free_epic_item_next_store is the ONE exception -- it's a
# single-use flag consumed by StoreController the next time the
# store opens (see store_controller.gd _on_continue_pressed()),
# regardless of whether the player actually bought it.
# ============================================================

var free_epic_item_next_store := false

var pong_boss_damage_multiplier := 1.0

# PillHalf.PillColor -> float multiplier, default 1.0 if absent.
var virus_coin_multiplier: Dictionary = {}


func reset() -> void:

	free_epic_item_next_store = false
	pong_boss_damage_multiplier = 1.0
	virus_coin_multiplier.clear()


func get_virus_coin_multiplier(color: int) -> float:

	return virus_coin_multiplier.get(color, 1.0)
