(() => {
 const card=document.querySelector('[data-work-system="technical-inbox"]'),base=document.querySelector('meta[name="companyportal-api-base"]')?.content;if(!card||!base)return;
 const list=card.querySelector('#technical-inbox-list'),status=card.querySelector('#technical-inbox-status'),badge=card.querySelector('[data-count-source]'),total=card.querySelector('[data-inbox-total]'),app=card.querySelector('[data-inbox-app]');
 const endpoint=path=>new URL('api/technical-inbox'+path,new URL(base.replace(/\/?$/,'/'),location.href));
 const make=(tag,cls,text)=>{const n=document.createElement(tag);if(cls)n.className=cls;if(text!==undefined)n.textContent=text;return n;};
 const lazy=window.CompanyPortalLazy?.gate(card)||{ready:true,run:f=>f()};
 let controller,generation=0,loading=false,timer,failures=0,fingerprint='',freshTimer,baseline=false;const seen=new Set(),fresh=new Map();
 function clear(){fingerprint='';list.replaceChildren();total.textContent='—';badge.textContent='—';badge.hidden=false;app.removeAttribute('href');app.setAttribute('aria-disabled','true');fresh.clear();seen.clear();baseline=false;clearTimeout(freshTimer);}
 function summary(data){
  if(!Number.isInteger(data.unreadCount)||data.unreadCount<0)throw new Error('تعذر قراءة عداد الإسناد الفني.');
  badge.textContent=String(data.unreadCount);badge.hidden=data.unreadCount===0;badge.setAttribute('aria-label',data.unreadCount+' طلبات إسناد غير مفتوحة');
  let url;try{url=new URL(data.appUrl);}catch{}if(url&&['http:','https:'].includes(url.protocol)&&!url.username&&!url.password){app.href=url.href;app.removeAttribute('aria-disabled');}else{app.removeAttribute('href');app.setAttribute('aria-disabled','true');}
 }
 function render(data){
  const now=Date.now();for(const row of data.items){if(row.isOpened)fresh.delete(row.inboxId);else if(baseline&&!seen.has(row.inboxId))fresh.set(row.inboxId,now+60000);seen.add(row.inboxId);}baseline=true;
  total.textContent=String(data.items.length);list.replaceChildren();
  for(const row of data.items){
   const item=make('article','portal-correspondence-item technical-inbox-item');item.dataset.state=row.isOpened?'opened':'unopened';item.dataset.inboxId=row.inboxId;
   const heading=make('span','portal-correspondence-heading');heading.append(make('span','portal-correspondence-purpose is-info',row.requestType));
   const details=make('strong','portal-correspondence-title',row.details);details.title=row.details;
   const meta=make('span','technical-inbox-meta');if(row.documentNumber?.trim())meta.append(make('span',null,'المستند: '+row.documentNumber));if(row.officeNumber?.trim())meta.append(make('span',null,'المكتب: '+row.officeNumber));
   if(row.hasAttachment){const attach=make('span','technical-inbox-attachment','مرفق');const icon=make('i','iconsax');icon.setAttribute('icon-name','document-text-1');icon.setAttribute('aria-hidden','true');attach.prepend(icon);meta.append(attach);}
   const time=make('time');time.dateTime=row.receivedAt;time.textContent=new Intl.DateTimeFormat('ar-OM',{dateStyle:'short',timeZone:'Asia/Muscat'}).format(new Date(row.receivedAt));
   if((fresh.get(row.inboxId)||0)>now)time.prepend(make('span','portal-correspondence-new','جديد'),document.createTextNode('\n'));
   item.append(heading,details,meta,time);list.append(item);
  }
  expireFresh();
  status.hidden=data.items.length>0;status.textContent=data.items.length?'':'لا توجد طلبات واردة.';card.dispatchEvent(new CustomEvent('workspace:cards-changed',{bubbles:true}));
 }
 function expireFresh(){clearTimeout(freshTimer);const now=Date.now();for(const node of list.querySelectorAll('[data-inbox-id]'))if((fresh.get(node.dataset.inboxId)||0)<=now)node.querySelector('.portal-correspondence-new')?.remove();const ends=[...fresh.values()].filter(t=>t>now);if(ends.length)freshTimer=setTimeout(expireFresh,Math.min(...ends)-now+20);}
 function schedule(){clearTimeout(timer);if(!document.hidden)timer=setTimeout(()=>void load(),Math.min(300000,60000*2**failures)+Math.random()*5000);}
 async function load(){
  if(loading||document.hidden)return;loading=true;controller=new AbortController();const stamp=++generation;list.setAttribute('aria-busy','true');
  try{
   const response=await fetch(endpoint(lazy.ready?'':'/count'),{credentials:'include',cache:'no-store',signal:AbortSignal.any([controller.signal,AbortSignal.timeout(20000)])});if(stamp!==generation)return;
   if(!response.ok){if(response.status===401||response.status===403)clear();throw new Error(response.status===401?'تعذر التحقق من حساب Windows.':response.status===403?'لا تتوفر صلاحية عرض وارد الإسناد الفني لحسابك.':'تعذر تحميل وارد الإسناد الفني. ستتم إعادة المحاولة تلقائيًا.');}
   const data=await response.json();if(stamp!==generation)return;summary(data);
   if(lazy.ready){if(!Array.isArray(data.items)||data.items.some(r=>!r||typeof r.inboxId!=='string'||!/^\d+$/.test(r.inboxId)||typeof r.details!=='string'||typeof r.requestType!=='string'||typeof r.hasAttachment!=='boolean'||typeof r.isOpened!=='boolean'||!Number.isFinite(Date.parse(r.receivedAt))||[r.documentNumber,r.officeNumber].some(v=>v!=null&&typeof v!=='string')))throw new Error('تعذر قراءة بيانات وارد الإسناد الفني.');const next=JSON.stringify(data);if(next!==fingerprint||failures){render(data);fingerprint=next;}}
   failures=0;
  }catch(error){if(stamp!==generation)return;failures=Math.min(3,failures+1);status.hidden=false;status.textContent=error.name==='Error'?error.message:'تعذر الاتصال بوارد الإسناد الفني. ستتم إعادة المحاولة تلقائيًا.';}
  finally{if(stamp===generation){loading=false;list.setAttribute('aria-busy','false');schedule();}}
 }
 function suspend(){++generation;controller?.abort();clearTimeout(timer);loading=false;clear();list.setAttribute('aria-busy','false');}
 document.addEventListener('visibilitychange',()=>{if(document.hidden)suspend();else void load();});window.addEventListener('online',()=>void load());window.addEventListener('pagehide',suspend);window.addEventListener('pageshow',e=>{if(e.persisted)void load();});
 if(!lazy.ready)lazy.run(()=>{++generation;controller?.abort();loading=false;clearTimeout(timer);void load();});void load();
})();
