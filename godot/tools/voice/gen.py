# Voices every line in lines.json with Piper (github.com/rhasspy/piper) and its LibriTTS voice (904 real
# speakers, CC BY 4.0): each character gets their own speaker (matched to their sex by pitch), a speaking pace,
# a little variation, and for the strange ones an effect (the radio's band-limited crackle, the Core's machine
# voice, the Hole's choir and echoes). Output: godot/voice/<who>/<key>.ogg, where key is
# md5(lower-case letters and digits of the line, with {name} in place of the player's name)[:16].
# Usage: python3 gen.py lines.json f0.json OUT_DIR [workers]
import json, sys, os, re, hashlib, subprocess, wave, io, multiprocessing as mp
LINES, F0, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
WORKERS = int(sys.argv[4]) if len(sys.argv) > 4 else 2
MODEL = os.path.join(os.path.dirname(os.path.abspath(LINES)), "en-us-libritts-high.onnx")
FEM = {"sheriff", "cass", "ro", "finch", "kess", "overseer", "nan", "tamsin", "sable", "vex", "trader", "della", "gambler2", "ines",
	"hale", "maren", "lark", "teacher", "grower", "rook", "dot", "settler_b", "settler_d", "settler_f", "goosebumps", "tuesday", "mother_hum", "pip"}
# special voices: [pool, which (0 = lowest/most extreme), pace, ffmpeg filter]
SPECIAL = {
	"radio": ["m", 6, 0.9, "highpass=f=320,lowpass=f=3300,acrusher=bits=10:mix=0.25,volume=1.4"],
	"narrator": ["m", 1, 1.1, "aecho=0.8:0.7:40:0.12"],
	"core": ["m", 3, 1.05, "asetrate=22050*0.88,aresample=22050,atempo=1.136,flanger=delay=2:depth=2:speed=0.6,aecho=0.8:0.6:12:0.35,highpass=f=180"],
	"ferryman": ["m", 0, 1.22, "asetrate=22050*0.86,aresample=22050,atempo=1.163,aecho=0.8:0.8:90|180:0.3|0.18"],
	"committee": ["m", 8, 1.0, "chorus=0.6:0.9:45|60|75:0.45|0.38|0.3:0.25|0.4|0.3:2|2.3|1.7,aecho=0.8:0.7:60:0.2"],
	"mother_hum": ["f", 2, 1.3, "asetrate=22050*0.92,aresample=22050,atempo=1.087,aecho=0.8:0.85:120|260:0.35|0.22"],
	"gnorl": ["m", 12, 0.95, "asetrate=22050*1.22,aresample=22050,atempo=0.82,vibrato=f=5:d=0.25"],
	"pip": ["f", 0, 0.95, "asetrate=22050*1.2,aresample=22050,atempo=0.833"],
	"overseer": ["f", 4, 1.05, ""],
}
f0 = {int(k): v for k, v in json.load(open(F0)).items() if v > 0}
male = sorted([s for s, v in f0.items() if v < 140], key=lambda s: f0[s])
female = sorted([s for s, v in f0.items() if v > 175], key=lambda s: -f0[s])

def key(t):
	return hashlib.md5(re.sub(r"[^a-z0-9]", "", t.lower()).encode()).hexdigest()[:16]

def spoken(t):
	t = re.sub(r"\[[^\]]*\]", " ", t)                 # subtitles for the Hole's languages
	t = re.sub(r"\*[^*]*\*", " ", t)                  # stage directions
	t = re.sub(r"\b(LEFT|MIDDLE|RIGHT|ALL HEADS):", " ", t)
	t = "\n".join(l for l in t.split("\n") if not l.strip().startswith(">"))
	t = re.sub(r",\s*\{name\}", "", t)
	t = re.sub(r"^\s*\{name\}[.,!?]\s*", "", t)
	t = t.replace("{name}", "friend").replace("—", ", ").replace("…", "...")
	return re.sub(r"\s+", " ", t).strip()

def profile(who):
	h = int(hashlib.md5(who.encode()).hexdigest(), 16)
	if who in SPECIAL:
		pool, i, pace, fx = SPECIAL[who]
		spk = (male if pool == "m" else female)[i]
		return spk, pace, fx
	pool = female if who in FEM else male
	# the ends of each list are kept for the specials; everyone else spreads across the middle
	spk = pool[4 + h % (len(pool) - 8)]
	pace = 0.92 + (h >> 8) % 17 / 100.0
	return spk, pace, ""

voice = None
def work(job):
	global voice
	who, text = job
	out = os.path.join(OUT, who, key(text) + ".ogg")
	if os.path.exists(out):
		return 0
	t = spoken(text)
	if not re.search(r"[A-Za-z]{2}", t):
		return 0
	from piper import PiperVoice, SynthesisConfig
	if voice is None:
		voice = PiperVoice.load(MODEL)
	spk, pace, fx = profile(who)
	buf = io.BytesIO()
	with wave.open(buf, "wb") as w:
		voice.synthesize_wav(t, w, syn_config=SynthesisConfig(speaker_id=spk, length_scale=pace, noise_scale=0.72, noise_w_scale=0.85))
	os.makedirs(os.path.dirname(out), exist_ok=True)
	af = ("%s," % fx if fx else "") + "loudnorm=I=-17:TP=-1.5:LRA=9"
	p = subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-f", "wav", "-i", "pipe:0", "-af", af, "-ac", "1", "-ar", "22050",
		"-c:a", "libvorbis", "-q:a", "3", out], input=buf.getvalue())
	return 1 if p.returncode == 0 else 0

if __name__ == "__main__":
	jobs = [tuple(x) for x in json.load(open(LINES))]
	jobs.sort(key=lambda j: j[0])
	with mp.Pool(WORKERS) as pool:
		n = 0
		for i, r in enumerate(pool.imap_unordered(work, jobs, chunksize=4)):
			n += r
			if i % 25 == 0:
				print("%d/%d" % (i, len(jobs)), flush=True)
	print("voiced", n)
	json.dump({w: profile(w) for w in sorted(set(j[0] for j in jobs))}, open(os.path.join(OUT, "voices.json"), "w"), indent=1)
