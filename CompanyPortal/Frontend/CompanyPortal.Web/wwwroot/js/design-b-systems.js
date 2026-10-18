(() => {
  const root=document.querySelector('.sc-section'),workspace=document.getElementById('workspace-cards');
  if(!root||!workspace)return;
  const cards=[...root.querySelectorAll('[data-system-id]')];
  const systems=new Map(cards.map(card=>[card.dataset.systemId,{id:card.dataset.systemId,category:card.dataset.systemCategory,categoryName:card.querySelector('.sc-category').textContent,title:card.querySelector('h3').textContent,description:card.querySelector('.sc-description').textContent,icon:card.dataset.systemIcon,card}]));
  const storageKey='clerio-design-b-pinned-systems-v1',defaults=['library','inbox','requests','services'];
  const search=root.querySelector('#sc-search'),categories=[...root.querySelectorAll('[data-sc-category]')],pinnedFilter=root.querySelector('#sc-pinned-filter');
  const motion=matchMedia('(prefers-reduced-motion: reduce)');
  let textureVisible=false;
  const updateTexture=()=>root.classList.toggle('sc-texture-active',textureVisible&&!document.hidden&&!motion.matches);
  const textureObserver=new IntersectionObserver(entries=>{textureVisible=entries[0].isIntersecting;if(textureVisible)root.classList.add('sc-has-entered');updateTexture();},{threshold:0});
  textureObserver.observe(root.querySelector('.sc-heading'));
  document.addEventListener('visibilitychange',updateTexture);motion.addEventListener('change',updateTexture);
  let category='all',onlyPinned=false;
  function decode(raw){try{const value=JSON.parse(raw);return Array.isArray(value)?new Set(value.filter(id=>typeof id==='string'&&systems.has(id))):new Set(defaults);}catch{return new Set(defaults);}}
  let pinned;try{pinned=decode(localStorage.getItem(storageKey));}catch{pinned=new Set(defaults);}
  const normalize=value=>value.normalize('NFKD').replace(/[\u064B-\u065F\u0670\u0640]/g,'').replace(/[أإآ]/g,'ا').replace(/ى/g,'ي').toLowerCase().trim();
  const number=value=>value.toLocaleString('ar-EG-u-nu-latn');
  function make(tag,className,text){const el=document.createElement(tag);if(className)el.className=className;if(text)el.textContent=text;return el;}
  function icon(name){const el=make('i','iconsax');el.setAttribute('icon-name',name);el.setAttribute('aria-hidden','true');return el;}
  function pinButton(id){const button=make('button','sc-pin');button.type='button';button.dataset.scPin=id;button.append(icon('add'),make('span',null,'تثبيت في ساحة العمل'));return button;}
  const workCards=new Map([...workspace.querySelectorAll('[data-work-system]')].map(card=>[card.dataset.workSystem,card]));
  systems.forEach(system=>{
    let card=workCards.get(system.id);
    if(!card){
      card=make('article','b-work-card sc-work-added');card.dataset.workSystem=system.id;card.dataset.widgetCategory=({daily:'communication',people:'attendance',operations:'services',finance:'forms',knowledge:'applications'})[system.category]||'applications';
      const heading=make('header','b-work-heading'),badge=make('div','b-work-icon'),copy=make('div'),title=make('h2',null,system.title);
      title.id=`work-system-${system.id}`;card.setAttribute('aria-labelledby',title.id);badge.append(icon(system.icon));copy.append(title);heading.append(badge,copy);
      const details=make('button','sc-details','تشغيل النظام ←');details.type='button';details.dataset.scDetails=system.id;
      card.append(heading,make('span','sc-work-category',system.categoryName),details);workspace.append(card);workCards.set(system.id,card);
    }
    const label=make('div','sc-work-label');label.append(pinButton(system.id));card.querySelector(':scope > .b-work-heading').append(label);
  });
  const emptyWorkspace=make('div','sc-work-empty');emptyWorkspace.append(make('h3',null,'مساحة العمل تبدأ باختياراتك'),make('p',null,'ثبّت الأنظمة التي تستخدمها من دليل الأنظمة.'));
  const browse=make('a',null,'استكشف الأنظمة ←');browse.href='#library';emptyWorkspace.append(browse);workspace.append(emptyWorkspace);
  const dialog=make('dialog','sc-system-dialog');dialog.setAttribute('aria-labelledby','sc-dialog-title');
  const dialogTop=make('div','sc-dialog-top'),dialogCategory=make('span'),close=make('button',null,'×');close.type='button';close.setAttribute('aria-label','إغلاق نافذة النظام');dialogTop.append(dialogCategory,close);
  const dialogTitle=make('h2');dialogTitle.id='sc-dialog-title';const dialogCopy=make('p'),dialogPin=pinButton('');
  dialog.append(dialogTop,dialogTitle,dialogCopy,make('small',null,'لم يُربط هذا النظام برابط تشغيل فعلي بعد. يمكنك تثبيته في مساحة العمل، وسيُتاح التشغيل عند إضافة رابط النظام.'),dialogPin);document.body.append(dialog);close.addEventListener('click',()=>dialog.close());
  const sheet=document.getElementById('systems-sheet'),sheetTrigger=document.getElementById('systems-sheet-trigger');
  if(sheet&&sheetTrigger){
    const sheetContent=sheet.querySelector('.b-systems-sheet-content'),sheetSearch=make('label','b-systems-sheet-search');
    sheetSearch.innerHTML='<span>البحث عن نظام</span><input type="search" placeholder="ابحث باسم النظام أو الخدمة…">';
    const sheetCategories=make('div','b-systems-sheet-categories');sheetCategories.setAttribute('role','group');sheetCategories.setAttribute('aria-label','تصنيفات الأنظمة الإلكترونية');
    const categoryNames=new Map([['all','جميع الأنظمة'],['daily','العمل اليومي'],['people','الموظفون'],['operations','التشغيل والخدمات'],['finance','المالية والمشتريات'],['knowledge','المعرفة والتقنية']]);
    categoryNames.forEach((label,id)=>{const button=make('button',null,label);button.type='button';button.dataset.sheetCategory=id;button.setAttribute('aria-pressed',String(id==='all'));sheetCategories.append(button);});
    const sheetCount=make('span','b-systems-sheet-count'),sheetGrid=make('div','sc-grid b-systems-sheet-grid'),sheetEmpty=make('p','b-systems-sheet-empty','لا توجد أنظمة مطابقة للبحث.');sheetEmpty.hidden=true;
    cards.forEach(card=>{const clone=card.cloneNode(true);clone.removeAttribute('aria-labelledby');clone.querySelector('h3')?.removeAttribute('id');sheetGrid.append(clone);});
    const sheetFilters=make('div','b-systems-sheet-filters');sheetFilters.append(sheetSearch,sheetCategories);
    sheetContent.append(sheetFilters,sheetCount,sheetGrid,sheetEmpty);
    let sheetCategory='all';const sheetInput=sheetSearch.querySelector('input');
    function filterSheet(){const terms=normalize(sheetInput.value).split(/\s+/).filter(Boolean);let count=0;[...sheetGrid.children].forEach(card=>{const system=systems.get(card.dataset.systemId),visible=(sheetCategory==='all'||system.category===sheetCategory)&&terms.every(term=>normalize(`${system.title} ${system.description} ${system.categoryName}`).includes(term));card.hidden=!visible;if(visible)count++;});sheetCategories.querySelectorAll('button').forEach(button=>button.setAttribute('aria-pressed',String(button.dataset.sheetCategory===sheetCategory)));sheetCount.textContent=`${number(count)} من ${number(systems.size)} نظامًا`;sheetEmpty.hidden=count!==0;}
    sheetTrigger.addEventListener('click',event=>{event.preventDefault();filterSheet();if(!sheet.open)sheet.showModal();});
    document.addEventListener('click',event=>{
      if(root.hidden&&event.target.closest('a[href="#library"]')){event.preventDefault();sheetTrigger.click();}
    });
    sheet.querySelector('.b-systems-sheet-close').addEventListener('click',()=>sheet.close());
    sheet.addEventListener('click',event=>{const bounds=sheet.getBoundingClientRect();if(event.target===sheet&&(event.clientX<bounds.left||event.clientX>bounds.right||event.clientY<bounds.top||event.clientY>bounds.bottom))sheet.close();});
    sheet.addEventListener('close',()=>sheetTrigger.focus());sheetInput.addEventListener('input',filterSheet);
    sheetCategories.addEventListener('click',event=>{const button=event.target.closest('[data-sheet-category]');if(!button)return;sheetCategory=button.dataset.sheetCategory;filterSheet();});
  }
  function filter(){
    const terms=normalize(search.value).split(/\s+/).filter(Boolean);let count=0;
    systems.forEach(system=>{const text=normalize(system.title+' '+system.description+' '+system.categoryName);const visible=(category==='all'||system.category===category)&&(!onlyPinned||pinned.has(system.id))&&terms.every(term=>text.includes(term));system.card.hidden=!visible;if(visible)count++;});
    categories.forEach(button=>button.setAttribute('aria-pressed',String(button.dataset.scCategory===category)));pinnedFilter.setAttribute('aria-pressed',String(onlyPinned));
    root.querySelector('#sc-results').textContent=`${number(count)} من ${number(systems.size)} نظامًا${onlyPinned?' · في مساحة العمل':''}`;root.querySelector('#sc-empty').hidden=count!==0;
  }
  function paintPin(button){const id=button.dataset.scPin,system=systems.get(id);if(!system)return;const selected=pinned.has(id);button.setAttribute('aria-pressed',String(selected));button.setAttribute('aria-label',selected?`إزالة تثبيت ${system.title} من مساحة العمل`:`تثبيت في ساحة العمل: ${system.title}`);button.title=button.getAttribute('aria-label');button.querySelector('span').textContent=selected?'إزالة التثبيت':'تثبيت في ساحة العمل';button.querySelector('i').setAttribute('icon-name',selected?'archive-book':'add');}
  function sync(){
    systems.forEach(system=>{const selected=pinned.has(system.id);system.card.classList.toggle('is-pinned',selected);system.card.querySelector('[data-sc-presence]').hidden=!selected;workCards.get(system.id).hidden=!selected;});
    document.querySelectorAll('[data-sc-pin]').forEach(paintPin);root.querySelector('#sc-filter-count').textContent=number(pinned.size);emptyWorkspace.hidden=pinned.size!==0||!!workspace.querySelector('[data-work-group]');filter();
    requestAnimationFrame(()=>{if(typeof updateWorkspaceNavigation==='function')updateWorkspaceNavigation();});
  }
  function reset(){search.value='';category='all';onlyPinned=false;filter();}
  function focusCatalog(){reset();root.scrollIntoView({behavior:motion.matches?'instant':'smooth',block:'start'});search.focus({preventScroll:true});}
  search.addEventListener('input',filter);categories.forEach(button=>button.addEventListener('click',()=>{category=button.dataset.scCategory;filter();}));pinnedFilter.addEventListener('click',()=>{onlyPinned=!onlyPinned;filter();});root.querySelector('#sc-reset').addEventListener('click',()=>{reset();search.focus();});
  document.querySelector('.b-add-system')?.addEventListener('click',focusCatalog);browse.addEventListener('click',event=>{event.preventDefault();focusCatalog();});
  document.addEventListener('click',event=>{
    const pin=event.target.closest('[data-sc-pin]');
    if(pin&&systems.has(pin.dataset.scPin)){
      const id=pin.dataset.scPin,adding=!pinned.has(id);if(adding)pinned.add(id);else pinned.delete(id);
      let saved=true;try{localStorage.setItem(storageKey,JSON.stringify([...pinned]));}catch{saved=false;}
      sync();
      if(pin.closest('[hidden]')){const next=pin.closest('#workspace-cards')?workspace.querySelector('[data-work-system]:not([hidden]) [data-sc-pin]')||browse:root.querySelector('.sc-card:not([hidden]) [data-sc-pin]')||search;next.focus({preventScroll:true});}
      if(typeof showToast==='function')showToast(`${adding?'تم تثبيت':'تمت إزالة تثبيت'} ${systems.get(id).title}${adding?' في مساحة العمل':''}${saved?'':' · تعذّر الحفظ الدائم؛ الاختيار لهذه الجلسة فقط'}`);
      return;
    }
    const details=event.target.closest('[data-sc-details]');if(!details)return;const system=systems.get(details.dataset.scDetails);if(!system)return;
    dialogCategory.textContent=system.categoryName;dialogTitle.textContent=system.title;dialogCopy.textContent=system.description;dialogPin.dataset.scPin=system.id;paintPin(dialogPin);if(!dialog.open)dialog.showModal();
  });
  document.addEventListener('sc:reveal',event=>{
    const target=event.detail?.target;if(!target)return;
    const work=target.closest('[data-work-system]');
    if(work?.hidden&&systems.has(work.dataset.workSystem)){reset();event.detail.target=systems.get(work.dataset.workSystem).card;}
    else if(target.closest('.sc-card'))reset();
  });
  window.addEventListener('storage',event=>{if(event.key===storageKey||event.key===null){pinned=decode(event.newValue);sync();}});
  workspace.addEventListener('workspace:cards-changed',sync);
  sync();
})();
