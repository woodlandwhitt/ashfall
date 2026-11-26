# Build 16: the northern band, z -1012..-500 across the whole map (2 km by 512 m), which makes the valley three
# times its original size. Reads build 15's map (tools/terrain/base15, written by expand.py) and keeps it as it was,
# except where two new roads climb through the old north wall (Northgate, above KDST Radio, and the Airfield Cut
# above Kestrel Airfield) and one through the Ashwood's northern ridge.
#
# z0 is -1012 rather than -1000 so the chunk grid stays aligned with the old world's 64 m chunk files (8 chunks).
#
#   Stillwater Reservoir (west): a shallow lake in a wide basin, the fishing town of Stillwater on its east shore.
#   Old Meridian (middle): the city the valley was named for, a grid of streets and the shells of its towers.
#   The Glass Bowl (east): a bomb crater, its floor fused to green glass and pooled with glowing water; the Children
#   of the Glass camp on its south rim; Silo 9 in the middle.
#
# Usage: python3 tools/terrain/north.py   (from godot/; after expand.py)
import json, numpy as np
from PIL import Image

B15 = "tools/terrain/base15/"
X0, X1 = -500, 1500
Z0, Z1 = -1012, 500
ZS = -500                    # where build 15's map begins
W, D = X1 - X0 + 1, Z1 - Z0 + 1
NB = ZS - Z0                 # rows of new land (512)

def value_noise(shape, cell, seed):
	r = np.random.default_rng(seed)
	gh, gw = shape[0] // cell + 3, shape[1] // cell + 3
	g = r.random((gh, gw)).astype(np.float32)
	y = np.arange(shape[0]) / cell
	x = np.arange(shape[1]) / cell
	yi, xi = y.astype(int), x.astype(int)
	yf, xf = y - yi, x - xi
	yf = yf * yf * (3 - 2 * yf)
	xf = xf * xf * (3 - 2 * xf)
	a = g[yi][:, xi]; b = g[yi][:, xi + 1]; c = g[yi + 1][:, xi]; d = g[yi + 1][:, xi + 1]
	top = a + (b - a) * xf[None, :]
	bot = c + (d - c) * xf[None, :]
	return top + (bot - top) * yf[:, None]

def fbm(shape, cell, octaves, seed):
	out = np.zeros(shape, np.float32)
	amp, tot = 1.0, 0.0
	for o in range(octaves):
		out += value_noise(shape, max(2, cell >> o), seed + o * 17) * amp
		tot += amp
		amp *= 0.5
	return out / tot

def sstep(a, b, v):
	t = np.clip((v - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)

zz, xx = np.mgrid[Z0:Z1 + 1, X0:X1 + 1].astype(np.float32)
old = np.fromfile(B15 + "height.f32", np.float32).reshape(1001, 2001)
h = np.zeros((D, W), np.float32)
h[NB:] = old
N = zz < ZS

# ---------------------------------------------------------------- the north's own ground
n1 = fbm((D, W), 200, 5, 1601)
n2 = fbm((D, W), 50, 4, 1602)
north = 10.0 + (n1 - 0.45) * 40.0 + (n2 - 0.5) * 6.0

def flatten(cx, cz, rx, rz, level, soft, arr):
	d = np.sqrt(((xx - cx) / rx) ** 2 + ((zz - cz) / rz) ** 2)
	w = np.clip(1.0 - (d - 1.0) * min(rx, rz) / soft, 0, 1)
	w = w * w * (3 - 2 * w)
	return arr * (1 - w) + level * w

# Stillwater: a basin and a shallow lake (water at 2.0; the bed shelves to 0.8 at the middle)
LAKE = (-220.0, -760.0, 125.0, 88.0)
WATER = 2.0
north = flatten(-220, -760, 210, 160, 4.0, 90, north)
ld = np.sqrt(((xx - LAKE[0]) / LAKE[2]) ** 2 + ((zz - LAKE[1]) / LAKE[3]) ** 2)
wob = (fbm((D, W), 24, 2, 1603) - 0.5) * 0.18
bed = WATER - 1.2 * np.clip(1.0 - (ld + wob), 0, 1) ** 0.6 - 0.15
north = np.where(ld + wob < 1.0, bed, np.minimum(north, WATER + 0.4 + (ld + wob - 1.0) * 14.0))
# the city: a broad flat plain
north = flatten(420, -760, 190, 140, 9.0, 70, north)
# the Glass Bowl: a crater with a raised rim and a fused floor
CR = (1150.0, -790.0, 140.0)
cd = np.sqrt((xx - CR[0]) ** 2 + (zz - CR[1]) ** 2) / CR[2]
rim = np.exp(-((cd - 1.0) / 0.18) ** 2) * 12.0
north = north + rim - (1.0 - sstep(0.3, 1.02, cd)) * 22.0
glassfloor = -8.0 + (fbm((D, W), 18, 2, 1604) - 0.5) * 0.8
wfl = 1.0 - sstep(0.4, 0.62, cd)
north = north * (1 - wfl) + np.minimum(north, glassfloor) * wfl
north = flatten(1150, -790, 22, 22, -8.2, 12, north)                # Silo 9's pad
# mountains round the outside
edge = np.minimum.reduce([zz - Z0, xx - X0, X1 - xx])
north += np.clip(1.0 - edge / 70.0, 0, 1) ** 2 * 55.0

# the seam: the old north walls stay; the new land starts at their height and falls away northward over 70 m
wall = old[0][None, :] * np.ones((D, 1), np.float32)
s = sstep(0, 70, ZS - zz)
north = wall * (1 - s) + north * s
h = np.where(N, north, h)

SITES = {
	"stillwater": (-55, -745, 40, None), "old_meridian": (420, -760, 150, None), "spire": (455, -790, 20, None),
	"glass_camp": (1150, -612, 26, None), "silo9": (1150, -790, 22, None), "northgate": (-170, -505, 20, None),
	"airfield_cut": (300, -505, 20, None), "ridge_gap": (1225, -500, 20, None),
}
h = np.where(N, flatten(-50, -748, 34, 40, WATER + 1.4, 18, h), h)
h = np.where(N, flatten(1150, -612, 28, 28, h[1012 - 612, 1150 + 500] if False else 9.0, 25, h), h)

# ---------------------------------------------------------------- roads
ROADS = [
	[(-172, -363), (-172, -420), (-168, -470), (-160, -520), (-140, -580), (-100, -650), (-70, -715), (-55, -745)],      # Northgate
	[(299, -333), (300, -400), (302, -470), (305, -540), (300, -620), (300, -680)],                                    # Airfield Cut
	[(-55, -745), (20, -770), (110, -800), (200, -790), (270, -780)],                                                 # lakeside to the city
	[(570, -770), (680, -790), (800, -795), (900, -790), (1000, -785)],                                                # city to the Bowl's west rim
	[(1250, -320), (1245, -400), (1232, -470), (1222, -540), (1195, -590), (1150, -612)],                              # Ashwood ridge gap
	[(1150, -612), (1150, -660), (1150, -790)],                                                                        # down into the Bowl
	[(1000, -785), (1060, -788), (1150, -790)],
]
# the city's street grid
CITY = []
for gx in range(270, 580, 50):
	CITY.append([(gx, -660), (gx, -870)])
for gz in range(-680, -880, -45):
	CITY.append([(270, gz), (570, gz)])

def polyline(pts, step=2.0):
	out = []
	for (ax, az), (bx, bz) in zip(pts, pts[1:]):
		n = max(2, int(np.hypot(bx - ax, bz - az) / step))
		for k in range(n):
			u = k / n
			out.append((ax + (bx - ax) * u, az + (bz - az) * u))
	out.append(pts[-1])
	return np.array(out, np.float32)

road_d = np.full((D, W), 1e9, np.float32)
road_y = np.zeros((D, W), np.float32)
def lay(pts, profile=None, smooth=25):
	p = polyline(pts)
	ys = np.array([h[int(round(z - Z0)), int(round(x - X0))] for x, z in p], np.float32)
	if profile is not None:
		ys = np.minimum(ys, profile(p))
	k = smooth
	ys = np.convolve(np.pad(ys, k, mode="edge"), np.ones(2 * k + 1) / (2 * k + 1), mode="same")[k:-k]
	for (x, z), y in zip(p[::2], ys[::2]):
		x0, x1 = int(max(X0, x - 40)), int(min(X1, x + 40))
		z0, z1 = int(max(Z0, z - 40)), int(min(Z1, z + 40))
		sl = (slice(z0 - Z0, z1 - Z0 + 1), slice(x0 - X0, x1 - X0 + 1))
		sub = np.sqrt((xx[sl] - x) ** 2 + (zz[sl] - z) ** 2)
		cur = road_d[sl]
		upd = sub < cur
		cur[upd] = sub[upd]
		road_y[sl][upd] = y
# the passes keep low: no road climbs more than it has to over the old walls
lay(ROADS[0], lambda p: np.interp(-p[:, 1], [363, 400, 505, 570, 650], [99, -2.0, 14.0, 7.0, 99]))
lay(ROADS[1], lambda p: np.interp(-p[:, 1], [333, 410, 505, 590, 680], [99, -0.8, 15.0, 13.0, 99]))
for r in ROADS[2:4]:
	lay(r)
lay(ROADS[4], lambda p: np.interp(-p[:, 1], [320, 420, 500, 570, 612], [99, 26.0, 24.0, 16.0, 99]))
for r in ROADS[5:]:
	lay(r, smooth=12)
for r in CITY:
	lay(r, smooth=8)
bank = 18.0 + 14.0 * np.exp(-((zz - ZS) / 60.0) ** 2)          # wider cuts through the walls
w = np.clip(1.0 - (road_d - 3.5) / bank, 0, 1)
w = w * w * (3 - 2 * w)
newh = h * (1 - w) + road_y * w
# the original square is only ever cut down (its buildings and props stand on it); the Ashwood can be reshaped
newh[NB:, :1001] = np.minimum(newh[NB:, :1001], h[NB:, :1001])
lower = h[NB:, :1001] - newh[NB:, :1001]
h = newh

# the Glass Bowl's pools of glowing water, and glass on its floor
rng = np.random.default_rng(16)
POOLS = []
for i in range(9):
	a = rng.random() * np.pi * 2
	r = 25 + rng.random() * 45
	px, pz = CR[0] + np.cos(a) * r, CR[1] + np.sin(a) * r
	if np.hypot(px - 1150, pz - 790 * -1) < 30:
		continue
	POOLS.append({"x": round(float(px), 1), "z": round(float(pz), 1), "r": round(float(5 + rng.random() * 6), 1), "y": float(h[int(pz - Z0), int(px - X0)]), "glow": True})

# ---------------------------------------------------------------- the ground's look
m15 = np.array(Image.open(B15 + "mask.png").convert("RGBA"))
mask = np.zeros((D, W, 4), np.uint8)
mask[:, :, 3] = 255
mask[NB:] = m15
rough = fbm((D, W), 14, 2, 1605)
road = np.clip(1.0 - (road_d - 3.2) / 1.6, 0, 1)
road = np.where(road > 0, road * (0.75 + rough * 0.4), 0)
mask[:, :, 0] = np.maximum(mask[:, :, 0], (np.clip(road, 0, 1) * 255).astype(np.uint8))
dirt = np.clip(1.0 - (road_d - 4.0) / 5.0, 0, 1) * 0.55
for k, (cx, cz, r, _) in SITES.items():
	dirt = np.maximum(dirt, np.clip(1.0 - (np.sqrt((xx - cx) ** 2 + (zz - cz) ** 2) - r * 0.7) / 25.0, 0, 1))
city = np.clip(1.0 - (np.maximum(np.abs(xx - 420) - 150, 0) + np.maximum(np.abs(zz + 765) - 105, 0)) / 20.0, 0, 1)
dirt = np.maximum(dirt, city * 0.7)
shore = np.clip(1.0 - np.abs(ld - 1.0) / 0.12, 0, 1)
dirt = np.maximum(dirt, shore * 0.8)
mask[:, :, 1] = np.where(N | (road_d < 12), np.maximum(mask[:, :, 1], (np.clip(dirt, 0, 1) * 255).astype(np.uint8)), mask[:, :, 1])
sick = np.clip(1.0 - cd / 0.9, 0, 1)
mask[:, :, 2] = np.where(N, np.maximum(mask[:, :, 2], (sick * 230).astype(np.uint8)), mask[:, :, 2])
Image.fromarray(mask, "RGBA").save("data/mask.png")

t15 = np.array(Image.open(B15 + "tint.png").convert("RGBA"))
tint = np.zeros((D, W, 4), np.uint8)
tint[:, :, 3] = 255
tint[NB:] = t15
base_col = t15[0:20, :, :3].mean(axis=(0, 1))
var = fbm((D, W), 120, 3, 1606)
green = np.clip(1.0 - (ld - 1.0) / 1.2, 0, 1) * (ld > 0.98)
for c in range(3):
	ch = base_col[c] * (0.88 + var * 0.24)
	ch = ch * (1 - green * 0.25) + green * [70, 95, 60][c] * 0.5
	ch = ch * (1 - city * 0.2) + city * [128, 124, 118][c] * 0.2
	ch = ch * (1 - sick * 0.5) + sick * [60, 110, 55][c] * 0.5
	tint[:, :, c] = np.where(N, np.clip(ch, 0, 255), tint[:, :, c]).astype(np.uint8)
Image.fromarray(tint, "RGBA").save("data/tint.png")

f15 = np.array(Image.open(B15 + "flora.png").convert("RGB"))
flora = np.zeros((D, W, 3), np.uint8)
flora[NB:] = f15
pines = np.clip((fbm((D, W), 80, 3, 1607) - 0.38) * 4.0, 0, 1)
pines *= np.clip(1.0 - np.maximum(0, ld - 1.0) / 1.6, 0, 1) * (ld > 1.08)         # woods round the lake
pines = np.maximum(pines, np.clip((fbm((D, W), 70, 3, 1608) - 0.5) * 3.0, 0, 1) * np.clip((zz + 940) / -60.0, 0, 1))   # and up the far slopes
dead = np.clip((fbm((D, W), 40, 2, 1609) - 0.55) * 2.5, 0, 1) * 0.6
keep = np.clip((road_d - 7.0) / 6.0, 0, 1) * (1 - city) * np.clip((cd - 1.15) / 0.2, 0, 1)
for k, (cx, cz, r, _) in SITES.items():
	keep *= np.clip((np.sqrt((xx - cx) ** 2 + (zz - cz) ** 2) - r) / 25.0, 0, 1)
keep *= np.clip(1.0 - np.maximum(0, h - 48) / 14.0, 0, 1)
flora[:, :, 0] = np.where(N, (np.clip(pines * keep, 0, 1) * 255).astype(np.uint8), (flora[:, :, 0] * np.clip((road_d - 7.0) / 6.0, 0, 1)).astype(np.uint8))
flora[:, :, 1] = np.where(N, (np.clip(dead * keep, 0, 1) * 255).astype(np.uint8), (flora[:, :, 1] * np.clip((road_d - 6.0) / 5.0, 0, 1)).astype(np.uint8))
Image.fromarray(flora, "RGB").save("data/flora.png")

h.astype(np.float32).tofile("data/height.f32")

# ---------------------------------------------------------------- the region: bounds, the old chunk files' origin, the new cut, solids that stood on it
reg = json.load(open(B15 + "region.json"))
reg["region"] = {"x0": X0, "x1": X1, "z0": Z0, "z1": Z1}
reg["heightSize"] = [W, D]
reg["glb_origin"] = [-500, -500]
zs_, xs_ = np.nonzero(lower > 0.3)
cuts = [reg.pop("cut")] if "cut" in reg else []
def grid_of(lw, xa, xb, za, zb):
	cx0, cx1 = xa // 4 * 4, xb // 4 * 4 + 4
	cz0, cz1 = za // 4 * 4, zb // 4 * 4 + 4
	cw, cdd = (cx1 - cx0) // 4 + 1, (cz1 - cz0) // 4 + 1
	vals = [int(round(float(lw[min(cz0 + j * 4, 1000), min(cx0 + i * 4, 1000)]) * 10)) for j in range(cdd) for i in range(cw)]
	return {"x0": cx0 - 500, "z0": cz0 - 500, "step": 4, "w": cw, "d": cdd, "v": vals}
# one grid per pass (they're far apart)
for lo_x, hi_x in [(0, 500), (500, 1001)]:
	sel = (xs_ >= lo_x) & (xs_ < hi_x)
	if sel.any():
		cuts.append(grid_of(lower, int(xs_[sel].min()), int(xs_[sel].max()), int(zs_[sel].min()), int(zs_[sel].max())))
reg["cuts"] = cuts
sol = []
dropped = 0
for so in reg["solids"]:
	cx, cz = (so[0] + so[1]) * 0.5, (so[2] + so[3]) * 0.5
	xi, zi = int(round(cx + 500)), int(round(cz + 500))
	lo = float(lower[zi, xi]) if 0 <= xi <= 1000 and 0 <= zi <= 1000 else 0.0
	if lo > 0.5:
		if max(so[1] - so[0], so[3] - so[2]) > 12.0 and lo > 3.0:
			dropped += 1
			continue
		so = list(so)
		if so[5] < 900:
			so[5] = round(so[5] - lo, 3)
		if so[4] > -900:
			so[4] = round(so[4] - lo, 3)
	sol.append(so)
reg["solids"] = sol
reg["pools"] = reg["pools"] + POOLS
reg["lake"] = {"x": LAKE[0], "z": LAKE[1], "rx": LAKE[2], "rz": LAKE[3], "y": WATER}
json.dump(reg, open("data/region.json", "w"), separators=(",", ":"))
json.dump({"sites": SITES, "roads": ROADS, "pools": POOLS}, open("tools/terrain/north_sites.json", "w"), indent=1)
print("map", W, "x", D, "h", float(h.min()), float(h.max()), "cuts", len(cuts), "solids dropped", dropped, "pools", len(POOLS))
