// Turns tools/story/story10.mjs into data/story.json: plain values stay JSON, every function becomes a trimmed ESTree
// syntax tree under {"$fn": ...} (the same encoding as tools/export/logic.mjs), for scripts/jsvm.gd to run.
// Usage: node build.mjs [OUT]   (needs acorn: npm i acorn, or NODE_PATH pointing at a node_modules with it)
import fs from 'fs';
import path from 'path';
import {createRequire} from 'module';
import {fileURLToPath} from 'url';
const here = path.dirname(fileURLToPath(import.meta.url));
let acorn;
for (const base of [here, '/home/claude/godot/tools', process.cwd()]) {
  try { acorn = createRequire(path.join(base, 'x.js'))('acorn'); break; } catch (e) {}
}
const OUT = process.argv[2] || path.join(here, '../../data/story.json');
const S = await import(path.join(here, 'story10.mjs'));
const DROP = new Set(['start', 'end', 'raw', 'sourceType', 'loc', 'range', 'generator', 'async', 'directive']);
function trim(n) {
  if (Array.isArray(n)) return n.map(trim);
  if (!n || typeof n !== 'object') return n;
  const o = {};
  for (const k in n) {
    if (DROP.has(k)) continue;
    if (k === 'expression' && typeof n[k] === 'boolean') continue;
    if ((k === 'computed' || k === 'optional') && !n[k]) continue;
    if (k === 'shorthand' || k === 'method' || k === 'kind' && n.type === 'Property') continue;
    if (k === 'regex' || k === 'bigint') continue;
    o[k] = trim(n[k]);
  }
  return o;
}
let nfn = 0;
function enc(v, where) {
  if (typeof v === 'function') {
    let src = v.toString();
    if (!/^(\(|function|async|[A-Za-z_$][\w$]*\s*=>)/.test(src)) src = 'function ' + src;
    nfn++;
    try { return {$fn: trim(acorn.parseExpressionAt('(' + src + ')', 0, {ecmaVersion: 'latest'}))}; }
    catch (e) { console.log('PARSE FAIL', where, e.message); return null; }
  }
  if (Array.isArray(v)) return v.map((x, i) => enc(x, where + '[' + i + ']'));
  if (v && typeof v === 'object') { const o = {}; for (const k in v) o[k] = enc(v[k], where + '.' + k); return o; }
  return v;
}
const out = {};
for (const k of Object.keys(S)) out[k.toLowerCase()] = enc(S[k], k);
fs.writeFileSync(OUT, JSON.stringify(out));
console.log('story:', Object.keys(out).map(k => k + ' ' + (Array.isArray(out[k]) ? out[k].length : Object.keys(out[k]).length)).join(', '), '| functions', nfn, '| bytes', fs.statSync(OUT).size);
