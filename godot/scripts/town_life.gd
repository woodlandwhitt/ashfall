# Townspeople going about their day. A walkable navigation mesh is baked for each place people live (all of Haven 12
# at once; each town room as you enter it; a patch of the valley round anyone who lives outdoors), so they walk round
# the furniture and each other instead of through them. Furnished rooms register "spots": chairs to sit in, desks,
# shelves, benches and planters to work at. Each person spends a while at home, goes to a free spot near it, sits or
# works there for a bit, and comes back (npc.gd's life loop). Chairs work for you too: look at one and USE.
# Townspeople walk on their own navigation map, apart from the coarse one hostiles hunt you on (main.gd's _bake_nav):
# the two need different detail, and Godot wants every mesh on a map baked at the map's cell size. Outdoors the
# valley is baked in 32 m tiles that line up edge to edge (a border is baked and trimmed, so neighbours join).
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
var _world_cells := {}       # outdoor tiles already baked
var map: RID                 # the townspeople's own navigation map
const CELL := 0.1
const CELL_H := 0.05
const TILE := 32.0
var obstacle: NavigationObstacle3D   # you: people step round you
var _near_t := 0.0

func _ready() -> void:
	inst = self
	map = NavigationServer3D.map_create()
	NavigationServer3D.map_set_up(map, Vector3.UP)
	NavigationServer3D.map_set_cell_size(map, CELL)
	NavigationServer3D.map_set_cell_height(map, CELL_H)
	NavigationServer3D.map_set_edge_connection_margin(map, 0.35)
	NavigationServer3D.map_set_link_connection_radius(map, 0.5)
	NavigationServer3D.map_set_active(map, true)

func _exit_tree() -> void:
	if map.is_valid():
		NavigationServer3D.map_set_active(map, false)

func _process(_d: float) -> void:
	# a moving obstacle on the player, so a person walking your way steps aside instead of into you
	if obstacle == null and Game.player and Game.player.is_inside_tree():
		obstacle = NavigationObstacle3D.new()
		obstacle.radius = 0.45
		obstacle.height = 1.8
		obstacle.avoidance_enabled = true
		Game.player.add_child(obstacle)
		obstacle.set_navigation_map(map)
	elif obstacle and Game.player:
		obstacle.velocity = Game.player.velocity
		# with company along outdoors, the ground round you gets baked too, so they can find their way after you
		_near_t -= _d
		if _near_t <= 0.0 and Game.area == "world" and Game.main and not Game.main.party.is_empty():
			_near_t = 2.0
			bake_outdoor(Game.player.global_position)

# an agent (a townsperson) put on the townspeople's map
func adopt(agent: NavigationAgent3D) -> void:
	agent.set_navigation_map(map)

static func _mesh() -> NavigationMesh:
	var nm := NavigationMesh.new()
	nm.cell_size = CELL
	nm.cell_height = CELL_H
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

# outdoors: the ground from the heightfield (half-metre grid) and the buildings' solid boxes, one 32 m tile at a
# time; tiles are baked with a 2 m border that is trimmed off, so neighbouring tiles share their edges exactly
func bake_outdoor(at: Vector3, reach := 1) -> void:
	var cx := floori(at.x / TILE)
	var cz := floori(at.z / TILE)
	for di in range(-reach, reach + 1):
		for dj in range(-reach, reach + 1):
			_tile(cx + di, cz + dj)

func _tile(cx: int, cz: int) -> void:
	var key := "w%d_%d" % [cx, cz]
	if _world_cells.has(key):
		return
	_world_cells[key] = true
	var border := 2.0
	var x0 := cx * TILE - border - 1.0
	var z0 := cz * TILE - border - 1.0
	var size := TILE + (border + 1.0) * 2.0
	var nm := _mesh()
	nm.agent_max_climb = 0.45
	nm.border_size = border
	var src := NavigationMeshSourceGeometryData3D.new()
	var f := PackedVector3Array()
	var step := 0.5
	var n := int(size / step)
	for i in n:
		for j in n:
			var x := x0 + i * step
			var z := z0 + j * step
			var a := Vector3(x, Game.height(x, z), z)
			var b := Vector3(x + step, Game.height(x + step, z), z)
			var c := Vector3(x, Game.height(x, z + step), z + step)
			var d := Vector3(x + step, Game.height(x + step, z + step), z + step)
			f.append_array([a, b, c, b, d, c])
	src.add_faces(f, Transform3D.IDENTITY)
	var r := Rect2(x0, z0, size, size)
	for s in Game.region.get("solids", []):
		var sr := Rect2(float(s[0]), float(s[2]), float(s[1]) - float(s[0]), float(s[3]) - float(s[2]))
		if not r.intersects(sr):
			continue
		src.add_faces(Game.main._box_faces(Vector3(s[0], s[4], s[2]), Vector3(s[1], s[5], s[3])), Transform3D.IDENTITY)
	nm.filter_baking_aabb = AABB(Vector3(cx * TILE - border, -400, cz * TILE - border), Vector3(TILE + border * 2.0, 800, TILE + border * 2.0))
	_bake(key, nm, src)
	# the town's own gathering places in this tile: the well, the notice board, the gaming tables
	var tile := Rect2(cx * TILE, cz * TILE, TILE, TILE)
	for pt in Game.W.get("points", []):
		var id := String(pt.get("id", ""))
		if not id in ["well", "saltwell", "board", "blackjack", "dice", "roulette", "slots0", "slots1", "slots2", "slots3"]:
			continue
		var pp := Vector3(float(pt.x), float(pt.get("y", Game.height(float(pt.x), float(pt.z)))), float(pt.z))
		if not tile.has_point(Vector2(pp.x, pp.z)):
			continue
		var anim := "Interact" if id in ["well", "saltwell"] else ("Idle_FoldArms" if id == "board" else "Idle")
		for k in (2 if id in ["well", "saltwell", "board"] else 1):
			var a := randf() * TAU + k * PI
			add_point_spot(key, pp + Vector3(cos(a), 0, sin(a)) * 1.1, pp, anim)

func _bake(key: String, nm: NavigationMesh, src: NavigationMeshSourceGeometryData3D) -> void:
	var reg := NavigationRegion3D.new()
	reg.name = "Nav_" + key
	add_child(reg)
	reg.set_navigation_map(map)
	regions[key] = reg
	NavigationServer3D.bake_from_source_geometry_data_async(nm, src, func():
		if is_instance_valid(reg):
			reg.navigation_mesh = nm
			ready_keys[key] = true
			if debug_on:
				_draw(reg))

# ---------------------------------------------------------------- seeing it (Developer menu)
static var debug_on := false
func show_debug(on: bool) -> void:
	debug_on = on
	for k in regions:
		var reg: NavigationRegion3D = regions[k]
		var old := reg.get_node_or_null("Debug")
		if old:
			old.queue_free()
		if on and reg.navigation_mesh:
			_draw(reg)

# the walkable polygons in translucent green, their edges darker, lifted a little off the floor
func _draw(reg: NavigationRegion3D) -> void:
	var nm := reg.navigation_mesh
	var verts := nm.get_vertices()
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in nm.get_polygon_count():
		var poly := nm.get_polygon(i)
		for k in range(1, poly.size() - 1):
			for idx in [poly[0], poly[k], poly[k + 1]]:
				im.surface_add_vertex(verts[idx] + Vector3.UP * 0.06)
	im.surface_end()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in nm.get_polygon_count():
		var poly := nm.get_polygon(i)
		for k in poly.size():
			im.surface_add_vertex(verts[poly[k]] + Vector3.UP * 0.08)
			im.surface_add_vertex(verts[poly[(k + 1) % poly.size()]] + Vector3.UP * 0.08)
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.name = "Debug"
	mi.mesh = im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.2, 1.0, 0.4, 0.28)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	mi.material_override = m
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(0.05, 0.4, 0.15)
	mi.set_surface_override_material(1, lm)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	reg.add_child(mi)

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
	var yaw := node.global_rotation.y
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

# somewhere to stand facing something (a well, a fire, a notice board)
func add_point_spot(key: String, at: Vector3, look: Vector3, anim: String) -> void:
	var to := look - at
	spots.append({"key": key, "kind": "use", "node": null, "yaw": atan2(to.x, to.z), "seat_h": 0.0, "at": at, "p": at, "anim": anim, "who": null})

# a fire: a few places round it to stand and warm your hands
func add_fire(pos: Vector3, size: float) -> void:
	var key := "fire_%d_%d" % [roundi(pos.x), roundi(pos.z)]
	for s in spots:
		if String(s.key) == key:
			return
	for k in 3:
		var a := k * TAU / 3.0 + randf() * 0.5
		add_point_spot(key, pos + Vector3(cos(a), 0, sin(a)) * (1.1 + size * 0.5), pos, "Idle_FoldArms" if k == 1 else "Idle")

# a free spot near home that this person can walk to
func pick(npc, home: Vector3, radius: float, avoid: Array = []) -> Dictionary:
	var best := {}
	var choices: Array = []
	for s in spots:
		if s.who != null and is_instance_valid(s.who) and s.who != npc:
			continue
		if s.node != null and not is_instance_valid(s.node):
			continue
		var been := false
		for a in avoid:
			if (a as Vector3).distance_to(s.p) < 0.8:
				been = true
		if been:
			continue
		var d: float = (s.p as Vector3).distance_to(home)
		if d > radius or absf((s.p as Vector3).y - home.y) > 1.5:
			continue
		choices.append(s)
	if choices.is_empty():
		return best
	# near by the way you'd walk, not through a wall into the next room
	choices.shuffle()
	var walkable: Array = []
	for c in choices:
		if walkable.size() >= 4:
			break
		var path := NavigationServer3D.map_get_path(map, home, c.p, true)
		if path.is_empty() or (path[path.size() - 1] as Vector3).distance_to(c.p) > 0.8:
			continue
		var length := 0.0
		for i in range(1, path.size()):
			length += path[i - 1].distance_to(path[i])
		if length <= radius * 1.3:
			walkable.append(c)
	choices = walkable
	if choices.is_empty():
		return best
	if OS.get_cmdline_user_args().has("--sitfirst"):
		var sits := choices.filter(func(c): return String(c.kind) == "sit")
		if not sits.is_empty():
			choices = sits
	best = choices[randi() % choices.size()]
	best.who = npc
	return best

# two neighbours stopping for a word: a spot for each, a pace apart, facing each other
func chat_spots(a: Vector3, b: Vector3) -> Array:
	var mid := (a + b) * 0.5
	var dir := (b - a)
	dir.y = 0
	dir = dir.normalized() if dir.length() > 0.1 else Vector3.FORWARD
	var pa := closest(mid - dir * 0.6)
	var pb := closest(mid + dir * 0.6)
	return [{"key": "chat", "kind": "chat", "node": null, "yaw": atan2(dir.x, dir.z), "seat_h": 0.0, "at": pa, "p": pa, "anim": "Idle_Talking", "who": null},
		{"key": "chat", "kind": "chat", "node": null, "yaw": atan2(-dir.x, -dir.z), "seat_h": 0.0, "at": pb, "p": pb, "anim": "Idle_Talking", "who": null}]

func release(s: Dictionary, npc) -> void:
	if not s.is_empty() and s.get("who") == npc:
		s.who = null

# the nearest free seat in front of you, for sitting down yourself
func seat_near(p: Vector3, fwd: Vector3, maxd: float) -> Dictionary:
	var best := {}
	var bd := maxd
	for s in spots:
		if String(s.kind) != "sit" or s.node == null or not is_instance_valid(s.node) or (s.who != null and is_instance_valid(s.who)):
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
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return false
	var c := NavigationServer3D.map_get_closest_point(map, p)
	return c.distance_to(p) < 1.2

func closest(p: Vector3) -> Vector3:
	return NavigationServer3D.map_get_closest_point(map, p)