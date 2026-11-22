# The world's interactive objects from data/world.json: containers (loot tables, fixed loot, locks, owners),
# items lying about, terminals (lore, the relay tower, the core), workbenches, locked doors, the Meridian core door and
# the quest points (wells, pools, the bounty board, holotapes, wreckage...). Quest points run the original game's
# label/use logic from data/logic.json. Objects are bucketed by chunk so finding the one in front of you is cheap;
# pickups get a small glowing model while their chunk is loaded.
class_name WorldObjects
extends Node3D

const LOCK_NAMES := ["Easy", "Average", "Hard", "Very Hard"]
var main
var grid: Dictionary = {}       # chunk key -> [obj]
var pickup_nodes: Dictionary = {}
var CH := 64.0

func setup(m) -> void:
	main = m
	CH = float(Game.region.get("chunk", 64))
	var W: Dictionary = Game.W
	for c in W.get("chests", []):
		_add("chest", c)
	for p in W.get("pickups", []):
		_add("pickup", p)
	for t in W.get("terminals", []):
		_add("term", t)
	for b in W.get("benches", []):
		_add("bench", b)
	for d in W.get("doors", []):
		_add("ldoor", d)
	for p in W.get("points", []):
		_add("point", p)
	if W.get("door") != null:
		_add("door", W.door)

# objects that come and go (a road event's dead scavenger)
func add_dynamic(o: Dictionary) -> void:
	_add(String(o._k), o)

func remove_dynamic(o: Dictionary) -> void:
	var key := key_of(float(o.x), float(o.z))
	if grid.has(key):
		grid[key].erase(o)

func key_of(x: float, z: float) -> String:
	return str(floori((x - Game.x0) / CH)) + "_" + str(floori((z - Game.z0) / CH))

func _add(k: String, o: Dictionary) -> void:
	o["_k"] = k
	var key := key_of(float(o.x), float(o.z))
	if not grid.has(key):
		grid[key] = []
	grid[key].append(o)

# ---------------------------------------------------------------- pickups shown while their chunk is loaded
func spawn_chunk(key: String) -> void:
	for o in grid.get(key, []):
		if o._k != "pickup" or Game.looted.has("pk_" + String(o.id)) or pickup_nodes.has(o.id):
			continue
		# the thing itself: a tin, a bottle, a syringe, the gun...
		var mi := ItemModels.build(String(o.item))
		mi.scale = Vector3.ONE * (1.25 if int(o.get("qty", 1)) == 1 else 1.4)
		if o.has("glow"):
			var gl := OmniLight3D.new()
			gl.light_color = Color.hex(int(o.glow) << 8 | 0xff)
			gl.light_energy = 0.6
			gl.omni_range = 1.6
			gl.position.y = 0.15
			mi.add_child(gl)
		add_child(mi)
		# resting on whatever is under it (the table or shelf it was left on, or the floor): never floating
		var gy := Game.height(float(o.x), float(o.z))
		var y := float(o.y) if o.has("y") and float(o.y) > gy - 0.3 else gy
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(float(o.x), y + 0.6, float(o.z)), Vector3(float(o.x), y - 1.5, float(o.z)), 1))
		if not hit.is_empty():
			y = maxf(hit.position.y, gy) if not Game.interior() else hit.position.y
		mi.global_position = Vector3(float(o.x), y + 0.005, float(o.z))
		mi.rotation.y = hash(o.id) % 628 / 100.0
		pickup_nodes[o.id] = mi

# a pickup added after its chunk was built gets its model straight away
func add_pickup_now(o: Dictionary) -> void:
	_add("pickup", o)
	spawn_chunk(key_of(float(o.x), float(o.z)))

func despawn_chunk(key: String) -> void:
	for o in grid.get(key, []):
		if o._k == "pickup" and pickup_nodes.has(o.id):
			pickup_nodes[o.id].queue_free()
			pickup_nodes.erase(o.id)

# ---------------------------------------------------------------- what's in front of you
func label_of(o: Dictionary) -> Variant:
	match String(o._k):
		"chest":
			if _chest_empty(o):
				return null
			if o.get("lock") != null and not Game.opened.has("u_" + String(o.id)):
				return "Pick lock (" + LOCK_NAMES[clampi(int(o.lock), 0, 3)] + ")"
			if o.get("owned", false) and not Game.opened.has(String(o.id)):
				return "Steal from " + String(o.get("name", "someone's things"))
			return "Open " + String(o.name) if o.has("name") else "Search container"
		"pickup":
			if Game.looted.has("pk_" + String(o.id)):
				return null
			return ("Steal " if o.get("owned") else "Take ") + Game.iname(o.item) + (" (" + str(int(o.qty)) + ")" if int(o.get("qty", 1)) > 1 else "")
		"term":
			if String(o.kind) == "lore":
				var lk := term_lock(o)
				if lk > 0 and not Game.opened.has("t_" + String(o.id)):
					return "Hack terminal (" + ["", "Easy", "Average", "Hard"][lk] + ")"
				return "Read terminal"
			return "Use terminal"
		"bench":
			return "Use workbench"
		"ldoor":
			if Game.opened.has("d_" + String(o.id)):
				return "Go through the door"
			return "Pick lock (" + LOCK_NAMES[clampi(int(o.get("lock", 0)), 0, 3)] + ")"
		"door":
			return "Enter the core chamber" if Game.flags.get("doorOpen") else "Open core chamber"
		"point":
			return point_label(o)
	return null

func best(pp: Vector3, fwd: Vector3, bd: float) -> Dictionary:
	var found := {}
	var kx := floori((pp.x - Game.x0) / CH)
	var kz := floori((pp.z - Game.z0) / CH)
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			for o in grid.get(str(kx + dx) + "_" + str(kz + dz), []):
				var r := 3.4
				match String(o._k):
					"chest", "bench": r = 3.0
					"ldoor": r = 2.6
					"door": r = 4.0
					"pickup": r = 2.4
					"point": r = float(o.get("r", 3.4))
				if o.has("y") and o._k != "door" and absf(pp.y - float(o.y)) > 2.6:
					continue
				var x := float(o.x)
				var z := float(o.z)
				if o._k == "point" and o.has("pr"):
					var d0 := maxf(0.001, Vector2(pp.x - x, pp.z - z).length())
					var k := minf(1.0, float(o.pr) / d0)
					x += (pp.x - x) * k
					z += (pp.z - z) * k
				var to := Vector3(x - pp.x, 0, z - pp.z)
				var d := to.length()
				var prio := 0.9 if o.has("prio") else 0.0
				# street doors give way to anyone standing near them (a bartender by the saloon door)
				# (unless you're looking straight at the door)
				if o._k == "point" and String(o.id) in ["cellin", "cellout"]:
					r = minf(r, 2.4)
					prio = 0.0
				if d > r or d - prio >= bd:
					continue
				if d > 1.2 and fwd.dot(to / d) < 0.45:
					continue
				var l = label_of(o)
				if l == null:
					continue
				bd = d - prio
				found = {"k": "obj", "o": o, "label": String(l), "d": bd, "at": Vector3(x, float(o.y) if o.has("y") else Game.height(x, z), z)}
	# nothing through walls: the eye must see the object (doors and wall-mounted things are allowed their own wall)
	if not found.is_empty() and found.o._k not in ["ldoor", "door"] and not found.o.has("pr"):
		var small: bool = found.o._k == "pickup"
		var at: Vector3 = found.at + Vector3.UP * (0.25 if small else 0.9)
		var eye := pp + Vector3.UP * 1.5
		var q := PhysicsRayQueryParameters3D.create(eye, at, 1)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		# things on the ground must be in plain sight; furniture-sized things may sit against their own wall
		if not hit.is_empty() and (hit.position.distance_to(at) > 0.45 if small else Vector2(hit.position.x - at.x, hit.position.z - at.z).length() > 1.3):
			return {}
	return found

# ---------------------------------------------------------------- using things
func use(o: Dictionary) -> void:
	match String(o._k):
		"chest": _chest(o)
		"pickup": _pickup(o)
		"term": _terminal(o)
		"bench": main.hud.open_craft(true)
		"ldoor": _ldoor(o)
		"door": _core_door(o)
		"point": point_use(o)

func _chest_empty(o: Dictionary) -> bool:
	var st = Game.opened.get(String(o.id))
	return st is Array and st.is_empty()

func _chest(o: Dictionary) -> void:
	var id := String(o.id)
	if o.get("lock") != null and not Game.opened.has("u_" + id):
		main.hud.screens.open_lock(int(o.lock), String(o.get("name", "Container")), func(ok):
			if ok:
				Game.opened["u_" + id] = true
				Game.add_xp(10 + int(o.lock) * 10)
				if o.get("owned", false):
					_steal(String(o.get("name", "a container")))
				_chest(o))
		return
	if o.get("owned", false) and o.get("lock") == null and not Game.opened.has(id):
		_steal("from " + String(o.get("name", "someone's things")))
	if not Game.opened.has(id):
		var out: Array = []
		for f in o.get("fixed", []):
			out.append([String(f[0]), int(f[1])])
		var n := 0 if o.get("plain", false) else (1 if o.has("fixed") else 2 + (1 if randf() < 0.4 else 0))
		var table: Array = Game.DB.loot.get(String(o.get("tier", "common")), [])
		for i in n:
			if table.is_empty():
				break
			var e: Array = table[randi() % table.size()]
			out.append([String(e[0]), randi_range(int(e[1]), int(e[2]))])
		if Game.perks.has("scrounger") and not o.get("plain", false):
			out.append([["ammo_9", "ammo_rifle", "shells", "ammo_44"][randi() % 4], 6 + randi() % 8])
		var merged := {}
		for it in out:
			if it[0] == "caps" or Game.DB.items.has(it[0]):
				merged[it[0]] = int(merged.get(it[0], 0)) + int(it[1])
		var items := []
		for k in merged:
			var c: int = merged[k]
			if k == "caps" and Game.perks.has("lucky_find"):
				c = ceili(c * 1.5)
			items.append([k, c])
		Game.opened[id] = items
	Sfx.play("k_creak", -6.0)
	main.hud.screens.open_loot(String(o.get("name", "Container")), Game.opened[id], func(_empty): pass)

# breaking into someone's property costs karma, and a guard who sees it comes for you
# Taking what isn't yours. Unseen, it costs a little karma. Seen (anyone nearby with a clear look at you, and how
# far they notice depends on how well you're sneaking) it costs more, and their people think less of you; get
# caught a third time and the owner stops warning you.
const CAUGHT := ["Hey! Put that back!", "Thief! I saw that.", "That's not yours, friend.", "Drop it. Now.", "I'm watching you."]
func _steal(what := "", owner := "") -> bool:
	var pp: Vector3 = main.player.global_position
	var vis: float = main.player.visibility()
	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	var seen = null
	for n in main.npcs:
		if not is_instance_valid(n) or not n.visible or n.get("hostile") == true or n.get("follow") == true:
			continue
		var dd: float = n.global_position.distance_to(pp)
		if dd > 13.0 * vis + 2.0:
			continue
		var q := PhysicsRayQueryParameters3D.create(n.global_position + Vector3.UP * 1.6, pp + Vector3.UP * 1.0, 1)
		q.exclude = [main.player.get_rid(), n.get_rid()]
		if space.intersect_ray(q).is_empty():
			seen = n
			if String(n.id) == owner:
				break
	if seen == null:
		Game.add_karma(-2, "Stole " + what if what != "" else "Stole")
		Game.msg("Nobody saw.")
		return false
	Game.add_karma(-6, "Caught stealing")
	var line: String = CAUGHT[randi() % CAUGHT.size()]
	Game.msg(String(seen.display_name) + ": \"" + line + "\"")
	main.speak(line, String(seen.id))
	var f = Game.STORY.get("npc_faction", {}).get(String(seen.id))
	if f != null:
		Game.rep(String(f), -2)
	Game.flags["caught"] = int(Game.flags.get("caught", 0)) + 1
	if int(Game.flags.caught) >= 3 and not String(seen.id) in main.ESSENTIAL and not String(seen.id) in main.CHILDREN:
		main.provoke(seen, 0.0, Vector3.FORWARD)
	return true

func _pickup(o: Dictionary) -> void:
	if o.get("owned"):
		_steal(Game.iname(o.item), String(o.owned))
	Game.looted["pk_" + String(o.id)] = true
	Game.give(String(o.item), int(o.get("qty", 1)))
	Sfx.play("k_cloth1", -4.0)
	Game.msg("Picked up " + Game.iname(o.item) + (" x" + str(int(o.qty)) if int(o.get("qty", 1)) > 1 else ""))
	if pickup_nodes.has(o.id):
		pickup_nodes[o.id].queue_free()
		pickup_nodes.erase(o.id)
	Game.check_quests()

func _terminal(o: Dictionary) -> void:
	Sfx.play("k_click", -8.0)
	var G := Game.G
	match String(o.kind):
		"lore":
			var l: Dictionary = Game.DB.lore.get(String(o.lore), {})
			var lk := term_lock(o)
			var lore := String(o.lore)
			var txt := String(l.get("t", ""))
			# long entries split at their blank lines into a menu of records
			var parts := txt.split("\n\n", false)
			var items: Array = []
			if parts.size() >= 3:
				for i in parts.size():
					items.append(["Record %d of %d" % [i + 1, parts.size()], parts[i]])
			else:
				items.append([String(l.get("h", "Entry")), txt])
			main.hud.term.open(String(l.get("h", "TERMINAL")), items, lk, String(o.id), func():
				if (lk == 0 or Game.opened.has("t_" + String(o.id))) and not Game.flags.has("read_" + lore):
					Game.flags["read_" + lore] = 1
					Game.add_xp(20)
					Game.check_quests())
		"tower":
			if G.questDone("static"):
				main.hud.screens.open_term("RELAY 4 // STATUS", "> CARRIER: ONLINE\n> POWER: 3/3 CELLS\n> LISTENERS: 3 SETTLEMENTS\n\nBroadcasting on all bands. Somebody out there is answering.")
			elif G.questActive("static") and Game.count("fusion_cell") >= 3:
				Game.take("fusion_cell", 3)
				Game.complete("static")
				Game.msg("The relay hums to life.")
			else:
				Game.msg("NO POWER. Insert 3 fusion cells. (" + str(Game.count("fusion_cell")) + "/3)")
		_:
			if not Game.killed.has("brute"):
				Game.msg("Something is in the way of that.")
			else:
				if not G.questKnown("meridian"):
					Game.start("meridian")
				main.start_dialog(null, "core")

# about a third of the valley's terminals are password-locked (never the ones in Haven 12, the relay or the core)
func term_lock(o: Dictionary) -> int:
	if Game.area == "vault" or String(o.get("kind", "")) != "lore" or o.has("lock"):
		return int(o.get("lock", 0))
	var h := absi(hash(String(o.id) + "lock"))
	if h % 100 < 62:
		return 0
	return 1 + h % 3

func _cross(o: Dictionary, col) -> void:
	# a door you have opened: step through it to the other side (the door model itself stays shut)
	var pp: Vector3 = main.player.global_position
	var n := Vector3(0, 0, 1)
	if col is Dictionary:
		n = Vector3(1, 0, 0) if float(col.x1) - float(col.x0) < float(col.z1) - float(col.z0) else Vector3(0, 0, 1)
	var c := Vector3(float(o.x), 0, float(o.z))
	var side := signf((pp - c).dot(n))
	if side == 0.0:
		side = 1.0
	var to := c - n * side * 1.3
	to.y = Game.height(to.x, to.z) + 0.2
	if o.has("y"):
		to.y = maxf(to.y, float(o.y) + 0.2)
	main.player.global_position = to
	main.player.velocity = Vector3.ZERO
	Sfx.play("k_door_open", -2.0)

func _ldoor(o: Dictionary) -> void:
	var id := String(o.id)
	if Game.opened.has("d_" + id):
		_cross(o, o.get("col"))
		return
	main.hud.screens.open_lock(int(o.get("lock", 0)), "Door", func(ok):
		if ok:
			Game.opened["d_" + id] = true
			Game.add_xp(10 + int(o.get("lock", 0)) * 10)
			if o.get("owned", false):
				_steal()
			_cross(o, o.get("col")))

func _core_door(o: Dictionary) -> void:
	if Game.flags.get("doorOpen"):
		_cross(o, o.get("collider"))
		return
	if not Game.has("keycard"):
		Game.msg("Sealed. Requires a Meridian Keycard.")
		Sfx.play("k_metal_click", -6.0)
		return
	Game.flags["doorOpen"] = true
	Sfx.play("o_hatch_open")
	Game.msg("The core chamber grinds open.")
	_cross(o, o.get("collider"))
	Game.check_quests()

# ---------------------------------------------------------------- quest points (pointLabel / pointUse in main.js)
func _qp(o: Dictionary) -> Dictionary:
	var id := String(o.id)
	var base := id
	while base.length() > 0 and base[base.length() - 1] >= "0" and base[base.length() - 1] <= "9":
		base = base.substr(0, base.length() - 1)
	return Game.L.get("points", {}).get(base, {})

func point_label(o: Dictionary) -> Variant:
	var id := String(o.id)
	var G := Game.G
	match id:
		"vaultExit":
			return "Go up to the surface" if Game.flags.get("leftVault") else "Open the great door"
		"recycler":
			return "Inspect the water recycler"
		"well":
			return "Draw a water sample" if not G.questDone("bad_water") and not G.has("sample_well") else "Drink from the well"
		"pool":
			return "Take a glowing water sample" if not G.questDone("bad_water") and not G.has("sample_glow") else null
		"board":
			return "Collect bounty" if G.qStage("bounty") == 1 else "Read bounty board"
	var qp := _qp(o)
	if qp.has("label"):
		var l = Game.vm.call_value(qp.label, [_pt(o)])
		return null if l == null else Game.vm.to_str(l)
	match id:
		"blackjack": return "Play blackjack"
		"roulette": return "Play roulette"
		"dice": return "Play dice"
		"patsyPanel": return "Open Old Patsy's service panel" if G.qStage("patsy") == 0 else null
		"buggy": return null
		"haven":
			if G.has("regulator") and Game.flags.get("coreChoice") == "scram":
				return "Deliver the regulator to Haven 12"
			return "Enter Haven 12" if Game.flags.get("leftVault") and not Game.flags.get("ending") else null
	if id.begins_with("slots"):
		return "Play Old Patsy" if id == "slots0" else "Play the slots"
	return null

# the object the original's label/use functions see
func _pt(o: Dictionary) -> Dictionary:
	var p := {}
	for k in o:
		if not String(k).begins_with("_"):
			p[k] = o[k]
	return p

func point_use(o: Dictionary) -> void:
	var id := String(o.id)
	var G := Game.G
	match id:
		"recycler":
			Game.msg("The regulator housing is split end to end. Pell has wrapped it in tape nine times.")
			Sfx.play("k_click", -8.0)
			return
		"vaultExit":
			if Game.flags.get("leftVault"):
				main.vault_travel(false)
			elif not Game.flags.get("metOverseer"):
				Game.msg("The Overseer wants to see you first. Her office is down the corridor.")
				Sfx.play("k_metal_click", -6.0)
			elif not Game.has("pipe_pistol"):
				Game.msg("Draw your gear from the Security locker before you go.")
				Sfx.play("k_metal_click", -6.0)
			else:
				main.leave_vault()
			return
		"well":
			if point_label(o) == "Drink from the well":
				Game.hp = minf(Game.hp_max, Game.hp + 6.0)
				Sfx.play("o_splash", -6.0)
				Game.msg("You haul up the bucket and drink. Gritty, slightly green.")
			else:
				Sfx.play("k_switch", -4.0)
				Game.give("sample_well", 1)
				Sfx.play("k_cloth1", -4.0)
				Game.msg("You crank the bucket up and fill a flask. The water is faintly green.")
				Game.check_quests()
			Game.stats_changed.emit()
			return
		"pool":
			Game.give("sample_glow", 1)
			Sfx.play("o_splash")
			Game.msg("You fill a flask at arm's length. It glows.")
			Game.check_quests()
			return
		"board":
			_board()
			return
		"haven":
			if G.has("regulator") and Game.flags.get("coreChoice") == "scram":
				Game.take("regulator", 1)
				Sfx.play("o_bigdoor")
				Game.finish("sealed")
			else:
				main.vault_travel(true)
			return
	var qp := _qp(o)
	if qp.has("label") and qp.has("use") and Game.vm.truthy(Game.vm.call_value(qp.label, [_pt(o)])):
		var p := _pt(o)
		Game.vm.call_value(qp.use, [p])
		for k in p:
			o[k] = p[k]
		Game.check_quests()
		return
	if id in ["blackjack", "roulette", "dice"]:
		main.hud.casino.open(id)
		return
	if id.begins_with("slots"):
		main.hud.casino.open("slots", int(id.substr(5)))
		return
	if id == "patsyPanel":
		if int(Game.stats.agility) < 5 and not G.has("gears"):
			Game.msg("The panel screws are seized. You need a steadier hand (Agility 5) or a spare gear to lever it.")
			Sfx.play("k_metal_click", -6.0)
			return
		Game.give("governor_chip", 1)
		Sfx.play("k_metal_latch", -2.0)
		Game.msg("Behind the panel, soldered across the payout line: a little board labelled GOVERNOR. You pocket it.")
		Game.check_quests()
	elif id == "buggy":
		Game.msg("A dune buggy with no engine, two flat tyres and a family of lizards in the seat. Brannock might know more.")

# the bounty board by the sheriff's office: one posted job at a time, paid on return
func _board() -> void:
	var G := Game.G
	Sfx.play("k_page", -4.0)
	if G.qStage("bounty") == 1:
		Game.complete("bounty")
		Game.flags.erase("bounty")
		return
	if G.questActive("bounty"):
		Game.msg(Game.stage_text("bounty"))
		return
	var list: Array = Game.L.get("bounties", [])
	if list.is_empty():
		return
	var b: Array = list[randi() % list.size()]
	var type := String(b[0])
	var pay := roundi(float(b[2]) * (1.0 + Game.level * 0.06))
	Game.flags["bounty"] = {"type": type, "n": int(b[1]), "base": int(Game.kills.get(type, 0)), "pay": pay}
	Game.start("bounty")
	Game.msg("Bounty: %d %ss for %d chits." % [int(b[1]), String(Game.DB.enemies.get(type, {}).get("n", type)), pay])
