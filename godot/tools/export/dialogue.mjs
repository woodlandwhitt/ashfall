// Adds the townsfolk's dialogue from the WebView build's data.js to region.json, in the slice's format. Options that
// depend on quests the slice doesn't have are dropped; Cass keeps her hound job (it is a slice quest).
import fs from 'fs';
const out = process.argv[2] || '/home/claude/ashfall/godot/data/region.json';
const {DIALOGUE} = await import('/home/claude/wasteland/src/data.js');
const R = JSON.parse(fs.readFileSync(out, 'utf8'));
const dlg = {};
for (const n of R.npcs) {
  const D = DIALOGUE[n.id];
  if (!D || n.id === 'sheriff') continue;
  const nodes = {};
  for (const k in D.nodes) {
    const nd = D.nodes[k];
    if (typeof nd.say !== 'string') continue;
    const opts = [];
    for (const o of nd.opts || []) {
      if (typeof o.t !== 'string') continue;
      if (o.if || o.act) continue;
      if (o.go && (!D.nodes[o.go] || typeof D.nodes[o.go].say !== 'string')) continue;
      opts.push(o.go ? {t: o.t, go: o.go} : {t: o.t});
    }
    nodes[k] = {say: nd.say, opts};
  }
  let entry = typeof D.entry === 'string' ? D.entry : 'hub';
  if (!nodes[entry]) entry = Object.keys(nodes)[0];
  if (!entry) continue;
  if (n.id === 'cass' && nodes.hub) {
    nodes.hub.opts.unshift(
      {t: 'Heard you have a hound problem.', if: [['unknown', 'hounds']], go: 'hounds', act: [['start', 'hounds']]},
      {t: 'The hounds are dead.', if: [['stage', 'hounds', 1]], go: 'houndsdone', act: [['complete', 'hounds']]});
    if (nodes.houndsdone) nodes.houndsdone.say = nodes.houndsdone.say.replace(/Here, take Pop.*$/, 'Drinks are on me for a week.');
  }
  for (const k in nodes) if (!nodes[k].opts.some(o => !o.if)) nodes[k].opts.push({t: 'Goodbye.'});
  dlg[n.id] = {name: D.name, entry: [['else', entry]], nodes};
}
R.dialogue = dlg;
fs.writeFileSync(out, JSON.stringify(R));
console.log('dialogue for', Object.keys(dlg).join(', '));

// looks: sex, shirt colour, skin colour and headwear for each townsperson, from entities.js LOOKS
{
  const src = fs.readFileSync('/home/claude/wasteland/src/entities.js', 'utf8');
  const R2 = JSON.parse(fs.readFileSync(out, 'utf8'));
  const hex = v => v ? '#' + Number(v).toString(16).padStart(6, '0') : null;
  for (const n of R2.npcs) {
    const m = src.match(new RegExp('\\b' + n.id + ':\\{([^}]*)\\}'));
    const s = m ? m[1] : '';
    const g = k => { const r = s.match(new RegExp('\\b' + k + ':([^,]+)')); return r ? r[1].replace(/'/g, '') : null; };
    n.look = {fem: g('fem') === 'true' || /^gambler2|^cass|^della/.test(n.id), body: hex(g('body')), skin: hex(g('skin')), hat: g('hat'), coat: hex(g('coat')), bulk: +(g('bulk') || 1)};
  }
  fs.writeFileSync(out, JSON.stringify(R2));
  console.log('looks', R2.npcs.map(n => n.id + (n.look.fem ? '(f)' : '') + (n.look.hat ? '[' + n.look.hat + ']' : '')).join(' '));
}
