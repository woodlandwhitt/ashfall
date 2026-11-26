// Dumps the WebView world's explosive barrels (red drums with the yellow hazard plate) for the Godot build.
import {createRequire} from 'module';import fs from 'fs';
const {chromium}=createRequire('/home/claude/wasteland/x.js')('playwright');
const b=await chromium.launch({args:['--use-gl=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist','--allow-file-access-from-files']});
const p=await b.newPage({viewport:{width:320,height:180}});
await p.addInitScript(()=>{try{localStorage.setItem('ashfall_meridian_v3_set',JSON.stringify({gfx:0}))}catch(e){}});
await p.goto('file:///home/claude/wasteland/dist/index.html',{timeout:300000});await p.waitForFunction(()=>window.__game,{timeout:300000});
const r=await p.evaluate(()=>__game.barrels.map(t=>({id:t.id,x:+t.x.toFixed(2),z:+t.z.toFixed(2),y:+t.mesh.position.y.toFixed(2)})));
console.log(JSON.stringify(r));await b.close();
