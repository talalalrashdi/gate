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

function renderSearch(showDirectory=false){
  if(searchMode==='phone')window.CompanyPortalPhoneDirectory?.search(showDirectory);
  else window.CompanyPortalAuthorizedSearch?.search();
}
function closeSearch(restoreFocus=true){
  window.CompanyPortalPhoneDirectory?.close();window.CompanyPortalAuthorizedSearch?.close();
  searchPanel.hidden=true;navigation.hidden=false;header.classList.remove('is-searching');searchTriggers.forEach(trigger=>trigger.setAttribute('aria-expanded','false'));searchInput.setAttribute('aria-expanded','false');searchInput.removeAttribute('aria-activedescendant');
  if(restoreFocus)activeSearchTrigger.focus({preventScroll:true});
}
function openSearch(mode='all',trigger=searchTrigger){
  window.CompanyPortalPhoneDirectory?.close();window.CompanyPortalAuthorizedSearch?.close();
  if(separateSearch){
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

    if(window.CompanyPortalAuthorizedSearch)window.CompanyPortalAuthorizedSearch.open();
    else{results.replaceChildren();searchStatus.textContent='خدمة البحث غير متاحة. أعد تحميل الصفحة.';}
  }
  searchInput.focus({preventScroll:true});
}
searchTriggers.forEach(trigger=>trigger.addEventListener('click',()=>openSearch(trigger.dataset.searchMode||'all',trigger)));
searchPanel.querySelector('.portal-phone-directory')?.addEventListener('click',()=>{searchInput.value='';renderSearch(true);searchInput.focus({preventScroll:true});results.scrollTop=0;});

document.querySelector('.portal-search-close').addEventListener('click',()=>{searchInput.value='';renderSearch();searchInput.focus({preventScroll:true});});
searchInput.addEventListener('input',()=>renderSearch());
searchPanel.querySelectorAll('[name="portal-search-scope"]').forEach(input=>input.addEventListener('change',()=>{
  searchInput.placeholder=input.value==='phone'?'ابحث بالاسم أو رقم الهاتف':'عن ماذا تبحث اليوم؟';
  renderSearch();
}));
searchInput.addEventListener('keydown',event=>{
  if(searchMode!=='phone'){window.CompanyPortalAuthorizedSearch?.key(event);return;}
  window.CompanyPortalPhoneDirectory?.key(event);
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

// Profile panel for the signed-in employee, read while the panel is open:
// name/title from Portal.UserProfile_Get, arrival/expected-leave (shown only when present) from
// Portal.UserAttendance_Get, and leave balance from Portal.UserLeaveBalance_Get.
(() => {
  const base=document.querySelector('meta[name="companyportal-api-base"]')?.content;
  if(!base||!profilePanel)return;
  const id=s=>document.getElementById('portal-profile-'+s), number=new Intl.NumberFormat('ar-OM',{maximumFractionDigits:2});
  const rows={arrival:id('arrival').parentElement,departure:id('departure').parentElement};
  const time=value=>typeof value==='string'&&/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/.test(value)?value.slice(11,16):null;
  const days=value=>value==null?'—':number.format(value)+' يوم';
  function showTime(field,value){id(field).textContent=value||'';rows[field].hidden=!value;}
  const sources={
    person:row=>{if(!row)return;if(row.displayName)id('name').textContent=row.displayName;const position=[row.jobTitle,row.department].filter(Boolean).join(' · ');if(position)id('position').textContent=position;},
    attendance:row=>{showTime('arrival',time(row?.arrivalAt));showTime('departure',time(row?.expectedLeaveAt));},
    'leave-balance':row=>{id('holiday').textContent=days(row?.holidayDays);id('deduction').textContent=days(row?.daysToBeDeleted);}
  };
  let generation=0,controller;
  function cancel(){++generation;controller?.abort();showTime('arrival',null);showTime('departure',null);id('holiday').textContent='—';id('deduction').textContent='—';}
  async function load(){
    if(profilePanel.hidden||document.hidden)return;
    const stamp=generation;controller?.abort();const current=controller=new AbortController();
    await Promise.all(Object.entries(sources).map(async([key,apply])=>{
      try{
        const response=await fetch(new URL('api/profile/'+key,new URL(base.replace(/\/?$/,'/'),location.href)),{credentials:'include',cache:'no-store',signal:AbortSignal.any([current.signal,AbortSignal.timeout(15000)])});
        if(!response.ok)return;const row=(await response.json()).data;
        if(stamp!==generation||profilePanel.hidden||current.signal.aborted)return;
        apply(row);
      }catch{}
    }));
  }
  new MutationObserver(()=>{cancel();if(!profilePanel.hidden)void load();}).observe(profilePanel,{attributes:true,attributeFilter:['hidden']});
  document.addEventListener('visibilitychange',()=>{cancel();if(!document.hidden&&!profilePanel.hidden)void load();});
  window.addEventListener('pagehide',cancel);window.addEventListener('pageshow',e=>{if(e.persisted&&!profilePanel.hidden){cancel();void load();}});
})();
