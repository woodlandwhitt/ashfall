# The Ashwood's settlements and ruins (build 15): the trading town of Cinder Gap, the Ashborn tribe's walled camp,
# the fire lookout and the hermit's cabin, the ruins of Mercy Falls and its hospital, and the old drive-in. Every
# building is put together here from boxes, cylinders and cones (scripts/builds.gdshader paints the boards, tin,
# canvas, logs and concrete from world position), merged into one mesh per material per building.
#
# Buildings turn only in quarter turns, so their walls are axis-aligned boxes: those that stand on the ground go
# into the region's solid list (main builds the colliders from it, and both navigation bakers read it, so people and
# enemies walk round them and in through the doors); anything raised or sloped gets a collider of its own.
class_name Frontier
extends Node3D

# where the places are, and how far round them the forest is kept back
const SITES := {"stillwater": [-60.0, -748.0, 52.0], "old_meridian": [420.0, -768.0, 165.0], "glass_camp": [1150.0, -612.0, 32.0], "silo9": [1150.0, -792.0, 34.0],
	"cinder_gap": [820.0, -40.0, 62.0], "ashborn": [1310.0, -330.0, 40.0], "lookout": [990.0, -232.0, 22.0],
	"mercy_falls": [1120.0, 300.0, 64.0], "drivein": [690.0, 232.0, 38.0],
	"lantern_row": [604.0, 120.0, 54.0], "starfall": [676.0, -418.0, 40.0], "havens_door": [0.0, 205.0, 18.0],
	"wayside": [900.0, -600.0, 30.0], "holloway": [-300.0, -600.0, 32.0], "relay_k": [1000.0, 100.0, 26.0]}

# build 17: ground levelled under a site before the terrain is built (x, z, inner radius flat, outer radius blended)
const FLAT := [[684.0, -424.0, 17.0, 32.0], [652.0, -397.0, 6.0, 12.0], [604.0, 120.0, 30.0, 46.0],
	[900.0, -600.0, 16.0, 28.0], [-300.0, -600.0, 16.0, 28.0], [1000.0, 100.0, 12.0, 24.0]]

static func level_ground() -> void:
	if Game.area != "world":
		return
	for f in FLAT:
		var cx: float = f[0]
		var cz: float = f[1]
		var r0: float = f[2]
		var r1: float = f[3]
		var h0 := Game.height(cx, cz)
		for z in range(int(cz - r1), int(cz + r1) + 1):
			for x in range(int(cx - r1), int(cx + r1) + 1):
				var dd := Vector2(x - cx, z - cz).length()
				if dd > r1:
					continue
				var ix := x - int(Game.x0)
				var iz := z - int(Game.z0)
				if ix < 0 or iz < 0 or ix >= Game.hw or iz >= Game.hd:
					continue
				var w := 1.0 if dd <= r0 else smoothstep(r1, r0, dd)
				var a := iz * Game.hw + ix
				Game.hm[a] = lerpf(Game.hm[a], h0, w)

static var _list: Array = []
static var _mats: Dictionary = {}
var main
var fires: Array = []

static func blocked(x: float, z: float) -> bool:
	for k in SITES:
		var s: Array = SITES[k]
		if Vector2(x - s[0], z - s[1]).length() < s[2]:
			return true
	return false

# ---------------------------------------------------------------- the layout
static func R(k: String, x: float, z: float, r := 0, extra := {}) -> Dictionary:
	var d := {"k": k, "x": x, "z": z, "r": r}
	d.merge(extra, true)
	return d

static func layout() -> Array:
	if not _list.is_empty():
		return _list
	var L: Array = []
	# Cinder Gap: a main street along the east road, the trading post, the Ember Room, the doctor, the town hall,
	# a market, the water tower, and a gate of scrap walls with two watchtowers on the west road in
	L.append(R("shack", 789, -53, 0, {"w": 6, "d": 5, "role": "home", "m": "plank", "roof": "tin"}))
	L.append(R("shack", 802, -54, 0, {"w": 8, "d": 6, "role": "shop", "m": "tin_teal", "roof": "tin", "sign": "PIKE'S GOODS"}))
	L.append(R("hall", 816, -56, 0, {"w": 12, "d": 9, "role": "bar", "m": "plank", "roof": "tin_red", "sign": "THE EMBER ROOM"}))
	L.append(R("shack", 832, -54, 0, {"w": 7, "d": 6, "role": "clinic", "m": "plank", "roof": "tin", "sign": "DOC SORREL"}))
	L.append(R("shack", 846, -53, 0, {"w": 6, "d": 5, "role": "home", "m": "tin", "roof": "tin_red"}))
	L.append(R("shack", 786, -28, 2, {"w": 6, "d": 5, "role": "home", "m": "tin_red", "roof": "tin"}))
	L.append(R("shack", 799, -27, 2, {"w": 8, "d": 6, "role": "office", "m": "plank", "roof": "tin", "sign": "TOWN HALL"}))
	L.append(R("stall", 825, -32, 2, {"goods": "food"}))
	L.append(R("stall", 831, -32, 2, {"goods": "scrap"}))
	L.append(R("shack", 836, -24, 2, {"w": 6, "d": 5, "role": "home", "m": "plank", "roof": "tin"}))
	L.append(R("shack", 856, -30, 2, {"w": 7, "d": 6, "role": "workshop", "m": "tin", "roof": "tin", "sign": "REPAIRS"}))
	L.append(R("water_tower", 828, -17, 0))
	L.append(R("tower", 777, -51, 0))
	L.append(R("tower", 777, -30, 0))
	L.append(R("fence", 777, -59.5, 1, {"len": 14.0}))
	L.append(R("fence", 777, -21.5, 1, {"len": 14.0}))
	L.append(R("sign", 770, -46, 1, {"text": "CINDER GAP\nTRADERS WELCOME\nRAIDERS ARE NOT"}))
	L.append(R("campfire", 808.0, -48.5, 0, {"s": 0.8}))
	L.append(R("seat", 806.5, -46.5, 1, {"id": "Rockingchair_01"}))
	L.append(R("seat", 810.0, -46.4, 3, {"id": "SchoolChair_01"}))
	L.append(R("seat", 793.0, -49.6, 0, {"id": "Rockingchair_01"}))
	L.append(R("seat", 835.2, -50.2, 0, {"id": "SchoolChair_01"}))
	L.append(R("seat", 802.0, -30.6, 2, {"id": "ArmChair_01"}))
	L.append(R("kit", 858, -63, 0, {"id": "k:q_Vehicle_Truck", "len": 6.0, "yaw": 0.4}))
	L.append(R("kit", 860, -47, 0, {"id": "k:q_Wheels_Stack", "len": 1.4}))
	L.append(R("kit", 852, -33, 0, {"id": "k:q_Barrel", "len": 0.9}))
	L.append(R("kit", 853, -34.2, 0, {"id": "k:s_barrel-open", "len": 0.9}))
	L.append(R("chest", 798.8, -54.9, 0, {"id": "cg_store", "tier": "uncommon", "owned": true}))
	L.append(R("chest", 831.2, -56.3, 0, {"id": "cg_doc", "tier": "common", "owned": true}))
	L.append(R("bench", 858.2, -28.2, 2))
	L.append(R("sign", 900, -77, 3, {"text": "LOOKOUT  1 KM\nASHBORN LAND  BEYOND"}))
	L.append(R("sign", 870, 10, 2, {"text": "MERCY FALLS  2 KM\nDON'T"}))
	L.append(R("sign", 560, -69, 1, {"text": "KETTLE PASS\nCINDER GAP  3 KM"}))
	# the Ashborn: a palisade ring with its gate to the west, hide tents round a great fire, the elders' longhouse,
	# totems, drying racks and the Ember Mother, a burnt pine hung with charms
	L.append(R("palisade", 1310, -330, 0, {"rad": 27.0, "gate": PI, "gap": 0.17}))
	for i in 7:
		var a := PI * 0.35 + i * (PI * 1.3 / 6.0)
		L.append(R("tipi", 1310 + cos(a) * 16.0, -330 + sin(a) * 16.0, 0, {"rad": 2.3 + (i % 2) * 0.4, "face": a + PI}))
	L.append(R("longhouse", 1310, -349, 0, {"w": 12, "d": 7}))
	L.append(R("campfire", 1310.0, -330.0, 0, {"s": 1.6}))
	L.append(R("totem", 1280, -334.5, 0, {"h": 4.2}))
	L.append(R("totem", 1280, -325.5, 0, {"h": 4.2}))
	L.append(R("totem", 1310, -339, 0, {"h": 5.5}))
	L.append(R("rack", 1325, -318, 1))
	L.append(R("rack", 1296, -316, 0))
	L.append(R("snag", 1329, -334, 0))
	for i in 5:
		var a := i * TAU / 5.0 + 0.3
		L.append(R("log_seat", 1310 + cos(a) * 4.2, -330 + sin(a) * 4.2, 0, {"yaw": a + PI * 0.5}))
	L.append(R("chest", 1315.2, -351.6, 0, {"id": "ab_hoard", "tier": "rare", "owned": true}))
	# the fire lookout on its hill, and the hermit's cabin under it
	L.append(R("lookout", 997, -236, 0))
	L.append(R("cabin", 981, -239, 1, {"w": 6, "d": 5}))
	L.append(R("outhouse", 976, -228, 1))
	L.append(R("kit", 985, -230, 0, {"id": "k:g_trunk", "len": 2.4, "yaw": 0.7}))
	L.append(R("kit", 987, -231, 0, {"id": "k:g_debris-wood", "len": 2.0}))
	L.append(R("seat", 984.5, -236.0, 1, {"id": "Rockingchair_01"}))
	L.append(R("campfire", 986.0, -244.0, 0, {"s": 0.6}))
	# Mercy Falls: what's left of a town on the plateau, and the hospital it was named for
	L.append(R("hospital", 1132, 314, 2, {"w": 26, "d": 16}))
	var ruins := [[1092, 300, 1], [1100, 322, 0], [1148, 285, 3], [1160, 304, 3], [1112, 270, 0], [1086, 280, 1]]
	for i in ruins.size():
		var rr: Array = ruins[i]
		L.append(R("ruin", rr[0], rr[1], rr[2], {"w": 7 + (i % 3) * 2, "d": 6 + (i % 2) * 2, "seed": i}))
	L.append(R("kit", 1108, 295, 0, {"id": "k:q_Vehicle_Sports", "len": 4.6, "yaw": 1.2, "burnt": true}))
	L.append(R("kit", 1140, 296, 0, {"id": "k:q_Vehicle_Pickup", "len": 5.2, "yaw": -0.5, "burnt": true}))
	L.append(R("kit", 1122, 330, 0, {"id": "k:q_TrafficBarrier_1", "len": 2.4, "yaw": 0.2}))
	L.append(R("kit", 1126, 331, 0, {"id": "k:q_PlasticBarrier", "len": 2.2, "yaw": -0.3}))
	L.append(R("chest", 1128.0, 321.2, 0, {"id": "mf_pharm", "tier": "rare"}))
	L.append(R("chest", 1097.0, 323.5, 0, {"id": "mf_house", "tier": "common"}))
	# the Sunset drive-in: the screen, the cars still parked facing it, the speaker posts and the snack bar
	L.append(R("screen", 690, 250, 2))
	L.append(R("shack", 676, 222, 1, {"w": 8, "d": 6, "role": "snack", "m": "tin_red", "roof": "tin", "sign": "SNACK BAR"}))
	var cars := ["k:q_Vehicle_Sports", "k:q_Vehicle_Pickup", "k:q_Vehicle_Truck"]
	for row in 2:
		for c in 5:
			if (row * 5 + c) % 3 == 1:
				continue
			L.append(R("kit", 682 + c * 5.5, 236 - row * 9.0, 0, {"id": cars[(row + c) % 3], "len": 5.0, "yaw": PI + sin(c * 2.1 + row) * 0.15, "burnt": (c + row) % 2 == 0}))
	for row in 2:
		for c in 6:
			L.append(R("post", 679.5 + c * 5.5, 236 - row * 9.0 + 2.6, 0))
	L.append(R("chest", 674.0, 220.0, 0, {"id": "di_safe", "tier": "uncommon"}))
	L.append(R("campfire", 701.0, 226.0, 0, {"s": 0.7}))
	_north(L)
	_dress(L)
	_ruins20(L)
	# ---------------------------------------------------------------- build 17
	# Lantern Row: a trading street east of Saltreach on the Kettle road, lamps on every post. The Lantern is its bar;
	# behind the bar, the back room nobody admits is there: the Quiet Hands, the valley's thieves' guild
	L.append(R("shack", 578, 107, 0, {"w": 6, "d": 5, "role": "home", "m": "plank", "roof": "tin"}))
	L.append(R("shack", 589, 106, 0, {"w": 8, "d": 6, "role": "shop", "m": "tin_teal", "roof": "tin", "sign": "ROW SUPPLY"}))
	L.append(R("hall", 604, 104, 0, {"w": 12, "d": 9, "role": "bar", "m": "plank", "roof": "tin_red", "sign": "THE LANTERN"}))
	L.append(R("shack", 620, 107, 0, {"w": 7, "d": 6, "role": "shop", "m": "tin", "roof": "tin", "sign": "LOU'S PAWN"}))
	L.append(R("cabin", 604, 89, 2, {"w": 6, "d": 5}))
	L.append(R("shack", 580, 134, 2, {"w": 6, "d": 5, "role": "home", "m": "tin_red", "roof": "tin"}))
	L.append(R("shack", 593, 135, 2, {"w": 8, "d": 6, "role": "office", "m": "plank", "roof": "tin", "sign": "ROW HALL"}))
	L.append(R("stall", 606, 132, 2, {"goods": "food"}))
	L.append(R("stall", 612, 132, 2, {"goods": "scrap"}))
	L.append(R("shack", 623, 134, 2, {"w": 6, "d": 5, "role": "home", "m": "plank", "roof": "tin"}))
	L.append(R("shack", 634, 133, 2, {"w": 7, "d": 6, "role": "workshop", "m": "tin", "roof": "tin_red", "sign": "TINKER"}))
	L.append(R("water_tower", 640, 116, 0))
	L.append(R("tower", 566, 112, 0))
	L.append(R("tower", 566, 128, 0))
	L.append(R("fence", 566, 104.5, 1, {"len": 12.0}))
	L.append(R("fence", 566, 135.5, 1, {"len": 12.0}))
	L.append(R("sign", 559, 117, 1, {"text": "LANTERN ROW\nLIGHTS ON\nHANDS IN POCKETS"}))
	L.append(R("campfire", 600.0, 120.5, 0, {"s": 0.9}))
	L.append(R("seat", 598.0, 122.5, 1, {"id": "Rockingchair_01"}))
	L.append(R("seat", 602.4, 122.4, 3, {"id": "SchoolChair_01"}))
	L.append(R("seat", 590.0, 110.2, 0, {"id": "ArmChair_01"}))
	L.append(R("bench", 615.0, 125.0, 2))
	L.append(R("bench", 585.0, 125.0, 2))
	for i in 6:
		L.append(R("post", 572 + i * 12.0, 116.5, 0))
	L.append(R("kit", 646, 126, 0, {"id": "k:q_Vehicle_Pickup", "len": 5.0, "yaw": 1.1, "burnt": true}))
	L.append(R("kit", 642, 104, 0, {"id": "k:q_Barrel", "len": 0.9}))
	L.append(R("chest", 588.8, 103.8, 0, {"id": "lr_store", "tier": "uncommon", "owned": true}))
	L.append(R("chest", 620.5, 104.6, 0, {"id": "lr_pawn", "tier": "rare", "owned": true}))
	L.append(R("chest", 606.0, 87.4, 0, {"id": "qh_vault", "tier": "rare", "owned": true}))
	L.append(R("sign", 540, 118, 1, {"text": "LANTERN ROW  50 M\nSALTREACH  250 M  WEST"}))
	# Starfall: what came down over the eastern ridge, a saucer ploughed into the scrub with a long scar behind it, and
	# Orrin Pike's camp on the rise where he watched it fall
	L.append(R("crater", 684, -424, 0, {"rad": 12.5}))
	L.append(R("ufo", 684, -424, 0))
	L.append(R("campfire", 702.0, -420.5, 0, {"s": 0.35}))
	L.append(R("campfire", 693.0, -431.0, 0, {"s": 0.28}))
	L.append(R("tent", 650, -398, 0))
	L.append(R("campfire", 654.0, -394.0, 0, {"s": 0.6}))
	L.append(R("seat", 656.0, -392.0, 1, {"id": "Rockingchair_01"}))
	L.append(R("post", 648, -394, 0))
	L.append(R("kit", 645, -400, 0, {"id": "k:g_trunk", "len": 2.0, "yaw": 0.4}))
	L.append(R("chest", 651.0, -401.0, 0, {"id": "orrin_box", "tier": "uncommon", "owned": true}))
	L.append(R("sign", 640, -380, 2, {"text": "PRIVATE OBSERVATORY\nKEEP OUT\n(UNLESS YOU SAW IT TOO)"}))
	# Haven's Door: the camp the vault folk pitched outside their own front door while they wait on the regulator
	for t in [[-8.0, 206.0], [8.0, 206.0], [-4.0, 197.0], [6.0, 196.0]]:
		L.append(R("tent", t[0], t[1], 0))
	L.append(R("campfire", 0.0, 203.0, 0, {"s": 0.8}))
	L.append(R("log_seat", -2.6, 203.6, 0, {"yaw": 1.3}))
	L.append(R("log_seat", 2.6, 202.4, 0, {"yaw": -1.7}))
	L.append(R("kit", -11, 199, 0, {"id": "k:q_Barrel", "len": 0.9}))
	L.append(R("kit", 11, 199, 0, {"id": "k:g_debris-wood", "len": 1.8}))
	L.append(R("chest", -10.0, 210.0, 0, {"id": "hd_supplies", "tier": "common", "owned": true}))
	L.append(R("sign", 0, 216, 0, {"text": "HAVEN 12\nCAMP OF THE DOOR\nWATER BY RATION"}))
	# the main quest's pieces out in the world: the instrument shop's rig cart at Kestrel, the old furnace at the
	# Cinder Quarry, the salt factor's strongbox under Saltreach's weigh-scales
	L.append(R("rig_cart", 292, -322, 0))
	L.append(R("furnace", 158, 362, 0))
	L.append(R("strongbox", 329, 58, 0))
	# build 17: the Meridian reactor opens through its north wall into a containment hall (Reactor does the rest)
	L.append(R("reactor_hall", 15, -221, 0, {"y": 5.218, "w": 16.0, "d": 14.0}))
	L.append(R("reactor_dress", 15, -207, 0, {"y": 5.218}))
	_list = L
	return L

# build 16: the north. Stillwater on its reservoir, the ruins of Old Meridian and the Highrisers' Spire, the Garage
# market, the Children of the Glass on the crater rim, and Silo 9 at the bottom of the Glass Bowl
static func _north(L: Array) -> void:
	var wy := float(Game.region.get("lake", {}).get("y", 2.0))
	# Stillwater: houses facing the water, the co-op, the smokehouse, the harbourmaster, the boathouse and its piers
	L.append(R("hall", -48, -773, 0, {"w": 12, "d": 9, "role": "shop", "m": "plank", "roof": "tin_teal", "sign": "STILLWATER CO-OP"}))
	L.append(R("shack", -80, -770, 3, {"w": 6, "d": 5, "role": "home", "m": "plank", "roof": "tin"}))
	L.append(R("shack", -80, -754, 3, {"w": 6, "d": 5, "role": "home", "m": "tin_teal", "roof": "tin_red"}))
	L.append(R("shack", -62, -727, 2, {"w": 7, "d": 6, "role": "smoke", "m": "plank", "roof": "tin", "sign": "SMOKEHOUSE"}))
	L.append(R("shack", -40, -728, 2, {"w": 8, "d": 6, "role": "office", "m": "plank", "roof": "tin_red", "sign": "HARBOURMASTER"}))
	L.append(R("shack", -24, -752, 1, {"w": 6, "d": 5, "role": "home", "m": "tin", "roof": "tin"}))
	L.append(R("shack", -92, -738, 3, {"w": 8, "d": 7, "role": "boats", "m": "plank", "roof": "tin", "sign": "BOATS"}))
	L.append(R("pier", -112, -748, 0, {"len": 26.0, "y": wy + 0.55}))
	L.append(R("pier", -110, -726, 0, {"len": 20.0, "y": wy + 0.55}))
	L.append(R("boat", -118, -744.5, 0, {"y": wy, "yaw": 0.15}))
	L.append(R("boat", -114, -722.5, 0, {"y": wy, "yaw": -0.2}))
	L.append(R("boat", -126, -751.5, 0, {"y": wy, "yaw": 0.4}))
	L.append(R("windmill", -30, -778, 0))
	L.append(R("rack", -70, -718, 0))
	L.append(R("rack", -54, -716, 0))
	L.append(R("campfire", -56.0, -756.0, 0, {"s": 0.8}))
	L.append(R("log_seat", -56.0, -752.0, 0, {"yaw": 0.0}))
	L.append(R("log_seat", -52.0, -757.5, 0, {"yaw": 1.4}))
	L.append(R("seat", -76.2, -770.0, 3, {"id": "Rockingchair_01"}))
	L.append(R("seat", -37.0, -732.2, 2, {"id": "ArmChair_01"}))
	L.append(R("chest", -52.0, -776.4, 0, {"id": "sw_coop", "tier": "uncommon", "owned": true}))
	L.append(R("chest", -95.5, -741.0, 0, {"id": "sw_boats", "tier": "common", "owned": true}))
	L.append(R("bench", -89.0, -735.5, 3))
	L.append(R("sign", -98, -668, 1, {"text": "STILLWATER\nCLEAN WATER  FAIR TRADE\nNO TROUBLE"}))
	L.append(R("sign", -166, -560, 0, {"text": "NORTHGATE\nSTILLWATER  2 KM"}))
	L.append(R("kit", -215, -856, 0, {"id": "k:q_Pipes", "len": 3.0, "yaw": 0.3}))
	# Old Meridian: tower shells on every block, a few fallen; the Spire; the Garage market at the south-west gate
	var rng := RandomNumberGenerator.new()
	rng.seed = 1616
	for bx in 6:
		for bz in 4:
			var cx := 295.0 + bx * 50.0
			var cz := -702.5 - bz * 45.0
			if bx == 0 and bz == 0:
				continue                    # the Garage
			if bx == 3 and bz == 2:
				continue                    # the Spire
			var roll := rng.randf()
			if roll < 0.18:
				L.append(R("rubble", cx, cz, 0, {"w": 30.0, "d": 26.0, "seed": bx * 7 + bz}))
				continue
			var w := snappedf(rng.randf_range(16, 30), 2.0)
			var dd := snappedf(rng.randf_range(14, 24), 2.0)
			L.append(R("highrise", cx + rng.randf_range(-3, 3), cz + rng.randf_range(-3, 3), rng.randi_range(0, 3), {"w": w, "d": dd,
				"h": snappedf(rng.randf_range(10, 34), 3.4), "seed": bx * 11 + bz * 3, "broken": rng.randf() < 0.45}))
			if rng.randf() < 0.6:
				L.append(R("kit", cx + rng.randf_range(-20, 20), cz + 21.5 + rng.randf_range(-1, 1), 0, {"id": ["k:q_Vehicle_Sports", "k:q_Vehicle_Pickup", "k:q_Vehicle_Truck"][rng.randi() % 3], "len": 5.0, "yaw": PI * 0.5 + rng.randf_range(-0.4, 0.4), "burnt": true}))
	L.append(R("highrise", 445, -792.5, 2, {"w": 24, "d": 20, "h": 44.2, "seed": 99, "broken": false, "lobby": true, "sign": "THE SPIRE"}))
	L.append(R("cage", 438.5, -799.0, 0))
	L.append(R("campfire", 452.0, -790.0, 0, {"s": 0.7}))
	L.append(R("seat", 448.0, -796.6, 0, {"id": "ArmChair_01"}))
	L.append(R("chest", 455.0, -800.0, 0, {"id": "om_spire", "tier": "rare", "owned": true}))
	L.append(R("garage", 295, -702.5, 0, {"w": 30, "d": 26}))
	L.append(R("stall", 288, -703, 0, {"goods": "scrap"}))
	L.append(R("stall", 296, -703, 0, {"goods": "food"}))
	L.append(R("campfire", 302.0, -696.0, 0, {"s": 0.6}))
	L.append(R("chest", 284.0, -712.0, 0, {"id": "om_garage", "tier": "uncommon", "owned": true}))
	L.append(R("bench", 305.0, -711.0, 0))
	L.append(R("sign", 296, -652, 0, {"text": "OLD MERIDIAN\nCITY LIMIT\nPOP. 0"}))
	L.append(R("sign", 300, -560, 0, {"text": "AIRFIELD CUT\nOLD MERIDIAN  2 KM"}))
	# the Children of the Glass, camped on the Bowl's south rim
	for i in 6:
		var a := PI * 0.15 + i * PI * 0.14
		L.append(R("tent", 1150 + cos(a + PI) * 15.0, -612 + sin(a) * 10.0 + 4.0, (i + 1) % 4))
	L.append(R("shrine", 1150, -628, 0))
	L.append(R("campfire", 1150.0, -612.0, 0, {"s": 1.0}))
	for i in 4:
		L.append(R("banner", 1150 + (i - 1.5) * 9.0, -600.0, 0))
	L.append(R("chest", 1162.0, -606.0, 0, {"id": "gc_tithe", "tier": "uncommon", "owned": true}))
	L.append(R("sign", 1222, -540, 1, {"text": "THE GLASS BOWL\nTURN BACK\nOR BE MADE CLEAN"}))
	# Silo 9: the blockhouse, the silo's cap, glass growing out of the crater floor
	L.append(R("blockhouse", 1146, -802, 0, {"w": 10, "d": 8}))
	L.append(R("silo", 1164, -790, 0))
	for i in 14:
		var a := i * 2.4
		var r := 30.0 + fmod(i * 13.7, 40.0)
		L.append(R("shards", 1150 + cos(a) * r, -790 + sin(a) * r, 0, {"seed": i}))
	L.append(R("sign", 1150, -668, 0, {"text": "SILO 9\nRESTRICTED AREA\nUSE OF DEADLY FORCE AUTHORIZED"}))

# ---------------------------------------------------------------- setup: solids into the region, the world objects, then the meshes
# (called by main before it builds colliders, so the walls are in the collision and the navigation from the start)
static func prepare() -> void:
	if Game.area != "world" or Game.region.get("frontier", false):
		return
	Game.region["frontier"] = true
	for d in layout():
		for s in _solids_of(d):
			Game.region.solids.append(s)
		match String(d.k):
			"chest":
				var c := {"id": String(d.id), "tier": String(d.tier), "x": float(d.x), "z": float(d.z), "y": Game.height(d.x, d.z) + 0.2}
				if d.get("owned", false):
					c["owned"] = true
				Game.W.get_or_add("chests", []).append(c)
			"bench":
				Game.W.get_or_add("benches", []).append({"x": float(d.x), "z": float(d.z), "y": Game.height(d.x, d.z)})

func setup(m) -> void:
	main = m
	if Game.region.has("lake"):
		add_child(_lake(Game.region.lake))
	for d in layout():
		var n := build(d)
		if n:
			add_child(n)
			n.global_position = Vector3(float(d.x), _ground(d), float(d.z))
			n.rotation.y = int(d.r) * PI * 0.5
			_after(n, d)

# the reservoir: a flat sheet of water at its level, a little wider than the basin it fills (the shore hides the rest)
func _lake(L: Dictionary) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rx := float(L.rx) * 1.08
	var rz := float(L.rz) * 1.08
	var seg := 64
	var rings := 6
	for r in rings:
		var f0 := float(r) / rings
		var f1 := float(r + 1) / rings
		for k in seg:
			var a0 := k * TAU / seg
			var a1 := (k + 1) * TAU / seg
			var ps := [Vector3(cos(a0) * rx * f0, 0, sin(a0) * rz * f0), Vector3(cos(a1) * rx * f0, 0, sin(a1) * rz * f0),
				Vector3(cos(a1) * rx * f1, 0, sin(a1) * rz * f1), Vector3(cos(a0) * rx * f1, 0, sin(a0) * rz * f1)]
			var up := Vector3.UP
			var w := Color.WHITE
			Flora.tri(st, [ps[0], ps[1], ps[2]], [up, up, up], [w, w, w])
			Flora.tri(st, [ps[0], ps[2], ps[3]], [up, up, up], [w, w, w])
	var mi := MeshInstance3D.new()
	mi.name = "Lake"
	mi.mesh = st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://scripts/lake.gdshader")
	mat.set_shader_parameter("radii", Vector2(float(L.rx), float(L.rz)))
	mat.set_shader_parameter("centre", Vector2(float(L.x), float(L.z)))
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(float(L.x), float(L.y), float(L.z))
	return mi

# the floor under a spot, if it's inside one of the buildings (people and things placed indoors stand on it)
static func floor_at(x: float, z: float) -> float:
	if Game.area != "world":
		return -INF
	for d in layout():
		if not String(d.k) in ["shack", "hall", "cabin", "hospital", "longhouse", "ruin", "outhouse", "highrise", "blockhouse", "garage", "reactor_hall"]:
			continue
		var w := float(d.get("w", 2.0)) * 0.5
		var dd := float(d.get("d", 2.0)) * 0.5
		if int(d.r) % 2 == 1:
			var t := w
			w = dd
			dd = t
		if absf(x - float(d.x)) < w and absf(z - float(d.z)) < dd:
			return _ground(d) + (0.12 if String(d.k) in ["hospital", "ruin", "highrise", "blockhouse", "garage", "reactor_hall"] else 0.16)
	return -INF

# the ground a building stands on: the highest point under its footprint, so no floor is ever buried
static func _ground(d: Dictionary) -> float:
	var w := float(d.get("w", 2.0)) * 0.5
	var dd := float(d.get("d", 2.0)) * 0.5
	if int(d.r) % 2 == 1:
		var t := w
		w = dd
		dd = t
	if d.has("y"):
		return float(d.y)
	var x := float(d.x)
	var z := float(d.z)
	# a tent, a shrine or a parked wreck settles into a slope rather than standing on its highest corner (build 19)
	if String(d.k) in ["tent", "shrine"] or (String(d.k) == "kit" and float(d.get("len", 1.0)) > 2.5):
		var rr := 1.8 if String(d.k) != "kit" else float(d.len) * 0.4
		var lo := Game.height(x, z)
		for i in 8:
			lo = minf(lo, Game.height(x + cos(i * TAU / 8.0) * rr, z + sin(i * TAU / 8.0) * rr))
		return (lo + Game.height(x, z)) * 0.5 if String(d.k) == "kit" else lo + 0.04
	match String(d.k):
		"palisade", "campfire", "kit", "seat", "post", "log_seat", "chest", "bench", "sign", "snag", "totem", "tipi", "banner", "shards", "rubble", "ufo", "crater", \
				"fence", "pump", "canopy", "sandbags", "washline", "crates", "watertank", "table", "scrap", "lamp", "tripod", "tarp", "generator", "antenna", "board", "lights", "garden":
			return Game.height(x, z)
	var g := -INF
	for p in [Vector2(-w, -dd), Vector2(w, -dd), Vector2(-w, dd), Vector2(w, dd), Vector2.ZERO]:
		g = maxf(g, Game.height(x + p.x, z + p.y))
	return g

# how far the ground falls away under a building from the floor it stands on (its footing goes down that far)
static func _sink(d: Dictionary) -> float:
	if d.has("y") or not d.has("w"):
		return 0.0
	var w := float(d.get("w", 2.0)) * 0.5
	var dd := float(d.get("d", 2.0)) * 0.5
	if int(d.r) % 2 == 1:
		var t := w
		w = dd
		dd = t
	var lo := INF
	for p in [Vector2(-w, -dd), Vector2(w, -dd), Vector2(-w, dd), Vector2(w, dd), Vector2(0, -dd), Vector2(0, dd), Vector2(-w, 0), Vector2(w, 0)]:
		lo = minf(lo, Game.height(float(d.x) + p.x, float(d.z) + p.y))
	return maxf(0.0, _ground(d) - lo)

# the walls standing on the ground, as world boxes for the region's solid list [x0, x1, z0, z1, y0, y1]
static func _solids_of(d: Dictionary) -> Array:
	var kit := Kit.new()
	kit.solids_only = true
	_shape(kit, d)
	var out: Array = []
	var g := _ground(d)
	var b := Basis(Vector3.UP, int(d.r) * PI * 0.5)
	for s in kit.solids:
		var ab: AABB = s
		var lo := Vector3(INF, INF, INF)
		var hi := -lo
		for i in 8:
			var p: Vector3 = b * ab.get_endpoint(i)
			lo = lo.min(p)
			hi = hi.max(p)
		out.append([snappedf(d.x + lo.x, 0.001), snappedf(d.x + hi.x, 0.001), snappedf(d.z + lo.z, 0.001), snappedf(d.z + hi.z, 0.001), -999, snappedf(g + hi.y, 0.001)])
	return out

func build(d: Dictionary) -> Node3D:
	var k := String(d.k)
	match k:
		"campfire":
			var cf := FireFX.make(float(d.get("s", 1.0)))
			fires.append([cf, float(d.get("s", 1.0))])
			return cf
		"seat":
			return Furniture.make(String(d.id), true)
		"kit":
			var kn := Furniture.make(String(d.id), false, 0)
			var ab := Furniture.aabb(String(d.id))
			var sc := float(d.get("len", 2.0)) / maxf(0.1, maxf(ab.size.x, ab.size.z))
			for c in kn.get_children():
				(c as Node3D).scale = Vector3.ONE * sc
				for mi in (c as Node).find_children("*", "MeshInstance3D", true, false):
					(mi as MeshInstance3D).visibility_range_end = 160.0
			kn.rotation.y = float(d.get("yaw", 0.0))
			var kb := StaticBody3D.new()
			kb.collision_layer = 1
			var kcs := CollisionShape3D.new()
			var kbs := BoxShape3D.new()
			kbs.size = (ab.size * sc).max(Vector3(0.1, 0.1, 0.1))
			kcs.shape = kbs
			kcs.position = ab.get_center() * sc
			kb.add_child(kcs)
			kn.add_child(kb)
			if d.get("burnt", false):
				for mi in kn.find_children("*", "MeshInstance3D", true, false):
					(mi as MeshInstance3D).material_override = _mat("burnt")
			var holder := Node3D.new()
			holder.add_child(kn)
			return holder
		"chest":
			return Furniture.make("treasure_chest", false, 1)
		"bench":
			var fg := Forge.new()
			var bn: Node3D = fg.build("bench", -1)
			fg.free()
			return bn
	var kit := Kit.new()
	_shape(kit, d)
	var root := Node3D.new()
	root.name = "FR_" + k
	kit.commit(root)
	return root

# things added once the building stands in the world: its furniture, lights, signs, people's seats
func _after(n: Node3D, d: Dictionary) -> void:
	var k := String(d.k)
	if k == "campfire":
		n.global_position.y = Game.height(n.global_position.x, n.global_position.z)
		if main and main.town:
			main.town.add_fire(n.global_position, float(d.get("s", 1.0)))
		return
	if k == "seat" and main and main.town:
		main.town.add_piece("fr_" + str(roundi(float(d.x))), String(d.id), n)
		return
	if k == "sign":
		# a road sign reads the same from both sides; each side's lettering only from its own side (it used to show
		# mirrored through and past the board), each line sized to fit the board, the first line largest (build 19)
		var lines := String(d.get("text", "")).split("\n")
		var sizes: Array = []
		var total := 0.0
		for i in lines.size():
			var ps := minf(0.0075 if i == 0 else 0.0058, 2.15 / (maxf(1.0, float(lines[i].length())) * 0.62 * 56.0))
			sizes.append(ps)
			total += ps * 56.0 * 1.18
		var fit := minf(1.0, 0.98 / maxf(0.01, total))
		for side in [0.0, PI]:
			var y := 1.75 + total * fit * 0.5
			for i in lines.size():
				var ps: float = sizes[i] * fit
				y -= ps * 56.0 * 1.18 * 0.5
				var lb := Label3D.new()
				lb.text = lines[i]
				lb.font_size = 56
				lb.pixel_size = ps
				lb.double_sided = false
				lb.modulate = Color(0.12, 0.09, 0.07)
				lb.outline_size = 0
				lb.position = Basis(Vector3.UP, side) * Vector3(0, y, 0.075)
				lb.rotation.y = side
				lb.visibility_range_end = 45.0
				n.add_child(lb)
				y -= ps * 56.0 * 1.18 * 0.5
		return
	if d.has("sign"):
		_sign_board(n, d)
	if d.has("role"):
		_furnish(n, d)

func _sign_board(n: Node3D, d: Dictionary) -> void:
	var w := float(d.get("w", 6))
	var dd := float(d.get("d", 5))
	var h := float(d.get("h", 3.4 if d.k == "hall" else 2.7))
	var lb := Label3D.new()
	lb.text = String(d.sign)
	lb.font_size = 72
	lb.pixel_size = 0.0075 if d.k == "hall" else 0.006
	lb.modulate = Color(0.93, 0.86, 0.7)
	lb.outline_modulate = Color(0.1, 0.06, 0.04)
	lb.outline_size = 10
	lb.position = Vector3(0, h + (0.75 if d.k == "hall" else 0.42), dd * 0.5 + 0.16)
	lb.double_sided = false
	lb.pixel_size = minf(lb.pixel_size, (w * 0.92) / maxf(1.0, float(String(d.sign).length()) * 0.6 * 72.0))
	lb.visibility_range_end = 60.0
	n.add_child(lb)

# ---------------------------------------------------------------- the rooms inside
func _put(n: Node3D, id: String, at: Vector3, yaw: float, seat := false) -> Node3D:
	var f := Furniture.make(id, true)
	n.add_child(f)
	f.position = at
	f.rotation.y = yaw
	if seat and main and main.town:
		main.town.add_piece("fr_" + n.name, id, f)
	return f

func _furnish(n: Node3D, d: Dictionary) -> void:
	var w := float(d.get("w", 6))
	var dd := float(d.get("d", 5))
	var hw := w * 0.5 - 0.35
	var hd := dd * 0.5 - 0.35
	var fl := 0.16
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.78, 0.5)
	l.light_energy = 0.9
	l.omni_range = maxf(w, dd) * 0.9
	l.position = Vector3(0, float(d.get("h", 2.7)) - 0.5, 0)
	l.distance_fade_enabled = true
	l.distance_fade_begin = 40.0
	l.distance_fade_length = 10.0
	n.add_child(l)
	match String(d.role):
		"home":
			_cot(n, Vector3(-hw + 0.45, fl, -hd + 1.0), 0.0)
			_put(n, "WoodenTable_02", Vector3(hw - 0.6, fl, -hd + 0.5), 0.0)
			_put(n, "SchoolChair_01", Vector3(hw - 0.6, fl, -hd + 1.3), PI, true)
			_put(n, "Shelf_01", Vector3(hw - 0.2, fl, 0.3), -PI * 0.5)
			_put(n, "k:q_Barrel", Vector3(-hw + 0.4, fl, hd - 0.5), 0.0)
			_put(n, "Lantern_01", Vector3(hw - 0.6, fl + 0.78, -hd + 0.4), 0.0)
		"shop":
			_counter(n, Vector3(0, fl, -0.2), w - 2.4)
			_put(n, "Shelf_01", Vector3(-hw + 1.2, fl, -hd + 0.2), 0.0)
			_put(n, "Shelf_01", Vector3(hw - 1.2, fl, -hd + 0.2), 0.0)
			_put(n, "k:s_box-large", Vector3(-hw + 0.5, fl, hd - 0.6), 0.3)
			_put(n, "k:q_Barrel", Vector3(hw - 0.5, fl, hd - 0.5), 0.0)
			_put(n, "metal_jug", Vector3(-0.6, fl + 1.0, -0.2), 0.0)
			_put(n, "hanging_industrial_lamp", Vector3(0, float(d.get("h", 2.7)) + 0.1, 0.4), 0.0)
		"bar":
			_counter(n, Vector3(-1.5, fl, -hd + 1.6), 5.5)
			for i in 4:
				_put(n, "modern_bar_stool", Vector3(-3.6 + i * 1.3, fl, -hd + 2.5), PI, true)
			_put(n, "Shelf_01", Vector3(-3.0, fl, -hd + 0.2), 0.0)
			_put(n, "Shelf_01", Vector3(-0.6, fl, -hd + 0.2), 0.0)
			_put(n, "jug_01", Vector3(-2.2, fl + 1.02, -hd + 1.6), 0.0)
			_put(n, "WoodenTable_01", Vector3(3.2, fl, 0.6), PI * 0.5)
			_put(n, "SchoolChair_01", Vector3(2.2, fl, 0.6), PI * 0.5, true)
			_put(n, "SchoolChair_01", Vector3(4.2, fl, 0.6), -PI * 0.5, true)
			_put(n, "WoodenTable_02", Vector3(-3.4, fl, hd - 1.2), 0.0)
			_put(n, "GreenChair_01", Vector3(-3.4, fl, hd - 0.5), PI, true)
			_put(n, "dartboard", Vector3(hw + 0.2, 1.7, -1.5), -PI * 0.5)
			_put(n, "lantern_chandelier_01", Vector3(0.5, float(d.get("h", 3.4)) - 0.1, 0.5), 0.0)
			_put(n, "k:q_Barrel", Vector3(1.6, fl, -hd + 0.6), 0.0)
		"clinic":
			_cot(n, Vector3(-hw + 0.45, fl, -hd + 1.0), 0.0)
			_cot(n, Vector3(-hw + 0.45, fl, hd - 1.2), 0.0)
			_put(n, "WoodenTable_03", Vector3(hw - 0.7, fl, -hd + 0.6), 0.0)
			_put(n, "brass_pot_01", Vector3(hw - 0.9, fl + 0.85, -hd + 0.6), 0.0)
			_put(n, "modern_sideboard", Vector3(hw - 0.3, fl, 0.6), -PI * 0.5)
			_put(n, "SchoolChair_01", Vector3(0.4, fl, -0.4), 0.0, true)
			_put(n, "vintage_oil_lamp", Vector3(hw - 0.5, fl + 0.85, -hd + 0.8), 0.0)
		"office":
			_put(n, "modern_desk", Vector3(0, fl, -hd + 0.7), 0.0)
			_put(n, "ArmChair_01", Vector3(0, fl, -hd + 0.2), 0.0, true)
			_put(n, "modern_bookshelf", Vector3(-hw + 0.2, fl, -0.5), PI * 0.5)
			_put(n, "ClassicNightstand_01", Vector3(hw - 0.3, fl, -hd + 0.4), 0.0)
			_put(n, "fancy_picture_frame_02", Vector3(0, 1.75, -hd - 0.15), 0.0)
			_put(n, "wall_clock", Vector3(hw - 1.4, 2.0, -hd - 0.15), 0.0)
			_put(n, "SchoolChair_01", Vector3(-0.8, fl, 0.6), PI, true)
		"workshop":
			_put(n, "WoodenTable_03", Vector3(hw - 0.7, fl, -hd + 0.6), 0.0)
			_put(n, "Drill_01", Vector3(hw - 0.9, fl + 0.85, -hd + 0.6), 0.0)
			_put(n, "k:q_Wheels_Stack", Vector3(hw - 0.7, fl, hd - 0.9), 0.0)
			_put(n, "k:q_Pipes", Vector3(hw - 0.6, fl, 0.6), 0.3)
			_put(n, "caged_hanging_light", Vector3(0, float(d.get("h", 2.7)) - 0.05, 0), 0.0)
		"smoke":
			for i in 3:
				_put(n, "k:s_barrel-open", Vector3(-hw + 0.6 + i * 1.1, fl, -hd + 0.5), 0.0)
			_put(n, "WoodenTable_03", Vector3(hw - 0.8, fl, 0.0), PI * 0.5)
			var kk := Kit.new()
			for i in 5:
				kk.box("hide", Vector3(-hw + 0.8 + i * 1.2, 2.0, -0.5), Vector3(0.25, 0.6, 0.05), 0)
			kk.box("log", Vector3(0, 2.35, -0.5), Vector3(w - 0.6, 0.06, 0.06), 0)
			var kn := Node3D.new()
			n.add_child(kn)
			kk.commit(kn)
		"boats":
			_put(n, "WoodenTable_03", Vector3(-hw + 0.8, fl, -hd + 0.6), 0.0)
			_put(n, "k:q_Pipes", Vector3(hw - 0.7, fl, -hd + 0.7), 0.0)
			var kb := Kit.new()
			_boat(kb, {"yaw": 0.0}, Vector3(0.6, fl + 0.45, 0.6))
			var bn := Node3D.new()
			bn.rotation.y = PI * 0.5
			n.add_child(bn)
			kb.commit(bn)
		"snack":
			_counter(n, Vector3(0, fl, 0.6), w - 2.0)
			_put(n, "Shelf_01", Vector3(0, fl, -hd + 0.2), 0.0)
			_put(n, "k:q_TrashBag_2", Vector3(hw - 0.6, fl, -hd + 0.6), 0.0)
			_put(n, "Television_01", Vector3(-1.2, fl + 1.0, 0.6), 0.0)

func _counter(n: Node3D, at: Vector3, length: float) -> void:
	var kit := Kit.new()
	kit.box("plank_dk", at + Vector3(0, 0.5, 0), Vector3(length, 1.0, 0.6), 2)
	kit.box("plank", at + Vector3(0, 1.02, 0), Vector3(length + 0.1, 0.06, 0.7), 0)
	var c := Node3D.new()
	c.name = "Counter"
	n.add_child(c)
	kit.commit(c)

func _cot(n: Node3D, at: Vector3, yaw: float) -> void:
	var kit := Kit.new()
	var b := Basis(Vector3.UP, yaw)
	kit.box("metal", at + b * Vector3(0, 0.3, 0), Vector3(0.8, 0.06, 1.9), 2)
	for c in [Vector2(-0.36, -0.9), Vector2(0.36, -0.9), Vector2(-0.36, 0.9), Vector2(0.36, 0.9)]:
		kit.box("metal", at + b * Vector3(c.x, 0.15, c.y), Vector3(0.05, 0.3, 0.05), 0)
	kit.box("mattress", at + b * Vector3(0, 0.4, 0), Vector3(0.72, 0.14, 1.8), 0)
	kit.box("mattress", at + b * Vector3(0, 0.5, -0.72), Vector3(0.5, 0.1, 0.3), 0)
	var c2 := Node3D.new()
	c2.name = "Cot"
	n.add_child(c2)
	kit.commit(c2)

# ---------------------------------------------------------------- shapes (local: origin on the ground at the middle, front to +Z)
static func _shape(kit: Kit, d: Dictionary) -> void:
	d["_sink"] = _sink(d)
	match String(d.k):
		"shack": _shack(kit, d, 2.7)
		"hall": _shack(kit, d, 3.4)
		"cabin": _cabin(kit, d)
		"stall": _stall(kit, d)
		"water_tower": _water_tower(kit, d)
		"tower": _watchtower(kit, d)
		"fence": _fence(kit, d)
		"sign": _signpost(kit)
		"palisade": _palisade(kit, d)
		"tipi": _tipi(kit, d)
		"longhouse": _longhouse(kit, d)
		"totem": _totem(kit, d)
		"rack": _rack(kit)
		"snag": _snag(kit)
		"log_seat": _log_seat(kit, d)
		"lookout": _lookout(kit)
		"outhouse": _outhouse(kit)
		"hospital": _hospital(kit, d)
		"ruin": _ruin(kit, d)
		"screen": _screen(kit)
		"pier": _pier(kit, d)
		"boat": _boat(kit, d)
		"windmill": _windmill(kit)
		"highrise": _highrise(kit, d)
		"rubble": _rubble(kit, d)
		"cage": _cage(kit)
		"garage": _garage(kit, d)
		"tent": _tent(kit)
		"shrine": _shrine(kit)
		"banner": _banner(kit)
		"blockhouse": _blockhouse(kit, d)
		"silo": _silo(kit)
		"shards": _shards(kit, d)
		"reactor_hall": _reactor_hall(kit)
		"ufo": _ufo(kit, d)
		"rig_cart":
			kit.box("metal", Vector3(0, 0.45, 0), Vector3(1.4, 0.08, 0.8), 1)
			for w in [Vector3(-0.55, 0.2, 0.42), Vector3(0.55, 0.2, 0.42), Vector3(-0.55, 0.2, -0.42), Vector3(0.55, 0.2, -0.42)]:
				kit.cyl("dark", w, 0.18, 0.18, 0.06, 10, 0, Basis(Vector3.RIGHT, PI * 0.5))
			kit.box("tin_teal", Vector3(0, 0.82, 0), Vector3(1.0, 0.66, 0.6), 0)
			for i in 3:
				kit.cyl("paint", Vector3(-0.3 + i * 0.3, 0.95, 0.31), 0.1, 0.1, 0.02, 12, 0, Basis(Vector3.RIGHT, PI * 0.5))
			kit.box("ochre", Vector3(0, 1.17, 0), Vector3(0.5, 0.05, 0.12), 0)
		"furnace":
			kit.cyl("concrete_dk", Vector3.ZERO, 1.6, 1.3, 2.6, 14, 1)
			kit.cyl("concrete", Vector3(0, 2.6, 0), 0.5, 0.45, 3.4, 10, 0)
			kit.box("dark", Vector3(0, 0.7, 1.32), Vector3(0.9, 0.8, 0.2), 0)
			kit.box("metal", Vector3(1.9, 0.5, 0), Vector3(0.9, 1.0, 0.9), 1)
			kit.box("burnt", Vector3(0, 0.03, 2.0), Vector3(2.6, 0.04, 1.6), 0)
		"strongbox":
			kit.box("metal", Vector3(0, 0.35, 0), Vector3(0.8, 0.7, 0.6), 1)
			kit.cyl("paint", Vector3(0, 0.42, 0.31), 0.1, 0.1, 0.03, 12, 0, Basis(Vector3.RIGHT, PI * 0.5))
			kit.box("dark", Vector3(0.22, 0.42, 0.31), Vector3(0.05, 0.16, 0.03), 0)
		"crater": _crater(kit, d)
		"sandbags": _sandbags(kit, d)
		"washline": _washline(kit, d)
		"crates": _crates(kit, d)
		"watertank": _watertank(kit, d)
		"table": _table(kit, d)
		"scrap": _scrap(kit, d)
		"lamp": _lamp(kit, d)
		"tripod": _tripod(kit, d)
		"pump": _pump(kit, d)
		"canopy": _canopy(kit, d)
		"tarp": _tarp(kit, d)
		"generator": _generator(kit, d)
		"antenna": _antenna(kit, d)
		"board": _board(kit, d)
		"lights": _lights(kit, d)
		"garden": _garden(kit, d)
		"reactor_dress": _reactor_dress(kit)
		"post":
			kit.cyl("metal", Vector3.ZERO, 0.05, 0.05, 1.2, 6, 0)
			kit.box("metal", Vector3(0, 1.25, 0), Vector3(0.3, 0.22, 0.14), 0)

# a wall from a to b (along x or z), with openings [offset from the middle, width, bottom, top]
static func _wall(kit: Kit, m: String, a: Vector3, b: Vector3, h: float, openings: Array, t := 0.12, y0 := 0.0) -> void:
	var len := a.distance_to(b)
	var u := (b - a) / len
	var mid := (a + b) * 0.5
	var cuts: Array = []
	for o in openings:
		cuts.append([float(o[0]) - float(o[1]) * 0.5, float(o[0]) + float(o[1]) * 0.5, float(o[2]), float(o[3])])
	cuts.sort_custom(func(p, q): return p[0] < q[0])
	var s := -len * 0.5
	var size_of := func(l: float, hh: float) -> Vector3:
		return Vector3(absf(u.x) * l + absf(u.z) * t, hh, absf(u.z) * l + absf(u.x) * t)
	for c in cuts:
		if c[0] > s:
			var l: float = c[0] - s
			kit.box(m, mid + u * (s + l * 0.5) + Vector3(0, y0 + h * 0.5, 0), size_of.call(l, h))
		var cl: float = c[1] - c[0]
		var cm: float = (c[0] + c[1]) * 0.5
		if c[2] > 0.0:
			kit.box(m, mid + u * cm + Vector3(0, y0 + c[2] * 0.5, 0), size_of.call(cl, c[2]))
		if c[3] < h:
			kit.box(m, mid + u * cm + Vector3(0, y0 + (c[3] + h) * 0.5, 0), size_of.call(cl, h - c[3]))
		s = c[1]
	if s < len * 0.5:
		var l2 := len * 0.5 - s
		kit.box(m, mid + u * (s + l2 * 0.5) + Vector3(0, y0 + h * 0.5, 0), size_of.call(l2, h))

static func _shack(kit: Kit, d: Dictionary, h: float) -> void:
	var w := float(d.get("w", 6))
	var dd := float(d.get("d", 5))
	var m := String(d.get("m", "plank"))
	var roof := String(d.get("roof", "tin"))
	var hw := w * 0.5
	var hd := dd * 0.5
	var door := float(d.get("door", 0.0))
	# a concrete footing down into the ground and a board floor
	var ft := 0.8 + float(d.get("_sink", 0.0))
	kit.box("concrete_dk", Vector3(0, -ft * 0.5, 0), Vector3(w + 0.1, ft, dd + 0.1), 1)
	kit.box("plank_dk", Vector3(0, 0.08, 0), Vector3(w - 0.1, 0.16, dd - 0.1), 1)
	var win := [0.0, 1.0, 1.05, 1.75]
	_wall(kit, m, Vector3(-hw, 0, -hd), Vector3(hw, 0, -hd), h, [win] if w >= 7 else [])
	_wall(kit, m, Vector3(-hw, 0, -hd + 0.06), Vector3(-hw, 0, hd - 0.06), h, [win])
	_wall(kit, m, Vector3(hw, 0, -hd + 0.06), Vector3(hw, 0, hd - 0.06), h, [win])
	var front := [[door, 1.2, 0.0, 2.15]]
	if w >= 7:
		front.append([door + (2.2 if door <= 0.0 else -2.2), 1.1, 1.05, 1.75])
	_wall(kit, m, Vector3(-hw, 0, hd), Vector3(hw, 0, hd), h, front)
	# window frames, a couple boarded over
	for wx in [[Vector3(-hw, 1.4, 0), 0], [Vector3(hw, 1.4, 0), 0]]:
		var p: Vector3 = wx[0]
		kit.box("plank_dk", p + Vector3(0, -0.38, 0), Vector3(0.2, 0.06, 1.15), 0)
		kit.box("plank_dk", p + Vector3(0, 0.38, 0), Vector3(0.2, 0.06, 1.15), 0)
	if int(d.x + d.z) % 2 == 0:
		kit.box("plank_v", Vector3(-hw - 0.07, 1.4, 0), Vector3(0.04, 0.16, 1.2), 0, Basis(Vector3.RIGHT, 0.5))
		kit.box("plank_v", Vector3(-hw - 0.07, 1.4, 0), Vector3(0.04, 0.16, 1.2), 0, Basis(Vector3.RIGHT, -0.45))
	# the roof: one slope, high at the front, eaves overhanging; a fascia board under its front edge
	var drop := 0.55
	var ang := atan2(drop, dd + 0.6)
	kit.box(roof, Vector3(0, h + 0.12 + drop * 0.5 - 0.1, 0), Vector3(w + 0.7, 0.08, sqrt(pow(dd + 0.9, 2) + drop * drop)), 0, Basis(Vector3.RIGHT, ang))
	kit.box("plank_dk", Vector3(0, h + 0.05, 0), Vector3(w, 0.1, dd), 0)
	# the roof is higher at the back: close the gap over the back wall and the triangles over the sides
	kit.box(m, Vector3(0, h + drop * 0.5 + 0.05, -hd), Vector3(w, drop + 0.1, 0.12), 0)
	for sx in [-hw, hw]:
		kit.tri3(m, Vector3(sx, h, -hd), Vector3(sx, h, hd), Vector3(sx, h + drop + 0.1, -hd))
	# the door, standing open
	var dl := Basis(Vector3.UP, -1.9)
	kit.box("plank_v", Vector3(door - 0.6, 0, hd) + dl * Vector3(0.52, 1.05, 0.03), Vector3(1.04, 2.08, 0.05), 0, dl)
	if d.k == "hall":
		# a false front: the board facade that makes a saloon a saloon, and a porch roof on posts
		kit.box(m, Vector3(0, h + 0.75, hd + 0.02), Vector3(w + 0.2, 1.5, 0.14), 0)
		kit.box("plank_dk", Vector3(0, h + 1.55, hd + 0.04), Vector3(w + 0.4, 0.12, 0.3), 0)
		kit.box("plank_dk", Vector3(0, 0.08, hd + 1.1), Vector3(w, 0.16, 2.2), 1)
		_door_ramp(kit, d, door, hd + 2.2, 2.0)
		for px in [-hw + 0.2, -hw * 0.33, hw * 0.33, hw - 0.2]:
			kit.box("log", Vector3(px, 1.35, hd + 2.05), Vector3(0.16, 2.7, 0.16), 0)
		kit.box(roof, Vector3(0, 2.72, hd + 1.15), Vector3(w + 0.3, 0.07, 2.5), 0, Basis(Vector3.RIGHT, 0.12))
	else:
		# a ramp of boards up to the door (build 20: the old decorative step had no collision, and the floor's edge
		# stopped you in the doorway)
		_door_ramp(kit, d, door, hd, 1.4)

# boards sloping from the ground up to a floor's edge (local z = edge, outward +z), gentle enough to walk up
static func _door_ramp(kit: Kit, d: Dictionary, x: float, edge: float, width: float) -> void:
	var g := _lifty(d, Vector3(x, 0, edge + 0.6))
	var rise := 0.16 - minf(g, 0.0)
	var l := maxf(0.6, rise / 0.42)
	g = _lifty(d, Vector3(x, 0, edge + l))
	rise = 0.16 - minf(g, 0.0)
	l = maxf(0.6, rise / 0.42)
	var ang := atan2(rise, l)
	var len := sqrt(l * l + rise * rise)
	var c := Vector3(x, 0.16 - rise * 0.5 - 0.05, edge + l * 0.5)
	kit.box("plank_dk", c, Vector3(width, 0.1, len), 2, Basis(Vector3.RIGHT, ang))
	# a sill so the ramp meets the floor flush
	kit.box("plank_dk", Vector3(x, 0.13, edge - 0.05), Vector3(width, 0.06, 0.14), 0)

static func _cabin(kit: Kit, d: Dictionary) -> void:
	var w := float(d.get("w", 6))
	var dd := float(d.get("d", 5))
	var hw := w * 0.5
	var hd := dd * 0.5
	var h := 2.5
	var ft := 0.7 + float(d.get("_sink", 0.0))
	kit.box("concrete_dk", Vector3(0, -ft * 0.5, 0), Vector3(w + 0.2, ft, dd + 0.2), 1)
	kit.box("plank_dk", Vector3(0, 0.08, 0), Vector3(w - 0.1, 0.16, dd - 0.1), 1)
	_wall(kit, "log", Vector3(-hw, 0, -hd), Vector3(hw, 0, -hd), h, [[1.2, 0.9, 1.0, 1.7]], 0.26)
	_wall(kit, "log", Vector3(-hw, 0, -hd + 0.13), Vector3(-hw, 0, hd - 0.13), h, [], 0.26)
	_wall(kit, "log", Vector3(hw, 0, -hd + 0.13), Vector3(hw, 0, hd - 0.13), h, [[0.0, 0.9, 1.0, 1.7]], 0.26)
	_wall(kit, "log", Vector3(-hw, 0, hd), Vector3(hw, 0, hd), h, [[-0.8, 1.1, 0.0, 2.05], [1.4, 0.9, 1.0, 1.7]], 0.26)
	# gable ends and a tin roof in two slopes
	var rise := 1.4
	kit.prism("log", Vector3(0, h, -hd), w, rise, 0.26)
	kit.prism("log", Vector3(0, h, hd), w, rise, 0.26)
	var ang := atan2(rise, hw)
	var sl := sqrt(hw * hw + rise * rise) + 0.5
	kit.box("tin", Vector3(-hw * 0.5 - 0.12, h + rise * 0.5 + 0.12, 0), Vector3(sl, 0.07, dd + 0.8), 0, Basis(Vector3.BACK, ang))
	kit.box("tin", Vector3(hw * 0.5 + 0.12, h + rise * 0.5 + 0.12, 0), Vector3(sl, 0.07, dd + 0.8), 0, Basis(Vector3.BACK, -ang))
	kit.box("plank_dk", Vector3(0, h + 0.05, 0), Vector3(w - 0.3, 0.1, dd - 0.3), 0)
	# a stovepipe, a porch
	kit.cyl("metal", Vector3(hw - 1.0, h + 0.6, -0.8), 0.12, 0.12, 1.6, 8, 0)
	kit.box("plank_dk", Vector3(0, 0.08, hd + 0.9), Vector3(w, 0.16, 1.8), 1)
	_door_ramp(kit, d, -0.8, hd + 1.8, 1.6)
	var dl := Basis(Vector3.UP, -1.7)
	kit.box("plank_v", Vector3(-1.35, 0, hd) + dl * Vector3(0.5, 1.0, 0.03), Vector3(1.0, 2.0, 0.05), 0, dl)

static func _outhouse(kit: Kit) -> void:
	kit.box("plank_dk", Vector3(0, 0.06, 0), Vector3(1.3, 0.12, 1.3), 1)
	_wall(kit, "plank_v", Vector3(-0.65, 0, -0.65), Vector3(0.65, 0, -0.65), 2.2, [], 0.06)
	_wall(kit, "plank_v", Vector3(-0.65, 0, -0.62), Vector3(-0.65, 0, 0.62), 2.2, [], 0.06)
	_wall(kit, "plank_v", Vector3(0.65, 0, -0.62), Vector3(0.65, 0, 0.62), 2.2, [], 0.06)
	kit.box("plank_v", Vector3(0, 1.05, 0.66), Vector3(1.2, 2.0, 0.05), 0)
	kit.box("tin", Vector3(0, 2.3, 0), Vector3(1.6, 0.06, 1.7), 0, Basis(Vector3.RIGHT, 0.15))

static func _stall(kit: Kit, d: Dictionary) -> void:
	kit.box("plank", Vector3(0, 0.45, 0.3), Vector3(2.6, 0.9, 0.7), 1)
	kit.box("plank_dk", Vector3(0, 0.93, 0.3), Vector3(2.75, 0.06, 0.85), 0)
	for p in [Vector2(-1.3, -0.5), Vector2(1.3, -0.5), Vector2(-1.3, 0.75), Vector2(1.3, 0.75)]:
		kit.box("log", Vector3(p.x, 1.2 if p.y < 0 else 1.05, p.y), Vector3(0.1, 2.4 if p.y < 0 else 2.1, 0.1), 0)
	kit.box("canvas_red" if String(d.get("goods", "")) == "food" else "canvas", Vector3(0, 2.25, 0.15), Vector3(3.0, 0.05, 1.9), 0, Basis(Vector3.RIGHT, -0.16))
	for i in 5:
		kit.box("canvas" if i % 2 == 0 else "plank", Vector3(-1.0 + i * 0.5, 1.03, 0.3 + sin(i * 2.0) * 0.12), Vector3(0.3, 0.16, 0.25), 0)

static func _water_tower(kit: Kit, d: Dictionary) -> void:
	# each leg reaches down to the ground under it (build 19: on a slope the low legs hung in the air)
	for p in [Vector2(-1.7, -1.7), Vector2(1.7, -1.7), Vector2(-1.7, 1.7), Vector2(1.7, 1.7)]:
		var lo := minf(0.0, _lifty(d, Vector3(p.x, 0, p.y))) - 0.3
		kit.box("log", Vector3(p.x, (7.0 + lo) * 0.5, p.y), Vector3(0.25, 7.0 - lo, 0.25), 1)
	kit.box("log", Vector3(0, 3.0, -1.7), Vector3(3.4, 0.12, 0.12), 0, Basis(Vector3.BACK, 0.9))
	kit.box("log", Vector3(0, 3.0, 1.7), Vector3(3.4, 0.12, 0.12), 0, Basis(Vector3.BACK, -0.9))
	kit.box("plank_dk", Vector3(0, 7.05, 0), Vector3(4.2, 0.14, 4.2), 2)
	kit.cyl("tin", Vector3(0, 7.1, 0), 2.1, 2.1, 3.4, 16, 2)
	kit.cone("tin_red", Vector3(0, 10.5, 0), 2.3, 0.6, 12)
	kit.box("metal", Vector3(2.15, 3.6, 0), Vector3(0.06, 7.2, 0.45), 0)

static func _watchtower(kit: Kit, d: Dictionary) -> void:
	for p in [Vector2(-1.3, -1.3), Vector2(1.3, -1.3), Vector2(-1.3, 1.3), Vector2(1.3, 1.3)]:
		var lo := minf(0.0, _lifty(d, Vector3(p.x, 0, p.y))) - 0.3
		kit.box("log", Vector3(p.x, (5.8 + lo) * 0.5, p.y), Vector3(0.2, 5.8 - lo, 0.2), 1)
	kit.box("plank_dk", Vector3(0, 4.6, 0), Vector3(3.2, 0.14, 3.2), 2)
	for s in [[Vector3(0, 5.15, -1.55), Vector3(3.2, 1.0, 0.08)], [Vector3(0, 5.15, 1.55), Vector3(3.2, 1.0, 0.08)],
			[Vector3(-1.55, 5.15, 0), Vector3(0.08, 1.0, 3.2)], [Vector3(1.55, 5.15, 0), Vector3(0.08, 1.0, 3.2)]]:
		kit.box("tin", s[0], s[1], 2)
	kit.box("tin_red", Vector3(0, 6.55, 0), Vector3(3.6, 0.07, 3.6), 0, Basis(Vector3.RIGHT, 0.12))
	kit.box("log", Vector3(0, 2.3, 1.45), Vector3(0.6, 4.6, 0.06), 0, Basis(Vector3.RIGHT, -0.12))

static func _fence(kit: Kit, d: Dictionary) -> void:
	# a run of scrap sheets nailed to posts, along local x
	var l := float(d.get("len", 10.0))
	var n := int(l / 1.8)
	# each sheet and post follows the ground under it, down into it on the low side (build 20: on a slope the run
	# hung in the air at one end)
	for i in n:
		var x := -l * 0.5 + (i + 0.5) * l / n
		var g := minf(_lifty(d, Vector3(x - l / n * 0.5, 0, 0)), _lifty(d, Vector3(x + l / n * 0.5, 0, 0)))
		var gt := _lifty(d, Vector3(x, 0, 0))
		var hh := 2.2 + sin(i * 1.9 + d.x) * 0.25
		var bot := g - 0.15
		kit.box(["tin", "tin_red", "plank_v", "tin_teal"][(i + int(d.z)) % 4], Vector3(x, (bot + gt + hh) * 0.5, 0), Vector3(l / n + 0.05, gt + hh - bot, 0.06), 1, Basis(Vector3.FORWARD, sin(i * 3.1) * 0.03))
	for i in n + 1:
		var px := -l * 0.5 + i * l / n
		var g := _lifty(d, Vector3(px, 0, -0.1))
		kit.box("log", Vector3(px, g + 1.25 - 0.15, -0.1), Vector3(0.12, 2.8, 0.12), 0)

static func _signpost(kit: Kit) -> void:
	kit.box("log", Vector3(-0.9, 1.2, 0), Vector3(0.12, 2.4, 0.12), 0)
	kit.box("log", Vector3(0.9, 1.2, 0), Vector3(0.12, 2.4, 0.12), 0)
	kit.box("plank", Vector3(0, 1.75, 0.04), Vector3(2.4, 1.1, 0.06), 0)

static func _palisade(kit: Kit, d: Dictionary) -> void:
	var rad := float(d.get("rad", 25.0))
	var gate := float(d.get("gate", PI))
	var gap := float(d.get("gap", 0.15))
	var n := int(TAU * rad / 0.42)
	var seg_start := -1
	for i in n:
		var a := i * TAU / n
		var da := wrapf(a - gate, -PI, PI)
		if absf(da) < gap:
			continue
		var p := Vector3(cos(a) * rad, 0, sin(a) * rad)
		var hh := 3.3 + sin(i * 2.7) * 0.25 + sin(i * 0.31) * 0.2
		kit.cyl("log", p + Vector3(0, -0.4, 0), 0.21, 0.19, hh + 0.4, 6, 0)
		kit.cone("log", p + Vector3(0, hh, 0), 0.19, 0.5, 6)
	# its solid: short chords round the ring
	var chords := int(TAU * rad / 2.5)
	for i in chords:
		var a0 := i * TAU / chords
		var a1 := (i + 1) * TAU / chords
		if absf(wrapf((a0 + a1) * 0.5 - gate, -PI, PI)) < gap + 0.02:
			continue
		var p0 := Vector3(cos(a0) * rad, 0, sin(a0) * rad)
		var p1 := Vector3(cos(a1) * rad, 0, sin(a1) * rad)
		var lo := p0.min(p1) - Vector3(0.2, 0, 0.2)
		var hi := p0.max(p1) + Vector3(0.2, 3.3, 0.2)
		kit.solid_box(AABB(lo, hi - lo))
	# the gate posts, taller, with skulls
	for s in [-1.0, 1.0]:
		var a: float = gate + s * (gap + 0.01)
		var p := Vector3(cos(a) * rad, 0, sin(a) * rad)
		kit.cyl("log", p, 0.3, 0.26, 4.6, 7, 0)
		kit.box("bone", p + Vector3(0, 4.75, 0), Vector3(0.32, 0.3, 0.36), 0)

static func _tipi(kit: Kit, d: Dictionary) -> void:
	var r := float(d.get("rad", 2.4))
	var h := r * 1.7
	var face := float(d.get("face", 0.0))
	kit.cone("hide", Vector3.ZERO, r, h * 0.92, 10, face)
	for i in 6:
		var a := i * TAU / 6.0 + 0.2
		var foot := Vector3(cos(a) * r * 0.97, 0, sin(a) * r * 0.97)
		var top := Vector3(cos(a) * -0.25, h * 1.12, sin(a) * -0.25)
		kit.pole("log", foot, top, 0.05)
	# the door flap, open: a dark triangle on the side it faces
	var f := Vector3(cos(face), 0, sin(face))
	var sd := Vector3(-f.z, 0, f.x)
	kit.tri3("dark", f * (r * 1.01) - sd * 0.55, f * (r * 1.01) + sd * 0.55, f * (r * 0.55) + Vector3(0, h * 0.42, 0))
	kit.solid_box(AABB(Vector3(-r * 0.75, 0, -r * 0.75), Vector3(r * 1.5, h * 0.8, r * 1.5)))
	# paint: a ring of ochre handprints
	kit.cone("ochre", Vector3(0, h * 0.55, 0), r * 0.47, h * 0.06, 10, face, true)

static func _longhouse(kit: Kit, d: Dictionary) -> void:
	var w := float(d.get("w", 12))
	var dd := float(d.get("d", 7))
	var hw := w * 0.5
	var hd := dd * 0.5
	var h := 2.4
	kit.box("plank_dk", Vector3(0, 0.08, 0), Vector3(w - 0.2, 0.16, dd - 0.2), 1)
	_wall(kit, "log", Vector3(-hw, 0, -hd), Vector3(hw, 0, -hd), h, [], 0.3)
	_wall(kit, "log", Vector3(-hw, 0, -hd + 0.15), Vector3(-hw, 0, hd - 0.15), h, [], 0.3)
	_wall(kit, "log", Vector3(hw, 0, -hd + 0.15), Vector3(hw, 0, hd - 0.15), h, [], 0.3)
	_wall(kit, "log", Vector3(-hw, 0, hd), Vector3(hw, 0, hd), h, [[0.0, 1.6, 0.0, 2.2]], 0.3)
	var rise := 2.2
	kit.prism("log", Vector3(0, h, -hd), w, rise, 0.3, true)
	kit.prism("log", Vector3(0, h, hd), w, rise, 0.3, true)
	var ang := atan2(rise, hd)
	var sl := sqrt(hd * hd + rise * rise) + 0.6
	kit.box("hide", Vector3(0, h + rise * 0.5 + 0.1, -hd * 0.5 - 0.15), Vector3(w + 1.0, 0.1, sl), 0, Basis(Vector3.RIGHT, ang))
	kit.box("hide", Vector3(0, h + rise * 0.5 + 0.1, hd * 0.5 + 0.15), Vector3(w + 1.0, 0.1, sl), 0, Basis(Vector3.RIGHT, -ang))
	kit.cyl("log", Vector3(-hw - 0.5, h + rise + 0.05, 0), 0.14, 0.14, w + 1.0, 6, 0, Basis(Vector3.BACK, -PI * 0.5))
	# horns over the door, a hide curtain pulled aside
	kit.box("bone", Vector3(0, h + 0.5, hd + 0.2), Vector3(0.5, 0.35, 0.3), 0)
	kit.box("bone", Vector3(-0.45, h + 0.7, hd + 0.2), Vector3(0.6, 0.08, 0.08), 0, Basis(Vector3.BACK, 0.6))
	kit.box("bone", Vector3(0.45, h + 0.7, hd + 0.2), Vector3(0.6, 0.08, 0.08), 0, Basis(Vector3.BACK, -0.6))
	kit.box("hide", Vector3(-0.65, 1.1, hd + 0.18), Vector3(0.5, 2.1, 0.04), 0)
	# inside: sleeping furs and a hearth stone
	for i in 4:
		kit.box("hide", Vector3(-hw + 1.6 + i * 2.6, 0.2, -hd + 1.0), Vector3(1.8, 0.08, 1.2), 0, Basis(Vector3.UP, sin(i) * 0.2))
	kit.box("concrete_dk", Vector3(0, 0.22, 0.2), Vector3(1.4, 0.14, 1.4), 0)

static func _totem(kit: Kit, d: Dictionary) -> void:
	var h := float(d.get("h", 4.5))
	kit.cyl("log", Vector3(0, -0.3, 0), 0.28, 0.24, h + 0.3, 8, 1)
	var cols := ["red", "ochre", "dark", "bone"]
	for i in int(h / 0.9):
		kit.cyl(cols[i % 4], Vector3(0, 0.5 + i * 0.9, 0), 0.3, 0.29, 0.22, 8, 0)
		kit.box("dark", Vector3(0, 0.85 + i * 0.9, 0.27), Vector3(0.24, 0.1, 0.06), 0)
	kit.box("bone", Vector3(0, h + 0.15, 0.05), Vector3(0.36, 0.32, 0.42), 0)
	kit.box("dark", Vector3(-0.09, h + 0.18, 0.27), Vector3(0.08, 0.08, 0.02), 0)
	kit.box("dark", Vector3(0.09, h + 0.18, 0.27), Vector3(0.08, 0.08, 0.02), 0)
	kit.box("bone", Vector3(-0.42, h + 0.4, 0), Vector3(0.55, 0.07, 0.07), 0, Basis(Vector3.BACK, 0.7))
	kit.box("bone", Vector3(0.42, h + 0.4, 0), Vector3(0.55, 0.07, 0.07), 0, Basis(Vector3.BACK, -0.7))

static func _rack(kit: Kit) -> void:
	for x in [-1.4, 1.4]:
		kit.box("log", Vector3(x, 1.0, 0), Vector3(0.12, 2.0, 0.12), 1)
	kit.cyl("log", Vector3(-1.6, 1.85, 0), 0.06, 0.06, 3.2, 5, 0, Basis(Vector3.BACK, -PI * 0.5))
	for i in 3:
		kit.box("hide", Vector3(-0.9 + i * 0.9, 1.25, 0), Vector3(0.75, 1.1 - (i % 2) * 0.2, 0.04), 0, Basis(Vector3.UP, sin(i * 2.0) * 0.15))

static func _snag(kit: Kit) -> void:
	kit.cyl("burnt", Vector3(0, -0.2, 0), 0.45, 0.12, 9.0, 8, 1)
	for i in 6:
		var a := i * 1.7
		var y := 3.0 + i * 0.85
		var dir := Vector3(cos(a), 0.55, sin(a)).normalized()
		kit.pole("burnt", Vector3(0, y, 0), Vector3(0, y, 0) + dir * (2.2 - i * 0.2), 0.08)
		# charms: bone and red cloth hanging from the branch ends
		var end := Vector3(0, y, 0) + dir * (1.9 - i * 0.2)
		kit.box("bone" if i % 2 == 0 else "red", end + Vector3(0, -0.4, 0), Vector3(0.12, 0.4, 0.04), 0)

static func _log_seat(kit: Kit, d: Dictionary) -> void:
	var yb := Basis(Vector3.UP, float(d.get("yaw", 0.0)))
	var lo := minf(_lifty(d, Vector3(-0.8, 0, 0)), _lifty(d, Vector3(0.8, 0, 0)))
	kit.cyl("log", yb * Vector3(-0.9, 0.2 + lo * 0.5, 0), 0.22, 0.2, 1.8, 10, 0, yb * Basis(Vector3.BACK, -PI * 0.5))
	# a bark split along the top where people sit, and a stub of branch
	kit.box("plank_dk", yb * Vector3(0, 0.41 + lo * 0.5, 0), Vector3(1.5, 0.03, 0.2), 0, yb)
	kit.cyl("log", yb * Vector3(0.5, 0.25 + lo * 0.5, 0.15), 0.05, 0.03, 0.3, 5, 0, yb * Basis(Vector3.RIGHT, 1.1))

static func _lookout(kit: Kit) -> void:
	var top := 12.0
	for p in [Vector2(-2.5, -2.5), Vector2(2.5, -2.5), Vector2(-2.5, 2.5), Vector2(2.5, 2.5)]:
		kit.box("metal", Vector3(p.x, top * 0.5, p.y), Vector3(0.22, top, 0.22), 1)
	for lv in 3:
		var y := 2.0 + lv * 3.6
		for s in [-2.5, 2.5]:
			kit.box("metal", Vector3(0, y + 1.8, s), Vector3(5.4, 0.08, 0.08), 0, Basis(Vector3.FORWARD, 0.6 * (1 if lv % 2 == 0 else -1)))
			kit.box("metal", Vector3(s, y + 1.8, 0), Vector3(0.08, 0.08, 5.4), 0, Basis(Vector3.RIGHT, 0.6 * (1 if lv % 2 == 0 else -1)))
	# eight flights of stairs, back and forth, with landings at each turn
	var flights := 8
	var rise := top / flights
	for i in flights:
		var y0 := i * rise
		var zs := 0.8 if i % 2 == 0 else -0.8
		var dirx := 1.0 if i % 2 == 0 else -1.0
		var run := 3.4
		var ang := atan2(rise, run)
		var b := Basis(Vector3.BACK, ang * dirx)
		var c := Vector3(0, y0 + rise * 0.5, zs)
		kit.box("plank_dk", c, Vector3(sqrt(run * run + rise * rise), 0.1, 1.4), 2, b)
		kit.box("metal", c + Vector3(0, 0.45, zs * 0.9), Vector3(sqrt(run * run + rise * rise), 0.05, 0.05), 0, b)
		if i < flights - 1:
			kit.box("plank_dk", Vector3(2.2 * dirx, y0 + rise - 0.05, 0), Vector3(1.0, 0.1, 3.2), 2)
	# the cab: a floor with a hatch where the last flight comes up, half walls, windows all round, a pyramid roof
	kit.box("plank_dk", Vector3(0, top - 0.05, 1.3), Vector3(5.2, 0.1, 2.6), 2)
	kit.box("plank_dk", Vector3(-2.15, top - 0.05, -1.3), Vector3(0.9, 0.1, 2.6), 2)
	kit.box("plank_dk", Vector3(2.15, top - 0.05, -1.3), Vector3(0.9, 0.1, 2.6), 2)
	for s in [[Vector3(0, top + 0.5, -2.6), Vector3(5.4, 1.0, 0.1)], [Vector3(0, top + 0.5, 2.6), Vector3(5.4, 1.0, 0.1)],
			[Vector3(-2.6, top + 0.5, 0), Vector3(0.1, 1.0, 5.4)], [Vector3(2.6, top + 0.5, 0), Vector3(0.1, 1.0, 5.4)]]:
		kit.box("plank", s[0], s[1], 2)
		kit.box("glass", s[0] + Vector3(0, 0.95, 0), s[1] * Vector3(1, 0.9, 1) * Vector3(1, 1, 1) - Vector3(0, 0, 0), 0)
	for p in [Vector2(-2.6, -2.6), Vector2(2.6, -2.6), Vector2(-2.6, 2.6), Vector2(2.6, 2.6)]:
		kit.box("metal", Vector3(p.x, top + 1.25, p.y), Vector3(0.12, 2.5, 0.12), 0)
	kit.cone("tin_red", Vector3(0, top + 2.5, 0), 4.3, 1.4, 4, PI * 0.25)
	# the Osborne fire-finder on its stand in the middle of the cab
	kit.cyl("metal", Vector3(0, top, 0.9), 0.08, 0.08, 1.0, 6, 0)
	kit.cyl("metal", Vector3(0, top + 1.0, 0.9), 0.4, 0.4, 0.08, 12, 0)

static func _hospital(kit: Kit, d: Dictionary) -> void:
	var w := float(d.get("w", 26))
	var dd := float(d.get("d", 16))
	var hw := w * 0.5
	var hd := dd * 0.5
	var h := 4.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	var ft := 0.6 + float(d.get("_sink", 0.0))
	kit.box("concrete_dk", Vector3(0, -ft * 0.5, 0), Vector3(w + 0.4, ft, dd + 0.4), 1)
	kit.box("concrete", Vector3(0, 0.06, 0), Vector3(w - 0.2, 0.12, dd - 0.2), 1)
	var win := func(n: int, l: float) -> Array:
		var o: Array = []
		for i in n:
			o.append([-l * 0.5 + (i + 0.5) * l / n, 1.4, 1.1, 2.6])
		return o
	var back: Array = win.call(6, w)
	_wall(kit, "concrete", Vector3(-hw, 0, -hd), Vector3(hw, 0, -hd), h, back, 0.3)
	_wall(kit, "concrete", Vector3(-hw, 0, -hd + 0.15), Vector3(-hw, 0, hd - 0.15), h, win.call(3, dd), 0.3)
	_wall(kit, "concrete", Vector3(hw, 0, -hd + 0.15), Vector3(hw, 0, hd - 0.15), h, win.call(3, dd), 0.3)
	var front: Array = win.call(6, w)
	front[2] = [front[2][0] + 1.0, 3.0, 0.0, 3.0]          # the main doors, blown in
	front.remove_at(3)
	_wall(kit, "concrete", Vector3(-hw, 0, hd), Vector3(hw, 0, hd), h, front, 0.3)
	# inner corridor walls with doorways
	_wall(kit, "concrete", Vector3(-hw + 0.3, 0, -1.5), Vector3(hw - 0.3, 0, -1.5), h, [[-8.0, 1.2, 0, 2.2], [-1.0, 1.2, 0, 2.2], [6.0, 1.2, 0, 2.2]], 0.18)
	_wall(kit, "concrete", Vector3(-4.0, 0, -hd + 0.3), Vector3(-4.0, 0, -1.6), h, [], 0.18)
	_wall(kit, "concrete", Vector3(3.0, 0, -hd + 0.3), Vector3(3.0, 0, -1.6), h, [], 0.18)
	# the upper floor fell in: what's left is a slab over the east wing and jagged stumps of wall above it
	kit.box("concrete", Vector3(hw * 0.5 + 0.5, h + 0.15, 0), Vector3(hw - 1.0, 0.3, dd - 0.6), 2)
	kit.box("concrete", Vector3(-hw + 2.5, h + 0.15, -hd + 2.0), Vector3(4.4, 0.3, 3.4), 2)
	for i in int(w / 1.3):
		var x := -hw + 0.65 + i * 1.3
		var hh := maxf(0.0, rng.randf_range(-0.8, 3.0) + (1.5 if x > 0 else -0.5))
		if hh > 0.3:
			kit.box("concrete", Vector3(x, h + 0.3 + hh * 0.5, -hd), Vector3(1.3, hh, 0.3), 0)
		var hf := maxf(0.0, rng.randf_range(-1.0, 2.6) + (1.2 if x > 0 else -0.8))
		if hf > 0.3:
			kit.box("concrete", Vector3(x, h + 0.3 + hf * 0.5, hd), Vector3(1.3, hf, 0.3), 0)
	# rebar, rubble, a red cross still on the wall, and the sign fallen across the steps
	for i in 14:
		kit.pole("metal", Vector3(rng.randf_range(-hw, hw), h + 0.3, rng.randf_range(-hd, hd) * 0.2 + (hd if i % 2 == 0 else -hd)), Vector3(rng.randf_range(-hw, hw), h + rng.randf_range(1.0, 2.4), (hd if i % 2 == 0 else -hd)), 0.02)
	for i in 22:
		var p := Vector3(rng.randf_range(-hw + 1, hw - 1), 0.25, rng.randf_range(-1.0, hd - 1.0) if i % 3 else rng.randf_range(-hd + 1, -2.0))
		kit.box("concrete_dk", p, Vector3(rng.randf_range(0.4, 1.6), rng.randf_range(0.2, 0.6), rng.randf_range(0.4, 1.4)), 0, Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3)))
	kit.box("red", Vector3(-hw + 4.5, 3.0, hd + 0.17), Vector3(1.2, 0.35, 0.04), 0)
	kit.box("red", Vector3(-hw + 4.5, 3.0, hd + 0.17), Vector3(0.35, 1.2, 0.04), 0)
	kit.box("paint", Vector3(2.0, 0.5, hd + 2.0), Vector3(6.0, 1.0, 0.12), 0, Basis(Vector3.UP, 0.15) * Basis(Vector3.RIGHT, -1.2))
	for i in 3:
		kit.box("metal", Vector3(6.0 + i * 2.4, 0.35, -hd + 1.6), Vector3(0.85, 0.06, 1.9), 0, Basis(Vector3.UP, sin(i) * 0.3) * Basis(Vector3.FORWARD, 0.2 if i == 1 else 0.0))

static func _ruin(kit: Kit, d: Dictionary) -> void:
	var w := float(d.get("w", 8))
	var dd := float(d.get("d", 6))
	var hw := w * 0.5
	var hd := dd * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = int(d.get("seed", 0)) * 7 + 3
	kit.box("concrete", Vector3(0, 0.05, 0), Vector3(w, 0.12, dd), 1)
	# walls broken into ragged columns
	var sides := [[Vector3(-hw, 0, -hd), Vector3(1, 0, 0), w], [Vector3(-hw, 0, hd), Vector3(1, 0, 0), w], [Vector3(-hw, 0, -hd), Vector3(0, 0, 1), dd], [Vector3(hw, 0, -hd), Vector3(0, 0, 1), dd]]
	for si in sides.size():
		var sd: Array = sides[si]
		var len: float = sd[2]
		var n := int(len / 0.9)
		for i in n:
			var along := (i + 0.5) * len / n
			var hh := rng.randf_range(0.2, 3.0) * (0.6 if si == 1 else 1.0)
			if si == 1 and absf(along - len * 0.5) < 0.8:
				continue
			if hh < 0.35:
				continue
			var u: Vector3 = sd[1]
			var p: Vector3 = sd[0] + u * along
			var sz := Vector3(len / n if u.x > 0 else 0.25, hh, len / n if u.z > 0 else 0.25)
			kit.box("concrete", p + Vector3(0, hh * 0.5, 0), sz, 1)
	for i in 8:
		var p := Vector3(rng.randf_range(-hw + 0.6, hw - 0.6), 0.2, rng.randf_range(-hd + 0.6, hd - 0.6))
		kit.box("concrete_dk", p, Vector3(rng.randf_range(0.3, 1.2), rng.randf_range(0.15, 0.5), rng.randf_range(0.3, 1.0)), 0, Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3)))
	for i in 3:
		kit.box("burnt", Vector3(rng.randf_range(-hw + 1, hw - 1), 0.3, rng.randf_range(-hd + 1, hd - 1)), Vector3(2.4, 0.12, 0.2), 0, Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.BACK, 0.25))

static func _screen(kit: Kit) -> void:
	for x in [-9.0, -3.0, 3.0, 9.0]:
		kit.box("metal", Vector3(x, 6.5, -0.6), Vector3(0.35, 13.0, 0.35), 1)
	for y in [4.0, 8.0, 12.0]:
		kit.box("metal", Vector3(0, y, -0.6), Vector3(18.5, 0.15, 0.15), 0)
	kit.box("paint", Vector3(0, 8.2, 0), Vector3(20.0, 9.5, 0.2), 2)
	# a bite out of the top corner where the storm took it
	kit.box("metal", Vector3(7.5, 12.8, 0.05), Vector3(4.0, 0.15, 0.24), 0, Basis(Vector3.FORWARD, 0.25))
	kit.box("concrete_dk", Vector3(0, 0.8, -0.6), Vector3(20.0, 1.6, 1.0), 1)

# ---------------------------------------------------------------- build 16's shapes
static func _pier(kit: Kit, d: Dictionary) -> void:
	# a board walk out over the water along local -x from the shore, on posts down into the lake bed
	var l := float(d.get("len", 20.0))
	kit.box("plank_dk", Vector3(l * 0.5 - l + 6.0, 0, 0), Vector3(l, 0.12, 2.2), 2)
	var n := int(l / 2.5)
	for i in n + 1:
		var x := 6.0 - i * l / n
		for zs in [-1.0, 1.0]:
			kit.box("log", Vector3(x, -1.6, zs), Vector3(0.18, 3.2, 0.18), 0)
	kit.box("log", Vector3(6.0 - l + 0.1, 0.45, -1.0), Vector3(0.12, 0.8, 0.12), 0)
	kit.box("log", Vector3(6.0 - l + 0.1, 0.45, 1.0), Vector3(0.12, 0.8, 0.12), 0)

static func _boat(kit: Kit, d: Dictionary, at := Vector3.ZERO) -> void:
	# a flat-bottomed skiff: bottom, two flared sides, a transom and a pointed bow
	var b := Basis(Vector3.UP, float(d.get("yaw", 0.0)))
	kit.box("plank_dk", at + b * Vector3(0, -0.05, 0), Vector3(3.2, 0.06, 1.0), 0, b)
	for sd in [-1.0, 1.0]:
		var sb := b * Basis(Vector3.RIGHT, sd * 0.35)
		kit.box("plank", at + b * Vector3(-0.2, 0.18, sd * 0.58), Vector3(2.8, 0.42, 0.05), 0, sb)
		kit.box("plank", at + b * Vector3(1.45, 0.18, sd * 0.32), Vector3(0.75, 0.42, 0.05), 0, b * Basis(Vector3.UP, -sd * 0.55) * Basis(Vector3.RIGHT, sd * 0.35))
	kit.box("plank", at + b * Vector3(-1.6, 0.18, 0), Vector3(0.05, 0.42, 1.25), 0, b)
	kit.box("plank_dk", at + b * Vector3(0.1, 0.25, 0), Vector3(0.3, 0.05, 1.15), 0, b)
	kit.box("log", at + b * Vector3(-0.3, 0.33, 0.3), Vector3(2.2, 0.05, 0.05), 0, b * Basis(Vector3.UP, 0.25))

static func _windmill(kit: Kit) -> void:
	for p in [Vector2(-1.4, -1.4), Vector2(1.4, -1.4), Vector2(-1.4, 1.4), Vector2(1.4, 1.4)]:
		kit.pole("metal", Vector3(p.x, 0, p.y), Vector3(p.x * 0.18, 10.5, p.y * 0.18), 0.07)
		kit.box("metal", Vector3(p.x, 0.15, p.y), Vector3(0.3, 0.3, 0.3), 1)
	for y in [3.0, 6.0, 8.5]:
		var k: float = 1.0 - y / 12.0
		kit.box("metal", Vector3(0, y, -1.4 * k), Vector3(2.8 * k, 0.05, 0.05), 0)
		kit.box("metal", Vector3(0, y, 1.4 * k), Vector3(2.8 * k, 0.05, 0.05), 0)
	kit.box("tin_red", Vector3(0, 10.7, 0.2), Vector3(0.5, 0.5, 1.2), 0)
	kit.box("tin", Vector3(0, 10.9, -1.2), Vector3(0.05, 1.0, 1.6), 0)
	# the wheel: eighteen blades round a hub, standing still in the windless noon
	for i in 18:
		var a := i * TAU / 18.0
		var bb := Basis(Vector3.BACK, a) * Basis(Vector3.UP, 0.35)
		kit.box("tin", Vector3(0, 10.7, 0.9) + Basis(Vector3.BACK, a) * Vector3(0, 1.3, 0), Vector3(0.32, 1.9, 0.03), 0, bb)
	kit.cyl("metal", Vector3(0, 10.7, 0.75), 0.2, 0.2, 0.3, 8, 0, Basis(Vector3.RIGHT, PI * 0.5))
	kit.cyl("tin", Vector3(2.4, 0, 0.0), 1.3, 1.3, 1.6, 12, 1)

static func _highrise(kit: Kit, d: Dictionary) -> void:
	var w := float(d.get("w", 20))
	var dd := float(d.get("d", 16))
	var H := float(d.get("h", 20))
	var hw := w * 0.5
	var hd := dd * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = int(d.get("seed", 1))
	var lobby := bool(d.get("lobby", false))
	var g := 4.0
	var ft := 1.0 + float(d.get("_sink", 0.0))
	kit.box("concrete_dk", Vector3(0, -ft * 0.5, 0), Vector3(w + 0.4, ft, dd + 0.4), 1)
	kit.box("concrete", Vector3(0, 0.06, 0), Vector3(w - 0.3, 0.12, dd - 0.3), 1)
	# the ground floor: real walls with a doorway and shopfront holes, so the lobby can be walked into
	var front := [[0.0, 3.0, 0.0, 2.9]]
	for i in int(hw / 4.0):
		front.append([-hw + 2.5 + i * 4.0, 2.2, 0.9, 2.9])
	_wall(kit, "concrete", Vector3(-hw, 0, hd), Vector3(hw, 0, hd), g, front, 0.35)
	_wall(kit, "concrete", Vector3(-hw, 0, -hd), Vector3(hw, 0, -hd), g, [] if lobby else [[hw * 0.4, 1.6, 0.0, 2.4]], 0.35)
	_wall(kit, "concrete", Vector3(-hw, 0, -hd + 0.17), Vector3(-hw, 0, hd - 0.17), g, [[0.0, 2.4, 0.9, 2.9]], 0.35)
	_wall(kit, "concrete", Vector3(hw, 0, -hd + 0.17), Vector3(hw, 0, hd - 0.17), g, [] if lobby else [[1.0, 2.4, 0.9, 2.9]], 0.35)
	# the storeys above: one shell painted with windows, broken back at the top
	var top := H
	if bool(d.get("broken", false)):
		top = H * rng.randf_range(0.55, 0.8)
	kit.box("facade", Vector3(0, g + (top - g) * 0.5, 0), Vector3(w, top - g, dd), 2)
	kit.box("concrete_dk", Vector3(0, top + 0.15, 0), Vector3(w + 0.3, 0.3, dd + 0.3), 0)
	for i in int(w / 2.0):
		var x := -hw + 1.0 + i * 2.0
		for zs in [-1.0, 1.0]:
			var hh := rng.randf_range(0.0, 2.8) if rng.randf() < 0.7 else 0.0
			if hh > 0.3:
				kit.box("facade", Vector3(x, top + 0.3 + hh * 0.5, zs * (hd - 0.2)), Vector3(2.0, hh, 0.4), 0)
	if bool(d.get("broken", false)):
		# what came down lies at the foot of the tower
		for i in 10:
			var p := Vector3(rng.randf_range(-hw - 4, hw + 4), 0.3, (hd + rng.randf_range(1.5, 5.0)) * (1.0 if i % 2 == 0 else -1.0))
			kit.box("concrete_dk", p, Vector3(rng.randf_range(0.8, 2.6), rng.randf_range(0.3, 1.1), rng.randf_range(0.6, 2.0)), 0, Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3)))
	# the lobby inside: a ceiling, a desk, columns
	kit.box("concrete_dk", Vector3(0, g - 0.1, 0), Vector3(w - 0.6, 0.2, dd - 0.6), 0)
	for p in [Vector2(-hw * 0.5, -hd * 0.4), Vector2(hw * 0.5, -hd * 0.4), Vector2(-hw * 0.5, hd * 0.4), Vector2(hw * 0.5, hd * 0.4)]:
		kit.box("concrete", Vector3(p.x, g * 0.5, p.y), Vector3(0.6, g, 0.6), 1)
	if lobby:
		kit.box("plank_dk", Vector3(0, 0.55, -hd + 3.0), Vector3(6.0, 1.1, 0.8), 1)
		kit.box("tin_red", Vector3(-hw + 0.25, 2.2, 0), Vector3(0.05, 2.0, 6.0), 0)

static func _rubble(kit: Kit, d: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(d.get("seed", 3)) * 31 + 7
	var w := float(d.get("w", 24))
	var dd := float(d.get("d", 20))
	for i in 26:
		var p := Vector3(rng.randf_range(-w * 0.45, w * 0.45), rng.randf_range(0.1, 0.9), rng.randf_range(-dd * 0.45, dd * 0.45))
		var sz := Vector3(rng.randf_range(1.0, 4.0), rng.randf_range(0.4, 1.8), rng.randf_range(0.8, 3.0))
		kit.box("concrete" if i % 3 else "concrete_dk", p, sz, 1 if sz.y > 1.2 and i % 2 == 0 else 0, Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.4, 0.4)))
	for i in 3:
		var x := rng.randf_range(-w * 0.3, w * 0.3)
		var hh := rng.randf_range(4.0, 9.0)
		kit.box("facade", Vector3(x, hh * 0.5, rng.randf_range(-dd * 0.3, dd * 0.3)), Vector3(rng.randf_range(3.0, 7.0), hh, 0.4), 1)
	for i in 8:
		kit.pole("metal", Vector3(rng.randf_range(-w * 0.4, w * 0.4), 0.4, rng.randf_range(-dd * 0.4, dd * 0.4)), Vector3(rng.randf_range(-w * 0.4, w * 0.4), rng.randf_range(1.5, 3.5), rng.randf_range(-dd * 0.4, dd * 0.4)), 0.025)

# ---------------------------------------------------------------- Starfall (build 17, remade in 19)
# A saucer some 17 m across, come down at a shallow angle out of the east and dug in on its leading (west) edge: a
# berm of earth shoved up in front of it, the upper hull stepped up to a cracked green-lit dome, a band of ports round
# the rim (most dark, three still lit), a landing leg torn off and lying in the scar, and hull plating strewn back
# along the furrow. Every loose piece sits on the ground where it lies (the site's own ground, not one flat level).

# how far the ground at a point of the site (local x, z) is above or below the site's origin
# ---------------------------------------------------------------- build 19: the towns' clutter
# Sandbag walls at the guard posts, washing lines, crate stacks, water tanks, tables, scrap heaps and lamp posts: the
# lived-in detail the settlements were short of. Each piece follows the ground under it, part by part.
static func _dress(L: Array) -> void:
	# Camp of the Door: the vault folk's camp in front of Haven 12
	L.append(R("sandbags", -5.5, 190.5, 0, {"len": 5.0, "yaw": 0.15}))
	L.append(R("sandbags", 5.5, 190.5, 0, {"len": 5.0, "yaw": -0.15}))
	L.append(R("lamp", -2.4, 189.6, 0))
	L.append(R("lamp", 2.4, 189.6, 0))
	L.append(R("washline", 0.0, 210.0, 0))
	L.append(R("crates", -12.5, 206.5, 0, {"seed": 1}))
	L.append(R("crates", 12.5, 203.0, 0, {"seed": 2}))
	L.append(R("watertank", 13.5, 209.5, 0))
	L.append(R("table", -7.0, 201.5, 0, {"yaw": 0.3}))
	L.append(R("scrap", -14.5, 199.5, 0, {"seed": 3}))
	L.append(R("kit", -12.4, 211.8, 0, {"id": "k:q_Barrel", "len": 0.9}))
	L.append(R("kit", 15.5, 193.5, 0, {"id": "k:g_gravestone-cross", "len": 0.9, "yaw": PI}))
	L.append(R("kit", 17.0, 194.0, 0, {"id": "k:g_gravestone-round", "len": 0.9, "yaw": PI + 0.2}))
	L.append(R("kit", 9.5, 212.0, 0, {"id": "k:s_box-large", "len": 1.0, "yaw": 0.4}))
	# build 20: a cook pot over the fire, a tarp over the stores, the generator and its aerial, the notice board,
	# lights strung over the middle of the camp, a garden plot, more seats round the fire, water drums by the tank
	L.append(R("tripod", 0.0, 203.0, 0))
	L.append(R("log_seat", 0.4, 206.4, 0, {"yaw": 0.1}))
	L.append(R("log_seat", -0.6, 199.8, 0, {"yaw": -0.15}))
	L.append(R("tarp", -15.5, 215.0, 0, {"yaw": 0.3}))
	L.append(R("crates", -15.6, 215.4, 0, {"seed": 20}))
	L.append(R("generator", 15.5, 213.5, 0, {"yaw": -0.4}))
	L.append(R("antenna", 17.5, 211.5, 0))
	L.append(R("board", 5.0, 215.0, 0, {"yaw": 0.0}))
	L.append(R("lights", 0.0, 199.6, 0, {"len": 10.0}))
	L.append(R("garden", -17.5, 207.5, 0, {"w": 3.2, "d": 2.2, "yaw": 0.2}))
	L.append(R("kit", 15.3, 207.6, 0, {"id": "k:q_Barrel", "len": 0.85, "yaw": 0.5}))
	L.append(R("kit", 15.9, 211.0, 0, {"id": "k:s_barrel-open", "len": 0.85}))
	L.append(R("kit", -5.5, 211.5, 0, {"id": "k:q_Pallet_Broken", "len": 1.3, "yaw": 1.0}))
	L.append(R("kit", 11.0, 192.0, 0, {"id": "k:q_TrashBag_2", "len": 1.0}))
	L.append(R("kit", -11.0, 193.0, 0, {"id": "k:q_Wheels_Stack", "len": 1.1}))
	# Dustwell: posts on the north-west and south-east roads, a well-side market table
	L.append(R("sandbags", -99.8, 73.2, 0, {"len": 4.0, "yaw": 0.38}))
	L.append(R("lamp", -105.9, 75.6, 0))
	L.append(R("sandbags", -81.2, 112.4, 0, {"len": 4.0, "yaw": 0.51}))
	L.append(R("lamp", -86.8, 115.6, 0))
	L.append(R("crates", -87.0, 101.0, 0, {"seed": 4}))
	L.append(R("table", -103.5, 110.0, 0, {"yaw": 0.6}))
	L.append(R("washline", -111.0, 89.0, 0, {"yaw": 0.2}))
	L.append(R("scrap", -73.0, 98.0, 0, {"seed": 5}))
	# Cinder Gap: the gate's sandbags, crates behind Pike's, a washing line behind the homes, lamps on the street
	L.append(R("sandbags", 774.0, -44.0, 0, {"len": 4.0, "yaw": PI * 0.5}))
	L.append(R("sandbags", 774.0, -37.5, 0, {"len": 3.0, "yaw": PI * 0.5}))
	L.append(R("crates", 806.5, -60.5, 0, {"seed": 6}))
	L.append(R("washline", 789.0, -20.5, 0))
	L.append(R("lamp", 795.0, -49.0, 0))
	L.append(R("lamp", 825.0, -49.0, 0))
	L.append(R("lamp", 845.0, -49.0, 0))
	L.append(R("table", 818.0, -45.0, 0, {"yaw": 0.0}))
	L.append(R("watertank", 845.5, -19.5, 0))
	L.append(R("scrap", 862.0, -40.0, 0, {"seed": 7}))
	# Lantern Row
	L.append(R("crates", 596.5, 98.0, 0, {"seed": 8}))
	L.append(R("washline", 580.0, 142.0, 0))
	L.append(R("table", 609.5, 125.5, 0, {"yaw": 0.2}))
	L.append(R("scrap", 640.0, 135.0, 0, {"seed": 9}))
	# Stillwater: nets and washing by the water, the co-op's stock, lamps along the shore path
	L.append(R("washline", -70.0, -745.0, 0, {"yaw": 1.2}))
	L.append(R("crates", -58.5, -780.5, 0, {"seed": 10}))
	L.append(R("table", -60.0, -751.0, 0, {"yaw": 0.4}))
	L.append(R("lamp", -70.0, -735.0, 0))
	L.append(R("lamp", -50.0, -740.0, 0))
	L.append(R("sandbags", -101.0, -679.0, 0, {"len": 3.0, "yaw": 0.1}))
	L.append(R("watertank", -20.0, -766.0, 0))
	# the Ashborn: meat racks have their tables, the gate its log wall
	L.append(R("table", 1302.0, -321.0, 0, {"yaw": 0.9}))
	L.append(R("crates", 1322.0, -349.0, 0, {"seed": 11}))
	# the Garage market and the Children's camp
	L.append(R("crates", 290.0, -712.0, 0, {"seed": 12}))
	L.append(R("scrap", 283.0, -695.0, 0, {"seed": 13}))
	L.append(R("table", 300.0, -699.0, 0, {"yaw": 0.0}))
	L.append(R("washline", 1140.0, -620.0, 0, {"yaw": 0.3}))
	L.append(R("crates", 1168.0, -612.0, 0, {"seed": 14}))

# the ground under a point of a piece, against the ground at its middle (turning with the piece)
static func _lifty(d: Dictionary, p: Vector3) -> float:
	var w: Vector3 = Basis(Vector3.UP, float(d.get("yaw", 0.0)) + int(d.r) * PI * 0.5) * p
	return Game.height(float(d.x) + w.x, float(d.z) + w.z) - _ground(d)

static func _sandbags(kit: Kit, d: Dictionary) -> void:
	var l := float(d.get("len", 4.0))
	var b := Basis(Vector3.UP, float(d.get("yaw", 0.0)))
	var n := maxi(2, int(l / 0.6))
	for layer in 3:
		var m := n - (layer % 2)
		for i in m:
			var x := (i - (m - 1) * 0.5) * (l / n)
			var y := _lifty(d, Vector3(x, 0, 0)) + 0.12 + layer * 0.22
			kit.box("canvas" if (i + layer) % 3 else "hide", b * Vector3(x, y, 0), Vector3(l / n * 0.96, 0.24, 0.44 - layer * 0.04), 0, b * Basis(Vector3.UP, sin(i * 3.1 + layer) * 0.08))
	if not kit.solids_only:
		var bs := BoxShape3D.new()
		bs.size = Vector3(l, 0.8, 0.46)
		kit.cols.append([bs, Transform3D(b, Vector3(0, _lifty(d, Vector3.ZERO) + 0.4, 0))])

static func _washline(kit: Kit, d: Dictionary) -> void:
	var b := Basis(Vector3.UP, float(d.get("yaw", 0.0)))
	var tops: Array = []
	for sx in [-2.6, 2.6]:
		var g := _lifty(d, Vector3(sx, 0, 0))
		kit.cyl("log", b * Vector3(sx, g - 0.2, 0), 0.05, 0.04, 2.3, 5, 0)
		tops.append(b * Vector3(sx, g + 2.0, 0))
	kit.pole("dark", tops[0], tops[1], 0.008)
	var cloth := ["canvas", "canvas_red", "mattress", "canvas_green", "hide"]
	for i in 5:
		var t := 0.12 + i * 0.19
		var at: Vector3 = (tops[0] as Vector3).lerp(tops[1], t)
		var sag := sin(t * PI) * 0.12
		var hh := 0.55 + fmod(i * 0.37, 0.35)
		var ww := 0.45 + fmod(i * 0.29, 0.3)
		kit.box(cloth[i % cloth.size()], at + Vector3(0, -sag - hh * 0.5 - 0.02, 0), Vector3(ww, hh, 0.02), 0, b * Basis(Vector3.RIGHT, sin(i * 1.7) * 0.08))

static func _crates(kit: Kit, d: Dictionary) -> void:
	var sd := int(d.get("seed", 0))
	var g := _lifty(d, Vector3.ZERO)
	var lo := minf(g, minf(_lifty(d, Vector3(0.9, 0, 0)), _lifty(d, Vector3(-0.9, 0, 0))))
	kit.box("plank", Vector3(-0.47, lo + 0.45, 0), Vector3(0.9, 0.9 + (g - lo) * 2.0, 0.9), 1)
	kit.box("plank_dk", Vector3(0.47, lo + 0.4, 0.05), Vector3(0.8, 0.8 + (g - lo) * 2.0, 0.8), 1, Basis(Vector3.UP, 0.12 * (sd % 3 - 1)))
	if sd % 2 == 0:
		kit.box("plank", Vector3(-0.3, lo + 0.9 + (g - lo) + 0.32, 0.0), Vector3(0.64, 0.64, 0.64), 0, Basis(Vector3.UP, 0.4))
	else:
		kit.box("tin_teal", Vector3(0.0, lo + 0.9 + (g - lo) + 0.2, 0.1), Vector3(0.9, 0.4, 0.55), 0, Basis(Vector3.UP, -0.25))
	for i in 2:
		kit.box("dark", Vector3(-0.47 + i * 0.94, lo + 0.45, 0.455), Vector3(0.7, 0.05, 0.01), 0)

static func _watertank(kit: Kit, d: Dictionary) -> void:
	for p in [Vector3(-0.6, 0, -0.6), Vector3(0.6, 0, -0.6), Vector3(-0.6, 0, 0.6), Vector3(0.6, 0, 0.6)]:
		var g := _lifty(d, p)
		kit.box("log", Vector3(p.x, g * 0.5 + 0.6 - 0.05, p.z), Vector3(0.12, 1.3 - g, 0.12), 0)
	kit.box("plank", Vector3(0, 1.22, 0), Vector3(1.5, 0.1, 1.5), 0)
	kit.cyl("tin_teal", Vector3(0, 1.27, 0), 0.72, 0.72, 1.5, 14, 0)
	kit.cyl("tin", Vector3(0, 2.77, 0), 0.74, 0.2, 0.18, 14, 0)
	kit.cyl("metal", Vector3(0.55, 1.45, 0.45), 0.05, 0.05, 0.3, 6, 0, Basis(Vector3.RIGHT, PI * 0.5))
	kit.box("tin", Vector3(0.6, 0.05 + _lifty(d, Vector3(0.6, 0, 0.9)), 0.9), Vector3(0.36, 0.1, 0.36), 0)
	kit.solid_box(AABB(Vector3(-0.75, 0, -0.75), Vector3(1.5, 2.9, 1.5)))

static func _table(kit: Kit, d: Dictionary) -> void:
	var b := Basis(Vector3.UP, float(d.get("yaw", 0.0)))
	for p in [Vector3(-0.72, 0, -0.33), Vector3(0.72, 0, -0.33), Vector3(-0.72, 0, 0.33), Vector3(0.72, 0, 0.33)]:
		var g := _lifty(d, b * p)
		kit.box("plank_dk", b * Vector3(p.x, (g + 0.76) * 0.5, p.z), Vector3(0.07, 0.76 - g, 0.07), 0, b)
	kit.box("plank", b * Vector3(0, 0.78, 0), Vector3(1.7, 0.05, 0.8), 0, b)
	for i in 3:
		kit.box(["tin", "metal", "bone"][i], b * Vector3(-0.5 + i * 0.45, 0.85, 0.1 - i * 0.08), Vector3(0.12, 0.1 + i * 0.04, 0.12), 0, b)
	for sx in [-1.0, 1.0]:
		var g := _lifty(d, b * Vector3(0, 0, sx * 0.75))
		kit.box("plank", b * Vector3(0, g + 0.22, sx * 0.75), Vector3(0.45, 0.44, 0.4), 0, b)
	if not kit.solids_only:
		var bs := BoxShape3D.new()
		bs.size = Vector3(1.7, 0.8, 0.8)
		kit.cols.append([bs, Transform3D(b, Vector3(0, 0.4, 0))])

static func _scrap(kit: Kit, d: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + int(d.get("seed", 0))
	for i in 9:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.0, 1.4)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		var g := _lifty(d, p)
		var sz := Vector3(rng.randf_range(0.5, 1.6), rng.randf_range(0.04, 0.4), rng.randf_range(0.4, 1.1))
		var bb := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.BACK, rng.randf_range(-0.5, 0.5)) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3))
		kit.box(["tin", "tin_red", "metal", "tin_teal", "plank_dk"][i % 5], p + Vector3(0, g + sz.y * 0.3 + (0.8 - r * 0.5) * 0.35, 0), sz, 0, bb)
	kit.cyl("dark", Vector3(1.3, _lifty(d, Vector3(1.3, 0, 0.4)) + 0.18, 0.4), 0.38, 0.38, 0.2, 12, 0, Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.BACK, 0.3))
	kit.solid_box(AABB(Vector3(-1.2, 0, -1.2), Vector3(2.4, 0.7, 2.4)))

static func _lamp(kit: Kit, d: Dictionary) -> void:
	kit.cyl("log", Vector3(0, -0.3, 0), 0.07, 0.06, 3.6, 6, 0)
	kit.box("log", Vector3(0.3, 3.15, 0), Vector3(0.7, 0.07, 0.07), 0)
	kit.box("metal", Vector3(0.58, 2.9, 0), Vector3(0.2, 0.3, 0.2), 0)
	kit.box("warm", Vector3(0.58, 2.88, 0), Vector3(0.14, 0.2, 0.21), 0)
	kit.box("warm", Vector3(0.58, 2.88, 0), Vector3(0.21, 0.2, 0.14), 0)

# ---------------------------------------------------------------- build 20: three new places on the empty stretches
static func _ruins20(L: Array) -> void:
	# Wayside 9: a fuel stop on the old north-east highway, the canopy still up, the store gutted, raiders living in it
	L.append(R("canopy", 900, -604, 0, {"w": 12.0, "d": 7.0}))
	for px in [-3.0, 0.0, 3.0]:
		L.append(R("pump", 900 + px, -604, 0))
	L.append(R("ruin", 900, -590, 0, {"w": 12, "d": 8, "seed": 41}))
	L.append(R("shack", 915, -591, 3, {"w": 6, "d": 5, "role": "workshop", "m": "tin", "roof": "tin_red", "sign": "SERVICE"}))
	L.append(R("kit", 893, -612, 0, {"id": "k:q_Vehicle_Pickup", "len": 5.0, "yaw": 0.3, "burnt": true}))
	L.append(R("kit", 908, -613, 0, {"id": "k:q_Vehicle_Sports", "len": 4.6, "yaw": 2.0, "burnt": true}))
	L.append(R("kit", 887, -598, 0, {"id": "k:q_Container_Red", "len": 6.0, "yaw": 1.57}))
	L.append(R("sandbags", 896, -618, 0, {"len": 4.0, "yaw": 0.1}))
	L.append(R("sandbags", 905, -618.5, 0, {"len": 3.0, "yaw": -0.2}))
	L.append(R("campfire", 902.0, -594.0, 0, {"s": 0.6}))
	L.append(R("crates", 896.0, -594.5, 0, {"seed": 30}))
	L.append(R("scrap", 915.0, -604.0, 0, {"seed": 31}))
	L.append(R("kit", 897, -606.5, 0, {"id": "k:q_Barrel", "len": 0.9}))
	L.append(R("chest", 898.0, -588.0, 0, {"id": "ws_stash", "tier": "uncommon"}))
	L.append(R("sign", 900, -628, 0, {"text": "WAYSIDE 9\nFUEL  FOOD  REPAIRS\nCLOSED"}))
	# Holloway Farm: a burnt farmhouse, the barn still standing, the windmill, the fields fenced and gone to weeds
	L.append(R("ruin", -306, -598, 0, {"w": 10, "d": 8, "seed": 52}))
	L.append(R("cabin", -288, -606, 3, {"w": 8, "d": 6}))
	L.append(R("windmill", -312, -615, 0))
	L.append(R("fence", -300, -582, 0, {"len": 18.0}))
	L.append(R("fence", -291, -590, 1, {"len": 14.0}))
	L.append(R("garden", -296, -588, 0, {"w": 6.0, "d": 4.0, "yaw": 0.0}))
	L.append(R("garden", -306, -587, 0, {"w": 5.0, "d": 3.0, "yaw": 0.1}))
	L.append(R("watertank", -313, -605, 0))
	L.append(R("kit", -296, -612, 0, {"id": "k:q_Vehicle_Truck", "len": 6.0, "yaw": 0.9, "burnt": true}))
	L.append(R("kit", -310, -592, 0, {"id": "k:g_debris-wood", "len": 2.2, "yaw": 0.4}))
	L.append(R("kit", -284, -598, 0, {"id": "k:g_grave", "len": 1.4, "yaw": 1.57}))
	L.append(R("kit", -283, -596, 0, {"id": "k:g_gravestone-broken", "len": 0.9, "yaw": 1.57}))
	L.append(R("chest", -290.0, -607.5, 0, {"id": "hf_cellar", "tier": "common"}))
	L.append(R("sign", -300, -575, 0, {"text": "HOLLOWAY FARM\nEGGS  MILK  HONEY\nNO TRESPASSERS"}))
	# Relay Station K: a signals post on a rise in the Ashwood's south, the mast still up, the sentries still on
	L.append(R("blockhouse", 1000, 96, 0, {"w": 8, "d": 6}))
	L.append(R("antenna", 1006, 104, 0))
	L.append(R("antenna", 994, 105, 0))
	L.append(R("sandbags", 996, 110, 0, {"len": 4.0, "yaw": 0.0}))
	L.append(R("sandbags", 1004.5, 110, 0, {"len": 4.0, "yaw": 0.0}))
	L.append(R("crates", 990.5, 98.0, 0, {"seed": 33}))
	L.append(R("generator", 1009, 96, 0, {"yaw": 1.57}))
	L.append(R("kit", 1012, 101, 0, {"id": "k:q_Container_Green", "len": 6.0, "yaw": 0.0}))
	L.append(R("chest", 1000.0, 94.8, 0, {"id": "rk_locker", "tier": "rare"}))
	L.append(R("sign", 1000, 122, 0, {"text": "RELAY STATION K\nAUTHORIZED PERSONNEL\nSENTRIES ACTIVE"}))

static func _pump(kit: Kit, d: Dictionary) -> void:
	kit.box("concrete", Vector3(0, 0.1, 0), Vector3(1.2, 0.2, 0.7), 1)
	kit.box("tin_red", Vector3(0, 0.95, 0), Vector3(0.6, 1.5, 0.45), 1)
	kit.box("paint", Vector3(0, 1.45, 0.23), Vector3(0.45, 0.35, 0.02), 0)
	kit.box("dark", Vector3(0, 1.05, 0.23), Vector3(0.3, 0.2, 0.02), 0)
	kit.pole("dark", Vector3(0.28, 1.1, 0.1), Vector3(0.55, 0.3, 0.4), 0.02)
	kit.box("metal", Vector3(0.55, 0.3, 0.4), Vector3(0.08, 0.2, 0.08), 0)

static func _canopy(kit: Kit, d: Dictionary) -> void:
	var w := float(d.get("w", 12.0))
	var dd := float(d.get("d", 7.0))
	for p in [Vector3(-w * 0.4, 0, 0), Vector3(w * 0.4, 0, 0)]:
		var g := _lifty(d, p)
		kit.box("concrete", Vector3(p.x, (g - 0.3 + 4.6) * 0.5, 0), Vector3(0.5, 4.6 - g + 0.3, 0.5), 1)
	kit.box("paint", Vector3(0, 4.75, 0), Vector3(w, 0.35, dd), 0)
	kit.box("red", Vector3(0, 4.75, dd * 0.5 + 0.01), Vector3(w, 0.3, 0.03), 0)
	kit.box("red", Vector3(0, 4.75, -dd * 0.5 - 0.01), Vector3(w, 0.3, 0.03), 0)
	# a corner of it has come down
	kit.box("tin", Vector3(w * 0.42, 3.2, dd * 0.4), Vector3(2.4, 0.06, 1.8), 0, Basis(Vector3.BACK, 0.9))

static func _tripod(kit: Kit, d: Dictionary) -> void:
	# three poles over the fire and a blackened pot on a chain
	var top := Vector3(0, 1.55, 0)
	for i in 3:
		var a := i * TAU / 3.0 + 0.3
		var foot := Vector3(cos(a) * 0.85, _lifty(d, Vector3(cos(a) * 0.85, 0, sin(a) * 0.85)) - 0.05, sin(a) * 0.85)
		kit.pole("log", foot, top + Vector3(cos(a) * 0.06, 0.12, sin(a) * 0.06), 0.035)
	kit.pole("dark", top, Vector3(0, 0.85, 0), 0.008)
	kit.cyl("burnt", Vector3(0, 0.55, 0), 0.2, 0.24, 0.3, 10, 0)
	kit.cyl("dark", Vector3(0, 0.84, 0), 0.24, 0.22, 0.03, 10, 0)

static func _tarp(kit: Kit, d: Dictionary) -> void:
	# a lean-to: two tall poles at the front, two short at the back, a canvas sheet sloping between them
	var b := Basis(Vector3.UP, float(d.get("yaw", 0.0)))
	var front := 2.3
	var back := 1.3
	for p in [Vector3(-1.5, 0, 1.2), Vector3(1.5, 0, 1.2), Vector3(-1.5, 0, -1.2), Vector3(1.5, 0, -1.2)]:
		var g := _lifty(d, p)
		var top := front if p.z > 0 else back
		kit.cyl("log", b * Vector3(p.x, g - 0.2, p.z), 0.045, 0.04, top - g + 0.2, 5, 0)
	var ang := atan2(front - back, 2.4)
	kit.box("canvas_green", b * Vector3(0, (front + back) * 0.5 + 0.02, 0), Vector3(3.3, 0.03, sqrt(2.4 * 2.4 + pow(front - back, 2)) + 0.3), 0, b * Basis(Vector3.RIGHT, ang))
	for sx in [-1.5, 1.5]:
		kit.pole("dark", b * Vector3(sx, front, 1.2), b * Vector3(sx * 1.25, _lifty(d, Vector3(sx * 1.25, 0, 2.4)), 2.4), 0.006)

static func _generator(kit: Kit, d: Dictionary) -> void:
	var b := Basis(Vector3.UP, float(d.get("yaw", 0.0)))
	var g := minf(_lifty(d, Vector3(-0.6, 0, 0)), _lifty(d, Vector3(0.6, 0, 0)))
	kit.box("plank_dk", b * Vector3(0, g + 0.06, 0), Vector3(1.5, 0.12 - g * 0.0, 0.9), 0, b)
	kit.box("tin_red", b * Vector3(0.15, g + 0.5, 0), Vector3(1.0, 0.7, 0.7), 0, b)
	kit.cyl("metal", b * Vector3(-0.55, g + 0.12, 0), 0.26, 0.26, 0.62, 12, 0)
	kit.box("dark", b * Vector3(0.15, g + 0.5, 0.36), Vector3(0.7, 0.4, 0.02), 0, b)
	kit.cyl("metal", b * Vector3(0.45, g + 0.85, -0.15), 0.05, 0.05, 0.35, 6, 0)
	kit.cyl("dark", b * Vector3(0.45, g + 1.2, -0.15), 0.07, 0.05, 0.08, 6, 0)
	kit.pole("dark", b * Vector3(0.6, g + 0.5, 0.2), b * Vector3(1.6, _lifty(d, Vector3(1.6, 0, 0.6)) + 0.02, 0.6), 0.015)
	if not kit.solids_only:
		var bs := BoxShape3D.new()
		bs.size = Vector3(1.5, 0.9, 0.9)
		kit.cols.append([bs, Transform3D(b, Vector3(0, g + 0.45, 0))])

static func _antenna(kit: Kit, d: Dictionary) -> void:
	kit.cyl("metal", Vector3(0, -0.3, 0), 0.06, 0.03, 7.0, 6, 0)
	for i in 3:
		var y := 4.6 + i * 0.75
		var w := 1.4 - i * 0.35
		kit.box("metal", Vector3(0, y, 0), Vector3(w, 0.03, 0.03), 0)
	kit.box("red", Vector3(0, 6.75, 0), Vector3(0.1, 0.1, 0.1), 0)
	for i in 3:
		var a := i * TAU / 3.0
		kit.pole("dark", Vector3(0, 5.0, 0), Vector3(cos(a) * 2.6, _lifty(d, Vector3(cos(a) * 2.6, 0, sin(a) * 2.6)), sin(a) * 2.6), 0.006)

static func _board(kit: Kit, d: Dictionary) -> void:
	# the camp's notice board: rosters, ration lists and a hand-drawn map pinned to boards on two posts
	var b := Basis(Vector3.UP, float(d.get("yaw", 0.0)))
	for sx in [-0.8, 0.8]:
		kit.cyl("log", b * Vector3(sx, _lifty(d, Vector3(sx, 0, 0)) - 0.3, 0), 0.06, 0.05, 2.3 - _lifty(d, Vector3(sx, 0, 0)), 5, 0)
	kit.box("plank", b * Vector3(0, 1.35, 0.05), Vector3(1.8, 1.0, 0.06), 0, b)
	kit.box("tin", b * Vector3(0, 1.95, 0.08), Vector3(2.0, 0.06, 0.3), 0, b * Basis(Vector3.RIGHT, -0.2))
	var paper := ["mattress", "bone", "mattress", "canvas", "bone"]
	for i in 5:
		var px := -0.6 + i * 0.3 + sin(i * 2.3) * 0.05
		var py := 1.35 + sin(i * 1.7) * 0.25
		kit.box(paper[i], b * Vector3(px, py, 0.09), Vector3(0.22, 0.3, 0.01), 0, b * Basis(Vector3.BACK, sin(i * 3.3) * 0.12))

static func _lights(kit: Kit, d: Dictionary) -> void:
	# a string of bulbs on two poles, sagging over the middle of the camp
	var l := float(d.get("len", 10.0))
	var b := Basis(Vector3.UP, float(d.get("yaw", 0.0)))
	var a := Vector3(-l * 0.5, 0, 0)
	var e := Vector3(l * 0.5, 0, 0)
	for p in [a, e]:
		var g := _lifty(d, p)
		kit.cyl("log", b * (p + Vector3(0, g - 0.3, 0)), 0.05, 0.045, 3.3 - g, 5, 0)
	var n := 12
	var prev := Vector3.ZERO
	for i in n + 1:
		var t := float(i) / n
		var p := a.lerp(e, t) + Vector3(0, 3.0 - sin(t * PI) * 0.55, 0)
		if i > 0:
			kit.pole("dark", b * prev, b * p, 0.006)
			kit.box("warm", b * (p + Vector3(0, -0.08, 0)), Vector3(0.07, 0.1, 0.07), 0)
		prev = p

static func _garden(kit: Kit, d: Dictionary) -> void:
	# a dug plot of rows with a few hardy greens coming up, and a low board edge
	var w := float(d.get("w", 3.0))
	var dd := float(d.get("d", 2.0))
	var b := Basis(Vector3.UP, float(d.get("yaw", 0.0)))
	var g := _lifty(d, Vector3.ZERO)
	kit.box("burnt", b * Vector3(0, g + 0.02, 0), Vector3(w, 0.08, dd), 0, b)
	for side in [[Vector3(0, 0, dd * 0.5), Vector3(w + 0.1, 0.2, 0.06)], [Vector3(0, 0, -dd * 0.5), Vector3(w + 0.1, 0.2, 0.06)],
			[Vector3(w * 0.5, 0, 0), Vector3(0.06, 0.2, dd)], [Vector3(-w * 0.5, 0, 0), Vector3(0.06, 0.2, dd)]]:
		var p: Vector3 = side[0]
		kit.box("plank_dk", b * (p + Vector3(0, _lifty(d, p) + 0.06, 0)), side[1], 0, b)
	var rows := int(dd / 0.5)
	for r in rows:
		var z := -dd * 0.5 + (r + 0.5) * dd / rows
		for i in int(w / 0.45):
			var x := -w * 0.5 + 0.25 + i * 0.45
			if (r * 7 + i * 3) % 5 == 0:
				continue
			kit.cone("canvas_green", b * Vector3(x, g + 0.05, z), 0.13, 0.22 + fmod(i * 0.37 + r, 0.18), 5)

static func _lift(d: Dictionary, lx: float, lz: float) -> float:
	return Game.height(float(d.x) + lx, float(d.z) + lz) - _ground(d)

static func _ufo(kit: Kit, d: Dictionary) -> void:
	var tilt := Basis(Vector3.BACK, 0.2) * Basis(Vector3.RIGHT, -0.06)     # nose down to the west, a little roll
	var c := Vector3(0, 0.3, 0)
	var R := 8.6
	var at := func(p: Vector3) -> Vector3: return c + tilt * p
	# lower dish, the rim band, then the upper hull in two steps and the dome
	kit.cyl("alien", at.call(Vector3(0, -0.2, 0)), R * 0.3, R, 1.0, 40, 2, tilt)
	kit.cyl("dark", at.call(Vector3(0, 0.78, 0)), R + 0.06, R + 0.06, 0.34, 40, 0, tilt)
	kit.cyl("alien", at.call(Vector3(0, 1.1, 0)), R, R * 0.64, 0.7, 40, 0, tilt)
	kit.cyl("alien", at.call(Vector3(0, 1.8, 0)), R * 0.64, R * 0.4, 0.5, 32, 0, tilt)
	kit.cyl("glass", at.call(Vector3(0, 2.3, 0)), R * 0.4, R * 0.08, 1.6, 24, 0, tilt)
	kit.cyl("glow", at.call(Vector3(0, 2.25, 0)), R * 0.3, R * 0.3, 0.06, 24, 0, tilt)
	# seams on the upper hull
	for i in 12:
		var a := i * TAU / 12.0
		kit.box("dark", at.call(Vector3(cos(a) * R * 0.82, 1.48, sin(a) * R * 0.82)), Vector3(R * 0.34, 0.04, 0.08), 0, tilt * Basis(Vector3.UP, -a) * Basis(Vector3.BACK, -0.22))
	# ports in the rim band: most dead, three lit
	for i in 24:
		var a := i * TAU / 24.0
		kit.box("glow" if i in [3, 4, 17] else "glass", at.call(Vector3(cos(a) * (R + 0.08), 0.95, sin(a) * (R + 0.08))), Vector3(0.7, 0.2, 0.12), 0, tilt * Basis(Vector3.UP, -a + PI * 0.5))
	# the dome cracked open on one side
	kit.box("dark", at.call(Vector3(1.6, 3.0, 0.8)), Vector3(1.6, 0.9, 0.12), 0, tilt * Basis(Vector3.UP, 0.7) * Basis(Vector3.RIGHT, 0.3))
	# the hull breach on the east side, plating peeled back
	kit.box("dark", at.call(Vector3(R - 1.2, 0.6, -2.6)), Vector3(2.2, 1.0, 1.6), 0, tilt * Basis(Vector3.UP, 0.5))
	kit.box("alien", at.call(Vector3(R + 0.3, 1.5, -2.2)), Vector3(1.8, 0.08, 1.4), 0, tilt * Basis(Vector3.BACK, -1.0))
	# the berm of earth it shoved up in front of it as it dug in (west), and soil thrown along its flanks
	for i in 9:
		var a := PI + (i - 4) * 0.16
		var p := Vector3(cos(a) * (R + 1.0), 0.0, sin(a) * (R + 1.0))
		p.y = _lift(d, p.x, p.z) - 0.3
		kit.box("burnt" if i % 2 else "dark", p, Vector3(2.4, 1.2 + 0.5 * cos((i - 4) * 0.4), 1.8), 0, Basis(Vector3.UP, -a) * Basis(Vector3.BACK, 0.25))
	# landing legs: one still under it, one torn off and thrown into the scar
	kit.pole("metal", at.call(Vector3(-2.5, -0.1, 4.6)), at.call(Vector3(-3.2, -1.4, 5.6)), 0.14)
	var lp := Vector3(17.0, 0.0, 3.4)
	lp.y = _lift(d, lp.x, lp.z) + 0.15
	kit.pole("alien", lp, lp + Vector3(2.6, 0.1, 0.8), 0.16)
	kit.cyl("dark", lp + Vector3(2.7, -0.12, 0.8), 0.5, 0.42, 0.18, 10, 0)
	# plating strewn back along the furrow, each piece lying on the ground where it landed
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in 18:
		var x := 11.0 + i * 2.2 + rng.randf_range(-1.0, 1.0)
		var z := sin(i * 1.7) * 3.0 + rng.randf_range(-2.0, 2.0)
		var sz := Vector3(rng.randf_range(0.5, 1.6), rng.randf_range(0.06, 0.25), rng.randf_range(0.4, 1.2))
		var y := _lift(d, x, z) + sz.y * 0.5 - 0.04
		kit.box(["alien", "dark", "alien", "metal"][i % 4], Vector3(x, y, z), sz, 0, Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.15, 0.15)))
		if i % 5 == 2:
			kit.box("glow", Vector3(x, y + sz.y * 0.5 + 0.01, z), Vector3(sz.x * 0.6, 0.02, 0.08), 0, Basis(Vector3.UP, rng.randf() * TAU))

# the scorched ground round the impact and the long furrow out to the east, laid on the ground in short pieces
static func _crater(kit: Kit, d: Dictionary) -> void:
	var r := float(d.get("rad", 14.0))
	kit.cyl("dark", Vector3(0, 0.03, 0), r, r, 0.04, 28, 0)
	kit.cyl("burnt", Vector3(0, 0.05, 0), r * 0.75, r * 0.75, 0.04, 28, 0)
	var x := r * 0.6
	while x < r * 0.6 + 34.0:
		var z := sin(x * 0.12) * 0.8
		var w := maxf(0.8, 3.0 - (x - r) * 0.06)
		var g := _lift(d, x, z)
		kit.box("dark", Vector3(x, g + 0.03, z), Vector3(2.1, 0.06, w), 0)
		# the lips of the furrow: earth thrown up either side
		for s in [-1.0, 1.0]:
			var zz: float = z + s * (w * 0.5 + 0.35)
			kit.box("burnt", Vector3(x, _lift(d, x, zz) + 0.12, zz), Vector3(2.1, 0.32, 0.6), 0, Basis(Vector3.RIGHT, -s * 0.35))
		x += 2.0

# ---------------------------------------------------------------- the Meridian reactor (build 17)
# The containment hall behind the old reactor room, 16 x 14 m and 7 m high: the pressure vessel under its dome, the
# coolant loop running round the walls to three tanks, the control desks, hazard paint, and the cell where the plant
# kept what came out of the vessel (the cage itself is Reactor's, so its door can open).
static func _reactor_hall(kit: Kit) -> void:
	var h := 7.0
	kit.box("concrete_dk", Vector3(0, 0.06, -0.1), Vector3(15.2, 0.12, 13.4), 1)
	_wall(kit, "concrete", Vector3(-7.8, 0, -6.8), Vector3(-7.8, 0, 6.6), h, [], 0.4)
	_wall(kit, "concrete", Vector3(7.8, 0, -6.8), Vector3(7.8, 0, 6.6), h, [], 0.4)
	_wall(kit, "concrete", Vector3(-8.0, 0, -6.8), Vector3(8.0, 0, -6.8), h, [], 0.4)
	# the old north wall, rebuilt with two doorways and an observation window looking onto the core
	_wall(kit, "concrete", Vector3(-8.0, 0, 7.0), Vector3(8.0, 0, 7.0), h, [[-5.2, 3.0, 0.0, 3.6], [5.2, 3.0, 0.0, 3.6], [0.0, 4.2, 1.4, 3.0]], 0.8)
	kit.box("glass", Vector3(0, 2.2, 7.0), Vector3(4.2, 1.6, 0.06), 0)
	kit.box("ochre", Vector3(-5.2, 3.75, 7.42), Vector3(3.2, 0.3, 0.04), 0)
	kit.box("ochre", Vector3(5.2, 3.75, 7.42), Vector3(3.2, 0.3, 0.04), 0)
	kit.box("concrete", Vector3(0, h + 0.15, 0), Vector3(16.4, 0.3, 14.6), 2)
	# the pressure vessel, banded, with its dome and inspection ports
	var vc := Vector3(1.0, 0, -2.4)
	kit.cyl("concrete_dk", vc, 3.0, 3.0, 4.8, 24, 1)
	kit.cone("concrete", vc + Vector3(0, 4.8, 0), 3.0, 1.3, 24)
	for y in [0.6, 2.4, 4.2]:
		kit.cyl("metal", vc + Vector3(0, y, 0), 3.08, 3.08, 0.22, 24, 0)
	for a in [0.4, 1.9, 3.5, 5.0]:
		var p := vc + Vector3(cos(a) * 3.07, 3.1, sin(a) * 3.07)
		kit.box("glow", p, Vector3(0.5, 0.36, 0.5), 0, Basis(Vector3.UP, -a))
	kit.cyl("ochre", vc + Vector3(0, 0.01, 0), 3.9, 3.9, 0.02, 24, 0)
	kit.cyl("concrete_dk", vc + Vector3(0, 0.02, 0), 3.6, 3.6, 0.02, 24, 0)
	# coolant loop: two fat pipes from the vessel to the tanks on the east wall, and a ring under the ceiling
	for i in 3:
		var tz := -4.6 + i * 3.4
		kit.cyl("tin_teal", Vector3(6.2, 0, tz), 1.0, 1.0, 3.4, 16, 1)
		kit.cyl("metal", Vector3(6.2, 3.4, tz), 1.0, 0.5, 0.4, 16, 0)
		kit.pole("metal", Vector3(6.2, 3.8, tz), Vector3(6.2, 5.6, tz), 0.16)
		kit.box("ochre", Vector3(5.18, 1.7, tz), Vector3(0.04, 0.3, 1.2), 0)
	kit.pole("metal", vc + Vector3(2.6, 3.4, 0.8), Vector3(6.2, 5.6, -1.2), 0.32)
	kit.pole("metal", vc + Vector3(2.6, 1.2, -0.8), Vector3(5.2, 1.2, -4.6), 0.28)
	kit.pole("metal", Vector3(6.2, 5.6, -4.6), Vector3(6.2, 5.6, 2.2), 0.2)
	for x in [-7.2, 7.2]:
		kit.pole("metal", Vector3(x, 5.9, -6.2), Vector3(x, 5.9, 6.2), 0.14)
		kit.pole("metal", Vector3(x, 6.3, -6.2), Vector3(x, 6.3, 6.2), 0.1)
	kit.pole("metal", Vector3(-7.2, 5.9, -6.2), Vector3(7.2, 5.9, -6.2), 0.14)
	kit.pole("metal", vc + Vector3(0, 6.1, 0), vc + Vector3(0, h, 0), 0.5)
	# control desks along the west wall, screens lit
	for i in 3:
		var dz := 0.6 + i * 1.9
		kit.box("metal", Vector3(-6.9, 0.5, dz), Vector3(0.9, 1.0, 1.6), 1)
		kit.box("metal", Vector3(-7.35, 1.35, dz), Vector3(0.2, 0.9, 1.6), 0, Basis(Vector3.FORWARD, 0.0))
		kit.box("glow", Vector3(-7.22, 1.45, dz - 0.35), Vector3(0.04, 0.42, 0.55), 0)
		kit.box("glow", Vector3(-7.22, 1.45, dz + 0.35), Vector3(0.04, 0.42, 0.55), 0)
		kit.box("red", Vector3(-6.6, 1.03, dz - 0.4), Vector3(0.12, 0.04, 0.12), 0)
		kit.box("ochre", Vector3(-6.6, 1.03, dz), Vector3(0.12, 0.04, 0.12), 0)
	# a gantry crane rail across the ceiling, and hazard chevrons on the floor
	kit.box("ochre", Vector3(0, 6.55, 1.8), Vector3(15.2, 0.35, 0.3), 0)
	kit.box("metal", Vector3(1.0, 6.2, 1.8), Vector3(1.2, 0.5, 0.8), 0)
	kit.pole("metal", Vector3(1.0, 5.95, 1.8), Vector3(1.0, 4.3, 1.8), 0.03)
	for i in 8:
		kit.box("ochre" if i % 2 == 0 else "dark", Vector3(-7.0 + i * 0.5, 0.13, -2.35), Vector3(0.5, 0.02, 0.25), 0)
	# drums of spent fuel, crates, a fallen ladder
	for p in [Vector3(-2.6, 0, 4.8), Vector3(-1.8, 0, 5.4), Vector3(3.2, 0, 5.2)]:
		kit.cyl("tin_red", p, 0.34, 0.34, 0.95, 12, 1)
	kit.box("plank_dk", Vector3(-0.4, 0.45, 5.4), Vector3(1.0, 0.9, 1.0), 1)
	kit.box("plank_dk", Vector3(-0.4, 1.2, 5.4), Vector3(0.7, 0.6, 0.7), 0, Basis(Vector3.UP, 0.4))
	kit.pole("metal", Vector3(3.4, 0.05, -6.0), Vector3(4.6, 3.6, -6.4), 0.03)
	kit.pole("metal", Vector3(3.9, 0.05, -6.0), Vector3(5.1, 3.6, -6.4), 0.03)

# the old reactor room dressed: coolant pipes along the walls, gauges, a desk, a bank of lockers, lamps
static func _reactor_dress(kit: Kit) -> void:
	# the room is x -8..8, z -7..7 round the core at (0, -4.5)
	for x in [-7.35, 7.35]:
		kit.pole("metal", Vector3(x, 5.2, -6.4), Vector3(x, 5.2, 6.0), 0.16)
		kit.pole("metal", Vector3(x, 0.6, -6.4), Vector3(x, 0.6, 4.6), 0.1)
		for z in [-5.0, -1.0, 3.0]:
			kit.pole("metal", Vector3(x, 0.6, z), Vector3(x, 5.2, z), 0.08)
			kit.cyl("dark", Vector3(x + (0.12 if x < 0 else -0.12), 1.5, z + 0.5), 0.16, 0.16, 0.06, 12, 0, Basis(Vector3.FORWARD, PI * 0.5))
	# lockers on the east wall by the door
	for i in 4:
		kit.box("tin_teal", Vector3(7.1, 1.0, 4.2 - i * 0.62), Vector3(0.5, 2.0, 0.58), 1)
		kit.box("dark", Vector3(6.84, 1.6, 4.2 - i * 0.62), Vector3(0.02, 0.2, 0.3), 0)
	# the shift desk and its chair, a fallen filing cabinet
	kit.box("metal", Vector3(-5.6, 0.45, 4.6), Vector3(1.8, 0.9, 0.9), 1)
	kit.box("glow", Vector3(-5.6, 1.12, 4.4), Vector3(0.5, 0.36, 0.04), 0, Basis(Vector3.RIGHT, -0.2))
	kit.box("metal", Vector3(-4.6, 0.25, 2.6), Vector3(0.5, 1.3, 0.6), 0, Basis(Vector3.FORWARD, PI * 0.5))
	# a ring of hazard paint round the core, and a lamp cage over each door of the hall
	kit.cyl("ochre", Vector3(0, 0.01, -4.5), 2.4, 2.4, 0.02, 20, 0)
	kit.cyl("concrete_dk", Vector3(0, 0.02, -4.5), 2.15, 2.15, 0.02, 20, 0)
	for x in [-5.2, 5.2]:
		kit.box("red", Vector3(x, 4.1, -6.55), Vector3(0.36, 0.24, 0.16), 0)

static func _cage(kit: Kit) -> void:
	# a cage of rebar and chain-link, door chained shut
	for i in 9:
		var t := i / 8.0
		kit.box("metal", Vector3(-1.4 + t * 2.8, 1.2, -1.2), Vector3(0.04, 2.4, 0.04), 0)
		kit.box("metal", Vector3(-1.4 + t * 2.8, 1.2, 1.2), Vector3(0.04, 2.4, 0.04), 0)
		kit.box("metal", Vector3(-1.4, 1.2, -1.2 + t * 2.4), Vector3(0.04, 2.4, 0.04), 0)
		kit.box("metal", Vector3(1.4, 1.2, -1.2 + t * 2.4), Vector3(0.04, 2.4, 0.04), 0)
	kit.box("metal", Vector3(0, 2.42, 0), Vector3(2.9, 0.06, 2.5), 0)
	kit.box("metal", Vector3(0, 0.03, 0), Vector3(2.9, 0.06, 2.5), 0)
	kit.solid_box(AABB(Vector3(-1.45, 0, -1.25), Vector3(0.1, 2.4, 2.5)))
	kit.solid_box(AABB(Vector3(1.35, 0, -1.25), Vector3(0.1, 2.4, 2.5)))
	kit.solid_box(AABB(Vector3(-1.45, 0, -1.25), Vector3(2.9, 2.4, 0.1)))
	kit.solid_box(AABB(Vector3(-1.45, 0, 1.15), Vector3(2.9, 2.4, 0.1)))
	kit.box("metal", Vector3(0.3, 1.1, 1.25), Vector3(0.3, 0.3, 0.06), 0)

static func _garage(kit: Kit, d: Dictionary) -> void:
	# a two-storey parking deck: the market lives underneath, sandbags and scrap across its open sides
	var w := float(d.get("w", 30))
	var dd := float(d.get("d", 26))
	var hw := w * 0.5
	var hd := dd * 0.5
	kit.box("concrete", Vector3(0, 0.06, 0), Vector3(w, 0.12, dd), 1)
	for ix in 5:
		for iz in 4:
			var x := -hw + 1.0 + ix * (w - 2.0) / 4.0
			var z := -hd + 1.0 + iz * (dd - 2.0) / 3.0
			kit.box("concrete", Vector3(x, 1.75, z), Vector3(0.6, 3.5, 0.6), 1)
			kit.box("concrete", Vector3(x, 5.25, z), Vector3(0.6, 3.5, 0.6), 0)
	kit.box("concrete_dk", Vector3(0, 3.65, 0), Vector3(w, 0.3, dd), 2)
	kit.box("concrete_dk", Vector3(0, 7.1, 0), Vector3(w, 0.3, dd), 2)
	for sd in [-1.0, 1.0]:
		kit.box("concrete", Vector3(0, 4.3, sd * hd), Vector3(w, 1.0, 0.25), 0)
		kit.box("concrete", Vector3(sd * hw, 4.3, 0), Vector3(0.25, 1.0, dd), 0)
	# the barricade: three sides closed, a gate on the south
	for side in [[Vector3(0, 0, -hd), Vector3(1, 0, 0), w], [Vector3(-hw, 0, 0), Vector3(0, 0, 1), dd], [Vector3(hw, 0, 0), Vector3(0, 0, 1), dd]]:
		var c: Vector3 = side[0]
		var u: Vector3 = side[1]
		var l: float = side[2]
		var n := int(l / 2.0)
		for i in n:
			var p: Vector3 = c + u * (-l * 0.5 + (i + 0.5) * l / n)
			kit.box(["tin", "tin_red", "plank_v", "tin_teal"][i % 4], p + Vector3(0, 1.0, 0), Vector3(absf(u.x) * l / n + 0.12, 2.0, absf(u.z) * l / n + 0.12), 1)
	for i in 6:
		var x := -hw + 1.5 + i * 2.2 if i < 3 else hw - 1.5 - (i - 3) * 2.2
		kit.box("canvas", Vector3(x, 0.45, hd), Vector3(2.0, 0.9, 0.7), 1)

static func _tent(kit: Kit) -> void:
	# a canvas A-frame on a ridge pole, its back closed and its front flaps tied open
	var l := 3.6
	var w := 2.6
	var h := 2.1
	var ang := atan2(h, w * 0.5)
	var sl := sqrt(h * h + w * w * 0.25)
	for sd in [-1.0, 1.0]:
		kit.box("canvas", Vector3(sd * w * 0.25, h * 0.5, 0), Vector3(sl, 0.04, l), 0, Basis(Vector3.BACK, -sd * ang))
	kit.cyl("log", Vector3(0, h, -l * 0.5 - 0.2), 0.04, 0.04, l + 0.4, 5, 0, Basis(Vector3.RIGHT, PI * 0.5))
	kit.tri3("canvas", Vector3(-w * 0.5, 0, -l * 0.5), Vector3(w * 0.5, 0, -l * 0.5), Vector3(0, h, -l * 0.5))
	kit.solid_box(AABB(Vector3(-w * 0.45, 0, -l * 0.5), Vector3(w * 0.9, h * 0.8, l)))

static func _shrine(kit: Kit) -> void:
	# a cairn of fused green glass dragged up out of the Bowl, hung with dosimeters like prayer bells
	kit.box("concrete_dk", Vector3(0, 0.3, 0), Vector3(3.0, 0.6, 2.0), 1)
	_shards(kit, {"seed": 77}, Vector3(0, 0.6, 0), 1.6)
	for i in 5:
		kit.box("metal", Vector3(-1.2 + i * 0.6, 1.9 + sin(i) * 0.2, 0.9), Vector3(0.12, 0.18, 0.05), 0)
	kit.box("log", Vector3(-1.5, 1.2, 0.9), Vector3(0.1, 2.4, 0.1), 0)
	kit.box("log", Vector3(1.5, 1.2, 0.9), Vector3(0.1, 2.4, 0.1), 0)
	kit.box("log", Vector3(0, 2.35, 0.9), Vector3(3.1, 0.08, 0.08), 0)

static func _banner(kit: Kit) -> void:
	kit.cyl("log", Vector3.ZERO, 0.06, 0.05, 4.2, 5, 0)
	kit.box("log", Vector3(0, 4.0, 0), Vector3(1.4, 0.05, 0.05), 0)
	kit.box("canvas_green", Vector3(0, 3.0, 0.03), Vector3(1.2, 2.0, 0.03), 0)
	kit.box("glow", Vector3(0, 3.2, 0.06), Vector3(0.35, 0.35, 0.02), 0)

static func _blockhouse(kit: Kit, d: Dictionary) -> void:
	var w := float(d.get("w", 10))
	var dd := float(d.get("d", 8))
	var hw := w * 0.5
	var hd := dd * 0.5
	var h := 3.4
	var ft := 0.8 + float(d.get("_sink", 0.0))
	kit.box("concrete_dk", Vector3(0, -ft * 0.5, 0), Vector3(w + 0.6, ft, dd + 0.6), 1)
	kit.box("concrete", Vector3(0, 0.06, 0), Vector3(w - 0.3, 0.12, dd - 0.3), 1)
	_wall(kit, "concrete", Vector3(-hw, 0, -hd), Vector3(hw, 0, -hd), h, [], 0.5)
	_wall(kit, "concrete", Vector3(-hw, 0, -hd + 0.25), Vector3(-hw, 0, hd - 0.25), h, [], 0.5)
	_wall(kit, "concrete", Vector3(hw, 0, -hd + 0.25), Vector3(hw, 0, hd - 0.25), h, [], 0.5)
	_wall(kit, "concrete", Vector3(-hw, 0, hd), Vector3(hw, 0, hd), h, [[0.0, 1.8, 0.0, 2.3]], 0.5)
	kit.box("concrete", Vector3(0, h + 0.25, 0), Vector3(w + 0.4, 0.5, dd + 0.4), 0)
	# the blast door, rolled aside on its track
	kit.cyl("metal", Vector3(2.2, 0.05, hd + 0.4), 1.25, 1.25, 0.35, 16, 0, Basis(Vector3.RIGHT, PI * 0.5))
	kit.box("metal", Vector3(0.6, 0.06, hd + 0.4), Vector3(4.0, 0.12, 0.3), 0)
	kit.box("paint", Vector3(0, 2.7, hd + 0.27), Vector3(2.6, 0.5, 0.04), 0)
	# inside: the launch console, dead screens, a locker
	kit.box("metal", Vector3(0, 0.55, -hd + 0.9), Vector3(4.2, 1.1, 0.8), 1)
	kit.box("glass", Vector3(0, 1.45, -hd + 0.55), Vector3(4.0, 0.7, 0.06), 0, Basis(Vector3.RIGHT, -0.25))
	kit.box("glow", Vector3(-1.3, 1.12, -hd + 0.75), Vector3(0.18, 0.04, 0.12), 0)
	kit.box("red", Vector3(1.3, 1.12, -hd + 0.75), Vector3(0.18, 0.04, 0.12), 0)
	kit.box("metal", Vector3(-hw + 0.6, 1.0, 0.5), Vector3(0.6, 2.0, 1.4), 1)
	kit.cyl("metal", Vector3(hw - 1.0, h + 0.5, -hd + 1.0), 0.06, 0.06, 4.0, 5, 0)

static func _silo(kit: Kit) -> void:
	# the silo's cap: a concrete ring and the great split hatch, one leaf raised; vents and a stair down that ends in rubble
	kit.cyl("concrete", Vector3(0, -0.4, 0), 6.5, 6.5, 1.2, 24, 0)
	kit.solid_box(AABB(Vector3(-4.6, -0.4, -4.6), Vector3(9.2, 1.2, 9.2)))
	kit.cyl("metal", Vector3(0, 0.8, 0), 4.6, 4.6, 0.15, 24, 0)
	kit.box("metal", Vector3(-2.3, 0.98, 0), Vector3(4.6, 0.2, 9.0), 0)
	kit.box("metal", Vector3(2.0, 3.2, 0), Vector3(0.25, 5.0, 8.6), 0, Basis(Vector3.BACK, 0.28))
	kit.box("dark", Vector3(2.3, 0.97, 0), Vector3(4.2, 0.04, 8.4), 0)
	for i in 4:
		var a := i * TAU / 4.0 + 0.4
		kit.box("concrete_dk", Vector3(cos(a) * 7.6, 0.6, sin(a) * 7.6), Vector3(1.2, 1.2, 1.2), 1)
		kit.box("metal", Vector3(cos(a) * 7.6, 1.25, sin(a) * 7.6), Vector3(1.0, 0.1, 1.0), 0)
	kit.box("red", Vector3(0, 0.88, -5.2), Vector3(6.0, 0.02, 0.3), 0)

static func _shards(kit: Kit, d: Dictionary, at := Vector3.ZERO, sc := 1.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(d.get("seed", 1)) * 13 + 5
	for i in rng.randi_range(4, 8):
		var p := at + Vector3(rng.randf_range(-1.2, 1.2), -0.2, rng.randf_range(-1.2, 1.2)) * sc
		var h := rng.randf_range(0.8, 2.6) * sc
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.35, 0.35)) * Basis(Vector3.BACK, rng.randf_range(-0.35, 0.35))
		kit.cyl("glow", p, rng.randf_range(0.12, 0.3) * sc, 0.0, h, 5, 0, b)

# ---------------------------------------------------------------- materials
static func _mat(k: String) -> Material:
	if _mats.has(k):
		return _mats[k]
	var sh := preload("res://scripts/builds.gdshader")
	var spec := {
		"plank": [0, Color(0.5, 0.39, 0.27), Color(0.36, 0.27, 0.19)], "plank_v": [1, Color(0.47, 0.36, 0.25), Color(0.34, 0.25, 0.17)],
		"plank_dk": [0, Color(0.33, 0.25, 0.18), Color(0.24, 0.18, 0.13)],
		"tin": [2, Color(0.58, 0.6, 0.61), Color(), 0.6], "tin_red": [2, Color(0.52, 0.2, 0.15), Color(), 0.5], "tin_teal": [2, Color(0.25, 0.44, 0.42), Color(), 0.45],
		"canvas": [3, Color(0.62, 0.56, 0.43), Color(0.36, 0.3, 0.22)], "canvas_red": [3, Color(0.6, 0.26, 0.2), Color(0.35, 0.2, 0.15)],
		"hide": [3, Color(0.56, 0.43, 0.31), Color(0.32, 0.23, 0.16)], "mattress": [3, Color(0.7, 0.66, 0.56), Color(0.5, 0.44, 0.36)],
		"log": [4, Color(0.42, 0.32, 0.23), Color(0.23, 0.17, 0.12)], "burnt": [4, Color(0.11, 0.1, 0.09), Color(0.05, 0.05, 0.05)],
		"facade": [6, Color(0.47, 0.45, 0.42)], "canvas_green": [3, Color(0.3, 0.42, 0.22), Color(0.2, 0.26, 0.15)],
		"concrete": [5, Color(0.47, 0.45, 0.42)], "concrete_dk": [5, Color(0.33, 0.32, 0.3)], "paint": [5, Color(0.72, 0.7, 0.65)],
	}
	var m: Material
	if spec.has(k):
		var s: Array = spec[k]
		var sm := ShaderMaterial.new()
		sm.shader = sh
		sm.set_shader_parameter("mode", s[0])
		sm.set_shader_parameter("base", s[1])
		if s.size() > 2:
			sm.set_shader_parameter("alt", s[2])
		if s.size() > 3:
			sm.set_shader_parameter("rust", s[3])
		m = sm
	else:
		var st := StandardMaterial3D.new()
		var cols := {"metal": Color(0.28, 0.28, 0.3), "bone": Color(0.84, 0.8, 0.7), "red": Color(0.5, 0.11, 0.08), "ochre": Color(0.72, 0.48, 0.16),
			"dark": Color(0.06, 0.05, 0.05), "glass": Color(0.12, 0.15, 0.16), "alien": Color(0.6, 0.64, 0.68)}
		st.albedo_color = cols.get(k, Color(0.5, 0.5, 0.5))
		if k == "alien":
			st.albedo_color = Color(0.72, 0.75, 0.78)
			st.metallic = 0.45
			st.roughness = 0.3
			m = st
			_mats[k] = m
			return m
		st.roughness = 0.2 if k == "glass" else (0.5 if k == "metal" else 0.85)
		st.metallic = 0.6 if k == "metal" else (0.3 if k == "glass" else 0.0)
		if k == "glass":
			st.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			st.albedo_color.a = 0.45
		if k == "warm":
			st.albedo_color = Color(1.0, 0.8, 0.5)
			st.emission_enabled = true
			st.emission = Color(1.0, 0.72, 0.38)
			st.emission_energy_multiplier = 2.2
		if k == "glow":
			st.albedo_color = Color(0.35, 0.85, 0.3)
			st.emission_enabled = true
			st.emission = Color(0.3, 0.95, 0.25)
			st.emission_energy_multiplier = 1.4
			st.roughness = 0.15
			st.metallic = 0.3
		m = st
	_mats[k] = m
	return m

# ---------------------------------------------------------------- the mesh kit: boxes, cylinders and cones merged per material
class Kit:
	var st: Dictionary = {}
	var solids: Array = []        # local AABBs standing on the ground (the region's solid list)
	var cols: Array = []          # [shape, transform] colliders of their own
	var solids_only := false

	func _s(m: String) -> SurfaceTool:
		if not st.has(m):
			var s := SurfaceTool.new()
			s.begin(Mesh.PRIMITIVE_TRIANGLES)
			st[m] = s
		return st[m]

	func solid_box(ab: AABB) -> void:
		solids.append(ab)

	# col: 0 none, 1 a ground-standing solid (or its own collider if it's off the ground), 2 its own collider
	func box(m: String, c: Vector3, size: Vector3, col := 1, b := Basis()) -> void:
		var h := size * 0.5
		if col > 0:
			var axis := b.is_equal_approx(Basis())
			if col == 1 and axis and c.y - h.y < 0.35:
				solids.append(AABB(c - h, size))
			elif not solids_only:
				var bs := BoxShape3D.new()
				bs.size = size
				cols.append([bs, Transform3D(b, c)])
		if solids_only:
			return
		var s := _s(m)
		for ax in 3:
			for sg in [-1.0, 1.0]:
				var n := Vector3.ZERO
				n[ax] = sg
				var u := Vector3.ZERO
				var v := Vector3.ZERO
				u[(ax + 1) % 3] = 1.0
				v[(ax + 2) % 3] = 1.0
				var cn := c + b * (n * h)
				var du := b * (u * h)
				var dv := b * (v * h)
				var nw := (b * n).normalized()
				var p0 := cn - du - dv
				var p1 := cn + du - dv
				var p2 := cn + du + dv
				var p3 := cn - du + dv
				Flora.tri(s, [p0, p1, p2], [nw, nw, nw], [Color.WHITE, Color.WHITE, Color.WHITE])
				Flora.tri(s, [p0, p2, p3], [nw, nw, nw], [Color.WHITE, Color.WHITE, Color.WHITE])

	func cyl(m: String, base: Vector3, r0: float, r1: float, h: float, seg: int, col := 0, b := Basis()) -> void:
		if col == 1 and b.is_equal_approx(Basis()) and base.y < 0.35:
			solids.append(AABB(base - Vector3(r0, 0, r0) * 0.8, Vector3(r0 * 1.6, h, r0 * 1.6)))
		elif col > 0 and not solids_only:
			var cs := CylinderShape3D.new()
			cs.radius = maxf(r0, r1)
			cs.height = h
			cols.append([cs, Transform3D(b, base + b * Vector3(0, h * 0.5, 0))])
		if solids_only:
			return
		var s := _s(m)
		var w := Color.WHITE
		for k in seg:
			var a0 := k * TAU / seg
			var a1 := (k + 1) * TAU / seg
			var d0 := Vector3(cos(a0), 0, sin(a0))
			var d1 := Vector3(cos(a1), 0, sin(a1))
			var n0 := b * (d0 * h + Vector3(0, r0 - r1, 0)).normalized()
			var n1 := b * (d1 * h + Vector3(0, r0 - r1, 0)).normalized()
			var b0 := base + b * (d0 * r0)
			var b1 := base + b * (d1 * r0)
			var t0 := base + b * (d0 * r1 + Vector3(0, h, 0))
			var t1 := base + b * (d1 * r1 + Vector3(0, h, 0))
			Flora.tri(s, [b0, t1, b1], [n0, n1, n1], [w, w, w])
			Flora.tri(s, [b0, t0, t1], [n0, n0, n1], [w, w, w])
			var up := b * Vector3.UP
			Flora.tri(s, [t0, t1, base + b * Vector3(0, h, 0)], [up, up, up], [w, w, w])
			# and the bottom end closed too (a log lying on its side showed its hollow end - build 20)
			Flora.tri(s, [b1, b0, base], [-up, -up, -up], [w, w, w])

	func cone(m: String, base: Vector3, r: float, h: float, seg: int, rot := 0.0, band := false) -> void:
		if solids_only:
			return
		var s := _s(m)
		var w := Color.WHITE
		for k in seg:
			var a0 := rot + k * TAU / seg
			var a1 := rot + (k + 1) * TAU / seg
			var d0 := Vector3(cos(a0), 0, sin(a0))
			var d1 := Vector3(cos(a1), 0, sin(a1))
			var n0 := (d0 * h + Vector3(0, r, 0)).normalized()
			var n1 := (d1 * h + Vector3(0, r, 0)).normalized()
			if band:
				# a painted stripe just proud of a cone's surface (h is its height on the slope)
				var rr := r * 1.03
				var lift := Vector3(0, h, 0)
				var shrink := 0.88
				Flora.tri(s, [base + d0 * rr, base + d1 * rr * shrink + lift, base + d1 * rr], [n0, n1, n1], [w, w, w])
				Flora.tri(s, [base + d0 * rr, base + d0 * rr * shrink + lift, base + d1 * rr * shrink + lift], [n0, n0, n1], [w, w, w])
				continue
			Flora.tri(s, [base + d0 * r, base + Vector3(0, h, 0), base + d1 * r], [n0, (n0 + n1).normalized(), n1], [w, w, w])

	# a gable end: a triangle of wall 'thick' deep, width w, rising 'rise' above base
	func prism(m: String, base: Vector3, w: float, rise: float, thick: float, solid := false) -> void:
		if solids_only:
			return
		var s := _s(m)
		var c := Color.WHITE
		for sg in [-1.0, 1.0]:
			var z := Vector3(0, 0, sg * thick * 0.5)
			var n := Vector3(0, 0, sg)
			Flora.tri(s, [base + z + Vector3(-w * 0.5, 0, 0), base + z + Vector3(w * 0.5, 0, 0), base + z + Vector3(0, rise, 0)], [n, n, n], [c, c, c])
		var hw := w * 0.5
		for sg in [-1.0, 1.0]:
			var a := base + Vector3(sg * hw, 0, 0)
			var t := base + Vector3(0, rise, 0)
			var n := Vector3(sg * rise, hw, 0).normalized()
			var dz := Vector3(0, 0, thick * 0.5)
			Flora.tri(s, [a - dz, t - dz, t + dz], [n, n, n], [c, c, c])
			Flora.tri(s, [a - dz, t + dz, a + dz], [n, n, n], [c, c, c])

	func pole(m: String, a: Vector3, b: Vector3, r: float) -> void:
		if solids_only:
			return
		var dir := b - a
		var l := dir.length()
		var y := dir / l
		var x := y.cross(Vector3.FORWARD if absf(y.y) > 0.9 else Vector3.UP).normalized()
		var z := x.cross(y)
		cyl(m, a, r, r * 0.7, l, 5, 0, Basis(x, y, z))

	func tri3(m: String, a: Vector3, b: Vector3, c: Vector3) -> void:
		if solids_only:
			return
		var n := (b - a).cross(c - a).normalized()
		if n.dot(Vector3(a.x + b.x + c.x, 0, a.z + b.z + c.z)) < 0:
			n = -n
		var w := Color.WHITE
		Flora.tri(_s(m), [a, b, c], [n, n, n], [w, w, w])

	func commit(root: Node3D) -> void:
		for m in st:
			var s: SurfaceTool = st[m]
			var mi := MeshInstance3D.new()
			mi.name = "M_" + m
			mi.mesh = s.commit()
			mi.material_override = Frontier._mat(m)
			mi.visibility_range_end = 420.0
			mi.visibility_range_end_margin = 20.0
			root.add_child(mi)
		if cols.is_empty():
			return
		var body := StaticBody3D.new()
		body.name = "Body"
		body.collision_layer = 1
		root.add_child(body)
		for c in cols:
			var cs := CollisionShape3D.new()
			cs.shape = c[0]
			cs.transform = c[1]
			body.add_child(cs)
