# The sky over the valley (main.js updSky/weatherTick, gfx.js atmos): a day lasts 1000 seconds; the sun rises,
# crosses and sets, the sky and fog follow it, and at night a lantern-light follows you. Weather drifts between clear,
# cloudy, dust storm, rain and thunderstorm, plus the radstorm a road event can call down. Radiation from glowing
# pools, a hot reactor and radstorms clicks on the counter. The chems' look (colour, saturation, exposure) lives here too.
class_name Atmos
extends Node

const DAY_LEN := 1000.0
const WX := {
	"clear": {"cover": 0.4, "haze": 0.0, "wind": 0.7, "rain": 0.0, "bolt": false, "green": 0.0},
	"cloudy": {"cover": 0.68, "haze": 0.12, "wind": 1.1, "rain": 0.0, "bolt": false, "green": 0.0},
	"storm": {"cover": 0.9, "haze": 1.0, "wind": 2.6, "rain": 0.0, "bolt": false, "green": 0.0},
	"rain": {"cover": 0.85, "haze": 0.12, "wind": 1.4, "rain": 1.0, "bolt": false, "green": 0.0},
	"thunder": {"cover": 0.95, "haze": 0.2, "wind": 2.0, "rain": 1.0, "bolt": true, "green": 0.0},
	"radstorm": {"cover": 0.86, "haze": 0.62, "wind": 1.9, "rain": 0.0, "bolt": true, "green": 1.0},
}
var main
var env: Environment
var sun: DirectionalLight3D
var sm: ProceduralSkyMaterial
var lamp: OmniLight3D
var rain_p: CPUParticles3D
var dust_p: CPUParticles3D
var tint: ColorRect
var flash: ColorRect
var kind := "clear"
var next := 200.0
var locked := false
var cur := {"cover": 0.4, "haze": 0.0, "wind": 0.7, "rain": 0.0, "green": 0.0}
var bolt_t := 8.0
var thunder: Array = []
var loops := {}
var geiger_t := 0.0
var heart_t := 0.0
var roof_t := 0.0
var roofed := false
var enclosed := false
var indoor_k := 0.0
var day := 1.0

func setup(m) -> void:
	main = m
	env = m.env
	sun = m.sun
	if env.sky:
		sm = env.sky.sky_material as ProceduralSkyMaterial
	lamp = OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.85, 0.62)
	lamp.omni_range = 18.0
	lamp.light_energy = 0.0
	lamp.shadow_enabled = false
	m.add_child(lamp)
	# rain streaks and blowing dust follow the camera
	rain_p = _particles(700, Vector3(22, 10, 22), Vector3(1.5, -26, 0.5), Color(0.82, 0.86, 0.92, 0.4), Vector2(0.018, 0.9), 0.8)
	dust_p = _particles(90, Vector3(36, 6, 36), Vector3(6, 0.2, 2), Color(0.85, 0.72, 0.52, 0.22), Vector2(3.0, 3.0), 4.0)
	# soft round puffs, drawn by their own shader (a textured alpha card showed as a solid tan blob on phones)
	var dm := ShaderMaterial.new()
	dm.shader = preload("res://scripts/dust.gdshader")
	(dust_p.mesh as QuadMesh).material = dm
	var layer := CanvasLayer.new()
	layer.layer = 0
	m.add_child(layer)
	tint = ColorRect.new()
	tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nrender_mode blend_mul;\nuniform vec4 t : source_color = vec4(1.0);\nvoid fragment(){ COLOR = t; }"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	tint.material = mat
	layer.add_child(tint)
	flash = ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(1, 1, 1, 0)
	layer.add_child(flash)
	if not Game.interior():
		for k in ["o_wind", "o_rain", "o_rainroof", "o_night", "o_hum"]:
			var p: AudioStreamPlayer = Sfx.loop(k, -80.0)
			if p:
				loops[k] = p
	kind = String(Game.flags.get("wx", "clear"))
	if not WX.has(kind):
		kind = "clear"
	cur = WX[kind].duplicate()

func _exit_tree() -> void:
	for k in loops:
		if is_instance_valid(loops[k]):
			loops[k].queue_free()

func _particles(n: int, box: Vector3, vel: Vector3, col: Color, size: Vector2, life: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = n
	p.lifetime = life
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = box
	p.direction = vel.normalized()
	p.spread = 4.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = vel.length() * 0.9
	p.initial_velocity_max = vel.length() * 1.1
	var q := QuadMesh.new()
	q.size = size
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = col
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y if size.y > size.x else BaseMaterial3D.BILLBOARD_ENABLED
	m.disable_receive_shadows = true
	# streaks right in front of the lens fade out instead of drawing a white bar across the screen
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = 2.0
	m.distance_fade_max_distance = 6.0
	q.material = m
	p.mesh = q
	p.local_coords = false
	p.emitting = false
	main.add_child(p)
	return p

func set_weather(k: String, lock := false) -> void:
	if not WX.has(k):
		return
	if k != kind and Game.booted:
		match k:
			"storm": Game.msg("A dust storm is rolling in. Hard to see, hard to be seen.")
			"rain": Game.msg("Rain. Actual rain. The dust turns to mud.")
			"thunder": Game.msg("A thunderstorm rolls in over the wastes.")
			"clear": if kind != "cloudy": Game.msg("The sky is clearing.")
	kind = k
	locked = lock
	next = randf_range(160.0, 360.0)
	Game.flags["wx"] = k

func night_f() -> float:
	return 1.0 - day

func clock() -> String:
	var h := Game.time * 24.0
	return "%02d:%02d" % [int(h), int(fmod(h, 1.0) * 60.0)]

func _process(dt: float) -> void:
	if Game.paused or Game.player == null:
		return
	main.radio_tick(dt)
	# the clock always runs (also indoors)
	Game.time += dt / DAY_LEN * float(Game.dev.dayrate)
	if Game.time >= 1.0:
		Game.time -= 1.0
		Game.day += 1
	var f: Dictionary = Game.fx()
	var tt: Color = Color(float(f.tr), float(f.tg), float(f.tb)) * clampf(1.0 + float(f.exposure), 0.6, 1.4)
	(tint.material as ShaderMaterial).set_shader_parameter("t", Color(minf(tt.r, 1.0), minf(tt.g, 1.0), minf(tt.b, 1.0), 1.0))
	if float(f.heart) > 0.0:
		heart_t -= dt
		if heart_t <= 0.0:
			heart_t = 60.0 / (60.0 + 40.0 * float(f.heart))
			Sfx.play("heart", -6.0 + float(f.heart) * 2.0)
	if Game.interior():
		return
	var pp: Vector3 = Game.player.global_position
	# weather drifts
	if not locked:
		next -= dt
		if next <= 0.0:
			var r := randf()
			set_weather("clear" if r < 0.46 else ("cloudy" if r < 0.7 else ("storm" if r < 0.82 else ("rain" if r < 0.93 else "thunder"))))
	var tgt: Dictionary = WX[kind]
	var k := minf(1.0, dt * 0.08)
	for key in cur:
		cur[key] = lerpf(float(cur[key]), float(tgt[key]), k)
	# the sun: 0.25 sunrise, 0.5 noon, 0.75 sunset
	var t := Game.time
	var elev := sin((t - 0.25) * TAU)
	day = clampf(elev * 3.0 + 0.25, 0.0, 1.0)
	var low := clampf(1.0 - absf(elev) * 4.0, 0.0, 1.0) * (1.0 if elev > -0.15 else 0.0)  # sunrise/sunset glow
	var az := -PI / 2.0 + t * TAU
	var moon := elev < 0.0
	var e := absf(elev) if moon else elev
	sun.rotation = Vector3(-asin(clampf(maxf(e, 0.08), 0.0, 1.0)), az + (PI if moon else 0.0), 0)
	var cover := float(cur.cover)
	var haze := float(cur.haze)
	var green := float(cur.green)
	var sun_col := Color(1.0, 0.88, 0.7).lerp(Color(1.0, 0.55, 0.3), low * 0.7)
	if moon:
		sun_col = Color(0.55, 0.65, 0.9)
	sun_col = sun_col.lerp(Color(0.7, 1.0, 0.6), green * 0.45)
	sun.light_color = sun_col
	sun.light_energy = (1.4 * day * (1.0 - cover * 0.45) * (1.0 - haze * 0.4)) if not moon else 0.12 * (1.0 - cover * 0.6)
	var night := 1.0 - day
	# indoors the sky's light only gets in by the door and the windows (build 23: a shack's insides were lit as
	# brightly as the street, flat and shadowless): eased down while you're under a roof with walls round you,
	# so the lamp inside does the work and the doorway glows with the day outside
	indoor_k = move_toward(indoor_k, 1.0 if enclosed else 0.0, dt * 1.5)
	# a little less fill and a little more sun than before: shadows that read, the light with a direction to it
	env.ambient_light_energy = (0.3 + 0.52 * day) * (1.0 - 0.55 * indoor_k)
	if sm:
		var top_d := Color(0.36, 0.47, 0.6).lerp(Color(0.5, 0.5, 0.5), cover * 0.5)
		var hor_d := Color(0.86, 0.74, 0.58).lerp(Color(0.95, 0.6, 0.35), low * 0.6)
		var top_n := Color(0.02, 0.03, 0.07)
		var hor_n := Color(0.08, 0.08, 0.12)
		var top := top_d.lerp(top_n, night).lerp(Color(0.62, 0.55, 0.42), haze * 0.6)
		var hor := hor_d.lerp(hor_n, night).lerp(Color(0.7, 0.6, 0.45) * (0.3 + 0.7 * day), haze * 0.7)
		top = top.lerp(Color(0.3, 0.5, 0.28) * (0.3 + 0.7 * day), green * 0.55)
		hor = hor.lerp(Color(0.5, 0.66, 0.36) * (0.3 + 0.7 * day), green * 0.5)
		sm.sky_top_color = top
		sm.sky_horizon_color = hor
		sm.ground_horizon_color = hor.darkened(0.2)
		sm.sun_angle_max = 20.0 if not moon else 6.0
	var fogc := Color(0.78, 0.68, 0.55).lerp(Color(0.1, 0.1, 0.14), night).lerp(Color(0.75, 0.62, 0.45) * (0.35 + 0.65 * day), haze)
	env.fog_light_color = fogc.lerp(Color(0.5, 0.7, 0.38) * (0.3 + 0.7 * day), green * 0.45)
	env.fog_density = 0.0045 * Quality.haze * (1.0 + haze * 5.0 + float(cur.rain) * 1.0) * (1.0 + night * 0.4)
	env.tonemap_exposure = 1.0 + (0.45 * night if float(f.night) > 0.0 else 0.0) * float(f.night)
	env.adjustment_saturation = 0.9 * float(f.sat)
	env.adjustment_contrast = 1.05 * float(f.con)
	# your lantern at night
	lamp.light_energy = night * 1.6 + haze * day * 0.3
	lamp.global_position = pp + Vector3.UP * 2.2
	# under a roof? (rain stops, rain drums instead; radstorm can't reach you)
	roof_t -= dt
	if roof_t <= 0.0:
		roof_t = 0.4
		var q := PhysicsRayQueryParameters3D.create(pp + Vector3.UP * 1.7, pp + Vector3.UP * 12.0, 1)
		roofed = not main.get_world_3d().direct_space_state.intersect_ray(q).is_empty()
		enclosed = false
		if Game.area == "world" and Frontier.indoors(pp.x, pp.z) and pp.y - Game.height(pp.x, pp.z) < 2.0:
			roofed = true
			enclosed = true
		elif roofed:
			var walls := 0
			for i in 8:
				var a := i * TAU / 8.0
				var hq := PhysicsRayQueryParameters3D.create(pp + Vector3.UP * 1.3, pp + Vector3(sin(a) * 7.0, 1.3, cos(a) * 7.0), 1)
				hq.exclude = [Game.player.get_rid()]
				if not main.get_world_3d().direct_space_state.intersect_ray(hq).is_empty():
					walls += 1
			enclosed = walls >= 6
	var rn := float(cur.rain)
	rain_p.emitting = rn > 0.1 and not roofed
	rain_p.global_position = pp + Vector3.UP * 8.0
	# rain is only as bright as the sky: grey streaks at night, not neon
	var rm := (rain_p.mesh as QuadMesh).material as StandardMaterial3D
	var lit := lerpf(0.22, 0.85, day)
	rm.albedo_color = Color(lit * 0.95, lit, lit * 1.05, lerpf(0.22, 0.4, day))
	dust_p.emitting = haze > 0.3
	dust_p.global_position = pp + Vector3.UP * 2.0
	_vol("o_wind", -24.0 + float(cur.wind) * 5.0)
	_vol("o_rain", -8.0 if rn > 0.05 and not roofed else -80.0, rn)
	_vol("o_rainroof", -6.0 if rn > 0.05 and roofed else -80.0, rn)
	_vol("o_night", -16.0, clampf(night * 1.4 - 0.2, 0.0, 1.0) * (1.0 - haze * 0.7))
	var core: Dictionary = Game.DB.locs.get("reactor", {"x": 9999, "z": 9999})
	var hot: bool = Game.flags.get("coreChoice") != "scram"
	var rd := Vector2(pp.x - float(core.x), pp.z - float(core.z)).length()
	_vol("o_hum", -12.0, clampf(1.0 - rd / 45.0, 0.0, 1.0) if hot else 0.0)
	# lightning and thunder
	if flash.color.a > 0.0:
		flash.color.a = maxf(0.0, flash.color.a - dt * 2.5)
	if WX[kind].bolt:
		bolt_t -= dt
		if bolt_t <= 0.0:
			bolt_t = randf_range(5.0, 21.0)
			var d := randf_range(120.0, 540.0)
			flash.color = Color(0.85, 1.0, 0.8, 0.0) if green > 0.5 else Color(1, 1, 1, 0.0)
			flash.color.a = 0.5 if d < 250.0 else 0.28
			thunder.append([d / 340.0, d])
	for i in range(thunder.size() - 1, -1, -1):
		thunder[i][0] -= dt
		if thunder[i][0] <= 0.0:
			var dd: float = thunder[i][1]
			Sfx.play("x_boom1" if randf() < 0.5 else "x_boom3", 2.0 - dd / 60.0, 0.55)
			if dd < 200.0:
				Game.player.hurt_shake = maxf(Game.player.hurt_shake, 0.2)
			thunder.remove_at(i)
	# radiation: glowing pools, a hot reactor, a radstorm with no roof over you
	var rate := 0.0
	for p in Game.region.pools:
		if p.get("glow", false) and Vector2(float(p.x) - pp.x, float(p.z) - pp.z).length() < float(p.r):
			rate += float(p.get("rate", 0.6))
	if hot and rd < 60.0:
		rate += 0.28 * (1.0 - rd / 75.0)
	if green > 0.3 and not roofed:
		rate += 0.4 * green
	if rate > 0.0:
		Game.add_rad(rate * dt)
		geiger_t -= dt * rate * 6.0
		if geiger_t <= 0.0:
			geiger_t = randf_range(0.25, 0.85)
			Sfx.play("geiger", -6.0, randf_range(0.9, 1.2))

func _vol(k: String, db: float, amt := 1.0) -> void:
	if not loops.has(k):
		return
	var p: AudioStreamPlayer = loops[k]
	var target := db if amt > 0.02 else -80.0
	if amt > 0.02 and amt < 1.0:
		target = db + linear_to_db(amt)
	p.volume_db = lerpf(p.volume_db, target, 0.05)
