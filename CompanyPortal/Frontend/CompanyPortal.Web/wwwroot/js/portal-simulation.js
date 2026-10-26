(() => {
 const root=document.getElementById('portal-simulation');if(!root)return;
 const dialog=document.getElementById('portal-simulation-dialog'),status=root.querySelector('[data-simulation-status]'),select=root.querySelector('[data-simulation-decision-type]');let sequence=0,rules=[],loading;
 const panel=root.querySelector('section');
 function position(){const r=root.getBoundingClientRect();panel.style.setProperty('--simulation-left',Math.max(12,Math.min(r.left,innerWidth-Math.min(350,innerWidth*.85)-12))+'px');panel.style.setProperty('--simulation-top',(r.bottom+12)+'px');}
 const names={decision:'قرار جديد',notice:'تنويه جديد',alert:'إعلان جديد',news:'خبر جديد',breaking:'خبر عاجل'};
 const base=document.querySelector('meta[name="companyportal-api-base"]')?.content;
 function lock(value){root.querySelectorAll('[data-simulate="decision"],[data-simulate="notice"],[data-simulate="alert"]').forEach(b=>b.disabled=value);}
 async function loadRules(){if(loading)return loading;lock(true);status.textContent='جارٍ تحميل إعدادات الأنواع من البوابة…';
  loading=(async()=>{try{
   const response=await fetch(new URL('api/decisions/notice-rules',new URL(base.replace(/\/?$/,'/'),location.href)),{credentials:'include',cache:'no-store',signal:AbortSignal.timeout(15000)});
   if(!response.ok)throw new Error();const data=await response.json();if(!Array.isArray(data)||data.some(r=>![1,2].includes(r.channelId)||!Array.isArray(r.decisionTypes)||r.decisionTypes.some(t=>typeof t!=='string')||typeof r.active!=='boolean'||!Number.isInteger(r.durationDays)))throw new Error();
   rules=data;const selected=select.value;select.replaceChildren();
   for(const type of new Set(['تعميم',...rules.flatMap(r=>r.decisionTypes)])){const option=document.createElement('option');option.value=option.textContent=type;select.append(option);}if([...select.options].some(o=>o.value===selected))select.value=selected;
   status.textContent='تم تحميل إعدادات الإدارة. النوع المشمول يظهر في التنويه أو التنبيه تلقائيًا.';lock(false);
  }catch{status.textContent='تعذر تحميل إعدادات الأنواع. اضغط تحديث إعدادات الأنواع للمحاولة مجددًا.';}finally{loading=null;}})();return loading;
 }
 root.addEventListener('toggle',()=>{if(root.open){position();if(!panel.matches(':popover-open'))panel.showPopover();if(!rules.length)void loadRules();}else if(panel.matches(':popover-open'))panel.hidePopover();});window.addEventListener('resize',position,{passive:true});root.querySelector('[data-simulation-rules]').addEventListener('click',()=>void loadRules());lock(true);
 root.addEventListener('click',event=>{
  const button=event.target.closest('[data-simulate]');if(!button)return;const kind=button.dataset.simulate;if(kind!=='reset'&&!Object.hasOwn(names,kind))return;
  let decisionType=select.value;
  if(kind==='notice'||kind==='alert'){const channel=kind==='notice'?1:2,rule=rules.find(r=>r.channelId===channel),preferred=channel===1?'تنويه':'إعلان';decisionType=rule?.decisionTypes.includes(preferred)?preferred:rule?.decisionTypes[0]||decisionType;}
  const notices=rules.filter(r=>r.active&&r.decisionTypes.includes(decisionType)).map(r=>({channelId:r.channelId,fromAt:new Date(Date.now()-1000).toISOString(),toAt:new Date(Date.now()+r.durationDays*86400000).toISOString()}));
  const title='[محاكاة] '+(root.querySelector('[data-simulation-title]').value.trim()||names[kind]||'');
  document.dispatchEvent(new CustomEvent('portal:simulate',{detail:{kind,id:++sequence,title,decisionType,notices}}));
  status.textContent=kind==='reset'?'تم مسح المواد المحلية. لم تتغير بيانات قاعدة البيانات.':'تمت محاكاة '+names[kind]+(['decision','notice','alert'].includes(kind)?' من نوع '+decisionType+(notices.length?'؛ ظهر بحسب إعدادات الإدارة.':'؛ غير مشمول حاليًا في قنوات الإدارة.'):'.');
 });
 document.addEventListener('portal:simulation-open',event=>{dialog.querySelector('h2').textContent=event.detail.title;dialog.querySelector('p').textContent=event.detail.text;if(!dialog.open)dialog.showModal();});
 dialog.querySelector('[data-simulation-dialog-close]').addEventListener('click',()=>dialog.close());
 document.addEventListener('pointerdown',event=>{if(root.open&&!root.contains(event.target))root.open=false;});
 root.addEventListener('keydown',event=>{if(event.key==='Escape'){event.stopPropagation();root.open=false;root.querySelector('summary').focus();}});
})();
