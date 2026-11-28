class_name QuestGlint
extends Node3D
# Something to look for (build 24): a spot a quest wants searched — the scorched pod, the hull breach, a cache behind a
# tent — shows a slow pale glint where it is while the quest wants it and you're within 35 m, and a ring of light on
# the ground under it when you're close, so a thing you need is never only a word on the screen.

const RANGE := 35.0
const MAX := 6
var pool: Array = []      # [sprite, ring]
var t := 0.0
var live: Array = []      # [point, at]

func _ready() -> void:
	for i in MAX:
		var s := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.9, 0.9)
		s.mesh = q
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.albedo_texture = GunFX._star()
		m.albedo_color = Color(1.0, 0.92, 0.65, 0.0)
		m.no_depth_test = false
		m.disable_fog = true
		s.material_override = m
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.visible = false
		add_child(s)
		var r := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.62
		tm.outer_radius = 0.7
		tm.rings = 24
		tm.ring_segments = 4
		r.mesh = tm
		r.scale = Vector3(1, 0.05, 1)
		var rm := StandardMaterial3D.new()
		rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		rm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		rm.albedo_color = Color(1.0, 0.9, 0.6, 0.0)
		r.material_override = rm
		r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		r.visible = false
		add_child(r)
		pool.append([s, r])

# the points worth a glint right now: story points whose label is up (the quest wants them), not doors or games
static func wanted(o: Dictionary) -> bool:
	if String(o.get("_k", "")) != "point":
		return false
	var id := String(o.get("id", ""))
	if id in ["cellin", "cellout", "vaultExit", "haven", "buggy", "board", "well", "pool", "recycler"] or id.begins_with("slots") \
			or id in ["blackjack", "roulette", "dice"]:
		return false
	var objs = Game.main.get("objects") if Game.main else null
	if objs == null:
		return false
	var qp: Dictionary = objs._qp(o)
	if not qp.has("label"):
		return false
	return objs.point_label(o) != null

func _process(d: float) -> void:
	var p = Game.player
	if p == null or Game.main == null or Game.main.get("objects") == null:
		return
	t += d
	# the list is looked at twice a second; the glints breathe every frame
	if fmod(t, 0.5) < d:
		live.clear()
		var pp: Vector3 = p.global_position
		var objs = Game.main.objects
		var kx := floori((pp.x - Game.x0) / objs.CH)
		var kz := floori((pp.z - Game.z0) / objs.CH)
		var found: Array = []
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				for o in objs.grid.get(str(kx + dx) + "_" + str(kz + dz), []):
					if not wanted(o):
						continue
					var y: float = float(o.y) if o.has("y") else Game.height(float(o.x), float(o.z))
					var at := Vector3(float(o.x), y, float(o.z))
					var dist := at.distance_to(pp)
					if dist < RANGE:
						found.append([dist, o, at])
		found.sort_custom(func(a, b): return a[0] < b[0])
		for f in found.slice(0, MAX):
			live.append([f[1], f[2], f[0]])
	for i in MAX:
		var s: MeshInstance3D = pool[i][0]
		var r: MeshInstance3D = pool[i][1]
		if i >= live.size():
			s.visible = false
			r.visible = false
			continue
		var at: Vector3 = live[i][1]
		var dist: float = live[i][2]
		var breathe := 0.5 + 0.5 * sin(t * 2.6 + i * 1.3)
		var near := clampf(1.0 - (dist - 2.0) / RANGE, 0.0, 1.0)
		s.visible = true
		s.global_position = at + Vector3.UP * (1.05 + 0.08 * sin(t * 1.7 + i))
		# big enough to spot across a field, small enough not to sit in your face up close
		var sz := lerpf(0.5, 1.4, clampf(dist / RANGE, 0.0, 1.0)) * (0.85 + 0.3 * breathe)
		s.scale = Vector3.ONE * sz
		(s.material_override as StandardMaterial3D).albedo_color.a = (0.35 + 0.45 * breathe) * (0.4 + 0.6 * near)
		r.visible = dist < 9.0
		if r.visible:
			r.global_position = at + Vector3.UP * 0.06
			r.rotation.y = t * 0.4
			var rs := 1.0 + 0.12 * breathe
			r.scale = Vector3(rs, 0.05, rs)
			(r.material_override as StandardMaterial3D).albedo_color.a = 0.25 + 0.25 * breathe
