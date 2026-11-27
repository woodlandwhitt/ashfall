# People, built from CC0 Quaternius parts that share one 65-bone skeleton: a Modular Outfit (peasant or ranger, male
# or female), a head cut from the Universal Base Character, and the Universal Animation Library's 45 motions
# (idle, walk, jog, sprint, talk, pistol aim/shoot/reload, hit, death, sitting, crouching...).
class_name Humanoid
extends RefCounted

static var _lib: AnimationLibrary
static var _mats: Dictionary = {}

const OUTFITS := ["Male_Peasant", "Male_Ranger", "Female_Peasant", "Female_Ranger", "Male_Noble", "Male_Wizard", "Male_Knight_Cloth"]
const HAIR_M := ["", "Hair_Buzzed", "Hair_SlickBack", "Hair_Balding", "Hair_Long", "Hair_Buzzed", "Hair_SlickBack"]
const HAIR_F := ["Hair_Bob", "Hair_Long", "Hair_SlickBack", "Hair_Bob", "Hair_Long", "Hair_Buzzed"]
const FACE_M := ["", "", "Hair_Beard", "Hair_Moustache", "Hair_Beard", ""]
const HAIR_COLS := [Color(0.08, 0.06, 0.05), Color(0.22, 0.14, 0.08), Color(0.4, 0.27, 0.15), Color(0.62, 0.48, 0.28),
	Color(0.45, 0.2, 0.1), Color(0.55, 0.55, 0.55), Color(0.85, 0.85, 0.82), Color(0.15, 0.12, 0.1)]

static func anim_library() -> AnimationLibrary:
	if _lib == null:
		var ual: Node = (load("res://chars/UAL1_Standard.glb") as PackedScene).instantiate()
		var ap := ual.find_child("AnimationPlayer", true, false) as AnimationPlayer
		_lib = ap.get_animation_library("")   # Godot's importer already loops the *_Loop clips (and drops the suffix)
		ual.free()
		# the second library: farming, eating, arms folded, nodding, the zombie shuffle, an overhand throw...
		if ResourceLoader.exists("res://chars/UAL2.glb"):
			var u2: Node = (load("res://chars/UAL2.glb") as PackedScene).instantiate()
			var ap2 := u2.find_child("AnimationPlayer", true, false) as AnimationPlayer
			var l2 := ap2.get_animation_library("")
			_lib = _lib.duplicate()
			for n in l2.get_animation_list():
				if not _lib.has_animation(n):
					_lib.add_animation(n, l2.get_animation(n))
			u2.free()
	return _lib

static func _mat(key: String, make: Callable) -> Material:
	if not _mats.has(key):
		_mats[key] = make.call()
	return _mats[key]

# outfit: one of OUTFITS. cloth tints the outfit (dusty wasteland colours), skin tints face and hands.
# opts (all optional): "mix" {"Body"/"Legs"/"Feet"/"Arms": outfit} wears another outfit's part; "acc" [mesh names]
# adds belts, pauldrons, bracers, a gorget or a hood from any outfit; "cols" {part: Color} dyes each part on its own;
# "horns" keeps the knight's horned helm; "ghoul" rots the skin and tears the clothes.
static func _prefix(outfit: String) -> String:
	return outfit.replace("_Cloth", "") + "_"

static func _part_of(mesh_name: String, outfit: String) -> String:
	var rest := mesh_name.trim_prefix(_prefix(outfit))
	var cat := rest.split("_")[0]
	# belts and ornaments hang off the body but are accessories
	if cat == "Body" and rest != "Body" and rest != "Body_Cloth":
		return "Acc"
	if cat == "Arms" and rest != "Arms":
		return "Acc"
	if cat == "Feet" and rest.begins_with("Feet_Armor"):
		return "Feet"
	if cat == "Legs" and rest.begins_with("Legs_Armor"):
		return "Legs"
	return cat

static func build(outfit: String, cloth: Color, skin: Color, quality_lod := true, opts := {}) -> Node3D:
	var root := (load("res://chars/" + outfit + ".gltf") as PackedScene).instantiate() as Node3D
	var skel := root.find_child("Skeleton3D", true, false) as Skeleton3D
	var female := outfit.begins_with("Female")
	var ghoul: bool = opts.get("ghoul", false)
	var skin_key := "skin_%s_%s_%s" % [female, skin.to_html(), ghoul]
	var skin_mat := _mat(skin_key, func():
		if ghoul:
			return _ghoul_skin(female, skin)
		var m := StandardMaterial3D.new()
		m.albedo_texture = load("res://chars/T_Regular_%s_Dark_BaseColor.png" % ("Female" if female else "Male"))
		m.normal_enabled = true
		m.normal_texture = load("res://chars/T_Regular_%s_Normal.png" % ("Female" if female else "Male"))
		m.roughness_texture = load("res://chars/T_Regular_%s_Roughness.png" % ("Female" if female else "Male"))
		m.albedo_color = skin
		return m)
	var mix: Dictionary = opts.get("mix", {})
	var acc: Array = opts.get("acc", [])
	var cols: Dictionary = opts.get("cols", {})
	# the files carry stray parts of other outfits (and a crown): keep only what this person is wearing
	for mi in skel.find_children("*", "MeshInstance3D", false, false):
		var nm := String(mi.name)
		var keep := false
		if nm.begins_with(_prefix(outfit)):
			var cat := _part_of(nm, outfit)
			keep = not mix.has(cat) and (cat != "Acc" or acc.is_empty() or acc.has(nm))
			if nm.ends_with("Head_Crown") or (nm.ends_with("Head_Horns") and not opts.get("horns", false)):
				keep = false
			if cat == "Head" and nm.ends_with("Hood") and opts.get("nohood", false):
				keep = false
		elif acc.has(nm):
			keep = true
		if not keep:
			skel.remove_child(mi)
			mi.queue_free()
	# parts borrowed from other outfits move onto this skeleton (bones matched by name, as the head does)
	var borrow := {}
	for cat in mix:
		borrow[String(mix[cat])] = true
	for nm2 in acc:
		var o2 := _outfit_of(String(nm2))
		if o2 != "" and o2 != outfit:
			borrow[o2] = true
	for src_outfit in borrow:
		if not ResourceLoader.exists("res://chars/" + String(src_outfit) + ".gltf"):
			continue
		var src := (load("res://chars/" + String(src_outfit) + ".gltf") as PackedScene).instantiate()
		var ssk := src.find_child("Skeleton3D", true, false)
		for mi in ssk.find_children("*", "MeshInstance3D", false, false):
			var nm := String(mi.name)
			if not nm.begins_with(_prefix(String(src_outfit))):
				continue
			var cat := _part_of(nm, String(src_outfit))
			var take: bool = (mix.get(cat, "") == src_outfit and cat != "Acc") or acc.has(nm)
			if nm.ends_with("Head_Crown") or (nm.ends_with("Head_Horns") and not opts.get("horns", false)):
				take = false
			if take:
				ssk.remove_child(mi)
				mi.owner = null
				skel.add_child(mi)
				(mi as MeshInstance3D).skeleton = NodePath("..")
		src.free()
	for mi in skel.find_children("*", "MeshInstance3D", false, false):
		var m := mi as MeshInstance3D
		var nm := String(m.name)
		var owner_outfit := _outfit_of(nm)
		var cat := _part_of(nm, owner_outfit) if owner_outfit != "" else "Body"
		var tint: Color = cols.get(cat, cloth)
		for s in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(s)
			if src and String(src.resource_name).begins_with("MI_Regular"):
				m.set_surface_override_material(s, skin_mat)
			elif src is StandardMaterial3D:
				var grime := float(opts.get("grime", 0.0))
				# the knight's tabard keeps its folds but loses the cross on its front (build 24)
				var flat := 0.85 if nm.begins_with("Male_Knight_Body") else 0.0
				var key := "cloth_%s_%s_%s_%.1f_%.1f" % [src.resource_name, tint.to_html(), ghoul, grime, flat]
				m.set_surface_override_material(s, _mat(key, func():
					if ghoul:
						return _tatters(src as StandardMaterial3D, tint)
					if grime > 0.0 or flat > 0.0:
						return _grimy(src as StandardMaterial3D, tint, grime, flat)
					var c := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
					c.albedo_color = tint
					return c))
	# the head (and eyes, brows) moves onto the outfit's skeleton; bones are matched by name
	var head := (load("res://chars/head_%s.glb" % ("female" if female else "male")) as PackedScene).instantiate()
	var hskel := head.find_child("Skeleton3D", true, false)
	var hood := outfit.ends_with("Ranger")
	for mi in hskel.find_children("*", "MeshInstance3D", false, false):
		var m := mi as MeshInstance3D
		hskel.remove_child(m)
		m.owner = null
		skel.add_child(m)
		m.skeleton = NodePath("..")
		var nm := String(m.name)
		if nm == "Eyes":
			m.material_override = _mat("eyes", func():
				var e := StandardMaterial3D.new()
				e.albedo_texture = load("res://chars/T_Eye_Brown.png")
				e.roughness = 0.2
				return e)
		elif nm == "Eyebrows" or nm == "Face":
			m.material_override = _mat("brows", func():
				var b := StandardMaterial3D.new()
				b.albedo_color = Color(0.12, 0.08, 0.05)
				b.roughness = 0.9
				return b)
		else:
			m.material_override = skin_mat
	head.free()
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	root.add_child(ap)
	ap.root_node = NodePath("..")
	ap.add_animation_library("", anim_library())
	ap.playback_default_blend_time = 0.25
	return root

static func play(ap: AnimationPlayer, anim: String, speed := 1.0) -> void:
	if ap.current_animation != anim:
		ap.play(anim)
	ap.speed_scale = speed

# a weapon in the right hand, lined up with the body's forward direction in the current pose (call after posing)
# fit: the gun model's own fix-up (its muzzle ends up along -Z); grip: where its origin sits, in the body's frame
# (x left, y up, z forward) relative to the right wrist
static func hold_aligned(root: Node3D, scene: PackedScene, fit: Basis, grip: Vector3) -> Node3D:
	var skel := root.find_child("Skeleton3D", true, false) as Skeleton3D
	skel.force_update_all_bone_transforms()
	var hb := skel.get_bone_global_pose(skel.find_bone("hand_r"))
	var D := Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1))
	var xf := Transform3D(hb.basis.inverse() * D * fit, hb.basis.inverse() * grip)
	return hold(root, scene, xf)

# a weapon in the right hand
static func hold(root: Node3D, scene: PackedScene, xf: Transform3D) -> Node3D:
	var skel := root.find_child("Skeleton3D", true, false) as Skeleton3D
	var ba := BoneAttachment3D.new()
	ba.bone_name = "hand_r"
	skel.add_child(ba)
	var g := scene.instantiate() as Node3D
	g.transform = xf
	ba.add_child(g)
	return g


# ---------------------------------------------------------------- seating a gun in the hand
# the model-space bounds of a gun model
static func gun_bounds(g: Node3D) -> AABB:
	var bb := AABB()
	var first := true
	for c in g.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var xf := Transform3D.IDENTITY
		var p: Node = mi
		while p != g:
			xf = (p as Node3D).transform * xf
			p = p.get_parent()
		var b: AABB = xf * mi.get_aabb()
		bb = b if first else bb.merge(b)
		first = false
	return bb

# where the hand closes on a gun, in model space: the pistol grip sits behind and below the barrel. fit is the
# model's fix-up (muzzle along -Z after it).
static func grip_of(bb: AABB, fit: Basis) -> Vector3:
	var inv := fit.orthonormalized().inverse()
	var fwd := (inv * Vector3(0, 0, -1)).normalized()
	var up := (inv * Vector3.UP).normalized()
	var c := bb.get_center()
	var half_len := absf(fwd.dot(bb.size)) * 0.5
	var half_h := absf(up.dot(bb.size)) * 0.5
	var length := half_len * 2.0 * fit.get_scale().x
	var long := length > 0.42
	var along := (0.30 if long else 0.30) * half_len * 2.0
	var g := c - fwd * half_len + fwd * along
	g += up * (half_h * (-0.45 if long else -0.4))
	return g

# put grip (model space) at palm (body frame, relative to the right wrist: x left, y up, z forward)
static func seat(root: Node3D, g: Node3D, palm: Vector3, grip: Vector3) -> void:
	var skel := root.find_child("Skeleton3D", true, false) as Skeleton3D
	var hb := skel.get_bone_global_pose(skel.find_bone("hand_r"))
	g.position = hb.basis.inverse() * palm - g.transform.basis * grip

const PALM := Vector3(0.0, -0.04, 0.035)

# hold a gun by its grip (call after posing)
static func hold_gun(root: Node3D, scene: PackedScene, fit: Basis, gf: Dictionary = {}) -> Node3D:
	var g := hold_aligned(root, scene, fit, Vector3.ZERO)
	GunPaint.apply(g, gf)
	var bb := gun_bounds(g)
	seat(root, g, PALM, grip_of(bb, fit) if gf.is_empty() else grip_fit(bb, fit, gf))
	return g

# a long gun brought up to the shoulder (build 22). The gun rides the chest (so it follows the chest when the body
# leans to aim up or down), its butt in the right shoulder and its muzzle where the body faces; the right hand reaches
# for the pistol grip and the left for the handguard. Before this a rifle sat in the right hand like a pistol, held
# out at arm's length, or pointing at the sky whenever the arm swung. Call with the body in its aiming pose.
static func shoulder_gun(root: Node3D, scene: PackedScene, fit: Basis, gf: Dictionary) -> Node3D:
	var sk := root.find_child("Skeleton3D", true, false) as Skeleton3D
	var spine := sk.find_bone("spine_03")
	var ua := sk.find_bone("upperarm_r")
	if spine < 0 or ua < 0:
		return hold_gun(root, scene, fit, gf)
	sk.force_update_all_bone_transforms()
	var ts: Transform3D = sk.get_bone_global_pose(spine)
	var shoulder: Vector3 = sk.get_bone_global_pose(ua).origin
	var ba := BoneAttachment3D.new()
	ba.bone_name = "spine_03"
	sk.add_child(ba)
	var g := scene.instantiate() as Node3D
	ba.add_child(g)
	GunPaint.apply(g, gf)
	var bb := gun_bounds(g)
	var inv := fit.orthonormalized().inverse()
	var fwd := (inv * Vector3(0, 0, -1)).normalized()
	var up := (inv * Vector3.UP).normalized()
	var half_len := absf(fwd.dot(bb.size)) * 0.5
	var half_h := absf(up.dot(bb.size)) * 0.5
	var rear := bb.get_center() - fwd * half_len * 0.92 + up * half_h * 0.2
	# bodies face +Z: turn the gun's muzzle (-Z after fit) round to +Z
	var gb := Basis(Vector3.UP, PI) * fit
	var at := shoulder + Vector3(-0.03, 0.02, 0.05)
	var xf := Transform3D(gb, at - gb * rear)
	g.transform = ts.affine_inverse() * xf
	var rt := Node3D.new()
	g.add_child(rt)
	rt.position = grip_fit(bb, fit, gf) - up * 0.02
	var ikr := ArmIK.new()
	sk.add_child(ikr)
	ikr.setup(sk, "r", rt)
	var lt := Node3D.new()
	g.add_child(lt)
	lt.position = guard_fit(bb, fit, gf) - up * 0.03
	var ikl := ArmIK.new()
	sk.add_child(ikl)
	ikl.setup(sk, "l", lt)
	g.set_meta("iks", [ikr, ikl])
	return g

# a long gun held in both hands (build 22): the left hand reaches for the handguard instead of hanging or cupping an
# empty pistol grip. Returns the IK (or null for a handgun).
static func two_hand(root: Node3D, g: Node3D, fit: Basis, gf: Dictionary) -> ArmIK:
	if gf.get("pistol", false) or g == null:
		return null
	var sk := root.find_child("Skeleton3D", true, false) as Skeleton3D
	if sk == null:
		return null
	var tgt := Node3D.new()
	tgt.name = "SupportHand"
	g.add_child(tgt)
	tgt.position = guard_fit(gun_bounds(g), fit, gf)
	var ik := ArmIK.new()
	sk.add_child(ik)
	ik.setup(sk, "l", tgt)
	return ik

# where the support hand goes on a long gun: under the handguard, about 0.6 of the way to the muzzle
static func guard_fit(bb: AABB, fit: Basis, gf: Dictionary) -> Vector3:
	var inv := fit.orthonormalized().inverse()
	var fwd := (inv * Vector3(0, 0, -1)).normalized()
	var up := (inv * Vector3.UP).normalized()
	var c := bb.get_center()
	var half_len := absf(fwd.dot(bb.size)) * 0.5
	var half_h := absf(up.dot(bb.size)) * 0.5
	var t: Array = grips.get(String(gf.get("glb", "")), [])
	var gfrac: float = t[2] if t.size() > 2 else 0.62
	var gdown: float = t[3] if t.size() > 3 else 0.55
	return c - fwd * half_len + up * half_h + fwd * half_len * 2.0 * gfrac - up * half_h * 2.0 * gdown

# where the hands close on each gun, as fractions of the model: [grip: from the back towards the muzzle, down from
# the top; support hand: along, down]. Read off side views of every model (tools/gunside.tscn).
const GRIPS := {
	"AssaultRifle2_2": [0.30, 0.56, 0.64, 0.27], "AssaultRifle_3": [0.07, 0.48, 0.63, 0.25], "Bullpup_1": [0.47, 0.68, 0.87, 0.54],
	"Pistol_4": [0.23, 0.62, 0.5], "Pistol_Compact_West": [0.2, 0.62, 0.5], "Pistol_Full_East": [0.19, 0.59, 0.5],
	"Revolver_3": [0.13, 0.64, 0.5], "Rifle_Assault_East": [0.34, 0.53, 0.72, 0.3], "Rifle_Battle_West": [0.3, 0.72, 0.67, 0.37],
	"SMG_Compact_West": [0.54, 0.45, 0.79, 0.26], "Shotgun_Auto_East": [0.33, 0.59, 0.79, 0.29], "Shotgun_Pump_West": [0.175, 0.46, 0.8, 0.48],
	"Shotgun_SawedOff": [0.13, 0.58, 0.67, 0.4], "SniperRifle_4": [0.235, 0.5, 0.52, 0.5], "Sniper_Rifle_West": [0.26, 0.72, 0.62, 0.43],
	"SubmachineGun_3": [0.46, 0.59, 0.85, 0.59],
}
# GRIPS plus the ones data/arsenal.json adds (Game._merge_arsenal)
static var grips: Dictionary = GRIPS.duplicate()

static func grip_fit(bb: AABB, fit: Basis, gf: Dictionary) -> Vector3:
	var inv := fit.orthonormalized().inverse()
	var fwd := (inv * Vector3(0, 0, -1)).normalized()
	var up := (inv * Vector3.UP).normalized()
	var c := bb.get_center()
	var half_len := absf(fwd.dot(bb.size)) * 0.5
	var half_h := absf(up.dot(bb.size)) * 0.5
	var t: Array = grips.get(String(gf.get("glb", "")), [])
	var pistol: bool = gf.get("pistol", false)
	var along: float = t[0] if t.size() > 0 else (0.3 if pistol else 0.33)
	var down: float = t[1] if t.size() > 1 else 0.62
	return c - fwd * half_len + up * half_h + fwd * half_len * 2.0 * along - up * half_h * 2.0 * down


# ---------------------------------------------------------------- telling people apart
# a hairstyle or beard (rigged to the same skeleton) onto a built body, dyed
static func add_hair(root: Node3D, style: String, col: Color) -> void:
	if style == "" or not ResourceLoader.exists("res://chars/" + style + ".gltf"):
		return
	var skel := root.find_child("Skeleton3D", true, false) as Skeleton3D
	var h := (load("res://chars/" + style + ".gltf") as PackedScene).instantiate()
	var hs := h.find_child("Skeleton3D", true, false)
	var m := _mat("hair_" + style.substr(5, 4) + col.to_html(), func():
		var src: Material = null
		for mi in hs.find_children("*", "MeshInstance3D", false, false):
			src = (mi as MeshInstance3D).mesh.surface_get_material(0)
		var c := (src as StandardMaterial3D).duplicate() as StandardMaterial3D if src is StandardMaterial3D else StandardMaterial3D.new()
		c.albedo_color = col * 2.2
		c.roughness = 0.75
		c.cull_mode = BaseMaterial3D.CULL_DISABLED
		return c)
	for mi in hs.find_children("*", "MeshInstance3D", false, false):
		hs.remove_child(mi)
		mi.owner = null
		skel.add_child(mi)
		(mi as MeshInstance3D).skeleton = NodePath("..")
		(mi as MeshInstance3D).material_override = m
	h.free()

# simple hats on the head bone: a wide-brimmed hat, the sheriff's, a cap, a steel helmet
static func add_hat(root: Node3D, kind: String, col: Color) -> void:
	if kind == "" or kind == "hood":
		return
	var skel := root.find_child("Skeleton3D", true, false) as Skeleton3D
	var ba := BoneAttachment3D.new()
	ba.bone_name = "Head"
	skel.add_child(ba)
	var hat := Node3D.new()
	ba.add_child(hat)
	# a woman's head sits lower and is a little smaller: the hat goes with it (build 24: caps floated over the hair)
	var hb := skel.get_bone_global_rest(skel.find_bone("Head")).origin
	if hb.y < 1.58:
		hat.scale = Vector3.ONE * 0.94
		hat.position.y = -0.008
	var m := _mat("hat_" + kind + col.to_html(), func():
		var c := StandardMaterial3D.new()
		c.albedo_color = col
		c.roughness = 0.35 if kind == "helmet" else 0.85
		c.metallic = 0.6 if kind == "helmet" else 0.0
		return c)
	var add := func(mesh: Mesh, pos: Vector3, rot := Vector3.ZERO, sc := Vector3.ONE):
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = m
		mi.position = pos
		mi.rotation = rot
		mi.scale = sc
		hat.add_child(mi)
	# the head bone sits at the base of the skull; the crown is about 0.2 m above it
	match kind:
		"wide", "sheriff":
			var brim := CylinderMesh.new()
			brim.top_radius = 0.2 if kind == "wide" else 0.17
			brim.bottom_radius = brim.top_radius
			brim.height = 0.012
			add.call(brim, Vector3(0, 0.15, 0.015))
			var crown := CylinderMesh.new()
			crown.top_radius = 0.08
			crown.bottom_radius = 0.1
			crown.height = 0.11
			add.call(crown, Vector3(0, 0.2, 0.01), Vector3.ZERO, Vector3(1, 1, 1.15))
			if kind == "sheriff":
				var band := CylinderMesh.new()
				band.top_radius = 0.101
				band.bottom_radius = 0.101
				band.height = 0.02
				var bm := MeshInstance3D.new()
				bm.mesh = band
				var bmat := StandardMaterial3D.new()
				bmat.albedo_color = Color(0.25, 0.18, 0.1)
				bm.material_override = bmat
				bm.position = Vector3(0, 0.17, 0.01)
				bm.scale = Vector3(1, 1, 1.15)
				hat.add_child(bm)
		"cap":
			var dome := SphereMesh.new()
			dome.radius = 0.105
			dome.height = 0.11
			dome.is_hemisphere = true
			add.call(dome, Vector3(0, 0.122, 0.0), Vector3.ZERO, Vector3(1, 1, 1.12))
			var visor := BoxMesh.new()
			visor.size = Vector3(0.15, 0.01, 0.09)
			add.call(visor, Vector3(0, 0.13, 0.135), Vector3(-0.15, 0, 0))
		"helmet":
			var dome := SphereMesh.new()
			dome.radius = 0.125
			dome.height = 0.13
			dome.is_hemisphere = true
			add.call(dome, Vector3(0, 0.098, 0.0), Vector3.ZERO, Vector3(1, 0.95, 1.1))
			var rim := CylinderMesh.new()
			rim.top_radius = 0.135
			rim.bottom_radius = 0.135
			rim.height = 0.012
			add.call(rim, Vector3(0, 0.098, 0.0), Vector3.ZERO, Vector3(1, 1, 1.1))
	for c in hat.get_children():
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func _outfit_of(mesh_name: String) -> String:
	for o in ["Male_Knight_Cloth", "Male_Peasant", "Male_Ranger", "Male_Noble", "Male_Wizard", "Female_Peasant", "Female_Ranger"]:
		if mesh_name.begins_with(_prefix(o)):
			return o
	return ""

# a ghoul's skin: the base skin turned grey-green and waxy, raw red patches where it has sloughed away, dark veins
static func _ghoul_skin(female: bool, skin: Color) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """shader_type spatial;
uniform sampler2D base_tex : source_color, filter_linear_mipmap;
uniform sampler2D nrm_tex : hint_normal, filter_linear_mipmap;
uniform vec4 tint : source_color;
varying vec3 lp;
float h(vec2 p){ return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float vn(vec2 p){ vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y); }
void vertex(){ lp = VERTEX; }
void fragment(){
	vec3 b = texture(base_tex, UV).rgb;
	float l = dot(b, vec3(0.3, 0.59, 0.11));
	vec3 c = mix(vec3(l), b, 0.12) * tint.rgb * 1.1;
	float n = vn(lp.xy * 18.0 + lp.z * 7.0) * 0.6 + vn(lp.yz * 41.0) * 0.4;
	// raw flesh where the skin has gone
	c = mix(c, vec3(0.42, 0.1, 0.07), smoothstep(0.62, 0.72, n) * 0.85);
	// darker, bruised blotches and veins
	c *= mix(1.0, 0.55, smoothstep(0.35, 0.2, n));
	float vein = smoothstep(0.04, 0.0, abs(vn(lp.xy * 9.0) - 0.5));
	c = mix(c, vec3(0.12, 0.16, 0.1), vein * 0.5);
	ALBEDO = c;
	NORMAL_MAP = texture(nrm_tex, UV).rgb;
	ROUGHNESS = mix(0.35, 0.85, smoothstep(0.62, 0.72, n));
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("base_tex", load("res://chars/T_Regular_%s_Dark_BaseColor.png" % ("Female" if female else "Male")))
	m.set_shader_parameter("nrm_tex", load("res://chars/T_Regular_%s_Normal.png" % ("Female" if female else "Male")))
	m.set_shader_parameter("tint", skin)
	return m

# rags: the outfit's own texture, dyed, filthy, and full of holes
static func _tatters(src: StandardMaterial3D, tint: Color) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode cull_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color;
varying vec3 lp;
float h(vec2 p){ return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float vn(vec2 p){ vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y); }
void vertex(){ lp = VERTEX; }
void fragment(){
	float n = vn(lp.xy * 14.0 + lp.z * 5.0) * 0.65 + vn(lp.xz * 30.0) * 0.35;
	if (n > 0.66) { discard; }
	vec3 c = texture(tex, UV).rgb * tint.rgb;
	c *= mix(0.45, 0.95, vn(lp.xy * 6.0));
	c = mix(c, vec3(0.25, 0.2, 0.12), smoothstep(0.5, 0.66, n) * 0.7);
	ALBEDO = c;
	ROUGHNESS = 0.95;
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("tex", src.albedo_texture)
	m.set_shader_parameter("tint", tint)
	return m

# clothes that have been lived in out here: the dye faded unevenly, dust ground into the lower half, sweat and oil
# stains, scuffed and frayed (darker) at the seams; flat > 0 averages the print away (a tabard's emblem) but keeps
# the folds and stitching
static var _grimy_sh: Shader
static var _white_t: ImageTexture
static func _white() -> ImageTexture:
	if _white_t == null:
		var im := Image.create(4, 4, false, Image.FORMAT_RGB8)
		im.fill(Color.WHITE)
		_white_t = ImageTexture.create_from_image(im)
	return _white_t
static func _grimy(src: StandardMaterial3D, tint: Color, grime: float, flat: float) -> ShaderMaterial:
	if _grimy_sh == null:
		_grimy_sh = Shader.new()
		_grimy_sh.code = """shader_type spatial;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color;
uniform float grime = 0.5;
uniform float flatten = 0.0;
uniform float use_vc = 0.0;
varying vec3 lp;
float h(vec2 p){ return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float vn(vec2 p){ vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y); }
void vertex(){ lp = VERTEX; }
void fragment(){
	vec3 tx = texture(tex, UV).rgb;
	vec3 t = tx * mix(vec3(1.0), COLOR.rgb, use_vc);
	// flatten: one plain cloth, keeping only the shading of the folds (the print, painted in the vertex colours, goes)
	t = mix(t, vec3(0.62) * (0.82 + 0.22 * dot(tx, vec3(0.3, 0.59, 0.11))), flatten);
	vec3 c = t * tint.rgb;
	float n = vn(lp.xy * 9.0 + lp.z * 3.0) * 0.6 + vn(lp.xz * 23.0) * 0.4;
	// faded in patches
	c = mix(c, vec3(dot(c, vec3(0.33))) * 1.08, smoothstep(0.45, 0.8, n) * 0.35 * grime);
	// dust, heavier toward the boots
	float low = clamp(1.0 - lp.y / 1.1, 0.0, 1.0);
	c = mix(c, vec3(0.46, 0.39, 0.3), clamp(low * low * 0.55 + smoothstep(0.55, 0.75, vn(lp.xy * 4.0)) * 0.25, 0.0, 1.0) * grime);
	// oil and old blood
	float st = smoothstep(0.7, 0.78, vn(lp.yz * 13.0 + 3.1));
	c = mix(c, vec3(0.16, 0.11, 0.08), st * 0.6 * grime);
	ALBEDO = c;
	ROUGHNESS = 0.92;
}"""
	var m := ShaderMaterial.new()
	m.shader = _grimy_sh
	m.set_shader_parameter("tex", src.albedo_texture if src.albedo_texture else _white())
	m.set_shader_parameter("use_vc", 1.0 if src.vertex_color_use_as_albedo else 0.0)
	m.set_shader_parameter("tint", tint * src.albedo_color if not src.vertex_color_use_as_albedo else tint)
	m.set_shader_parameter("grime", grime)
	m.set_shader_parameter("flatten", flat)
	return m

# every person different: shirt, trousers, boots and sleeves picked from different outfits, each dyed its own
# wasteland colour (dust, rust, olive, faded denim, leather), plus belts, pauldrons, bracers, a gorget or a hood
const DYES := [Color(0.55, 0.48, 0.38), Color(0.42, 0.36, 0.3), Color(0.5, 0.33, 0.24), Color(0.36, 0.4, 0.3), Color(0.34, 0.38, 0.46),
	Color(0.6, 0.56, 0.48), Color(0.3, 0.27, 0.24), Color(0.52, 0.42, 0.3), Color(0.45, 0.25, 0.2), Color(0.4, 0.42, 0.38), Color(0.62, 0.5, 0.34), Color(0.24, 0.26, 0.3)]
const ACC_M := ["Male_Ranger_Body_Belt_1", "Male_Ranger_Body_Belt_2", "Male_Ranger_Acc_Pauldron", "Male_Ranger_Arms_Bracer", "Male_Noble_Acc_Gorget",
	"Male_Noble_Body_Belt", "Male_Noble_Acc_Pauldron", "Male_Knight_Acc_Pauldron_Spike", "Male_Noble_Arms_Guards", "Male_Wizard_Body_Belt"]
const ACC_F := ["Female_Ranger_Body_Belt_1", "Female_Ranger_Body_Belt_2", "Female_Ranger_Acc_Pauldrons", "Female_Ranger_Arms_Bracer"]
static func mix_spec(rng: RandomNumberGenerator, fem: bool, base: Color, tough := false) -> Dictionary:
	# build 24: the shirt and its sleeves always come from the same outfit (sleeves borrowed from another left bare
	# skin at the shoulder), nobody but the guards wears the knight's tabard with its cross, and the only things worn
	# from another outfit are trousers and boots, which meet the shirt under a belt
	var pool: Array = ["Female_Peasant", "Female_Ranger"] if fem else ["Male_Peasant", "Male_Ranger", "Male_Noble", "Male_Ranger", "Male_Peasant"]
	var body: String = pool[rng.randi() % pool.size()]
	var lower: Array = pool + ([] if fem else ["Male_Knight_Cloth"])
	var mix := {}
	for cat in ["Legs", "Feet"]:
		var o: String = lower[rng.randi() % lower.size()]
		if o == "Male_Knight_Cloth" and cat == "Legs" and not tough:
			o = "Male_Peasant"
		if o != body:
			mix[cat] = o
	var cols := {}
	for cat in ["Body", "Legs", "Feet", "Arms", "Acc"]:
		var dye: Color = DYES[rng.randi() % DYES.size()]
		cols[cat] = dye.lerp(base, 0.35 if cat == "Body" else 0.15) * rng.randf_range(0.85, 1.1)
	cols["Feet"] = (cols["Feet"] as Color).darkened(0.35)
	cols["Acc"] = (cols["Acc"] as Color).darkened(0.25)
	# armour and belts only from the shirt's own outfit, so they sit where they were made to
	var acc: Array = []
	var ap: Array = (ACC_F if fem else ACC_M).filter(func(a): return String(a).begins_with(body + "_"))
	for i in rng.randi() % (4 if tough else 3):
		if ap.is_empty():
			break
		var a: String = ap[rng.randi() % ap.size()]
		if not acc.has(a):
			acc.append(a)
	return {"outfit": body, "mix": mix, "cols": cols, "acc": acc, "nohood": rng.randf() < 0.6, "horns": tough and rng.randf() < 0.3}

# a whole person from the original's look (sex, clothes colour, skin, hat, coat, bulk) plus a seed that settles
# everything the original left open: outfit cut, hair, beard, hair colour, height, a second clothes tint
static func person(look: Dictionary, seed: int, role := "") -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var fem: bool = look.get("fem", false)
	var coat = look.get("coat")
	var hat = look.get("hat")
	var outfit := ""
	if fem:
		outfit = "Female_Ranger" if hat == "hood" or coat != null or rng.randf() < 0.3 else "Female_Peasant"
	else:
		match role:
			"guard", "soldier": outfit = "Male_Knight_Cloth"
			"boss": outfit = "Male_Noble"
			"robe": outfit = "Male_Wizard"
			_:
				if hat == "hood":
					outfit = "Male_Ranger"
				elif coat != null:
					outfit = ["Male_Noble", "Male_Ranger", "Male_Wizard"][rng.randi() % 3]
				elif hat == "helmet":
					outfit = "Male_Knight_Cloth"
				else:
					outfit = ["Male_Peasant", "Male_Peasant", "Male_Ranger", "Male_Noble", "Male_Ranger"][rng.randi() % 5]
	var cols: Array = npc_colors(look)
	var cloth: Color = cols[0]
	# a second hue so two people in the same colour still differ
	cloth = cloth.lerp(Color.from_hsv(rng.randf(), 0.35, 0.75), 0.18 + rng.randf() * 0.12)
	if coat != null:
		cloth = cloth.lerp(Color(coat).lightened(0.25), 0.5)
	# everyone dressed differently: parts from different outfits, each dyed its own colour
	var spec := mix_spec(rng, fem, cloth, role in ["guard", "soldier"])
	if role == "" and hat != "hood" and coat == null:
		outfit = spec.outfit
	else:
		spec.mix = {} if role != "" else spec.mix
	if hat == "hood":
		spec["nohood"] = false
	spec["grime"] = 0.35
	var m := build(outfit, cloth, cols[1], true, spec)
	var hc: Color = HAIR_COLS[rng.randi() % HAIR_COLS.size()]
	face(m, rng, hc, true)
	if rng.randf() < 0.3 and role == "":
		gear(m, rng, "settler", hat != null and hat != "")
	if not (hat in ["helmet"]) and not (hat == "hood" and outfit.ends_with("Ranger") and not spec.get("nohood", true)):
		add_hair(m, (HAIR_F if fem else HAIR_M)[rng.randi() % (HAIR_F if fem else HAIR_M).size()], hc)
	if not fem:
		add_hair(m, FACE_M[rng.randi() % FACE_M.size()], hc)
	if hat != null and hat != "hood":
		add_hat(m, String(hat), Color(0.35, 0.37, 0.36) if hat == "helmet" else (Color(0.42, 0.3, 0.18) if hat in ["wide", "sheriff"] else Color.from_hsv(rng.randf(), 0.35, 0.45)))
	var bulk := float(look.get("bulk", 1.0))
	var h := rng.randf_range(0.95, 1.05) * (0.96 if fem else 1.0)
	m.scale = Vector3(h * maxf(1.0, bulk), h * (1.0 + (bulk - 1.0) * 0.4), h * maxf(1.0, bulk))
	return m

static func npc_colors(look: Dictionary) -> Array:
	var cloth := Color(0.85, 0.8, 0.72)
	if look.get("body"):
		cloth = Color(1, 1, 1).lerp(Color(look.body).lightened(0.3), 0.6)
	var skin := Color(1.0, 0.9, 0.82)
	if look.get("skin"):
		var c := Color(look.skin)
		skin = Color(clampf(c.r / 0.62, 0.45, 1.6), clampf(c.g / 0.45, 0.4, 1.6), clampf(c.b / 0.34, 0.35, 1.6))
	return [cloth, skin]

# idles that make a crowd look like people doing things
const IDLES := ["Idle", "Idle", "Idle_FoldArms", "Idle", "Idle_FoldArms", "Idle"]


# a hostile person as the wastes dress them (raiders, marauders, ghouls, the hill families, the machines' shells):
# type is the enemy's, p its PEOPLE entry [outfit, cloth, skin]
const ENEMY_MACHINES := ["synth", "guardbot", "warden"]
static func enemy_person(type: String, p: Array, seed: int) -> Node3D:
	# every raider his own: cut, dye, skin, hair, beard, headgear
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var fem: bool = String(p[0]).begins_with("Female") or (type in ["raider", "jackal"] and rng.randf() < 0.25)
	var outfit: String = p[0]
	if not fem and type in ["raider", "jackal", "pyro"]:
		outfit = ["Male_Ranger", "Male_Peasant", "Male_Knight_Cloth", "Male_Ranger"][rng.randi() % 4]
	elif fem:
		outfit = "Female_Ranger" if rng.randf() < 0.6 else "Female_Peasant"
	if type in ["heavy", "guardbot", "warden"]:
		outfit = "Male_Knight_Cloth"
	elif type == "tollking":
		outfit = "Male_Noble"
	elif type == "hillfolk":
		fem = rng.randf() < 0.3
		outfit = "Female_Peasant" if fem else "Male_Peasant"
	elif type == "hill_ma":
		fem = true
	var cloth: Color = (p[1] as Color).lerp(Color.from_hsv(rng.randf(), 0.4, 0.6), 0.25) * rng.randf_range(0.8, 1.1)
	var skins := [Color(1.0, 0.86, 0.76), Color(0.85, 0.66, 0.52), Color(0.62, 0.45, 0.33), Color(0.45, 0.32, 0.24), Color(0.95, 0.78, 0.66)]
	var ghoulish: bool = type in ["ghoul", "glowhusk"]
	var skin: Color = (p[2] as Color) * rng.randf_range(0.85, 1.05) if ghoulish else skins[rng.randi() % skins.size()]
	# every raider his own outfit: shirt, trousers, boots, sleeves, belts and armour pieces from different kits
	var spec := mix_spec(rng, fem, cloth, type in ["raider", "heavy", "marauder", "tollking", "jackal", "pyro"])
	if not ghoulish and not type in ["heavy", "tollking"] and not type in ENEMY_MACHINES and not type in ["hillfolk", "hill_ma"]:
		outfit = spec.outfit
	if type in ENEMY_MACHINES:
		spec["acc"] = []
		spec["nohood"] = true
	if ghoulish:
		spec["ghoul"] = true
		spec["acc"] = []
		spec["nohood"] = true
	var wild: bool = type in ["raider", "jackal", "pyro", "marauder", "tollking", "warlord", "heavy", "sniper", "hunter", "hired"]
	if not ghoulish and not type in ENEMY_MACHINES:
		spec["grime"] = 0.9 if wild else 0.5
	var model := build(outfit, cloth, skin, true, spec)
	if type == "glowhusk":
		# they glow from the inside
		var gl := OmniLight3D.new()
		gl.light_color = Color(0.5, 1.0, 0.4)
		gl.light_energy = 0.9
		gl.omni_range = 4.0
		gl.position.y = 1.2
		model.add_child(gl)
	var hc: Color = HAIR_COLS[rng.randi() % HAIR_COLS.size()]
	var hat: String = ["", "", "cap", "wide", "helmet", ""][rng.randi() % 6] if not type in ["ghoul", "glowhusk"] else ""
	# nothing on top of a hood
	if outfit.ends_with("Ranger") and not spec.get("nohood", true):
		hat = ""
	if type == "heavy":
		hat = "helmet"
	elif type in ["hillfolk", "hill_ma"]:
		hat = ["wide", "", "wide", "cap"][rng.randi() % 4]
	elif type in ENEMY_MACHINES:
		hat = "helmet" if type != "synth" else ""
	if hat != "helmet" and not type in ["ghoul", "glowhusk"] and not type in ENEMY_MACHINES:
		add_hair(model, (HAIR_F if fem else HAIR_M)[rng.randi() % 6], hc)
	if not fem and not type in ["ghoul", "glowhusk"] and not type in ENEMY_MACHINES:
		add_hair(model, FACE_M[rng.randi() % FACE_M.size()], hc)
	if hat != "":
		add_hat(model, hat, Color(0.33, 0.34, 0.33) if hat == "helmet" else Color.from_hsv(rng.randf(), 0.3, 0.35))
	if type in ENEMY_MACHINES:
		Machine.dress(model, type)
	elif not ghoulish:
		face(model, rng, hc, not wild)
		if wild:
			gear(model, rng, "heavy" if type in ["heavy", "warlord"] else "raider", hat != "")
		elif rng.randf() < 0.4:
			gear(model, rng, "settler", hat != "")
	var hh := rng.randf_range(0.95, 1.05)
	model.scale = Vector3.ONE * hh * (1.12 if type == "heavy" else (1.15 if type == "warden" else 1.0))
	if type in ["ghoul", "glowhusk"]:
		# wasted to the bone
		model.scale = Vector3(hh * 0.88, hh * 0.98, hh * 0.88)
	return model

# ---------------------------------------------------------------- build 24: wasteland gear and faces of their own
# Pieces are placed in the model's own rest pose (standing, arms out, facing +Z) and hung on the bone that carries
# that part of the body, so they move with it.
static func _on_bone(root: Node3D, bone: String, at: Vector3, b := Basis()) -> Node3D:
	var skel := root.find_child("Skeleton3D", true, false) as Skeleton3D
	var bi := skel.find_bone(bone)
	if bi < 0:
		return null
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	skel.add_child(ba)
	var n := Node3D.new()
	n.transform = skel.get_bone_global_rest(bi).affine_inverse() * Transform3D(b, at)
	ba.add_child(n)
	return n

static func _flat(col: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	return _mat("flat_%s_%.2f_%.2f" % [col.to_html(), rough, metal], func():
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.roughness = rough
		m.metallic = metal
		return m)

static func _piece(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, sc := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = sc
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

static func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b

static func _cyl(r0: float, r1: float, h: float, seg := 10) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r0
	c.bottom_radius = r1
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c

# where the head is in the rest pose (the top of the skull, the face's front) for this body
static func _head(root: Node3D) -> Dictionary:
	var skel := root.find_child("Skeleton3D", true, false) as Skeleton3D
	var hb := skel.get_bone_global_rest(skel.find_bone("Head")).origin
	var fem := hb.y < 1.58
	return {"o": hb, "fem": fem, "k": 0.94 if fem else 1.0}

# a raider's kit: some of a gas mask, goggles, a bandana over the face, a tyre or scrap-plate pauldron with spikes,
# a bandolier, a chest plate of road signs and car doors, and war paint. kind: "raider", "settler", "heavy"
static func gear(root: Node3D, rng: RandomNumberGenerator, kind: String, hatted := false) -> void:
	var H := _head(root)
	var k: float = H.k
	var o: Vector3 = H.o
	var rust := _flat(Color(0.42, 0.24, 0.14), 0.8, 0.35)
	var steel := _flat(Color(0.36, 0.37, 0.38), 0.45, 0.7)
	var rubber := _flat(Color(0.07, 0.07, 0.07), 0.9)
	var leather := _flat(Color(0.28, 0.18, 0.11), 0.75)
	var cloth := _flat(Color.from_hsv(rng.randf(), rng.randf_range(0.15, 0.35), rng.randf_range(0.25, 0.42)), 0.95)
	var lens := _mat("lens", func():
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.25, 0.32, 0.3)
		m.metallic = 0.8
		m.roughness = 0.1
		return m)
	var face := rng.randf()
	var hp := _on_bone(root, "Head", o)
	var ring := func(parent: Node3D, r: float, w: float, mat: Material, pos: Vector3, rot: Vector3, sc := Vector3.ONE):
		var t := TorusMesh.new()
		t.inner_radius = r - w
		t.outer_radius = r
		t.rings = 20
		t.ring_segments = 6
		_piece(parent, t, mat, pos, rot, sc)
	var blob := func(parent: Node3D, rad: Vector3, mat: Material, pos: Vector3, rot := Vector3.ZERO):
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		sm.radial_segments = 14
		sm.rings = 8
		_piece(parent, sm, mat, pos, rot, rad)
	if hp and (face < 0.55):
		# a mask or a bandana over the face: no beard poking through it
		for mi in (root.find_child("Skeleton3D", true, false) as Skeleton3D).get_children():
			var nm := String(mi.name).to_lower()
			if mi is MeshInstance3D and ("beard" in nm or "moustache" in nm or "mustache" in nm):
				mi.visible = false
	if hp:
		# the head in the rest pose: its bone at the base of the skull, the eyes about 0.08 up and 0.1 forward,
		# the crown 0.21 up; everything is worn hugging that shape
		if kind == "raider" and face < 0.28:
			# a gas mask: a rubber snout over nose and mouth, a filter can, round eyepieces, and its strap
			blob.call(hp, Vector3(0.066, 0.06, 0.055) * k, rubber, Vector3(0, 0.035, 0.083) * k)
			_piece(hp, _cyl(0.032, 0.03, 0.06), steel, Vector3(0, 0.012, 0.135) * k, Vector3(PI * 0.5 + 0.45, 0, 0))
			_piece(hp, _cyl(0.034, 0.034, 0.012), rubber, Vector3(0, 0.0, 0.16) * k, Vector3(PI * 0.5 + 0.45, 0, 0))
			for sx in [-0.034, 0.034]:
				_piece(hp, _cyl(0.024, 0.026, 0.026), rubber, Vector3(sx, 0.085, 0.095) * k, Vector3(PI * 0.5, 0, 0))
				_piece(hp, _cyl(0.019, 0.019, 0.028), lens, Vector3(sx, 0.085, 0.097) * k, Vector3(PI * 0.5, 0, 0))
			ring.call(hp, 0.1 * k, 0.012, rubber, Vector3(0, 0.08, -0.005) * k, Vector3(0.15, 0, 0), Vector3(1, 1, 1.12))
		elif face < 0.55:
			# a bandana pulled up over nose and mouth, knotted behind
			blob.call(hp, Vector3(0.074, 0.046, 0.066) * k, cloth, Vector3(0, 0.032, 0.042) * k)
			blob.call(hp, Vector3(0.026, 0.018, 0.018) * k, cloth, Vector3(0, 0.05, -0.068) * k)
		if rng.randf() < (0.45 if kind == "raider" else 0.15) and face >= 0.28 and not hatted:
			# goggles pushed up on the forehead, on their strap
			ring.call(hp, 0.1 * k, 0.01, leather, Vector3(0, 0.15, 0.0) * k, Vector3(-0.12, 0, 0), Vector3(1, 1, 1.1))
			for sx in [-0.036, 0.036]:
				_piece(hp, _cyl(0.025, 0.027, 0.028), steel, Vector3(sx, 0.165, 0.098) * k, Vector3(PI * 0.5 - 0.55, 0, 0))
				_piece(hp, _cyl(0.02, 0.02, 0.03), lens, Vector3(sx, 0.167, 0.101) * k, Vector3(PI * 0.5 - 0.55, 0, 0))
	var skel := root.find_child("Skeleton3D", true, false) as Skeleton3D
	# the shoulder: half a tyre, or a plate of scrap, riding on the shoulder (on the collarbone, which doesn't swing
	# with the arm), often with bolts or spikes
	if rng.randf() < (0.65 if kind == "raider" else (0.9 if kind == "heavy" else 0.1)):
		var side := 1.0 if rng.randf() < 0.6 else -1.0
		var bone := "clavicle_l" if side > 0 else "clavicle_r"
		var ua := skel.get_bone_global_rest(skel.find_bone("upperarm_l" if side > 0 else "upperarm_r")).origin
		var sp := _on_bone(root, bone, ua + Vector3(-0.005 * side, 0.07, 0.02) * k)
		if sp:
			if rng.randf() < 0.5:
				ring.call(sp, 0.1 * k, 0.045, rubber, Vector3.ZERO, Vector3(0, 0, -0.5 * side), Vector3(1, 0.85, 1.1))
			else:
				blob.call(sp, Vector3(0.1, 0.04, 0.1) * k, rust, Vector3.ZERO, Vector3(0, 0, -0.4 * side))
				blob.call(sp, Vector3(0.085, 0.035, 0.09) * k, steel, Vector3(0.04 * side, -0.03, 0) * k, Vector3(0, 0, -0.75 * side))
			if kind != "settler":
				for i in 3:
					var c := CylinderMesh.new()
					c.top_radius = 0.0
					c.bottom_radius = 0.011
					c.height = 0.06
					c.radial_segments = 6
					_piece(sp, c, steel, Vector3((0.01 + 0.025 * i) * side, 0.05 - 0.015 * i, -0.03 + i * 0.03) * k, Vector3(0, 0, -0.5 * side))
	# across the chest: a bandolier from shoulder to hip, or a plate cut from a car door or a road sign
	var s3 := skel.get_bone_global_rest(skel.find_bone("spine_03")).origin
	var chest := _on_bone(root, "spine_03", s3)
	if chest:
		var r := rng.randf()
		if r < (0.4 if kind == "raider" else 0.2):
			var lean := 0.62
			_piece(chest, _box(Vector3(0.05, 0.5, 0.02) * k), leather, Vector3(0.0, 0.0, 0.142) * k, Vector3(0, 0, lean))
			_piece(chest, _box(Vector3(0.05, 0.5, 0.02) * k), leather, Vector3(0.0, 0.0, -0.2) * k, Vector3(0, 0, -lean))
			for i in 7:
				var t := -0.15 + i * 0.05
				_piece(chest, _box(Vector3(0.018, 0.04, 0.022) * k), _flat(Color(0.62, 0.5, 0.22), 0.4, 0.8), Vector3(-sin(lean) * t, cos(lean) * t, 0.152) * k, Vector3(0, 0, lean))
		elif r < (0.7 if kind == "raider" else (0.95 if kind == "heavy" else 0.0)):
			armour_vest(root, rng)

# a vest of scrap plate over the shirt: the shirt's own mesh blown out a finger's width along its normals (so it fits
# the body exactly and bends with it), cut off at the belt and the arms, and painted as riveted, rusted, mismatched
# plates (road signs, car doors) by a shader (build 24)
static var _vest_meshes := {}
static var _vest_sh: Shader
static func armour_vest(root: Node3D, rng: RandomNumberGenerator) -> void:
	var skel := root.find_child("Skeleton3D", true, false) as Skeleton3D
	var body: MeshInstance3D = null
	for mi in skel.find_children("*", "MeshInstance3D", false, false):
		var nm := String(mi.name)
		if (nm.ends_with("_Body") or nm.ends_with("_Body_Cloth")) and (mi as MeshInstance3D).mesh:
			body = mi
	if body == null:
		return
	var key := body.mesh.get_rid().get_id()
	if not _vest_meshes.has(key):
		var am := ArrayMesh.new()
		for si in body.mesh.get_surface_count():
			var arr: Array = body.mesh.surface_get_arrays(si)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			for i in v.size():
				v[i] += nrm[i] * 0.018
			arr[Mesh.ARRAY_VERTEX] = v
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		_vest_meshes[key] = am
	if _vest_sh == null:
		_vest_sh = Shader.new()
		_vest_sh.code = """shader_type spatial;
render_mode cull_disabled;
uniform float seed = 0.0;
varying vec3 lp;
float h(vec2 p){ return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float vn(vec2 p){ vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y); }
void vertex(){ lp = VERTEX; }
void fragment(){
	// a vest: nothing below the belt, nothing past the shoulders
	if (lp.y < 1.08 || abs(lp.x) > 0.21) { discard; }
	vec2 g = vec2(lp.x * 7.0 + (lp.z > 0.0 ? 0.0 : 3.0), lp.y * 6.0);
	vec2 cell = floor(g + vec2(0.0, step(0.5, fract(floor(g.y) * 0.5)) * 0.5));
	vec2 f = fract(g + vec2(0.0, step(0.5, fract(floor(g.y) * 0.5)) * 0.5));
	float r = h(cell + seed);
	vec3 base = r < 0.4 ? vec3(0.42, 0.24, 0.13) : (r < 0.65 ? vec3(0.36, 0.37, 0.36) : (r < 0.85 ? vec3(0.55, 0.47, 0.16) : vec3(0.2, 0.3, 0.33)));
	float rust = vn(lp.xy * 30.0 + seed) * 0.6 + vn(lp.yz * 70.0) * 0.4;
	vec3 c = mix(base, vec3(0.32, 0.16, 0.08), smoothstep(0.5, 0.8, rust) * 0.8);
	// seams between the plates, rivets at their corners
	float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	c *= mix(0.45, 1.0, smoothstep(0.0, 0.06, edge));
	float rv = length(vec2(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)) - vec2(0.12));
	c = mix(c, vec3(0.6), smoothstep(0.05, 0.02, rv) * 0.8);
	ALBEDO = c;
	METALLIC = 0.55 * (1.0 - smoothstep(0.5, 0.8, rust));
	ROUGHNESS = mix(0.45, 0.9, rust);
}"""
	var vest := MeshInstance3D.new()
	vest.name = "ScrapVest"
	vest.mesh = _vest_meshes[key]
	vest.skin = body.skin
	var m := ShaderMaterial.new()
	m.shader = _vest_sh
	m.set_shader_parameter("seed", rng.randf() * 100.0)
	vest.material_override = m
	skel.add_child(vest)
	vest.skeleton = NodePath("..")
	vest.transform = body.transform

# a face of its own: eye colour, brows the colour of the hair, sometimes a scar, freckles, a broken nose's tape,
# grey at the temples, glasses (townsfolk), for the old a greyer beard
const EYE_TINTS := [Color(1, 1, 1), Color(0.75, 0.85, 1.25), Color(0.8, 1.1, 0.85), Color(0.95, 0.95, 1.05), Color(1.1, 0.9, 0.7), Color(0.85, 0.9, 1.15)]
static func face(root: Node3D, rng: RandomNumberGenerator, hair_col: Color, townsfolk := true) -> void:
	var skel := root.find_child("Skeleton3D", true, false) as Skeleton3D
	var eye_t: Color = EYE_TINTS[rng.randi() % EYE_TINTS.size()]
	for mi in skel.find_children("*", "MeshInstance3D", false, false):
		var m := mi as MeshInstance3D
		if m.name == "Eyes":
			m.material_override = _mat("eyes_" + eye_t.to_html(), func():
				var e := StandardMaterial3D.new()
				e.albedo_texture = load("res://chars/T_Eye_Brown.png")
				e.albedo_color = eye_t
				e.roughness = 0.2
				return e)
		elif m.name == "Eyebrows":
			var bc := hair_col.darkened(0.2)
			m.material_override = _flat(bc, 0.9)
	var H := _head(root)
	var k: float = H.k
	var hp := _on_bone(root, "Head", H.o)
	if hp == null:
		return
	if rng.randf() < 0.22:
		# a scar across a cheek or through a brow
		var scar := _flat(Color(0.55, 0.3, 0.28), 0.6)
		var sx := rng.randf_range(-0.05, 0.05)
		_piece(hp, _box(Vector3(0.006, 0.05, 0.006) * k), scar, Vector3(sx, 0.07 if rng.randf() < 0.5 else 0.03, 0.085) * k, Vector3(0, 0, rng.randf_range(-0.6, 0.6)))
	if townsfolk and rng.randf() < 0.12:
		# wire glasses
		var wire := _flat(Color(0.2, 0.18, 0.15), 0.4, 0.8)
		for sx in [-0.034, 0.034]:
			var t := TorusMesh.new()
			t.inner_radius = 0.016 * k
			t.outer_radius = 0.019 * k
			t.rings = 10
			t.ring_segments = 4
			_piece(hp, t, wire, Vector3(sx, 0.084, 0.092) * k, Vector3(PI * 0.5, 0, 0))
		_piece(hp, _box(Vector3(0.016, 0.003, 0.003) * k), wire, Vector3(0, 0.088, 0.094) * k)
	if not townsfolk and rng.randf() < 0.15:
		# tape over a broken nose
		_piece(hp, _box(Vector3(0.035, 0.012, 0.006) * k), _flat(Color(0.78, 0.74, 0.62), 0.9), Vector3(0, 0.068, 0.103) * k)

# ---------------------------------------------------------------- the Visitor's people (build 24)
# A grey: a slight body in a close-fitting flight suit, grey-green skin with a dull sheen, and the head they are
# drawn with in every story: high-domed, narrow-chinned, two great black almond eyes. armoured: the wreck's sentinel,
# in a ribbed pressure suit with a glowing visor band. dead: lying as it fell.
static func alien(seed: int, armoured := false) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var root := build("Male_Peasant", Color(0.5, 0.52, 0.55), Color(0.62, 0.68, 0.62), true, {"nohood": true, "acc": []})
	var skel := root.find_child("Skeleton3D", true, false) as Skeleton3D
	var skin := _mat("alien_skin", func():
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.52, 0.58, 0.54)
		m.roughness = 0.32
		m.metallic = 0.05
		m.rim_enabled = true
		m.rim = 0.4
		return m)
	var suit := _mat("alien_suit_%s" % armoured, func():
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.3, 0.33, 0.37) if armoured else Color(0.55, 0.6, 0.64)
		m.metallic = 0.35
		m.roughness = 0.38
		return m)
	for mi in skel.find_children("*", "MeshInstance3D", false, false):
		var m := mi as MeshInstance3D
		var nm := String(m.name)
		if nm in ["Eyes", "Eyebrows"]:
			m.visible = false
			continue
		for s in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(s)
			if nm.begins_with("SuperHero") or (src and String(src.resource_name).begins_with("MI_Regular")):
				m.set_surface_override_material(s, skin)
			else:
				m.set_surface_override_material(s, suit)
		m.material_override = null
	var hb := skel.get_bone_global_rest(skel.find_bone("Head")).origin
	var hp := _on_bone(root, "Head", hb)
	if hp:
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		sm.radial_segments = 20
		sm.rings = 12
		# the cranium, swollen and domed, over the jaw that narrows to a small chin
		_piece(hp, sm, skin, Vector3(0, 0.135, 0.0), Vector3(0.15, 0, 0), Vector3(0.135, 0.15, 0.15))
		_piece(hp, sm, skin, Vector3(0, 0.035, 0.05), Vector3(-0.3, 0, 0), Vector3(0.075, 0.085, 0.08))
		var eye := _mat("alien_eye", func():
			var e := StandardMaterial3D.new()
			e.albedo_color = Color(0.02, 0.02, 0.03)
			e.metallic = 0.4
			e.roughness = 0.05
			e.clearcoat_enabled = true
			return e)
		for sx in [-1.0, 1.0]:
			_piece(hp, sm, eye, Vector3(0.05 * sx, 0.1, 0.118), Vector3(0.1, 0.35 * sx, 0.55 * sx), Vector3(0.045, 0.024, 0.02))
		# nostril slits and the line of a lipless mouth
		var dk := _flat(Color(0.25, 0.28, 0.26), 0.6)
		for sx in [-0.008, 0.008]:
			_piece(hp, _box(Vector3(0.003, 0.008, 0.003)), dk, Vector3(sx, 0.052, 0.121))
		_piece(hp, _box(Vector3(0.022, 0.002, 0.003)), dk, Vector3(0, 0.025, 0.112))
		if armoured:
			# the helmet: a smooth shell over the dome with a glowing band across the eyes
			_piece(hp, sm, suit, Vector3(0, 0.14, -0.01), Vector3(0.15, 0, 0), Vector3(0.15, 0.165, 0.165))
			var glow := _mat("alien_visor", func():
				var g := StandardMaterial3D.new()
				g.albedo_color = Color(0.3, 1.0, 0.6)
				g.emission_enabled = true
				g.emission = Color(0.25, 1.0, 0.55)
				g.emission_energy_multiplier = 2.5
				return g)
			_piece(hp, _box(Vector3(0.2, 0.035, 0.02)), glow, Vector3(0, 0.1, 0.14), Vector3(0.1, 0, 0))
	if armoured:
		# ribs on the chest and the arms of the pressure suit
		var s3 := skel.get_bone_global_rest(skel.find_bone("spine_03")).origin
		var ch := _on_bone(root, "spine_03", s3)
		if ch:
			for i in 4:
				_piece(ch, _box(Vector3(0.27, 0.02, 0.21)), suit, Vector3(0, -0.12 + i * 0.07, -0.01))
	# slight and long in the limb
	var h := rng.randf_range(0.9, 0.98)
	root.scale = Vector3(h * 0.86, h, h * 0.86)
	return root
