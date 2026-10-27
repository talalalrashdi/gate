(() => {
  const panel=document.querySelector('[data-admin-panel="themes"]'),base=document.querySelector('meta[name="companyportal-api-base"]')?.content;
  if(!panel||!base)return;
  const api=new URL(base.replace(/\/?$/,'/'),location.href),get=id=>document.getElementById(id),status=get('themes-status'),gallery=get('theme-gallery'),editor=get('theme-editor'),form=get('theme-form'),frame=get('theme-preview-frame'),dialog=get('theme-preview-dialog'),galleryFrame=get('theme-gallery-preview');
  let themes=[],templates=[],library={groups:[],items:[],images:[]},draft=null,id=null,snapshot='',busy=false,loaded=false,previewRecord=null;
  const core=window.AdminCore,ready=new Set(),say=(text,error=false)=>{core.feedback(status,text,error);};
  const node=(tag,text,css)=>{const n=document.createElement(tag);if(text!==undefined)n.textContent=text;if(css)n.className=css;return n;};
  const option=(value,text)=>{const n=node('option',text);n.value=String(value??'');return n;};
  const template=key=>templates.find(t=>t.layoutKey===key)||templates[0];
  const serial=()=>JSON.stringify(draft);
  const dirty=()=>draft&&serial()!==snapshot;
  async function request(path,method='GET',body){
    const response=await core.request(path,{method,body,header:'admin-themes'});
    if(!response.ok){
      if(response.status===401||response.status===403){editor.hidden=true;gallery.replaceChildren();loaded=false;get('theme-add').disabled=true;throw new Error('ليس لديك صلاحية إدارة الثيمات.');}
      throw new Error(response.status===400?'تحقق من حالة النشر والأدوار والمجموعة النشطة. اختر ثيمًا افتراضيًا مباشرًا آخر قبل إخفاء أو حذف الافتراضي الحالي.':'تعذر تحميل أو حفظ الثيمات. أعد المحاولة.');
    }
    return response.status===204?null:response.json();
  }
  function groupData(theme){
    const group=library.groups.find(g=>g.imageGroupId===theme.imageGroupId&&g.active);
    const ids=group?library.items.filter(i=>i.imageGroupId===group.imageGroupId&&i.active).sort((a,b)=>a.displayOrder-b.displayOrder).filter(i=>library.images.some(image=>image.imageId===i.imageId)):[];
    return {settings:group?{rotateImages:group.rotateImages,rotationSeconds:group.rotationSeconds,defaultImageId:group.defaultImageId}:null,images:ids.map(i=>({imageId:i.imageId}))};
  }
  function send(target,theme){if(ready.has(target)&&theme)target.contentWindow.postMessage({type:'companyportal:theme-preview',theme,...groupData(theme)},location.origin);}
  window.addEventListener('message',event=>{
    if(event.origin!==location.origin||event.data?.type!=='companyportal:preview-ready')return;
    const target=[frame,galleryFrame].find(f=>event.source===f.contentWindow);if(!target)return;
    ready.add(target);send(target,target===frame?draft:previewRecord);
  });
  // Scale the current desktop viewport; do not trigger a different header breakpoint.
  function fit(){
    const width=document.documentElement.clientWidth,height=window.innerHeight;
    for(const [target,visible,padding] of [[frame,!editor.hidden,20],[galleryFrame,dialog.open,0]]){
      if(!visible)continue;
      const container=target.parentElement,available=container.clientWidth-padding;
      if(available<=0)continue;
      const scale=Math.min(1,available/width);
      target.style.width=width+'px';target.style.height=height+'px';target.style.transform=`scale(${scale})`;target.style.transformOrigin='top left';
      container.style.height=(height*scale+padding)+'px';
    }
  }
  const previewObserver=new ResizeObserver(fit);
  previewObserver.observe(frame.parentElement);previewObserver.observe(galleryFrame.parentElement);
  window.addEventListener('resize',fit);
  function changed(){
    get('theme-dirty').textContent=dirty()?'تغييرات غير محفوظة':id?'كل التغييرات محفوظة':'لم يُحفظ بعد';
    get('theme-save').disabled=busy||!dirty();
    get('theme-overlay-value').textContent=draft.overlayOpacity===null?'إعداد القالب':draft.overlayOpacity+'%';
    const group=library.groups.find(g=>g.imageGroupId===draft.imageGroupId),members=groupData(draft).images.length;
    get('theme-group-summary').textContent=group?`${group.groupName} · ${members} صورة نشطة · ${group.rotateImages?'تدوير كل '+group.rotationSeconds+' ثوانٍ':'صورة ثابتة'}${group.active?'':' · المجموعة غير نشطة؛ اختر مجموعة نشطة للحفظ.'}`:'ستظهر الصور الأصلية لقالب التصميم.';
    const bg=draft.backgroundColor||template(draft.layoutKey).backgroundColor,primary=draft.primaryColor||template(draft.layoutKey).primaryColor;
    get('theme-colour-advice').textContent=bg.toLowerCase()===primary.toLowerCase()?'اللون الرئيسي والخلفية متطابقان. راجع تباين العناوين في المعاينة.':'راجع وضوح النصوص والأزرار في المعاينة.';
    get('theme-roles-field').hidden=draft.visibility!=='preview';
    get('theme-publication-note').textContent=visibilityName[draft.visibility]+(draft.visibility==='public'?' — بعد الحفظ يظهر في قائمة الثيمات لدى الجميع.':draft.visibility==='preview'?' — يظهر فقط لمن يحمل أحد الأدوار المحددة.':' — لا يظهر في قائمة الثيمات لدى الموظفين.');
    get('theme-save').textContent=draft.visibility==='public'?'حفظ ونشر للجميع':draft.visibility==='preview'?'حفظ وإتاحة للأدوار المحددة':'حفظ كمخفي';
    send(frame,draft);
  }
  const visibilityName={hidden:'مخفي — للإدارة فقط',preview:'معاينة لأدوار محددة',public:'مباشر — لجميع المستخدمين'};
  const confirmAction=(title,message)=>core.confirm(message,{title,accept:title.startsWith('حذف')?'حذف':title.startsWith('إخفاء')?'إخفاء':'تأكيد',danger:/حذف|إخفاء|تطبيق|استبدال/.test(title)});
  const savedPayload=theme=>Object.fromEntries(['themeName','layoutKey','displayOrder','active','isDefault','primaryColor','accentColor','backgroundColor','overlayOpacity','foregroundPreset','imagePresentation','imageGroupId','visibility','previewRoles'].map(key=>[key,theme[key]]));
  async function catalogAction(theme,action){
    if(busy)return;
    if(dirty()){say('احفظ تغييرات المحرر أو ألغها أولًا.',true);return;}
    const messages={delete:['حذف الثيم','حذف «'+theme.themeName+'»؟ سيعود مستخدموه إلى الافتراضي عند تحميل البوابة.'],hide:['إخفاء الثيم','إخفاء «'+theme.themeName+'» عن جميع المستخدمين؟ سيبقى متاحًا للإدارة.'],publish:['النشر المباشر للجميع','نشر «'+theme.themeName+'» ليتمكن جميع المستخدمين من اختياره؟ لن يستبدل اختياراتهم الحالية.'],apply:['تعيين الافتراضي وتطبيقه على الجميع','سيُعيّن «'+theme.themeName+'» افتراضيًا ويستبدل اختيارات جميع المستخدمين عند فتح البوابة أو إعادة تحميلها. هل تريد المتابعة؟']};
    if(!await confirmAction(...messages[action]))return;
    busy=true;gallery.querySelectorAll('button').forEach(button=>{button.disabled=true;});
    try{
      if(action==='delete')await request(`api/admin/themes/${theme.themeId}`,'DELETE');
      else if(action==='apply')await request(`api/admin/themes/${theme.themeId}/apply-to-all`,'POST');
      else await request(`api/admin/themes/${theme.themeId}`,'PUT',{...savedPayload(theme),active:action==='publish',visibility:action==='publish'?'public':'hidden'});
      themes=await request('api/admin/themes');
      if(id===theme.themeId){draft=null;id=null;snapshot='';editor.hidden=true;frame.src='about:blank';ready.delete(frame);}
      renderGallery();say(action==='apply'?'تم تعيين الافتراضي وتطبيقه على الجميع. يظهر عند تحميل البوابة.':action==='publish'?'الثيم مباشر ومتاح الآن لجميع المستخدمين.':action==='delete'?'تم حذف الثيم.':'تم إخفاء الثيم عن المستخدمين.');
    }catch(error){say(error.message,true);}finally{busy=false;renderGallery();}
  }
  function cover(theme){const data=groupData(theme),first=data.images.find(i=>i.imageId===data.settings?.defaultImageId)||data.images[0];return first?new URL(`api/images/${first.imageId}/content`,api).href:new URL(template(theme.layoutKey).thumbnail,document.baseURI).href;}
  function renderGallery(){
    gallery.replaceChildren();themes.forEach(theme=>{
      const card=node('article',undefined,'theme-card'),coverBox=node('div',undefined,'theme-card-cover'),image=node('img');image.src=cover(theme);image.alt='';image.loading='lazy';coverBox.append(image);
      const body=node('div',undefined,'theme-card-body'),badges=node('div',undefined,'theme-card-badges');
      badges.append(node('span',visibilityName[theme.visibility]||'مخفي','admin-badge'+(theme.active?' is-ready':'')));if(theme.isDefault)badges.append(node('span','افتراضي للجميع','admin-badge is-ready'));
      const swatches=node('div',undefined,'theme-swatches');for(const key of ['primaryColor','accentColor','backgroundColor']){const dot=node('i');dot.style.backgroundColor=theme[key]||template(theme.layoutKey)[key];swatches.append(dot);}
      const actions=node('div',undefined,'theme-card-actions');
      for(const [text,action] of [['تعديل',()=>open(theme,false)],['نسخ',()=>open(theme,true)],['معاينة',()=>preview(theme)]]){const button=node('button',text);button.type='button';button.setAttribute('aria-label',text+' '+theme.themeName);button.addEventListener('click',action);actions.append(button);}
      for(const [text,action,disabled] of [['إخفاء','hide',theme.isDefault||theme.visibility==='hidden'],['نشر للجميع','publish',theme.visibility==='public'],['افتراضي وتطبيق للجميع','apply',theme.visibility!=='public'||!theme.active],['حذف','delete',theme.isDefault]]){
        const button=node('button',text);button.type='button';button.disabled=disabled;button.setAttribute('aria-label',text+' '+theme.themeName);
        if(disabled&&theme.isDefault&&['hide','delete'].includes(action))button.title='عيّن ثيمًا آخر افتراضيًا أولًا';
        button.addEventListener('click',()=>catalogAction(theme,action));actions.append(button);
      }
      body.append(badges,node('h3',theme.themeName),node('p','قالب '+template(theme.layoutKey).templateName+' · ترتيب '+theme.displayOrder),swatches,actions);card.append(coverBox,body);gallery.append(card);
    });
  }
  function preview(theme){previewRecord=theme;dialog.showModal();fit();if(galleryFrame.src==='about:blank'){galleryFrame.src=frame.dataset.previewUrl;ready.delete(galleryFrame);}else send(galleryFrame,theme);}
  get('theme-preview-close').addEventListener('click',()=>{dialog.close();galleryFrame.src='about:blank';ready.delete(galleryFrame);previewRecord=null;});
  dialog.addEventListener('close',()=>{galleryFrame.src='about:blank';ready.delete(galleryFrame);});
  function showTab(key,focus=false){
    document.querySelectorAll('[data-theme-tab]').forEach(button=>{const selected=button.dataset.themeTab===key;button.setAttribute('aria-selected',String(selected));button.tabIndex=selected?0:-1;get('theme-'+button.dataset.themeTab).hidden=!selected;if(selected&&focus)button.focus();});
  }
  document.querySelectorAll('[data-theme-tab]').forEach((button,index,list)=>{button.addEventListener('click',()=>showTab(button.dataset.themeTab));button.addEventListener('keydown',event=>{if(!['ArrowLeft','ArrowRight','Home','End'].includes(event.key))return;event.preventDefault();const target=event.key==='Home'?0:event.key==='End'?list.length-1:(index+(event.key==='ArrowLeft'?1:-1)+list.length)%list.length;showTab(list[target].dataset.themeTab,true);});});
  function colourFields(){
    const target=get('theme-colour-fields');target.replaceChildren();
    for(const [key,caption] of [['primaryColor','اللون الرئيسي'],['accentColor','لون التمييز'],['backgroundColor','لون الخلفية']]){
      const box=node('div',undefined,'theme-colour-field'),label=node('label',caption),controls=node('div',undefined,'theme-colour-controls'),picker=node('input'),hex=node('input'),reset=node('button','استعادة لون القالب','theme-text-button');
      picker.type='color';picker.value=draft[key]||template(draft.layoutKey)[key];picker.setAttribute('aria-label',caption+' — اختيار اللون');hex.type='text';hex.maxLength=7;hex.pattern='#[0-9a-fA-F]{6}';hex.placeholder=template(draft.layoutKey)[key];hex.value=draft[key]||'';hex.setAttribute('aria-label',caption+' — القيمة');label.htmlFor='theme-colour-'+key;hex.id=label.htmlFor;reset.type='button';
      picker.addEventListener('input',()=>{hex.value=picker.value;draft[key]=picker.value.toUpperCase();changed();});hex.addEventListener('input',()=>{draft[key]=hex.value?hex.value.toUpperCase():null;if(/^#[\da-f]{6}$/i.test(hex.value))picker.value=hex.value;changed();});reset.addEventListener('click',()=>{draft[key]=null;hex.value='';picker.value=template(draft.layoutKey)[key];changed();});controls.append(picker,hex,reset);box.append(label,controls);target.append(box);
    }
  }
  async function open(record,copy){
    if(busy)return;
    if(dirty()&&!await core.discard())return;
    id=record&&!copy?record.themeId:null;
    draft={themeName:record?(copy?'نسخة من '+record.themeName:record.themeName):'',layoutKey:record?.layoutKey||'official',displayOrder:record&&!copy?record.displayOrder:Math.min(1000000,Math.max(0,...themes.map(t=>t.displayOrder))+1),visibility:record&&!copy?record.visibility:'hidden',previewRoles:[...(record?.previewRoles||[])],active:record&&!copy?record.active:false,isDefault:record&&!copy?record.isDefault:false,primaryColor:record?.primaryColor??null,accentColor:record?.accentColor??null,backgroundColor:record?.backgroundColor??null,overlayOpacity:record?.overlayOpacity??null,foregroundPreset:record?.foregroundPreset??null,imagePresentation:record?.imagePresentation||'background',imageGroupId:record?.imageGroupId??null};
    draft.themeName=draft.themeName.slice(0,200);snapshot=id?serial():'';
    editor.hidden=false;get('theme-editor-title').textContent=id?'تعديل '+draft.themeName:copy?'نسخ الثيم':'ثيم جديد';
    get('theme-name').value=draft.themeName;get('theme-order').value=draft.displayOrder;get('theme-visibility').value=draft.visibility;get('theme-preview-roles').value=draft.previewRoles.join('\n');get('theme-default').checked=draft.isDefault;get('theme-default').disabled=!!record?.isDefault&&!copy;
    const choices=get('theme-templates');choices.replaceChildren();templates.forEach(t=>{const label=node('label',undefined,'theme-template-option'),image=node('img'),line=node('span'),radio=node('input');image.src=new URL(t.thumbnail,document.baseURI);image.alt='';radio.type='radio';radio.name='theme-layout';radio.value=t.layoutKey;radio.checked=draft.layoutKey===t.layoutKey;radio.addEventListener('change',()=>{draft.layoutKey=t.layoutKey;colourFields();get('theme-overlay').value=draft.overlayOpacity??t.overlayOpacity;changed();});line.append(radio,node('span',t.templateName));label.append(image,line);choices.append(label);});
    const groups=get('theme-image-group');groups.replaceChildren(option('','الصور الأصلية للقالب'));library.groups.filter(g=>g.active||g.imageGroupId===draft.imageGroupId).forEach(g=>groups.append(option(g.imageGroupId,g.groupName+(g.active?'':' (غير نشطة)'))));groups.value=String(draft.imageGroupId??'');
    document.querySelectorAll('[name="theme-presentation"]').forEach(radio=>{radio.checked=radio.value===draft.imagePresentation;});get('theme-foreground').value=draft.foregroundPreset||'';get('theme-overlay').value=draft.overlayOpacity??template(draft.layoutKey).overlayOpacity;colourFields();showTab('details');changed();
    if(frame.src==='about:blank'){ready.delete(frame);frame.src=frame.dataset.previewUrl;}requestAnimationFrame(fit);editor.scrollIntoView({behavior:'smooth',block:'start'});get('theme-name').focus({preventScroll:true});
  }
  get('theme-add').addEventListener('click',()=>open(null,false));
  get('theme-name').addEventListener('input',()=>{draft.themeName=get('theme-name').value;changed();});get('theme-order').addEventListener('input',()=>{draft.displayOrder=Number(get('theme-order').value);changed();});
  get('theme-visibility').addEventListener('change',()=>{draft.visibility=get('theme-visibility').value;draft.active=draft.visibility!=='hidden';changed();});
  get('theme-preview-roles').addEventListener('input',()=>{draft.previewRoles=get('theme-preview-roles').value.split(/\r?\n/).map(r=>r.trim()).filter(Boolean);changed();});
  get('theme-default').addEventListener('change',()=>{draft.isDefault=get('theme-default').checked;if(draft.isDefault){draft.active=true;draft.visibility='public';get('theme-visibility').value='public';}changed();});
  get('theme-foreground').addEventListener('change',()=>{draft.foregroundPreset=get('theme-foreground').value||null;changed();});get('theme-overlay').addEventListener('input',()=>{draft.overlayOpacity=Number(get('theme-overlay').value);changed();});get('theme-overlay-reset').addEventListener('click',()=>{draft.overlayOpacity=null;get('theme-overlay').value=template(draft.layoutKey).overlayOpacity;changed();});
  get('theme-image-group').addEventListener('change',()=>{draft.imageGroupId=get('theme-image-group').value?Number(get('theme-image-group').value):null;changed();});document.querySelectorAll('[name="theme-presentation"]').forEach(radio=>radio.addEventListener('change',()=>{draft.imagePresentation=radio.value;changed();}));
  form.addEventListener('invalid',event=>{const pane=event.target.closest('[role=tabpanel]');if(pane)showTab(pane.id.replace('theme-',''));},true);
  get('theme-cancel').addEventListener('click',async()=>{if(busy)return;if(dirty()&&!await core.discard())return;draft=null;id=null;snapshot='';editor.hidden=true;frame.src='about:blank';ready.delete(frame);get('theme-add').focus();});
  async function load(){
    if(busy)return;busy=true;get('themes-retry').hidden=true;
    try{[themes,templates,library]=await Promise.all([request('api/admin/themes'),request('api/admin/themes/templates'),request('api/admin/images')]);loaded=true;renderGallery();get('theme-add').disabled=false;say('الثيمات جاهزة. أضف ثيمًا أو عدّل أحد الثيمات الحالية.');}
    catch(error){say(error.message,true);get('themes-retry').hidden=false;}finally{busy=false;}
  }
  form.addEventListener('submit',async event=>{
    event.preventDefault();if(busy||!draft)return;
    if(!draft.themeName.trim()){get('theme-name').focus();return;}
    if(draft.visibility==='preview'&&(!draft.previewRoles.length||draft.previewRoles.length>50||draft.previewRoles.some(r=>r.length>200)||new Set(draft.previewRoles).size!==draft.previewRoles.length)){showTab('details');say('أدخل حتى 50 دورًا مختلفًا، بطول لا يزيد عن 200 حرف لكل دور.',true);return;}
    if(draft.isDefault&&(!draft.active||draft.visibility!=='public')){say('لا يمكن تعطيل الثيم الافتراضي. اختر افتراضيًا آخر أولًا.',true);return;}
    if(draft.isDefault&&!themes.some(t=>t.themeId===id&&t.isDefault)&&!await confirmAction('تطبيق الافتراضي على الجميع','سيتم نشر هذا الثيم للجميع وتعيينه لجميع المستخدمين عند تحميل البوابة، مع استبدال اختياراتهم الحالية. متابعة؟'))return;
    busy=true;form.querySelectorAll('input,select,textarea,button').forEach(n=>{n.disabled=true;});
    try{const result=await request('api/admin/themes'+(id?'/'+id:''),id?'PUT':'POST',draft);id=result.themeId;themes=await request('api/admin/themes');snapshot=serial();renderGallery();get('theme-default').disabled=themes.some(t=>t.themeId===id&&t.isDefault);say(draft.isDefault?'تم حفظ الافتراضي. يظهر عند تحميل البوابة.':draft.visibility==='public'?'تم الحفظ والنشر المباشر لجميع المستخدمين.':draft.visibility==='preview'?'تم الحفظ وإتاحة المعاينة للأدوار المحددة فقط.':'تم الحفظ كمخفي للإدارة فقط.');get('theme-editor-title').textContent='تعديل '+draft.themeName;}
    catch(error){say(error.message,true);}finally{busy=false;form.querySelectorAll('input,select,textarea,button').forEach(n=>{n.disabled=false;});get('theme-default').disabled=themes.some(t=>t.themeId===id&&t.isDefault);changed();}
  });
  get('themes-retry').addEventListener('click',async()=>{if(!busy&&(!dirty()||await core.discard()))load();});
  core.watch('themes',form,()=>!editor.hidden&&dirty(),()=>busy);
  core.whenSection('themes',()=>{if(!busy&&!dirty())load();});
})();
