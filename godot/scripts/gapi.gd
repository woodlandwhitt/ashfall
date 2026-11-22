# The game API the converted quest and dialogue logic calls: the same names and meanings as the WebView build's G
# object (main.js), backed by the Godot Game autoload and the main scene. install() puts it and the other globals the
# logic refers to (flags, P, msg, sfx, Math, the data tables...) into a JsVM.
class_name GApi
extends RefCounted

var vm: JsVM

static func install(v: JsVM, logic: Dictionary) -> GApi:
	var g := GApi.new()
	g.vm = v
	v.define("G", g)
	v.define("P", PProxy.new())
	v.define("flags", Game.flags)
	v.define("sfx", SfxProxy.new())
	v.define("Math", MathObj.new())
	v.define("Object", ObjectObj.new())
	v.define("KHM", KhmProxy.new())
	v.define("dev", {"god": false, "fastText": false})
	v.define("msg", func(a = "", b = "", c = ""): Game.msg(v.to_str(a) + ("" if b == null or str(b) == "" else " " + v.to_str(b))))
	v.define("checkQuests", func(): Game.check_quests())
	v.define("banner", func(a = "", b = ""): Game.banner(v.to_str(a), v.to_str(b)))
	v.define("speak", func(t = "", voice = null): if Game.main: Game.main.speak(v.to_str(t), "narrator"))
	v.define("syncLostThings", func(): pass)
	v.define("cellTravel", func(i = 0, inward = true): if Game.main: Game.main.cell_travel(int(v.num(i)), bool(inward)))
	v.define("cellName", func(i = 0): return Game.cell_name(int(v.num(i))))
	v.define("spat", func(x = 0, z = 0): return null)
	v.define("pick", func(a = []): return a[randi() % a.size()] if a is Array and a.size() else null)
	v.define("addXp", func(n = 0): Game.add_xp(int(v.num(n))))
	v.define("maxHp", func(): return Game.hp_max)
	v.define("radMul", func(): return 1.0)
	v.define("setTimeout", func(f = null, ms = 0): (func(): v.call_value(f)).call_deferred())
	v.define("karmaTitle", func(k = 0): return Game.karma_title(int(v.num(k))))
	v.define("stageText", func(id = ""): return Game.stage_text(_s(id)))
	v.define("killed", Game.killed)
	for k in logic.get("helpers", {}):
		v.define(k, v.fn_of(logic.helpers[k]))
	for k in logic.get("consts", {}):
		v.define(k, logic.consts[k])
	v.define("QUESTS", logic.quests)
	v.define("DIALOGUE", logic.dialogue)
	v.define("COMPANIONS", logic.get("companions", {}))
	v.define("ITEMS", Game.DB.items)
	v.define("ENEMIES", Game.DB.enemies)
	v.define("LORE", Game.DB.lore)
	v.define("VENDORS", Game.DB.vendors)
	v.define("LOCS", Game.DB.locs)
	return g

static func _s(v) -> String:
	return "" if v == null else str(v)

func js_get(k: String):
	match k:
		"flags": return Game.flags
		"caps": return Game.caps
		"P": return vm.globals.vars.P
		"day": return Game.day
	return null

# ---------------------------------------------------------------- inventory
func count(id = "") -> int: return Game.count(_s(id))
func has(id = "") -> bool: return Game.count(_s(id)) > 0
func stat(s = "") -> int: return int(Game.stats.get(_s(s), 5))
func give(id = "", n = 1) -> void:
	if _s(id) == "caps":
		Game.caps += int(vm.num(n))
		Game.stats_changed.emit()
		return
	Game.give(_s(id), int(vm.num(n)))
	Game.check_quests()
func take(id = "", n = 1) -> void:
	if Game.count(_s(id)) > 0:
		Game.take(_s(id), int(vm.num(n)))
func rep(f = "", n = 0) -> void: Game.rep(_s(f), int(vm.num(n)))
func repOf(f = "") -> int: return Game.rep_of(_s(f))
# the council: name a side
func pledge(f = "") -> void:
	var k := _s(f)
	Game.flags["pledge"] = k
	for x in ["dustwell", "saltreach", "lamplight", "gantry", "haven"]:
		Game.rep(x, 4 if x == k else -1)
	Game.give("council_token", 1)
	Game.complete("council")
func addCaps(n = 0) -> void:
	Game.caps = maxi(0, Game.caps + int(vm.num(n)))
	Game.stats_changed.emit()
func msg(t = "", b = null) -> void: Game.msg(vm.to_str(t))

# ---------------------------------------------------------------- quests and flags
func setFlag(f = "", v = true) -> void:
	Game.flags[_s(f)] = v
	Game.check_quests()
func questKnown(id = "") -> bool: return Game.quests.has(_s(id))
func questActive(id = "") -> bool: return Game.quests.has(_s(id)) and not Game.quests[_s(id)].done
func questDone(id = "") -> bool: return Game.quests.has(_s(id)) and Game.quests[_s(id)].done
func qStage(id = "") -> int: return Game.stage(_s(id))
func start(id = "") -> void: Game.start(_s(id))
func advance(id = "") -> void: Game.advance(_s(id))
func complete(id = "") -> void: Game.complete(_s(id))
func karma(n = 0, why = "") -> void: Game.add_karma(int(vm.num(n)), "" if why == null else _s(why))
func finish(k = "") -> void: Game.finish(_s(k))
func coreChoice(k = "") -> void:
	Game.flags["coreChoice"] = _s(k)
	if Game.main and Game.main.has_method("core_set"):
		Game.main.core_set(_s(k))
	Game.banner("COOLANT RESTORED" if k == "repair" else "CORE SHUT DOWN", "The core settles to a steady blue" if k == "repair" else "The green light dies")
	Sfx.play("o_hatch_open")
	Game.check_quests()

# ---------------------------------------------------------------- the world
func kills(t = "") -> int: return int(Game.flags.get("k_" + _s(t), 0))
func killed(id = "") -> bool: return Game.killed.has(_s(id))
func enemyName(t = "") -> String: return str(Game.DB.enemies.get(_s(t), {}).get("n", _s(t)))
func allDead(pre = "", n = 0) -> bool:
	for i in int(vm.num(n)):
		if not Game.killed.has(_s(pre) + str(i)):
			return false
	return true
func campCleared(ci = 0, n = 0) -> bool:
	for i in int(vm.num(n)):
		if not Game.killed.has("cp" + vm.to_str(ci) + "_" + str(i)):
			return false
	return true
func visited(k = "") -> bool: return Game.discovered.has(_s(k))
func makeHostile(id = "") -> void:
	if Game.main:
		Game.main.make_hostile(_s(id))
func nearestPool():
	return Game.main.nearest_pool() if Game.main else null
func nearestFungus():
	return Game.main.nearest_pickup("glow_fungus", "reactor") if Game.main else null
func nextCellSpot():
	return Game.main.nearest_pickup("fusion_cell", "tower") if Game.main else null

# ---------------------------------------------------------------- screens other systems own
func openTrade(id = "") -> void:
	if Game.main:
		Game.main.queue_trade(_s(id))
func casino(g = "", m = null) -> void:
	if Game.main:
		Game.main.queue_casino(_s(g), 0 if m == null else int(vm.num(m)))
func event(k = "") -> void:
	Game.flags["ev_" + _s(k)] = true
	if _s(k) == "helped":
		var r: Array = [["stimpak", 1], ["spur_chip", 2], ["ammo_44", 12], ["medal", 1], ["fuel_can", 1]][randi() % 5]
		if Game.DB.items.has(r[0]):
			Game.give(r[0], r[1])
			Game.msg("Received " + Game.iname(r[0]) + (" x" + str(r[1]) if r[1] > 1 else ""))
func sleep(cost = 0) -> void:
	Game.caps -= int(vm.num(cost))
	if Game.time > 0.25:
		Game.day += 1
	Game.time = 0.27
	Game.hp = Game.hp_max
	Game.msg("You slept until morning. Health restored.")
	Sfx.play("o_levelup", -10.0, 0.8)
	Game.stats_changed.emit()

# companions (main.gd keeps the party)
func recruit(id = "") -> void:
	if Game.main:
		Game.main.recruit(_s(id))
func dismiss(id = "") -> void:
	if Game.main:
		Game.main.dismiss(_s(id))
func inParty(id = "") -> bool:
	return Game.main != null and Game.main.party_state(_s(id)) != null
func partyState(id = ""):
	return Game.main.party_state(_s(id)) if Game.main else null
func partyCmd(id = "", st = "") -> void:
	if Game.main:
		Game.main.party_cmd(_s(id), _s(st))


class PProxy:
	func js_get(k: String):
		match k:
			"karma": return Game.karma
			"caps": return Game.caps
			"stats": return Game.stats
			"level": return Game.level
			"hp": return Game.hp
			"name": return Game.player_name
			"inv": return Game.inv
			"day": return Game.day
			"rad": return 0
			"perks": return Game.perks
			"x": return Game.player.global_position.x if Game.player else 0.0
			"z": return Game.player.global_position.z if Game.player else 0.0
		return null
	func js_set(k: String, v) -> void:
		match k:
			"karma": Game.karma = clampi(int(v), -100, 100)
			"caps": Game.caps = maxi(0, int(v))
			"hp": Game.hp = clampf(float(v), 0.0, Game.hp_max)
		Game.stats_changed.emit()

# the original's named sounds, mapped onto the recordings this build ships
class SfxProxy:
	const MAP := {"pick": ["k_cloth1", -4.0], "ui": ["k_click", -8.0], "empty": ["k_metal_click", -6.0], "craft": ["k_metal_latch", -2.0],
		"heal": ["o_coin", -10.0], "page": ["k_page", -4.0], "unlock": ["o_unlock", -2.0], "door": ["k_door_open", -2.0],
		"bark": ["o_bark1", -2.0], "drink": ["o_splash", -6.0], "lever": ["k_switch", -4.0], "quest": ["o_quest", 0.0],
		"karmaUp": ["o_karmaup", -4.0], "karmaDown": ["o_karmadown", -4.0], "type": ["x_computer0", -14.0], "termOpen": ["o_typing", -10.0]}
	func js_get(k: String):
		return func(a = null, b = null): js_call(k, [])
	func js_call(name: String, _args: Array):
		var m = MAP.get(name)
		if m:
			Sfx.play(m[0], m[1])
		return null

class MathObj:
	func js_get(k: String):
		match k:
			"PI": return PI
		return null
	func js_call(name: String, a: Array):
		var n := a.map(func(x): return float(x) if x is float or x is int else 0.0)
		match name:
			"min":
				var r := INF
				for x in n: r = minf(r, x)
				return r
			"max":
				var r := -INF
				for x in n: r = maxf(r, x)
				return r
			"floor": return floorf(n[0])
			"ceil": return ceilf(n[0])
			"round": return roundf(n[0])
			"abs": return absf(n[0])
			"random": return randf()
			"hypot": return sqrt(n[0] * n[0] + n[1] * n[1])
			"sqrt": return sqrt(n[0])
		return null

class ObjectObj:
	func js_call(name: String, a: Array):
		var o = a[0] if a.size() else {}
		if not (o is Dictionary):
			return []
		match name:
			"keys": return o.keys()
			"values": return o.values()
			"entries": return o.keys().map(func(k): return [k, o[k]])
			"assign":
				for i in range(1, a.size()):
					if a[i] is Dictionary: o.merge(a[i], true)
				return o
		return null

class KhmProxy:
	func js_get(_k: String):
		return null
	func js_call(name: String, _a: Array):
		if name == "pulse" and Game.main and Game.main.khole:
			Game.main.khole.pulse()
		return null

class Nop:
	func js_get(_k: String):
		return null
	func js_call(_name: String, _a: Array):
		return null
