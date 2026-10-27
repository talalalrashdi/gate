(() => {
  const base = document.querySelector('meta[name="companyportal-api-base"]')?.content;
  const root = document.getElementById('admin-cards'), status = document.getElementById('admin-cards-status');
  if (!base || !root || !status) return;
  const retry = document.getElementById('admin-cards-retry');
  const create = document.getElementById('admin-card-create');
  const make = (tag,cls,text) => { const node = document.createElement(tag); if (cls) node.className = cls; if (text) node.textContent = text; return node; };
  let records = [], apps = [], busy = false, catalogAvailable = false;
  const setStatus = (text,state='ready',canRetry=false) => { core.feedback(status,text,state==='error'); status.parentElement.dataset.state=state; retry.hidden=!canRetry; };
  const core=window.AdminCore;
  const request=(path,method='GET',body)=>core.request(path,{method,body,header:'admin-cards',timeout:10000});
  const unavailable = response => response.status===401 || response.status===403 ? 'ليس لديك صلاحية إدارة البوابة.'
    : response.status===400 ? 'تحقق من الاسم والتطبيقات والأدوار والموضع. قد يلزم نقل بطاقة ثابتة قبل إخفاء بطاقة أخرى.'
    : 'تعذر الاتصال بخدمة الإدارة. تحقق من إعداد دليل التطبيقات ثم أعد المحاولة.';
  function summaries() {
    const active=records.filter(card=>card.active), fixed=active.filter(card=>card.isFixed).length;
    for (const [selector,value] of [['[data-admin-total]',active.length],['[data-admin-fixed]',fixed],['[data-admin-movable]',active.length-fixed]])
      document.querySelectorAll(selector).forEach(node=>{node.textContent=String(value);});
  }
  function refresh() {
    root.querySelectorAll('form').forEach(form=>form.dispatchEvent(new Event('admin:refresh')));
    create.disabled=busy || !catalogAvailable;
  }
  const dirty = () => [...root.querySelectorAll('.is-dirty')].length>0;
  core.watch('cards',root,()=>false,()=>busy);
  function renderCard(card,isNew=false) {
    const form=make('form','admin-card'); form.setAttribute('aria-label',isNew?'بطاقة تطبيقات جديدة':'إعدادات '+card.cardName);
    AdminChanges.tag(form,'cards','card',isNew?null:card.cardId);
    const badge=make('span','admin-card-number',isNew?'+':String(card.cardId));form.append(badge);
    const field=(caption,type,value,cls)=>{
      const label=make('label',cls),input=make('input');input.type=type;input.value=value;input.required=true;
      label.append(make('span',null,caption),input);form.append(label);return input;
    };
    const name=field('اسم البطاقة','text',card.cardName,'admin-name');name.maxLength=200;
    const order=field('الموضع الافتراضي','number',card.displayOrder,'admin-order');order.min=1;order.max=200;order.step=1;
    const fixedLabel=make('label','admin-fixed'),fixed=make('input'),line=make('span','admin-switch-line');fixed.type='checkbox';fixed.checked=card.isFixed;fixed.setAttribute('role','switch');
    line.append(fixed,make('span',null,'تثبيت الموضع'));fixedLabel.append(make('span',null,'موضع البطاقة'),line);form.append(fixedLabel);
    const save=make('button',null,isNew?'إنشاء البطاقة':'حفظ التغييرات');save.type='submit';form.append(save);
    const details=make('div','admin-card-details');
    details.append(make('span','admin-badge',card.cardType==='applications'?'بطاقة تطبيقات':'بطاقة متصلة — المحتوى محفوظ'));
    const visibilityLabel=make('label'),visibility=make('input');visibility.type='checkbox';visibility.checked=card.active;
    visibilityLabel.append(visibility,make('span',null,'إظهار في بوابة الموظفين'));details.append(visibilityLabel);
    const audienceLabel=make('label'),audience=make('select');audienceLabel.append(make('span',null,'الجمهور'));
    for (const [value,text] of [['everyone','جميع المستخدمين'],['roles','أدوار محددة']]) {const option=make('option',null,text);option.value=value;audience.append(option);}
    audience.value=card.audience;audienceLabel.append(audience);details.append(audienceLabel);
    const rolesLabel=make('label','admin-card-roles'),roles=make('textarea');roles.rows=3;roles.maxLength=10050;roles.value=card.roleNames.join('\n');
    rolesLabel.append(make('span',null,'أسماء الأدوار الدقيقة — دور واحد في كل سطر'),roles);details.append(rolesLabel);
    let appChoices=null;
    if(card.cardType==='applications') {
      const fieldset=make('fieldset','admin-card-apps');fieldset.append(make('legend',null,'التطبيقات — صلاحيات الموظف تبقى مطلوبة'));
      appChoices=make('div','admin-card-app-options');
      const selected=new Set(card.appIds),catalog=new Map(apps.map(app=>[app.appId,app]));
      card.appIds.forEach(id=>{if(!catalog.has(id))catalog.set(id,{appId:id,appName:'تطبيق غير متاح في الدليل ('+id+') — أزله قبل الحفظ'});});
      catalog.forEach(app=>{const label=make('label'),input=make('input');input.type='checkbox';input.value=String(app.appId);input.checked=selected.has(app.appId);label.append(input,make('span',null,app.appName));appChoices.append(label);});
      fieldset.append(appChoices);details.append(fieldset);
    }
    form.append(details);
    const note=make('p','admin-card-note');note.setAttribute('aria-live','polite');form.append(note);
    const values=()=>({cardName:name.value.trim(),displayOrder:Number(order.value),isFixed:fixed.checked,active:visibility.checked,audience:audience.value,
      appIds:appChoices?[...appChoices.querySelectorAll('input:checked')].map(input=>Number(input.value)).sort((a,b)=>a-b):[],
      roleNames:audience.value==='roles'?[...new Set(roles.value.split('\n').map(value=>value.trim()).filter(Boolean))].sort():[]});
    const baseline=()=>({cardName:card.cardName,displayOrder:card.displayOrder,isFixed:card.isFixed,active:card.active,audience:card.audience,
      appIds:[...card.appIds].sort((a,b)=>a-b),roleNames:[...card.roleNames].sort()});
    function sync(){
      const changed=isNew || JSON.stringify(values())!==JSON.stringify(baseline());
      form.classList.toggle('is-dirty',changed);save.disabled=busy || !changed || (card.cardType==='applications'&&!catalogAvailable);
      rolesLabel.hidden=audience.value!=='roles';
      note.textContent=changed?'تغييرات غير محفوظة':!card.active?'مخفية — الإعدادات وترتيب الموظفين محفوظة.':card.isFixed?'ثابتة؛ يُضغط موضعها عند اختلاف البطاقات المتاحة حسب الدور.':'متحركة؛ يحتفظ الموظف بترتيبه المحفوظ.';
    }
    form.addEventListener('input',sync);form.addEventListener('change',sync);form.addEventListener('admin:refresh',sync);
    if(isNew){const cancel=make('button','admin-card-cancel','إلغاء');cancel.type='button';cancel.addEventListener('click',async()=>{if(!busy&&await core.discard())form.remove();});details.append(cancel);}
    form.addEventListener('submit',async event=>{
      event.preventDefault();if(busy)return;
      const selected=values();
      if(!selected.cardName || (card.cardType==='applications'&&!selected.appIds.length) || (selected.audience==='roles'&&!selected.roleNames.length)
        ||selected.roleNames.some(role=>role.length>200)||selected.roleNames.length>50||selected.appIds.length>100){setStatus('أدخل الاسم واختر التطبيقات والأدوار المطلوبة ضمن الحدود.','error');return;}
      if(card.active&&!selected.active&&!await core.confirm('إخفاء هذه البطاقة من بوابة الموظفين؟ سيبقى ترتيبها المحفوظ.',{title:'إخفاء البطاقة',accept:'إخفاء',danger:true}))return;
      busy=true;root.querySelectorAll('button,input,select,textarea').forEach(node=>{node.disabled=true;});refresh();setStatus('جارٍ حفظ البطاقة…','loading');
      try{
        const response=await request('api/admin/cards'+(isNew?'':'/'+card.cardId),isNew?'POST':'PUT',selected);
        if(!response.ok){setStatus(unavailable(response),'error',true);return;}
        if(isNew){card.cardId=(await response.json()).cardId;records.push(card);form.replaceWith(renderCard(Object.assign(card,selected)));}
        else{Object.assign(card,selected);name.value=card.cardName;form.setAttribute('aria-label','إعدادات '+card.cardName);}
        summaries();setStatus('تم الحفظ. تظهر الإعدادات للموظفين عند إعادة تحميل البوابة؛ صلاحيات التطبيقات لا تتغير.');
      }catch{setStatus('تعذر تأكيد الحفظ. أعد تحميل الصفحة للتحقق قبل إعادة الإنشاء أو الحفظ.','error');}
      finally{busy=false;root.querySelectorAll('input,select,textarea,button').forEach(node=>{node.disabled=false;});refresh();}
    });
    sync();core.watch('cards',form,()=>form.classList.contains('is-dirty'),()=>busy);return form;
  }
  async function load(){
    setStatus('جارٍ تحميل إعدادات البطاقات…','loading');
    try{
      const response=await request('api/admin/cards');if(!response.ok){setStatus(unavailable(response),'error',true);return;}
      records=await response.json();
      const catalog=await request('api/admin/cards/applications');catalogAvailable=catalog.ok;apps=catalog.ok?await catalog.json():[];
      if(catalog.status===401||catalog.status===403){setStatus(unavailable(catalog),'error',true);return;}
      root.replaceChildren(...records.map(card=>renderCard(card)));summaries();refresh();
      setStatus(catalogAvailable?'تم التحقق من صلاحية الإدارة. الأقسام جاهزة.':'البطاقات متاحة؛ إعداد دليل التطبيقات مطلوب قبل إنشاء أو تعديل بطاقة تطبيقات.',catalogAvailable?'ready':'error',!catalogAvailable);
    }catch{setStatus('خدمة الإدارة غير متاحة حاليًا.','error',true);}
  }
  create.addEventListener('click',()=>{
    if(busy||root.querySelector('[data-new-card]'))return;
    const card={cardName:'',displayOrder:records.filter(card=>card.active).length+1,isFixed:false,active:false,audience:'everyone',cardType:'applications',appIds:[],roleNames:[]};
    const form=renderCard(card,true);form.dataset.newCard='';root.prepend(form);form.querySelector('input[type=text]').focus();
  });
  retry.addEventListener('click',async()=>{if(!busy&&(!dirty()||await core.discard('إعادة التحميل ستلغي التغييرات غير المحفوظة. متابعة؟')))load();});
  core.whenSection('cards',()=>{if(!busy&&!records.length)load();});

})();
