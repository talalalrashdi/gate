(() => {
  const planner=document.querySelector('[data-schedule-source="exchange"]'),base=document.querySelector('meta[name="companyportal-api-base"]')?.content;
  if(!planner||!base)return;
  const root=new URL(base.replace(/\/?$/,'/'),location.href),endpoint=path=>new URL(path,root).href;
  const node=(tag,text,css)=>{const n=document.createElement(tag);if(text!==undefined)n.textContent=text;if(css)n.className=css;return n;};
  const button=(text,label)=>{const b=node('button',text);b.type='button';if(label)b.setAttribute('aria-label',label);return b;};
  let zone='Asia/Muscat',catalog=[],data=null,stream,retry,delay=5000,generation=0,leaving=false,first=true,lastNotice=0,initialized=false;
  const dateFormat=()=>new Intl.DateTimeFormat('en-CA',{timeZone:zone,year:'numeric',month:'2-digit',day:'2-digit'});
  const key=value=>{const parts=dateFormat().formatToParts(new Date(value));return ['year','month','day'].map(t=>parts.find(p=>p.type===t).value).join('-');};
  const day=value=>new Date(value+'T12:00:00Z');
  const iso=value=>value.toISOString().slice(0,10);
  let today=key(Date.now()),selected=today,month=day(today.slice(0,7)+'-01');
  const main=node('div',undefined,'personal-calendar-main'),head=node('header',undefined,'personal-planner-head'),heading=node('div');
  heading.append(node('h2','تقويم الأعمال'),node('small','Outlook Exchange · عرض فقط'));
  const refresh=button('تحديث','إعادة الاتصال بتقويم Outlook');head.append(heading,refresh);
  const label=node('label','التقويم'),picker=node('select');picker.setAttribute('aria-label','اختيار تقويم Outlook');label.append(picker);
  const status=node('p','جارٍ الاتصال بتقويم Outlook…','exchange-schedule-status');status.setAttribute('role','status');status.setAttribute('aria-live','polite');
  const nav=node('div',undefined,'personal-month-nav'),previous=button('→','الشهر السابق'),next=button('←','الشهر التالي'),monthLabel=node('strong'),goToday=button('اليوم','العودة إلى اليوم');
  monthLabel.setAttribute('aria-live','polite');nav.append(previous,monthLabel,next,goToday);
  const grid=node('div',undefined,'personal-month-grid');grid.setAttribute('aria-label','أيام الشهر ومواعيد Outlook');
  main.append(head,label,status,nav,grid);
  const agenda=node('section',undefined,'exchange-agenda'),dayHeading=node('h3'),appointments=node('div',undefined,'exchange-agenda-items');
  const tasksHeading=node('h3','مهامي غير المكتملة'),filters=node('div',undefined,'exchange-task-filters'),taskList=node('div',undefined,'exchange-task-items');
  filters.setAttribute('role','group');filters.setAttribute('aria-label','تصفية مهام Outlook');
  let taskFilter='all';
  for(const [value,caption] of [['all','الكل'],['overdue','متأخرة'],['today','اليوم'],['upcoming','قادمة']]){const b=button(caption);b.dataset.filter=value;b.setAttribute('aria-pressed',String(value===taskFilter));b.addEventListener('click',()=>{taskFilter=value;renderTasks();});filters.append(b);}
  agenda.append(dayHeading,appointments,tasksHeading,filters,taskList);
  const oldAdd=document.getElementById('planner-task-add-toggle');if(oldAdd)oldAdd.hidden=true;
  planner.replaceChildren(main,agenda);planner.classList.add('exchange-planner');
  const composer=document.getElementById('planner-task-composer');if(composer){composer.hidden=true;composer.querySelectorAll('button,input,select,textarea').forEach(n=>{n.disabled=true;});}
  const float=document.getElementById('portal-floating-calendar'),floatBody=document.getElementById('portal-floating-calendar-body'),summary=document.getElementById('portal-calendar-summary');
  let expanded=false;
  const setExpanded=value=>{expanded=value;floatBody.hidden=!value;summary.hidden=value;float.classList.toggle('is-expanded',value);const b=document.getElementById('portal-calendar-toggle');b.textContent=value?'−':'＋';b.setAttribute('aria-expanded',String(value));b.setAttribute('aria-label',value?'طي تقويم الأعمال':'توسيع تقويم الأعمال');};
  document.getElementById('portal-calendar-toggle')?.addEventListener('click',()=>setExpanded(!expanded));
  document.getElementById('portal-calendar-content-toggle')?.closest('.portal-floating-calendar-handle')?.setAttribute('hidden','');
  const intersects=(item,date)=>key(item.start)<=date&&key(new Date(Math.max(Date.parse(item.start)+1,Date.parse(item.end))-1))>=date;
  const time=value=>new Intl.DateTimeFormat('ar-OM-u-nu-latn',{timeZone:zone,hour:'2-digit',minute:'2-digit'}).format(new Date(value));
  const appointmentRow=item=>{const row=node('article',undefined,'exchange-appointment');row.classList.toggle('is-cancelled',item.isCancelled);row.append(node('strong',item.subject||'(بدون عنوان)'));const details=[item.isAllDay?'طوال اليوم':time(item.start)+' – '+time(item.end),item.location,item.organizer,item.isCancelled?'ملغي':'',item.responseStatus==='Tentative'?'مبدئي':item.responseStatus==='NoResponseReceived'?'لم تتم الاستجابة':''].filter(Boolean);row.append(node('small',details.join(' · ')));return row;};
  function renderTasks(){
    filters.querySelectorAll('button').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.filter===taskFilter)));taskList.replaceChildren();
    if(!data){taskList.append(node('p','المهام غير متاحة حاليًا.'));return;}
    const rows=data.tasks.items.filter(t=>taskFilter==='all'||taskFilter==='today'&&t.dueDate===today||taskFilter==='overdue'&&t.dueDate&&t.dueDate<today||taskFilter==='upcoming'&&t.dueDate&&t.dueDate>today);
    const states={NotStarted:'لم تبدأ',InProgress:'قيد التنفيذ',WaitingOnOthers:'بانتظار الآخرين',Deferred:'مؤجلة',Completed:'مكتملة'};
    rows.forEach(task=>{const row=node('article',undefined,'exchange-task');row.classList.toggle('is-overdue',!!task.dueDate&&task.dueDate<today);row.append(node('strong',task.subject||'(بدون عنوان)'));row.append(node('small',[task.dueDate?'الاستحقاق: '+task.dueDate:'بدون تاريخ استحقاق',states[task.status]||'مهمة',task.importance==='High'?'أولوية عالية':'',task.percentComplete?Math.round(task.percentComplete)+'%':''].filter(Boolean).join(' · ')));taskList.append(row);});
    if(!rows.length)taskList.append(node('p','لا توجد مهام ضمن هذا الاختيار.'));
    if(data.tasks.truncated)taskList.append(node('p','تظهر أول 500 مهمة؛ افتح Outlook للاطلاع على البقية.','exchange-schedule-warning'));
  }
  function render(){
    today=key(Date.now());monthLabel.textContent=new Intl.DateTimeFormat('ar-OM-u-nu-latn',{timeZone:'UTC',month:'long',year:'numeric'}).format(month);
    previous.disabled=month.getUTCFullYear()<=1901&&month.getUTCMonth()===0;next.disabled=month.getUTCFullYear()>=2099&&month.getUTCMonth()===11;
    const focused=grid.contains(document.activeElement)?document.activeElement.dataset.date:null;grid.replaceChildren();
    for(const name of ['أحد','اثنين','ثلاثاء','أربعاء','خميس','جمعة','سبت'])grid.append(node('span',name,'personal-weekday'));
    const start=new Date(month);start.setUTCDate(1-start.getUTCDay());
    for(let i=0;i<42;i++){const date=new Date(start);date.setUTCDate(start.getUTCDate()+i);const value=iso(date),b=button(String(date.getUTCDate()));b.dataset.date=value;b.setAttribute('aria-pressed',String(value===selected));b.setAttribute('aria-label',value+(data?.calendar.items.some(item=>intersects(item,value))?' · توجد مواعيد':''));if(value===today)b.setAttribute('aria-current','date');b.classList.toggle('is-outside',date.getUTCMonth()!==month.getUTCMonth());b.classList.toggle('has-tasks',!!data?.calendar.items.some(item=>intersects(item,value)));b.addEventListener('click',()=>{selected=value;render();[...grid.children].find(n=>n.dataset.date===value)?.focus({preventScroll:true});});b.addEventListener('keydown',event=>{const delta={ArrowRight:-1,ArrowLeft:1,ArrowUp:-7,ArrowDown:7}[event.key];if(delta===undefined)return;event.preventDefault();const target=new Date(date);target.setUTCDate(target.getUTCDate()+delta);const targetButton=[...grid.children].find(n=>n.dataset.date===iso(target));if(targetButton){selected=iso(target);render();[...grid.children].find(n=>n.dataset.date===selected)?.focus({preventScroll:true});}});grid.append(b);}
    if(focused)[...grid.children].find(n=>n.dataset.date===focused)?.focus({preventScroll:true});
    dayHeading.textContent=(selected===today?'جدول اليوم · ':'جدول · ')+new Intl.DateTimeFormat('ar-OM-u-nu-latn',{timeZone:'UTC',weekday:'long',day:'numeric',month:'long'}).format(day(selected));appointments.replaceChildren();
    const selectedItems=data?.calendar.items.filter(item=>intersects(item,selected))||[];selectedItems.forEach(item=>appointments.append(appointmentRow(item)));
    if(!selectedItems.length)appointments.append(node('p',data?'لا توجد مواعيد في هذا اليوم.':'الجدول غير متاح حاليًا.'));
    if(data?.calendar.truncated)appointments.append(node('p','نتائج التقويم كثيرة وقد لا تظهر كلها. افتح Outlook للاطلاع على الجدول الكامل.','exchange-schedule-warning'));
    renderTasks();summary.replaceChildren();
    if(!data)summary.append(node('p','تقويم Outlook والمهام غير متاحين حاليًا.'));
    else{const upcoming=data.calendar.items.filter(item=>!item.isCancelled&&Date.parse(item.end)>Date.now()).slice(0,2);if(!upcoming.length)summary.append(node('p','لا توجد مواعيد قادمة ضمن الفترة المعروضة.'));upcoming.forEach(item=>{const b=button('');b.className='portal-calendar-summary-item';b.append(node('strong',item.subject||'(بدون عنوان)'),node('small',key(item.start)+' · '+(item.isAllDay?'طوال اليوم':time(item.start))));b.addEventListener('click',()=>{selected=key(item.start);render();setExpanded(true);});summary.append(b);});summary.append(node('p',`${data.tasks.items.length}${data.tasks.truncated?'+':''} مهمة غير مكتملة`));}
    const notificationItems=data?[...data.calendar.items.filter(i=>!i.isCancelled&&Date.parse(i.end)>Date.now()).slice(0,5).map(i=>({title:i.subject||'موعد',meta:key(i.start)+' · '+(i.isAllDay?'طوال اليوم':time(i.start))})),...data.tasks.items.slice(0,5).map(t=>({title:t.subject||'مهمة',meta:t.dueDate||'بدون تاريخ استحقاق'}))]:[];
    window.CompanyPortalSchedule={notifications:notificationItems};document.dispatchEvent(new CustomEvent('companyportal:schedule-updated'));
  }
  function range(){const start=new Date(month);start.setUTCDate(1-start.getUTCDay());const end=new Date(start);end.setUTCDate(start.getUTCDate()+42);return {from:iso(start),to:iso(end)};}
  function clear(message){data=null;status.textContent=message;render();}
  function stop(){++generation;stream?.close();stream=null;clearTimeout(retry);retry=null;}
  function reconnect(serial){if(serial!==generation)return;stop();clear('اتصال Outlook غير متاح حاليًا. جارٍ إعادة الاتصال…');if(!leaving)retry=setTimeout(()=>{retry=null;connect();},delay);delay=Math.min(30000,delay*2);}
  function validate(value,dates){
    if(typeof value.timeZone!=='string')throw new Error('Missing schedule timezone');
    new Intl.DateTimeFormat('ar-OM',{timeZone:value.timeZone});
    const validDay=d=>d===null||typeof d==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(d)&&Number.isFinite(Date.parse(d));
    if(value.calendarKey!==picker.value||value.from!==dates.from||value.to!==dates.to||!Array.isArray(value.calendar?.items)||value.calendar.items.length>1000||!Array.isArray(value.tasks?.items)||value.tasks.items.length>500
      ||value.calendar.items.some(i=>typeof i.itemId!=='string'||!i.itemId||i.itemId.length>8000||typeof i.subject!=='string'||!Number.isFinite(Date.parse(i.start))||!Number.isFinite(Date.parse(i.end))||Date.parse(i.end)<Date.parse(i.start)||typeof i.isAllDay!=='boolean'||typeof i.isCancelled!=='boolean'||typeof i.location!=='string'||typeof i.organizer!=='string')
      ||value.tasks.items.some(t=>typeof t.itemId!=='string'||!t.itemId||typeof t.subject!=='string'||!validDay(t.dueDate)||!validDay(t.startDate)||!Number.isFinite(t.percentComplete)))throw new Error('Invalid schedule snapshot');
  }
  function connect(){
    if(leaving||!catalog.length)return;stop();first=true;clear('جارٍ الاتصال بتقويم Outlook والمهام…');const serial=generation,dates=range();
    const params=new URLSearchParams({...dates,calendar:picker.value});const source=new EventSource(endpoint('api/schedule/stream?'+params),{withCredentials:true});stream=source;
    source.addEventListener('schedule',event=>{if(serial!==generation)return;try{const value=JSON.parse(event.data);validate(value,dates);const previous=data;data=value;zone=value.timeZone;render();status.textContent=value.calendarLive?'متصل بـ Outlook · تحديث مباشر':'المهام مباشرة · التقويم المشترك يحتاج تحديثًا يدويًا';delay=5000;
      if(!first&&Date.now()-lastNotice>2000){const oldAppointments=new Set(previous?.calendar.items.map(i=>i.itemId)),oldTasks=new Set(previous?.tasks.items.map(i=>i.itemId));const added=value.calendar.items.some(i=>!oldAppointments.has(i.itemId))||value.tasks.items.some(i=>!oldTasks.has(i.itemId));window.showToast?.(added?'ورد موعد أو مهمة جديدة في Outlook.':'تم تحديث تقويم Outlook أو المهام.');lastNotice=Date.now();}first=false;
    }catch{reconnect(serial);}});
    source.addEventListener('unavailable',()=>reconnect(serial));source.onerror=()=>reconnect(serial);
  }
  async function load(){
    stop();clear('جارٍ التحقق من اتصال Outlook…');const serial=generation,previousKey=picker.value,previousZone=zone;picker.disabled=true;
    try{const response=await fetch(endpoint('api/schedule/calendars'),{credentials:'include',cache:'no-store',signal:AbortSignal.timeout(15000)});if(!response.ok)throw new Error();const value=await response.json();if(serial!==generation)return;
      if(typeof value.timeZone!=='string'||!Array.isArray(value.calendars)||value.calendars.length>11||value.calendars.some(c=>typeof c.name!=='string'||!/^[a-zA-Z0-9_-]{1,40}$/.test(c.key))||new Set(value.calendars.map(c=>c.key)).size!==value.calendars.length)throw new Error();
      new Intl.DateTimeFormat('ar-OM',{timeZone:value.timeZone});zone=value.timeZone;catalog=value.calendars;today=key(Date.now());if(!initialized||zone!==previousZone){selected=today;month=day(today.slice(0,7)+'-01');}initialized=true;picker.replaceChildren();catalog.forEach(c=>{const option=node('option',c.name+(c.isOwn?'':' · مشترك'));option.value=c.key;picker.append(option);});if(catalog.some(c=>c.key===previousKey))picker.value=previousKey;picker.disabled=false;
      if(!catalog.length){clear('لا توجد تقاويم متاحة لصلاحيات حسابك.');return;}connect();
    }catch{if(serial===generation){catalog=[];picker.replaceChildren(node('option','التقويم غير متاح حاليًا'));clear('تقويم Outlook والمهام غير مهيأين أو غير متاحين حاليًا.');}}
  }
  picker.addEventListener('change',connect);refresh.addEventListener('click',load);
  previous.addEventListener('click',()=>{month.setUTCMonth(month.getUTCMonth()-1);selected=iso(month);connect();render();});next.addEventListener('click',()=>{month.setUTCMonth(month.getUTCMonth()+1);selected=iso(month);connect();render();});goToday.addEventListener('click',()=>{today=key(Date.now());selected=today;month=day(today.slice(0,7)+'-01');connect();render();});
  document.addEventListener('visibilitychange',()=>{if(document.hidden)return;const current=key(Date.now());if(current!==today){const followingToday=selected===today;today=current;if(followingToday){selected=today;month=day(today.slice(0,7)+'-01');connect();}render();}});
  window.addEventListener('pagehide',()=>{leaving=true;stop();clear('اتصال Outlook متوقف.');});window.addEventListener('pageshow',event=>{if(event.persisted){leaving=false;load();}});
  render();load();
})();
