/* Pure geometry and frame-rate-independent, critically damped motion. */
(function(root){
  const dimensions=w=>w<=760?{w:94,h:154}:{w:132,h:216};
  function fan(i,n,width){
    const u=n>1?(i/(n-1)*2-1):0,d=dimensions(width);
    const span=Math.min(1040,Math.max(0,width*.86-d.w*1.3))*Math.min(1,Math.max(0,n-1)/20);
    return {x:u*span/2,y:44*u*u-20,z:0,rz:u*14,ry:0,rx:0,s:1,o:1};
  }
  function dockZoom(){return 1;}
  function wave(i,n,width,hover){
    const p=fan(i,n,width);
    if(hover>=0){
      const d=Math.abs(i-hover),lift=(width<=760?88:124)*Math.exp(-d*.36);
      p.y-=lift;p.rz*=1-.55*Math.exp(-d*.6);
      p.s+=.025*Math.exp(-d*.7);
    }
    return p;
  }
  function contains(x,y,p,w,h,pad=0){
    const rad=p.rz*Math.PI/180,dx=x-p.x,dy=y-p.y;
    const lx=(dx*Math.cos(rad)+dy*Math.sin(rad))/p.s,ly=(-dx*Math.sin(rad)+dy*Math.cos(rad))/p.s;
    return Math.abs(lx)<=w/2+pad&&Math.abs(ly)<=h/2+pad;
  }
  function hit(x,y,n,width){
    const d=dimensions(width);
    for(let i=n-1;i>=0;i--)if(contains(x,y,fan(i,n,width),d.w,d.h))return i;
    return -1;
  }
  function spring(x,v,goal,dt,omega=16){
    const offset=x-goal,c=v+omega*offset,e=Math.exp(-omega*dt);
    const nx=goal+(offset+c*dt)*e,nv=(v-omega*c*dt)*e;
    return Math.abs(nx-goal)<.002&&Math.abs(nv)<.01?[goal,0]:[nx,nv];
  }
  const ease={smooth:t=>t*t*(3-2*t),out:t=>1-Math.pow(1-t,3),in:t=>t*t*t,linear:t=>t};
  function shufflePlan(n,width,initial){
    const small=width<=760,loopStart=650,loopEnd=3050;
    const defaults={x:0,y:0,z:0,rx:0,ry:0,rz:0,s:1,o:1};
    const stack=i=>({...defaults,x:(i-(n-1)/2)*.13,y:-(i/Math.max(1,n-1))*16,rx:18,ry:-14,rz:-3});
    const curl=(i,turn)=>{
      const phase=i/Math.max(1,n)*Math.PI*2,angle=phase+turn*Math.PI*2;
      const height=small?61:90;
      // Rotate the whole moving ribbon around a shared vertical axis, then project
      // each card center and depth. Face orientation uses the same parent-first yaw.
      const yaw=turn*Math.PI*2-24*Math.PI/180;
      const localX=Math.sin(angle)*24+(i/n-.5)*12,localZ=Math.cos(angle)*35;
      const x=localX*Math.cos(yaw)+localZ*Math.sin(yaw);
      const z=-localX*Math.sin(yaw)+localZ*Math.cos(yaw);
      const perspective=900/(900-z);
      return {...defaults,x:x*perspective,y:(Math.sin(angle)*height-8)*perspective,
        z,rx:angle*180/Math.PI,ry:yaw*180/Math.PI,rz:4*Math.sin(phase*3),s:(small?.86:.95)*perspective};
    };
    const tracks=Array.from({length:n},(_,i)=>{
      const frames=[];let prev={...defaults};
      const add=(t,p,layer=i+1,curve='smooth')=>{prev={...prev,...p};frames.push({t,p:{...prev},layer,curve})};
      add(0,initial?.[i]||defaults);add(430,stack(i),i+1,'out');
      add(loopStart,curl(i,0),Math.round(100+Math.cos(i/n*Math.PI*2)*70));
      for(let j=1;j<=48;j++){
        const p=curl(i,j/48);add(loopStart+(loopEnd-loopStart)*j/48,p,Math.round(100+p.z*2),'linear');
      }
      const stop=stack(i);stop.rx=720;stop.ry=360;stop.rz=0;
      add(loopEnd+500+i/Math.max(1,n-1)*140,stop,i+1,'out');
      add(3800,{...stop,y:0,rx:720},i+1,'out');
      return frames;
    });
    const events=[{t:250,type:'sweep'},...Array.from({length:16},(_,i)=>({t:loopStart+i*150,type:'riffle',pan:Math.sin(i*.4)*.3,gain:.3})),{t:3650,type:'tap'},{t:3790,type:'spread'}];
    return {tracks,events,duration:3800,loopStart,loopEnd,merged:3690};
  }
  function sampleTrack(frames,time){
    let i=0;while(i<frames.length-1&&time>=frames[i+1].t)i++;
    const a=frames[i],b=frames[Math.min(i+1,frames.length-1)],u=b.t===a.t?1:Math.max(0,Math.min(1,(time-a.t)/(b.t-a.t))),t=(ease[b.curve]||ease.smooth)(u),p={};
    for(const key in a.p)p[key]=a.p[key]+(b.p[key]-a.p[key])*t;
    return {p,layer:a.layer};
  }
  const api={dimensions,fan,wave,dockZoom,contains,hit,spring,shufflePlan,sampleTrack};
  if(typeof module==='object')module.exports=api;else root.LuneMotion=api;
})(typeof window!=='undefined'?window:this);
