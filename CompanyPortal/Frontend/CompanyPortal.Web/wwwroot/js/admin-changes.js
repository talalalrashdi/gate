/* One batch per visited section; refresh only after successful writes to that section. */
(() => {
  const core=window.AdminCore,cache=new Map(),pending=new Map(),versions=new Map(),timers=new Map(),queued=new Set(),failed=new Set();
  const key=(type,id)=>JSON.stringify([type,String(id)]);
  const formatter=new Intl.DateTimeFormat('ar-OM',{dateStyle:'medium',timeStyle:'short',timeZone:'Asia/Muscat'});
  const date=value=>formatter.format(new Date(/Z$|[+-]\d\d:\d\d$/.test(value)?value:value+'+04:00'));
  function render(section){
    document.querySelectorAll('[data-admin-item-section]').forEach(element=>{
      if(element.dataset.adminItemSection!==section)return;
      let label=element.querySelector(':scope > .admin-last-change');
      if(!label){label=document.createElement('small');label.className='admin-last-change';element.append(label);}
      const rows=cache.get(section),row=rows?.get(key(element.dataset.adminItemType,element.dataset.adminItemId));
      const text=row?'آخر تعديل: '+row.displayName+' · '+date(row.changedAt):rows?'لا يوجد تعديل مسجل':failed.has(section)?'تعذر تحميل آخر تعديل؛ أعد فتح القسم للمحاولة.':'جارٍ تحميل آخر تعديل…';
      if(label.textContent!==text)label.textContent=text;
    });
  }
  async function load(section){
    if(['overview','history'].includes(section)||!core.can(section)||cache.has(section)||pending.has(section))return;
    const version=versions.get(section)||0;failed.delete(section);
    const task=(async()=>{try{
      const r=await core.request('api/admin/changes/latest?section='+encodeURIComponent(section));
      if(!r.ok)throw new Error();const rows=await r.json();
      if(core.can(section)&&version===(versions.get(section)||0))cache.set(section,new Map(rows.map(row=>[key(row.itemType,row.itemId),row])));
    }catch{
      failed.add(section);render(section);
    }finally{pending.delete(section);if(cache.has(section))render(section);else if(version!==(versions.get(section)||0))void load(section);}})();
    pending.set(section,task);
  }
  function tag(element,section,type,id){
    if(id===null||id===undefined||id===''){
      delete element.dataset.adminItemSection;delete element.dataset.adminItemType;delete element.dataset.adminItemId;
      element.querySelector(':scope > .admin-last-change')?.remove();return;
    }
    Object.assign(element.dataset,{adminItemSection:section,adminItemType:type,adminItemId:String(id)});
    if(!queued.has(section)){queued.add(section);queueMicrotask(()=>{queued.delete(section);render(section);});}
  }
  const routes={events:'events','admin-cards':'cards','application-directory':'applications','document-library':'documents','safety-library':'safety','fixed-orders':'fixed-orders','header-content':'header-content',media:'media','admin-images':'images','admin-themes':'themes'};
  document.addEventListener('admin:saved',e=>{
    const section=e.detail.header==='decision-notices'?(e.detail.path.match(/decision-notices\/([12])/)[1]==='1'?'notices':'alerts'):routes[e.detail.header];
    if(!section)return;versions.set(section,(versions.get(section)||0)+1);cache.delete(section);
    clearTimeout(timers.get(section));timers.set(section,setTimeout(()=>void load(section),250));
  });
  document.addEventListener('admin:section',e=>void load(e.detail.section));
  document.addEventListener('admin:access',()=>{
    for(const section of cache.keys())if(!core.can(section))cache.delete(section);
    document.querySelectorAll('[data-admin-item-section]').forEach(e=>{if(!core.can(e.dataset.adminItemSection))e.querySelector(':scope > .admin-last-change')?.remove();});
  });
  window.AdminChanges={tag,date};
  if(document.body.dataset.adminCurrent)queueMicrotask(()=>void load(document.body.dataset.adminCurrent));
})();
