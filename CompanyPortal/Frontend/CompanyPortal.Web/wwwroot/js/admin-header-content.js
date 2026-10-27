(() => {
  // /admin/header-content: «أرقام تهمك» (Mng.ImportantNumbers) and حالة المؤسسة texts (Mng.StatusLevels).
  const root=document.getElementById('admin-header-content'),base=document.querySelector('meta[name="companyportal-api-base"]')?.content;if(!root||!base)return;
  const endpoint=path=>new URL('api/admin/header-content'+path,new URL(base.replace(/\/?$/,'/'),location.href));
  const byId=id=>document.getElementById(id),status=byId('header-content-status'),retry=byId('header-content-retry'),add=byId('header-number-add'),numbers=byId('header-numbers'),levels=byId('header-levels');
  const make=(tag,props={})=>Object.assign(document.createElement(tag),props);
  const request=(path,method='GET',body)=>fetch(endpoint(path),{method,credentials:'include',cache:'no-store',signal:AbortSignal.timeout(15000),
    ...(method==='GET'?{}:{headers:{'Content-Type':'application/json','X-CompanyPortal-Request':'header-content'},body:body===undefined?undefined:JSON.stringify(body)})});
  let loaded=false,busy=false;
  function message(text,canRetry=false){status.textContent=text;retry.hidden=!canRetry;}
  async function failure(response){if(response.status===400)return'تحقق من الحقول المطلوبة.';if(response.status===403)return'حسابك غير مخوّل لإدارة هذا القسم.';if(response.status===404)return'العنصر غير موجود. أعد التحميل.';return'تعذر الحفظ. حاول مجددًا.';}
  function field(label,value,attrs={}){const wrap=make('label',{className:'hc-field'}),input=make(attrs.multiline?'textarea':'input',{value:value??''});
    Object.entries(attrs).forEach(([k,v])=>{if(k!=='multiline')input.setAttribute(k,v);});wrap.append(make('span',{textContent:label}),input);return [wrap,input];}

  function numberRow(item){
    const row=make('div',{className:'hc-number-row'});row.setAttribute('role','row');
    const title=make('input',{value:item?.title??'',maxLength:150,required:true,placeholder:'مثال: طوارئ المؤسسة'});title.setAttribute('aria-label','الاسم');
    const number=make('input',{value:item?.number??'',maxLength:50,required:true,dir:'ltr',placeholder:'1000'});number.setAttribute('aria-label','الرقم');
    const order=make('input',{type:'number',min:0,max:100000,value:item?.sortOrder??(numbers.children.length+1)});order.setAttribute('aria-label','الترتيب');
    const active=make('input',{type:'checkbox',checked:item?.active??true});active.setAttribute('aria-label','ظاهر للمستخدمين');
    const save=make('button',{type:'button',className:'admin-primary',textContent:item?'حفظ':'إضافة'}),remove=make('button',{type:'button',className:'hc-danger',textContent:item?'حذف':'إلغاء'});
    const cells=[title,number,order,active].map(input=>{const cell=make('span');cell.setAttribute('role','cell');cell.append(input);return cell;});
    const actions=make('span',{className:'hc-actions'});actions.setAttribute('role','cell');actions.append(save,remove);row.append(...cells,actions);
    save.addEventListener('click',async()=>{
      if(busy)return;if(!title.value.trim()||!number.value.trim()){message('أدخل الاسم والرقم.');(title.value.trim()?number:title).focus();return;}
      busy=true;save.disabled=true;message('جارٍ الحفظ…');
      try{const body={title:title.value.trim(),number:number.value.trim(),sortOrder:Number(order.value)||0,active:active.checked};
        const response=await request(item?'/important-numbers/'+item.id:'/important-numbers',item?'PUT':'POST',body);
        if(!response.ok){message(await failure(response));return;}busy=false;await load(false);message('تم الحفظ. يظهر للمستخدمين عند إعادة تحميل البوابة.');}
      catch{message('تعذر الحفظ. حاول مجددًا.');}finally{busy=false;save.disabled=false;}
    });
    remove.addEventListener('click',async()=>{
      if(!item){row.remove();return;}if(busy||!confirm(`حذف «${item.title}»؟`))return;
      busy=true;remove.disabled=true;message('جارٍ الحذف…');
      try{const response=await request('/important-numbers/'+item.id,'DELETE');if(!response.ok){message(await failure(response));return;}busy=false;await load(false);message('تم الحذف.');}
      catch{message('تعذر الحذف. حاول مجددًا.');}finally{busy=false;remove.disabled=false;}
    });
    return row;
  }

  function levelCard(level){
    const card=make('form',{className:'hc-level is-'+level.color});card.noValidate=true;
    const head=make('div',{className:'hc-level-head'});head.append(make('span',{className:'hc-dot'}),make('strong',{textContent:level.title}));
    const [titleWrap,title]=field('العنوان',level.title,{maxlength:100,required:''});
    const [nameWrap,name]=field('اسم اللون',level.colorName,{maxlength:30,required:''});
    const [summaryWrap,summary]=field('الوصف (يظهر في النافذة عند هذه الحالة)',level.summary,{maxlength:600,required:'',rows:3,multiline:true});
    const [guideWrap,guide]=field('نص مختصر في «دليل الحالات»',level.guideText,{maxlength:300,rows:2,multiline:true});
    const [actionsWrap,actions]=field('ما الذي يجب فعله؟ — خطوة في كل سطر',level.actions,{maxlength:1500,rows:4,multiline:true});
    if(level.color==='green'){guideWrap.hidden=true;actionsWrap.hidden=true;}
    const save=make('button',{type:'submit',className:'admin-primary',textContent:'حفظ'}),note=make('small',{className:'hc-note',textContent:'آخر تعديل: '+String(level.lastChangeAt||'').replace('T',' ').slice(0,16)});
    const footer=make('div',{className:'hc-level-footer'});footer.append(note,save);
    card.append(head,titleWrap,nameWrap,summaryWrap,guideWrap,actionsWrap,footer);
    card.addEventListener('submit',async event=>{
      event.preventDefault();if(busy)return;
      if(!title.value.trim()||!name.value.trim()||!summary.value.trim()){message('أدخل العنوان واسم اللون والوصف.');return;}
      busy=true;save.disabled=true;message('جارٍ الحفظ…');
      try{const response=await request('/status-levels/'+level.colorValue,'PUT',{title:title.value.trim(),colorName:name.value.trim(),summary:summary.value.trim(),guideText:guide.value.trim()||null,actions:actions.value.trim()||null});
        if(!response.ok){message(await failure(response));return;}const saved=title.value.trim();busy=false;await load(false);message('تم حفظ نصوص «'+saved+'». تظهر للمستخدمين عند إعادة تحميل البوابة.');}
      catch{message('تعذر الحفظ. حاول مجددًا.');}finally{busy=false;save.disabled=false;}
    });
    return card;
  }

  async function load(announce=true){
    if(busy)return;busy=true;add.disabled=true;if(announce)message('جارٍ التحميل…');
    try{
      const response=await request('');if(!response.ok){message(response.status===403?'حسابك غير مخوّل لإدارة هذا القسم.':'تعذر تحميل المحتوى.',true);return;}
      const data=await response.json();
      numbers.replaceChildren(...data.numbers.map(numberRow));
      levels.replaceChildren(...data.levels.map(levelCard));
      loaded=true;add.disabled=false;if(announce)message('');
    }catch{message('تعذر تحميل المحتوى.',true);}finally{busy=false;}
  }
  add.addEventListener('click',()=>{const row=numberRow(null);numbers.append(row);row.querySelector('input').focus();});
  retry.addEventListener('click',()=>load());
  document.querySelectorAll('[data-admin-section="header-content"]').forEach(b=>b.addEventListener('click',()=>{if(!loaded)load();}));
  window.addEventListener('popstate',()=>{if(location.hash==='#header-content'&&!loaded)load();});
  if(document.body.dataset.adminStart==='header-content'||location.hash==='#header-content')load();
})();
