# What the gunsmith's parts look like on the gun: a scope or a reflex sight on top, a suppressor, compensator or
# longer barrel past the muzzle, a bigger magazine or a drum underneath, a padded or wire stock at the back. Sized from
# the gun's own length, so they fit pistols and rifles alike. (Gunsmith tab in the Pip menu; data in tools/arsenal.)
class_name GunMods

static func attach(gun: Node3D, fit: Basis, id: String) -> void:
	var fitted: Dictionary = Game.mods.get(id, {})
	if fitted.is_empty():
		return
	var old := gun.get_node_or_null("Mods")
	if old:
		old.free()
	var bb := Humanoid.gun_bounds(gun)
	var fwd := (fit.inverse() * Vector3(0, 0, -1))
	fwd.y = 0
	fwd = fwd.normalized() if fwd.length() > 0.1 else Vector3.FORWARD
	# a frame on the gun: -Z toward the muzzle, +Y up
	var zb := -fwd
	var xb := Vector3.UP.cross(zb).normalized()
	var fr := Node3D.new()
	fr.name = "Mods"
	fr.basis = Basis(xb, Vector3.UP, zb)
	gun.add_child(fr)
	var inv := fr.basis.inverse()
	var fb := AABB()
	var first := true
	for i in 8:
		var p: Vector3 = inv * bb.get_endpoint(i)
		fb = AABB(p, Vector3.ZERO) if first else fb.expand(p)
		first = false
	var L := fb.size.z
	var front := fb.position.z
	var rear := fb.end.z
	var top := fb.end.y
	var bottom := fb.position.y
	var cx := fb.get_center().x
	var muzzle_y := top - fb.size.y * 0.18
	var metal := _m(Color(0.16, 0.16, 0.17), 0.6, 0.4)
	var M: Dictionary = Game.ARSENAL.get("mods", {})
	for slot in fitted:
		match String(fitted[slot]):
			"suppressor":
				_cyl(fr, 0.032 * L, 0.24 * L, Vector3(cx, muzzle_y, front - 0.12 * L), metal)
			"compensator":
				_box(fr, Vector3(0.05 * L, 0.05 * L, 0.07 * L), Vector3(cx, muzzle_y, front - 0.035 * L), metal)
			"focus_lens":
				_cyl(fr, 0.04 * L, 0.05 * L, Vector3(cx, muzzle_y, front - 0.025 * L), metal)
				_cyl(fr, 0.03 * L, 0.006 * L, Vector3(cx, muzzle_y, front - 0.052 * L), _glow(Color(0.6, 1.0, 0.9)))
			"long_barrel":
				_cyl(fr, 0.016 * L, 0.18 * L, Vector3(cx, muzzle_y, front - 0.09 * L), metal)
			"ported_barrel":
				for k in 3:
					_box(fr, Vector3(0.03 * L, 0.01 * L, 0.02 * L), Vector3(cx, top + 0.003 * L, front + (0.05 + k * 0.04) * L), _m(Color(0.05, 0.05, 0.05), 0.2, 0.8))
			"scope":
				var z := lerpf(rear, front, 0.55)
				_cyl(fr, 0.021 * L, 0.26 * L, Vector3(cx, top + 0.04 * L, z), metal)
				_cyl(fr, 0.018 * L, 0.004 * L, Vector3(cx, top + 0.04 * L, z - 0.131 * L), _m(Color(0.1, 0.2, 0.35), 0.9, 0.1))
				for dz in [-0.07, 0.07]:
					_box(fr, Vector3(0.018 * L, 0.03 * L, 0.016 * L), Vector3(cx, top + 0.015 * L, z + dz * L), metal)
			"reflex":
				var z2 := lerpf(rear, front, 0.4)
				_box(fr, Vector3(0.05 * L, 0.012 * L, 0.06 * L), Vector3(cx, top + 0.006 * L, z2), metal)
				_box(fr, Vector3(0.05 * L, 0.05 * L, 0.008 * L), Vector3(cx, top + 0.035 * L, z2 - 0.02 * L), _m(Color(0.25, 0.35, 0.4, 0.4), 0.3, 0.1, true))
				_box(fr, Vector3(0.006 * L, 0.006 * L, 0.004 * L), Vector3(cx, top + 0.035 * L, z2 - 0.016 * L), _glow(Color(1.0, 0.15, 0.1)))
			"big_mag":
				_box(fr, Vector3(0.05 * L, 0.24 * L, 0.08 * L), Vector3(cx, bottom - 0.06 * L, lerpf(rear, front, 0.5)), metal)
			"drum_mag":
				var dm := _cyl(fr, 0.11 * L, 0.07 * L, Vector3(cx, bottom - 0.05 * L, lerpf(rear, front, 0.5)), metal)
				dm.rotation = Vector3(0, 0, PI / 2)
			"quick_mag":
				_box(fr, Vector3(0.055 * L, 0.025 * L, 0.03 * L), Vector3(cx, bottom - 0.01 * L, lerpf(rear, front, 0.5)), _m(Color(0.8, 0.65, 0.2), 0.1, 0.7))
			"full_stock":
				_box(fr, Vector3(0.06 * L, fb.size.y * 0.55, 0.04 * L), Vector3(cx, lerpf(bottom, top, 0.45), rear + 0.02 * L), _m(Color(0.12, 0.1, 0.09), 0.1, 0.9))
			"wire_stock":
				for y in [0.25, 0.75]:
					_box(fr, Vector3(0.012 * L, 0.012 * L, 0.3 * L), Vector3(cx, lerpf(bottom, top, y), rear + 0.15 * L), metal)
				_box(fr, Vector3(0.012 * L, fb.size.y * 0.55, 0.012 * L), Vector3(cx, lerpf(bottom, top, 0.5), rear + 0.3 * L), metal)
			"capacitor", "heavy_receiver":
				_cyl(fr, 0.025 * L, 0.12 * L, Vector3(cx + fb.size.x * 0.55, lerpf(bottom, top, 0.6), lerpf(rear, front, 0.4)),
					_glow(Color(0.4, 0.8, 1.0)) if String(fitted[slot]) == "capacitor" else metal)

static func _m(c: Color, metal: float, rough: float, clear := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	if clear:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

static func _glow(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	return m

static func _box(p: Node3D, size: Vector3, at: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = at
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(mi)
	return mi

# a cylinder lying along the gun (its axis on Z)
static func _cyl(p: Node3D, r: float, h: float, at: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 12
	mi.mesh = c
	mi.position = at
	mi.rotation = Vector3(PI / 2, 0, 0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(mi)
	return mi
