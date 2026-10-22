(() => {
  const sheet=document.getElementById('systems-sheet'),trigger=document.getElementById('systems-sheet-trigger');
  const base=document.querySelector('meta[name="companyportal-api-base"]')?.content;
  if(!sheet||!trigger||!base)return;
  const api=new URL(base.replace(/\/?$/,'/'),location.href);
  const make=(tag,cls,text)=>{const node=document.createElement(tag);if(cls)node.className=cls;if(text)node.textContent=text;return node;};
  const normalize=value=>value.normalize('NFKD').replace(/[\u064B-\u065F\u0670\u0640]/g,'').replace(/[أإآ]/g,'ا').replace(/ى/g,'ي').toLowerCase().trim();
  const content=sheet.querySelector('.portal-systems-sheet-content');
  const filters=make('div','portal-systems-sheet-filters'),label=make('label','portal-systems-sheet-search'),input=make('input');
  input.type='search';input.placeholder='ابحث باسم النظام أو وصفه أو تصنيفه…';input.autocomplete='off';input.id='authorized-systems-search';input.setAttribute('aria-controls','authorized-systems-grid');
  label.htmlFor=input.id;label.append(make('span',null,'البحث عن نظام'),input);
  const categories=make('div','portal-systems-sheet-categories');categories.setAttribute('role','group');categories.setAttribute('aria-label','تصنيفات الأنظمة الإلكترونية');
  filters.append(label,categories);
  const count=make('span','portal-systems-sheet-count');count.setAttribute('aria-live','polite');
  const status=make('p','portal-systems-sheet-empty');status.setAttribute('role','status');
  const retry=make('button','systems-directory-retry','إعادة المحاولة');retry.type='button';retry.hidden=true;
  const grid=make('div','systems-grid portal-systems-sheet-grid');grid.id='authorized-systems-grid';
  content.replaceChildren(filters,count,status,retry,grid);
  let apps=[],category='all',controller=null,generation=0,loaded=false;
  const byId=new Map();
  const categoryKey=app=>app.categoryId===null?'uncategorized':String(app.categoryId);
  function filter(){
    if(!loaded)return;
    const terms=normalize(input.value).split(/\s+/).filter(Boolean);
    let visible=0;
    for(const card of grid.children){
      const app=byId.get(Number(card.dataset.appId));
      card.hidden=(category!=='all'&&categoryKey(app)!==category)||!terms.every(term=>normalize(app.appName+' '+app.description+' '+app.categoryName).includes(term));
      if(!card.hidden)visible++;
    }
    categories.querySelectorAll('button').forEach(button=>button.setAttribute('aria-pressed',String(button.dataset.category===category)));
    count.textContent=visible.toLocaleString('ar-EG-u-nu-latn')+' من '+apps.length.toLocaleString('ar-EG-u-nu-latn')+' نظامًا';
    status.hidden=visible>0;
    status.textContent=apps.length?'لا توجد أنظمة مطابقة للبحث أو التصنيف المحدد.':'لا توجد أنظمة مصرح بها لحسابك حاليًا.';
  }
  function render(){
    const names=new Map([['all','جميع الأنظمة']]);apps.forEach(app=>names.set(categoryKey(app),app.categoryName));
    if(!names.has(category))category='all';
    categories.replaceChildren();
    names.forEach((name,key)=>{const button=make('button',null,name);button.type='button';button.dataset.category=key;button.setAttribute('aria-pressed',String(category===key));categories.append(button);});
    grid.replaceChildren();
    apps.forEach((app,index)=>{
      const card=make('article','systems-card'),top=make('div','systems-card-top'),icon=make('span','systems-icon');
      card.dataset.appId=String(app.appId);
      const glyph=make('i','iconsax');glyph.setAttribute('icon-name','setting-2');glyph.setAttribute('aria-hidden','true');icon.append(glyph);
      top.append(icon,make('span','systems-category',app.categoryName),make('span','systems-sequence',String(index+1)));
      const heading=make('h3',null,app.appName);heading.id='authorized-system-'+app.appId;card.setAttribute('aria-labelledby',heading.id);
      const description=make('p','systems-description',app.description||'');
      const actions=make('div','systems-card-actions'),launch=make('a','systems-details','فتح النظام ↗');
      launch.href=new URL('api/applications/'+app.appId+'/launch',api).href;launch.target='_blank';launch.rel='noopener';launch.setAttribute('aria-label','فتح نظام '+app.appName);
      actions.append(launch);card.append(top,heading,description,actions);grid.append(card);
    });
    filter();
  }
  async function load(){
    controller?.abort();controller=new AbortController();const current=++generation;
    apps=[];byId.clear();loaded=false;grid.replaceChildren();categories.replaceChildren();count.textContent='';retry.hidden=true;
    status.hidden=false;status.textContent='جارٍ تحميل الأنظمة المصرح بها لحسابك…';grid.setAttribute('aria-busy','true');
    try{
      const response=await fetch(new URL('api/applications',api),{credentials:'include',cache:'no-store',signal:AbortSignal.any([controller.signal,AbortSignal.timeout(10000)])});
      if(current!==generation||!sheet.open)return;
      if(!response.ok)throw new Error(response.status===401?'تعذر التحقق من تسجيل الدخول. افتح البوابة بحساب Windows الخاص بك.'
        :response.status===403?'الحساب غير مسجل أو غير نشط في البوابة.':'تعذر تحميل الأنظمة. تحقق من الاتصال بخدمة البوابة ثم أعد المحاولة.');
      const result=await response.json();
      if(current!==generation||!sheet.open)return;
      if(!Array.isArray(result)||new Set(result.map(app=>app?.appId)).size!==result.length||result.some(app=>!Number.isInteger(app.appId)||app.appId<1
        ||typeof app.appName!=='string'||typeof app.description!=='string'||typeof app.categoryName!=='string'
        ||(app.categoryId!==null&&(!Number.isInteger(app.categoryId)||app.categoryId<1))))throw new Error('تعذر قراءة دليل الأنظمة. أعد المحاولة.');
      apps=result;apps.forEach(app=>byId.set(app.appId,app));loaded=true;render();
    }catch(error){
      if(current!==generation||!sheet.open)return;
      status.textContent=error.name==='Error'?error.message:'تعذر الاتصال بخدمة الأنظمة. أعد المحاولة.';retry.hidden=false;
    }finally{if(current===generation)grid.setAttribute('aria-busy','false');}
  }
  function open(){
    if(sheet.open)return;
    input.value='';category='all';sheet.showModal();trigger.setAttribute('aria-expanded','true');input.focus();load();
  }
  trigger.setAttribute('aria-expanded','false');
  trigger.addEventListener('click',event=>{event.preventDefault();open();});
  sheet.querySelector('.portal-systems-sheet-close').addEventListener('click',()=>sheet.close());
  sheet.addEventListener('close',()=>{generation++;controller?.abort();apps=[];byId.clear();loaded=false;grid.replaceChildren();categories.replaceChildren();count.textContent='';trigger.setAttribute('aria-expanded','false');trigger.focus();});
  sheet.addEventListener('click',event=>{const bounds=sheet.getBoundingClientRect();if(event.target===sheet&&(event.clientX<bounds.left||event.clientX>bounds.right||event.clientY<bounds.top||event.clientY>bounds.bottom))sheet.close();});
  input.addEventListener('input',filter);retry.addEventListener('click',load);
  categories.addEventListener('click',event=>{const button=event.target.closest('[data-category]');if(button){category=button.dataset.category;filter();}});
  document.addEventListener('click',event=>{if(event.target.closest('a[href="#library"],.portal-add-system')){event.preventDefault();open();}});
  window.addEventListener('pagehide',()=>{generation++;controller?.abort();});
})();
