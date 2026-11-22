# Every line a character speaks, as [who, text]: conversation lines (data/logic.json), companion barks, radio
# broadcasts, the DJ, the intro narration and the fixed lines in the scripts. Output: voice/lines.json
# Usage: python3 lines.py GODOT_DIR OUT.json
import json, re, sys, os
G = sys.argv[1]
L = json.load(open(os.path.join(G, "data/logic.json")))
out = []
seen = set()
def add(who, t):
    t = t.strip()
    if len(t) < 2 or (who, t) in seen:
        return
    seen.add((who, t))
    out.append([who, t])
def strs(o, acc):
    if isinstance(o, dict):
        if o.get("type") == "Literal" and isinstance(o.get("value"), str):
            acc.append(o["value"])
        for v in o.values():
            strs(v, acc)
    elif isinstance(o, list):
        for v in o:
            strs(v, acc)
sent = re.compile(r"[A-Za-z].*\s.*[.!?…\"')\]]$")
for who, d in L["dialogue"].items():
    for nk, n in d.get("nodes", {}).items():
        s = n.get("say")
        if isinstance(s, str):
            add(who, s)
        elif s is not None:
            acc = []
            strs(s, acc)
            for x in acc:
                if len(x) >= 24 and sent.match(x.strip()):
                    add(who, x)
for who, c in L.get("companions", {}).items():
    for k, v in c.get("barks", {}).items():
        for x in ([v] if isinstance(v, str) else v):
            add(who, x)
for k, r in L.get("radio", {}).items():
    if "t" in r:
        add("overseer", r["t"])
        paras = [x for x in r["t"].split("\n\n") if not x.strip().startswith(">")]
        if paras:
            add("radio", paras[-1])
def consts(path, name):
    src = open(os.path.join(G, path)).read()
    m = re.search(r"const %s := \[(.*?)\]\n" % name, src, re.S)
    return re.findall(r'"((?:[^"\\]|\\.)*)"', m.group(1)) if m else []
for x in consts("scripts/main.gd", "DJ"):
    add("radio", x)
for x in consts("scripts/screens.gd", "SLIDES"):
    add("narrator", x)
# literal speak("...", "who") calls
for f in os.listdir(os.path.join(G, "scripts")):
    if f.endswith(".gd"):
        for m in re.finditer(r'speak\("((?:[^"\\]|\\.)+)",\s*"(\w+)"\)', open(os.path.join(G, "scripts", f)).read()):
            add(m.group(2), m.group(1))
add("overseer", "Attention, Haven 12. Water rationing is now in effect. {name}, report to the Overseer's office immediately.")
for who in ["overseer", "pell", "nan", "cass", "brannock", "wick", "halloran", "sheriff", "ines", "vex", "finch", "maren"]:
    for x in ["Enough! Enough. I give up.", "Stop! Please, I yield.", "You win. Put it down. Please."]:
        add(who, x)
json.dump(out, open(sys.argv[2], "w"), indent=0)
from collections import Counter
print(len(out), "lines,", sum(len(t) for _, t in out), "characters,", len(set(w for w, _ in out)), "voices")
print(Counter(w for w, _ in out).most_common(8))
