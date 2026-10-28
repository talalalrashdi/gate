(() => {
  const card=document.querySelector('[data-work-system="inbox"]'),base=document.querySelector('meta[name="companyportal-api-base"]')?.content;
  if(!card||!base)return;
  const list=card.querySelector('#correspondence-inbox-list'),status=card.querySelector('#correspondence-inbox-status'),badge=card.querySelector('[data-count-source="correspondence"]'),dialog=card.querySelector('#correspondence-sample-dialog'),filter=card.querySelector('#correspondence-purpose-filter');
  let loading=false,controller,timer,generation=0,failures=0,fingerprint='',rows=[],unreadCount=0,selectedPurpose='';
  let realData={items:[],unreadCount:0},simulatedRows=[];
  const total=card.querySelector('[data-inbox-total]'),app=card.querySelector('[data-inbox-app]');
  function updateApp(value){let url;try{url=new URL(value);}catch{}const valid=typeof value==='string'&&url&&['https:','http:'].includes(url.protocol)&&!url.username&&!url.password;if(valid){app.href=url.href;app.removeAttribute('aria-disabled');app.title='فتح التطبيق في علامة تبويب جديدة';}else{app.removeAttribute('href');app.setAttribute('aria-disabled','true');app.title='رابط التطبيق لم يُضبط بعد';}}
  const previewOpened=new Set();
  const seen=new Set(),freshUntil=new Map();let baseline=false,freshTimer;
  function updateFresh(){clearTimeout(freshTimer);const now=Date.now();for(const el of list.querySelectorAll('[data-correspondence-id]'))if((freshUntil.get(el.dataset.correspondenceId)||0)<=now){const badge=el.querySelector('.portal-correspondence-new');if(badge?.nextSibling?.nodeType===3&&badge.nextSibling.textContent==='\n')badge.nextSibling.remove();badge?.remove();}const next=[...freshUntil.values()].filter(at=>at>now).sort((a,b)=>a-b)[0];if(next&&!document.hidden)freshTimer=setTimeout(updateFresh,next-now+10);}
  function receivedLabel(value,now=new Date()){
    const day=date=>{const parts=new Intl.DateTimeFormat('en-US',{timeZone:'Asia/Muscat',year:'numeric',month:'numeric',day:'numeric'}).formatToParts(date);const part=key=>Number(parts.find(p=>p.type===key).value);return Date.UTC(part('year'),part('month')-1,part('day'))/86400000;};
    const date=new Date(value),days=day(now)-day(date);
    if(days===0)return new Intl.DateTimeFormat('ar-OM',{timeStyle:'short',timeZone:'Asia/Muscat'}).format(date);
    const full=new Intl.DateTimeFormat('ar-OM',{dateStyle:'short',timeZone:'Asia/Muscat'}).format(date);
    return full+(days>0?'\n'+(days===1?'قبل يوم':'قبل '+days+' أيام'):'');
  }
  const endpoint=path=>new URL(path,new URL(base.replace(/\/?$/,'/'),location.href));
  const make=(tag,cls,text)=>{const el=document.createElement(tag);if(cls)el.className=cls;if(text!==undefined)el.textContent=text;return el;};
  function clear(){total.textContent='—';updateApp(null);rows=[];realData={items:[],unreadCount:0};fingerprint='';list.replaceChildren();filter.replaceChildren();selectedPurpose='';badge.hidden=false;badge.textContent='—';badge.setAttribute('aria-label','عدد المراسلات غير المفتوحة غير متاح');if(dialog.open)dialog.close();}
  function schedule(){clearTimeout(timer);if(!document.hidden)timer=setTimeout(()=>void load(),Math.min(300000,60000*2**failures)+Math.random()*5000);}
  function render(data){
    realData=data;const previewCount=data.items.filter(r=>!r.isOpened&&r.isSamplePreview&&!r.canOpen&&previewOpened.has(r.correspondenceId)).length;
    rows=[...simulatedRows,...data.items.map(r=>previewOpened.has(r.correspondenceId)&&r.isSamplePreview&&!r.canOpen?{...r,isOpened:true}:r)];unreadCount=Math.max(0,data.unreadCount-previewCount)+simulatedRows.filter(row=>!row.isOpened).length;
    total.textContent=String(rows.length);updateApp(data.appUrl);
    const types=[...new Set(rows.map(r=>r.purpose))].sort((a,b)=>a.localeCompare(b,'ar'));
    if(!types.includes(selectedPurpose))selectedPurpose='';
    const focused=filter.contains(document.activeElement)?document.activeElement.dataset.purpose:null;
    filter.replaceChildren();
    for(const type of ['',...types]){const button=make('button','portal-correspondence-filter-pill',type||'الكل');button.type='button';button.dataset.purpose=type;filter.append(button);}
    updateFilter();
    if(focused!==null)[...filter.children].find(button=>button.dataset.purpose===focused)?.focus();
    renderRows();
  }
  function renderRows(){
    list.replaceChildren();
    const visible=rows.filter(row=>!selectedPurpose||row.purpose===selectedPurpose);
    for(const row of visible){
      const el=make(row.canOpen?'a':'button','portal-correspondence-item');el.dataset.state=row.isOpened?'opened':'unopened';el.dataset.correspondenceId=row.correspondenceId;
      el.setAttribute('aria-label',row.title+' — '+(row.isOpened?'مفتوحة':'غير مفتوحة')+(row.isSimulation?' — محاكاة محلية':row.isSamplePreview?' — معاينة محلية':''));
      if(row.canOpen){el.href=endpoint('api/correspondence/'+row.correspondenceId+'/open');el.target='_blank';el.rel='noopener noreferrer';}
      else{el.type='button';el.disabled=!row.isSamplePreview;}
      const title=make('strong','portal-correspondence-title',row.title);title.title=row.title;
      const header=make('span','portal-correspondence-heading'),number=make('span','portal-correspondence-number',row.docNo),purpose=make('span','portal-correspondence-purpose '+(row.purpose==='للإجراء'?'is-action':'is-info'),row.purpose);number.dir='ltr';header.append(number,purpose);el.append(header,title);
      const sender=make('span','portal-correspondence-sender','مرسلة من قبل: '+(row.senderName||'غير محدد'));sender.title=sender.textContent;el.append(sender);
      const date=make('time',null,receivedLabel(row.receivedAt));date.dateTime=row.receivedAt;if(!row.isOpened&&(freshUntil.get(row.correspondenceId)||0)>Date.now())date.prepend(make('span','portal-correspondence-new','جديد'),document.createTextNode('\n'));el.append(date);
      if(!row.canOpen&&row.isSamplePreview)el.addEventListener('click',()=>{dialog.querySelector('h2').textContent=row.title;dialog.querySelector('[data-correspondence-sample-meta]').textContent=row.docNo+' · '+row.purpose+' · مرسلة من قبل: '+(row.senderName||'غير محدد')+' · '+date.textContent;dialog.querySelector('header strong').textContent=row.isSimulation?'معاينة مراسلة — محاكاة محلية':'معاينة مراسلة — بيانات محلية';dialog.querySelector('p:last-child').textContent=row.isSimulation?'هذه مراسلة محاكاة مؤقتة في الصفحة فقط، دون حفظ أو فتح تطبيق خارجي.':'هذه معاينة محلية حتى إعداد رابط تطبيق المراسلات. تتغير حالة القراءة في هذا التبويب فقط، دون تعديل OfficeFormsdb.';if(!row.isOpened){if(row.isSimulation)row.isOpened=true;else previewOpened.add(row.correspondenceId);freshUntil.delete(row.correspondenceId);render(realData);}dialog.showModal();});
      list.append(el);
    }
    updateFresh();
    badge.textContent=String(unreadCount);badge.hidden=unreadCount===0;badge.setAttribute('aria-label',unreadCount+' مراسلات غير مفتوحة');
    status.hidden=visible.length>0&&(visible.every(r=>r.canOpen||r.isSamplePreview));
    status.textContent=!visible.length?'لا توجد مراسلات واردة.':visible.some(r=>!r.canOpen)?'رابط تطبيق المراسلات غير مهيأ.':' ';
  }
  async function load(){
    if(loading||document.hidden)return;loading=true;const mine=++generation;controller=new AbortController();list.setAttribute('aria-busy','true');
    try{
      const response=await fetch(endpoint('api/correspondence'),{credentials:'include',cache:'no-store',signal:AbortSignal.any([controller.signal,AbortSignal.timeout(20000)])});
      if(mine!==generation)return;
      if(response.status===401||response.status===403){previewOpened.clear();seen.clear();freshUntil.clear();baseline=false;clearTimeout(freshTimer);clear();throw new Error('لا تتوفر صلاحية عرض وارد المراسلات لحسابك.');}
      if(!response.ok)throw new Error('تعذر تحميل وارد المراسلات. ستتم إعادة المحاولة تلقائيًا.');
      const data=await response.json();if(mine!==generation)return;
      if(!Array.isArray(data.items)||!Number.isInteger(data.unreadCount)||data.unreadCount<0||data.items.some(r=>!r||!/^\d+$/.test(r.correspondenceId)||typeof r.title!=='string'||typeof r.docNo!=='string'||typeof r.purpose!=='string'||(r.senderName!=null&&typeof r.senderName!=='string')||typeof r.isOpened!=='boolean'||!Number.isFinite(Date.parse(r.receivedAt))))throw new Error('تعذر قراءة بيانات وارد المراسلات.');
      const now=Date.now();for(const row of data.items){if(row.isOpened||previewOpened.has(row.correspondenceId))freshUntil.delete(row.correspondenceId);else if(baseline&&!seen.has(row.correspondenceId))freshUntil.set(row.correspondenceId,now+60000);seen.add(row.correspondenceId);}baseline=true;
      const next=JSON.stringify(data);if(next!==fingerprint||failures){render(data);fingerprint=next;}else list.querySelectorAll('time[datetime]').forEach(time=>{const fresh=time.querySelector('.portal-correspondence-new');time.replaceChildren(...(fresh?[fresh,document.createTextNode('\n')]:[]),document.createTextNode(receivedLabel(time.dateTime)));});failures=0;
    }catch(error){if(mine!==generation)return;failures=Math.min(3,failures+1);status.hidden=false;status.textContent=error.name==='Error'?error.message:'تعذر الاتصال بوارد المراسلات. ستتم إعادة المحاولة تلقائيًا.';}
    finally{if(mine===generation){loading=false;list.setAttribute('aria-busy','false');schedule();}}
  }
  if(document.getElementById('portal-simulation'))document.addEventListener('portal:simulate',event=>{
    const detail=event.detail;if(!detail||!['correspondence','reset'].includes(detail.kind))return;
    if(detail.kind==='reset'){for(const row of simulatedRows){seen.delete(row.correspondenceId);freshUntil.delete(row.correspondenceId);}simulatedRows=[];}
    else{
      const id='simulation-correspondence-'+detail.id;
      simulatedRows.unshift({correspondenceId:id,docNo:'SIM/'+detail.id,title:detail.title,purpose:detail.correspondencePurpose,senderName:detail.correspondenceSender,receivedAt:new Date().toISOString(),isOpened:false,isSamplePreview:true,canOpen:false,isSimulation:true});
      freshUntil.set(id,Date.now()+60000);seen.add(id);selectedPurpose='';
    }
    render(realData);
  });
  function updateFilter(){for(const button of filter.children)button.setAttribute('aria-pressed',String(button.dataset.purpose===selectedPurpose));}
  filter.addEventListener('click',event=>{const button=event.target.closest('button[data-purpose]');if(!button||!filter.contains(button)||selectedPurpose===button.dataset.purpose)return;selectedPurpose=button.dataset.purpose;updateFilter();renderRows();});
  dialog.querySelector('button').addEventListener('click',()=>dialog.close());
  dialog.addEventListener('click',event=>{if(event.target!==dialog)return;const r=dialog.getBoundingClientRect();if(event.clientX<r.left||event.clientX>r.right||event.clientY<r.top||event.clientY>r.bottom)dialog.close();});
  function suspend(){generation++;controller?.abort();clearTimeout(timer);clearTimeout(freshTimer);loading=false;list.setAttribute('aria-busy','false');clear();}
  document.addEventListener('visibilitychange',()=>{if(document.hidden)suspend();else void load();});
  window.addEventListener('online',()=>void load());window.addEventListener('pagehide',suspend);window.addEventListener('pageshow',e=>{if(e.persisted)void load();});
  void load();
})();
