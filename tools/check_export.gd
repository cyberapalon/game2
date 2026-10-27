extends SceneTree
## Run from an empty project directory to inspect the mounted release PCK.


func _initialize() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() != 1 or not ProjectSettings.load_resource_pack(arguments[0]):
		push_error("Expected one readable release PCK")
		quit(1)
		return
	var paths: PackedStringArray = []
	_collect("res://", paths)
	for path: String in paths:
		if path.ends_with(".svg") or path.ends_with(".svg.remap") or path.ends_with(".svg.import"):
			push_error("Legacy SVG leaked into the playable release: " + path)
			quit(1)
			return
		if path.begins_with("res://addons/") or path.begins_with("res://tests/"):
			push_error("Development dependency leaked into release: " + path)
			quit(1)
			return
	for required: String in [
		"res://world/surface/surface.tscn", "res://world/surface/surface_landscape.tscn",
		"res://world/roots/landing.tscn", "res://world/roots/junction.tscn",
		"res://world/roots/hollow.tscn", "res://world/roots/seal.tscn",
		"res://world/interactions/dialogue.gd",
		"res://game/enemies/spore.tscn", "res://world/roots/afterheart.tscn",
		"res://game/boss/heart.tscn", "res://assets/audio/roots_theme.wav", "res://assets/audio/heart_theme.wav",
	]:
		if not ResourceLoader.exists(required):
			push_error("Route resource missing from release: " + required)
			quit(1)
			return
	print("Release PCK checked: ", paths.size(), " files, no addons/tests")
	quit()


func _collect(directory: String, paths: PackedStringArray) -> void:
	for file: String in DirAccess.get_files_at(directory):
		paths.append(directory.path_join(file))
	for child: String in DirAccess.get_directories_at(directory):
		_collect(directory.path_join(child), paths)
