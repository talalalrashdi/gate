(() => {
  const section=document.getElementById('digital-library'),base=document.querySelector('meta[name="companyportal-api-base"]')?.content;
  if(!section||!base)return;
  const endpoint=path=>new URL('api/document-library'+path,new URL(base.replace(/\/?$/,'/'),location.href)).href;
  const results=section.querySelector('#documents-results'),categories=section.querySelector('.documents-categories'),status=section.querySelector('#documents-status'),retry=section.querySelector('#documents-retry');
  const dialog=section.querySelector('#documents-dialog'),body=section.querySelector('#documents-dialog-body');
  const make=(tag,cls,text)=>{const n=document.createElement(tag);if(cls)n.className=cls;if(text!==undefined)n.textContent=text;return n;};
  const reads=window.CompanyPortalLibraryReads('documents',endpoint);
  const lazy=window.CompanyPortalLazy?.gate(section)||{run:f=>f(),clear(){}};
  let tabs=[],selected,controller,generation=0;
  function clear(){lazy.clear();reads.clear();tabs=[];categories.replaceChildren();results.replaceChildren();section.querySelector('#documents-count').textContent='';section.querySelector('#documents-current-title').textContent='الوثائق';dialog.close();body.replaceChildren();}
  function open(doc,tab){
    section.querySelector('#documents-dialog-title').textContent=doc.documentName;
    section.querySelector('#documents-dialog-category').textContent=tab.tabName;
    section.querySelector('#documents-dialog-description').textContent='استعراض ملف PDF';
    const url=endpoint('/'+doc.documentId+'/file');
    const link=make('a',null,'فتح ملف PDF في نافذة مستقلة ↗');link.href=url;link.target='_blank';link.rel='noopener';
    const frame=make('iframe');frame.src=url;frame.title=doc.documentName;
    body.replaceChildren(link,frame);dialog.showModal();void reads.open(doc);
  }
  function tabBadges(){
    categories.querySelectorAll('[data-library-tab]').forEach(button=>{
      const tab=tabs.find(t=>String(t.documentTabId)===button.getAttribute('data-library-tab'));
      button.querySelector('.library-tab-new')?.remove();
      if(tab?.documents.some(d=>d.hasRead===false))button.append(make('span','library-item-new library-tab-new','جديد'));
    });
  }
  function render(){lazy.run(renderVisible);}
  function renderVisible(){
    const tab=tabs.find(t=>t.documentTabId===selected)||tabs[0];selected=tab?.documentTabId;
    categories.replaceChildren(...tabs.map(t=>{const b=make('button',null,t.tabName);b.type='button';b.setAttribute('aria-pressed',String(t===tab));b.setAttribute('data-library-tab',t.documentTabId);if(t.documents.some(d=>d.hasRead===false))b.append(make('span','library-item-new library-tab-new','جديد'));b.addEventListener('click',()=>{selected=t.documentTabId;render();categories.querySelector('[aria-pressed="true"]')?.focus();});return b;}));
    section.querySelector('#documents-current-title').textContent=tab?.tabName||'الوثائق';
    const docs=tab?.documents||[];section.querySelector('#documents-count').textContent='عدد الوثائق: '+docs.length;
    results.replaceChildren(...docs.map(doc=>{
      const row=make('article','documents-row');row.setAttribute('role','listitem');row.setAttribute('data-document-id',doc.documentId);
      const icon=make('span','documents-file-icon','PDF');icon.setAttribute('aria-hidden','true');
      const content=make('div');if(doc.hasRead===false)content.append(make('span','library-item-new','جديد'));content.append(make('h4',null,doc.documentName),make('small',null,'PDF'));
      const button=make('button',null,'استعراض الملف ↗');button.type='button';button.setAttribute('aria-label','استعراض '+doc.documentName);button.addEventListener('click',()=>open(doc,tab));
      row.append(icon,content,button);return row;
    }));
    status.textContent=tabs.length?'اختر الوثيقة لاستعراضها.':'لا توجد وثائق متاحة حاليًا.';
  }
  async function load(){
    controller?.abort();controller=new AbortController();const current=++generation;
    clear();retry.hidden=true;status.textContent='جارٍ تحميل الوثائق…';results.setAttribute('aria-busy','true');
    try{
      const response=await fetch(endpoint(''),{credentials:'include',cache:'no-store',signal:AbortSignal.any([controller.signal,AbortSignal.timeout(15000)])});
      if(current!==generation)return;
      if(!response.ok)throw new Error(String(response.status));
      const data=await response.json();if(current!==generation)return;
      tabs=data;reads.catalog(tabs,id=>{results.querySelectorAll('[data-document-id]').forEach(row=>{if(row.getAttribute('data-document-id')===id)row.querySelector('.library-item-new')?.remove();});tabBadges();});render();
    }catch(e){if(current!==generation)return;clear();status.textContent=e.message==='401'||e.message==='403'?'حسابك غير مخوّل لعرض الوثائق.':'تعذر تحميل الوثائق. تحقق من الاتصال وأعد المحاولة.';retry.hidden=false;}
    finally{if(current===generation)results.setAttribute('aria-busy','false');}
  }
  section.querySelector('#documents-close').addEventListener('click',()=>dialog.close());dialog.addEventListener('close',()=>body.replaceChildren());retry.addEventListener('click',load);
  document.addEventListener('visibilitychange',()=>{if(document.hidden){++generation;controller?.abort();clear();}else load();});
  window.addEventListener('pagehide',()=>{++generation;controller?.abort();clear();});window.addEventListener('pageshow',e=>{if(e.persisted)load();});load();
})();
