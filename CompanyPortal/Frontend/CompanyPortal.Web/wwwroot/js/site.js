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
let selectedResult=-1,visibleResults=[];
const headerSpace = document.createElement('div');
headerSpace.className = 'portal-header-scroll-space';
headerSpace.hidden = true;
function updateHeader(){
  const current = Math.max(0, window.scrollY);
  header.classList.toggle('is-scrolled', current > 40);
  const hero=document.querySelector('.portal-personal-zone');
  header.classList.toggle('is-past-hero',!!hero&&hero.getBoundingClientRect().bottom<=header.offsetHeight);
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
window.addEventListener('scroll',updateHeader,{passive:true});window.addEventListener('resize',updateHeader);const headerHero=document.querySelector('.portal-personal-zone');if(headerHero)new ResizeObserver(updateHeader).observe(headerHero);updateHeader();

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
  if(searchMode!=='phone'||!separateSearch||!query||!visibleResults.length||visibleResults[0].recent)return;
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
  if(searchMode!=='phone'){window.CompanyPortalAuthorizedSearch?.search();return;}
  const term=normalizeSearch(searchInput.value);
  const phoneOnly=separateSearch?searchMode==='phone':searchPanel.querySelector('[name="portal-search-scope"]:checked')?.value==='phone';
  const entries=phoneSamples;
  visibleResults=term?entries.filter(entry=>normalizeSearch(entry.title+' '+entry.category+' '+entry.text).includes(term)).sort((a,b)=>Number(normalizeSearch(b.title).includes(term))-Number(normalizeSearch(a.title).includes(term))):entries;
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
  window.CompanyPortalAuthorizedSearch?.close();visibleResults=[];selectedResult=-1;
  searchPanel.hidden=true;navigation.hidden=false;header.classList.remove('is-searching');searchTriggers.forEach(trigger=>trigger.setAttribute('aria-expanded','false'));searchInput.setAttribute('aria-expanded','false');searchInput.removeAttribute('aria-activedescendant');
  if(restoreFocus)activeSearchTrigger.focus({preventScroll:true});
}
function openSearch(mode='all',trigger=searchTrigger){
  window.CompanyPortalAuthorizedSearch?.close();
  if(separateSearch){
    if(!searchPanel.hidden)rememberSearch();
    searchMode=mode==='phone'?'phone':'all';activeSearchTrigger=trigger;
    const phoneOnly=searchMode==='phone',title=phoneOnly?'البحث في دليل الهاتف':'البحث العام';
    document.getElementById('portal-search-title').textContent=title;
    searchPanel.dataset.searchMode=searchMode;
    searchPanel.querySelector('.portal-phone-important').hidden=!phoneOnly;
    searchPanel.querySelector('.portal-phone-directory').hidden=!phoneOnly;
    searchInput.value='';
    searchInput.placeholder=phoneOnly?'ابحث بالاسم أو الإدارة أو رقم الهاتف':'ابحث عن استمارة، وثيقة أو نظام…';
    searchInput.setAttribute('aria-label',title);
    results.setAttribute('aria-label',phoneOnly?'نتائج دليل الهاتف':'نتائج البحث العام');
    const caption=searchPanel.querySelector('.portal-search-caption small');caption.textContent=phoneOnly?'جهات الاتصال وأرقام التواصل':'';caption.hidden=!phoneOnly;
    searchTriggers.forEach(button=>button.setAttribute('aria-expanded',String(button===trigger)));
  }
  closeProfile();
  closeNotifications();
  navigation.hidden=!separateSearch;searchPanel.hidden=false;header.classList.add('is-searching');activeSearchTrigger.setAttribute('aria-expanded','true');searchInput.setAttribute('aria-expanded','true');
  if(searchMode==='phone')renderSearch();else{
    visibleResults=[];selectedResult=-1;
    if(window.CompanyPortalAuthorizedSearch)window.CompanyPortalAuthorizedSearch.open();
    else{results.replaceChildren();searchStatus.textContent='خدمة البحث غير متاحة. أعد تحميل الصفحة.';}
  }
  searchInput.focus({preventScroll:true});
}
function openResult(index){
  const selectedEntry=visibleResults[index];if(!selectedEntry)return;
  if(selectedEntry.recent){searchInput.value=selectedEntry.title;renderSearch();searchInput.focus({preventScroll:true});rememberSearch();return;}
  rememberSearch();
  if(selectedEntry.contact){setActiveResult(index);results.children[index].focus({preventScroll:true});return;}

}
searchTriggers.forEach(trigger=>trigger.addEventListener('click',()=>openSearch(trigger.dataset.searchMode||'all',trigger)));
searchPanel.querySelector('.portal-phone-directory')?.addEventListener('click',()=>{searchInput.value='';renderSearch(true);searchInput.focus({preventScroll:true});results.scrollTop=0;});

document.querySelector('.portal-search-close').addEventListener('click',()=>{searchInput.value='';renderSearch();searchInput.focus({preventScroll:true});});
searchInput.addEventListener('input',()=>{renderSearch();clearTimeout(recentSearchTimer);if(separateSearch)recentSearchTimer=setTimeout(rememberSearch,600);});
searchPanel.querySelectorAll('[name="portal-search-scope"]').forEach(input=>input.addEventListener('change',()=>{
  searchInput.placeholder=input.value==='phone'?'ابحث بالاسم أو رقم الهاتف':'عن ماذا تبحث اليوم؟';
  renderSearch();
}));
searchInput.addEventListener('keydown',event=>{
  if(searchMode!=='phone'){window.CompanyPortalAuthorizedSearch?.key(event);return;}
  if(event.key==='ArrowDown'||event.key==='ArrowUp'){
    event.preventDefault();if(!visibleResults.length)return;
    const direction=event.key==='ArrowDown'?1:-1;setActiveResult(selectedResult<0?(direction===1?0:visibleResults.length-1):(selectedResult+direction+visibleResults.length)%visibleResults.length);
  }else if(event.key==='Enter'){event.preventDefault();openResult(selectedResult<0?0:selectedResult)}
});
document.addEventListener('keydown',event=>{
  if((event.ctrlKey||event.metaKey)&&event.key.toLowerCase()==='k'){event.preventDefault();openSearch()}
  if(event.key==='Escape'&&!searchPanel.hidden){event.preventDefault();closeSearch()}
});
document.addEventListener('pointerdown',event=>{if(!searchPanel.hidden&&!searchPanel.contains(event.target)&&!event.target.closest('.portal-search'))closeSearch(false)});

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

// Read each profile source separately, only for the signed-in employee and while the panel is open.
(() => {
  const base=document.querySelector('meta[name="companyportal-api-base"]')?.content;
  if(!base||!profilePanel)return;
  const id=s=>document.getElementById('portal-profile-'+s), number=new Intl.NumberFormat('ar-OM',{maximumFractionDigits:2});
  const sources={attendance:{fields:['name','position','arrival','departure']},'leave-balance':{fields:['holiday','deduction']}};
  let generation=0;
  const time=value=>typeof value==='string'&&/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/.test(value)?value.slice(11,16):'—';
  const date=value=>typeof value==='string'&&/^\d{4}-\d{2}-\d{2}/.test(value)?value.slice(0,10):null;
  const label=key=>key==='attendance'?'attendance':'leave';
  function clear(key){sources[key].fields.forEach(field=>{id(field).textContent='—';});}
  function cancel(){++generation;Object.values(sources).forEach(source=>source.controller?.abort());Object.keys(sources).forEach(key=>{clear(key);id(label(key)+'-status').textContent='';id(label(key)+'-retry').hidden=true;});}
  async function load(key){
    if(profilePanel.hidden||document.hidden)return;
    const source=sources[key],stamp=generation;source.controller?.abort();const controller=new AbortController();source.controller=controller;
    const status=id(label(key)+'-status'),retry=id(label(key)+'-retry');clear(key);retry.hidden=true;status.textContent=key==='attendance'?'جارٍ تحميل بيانات الدوام…':'جارٍ تحميل رصيد الإجازات…';
    try{
      const response=await fetch(new URL('api/profile/'+key,new URL(base.replace(/\/?$/,'/'),location.href)),{credentials:'include',cache:'no-store',signal:AbortSignal.any([controller.signal,AbortSignal.timeout(15000)])});
      if(!response.ok)throw new Error(String(response.status));const result=await response.json();
      if(stamp!==generation||profilePanel.hidden||controller.signal.aborted)return;
      const row=result.data;
      if(key==='attendance'){
        if(!row){status.textContent='لا تتوفر بيانات المستخدم والدوام حاليًا.';return;}
        id('name').textContent=row.displayName||'—';id('position').textContent=[row.jobTitle,row.department].filter(Boolean).join(' · ')||'—';
        id('arrival').textContent=time(row.arrivalAt);id('departure').textContent=time(row.expectedLeaveAt);
        status.textContent=date(row.attendanceDate)?'بيانات الدوام بتاريخ '+date(row.attendanceDate):'لم يُسجّل حضور اليوم.';
      }else{
        if(!row){status.textContent='لا يتوفر رصيد إجازات مسجل حاليًا.';return;}
        id('holiday').textContent=row.holidayDays==null?'—':number.format(row.holidayDays)+' يوم';id('deduction').textContent=row.daysToBeDeleted==null?'—':number.format(row.daysToBeDeleted)+' يوم';
        status.textContent=[date(row.asOfDate)?'الرصيد بتاريخ '+date(row.asOfDate):'',date(row.deletionDate)?'موعد حذف الأيام: '+date(row.deletionDate):''].filter(Boolean).join(' · ');
      }
    }catch(e){
      if(stamp!==generation||controller.signal.aborted||profilePanel.hidden)return;clear(key);
      status.textContent=e.message==='401'||e.message==='403'?'حسابك غير مخوّل لعرض هذه البيانات.':key==='attendance'?'تعذر تحميل بيانات المستخدم والدوام. أعد المحاولة.':'تعذر تحميل رصيد الإجازات. أعد المحاولة.';retry.hidden=false;
    }
  }
  new MutationObserver(()=>{cancel();if(!profilePanel.hidden)Object.keys(sources).forEach(load);}).observe(profilePanel,{attributes:true,attributeFilter:['hidden']});
  Object.keys(sources).forEach(key=>id(label(key)+'-retry').addEventListener('click',()=>load(key)));
  document.addEventListener('visibilitychange',()=>{cancel();if(!document.hidden&&!profilePanel.hidden)Object.keys(sources).forEach(load);});
  window.addEventListener('pagehide',cancel);window.addEventListener('pageshow',e=>{if(e.persisted&&!profilePanel.hidden){cancel();Object.keys(sources).forEach(load);}});
})();
