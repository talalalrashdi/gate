(() => {
  const card=document.querySelector('[data-work-system="requests"]'),base=document.querySelector('meta[name="companyportal-api-base"]')?.content;
  if(!card||!base)return;
  const list=card.querySelector('#forms-inbox-list'),status=card.querySelector('#forms-inbox-status'),badge=card.querySelector('[data-count-source="forms"]'),dialog=card.querySelector('#forms-sample-dialog');
  let loading=false,controller,timer,generation=0,failures=0,fingerprint='',rows=[];
  const seen=new Set(),freshUntil=new Map();let baseline=false,freshTimer;
  function updateFresh(){clearTimeout(freshTimer);const now=Date.now();for(const el of list.querySelectorAll('[data-form-id]'))if((freshUntil.get(el.dataset.formId)||0)<=now){const badge=el.querySelector('.portal-form-new');if(badge?.nextSibling?.nodeType===3&&badge.nextSibling.textContent==='\n')badge.nextSibling.remove();badge?.remove();}const next=[...freshUntil.values()].filter(at=>at>now).sort((a,b)=>a-b)[0];if(next&&!document.hidden)freshTimer=setTimeout(updateFresh,next-now+10);}
  const endpoint=path=>new URL(path,new URL(base.replace(/\/?$/,'/'),location.href));
  const make=(tag,cls,text)=>{const el=document.createElement(tag);if(cls)el.className=cls;if(text!==undefined)el.textContent=text;return el;};
  function clear(){rows=[];fingerprint='';list.replaceChildren();badge.hidden=false;badge.textContent='—';badge.setAttribute('aria-label','عدد الاستمارات غير المفتوحة غير متاح');if(dialog.open)dialog.close();}
  function schedule(){clearTimeout(timer);if(!document.hidden)timer=setTimeout(()=>void load(),Math.min(300000,60000*2**failures)+Math.random()*5000);}
  function render(data){
    rows=data.items;list.replaceChildren();
    for(const row of rows){
      const el=make(row.canOpen?'a':'button','portal-form-item');el.dataset.state=row.isOpened?'opened':'unopened';el.dataset.formId=row.formId;
      el.setAttribute('aria-label',row.title+' — '+(row.isOpened?'مفتوحة':'غير مفتوحة')+(row.isSamplePreview?' — معاينة محلية':''));
      if(row.canOpen){el.href=endpoint('api/forms/'+row.formId+'/open');el.target='_blank';el.rel='noopener noreferrer';}
      else{el.type='button';el.disabled=!row.isSamplePreview;}
      const title=make('strong','portal-form-title',row.title);
      el.append(title,make('span','portal-form-sender',row.senderName));
      const sent=new Date(row.sentAt),date=make('time',null,new Intl.DateTimeFormat('ar-OM',{dateStyle:'short',timeZone:'Asia/Muscat'}).format(sent)+'\n'+new Intl.DateTimeFormat('ar-OM',{timeStyle:'short',timeZone:'Asia/Muscat'}).format(sent));date.dateTime=row.sentAt;if(!row.isOpened&&(freshUntil.get(row.formId)||0)>Date.now())date.prepend(make('span','portal-form-new','جديد'),document.createTextNode('\n'));el.append(date);
      if(!row.canOpen&&row.isSamplePreview)el.addEventListener('click',()=>{dialog.querySelector('h2').textContent=row.title;dialog.querySelector('[data-forms-sample-sender]').textContent=row.senderName+' · '+date.textContent;dialog.showModal();});
      list.append(el);
    }
    updateFresh();
    badge.textContent=String(data.unreadCount);badge.hidden=data.unreadCount===0;badge.setAttribute('aria-label',data.unreadCount+' استمارات غير مفتوحة');
    status.hidden=rows.length>0&&(rows.every(r=>r.canOpen||r.isSamplePreview));
    status.textContent=!rows.length?'لا توجد استمارات واردة.':rows.some(r=>!r.canOpen)?'رابط تطبيق الاستمارات غير مهيأ.':' ';
  }
  async function load(){
    if(loading||document.hidden)return;loading=true;const mine=++generation;controller=new AbortController();list.setAttribute('aria-busy','true');
    try{
      const response=await fetch(endpoint('api/forms'),{credentials:'include',cache:'no-store',signal:AbortSignal.any([controller.signal,AbortSignal.timeout(20000)])});
      if(mine!==generation)return;
      if(response.status===401||response.status===403){seen.clear();freshUntil.clear();baseline=false;clearTimeout(freshTimer);clear();throw new Error('لا تتوفر صلاحية عرض وارد الاستمارات لحسابك.');}
      if(!response.ok)throw new Error('تعذر تحميل وارد الاستمارات. ستتم إعادة المحاولة تلقائيًا.');
      const data=await response.json();if(mine!==generation)return;
      if(!Array.isArray(data.items)||!Number.isInteger(data.unreadCount)||data.unreadCount<0||data.items.some(r=>!r||!/^\d+$/.test(r.formId)||typeof r.title!=='string'||typeof r.senderName!=='string'||typeof r.isOpened!=='boolean'||!Number.isFinite(Date.parse(r.sentAt))))throw new Error('تعذر قراءة بيانات وارد الاستمارات.');
      const now=Date.now();for(const row of data.items){if(row.isOpened)freshUntil.delete(row.formId);else if(baseline&&!seen.has(row.formId))freshUntil.set(row.formId,now+60000);seen.add(row.formId);}baseline=true;
      const next=JSON.stringify(data);if(next!==fingerprint||failures){render(data);fingerprint=next;}failures=0;
    }catch(error){if(mine!==generation)return;failures=Math.min(3,failures+1);status.hidden=false;status.textContent=error.name==='Error'?error.message:'تعذر الاتصال بوارد الاستمارات. ستتم إعادة المحاولة تلقائيًا.';}
    finally{if(mine===generation){loading=false;list.setAttribute('aria-busy','false');schedule();}}
  }
  dialog.querySelector('button').addEventListener('click',()=>dialog.close());
  dialog.addEventListener('click',event=>{if(event.target!==dialog)return;const r=dialog.getBoundingClientRect();if(event.clientX<r.left||event.clientX>r.right||event.clientY<r.top||event.clientY>r.bottom)dialog.close();});
  function suspend(){generation++;controller?.abort();clearTimeout(timer);clearTimeout(freshTimer);loading=false;list.setAttribute('aria-busy','false');clear();}
  document.addEventListener('visibilitychange',()=>{if(document.hidden)suspend();else void load();});
  window.addEventListener('online',()=>void load());window.addEventListener('pagehide',suspend);window.addEventListener('pageshow',e=>{if(e.persisted)void load();});
  void load();
})();
