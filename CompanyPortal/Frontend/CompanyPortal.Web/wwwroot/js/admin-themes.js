(() => {
  const panel=document.querySelector('[data-admin-panel="themes"]'),base=document.querySelector('meta[name="companyportal-api-base"]')?.content;
  if(!panel||!base)return;
  const api=new URL(base.replace(/\/?$/,'/'),location.href),get=id=>document.getElementById(id),status=get('themes-status'),gallery=get('theme-gallery'),editor=get('theme-editor'),form=get('theme-form'),frame=get('theme-preview-frame'),dialog=get('theme-preview-dialog'),galleryFrame=get('theme-gallery-preview');
  let themes=[],templates=[],library={groups:[],items:[],images:[]},knownRoles=[],draft=null,id=null,snapshot='',busy=false,loaded=false,libraryLoading=false,previewRecord=null,focusImageId=null;
  const core=window.AdminCore,ready=new Set(),say=(text,error=false)=>{core.feedback(status,text,error);};
  const node=(tag,text,css)=>{const n=document.createElement(tag);if(text!==undefined)n.textContent=text;if(css)n.className=css;return n;};
  const option=(value,text)=>{const n=node('option',text);n.value=String(value??'');return n;};
  const template=key=>templates.find(t=>t.layoutKey===key)||templates[0];
  const serial=()=>JSON.stringify(draft);
  const dirty=()=>draft&&serial()!==snapshot;
  // The API sends a code for each theme rule (see ThemeAdministrationController.Classify); field errors come from model validation.
  const errorMessages={busy:'يجري حفظ تعديل آخر على الثيمات. أعد المحاولة بعد لحظات.','not-found':'الثيم غير موجود؛ ربما حُذف. أعد تحميل القائمة.','default-not-public':'الثيم الافتراضي يجب أن يكون منشورًا للجميع. انشره أولًا ثم عيّنه افتراضيًا.','default-required':'عيّن ثيمًا افتراضيًا آخر أولًا، ثم أخفِ هذا الثيم أو احذفه.',roles:'أدخل حتى 50 دورًا مختلفًا، بطول لا يزيد عن 200 حرف. حالة المعاينة تحتاج دورًا واحدًا على الأقل.','inactive-group':'مجموعة الصور المختارة غير نشطة. اختر مجموعة نشطة أو الصور الأصلية للقالب.',positions:'مواضع الصور لا تطابق صور المجموعة المختارة. اضبطها من جديد.',details:'تحقق من اسم الثيم والقالب وترتيب الظهور.'};
  const colourMessage='أدخل الألوان بصيغة #RRGGBB، أو اتركها فارغة لاستخدام ألوان القالب.';
  function errorText(status,problem){
    if(errorMessages[problem?.code])return errorMessages[problem.code];
    const fields=Object.keys(problem?.errors||{}).join(' ').toLowerCase();
    if(/colou?r/.test(fields))return colourMessage;
    if(/overlay/.test(fields))return 'قوة طبقة التباين يجب أن تكون بين 0 و85.';
    if(/name/.test(fields))return 'اسم الثيم مطلوب، حتى 200 حرف.';
    if(/order/.test(fields))return 'ترتيب الظهور رقم من 0 إلى 1000000.';
    if(/role/.test(fields))return errorMessages.roles;
    return status===404?errorMessages['not-found']:status===409?errorMessages.busy:status===400?'تعذر الحفظ. راجع قيم الثيم وأعد المحاولة.':'تعذر تحميل أو حفظ الثيمات. أعد المحاولة.';
  }
  async function request(path,method='GET',body){
    const response=await core.request(path,{method,body,header:'admin-themes',handled:[400,404,409]});
    if(!response.ok){
      if(response.status===401||response.status===403){editor.hidden=true;gallery.replaceChildren();loaded=false;get('theme-add').disabled=true;throw new Error('ليس لديك صلاحية إدارة الثيمات.');}
      throw new Error(errorText(response.status,await response.json().catch(()=>null)));
    }
    return response.status===204?null:response.json();
  }
  function groupData(theme){
    const group=library.groups.find(g=>g.imageGroupId===theme.imageGroupId&&g.active);
    const ids=group?library.items.filter(i=>i.imageGroupId===group.imageGroupId&&i.active).sort((a,b)=>a.displayOrder-b.displayOrder).filter(i=>library.images.some(image=>image.imageId===i.imageId)):[];
    return {settings:group?{rotateImages:group.rotateImages,rotationSeconds:group.rotationSeconds,defaultImageId:group.defaultImageId}:null,images:ids.map(i=>({imageId:i.imageId}))};
  }
  function focusPosition(){return draft?.imagePositions.find(p=>p.imageId===focusImageId)||{imageId:focusImageId,focalX:50,focalY:draft?.imagePresentation==='artwork'?50:56};}
  function syncFocus(){
    const members=groupData(draft).images,select=get('theme-focus-image');
    if(!members.some(i=>i.imageId===focusImageId))focusImageId=members.find(i=>i.imageId===groupData(draft).settings?.defaultImageId)?.imageId||members[0]?.imageId||null;
    if(select.dataset.members!==JSON.stringify(members)){
      select.replaceChildren(...members.map(i=>option(i.imageId,library.images.find(image=>image.imageId===i.imageId)?.imageName||'صورة '+i.imageId)));select.dataset.members=JSON.stringify(members);
    }
    select.value=String(focusImageId??'');get('theme-focus-controls').hidden=!members.length;
    const p=focusPosition();for(const [axis,value] of [['x',p.focalX],['y',p.focalY]]){get('theme-focus-'+axis).value=value;get('theme-focus-'+axis+'-value').textContent=value+'%';}
  }
  function setFocus(x,y){
    if(busy||!draft||!focusImageId||![x,y].every(v=>typeof v==='number'&&Number.isFinite(v)&&v>=0&&v<=100))return;
    const p={imageId:focusImageId,focalX:Math.round(x*100)/100,focalY:Math.round(y*100)/100};
    draft.imagePositions=draft.imagePositions.filter(i=>i.imageId!==focusImageId).concat(p).sort((a,b)=>a.imageId-b.imageId);changed();
  }
  function send(target,theme){
    if(!ready.has(target)||!theme)return;
    const data=groupData(theme),editing=target===frame&&!!focusImageId;
    if(editing&&data.settings)data.settings={...data.settings,rotateImages:false,defaultImageId:focusImageId};
    target.contentWindow.postMessage({type:'companyportal:theme-preview',theme,...data,positioning:editing&&!get('theme-images').hidden},location.origin);
  }
  window.addEventListener('message',event=>{
    if(event.origin===location.origin&&event.source===frame.contentWindow&&event.data?.type==='companyportal:image-position'&&!get('theme-images').hidden&&event.data.imageId===focusImageId){setFocus(event.data.focalX,event.data.focalY);return;}
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
    syncFocus();
    get('theme-dirty').textContent=dirty()?'تغييرات غير محفوظة':id?'كل التغييرات محفوظة':'لم يُحفظ بعد';
    get('theme-save').disabled=busy||!dirty();
    get('theme-overlay-value').textContent=draft.overlayOpacity===null?'إعداد القالب':draft.overlayOpacity+'%';
    const group=library.groups.find(g=>g.imageGroupId===draft.imageGroupId),members=groupData(draft).images.length;
    get('theme-group-summary').textContent=group?`${group.groupName} · ${members} صورة نشطة · ${group.rotateImages?'تدوير كل '+group.rotationSeconds+' ثوانٍ':'صورة ثابتة'}${group.active?'':' · المجموعة غير نشطة؛ اختر مجموعة نشطة للحفظ.'}`:'ستظهر الصور الأصلية لقالب التصميم.';
    const bg=draft.backgroundColor||template(draft.layoutKey).backgroundColor,primary=draft.primaryColor||template(draft.layoutKey).primaryColor;
    get('theme-colour-advice').textContent=bg.toLowerCase()===primary.toLowerCase()?'اللون الرئيسي والخلفية متطابقان. راجع تباين العناوين في المعاينة.':'راجع وضوح النصوص والأزرار في المعاينة.';
    get('theme-roles-field').hidden=draft.visibility!=='preview';rolesHelp();
    get('theme-publication-note').textContent=visibilityName[draft.visibility]+(draft.visibility==='public'?' — بعد الحفظ يظهر في قائمة الثيمات لدى الجميع.':draft.visibility==='preview'?' — يظهر فقط لمن يحمل أحد الأدوار المحددة.':' — لا يظهر في قائمة الثيمات لدى الموظفين.');
    get('theme-save').textContent=draft.visibility==='public'?'حفظ ونشر للجميع':draft.visibility==='preview'?'حفظ وإتاحة للأدوار المحددة':'حفظ كمخفي';
    send(frame,draft);
  }
  const visibilityName={hidden:'مخفي — للإدارة فقط',preview:'معاينة لأدوار محددة',public:'مباشر — لجميع المستخدمين'};
  const confirmAction=(title,message)=>core.confirm(message,{title,accept:title.startsWith('حذف')?'حذف':title.startsWith('إخفاء')?'إخفاء':'تأكيد',danger:/حذف|إخفاء|تطبيق|استبدال/.test(title)});
  const savedPayload=theme=>Object.fromEntries(['themeName','layoutKey','displayOrder','active','isDefault','primaryColor','accentColor','backgroundColor','overlayOpacity','foregroundPreset','imagePresentation','imageGroupId','visibility','previewRoles','imagePositions'].map(key=>[key,theme[key]]));
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
  // Known roles are suggestions only; a name outside the list may still be valid, so it only warns.
  function rolesHelp(){
    const help=get('theme-roles-help');help.hidden=draft.visibility!=='preview';if(help.hidden)return;
    const unknown=draft.previewRoles.filter(r=>!knownRoles.includes(r));
    get('theme-roles-warning').textContent=unknown.length?'غير معروف للبوابة: '+unknown.join('، ')+'. تأكد أنه مكتوب كما يعيده مصدر الصلاحيات تمامًا، وإلا فلن يرى أحد هذا الثيم.':'';
    const box=get('theme-roles-known'),suggest=knownRoles.filter(r=>!draft.previewRoles.includes(r));
    if(box.dataset.list===JSON.stringify(suggest))return;box.dataset.list=JSON.stringify(suggest);
    box.replaceChildren(...suggest.map(role=>{const button=node('button','+ '+role);button.type='button';button.setAttribute('aria-label','إضافة الدور '+role);button.addEventListener('click',()=>{const field=get('theme-preview-roles');field.value=(field.value.trim()?field.value.replace(/\s*$/,'')+'\n':'')+role;field.dispatchEvent(new Event('input',{bubbles:true}));});return button;}));
  }
  function groupOptions(){
    const groups=get('theme-image-group');groups.replaceChildren(option('','الصور الأصلية للقالب'));library.groups.filter(g=>g.active||g.imageGroupId===draft.imageGroupId).forEach(g=>groups.append(option(g.imageGroupId,g.groupName+(g.active?'':' (غير نشطة)'))));groups.value=String(draft.imageGroupId??'');
  }
  // Groups created on the images page (often in another tab) appear without reloading; the draft is kept.
  async function refreshLibrary(){
    if(!loaded||busy||libraryLoading)return;libraryLoading=true;
    try{library=await request('api/admin/images');}catch{return;}finally{libraryLoading=false;}
    if(draft){groupOptions();changed();}renderGallery();
  }
  window.addEventListener('focus',()=>{if(document.body.dataset.adminCurrent==='themes')refreshLibrary();});
  function cover(theme){const data=groupData(theme),first=data.images.find(i=>i.imageId===data.settings?.defaultImageId)||data.images[0];return first?new URL(`api/images/${first.imageId}/${library.images.find(image=>image.imageId===first.imageId)?.hasThumbnail?'thumbnail':'content'}`,api).href:new URL(template(theme.layoutKey).thumbnail,document.baseURI).href;}
  function renderGallery(){
    gallery.replaceChildren();themes.forEach(theme=>{
      const card=node('article',undefined,'theme-card'),coverBox=node('div',undefined,'theme-card-cover'),image=node('img');AdminChanges.tag(card,'themes','theme',theme.themeId);image.src=cover(theme);image.alt='';image.loading='lazy';coverBox.append(image);
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
    if(draft)send(frame,draft);
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
    id=record&&!copy?record.themeId:null;AdminChanges.tag(form,'themes','theme',id);
    draft={themeName:record?(copy?'نسخة من '+record.themeName:record.themeName):'',layoutKey:record?.layoutKey||'official',displayOrder:record&&!copy?record.displayOrder:Math.min(1000000,Math.max(0,...themes.map(t=>t.displayOrder))+1),visibility:record&&!copy?record.visibility:'hidden',previewRoles:[...(record?.previewRoles||[])],active:record&&!copy?record.active:false,isDefault:record&&!copy?record.isDefault:false,primaryColor:record?.primaryColor??null,accentColor:record?.accentColor??null,backgroundColor:record?.backgroundColor??null,overlayOpacity:record?.overlayOpacity??null,foregroundPreset:record?.foregroundPreset??null,imagePresentation:record?.imagePresentation||'background',imageGroupId:record?.imageGroupId??null};
    draft.imagePositions=(record?.imagePositions||[]).map(p=>({...p}));focusImageId=null;
    draft.themeName=draft.themeName.slice(0,200);snapshot=id?serial():'';
    editor.hidden=false;get('theme-editor-title').textContent=id?'تعديل '+draft.themeName:copy?'نسخ الثيم':'ثيم جديد';
    get('theme-name').value=draft.themeName;get('theme-order').value=draft.displayOrder;get('theme-visibility').value=draft.visibility;get('theme-preview-roles').value=draft.previewRoles.join('\n');get('theme-default').checked=draft.isDefault;get('theme-default').disabled=!!record?.isDefault&&!copy;
    const choices=get('theme-templates');choices.replaceChildren();templates.forEach(t=>{const label=node('label',undefined,'theme-template-option'),image=node('img'),line=node('span'),radio=node('input');image.src=new URL(t.thumbnail,document.baseURI);image.alt='';radio.type='radio';radio.name='theme-layout';radio.value=t.layoutKey;radio.checked=draft.layoutKey===t.layoutKey;radio.addEventListener('change',()=>{draft.layoutKey=t.layoutKey;colourFields();get('theme-overlay').value=draft.overlayOpacity??t.overlayOpacity;changed();});line.append(radio,node('span',t.templateName));label.append(image,line);choices.append(label);});
    groupOptions();
    document.querySelectorAll('[name="theme-presentation"]').forEach(radio=>{radio.checked=radio.value===draft.imagePresentation;});get('theme-foreground').value=draft.foregroundPreset||'';get('theme-overlay').value=draft.overlayOpacity??template(draft.layoutKey).overlayOpacity;colourFields();showTab('details');changed();
    if(frame.src==='about:blank'){ready.delete(frame);frame.src=frame.dataset.previewUrl;}requestAnimationFrame(fit);editor.scrollIntoView({behavior:'smooth',block:'start'});get('theme-name').focus({preventScroll:true});
  }
  get('theme-add').addEventListener('click',()=>open(null,false));
  get('theme-name').addEventListener('input',()=>{draft.themeName=get('theme-name').value;changed();});get('theme-order').addEventListener('input',()=>{draft.displayOrder=Number(get('theme-order').value);changed();});
  get('theme-visibility').addEventListener('change',()=>{draft.visibility=get('theme-visibility').value;draft.active=draft.visibility!=='hidden';changed();});
  get('theme-preview-roles').addEventListener('input',()=>{draft.previewRoles=get('theme-preview-roles').value.split(/\r?\n/).map(r=>r.trim()).filter(Boolean);changed();});
  get('theme-default').addEventListener('change',()=>{draft.isDefault=get('theme-default').checked;if(draft.isDefault){draft.active=true;draft.visibility='public';get('theme-visibility').value='public';}changed();});
  get('theme-foreground').addEventListener('change',()=>{draft.foregroundPreset=get('theme-foreground').value||null;changed();});get('theme-overlay').addEventListener('input',()=>{draft.overlayOpacity=Number(get('theme-overlay').value);changed();});get('theme-overlay-reset').addEventListener('click',()=>{draft.overlayOpacity=null;get('theme-overlay').value=template(draft.layoutKey).overlayOpacity;changed();});
  get('theme-image-group').addEventListener('change',()=>{draft.imageGroupId=get('theme-image-group').value?Number(get('theme-image-group').value):null;const members=groupData(draft).images;draft.imagePositions=draft.imagePositions.filter(p=>members.some(i=>i.imageId===p.imageId));changed();});document.querySelectorAll('[name="theme-presentation"]').forEach(radio=>radio.addEventListener('change',()=>{draft.imagePresentation=radio.value;changed();}));
  get('theme-focus-image').addEventListener('change',()=>{focusImageId=Number(get('theme-focus-image').value);syncFocus();send(frame,draft);});
  for(const axis of ['x','y'])get('theme-focus-'+axis).addEventListener('input',()=>{const p=focusPosition();setFocus(axis==='x'?Number(get('theme-focus-x').value):p.focalX,axis==='y'?Number(get('theme-focus-y').value):p.focalY);});
  get('theme-focus-reset').addEventListener('click',()=>setFocus(50,50));
  form.addEventListener('invalid',event=>{const pane=event.target.closest('[role=tabpanel]');if(pane)showTab(pane.id.replace('theme-',''));if(event.target.id.startsWith('theme-colour-'))say(colourMessage,true);},true);
  get('theme-cancel').addEventListener('click',async()=>{if(busy)return;if(dirty()&&!await core.discard())return;draft=null;id=null;snapshot='';editor.hidden=true;frame.src='about:blank';ready.delete(frame);get('theme-add').focus();});
  async function load(){
    if(busy)return;busy=true;get('themes-retry').hidden=true;
    try{[themes,templates,library,knownRoles]=await Promise.all([request('api/admin/themes'),request('api/admin/themes/templates'),request('api/admin/images'),request('api/admin/themes/roles').catch(()=>[])]);loaded=true;renderGallery();get('theme-add').disabled=false;say('الثيمات جاهزة. أضف ثيمًا أو عدّل أحد الثيمات الحالية.');}
    catch(error){say(error.message,true);get('themes-retry').hidden=false;}finally{busy=false;}
  }
  form.addEventListener('submit',async event=>{
    event.preventDefault();if(busy||!draft)return;
    if(!draft.themeName.trim()){get('theme-name').focus();return;}
    const badColour=['primaryColor','accentColor','backgroundColor'].find(key=>draft[key]!==null&&!/^#[\da-f]{6}$/i.test(draft[key]));
    if(badColour){showTab('colours');say(colourMessage,true);get('theme-colour-'+badColour)?.focus();return;}
    if(draft.visibility==='preview'&&(!draft.previewRoles.length||draft.previewRoles.length>50||draft.previewRoles.some(r=>r.length>200)||new Set(draft.previewRoles).size!==draft.previewRoles.length)){showTab('details');say('أدخل حتى 50 دورًا مختلفًا، بطول لا يزيد عن 200 حرف لكل دور.',true);return;}
    if(draft.isDefault&&(!draft.active||draft.visibility!=='public')){say('لا يمكن تعطيل الثيم الافتراضي. اختر افتراضيًا آخر أولًا.',true);return;}
    if(draft.isDefault&&!themes.some(t=>t.themeId===id&&t.isDefault)&&!await confirmAction('تطبيق الافتراضي على الجميع','سيتم نشر هذا الثيم للجميع وتعيينه لجميع المستخدمين عند تحميل البوابة، مع استبدال اختياراتهم الحالية. متابعة؟'))return;
    busy=true;form.querySelectorAll('input,select,textarea,button').forEach(n=>{n.disabled=true;});
    try{const result=await request('api/admin/themes'+(id?'/'+id:''),id?'PUT':'POST',draft);id=result.themeId;AdminChanges.tag(form,'themes','theme',id);themes=await request('api/admin/themes');knownRoles=await request('api/admin/themes/roles').catch(()=>knownRoles);snapshot=serial();renderGallery();get('theme-default').disabled=themes.some(t=>t.themeId===id&&t.isDefault);say(draft.isDefault?'تم حفظ الافتراضي. يظهر عند تحميل البوابة.':draft.visibility==='public'?'تم الحفظ والنشر المباشر لجميع المستخدمين.':draft.visibility==='preview'?'تم الحفظ وإتاحة المعاينة للأدوار المحددة فقط.':'تم الحفظ كمخفي للإدارة فقط.');get('theme-editor-title').textContent='تعديل '+draft.themeName;}
    catch(error){say(error.message,true);}finally{busy=false;form.querySelectorAll('input,select,textarea,button').forEach(n=>{n.disabled=false;});get('theme-default').disabled=themes.some(t=>t.themeId===id&&t.isDefault);changed();}
  });
  get('themes-retry').addEventListener('click',async()=>{if(!busy&&(!dirty()||await core.discard()))load();});
  core.watch('themes',form,()=>!editor.hidden&&dirty(),()=>busy);
  core.whenSection('themes',()=>{if(!busy&&!dirty())load();else refreshLibrary();});
})();
