(() => {
  const root=document.getElementById('admin-applications'),base=document.querySelector('meta[name="companyportal-api-base"]')?.content;
  if(!root||!base)return;
  const endpoint=path=>new URL('api/admin/application-directory'+path,new URL(base.replace(/\/?$/,'/'),location.href));
  const list=document.getElementById('admin-application-details'),categoryList=document.getElementById('admin-application-categories');
  const status=document.getElementById('admin-applications-status'),retry=document.getElementById('admin-applications-retry'),add=document.getElementById('admin-category-add'),search=document.getElementById('admin-application-search');
  const make=(tag,cls,text)=>{const node=document.createElement(tag);if(cls)node.className=cls;if(text)node.textContent=text;return node;};
  let categories=[],loaded=false,busy=false;
  const core=window.AdminCore;
  const request=(path,method='GET',body)=>core.request(endpoint(path),{method,body,header:'application-directory',timeout:10000});
  const message=(text,canRetry=false)=>{core.feedback(status,text);retry.hidden=!canRetry;};
  const dirty=()=>root.querySelector('.is-dirty')!==null;
  function refresh(){root.querySelectorAll('form').forEach(form=>form.dispatchEvent(new Event('directory:refresh')));add.disabled=busy||!loaded;}
  function options(select,value){
    select.replaceChildren();const none=make('option',null,'غير مصنف');none.value='';select.append(none);
    [...categories].sort((a,b)=>a.displayOrder-b.displayOrder||a.categoryId-b.categoryId).forEach(category=>{const option=make('option',null,category.categoryName+(category.active?'':' — غير نشط'));option.value=String(category.categoryId);select.append(option);});
    select.value=value===null?'':String(value);
  }
  function field(form,caption,tag='input',cls=''){
    const label=make('label',cls),input=make(tag);label.append(make('span',null,caption),input);form.append(label);return input;
  }
  async function save(form,path,method,body,onSaved){
    if(busy)return;busy=true;root.querySelectorAll('input,textarea,select,button').forEach(node=>{node.disabled=true;});refresh();message('جارٍ حفظ معلومات الدليل…');
    try{
      const response=await request(path,method,body);
      if(!response.ok){
        if(response.status===401||response.status===403){list.replaceChildren();categoryList.replaceChildren();loaded=false;}
        message(response.status===400?'تحقق من الاسم والوصف والترتيب؛ قد يكون اسم التصنيف مستخدمًا.':response.status===401||response.status===403?'ليس لديك صلاحية إدارة دليل التطبيقات.':response.status===404?'التطبيق أو التصنيف لم يعد موجودًا. أعد تحميل الدليل.':'تعذر حفظ الدليل. تحقق من الاتصال وأعد المحاولة.',true);return;
      }
      onSaved(response.status===201?await response.json():null);
      message('تم الحفظ. تظهر المعلومات للموظفين عند إعادة فتح دليل الأنظمة؛ الصلاحيات لا تتغير.');
    }catch{message('تعذر تأكيد الحفظ. أعد تحميل الدليل للتحقق قبل إعادة المحاولة.',true);}
    finally{busy=false;root.querySelectorAll('input,textarea,select,button').forEach(node=>{node.disabled=false;});refresh();}
  }
  function categoryForm(category,isNew=false){
    const form=make('form','admin-directory-form');form.setAttribute('aria-label',isNew?'تصنيف جديد':'تصنيف '+category.categoryName);
    AdminChanges.tag(form,'applications','category',isNew?null:category.categoryId);
    if(isNew)form.dataset.newCategory='';
    const name=field(form,'اسم التصنيف');name.value=category.categoryName;name.maxLength=200;name.required=true;
    const order=field(form,'ترتيب التصنيف');order.type='number';order.min=0;order.step=1;order.required=true;order.value=category.displayOrder;
    const button=make('button',null,isNew?'إنشاء التصنيف':'حفظ التصنيف');button.type='submit';form.append(button);
    const activeLabel=make('label','admin-directory-active'),active=make('input');active.type='checkbox';active.checked=category.active;activeLabel.append(active,make('span',null,'تصنيف نشط'));form.append(activeLabel);
    const note=make('p','admin-directory-note');form.append(note);
    const values=()=>({categoryName:name.value.trim(),displayOrder:Number(order.value),active:active.checked});
    function sync(){const value=values(),changed=isNew||value.categoryName!==category.categoryName||value.displayOrder!==category.displayOrder||value.active!==category.active;form.classList.toggle('is-dirty',changed);button.disabled=busy||!changed;note.textContent=changed?'تغييرات غير محفوظة':category.active?'متاح لتصنيف التطبيقات.':'التطبيقات التابعة تظهر تحت غير مصنف.';}
    form.addEventListener('input',sync);form.addEventListener('change',sync);form.addEventListener('directory:refresh',sync);
    if(isNew){const cancel=make('button',null,'إلغاء');cancel.type='button';cancel.addEventListener('click',async()=>{if(!busy&&await core.discard())form.remove();});form.append(cancel);}
    form.addEventListener('submit',event=>{event.preventDefault();const value=values();if(!value.categoryName){name.focus();return;}
      save(form,'/categories'+(isNew?'':'/'+category.categoryId),isNew?'POST':'PUT',value,result=>{
        Object.assign(category,value);if(isNew){category.categoryId=result.categoryId;categories.push(category);form.replaceWith(categoryForm(category));}
        else form.setAttribute('aria-label','تصنيف '+category.categoryName);
        list.querySelectorAll('select').forEach(select=>{const current=select.value;options(select,current||null);});
      });
    });sync();core.watch('applications',form,()=>form.classList.contains('is-dirty'),()=>busy);return form;
  }
  function applicationForm(app){
    const form=make('form','admin-directory-form');form.setAttribute('aria-label','وصف '+app.appName);form.dataset.appName=app.appName;
    AdminChanges.tag(form,'applications','application',app.appId);
    form.append(make('h3',null,app.appName));
    const category=field(form,'التصنيف','select');options(category,app.categoryId);
    const button=make('button',null,'حفظ الوصف والتصنيف');button.type='submit';form.append(button);
    const description=field(form,'وصف التطبيق','textarea','admin-directory-description');description.value=app.description;description.maxLength=2000;description.rows=3;
    const note=make('p','admin-directory-note');form.append(note);
    const values=()=>({description:description.value.trim(),categoryId:category.value?Number(category.value):null});
    function sync(){const value=values(),changed=value.description!==app.description||value.categoryId!==app.categoryId;form.classList.toggle('is-dirty',changed);button.disabled=busy||!changed;note.textContent=changed?'تغييرات غير محفوظة':'معلومات عرض؛ لا تغيّر صلاحيات التطبيق أو رابط تشغيله.';}
    form.addEventListener('input',sync);form.addEventListener('change',sync);form.addEventListener('directory:refresh',sync);
    form.addEventListener('submit',event=>{event.preventDefault();const value=values();save(form,'/applications/'+app.appId,'PUT',value,()=>{Object.assign(app,value);description.value=app.description;});});sync();core.watch('applications',form,()=>form.classList.contains('is-dirty'),()=>busy);return form;
  }
  async function load(){
    if(busy)return;busy=true;add.disabled=true;retry.disabled=true;message('جارٍ تحميل التطبيقات والتصنيفات…');
    try{
      const response=await request('');
      if(!response.ok){list.replaceChildren();categoryList.replaceChildren();loaded=false;message(response.status===401||response.status===403?'ليس لديك صلاحية إدارة دليل التطبيقات.':'تعذر تحميل الدليل. تحقق من خدمة البوابة وإعداد مصدر التطبيقات.',true);refresh();return;}
      const result=await response.json();categories=result.categories;loaded=true;
      categoryList.replaceChildren(...categories.map(category=>categoryForm(category)));
      list.replaceChildren(...result.applications.map(applicationForm));
      if(!result.applications.length)list.append(make('p',null,'لا توجد تطبيقات نشطة في المصدر.'));
      message('الدليل جاهز. يمكنك تعديل الأوصاف وإدارة التصنيفات.');refresh();filter();
    }catch{list.replaceChildren();categoryList.replaceChildren();loaded=false;message('تعذر الاتصال بخدمة دليل التطبيقات.',true);}
    finally{busy=false;retry.disabled=false;refresh();}
  }
  const normalize=value=>value.replace(/[أإآ]/g,'ا').toLowerCase().trim();
  function filter(){const query=normalize(search.value);list.querySelectorAll('form').forEach(form=>{form.hidden=!normalize(form.dataset.appName).includes(query);});}
  add.addEventListener('click',()=>{if(!busy&&!categoryList.querySelector('[data-new-category]')){const form=categoryForm({categoryName:'',displayOrder:categories.length+1,active:true},true);categoryList.prepend(form);form.querySelector('input').focus();}});
  retry.addEventListener('click',async()=>{if(!busy&&(!dirty()||await core.discard()))load();});
  search.addEventListener('input',filter);
  core.watch('applications',root,()=>false,()=>busy);
  core.whenSection('applications',()=>{if(!loaded&&!busy)load();});
})();
