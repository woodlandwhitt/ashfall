# Global game state for the slice: the region data exported from the three.js build, the player's stats and
# inventory, quests, flags, and the dialogue trees (lines taken from the original game).
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

var inv: Dictionary = {}
var flags: Dictionary = {}
var quests: Dictionary = {}   # id -> {"stage": int, "done": bool}
var kills: Dictionary = {}    # enemy type -> count
var hp := 100.0
var hp_max := 100.0
var caps := 25
var xp := 0
var level := 1
var mag := 12
var mag_size := 12
var reserve := 48
var player: Node3D
var main: Node3D
var nav_ready := false
var touch_move := Vector2.ZERO
var paused := false

const ITEMS := {
	"sample_well": "Well Water Sample", "sample_glow": "Glowing Water Sample", "stimpak": "Stim Shot",
	"ammo_9": "9mm Rounds", "hound_hide": "Hound Hide", "scrap": "Scrap Metal",
}

const QUESTS := {
	"bad_water": {"t": "Bad Water", "stages": [
		"Draw a water sample from the well in Dustwell.",
		"Draw a sample from any glowing pool out in the wastes.",
		"Take both samples back to Sheriff Voss."], "xp": 160, "caps": 60},
	"hounds": {"t": "The Hound Dens", "stages": [
		"Kill the mutant hounds at the old Dens north of town.",
		"Tell Cass at the saloon the hounds are dead."], "xp": 120, "caps": 40},
}

# Dialogue: node = {say, opts:[{t, go, act:[[op,...]], if:[[op,...]]}]}. A missing "go" ends the conversation.
var DIALOGUE := {
	"sheriff": {"name": "Sheriff Marla Voss", "entry": [["not_flag", "met_sheriff", "intro"], ["else", "hub"]], "nodes": {
		"intro": {"say": "Another face from behind a sealed door. Didn't think Haven 12 was still breathing. Marla Voss. I keep the peace in Dustwell, what there is of it.",
			"opts": [{"t": "What happened out here?", "go": "story"}, {"t": "My shelter's recycler is dead. I need a coolant regulator.", "go": "part"}]},
		"part": {"say": "A regulator. Only place in this valley that ever had parts like that is the Meridian plant. And Meridian is what's killing us. Seems your trouble and mine are the same trouble.",
			"opts": [{"t": "Killing you how?", "go": "story"}]},
		"story": {"say": "The reactor woke up two winters back. Nobody knows how. Since then the wells run green and half the town is coughing. Doc Halloran swears he can prove where the poison comes from, if somebody brings him samples.",
			"opts": [{"t": "I'll get him his samples.", "go": "accept", "act": [["flag", "met_sheriff"], ["start", "bad_water"]]}]},
		"accept": {"say": "Draw a flask from our well, right there in the square. Then one from any of the glowing pools out in the waste. Don't wade in. Halloran comes through town on the supply cart, so bring both back to me. And take these, you'll want them.",
			"opts": [{"t": "Thanks, Sheriff.", "act": [["give", "stimpak", 2], ["msg", "Received 2 Stim Shots"]]}]},
		"hub": {"say": "Speak.", "opts": [
			{"t": "I have both samples.", "if": [["stage", "bad_water", 2], ["has", "sample_well"], ["has", "sample_glow"]], "go": "proof",
				"act": [["take", "sample_well", 1], ["take", "sample_glow", 1], ["complete", "bad_water"]]},
			{"t": "Where should I go next?", "go": "dir"},
			{"t": "Tell me about Dustwell.", "go": "town"},
			{"t": "Goodbye."}]},
		"proof": {"say": "Green as a bottle. I'll get these to Halloran on the next cart. If he's right about where this comes from, God help whoever is up at Meridian. You did good. Take this.",
			"opts": [{"t": "Glad to help.", "go": "hub"}]},
		"work": {"say": "Hounds. The dens north-east of town have been breeding all spring and they've started taking goats. Next it'll be a kid. Thin them out and I'll pay.",
			"opts": [{"t": "Consider it done.", "act": [["start", "hounds"]]}, {"t": "Maybe later.", "go": "hub"}]},
		"hounds_done": {"say": "Heard the shooting from here. Good. The goats thank you, and so do I.", "opts": [{"t": "Back.", "go": "hub"}]},
		"dir": {"say": "Bunker Nine is south-east along the road. The Relay Tower is far west. Meridian is dead north and I wouldn't go without armor. Hound Dens are just north of town. Cass at the saloon knows the rest.",
			"opts": [{"t": "Understood.", "go": "hub"}]},
		"town": {"say": "Sixty-one people, nine goats, one well. We trade scrap for bullets and bullets for food. Before the reactor woke we were nearly comfortable. Now I bury somebody every month.",
			"opts": [{"t": "Back.", "go": "hub"}]},
	}},
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var f := FileAccess.open("res://data/region.json", FileAccess.READ)
	region = JSON.parse_string(f.get_as_text())
	var hf := FileAccess.open("res://data/height.f32", FileAccess.READ)
	hm = hf.get_buffer(hf.get_length()).to_float32_array()
	hw = int(region.heightSize[0])
	hd = int(region.heightSize[1])
	x0 = float(region.region.x0)
	z0 = float(region.region.z0)
	_extra_dialogue()

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

func known(q: String) -> bool:
	return quests.has(q)

func stage(q: String) -> int:
	return int(quests[q].stage) if quests.has(q) and not quests[q].done else -1

func is_done(q: String) -> bool:
	return quests.has(q) and quests[q].done

func start(q: String) -> void:
	if quests.has(q):
		return
	quests[q] = {"stage": 0, "done": false}
	msg("New quest: " + QUESTS[q].t)
	Sfx.play("o_quest")
	quest_changed.emit()
	check_quests()

func advance(q: String) -> void:
	if stage(q) < 0:
		return
	quests[q].stage += 1
	msg(QUESTS[q].t + ": " + QUESTS[q].stages[quests[q].stage])
	Sfx.play("o_quest")
	quest_changed.emit()

func complete(q: String) -> void:
	if not quests.has(q):
		quests[q] = {"stage": 0, "done": false}
	quests[q].done = true
	var d: Dictionary = QUESTS[q]
	caps += int(d.caps)
	msg("Quest complete: " + d.t + "  (+" + str(d.xp) + " XP, +" + str(d.caps) + " caps)")
	add_xp(int(d.xp))
	Sfx.play("o_quest")
	quest_changed.emit()

# stages that finish themselves when their condition becomes true
func check_quests() -> void:
	if stage("bad_water") == 0 and has("sample_well"):
		advance("bad_water")
	if stage("bad_water") == 1 and has("sample_glow"):
		advance("bad_water")
	if stage("hounds") == 0 and main and main.hounds_left() == 0:
		advance("hounds")

func add_xp(n: int) -> void:
	xp += n
	while xp >= level * 200:
		level += 1
		hp_max += 10
		hp = hp_max
		msg("Level up! You are now level " + str(level) + ".")
		Sfx.play("o_levelup")
	stats_changed.emit()

func current_objective() -> Dictionary:
	for q in ["bad_water", "hounds"]:
		if stage(q) >= 0:
			return {"q": q, "title": QUESTS[q].t, "text": QUESTS[q].stages[stage(q)]}
	return {}

func on_kill(type: String) -> void:
	kills[type] = int(kills.get(type, 0)) + 1
	check_quests()

# ---------------------------------------------------------------- dialogue conditions and actions
func cond(list) -> bool:
	if list == null:
		return true
	for c in list:
		match c[0]:
			"has": if not has(c[1]): return false
			"flag": if not flags.has(c[1]): return false
			"not_flag": if flags.has(c[1]): return false
			"stage": if stage(c[1]) != int(c[2]): return false
			"done": if not is_done(c[1]): return false
			"unknown": if known(c[1]): return false
			"known": if not known(c[1]): return false
	return true

func act(list) -> void:
	if list == null:
		return
	for a in list:
		match a[0]:
			"flag": flags[a[1]] = true
			"start": start(a[1])
			"complete": complete(a[1])
			"give": give(a[1], int(a[2]))
			"take": take(a[1], int(a[2]))
			"msg": msg(a[1])
			"caps": caps += int(a[1]); stats_changed.emit()
			"heal": hp = hp_max; stats_changed.emit()
	check_quests()

func entry_node(id: String) -> String:
	var d: Dictionary = DIALOGUE[id]
	for e in d.entry:
		if e[0] == "else":
			return e[1]
		if e[0] == "not_flag" and not flags.has(e[1]):
			return e[2]
		if e[0] == "flag" and flags.has(e[1]):
			return e[2]
	return "hub"

# townsfolk outside the sheriff speak their lines from the original game (converted by tools/dialogue.mjs)
func _extra_dialogue() -> void:
	var extra: Dictionary = region.get("dialogue", {})
	for id in extra:
		if not DIALOGUE.has(id):
			DIALOGUE[id] = extra[id]
	# everyone else (saloon patrons, card players, the lamplighter) gets a line of their own
	var barks := ["Water's gone green again. Don't drink from the trough.", "You're from the Shelter? Huh. Thought you'd be taller.",
		"If you're going north, go armed. The hounds have got bold.", "Cass waters the whiskey. Everybody knows. Nobody says.",
		"Two winters since the reactor woke up. Feels like twenty.", "Got nothing to sell you, friend. Got nothing at all.",
		"Sheriff's fair. Hard, but fair. That's rare out here.", "Heard a caravan got hit on the spur road. Raiders again."]
	for n in region.npcs:
		if not DIALOGUE.has(n.id):
			var nm := String(n.name).capitalize()
			if nm.begins_with("Patron") or nm.begins_with("Gambler") or nm.begins_with("Lamp"):
				nm = {"P": "Saloon Regular", "G": "Card Player", "L": "Lamplighter"}[nm[0]]
			DIALOGUE[n.id] = {"name": nm, "entry": [["else", "b"]], "nodes": {"b": {"say": barks[hash(n.id) % barks.size()], "opts": [{"t": "Take care."}]}}}

func hurt(d: float) -> void:
	if hp <= 0:
		return
	hp = maxf(0.0, hp - d)
	stats_changed.emit()
	if main:
		main.on_player_hurt(d)
