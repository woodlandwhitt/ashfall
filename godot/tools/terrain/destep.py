# Build 18: smooth out the stair-steps in the roads that north.py and expand.py cut (build 15/16). Their roads took
# their height from samples every 4 m along the line, each ground cell getting the height of the nearest sample,
# so a road down a slope became a flight of 4 m treads (up to 2 m risers on the way into the Glass Bowl), and the
# banks blended off those treads carried the steps out to the sides. This re-lays every road's surface by
# interpolating the height along the road instead, then blends it back with the same bank, and finishes with a
# light smoothing over any remaining treads. The original square (x < 500, z > -500, where the WebView build's
# buildings and props stand) is left alone except where it was already cut.
#   python3 tools/terrain/destep.py [--report]
import json, sys
import numpy as np
from scipy import ndimage

X0, X1, Z0, Z1 = -500, 1500, -1012, 500
W, D = X1 - X0 + 1, Z1 - Z0 + 1
h = np.fromfile("data/height.f32", dtype=np.float32).reshape(D, W)

def steps(a):
	"""cells at the foot of a riser: a jump of more than 0.45 m between two flat runs, along x or z"""
	out = np.zeros(a.shape, bool)
	for ax in (0, 1):
		d = np.abs(np.diff(a, axis=ax))
		big = d > 0.45
		flat = d < 0.06
		if ax == 0:
			m = big[1:-1, :] & flat[:-2, :] & flat[2:, :]
			out[2:-1, :] |= m
		else:
			m = big[:, 1:-1] & flat[:, :-2] & flat[:, 2:]
			out[:, 2:-1] |= m
	return out

before = steps(h)
old = np.zeros((D, W), bool)
old[-500 - Z0:, :1001] = True            # the original square
print("stair cells before: %d (old square %d)" % (before.sum(), (before & old).sum()))
if "--report" in sys.argv:
	sys.exit()

roads = json.load(open("tools/terrain/north_sites.json"))["roads"] + json.load(open("tools/terrain/east_sites.json"))["roads"]
for gx in range(270, 580, 50):
	roads.append([(gx, -660), (gx, -870)])
for gz in range(-680, -880, -45):
	roads.append([(270, gz), (570, gz)])

xx, zz = np.meshgrid(np.arange(X0, X1 + 1, dtype=np.float32), np.arange(Z0, Z1 + 1, dtype=np.float32))
road_d = np.full((D, W), 1e9, np.float32)
road_y = np.zeros((D, W), np.float32)
for pts in roads:
	pts = [(float(p[0]), float(p[1])) for p in pts]
	# the surface along the line, from the current (stepped) ground smoothed along the road: the steps average out
	dense = []
	for (ax, az), (bx, bz) in zip(pts, pts[1:]):
		n = max(2, int(np.hypot(bx - ax, bz - az) / 1.0))
		for k in range(n):
			u = k / n
			dense.append((ax + (bx - ax) * u, az + (bz - az) * u))
	dense.append(pts[-1])
	dense = np.array(dense, np.float32)
	ys = np.array([h[int(round(z - Z0)), int(round(x - X0))] for x, z in dense], np.float32)
	k = 9
	ys = np.convolve(np.pad(ys, k, mode="edge"), np.ones(2 * k + 1) / (2 * k + 1), mode="same")[k:-k]
	# each cell takes the height of its nearest point on the line, interpolated between samples (1 m apart)
	for i in range(len(dense) - 1):
		ax, az = dense[i]
		bx, bz = dense[i + 1]
		x0, x1 = int(max(X0, min(ax, bx) - 36)), int(min(X1, max(ax, bx) + 36))
		z0, z1 = int(max(Z0, min(az, bz) - 36)), int(min(Z1, max(az, bz) + 36))
		sl = (slice(z0 - Z0, z1 - Z0 + 1), slice(x0 - X0, x1 - X0 + 1))
		px, pz = xx[sl], zz[sl]
		vx, vz = bx - ax, bz - az
		L2 = max(1e-6, vx * vx + vz * vz)
		t = np.clip(((px - ax) * vx + (pz - az) * vz) / L2, 0, 1)
		dx, dz = px - (ax + vx * t), pz - (az + vz * t)
		dd = np.sqrt(dx * dx + dz * dz)
		cur = road_d[sl]
		upd = dd < cur
		cur[upd] = dd[upd]
		road_y[sl][upd] = (ys[i] + (ys[i + 1] - ys[i]) * t)[upd]

# the road surface and its banks, blended over the ground as before but from a smooth surface
bank = 18.0 + 14.0 * np.exp(-((zz + 500.0) / 60.0) ** 2)
w = np.clip(1.0 - (road_d - 3.5) / bank, 0, 1)
w = w * w * (3 - 2 * w)
newh = h * (1 - w) + road_y * w
# then a light smoothing wherever there were treads left (and their surroundings), to round off what remains
st = steps(newh) | before
near = ndimage.binary_dilation(st, iterations=6)
soft = ndimage.gaussian_filter(newh, 2.2)
wn = ndimage.gaussian_filter(near.astype(np.float32), 2.0)
newh = newh * (1 - wn) + soft * wn
# only where there were treads: everywhere else the ground stays exactly as it was
zone = ndimage.gaussian_filter(ndimage.binary_dilation(before, iterations=14).astype(np.float32), 4.0)
newh = h * (1 - zone) + newh * zone
# the original square: its buildings and props sit on its ground, so wherever the ground here comes down, a cut grid
# (region.cuts, read by chunks.cut_at) lets the props there come down with it; it's never raised by more than 60 cm (only in the pass cuts)
R = json.load(open("data/region.json"))
def cut_existing(x, z):
	lo = 0.0
	for C in R.get("cuts", []):
		st = float(C["step"]); fx = (x - C["x0"]) / st; fz = (z - C["z0"]) / st
		if fx < 0 or fz < 0 or fx > C["w"] - 1 or fz > C["d"] - 1:
			continue
		ix = min(int(fx), C["w"] - 2); iz = min(int(fz), C["d"] - 2); tx = fx - ix; tz = fz - iz
		v = C["v"]; w_ = C["w"]
		a = v[iz * w_ + ix] * (1 - tx) + v[iz * w_ + ix + 1] * tx
		b = v[(iz + 1) * w_ + ix] * (1 - tx) + v[(iz + 1) * w_ + ix + 1] * tx
		lo = max(lo, (a * (1 - tz) + b * tz) / 10.0)
	return lo
# (here the road isn't re-laid, which would eat into the pass walls; the treads are only smoothed off)
soft_old = ndimage.gaussian_filter(h, 2.4)
w_old = ndimage.gaussian_filter(ndimage.binary_dilation(before, iterations=5).astype(np.float32), 1.5)
newh = np.where(old, h * (1 - w_old) + soft_old * w_old, newh)
newh = np.where(old, np.minimum(newh, h + 0.6), newh)
low = np.where(old, np.maximum(0.0, h - newh), 0.0)
R["cuts"] = [C for C in R.get("cuts", []) if not C.get("destep")]
lab, n = ndimage.label(ndimage.binary_dilation(low > 0.02, iterations=4))
for k in range(1, n + 1):
	zi, xi = np.where(lab == k)
	x0 = int(X0 + xi.min()) // 4 * 4 - 4; x1 = int(X0 + xi.max()) + 8
	z0 = int(Z0 + zi.min()) // 4 * 4 - 4; z1 = int(Z0 + zi.max()) + 8
	gw = (x1 - x0) // 4 + 1; gd = (z1 - z0) // 4 + 1
	v = []
	for gz in range(gd):
		for gx in range(gw):
			x = x0 + gx * 4; z = z0 + gz * 4
			ix = min(max(x - X0, 0), W - 1); iz = min(max(z - Z0, 0), D - 1)
			v.append(int(round((cut_existing(x, z) + float(low[iz, ix])) * 10.0)))
	R["cuts"].append({"x0": x0, "z0": z0, "step": 4, "w": gw, "d": gd, "v": v, "destep": True})
	print("cut grid at %d,%d %dx%d, deepest %.2f m" % (x0, z0, gw, gd, low[zi, xi].max()))
after = steps(newh)
print("stair cells after: %d (old square %d); max change %.2f m, mean change on roads %.2f m" % (after.sum(), (after & old).sum(), np.abs(newh - h).max(), np.abs(newh - h)[w > 0.5].mean()))
if '--dry' in sys.argv:
	sys.exit()
newh.astype(np.float32).tofile("data/height.f32")
json.dump(R, open("data/region.json", "w"), separators=(",", ":"))
