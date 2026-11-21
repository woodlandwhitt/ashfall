// Runs the three.js build of Ashfall in a headless browser and exports one region of its world (static geometry as GLB,
// characters as GLBs with named limbs, heightmap, ground mask, colliders, NPCs, enemies, points) for the Godot slice.
import {createRequire} from 'module';import fs from 'fs';
const {chromium}=createRequire('/home/claude/wasteland/x.js')('playwright');
const OUT=process.argv[2]||'/home/claude/ashfall/godot/data';fs.mkdirSync(OUT+'/chars',{recursive:true});fs.mkdirSync(OUT+'/world/tex',{recursive:true});
const b=await chromium.launch({args:['--use-gl=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist','--allow-file-access-from-files']});
const p=await b.newPage({viewport:{width:640,height:360}});
p.on('pageerror',e=>console.log('PAGEERR',e.message));
await p.exposeFunction('__exists',n=>fs.existsSync(OUT+'/'+n));
await p.exposeFunction('__save',(name,b64,append)=>{const buf=Buffer.from(b64,'base64');if(append)fs.appendFileSync(OUT+'/'+name,buf);else fs.writeFileSync(OUT+'/'+name,buf);return buf.length});
await p.addInitScript(()=>{try{localStorage.setItem('ashfall_meridian_v3_set',JSON.stringify({gfx:3}))}catch(e){}});
await p.goto('file:///home/claude/wasteland/dist/index.html',{timeout:300000});await p.waitForFunction(()=>window.__game,{timeout:300000});
await p.addScriptTag({path:'/home/claude/godot/tools/exp_bundle.js'});
await p.evaluate(()=>{document.getElementById('sNew').click()});await p.waitForTimeout(600);await p.evaluate(()=>document.getElementById('iGo').click());await p.waitForTimeout(1500);
await p.evaluate(()=>{const g=__game;g.dev.fastText=true;g.dev.god=true;g.run('skipvault')});
await p.waitForFunction(()=>__game.flags.leftVault&&__game.mode==='play',{timeout:240000});
await p.evaluate(()=>{const g=__game;g.dev.noai=true;g.P.x=-95;g.P.z=100;g.P.y=g.H(-95,100)});
await p.waitForFunction(()=>__game.scene.children.some(o=>o.userData&&o.userData.props),{timeout:240000});await p.waitForTimeout(3000);
const R=process.env.REGION?Object.fromEntries(['x0','x1','z0','z1'].map((k,i)=>[k,+process.env.REGION.split(',')[i]])):{x0:-260,x1:100,z0:-120,z1:240};
const log=await p.evaluate(async ([R,SKIP])=>{
  const g=__game,W=g.W,T=g.THREE,{GLTFExporter,mergeGeometries}=__EXP,scene=g.scene;const out=[];
  const send=async(name,buf)=>{const u8=new Uint8Array(buf);const CH=1<<22;for(let i=0;i<u8.length;i+=CH){let s='';const part=u8.subarray(i,i+CH);for(let k=0;k<part.length;k+=0x8000)s+=String.fromCharCode.apply(null,part.subarray(k,k+0x8000));await window.__save(name,btoa(s),i>0)}return u8.length};
  const exportGLB=o=>new Promise((res,rej)=>new GLTFExporter().parse(o,res,rej,{binary:true,maxTextureSize:1024,onlyVisible:true}));
  for(const f of W.farCull)f.m.visible=true;
  scene.updateMatrixWorld(true);
  const skip=new Set([W.terrain,W.skyline,g.KHM.group,g.atmos.sky,g.camera]);
  for(const n of g.npcs)skip.add(n.mesh);for(const e of g.enemies)skip.add(e.mesh);for(const n of g.party||[])skip.add(n.mesh);
  scene.traverse(o=>{if(o.geometry===W.grassGeo)skip.add(o)});
  const M=1e9,inR=(x,z,pad=0)=>x>=R.x0-pad&&x<=R.x1+pad&&z>=R.z0-pad&&z<=R.z1+pad;
  // ---- static geometry: every visible mesh in the region, triangles clipped to the region, baked to world space, merged per material
  const byMat=new Map(),matKey=new Map();let tris=0,skipped={shader:0,fx:0};
  // textures: every chunk refers to a tiny stand-in image tagged with the real texture's id; each real texture is
  // written once at the end (share_textures.py swaps the stand-ins for the shared files)
  const texSrc=new Map(),proxies=new Map(),stub=document.createElement('canvas');stub.width=stub.height=4;
  const proxy=t=>{if(!t||!t.image)return null;let id=t.userData.__tid;if(!id){id=t.uuid.slice(0,13);t.userData.__tid=id}
    if(!texSrc.has(id))texSrc.set(id,t);if(!proxies.has(id)){const p=new T.Texture(stub);p.name='tex:'+id;p.wrapS=t.wrapS;p.wrapT=t.wrapT;p.magFilter=t.magFilter;p.minFilter=t.minFilter;p.colorSpace=t.colorSpace;p.flipY=false;p.needsUpdate=true;proxies.set(id,p)}return proxies.get(id)};
  const plainMat=m=>{if(matKey.has(m))return matKey.get(m);let o;m={...m,isMeshBasicMaterial:m.isMeshBasicMaterial,map:proxy(m.map),normalMap:proxy(m.normalMap),emissiveMap:proxy(m.emissiveMap),color:m.color,emissive:m.emissive,__src:m};
    if(m.isMeshBasicMaterial){o=new T.MeshBasicMaterial({color:m.color,map:m.map,vertexColors:m.vertexColors,side:m.side,alphaTest:m.alphaTest,transparent:m.transparent,opacity:m.opacity})}
    else{o=new T.MeshStandardMaterial({color:m.color||0xffffff,map:m.map||null,normalMap:m.normalMap||null,roughness:m.roughness??.8,metalness:m.metalness??0,emissive:m.emissive||0,emissiveIntensity:m.emissiveIntensity??1,emissiveMap:m.emissiveMap||null,
      vertexColors:m.vertexColors,side:m.side,alphaTest:m.alphaTest,transparent:m.transparent&&m.opacity<1,opacity:m.opacity})}
    o.name=(m.name||m.type)+'_'+matKey.size;matKey.set(m.__src,o);return o};
  // every triangle goes to the 64 m chunk its centre is in; small things (props.js 'small' chunks, or meshes under 5 m)
  // are kept apart from buildings so the slice can draw them only up close
  const CHK=64,chunkOf=(x,z)=>Math.floor((x-R.x0)/CHK)+'_'+Math.floor((z-R.z0)/CHK);
  const take=(geo,mw,mat,colMul,small)=>{
    if(!geo.attributes.position)return;const pos=geo.attributes.position,nor=geo.attributes.normal,uv=geo.attributes.uv,col=geo.attributes.color;
    const idx=geo.index?geo.index.array:null,triCount=(idx?idx.length:pos.count)/3;const nm=new T.Matrix3().getNormalMatrix(mw);
    const v=new T.Vector3(),n=new T.Vector3();const groups=geo.groups&&geo.groups.length?geo.groups:[{start:0,count:idx?idx.length:pos.count,materialIndex:0}];
    for(const gr of groups){const m=Array.isArray(mat)?mat[gr.materialIndex]:mat;if(!m||!m.visible)continue;
      if(m.isShaderMaterial||m.isRawShaderMaterial){skipped.shader++;continue}if(m.transparent&&!m.depthWrite){skipped.fx++;continue}if(m.isPointsMaterial||m.isLineBasicMaterial||m.isSpriteMaterial)continue;
      const pm=plainMat(m);const per={};
      for(let t=gr.start/3;t<(gr.start+gr.count)/3&&t<triCount;t++){const ii=[0,1,2].map(k=>idx?idx[t*3+k]:t*3+k);
        let cx=0,cz=0;const ws=ii.map(i=>{v.fromBufferAttribute(pos,i).applyMatrix4(mw);cx+=v.x;cz+=v.z;return v.clone()});if(!inR(cx/3,cz/3,0))continue;
        const key=chunkOf(cx/3,cz/3);const A=per[key]||(per[key]={P:[],N:[],U:[],C:[]});
        for(let k=0;k<3;k++){const i=ii[k];A.P.push(ws[k].x,ws[k].y,ws[k].z);if(nor){n.fromBufferAttribute(nor,i).applyMatrix3(nm).normalize();A.N.push(n.x,n.y,n.z)}
          if(uv)A.U.push(uv.getX(i),uv.getY(i));else A.U.push(0,0);
          if(pm.vertexColors){const c=col?[col.getX(i),col.getY(i),col.getZ(i)]:[1,1,1];A.C.push(c[0]*colMul[0],c[1]*colMul[1],c[2]*colMul[2])}}}
      for(const key in per){const A=per[key];tris+=A.P.length/9;const ng=new T.BufferGeometry();ng.setAttribute('position',new T.Float32BufferAttribute(A.P,3));
        if(A.N.length)ng.setAttribute('normal',new T.Float32BufferAttribute(A.N,3));else ng.computeVertexNormals();ng.setAttribute('uv',new T.Float32BufferAttribute(A.U,2));
        if(pm.vertexColors)ng.setAttribute('color',new T.Float32BufferAttribute(A.C,3));
        const ck=key+'|'+(small?'s':'b')+'|'+pm.uuid;let L=byMat.get(ck);if(!L)byMat.set(ck,L=[pm]);L.push(ng)}}};
  const walk=(o,small)=>{if(skip.has(o)||!o.visible)return;if(o.userData&&o.userData.props==='s')small=true;
    if(o.isInstancedMesh){const im=new T.Matrix4(),mw=new T.Matrix4(),c=new T.Color();o.geometry.computeBoundingBox();const gs=o.geometry.boundingBox.getSize(new T.Vector3()).length();
      for(let i=0;i<o.count;i++){o.getMatrixAt(i,im);mw.multiplyMatrices(o.matrixWorld,im);const e=mw.elements;if(!inR(e[12],e[14],20))continue;
        const sc=Math.hypot(e[0],e[1],e[2]);let cm=[1,1,1];if(o.instanceColor){o.getColorAt(i,c);cm=[c.r,c.g,c.b]}take(o.geometry,mw,o.material,cm,small||gs*sc<5)}}
    else if(o.isMesh&&!o.isSkinnedMesh){o.geometry.computeBoundingBox();const bb=o.geometry.boundingBox.clone().applyMatrix4(o.matrixWorld);
      if(bb.max.x>=R.x0-8&&bb.min.x<=R.x1+8&&bb.max.z>=R.z0-8&&bb.min.z<=R.z1+8)take(o.geometry,o.matrixWorld,o.material,[1,1,1],small||bb.getSize(new T.Vector3()).length()<5)}
    for(const c of o.children)walk(c,small)};
  for(const c of scene.children)walk(c,false);
  // one GLB per chunk: meshes named s_* (small) or b_* (buildings, big props)
  const chunks={};let mi=0;
  for(const [ck,L0] of byMat){const [key,sb]=ck.split('|');const m=L0[0],L=L0.slice(1);let geo=mergeGeometries(L,false);if(!geo)continue;geo=__EXP.mergeVertices(geo,1e-4);
    const mesh=new T.Mesh(geo,m);mesh.name=sb+'_'+(mi++);(chunks[key]||(chunks[key]=new T.Scene())).add(mesh)}
  out.push('static tris '+tris+' meshes '+mi+' chunks '+Object.keys(chunks).length+' skipped '+JSON.stringify(skipped));
  if(!SKIP.includes('world'))for(const [id,t] of texSrc){if(await window.__exists('world/tex/'+id+'.webp'))continue;const img=t.image,c=document.createElement('canvas'),sc=Math.min(1,1024/Math.max(img.width||1,img.height||1));
    c.width=Math.max(1,Math.round((img.width||1)*sc));c.height=Math.max(1,Math.round((img.height||1)*sc));const x=c.getContext('2d');if(t.flipY){x.translate(0,c.height);x.scale(1,-1)}
    try{if(img.data){const id2=new ImageData(new Uint8ClampedArray(img.data.buffer.slice(0)),img.width,img.height);const c0=document.createElement('canvas');c0.width=img.width;c0.height=img.height;c0.getContext('2d').putImageData(id2,0,0);x.drawImage(c0,0,0,c.width,c.height)}else x.drawImage(img,0,0,c.width,c.height)}catch(e){continue}
    const b=await new Promise(r=>c.toBlob(r,'image/webp',.9));await send('world/tex/'+id+'.webp',await b.arrayBuffer())}
  if(!SKIP.includes('world'))for(const key in chunks)if(!await window.__exists('world/c_'+key+'.glb'))out.push('world/c_'+key+'.glb '+await send('world/c_'+key+'.glb',await exportGLB(chunks[key])));
  // ---- characters with named limbs
  const LIMBS=['armL','armR','foreL','foreR','legL','legR','shinL','shinR','head','chest','up','wingL','wingR'];
  const charGLB=async(mesh,file)=>{if(await window.__exists('chars/'+file))return;const u=mesh.userData;const saved={p:mesh.position.clone(),r:mesh.rotation.clone(),s:mesh.scale.clone()};
    const ud=[];mesh.traverse(o=>{ud.push([o,o.userData]);o.userData={}});const wasVis=mesh.visible;mesh.visible=true;const hid=[];for(const c of mesh.children){if(c===u.label||c.userData.blob||c===u.lod||c.isSprite){if(c.visible){hid.push(c);c.visible=false}}else if(!c.visible){c.visible=true;hid.push([c])}}
    for(const k of LIMBS)if(u[k]&&u[k].isObject3D&&u[k]!==mesh)u[k].name=k;
    mesh.position.set(0,0,0);mesh.rotation.set(0,0,0);mesh.updateMatrixWorld(true);
    const n=SKIP.includes('chars')?0:await send('chars/'+file,await exportGLB(mesh));for(const [o,v] of ud)o.userData=v;mesh.visible=wasVis;
    mesh.position.copy(saved.p);mesh.rotation.copy(saved.r);mesh.scale.copy(saved.s);for(const h of hid){if(Array.isArray(h))h[0].visible=false;else h.visible=true}return n};
  const npcs=[];
  for(const n of g.npcs){if(!inR(n.x,n.z)||!n.mesh||g.inCells(n.x,n.z))continue;const id=n.id;await charGLB(n.mesh,'npc_'+id+'.glb');
    npcs.push({id,name:n.name||id,x:n.x,z:n.z,y:g.H(n.x,n.z),rot:n.mesh.rotation.y,wander:n.wander||null,scale:n.mesh.scale.x})}
  out.push('npcs '+npcs.map(n=>n.id).join(','));
  const etypes={},enemies=[];
  for(const e of g.enemies){if(!inR(e.x,e.z)||e.dead||!e.mesh)continue;const t=e.type;if(!etypes[t]){await charGLB(e.mesh,'enemy_'+t+'.glb');const d=e.def||{};etypes[t]={hp:e.maxHp||e.hp,name:d.name||t,dmg:d.dmg,speed:d.speed||d.spd,range:d.range,xp:d.xp,ranged:!!(d.gun||d.ranged),quad:!!e.mesh.userData.quad,scale:e.mesh.scale.x}}
    enemies.push({type:t,x:e.x,z:e.z,y:g.H(e.x,e.z),hostile:e.hostile!==false,id:e.id||null})}
  out.push('enemies '+JSON.stringify(Object.keys(etypes)));
  // ---- terrain: heightmap at 1 m, ground mask (r road, g dirt, b sick-green) and vertex tint, cropped to the region
  const NX=R.x1-R.x0+1,NZ=R.z1-R.z0+1,hm=new Float32Array(NX*NZ);for(let j=0;j<NZ;j++)for(let i=0;i<NX;i++)hm[j*NX+i]=W.H(R.x0+i,R.z0+j);
  out.push('height.f32 '+await send('height.f32',hm.buffer));
  const mt=W.terrainMat.userData.mask.value,MS=mt.image.width,md=mt.image.data,WORLD=1000;
  const cnv=document.createElement('canvas');cnv.width=NX;cnv.height=NZ;const cx=cnv.getContext('2d'),id=cx.createImageData(NX,NZ);
  const tint=null,SEG=0;
  const tc=document.createElement('canvas');tc.width=NX;tc.height=NZ;const tx=tc.getContext('2d'),td=tx.createImageData(NX,NZ);
  for(let j=0;j<NZ;j++)for(let i=0;i<NX;i++){const x=R.x0+i,z=R.z0+j;const mi2=Math.min(MS-1,Math.max(0,Math.round((x/WORLD+.5)*(MS-1)))),mj=Math.min(MS-1,Math.max(0,Math.round((z/WORLD+.5)*(MS-1))));
    const s=(mj*MS+mi2)*4,d=(j*NX+i)*4;id.data[d]=md[s];id.data[d+1]=md[s+1];id.data[d+2]=md[s+2];id.data[d+3]=255;
    td.data[(j*NX+i)*4]=200;td.data[(j*NX+i)*4+1]=200;td.data[(j*NX+i)*4+2]=200;td.data[(j*NX+i)*4+3]=255;if(tint){const ti=Math.round((z/WORLD+.5)*SEG)*(SEG+1)+Math.round((x/WORLD+.5)*SEG);td.data[d]=Math.min(255,tint.getX(ti)*200);td.data[d+1]=Math.min(255,tint.getY(ti)*200);td.data[d+2]=Math.min(255,tint.getZ(ti)*200);td.data[d+3]=255}}
  cx.putImageData(id,0,0);tx.putImageData(td,0,0);
  const png=c=>new Promise(r=>c.toBlob(b=>b.arrayBuffer().then(r),'image/png'));
  out.push('mask.png '+await send('mask.png',await png(cnv)));out.push('tint.png '+await send('tint.png',await png(tc)));
  // ---- everything else the slice needs, as JSON
  const solids=W.solids.filter(s=>!s.off&&s.x1>=R.x0&&s.x0<=R.x1&&s.z1>=R.z0&&s.z0<=R.z1&&s.y1-s.y0>.05).map(s=>[+s.x0.toFixed(3),+s.x1.toFixed(3),+s.z0.toFixed(3),+s.z1.toFixed(3),+s.y0.toFixed(3),+s.y1.toFixed(3)]);
  const pools=W.pools.filter(q=>inR(q.x,q.z)).map(q=>({x:q.x,z:q.z,r:q.r,y:q.y??W.H(q.x,q.z),glow:!!q.glow||q.rad!==false}));
  const points=W.points.filter(q=>inR(q.x,q.z)).map(q=>({id:q.id,x:q.x,z:q.z,y:q.y??null}));
  const locs={};for(const k in g.LOCS){const L=g.LOCS[k];if(inR(L.x,L.z))locs[k]={name:L.name,x:L.x,z:L.z,r:L.r}}
  const lamps=[];scene.traverse(o=>{if(o.isPointLight&&inR(o.getWorldPosition(new T.Vector3()).x,o.getWorldPosition(new T.Vector3()).z)){const w=o.getWorldPosition(new T.Vector3());lamps.push({x:w.x,y:w.y,z:w.z,c:o.color.getHex(),i:o.intensity,d:o.distance})}});
  const meta={region:R,chunk:64,heightSize:[NX,NZ],solids,pools,points,locs,npcs,enemies,etypes,lamps,start:{x:-95,z:108}};
  const js=new TextEncoder().encode(JSON.stringify(meta));out.push('region.json '+await send('region.json',js.buffer)+' solids '+solids.length+' pools '+pools.length+' points '+points.length+' lamps '+lamps.length);
  return out},[R,(process.env.SKIP||'').split(',')]);
console.log(log.join('\n'));await b.close();
