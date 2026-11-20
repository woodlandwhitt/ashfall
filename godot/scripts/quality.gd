# Graphics presets, saved between runs. Low trades looks for frame rate on older phones; High is for flagships.
class_name Quality
extends RefCounted

const NAMES := ["Low", "Medium", "High"]
const P := [
	# render scale, shadows (0 off, 1 near, 2 far), grass range, small-prop range, chunk radius, glow, msaa, fog
	{"scale": 0.6, "shadow": 0, "grass": 0.0, "small": 45.0, "radius": 1, "glow": false, "msaa": 0, "big": 180.0, "fog": 0.0085},
	{"scale": 0.78, "shadow": 1, "grass": 38.0, "small": 65.0, "radius": 2, "glow": false, "msaa": 0, "big": 260.0, "fog": 0.006},
	{"scale": 1.0, "shadow": 2, "grass": 55.0, "small": 95.0, "radius": 2, "glow": true, "msaa": 1, "big": 340.0, "fog": 0.0045},
]

static func load_level() -> int:
	var cf := ConfigFile.new()
	if cf.load("user://settings.cfg") == OK:
		return clampi(int(cf.get_value("gfx", "level", 1)), 0, 2)
	return 1

static func save_level(l: int) -> void:
	var cf := ConfigFile.new()
	cf.load("user://settings.cfg")
	cf.set_value("gfx", "level", l)
	cf.save("user://settings.cfg")

static func apply(main: Node, l: int) -> void:
	var q: Dictionary = P[l]
	var vp := main.get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if q.scale < 1.0 else Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = q.scale
	vp.msaa_3d = Viewport.MSAA_2X if q.msaa == 1 else Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if q.msaa == 0 and l > 0 else Viewport.SCREEN_SPACE_AA_DISABLED
	var sun: DirectionalLight3D = main.sun
	sun.shadow_enabled = q.shadow > 0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if q.shadow == 1 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 40.0 if q.shadow == 1 else 70.0
	main.env.glow_enabled = q.glow
	main.env.fog_density = q.fog
	main.chunks.configure(q.radius, q.small, q.big)
	for g in main.grass_nodes:
		g.visible = q.grass > 0.0
		g.visibility_range_end = q.grass
	main.cam_far(q.big)
