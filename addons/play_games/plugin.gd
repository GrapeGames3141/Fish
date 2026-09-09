@tool
extends EditorPlugin

var export_plugin: PlayGamesRecordsExportPlugin

func _enter_tree() -> void:
	export_plugin = PlayGamesRecordsExportPlugin.new()
	add_export_plugin(export_plugin)

func _exit_tree() -> void:
	if export_plugin != null:
		remove_export_plugin(export_plugin)
		export_plugin = null
