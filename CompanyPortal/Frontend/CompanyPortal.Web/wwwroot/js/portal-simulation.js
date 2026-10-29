(() => {
 const root=document.getElementById('portal-simulation');if(!root)return;
 const dialog=document.getElementById('portal-simulation-dialog'),status=root.querySelector('[data-simulation-status]');let sequence=0,correspondenceSequence=0,rules=[],loading;
 const panel=root.querySelector('section');
 function position(){const r=root.getBoundingClientRect();panel.style.setProperty('--simulation-left',Math.max(12,Math.min(r.left,innerWidth-Math.min(350,innerWidth*.85)-12))+'px');panel.style.setProperty('--simulation-top',(r.bottom+12)+'px');}
 const names={'media-photo':'صورة جديدة','media-video':'فيديو جديد',event:'فعالية جديدة',correspondence:'مراسلة جديدة',decision:'قرار جديد',notice:'تنويه جديد',alert:'إعلان جديد',news:'خبر جديد',breaking:'خبر عاجل'};
 const base=document.querySelector('meta[name="companyportal-api-base"]')?.content;
 function lock(value){root.querySelectorAll('[data-simulate="decision"],[data-simulate="notice"],[data-simulate="alert"]').forEach(b=>b.disabled=value);}
 async function loadRules(){if(loading)return loading;lock(true);status.textContent='جارٍ تحميل إعدادات الأنواع من البوابة…';
  loading=(async()=>{try{
   const response=await fetch(new URL('api/decisions/notice-rules',new URL(base.replace(/\/?$/,'/'),location.href)),{credentials:'include',cache:'no-store',signal:AbortSignal.timeout(15000)});
   if(!response.ok)throw new Error();const data=await response.json();if(!Array.isArray(data)||data.some(r=>![1,2].includes(r.channelId)||!Array.isArray(r.decisionTypes)||r.decisionTypes.some(t=>typeof t!=='string')||typeof r.active!=='boolean'||!Number.isInteger(r.durationDays)))throw new Error();
   rules=data;
   status.textContent='تم تحميل إعدادات الإدارة. النوع المشمول يظهر في التنويه أو التنبيه تلقائيًا.';lock(false);
  }catch{status.textContent='تعذر تحميل إعدادات الأنواع. اضغط تحديث إعدادات الأنواع للمحاولة مجددًا.';}finally{loading=null;}})();return loading;
 }
 root.addEventListener('toggle',()=>{if(root.open){position();if(!panel.matches(':popover-open'))panel.showPopover();if(!rules.length)void loadRules();}else if(panel.matches(':popover-open'))panel.hidePopover();});window.addEventListener('resize',position,{passive:true});root.querySelector('[data-simulation-rules]').addEventListener('click',()=>void loadRules());lock(true);
 root.addEventListener('click',event=>{
  const outlook=event.target.closest('[data-outlook-simulate]');
  if(outlook){document.dispatchEvent(new CustomEvent('portal:outlook-simulate',{detail:{action:outlook.dataset.outlookSimulate}}));status.textContent=outlook.dataset.outlookSimulate==='outlook-exit'?'انتهت محاكاة Outlook؛ عاد الاتصال الحقيقي.':'محاكاة Outlook محلية — دون تغيير البريد أو قاعدة البيانات.';root.open=false;return;}
  if(event.target.closest('[data-simulate="reset"]'))document.dispatchEvent(new CustomEvent('portal:outlook-simulate',{detail:{action:'outlook-exit'}}));
  if(event.target.closest('[data-simulate="reset"]'))root.querySelectorAll('[data-simulate-status]').forEach(b=>b.setAttribute('aria-pressed','false'));
  const statusButton=event.target.closest('[data-simulate-status]');
  if(statusButton){const color=statusButton.dataset.simulateStatus;root.querySelectorAll('[data-simulate-status]').forEach(b=>b.setAttribute('aria-pressed',String(b===statusButton&&color!=='real')));
   document.dispatchEvent(new CustomEvent('portal:org-status-simulation',{detail:{color}}));
   status.textContent=color==='real'?'عادت حالة المؤسسة إلى قاعدة البيانات.':'حالة المؤسسة: محاكاة «'+statusButton.textContent+'»، دون حفظ في قاعدة البيانات.';return;}
  const button=event.target.closest('[data-simulate]');if(!button)return;const kind=button.dataset.simulate;if(kind!=='reset'&&kind!=='phone'&&!Object.hasOwn(names,kind))return;
  if(kind==='phone'){
    const contacts=[
      {name:'سالم حمد السالمي',employeeTypeName:'موظف',jobDesignate:'رئيس قسم الأنظمة',attendanceStatus:'غير موجود',personalIDAssignedTo:'simulation-phone-2',assignedToFullName:'خالد سعيد البلوشي'},
      {name:'خالد سعيد البلوشي',employeeTypeName:'موظف',jobDesignate:'أخصائي أنظمة',attendanceStatus:'موجود'},
      {name:'مريم أحمد الحارثية',employeeTypeName:'متعاقد',jobDesignate:'مهندسة دعم',attendanceStatus:'موجود'},
      {name:'أحمد ناصر العامري',employeeTypeName:'موظف',jobDesignate:'أخصائي موارد بشرية',attendanceStatus:'غير موجود'},
      {name:'فاطمة علي الرواحية',employeeTypeName:'متدرب',jobDesignate:'متدربة تقنية معلومات',attendanceStatus:'موجود',noEmail:true},
      {name:'سعيد محمد العبري',employeeTypeName:'متقاعد',jobDesignate:'مستشار سابق',attendanceStatus:'غير موجود',isRetired:true,noEmail:true}
    ].map((p,i)=>({...p,personalID:'simulation-phone-'+(i+1),persID:'simulation-phone-'+(i+1),employeeTypeID:'1',isSimulation:true,
      officePhoneNumber:i===5?null:String(1312+i),employeeSectionName:i===3?'الموارد البشرية':'تقنية المعلومات',
      simulationEmail:p.noEmail?null:'sample'+(i+1)+'@email.com',
      moreInfo:{phoneNumbers:i===5?[]:[{number:String(1312+i),phoneTypeName:'محول',phonePlace:'المكتب',phoneStateName:'مسقط',note:'رقم محاكاة فقط'},{number:'24XX '+(1100+i),phoneTypeName:'هاتف',phonePlace:'الاستقبال'}],contactAddress:i===5?{}:{currentAddress:'السيب',permanentAddress:'مسقط'}}}));
    root.open=false;
    document.dispatchEvent(new CustomEvent('portal:phone-simulation',{detail:contacts}));
    return;
  }
  if(kind==='reset')correspondenceSequence=0;
  let decisionType=rules.filter(r=>r.active).flatMap(r=>r.decisionTypes)[0]||'تعميم';
  if(kind==='notice'||kind==='alert'){const channel=kind==='notice'?1:2,rule=rules.find(r=>r.channelId===channel),preferred=channel===1?'تنويه':'إعلان';decisionType=rule?.decisionTypes.includes(preferred)?preferred:rule?.decisionTypes[0]||decisionType;}
  const notices=rules.filter(r=>r.active&&r.decisionTypes.includes(decisionType)).map(r=>({channelId:r.channelId,fromAt:new Date(Date.now()-1000).toISOString(),toAt:new Date(Date.now()+r.durationDays*86400000).toISOString()}));
  const id=++sequence,title=names[kind]?'[محاكاة] '+names[kind]+' '+id:'';
  const correspondencePurpose=kind==='correspondence'&&correspondenceSequence++%2?'للإجراء':'للعلم';
  const correspondenceSender=correspondencePurpose==='للعلم'?'سالم العبري':'مريم الحارثية';
  document.dispatchEvent(new CustomEvent('portal:simulate',{detail:{kind,id,title,decisionType,notices,correspondencePurpose,correspondenceSender}}));
  status.textContent=kind==='reset'?'تم مسح المواد المحلية. لم تتغير بيانات قاعدة البيانات.':'تمت محاكاة '+names[kind]+(['decision','notice','alert'].includes(kind)?' من نوع '+decisionType+(notices.length?'؛ ظهر بحسب إعدادات الإدارة.':'؛ غير مشمول حاليًا في قنوات الإدارة.'):'.');
 });
 document.addEventListener('portal:simulation-open',event=>{dialog.querySelector('h2').textContent=event.detail.title;dialog.querySelector('p').textContent=event.detail.text;if(!dialog.open)dialog.showModal();});
 dialog.querySelector('[data-simulation-dialog-close]').addEventListener('click',()=>dialog.close());
 document.addEventListener('pointerdown',event=>{if(root.open&&!root.contains(event.target))root.open=false;});
 root.addEventListener('keydown',event=>{if(event.key==='Escape'){event.stopPropagation();root.open=false;root.querySelector('summary').focus();}});
})();
