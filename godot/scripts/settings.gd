# The player's settings that outlive a save (user://settings.cfg): on-screen DEV and FORGE buttons. Graphics and the
# camera keep their own entries in the same file (quality.gd, third_person.gd).
class_name Settings

static var flags := {"dev": false, "forge": false}

static func load_all() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://settings.cfg") == OK:
		for k in flags:
			flags[k] = bool(cf.get_value("hud", k, flags[k]))

static func flag(k: String) -> bool:
	return bool(flags.get(k, false))

static func set_flag(k: String, v: bool) -> void:
	flags[k] = v
	var cf := ConfigFile.new()
	cf.load("user://settings.cfg")
	cf.set_value("hud", k, v)
	cf.save("user://settings.cfg")
