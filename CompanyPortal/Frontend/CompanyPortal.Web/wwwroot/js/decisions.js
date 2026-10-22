(() => {
  const card=document.querySelector('[data-work-system="library"]');
  const base=document.querySelector('meta[name="companyportal-api-base"]')?.content;
  if(!card||!base)return;
  const list=card.querySelector('#decisions-list'),types=card.querySelector('#decision-types');
  const status=card.querySelector('#decisions-status'),refresh=card.querySelector('#decisions-refresh');
  const search=card.querySelector('#work-library-search');
  const endpoint=path=>new URL(path,new URL(base.replace(/\/?$/,'/'),location.href)).href;
  const make=(tag,cls,text)=>{const node=document.createElement(tag);if(cls)node.className=cls;if(text!==undefined)node.textContent=text;return node;};
  const normalize=text=>text.normalize('NFKC').replace(/[\u064B-\u065F\u0670\u0640]/g,'').replace(/[أإآ]/g,'ا').replace(/ى/g,'ي').toLocaleLowerCase('ar').trim();
  let rows=[],category='',controller,generation=0,ready=false;
  function clear(){ready=false;rows=[];list.replaceChildren();types.replaceChildren();types.hidden=true;}
  function render(){
    if(!ready)return;
    list.replaceChildren();
    const query=normalize(search.value);
    const shown=rows.filter(row=>(!category||row.decisionType===category)&&normalize(row.title+' '+row.decisionType).includes(query));
    for(const row of shown){
      const link=make('a','portal-decision-link');link.href=endpoint('api/decisions/'+row.decisionId+'/pdf');
      link.target='_blank';link.rel='noopener noreferrer';link.dataset.decisionId=row.decisionId;
      link.setAttribute('aria-label',row.title+' — فتح PDF في علامة تبويب جديدة');
      const surface=make('span','portal-doc-surface'),type=make('span','portal-doc-type');type.append(make('strong',null,row.decisionType));
      const copy=make('span','portal-doc-copy');copy.append(make('b',null,row.title));
      const meta=make('span','portal-item-meta'),time=make('time',null,new Intl.DateTimeFormat('ar-OM',{dateStyle:'medium',timeStyle:'short'}).format(new Date(row.publishedAt)));
      time.dateTime=row.publishedAt;meta.append(time);copy.append(meta);surface.append(type,copy);link.append(surface);list.append(link);
    }
    status.hidden=shown.length>0;status.textContent=rows.length?'لا توجد قرارات مطابقة.':'لا توجد قرارات متاحة حاليًا.';
    types.querySelectorAll('button').forEach(button=>button.setAttribute('aria-pressed',String(button.dataset.type===category)));
  }
  async function load(){
    controller?.abort();controller=new AbortController();const current=++generation;
    clear();category='';status.hidden=false;status.textContent='جارٍ تحميل القرارات…';refresh.disabled=true;list.setAttribute('aria-busy','true');
    try{
      const response=await fetch(endpoint('api/decisions'),{credentials:'include',cache:'no-store',signal:AbortSignal.any([controller.signal,AbortSignal.timeout(15000)])});
      if(!response.ok)throw new Error(response.status===403?'الحساب غير مسجل أو غير نشط في البوابة.':response.status===401?'تعذر التحقق من حساب Windows.':'تعذر تحميل القرارات. أعد المحاولة.');
      const data=await response.json();if(current!==generation)return;
      if(!Array.isArray(data)||new Set(data.map(row=>row?.decisionId)).size!==data.length||data.some(row=>!row||typeof row.decisionId!=='string'||!/^[1-9]\d{0,18}$/.test(row.decisionId)
        ||typeof row.decisionType!=='string'||typeof row.title!=='string'||typeof row.publishedAt!=='string'||!Number.isFinite(Date.parse(row.publishedAt))))throw new Error('تعذر قراءة بيانات القرارات.');
      rows=data;ready=true;
      for(const label of ['',...new Set(rows.map(row=>row.decisionType))]){
        const button=make('button',null,label||'الكل');button.type='button';button.dataset.type=label;types.append(button);
      }
      types.hidden=!rows.length;render();
    }catch(error){if(current!==generation)return;clear();status.hidden=false;status.textContent=error.name==='Error'?error.message:'تعذر الاتصال بخدمة القرارات. أعد المحاولة.';}
    finally{if(current===generation){refresh.disabled=false;list.setAttribute('aria-busy','false');}}
  }
  search.addEventListener('input',render);
  types.addEventListener('click',event=>{const button=event.target.closest('button');if(button){category=button.dataset.type;render();}});
  refresh.addEventListener('click',load);
  // Clear permission-filtered content while away; never restore it from browser storage.
  document.addEventListener('visibilitychange',()=>{if(document.hidden){generation++;controller?.abort();clear();status.hidden=false;status.textContent='جارٍ تحميل القرارات…';}else load();});
  window.addEventListener('pagehide',()=>{generation++;controller?.abort();clear();});
  window.addEventListener('pageshow',event=>{if(event.persisted)load();});
  load();
})();
