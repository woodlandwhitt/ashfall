# Updates without reinstalling. The first thing to load: before any other script is read, a downloaded patch
# (user://patch.pck, every file changed since the build this APK was made from) is mounted over the game's own files,
# so the rest of the game, scripts and all, loads in its newer form. Updater (on the title screen) fetches patches.
extends Node

var base_build := 0       # the build the installed APK was made from
var build := 0            # the build running now (the patch's, if one is mounted)
var patched := false

func _init() -> void:
	base_build = int(_read_build().get("base", 0))
	var info := _patch_info()
	if FileAccess.file_exists("user://patch.pck") and int(info.get("base", -1)) == base_build and int(info.get("build", 0)) > int(_read_build().get("build", 0)):
		patched = ProjectSettings.load_resource_pack("user://patch.pck", true)
		if not patched:
			# a broken download: throw it away so the next start is clean
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://patch.pck"))
	elif FileAccess.file_exists("user://patch.pck"):
		# made for a different APK (a newer one was installed since): no longer applies
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://patch.pck"))
	build = int(_read_build().get("build", 0))

func _ready() -> void:
	# anything a later build adds as an always-loaded script (project settings can't be patched, so they're listed
	# in data/boot.json instead)
	var f := FileAccess.open("res://data/boot.json", FileAccess.READ)
	if f:
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			for k in d.get("autoloads", {}):
				if get_tree().root.get_node_or_null(String(k)) == null:
					var n: Node = (load(String(d.autoloads[k])) as Script).new()
					n.name = String(k)
					get_tree().root.add_child.call_deferred(n)

static func _read_build() -> Dictionary:
	var f := FileAccess.open("res://data/build.json", FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}

static func _patch_info() -> Dictionary:
	var f := FileAccess.open("user://patch.json", FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}
