# Furnishes the town's rooms (the cells: saloons, stores, offices, clinics, workshops, radio rooms, the lab, the
# storerooms) with the photoscanned furniture, by what kind of room it is. Big pieces go against the walls with their
# backs to them, tables stand out in the room with chairs round them, the small things go on top of the furniture,
# pictures, clocks and lamps on the walls, lights from the ceiling. Every spot is checked against the walls, the
# counters already there and everything placed so far, and the way in from the door is kept clear. The layout is
# seeded by the room, so it's the same every visit. Only the room you're in is furnished.
class_name Furnish

const ROOM_H := 3.9
# per kind: wall pieces, table sets (table, chair), clutter, wall decor, ceiling lights, how many table sets
const KIND := {
	"saloon": {"wall": ["Shelf_01", "modern_sideboard", "Sofa_01", "ClassicConsole_01", "Rockingchair_01", "modern_bookshelf"], "table": ["WoodenTable_01", "WoodenTable_03", "CoffeeTable_01"],
		"chair": ["SchoolChair_01", "GreenChair_01", "modern_bar_stool"], "clutter": ["metal_jug", "jug_01", "carved_wooden_plate", "wooden_bowl_01", "chess_set", "vintage_oil_lamp", "brass_pot_01"],
		"decor": ["dartboard", "fancy_picture_frame_02", "wall_clock", "ornate_mirror_01", "fancy_picture_frame_01", "industrial_wall_lamp"], "ceil": ["lantern_chandelier_01", "caged_hanging_light"], "sets": 4},
	"store": {"wall": ["Shelf_01", "modern_bookshelf", "Shelf_01", "modern_sideboard", "treasure_chest", "ClassicConsole_01", "k:q_Barrel", "k:s_box-large"], "table": ["WoodenTable_03"], "chair": ["Ottoman_01"],
		"clutter": ["metal_jug", "jug_01", "brass_pot_01", "brass_pan_01", "ceramic_pot", "book_encyclopedia_set_01", "portable_searchlight", "Drill_01", "Lantern_01"],
		"decor": ["wall_clock", "industrial_wall_lamp", "fancy_picture_frame_01"], "ceil": ["hanging_industrial_lamp"], "sets": 2},
	"office": {"wall": ["modern_bookshelf", "modern_wardrobe", "ClassicNightstand_01", "Shelf_01", "ClassicConsole_01", "ArmChair_01"], "table": ["modern_desk", "WoodenTable_03"],
		"chair": ["GreenChair_01", "ArmChair_01"], "clutter": ["book_encyclopedia_set_01", "Television_01", "vintage_oil_lamp", "ceramic_vase_02", "antique_ceramic_vase_01", "chess_set"],
		"decor": ["fancy_picture_frame_02", "vintage_telephone_wall_clock", "wall_clock", "fancy_picture_frame_01", "ornate_mirror_01"], "ceil": ["caged_hanging_light"], "sets": 2},
	"clinic": {"wall": ["modern_wardrobe", "Shelf_01", "ClassicNightstand_01", "modern_sideboard", "BarberShopChair_01"], "table": ["WoodenTable_03"], "chair": ["SchoolChair_01"],
		"clutter": ["metal_jug", "ceramic_vase_02", "jug_01", "book_encyclopedia_set_01", "vintage_oil_lamp", "wooden_bowl_01"],
		"decor": ["ornate_mirror_01", "wall_clock", "industrial_wall_lamp"], "ceil": ["caged_hanging_light"], "sets": 1},
	"workshop": {"wall": ["Shelf_01", "WoodenTable_03", "treasure_chest", "Shelf_01", "modern_sideboard", "k:q_Barrel", "k:q_Wheels_Stack", "k:s_box-large", "k:q_Pipes"], "table": ["WoodenTable_03", "WoodenTable_01"], "chair": ["Ottoman_01", "SchoolChair_01"],
		"clutter": ["Drill_01", "portable_searchlight", "brass_pan_01", "metal_jug", "Lantern_01", "brass_pot_01"],
		"decor": ["industrial_wall_lamp", "wall_clock"], "ceil": ["hanging_industrial_lamp"], "sets": 2},
	"tech": {"wall": ["modern_bookshelf", "ClassicConsole_01", "Shelf_01", "modern_sideboard", "k:s_box-large"], "table": ["modern_desk"], "chair": ["GreenChair_01", "SchoolChair_01"],
		"clutter": ["Television_01", "portable_searchlight", "book_encyclopedia_set_01", "Drill_01", "metal_jug"],
		"decor": ["vintage_telephone_wall_clock", "industrial_wall_lamp", "wall_clock"], "ceil": ["caged_hanging_light"], "sets": 2},
	"lab": {"wall": ["modern_bookshelf", "modern_wardrobe", "Shelf_01", "modern_sideboard", "ClassicConsole_01"], "table": ["modern_desk", "WoodenTable_03"], "chair": ["SchoolChair_01", "GreenChair_01"],
		"clutter": ["Television_01", "book_encyclopedia_set_01", "portable_searchlight", "ceramic_vase_02", "metal_jug"],
		"decor": ["wall_clock", "industrial_wall_lamp", "vintage_telephone_wall_clock"], "ceil": ["caged_hanging_light", "hanging_industrial_lamp"], "sets": 3},
	# Haven 12's rooms
	"quarters": {"wall": ["modern_wardrobe", "ClassicNightstand_01", "Shelf_01", "ArmChair_01", "Sofa_01", "modern_bookshelf"], "table": ["CoffeeTable_01", "WoodenTable_02"],
		"chair": ["GreenChair_01"], "clutter": ["book_encyclopedia_set_01", "Television_01", "ceramic_vase_02", "vintage_oil_lamp", "chess_set", "jug_01"],
		"decor": ["fancy_picture_frame_01", "fancy_picture_frame_02", "ornate_mirror_01", "wall_clock"], "ceil": [], "sets": 1},
	"classroom": {"wall": ["modern_bookshelf", "Shelf_01", "modern_sideboard", "ClassicConsole_01", "ClassicNightstand_01", "ArmChair_01"], "table": ["WoodenTable_03", "WoodenTable_03"], "chair": ["SchoolChair_01"],
		"clutter": ["book_encyclopedia_set_01", "book_encyclopedia_set_01", "ceramic_vase_02", "chess_set"], "decor": ["wall_clock", "fancy_picture_frame_01"], "ceil": [], "sets": 4},
	"security": {"wall": ["modern_wardrobe", "Shelf_01", "k:s_box-large", "modern_wardrobe", "k:q_Barrel"], "table": ["modern_desk"], "chair": ["GreenChair_01"],
		"clutter": ["Television_01", "portable_searchlight", "book_encyclopedia_set_01", "metal_jug"], "decor": ["wall_clock", "vintage_telephone_wall_clock"], "ceil": [], "sets": 1},
	"hydroponics": {"wall": ["ceramic_pot", "k:q_Barrel", "Shelf_01", "ceramic_pot", "k:s_barrel-open"], "table": ["WoodenTable_03", "WoodenTable_01"], "chair": ["Ottoman_01"],
		"clutter": ["ceramic_pot", "brass_pot_01", "jug_01", "metal_jug", "wooden_bowl_01"], "decor": ["wall_clock"], "ceil": [], "sets": 3},
	"cafeteria": {"wall": ["modern_sideboard", "Shelf_01", "ClassicConsole_01", "k:q_Barrel"], "table": ["WoodenTable_01"], "chair": ["SchoolChair_01"],
		"clutter": ["carved_wooden_plate", "wooden_bowl_01", "jug_01", "brass_pot_01", "brass_pan_01", "metal_jug"], "decor": ["wall_clock", "fancy_picture_frame_01"], "ceil": [], "sets": 2},
	"storage": {"wall": ["Shelf_01", "Shelf_01", "k:s_box-large", "k:q_Barrel", "k:s_barrel-open", "modern_wardrobe", "k:q_Wheels_Stack", "k:q_Pallet_Broken"], "table": ["WoodenTable_03"], "chair": ["Ottoman_01"],
		"clutter": ["metal_jug", "brass_pot_01", "ceramic_pot", "Lantern_01", "Drill_01", "portable_searchlight"],
		"decor": ["industrial_wall_lamp"], "ceil": ["hanging_industrial_lamp"], "sets": 1},
}

var root: Node3D
var space: PhysicsDirectSpaceState3D
var rng := RandomNumberGenerator.new()
var taken: Array = []        # Rect2 footprints already used (x, z)
var keep_clear: Array = []   # Rect2 areas that must stay walkable
var fy := -60.0
var lights := 0
var rect: Rect2

var nav_key := ""            # TownLife area the seats and work spots belong to
var kind_now := ""
var stolen_n := 0
# what's lying about in someone's room that you could pocket (build 17: there was too little to steal)
const STEALABLE := {"store": ["ammo_9", "jerky", "purified_water", "canned_beans", "duct_tape", "bobby_pin", "shells"],
	"saloon": ["prewar_cola", "jerky", "flatbread", "coffee_tin", "bobby_pin"], "clinic": ["stimpak", "radaway", "rad_tea", "purified_water"],
	"office": ["bobby_pin", "circuit", "coffee_tin", "ammo_9"], "workshop": ["gears", "circuit", "duct_tape", "scrap_metal", "cell"],
	"tech": ["circuit", "cell", "gears"], "lab": ["circuit", "radaway", "cell", "stimpak"], "storage": ["scrap_metal", "duct_tape", "canned_beans", "ammo_rifle"]}
static func room(parent: Node3D, C: Dictionary, key := "") -> Node3D:
	var f := Furnish.new()
	f.nav_key = key
	return f._build(parent, C)

# Haven 12: its rooms (found from the walls; x, z ranges relative to the vault's origin), what each one is, and the
# doorway it opens from
const VAULT_ROOMS := [[-25.75, -2.25, 1.25, 15.75, "quarters", [-3.0, 10]], [-25.75, -2.25, 16.25, 25.75, "quarters", [-3.0, 21]],
	[-25.75, -2.25, 26.25, 37.75, "classroom", [-3.0, 32]], [-25.75, -2.25, 38.25, 49.75, "clinic", [-3.0, 44]],
	[-25.75, -2.25, 50.25, 61.75, "office", [-3.0, 56]], [-25.75, -2.25, 62.25, 73.75, "security", [-3.0, 68]],
	[2.25, 25.75, 1.25, 21.75, "cafeteria", [3.0, 13]], [2.25, 25.75, 22.25, 33.75, "hydroponics", [3.0, 28]],
	[2.25, 25.75, 34.25, 49.75, "workshop", [3.0, 42]], [2.25, 25.75, 50.25, 61.75, "storage", [3.0, 56]], [2.25, 25.75, 62.25, 73.75, "quarters", [3.0, 68]]]

static func vault(parent: Node3D, origin: Vector3) -> Node3D:
	var all := Node3D.new()
	all.name = "VaultFurniture"
	parent.add_child(all)
	for i in VAULT_ROOMS.size():
		var R: Array = VAULT_ROOMS[i]
		var f := Furnish.new()
		f.no_lights = true
		f.nav_key = "vault"
		var rr := Rect2(origin.x + float(R[0]), origin.z + float(R[2]), float(R[1]) - float(R[0]), float(R[3]) - float(R[2]))
		var dp := Vector2(origin.x + float(R[5][0]), origin.z + float(R[5][1]))
		f._area(all, rr, String(R[4]), origin.y, [dp], "vault%d" % i)
	return all

var no_lights := false

func _build(parent: Node3D, C: Dictionary) -> Node3D:
	var w := float(C.W2)
	var dd := float(C.D2)
	var doors: Array = []
	var r0 := Rect2(float(C.ox) - w * 0.5 + 0.2, float(C.oz) - dd * 0.5 + 0.2, w - 0.4, dd - 0.4)
	for p in Game.W.get("points", []):
		if String(p.get("id", "")) == "cellout" and r0.grow(1.5).has_point(Vector2(float(p.x), float(p.z))):
			doors.append(Vector2(float(p.x), float(p.z)))
	if String(C.get("sign", "")) == "HANGAR 2":
		hangar = true
	return _area(parent, r0, String(C.get("kind", "office")), float(Game.L.consts.CELLS.y), doors, "room" + str(C.i))

# ---------------------------------------------------------------- Hangar 2 (build 17)
# The last relief plane out of Kestrel: it came down short and they dragged what was left inside. The fuselage lies on
# its belly with a wing sheared off, and the tail section broke away at the far end; the flight recorder lies by the
# tail, orange and blinking (until you take it). Before this the hangar was just a storeroom of shelves and the
# recorder an invisible spot on the floor.
var hangar := false
func _hangar() -> void:
	var y := fy
	var kit := Frontier.Kit.new()
	var fz := -320.0
	var fx := 2768.0
	var along := Basis(Vector3.RIGHT, PI * 0.5)       # a cylinder lying along z
	kit.cyl("tin", Vector3(fx, 1.6, fz - 8.0), 1.6, 1.6, 15.0, 18, 2, along)
	kit.cyl("tin", Vector3(fx, 1.6, fz + 7.0), 1.6, 1.1, 2.2, 18, 0, along)
	kit.cyl("dark", Vector3(fx, 1.6, fz + 9.15), 1.12, 1.12, 0.05, 18, 0, along)
	kit.box("tin_red", Vector3(fx, 1.6, fz), Vector3(3.26, 0.35, 15.0), 0)
	for i in 6:
		kit.box("glass", Vector3(fx - 1.55, 2.2, fz - 5.0 + i * 2.0), Vector3(0.06, 0.45, 0.5), 0)
		kit.box("glass", Vector3(fx + 1.55, 2.2, fz - 5.0 + i * 2.0), Vector3(0.06, 0.45, 0.5), 0)
	# the left wing, whole, and the stump of the right one; an engine fallen off on the floor
	kit.box("tin", Vector3(fx - 6.5, 1.0, fz - 1.0), Vector3(10.0, 0.28, 3.0), 2, Basis(Vector3.FORWARD, -0.06))
	kit.box("tin_red", Vector3(fx - 10.9, 1.25, fz - 1.0), Vector3(1.2, 0.3, 3.02), 0, Basis(Vector3.FORWARD, -0.06))
	kit.box("tin", Vector3(fx + 2.6, 1.15, fz - 1.0), Vector3(2.2, 0.28, 2.6), 0)
	kit.cyl("metal", Vector3(fx - 4.5, 0.75, fz - 3.6), 0.75, 0.6, 2.6, 14, 2, along)
	kit.cyl("dark", Vector3(fx - 4.5, 0.75, fz - 3.62), 0.55, 0.55, 0.05, 14, 0, along)
	kit.box("metal", Vector3(fx + 5.5, 0.55, fz + 2.0), Vector3(1.1, 1.1, 2.0), 2, Basis(Vector3.UP, 0.5))
	# the tail section, broken off near the far wall, fin up
	var tx := 2764.0
	var tz := -303.6
	kit.cyl("tin", Vector3(tx, 1.3, tz - 2.0), 1.3, 0.55, 4.0, 16, 2, along * Basis(Vector3.FORWARD, 0.0))
	kit.box("tin_red", Vector3(tx, 2.8, tz + 0.6), Vector3(0.16, 1.9, 1.8), 0, Basis(Vector3.RIGHT, -0.35))
	kit.box("tin", Vector3(tx, 1.5, tz + 1.2), Vector3(4.0, 0.12, 1.0), 0)
	kit.cyl("dark", Vector3(tx, 1.3, tz - 2.02), 1.28, 1.28, 0.04, 16, 0, along)
	# rubble of the impact, a tool cart, chocks
	for i in 6:
		kit.box("metal", Vector3(fx - 2.0 + i * 0.9, 0.12, fz + 10.5 + (i % 3) * 0.6), Vector3(0.6, 0.12, 0.9), 0, Basis(Vector3.UP, i * 0.7))
	var n := Node3D.new()
	n.name = "Hangar2"
	kit.commit(n)
	root.add_child(n)
	n.position = Vector3(0, y, 0)
	taken.append(Rect2(Vector2(fx - 12.0, fz - 9.5), Vector2(15.5, 20.0)))
	taken.append(Rect2(Vector2(fx + 1.0, fz - 9.5), Vector2(6.5, 20.0)))
	taken.append(Rect2(Vector2(tx - 2.5, tz - 4.5), Vector2(5.0, 6.5)))
	# the recorder: an orange box by the tail with a blinking beacon, gone once it's in your pack
	if not Game.has("black_box") and not Game.quests.get("black_box", {}).get("done", false):
		var bp := Vector3(2762.23, y, -306.07)
		for p in Game.W.get("points", []):
			if String(p.get("id", "")) == "blackbox":
				bp = Vector3(float(p.x), y, float(p.z))
		var box := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.45, 0.32, 0.6)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.95, 0.4, 0.05)
		mat.roughness = 0.6
		bm.material = mat
		box.mesh = bm
		box.name = "FlightRecorder"
		root.add_child(box)
		box.position = bp + Vector3(0, 0.16, 0)
		box.rotation.y = 0.4
		var beacon := OmniLight3D.new()
		beacon.light_color = Color(1.0, 0.5, 0.15)
		beacon.light_energy = 0.8
		beacon.omni_range = 3.0
		box.add_child(beacon)
		beacon.position = Vector3(0, 0.4, 0)
		var tw := beacon.create_tween().set_loops()
		tw.tween_property(beacon, "light_energy", 0.0, 0.5)
		tw.tween_property(beacon, "light_energy", 1.2, 0.5)
		taken.append(Rect2(Vector2(bp.x, bp.z) - Vector2(1.2, 1.2), Vector2(2.4, 2.4)))
		var tm := Timer.new()
		tm.wait_time = 0.4
		tm.autostart = true
		box.add_child(tm)
		tm.timeout.connect(func():
			if Game.has("black_box"):
				box.queue_free())

func _area(parent: Node3D, r0: Rect2, kind: String, floor_y: float, doors: Array, key: String) -> Node3D:
	root = Node3D.new()
	root.name = "Furnish_" + key
	parent.add_child(root)
	space = parent.get_world_3d().direct_space_state
	rng.seed = hash(key)
	fy = floor_y
	rect = r0
	var C := {"kind": kind}
	kind_now = kind
	var K: Dictionary = KIND.get(kind, KIND.office)
	# the way in: around the door, and a lane from it into the room
	for dp0 in doors:
		if true:
			var dp: Vector2 = dp0
			keep_clear.append(Rect2(dp - Vector2(2.2, 2.2), Vector2(4.4, 4.4)))
			var into := (rect.get_center() - dp).normalized()
			for k in 5:
				var c := dp + into * (1.5 + k * 1.3)
				keep_clear.append(Rect2(c - Vector2(1.0, 1.0), Vector2(2.0, 2.0)))
	# people stand where they stand: keep a little room around them
	for n in Game.region.get("npcs", []) + Game.W.get("npcs", []):
		if rect.has_point(Vector2(float(n.x), float(n.z))):
			keep_clear.append(Rect2(Vector2(float(n.x), float(n.z)) - Vector2(1.1, 1.1), Vector2(2.2, 2.2)))
	# signs and posters on the walls stay readable: nothing stands in front of them
	_find_signs(parent.get_tree().current_scene if parent.get_tree() else parent, floor_y)
	if hangar:
		_hangar()
	# where you can walk in the bare room (build 23): checked again once it's furnished, so nothing cuts off a doorway
	var t0 := Time.get_ticks_usec()
	_walk0(doors)
	var t_grid := Time.get_ticks_usec() - t0
	_walls(K)
	if String(C.get("kind", "")) in ["storage", "workshop", "store"] and not hangar:
		_aisles(K, String(C.get("kind", "")))
	_tables(K)
	if not no_lights or kind in ["storage", "workshop"]:
		_junk(String(C.get("kind", "")))
	var lost0 := _lost(_furnished()) if wg.has("r0") else -1.0
	_unblock()
	var lost1 := _lost(_furnished()) if wg.has("r0") else -1.0
	audit.append("%s %s @%s: grid %s, %.1f ms; %d pieces; cut off %.2f m2 -> %.2f m2; took out %s; doorway cells %d; %s" % [key, kind, str(rect.get_center().round()),
		("%dx%d" % [wg.nx, wg.nz]) if wg.has("nx") else "none", t_grid / 1000.0, pieces.size(), lost0, lost1, str(removed), int(wg.get("throats", 0)), String(wg.get("stat", "")) + " " + str(dropped)])
	worst = maxf(worst, lost1)
	if wg.has("r0"):
		rooms_checked += 1
	_decor(K)
	_ceiling(K)
	why = {}
	return root

var signs: Array = []   # Rect2 on the floor in front of each sign
func _find_signs(top: Node, floor_y: float) -> void:
	if top == null:
		return
	for c in top.find_children("s_*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if not mi.is_inside_tree():
			continue
		var ab: AABB = mi.global_transform * mi.get_aabb()
		var thin := minf(ab.size.x, ab.size.z)
		var wide := maxf(ab.size.x, ab.size.z)
		if thin > 0.08 or wide < 0.3 or ab.size.y < 0.15 or ab.position.y > floor_y + 2.8 or ab.end.y < floor_y + 0.5:
			continue
		var r := Rect2(ab.position.x, ab.position.z, ab.size.x, ab.size.z).grow(0.15)
		if not rect.grow(0.6).intersects(r):
			continue
		var g := r.grow_individual(1.1 if ab.size.x <= ab.size.z else 0.0, 1.1 if ab.size.x > ab.size.z else 0.0, 1.1 if ab.size.x <= ab.size.z else 0.0, 1.1 if ab.size.x > ab.size.z else 0.0)
		keep_clear.append(g)
		signs.append(g)

# ---------------------------------------------------------------- placement checks
func _footprint(id: String, pos: Vector2, yaw: float, pad := 0.05) -> Rect2:
	var ab := Furniture.aabb(id)
	var sx := ab.size.x
	var sz := ab.size.z
	if absf(sin(yaw)) > 0.7:
		var t := sx
		sx = sz
		sz = t
	return Rect2(pos - Vector2(sx, sz) * 0.5 - Vector2(pad, pad), Vector2(sx, sz) + Vector2(pad, pad) * 2.0)

static var why := {}
func _no(k: String) -> bool:
	why[k] = int(why.get(k, 0)) + 1
	return false

func _free(id: String, pos: Vector2, yaw: float, y: float, clear := true) -> bool:
	var fp := _footprint(id, pos, yaw)
	if not rect.encloses(fp):
		return _no("outside")
	for r in taken:
		if (r as Rect2).intersects(fp):
			return _no("taken")
	if clear:
		for r in keep_clear:
			if (r as Rect2).intersects(fp):
				return _no("clear")
	for r in throats:
		if (r as Rect2).intersects(fp):
			return _no("doorway")
	# the walls, counters and bits of old furniture already standing in the room
	var ab := Furniture.aabb(id)
	var q := PhysicsShapeQueryParameters3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(fp.size.x - 0.12, maxf(0.1, ab.size.y - 0.15), fp.size.y - 0.12)
	q.shape = bs
	q.transform = Transform3D(Basis(), Vector3(pos.x, y + 0.1 + bs.size.y * 0.5, pos.y))
	q.collision_mask = 1
	var hit := space.intersect_shape(q, 1)
	if not hit.is_empty():
		return _no("solid")
	return true

func _put(id: String, pos: Vector2, yaw: float, y: float, lit := false) -> Node3D:
	var n := Furniture.make(id, lit and lights < 3 and not no_lights)
	if lit and Furniture.LIGHTS.has(id) and lights < 3:
		lights += 1
	root.add_child(n)
	n.global_position = Vector3(pos.x, y, pos.y)
	n.rotation.y = yaw
	taken.append(_footprint(id, pos, yaw, 0.0))
	# a solid piece standing on the floor is something you'd have to walk round
	if y < fy + 0.3 and bool(Furniture.CAT.get(id, ["", "", false])[2]):
		var sq := absf(sin(yaw * 2.0)) > 0.2
		pieces.append([n, _footprint(id, pos, yaw, 0.12 if sq else 0.0), id])
	if nav_key != "" and TownLife.inst:
		TownLife.inst.add_piece(nav_key, id, n)
	return n

# small things on a piece of furniture: on its top, or (shelving) on its shelves, each one set down on a real
# surface of the model (Furniture.surfaces) and only where it's supported all the way under it
func _on_top(host: String, at: Vector2, yaw: float, y: float, K: Dictionary, n: int, shelves := false) -> void:
	if host in Furniture.SEATS:
		return
	var ab := Furniture.aabb(host)
	var placed: Array = []
	for i in n:
		var id: String = K.clutter[rng.randi() % K.clutter.size()]
		var cab := Furniture.aabb(id)
		if cab.size.x > ab.size.x * 0.7 or cab.size.z > ab.size.z * 0.9:
			continue
		var lv := Furniture.levels(host, cab.size.y)
		if not shelves:
			lv = lv.slice(lv.size() - 1) if not lv.is_empty() else lv
		elif not lv.is_empty() and float(lv[lv.size() - 1]) > 1.9:
			lv.pop_back()   # nothing up on top of a tall bookcase where nobody can reach it
		if lv.is_empty():
			continue
		var level: float = lv[rng.randi() % lv.size()]
		for attempt in 6:
			var lp := Vector2(rng.randf_range(ab.position.x + cab.size.x * 0.6, ab.end.x - cab.size.x * 0.6),
				rng.randf_range(ab.position.z + cab.size.z * 0.6, ab.end.z - cab.size.z * 0.6))
			var r := maxf(cab.size.x, cab.size.z) * 0.42
			var ok := true
			for o in [Vector2.ZERO, Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r)]:
				if absf(Furniture.surface_at(host, lp + o, level + 0.01) - level) > 0.025:
					ok = false
					break
			for q in placed:
				if (q as Vector2).distance_to(lp) < r + 0.08:
					ok = false
			if not ok:
				continue
			placed.append(lp)
			var w := lp.rotated(-yaw)
			# now and then it's not an ornament but something worth taking, and it belongs to somebody
			if Game.area == "cells" and STEALABLE.has(kind_now) and stolen_n < 4 and rng.randf() < 0.3 and Game.main and Game.main.objects:
				var pool: Array = STEALABLE[kind_now].filter(func(x): return Game.DB.items.has(x))
				if not pool.is_empty():
					var item: String = pool[rng.randi() % pool.size()]
					var qty := 1
					if item.begins_with("ammo") or item == "shells":
						qty = rng.randi_range(6, 14)
					var pid := "fs_%s_%d" % [root.name, stolen_n]
					stolen_n += 1
					Game.main.objects.add_pickup_now({"id": pid, "item": item, "qty": qty, "x": at.x + w.x, "z": at.y + w.y, "y": y + level, "owned": "town"})
					break
			var c := Furniture.make(id, false)
			root.add_child(c)
			c.global_position = Vector3(at.x + w.x, y + level - cab.position.y + 0.002, at.y + w.y)
			c.rotation.y = rng.randf() * TAU
			break

# ---------------------------------------------------------------- big pieces against the walls
func _walls(K: Dictionary) -> void:
	var sides := [[Vector2(rect.position.x, rect.position.y), Vector2(rect.end.x, rect.position.y), Vector2(0, 1)],
		[Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, rect.end.y), Vector2(-1, 0)],
		[Vector2(rect.end.x, rect.end.y), Vector2(rect.position.x, rect.end.y), Vector2(0, -1)],
		[Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x, rect.position.y), Vector2(1, 0)]]
	for s in sides:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var nrm: Vector2 = s[2]
		var L := a.distance_to(b)
		var dir := (b - a) / L
		var t := rng.randf_range(0.6, 2.0)
		var last := ""
		# a real room has a few pieces along a wall, not a showroom's worth
		var cap := maxi(1, int(L / (4.5 if no_lights else 3.2)))
		while t < L - 0.5 and cap > 0:
			var id: String = K.wall[rng.randi() % K.wall.size()]
			if id == last:
				id = K.wall[rng.randi() % K.wall.size()]
			var ab := Furniture.aabb(id)
			# the piece's front (+Z) faces into the room
			var yaw := atan2(nrm.x, nrm.y)
			var along := ab.size.x
			var pos := a + dir * (t + along * 0.5) + nrm * (ab.size.z * 0.5 + 0.09)
			if _free(id, pos, yaw, fy):
				_put(id, pos, yaw, fy)
				if ab.end.y < 1.3 and ab.size.x > 0.5:
					_on_top(id, pos, yaw, fy, K, rng.randi_range(0, 2))
				elif id in ["Shelf_01", "modern_bookshelf", "modern_sideboard", "ClassicConsole_01"]:
					_on_top(id, pos, yaw, fy, K, rng.randi_range(1, 2), true)
				last = id
				cap -= 1
				t += along + (rng.randf_range(1.2, 3.2) if no_lights else rng.randf_range(0.5, 1.8))
			else:
				t += 0.5

# ---------------------------------------------------------------- storerooms: rows of shelving with crates between
func _aisles(K: Dictionary, kind: String) -> void:
	var rows := 2 if rect.size.x > 14.0 else 1
	for r in rows:
		var x := rect.position.x + rect.size.x * (r + 1) / (rows + 1)
		var z := rect.position.y + 2.2
		while z < rect.end.y - 2.2:
			var id: String = ["Shelf_01", "k:s_box-large", "Shelf_01", "k:q_Barrel"][rng.randi() % 4] if kind == "storage" else ["Shelf_01", "modern_sideboard", "k:s_box-large"][rng.randi() % 3]
			var yaw := PI * 0.5 if rng.randf() < 0.5 else -PI * 0.5
			var p := Vector2(x + rng.randf_range(-0.2, 0.2), z)
			if _free(id, p, yaw, fy):
				_put(id, p, yaw, fy)
				if id == "Shelf_01":
					_on_top(id, p, yaw, fy, K, 3, true)
			z += Furniture.aabb(id).size.x + rng.randf_range(0.1, 0.6)

# ---------------------------------------------------------------- the bits on the floor that tell you nobody sweeps
func _junk(kind: String) -> void:
	var pool := ["k:q_TrashBag_1", "k:q_CinderBlock", "k:g_debris-wood", "k:q_TrashBag_2"]
	if kind in ["storage", "workshop"]:
		pool += ["k:q_Pipes", "k:g_shovel-dirt", "k:q_Pallet_Broken", "k:s_barrel-open"]
	var n := 2 + rng.randi() % 3
	var tries := 0
	while n > 0 and tries < 40:
		tries += 1
		var id: String = pool[rng.randi() % pool.size()]
		# mostly in corners and along the walls
		var cx: float = [rect.position.x + 0.6, rect.end.x - 0.6][rng.randi() % 2] if rng.randf() < 0.7 else rng.randf_range(rect.position.x + 1, rect.end.x - 1)
		var cz: float = rng.randf_range(rect.position.y + 0.6, rect.end.y - 0.6)
		var yaw := rng.randf() * TAU
		if _free(id, Vector2(cx, cz), yaw, fy):
			_put(id, Vector2(cx, cz), yaw, fy)
			n -= 1

# ---------------------------------------------------------------- the way through (build 23)
# A chair pulled out into a doorway, a sideboard across the gap to the next room: the bare room is mapped on a grid of
# spots a body fits (the walls and anything already standing there, from the physics), and once the furniture is in,
# every spot you could reach from the door before must still be reachable, round the furniture. Whatever cuts a
# stretch of floor off is taken out again, with what was standing on it.
const GC := 0.2
var pieces: Array = []    # [node, footprint Rect2, id] of every solid piece on the floor
var wg := {}              # the walk grid: origin, nx, nz, free (bare room), seeds
func _walk0(doors: Array) -> void:
	wg = {}
	if space == null:
		return
	var g := rect.grow(1.0)
	var nx := int(ceil(g.size.x / GC))
	var nz := int(ceil(g.size.y / GC))
	if nx * nz > 60000:
		return
	var free := PackedByteArray()     # nothing in the way
	free.resize(nx * nz)
	var free_w := PackedByteArray()   # no wall in the way (the old map's own chairs and crates don't count)
	free_w.resize(nx * nz)
	var props := {}                   # the old map's loose pieces (chair-sized solids) met on the way
	var by_prop := {}                 # cell -> the loose pieces that are all that's in it
	var q := PhysicsShapeQueryParameters3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.64, 1.15, 0.64)
	q.shape = bs
	q.collision_mask = 1
	for i in nx:
		for j in nz:
			var c := g.position + Vector2(i + 0.5, j + 0.5) * GC
			q.transform = Transform3D(Basis(), Vector3(c.x, fy + 0.4 + 0.575, c.y))
			# walls and fixtures only: people standing about (in a doorway, say) aren't part of the room
			var wall := false
			var mine: Array = []
			for h in space.intersect_shape(q, 6):
				if h.collider is CharacterBody3D or h.collider is RigidBody3D:
					continue
				var pk := _prop_key(h)
				if pk == "":
					wall = true
					break
				if not props.has(pk):
					props[pk] = h
				mine.append(pk)
			var k := i * nz + j
			free_w[k] = 0 if wall else 1
			free[k] = 1 if (not wall and mine.is_empty()) else 0
			if not wall and not mine.is_empty():
				by_prop[k] = mine
	wg = {"o": g.position, "nx": nx, "nz": nz, "free": free_w}
	wg["seeds"] = _seeds(free_w, doors)
	# the doorways, found from the walls alone; any of the old map's loose pieces standing in one is taken away
	# (build 23: the clinic's armchair stood square in the door to its back room)
	var rw := _reach(free_w, wg.seeds)
	_throats(free_w, rw)
	var gone := {}
	for pk in props:
		var fp := _prop_rect(props[pk])
		for tr in throats:
			if (tr as Rect2).intersects(fp):
				if _drop_prop(props[pk]):
					gone[pk] = true
				break
	for k in by_prop:
		var all_gone := true
		for pk in by_prop[k]:
			if not gone.has(pk):
				all_gone = false
		if all_gone:
			free[k] = 1
	wg.free = free
	wg.seeds = _seeds(free, doors)
	wg["props_gone"] = gone.size()
	var r0 := _reach(free, wg.seeds)
	# a room you can't get into from its edges (sealed, or a cell whose door is a teleport): from its biggest open patch
	var inside := 0
	for k in r0.size():
		if r0[k] == 1 and _in_room(k):
			inside += 1
	if inside < 6:
		var best: Array = []
		var seen := PackedByteArray()
		seen.resize(nx * nz)
		for k in nx * nz:
			if free[k] == 1 and seen[k] == 0 and _in_room(k):
				var comp := _reach(free, [k])
				var cs: Array = []
				for m in comp.size():
					if comp[m] == 1:
						seen[m] = 1
						cs.append(m)
				if cs.size() > best.size():
					best = cs
		if best.is_empty():
			wg = {}
			return
		wg.seeds = [best[0]]
		r0 = _reach(free, wg.seeds)
	wg["r0"] = r0
	var nf := 0
	var nr := 0
	for k in r0.size():
		nf += free[k]
		nr += 1 if r0[k] == 1 and _in_room(k) else 0
	wg["stat"] = "free %d reach-in %d seeds %d, old pieces out of doorways %d" % [nf, nr, wg.seeds.size(), int(wg.props_gone)]

func _seeds(free: PackedByteArray, doors: Array) -> Array:
	var nx: int = wg.nx
	var nz: int = wg.nz
	var seeds: Array = []
	for i in nx:
		for j in nz:
			var c: Vector2 = wg.o + Vector2(i + 0.5, j + 0.5) * GC
			if free[i * nz + j] == 1 and not rect.grow(-0.05).has_point(c):
				seeds.append(i * nz + j)
	for dp in doors:
		var i := int(((dp as Vector2).x - wg.o.x) / GC)
		var j := int(((dp as Vector2).y - wg.o.y) / GC)
		if i >= 0 and j >= 0 and i < nx and j < nz and free[i * nz + j] == 1:
			seeds.append(i * nz + j)
	return seeds

# one of the old map's loose pieces (a chair, a crate, a barrel: a solid no bigger than furniture, standing on the
# floor, one of many boxes in the map's collision): "" for a wall or anything else
func _prop_key(h: Dictionary) -> String:
	var co := h.collider as CollisionObject3D
	if co == null or not (co is StaticBody3D) or co.get_shape_owners().size() < 4:
		return ""
	var ow := co.shape_owner_get_owner(co.shape_find_owner(int(h.shape))) as CollisionShape3D
	if ow == null or not (ow.shape is BoxShape3D) or ow.disabled:
		return ""
	var sz: Vector3 = (ow.shape as BoxShape3D).size
	var bot := ow.global_position.y - sz.y * 0.5
	if sz.x > 1.7 or sz.z > 1.7 or sz.y > 1.9 or sz.x * sz.z > 1.6 or absf(bot - fy) > 0.4:
		return ""
	# a locked door's leaf is a solid in its doorway too, and it stays
	var p := ow.global_position
	for d in Game.W.get("doors", []):
		if Vector2(float(d.x) - p.x, float(d.z) - p.z).length() < 1.3:
			return ""
	# nor is a terminal's stand
	for t in Game.W.get("terminals", []):
		if Vector2(float(t.x) - p.x, float(t.z) - p.z).length() < 0.8:
			return ""
	return str(ow.get_instance_id())

func _prop_rect(h: Dictionary) -> Rect2:
	var co := h.collider as CollisionObject3D
	var ow := co.shape_owner_get_owner(co.shape_find_owner(int(h.shape))) as CollisionShape3D
	var sz: Vector3 = (ow.shape as BoxShape3D).size
	var p := ow.global_position
	return Rect2(Vector2(p.x, p.z) - Vector2(sz.x, sz.z) * 0.5, Vector2(sz.x, sz.z))

var dropped: Array = []
func _drop_prop(h: Dictionary) -> bool:
	var co := h.collider as CollisionObject3D
	var ow := co.shape_owner_get_owner(co.shape_find_owner(int(h.shape))) as CollisionShape3D
	var sz: Vector3 = (ow.shape as BoxShape3D).size
	var p := ow.global_position
	# the piece you can see there
	var seen: Array = []
	var top := root.get_tree().current_scene if root.get_tree() else null
	if top:
		for c in top.find_children("*", "MeshInstance3D", true, false):
			var mi := c as MeshInstance3D
			var nm := String(mi.name)
			if not (nm.begins_with("s_") or nm.begins_with("b_")) or not mi.visible or not mi.is_inside_tree():
				continue
			var ab: AABB = mi.global_transform * mi.get_aabb()
			var cc := ab.get_center()
			if Vector2(cc.x - p.x, cc.z - p.z).length() < 0.45 and absf(cc.y - p.y) < 0.6 and ab.size.x < sz.x + 0.6 and ab.size.z < sz.z + 0.6 \
					and ab.size.x > minf(sz.x, sz.z) * 0.5 and ab.size.y < sz.y + 0.6:
				seen.append(mi)
	if seen.is_empty() and sz.y > 1.5 and maxf(sz.x, sz.z) <= 1.3 and maxf(sz.x, sz.z) >= 0.7 and minf(sz.x, sz.z) <= 0.6:
		# a shut door, part of the room's own model: it stays, but it opens now (you step through, like the town's
		# other doors) instead of shutting a back room away for good
		var id := "fd_%d_%d" % [roundi(p.x * 10.0), roundi(p.z * 10.0)]
		if Game.main and Game.main.get("objects"):
			var o := {"id": id, "x": p.x, "z": p.z, "y": fy, "lock": 0,
				"col": {"x0": p.x - sz.x * 0.5, "x1": p.x + sz.x * 0.5, "z0": p.z - sz.z * 0.5, "z1": p.z + sz.z * 0.5}}
			var known := false
			for k in Game.main.objects.grid:
				for o2 in Game.main.objects.grid[k]:
					if String(o2.get("id", "")) == id:
						known = true
			if not known:
				Game.main.objects._add("ldoor", o)
			Game.opened["d_" + id] = true
			dropped.append("door made usable@" + str(p.snapped(Vector3.ONE * 0.1)))
		return false
	if seen.is_empty():
		# no piece of its own to take away (it's part of the room's model): it stays as it is
		return false
	for mi in seen:
		(mi as MeshInstance3D).visible = false
		dropped.append(String(mi.name))
	ow.set_deferred("disabled", true)
	PhysicsServer3D.body_set_shape_disabled(co.get_rid(), int(h.shape), true)
	dropped.append("solid@" + str(p.snapped(Vector3.ONE * 0.1)) + " size " + str(sz.snapped(Vector3.ONE * 0.01)))
	return true

# doorways and passages: floor squeezed between two walls (a gap no wider than THROAT across) that runs on the
# other way. Nothing goes in one, or just either side of it, chairs included: you walk through a doorway, not round
# the chair parked in it.
const THROAT := 1.7
var throats: Array = []
func _throats(free: PackedByteArray, r0: PackedByteArray) -> void:
	var nx: int = wg.nx
	var nz: int = wg.nz
	var lim := int(THROAT / GC)
	# run lengths across x (for each cell, the free run it's in along x) and along z
	var run_x := PackedInt32Array()
	run_x.resize(nx * nz)
	var walled_x := PackedByteArray()
	walled_x.resize(nx * nz)
	for j in nz:
		var i := 0
		while i < nx:
			if free[i * nz + j] == 0:
				i += 1
				continue
			var s := i
			while i < nx and free[i * nz + j] == 1:
				i += 1
			var closed := 1 if s > 0 and i < nx else 0
			for k in range(s, i):
				run_x[k * nz + j] = i - s
				walled_x[k * nz + j] = closed
	var run_z := PackedInt32Array()
	run_z.resize(nx * nz)
	var walled_z := PackedByteArray()
	walled_z.resize(nx * nz)
	for i in nx:
		var j := 0
		while j < nz:
			if free[i * nz + j] == 0:
				j += 1
				continue
			var s := j
			while j < nz and free[i * nz + j] == 1:
				j += 1
			var closed := 1 if s > 0 and j < nz else 0
			for k in range(s, j):
				run_z[i * nz + k] = j - s
				walled_z[i * nz + k] = closed
	var n := 0
	for i in nx:
		for j in nz:
			var k := i * nz + j
			if r0[k] == 0:
				continue
			var c: Vector2 = wg.o + Vector2(i + 0.5, j + 0.5) * GC
			if not rect.grow(0.4).has_point(c):
				continue
			# only every other cell: the rects overlap anyway
			if (i + j) % 2 == 1:
				continue
			if walled_x[k] == 1 and run_x[k] <= lim and run_z[k] * GC >= 2.4:
				throats.append(Rect2(c - Vector2(GC * 0.5 + 0.25, 1.2), Vector2(GC + 0.5, 2.4)))
				n += 1
			elif walled_z[k] == 1 and run_z[k] <= lim and run_x[k] * GC >= 2.4:
				throats.append(Rect2(c - Vector2(1.2, GC * 0.5 + 0.25), Vector2(2.4, GC + 0.5)))
				n += 1
	wg["throats"] = n

func _in_room(k: int) -> bool:
	var c: Vector2 = wg.o + Vector2(k / int(wg.nz) + 0.5, k % int(wg.nz) + 0.5) * GC
	return rect.has_point(c)

func _reach(free: PackedByteArray, seeds: Array) -> PackedByteArray:
	var nz: int = wg.get("nz", 1)
	var n := free.size()
	var seen := PackedByteArray()
	seen.resize(n)
	var stack: Array = []
	for s in seeds:
		if free[s] == 1 and seen[s] == 0:
			seen[s] = 1
			stack.append(s)
	while not stack.is_empty():
		var k: int = stack.pop_back()
		var j := k % nz
		for nb in [k - nz, k + nz, k - 1 if j > 0 else -1, k + 1 if j < nz - 1 else -1]:
			if nb >= 0 and nb < n and free[nb] == 1 and seen[nb] == 0:
				seen[nb] = 1
				stack.append(nb)
	return seen

# the grid with the furniture in it (all but the piece `skip`)
func _furnished(skip := -1) -> PackedByteArray:
	var f: PackedByteArray = (wg.free as PackedByteArray).duplicate()
	var nz: int = wg.nz
	var nx: int = wg.nx
	for pi in pieces.size():
		if pi == skip or pieces[pi][0] == null or not is_instance_valid(pieces[pi][0]):
			continue
		var r: Rect2 = (pieces[pi][1] as Rect2).grow(0.34)
		var i0 := maxi(0, int(floor((r.position.x - wg.o.x) / GC - 0.5)))
		var i1 := mini(nx - 1, int(ceil((r.end.x - wg.o.x) / GC - 0.5)))
		var j0 := maxi(0, int(floor((r.position.y - wg.o.y) / GC - 0.5)))
		var j1 := mini(nz - 1, int(ceil((r.end.y - wg.o.y) / GC - 0.5)))
		for i in range(i0, i1 + 1):
			for j in range(j0, j1 + 1):
				var c: Vector2 = wg.o + Vector2(i + 0.5, j + 0.5) * GC
				if r.has_point(c):
					f[i * nz + j] = 0
	return f

# floor that could be walked to before and now can't (not counting what's under the furniture itself), in m²
var lost_at: Array = []   # where, the last time it was counted
func _lost(f: PackedByteArray) -> float:
	var r1 := _reach(f, wg.seeds)
	var r0: PackedByteArray = wg.r0
	lost_at = []
	for k in r0.size():
		if r0[k] == 1 and f[k] == 1 and r1[k] == 0:
			lost_at.append(wg.o + Vector2(k / int(wg.nz) + 0.5, k % int(wg.nz) + 0.5) * GC)
	return lost_at.size() * GC * GC

var removed: Array = []   # ids taken out again, for the tests
static var audit: Array = []
static var worst := 0.0       # the most floor any room was left cut off from its door, m²
static var rooms_checked := 0
func _unblock() -> void:
	if wg.is_empty() or not wg.has("r0"):
		return
	for round_i in 6:
		var lost := _lost(_furnished())
		if lost < 1.0:
			return
		# only what stands next to the cut-off floor can be what cuts it off
		var near: Array = lost_at.duplicate()
		var best := -1
		var best_l := lost
		for pi in pieces.size():
			if pieces[pi][0] == null or not is_instance_valid(pieces[pi][0]):
				continue
			var g: Rect2 = (pieces[pi][1] as Rect2).grow(0.7)
			var by := false
			for c in near:
				if g.has_point(c):
					by = true
					break
			if not by:
				continue
			var l := _lost(_furnished(pi))
			if l < best_l - 0.05:
				best_l = l
				best = pi
		if best < 0:
			return
		_take_out(best)

func _take_out(pi: int) -> void:
	var n: Node3D = pieces[pi][0]
	var fp: Rect2 = pieces[pi][1]
	removed.append(String(pieces[pi][2]))
	# what was standing on it goes too
	for c in root.get_children():
		if c is Node3D and c != n and (c as Node3D).global_position.y > fy + 0.25 and fp.grow(0.05).has_point(Vector2((c as Node3D).global_position.x, (c as Node3D).global_position.z)):
			c.queue_free()
	if TownLife.inst:
		TownLife.inst.spots = TownLife.inst.spots.filter(func(s): return s.node != n)
	taken.erase(_footprint(String(pieces[pi][2]), Vector2(n.global_position.x, n.global_position.z), n.rotation.y, 0.0))
	# gone from the physics now, not at the end of the frame
	for b in n.find_children("*", "CollisionObject3D", true, false):
		(b as CollisionObject3D).process_mode = Node.PROCESS_MODE_DISABLED
		(b as CollisionObject3D).collision_layer = 0
	n.queue_free()
	pieces[pi][0] = null

# ---------------------------------------------------------------- tables out in the room, chairs round them
func _tables(K: Dictionary) -> void:
	var want: int = K.sets
	if no_lights:
		want = maxi(1, want / 2)
	var tries := 0
	while want > 0 and tries < 60:
		tries += 1
		var tid: String = K.table[rng.randi() % K.table.size()]
		var p := Vector2(rng.randf_range(rect.position.x + 1.6, rect.end.x - 1.6), rng.randf_range(rect.position.y + 1.6, rect.end.y - 1.6))
		var yaw: float = [0.0, PI * 0.5][rng.randi() % 2] + rng.randf_range(-0.12, 0.12)
		# room to pull the chairs out
		var ab := Furniture.aabb(tid)
		if not _free(tid, p, yaw, fy):
			continue
		var grow := _footprint(tid, p, yaw).grow(0.75)
		var ok := true
		for r in taken:
			if (r as Rect2).intersects(grow):
				ok = false
		if not ok:
			continue
		_put(tid, p, yaw, fy)
		_on_top(tid, p, yaw, fy, K, rng.randi_range(0, 2))
		want -= 1
		# chairs on the long sides (and the ends of a long table), facing in, pushed in a little askew
		var cid: String = K.chair[rng.randi() % K.chair.size()]
		var spots := [Vector2(0, ab.size.z * 0.5 + 0.38), Vector2(0, -ab.size.z * 0.5 - 0.38)]
		if ab.size.x > 1.2:
			spots = [Vector2(-ab.size.x * 0.25, ab.size.z * 0.5 + 0.38), Vector2(ab.size.x * 0.25, ab.size.z * 0.5 + 0.38),
				Vector2(-ab.size.x * 0.25, -ab.size.z * 0.5 - 0.38), Vector2(ab.size.x * 0.25, -ab.size.z * 0.5 - 0.38)]
		for sp in spots:
			if rng.randf() < 0.25:
				continue
			var off: Vector2 = (sp as Vector2).rotated(-yaw)
			var cp := p + off
			var cy := atan2(-off.x, -off.y) + rng.randf_range(-0.35, 0.35)
			if _free(cid, cp, cy, fy, false):
				_put(cid, cp, cy, fy)

# ---------------------------------------------------------------- on the walls: pictures, clocks, a dartboard, lamps
func _decor(K: Dictionary) -> void:
	var n := 2 + rng.randi() % 2
	var tries := 0
	while n > 0 and tries < 40:
		tries += 1
		var side := rng.randi() % 4
		var p := Vector2.ZERO
		var nrm := Vector2.ZERO
		match side:
			0: p = Vector2(rng.randf_range(rect.position.x + 1, rect.end.x - 1), rect.position.y); nrm = Vector2(0, 1)
			1: p = Vector2(rect.end.x, rng.randf_range(rect.position.y + 1, rect.end.y - 1)); nrm = Vector2(-1, 0)
			2: p = Vector2(rng.randf_range(rect.position.x + 1, rect.end.x - 1), rect.end.y); nrm = Vector2(0, -1)
			_: p = Vector2(rect.position.x, rng.randf_range(rect.position.y + 1, rect.end.y - 1)); nrm = Vector2(1, 0)
		var y := fy + rng.randf_range(1.55, 1.85)
		# is there really a wall here (not a window or a doorway), and nothing tall in front of it?
		var from := Vector3(p.x + nrm.x * 1.0, y, p.y + nrm.y * 1.0)
		var to := Vector3(p.x - nrm.x * 0.6, y, p.y - nrm.y * 0.6)
		var h := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
		if h.is_empty():
			continue
		var hp: Vector3 = h.position
		if Vector2(hp.x, hp.z).distance_to(p) > 0.5 or absf(Vector2(h.normal.x, h.normal.z).dot(nrm)) < 0.8:
			continue
		var on_sign := false
		for sg in signs:
			if (sg as Rect2).grow(0.4).has_point(Vector2(hp.x, hp.z)):
				on_sign = true
		# not on the edge of a doorway (a mirror hung on the jamb sticks out into the way through)
		for tr in throats:
			if (tr as Rect2).grow(0.1).has_point(Vector2(hp.x, hp.z)):
				on_sign = true
		if on_sign:
			continue
		var id: String = K.decor[rng.randi() % K.decor.size()]
		var c := Furniture.make(id, id == "industrial_wall_lamp" and lights < 3 and not no_lights)
		if id == "industrial_wall_lamp":
			lights += 1
		root.add_child(c)
		c.global_position = hp + Vector3(nrm.x, 0, nrm.y) * 0.03
		c.rotation.y = atan2(nrm.x, nrm.y)
		n -= 1

# ---------------------------------------------------------------- hanging from the ceiling
func _ceiling(K: Dictionary) -> void:
	if K.ceil.is_empty():
		return
	var cols := 1 if rect.size.x < 10.0 else 2
	var rows := 1 if rect.size.y < 10.0 else 2
	for i in cols:
		for j in rows:
			var p := Vector2(rect.position.x + rect.size.x * (i + 0.5) / cols, rect.position.y + rect.size.y * (j + 0.5) / rows)
			var id: String = K.ceil[rng.randi() % K.ceil.size()]
			# hung from the ceiling that's really there (build 23: they were hung at a guessed height, some in mid-air)
			var cy := fy + (3.58 if no_lights else ROOM_H)
			if space:
				var h := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x, fy + 1.9, p.y), Vector3(p.x, fy + 9.0, p.y), 1))
				if not h.is_empty():
					cy = float(h.position.y)
			var c := Furniture.hang(id, cy, fy, lights < 4 and not no_lights)
			lights += 1
			root.add_child(c)
			c.global_position = Vector3(p.x, cy, p.y)
			c.rotation.y = rng.randf() * TAU
