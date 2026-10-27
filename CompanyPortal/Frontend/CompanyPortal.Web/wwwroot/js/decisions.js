(() => {
  const attempted=new Set(),confirmed=new Set();
  const simulationEnabled=!!document.getElementById('portal-simulation');let simulatedRows=[],realRows=[];
  const card=document.querySelector('[data-work-system="library"]');
  const base=document.querySelector('meta[name="companyportal-api-base"]')?.content;
  if(!card||!base)return;
  const list=card.querySelector('#decisions-list'),types=card.querySelector('#decision-types');
  const status=card.querySelector('#decisions-status'),search=card.querySelector('#work-library-search'),reset=card.querySelector('#decision-search-clear');
  const endpoint=path=>new URL(path,new URL(base.replace(/\/?$/,'/'),location.href)).href;
  const make=(tag,cls,text)=>{const node=document.createElement(tag);if(cls)node.className=cls;if(text!==undefined)node.textContent=text;return node;};
  const normalize=text=>text.normalize('NFKC').replace(/[\u064B-\u065F\u0670\u0640]/g,'').replace(/[أإآ]/g,'ا').replace(/ى/g,'ي').toLocaleLowerCase('ar').trim();
  function decisionDate(value,now=new Date()){
    const day=date=>{const parts=new Intl.DateTimeFormat('en-US',{timeZone:'Asia/Muscat',year:'numeric',month:'numeric',day:'numeric'}).formatToParts(date);const part=key=>Number(parts.find(p=>p.type===key).value);return Date.UTC(part('year'),part('month')-1,part('day'))/86400000;};
    const date=new Date(value),days=day(now)-day(date);
    return days===0?'اليوم':days===1?'قبل يوم':days>=2&&days<=6?'قبل '+days+' أيام':new Intl.DateTimeFormat('ar-OM',{dateStyle:'medium',timeZone:'Asia/Muscat'}).format(date);
  }
  let rows=[],category='',controller,generation=0,ready=false,loading=false,timer,searchTimer,fingerprint='',failures=0;
  function clear(){ready=false;rows=[];realRows=[];fingerprint='';document.dispatchEvent(new CustomEvent('portal:decisions',{detail:{rows:[],loaded:false}}));list.replaceChildren();types.replaceChildren();types.closest('label').hidden=true;}
  function schedule(){clearTimeout(timer);if(!document.hidden)timer=setTimeout(()=>void load(),Math.min(300000,60000*2**failures)+Math.random()*5000);}
  function render(){
    reset.hidden=!search.value;if(!ready)return;
    list.replaceChildren();
    const terms=normalize(search.value).split(/\s+/).filter(Boolean);
    const shown=rows.filter(row=>(!category||row.decisionType===category)&&terms.every(term=>normalize(row.title).includes(term)));
    const categories=[...new Set(rows.map(row=>row.decisionType))].sort((a,b)=>a.localeCompare(b,'ar'));
    for(const row of shown){
      const read=row.hasRead||confirmed.has(row.decisionId);
      const link=make('a','portal-decision-link');link.href=endpoint('api/decisions/'+row.decisionId+'/pdf');
      if(row.isSimulation){link.href='#';link.dataset.simulation='true';}else{link.target='_blank';link.rel='noopener noreferrer';}link.title=row.title;link.dataset.decisionId=row.decisionId;link.dataset.state=read?'read':'unread';
      link.setAttribute('aria-label',row.title+' — '+(read?'مقروء':'غير مقروء')+(row.isSimulation?' — معاينة محاكاة محلية':' — فتح PDF في علامة تبويب جديدة'));
      const surface=make('span','portal-doc-surface'),type=make('span','portal-doc-type');type.dataset.tone=String(categories.indexOf(row.decisionType)%8);type.append(make('strong',null,row.decisionType));
      const copy=make('span','portal-doc-copy');copy.append(make('b',null,row.title));
      const meta=make('span','portal-item-meta'),time=make('time',null,decisionDate(row.publishedAt));
      time.dateTime=row.publishedAt;time.title=new Intl.DateTimeFormat('ar-OM',{dateStyle:'long',timeZone:'Asia/Muscat'}).format(new Date(row.publishedAt));if(row.decisionNumber){const number=make('span','portal-decision-number','['+row.decisionNumber+']');number.dir='ltr';type.append(number);}meta.append(time);copy.append(meta);surface.append(type,copy);link.append(surface);list.append(link);
    }
    status.hidden=shown.length>0&&!terms.length;status.textContent=shown.length?'عدد النتائج: '+shown.length:rows.length?'لا توجد قرارات مطابقة.':'لا توجد قرارات متاحة حاليًا.';
    types.value=category;
  }
  function renderTypes(){
    types.replaceChildren();if(category&&!rows.some(row=>row.decisionType===category))category='';
    for(const label of ['',...new Set(rows.map(row=>row.decisionType))]){const option=make('option',null,label||'جميع الأنواع');option.value=label;types.append(option);}
    types.closest('label').hidden=!rows.length;types.value=category;
  }
  async function load(){
    if(document.hidden||loading)return;clearTimeout(timer);loading=true;controller=new AbortController();const current=++generation;
    if(!ready){status.hidden=false;status.textContent='جارٍ تحميل القرارات…';list.setAttribute('aria-busy','true');}
    try{
      const response=await fetch(endpoint('api/decisions'),{credentials:'include',cache:'no-store',signal:AbortSignal.any([controller.signal,AbortSignal.timeout(15000)])});
      if(!response.ok){if(response.status===401||response.status===403)clear();throw new Error(response.status===403?'الحساب غير مسجل أو غير نشط في البوابة.':response.status===401?'تعذر التحقق من حساب Windows.':'تعذر تحديث القرارات. ستتم إعادة المحاولة تلقائيًا.');}
      const data=await response.json();if(current!==generation)return;
      if(!Array.isArray(data)||new Set(data.map(row=>row?.decisionId)).size!==data.length||data.some(row=>!row||typeof row.decisionId!=='string'||!/^[1-9]\d{0,18}$/.test(row.decisionId)
        ||typeof row.decisionType!=='string'||typeof row.title!=='string'||typeof row.hasRead!=='boolean'||typeof row.publishedAt!=='string'||!Number.isFinite(Date.parse(row.publishedAt))))throw new Error('تعذر قراءة بيانات القرارات.');
      data.forEach(row=>{if(confirmed.has(row.decisionId))row.hasRead=true;});realRows=data;const combined=[...simulatedRows,...data],next=JSON.stringify(combined),recovering=failures>0;failures=0;
      if(next!==fingerprint||!ready){rows=combined;fingerprint=next;ready=true;document.dispatchEvent(new CustomEvent('portal:decisions',{detail:{rows,loaded:true}}));renderTypes();render();}
      else if(recovering)render();else list.querySelectorAll('time[datetime]').forEach(time=>time.textContent=decisionDate(time.dateTime));
    }catch(error){if(current!==generation)return;failures=Math.min(3,failures+1);status.hidden=false;status.textContent=error.name==='Error'?error.message:'تعذر الاتصال بخدمة القرارات. ستتم إعادة المحاولة تلقائيًا.';}
    finally{if(current===generation){loading=false;list.setAttribute('aria-busy','false');schedule();}}
  }
  async function mark(id){
    const row=rows.find(row=>row.decisionId===id);if(!row||row.hasRead||attempted.has(id))return;
    attempted.add(id);
    if(row.isSimulation&&simulationEnabled){row.hasRead=true;confirmed.add(id);document.dispatchEvent(new CustomEvent('portal:decision-read',{detail:id}));render();return;}
    try{const response=await fetch(endpoint('api/decisions/'+id+'/read'),{method:'POST',credentials:'include',cache:'no-store',headers:{'X-CompanyPortal-Request':'decision-read'},signal:AbortSignal.timeout(15000)});
      if(!response.ok)throw new Error();confirmed.add(id);rows.filter(r=>r.decisionId===id).forEach(r=>r.hasRead=true);fingerprint=JSON.stringify(rows);
      document.querySelectorAll('[data-decision-id]').forEach(link=>{if(link.dataset.decisionId===id){link.dataset.state='read';link.querySelector('.portal-decision-unread')?.remove();if(link.classList.contains('portal-decision-link'))link.setAttribute('aria-label',row.title+' — مقروء — فتح PDF في علامة تبويب جديدة');}});
      document.dispatchEvent(new CustomEvent('portal:decision-read',{detail:id}));
    }catch{status.hidden=false;status.textContent='تم فتح الملف، لكن تعذر حفظ حالة القراءة. حدّث الصفحة ثم أعد فتحه للمحاولة مجددًا.';document.dispatchEvent(new CustomEvent('portal:decision-read-error',{detail:id}));}
  }
  for(const type of ['click','auxclick'])document.addEventListener(type,event=>{
    if(type==='auxclick'&&event.button!==1||type==='click'&&event.button!==0)return;
    const link=event.target.closest('a[data-decision-id]');if(link){const row=rows.find(r=>r.decisionId===link.dataset.decisionId);if(row?.isSimulation){event.preventDefault();if(type==='click')document.dispatchEvent(new CustomEvent('portal:simulation-open',{detail:{title:row.title,text:'هذه مادة محاكاة محلية. لا يوجد ملف PDF أو سجل في قاعدة البيانات.'}}));}void mark(link.dataset.decisionId);}
  });
  search.addEventListener('input',()=>{reset.hidden=!search.value;clearTimeout(searchTimer);searchTimer=setTimeout(render,150);});
  search.addEventListener('keydown',event=>{if(event.key==='Escape'&&search.value){event.preventDefault();event.stopPropagation();search.value='';clearTimeout(searchTimer);render();}});
  reset.addEventListener('click',()=>{search.value='';clearTimeout(searchTimer);render();search.focus();});
  types.addEventListener('change',()=>{category=types.value;render();});
  if(simulationEnabled)document.addEventListener('portal:simulate',event=>{
    const kind=event.detail?.kind;if(!['decision','notice','alert','reset'].includes(kind))return;
    if(kind==='reset'){simulatedRows=[];document.dispatchEvent(new Event('portal:simulation-reset'));}else{const id='simulation-'+event.detail.id;simulatedRows.unshift({decisionId:id,decisionType:event.detail.decisionType,decisionNumber:new Intl.DateTimeFormat('en-US',{year:'numeric',timeZone:'Asia/Muscat'}).format(new Date())+'/'+event.detail.id,title:event.detail.title,publishedAt:new Date().toISOString(),hasRead:false,isSimulation:true,notices:event.detail.notices??[]});simulatedRows=simulatedRows.slice(0,20);}
    rows=[...simulatedRows,...realRows];ready=true;fingerprint=JSON.stringify(rows);renderTypes();render();document.dispatchEvent(new CustomEvent('portal:decisions',{detail:{rows,loaded:true,origin:'simulation'}}));
    if(kind!=='reset'&&(event.detail.notices??[]).length)document.dispatchEvent(new CustomEvent('portal:simulation-reveal',{detail:{channels:event.detail.notices.map(n=>n.channelId),decisionId:'simulation-'+event.detail.id}}));
  });
  function suspend(){generation++;controller?.abort();loading=false;clearTimeout(timer);clearTimeout(searchTimer);clear();status.hidden=false;status.textContent='جارٍ تحميل القرارات…';}
  document.addEventListener('visibilitychange',()=>{if(document.hidden)suspend();else void load();});
  window.addEventListener('online',()=>void load());window.addEventListener('pagehide',suspend);
  window.addEventListener('pageshow',event=>{if(event.persisted)void load();});
  void load();
})();
