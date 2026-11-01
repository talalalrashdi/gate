(() => {
 const host=document.getElementById('custom-popup-admin'),core=window.AdminCore;if(!host)return;
 const form=document.getElementById('custom-popup-form'),list=document.getElementById('custom-popup-list'),status=document.getElementById('custom-popup-status'),retry=document.getElementById('custom-popup-retry');
 let rows=[],loaded=false,busy=false;const tracker=core.trackForm('notices',form,{busy:()=>busy});
 const field=name=>form.elements.namedItem(name),make=(tag,text)=>{const n=document.createElement(tag);n.textContent=text;return n;};
 const local=value=>new Date(Date.parse(value)+4*3600000).toISOString().slice(0,16);
 function reset(row){form.reset();field('popupId').value=row?.popupId||'';field('popupType').value=row?.popupType||'';field('details').value=row?.details||'';field('startAt').value=local(row?.startAt||new Date().toISOString());field('endAt').value=local(row?.endAt||new Date(Date.now()+7*86400000).toISOString());field('isDisplayed').checked=row?.isDisplayed||false;tracker.saved();}
 async function request(path='',method='GET',body){const r=await core.request('api/admin/custom-popups'+path,{method,body,header:'custom-popups'});if(!r.ok)throw new Error();return r.status===204||r.status===201?null:r.json();}
 function render(){list.replaceChildren();if(!rows.length)list.append(make('p','لا توجد تنويهات مخصصة.'));
  for(const row of rows){const card=make('article','');card.className='custom-popup-admin-row';window.AdminChanges?.tag(card,'notices','custom-popup',row.popupId);const state=make('small',!row.isDisplayed?'مخفي':Date.parse(row.endAt)<=Date.now()?'منتهي':Date.parse(row.startAt)>Date.now()?'مجدول':'ظاهر للجميع');card.append(make('h3',row.popupType),state,make('p',row.details),make('p',local(row.startAt).replace('T',' ')+' ← '+local(row.endAt).replace('T',' ')+' · توقيت عُمان'));
   const edit=make('button','تعديل'),remove=make('button','حذف');edit.type=remove.type='button';edit.disabled=remove.disabled=busy;
   edit.onclick=async()=>{if(busy||tracker.dirty()&&!await core.discard())return;reset(row);form.scrollIntoView({behavior:'smooth',block:'center'});};
   remove.onclick=async()=>{if(busy||tracker.dirty()&&!await core.discard()||!await core.confirm('حذف التنويه «'+row.popupType+'»؟',{title:'حذف التنويه',accept:'حذف',danger:true}))return;await operation(async()=>{await request('/'+row.popupId,'DELETE');await loadData();reset();core.feedback(status,'تم حذف التنويه.');});};card.append(edit,remove);list.append(card);
  }
 }
 async function loadData(){rows=await request();loaded=true;render();}
 async function operation(action){if(busy)return;busy=true;form.querySelector('fieldset').disabled=true;retry.hidden=true;render();try{await action();}catch{core.feedback(status,'تعذر تحميل أو حفظ التنويه. تحقق من الاتصال والحقول ثم أعد المحاولة.',true);retry.hidden=false;}finally{busy=false;form.querySelector('fieldset').disabled=!loaded;render();core.refresh();}}
 form.onsubmit=e=>{e.preventDefault();const a=field('startAt').value,b=field('endAt').value;if(!a||!b||b<=a){core.feedback(status,'نهاية العرض يجب أن تكون بعد البداية.',true);return;}
  const id=field('popupId').value,body={popupType:field('popupType').value.trim(),details:field('details').value.trim(),startAt:new Date(a+'+04:00').toISOString(),endAt:new Date(b+'+04:00').toISOString(),isDisplayed:field('isDisplayed').checked};
  if(!body.popupType||!body.details){core.feedback(status,'أدخل النوع والتفاصيل.',true);return;}
  void operation(async()=>{await request(id?'/'+id:'',id?'PUT':'POST',body);tracker.saved();await loadData();reset();core.feedback(status,'تم حفظ التنويه.');});};
 document.getElementById('custom-popup-cancel').onclick=async()=>{if(!busy&&(!tracker.dirty()||await core.discard()))reset();};
 retry.onclick=()=>{if(!busy&&!tracker.dirty())void operation(loadData);};
 core.whenSection('notices',()=>{if(!loaded&&!busy)void operation(async()=>{await loadData();reset();});});
})();
