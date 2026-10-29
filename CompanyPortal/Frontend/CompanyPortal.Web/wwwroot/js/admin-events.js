(() => {
 const root=document.getElementById('admin-events');if(!root)return;
 const core=window.AdminCore,form=document.getElementById('event-editor'),list=document.getElementById('events-list'),status=document.getElementById('events-status'),retry=document.getElementById('events-retry');
 const field=name=>form.elements.namedItem(name),make=(tag,text)=>Object.assign(document.createElement(tag),{textContent:text});
 let busy=false,loaded=false,editing=null;
 const tracker=core.trackForm('events',form,{busy:()=>busy});
 const request=(path='',method='GET',body)=>core.request('api/admin/events'+path,{method,body,header:'events'});
 const fmt=new Intl.DateTimeFormat('ar-OM',{dateStyle:'medium',timeStyle:'short',timeZone:'Asia/Muscat'});
 const local=at=>new Date(new Date(at).getTime()+4*3600000).toISOString().slice(0,16);
 function message(text,error=false){core.feedback(status,text,error);}
 function close(){form.hidden=true;form.reset();editing=null;tracker.saved();}
 async function edit(row){if(busy||tracker.dirty()&&!await core.discard())return;form.hidden=false;editing=row?.eventId??null;
  document.getElementById('event-editor-title').textContent=row?'تعديل الفعالية':'فعالية جديدة';
  field('title').value=row?.title??'';field('appUrl').value=row?.appUrl??'';field('startAt').value=local(row?.startAt??Date.now());field('endAt').value=local(row?.endAt??Date.now()+7*86400000);field('active').checked=row?.active??true;tracker.saved();field('title').focus();
 }
 function render(rows){list.replaceChildren();if(!rows.length)list.append(make('p','لا توجد فعاليات.'));
  for(const row of rows){const item=make('article','');item.className='event-row';const copy=make('div',''),state=!row.active?'مخفية':Date.parse(row.endAt)<=Date.now()?'انتهت':Date.parse(row.startAt)>Date.now()?'مجدولة':'ظاهرة للجميع';
   copy.append(make('strong',row.title),make('p',state),make('p',fmt.format(new Date(row.startAt))+' — '+fmt.format(new Date(row.endAt))));
   const url=make('p',row.appUrl);url.dir='ltr';copy.append(url);
   const editButton=make('button','تعديل'),remove=make('button','حذف');editButton.type=remove.type='button';remove.className='event-delete';editButton.onclick=()=>void edit(row);
   remove.onclick=async()=>{if(busy||tracker.dirty()&&!await core.discard())return;if(!await core.confirm('حذف «'+row.title+'»؟',{title:'حذف الفعالية',accept:'حذف',danger:true}))return;
    await run(async()=>{const r=await request('/'+row.eventId,'DELETE');if(!r.ok)throw new Error();close();await load();message('تم الحذف');});};
   item.append(copy,editButton,remove);AdminChanges.tag(item,'events','event',row.eventId);list.append(item);
  }
 }
 async function load(){retry.hidden=true;try{const r=await request();if(!r.ok)throw new Error();const rows=await r.json();render(rows);loaded=true;}catch{retry.hidden=false;throw new Error('تعذر تحميل الفعاليات.');}}
 async function run(action){if(busy)return;busy=true;const controls=[...root.querySelectorAll('button,input')].filter(e=>!e.disabled);controls.forEach(e=>e.disabled=true);core.refresh();try{await action();}catch(e){message(e.message==='تعذر تحميل الفعاليات.'?e.message:'تعذر إتمام العملية. تحقق من الحقول والاتصال ثم حاول مجددًا.',true);}finally{busy=false;controls.forEach(e=>{if(e.isConnected)e.disabled=false;});core.refresh();}}
 document.getElementById('event-add').onclick=()=>void edit(null);document.getElementById('event-cancel').onclick=async()=>{if(!busy&&(!tracker.dirty()||await core.discard()))close();};retry.onclick=()=>void run(load);
 form.addEventListener('submit',e=>{e.preventDefault();if(busy||!form.reportValidity())return;
  const start=field('startAt').value,end=field('endAt').value;if(end<=start){message('يجب أن تكون نهاية العرض بعد بدايته.',true);return;}
  const body={title:field('title').value.trim(),appUrl:field('appUrl').value.trim(),startAt:start+':00+04:00',endAt:end+':00+04:00',active:field('active').checked};
  void run(async()=>{const r=await request(editing?'/'+editing:'',editing?'PUT':'POST',body);if(!r.ok)throw new Error();close();await load();message('تم الحفظ. تظهر الفعالية خلال الفترة المحددة عند فتح البوابة.');});
 });
 core.whenSection('events',()=>{if(!loaded)void run(load);});
})();
