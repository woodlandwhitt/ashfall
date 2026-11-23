# The Ashwood's settlements and ruins (build 15): the trading town of Cinder Gap, the Ashborn tribe's walled camp,
# the fire lookout and the hermit's cabin, the ruins of Mercy Falls and its hospital, and the old drive-in. Every
# building is put together here from boxes, cylinders and cones (scripts/builds.gdshader paints the boards, tin,
# canvas, logs and concrete from world position), merged into one mesh per material per building.
#
# Buildings turn only in quarter turns, so their walls are axis-aligned boxes: those that stand on the ground go
# into the region's solid list (main builds the colliders from it, and both navigation bakers read it, so people and
# enemies walk round them and in through the doors); anything raised or sloped gets a collider of its own.
class_name Frontier
extends Node3D

# where the places are, and how far round them the forest is kept back
const SITES := {"cinder_gap": [820.0, -40.0, 62.0], "ashborn": [1310.0, -330.0, 40.0], "lookout": [990.0, -232.0, 22.0],
	"mercy_falls": [1120.0, 300.0, 64.0], "drivein": [690.0, 232.0, 38.0]}

static var _list: Array = []
static var _mats: Dictionary = {}
var main
var fires: Array = []

static func blocked(x: float, z: float) -> bool:
	for k in SITES:
		var s: Array = SITES[k]
		if Vector2(x - s[0], z - s[1]).length() < s[2]:
			return true
	return false

# ---------------------------------------------------------------- the layout
static func R(k: String, x: float, z: float, r := 0, extra := {}) -> Dictionary:
	var d := {"k": k, "x": x, "z": z, "r": r}
	d.merge(extra, true)
	return d

static func layout() -> Array:
	if not _list.is_empty():
		return _list
	var L: Array = []
	# Cinder Gap: a main street along the east road, the trading post, the Ember Room, the doctor, the town hall,
	# a market, the water tower, and a gate of scrap walls with two watchtowers on the west road in
	L.append(R("shack", 789, -53, 0, {"w": 6, "d": 5, "role": "home", "m": "plank", "roof": "tin"}))
	L.append(R("shack", 802, -54, 0, {"w": 8, "d": 6, "role": "shop", "m": "tin_teal", "roof": "tin", "sign": "PIKE'S GOODS"}))
	L.append(R("hall", 816, -56, 0, {"w": 12, "d": 9, "role": "bar", "m": "plank", "roof": "tin_red", "sign": "THE EMBER ROOM"}))
	L.append(R("shack", 832, -54, 0, {"w": 7, "d": 6, "role": "clinic", "m": "plank", "roof": "tin", "sign": "DOC SORREL"}))
	L.append(R("shack", 846, -53, 0, {"w": 6, "d": 5, "role": "home", "m": "tin", "roof": "tin_red"}))
	L.append(R("shack", 786, -28, 2, {"w": 6, "d": 5, "role": "home", "m": "tin_red", "roof": "tin"}))
	L.append(R("shack", 799, -27, 2, {"w": 8, "d": 6, "role": "office", "m": "plank", "roof": "tin", "sign": "TOWN HALL"}))
	L.append(R("stall", 825, -32, 2, {"goods": "food"}))
	L.append(R("stall", 831, -32, 2, {"goods": "scrap"}))
	L.append(R("shack", 836, -24, 2, {"w": 6, "d": 5, "role": "home", "m": "plank", "roof": "tin"}))
	L.append(R("shack", 856, -30, 2, {"w": 7, "d": 6, "role": "workshop", "m": "tin", "roof": "tin", "sign": "REPAIRS"}))
	L.append(R("water_tower", 828, -17, 0))
	L.append(R("tower", 777, -51, 0))
	L.append(R("tower", 777, -30, 0))
	L.append(R("fence", 777, -59.5, 1, {"len": 14.0}))
	L.append(R("fence", 777, -21.5, 1, {"len": 14.0}))
	L.append(R("sign", 770, -46, 1, {"text": "CINDER GAP\nTRADERS WELCOME\nRAIDERS ARE NOT"}))
	L.append(R("campfire", 808.0, -48.5, 0, {"s": 0.8}))
	L.append(R("seat", 806.5, -46.5, 1, {"id": "Rockingchair_01"}))
	L.append(R("seat", 810.0, -46.4, 3, {"id": "SchoolChair_01"}))
	L.append(R("seat", 793.0, -49.6, 0, {"id": "Rockingchair_01"}))
	L.append(R("seat", 835.2, -50.2, 0, {"id": "SchoolChair_01"}))
	L.append(R("seat", 802.0, -30.6, 2, {"id": "ArmChair_01"}))
	L.append(R("kit", 858, -63, 0, {"id": "k:q_Vehicle_Truck", "len": 6.0, "yaw": 0.4}))
	L.append(R("kit", 860, -47, 0, {"id": "k:q_Wheels_Stack", "len": 1.4}))
	L.append(R("kit", 852, -33, 0, {"id": "k:q_Barrel", "len": 0.9}))
	L.append(R("kit", 853, -34.2, 0, {"id": "k:s_barrel-open", "len": 0.9}))
	L.append(R("chest", 798.8, -54.9, 0, {"id": "cg_store", "tier": "uncommon", "owned": true}))
	L.append(R("chest", 831.2, -56.3, 0, {"id": "cg_doc", "tier": "common", "owned": true}))
	L.append(R("bench", 858.2, -28.2, 2))
	L.append(R("sign", 900, -77, 3, {"text": "LOOKOUT  1 KM\nASHBORN LAND  BEYOND"}))
	L.append(R("sign", 870, 10, 2, {"text": "MERCY FALLS  2 KM\nDON'T"}))
	L.append(R("sign", 560, -69, 1, {"text": "KETTLE PASS\nCINDER GAP  3 KM"}))
	# the Ashborn: a palisade ring with its gate to the west, hide tents round a great fire, the elders' longhouse,
	# totems, drying racks and the Ember Mother, a burnt pine hung with charms
	L.append(R("palisade", 1310, -330, 0, {"rad": 27.0, "gate": PI, "gap": 0.17}))
	for i in 7:
		var a := PI * 0.35 + i * (PI * 1.3 / 6.0)
		L.append(R("tipi", 1310 + cos(a) * 16.0, -330 + sin(a) * 16.0, 0, {"rad": 2.3 + (i % 2) * 0.4, "face": a + PI}))
	L.append(R("longhouse", 1310, -349, 0, {"w": 12, "d": 7}))
	L.append(R("campfire", 1310.0, -330.0, 0, {"s": 1.6}))
	L.append(R("totem", 1280, -334.5, 0, {"h": 4.2}))
	L.append(R("totem", 1280, -325.5, 0, {"h": 4.2}))
	L.append(R("totem", 1310, -339, 0, {"h": 5.5}))
	L.append(R("rack", 1325, -318, 1))
	L.append(R("rack", 1296, -316, 0))
	L.append(R("snag", 1329, -334, 0))
	for i in 5:
		var a := i * TAU / 5.0 + 0.3
		L.append(R("log_seat", 1310 + cos(a) * 4.2, -330 + sin(a) * 4.2, 0, {"yaw": a + PI * 0.5}))
	L.append(R("chest", 1315.2, -351.6, 0, {"id": "ab_hoard", "tier": "rare", "owned": true}))
	# the fire lookout on its hill, and the hermit's cabin under it
	L.append(R("lookout", 997, -236, 0))
	L.append(R("cabin", 981, -239, 1, {"w": 6, "d": 5}))
	L.append(R("outhouse", 976, -228, 1))
	L.append(R("kit", 985, -230, 0, {"id": "k:g_trunk", "len": 2.4, "yaw": 0.7}))
	L.append(R("kit", 987, -231, 0, {"id": "k:g_debris-wood", "len": 2.0}))
	L.append(R("seat", 984.5, -236.0, 1, {"id": "Rockingchair_01"}))
	L.append(R("campfire", 986.0, -244.0, 0, {"s": 0.6}))
	# Mercy Falls: what's left of a town on the plateau, and the hospital it was named for
	L.append(R("hospital", 1132, 314, 2, {"w": 26, "d": 16}))
	var ruins := [[1092, 300, 1], [1100, 322, 0], [1148, 285, 3], [1160, 304, 3], [1112, 270, 0], [1086, 280, 1]]
	for i in ruins.size():
		var rr: Array = ruins[i]
		L.append(R("ruin", rr[0], rr[1], rr[2], {"w": 7 + (i % 3) * 2, "d": 6 + (i % 2) * 2, "seed": i}))
	L.append(R("kit", 1108, 295, 0, {"id": "k:q_Vehicle_Sports", "len": 4.6, "yaw": 1.2, "burnt": true}))
	L.append(R("kit", 1140, 296, 0, {"id": "k:q_Vehicle_Pickup", "len": 5.2, "yaw": -0.5, "burnt": true}))
	L.append(R("kit", 1122, 330, 0, {"id": "k:q_TrafficBarrier_1", "len": 2.4, "yaw": 0.2}))
	L.append(R("kit", 1126, 331, 0, {"id": "k:q_PlasticBarrier", "len": 2.2, "yaw": -0.3}))
	L.append(R("chest", 1128.0, 321.2, 0, {"id": "mf_pharm", "tier": "rare"}))
	L.append(R("chest", 1097.0, 323.5, 0, {"id": "mf_house", "tier": "common"}))
	# the Sunset drive-in: the screen, the cars still parked facing it, the speaker posts and the snack bar
	L.append(R("screen", 690, 250, 2))
	L.append(R("shack", 676, 222, 1, {"w": 8, "d": 6, "role": "snack", "m": "tin_red", "roof": "tin", "sign": "SNACK BAR"}))
	var cars := ["k:q_Vehicle_Sports", "k:q_Vehicle_Pickup", "k:q_Vehicle_Truck"]
	for row in 2:
		for c in 5:
			if (row * 5 + c) % 3 == 1:
				continue
			L.append(R("kit", 682 + c * 5.5, 236 - row * 9.0, 0, {"id": cars[(row + c) % 3], "len": 5.0, "yaw": PI + sin(c * 2.1 + row) * 0.15, "burnt": (c + row) % 2 == 0}))
	for row in 2:
		for c in 6:
			L.append(R("post", 679.5 + c * 5.5, 236 - row * 9.0 + 2.6, 0))
	L.append(R("chest", 674.0, 220.0, 0, {"id": "di_safe", "tier": "uncommon"}))
	L.append(R("campfire", 701.0, 226.0, 0, {"s": 0.7}))
	_list = L
	return L

# ---------------------------------------------------------------- setup: solids into the region, the world objects, then the meshes
# (called by main before it builds colliders, so the walls are in the collision and the navigation from the start)
static func prepare() -> void:
	if Game.area != "world" or Game.region.get("frontier", false):
		return
	Game.region["frontier"] = true
	for d in layout():
		for s in _solids_of(d):
			Game.region.solids.append(s)
		match String(d.k):
			"chest":
				var c := {"id": String(d.id), "tier": String(d.tier), "x": float(d.x), "z": float(d.z), "y": Game.height(d.x, d.z) + 0.2}
				if d.get("owned", false):
					c["owned"] = true
				Game.W.get_or_add("chests", []).append(c)
			"bench":
				Game.W.get_or_add("benches", []).append({"x": float(d.x), "z": float(d.z), "y": Game.height(d.x, d.z)})

func setup(m) -> void:
	main = m
	for d in layout():
		var n := build(d)
		if n:
			add_child(n)
			n.global_position = Vector3(float(d.x), _ground(d), float(d.z))
			n.rotation.y = int(d.r) * PI * 0.5
			_after(n, d)

# the floor under a spot, if it's inside one of the buildings (people and things placed indoors stand on it)
static func floor_at(x: float, z: float) -> float:
	if Game.area != "world":
		return -INF
	for d in layout():
		if not String(d.k) in ["shack", "hall", "cabin", "hospital", "longhouse", "ruin", "outhouse"]:
			continue
		var w := float(d.get("w", 2.0)) * 0.5
		var dd := float(d.get("d", 2.0)) * 0.5
		if int(d.r) % 2 == 1:
			var t := w
			w = dd
			dd = t
		if absf(x - float(d.x)) < w and absf(z - float(d.z)) < dd:
			return _ground(d) + (0.12 if String(d.k) in ["hospital", "ruin"] else 0.16)
	return -INF

# the ground a building stands on: the highest point under its footprint, so no floor is ever buried
static func _ground(d: Dictionary) -> float:
	var w := float(d.get("w", 2.0)) * 0.5
	var dd := float(d.get("d", 2.0)) * 0.5
	if int(d.r) % 2 == 1:
		var t := w
		w = dd
		dd = t
	var x := float(d.x)
	var z := float(d.z)
	match String(d.k):
		"palisade", "campfire", "kit", "seat", "post", "log_seat", "chest", "bench", "sign", "snag", "totem", "tipi":
			return Game.height(x, z)
	var g := -INF
	for p in [Vector2(-w, -dd), Vector2(w, -dd), Vector2(-w, dd), Vector2(w, dd), Vector2.ZERO]:
		g = maxf(g, Game.height(x + p.x, z + p.y))
	return g

# the walls standing on the ground, as world boxes for the region's solid list [x0, x1, z0, z1, y0, y1]
static func _solids_of(d: Dictionary) -> Array:
	var kit := Kit.new()
	kit.solids_only = true
	_shape(kit, d)
	var out: Array = []
	var g := _ground(d)
	var b := Basis(Vector3.UP, int(d.r) * PI * 0.5)
	for s in kit.solids:
		var ab: AABB = s
		var lo := Vector3(INF, INF, INF)
		var hi := -lo
		for i in 8:
			var p: Vector3 = b * ab.get_endpoint(i)
			lo = lo.min(p)
			hi = hi.max(p)
		out.append([snappedf(d.x + lo.x, 0.001), snappedf(d.x + hi.x, 0.001), snappedf(d.z + lo.z, 0.001), snappedf(d.z + hi.z, 0.001), -999, snappedf(g + hi.y, 0.001)])
	return out

func build(d: Dictionary) -> Node3D:
	var k := String(d.k)
	match k:
		"campfire":
			var cf := FireFX.make(float(d.get("s", 1.0)))
			fires.append([cf, float(d.get("s", 1.0))])
			return cf
		"seat":
			return Furniture.make(String(d.id), true)
		"kit":
			var kn := Furniture.make(String(d.id), false, 0)
			var ab := Furniture.aabb(String(d.id))
			var sc := float(d.get("len", 2.0)) / maxf(0.1, maxf(ab.size.x, ab.size.z))
			for c in kn.get_children():
				(c as Node3D).scale = Vector3.ONE * sc
				for mi in (c as Node).find_children("*", "MeshInstance3D", true, false):
					(mi as MeshInstance3D).visibility_range_end = 160.0
			kn.rotation.y = float(d.get("yaw", 0.0))
			var kb := StaticBody3D.new()
			kb.collision_layer = 1
			var kcs := CollisionShape3D.new()
			var kbs := BoxShape3D.new()
			kbs.size = (ab.size * sc).max(Vector3(0.1, 0.1, 0.1))
			kcs.shape = kbs
			kcs.position = ab.get_center() * sc
			kb.add_child(kcs)
			kn.add_child(kb)
			if d.get("burnt", false):
				for mi in kn.find_children("*", "MeshInstance3D", true, false):
					(mi as MeshInstance3D).material_override = _mat("burnt")
			var holder := Node3D.new()
			holder.add_child(kn)
			return holder
		"chest":
			return Furniture.make("treasure_chest", false, 1)
		"bench":
			var fg := Forge.new()
			var bn: Node3D = fg.build("bench", -1)
			fg.free()
			return bn
	var kit := Kit.new()
	_shape(kit, d)
	var root := Node3D.new()
	root.name = "FR_" + k
	kit.commit(root)
	return root

# things added once the building stands in the world: its furniture, lights, signs, people's seats
func _after(n: Node3D, d: Dictionary) -> void:
	var k := String(d.k)
	if k == "campfire":
		n.global_position.y = Game.height(n.global_position.x, n.global_position.z)
		if main and main.town:
			main.town.add_fire(n.global_position, float(d.get("s", 1.0)))
		return
	if k == "seat" and main and main.town:
		main.town.add_piece("fr_" + str(roundi(float(d.x))), String(d.id), n)
		return
	if k == "sign":
		# a road sign reads the same from both sides
		for side in [0.0, PI]:
			var lb := Label3D.new()
			lb.text = String(d.get("text", ""))
			lb.font_size = 56
			lb.pixel_size = 0.0055
			lb.modulate = Color(0.12, 0.09, 0.07)
			lb.outline_size = 0
			lb.position = Basis(Vector3.UP, side) * Vector3(0, 1.75, 0.075)
			lb.rotation.y = side
			lb.visibility_range_end = 45.0
			n.add_child(lb)
		return
	if d.has("sign"):
		_sign_board(n, d)
	if d.has("role"):
		_furnish(n, d)

func _sign_board(n: Node3D, d: Dictionary) -> void:
	var w := float(d.get("w", 6))
	var dd := float(d.get("d", 5))
	var h := float(d.get("h", 3.4 if d.k == "hall" else 2.7))
	var lb := Label3D.new()
	lb.text = String(d.sign)
	lb.font_size = 72
	lb.pixel_size = 0.0075 if d.k == "hall" else 0.006
	lb.modulate = Color(0.93, 0.86, 0.7)
	lb.outline_modulate = Color(0.1, 0.06, 0.04)
	lb.outline_size = 10
	lb.position = Vector3(0, h + (0.75 if d.k == "hall" else 0.42), dd * 0.5 + 0.16)
	lb.visibility_range_end = 60.0
	n.add_child(lb)

# ---------------------------------------------------------------- the rooms inside
func _put(n: Node3D, id: String, at: Vector3, yaw: float, seat := false) -> Node3D:
	var f := Furniture.make(id, true)
	n.add_child(f)
	f.position = at
	f.rotation.y = yaw
	if seat and main and main.town:
		main.town.add_piece("fr_" + n.name, id, f)
	return f

func _furnish(n: Node3D, d: Dictionary) -> void:
	var w := float(d.get("w", 6))
	var dd := float(d.get("d", 5))
	var hw := w * 0.5 - 0.35
	var hd := dd * 0.5 - 0.35
	var fl := 0.16
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.78, 0.5)
	l.light_energy = 0.9
	l.omni_range = maxf(w, dd) * 0.9
	l.position = Vector3(0, float(d.get("h", 2.7)) - 0.5, 0)
	l.distance_fade_enabled = true
	l.distance_fade_begin = 40.0
	l.distance_fade_length = 10.0
	n.add_child(l)
	match String(d.role):
		"home":
			_cot(n, Vector3(-hw + 0.45, fl, -hd + 1.0), 0.0)
			_put(n, "WoodenTable_02", Vector3(hw - 0.6, fl, -hd + 0.5), 0.0)
			_put(n, "SchoolChair_01", Vector3(hw - 0.6, fl, -hd + 1.3), PI, true)
			_put(n, "Shelf_01", Vector3(hw - 0.2, fl, 0.3), -PI * 0.5)
			_put(n, "k:q_Barrel", Vector3(-hw + 0.4, fl, hd - 0.5), 0.0)
			_put(n, "Lantern_01", Vector3(hw - 0.6, fl + 0.78, -hd + 0.4), 0.0)
		"shop":
			_counter(n, Vector3(0, fl, -0.2), w - 2.4)
			_put(n, "Shelf_01", Vector3(-hw + 1.2, fl, -hd + 0.2), 0.0)
			_put(n, "Shelf_01", Vector3(hw - 1.2, fl, -hd + 0.2), 0.0)
			_put(n, "k:s_box-large", Vector3(-hw + 0.5, fl, hd - 0.6), 0.3)
			_put(n, "k:q_Barrel", Vector3(hw - 0.5, fl, hd - 0.5), 0.0)
			_put(n, "metal_jug", Vector3(-0.6, fl + 1.0, -0.2), 0.0)
			_put(n, "hanging_industrial_lamp", Vector3(0, float(d.get("h", 2.7)) + 0.1, 0.4), 0.0)
		"bar":
			_counter(n, Vector3(-1.5, fl, -hd + 1.6), 5.5)
			for i in 4:
				_put(n, "modern_bar_stool", Vector3(-3.6 + i * 1.3, fl, -hd + 2.5), PI, true)
			_put(n, "Shelf_01", Vector3(-3.0, fl, -hd + 0.2), 0.0)
			_put(n, "Shelf_01", Vector3(-0.6, fl, -hd + 0.2), 0.0)
			_put(n, "jug_01", Vector3(-2.2, fl + 1.02, -hd + 1.6), 0.0)
			_put(n, "WoodenTable_01", Vector3(3.2, fl, 0.6), PI * 0.5)
			_put(n, "SchoolChair_01", Vector3(2.2, fl, 0.6), PI * 0.5, true)
			_put(n, "SchoolChair_01", Vector3(4.2, fl, 0.6), -PI * 0.5, true)
			_put(n, "WoodenTable_02", Vector3(-3.4, fl, hd - 1.2), 0.0)
			_put(n, "GreenChair_01", Vector3(-3.4, fl, hd - 0.5), PI, true)
			_put(n, "dartboard", Vector3(hw + 0.2, 1.7, -1.5), -PI * 0.5)
			_put(n, "lantern_chandelier_01", Vector3(0.5, float(d.get("h", 3.4)) - 0.1, 0.5), 0.0)
			_put(n, "k:q_Barrel", Vector3(1.6, fl, -hd + 0.6), 0.0)
		"clinic":
			_cot(n, Vector3(-hw + 0.45, fl, -hd + 1.0), 0.0)
			_cot(n, Vector3(-hw + 0.45, fl, hd - 1.2), 0.0)
			_put(n, "WoodenTable_03", Vector3(hw - 0.7, fl, -hd + 0.6), 0.0)
			_put(n, "brass_pot_01", Vector3(hw - 0.9, fl + 0.85, -hd + 0.6), 0.0)
			_put(n, "modern_sideboard", Vector3(hw - 0.3, fl, 0.6), -PI * 0.5)
			_put(n, "SchoolChair_01", Vector3(0.4, fl, -0.4), 0.0, true)
			_put(n, "vintage_oil_lamp", Vector3(hw - 0.5, fl + 0.85, -hd + 0.8), 0.0)
		"office":
			_put(n, "modern_desk", Vector3(0, fl, -hd + 0.7), 0.0)
			_put(n, "ArmChair_01", Vector3(0, fl, -hd + 0.2), 0.0, true)
			_put(n, "modern_bookshelf", Vector3(-hw + 0.2, fl, -0.5), PI * 0.5)
			_put(n, "ClassicNightstand_01", Vector3(hw - 0.3, fl, -hd + 0.4), 0.0)
			_put(n, "fancy_picture_frame_02", Vector3(0, 1.75, -hd - 0.15), 0.0)
			_put(n, "wall_clock", Vector3(hw - 1.4, 2.0, -hd - 0.15), 0.0)
			_put(n, "SchoolChair_01", Vector3(-0.8, fl, 0.6), PI, true)
		"workshop":
			_put(n, "WoodenTable_03", Vector3(hw - 0.7, fl, -hd + 0.6), 0.0)
			_put(n, "Drill_01", Vector3(hw - 0.9, fl + 0.85, -hd + 0.6), 0.0)
			_put(n, "k:q_Wheels_Stack", Vector3(hw - 0.7, fl, hd - 0.9), 0.0)
			_put(n, "k:q_Pipes", Vector3(hw - 0.6, fl, 0.6), 0.3)
			_put(n, "caged_hanging_light", Vector3(0, float(d.get("h", 2.7)) - 0.05, 0), 0.0)
		"snack":
			_counter(n, Vector3(0, fl, 0.6), w - 2.0)
			_put(n, "Shelf_01", Vector3(0, fl, -hd + 0.2), 0.0)
			_put(n, "k:q_TrashBag_2", Vector3(hw - 0.6, fl, -hd + 0.6), 0.0)
			_put(n, "Television_01", Vector3(-1.2, fl + 1.0, 0.6), 0.0)

func _counter(n: Node3D, at: Vector3, length: float) -> void:
	var kit := Kit.new()
	kit.box("plank_dk", at + Vector3(0, 0.5, 0), Vector3(length, 1.0, 0.6), 2)
	kit.box("plank", at + Vector3(0, 1.02, 0), Vector3(length + 0.1, 0.06, 0.7), 0)
	var c := Node3D.new()
	c.name = "Counter"
	n.add_child(c)
	kit.commit(c)

func _cot(n: Node3D, at: Vector3, yaw: float) -> void:
	var kit := Kit.new()
	var b := Basis(Vector3.UP, yaw)
	kit.box("metal", at + b * Vector3(0, 0.3, 0), Vector3(0.8, 0.06, 1.9), 2)
	for c in [Vector2(-0.36, -0.9), Vector2(0.36, -0.9), Vector2(-0.36, 0.9), Vector2(0.36, 0.9)]:
		kit.box("metal", at + b * Vector3(c.x, 0.15, c.y), Vector3(0.05, 0.3, 0.05), 0)
	kit.box("mattress", at + b * Vector3(0, 0.4, 0), Vector3(0.72, 0.14, 1.8), 0)
	kit.box("mattress", at + b * Vector3(0, 0.5, -0.72), Vector3(0.5, 0.1, 0.3), 0)
	var c2 := Node3D.new()
	c2.name = "Cot"
	n.add_child(c2)
	kit.commit(c2)

# ---------------------------------------------------------------- shapes (local: origin on the ground at the middle, front to +Z)
static func _shape(kit: Kit, d: Dictionary) -> void:
	match String(d.k):
		"shack": _shack(kit, d, 2.7)
		"hall": _shack(kit, d, 3.4)
		"cabin": _cabin(kit, d)
		"stall": _stall(kit, d)
		"water_tower": _water_tower(kit)
		"tower": _watchtower(kit)
		"fence": _fence(kit, d)
		"sign": _signpost(kit)
		"palisade": _palisade(kit, d)
		"tipi": _tipi(kit, d)
		"longhouse": _longhouse(kit, d)
		"totem": _totem(kit, d)
		"rack": _rack(kit)
		"snag": _snag(kit)
		"log_seat": _log_seat(kit, d)
		"lookout": _lookout(kit)
		"outhouse": _outhouse(kit)
		"hospital": _hospital(kit, d)
		"ruin": _ruin(kit, d)
		"screen": _screen(kit)
		"post":
			kit.cyl("metal", Vector3.ZERO, 0.05, 0.05, 1.2, 6, 0)
			kit.box("metal", Vector3(0, 1.25, 0), Vector3(0.3, 0.22, 0.14), 0)

# a wall from a to b (along x or z), with openings [offset from the middle, width, bottom, top]
static func _wall(kit: Kit, m: String, a: Vector3, b: Vector3, h: float, openings: Array, t := 0.12, y0 := 0.0) -> void:
	var len := a.distance_to(b)
	var u := (b - a) / len
	var mid := (a + b) * 0.5
	var cuts: Array = []
	for o in openings:
		cuts.append([float(o[0]) - float(o[1]) * 0.5, float(o[0]) + float(o[1]) * 0.5, float(o[2]), float(o[3])])
	cuts.sort_custom(func(p, q): return p[0] < q[0])
	var s := -len * 0.5
	var size_of := func(l: float, hh: float) -> Vector3:
		return Vector3(absf(u.x) * l + absf(u.z) * t, hh, absf(u.z) * l + absf(u.x) * t)
	for c in cuts:
		if c[0] > s:
			var l: float = c[0] - s
			kit.box(m, mid + u * (s + l * 0.5) + Vector3(0, y0 + h * 0.5, 0), size_of.call(l, h))
		var cl: float = c[1] - c[0]
		var cm: float = (c[0] + c[1]) * 0.5
		if c[2] > 0.0:
			kit.box(m, mid + u * cm + Vector3(0, y0 + c[2] * 0.5, 0), size_of.call(cl, c[2]))
		if c[3] < h:
			kit.box(m, mid + u * cm + Vector3(0, y0 + (c[3] + h) * 0.5, 0), size_of.call(cl, h - c[3]))
		s = c[1]
	if s < len * 0.5:
		var l2 := len * 0.5 - s
		kit.box(m, mid + u * (s + l2 * 0.5) + Vector3(0, y0 + h * 0.5, 0), size_of.call(l2, h))

static func _shack(kit: Kit, d: Dictionary, h: float) -> void:
	var w := float(d.get("w", 6))
	var dd := float(d.get("d", 5))
	var m := String(d.get("m", "plank"))
	var roof := String(d.get("roof", "tin"))
	var hw := w * 0.5
	var hd := dd * 0.5
	var door := float(d.get("door", 0.0))
	# a concrete footing down into the ground and a board floor
	kit.box("concrete_dk", Vector3(0, -0.4, 0), Vector3(w + 0.1, 0.8, dd + 0.1), 1)
	kit.box("plank_dk", Vector3(0, 0.08, 0), Vector3(w - 0.1, 0.16, dd - 0.1), 1)
	var win := [0.0, 1.0, 1.05, 1.75]
	_wall(kit, m, Vector3(-hw, 0, -hd), Vector3(hw, 0, -hd), h, [win] if w >= 7 else [])
	_wall(kit, m, Vector3(-hw, 0, -hd + 0.06), Vector3(-hw, 0, hd - 0.06), h, [win])
	_wall(kit, m, Vector3(hw, 0, -hd + 0.06), Vector3(hw, 0, hd - 0.06), h, [win])
	var front := [[door, 1.2, 0.0, 2.15]]
	if w >= 7:
		front.append([door + (2.2 if door <= 0.0 else -2.2), 1.1, 1.05, 1.75])
	_wall(kit, m, Vector3(-hw, 0, hd), Vector3(hw, 0, hd), h, front)
	# window frames, a couple boarded over
	for wx in [[Vector3(-hw, 1.4, 0), 0], [Vector3(hw, 1.4, 0), 0]]:
		var p: Vector3 = wx[0]
		kit.box("plank_dk", p + Vector3(0, -0.38, 0), Vector3(0.2, 0.06, 1.15), 0)
		kit.box("plank_dk", p + Vector3(0, 0.38, 0), Vector3(0.2, 0.06, 1.15), 0)
	if int(d.x + d.z) % 2 == 0:
		kit.box("plank_v", Vector3(-hw - 0.07, 1.4, 0), Vector3(0.04, 0.16, 1.2), 0, Basis(Vector3.RIGHT, 0.5))
		kit.box("plank_v", Vector3(-hw - 0.07, 1.4, 0), Vector3(0.04, 0.16, 1.2), 0, Basis(Vector3.RIGHT, -0.45))
	# the roof: one slope, high at the front, eaves overhanging; a fascia board under its front edge
	var drop := 0.55
	var ang := atan2(drop, dd + 0.6)
	kit.box(roof, Vector3(0, h + 0.12 + drop * 0.5 - 0.1, 0), Vector3(w + 0.7, 0.08, sqrt(pow(dd + 0.9, 2) + drop * drop)), 0, Basis(Vector3.RIGHT, ang))
	kit.box("plank_dk", Vector3(0, h + 0.05, 0), Vector3(w, 0.1, dd), 0)
	# the roof is higher at the back: close the gap over the back wall and the triangles over the sides
	kit.box(m, Vector3(0, h + drop * 0.5 + 0.05, -hd), Vector3(w, drop + 0.1, 0.12), 0)
	for sx in [-hw, hw]:
		kit.tri3(m, Vector3(sx, h, -hd), Vector3(sx, h, hd), Vector3(sx, h + drop + 0.1, -hd))
	# the door, standing open
	var dl := Basis(Vector3.UP, -1.9)
	kit.box("plank_v", Vector3(door - 0.6, 0, hd) + dl * Vector3(0.52, 1.05, 0.03), Vector3(1.04, 2.08, 0.05), 0, dl)
	if d.k == "hall":
		# a false front: the board facade that makes a saloon a saloon, and a porch roof on posts
		kit.box(m, Vector3(0, h + 0.75, hd + 0.02), Vector3(w + 0.2, 1.5, 0.14), 0)
		kit.box("plank_dk", Vector3(0, h + 1.55, hd + 0.04), Vector3(w + 0.4, 0.12, 0.3), 0)
		kit.box("plank_dk", Vector3(0, 0.08, hd + 1.1), Vector3(w, 0.16, 2.2), 1)
		for px in [-hw + 0.2, -hw * 0.33, hw * 0.33, hw - 0.2]:
			kit.box("log", Vector3(px, 1.35, hd + 2.05), Vector3(0.16, 2.7, 0.16), 0)
		kit.box(roof, Vector3(0, 2.72, hd + 1.15), Vector3(w + 0.3, 0.07, 2.5), 0, Basis(Vector3.RIGHT, 0.12))
	else:
		# a step at the door
		kit.box("plank_dk", Vector3(door, 0.06, hd + 0.4), Vector3(1.4, 0.12, 0.7), 0)

static func _cabin(kit: Kit, d: Dictionary) -> void:
	var w := float(d.get("w", 6))
	var dd := float(d.get("d", 5))
	var hw := w * 0.5
	var hd := dd * 0.5
	var h := 2.5
	kit.box("concrete_dk", Vector3(0, -0.35, 0), Vector3(w + 0.2, 0.7, dd + 0.2), 1)
	kit.box("plank_dk", Vector3(0, 0.08, 0), Vector3(w - 0.1, 0.16, dd - 0.1), 1)
	_wall(kit, "log", Vector3(-hw, 0, -hd), Vector3(hw, 0, -hd), h, [[1.2, 0.9, 1.0, 1.7]], 0.26)
	_wall(kit, "log", Vector3(-hw, 0, -hd + 0.13), Vector3(-hw, 0, hd - 0.13), h, [], 0.26)
	_wall(kit, "log", Vector3(hw, 0, -hd + 0.13), Vector3(hw, 0, hd - 0.13), h, [[0.0, 0.9, 1.0, 1.7]], 0.26)
	_wall(kit, "log", Vector3(-hw, 0, hd), Vector3(hw, 0, hd), h, [[-0.8, 1.1, 0.0, 2.05], [1.4, 0.9, 1.0, 1.7]], 0.26)
	# gable ends and a tin roof in two slopes
	var rise := 1.4
	kit.prism("log", Vector3(0, h, -hd), w, rise, 0.26)
	kit.prism("log", Vector3(0, h, hd), w, rise, 0.26)
	var ang := atan2(rise, hw)
	var sl := sqrt(hw * hw + rise * rise) + 0.5
	kit.box("tin", Vector3(-hw * 0.5 - 0.12, h + rise * 0.5 + 0.12, 0), Vector3(sl, 0.07, dd + 0.8), 0, Basis(Vector3.BACK, ang))
	kit.box("tin", Vector3(hw * 0.5 + 0.12, h + rise * 0.5 + 0.12, 0), Vector3(sl, 0.07, dd + 0.8), 0, Basis(Vector3.BACK, -ang))
	kit.box("plank_dk", Vector3(0, h + 0.05, 0), Vector3(w - 0.3, 0.1, dd - 0.3), 0)
	# a stovepipe, a porch
	kit.cyl("metal", Vector3(hw - 1.0, h + 0.6, -0.8), 0.12, 0.12, 1.6, 8, 0)
	kit.box("plank_dk", Vector3(0, 0.08, hd + 0.9), Vector3(w, 0.16, 1.8), 1)
	var dl := Basis(Vector3.UP, -1.7)
	kit.box("plank_v", Vector3(-1.35, 0, hd) + dl * Vector3(0.5, 1.0, 0.03), Vector3(1.0, 2.0, 0.05), 0, dl)

static func _outhouse(kit: Kit) -> void:
	kit.box("plank_dk", Vector3(0, 0.06, 0), Vector3(1.3, 0.12, 1.3), 1)
	_wall(kit, "plank_v", Vector3(-0.65, 0, -0.65), Vector3(0.65, 0, -0.65), 2.2, [], 0.06)
	_wall(kit, "plank_v", Vector3(-0.65, 0, -0.62), Vector3(-0.65, 0, 0.62), 2.2, [], 0.06)
	_wall(kit, "plank_v", Vector3(0.65, 0, -0.62), Vector3(0.65, 0, 0.62), 2.2, [], 0.06)
	kit.box("plank_v", Vector3(0, 1.05, 0.66), Vector3(1.2, 2.0, 0.05), 0)
	kit.box("tin", Vector3(0, 2.3, 0), Vector3(1.6, 0.06, 1.7), 0, Basis(Vector3.RIGHT, 0.15))

static func _stall(kit: Kit, d: Dictionary) -> void:
	kit.box("plank", Vector3(0, 0.45, 0.3), Vector3(2.6, 0.9, 0.7), 1)
	kit.box("plank_dk", Vector3(0, 0.93, 0.3), Vector3(2.75, 0.06, 0.85), 0)
	for p in [Vector2(-1.3, -0.5), Vector2(1.3, -0.5), Vector2(-1.3, 0.75), Vector2(1.3, 0.75)]:
		kit.box("log", Vector3(p.x, 1.2 if p.y < 0 else 1.05, p.y), Vector3(0.1, 2.4 if p.y < 0 else 2.1, 0.1), 0)
	kit.box("canvas_red" if String(d.get("goods", "")) == "food" else "canvas", Vector3(0, 2.25, 0.15), Vector3(3.0, 0.05, 1.9), 0, Basis(Vector3.RIGHT, -0.16))
	for i in 5:
		kit.box("canvas" if i % 2 == 0 else "plank", Vector3(-1.0 + i * 0.5, 1.03, 0.3 + sin(i * 2.0) * 0.12), Vector3(0.3, 0.16, 0.25), 0)

static func _water_tower(kit: Kit) -> void:
	for p in [Vector2(-1.7, -1.7), Vector2(1.7, -1.7), Vector2(-1.7, 1.7), Vector2(1.7, 1.7)]:
		kit.box("log", Vector3(p.x, 3.5, p.y), Vector3(0.25, 7.0, 0.25), 1)
	kit.box("log", Vector3(0, 3.0, -1.7), Vector3(3.4, 0.12, 0.12), 0, Basis(Vector3.BACK, 0.9))
	kit.box("log", Vector3(0, 3.0, 1.7), Vector3(3.4, 0.12, 0.12), 0, Basis(Vector3.BACK, -0.9))
	kit.box("plank_dk", Vector3(0, 7.05, 0), Vector3(4.2, 0.14, 4.2), 2)
	kit.cyl("tin", Vector3(0, 7.1, 0), 2.1, 2.1, 3.4, 16, 2)
	kit.cone("tin_red", Vector3(0, 10.5, 0), 2.3, 0.6, 12)
	kit.box("metal", Vector3(2.15, 3.6, 0), Vector3(0.06, 7.2, 0.45), 0)

static func _watchtower(kit: Kit) -> void:
	for p in [Vector2(-1.3, -1.3), Vector2(1.3, -1.3), Vector2(-1.3, 1.3), Vector2(1.3, 1.3)]:
		kit.box("log", Vector3(p.x, 2.9, p.y), Vector3(0.2, 5.8, 0.2), 1)
	kit.box("plank_dk", Vector3(0, 4.6, 0), Vector3(3.2, 0.14, 3.2), 2)
	for s in [[Vector3(0, 5.15, -1.55), Vector3(3.2, 1.0, 0.08)], [Vector3(0, 5.15, 1.55), Vector3(3.2, 1.0, 0.08)],
			[Vector3(-1.55, 5.15, 0), Vector3(0.08, 1.0, 3.2)], [Vector3(1.55, 5.15, 0), Vector3(0.08, 1.0, 3.2)]]:
		kit.box("tin", s[0], s[1], 2)
	kit.box("tin_red", Vector3(0, 6.55, 0), Vector3(3.6, 0.07, 3.6), 0, Basis(Vector3.RIGHT, 0.12))
	kit.box("log", Vector3(0, 2.3, 1.45), Vector3(0.6, 4.6, 0.06), 0, Basis(Vector3.RIGHT, -0.12))

static func _fence(kit: Kit, d: Dictionary) -> void:
	# a run of scrap sheets nailed to posts, along local x
	var l := float(d.get("len", 10.0))
	var n := int(l / 1.8)
	for i in n:
		var x := -l * 0.5 + (i + 0.5) * l / n
		var hh := 2.2 + sin(i * 1.9 + d.x) * 0.25
		kit.box(["tin", "tin_red", "plank_v", "tin_teal"][(i + int(d.z)) % 4], Vector3(x, hh * 0.5, 0), Vector3(l / n + 0.05, hh, 0.06), 1, Basis(Vector3.FORWARD, sin(i * 3.1) * 0.03))
	for i in n + 1:
		kit.box("log", Vector3(-l * 0.5 + i * l / n, 1.25, -0.1), Vector3(0.12, 2.5, 0.12), 0)

static func _signpost(kit: Kit) -> void:
	kit.box("log", Vector3(-0.9, 1.2, 0), Vector3(0.12, 2.4, 0.12), 0)
	kit.box("log", Vector3(0.9, 1.2, 0), Vector3(0.12, 2.4, 0.12), 0)
	kit.box("plank", Vector3(0, 1.75, 0.04), Vector3(2.4, 1.1, 0.06), 0)

static func _palisade(kit: Kit, d: Dictionary) -> void:
	var rad := float(d.get("rad", 25.0))
	var gate := float(d.get("gate", PI))
	var gap := float(d.get("gap", 0.15))
	var n := int(TAU * rad / 0.42)
	var seg_start := -1
	for i in n:
		var a := i * TAU / n
		var da := wrapf(a - gate, -PI, PI)
		if absf(da) < gap:
			continue
		var p := Vector3(cos(a) * rad, 0, sin(a) * rad)
		var hh := 3.3 + sin(i * 2.7) * 0.25 + sin(i * 0.31) * 0.2
		kit.cyl("log", p + Vector3(0, -0.4, 0), 0.21, 0.19, hh + 0.4, 6, 0)
		kit.cone("log", p + Vector3(0, hh, 0), 0.19, 0.5, 6)
	# its solid: short chords round the ring
	var chords := int(TAU * rad / 2.5)
	for i in chords:
		var a0 := i * TAU / chords
		var a1 := (i + 1) * TAU / chords
		if absf(wrapf((a0 + a1) * 0.5 - gate, -PI, PI)) < gap + 0.02:
			continue
		var p0 := Vector3(cos(a0) * rad, 0, sin(a0) * rad)
		var p1 := Vector3(cos(a1) * rad, 0, sin(a1) * rad)
		var lo := p0.min(p1) - Vector3(0.2, 0, 0.2)
		var hi := p0.max(p1) + Vector3(0.2, 3.3, 0.2)
		kit.solid_box(AABB(lo, hi - lo))
	# the gate posts, taller, with skulls
	for s in [-1.0, 1.0]:
		var a: float = gate + s * (gap + 0.01)
		var p := Vector3(cos(a) * rad, 0, sin(a) * rad)
		kit.cyl("log", p, 0.3, 0.26, 4.6, 7, 0)
		kit.box("bone", p + Vector3(0, 4.75, 0), Vector3(0.32, 0.3, 0.36), 0)

static func _tipi(kit: Kit, d: Dictionary) -> void:
	var r := float(d.get("rad", 2.4))
	var h := r * 1.7
	var face := float(d.get("face", 0.0))
	kit.cone("hide", Vector3.ZERO, r, h * 0.92, 10, face)
	for i in 6:
		var a := i * TAU / 6.0 + 0.2
		var foot := Vector3(cos(a) * r * 0.97, 0, sin(a) * r * 0.97)
		var top := Vector3(cos(a) * -0.25, h * 1.12, sin(a) * -0.25)
		kit.pole("log", foot, top, 0.05)
	# the door flap, open: a dark triangle on the side it faces
	var f := Vector3(cos(face), 0, sin(face))
	var sd := Vector3(-f.z, 0, f.x)
	kit.tri3("dark", f * (r * 1.01) - sd * 0.55, f * (r * 1.01) + sd * 0.55, f * (r * 0.55) + Vector3(0, h * 0.42, 0))
	kit.solid_box(AABB(Vector3(-r * 0.75, 0, -r * 0.75), Vector3(r * 1.5, h * 0.8, r * 1.5)))
	# paint: a ring of ochre handprints
	kit.cone("ochre", Vector3(0, h * 0.55, 0), r * 0.47, h * 0.06, 10, face, true)

static func _longhouse(kit: Kit, d: Dictionary) -> void:
	var w := float(d.get("w", 12))
	var dd := float(d.get("d", 7))
	var hw := w * 0.5
	var hd := dd * 0.5
	var h := 2.4
	kit.box("plank_dk", Vector3(0, 0.08, 0), Vector3(w - 0.2, 0.16, dd - 0.2), 1)
	_wall(kit, "log", Vector3(-hw, 0, -hd), Vector3(hw, 0, -hd), h, [], 0.3)
	_wall(kit, "log", Vector3(-hw, 0, -hd + 0.15), Vector3(-hw, 0, hd - 0.15), h, [], 0.3)
	_wall(kit, "log", Vector3(hw, 0, -hd + 0.15), Vector3(hw, 0, hd - 0.15), h, [], 0.3)
	_wall(kit, "log", Vector3(-hw, 0, hd), Vector3(hw, 0, hd), h, [[0.0, 1.6, 0.0, 2.2]], 0.3)
	var rise := 2.2
	kit.prism("log", Vector3(0, h, -hd), w, rise, 0.3, true)
	kit.prism("log", Vector3(0, h, hd), w, rise, 0.3, true)
	var ang := atan2(rise, hd)
	var sl := sqrt(hd * hd + rise * rise) + 0.6
	kit.box("hide", Vector3(0, h + rise * 0.5 + 0.1, -hd * 0.5 - 0.15), Vector3(w + 1.0, 0.1, sl), 0, Basis(Vector3.RIGHT, ang))
	kit.box("hide", Vector3(0, h + rise * 0.5 + 0.1, hd * 0.5 + 0.15), Vector3(w + 1.0, 0.1, sl), 0, Basis(Vector3.RIGHT, -ang))
	kit.cyl("log", Vector3(-hw - 0.5, h + rise + 0.05, 0), 0.14, 0.14, w + 1.0, 6, 0, Basis(Vector3.BACK, -PI * 0.5))
	# horns over the door, a hide curtain pulled aside
	kit.box("bone", Vector3(0, h + 0.5, hd + 0.2), Vector3(0.5, 0.35, 0.3), 0)
	kit.box("bone", Vector3(-0.45, h + 0.7, hd + 0.2), Vector3(0.6, 0.08, 0.08), 0, Basis(Vector3.BACK, 0.6))
	kit.box("bone", Vector3(0.45, h + 0.7, hd + 0.2), Vector3(0.6, 0.08, 0.08), 0, Basis(Vector3.BACK, -0.6))
	kit.box("hide", Vector3(-0.65, 1.1, hd + 0.18), Vector3(0.5, 2.1, 0.04), 0)
	# inside: sleeping furs and a hearth stone
	for i in 4:
		kit.box("hide", Vector3(-hw + 1.6 + i * 2.6, 0.2, -hd + 1.0), Vector3(1.8, 0.08, 1.2), 0, Basis(Vector3.UP, sin(i) * 0.2))
	kit.box("concrete_dk", Vector3(0, 0.22, 0.2), Vector3(1.4, 0.14, 1.4), 0)

static func _totem(kit: Kit, d: Dictionary) -> void:
	var h := float(d.get("h", 4.5))
	kit.cyl("log", Vector3(0, -0.3, 0), 0.28, 0.24, h + 0.3, 8, 1)
	var cols := ["red", "ochre", "dark", "bone"]
	for i in int(h / 0.9):
		kit.cyl(cols[i % 4], Vector3(0, 0.5 + i * 0.9, 0), 0.3, 0.29, 0.22, 8, 0)
		kit.box("dark", Vector3(0, 0.85 + i * 0.9, 0.27), Vector3(0.24, 0.1, 0.06), 0)
	kit.box("bone", Vector3(0, h + 0.15, 0.05), Vector3(0.36, 0.32, 0.42), 0)
	kit.box("dark", Vector3(-0.09, h + 0.18, 0.27), Vector3(0.08, 0.08, 0.02), 0)
	kit.box("dark", Vector3(0.09, h + 0.18, 0.27), Vector3(0.08, 0.08, 0.02), 0)
	kit.box("bone", Vector3(-0.42, h + 0.4, 0), Vector3(0.55, 0.07, 0.07), 0, Basis(Vector3.BACK, 0.7))
	kit.box("bone", Vector3(0.42, h + 0.4, 0), Vector3(0.55, 0.07, 0.07), 0, Basis(Vector3.BACK, -0.7))

static func _rack(kit: Kit) -> void:
	for x in [-1.4, 1.4]:
		kit.box("log", Vector3(x, 1.0, 0), Vector3(0.12, 2.0, 0.12), 1)
	kit.cyl("log", Vector3(-1.6, 1.85, 0), 0.06, 0.06, 3.2, 5, 0, Basis(Vector3.BACK, -PI * 0.5))
	for i in 3:
		kit.box("hide", Vector3(-0.9 + i * 0.9, 1.25, 0), Vector3(0.75, 1.1 - (i % 2) * 0.2, 0.04), 0, Basis(Vector3.UP, sin(i * 2.0) * 0.15))

static func _snag(kit: Kit) -> void:
	kit.cyl("burnt", Vector3(0, -0.2, 0), 0.45, 0.12, 9.0, 8, 1)
	for i in 6:
		var a := i * 1.7
		var y := 3.0 + i * 0.85
		var dir := Vector3(cos(a), 0.55, sin(a)).normalized()
		kit.pole("burnt", Vector3(0, y, 0), Vector3(0, y, 0) + dir * (2.2 - i * 0.2), 0.08)
		# charms: bone and red cloth hanging from the branch ends
		var end := Vector3(0, y, 0) + dir * (1.9 - i * 0.2)
		kit.box("bone" if i % 2 == 0 else "red", end + Vector3(0, -0.4, 0), Vector3(0.12, 0.4, 0.04), 0)

static func _log_seat(kit: Kit, d: Dictionary) -> void:
	kit.cyl("log", Vector3(-0.9, 0.22, 0), 0.22, 0.22, 1.8, 7, 0, Basis(Vector3.UP, float(d.get("yaw", 0.0))) * Basis(Vector3.BACK, -PI * 0.5))

static func _lookout(kit: Kit) -> void:
	var top := 12.0
	for p in [Vector2(-2.5, -2.5), Vector2(2.5, -2.5), Vector2(-2.5, 2.5), Vector2(2.5, 2.5)]:
		kit.box("metal", Vector3(p.x, top * 0.5, p.y), Vector3(0.22, top, 0.22), 1)
	for lv in 3:
		var y := 2.0 + lv * 3.6
		for s in [-2.5, 2.5]:
			kit.box("metal", Vector3(0, y + 1.8, s), Vector3(5.4, 0.08, 0.08), 0, Basis(Vector3.FORWARD, 0.6 * (1 if lv % 2 == 0 else -1)))
			kit.box("metal", Vector3(s, y + 1.8, 0), Vector3(0.08, 0.08, 5.4), 0, Basis(Vector3.RIGHT, 0.6 * (1 if lv % 2 == 0 else -1)))
	# eight flights of stairs, back and forth, with landings at each turn
	var flights := 8
	var rise := top / flights
	for i in flights:
		var y0 := i * rise
		var zs := 0.8 if i % 2 == 0 else -0.8
		var dirx := 1.0 if i % 2 == 0 else -1.0
		var run := 3.4
		var ang := atan2(rise, run)
		var b := Basis(Vector3.BACK, ang * dirx)
		var c := Vector3(0, y0 + rise * 0.5, zs)
		kit.box("plank_dk", c, Vector3(sqrt(run * run + rise * rise), 0.1, 1.4), 2, b)
		kit.box("metal", c + Vector3(0, 0.45, zs * 0.9), Vector3(sqrt(run * run + rise * rise), 0.05, 0.05), 0, b)
		if i < flights - 1:
			kit.box("plank_dk", Vector3(2.2 * dirx, y0 + rise - 0.05, 0), Vector3(1.0, 0.1, 3.2), 2)
	# the cab: a floor with a hatch where the last flight comes up, half walls, windows all round, a pyramid roof
	kit.box("plank_dk", Vector3(0, top - 0.05, 1.3), Vector3(5.2, 0.1, 2.6), 2)
	kit.box("plank_dk", Vector3(-2.15, top - 0.05, -1.3), Vector3(0.9, 0.1, 2.6), 2)
	kit.box("plank_dk", Vector3(2.15, top - 0.05, -1.3), Vector3(0.9, 0.1, 2.6), 2)
	for s in [[Vector3(0, top + 0.5, -2.6), Vector3(5.4, 1.0, 0.1)], [Vector3(0, top + 0.5, 2.6), Vector3(5.4, 1.0, 0.1)],
			[Vector3(-2.6, top + 0.5, 0), Vector3(0.1, 1.0, 5.4)], [Vector3(2.6, top + 0.5, 0), Vector3(0.1, 1.0, 5.4)]]:
		kit.box("plank", s[0], s[1], 2)
		kit.box("glass", s[0] + Vector3(0, 0.95, 0), s[1] * Vector3(1, 0.9, 1) * Vector3(1, 1, 1) - Vector3(0, 0, 0), 0)
	for p in [Vector2(-2.6, -2.6), Vector2(2.6, -2.6), Vector2(-2.6, 2.6), Vector2(2.6, 2.6)]:
		kit.box("metal", Vector3(p.x, top + 1.25, p.y), Vector3(0.12, 2.5, 0.12), 0)
	kit.cone("tin_red", Vector3(0, top + 2.5, 0), 4.3, 1.4, 4, PI * 0.25)
	# the Osborne fire-finder on its stand in the middle of the cab
	kit.cyl("metal", Vector3(0, top, 0.9), 0.08, 0.08, 1.0, 6, 0)
	kit.cyl("metal", Vector3(0, top + 1.0, 0.9), 0.4, 0.4, 0.08, 12, 0)

static func _hospital(kit: Kit, d: Dictionary) -> void:
	var w := float(d.get("w", 26))
	var dd := float(d.get("d", 16))
	var hw := w * 0.5
	var hd := dd * 0.5
	var h := 4.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	kit.box("concrete_dk", Vector3(0, -0.3, 0), Vector3(w + 0.4, 0.6, dd + 0.4), 1)
	kit.box("concrete", Vector3(0, 0.06, 0), Vector3(w - 0.2, 0.12, dd - 0.2), 1)
	var win := func(n: int, l: float) -> Array:
		var o: Array = []
		for i in n:
			o.append([-l * 0.5 + (i + 0.5) * l / n, 1.4, 1.1, 2.6])
		return o
	var back: Array = win.call(6, w)
	_wall(kit, "concrete", Vector3(-hw, 0, -hd), Vector3(hw, 0, -hd), h, back, 0.3)
	_wall(kit, "concrete", Vector3(-hw, 0, -hd + 0.15), Vector3(-hw, 0, hd - 0.15), h, win.call(3, dd), 0.3)
	_wall(kit, "concrete", Vector3(hw, 0, -hd + 0.15), Vector3(hw, 0, hd - 0.15), h, win.call(3, dd), 0.3)
	var front: Array = win.call(6, w)
	front[2] = [front[2][0] + 1.0, 3.0, 0.0, 3.0]          # the main doors, blown in
	front.remove_at(3)
	_wall(kit, "concrete", Vector3(-hw, 0, hd), Vector3(hw, 0, hd), h, front, 0.3)
	# inner corridor walls with doorways
	_wall(kit, "concrete", Vector3(-hw + 0.3, 0, -1.5), Vector3(hw - 0.3, 0, -1.5), h, [[-8.0, 1.2, 0, 2.2], [-1.0, 1.2, 0, 2.2], [6.0, 1.2, 0, 2.2]], 0.18)
	_wall(kit, "concrete", Vector3(-4.0, 0, -hd + 0.3), Vector3(-4.0, 0, -1.6), h, [], 0.18)
	_wall(kit, "concrete", Vector3(3.0, 0, -hd + 0.3), Vector3(3.0, 0, -1.6), h, [], 0.18)
	# the upper floor fell in: what's left is a slab over the east wing and jagged stumps of wall above it
	kit.box("concrete", Vector3(hw * 0.5 + 0.5, h + 0.15, 0), Vector3(hw - 1.0, 0.3, dd - 0.6), 2)
	kit.box("concrete", Vector3(-hw + 2.5, h + 0.15, -hd + 2.0), Vector3(4.4, 0.3, 3.4), 2)
	for i in int(w / 1.3):
		var x := -hw + 0.65 + i * 1.3
		var hh := maxf(0.0, rng.randf_range(-0.8, 3.0) + (1.5 if x > 0 else -0.5))
		if hh > 0.3:
			kit.box("concrete", Vector3(x, h + 0.3 + hh * 0.5, -hd), Vector3(1.3, hh, 0.3), 0)
		var hf := maxf(0.0, rng.randf_range(-1.0, 2.6) + (1.2 if x > 0 else -0.8))
		if hf > 0.3:
			kit.box("concrete", Vector3(x, h + 0.3 + hf * 0.5, hd), Vector3(1.3, hf, 0.3), 0)
	# rebar, rubble, a red cross still on the wall, and the sign fallen across the steps
	for i in 14:
		kit.pole("metal", Vector3(rng.randf_range(-hw, hw), h + 0.3, rng.randf_range(-hd, hd) * 0.2 + (hd if i % 2 == 0 else -hd)), Vector3(rng.randf_range(-hw, hw), h + rng.randf_range(1.0, 2.4), (hd if i % 2 == 0 else -hd)), 0.02)
	for i in 22:
		var p := Vector3(rng.randf_range(-hw + 1, hw - 1), 0.25, rng.randf_range(-1.0, hd - 1.0) if i % 3 else rng.randf_range(-hd + 1, -2.0))
		kit.box("concrete_dk", p, Vector3(rng.randf_range(0.4, 1.6), rng.randf_range(0.2, 0.6), rng.randf_range(0.4, 1.4)), 0, Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3)))
	kit.box("red", Vector3(-hw + 4.5, 3.0, hd + 0.17), Vector3(1.2, 0.35, 0.04), 0)
	kit.box("red", Vector3(-hw + 4.5, 3.0, hd + 0.17), Vector3(0.35, 1.2, 0.04), 0)
	kit.box("paint", Vector3(2.0, 0.5, hd + 2.0), Vector3(6.0, 1.0, 0.12), 0, Basis(Vector3.UP, 0.15) * Basis(Vector3.RIGHT, -1.2))
	for i in 3:
		kit.box("metal", Vector3(6.0 + i * 2.4, 0.35, -hd + 1.6), Vector3(0.85, 0.06, 1.9), 0, Basis(Vector3.UP, sin(i) * 0.3) * Basis(Vector3.FORWARD, 0.2 if i == 1 else 0.0))

static func _ruin(kit: Kit, d: Dictionary) -> void:
	var w := float(d.get("w", 8))
	var dd := float(d.get("d", 6))
	var hw := w * 0.5
	var hd := dd * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = int(d.get("seed", 0)) * 7 + 3
	kit.box("concrete", Vector3(0, 0.05, 0), Vector3(w, 0.12, dd), 1)
	# walls broken into ragged columns
	var sides := [[Vector3(-hw, 0, -hd), Vector3(1, 0, 0), w], [Vector3(-hw, 0, hd), Vector3(1, 0, 0), w], [Vector3(-hw, 0, -hd), Vector3(0, 0, 1), dd], [Vector3(hw, 0, -hd), Vector3(0, 0, 1), dd]]
	for si in sides.size():
		var sd: Array = sides[si]
		var len: float = sd[2]
		var n := int(len / 0.9)
		for i in n:
			var along := (i + 0.5) * len / n
			var hh := rng.randf_range(0.2, 3.0) * (0.6 if si == 1 else 1.0)
			if si == 1 and absf(along - len * 0.5) < 0.8:
				continue
			if hh < 0.35:
				continue
			var u: Vector3 = sd[1]
			var p: Vector3 = sd[0] + u * along
			var sz := Vector3(len / n if u.x > 0 else 0.25, hh, len / n if u.z > 0 else 0.25)
			kit.box("concrete", p + Vector3(0, hh * 0.5, 0), sz, 1)
	for i in 8:
		var p := Vector3(rng.randf_range(-hw + 0.6, hw - 0.6), 0.2, rng.randf_range(-hd + 0.6, hd - 0.6))
		kit.box("concrete_dk", p, Vector3(rng.randf_range(0.3, 1.2), rng.randf_range(0.15, 0.5), rng.randf_range(0.3, 1.0)), 0, Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3)))
	for i in 3:
		kit.box("burnt", Vector3(rng.randf_range(-hw + 1, hw - 1), 0.3, rng.randf_range(-hd + 1, hd - 1)), Vector3(2.4, 0.12, 0.2), 0, Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.BACK, 0.25))

static func _screen(kit: Kit) -> void:
	for x in [-9.0, -3.0, 3.0, 9.0]:
		kit.box("metal", Vector3(x, 6.5, -0.6), Vector3(0.35, 13.0, 0.35), 1)
	for y in [4.0, 8.0, 12.0]:
		kit.box("metal", Vector3(0, y, -0.6), Vector3(18.5, 0.15, 0.15), 0)
	kit.box("paint", Vector3(0, 8.2, 0), Vector3(20.0, 9.5, 0.2), 2)
	# a bite out of the top corner where the storm took it
	kit.box("metal", Vector3(7.5, 12.8, 0.05), Vector3(4.0, 0.15, 0.24), 0, Basis(Vector3.FORWARD, 0.25))
	kit.box("concrete_dk", Vector3(0, 0.8, -0.6), Vector3(20.0, 1.6, 1.0), 1)

# ---------------------------------------------------------------- materials
static func _mat(k: String) -> Material:
	if _mats.has(k):
		return _mats[k]
	var sh := preload("res://scripts/builds.gdshader")
	var spec := {
		"plank": [0, Color(0.5, 0.39, 0.27), Color(0.36, 0.27, 0.19)], "plank_v": [1, Color(0.47, 0.36, 0.25), Color(0.34, 0.25, 0.17)],
		"plank_dk": [0, Color(0.33, 0.25, 0.18), Color(0.24, 0.18, 0.13)],
		"tin": [2, Color(0.58, 0.6, 0.61), Color(), 0.6], "tin_red": [2, Color(0.52, 0.2, 0.15), Color(), 0.5], "tin_teal": [2, Color(0.25, 0.44, 0.42), Color(), 0.45],
		"canvas": [3, Color(0.62, 0.56, 0.43), Color(0.36, 0.3, 0.22)], "canvas_red": [3, Color(0.6, 0.26, 0.2), Color(0.35, 0.2, 0.15)],
		"hide": [3, Color(0.56, 0.43, 0.31), Color(0.32, 0.23, 0.16)], "mattress": [3, Color(0.7, 0.66, 0.56), Color(0.5, 0.44, 0.36)],
		"log": [4, Color(0.42, 0.32, 0.23), Color(0.23, 0.17, 0.12)], "burnt": [4, Color(0.11, 0.1, 0.09), Color(0.05, 0.05, 0.05)],
		"concrete": [5, Color(0.47, 0.45, 0.42)], "concrete_dk": [5, Color(0.33, 0.32, 0.3)], "paint": [5, Color(0.72, 0.7, 0.65)],
	}
	var m: Material
	if spec.has(k):
		var s: Array = spec[k]
		var sm := ShaderMaterial.new()
		sm.shader = sh
		sm.set_shader_parameter("mode", s[0])
		sm.set_shader_parameter("base", s[1])
		if s.size() > 2:
			sm.set_shader_parameter("alt", s[2])
		if s.size() > 3:
			sm.set_shader_parameter("rust", s[3])
		m = sm
	else:
		var st := StandardMaterial3D.new()
		var cols := {"metal": Color(0.28, 0.28, 0.3), "bone": Color(0.84, 0.8, 0.7), "red": Color(0.5, 0.11, 0.08), "ochre": Color(0.72, 0.48, 0.16),
			"dark": Color(0.06, 0.05, 0.05), "glass": Color(0.12, 0.15, 0.16)}
		st.albedo_color = cols.get(k, Color(0.5, 0.5, 0.5))
		st.roughness = 0.2 if k == "glass" else (0.5 if k == "metal" else 0.85)
		st.metallic = 0.6 if k == "metal" else (0.3 if k == "glass" else 0.0)
		if k == "glass":
			st.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			st.albedo_color.a = 0.45
		m = st
	_mats[k] = m
	return m

# ---------------------------------------------------------------- the mesh kit: boxes, cylinders and cones merged per material
class Kit:
	var st: Dictionary = {}
	var solids: Array = []        # local AABBs standing on the ground (the region's solid list)
	var cols: Array = []          # [shape, transform] colliders of their own
	var solids_only := false

	func _s(m: String) -> SurfaceTool:
		if not st.has(m):
			var s := SurfaceTool.new()
			s.begin(Mesh.PRIMITIVE_TRIANGLES)
			st[m] = s
		return st[m]

	func solid_box(ab: AABB) -> void:
		solids.append(ab)

	# col: 0 none, 1 a ground-standing solid (or its own collider if it's off the ground), 2 its own collider
	func box(m: String, c: Vector3, size: Vector3, col := 1, b := Basis()) -> void:
		var h := size * 0.5
		if col > 0:
			var axis := b.is_equal_approx(Basis())
			if col == 1 and axis and c.y - h.y < 0.35:
				solids.append(AABB(c - h, size))
			elif not solids_only:
				var bs := BoxShape3D.new()
				bs.size = size
				cols.append([bs, Transform3D(b, c)])
		if solids_only:
			return
		var s := _s(m)
		for ax in 3:
			for sg in [-1.0, 1.0]:
				var n := Vector3.ZERO
				n[ax] = sg
				var u := Vector3.ZERO
				var v := Vector3.ZERO
				u[(ax + 1) % 3] = 1.0
				v[(ax + 2) % 3] = 1.0
				var cn := c + b * (n * h)
				var du := b * (u * h)
				var dv := b * (v * h)
				var nw := (b * n).normalized()
				var p0 := cn - du - dv
				var p1 := cn + du - dv
				var p2 := cn + du + dv
				var p3 := cn - du + dv
				Flora.tri(s, [p0, p1, p2], [nw, nw, nw], [Color.WHITE, Color.WHITE, Color.WHITE])
				Flora.tri(s, [p0, p2, p3], [nw, nw, nw], [Color.WHITE, Color.WHITE, Color.WHITE])

	func cyl(m: String, base: Vector3, r0: float, r1: float, h: float, seg: int, col := 0, b := Basis()) -> void:
		if col == 1 and b.is_equal_approx(Basis()) and base.y < 0.35:
			solids.append(AABB(base - Vector3(r0, 0, r0) * 0.8, Vector3(r0 * 1.6, h, r0 * 1.6)))
		elif col > 0 and not solids_only:
			var cs := CylinderShape3D.new()
			cs.radius = maxf(r0, r1)
			cs.height = h
			cols.append([cs, Transform3D(b, base + b * Vector3(0, h * 0.5, 0))])
		if solids_only:
			return
		var s := _s(m)
		var w := Color.WHITE
		for k in seg:
			var a0 := k * TAU / seg
			var a1 := (k + 1) * TAU / seg
			var d0 := Vector3(cos(a0), 0, sin(a0))
			var d1 := Vector3(cos(a1), 0, sin(a1))
			var n0 := b * (d0 * h + Vector3(0, r0 - r1, 0)).normalized()
			var n1 := b * (d1 * h + Vector3(0, r0 - r1, 0)).normalized()
			var b0 := base + b * (d0 * r0)
			var b1 := base + b * (d1 * r0)
			var t0 := base + b * (d0 * r1 + Vector3(0, h, 0))
			var t1 := base + b * (d1 * r1 + Vector3(0, h, 0))
			Flora.tri(s, [b0, t1, b1], [n0, n1, n1], [w, w, w])
			Flora.tri(s, [b0, t0, t1], [n0, n0, n1], [w, w, w])
			var up := b * Vector3.UP
			Flora.tri(s, [t0, t1, base + b * Vector3(0, h, 0)], [up, up, up], [w, w, w])

	func cone(m: String, base: Vector3, r: float, h: float, seg: int, rot := 0.0, band := false) -> void:
		if solids_only:
			return
		var s := _s(m)
		var w := Color.WHITE
		for k in seg:
			var a0 := rot + k * TAU / seg
			var a1 := rot + (k + 1) * TAU / seg
			var d0 := Vector3(cos(a0), 0, sin(a0))
			var d1 := Vector3(cos(a1), 0, sin(a1))
			var n0 := (d0 * h + Vector3(0, r, 0)).normalized()
			var n1 := (d1 * h + Vector3(0, r, 0)).normalized()
			if band:
				# a painted stripe just proud of a cone's surface (h is its height on the slope)
				var rr := r * 1.03
				var lift := Vector3(0, h, 0)
				var shrink := 0.88
				Flora.tri(s, [base + d0 * rr, base + d1 * rr * shrink + lift, base + d1 * rr], [n0, n1, n1], [w, w, w])
				Flora.tri(s, [base + d0 * rr, base + d0 * rr * shrink + lift, base + d1 * rr * shrink + lift], [n0, n0, n1], [w, w, w])
				continue
			Flora.tri(s, [base + d0 * r, base + Vector3(0, h, 0), base + d1 * r], [n0, (n0 + n1).normalized(), n1], [w, w, w])

	# a gable end: a triangle of wall 'thick' deep, width w, rising 'rise' above base
	func prism(m: String, base: Vector3, w: float, rise: float, thick: float, solid := false) -> void:
		if solids_only:
			return
		var s := _s(m)
		var c := Color.WHITE
		for sg in [-1.0, 1.0]:
			var z := Vector3(0, 0, sg * thick * 0.5)
			var n := Vector3(0, 0, sg)
			Flora.tri(s, [base + z + Vector3(-w * 0.5, 0, 0), base + z + Vector3(w * 0.5, 0, 0), base + z + Vector3(0, rise, 0)], [n, n, n], [c, c, c])
		var hw := w * 0.5
		for sg in [-1.0, 1.0]:
			var a := base + Vector3(sg * hw, 0, 0)
			var t := base + Vector3(0, rise, 0)
			var n := Vector3(sg * rise, hw, 0).normalized()
			var dz := Vector3(0, 0, thick * 0.5)
			Flora.tri(s, [a - dz, t - dz, t + dz], [n, n, n], [c, c, c])
			Flora.tri(s, [a - dz, t + dz, a + dz], [n, n, n], [c, c, c])

	func pole(m: String, a: Vector3, b: Vector3, r: float) -> void:
		if solids_only:
			return
		var dir := b - a
		var l := dir.length()
		var y := dir / l
		var x := y.cross(Vector3.FORWARD if absf(y.y) > 0.9 else Vector3.UP).normalized()
		var z := x.cross(y)
		cyl(m, a, r, r * 0.7, l, 5, 0, Basis(x, y, z))

	func tri3(m: String, a: Vector3, b: Vector3, c: Vector3) -> void:
		if solids_only:
			return
		var n := (b - a).cross(c - a).normalized()
		if n.dot(Vector3(a.x + b.x + c.x, 0, a.z + b.z + c.z)) < 0:
			n = -n
		var w := Color.WHITE
		Flora.tri(_s(m), [a, b, c], [n, n, n], [w, w, w])

	func commit(root: Node3D) -> void:
		for m in st:
			var s: SurfaceTool = st[m]
			var mi := MeshInstance3D.new()
			mi.name = "M_" + m
			mi.mesh = s.commit()
			mi.material_override = Frontier._mat(m)
			mi.visibility_range_end = 420.0
			mi.visibility_range_end_margin = 20.0
			root.add_child(mi)
		if cols.is_empty():
			return
		var body := StaticBody3D.new()
		body.name = "Body"
		body.collision_layer = 1
		root.add_child(body)
		for c in cols:
			var cs := CollisionShape3D.new()
			cs.shape = c[0]
			cs.transform = c[1]
			body.add_child(cs)
