(() => {
  const panel=document.getElementById('portal-search-panel'),input=document.getElementById('portal-search-input');
  const results=document.getElementById('portal-search-results'),status=document.getElementById('portal-search-status');
  const filters=document.getElementById('authorized-search-filters'),error=document.getElementById('authorized-search-error'),retry=document.getElementById('authorized-search-retry');
  const base=document.querySelector('meta[name="companyportal-api-base"]')?.content;
  if(!panel||!input||!results||!status||!filters||!error||!retry||!base)return;
  const endpoint=path=>new URL(path,new URL(base.replace(/\/?$/,'/'),location.href)).href;
  const make=(tag,cls,text)=>{const node=document.createElement(tag);if(cls)node.className=cls;if(text!==undefined)node.textContent=text;return node;};
  const normalize=text=>text.normalize('NFKD').replace(/[\u064B-\u065F\u0670\u0640]/g,'').replace(/[أإآ]/g,'ا').replace(/ى/g,'ي').toLocaleLowerCase('ar').trim();
  const sources=[{key:'documents',label:'الاستمارات والوثائق',path:'api/documents'},{key:'apps',label:'الأنظمة الإلكترونية',path:'api/applications'}];
  let active=false,loading=false,generation=0,controller,timer,scope='all',items=[],options=[],selected=-1,failures=[];
  function clearResults(){results.replaceChildren();options=[];selected=-1;input.removeAttribute('aria-activedescendant');}
  function clear(){items=[];failures=[];clearResults();error.textContent='';error.hidden=true;retry.hidden=true;status.textContent='';}
  function select(index){
    selected=index;options.forEach((option,i)=>option.setAttribute('aria-selected',String(i===index)));
    if(index>=0){input.setAttribute('aria-activedescendant',options[index].id);options[index].scrollIntoView({block:'nearest'});}
    else input.removeAttribute('aria-activedescendant');
  }
  function render(){
    if(!active)return;
    clearResults();results.setAttribute('aria-busy',String(loading));
    filters.querySelectorAll('button').forEach(button=>button.setAttribute('aria-pressed',String(button.dataset.searchSource===scope)));
    error.hidden=!failures.length;error.textContent=failures.join(' ');retry.hidden=!failures.length;
    if(loading){status.textContent='جارٍ تحميل الأنظمة والملفات المصرح بها…';return;}
    const terms=normalize(input.value).split(/\s+/).filter(Boolean);
    if(!terms.length){status.textContent='ابحث في الأنظمة والملفات المصرح بها لحسابك';results.append(make('p','portal-search-empty','اكتب اسم استمارة، وثيقة أو نظام للبحث.'));return;}
    const matches=items.filter(item=>(scope==='all'||scope===item.source)&&terms.every(term=>normalize(item.title+' '+item.text).includes(term)));
    status.textContent=matches.length.toLocaleString('ar-OM')+' نتيجة'+(failures.length?' في المصادر المتاحة':'');
    for(const source of sources){
      const entries=matches.filter(item=>item.source===source.key);if(!entries.length)continue;
      const group=make('div','portal-authorized-search-group');group.setAttribute('role','group');group.setAttribute('aria-label',source.label);
      const heading=make('h3','portal-authorized-search-group-title',source.label+' ('+entries.length.toLocaleString('ar-OM')+')');group.append(heading);
      for(const item of entries){
        const link=make('a','portal-search-option portal-authorized-search-option');link.id='authorized-search-result-'+options.length;
        link.href=item.href;link.rel='noopener noreferrer';if(item.newTab)link.target='_blank';link.setAttribute('role','option');link.setAttribute('aria-selected','false');
        let icon;
        if(item.fileKind==='pdf'||item.fileKind==='docx'){
          icon=make('img','portal-search-file-icon');icon.src=new URL('assets/icons/file-'+item.fileKind+'.svg',document.baseURI).href;icon.alt='';icon.width=44;icon.height=44;
        }else{icon=make('i','iconsax');icon.setAttribute('icon-name',item.source==='apps'?'setting-2':'document-text-1');}
        icon.setAttribute('aria-hidden','true');
        const copy=make('span');copy.append(make('strong',null,item.title),make('small',null,item.detail));
        if(item.description)copy.append(make('small','portal-authorized-search-description',item.description));
        copy.append(make('small','portal-authorized-search-action',item.action));
        const arrow=make('span',null,item.newTab?'↗':'↓');arrow.setAttribute('aria-hidden','true');link.append(icon,copy,arrow);
        link.setAttribute('aria-label',item.title+' — '+item.action);
        const index=options.length;link.addEventListener('click',()=>select(index));options.push(link);group.append(link);
      }
      results.append(group);
    }
    if(!matches.length)results.append(make('p','portal-search-empty',failures.length?'لا توجد نتائج في المصادر المتاحة. أعد المحاولة لتحميل المصادر الأخرى.':'لا توجد نتائج مطابقة ضمن الأنظمة والملفات المصرح بها لحسابك.'));
  }
  function mapRows(key,data){
    if(!Array.isArray(data))throw new Error('Invalid search catalog');
    if(key==='apps'){
      if(new Set(data.map(row=>row?.appId)).size!==data.length||data.some(row=>!row||!Number.isSafeInteger(row.appId)||row.appId<1||!['appName','description','categoryName'].every(field=>typeof row[field]==='string')))throw new Error('Invalid apps');
      return data.map(row=>({source:key,title:row.appName,text:row.description+' '+row.categoryName,detail:row.categoryName,description:row.description,action:'فتح النظام في علامة تبويب جديدة',href:endpoint('api/applications/'+row.appId+'/launch'),newTab:true}));
    }
    if(new Set(data.map(row=>row?.documentId)).size!==data.length||data.some(row=>!row||typeof row.documentId!=='string'||! /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(row.documentId)||!['documentName','fileName','folderName','folderPath'].every(field=>typeof row[field]==='string')||typeof row.isPdf!=='boolean'))throw new Error('Invalid documents');
    return data.map(row=>({source:key,title:row.documentName,text:row.fileName+' '+row.folderPath,detail:row.fileName,fileKind:row.isPdf?'pdf':/\.docx$/i.test(row.fileName)?'docx':'other',action:row.isPdf?'عرض PDF في علامة تبويب جديدة':'تنزيل الملف',href:endpoint('api/documents/'+row.documentId+'/file'),newTab:row.isPdf}));
  }
  async function load(){
    controller?.abort();controller=new AbortController();const current=++generation;clear();loading=true;render();
    const signal=AbortSignal.any([controller.signal,AbortSignal.timeout(10000)]);
    const loaded=await Promise.allSettled(sources.map(async source=>{
      const response=await fetch(endpoint(source.path),{credentials:'include',cache:'no-store',signal});
      if(!response.ok)throw new Error('Search source unavailable');
      return mapRows(source.key,await response.json());
    }));
    if(current!==generation||!active)return;
    loaded.forEach((result,index)=>{if(result.status==='fulfilled')items.push(...result.value);else failures.push('تعذر تحميل '+sources[index].label+'.');});
    loading=false;render();
  }
  window.CompanyPortalAuthorizedSearch={
    open(){active=true;scope='all';filters.hidden=false;load();},
    close(){active=false;generation++;clearTimeout(timer);controller?.abort();loading=false;clear();filters.hidden=true;results.setAttribute('aria-busy','false');},
    search(){clearTimeout(timer);clearResults();timer=setTimeout(render,200);},
    key(event){
      if(event.key==='ArrowDown'||event.key==='ArrowUp'){event.preventDefault();if(options.length)select(selected<0?(event.key==='ArrowDown'?0:options.length-1):(selected+(event.key==='ArrowDown'?1:-1)+options.length)%options.length);}
      else if(event.key==='Enter'){event.preventDefault();clearTimeout(timer);if(selected<0)render();options[Math.max(0,selected)]?.click();}
    }
  };
  filters.addEventListener('click',event=>{const button=event.target.closest('[data-search-source]');if(button){scope=button.dataset.searchSource;clearTimeout(timer);render();}});
  retry.addEventListener('click',load);
  document.addEventListener('visibilitychange',()=>{if(!active)return;if(document.hidden){generation++;controller?.abort();clearTimeout(timer);loading=false;clear();}else load();});
  window.addEventListener('pagehide',()=>{if(active)window.CompanyPortalAuthorizedSearch.close();});
  window.addEventListener('pageshow',event=>{if(event.persisted&&!panel.hidden&&panel.dataset.searchMode!=='phone')window.CompanyPortalAuthorizedSearch.open();});
})();
