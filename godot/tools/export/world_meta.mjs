// Dumps the WebView world's gameplay objects for the Godot build: every enemy spawn (with the quest that summons or
// requires it), containers (tier, lock, fixed loot, owner), items lying in the world, terminals, workbenches, the
// interaction points quests use, the Meridian core door and townsfolk. Interiors (vault, cells, K-hole) are left out;
// they arrive with godot-7. Output: data/world.json
import {createRequire} from 'module';import fs from 'fs';
const {chromium}=createRequire('/home/claude/wasteland/x.js')('playwright');
const OUT=process.argv[2]||'/home/claude/ashfall/godot/data/world.json';
const AREA=process.env.AREA||'world';   // 'world' = the surface, 'vault' = Haven 12, 'cells' = building interiors, 'khole' = the Hole
const b=await chromium.launch({args:['--use-gl=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist','--allow-file-access-from-files']});
const p=await b.newPage({viewport:{width:320,height:180}});
p.on('pageerror',e=>console.log('PAGEERR',e.message));
await p.addInitScript(()=>{try{localStorage.setItem('ashfall_meridian_v3_set',JSON.stringify({gfx:0}))}catch(e){}});
await p.goto('file:///home/claude/wasteland/dist/index.html',{timeout:300000});await p.waitForFunction(()=>window.__game,{timeout:300000});
const meta=await p.evaluate((AREA)=>{
  const g=__game,W=g.W,H=g.H;
  const inner=AREA==='vault'?(x,z)=>!g.inVault(x,z):AREA==='cells'?(x,z)=>!g.inCells(x,z):AREA==='khole'?(x,z)=>!g.inKhole(x,z):(x,z)=>g.inVault(x,z)||g.inCells(x,z)||g.inKhole(x,z);
  const keep=(o,keys)=>{const r={};for(const k of keys)if(o[k]!==undefined&&o[k]!==null&&typeof o[k]!=='function'&&!(o[k]&&o[k].isObject3D))r[k]=o[k];return r};
  const num=v=>Math.round(v*1000)/1000;
  const pos=o=>({x:num(o.x),z:num(o.z),y:num(o.y!=null?o.y:H(o.x,o.z))});
  const out={};
  out.spawns=W.spawns.filter(s=>!inner(s.x,s.z)).map(s=>({...keep(s,['id','type','neutral','group','persist','req','onStart','den','pen','talk','boss']),...pos(s)}));
  out.chests=W.chests.filter(c=>!inner(c.x,c.z)).map(c=>({...keep(c,['id','tier','fixed','lock','owned','name','plain','rot']),...pos(c)}));
  out.pickups=W.pickups.filter(c=>!inner(c.x,c.z)).map(c=>({...keep(c,['id','item','qty','fixed','glow','col']),...pos(c)}));
  out.terminals=W.terminals.filter(c=>!inner(c.x,c.z)).map(c=>({...keep(c,['id','kind','lore']),...pos(c)}));
  out.benches=W.benches.filter(c=>!inner(c.x,c.z)).map(pos);
  out.points=W.points.filter(c=>!inner(c.x,c.z)).map(c=>({...keep(c,['id','r','pr','prio','echo','cellIn','cellOut','nx','nz']),...pos(c)}));
  out.cells=(W.cells||[]).map((c,i)=>({i,...keep(c,['ox','oz','W2','D2','door','sign','kind','name','w','d','x','z','light'])}));
  out.door=W.door&&!inner(W.door.x,W.door.z)?{...pos(W.door),w:W.door.w,h:W.door.h,d:W.door.d,collider:W.door.collider}:null;
  out.doors=(W.doors||[]).filter(d=>!inner(d.x,d.z)).map(d=>({...keep(d,['id','lock','owned']),...pos(d),col:keep(d.col,['x0','x1','z0','z1','y0','y1'])}));
  out.npcs=g.npcs.filter(n=>!inner(n.x,n.z)).map(n=>({id:n.id,name:n.name,...pos(n),rot:n.rot||0,wander:n.wander||null,vendor:n.vendor||null,look:typeof n.look==='string'?n.look:null}));
  return out;
},AREA);
fs.writeFileSync(OUT,JSON.stringify(meta));
console.log(Object.entries(meta).map(([k,v])=>k+' '+(Array.isArray(v)?v.length:v?1:0)).join(', '));
await b.close();
