# Builds the Hole (the K-hole's other place) as a Godot area: data/khole/{region.json,height.f32,world.json}.
# The original draws it procedurally (khole.js, KH() in world.js), so this script evaluates the same terrain function
# on a 1 m grid and takes the Hole's people, echo shards and the glyph stone from world_meta.mjs (AREA=khole).
# Usage: python3 khole_area.py meta/khole.json data/khole
import json, math, struct, sys, os
meta = json.load(open(sys.argv[1]))
out = sys.argv[2]
X, Z, R, Y = -2500.0, 0.0, 250.0, -30.0
def KH(x, z):
    lx, lz = x - X, z - Z
    d = math.hypot(lx, lz)
    return (Y + 2.4 * math.sin(lx * .035) * math.cos(lz * .03) + 1.1 * math.sin((lx + lz) * .08)
            + .5 * math.sin(lx * .21 + math.cos(lz * .13) * 2) + max(0, d - R * .78) ** 2 * .012)
E = R + 80
x0, z0 = X - E, Z - E
n = int(E * 2) + 1
hm = [KH(x0 + i, z0 + j) for j in range(n) for i in range(n)]
os.makedirs(out, exist_ok=True)
open(os.path.join(out, "height.f32"), "wb").write(struct.pack("<%df" % len(hm), *hm))
hexc = lambda v: "#%06x" % v
LOOKS = {  # entities.js LOOKS for the Hole's inhabitants
    "ferryman": {"body": hexc(0x1a1a2a), "skin": hexc(0x6a7a9a), "hat": "hood", "coat": hexc(0x1a1a2a), "bulk": 1, "glow": hexc(0x88ffff), "scale": 1.65},
    "committee": {"body": hexc(0xd84a8a), "skin": hexc(0x9ad8a8), "bulk": 1.6, "glow": hexc(0xffcc44), "scale": 1.1, "bald": True},
    "mother_hum": {"fem": True, "body": hexc(0xf0e8d8), "skin": hexc(0xc8b8e8), "bulk": 1.9, "glow": hexc(0xe8ccff), "scale": 1.45},
    "gnorl": {"body": hexc(0x8aaa3a), "skin": hexc(0xe8a8d8), "bulk": 1, "scale": 0.95},
}
npcs = []
for d in meta["npcs"]:
    lk = LOOKS.get(d["id"], {})
    npcs.append({"id": d["id"], "name": d["name"], "x": d["x"], "z": d["z"], "y": KH(d["x"], d["z"]), "rot": math.atan2(X + 4 - d["x"], Z + 24 - d["z"]),
                 "wander": d.get("wander"), "scale": lk.get("scale", 1), "look": lk})
region = {"region": {"x0": x0, "x1": X + E, "z0": z0, "z1": Z + E}, "chunk": 64, "heightSize": [n, n], "solids": [
    [X - 8 - .7, X - 8 + .7, Z - 5.6 - .25, Z - 5.6 + .25, KH(X - 8, Z - 6) - .3, KH(X - 8, Z - 6) + 2.1]],
    "pools": [], "points": [], "locs": {}, "npcs": npcs, "enemies": [], "etypes": {}, "lamps": [],
    "start": {"x": X + 4, "z": Z + 24}, "dialogue": {}}
json.dump(region, open(os.path.join(out, "region.json"), "w"))
world = {k: meta.get(k, []) for k in ["spawns", "chests", "pickups", "terminals", "benches", "points", "doors"]}
world["door"] = None
json.dump(world, open(os.path.join(out, "world.json"), "w"))
print("khole", n, "x", n, len(npcs), "npcs", len(world["points"]), "points")
