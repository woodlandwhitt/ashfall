# The building interiors ("cells"): each one's room (origin, size, sign) and the street door that leads into it.
# Usage: python3 cells_list.py meta/khole.json data/world.json data/cells.json   (any world_meta.mjs dump has the cells list)
import json, sys
cells = json.load(open(sys.argv[1]))["cells"]
pts = [p for p in json.load(open(sys.argv[2]))["points"] if p["id"] == "cellin"]
N = {"n": [0, -1], "s": [0, 1], "e": [1, 0], "w": [-1, 0]}
out = []
for c in cells:
    p = next((p for p in pts if p.get("cellIn") == c["i"]), None)
    n = N[c["door"]]
    o = {k: c[k] for k in ["i", "ox", "oz", "W2", "D2", "door", "sign", "kind"] if k in c}
    o["out"] = {"x": p["x"], "z": p["z"], "nx": p.get("nx", n[0]), "nz": p.get("nz", n[1])} if p else None
    out.append(o)
json.dump(out, open(sys.argv[3], "w"))
print(len(out), "cells,", sum(1 for o in out if o["out"]), "with a street door")
