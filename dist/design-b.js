const toast=document.getElementById('b-toast');let toastTimer;
function showToast(message){toast.textContent=message;toast.classList.add('is-visible');clearTimeout(toastTimer);toastTimer=setTimeout(()=>toast.classList.remove('is-visible'),2400)}
document.querySelectorAll('[data-b-action]').forEach(button=>button.addEventListener('click',()=>showToast(`${button.dataset.bAction} · واجهة تجريبية، ربط النظام لاحقًا`)));
document.querySelectorAll('[data-b-scroll]').forEach(button=>button.addEventListener('click',()=>showToast(button.dataset.bScroll==='1'?'انتقلت إلى التحديث التالي':'عدت إلى التحديث السابق')));
const header=document.querySelector('.b-header');
const navigation=document.querySelector('.b-navigation');
const searchTrigger=document.querySelector('.b-search');
const searchPanel=document.getElementById('b-search-panel');
const searchInput=document.getElementById('b-search-input');
const results=document.getElementById('b-search-results');
const searchStatus=document.getElementById('b-search-status');
const reducedMotion=matchMedia('(prefers-reduced-motion: reduce)');
const profileTrigger=document.querySelector('.b-profile-trigger');
const profilePanel=document.getElementById('b-header-profile');
function closeProfile(restoreFocus=false){
  profilePanel.hidden=true;header.classList.remove('is-profile-open');profileTrigger.setAttribute('aria-expanded','false');
  if(restoreFocus)profileTrigger.focus({preventScroll:true});
}
profileTrigger.addEventListener('click',()=>{
  if(!profilePanel.hidden){closeProfile();return;}
  closeSearch(false);profilePanel.hidden=false;header.classList.add('is-profile-open');profileTrigger.setAttribute('aria-expanded','true');
});
document.querySelector('.b-profile-close').addEventListener('click',()=>closeProfile(true));
document.addEventListener('pointerdown',event=>{if(!profilePanel.hidden&&!header.contains(event.target))closeProfile();});
document.addEventListener('keydown',event=>{if(event.key==='Escape'&&!profilePanel.hidden){event.preventDefault();closeProfile(true);}});
header.addEventListener('focusout',()=>requestAnimationFrame(()=>{if(!profilePanel.hidden&&!header.contains(document.activeElement))closeProfile();}));
let selectedResult=-1,visibleResults=[],highlightTimer,highlightedTarget;
function updateHeader(){header.classList.toggle('is-scrolled',window.scrollY>40)}
window.addEventListener('scroll',updateHeader,{passive:true});updateHeader();

// Index the rendered content so titles and their destinations stay in sync.
const searchEntries=[...document.querySelectorAll('.b-section h2,.b-section h3,.b-workspace-section h2,.b-doc-list button,.b-library-catalog button')].filter(element=>!element.closest('.sc-empty')).map((element,index)=>{
  const section=element.closest('.b-section, .b-workspace-section');
  const title=element.matches('h2,h3')?element.innerText:(element.querySelector('.b-doc-copy b')||element.querySelector('b,span'))?.textContent;
  const target=element.matches('h2')?(element.closest('.b-work-card')||section):element.closest('article,button')||element;
  target.dataset.bSearchTarget=String(index);
  const category=section?.dataset.searchCategory||section?.querySelector('h2')?.innerText.trim().replace(/\s+/g,' ')||'مساحة العمل';
  return {title:(title||'').trim().replace(/\s+/g,' '),category,text:element.matches('h2')?title:target.textContent.trim(),target};
});
const normalizeSearch=value=>value.normalize('NFKD').replace(/[\u064B-\u065F\u0670\u0640]/g,'').replace(/[أإآ]/g,'ا').replace(/ى/g,'ي').toLowerCase().trim();
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
function renderSearch(){
  const term=normalizeSearch(searchInput.value);
  visibleResults=term?searchEntries.filter(entry=>normalizeSearch(entry.title+' '+entry.category+' '+entry.text).includes(term)).sort((a,b)=>Number(normalizeSearch(b.title).includes(term))-Number(normalizeSearch(a.title).includes(term))):searchEntries.filter(entry=>entry.target.matches('.b-section'));
  searchStatus.textContent=term?`${visibleResults.length.toLocaleString('ar-EG')} نتائج مطابقة`:'وصول سريع';
  results.replaceChildren();selectedResult=-1;searchInput.removeAttribute('aria-activedescendant');
  visibleResults.forEach((entry,index)=>{
    const option=document.createElement('div');option.className='b-search-option';option.id=`b-result-${index}`;option.setAttribute('role','option');option.setAttribute('aria-selected','false');
    const icon=document.createElement('i');icon.className='iconsax';icon.setAttribute('icon-name','document-text-1');icon.setAttribute('aria-hidden','true');
    const copy=document.createElement('span'),title=document.createElement('strong'),category=document.createElement('small'),arrow=document.createElement('span');
    paintMatch(title,entry.title,searchInput.value);category.textContent=entry.category;arrow.textContent='←';arrow.setAttribute('aria-hidden','true');copy.append(title,category);option.append(icon,copy,arrow);
    option.addEventListener('pointerdown',event=>event.preventDefault());option.addEventListener('click',()=>openResult(index));results.append(option);
  });
  if(!visibleResults.length){const empty=document.createElement('p');empty.className='b-search-empty';empty.textContent='لم نجد نتيجة. جرّب اسم نظام، مستند أو موضوع.';results.append(empty)}
}
function closeSearch(restoreFocus=true){
  searchPanel.hidden=true;navigation.hidden=false;header.classList.remove('is-searching');searchTrigger.setAttribute('aria-expanded','false');searchInput.setAttribute('aria-expanded','false');searchInput.removeAttribute('aria-activedescendant');
  if(restoreFocus)searchTrigger.focus({preventScroll:true});
}
function openSearch(){
  closeProfile();
  navigation.hidden=true;searchPanel.hidden=false;header.classList.add('is-searching');searchTrigger.setAttribute('aria-expanded','true');searchInput.setAttribute('aria-expanded','true');renderSearch();searchInput.focus({preventScroll:true});
}
function openResult(index){
  const selectedEntry=visibleResults[index];if(!selectedEntry)return;
  const reveal={target:selectedEntry.target};document.dispatchEvent(new CustomEvent('sc:reveal',{detail:reveal}));
  const entry={...selectedEntry,target:reveal.target};
  if(entry.target.matches('[data-doc-id]')){libraryInput.value='';activeDocCategory='all';renderLibrary();}
  closeSearch(false);highlightedTarget?.classList.remove('b-search-target');clearTimeout(highlightTimer);
  highlightedTarget=entry.target;entry.target.classList.add('b-search-target');
  if(!entry.target.matches('button,a'))entry.target.setAttribute('tabindex','-1');
  entry.target.focus({preventScroll:true});entry.target.scrollIntoView({behavior:reducedMotion.matches?'instant':'smooth',block:'center'});
  highlightTimer=setTimeout(()=>entry.target.classList.remove('b-search-target'),2400);
}
searchTrigger.addEventListener('click',openSearch);
document.querySelector('.b-search-close').addEventListener('click',()=>closeSearch());
searchInput.addEventListener('input',renderSearch);
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
    const matches=(activeDocCategory==='all'||button.dataset.category===activeDocCategory)&&normalizeSearch(button.querySelector('.b-doc-copy').textContent+' '+button.querySelector('.b-doc-type').textContent).includes(query);
    button.hidden=!matches;if(matches)count++;
  });
  categoryButtons.forEach(button=>button.setAttribute('aria-pressed',String(button.dataset.docCategory===activeDocCategory)));
  document.querySelector('.b-doc-empty').hidden=count>0;
}
libraryInput.addEventListener('input',renderLibrary);
categoryButtons.forEach(button=>button.addEventListener('click',()=>{activeDocCategory=button.dataset.docCategory;renderLibrary()}));
const docDialog=document.querySelector('.b-doc-dialog');
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
  let status=button.querySelector('.b-decision-state');
  if(!status){status=document.createElement('span');status.className='b-decision-state';button.querySelector('.b-item-meta').append(status);}
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
document.querySelector('.b-doc-close').addEventListener('click',()=>docDialog.close());
renderLibrary();

// Native RTL scrolling supports touch/trackpads, buttons, and keyboard navigation.
const alertTrack=document.getElementById('workspace-alerts');
const alertCards=[...alertTrack.querySelectorAll('.b-alert')];
const alertPrev=document.querySelector('.b-alert-prev');
const alertNext=document.querySelector('.b-alert-next');
function updateAlertNavigation(){
  const max=Math.max(0,alertTrack.scrollWidth-alertTrack.clientWidth);
  const progress=Math.abs(alertTrack.scrollLeft);
  alertPrev.disabled=progress<2;alertNext.disabled=progress>=max-2;
  alertTrack.parentElement.classList.toggle('has-before',!alertPrev.disabled);
  alertTrack.parentElement.classList.toggle('has-after',!alertNext.disabled);
  const bounds=alertTrack.getBoundingClientRect();
  const active=alertCards.filter(card=>!card.hidden);
  const visible=active.map((card,index)=>({rect:card.getBoundingClientRect(),index})).filter(({rect})=>Math.min(rect.right,bounds.right)-Math.max(rect.left,bounds.left)>Math.min(rect.width,alertTrack.clientWidth)/2);
  const positionLabel=document.querySelector('.b-alert-position');
  if(visible.length){const first=visible[0].index+1,last=visible.at(-1).index+1;positionLabel.textContent=`${first.toLocaleString('ar-EG')}${first!==last?'–'+last.toLocaleString('ar-EG'):''} من ${active.length.toLocaleString('ar-EG')}`;}else positionLabel.textContent='';
  document.querySelector('.b-alert-carousel .b-alert-toolbar small').textContent=active.length?`${active.length.toLocaleString('ar-EG')} تحديثات`:'لا توجد تحديثات';
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
const workspacePrev=document.querySelector('.b-workspace-prev');
const workspaceNext=document.querySelector('.b-workspace-next');
function updateWorkspaceNavigation(){
  const grid=getComputedStyle(workspaceTrack).display==='grid';
  const controls=workspacePrev.closest('.b-alert-controls');
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

// Hide the entire region so its height is released to the workspace below.
(() => {
  const toggle=document.getElementById('b-alert-visibility'),section=document.getElementById('b-alerts-section');if(!toggle||!section)return;
  function setAlertsVisible(visible){
    section.hidden=!visible;toggle.setAttribute('aria-expanded',String(visible));
    const label=visible?'إخفاء تنبيهات تهمّك':'إظهار تنبيهات تهمّك';toggle.setAttribute('aria-label',label);toggle.title=label;
    requestAnimationFrame(()=>{if(visible)updateAlertNavigation();updateWorkspaceNavigation();});
  }
  toggle.addEventListener('click',()=>setAlertsVisible(section.hidden));
  document.addEventListener('sc:reveal',event=>{if(event.detail?.target?.closest('#b-alerts-section'))setAlertsVisible(true);});
})();

// Alert details use a native modal bottom sheet; dismissal stays reversible in this session.
(() => {
  const carousel=document.querySelector('.b-alert-carousel');if(!carousel)return;
  const copy=[
    ['قرار جديد','نموذج تنبيه لاعتماد خطة التحول الرقمي، يجمع محاور العمل في مسار واضح يمكن الرجوع إليه.','يركز التصور على تبسيط الخدمات وتوحيد الوصول إلى الأنظمة ومشاركة المعرفة بين الفرق.'],
    ['تنبيه نظام','تنبيه توضيحي بموعد تحديث مجدول للخدمات، لمساعدة المستخدم على ترتيب أعماله مسبقًا.','عند ربط النظام الفعلي ستظهر هنا مدة التحديث والخدمات المتأثرة وأي تعليمات ذات صلة.'],
    ['فرصة تعلّم','ورشة توضيحية حول تحويل أفكار تحسين العمل إلى تجارب صغيرة قابلة للتقييم.','تتناول الورشة فهم الاحتياج، وتطوير نموذج أولي، وتبادل الملاحظات بين المشاركين.'],
    ['دعوة لقاء','جلسة تجريبية لمشاركة الخبرات والتجارب بين فرق العمل.','مساحة لعرض تجربة مفيدة، ومناقشة ما تعلمه الفريق، وتدوين الأفكار التي يمكن الاستفادة منها.'],
    ['تذكير مهم','تذكير توضيحي بمراجعة التقارير الشهرية واستكمال البيانات قبل موعد التسليم.','يساعد توحيد المؤشرات وإبراز النتائج والخطوات التالية على إعداد تقرير واضح وسهل القراءة.'],
    ['تحديث الموظفين','نموذج إشعار بواجهة محدثة لدليل المزايا والخدمات الخاصة بالموظفين.','تجمع الصفحة التعريف بالخدمات والمتطلبات ومسارات الوصول في مرجع واحد قابل للمراجعة.']
  ];
  const sheet=document.createElement('dialog');sheet.className='b-alert-sheet';sheet.setAttribute('aria-labelledby','b-alert-sheet-title');
  sheet.innerHTML='<div class="b-alert-sheet-handle" aria-hidden="true"></div><header class="b-alert-sheet-top"><span>تفاصيل التنبيه</span><button type="button" class="b-alert-sheet-close" aria-label="إغلاق تفاصيل التنبيه" autofocus>×</button></header><div class="b-alert-sheet-body"><div class="b-alert-sheet-type"><span class="b-alert-sheet-symbol"><i class="iconsax" aria-hidden="true"></i></span><span class="b-alert-badge"></span></div><h2 id="b-alert-sheet-title"></h2><p class="b-alert-sheet-meta"></p><div class="b-alert-sheet-copy"></div><p class="b-alert-sheet-note">محتوى توضيحي لمعاينة التصميم، وليس إشعارًا فعليًا صادرًا عن المؤسسة.</p></div><footer class="b-alert-sheet-footer"><button type="button" class="b-alert-sheet-done">عودة إلى التنبيهات <span aria-hidden="true">←</span></button><span>مساحة العمل · كليريو</span></footer>';
  document.body.append(sheet);let opener=null,closing=false;
  function closeSheet(){if(!sheet.open||closing)return;closing=true;sheet.classList.add('is-closing');setTimeout(()=>sheet.close(),reducedMotion.matches?0:180);}
  sheet.querySelector('.b-alert-sheet-close').addEventListener('click',closeSheet);sheet.querySelector('.b-alert-sheet-done').addEventListener('click',closeSheet);
  sheet.addEventListener('cancel',event=>{event.preventDefault();closeSheet();});sheet.addEventListener('click',event=>{if(event.target!==sheet)return;const bounds=sheet.getBoundingClientRect();if(event.clientX<bounds.left||event.clientX>bounds.right||event.clientY<bounds.top||event.clientY>bounds.bottom)closeSheet();});
  sheet.addEventListener('close',()=>{document.body.classList.remove('has-alert-sheet');sheet.classList.remove('is-closing');closing=false;if(opener&&!opener.closest('[hidden]'))opener.focus({preventScroll:true});});
  const recovery=document.createElement('div');recovery.className='b-alert-recovery';recovery.hidden=true;
  const empty=document.createElement('span');empty.textContent='أغلقت جميع التنبيهات.';empty.hidden=true;
  const restore=document.createElement('button');restore.type='button';recovery.append(empty,restore);carousel.append(recovery);
  function updateDismissed(){const count=alertCards.filter(card=>card.hidden).length;recovery.hidden=count===0;empty.hidden=count!==alertCards.length;restore.textContent=`استعادة التنبيهات المغلقة (${count.toLocaleString('ar-EG')})`;requestAnimationFrame(updateAlertNavigation);}
  restore.addEventListener('click',()=>{alertCards.forEach(card=>card.hidden=false);updateDismissed();alertTrack.scrollLeft=0;alertCards[0].querySelector('.b-alert-open').focus({preventScroll:true});});
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
    const title=card.querySelector('h3').textContent,badge=card.querySelector('div > span'),cardIcon=card.querySelector(':scope > i');badge.classList.add('b-alert-badge');cardIcon?.setAttribute('aria-hidden','true');
    const labelRow=document.createElement('div');labelRow.className='b-alert-card-label';const divider=document.createElement('span');divider.className='b-alert-label-divider';divider.textContent='|';divider.setAttribute('aria-hidden','true');card.querySelector(':scope > div').prepend(labelRow);if(cardIcon)labelRow.append(cardIcon);labelRow.append(divider,badge);
    const kind=Object.keys(alertEmblems).find(name=>card.classList.contains(`b-alert-${name}`));
    if(kind){const emblem=document.createElement('span');emblem.className='b-alert-emblem';emblem.setAttribute('aria-hidden','true');emblem.innerHTML=kind==='violet'?learningIllustration:`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" focusable="false">${alertEmblems[kind]}</svg>`;card.append(emblem);}
    const open=document.createElement('button');open.type='button';open.className='b-alert-open';open.setAttribute('aria-label',`عرض تفاصيل ${title}`);open.setAttribute('aria-haspopup','dialog');
    const close=document.createElement('button');close.type='button';close.className='b-alert-dismiss';close.textContent='×';close.setAttribute('aria-label',`إغلاق تنبيه ${title}`);card.append(open,close);
    open.addEventListener('click',()=>{
      opener=open;sheet.className=`b-alert-sheet ${[...card.classList].find(name=>/^b-alert-(warm|cool|violet|blue|gold|rose)$/.test(name))||''}`;
      sheet.querySelector('.b-alert-badge').textContent=badge.textContent;sheet.querySelector('.b-alert-sheet-symbol i').setAttribute('icon-name',cardIcon?.getAttribute('icon-name')||'bell-1');
      sheet.querySelector('h2').textContent=title;sheet.querySelector('.b-alert-sheet-meta').textContent=card.querySelector('p').textContent;
      const paragraphs=sheet.querySelector('.b-alert-sheet-copy');paragraphs.replaceChildren();copy[index].slice(1).forEach(text=>{const p=document.createElement('p');p.textContent=text;paragraphs.append(p);});
      document.body.classList.add('has-alert-sheet');sheet.showModal();sheet.scrollTop=0;
    });
    close.addEventListener('click',event=>{event.stopPropagation();card.hidden=true;updateDismissed();const next=alertCards.slice(index+1).find(item=>!item.hidden)||alertCards.find(item=>!item.hidden);(next?.querySelector('.b-alert-open')||restore).focus({preventScroll:true});showToast('تم إخفاء التنبيه · يمكنك استعادته من أسفل البطاقات');});
  });
})();
