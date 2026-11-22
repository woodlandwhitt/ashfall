# Graphics settings, saved between runs. A preset (Low trades looks for frame rate on older phones; High and Ultra
# are for flagships) sets everything at once; any single setting can then be changed on its own in the Graphics
# menu, which makes the preset "Custom". Each setting's choices are listed in OPTS.
class_name Quality
extends RefCounted

const NAMES := ["Low", "Medium", "High", "Ultra"]
const P := [
	{"scale": 0.6, "shadow": 0, "grass": 0.0, "small": 45.0, "radius": 1, "glow": false, "aa": 0, "big": 180.0, "fog": 1, "fps": 60, "lights": 0, "sharpen": 0},
	{"scale": 0.78, "shadow": 1, "grass": 38.0, "small": 65.0, "radius": 2, "glow": false, "aa": 1, "big": 260.0, "fog": 1, "fps": 60, "lights": 1, "sharpen": 1},
	{"scale": 1.0, "shadow": 2, "grass": 55.0, "small": 95.0, "radius": 2, "glow": true, "aa": 2, "big": 340.0, "fog": 1, "fps": 60, "lights": 1, "sharpen": 1},
	{"scale": 1.0, "shadow": 3, "grass": 75.0, "small": 130.0, "radius": 3, "glow": true, "aa": 3, "big": 450.0, "fog": 1, "fps": 0, "lights": 2, "sharpen": 1},
]
# every adjustable setting: [key, label, values, how each value reads]
const OPTS := [
	["scale", "Render resolution", [0.5, 0.6, 0.7, 0.78, 0.85, 1.0], ["50%", "60%", "70%", "78%", "85%", "100%"]],
	["radius", "View distance", [1, 2, 3], ["Near", "Far", "Furthest"]],
	["big", "Building distance", [180.0, 260.0, 340.0, 450.0], ["180 m", "260 m", "340 m", "450 m"]],
	["small", "Detail distance", [45.0, 65.0, 95.0, 130.0], ["45 m", "65 m", "95 m", "130 m"]],
	["grass", "Grass", [0.0, 38.0, 55.0, 75.0], ["Off", "Near", "Far", "Furthest"]],
	["shadow", "Shadows", [0, 1, 2, 3], ["Off", "Near", "Far", "Far, sharp"]],
	["aa", "Anti-aliasing", [0, 1, 2, 3], ["Off", "FXAA", "MSAA 2x", "MSAA 4x"]],
	["glow", "Glow", [false, true], ["Off", "On"]],
	["fog", "Haze", [0, 1, 2], ["Light", "Normal", "Thick"]],
	["lights", "Lamps and fires", [0, 1, 2], ["Few", "Normal", "All"]],
	["sharpen", "Sharpen", [0, 1], ["Off", "On"]],
	["fps", "Frame rate cap", [30, 45, 60, 0], ["30", "45", "60", "Unlimited"]],
	["fov", "Field of view", [65.0, 70.0, 75.0, 80.0, 85.0, 90.0], ["65°", "70°", "75°", "80°", "85°", "90°"]],
]

static var custom := {}     # per-setting overrides of the preset
static var fov := 75.0
static var haze := 1.0       # the Haze setting, applied over the weather's own fog (atmos.gd)

static func load_level() -> int:
	var cf := ConfigFile.new()
	if cf.load("user://settings.cfg") == OK:
		custom = cf.get_value("gfx", "custom", {})
		fov = float(cf.get_value("gfx", "fov", 75.0))
		return clampi(int(cf.get_value("gfx", "level", 1)), 0, NAMES.size() - 1)
	return 1

static func save_level(l: int) -> void:
	var cf := ConfigFile.new()
	cf.load("user://settings.cfg")
	cf.set_value("gfx", "level", l)
	cf.set_value("gfx", "custom", custom)
	cf.set_value("gfx", "fov", fov)
	cf.save("user://settings.cfg")

# the settings in force: the preset, with any custom changes on top
static func current(l: int) -> Dictionary:
	var q: Dictionary = P[clampi(l, 0, P.size() - 1)].duplicate()
	for k in custom:
		q[k] = custom[k]
	q["fov"] = fov
	return q

static func label(l: int) -> String:
	return NAMES[l] + (" (custom)" if not custom.is_empty() else "")

static func apply(main: Node, l: int) -> void:
	var q := current(l)
	var vp := main.get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR if not q.get("sharpen", 1) else Viewport.SCALING_3D_MODE_FSR
	vp.scaling_3d_scale = float(q.scale)
	var aa := int(q.get("aa", 1))
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][aa]
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if aa == 1 else Viewport.SCREEN_SPACE_AA_DISABLED
	var sun: DirectionalLight3D = main.sun
	var sh := int(q.shadow)
	sun.shadow_enabled = sh > 0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if sh == 1 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = [0.0, 40.0, 70.0, 90.0][sh]
	RenderingServer.directional_shadow_atlas_set_size(4096 if sh == 3 else 2048, true)
	main.env.glow_enabled = bool(q.glow)
	haze = [0.6, 1.0, 1.6][int(q.get("fog", 1))]
	main.env.fog_density = 0.0045 * haze
	main.chunks.configure(int(q.radius), float(q.small), float(q.big), float(q.grass))
	main.cam_far(float(q.big))
	Engine.max_fps = int(q.get("fps", 60))
	main.lamp_detail = int(q.get("lights", 1))
