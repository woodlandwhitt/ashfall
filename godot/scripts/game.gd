# Global game state: the world data exported from the three.js build, the player's stats and inventory, flags, and
# the quest system. Quests, dialogue, vendors, recipes and the world's quest objects are data (data/logic.json, made
# by tools/logic.mjs from the original game) run by JsVM through the GApi game interface; data/world.json holds the
# world's containers, terminals, benches, spawns and pickups.
extends Node

signal message(text: String)
signal quest_changed
signal stats_changed

var region: Dictionary = {}
var hm := PackedFloat32Array()
var hw := 0
var hd := 0
var x0 := 0.0
var z0 := 0.0

var inv: Dictionary = {"vault_suit": 1, "pipe_pistol": 1, "ammo_9": 36, "stimpak": 2}
var flags: Dictionary = {}
var quests: Dictionary = {}   # id -> {"stage": int, "done": bool}
var kills: Dictionary = {}    # enemy type -> count
var killed: Dictionary = {}   # enemy id -> true (quests ask for named enemies: the Glow Brute, a camp's raiders)
var shops: Dictionary = {}    # vendor id -> {day, caps, stock, back, deal}
var upgrades: Dictionary = {} # weapon or armor id -> workbench upgrade level (0..3)
var opened: Dictionary = {}   # container id -> remaining items ([] when emptied); unlocked locks
var day := 1
var player_name := "Wanderer"
var rad := 0.0               # radiation 0..100: eats into max health; at 100 it eats health
var time := 0.32              # time of day, 0 = midnight, 0.5 = noon (a day is 1000 s)
var buffs: Dictionary = {}    # id -> {amt, t}: Lead Tabs, Numb, Rotgut, Lucky Sour, Prickly Pop
var drugs: Dictionary = {}    # chem -> {age, crash, applied}
var addict: Dictionary = {}   # chems you're hooked on
var area := "world"           # "world" = the valley, "vault" = Haven 12 (an interior with its own data folder)
var pending_new := false      # a new game: main plays the opening in Haven 12
var booted := false           # the title screen has been seen this session
var test_log: Array = []      # --newgame test: results carried across scene reloads
var hp := 100.0
var caps := 25
var xp := 0
var level := 1
var points := 0               # unspent stat points
var perk_pts := 0             # unspent perks (one every second level)
var ap := 100.0               # action points for FOCUS targeting
# S.P.E.C.I.A.L.: Strength (might), Perception (aim), Endurance, Charisma (charm), Intelligence (intellect), Agility, Luck
const SPECIAL := ["might", "aim", "endurance", "charm", "intellect", "agility", "luck"]
var stats := {"might": 5, "aim": 5, "endurance": 5, "charm": 5, "intellect": 5, "agility": 5, "luck": 5}
var perks: Dictionary = {}
var karma := 0
var weapon := "pipe_pistol"
var nade := ""                 # the readied throwable (thrown first)
var armor := "vault_suit"
var magd := {"pipe_pistol": 8}  # rounds loaded, per weapon
var discovered: Dictionary = {}
var dead: Dictionary = {}     # enemy spawn index -> true (they stay dead)
var looted: Dictionary = {}
var player: Node3D
var main: Node3D
var nav_ready := false
var touch_move := Vector2.ZERO
var touch_fly := 0.0          # up (+1) or down (-1) while flying, from the touch buttons
var paused := false
var DB: Dictionary = {}       # items, enemies, loot, perks, stats, places, vendors, gun fits (data/game.json)
var L: Dictionary = {}        # quests, dialogue, quest objects, vendors, recipes, endings (data/logic.json)
var W: Dictionary = {}        # spawns, containers, pickups, terminals, benches, points (data/world.json)
var vm: JsVM
var G: GApi
var _checking := false

# the slice's own quest items, on top of the original game's 134
const EXTRA_ITEMS := {
	"sample_well": {"n": "Well Water Sample", "t": "quest", "w": 0.5, "v": 0, "desc": "A flask of Dustwell's well water. Faintly green."},
	"sample_glow": {"n": "Glowing Water Sample", "t": "quest", "w": 0.5, "v": 0, "desc": "A flask from an irradiated pool. It glows in the dark."},
}

var hp_max: float:
	get:
		return float(maxi(20, 60 + int(stats.endurance) * 8 + level * 6 - floori(rad * 0.4)))

var ap_max: float:
	get:
		return 60.0 + int(stats.agility) * 6.0 + (30.0 if perks.has("focus_training") else 0.0)

var mag: int:
	get:
		return int(magd.get(weapon, 0))
	set(v):
		magd[weapon] = v

var mag_size: int:
	get:
		return int(item(weapon).get("mag", 0))

var reserve: int:
	get:
		var a = item(weapon).get("ammo")
		return count(a) if a else 0
	set(v):
		var a = item(weapon).get("ammo")
		if a:
			if v <= 0:
				inv.erase(a)
			else:
				inv[a] = v

# bare hands when nothing is equipped (a new resident leaves their quarters unarmed)
const FISTS := {"n": "Fists", "t": "weapon", "kind": "melee", "dmg": 5, "range": 2.2, "rof": 0.5, "w": 0, "v": 0}

func item(id) -> Dictionary:
	if id == null or String(id) == "":
		return FISTS
	return DB.items.get(id, {})

func iname(id) -> String:
	var up := int(upgrades.get(id, 0)) if id != null else 0
	return String(item(id).get("n", str(id))) + (" +" + str(up) if up > 0 else "")

func count(id) -> int:
	return int(inv.get(id, 0))

func xp_need() -> int:
	return 60 + level * 70

func carry_max() -> float:
	return 90.0 + int(stats.might) * 12.0

func carry_now() -> float:
	var w := 0.0
	for k in inv:
		w += float(item(k).get("w", 0.0)) * int(inv[k])
	return w

func equip(id: String) -> void:
	var it := item(id)
	if it.is_empty() or not has(id):
		return
	if it.t == "weapon":
		weapon = id
		if it.has("mag") and not magd.has(id):
			magd[id] = 0
		if player:
			player.weapon_changed()
		msg("Equipped " + iname(id))
	elif it.t == "armor":
		_armor_bonus(armor, -1)
		armor = id
		_armor_bonus(id, 1)
		msg("Wearing " + iname(id))
	stats_changed.emit()

# take off what you're wearing, or put the gun away (bare hands)
func unequip(id: String) -> void:
	if id == weapon:
		weapon = ""
		if player:
			player.weapon_changed()
		msg("Bare hands")
	elif id == armor:
		_armor_bonus(armor, -1)
		armor = ""
		msg("Took off " + iname(id))
	stats_changed.emit()

func _armor_bonus(id, sgn: int) -> void:
	var b: Dictionary = item(id).get("bonus", {})
	for k in b:
		stats[k] = clampi(int(stats[k]) + int(b[k]) * sgn, 1, 12)

# eat, drink, inject: the aid items' effects from the original
func use_item(id: String) -> void:
	var it := item(id)
	if it.is_empty() or not has(id):
		return
	match String(it.t):
		"weapon", "armor":
			equip(id)
			return
		"aid":
			if it.get("throw"):
				nade = id
				msg(iname(id) + " readied. Tap NADE (or G) to throw.")
				Sfx.play("k_click", -6.0)
				return
			if id == "clean_slate":
				take(id)
				addict.clear()
				msg("Clean Slate. The cravings let go of you.")
				Sfx.play("o_coin", -12.0, 1.6)
				stats_changed.emit()
				return
			if it.get("drug"):
				take(id)
				take_drug(String(it.drug))
				stats_changed.emit()
				return
			take(id)
			var heal := float(it.get("heal", 0))
			if heal > 0:
				hp = minf(hp_max, hp + heal * (1.25 if perks.has("iron_gut") else 1.0) * (1.0 + (int(stats.get("intellect", 5)) - 5) * 0.04))
			if it.get("rad") and not perks.has("iron_gut"):
				add_rad(float(it.rad) * (1.0 - (int(stats.endurance) - 5) * 0.04), false)
			if it.get("radx"):
				rad = maxf(0.0, rad - float(it.radx))
				msg("Radiation flushed (" + str(int(rad)) + " left)")
			if it.get("buff"):
				buffs[String(it.buff.k)] = {"amt": float(it.buff.amt), "t": float(it.buff.t)}
			msg("Used " + iname(id) + (" (+" + str(int(heal)) + " HP)" if heal > 0 else ""))
			Sfx.play("o_coin", -12.0, 1.6)
	stats_changed.emit()

# ---------------------------------------------------------------- radiation, buffs, chems (drugs.js)
func rad_mul() -> float:
	var m := (1.0 - (int(stats.endurance) - 5) * 0.05) * (0.5 if perks.has("rad_shield") else 1.0)
	if buffs.has("rad"):
		m *= float(buffs.rad.amt)
	var a := item(armor) if armor != "" else {}
	if a.get("rr"):
		m *= 1.0 - float(a.rr)
	return maxf(0.05, m)

func add_rad(n: float, scaled := true) -> void:
	if dev.god and n > 0.0:
		return
	var before := int(rad / 25.0)
	rad = minf(100.0, rad + n * (rad_mul() if scaled else 1.0))
	if int(rad / 25.0) > before:
		msg(["", "Radiation sickness: mild. Max health reduced.", "Radiation sickness: severe. Find Rad Flush.", "Radiation sickness: critical!", "Lethal radiation!"][int(rad / 25.0)])
	if hp > hp_max:
		hp = hp_max

func buff(k: String, def := 1.0) -> float:
	return float(buffs[k].amt) if buffs.has(k) else def

func take_drug(k: String) -> void:
	var D: Dictionary = L.consts.DRUGS.get(k, {})
	if D.is_empty():
		return
	# a second dose of ketarad while the first still runs drops you through the floor of the world
	if k == "ketarad" and drugs.has("ketarad") and not drugs.ketarad.get("crash", false) and main and main.has_method("khole_start"):
		if main.khole_start():
			return
	if drugs.has(k):
		drugs[k].age = minf(float(drugs[k].age), float(D.onset))
	else:
		drugs[k] = {"age": 0.0, "crash": false, "applied": {}}
		for st in D.get("stats", {}):
			var b := int(stats.get(st, 5))
			stats[st] = clampi(b + int(D.stats[st]), 1, 14)
			drugs[k].applied[st] = int(stats[st]) - b
	msg("You take the " + String(D.n) + ". " + String(D.lines[randi() % D.lines.size()]))
	if randf() < float(D.get("addict", 0.0)) and not addict.has(k):
		addict[k] = 1
		msg("You're hooked on " + String(D.n) + ".")
	stats_changed.emit()

func _end_drug(k: String) -> void:
	var d: Dictionary = drugs[k]
	for st in d.get("applied", {}):
		stats[st] = int(stats[st]) - int(d.applied[st])
	drugs.erase(k)

# the combined effect of everything in the bloodstream: speed, ap, reload, dr, regen, rad, spread, melee, the look
func fx() -> Dictionary:
	var f := {"speed": 1.0, "ap": 1.0, "reload": 1.0, "dr": 0.0, "regen": 0.0, "rad": 0.0, "spread": 1.0, "melee": 1.0, "fov": 1.0,
		"sat": 1.0, "con": 1.0, "exposure": 0.0, "tr": 1.0, "tg": 1.0, "tb": 1.0, "warp": 0.0, "heart": 0.0, "night": 0.0}
	const MUL := ["speed", "ap", "reload", "spread", "melee", "fov", "sat", "con", "tr", "tg", "tb"]
	for k in drugs:
		var d: Dictionary = drugs[k]
		var D: Dictionary = L.consts.DRUGS.get(k, {})
		if D.is_empty():
			continue
		var src: Dictionary = D.crash.fx if d.crash else D.fx
		var a := 0.0
		var age := float(d.age)
		if d.crash:
			a = minf(1.0, minf(age / 4.0, (float(D.crash.dur) - age) / 6.0))
		elif age < float(D.onset):
			a = age / float(D.onset)
		elif age > float(D.dur) - float(D.fade):
			a = maxf(0.0, (float(D.dur) - age) / float(D.fade))
		else:
			a = 1.0
		if a <= 0.0:
			continue
		for p in src:
			if not f.has(p):
				continue
			var v := float(src[p])
			if p in MUL:
				f[p] *= 1.0 + (v - 1.0) * a
			else:
				f[p] += v * a
	for k in addict:
		if not drugs.has(k):
			f.speed *= 0.94
			f.spread *= 1.15
			f.sat *= 0.92
			f.ap *= 0.85
	if buffs.has("dr"):
		f.dr += float(buffs.dr.amt)
	if buffs.has("melee"):
		f.melee *= float(buffs.melee.amt)
	if buffs.has("ap"):
		f.ap *= 1.0 + float(buffs.ap.amt)
	return f

# time passing for the body: chems rise and fade, buffs run out, radiation bites, slow healing
func body_tick(dt: float) -> void:
	for k in buffs.keys():
		buffs[k].t = float(buffs[k].t) - dt
		if float(buffs[k].t) <= 0.0:
			buffs.erase(k)
			msg({"dr": "Numb", "rad": "Lead Tabs", "melee": "Rotgut", "luck": "Lucky Sour", "ap": "Prickly Pop"}.get(k, k) + " wore off.")
	for k in drugs.keys():
		var d: Dictionary = drugs[k]
		var D: Dictionary = L.consts.DRUGS.get(k, {})
		d.age = float(d.age) + dt
		if d.crash:
			if float(d.age) >= float(D.crash.dur):
				drugs.erase(k)
				msg("The " + String(D.n) + " crash passes.")
		elif float(d.age) >= float(D.dur):
			_end_drug(k)
			msg(String(D.n) + " wore off.")
			if D.has("crash"):
				drugs[k] = {"age": 0.0, "crash": true, "applied": {}}
				msg("You crash.")
	var f := fx()
	if f.regen > 0.0 and hp > 0.0:
		hp = minf(hp_max, hp + f.regen * dt)
	if f.rad > 0.0:
		add_rad(f.rad * dt)
	if rad >= 100.0:
		hurt(7.5 * dt)

func discover(k: String) -> void:
	if discovered.has(k):
		return
	discovered[k] = true
	var L: Dictionary = DB.locs[k]
	msg("Discovered: " + String(L.name) + "  (+20 XP)")
	add_xp(20)

# ---------------------------------------------------------------- save / load (three slots and an autosave)
func save_game(slot: String) -> bool:
	if player == null:
		return false
	var s := {"v": 1, "time": Time.get_datetime_string_from_system(), "pos": [player.global_position.x, player.global_position.y, player.global_position.z, player.yaw],
		"inv": inv, "flags": flags, "quests": quests, "kills": kills, "hp": hp, "caps": caps, "xp": xp, "level": level, "points": points, "perk_pts": perk_pts, "ap": ap, "name": player_name, "area": area, "rad": rad, "tod": time, "buffs": buffs, "drugs": drugs, "addict": addict,
		"stats": stats, "perks": perks, "karma": karma, "weapon": weapon, "nade": nade, "armor": armor, "magd": magd, "discovered": discovered,
		"dead": dead, "looted": looted, "killed": killed, "shops": shops, "upgrades": upgrades, "opened": opened, "day": day}
	var f := FileAccess.open("user://save_" + slot + ".json", FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(s))
	return true

func save_info(slot: String) -> String:
	var f := FileAccess.open("user://save_" + slot + ".json", FileAccess.READ)
	if f == null:
		return ""
	var s = JSON.parse_string(f.get_as_text())
	if s == null:
		return ""
	return "Level %d, %s" % [int(s.level), String(s.time).replace("T", " ")]

func load_game(slot: String) -> bool:
	var f := FileAccess.open("user://save_" + slot + ".json", FileAccess.READ)
	if f == null:
		return false
	var s = JSON.parse_string(f.get_as_text())
	if s == null:
		return false
	for k in ["inv", "flags", "quests", "kills", "stats", "perks", "magd", "discovered", "dead", "looted"]:
		set(k, s[k])
	for k in ["killed", "shops", "upgrades", "opened"]:
		set(k, s.get(k, {}))
	day = int(s.get("day", 1))
	for st in SPECIAL:
		if not stats.has(st):
			stats[st] = 5
	for q in quests:
		quests[q].stage = int(quests[q].stage)
	_vm_state()
	for k in ["hp", "caps", "xp", "level", "points", "karma", "weapon", "nade", "armor"]:
		set(k, s[k])
	for k in ["caps", "xp", "level", "points", "karma"]:
		set(k, int(get(k)))
	perk_pts = int(s.get("perk_pts", 0))
	rad = float(s.get("rad", 0.0))
	time = float(s.get("tod", 0.32))
	buffs = s.get("buffs", {})
	drugs = s.get("drugs", {})
	addict = s.get("addict", {})
	if String(s.get("area", "world")) != area:
		load_area(String(s.get("area", "world")))
	ap = float(s.get("ap", ap_max))
	player_name = String(s.get("name", "Wanderer"))
	pending_pos = s.pos
	main.restart_keep()
	return true

var pending_pos = null
var CELLS: Array = []
# developer switches (the DEV menu and console)
var dev := {"god": false, "noclip": false, "ammo": false, "ap": false, "onehit": false, "invis": false, "noai": false, "speed": 1.0,
	"dayrate": 1.0, "perf": false, "timescale": 1.0}        # building interiors: room origin and size, sign, street door

# a new resident of Haven 12: the name and aptitudes from the registration screen, waking in their quarters
func new_game(nm: String, st: Dictionary, pts: int) -> void:
	reset()
	player_name = nm if nm != "" else "Wanderer"
	stats = st.duplicate()
	points = pts
	inv = {"vault_suit": 1}
	weapon = ""
	magd = {"pipe_pistol": 8}
	hp = hp_max
	ap = ap_max
	load_area("vault")
	var sp: Array = L.consts.VSPOT.start
	var x := float(L.consts.VAULT_O.x) + float(sp[0])
	var z := float(L.consts.VAULT_O.z) + float(sp[1])
	pending_pos = [x, height(x, z), z, -PI / 2]
	pending_new = true
	main.restart_keep()

# through Haven 12's great door, in either direction
func travel_area(a: String, x: float, z: float, yaw: float) -> void:
	save_game("auto")
	load_area(a)
	pending_pos = [x, height(x, z), z, yaw]
	main.restart_keep()

func reset() -> void:
	if area != "world":
		load_area("world")
	player_name = "Wanderer"
	inv = {"vault_suit": 1, "pipe_pistol": 1, "ammo_9": 36, "stimpak": 2}
	for k in ["flags", "quests", "kills", "perks", "discovered", "dead", "looted", "killed", "shops", "upgrades", "opened"]:
		set(k, {})
	day = 1
	_vm_state()
	stats = {"might": 5, "aim": 5, "endurance": 5, "charm": 5, "intellect": 5, "agility": 5, "luck": 5}
	caps = 25
	xp = 0
	level = 1
	points = 0
	perk_pts = 0
	rad = 0.0
	time = 0.32
	buffs = {}
	drugs = {}
	addict = {}
	karma = 0
	weapon = "pipe_pistol"
	nade = ""
	armor = "vault_suit"
	magd = {"pipe_pistol": 8}
	hp = hp_max
	ap = ap_max
	nav_ready = false
	paused = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var gf := FileAccess.open("res://data/game.json", FileAccess.READ)
	DB = JSON.parse_string(gf.get_as_text())
	for k in EXTRA_ITEMS:
		if not DB.items.has(k):
			DB.items[k] = EXTRA_ITEMS[k]
	# the seventh letter, and every stat named for its letter
	DB.statinfo = {"might": ["STRENGTH", "Melee damage, carry weight, intimidation"], "aim": ["PERCEPTION", "Firearm damage, FOCUS accuracy, spotting trouble"],
		"endurance": ["ENDURANCE", "Health and radiation resistance"], "charm": ["CHARISMA", "Better prices and new things to say"],
		"intellect": ["INTELLIGENCE", "Experience gained, healing from medicine, and clever things to say"],
		"agility": ["AGILITY", "Move speed, reload speed, Action Points"], "luck": ["LUCK", "Critical hit chance, the tables at the Spur"]}
	L = _json("res://data/logic.json")
	_merge_story()
	CELLS = _json("res://data/cells.json")
	vm = JsVM.new()
	G = GApi.install(vm, L)
	DIALOGUE = L.get("dialogue", {})
	load_area("world")

func height(x: float, z: float) -> float:
	var fx := clampf(x - x0, 0.0, hw - 1.001)
	var fz := clampf(z - z0, 0.0, hd - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var a := iz * hw + ix
	return lerpf(lerpf(hm[a], hm[a + 1], tx), lerpf(hm[a + hw], hm[a + hw + 1], tx), tz)

# ---------------------------------------------------------------- inventory, quests
func msg(t: String) -> void:
	message.emit(t)

func give(item: String, n: int = 1) -> void:
	inv[item] = int(inv.get(item, 0)) + n
	stats_changed.emit()

func has(item: String, n: int = 1) -> bool:
	return int(inv.get(item, 0)) >= n

func take(item: String, n: int = 1) -> void:
	inv[item] = maxi(0, int(inv.get(item, 0)) - n)
	if inv[item] == 0:
		inv.erase(item)
	stats_changed.emit()

func dir() -> String:
	return "res://data/" if area == "world" else "res://data/" + area + "/"

func interior() -> bool:
	return area != "world"

func cell_name(i: int) -> String:
	if i < 0 or i >= CELLS.size():
		return "the building"
	var sg := String(CELLS[i].get("sign", ""))
	if sg == "":
		return "the building"
	var w := []
	for part in sg.to_lower().split(" "):
		w.append(part.substr(0, 1).to_upper() + part.substr(1))
	return " ".join(w)

# the region, heightmap and world objects of an area (the valley or an interior); main rebuilds the scene after
func load_area(a: String) -> void:
	area = a
	region = _json(dir() + "region.json")
	var hf := FileAccess.open(dir() + "height.f32", FileAccess.READ)
	hm = hf.get_buffer(hf.get_length()).to_float32_array()
	hw = int(region.heightSize[0])
	hd = int(region.heightSize[1])
	x0 = float(region.region.x0)
	z0 = float(region.region.z0)
	W = _json(dir() + "world.json") if FileAccess.file_exists(dir() + "world.json") else {}
	if area == "world" and not STORY.is_empty():
		if not W.has("points"):
			W["points"] = []
		for p in STORY.get("world_points", []):
			W.points.append(p.duplicate())
		if not W.has("spawns"):
			W["spawns"] = []
		for sp in STORY.get("spawns", []):
			var d: Dictionary = sp.duplicate()
			d["y"] = height(float(d.x), float(d.z))
			W.spawns.append(d)
	if not interior():
		_merge_spawns()
	_extra_dialogue()

# a character model from this area's folder, or the valley's
func char_path(file: String) -> String:
	var p := dir() + "chars/" + file
	return p if ResourceLoader.exists(p) else "res://data/chars/" + file

func _json(path: String):
	var f := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(f.get_as_text()) if f else {}

# the interpreter holds references to the state dictionaries; point it at the current ones after a reset or a load
func _vm_state() -> void:
	if vm:
		vm.define("flags", flags)
		vm.define("killed", killed)

func qdef(q) -> Dictionary:
	return L.get("quests", {}).get(String(q), {})

func known(q: String) -> bool:
	return quests.has(q)

func stage(q: String) -> int:
	return int(quests[q].stage) if quests.has(q) and not quests[q].done else -1

func is_done(q: String) -> bool:
	return quests.has(q) and quests[q].done

func start(q: String) -> void:
	var d := qdef(q)
	if d.is_empty():
		push_warning("no quest " + q)
		return
	if quests.has(q):
		if not (quests[q].done and d.get("repeat", false)):
			return
		quests.erase(q)
	quests[q] = {"stage": 0, "done": false}
	msg("New quest: " + String(d.t))
	Sfx.play("o_quest")
	var tr = flags.get("track")
	if tr == null or stage(String(tr)) < 0 or (d.get("main", false) and not qdef(tr).get("main", false)):
		flags["track"] = q
	if main:
		main.refresh_spawns()
	quest_changed.emit()
	check_quests()

func advance(q: String) -> void:
	if stage(q) < 0:
		return
	quests[q].stage = int(quests[q].stage) + 1
	msg("Quest updated: " + String(qdef(q).t))
	Sfx.play("o_quest")
	quest_changed.emit()
	check_quests()

func complete(q: String) -> void:
	if not quests.has(q):
		quests[q] = {"stage": 0, "done": false}
	if quests[q].done:
		return
	quests[q].done = true
	var d := qdef(q)
	var r = vm.val(d.get("reward"), [G])
	if not (r is Dictionary):
		r = {}
	banner("QUEST COMPLETE", String(d.get("t", q)))
	Sfx.play("o_quest")
	if r.get("caps"):
		caps += int(r.caps)
		msg("+" + str(int(r.caps)) + " chits")
	for it in r.get("items", []):
		give(String(it[0]), int(it[1]))
		msg("Received " + iname(it[0]) + (" x" + str(int(it[1])) if int(it[1]) > 1 else ""))
	if r.get("xp"):
		add_xp(int(r.xp))
	if d.get("rep"):
		flags["rep"] = int(flags.get("rep", 0)) + int(d.rep)
	for f in STORY.get("quest_rep", {}).get(q, {}):
		rep(f, int(STORY.quest_rep[q][f]))
	if not d.get("main", false):
		party_react("quest")
	if d.get("karma"):
		add_karma(int(d.karma), "")
	if d.get("radio"):
		flags["radio"] = d.radio
	if flags.get("track") == q:
		flags["track"] = null
		for k in quests:
			if not quests[k].done:
				flags["track"] = k
				if qdef(k).get("main", false):
					break
	if d.get("then"):
		start(String(d.then))
	if main:
		main.refresh_spawns()
	quest_changed.emit()
	stats_changed.emit()

# stages that finish themselves when their condition becomes true (the original's checkQuests)
func check_quests() -> void:
	if vm == null or _checking:
		return
	_checking = true
	var changed := false
	for q in quests.keys():
		var s: Dictionary = quests[q]
		var d := qdef(q)
		var stages: Array = d.get("stages", [])
		var guard := 0
		while not s.done and guard < 8:
			guard += 1
			var i := int(s.stage)
			if i >= stages.size():
				break
			var st: Dictionary = stages[i]
			if not st.has("done") or not vm.truthy(vm.call_value(st.done, [G])):
				break
			if st.get("auto", false):
				_checking = false
				complete(q)
				_checking = true
				changed = true
				break
			if i >= stages.size() - 1:
				break
			s.stage = i + 1
			msg("Quest updated: " + String(d.t))
			Sfx.play("o_quest")
			changed = true
	_checking = false
	_story_triggers()
	if changed:
		quest_changed.emit()

func stage_text(q: String) -> String:
	var i := stage(q)
	var stages: Array = qdef(q).get("stages", [])
	if i < 0 or i >= stages.size():
		return ""
	return subst(vm.to_str(vm.val(stages[i].get("txt", ""), [G])))

func current_objective() -> Dictionary:
	var q = flags.get("track")
	if q == null or stage(String(q)) < 0:
		for k in quests:
			if not quests[k].done:
				q = k
				break
	if q == null or stage(String(q)) < 0:
		return {}
	return {"q": q, "title": String(qdef(q).t), "text": stage_text(String(q))}

# where the tracked quest points: a stage's own spot (a function of the game) or the place it names
func quest_target() -> Variant:
	var o := current_objective()
	if o.is_empty():
		return null
	var st: Dictionary = qdef(o.q).stages[stage(o.q)]
	var p = null
	if st.has("pos"):
		p = vm.val(st.pos, [G])
	elif st.has("at"):
		p = DB.locs.get(String(st.at))
	if p is Dictionary and p.has("x") and p.has("z"):
		var x := float(p.x)
		var z := float(p.z)
		# a target inside a building: on the street, point at its front door; inside, at the way out
		var ci := cell_at(x, z)
		if area == "world" and ci >= 0 and CELLS[ci].get("out"):
			x = float(CELLS[ci].out.x)
			z = float(CELLS[ci].out.z)
		elif area == "cells" and player:
			var mine := cell_at(player.global_position.x, player.global_position.z)
			if mine >= 0 and ci != mine:
				x = float(CELLS[mine].ox)
				z = float(CELLS[mine].oz) + float(CELLS[mine].D2) / 2.0 - 1.3
		return Vector3(x, height(x, z), z)
	return null

func cell_at(x: float, z: float) -> int:
	if x < 1900.0:
		return -1
	for C in CELLS:
		if absf(x - float(C.ox)) < float(C.W2) / 2.0 + 1.0 and absf(z - float(C.oz)) < float(C.D2) / 2.0 + 1.0:
			return int(C.i)
	return -1

func add_xp(n: int) -> void:
	n = maxi(1, int(round(n * (1.0 + (int(stats.get("intellect", 5)) - 5) * 0.05)))) if n > 0 else n
	xp += n
	while xp >= xp_need():
		xp -= xp_need()
		level += 1
		points += 1
		if level % 2 == 0:
			perk_pts += 1
		hp = hp_max
		var what := "A new perk and a stat point are" if level % 2 == 0 else "A stat point is"
		msg("Level up! You are now level " + str(level) + ". " + what + " waiting in the Pip menu.")
		banner("LEVEL " + str(level), what + " waiting in the Pip menu")
		Sfx.play("o_levelup")
	stats_changed.emit()

func on_kill(type: String, id = null) -> void:
	kills[type] = int(kills.get(type, 0)) + 1
	flags["k_" + type] = kills[type]
	if id != null and String(id) != "":
		killed[String(id)] = true
	check_quests()

func karma_title(k: int) -> String:
	for t in DB.get("karma_titles", []):
		if k < int(t[0]):
			return String(t[1])
	return "Lamplight Saint"

func add_karma(n: int, why: String) -> void:
	if n == 0:
		return
	var before := karma_title(karma)
	karma = clampi(karma + n, -100, 100)
	msg(("Karma +" if n > 0 else "Karma ") + str(n) + (" — " + why if why != "" else ""))
	Sfx.play("o_karmaup" if n > 0 else "o_karmadown", -4.0)
	_karma_react(n)
	var after := karma_title(karma)
	if after != before:
		banner("KARMA", "You are now known as " + after)
	stats_changed.emit()

func banner(title: String, sub: String) -> void:
	if main and main.hud and main.hud.screens:
		main.hud.screens.banner(title, sub)

func subst(t: String) -> String:
	return t.replace("{name}", player_name)

# the story's end: the ending's heading and paragraph, then every epilogue line whose condition holds
func finish(k: String) -> void:
	flags["ending"] = k
	complete("meridian")
	var e: Dictionary = L.get("endings", {}).get(k, {})
	var text := String(e.get("t", ""))
	for ep in L.get("epilogue", []):
		if not ep.has("if") or vm.truthy(vm.call_value(ep["if"], [G])):
			text += "\n\n" + vm.to_str(vm.val(ep.get("t", ""), [G]))
	if main and main.hud and main.hud.screens:
		main.hud.screens.open_term(String(e.get("h", "THE END")), text + "\n\n— Your story goes on. Keep exploring the valley. —")

# ---------------------------------------------------------------- dialogue
func dlg(id: String) -> Dictionary:
	return DIALOGUE.get(id, {})

func dlg_entry(id: String) -> String:
	var D := dlg(id)
	var nodes: Dictionary = D.get("nodes", {})
	var e = vm.val(D.get("entry", "hub"), [G]) if D.has("entry") else "hub"
	if e == null or not nodes.has(String(e)):
		e = "hub" if nodes.has("hub") else (nodes.keys()[0] if nodes.size() else "")
	return String(e)

# the visible options at a node: [{t, o, off}] (off = a stat check you don't meet)
func dlg_options(id: String, node: String) -> Array:
	var out := []
	var n: Dictionary = dlg(id).nodes.get(node, {})
	for o in n.get("opts", []):
		if o.has("if") and not vm.truthy(vm.call_value(o["if"], [G])):
			continue
		var t := subst(vm.to_str(vm.val(o.get("t", ""), [G])))
		var off := false
		if o.has("check"):
			var st := String(o.check[0])
			var need := int(o.check[1])
			var have := int(stats.get(st, 5))
			var nm := String(DB.statinfo.get(st, [st.to_upper()])[0])
			t = "[" + nm + " " + str(need) + ("" if have >= need else " — you have " + str(have)) + "] " + t
			off = have < need
		out.append({"t": t, "o": o, "off": off})
	return out

func dlg_say(id: String, node: String) -> String:
	return subst(vm.to_str(vm.val(dlg(id).nodes.get(node, {}).get("say", ""), [G])))

# ---------------------------------------------------------------- vendors
func vendor(id: String) -> Dictionary:
	return L.get("vendors", {}).get(id, {})

# stock and purse reset at sunrise; one item a day is 30% off
func shop_state(id: String) -> Dictionary:
	var v := vendor(id)
	var st = shops.get(id)
	if st == null or int(st.day) != day:
		st = {"day": day, "caps": int(v.get("caps", 200)), "stock": {}, "back": []}
		for s in v.get("stock", []):
			st.stock[s[0]] = int(st.stock.get(s[0], 0)) + int(s[1])
		for ex in v.get("extra", []):
			if not ex.has("if") or vm.truthy(vm.call_value(ex["if"], [G])):
				for s in ex.get("items", []):
					st.stock[s[0]] = int(st.stock.get(s[0], 0)) + int(s[1])
		var ks: Array = st.stock.keys().filter(func(k): return float(item(k).get("v", 0)) >= 10.0 and DB.items.has(k))
		st["deal"] = ks[(day * 7 + id.length() * 3) % ks.size()] if ks.size() else null
		for k in st.stock.keys():
			if not DB.items.has(k):
				st.stock.erase(k)
		shops[id] = st
	return st

# ---------------------------------------------------------------- the world's spawns
# enemies the export didn't place (a quest summons them, or they appear once a quest is done) join the region list;
# main only spawns them when their quest allows it
func _merge_spawns() -> void:
	var have := {}
	for e in region.enemies:
		if e.get("id") != null:
			have[String(e.id)] = true
	for sp in W.get("spawns", []):
		var id := String(sp.get("id", ""))
		if id == "" or have.has(id):
			if have.has(id):
				for e in region.enemies:
					if String(e.get("id", "")) == id:
						for k in ["req", "onStart", "neutral", "group"]:
							if sp.has(k):
								e[k] = sp[k]
						if sp.get("neutral", false):
							e["hostile"] = false
			continue
		if not (sp.has("req") or sp.has("onStart")):
			continue
		var t := String(sp.type)
		if not region.etypes.has(t):
			t = "raider"
			if not region.etypes.has(t):
				continue
		region.enemies.append({"type": t, "x": sp.x, "z": sp.z, "y": sp.y, "hostile": not sp.get("neutral", false), "id": id,
			"req": sp.get("req"), "onStart": sp.get("onStart"), "name": sp.get("name")})

func spawn_allowed(e: Dictionary) -> bool:
	if e.get("req") != null and not is_done(String(e.req)):
		return false
	if e.get("onStart") != null and not known(String(e.onStart)):
		return false
	return true

var DIALOGUE: Dictionary = {}

# ---------------------------------------------------------------- the build 10 story (data/story.json, from tools/story)
var STORY: Dictionary = {}
func _merge_story() -> void:
	STORY = _json("res://data/story.json")
	if STORY.is_empty():
		return
	for k in STORY.get("quests", {}):
		L.quests[k] = STORY.quests[k]
	for npc in STORY.get("dialogue", {}):
		if L.dialogue.has(npc):
			for nk in STORY.dialogue[npc].nodes:
				L.dialogue[npc].nodes[nk] = STORY.dialogue[npc].nodes[nk]
		else:
			L.dialogue[npc] = STORY.dialogue[npc]
	for inj in STORY.get("inject", []):
		var node: Dictionary = L.dialogue.get(inj.npc, {}).get("nodes", {}).get(inj.node, {})
		if node.is_empty():
			continue
		if not node.has("opts"):
			node["opts"] = []
		var at: int = maxi(0, node.opts.size() - 1)
		for o in inj.opts:
			node.opts.insert(at, o)
			at += 1
	var ep: Array = L.get("epilogue", [])
	var last = ep.pop_back() if not ep.is_empty() else null
	ep.append_array(STORY.get("epilogue", []))
	if last != null:
		ep.append(last)
	for k in STORY.get("radio", {}):
		L.radio[k] = STORY.radio[k]
	for k in STORY.get("points", {}):
		L.points[k] = STORY.points[k]
	for k in STORY.get("items", {}):
		DB.items[k] = STORY.items[k]
	if not L.has("companions"):
		L["companions"] = {}
	for k in STORY.get("companions", {}):
		L.companions[k] = STORY.companions[k]
	for npc in STORY.get("entry", {}):
		if L.dialogue.has(npc):
			L.dialogue[npc]["entry"] = STORY.entry[npc]

var _trig := false
func _story_triggers() -> void:
	if _trig or STORY.is_empty() or vm == null:
		return
	_trig = true
	for t in STORY.get("triggers", []):
		if vm.truthy(vm.call_value(t["if"], [G])):
			vm.call_value(t["do"], [G])
	_trig = false

# standing with the valley's powers, -10 (hated) to +10 (idolised)
func rep_of(f: String) -> int:
	var r := int(flags.get("rep_" + f, 0))
	if f == "dustwell":
		r += int(flags.get("rep", 0))
	return clampi(r, -10, 10)

func rep(f: String, n: int) -> void:
	if n == 0 or not STORY.get("factions", {}).has(f):
		return
	var before := rep_title(rep_of(f))
	flags["rep_" + f] = int(flags.get("rep_" + f, 0)) + n
	var nm := String(STORY.factions[f].n)
	msg("%s: %s" % [nm, ("standing rises" if n > 0 else "standing falls")])
	var after := rep_title(rep_of(f))
	if after != before:
		msg("%s now see you as %s." % [nm, after.to_lower()])

static func rep_title(r: int) -> String:
	if r <= -6: return "Hated"
	if r <= -2: return "Disliked"
	if r <= 1: return "Neutral"
	if r <= 5: return "Liked"
	if r <= 9: return "Respected"
	return "Idolised"

# ---------------------------------------------------------------- what your companions think of you (build 11)
# -100..100 per companion. Karma moves it by each one's taste (Jory and Renn like decency, Sable likes a bit of
# larceny), so do stealing, the Spur's tables and their own quests. Talk to them past 30 for their personal
# conversation and loyalty (tougher, deadlier, and they won't walk over karma); at -40 they leave and won't come back.
const APPROVAL_TASTE := {"jory": 1.5, "sable": -1.2, "renn2": 1.0}
const REACT := {"steal": {"jory": -3, "renn2": -2, "sable": 3}, "caught": {"jory": -5, "renn2": -4, "sable": -2},
	"casino": {"sable": 2, "jory": -1}, "quest": {"jory": 3, "renn2": 3, "sable": 2}, "sneak_kill": {"sable": 1}, "murder": {"jory": -15, "renn2": -15, "sable": -4}}
func approval(id: String) -> int:
	return int(flags.get("appr_" + id, 0))

func approval_title(a: int) -> String:
	if a <= -40: return "Done with you"
	if a <= -15: return "Wary"
	if a < 15: return "Neutral"
	if a < 40: return "Friendly"
	return "Loyal"

func approve(id: String, n: int, why := "") -> void:
	if n == 0 or not L.get("companions", {}).has(id) or L.companions[id].get("dog", false):
		return
	var before := approval(id)
	var v := clampi(before + n, -100, 100)
	flags["appr_" + id] = v
	var nm := String(L.companions[id].n).split(" ")[0]
	msg("%s %s%s" % [nm, ("approves" if n > 0 else "disapproves") if absi(n) < 8 else ("really likes that" if n > 0 else "hated that"), (". " + why) if why != "" else "."])
	if v <= -40 and before > -40 and main and main.party.any(func(p): return p.id == id):
		flags["left_" + id] = 1
		for p in main.party:
			if p.id == id:
				p.say("leave")
		main.dismiss(id, true)
		msg(nm + " has had enough of you, and leaves.")

func is_loyal(id: String) -> bool:
	return bool(flags.get("loyal_" + id, false))

func make_loyal(id: String) -> void:
	if is_loyal(id):
		return
	flags["loyal_" + id] = 1
	flags["appr_" + id] = maxi(approval(id), 40)
	banner("LOYALTY", String(L.companions.get(id, {}).get("n", id)) + " is loyal to you")
	Sfx.play("o_levelup", -6.0, 1.2)
	if main:
		main.refresh_party()

# everyone in the party with an opinion reacts (REACT kinds, or karma by taste)
func party_react(kind: String, why := "") -> void:
	if main == null:
		return
	for p in main.party.duplicate():
		var id := String(p.id)
		var n := int(REACT.get(kind, {}).get(id, 0))
		if n != 0:
			approve(id, n, why)

func _karma_react(n: int) -> void:
	if main == null:
		return
	for p in main.party.duplicate():
		var t := float(APPROVAL_TASTE.get(String(p.id), 0.0))
		var a := int(round(n * t))
		if a != 0:
			approve(String(p.id), a)

# everyone with a conversation in the original speaks it (data/logic.json)
func _extra_dialogue() -> void:
	# everyone else (saloon patrons, card players, the lamplighter) gets a line of their own
	var barks := ["Nine days of water. Nine. I counted the tanks myself.", "The Overseer hasn't slept. You can tell by the coffee.",
		"Pell says the regulator's done for. Pell says that about everything.", "They say the surface is just ash. I'd still like to see it."] if interior() else ["Water's gone green again. Don't drink from the trough.", "You're from the Shelter? Huh. Thought you'd be taller.",
		"If you're going north, go armed. The hounds have got bold.", "Cass waters the whiskey. Everybody knows. Nobody says.",
		"Two winters since the reactor woke up. Feels like twenty.", "Got nothing to sell you, friend. Got nothing at all.",
		"Sheriff's fair. Hard, but fair. That's rare out here.", "Heard a caravan got hit on the spur road. Raiders again."]
	for n in region.npcs:
		if not DIALOGUE.has(n.id):
			var nm := String(n.name).capitalize()
			if nm.begins_with("Patron") or nm.begins_with("Gambler") or nm.begins_with("Lamp"):
				nm = {"P": "Saloon Regular", "G": "Card Player", "L": "Lamplighter"}[nm[0]]
			DIALOGUE[n.id] = {"name": nm, "entry": "b", "nodes": {"b": {"say": barks[hash(n.id) % barks.size()], "opts": [{"t": "Take care."}]}}}

# armour soaks a share of every hit: DR / (DR + 40), as in the original
func armor_dr() -> float:
	var dr := 0.0
	if armor != "":
		dr = float(item(armor).get("dr", 0)) + 3.0 * int(upgrades.get(armor, 0))
	return dr + (8.0 if perks.has("toughness") else 0.0)

func hurt(d: float) -> void:
	if hp <= 0 or dev.god:
		return
	var dr := armor_dr() + float(fx().dr)
	d *= 1.0 - dr / (dr + 40.0)
	hp = maxf(0.0, hp - d)
	stats_changed.emit()
	if main:
		main.on_player_hurt(d)

# the throwable that goes first: the readied one, else whatever is carried
func nade_kind() -> String:
	if nade != "" and has(nade):
		return nade
	for k in Nade.THROWN:
		if has(k):
			return k
	return ""
