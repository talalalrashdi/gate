/* One catalogue supplies the unread IDs; acknowledgement only on the أخبارنا header click. */
(() => {
 const badge=document.querySelector('[data-media-new]'),link=badge?.closest('a'),base=document.querySelector('meta[name="companyportal-api-base"]')?.content;if(!badge||!link||!base)return;
 let unread=[],loaded=false,clickPending=false,marking=false,simulating=false,simulatedNew=false;
 const acknowledged=new Set(),pending=new Set();
 const update=()=>{badge.hidden=!(simulating?simulatedNew:unread.some(id=>!acknowledged.has(id)&&!pending.has(id)));};
 async function mark(){
  if(simulating){simulatedNew=false;update();return;}
  if(!loaded){clickPending=true;return;}
  if(marking)return;
  const ids=unread.filter(id=>!acknowledged.has(id));if(!ids.length)return;
  marking=true;ids.forEach(id=>pending.add(id));update();
  try{
   const r=await fetch(new URL('api/media/seen',new URL(base.replace(/\/?$/,'/'),location.href)),{method:'POST',credentials:'include',headers:{'Content-Type':'application/json','X-CompanyPortal-Request':'media-read'},body:JSON.stringify({mediaIds:ids.map(Number)}),signal:AbortSignal.timeout(15000)});
   if(!r.ok)throw new Error();ids.forEach(id=>acknowledged.add(id));
  }catch{/* Keep the badge for retry on the next click; never claim an unsaved acknowledgement. */}
  finally{marking=false;pending.clear();update();}
 }
 link.addEventListener('click',()=>void mark());
 document.addEventListener('portal:media-catalog',e=>{
  if(!e.detail){loaded=false;unread=[];clickPending=false;update();return;}
  loaded=true;unread=Array.isArray(e.detail.unreadMediaIds)?e.detail.unreadMediaIds.map(String):[];
  update();if(clickPending){clickPending=false;void mark();}
 });
 if(document.getElementById('portal-simulation'))document.addEventListener('portal:simulate',e=>{
  if(['media-photo','media-video'].includes(e.detail?.kind)){simulating=true;simulatedNew=true;}
  else if(e.detail?.kind==='reset'){simulating=false;simulatedNew=false;}else return;update();
 });
})();
