# Points every chunk GLB at the shared texture files instead of embedded images, so a texture used by many chunks
# is stored, imported and loaded once.
#  - textures tagged by the exporter (extras.tex = id) use tex/<id>.webp, written once by export_region.mjs
#  - any other embedded image is moved out to tex/<sha1>.<ext>
import hashlib, json, os, struct, sys

root = sys.argv[1]               # .../data/world
tex = os.path.join(root, 'tex')
os.makedirs(tex, exist_ok=True)
seen = set()
before = after = 0

def ext_of(data):
    if data[:4] == b'\x89PNG':
        return 'png'
    if data[8:12] == b'WEBP':
        return 'webp'
    return 'jpg'

for f in sorted(os.listdir(root)):
    if not f.endswith('.glb'):
        continue
    path = os.path.join(root, f)
    b = open(path, 'rb').read()
    before += len(b)
    jl = struct.unpack('<I', b[12:16])[0]
    j = json.loads(b[20:20 + jl])
    if len(b) > 20 + jl:
        bl = struct.unpack('<I', b[20 + jl:24 + jl])[0]
        binc = b[28 + jl:28 + jl + bl]
    else:
        binc = b''
    views = j.get('bufferViews', [])
    images = j.get('images', [])
    new_images, img_index = [], {}
    def image_for(uri):
        if uri not in img_index:
            img_index[uri] = len(new_images)
            new_images.append({'uri': uri})
        return img_index[uri]
    for t in j.get('textures', []):
        tid = (t.get('extras') or {}).get('tex') or (t.get('name', '')[4:] if t.get('name', '').startswith('tex:') else None)
        src = t.get('source')
        if tid:
            t['source'] = image_for('tex/' + tid + '.webp')
        elif src is not None:
            im = images[src]
            if 'bufferView' in im:
                v = views[im['bufferView']]
                data = binc[v.get('byteOffset', 0):v.get('byteOffset', 0) + v['byteLength']]
                name = hashlib.sha1(data).hexdigest()[:16] + '.' + ext_of(data)
                if name not in seen:
                    seen.add(name)
                    open(os.path.join(tex, name), 'wb').write(data)
                t['source'] = image_for('tex/' + name)
            elif 'uri' in im:
                t['source'] = image_for(im['uri'])
        t.pop('extras', None)
    drop = {im['bufferView'] for im in images if 'bufferView' in im}
    j['images'] = new_images
    if not new_images:
        j.pop('images', None)
    remap, newbin, newviews = {}, bytearray(), []
    for i, v in enumerate(views):
        if i in drop:
            continue
        data = binc[v.get('byteOffset', 0):v.get('byteOffset', 0) + v['byteLength']]
        while len(newbin) % 4:
            newbin.append(0)
        nv = dict(v)
        nv['byteOffset'] = len(newbin)
        newbin += data
        remap[i] = len(newviews)
        newviews.append(nv)
    while len(newbin) % 4:
        newbin.append(0)
    j['bufferViews'] = newviews
    for a in j.get('accessors', []):
        if 'bufferView' in a:
            a['bufferView'] = remap[a['bufferView']]
    j['buffers'] = [{'byteLength': len(newbin)}]
    js = json.dumps(j, separators=(',', ':')).encode()
    js += b' ' * ((4 - len(js) % 4) % 4)
    out = struct.pack('<4sII', b'glTF', 2, 28 + len(js) + len(newbin)) + struct.pack('<I4s', len(js), b'JSON') + js + struct.pack('<I4s', len(newbin), b'BIN\x00') + bytes(newbin)
    open(path, 'wb').write(out)
    after += len(out)
size = sum(os.path.getsize(os.path.join(tex, t)) for t in os.listdir(tex) if not t.endswith('.import'))
print('chunks %.0f MB -> %.0f MB, shared textures %d files %.1f MB' % (before / 1e6, after / 1e6, len(os.listdir(tex)), size / 1e6))
