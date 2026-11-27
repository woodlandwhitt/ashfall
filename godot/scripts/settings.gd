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

# build 21: sliders from the main menu's OPTIONS: look sensitivity, and the volume of everything and of the radio
static var nums := {"sens": 1.0, "vol": 1.0, "radio": 1.0}
static var _nums_read := false

static func num(k: String) -> float:
	if not _nums_read:
		_nums_read = true
		var cf := ConfigFile.new()
		if cf.load("user://settings.cfg") == OK:
			for n in nums:
				nums[n] = float(cf.get_value("opt", n, nums[n]))
	return float(nums.get(k, 1.0))

static func set_num(k: String, v: float) -> void:
	num(k)
	nums[k] = v
	var cf := ConfigFile.new()
	cf.load("user://settings.cfg")
	cf.set_value("opt", k, v)
	cf.save("user://settings.cfg")
	apply_audio()

static func apply_audio() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, num("vol"))))
	var r := AudioServer.get_bus_index("Radio")
	if r >= 0:
		AudioServer.set_bus_volume_db(r, linear_to_db(maxf(0.0001, num("radio"))))
