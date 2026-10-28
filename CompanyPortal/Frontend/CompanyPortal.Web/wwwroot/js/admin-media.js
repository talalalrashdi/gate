(() => {
 const root=document.getElementById('admin-media'),base=document.querySelector('meta[name="companyportal-api-base"]')?.content;if(!root||!base)return;
 const endpoint=path=>new URL('api/admin/media'+path,new URL(base.replace(/\/?$/,'/'),location.href)).href;
 const id=value=>document.getElementById('admin-media-'+value),list=id('list'),search=id('search'),status=id('status'),retry=id('retry'),editor=id('editor'),form=id('form'),save=id('save'),error=id('error'),preview=id('preview');
 const fields={name:id('name'),path:id('path'),album:id('album'),cover:id('cover'),order:id('order'),active:id('active')};
 const make=(tag,text)=>{const n=document.createElement(tag);if(text!==undefined)n.textContent=text;return n;};
 let catalog={groups:[],items:[]},loaded=false,busy=false,mode='video',kind='video',current=null,isNew=false,original='';
 const core=window.AdminCore;
 const request=(path,method='GET',body)=>core.request(endpoint(path),{method,body,header:'media'});
 function clearPreview(){preview.querySelectorAll('video').forEach(v=>{v.pause();v.removeAttribute('src');v.load();});preview.replaceChildren();}
 function values(){return kind==='group'?{groupName:fields.name.value.trim(),coverMediaId:fields.cover.value?Number(fields.cover.value):null,displayOrder:Number(fields.order.value),active:fields.active.checked}:{mediaName:fields.name.value.trim(),mediaPath:fields.path.value.trim(),mediaType:kind,mediaGroupId:kind==='image'&&fields.album.value?Number(fields.album.value):null,displayOrder:Number(fields.order.value),active:fields.active.checked};}
 const dirty=()=>!editor.hidden&&(isNew||JSON.stringify(values())!==original);
 function sync(){const hiddenAlbum=kind==='image'&&catalog.groups.some(g=>g.mediaGroupId===Number(fields.album.value)&&!g.active);id('album-warning').hidden=!hiddenAlbum;save.disabled=busy||!dirty();id('dirty').textContent=dirty()?'تغييرات غير محفوظة':'لا توجد تغييرات غير محفوظة';save.textContent=!fields.active.checked?'حفظ مخفيًا':hiddenAlbum?'حفظ داخل ألبوم مخفي':'حفظ وإظهار للجميع';}
 function lock(){root.querySelectorAll('input,select,button').forEach(n=>{n.disabled=busy;});root.querySelectorAll('[data-media-add]').forEach(n=>{n.disabled=busy||!loaded;});if(!editor.hidden)sync();}
 function message(text,canRetry=false){core.feedback(status,text);retry.hidden=!canRetry;}
 const confirmDiscard=async()=>!dirty()||await core.discard();
 const normalize=s=>(s||'').normalize('NFKD').replace(/[\u064B-\u065F\u0670]/g,'').replace(/[أإآ]/g,'ا').replace(/ى/g,'ي').toLowerCase().trim();
 function renderList(){
  id('empty').hidden=!editor.hidden;id('count-video').textContent=String(catalog.items.filter(m=>m.mediaType==='video').length);id('count-image').textContent=String(catalog.items.filter(m=>m.mediaType==='image').length);id('count-group').textContent=String(catalog.groups.length);
  const entries=mode==='video'?catalog.items.filter(m=>m.mediaType==='video').map(m=>({kind:'video',row:m})):catalog.groups.map(row=>({kind:'group',row})).concat(catalog.items.filter(m=>m.mediaType==='image').map(row=>({kind:'image',row})));
  const q=normalize(search.value);list.replaceChildren(...entries.filter(e=>normalize((e.row.mediaName||e.row.groupName)+' '+(catalog.groups.find(g=>g.mediaGroupId===e.row.mediaGroupId)?.groupName||'')).includes(q)).map(e=>{
   const b=make('button');b.type='button';const key=e.kind==='group'?e.row.mediaGroupId:e.row.mediaId;
   AdminChanges.tag(b,'media',e.kind==='group'?'album':'media',key);b.dataset.mediaKind=e.kind;b.dataset.visible=String(e.row.active&&!(e.kind==='image'&&catalog.groups.some(g=>g.mediaGroupId===e.row.mediaGroupId&&!g.active)));b.setAttribute('aria-pressed',String(current?.key===key&&current?.kind===e.kind));b.append(make('strong',e.row.mediaName||e.row.groupName),make('small',(e.kind==='group'?'ألبوم':e.kind==='video'?'فيديو':'صورة')+' · '+(!e.row.active?'مخفي':e.kind==='image'&&catalog.groups.some(g=>g.mediaGroupId===e.row.mediaGroupId&&!g.active)?'مخفي مع الألبوم':'ظاهر')));b.addEventListener('click',()=>choose(e.kind,e.row));return b;
  }));if(!list.children.length)list.append(make('p','لا توجد سجلات مطابقة.'));root.querySelectorAll('[data-media-mode]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.mediaMode===mode)));
 }
 function options(select,items,selected,none){select.replaceChildren();const empty=make('option',none);empty.value='';select.append(empty);items.forEach(item=>{const o=make('option',item.name);o.value=String(item.id);select.append(o);});select.value=selected==null?'':String(selected);}
 async function choose(type,row){
  if(busy||!await confirmDiscard())return;kind=type;mode=type==='video'?'video':'image';isNew=!row;current=row?{kind:type,key:type==='group'?row.mediaGroupId:row.mediaId}:null;editor.hidden=false;AdminChanges.tag(form,'media',type==='group'?'album':'media',current?.key);clearPreview();error.hidden=true;
  id('editor-title').textContent=(isNew?'إضافة ':'تعديل ')+(kind==='group'?'ألبوم':kind==='image'?'صورة':'فيديو');fields.name.maxLength=kind==='group'?200:300;fields.name.value=row?.mediaName||row?.groupName||'';fields.path.value=row?.mediaPath||'';fields.order.value=row?.displayOrder??0;fields.active.checked=row?.active??true;
  id('file-fields').hidden=kind==='group';fields.path.required=kind!=='group';id('album-label').hidden=kind!=='image';id('cover-label').hidden=kind!=='group';
  options(fields.album,catalog.groups.map(g=>({id:g.mediaGroupId,name:g.groupName+(g.active?'':' — مخفي')})),row?.mediaGroupId,'صورة مستقلة');
  options(fields.cover,catalog.items.filter(m=>m.mediaType==='image'&&m.mediaGroupId===row?.mediaGroupId).map(m=>({id:m.mediaId,name:m.mediaName+(m.active?'':' — صورة مخفية')})),row?.coverMediaId,'اختيار تلقائي من الصور الظاهرة');
  id('preview-button').closest('.admin-media-preview-section').hidden=kind==='group';id('preview-button').hidden=kind==='group';original=JSON.stringify(values());renderList();sync();fields.name.focus();
 }
 async function load(select){
  busy=true;lock();message('جارٍ تحميل سجل أخبارنا…');
  try{const response=await request('');if(!response.ok)throw new Error(String(response.status));catalog=await response.json();loaded=true;renderList();message('السجل جاهز. الصور والفيديوهات الظاهرة متاحة لجميع مستخدمي البوابة.');if(select){editor.hidden=true;isNew=false;}}
  catch(e){catalog={groups:[],items:[]};loaded=false;current=null;editor.hidden=true;clearPreview();list.replaceChildren();message(e.message==='401'||e.message==='403'?'ليس لديك صلاحية إدارة أخبارنا.':'تعذر تحميل سجل أخبارنا. تحقق من الاتصال وقاعدة البيانات.',true);}
  finally{busy=false;lock();if(select&&loaded){const row=select.kind==='group'?catalog.groups.find(g=>g.mediaGroupId===select.key):catalog.items.find(m=>m.mediaId===select.key);if(row)choose(select.kind,row);}}
 }
 const codes={ROOT_NOT_CONFIGURED:'اضبط مجلد الوسائط المعتمد تحت المفتاح PortalMedia أولًا.',OUTSIDE_ALLOWED_ROOT:'الملف خارج مجلد الوسائط المعتمد.',INVALID_PATH:'مسار الملف غير صالح؛ لا تستخدم اختصارات أو مسارات رجوع.',FILE_NOT_FOUND:'لم يُعثر على الملف. تحقق من المسار واسم الملف.',FILE_ACCESS_DENIED:'حساب تشغيل API لا يملك صلاحية قراءة الملف أو المجلد.',UNSUPPORTED_TYPE:'نوع الملف غير مدعوم: استخدم JPG أو PNG أو GIF أو WebP للصور وMP4 للفيديو.',INVALID_FILE:'محتوى الملف لا يطابق نوعه أو امتداده.',SOURCE_UNAVAILABLE:'تعذر الاتصال بمصدر الوسائط أو قراءة الملف.'};
 async function failure(response){let problem;try{problem=await response.json();}catch{}return codes[problem?.code]||(response.status===400?'تحقق من الاسم والمسار والترتيب والألبوم وصورة الغلاف.':response.status===404?'السجل أو الملف غير موجود. أعد تحميل السجل.':'تعذر إتمام العملية. تحقق من الاتصال وأعد المحاولة.');}
 function revoke(){catalog={groups:[],items:[]};loaded=false;editor.hidden=true;list.replaceChildren();clearPreview();message('ليس لديك صلاحية إدارة أخبارنا.',true);}
 id('preview-button').addEventListener('click',async()=>{
  if(busy||!fields.path.reportValidity())return;busy=true;lock();clearPreview();error.hidden=true;message('جارٍ التحقق من الملف…');
  try{const response=await request('/preview','POST',{mediaPath:fields.path.value.trim(),mediaType:kind});if(!response.ok){if(response.status===401||response.status===403){revoke();return;}throw new Error(await failure(response));}
   const result=await response.json(),node=make(kind==='video'?'video':'img');node.src=endpoint('/preview/'+encodeURIComponent(result.token));if(kind==='video'){node.controls=true;node.preload='metadata';node.addEventListener('loadedmetadata',()=>{if(node.paused&&Number.isFinite(node.duration)&&node.duration>0)node.currentTime=Math.min(.1,node.duration/2);},{once:true});}else node.alt=fields.name.value||'معاينة الصورة';node.addEventListener('error',()=>{error.textContent='تعذر عرض الملف؛ تحقق من اتصال البوابة أو ترميز الفيديو، أو أعد المعاينة إذا انتهت صلاحيتها.';error.hidden=false;});preview.append(node);message('تم التحقق من الملف. هذه المعاينة لا تحفظ ولا تنشر التغييرات.');
  }catch(e){error.textContent=e.message;error.hidden=false;message('تعذر التحقق من الملف.');}finally{busy=false;lock();}
 });
 form.addEventListener('input',()=>{clearPreview();error.hidden=true;sync();});form.addEventListener('change',sync);
 form.addEventListener('submit',async e=>{
  e.preventDefault();if(busy||!dirty()||!form.reportValidity())return;const body=values(),key=current?.key,type=kind;busy=true;lock();error.hidden=true;message('جارٍ الحفظ…');
  try{const route=kind==='group'?'/groups':'/items';const response=await request(route+(isNew?'':'/'+key),isNew?'POST':'PUT',body);if(!response.ok){if(response.status===401||response.status===403){revoke();return;}throw new Error(await failure(response));}
   const result=await response.json(),savedKey=type==='group'?result.mediaGroupId:result.mediaId;editor.hidden=true;isNew=false;busy=false;clearPreview();await load({kind:type,key:savedKey});if(loaded)message('تم الحفظ. تظهر التغييرات عند إعادة تحميل أخبارنا في البوابة.');
  }catch(e){error.textContent=e.message||'تعذر تأكيد الحفظ. أعد تحميل السجل للتحقق.';error.hidden=false;message('تعذر الحفظ. إذا انقطع الاتصال فأعد تحميل السجل قبل إعادة المحاولة.',true);}finally{busy=false;lock();}
 });
 root.querySelectorAll('[data-media-add]').forEach(b=>b.addEventListener('click',()=>choose(b.dataset.mediaAdd,null)));root.querySelectorAll('[data-media-mode]').forEach(b=>b.addEventListener('click',async()=>{if(busy||!await confirmDiscard())return;clearPreview();editor.hidden=true;current=null;mode=b.dataset.mediaMode;renderList();}));
 search.addEventListener('input',renderList);id('cancel').addEventListener('click',async()=>{if(busy||!await confirmDiscard())return;clearPreview();editor.hidden=true;current=null;renderList();});retry.addEventListener('click',async()=>{if(!busy&&await confirmDiscard()){editor.hidden=true;current=null;load();}});
 AdminPreview.button(root.querySelector('.admin-media-actions'),'media',async()=>{
  const draftKind=kind,draftName=fields.name.value,draftActive=fields.active.checked;
  const row=kind==='group'?catalog.items.find(m=>m.mediaId===Number(fields.cover.value))||catalog.items.filter(m=>m.mediaGroupId===current?.key&&m.active).sort((a,b)=>a.displayOrder-b.displayOrder)[0]:{mediaPath:fields.path.value.trim(),mediaType:kind};
  let url=null;if(row?.mediaPath){const r=await request('/preview','POST',{mediaPath:row.mediaPath,mediaType:row.mediaType});if(!r.ok)throw new Error();url=endpoint('/preview/'+encodeURIComponent((await r.json()).token));}
  return {kind:draftKind,name:draftName,url,active:draftActive};
 });
 core.watch('media',form,dirty,()=>busy);
 core.whenSection('media',()=>{if(!loaded&&!busy)load();});
 document.addEventListener('admin:section',event=>{if(event.detail.section!=='media')clearPreview();});
 document.addEventListener('visibilitychange',()=>{if(document.hidden)clearPreview();});
})();
