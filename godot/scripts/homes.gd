class_name Homes
extends RefCounted
# Places of your own (build 25). Three houses are for sale in the valley: the Tinsmith's Shack at the east end of
# Cinder Gap, Row House Nine on Lantern Row and the Lockwood Place by the water at Stillwater. Each has a quest that
# comes with it (squatters to clear, a roof to mend, a deed to find), a seller in town, and a price that depends on
# how the town sees you: the faction's standing, a job done for the house, your karma and your Charisma.
#
# A house you own is yours to build up and furnish. Upgrades: a proper bed (you wake Well Rested), wall lockers (more
# room in the stash), a workbench, an armory, a water purifier and a planter (they fill the stash while you're away),
# companion bunks and a medicine cabinet. Furnishings: a rug, a table, a chair, shelves, something on the wall, a
# light and a keepsake, each chosen from a few. Companions can move in (two to a house, with the bunks): they live
# there while you travel, come along when you ask, and bring home what they find on their own wanderings.
#
# One stash serves every house you own (the lockers in one are the lockers in all: it's your things, wherever you
# sleep). Everything is kept in Game.homes and saved with the game.

const HOMES := {
	"cinder": {"n": "The Tinsmith's Shack", "town": "Cinder Gap", "fac": "cinder", "price": 650, "x": 846.0, "z": -53.0, "r": 0,
		"seller": "Mags Tinley", "quest": "squatters_rights", "qcut": 0.25},
	"lantern": {"n": "Row House Nine", "town": "Lantern Row", "fac": "lamplight", "price": 520, "x": 623.0, "z": 134.0, "r": 2,
		"seller": "Orla Penn", "quest": "roof_over_head", "qcut": 0.3},
	"stillwater": {"n": "The Lockwood Place", "town": "Stillwater", "fac": "stillwater", "price": 580, "x": -24.0, "z": -752.0, "r": 1,
		"seller": "Deacon Hale", "quest": "lockwood_deed", "qcut": 0.75},
}
const W := 8.0
const D := 7.0
const FL := 0.16
const HW := W * 0.5 - 0.35
const HD := D * 0.5 - 0.35

const UPGRADES := {
	"bed": {"n": "A proper bed", "cost": 160, "desc": "A real double bed with a frame and a mattress that isn't straw. You wake Well Rested: a while of quicker learning (more XP)."},
	"lockers": {"n": "Wall lockers", "cost": 200, "desc": "A bank of steel lockers on the back wall. The stash holds 250 lbs more (in every house you own)."},
	"bench": {"n": "Workbench", "cost": 240, "desc": "A bench with a vice and a rack of tools: craft and work on your gear at home."},
	"armory": {"n": "Armory", "cost": 220, "desc": "A gun rack and an armour stand on the side wall, and a lockable rack of its own for weapons and armour, no weight limit."},
	"purifier": {"n": "Water purifier", "cost": 320, "desc": "A filter tank plumbed to the roof gutter. Three bottles of purified water a day go into the stash."},
	"garden": {"n": "Planter and grow lamp", "cost": 180, "desc": "A planter of prickly pear and herbs under a lamp. Two pickings a day go into the stash."},
	"bunks": {"n": "Companion bunks", "cost": 200, "desc": "A two-tier bunk and a pair of lockers. Up to two companions can live here, and they bring home what they find."},
	"medbay": {"n": "Medicine cabinet", "cost": 260, "desc": "A stocked cabinet over the bed. A night at home also flushes out a good part of your radiation."},
}
const UP_ORDER := ["bed", "lockers", "bench", "armory", "purifier", "garden", "bunks", "medbay"]

# furnishing slots: what can go there, and what each costs (the first is the bare slot)
const FURNISH := {
	"rug": {"n": "Rug", "opts": [["Bare boards", "", 0], ["Woven rug", "rug_woven", 35], ["Patchwork rug", "rug_patch", 25], ["Old red rug", "rug_red", 60]]},
	"table": {"n": "Table", "opts": [["No table", "", 0], ["Kitchen table and chairs", "WoodenTable_03", 80], ["Low table and footstools", "CoffeeTable_01", 45]]},
	"seat": {"n": "Chair", "opts": [["Nowhere to sit", "", 0], ["Armchair", "ArmChair_01", 70], ["Rocking chair", "Rockingchair_01", 60], ["Old couch", "k:q_Couch", 90], ["Green chair", "GreenChair_01", 40]]},
	"shelf": {"n": "Shelves", "opts": [["Bare wall", "", 0], ["Plank shelf", "Shelf_01", 40], ["Bookcase", "modern_bookshelf", 75], ["Sideboard", "modern_sideboard", 65]]},
	"wall": {"n": "On the wall", "opts": [["Nothing", "", 0], ["A framed picture", "fancy_picture_frame_01", 30], ["Dartboard", "dartboard", 25], ["Wall clock", "wall_clock", 35], ["Mirror", "ornate_mirror_01", 45]]},
	"light": {"n": "Light", "opts": [["An oil lantern", "Lantern_01", 0], ["Caged lamp", "caged_hanging_light", 40], ["Lantern chandelier", "lantern_chandelier_01", 90]]},
	"keepsake": {"n": "Keepsake", "opts": [["Nothing", "", 0], ["Chess set", "chess_set", 30], ["A vase", "ceramic_vase_02", 20], ["Oil lamp", "vintage_oil_lamp", 25], ["Brass pot", "brass_pot_01", 15]]},
}
const FURN_ORDER := ["rug", "table", "seat", "shelf", "wall", "light", "keepsake"]

# what a companion living with you brings home, a day at a time
const FINDS := {
	"jory": [["stew", 1, "a pot of stew"], ["stimpak", 1, "a stimpak"], ["purified_water", 2, "two bottles of water"]],
	"sable": [["caps", 30, "a purse of caps"], ["bobby_pin", 3, "a few bobby pins"], ["circuit", 1, "a circuit board"]],
	"renn2": [["ammo_9", 18, "a box of 9mm"], ["ammo_44", 8, ".44 rounds"], ["scrap_metal", 2, "scrap metal"]],
	"biscuit": [["boar_hide", 1, "a boar hide"], ["scrap_metal", 1, "a chewed bit of metal"], ["vulture_quill", 2, "vulture quills"]],
}
const BASE_CAP := 150.0
const LOCKER_CAP := 250.0

static var interiors := {}        # home id -> its shack node (while the world is loaded)

# ================================================================ state
static func S() -> Dictionary:
	if not (Game.homes is Dictionary):
		Game.homes = {}
	if not Game.homes.has("owned"):
		Game.homes["owned"] = {}
	if not Game.homes.has("stash"):
		Game.homes["stash"] = []
	if not Game.homes.has("armory"):
		Game.homes["armory"] = []
	if not Game.homes.has("orig"):
		Game.homes["orig"] = {}
	return Game.homes

# after a load: JSON brings every number back as a float
static func normalize() -> void:
	var s := S()
	for list in [s.stash, s.armory]:
		for it in list:
			it[1] = int(it[1])
	for id in s.owned:
		var h: Dictionary = s.owned[id]
		h["day"] = int(h.get("day", 1))
		h["last"] = int(h.get("last", 1))

static func owns(id: String) -> bool:
	return S().owned.has(id)

static func owns_any() -> bool:
	return not S().owned.is_empty()

static func H(id: String) -> Dictionary:
	return S().owned.get(id, {})

static func has_up(id: String, k: String) -> bool:
	return owns(id) and bool(H(id).get("up", {}).get(k, false))

static func any_up(k: String) -> bool:
	for id in S().owned:
		if has_up(String(id), k):
			return true
	return false

# pieces you've chosen yourself (the oil lantern every house comes with doesn't count)
static func furnished_count() -> int:
	var n := 0
	for id in S().owned:
		for s in H(String(id)).get("furn", {}):
			var v := String(H(String(id)).furn[s])
			if v != "" and not (s == "light" and v == "Lantern_01"):
				n += 1
	return n

static func residents() -> Array:
	var out: Array = []
	for id in S().owned:
		for c in H(String(id)).get("res", []):
			out.append(String(c))
	return out

static func home_of(comp: String) -> String:
	for id in S().owned:
		if String(comp) in H(String(id)).get("res", []):
			return String(id)
	return ""

# ================================================================ prices
# the parts of a price: [why, fraction off (or on, if negative)]; refused when the town won't deal with you at all
static func quote(id: String) -> Dictionary:
	var h: Dictionary = HOMES[id]
	var parts: Array = []
	var off := 0.0
	var fac := String(h.fac)
	var r := Game.rep_of(fac)
	var fname := String(Game.STORY.get("factions", {}).get(fac, {}).get("n", h.town))
	if r <= -6:
		return {"refused": true, "why": "%s won't sell to someone they hate." % fname, "price": 0, "parts": []}
	var fo := faction_cut(fac)
	if fo != 0.0:
		parts.append(["%s see you as %s" % [fname, Game.rep_title(r).to_lower()], fo])
		off += fo
	if Game.is_done(String(h.quest)):
		parts.append(["You did right by the house", float(h.qcut)])
		off += float(h.qcut)
	if Game.flags.get("haggle_" + id, false):
		parts.append(["You haggled", 0.1])
		off += 0.1
	var k := int(Game.karma)
	if k >= 250:
		parts.append(["Your good name", 0.05])
		off += 0.05
	elif k <= -250:
		parts.append(["Your bad name", -0.1])
		off -= 0.1
	var ch := int(Game.stats.get("charm", 5))
	if ch != 5:
		var co := (ch - 5) * 0.02
		parts.append(["Charisma %d" % ch, co])
		off += co
	off = clampf(off, -0.4, 0.8)
	return {"refused": false, "price": maxi(60, int(round(float(h.price) * (1.0 - off)))), "parts": parts, "base": int(h.price), "off": off}

# a town's goodwill towards you, as a cut on what you buy there
static func faction_cut(fac: String) -> float:
	var r := Game.rep_of(fac)
	if r <= -2:
		return -0.2
	if r <= 1:
		return 0.0
	if r <= 5:
		return 0.1
	if r <= 9:
		return 0.2
	return 0.3

static func up_cost(id: String, k: String) -> int:
	return maxi(10, int(round(float(UPGRADES[k].cost) * (1.0 - faction_cut(String(HOMES[id].fac)) * 0.75))))

static func furn_cost(id: String, base: int) -> int:
	if base <= 0:
		return 0
	return maxi(5, int(round(float(base) * (1.0 - faction_cut(String(HOMES[id].fac)) * 0.75))))

# ================================================================ buying, building up, furnishing
static func buy(id: String) -> bool:
	if owns(id):
		return false
	var q := quote(id)
	if q.refused:
		Game.msg(String(q.why))
		return false
	if Game.caps < int(q.price):
		Game.msg("You need %d caps for %s." % [int(q.price), String(HOMES[id].n)])
		return false
	Game.caps -= int(q.price)
	S().owned[id] = {"day": Game.day, "last": Game.day, "up": {}, "furn": {"light": "Lantern_01"}, "res": []}
	Game.banner("HOME", "%s is yours" % String(HOMES[id].n))
	Sfx.play("o_quest")
	Game.flags["home_" + id] = 1
	if not Game.known("housewarming"):
		Game.start("housewarming")
	dress(id)
	Game.stats_changed.emit()
	Game.check_quests()
	return true

static func buy_up(id: String, k: String) -> bool:
	if not owns(id) or has_up(id, k):
		return false
	var c := up_cost(id, k)
	if Game.caps < c:
		Game.msg("You need %d caps for that." % c)
		return false
	Game.caps -= c
	H(id)["up"][k] = true
	Game.msg("%s: %s put in." % [String(HOMES[id].n), String(UPGRADES[k].n).to_lower()])
	Sfx.play("k_metal_latch", -4.0)
	dress(id)
	Game.stats_changed.emit()
	Game.check_quests()
	return true

static func furnish(id: String, slot: String, opt: int) -> bool:
	if not owns(id):
		return false
	var o: Array = FURNISH[slot].opts[opt]
	var cur := String(H(id).get("furn", {}).get(slot, ""))
	if cur == String(o[1]):
		return false
	var c := furn_cost(id, int(o[2]))
	if Game.caps < c:
		Game.msg("You need %d caps for that." % c)
		return false
	Game.caps -= c
	H(id)["furn"][slot] = String(o[1])
	Sfx.play("k_drop", -6.0)
	dress(id)
	Game.stats_changed.emit()
	Game.check_quests()
	return true

# ================================================================ the stash, and what fills it while you're away
static func stash_weight(list: Array) -> float:
	var w := 0.0
	for it in list:
		if String(it[0]) != "caps":
			w += float(Game.item(String(it[0])).get("w", 0.5)) * int(it[1])
	return w

static func stash_cap() -> float:
	return BASE_CAP + (LOCKER_CAP if any_up("lockers") else 0.0)

static func _put_in(list: Array, item: String, n: int) -> void:
	for it in list:
		if String(it[0]) == item:
			it[1] = int(it[1]) + n
			return
	list.append([item, n])

# days since you were last home: the purifier, the planter and the people living here have been busy (up to a week)
static func collect(id: String) -> Array:
	var h := H(id)
	if h.is_empty():
		return []
	var days := clampi(Game.day - int(h.get("last", Game.day)), 0, 7)
	h["last"] = Game.day
	var notes: Array = []
	if days <= 0:
		return notes
	var st: Array = S().stash
	if has_up(id, "purifier"):
		_put_in(st, "purified_water", 3 * days)
		notes.append("The purifier filled %d bottles." % (3 * days))
	if has_up(id, "garden"):
		for d in days:
			_put_in(st, ["prickly_pop", "med_herbs", "prickly_pop"][(Game.day + d) % 3], 2)
		notes.append("The planter gave %d pickings." % (2 * days))
	for c in h.get("res", []):
		var cid := String(c)
		if Game.main and Game.main.party.any(func(p): return String(p.id) == cid):
			continue
		var f: Array = FINDS.get(cid, [["scrap_metal", 1, "some scrap"]])
		var got: Array = []
		for d in days:
			var pick: Array = f[(hash(cid) + Game.day + d) % f.size()]
			_put_in(st, String(pick[0]), int(pick[1]))
			got.append(String(pick[2]))
		var nm := String(Game.L.get("companions", {}).get(cid, {}).get("n", cid)).split(" ")[0]
		notes.append("%s brought home %s." % [nm, ", ".join(got.slice(0, 3)) + (" and more" if got.size() > 3 else "")])
	return notes

static func open_stash(id: String) -> void:
	var hud = Game.main.hud
	for n in collect(id):
		Game.msg(String(n))
	hud.screens.loot_cap = stash_cap()
	hud.screens.open_loot("Home stash  (%.0f / %.0f lbs)" % [stash_weight(S().stash), stash_cap()], S().stash, func(_e): pass)

static func open_armory(_id: String) -> void:
	var hud = Game.main.hud
	hud.screens.loot_only = ["weapon", "armor", "ammo"]
	hud.screens.open_loot("Armory", S().armory, func(_e): pass)

# a night in your own bed: morning, full health, the game saved; better with the upgrades
static func sleep(id: String) -> void:
	var gapi = Game.vm.globals.vars.G if Game.vm else null
	if Game.time > 0.25:
		Game.day += 1
	Game.time = 0.27
	Game.hp = Game.hp_max
	var lines: Array = ["You sleep in your own bed until morning. Health restored."]
	if has_up(id, "bed"):
		var amt := 1.15 if Game.is_done("housewarming") else 1.1
		Game.buffs["xp"] = {"amt": amt, "t": 1800.0, "n": "Well Rested"}
		lines.append("You wake Well Rested (+%d%% XP for a while)." % int(round((amt - 1.0) * 100.0)))
	if has_up(id, "medbay") and Game.rad > 0.0:
		var was := Game.rad
		Game.rad = maxf(0.0, Game.rad - 40.0)
		lines.append("The medicine cabinet takes %d rads off you." % int(was - Game.rad))
	Game.flags["home_slept"] = 1
	for l in lines:
		Game.msg(String(l))
	Sfx.play("o_levelup", -10.0, 0.8)
	Game.stats_changed.emit()
	Game.check_quests()
	Game.save_game("auto")
	if gapi == null:
		pass

# ================================================================ companions living with you
static func cap_res(id: String) -> int:
	return 2 if has_up(id, "bunks") else 0

static func bunk_spot(id: String, i: int) -> Vector3:
	return world(id, Vector3(-HW + 1.35, FL, 0.6 + i * 1.0))

static func move_in(id: String, comp: String) -> bool:
	if not owns(id) or cap_res(id) <= H(id).get("res", []).size():
		Game.msg("There's no bunk free here.")
		return false
	var other := home_of(comp)
	if other != "":
		H(other).res.erase(comp)
	if Game.main and Game.main.party.any(func(p): return String(p.id) == comp):
		Game.main.dismiss(comp, true)
	H(id)["res"].append(comp)
	place_resident(comp)
	var nm := String(Game.L.get("companions", {}).get(comp, {}).get("n", comp))
	Game.msg("%s moves into %s." % [nm, String(HOMES[id].n)])
	Game.approve(comp, 5, "A place of their own.")
	Game.check_quests()
	return true

static func move_out(comp: String) -> void:
	var id := home_of(comp)
	if id == "":
		return
	H(id).res.erase(comp)
	var o = S().orig.get(comp)
	if o is Array and Game.main:
		Game.main.relocate_npc(comp, float(o[0]), float(o[1]))
	S().orig.erase(comp)
	Game.msg("%s goes back to where they lived before." % String(Game.L.get("companions", {}).get(comp, {}).get("n", comp)))

static func bring(comp: String) -> void:
	if Game.main:
		Game.main.recruit(comp)

# where a resident is to be found: their bunk (the NPC's home spot, saved apart from where they used to live)
static func place_resident(comp: String) -> void:
	var id := home_of(comp)
	if id == "" or Game.main == null:
		return
	var i: int = H(id).res.find(comp)
	var at := bunk_spot(id, maxi(0, i))
	if not S().orig.has(comp):
		var idx: int = Game.main._npc_index(comp)
		if idx >= 0:
			var d: Dictionary = Game.region.npcs[idx]
			S().orig[comp] = [float(d.x), float(d.z)]
	Game.main.relocate_npc(comp, at.x, at.z)

# at the start of a game (or after a load), before anyone is spawned: residents are at home
static func apply_residents() -> void:
	if Game.area != "world":
		return
	for comp in residents():
		var id := home_of(comp)
		var i: int = H(id).res.find(comp)
		var at := bunk_spot(id, maxi(0, i))
		for d in Game.region.npcs:
			if String(d.id) == comp:
				if not S().orig.has(comp):
					S().orig[comp] = [float(d.x), float(d.z)]
				d["x"] = at.x
				d["z"] = at.z
				d["wander"] = null

# ================================================================ the house itself
static func basis(id: String) -> Basis:
	return Basis(Vector3.UP, int(HOMES[id].r) * PI * 0.5)

static func world(id: String, local: Vector3) -> Vector3:
	var h: Dictionary = HOMES[id]
	var g := Frontier._ground({"k": "shack", "x": h.x, "z": h.z, "r": h.r, "w": W, "d": D})
	return Vector3(float(h.x), g, float(h.z)) + basis(id) * local

static func world_dir(id: String, v: Vector3) -> Vector3:
	return basis(id) * v

# the shack's own frontier node is handed over when it's built: the house is dressed to what you've done to it
static func adopt(id: String, n: Node3D) -> void:
	interiors[id] = n
	dress(id)
	_points(id)

static func _points(id: String) -> void:
	if Game.main == null or Game.main.get("objects") == null:
		return
	var objs = Game.main.objects
	var g: float = world(id, Vector3.ZERO).y
	var pts := {
		"sale": Vector3(-2.05, 0, HD + 1.4),
		"ledger": Vector3(-0.95, 0, HD - 0.35),
		"bed": Vector3(-HW + 0.8, 0, -HD + 1.2),
		"stash": Vector3(-HW + 0.85, 0, -HD + 2.55),
		"bench": Vector3(HW - 0.95, 0, -HD + 1.0),
		"armory": Vector3(HW - 0.6, 0, -0.2),
	}
	for k in pts:
		var wp := world(id, pts[k])
		var pid := "home:%s:%s" % [id, k]
		for kk in objs.grid:
			for o in (objs.grid[kk] as Array).duplicate():
				if String(o.get("id", "")) == pid:
					objs.grid[kk].erase(o)
		objs.add_dynamic({"_k": "point", "id": pid, "x": wp.x, "z": wp.z, "y": g + FL if k != "sale" else Game.height(wp.x, wp.z), "r": 2.2 if k != "sale" else 2.8})

static func label(o: Dictionary) -> Variant:
	var p := String(o.id).split(":")
	if p.size() < 3 or not HOMES.has(p[1]):
		return null
	var id := p[1]
	var h: Dictionary = HOMES[id]
	match p[2]:
		"sale":
			if owns(id):
				return null
			return "Read the notice on the door (FOR SALE)"
		"ledger":
			return "Your home: upgrades, furnishings, who lives here" if owns(id) else null
		"bed":
			return "Sleep in your own bed" if owns(id) else null
		"stash":
			return "Open the home stash" if owns(id) else null
		"bench":
			return "Use your workbench" if has_up(id, "bench") else null
		"armory":
			return "Open the armory" if has_up(id, "armory") else null
	return null

static func use(o: Dictionary) -> void:
	var p := String(o.id).split(":")
	var id := p[1]
	var h: Dictionary = HOMES[id]
	match p[2]:
		"sale":
			var q := quote(id)
			if q.refused:
				Game.msg("FOR SALE: %s. %s" % [String(h.n), String(q.why)])
			else:
				Game.msg("FOR SALE: %s, %s. Enquire with %s. Asking %d caps; to you, %d." % [String(h.n), String(h.town), String(h.seller), int(h.price), int(q.price)])
		"ledger":
			Game.main.hud.screens.open_home(id)
		"bed":
			sleep(id)
		"stash":
			open_stash(id)
		"bench":
			Game.main.hud.open_craft(true)
		"armory":
			open_armory(id)

# ---------------------------------------------------------------- dressing the house
static func dress(id: String) -> void:
	var n: Node3D = interiors.get(id)
	if n == null or not is_instance_valid(n):
		return
	var old := n.get_node_or_null("HomeDress")
	if old:
		old.name = "HomeDressOld"
		old.queue_free()
	var root := Node3D.new()
	root.name = "HomeDress"
	n.add_child(root)
	var owned := owns(id)
	# the sale notice on the door while it's for sale; a name board when it's yours
	# beside the door, at eye height: a board with the notice (or the house's name) painted on
	var sx := -2.05
	var sign := Frontier.Kit.new()
	sign.box("plank", Vector3(sx, 1.45, D * 0.5 + 0.1), Vector3(0.95, 0.55, 0.03), 0)
	for yy in [1.19, 1.71]:
		sign.box("plank_dk", Vector3(sx, yy, D * 0.5 + 0.12), Vector3(0.99, 0.04, 0.03), 0)
	var sc := Node3D.new()
	root.add_child(sc)
	sign.commit(sc)
	var big := Label3D.new()
	big.text = "FOR SALE" if not owned else String(HOMES[id].n).to_upper()
	big.font_size = 44 if not owned else 26
	big.pixel_size = 0.004
	big.width = 220.0
	big.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	big.modulate = Color(0.45, 0.07, 0.04) if not owned else Color(0.16, 0.1, 0.05)
	big.outline_size = 0
	big.position = Vector3(sx, 1.52 if not owned else 1.45, D * 0.5 + 0.125)
	root.add_child(big)
	if not owned:
		var small := Label3D.new()
		small.text = "see %s" % String(HOMES[id].seller)
		small.font_size = 22
		small.pixel_size = 0.004
		small.modulate = Color(0.14, 0.09, 0.05)
		small.outline_size = 0
		small.position = Vector3(sx, 1.33, D * 0.5 + 0.125)
		root.add_child(small)
	if not owned:
		# empty and gone to seed: a broken crate, a bedroll, dust
		_f(root, "k:q_Pallet_Broken", Vector3(HW - 0.7, FL, -HD + 0.6), 0.3)
		_f(root, "k:q_TrashBag_1", Vector3(-HW + 0.5, FL, HD - 0.6), 0.0)
		return
	var H0 := H(id)
	var up: Dictionary = H0.get("up", {})
	var furn: Dictionary = H0.get("furn", {})
	# --- the bed
	if up.get("bed", false):
		_bed(root, Vector3(-HW + 0.85, FL, -HD + 1.1))
		_f(root, "ClassicNightstand_01", Vector3(-HW + 1.95, FL, -HD + 0.3), 0.0)
	else:
		_cot(root, Vector3(-HW + 0.5, FL, -HD + 1.05))
		_f(root, "ClassicNightstand_01", Vector3(-HW + 1.25, FL, -HD + 0.3), 0.0)
	var ns_x := -HW + (1.95 if up.get("bed", false) else 1.25)
	var ns_top := FL + Furniture.aabb("ClassicNightstand_01").end.y
	# --- the stash: a footlocker at the foot of the bed
	_footlocker(root, Vector3(-HW + 0.85, FL, -HD + 2.55))
	# --- upgrades
	if up.get("lockers", false):
		for i in 3:
			_locker(root, Vector3(-0.45 + i * 0.45, FL, -HD + 0.24))
	if up.get("medbay", false):
		_medcab(root, Vector3(-HW + 0.9, FL + 1.35, -HD + 0.07))
	if up.get("bench", false):
		var fg := Forge.new()
		var b: Node3D = fg.build("bench", -1)
		fg.free()
		root.add_child(b)
		b.position = Vector3(HW - 0.95, FL, -HD + 0.5)
	if up.get("armory", false):
		_armory(root, Vector3(HW - 0.1, FL, -0.2))
	if up.get("purifier", false):
		_purifier(root, Vector3(HW - 0.55, FL, HD - 0.6))
	if up.get("garden", false):
		_planter(root, Vector3(-HW + 0.5, FL, HD - 0.55))
	if up.get("bunks", false):
		_bunk(root, Vector3(-HW + 0.45, FL, 1.25))
	# --- furnishings
	match String(furn.get("rug", "")):
		"rug_woven": _rug(root, Vector3(0.3, FL, 0.2), Vector2(2.2, 1.5), Color(0.55, 0.42, 0.26), Color(0.32, 0.18, 0.1))
		"rug_patch": _rug(root, Vector3(0.3, FL, 0.2), Vector2(2.0, 1.4), Color(0.36, 0.42, 0.38), Color(0.5, 0.32, 0.22))
		"rug_red": _rug(root, Vector3(0.3, FL, 0.2), Vector2(2.4, 1.6), Color(0.45, 0.12, 0.08), Color(0.62, 0.48, 0.25))
	var t := String(furn.get("table", ""))
	if t == "WoodenTable_03":
		_f(root, t, Vector3(0.9, FL, 0.1), 0.0)
		_f(root, "SchoolChair_01", Vector3(0.9, FL, -0.65), 0.0)
		_f(root, "SchoolChair_01", Vector3(0.9, FL, 0.85), PI)
	elif t == "CoffeeTable_01":
		_f(root, t, Vector3(0.6, FL, 0.3), 0.0)
		_f(root, "Ottoman_01", Vector3(0.6, FL, -0.45), 0.0)
		_f(root, "Ottoman_01", Vector3(0.6, FL, 1.05), 0.0)
	var s := String(furn.get("seat", ""))
	if s != "":
		_f(root, s, Vector3(-0.6, FL, 1.9), PI * 0.85)
	var sh := String(furn.get("shelf", ""))
	if sh != "":
		var shn := _f(root, sh, Vector3(-1.75, FL, HD - 0.22), PI)
		if sh == "modern_bookshelf" and shn:
			_f(root, "book_encyclopedia_set_01", Vector3(-1.75, FL + 1.05, HD - 0.25), PI)
	var wl := String(furn.get("wall", ""))
	if wl != "":
		_f(root, wl, Vector3(1.25, FL + 1.5, -HD + 0.04), 0.0)
	var lt := String(furn.get("light", "Lantern_01"))
	if lt == "Lantern_01" or lt == "":
		_f(root, "Lantern_01", Vector3(ns_x - 0.12, ns_top, -HD + 0.26), 0.0, true)
	else:
		var hang := Furniture.hang(lt, 2.7, FL, true)
		root.add_child(hang)
		hang.position = Vector3(0.2, 2.7, 0.2)
	var ks := String(furn.get("keepsake", ""))
	if ks != "":
		if t != "":
			var top := FL + Furniture.aabb(t).end.y
			_f(root, ks, Vector3(0.9 if t == "WoodenTable_03" else 0.6, top, 0.15), 0.4)
		else:
			_f(root, ks, Vector3(ns_x + 0.12, ns_top, -HD + 0.3), 0.4)

static func _f(root: Node3D, id: String, at: Vector3, yaw: float, lit := false) -> Node3D:
	if id == "":
		return null
	var f := Furniture.make(id, lit)
	root.add_child(f)
	f.position = at
	f.rotation.y = yaw
	return f

static func _box(kit: Frontier.Kit, m: String, at: Vector3, sz: Vector3, solid := 0) -> void:
	kit.box(m, at, sz, solid)

static func _cot(root: Node3D, at: Vector3) -> void:
	var kit := Frontier.Kit.new()
	kit.box("metal", at + Vector3(0, 0.3, 0), Vector3(0.8, 0.06, 1.9), 2)
	for c in [Vector2(-0.36, -0.9), Vector2(0.36, -0.9), Vector2(-0.36, 0.9), Vector2(0.36, 0.9)]:
		kit.box("metal", at + Vector3(c.x, 0.15, c.y), Vector3(0.05, 0.3, 0.05), 0)
	kit.box("mattress", at + Vector3(0, 0.4, 0), Vector3(0.72, 0.14, 1.8), 0)
	kit.box("mattress", at + Vector3(0, 0.5, -0.72), Vector3(0.5, 0.1, 0.3), 0)
	_commit(kit, root, "Cot")

# a double bed: a plank frame with a headboard, a mattress, two pillows, a blanket folded back
static func _bed(root: Node3D, at: Vector3) -> void:
	var kit := Frontier.Kit.new()
	kit.box("plank_dk", at + Vector3(0, 0.22, 0.05), Vector3(1.5, 0.1, 2.05), 2)
	for c in [Vector2(-0.7, -0.95), Vector2(0.7, -0.95), Vector2(-0.7, 1.05), Vector2(0.7, 1.05)]:
		kit.box("plank_dk", at + Vector3(c.x, 0.11, c.y), Vector3(0.08, 0.22, 0.08), 0)
	kit.box("plank_dk", at + Vector3(0, 0.6, -0.98), Vector3(1.56, 0.9, 0.07), 2)
	kit.box("plank", at + Vector3(0, 1.08, -0.98), Vector3(1.62, 0.07, 0.1), 0)
	kit.box("mattress", at + Vector3(0, 0.37, 0.05), Vector3(1.4, 0.2, 1.95), 0)
	kit.box("cloth_white", at + Vector3(-0.35, 0.53, -0.72), Vector3(0.55, 0.12, 0.32), 0)
	kit.box("cloth_white", at + Vector3(0.35, 0.53, -0.72), Vector3(0.55, 0.12, 0.32), 0)
	kit.box("cloth_red", at + Vector3(0, 0.49, 0.35), Vector3(1.44, 0.06, 1.3), 0)
	kit.box("cloth_red", at + Vector3(0, 0.53, -0.28), Vector3(1.44, 0.1, 0.22), 0)
	_commit(kit, root, "Bed")

static func _footlocker(root: Node3D, at: Vector3) -> void:
	var kit := Frontier.Kit.new()
	kit.box("army", at + Vector3(0, 0.22, 0), Vector3(0.9, 0.42, 0.5), 2)
	kit.box("army_dk", at + Vector3(0, 0.45, 0), Vector3(0.92, 0.05, 0.52), 0)
	for x in [-0.36, 0.36]:
		kit.box("metal", at + Vector3(x, 0.24, 0), Vector3(0.05, 0.46, 0.54), 0)
	kit.box("brass", at + Vector3(0, 0.36, 0.26), Vector3(0.09, 0.08, 0.02), 0)
	_commit(kit, root, "Footlocker")

static func _locker(root: Node3D, at: Vector3) -> void:
	var kit := Frontier.Kit.new()
	kit.box("steel_blue", at + Vector3(0, 0.95, 0), Vector3(0.42, 1.9, 0.42), 2)
	for y in [1.55, 1.62, 1.69]:
		kit.box("metal_dk", at + Vector3(0, y, 0.215), Vector3(0.28, 0.02, 0.01), 0)
	kit.box("metal", at + Vector3(0.14, 1.0, 0.22), Vector3(0.03, 0.12, 0.02), 0)
	_commit(kit, root, "Locker")

static func _medcab(root: Node3D, at: Vector3) -> void:
	var kit := Frontier.Kit.new()
	kit.box("paint_white", at + Vector3(0, 0.3, 0.08), Vector3(0.6, 0.6, 0.16), 0)
	kit.box("cloth_red", at + Vector3(0, 0.32, 0.165), Vector3(0.2, 0.06, 0.01), 0)
	kit.box("cloth_red", at + Vector3(0, 0.32, 0.165), Vector3(0.06, 0.2, 0.01), 0)
	_commit(kit, root, "MedCabinet")

static func _armory(root: Node3D, at: Vector3) -> void:
	var kit := Frontier.Kit.new()
	# a pegboard rack on the wall with three long guns, and an armour stand beside it
	kit.box("plank_dk", at + Vector3(-0.04, 1.25, 0), Vector3(0.06, 1.0, 1.4), 0)
	for i in 3:
		var z := -0.45 + i * 0.45
		kit.box("metal_dk", at + Vector3(-0.12, 1.25, z), Vector3(0.06, 0.9, 0.07), 0)
		kit.box("plank", at + Vector3(-0.12, 0.88, z), Vector3(0.07, 0.25, 0.1), 0)
		kit.box("metal", at + Vector3(-0.15, 1.08, z), Vector3(0.05, 0.08, 0.05), 0)
	kit.box("plank_dk", at + Vector3(-0.4, 0.04, 1.2), Vector3(0.45, 0.06, 0.45), 2)
	kit.box("metal", at + Vector3(-0.4, 0.75, 1.2), Vector3(0.05, 1.4, 0.05), 0)
	kit.box("army", at + Vector3(-0.4, 1.2, 1.2), Vector3(0.48, 0.55, 0.26), 0)
	kit.box("army_dk", at + Vector3(-0.4, 1.48, 1.2), Vector3(0.6, 0.08, 0.3), 0)
	_commit(kit, root, "Armory")

static func _purifier(root: Node3D, at: Vector3) -> void:
	var kit := Frontier.Kit.new()
	kit.cyl("steel_blue", at + Vector3(0, 0.6, 0), 0.32, 0.32, 1.2, 14, 2)
	kit.cyl("metal_dk", at + Vector3(0, 1.22, 0), 0.34, 0.3, 0.06, 14, 0)
	kit.box("metal", at + Vector3(0, 1.75, 0), Vector3(0.06, 1.0, 0.06), 0)
	kit.box("metal", at + Vector3(0.3, 0.3, 0.2), Vector3(0.3, 0.04, 0.04), 0)
	kit.box("brass", at + Vector3(0.42, 0.3, 0.2), Vector3(0.06, 0.08, 0.06), 0)
	kit.box("glass_green", at + Vector3(-0.28, 0.75, 0.2), Vector3(0.02, 0.5, 0.1), 0)
	_commit(kit, root, "Purifier")

static func _planter(root: Node3D, at: Vector3) -> void:
	var kit := Frontier.Kit.new()
	kit.box("plank", at + Vector3(0, 0.2, 0), Vector3(0.9, 0.4, 0.55), 2)
	kit.box("soil", at + Vector3(0, 0.39, 0), Vector3(0.82, 0.04, 0.47), 0)
	for i in 5:
		var p := at + Vector3(-0.3 + i * 0.15, 0.55, -0.1 + (i % 2) * 0.2)
		kit.cyl("leaf", p, 0.01, 0.09, 0.3, 6, 0)
		kit.cyl("leaf", p + Vector3(0.03, 0.1, 0.0), 0.0, 0.07, 0.2, 6, 0)
	kit.box("metal", at + Vector3(0, 1.3, -0.22), Vector3(0.04, 1.8, 0.04), 0)
	kit.box("metal_dk", at + Vector3(0, 1.0, 0), Vector3(0.6, 0.05, 0.14), 0)
	_commit(kit, root, "Planter")
	var l := OmniLight3D.new()
	l.light_color = Color(0.85, 0.75, 1.0)
	l.light_energy = 0.5
	l.omni_range = 1.6
	root.add_child(l)
	l.position = at + Vector3(0, 0.9, 0)

static func _bunk(root: Node3D, at: Vector3) -> void:
	# two cots stacked on posts along the side wall, a ladder at the foot, a blanket on each
	var kit := Frontier.Kit.new()
	for y in [0.35, 1.35]:
		kit.box("metal", at + Vector3(0, y, 0), Vector3(0.8, 0.06, 1.9), 2 if y < 1.0 else 0)
		kit.box("mattress", at + Vector3(0, y + 0.1, 0), Vector3(0.72, 0.14, 1.8), 0)
		kit.box("mattress", at + Vector3(0, y + 0.2, -0.72), Vector3(0.5, 0.1, 0.3), 0)
		kit.box("army", at + Vector3(0.0, y + 0.18, 0.3), Vector3(0.74, 0.04, 1.0), 0)
	for c in [Vector2(-0.37, -0.92), Vector2(0.37, -0.92), Vector2(-0.37, 0.92), Vector2(0.37, 0.92)]:
		kit.box("metal", at + Vector3(c.x, 0.85, c.y), Vector3(0.05, 1.7, 0.05), 0)
	for y in [0.55, 0.85, 1.15]:
		kit.box("metal", at + Vector3(0.2, y, 0.95), Vector3(0.32, 0.03, 0.04), 0)
	_commit(kit, root, "Bunks")

static func _rug(root: Node3D, at: Vector3, sz: Vector2, a: Color, b: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(sz.x, 0.012, sz.y)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_texture = _rug_tex(a, b)
	m.roughness = 1.0
	mi.material_override = m
	mi.position = at + Vector3(0, 0.007, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)

static var _rugs := {}
static func _rug_tex(a: Color, b: Color) -> Texture2D:
	var key := a.to_html() + b.to_html()
	if _rugs.has(key):
		return _rugs[key]
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var bx := mini(mini(x, 63 - x), mini(y, 63 - y))
			var c := a
			if bx < 4 or (bx > 8 and bx < 11):
				c = b
			elif (x / 8 + y / 8) % 2 == 0 and bx > 14:
				c = a.lerp(b, 0.35)
			var n := (hash(x * 131 + y * 71) % 100) / 100.0
			c = c * (0.86 + n * 0.18)
			img.set_pixel(x, y, Color(c.r, c.g, c.b))
	var t := ImageTexture.create_from_image(img)
	_rugs[key] = t
	return t

static func _commit(kit: Frontier.Kit, root: Node3D, nm: String) -> void:
	var n := Node3D.new()
	n.name = nm
	root.add_child(n)
	kit.commit(n)
