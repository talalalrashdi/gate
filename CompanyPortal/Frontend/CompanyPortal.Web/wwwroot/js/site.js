const toast=document.getElementById('portal-toast');let toastTimer;
function showToast(message){toast.textContent=message;toast.classList.add('is-visible');clearTimeout(toastTimer);toastTimer=setTimeout(()=>toast.classList.remove('is-visible'),2400)}
document.querySelectorAll('[data-portal-action]').forEach(button=>button.addEventListener('click',()=>showToast(`${button.dataset.portalAction} · واجهة تجريبية، ربط النظام لاحقًا`)));
document.querySelectorAll('[data-portal-scroll]').forEach(button=>button.addEventListener('click',()=>showToast(button.dataset.portalScroll==='1'?'انتقلت إلى التحديث التالي':'عدت إلى التحديث السابق')));
const header=document.querySelector('.portal-header');
const navigation=document.querySelector('.portal-navigation');
const searchTrigger=document.querySelector('.portal-search');
const searchTriggers=[...document.querySelectorAll('.portal-search')];
const separateSearch=!!document.querySelector('.portal-search-group');
let activeSearchTrigger=searchTrigger,searchMode='all';
const searchPanel=document.getElementById('portal-search-panel');
const searchInput=document.getElementById('portal-search-input');
const results=document.getElementById('portal-search-results');
const searchStatus=document.getElementById('portal-search-status');
const reducedMotion=matchMedia('(prefers-reduced-motion: reduce)');
const profileTrigger=document.querySelector('.portal-profile-trigger');
const profilePanel=document.getElementById('portal-header-profile');
const notificationsTrigger=document.querySelector('.portal-notifications-trigger');
const notificationsPanel=document.getElementById('portal-header-notifications');
function positionProfile(){
  const panel=!profilePanel.hidden?profilePanel:notificationsPanel;
  const trigger=panel===profilePanel?profileTrigger:notificationsTrigger;
  if(!panel||panel.hidden||!document.body.classList.contains('portal-dashboard'))return;
  const avatar=trigger.getBoundingClientRect(), frame=header.getBoundingClientRect();
  const center=avatar.left+avatar.width/2;
  const panelLeft=Math.max(12,Math.min(center-36,document.documentElement.clientWidth-panel.offsetWidth-12));
  header.style.setProperty('--profile-panel-top',`${avatar.bottom-frame.top+14}px`);
  header.style.setProperty('--profile-panel-left',`${panelLeft-frame.left}px`);
  header.style.setProperty('--profile-panel-max-height',`${Math.max(0,window.innerHeight-avatar.bottom-26)}px`);
  header.style.setProperty('--profile-arrow-left',`${center-frame.left}px`);
}
window.addEventListener('resize',positionProfile);
function closeProfile(restoreFocus=false){
  profilePanel.hidden=true;header.classList.remove('is-profile-open');profileTrigger.setAttribute('aria-expanded','false');
  if(restoreFocus)profileTrigger.focus({preventScroll:true});
}
profileTrigger.addEventListener('click',()=>{
  if(!profilePanel.hidden){closeProfile();return;}
  closeNotifications();
  closeSearch(false);profilePanel.hidden=false;header.classList.add('is-profile-open');profileTrigger.setAttribute('aria-expanded','true');
  positionProfile();
});
document.querySelector('.portal-profile-close')?.addEventListener('click',()=>closeProfile(true));
document.addEventListener('pointerdown',event=>{if(!profilePanel.hidden&&!header.contains(event.target))closeProfile();});
document.addEventListener('keydown',event=>{if(event.key==='Escape'&&!profilePanel.hidden){event.preventDefault();closeProfile(true);}});
header.addEventListener('focusout',()=>requestAnimationFrame(()=>{if(!profilePanel.hidden&&!header.contains(document.activeElement))closeProfile();}));
function closeNotifications(restoreFocus=false){
  if(!notificationsPanel||notificationsPanel.hidden)return;
  notificationsPanel.hidden=true;header.classList.remove('is-profile-open');notificationsTrigger.setAttribute('aria-expanded','false');
  if(restoreFocus)notificationsTrigger.focus({preventScroll:true});
}
function renderNotifications(){
  if(!notificationsPanel||!notificationsTrigger)return;
  const systemsList=document.getElementById('portal-system-notifications'),calendarList=document.getElementById('portal-calendar-notifications');
  function renderList(list,items,emptyText){
    list.replaceChildren();
    if(!items.length){const empty=document.createElement('li');empty.className='portal-notifications-empty';empty.textContent=emptyText;list.append(empty);return;}
    items.forEach(item=>{const row=document.createElement('li'),title=document.createElement('strong'),meta=document.createElement('small');title.textContent=item.title;meta.textContent=item.meta;row.append(title,meta);list.append(row);});
  }
  const systems=[...document.querySelectorAll('#portal-alerts-section .portal-alert')].filter(card=>!card.hidden&&card.querySelector('.portal-alert-badge')?.textContent.includes('نظام')).map(card=>({title:card.querySelector('h3').textContent,meta:card.querySelector('p').textContent}));
  const exchangePlanner=!!document.querySelector('[data-schedule-source=exchange]');
  let tasks=[];if(!exchangePlanner)try{const saved=JSON.parse(localStorage.getItem('clerio-personal-tasks'));if(Array.isArray(saved))tasks=saved;}catch{}
  const today=new Date(),todayKey=`${today.getFullYear()}-${String(today.getMonth()+1).padStart(2,'0')}-${String(today.getDate()).padStart(2,'0')}`;
  const calendar=exchangePlanner?(window.CompanyPortalSchedule?.notifications||[]):tasks.filter(task=>task&&typeof task.title==='string'&&task.done===false&&task.type!=='note'&&typeof task.date==='string'&&task.date>=todayKey).sort((a,b)=>`${a.date} ${a.time||''}`.localeCompare(`${b.date} ${b.time||''}`)).map(task=>({title:task.title,meta:[task.date,typeof task.time==='string'?task.time:''].filter(Boolean).join(' · ')}));
  systems.push(
    {title:'تم اعتماد طلبك في نظام الاستمارات',meta:'تجريبي · نظام الاستمارات · منذ 10 دقائق'},
    {title:'مراسلة جديدة بانتظار الاطلاع',meta:'تجريبي · نظام المراسلات · منذ 20 دقيقة'}
  );
  if(!exchangePlanner)calendar.push(
    {title:'تذكير باجتماع متابعة الفريق',meta:'تجريبي · اليوم · 10:00 صباحًا'},
    {title:'موعد تسليم تقرير الأسبوع',meta:'تجريبي · غدًا · 02:00 مساءً'}
  );
  const count=systems.length+calendar.length,badge=notificationsTrigger.querySelector('.portal-notifications-count'),number=count.toLocaleString('ar-EG-u-nu-latn');
  if(badge){badge.textContent=number;badge.hidden=count===0;}
  notificationsTrigger.setAttribute('aria-label',`الإشعارات، ${number} إشعارات`);notificationsTrigger.title=`الإشعارات (${number})`;
  renderList(systemsList,systems,'لا توجد إشعارات أنظمة حاليًا.');
  renderList(calendarList,calendar,'لا توجد مهام قادمة في تقويم الأعمال.');
}
document.addEventListener('DOMContentLoaded',renderNotifications,{once:true});
document.addEventListener('companyportal:schedule-updated',renderNotifications);
notificationsTrigger?.addEventListener('click',()=>{
  if(!notificationsPanel.hidden){closeNotifications();return;}
  closeProfile();closeSearch(false);renderNotifications();notificationsPanel.hidden=false;header.classList.add('is-profile-open');notificationsTrigger.setAttribute('aria-expanded','true');positionProfile();
});
document.addEventListener('pointerdown',event=>{if(notificationsPanel&&!notificationsPanel.hidden&&!notificationsPanel.contains(event.target)&&!notificationsTrigger.contains(event.target))closeNotifications();});
document.addEventListener('keydown',event=>{if(event.key==='Escape'&&notificationsPanel&&!notificationsPanel.hidden){event.preventDefault();closeNotifications(true);}});
header.addEventListener('focusout',()=>requestAnimationFrame(()=>{if(notificationsPanel&&!notificationsPanel.hidden&&!header.contains(document.activeElement))closeNotifications();}));
let selectedResult=-1,visibleResults=[],highlightTimer,highlightedTarget;
const headerSpace = document.createElement('div');
headerSpace.className = 'portal-header-scroll-space';
headerSpace.hidden = true;
function updateHeader(){
  const current = Math.max(0, window.scrollY);
  header.classList.toggle('is-scrolled', current > 40);
  if (current <= 40) {
    header.classList.remove('is-pinned');
    headerSpace.hidden = true;
  } else if (!header.classList.contains('is-pinned')) {
    if (getComputedStyle(header).position === 'relative') {
      headerSpace.style.height = header.offsetHeight + 'px';
      header.before(headerSpace);
      headerSpace.hidden = false;
    }
    header.classList.add('is-pinned');
  }
}
window.addEventListener('scroll',updateHeader,{passive:true});updateHeader();

// Index the rendered content so titles and their destinations stay in sync.
const searchEntries=[...document.querySelectorAll('.portal-section h2,.portal-section h3,.portal-workspace-section h2,.portal-doc-list button,.portal-library-catalog button')].filter(element=>!element.closest('.systems-empty,.systems-section[hidden]')).map((element,index)=>{
  const section=element.closest('.portal-section, .portal-workspace-section');
  const title=element.matches('h2,h3')?element.innerText:(element.querySelector('.portal-doc-copy b')||element.querySelector('b,span'))?.textContent;
  const target=element.matches('h2')?(element.closest('.portal-work-card')||section):element.closest('article,button')||element;
  target.dataset.portalSearchTarget=String(index);
  const category=section?.dataset.searchCategory||section?.querySelector('h2')?.innerText.trim().replace(/\s+/g,' ')||'مساحة العمل';
  return {title:(title||'').trim().replace(/\s+/g,' '),category,text:element.matches('h2')?title:target.textContent.trim(),target};
});
// Illustrative contacts only; masked mobile numbers cannot be mistaken for live contacts.
const phoneSamples=[
  {title:'أحمد سالم',category:'الإدارة العامة',address:'مدير الشؤون الإدارية · المبنى الرئيسي، الطابق الأول',office:'1033',mobile:'9XXX 1033',photo:'workspace-person.png'},
  {title:'خالد البلوشي',category:'تقنية المعلومات',address:'أخصائي دعم فني · المبنى الرئيسي، الطابق الثاني',office:'1044',mobile:'9XXX 1044',photo:'phone-khalid-mussar.png'},
  {title:'سعيد الحارثي',category:'الموارد البشرية',address:'أخصائي شؤون الموظفين · مبنى الخدمات، الطابق الأول',office:'1055',mobile:'9XXX 1055',photo:'phone-saeed-mussar.png'}
].map(person=>({...person,contact:true,text:[person.address,person.office,person.mobile].join(' ')}));
const normalizeSearch=value=>value.normalize('NFKD').replace(/[\u064B-\u065F\u0670\u0640]/g,'').replace(/[أإآ]/g,'ا').replace(/ى/g,'ي').replace(/[٠-٩۰-۹]/g,digit=>String(digit.charCodeAt(0)-(digit<='٩'?0x660:0x6f0))).toLowerCase().trim();
const recentSearchKey='clerio-search-recents-v1';
let recentSearches={all:[],phone:[]},recentSearchTimer;
try{const saved=JSON.parse(localStorage.getItem(recentSearchKey));for(const mode of ['all','phone'])if(Array.isArray(saved?.[mode]))recentSearches[mode]=saved[mode].filter(value=>typeof value==='string'&&value.trim()&&value.length<=80).slice(0,6);}catch{}
function rememberSearch(){
  clearTimeout(recentSearchTimer);
  const query=searchInput.value.trim().slice(0,80);
  if(!separateSearch||!query||!visibleResults.length||visibleResults[0].recent)return;
  recentSearches[searchMode]=[query,...recentSearches[searchMode].filter(value=>normalizeSearch(value)!==normalizeSearch(query))].slice(0,6);
  try{localStorage.setItem(recentSearchKey,JSON.stringify(recentSearches));}catch{}
}
function paintMatch(node,title,query){
  const term=normalizeSearch(query),normalized=normalizeSearch(title),start=term?normalized.indexOf(term):-1;
  // Character offsets remain exact for unaccented literal matches.
  const literal=query.trim(),exact=literal?title.indexOf(literal):-1;
  if(start<0||exact<0){node.textContent=title;return}
  node.append(document.createTextNode(title.slice(0,exact)));
  const mark=document.createElement('mark');mark.textContent=title.slice(exact,exact+literal.length);node.append(mark,document.createTextNode(title.slice(exact+literal.length)));
}
function setActiveResult(index){
  selectedResult=index;
  [...results.children].forEach((option,i)=>option.setAttribute('aria-selected',String(i===index)));
  if(index>=0){const option=results.children[index];searchInput.setAttribute('aria-activedescendant',option.id);option.scrollIntoView({block:'nearest'})}
  else searchInput.removeAttribute('aria-activedescendant');
}
function renderSearch(showDirectory=false){
  const term=normalizeSearch(searchInput.value);
  const phoneOnly=separateSearch?searchMode==='phone':searchPanel.querySelector('[name="portal-search-scope"]:checked')?.value==='phone';
  const entries=phoneOnly&&separateSearch?phoneSamples:phoneOnly?searchEntries.filter(entry=>entry.target.closest('[data-search-category="دليل الهاتف"]')):searchEntries;
  visibleResults=term?entries.filter(entry=>normalizeSearch(entry.title+' '+entry.category+' '+entry.text).includes(term)).sort((a,b)=>Number(normalizeSearch(b.title).includes(term))-Number(normalizeSearch(a.title).includes(term))):entries.filter(entry=>phoneOnly||entry.target.matches('.portal-section'));
  searchStatus.textContent=term?`${visibleResults.length.toLocaleString('ar-EG-u-nu-latn')} نتائج مطابقة`:phoneOnly?'جهات الاتصال':'وصول سريع';
  if(separateSearch&&!term&&!showDirectory&&(phoneOnly||recentSearches[searchMode].length)){
    visibleResults=recentSearches[searchMode].map(query=>({recent:true,title:query,category:phoneOnly?'دليل الهاتف':'البحث العام'}));
    searchStatus.textContent='عمليات البحث الأخيرة';
  }
  results.replaceChildren();selectedResult=-1;searchInput.removeAttribute('aria-activedescendant');
  visibleResults.forEach((entry,index)=>{
    const option=document.createElement('div');option.className='portal-search-option';option.id=`portal-result-${index}`;option.setAttribute('role','option');option.setAttribute('aria-selected','false');
    if(entry.recent){
      option.classList.add('portal-search-recent');
      const clock=document.createElement('span'),copy=document.createElement('span'),title=document.createElement('strong'),description=document.createElement('small');
      clock.className='portal-search-recent-icon';clock.setAttribute('aria-hidden','true');clock.textContent='↶';title.textContent=entry.title;
      copy.append(title);
      if(!phoneOnly){description.textContent=entry.category;copy.append(description);}
      option.append(clock,copy);
      option.addEventListener('pointerdown',event=>event.preventDefault());option.addEventListener('click',()=>openResult(index));results.append(option);return;
    }
    if(entry.contact){
      option.classList.add('portal-search-contact');option.tabIndex=-1;
      const photo=document.createElement('img');photo.src='./assets/'+entry.photo;photo.alt='صورة توضيحية لشخصية '+entry.title;photo.width=44;photo.height=44;
      const copy=document.createElement('div'),name=document.createElement('strong'),department=document.createElement('small'),address=document.createElement('p'),numbers=document.createElement('dl'),badge=document.createElement('span');
      paintMatch(name,entry.title,searchInput.value);department.textContent=entry.category;address.textContent=entry.address;badge.className='portal-search-contact-demo';badge.textContent='نموذج تجريبي';
      [['رقم المكتب',entry.office],['الهاتف النقال',entry.mobile]].forEach(([label,value])=>{const row=document.createElement('div'),dt=document.createElement('dt'),dd=document.createElement('dd');dt.textContent=label;dd.textContent=value;dd.dir='ltr';row.append(dt,dd);numbers.append(row);});
      copy.append(name,department,address,numbers,badge);option.append(photo,copy);results.append(option);return;
    }
    const icon=document.createElement('i');icon.className='iconsax';icon.setAttribute('icon-name','document-text-1');icon.setAttribute('aria-hidden','true');
    const copy=document.createElement('span'),title=document.createElement('strong'),category=document.createElement('small'),arrow=document.createElement('span');
    paintMatch(title,entry.title,searchInput.value);category.textContent=entry.category;arrow.textContent='←';arrow.setAttribute('aria-hidden','true');copy.append(title,category);option.append(icon,copy,arrow);
    option.addEventListener('pointerdown',event=>event.preventDefault());option.addEventListener('click',()=>openResult(index));results.append(option);
  });
  if(!visibleResults.length){const empty=document.createElement('p');empty.className='portal-search-empty';empty.textContent=phoneOnly&&!term&&!showDirectory?'لا توجد عمليات بحث سابقة بعد.':phoneOnly?(entries.length?'لم نجد نتيجة في دليل الهاتف. جرّب الاسم أو رقم الهاتف.':'لا توجد بيانات لدليل الهاتف متاحة حاليًا.'):'لم نجد نتيجة. جرّب اسم نظام، مستند أو موضوع.';results.append(empty)}
}
function closeSearch(restoreFocus=true){
  if(separateSearch&&!searchPanel.hidden){rememberSearch();}
  searchPanel.hidden=true;navigation.hidden=false;header.classList.remove('is-searching');searchTriggers.forEach(trigger=>trigger.setAttribute('aria-expanded','false'));searchInput.setAttribute('aria-expanded','false');searchInput.removeAttribute('aria-activedescendant');
  if(restoreFocus)activeSearchTrigger.focus({preventScroll:true});
}
function openSearch(mode='all',trigger=searchTrigger){
  if(separateSearch){
    if(!searchPanel.hidden)rememberSearch();
    searchMode=mode==='phone'?'phone':'all';activeSearchTrigger=trigger;
    const phoneOnly=searchMode==='phone',title=phoneOnly?'البحث في دليل الهاتف':'البحث العام';
    document.getElementById('portal-search-title').textContent=title;
    searchPanel.dataset.searchMode=searchMode;
    searchPanel.querySelector('.portal-phone-important').hidden=!phoneOnly;
    searchPanel.querySelector('.portal-phone-directory').hidden=!phoneOnly;
    searchInput.value='';
    searchInput.placeholder=phoneOnly?'ابحث بالاسم أو الإدارة أو رقم الهاتف':'عن ماذا تبحث اليوم؟';
    searchInput.setAttribute('aria-label',title);
    results.setAttribute('aria-label',phoneOnly?'نتائج دليل الهاتف':'نتائج البحث العام');
    searchPanel.querySelector('.portal-search-caption small').textContent=phoneOnly?'جهات الاتصال وأرقام التواصل':'الأنظمة والمستندات ومحتوى الصفحة';
    searchTriggers.forEach(button=>button.setAttribute('aria-expanded',String(button===trigger)));
  }
  closeProfile();
  closeNotifications();
  navigation.hidden=!separateSearch;searchPanel.hidden=false;header.classList.add('is-searching');activeSearchTrigger.setAttribute('aria-expanded','true');searchInput.setAttribute('aria-expanded','true');renderSearch();searchInput.focus({preventScroll:true});
}
function openResult(index){
  const selectedEntry=visibleResults[index];if(!selectedEntry)return;
  if(selectedEntry.recent){searchInput.value=selectedEntry.title;renderSearch();searchInput.focus({preventScroll:true});rememberSearch();return;}
  rememberSearch();
  if(selectedEntry.contact){setActiveResult(index);results.children[index].focus({preventScroll:true});return;}
  const reveal={target:selectedEntry.target};document.dispatchEvent(new CustomEvent('systems:reveal',{detail:reveal}));
  const entry={...selectedEntry,target:reveal.target};
  if(entry.target.matches('[data-doc-id]')){libraryInput.value='';activeDocCategory='all';renderLibrary();}
  closeSearch(false);highlightedTarget?.classList.remove('portal-search-target');clearTimeout(highlightTimer);
  highlightedTarget=entry.target;entry.target.classList.add('portal-search-target');
  if(!entry.target.matches('button,a'))entry.target.setAttribute('tabindex','-1');
  entry.target.focus({preventScroll:true});entry.target.scrollIntoView({behavior:reducedMotion.matches?'instant':'smooth',block:'center'});
  highlightTimer=setTimeout(()=>entry.target.classList.remove('portal-search-target'),2400);
}
searchTriggers.forEach(trigger=>trigger.addEventListener('click',()=>openSearch(trigger.dataset.searchMode||'all',trigger)));
searchPanel.querySelector('.portal-phone-directory')?.addEventListener('click',()=>{searchInput.value='';renderSearch(true);searchInput.focus({preventScroll:true});results.scrollTop=0;});

document.querySelector('.portal-search-close').addEventListener('click',()=>closeSearch());
searchInput.addEventListener('input',()=>{renderSearch();clearTimeout(recentSearchTimer);if(separateSearch)recentSearchTimer=setTimeout(rememberSearch,600);});
searchPanel.querySelectorAll('[name="portal-search-scope"]').forEach(input=>input.addEventListener('change',()=>{
  searchInput.placeholder=input.value==='phone'?'ابحث بالاسم أو رقم الهاتف':'عن ماذا تبحث اليوم؟';
  renderSearch();
}));
searchInput.addEventListener('keydown',event=>{
  if(event.key==='ArrowDown'||event.key==='ArrowUp'){
    event.preventDefault();if(!visibleResults.length)return;
    const direction=event.key==='ArrowDown'?1:-1;setActiveResult(selectedResult<0?(direction===1?0:visibleResults.length-1):(selectedResult+direction+visibleResults.length)%visibleResults.length);
  }else if(event.key==='Enter'){event.preventDefault();openResult(selectedResult<0?0:selectedResult)}
});
document.addEventListener('keydown',event=>{
  if((event.ctrlKey||event.metaKey)&&event.key.toLowerCase()==='k'){event.preventDefault();openSearch()}
  if(event.key==='Escape'&&!searchPanel.hidden){event.preventDefault();closeSearch()}
});
document.addEventListener('pointerdown',event=>{if(!searchPanel.hidden&&!header.contains(event.target))closeSearch(false)});
header.addEventListener('focusout',()=>requestAnimationFrame(()=>{if(!searchPanel.hidden&&!header.contains(document.activeElement))closeSearch(false)}));

// Combined library search + category filters, with explicit sample reading states.
const libraryInput=document.getElementById('work-library-search');
const docButtons=[...document.querySelectorAll('[data-doc-id]')];
const categoryButtons=[...document.querySelectorAll('[data-doc-category]')];
let activeDocCategory='all';
function renderLibrary(){
  const query=normalizeSearch(libraryInput.value);let count=0;
  docButtons.forEach(button=>{
    const matches=(activeDocCategory==='all'||button.dataset.category===activeDocCategory)&&normalizeSearch(button.querySelector('.portal-doc-copy').textContent+' '+button.querySelector('.portal-doc-type').textContent).includes(query);
    button.hidden=!matches;if(matches)count++;
  });
  categoryButtons.forEach(button=>button.setAttribute('aria-pressed',String(button.dataset.docCategory===activeDocCategory)));
  document.querySelector('.portal-doc-empty').hidden=count>0;
}
libraryInput.addEventListener('input',renderLibrary);
categoryButtons.forEach(button=>button.addEventListener('click',()=>{activeDocCategory=button.dataset.docCategory;renderLibrary()}));
const docDialog=document.querySelector('.portal-doc-dialog');
const docSamples={
  guide:'مرحبًا بك في مساحة العمل. استخدم مكتبة العمل للعثور على الأدلة والسياسات، وتابع المراسلات والطلبات من البطاقات المخصصة. يمكنك الجمع بين البحث والتصنيف للوصول إلى المستند المطلوب.',
  policy:'يقدّم هذا النموذج إرشادات عامة لحماية معلومات العمل: استخدام كلمات مرور قوية، ومشاركة المستندات مع الجهات المخوّلة فقط، والإبلاغ عن الرسائل المشبوهة عبر القنوات المعتمدة.',
  leave:'نموذج توضيحي لقرار تنظيم الإجازات السنوية وإجراءات تقديم الطلبات واعتمادها.',
  training:'نموذج توضيحي لقرار اعتماد خطة التدريب وتنسيق مشاركة الموظفين في البرامج.',
  delegation:'نموذج توضيحي لقرار تفويض الصلاحيات الإدارية وتحديد مسؤوليات متابعة الإجراءات.',
  report:'يعرض هذا النموذج ملخصًا توضيحيًا للأداء الشهري: تقدم الطلبات، ومستوى إنجاز الخدمات، وأبرز فرص التحسين. تُضاف البيانات الفعلية عند ربط المكتبة بمصدر المستندات.'
};
function paintDecisionState(button){
  const labels={new:'غير مفتوح',unread:'غير مقروء',read:'مقروء'};
  let status=button.querySelector('.portal-decision-state');
  if(!status){status=document.createElement('span');status.className='portal-decision-state';button.querySelector('.portal-item-meta').append(status);}
  status.textContent=labels[button.dataset.state]||labels.unread;
  const ageLabels={today:'اليوم',yesterday:'أمس',older:'سابق'};
  const time=button.querySelector('time');
  time.textContent=(ageLabels[button.dataset.decisionAge]||'')+' · '+time.textContent.split(' · ').at(-1);
  button.setAttribute('aria-label',button.querySelector('b').textContent+' — '+time.textContent+' — '+status.textContent);
}
docButtons.forEach(paintDecisionState);
docButtons.forEach(button=>button.addEventListener('click',()=>{
  document.getElementById('doc-preview-title').textContent=button.querySelector('b').textContent;
  document.getElementById('doc-preview-copy').textContent=docSamples[button.dataset.docId].replace('مكتبة العمل',document.getElementById('work-library-title')?.textContent.trim()||'مكتبة العمل');
  docDialog.showModal();
  button.dataset.state='read';
  paintDecisionState(button);
}));
document.querySelector('.portal-doc-close').addEventListener('click',()=>docDialog.close());
renderLibrary();

// Native RTL scrolling supports touch/trackpads, buttons, and keyboard navigation.
const alertTrack=document.getElementById('workspace-alerts');
const alertCards=[...alertTrack.querySelectorAll('.portal-alert')];
const alertPrev=document.querySelector('.portal-alert-prev');
const alertNext=document.querySelector('.portal-alert-next');
function updateAlertNavigation(){
  const max=Math.max(0,alertTrack.scrollWidth-alertTrack.clientWidth);
  const progress=Math.abs(alertTrack.scrollLeft);
  alertPrev.disabled=progress<2;alertNext.disabled=progress>=max-2;
  alertTrack.parentElement.classList.toggle('has-before',!alertPrev.disabled);
  alertTrack.parentElement.classList.toggle('has-after',!alertNext.disabled);
  const bounds=alertTrack.getBoundingClientRect();
  const active=alertCards.filter(card=>!card.hidden);
  const visible=active.map((card,index)=>({rect:card.getBoundingClientRect(),index})).filter(({rect})=>Math.min(rect.right,bounds.right)-Math.max(rect.left,bounds.left)>Math.min(rect.width,alertTrack.clientWidth)/2);
  const positionLabel=document.querySelector('.portal-alert-position');
  if(visible.length){const first=visible[0].index+1,last=visible.at(-1).index+1;positionLabel.textContent=`${first.toLocaleString('ar-EG-u-nu-latn')}${first!==last?'–'+last.toLocaleString('ar-EG-u-nu-latn'):''} من ${active.length.toLocaleString('ar-EG-u-nu-latn')}`;}else positionLabel.textContent='';
  document.querySelector('.portal-alert-carousel .portal-alert-toolbar small').textContent=active.length?`${active.length.toLocaleString('ar-EG-u-nu-latn')} تحديثات`:'لا توجد تحديثات';
}
function moveAlerts(direction){
  const first=alertCards.find(card=>!card.hidden);if(!first)return;
  const step=first.getBoundingClientRect().width+parseFloat(getComputedStyle(alertTrack).columnGap);
  alertTrack.scrollBy({left:direction*step,behavior:reducedMotion.matches?'instant':'smooth'});
}
alertPrev.addEventListener('click',()=>moveAlerts(1));
alertNext.addEventListener('click',()=>moveAlerts(-1));
alertTrack.addEventListener('keydown',event=>{
  if(event.key==='ArrowLeft'||event.key==='ArrowRight'){event.preventDefault();moveAlerts(event.key==='ArrowLeft'?-1:1);}
});
alertTrack.addEventListener('scroll',updateAlertNavigation,{passive:true});
new ResizeObserver(updateAlertNavigation).observe(alertTrack);
updateAlertNavigation();

const workspaceTrack=document.getElementById('workspace-cards');
const workspacePrev=document.querySelector('.portal-workspace-prev');
const workspaceNext=document.querySelector('.portal-workspace-next');
function updateWorkspaceNavigation(){
  const grid=getComputedStyle(workspaceTrack).display==='grid';
  const controls=workspacePrev.closest('.portal-alert-controls');
  if(controls)controls.hidden=grid;
  workspaceTrack.setAttribute('aria-label',grid?'بطاقات مساحة العمل':'بطاقات مساحة العمل، استخدم سهمي اليمين واليسار للتصفح');
  const max=Math.max(0,workspaceTrack.scrollWidth-workspaceTrack.clientWidth);
  const position=Math.abs(workspaceTrack.scrollLeft);
  workspacePrev.disabled=position<2;workspaceNext.disabled=position>=max-2;
  workspaceTrack.parentElement.classList.toggle('has-before',!workspacePrev.disabled);
  workspaceTrack.parentElement.classList.toggle('has-after',!workspaceNext.disabled);
}
function moveWorkspace(direction){
  workspaceTrack.scrollBy({left:direction*workspaceTrack.clientWidth*.8,behavior:reducedMotion.matches?'instant':'smooth'});
}
workspacePrev.addEventListener('click',()=>moveWorkspace(1));
workspaceNext.addEventListener('click',()=>moveWorkspace(-1));
workspaceTrack.addEventListener('keydown',event=>{
  if(event.target!==workspaceTrack||getComputedStyle(workspaceTrack).display==='grid')return;
  if(event.key==='ArrowLeft'||event.key==='ArrowRight'){event.preventDefault();moveWorkspace(event.key==='ArrowLeft'?-1:1);}
});
workspaceTrack.addEventListener('scroll',updateWorkspaceNavigation,{passive:true});
new ResizeObserver(updateWorkspaceNavigation).observe(workspaceTrack);
updateWorkspaceNavigation();
// The view toggle is only present on design B; cards and their state stay in place.
(() => {
  const toggle=document.getElementById('portal-workspace-view-toggle');
  if(!toggle)return;
  const key='clerio-workspace-view-v1';
  let horizontalPosition=0;
  function apply(view,persist=false){
    const grid=view==='grid';
    if(grid&&workspaceTrack.dataset.workspaceView!=='grid')horizontalPosition=workspaceTrack.scrollLeft;
    workspaceTrack.dataset.workspaceView=grid?'grid':'horizontal';
    toggle.setAttribute('aria-pressed',String(grid));
    toggle.querySelector('span').textContent=grid?'عرض أفقي':'عرض شبكي';
    toggle.title=grid?'العودة إلى العرض الأفقي':'عرض جميع البطاقات في شبكة';
    workspaceTrack.scrollLeft=grid?0:horizontalPosition;
    updateWorkspaceNavigation();
    if(persist){try{localStorage.setItem(key,grid?'grid':'horizontal');}catch{}}
  }
  let saved;try{saved=localStorage.getItem(key);}catch{}
  apply(saved);
  toggle.addEventListener('click',()=>apply(workspaceTrack.dataset.workspaceView==='grid'?'horizontal':'grid',true));
  window.addEventListener('storage',event=>{if(event.key===key)apply(event.newValue);});
})();


// Hide the entire region so its height is released to the workspace below.
(() => {
  const toggle=document.getElementById('portal-alert-visibility'),section=document.getElementById('portal-alerts-section');if(!toggle||!section)return;
  function setAlertsVisible(visible){
    section.hidden=!visible;toggle.setAttribute('aria-expanded',String(visible));
    const label=visible?'إخفاء التنوية':'إظهار التنوية';toggle.setAttribute('aria-label',label);toggle.title=label;
    requestAnimationFrame(()=>{if(visible)updateAlertNavigation();updateWorkspaceNavigation();});
  }
  toggle.addEventListener('click',()=>setAlertsVisible(section.hidden));
  document.addEventListener('systems:reveal',event=>{if(event.detail?.target?.closest('#portal-alerts-section'))setAlertsVisible(true);});
})();

// Alert details use a native modal bottom sheet; dismissal stays reversible in this session.
(() => {
  const carousel=document.querySelector('.portal-alert-carousel');if(!carousel)return;
  const copy=[
    ['قرار جديد','نموذج تنبيه لاعتماد خطة التحول الرقمي، يجمع محاور العمل في مسار واضح يمكن الرجوع إليه.','يركز التصور على تبسيط الخدمات وتوحيد الوصول إلى الأنظمة ومشاركة المعرفة بين الفرق.'],
    ['تنبيه نظام','تنبيه توضيحي بموعد تحديث مجدول للخدمات، لمساعدة المستخدم على ترتيب أعماله مسبقًا.','عند ربط النظام الفعلي ستظهر هنا مدة التحديث والخدمات المتأثرة وأي تعليمات ذات صلة.'],
    ['فرصة تعلّم','ورشة توضيحية حول تحويل أفكار تحسين العمل إلى تجارب صغيرة قابلة للتقييم.','تتناول الورشة فهم الاحتياج، وتطوير نموذج أولي، وتبادل الملاحظات بين المشاركين.'],
    ['دعوة لقاء','جلسة تجريبية لمشاركة الخبرات والتجارب بين فرق العمل.','مساحة لعرض تجربة مفيدة، ومناقشة ما تعلمه الفريق، وتدوين الأفكار التي يمكن الاستفادة منها.'],
    ['تذكير مهم','تذكير توضيحي بمراجعة التقارير الشهرية واستكمال البيانات قبل موعد التسليم.','يساعد توحيد المؤشرات وإبراز النتائج والخطوات التالية على إعداد تقرير واضح وسهل القراءة.'],
    ['تحديث الموظفين','نموذج إشعار بواجهة محدثة لدليل المزايا والخدمات الخاصة بالموظفين.','تجمع الصفحة التعريف بالخدمات والمتطلبات ومسارات الوصول في مرجع واحد قابل للمراجعة.']
  ];
  const sheet=document.createElement('dialog');sheet.className='portal-alert-sheet';sheet.setAttribute('aria-labelledby','portal-alert-sheet-title');
  sheet.innerHTML='<div class="portal-alert-sheet-handle" aria-hidden="true"></div><header class="portal-alert-sheet-top"><span>تفاصيل التنبيه</span><button type="button" class="portal-alert-sheet-close" aria-label="إغلاق تفاصيل التنبيه" autofocus>×</button></header><div class="portal-alert-sheet-body"><div class="portal-alert-sheet-type"><span class="portal-alert-sheet-symbol"><i class="iconsax" aria-hidden="true"></i></span><span class="portal-alert-badge"></span></div><h2 id="portal-alert-sheet-title"></h2><p class="portal-alert-sheet-meta"></p><div class="portal-alert-sheet-copy"></div><p class="portal-alert-sheet-note">محتوى توضيحي لمعاينة التصميم، وليس إشعارًا فعليًا صادرًا عن المؤسسة.</p></div><footer class="portal-alert-sheet-footer"><button type="button" class="portal-alert-sheet-done">عودة إلى التنبيهات <span aria-hidden="true">←</span></button><span>مساحة العمل · كليريو</span></footer>';
  document.body.append(sheet);let opener=null,closing=false;
  function closeSheet(){if(!sheet.open||closing)return;closing=true;sheet.classList.add('is-closing');setTimeout(()=>sheet.close(),reducedMotion.matches?0:180);}
  sheet.querySelector('.portal-alert-sheet-close').addEventListener('click',closeSheet);sheet.querySelector('.portal-alert-sheet-done').addEventListener('click',closeSheet);
  sheet.addEventListener('cancel',event=>{event.preventDefault();closeSheet();});sheet.addEventListener('click',event=>{if(event.target!==sheet)return;const bounds=sheet.getBoundingClientRect();if(event.clientX<bounds.left||event.clientX>bounds.right||event.clientY<bounds.top||event.clientY>bounds.bottom)closeSheet();});
  sheet.addEventListener('close',()=>{document.body.classList.remove('has-alert-sheet');sheet.classList.remove('is-closing');closing=false;if(opener&&!opener.closest('[hidden]'))opener.focus({preventScroll:true});});
  const recovery=document.createElement('div');recovery.className='portal-alert-recovery';recovery.hidden=true;
  const empty=document.createElement('span');empty.textContent='أغلقت جميع التنبيهات.';empty.hidden=true;
  const restore=document.createElement('button');restore.type='button';recovery.append(empty,restore);carousel.append(recovery);
  function updateDismissed(){const count=alertCards.filter(card=>card.hidden).length;recovery.hidden=count===0;empty.hidden=count!==alertCards.length;restore.textContent=`استعادة التنبيهات المغلقة (${count.toLocaleString('ar-EG-u-nu-latn')})`;requestAnimationFrame(updateAlertNavigation);}
  restore.addEventListener('click',()=>{alertCards.forEach(card=>card.hidden=false);updateDismissed();alertTrack.scrollLeft=0;alertCards[0].querySelector('.portal-alert-open').focus({preventScroll:true});});
  const learningIllustration='<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 180 180" fill="none" focusable="false"><defs><linearGradient id="learning-glass" x1="49" y1="28" x2="135" y2="112" gradientUnits="userSpaceOnUse"><stop stop-color="#fffef9"/><stop offset=".43" stop-color="#f0e9fc"/><stop offset="1" stop-color="#b6a0d7"/></linearGradient><linearGradient id="learning-metal" x1="65" y1="115" x2="116" y2="132" gradientUnits="userSpaceOnUse"><stop stop-color="#dfd2ef"/><stop offset=".4" stop-color="#f9f5ff"/><stop offset="1" stop-color="#9c86bc"/></linearGradient><radialGradient id="learning-glow"><stop stop-color="#fff0bd" stop-opacity=".9"/><stop offset="1" stop-color="#fff0bd" stop-opacity="0"/></radialGradient></defs><circle cx="94" cy="101" r="73" fill="#ece4f4" fill-opacity=".6"/><circle cx="94" cy="101" r="61" stroke="#fff" stroke-width="1.5"/><ellipse cx="94" cy="151" rx="42" ry="8" fill="#9a85b5" fill-opacity=".15"/><path d="M70 115c-2-19-19-24-24-47C40 41 63 19 91 19s51 22 45 49c-5 23-22 28-24 47z" fill="url(#learning-glass)" stroke="#fff" stroke-width="1.5"/><circle cx="87" cy="62" r="40" fill="url(#learning-glow)"/><path d="M58 57c1-14 12-25 27-27" stroke="#fff" stroke-width="6" stroke-linecap="round" opacity=".85"/><path d="M84 114V88L71 69m27 45V88l13-19M71 69l13 8 7-10 7 10 13-8" stroke="#c7a163" stroke-width="2.7" stroke-linecap="round" stroke-linejoin="round"/><rect x="68" y="113" width="46" height="11" rx="5.5" fill="url(#learning-metal)"/><rect x="69" y="124" width="44" height="10" rx="5" fill="url(#learning-metal)"/><path d="M77 134h28c-1 9-7 13-14 13s-13-4-14-13" fill="#9d88bc"/><path d="M72 119h35m-33 10h31" stroke="#a38dbc" stroke-opacity=".45" stroke-width="1.2"/><path d="m146 30 4 10 10 4-10 4-4 10-4-10-10-4 10-4z" fill="#ddbd7c"/><path d="m36 92 3 7 7 3-7 3-3 7-3-7-7-3 7-3z" fill="#b6a0cc"/><circle cx="139" cy="108" r="4" fill="#e4c998"/><circle cx="37" cy="47" r="3" fill="#c5b8dc"/></svg>';
  const alertEmblems={
    warm:'<path d="m50 13 10 6 12 1 5 11 9 8-3 12 1 12-10 7-7 10-12-1-11 3-9-9-11-5-1-12-6-10 7-10 4-12 12-3z"/><circle cx="48" cy="45" r="20"/><path d="m38 45 7 7 15-16M31 76l-4 15 17-7m17-9 7 16-18-8"/>',
    cool:'<path d="M23 69h54l-8-12V42a19 19 0 0 0-38 0v15zM43 79a8 8 0 0 0 14 0M46 22v-4a4 4 0 0 1 8 0v4M18 38c0-8 4-15 10-20m54 20c0-8-4-15-10-20M50 38v13"/><circle cx="50" cy="59" r="1.5" fill="currentColor"/>',
    violet:'<path d="M30 40a20 20 0 1 1 40 0c0 14-13 17-13 30H43c0-13-13-16-13-30zM43 78h14m-11 7h8M50 3v8M15 20l7 6m63-6-7 6M8 46h10m64 0h10M18 72l8-6m56 6-8-6M45 41l5 9 8-15m-8 15v20"/>',
    blue:'<path d="M17 20h66v46H61L45 81V66H17z"/><circle cx="39" cy="37" r="6"/><circle cx="62" cy="37" r="6"/><path d="M28 55a11 11 0 0 1 22 0m2 0a10 10 0 0 1 21 0"/>',
    gold:'<rect x="17" y="22" width="64" height="64" rx="12"/><path d="M17 41h64M33 14v17m31-17v17M32 54h8m12 0h8m-28 13h8"/><circle cx="71" cy="72" r="19" fill="#f8f6fb"/><path d="M71 61v12l8 5"/>',
    rose:'<rect x="19" y="43" width="62" height="42" rx="6"/><rect x="14" y="31" width="72" height="15" rx="4"/><path d="M50 31v54m0-54C22 33 24 9 36 15c7 3 14 16 14 16Zm0 0C78 33 76 9 64 15c-7 3-14 16-14 16Z"/>'
  };
  alertCards.forEach((card,index)=>{
    const title=card.querySelector('h3').textContent,badge=card.querySelector('div > span'),cardIcon=card.querySelector(':scope > i');badge.classList.add('portal-alert-badge');cardIcon?.setAttribute('aria-hidden','true');
    const labelRow=document.createElement('div');labelRow.className='portal-alert-card-label';const divider=document.createElement('span');divider.className='portal-alert-label-divider';divider.textContent='|';divider.setAttribute('aria-hidden','true');card.querySelector(':scope > div').prepend(labelRow);if(cardIcon)labelRow.append(cardIcon);labelRow.append(divider,badge);
    const kind=Object.keys(alertEmblems).find(name=>card.classList.contains(`portal-alert-${name}`));
    if(kind){const emblem=document.createElement('span');emblem.className='portal-alert-emblem';emblem.setAttribute('aria-hidden','true');emblem.innerHTML=kind==='violet'?learningIllustration:`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" focusable="false">${alertEmblems[kind]}</svg>`;card.append(emblem);}
    const open=document.createElement('button');open.type='button';open.className='portal-alert-open';open.setAttribute('aria-label',`عرض تفاصيل ${title}`);open.setAttribute('aria-haspopup','dialog');
    const close=document.createElement('button');close.type='button';close.className='portal-alert-dismiss';close.textContent='×';close.setAttribute('aria-label',`إغلاق تنبيه ${title}`);card.append(open,close);
    open.addEventListener('click',()=>{
      opener=open;sheet.className=`portal-alert-sheet ${[...card.classList].find(name=>/^portal-alert-(warm|cool|violet|blue|gold|rose)$/.test(name))||''}`;
      sheet.querySelector('.portal-alert-badge').textContent=badge.textContent;sheet.querySelector('.portal-alert-sheet-symbol i').setAttribute('icon-name',cardIcon?.getAttribute('icon-name')||'bell-1');
      sheet.querySelector('h2').textContent=title;sheet.querySelector('.portal-alert-sheet-meta').textContent=card.querySelector('p').textContent;
      const paragraphs=sheet.querySelector('.portal-alert-sheet-copy');paragraphs.replaceChildren();copy[index].slice(1).forEach(text=>{const p=document.createElement('p');p.textContent=text;paragraphs.append(p);});
      document.body.classList.add('has-alert-sheet');sheet.showModal();sheet.scrollTop=0;
    });
    close.addEventListener('click',event=>{event.stopPropagation();card.hidden=true;updateDismissed();const next=alertCards.slice(index+1).find(item=>!item.hidden)||alertCards.find(item=>!item.hidden);(next?.querySelector('.portal-alert-open')||restore).focus({preventScroll:true});showToast('تم إخفاء التنبيه · يمكنك استعادته من أسفل البطاقات');});
  });
})();
