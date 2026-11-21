// Turns the WebView build's quest, dialogue and world-object logic into data for the Godot build (data/logic.json).
// Plain values stay JSON; every function (a stage's done-check, a dialogue line that depends on karma, an option's
// effect...) is parsed with acorn and stored as a trimmed ESTree syntax tree under {"$fn": ...}. The Godot side runs
// those trees with a small interpreter (scripts/jsvm.gd) against a G object that mirrors the original game API, so
// quests and conversations are data, not hand-ported code.
import fs from 'fs';
import {createRequire} from 'module';
const acorn = createRequire(import.meta.url)('acorn');
const OUT = process.argv[2] || '/home/claude/ashfall/godot/data/logic.json';
const SRC = '/home/claude/wasteland/src/';
const D = await import(SRC + 'data.js');
const dataSrc = fs.readFileSync(SRC + 'data.js', 'utf8');
const mainSrc = fs.readFileSync(SRC + 'main.js', 'utf8');

const DROP = new Set(['start', 'end', 'raw', 'sourceType', 'loc', 'range', 'generator', 'async', 'directive']);
function trim(n) {
  if (Array.isArray(n)) return n.map(trim);
  if (!n || typeof n !== 'object') return n;
  const o = {};
  for (const k in n) {
    if (DROP.has(k)) continue;
    if (k === 'expression' && typeof n[k] === 'boolean') continue;
    if (k === 'computed' && !n[k]) continue;
    if (k === 'optional' && !n[k]) continue;
    if (k === 'shorthand' || k === 'method' || k === 'kind' && n.type === 'Property') continue;
    if (k === 'regex' || k === 'bigint') continue;
    o[k] = trim(n[k]);
  }
  return o;
}
const parseFn = src => {
  const ast = acorn.parseExpressionAt('(' + src + ')', 0, {ecmaVersion: 'latest'});
  return trim(ast);
};

// free identifiers, so anything the interpreter must supply is visible at conversion time
const GLOBALS = new Set(['G', 'Math', 'Object', 'Array', 'JSON', 'String', 'Number', 'undefined', 'Infinity', 'NaN', 'isNaN',
  'QUESTS', 'DIALOGUE', 'LOCS', 'CAMPS', 'ITEMS', 'ENEMIES', 'COMPANIONS', 'BOUNTIES', 'CUR', 'VOICES', 'karmaTitle', 'LORE', 'VENDORS', 'RECIPES',
  'flags', 'P', 'msg', 'sfx', 'checkQuests', 'banner', 'speak', 'KHM', 'syncLostThings', 'cellTravel', 'cellName', 'spat', 'pick',
  'addXp', 'maxHp', 'radMul', 'dev', 'setTimeout', 'killed', 'stageText', 'console', 'VAULT_O', 'VSPOT', 'KARMA_TITLES']);
const helpers = {};
const free = new Map();
function scan(n, bound) {
  if (Array.isArray(n)) { for (const c of n) scan(c, bound); return; }
  if (!n || typeof n !== 'object') return;
  switch (n.type) {
    case 'ArrowFunctionExpression': case 'FunctionExpression': {
      const b = new Set(bound);
      const bind = p => { if (!p) return; if (p.type === 'Identifier') b.add(p.name); else if (p.type === 'AssignmentPattern') bind(p.left); else if (p.type === 'ObjectPattern') p.properties.forEach(q => bind(q.value || q.argument)); else if (p.type === 'ArrayPattern') p.elements.forEach(bind); else if (p.type === 'RestElement') bind(p.argument); };
      n.params.forEach(bind);
      // hoist every declaration in the body (good enough for these short functions)
      const hoist = m => { if (Array.isArray(m)) return m.forEach(hoist); if (!m || typeof m !== 'object') return; if (m.type === 'VariableDeclarator') bind(m.id); if (m.type !== 'ArrowFunctionExpression' && m.type !== 'FunctionExpression') for (const k in m) hoist(m[k]); };
      hoist(n.body);
      n.params.forEach(p => p.type === 'AssignmentPattern' && scan(p.right, b));
      scan(n.body, b);
      return;
    }
    case 'Identifier':
      if (!bound.has(n.name) && !GLOBALS.has(n.name)) free.set(n.name, (free.get(n.name) || 0) + 1);
      return;
    case 'MemberExpression':
      scan(n.object, bound);
      if (n.computed) scan(n.property, bound);
      return;
    case 'Property':
      if (n.computed) scan(n.key, bound);
      scan(n.value, bound);
      return;
    case 'CatchClause':
      { const b = new Set(bound); if (n.param) b.add(n.param.name); scan(n.body, b); return; }
  }
  for (const k in n) if (k !== 'type') scan(n[k], bound);
}

let nfn = 0;
function enc(v, path) {
  if (typeof v === 'function') {
    let src = v.toString();
    // methods written as name(){...} inside object literals
    if (!/^(\(|function|async|[A-Za-z_$][\w$]*\s*=>)/.test(src)) src = 'function ' + src;
    let ast;
    try { ast = parseFn(src); } catch (e) { console.log('PARSE FAIL', path, e.message, src.slice(0, 120)); return null; }
    scan(ast, new Set());
    nfn++;
    return {$fn: ast};
  }
  if (Array.isArray(v)) return v.map((x, i) => enc(x, path + '[' + i + ']'));
  if (v && typeof v === 'object') {
    const o = {};
    for (const k in v) o[k] = enc(v[k], path + '.' + k);
    return o;
  }
  return v;
}

// module-level helpers the functions call (done(G,q), fin(G,q) ...): pull their source out of data.js
const top = acorn.parse(dataSrc, {ecmaVersion: 'latest', sourceType: 'module'});
const declared = {};
(function walk(n) {
  if (Array.isArray(n)) return n.forEach(walk);
  if (!n || typeof n !== 'object') return;
  if (n.type === 'VariableDeclarator' && n.id.type === 'Identifier' && n.init && /Function/.test(n.init.type))
    (declared[n.id.name] ||= []).push(dataSrc.slice(n.init.start, n.init.end));
  for (const k in n) if (k !== 'type') walk(n[k]);
})(top);

// the world's quest objects (QUEST_POINTS in main.js): an object literal of {label, use} functions
const qpStart = mainSrc.indexOf('const QUEST_POINTS={') + 'const QUEST_POINTS='.length;
let depth = 0, qpEnd = qpStart;
for (let i = qpStart; i < mainSrc.length; i++) {
  const c = mainSrc[i];
  if (c === '{') depth++;
  else if (c === '}') { depth--; if (depth === 0) { qpEnd = i + 1; break; } }
  else if (c === "'" || c === '"' || c === '`') { const q = c; i++; while (i < mainSrc.length && mainSrc[i] !== q) { if (mainSrc[i] === '\\') i++; i++; } }
}
const QP = Function('return ' + mainSrc.slice(qpStart, qpEnd).replace(/\b(G|sfx|msg|flags|P)\b/g, '$&'))();
for (const e of 'bcde') QP['echo' + e] = QP.echoa;

// closures the converter cannot see through: the Oskar parcel options wrap their original effect in a() at load time
{
  const i = dataSrc.indexOf("N('oskar','parcelcaught',");
  const objSrc = dataSrc.slice(dataSrc.indexOf('{', i), dataSrc.indexOf('});', i) + 1);
  const orig = Function('return ' + objSrc)();
  D.DIALOGUE.oskar.nodes.parcelcaught.opts.forEach((o, k) => {
    o.act = Function('return G=>{G.take(\'opened_parcel\',1);(' + orig.opts[k].act.toString() + ')(G)}')();
  });
}
// enemy hit volumes (entities.js imports three.js, so read the table from its source)
const entSrc = fs.readFileSync(SRC + 'entities.js', 'utf8');
const hbStart = entSrc.indexOf('export const HITBOX=') + 'export const HITBOX='.length;
const HITBOX = Function('return ' + entSrc.slice(hbStart, entSrc.indexOf('};', hbStart) + 1))();
const out = {
  quests: enc(D.QUESTS, 'QUESTS'),
  dialogue: enc(D.DIALOGUE, 'DIALOGUE'),
  points: enc(QP, 'QUEST_POINTS'),
  companions: enc(D.COMPANIONS || {}, 'COMPANIONS'),
  endings: enc(D.ENDINGS || {}, 'ENDINGS'),
  epilogue: enc(D.EPILOGUE || [], 'EPILOGUE'),
  radio: enc(D.RADIO || {}, 'RADIO'),
  bounties: D.BOUNTIES || [],
  vendors: enc(D.VENDORS || {}, 'VENDORS'),
  recipes: enc(D.RECIPES || [], 'RECIPES'),
  camps: D.CAMPS || {},
  voices: D.VOICES || {},
  settler_lines: D.SETTLER_LINES || [],
  helpers: {},
  consts: {HITBOX, PERKS: D.PERKS, AP_COST: D.AP_COST, EVENTS: D.EVENTS, VAULT_O: D.VAULT_O, VSPOT: D.VSPOT, LOCS: D.LOCS, CAMPS: D.CAMPS, BOUNTIES: D.BOUNTIES, VOICES: D.VOICES, CUR: D.CUR, KARMA_TITLES: D.KARMA_TITLES},
};
// resolve free identifiers that are data.js helpers
for (let pass = 0; pass < 3; pass++) {
  for (const [name] of [...free]) {
    if (declared[name] && !out.helpers[name]) {
      if (declared[name].length > 1 && new Set(declared[name]).size > 1) console.log('HELPER with several definitions', name, declared[name]);
      out.helpers[name] = {$fn: parseFn(declared[name][0])};
      scan(out.helpers[name].$fn, new Set());
      nfn++;
    }
  }
}
const unresolved = [...free].filter(([n]) => !out.helpers[n]);
fs.writeFileSync(OUT, JSON.stringify(out));
console.log('quests', Object.keys(out.quests).length, 'dialogue', Object.keys(out.dialogue).length, 'points', Object.keys(out.points).length,
  'functions', nfn, 'helpers', Object.keys(out.helpers).join(','), 'bytes', fs.statSync(OUT).size);
if (unresolved.length) console.log('UNRESOLVED', unresolved.map(([n, c]) => n + '×' + c).join(' '));
