(() => {
  const form=document.getElementById('portal-electronic-service-form'),base=document.querySelector('meta[name="companyportal-api-base"]')?.content;if(!form||!base)return;
  const card=form.closest('.portal-work-card'),tabs=[...card.querySelectorAll('[data-technical-tab]')],panel=card.querySelector('[role="tabpanel"]'),fields=form.elements;
  const status=document.getElementById('portal-electronic-service-status'),retry=document.getElementById('technical-service-retry'),system=document.getElementById('technical-system-link');
  const endpoint=path=>new URL('api/technical-services'+path,new URL(base.replace(/\/?$/,'/'),location.href));
  const drafts={},attempts={};let kind='assignment',catalog=null,busy=false,loading=false;
  const names=['categoryId','recipientId','typeId','title','officeNumber','documentNumber','details'];
  const snapshot=()=>Object.fromEntries(names.map(name=>[name,fields[name].value]));
  function options(select,rows,selected){select.replaceChildren();const empty=document.createElement('option');empty.value='';empty.textContent=select.name==='categoryId'?'اختر تصنيف البلاغ':select.name==='recipientId'?(kind==='assignment'?'اختر جهة استلام البلاغ':'اختر الجهة'):'اختر النوع';select.append(empty);for(const row of rows){const option=document.createElement('option');option.value=String(row.id);option.textContent=row.name;select.append(option);}if(rows.some(r=>String(r.id)===String(selected)))select.value=String(selected);}
  function show(name,visible,required=false){const node=form.querySelector('[data-technical-field="'+name+'"]');node.hidden=!visible;const control=node.querySelector('input,select');control.disabled=!visible;control.required=visible&&required;}
  function configure(saved={}){
    const isReport=kind==='report',isAssignment=kind==='assignment';panel.dataset.kind=kind;
    options(fields.categoryId,catalog?.reportCategories||[],saved.categoryId);
    show('category',isReport,true);show('office',isAssignment);show('document',isAssignment);show('title',!isAssignment,true);
    if(catalog){
      const category=catalog.reportCategories.find(c=>String(c.id)===fields.categoryId.value);
      const recipientVisible=isAssignment||isReport&&category?.requiresRecipient;
      show('recipient',!!recipientVisible,true);card.querySelector('#technical-recipient-label').textContent=isAssignment?'جهة استلام البلاغ':'إلى جهة';
      options(fields.recipientId,isAssignment?catalog.assignmentRecipients:catalog.reportRecipients.filter(r=>r.categoryId===category?.id),saved.recipientId);
      show('type',kind==='initiative'||isReport&&!!category,true);options(fields.typeId,isReport?catalog.reportTypes.filter(t=>t.categoryId===category?.id):catalog.initiativeTypes,saved.typeId);
    }else{show('recipient',isAssignment,true);show('type',!isAssignment,true);}
    for(const name of ['title','officeNumber','documentNumber','details'])fields[name].value=saved[name]||'';
    const link=catalog?.links?.[kind];system.textContent=isAssignment?'نظام الإسناد':'نظام البلاغات';system.removeAttribute('href');system.setAttribute('aria-disabled','true');system.title='رابط النظام غير متاح حاليًا';
    if(link){const url=new URL(link);if(['http:','https:'].includes(url.protocol)){system.href=url.href;system.removeAttribute('aria-disabled');system.title='فتح '+system.textContent;}}
    form.querySelector('fieldset').disabled=busy||!catalog;
  }
  function change(next,focus=false){if(busy)return;drafts[kind]=snapshot();kind=next;tabs.forEach(tab=>{const active=tab.dataset.technicalTab===kind;tab.setAttribute('aria-selected',String(active));tab.tabIndex=active?0:-1;if(active&&focus)tab.focus();});panel.setAttribute('aria-labelledby','technical-tab-'+kind);configure(drafts[kind]);status.textContent='';}
  tabs.forEach((tab,index)=>{tab.addEventListener('click',()=>change(tab.dataset.technicalTab));tab.addEventListener('keydown',event=>{let next;if(event.key==='ArrowLeft')next=(index+1)%3;else if(event.key==='ArrowRight')next=(index+2)%3;else if(event.key==='Home')next=0;else if(event.key==='End')next=2;else return;event.preventDefault();change(tabs[next].dataset.technicalTab,true);});});
  fields.categoryId.addEventListener('change',()=>{const saved=snapshot();saved.recipientId='';saved.typeId='';configure(saved);});
  system.addEventListener('click',event=>{if(!system.hasAttribute('href')){event.preventDefault();status.textContent='رابط النظام غير متاح حاليًا.';}});
  async function load(){
    if(loading||busy)return;loading=true;retry.hidden=true;status.textContent='جارٍ تحميل قوائم الخدمات…';const saved=snapshot();form.querySelector('fieldset').disabled=true;
    try{const response=await fetch(endpoint(''),{credentials:'include',cache:'no-store',signal:AbortSignal.timeout(20000)});if(!response.ok)throw new Error('تعذر تحميل قوائم الخدمات. تحقق من الاتصال وأعد المحاولة.');const data=await response.json();if(['assignmentRecipients','reportCategories','reportRecipients','reportTypes','initiativeTypes'].some(key=>!Array.isArray(data[key])))throw new Error('استجابة قوائم الخدمات غير صالحة.');catalog=data;configure(saved);status.textContent='';}
    catch(error){catalog=null;configure(saved);retry.hidden=false;status.textContent=error.name==='Error'?error.message:'تعذر الاتصال بخدمة القوائم. حاول مجددًا.';}finally{loading=false;}
  }
  form.addEventListener('submit',async event=>{
    event.preventDefault();if(busy||!catalog)return;
    fields.details.setCustomValidity(fields.details.value.trim()?'':'اكتب تفاصيل الطلب.');fields.title.setCustomValidity(kind==='assignment'||fields.title.value.trim()?'':'اكتب عنوان الطلب.');if(!form.reportValidity())return;
    const payload={details:fields.details.value.trim()};
    if(kind==='assignment'){payload.recipientId=Number(fields.recipientId.value);payload.officeNumber=fields.officeNumber.value.trim();payload.documentNumber=fields.documentNumber.value.trim();}
    else{payload.title=fields.title.value.trim();payload.typeId=Number(fields.typeId.value);if(kind==='report'){payload.categoryId=Number(fields.categoryId.value);payload.recipientId=fields.recipientId.disabled?null:Number(fields.recipientId.value);}}
    const signature=JSON.stringify(payload);if(attempts[kind]?.signature!==signature)attempts[kind]={signature,key:crypto.randomUUID()};payload.requestKey=attempts[kind].key;
    busy=true;form.querySelector('fieldset').disabled=true;tabs.forEach(tab=>tab.disabled=true);retry.hidden=true;status.textContent='جارٍ إرسال الطلب…';
    try{const response=await fetch(endpoint('/'+kind),{method:'POST',credentials:'include',cache:'no-store',headers:{'Content-Type':'application/json','X-CompanyPortal-Request':'technical-services'},body:JSON.stringify(payload),signal:AbortSignal.timeout(20000)});const data=await response.json();if(!response.ok)throw new Error(data.title||'تعذر إرسال الطلب. احتفظ بالتفاصيل وحاول مجددًا.');drafts[kind]={};delete attempts[kind];configure();status.textContent='تم إرسال الطلب بنجاح. رقم الطلب: '+data.requestId;}
    catch(error){status.textContent=error.name==='Error'?error.message:'تعذر تأكيد الإرسال. احتفظ بالتفاصيل وأعد المحاولة؛ لن يتكرر الطلب نفسه.';retry.hidden=false;}
    finally{busy=false;form.querySelector('fieldset').disabled=!catalog;tabs.forEach(tab=>tab.disabled=false);}
  });
  form.addEventListener('input',()=>{fields.details.setCustomValidity('');fields.title.setCustomValidity('');});retry.addEventListener('click',()=>void load());configure();void load();
})();
