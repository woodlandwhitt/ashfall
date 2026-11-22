# The photoscanned furniture (Poly Haven, CC0; props/*.glb): one catalogue for furnishing the town's rooms, Haven 12
# and Forge mode. Each piece comes with a collision box from its own bounds and sits on whatever it's placed on.
class_name Furniture

# id: [display name, group, solid]
const CAT := {
	"WoodenTable_01": ["Long table", "Tables", true], "WoodenTable_03": ["Work table", "Tables", true], "WoodenTable_02": ["Side table", "Tables", true],
	"CoffeeTable_01": ["Coffee table", "Tables", true], "modern_desk": ["Desk", "Tables", true], "ClassicConsole_01": ["Console table", "Tables", true],
	"ArmChair_01": ["Armchair", "Seats", true], "GreenChair_01": ["Green chair", "Seats", true], "SchoolChair_01": ["School chair", "Seats", true],
	"Rockingchair_01": ["Rocking chair", "Seats", true], "Sofa_01": ["Sofa", "Seats", true], "Ottoman_01": ["Ottoman", "Seats", true],
	"modern_bar_stool": ["Bar stool", "Seats", true], "BarberShopChair_01": ["Barber's chair", "Seats", true],
	"Shelf_01": ["Shelf", "Storage", true], "modern_bookshelf": ["Bookshelf", "Storage", true], "modern_wardrobe": ["Wardrobe", "Storage", true],
	"modern_sideboard": ["Sideboard", "Storage", true], "ClassicNightstand_01": ["Nightstand", "Storage", true], "treasure_chest": ["Old chest", "Storage", true],
	"Television_01": ["Television", "Clutter", false], "book_encyclopedia_set_01": ["Books", "Clutter", false], "chess_set": ["Chess set", "Clutter", false],
	"metal_jug": ["Metal jug", "Clutter", false], "jug_01": ["Clay jug", "Clutter", false], "brass_pot_01": ["Brass pot", "Clutter", false],
	"brass_pan_01": ["Pan", "Clutter", false], "carved_wooden_plate": ["Plate", "Clutter", false], "wooden_bowl_01": ["Bowl", "Clutter", false],
	"ceramic_pot": ["Planter", "Clutter", false], "ceramic_vase_02": ["Vase", "Clutter", false], "antique_ceramic_vase_01": ["Old vase", "Clutter", false],
	"Drill_01": ["Drill", "Clutter", false], "portable_searchlight": ["Flashlight", "Clutter", false],
	"dartboard": ["Dartboard", "Walls", false], "fancy_picture_frame_01": ["Picture", "Walls", false], "fancy_picture_frame_02": ["Portrait", "Walls", false],
	"wall_clock": ["Wall clock", "Walls", false], "vintage_telephone_wall_clock": ["Wall telephone", "Walls", false], "ornate_mirror_01": ["Mirror", "Walls", false],
	"industrial_wall_lamp": ["Wall lamp", "Lights", false], "caged_hanging_light": ["Caged light", "Lights", false], "hanging_industrial_lamp": ["Hanging lamp", "Lights", false],
	"lantern_chandelier_01": ["Chandelier", "Lights", false], "vintage_oil_lamp": ["Oil lamp", "Lights", false], "wooden_lantern_01": ["Lantern", "Lights", false],
	"Lantern_01": ["Small lantern", "Lights", false],
	# the wasteland kit (Quaternius and Kenney, CC0): junk that piles up in storerooms and workshops
	"k:q_Barrel": ["Barrel", "Junk", true], "k:s_barrel-open": ["Open barrel", "Junk", true], "k:s_box-large": ["Big crate", "Junk", true],
	"k:q_Pallet_Broken": ["Broken pallet", "Junk", false], "k:q_Wheels_Stack": ["Tyre stack", "Junk", true], "k:q_TrashBag_1": ["Rubbish bag", "Junk", false],
	"k:q_TrashBag_2": ["Rubbish bags", "Junk", false], "k:q_CinderBlock": ["Cinder block", "Junk", false], "k:q_Pipes": ["Pipes", "Junk", false],
	"k:g_debris-wood": ["Planks", "Junk", false], "k:g_shovel-dirt": ["Shovel", "Junk", false], "k:g_lantern-candle": ["Candle lantern", "Lights", false],
	"k:q_Couch": ["Old couch", "Seats", true],
}
const LIGHTS := {"industrial_wall_lamp": [Color(1.0, 0.82, 0.6), 1.4, 5.0, Vector3(0, 0, 0.12)], "caged_hanging_light": [Color(1.0, 0.86, 0.65), 1.8, 7.0, Vector3(0, -0.5, 0)],
	"hanging_industrial_lamp": [Color(1.0, 0.85, 0.62), 2.2, 9.0, Vector3(0, -1.2, 0)], "lantern_chandelier_01": [Color(1.0, 0.75, 0.45), 2.0, 9.0, Vector3(0, -0.6, 0)],
	"vintage_oil_lamp": [Color(1.0, 0.68, 0.35), 0.9, 4.0, Vector3(0, 0.45, 0)], "wooden_lantern_01": [Color(1.0, 0.7, 0.4), 0.8, 4.0, Vector3(0, 0.3, 0)],
	"Lantern_01": [Color(1.0, 0.7, 0.4), 0.6, 3.0, Vector3(0, 0.15, 0)]}

static var scenes: Dictionary = {}
static var bounds: Dictionary = {}

static var kit: Node3D
static func scene(id: String) -> PackedScene:
	if id.begins_with("k:"):
		if not scenes.has(id):
			if kit == null:
				var ks := load("res://props/wasteland_kit.glb") as PackedScene
				kit = ks.instantiate() if ks else null
			var src: Node = kit.find_child(id.substr(2), true, false) if kit else null
			if src:
				var copy := src.duplicate()
				(copy as Node3D).transform = Transform3D.IDENTITY
				# the Kenney pieces are modelled small; the Quaternius ones are already life size
				if id.substr(2).begins_with("s_") or id.substr(2).begins_with("g_"):
					(copy as Node3D).scale = Vector3.ONE * 2.6
				var holder := Node3D.new()
				holder.add_child(copy)
				copy.owner = holder
				for c in copy.find_children("*", "", true, false):
					c.owner = holder
				var ps := PackedScene.new()
				ps.pack(holder)
				holder.free()
				scenes[id] = ps
			else:
				scenes[id] = null
		return scenes[id]
	if not scenes.has(id):
		var p := "res://props/%s.glb" % id
		scenes[id] = load(p) if ResourceLoader.exists(p) else null
	return scenes[id]

# the piece's own bounds (local, unscaled)
static func aabb(id: String) -> AABB:
	if bounds.has(id):
		return bounds[id]
	var ab := AABB()
	var ps := scene(id)
	if ps:
		var n := ps.instantiate() as Node3D
		var first := true
		for c in n.find_children("*", "MeshInstance3D", true, false):
			var mi := c as MeshInstance3D
			var b: AABB = _local_xf(mi, n) * mi.get_aabb()
			ab = b if first else ab.merge(b)
			first = false
		n.free()
	bounds[id] = ab
	return ab

static func _local_xf(n: Node3D, root: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var x: Node = n
	while x != root and x is Node3D:
		t = (x as Node3D).transform * t
		x = x.get_parent()
	return t

# a placed piece: model, collision (if it's something you'd bump into), its lamp if it's a light
static func make(id: String, lit := true, solid_override := -1) -> Node3D:
	var root := Node3D.new()
	root.name = "f_" + id
	var ps := scene(id)
	if ps == null:
		return root
	var m := ps.instantiate() as Node3D
	root.add_child(m)
	# nothing out here is showroom-new: every piece is aged, the painted junk most of all
	Weathering.apply(m, 0.8 if id.begins_with("k:") else 0.45, false, true)
	for c in m.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		mi.visibility_range_end = 32.0
		mi.visibility_range_end_margin = 4.0
		if aabb(id).size.length() < 0.8:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var solid: bool = CAT.get(id, ["", "", false])[2] if solid_override < 0 else solid_override == 1
	if solid:
		var ab := aabb(id)
		var sb := StaticBody3D.new()
		sb.name = "Body"
		sb.collision_layer = 1
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = ab.size.max(Vector3(0.05, 0.05, 0.05))
		cs.shape = bs
		cs.position = ab.get_center()
		sb.add_child(cs)
		root.add_child(sb)
	if lit and LIGHTS.has(id):
		var L: Array = LIGHTS[id]
		var l := OmniLight3D.new()
		l.light_color = L[0]
		l.light_energy = L[1]
		l.omni_range = L[2]
		l.position = L[3]
		l.shadow_enabled = false
		l.distance_fade_enabled = true
		l.distance_fade_begin = 28.0
		l.distance_fade_length = 6.0
		root.add_child(l)
	return root

static func ids_in(group: String) -> Array:
	var out: Array = []
	for k in CAT:
		if String(CAT[k][1]) == group:
			out.append(k)
	return out
