# Ammunition types (build 17). Every calibre comes three ways: standard, FMJ (full metal jacket: a little harder
# hitting, and it punches through machines, armour plate and cover-hugging robots for much more) and explosive
# (a tipped round that bursts on impact: more damage and a small blast, hard on the gun). The Haven 10mm Service
# Pistol finally takes 10mm (it took 9mm before: build 17 report). The variants turn up in loot and on gun traders'
# shelves, and the workbench makes them: FMJ from standard rounds and copper wire, explosive from standard rounds and
# blasting powder (which comes from loot, or from breaking down a pipe bomb).
class_name Ammo

# calibre id -> [short name, rounds per craft, value of a round, weight]
const CAL := {
	"ammo_9": ["9mm", 12, 1, 0.03],
	"ammo_10": ["10mm", 10, 2, 0.04],
	"ammo_44": [".44", 6, 3, 0.05],
	"ammo_rifle": ["Rifle", 6, 3, 0.05],
	"shells": ["Shotgun", 5, 3, 0.06],
}
const TEN_MM := ["service_pistol"]

static func kind(id: String) -> String:
	if id.ends_with("_fmj"):
		return "fmj"
	if id.ends_with("_ex"):
		return "ex"
	return ""

static func base(id: String) -> String:
	for s in ["_fmj", "_ex"]:
		if id.ends_with(s) and CAL.has(id.trim_suffix(s)):
			return id.trim_suffix(s)
	return id

static func variants(b: String) -> Array:
	if not CAL.has(b):
		return [b]
	return [b, b + "_fmj", b + "_ex"]

static func label(id: String) -> String:
	match kind(id):
		"fmj":
			return "FMJ"
		"ex":
			return "EXP"
	return "STD"

# damage multiplier for the loaded round against a target (robot/machine or not)
static func mult(id: String, machine: bool) -> float:
	match kind(id):
		"fmj":
			return 1.6 if machine else 1.12
		"ex":
			return 1.3
	return 1.0

static func merge(g: Node) -> void:
	var items: Dictionary = g.DB.items
	if not items.has("ammo_10"):
		items["ammo_10"] = {"n": "10mm Rounds", "t": "ammo", "w": 0.04, "v": 2, "desc": "Service-pistol ammunition. Haven 12's armoury standard."}
	items["blast_powder"] = {"n": "Blasting Powder", "t": "junk", "w": 0.2, "v": 6, "desc": "Coarse black powder in a twist of oilcloth. Packs the tips of explosive rounds."}
	for b in CAL:
		var c: Array = CAL[b]
		var bn := String(items.get(b, {}).get("n", c[0] + " Rounds"))
		items[b + "_fmj"] = {"n": bn.replace("Rounds", "FMJ Rounds").replace("Shells", "Slugs") if b != "shells" else "Shotgun Slugs (FMJ)", "t": "ammo", "w": c[3], "v": int(c[2]) * 2,
			"desc": "Full metal jacket. Hits a little harder and goes through machines and plate: +60% against robots and turrets."}
		items[b + "_ex"] = {"n": bn.replace("Rounds", "Explosive Rounds") if b != "shells" else "Explosive Shells", "t": "ammo", "w": c[3], "v": int(c[2]) * 3,
			"desc": "Tipped with a pinch of blasting powder: +30% damage and a small burst where it lands. Sets off fuel drums."}
	for w in TEN_MM:
		if items.has(w):
			items[w]["ammo"] = "ammo_10"
	# the workbench
	var R: Array = g.L.get("recipes", [])
	var have := {}
	for r in R:
		have[String(r.id)] = true
	var add := func(r: Dictionary):
		if not have.has(r.id):
			R.append(r)
	add.call({"id": "ammo_10", "n": "10mm Rounds x10", "need": {"scrap_metal": 1}, "out": ["ammo_10", 10]})
	add.call({"id": "blast_powder", "n": "Blasting Powder x3", "need": {"pipe_bomb": 1}, "out": ["blast_powder", 3], "d": "Break a pipe bomb down for its charge."})
	for b in CAL:
		var c: Array = CAL[b]
		var nm := String(c[0])
		add.call({"id": b + "_fmj", "n": "%s FMJ x%d" % [nm, int(c[1])], "need": {b: int(c[1]), "copper_wire": 1}, "out": [b + "_fmj", int(c[1])], "d": "Jacket standard rounds in copper."})
		add.call({"id": b + "_ex", "n": "%s Explosive x%d" % [nm, int(c[1])], "need": {b: int(c[1]), "blast_powder": 1}, "out": [b + "_ex", int(c[1])], "d": "Tip standard rounds with blasting powder."})
	# loot and traders
	var loot: Dictionary = g.DB.loot
	if loot.has("common"):
		loot.common.append(["ammo_10", 3, 8])
	if loot.has("uncommon"):
		loot.uncommon.append_array([["ammo_9_fmj", 4, 10], ["ammo_10_fmj", 3, 8], ["shells_fmj", 2, 5], ["blast_powder", 1, 2], ["ammo_10", 4, 10]])
	if loot.has("rare"):
		loot.rare.append_array([["ammo_rifle_fmj", 3, 8], ["ammo_44_ex", 3, 6], ["ammo_9_ex", 4, 10], ["shells_ex", 2, 5], ["ammo_rifle_ex", 2, 6], ["blast_powder", 2, 3]])
	var V: Dictionary = g.L.get("vendors", {})
	if V.has("duggan") and V.duggan.has("stock"):
		V.duggan.stock.append_array([["ammo_10", 40], ["ammo_9_fmj", 30], ["blast_powder", 2]])
	if V.has("brannock") and V.brannock.has("stock"):
		V.brannock.stock.append_array([["ammo_10", 60], ["ammo_10_fmj", 30], ["ammo_9_fmj", 40], ["ammo_44_fmj", 18], ["ammo_rifle_fmj", 18], ["shells_fmj", 15],
			["ammo_9_ex", 20], ["ammo_44_ex", 10], ["ammo_rifle_ex", 10], ["shells_ex", 10], ["blast_powder", 4]])
