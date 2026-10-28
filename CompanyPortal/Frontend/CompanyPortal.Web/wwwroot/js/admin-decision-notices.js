(() => {
 const panels=[...document.querySelectorAll('[data-notice-admin]')],core=window.AdminCore;if(!panels.length)return;
 let data,pending,saving=false;const trackers=new Map();
 // Specific messages for the reasons the API rejects a save (see DecisionNoticesAdministrationController).
 const failure=(path,body,status)=>!body?'تعذر تحميل الإعدادات. تحقق من الاتصال وأعد المحاولة.':status===404?'القرار لم يعد متاحًا لحسابك. أعد تحميل القائمة.':status===400&&path.endsWith('/window')?'تحقق من التاريخين: أدخل البداية والنهاية معًا، والنهاية بعد البداية.':status===400?'تحقق من مدة العرض (من 1 إلى 365 يومًا) وأنواع القرارات (حتى 16 نوعًا).':status===403?'ليس لديك صلاحية إدارة هذا القسم.':'تعذر الحفظ. تحقق من الاتصال وأعد المحاولة.';
 const request=async(path='',body)=>{const response=await core.request('api/admin/decision-notices'+path,{method:body?'PUT':'GET',body,header:'decision-notices',handled:body?[400,404]:[]});if(!response.ok)throw new Error(failure(path,body,response.status));return response.status===204?null:response.json();};
 const option=(value,text)=>{const n=document.createElement('option');n.value=value;n.textContent=text;return n;};
 const section=panel=>Number(panel.dataset.noticeAdmin)===1?'notices':'alerts';
 const message=(panel,text,error=false)=>core.feedback(panel.querySelector('[data-notice-message]'),text,error);
 function settings(panel){
  const setting=data.settings.find(s=>s.channelID===Number(panel.dataset.noticeAdmin)),form=panel.querySelector('[data-notice-settings]');
  form.elements.days.value=setting.durationDays;form.elements.active.checked=setting.active;const types=panel.querySelector('[data-notice-types]');types.replaceChildren();
  AdminChanges.tag(form,section(panel),'notice-settings',setting.channelID);
  for(const type of data.types){const label=document.createElement('label'),input=document.createElement('input');input.type='checkbox';input.name='type';input.value=type;input.checked=setting.decisionTypes.includes(type);label.append(input,document.createTextNode(type));types.append(label);}
 }
 function editWindow(panel){
  const form=panel.querySelector('[data-notice-window]'),id=form.elements.decision.value,channel=Number(panel.dataset.noticeAdmin),w=data.windows.find(w=>w.channelID===channel&&w.decisionId===id),row=data.decisions.find(r=>r.decisionId===id),setting=data.settings.find(s=>s.channelID===channel);
  form.elements.from.value=w?.fromAt?.slice(0,19)||'';form.elements.to.value=w?.toAt?.slice(0,19)||'';form.elements.hidden.checked=w?.isHidden||false;
  panel.querySelector('[data-notice-preview]').textContent=row?('نُشر في '+row.publishedAt.replace('T',' ')+' · '+(setting.decisionTypes.includes(row.decisionType)?'نوع مشمول؛ المدة العامة '+setting.durationDays+' أيام':'النوع غير مشمول في إعدادات هذا القسم')):'';
  AdminChanges.tag(form,section(panel),'notice-window',id?channel+':'+id:null);
  form.dataset.selectedDecision=id;trackers.get(form)?.saved();
 }
 function populate(panel){
  if(!core.can(section(panel)))return;settings(panel);const win=panel.querySelector('[data-notice-window]'),selected=win.elements.decision.value;
  win.elements.decision.replaceChildren(option('','اختر قرارًا'),...data.decisions.map(r=>option(r.decisionId,r.decisionType+' — '+r.title)));win.elements.decision.value=selected;
  editWindow(panel);panel.querySelectorAll('form>fieldset').forEach(f=>f.disabled=false);trackers.get(panel.querySelector('[data-notice-settings]'))?.saved();
 }
 async function load(){if(pending||saving)return pending;pending=(async()=>{try{data=await request();panels.forEach(p=>{populate(p);if(core.can(section(p)))message(p,'تم تحميل الإعدادات. التنبيهات المقروءة تغلق تلقائيًا.');});}catch(e){panels.filter(p=>core.can(section(p))).forEach(p=>{message(p,e.message,true);p.querySelectorAll('form>fieldset').forEach(f=>f.disabled=true);});}finally{pending=null;core.refresh();}})();return pending;}
 async function save(panel,path,body,source){
  if(saving||pending)return;saving=true;panel.querySelectorAll('form>fieldset').forEach(f=>f.disabled=true);message(panel,'جارٍ الحفظ…');
  try{await request(path,body);data=await request();if(source.matches('[data-notice-settings]')){settings(panel);trackers.get(source).saved();}else editWindow(panel);message(panel,'تم الحفظ.');}
  catch(e){message(panel,e.message,true);}finally{saving=false;panel.querySelectorAll('form>fieldset').forEach(f=>f.disabled=false);core.refresh();}
 }
 for(const panel of panels){
  const channel=Number(panel.dataset.noticeAdmin),form=panel.querySelector('[data-notice-settings]'),win=panel.querySelector('[data-notice-window]');win.elements.decision.dataset.adminIgnoreDirty='';
  trackers.set(form,core.trackForm(section(panel),form,{busy:()=>saving||!!pending}));trackers.set(win,core.trackForm(section(panel),win,{busy:()=>saving||!!pending}));
  panel.querySelector('[data-notice-reload]').addEventListener('click',async()=>{if(!saving&&!(core.busyIn('notices')||core.busyIn('alerts'))&&(!(core.dirtyIn('notices')||core.dirtyIn('alerts'))||await core.discard()))load();});
  form.addEventListener('submit',e=>{e.preventDefault();if(form.querySelectorAll('[name=type]:checked').length>16){message(panel,'اختر حتى 16 نوعًا من القرارات.',true);return;}void save(panel,'/'+channel,{durationDays:Number(form.elements.days.value),active:form.elements.active.checked,decisionTypes:[...form.querySelectorAll('[name=type]:checked')].map(n=>n.value)},form);});
  win.elements.decision.addEventListener('change',async()=>{if(saving){win.elements.decision.value=win.dataset.selectedDecision||'';return;}if(trackers.get(win).dirty()&&!await core.discard()){win.elements.decision.value=win.dataset.selectedDecision||'';return;}editWindow(panel);});
  const body=()=>({decisionId:win.elements.decision.value,fromAt:win.elements.from.value||null,toAt:win.elements.to.value||null,isHidden:win.elements.hidden.checked});
  win.addEventListener('submit',e=>{e.preventDefault();if(Boolean(win.elements.from.value)!==Boolean(win.elements.to.value)||(win.elements.from.value&&win.elements.to.value<=win.elements.from.value)){message(panel,'أدخل تاريخ بداية ونهاية صحيحين.',true);return;}void save(panel,'/'+channel+'/window',body(),win);});
  panel.querySelector('[data-notice-reset]').addEventListener('click',async()=>{if(saving||!win.elements.decision.value||trackers.get(win).dirty()&&!await core.discard())return;win.elements.from.value='';win.elements.to.value='';win.elements.hidden.checked=false;void save(panel,'/'+channel+'/window',body(),win);});
  panel.querySelectorAll('[data-notice-days]').forEach(b=>b.addEventListener('click',()=>{form.elements.days.value=b.dataset.noticeDays;core.refresh();}));
  panel.querySelectorAll('[data-window-days]').forEach(b=>b.addEventListener('click',()=>{const row=data?.decisions.find(r=>r.decisionId===win.elements.decision.value);if(!row)return;const start=win.elements.from.value||row.publishedAt.slice(0,19),date=new Date(start+'+04:00');date.setTime(date.getTime()+Number(b.dataset.windowDays)*86400000);win.elements.from.value=start;win.elements.to.value=new Date(date.getTime()+4*3600000).toISOString().slice(0,19);core.refresh();}));
  const draft=()=>{
   if(!data)return;const types=[...form.querySelectorAll('[name=type]:checked')].map(n=>n.value),now=Date.now(),days=Number(form.elements.days.value);
   const rows=form.elements.active.checked?data.decisions.filter(row=>{
    if(!types.includes(row.decisionType))return false;
    const w=row.decisionId===win.elements.decision.value?{fromAt:win.elements.from.value,toAt:win.elements.to.value,isHidden:win.elements.hidden.checked}:data.windows.find(w=>w.channelID===channel&&w.decisionId===row.decisionId);
    const from=new Date((w?.fromAt||row.publishedAt)+'+04:00').getTime(),to=w?.toAt?new Date(w.toAt+'+04:00').getTime():new Date(row.publishedAt+'+04:00').getTime()+days*86400000;
    return !w?.isHidden&&from<=now&&now<to;
   }):[];return {rows};
  };
  AdminPreview.button(form.querySelector('fieldset'),section(panel),draft);AdminPreview.button(win.querySelector('fieldset'),section(panel),draft);
  core.whenSection(section(panel),()=>{if(!data&&!pending&&!saving)load();});
 }
})();
