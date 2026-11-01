document.querySelectorAll('[data-header-content-editor]').forEach(root => {
  // Independent pages and drafts; shared header-content API permission/audit contract.
  const section=root.dataset.headerContentEditor,isNumbers=section==='important-numbers',base=document.querySelector('meta[name="companyportal-api-base"]')?.content;if(!root||!base)return;
  const endpoint=path=>new URL('api/admin/header-content'+path,new URL(base.replace(/\/?$/,'/'),location.href));
  const byId=id=>document.getElementById(id),status=byId(section+'-status'),retry=byId(section+'-retry'),add=isNumbers?byId('header-number-add'):null,numbers=isNumbers?byId('header-numbers'):null,levels=isNumbers?null:byId('header-levels');
  const make=(tag,props={})=>Object.assign(document.createElement(tag),props);
  const core=window.AdminCore;
  const request=(path,method='GET',body)=>core.request(endpoint(path),{method,body,header:'header-content'});
  const lock=(element,value)=>element.querySelectorAll('input,textarea,select,button').forEach(e=>e.disabled=value);
  let loaded=false,busy=false,creationModal;
  function message(text,canRetry=false){core.feedback(status,text);retry.hidden=!canRetry;}
  async function failure(response){if(response.status===400)return'تحقق من الحقول المطلوبة.';if(response.status===403)return'حسابك غير مخوّل لإدارة هذا القسم.';if(response.status===404)return'العنصر غير موجود. أعد التحميل.';return'تعذر الحفظ. حاول مجددًا.';}
  function field(label,value,attrs={}){const wrap=make('label',{className:'hc-field'}),input=make(attrs.multiline?'textarea':'input',{value:value??''});
    Object.entries(attrs).forEach(([k,v])=>{if(k!=='multiline')input.setAttribute(k,v);});wrap.append(make('span',{textContent:label}),input);return [wrap,input];}

  function numberRow(item){
    const row=make('div',{className:'hc-number-row'});row.setAttribute('role','row');AdminChanges.tag(row,'important-numbers','important-number',item?.id);
    const title=make('input',{value:item?.title??'',maxLength:150,required:true,placeholder:'مثال: طوارئ المؤسسة'});title.setAttribute('aria-label','الاسم');
    const number=make('input',{value:item?.number??'',maxLength:50,required:true,dir:'ltr',placeholder:'1000'});number.setAttribute('aria-label','الرقم');
    const order=make('input',{type:'number',min:0,max:100000,value:item?.sortOrder??(numbers.children.length+1)});order.setAttribute('aria-label','الترتيب');
    const active=make('input',{type:'checkbox',checked:item?.active??true});active.setAttribute('aria-label','ظاهر للمستخدمين');
    const save=make('button',{type:'button',className:'admin-primary',textContent:item?'حفظ':'إضافة'}),remove=make('button',{type:'button',className:'hc-danger',textContent:item?'حذف':'إلغاء'});
    const cells=[title,number,order,active].map(input=>{const cell=make('span');cell.setAttribute('role','cell');if(!item)cell.dataset.label=input.getAttribute('aria-label');cell.append(input);return cell;});
    const actions=make('span',{className:'hc-actions'});actions.setAttribute('role','cell');actions.append(save,remove);row.append(...cells,actions);const tracker=core.trackForm(section,row,{isNew:!item,busy:()=>busy});
    save.addEventListener('click',async()=>{
      if(busy)return;if(!title.value.trim()||!number.value.trim()){message('أدخل الاسم والرقم.');(title.value.trim()?number:title).focus();return;}
      busy=true;lock(row,true);message('جارٍ الحفظ…');
      try{const body={title:title.value.trim(),number:number.value.trim(),sortOrder:Number(order.value)||0,active:active.checked};
        const response=await request(item?'/important-numbers/'+item.id:'/important-numbers',item?'PUT':'POST',body);
        if(!response.ok){message(await failure(response));return;}const id=item?.id??(await response.json()).id;if(item)row.replaceWith(numberRow({...item,...body,id}));else{numbers.append(numberRow({...body,id}));creationModal?.close();}message('تم الحفظ. يظهر للمستخدمين عند إعادة تحميل البوابة.');}
      catch{message('تعذر الحفظ. حاول مجددًا.');}finally{busy=false;lock(row,false);core.refresh();}
    });
    remove.addEventListener('click',async()=>{
      if(busy)return;if(!item){await creationModal?.requestClose();return;}if(!await core.confirm(`حذف «${item.title}»؟`,{title:'حذف الرقم',accept:'حذف',danger:true}))return;
      busy=true;remove.disabled=true;message('جارٍ الحذف…');
      try{const response=await request('/important-numbers/'+item.id,'DELETE');if(!response.ok){message(await failure(response));return;}row.remove();message('تم الحذف.');}
      catch{message('تعذر الحذف. حاول مجددًا.');}finally{busy=false;remove.disabled=false;}
    });
    return row;
  }

  function levelCard(level){
    const card=make('form',{className:'hc-level is-'+level.color});card.noValidate=true;AdminChanges.tag(card,'institution-status','status-level',level.colorValue);
    const head=make('div',{className:'hc-level-head'});head.append(make('span',{className:'hc-dot'}),make('strong',{textContent:level.title}));
    const [titleWrap,title]=field('العنوان',level.title,{maxlength:100,required:''});
    const [nameWrap,name]=field('اسم اللون',level.colorName,{maxlength:30,required:''});
    const [summaryWrap,summary]=field('الوصف (يظهر في النافذة عند هذه الحالة)',level.summary,{maxlength:600,required:'',rows:3,multiline:true});
    const [guideWrap,guide]=field('نص مختصر في «دليل الحالات»',level.guideText,{maxlength:300,rows:2,multiline:true});
    const [actionsWrap,actions]=field('ما الذي يجب فعله؟ — خطوة في كل سطر',level.actions,{maxlength:1500,rows:4,multiline:true});
    if(level.color==='green'){guideWrap.hidden=true;actionsWrap.hidden=true;}
    const save=make('button',{type:'submit',className:'admin-primary',textContent:'حفظ'}),note=make('small',{className:'hc-note',textContent:'تُحفظ نصوص هذه الحالة مستقلة.'});
    const footer=make('div',{className:'hc-level-footer'});footer.append(note,save);AdminPreview.button(footer,section,()=>({kind:'status',color:level.color,title:title.value,colorName:name.value,summary:summary.value,guideText:guide.value,actions:actions.value}));
    card.append(head,titleWrap,nameWrap,summaryWrap,guideWrap,actionsWrap,footer);const tracker=core.trackForm(section,card,{busy:()=>busy});
    card.addEventListener('submit',async event=>{
      event.preventDefault();if(busy)return;
      if(!title.value.trim()||!name.value.trim()||!summary.value.trim()){message('أدخل العنوان واسم اللون والوصف.');return;}
      busy=true;lock(card,true);message('جارٍ الحفظ…');
      try{const response=await request('/status-levels/'+level.colorValue,'PUT',{title:title.value.trim(),colorName:name.value.trim(),summary:summary.value.trim(),guideText:guide.value.trim()||null,actions:actions.value.trim()||null});
        if(!response.ok){message(await failure(response));return;}tracker.saved();head.querySelector('strong').textContent=title.value.trim();note.textContent='تم حفظ التغييرات.';message('تم حفظ نصوص «'+title.value.trim()+'». تظهر للمستخدمين عند إعادة تحميل البوابة.');}
      catch{message('تعذر الحفظ. حاول مجددًا.');}finally{busy=false;lock(card,false);core.refresh();}
    });
    return card;
  }

  function renderCurrent(data,definitions){
    const target=byId('institution-current-editor'),history=byId('institution-status-history');target.replaceChildren();history.replaceChildren();
    const form=make('form',{className:'hc-current-form'}),label=make('label',{textContent:'الحالة الجديدة'}),select=make('select',{required:true});
    const empty=make('option',{value:'',textContent:'اختر الحالة'});select.append(empty);definitions.forEach(level=>select.append(make('option',{value:String(level.colorValue),textContent:level.title+' — '+level.colorName})));select.value=data.current?String(data.current.colorValue):'';label.append(select);
    const currentTitle=definitions.find(r=>r.colorValue===data.current?.colorValue)?.title||'لم تُحدد بعد';const current=make('p',{textContent:'الحالة الحالية: '+currentTitle});
    const fmt=value=>new Intl.DateTimeFormat('ar-OM',{dateStyle:'medium',timeStyle:'short',timeZone:'Asia/Muscat'}).format(new Date(value));
    if(data.current)target.append(make('p',{className:'hc-current-meta',textContent:'آخر تغيير: '+(data.current.displayName||'غير مسجل للبيانات القديمة')+' · '+fmt(data.current.lastUpdated)}));
    const save=make('button',{type:'submit',className:'admin-primary',textContent:'تطبيق الحالة'});form.append(current,label,save);target.append(form);core.trackForm(section,form,{busy:()=>busy});
    const sync=()=>{save.disabled=busy||!select.value||Number(select.value)===data.current?.colorValue;};select.addEventListener('change',sync);sync();
    form.addEventListener('submit',async e=>{e.preventDefault();if(busy||!form.reportValidity()||Number(select.value)===data.current?.colorValue)return;const next=definitions.find(r=>r.colorValue===Number(select.value));if(!await core.confirm('تغيير حالة المؤسسة من «'+currentTitle+'» إلى «'+next.title+'»؟ ستظهر للمستخدمين عند تحميل البوابة.',{title:'تأكيد تغيير حالة المؤسسة',accept:'تطبيق الحالة',danger:next.colorValue===4}))return;
      busy=true;lock(form,true);try{const response=await request('/current-status','PUT',{colorValue:Number(select.value)});if(!response.ok){message(await failure(response));return;}const result=await request('/current-status');if(!result.ok)throw new Error();renderCurrent(await result.json(),definitions);message('تم حفظ الحالة وتسجيل التغيير.');}catch{message('تعذر تأكيد تغيير الحالة. أعد تحميل الصفحة للتحقق قبل إعادة المحاولة.',true);}finally{busy=false;lock(form,false);sync();core.refresh();}
    });
    history.append(make('h3',{textContent:'سجل تغيير الحالة'}));if(!data.history.length){history.append(make('p',{textContent:'لا توجد تغييرات مسجلة حتى الآن.'}));return;}
    const table=make('table',{className:'hc-status-history'}),head=make('tr');['من','إلى','بواسطة','التاريخ والوقت'].forEach(text=>head.append(make('th',{textContent:text})));const thead=make('thead');thead.append(head);table.append(thead);const body=make('tbody');for(const row of data.history){const tr=make('tr');[row.fromTitle||'غير محددة',row.toTitle||'غير محددة',row.displayName||row.changedBy,fmt(row.changedAt)].forEach(text=>tr.append(make('td',{textContent:text})));body.append(tr);}table.append(body);history.append(table,make('p',{textContent:'آخر 50 تغييرًا. السجل الكامل متاح في سجل التعديلات للمدير العام.'}));
  }

  async function load(announce=true){
    if(busy)return;busy=true;if(add)add.disabled=true;if(announce)message('جارٍ التحميل…');
    try{
      const response=await request('');if(!response.ok){message(response.status===403?'حسابك غير مخوّل لإدارة هذا القسم.':'تعذر تحميل المحتوى.',true);return;}
      const data=await response.json();
      numbers?.replaceChildren(...data.numbers.map(numberRow));
      levels?.replaceChildren(...data.levels.map(levelCard));
      if(!isNumbers){const current=await request('/current-status');if(!current.ok)throw new Error();renderCurrent(await current.json(),data.levels);}
      loaded=true;if(add)add.disabled=false;if(announce)message('');
    }catch{message('تعذر تحميل المحتوى.',true);}finally{busy=false;}
  }
  add?.addEventListener('click',()=>{if(busy||!loaded||creationModal)return;const row=numberRow(null);creationModal=window.AdminEditorModal.open({title:'إضافة رقم',section,content:row,status,mount:root,busy:()=>busy,onCancel:async()=>await core.discard(),onClosed:()=>{row.remove();creationModal=null;}});row.querySelector('input').focus();});
  retry.addEventListener('click',async()=>{if(!busy&&(!core.dirtyIn(section)||await core.discard()))load();});
  if(add){const numberActions=make('div',{className:'hc-actions'});add.replaceWith(numberActions);numberActions.append(add);
  AdminPreview.button(numberActions,section,()=>({kind:'numbers',rows:[...numbers.querySelectorAll('.hc-number-row')].map(r=>{const a=r.querySelectorAll('input');return{title:a[0].value,number:a[1].value,active:a[3].checked,order:Number(a[2].value)};}).sort((a,b)=>a.order-b.order)}));
  }
  core.watch(section,root,()=>false,()=>busy);
  core.whenSection(section,()=>{if(!loaded&&!busy)load();});
});
