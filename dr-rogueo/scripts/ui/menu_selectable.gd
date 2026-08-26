class_name MenuSelectable
extends Node2D

## Attach to (or use as) any selectable menu element. Wire up NodePaths to
## its neighbors in the inspector. Leave a direction's NodePath empty to
## make that direction a dead end from this node (useful for one-way
## connections: set the NodePath on the source only, leave it unset on
## the destination if there's no way back).

enum Dir { UP, DOWN, LEFT, RIGHT }

@export var neighbor_up: NodePath
@export var neighbor_down: NodePath
@export var neighbor_left: NodePath
@export var neighbor_right: NodePath

func get_neighbor(dir: Dir) -> Node:
	var path: NodePath
	match dir:
		Dir.UP:
			path = neighbor_up
		Dir.DOWN:
			path = neighbor_down
		Dir.LEFT:
			path = neighbor_left
		Dir.RIGHT:
			path = neighbor_right
	if path.is_empty():
		return null
	return get_node_or_null(path)
