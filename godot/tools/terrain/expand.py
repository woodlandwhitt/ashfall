# Grows the valley's map, region by region. The original 1 km square (tools/terrain/base: the WebView build's
# heightfield, ground mask and tint) is kept as it is; new land is added around it from noise and hand-placed
# features, and the mountain wall between them is cut through where a road crosses.
#
# Regions so far:
#   east (build 15)  x 500..1500: the Ashwood. A pass out of Kettle Hollow, the Cinder Gap basin with a trading
#                    town, the burnt and living forest of the Ashwood hills, a dry river canyon, the ruins of Mercy
#                    Falls on a plateau, and the Ashborn tribe's camp in the north-east hills.
#
# Writes data/height.f32, data/mask.png (r road, g dirt, b vegetation tint), data/tint.png, data/flora.png (forest
# density, read by chunks.gd to plant trees) and the new bounds into data/region.json.
# Usage: python3 tools/terrain/expand.py   (from godot/)
import json, numpy as np
from PIL import Image

BASE = "tools/terrain/base/"
X0, X1, Z0, Z1 = -500, 1500, -500, 500          # the whole map after this build
W, D = X1 - X0 + 1, Z1 - Z0 + 1
rng = np.random.default_rng(15)

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

# grid coordinates of every height sample
zz, xx = np.mgrid[Z0:Z1 + 1, X0:X1 + 1].astype(np.float32)

h = np.zeros((D, W), np.float32)
base = np.fromfile(BASE + "height.f32", np.float32).reshape(1001, 1001)
h[:, :1001] = base

# ---------------------------------------------------------------- the east: the Ashwood
E = xx >= 500
n1 = fbm((D, W), 220, 5, 101)
n2 = fbm((D, W), 60, 4, 202)
east = 6.0 + (n1 - 0.45) * 46.0 + (n2 - 0.5) * 7.0
# the Ashwood hills swell in the middle and north
east += 14.0 * np.exp(-(((xx - 1150) / 260) ** 2 + ((zz + 120) / 260) ** 2))

def blob(cx, cz, r, level, soft):
	"""flatten toward a level inside r, easing out over soft metres"""
	global east
	d = np.sqrt((xx - cx) ** 2 + (zz - cz) ** 2)
	w = np.clip(1.0 - (d - r) / soft, 0.0, 1.0)
	w = w * w * (3 - 2 * w)
	east = east * (1 - w) + level * w

SITES = {
	"cinder_gap": (820, -40, 46, 6.0),       # the trading town in the basin
	"mercy_falls": (1120, 300, 60, 22.0),    # ruins on a plateau
	"ashborn": (1310, -330, 36, 24.0),       # the tribe's camp
	"lookout": (990, -230, 18, 30.0),        # a fire lookout on a hill in the forest
	"drivein": (690, 230, 30, 3.0),          # the old drive-in theatre
}
for k, (cx, cz, r, lv) in SITES.items():
	blob(cx, cz, r, lv, 45)

# mesas: flat-topped, steep-sided buttes standing out of the plain, with a ledge partway up
def mesa(cx, cz, rx, rz, top, rot):
	global east
	c, s_ = np.cos(rot), np.sin(rot)
	u = ((xx - cx) * c + (zz - cz) * s_) / rx
	v = (-(xx - cx) * s_ + (zz - cz) * c) / rz
	wob = (fbm((D, W), 30, 2, int(cx + cz) & 1023) - 0.5) * 0.35
	d = np.sqrt(u * u + v * v) + wob
	cliff = np.clip((1.0 - d) / 0.12, 0, 1)
	ledge = np.clip((1.12 - d) / 0.1, 0, 1)
	east = np.maximum(east, east * (1 - ledge) + (east + (top - east) * 0.35) * ledge)
	east = np.maximum(east, east * (1 - cliff) + top * cliff)
MESAS = [(660, -330, 70, 40, 34.0, 0.4), (1390, 130, 55, 85, 40.0, -0.3), (960, 400, 45, 30, 28.0, 1.1), (560, 330, 30, 50, 26.0, 0.2)]
for m in MESAS:
	mesa(*m)

# the dry river: a winding canyon from the north-west to the south-east, 10 m deep
t = np.linspace(0, 1, 1600)
rx = 560 + t * 900 + np.sin(t * 9.0) * 60
rz = -470 + t * 940 + np.sin(t * 5.0 + 1.0) * 90
dmin = np.full((D, W), 1e9, np.float32)
for i in range(0, len(t)):
	dd = np.sqrt((xx - rx[i]) ** 2 + (zz - rz[i]) ** 2)
	dmin = np.minimum(dmin, dd)
canyon = np.clip(1.0 - dmin / 30.0, 0, 1)
east -= (canyon ** 1.2) * 12.0
# its floor: a flat dry bed 8 m wide
bed = np.clip(1.0 - (dmin - 4.0) / 3.0, 0, 1)

# mountains along the new outer edges, like the old map's walls
edge = np.minimum.reduce([X1 - xx, zz - Z0, Z1 - zz])
east += np.clip(1.0 - edge / 70.0, 0, 1) ** 2 * 55.0

# ---------------------------------------------------------------- the seam and the pass
# the old east wall stays; east of it the new land starts at the wall's height and falls away over 70 m
wall = base[:, 1000][:, None] * np.ones((1, W), np.float32)
s = np.clip((xx - 500) / 70.0, 0, 1)
s = s * s * (3 - 2 * s)
east = wall * (1 - s) + east * s
h = np.where(E, east, h)

# the road east: out of Kettle Hollow, over the saddle, down into the Cinder Gap
ROADS = [
	[(400, -72), (450, -70), (500, -66), (560, -60), (640, -55), (720, -48), (800, -42), (840, -40)],
	[(840, -40), (900, -70), (960, -140), (990, -210)],                                  # to the lookout
	[(990, -210), (1060, -260), (1150, -300), (1250, -320), (1300, -330)],               # on to the Ashborn
	[(840, -40), (880, 40), (950, 120), (1030, 210), (1100, 280), (1120, 300)],          # south-east to Mercy Falls
	[(820, -41), (812, -20), (760, 60), (720, 150), (690, 222)],                                    # down to the drive-in
]

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
for pts in ROADS:
	p = polyline(pts)
	# the road's own height: the ground along it, smoothed, and kept low over the old wall (the pass)
	ys = np.array([h[int(round(z - Z0)), int(round(x - X0))] for x, z in p], np.float32)
	if pts is ROADS[0]:
		ys = np.minimum(ys, np.interp(p[:, 0], [400, 470, 560, 640], [0.6, 6.0, 9.0, 7.0]).astype(np.float32))
	k = 25
	ys = np.convolve(np.pad(ys, k, mode="edge"), np.ones(2 * k + 1) / (2 * k + 1), mode="same")[k:-k]
	for (x, z), y in zip(p[::2], ys[::2]):
		x0, x1 = int(max(X0, x - 40)), int(min(X1, x + 40))
		z0, z1 = int(max(Z0, z - 40)), int(min(Z1, z + 40))
		sub = np.sqrt((xx[z0 - Z0:z1 - Z0 + 1, x0 - X0:x1 - X0 + 1] - x) ** 2 + (zz[z0 - Z0:z1 - Z0 + 1, x0 - X0:x1 - X0 + 1] - z) ** 2)
		cur = road_d[z0 - Z0:z1 - Z0 + 1, x0 - X0:x1 - X0 + 1]
		upd = sub < cur
		cur[upd] = sub[upd]
		road_y[z0 - Z0:z1 - Z0 + 1, x0 - X0:x1 - X0 + 1][upd] = y
# the road bed: flat 7 m across, banks blending over 18 m (wider through the pass, where the wall is cut)
def sstep(a, b, v):
	t_ = np.clip((v - a) / (b - a), 0, 1)
	return t_ * t_ * (3 - 2 * t_)
bank = 18.0 + 16.0 * sstep(380, 420, xx) * (1.0 - sstep(600, 690, xx))
w = np.clip(1.0 - (road_d - 3.5) / bank, 0, 1)
w = w * w * (3 - 2 * w)
h = h * (1 - w) + road_y * w
# the old map's ground is never raised (its buildings and props sit on it); only cut down, through the pass
h[:, :1001] = np.minimum(h[:, :1001], base)
# where the old ground was cut down, on a 4 m grid in decimetres: the game drops props and colliders there
lower = base - h[:, :1001]
zs, xs = np.nonzero(lower > 0.3)
cut = {}
if len(xs):
	cx0, cx1 = int(xs.min()) // 4 * 4, int(xs.max()) // 4 * 4 + 4
	cz0, cz1 = int(zs.min()) // 4 * 4, int(zs.max()) // 4 * 4 + 4
	cw, cd = (cx1 - cx0) // 4 + 1, (cz1 - cz0) // 4 + 1
	vals = []
	for j in range(cd):
		for i in range(cw):
			zi, xi = cz0 + j * 4, cx0 + i * 4
			vals.append(int(round(float(lower[min(zi, 1000), min(xi, 1000)]) * 10)))
	cut = {"x0": cx0 + X0, "z0": cz0 + Z0, "step": 4, "w": cw, "d": cd, "v": vals}

def lower_at(x, z):
	xi, zi = int(round(x - X0)), int(round(z - Z0))
	if 0 <= xi <= 1000 and 0 <= zi <= 1000:
		return float(lower[zi, xi])
	return 0.0

# ---------------------------------------------------------------- the ground's look
mask = np.zeros((D, W, 4), np.uint8)
mask[:, :, 3] = 255
mask[:, :1001] = np.array(Image.open(BASE + "mask.png").convert("RGBA"))
road = np.clip(1.0 - (road_d - 3.2) / 1.6, 0, 1)
rough = fbm((D, W), 14, 2, 303)
road = np.where(road > 0, road * (0.75 + rough * 0.4), 0)            # broken, patched asphalt
mask[:, :, 0] = np.maximum(mask[:, :, 0], (np.clip(road, 0, 1) * 255).astype(np.uint8))
dirt = np.zeros((D, W), np.float32)
for k, (cx, cz, r, lv) in SITES.items():
	dirt = np.maximum(dirt, np.clip(1.0 - (np.sqrt((xx - cx) ** 2 + (zz - cz) ** 2) - r * 0.7) / 25.0, 0, 1))
dirt = np.maximum(dirt, np.clip(1.0 - (road_d - 4.0) / 5.0, 0, 1) * 0.55)          # road shoulders
dirt = np.maximum(dirt, canyon * 0.8)
eg = np.where(E, dirt, 0)
mask[:, :, 1] = np.maximum(mask[:, :, 1], (np.clip(eg, 0, 1) * 255).astype(np.uint8))
# the Ashwood: where it's still green
forest = np.clip((fbm((D, W), 90, 3, 404) - 0.36) * 4.5, 0, 1) * np.clip(1.6 * np.exp(-(((xx - 1130) / 420) ** 2 + ((zz + 100) / 430) ** 2)), 0, 1)
forest = np.where(E & (xx > 560), forest, 0)
for k, (cx, cz, r, lv) in SITES.items():
	forest *= np.clip((np.sqrt((xx - cx) ** 2 + (zz - cz) ** 2) - r) / 30.0, 0, 1)
forest *= np.clip((road_d - 7.0) / 6.0, 0, 1)
forest *= np.clip(1.0 - (np.maximum(0, h - 45)) / 15.0, 0, 1)          # not up on the bare peaks
mask[:, :, 2] = np.maximum(mask[:, :, 2], (np.clip(forest * 0.75, 0, 1) * 255).astype(np.uint8))
Image.fromarray(mask, "RGBA").save("data/mask.png")

# flora: forest density (living pines) in r, scattered dead trees in g
flora = np.zeros((D, W, 3), np.uint8)
dead = np.where(E & (xx > 540), np.clip((fbm((D, W), 40, 2, 505) - 0.55) * 2.5, 0, 1) * 0.5, 0)
dead *= np.clip((road_d - 6.0) / 5.0, 0, 1)
for k, (cx, cz, r, lv) in SITES.items():
	dead *= np.clip((np.sqrt((xx - cx) ** 2 + (zz - cz) ** 2) - r) / 20.0, 0, 1)
flora[:, :, 0] = (np.clip(forest, 0, 1) * 255).astype(np.uint8)
flora[:, :, 1] = (np.clip(dead, 0, 1) * 255).astype(np.uint8)
Image.fromarray(flora, "RGB").save("data/flora.png")

tint = np.zeros((D, W, 4), np.uint8)
tint[:, :, 3] = 255
tint[:, :1001] = np.array(Image.open(BASE + "tint.png").convert("RGBA"))
# the old map's colour at its east edge, carried on and varied
edge_col = tint[:, 990:1000, :3].mean(axis=(0, 1))
var = fbm((D, W), 120, 3, 606)
for c in range(3):
	ch = edge_col[c] * (0.88 + var * 0.24)
	ch = ch * (1.0 - forest * 0.12) + (forest * [70, 95, 55][c] * 0.6)
	tint[:, :, c] = np.where(E, np.clip(ch, 0, 255), tint[:, :, c]).astype(np.uint8)
Image.fromarray(tint, "RGBA").save("data/tint.png")

h.astype(np.float32).tofile("data/height.f32")
reg = json.load(open(BASE + "region.json"))
# colliders standing where the ground was cut: lowered with it, or gone if they were great slabs of the old wall
sol = []
for so in reg["solids"]:
	lo = lower_at((so[0] + so[1]) * 0.5, (so[2] + so[3]) * 0.5)
	if lo > 0.5:
		if max(so[1] - so[0], so[3] - so[2]) > 12.0 and lo > 3.0:
			continue
		so = list(so)
		if so[5] < 900:
			so[5] = round(so[5] - lo, 3)
		if so[4] > -900:
			so[4] = round(so[4] - lo, 3)
	sol.append(so)
print("solids", len(reg["solids"]), "->", len(sol))
reg["solids"] = sol
reg["cut"] = cut
reg["region"] = {"x0": X0, "x1": X1, "z0": Z0, "z1": Z1}
reg["heightSize"] = [W, D]
json.dump(reg, open("data/region.json", "w"), separators=(",", ":"))
json.dump({"sites": {k: list(v) for k, v in SITES.items()}, "roads": ROADS}, open("tools/terrain/east_sites.json", "w"), indent=1)
print("map", W, "x", D, "height", float(h.min()), float(h.max()))
