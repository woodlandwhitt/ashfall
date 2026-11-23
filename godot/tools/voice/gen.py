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
	"hale", "maren", "lark", "teacher", "grower", "rook", "dot", "settler_b", "settler_d", "settler_f", "goosebumps", "tuesday", "mother_hum", "pip",
	"odile", "juno", "saba", "ira", "hester", "hester2", "cg_guard2", "ab_guard2", "ab_folk2", "cg_folk1"}
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

# how a line is said: each line is read for its mood from its words and punctuation, and voiced to match
# (angry lines faster, louder and a touch higher; frightened ones quick and shaky; sad ones slower, lower and softer;
# glad ones brighter). [length scale x, noise scale, ffmpeg filter]
MOODS = {
	"angry": [0.9, 0.86, "asetrate=22050*1.03,aresample=22050,atempo=0.971,volume=1.3"],
	"afraid": [0.87, 0.9, "asetrate=22050*1.045,aresample=22050,atempo=0.957,vibrato=f=6.5:d=0.1"],
	"sad": [1.13, 0.6, "asetrate=22050*0.965,aresample=22050,atempo=1.036,volume=0.85"],
	"glad": [0.95, 0.8, "asetrate=22050*1.035,aresample=22050,atempo=0.966"],
	"wry": [1.0, 0.78, ""],
	"calm": [1.0, 0.72, ""],
}
CUES = {
	"angry": r"\b(damn|hell|get out|back off|kill|shut up|idiot|fool|bastard|how dare|enough|liar|thief|rot|burn|move it|touch that|last warning|scum)\b",
	"afraid": r"\b(please|help me|help us|don'?t hurt|scared|afraid|run\b|they'?re coming|oh god|no,? no|hide|monsters?|screaming)\b",
	"sad": r"\b(sorry|died|dead|gone|lost|miss (him|her|them)|grave|buried|never came back|alone|tears|cried|mourn|funeral|last of)\b",
	"glad": r"\b(ha(ha)*|great|wonderful|thank you|thanks|glad|welcome|good to see|cheers|lovely|brilliant|hooray|finally!|beautiful)\b",
	"wry": r"\b(of course|naturally|sure you|right\.|figures|funny|joke)\b",
}
def mood(t):
	low = t.lower()
	score = {m: len(re.findall(rx, low)) for m, rx in CUES.items()}
	score["angry"] += t.count("!") * 0.6 if score["glad"] == 0 else 0
	score["sad"] += t.count("...") * 0.5
	best = max(score, key=lambda m: score[m])
	return best if score[best] >= 1 else "calm"

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

# the same person under two ids (someone who moves house mid-story) keeps one voice
ALIAS = {"hester2": "hester", "dex2": "dex"}

def profile(who):
	who = ALIAS.get(who, who)
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
	md = MOODS[mood(t)] if who not in ("radio", "core", "committee", "ferryman", "narrator") else MOODS["calm"]
	buf = io.BytesIO()
	with wave.open(buf, "wb") as w:
		voice.synthesize_wav(t, w, syn_config=SynthesisConfig(speaker_id=spk, length_scale=pace * md[0], noise_scale=md[1], noise_w_scale=0.85))
	os.makedirs(os.path.dirname(out), exist_ok=True)
	chain = [f for f in (md[2], fx) if f]
	af = (",".join(chain) + "," if chain else "") + ("loudnorm=I=-17:TP=-1.5:LRA=9" if md is not MOODS["sad"] else "loudnorm=I=-19:TP=-1.5:LRA=9")
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
