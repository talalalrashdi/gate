(() => {
  const panels = [...document.querySelectorAll('[data-admin-panel]')];
  let buttons = [...document.querySelectorAll('[data-admin-section]')];
  const titles = {
    overview:['نظرة عامة','إدارة محتوى البوابة ومظهرها من مكان واحد.'],
    history:['سجل التعديلات','جميع تعديلات الإدارة؛ للمدير العام فقط، مع مقارنة قبل وبعد دون تراجع.'],
    cards:['إدارة البطاقات الأساسية','أدر بطاقات التطبيقات والجمهور والإظهار والترتيب والمواضع الثابتة.'],
    applications:['الأنظمة الإلكترونية','أدر تصنيفات التطبيقات وأوصافها؛ الصلاحيات وروابط التشغيل تبقى في قاعدة الأمن.'],
    documents:['وثائق تهمك','اختر مجلدًا وملفات PDF مسجلة، ورتّب التبويبات وحدّد إظهارها.'],
    safety:['تعليمات السلامة','اختر ملفات PDF للكتيبات وحدّد أسماءها وترتيبها وإظهارها.'],
    'fixed-orders':['التوجيهات السامية','أضف التوجيهات وحدّد التاريخ والنصوص مع معاينة تنسيقها قبل الحفظ.'],
    'header-content':['أرقام تهمك وحالة المؤسسة','أدر أرقام نافذة دليل الهاتف، ونصوص كل لون في حالة المؤسسة.'],
    notices:['إدارة التنويهات','اختر أنواع القرارات وفترة العرض وحدّد الاستثناءات.'],
    alerts:['إدارة التنبيهات','اختر أنواع القرارات وفترة العرض وحدّد الاستثناءات.'],
    media:['أخبارنا','أدر الفيديوهات والصور وألبوماتها، وتحقق من الملفات قبل نشرها للجميع.'],
    images:['صور الواجهة',''],
    themes:['الثيمات والمظهر','']
  };
  const features=document.querySelector('.admin-feature-grid');
  for(const [key,[title,description]] of Object.entries(titles)){
    if(key==='overview'||features.querySelector('[data-admin-section="'+key+'"]'))continue;
    const button=document.createElement('button');button.type='button';button.className='admin-feature';button.dataset.adminSection=key;button.hidden=true;button.disabled=true;
    const top=document.createElement('span'),icon=document.createElement('span'),badge=document.createElement('span');top.className='admin-feature-top';icon.className='admin-feature-icon';icon.setAttribute('aria-hidden','true');const source=document.querySelector('.admin-nav [data-admin-section="'+key+'"] > :first-child');if(source){const image=source.cloneNode(true);if(image.tagName.toLowerCase()==='svg'){image.setAttribute('width','24');image.setAttribute('height','24');}icon.append(image);}badge.className='admin-badge is-ready';badge.textContent='متاح الآن';top.append(icon,badge);
    const name=document.createElement('strong'),copy=document.createElement('span'),action=document.createElement('span');name.textContent=title;copy.textContent=description;action.className='admin-feature-action';action.append(document.createTextNode('استعراض القسم '));const arrow=document.createElement('i');arrow.className='iconsax';arrow.setAttribute('icon-name','arrow-left');arrow.setAttribute('aria-hidden','true');action.append(arrow);button.append(top,name,copy,action);features.append(button);
  }
  buttons=[...document.querySelectorAll('[data-admin-section]')];
  const core=window.AdminCore;let current='overview',url=location.href,position=0,reverting=false,navigating=false;
  history.replaceState({...history.state,adminPosition:0},'',location.href);
  panels.forEach(p=>p.hidden=true);
  function show(key,focus=false){
    if(!Object.hasOwn(titles,key)||!core.can(key))key='overview';
    current=key;document.body.dataset.adminCurrent=key;
    buttons.forEach(b=>{const allowed=core.can(b.dataset.adminSection);b.hidden=!allowed;b.disabled=!allowed;});
    document.querySelectorAll('[data-admin-group]').forEach(g=>{g.hidden=![...g.querySelectorAll('[data-admin-section]')].some(b=>core.can(b.dataset.adminSection));});
    panels.forEach(p=>p.hidden=p.dataset.adminPanel!==key||!core.can(key));
    buttons.filter(b=>b.closest('.admin-nav')).forEach(b=>{if(b.dataset.adminSection===key)b.setAttribute('aria-current','page');else b.removeAttribute('aria-current');});
    const heading=document.getElementById('admin-page-title');heading.textContent=titles[key][0];const description=document.getElementById('admin-page-description');description.textContent=titles[key][1];description.hidden=!titles[key][1];
    if(focus){heading.tabIndex=-1;heading.focus({preventScroll:true});window.scrollTo({top:0,behavior:'instant'});}
    document.dispatchEvent(new CustomEvent('admin:section',{detail:{section:key}}));core.refresh();
  }
  document.addEventListener('click',async e=>{
    const button=e.target.closest('[data-admin-section]');if(!button)return;e.preventDefault();e.stopImmediatePropagation();
    const key=button.dataset.adminSection;if(navigating||button.disabled||!core.can(key))return;
    navigating=true;try{if(key!==current&&!await core.mayLeave(current))return;const next=new URL(location.href);next.hash=key;if(key!==current){position++;history.pushState({adminPosition:position},'',next);}url=location.href;show(key,true);}finally{navigating=false;}
  },true);
  window.addEventListener('popstate',async e=>{
    if(reverting){reverting=false;return;}const target=e.state?.adminPosition;
    if(navigating)return;navigating=true;
    try{if(!await core.mayLeave(current)){if(Number.isInteger(target)&&target!==position){reverting=true;history.go(position-target);}else history.replaceState({adminPosition:position},'',url);return;}
      position=Number.isInteger(target)?target:position;url=location.href;show(location.hash.slice(1),true);
    }finally{navigating=false;}
  });
  document.addEventListener('admin:access',()=>{const wanted=location.hash.slice(1)||document.body.dataset.adminStart||'overview';show(core.can(current)&&document.body.dataset.adminCurrent?current:wanted);});
  if(core.can('overview'))show(location.hash.slice(1)||document.body.dataset.adminStart);
})();
