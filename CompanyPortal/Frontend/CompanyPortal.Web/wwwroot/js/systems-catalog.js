(() => {
  const root=document.querySelector('.systems-section'),workspace=document.getElementById('workspace-cards');
  if(!root||!workspace)return;
  const cards=[...root.querySelectorAll('[data-system-id]')];
  const systems=new Map(cards.map(card=>[card.dataset.systemId,{id:card.dataset.systemId,category:card.dataset.systemCategory,categoryName:card.querySelector('.systems-category').textContent,title:card.querySelector('h3').textContent,description:card.querySelector('.systems-description').textContent,icon:card.dataset.systemIcon,card}]));
  // Applications remain illustrative until an authorized per-user catalog is connected.
  root.querySelectorAll('[data-systems-pin]').forEach(button=>button.remove());
  const search=root.querySelector('#systems-search'),categories=[...root.querySelectorAll('[data-systems-category]')],pinnedFilter=root.querySelector('#systems-pinned-filter');
  const motion=matchMedia('(prefers-reduced-motion: reduce)');
  let textureVisible=false;
  const updateTexture=()=>root.classList.toggle('systems-texture-active',textureVisible&&!document.hidden&&!motion.matches);
  const textureObserver=new IntersectionObserver(entries=>{textureVisible=entries[0].isIntersecting;if(textureVisible)root.classList.add('systems-has-entered');updateTexture();},{threshold:0});
  textureObserver.observe(root.querySelector('.systems-heading'));
  document.addEventListener('visibilitychange',updateTexture);motion.addEventListener('change',updateTexture);
  let category='all';
  pinnedFilter.hidden=true;
  const normalize=value=>value.normalize('NFKD').replace(/[\u064B-\u065F\u0670\u0640]/g,'').replace(/[أإآ]/g,'ا').replace(/ى/g,'ي').toLowerCase().trim();
  const number=value=>value.toLocaleString('ar-EG-u-nu-latn');
  function make(tag,className,text){const el=document.createElement(tag);if(className)el.className=className;if(text)el.textContent=text;return el;}
  const dialog=make('dialog','systems-system-dialog');dialog.setAttribute('aria-labelledby','systems-dialog-title');
  const dialogTop=make('div','systems-dialog-top'),dialogCategory=make('span'),close=make('button',null,'×');close.type='button';close.setAttribute('aria-label','إغلاق نافذة النظام');dialogTop.append(dialogCategory,close);
  const dialogTitle=make('h2');dialogTitle.id='systems-dialog-title';const dialogCopy=make('p');
  dialog.append(dialogTop,dialogTitle,dialogCopy,make('small',null,'هذا عرض توضيحي؛ لم يُربط النظام برابط تشغيل فعلي بعد.'));document.body.append(dialog);close.addEventListener('click',()=>dialog.close());
  const sheet=document.getElementById('systems-sheet'),sheetTrigger=document.getElementById('systems-sheet-trigger');
  if(sheet&&sheetTrigger){
    const sheetContent=sheet.querySelector('.portal-systems-sheet-content'),sheetSearch=make('label','portal-systems-sheet-search');
    sheetSearch.innerHTML='<span>البحث عن نظام</span><input type="search" placeholder="ابحث باسم النظام أو الخدمة…">';
    const sheetCategories=make('div','portal-systems-sheet-categories');sheetCategories.setAttribute('role','group');sheetCategories.setAttribute('aria-label','تصنيفات الأنظمة الإلكترونية');
    const categoryNames=new Map([['all','جميع الأنظمة'],['daily','العمل اليومي'],['people','الموظفون'],['operations','التشغيل والخدمات'],['finance','المالية والمشتريات'],['knowledge','المعرفة والتقنية']]);
    categoryNames.forEach((label,id)=>{const button=make('button',null,label);button.type='button';button.dataset.sheetCategory=id;button.setAttribute('aria-pressed',String(id==='all'));sheetCategories.append(button);});
    const sheetCount=make('span','portal-systems-sheet-count'),sheetGrid=make('div','systems-grid portal-systems-sheet-grid'),sheetEmpty=make('p','portal-systems-sheet-empty','لا توجد أنظمة مطابقة للبحث.');sheetEmpty.hidden=true;
    cards.forEach(card=>{const clone=card.cloneNode(true);clone.removeAttribute('aria-labelledby');clone.querySelector('h3')?.removeAttribute('id');sheetGrid.append(clone);});
    const sheetFilters=make('div','portal-systems-sheet-filters');sheetFilters.append(sheetSearch,sheetCategories);
    sheetContent.append(sheetFilters,sheetCount,sheetGrid,sheetEmpty);
    let sheetCategory='all';const sheetInput=sheetSearch.querySelector('input');
    function filterSheet(){const terms=normalize(sheetInput.value).split(/\s+/).filter(Boolean);let count=0;[...sheetGrid.children].forEach(card=>{const system=systems.get(card.dataset.systemId),visible=(sheetCategory==='all'||system.category===sheetCategory)&&terms.every(term=>normalize(`${system.title} ${system.description} ${system.categoryName}`).includes(term));card.hidden=!visible;if(visible)count++;});sheetCategories.querySelectorAll('button').forEach(button=>button.setAttribute('aria-pressed',String(button.dataset.sheetCategory===sheetCategory)));sheetCount.textContent=`${number(count)} من ${number(systems.size)} نظامًا`;sheetEmpty.hidden=count!==0;}
    sheetTrigger.addEventListener('click',event=>{event.preventDefault();filterSheet();if(!sheet.open)sheet.showModal();});
    document.addEventListener('click',event=>{
      if(root.hidden&&event.target.closest('a[href="#library"]')){event.preventDefault();sheetTrigger.click();}
    });
    sheet.querySelector('.portal-systems-sheet-close').addEventListener('click',()=>sheet.close());
    sheet.addEventListener('click',event=>{const bounds=sheet.getBoundingClientRect();if(event.target===sheet&&(event.clientX<bounds.left||event.clientX>bounds.right||event.clientY<bounds.top||event.clientY>bounds.bottom))sheet.close();});
    sheet.addEventListener('close',()=>sheetTrigger.focus());sheetInput.addEventListener('input',filterSheet);
    sheetCategories.addEventListener('click',event=>{const button=event.target.closest('[data-sheet-category]');if(!button)return;sheetCategory=button.dataset.sheetCategory;filterSheet();});
  }
  function filter(){
    const terms=normalize(search.value).split(/\s+/).filter(Boolean);let count=0;
    systems.forEach(system=>{const text=normalize(system.title+' '+system.description+' '+system.categoryName);const visible=(category==='all'||system.category===category)&&terms.every(term=>text.includes(term));system.card.hidden=!visible;if(visible)count++;});
    categories.forEach(button=>button.setAttribute('aria-pressed',String(button.dataset.systemsCategory===category)));
    root.querySelector('#systems-results').textContent=`${number(count)} من ${number(systems.size)} نظامًا`;root.querySelector('#systems-empty').hidden=count!==0;
  }
  function reset(){search.value='';category='all';filter();}
  function focusCatalog(){reset();root.scrollIntoView({behavior:motion.matches?'instant':'smooth',block:'start'});search.focus({preventScroll:true});}
  search.addEventListener('input',filter);categories.forEach(button=>button.addEventListener('click',()=>{category=button.dataset.systemsCategory;filter();}));root.querySelector('#systems-reset').addEventListener('click',()=>{reset();search.focus();});
  document.querySelector('.portal-add-system')?.addEventListener('click',focusCatalog);
  document.addEventListener('click',event=>{
    const details=event.target.closest('[data-systems-details]');if(!details)return;const system=systems.get(details.dataset.systemsDetails);if(!system)return;
    dialogCategory.textContent=system.categoryName;dialogTitle.textContent=system.title;dialogCopy.textContent=system.description;if(!dialog.open)dialog.showModal();
  });
  document.addEventListener('systems:reveal',event=>{
    const target=event.detail?.target;if(!target)return;
    const work=target.closest('[data-work-system]');
    if(work?.hidden&&systems.has(work.dataset.workSystem)){reset();event.detail.target=systems.get(work.dataset.workSystem).card;}
    else if(target.closest('.systems-card'))reset();
  });
  filter();
})();
