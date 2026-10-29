(() => {
 const root=document.getElementById('admin-events');if(!root)return;
 const core=window.AdminCore,form=document.getElementById('event-editor'),list=document.getElementById('events-list'),status=document.getElementById('events-status'),retry=document.getElementById('events-retry');
 const editorDialog=document.getElementById('event-editor-dialog'),errors=document.getElementById('event-editor-errors');
 const publishDialog=document.getElementById('event-publish-dialog'),publishForm=document.getElementById('event-publish-form'),publishEnd=document.getElementById('event-publish-end');
 const field=name=>form.elements.namedItem(name),make=(tag,text)=>Object.assign(document.createElement(tag),{textContent:text});
 let busy=false,loaded=false,editing=null,publishing=null,options=null,optionsPending=false;
 const tracker=core.trackForm('events',form,{busy:()=>busy});
 const fmt=new Intl.DateTimeFormat('ar-OM',{dateStyle:'medium',timeStyle:'short',timeZone:'Asia/Muscat'});
 const local=at=>new Date(new Date(at).getTime()+4*3600000).toISOString().slice(0,16);
 const types=['ملف PDF','صفحة أو تطبيق','فيديو'];
 const message=(text,error=false)=>core.feedback(status,text,error);
 async function request(path='',method='GET',body){
  const r=await core.request('api/admin/events'+path,{method,body,header:'events',timeout:body instanceof FormData?120000:15000,handled:[400,404,409,413,415,422,500,503]});
  if(!r.ok){let data;try{data=await r.json();}catch{}
   const fields={};for(const [key,value] of Object.entries(data?.errors??{})){const name=key.split('.').pop();fields[name.charAt(0).toLowerCase()+name.slice(1)]=Array.isArray(value)?value.join(' '):String(value);}
   const statusMessage=body instanceof FormData&&!data&&r.status===404?'رفض الخادم رفع الملف. تحقق من حد حجم الطلب في IIS ومسار خدمة الرفع.':({401:'انتهت صلاحية الجلسة. أعد تحميل الصفحة.',403:'لا تملك صلاحية إدارة الفعاليات.',404:'الفعالية غير موجودة. أعد تحميل القائمة.',413:'الملف أكبر من الحد المسموح (100 ميجابايت).'})[r.status];const error=new Error(Object.keys(fields).length?'لم يتم الحفظ. راجع الحقول الموضحة أدناه.':statusMessage||data?.message||data?.title||'تعذر إتمام العملية. حاول مجددًا.');
   if(r.status>=500&&data?.reference)error.message+=' رقم المرجع: '+data.reference;error.eventError=true;error.fields=fields;if(data?.field)error.fields[body instanceof FormData&&data.field==='eventTarget'?'eventFile':data.field]=error.message;throw error;
  }return r;
 }
 function clearErrors(){errors.hidden=true;errors.replaceChildren();for(const e of form.querySelectorAll('[data-event-error]')){e.hidden=true;e.textContent='';}for(const e of form.querySelectorAll('[aria-invalid]')){e.removeAttribute('aria-invalid');e.removeAttribute('aria-describedby');}}
 function showErrors(text,fields={}){
  const area=editorDialog.open?errors:publishDialog.open?document.getElementById('event-publish-errors'):status;area.replaceChildren(make('strong',text));
  for(const [key,value] of Object.entries(fields)){const node=[...form.querySelectorAll('[data-event-error]')].find(e=>e.dataset.eventError===key);if(node){node.textContent=value;node.hidden=false;node.id='event-error-'+key;field(key)?.setAttribute?.('aria-invalid','true');field(key)?.setAttribute?.('aria-describedby',node.id);}if(value!==text)area.append(make('p',value));}
  area.hidden=false;if(area===errors){errors.focus();errors.scrollIntoView({block:'nearest'});}else if(area===status)core.feedback(status,text,true);
 }
 const source=()=>form.querySelector('[name=fileSource]:checked')?.value??'upload';
 const selectedTarget=()=>Number(field('eventType').value)===1?field('appUrl').value.trim():field('eventTarget').value.trim();
 function close(){editorDialog.close();form.hidden=true;form.reset();editing=null;clearErrors();tracker.saved();}
 function syncSource(){const type=Number(field('eventType').value);for(const card of form.querySelectorAll('[data-source-card]'))card.dataset.selected=String(card.dataset.sourceCard===source());field('eventFile').disabled=type===1||source()!=='upload';field('eventTarget').disabled=type===1||source()!=='path';}
 async function loadOptions(){
  const roots=document.getElementById('event-path-roots');if(optionsPending||options)return;optionsPending=true;roots.textContent='جارٍ تحميل المجلدات المسموحة…';
  try{options=await(await request('/file-options')).json();roots.replaceChildren(make('strong',options.roots.length?'المجلدات المسموحة على الخادم:':'لم تُضبط المجلدات. أضف Events في Mstr.Utls.'));for(const root of options.roots){const path=make('bdi',root);path.dir='ltr';roots.append(path);}}
  catch(e){roots.textContent=e.eventError?e.message:'تعذر تحميل المجلدات. تحقق من الاتصال.';}finally{optionsPending=false;}
 }
 function syncType(){const type=Number(field('eventType').value);document.getElementById('event-file-sources').hidden=type===1;document.getElementById('event-url-label').hidden=type!==1;field('eventFile').accept=type===0?'.pdf,application/pdf':'.mp4,video/mp4';document.getElementById('event-file-help').textContent=(type===0?'PDF فقط':'MP4 فقط')+' · الحد الأقصى 100 ميجابايت';syncSource();if(type!==1)void loadOptions();}
 async function edit(row,reactivate=false){
  if(busy||tracker.dirty()&&!await core.discard())return;form.hidden=false;editing=row?.eventId??null;clearErrors();
  document.getElementById('event-editor-title').textContent=row?'تعديل الفعالية':'فعالية جديدة';
  field('title').value=row?.title??'';field('eventType').value=String(row?.eventType??1);field('eventFile').value='';
  field('appUrl').value=(row?.eventType??1)===1?(row?.eventTarget??row?.appUrl??''):'';field('eventTarget').value=row?.eventType!==1?(row?.eventTarget??''):'';
  form.querySelector('[name=fileSource][value="'+(row&&row.eventType!==1?'path':'upload')+'"]').checked=true;
  field('startAt').value=local(row?.startAt??Date.now());field('endAt').value=local(row?.endAt??Date.now()+7*86400000).slice(0,10);field('isDisplayed').checked=row?.isDisplayed??true;
  syncType();tracker.saved();if(!editorDialog.open)editorDialog.showModal();
  if(reactivate){field('isDisplayed').checked=true;document.getElementById('event-editor-title').textContent='إعادة جدولة الفعالية';core.refresh();field('startAt').focus();}else field('title').focus();
 }
 function eventState(row){return !row.isDisplayed?['hidden','مخفية']:Date.parse(row.endAt)<=Date.now()?['expired','انتهت']:Date.parse(row.startAt)>Date.now()?['scheduled','مجدولة']:['live','منشورة للجميع'];}
 function detail(label,value){const box=make('div','');box.append(make('dt',label),make('dd',value));return box;}
 function render(rows){
  list.replaceChildren();if(!rows.length){const empty=make('p','لا توجد فعاليات. أضف فعالية وحدّد فترة عرضها.');empty.className='event-empty';list.append(empty);}
  for(const row of rows){
   const item=make('article','');item.className='event-row';item.dataset.eventId=row.eventId;const [key,state]=eventState(row);item.dataset.state=key;
   const heading=make('div','');heading.className='event-row-heading';const title=make('h3',row.title),badge=make('span',state),titleBlock=make('div','');titleBlock.className='event-title-block';badge.className='event-status event-status--'+key;titleBlock.append(make('span','العنوان'),title);heading.append(titleBlock,badge);
   const info=make('dl','');info.className='event-details';info.append(detail('النوع',types[row.eventType??1]),detail('بداية العرض',fmt.format(new Date(row.startAt))),detail('نهاية العرض',fmt.format(new Date(row.endAt))));
   const target=make('div','');target.className='event-target-direct';target.append(make('span',row.eventType===1?'الرابط':'مسار الملف'));const path=make('p',row.eventTarget??row.appUrl);path.dir='ltr';target.append(path);
   const actions=make('div','');actions.className='event-row-actions';const editButton=make('button','تعديل'),remove=make('button','حذف');editButton.type=remove.type='button';remove.className='event-delete';editButton.onclick=()=>void edit(row);
   remove.onclick=async()=>{if(busy||tracker.dirty()&&!await core.discard())return;if(!await core.confirm('حذف «'+row.title+'»؟',{title:'حذف الفعالية',accept:'حذف',danger:true}))return;await run(async()=>{await request('/'+row.eventId,'DELETE');close();await load();message('تم الحذف');});};
   actions.append(editButton);if(key!=='live'){const publish=make('button','نشر للجميع الآن');publish.type='button';publish.className='admin-primary event-publish';publish.onclick=()=>void preparePublish(row);actions.prepend(publish);}
   if(row.isDisplayed){const hide=make('button','إخفاء عن الجميع');hide.type='button';hide.className='event-hide';hide.onclick=()=>void hideEvent(row);actions.append(hide);}
   const reschedule=make('button','إعادة جدولة');reschedule.type='button';reschedule.onclick=()=>void edit(row,true);actions.append(reschedule,remove);item.append(heading,info,target,actions);AdminChanges.tag(item,'events','event',row.eventId);list.append(item);
  }
 }
 async function hideEvent(row){if(busy||tracker.dirty()&&!await core.discard())return;if(!await core.confirm('سيتم إخفاء «'+row.title+'» عن جميع المستخدمين دون حذفها. يختفي التبويب عند إعادة تحميل البوابة، ويتوقف الوصول لملف الفعالية فورًا.',{title:'إخفاء الفعالية عن الجميع؟',accept:'إخفاء عن الجميع',danger:true}))return;
  await run(async()=>{await request('/'+row.eventId,'PUT',{title:row.title,eventType:row.eventType??1,eventTarget:row.eventTarget??row.appUrl,startAt:row.startAt,endAt:row.endAt,isDisplayed:false});close();await load();message('تم إخفاء الفعالية عن الجميع.');});
 }
 root.querySelectorAll('[data-event-end-days]').forEach(button=>button.addEventListener('click',()=>{if(busy)return;const input=button.closest('#event-publish-dialog')?publishEnd:field('endAt');input.value=local(Date.now()+Number(button.dataset.eventEndDays)*86400000).slice(0,10);input.setCustomValidity('');input.dispatchEvent(new Event('input',{bubbles:true}));}));
 async function preparePublish(row){if(busy||tracker.dirty()&&!await core.discard())return;publishing=row;document.getElementById('event-publish-name').textContent=row.title;publishEnd.value=local(Date.parse(row.endAt)>Date.now()?row.endAt:Date.now()+7*86400000).slice(0,10);publishEnd.setCustomValidity('');document.getElementById('event-publish-errors').hidden=true;publishDialog.showModal();}
 publishEnd.addEventListener('input',()=>publishEnd.setCustomValidity(''));document.getElementById('event-publish-cancel').onclick=()=>{if(!busy)publishDialog.close();};publishDialog.addEventListener('cancel',e=>{if(busy)e.preventDefault();});publishDialog.addEventListener('close',()=>{publishing=null;});
 publishForm.addEventListener('submit',e=>{e.preventDefault();if(busy||!publishing)return;publishEnd.setCustomValidity('');const end=new Date(publishEnd.value+'T23:59:00+04:00');if(!Number.isFinite(end.getTime())||end<=new Date()){showErrors('اختر نهاية عرض بعد الوقت الحالي.');return;}
  const row=publishing;void run(async()=>{await request('/'+row.eventId,'PUT',{title:row.title,eventType:row.eventType??1,eventTarget:row.eventTarget??row.appUrl,startAt:new Date().toISOString(),endAt:end.toISOString(),isDisplayed:true});publishDialog.close();close();await load();message('تم نشر الفعالية للجميع. تظهر عند فتح البوابة أو إعادة تحميلها.');});
 });
 async function load(){retry.hidden=true;try{render(await(await request()).json());loaded=true;}catch(e){retry.hidden=false;throw e;}}
 async function run(action){if(busy)return;busy=true;const controls=[...root.querySelectorAll('button,input,select')].filter(e=>!e.disabled);controls.forEach(e=>e.disabled=true);core.refresh();try{await action();}catch(e){showErrors(e.eventError?e.message:'تعذر الاتصال بخدمة البوابة أو انتهت مهلة الطلب. تحقق من الاتصال قبل إعادة المحاولة.',e.fields??{});}finally{busy=false;controls.forEach(e=>{if(e.isConnected)e.disabled=false;});syncSource();core.refresh();}}
 async function cancelEdit(){if(!busy&&(!tracker.dirty()||await core.discard()))close();}
 document.getElementById('event-add').onclick=()=>void edit(null);document.getElementById('event-cancel').onclick=()=>void cancelEdit();document.getElementById('event-editor-close').onclick=()=>void cancelEdit();retry.onclick=()=>void run(load);
 editorDialog.addEventListener('cancel',e=>{e.preventDefault();void cancelEdit();});editorDialog.addEventListener('click',e=>{if(e.target!==editorDialog)return;const r=editorDialog.getBoundingClientRect();if(e.clientX<r.left||e.clientX>r.right||e.clientY<r.top||e.clientY>r.bottom)void cancelEdit();});
 form.addEventListener('submit',e=>{e.preventDefault();if(busy)return;clearErrors();const issues={},type=Number(field('eventType').value),file=field('eventFile').files[0],target=selectedTarget(),start=field('startAt').value,end=field('endAt').value+'T23:59';
  if(!field('title').value.trim())issues.title='أدخل عنوان الفعالية.';else if(field('title').value.trim().length>150)issues.title='العنوان يجب ألا يتجاوز 150 حرفًا.';
  if(!start)issues.startAt='حدد تاريخ ووقت بداية العرض.';if(!field('endAt').value)issues.endAt='حدد تاريخ نهاية العرض.';else if(start&&end<=start)issues.endAt='نهاية العرض الساعة 11:59 مساءً يجب أن تكون بعد بداية العرض.';
  if(type===1){try{const url=new URL(target);if(!['http:','https:'].includes(url.protocol)||url.username||url.password)throw new Error();}catch{issues.appUrl='أدخل رابطًا صحيحًا يبدأ بـ https:// أو http:// دون اسم مستخدم أو كلمة مرور.';}}
  else if(source()==='upload'){if(!file)issues.eventFile='اختر ملفًا من جهازك، أو اختر طريقة كتابة المسار.';else if(!file.name.toLowerCase().endsWith(type===0?'.pdf':'.mp4'))issues.eventFile=type===0?'اختر ملف PDF بامتداد .pdf.':'اختر فيديو MP4 بامتداد .mp4.';else if(file.size===0)issues.eventFile='الملف فارغ. اختر ملفًا صالحًا.';else if(file.size>100*1024*1024)issues.eventFile='حجم الملف يتجاوز 100 ميجابايت.';}
  else if(!target)issues.eventTarget='أدخل المسار الكامل للملف على الخادم، أو اختر ملفًا من جهازك.';
  else if(!/^(?:[a-z]:[\\/]|\\\\[^\\]+\\[^\\]+)/i.test(target))issues.eventTarget='استخدم مسارًا كاملًا مثل D:\\PortalFiles\\Events\\event.pdf أو مسار مجلد شبكي.';
  else if(!target.toLowerCase().endsWith(type===0?'.pdf':'.mp4'))issues.eventTarget=type===0?'المسار يجب أن ينتهي بـ .pdf.':'المسار يجب أن ينتهي بـ .mp4.';
  if(Object.keys(issues).length){showErrors('لم يتم الحفظ. راجع الحقول الموضحة أدناه.',issues);return;}
  const body={title:field('title').value.trim(),eventType:type,eventTarget:target,startAt:start+':00+04:00',endAt:end+':00+04:00',isDisplayed:field('isDisplayed').checked};let path=editing?'/'+editing:'',method=editing?'PUT':'POST',payload=body;
  if(type!==1&&source()==='upload'){const data=new FormData();data.append('file',file);data.append('payload',JSON.stringify(body));if(editing)data.append('eventId',editing);path='/upload';method='POST';payload=data;}
  void run(async()=>{await request(path,method,payload);close();await load();message('تم الحفظ. تظهر الفعالية خلال الفترة المحددة عند فتح البوابة.');});
 });
 field('eventType').addEventListener('change',()=>{clearErrors();syncType();});form.querySelectorAll('[name=fileSource]').forEach(r=>r.addEventListener('change',()=>{clearErrors();syncSource();}));field('eventFile').addEventListener('change',clearErrors);
 document.addEventListener('admin:section',e=>{if(e.detail?.section!=='events'){if(editorDialog.open)close();if(publishDialog.open)publishDialog.close();}});core.whenSection('events',()=>{if(!loaded)void run(load);});
})();
