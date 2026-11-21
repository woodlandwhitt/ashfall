// Converts the WebView build's content tables (data.js, gunmodels.js, main.js STATINFO) into data/game.json for
// the Godot build. Functions (quest logic, dialogue conditions) are dropped here; they are ported by hand in GDScript.
import fs from 'fs';
const out = process.argv[2] || '/home/claude/ashfall/godot/data/game.json';
const d = await import('/home/claude/wasteland/src/data.js');
const src = fs.readFileSync('/home/claude/wasteland/src/gunmodels.js', 'utf8');
const gf = src.slice(src.indexOf('export const GUNFIT={'), src.indexOf('};', src.indexOf('export const GUNFIT={')) + 1).replace('export const GUNFIT=', '').replace(/\/\/.*$/gm, '');
const GUNFIT = Function('return ' + gf)();
const main = fs.readFileSync('/home/claude/wasteland/src/main.js', 'utf8');
const si = main.slice(main.indexOf('const STATINFO={') + 15, main.indexOf('};', main.indexOf('const STATINFO={')) + 1);
const STATINFO = Function('return ' + si)();
const plain = o => JSON.parse(JSON.stringify(o));
const game = {items: plain(d.ITEMS), enemies: plain(d.ENEMIES), loot: plain(d.LOOT), perks: plain(d.PERKS), statinfo: STATINFO,
  locs: plain(d.LOCS), vendors: plain(d.VENDORS), gunfit: GUNFIT, lore: plain(d.LORE || {}), recipes: plain(d.RECIPES || {}),
  karma_titles: plain(d.KARMA_TITLES || []), world: d.WORLD};
fs.writeFileSync(out, JSON.stringify(game));
console.log('items', Object.keys(game.items).length, 'enemies', Object.keys(game.enemies).length, 'vendors', Object.keys(game.vendors).length, 'gunfit', Object.keys(GUNFIT).length, 'bytes', JSON.stringify(game).length);
