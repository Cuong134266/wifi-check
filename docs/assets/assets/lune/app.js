'use strict';
const $=s=>document.querySelector(s), reduce=matchMedia('(prefers-reduced-motion: reduce)').matches;
const catalog=window.TAROT_CARDS;
const data=catalog.map(c=>[c.name,c.vn,c.keywords,c.overview,c.question,c.action,c.symbol]);
let shuffleMotion=null;
let state='intro', cards=[], picked=null,hover=-1,drag=null,used=new Set(),session=0,soundOn=false,audioCtx,animId,last=0,active=true;
let journal=[];try{journal=JSON.parse(localStorage.getItem('lune-journal')||'[]');if(!Array.isArray(journal))journal=[];journal=journal.filter(x=>Number.isInteger(x.id)&&data[x.id]&&typeof x.date==='string').slice(0,60)}catch{}
const roman=['0','I','II','III','IV','V','VI','VII','VIII','IX','X','XI','XII','XIII','XIV','XV','XVI','XVII','XVIII','XIX','XX','XXI'];
function star(x,y,r=6){return `<path d="M${x} ${y-r}Q${x+1} ${y-1} ${x+r} ${y}Q${x+1} ${y+1} ${x} ${y+r}Q${x-1} ${y+1} ${x-r} ${y}Q${x-1} ${y-1} ${x} ${y-r}Z"/>`}
function backArt(){return `<svg viewBox="0 0 180 294" xmlns="http://www.w3.org/2000/svg"><defs><radialGradient id="b"><stop stop-color="#26364c"/><stop offset="1" stop-color="#101a2c"/></radialGradient><pattern id="p" width="12" height="12" patternUnits="userSpaceOnUse"><path d="M0 6L6 0 12 6 6 12Z" fill="none" stroke="#c9b583" stroke-opacity=".075" stroke-width=".6"/></pattern></defs><rect width="180" height="294" fill="url(#b)"/><g fill="none" stroke="#c4a779" stroke-width=".65"><rect x="7" y="7" width="166" height="280" rx="5"/><rect x="12" y="12" width="156" height="270" rx="3"/><path d="M23 68Q90 -18 157 68V226Q90 312 23 226Z"/><path d="M30 75Q90 -3 150 75V219Q90 295 30 219Z"/><ellipse cx="90" cy="147" rx="50" ry="75"/><ellipse cx="90" cy="147" rx="39" ry="65" stroke-opacity=".4"/><path d="M90 56V80M90 214V238M33 147H48M132 147H147M50 93L60 107M120 187L130 201M50 201L60 187M120 107L130 93"/><circle cx="90" cy="147" r="31"/><path d="M94 117a30 30 0 1 0 0 60 34 34 0 0 1 0-60Z" fill="#c5ac7c" fill-opacity=".78"/><path d="M90 19L98 30 90 41 82 30ZM90 253L98 264 90 275 82 264Z"/><path d="M17 40V18H39M141 18H163V40M17 254V276H39M141 276H163V254"/></g><g fill="#cfb886">${star(105,141,9)}${star(113,161,3)}${star(94,91,4)}${star(89,203,4)}${star(42,50,3)}${star(138,244,3)}<circle cx="118" cy="128" r="1"/><circle cx="65" cy="181" r="1"/></g><text x="90" y="251" font-size="6" letter-spacing="4" text-anchor="middle" fill="#c3aa80" font-family="Georgia">LUNE</text></svg>`}
function frontArt(id){const d=data[id],type=d[6];let symbol='';
if(type==='moon')symbol='<path d="M106 59a39 39 0 1 0 0 78A43 43 0 0 1 106 59Z" fill="#d8bc7f"/>'+star(121,84,10)+star(131,114,4);
if(type==='sun')symbol='<circle cx="90" cy="102" r="28" fill="#d8bc7f"/>'+Array.from({length:16},(_,i)=>`<path transform="rotate(${i*22.5} 90 102)" d="M90 67V52"/>`).join('')+'<path d="M78 100q5 -5 10 0M94 100q5 -5 10 0M84 113q6 5 12 0" stroke="#535342"/>';
if(type==='star')symbol=star(90,93,33)+[[-39,-20],[39,-20],[-43,24],[43,24],[0,-48]].map(([x,y])=>star(90+x,93+y,5)).join('')+'<path d="M90 136V173M76 141L68 166M104 141L112 166"/>';
if(type==='tree')symbol='<path d="M90 204V110M90 158Q50 147 49 104M90 146Q128 134 133 91M90 126Q67 100 73 70M90 115Q102 88 99 61" stroke-width="3"/><g fill="#9caa83" fill-opacity=".6"><ellipse cx="56" cy="101" rx="21" ry="30"/><ellipse cx="117" cy="97" rx="22" ry="34"/><ellipse cx="85" cy="72" rx="23" ry="32"/></g>';
if(type==='mountain')symbol='<circle cx="90" cy="81" r="24" fill="#d1b078"/><path d="M25 192L70 102 93 146 117 119 159 192Z" fill="#79867b"/><path d="M70 102L55 134 69 129 82 136ZM117 119L105 142 119 136 128 145" fill="#d7c6a1"/>';
if(type==='temple')symbol='<path d="M50 196V101L90 64 130 101V196M45 101H135M43 194H137M57 115H123M65 115V186M115 115V186M80 186V146Q90 127 100 146V186" stroke-width="2" fill="none"/><circle cx="90" cy="92" r="9"/>';
if(type==='lantern')symbol='<path d="M90 55V74M71 87L79 75H101L109 87V143L99 157H81L71 143ZM71 89H109M71 142H109M90 157V177" fill="none" stroke-width="2"/><path d="M88 137C68 122 93 112 88 100C112 123 101 131 88 137" fill="#e5c98a"/><circle cx="90" cy="117" r="50" stroke-opacity=".2"/>';
if(type==='wheel')symbol='<circle cx="90" cy="121" r="48" fill="none"/><circle cx="90" cy="121" r="38" fill="none"/>'+Array.from({length:8},(_,i)=>`<path transform="rotate(${i*45} 90 121)" d="M90 73V109M85 78L90 85 95 78"/>`).join('')+star(90,121,15);
if(type==='scales')symbol='<path d="M90 68V189M68 190H112M48 94H132M58 95L40 133H76ZM122 95L104 133H140Z" fill="none" stroke-width="2"/><path d="M40 133Q58 158 76 133M104 133Q122 158 140 133" fill="#b6a77e"/>'+star(90,65,8);
if(type==='vessel')symbol='<path d="M53 91H86L82 126Q69 143 57 126ZM94 134H127L123 169Q110 186 98 169ZM69 135V155M58 156H80M110 178V198M99 199H121M82 113Q108 109 110 141" fill="none" stroke-width="2"/>'+star(106,75,15);
if(type==='wands')symbol='<path d="M72 178L108 65M70 169L83 160M99 91L111 84" stroke-width="6" fill="none"/>'+star(90,55,9);
if(type==='cups')symbol='<path d="M54 75H126L117 122Q90 150 63 122ZM90 139V174M67 178H113M55 84H40Q37 116 64 119M125 84H140Q143 116 116 119" fill="none" stroke-width="3"/>';
if(type==='swords')symbol='<path d="M90 52L100 80 94 153H86L80 80ZM64 153H116M90 153V185M81 187H99" fill="none" stroke-width="3"/>';
if(type==='pentacles')symbol='<circle cx="90" cy="119" r="48" fill="none" stroke-width="2"/><path d="M90 77L115 153 51 106H129L65 153Z" fill="none" stroke-width="2"/>';
return `<svg viewBox="0 0 180 294" xmlns="http://www.w3.org/2000/svg"><rect width="180" height="294" fill="#d3c39d"/><rect x="8" y="8" width="164" height="278" rx="3" fill="none" stroke="#85744f" stroke-width=".6"/><path d="M17 219V82a73 73 0 0 1 146 0V219Z" fill="#1b2e3b"/><clipPath id="clip${id}"><path d="M18 219V82a72 72 0 0 1 144 0V219Z"/></clipPath><g clip-path="url(#clip${id})"><g fill="#c2a779" stroke="#c2a779" stroke-width=".8">${symbol}</g><path d="M14 201Q50 175 90 199T169 193V224H14Z" fill="#596e65"/><path d="M14 215Q57 195 96 211T171 207" fill="none" stroke="#b8b391" stroke-width=".7"/><g fill="#d2ba80">${star(37,153,3)}${star(143,56,3)}${star(31,76,2)}</g><path d="M35 219Q36 193 29 181M35 211Q47 203 47 193M145 219Q145 192 151 178M145 207Q134 198 134 189" stroke="#c2b38c" fill="none"/></g><text x="90" y="237" text-anchor="middle" fill="#75603d" font-size="8" letter-spacing="3" font-family="Georgia">${catalog[id].label}</text><text x="90" y="258" text-anchor="middle" fill="#2a3838" font-size="${d[0].length>16?10:12}" letter-spacing="1" font-family="Georgia">${d[0].toUpperCase()}</text><path d="M62 273H79M101 273H118" stroke="#8f7955" stroke-width=".6"/><g fill="#8f7955">${star(90,273,3)}</g></svg>`}
function frontFace(id){
  const fileName=catalog[id].name.trim().replace(/\s+/g,'_');
  const src='../tarot_thumbs/'+fileName+'.jpg?v=3';
  return `<img class="tarot-art" src="${src}" alt="" draggable="false"><div class="holo-foil"></div><div class="holo-glare"></div><div class="holo-grain"></div><div class="holo-rim"></div>`;
}
function holoPoint(e,c){
  if(state!=='result'||c!==picked)return;
  const r=c.el.parentElement.getBoundingClientRect(),d=LuneMotion.dimensions(innerWidth);
  const x=Math.max(-1,Math.min(1,(e.clientX-r.x-c.p.x)/(d.w*c.p.s/2)));
  const y=Math.max(-1,Math.min(1,(e.clientY-r.y-c.p.y)/(d.h*c.p.s/2)));
  c.holo.tx=-y*12;c.holo.ty=x*15;c.holo.x=50+x*38;c.holo.y=50+y*38;c.holo.targetPower=.42;
}
function resetHolo(c){c.holo.tx=0;c.holo.ty=0;c.holo.x=50;c.holo.y=50;c.holo.targetPower=.08;}
const pause=ms=>new Promise(r=>setTimeout(r,reduce?Math.min(ms,80):ms));
function tone(kind='paper'){if(!soundOn)return;try{audioCtx??=new(window.AudioContext||window.webkitAudioContext)();audioCtx.resume();const t=audioCtx.currentTime,g=audioCtx.createGain();g.connect(audioCtx.destination);if(kind==='paper'){const b=audioCtx.createBuffer(1,audioCtx.sampleRate*.09,audioCtx.sampleRate),arr=b.getChannelData(0);for(let i=0;i<arr.length;i++)arr[i]=(Math.random()*2-1)*.14;const n=audioCtx.createBufferSource(),f=audioCtx.createBiquadFilter();f.type='highpass';f.frequency.value=2000;n.buffer=b;n.connect(f);f.connect(g);g.gain.setValueAtTime(.3,t);g.gain.exponentialRampToValueAtTime(.001,t+.09);n.start()}else{[440,659.25,880].forEach((hz,i)=>{const o=audioCtx.createOscillator(),v=audioCtx.createGain();o.type='sine';o.frequency.value=hz;o.connect(v);v.connect(g);v.gain.setValueAtTime(0,t+i*.08);v.gain.linearRampToValueAtTime(.028,t+i*.08+.04);v.gain.exponentialRampToValueAtTime(.001,t+1.7);o.start(t+i*.08);o.stop(t+1.8)})}}catch{}}
function setStep(n){[1,2,3].forEach(i=>$('#step'+i).classList.toggle('current',i===n))}
function mobile(){return innerWidth<=760}
function dockZoom(){const configured=parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--embed-fan-zoom'));return Number.isFinite(configured)?configured:LuneMotion.dockZoom(innerWidth,cards.length)}
function fanZoom(){return document.body.classList.contains('fan-docked')?dockZoom():1}
function setFanDock(on){const before=$('#deck').getBoundingClientRect(),z1=fanZoom();document.documentElement.style.setProperty('--fan-zoom',dockZoom());document.body.classList.toggle('fan-docked',on);const after=$('#deck').getBoundingClientRect(),z2=fanZoom();cards.forEach(c=>{c.p.x=(before.x+c.p.x*z1-after.x)/z2;c.p.y=(before.y+c.p.y*z1-after.y)/z2;c.p.s*=z1/z2;Object.assign(c.t,c.p);for(const k in c.v)c.v[k]=0;});}
function fanPose(i){return LuneMotion.fan(i,cards.length,innerWidth)}
function target(c,p){Object.assign(c.t,p)}
function makeDeck(){
  $('#deck').replaceChildren(); cards=[];
  const ids=data.map((_,i)=>i).filter(i=>!used.has(i));
  for(let i=ids.length-1;i>0;i--){const a=new Uint32Array(1);crypto.getRandomValues(a);const j=a[0]%(i+1);[ids[i],ids[j]]=[ids[j],ids[i]]}
  ids.slice(0,72).forEach((id,i)=>{
    const el=document.createElement('button');el.className='card';el.tabIndex=-1;
    el.setAttribute('aria-label','Chọn lá bài úp '+(i+1));
    el.innerHTML=`<div class="card-inner"><div class="face back" aria-hidden="true">${backArt()}</div><div class="face shuffle-back" aria-hidden="true">${backArt()}</div><div class="face front" aria-hidden="true">${frontFace(id)}</div></div>`;
    const p={x:0,y:55,z:0,rz:-8,ry:12,rx:8,s:.85,o:0};
    const c={el,id,holo:{tx:0,ty:0,rx:0,ry:0,vx:0,vy:0,x:50,y:50,mx:50,my:50,power:.08,targetPower:.08},p:{...p},t:{...p},v:Object.fromEntries(Object.keys(p).map(k=>[k,0]))};
    el.addEventListener('pointermove',e=>{if(e.pointerType==='mouse'||el.hasPointerCapture(e.pointerId))holoPoint(e,c)});
    el.addEventListener('pointerdown',e=>{if(state==='result'&&c===picked){el.setPointerCapture(e.pointerId);holoPoint(e,c);e.preventDefault()}});
    el.addEventListener('pointerup',e=>{if(el.hasPointerCapture(e.pointerId))el.releasePointerCapture(e.pointerId);resetHolo(c)});
    el.addEventListener('pointercancel',()=>resetHolo(c));el.addEventListener('pointerleave',()=>resetHolo(c));el.addEventListener('blur',()=>resetHolo(c));
    el.addEventListener('keydown',e=>{if(state==='result'&&c===picked&&['ArrowLeft','ArrowRight','ArrowUp','ArrowDown','Escape'].includes(e.key)){e.preventDefault();if(e.key==='Escape')resetHolo(c);else{c.holo.ty=Math.max(-15,Math.min(15,c.holo.ty+(e.key==='ArrowLeft'?-4:e.key==='ArrowRight'?4:0)));c.holo.tx=Math.max(-12,Math.min(12,c.holo.tx+(e.key==='ArrowUp'?4:e.key==='ArrowDown'?-4:0)));c.holo.x=50+c.holo.ty/15*38;c.holo.y=50-c.holo.tx/12*38;c.holo.targetPower=.42}}});
    el.style.zIndex=i+1;cards.push(c);$('#deck').append(el);
    el.addEventListener('click',e=>{if(state==='chosen'&&c===picked)flip();else if(state==='fan'&&e.detail===0)selectCard(i)});
    el.addEventListener('focus',()=>{if(state==='fan'&&!drag){hover=i;refreshFan()}});
    el.addEventListener('blur',()=>{if(!drag&&state==='fan'){hover=-1;refreshFan()}});
  });
}
function refreshFan(){
  if(state!=='fan')return;
  document.documentElement.style.setProperty('--fan-zoom',dockZoom());
  cards.forEach((c,i)=>{
    if(drag&&drag.i===i)return;
    const p=LuneMotion.wave(i,cards.length,innerWidth,hover);
    if(i===hover)p.s=1.12;
    target(c,p);c.el.classList.toggle('hover',i===hover);
    c.el.style.zIndex=i+1;c.el.tabIndex=0;
    c.el.style.pointerEvents='none';
  });
}
async function start(newSpread=true){if(shuffleMotion){shuffleMotion.resolve();shuffleMotion=null;}$('#stage').classList.remove('shuffling','shuffle-impact');const run=++session;state='intro';picked=null;hover=-1;drag=null;$('#revealStage').hidden=true;$('#revealDeck').replaceChildren();if(newSpread)used.clear();if(used.size>=data.length)used.clear();document.body.classList.remove('result','fan-docked');$('#stage').classList.remove('fan-ready');$('#intro').inert=false;$('#reading').hidden=true;$('#deeper').hidden=true;$('#more').setAttribute('aria-expanded','false');$('#more').innerHTML='Khám phá sâu hơn <span>↗</span>';$('#topic').disabled=false;$('#shuffle').disabled=true;$('#hint').textContent='Bộ bài đang thức giấc…';setStep(1);makeDeck();await pause(100);if(run!==session)return;cards.forEach((c,i)=>target(c,{x:i*.13,y:-i*.27,z:0,rz:0,ry:0,rx:0,s:1,o:1}));await pause(1300);if(run!==session)return;await shuffleDeck(run)}
function shuffleSound(type,pan=0,gain=1){
  if(!soundOn)return;
  try{
    audioCtx??=new(window.AudioContext||window.webkitAudioContext)();audioCtx.resume();
    const ctx=audioCtx,t=ctx.currentTime,short=type==='riffle',tap=type==='tap';
    const duration=short?.045:tap?.13:type==='tension'?.15:.25;
    const buffer=ctx.createBuffer(1,Math.ceil(ctx.sampleRate*duration),ctx.sampleRate),d=buffer.getChannelData(0);
    for(let i=0;i<d.length;i++)d[i]=(Math.random()*2-1);
    const src=ctx.createBufferSource(),filter=ctx.createBiquadFilter(),volume=ctx.createGain();
    src.buffer=buffer;filter.type='bandpass';filter.Q.value=short?.7:.5;
    filter.frequency.setValueAtTime(tap?380:short?3400:1200,t);
    filter.frequency.exponentialRampToValueAtTime(tap?140:short?1800:4000,t+duration);
    const peak=(short?.1:tap?.19:.075)*gain;
    volume.gain.setValueAtTime(.0001,t);volume.gain.linearRampToValueAtTime(peak,t+.004);volume.gain.exponentialRampToValueAtTime(.0001,t+duration);
    src.connect(filter);filter.connect(volume);
    if(ctx.createStereoPanner){const stereo=ctx.createStereoPanner();stereo.pan.value=pan;volume.connect(stereo);stereo.connect(ctx.destination)}else volume.connect(ctx.destination);
    src.start(t);src.stop(t+duration);
    if(tap){const o=ctx.createOscillator(),g=ctx.createGain();o.type='sine';o.frequency.setValueAtTime(125,t);o.frequency.exponentialRampToValueAtTime(65,t+.09);g.gain.setValueAtTime(.06,t);g.gain.exponentialRampToValueAtTime(.0001,t+.11);o.connect(g);g.connect(ctx.destination);o.start(t);o.stop(t+.12)}
  }catch{}
}
async function shuffleDeck(run=session){
  if(state==='shuffle')return;
  state='shuffle';hover=-1;cancelDrag();setFanDock(false);$('#stage').classList.remove('fan-ready');$('#stage').classList.add('shuffling');
  $('#shuffle').disabled=true;$('#shuffle').style.visibility='hidden';$('#hint').textContent='Giữ một ý niệm. Bộ bài sẽ tự xòe sau một vòng tráo.';
  cards.forEach((c,i)=>{c.el.classList.remove('hover');c.el.tabIndex=-1;c.el.style.pointerEvents='none';c.el.style.zIndex=i+1;});
  if(!reduce){
    const plan=LuneMotion.shufflePlan(cards.length,innerWidth,cards.map(c=>({...c.p})));
    await new Promise(resolve=>{shuffleMotion={plan,start:performance.now(),nextEvent:0,resolve,run}});
  }
  if(run!==session)return;
  const shuffled=data.map((_,i)=>i).filter(i=>!used.has(i));
  for(let j=shuffled.length-1;j>0;j--){const a=new Uint32Array(1);crypto.getRandomValues(a);const k=a[0]%(j+1);[shuffled[j],shuffled[k]]=[shuffled[k],shuffled[j]]}
  cards.forEach((c,i)=>{c.id=shuffled[i];c.el.querySelector('.front').innerHTML=frontFace(c.id);c.el.style.zIndex=i+1;target(c,fanPose(i));});
  cards.forEach(c=>{c.p.rx=0;c.t.rx=0;c.p.ry=0;c.t.ry=0});
  $('#stage').classList.remove('shuffling','shuffle-impact');
  $('#shuffle').style.visibility='';$('#shuffle').innerHTML='<span>⤨</span> Xáo bài lần nữa';
  state='fan';setFanDock(true);setStep(2);$('#stage').classList.add('fan-ready');refreshFan();$('#shuffle').disabled=false;
  $('#hint').textContent='';
}
function stagePoint(e){const r=$('#deck').getBoundingClientRect();return{x:(e.clientX-r.x)/fanZoom(),y:(e.clientY-r.y)/fanZoom()}}
function hitCard(e){
 const p=stagePoint(e),d=LuneMotion.dimensions(innerWidth);
 const base=LuneMotion.hit(p.x,p.y,cards.length,innerWidth);
 if(base>=0)return base;
 // Only use animated geometry outside the stable baseline fan: moving leaves cannot fight over a stationary pointer.
 for(let i=cards.length-1;i>=0;i--)if(LuneMotion.contains(p.x,p.y,cards[i].p,d.w,d.h,2))return i;
 return -1;
}
function startDrag(e,i){
  if(state!=='fan'||drag||e.button!==0||i<0)return;
  const c=cards[i];hover=i;refreshFan();
  drag={i,x:e.clientX,y:e.clientY,px:e.clientX,py:e.clientY,base:{...c.p},max:0,pointer:e.pointerId};
  $('#stage').setPointerCapture(e.pointerId);$('#stage').classList.add('dragging');c.el.classList.add('dragging');
  e.preventDefault();
}
function moveDrag(e){
  if(!drag||e.pointerId!==drag.pointer)return;
  const zoom=fanZoom(),dx=(e.clientX-drag.x)/zoom,dy=(e.clientY-drag.y)/zoom,c=cards[drag.i];drag.max=Math.max(drag.max,Math.hypot(e.clientX-drag.x,e.clientY-drag.y));
  const d=LuneMotion.dimensions(innerWidth),h=$('#stage').clientHeight;
  const x=Math.max(-innerWidth/2+d.w*.65,Math.min(innerWidth/2-d.w*.65,drag.base.x+dx));
  const y=document.body.classList.contains('fan-docked')?Math.max(-innerHeight/fanZoom()+d.h*.55,Math.min(40,drag.base.y+dy)):Math.max(-h/2+d.h*.56,Math.min(h/2-d.h*.56,drag.base.y+dy));
  target(c,{x,y,z:0,rx:Math.max(-8,Math.min(8,(e.clientY-drag.py)*.5)),ry:Math.max(-8,Math.min(8,(e.clientX-drag.px)*.5)),rz:drag.base.rz+Math.max(-10,Math.min(10,dx*.035)),s:1.04});
  c.el.style.setProperty('--shine',`${50+dx*.3}%`);drag.px=e.clientX;drag.py=e.clientY;
}
function releasePointer(d){if($('#stage').hasPointerCapture(d.pointer))$('#stage').releasePointerCapture(d.pointer);$('#stage').classList.remove('dragging');cards[d.i].el.classList.remove('dragging')}
function endDrag(e){
  if(!drag||e.pointerId!==drag.pointer)return;
  const d=drag;drag=null;releasePointer(d);
  const dist=Math.hypot(e.clientX-d.x,e.clientY-d.y);
  if(d.max<8||dist>(mobile()?60:85))selectCard(d.i);
  else{hover=-1;refreshFan();$('#hint').textContent='Kéo lá bài ra xa hơn một chút, hoặc chạm để chọn.'}
}
function cancelDrag(){if(!drag)return;const d=drag;drag=null;releasePointer(d);hover=-1;refreshFan()}
function revealScale(){const d=LuneMotion.dimensions(innerWidth);return Math.max(.8,Math.min(mobile()?2.05:1.9,(innerHeight-100)/d.h,(innerWidth-48)/d.w))}
async function selectCard(i){
  if(state!=='fan')return;
  const run=session;state='drawing';picked=cards[i];hover=-1;
  $('#stage').classList.remove('fan-ready');$('#shuffle').disabled=true;$('#topic').disabled=true;
  $('#hint').textContent='Lá bài của bạn đang được hé lộ.';
  cards.forEach(c=>{c.el.tabIndex=-1;c.el.classList.remove('hover');c.el.style.pointerEvents='none'});
  const oldOrigin=$('#deck').getBoundingClientRect(),oldZoom=fanZoom();
  $('#revealStage').hidden=false;
  $('#revealDeck').append(picked.el);
  const newOrigin=$('#revealDeck').getBoundingClientRect();
  picked.p.x=oldOrigin.x+picked.p.x*oldZoom-newOrigin.x;picked.p.y=oldOrigin.y+picked.p.y*oldZoom-newOrigin.y;picked.p.s*=oldZoom;document.body.classList.remove('fan-docked');
  picked.el.style.zIndex=150;
  // Reparenting preserves screen coordinates, then the card travels to viewport center.
  target(picked,{x:0,y:0,z:0,rz:0,ry:-7,rx:0,s:revealScale(),o:1});
  cards.forEach((c,j)=>{if(c!==picked){c.el.setAttribute('aria-hidden','true');target(c,{x:0,y:45-j*.25,z:0,rz:0,rx:0,ry:0,s:.85,o:0})}});
  window.scrollTo({top:0,behavior:reduce?'instant':'smooth'});
  tone();await pause(550);if(run!==session)return;
  state='chosen';await flip();
}
async function flip(){
  if(state!=='chosen')return;
  state='flipping';const run=session;
  target(picked,{z:0,s:revealScale()*.96,rx:4,ry:0});
  await pause(140);if(run!==session)return;
  picked.el.classList.add('flipped','reveal');tone('chime');
  target(picked,{z:0,rx:0,s:revealScale(),ry:0});
  await pause(1050);if(run!==session)return;
  picked.el.classList.add('holo');burst();document.documentElement.style.setProperty('--glow',picked.id===19?'150,116,63':picked.id===17?'60,114,135':'112,80,134');
  await pause(280);if(run!==session)return;showResult();
}
function burst(){if(reduce)return;for(let i=0;i<20;i++){let el=document.createElement('i');el.className='spark';let a=Math.random()*Math.PI*2,r=100+Math.random()*100;el.style.setProperty('--px',Math.cos(a)*r+'px');el.style.setProperty('--py',Math.sin(a)*r+'px');($('#revealStage').hidden?$('#burst'):$('#revealDeck')).append(el);setTimeout(()=>el.remove(),1600)}}
function resultPose(){if(picked)target(picked,{x:0,y:0,z:0,rz:-2,ry:0,rx:0,s:mobile()?1.75:1.75,o:1})}
function showResult(){state='result';used.add(picked.id);const d=data[picked.id],topic=$('#topic').value;const before=picked.el.parentElement.getBoundingClientRect();document.body.classList.add('result');$('#intro').inert=true;$('#reading').hidden=false;$('#deck').append(picked.el);$('#revealStage').hidden=true;const after=$('#deck').getBoundingClientRect();picked.p.x+=before.x-after.x;picked.p.y+=before.y-after.y;resultPose();setStep(3);$('#reading').hidden=false;$('#readingTopic').textContent='LỜI NHẮN VỀ '+({self:'BẢN THÂN',love:'TÌNH YÊU',work:'CÔNG VIỆC'}[topic]);$('#arcana').textContent=catalog[picked.id].family+' · '+catalog[picked.id].label+' · '+d[0].toUpperCase();$('#cardName').setAttribute('aria-label',d[1]);let letterIndex=0;$('#cardName').innerHTML=d[1].split(' ').map(word=>`<span class="title-word">${Array.from(word).map(c=>`<span class="letter" style="--i:${letterIndex++}">${c}</span>`).join('')}</span>`).join(' ');$('#keywords').innerHTML=d[2].split(',').map((k,i)=>`<span style="--i:${i}">${k}</span>`).join('');$('#message').textContent=d[3];$('#question').textContent=d[4];$('#message').textContent=topic==='self'?d[3]:d[3]+' '+catalog[picked.id][topic];$('#deeper').innerHTML=readingDetail(picked.id,topic);picked.el.setAttribute('aria-label',d[0]+' — '+d[1]);picked.el.tabIndex=0;picked.el.style.pointerEvents='auto';picked.el.setAttribute('aria-description','Di chuột hoặc chạm và kéo để nghiêng thẻ và đổi ánh holo. Có thể dùng các phím mũi tên.');$('#next').textContent=used.size===data.length?'Bắt đầu hành trình mới ↗':'Rút lá tiếp theo ↗';journal.unshift({id:picked.id,date:new Date().toISOString(),topic});journal=journal.slice(0,60);try{localStorage.setItem('lune-journal',JSON.stringify(journal));$('#saved').textContent='✓ Đã lưu vào nhật ký trên thiết bị này'}catch{$('#saved').textContent='Nhật ký chỉ được giữ trong phiên này'}updateCount()}
function updateCount(){$('#journalCount').textContent=journal.length?'· '+journal.length:''}
function tick(t){
  const dt=Math.min((t-last)/1000||.016,.25);last=t;
  const motion=shuffleMotion;
  let elapsed=motion?t-motion.start:0;
  if(motion){
    while(motion.nextEvent<motion.plan.events.length&&elapsed>=motion.plan.events[motion.nextEvent].t){
      const event=motion.plan.events[motion.nextEvent++];
      if(elapsed-event.t<120){shuffleSound(event.type,event.pan,event.gain);if(event.type==='tap')$('#stage').classList.add('shuffle-impact')}
    }
  }
  cards.forEach((c,i)=>{
    if(motion){
      const sampled=LuneMotion.sampleTrack(motion.plan.tracks[i],elapsed);
      Object.assign(c.p,sampled.p);Object.assign(c.t,sampled.p);
      for(const k in c.v)c.v[k]=0;
      c.el.style.zIndex=sampled.layer;
    }else for(const k of Object.keys(c.p)){
      if(reduce){c.p[k]=c.t[k];c.v[k]=0}
      else [c.p[k],c.v[k]]=LuneMotion.spring(c.p[k],c.v[k],c.t[k],dt,drag&&cards[drag.i]===c?22:14);
    }
    const p=c.p;
    if(motion)c.el.style.zIndex=elapsed>=motion.plan.loopStart&&elapsed<motion.plan.loopEnd?Math.round(100+p.z*2):i+1;
    const float=!reduce&&state==='chosen'&&c===picked?Math.sin(t*.0015)*1.5:0;
    c.el.style.transform=`translate(${p.x.toFixed(3)}px,${(p.y+float).toFixed(3)}px) rotate(${p.rz.toFixed(3)}deg) scale(${p.s.toFixed(4)})`;
    const h=c.holo;let hx=0,hy=0;
    if(c.el.classList.contains('holo')){
      [h.rx,h.vx]=LuneMotion.spring(h.rx,h.vx,reduce?0:h.tx,dt,13);
      [h.ry,h.vy]=LuneMotion.spring(h.ry,h.vy,reduce?0:h.ty,dt,13);
      const follow=1-Math.exp(-dt*9);h.mx+=(h.x-h.mx)*follow;h.my+=(h.y-h.my)*follow;h.power+=(h.targetPower-h.power)*(1-Math.exp(-dt*7));
      c.el.style.setProperty('--holo-x',h.mx+'%');c.el.style.setProperty('--holo-y',h.my+'%');c.el.style.setProperty('--holo-power',h.power);
      hx=h.rx;hy=h.ry;
    }
    c.el.querySelector('.card-inner').style.transform=motion
      ?`perspective(1100px) rotateY(${p.ry.toFixed(3)}deg) rotateX(${p.rx.toFixed(3)}deg)`
      :`perspective(1100px) rotateX(${(p.rx+hx).toFixed(3)}deg) rotateY(${(p.ry+hy+(c.el.classList.contains('flipped')?180:0)).toFixed(3)}deg)`;
    c.el.style.opacity=p.o>.999?1:p.o<.001?0:p.o;
    c.el.style.visibility=p.o<.001?'hidden':'visible';
  });
  if(motion&&elapsed>=motion.plan.duration&&shuffleMotion===motion){shuffleMotion=null;motion.resolve()}
  if(active)animId=requestAnimationFrame(tick);
}
function stars(){const canvas=$('#stars'),ctx=canvas.getContext('2d'),dpr=Math.min(devicePixelRatio||1,1.5);canvas.width=innerWidth*dpr;canvas.height=innerHeight*dpr;ctx.scale(dpr,dpr);let seed=41;function rand(){seed=(seed*16807)%2147483647;return seed/2147483647}for(let i=0;i<(mobile()?55:110);i++){const x=rand()*innerWidth,y=rand()*innerHeight;ctx.fillStyle=`rgba(210,195,161,${.12+rand()*.35})`;ctx.beginPath();ctx.arc(x,y,rand()*.8+.25,0,Math.PI*2);ctx.fill()}}
$('#shuffle').onclick=()=>{if(state==='fan'){if(soundOn){audioCtx??=new(window.AudioContext||window.webkitAudioContext)();audioCtx.resume()}shuffleDeck()}};$('#sound').onclick=()=>{soundOn=!soundOn;$('#sound').setAttribute('aria-pressed',soundOn);$('#sound').setAttribute('aria-label',soundOn?'Tắt âm thanh':'Bật âm thanh');$('#soundLabel').textContent=soundOn?'Âm thanh bật':'Âm thanh tắt';if(soundOn)tone('chime')};$('#more').onclick=()=>{const expanded=$('#deeper').hidden;$('#deeper').hidden=!expanded;$('#more').setAttribute('aria-expanded',expanded);$('#more').innerHTML=expanded?'Thu gọn <span>↑</span>':'Khám phá sâu hơn <span>↗</span>'};$('#next').onclick=()=>{window.scrollTo({top:0,behavior:reduce?'instant':'smooth'});start(false)};$('#reset').onclick=()=>{window.scrollTo({top:0,behavior:reduce?'instant':'smooth'});start(true)};$('#ritualNav').onclick=()=>{if(state==='result')start(true);else window.scrollTo({top:0,behavior:'smooth'})};
function openModal(html){$('#modalBody').innerHTML=html;$('#modal').showModal()}
$('#guideNav').onclick=()=>openModal('<h2>Một nghi thức của riêng bạn.</h2><ol><li>Hít thở sâu và chọn điều bạn muốn suy ngẫm: bản thân, tình yêu hoặc công việc.</li><li>Bộ bài tự quay một vòng, gom lại rồi xòe ra. Rê chuột qua dải bài để nâng từng lá. Bạn có thể xáo lại bằng nút bên dưới, hoặc vuốt ngang khoảng trống dưới bộ bài.</li><li>Di chuột, dùng phím Tab, hoặc chạm vào một lá bài. Kéo ra xa để rút; kéo ngắn rồi thả để trả lại.</li><li>Lá được chọn sẽ phóng to giữa màn hình và tự lật. Đọc lời nhắn và kết nối với câu chuyện của bạn.</li></ol><p>Bộ bài có đủ 78 lá: 22 Ẩn chính và 56 Ẩn phụ (Gậy, Cốc, Kiếm, Tiền), mỗi bộ gồm Át–10 và Tiểu Đồng, Kỵ Sĩ, Nữ Hoàng, Vua. Mỗi lần xáo, tối đa 72 lá được lấy ngẫu nhiên từ các lá chưa rút để tạo vòng cung rộng. Toàn bộ 78 lá đều có thể xuất hiện; không lặp lá đã rút trong cùng lượt trải. Hiện đọc theo chiều xuôi; phần mặt hạn chế là góc đối chiếu, không phải kết quả rút ngược. Hình minh họa đang là bản tạm. Nhật ký lưu trên trình duyệt của thiết bị này. Âm thanh có thể bật ở góc trên.</p><p>Tarot ở đây là công cụ tự suy ngẫm. Lời giải nghĩa được biên soạn sẵn, không phải dự báo cá nhân.</p>');
$('#journalNav').onclick=()=>openModal('<h2>Những lời nhắn đã gặp.</h2>'+(journal.length?journal.map(x=>`<div class="journal-item"><small>${new Intl.DateTimeFormat('vi-VN',{day:'2-digit',month:'2-digit',year:'numeric',hour:'2-digit',minute:'2-digit'}).format(new Date(x.date))} · ${{self:'Bản thân',love:'Tình yêu',work:'Công việc'}[x.topic]||'Bản thân'}</small><h3>${data[x.id][1]} · ${data[x.id][0]}</h3><p>${data[x.id][4]}</p></div>`).join(''):'<p class="journal-empty">Chưa có lá bài nào được mở. Mỗi lời nhắn bạn khám phá sẽ được lưu lại tại đây.</p>'));
$('#closeModal').onclick=()=>$('#modal').close();$('#modal').addEventListener('click',e=>{if(e.target===$('#modal')){const r=$('#modal').getBoundingClientRect();if(e.clientX<r.left||e.clientX>r.right||e.clientY<r.top||e.clientY>r.bottom)$('#modal').close()}});
let swipe=null;
$('#stage').addEventListener('pointerdown',e=>{
  if(state!=='fan')return;
  const i=hitCard(e);
  if(i>=0)startDrag(e,i);else swipe={x:e.clientX,y:e.clientY};
});
$('#stage').addEventListener('pointermove',e=>{
  if(drag){moveDrag(e);return}
  if(state!=='fan'||e.pointerType==='touch')return;
  const i=hitCard(e);
  if(i!==hover){hover=i;refreshFan();if(i>=0)tone()}
});
$('#stage').addEventListener('pointerleave',()=>{if(state==='fan'&&!drag){hover=-1;refreshFan()}});
$('#stage').addEventListener('pointerup',e=>{
  if(drag){endDrag(e);return}
  if(swipe&&state==='fan'&&Math.abs(e.clientX-swipe.x)>70&&Math.abs(e.clientY-swipe.y)<50)shuffleDeck();swipe=null;
});
$('#stage').addEventListener('pointercancel',()=>{swipe=null;cancelDrag()});
$('#stage').addEventListener('lostpointercapture',()=>cancelDrag());
window.addEventListener('blur',cancelDrag);
window.addEventListener('resize',()=>{cancelDrag();stars();if(state==='fan')refreshFan();if(state==='result')resultPose();if(state==='drawing'||state==='flipping'||state==='chosen'){target(picked,{x:0,y:0,s:revealScale()})}});document.addEventListener('visibilitychange',()=>{active=!document.hidden;if(active){last=performance.now();animId=requestAnimationFrame(tick)}else cancelAnimationFrame(animId)});stars();updateCount();requestAnimationFrame(tick);start();

function readingDetail(id,topic='self'){
 const c=catalog[id];
 const fields=topic==='work'?[['Công việc & nguồn lực',c.work],['Tình cảm & kết nối',c.love]]:[['Tình cảm & kết nối',c.love],['Công việc & nguồn lực',c.work]];
 return `<p class="reading-context">${c.family} · ${c.lens} Đọc theo chiều xuôi.</p>`+fields.concat([['Mặt hạn chế cần đối chiếu',c.shadow],['Một bước cụ thể',c.action]]).map(([title,body])=>`<section class="meaning-section"><h3>${title}</h3><p>${body}</p></section>`).join('')+`<p class="reading-note">Đặt lời giải trong hoàn cảnh thật của bạn: phần nào đúng với trải nghiệm, phần nào chưa phù hợp? Đây là cách diễn giải biểu tượng được biên soạn sẵn, không đọc được suy nghĩ người khác hay xác định tương lai.</p>`;
}
function openCatalog(){
 openModal('<h2>78 lá, 78 góc nhìn.</h2><p>22 lá Ẩn chính · 56 lá Ẩn phụ. Minh họa hiện là bản tạm.</p><label for="cardSearch">Tìm theo tên hoặc từ khóa</label><input id="cardSearch" type="search" placeholder="Ví dụ: Ngôi Sao, Cups, kiên nhẫn…"><div class="catalog-filters"><button data-family="all" class="active">Tất cả</button>'+['Ẩn chính','Bộ Gậy','Bộ Cốc','Bộ Kiếm','Bộ Tiền'].map(f=>`<button data-family="${f}">${f}</button>`).join('')+'</div><p id="catalogCount" role="status"></p><div id="catalogList"></div><div id="catalogDetail"></div>');
 let family='all';const norm=t=>t.normalize('NFD').replace(/[\u0300-\u036f]/g,'').replace(/đ/g,'d').toLowerCase();
 function render(){const q=norm($('#cardSearch').value);const found=catalog.filter(c=>(family==='all'||c.family===family)&&norm(c.vn+' '+c.name+' '+c.keywords).includes(q));$('#catalogCount').textContent=found.length+' / 78 lá';$('#catalogList').innerHTML=found.map(c=>`<button data-card="${c.id}"><span>${c.vn}</span><small>${c.name}</small></button>`).join('')||'<p>Chưa tìm thấy lá phù hợp. Thử từ khóa khác nhé.</p>';}
 $('#cardSearch').oninput=render;
 document.querySelectorAll('[data-family]').forEach(b=>b.onclick=()=>{family=b.dataset.family;document.querySelectorAll('[data-family]').forEach(x=>x.classList.toggle('active',x===b));render()});
 $('#catalogList').onclick=e=>{const b=e.target.closest('[data-card]');if(!b)return;const c=catalog[Number(b.dataset.card)];$('#catalogDetail').innerHTML=`<h2 tabindex="-1">${c.vn}</h2><p class="arcana">${c.name} · ${c.family}</p><p>${c.overview}</p>${readingDetail(c.id)}<div class="reflection"><span>MỘT ĐIỀU ĐỂ SUY NGẪM</span><p>${c.question}</p></div>`;$('#catalogDetail h2').focus();};render();
}
$('#catalogNav').onclick=openCatalog;
