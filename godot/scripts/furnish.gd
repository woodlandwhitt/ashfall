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

static func room(parent: Node3D, C: Dictionary) -> Node3D:
	var f := Furnish.new()
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
	return _area(parent, r0, String(C.get("kind", "office")), float(Game.L.consts.CELLS.y), doors, "room" + str(C.i))

func _area(parent: Node3D, r0: Rect2, kind: String, floor_y: float, doors: Array, key: String) -> Node3D:
	root = Node3D.new()
	root.name = "Furnish_" + key
	parent.add_child(root)
	space = parent.get_world_3d().direct_space_state
	rng.seed = hash(key)
	fy = floor_y
	rect = r0
	var C := {"kind": kind}
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
	_walls(K)
	if String(C.get("kind", "")) in ["storage", "workshop", "store"]:
		_aisles(K, String(C.get("kind", "")))
	_tables(K)
	if not no_lights or kind in ["storage", "workshop"]:
		_junk(String(C.get("kind", "")))
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
		var t := rng.randf_range(0.3, 1.2)
		var last := ""
		while t < L - 0.5:
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
					_on_top(id, pos, yaw, fy, K, rng.randi_range(1, 3))
				elif id in ["Shelf_01", "modern_bookshelf", "modern_sideboard", "ClassicConsole_01"]:
					_on_top(id, pos, yaw, fy, K, 3, true)
				last = id
				t += along + (rng.randf_range(0.4, 1.8) if no_lights else rng.randf_range(0.08, 0.7))
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
	var n := 3 + rng.randi() % 4
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

# ---------------------------------------------------------------- tables out in the room, chairs round them
func _tables(K: Dictionary) -> void:
	var want: int = K.sets
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
		_on_top(tid, p, yaw, fy, K, rng.randi_range(1, 3))
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
	var n := 3 + rng.randi() % 3
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
			var c := Furniture.make(id, lights < 4 and not no_lights)
			lights += 1
			root.add_child(c)
			c.global_position = Vector3(p.x, fy + (3.58 if no_lights else ROOM_H) - 0.02, p.y)
			c.rotation.y = rng.randf() * TAU
