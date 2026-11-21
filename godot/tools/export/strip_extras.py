# Removes three.js userData ("extras") from GLB files in place: the exporter serialises whole objects into it.
import json, struct, sys

def strip(o):
    if isinstance(o, dict):
        o.pop('extras', None)
        for v in o.values():
            strip(v)
    elif isinstance(o, list):
        for v in o:
            strip(v)

for path in sys.argv[1:]:
    b = open(path, 'rb').read()
    if len(b) < 20 or b[:4] != b'glTF':
        continue
    jl = struct.unpack('<I', b[12:16])[0]
    j = json.loads(b[20:20 + jl])
    rest = b[20 + jl:]
    strip(j)
    js = json.dumps(j, separators=(',', ':')).encode()
    js += b' ' * ((4 - len(js) % 4) % 4)
    out = struct.pack('<4sII', b'glTF', 2, 12 + 8 + len(js) + len(rest)) + struct.pack('<I4s', len(js), b'JSON') + js + rest
    open(path, 'wb').write(out)
    print(path.split('/')[-1], len(b), '->', len(out))
