# World streaming: the region is cut into 64 m chunks (one GLB each). Chunks near the player are loaded on a worker
# thread and added one per frame; chunks that fall out of range are freed. Inside a chunk, small things (props,
# clutter) are only drawn up close and never cast shadows; buildings and big props draw further and cast shadows.
extends Node3D

const SIZE := 64.0
var files: Dictionary = {}      # "i_j" -> path
var loaded: Dictionary = {}     # "i_j" -> Node3D
var pending: Dictionary = {}    # "i_j" -> path (threaded load requested)
var ready_q: Array = []         # [key, PackedScene] waiting to be added
var load_r := 2                 # chunks around the player to keep (2 -> a 5x5 block, ~160 m each way)
var small_range := 70.0
var big_range := 320.0
var check_t := 0.0

func _ready() -> void:
	var dir := DirAccess.open("res://data/world")
	if dir == null:
		return
	for f in dir.get_files():
		f = f.trim_suffix(".import").trim_suffix(".remap")
		if f.ends_with(".glb") and f.begins_with("c_"):
			files[f.trim_prefix("c_").trim_suffix(".glb")] = "res://data/world/" + f

func configure(radius: int, small_r: float, big_r: float) -> void:
	load_r = radius
	small_range = small_r
	big_range = big_r
	for k in loaded:
		_tune(loaded[k])
	check_t = 0.0

func _key_at(p: Vector3) -> Vector2i:
	return Vector2i(int(floor((p.x - Game.x0) / SIZE)), int(floor((p.z - Game.z0) / SIZE)))

func wanted(p: Vector3) -> Array:
	var c := _key_at(p)
	var out: Array = []
	for j in range(-load_r, load_r + 1):
		for i in range(-load_r, load_r + 1):
			var k := str(c.x + i) + "_" + str(c.y + j)
			if files.has(k):
				out.append(k)
	# nearest first
	out.sort_custom(func(a, b): return _dist(a, p) < _dist(b, p))
	return out

func _dist(k: String, p: Vector3) -> float:
	var ij := k.split("_")
	var cx := Game.x0 + (int(ij[0]) + 0.5) * SIZE
	var cz := Game.z0 + (int(ij[1]) + 0.5) * SIZE
	return Vector2(cx - p.x, cz - p.z).length()

# blocking load of everything around a spot (used at start so the town is there on the first frame)
func load_now(p: Vector3) -> void:
	for k in wanted(p):
		if not loaded.has(k):
			_add(k, load(files[k]))

func _add(k: String, ps: PackedScene) -> void:
	if ps == null or loaded.has(k):
		return
	var n := ps.instantiate() as Node3D
	add_child(n)
	loaded[k] = n
	_tune(n)

func _tune(n: Node) -> void:
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var small := mi.name.begins_with("s_")
		mi.visibility_range_end = small_range if small else big_range
		mi.visibility_range_end_margin = 6.0 if small else 20.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		if small:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _process(d: float) -> void:
	# finished background loads go in at one per frame so adding a chunk never costs more than one instantiate
	if not ready_q.is_empty():
		var it: Array = ready_q.pop_front()
		_add(it[0], it[1])
	for k in pending.keys():
		var st := ResourceLoader.load_threaded_get_status(pending[k])
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			ready_q.append([k, ResourceLoader.load_threaded_get(pending[k])])
			pending.erase(k)
		elif st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			pending.erase(k)
	check_t -= d
	if check_t > 0.0 or Game.player == null:
		return
	check_t = 0.5
	var p: Vector3 = Game.player.global_position
	var want := wanted(p)
	for k in want:
		if not loaded.has(k) and not pending.has(k) and not ready_q.any(func(it): return it[0] == k):
			pending[k] = files[k]
			ResourceLoader.load_threaded_request(files[k], "PackedScene", true)
	# free chunks one ring beyond the load radius (the gap stops chunks flickering in and out at a border)
	var c := _key_at(p)
	for k in loaded.keys():
		var ij: PackedStringArray = k.split("_")
		if absi(int(ij[0]) - c.x) > load_r + 1 or absi(int(ij[1]) - c.y) > load_r + 1:
			loaded[k].queue_free()
			loaded.erase(k)

func count() -> int:
	return loaded.size()
