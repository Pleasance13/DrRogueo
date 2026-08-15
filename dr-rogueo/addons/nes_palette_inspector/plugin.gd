@tool
extends EditorPlugin


var inspector_plugin: EditorInspectorPlugin


func _enter_tree() -> void:
	inspector_plugin = preload(
		"res://addons/nes_palette_inspector/nes_palette_inspector.gd"
	).new()

	add_inspector_plugin(inspector_plugin)


func _exit_tree() -> void:
	if inspector_plugin:
		remove_inspector_plugin(inspector_plugin)

		inspector_plugin = null
