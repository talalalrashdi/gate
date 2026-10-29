/* Scheduled event links load once per page; simulation is memory-only. */
(() => {
 const marker=document.getElementById('portal-header-events'),base=document.querySelector('meta[name="companyportal-api-base"]')?.content;if(!marker||!base)return;
 let real=[],samples=[],timer;const freshUntil=new Map();
 function expire(){clearTimeout(timer);const now=Date.now();for(const a of marker.parentElement.querySelectorAll('[data-header-event]')){const fresh=(freshUntil.get(a.dataset.headerEvent)||0)>now;a.querySelector('.portal-header-event-new').hidden=!fresh;if(!a.dataset.headerEvent.startsWith('simulation-'))a.setAttribute('aria-label',a.dataset.eventTitle+' — '+(fresh?'جديد — ':'')+'فتح التطبيق في علامة تبويب جديدة');}const next=[...freshUntil.values()].filter(at=>at>now).sort((a,b)=>a-b)[0];if(next&&!document.hidden)timer=setTimeout(expire,next-now+10); }
 const safe=value=>{try{const url=new URL(value);return ['http:','https:'].includes(url.protocol)&&!url.username&&!url.password;}catch{return false;}};
 function render(){
  for(const link of marker.parentElement.querySelectorAll('[data-header-event]'))link.remove();
  let previous=marker;
  for(const row of [...real,...samples]){
   if(!row.isSimulation&&!safe(row.appUrl))continue;
   const a=document.createElement('a');a.textContent=row.title;a.dataset.headerEvent=String(row.eventId);a.dataset.eventTitle=row.title;if(!freshUntil.has(String(row.eventId)))freshUntil.set(String(row.eventId),Date.now()+60000);a.href=row.isSimulation?'#':row.appUrl;
   if(row.isSimulation)a.addEventListener('click',e=>{e.preventDefault();const dialog=document.getElementById('portal-simulation-dialog');if(!dialog)return;dialog.querySelector('h2').textContent=row.title;dialog.querySelector('p').textContent='هذا رابط فعالية للمحاكاة فقط. الرابط الحقيقي يفتح تطبيق الفعالية في علامة تبويب جديدة.';dialog.showModal();});
   else{a.target='_blank';a.rel='noopener noreferrer';a.setAttribute('aria-label',row.title+' — جديد — فتح التطبيق في علامة تبويب جديدة');}
   const badge=document.createElement('span');badge.className='portal-header-event-new';badge.textContent='جديد';a.append(badge);
   previous.after(a);previous=a;
  }
  const present=new Set([...real,...samples].map(row=>String(row.eventId)));for(const id of freshUntil.keys())if(!present.has(id))freshUntil.delete(id);expire();
 }
 async function load(){try{
  const response=await fetch(new URL('api/header-events',new URL(base.replace(/\/?$/,'/'),location.href)),{credentials:'include',cache:'no-store',signal:AbortSignal.timeout(15000)});
  if(!response.ok)throw new Error();const rows=await response.json();
  if(!Array.isArray(rows)||rows.some(r=>!Number.isInteger(r.eventId)||typeof r.title!=='string'||typeof r.appUrl!=='string'))throw new Error();
  real=rows;render();
 }catch{real=[];render();}}
 if(document.getElementById('portal-simulation'))document.addEventListener('portal:simulate',e=>{
  if(e.detail?.kind==='event')samples.push({eventId:'simulation-event-'+e.detail.id,title:e.detail.title,isSimulation:true});
  else if(e.detail?.kind==='reset')samples=[];else return;render();
 });
 document.addEventListener('visibilitychange',()=>{if(document.hidden)clearTimeout(timer);else expire();});window.addEventListener('pagehide',()=>clearTimeout(timer));window.addEventListener('pageshow',expire);
 void load();
})();
