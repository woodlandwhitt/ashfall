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
static func build(outfit: String, cloth: Color, skin: Color, quality_lod := true) -> Node3D:
	var root := (load("res://chars/" + outfit + ".gltf") as PackedScene).instantiate() as Node3D
	var skel := root.find_child("Skeleton3D", true, false) as Skeleton3D
	var female := outfit.begins_with("Female")
	var skin_key := "skin_%s_%s" % [female, skin.to_html()]
	var skin_mat := _mat(skin_key, func():
		var m := StandardMaterial3D.new()
		m.albedo_texture = load("res://chars/T_Regular_%s_Dark_BaseColor.png" % ("Female" if female else "Male"))
		m.normal_enabled = true
		m.normal_texture = load("res://chars/T_Regular_%s_Normal.png" % ("Female" if female else "Male"))
		m.roughness_texture = load("res://chars/T_Regular_%s_Roughness.png" % ("Female" if female else "Male"))
		m.albedo_color = skin
		return m)
	for mi in skel.find_children("*", "MeshInstance3D", false, false):
		var m := mi as MeshInstance3D
		for s in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(s)
			if src and String(src.resource_name).begins_with("MI_Regular"):
				m.set_surface_override_material(s, skin_mat)
			elif src is StandardMaterial3D:
				var key := "cloth_%s_%s" % [src.resource_name, cloth.to_html()]
				m.set_surface_override_material(s, _mat(key, func():
					var c := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
					c.albedo_color = cloth
					return c))
	# the head (and eyes, brows) moves onto the outfit's skeleton; bones are matched by name
	var head := (load("res://chars/head_%s.glb" % ("female" if female else "male")) as PackedScene).instantiate()
	var hskel := head.find_child("Skeleton3D", true, false)
	var hood := outfit.ends_with("Ranger")
	for mi in hskel.find_children("*", "MeshInstance3D", false, false):
		var m := mi as MeshInstance3D
		hskel.remove_child(m)
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
	var bb := gun_bounds(g)
	seat(root, g, PALM, grip_of(bb, fit) if gf.is_empty() else grip_fit(bb, fit, gf))
	return g

# where the support hand goes on a long gun: under the handguard, about 0.6 of the way to the muzzle
static func guard_fit(bb: AABB, fit: Basis, gf: Dictionary) -> Vector3:
	var inv := fit.orthonormalized().inverse()
	var fwd := (inv * Vector3(0, 0, -1)).normalized()
	var up := (inv * Vector3.UP).normalized()
	var c := bb.get_center()
	var half_len := absf(fwd.dot(bb.size)) * 0.5
	var half_h := absf(up.dot(bb.size)) * 0.5
	var t: Array = GRIPS.get(String(gf.get("glb", "")), [])
	var gfrac: float = t[2] if t.size() > 2 else 0.62
	return c - fwd * half_len + fwd * half_len * 2.0 * gfrac - up * half_h * 0.1

# where the hand closes on each gun, as fractions of the model: [from the back towards the muzzle, down from the top,
# the support hand's spot along the gun]. Tuned by eye with --gungrid.
const GRIPS := {
	"AssaultRifle2_2": [0.34, 0.6, 0.68], "AssaultRifle_3": [0.12, 0.6, 0.66], "Bullpup_1": [0.33, 0.6, 0.86],
	"Revolver_3": [0.22, 0.62, 0.6], "Rifle_Battle_West": [0.33, 0.68, 0.62], "SMG_Compact_West": [0.57, 0.66, 0.82],
	"Shotgun_Pump_West": [0.33, 0.62, 0.76], "Sniper_Rifle_West": [0.25, 0.68, 0.6], "SubmachineGun_3": [0.66, 0.62, 0.86],
}

static func grip_fit(bb: AABB, fit: Basis, gf: Dictionary) -> Vector3:
	var inv := fit.orthonormalized().inverse()
	var fwd := (inv * Vector3(0, 0, -1)).normalized()
	var up := (inv * Vector3.UP).normalized()
	var c := bb.get_center()
	var half_len := absf(fwd.dot(bb.size)) * 0.5
	var half_h := absf(up.dot(bb.size)) * 0.5
	var t: Array = GRIPS.get(String(gf.get("glb", "")), [])
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
			add.call(brim, Vector3(0, 0.155, 0.015))
			var crown := CylinderMesh.new()
			crown.top_radius = 0.08
			crown.bottom_radius = 0.1
			crown.height = 0.11
			add.call(crown, Vector3(0, 0.21, 0.01), Vector3.ZERO, Vector3(1, 1, 1.15))
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
			add.call(dome, Vector3(0, 0.165, 0.0), Vector3.ZERO, Vector3(1, 1, 1.1))
			var visor := BoxMesh.new()
			visor.size = Vector3(0.15, 0.01, 0.09)
			add.call(visor, Vector3(0, 0.168, 0.135), Vector3(-0.15, 0, 0))
		"helmet":
			var dome := SphereMesh.new()
			dome.radius = 0.125
			dome.height = 0.13
			dome.is_hemisphere = true
			add.call(dome, Vector3(0, 0.15, 0.0), Vector3.ZERO, Vector3(1, 1, 1.08))
			var rim := CylinderMesh.new()
			rim.top_radius = 0.135
			rim.bottom_radius = 0.135
			rim.height = 0.012
			add.call(rim, Vector3(0, 0.15, 0.0), Vector3.ZERO, Vector3(1, 1, 1.08))
	for c in hat.get_children():
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

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
					outfit = ["Male_Peasant", "Male_Peasant", "Male_Ranger", "Male_Noble", "Male_Knight_Cloth"][rng.randi() % 5]
	var cols: Array = npc_colors(look)
	var cloth: Color = cols[0]
	# a second hue so two people in the same colour still differ
	cloth = cloth.lerp(Color.from_hsv(rng.randf(), 0.35, 0.75), 0.18 + rng.randf() * 0.12)
	if coat != null:
		cloth = cloth.lerp(Color(coat).lightened(0.25), 0.5)
	var m := build(outfit, cloth, cols[1])
	var hc: Color = HAIR_COLS[rng.randi() % HAIR_COLS.size()]
	if not (hat in ["helmet"]) and not (hat == "hood" and outfit.ends_with("Ranger")):
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
