(() => {
 const panels=[...document.querySelectorAll('[data-notice-admin]')],base=document.querySelector('meta[name="companyportal-api-base"]')?.content;if(!base||!panels.length)return;
 const url=path=>new URL('api/admin/decision-notices'+path,new URL(base.replace(/\/?$/,'/'),location.href));
 let data,pending;
 async function request(path='',body){const response=await fetch(url(path),{method:body?'PUT':'GET',credentials:'include',cache:'no-store',headers:body?{'Content-Type':'application/json','X-CompanyPortal-Request':'decision-notices'}:{},body:body?JSON.stringify(body):undefined,signal:AbortSignal.timeout(15000)});if(!response.ok)throw new Error(response.status===403?'هذه الصفحة للمسؤولين فقط.':'تعذر حفظ أو تحميل الإعدادات. تحقق من القيم والاتصال.');return response.status===204?null:response.json();}
 const option=(value,text)=>{const n=document.createElement('option');n.value=value;n.textContent=text;return n;};
 function populate(panel){
  const channel=Number(panel.dataset.noticeAdmin),setting=data.settings.find(s=>s.channelID===channel),form=panel.querySelector('[data-notice-settings]'),win=panel.querySelector('[data-notice-window]');
  form.elements.days.value=setting.durationDays;form.elements.active.checked=setting.active;const types=panel.querySelector('[data-notice-types]');types.replaceChildren();
  for(const type of data.types){const label=document.createElement('label'),input=document.createElement('input');input.type='checkbox';input.name='type';input.value=type;input.checked=setting.decisionTypes.includes(type);label.append(input,document.createTextNode(type));types.append(label);}
  const selected=win.elements.decision.value;win.elements.decision.replaceChildren(option('','اختر قرارًا'),...data.decisions.map(r=>option(r.decisionId,r.decisionType+' — '+r.title)));win.elements.decision.value=selected;
  panel.querySelectorAll('form>fieldset').forEach(f=>f.disabled=false);editWindow(panel);
 }
 function editWindow(panel){const form=panel.querySelector('[data-notice-window]'),id=form.elements.decision.value,channel=Number(panel.dataset.noticeAdmin),w=data.windows.find(w=>w.channelID===channel&&w.decisionId===id),row=data.decisions.find(r=>r.decisionId===id),setting=data.settings.find(s=>s.channelID===channel);
  form.elements.from.value=w?.fromAt?.slice(0,19)||'';form.elements.to.value=w?.toAt?.slice(0,19)||'';form.elements.hidden.checked=w?.isHidden||false;
  panel.querySelector('[data-notice-preview]').textContent=row?('نُشر في '+row.publishedAt.replace('T',' ')+' · '+(setting.decisionTypes.includes(row.decisionType)?'نوع مشمول؛ المدة العامة '+setting.durationDays+' أيام':'النوع غير مشمول في إعدادات هذا القسم')):'';
 }
 async function load(){if(pending)return pending;pending=(async()=>{try{data=await request();panels.forEach(p=>{populate(p);p.querySelector('[data-notice-message]').textContent='تم تحميل الإعدادات. القراءة لا تخفي المادة قبل انتهاء المدة.';});}catch(e){panels.forEach(p=>{p.querySelector('[data-notice-message]').textContent=e.message;p.querySelectorAll('form>fieldset').forEach(f=>f.disabled=true);});}finally{pending=null;}})();return pending;}
 async function save(panel,path,body){const message=panel.querySelector('[data-notice-message]');panel.querySelectorAll('form>fieldset').forEach(f=>f.disabled=true);message.textContent='جارٍ الحفظ…';try{await request(path,body);data=await request();panels.forEach(populate);message.textContent='تم الحفظ.';}catch(e){message.textContent=e.message;}finally{panel.querySelectorAll('form>fieldset').forEach(f=>f.disabled=false);}}
 for(const panel of panels){const channel=Number(panel.dataset.noticeAdmin),form=panel.querySelector('[data-notice-settings]'),win=panel.querySelector('[data-notice-window]');
  panel.querySelector('[data-notice-reload]').addEventListener('click',load);
  form.addEventListener('submit',e=>{e.preventDefault();void save(panel,'/'+channel,{durationDays:Number(form.elements.days.value),active:form.elements.active.checked,decisionTypes:[...form.querySelectorAll('[name=type]:checked')].map(n=>n.value)});});
  win.elements.decision.addEventListener('change',()=>editWindow(panel));
  function body(){return {decisionId:win.elements.decision.value,fromAt:win.elements.from.value||null,toAt:win.elements.to.value||null,isHidden:win.elements.hidden.checked};}
  win.addEventListener('submit',e=>{e.preventDefault();if(Boolean(win.elements.from.value)!==Boolean(win.elements.to.value)||(win.elements.from.value&&win.elements.to.value<=win.elements.from.value)){panel.querySelector('[data-notice-message]').textContent='أدخل تاريخ بداية ونهاية صحيحين.';return;}void save(panel,'/'+channel+'/window',body());});
  panel.querySelector('[data-notice-reset]').addEventListener('click',()=>{if(!win.elements.decision.value)return;win.elements.from.value='';win.elements.to.value='';win.elements.hidden.checked=false;void save(panel,'/'+channel+'/window',body());});
  panel.querySelectorAll('[data-notice-days]').forEach(b=>b.addEventListener('click',()=>form.elements.days.value=b.dataset.noticeDays));
  panel.querySelectorAll('[data-window-days]').forEach(b=>b.addEventListener('click',()=>{const row=data?.decisions.find(r=>r.decisionId===win.elements.decision.value);if(!row)return;const start=win.elements.from.value||row.publishedAt.slice(0,19),date=new Date(start+'+04:00');date.setTime(date.getTime()+Number(b.dataset.windowDays)*86400000);win.elements.from.value=start;win.elements.to.value=new Date(date.getTime()+4*3600000).toISOString().slice(0,19);}));
 }
 // Lazy-load both panels in one request, only after admin access enables the navigation.
 const observer=new MutationObserver(()=>{if(panels.some(p=>!p.hidden)&&!data)void load();});panels.forEach(p=>observer.observe(p,{attributes:true,attributeFilter:['hidden']}));if(panels.some(p=>!p.hidden))void load();
})();
