// writes data/arsenal.json: build 13's guns, grenades and chems, their fits and grips, and where they turn up
import fs from 'fs';
import {FIT, GRIPS} from './fit.mjs';
const out = {gunfit: FIT, grips: GRIPS, items: {}, drugs: {}, stock: {}, loot: {}, perks: {}, enemies: {}, locs: {}, spawns: []};
let A = {};
try { A = await import('./items.mjs'); } catch (e) { if (!String(e).includes('Cannot find')) throw e; }
for (const k of ['items', 'drugs', 'stock', 'loot', 'perks', 'enemies', 'locs', 'spawns']) if (A[k.toUpperCase()]) out[k] = A[k.toUpperCase()];
const here = new URL('.', import.meta.url).pathname;
fs.writeFileSync(here + '../../data/arsenal.json', JSON.stringify(out));
console.log('arsenal', Object.keys(out.items).length, 'items', Object.keys(out.drugs).length, 'drugs', Object.keys(out.gunfit).length, 'fits');
