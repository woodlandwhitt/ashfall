# Pickpocketing (build 17). Sneak up behind someone who isn't looking and you can go through their pockets. Every
# item is a separate try: Agility, sneaking well, the dark and a light touch help; heavy things and big rolls of
# chits are harder. Get caught and they turn round: karma, their people's opinion, and a third time, a fight.
# What people carry is decided once every few days, so a mark you've emptied has new pockets later.
class_name Pockets
extends RefCounted

var main
const TABLE := [["bobby_pin", 1, 2], ["jerky", 1, 2], ["purified_water", 1, 1], ["stimpak", 1, 1], ["ammo_9", 6, 14], ["duct_tape", 1, 1],
	["coffee_tin", 1, 1], ["shells", 3, 6], ["ammo_rifle", 4, 10], ["radaway", 1, 1], ["flatbread", 1, 1], ["scrap_metal", 1, 2], ["circuit", 1, 1]]

func _init(m) -> void:
	main = m

# from behind (their back to you, within a step or two), sneaking, and they aren't busy talking or fighting
func can_pick(n, pl) -> bool:
	if pl == null or not pl.crouch or n.follow or n.hostile or n.talking or String(n.id) in main.CHILDREN:
		return false
	var f := Vector3(sin(float(n.face_yaw)), 0, cos(float(n.face_yaw)))
	var to_me: Vector3 = pl.global_position - n.global_position
	to_me.y = 0.0
	if to_me.length() > 2.4 or to_me.length() < 0.05:
		return false
	return f.dot(to_me.normalized()) < -0.3

func items_of(n) -> Array:
	var id := String(n.id)
	var period := int(Game.day / 3)
	if int(Game.flags.get("ppd_" + id, -1)) != period or not Game.opened.has("pp_" + id):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(id) + period * 7919
		var out: Array = []
		var trader: bool = Game.L.get("vendors", {}).has(id) or Game.DB.get("vendors", {}).has(id)
		var c := rng.randi_range(40, 140) if trader else rng.randi_range(3, 45)
		if c > 0:
			out.append(["caps", c])
		for i in rng.randi_range(1, 3):
			var e: Array = TABLE[rng.randi() % TABLE.size()]
			if Game.DB.items.has(String(e[0])):
				out.append([String(e[0]), rng.randi_range(int(e[1]), int(e[2]))])
		# a few people carry something particular (keys and notes the story hands out)
		for x in Game.STORY.get("pockets", {}).get(id, []):
			if not Game.has(String(x[0])) and not Game.flags.has("ppgot_" + String(x[0])):
				out.append([String(x[0]), int(x[1])])
		Game.opened["pp_" + id] = out
		Game.flags["ppd_" + id] = period
	return Game.opened["pp_" + id]

func open(n) -> void:
	var items := items_of(n)
	Sfx.play("k_cloth1", -12.0)
	main.hud.screens.open_loot(String(n.display_name) + "'s pockets", items, func(_e): pass, _try.bind(n), false)

# the chance of lifting one thing without being felt
func chance(n, it: Array) -> float:
	var k := 0.3 + (int(Game.stats.agility) - 5) * 0.06
	if Game.perks.has("light_step"):
		k += 0.12
	k += 0.12 if (Game.time < 0.25 or Game.time > 0.8) else 0.0
	var w: float = 0.0 if String(it[0]) == "caps" else float(Game.item(String(it[0])).get("w", 0.5)) * int(it[1])
	k -= w * 0.05
	if String(it[0]) == "caps":
		k -= int(it[1]) / 400.0
	return clampf(k, 0.05, 0.92)

func _try(it: Array, n) -> bool:
	if not is_instance_valid(n):
		return false
	if Game.dev.get("checks", false) or randf() < chance(n, it):
		Game.add_karma(-1, "Picked a pocket")
		Game.flags["ppgot_" + String(it[0])] = 1
		return true
	# caught
	main.hud.screens.close()
	Game.add_karma(-5, "Caught picking a pocket")
	var line: String = ["Hey! Hands off!", "What do you think you're doing?", "Thief! Get your hand out of my coat!"][randi() % 3]
	Game.msg(String(n.display_name) + ": \"" + line + "\"")
	main.speak(line, String(n.id))
	n.face_yaw = atan2(main.player.global_position.x - n.global_position.x, main.player.global_position.z - n.global_position.z)
	var f = Game.STORY.get("npc_faction", {}).get(String(n.id))
	if f != null:
		Game.rep(String(f), -2)
	Game.flags["caught"] = int(Game.flags.get("caught", 0)) + 1
	if int(Game.flags.caught) >= 3 and not String(n.id) in main.ESSENTIAL:
		main.provoke(n, 0.0, Vector3.FORWARD)
	return false
