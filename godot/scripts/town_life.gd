# Townspeople going about their day. A walkable navigation mesh is baked for each place people live (all of Haven 12
# at once; each town room as you enter it; a patch of the valley round anyone who lives outdoors), so they walk round
# the furniture and each other instead of through them. Furnished rooms register "spots": chairs to sit in, desks,
# shelves, benches and planters to work at. Each person spends a while at home, goes to a free spot near it, sits or
# works there for a bit, and comes back (npc.gd's life loop). Chairs work for you too: look at one and USE.
class_name TownLife
extends Node

static var inst: TownLife

# kinds of spot and what a person does there
const USE := {
	"modern_desk": "PickUp_Table", "WoodenTable_01": "PickUp_Table", "WoodenTable_02": "PickUp_Table", "WoodenTable_03": "PickUp_Table",
	"CoffeeTable_01": "Idle_FoldArms", "Shelf_01": "Interact", "modern_bookshelf": "Interact", "modern_sideboard": "Interact",
	"ClassicConsole_01": "Interact", "ClassicNightstand_01": "Interact", "modern_wardrobe": "Chest_Open", "treasure_chest": "Chest_Open",
	"ceramic_pot": "Farm_Watering", "k:q_Barrel": "Interact", "k:s_box-large": "PickUp_Table", "k:q_Wheels_Stack": "Fixing_Kneeling",
	"k:q_Pipes": "Fixing_Kneeling", "Television_01": "Idle_FoldArms",
}

var spots: Array = []        # {p: approach point, at: where the body goes, yaw, kind: "sit"/"use", anim, seat_h, node, who}
var regions := {}            # key -> NavigationRegion3D
var ready_keys := {}         # key -> true once its mesh is baked
var _world_cells := {}       # outdoor patches already baked

func _ready() -> void:
	inst = self
	var map := get_viewport().find_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(map, 0.1)
	NavigationServer3D.map_set_cell_height(map, 0.05)
	NavigationServer3D.map_set_edge_connection_margin(map, 0.3)

static func _mesh() -> NavigationMesh:
	var nm := NavigationMesh.new()
	nm.cell_size = 0.1
	nm.cell_height = 0.05
	nm.agent_radius = 0.3
	nm.agent_height = 1.7
	nm.agent_max_climb = 0.3
	nm.agent_max_slope = 40.0
	nm.region_min_size = 4.0
	nm.edge_max_error = 1.6
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	return nm

# an indoor place: everything solid inside 'box' (walls, counters, furniture) is parsed from the scene
func bake_box(key: String, box: AABB) -> void:
	if regions.has(key):
		forget(key)
	var nm := _mesh()
	nm.filter_baking_aabb = box
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, Game.main)
	_bake(key, nm, src)

# outdoors: the ground from the heightfield (a metre grid) and the buildings' solid boxes, round a point
func bake_outdoor(at: Vector3) -> void:
	var cx := floori(at.x / 40.0)
	var cz := floori(at.z / 40.0)
	var key := "w%d_%d" % [cx, cz]
	if _world_cells.has(key):
		return
	_world_cells[key] = true
	var x0 := cx * 40.0 - 6.0
	var z0 := cz * 40.0 - 6.0
	var size := 52.0
	var nm := _mesh()
	nm.cell_size = 0.2
	nm.cell_height = 0.1
	nm.agent_max_climb = 0.45
	var src := NavigationMeshSourceGeometryData3D.new()
	var f := PackedVector3Array()
	var n := int(size)
	var hy := func(x: float, z: float) -> Vector3: return Vector3(x, Game.height(x, z), z)
	for i in n:
		for j in n:
			var a: Vector3 = hy.call(x0 + i, z0 + j)
			var b: Vector3 = hy.call(x0 + i + 1, z0 + j)
			var c: Vector3 = hy.call(x0 + i, z0 + j + 1)
			var d: Vector3 = hy.call(x0 + i + 1, z0 + j + 1)
			f.append_array([a, c, b, b, c, d])
	src.add_faces(f, Transform3D.IDENTITY)
	var r := Rect2(x0, z0, size, size)
	for s in Game.region.get("solids", []):
		var sr := Rect2(float(s[0]), float(s[2]), float(s[1]) - float(s[0]), float(s[3]) - float(s[2]))
		if not r.intersects(sr):
			continue
		var bm := BoxMesh.new()
		bm.size = Vector3(sr.size.x, float(s[5]) - float(s[4]), sr.size.y)
		src.add_mesh(bm, Transform3D(Basis(), Vector3(sr.get_center().x, (float(s[4]) + float(s[5])) * 0.5, sr.get_center().y)))
	nm.filter_baking_aabb = AABB(Vector3(x0, -200, z0), Vector3(size, 600, size))
	_bake(key, nm, src)

func _bake(key: String, nm: NavigationMesh, src: NavigationMeshSourceGeometryData3D) -> void:
	var reg := NavigationRegion3D.new()
	reg.name = "Nav_" + key
	add_child(reg)
	regions[key] = reg
	NavigationServer3D.bake_from_source_geometry_data_async(nm, src, func():
		if is_instance_valid(reg):
			reg.navigation_mesh = nm
			ready_keys[key] = true)

func forget(key: String) -> void:
	if regions.has(key):
		(regions[key] as Node).queue_free()
		regions.erase(key)
		ready_keys.erase(key)
	spots = spots.filter(func(s): return String(s.key) != key)

func clear_all() -> void:
	for k in regions.keys():
		forget(k)
	_world_cells.clear()
	spots.clear()

# ---------------------------------------------------------------- spots
# a placed piece of furniture: a seat to sit on, or something to stand at and use
func add_piece(key: String, id: String, node: Node3D) -> void:
	var yaw := node.rotation.y
	var fwd := Vector3(sin(yaw), 0, cos(yaw))        # pieces face +Z into the room
	var ab := Furniture.aabb(id)
	var base := node.global_position
	if id in Furniture.SEATS:
		var seat := Furniture.surface_at(id, Vector2(ab.get_center().x, ab.get_center().z + ab.size.z * 0.1), ab.position.y + 0.75)
		if seat == -INF:
			seat = 0.45
		spots.append({"key": key, "kind": "sit", "node": node, "yaw": yaw, "seat_h": seat,
			"at": base + fwd * (ab.get_center().z + 0.02), "p": base + fwd * (ab.end.z + 0.45), "anim": "Sitting_Idle", "who": null})
	elif USE.has(id):
		var reach := ab.end.z + 0.42
		spots.append({"key": key, "kind": "use", "node": node, "yaw": yaw + PI, "seat_h": 0.0,
			"at": base + fwd * reach, "p": base + fwd * reach, "anim": USE[id], "who": null})

# a free spot near home that this person can walk to
func pick(npc, home: Vector3, radius: float) -> Dictionary:
	var best := {}
	var choices: Array = []
	for s in spots:
		if s.who != null and is_instance_valid(s.who) and s.who != npc:
			continue
		if not is_instance_valid(s.node):
			continue
		var d: float = (s.p as Vector3).distance_to(home)
		if d > radius or absf((s.p as Vector3).y - home.y) > 1.5:
			continue
		choices.append(s)
	if choices.is_empty():
		return best
	if OS.get_cmdline_user_args().has("--sitfirst"):
		var sits := choices.filter(func(c): return String(c.kind) == "sit")
		if not sits.is_empty():
			choices = sits
	best = choices[randi() % choices.size()]
	best.who = npc
	return best

func release(s: Dictionary, npc) -> void:
	if not s.is_empty() and s.get("who") == npc:
		s.who = null

# the nearest free seat in front of you, for sitting down yourself
func seat_near(p: Vector3, fwd: Vector3, maxd: float) -> Dictionary:
	var best := {}
	var bd := maxd
	for s in spots:
		if String(s.kind) != "sit" or not is_instance_valid(s.node) or (s.who != null and is_instance_valid(s.who)):
			continue
		var to: Vector3 = (s.at as Vector3) - p
		to.y = 0
		var d := to.length()
		if d < bd and (d < 0.9 or fwd.dot(to / d) > 0.55):
			# and not through a wall
			var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.2, (s.at as Vector3) + Vector3.UP * 0.6, 1)
			var h := get_viewport().find_world_3d().direct_space_state.intersect_ray(q)
			if not h.is_empty() and (h.position as Vector3).distance_to(s.at as Vector3) > 0.7:
				continue
			bd = d
			best = s
	return best

# whether there's a walkable mesh under a point yet (people stay put until the bake for their place finishes)
func ready_at(p: Vector3) -> bool:
	var map := get_viewport().find_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return false
	var c := NavigationServer3D.map_get_closest_point(map, p)
	return c.distance_to(p) < 1.2
